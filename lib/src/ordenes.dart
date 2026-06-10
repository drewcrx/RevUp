import 'package:flutter/material.dart';
import 'api_service.dart';
import 'orden_model.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kBlueGlow = Color(0xFF00BFFF);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);
const _kCard     = Color(0xFF080E1A);

class OrdenesPage extends StatefulWidget {
  const OrdenesPage({super.key});
  @override
  State<OrdenesPage> createState() => _OrdenesPageState();
}

class _OrdenesPageState extends State<OrdenesPage> {
  // ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
  bool loading = true;
  String error = '';
  List<OrdenTrabajo> ordenes = [];

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { loading = true; error = ''; });
    try {
      final data = await ApiService.obtenerOrdenes(soloMias: true);
      ordenes = data.map((e) => OrdenTrabajo.fromMap(e)).toList();
    } catch (e) { error = e.toString(); }
    if (!mounted) return;
    setState(() => loading = false);
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'RECIBIDO':    return _kBlueGlow;
      case 'DIAGNOSTICO': return Colors.amberAccent;
      case 'REPARACION':  return Colors.orangeAccent;
      case 'LISTO':       return Colors.lightGreenAccent;
      case 'ENTREGADO':   return Colors.greenAccent;
      default:            return _kWhite;
    }
  }

  IconData _iconEstado(String estado) {
    switch (estado) {
      case 'RECIBIDO':    return Icons.inbox_rounded;
      case 'DIAGNOSTICO': return Icons.search_rounded;
      case 'REPARACION':  return Icons.build_rounded;
      case 'LISTO':       return Icons.check_circle_rounded;
      case 'ENTREGADO':   return Icons.done_all_rounded;
      default:            return Icons.help_outline_rounded;
    }
  }
  // ═════════════════════════════════════════════════════════════════════════ //

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(fontFamily: 'Ubuntu', textTheme: const TextTheme().apply(fontFamily: 'Ubuntu')),
      child: Scaffold(
        backgroundColor: _kBg,

        // ── AppBar ──────────────────────────────────────────────────────────
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
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(
              color: _kBlue, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text("ÓRDENES", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 2.5)),
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

        // ── FAB ─────────────────────────────────────────────────────────────
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _kBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          icon: const Icon(Icons.add_rounded),
          label: const Text("Nueva OT", style: TextStyle(
            fontFamily: 'Ubuntu', fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          onPressed: () async {
            final ok = await Navigator.pushNamed(context, '/nueva_orden');
            if (ok == true) _cargar();
          },
        ),

        // ── Body ────────────────────────────────────────────────────────────
        body: Stack(children: [
          // Fondo
          Positioned.fill(child: const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF060B18), _kBg, Color(0xFF030509)]),
          ))),
          Positioned(top: -100, right: -80, child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_kBlue.withOpacity(0.07), Colors.transparent])),
          )),

          // Contenido
          loading
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 32, height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)),
                  const SizedBox(height: 12),
                  Text("Cargando órdenes...", style: TextStyle(
                    fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.30), fontSize: 12)),
                ]))
              : error.isNotEmpty
                  ? _errorView()
                  : ordenes.isEmpty
                      ? _emptyView()
                      : _listaView(),
        ]),
      ),
    );
  }

  // ── Vista de error ─────────────────────────────────────────────────────────
  Widget _errorView() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
        const SizedBox(height: 10),
        Text(error, textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.55), fontSize: 13)),
        const SizedBox(height: 16),
        _btn("Reintentar", Icons.refresh_rounded, _cargar),
      ]),
    ),
  ));

  // ── Vista vacía ────────────────────────────────────────────────────────────
  Widget _emptyView() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.receipt_long_rounded, color: _kBlue.withOpacity(0.20), size: 52),
    const SizedBox(height: 12),
    Text("No hay órdenes aún", style: TextStyle(
      fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.35), fontSize: 14)),
    const SizedBox(height: 6),
    Text("Crea una nueva con el botón +", style: TextStyle(
      fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.20), fontSize: 12)),
  ]));

  // ── Lista ──────────────────────────────────────────────────────────────────
  Widget _listaView() {
    // Agrupar por estado para un look más organizado (opcional — misma lógica)
    return RefreshIndicator(
      onRefresh: _cargar,
      color: _kBlue,
      backgroundColor: const Color(0xFF0D1420),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        itemCount: ordenes.length,
        itemBuilder: (_, i) {
          // Insertar cabecera de grupo cuando cambia el estado
          final o = ordenes[i];
          final prevEstado = i > 0 ? ordenes[i - 1].estado : null;
          final showHeader = o.estado != prevEstado;

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (showHeader) _grupoHeader(o.estado),
            _ordenCard(o),
          ]);
        },
      ),
    );
  }

  // Cabecera de grupo de estado
  Widget _grupoHeader(String estado) {
    final c = _colorEstado(estado);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6, left: 4),
      child: Row(children: [
        Icon(_iconEstado(estado), color: c, size: 13),
        const SizedBox(width: 6),
        Text(estado, style: TextStyle(
          fontFamily: 'Ubuntu', color: c,
          fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: c.withOpacity(0.18), thickness: 1)),
      ]),
    );
  }

  // Card de orden
  Widget _ordenCard(OrdenTrabajo o) {
    final c     = _colorEstado(o.estado);
    final isPend = o.pagoEstado.toUpperCase().contains("PEND");

    return GestureDetector(
      onTap: () async {
        final ok = await Navigator.pushNamed(context, '/detalle_orden', arguments: o.id);
        if (ok == true) _cargar();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _kBlue.withOpacity(0.10), width: 1),
        ),
        child: Row(children: [

          // Ícono de estado circular
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.withOpacity(0.10),
              border: Border.all(color: c.withOpacity(0.25), width: 1),
            ),
            child: Icon(_iconEstado(o.estado), color: c, size: 18),
          ),

          const SizedBox(width: 12),

          // Info principal
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Placa + OT ID
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _kBlue.withOpacity(0.28)),
                ),
                child: Text(o.placa, style: const TextStyle(
                  fontFamily: 'Ubuntu', color: _kBlue,
                  fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
              ),
              const SizedBox(width: 8),
              Text("OT #${o.id}", style: TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.30), fontSize: 11)),
            ]),

            const SizedBox(height: 6),

            // Fila de datos: total + pago
            Row(children: [
              // Total
              _inlineKv("Total", "\$${o.total.toStringAsFixed(2)}", _kWhite),
              const SizedBox(width: 14),
              // Pago
              _inlineKv("Pago", o.pagoEstado,
                isPend ? Colors.orangeAccent : Colors.greenAccent),
            ]),
          ])),

          const SizedBox(width: 8),

          // Chevron
          Icon(Icons.chevron_right_rounded, color: _kBlue.withOpacity(0.35), size: 18),
        ]),
      ),
    );
  }

  // Clave-valor inline pequeño
  Widget _inlineKv(String k, String v, Color vc) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text("$k ", style: TextStyle(
        fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.30), fontSize: 11)),
      Text(v, style: TextStyle(
        fontFamily: 'Ubuntu', color: vc, fontWeight: FontWeight.w700, fontSize: 11)),
    ],
  );

  // Botón primario
  Widget _btn(String label, IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2AA0FF), _kBlueDark]),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: _kBlue.withOpacity(0.28), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(
              fontFamily: 'Ubuntu', color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      );
}