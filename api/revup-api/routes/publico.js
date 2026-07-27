// routes/publico.js — página pública (sin login) para el QR de cada vehículo.
// Se muestra cuando alguien escanea el sticker con la cámara normal del
// celular (no con la app). Solo expone información no sensible: no incluye
// datos de contacto del propietario ni notas internas del taller.
import express from "express";
import { pool } from "../db/connection.js";
import { FAVICON_LINK_TAG } from "../utils/favicon.js";
import { escapeHtml } from "../utils/html.js";

const router = express.Router();

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const kBg     = "#04060D";
const kCard   = "#080E1A";
const kBlue   = "#1E90FF";
const kWhite  = "#F0F4FF";
const kBorder = "rgba(30,144,255,0.18)";

function estadoInfo(estadoUi) {
  switch (estadoUi) {
    case "ENTREGADO": return { label: "ENTREGADO", color: "#66BB6A" };
    case "PENDIENTE": return { label: "EN PROCESO", color: "#FFA726" };
    case "RECIBIDO":  return { label: "RECIBIDO",   color: "#00BFFF" };
    default:          return { label: "SIN INFORMACIÓN", color: kWhite };
  }
}

function pagoInfo(pagoEstado) {
  const pendiente = String(pagoEstado || "").toUpperCase().includes("PEND");
  return pendiente
    ? { label: "PAGO PENDIENTE", color: "#FFA726" }
    : { label: "PAGADO", color: "#66BB6A" };
}

function shellPage(bodyHtml, title) {
  return `<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>RevUp — ${title}</title>
  ${FAVICON_LINK_TAG}
  <style>
    *,*::before,*::after{box-sizing:border-box;margin:0;padding:0;}
    body{
      font-family:'Helvetica Neue',Arial,sans-serif;background:${kBg};color:${kWhite};
      min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px 16px;
    }
    .card{width:min(480px,100%);background:${kCard};border:1px solid ${kBorder};border-radius:16px;overflow:hidden;}
    .card-header{
      background:linear-gradient(135deg,#0A1628 0%,#060B18 100%);
      border-bottom:1px solid rgba(30,144,255,0.20);padding:14px 22px;
      display:flex;align-items:center;gap:9px;
    }
    .dot{width:8px;height:8px;background:${kBlue};border-radius:50%;flex-shrink:0;}
    .wordmark{font-size:12px;font-weight:800;letter-spacing:3px;color:${kWhite};}
    .tagline{font-size:10px;color:rgba(30,144,255,0.60);letter-spacing:1.2px;font-weight:600;margin-left:4px;}
    .card-body{padding:26px 24px;}
    .placa{
      display:inline-block;padding:6px 14px;border-radius:8px;background:rgba(30,144,255,0.12);
      border:1px solid rgba(30,144,255,0.30);color:${kBlue};font-weight:800;font-size:18px;letter-spacing:1.5px;
    }
    .subtitle{margin-top:10px;font-size:13px;color:rgba(240,244,255,0.45);}
    .chips{margin-top:18px;display:flex;gap:8px;flex-wrap:wrap;}
    .chip{padding:6px 12px;border-radius:999px;font-size:11px;font-weight:800;letter-spacing:0.5px;}
    .divider{height:1px;background:linear-gradient(90deg,transparent,rgba(30,144,255,0.14),transparent);margin:20px 0;}
    .row{display:flex;justify-content:space-between;padding:8px 0;font-size:13px;}
    .row .k{color:rgba(240,244,255,0.45);}
    .row .v{color:${kWhite};font-weight:700;}
    .msg{font-size:14px;color:rgba(240,244,255,0.55);line-height:1.6;}
    .hist-title{margin-top:22px;margin-bottom:10px;font-size:12px;font-weight:800;letter-spacing:0.5px;color:rgba(240,244,255,0.55);}
    .hist-item{padding:12px;margin-bottom:8px;border-radius:10px;background:rgba(30,144,255,0.04);border:1px solid rgba(30,144,255,0.10);}
    .hist-top{display:flex;justify-content:space-between;align-items:center;gap:8px;}
    .hist-date{font-size:11px;color:rgba(240,244,255,0.35);}
    .hist-sintomas{margin-top:6px;font-size:12px;color:rgba(240,244,255,0.60);line-height:1.4;}
    .hist-bottom{margin-top:8px;display:flex;justify-content:space-between;align-items:center;}
    .hist-total{font-size:13px;font-weight:800;color:${kBlue};}
    .note{margin-top:18px;font-size:11px;color:rgba(240,244,255,0.28);line-height:1.5;text-align:center;}
    .card-footer{
      padding:12px 22px;border-top:1px solid rgba(30,144,255,0.08);background:#060B18;
      display:flex;justify-content:space-between;align-items:center;
    }
    .footer-copy{font-size:10px;color:rgba(240,244,255,0.18);}
    .footer-brand{font-size:10px;color:rgba(30,144,255,0.35);font-weight:600;letter-spacing:0.5px;}
  </style>
</head>
<body>
  <div class="card">
    <div class="card-header">
      <div class="dot"></div>
      <span class="wordmark">REVUP</span>
      <span class="tagline">MÁS CONTROL. MÁS RENDIMIENTO.</span>
    </div>
    <div class="card-body">
      ${bodyHtml}
    </div>
    <div class="card-footer">
      <span class="footer-copy">© ${new Date().getFullYear()} RevUp · Andrew Carrera</span>
      <span class="footer-brand">revup.app</span>
    </div>
  </div>
</body>
</html>`;
}

