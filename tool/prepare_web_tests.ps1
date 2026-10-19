$ErrorActionPreference = 'Stop'
$flutterCommand = Get-Command flutter
$flutterRoot = Split-Path (Split-Path $flutterCommand.Source -Parent) -Parent
$sourceRoot = Join-Path $flutterRoot 'bin\cache\flutter_web_sdk\canvaskit'
$projectRoot = Split-Path $PSScriptRoot -Parent
$targetRoot = Join-Path $projectRoot 'test\canvaskit'

# Flutter 3.44 en Windows no reconoce la ruta de CanvasKit en su handler.
# Su servidor sí permite leer estos mismos archivos desde la carpeta test.
foreach ($relative in @('canvaskit.js', 'canvaskit.wasm', 'chromium\canvaskit.js', 'chromium\canvaskit.wasm')) {
    $source = Join-Path $sourceRoot $relative
    $target = Join-Path $targetRoot $relative
    if (-not (Test-Path -LiteralPath $source)) { throw "Falta el recurso del SDK: $source" }
    New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Force
}
Write-Output 'CanvasKit listo para las pruebas Chrome.'
