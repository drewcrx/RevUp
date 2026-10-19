import nodemailer from "nodemailer";

function toBool(v) {
  return String(v || "").toLowerCase() === "true";
}

export function buildTransporter() {
  const host = process.env.MAIL_HOST;
  if (!host) return null;

  const port = Number(process.env.MAIL_PORT || 587);
  const secure = toBool(process.env.MAIL_SECURE);

  return nodemailer.createTransport({
    host,
    port,
    secure,
    connectionTimeout: 10000,
    greetingTimeout: 10000,
    socketTimeout: 15000,
    auth: {
      user: process.env.MAIL_USER,
      pass: process.env.MAIL_PASS,
    },
  });
}

export async function sendMail({ to, subject, html, text }) {
  const transporter = buildTransporter();

  // No simular entregas ni escribir enlaces privados de activación en logs.
  if (!transporter) {
    throw new Error('SMTP no configurado: no se pudo enviar el correo');
  }

  const fromName = process.env.MAIL_FROM_NAME || "RevUp";
  const fromEmail = process.env.MAIL_FROM_EMAIL || process.env.MAIL_USER;

  const info = await transporter.sendMail({
    from: `"${fromName}" <${fromEmail}>`,
    to,
    subject,
    text,
    html,
  });

  return { skipped: false, messageId: info.messageId };
}
