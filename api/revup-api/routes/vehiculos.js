// vehiculos.js (COMPLETO) — privado por mecánico + superuser ve todo
import express from "express";
import { pool } from "../db/connection.js";
import crypto from "crypto";
import { requireAuth } from "../src/middleware/auth.js";

const router = express.Router();
router.use(requireAuth);

// ===========================
// Helpers de seguridad / scope
// ===========================
function isSuper(req) {
  return req.user?.role === "superuser";
}

async function ensureVehiculoOwnedByUserOr404(req, placaNorm) {
  const params = [placaNorm];
  let extra = "";

  if (!isSuper(req)) {
    params.push(req.user.id);
    extra = " AND mechanic_id = $2";
  }

  const v = await pool.query(
    `SELECT id, placa, mechanic_id
     FROM vehiculos
     WHERE placa = $1
     ${extra}
     LIMIT 1`,
    params
  );

  return v.rowCount ? v.rows[0] : null;
}

// Resuelve un propietario a partir de texto libre (nombre/telefono),
// reutilizando uno existente si ya hay un registro con el mismo
// nombre+telefono (evita duplicados cuando distintos mecánicos escriben
// al mismo cliente).
async function findOrCreatePropietario(nombre, telefono) {
  if (!nombre) return null;
  const existente = await pool.query(
    `SELECT id FROM propietarios WHERE nombre = $1 AND telefono IS NOT DISTINCT FROM $2 LIMIT 1`,
    [nombre, telefono]
  );
  if (existente.rowCount > 0) return existente.rows[0].id;

  const ins = await pool.query(
    `INSERT INTO propietarios (nombre, telefono) VALUES ($1, $2) RETURNING id`,
    [nombre, telefono]
  );
  return ins.rows[0].id;
}

async function ensureVehiculoByQrOwnedOr404(req, token) {
  const params = [token];
  let extra = "";

  if (!isSuper(req)) {
    params.push(req.user.id);
    extra = " AND v.mechanic_id = $2";
  }

  const q = await pool.query(
    `SELECT v.id, v.placa
     FROM vehiculos v
     JOIN vehiculo_qr q ON q.vehiculo_id = v.id
     WHERE q.qr_token = $1 AND q.activo = true
     ${extra}
     LIMIT 1`,
    params
  );

  return q.rowCount ? q.rows[0] : null;
}

// ===========================
// ✅ QR: Detalle + pendientes/recientes (privado)
// (IMPORTANTE: DEBE IR ANTES DE "/:placa")
// ===========================
router.get("/qr/:token", async (req, res) => {
  const token = String(req.params.token || "").trim();
  if (!token) return res.status(400).json({ error: "token inválido" });

  try {
    const veh = await ensureVehiculoByQrOwnedOr404(req, token);
    if (!veh) return res.status(404).json({ error: "QR no válido o no activo" });

    const vehiculoRes = await pool.query(
      `SELECT v.id, v.marca, v.modelo, v.placa, v.kilometraje, v.ultima_visita,
              v.anio, v.color, v.nota_ingreso, v.tipo_vehiculo,
              p.id AS propietario_id, p.nombre AS propietario_nombre, p.telefono AS propietario_telefono,
              q.qr_token
       FROM vehiculos v
       JOIN vehiculo_qr q ON q.vehiculo_id = v.id
       LEFT JOIN propietarios p ON p.id = v.propietario_id
       WHERE q.qr_token = $1 AND q.activo = true
       LIMIT 1`,
      [token]
    );

    res.json({
      vehiculo: vehiculoRes.rows[0],
    });
  } catch (error) {
    res.status(500).json({ error: "Error buscando por QR", detalle: error.message });
  }
});

// ===========================
// ✅ QR: historial completo (privado)
// ===========================
router.get("/qr/:token/historial", async (req, res) => {
  const token = String(req.params.token || "").trim();
  if (!token) return res.status(400).json({ error: "token inválido" });

  try {
    const veh = await ensureVehiculoByQrOwnedOr404(req, token);
    if (!veh) return res.status(404).json({ error: "QR no válido o no activo" });

    const placa = veh.placa;

    const historialRes = await pool.query(
      `SELECT id, descripcion, tipo, fecha, completado
       FROM arreglos
       WHERE vehiculo_placa = $1
       ORDER BY fecha DESC`,
      [placa]
    );

    res.json({ historial: historialRes.rows });
  } catch (error) {
    res.status(500).json({ error: "Error obteniendo historial", detalle: error.message });
  }
});

