// routes/ordenes.js (COMPLETO) — OT privadas por mecánico + superuser ve todo
import express from "express";
import { money, cents } from "../utils/money.js";
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

// La extensión con la que se guarda el archivo en disco debe salir del
// mimetype YA VALIDADO por fileFilter, nunca de file.originalname: ese
// campo lo controla el cliente y no tiene relación con el contenido real
// ni con el mimetype declarado — permitir que decida la extensión abría
// la puerta a guardar, p. ej., un archivo con mimetype "image/png" pero
// originalname "x.svg" o "x.html", que luego express.static serviría con
// Content-Type de HTML/SVG ejecutable (XSS almacenado).
const EXT_POR_MIMETYPE = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
  "image/gif": ".gif",
  "image/heic": ".heic",
  "image/heif": ".heif",
};
function extSeguraDeMimetype(mimetype) {
  return EXT_POR_MIMETYPE[mimetype] || ".jpg";
}

// Multer ya escribió los archivos en disco antes de que el handler pueda
// comprobar si el usuario tiene acceso a la OT/daño/actualización dueña
// (esa comprobación necesita una consulta async, y multer no espera por
// eso). Si la comprobación falla, hay que borrar lo que ya se escribió
// para no dejar archivos huérfanos en la carpeta.
function borrarArchivosSubidos(files) {
  for (const file of files || []) {
    fs.unlink(file.path, () => {}); // best-effort
  }
}

