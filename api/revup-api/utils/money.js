// Importes de la API: dos decimales, sin separadores de miles ni valores ambiguos.
export function money(value) {
  if (value === null || value === undefined || typeof value === 'boolean') return null;
  const text = String(value).trim();
  if (!/^\d+(?:[.,]\d{1,2})?$/.test(text)) return null;
  const amount = Number(text.replace(',', '.'));
  return Number.isFinite(amount) && amount <= 9999999999.99 ? Math.round(amount * 100) / 100 : null;
}

export const cents = value => Math.round(Number(value) * 100);