// ===========================
// ✅ QR: OTs del vehículo (privado)
// GET /vehiculos/qr/:token/ots
// ===========================
router.get("/qr/:token/ots", async (req, res) => {
  const token = String(req.params.token || "").trim();
  if (!token) return res.status(400).json({ error: "token inválido" });

  try {
    const veh = await ensureVehiculoByQrOwnedOr404(req, token);
    if (!veh) return res.status(404).json({ error: "QR no válido o no activo" });

    const placa = String(veh.placa || "").trim().toUpperCase();
    if (!placa) return res.status(500).json({ error: "Vehículo sin placa" });

    const params = [placa];
    let extra = "";

    if (!isSuper(req)) {
      params.push(req.user.id);
      extra = ` AND mechanic_id = $${params.length}`;
    }

    const q = await pool.query(
      `
      SELECT
        id, placa, mechanic_id, usuario_id, symptoms,
        estado, pago_estado,
        total_servicios, total_repuestos, total,
        kilometraje_ot,
        created_at, closed_at, 
        CASE
          WHEN estado = 'ENTREGADO' THEN 'ENTREGADO'
          WHEN estado = 'RECIBIDO'
               AND (COALESCE(total_servicios,0) > 0
                    OR COALESCE(total_repuestos,0) > 0
                    OR COALESCE(total,0) > 0)
            THEN 'PENDIENTE'
          ELSE estado
        END AS estado_ui
      FROM ordenes_trabajo
      WHERE placa = $1
      ${extra}
      ORDER BY created_at DESC
      `,
      params
    );

    return res.json(q.rows);
  } catch (error) {
    return res.status(500).json({ error: "Error obteniendo OTs por QR", detalle: error.message });
  }
});

// ===========================
// GET TODOS LOS VEHÍCULOS (privado)
// ===========================
router.get("/", async (req, res) => {
  try {
    const params = [];
    let where = "WHERE 1=1";

    if (!isSuper(req)) {
      params.push(req.user.id);
      where += ` AND v.mechanic_id = $${params.length}`;
    }

    const sql = `
      SELECT v.*, q.qr_token,
             p.id AS propietario_id, p.nombre AS propietario_nombre, p.telefono AS propietario_telefono
      FROM vehiculos v
      LEFT JOIN vehiculo_qr q
        ON q.vehiculo_id = v.id AND q.activo = true
      LEFT JOIN propietarios p ON p.id = v.propietario_id
      ${where}
      ORDER BY v.placa ASC
    `;

    const result = await pool.query(sql, params);
    res.json(Array.isArray(result.rows) ? result.rows : []);
  } catch (error) {
    res.status(500).json({ error: "Error al obtener vehículos", detalle: error.message });
  }
});

// ===========================
// GET VEHÍCULO POR PLACA (privado)
// ===========================
router.get("/:placa", async (req, res) => {
  const placa = String(req.params.placa || "").trim().toUpperCase();
  if (!placa) return res.status(400).json({ error: "placa inválida" });

  try {
    const params = [placa];
    let extra = "";

    if (!isSuper(req)) {
      params.push(req.user.id);
      extra = " AND v.mechanic_id = $2";
    }

    const result = await pool.query(
      `SELECT v.*, q.qr_token,
              p.id AS propietario_id, p.nombre AS propietario_nombre, p.telefono AS propietario_telefono,
              p.cedula AS propietario_cedula, p.email AS propietario_email
       FROM vehiculos v
       LEFT JOIN vehiculo_qr q ON q.vehiculo_id = v.id AND q.activo = true
       LEFT JOIN propietarios p ON p.id = v.propietario_id
       WHERE v.placa = $1
       ${extra}
       LIMIT 1`,
      params
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Vehículo no encontrado" });
    }

    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: "Error al obtener el vehículo", detalle: error.message });
  }
});

