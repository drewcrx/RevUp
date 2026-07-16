// utils/favicon.js — mismo ícono de RevUp (el del login de la app) embebido
// como data URI, para que las páginas web del backend (recuperar contraseña,
// estado público del vehículo) muestren el ícono correcto en la pestaña del
// navegador, sin depender de servir un archivo estático aparte.
export const FAVICON_LINK_TAG =
  '<link rel="icon" type="image/png" href="data:image/png;base64,' +
  "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAABkElEQVR4nKWSu0oDQRiFZ2Yv3mI2QZMt" +
  "NiopLIyipRj1EfIMiW20MS8gFgo2PoAWQSy0VzSKIggREotA3EFQWTBRxLUwK9khezEjZL2wi0XEH6Y7" +
  "H3PO+X8WMRz4y7B/UnsACgBsE3CkLvVAJCJFJMs0ZRkbpglbot8tcRwnimFVVasPD4GAkEolc7mjSqXq" +
  "IA4AWw/Oz6cnJsYdTNO0ldXVLvK2s5VNB7rXPj9wZ9jb34ctXxDCTGZRwfLdwW4m4d84rFNPaAhhqL9P" +
  "DIdmZ2cEQUAIqap6fHqSnfRvXpDjJ8PbEqX0taaN+XySJKXTC/H41PR0fLnXyuHGtkK8LTnt2JZV1/Wl" +
  "peVyuSxj7Pf32mJs/eycAsemOwPf0TGXSrIsBxEMBoMNo4Hxdf3mctCHEtHOF7N5X7MLzxb9BkZjMZ0Q" +
  "X09PdCiKMY6NjBSKxWGdRhBPVfpo2Vea/bMHCkCpVFIUxTANBjEIoXw+zzDsLc83QZMS+m6z5N1yzH+F" +
  "BqCmae4FmoQAz9B/Hl9b8wF/fqY10shAFgAAAABJRU5ErkJggg==" +
  '" />';
