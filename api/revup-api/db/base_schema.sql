-- Esquema inicial. IF NOT EXISTS conserva los datos de instalaciones existentes.
CREATE TABLE IF NOT EXISTS usuarios (
  id SERIAL PRIMARY KEY,
  nombre TEXT NOT NULL,
  correo TEXT UNIQUE NOT NULL,
  usuario TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'mechanic' CHECK (role IN ('mechanic', 'superuser')),
  verificado BOOLEAN NOT NULL DEFAULT false,
  verificacion_token_hash TEXT,
  verificacion_expires TIMESTAMPTZ,
  verificado_en TIMESTAMPTZ,
  reset_token_hash TEXT,
  reset_expires TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vehiculos (
  id SERIAL PRIMARY KEY,
  marca TEXT NOT NULL,
  modelo TEXT NOT NULL,
  placa TEXT UNIQUE NOT NULL,
  kilometraje INTEGER NOT NULL DEFAULT 0 CHECK (kilometraje >= 0),
  ultima_visita DATE,
  mechanic_id INTEGER NOT NULL REFERENCES usuarios(id),
  anio INTEGER,
  color TEXT,
  propietario_nombre TEXT,
  propietario_telefono TEXT,
  nota_ingreso TEXT,
  tipo_vehiculo TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vehiculo_qr (
  id SERIAL PRIMARY KEY,
  vehiculo_id INTEGER NOT NULL REFERENCES vehiculos(id) ON DELETE CASCADE,
  qr_token TEXT UNIQUE NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS arreglos (
  id SERIAL PRIMARY KEY,
  vehiculo_placa TEXT NOT NULL REFERENCES vehiculos(placa) ON DELETE CASCADE,
  descripcion TEXT NOT NULL,
  tipo TEXT,
  fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completado BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS ordenes_trabajo (
  id SERIAL PRIMARY KEY,
  placa TEXT NOT NULL REFERENCES vehiculos(placa) ON DELETE CASCADE,
  mechanic_id INTEGER NOT NULL REFERENCES usuarios(id),
  usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
  symptoms TEXT NOT NULL,
  estado TEXT NOT NULL DEFAULT 'RECIBIDO'
    CHECK (estado IN ('RECIBIDO', 'PENDIENTE', 'ENTREGADO')),
  pago_estado TEXT NOT NULL DEFAULT 'PENDIENTE'
    CHECK (pago_estado IN ('PENDIENTE', 'PAGADO')),
  total_servicios NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_repuestos NUMERIC(12,2) NOT NULL DEFAULT 0,
  total NUMERIC(12,2) NOT NULL DEFAULT 0,
  kilometraje_ot INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS orden_servicios (
  id SERIAL PRIMARY KEY,
  orden_id INTEGER NOT NULL REFERENCES ordenes_trabajo(id) ON DELETE CASCADE,
  descripcion TEXT NOT NULL,
  precio NUMERIC(12,2) NOT NULL CHECK (precio >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS orden_repuestos (
  id SERIAL PRIMARY KEY,
  orden_id INTEGER NOT NULL REFERENCES ordenes_trabajo(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  cantidad INTEGER NOT NULL CHECK (cantidad > 0),
  costo_unitario NUMERIC(12,2) NOT NULL CHECK (costo_unitario >= 0),
  precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS orden_pagos (
  id SERIAL PRIMARY KEY,
  orden_id INTEGER NOT NULL REFERENCES ordenes_trabajo(id) ON DELETE CASCADE,
  monto NUMERIC(12,2) NOT NULL CHECK (monto > 0),
  metodo TEXT NOT NULL DEFAULT 'EFECTIVO',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
