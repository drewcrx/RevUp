import 'package:flutter/material.dart';
import 'api_service.dart';
import 'formulario.dart';
import 'share_text.dart';

class RecordatoriosPage extends StatefulWidget {
  final String? placa;
  const RecordatoriosPage({super.key, this.placa});
  @override
  State<RecordatoriosPage> createState() => _RecordatoriosPageState();
}

class _RecordatoriosPageState extends State<RecordatoriosPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true, _completados = false, _vencidos = false;
  String _error = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final rows = await ApiService.taller('recordatorios') as List;
      if (mounted)
        setState(() {
          _rows = rows.cast<Map<String, dynamic>>();
          _error = '';
        });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _crear() async {
    try {
      final vehicles = await ApiService.obtenerVehiculos();
      if (!mounted) return;
      if (vehicles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registra primero un vehículo activo.')),
        );
        return;
      }
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => FormularioPage(
            title: 'Próximo servicio',
            ayuda:
                'El recordatorio aparecerá como vencido al alcanzar la fecha o el kilometraje. Puedes compartirlo con el cliente desde la lista.',
            campos: [
              CampoFormulario(
                'placa',
                'Vehículo',
                initial: widget.placa ?? '',
                opciones: vehicles.map((v) => v.placa).toList(),
              ),
              const CampoFormulario('titulo', 'Servicio / motivo'),
              const CampoFormulario(
                'fecha',
                'Fecha',
                fecha: true,
                requerido: false,
              ),
              CampoFormulario(
                'kilometraje',
                'Kilometraje objetivo',
                numero: true,
                requerido: false,
                validator: (v) =>
                    (v ?? '').isEmpty || (int.tryParse(v!) ?? 0) > 0
                    ? null
                    : 'Kilometraje inválido',
              ),
            ],
            guardar: (v) async {
              if (v['fecha']!.isEmpty && v['kilometraje']!.isEmpty)
                throw Exception('Indica una fecha o un kilometraje');
              await ApiService.taller(
                'recordatorios',
                method: 'POST',
                body: {
                  ...v,
                  'fecha': v['fecha']!.isEmpty ? null : v['fecha'],
                  'kilometraje': int.tryParse(v['kilometraje']!),
                },
              );
            },
          ),
        ),
      );
      if (ok == true) await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    try {
      await ApiService.taller(
        'recordatorios/${row['id']}',
        method: 'PUT',
        body: {'completado': row['completado'] != true},
      );
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows
        .where(
          (r) =>
              (widget.placa == null || r['placa'] == widget.placa) &&
              (_completados || r['completado'] != true) &&
              (!_vencidos || r['vencido'] == true),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.placa == null
              ? 'Recordatorios'
              : 'Recordatorios · ${widget.placa}',
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crear,
        icon: const Icon(Icons.add_alert),
        label: const Text('Recordatorio'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Solo vencidos'),
                  selected: _vencidos,
                  onSelected: (v) => setState(() => _vencidos = v),
                ),
                FilterChip(
                  label: const Text('Incluir completados'),
                  selected: _completados,
                  onSelected: (v) => setState(() => _completados = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                ? Center(
                    child: TextButton(
                      onPressed: _load,
                      child: Text('$_error\nReintentar'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                      children: [
                        if (rows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Sin recordatorios para estos filtros. Programa el próximo servicio por fecha o kilometraje.',
                            ),
                          ),
                        for (final row in rows)
                          Card(
                            child: ListTile(
                              leading: Icon(
                                row['completado'] == true
                                    ? Icons.check_circle
                                    : row['vencido'] == true
                                    ? Icons.notification_important
                                    : Icons.notifications_outlined,
                                color: row['vencido'] == true
                                    ? Colors.orangeAccent
                                    : null,
                              ),
                              title: Text('${row['placa']} · ${row['titulo']}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (row['propietario_nombre'] != null)
                                    Text('${row['propietario_nombre']}'),
                                  if (row['fecha'] != null)
                                    Text(
                                      'Fecha: ${row['fecha'].toString().split('T').first}',
                                    ),
                                  if (row['kilometraje'] != null)
                                    Text(
                                      'A los ${row['kilometraje']} km · Actual ${row['km_actual']} km',
                                    ),
                                  if (row['vencido'] == true)
                                    const Text(
                                      'Servicio pendiente',
                                      style: TextStyle(
                                        color: Colors.orangeAccent,
                                      ),
                                    ),
                                  Wrap(
                                    children: [
                                      TextButton(
                                        onPressed: () => _toggle(row),
                                        child: Text(
                                          row['completado'] == true
                                              ? 'Reactivar'
                                              : 'Marcar completado',
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Compartir recordatorio',
                                        icon: const Icon(Icons.share_outlined),
                                        onPressed: () async {
                                          final shared = await compartirTexto(
                                            'RevUp · Recordatorio de servicio\nVehículo: ${row['placa']}\n${row['titulo']}${row['fecha'] == null ? '' : '\nFecha: ${row['fecha'].toString().split('T').first}'}${row['kilometraje'] == null ? '' : '\nKilometraje: ${row['kilometraje']} km'}',
                                          );
                                          if (!shared && context.mounted)
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Recordatorio copiado al portapapeles',
                                                ),
                                              ),
                                            );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
