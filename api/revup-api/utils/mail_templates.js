export function baseTemplate({ title, subtitle, buttonText, buttonUrl, note }) {
  return `
  <!DOCTYPE html>
  <html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${title}</title>
  </head>
  <body style="margin:0; padding:0; background-color:#04060D; font-family:'Helvetica Neue', Arial, sans-serif;">

    <!-- Wrapper -->
    <table width="100%" cellpadding="0" cellspacing="0" border="0"
           style="background-color:#04060D; padding:32px 16px;">
      <tr>
        <td align="center">

          <!-- Card -->
          <table width="100%" cellpadding="0" cellspacing="0" border="0"
                 style="max-width:520px; background-color:#080E1A;
                        border:1px solid rgba(30,144,255,0.18);
                        border-radius:16px; overflow:hidden;">

            <!-- Header bar -->
            <tr>
              <td style="background:linear-gradient(135deg,#0A1628 0%,#060B18 100%);
                          padding:0; border-bottom:1px solid rgba(30,144,255,0.25);">
                <table width="100%" cellpadding="0" cellspacing="0" border="0">
                  <tr>
                    <!-- Dot + wordmark -->
                    <td style="padding:16px 22px;" align="center">
                      <table cellpadding="0" cellspacing="0" border="0"
                             style="display:inline-table;">
                        <tr>
                          <td style="width:8px; height:8px; background:#1E90FF;
                                      border-radius:50%; vertical-align:middle;"></td>
                          <td style="padding-left:9px; vertical-align:middle;">
                            <span style="font-size:13px; font-weight:800;
                                         letter-spacing:3px; color:#F0F4FF;">
                              REVUP
                            </span>
                          </td>
                          <td style="padding-left:12px; vertical-align:middle;">
                            <span style="font-size:10px; color:rgba(30,144,255,0.65);
                                         letter-spacing:1.5px; font-weight:600;">
                              MÁS CONTROL. MÁS RENDIMIENTO.
                            </span>
                          </td>
                        </tr>
                      </table>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>

            <!-- Body -->
            <tr>
              <td style="padding:30px 28px 26px 28px;">

                <!-- Icon circle -->
                <table width="100%" cellpadding="0" cellspacing="0" border="0">
                  <tr>
                    <td align="center" style="padding-bottom:22px;">
                      <div style="display:inline-block; width:60px; height:60px;
                                   background:rgba(30,144,255,0.09);
                                   border:1.5px solid rgba(30,144,255,0.28);
                                   border-radius:50%; text-align:center;
                                   line-height:60px; font-size:24px;">
                        ⚡
                      </div>
                    </td>
                  </tr>
                </table>

                <!-- Title -->
                <h2 style="margin:0 0 10px 0; font-size:20px; font-weight:800;
                            color:#F0F4FF; text-align:center; letter-spacing:0.3px;">
                  ${title}
                </h2>

                <!-- Subtitle -->
                <p style="margin:0 0 24px 0; font-size:14px; color:rgba(240,244,255,0.55);
                           line-height:1.7; text-align:center;">
                  ${subtitle}
                </p>

                <!-- Divider -->
                <div style="height:1px; background:linear-gradient(90deg,
                             transparent, rgba(30,144,255,0.20), transparent);
                             margin-bottom:24px;"></div>

                <!-- CTA Button -->
                <table width="100%" cellpadding="0" cellspacing="0" border="0">
                  <tr>
                    <td align="center" style="padding-bottom:24px;">
                      <!--[if mso]>
                      <v:roundrect xmlns:v="urn:schemas-microsoft-com:vml"
                        href="${buttonUrl}"
                        style="height:48px;v-text-anchor:middle;width:220px;"
                        arcsize="50%" stroke="f"
                        fillcolor="#1E90FF">
                        <w:anchorlock/>
                        <center style="color:#ffffff;font-family:sans-serif;
                                       font-size:13px;font-weight:700;">
                          ${buttonText}
                        </center>
                      </v:roundrect>
                      <![endif]-->
                      <!--[if !mso]><!-->
                      <a href="${buttonUrl}"
                         style="display:inline-block;
                                padding:14px 32px;
                                background:linear-gradient(135deg,#2AA0FF 0%,#0A5FCC 100%);
                                color:#ffffff;
                                text-decoration:none;
                                border-radius:999px;
                                font-weight:800;
                                font-size:13px;
                                letter-spacing:1.5px;
                                box-shadow:0 4px 18px rgba(30,144,255,0.38);">
                        ${buttonText}
                      </a>
                      <!--<![endif]-->
                    </td>
                  </tr>
                </table>

                <!-- Note -->
                <p style="margin:0; font-size:11px; color:rgba(240,244,255,0.25);
                           line-height:1.6; text-align:center;">
                  ${note || "Si no solicitaste esto, puedes ignorar este mensaje de forma segura."}
                </p>

              </td>
            </tr>

            <!-- Footer -->
            <tr>
              <td style="padding:14px 28px 18px 28px;
                          border-top:1px solid rgba(30,144,255,0.08);
                          background-color:#060B18;">
                <table width="100%" cellpadding="0" cellspacing="0" border="0">
                  <tr>
                    <td>
                      <span style="font-size:10px; color:rgba(240,244,255,0.18);
                                    letter-spacing:0.3px;">
                        © ${new Date().getFullYear()} RevUp · Taller Inteligente
                      </span>
                    </td>
                    <td align="right">
                      <span style="font-size:10px; color:rgba(30,144,255,0.35);
                                    letter-spacing:0.5px; font-weight:600;">
                        revup.app
                      </span>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>

          </table>
          <!-- /Card -->

        </td>
      </tr>
    </table>
    <!-- /Wrapper -->

  </body>
  </html>
  `;
}