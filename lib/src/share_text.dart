import 'package:flutter/services.dart';
import 'share_native.dart'
    if (dart.library.js_interop) 'share_web.dart'
    as platform;

/// Devuelve false si el sistema no dispone de hoja de compartir; copia el texto.
Future<bool> compartirTexto(String text) async {
  try {
    if (await platform.compartir(text)) return true;
  } catch (_) {}
  await Clipboard.setData(ClipboardData(text: text));
  return false;
}