function renderNoEncontrado() {
  return shellPage(`
    <p class="msg">
      No encontramos ningún vehículo con este código QR. Si crees que es un
      error, contacta al taller donde se realizó el servicio.
    </p>
  `, "Código no válido");
}

function renderVehiculo(v, ots) {
  const actual = ots[0] || null;
  const est  = actual ? estadoInfo(actual.estado_ui) : { label: "SIN ÓRDENES REGISTRADAS", color: kWhite };
  const pago = actual ? pagoInfo(actual.pago_estado) : null;
  const placa = escapeHtml(v.placa);
  const nombreVehiculo = escapeHtml([v.marca, v.modelo].filter(Boolean).join(" ") || "Vehículo");
  const detalles = escapeHtml([v.anio, v.color].filter(Boolean).join(" · "));

  const historial = ots.length
    ? ots.map((o) => {
        const oEst  = estadoInfo(o.estado_ui);
        const oPago = pagoInfo(o.pago_estado);
        const fecha = new Date(o.created_at).toLocaleDateString("es-EC");
        const km = Number(o.kilometraje_ot || 0) > 0
          ? `${Number(o.kilometraje_ot).toLocaleString("es-EC")} km` : "";
        const sintomas = escapeHtml(o.symptoms || "");
        return `
          <div class="hist-item">
            <div class="hist-top">
              <span class="chip" style="background:${oEst.color}22;color:${oEst.color};border:1px solid ${oEst.color}55;">${oEst.label}</span>
              <span class="hist-date">${fecha}${km ? " · " + km : ""}</span>
            </div>
            ${sintomas ? `<div class="hist-sintomas">${sintomas}</div>` : ""}
            <div class="hist-bottom">
              <span class="chip" style="background:${oPago.color}22;color:${oPago.color};border:1px solid ${oPago.color}55;">${oPago.label}</span>
              <span class="hist-total">$${Number(o.total || 0).toFixed(2)}</span>
            </div>
          </div>
        `;
      }).join("")
    : `<p class="msg">Este vehículo todavía no tiene órdenes de trabajo registradas.</p>`;

  return shellPage(`
    <span class="placa">${placa}</span>
    <div class="subtitle">${nombreVehiculo}${detalles ? " · " + detalles : ""}</div>

    <div class="chips">
      <span class="chip" style="background:${est.color}22;color:${est.color};border:1px solid ${est.color}55;">${est.label}</span>
      ${pago ? `<span class="chip" style="background:${pago.color}22;color:${pago.color};border:1px solid ${pago.color}55;">${pago.label}</span>` : ""}
    </div>

    <div class="divider"></div>

    <div class="hist-title">HISTORIAL DE ÓRDENES (${ots.length})</div>
    ${historial}

    <p class="note">Esta información se actualiza en tiempo real. Para más detalle, contacta al taller.</p>
  `, `${placa} — Estado del vehículo`);
}

router.get("/:token", async (req, res) => {
  const token = String(req.params.token || "").trim();
  if (!token) return res.status(400).send(renderNoEncontrado());

  try {
    const vq = await pool.query(
      `SELECT v.placa, v.marca, v.modelo, v.anio, v.color
       FROM vehiculos v
       JOIN vehiculo_qr q ON q.vehiculo_id = v.id
       WHERE q.qr_token = $1 AND q.activo = true
       LIMIT 1`,
      [token]
    );

    if (vq.rowCount === 0) {
      return res.status(404).send(renderNoEncontrado());
    }

    const v = vq.rows[0];

    const otq = await pool.query(
      `SELECT
         symptoms, estado, pago_estado, total, kilometraje_ot, created_at,
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
       ORDER BY created_at DESC
       LIMIT 25`,
      [v.placa]
    );

    return res.send(renderVehiculo(v, otq.rows));
  } catch (e) {
    return res.status(500).send(renderNoEncontrado());
  }
});

export default router;
