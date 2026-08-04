import pg from "pg";

export const pool = new pg.Pool({
  user:     process.env.PGUSER,
  password: process.env.PGPASSWORD,
  host:     process.env.PGHOST     || "localhost",
  port:     Number(process.env.PGPORT) || 5432,
  database: process.env.PGDATABASE,
});

// ─── Datos semilla de catálogos ────────────────────────────────────────────
// Listas iniciales, pensadas para ampliarse después (vía Adminer, sin código).
const MARCAS_MODELOS = {
  "Toyota":     ["Corolla", "Yaris", "Hilux", "RAV4", "Fortuner", "Prado", "Land Cruiser"],
  "Chevrolet":  ["Spark", "Aveo", "Sail", "D-Max", "Captiva", "Tracker"],
  "Kia":        ["Rio", "Picanto", "Sportage", "Sorento", "Soluto"],
  "Hyundai":    ["Accent", "i10", "Tucson", "Santa Fe", "Grand i10"],
  "Nissan":     ["Sentra", "Versa", "X-Trail", "Frontier", "Kicks"],
  "Mazda":      ["Mazda 2", "Mazda 3", "CX-3", "CX-5", "BT-50"],
  "Ford":       ["Fiesta", "Focus", "Ranger", "Escape", "EcoSport"],
  "Volkswagen": ["Gol", "Voyage", "Amarok", "Tiguan"],
  "Renault":    ["Sandero", "Logan", "Duster", "Kwid"],
  "Suzuki":     ["Alto", "Swift", "Vitara", "Grand Vitara"],
  "Honda":      ["Civic", "CR-V", "Fit", "HR-V"],
  "Mitsubishi": ["Lancer", "Montero", "L200", "ASX"],
  "Great Wall": ["Wingle", "Haval H6", "Poer"],
  "Chery":      ["Tiggo 2", "Tiggo 7", "Arrizo"],
  "Peugeot":    ["208", "3008", "Partner"],
  "Subaru":     ["Impreza", "Forester", "BRZ", "Outback"],
};

const ITEMS_FLAT = {
  color: ["Blanco", "Negro", "Rojo", "Azul", "Plomo", "Plateado", "Amarillo", "Verde", "Otro"],
  tipo_vehiculo: [
    "Sedán", "Hatchback", "SUV", "Pickup / Camioneta",
    "Coupé", "Van / Minivan", "Camión liviano", "Otro",
  ],
  combustible: ["Gasolina", "Diésel", "Híbrido", "Eléctrico", "GLP", "Otro"],
  transmision: ["Manual", "Automática", "CVT", "Otro"],
};

const REPUESTOS = [
  { nombre: "Aceite de motor",        categoria: "Aceites" },
  { nombre: "Filtro de aceite",       categoria: "Filtros" },
  { nombre: "Filtro de aire",         categoria: "Filtros" },
  { nombre: "Filtro de combustible",  categoria: "Filtros" },
  { nombre: "Filtro de cabina",       categoria: "Filtros" },
  { nombre: "Bujías",                 categoria: "Encendido" },
  { nombre: "Faro delantero",         categoria: "Iluminación" },
  { nombre: "Faro posterior",         categoria: "Iluminación" },
  { nombre: "Pastillas de freno",     categoria: "Frenos" },
  { nombre: "Discos de freno",        categoria: "Frenos" },
  { nombre: "Líquido de frenos",      categoria: "Frenos" },
  { nombre: "Amortiguadores",         categoria: "Suspensión" },
  { nombre: "Batería",                categoria: "Eléctrico" },
  { nombre: "Correa de distribución", categoria: "Correas" },
  { nombre: "Correa de accesorios",   categoria: "Correas" },
  { nombre: "Bomba de agua",          categoria: "Motor" },
  { nombre: "Bomba de combustible",   categoria: "Motor" },
  { nombre: "Radiador",               categoria: "Refrigeración" },
  { nombre: "Sensor de oxígeno",      categoria: "Sensores" },
  { nombre: "Sensor de temperatura",  categoria: "Sensores" },
  { nombre: "Refrigerante",           categoria: "Lubricantes" },
  { nombre: "Aditivo / lubricante",   categoria: "Lubricantes" },
];

