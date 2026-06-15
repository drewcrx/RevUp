# RevUp

**RevUp** es una aplicación desarrollada en Flutter para la gestión digital de vehículos en talleres mecánicos. El proyecto busca facilitar el registro, consulta y seguimiento de información vehicular mediante una solución moderna conectada a un backend y una base de datos.

Su propósito principal es reducir el uso de documentación física en talleres, mejorar la organización del historial de los vehículos y agilizar el trabajo de administradores y mecánicos.

---

## Descripción del proyecto

RevUp permite administrar información relacionada con vehículos, usuarios, órdenes de trabajo, reportes y procesos internos de un taller mecánico.

La aplicación está pensada para que el taller pueda consultar datos importantes de cada vehículo, como información general, mantenimientos realizados, kilometraje, órdenes asociadas y registros relevantes para el seguimiento del servicio.

---

## Problema que resuelve

En muchos talleres mecánicos, la información de los vehículos todavía se maneja mediante hojas físicas, cuadernos o documentos impresos. Esto puede provocar pérdida de información, desorganización, demoras en la atención y dificultad para consultar trabajos anteriores.

RevUp propone una solución digital que centraliza la información del taller y permite acceder a los datos de forma rápida, ordenada y segura.

---

## Objetivo general

Desarrollar una aplicación para la gestión digital de vehículos en talleres mecánicos, permitiendo registrar, consultar y actualizar información relacionada con usuarios, vehículos, órdenes de trabajo y reportes.

---

## Objetivos específicos

* Registrar y gestionar usuarios del sistema.
* Registrar información de vehículos.
* Consultar datos asociados a cada vehículo.
* Gestionar órdenes de trabajo.
* Generar y consultar reportes.
* Organizar la información del taller de forma digital.
* Reducir la dependencia de documentos físicos.
* Agilizar los procesos internos del taller mecánico.

---

## Funcionalidades principales

* Inicio de sesión de usuarios.
* Registro de usuarios.
* Gestión de vehículos.
* Consulta de información vehicular.
* Gestión de órdenes de trabajo.
* Generación de reportes.
* Conexión con backend.
* Integración con base de datos.
* Interfaz desarrollada en Flutter.
* Soporte para múltiples plataformas mediante Flutter.

---

## Tecnologías utilizadas

### Frontend

* Flutter
* Dart

### Backend

* Node.js
* Express.js

### Base de datos

* PostgreSQL

### Dependencias principales

* http
* shared_preferences
* image_picker
* qr_flutter
* mobile_scanner
* pdf
* printing
* bcrypt
* cors
* dotenv
* express
* jsonwebtoken
* nodemailer
* pg

---

## Estructura del proyecto

```txt
RevUp/
│
├── android/
├── ios/
├── lib/
│   ├── main.dart
│   └── src/
│
├── web/
├── windows/
├── linux/
├── macos/
│
├── assets/
├── fonts/
├── images/
│
├── api/
│   └── backfire-api/
│       ├── db/
│       ├── routes/
│       ├── src/
│       │   └── middleware/
│       ├── utils/
│       ├── server.js
│       └── package.json
│
├── pubspec.yaml
├── package.json
├── README.md
└── .gitignore
```

> Nota: aunque la carpeta del backend conserve el nombre `backfire-api`, el nombre oficial del proyecto es **RevUp**.

---

## Instalación del proyecto

Clonar el repositorio:

```bash
git clone https://github.com/drewcrx/RevUp.git
```

Entrar a la carpeta del proyecto:

```bash
cd RevUp
```

---

## Ejecución del frontend

Instalar las dependencias de Flutter:

```bash
flutter pub get
```

Ejecutar la aplicación:

```bash
flutter run
```

Para ejecutar en navegador:

```bash
flutter run -d chrome
```

---

## Ejecución del backend

Entrar a la carpeta del backend:

```bash
cd api/backfire-api
```

Instalar dependencias:

```bash
npm install
```

Ejecutar el servidor en modo desarrollo:

```bash
npm run dev
```

O ejecutar en modo normal:

```bash
npm start
```

Por defecto, el backend se ejecuta en:

```txt
http://localhost:3000
```

---

## Endpoints principales del backend

El backend cuenta con rutas principales para:

```txt
/health
/vehiculos
/usuarios
/ordenes
/reportes
```

La ruta de prueba del servidor es:

```txt
GET /health
```

---

## Variables de entorno

El backend utiliza variables de entorno para configurar datos sensibles como el puerto, conexión a base de datos y claves privadas.

Crear un archivo `.env` dentro de:

```txt
api/backfire-api/
```

Ejemplo:

```env
PORT=3000

DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=tu_password
DB_NAME=revup

JWT_SECRET=tu_clave_secreta
```

> Importante: el archivo `.env` no debe subirse al repositorio.

---

## Base de datos

El proyecto utiliza PostgreSQL como sistema de base de datos.

Crear la base de datos:

```sql
CREATE DATABASE revup;
```

Luego configurar las credenciales correspondientes en el archivo `.env` del backend.

---

## Flujo general del sistema

1. El usuario inicia sesión en la aplicación.
2. El sistema valida sus credenciales.
3. El usuario accede a las funcionalidades disponibles.
4. Se registra o consulta información de vehículos.
5. Se gestionan órdenes de trabajo y reportes.
6. La información queda almacenada en la base de datos.

---

## Roles principales

### Administrador

Usuario encargado de gestionar información general del sistema, usuarios, vehículos, órdenes y reportes del taller.

### Mecánico

Usuario encargado de consultar información vehicular y registrar datos relacionados con los trabajos realizados.

---

## Estado del proyecto

Proyecto en desarrollo, orientado a la digitalización de procesos en talleres mecánicos mediante una aplicación móvil/frontend conectada a un backend.

---

## Autor

**Andrew Carrera**
Estudiante de Desarrollo de Software

---

## Repositorio

```txt
https://github.com/drewcrx/RevUp.git
```
