# Pruebas de RevUp

Desde esta carpeta:

```powershell
flutter pub get
flutter test
flutter test --platform chrome
flutter build web --release
```

Flutter comprueba sesión persistida y expirada, redirección por HTTP 401,
validación del login, subidas multipart desde bytes y recuperación del
formulario de vehículos ante desconexión y tiempo de espera agotado.
Las peticiones se simulan: estas pruebas no usan cuentas ni servicios remotos.

En Windows con Flutter 3.44, si Chrome queda esperando y CanvasKit responde
404, prepara sus recursos locales antes de ejecutar las pruebas web:

```powershell
.\tool\prepare_web_tests.ps1
flutter test --platform chrome
```

El script copia cuatro archivos del SDK a `test/canvaskit` (ignorado por Git).
No cambia el SDK. En Linux no hace falta esta preparación.

Para el backend (Node 20 o posterior):

```powershell
cd api/revup-api
npm ci
npm test
npm audit
```

Las pruebas ejecutan la API por HTTP contra PostgreSQL en memoria (PGlite).
No conectan a la base indicada en `.env`. Cubren creación del esquema vacío,
repetición sin borrar datos, permisos entre mecánicos y superuser, cargos,
pagos y entrega, reversión de transacciones, fotos, autenticación y salud
del servidor. Las fotos de prueba quedan en una carpeta temporal del sistema.
PGlite utiliza una conexión; comprobar contención con múltiples conexiones
y realizar pruebas de carga requiere una instancia PostgreSQL independiente.

Al arrancar, el servidor crea las tablas iniciales que falten y ejecuta las
ampliaciones existentes. Si falla, termina con error sin abrir el puerto.
`/health` responde HTTP 503 cuando la conexión con la base no está disponible.
Los registros existentes se conservan. Las nuevas cuentas siguen teniendo
el rol `mechanic`; el esquema no crea usuarios ni contraseñas iniciales.

El workflow de GitHub ejecuta las pruebas Flutter y backend y compila la web
en los pushes a `main` y las pull requests. La publicación de imágenes y el
despliegue al VPS requieren una ejecución manual con `deploy` activado.

Para Android físico, la API y PostgreSQL nativo en esta PC, consulta
[LOCAL_ANDROID.md](LOCAL_ANDROID.md). La validación adicional
`node tool/test-local-postgres.mjs` usa una base real aislada y permite probar
contención con varias conexiones, además de las pruebas rápidas con PGlite.
