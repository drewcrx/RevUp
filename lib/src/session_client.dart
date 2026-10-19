import 'package:http/http.dart' as http;
import 'session.dart';

class SessionExpiredException implements Exception {
  @override
  String toString() => 'Tu sesión expiró. Inicia sesión de nuevo.';
}

/// Comparte el manejo de autenticación entre JSON y subidas multipart.
class SessionClient extends http.BaseClient {
  SessionClient(this._inner);
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final authorization = request.headers['Authorization'];
    final response = await _inner
        .send(request)
        .timeout(Duration(seconds: request is http.MultipartRequest ? 45 : 12));
    if (response.statusCode == 401 &&
        authorization != null &&
        authorization == 'Bearer ${Session.token}') {
      await Session.expire(Session.token!);
      await response.stream.drain<void>();
      throw SessionExpiredException();
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
