// api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'vehiculo_model.dart';
import 'session.dart';

class ApiService {
  static const String baseUrl = "https://backrevup.byronrm.com";

  // =========================
  // Helpers
  // =========================
  static Map<String, String> _headersAuth() {
    final t = Session.token;
    if (t == null || t.trim().isEmpty) {
      return {'Content-Type': 'application/json'};
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $t',
    };
  }

  static Exception _httpError(http.Response res, String msgBase) {
    try {
      final data = jsonDecode(res.body);
      final msg = (data['error'] ?? data['mensaje'] ?? res.body).toString();
      return Exception("$msgBase (HTTP ${res.statusCode}) - $msg");
    } catch (_) {
      return Exception("$msgBase (HTTP ${res.statusCode})");
    }
  }

  // =========================
  // QR / HISTORIAL (privado)
  // =========================

  static Future<Map<String, dynamic>?> buscarDetallePorQrToken(String token) async {
    final url = Uri.parse("$baseUrl/vehiculos/qr/$token");
    final res = await http.get(url, headers: _headersAuth());

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>?> obtenerHistorialPorQrToken(String token) async {
    final url = Uri.parse("$baseUrl/vehiculos/qr/$token/historial");
    final res = await http.get(url, headers: _headersAuth());

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data["historial"] as List).cast<Map<String, dynamic>>();
      return list;
    }
    return null;
  }

  // =========================
  // VEHICULOS (privado)
  // =========================

  static Future<List<Vehiculo>> obtenerVehiculos() async {
    final url = Uri.parse("$baseUrl/vehiculos");
    final res = await http.get(url, headers: _headersAuth());

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((v) => Vehiculo.fromMap(v)).toList();
    }

    throw _httpError(res, "Error al obtener vehículos");
  }

  static Future<Vehiculo?> buscarPorPlaca(String placa) async {
    final url = Uri.parse("$baseUrl/vehiculos/${placa.toUpperCase()}");
    final res = await http.get(url, headers: _headersAuth());

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return Vehiculo.fromMap(data);
    }
    if (res.statusCode == 404) return null;

    throw _httpError(res, "Error al buscar vehículo");
  }

  // ✅ ACTUALIZADO: ahora soporta nuevos campos
  static Future<bool> agregarVehiculo({
    required String marca,
    required String modelo,
    required String placa,
    String? kilometraje,
    String? ultimaVisita,

    // NUEVOS
    int? anio,
    String? color,
    String? propietarioNombre,
    String? propietarioTelefono,
    String? notaIngreso,

    // ✅ NUEVO
    String? tipoVehiculo,
    String? tipoCombustible,
    String? transmision,
    String? cilindraje,
  }) async {
    final url = Uri.parse("$baseUrl/vehiculos");

    final Map<String, dynamic> bodyData = {
      "marca": marca,
      "modelo": modelo,
      "placa": placa.toUpperCase(),
    };

    if (kilometraje != null && kilometraje.trim().isNotEmpty) {
      bodyData["kilometraje"] = int.tryParse(kilometraje) ?? 0;
    }
    if (ultimaVisita != null && ultimaVisita.trim().isNotEmpty) {
      bodyData["ultima_visita"] = ultimaVisita.trim();
    }

    if (anio != null) bodyData["anio"] = anio;
    if (color != null && color.trim().isNotEmpty) bodyData["color"] = color.trim();

    if (propietarioNombre != null && propietarioNombre.trim().isNotEmpty) {
      bodyData["propietario_nombre"] = propietarioNombre.trim();
    }
    if (propietarioTelefono != null && propietarioTelefono.trim().isNotEmpty) {
      bodyData["propietario_telefono"] = propietarioTelefono.trim();
    }
    if (notaIngreso != null && notaIngreso.trim().isNotEmpty) {
      final n = notaIngreso.trim();
      bodyData["nota_ingreso"] = (n.length > 300) ? n.substring(0, 300) : n;
    }

    // ✅ NUEVO
    if (tipoVehiculo != null && tipoVehiculo.trim().isNotEmpty) {
      bodyData["tipo_vehiculo"] = tipoVehiculo.trim();
    }
    if (tipoCombustible != null && tipoCombustible.trim().isNotEmpty) {
      bodyData["tipo_combustible"] = tipoCombustible.trim();
    }
    if (transmision != null && transmision.trim().isNotEmpty) {
      bodyData["transmision"] = transmision.trim();
    }
    if (cilindraje != null && cilindraje.trim().isNotEmpty) {
      bodyData["cilindraje"] = cilindraje.trim();
    }

    final res = await http.post(
      url,
      headers: _headersAuth(),
      body: jsonEncode(bodyData),
    );

    return res.statusCode == 200;
  }

  // ✅ ACTUALIZADO: ahora soporta nuevos campos (sin romper llamadas viejas)
  static Future<bool> actualizarVehiculo({
    required String placa,
    int? kilometraje,
    String? ultimaVisita,

    // NUEVOS
    int? anio,
    String? color,
    String? propietarioNombre,
    String? propietarioTelefono,
    String? notaIngreso,

    // ✅ NUEVO
    String? tipoVehiculo,
    String? tipoCombustible,
    String? transmision,
    String? cilindraje,
  }) async {
    final url = Uri.parse("$baseUrl/vehiculos/${placa.toUpperCase()}");

    final Map<String, dynamic> body = {};

    if (kilometraje != null) body["kilometraje"] = kilometraje;
    if (ultimaVisita != null && ultimaVisita.trim().isNotEmpty) {
      body["ultima_visita"] = ultimaVisita.trim();
    }

    if (anio != null) body["anio"] = anio;
    if (color != null && color.trim().isNotEmpty) body["color"] = color.trim();

    if (propietarioNombre != null && propietarioNombre.trim().isNotEmpty) {
      body["propietario_nombre"] = propietarioNombre.trim();
    }
    if (propietarioTelefono != null && propietarioTelefono.trim().isNotEmpty) {
      body["propietario_telefono"] = propietarioTelefono.trim();
    }
    if (notaIngreso != null) {
      final n = notaIngreso.trim();
      body["nota_ingreso"] = n.isEmpty ? null : (n.length > 300 ? n.substring(0, 300) : n);
    }

    // ✅ NUEVO
    if (tipoVehiculo != null) {
      final t = tipoVehiculo.trim();
      body["tipo_vehiculo"] = t.isEmpty ? null : t;
    }
    if (tipoCombustible != null) {
      final t = tipoCombustible.trim();
      body["tipo_combustible"] = t.isEmpty ? null : t;
    }
    if (transmision != null) {
      final t = transmision.trim();
      body["transmision"] = t.isEmpty ? null : t;
    }
    if (cilindraje != null) {
      final t = cilindraje.trim();
      body["cilindraje"] = t.isEmpty ? null : t;
    }

    if (body.isEmpty) return false;

    final res = await http.put(
      url,
      headers: _headersAuth(),
      body: jsonEncode(body),
    );

    return res.statusCode == 200;
  }

  static Future<bool> eliminarVehiculoPorPlaca(String placa) async {
    final url = Uri.parse("$baseUrl/vehiculos/${placa.toUpperCase()}");
    final res = await http.delete(url, headers: _headersAuth());

    return res.statusCode == 200 || res.statusCode == 204;
  }

  // =========================
  // HISTORIAL DE OTs POR VEHÍCULO (privado)
  // =========================

  static Future<List<Map<String, dynamic>>> obtenerOtsDelVehiculo(String placa) async {
    final url = Uri.parse("$baseUrl/vehiculos/${placa.toUpperCase()}/ordenes");
    final res = await http
        .get(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    throw _httpError(res, "Error al obtener historial de OTs");
  }

  // =========================
  // CATÁLOGOS (privado) — marca/modelo, listas planas, repuestos
  // =========================

  static Future<List<Map<String, dynamic>>> obtenerMarcas() async {
    final url = Uri.parse("$baseUrl/catalogos/marcas");
    final res = await http.get(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw _httpError(res, "Error al obtener marcas");
  }

  static Future<List<Map<String, dynamic>>> obtenerModelos(int marcaId) async {
    final url = Uri.parse("$baseUrl/catalogos/marcas/$marcaId/modelos");
    final res = await http.get(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw _httpError(res, "Error al obtener modelos");
  }

  /// categoria: color | tipo_vehiculo | combustible | transmision
  static Future<List<String>> obtenerCatalogoItems(String categoria) async {
    final url = Uri.parse("$baseUrl/catalogos/items/$categoria");
    final res = await http.get(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      return data.map((e) => (e as Map)['valor'].toString()).toList();
    }
    throw _httpError(res, "Error al obtener catálogo");
  }

  static Future<List<Map<String, dynamic>>> buscarRepuestosCatalogo(String query) async {
    final url = Uri.parse("$baseUrl/catalogos/repuestos?q=${Uri.encodeQueryComponent(query)}");
    final res = await http.get(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw _httpError(res, "Error al obtener repuestos");
  }

  // =========================
  // USUARIOS (público)
  // =========================

  static Future<String?> resendVerification({required String correo}) async {
    final url = Uri.parse("$baseUrl/usuarios/resend-verification");

    try {
      final res = await http
          .post(
            url,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'correo': correo.trim()}),
          )
          .timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['mensaje'] ??
              "Si el correo existe, te enviamos el enlace de activación.")
          .toString();
    } catch (_) {
      return "No se pudo conectar al servidor. Verifica que el backend esté encendido.";
    }
  }

  static Future<String?> registrarUsuario({
    required String nombre,
    required String correo,
    required String usuario,
    required String password,
  }) async {
    final url = Uri.parse("$baseUrl/usuarios/register");

    final res = await http.post(
      url,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': nombre,
        'correo': correo,
        'usuario': usuario,
        'password': password,
      }),
    );

    if (res.statusCode == 200) return null;

    try {
      final data = jsonDecode(res.body);
      return (data['error'] ?? "Error desconocido").toString();
    } catch (_) {
      return "Error desconocido";
    }
  }

  /// ✅ Login: guarda user + token en Session.setSession(user:..., token:...)
  static Future<String?> loginUsuario({
    String? usuario,
    String? correo,
    required String password,
  }) async {
    final url = Uri.parse("$baseUrl/usuarios/login");

    try {
      final res = await http
          .post(
            url,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'usuario': usuario,
              'correo': correo,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        final token = (data['token'] ?? data['accessToken'] ?? data['jwt'])?.toString();
        final Map<String, dynamic> user =
            (data['user'] ?? data['usuario']) as Map<String, dynamic>;

        if (token == null || token.trim().isEmpty) {
          return "Login OK pero el backend no devolvió token.";
        }

        await Session.setSession(user: user, token: token);
        return null;
      }

      final data = jsonDecode(res.body);
      return (data['error'] ?? "Error de autenticación").toString();
    } catch (_) {
      return "No se pudo conectar al servidor. Verifica que el backend esté encendido.";
    }
  }

  /// Actualiza nombre y/o avatar del usuario logueado. Devuelve el usuario
  /// actualizado (para refrescar la sesión local), o null + mensaje de error.
  static Future<Map<String, dynamic>?> actualizarPerfil({
    String? nombre,
    String? avatarB64,
  }) async {
    final url = Uri.parse("$baseUrl/usuarios/perfil");

    final Map<String, dynamic> body = {};
    if (nombre != null) body['nombre'] = nombre;
    if (avatarB64 != null) body['avatar_b64'] = avatarB64;

    final res = await http
        .put(url, headers: _headersAuth(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['user'] as Map<String, dynamic>;
    }

    throw _httpError(res, "No se pudo actualizar el perfil");
  }

  /// Cambia la contraseña del usuario logueado (requiere la actual).
  static Future<String?> cambiarPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final url = Uri.parse("$baseUrl/usuarios/password");

    try {
      final res = await http
          .put(
            url,
            headers: _headersAuth(),
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) return null;

      final data = jsonDecode(res.body);
      return (data['error'] ?? "No se pudo cambiar la contraseña").toString();
    } catch (_) {
      return "No se pudo conectar al servidor. Verifica que el backend esté encendido.";
    }
  }

  // =========================
  // ORDENES DE TRABAJO (privado)
  // =========================

  static int _currentMechanicIdOrThrow() {
    final u = Session.user;
    final id = u?['id'];
    if (id == null) {
      throw Exception("No hay sesión activa (user.id es null)");
    }
    return int.parse(id.toString());
  }

  // =========================
  // OTs por PLACA (privado)  ✅ NUEVO
  // =========================
  static Future<List<Map<String, dynamic>>> obtenerOtsPorPlaca({
    required String placa,
  }) async {
    final p = placa.trim().toUpperCase();
    if (p.isEmpty) return [];

    final url = Uri.parse("$baseUrl/ordenes");

    final res = await http
        .get(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      final all = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final filtradas = all.where((o) {
        final placaOt = (o["placa"] ?? "").toString().toUpperCase();
        return placaOt == p;
      }).toList();

      filtradas.sort((a, b) {
        final da = DateTime.tryParse((a["created_at"] ?? "").toString()) ?? DateTime(1970);
        final db = DateTime.tryParse((b["created_at"] ?? "").toString()) ?? DateTime(1970);
        return db.compareTo(da);
      });

      return filtradas;
    }

    throw _httpError(res, "Error al obtener OTs por placa");
  }

  static Future<List<Map<String, dynamic>>> obtenerOrdenes({bool soloMias = true}) async {
    final url = soloMias
        ? Uri.parse("$baseUrl/ordenes?mechanicId=${_currentMechanicIdOrThrow()}")
        : Uri.parse("$baseUrl/ordenes");

    final res = await http
        .get(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));

    // ignore: avoid_print
    print("GET ORDENES status=${res.statusCode} body=${res.body}");

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      return data.cast<Map<String, dynamic>>();
    }

    throw _httpError(res, "Error al obtener órdenes");
  }

  static Future<List<Map<String, dynamic>>> obtenerOtsPorQrToken(String token) async {
    final url = Uri.parse("$baseUrl/vehiculos/qr/$token/ots");

    final res = await http
        .get(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    throw _httpError(res, "Error obteniendo OTs del vehículo (QR)");
  }

  static Future<Map<String, dynamic>> crearOrden({
    required String placa,
    required String symptoms,
  }) async {
    final url = Uri.parse("$baseUrl/ordenes");

    final res = await http
        .post(
          url,
          headers: _headersAuth(),
          body: jsonEncode({
            "placa": placa.toUpperCase(),
            "symptoms": symptoms,
          }),
        )
        .timeout(const Duration(seconds: 10));

    // ignore: avoid_print
    print("CREAR OT status=${res.statusCode} body=${res.body}");

    if (res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw _httpError(res, "Error creando OT");
  }

  static Future<Map<String, dynamic>> obtenerDetalleOrden(int ordenId) async {
    final url = Uri.parse("$baseUrl/ordenes/$ordenId");

    final res = await http
        .get(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));

    // ignore: avoid_print
    print("DETALLE OT status=${res.statusCode} body=${res.body}");

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw _httpError(res, "Error al obtener detalle OT");
  }

  static Future<void> agregarServicioOT({
    required int ordenId,
    required String descripcion,
    required double precio,
  }) async {
    final url = Uri.parse("$baseUrl/ordenes/$ordenId/servicios");

    final res = await http
        .post(
          url,
          headers: _headersAuth(),
          body: jsonEncode({"descripcion": descripcion, "precio": precio}),
        )
        .timeout(const Duration(seconds: 10));

    // ignore: avoid_print
    print("ADD SERV status=${res.statusCode} body=${res.body}");

    if (res.statusCode != 201) {
      throw _httpError(res, "No se pudo agregar servicio");
    }
  }

  static Future<void> agregarRepuestoOT({
    required int ordenId,
    required String nombre,
    required int cantidad,
    required double costoUnitario,
    required double precioUnitario,
  }) async {
    final url = Uri.parse("$baseUrl/ordenes/$ordenId/repuestos");

    final res = await http
        .post(
          url,
          headers: _headersAuth(),
          body: jsonEncode({
            "nombre": nombre,
            "cantidad": cantidad,
            "costoUnitario": costoUnitario,
            "precioUnitario": precioUnitario,
          }),
        )
        .timeout(const Duration(seconds: 10));

    // ignore: avoid_print
    print("ADD REP status=${res.statusCode} body=${res.body}");

    if (res.statusCode != 201) {
      throw _httpError(res, "No se pudo agregar repuesto");
    }
  }

  static Future<void> registrarPagoOT({
    required int ordenId,
    required double monto,
    required String metodo,
  }) async {
    final url = Uri.parse("$baseUrl/ordenes/$ordenId/pagos");

    final res = await http
        .post(
          url,
          headers: _headersAuth(),
          body: jsonEncode({"monto": monto, "metodo": metodo}),
        )
        .timeout(const Duration(seconds: 10));

    // ignore: avoid_print
    print("PAGO status=${res.statusCode} body=${res.body}");

    if (res.statusCode != 201) {
      throw _httpError(res, "No se pudo registrar pago");
    }
  }

  static Future<Map<String, dynamic>> cerrarOT(int ordenId) async {
    final url = Uri.parse("$baseUrl/ordenes/$ordenId/cerrar");

    final res = await http
        .post(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));

    // ignore: avoid_print
    print("CERRAR OT status=${res.statusCode} body=${res.body}");

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw _httpError(res, "Error cerrando OT");
  }

  /// tipo: 'ingreso' | 'entrega'
  static Future<List<Map<String, dynamic>>> subirFotosOT({
    required int ordenId,
    required String tipo,
    required List<XFile> archivos,
  }) async {
    final url = Uri.parse("$baseUrl/ordenes/$ordenId/fotos");
    final request = http.MultipartRequest('POST', url);

    final t = Session.token;
    if (t != null && t.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $t';
    }
    request.fields['tipo'] = tipo;
    for (final archivo in archivos) {
      request.files.add(await http.MultipartFile.fromPath('fotos', archivo.path));
    }

    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 201) {
      final List data = jsonDecode(res.body) as List;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw _httpError(res, "No se pudieron subir las fotos");
  }

  static Future<void> eliminarFotoOT(int fotoId) async {
    final url = Uri.parse("$baseUrl/ordenes/fotos/$fotoId");
    final res = await http
        .delete(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw _httpError(res, "No se pudo eliminar la foto");
    }
  }

  // =========================
  // REPORTES (privado)
  // =========================

  static Future<List<Map<String, dynamic>>> obtenerReporteMecanicos({String? month}) async {
    final q = (month != null && month.trim().isNotEmpty) ? "?month=${month.trim()}" : "";
    final url = Uri.parse("$baseUrl/reportes/mecanicos$q");

    final res = await http
        .get(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));

    // ignore: avoid_print
    print("REPORTES MEC status=${res.statusCode} body=${res.body}");

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    throw _httpError(res, "Error al obtener reporte");
  }

  static Future<Map<String, dynamic>> obtenerMiResumenMensual({String? month}) async {
    final q = (month != null && month.trim().isNotEmpty) ? "?month=${month.trim()}" : "";
    final url = Uri.parse("$baseUrl/reportes/mi-resumen$q");

    final res = await http
        .get(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw _httpError(res, "Error al obtener mi resumen mensual");
  }

  static Future<List<Map<String, dynamic>>> obtenerMisOtsDelMes({String? month}) async {
    final q = (month != null && month.trim().isNotEmpty) ? "?month=${month.trim()}" : "";
    final url = Uri.parse("$baseUrl/reportes/mi-mes/ordenes$q");

    final res = await http
        .get(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    throw _httpError(res, "Error al obtener mis OTs del mes");
  }

  static Future<Map<String, dynamic>> obtenerResumenMensual({String? month}) async {
    final q = (month != null && month.trim().isNotEmpty) ? "?month=${month.trim()}" : "";
    final url = Uri.parse("$baseUrl/reportes/resumen$q");

    final res = await http
        .get(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));

    // ignore: avoid_print
    print("RESUMEN MES status=${res.statusCode} body=${res.body}");

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw _httpError(res, "Error al obtener resumen mensual");
  }

  static Future<List<Map<String, dynamic>>> obtenerOtsMecanicoMes({
    required int mechanicId,
    String? month,
  }) async {
    final q = (month != null && month.trim().isNotEmpty) ? "?month=${month.trim()}" : "";
    final url = Uri.parse("$baseUrl/reportes/mecanicos/$mechanicId/ordenes$q");

    final res = await http
        .get(url, headers: _headersAuth())
        .timeout(const Duration(seconds: 10));

    // ignore: avoid_print
    print("OTS MEC MES status=${res.statusCode} body=${res.body}");

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    throw _httpError(res, "Error obteniendo OTs");
  }

  // =========================
  // RECUPERACIÓN (público)
  // =========================

  static Future<String?> forgotPassword({required String correo}) async {
    final url = Uri.parse("$baseUrl/usuarios/forgot-password");
    try {
      final res = await http
          .post(
            url,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'correo': correo.trim()}),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) return null;

      final data = jsonDecode(res.body);
      return (data['error'] ?? "Error enviando recuperación").toString();
    } catch (_) {
      return "No se pudo conectar al servidor.";
    }
  }

  static Future<String?> forgotUsername({required String correo}) async {
    final url = Uri.parse("$baseUrl/usuarios/forgot-username");

    try {
      final res = await http
          .post(
            url,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'correo': correo.trim()}),
          )
          .timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['mensaje'] ?? "Si el correo existe, te enviamos tu usuario.").toString();
    } catch (_) {
      return "No se pudo conectar al servidor. Verifica que el backend esté encendido.";
    }
  }

  // =========================
  // OTs por Vehículo (para QR)
  // =========================

  static Future<List<Map<String, dynamic>>> obtenerOtsPorQrOTokenOFallback({
    required String placa,
    required String token,
  }) async {
    if (token.trim().isNotEmpty) {
      final r1 = await _tryGetOtsByToken(token.trim());
      if (r1 != null) return r1;
    }

    if (placa.trim().isNotEmpty) {
      final r2 = await _getOtsByPlaca(placa.trim().toUpperCase());
      return r2;
    }

    return [];
  }

  static Future<List<Map<String, dynamic>>?> _tryGetOtsByToken(String token) async {
    final url = Uri.parse("$baseUrl/vehiculos/qr/$token/ots");
    final res = await http.get(url, headers: _headersAuth()).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      if (decoded is Map<String, dynamic> && decoded["ots"] is List) {
        return (decoded["ots"] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return <Map<String, dynamic>>[];
    }

    if (res.statusCode == 404) return null;

    throw _httpError(res, "Error obteniendo OTs por QR");
  }

  static Future<List<Map<String, dynamic>>> _getOtsByPlaca(String placa) async {
    final url = Uri.parse("$baseUrl/ordenes?placa=$placa");
    final res = await http.get(url, headers: _headersAuth()).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body) as List;
      return data.cast<Map<String, dynamic>>();
    }

    throw _httpError(res, "Error obteniendo OTs por placa");
  }
}
