# RevUp API

API backend para la aplicación **RevUp**, un sistema orientado a la gestión digital de vehículos dentro de talleres mecánicos.

El objetivo principal del proyecto es agilizar el registro, consulta y seguimiento de información vehicular mediante una plataforma digital conectada a una base de datos, reduciendo la dependencia de documentación física y facilitando el acceso rápido al historial de cada vehículo.

---

## Descripción del proyecto

**RevUp** permite administrar información relacionada con vehículos, usuarios y procesos de mantenimiento dentro de un taller mecánico.

El sistema está pensado para que cada vehículo pueda tener un registro digital único, facilitando la consulta de datos como:

- Información del vehículo.
- Historial de mantenimientos.
- Kilometraje.
- Últimos trabajos realizados.
- Mecánico responsable.
- Datos asociados al cliente.
- Control y seguimiento de registros del taller.

---

## Problema que resuelve

En muchos talleres mecánicos tradicionales, la información de los vehículos se maneja en hojas físicas, cuadernos o documentos impresos. Esto puede generar problemas como:

- Pérdida de historiales.
- Dificultad para consultar mantenimientos anteriores.
- Uso excesivo de papel.
- Falta de organización.
- Demoras al buscar información de un vehículo.
- Dependencia de la memoria del mecánico o administrador.

**RevUp** busca digitalizar este proceso para hacerlo más rápido, seguro y ordenado.

---

## Objetivo general

Desarrollar una API backend que permita gestionar la información principal de un taller mecánico, facilitando el registro, actualización y consulta de datos de vehículos, usuarios y mantenimientos.

---

## Objetivos específicos

- Registrar usuarios del sistema.
- Gestionar información de vehículos.
- Consultar datos asociados a cada vehículo.
- Almacenar historial de mantenimientos.
- Facilitar la integración con una aplicación frontend.
- Reducir el uso de documentación física dentro del taller.
- Mejorar la organización de la información del taller.
- Agilizar los tiempos de consulta y trabajo dentro del taller mecánico.

---

## Tecnologías utilizadas

- Node.js
- NestJS
- TypeScript
- PostgreSQL
- TypeORM
- Git
- GitHub

---

## Estructura general del proyecto

```txt
revup-api/
│
├── src/
│   ├── modules/
│   │   ├── auth/
│   │   ├── users/
│   │   ├── vehicles/
│   │   └── ...
│   │
│   ├── database/
│   │   └── migrations/
│   │
│   ├── app.module.ts
│   └── main.ts
│
├── .env.example
├── package.json
├── README.md
└── tsconfig.json