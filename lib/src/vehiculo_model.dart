import 'dart:convert';

class Arreglo {
  int? id;
  String descripcion;
  String tipo;
  DateTime fecha;
  bool completado;

  Arreglo({
    this.id,
    required this.descripcion,
    required this.tipo,
    required this.fecha,
    this.completado = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'descripcion': descripcion,
      'tipo': tipo,
      'fecha': fecha.toIso8601String(),
      'completado': completado,
    };
  }

  factory Arreglo.fromMap(Map<String, dynamic> map) {
    return Arreglo(
      id: map['id'] is int ? map['id'] : int.tryParse((map['id'] ?? '').toString()),
      descripcion: (map['descripcion'] ?? '').toString(),
      tipo: (map['tipo'] ?? '').toString(),
      fecha: DateTime.tryParse((map['fecha'] ?? '').toString()) ?? DateTime.now(),
      completado: map['completado'] == true,
    );
  }
}

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

  // QR activo
  String? qrToken;

  List<Arreglo> arreglos;

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
    this.qrToken,
    this.arreglos = const [],
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

      qrToken: map['qr_token']?.toString(),

      arreglos: (map['arreglos'] is List)
          ? (map['arreglos'] as List)
              .map((e) => Arreglo.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : <Arreglo>[],
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

      'qr_token': qrToken,
      'arreglos': arreglos.map((e) => e.toMap()).toList(),
    };
  }

  String toJson() => jsonEncode(toMap());

  factory Vehiculo.fromJson(String source) =>
      Vehiculo.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
