// perfil.dart
import 'dart:convert';
import 'package:flutter/material.dart';

import 'session.dart';
import 'api_service.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  bool loading = true;

  String nombre = '';
  String correo = '';
  String usuario = '';
  String role = 'mechanic';
  String? avatarB64;

  // Resumen mes
  bool loadingResumen = true;
  int ots = 0;
  int pendientes = 0;
  double total = 0;

  static const green = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

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
      nombre = (u?['nombre'] ?? 'Sin nombre').toString();
      correo = (u?['correo'] ?? 'Sin correo').toString();
      usuario = (u?['usuario'] ?? 'Sin usuario').toString();
      role = (u?['role'] ?? 'mechanic').toString();
      avatarB64 = u?['avatar_b64']?.toString();
    });
  }

  // ✅ Resumen del mes desde /ordenes (mismo origen que tu dashboard)
  Future<void> _cargarResumenMes() async {
    if (!mounted) return;
    setState(() => loadingResumen = true);

    try {
      final ordenes = await ApiService.obtenerOrdenes(soloMias: true);

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final nextMonthStart = DateTime(now.year, now.month + 1, 1);

      bool isInThisMonth(DateTime d) =>
          !d.isBefore(monthStart) && d.isBefore(nextMonthStart);

      String estadoUiFrom(Map<String, dynamic> o) {
        final s = (o['estado_ui'] ?? o['estado'] ?? '').toString().trim();
        if (s.isNotEmpty) return s;

        // Fallback por si algún día no viene estado_ui:
        final estado = (o['estado'] ?? '').toString().trim();
        final ts = double.tryParse((o['total_servicios'] ?? 0).toString()) ?? 0;
        final tr = double.tryParse((o['total_repuestos'] ?? 0).toString()) ?? 0;
        final t = double.tryParse((o['total'] ?? 0).toString()) ?? 0;

        if (estado == 'RECIBIDO' && (ts > 0 || tr > 0 || t > 0)) return 'PENDIENTE';
        return estado;
      }

      double money(dynamic v) => double.tryParse((v ?? 0).toString()) ?? 0;

      int otsLocal = 0;
      int pendientesLocal = 0;
      double totalLocal = 0;

      for (final o in ordenes) {
        final raw = (o['created_at'] ?? '').toString();
        final dt = DateTime.tryParse(raw);
        if (dt == null) continue;

        final local = dt.toLocal();
        if (!isInThisMonth(local)) continue;

        otsLocal++;

        final estadoUi = estadoUiFrom(o).toUpperCase();
        if (estadoUi == 'PENDIENTE') pendientesLocal++;

        totalLocal += money(o['total']);
      }

      if (!mounted) return;
      setState(() {
        ots = otsLocal;
        pendientes = pendientesLocal;
        total = totalLocal;
        loadingResumen = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        ots = 0;
        pendientes = 0;
        total = 0;
        loadingResumen = false;
      });
    }
  }

  ImageProvider? _avatarProvider() {
    final b64 = (avatarB64 ?? '').trim();
    if (b64.isEmpty) return null;

    try {
      final cleaned = b64.contains(',') ? b64.split(',').last : b64;
      final bytes = base64Decode(cleaned);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  String _roleLabel(String r) {
    final s = r.trim().toLowerCase();
    if (s == 'superuser' || s == 'admin') return 'Administrador';
    if (s == 'mechanic' || s == 'mecanico' || s == 'mecánico') return 'Mecánico';
    return r.isEmpty ? 'Usuario' : r;
  }

  String _money(double v) {
    // Formato simple tipo: $1,240.50 (sin intl para no agregar dependencia)
    final sign = v < 0 ? "-" : "";
    final n = v.abs();

    final parts = n.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final idxFromEnd = intPart.length - i;
      buf.write(intPart[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(',');
    }

    return "$sign\$${buf.toString()}.$decPart";
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        t,
        style: const TextStyle(
          fontFamily: 'BBH_Sans_Bogle',
          color: Colors.white70,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final avatar = _avatarProvider();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: green,
        foregroundColor: Colors.black,
        title: const Text(
          'PERFIL',
          style: TextStyle(fontFamily: 'BBH_Sans_Bogle', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Refrescar",
            onPressed: () async => _cargarTodo(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.black,
                  backgroundImage: avatar,
                  child: avatar == null
                      ? const Icon(Icons.person, size: 34, color: Colors.white70)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontFamily: 'BBH_Sans_Bogle',
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _roleLabel(role),
                        style: const TextStyle(
                          fontFamily: 'BBH_Sans_Bogle',
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          Icon(Icons.circle, size: 10, color: green),
                          SizedBox(width: 6),
                          Text(
                            "Sesión activa",
                            style: TextStyle(
                              fontFamily: 'BBH_Sans_Bogle',
                              color: Colors.white60,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _sectionTitle("[ Resumen del mes ]"),
          _card(
            child: loadingResumen
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _metricBox(
                          title: "OTs",
                          value: ots.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _metricBox(
                          title: "Pendientes",
                          value: pendientes.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _metricBox(
                          title: "Total",
                          value: _money(total),
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 16),

          _sectionTitle("[ Acciones ]"),
          _card(
            child: Column(
              children: [
                _actionTile(
                  icon: Icons.edit,
                  title: "Editar perfil",
                  onTap: () async {
                    final changed = await Navigator.pushNamed(context, '/editarperfil');
                    if (changed == true) {
                      await _cargarTodo();
                    }
                  },
                ),
                const Divider(color: Colors.white12, height: 18),
                _actionTile(
                  icon: Icons.lock_reset,
                  title: "Cambiar contraseña",
                  onTap: () => Navigator.pushNamed(context, '/forgot_password'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _sectionTitle("[ Info ]"),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow("Correo:", correo),
                const SizedBox(height: 10),
                _infoRow("Usuario:", usuario),
              ],
            ),
          ),

          const SizedBox(height: 22),
        ],
      ),
    );
  }

  Widget _metricBox({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'BBH_Sans_Bogle',
              color: Colors.white60,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'BBH_Sans_Bogle',
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: green.withOpacity(0.35)),
              ),
              child: Icon(icon, color: green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'BBH_Sans_Bogle',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            k,
            style: const TextStyle(
              fontFamily: 'BBH_Sans_Bogle',
              color: Colors.white60,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontFamily: 'BBH_Sans_Bogle',
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
