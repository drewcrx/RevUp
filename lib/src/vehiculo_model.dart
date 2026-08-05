import 'dart:convert';

class Vehiculo {
  int? id;

  final String marca;
  final String modelo;
  final String placa;

  int kilometraje;
  DateTime? ultimaVisita;

  // NUEVOS
  int? anio;
  String? color;
  int? propietarioId;
  String? propietarioNombre;
  String? propietarioTelefono;
  String? notaIngreso;

  // ✅ NUEVO
  String? tipoVehiculo;

  // ✅ NUEVO (Fase 1 — catálogos)
  String? tipoCombustible;
  String? transmision;
  String? cilindraje;

  // QR activo
  String? qrToken;

  Vehiculo({
    this.id,
    required this.marca,
    required this.modelo,
    required this.placa,
    required this.kilometraje,
    required this.ultimaVisita,
    this.anio,
    this.color,
    this.propietarioId,
    this.propietarioNombre,
    this.propietarioTelefono,
    this.notaIngreso,
    this.tipoVehiculo,
    this.tipoCombustible,
    this.transmision,
    this.cilindraje,
    this.qrToken,
  });

  factory Vehiculo.fromMap(Map<String, dynamic> map) {
    return Vehiculo(
      id: map['id'] is int ? map['id'] as int : int.tryParse((map['id'] ?? '').toString()),
      marca: (map['marca'] ?? '').toString(),
      modelo: (map['modelo'] ?? '').toString(),
      placa: (map['placa'] ?? '').toString(),

      // Postgres devuelve columnas numeric como string con decimal
      // (ej. "42000.0"): int.tryParse falla con el punto y siempre da
      // null -> 0, aunque el valor SÍ esté guardado. double.tryParse sí
      // acepta el decimal.
      kilometraje: map['kilometraje'] is int
          ? map['kilometraje'] as int
          : (double.tryParse((map['kilometraje'] ?? '0').toString()))?.round() ?? 0,

      ultimaVisita: DateTime.tryParse((map['ultima_visita'] ?? '').toString()),

      anio: map['anio'] is int ? map['anio'] as int : int.tryParse((map['anio'] ?? '').toString()),
      color: map['color']?.toString(),
      propietarioId: map['propietario_id'] is int
          ? map['propietario_id'] as int
          : int.tryParse((map['propietario_id'] ?? '').toString()),
      propietarioNombre: map['propietario_nombre']?.toString(),
      propietarioTelefono: map['propietario_telefono']?.toString(),
      notaIngreso: map['nota_ingreso']?.toString(),

      // ✅ NUEVO
      tipoVehiculo: map['tipo_vehiculo']?.toString(),

      // ✅ NUEVO (Fase 1 — catálogos)
      tipoCombustible: map['tipo_combustible']?.toString(),
      transmision: map['transmision']?.toString(),
      cilindraje: map['cilindraje']?.toString(),

      qrToken: map['qr_token']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'marca': marca,
      'modelo': modelo,
      'placa': placa,
      'kilometraje': kilometraje,
      'ultima_visita': ultimaVisita?.toIso8601String(),
      'anio': anio,
      'color': color,
      'propietario_id': propietarioId,
      'propietario_nombre': propietarioNombre,
      'propietario_telefono': propietarioTelefono,
      'nota_ingreso': notaIngreso,

      // ✅ NUEVO
      'tipo_vehiculo': tipoVehiculo,

      // ✅ NUEVO (Fase 1 — catálogos)
      'tipo_combustible': tipoCombustible,
      'transmision': transmision,
      'cilindraje': cilindraje,

      'qr_token': qrToken,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory Vehiculo.fromJson(String source) =>
      Vehiculo.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
