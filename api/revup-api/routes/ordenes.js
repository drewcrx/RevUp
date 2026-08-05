// routes/ordenes.js (COMPLETO) — OT privadas por mecánico + superuser ve todo
import express from "express";
import multer from "multer";
import path from "path";
import fs from "fs";
import crypto from "crypto";
import { pool } from "../db/connection.js";
import { requireAuth } from "../src/middleware/auth.js";

const router = express.Router();

// 🔒 TODO este módulo requiere auth
router.use(requireAuth);

// =========================
// Fotos de OT — almacenamiento en disco (volumen persistente)
// =========================
const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(process.cwd(), "uploads");

const fotosStorage = multer.diskStorage({
  destination: (req, _file, cb) => {
    const dir = path.join(UPLOAD_DIR, `ot_${req.params.id}`);
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || "").slice(0, 10) || ".jpg";
    cb(null, `${crypto.randomUUID()}${ext}`);
  },
});

const uploadFotos = multer({
  storage: fotosStorage,
  limits: { fileSize: 8 * 1024 * 1024, files: 10 },
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith("image/")) {
      return cb(new Error("Solo se permiten imágenes"));
    }
    cb(null, true);
  },
});

// Envuelve multer para que sus errores (archivo muy grande, tipo inválido)
// respondan JSON en vez de tumbar la request con la página de error de Express.
function subirFotosMiddleware(req, res, next) {
  uploadFotos.array("fotos", 10)(req, res, (err) => {
    if (err) return res.status(400).json({ error: err.message || "Error subiendo archivo" });
    next();
  });
}

// =========================
// Inspección de daños — vistas/zonas válidas + fotos por zona
// =========================
const VISTAS_VALIDAS = new Set([
  "frontal", "posterior", "lateral_izquierdo", "lateral_derecho", "superior",
]);
const TIPOS_DANO_VALIDOS = new Set(["ingreso", "entrega"]);

const danoFotosStorage = multer.diskStorage({
  destination: (req, _file, cb) => {
    const dir = path.join(UPLOAD_DIR, `dano_${req.params.danoId}`);
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || "").slice(0, 10) || ".jpg";
    cb(null, `${crypto.randomUUID()}${ext}`);
  },
});

const uploadDanoFotos = multer({
  storage: danoFotosStorage,
  limits: { fileSize: 8 * 1024 * 1024, files: 10 },
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith("image/")) {
      return cb(new Error("Solo se permiten imágenes"));
    }
    cb(null, true);
  },
});

function subirDanoFotosMiddleware(req, res, next) {
  uploadDanoFotos.array("fotos", 10)(req, res, (err) => {
    if (err) return res.status(400).json({ error: err.message || "Error subiendo archivo" });
    next();
  });
}

// Verifica que el daño exista y que el usuario tenga acceso a la OT dueña
async function getDanoIfAllowed(danoId, user) {
  const d = await pool.query(`SELECT * FROM orden_danos WHERE id = $1`, [danoId]);
  if (d.rowCount === 0) return null;
  const ot = await getOtIfAllowed(d.rows[0].orden_id, user);
  if (!ot) return null;
  return d.rows[0];
}

// =========================
// Actualizaciones de la OT — foto(s) + nota mientras se trabaja el auto
// =========================
const actualizacionFotosStorage = multer.diskStorage({
  destination: (req, _file, cb) => {
    const dir = path.join(UPLOAD_DIR, `actualizacion_${req.params.actId}`);
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || "").slice(0, 10) || ".jpg";
    cb(null, `${crypto.randomUUID()}${ext}`);
  },
});

const uploadActualizacionFotos = multer({
  storage: actualizacionFotosStorage,
  limits: { fileSize: 8 * 1024 * 1024, files: 10 },
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith("image/")) {
      return cb(new Error("Solo se permiten imágenes"));
    }
    cb(null, true);
  },
});

function subirActualizacionFotosMiddleware(req, res, next) {
  uploadActualizacionFotos.array("fotos", 10)(req, res, (err) => {
    if (err) return res.status(400).json({ error: err.message || "Error subiendo archivo" });
    next();
  });
}