// No hay sistema formal de migraciones en este proyecto; los cambios de
// esquema chicos y aditivos (columnas/tablas nuevas nullable) se aplican
// aquí de forma idempotente al arrancar el servidor.
export async function ensureSchema() {
  await pool.query(`ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS avatar_b64 TEXT`);

  // Campos nuevos del vehículo
  await pool.query(`ALTER TABLE vehiculos ADD COLUMN IF NOT EXISTS tipo_combustible TEXT`);
  await pool.query(`ALTER TABLE vehiculos ADD COLUMN IF NOT EXISTS transmision TEXT`);
  await pool.query(`ALTER TABLE vehiculos ADD COLUMN IF NOT EXISTS cilindraje TEXT`);

  // Catálogos: marca → modelo
  await pool.query(`
    CREATE TABLE IF NOT EXISTS catalogo_marcas (
      id SERIAL PRIMARY KEY,
      nombre TEXT UNIQUE NOT NULL,
      activo BOOLEAN NOT NULL DEFAULT true
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS catalogo_modelos (
      id SERIAL PRIMARY KEY,
      marca_id INTEGER NOT NULL REFERENCES catalogo_marcas(id) ON DELETE CASCADE,
      nombre TEXT NOT NULL,
      activo BOOLEAN NOT NULL DEFAULT true,
      UNIQUE(marca_id, nombre)
    )
  `);

  // Catálogos planos (color, tipo de vehículo, combustible, transmisión)
  await pool.query(`
    CREATE TABLE IF NOT EXISTS catalogo_items (
      id SERIAL PRIMARY KEY,
      categoria TEXT NOT NULL,
      valor TEXT NOT NULL,
      orden INTEGER NOT NULL DEFAULT 0,
      activo BOOLEAN NOT NULL DEFAULT true,
      UNIQUE(categoria, valor)
    )
  `);

  // Catálogo de repuestos
  await pool.query(`
    CREATE TABLE IF NOT EXISTS catalogo_repuestos (
      id SERIAL PRIMARY KEY,
      nombre TEXT UNIQUE NOT NULL,
      categoria TEXT,
      activo BOOLEAN NOT NULL DEFAULT true
    )
  `);

  await seedCatalogos();
}

async function seedCatalogos() {
  for (const [marca, modelos] of Object.entries(MARCAS_MODELOS)) {
    const m = await pool.query(
      `INSERT INTO catalogo_marcas (nombre) VALUES ($1)
       ON CONFLICT (nombre) DO UPDATE SET nombre = EXCLUDED.nombre
       RETURNING id`,
      [marca]
    );
    const marcaId = m.rows[0].id;
    for (const modelo of modelos) {
      await pool.query(
        `INSERT INTO catalogo_modelos (marca_id, nombre) VALUES ($1, $2)
         ON CONFLICT (marca_id, nombre) DO NOTHING`,
        [marcaId, modelo]
      );
    }
  }

  for (const [categoria, valores] of Object.entries(ITEMS_FLAT)) {
    for (let i = 0; i < valores.length; i++) {
      await pool.query(
        `INSERT INTO catalogo_items (categoria, valor, orden) VALUES ($1, $2, $3)
         ON CONFLICT (categoria, valor) DO NOTHING`,
        [categoria, valores[i], i]
      );
    }
  }

  for (const r of REPUESTOS) {
    await pool.query(
      `INSERT INTO catalogo_repuestos (nombre, categoria) VALUES ($1, $2)
       ON CONFLICT (nombre) DO NOTHING`,
      [r.nombre, r.categoria]
    );
  }
}
