// routes/usuarios.js
import express from "express";
import bcrypt from "bcrypt";
import crypto from "crypto";
import { pool } from "../db/connection.js";
import jwt from "jsonwebtoken";

import { sendMail } from "../utils/mailer.js";
import { baseTemplate } from "../utils/mail_templates.js";

const router = express.Router();

// Necesario para formularios HTML (reset-password)
router.use(express.urlencoded({ extended: true }));

function appUrl() {
  return process.env.APP_URL || `http://localhost:${process.env.PORT || 3000}`;
}

function createTokenPair() {
  const token = crypto.randomBytes(32).toString("hex");
  const tokenHash = crypto.createHash("sha256").update(token).digest("hex");
  return { token, tokenHash };
}

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const kBg      = "#04060D";
const kCard    = "#080E1A";
const kBlue    = "#1E90FF";
const kWhite   = "#F0F4FF";
const kBorder  = "rgba(30,144,255,0.18)";

function renderSimplePage(title, message, ok = false) {
  const accentColor = ok ? "#22C55E" : "#EF4444";
  const badgeLabel  = ok ? "OK" : "ERROR";

  return `<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>RevUp — ${title}</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Helvetica Neue', Arial, sans-serif;
      background: ${kBg};
      color: ${kWhite};
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px 16px;
    }
    .card {
      width: min(520px, 100%);
      background: ${kCard};
      border: 1px solid ${kBorder};
      border-radius: 16px;
      overflow: hidden;
    }
    /* Header */
    .card-header {
      background: linear-gradient(135deg, #0A1628 0%, #060B18 100%);
      border-bottom: 1px solid rgba(30,144,255,0.20);
      padding: 14px 22px;
      display: flex;
      align-items: center;
      gap: 9px;
    }
    .dot {
      width: 8px; height: 8px;
      background: ${kBlue};
      border-radius: 50%;
      flex-shrink: 0;
    }
    .wordmark {
      font-size: 12px;
      font-weight: 800;
      letter-spacing: 3px;
      color: ${kWhite};
    }
    .tagline {
      font-size: 10px;
      color: rgba(30,144,255,0.60);
      letter-spacing: 1.2px;
      font-weight: 600;
      margin-left: 4px;
    }
    /* Body */
    .card-body {
      padding: 28px 24px 26px;
      text-align: center;
    }
    /* Badge */
    .badge {
      display: inline-block;
      padding: 5px 14px;
      border-radius: 999px;
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 1px;
      color: #fff;
      background: ${accentColor};
      box-shadow: 0 2px 12px ${accentColor}55;
      margin-bottom: 18px;
    }
    h1 {
      font-size: 20px;
      font-weight: 800;
      color: ${kWhite};
      margin-bottom: 8px;
      letter-spacing: 0.2px;
    }
    h1 .brand {
      color: ${kBlue};
    }
    .message {
      font-size: 14px;
      color: rgba(240,244,255,0.50);
      line-height: 1.6;
    }
    /* Divider */
    .divider {
      height: 1px;
      background: linear-gradient(90deg, transparent, rgba(30,144,255,0.18), transparent);
      margin: 22px 0;
    }
    /* Footer */
    .card-footer {
      padding: 12px 22px;
      border-top: 1px solid rgba(30,144,255,0.08);
      background: #060B18;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .footer-copy { font-size: 10px; color: rgba(240,244,255,0.18); }
    .footer-brand { font-size: 10px; color: rgba(30,144,255,0.35); font-weight: 600; letter-spacing: 0.5px; }
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
      <div class="badge">${badgeLabel}</div>
      <h1><span class="brand">RevUp</span> — ${title}</h1>
      <div class="divider"></div>
      <p class="message">${message}</p>
    </div>
    <div class="card-footer">
      <span class="footer-copy">© ${new Date().getFullYear()} RevUp · Taller Inteligente</span>
      <span class="footer-brand">revup.app</span>
    </div>
  </div>
</body>
</html>`;
}

