// lib/src/inicio.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'api_service.dart';
import 'session.dart';
import 'ots_mecanico_mes.dart';
import 'detalle_orden.dart';
import 'navbar.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const kBlue     = Color(0xFF1E90FF);
const kBlueDark = Color(0xFF0A5FCC);
const kBlueGlow = Color(0xFF00BFFF);
const kWhite    = Color(0xFFF0F4FF);
const kBg       = Color(0xFF04060D);
const kOrange   = Colors.orangeAccent;

// ─── Painter fondo (igual al sistema de diseño) ───────────────────────────────
class _RacingPainter extends CustomPainter {
  final double progress;
  _RacingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final sp = Paint()..strokeCap = StrokeCap.round;
    for (int i = 0; i < 18; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final len = 40.0 + rng.nextDouble() * 100;
      final pulse = math.sin(progress * math.pi * 2 + i * 0.6) * 0.5 + 0.5;
      final opacity = (0.02 + rng.nextDouble() * 0.05) * pulse;
      sp
        ..color = Color.lerp(kBlue, kBlueGlow, rng.nextDouble())!
            .withOpacity(opacity)
        ..strokeWidth = 0.5 + rng.nextDouble() * 1.4;
      canvas.drawLine(Offset(x, y), Offset(x - len, y + len * 0.08), sp);
    }
    // arco velocímetro — esquina superior derecha
    final ac = Offset(size.width + 30, -30);
    final ap = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final sweep = (progress + i * 0.15) % 1.0;
      ap.color = kBlue.withOpacity(0.06 + i * 0.025);
      canvas.drawArc(
        Rect.fromCircle(center: ac, radius: 90.0 + i * 32),
        math.pi * 0.6, math.pi * 0.9 * sweep, false, ap);
    }
  }

  @override
  bool shouldRepaint(_RacingPainter o) => o.progress != progress;
}

class _AnimBg extends StatefulWidget {
  const _AnimBg();
  @override
  State<_AnimBg> createState() => _AnimBgState();
}

class _AnimBgState extends State<_AnimBg> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => CustomPaint(painter: _RacingPainter(_c.value), size: Size.infinite),
  );
}

// ─── InicioPage ───────────────────────────────────────────────────────────────
class InicioPage extends StatefulWidget {
  const InicioPage({super.key});
  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  // ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
  bool loading = true;
  String error = "";

  Map<String, dynamic>? user;
  bool get isSuper => (user?["role"]?.toString() ?? "") == "superuser";

  String month = "";
  bool soloPendientes = false;

