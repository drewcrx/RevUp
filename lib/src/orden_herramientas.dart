import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'api_service.dart';
import 'formulario.dart';
import 'share_text.dart';
import 'ui_tools.dart';

Future<Uint8List> crearPdfOrden(Map<String, dynamic> data) async {
  final ot = Map<String, dynamic>.from(data['ot'] ?? {}),
      v = Map<String, dynamic>.from(data['vehiculo'] ?? {});
  final pagos = (data['pagos'] as List? ?? []).cast<Map<String, dynamic>>();
  final abonado = pagos.fold(
    0.0,
    (sum, p) => sum + (double.tryParse('${p['monto']}') ?? 0),
  );
  final total = double.tryParse('${ot['total']}') ?? 0;
  final font = pw.Font.ttf(await rootBundle.load('fonts/Ubuntu-Light.ttf'));
  final pdf = pw.Document();
  pw.Widget line(String label, dynamic value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Text('$label: ${value ?? "—"}'),
  );
  final token = v['qr_token'];
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: font),
      footer: (ctx) => pw.Text(
        'RevUp · OT #${ot['id']} · Página ${ctx.pageNumber} de ${ctx.pagesCount}',
        style: const pw.TextStyle(fontSize: 9),
      ),
      build: (_) => [
        pw.Text(
          'RevUp · Orden de trabajo #${ot['id']}',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 16),
        line(
          'Vehículo',
          '${ot['placa']} · ${v['marca'] ?? ''} ${v['modelo'] ?? ''}',
        ),
        line('Cliente', v['propietario_nombre']),
        line('Teléfono', v['propietario_telefono']),
        line('Kilometraje de ingreso', ot['kilometraje_ot']),
        line('Mecánico', ot['mechanic_nombre']),
        line(
          'Estado',
          ot['estado'] == 'ENTREGADO'
              ? 'ENTREGADO'
              : ot['fase'] ?? ot['estado'],
        ),
        line(
          'Ingreso',
          DateTime.tryParse(
            '${ot['created_at']}',
          )?.toLocal().toString().split('.').first,
        ),
        if (ot['closed_at'] != null)
          line(
            'Entrega',
            DateTime.tryParse(
              '${ot['closed_at']}',
            )?.toLocal().toString().split('.').first,
          ),
        pw.Divider(),
        line('Síntomas', ot['symptoms']),
        line('Diagnóstico', ot['diagnostico']),
        pw.SizedBox(height: 12),
        pw.Text(
          'Servicios',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        for (final s in data['servicios'] as List? ?? [])
          line('${s['descripcion']}', dinero(s['precio'])),
        pw.SizedBox(height: 12),
        pw.Text(
          'Repuestos',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        for (final r in data['repuestos'] as List? ?? [])
          line(
            '${r['nombre']} · ${r['cantidad']} × ${dinero(r['precio_unitario'])}',
            dinero(
              (num.tryParse('${r['cantidad']}') ?? 0) *
                  (num.tryParse('${r['precio_unitario']}') ?? 0),
            ),
          ),
        pw.Divider(),
        line('Total', dinero(total)),
        line('Abonado', dinero(abonado)),
        line(
          'Saldo pendiente',
          dinero((total - abonado).clamp(0.0, double.infinity)),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Pagos registrados',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        for (final p in pagos)
          line(
            '${p['metodo']} · ${DateTime.tryParse('${p['created_at']}')?.toLocal().toString().split('.').first ?? ''}',
            dinero(p['monto']),
          ),
        for (final c in data['checklists'] as List? ?? []) ...[
          pw.SizedBox(height: 14),
          pw.Text(
            'Inspección de ${c['tipo']}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          line('Revisada', c['revisado'] == true ? 'Sí' : 'Pendiente'),
          line(
            'Combustible',
            c['combustible'] == null ? 'Sin registrar' : '${c['combustible']}%',
          ),
          line('Accesorios', c['accesorios']),
          line('Daños', c['revision_danos']),
          line('Observaciones', c['observaciones']),
        ],
        if ((data['danos'] as List? ?? []).isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text('Daños documentados'),
          for (final d in data['danos'] as List)
            line(
              '${d['tipo'] ?? 'ingreso'} · ${d['vista']} · ${d['zona']}',
              [
                d['estado_dano'],
                d['observaciones'],
              ].where((v) => v != null).join(' · '),
            ),
        ],
        for (final n in (data['anotaciones'] as List? ?? []).where(
          (n) => n['clase'] == 'NOTA',
        )) ...[
          pw.SizedBox(height: 10),
          line(
            'Anotación · ${n['autor']} · ${DateTime.tryParse('${n['created_at']}')?.toLocal().toString().split('.').first ?? ''}',
            n['texto'],
          ),
        ],
        if (token != null) ...[
          pw.SizedBox(height: 18),
          pw.Text('Seguimiento del vehículo'),
          pw.SizedBox(height: 6),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: '${ApiService.baseUrl}/v/$token',
            width: 90,
            height: 90,
          ),
        ],
      ],
    ),
  );
  return pdf.save();
}