// ===========================
// POST AGREGAR VEHÍCULO (privado)
// ===========================
router.post("/", async (req, res) => {
  const b = req.body || {};

  if (!b.marca || !b.modelo || !b.placa) {
    return res.status(400).json({ error: "Datos faltantes" });
  }

  const marca = String(b.marca).trim();
  const modelo = String(b.modelo).trim();
  const placa = String(b.placa).trim().toUpperCase();

  const kilometraje = b.kilometraje ?? null;
  const ultima_visita = b.ultima_visita ?? null;

  // NUEVOS
  const anio = Number.isFinite(Number(b.anio)) ? Number(b.anio) : null;
  const color = (b.color ?? null) ? String(b.color).trim() : null;

  // Propietario: por id existente (seleccionado en búsqueda) o por texto
  // libre (nombre/teléfono), que crea o reutiliza un registro normalizado.
  const propietarioIdBody = Number.isFinite(Number(b.propietario_id ?? b.propietarioId))
    ? Number(b.propietario_id ?? b.propietarioId)
    : null;
  const propietarioNombre = (b.propietario_nombre ?? b.propietarioNombre ?? null)
    ? String(b.propietario_nombre ?? b.propietarioNombre).trim()
    : null;
  const propietarioTelefono = (b.propietario_telefono ?? b.propietarioTelefono ?? null)
    ? String(b.propietario_telefono ?? b.propietarioTelefono).trim()
    : null;
  const notaIngreso = (b.nota_ingreso ?? b.notaIngreso ?? null)
    ? String(b.nota_ingreso ?? b.notaIngreso).trim().slice(0, 300)
    : null;

  // ✅ NUEVO: tipo de vehículo
  const tipoVehiculo = (b.tipo_vehiculo ?? b.tipoVehiculo ?? null)
    ? String(b.tipo_vehiculo ?? b.tipoVehiculo).trim().slice(0, 30)
    : null;

  // ✅ NUEVO: combustible / transmisión / cilindraje
  const tipoCombustible = (b.tipo_combustible ?? b.tipoCombustible ?? null)
    ? String(b.tipo_combustible ?? b.tipoCombustible).trim().slice(0, 30)
    : null;
  const transmision = (b.transmision ?? null)
    ? String(b.transmision).trim().slice(0, 30)
    : null;
  const cilindraje = (b.cilindraje ?? null)
    ? String(b.cilindraje).trim().slice(0, 20)
    : null;

  if (!placa) return res.status(400).json({ error: "placa inválida" });

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const mechanicId = req.user.id;

    let propietarioId = propietarioIdBody;
    if (!propietarioId && propietarioNombre) {
      propietarioId = await findOrCreatePropietario(propietarioNombre, propietarioTelefono);
    }

    const insertVeh = await client.query(
      `INSERT INTO vehiculos (
         marca, modelo, placa, kilometraje, ultima_visita, mechanic_id,
         anio, color, propietario_id, nota_ingreso,
         tipo_vehiculo, tipo_combustible, transmision, cilindraje
       )
       VALUES ($1,$2,$3,$4,$5,$6, $7,$8,$9,$10, $11, $12,$13,$14)
       RETURNING id`,
      [
        marca, modelo, placa, kilometraje, ultima_visita, mechanicId,
        anio, color, propietarioId, notaIngreso,
        tipoVehiculo, tipoCombustible, transmision, cilindraje
      ]
    );

    const vehiculoId = insertVeh.rows[0].id;
    const token = crypto.randomUUID();

    await client.query(
      `INSERT INTO vehiculo_qr (vehiculo_id, qr_token, activo)
       VALUES ($1, $2, true)`,
      [vehiculoId, token]
    );

    await client.query("COMMIT");

    res.json({
      mensaje: "Vehículo agregado correctamente",
      vehiculo_id: vehiculoId,
      qr_token: token,
    });
  } catch (error) {
    await client.query("ROLLBACK");

    const msg = String(error.message || "");
    if (msg.toLowerCase().includes("duplicate") || msg.toLowerCase().includes("unique")) {
      return res.status(409).json({ error: "La placa ya existe" });
    }

    res.status(500).json({ error: "Error al agregar el vehículo", detalle: error.message });
  } finally {
    client.release();
  }
});

