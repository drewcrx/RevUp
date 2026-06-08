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
    auth: {
      user: process.env.MAIL_USER,
      pass: process.env.MAIL_PASS,
    },
  });
}

export async function sendMail({ to, subject, html, text }) {
  const transporter = buildTransporter();

  // Si no configuras MAIL_HOST, no revienta: solo lo imprime
  if (!transporter) {
    console.log("[MAIL DISABLED] To:", to);
    console.log("[MAIL DISABLED] Subject:", subject);
    console.log("[MAIL DISABLED] Text:", text);
    console.log("[MAIL DISABLED] Html:", html);
    return { skipped: true };
  }

  const fromName = process.env.MAIL_FROM_NAME || "Backfire";
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
