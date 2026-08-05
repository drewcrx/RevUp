import 'package:flutter/material.dart';
import 'api_service.dart';
import 'ots_mecanico_mes.dart';
import 'session.dart';
import 'detalle_orden.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kBlueGlow = Color(0xFF00BFFF);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);
const _kCard     = Color(0xFF080E1A);

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});
  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  // ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
  final _monthCtrl = TextEditingController();

  bool   loading = false;
  String error   = '';
  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic>? resumen;
  bool isSuper = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthCtrl.text = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    isSuper = _isSuperuser();
    _load();
  }

  @override
  void dispose() { _monthCtrl.dispose(); super.dispose(); }

  bool _isSuperuser() {
    final u = Session.user;
    if (u == null) return false;
    final role = (u['role'] ?? u['rol'] ?? u['tipo'] ?? '').toString().toLowerCase().trim();
    return role == 'superuser';
  }

  String _money(dynamic v) { if (v == null) return "0.00"; return v.toString(); }

  Future<void> _load() async {
    setState(() { loading = true; error = ''; });
    try {
      final month = _monthCtrl.text.trim();
      if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(month)) {
        throw Exception("Mes inválido. Usa formato YYYY-MM (ej: 2026-02)");
      }
      isSuper = _isSuperuser();
      if (isSuper) {
        final r    = await ApiService.obtenerResumenMensual(month: month);
        final data = await ApiService.obtenerReporteMecanicos(month: month);
        setState(() { resumen = r; rows = data; });
      } else {
        final r   = await ApiService.obtenerMiResumenMensual(month: month);
        final ots = await ApiService.obtenerMisOtsDelMes(month: month);
        setState(() { resumen = r; rows = ots; });
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  void _onTapRow(Map<String, dynamic> r) {
    if (isSuper) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OtsMecanicoMesPage(
          mechanicId: r["mechanic_id"],
          mechanicNombre: r["mechanic_nombre"] ?? "Mecánico",
          month: _monthCtrl.text.trim(),
        ),
      ));
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => DetalleOrdenPage(ordenId: int.parse(r["id"].toString())),
      ));
    }
  }
  // ═════════════════════════════════════════════════════════════════════════ //

  // ── Helpers UI ─────────────────────────────────────────────────────────────

  Widget _card({required Widget child, Color? border, EdgeInsets? padding}) =>
      Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: (border ?? _kBlue).withOpacity(0.14), width: 1),
        ),
        child: child,
      );

  Widget _divider() => Divider(height: 18, thickness: 1, color: _kBlue.withOpacity(0.08));

  Widget _secHeader(String title, {IconData? icon}) => Row(children: [
    if (icon != null) ...[Icon(icon, color: _kBlue, size: 16), const SizedBox(width: 8)],
    Text(title, style: const TextStyle(
      fontFamily: 'Ubuntu', color: _kWhite,
      fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.3)),
  ]);

  Widget _stat(String val, String lbl, Color c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(val, style: TextStyle(
        fontFamily: 'Ubuntu', color: c, fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 1),
      Text(lbl, style: TextStyle(
        fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.38), fontSize: 10)),
    ],
  );

  Widget _statDivider() => Container(
    width: 1, height: 30, margin: const EdgeInsets.symmetric(horizontal: 14),
    color: _kBlue.withOpacity(0.10),
  );

  Widget _chip(String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: c.withOpacity(0.10),
      border: Border.all(color: c.withOpacity(0.30)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: TextStyle(
      fontFamily: 'Ubuntu', color: c,
      fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.4)),
  );

  // ── Repuestos más usados / daños del mes ───────────────────────────────────
  Widget _buildOperativoCard() {
    final repuestos = (resumen?['repuestos_top'] as List? ?? []).cast<Map<String, dynamic>>();
    final danos = (resumen?['danos_por_estado'] as List? ?? []).cast<Map<String, dynamic>>();
    final actualizacionesMes = int.tryParse((resumen?['actualizaciones_mes'] ?? '0').toString()) ?? 0;
    final otsConDiagnostico = int.tryParse((resumen?['ots_con_diagnostico'] ?? '0').toString()) ?? 0;
    final otsTotalMes = int.tryParse((resumen?['ots_total_mes'] ?? '0').toString()) ?? 0;
    final hayTransparencia = actualizacionesMes > 0 || otsTotalMes > 0;
    if (repuestos.isEmpty && danos.isEmpty && !hayTransparencia) return const SizedBox.shrink();

    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secHeader("Repuestos más usados", icon: Icons.build_circle_rounded),
      _divider(),
      if (repuestos.isEmpty)
        Text("Sin repuestos registrados este mes", style: TextStyle(
          fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.30), fontSize: 12))
      else
        ...repuestos.map((r) {
          final nombre = (r['nombre'] ?? '').toString();
          final cant = _money(r['cantidad_total']);
          final monto = _money(r['monto_total']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: Text(nombre, style: const TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite, fontSize: 12, fontWeight: FontWeight.w600))),
              Text("×$cant", style: TextStyle(fontFamily: 'Ubuntu',
                color: _kWhite.withOpacity(0.40), fontSize: 11)),
              const SizedBox(width: 8),
              Text("\$$monto", style: const TextStyle(fontFamily: 'Ubuntu',
                color: _kBlue, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
          );
        }),
      if (danos.isNotEmpty) ...[
        const SizedBox(height: 6),
        _divider(),
        _secHeader("Daños registrados", icon: Icons.warning_amber_rounded),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: danos.map((d) {
          final estado = (d['estado_dano'] ?? '').toString();
          final cant = (d['cantidad'] ?? '0').toString();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.25)),
            ),
            child: Text("$estado · $cant", style: const TextStyle(
              fontFamily: 'Ubuntu', color: Colors.orangeAccent,
              fontWeight: FontWeight.w700, fontSize: 11)),
          );
        }).toList()),
      ],
      if (hayTransparencia) ...[
        const SizedBox(height: 6),
        _divider(),
        _secHeader("Transparencia con el cliente", icon: Icons.visibility_rounded),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _stat("$actualizacionesMes", "Actualizaciones enviadas", _kBlue)),
          if (otsTotalMes > 0)
            Expanded(child: _stat(
              "${((otsConDiagnostico / otsTotalMes) * 100).round()}%",
              "OTs con diagnóstico", Colors.greenAccent)),
        ]),
      ],
    ]));
  }

  // ── Tarjeta resumen ────────────────────────────────────────────────────────
  Widget _buildResumenCard() {
    if (resumen == null) return const SizedBox.shrink();

    final ing  = _money(resumen!['ingresos']);
    final gas  = _money(resumen!['gastos']);
    final util = _money(resumen!['utilidad']);

    // Barra de margen
    final ingV = double.tryParse(ing) ?? 0;
    final gasV = double.tryParse(gas) ?? 0;
    final pct  = ingV > 0 ? ((ingV - gasV) / ingV).clamp(0.0, 1.0) : 0.0;
    final barColor = pct > 0.5 ? Colors.greenAccent : pct > 0.25 ? _kBlue : Colors.orangeAccent;

    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _secHeader(
        isSuper ? "Resumen del taller" : "Mi resumen del mes",
        icon: isSuper ? Icons.analytics_rounded : Icons.bar_chart_rounded,
      ),
      _divider(),

      // 3 stats en fila
      Row(children: [
        _stat("\$$ing",  "Ingresos", Colors.greenAccent),
        _statDivider(),
        _stat("\$$gas",  "Gastos",   Colors.orangeAccent),
        _statDivider(),
        _stat("\$$util", "Utilidad", _kBlue),
      ]),

      const SizedBox(height: 14),

      // Barra de margen
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("Margen operativo", style: TextStyle(
          fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.35), fontSize: 10)),
        Text("${(pct * 100).toStringAsFixed(1)}%", style: TextStyle(
          fontFamily: 'Ubuntu', color: barColor, fontWeight: FontWeight.w700, fontSize: 10)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct, minHeight: 5,
          backgroundColor: _kBlue.withOpacity(0.10),
          valueColor: AlwaysStoppedAnimation<Color>(barColor),
        ),
      ),
    ]));
  }

  // ── Card de fila (mecánico o OT) ───────────────────────────────────────────
  Widget _buildRowCard(Map<String, dynamic> r) {
    return isSuper ? _mecanicoCard(r) : _otCard(r);
  }

  Widget _mecanicoCard(Map<String, dynamic> r) {
    final nom = (r["mechanic_nombre"] ?? "Mecánico").toString();
    final mid = r["mechanic_id"]?.toString() ?? "—";
    final initial = nom.isNotEmpty ? nom[0].toUpperCase() : "M";

    return GestureDetector(
      onTap: () => _onTapRow(r),
      child: _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cabecera: avatar + nombre
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF2AA0FF), _kBlueDark]),
            ),
            child: Center(child: Text(initial, style: const TextStyle(
              fontFamily: 'Ubuntu', color: Colors.white,
              fontWeight: FontWeight.w800, fontSize: 16))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nom, style: const TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w700, fontSize: 14)),
            Text("ID $mid  ·  ${r["ots"] ?? 0} órdenes",
              style: TextStyle(fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.38), fontSize: 11)),
          ])),
          Icon(Icons.chevron_right_rounded, color: _kBlue.withOpacity(0.35), size: 18),
        ]),

        _divider(),

        // Stats en fila
        Row(children: [
          _stat("\$${_money(r["total_ot"])}",          "Total OT",  _kBlue),
          _statDivider(),
          _stat("\$${_money(r["total_pagado_mes"])}",  "Cobrado",   Colors.greenAccent),
          _statDivider(),
          _stat("\$${_money(r["total_gastos"])}",      "Gastos",    Colors.orangeAccent),
        ]),

        const SizedBox(height: 12),

        // Utilidad
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _kBlue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(children: [
            const Icon(Icons.insights_rounded, color: _kBlue, size: 14),
            const SizedBox(width: 8),
            Text("Utilidad estimada  ", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.40), fontSize: 11)),
            Text("\$${_money(r["utilidad_estimada"])}", style: const TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite, fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
        ),
      ])),
    );
  }

  Widget _otCard(Map<String, dynamic> r) {
    final id       = r["id"]?.toString() ?? "—";
    final placa    = (r["placa"] ?? "").toString();
    final estado   = (r["estado"] ?? "").toString().toUpperCase();
    final total    = _money(r["total"]);
    final pagado   = _money(r["pagado"]);
    final fecha    = (r["created_at"] ?? "").toString();
    final isPend   = estado == "PENDIENTE";
    final stColor  = isPend ? Colors.orangeAccent
        : estado == "ENTREGADO" ? Colors.greenAccent
        : _kBlueGlow;

    return GestureDetector(
      onTap: () => _onTapRow(r),
      child: _card(child: Row(children: [
        // ID circle
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kBlue.withOpacity(0.10),
            border: Border.all(color: _kBlue.withOpacity(0.22)),
          ),
          child: Center(child: Text("#$id", style: const TextStyle(
            fontFamily: 'Ubuntu', color: _kBlue,
            fontWeight: FontWeight.w800, fontSize: 10))),
        ),
        const SizedBox(width: 12),

        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Placa + estado
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kBlue.withOpacity(0.28)),
              ),
              child: Text(placa, style: const TextStyle(
                fontFamily: 'Ubuntu', color: _kBlue,
                fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
            ),
            const SizedBox(width: 8),
            _chip(estado, stColor),
          ]),
          const SizedBox(height: 6),
          // Montos
          Row(children: [
            Text("Total \$$total", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.70),
              fontWeight: FontWeight.w700, fontSize: 12)),
            Expanded(child: Text("  ·  Cobrado \$$pagado",
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.38), fontSize: 11))),
          ]),
          if (fecha.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(fecha, style: TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.22), fontSize: 10)),
            ),
        ])),

        Icon(Icons.chevron_right_rounded, color: _kBlue.withOpacity(0.30), size: 18),
      ])),
    );
  }

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
            const Text("REPORTES", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 2.5)),
          ]),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _kBlue, size: 20),
              tooltip: "Refrescar",
              onPressed: loading ? null : _load,
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
          Positioned(top: -100, right: -80, child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_kBlue.withOpacity(0.07), Colors.transparent])),
          )),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(children: [

              // ── Selector de mes ──────────────────────────────────────────
              _card(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Icon(Icons.calendar_month_rounded, color: _kBlue.withOpacity(0.7), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _monthCtrl,
                      style: const TextStyle(
                        fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "YYYY-MM  (ej: 2026-02)",
                        hintStyle: TextStyle(
                          fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.25), fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      onSubmitted: (_) => loading ? null : _load(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: loading ? null : _load,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2AA0FF), _kBlueDark]),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [BoxShadow(
                          color: _kBlue.withOpacity(0.30),
                          blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: loading
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text("VER", style: TextStyle(
                              fontFamily: 'Ubuntu', color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.5)),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 12),

              // ── Contenido ────────────────────────────────────────────────
              if (loading)
                Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 30, height: 30,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)),
                  const SizedBox(height: 12),
                  Text("Cargando reporte...", style: TextStyle(
                    fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.28), fontSize: 12)),
                ])))

              else if (error.isNotEmpty)
                _card(
                  border: Colors.redAccent,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(error, style: TextStyle(
                      fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.55), fontSize: 12))),
                  ]),
                )

              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      _buildResumenCard(),
                      const SizedBox(height: 14),
                      _buildOperativoCard(),
                      if (rows.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        // Cabecera de sección de filas
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, left: 2),
                          child: Row(children: [
                            Icon(
                              isSuper ? Icons.engineering_rounded : Icons.receipt_long_rounded,
                              color: _kBlue, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              isSuper
                                  ? "Mecánicos · ${rows.length}"
                                  : "Órdenes · ${rows.length}",
                              style: TextStyle(
                                fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.45),
                                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                          ]),
                        ),
                        ...rows.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildRowCard(r),
                        )),
                      ] else if (resumen != null) ...[
                        const SizedBox(height: 40),
                        Center(child: Column(children: [
                          Icon(Icons.inbox_rounded, color: _kBlue.withOpacity(0.20), size: 36),
                          const SizedBox(height: 8),
                          Text("Sin registros para este mes", style: TextStyle(
                            fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.28), fontSize: 12)),
                        ])),
                      ],
                    ],
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}