# RevUp — Guía de Despliegue en VPS

## Arquitectura

```
Internet
   │
   ▼
Traefik (puerto 80/443) ── SSL automático con Let's Encrypt
   │
   ├── app.tudominio.com      → Frontend  (Flutter Web / nginx)
   ├── api.tudominio.com      → Backend   (Node.js / Express)
   ├── portainer.tudominio.com → Portainer (gestión de contenedores)
   ├── adminer.tudominio.com  → Adminer   (admin de base de datos)
   └── traefik.tudominio.com  → Dashboard de Traefik
         │
         └── Red interna Docker
               ├── backend  ←→  db (PostgreSQL)
               └── adminer  ←→  db (PostgreSQL)
```

## Servicios y subdominios

| Servicio   | Subdominio              | Descripción                      |
|------------|-------------------------|----------------------------------|
| Frontend   | app.tudominio.com       | Aplicación Flutter Web           |
| Backend    | api.tudominio.com       | API REST Node.js/Express         |
| Portainer  | portainer.tudominio.com | Gestión visual de contenedores   |
| Adminer    | adminer.tudominio.com   | Administrador gráfico PostgreSQL |
| Traefik    | traefik.tudominio.com   | Dashboard del proxy inverso      |

## Requisitos del VPS

- Ubuntu 22.04 o superior
- Al menos 2 GB RAM
- Docker instalado
- Dominio apuntando al IP del VPS (registros DNS tipo A para cada subdominio)

## Instalación de Docker en el VPS

```bash
curl -fsSL https://get.docker.com | sh
usermod -aG docker $USER
newgrp docker
```

## Primer despliegue

```bash
# 1. Clonar el repositorio
git clone https://github.com/drewcrx/RevUp.git /opt/revup
cd /opt/revup

# 2. Crear el archivo de variables de entorno
cp .env.example .env
nano .env   # editar con los valores reales

# 3. Generar la contraseña del dashboard de Traefik
htpasswd -nb admin tupassword
# copiar el resultado en TRAEFIK_AUTH del .env

# 4. Levantar todos los servicios
docker compose up -d --build

# 5. Verificar que todo esté corriendo
docker compose ps
```

## CI/CD con GitHub Actions

El pipeline se activa automáticamente en cada `git push` a `main`.

### Secrets a configurar en GitHub (Settings → Secrets → Actions)

| Secret          | Valor                        |
|-----------------|------------------------------|
| `VPS_HOST`      | IP del VPS (ej: 46.224.5.181)|
| `VPS_USER`      | Usuario SSH (ej: andrew)     |
| `VPS_PASSWORD`  | Contraseña SSH del VPS       |

### Flujo del pipeline

1. **Build backend** → imagen Docker → push a `ghcr.io/drewcrx/revup-backend:latest`
2. **Build frontend** → imagen Docker (Flutter web + nginx) → push a `ghcr.io/drewcrx/revup-frontend:latest`
3. **Deploy** → SSH al VPS → `docker compose pull && docker compose up -d`

## Actualización manual

```bash
cd /opt/revup
git pull origin main
docker compose pull
docker compose up -d --remove-orphans
docker image prune -f
```

## Verificar logs de un servicio

```bash
docker compose logs backend --tail=50 -f
docker compose logs frontend --tail=50
docker compose logs traefik --tail=50
```

## DNS — Registros A necesarios

Crear en tu proveedor de dominio un registro A para cada subdominio apuntando al IP del VPS:

```
app.tudominio.com        A   46.224.5.181
api.tudominio.com        A   46.224.5.181
portainer.tudominio.com  A   46.224.5.181
adminer.tudominio.com    A   46.224.5.181
traefik.tudominio.com    A   46.224.5.181
```
