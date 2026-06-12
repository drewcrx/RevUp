export function baseTemplate({ title, subtitle, buttonText, buttonUrl, note }) {
  return `
  <div style="font-family: Arial, sans-serif; background:#0b0b0b; padding:24px;">
    <div style="max-width:520px; margin:0 auto; background:#111; border:1px solid #2ecc71; border-radius:12px; overflow:hidden;">
      <div style="padding:18px 22px; background:#2ecc71; color:#000; font-weight:700; text-align:center;">
        REVUP
      </div>
      <div style="padding:22px; color:#eaeaea;">
        <h2 style="margin:0 0 8px 0; color:#2ecc71;">${title}</h2>
        <p style="margin:0 0 18px 0; line-height:1.5;">${subtitle}</p>
        <div style="text-align:center; margin:22px 0;">
          <a href="${buttonUrl}"
             style="display:inline-block; padding:12px 18px; background:#2ecc71; color:#000; text-decoration:none; border-radius:999px; font-weight:700;">
             ${buttonText}
          </a>
        </div>
        <p style="margin:18px 0 0 0; font-size:12px; color:#bdbdbd; line-height:1.4;">
          ${note || "Si no solicitaste esto, ignora este mensaje."}
        </p>
      </div>
    </div>
  </div>
  `;
}
