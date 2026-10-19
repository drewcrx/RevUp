param(
    [ValidateSet('Setup','Start','Stop','Status','Build','Run','Install','Firewall','Check')]
    [string]$Action = 'Status',
    [string]$ServerIp,
    [string]$DeviceId
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$entry = Join-Path $PSScriptRoot 'local.mjs'
$node = (Get-Command node).Source
$localRoot = Join-Path $projectRoot '.local'
$runtimeFile = Join-Path $localRoot 'runtime.json'
$hostArgs = @()
if ($ServerIp) {
    if ($ServerIp -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { throw 'ServerIp debe ser una IPv4 privada.' }
    $hostArgs = @('--host', $ServerIp)
}
Set-Location -LiteralPath $projectRoot

function Invoke-LocalNode([string]$Command) {
    & $node $entry $Command @hostArgs
    if ($LASTEXITCODE -ne 0) { throw "No se pudo completar $Command." }
}
function Get-LocalStatus {
    $result = & $node $entry status
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar el entorno local.' }
    return ($result | ConvertFrom-Json)
}
function Get-AndroidBridge {
    $properties = Get-Content -LiteralPath (Join-Path $projectRoot 'android\local.properties')
    $sdk = (($properties | Where-Object { $_ -like 'sdk.dir=*' }) -split '=',2)[1].Replace('\\','\')
    $bridge = Join-Path $sdk 'platform-tools\adb.exe'
    if (-not (Test-Path -LiteralPath $bridge)) { throw 'No se encontro adb. Revisa flutter doctor -v.' }
    return $bridge
}
function Get-Phone([string]$Bridge) {
    $devices = @(& $Bridge devices | Select-String '^([^\s]+)\s+device$' | ForEach-Object { $_.Matches[0].Groups[1].Value })
    if ($DeviceId) {
        if ($devices -notcontains $DeviceId) { throw 'El telefono indicado no esta conectado y autorizado.' }
        return $DeviceId
    }
    if ($devices.Count -ne 1) { throw 'Conecta y autoriza un telefono USB, o especifica -DeviceId si hay varios.' }
    return $devices[0]
}

switch ($Action) {
    'Setup' { Invoke-LocalNode 'setup' }
    'Start' {
        $current = Get-LocalStatus
        if (-not $current.running) {
            New-Item -ItemType Directory -Force -Path $localRoot | Out-Null
            $arguments = @(('"' + $entry + '"'), 'start') + $hostArgs
            Write-Output 'Iniciando PostgreSQL y API en segundo plano...'
            $process = Start-Process -FilePath $node -ArgumentList $arguments -WorkingDirectory $projectRoot `
                -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $localRoot 'supervisor.log') `
                -RedirectStandardError (Join-Path $localRoot 'supervisor-error.log')
            $deadline = (Get-Date).AddSeconds(100)
            do {
                Start-Sleep -Milliseconds 500
                $current = Get-LocalStatus
                $process.Refresh()
                if ($process.HasExited) { throw 'No se pudo iniciar. Revisa .local/supervisor-error.log.' }
            } until ($current.ready -or (Get-Date) -gt $deadline)
            if (-not $current.ready) { throw 'El entorno no termino de iniciar. Revisa .local/supervisor-error.log.' }
        }
        if ($current.stopping) { throw 'El entorno se esta deteniendo. Espera a que termine antes de iniciar de nuevo.' }
        if (-not $current.ready) {
            $deadline = (Get-Date).AddSeconds(100)
            do {
                Start-Sleep -Milliseconds 500
                $current = Get-LocalStatus
                if (-not $current.running) { throw 'El arranque termino con error. Revisa .local/supervisor-error.log.' }
            } until ($current.ready -or (Get-Date) -gt $deadline)
            if (-not $current.ready) { throw 'El entorno no termino de iniciar.' }
        }
        Write-Output ('API lista: ' + $current.apiUrl + '/health')
        Write-Output ('Credenciales privadas y datos: ' + $current.dataRoot)
    }
    'Stop' {
        Write-Output 'Deteniendo los servicios locales...'
        & $node $entry stop | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo solicitar el cierre de los servicios.' }
        $deadline = (Get-Date).AddSeconds(45)
        do { Start-Sleep -Milliseconds 500; $current = Get-LocalStatus }
        until (-not $current.running -or (Get-Date) -gt $deadline)
        if ($current.running) { throw 'El cierre sigue en curso. Revisa los registros antes de apagar la PC.' }
        Write-Output 'Servicios detenidos. La base y las fotos se conservan.'
    }
    'Status' { Get-LocalStatus | Format-List }
    'Build' {
        Invoke-LocalNode 'configure'
        & flutter build apk --flavor local --release --dart-define-from-file=.local/flutter.local.json
        if ($LASTEXITCODE -ne 0) { throw 'La compilacion APK fallo. Revisa el error anterior.' }
        Write-Output 'APK: build\app\outputs\flutter-apk\app-local-release.apk'
    }
    'Run' {
        Invoke-LocalNode 'configure'
        $bridge = Get-AndroidBridge
        $phone = Get-Phone $bridge
        & flutter run --flavor local --dart-define-from-file=.local/flutter.local.json -d $phone
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo ejecutar en el telefono.' }
    }
    'Install' {
        $apk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-local-release.apk'
        if (-not (Test-Path -LiteralPath $apk)) { throw 'Genera primero la APK con -Action Build.' }
        $bridge = Get-AndroidBridge
        $phone = Get-Phone $bridge
        & $bridge -s $phone install -r $apk
        if ($LASTEXITCODE -ne 0) { throw 'La instalacion no termino correctamente.' }
        & $bridge -s $phone shell am start -n com.example.menudrawer.local/com.example.menudrawer.MainActivity
        if ($LASTEXITCODE -ne 0) { throw 'Se instalo, pero no se pudo abrir la app.' }
    }
    'Firewall' {
        if (-not (Test-Path -LiteralPath $runtimeFile)) { Invoke-LocalNode 'configure' }
        $runtime = Get-Content -LiteralPath $runtimeFile -Raw | ConvertFrom-Json
        $address = ([Uri]$runtime.apiUrl).Host
        $ruleName = 'RevUp-Local-API-' + $address + '-' + $runtime.apiPort
        if (-not (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -Name $ruleName -DisplayName $ruleName -Direction Inbound -Action Allow `
                -Protocol TCP -LocalPort $runtime.apiPort -LocalAddress $address -RemoteAddress LocalSubnet `
                -Program $node -Profile Any | Out-Null
        }
        Write-Output ('Regla limitada a la subred local: ' + $ruleName)
    }
    'Check' {
        if (-not (Test-Path -LiteralPath $runtimeFile)) { throw 'Ejecuta primero Start.' }
        $runtime = Get-Content -LiteralPath $runtimeFile -Raw | ConvertFrom-Json
        $health = Invoke-RestMethod -Uri ($runtime.apiUrl + '/health') -TimeoutSec 12
        if (-not $health.ok) { throw 'La API no esta lista.' }
        Write-Output ('API y base accesibles desde esta PC: ' + $runtime.apiUrl + '/health')
        Write-Output 'Abre esa misma direccion en el navegador del telefono conectado a la misma red Wi-Fi.'
    }
}