function renderResetPasswordForm(token, error = "") {
  const errHtml = error
    ? `<div class="error-box">${error}</div>`
    : "";

  return `<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>RevUp — Cambiar contraseña</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Helvetica Neue', Arial, sans-serif;
      background: ${kBg};
      color: ${kWhite};
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px 16px;
    }
    .card {
      width: min(520px, 100%);
      background: ${kCard};
      border: 1px solid ${kBorder};
      border-radius: 16px;
      overflow: hidden;
    }
    /* Header */
    .card-header {
      background: linear-gradient(135deg, #0A1628 0%, #060B18 100%);
      border-bottom: 1px solid rgba(30,144,255,0.20);
      padding: 14px 22px;
      display: flex;
      align-items: center;
      gap: 9px;
    }
    .dot { width: 8px; height: 8px; background: ${kBlue}; border-radius: 50%; flex-shrink: 0; }
    .wordmark { font-size: 12px; font-weight: 800; letter-spacing: 3px; color: ${kWhite}; }
    .tagline { font-size: 10px; color: rgba(30,144,255,0.60); letter-spacing: 1.2px; font-weight: 600; margin-left: 4px; }
    /* Body */
    .card-body { padding: 26px 24px 28px; }
    h1 { font-size: 19px; font-weight: 800; color: ${kWhite}; margin-bottom: 6px; }
    h1 .brand { color: ${kBlue}; }
    .subtitle { font-size: 13px; color: rgba(240,244,255,0.45); margin-bottom: 22px; line-height: 1.5; }
    /* Divider */
    .divider {
      height: 1px;
      background: linear-gradient(90deg, transparent, rgba(30,144,255,0.14), transparent);
      margin: 18px 0;
    }
    /* Error */
    .error-box {
      margin-bottom: 16px;
      padding: 12px 14px;
      border-radius: 10px;
      border: 1px solid rgba(239,68,68,0.35);
      background: rgba(239,68,68,0.07);
      color: #FCA5A5;
      font-size: 13px;
      line-height: 1.5;
    }
    /* Labels & inputs */
    label {
      display: block;
      font-size: 12px;
      font-weight: 600;
      color: rgba(240,244,255,0.55);
      margin-bottom: 6px;
      letter-spacing: 0.3px;
    }
    input[type="password"] {
      width: 100%;
      padding: 13px 14px;
      border-radius: 10px;
      border: 1px solid rgba(30,144,255,0.22);
      background: rgba(30,144,255,0.05);
      color: ${kWhite};
      font-size: 14px;
      outline: none;
      transition: border-color 0.2s;
      margin-bottom: 14px;
    }
    input[type="password"]:focus {
      border-color: ${kBlue};
    }
    input[type="hidden"] {}
    /* Button */
    button[type="submit"] {
      margin-top: 6px;
      width: 100%;
      padding: 14px;
      border-radius: 10px;
      border: 0;
      background: linear-gradient(135deg, #2AA0FF 0%, #0A5FCC 100%);
      color: #fff;
      font-weight: 800;
      font-size: 13px;
      letter-spacing: 1.5px;
      cursor: pointer;
      box-shadow: 0 4px 16px rgba(30,144,255,0.35);
      transition: opacity 0.2s;
    }
    button[type="submit"]:hover { opacity: 0.88; }
    /* Note */
    .note {
      margin-top: 16px;
      font-size: 11px;
      color: rgba(240,244,255,0.22);
      line-height: 1.5;
      text-align: center;
    }
    /* Footer */
    .card-footer {
      padding: 12px 22px;
      border-top: 1px solid rgba(30,144,255,0.08);
      background: #060B18;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .footer-copy { font-size: 10px; color: rgba(240,244,255,0.18); }
    .footer-brand { font-size: 10px; color: rgba(30,144,255,0.35); font-weight: 600; letter-spacing: 0.5px; }
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
      <h1><span class="brand">RevUp</span> — Cambiar contraseña</h1>
      <p class="subtitle">Ingresa tu nueva contraseña a continuación.</p>

      <div class="divider"></div>

      ${errHtml}

      <form method="POST" action="/usuarios/reset-password">
        <input type="hidden" name="token" value="${token || ""}" />

        <label>Nueva contraseña</label>
        <input type="password" name="password" minlength="6" required placeholder="Mínimo 6 caracteres" />

        <label>Confirmar contraseña</label>
        <input type="password" name="password2" minlength="6" required placeholder="Repite la contraseña" />

        <button type="submit">GUARDAR CONTRASEÑA</button>
      </form>

      <p class="note">Si el enlace expiró, vuelve a solicitar la recuperación desde la app.</p>
    </div>
    <div class="card-footer">
      <span class="footer-copy">© ${new Date().getFullYear()} RevUp · Taller Inteligente</span>
      <span class="footer-brand">revup.app</span>
    </div>
  </div>
</body>
</html>`;
}

