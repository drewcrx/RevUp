import 'package:flutter_test/flutter_test.dart';
import 'package:menudrawer/src/app_config.dart';

void main() {
  test('local usa una IP privada real y normaliza la URL', () {
    final config = AppConfig(
      environment: 'local',
      apiBaseUrl: 'http://192.168.1.11:3000/',
    );
    expect(config.apiBaseUrl, 'http://192.168.1.11:3000');
    expect(config.isLocal, isTrue);
  });
  for (final host in ['localhost', '127.0.0.1', '10.0.2.2', '8.8.8.8']) {
    test('local rechaza dirección no válida para el teléfono: $host', () {
      expect(
        () => AppConfig(environment: 'local', apiBaseUrl: 'http://$host:3000'),
        throwsArgumentError,
      );
    });
  }
  test('producción exige HTTPS y no admite credenciales en la URL', () {
    expect(
      () => AppConfig(
        environment: 'production',
        apiBaseUrl: 'http://api.example.com',
      ),
      throwsArgumentError,
    );
    expect(
      () => AppConfig(
        environment: 'production',
        apiBaseUrl: 'https://user:secret@api.example.com',
      ),
      throwsArgumentError,
    );
    expect(
      AppConfig(
        environment: 'production',
        apiBaseUrl: 'https://api.example.com',
      ).isLocal,
      isFalse,
    );
  });
  test('impide mezclar la variante de producción con configuración local', () {
    expect(
      () => AppConfig(
        environment: 'local',
        flavor: 'production',
        apiBaseUrl: 'http://192.168.1.11:3000',
      ),
      throwsArgumentError,
    );
  });
}
