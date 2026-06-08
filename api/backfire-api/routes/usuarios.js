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

function renderSimplePage(title, message, ok = false) {
  const color = ok ? "#16a34a" : "#ef4444";
  return `
  <!doctype html>
  <html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>${title}</title>
    <style>
      body{margin:0;font-family:Arial;background:#0b0b0b;color:#fff;display:flex;min-height:100vh;align-items:center;justify-content:center}
      .card{width:min(560px,92vw);background:#111;border:1px solid #1f2937;border-radius:16px;padding:22px}
      .badge{display:inline-block;padding:6px 10px;border-radius:999px;background:${color};font-weight:700}
      h1{margin:14px 0 8px 0;font-size:22px}
      p{margin:0;color:#cbd5e1}
      .brand{color:#22c55e;font-weight:800}
    </style>
  </head>
  <body>
    <div class="card">
      <div class="badge">${ok ? "OK" : "ERROR"}</div>
      <h1><span class="brand">Backfire</span> — ${title}</h1>
      <p>${message}</p>
    </div>
  </body>
  </html>`;
}

function renderResetPasswordForm(token, error = "") {
  const errHtml = error
    ? `<div style="margin:10px 0;padding:10px;border-radius:12px;border:1px solid #ef4444;color:#fecaca;background:#2a0f0f">
         ${error}
       </div>`
    : "";

  return `
  <!doctype html>
  <html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>Backfire — Cambiar contraseña</title>
    <style>
      body{margin:0;font-family:Arial;background:#0b0b0b;color:#fff;display:flex;min-height:100vh;align-items:center;justify-content:center}
      .card{width:min(560px,92vw);background:#111;border:1px solid #1f2937;border-radius:16px;padding:22px}
      h1{margin:10px 0 6px 0;font-size:22px}
      p{margin:0 0 14px 0;color:#cbd5e1}
      label{display:block;margin:10px 0 6px 0;color:#cbd5e1;font-weight:700}
      input{width:100%;padding:12px;border-radius:12px;border:1px solid #334155;background:#0b0b0b;color:#fff;outline:none}
      button{margin-top:14px;width:100%;padding:12px;border-radius:12px;border:0;background:#22c55e;color:#0b0b0b;font-weight:900;cursor:pointer}
      .brand{color:#22c55e;font-weight:800}
      .small{margin-top:10px;color:#94a3b8;font-size:12px}
    </style>
  </head>
  <body>
    <div class="card">
      <h1><span class="brand">Backfire</span> — Cambiar contraseña</h1>
      <p>Ingresa tu nueva contraseña.</p>

      ${errHtml}

      <form method="POST" action="/usuarios/reset-password">
        <input type="hidden" name="token" value="${token || ""}" />

        <label>Nueva contraseña</label>
        <input type="password" name="password" minlength="6" required />

        <label>Confirmar contraseña</label>
        <input type="password" name="password2" minlength="6" required />

        <button type="submit">Guardar contraseña</button>
      </form>

      <div class="small">Si el enlace expiró, vuelve a solicitar la recuperación.</div>
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
      subject: "Activa tu cuenta - Backfire",
      text: `Activa tu cuenta aquí: ${verifyLink}`,
      html: baseTemplate({
        title: "Activa tu cuenta",
        subtitle: "Confirma tu correo para empezar a usar Backfire.",
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
      return res.send(renderSimplePage("Error", "Enlace expirado"));
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
// Reenviar verificación (por correo)
// (responde genérico por seguridad)
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
      subject: "Activa tu cuenta - Backfire",
      html: baseTemplate({
        title: "Reenvío de activación",
        subtitle: "Confirma tu correo para activar tu cuenta y empezar a usar Backfire.",
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
// (responde genérico por seguridad)
// =========================
router.post("/forgot-password", async (req, res) => {
  const { correo } = req.body || {};
  const email = (correo || "").trim();

  // Respuesta genérica SIEMPRE
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
        subject: "Recupera tu contraseña - Backfire",
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
// RESET PASSWORD (HTML)
// GET /usuarios/reset-password?token=...
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
      return res.status(400).send(renderSimplePage("Error", "Enlace expirado"));
    }

    return res.send(renderResetPasswordForm(token));
  } catch (e) {
    return res.status(500).send(renderSimplePage("Error", "No se pudo abrir el formulario"));
  }
});

// =========================
// RESET PASSWORD (POST)
// POST /usuarios/reset-password  (token + password)
// =========================
router.post("/reset-password", async (req, res) => {
  const token = (req.body?.token || "").toString().trim();
  const password = (req.body?.password || "").toString();
  const password2 = (req.body?.password2 || "").toString();

  if (!token) return res.status(400).send(renderSimplePage("Error", "Token inválido"));
  if (!password || password.length < 6) {
    return res
      .status(400)
      .send(renderResetPasswordForm(token, "La contraseña debe tener mínimo 6 caracteres."));
  }
  if (password !== password2) {
    return res.status(400).send(renderResetPasswordForm(token, "Las contraseñas no coinciden."));
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
      return res.status(400).send(renderSimplePage("Error", "Enlace expirado"));
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
// (responde genérico por seguridad)
// =========================
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
        subject: "Tu usuario - Backfire",
        html: baseTemplate({
          title: "Recuperar usuario",
          subtitle: `Tu usuario es: <b>${q.rows[0].usuario}</b>`,
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