//
// =========================
// REGISTRO + VERIFICACIÓN
// =========================
//
router.post("/register", async (req, res) => {
  const { nombre, correo, usuario, password } = req.body || {};
  if (!nombre || !correo || !usuario || !password) {
    return res.status(400).json({ error: "Completa todos los campos" });
  }

  try {
    const existeUser = await pool.query("SELECT 1 FROM usuarios WHERE usuario = $1", [usuario]);
    const existeCorreo = await pool.query("SELECT 1 FROM usuarios WHERE correo = $1", [correo]);

    if (existeUser.rowCount > 0) return res.status(409).json({ error: "El usuario ya existe" });
    if (existeCorreo.rowCount > 0) return res.status(409).json({ error: "El correo ya está registrado" });

    const hash = await bcrypt.hash(password, 10);
    const { token, tokenHash } = createTokenPair();
    const expires = new Date(Date.now() + 1000 * 60 * 60 * 24); // 24h

    await pool.query(
      `INSERT INTO usuarios (nombre, correo, usuario, password_hash, verificado, verificacion_token_hash, verificacion_expires)
       VALUES ($1,$2,$3,$4,false,$5,$6)`,
      [nombre, correo, usuario, hash, tokenHash, expires]
    );

    const verifyLink = `${appUrl()}/usuarios/verify?token=${token}`;

    await sendMail({
      to: correo,
      subject: "Activa tu cuenta - RevUp",
      text: `Activa tu cuenta aquí: ${verifyLink}`,
      html: baseTemplate({
        title: "Activa tu cuenta",
        subtitle: "Confirma tu correo para empezar a usar RevUp.",
        buttonText: "Activar cuenta",
        buttonUrl: verifyLink,
      }),
    });

    return res.json({ mensaje: "Registro exitoso. Revisa tu correo." });
  } catch (e) {
    return res.status(500).json({ error: "Error en el registro", detalle: e.message });
  }
});

//
// =========================
// VERIFY
// =========================
//
router.get("/verify", async (req, res) => {
  const token = req.query?.token;
  if (!token) return res.status(400).send(renderSimplePage("Error", "Token inválido"));

  try {
    const tokenHash = crypto.createHash("sha256").update(token).digest("hex");
    const q = await pool.query(
      "SELECT id, verificado, verificacion_expires FROM usuarios WHERE verificacion_token_hash = $1",
      [tokenHash]
    );

    if (q.rowCount === 0) {
      return res.status(400).send(renderSimplePage("Error", "Enlace inválido"));
    }

    const u = q.rows[0];

    if (u.verificado) {
      return res.send(renderSimplePage("Cuenta activa", "Tu cuenta ya estaba activada.", true));
    }

    if (!u.verificacion_expires || new Date(u.verificacion_expires) < new Date()) {
      return res.send(renderSimplePage("Enlace expirado", "Solicita un nuevo enlace de activación desde la app."));
    }

    await pool.query(
      `UPDATE usuarios
       SET verificado=true,
           verificado_en=NOW(),
           verificacion_token_hash=NULL,
           verificacion_expires=NULL
       WHERE id=$1`,
      [u.id]
    );

    return res.send(renderSimplePage("Cuenta activada", "Ya puedes iniciar sesión.", true));
  } catch {
    return res.status(500).send(renderSimplePage("Error", "No se pudo verificar la cuenta"));
  }
});