// Verifica que la actualización exista y que el usuario tenga acceso a la OT dueña
async function getActualizacionIfAllowed(actId, user) {
  const a = await pool.query(`SELECT * FROM orden_actualizaciones WHERE id = $1`, [actId]);
  if (a.rowCount === 0) return null;
  const ot = await getOtIfAllowed(a.rows[0].orden_id, user);
  if (!ot) return null;
  return a.rows[0];
}

// =========================
// Helpers
// =========================
async function recalcularTotales(ordenId) {
  const s = await pool.query(
    `SELECT COALESCE(SUM(precio), 0) AS total_servicios
     FROM orden_servicios
     WHERE orden_id = $1`,
    [ordenId]
  );

  const r = await pool.query(
    `SELECT COALESCE(SUM(cantidad * precio_unitario), 0) AS total_repuestos
     FROM orden_repuestos
     WHERE orden_id = $1`,
    [ordenId]
  );

  const totalServicios = Number(s.rows[0].total_servicios || 0);
  const totalRepuestos = Number(r.rows[0].total_repuestos || 0);
  const total = totalServicios + totalRepuestos;

  await pool.query(
    `UPDATE ordenes_trabajo
     SET total_servicios = $2,
         total_repuestos = $3,
         total = $4
     WHERE id = $1`,
    [ordenId, totalServicios, totalRepuestos, total]
  );

  return { totalServicios, totalRepuestos, total };
}

async function getPagado(ordenId) {
  const p = await pool.query(
    `SELECT COALESCE(SUM(monto), 0) AS pagado
     FROM orden_pagos
     WHERE orden_id = $1`,
    [ordenId]
  );
  return Number(p.rows[0].pagado || 0);
}

async function recalcularPagoEstado(ordenId) {
  const ot = await pool.query(`SELECT total FROM ordenes_trabajo WHERE id = $1`, [ordenId]);
  if (ot.rowCount === 0) return;

  const total = Number(ot.rows[0].total || 0);
  const pagado = await getPagado(ordenId);

  const pagoEstado = total > 0 && pagado >= total ? "PAGADO" : "PENDIENTE";

  await pool.query(
    `UPDATE ordenes_trabajo
     SET pago_estado = $2
     WHERE id = $1`,
    [ordenId, pagoEstado]
  );
}

// ✅ NUEVO: cuando se agrega trabajo (servicio/repuesto) y la OT estaba RECIBIDO,
// pasa a PENDIENTE automáticamente.
async function marcarPendienteSiRecibido(ordenId) {
  await pool.query(
    `UPDATE ordenes_trabajo
     SET estado = 'PENDIENTE'
     WHERE id = $1
       AND estado = 'RECIBIDO'`,
    [ordenId]
  );
}

// =========================
// Seguridad: validar acceso OT
// =========================
async function getOtIfAllowed(ordenId, user) {
  const params = [ordenId];
  let extra = "";

  if (user.role !== "superuser") {
    params.push(user.id);
    extra = " AND mechanic_id = $2";
  }

  const ot = await pool.query(
    `SELECT ot.*, u.nombre AS mechanic_nombre
     FROM ordenes_trabajo ot
     LEFT JOIN usuarios u ON u.id = ot.mechanic_id
     WHERE ot.id = $1
     ${extra}`,
    params
  );

  return ot.rowCount ? ot.rows[0] : null;
}

