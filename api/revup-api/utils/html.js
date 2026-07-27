// utils/html.js — escapa valores antes de insertarlos en HTML generado por
// el servidor. Cualquier dato que venga de la base de datos (marca, modelo,
// placa, etc.) o de la URL (token) debe pasar por aquí antes de interpolarse
// en una plantilla, para evitar XSS reflejado/almacenado.
export function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
