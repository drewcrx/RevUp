# RevUp en un Android físico y una PC Windows

Se ejecuta la aplicación existente, con la misma API, SQL, JWT, fotos,
órdenes, pagos, QR y reportes. No hay un backend de demostración ni datos
ficticios para reemplazar sus funciones.

## Arquitectura y diagnóstico

| Componente | Antes | Presentación local |
|---|---|---|
| Flutter/Dart | URL del VPS fija en `ApiService` | Una configuración generada con `APP_ENV` y `API_BASE_URL` |
| Node/Express | API desplegada con Docker/Traefik | El mismo `server.js`, escuchando en el puerto 3000 |
| PostgreSQL | PostgreSQL 16 del VPS | PostgreSQL 16 nativo, persistente, en el puerto 55432 de loopback |
| Sesión | JWT de 7 días y SharedPreferences | Mismo mecanismo; secretos locales independientes |
| Fotos | Volumen `/app/uploads` | Carpeta persistente `uploads` junto a la base local |
| QR y enlaces de correo | `APP_URL` del VPS | URL de la PC accesible por la Wi-Fi |
| Correo | SMTP configurado en `.env` | Mismo SMTP real, requiere Internet |
| Hosting | VPS, DNS, Traefik, certificados, GHCR | No se necesitan para ejecutar Android y la API local |

El `.env` anterior no se modifica. El lanzador importa exclusivamente sus
variables `MAIL_*`; genera configuración, claves JWT y contraseña PostgreSQL
independientes. `REVUP_ENV_FILE` selecciona el archivo del backend local.
El HTTP local no depende de CORS: Android nativo no aplica esa restricción
del navegador; la API conserva CORS para sus clientes web.

El backend permanece real. Registro, activación y recuperación siguen usando
SMTP, y sus enlaces apuntan a la IP de la PC. Sin Internet funcionan los datos
locales y las cuentas ya activadas, pero no la entrega de correo. No se ha
sustituido el correo por mensajes simulados ni se envían correos al preparar
el entorno.
Si SMTP no está configurado, el envío falla explícitamente y no se imprimen
enlaces de activación o recuperación en los registros.

## Preparación inicial

Necesitas Node 20 o posterior, Flutter y el SDK Android. Abre PowerShell en
la carpeta `menudrawer`:

```powershell
npm ci --prefix api/revup-api
flutter pub get
flutter doctor -v
.\tool\local.ps1 -Action Setup
```

La instalación inicial descarga dependencias, incluidos los binarios de
PostgreSQL. No instala un servicio global ni modifica la instalación antigua
de PostgreSQL. Después puedes repetir las presentaciones sin descargarlos.
Si Flutter solicita licencias, revisa y acepta las necesarias mediante:

```powershell
flutter doctor --android-licenses
```

`Setup` crea únicamente el clúster local nuevo, las tablas de la aplicación y
la cuenta administradora inicial `admin.local`. La cuenta tiene contraseña
aleatoria y hash bcrypt; no cambia la validación de login ni la activación
normal del registro. Su correo se toma del SMTP configurado, cuando existe.
No crea vehículos, clientes, órdenes ni ventas de muestra.

Los datos y las credenciales están en:

```text
%LOCALAPPDATA%\RevUpLocal\<identificador-del-proyecto>\
  postgres\         Base persistente; no borrar
  uploads\          Fotos persistentes
  credentials.json  Claves privadas del entorno
  access.txt        Usuario y contraseña de acceso local
  backend.env       Configuración privada del backend
  api.log           Registro de la API
  api-error.log     Errores de la API
  postgres.log      Registro de PostgreSQL
```

Se guardan fuera de OneDrive. La carpeta `.local` del proyecto contiene la
configuración Flutter y un `runtime.json` con la ruta exacta, sin contraseñas.
Estas carpetas y los archivos privados están excluidos de Git.
No publiques ni compartas `access.txt`, `backend.env` ni `credentials.json`.
El acceso anterior al VPS no se ha importado; los datos nuevos pertenecen
exclusivamente a esta PC. Para recuperar datos históricos hace falta un respaldo.

## Iniciar la API y la base

```powershell
.\tool\local.ps1 -Action Start
.\tool\local.ps1 -Action Status
.\tool\local.ps1 -Action Check
```

`Start` inicia primero PostgreSQL y después la API, en segundo plano y sin
ventanas adicionales. Es idempotente: ejecutarlo de nuevo no crea otro servidor
ni restablece cuentas. `Stop` detiene ambos servicios conservando datos.

Para conocer la carpeta y abrir las credenciales tú mismo:

```powershell
$runtime = Get-Content .local/runtime.json -Raw | ConvertFrom-Json
notepad (Join-Path $runtime.dataRoot 'access.txt')
```

## IP local, Wi-Fi y firewall

El teléfono debe estar en la misma red local que la PC. La PC puede usar
Ethernet y el teléfono Wi-Fi del mismo router. No sirve una red de invitados
con aislamiento entre dispositivos. El lanzador detecta la IP privada del
adaptador físico; si hay varias, indícala:

