import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);
const _kCard     = Color(0xFF080E1A);
const _kDano     = Colors.orangeAccent;

// ─── Catálogo de vistas y zonas (fijo — el esquema es siempre el mismo auto) ──
class _Zona {
  final String nombre;
  final double x; // posición normalizada 0..1 dentro del esquema
  final double y;
  const _Zona(this.nombre, this.x, this.y);
}

const Map<String, String> kVistaLabel = {
  'frontal': 'Frontal',
  'posterior': 'Posterior',
  'lateral_izquierdo': 'Lat. izquierdo',
  'lateral_derecho': 'Lat. derecho',
  'superior': 'Superior',
};

const Map<String, IconData> kVistaIcon = {
  'frontal': Icons.arrow_upward_rounded,
  'posterior': Icons.arrow_downward_rounded,
  'lateral_izquierdo': Icons.arrow_back_rounded,
  'lateral_derecho': Icons.arrow_forward_rounded,
  'superior': Icons.arrow_circle_up_rounded,
};

const Map<String, List<_Zona>> _zonasPorVista = {
  'frontal': [
    _Zona('Parabrisas', 0.5, 0.16),
    _Zona('Faro izquierdo', 0.18, 0.55),
    _Zona('Faro derecho', 0.82, 0.55),
    _Zona('Capó', 0.5, 0.42),
    _Zona('Rejilla', 0.5, 0.68),
    _Zona('Parachoques delantero', 0.5, 0.87),
    _Zona('Placa delantera', 0.5, 0.97),
  ],
  'posterior': [
    _Zona('Luneta', 0.5, 0.16),
    _Zona('Stop izquierdo', 0.18, 0.55),
    _Zona('Stop derecho', 0.82, 0.55),
    _Zona('Baúl / compuerta', 0.5, 0.42),
    _Zona('Parachoques posterior', 0.5, 0.87),
    _Zona('Placa posterior', 0.5, 0.97),
  ],
  'lateral_izquierdo': [
    _Zona('Techo', 0.5, 0.10),
    _Zona('Espejo', 0.24, 0.24),
    _Zona('Guardafango delantero', 0.13, 0.55),
    _Zona('Puerta delantera', 0.35, 0.55),
    _Zona('Puerta posterior', 0.63, 0.55),
    _Zona('Guardafango posterior', 0.87, 0.55),
    _Zona('Llanta delantera', 0.22, 0.92),
    _Zona('Llanta posterior', 0.78, 0.92),
  ],
  'lateral_derecho': [
    _Zona('Techo', 0.5, 0.10),
    _Zona('Espejo', 0.76, 0.24),
    _Zona('Guardafango delantero', 0.87, 0.55),
    _Zona('Puerta delantera', 0.65, 0.55),
    _Zona('Puerta posterior', 0.37, 0.55),
    _Zona('Guardafango posterior', 0.13, 0.55),
    _Zona('Llanta delantera', 0.78, 0.92),
    _Zona('Llanta posterior', 0.22, 0.92),
  ],
  'superior': [
    _Zona('Capó', 0.5, 0.14),
    _Zona('Parabrisas', 0.5, 0.29),
    _Zona('Techo', 0.5, 0.5),
    _Zona('Luneta', 0.5, 0.71),
    _Zona('Baúl', 0.5, 0.86),
  ],
};

// ─── Esquema del vehículo (dibujado, sin depender de imágenes externas) ───────
class _CochePainter extends CustomPainter {
  final String vista;
  _CochePainter(this.vista);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final linea = Paint()
      ..color = _kBlue.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final relleno = Paint()..color = _kBlue.withOpacity(0.06);