class OrdenHerramientas extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onChanged;
  const OrdenHerramientas({
    super.key,
    required this.data,
    required this.onChanged,
  });
  Map<String, dynamic> get ot => Map<String, dynamic>.from(data['ot'] ?? {});
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final closed = ot['estado'] == 'ENTREGADO';
    final checks = (data['checklists'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final notes = (data['anotaciones'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    return Card(
      color: const Color(0xFF080E1A),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recepción y seguimiento',
                    style: TextStyle(
                      color: Color(0xFFF0F4FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!closed)
                  PopupMenuButton<String>(
                    tooltip: 'Cambiar etapa del trabajo',
                    initialValue: '${ot['fase'] ?? 'RECIBIDO'}',
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'RECIBIDO', child: Text('Recibido')),
                      PopupMenuItem(
                        value: 'EN_PROCESO',
                        child: Text('En proceso'),
                      ),
                      PopupMenuItem(
                        value: 'LISTO',
                        child: Text('Listo para retirar'),
                      ),
                    ],
                    onSelected: (fase) => _run(context, () async {
                      await ApiService.taller(
                        'ordenes/${ot['id']}/etapa',
                        method: 'PUT',
                        body: {'fase': fase},
                      );
                      await onChanged();
                    }),
                    icon: const Icon(
                      Icons.change_circle_outlined,
                      color: Color(0xFF1E90FF),
                    ),
                  ),
              ],
            ),
            Text(
              closed
                  ? 'Entregado'
                  : '${ot['fase'] ?? 'RECIBIDO'}'.replaceAll('_', ' '),
              style: const TextStyle(
                color: Colors.lightGreenAccent,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            for (final tipo in ['ingreso', 'entrega'])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  checks.any((c) => c['tipo'] == tipo && c['revisado'] == true)
                      ? Icons.check_circle_outline
                      : Icons.radio_button_unchecked,
                  color:
                      checks.any(
                        (c) => c['tipo'] == tipo && c['revisado'] == true,
                      )
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                ),
                title: Text(
                  'Lista de $tipo',
                  style: const TextStyle(
                    color: Color(0xFFF0F4FF),
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  checks.any((c) => c['tipo'] == tipo && c['revisado'] == true)
                      ? 'Inspección revisada'
                      : 'Inspección pendiente',
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
                ),
                trailing: closed && tipo == 'ingreso'
                    ? const Icon(Icons.lock_outline, size: 16)
                    : const Icon(Icons.chevron_right),
                onTap: closed && tipo == 'ingreso'
                    ? null
                    : () async {
                        final ok = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChecklistPage(
                              ordenId: ot['id'] as int,
                              tipo: tipo,
                              initial: checks
                                  .where((c) => c['tipo'] == tipo)
                                  .firstOrNull,
                            ),
                          ),
                        );
                        if (ok == true) await onChanged();
                      },
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _run(context, () async {
                    final bytes = await crearPdfOrden(data);
                    await Printing.layoutPdf(
                      name: 'OT-${ot['id']}-${ot['placa']}.pdf',
                      onLayout: (_) => bytes,
                    );
                  }),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                  label: const Text('PDF de la OT'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _run(context, () async {
                    final v = Map<String, dynamic>.from(data['vehiculo'] ?? {});
                    if (v['qr_token'] == null)
                      throw Exception('Este vehículo no tiene un QR activo');
                    final shared = await compartirTexto(
                      'RevUp · Seguimiento de ${ot['placa']}\n${ApiService.baseUrl}/v/${v['qr_token']}',
                    );
                    if (!shared && context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enlace copiado al portapapeles'),
                        ),
                      );
                  }),
                  icon: const Icon(Icons.share_outlined, size: 17),
                  label: const Text('Compartir'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CompararFotosPage(
                        fotos: (data['fotos'] as List? ?? [])
                            .cast<Map<String, dynamic>>(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.compare_outlined, size: 17),
                  label: const Text('Ingreso / entrega'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FormularioPage(
                          title: 'Anotacion para seguimiento',
                          ayuda:
                              'Se conserva autor y fecha sin modificar el diagnostico original. Esta anotacion tambien sera visible para el cliente en el seguimiento QR.',
                          campos: const [
                            CampoFormulario('texto', 'Observación', lineas: 5),
                          ],
                          guardar: (v) async {
                            await ApiService.taller(
                              'ordenes/${ot['id']}/anotaciones',
                              method: 'POST',
                              body: v,
                            );
                          },
                        ),
                      ),
                    );
                    if (ok == true) await onChanged();
                  },
                  icon: const Icon(Icons.edit_note, size: 17),
                  label: const Text('Anotación'),
                ),
              ],
            ),
            if (notes.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Actividad y anotaciones (${notes.length})',
                  style: const TextStyle(
                    color: Color(0xFFF0F4FF),
                    fontSize: 12,
                  ),
                ),
                children: [
                  for (final n in notes)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${n['texto']}',
                        style: const TextStyle(
                          color: Color(0xFFF0F4FF),
                          fontSize: 12,
                        ),
                      ),
                      subtitle: Text(
                        '${n['autor']} · ${DateTime.tryParse('${n['created_at']}')?.toLocal().toString().split('.').first ?? ''}',
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class ChecklistPage extends StatefulWidget {
  final int ordenId;
  final String tipo;
  final Map<String, dynamic>? initial;
  const ChecklistPage({
    super.key,
    required this.ordenId,
    required this.tipo,
    this.initial,
  });
  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  late final _accesorios = TextEditingController(
    text: '${widget.initial?['accesorios'] ?? ''}',
  );
  late final _obs = TextEditingController(
    text: '${widget.initial?['observaciones'] ?? ''}',
  );
  late double? _combustible = widget.initial?['combustible'] == null
      ? null
      : (widget.initial!['combustible'] as num).toDouble();
  late String _revision = '${widget.initial?['revision_danos'] ?? 'PENDIENTE'}';
  late bool _revisado = widget.initial?['revisado'] == true;
  bool _dirty = false, _saving = false;
  @override
  void dispose() {
    _accesorios.dispose();
    _obs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProtegerFormulario(
    tieneCambios: () => _dirty,
    guardando: _saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text('Lista de ${widget.tipo}'),
        leading: BackButton(
          onPressed: _saving ? null : () => Navigator.maybePop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Nivel de combustible'),
          Text(
            _combustible == null
                ? 'Sin registrar'
                : '${_combustible!.round()}%',
          ),
          Slider(
            value: _combustible ?? 0,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${(_combustible ?? 0).round()}%',
            onChanged: _saving
                ? null
                : (v) => setState(() {
                    _combustible = v;
                    _dirty = true;
                  }),
          ),
          TextField(
            controller: _accesorios,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Accesorios / objetos recibidos',
            ),
            maxLines: 3,
            onChanged: (_) => setState(() => _dirty = true),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _revision,
            decoration: const InputDecoration(labelText: 'Revisión de daños'),
            items: const [
              DropdownMenuItem(
                value: 'PENDIENTE',
                child: Text('Todavía sin inspeccionar'),
              ),
              DropdownMenuItem(
                value: 'SIN_DANOS',
                child: Text('Revisado: sin daños'),
              ),
              DropdownMenuItem(
                value: 'CON_DANOS',
                child: Text('Revisado: con daños registrados'),
              ),
            ],
            onChanged: _saving
                ? null
                : (v) => setState(() {
                    _revision = v!;
                    _dirty = true;
                  }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _obs,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Observaciones'),
            maxLines: 4,
            onChanged: (_) => setState(() => _dirty = true),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'He revisado el vehículo y los datos de esta lista',
            ),
            value: _revisado,
            onChanged: _saving
                ? null
                : (v) => setState(() {
                    _revisado = v!;
                    _dirty = true;
                  }),
          ),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await ApiService.taller(
                        'ordenes/${widget.ordenId}/checklist/${widget.tipo}',
                        method: 'PUT',
                        body: {
                          'combustible': _combustible?.round(),
                          'accesorios': _accesorios.text.trim(),
                          'observaciones': _obs.text.trim(),
                          'revision_danos': _revision,
                          'revisado': _revisado,
                        },
                      );
                      if (!mounted) return;
                      setState(() {
                        _dirty = false;
                        _saving = false;
                      });
                      Navigator.pop(context, true);
                    } catch (e) {
                      if (mounted) {
                        setState(() => _saving = false);
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
            child: Text(_saving ? 'Guardando…' : 'Guardar inspección'),
          ),
        ],
      ),
    ),
  );
}

