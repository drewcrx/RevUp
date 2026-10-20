import 'package:flutter/services.dart';

Future<bool> compartir(String text) async =>
    await const MethodChannel(
      'revup/share',
    ).invokeMethod<bool>('shareText', {'text': text}) ??
    false;
