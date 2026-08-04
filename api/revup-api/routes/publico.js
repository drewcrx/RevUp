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

const VISTA_LABELS = {
  frontal: "Frontal",
  posterior: "Posterior",
  lateral_izquierdo: "Lateral izquierdo",
  lateral_derecho: "Lateral derecho",
  superior: "Superior",
};

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
    .ficha{margin-top:14px;display:grid;grid-template-columns:1fr 1fr;gap:9px 16px;}
    .ficha .k{font-size:10px;color:rgba(240,244,255,0.35);text-transform:uppercase;letter-spacing:0.5px;}
    .ficha .v{font-size:13px;color:${kWhite};font-weight:700;margin-top:2px;}
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
    .fotos-grupo{margin-top:10px;}
    .fotos-label{font-size:10px;font-weight:800;letter-spacing:0.5px;color:rgba(240,244,255,0.35);margin-bottom:5px;}
    .fotos-grid{display:flex;gap:6px;flex-wrap:wrap;}
    .fotos-grid a{display:block;width:56px;height:56px;border-radius:8px;overflow:hidden;border:1px solid rgba(30,144,255,0.20);}
    .fotos-grid img{width:100%;height:100%;object-fit:cover;display:block;}
    .danos-grupo{margin-top:12px;padding-top:10px;border-top:1px dashed rgba(30,144,255,0.14);}
    .danos-label{font-size:10px;font-weight:800;letter-spacing:0.5px;color:rgba(240,244,255,0.35);margin-bottom:6px;}
    .dano-item{padding:8px 10px;margin-bottom:6px;border-radius:8px;background:rgba(255,167,38,0.05);border:1px solid rgba(255,167,38,0.18);}
    .dano-top{display:flex;justify-content:space-between;gap:8px;font-size:11px;color:#FFA726;font-weight:700;}
    .dano-obs{margin-top:4px;font-size:11px;color:rgba(240,244,255,0.55);line-height:1.4;}
    .trabajo-grupo{margin-top:12px;padding-top:10px;border-top:1px dashed rgba(30,144,255,0.14);}
    .trabajo-label{font-size:10px;font-weight:800;letter-spacing:0.5px;color:rgba(240,244,255,0.35);margin-bottom:6px;}
    .trabajo-item{display:flex;justify-content:space-between;gap:8px;font-size:12px;padding:3px 0;color:rgba(240,244,255,0.65);}
    .trabajo-item .precio{color:${kBlue};font-weight:700;flex-shrink:0;}
    .diagnostico-block{margin-top:10px;padding:10px 12px;border-radius:8px;background:rgba(30,144,255,0.05);border:1px solid rgba(30,144,255,0.14);}
    .diagnostico-label{font-size:10px;font-weight:800;letter-spacing:0.5px;color:${kBlue};margin-bottom:4px;}
    .diagnostico-texto{font-size:12px;color:rgba(240,244,255,0.70);line-height:1.5;white-space:pre-wrap;}
    .act-grupo{margin-top:12px;padding-top:10px;border-top:1px dashed rgba(30,144,255,0.14);}
    .act-label{font-size:10px;font-weight:800;letter-spacing:0.5px;color:rgba(240,244,255,0.35);margin-bottom:6px;}
    .act-item{padding:8px 10px;margin-bottom:6px;border-radius:8px;background:rgba(255,167,38,0.04);border:1px solid rgba(255,167,38,0.16);}
    .act-fecha{font-size:10px;color:rgba(240,244,255,0.35);margin-bottom:3px;}
    .act-nota{font-size:12px;color:rgba(240,244,255,0.70);line-height:1.4;}
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

  const fichaCampos = [
    ["Kilometraje", Number(v.kilometraje || 0) > 0 ? `${Number(v.kilometraje).toLocaleString("es-EC")} km` : null],
    ["Tipo", v.tipo_vehiculo],
    ["Combustible", v.tipo_combustible],
    ["Transmisión", v.transmision],
    ["Cilindraje", v.cilindraje],
  ].filter(([, val]) => val);
  const ficha = fichaCampos.length ? `
    <div class="ficha">
      ${fichaCampos.map(([k, val]) => `
        <div><div class="k">${escapeHtml(k)}</div><div class="v">${escapeHtml(String(val))}</div></div>
      `).join("")}
    </div>` : "";

  const historial = ots.length
    ? ots.map((o) => {
        const oEst  = estadoInfo(o.estado_ui);
        const oPago = pagoInfo(o.pago_estado);
        const fecha = new Date(o.created_at).toLocaleDateString("es-EC");
        const km = Number(o.kilometraje_ot || 0) > 0
          ? `${Number(o.kilometraje_ot).toLocaleString("es-EC")} km` : "";
        const sintomas = escapeHtml(o.symptoms || "");
        const fotosIngreso = (o.fotos || []).filter((f) => f.tipo === "ingreso");
        const fotosEntrega = (o.fotos || []).filter((f) => f.tipo === "entrega");

        const grupoFotos = (label, fotos) => fotos.length ? `
          <div class="fotos-grupo">
            <div class="fotos-label">${label} (${fotos.length})</div>
            <div class="fotos-grid">
              ${fotos.map((f) => `<a href="${f.url}" target="_blank" rel="noopener"><img src="${f.url}" loading="lazy" /></a>`).join("")}
            </div>
          </div>` : "";

        const servicios = o.servicios || [];
        const repuestos = o.repuestos || [];
        const trabajo = (servicios.length || repuestos.length) ? `
          <div class="trabajo-grupo">
            <div class="trabajo-label">TRABAJO REALIZADO</div>
            ${servicios.map((s) => `
              <div class="trabajo-item">
                <span>${escapeHtml(s.descripcion || "Servicio")}</span>
                <span class="precio">$${Number(s.precio || 0).toFixed(2)}</span>
              </div>`).join("")}
            ${repuestos.map((r) => `
              <div class="trabajo-item">
                <span>${escapeHtml(r.nombre || "Repuesto")}${Number(r.cantidad || 1) > 1 ? ` ×${Number(r.cantidad)}` : ""}</span>
                <span class="precio">$${(Number(r.precio_unitario || 0) * Number(r.cantidad || 1)).toFixed(2)}</span>
              </div>`).join("")}
          </div>` : "";

        const danos = o.danos || [];
        const danoItemHtml = (d) => {
          const vista = escapeHtml(VISTA_LABELS[d.vista] || d.vista);
          const zona = escapeHtml(d.zona);
          const estado = escapeHtml(d.estado_dano || "");
          const reparacion = escapeHtml(d.tipo_reparacion || "");
          const obs = escapeHtml(d.observaciones || "");
          const fotosD = d.fotos || [];
          return `
            <div class="dano-item">
              <div class="dano-top">
                <span>${vista} · ${zona}</span>
                <span>${estado}${reparacion ? " · " + reparacion : ""}</span>
              </div>
              ${obs ? `<div class="dano-obs">${obs}</div>` : ""}
              ${fotosD.length ? `<div class="fotos-grid" style="margin-top:6px;">
                ${fotosD.map((url) => `<a href="${url}" target="_blank" rel="noopener"><img src="${url}" loading="lazy" /></a>`).join("")}
              </div>` : ""}
            </div>
          `;
        };
        const danosIngreso = danos.filter((d) => d.tipo !== "entrega");
        const danosEntrega = danos.filter((d) => d.tipo === "entrega");
        const grupoDanosTipo = (label, lista) => lista.length ? `
          <div class="danos-grupo">
            <div class="danos-label">${label} (${lista.length})</div>
            ${lista.map(danoItemHtml).join("")}
          </div>` : "";
        const grupoDanos = danosIngreso.length || danosEntrega.length
          ? `${grupoDanosTipo("DAÑOS AL INGRESAR", danosIngreso)}${grupoDanosTipo("DAÑOS AL ENTREGAR", danosEntrega)}`
          : "";

        const diagnostico = escapeHtml(o.diagnostico || "");
        const diagnosticoHtml = diagnostico ? `
          <div class="diagnostico-block">
            <div class="diagnostico-label">DIAGNÓSTICO DEL MECÁNICO</div>
            <div class="diagnostico-texto">${diagnostico}</div>
          </div>` : "";

        const entregadoEl = o.closed_at
          ? `Entregado el ${new Date(o.closed_at).toLocaleDateString("es-EC")}` : "";

        const actualizaciones = o.actualizaciones || [];
        const actualizacionesHtml = actualizaciones.length ? `
          <div class="act-grupo">
            <div class="act-label">ACTUALIZACIONES DURANTE EL TRABAJO (${actualizaciones.length})</div>
            ${actualizaciones.map((a) => {
              const fechaAct = new Date(a.created_at).toLocaleString("es-EC",
                { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" });
              const nota = escapeHtml(a.nota || "");
              const fotosA = a.fotos || [];
              return `
                <div class="act-item">
                  <div class="act-fecha">${fechaAct}</div>
                  ${nota ? `<div class="act-nota">${nota}</div>` : ""}
                  ${fotosA.length ? `<div class="fotos-grid" style="margin-top:6px;">
                    ${fotosA.map((url) => `<a href="${url}" target="_blank" rel="noopener"><img src="${url}" loading="lazy" /></a>`).join("")}
                  </div>` : ""}
                </div>
              `;
            }).join("")}
          </div>` : "";

        return `
          <div class="hist-item">
            <div class="hist-top">
              <span class="chip" style="background:${oEst.color}22;color:${oEst.color};border:1px solid ${oEst.color}55;">${oEst.label}</span>
              <span class="hist-date">${fecha}${km ? " · " + km : ""}</span>
            </div>
            ${sintomas ? `<div class="hist-sintomas">${sintomas}</div>` : ""}
            ${entregadoEl ? `<div class="hist-date" style="margin-top:4px;">${entregadoEl}</div>` : ""}
            <div class="hist-bottom">
              <span class="chip" style="background:${oPago.color}22;color:${oPago.color};border:1px solid ${oPago.color}55;">${oPago.label}</span>
              <span class="hist-total">$${Number(o.total || 0).toFixed(2)}</span>
            </div>
            ${diagnosticoHtml}
            ${trabajo}
            ${grupoFotos("Al ingresar", fotosIngreso)}
            ${grupoFotos("Al entregar", fotosEntrega)}
            ${grupoDanos}
            ${actualizacionesHtml}
          </div>
        `;
      }).join("")
    : `<p class="msg">Este vehículo todavía no tiene órdenes de trabajo registradas.</p>`;

  return shellPage(`
    <span class="placa">${placa}</span>
    <div class="subtitle">${nombreVehiculo}${detalles ? " · " + detalles : ""}</div>
    ${ficha}

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
      `SELECT v.placa, v.marca, v.modelo, v.anio, v.color, v.kilometraje,
              v.tipo_vehiculo, v.tipo_combustible, v.transmision, v.cilindraje
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
         id, symptoms, diagnostico, estado, pago_estado, total, kilometraje_ot,
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
       ORDER BY created_at DESC
       LIMIT 25`,
      [v.placa]
    );

    const ots = otq.rows;
    if (ots.length) {
      const ids = ots.map((o) => o.id);
      const fq = await pool.query(
        `SELECT orden_id, tipo, ruta FROM orden_fotos WHERE orden_id = ANY($1::int[])`,
        [ids]
      );
      const base = process.env.APP_URL || "";
      const porOrden = {};
      for (const f of fq.rows) {
        (porOrden[f.orden_id] ??= []).push({ tipo: f.tipo, url: `${base}/uploads/${f.ruta}` });
      }
      for (const o of ots) o.fotos = porOrden[o.id] || [];

      const dq = await pool.query(
        `SELECT id, orden_id, tipo, vista, zona, estado_dano, tipo_reparacion, observaciones
         FROM orden_danos WHERE orden_id = ANY($1::int[])`,
        [ids]
      );
      const danosPorOrden = {};
      for (const d of dq.rows) (danosPorOrden[d.orden_id] ??= []).push(d);

      if (dq.rowCount > 0) {
        const danoIds = dq.rows.map((d) => d.id);
        const dfq = await pool.query(
          `SELECT dano_id, ruta FROM orden_dano_fotos WHERE dano_id = ANY($1::int[])`,
          [danoIds]
        );
        const fotosPorDano = {};
        for (const f of dfq.rows) (fotosPorDano[f.dano_id] ??= []).push(`${base}/uploads/${f.ruta}`);
        for (const list of Object.values(danosPorOrden)) {
          for (const d of list) d.fotos = fotosPorDano[d.id] || [];
        }
      }
      for (const o of ots) o.danos = danosPorOrden[o.id] || [];

      const sq = await pool.query(
        `SELECT orden_id, descripcion, precio FROM orden_servicios
         WHERE orden_id = ANY($1::int[]) ORDER BY created_at ASC`,
        [ids]
      );
      const serviciosPorOrden = {};
      for (const s of sq.rows) (serviciosPorOrden[s.orden_id] ??= []).push(s);
      for (const o of ots) o.servicios = serviciosPorOrden[o.id] || [];

      const rq = await pool.query(
        `SELECT orden_id, nombre, cantidad, precio_unitario FROM orden_repuestos
         WHERE orden_id = ANY($1::int[]) ORDER BY created_at ASC`,
        [ids]
      );
      const repuestosPorOrden = {};
      for (const r of rq.rows) (repuestosPorOrden[r.orden_id] ??= []).push(r);
      for (const o of ots) o.repuestos = repuestosPorOrden[o.id] || [];

      const aq = await pool.query(
        `SELECT id, orden_id, nota, created_at FROM orden_actualizaciones
         WHERE orden_id = ANY($1::int[]) ORDER BY created_at ASC`,
        [ids]
      );
      const actualizacionesPorOrden = {};
      for (const a of aq.rows) (actualizacionesPorOrden[a.orden_id] ??= []).push(a);

      if (aq.rowCount > 0) {
        const actIds = aq.rows.map((a) => a.id);
        const afq = await pool.query(
          `SELECT actualizacion_id, ruta FROM orden_actualizacion_fotos WHERE actualizacion_id = ANY($1::int[])`,
          [actIds]
        );
        const fotosPorAct = {};
        for (const f of afq.rows) (fotosPorAct[f.actualizacion_id] ??= []).push(`${base}/uploads/${f.ruta}`);
        for (const list of Object.values(actualizacionesPorOrden)) {
          for (const a of list) a.fotos = fotosPorAct[a.id] || [];
        }
      }
      for (const o of ots) o.actualizaciones = actualizacionesPorOrden[o.id] || [];
    }

    return res.send(renderVehiculo(v, ots));
  } catch (e) {
    return res.status(500).send(renderNoEncontrado());
  }
});

export default router;
