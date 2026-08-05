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
      id: int.parse(m['id'].toString()),
      placa: (m['placa'] ?? '').toString(),
      mechanicId: int.parse(m['mechanic_id'].toString()),
      symptoms: (m['symptoms'] ?? '').toString(),
      estado: (m['estado'] ?? '').toString(),
      pagoEstado: (m['pago_estado'] ?? '').toString(),
      totalServicios: double.parse((m['total_servicios'] ?? 0).toString()),
      totalRepuestos: double.parse((m['total_repuestos'] ?? 0).toString()),
      total: double.parse((m['total'] ?? 0).toString()),
      createdAt: DateTime.tryParse((m['created_at'] ?? '').toString()) ?? DateTime.now(),
      diagnostico: m['diagnostico']?.toString(),
      mechanicNombre: m['mechanic_nombre']?.toString(),
      closedAt: DateTime.tryParse((m['closed_at'] ?? '').toString()),
      actualizacionesCount: int.tryParse((m['actualizaciones_count'] ?? '0').toString().split('.').first) ?? 0,
    );
  }
}
