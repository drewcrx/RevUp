-- Ampliaciones aditivas: conservan órdenes, pagos y vehículos existentes.
ALTER TABLE vehiculos ADD COLUMN IF NOT EXISTS archivado BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE ordenes_trabajo ADD COLUMN IF NOT EXISTS fase TEXT;
UPDATE ordenes_trabajo SET fase = CASE
  WHEN estado = 'ENTREGADO' THEN 'ENTREGADO'
  WHEN estado = 'PENDIENTE' THEN 'EN_PROCESO' ELSE 'RECIBIDO' END WHERE fase IS NULL;
ALTER TABLE ordenes_trabajo ALTER COLUMN fase SET DEFAULT 'RECIBIDO';
ALTER TABLE orden_pagos ADD COLUMN IF NOT EXISTS operacion_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS orden_pago_operacion ON orden_pagos(orden_id, operacion_id);
CREATE TABLE IF NOT EXISTS orden_checklists (
  id SERIAL PRIMARY KEY,
  orden_id INTEGER NOT NULL REFERENCES ordenes_trabajo(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL CHECK (tipo IN ('ingreso', 'entrega')),
  combustible INTEGER CHECK (combustible BETWEEN 0 AND 100),
  accesorios TEXT NOT NULL DEFAULT '',
  observaciones TEXT NOT NULL DEFAULT '',
  revision_danos TEXT NOT NULL DEFAULT 'PENDIENTE'
    CHECK (revision_danos IN ('PENDIENTE', 'SIN_DANOS', 'CON_DANOS')),
  revisado BOOLEAN NOT NULL DEFAULT false,
  autor_id INTEGER NOT NULL REFERENCES usuarios(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(orden_id, tipo)
);
CREATE TABLE IF NOT EXISTS orden_anotaciones (
  id SERIAL PRIMARY KEY,
  orden_id INTEGER NOT NULL REFERENCES ordenes_trabajo(id) ON DELETE CASCADE,
  autor_id INTEGER NOT NULL REFERENCES usuarios(id),
  clase TEXT NOT NULL DEFAULT 'NOTA',
  texto TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS inventario (
  id SERIAL PRIMARY KEY,
  mechanic_id INTEGER NOT NULL REFERENCES usuarios(id),
  nombre TEXT NOT NULL,
  sku TEXT NOT NULL,
  existencias INTEGER NOT NULL DEFAULT 0 CHECK (existencias >= 0),
  minimo INTEGER NOT NULL DEFAULT 0 CHECK (minimo >= 0),
  costo NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (costo >= 0),
  precio NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (precio >= 0),
  activo BOOLEAN NOT NULL DEFAULT true,
  UNIQUE(mechanic_id, sku)
);
ALTER TABLE orden_repuestos ADD COLUMN IF NOT EXISTS inventario_id INTEGER REFERENCES inventario(id);
CREATE TABLE IF NOT EXISTS inventario_movimientos (
  id SERIAL PRIMARY KEY,
  inventario_id INTEGER NOT NULL REFERENCES inventario(id),
  orden_id INTEGER REFERENCES ordenes_trabajo(id),
  autor_id INTEGER NOT NULL REFERENCES usuarios(id),
  cantidad INTEGER NOT NULL CHECK (cantidad <> 0),
  motivo TEXT NOT NULL,
  operacion_id TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS recordatorios (
  id SERIAL PRIMARY KEY,
  vehiculo_id INTEGER NOT NULL REFERENCES vehiculos(id),
  mechanic_id INTEGER NOT NULL REFERENCES usuarios(id),
  titulo TEXT NOT NULL,
  fecha DATE,
  kilometraje INTEGER CHECK (kilometraje > 0),
  completado BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (fecha IS NOT NULL OR kilometraje IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS recordatorios_pendientes ON recordatorios(mechanic_id, completado, fecha);
