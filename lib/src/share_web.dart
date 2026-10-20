import 'dart:js_interop';

@JS('navigator.share')
external JSPromise<JSAny?> _share(JSObject data);
Future<bool> compartir(String text) async {
  await _share({'text': text}.jsify() as JSObject).toDart;
  return true;
}
