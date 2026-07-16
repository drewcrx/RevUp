// Regla de contraseña fuerte, compartida entre registro y cambio de
// contraseña: mínimo 8 caracteres, con al menos una letra y un número.
const String kPasswordHint = "Mínimo 8 caracteres, con letras y números";

final RegExp _kLetra  = RegExp(r'[A-Za-z]');
final RegExp _kNumero = RegExp(r'[0-9]');

bool esPasswordFuerte(String pw) =>
    pw.length >= 8 && _kLetra.hasMatch(pw) && _kNumero.hasMatch(pw);

/// Devuelve el mensaje de error (o null si es válida) para usar en
/// validators de formularios.
String? validarPasswordFuerte(String pw) {
  if (pw.length < 8) return "Mínimo 8 caracteres";
  if (!_kLetra.hasMatch(pw)) return "Debe incluir al menos una letra";
  if (!_kNumero.hasMatch(pw)) return "Debe incluir al menos un número";
  return null;
}