```powershell
Get-NetIPAddress -AddressFamily IPv4
.\tool\local.ps1 -Action Start -ServerIp 192.168.1.11
```

En esta sesión la IP detectada fue `192.168.1.11`. Puede cambiar con DHCP.
La IP se valida contra los adaptadores de esta PC, evitando `localhost`,
`127.0.0.1` y la dirección de emulador como configuración del teléfono físico.

Abre **PowerShell como administrador** una vez y ejecuta, desde `menudrawer`:

```powershell
.\tool\local.ps1 -Action Firewall
```

La regla permite solo Node, TCP 3000, la IP de la PC y equipos de la subred
local. No desactiva el firewall ni abre PostgreSQL. Usa una red de confianza
para la presentación: el tráfico HTTP local no está cifrado.

En el navegador del teléfono abre la URL que muestra `Start`, por ejemplo:

```text
http://192.168.1.11:3000/health
```

Debe mostrar `{"ok":true}`. Esto comprueba el recorrido teléfono → Wi-Fi →
API → PostgreSQL. Si la base está caída, la API devuelve HTTP 503.
No necesitas abrir puertos del router ni activar reenvío a Internet.

Si cambias de router o la PC recibe otra IP: detén el entorno, vuelve a
iniciarlo con la IP nueva, actualiza la regla de firewall y recompila/reinstala
la APK. Los registros de la base se conservan; los QR nuevos usarán la IP nueva.
Los QR impresos con la IP anterior requieren reimpresión o mantener la IP
de la PC mediante una reserva DHCP en el router.

## Compilar e instalar

```powershell
.\tool\local.ps1 -Action Build
```

El archivo instalable es:

```text
build\app\outputs\flutter-apk\app-local-release.apk
```

La aplicación se llama **RevUp Local** y usa el identificador
`com.example.menudrawer.local`. Puede coexistir con la de producción y tiene
su propio almacenamiento de sesión. La variante local permite HTTP; el
manifiesto principal/producción lo prohíbe. La compilación valida que la
variante Android coincida con `APP_ENV`. La firma de pruebas no sustituye
la clave necesaria para publicar producción.

Activa las opciones de desarrollador y «Depuración USB» en Android. Conecta
el cable y acepta la autorización de la PC en el teléfono. Luego:

```powershell
.\tool\local.ps1 -Action Install
```

`Install` actualiza únicamente la app local, sin borrar su sesión ni sus datos,
y la abre. Para desarrollo con hot reload:

```powershell
.\tool\local.ps1 -Action Run
```

Si hay varios teléfonos, añade `-DeviceId` con el identificador de `adb devices`.
También puedes copiar la APK al teléfono e instalarla manualmente autorizando
esa fuente de instalación. Después de instalarla no necesitas el cable USB
para usarla: sí deben permanecer encendidos la PC y los servicios, en la misma red.

## Prueba funcional con el cliente

1. Abrir `/health` desde el teléfono.
2. Iniciar sesión con `admin.local` y la contraseña de `access.txt`.
3. Crear un propietario y un vehículo reales; consultar y editar sus datos.
4. Abrir el QR del vehículo desde otro dispositivo de la misma red.
5. Crear una OT, añadir diagnóstico, servicios y repuestos.
6. Usar cámara/galería para las fotos de ingreso, daños y avances.
7. Confirmar que la entrega está bloqueada mientras falte cobrar; registrar
   el pago y entregar. Los cargos deben quedar bloqueados tras la entrega.
8. Consultar reportes e historial y probar la impresión/PDF cuando haya una
   aplicación/servicio de impresión instalado en Android.
9. Cerrar sesión, volver a entrar y comprobar la persistencia de registros.
10. Registrar un usuario con un correo real bajo tu control, distinto del de
    la cuenta administradora, activar la cuenta
    y probar recuperación, con acceso a Internet. Esto enviará correos reales.
11. Para borrar, usar únicamente un registro creado expresamente para probar
    esa operación; no eliminar información del cliente.

La cámara, el permiso de galería, la lectura de un QR físico, el visor de PDF
y la entrega final del correo deben comprobarse con sus dispositivos/servicios
reales. Una prueba HTTP por sí sola no certifica esos comportamientos.

## Validación automática

```powershell
flutter test
npm test --prefix api/revup-api
node tool/test-local-postgres.mjs
```

El último comando requiere `Start` y crea una base `revup_validation_<fecha>`
en PostgreSQL real. Prueba CRUD, login, JWT, QR público, fotos, permisos,
pagos, transacciones y contención entre entrega y cargo con varias conexiones.
No utiliza la base de la presentación ni borra bases existentes. La base de
validación queda conservada y su resultado se registra en `last-validation.json`.
El test CRUD elimina solo su propio vehículo de prueba en esa base aislada.

Consulta también `TESTING.md` para pruebas Chrome y los recursos CanvasKit
que requiere el SDK Windows utilizado.