    switch (vista) {
      case 'frontal':
      case 'posterior':
        final body = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.10, h * 0.35, w * 0.80, h * 0.55),
          const Radius.circular(18));
        canvas.drawRRect(body, relleno);
        canvas.drawRRect(body, linea);
        final parabrisas = Path()
          ..moveTo(w * 0.28, h * 0.35)
          ..lineTo(w * 0.38, h * 0.06)
          ..lineTo(w * 0.62, h * 0.06)
          ..lineTo(w * 0.72, h * 0.35)
          ..close();
        canvas.drawPath(parabrisas, relleno);
        canvas.drawPath(parabrisas, linea);
        for (final dx in [0.20, 0.80]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(w * dx, h * 0.55), width: w * 0.12, height: h * 0.10),
              const Radius.circular(6)),
            linea);
        }
        break;

      case 'lateral_izquierdo':
      case 'lateral_derecho':
        final body = Path()
          ..moveTo(w * 0.06, h * 0.62)
          ..quadraticBezierTo(w * 0.04, h * 0.40, w * 0.20, h * 0.38)
          ..lineTo(w * 0.30, h * 0.16)
          ..quadraticBezierTo(w * 0.35, h * 0.06, w * 0.50, h * 0.06)
          ..lineTo(w * 0.62, h * 0.06)
          ..quadraticBezierTo(w * 0.72, h * 0.08, w * 0.76, h * 0.20)
          ..lineTo(w * 0.80, h * 0.38)
          ..quadraticBezierTo(w * 0.96, h * 0.40, w * 0.94, h * 0.62)
          ..lineTo(w * 0.94, h * 0.70)
          ..lineTo(w * 0.06, h * 0.70)
          ..close();
        canvas.drawPath(body, relleno);
        canvas.drawPath(body, linea);
        for (final dx in [0.22, 0.78]) {
          canvas.drawCircle(Offset(w * dx, h * 0.80), w * 0.09,
            Paint()..color = _kBg);
          canvas.drawCircle(Offset(w * dx, h * 0.80), w * 0.09, linea);
        }
        break;

      case 'superior':
        final body = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.20, h * 0.06, w * 0.60, h * 0.88),
          const Radius.circular(28));
        canvas.drawRRect(body, relleno);
        canvas.drawRRect(body, linea);
        canvas.drawLine(Offset(w * 0.22, h * 0.24), Offset(w * 0.78, h * 0.24), linea);
        canvas.drawLine(Offset(w * 0.22, h * 0.76), Offset(w * 0.78, h * 0.76), linea);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CochePainter oldDelegate) => oldDelegate.vista != vista;
}

// ─── Pantalla principal ────────────────────────────────────────────────────────
class InspeccionDanosPage extends StatefulWidget {
  final int ordenId;
  final String placa;
  const InspeccionDanosPage({super.key, required this.ordenId, required this.placa});

  @override
  State<InspeccionDanosPage> createState() => _InspeccionDanosPageState();
}

