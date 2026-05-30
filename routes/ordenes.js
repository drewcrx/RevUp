import express from "express";
import { pool } from "../db/connection.js";
import { requireAuth } from "../src/middleware/auth.js";

const router = express.Router();

router.use(requireAuth);


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

async function marcarPendienteSiRecibido(ordenId) {
  await pool.query(
    `UPDATE ordenes_trabajo
     SET estado = 'PENDIENTE'
     WHERE id = $1
       AND estado = 'RECIBIDO'`,
    [ordenId]
  );
}

async function getOtIfAllowed(ordenId, user) {
  const params = [ordenId];
  let extra = "";

  if (user.role !== "superuser") {
    params.push(user.id);
    extra = " AND mechanic_id = $2";
  }

  const ot = await pool.query(
    `SELECT *
     FROM ordenes_trabajo
     WHERE id = $1
     ${extra}`,
    params
  );

  return ot.rowCount ? ot.rows[0] : null;
}


router.post("/", async (req, res) => {
  try {
    const { placa, symptoms } = req.body;

    if (!placa || !symptoms) {
      return res.status(400).json({ error: "Faltan datos (placa, symptoms)" });
    }

    const mechanicId = Number(req.user?.id);
    if (!mechanicId) {
      return res.status(401).json({ error: "Token válido pero sin id de usuario" });
    }

    const placaUpper = String(placa).toUpperCase();

    
    const vk = await pool.query(
      `SELECT kilometraje
       FROM vehiculos
       WHERE placa = $1
       LIMIT 1`,
      [placaUpper]
    );

    
    const kmOt = vk.rowCount ? Number(vk.rows[0].kilometraje || 0) : null;

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
        id, placa, mechanic_id, usuario_id, symptoms,
        estado, pago_estado,
        total_servicios, total_repuestos, total,
        kilometraje_ot, -- ✅ NUEVO
        created_at, closed_at,

        -- ✅ NUEVO: Estado lógico para UI
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
      ${where.length ? `WHERE ${where.join(" AND ")}` : ""}
      ORDER BY created_at DESC
    `;

    const q = await pool.query(sql, params);
    return res.json(q.rows);
  } catch (e) {
    return res.status(500).json({ error: "Error listando OTs", detalle: e.message });
  }
});


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

    return res.json({
      ot,
      servicios: servicios.rows,
      repuestos: repuestos.rows,
      pagos: pagos.rows,
    });
  } catch (e) {
    return res.status(500).json({ error: "Error cargando detalle", detalle: e.message });
  }
});


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


router.post("/:id/cerrar", async (req, res) => {
  const ordenId = Number(req.params.id);
  if (!Number.isFinite(ordenId)) return res.status(400).json({ error: "id inválido" });

  try {
    const ot = await getOtIfAllowed(ordenId, req.user);
    if (!ot) return res.status(404).json({ error: "OT no encontrada" });

    await recalcularTotales(ordenId);
    await recalcularPagoEstado(ordenId);

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