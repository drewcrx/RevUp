import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:menudrawer/src/api_service.dart';
import 'package:menudrawer/src/session.dart';
import 'package:menudrawer/src/session_client.dart';
import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late http.Client original;
  setUp(() async {
    original = ApiService.client;
    SharedPreferences.setMockInitialValues({});
    await Session.setSession(user: {'nombre': 'Ana'}, token: testToken());
  });
  tearDown(() async {
    ApiService.client.close();
    ApiService.client = original;
    await Session.clear();
  });

  for (final kind in ['ot', 'dano', 'actualizacion']) {
    test(
      'sube foto $kind desde bytes sin ruta de disco (también web)',
      () async {
        final bytes = Uint8List.fromList([
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
          99,
          42,
        ]);
        final file = XFile.fromData(
          bytes,
          name: 'foto.png',
        path: 'foto.png',
          mimeType: 'image/png',
        );
        ApiService.client = SessionClient(
          MockClient((request) async {
            final body = latin1.decode(request.bodyBytes);
            expect(request.headers['Authorization'], 'Bearer ${Session.token}');
            expect(
              request.headers['content-type'],
              startsWith('multipart/form-data;'),
            );
            expect(body, contains('filename="foto.png"'));
            expect(body, contains('image/png'));
            expect(body, contains(latin1.decode(bytes)));
            final expected = kind == 'ot'
                ? '/ordenes/7/fotos'
                : kind == 'dano'
                ? '/ordenes/danos/8/fotos'
                : '/ordenes/actualizaciones/9/fotos';
            expect(request.url.path, expected);
            return http.Response('[{"id":1}]', 201);
          }),
        );
        final result = switch (kind) {
          'ot' => await ApiService.subirFotosOT(
            ordenId: 7,
            tipo: 'ingreso',
            archivos: [file],
          ),
          'dano' => await ApiService.subirFotosDano(
            danoId: 8,
            archivos: [file],
          ),
          _ => await ApiService.subirFotosActualizacion(
            actualizacionId: 9,
            archivos: [file],
          ),
        };
        expect(result.single['id'], 1);
      },
    );
  }

  test(
    'propaga el mensaje del backend al guardar un vehículo duplicado',
    () async {
      ApiService.client = MockClient(
        (_) async => http.Response('{"error":"La placa ya existe"}', 409),
      );
      await expectLater(
        ApiService.agregarVehiculo(
          marca: 'Toyota',
          modelo: 'Yaris',
          placa: 'ABC',
        ),
        throwsA(predicate((e) => e.toString().contains('La placa ya existe'))),
      );
    },
  );

  testWidgets('limita a 12 segundos una petición de guardado sin respuesta', (
    tester,
  ) async {
    ApiService.client = MockClient((_) => Completer<http.Response>().future);
    final pending = expectLater(
      ApiService.agregarVehiculo(
        marca: 'Toyota',
        modelo: 'Yaris',
        placa: 'ABC',
      ),
      throwsA(isA<TimeoutException>()),
    );
    await tester.pump(const Duration(seconds: 13));
    await pending;
  });
}