// ===========================
// DELETE VEHÍCULO POR PLACA (privado)
// ===========================
router.delete("/:placa", async (req, res) => {
  const placa = String(req.params.placa || "").trim().toUpperCase();
  if (!placa) return res.status(400).json({ error: "placa inválida" });

  try {
    const params = [placa];
    let extra = "";

    if (!isSuper(req)) {
      params.push(req.user.id);
      extra = " AND mechanic_id = $2";
    }

    const result = await pool.query(
      `DELETE FROM vehiculos
       WHERE placa = $1
       ${extra}`,
      params
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Vehículo no encontrado" });
    }

    res.json({ mensaje: "Vehículo eliminado correctamente" });
  } catch (error) {
    res.status(500).json({ error: "Error al eliminar vehículo", detalle: error.message });
  }
});

// ===========================
// PUT ACTUALIZAR VEHÍCULO (privado)
// (ampliado: permite actualizar campos nuevos sin romper lo anterior)
// ===========================
router.put("/:placa", async (req, res) => {
  const placa = String(req.params.placa || "").trim().toUpperCase();
  if (!placa) return res.status(400).json({ error: "placa inválida" });

  const b = req.body || {};

  const kilometraje = (b.kilometraje === undefined) ? undefined : (b.kilometraje ?? null);
  const ultima_visita = (b.ultima_visita === undefined) ? undefined : (b.ultima_visita ?? null);

  const anio = (b.anio === undefined) ? undefined : (Number.isFinite(Number(b.anio)) ? Number(b.anio) : null);
  const color = (b.color === undefined) ? undefined : ((b.color ?? null) ? String(b.color).trim() : null);

  // El propietario ya no es un campo plano de vehiculos: se edita en
  // /propietarios/:id (afecta a todos sus vehículos) o se reasigna con
  // PUT /vehiculos/:placa/propietario.

  const notaIngreso = (b.nota_ingreso === undefined && b.notaIngreso === undefined)
    ? undefined
    : ((b.nota_ingreso ?? b.notaIngreso ?? null) ? String(b.nota_ingreso ?? b.notaIngreso).trim().slice(0, 300) : null);

  // ✅ NUEVO: tipo de vehículo
  const tipoVehiculo = (b.tipo_vehiculo === undefined && b.tipoVehiculo === undefined)
    ? undefined
    : ((b.tipo_vehiculo ?? b.tipoVehiculo ?? null) ? String(b.tipo_vehiculo ?? b.tipoVehiculo).trim().slice(0, 30) : null);

  // ✅ NUEVO: combustible / transmisión / cilindraje
  const tipoCombustible = (b.tipo_combustible === undefined && b.tipoCombustible === undefined)
    ? undefined
    : ((b.tipo_combustible ?? b.tipoCombustible ?? null) ? String(b.tipo_combustible ?? b.tipoCombustible).trim().slice(0, 30) : null);
  const transmision = (b.transmision === undefined)
    ? undefined
    : ((b.transmision ?? null) ? String(b.transmision).trim().slice(0, 30) : null);
  const cilindraje = (b.cilindraje === undefined)
    ? undefined
    : ((b.cilindraje ?? null) ? String(b.cilindraje).trim().slice(0, 20) : null);

  const sets = [];
  const params = [];
  let idx = 1;

  function addSet(col, val) {
    sets.push(`${col} = $${idx++}`);
    params.push(val);
  }

  if (kilometraje !== undefined) addSet("kilometraje", kilometraje);
  if (ultima_visita !== undefined) addSet("ultima_visita", ultima_visita);
  if (anio !== undefined) addSet("anio", anio);
  if (color !== undefined) addSet("color", color);
  if (notaIngreso !== undefined) addSet("nota_ingreso", notaIngreso);
  if (tipoVehiculo !== undefined) addSet("tipo_vehiculo", tipoVehiculo);
  if (tipoCombustible !== undefined) addSet("tipo_combustible", tipoCombustible);
  if (transmision !== undefined) addSet("transmision", transmision);
  if (cilindraje !== undefined) addSet("cilindraje", cilindraje);

  if (sets.length === 0) {
    return res.status(400).json({ error: "No hay campos para actualizar" });
  }

  params.push(placa);
  const placaParam = `$${idx++}`;

  let extra = "";
  if (!isSuper(req)) {
    params.push(req.user.id);
    extra = ` AND mechanic_id = $${idx++}`;
  }

  try {
    const result = await pool.query(
      `UPDATE vehiculos
       SET ${sets.join(", ")}
       WHERE placa = ${placaParam}
       ${extra}
       RETURNING *`,
      params
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Vehículo no encontrado" });
    }

    res.json({
      mensaje: "Vehículo actualizado correctamente",
      vehiculo: result.rows[0],
    });
  } catch (error) {
    res.status(500).json({ error: "Error al actualizar vehículo", detalle: error.message });
  }
});

