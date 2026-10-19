import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:menudrawer/src/agregar_vehiculo.dart';
import 'package:menudrawer/src/api_service.dart';

void main() {
  testWidgets('guardar se recupera de desconexión y timeout y permite reintentar', (tester) async {
    final original = ApiService.client;
    addTearDown(() { ApiService.client.close(); ApiService.client = original; });
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var posts = 0;
    ApiService.client = MockClient((req) async {
      if (req.method == 'POST') {
        posts++;
        if (posts == 1) throw http.ClientException('Sin conexión');
        if (posts == 2) return Completer<http.Response>().future;
        return http.Response('{}', 200);
      }
      final body = switch (req.url.path) {
        '/catalogos/marcas' => [{'id': 1, 'nombre': 'Toyota'}],
        '/catalogos/marcas/1/modelos' => [{'id': 1, 'nombre': 'Yaris'}],
        '/catalogos/items/color' => [{'valor': 'Azul'}],
        '/catalogos/items/tipo_vehiculo' => [{'valor': 'Sedán'}],
        _ => <Object>[],
      };
      return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
        builder: (_) => const AgregarVehiculoPage(),
      )), child: const Text('Abrir')),
    ))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    Future<void> select(String label, String value) async {
      final dropdown = find.byWidgetPredicate((w) => w is DropdownButtonFormField<String> &&
        w.decoration.labelText == label);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(value).last);
      await tester.pumpAndSettle();
    }
    Future<void> enter(String label, String value) async {
      final field = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == label);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
      await tester.pump();
    }
    await select('Marca', 'Toyota');
    await select('Modelo', 'Yaris');
    await enter('Placa', 'TEST-001');
    await select('Tipo de vehículo', 'Sedán');
    await enter('Año', '2020');
    await select('Color', 'Azul');
    await enter('Kilometraje', '500');
    final date = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Última visita');
    await tester.ensureVisible(date);
    await tester.tap(date);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await enter('Nombre del propietario', 'Ana');
    await enter('Teléfono', '0999999999');
    await tester.ensureVisible(find.text('GUARDAR'));
    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();
    expect(posts, 1);
    expect(find.text('GUARDAR'), findsOneWidget);
    expect(find.textContaining('No se pudo guardar el vehículo'), findsOneWidget);

    await tester.tap(find.text('GUARDAR'));
    await tester.pump();
    expect(find.text('GUARDAR'), findsNothing);
    await tester.pump(const Duration(seconds: 13));
    await tester.pumpAndSettle();
    expect(posts, 2);
    expect(find.text('GUARDAR'), findsOneWidget);
    expect(find.textContaining('El servidor tardó demasiado'), findsOneWidget);
    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();
    expect(posts, 3);
    expect(find.text('Abrir'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
