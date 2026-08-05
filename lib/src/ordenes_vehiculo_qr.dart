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

class OrdenesVehiculoQrPage extends StatefulWidget {
  final String  qrToken;
  final String? placa;
  const OrdenesVehiculoQrPage({super.key, required this.qrToken, this.placa});
  @override
  State<OrdenesVehiculoQrPage> createState() => _OrdenesVehiculoQrPageState();
}

class _OrdenesVehiculoQrPageState extends State<OrdenesVehiculoQrPage> {
  // ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
  bool   loading = true;
  String error   = '';
  List<OrdenTrabajo> ordenes = [];

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() { loading = true; error = ''; });
    try {
      final data = await ApiService.obtenerOtsPorQrToken(widget.qrToken);
      ordenes = data.map((e) => OrdenTrabajo.fromMap(e)).toList();
    } catch (e) { error = e.toString(); }
    if (!mounted) return;
    setState(() => loading = false);
  }

  // Estados reales del backend: RECIBIDO, PENDIENTE, ENTREGADO.
  Color _colorEstado(String estado) {
    switch (estado) {
      case 'RECIBIDO':    return _kBlueGlow;
      case 'PENDIENTE':   return Colors.orangeAccent;
      case 'ENTREGADO':   return Colors.greenAccent;
      default:            return _kWhite;
    }
  }

  IconData _iconEstado(String estado) {
    switch (estado) {
      case 'RECIBIDO':    return Icons.inbox_rounded;
      case 'PENDIENTE':   return Icons.build_rounded;
      case 'ENTREGADO':   return Icons.done_all_rounded;
      default:            return Icons.pending_actions_rounded;
    }
  }

  // Etiqueta amigable: "PENDIENTE" aquí es el trabajo en curso, no el pago
  // (el pago se muestra aparte, con su propia etiqueta "Pago").
  String _labelEstado(String estado) {
    switch (estado) {
      case 'PENDIENTE': return 'EN PROCESO';
      default:          return estado;
    }
  }

  String _estadoUI(OrdenTrabajo o) => o.estado.isEmpty ? '' : o.estado;
  // ═════════════════════════════════════════════════════════════════════════ //

  @override
  Widget build(BuildContext context) {
    final placaTitulo = (widget.placa != null && widget.placa!.trim().isNotEmpty)
        ? widget.placa!.toUpperCase()
        : "Vehículo";

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
          title: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                decoration: const BoxDecoration(
                  color: _kBlue, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              const Text("ÓRDENES", style: TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite,
                fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 2.5)),
            ]),
            Text(placaTitulo, style: TextStyle(
              fontFamily: 'Ubuntu', color: _kBlue.withOpacity(0.75),
              fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
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

          // ── Contenido ─────────────────────────────────────────────────────
          if (loading)
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 30, height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: _kBlue)),
              const SizedBox(height: 12),
              Text("Cargando órdenes...", style: TextStyle(
                fontFamily: 'Ubuntu',
                color: _kWhite.withOpacity(0.28), fontSize: 12)),
            ]))

          else if (error.isNotEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _kCard, borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.redAccent.withOpacity(0.22))),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 28),
                  const SizedBox(height: 10),
                  Text(error, textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Ubuntu',
                      color: _kWhite.withOpacity(0.50), fontSize: 12)),
                  const SizedBox(height: 14),
                  _primaryButton("Reintentar",
                    Icons.refresh_rounded, _cargar),
                ]),
              ),
            ))

          else if (ordenes.isEmpty)
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.receipt_long_rounded,
                color: _kBlue.withOpacity(0.20), size: 44),
              const SizedBox(height: 12),
              Text("Este vehículo no tiene OTs aún",
                style: TextStyle(fontFamily: 'Ubuntu',
                  color: _kWhite.withOpacity(0.30), fontSize: 13)),
              const SizedBox(height: 4),
              Text("Crea una nueva orden desde Vehículos",
                style: TextStyle(fontFamily: 'Ubuntu',
                  color: _kWhite.withOpacity(0.18), fontSize: 11)),
            ]))

          else
            RefreshIndicator(
              onRefresh: _cargar,
              color: _kBlue,
              backgroundColor: const Color(0xFF0D1420),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
                itemCount: ordenes.length,
                itemBuilder: (_, i) {
                  final o      = ordenes[i];
                  final estado = _estadoUI(o).toUpperCase();
                  final c      = _colorEstado(estado);
                  final isPend = o.pagoEstado.toUpperCase().contains("PEND");

                  // Cabecera de grupo por estado
                  final prevEstado = i > 0
                      ? _estadoUI(ordenes[i - 1]).toUpperCase() : null;
                  final showHeader = estado != prevEstado;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader) _grupoHeader(estado, c),
                      GestureDetector(
                        onTap: () async {
                          // DetalleOrdenPage nunca hace pop con `true` — el
                          // refresco tiene que ser incondicional.
                          await Navigator.pushNamed(
                            context, '/detalle_orden', arguments: o.id);
                          _cargar();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _kCard,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: _kBlue.withOpacity(0.10))),
                          child: Row(children: [
                            // Ícono estado
                            Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.withOpacity(0.10),
                                border: Border.all(
                                  color: c.withOpacity(0.22))),
                              child: Icon(_iconEstado(estado),
                                color: c, size: 17),
                            ),
                            const SizedBox(width: 12),

                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // OT ID + placa
                                Row(children: [
                                  Text("OT #${o.id}",
                                    style: const TextStyle(
                                      fontFamily: 'Ubuntu', color: _kWhite,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _kBlue.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _kBlue.withOpacity(0.28))),
                                    child: Text(o.placa, style: const TextStyle(
                                      fontFamily: 'Ubuntu', color: _kBlue,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10, letterSpacing: 1))),
                                ]),
                                const SizedBox(height: 4),
                                // Total + pago
                                Row(children: [
                                  Text(
                                    "Total \$${o.total.toStringAsFixed(2)}",
                                    style: TextStyle(fontFamily: 'Ubuntu',
                                      color: _kWhite.withOpacity(0.65),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                                  Text("  ·  Pago ",
                                    style: TextStyle(fontFamily: 'Ubuntu',
                                      color: _kWhite.withOpacity(0.30),
                                      fontSize: 11)),
                                  Text(o.pagoEstado, style: TextStyle(
                                    fontFamily: 'Ubuntu',
                                    color: isPend
                                      ? Colors.orangeAccent
                                      : Colors.greenAccent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11)),
                                ]),
                              ],
                            )),

                            Icon(Icons.chevron_right_rounded,
                              color: _kBlue.withOpacity(0.30), size: 18),
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }

  // ── Cabecera de grupo de estado ──────────────────────────────────────────
  Widget _grupoHeader(String estado, Color c) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6, left: 2),
    child: Row(children: [
      Icon(_iconEstado(estado), color: c, size: 12),
      const SizedBox(width: 6),
      Text(_labelEstado(estado), style: TextStyle(
        fontFamily: 'Ubuntu', color: c,
        fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 1)),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: c.withOpacity(0.15), thickness: 1)),
    ]),
  );

  // ── Botón primario ────────────────────────────────────────────────────────
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
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(
                fontFamily: 'Ubuntu', color: Colors.white,
                fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
        ),
      );
}