class CompararFotosPage extends StatelessWidget {
  final List<Map<String, dynamic>> fotos;
  const CompararFotosPage({super.key, required this.fotos});
  @override
  Widget build(BuildContext context) {
    final panels = [
      for (final tipo in ['ingreso', 'entrega'])
        _FotosEtapa(
          tipo: tipo,
          fotos: fotos.where((f) => f['tipo'] == tipo).toList(),
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Comparar ingreso y entrega')),
      body: LayoutBuilder(
        builder: (_, c) => c.maxWidth >= 700
            ? Row(
                children: [for (final panel in panels) Expanded(child: panel)],
              )
            : ListView(
                children: [
                  for (final panel in panels)
                    SizedBox(height: 350, child: panel),
                ],
              ),
      ),
    );
  }
}

class _FotosEtapa extends StatefulWidget {
  final String tipo;
  final List<Map<String, dynamic>> fotos;
  const _FotosEtapa({required this.tipo, required this.fotos});
  @override
  State<_FotosEtapa> createState() => _FotosEtapaState();
}

class _FotosEtapaState extends State<_FotosEtapa> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        Text(
          '${widget.tipo.toUpperCase()} · ${widget.fotos.isEmpty ? 'Sin fotos' : '${_index + 1}/${widget.fotos.length}'}',
        ),
        const SizedBox(height: 8),
        Expanded(
          child: widget.fotos.isEmpty
              ? const Center(
                  child: Icon(Icons.no_photography_outlined, size: 40),
                )
              : PageView.builder(
                  itemCount: widget.fotos.length,
                  onPageChanged: (v) => setState(() => _index = v),
                  itemBuilder: (_, i) => InkWell(
                    onTap: () => showDialog(
                      context: context,
                      builder: (ctx) => Dialog.fullscreen(
                        child: Scaffold(
                          appBar: AppBar(
                            title: Text('Foto de ${widget.tipo}'),
                            leading: CloseButton(
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ),
                          body: InteractiveViewer(
                            minScale: 1,
                            maxScale: 5,
                            child: Center(child: _image(i)),
                          ),
                        ),
                      ),
                    ),
                    child: _image(i),
                  ),
                ),
        ),
        if (widget.fotos.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Desliza para cambiar · Toca para ampliar',
              style: TextStyle(fontSize: 10),
            ),
          ),
      ],
    ),
  );
  Widget _image(int i) => Image.network(
    '${widget.fotos[i]['url']}',
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) =>
        const Center(child: Icon(Icons.broken_image_outlined)),
  );
}