  Map<String, dynamic>? resumenTaller;
  List<Map<String, dynamic>> reporteMecanicos = [];
  Map<String, dynamic>? resumenMecanico;
  List<Map<String, dynamic>> otsMecanicoMes = [];

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, "0");
    month = "${now.year}-$m";
    _bootstrap();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load(silent: true));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _bootstrap() async {
    try {
      final u = await Session.loadUser();
      if (!mounted) return;
      setState(() { user = u; });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = e.toString(); });
    }
  }

  String _money(dynamic v) {
    if (v == null) return "0.00";
    final s = v.toString();
    return s.isEmpty ? "0.00" : s;
  }

  String _estadoUI(Map<String, dynamic> ot) {
    final e = (ot["estado_ui"] ?? ot["estado"] ?? "").toString().toUpperCase();
    return e.isEmpty ? "RECIBIDO" : e;
  }

  bool _isPendiente(Map<String, dynamic> ot) => _estadoUI(ot) == "PENDIENTE";

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { loading = true; error = ""; });
    try {
      final u = user ?? await Session.loadUser();
      if (!mounted) return;
      user = u;
      if (u == null) { setState(() { loading = false; error = "No hay sesión cargada."; }); return; }
      final role = (u["role"] ?? "").toString();
      if (role == "superuser") {
        final r   = await ApiService.obtenerResumenMensual(month: month);
        final mec = await ApiService.obtenerReporteMecanicos(month: month);
        if (!mounted) return;
        setState(() { resumenTaller = r; reporteMecanicos = mec; loading = false; error = ""; });
      } else {
        final id = int.tryParse((u["id"] ?? "").toString());
        if (id == null) { setState(() { loading = false; error = "Tu usuario no tiene ID válido en sesión."; }); return; }
        final ots = await ApiService.obtenerOtsMecanicoMes(mechanicId: id, month: month);
        double totalOt = 0, totalPagado = 0; int count = 0;
        for (final ot in ots) {
          totalOt    += double.tryParse((ot["total"]  ?? 0).toString()) ?? 0;
          totalPagado += double.tryParse((ot["pagado"] ?? 0).toString()) ?? 0;
          count++;
        }
        final resumen = <String, dynamic>{ "ots": count, "total_ot": totalOt, "total_pagado": totalPagado, "pendiente": (totalOt - totalPagado) };
        if (!mounted) return;
        setState(() { otsMecanicoMes = ots; resumenMecanico = resumen; loading = false; error = ""; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = e.toString(); });
    }
  }

  Future<void> _changeMonthPicker() async {
    final now = DateTime.now();
    DateTime initial = now;
    final parts = month.split("-");
    if (parts.length == 2) {
      final y = int.tryParse(parts[0]); final m = int.tryParse(parts[1]);
      if (y != null && m != null && m >= 1 && m <= 12) initial = DateTime(y, m, 1);
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      helpText: "Selecciona una fecha (usaremos el mes)",
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: kBlue, onPrimary: Colors.white,
            surface: Color(0xFF0D1420), onSurface: kWhite,
          ),
          dialogBackgroundColor: const Color(0xFF0D1420),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final m = picked.month.toString().padLeft(2, "0");
    final newMonth = "${picked.year}-$m";
    if (!mounted) return;
    if (newMonth == month) return;
    setState(() => month = newMonth);
    await _load();
  }
  // ═════════════════════════════════════════════════════════════════════════ //

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  /// Tarjeta con vidrio azulado y borde sutil
  Widget _glass({required Widget child, EdgeInsets? padding, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBlue.withOpacity(0.05),
        border: Border.all(color: (borderColor ?? kBlue).withOpacity(0.18), width: 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: kBlue.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  /// Título de sección con acento izquierdo
  Widget _sectionTitle(String t, {IconData? icon}) {
    return Row(
      children: [
        Container(width: 3, height: 18, decoration: BoxDecoration(
          color: kBlue, borderRadius: BorderRadius.circular(2),
        )),
        const SizedBox(width: 10),
        if (icon != null) ...[Icon(icon, color: kBlue, size: 17), const SizedBox(width: 6)],
        Text(t, style: const TextStyle(
          fontFamily: 'Ubuntu', color: kWhite,
          fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3,
        )),
      ],
    );
  }

  /// Fila clave-valor estilizada
  Widget _kv(String k, String v, {Color valueColor = kBlue, VoidCallback? onTap}) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(k, style: TextStyle(
            fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.5), fontSize: 13,
          ))),
          Text(v, style: TextStyle(
            fontFamily: 'Ubuntu', color: valueColor,
            fontWeight: FontWeight.w700, fontSize: 13,
          )),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: kBlue.withOpacity(0.6)),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: content);
  }

  /// Badge de rol
  Widget _roleBadge(String role) {
    final label = role == "superuser" ? "SUPERUSER" : "MECÁNICO";
    final icon  = role == "superuser" ? Icons.admin_panel_settings_rounded : Icons.build_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2AA0FF), kBlueDark]),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: kBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 13),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(
          fontFamily: 'Ubuntu', color: Colors.white,
          fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1,
        )),
      ]),
    );
  }

  /// Chip de estado para OT
  Widget _estadoChip(String estado) {
    Color c;
    if (estado == "ENTREGADO") c = kBlue;
    else if (estado == "PENDIENTE") c = kOrange;
    else c = kBlueGlow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        border: Border.all(color: c.withOpacity(0.35), width: 1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(estado, style: TextStyle(
        fontFamily: 'Ubuntu', color: c,
        fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5,
      )),
    );
  }

  /// Botón de acceso rápido
  Widget _quickBtn(String text, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: kBlue.withOpacity(0.07),
            border: Border.all(color: kBlue.withOpacity(0.22), width: 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: kBlue, size: 18),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(
              fontFamily: 'Ubuntu', color: kWhite,
              fontWeight: FontWeight.w600, fontSize: 13,
            )),
          ]),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final nombre = (user?["nombre"] ?? "Usuario").toString();
    final role   = (user?["role"] ?? "mechanic").toString();

    final List<Map<String, dynamic>> listaOtsUI = (!isSuper && soloPendientes)
        ? otsMecanicoMes.where(_isPendiente).toList()
        : otsMecanicoMes;

    return Theme(
      data: ThemeData(fontFamily: 'Ubuntu', textTheme: const TextTheme().apply(fontFamily: 'Ubuntu')),
      child: Scaffold(
        backgroundColor: kBg,
        drawer: const Navbar(),

        // ── AppBar ──────────────────────────────────────────────────────────
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0D1E3A), Color(0xFF060B18)],
              ),
            ),
          ),
          // línea inferior
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent, kBlue.withOpacity(0.4), Colors.transparent,
              ]),
            )),
          ),
          leading: Builder(builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: kBlue),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          )),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(
                color: kBlue, shape: BoxShape.circle,
              )),
              const SizedBox(width: 8),
              const Text("DASHBOARD", style: TextStyle(
                fontFamily: 'Ubuntu', color: kWhite,
                fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 2,
              )),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _changeMonthPicker,
              icon: const Icon(Icons.calendar_month_rounded, color: kBlue, size: 22),
              tooltip: "Cambiar mes",
            ),
            IconButton(
              onPressed: () => _load(),
              icon: const Icon(Icons.refresh_rounded, color: kBlue, size: 22),
              tooltip: "Refrescar",
            ),
          ],
        ),

        // ── Body ────────────────────────────────────────────────────────────
        body: Stack(
          children: [
            // Fondo
            Positioned.fill(child: DecoratedBox(decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF060B18), kBg, Color(0xFF030509)],
              ),
            ))),
            Positioned(top: -140, right: -100, child: Container(
              width: 380, height: 380,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [kBlue.withOpacity(0.09), Colors.transparent])),
            )),
            Positioned(bottom: -60, left: -50, child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [kBlueDark.withOpacity(0.10), Colors.transparent])),
            )),
            const Positioned.fill(child: _AnimBg()),

            // Contenido
            RefreshIndicator(
              onRefresh: () => _load(),
              color: kBlue,
              backgroundColor: const Color(0xFF0D1420),
              child: loading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 140),
                        Center(child: Column(children: [
                          SizedBox(width: 36, height: 36, child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: kBlue,
                          )),
                          const SizedBox(height: 14),
                          Text("Cargando...", style: TextStyle(
                            fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.35), fontSize: 13,
                          )),
                        ])),
                      ],
                    )
                  : error.isNotEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            const SizedBox(height: 40),
                            _glass(
                              borderColor: Colors.redAccent,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                                  const SizedBox(width: 8),
                                  const Text("Error", style: TextStyle(
                                    fontFamily: 'Ubuntu', color: Colors.redAccent,
                                    fontWeight: FontWeight.w700, fontSize: 15,
                                  )),
                                ]),
                                const SizedBox(height: 10),
                                Text(error, style: TextStyle(
                                  fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.6), fontSize: 13,
                                )),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity, height: 46,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFF2AA0FF), kBlueDark]),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [BoxShadow(color: kBlue.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))],
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => _load(),
                                      child: const Text("Reintentar", style: TextStyle(
                                        fontFamily: 'Ubuntu', color: Colors.white,
                                        fontWeight: FontWeight.w800, letterSpacing: 1,
                                      )),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ],
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                          children: [

                            // ── Bienvenida ──────────────────────────────────
                            _glass(child: Row(children: [
                              // Avatar circular con inicial
                              Container(
                                width: 46, height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                                    colors: [Color(0xFF2AA0FF), kBlueDark],
                                  ),
                                  boxShadow: [BoxShadow(color: kBlue.withOpacity(0.35), blurRadius: 10)],
                                ),
                                child: Center(child: Text(
                                  nombre.isNotEmpty ? nombre[0].toUpperCase() : "U",
                                  style: const TextStyle(
                                    fontFamily: 'Ubuntu', color: Colors.white,
                                    fontWeight: FontWeight.w800, fontSize: 20,
                                  ),
                                )),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(
                                  nombre.toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'Ubuntu', color: kWhite,
                                    fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(children: [
                                  _roleBadge(role),
                                  const SizedBox(width: 8),
                                  Text(month, style: TextStyle(
                                    fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.4), fontSize: 12,
                                  )),
                                ]),
                              ])),
                            ])),

                            const SizedBox(height: 14),

                            // ════════════════════════════════════════════════
                            // MECÁNICO
                            // ════════════════════════════════════════════════
                            if (!isSuper) ...[

                              // Resumen del mes — 4 métricas en grid 2×2
                              _glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _sectionTitle("Mi resumen del mes", icon: Icons.bar_chart_rounded),
                                const SizedBox(height: 16),
                                Row(children: [
                                  Expanded(child: _metricTile(
                                    "${resumenMecanico?["ots"] ?? 0}",
                                    "OTs del mes",
                                    Icons.assignment_rounded,
                                    kBlueGlow,
                                  )),
                                  const SizedBox(width: 10),
                                  Expanded(child: _metricTile(
                                    "\$${_money(resumenMecanico?["total_ot"])}",
                                    "Total OT",
                                    Icons.monetization_on_rounded,
                                    kBlue,
                                  )),
                                ]),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Expanded(child: _metricTile(
                                    "\$${_money(resumenMecanico?["total_pagado"])}",
                                    "Pagado",
                                    Icons.check_circle_rounded,
                                    Colors.greenAccent,
                                  )),
                                  const SizedBox(width: 10),
                                  Expanded(child: GestureDetector(
                                    onTap: () => Navigator.pushNamed(context, "/ordenes"),
                                    child: _metricTile(
                                      "\$${_money(resumenMecanico?["pendiente"])}",
                                      "Pendiente",
                                      Icons.pending_actions_rounded,
                                      kOrange,
                                      tappable: true,
                                    ),
                                  )),
                                ]),
                              ])),

                              const SizedBox(height: 14),

                              // Lista OTs
                              _glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: _sectionTitle("Mis OTs del mes", icon: Icons.list_alt_rounded)),
                                  // Toggle "Solo pendientes"
                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                    Text("Pendientes", style: TextStyle(
                                      fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.45), fontSize: 11,
                                    )),
                                    Transform.scale(
                                      scale: 0.78,
                                      child: Switch(
                                        value: soloPendientes,
                                        activeColor: kBlue,
                                        activeTrackColor: kBlue.withOpacity(0.25),
                                        inactiveThumbColor: kWhite.withOpacity(0.3),
                                        inactiveTrackColor: kWhite.withOpacity(0.08),
                                        onChanged: (v) => setState(() => soloPendientes = v),
                                      ),
                                    ),
                                  ]),
                                ]),
                                const SizedBox(height: 12),

                                if (listaOtsUI.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    child: Center(child: Column(children: [
                                      Icon(Icons.inbox_rounded, color: kBlue.withOpacity(0.3), size: 36),
                                      const SizedBox(height: 8),
                                      Text(
                                        soloPendientes
                                            ? "No tienes órdenes pendientes en este mes."
                                            : "No hay órdenes en este mes.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.35), fontSize: 13),
                                      ),
                                    ])),
                                  )
                                else
                                  ...listaOtsUI.take(8).map((ot) {
                                    final id     = int.tryParse((ot["id"] ?? "").toString()) ?? 0;
                                    final placa  = (ot["placa"] ?? "").toString();
                                    final estado = _estadoUI(ot);
                                    final total  = _money(ot["total"]);
                                    final pagado = _money(ot["pagado"]);
                                    final isPend = _isPendiente(ot);

                                    return GestureDetector(
                                      onTap: () => Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => DetalleOrdenPage(ordenId: id))),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isPend
                                              ? kOrange.withOpacity(0.04)
                                              : kBlue.withOpacity(0.04),
                                          border: Border.all(
                                            color: isPend ? kOrange.withOpacity(0.30) : kBlue.withOpacity(0.15),
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(children: [
                                          // Número OT
                                          Container(
                                            width: 36, height: 36,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: (isPend ? kOrange : kBlue).withOpacity(0.12),
                                            ),
                                            child: Center(child: Text(
                                              "#$id",
                                              style: TextStyle(
                                                fontFamily: 'Ubuntu',
                                                color: isPend ? kOrange : kBlue,
                                                fontWeight: FontWeight.w800, fontSize: 10,
                                              ),
                                            )),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(placa, style: const TextStyle(
                                              fontFamily: 'Ubuntu', color: kWhite,
                                              fontWeight: FontWeight.w700, fontSize: 14,
                                            )),
                                            const SizedBox(height: 2),
                                            Text(
                                              "Total \$$total  ·  Pagado \$$pagado",
                                              style: TextStyle(fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.4), fontSize: 12),
                                            ),
                                          ])),
                                          const SizedBox(width: 8),
                                          _estadoChip(estado),
                                          const SizedBox(width: 6),
                                          Icon(Icons.chevron_right_rounded, color: kBlue.withOpacity(0.5), size: 18),
                                        ]),
                                      ),
                                    );
                                  }).toList(),

                                if (listaOtsUI.length > 8)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      "Mostrando las primeras 8. Ver más en Reportes u Órdenes.",
                                      style: TextStyle(fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.25), fontSize: 11),
                                    ),
                                  ),
                              ])),
                            ],

                            // ════════════════════════════════════════════════
                            // SUPERUSER
                            // ════════════════════════════════════════════════
                            if (isSuper) ...[

                              // Resumen taller — 3 métricas
                              _glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _sectionTitle("Resumen del taller", icon: Icons.garage_rounded),
                                const SizedBox(height: 16),
                                Row(children: [
                                  Expanded(child: _metricTile(
                                    "\$${_money(resumenTaller?["ingresos"])}",
                                    "Ingresos",
                                    Icons.trending_up_rounded,
                                    Colors.greenAccent,
                                  )),
                                  const SizedBox(width: 10),
                                  Expanded(child: _metricTile(
                                    "\$${_money(resumenTaller?["gastos"])}",
                                    "Gastos",
                                    Icons.trending_down_rounded,
                                    kOrange,
                                  )),
                                ]),
                                const SizedBox(height: 10),
                                _metricTile(
                                  "\$${_money(resumenTaller?["utilidad"])}",
                                  "Utilidad neta",
                                  Icons.account_balance_wallet_rounded,
                                  kBlue,
                                  wide: true,
                                ),
                              ])),

                              const SizedBox(height: 14),

                              // Mecánicos
                              _glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _sectionTitle("Mecánicos del mes", icon: Icons.engineering_rounded),
                                const SizedBox(height: 12),

                                if (reporteMecanicos.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    child: Center(child: Text("No hay datos para este mes.",
                                      style: TextStyle(fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.35), fontSize: 13))),
                                  )
                                else
                                  ...reporteMecanicos.map((r) {
                                    final mid = int.tryParse((r["mechanic_id"] ?? "").toString()) ?? 0;
                                    final nom = (r["mechanic_nombre"] ?? "Mecánico").toString();

                                    return GestureDetector(
                                      onTap: () => Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => OtsMecanicoMesPage(
                                          mechanicId: mid, mechanicNombre: nom, month: month,
                                        ))),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: kBlue.withOpacity(0.04),
                                          border: Border.all(color: kBlue.withOpacity(0.15), width: 1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Row(children: [
                                            Container(
                                              width: 38, height: 38,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: const LinearGradient(colors: [Color(0xFF2AA0FF), kBlueDark]),
                                              ),
                                              child: Center(child: Text(
                                                nom.isNotEmpty ? nom[0].toUpperCase() : "M",
                                                style: const TextStyle(fontFamily: 'Ubuntu', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                                              )),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Text(nom, style: const TextStyle(
                                                fontFamily: 'Ubuntu', color: kWhite, fontWeight: FontWeight.w700, fontSize: 14,
                                              )),
                                              Text("ID: $mid  ·  OTs: ${r["ots"] ?? 0}",
                                                style: TextStyle(fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.4), fontSize: 12)),
                                            ])),
                                            Icon(Icons.chevron_right_rounded, color: kBlue.withOpacity(0.5), size: 20),
                                          ]),
                                          const SizedBox(height: 12),
                                          // mini métricas inline
                                          Row(children: [
                                            _miniKv("Total OT", "\$${_money(r["total_ot"])}", kBlue),
                                            const SizedBox(width: 14),
                                            _miniKv("Pagado", "\$${_money(r["total_pagado_mes"])}", Colors.greenAccent),
                                            const SizedBox(width: 14),
                                            _miniKv("Gastos", "\$${_money(r["total_gastos"])}", kOrange),
                                          ]),
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: kBlue.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(children: [
                                              const Icon(Icons.insights_rounded, color: kBlue, size: 15),
                                              const SizedBox(width: 6),
                                              Text("Utilidad estimada  ", style: TextStyle(
                                                fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.5), fontSize: 12,
                                              )),
                                              Text("\$${_money(r["utilidad_estimada"])}", style: const TextStyle(
                                                fontFamily: 'Ubuntu', color: kWhite, fontWeight: FontWeight.w800, fontSize: 13,
                                              )),
                                            ]),
                                          ),
                                        ]),
                                      ),
                                    );
                                  }).toList(),
                              ])),
                            ],

                            const SizedBox(height: 14),

                            // ── Accesos rápidos ──────────────────────────────
                            _glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _sectionTitle("Accesos rápidos", icon: Icons.rocket_launch_rounded),
                              const SizedBox(height: 14),
                              Wrap(spacing: 10, runSpacing: 10, children: [
                                _quickBtn("Órdenes",    Icons.assignment_rounded,      () => Navigator.pushNamed(context, "/ordenes")),
                                _quickBtn("Vehículos",  Icons.directions_car_rounded,  () => Navigator.pushNamed(context, "/vehiculos")),
                                _quickBtn("Escanear QR",Icons.qr_code_scanner_rounded, () => Navigator.pushNamed(context, "/scanqr")),
                                _quickBtn("Perfil",     Icons.person_rounded,          () => Navigator.pushNamed(context, "/perfil")),
                                if (isSuper) _quickBtn("Reportes", Icons.bar_chart_rounded, () => Navigator.pushNamed(context, "/reportes")),
                              ]),
                            ])),

                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tile de métrica ──────────────────────────────────────────────────────
  Widget _metricTile(String value, String label, IconData icon, Color color, {bool wide = false, bool tappable = false}) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border.all(color: color.withOpacity(0.20), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.12)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(
              fontFamily: 'Ubuntu', color: color, fontWeight: FontWeight.w800, fontSize: 15,
            )),
            Text(label, style: TextStyle(
              fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.4), fontSize: 11,
            )),
          ])),
          if (tappable) Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.5), size: 12),
        ],
      ),
    );
  }

  Widget _miniKv(String k, String v, Color c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(k, style: TextStyle(fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.35), fontSize: 10)),
      Text(v, style: TextStyle(fontFamily: 'Ubuntu', color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    ]);
  }
}