// =========================
// 1) Crear OT (CON KM SNAPSHOT)
// - mechanic_id SIEMPRE desde JWT
// - usuario_id también (porque tu tabla lo exige NOT NULL)
// - kilometraje_ot: km actual del vehículo al momento de crear la OT
// =========================
router.post("/", async (req, res) => {
  try {
    const { placa, symptoms, kilometraje } = req.body;

    if (!placa || !symptoms) {
      return res.status(400).json({ error: "Faltan datos (placa, symptoms)" });
    }

    const mechanicId = Number(req.user?.id);
    if (!mechanicId) {
      return res.status(401).json({ error: "Token válido pero sin id de usuario" });
    }

    const placaUpper = String(placa).toUpperCase();

    // El kilometraje con el que llega el auto se registra aquí, al crear la
    // OT (que es cuando el auto está físicamente presente) — no se asume
    // el valor guardado del vehículo, que puede estar desactualizado desde
    // la última visita. Si viene en el body, además se sincroniza con
    // vehiculos.kilometraje para que quede al día.
    const kmIngreso = Number.isFinite(Number(kilometraje)) && Number(kilometraje) > 0
      ? Number(kilometraje) : null;

    let kmOt = kmIngreso;
    if (kmIngreso !== null) {
      await pool.query(
        `UPDATE vehiculos SET kilometraje = $1 WHERE placa = $2`,
        [kmIngreso, placaUpper]
      );
    } else {
      const vk = await pool.query(
        `SELECT kilometraje FROM vehiculos WHERE placa = $1 LIMIT 1`,
        [placaUpper]
      );
      kmOt = vk.rowCount ? Number(vk.rows[0].kilometraje || 0) : null;
    }

    const q = await pool.query(
      `
      INSERT INTO ordenes_trabajo (
        placa, mechanic_id, usuario_id, symptoms,
        estado, total, kilometraje_ot, created_at
      )
      VALUES ($1, $2, $3, $4, 'RECIBIDO', 0, $5, NOW())
      RETURNING *;
      `,
      [placaUpper, mechanicId, mechanicId, String(symptoms), kmOt]
    );

    return res.status(201).json(q.rows[0]);
  } catch (e) {
    return res.status(500).json({ error: "Error creando OT", detalle: e.message });
  }
});

// =========================
// 2) Listar OTs (privado)
// - mechanic: solo las suyas
// - superuser: todas (y puede filtrar por mechanicId)
// ?estado=RECIBIDO
// ?mechanicId=1 (solo superuser; si lo manda un mecánico se ignora)
// =========================
router.get("/", async (req, res) => {
  const { mechanicId, estado } = req.query || {};

  try {
    const params = [];
    const where = [];

    if (estado) {
      params.push(String(estado));
      where.push(`estado = $${params.length}`);
    }

    if (req.user.role === "superuser") {
      if (mechanicId) {
        const mid = Number(mechanicId);
        if (Number.isFinite(mid) && mid > 0) {
          params.push(mid);
          where.push(`mechanic_id = $${params.length}`);
        }
      }
    } else {
      params.push(Number(req.user.id));
      where.push(`mechanic_id = $${params.length}`);
    }

    const sql = `
      SELECT
        ot.id, ot.placa, ot.mechanic_id, ot.usuario_id, ot.symptoms,
        ot.diagnostico, u.nombre AS mechanic_nombre,
        ot.estado, ot.pago_estado,
        ot.total_servicios, ot.total_repuestos, ot.total,
        ot.kilometraje_ot,
        ot.created_at, ot.closed_at,
        COALESCE(act.actualizaciones_count, 0) AS actualizaciones_count,

        -- Estado lógico para UI
        CASE
          WHEN ot.estado = 'ENTREGADO' THEN 'ENTREGADO'
          WHEN ot.estado = 'RECIBIDO'
               AND (COALESCE(ot.total_servicios,0) > 0
                    OR COALESCE(ot.total_repuestos,0) > 0
                    OR COALESCE(ot.total,0) > 0)
            THEN 'PENDIENTE'
          ELSE ot.estado
        END AS estado_ui

      FROM ordenes_trabajo ot
      LEFT JOIN usuarios u ON u.id = ot.mechanic_id
      LEFT JOIN (
        SELECT orden_id, COUNT(*) AS actualizaciones_count
        FROM orden_actualizaciones
        GROUP BY orden_id
      ) act ON act.orden_id = ot.id
      ${where.length ? `WHERE ${where.map((w) => `ot.${w}`).join(" AND ")}` : ""}
      ORDER BY ot.created_at DESC
    `;

    const q = await pool.query(sql, params);
    return res.json(q.rows);
  } catch (e) {
    return res.status(500).json({ error: "Error listando OTs", detalle: e.message });
  }
});

