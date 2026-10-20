import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:menudrawer/src/api_service.dart';
import 'package:menudrawer/src/detalle_orden.dart';
import 'package:menudrawer/src/formulario.dart';
import 'package:menudrawer/src/orden_herramientas.dart';
import 'package:menudrawer/src/ordenes.dart';
import 'package:menudrawer/src/session.dart';
import 'package:menudrawer/src/ui_tools.dart';
import 'package:menudrawer/src/vehiculo_3d.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers.dart';

void main() {
  testWidgets(
    'volver atras protege los cambios del formulario y cancelar conserva los datos',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FormularioPage(
                      title: 'Formulario de prueba',
                      campos: const [CampoFormulario('nombre', 'Nombre')],
                      guardar: (_) async {},
                    ),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Datos que quiero conservar',
      );
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Datos sin guardar'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Datos que quiero conservar'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'importes admiten coma y punto sin convertir entradas invalidas en cero',
    () {
      expect(parseImporte('12,50'), 12.5);
      expect(parseImporte('12.50'), 12.5);
      expect(parseImporte('0'), 0);
      for (final bad in ['', 'NaN', 'Infinity', '-1', '1,234.56', '12,345'])
        expect(parseImporte(bad), isNull, reason: bad);
    },
  );

  testWidgets(
    'guardar un servicio valida el importe, bloquea doble toque y cierra sin destruir controladores antes de tiempo',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = ApiService.client;
      addTearDown(() {
        ApiService.client.close();
        ApiService.client = original;
      });
      final gate = Completer<http.Response>();
      final posts = <Map<String, dynamic>>[];
      ApiService.client = MockClient((req) async {
        if (req.method == 'POST') {
          posts.add(jsonDecode(req.body) as Map<String, dynamic>);
          return gate.future;
        }
        return http.Response(
          jsonEncode({
            'ot': {
              'id': 7,
              'placa': 'TEST-007',
              'estado': 'RECIBIDO',
              'fase': 'RECIBIDO',
              'pago_estado': 'PAGADO',
              'total': 0,
            },
          }),
          200,
        );
      });
      await tester.pumpWidget(
        const MaterialApp(home: DetalleOrdenPage(ordenId: 7)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Agregar servicio'));
      await tester.tap(find.text('Agregar servicio'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'Cambio de aceite');
      await tester.enterText(fields.at(1), 'no es un precio');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(posts, isEmpty);
      expect(find.textContaining('Usa un importe'), findsOneWidget);
      await tester.enterText(fields.at(1), '12,50');
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last);
      await tester.pump();
      expect(posts.single['precio'], 12.5);
      gate.complete(http.Response('{}', 201));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ordenes filtra por placa, cliente, etapa y saldo y agrupa sin repetir encabezados',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await Session.setSession(
        user: {'id': 1, 'role': 'mechanic'},
        token: testToken(),
      );
      final original = ApiService.client;
      addTearDown(() {
        ApiService.client.close();
        ApiService.client = original;
      });
      ApiService.client = MockClient(
        (req) async => http.Response(
          jsonEncode([
            {
              'id': 1,
              'placa': 'AAA-001',
              'estado': 'RECIBIDO',
              'fase': 'RECIBIDO',
              'total': 10,
              'pagado': 0,
              'propietario_nombre': 'Ana',
            },
            {
              'id': 2,
              'placa': 'BBB-002',
              'estado': 'PENDIENTE',
              'fase': 'LISTO',
              'total': 20,
              'pagado': 20,
              'propietario_nombre': 'Luis',
            },
            {
              'id': 3,
              'placa': 'CCC-003',
              'estado': 'RECIBIDO',
              'fase': 'RECIBIDO',
              'total': 15,
              'pagado': 0,
              'propietario_nombre': 'Ana',
            },
          ]),
          200,
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: OrdenesPage()));
      await tester.pumpAndSettle();
      expect(find.text('AAA-001'), findsOneWidget);
      expect(find.text('CCC-003'), findsOneWidget);
      // Un chip y una cabecera, aunque las filas originales esten intercaladas.
      expect(find.text('RECIBIDO'), findsNWidgets(2));
      await tester.enterText(find.byKey(const Key('buscar-ordenes')), 'Luis');
      await tester.pumpAndSettle();
      expect(find.text('BBB-002'), findsOneWidget);
      expect(find.text('AAA-001'), findsNothing);
      await tester.tap(find.text('Con saldo'));
      await tester.pumpAndSettle();
      expect(find.text('BBB-002'), findsNothing);
      expect(find.textContaining('Sin órdenes'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await Session.clear();
    },
  );

  testWidgets(
    'visor 3D gira, cambia carroceria y permite seleccionar una pieza',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: Vehiculo3DPage()));
      await tester.pumpAndSettle();
      final canvas = find.byKey(const Key('vehiculo-3d-lienzo'));
      await tester.drag(canvas, const Offset(80, 20));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Frontal'));
      await tester.pumpAndSettle();
      final bounds = tester.getRect(canvas);
      await tester.tapAt(
        Offset(bounds.center.dx, bounds.top + bounds.height * .54),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inspeccionar-pieza-3d')), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SUV').last);
      await tester.pumpAndSettle();
      expect(find.text('SUV'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('PDF de orden genera documento con cliente, partidas y pagos', (
    tester,
  ) async {
    final bytes = await tester.runAsync(
      () => crearPdfOrden({
        'ot': {
          'id': 9,
          'placa': 'PDF-009',
          'total': 32.5,
          'symptoms': 'Revision',
          'diagnostico': 'Cambio de filtro',
        },
        'vehiculo': {
          'marca': 'Toyota',
          'modelo': 'Yaris',
          'propietario_nombre': 'Ana',
        },
        'servicios': [
          {'descripcion': 'Revision', 'precio': 12.5},
        ],
        'repuestos': [
          {'nombre': 'Filtro', 'cantidad': 2, 'precio_unitario': 10},
        ],
        'pagos': [
          {'monto': 10, 'metodo': 'EFECTIVO'},
        ],
      }),
    );
    expect(ascii.decode(bytes!.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });
}
