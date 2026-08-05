// routes/reportes.js
import express from "express";
import { pool } from "../db/connection.js";
import { requireAuth, requireSuper } from "../src/middleware/auth.js";

const router = express.Router();

// Todo este router exige sesión
router.use(requireAuth);

function normalizeMonth(maybeMonth) {
  let month = String(maybeMonth || "").trim();

  if (!month) {
    const now = new Date();
    const m = String(now.getMonth() + 1).padStart(2, "0");
    month = `${now.getFullYear()}-${m}`;
  }

  if (!/^\d{4}-\d{2}$/.test(month)) return null;
  return month;
}

/**
 * GET /reportes/mi-resumen?month=YYYY-MM
 * Resumen mensual del mecánico logueado (NO requiere superuser)
 */
router.get("/mi-resumen", async (req, res) => {
  try {
    const month = normalizeMonth(req.query.month);
    if (!month) return res.status(400).json({ error: "Formato inválido. Usa month=YYYY-MM" });

    const start = `${month}-01`;
    const mechanicId = Number(req.user.id);

    const q = await pool.query(
      `
      WITH rango AS (
        SELECT
          $1::date AS inicio,
          (date_trunc('month', $1::date) + interval '1 month')::date AS fin
      ),
      mis_ots AS (
        SELECT ot.id
        FROM ordenes_trabajo ot, rango r
        WHERE ot.mechanic_id = $2
          AND ot.created_at >= r.inicio
          AND ot.created_at < r.fin
      )
      SELECT
        -- ingresos = pagos del mes SOLO de mis ots
        COALESCE((
          SELECT SUM(p.monto)
          FROM orden_pagos p
          JOIN mis_ots mo ON mo.id = p.orden_id
          JOIN rango r ON p.created_at >= r.inicio AND p.created_at < r.fin
        ), 0) AS ingresos,

        -- gastos = repuestos del mes SOLO de mis ots
        COALESCE((
          SELECT SUM(rp.cantidad * rp.costo_unitario)
          FROM orden_repuestos rp
          JOIN mis_ots mo ON mo.id = rp.orden_id
          JOIN rango rr ON rp.created_at >= rr.inicio AND rp.created_at < rr.fin
        ), 0) AS gastos
      `,
      [start, mechanicId]
    );

    const row = q.rows[0] || { ingresos: 0, gastos: 0 };
    const ingresos = Number(row.ingresos || 0);
    const gastos = Number(row.gastos || 0);

    const repuestosTop = await pool.query(
      `SELECT rp.nombre,
              SUM(rp.cantidad) AS cantidad_total,
              SUM(rp.cantidad * rp.precio_unitario) AS monto_total
       FROM orden_repuestos rp
       JOIN ordenes_trabajo ot ON ot.id = rp.orden_id
       WHERE ot.mechanic_id = $1
         AND rp.created_at >= $2::date
         AND rp.created_at < (date_trunc('month', $2::date) + interval '1 month')::date
       GROUP BY rp.nombre
       ORDER BY cantidad_total DESC
       LIMIT 5`,
      [mechanicId, start]
    );

    const danosPorEstado = await pool.query(
      `SELECT od.estado_dano, COUNT(*) AS cantidad
       FROM orden_danos od
       JOIN ordenes_trabajo ot ON ot.id = od.orden_id
       WHERE ot.mechanic_id = $1
         AND od.estado_dano IS NOT NULL
         AND od.created_at >= $2::date
         AND od.created_at < (date_trunc('month', $2::date) + interval '1 month')::date
       GROUP BY od.estado_dano
       ORDER BY cantidad DESC`,
      [mechanicId, start]
    );

    // Transparencia con el cliente: cuántas actualizaciones se publicaron y
    // qué porcentaje de las OTs del mes quedaron con diagnóstico registrado.
    const actualizacionesMes = await pool.query(
      `SELECT COUNT(*) AS cantidad
       FROM orden_actualizaciones oa
       JOIN ordenes_trabajo ot ON ot.id = oa.orden_id
       WHERE ot.mechanic_id = $1
         AND oa.created_at >= $2::date
         AND oa.created_at < (date_trunc('month', $2::date) + interval '1 month')::date`,
      [mechanicId, start]
    );

    const diagnosticoMes = await pool.query(
      `SELECT COUNT(*) AS total,
              COUNT(*) FILTER (WHERE diagnostico IS NOT NULL AND trim(diagnostico) <> '') AS con_diagnostico
       FROM ordenes_trabajo
       WHERE mechanic_id = $1
         AND created_at >= $2::date
         AND created_at < (date_trunc('month', $2::date) + interval '1 month')::date`,
      [mechanicId, start]
    );

    return res.json({
      ingresos,
      gastos,
      utilidad: ingresos - gastos,
      repuestos_top: repuestosTop.rows,
      danos_por_estado: danosPorEstado.rows,
      actualizaciones_mes: Number(actualizacionesMes.rows[0]?.cantidad || 0),
      ots_con_diagnostico: Number(diagnosticoMes.rows[0]?.con_diagnostico || 0),
      ots_total_mes: Number(diagnosticoMes.rows[0]?.total || 0),
    });
  } catch (e) {
    return res.status(500).json({ error: "Error en mi resumen mensual", detalle: e.message });
  }
});

