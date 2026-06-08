import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import 'package:menudrawer/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('La pantalla de login carga correctamente', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await app.main();

    // No usamos pumpAndSettle porque tu login tiene animaciones infinitas.
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(find.text('Usuario o correo'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
  });

  testWidgets('Valida campos vacíos en el login', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await app.main();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Ingresa tu usuario o correo'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });

  testWidgets('Permite escribir usuario y contraseña', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await app.main();
    await tester.pump(const Duration(seconds: 2));

    await tester.enterText(
      find.byKey(const Key('identityField')),
      'correo_prueba@gmail.com',
    );

    await tester.enterText(
      find.byKey(const Key('passwordField')),
      'clave_prueba',
    );

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('correo_prueba@gmail.com'), findsOneWidget);
    expect(find.text('clave_prueba'), findsOneWidget);
  });
}