// perfil.dart
import 'dart:convert';
import 'package:flutter/material.dart';

import 'session.dart';
import 'api_service.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kBlueGlow = Color(0xFF00BFFF);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});
  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  // ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
  bool loading = true;

  String nombre  = '';
  String correo  = '';
  String usuario = '';
  String role    = 'mechanic';
  String? avatarB64;

  bool   loadingResumen = true;
  int    ots        = 0;
  int    pendientes = 0;
  double total      = 0;

  @override
  void initState() { super.initState(); _cargarTodo(); }

  Future<void> _cargarTodo() async {
    await _cargarPerfilLocal();
    await _cargarResumenMes();
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _cargarPerfilLocal() async {
    final u = await Session.loadUser();
    if (!mounted) return;
    setState(() {
      nombre    = (u?['nombre']     ?? 'Sin nombre').toString();
      correo    = (u?['correo']     ?? 'Sin correo').toString();
      usuario   = (u?['usuario']    ?? 'Sin usuario').toString();
      role      = (u?['role']       ?? 'mechanic').toString();
      avatarB64 = u?['avatar_b64']?.toString();
    });
  }

  Future<void> _cargarResumenMes() async {
    if (!mounted) return;
    setState(() => loadingResumen = true);
    try {
      final ordenes   = await ApiService.obtenerOrdenes(soloMias: true);
      final now       = DateTime.now();
      final monthStart     = DateTime(now.year, now.month, 1);
      final nextMonthStart = DateTime(now.year, now.month + 1, 1);

      bool isInThisMonth(DateTime d) =>
          !d.isBefore(monthStart) && d.isBefore(nextMonthStart);

      String estadoUiFrom(Map<String, dynamic> o) {
        final s = (o['estado_ui'] ?? o['estado'] ?? '').toString().trim();
        if (s.isNotEmpty) return s;
        final estado = (o['estado'] ?? '').toString().trim();
        final ts = double.tryParse((o['total_servicios'] ?? 0).toString()) ?? 0;
        final tr = double.tryParse((o['total_repuestos']  ?? 0).toString()) ?? 0;
        final t  = double.tryParse((o['total']            ?? 0).toString()) ?? 0;
        if (estado == 'RECIBIDO' && (ts > 0 || tr > 0 || t > 0)) return 'PENDIENTE';
        return estado;
      }

      double money(dynamic v) => double.tryParse((v ?? 0).toString()) ?? 0;

      int otsLocal = 0, pendientesLocal = 0; double totalLocal = 0;
      for (final o in ordenes) {
        final dt = DateTime.tryParse((o['created_at'] ?? '').toString());
        if (dt == null) continue;
        if (!isInThisMonth(dt.toLocal())) continue;
        otsLocal++;
        if (estadoUiFrom(o).toUpperCase() == 'PENDIENTE') pendientesLocal++;
        totalLocal += money(o['total']);
      }

      if (!mounted) return;
      setState(() { ots = otsLocal; pendientes = pendientesLocal; total = totalLocal; loadingResumen = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { ots = 0; pendientes = 0; total = 0; loadingResumen = false; });
    }
  }

  ImageProvider? _avatarProvider() {
    final b64 = (avatarB64 ?? '').trim();
    if (b64.isEmpty) return null;
    try {
      final cleaned = b64.contains(',') ? b64.split(',').last : b64;
      return MemoryImage(base64Decode(cleaned));
    } catch (_) { return null; }
  }

  String _roleLabel(String r) {
    final s = r.trim().toLowerCase();
    if (s == 'superuser' || s == 'admin') return 'Administrador';
    if (s == 'mechanic'  || s == 'mecanico' || s == 'mecánico') return 'Mecánico';
    return r.isEmpty ? 'Usuario' : r;
  }

  String _money(double v) {
    final sign = v < 0 ? "-" : "";
    final n    = v.abs();
    final parts   = n.toStringAsFixed(2).split('.');
    final intPart = parts[0]; final decPart = parts[1];
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final idxFromEnd = intPart.length - i;
      buf.write(intPart[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(',');
    }
    return "$sign\$${buf.toString()}.$decPart";
  }
  // ═════════════════════════════════════════════════════════════════════════ //

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  /// Tarjeta glass
  Widget _glass({required Widget child, EdgeInsets? padding, Color? border}) =>
      Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _kBlue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (border ?? _kBlue).withOpacity(0.16), width: 1),
          boxShadow: [BoxShadow(color: _kBlue.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: child,
      );

  /// Título de sección con acento izquierdo
  Widget _sectionTitle(String t, {IconData? icon}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(width: 3, height: 16, decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      if (icon != null) ...[Icon(icon, color: _kBlue, size: 16), const SizedBox(width: 6)],
      Text(t, style: const TextStyle(
        fontFamily: 'Ubuntu', color: _kWhite,
        fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.3,
      )),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 34, height: 34,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _kBlue)),
          const SizedBox(height: 14),
          Text("Cargando perfil...", style: TextStyle(
            fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.35), fontSize: 13)),
        ])),
      );
    }

    final avatar = _avatarProvider();
    final initial = nombre.isNotEmpty ? nombre[0].toUpperCase() : "U";

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
              colors: [Color(0xFF0D1E3A), Color(0xFF060B18)],
            ),
          )),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent, _kBlue.withOpacity(0.35), Colors.transparent,
              ]),
            )),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kBlue, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: _kBlue, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text("PERFIL", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 2,
            )),
          ]),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: "Refrescar",
              onPressed: () async => _cargarTodo(),
              icon: const Icon(Icons.refresh_rounded, color: _kBlue, size: 22),
            ),
          ],
        ),

        // ── Body ────────────────────────────────────────────────────────────
        body: Stack(children: [
          // Fondo
          Positioned.fill(child: const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF060B18), _kBg, Color(0xFF030509)],
            ),
          ))),
          Positioned(top: -120, right: -80, child: Container(
            width: 320, height: 320,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_kBlue.withOpacity(0.09), Colors.transparent])),
          )),
          Positioned(bottom: -60, left: -40, child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_kBlueDark.withOpacity(0.09), Colors.transparent])),
          )),

          ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: [

              // ── Tarjeta de identidad ───────────────────────────────────────
              _glass(child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Avatar
                Stack(children: [
                  Container(
                    width: 68, height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: avatar == null
                          ? const LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [Color(0xFF2AA0FF), _kBlueDark])
                          : null,
                      boxShadow: [BoxShadow(color: _kBlue.withOpacity(0.30), blurRadius: 14)],
                    ),
                    child: avatar != null
                        ? ClipOval(child: Image(image: avatar, fit: BoxFit.cover))
                        : Center(child: Text(initial, style: const TextStyle(
                            fontFamily: 'Ubuntu', color: Colors.white,
                            fontWeight: FontWeight.w800, fontSize: 26))),
                  ),
                  Positioned(right: 2, bottom: 2, child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: Colors.greenAccent,
                      border: Border.all(color: _kBg, width: 2),
                    ),
                  )),
                ]),

                const SizedBox(width: 16),

                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nombre, style: const TextStyle(
                    fontFamily: 'Ubuntu', color: _kWhite,
                    fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: 0.2,
                  )),
                  const SizedBox(height: 4),
                  // Badge de rol
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF2AA0FF), _kBlueDark]),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [BoxShadow(color: _kBlue.withOpacity(0.28), blurRadius: 8)],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        role == 'superuser' ? Icons.admin_panel_settings_rounded : Icons.build_rounded,
                        color: Colors.white, size: 12,
                      ),
                      const SizedBox(width: 5),
                      Text(_roleLabel(role), style: const TextStyle(
                        fontFamily: 'Ubuntu', color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8,
                      )),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.greenAccent,
                    )),
                    const SizedBox(width: 6),
                    Text("Sesión activa", style: TextStyle(
                      fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.45), fontSize: 12,
                    )),
                  ]),
                ])),
              ])),

              const SizedBox(height: 20),

              // ── Resumen del mes ────────────────────────────────────────────
              _sectionTitle("Resumen del mes", icon: Icons.bar_chart_rounded),
              _glass(
                padding: const EdgeInsets.all(16),
                child: loadingResumen
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: _kBlue)),
                      )
                    : Row(children: [
                        Expanded(child: _metricTile("OTs",        ots.toString(),        Icons.assignment_rounded,       _kBlueGlow)),
                        const SizedBox(width: 10),
                        Expanded(child: _metricTile("Pendientes", pendientes.toString(), Icons.pending_actions_rounded,  Colors.orangeAccent)),
                        const SizedBox(width: 10),
                        Expanded(child: _metricTile("Total",      _money(total),         Icons.monetization_on_rounded,  _kBlue)),
                      ]),
              ),

              const SizedBox(height: 20),

              // ── Acciones ──────────────────────────────────────────────────
              _sectionTitle("Acciones", icon: Icons.bolt_rounded),
              _glass(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Column(children: [
                _actionTile(
                  icon: Icons.edit_rounded,
                  label: "Editar perfil",
                  onTap: () async {
                    final changed = await Navigator.pushNamed(context, '/editarperfil');
                    if (changed == true) await _cargarTodo();
                  },
                ),
                Divider(color: _kBlue.withOpacity(0.10), height: 1),
                _actionTile(
                  icon: Icons.lock_reset_rounded,
                  label: "Cambiar contraseña",
                  onTap: () => Navigator.pushNamed(context, '/cambiar_password'),
                ),
              ])),

              const SizedBox(height: 20),

              // ── Info ──────────────────────────────────────────────────────
              _sectionTitle("Información", icon: Icons.info_outline_rounded),
              _glass(padding: const EdgeInsets.all(18), child: Column(children: [
                _infoRow(Icons.email_outlined,      "Correo",   correo),
                Divider(color: _kBlue.withOpacity(0.08), height: 20),
                _infoRow(Icons.alternate_email_rounded, "Usuario", usuario),
              ])),

            ],
          ),
        ]),
      ),
    );
  }

  // ── Tile de métrica ────────────────────────────────────────────────────────
  Widget _metricTile(String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.20), width: 1),
        ),
        child: Column(children: [
          Container(width: 30, height: 30,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.12)),
            child: Icon(icon, color: color, size: 15)),
          const SizedBox(height: 7),
          Text(value,
            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Ubuntu', color: color, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
            fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.38), fontSize: 10, letterSpacing: 0.3)),
        ]),
      );

  // ── Fila de acción ─────────────────────────────────────────────────────────
  Widget _actionTile({required IconData icon, required String label, required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBlue.withOpacity(0.25), width: 1),
              ),
              child: Icon(icon, color: _kBlue, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite, fontWeight: FontWeight.w600, fontSize: 14))),
            Icon(Icons.chevron_right_rounded, color: _kBlue.withOpacity(0.45), size: 20),
          ]),
        ),
      );

  // ── Fila de info ───────────────────────────────────────────────────────────
  Widget _infoRow(IconData icon, String key, String value) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: _kBlue.withOpacity(0.6), size: 18),
        const SizedBox(width: 10),
        SizedBox(width: 68, child: Text(key, style: TextStyle(
          fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.40),
          fontWeight: FontWeight.w600, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(
          fontFamily: 'Ubuntu', color: _kWhite, fontWeight: FontWeight.w600, fontSize: 13))),
      ]);
}