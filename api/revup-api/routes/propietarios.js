// routes/propietarios.js — propietarios normalizados (1 propietario -> N
// vehículos). Compartido entre todos los mecánicos: un mismo cliente puede
// traer distintos autos a distintos mecánicos del taller, así que la
// búsqueda no se filtra por mechanic_id (a diferencia de /vehiculos).
import express from "express";
import { pool } from "../db/connection.js";
import { requireAuth } from "../src/middleware/auth.js";

const router = express.Router();
router.use(requireAuth);

function isSuper(req) {
  return req.user?.role === "superuser";
}

// ¿Este mecánico ya atendió algún vehículo de este propietario? Se usa
// para decidir si puede ver/editar sus datos de contacto completos, o
// solo lo mínimo para no crear un registro duplicado.
async function tieneRelacion(propietarioId, user) {
  if (isSuper({ user })) return true;
  const q = await pool.query(
    `SELECT 1 FROM vehiculos WHERE propietario_id = $1 AND mechanic_id = $2 LIMIT 1`,
    [propietarioId, user.id]
  );
  return q.rowCount > 0;
}

// GET /propietarios?q=texto — buscar por nombre o teléfono (para elegir un
// propietario existente al registrar un vehículo, evitando duplicados).
// No incluye cédula/email: eso solo se ve en el detalle, y solo si el
// mecánico ya tiene una relación real con ese propietario.
router.get("/", async (req, res) => {
  const q = String(req.query.q || "").trim();

  try {
    const params = [];
    let where = "";
    if (q) {
      params.push(`%${q}%`);
      where = `WHERE p.nombre ILIKE $1 OR p.telefono ILIKE $1`;
    }

    const result = await pool.query(
      `SELECT p.id, p.nombre, p.telefono,
              COUNT(v.id) AS vehiculos_count
       FROM propietarios p
       LEFT JOIN vehiculos v ON v.propietario_id = p.id
       ${where}
       GROUP BY p.id
       ORDER BY p.nombre ASC
       LIMIT 30`,
      params
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: "Error al buscar propietarios", detalle: error.message });
  }
});

// GET /propietarios/:id — detalle + vehículos asociados. El detalle
// completo (teléfono/cédula/email) solo se entrega si el mecánico ya
// atendió un vehículo de este propietario, o es superuser.
router.get("/:id", async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ error: "id inválido" });

  try {
    const p = await pool.query(
      `SELECT id, nombre, telefono, cedula, email FROM propietarios WHERE id = $1`,
      [id]
    );
    if (p.rowCount === 0) return res.status(404).json({ error: "Propietario no encontrado" });

    const vParams = [id];
    let vExtra = "";
    if (!isSuper(req)) {
      vParams.push(req.user.id);
      vExtra = " AND v.mechanic_id = $2";
    }

    const vehiculos = await pool.query(
      `SELECT v.placa, v.marca, v.modelo, v.anio, v.color
       FROM vehiculos v
       WHERE v.propietario_id = $1
       ${vExtra}
       ORDER BY v.placa ASC`,
      vParams
    );

    const relacionado = isSuper(req) || vehiculos.rowCount > 0;
    const propietario = { ...p.rows[0] };
    if (!relacionado) {
      propietario.telefono = null;
      propietario.cedula = null;
      propietario.email = null;
    }

    res.json({ ...propietario, vehiculos: vehiculos.rows, relacionado });
  } catch (error) {
    res.status(500).json({ error: "Error al obtener propietario", detalle: error.message });
  }
});

// POST /propietarios — crear
router.post("/", async (req, res) => {
  const b = req.body || {};
  const nombre = String(b.nombre || "").trim();
  if (!nombre) return res.status(400).json({ error: "El nombre es obligatorio" });

  const telefono = b.telefono ? String(b.telefono).trim() : null;
  const cedula = b.cedula ? String(b.cedula).trim() : null;
  const email = b.email ? String(b.email).trim() : null;

  try {
    const q = await pool.query(
      `INSERT INTO propietarios (nombre, telefono, cedula, email)
       VALUES ($1, $2, $3, $4)
       RETURNING id, nombre, telefono, cedula, email`,
      [nombre, telefono, cedula, email]
    );
    res.status(201).json(q.rows[0]);
  } catch (error) {
    res.status(500).json({ error: "Error al crear propietario", detalle: error.message });
  }
});

// PUT /propietarios/:id — editar (se refleja en todos sus vehículos)
router.put("/:id", async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ error: "id inválido" });

  const b = req.body || {};
  const sets = [];
  const params = [];
  let idx = 1;
  function addSet(col, val) {
    sets.push(`${col} = $${idx++}`);
    params.push(val);
  }

  if (b.nombre !== undefined) {
    const nombre = String(b.nombre || "").trim();
    if (!nombre) return res.status(400).json({ error: "El nombre no puede quedar vacío" });
    addSet("nombre", nombre);
  }
  if (b.telefono !== undefined) addSet("telefono", b.telefono ? String(b.telefono).trim() : null);
  if (b.cedula !== undefined) addSet("cedula", b.cedula ? String(b.cedula).trim() : null);
  if (b.email !== undefined) addSet("email", b.email ? String(b.email).trim() : null);

  if (sets.length === 0) return res.status(400).json({ error: "No hay campos para actualizar" });

  try {
    if (!(await tieneRelacion(id, req.user))) {
      return res.status(403).json({ error: "No puedes editar un propietario con el que no tienes vehículos en común" });
    }

    params.push(id);
    const q = await pool.query(
      `UPDATE propietarios SET ${sets.join(", ")} WHERE id = $${idx} RETURNING id, nombre, telefono, cedula, email`,
      params
    );
    if (q.rowCount === 0) return res.status(404).json({ error: "Propietario no encontrado" });
    res.json(q.rows[0]);
  } catch (error) {
    res.status(500).json({ error: "Error al actualizar propietario", detalle: error.message });
  }
});

export default router;