// =========================
// 3) Detalle OT (privado + hijos)
// =========================
router.get("/:id", async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ error: "id inválido" });

  try {
    const ot = await getOtIfAllowed(id, req.user);
    if (!ot) return res.status(404).json({ error: "OT no encontrada" });

    const servicios = await pool.query(
      `SELECT id, descripcion, precio, created_at
       FROM orden_servicios
       WHERE orden_id = $1
       ORDER BY created_at DESC`,
      [id]
    );

    const repuestos = await pool.query(
      `SELECT id, nombre, cantidad, costo_unitario, precio_unitario, created_at
       FROM orden_repuestos
       WHERE orden_id = $1
       ORDER BY created_at DESC`,
      [id]
    );

    const pagos = await pool.query(
      `SELECT id, monto, metodo, created_at
       FROM orden_pagos
       WHERE orden_id = $1
       ORDER BY created_at DESC`,
      [id]
    );

    const fotos = await pool.query(
      `SELECT id, tipo, ruta, created_at
       FROM orden_fotos
       WHERE orden_id = $1
       ORDER BY created_at ASC`,
      [id]
    );

    const danos = await pool.query(
      `SELECT id, orden_id, tipo, vista, zona, estado_dano, tipo_reparacion, observaciones, created_at
       FROM orden_danos
       WHERE orden_id = $1
       ORDER BY created_at ASC`,
      [id]
    );
    let danoFotosPorId = {};
    if (danos.rowCount > 0) {
      const danoIds = danos.rows.map((d) => d.id);
      const df = await pool.query(
        `SELECT id, dano_id, ruta, created_at
         FROM orden_dano_fotos
         WHERE dano_id = ANY($1::int[])
         ORDER BY created_at ASC`,
        [danoIds]
      );
      for (const f of df.rows) {
        (danoFotosPorId[f.dano_id] ??= []).push({ ...f, url: fotoUrl(f.ruta) });
      }
    }

    const actualizaciones = await pool.query(
      `SELECT id, orden_id, nota, created_at
       FROM orden_actualizaciones
       WHERE orden_id = $1
       ORDER BY created_at DESC`,
      [id]
    );
    let actFotosPorId = {};
    if (actualizaciones.rowCount > 0) {
      const actIds = actualizaciones.rows.map((a) => a.id);
      const af = await pool.query(
        `SELECT id, actualizacion_id, ruta, created_at
         FROM orden_actualizacion_fotos
         WHERE actualizacion_id = ANY($1::int[])
         ORDER BY created_at ASC`,
        [actIds]
      );
      for (const f of af.rows) {
        (actFotosPorId[f.actualizacion_id] ??= []).push({ ...f, url: fotoUrl(f.ruta) });
      }
    }

    return res.json({
      ot,
      servicios: servicios.rows,
      repuestos: repuestos.rows,
      pagos: pagos.rows,
      fotos: fotos.rows.map((f) => ({ ...f, url: fotoUrl(f.ruta) })),
      danos: danos.rows.map((d) => ({ ...d, fotos: danoFotosPorId[d.id] || [] })),
      actualizaciones: actualizaciones.rows.map((a) => ({ ...a, fotos: actFotosPorId[a.id] || [] })),
    });
  } catch (e) {
    return res.status(500).json({ error: "Error cargando detalle", detalle: e.message });
  }
});

// =========================
// 2b) Diagnóstico / notas generales de la OT
// =========================
router.put("/:id/diagnostico", async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ error: "id inválido" });

  const diagnostico = String(req.body?.diagnostico || "").trim().slice(0, 2000) || null;

  try {
    const ot = await getOtIfAllowed(id, req.user);
    if (!ot) return res.status(404).json({ error: "OT no encontrada" });

    const q = await pool.query(
      `UPDATE ordenes_trabajo SET diagnostico = $1 WHERE id = $2 RETURNING id, diagnostico`,
      [diagnostico, id]
    );

    return res.json(q.rows[0]);
  } catch (e) {
    return res.status(500).json({ error: "Error actualizando diagnóstico", detalle: e.message });
  }
});

// =========================
// 3b) Fotos de la OT: subir / listar / eliminar
// =========================
function fotoUrl(ruta) {
  const base = process.env.APP_URL || "";
  return `${base}/uploads/${ruta}`;
}