/**
 * GET /reportes/mi-mes/ordenes?month=YYYY-MM
 * OTs del mecánico logueado en ese mes (NO requiere superuser)
 */
router.get("/mi-mes/ordenes", async (req, res) => {
  try {
    const month = normalizeMonth(req.query.month);
    if (!month) return res.status(400).json({ error: "Formato inválido. Usa month=YYYY-MM" });

    const start = `${month}-01`;
    const mechanicId = Number(req.user.id);

    const q = await pool.query(
      `
      WITH rango AS (
        SELECT
          $1::date AS inicio,
          (date_trunc('month', $1::date) + interval '1 month')::date AS fin
      ),
      pagos_ot AS (
        SELECT orden_id, SUM(monto) AS pagado
        FROM orden_pagos
        GROUP BY orden_id
      ),
      act_ot AS (
        SELECT orden_id, COUNT(*) AS actualizaciones_count
        FROM orden_actualizaciones
        GROUP BY orden_id
      )
      SELECT
        ot.id,
        ot.placa,
        ot.total,
        COALESCE(p.pagado, 0) AS pagado,
        ot.estado,
        ot.diagnostico,
        ot.closed_at,
        COALESCE(a.actualizaciones_count, 0) AS actualizaciones_count,
        ot.created_at
      FROM ordenes_trabajo ot
      LEFT JOIN pagos_ot p ON p.orden_id = ot.id
      LEFT JOIN act_ot a ON a.orden_id = ot.id
      JOIN rango r
        ON ot.created_at >= r.inicio
       AND ot.created_at < r.fin
      WHERE ot.mechanic_id = $2
      ORDER BY ot.created_at DESC;
      `,
      [start, mechanicId]
    );

    return res.json(q.rows);
  } catch (e) {
    return res.status(500).json({ error: "Error obteniendo mis OTs del mes", detalle: e.message });
  }
});


/**
 * GET /reportes/mecanicos?month=YYYY-MM
 * Resumen mensual por mecánico (SOLO SUPERUSER)
 */
router.get("/mecanicos", requireSuper, async (req, res) => {
  try {
    const month = normalizeMonth(req.query.month);
    if (!month) return res.status(400).json({ error: "Formato inválido. Usa month=YYYY-MM" });

    const start = `${month}-01`;

    const q = await pool.query(
      `
      WITH rango AS (
        SELECT
          $1::date AS inicio,
          (date_trunc('month', $1::date) + interval '1 month')::date AS fin
      ),
      ots AS (
        SELECT ot.*
        FROM ordenes_trabajo ot, rango r
        WHERE ot.created_at >= r.inicio
          AND ot.created_at < r.fin
      ),
      pagos_mes AS (
        SELECT p.orden_id, SUM(p.monto) AS pagado_mes
        FROM orden_pagos p, rango r
        WHERE p.created_at >= r.inicio
          AND p.created_at < r.fin
        GROUP BY p.orden_id
      ),
      gastos_ot AS (
        SELECT r.orden_id,
               SUM(r.cantidad * r.costo_unitario) AS gasto_repuestos
        FROM orden_repuestos r
        GROUP BY r.orden_id
      )
      SELECT
        u.id AS mechanic_id,
        u.nombre AS mechanic_nombre,
        COUNT(ot.id) AS ots,
        COALESCE(SUM(ot.total), 0) AS total_ot,
        COALESCE(SUM(pm.pagado_mes), 0) AS total_pagado_mes,
        COALESCE(SUM(go.gasto_repuestos), 0) AS total_gastos,
        COALESCE(SUM(ot.total), 0) - COALESCE(SUM(go.gasto_repuestos), 0) AS utilidad_estimada
      FROM usuarios u
      LEFT JOIN ots ot ON ot.mechanic_id = u.id
      LEFT JOIN pagos_mes pm ON pm.orden_id = ot.id
      LEFT JOIN gastos_ot go ON go.orden_id = ot.id
      GROUP BY u.id, u.nombre
      ORDER BY total_ot DESC, u.nombre ASC;
      `,
      [start]
    );

    return res.json(q.rows);
  } catch (e) {
    return res.status(500).json({ error: "Error generando reporte", detalle: e.message });
  }
});

/**
 * GET /reportes/mecanicos/:id/ordenes?month=YYYY-MM
 * OTs de un mecánico en un mes (SUPERUSER o el MISMO mecánico)
 */
