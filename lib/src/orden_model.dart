class OrdenTrabajo {
  final int id;
  final String placa;
  final int mechanicId;
  final String symptoms;
  final String estado;
  final String pagoEstado;
  final double totalServicios;
  final double totalRepuestos;
  final double total;
  final DateTime createdAt;

  // Datos agregados a la OT despues de la primera version de este modelo.
  final String? diagnostico;
  final String? mechanicNombre;
  final DateTime? closedAt;
  final int actualizacionesCount;

  OrdenTrabajo({
    required this.id,
    required this.placa,
    required this.mechanicId,
    required this.symptoms,
    required this.estado,
    required this.pagoEstado,
    required this.totalServicios,
    required this.totalRepuestos,
    required this.total,
    required this.createdAt,
    this.diagnostico,
    this.mechanicNombre,
    this.closedAt,
    this.actualizacionesCount = 0,
  });

  bool get tieneDiagnostico => (diagnostico ?? '').trim().isNotEmpty;

  factory OrdenTrabajo.fromMap(Map<String, dynamic> m) {
    return OrdenTrabajo(
      // tryParse en todo: una sola fila con un campo inesperado (ej. sin
      // mecanico asignado) no debe tumbar la lista completa de OTs.
      id: int.tryParse((m['id'] ?? '').toString()) ?? 0,
      placa: (m['placa'] ?? '').toString(),
      mechanicId: int.tryParse((m['mechanic_id'] ?? '').toString()) ?? 0,
      symptoms: (m['symptoms'] ?? '').toString(),
      estado: (m['estado'] ?? '').toString(),
      pagoEstado: (m['pago_estado'] ?? '').toString(),
      totalServicios: double.tryParse((m['total_servicios'] ?? 0).toString()) ?? 0,
      totalRepuestos: double.tryParse((m['total_repuestos'] ?? 0).toString()) ?? 0,
      total: double.tryParse((m['total'] ?? 0).toString()) ?? 0,
      // El backend manda las fechas en UTC (con sufijo Z); sin .toLocal()
      // Dart deja el DateTime marcado como UTC y day/month/hour devuelven
      // los valores UTC crudos, no la hora real de Ecuador.
      createdAt: DateTime.tryParse((m['created_at'] ?? '').toString())?.toLocal() ?? DateTime.now(),
      diagnostico: m['diagnostico']?.toString(),
      mechanicNombre: m['mechanic_nombre']?.toString(),
      closedAt: DateTime.tryParse((m['closed_at'] ?? '').toString())?.toLocal(),
      actualizacionesCount: int.tryParse((m['actualizaciones_count'] ?? '0').toString().split('.').first) ?? 0,
    );
  }
}
