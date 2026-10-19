import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:menudrawer/main.dart';
import 'package:menudrawer/src/api_service.dart';
import 'package:menudrawer/src/session.dart';
import 'package:menudrawer/src/session_client.dart';
import 'helpers.dart';

void main() {
  late http.Client original;
  setUp(() async {
    original = ApiService.client;
    SharedPreferences.setMockInitialValues({});
    await Session.clear();
    ApiService.client = SessionClient(
      MockClient((_) async => http.Response('{}', 200)),
    );
  });
  tearDown(() async {
    ApiService.client.close();
    ApiService.client = original;
    await Session.clear();
  });

  testWidgets('sin sesión abre login y valida campos vacíos', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump();
    expect(find.text('Ingresa tu usuario o correo'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('401 redirige al login y elimina las rutas privadas', (
    tester,
  ) async {
    await Session.setSession(
      user: {'id': 1, 'nombre': 'Ana', 'role': 'mechanic'},
      token: testToken(),
    );
    ApiService.client = SessionClient(
      MockClient((_) async => http.Response('{}', 401)),
    );
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(Session.token, isNull);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    expect(nav.canPop(), isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
