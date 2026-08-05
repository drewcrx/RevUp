import 'package:flutter/material.dart';
import 'api_service.dart';
import 'detalle_orden.dart';
import 'session.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kBlueGlow = Color(0xFF00BFFF);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);
const _kCard     = Color(0xFF080E1A);

class OtsMecanicoMesPage extends StatefulWidget {
  final int    mechanicId;
  final String mechanicNombre;
  final String month;

  const OtsMecanicoMesPage({
    super.key,
    required this.mechanicId,
    required this.mechanicNombre,
    required this.month,
  });

  @override
  State<OtsMecanicoMesPage> createState() => _OtsMecanicoMesPageState();
}

class _OtsMecanicoMesPageState extends State<OtsMecanicoMesPage> {
  // ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
  late Future<List<Map<String, dynamic>>> future;

  int _currentUserIdOrThrow() {
    final u  = Session.user;
    final id = u?['id'];
    if (id == null) throw Exception("No hay sesión activa (user.id es null)");
    return int.parse(id.toString());
  }

  String _money(dynamic v) { if (v == null) return "0.00"; return v.toString(); }

  // Si la sesión no está lista, que el error lo muestre el FutureBuilder
  // (tarjeta roja ya existente) en vez de tumbar la pantalla completa.
  void _cargar() {
    try {
      final myId = _currentUserIdOrThrow();
      if (widget.mechanicId == myId) {
        future = ApiService.obtenerMisOtsDelMes(month: widget.month);
      } else {
        future = ApiService.obtenerOtsMecanicoMes(
          mechanicId: widget.mechanicId, month: widget.month);
      }
    } catch (e) {
      future = Future.error(e);
    }
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }
  // ═════════════════════════════════════════════════════════════════════════ //

  // Estados reales del backend: RECIBIDO, PENDIENTE, ENTREGADO.
  Color _colorEstado(String e) {
    switch (e.toUpperCase()) {
      case 'RECIBIDO':  return _kBlueGlow;
      case 'PENDIENTE': return Colors.orangeAccent;
      case 'ENTREGADO': return Colors.greenAccent;
      default:          return _kWhite;
    }
  }

  IconData _iconEstado(String e) {
    switch (e.toUpperCase()) {
      case 'RECIBIDO':  return Icons.inbox_rounded;
      case 'PENDIENTE': return Icons.build_rounded;
      case 'ENTREGADO': return Icons.done_all_rounded;
      default:          return Icons.pending_actions_rounded;
    }
  }

  // Etiqueta amigable: "PENDIENTE" aquí es el trabajo en curso, no el pago.
  String _labelEstado(String e) =>
      e.toUpperCase() == 'PENDIENTE' ? 'EN PROCESO' : e;

