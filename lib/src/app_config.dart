class AppConfig {
  AppConfig({
    required this.environment,
    required String apiBaseUrl,
    String flavor = '',
  }) : apiBaseUrl = apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '') {
    if (!['local', 'production'].contains(environment)) {
      throw ArgumentError('APP_ENV debe ser local o production');
    }
    if (flavor.isNotEmpty && flavor != environment) {
      throw ArgumentError('La variante Android y APP_ENV deben coincidir');
    }
    final uri = Uri.tryParse(this.apiBaseUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !['http', 'https'].contains(uri.scheme)) {
      throw ArgumentError(
        'API_BASE_URL debe ser una URL absoluta sin credenciales',
      );
    }
    if (environment == 'production' && uri.scheme != 'https') {
      throw ArgumentError('Producción requiere HTTPS');
    }
    if (environment == 'local' &&
        (!isPrivateIpv4(uri.host) || uri.host == '10.0.2.2')) {
      throw ArgumentError(
        'Usa la IP privada de la PC; localhost no sirve en el teléfono',
      );
    }
  }

  final String environment;
  final String apiBaseUrl;
  bool get isLocal => environment == 'local';

  static bool isPrivateIpv4(String host) {
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((n) => n == null || n < 0 || n > 255))
      return false;
    return parts[0] == 10 ||
        (parts[0] == 192 && parts[1] == 168) ||
        (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31);
  }

  static final current = AppConfig(
    environment: const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'production',
    ),
    flavor: const String.fromEnvironment('FLUTTER_APP_FLAVOR'),
    apiBaseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.revup.example',
    ),
  );
}