//
// =========================
// LOGIN
// =========================
//
router.post("/login", async (req, res) => {
  const { usuario, correo, password } = req.body || {};
  const identidad = usuario || correo;

  if (!identidad || !password) {
    return res.status(400).json({ error: "Credenciales incompletas" });
  }

  const q = await pool.query(
    `SELECT id,nombre,correo,usuario,password_hash,verificado,role
     FROM usuarios WHERE usuario=$1 OR correo=$1`,
    [identidad]
  );

  if (q.rowCount === 0) return res.status(401).json({ error: "Credenciales inválidas" });
  if (!q.rows[0].verificado) return res.status(403).json({ error: "Cuenta no verificada" });

  const ok = await bcrypt.compare(password, q.rows[0].password_hash);
  if (!ok) return res.status(401).json({ error: "Credenciales inválidas" });

  const user = q.rows[0];

  const token = jwt.sign(
    { id: user.id, role: user.role || "mechanic" },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES || "7d" }
  );

  return res.json({
    token,
    user: {
      id: user.id,
      nombre: user.nombre,
      correo: user.correo,
      usuario: user.usuario,
      role: user.role || "mechanic",
    },
  });
});

// =========================
// Reenviar verificación
// =========================
router.post("/resend-verification", async (req, res) => {
  const { correo } = req.body || {};
  const email = (correo || "").trim();
  if (!email) return res.status(400).json({ error: "Ingresa tu correo" });

  try {
    const q = await pool.query(
      "SELECT id, nombre, correo, verificado FROM usuarios WHERE correo = $1",
      [email]
    );

    const generic = { mensaje: "Si el correo existe, te enviamos el enlace de activación." };

    if (q.rowCount === 0) return res.json(generic);

    const u = q.rows[0];

    if (u.verificado) return res.json(generic);

    const { token, tokenHash } = createTokenPair();
    const expires = new Date(Date.now() + 1000 * 60 * 60 * 24); // 24h

    await pool.query(
      `UPDATE usuarios
       SET verificacion_token_hash = $1,
           verificacion_expires = $2
       WHERE id = $3`,
      [tokenHash, expires, u.id]
    );

    const link = `${appUrl()}/usuarios/verify?token=${token}`;

    await sendMail({
      to: u.correo,
      subject: "Activa tu cuenta - RevUp",
      html: baseTemplate({
        title: "Reenvío de activación",
        subtitle: "Confirma tu correo para activar tu cuenta y empezar a usar RevUp.",
        buttonText: "Activar cuenta",
        buttonUrl: link,
      }),
    });

    return res.json(generic);
  } catch (e) {
    return res.status(500).json({ error: "Error reenviando verificación", detalle: e.message });
  }
});

//
// =========================
// FORGOT PASSWORD
// =========================
//
router.post("/forgot-password", async (req, res) => {
  const { correo } = req.body || {};
  const email = (correo || "").trim();

  const generic = { mensaje: "Si existe el correo, se enviará un enlace." };
  if (!email) return res.json(generic);

  try {
    const q = await pool.query("SELECT id,nombre,correo FROM usuarios WHERE correo=$1", [email]);

    if (q.rowCount > 0) {
      const { token, tokenHash } = createTokenPair();
      const expires = new Date(Date.now() + 1000 * 60 * 30); // 30 min

      await pool.query(
        "UPDATE usuarios SET reset_token_hash=$1, reset_expires=$2 WHERE id=$3",
        [tokenHash, expires, q.rows[0].id]
      );

      const link = `${appUrl()}/usuarios/reset-password?token=${token}`;

      await sendMail({
        to: email,
        subject: "Recupera tu contraseña - RevUp",
        html: baseTemplate({
          title: "Recuperar contraseña",
          subtitle: "Haz clic para crear una nueva contraseña.",
          buttonText: "Cambiar contraseña",
          buttonUrl: link,
        }),
      });
    }

    return res.json(generic);
  } catch (e) {
    return res.status(500).json({ error: "Error enviando recuperación", detalle: e.message });
  }
});