  // Parsear "YYYY-MM" para mostrarlo legible
  String _mesLabel(String m) {
    final parts = m.split("-");
    if (parts.length != 2) return m;
    const meses = ["","Enero","Febrero","Marzo","Abril","Mayo","Junio",
        "Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"];
    final idx = int.tryParse(parts[1]) ?? 0;
    return "${meses[idx.clamp(0,12)]} ${parts[0]}";
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.mechanicNombre.isNotEmpty
        ? widget.mechanicNombre[0].toUpperCase() : "M";

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
              Flexible(child: Text(
                widget.mechanicNombre.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Ubuntu', color: _kWhite,
                  fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.5))),
            ]),
            Text(_mesLabel(widget.month), style: TextStyle(
              fontFamily: 'Ubuntu', color: _kBlue.withOpacity(0.70),
              fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
          ]),
          centerTitle: true,
        ),

        // ── Body ────────────────────────────────────────────────────────────
        body: Stack(children: [
          Positioned.fill(child: const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF060B18), _kBg, Color(0xFF030509)]),
          ))),
          Positioned(top: -80, right: -60, child: Container(
            width: 220, height: 220,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _kBlue.withOpacity(0.07), Colors.transparent])),
          )),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snapshot) {

              // ── Cargando ─────────────────────────────────────────────────
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min,
                    children: [
                  SizedBox(width: 30, height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kBlue)),
                  const SizedBox(height: 12),
                  Text("Cargando órdenes...", style: TextStyle(
                    fontFamily: 'Ubuntu',
                    color: _kWhite.withOpacity(0.28), fontSize: 12)),
                ]));
              }

              // ── Error ─────────────────────────────────────────────────────
              if (snapshot.hasError) {
                return Center(child: Padding(
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
                      Text(snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Ubuntu',
                          color: _kWhite.withOpacity(0.50), fontSize: 12)),
                    ]),
                  ),
                ));
              }

              final ots = snapshot.data ?? [];

              // ── Vacío ─────────────────────────────────────────────────────
              if (ots.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min,
                    children: [
                  Icon(Icons.inbox_rounded,
                    color: _kBlue.withOpacity(0.18), size: 44),
                  const SizedBox(height: 12),
                  Text("Sin órdenes este mes", style: TextStyle(
                    fontFamily: 'Ubuntu',
                    color: _kWhite.withOpacity(0.30), fontSize: 13)),
                ]));
              }

              // ── Lista ─────────────────────────────────────────────────────
              // Calcular totales para el resumen superior
              double sumTotal  = 0;
              double sumPagado = 0;
              for (final ot in ots) {
                sumTotal  += double.tryParse((ot["total"]  ?? 0).toString()) ?? 0;
                sumPagado += double.tryParse((ot["pagado"] ?? 0).toString()) ?? 0;
              }
              final pct = sumTotal > 0
                  ? (sumPagado / sumTotal).clamp(0.0, 1.0) : 0.0;

              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
                children: [

                  // ── Tarjeta resumen ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kBlue.withOpacity(0.14))),
                    child: Column(children: [
                      // Avatar + nombre
                      Row(children: [
                        Container(width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2AA0FF), _kBlueDark]),
                            boxShadow: [BoxShadow(
                              color: _kBlue.withOpacity(0.25), blurRadius: 8)]),
                          child: Center(child: Text(initial,
                            style: const TextStyle(fontFamily: 'Ubuntu',
                              color: Colors.white, fontWeight: FontWeight.w800,
                              fontSize: 17))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(widget.mechanicNombre, style: const TextStyle(
                            fontFamily: 'Ubuntu', color: _kWhite,
                            fontWeight: FontWeight.w700, fontSize: 14)),
                          Text("${ots.length} órdenes · ${_mesLabel(widget.month)}",
                            style: TextStyle(fontFamily: 'Ubuntu',
                              color: _kWhite.withOpacity(0.38), fontSize: 11)),
                        ])),
                      ]),

                      Divider(height: 18, color: _kBlue.withOpacity(0.08)),

                      // Stats en fila
                      Row(children: [
                        _stat("\$${_money(sumTotal)}",  "Total OT",  _kBlue),
                        _statDiv(),
                        _stat("\$${_money(sumPagado)}", "Cobrado",   Colors.greenAccent),
                        _statDiv(),
                        _stat("\$${_money(sumTotal - sumPagado)}",
                          "Pendiente", Colors.orangeAccent),
                      ]),

                      const SizedBox(height: 12),

                      // Barra de progreso
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                        Text("Progreso de cobro", style: TextStyle(
                          fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.32),
                          fontSize: 10)),
                        Text("${(pct * 100).toStringAsFixed(0)}%",
                          style: TextStyle(fontFamily: 'Ubuntu',
                            color: pct > 0.7 ? Colors.greenAccent
                                : pct > 0.4 ? _kBlue : Colors.orangeAccent,
                            fontWeight: FontWeight.w700, fontSize: 10)),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct, minHeight: 5,
                          backgroundColor: _kBlue.withOpacity(0.10),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            pct > 0.7 ? Colors.greenAccent
                                : pct > 0.4 ? _kBlue : Colors.orangeAccent),
                        ),
                      ),
                    ]),
                  ),

                  // ── Cabecera de lista ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 2),
                    child: Row(children: [
                      Container(width: 3, height: 14,
                        decoration: BoxDecoration(color: _kBlue,
                          borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      const Icon(Icons.receipt_long_rounded,
                        color: _kBlue, size: 14),
                      const SizedBox(width: 6),
                      Text("Órdenes · ${ots.length}", style: TextStyle(
                        fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.45),
                        fontSize: 11, fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
                    ]),
                  ),

                  // ── Cards de OTs ─────────────────────────────────────────
                  ...ots.map((ot) {
                    final id     = ot["id"]?.toString() ?? "—";
                    final idInt  = int.tryParse((ot["id"] ?? '').toString());
                    final placa  = (ot["placa"] ?? "").toString();
                    final estado = (ot["estado"] ?? "").toString().toUpperCase();
                    final total  = _money(ot["total"]);
                    final pagado = _money(ot["pagado"]);
                    final c      = _colorEstado(estado);
                    final tieneDiagnostico = (ot["diagnostico"] ?? "").toString().trim().isNotEmpty;
                    final actCount = int.tryParse((ot["actualizaciones_count"] ?? "0").toString().split('.').first) ?? 0;
                    final closedAt = DateTime.tryParse((ot["closed_at"] ?? "").toString())?.toLocal();

                    // Cabecera de grupo
                    final idx      = ots.indexOf(ot);
                    final prevEst  = idx > 0
                        ? (ots[idx-1]["estado"] ?? "").toString().toUpperCase()
                        : null;
                    final showHdr  = estado != prevEst;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHdr) _grupoHeader(estado, c),
                        GestureDetector(
                          onTap: idInt == null ? null : () async {
                            await Navigator.push(context,
                              MaterialPageRoute(builder: (_) => DetalleOrdenPage(
                                ordenId: idInt)));
                            if (mounted) setState(_cargar);
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
                              Container(width: 38, height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c.withOpacity(0.10),
                                  border: Border.all(
                                    color: c.withOpacity(0.22))),
                                child: Icon(_iconEstado(estado),
                                  color: c, size: 17)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Row(children: [
                                  Text("OT #$id", style: const TextStyle(
                                    fontFamily: 'Ubuntu', color: _kWhite,
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _kBlue.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _kBlue.withOpacity(0.28))),
                                    child: Text(placa, style: const TextStyle(
                                      fontFamily: 'Ubuntu', color: _kBlue,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10, letterSpacing: 1))),
                                ]),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Text("Total \$$total",
                                    style: TextStyle(fontFamily: 'Ubuntu',
                                      color: _kWhite.withOpacity(0.65),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                                  Expanded(child: Text("  ·  Cobrado \$$pagado",
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontFamily: 'Ubuntu',
                                      color: _kWhite.withOpacity(0.35),
                                      fontSize: 11))),
                                ]),
                                if (tieneDiagnostico || actCount > 0 || closedAt != null) ...[
                                  const SizedBox(height: 5),
                                  Row(children: [
                                    if (tieneDiagnostico) ...[
                                      Icon(Icons.fact_check_rounded,
                                        color: _kBlue.withOpacity(0.55), size: 12),
                                      const SizedBox(width: 8),
                                    ],
                                    if (actCount > 0) ...[
                                      Icon(Icons.update_rounded,
                                        color: Colors.orangeAccent.withOpacity(0.70), size: 12),
                                      const SizedBox(width: 3),
                                      Text("$actCount", style: TextStyle(fontFamily: 'Ubuntu',
                                        color: Colors.orangeAccent.withOpacity(0.80),
                                        fontWeight: FontWeight.w700, fontSize: 10)),
                                      const SizedBox(width: 8),
                                    ],
                                    if (closedAt != null) ...[
                                      Icon(Icons.event_available_rounded,
                                        color: Colors.greenAccent.withOpacity(0.55), size: 12),
                                      const SizedBox(width: 3),
                                      Text(
                                        "${closedAt.day.toString().padLeft(2, '0')}/${closedAt.month.toString().padLeft(2, '0')}",
                                        style: TextStyle(fontFamily: 'Ubuntu',
                                          color: Colors.greenAccent.withOpacity(0.65), fontSize: 10)),
                                    ],
                                  ]),
                                ],
                              ])),
                              Icon(Icons.chevron_right_rounded,
                                color: _kBlue.withOpacity(0.30), size: 18),
                            ]),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              );
            },
          ),
        ]),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _stat(String val, String lbl, Color c) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(val, style: TextStyle(fontFamily: 'Ubuntu', color: c,
        fontWeight: FontWeight.w800, fontSize: 14),
        overflow: TextOverflow.ellipsis),
      Text(lbl, style: TextStyle(fontFamily: 'Ubuntu',
        color: _kWhite.withOpacity(0.35), fontSize: 10)),
    ]),
  );

  Widget _statDiv() => Container(
    width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 10),
    color: _kBlue.withOpacity(0.10));

  Widget _grupoHeader(String estado, Color c) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6, left: 2),
    child: Row(children: [
      Icon(_iconEstado(estado), color: c, size: 12),
      const SizedBox(width: 6),
      Text(_labelEstado(estado), style: TextStyle(fontFamily: 'Ubuntu', color: c,
        fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 1)),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: c.withOpacity(0.15), thickness: 1)),
    ]),
  );
}