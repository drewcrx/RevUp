import express from "express";
import { pool } from "../db/connection.js";
import { requireAuth, requireSuper } from "../src/middleware/auth.js";

const router = express.Router();


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

    return res.json({
      ingresos,
      gastos,
      utilidad: ingresos - gastos,
    });
  } catch (e) {
    return res.status(500).json({ error: "Error en mi resumen mensual", detalle: e.message });
  }
});


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
      )
      SELECT
        ot.id,
        ot.placa,
        ot.total,
        COALESCE(p.pagado, 0) AS pagado,
        ot.estado,
        ot.created_at
      FROM ordenes_trabajo ot
      LEFT JOIN pagos_ot p ON p.orden_id = ot.id
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


router.get("/mecanicos/:id/ordenes", async (req, res) => {
  try {
    const requestedId = Number(req.params.id);
    const month = normalizeMonth(req.query.month);
    if (!month) return res.status(400).json({ error: "Formato inválido. Usa month=YYYY-MM" });

    
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
      )
      SELECT
        ot.id,
        ot.placa,
        ot.total,
        COALESCE(p.pagado, 0) AS pagado,
        ot.estado,
        ot.created_at
      FROM ordenes_trabajo ot
      LEFT JOIN pagos_ot p ON p.orden_id = ot.id
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

    return res.json(q.rows[0]);
  } catch (e) {
    return res.status(500).json({ error: "Error en resumen mensual", detalle: e.message });
  }
});

export default router;
