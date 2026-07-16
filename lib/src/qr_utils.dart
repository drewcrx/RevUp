import 'api_service.dart';

/// URL pública (sin login) que se codifica en el QR del vehículo.
/// Cualquiera que la abra con la cámara normal del celular ve el estado
/// del vehículo en una página web, sin necesitar la app.
String qrUrlParaToken(String token) => "${ApiService.baseUrl}/v/$token";

/// El escáner interno de la app también debe seguir funcionando cuando
/// lee ese mismo QR: si lo escaneado es una URL, se extrae el token del
/// final del path; si es un token suelto (stickers viejos), se usa tal cual.
String extraerTokenDeQr(String escaneado) {
  final s = escaneado.trim();
  final uri = Uri.tryParse(s);
  if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
    final last = uri.pathSegments.last.trim();
    if (last.isNotEmpty) return last;
  }
  return s;
}
