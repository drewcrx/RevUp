// routes/catalogos.js — listas desplegables (marca/modelo, color, tipo de
// vehículo, combustible, transmisión, repuestos) para no escribir texto
// libre en el ingreso de vehículos y OTs. Editable desde Adminer, sin
// necesidad de tocar código ni desplegar de nuevo.
import express from "express";
import { pool } from "../db/connection.js";
import { requireAuth } from "../src/middleware/auth.js";

const router = express.Router();
router.use(requireAuth);

const CATEGORIAS_VALIDAS = new Set([
  "color", "tipo_vehiculo", "combustible", "transmision",
  "estado_dano", "tipo_reparacion",
]);

// GET /catalogos/marcas
router.get("/marcas", async (_req, res) => {
  try {
    const q = await pool.query(
      `SELECT id, nombre FROM catalogo_marcas WHERE activo = true ORDER BY nombre ASC`
    );
    res.json(q.rows);
  } catch (error) {
    res.status(500).json({ error: "Error al obtener marcas", detalle: error.message });
  }
});

// GET /catalogos/marcas/:id/modelos
router.get("/marcas/:id/modelos", async (req, res) => {
  const marcaId = Number(req.params.id);
  if (!Number.isFinite(marcaId)) return res.status(400).json({ error: "id inválido" });

  try {
    const q = await pool.query(
      `SELECT id, nombre FROM catalogo_modelos
       WHERE marca_id = $1 AND activo = true
       ORDER BY nombre ASC`,
      [marcaId]
    );
    res.json(q.rows);
  } catch (error) {
    res.status(500).json({ error: "Error al obtener modelos", detalle: error.message });
  }
});

// GET /catalogos/items/:categoria  (color | tipo_vehiculo | combustible | transmision)
router.get("/items/:categoria", async (req, res) => {
  const categoria = String(req.params.categoria || "");
  if (!CATEGORIAS_VALIDAS.has(categoria)) {
    return res.status(400).json({ error: "categoría inválida" });
  }

  try {
    const q = await pool.query(
      `SELECT id, valor FROM catalogo_items
       WHERE categoria = $1 AND activo = true
       ORDER BY orden ASC, valor ASC`,
      [categoria]
    );
    res.json(q.rows);
  } catch (error) {
    res.status(500).json({ error: "Error al obtener catálogo", detalle: error.message });
  }
});

// GET /catalogos/repuestos?q=texto
router.get("/repuestos", async (req, res) => {
  const q = String(req.query.q || "").trim();

  try {
    const params = [];
    let where = "WHERE activo = true";
    if (q) {
      params.push(`%${q}%`);
      where += ` AND nombre ILIKE $${params.length}`;
    }

    const result = await pool.query(
      `SELECT id, nombre, categoria FROM catalogo_repuestos
       ${where}
       ORDER BY nombre ASC
       LIMIT 50`,
      params
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: "Error al obtener repuestos", detalle: error.message });
  }
});

export default router;
