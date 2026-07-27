import pg from "pg";

export const pool = new pg.Pool({
  user:     process.env.PGUSER,
  password: process.env.PGPASSWORD,
  host:     process.env.PGHOST     || "localhost",
  port:     Number(process.env.PGPORT) || 5432,
  database: process.env.PGDATABASE,
});

// No hay sistema formal de migraciones en este proyecto; los cambios de
// esquema chicos y aditivos (columnas nuevas nullable) se aplican aquí de
// forma idempotente al arrancar el servidor.
export async function ensureSchema() {
  await pool.query(
    `ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS avatar_b64 TEXT`
  );
}
