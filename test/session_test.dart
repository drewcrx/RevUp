import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:menudrawer/src/session.dart';
import 'package:menudrawer/src/session_client.dart';
import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Session.clear();
  });
  tearDown(Session.clear);

  test('restaura una sesión válida desde el almacenamiento', () async {
    final token = testToken();
    SharedPreferences.setMockInitialValues({
      'current_user': jsonEncode({'nombre': 'Ana'}),
      'auth_token': token,
    });
    await Session.loadSession();
    expect(Session.hasValidSession, isTrue);
    expect(Session.getNombre(), 'Ana');
    expect(Session.token, token);
  });

  for (final value in [testToken(expires: 1), 'invalido']) {
    test('descarta token vencido o inválido: $value', () async {
      SharedPreferences.setMockInitialValues({
        'current_user': jsonEncode({'nombre': 'Ana'}),
        'auth_token': value,
      });
      await Session.loadSession();
      expect(Session.token, isNull);
      expect(Session.user, isNull);
      expect(
        (await SharedPreferences.getInstance()).getString('auth_token'),
        isNull,
      );
    });
  }

  test('un usuario corrupto no impide abrir la app', () async {
    SharedPreferences.setMockInitialValues({
      'current_user': '{',
      'auth_token': testToken(),
    });
    await Session.loadSession();
    expect(Session.hasValidSession, isFalse);
  });

  test('401 autenticado limpia sesión y notifica una sola vez', () async {
    await Session.setSession(user: {'nombre': 'Ana'}, token: testToken());
    final revision = Session.expirationEvents.value;
    final client = SessionClient(
      MockClient((_) async => http.Response('{}', 401)),
    );
    await expectLater(
      client.get(
        Uri.https('test.invalid', '/vehiculos'),
        headers: {'Authorization': 'Bearer ${Session.token}'},
      ),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(Session.user, isNull);
    expect(Session.token, isNull);
    expect(Session.expirationEvents.value, revision + 1);
    client.close();
  });

  test('401 de login y 403 de permisos conservan la sesión', () async {
    final token = testToken();
    await Session.setSession(user: {'nombre': 'Ana'}, token: token);
    final client = SessionClient(
      MockClient(
        (r) async => http.Response('{}', r.url.path == '/login' ? 401 : 403),
      ),
    );
    await client.post(Uri.https('test.invalid', '/login'));
    await client.get(
      Uri.https('test.invalid', '/admin'),
      headers: {'Authorization': 'Bearer $token'},
    );
    expect(Session.token, token);
    client.close();
  });

  test('un 401 atrasado no cierra la sesión nueva', () async {
    final old = testToken(id: 'old');
    final fresh = testToken(id: 'new');
    await Session.setSession(user: {'nombre': 'Ana'}, token: old);
    final client = SessionClient(
      MockClient((_) async {
        await Session.setSession(user: {'nombre': 'Beto'}, token: fresh);
        return http.Response('{}', 401);
      }),
    );
    final response = await client.get(
      Uri.https('test.invalid', '/vehiculos'),
      headers: {'Authorization': 'Bearer $old'},
    );
    expect(response.statusCode, 401);
    expect(Session.token, fresh);
    client.close();
  });
}