router.post("/:id/fotos", subirFotosMiddleware, async (req, res) => {
  const ordenId = Number(req.params.id);
  const tipo = String(req.body?.tipo || "").trim();

  if (!Number.isFinite(ordenId)) return res.status(400).json({ error: "id inválido" });
  if (!["ingreso", "entrega"].includes(tipo)) {
    return res.status(400).json({ error: "tipo debe ser 'ingreso' o 'entrega'" });
  }

  try {
    const ot = await getOtIfAllowed(ordenId, req.user);
    if (!ot) return res.status(404).json({ error: "OT no encontrada" });

    const files = req.files || [];
    if (files.length === 0) {
      return res.status(400).json({ error: "No se recibió ninguna foto" });
    }

    const inserted = [];
    for (const file of files) {
      const relPath = `ot_${ordenId}/${file.filename}`;
      const q = await pool.query(
        `INSERT INTO orden_fotos (orden_id, tipo, ruta)
         VALUES ($1, $2, $3)
         RETURNING id, tipo, ruta, created_at`,
        [ordenId, tipo, relPath]
      );
      inserted.push({ ...q.rows[0], url: fotoUrl(relPath) });
    }

    return res.status(201).json(inserted);
  } catch (e) {
    return res.status(500).json({ error: "Error subiendo fotos", detalle: e.message });
  }
});

router.delete("/fotos/:fotoId", async (req, res) => {
  const fotoId = Number(req.params.fotoId);
  if (!Number.isFinite(fotoId)) return res.status(400).json({ error: "id inválido" });

  try {
    const f = await pool.query(
      `SELECT f.id, f.ruta, f.orden_id
       FROM orden_fotos f
       JOIN ordenes_trabajo o ON o.id = f.orden_id
       WHERE f.id = $1`,
      [fotoId]
    );
    if (f.rowCount === 0) return res.status(404).json({ error: "Foto no encontrada" });

    const allowed = await getOtIfAllowed(f.rows[0].orden_id, req.user);
    if (!allowed) return res.status(404).json({ error: "Foto no encontrada" });

    await pool.query(`DELETE FROM orden_fotos WHERE id = $1`, [fotoId]);

    const fullPath = path.join(UPLOAD_DIR, f.rows[0].ruta);
    fs.unlink(fullPath, () => {}); // best-effort, no bloquea la respuesta

    return res.json({ mensaje: "Foto eliminada" });
  } catch (e) {
    return res.status(500).json({ error: "Error eliminando foto", detalle: e.message });
  }
});

