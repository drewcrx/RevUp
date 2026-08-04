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

      kilometraje: map['kilometraje'] is int
          ? map['kilometraje'] as int
          : int.tryParse((map['kilometraje'] ?? '0').toString()) ?? 0,

      ultimaVisita: DateTime.tryParse((map['ultima_visita'] ?? '').toString()),

      anio: map['anio'] is int ? map['anio'] as int : int.tryParse((map['anio'] ?? '').toString()),
      color: map['color']?.toString(),
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
