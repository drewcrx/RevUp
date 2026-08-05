import 'package:flutter/material.dart';
import 'api_service.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kBlueGlow = Color(0xFF00BFFF);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);
const _kCard     = Color(0xFF080E1A);

class DetalleVehiculoDesdeQrPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const DetalleVehiculoDesdeQrPage({super.key, required this.data});
  @override
  State<DetalleVehiculoDesdeQrPage> createState() =>
      _DetalleVehiculoDesdeQrPageState();
}

class _DetalleVehiculoDesdeQrPageState
    extends State<DetalleVehiculoDesdeQrPage> {
  // ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
  late final Map<String, dynamic> vehiculo;
  late final String placa;
  late final String token;

  bool   loading = false;
  String error   = '';
  List<Map<String, dynamic>> ots = [];

  @override
  void initState() {
    super.initState();
    vehiculo = (widget.data["vehiculo"] as Map<String, dynamic>?) ?? {};
    placa    = (vehiculo["placa"]     ?? "").toString().trim().toUpperCase();
    token    = (vehiculo["qr_token"]  ?? "").toString().trim();
    _loadOts();
  }

  Future<void> _loadOts() async {
    if (!mounted) return;
    setState(() { loading = true; error = ''; ots = []; });
    try {
      final data = await ApiService.obtenerOtsPorQrOTokenOFallback(
          placa: placa, token: token);
      if (!mounted) return;
      setState(() => ots = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
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

  String _money(dynamic v) {
    if (v == null) return "0.00";
    return v.toString();
  }
  // ═════════════════════════════════════════════════════════════════════════ //

  @override
  Widget build(BuildContext context) {
    final marca  = (vehiculo["marca"]        ?? "").toString();
    final modelo = (vehiculo["modelo"]       ?? "").toString();
    final km     = (vehiculo["kilometraje"]  ?? 0).toString();
    final anio   = (vehiculo["anio"]         ?? "").toString();
    final color  = (vehiculo["color"]        ?? "").toString();
    final tipo   = (vehiculo["tipo_vehiculo"] ?? "").toString();
    final initial = marca.isNotEmpty ? marca[0].toUpperCase() : "V";

    return Theme(
      data: ThemeData(fontFamily: 'Ubuntu',
          textTheme: const TextTheme().apply(fontFamily: 'Ubuntu')),
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
                Colors.transparent, _kBlue.withOpacity(0.35),
                Colors.transparent]))),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _kBlue, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
                decoration: const BoxDecoration(
                    color: _kBlue, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(child: Text(
              "$marca $modelo".toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite,
                fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.5),
            )),
          ]),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _kBlue, size: 20),
              tooltip: "Refrescar",
              onPressed: _loadOts,
            ),
          ],
        ),

        // ── Body ────────────────────────────────────────────────────────────
        body: Stack(children: [
          Positioned.fill(child: const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF060B18), _kBg, Color(0xFF030509)]),
          ))),
          Positioned(top: -80, right: -60, child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _kBlue.withOpacity(0.07), Colors.transparent])),
          )),

          Column(children: [

            // ── Tarjeta del vehículo ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBlue.withOpacity(0.14)),
                ),
                child: Row(children: [
                  // Avatar
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF2AA0FF), _kBlueDark]),
                      boxShadow: [BoxShadow(
                          color: _kBlue.withOpacity(0.28), blurRadius: 12)],
                    ),
                    child: Center(child: Text(initial, style: const TextStyle(
                      fontFamily: 'Ubuntu', color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 20))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text("$marca $modelo", style: const TextStyle(
                      fontFamily: 'Ubuntu', color: _kWhite,
                      fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      _chip(placa, _kBlue, bold: true, letterSpacing: 1.2),
                      if (anio.isNotEmpty && anio != "0")
                        _chip(anio, _kWhite.withOpacity(0.5)),
                      if (color.isNotEmpty)
                        _chip(color, _kWhite.withOpacity(0.5)),
                      if (tipo.isNotEmpty)
                        _chip(tipo, _kWhite.withOpacity(0.5)),
                    ]),
                    if (km.isNotEmpty && km != "0") ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.speed_rounded,
                            color: _kWhite.withOpacity(0.30), size: 13),
                        const SizedBox(width: 4),
                        Text("$km km", style: TextStyle(
                          fontFamily: 'Ubuntu',
                          color: _kWhite.withOpacity(0.38), fontSize: 12)),
                      ]),
                    ],
                  ])),
                ]),
              ),
            ),

            const SizedBox(height: 12),

            // ── Cabecera historial ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Container(width: 3, height: 16,
                  decoration: BoxDecoration(
                    color: _kBlue, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                const Icon(Icons.receipt_long_rounded, color: _kBlue, size: 15),
                const SizedBox(width: 6),
                const Text("Historial de OTs", style: TextStyle(
                  fontFamily: 'Ubuntu', color: _kWhite,
                  fontWeight: FontWeight.w700, fontSize: 13)),
                if (ots.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _kBlue.withOpacity(0.28)),
                    ),
                    child: Text("${ots.length}", style: const TextStyle(
                      fontFamily: 'Ubuntu', color: _kBlue,
                      fontWeight: FontWeight.w700, fontSize: 10)),
                  ),
                ],
              ]),
            ),

            const SizedBox(height: 10),

            // ── Lista OTs ──────────────────────────────────────────────────
            Expanded(child: _buildBody()),
          ]),
        ]),
      ),
    );
  }

  // ── Estado del cuerpo ──────────────────────────────────────────────────────
  Widget _buildBody() {
    if (loading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 30, height: 30,
          child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)),
        const SizedBox(height: 12),
        Text("Cargando órdenes...", style: TextStyle(
          fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.28), fontSize: 12)),
      ]));
    }

    if (error.isNotEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.redAccent.withOpacity(0.22)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 28),
            const SizedBox(height: 10),
            Text(error, textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Ubuntu',
                color: _kWhite.withOpacity(0.50), fontSize: 12)),
            const SizedBox(height: 14),
            _primaryButton("Reintentar", Icons.refresh_rounded, _loadOts),
          ]),
        ),
      ));
    }

    if (ots.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_rounded, color: _kBlue.withOpacity(0.20), size: 40),
        const SizedBox(height: 10),
        Text("Sin OTs registradas", style: TextStyle(
          fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.30), fontSize: 13)),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _loadOts,
      color: _kBlue,
      backgroundColor: const Color(0xFF0D1420),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 40),
        itemCount: ots.length,
        itemBuilder: (_, i) {
          final o      = ots[i];
          final id     = int.tryParse((o['id'] ?? '').toString()) ?? 0;
          final estado = (o['estado']     ?? '').toString().toUpperCase();
          final pago   = (o['pago_estado'] ?? '').toString();
          final total  = o['total'];
          final km     = int.tryParse((o['kilometraje_ot'] ?? '').toString()) ?? 0;
          final c      = _colorEstado(estado);
          final isPend = pago.toUpperCase().contains("PEND");

          // Cabecera de grupo por estado
          final prevEstado = i > 0
              ? (ots[i - 1]['estado'] ?? '').toString().toUpperCase()
              : null;
          final showHeader = estado != prevEstado;

          return Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            if (showHeader) _grupoHeader(estado, c),
            GestureDetector(
              onTap: () async {
                // DetalleOrdenPage nunca hace pop con `true` — el refresco
                // tiene que ser incondicional, si no la lista se queda con
                // datos viejos tras cerrar/pagar la OT y volver.
                await Navigator.pushNamed(
                    context, '/detalle_orden', arguments: id);
                _loadOts();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _kBlue.withOpacity(0.10)),
                ),
                child: Row(children: [
                  // Ícono de estado
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.withOpacity(0.10),
                      border: Border.all(color: c.withOpacity(0.22))),
                    child: Icon(_iconEstado(estado), color: c, size: 17),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Text("OT #$id", style: const TextStyle(
                        fontFamily: 'Ubuntu', color: _kWhite,
                        fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(width: 8),
                      _chip(estado, c, small: true),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text("Total \$${_money(total)}",
                        style: TextStyle(fontFamily: 'Ubuntu',
                          color: _kWhite.withOpacity(0.65),
                          fontWeight: FontWeight.w600, fontSize: 12)),
                      Text("  ·  Pago ", style: TextStyle(
                        fontFamily: 'Ubuntu',
                        color: _kWhite.withOpacity(0.30), fontSize: 11)),
                      Expanded(child: Text(pago,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Ubuntu',
                          color: isPend ? Colors.orangeAccent : Colors.greenAccent,
                          fontWeight: FontWeight.w700, fontSize: 11))),
                    ]),
                    if (km > 0) ...[
                      const SizedBox(height: 3),
                      Text("$km km", style: TextStyle(
                        fontFamily: 'Ubuntu',
                        color: _kWhite.withOpacity(0.30), fontSize: 11)),
                    ],
                  ])),
                  Icon(Icons.chevron_right_rounded,
                      color: _kBlue.withOpacity(0.30), size: 18),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  // ── Cabecera de grupo de estado ────────────────────────────────────────────
  Widget _grupoHeader(String estado, Color c) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6, left: 2),
    child: Row(children: [
      Icon(_iconEstado(estado), color: c, size: 12),
      const SizedBox(width: 6),
      Text(estado, style: TextStyle(
        fontFamily: 'Ubuntu', color: c,
        fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 1)),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: c.withOpacity(0.15), thickness: 1)),
    ]),
  );

  // ── Chip ───────────────────────────────────────────────────────────────────
  Widget _chip(String label, Color c, {
    bool bold = false, bool small = false, double letterSpacing = 0.3}) =>
      Container(
        padding: EdgeInsets.symmetric(
            horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
        decoration: BoxDecoration(
          color: c.withOpacity(0.10),
          border: Border.all(color: c.withOpacity(0.28)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(
          fontFamily: 'Ubuntu', color: c,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          fontSize: small ? 10 : 11, letterSpacing: letterSpacing)),
      );

  // ── Botón primario ─────────────────────────────────────────────────────────
  Widget _primaryButton(String label, IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42, width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF2AA0FF), _kBlueDark]),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: _kBlue.withOpacity(0.28),
                blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(
              fontFamily: 'Ubuntu', color: Colors.white,
              fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      );
}