class _InspeccionDanosPageState extends State<InspeccionDanosPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> danos = [];
  List<String> estadoOpciones = [];
  List<String> reparacionOpciones = [];

  String vistaActual = 'frontal';

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { loading = true; error = null; });
    try {
      final detalle = await ApiService.obtenerDetalleOrden(widget.ordenId);
      final estados = await ApiService.obtenerCatalogoItems('estado_dano');
      final reparaciones = await ApiService.obtenerCatalogoItems('tipo_reparacion');
      if (!mounted) return;
      setState(() {
        danos = (detalle['danos'] as List? ?? []).cast<Map<String, dynamic>>();
        estadoOpciones = estados;
        reparacionOpciones = reparaciones;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> _danosDeZona(String zona) => danos
      .where((d) => d['vista'] == vistaActual && d['zona'] == zona)
      .toList();

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Ubuntu')),
      backgroundColor: error ? Colors.red.shade900 : _kBlueDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final zonas = _zonasPorVista[vistaActual]!;

    return Theme(
      data: ThemeData(fontFamily: 'Ubuntu',
        textTheme: const TextTheme().apply(fontFamily: 'Ubuntu')),
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0A1628), Color(0xFF060B18)]),
          )),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent, _kBlue.withOpacity(0.35), Colors.transparent]))),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kBlue, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("INSPECCIÓN DE DAÑOS", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.5)),
            Text(widget.placa, style: TextStyle(fontFamily: 'Ubuntu',
              color: _kBlue.withOpacity(0.75), fontSize: 11, letterSpacing: 1)),
          ]),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _kBlue, size: 20),
              tooltip: "Refrescar",
              onPressed: _cargar,
            ),
          ],
        ),
        body: Stack(children: [
          Positioned.fill(child: const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF060B18), _kBg, Color(0xFF030509)]),
          ))),
          if (loading)
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 30, height: 30,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)),
              const SizedBox(height: 12),
              Text("Cargando inspección...", style: TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.28), fontSize: 12)),
            ]))
          else if (error != null)
            Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
                const SizedBox(height: 10),
                Text(error!, textAlign: TextAlign.center, style: TextStyle(
                  fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.5), fontSize: 12)),
                const SizedBox(height: 14),
                TextButton(onPressed: _cargar, child: const Text("Reintentar",
                  style: TextStyle(fontFamily: 'Ubuntu', color: _kBlue))),
              ]),
            ))
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
              children: [
                // ── Selector de vista ──────────────────────────────────────
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kVistaLabel.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final key = kVistaLabel.keys.elementAt(i);
                      final activo = key == vistaActual;
                      final count = danos.where((d) => d['vista'] == key).length;
                      return GestureDetector(
                        onTap: () => setState(() => vistaActual = key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: activo ? _kBlue.withOpacity(0.15) : _kBlue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: activo
                                ? _kBlue.withOpacity(0.5) : _kBlue.withOpacity(0.15)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(kVistaIcon[key], size: 14,
                              color: activo ? _kBlue : _kWhite.withOpacity(0.4)),
                            const SizedBox(width: 6),
                            Text(kVistaLabel[key]!, style: TextStyle(
                              fontFamily: 'Ubuntu',
                              color: activo ? _kWhite : _kWhite.withOpacity(0.45),
                              fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12)),
                            if (count > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _kDano.withOpacity(0.20),
                                  borderRadius: BorderRadius.circular(999)),
                                child: Text("$count", style: const TextStyle(
                                  fontFamily: 'Ubuntu', color: _kDano,
                                  fontWeight: FontWeight.w800, fontSize: 10)),
                              ),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 14),

                // ── Esquema con zonas tocables ──────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kBlue.withOpacity(0.14)),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.15,
                    child: LayoutBuilder(
                      builder: (ctx, cons) => Stack(children: [
                        Positioned.fill(child: CustomPaint(painter: _CochePainter(vistaActual))),
                        ...zonas.map((z) {
                          final n = _danosDeZona(z.nombre).length;
                          return Positioned(
                            left: cons.maxWidth * z.x - 16,
                            top: cons.maxHeight * z.y - 16,
                            child: GestureDetector(
                              onTap: () => _abrirZona(z.nombre),
                              child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (n > 0 ? _kDano : _kBlue).withOpacity(0.18),
                                  border: Border.all(
                                    color: n > 0 ? _kDano : _kBlue, width: 1.5),
                                ),
                                child: Center(child: n > 0
                                    ? Text("$n", style: const TextStyle(fontFamily: 'Ubuntu',
                                        color: _kDano, fontWeight: FontWeight.w800, fontSize: 13))
                                    : Icon(Icons.add_rounded, color: _kBlue.withOpacity(0.7), size: 16)),
                              ),
                            ),
                          );
                        }),
                      ]),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Text("Toca una zona para registrar o revisar un daño",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Ubuntu',
                    color: _kWhite.withOpacity(0.30), fontSize: 11)),

                const SizedBox(height: 18),

                // ── Lista de zonas de esta vista (acceso directo por nombre) ─
                Wrap(spacing: 8, runSpacing: 8, children: zonas.map((z) {
                  final n = _danosDeZona(z.nombre).length;
                  return GestureDetector(
                    onTap: () => _abrirZona(z.nombre),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: (n > 0 ? _kDano : _kBlue).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: (n > 0 ? _kDano : _kBlue).withOpacity(0.25)),
                      ),
                      child: Text(z.nombre, style: TextStyle(fontFamily: 'Ubuntu',
                        color: n > 0 ? _kDano : _kWhite.withOpacity(0.65),
                        fontWeight: n > 0 ? FontWeight.w700 : FontWeight.w500, fontSize: 11)),
                    ),
                  );
                }).toList()),

                const SizedBox(height: 24),

                // ── Resumen general (todas las vistas) ──────────────────────
                if (danos.isNotEmpty) ...[
                  Row(children: [
                    Container(width: 3, height: 16,
                      decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    Text("Resumen de daños (${danos.length})", style: const TextStyle(
                      fontFamily: 'Ubuntu', color: _kWhite,
                      fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                  const SizedBox(height: 10),
                  ...danos.map((d) => _resumenItem(d)),
                ],
              ],
            ),
        ]),
      ),
    );
  }

  Widget _resumenItem(Map<String, dynamic> d) {
    final vista = kVistaLabel[d['vista']] ?? d['vista'].toString();
    final zona = (d['zona'] ?? '').toString();
    final estado = (d['estado_dano'] ?? '').toString();
    final reparacion = (d['tipo_reparacion'] ?? '').toString();
    final fotos = (d['fotos'] as List? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kDano.withOpacity(0.04),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _kDano.withOpacity(0.20)),
      ),
      child: GestureDetector(
        onTap: () => setState(() {
          vistaActual = d['vista'].toString();
        }),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, color: _kDano.withOpacity(0.8), size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("$vista · $zona", style: const TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite, fontWeight: FontWeight.w700, fontSize: 12)),
            if (estado.isNotEmpty || reparacion.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text([estado, reparacion].where((s) => s.isNotEmpty).join(" · "),
                  style: TextStyle(fontFamily: 'Ubuntu',
                    color: _kWhite.withOpacity(0.45), fontSize: 11)),
              ),
          ])),
          if (fotos.isNotEmpty) ...[
            Icon(Icons.photo_rounded, color: _kBlue.withOpacity(0.5), size: 14),
            const SizedBox(width: 3),
            Text("${fotos.length}", style: TextStyle(fontFamily: 'Ubuntu',
              color: _kBlue.withOpacity(0.6), fontSize: 11)),
          ],
        ]),
      ),
    );
  }

  // ── Hoja de una zona: lista de daños + agregar nuevo ────────────────────────
  Future<void> _abrirZona(String zona) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) {
          final items = _danosDeZona(zona);
          return Container(
            padding: EdgeInsets.only(
              left: 18, right: 18, top: 18,
              bottom: MediaQuery.of(ctx2).viewInsets.bottom + 18),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx2).size.height * 0.85),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1420),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.location_on_rounded, color: _kBlue, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text("${kVistaLabel[vistaActual]} · $zona",
                    style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite,
                      fontWeight: FontWeight.w700, fontSize: 15))),
                ]),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text("Sin daños registrados en esta zona todavía.",
                      style: TextStyle(fontFamily: 'Ubuntu',
                        color: _kWhite.withOpacity(0.35), fontSize: 12)),
                  )
                else
                  ...items.map((d) => _itemZonaCard(d, () async {
                    Navigator.pop(ctx2);
                    await _cargar();
                    if (mounted) _abrirZona(zona);
                  })),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity, height: 46,
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx2);
                      await _formularioDano(zona);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2AA0FF), _kBlueDark]),
                      ),
                      child: const Center(child: Text("REGISTRAR DAÑO AQUÍ",
                        style: TextStyle(fontFamily: 'Ubuntu', color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1))),
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _itemZonaCard(Map<String, dynamic> d, VoidCallback onChanged) {
    final estado = (d['estado_dano'] ?? '').toString();
    final reparacion = (d['tipo_reparacion'] ?? '').toString();
    final obs = (d['observaciones'] ?? '').toString();
    final fotos = (d['fotos'] as List? ?? []).cast<Map<String, dynamic>>();
    final danoId = int.tryParse((d['id'] ?? '').toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kDano.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kDano.withOpacity(0.20)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(
            [estado, reparacion].where((s) => s.isNotEmpty).join(" · ").isEmpty
                ? "Sin detalles" : [estado, reparacion].where((s) => s.isNotEmpty).join(" · "),
            style: const TextStyle(fontFamily: 'Ubuntu', color: _kDano,
              fontWeight: FontWeight.w700, fontSize: 12))),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.7), size: 18),
            onPressed: danoId == null ? null : () async {
              try {
                await ApiService.eliminarDano(danoId);
                onChanged();
              } catch (e) { _snack(e.toString(), error: true); }
            },
          ),
        ]),
        if (obs.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(obs, style: TextStyle(fontFamily: 'Ubuntu',
              color: _kWhite.withOpacity(0.55), fontSize: 12))),
        if (fotos.isNotEmpty)
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: fotos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network((fotos[i]['url'] ?? '').toString(),
                  width: 56, height: 56, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 56, height: 56,
                    color: _kBlue.withOpacity(0.08),
                    child: Icon(Icons.broken_image_rounded, color: _kWhite.withOpacity(0.2), size: 18))),
              ),
            ),
          ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: danoId == null ? null : () async {
            await _agregarFotosDano(danoId);
            onChanged();
          },
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_a_photo_rounded, color: _kBlue.withOpacity(0.8), size: 14),
            const SizedBox(width: 4),
            Text("Agregar foto", style: TextStyle(fontFamily: 'Ubuntu',
              color: _kBlue.withOpacity(0.8), fontWeight: FontWeight.w700, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  // ── Formulario: nuevo daño en una zona ──────────────────────────────────────
  Future<void> _formularioDano(String zona) async {
    String? estado = estadoOpciones.isNotEmpty ? estadoOpciones.first : null;
    String? reparacion = reparacionOpciones.isNotEmpty ? reparacionOpciones.first : null;
    final obsCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1420),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kBlue.withOpacity(0.18))),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Nuevo daño · $zona", style: const TextStyle(fontFamily: 'Ubuntu',
                color: _kWhite, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 16),
              _dropdownDialog("Estado del daño", estado, estadoOpciones,
                (v) => setS(() => estado = v)),
              const SizedBox(height: 12),
              _dropdownDialog("Tipo de reparación", reparacion, reparacionOpciones,
                (v) => setS(() => reparacion = v)),
              const SizedBox(height: 12),
              TextField(
                controller: obsCtrl,
                maxLines: 3,
                style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 13),
                decoration: InputDecoration(
                  labelText: "Observaciones (opcional)",
                  labelStyle: TextStyle(fontFamily: 'Ubuntu',
                    color: _kBlue.withOpacity(0.8), fontSize: 12),
                  filled: true, fillColor: _kBlue.withOpacity(0.05),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _kBlue.withOpacity(0.22))),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBlue, width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(ctx2),
                  child: Container(height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBlue.withOpacity(0.25))),
                    child: Center(child: Text("Cancelar", style: TextStyle(
                      fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.5),
                      fontWeight: FontWeight.w600, fontSize: 13))),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () async {
                    try {
                      await ApiService.agregarDano(
                        ordenId: widget.ordenId, vista: vistaActual, zona: zona,
                        estadoDano: estado, tipoReparacion: reparacion,
                        observaciones: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
                      );
                      if (!mounted) return;
                      Navigator.pop(ctx2);
                      await _cargar();
                    } catch (e) {
                      _snack(e.toString(), error: true);
                    }
                  },
                  child: Container(height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(colors: [Color(0xFF2AA0FF), _kBlueDark])),
                    child: const Center(child: Text("Guardar", style: TextStyle(
                      fontFamily: 'Ubuntu', color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 13))),
                  ),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
    obsCtrl.dispose();
  }

  Widget _dropdownDialog(String label, String? value, List<String> items,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF0D1420),
      isExpanded: true,
      style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 13),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: _kBlue.withOpacity(0.7)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: 'Ubuntu', color: _kBlue.withOpacity(0.8), fontSize: 12),
        filled: true, fillColor: _kBlue.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _kBlue.withOpacity(0.22))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBlue, width: 1.5)),
      ),
      items: items.map((v) => DropdownMenuItem(value: v,
        child: Text(v, style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 13)))).toList(),
      onChanged: onChanged,
    );
  }

  // ── Subir fotos a un daño existente ─────────────────────────────────────────
  final _picker = ImagePicker();

  Future<void> _agregarFotosDano(int danoId) async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF0D1420),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.camera_alt_rounded, color: _kBlue),
          title: const Text("Tomar foto", style: TextStyle(fontFamily: 'Ubuntu', color: _kWhite)),
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_rounded, color: _kBlue),
          title: const Text("Elegir de la galería", style: TextStyle(fontFamily: 'Ubuntu', color: _kWhite)),
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ])),
    );
    if (origen == null) return;

    List<XFile> archivos = [];
    try {
      if (origen == ImageSource.camera) {
        final foto = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75, maxWidth: 1600);
        if (foto != null) archivos = [foto];
      } else {
        archivos = await _picker.pickMultiImage(imageQuality: 75, maxWidth: 1600);
      }
    } catch (e) {
      _snack("No se pudo abrir la cámara/galería: $e", error: true);
      return;
    }
    if (archivos.isEmpty) return;

    try {
      await ApiService.subirFotosDano(danoId: danoId, archivos: archivos);
      await _cargar();
      _snack("${archivos.length} foto(s) subida(s)");
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }
}
