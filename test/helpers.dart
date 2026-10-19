import 'dart:convert';

String testToken({int? expires, String id = 'test'}) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': id,
            'exp':
                expires ?? DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          }),
        ),
      )
      .replaceAll('=', '');
  return 'header.$payload.signature';
}
