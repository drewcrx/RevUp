import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:menudrawer/src/api_service.dart';
import 'package:menudrawer/src/inspeccion_danos.dart';
import 'package:menudrawer/src/inspeccion_vehiculo.dart';

void main() {
  testWidgets('las piezas se pueden seleccionar en las cinco vistas en móvil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final vista in zonasVehiculo.keys) {
      String? seleccionada;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MapaVehiculoInspeccion(
                vista: vista,
                nombreVista: kVistaLabel[vista]!,
                danosPorZona: const {},
                onZonaTap: (zona) => seleccionada = zona,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final zona in zonasVehiculo[vista]!) {
        await tester.tap(find.byKey(ValueKey('zona-${zona.nombre}')));
        expect(seleccionada, zona.nombre, reason: '$vista / ${zona.nombre}');
      }
      expect(tester.takeException(), isNull, reason: vista);
    }
  });

  testWidgets(
    'ampliar, acercar y seleccionar conserva la pieza y cierra el visor',
    (tester) async {
      String? seleccionada;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MapaVehiculoInspeccion(
                vista: 'frontal',
                nombreVista: 'Frontal',
                danosPorZona: const {'Capó': 2},
                onZonaTap: (zona) => seleccionada = zona,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Ampliar vehículo'));
      await tester.pumpAndSettle();
      final visor = find.byType(InteractiveViewer);
      final controller = tester
          .widget<InteractiveViewer>(visor)
          .transformationController!;
      await tester.tap(find.byTooltip('Acercar'));
      await tester.pump();
      expect(controller.value.getMaxScaleOnAxis(), 1.5);
      final pieza = find.descendant(
        of: visor,
        matching: find.byKey(const ValueKey('zona-Capó')),
      );
      await tester.tap(pieza);
      await tester.pumpAndSettle();
      expect(seleccionada, 'Capó');
      expect(visor, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('registra desde el modelo con la vista y la etapa correctas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = ApiService.client;
    addTearDown(() {
      ApiService.client.close();
      ApiService.client = original;
    });
    final guardados = <Map<String, dynamic>>[];
    final danos = <Map<String, dynamic>>[
      {'id': 1, 'tipo': 'ingreso', 'vista': 'frontal', 'zona': 'Capó'},
      {'id': 2, 'tipo': 'entrega', 'vista': 'frontal', 'zona': 'Rejilla'},
    ];
    ApiService.client = MockClient((req) async {
      Object body;
      if (req.method == 'POST') {
        final nuevo = jsonDecode(req.body) as Map<String, dynamic>;
        guardados.add(nuevo);
        danos.add({'id': 3, ...nuevo});
        body = {'id': 3, ...nuevo};
      } else if (req.url.path == '/ordenes/7') {
        body = {'danos': danos};
      } else {
        body = [
          {'valor': 'Leve'},
        ];
      }
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: InspeccionDanosPage(ordenId: 7, placa: 'TEST-007'),
      ),
    );
    await tester.pumpAndSettle();
    var mapa = tester.widget<MapaVehiculoInspeccion>(
      find.byType(MapaVehiculoInspeccion),
    );
    expect(mapa.danosPorZona['Capó'], 1);
    expect(mapa.danosPorZona['Rejilla'], 0);
    await tester.tap(find.text('Al entregar'));
    await tester.pumpAndSettle();
    mapa = tester.widget<MapaVehiculoInspeccion>(
      find.byType(MapaVehiculoInspeccion),
    );
    expect(mapa.danosPorZona['Capó'], 0);
    expect(mapa.danosPorZona['Rejilla'], 1);

    await tester.tap(find.byKey(const ValueKey('zona-Capó')));
    await tester.pumpAndSettle();
    expect(find.text('Frontal · Capó'), findsOneWidget);
    await tester.tap(find.text('REGISTRAR DAÑO AQUÍ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(guardados.single, containsPair('vista', 'frontal'));
    expect(guardados.single, containsPair('zona', 'Capó'));
    expect(guardados.single, containsPair('tipo', 'entrega'));
    expect(tester.takeException(), isNull);
  });
}
