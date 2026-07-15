# RevUp — Gestión de Taller Automotriz

Aplicación web completa para la gestión digital de vehículos en talleres mecánicos. Permite registrar vehículos, crear órdenes de trabajo, gestionar repuestos y servicios, y generar reportes. Desplegada en VPS con Docker, Traefik y CI/CD automatizado.

## URLs de los servicios

| Servicio | URL | Descripción |
|---|---|---|
| **Frontend** | https://revup.byronrm.com | Aplicación Flutter Web |
| **Backend API** | https://backrevup.byronrm.com | API REST Node.js/Express |
| **Portainer** | https://portainerrevup.byronrm.com | Gestión visual de contenedores |
| **Adminer** | https://pgrevup.byronrm.com | Administrador gráfico PostgreSQL |

## Stack tecnológico

- **Frontend**: Flutter Web → compilado a HTML/JS estático, servido por nginx
- **Backend**: Node.js + Express → API REST con JWT
- **Base de datos**: PostgreSQL 16
- **Proxy inverso**: Traefik v3.3 → SSL automático con Let's Encrypt
- **Gestión de contenedores**: Portainer CE
- **Admin DB**: Adminer
- **Infraestructura**: VPS Contabo Ubuntu 22.04 · `169.58.20.41`
- **CI/CD**: GitHub Actions → GHCR → SSH deploy

## Arquitectura

```
Internet (HTTPS)
      │
      ▼
 Traefik v3.3  ──── :80 redirige a :443 ──── Let's Encrypt SSL
      │
      ├── revup.byronrm.com          → Frontend  (nginx:alpine   :80)
      ├── backrevup.byronrm.com      → Backend   (node:20-alpine :3000)
      ├── portainerrevup.byronrm.com → Portainer (portainer-ce   :9000)
      └── pgrevup.byronrm.com        → Adminer   (adminer        :8080)
                                              │
                              Red backend     │
                              ┌───────────────┘
                              ▼
                         PostgreSQL 16 (:5432)
                         DB: revup
```

### Redes Docker

| Red | Servicios |
|---|---|
| `proxy` | Traefik, Frontend, Backend, Portainer, Adminer |
| `backend` | Backend, Adminer, PostgreSQL |

PostgreSQL **no está expuesto** a la red `proxy` — solo accesible internamente desde Backend y Adminer.

## Esquema de la base de datos

| Tabla | Descripción |
|---|---|
| `usuarios` | Registro, login, verificación de correo, roles |
| `vehiculos` | Vehículos registrados por mecánico |
| `vehiculo_qr` | Tokens QR por vehículo |
| `arreglos` | Historial de reparaciones por vehículo |
| `ordenes_trabajo` | Órdenes de trabajo (OT) |
| `orden_servicios` | Servicios facturados dentro de una OT |
| `orden_repuestos` | Repuestos usados dentro de una OT |
| `orden_pagos` | Pagos registrados en una OT |

## CI/CD — GitHub Actions

El pipeline se activa automáticamente en cada `push` a la rama `main`:

```
git push → main
    │
    ├── 1. flutter pub get + flutter build web --release
    ├── 2. docker build frontend (nginx + build/web) → push ghcr.io/drewcrx/revup-frontend:latest
    ├── 3. docker build backend (node:20-alpine)     → push ghcr.io/drewcrx/revup-backend:latest
    └── 4. SSH al VPS → docker compose pull && docker compose up -d --remove-orphans
```

### Secrets requeridos en GitHub

| Secret | Descripción |
|---|---|
| `VPS_HOST` | IP del VPS |
| `VPS_USER` | Usuario SSH |
| `VPS_PASSWORD` | Contraseña SSH del VPS |

## Primer despliegue manual

```bash
# 1. Instalar Docker en el VPS
curl -fsSL https://get.docker.com | sh

# 2. Clonar el repositorio
git clone https://github.com/drewcrx/RevUp.git /opt/revup
cd /opt/revup

# 3. Crear variables de entorno
cp .env.example .env
nano .env   # completar con valores reales

# 4. Levantar todos los servicios
docker compose up -d --build

# 5. Verificar estado
docker compose ps
```

## Variables de entorno (.env)

```env
ACME_EMAIL=tu@email.com       # Email para certificados Let's Encrypt

PGUSER=usuario_db
PGPASSWORD=contraseña_db
PGDATABASE=revup

JWT_SECRET=cadena_secreta_larga

MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_SECURE=false
MAIL_USER=tu@gmail.com
MAIL_PASS=app_password_gmail
```

## Comandos útiles

```bash
# Ver estado de contenedores
docker compose ps

# Ver logs de un servicio
docker compose logs backend -f --tail=50

# Actualización manual
docker compose pull && docker compose up -d --remove-orphans

# Limpiar imágenes antiguas
docker image prune -f
```

## Registros DNS

4 registros tipo A en el proveedor DNS del dominio:

```
revup.byronrm.com          A  169.58.20.41
backrevup.byronrm.com      A  169.58.20.41
portainerrevup.byronrm.com A  169.58.20.41
pgrevup.byronrm.com        A  169.58.20.41
```

---

Desarrollado por **Andrew Carrera**