// =========================
// 3c) Inspección de daños: crear / editar / eliminar zona marcada
// =========================
router.post("/:id/danos", async (req, res) => {
  const ordenId = Number(req.params.id);
  const { vista, zona, tipo, estado_dano, tipo_reparacion, observaciones } = req.body || {};

  if (!Number.isFinite(ordenId)) return res.status(400).json({ error: "id inválido" });
  if (!VISTAS_VALIDAS.has(String(vista || ""))) {
    return res.status(400).json({ error: "vista inválida" });
  }
  if (!zona || !String(zona).trim()) {
    return res.status(400).json({ error: "zona es obligatoria" });
  }
  const tipoDano = tipo ? String(tipo) : "ingreso";
  if (!TIPOS_DANO_VALIDOS.has(tipoDano)) {
    return res.status(400).json({ error: "tipo inválido (ingreso o entrega)" });
  }

  try {
    const ot = await getOtIfAllowed(ordenId, req.user);
    if (!ot) return res.status(404).json({ error: "OT no encontrada" });

    const q = await pool.query(
      `INSERT INTO orden_danos (orden_id, tipo, vista, zona, estado_dano, tipo_reparacion, observaciones)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        ordenId, tipoDano, vista, String(zona).trim(),
        estado_dano ? String(estado_dano).trim() : null,
        tipo_reparacion ? String(tipo_reparacion).trim() : null,
        observaciones ? String(observaciones).trim().slice(0, 500) : null,
      ]
    );

    return res.status(201).json({ ...q.rows[0], fotos: [] });
  } catch (e) {
    return res.status(500).json({ error: "Error agregando daño", detalle: e.message });
  }
});

router.put("/danos/:danoId", async (req, res) => {
  const danoId = Number(req.params.danoId);
  if (!Number.isFinite(danoId)) return res.status(400).json({ error: "id inválido" });

  const b = req.body || {};
  const estadoDano = b.estado_dano === undefined
    ? undefined : (String(b.estado_dano || "").trim() || null);
  const tipoReparacion = b.tipo_reparacion === undefined
    ? undefined : (String(b.tipo_reparacion || "").trim() || null);
  const observaciones = b.observaciones === undefined
    ? undefined : (String(b.observaciones || "").trim().slice(0, 500) || null);
  const tipo = b.tipo === undefined ? undefined : String(b.tipo || "");

  if (tipo !== undefined && !TIPOS_DANO_VALIDOS.has(tipo)) {
    return res.status(400).json({ error: "tipo inválido (ingreso o entrega)" });
  }

  const sets = [];
  const params = [];
  let idx = 1;
  function addSet(col, val) { sets.push(`${col} = $${idx++}`); params.push(val); }

  if (estadoDano !== undefined) addSet("estado_dano", estadoDano);
  if (tipoReparacion !== undefined) addSet("tipo_reparacion", tipoReparacion);
  if (observaciones !== undefined) addSet("observaciones", observaciones);
  if (tipo !== undefined) addSet("tipo", tipo);

  if (sets.length === 0) {
    return res.status(400).json({ error: "No hay campos para actualizar" });
  }

  try {
    const dano = await getDanoIfAllowed(danoId, req.user);
    if (!dano) return res.status(404).json({ error: "Daño no encontrado" });

    params.push(danoId);
    const q = await pool.query(
      `UPDATE orden_danos SET ${sets.join(", ")} WHERE id = $${idx} RETURNING *`,
      params
    );

    return res.json(q.rows[0]);
  } catch (e) {
    return res.status(500).json({ error: "Error actualizando daño", detalle: e.message });
  }
});

router.delete("/danos/:danoId", async (req, res) => {
  const danoId = Number(req.params.danoId);
  if (!Number.isFinite(danoId)) return res.status(400).json({ error: "id inválido" });

  try {
    const dano = await getDanoIfAllowed(danoId, req.user);
    if (!dano) return res.status(404).json({ error: "Daño no encontrado" });

    const fotosRes = await pool.query(
      `SELECT ruta FROM orden_dano_fotos WHERE dano_id = $1`, [danoId]);

    await pool.query(`DELETE FROM orden_danos WHERE id = $1`, [danoId]);

    for (const f of fotosRes.rows) {
      fs.unlink(path.join(UPLOAD_DIR, f.ruta), () => {});
    }

    return res.json({ mensaje: "Daño eliminado" });
  } catch (e) {
    return res.status(500).json({ error: "Error eliminando daño", detalle: e.message });
  }
});

router.post("/danos/:danoId/fotos", subirDanoFotosMiddleware, async (req, res) => {
  const danoId = Number(req.params.danoId);
  if (!Number.isFinite(danoId)) return res.status(400).json({ error: "id inválido" });

  try {
    const dano = await getDanoIfAllowed(danoId, req.user);
    if (!dano) return res.status(404).json({ error: "Daño no encontrado" });

    const files = req.files || [];
    if (files.length === 0) return res.status(400).json({ error: "No se recibió ninguna foto" });

    const inserted = [];
    for (const file of files) {
      const relPath = `dano_${danoId}/${file.filename}`;
      const q = await pool.query(
        `INSERT INTO orden_dano_fotos (dano_id, ruta)
         VALUES ($1, $2)
         RETURNING id, dano_id, ruta, created_at`,
        [danoId, relPath]
      );
      inserted.push({ ...q.rows[0], url: fotoUrl(relPath) });
    }

    return res.status(201).json(inserted);
  } catch (e) {
    return res.status(500).json({ error: "Error subiendo fotos", detalle: e.message });
  }
});

router.delete("/danos/fotos/:fotoId", async (req, res) => {
  const fotoId = Number(req.params.fotoId);
  if (!Number.isFinite(fotoId)) return res.status(400).json({ error: "id inválido" });

  try {
    const f = await pool.query(
      `SELECT f.id, f.ruta, f.dano_id
       FROM orden_dano_fotos f
       WHERE f.id = $1`,
      [fotoId]
    );
    if (f.rowCount === 0) return res.status(404).json({ error: "Foto no encontrada" });

    const allowed = await getDanoIfAllowed(f.rows[0].dano_id, req.user);
    if (!allowed) return res.status(404).json({ error: "Foto no encontrada" });

    await pool.query(`DELETE FROM orden_dano_fotos WHERE id = $1`, [fotoId]);
    fs.unlink(path.join(UPLOAD_DIR, f.rows[0].ruta), () => {});

    return res.json({ mensaje: "Foto eliminada" });
  } catch (e) {
    return res.status(500).json({ error: "Error eliminando foto", detalle: e.message });
  }
});

// =========================
// Actualizaciones de la OT (foto + nota mientras se trabaja)
// =========================
router.post("/:id/actualizaciones", async (req, res) => {
  const ordenId = Number(req.params.id);
  if (!Number.isFinite(ordenId)) return res.status(400).json({ error: "id inválido" });

  const nota = req.body?.nota ? String(req.body.nota).trim().slice(0, 1000) : null;

  try {
    const ot = await getOtIfAllowed(ordenId, req.user);
    if (!ot) return res.status(404).json({ error: "OT no encontrada" });

    const q = await pool.query(
      `INSERT INTO orden_actualizaciones (orden_id, nota) VALUES ($1, $2) RETURNING *`,
      [ordenId, nota]
    );

    return res.status(201).json({ ...q.rows[0], fotos: [] });
  } catch (e) {
    return res.status(500).json({ error: "Error agregando actualización", detalle: e.message });
  }
});

router.delete("/actualizaciones/:actId", async (req, res) => {
  const actId = Number(req.params.actId);
  if (!Number.isFinite(actId)) return res.status(400).json({ error: "id inválido" });

  try {
    const act = await getActualizacionIfAllowed(actId, req.user);
    if (!act) return res.status(404).json({ error: "Actualización no encontrada" });

    const fotosRes = await pool.query(
      `SELECT ruta FROM orden_actualizacion_fotos WHERE actualizacion_id = $1`, [actId]);

    await pool.query(`DELETE FROM orden_actualizaciones WHERE id = $1`, [actId]);

    for (const f of fotosRes.rows) {
      fs.unlink(path.join(UPLOAD_DIR, f.ruta), () => {});
    }

    return res.json({ mensaje: "Actualización eliminada" });
  } catch (e) {
    return res.status(500).json({ error: "Error eliminando actualización", detalle: e.message });
  }
});

router.post("/actualizaciones/:actId/fotos", subirActualizacionFotosMiddleware, async (req, res) => {
  const actId = Number(req.params.actId);
  if (!Number.isFinite(actId)) return res.status(400).json({ error: "id inválido" });

  try {
    const act = await getActualizacionIfAllowed(actId, req.user);
    if (!act) return res.status(404).json({ error: "Actualización no encontrada" });

    const files = req.files || [];
    if (files.length === 0) return res.status(400).json({ error: "No se recibió ninguna foto" });

    const inserted = [];
    for (const file of files) {
      const relPath = `actualizacion_${actId}/${file.filename}`;
      const q = await pool.query(
        `INSERT INTO orden_actualizacion_fotos (actualizacion_id, ruta)
         VALUES ($1, $2)
         RETURNING id, actualizacion_id, ruta, created_at`,
        [actId, relPath]
      );
      inserted.push({ ...q.rows[0], url: fotoUrl(relPath) });
    }

    return res.status(201).json(inserted);
  } catch (e) {
    return res.status(500).json({ error: "Error subiendo fotos", detalle: e.message });
  }
});

router.delete("/actualizaciones/fotos/:fotoId", async (req, res) => {
  const fotoId = Number(req.params.fotoId);
  if (!Number.isFinite(fotoId)) return res.status(400).json({ error: "id inválido" });

  try {
    const f = await pool.query(
      `SELECT f.id, f.ruta, f.actualizacion_id
       FROM orden_actualizacion_fotos f
       WHERE f.id = $1`,
      [fotoId]
    );
    if (f.rowCount === 0) return res.status(404).json({ error: "Foto no encontrada" });

    const allowed = await getActualizacionIfAllowed(f.rows[0].actualizacion_id, req.user);
    if (!allowed) return res.status(404).json({ error: "Foto no encontrada" });

    await pool.query(`DELETE FROM orden_actualizacion_fotos WHERE id = $1`, [fotoId]);
    fs.unlink(path.join(UPLOAD_DIR, f.rows[0].ruta), () => {});

    return res.json({ mensaje: "Foto eliminada" });
  } catch (e) {
    return res.status(500).json({ error: "Error eliminando foto", detalle: e.message });
  }
});

// =========================
// 4) Agregar servicio (privado)
// =========================
router.post("/:id/servicios", async (req, res) => {
  const ordenId = Number(req.params.id);
  const { descripcion, precio } = req.body || {};

  if (!Number.isFinite(ordenId)) return res.status(400).json({ error: "id inválido" });
  if (!descripcion) return res.status(400).json({ error: "descripcion es obligatoria" });

  try {
    const ot = await getOtIfAllowed(ordenId, req.user);
    if (!ot) return res.status(404).json({ error: "OT no encontrada" });

    const q = await pool.query(
      `INSERT INTO orden_servicios (orden_id, descripcion, precio)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [ordenId, String(descripcion).trim(), Number(precio || 0)]
    );

    await recalcularTotales(ordenId);
    await recalcularPagoEstado(ordenId);

    await marcarPendienteSiRecibido(ordenId);

    return res.status(201).json(q.rows[0]);
  } catch (e) {
    return res.status(500).json({ error: "Error agregando servicio", detalle: e.message });
  }
});