// =========================
// RESET PASSWORD — GET
// =========================
router.get("/reset-password", async (req, res) => {
  const token = (req.query?.token || "").toString().trim();
  if (!token) return res.status(400).send(renderSimplePage("Error", "Token inválido"));

  try {
    const tokenHash = crypto.createHash("sha256").update(token).digest("hex");

    const q = await pool.query(
      "SELECT id, reset_expires FROM usuarios WHERE reset_token_hash = $1",
      [tokenHash]
    );

    if (q.rowCount === 0) {
      return res.status(400).send(renderSimplePage("Error", "Enlace inválido"));
    }

    const u = q.rows[0];

    if (!u.reset_expires || new Date(u.reset_expires) < new Date()) {
      return res.status(400).send(renderSimplePage("Enlace expirado", "Solicita un nuevo enlace desde la app."));
    }

    return res.send(renderResetPasswordForm(token));
  } catch (e) {
    return res.status(500).send(renderSimplePage("Error", "No se pudo abrir el formulario"));
  }
});

// =========================
// RESET PASSWORD — POST
// =========================
router.post("/reset-password", async (req, res) => {
  const token     = (req.body?.token     || "").toString().trim();
  const password  = (req.body?.password  || "").toString();
  const password2 = (req.body?.password2 || "").toString();

  if (!token) return res.status(400).send(renderSimplePage("Error", "Token inválido"));
  if (!password || password.length < 6) {
    return res.status(400).send(
      renderResetPasswordForm(token, "La contraseña debe tener mínimo 6 caracteres.")
    );
  }
  if (password !== password2) {
    return res.status(400).send(
      renderResetPasswordForm(token, "Las contraseñas no coinciden.")
    );
  }

  try {
    const tokenHash = crypto.createHash("sha256").update(token).digest("hex");

    const q = await pool.query(
      "SELECT id, reset_expires FROM usuarios WHERE reset_token_hash = $1",
      [tokenHash]
    );

    if (q.rowCount === 0) {
      return res.status(400).send(renderSimplePage("Error", "Enlace inválido"));
    }

    const u = q.rows[0];

    if (!u.reset_expires || new Date(u.reset_expires) < new Date()) {
      return res.status(400).send(renderSimplePage("Enlace expirado", "Solicita un nuevo enlace desde la app."));
    }

    const hash = await bcrypt.hash(password, 10);

    await pool.query(
      `UPDATE usuarios
       SET password_hash = $1,
           reset_token_hash = NULL,
           reset_expires = NULL
       WHERE id = $2`,
      [hash, u.id]
    );

    return res.send(
      renderSimplePage("Contraseña actualizada", "Ya puedes iniciar sesión con tu nueva contraseña.", true)
    );
  } catch (e) {
    return res.status(500).send(renderSimplePage("Error", "No se pudo actualizar la contraseña"));
  }
});

//
// =========================
// FORGOT USERNAME
// =========================
//
router.post("/forgot-username", async (req, res) => {
  const { correo } = req.body || {};
  const email = (correo || "").trim();

  const generic = { mensaje: "Si existe el correo, te enviaremos tu usuario." };
  if (!email) return res.json(generic);

  try {
    const q = await pool.query("SELECT nombre,usuario,correo FROM usuarios WHERE correo=$1", [email]);

    if (q.rowCount > 0) {
      await sendMail({
        to: email,
        subject: "Tu usuario - RevUp",
        html: baseTemplate({
          title: "Recuperar usuario",
          subtitle: `Tu nombre de usuario es: <b style="color:#F0F4FF;">${q.rows[0].usuario}</b>`,
          buttonText: "Iniciar sesión",
          buttonUrl: appUrl(),
        }),
      });
    }

    return res.json(generic);
  } catch (e) {
    return res.status(500).json({ error: "Error enviando usuario", detalle: e.message });
  }
});

export default router;