## Detener, reiniciar y respaldar

```powershell
.\tool\local.ps1 -Action Stop
.\tool\local.ps1 -Action Status
```

Detén los servicios antes de apagar la PC o copiar la carpeta completa de
datos. Con los servicios detenidos, puedes respaldar toda la carpeta indicada
por `runtime.json`, incluyendo fotos y claves. Una copia del clúster físico
se restaura con la misma versión mayor de PostgreSQL. No borres carpetas de
datos para solucionar un error de arranque. Si no se reconoce el clúster,
el lanzador falla preservando su contenido.

## Problemas frecuentes

| Síntoma | Comprobación |
|---|---|
| El teléfono no abre `/health` | Misma Wi-Fi, IP actual de la PC, `Start`, firewall y aislamiento del router |
| La PC tampoco abre `/health` | `Status`, `.local/supervisor-error.log`, `api-error.log` y `postgres.log` |
| Puerto ocupado | Detener el otro proceso identificado; no abrir otra base ni borrar datos a ciegas |
| APK apunta a una IP vieja | `Stop`, `Start -ServerIp ...`, `Firewall`, `Build` e `Install` |
| Android bloquea HTTP | Instalar `app-local-release.apk`; producción rechaza HTTP deliberadamente |
| `adb` muestra `unauthorized` | Desbloquear el teléfono y aceptar la depuración USB |
| No aparece un teléfono | Probar un cable de datos, modo USB y el controlador del fabricante |
| Cámara no abre | Permiso Cámara para RevUp Local, cámara disponible y app en primer plano |
| No llega un correo | Internet, configuración SMTP real y carpeta de spam; no se usa el VPS |
| Credenciales correctas rechazadas | Verificar que el teclado no haya insertado espacios dentro de `admin.local`; los campos desactivan sugerencias, pero algunos teclados pueden alterar la entrada |
| Error de ejecución de PowerShell | Usar `powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\local.ps1 -Action Start`; solo afecta ese proceso |
| Licencias/SDK pendientes | Revisar `flutter doctor -v` y `flutter doctor --android-licenses` |

## Resultados comprobados el 19/10/2026

| Verificación | Resultado |
|---|---|
| Flutter: regresión, sesión, formulario y configuración | 22 pruebas aprobadas |
| Node: API, entorno local y error SMTP | 16 pruebas aprobadas |
| API HTTP con PostgreSQL 16 nativo y varias conexiones | 13 pruebas aprobadas en una base aislada |
| Reinicio de PostgreSQL y API | Datos conservados y login real nuevamente correcto |
| Navegador del teléfono → API → base | El usuario confirmó `{"ok":true}` por Wi-Fi |
| APK local | Compilada e instalada en Huawei ANE-LX3, Android 9/API 28 |
| Login/logout en la APK | Comprobados con la cuenta local real |
| Sesión al cerrar y reabrir Android | Conservada; vuelve al dashboard autenticado |
| Navegación Android | Vehículos, formulario y catálogos, órdenes y reportes cargaron |
| Cámara del escáner | Permiso y apertura comprobados; cliente activo confirmado por Android |
| Seguridad de la variante de producción | Manifiesto `productionDebug` generado con `usesCleartextTraffic="false"` |
| SMTP | Conexión y autenticación verificadas sin enviar correos |

El 19/10/2026 el usuario confirmó que todas las pruebas físicas pendientes
funcionan: captura y envío de fotos, lectura de un QR físico,
exportación/impresión PDF y recepción de correos de activación y recuperación.
Con esta confirmación manual, queda completada la validación funcional del
entorno local en el Huawei con la API y PostgreSQL de la PC.

Quedan avisos informativos de APIs Flutter obsoletas y recomendaciones futuras
de actualizar Gradle/AGP/Kotlin; no impidieron generar ni instalar la APK.

## Futuro entorno de producción

Copia `config/production.example.json` a `config/production.json` y establece
la URL HTTPS real. No contiene contraseñas. Compila con:

```powershell
flutter build apk --flavor production --release --dart-define-from-file=config/production.json
flutter build web --release --dart-define-from-file=config/production.json
```

El backend debe tener su propio `.env` o `REVUP_ENV_FILE`, `APP_ENV=production`,
`APP_URL` con esa misma URL HTTPS, PostgreSQL y SMTP de producción y sus propias
claves. Docker toma `APP_URL` del entorno. Traefik/DNS/TLS se configuran para el
host elegido. No copies el archivo privado local ni sus credenciales.
El workflow ya no ejecuta SSH al VPS con un push: el despliegue requiere
activación manual y la variable `REVUP_API_URL` configurada.

PostgreSQL portátil se distribuye mediante
[embedded-postgres](https://github.com/leinelissen/embedded-postgres), fijado
a la versión instalada. Es una instancia PostgreSQL nativa, no PGlite ni una
base en memoria; PGlite se conserva exclusivamente para las pruebas rápidas.