// ===========================
// PUT REASIGNAR PROPIETARIO (privado)
// Body: { propietario_id } para uno existente, o { nombre, telefono }
// para crear uno nuevo (o reutilizar uno con el mismo nombre+teléfono)
// y asignarlo. El historial de OTs no se ve afectado: está ligado a la
// placa, no al propietario.
// ===========================
router.put("/:placa/propietario", async (req, res) => {
  const placa = String(req.params.placa || "").trim().toUpperCase();
  if (!placa) return res.status(400).json({ error: "placa inválida" });

  const b = req.body || {};
  const propietarioIdBody = Number.isFinite(Number(b.propietario_id ?? b.propietarioId))
    ? Number(b.propietario_id ?? b.propietarioId)
    : null;
  const nombre = b.nombre ? String(b.nombre).trim() : null;
  const telefono = b.telefono ? String(b.telefono).trim() : null;

  if (!propietarioIdBody && !nombre) {
    return res.status(400).json({ error: "Falta propietario_id o nombre" });
  }

  try {
    let propietarioId = propietarioIdBody;

    if (propietarioId) {
      const existe = await pool.query(`SELECT id FROM propietarios WHERE id = $1`, [propietarioId]);
      if (existe.rowCount === 0) return res.status(404).json({ error: "Propietario no encontrado" });
    } else {
      propietarioId = await findOrCreatePropietario(nombre, telefono);
    }

    const params = [propietarioId, placa];
    let extra = "";
    if (!isSuper(req)) {
      params.push(req.user.id);
      extra = " AND mechanic_id = $3";
    }

    const result = await pool.query(
      `UPDATE vehiculos SET propietario_id = $1 WHERE placa = $2 ${extra} RETURNING id`,
      params
    );
    if (result.rowCount === 0) return res.status(404).json({ error: "Vehículo no encontrado" });

    const p = await pool.query(
      `SELECT id, nombre, telefono, cedula, email FROM propietarios WHERE id = $1`,
      [propietarioId]
    );

    res.json({ mensaje: "Propietario reasignado correctamente", propietario: p.rows[0] });
  } catch (error) {
    res.status(500).json({ error: "Error al reasignar propietario", detalle: error.message });
  }
});

// ===========================
// GET OTs DE UN VEHÍCULO POR PLACA (privado)
// Usado por Detalle de Vehículo para mostrar el historial de órdenes.
// ===========================
router.get("/:placa/ordenes", async (req, res) => {
  const placa = String(req.params.placa || "").trim().toUpperCase();
  if (!placa) return res.status(400).json({ error: "placa inválida" });

  try {
    const veh = await ensureVehiculoOwnedByUserOr404(req, placa);
    if (!veh) return res.status(404).json({ error: "Vehículo no encontrado" });

    const result = await pool.query(
      `SELECT
         id, symptoms, estado, pago_estado, total, kilometraje_ot, created_at, closed_at,
         CASE
           WHEN estado = 'ENTREGADO' THEN 'ENTREGADO'
           WHEN estado = 'RECIBIDO'
                AND (COALESCE(total_servicios,0) > 0
                     OR COALESCE(total_repuestos,0) > 0
                     OR COALESCE(total,0) > 0)
             THEN 'PENDIENTE'
           ELSE estado
         END AS estado_ui
       FROM ordenes_trabajo
       WHERE placa = $1
       ORDER BY created_at DESC`,
      [placa]
    );

    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: "Error al obtener historial de OTs", detalle: error.message });
  }
});

export default router;