router.get("/mecanicos/:id/ordenes", async (req, res) => {
  try {
    const requestedId = Number(req.params.id);
    const month = normalizeMonth(req.query.month);
    if (!month) return res.status(400).json({ error: "Formato inválido. Usa month=YYYY-MM" });

    // Si no es superuser, solo puede consultar SU PROPIO id
    if (req.user.role !== "superuser" && requestedId !== Number(req.user.id)) {
      return res.status(403).json({ error: "No autorizado" });
    }

    const start = `${month}-01`;

    const q = await pool.query(
      `
      WITH rango AS (
        SELECT
          $1::date AS inicio,
          (date_trunc('month', $1::date) + interval '1 month')::date AS fin
      ),
      pagos_ot AS (
        SELECT orden_id, SUM(monto) AS pagado
        FROM orden_pagos
        GROUP BY orden_id
      ),
      act_ot AS (
        SELECT orden_id, COUNT(*) AS actualizaciones_count
        FROM orden_actualizaciones
        GROUP BY orden_id
      )
      SELECT
        ot.id,
        ot.placa,
        ot.total,
        COALESCE(p.pagado, 0) AS pagado,
        ot.estado,
        ot.diagnostico,
        ot.closed_at,
        COALESCE(a.actualizaciones_count, 0) AS actualizaciones_count,
        ot.created_at
      FROM ordenes_trabajo ot
      LEFT JOIN pagos_ot p ON p.orden_id = ot.id
      LEFT JOIN act_ot a ON a.orden_id = ot.id
      JOIN rango r
        ON ot.created_at >= r.inicio
       AND ot.created_at < r.fin
      WHERE ot.mechanic_id = $2
      ORDER BY ot.created_at DESC;
      `,
      [start, requestedId]
    );

    return res.json(q.rows);
  } catch (e) {
    return res.status(500).json({ error: "Error obteniendo OTs", detalle: e.message });
  }
});

/**
 * GET /reportes/resumen?month=YYYY-MM
 * Resumen global mensual del taller (SOLO SUPERUSER)
 */
router.get("/resumen", requireSuper, async (req, res) => {
  try {
    const month = normalizeMonth(req.query.month);
    if (!month) return res.status(400).json({ error: "Formato inválido. Usa month=YYYY-MM" });

    const start = `${month}-01`;

    const q = await pool.query(
      `
      WITH rango AS (
        SELECT
          $1::date AS inicio,
          (date_trunc('month', $1::date) + interval '1 month')::date AS fin
      )
      SELECT
        COALESCE(SUM(p.monto), 0) AS ingresos,
        COALESCE(SUM(r.cantidad * r.costo_unitario), 0) AS gastos,
        COALESCE(SUM(p.monto), 0) - COALESCE(SUM(r.cantidad * r.costo_unitario), 0) AS utilidad
      FROM rango ra
      LEFT JOIN orden_pagos p
        ON p.created_at >= ra.inicio AND p.created_at < ra.fin
      LEFT JOIN orden_repuestos r
        ON r.created_at >= ra.inicio AND r.created_at < ra.fin;
      `,
      [start]
    );

    const repuestosTop = await pool.query(
      `SELECT nombre,
              SUM(cantidad) AS cantidad_total,
              SUM(cantidad * precio_unitario) AS monto_total
       FROM orden_repuestos
       WHERE created_at >= $1::date
         AND created_at < (date_trunc('month', $1::date) + interval '1 month')::date
       GROUP BY nombre
       ORDER BY cantidad_total DESC
       LIMIT 5`,
      [start]
    );

    const danosPorEstado = await pool.query(
      `SELECT estado_dano, COUNT(*) AS cantidad
       FROM orden_danos
       WHERE estado_dano IS NOT NULL
         AND created_at >= $1::date
         AND created_at < (date_trunc('month', $1::date) + interval '1 month')::date
       GROUP BY estado_dano
       ORDER BY cantidad DESC`,
      [start]
    );

    const actualizacionesMes = await pool.query(
      `SELECT COUNT(*) AS cantidad
       FROM orden_actualizaciones
       WHERE created_at >= $1::date
         AND created_at < (date_trunc('month', $1::date) + interval '1 month')::date`,
      [start]
    );

    const diagnosticoMes = await pool.query(
      `SELECT COUNT(*) AS total,
              COUNT(*) FILTER (WHERE diagnostico IS NOT NULL AND trim(diagnostico) <> '') AS con_diagnostico
       FROM ordenes_trabajo
       WHERE created_at >= $1::date
         AND created_at < (date_trunc('month', $1::date) + interval '1 month')::date`,
      [start]
    );

    return res.json({
      ...q.rows[0],
      repuestos_top: repuestosTop.rows,
      danos_por_estado: danosPorEstado.rows,
      actualizaciones_mes: Number(actualizacionesMes.rows[0]?.cantidad || 0),
      ots_con_diagnostico: Number(diagnosticoMes.rows[0]?.con_diagnostico || 0),
      ots_total_mes: Number(diagnosticoMes.rows[0]?.total || 0),
    });
  } catch (e) {
    return res.status(500).json({ error: "Error en resumen mensual", detalle: e.message });
  }
});

export default router;