// =========================
// 5) Agregar repuesto (privado)
// =========================
router.post("/:id/repuestos", async (req, res) => {
  const ordenId = Number(req.params.id);
  const { nombre, cantidad, costoUnitario, precioUnitario } = req.body || {};

  if (!Number.isFinite(ordenId)) return res.status(400).json({ error: "id inválido" });
  if (!nombre) return res.status(400).json({ error: "nombre es obligatorio" });

  try {
    const ot = await getOtIfAllowed(ordenId, req.user);
    if (!ot) return res.status(404).json({ error: "OT no encontrada" });

    const q = await pool.query(
      `INSERT INTO orden_repuestos (orden_id, nombre, cantidad, costo_unitario, precio_unitario)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [
        ordenId,
        String(nombre).trim(),
        Number(cantidad || 1),
        Number(costoUnitario || 0),
        Number(precioUnitario || 0),
      ]
    );

    await recalcularTotales(ordenId);
    await recalcularPagoEstado(ordenId);

    await marcarPendienteSiRecibido(ordenId);

    return res.status(201).json(q.rows[0]);
  } catch (e) {
    return res.status(500).json({ error: "Error agregando repuesto", detalle: e.message });
  }
});

// =========================
// 6) Registrar pago (privado)
// =========================
router.post("/:id/pagos", async (req, res) => {
  const ordenId = Number(req.params.id);
  const { monto, metodo } = req.body || {};

  if (!Number.isFinite(ordenId)) return res.status(400).json({ error: "id inválido" });
  if (monto == null) return res.status(400).json({ error: "monto es obligatorio" });

  try {
    const ot = await getOtIfAllowed(ordenId, req.user);
    if (!ot) return res.status(404).json({ error: "OT no encontrada" });

    const q = await pool.query(
      `INSERT INTO orden_pagos (orden_id, monto, metodo)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [ordenId, Number(monto), String(metodo || "EFECTIVO")]
    );

    await recalcularPagoEstado(ordenId);

    return res.status(201).json(q.rows[0]);
  } catch (e) {
    return res.status(500).json({ error: "Error registrando pago", detalle: e.message });
  }
});

// =========================
// 7) Cerrar OT (privado)
// =========================
router.post("/:id/cerrar", async (req, res) => {
  const ordenId = Number(req.params.id);
  if (!Number.isFinite(ordenId)) return res.status(400).json({ error: "id inválido" });

  try {
    const ot = await getOtIfAllowed(ordenId, req.user);
    if (!ot) return res.status(404).json({ error: "OT no encontrada" });

    const { total } = await recalcularTotales(ordenId);
    await recalcularPagoEstado(ordenId);

    // 🔒 No se puede entregar el vehículo si el pago no está completo.
    const pagado = await getPagado(ordenId);
    if (total > 0 && pagado < total) {
      const falta = (total - pagado).toFixed(2);
      return res.status(400).json({
        error: `No se puede entregar: falta registrar el pago. Faltan $${falta} de $${total.toFixed(2)}.`,
      });
    }

    const q = await pool.query(
      `UPDATE ordenes_trabajo
       SET estado = 'ENTREGADO',
           closed_at = NOW()
       WHERE id = $1
       RETURNING *`,
      [ordenId]
    );

    return res.json(q.rows[0]);
  } catch (e) {
    return res.status(500).json({ error: "Error cerrando OT", detalle: e.message });
  }
});

export default router;