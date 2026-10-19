# RevUp — Gestión de Taller Automotriz

Repositorio: [drewcrx/RevUp](https://github.com/drewcrx/RevUp).

Aplicación Flutter para Android y web con API Node.js/Express, PostgreSQL,
autenticación JWT y correo SMTP. Gestiona propietarios, vehículos, órdenes
de trabajo, diagnósticos, servicios, repuestos, pagos, fotos, QR e historial.

## Entorno local validado

La aplicación funciona en un Android físico conectado a la misma red que
una PC Windows. La PC ejecuta la API y una instancia PostgreSQL 16 nativa
con datos persistentes. No requiere un VPS para este modo.

Desde esta carpeta:

```powershell
# Primera preparación
npm ci --prefix api/revup-api
flutter pub get
.\tool\local.ps1 -Action Setup

# Cada sesión
.\tool\local.ps1 -Action Start
.\tool\local.ps1 -Action Status
```

Consulta [LOCAL_ANDROID.md](LOCAL_ANDROID.md) para configurar la red y el
firewall, generar e instalar la APK, localizar las credenciales iniciales y
respaldar la base. El correo real requiere Internet.

Para detener los servicios conservando los datos:

```powershell
.\tool\local.ps1 -Action Stop
```

## Código y pruebas

| Ruta | Contenido |
|---|---|
| `lib/` | Aplicación Flutter |
| `api/revup-api/` | API, esquema PostgreSQL y pruebas del backend |
| `tool/` | Lanzador local y herramientas de validación |
| `test/` | Pruebas Flutter |
| `config/production.example.json` | Ejemplo de configuración HTTPS de producción |

```powershell
flutter test
npm test --prefix api/revup-api
node tool/test-local-postgres.mjs
```

El último comando requiere el entorno encendido y usa una base de validación
aislada. Más detalles en [TESTING.md](TESTING.md).

Las pruebas físicas de fotos, QR, PDF y recuperación de contraseña fueron
confirmadas por el usuario el 19/10/2026. Los resultados automáticos están
registrados en [LOCAL_ANDROID.md](LOCAL_ANDROID.md).

## Producción

Las variantes Android `local` y `production` tienen configuración separada;
producción exige HTTPS y firma de publicación. El repositorio incluye
Docker, nginx y Traefik para preparar un futuro despliegue según
[DEPLOY.md](DEPLOY.md).

El workflow está en `.github/workflows/deploy.yml`. Los pushes a `main`
y las pull requests ejecutan pruebas y compilan la web. Publicar imágenes
y desplegar al VPS requiere una ejecución manual con `deploy` activado y
la URL de producción configurada.

Desarrollado por **Andrew Carrera**.