const fotosStorage = multer.diskStorage({
  destination: (req, _file, cb) => {
    // multer corre antes de que el handler de la ruta valide nada, así que
    // el id se valida aquí también — si no, un id manipulado terminaría
    // armando una ruta de carpeta con datos no verificados.
    const id = Number(req.params.id);
    if (!Number.isFinite(id)) return cb(new Error("id de OT inválido"));
    const dir = path.join(UPLOAD_DIR, `ot_${id}`);
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (_req, file, cb) => {
    const ext = extSeguraDeMimetype(file.mimetype);
    cb(null, `${crypto.randomUUID()}${ext}`);
  },
});

const uploadFotos = multer({
  storage: fotosStorage,
  limits: { fileSize: 8 * 1024 * 1024, files: 10 },
  fileFilter: (_req, file, cb) => {
    // SVG se sirve como archivo estático desde /uploads y puede llevar
    // <script> embebido — no se acepta aunque el mimetype empiece con
    // "image/".
    if (!file.mimetype.startsWith("image/") || file.mimetype === "image/svg+xml") {
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
    const danoId = Number(req.params.danoId);
    if (!Number.isFinite(danoId)) return cb(new Error("id de daño inválido"));
    const dir = path.join(UPLOAD_DIR, `dano_${danoId}`);
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (_req, file, cb) => {
    const ext = extSeguraDeMimetype(file.mimetype);
    cb(null, `${crypto.randomUUID()}${ext}`);
  },
});

const uploadDanoFotos = multer({
  storage: danoFotosStorage,
  limits: { fileSize: 8 * 1024 * 1024, files: 10 },
  fileFilter: (_req, file, cb) => {
    // SVG se sirve como archivo estático desde /uploads y puede llevar
    // <script> embebido — no se acepta aunque el mimetype empiece con
    // "image/".
    if (!file.mimetype.startsWith("image/") || file.mimetype === "image/svg+xml") {
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


// =========================
// Actualizaciones de la OT — foto(s) + nota mientras se trabaja el auto
// =========================
const actualizacionFotosStorage = multer.diskStorage({
  destination: (req, _file, cb) => {
    const actId = Number(req.params.actId);
    if (!Number.isFinite(actId)) return cb(new Error("id de actualización inválido"));
    const dir = path.join(UPLOAD_DIR, `actualizacion_${actId}`);
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (_req, file, cb) => {
    const ext = extSeguraDeMimetype(file.mimetype);
    cb(null, `${crypto.randomUUID()}${ext}`);
  },
});

const uploadActualizacionFotos = multer({
  storage: actualizacionFotosStorage,
  limits: { fileSize: 8 * 1024 * 1024, files: 10 },
  fileFilter: (_req, file, cb) => {
    // SVG se sirve como archivo estático desde /uploads y puede llevar
    // <script> embebido — no se acepta aunque el mimetype empiece con
    // "image/".
    if (!file.mimetype.startsWith("image/") || file.mimetype === "image/svg+xml") {
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


// =========================
// Helpers
// =========================
async function recalcularTotales(ordenId, db = pool) {
  const s = await db.query(
    `SELECT COALESCE(SUM(precio), 0) AS total_servicios
     FROM orden_servicios
     WHERE orden_id = $1`,
    [ordenId]
  );

  const r = await db.query(
    `SELECT COALESCE(SUM(cantidad * precio_unitario), 0) AS total_repuestos
     FROM orden_repuestos
     WHERE orden_id = $1`,
    [ordenId]
  );

  const totalServicios = Number(s.rows[0].total_servicios || 0);
  const totalRepuestos = Number(r.rows[0].total_repuestos || 0);
  const total = totalServicios + totalRepuestos;

  await db.query(
    `UPDATE ordenes_trabajo
     SET total_servicios = $2,
         total_repuestos = $3,
         total = $4
     WHERE id = $1`,
    [ordenId, totalServicios, totalRepuestos, total]
  );

  return { totalServicios, totalRepuestos, total };
}

async function getPagado(ordenId, db = pool) {
  const p = await db.query(
    `SELECT COALESCE(SUM(monto), 0) AS pagado
     FROM orden_pagos
     WHERE orden_id = $1`,
    [ordenId]
  );
  return Number(p.rows[0].pagado || 0);
}

async function recalcularPagoEstado(ordenId, db = pool) {
  const ot = await db.query(`SELECT total FROM ordenes_trabajo WHERE id = $1`, [ordenId]);
  if (ot.rowCount === 0) return;

  const total = Number(ot.rows[0].total || 0);
  const pagado = await getPagado(ordenId, db);

  const pagoEstado = pagado >= total ? "PAGADO" : "PENDIENTE";

  await db.query(
    `UPDATE ordenes_trabajo
     SET pago_estado = $2
     WHERE id = $1`,
    [ordenId, pagoEstado]
  );
}

// ✅ NUEVO: cuando se agrega trabajo (servicio/repuesto) y la OT estaba RECIBIDO,
// pasa a PENDIENTE automáticamente.
async function marcarPendienteSiRecibido(ordenId, db = pool) {
  await db.query(
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

// Serializa cargos, pagos y entrega sobre la misma fila. La validación del
// estado y el cambio financiero se confirman juntos o se revierten juntos.
async function modificarOtAbierta(req, res, mensajeError, operation, replay) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const params = [Number(req.params.id)];
    const filtro = req.user.role === 'superuser' ? '' : ' AND mechanic_id = $2';
    if (filtro) params.push(req.user.id);
    const found = await client.query(
      `SELECT * FROM ordenes_trabajo WHERE id = $1 ${filtro} FOR UPDATE`, params,
    );
    if (!found.rowCount) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'OT no encontrada' });
    }
    if (replay) {
      const previous = await replay(client, found.rows[0]);
      if (previous) {
        await client.query(previous.status >= 400 ? 'ROLLBACK' : 'COMMIT');
        return res.status(previous.status).json(previous.body);
      }
    }
    if (found.rows[0].estado === 'ENTREGADO') {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'La OT ya fue entregada y no admite cambios financieros' });
    }
    const result = await operation(client, found.rows[0]);
    if (result.status < 400) await client.query(
      'INSERT INTO orden_anotaciones (orden_id, autor_id, clase, texto) VALUES ($1,$2,$3,$4)',
      [Number(req.params.id), req.user.id, 'EVENTO', req.auditText || ({servicios:'Servicio agregado',repuestos:'Repuesto agregado',cerrar:'Vehículo entregado',diagnostico:'Diagnóstico actualizado'}[req.route.path.split('/').at(-1)] || 'Orden actualizada')]);
    await client.query(result.status >= 400 ? 'ROLLBACK' : 'COMMIT');
    return res.status(result.status).json(result.body);
  } catch (e) {
    await client.query('ROLLBACK');
    return res.status(500).json({ error: mensajeError, detalle: e.message });
  } finally {
    client.release();
  }
}

// =========================
// 1) Crear OT (CON KM SNAPSHOT)
// - mechanic_id SIEMPRE desde JWT
// - usuario_id también (porque tu tabla lo exige NOT NULL)
// - kilometraje_ot: km actual del vehículo al momento de crear la OT
// =========================
router.post("/", async (req, res) => {
  const { placa, symptoms, kilometraje } = req.body;

  if (!placa || !symptoms) {
    return res.status(400).json({ error: "Faltan datos (placa, symptoms)" });
  }

  const mechanicId = Number(req.user?.id);
  if (!mechanicId) {
    return res.status(401).json({ error: "Token válido pero sin id de usuario" });
  }

  const placaUpper = String(placa).trim().toUpperCase();
  if (!placaUpper || !String(symptoms).trim()) {
    return res.status(400).json({ error: 'Placa y síntomas son obligatorios' });
  }

  // El kilometraje con el que llega el auto se registra aquí, al crear la
  // OT (que es cuando el auto está físicamente presente) — no se asume
  // el valor guardado del vehículo, que puede estar desactualizado desde
  // la última visita. Si viene en el body, además se sincroniza con
  // vehiculos.kilometraje para que quede al día.
  const kmIngreso = Number.isFinite(Number(kilometraje)) && Number(kilometraje) > 0
    ? Number(kilometraje) : null;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const params = [placaUpper];
    const filtro = req.user.role === 'superuser' ? '' : ' AND mechanic_id = $2';
    if (filtro) params.push(mechanicId);
    const vehiculo = await client.query(
      `SELECT id, kilometraje FROM vehiculos WHERE placa = $1 AND archivado = false ${filtro} FOR UPDATE`, params,
    );
    if (!vehiculo.rowCount) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Vehículo no encontrado' });
    }

    let kmOt = kmIngreso;
    if (kmIngreso !== null) {
      // GREATEST evita que un typo al tipear el km de ingreso (ej. 8000 en
      // vez de 80000) deje el kilometraje del vehículo por debajo del que
      // ya tenía registrado; el snapshot de esta OT (kilometraje_ot) sigue
      // siendo el valor exacto que se ingresó, no el corregido.
      await client.query(
        `UPDATE vehiculos SET kilometraje = GREATEST(kilometraje, $1) WHERE placa = $2`,
        [kmIngreso, placaUpper]
      );
    } else {
      kmOt = Number(vehiculo.rows[0].kilometraje || 0);
    }

    const q = await client.query(
      `
      INSERT INTO ordenes_trabajo (
        placa, mechanic_id, usuario_id, symptoms,
        estado, pago_estado, total, kilometraje_ot, created_at
      )
      VALUES ($1, $2, $3, $4, 'RECIBIDO', 'PAGADO', 0, $5, NOW())
      RETURNING *;
      `,
      [placaUpper, mechanicId, mechanicId, String(symptoms), kmOt]
    );

    await client.query("COMMIT");
    return res.status(201).json(q.rows[0]);
  } catch (e) {
    await client.query("ROLLBACK");
    return res.status(500).json({ error: "Error creando OT", detalle: e.message });
  } finally {
    client.release();
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
        (SELECT p.nombre FROM vehiculos v LEFT JOIN propietarios p ON p.id=v.propietario_id WHERE v.placa=ot.placa) AS propietario_nombre,
        ot.estado, ot.pago_estado,
        ot.total_servicios, ot.total_repuestos, ot.total, ot.fase,
        (SELECT COALESCE(SUM(monto),0) FROM orden_pagos WHERE orden_id=ot.id) AS pagado,
        ot.kilometraje_ot,
        ot.created_at, ot.closed_at,
        COALESCE(act.actualizaciones_count, 0) AS actualizaciones_count,

        -- Estado lógico para UI
        CASE
          WHEN ot.estado = 'ENTREGADO' THEN 'ENTREGADO'
          WHEN ot.fase = 'LISTO' THEN 'LISTO'
          WHEN ot.fase = 'RECIBIDO' THEN 'RECIBIDO'
          WHEN ot.fase = 'EN_PROCESO' THEN 'PENDIENTE'
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

    const metadata = await pool.query(`SELECT v.marca, v.modelo, v.tipo_vehiculo, v.anio,
      p.nombre AS propietario_nombre, p.telefono AS propietario_telefono, p.email AS propietario_email,
      q.qr_token FROM vehiculos v LEFT JOIN propietarios p ON p.id=v.propietario_id
      LEFT JOIN vehiculo_qr q ON q.vehiculo_id=v.id AND q.activo=true WHERE v.placa=$1`, [ot.placa]);
    const checklists = await pool.query('SELECT * FROM orden_checklists WHERE orden_id=$1 ORDER BY tipo', [id]);
    const notas = await pool.query(`SELECT a.*, u.nombre AS autor FROM orden_anotaciones a
      JOIN usuarios u ON u.id=a.autor_id WHERE a.orden_id=$1 ORDER BY a.created_at DESC, a.id DESC`, [id]);
    return res.json({
      ot, vehiculo: metadata.rows[0] || {}, checklists: checklists.rows, anotaciones: notas.rows,
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

  req.auditText = 'Diagnostico actualizado';
  return modificarOtAbierta(req, res, 'Error actualizando diagnostico', async (client) => {
    const q = await client.query('UPDATE ordenes_trabajo SET diagnostico=$1 WHERE id=$2 RETURNING id, diagnostico', [diagnostico,id]);
    return {status:200, body:q.rows[0]};
  });
});

// =========================
// 3b) Fotos de la OT: subir / listar / eliminar
// =========================
function fotoUrl(ruta) {
  const base = process.env.APP_URL || "";
  return `${base}/uploads/${ruta}`;
}

async function documento(req,res,resolve,canAppendDelivery,operation) {
  const client=await pool.connect();
  try {
    await client.query('BEGIN');
    const entity=await resolve(client);
    if(!entity) {await client.query('ROLLBACK');borrarArchivosSubidos(req.files);return res.status(404).json({error:'Documento no encontrado'});}
    const q=await client.query(`SELECT * FROM ordenes_trabajo WHERE id=$1
      AND ($2::text='superuser' OR mechanic_id=$3) FOR UPDATE`,[entity.orden_id,req.user.role,req.user.id]);
    if(!q.rowCount) {await client.query('ROLLBACK');borrarArchivosSubidos(req.files);return res.status(404).json({error:'Orden no encontrada'});}
    if(q.rows[0].estado==='ENTREGADO' && !(canAppendDelivery && entity.tipo==='entrega')) {
      await client.query('ROLLBACK');borrarArchivosSubidos(req.files);
      return res.status(409).json({error:'El documento quedo cerrado al entregar. Agrega una anotacion fechada.'});
    }
    const result=await operation(client,entity);
    if(result.status>=400) {await client.query('ROLLBACK');borrarArchivosSubidos(req.files);}
    else {
      const route=req.route.path;
      const kind=route.includes('actualizaciones')?(route.includes('fotos')?'fotografía de un avance':'avance del trabajo'):
        route.includes('danos')?(route.includes('fotos')?'fotografía de un daño':'daño de la inspección'):'fotografía del vehículo';
      const action=req.method==='DELETE'?'Se eliminó':req.method==='PUT'?'Se actualizó':'Se registró';
      await client.query(`INSERT INTO orden_anotaciones (orden_id,autor_id,clase,texto) VALUES ($1,$2,'EVENTO',$3)`,
        [entity.orden_id,req.user.id,req.auditText || `${action} ${kind}${entity.tipo ? ` · ${entity.tipo}` : ''}`]);
      await client.query('COMMIT');
      for(const file of result.remove || [])fs.unlink(path.join(UPLOAD_DIR,file),()=>{});
    }
    return res.status(result.status).json(result.body);
  } catch(e) {await client.query('ROLLBACK');borrarArchivosSubidos(req.files);return res.status(500).json({error:'No se pudo guardar el documento'});}
  finally {client.release();}
}
const rootDocument=(req,tipo)=>async()=>({orden_id:Number(req.params.id),tipo});
const childDocument=(sql,id)=>async client=>(await client.query(sql,[Number(id)])).rows[0];
const bad=(res,message)=>res.status(400).json({error:message});

router.post('/:id/fotos',subirFotosMiddleware,(req,res)=>{
  const tipo=req.body.tipo;
  if(!['ingreso','entrega'].includes(tipo)) {borrarArchivosSubidos(req.files);return bad(res,'Tipo de foto invalido');}
  return documento(req,res,rootDocument(req,tipo),true,async(client,entity)=>{
    if(!req.files?.length)return {status:400,body:{error:'Selecciona una foto'}};
    const rows=[];
    for(const f of req.files) {
      const ruta=`ot_${entity.orden_id}/${f.filename}`;
      const q=await client.query('INSERT INTO orden_fotos (orden_id,tipo,ruta) VALUES ($1,$2,$3) RETURNING *',[entity.orden_id,tipo,ruta]);
      rows.push({...q.rows[0],url:fotoUrl(ruta)});
    }
    return {status:201,body:rows};
  });
});
router.delete('/fotos/:fotoId',(req,res)=>documento(req,res,
  childDocument('SELECT * FROM orden_fotos WHERE id=$1',req.params.fotoId),false,async(client,f)=>{
    await client.query('DELETE FROM orden_fotos WHERE id=$1',[f.id]);
    return {status:200,body:{mensaje:'Foto eliminada'},remove:[f.ruta]};
  }));
router.post('/:id/danos',(req,res)=>{
  const b=req.body,tipo=b.tipo || 'ingreso';
  if(!VISTAS_VALIDAS.has(b.vista) || !TIPOS_DANO_VALIDOS.has(tipo) || !String(b.zona||'').trim())return bad(res,'Vista, zona o etapa invalida');
  return documento(req,res,rootDocument(req,tipo),true,async(client,entity)=>{
    const q=await client.query(`INSERT INTO orden_danos (orden_id,tipo,vista,zona,estado_dano,tipo_reparacion,observaciones)
      VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,[entity.orden_id,tipo,b.vista,String(b.zona).trim().slice(0,160),
      b.estado_dano?String(b.estado_dano).trim().slice(0,160):null,b.tipo_reparacion?String(b.tipo_reparacion).trim().slice(0,160):null,b.observaciones?String(b.observaciones).trim().slice(0,500):null]);
    await client.query(`UPDATE orden_checklists SET revision_danos='CON_DANOS',revisado=false WHERE orden_id=$1 AND tipo=$2`,[entity.orden_id,tipo]);
    return {status:201,body:{...q.rows[0],fotos:[]}};
  });
});
router.put('/danos/:danoId',(req,res)=>{
  const b=req.body;
  if(b.tipo!==undefined && !TIPOS_DANO_VALIDOS.has(b.tipo))return bad(res,'Etapa invalida');
  return documento(req,res,childDocument('SELECT * FROM orden_danos WHERE id=$1',req.params.danoId),false,async(client,d)=>{
    const values=[d.id],sets=[];
    for(const col of ['tipo','estado_dano','tipo_reparacion','observaciones'])if(b[col]!==undefined){values.push(String(b[col]||'').trim().slice(0,col==='observaciones'?500:160)||null);sets.push(`${col}=$${values.length}`);}
    if(!sets.length)return {status:400,body:{error:'No hay campos para actualizar'}};
    const q=await client.query(`UPDATE orden_danos SET ${sets.join(',')} WHERE id=$1 RETURNING *`,values);
    await client.query(`UPDATE orden_checklists SET revisado=false,revision_danos='PENDIENTE' WHERE orden_id=$1`,[d.orden_id]);
    return {status:200,body:q.rows[0]};
  });
});
router.delete('/danos/:danoId',(req,res)=>documento(req,res,
  childDocument('SELECT * FROM orden_danos WHERE id=$1',req.params.danoId),false,async(client,d)=>{
    const photos=await client.query('SELECT ruta FROM orden_dano_fotos WHERE dano_id=$1',[d.id]);
    await client.query('DELETE FROM orden_danos WHERE id=$1',[d.id]);
    await client.query(`UPDATE orden_checklists SET revisado=false,revision_danos='PENDIENTE' WHERE orden_id=$1 AND tipo=$2`,[d.orden_id,d.tipo]);
    return {status:200,body:{mensaje:'Dano eliminado'},remove:photos.rows.map(f=>f.ruta)};
  }));
router.post('/danos/:danoId/fotos',subirDanoFotosMiddleware,(req,res)=>documento(req,res,
  childDocument('SELECT * FROM orden_danos WHERE id=$1',req.params.danoId),true,async(client,d)=>{
    if(!req.files?.length)return {status:400,body:{error:'Selecciona una foto'}};
    const rows=[];
    for(const f of req.files){const ruta=`dano_${d.id}/${f.filename}`;
      const q=await client.query('INSERT INTO orden_dano_fotos (dano_id,ruta) VALUES ($1,$2) RETURNING *',[d.id,ruta]);rows.push({...q.rows[0],url:fotoUrl(ruta)});}
    return {status:201,body:rows};
  }));
router.delete('/danos/fotos/:fotoId',(req,res)=>documento(req,res,
  childDocument('SELECT f.*,d.orden_id,d.tipo FROM orden_dano_fotos f JOIN orden_danos d ON d.id=f.dano_id WHERE f.id=$1',req.params.fotoId),false,async(client,f)=>{
    await client.query('DELETE FROM orden_dano_fotos WHERE id=$1',[f.id]);return {status:200,body:{mensaje:'Foto eliminada'},remove:[f.ruta]};
  }));
router.post('/:id/actualizaciones',(req,res)=>documento(req,res,rootDocument(req,'trabajo'),false,async(client,entity)=>{
  const nota=String(req.body.nota||'').trim().slice(0,1000)||null;
  const q=await client.query('INSERT INTO orden_actualizaciones (orden_id,nota) VALUES ($1,$2) RETURNING *',[entity.orden_id,nota]);
  return {status:201,body:{...q.rows[0],fotos:[]}};
}));
router.delete('/actualizaciones/:actId',(req,res)=>documento(req,res,
  childDocument('SELECT * FROM orden_actualizaciones WHERE id=$1',req.params.actId),false,async(client,a)=>{
    const photos=await client.query('SELECT ruta FROM orden_actualizacion_fotos WHERE actualizacion_id=$1',[a.id]);
    await client.query('DELETE FROM orden_actualizaciones WHERE id=$1',[a.id]);
    return {status:200,body:{mensaje:'Actualizacion eliminada'},remove:photos.rows.map(f=>f.ruta)};
  }));
router.post('/actualizaciones/:actId/fotos',subirActualizacionFotosMiddleware,(req,res)=>documento(req,res,
  childDocument('SELECT * FROM orden_actualizaciones WHERE id=$1',req.params.actId),false,async(client,a)=>{
    if(!req.files?.length)return {status:400,body:{error:'Selecciona una foto'}};
    const rows=[];for(const f of req.files){const ruta=`actualizacion_${a.id}/${f.filename}`;
      const q=await client.query('INSERT INTO orden_actualizacion_fotos (actualizacion_id,ruta) VALUES ($1,$2) RETURNING *',[a.id,ruta]);rows.push({...q.rows[0],url:fotoUrl(ruta)});}
    return {status:201,body:rows};
  }));
router.delete('/actualizaciones/fotos/:fotoId',(req,res)=>documento(req,res,
  childDocument('SELECT f.*,a.orden_id FROM orden_actualizacion_fotos f JOIN orden_actualizaciones a ON a.id=f.actualizacion_id WHERE f.id=$1',req.params.fotoId),false,async(client,f)=>{
    await client.query('DELETE FROM orden_actualizacion_fotos WHERE id=$1',[f.id]);return {status:200,body:{mensaje:'Foto eliminada'},remove:[f.ruta]};
  }));

// =========================
// 4) Agregar servicio (privado)
// =========================
router.post("/:id/servicios", async (req, res) => {
  const ordenId = Number(req.params.id);
  const { descripcion, precio } = req.body || {};

  if (!Number.isFinite(ordenId)) return res.status(400).json({ error: "id inválido" });
  if (!descripcion) return res.status(400).json({ error: "descripcion es obligatoria" });

  const precioNum = money(precio);
  if (precioNum === null) {
    return res.status(400).json({ error: "precio inválido" });
  }

  return modificarOtAbierta(req, res, "Error agregando servicio", async (client) => {
    const q = await client.query(
      `INSERT INTO orden_servicios (orden_id, descripcion, precio)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [ordenId, String(descripcion).trim(), precioNum]
    );

    await recalcularTotales(ordenId, client);
    await recalcularPagoEstado(ordenId, client);

    await marcarPendienteSiRecibido(ordenId, client);

    return { status: 201, body: q.rows[0] };
  });
});

// =========================
// 5) Agregar repuesto (privado)
// =========================
router.post("/:id/repuestos", async (req, res) => {
  const ordenId = Number(req.params.id);
  const { nombre, cantidad, costoUnitario, precioUnitario, inventarioId } = req.body || {};

  if (!Number.isFinite(ordenId)) return res.status(400).json({ error: "id inválido" });
  if (!nombre) return res.status(400).json({ error: "nombre es obligatorio" });

  const cantidadNum = Number(cantidad ?? 1);
  const costoNum = money(costoUnitario);
  const precioNum = money(precioUnitario);
  if (!Number.isSafeInteger(cantidadNum) || cantidadNum <= 0) {
    return res.status(400).json({ error: "cantidad inválida" });
  }
  if (costoNum === null) {
    return res.status(400).json({ error: "costo unitario inválido" });
  }
  if (precioNum === null) {
    return res.status(400).json({ error: "precio unitario inválido" });
  }

  return modificarOtAbierta(req, res, "Error agregando repuesto", async (client) => {
    let stock = null;
    if (inventarioId != null) {
      const item = await client.query(`SELECT * FROM inventario WHERE id=$1 AND activo=true
        AND ($2::text='superuser' OR mechanic_id=$3) FOR UPDATE`, [Number(inventarioId),req.user.role,req.user.id]);
      if (!item.rowCount) return {status:404,body:{error:'Repuesto de inventario no encontrado'}};
      stock=item.rows[0];
      if (stock.existencias < cantidadNum) return {status:409,body:{error:'Existencias insuficientes'}};
      await client.query('UPDATE inventario SET existencias=existencias-$1 WHERE id=$2', [cantidadNum,stock.id]);
      await client.query(`INSERT INTO inventario_movimientos (inventario_id,orden_id,autor_id,cantidad,motivo,operacion_id)
        VALUES ($1,$2,$3,$4,$5,$6)`, [stock.id,ordenId,req.user.id,-cantidadNum,'Uso en OT',crypto.randomUUID()]);
    }
    const q = await client.query(
      `INSERT INTO orden_repuestos (orden_id, nombre, cantidad, costo_unitario, precio_unitario)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [ordenId, stock ? stock.nombre : String(nombre).trim(), cantidadNum, stock ? Number(stock.costo) : costoNum, precioNum]
    );

    if (stock) await client.query('UPDATE orden_repuestos SET inventario_id=$1 WHERE id=$2', [stock.id,q.rows[0].id]);
    await recalcularTotales(ordenId, client);
    await recalcularPagoEstado(ordenId, client);
    await marcarPendienteSiRecibido(ordenId, client);
    return { status: 201, body: q.rows[0] };
  });
});

// =========================
// 6) Registrar pago (privado)
// =========================
router.post("/:id/pagos", async (req, res) => {
  const ordenId = Number(req.params.id);
  const {monto, metodo='EFECTIVO', operacionId} = req.body || {};
  const amount=money(monto);
  if (!Number.isSafeInteger(ordenId) || amount === null || amount <= 0) return res.status(400).json({error:'Monto o id invalido'});
  if (!['EFECTIVO','TRANSFERENCIA','TARJETA'].includes(metodo)) return res.status(400).json({error:'Metodo invalido'});
  if (operacionId != null && (typeof operacionId !== 'string' || !/^[a-zA-Z0-9_-]{16,100}$/.test(operacionId))) return res.status(400).json({error:'Identificador de operacion invalido'});
  req.auditText=`Pago registrado: $${amount.toFixed(2)} (${metodo})`;
  return modificarOtAbierta(req,res,'Error registrando pago',async client=>{
    const {total}=await recalcularTotales(ordenId,client);
    const paid=await getPagado(ordenId,client);
    if (cents(amount)>cents(total)-cents(paid)) return {status:409,body:{error:'El pago supera el saldo pendiente',saldo:Math.max(0,cents(total)-cents(paid))/100}};
    const q=await client.query(`INSERT INTO orden_pagos (orden_id,monto,metodo,operacion_id) VALUES ($1,$2,$3,$4) RETURNING *`,[ordenId,amount,metodo,operacionId || null]);
    await recalcularPagoEstado(ordenId,client);
    return {status:201,body:q.rows[0]};
  },async client=>{
    if (!operacionId) return null;
    const q=await client.query('SELECT * FROM orden_pagos WHERE orden_id=$1 AND operacion_id=$2',[ordenId,operacionId]);
    if (!q.rowCount) return null;
    if (cents(q.rows[0].monto)!==cents(amount) || q.rows[0].metodo!==metodo) return {status:409,body:{error:'La operacion ya se uso con otros datos'}};
    return {status:201,body:q.rows[0]};
  });
});

// =========================
// 7) Cerrar OT (privado)
// =========================
router.post("/:id/cerrar", async (req, res) => {
  const ordenId = Number(req.params.id);
  if (!Number.isFinite(ordenId)) return res.status(400).json({ error: "id inválido" });

  return modificarOtAbierta(req, res, "Error cerrando OT", async (client) => {
    const { total } = await recalcularTotales(ordenId, client);
    await recalcularPagoEstado(ordenId, client);

    // 🔒 No se puede entregar el vehículo si el pago no está completo.
    const pagado = await getPagado(ordenId, client);
    if (total > 0 && pagado < total) {
      const falta = (total - pagado).toFixed(2);
      return { status: 400, body: {
        error: `No se puede entregar: falta registrar el pago. Faltan $${falta} de $${total.toFixed(2)}.`,
      } };
    }

    const q = await client.query(
      `UPDATE ordenes_trabajo
       SET estado = 'ENTREGADO', fase='ENTREGADO',
           closed_at = NOW()
       WHERE id = $1
       RETURNING *`,
      [ordenId]
    );

    return { status: 200, body: q.rows[0] };
  });
});

export default router;
