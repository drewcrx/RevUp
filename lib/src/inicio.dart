// lib/src/inicio.dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'api_service.dart';
import 'session.dart';
import 'ots_mecanico_mes.dart';
import 'detalle_orden.dart';
import 'navbar.dart';

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  static const green = Color(0xFF00A86B);

  bool loading = true;
  String error = "";

  Map<String, dynamic>? user;
  bool get isSuper => (user?["role"]?.toString() ?? "") == "superuser";

  String month = ""; // YYYY-MM

  // ✅ Toggle “Solo pendientes” (solo mecánico)
  bool soloPendientes = false;

  // data
  Map<String, dynamic>? resumenTaller; // superuser
  List<Map<String, dynamic>> reporteMecanicos = []; // superuser

  Map<String, dynamic>? resumenMecanico; // mechanic
  List<Map<String, dynamic>> otsMecanicoMes = []; // mechanic

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, "0");
    month = "${now.year}-$m";

    _bootstrap();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final u = await Session.loadUser();
      if (!mounted) return;

      setState(() {
        user = u;
      });

      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  String _money(dynamic v) {
    if (v == null) return "0.00";
    final s = v.toString();
    return s.isEmpty ? "0.00" : s;
  }

  // ✅ Estado lógico para UI:
  // - Usa estado_ui si viene del backend
  // - Si no existe, cae a estado
  String _estadoUI(Map<String, dynamic> ot) {
    final e = (ot["estado_ui"] ?? ot["estado"] ?? "").toString().toUpperCase();
    return e.isEmpty ? "RECIBIDO" : e;
  }

  // ✅ Solo pendientes reales (no todo menos ENTREGADO)
  bool _isPendiente(Map<String, dynamic> ot) {
    final e = _estadoUI(ot);
    return e == "PENDIENTE";
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        loading = true;
        error = "";
      });
    }

    try {
      final u = user ?? await Session.loadUser();
      if (!mounted) return;
      user = u;

      if (u == null) {
        setState(() {
          loading = false;
          error = "No hay sesión cargada.";
        });
        return;
      }

      final role = (u["role"] ?? "").toString();

      if (role == "superuser") {
        // SUPERUSER
        final r = await ApiService.obtenerResumenMensual(month: month);
        final mec = await ApiService.obtenerReporteMecanicos(month: month);

        if (!mounted) return;
        setState(() {
          resumenTaller = r;
          reporteMecanicos = mec;
          loading = false;
          error = "";
        });
      } else {
        // MECÁNICO
        final id = int.tryParse((u["id"] ?? "").toString());
        if (id == null) {
          setState(() {
            loading = false;
            error = "Tu usuario no tiene ID válido en sesión.";
          });
          return;
        }

        final ots = await ApiService.obtenerOtsMecanicoMes(mechanicId: id, month: month);

        // resumen calculado desde lista (total / pagado / pendientes)
        double totalOt = 0;
        double totalPagado = 0;
        int count = 0;

        for (final ot in ots) {
          final t = double.tryParse((ot["total"] ?? 0).toString()) ?? 0;
          final p = double.tryParse((ot["pagado"] ?? 0).toString()) ?? 0;
          totalOt += t;
          totalPagado += p;
          count++;
        }

        final resumen = <String, dynamic>{
          "ots": count,
          "total_ot": totalOt,
          "total_pagado": totalPagado,
          "pendiente": (totalOt - totalPagado),
        };

        if (!mounted) return;
        setState(() {
          otsMecanicoMes = ots;
          resumenMecanico = resumen;
          loading = false;
          error = "";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _changeMonthPicker() async {
    final now = DateTime.now();

    DateTime initial = now;
    final parts = month.split("-");
    if (parts.length == 2) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (y != null && m != null && m >= 1 && m <= 12) {
        initial = DateTime(y, m, 1);
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      helpText: "Selecciona una fecha (usaremos el mes)",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: green,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.black,
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    final m = picked.month.toString().padLeft(2, "0");
    final newMonth = "${picked.year}-$m";

    if (!mounted) return;
    if (newMonth == month) return;

    setState(() => month = newMonth);
    await _load();
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: green, width: 1.2),
        borderRadius: BorderRadius.circular(14),
        color: Colors.black,
      ),
      child: child,
    );
  }

  Widget _title(String t) {
    return Text(
      t,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: "BBH_Sans_Bogle",
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }

  Widget _kv(String k, String v, {Color valueColor = green, VoidCallback? onTap}) {
    final row = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: const TextStyle(color: Colors.white70, fontFamily: "BBH_Sans_Bogle"),
            ),
          ),
          Text(
            v,
            style: TextStyle(color: valueColor, fontFamily: "BBH_Sans_Bogle", fontWeight: FontWeight.bold),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
          ]
        ],
      ),
    );

    if (onTap == null) return row;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = (user?["nombre"] ?? "Usuario").toString();
    final role = (user?["role"] ?? "mechanic").toString();

    // ✅ aplica filtro SOLO si es mecánico
    final List<Map<String, dynamic>> listaOtsUI = (!isSuper && soloPendientes)
        ? otsMecanicoMes.where(_isPendiente).toList()
        : otsMecanicoMes;

    return Scaffold(
      backgroundColor: Colors.black,
      drawer: const Navbar(),
      appBar: AppBar(
        backgroundColor: green,
        foregroundColor: Colors.black,
        title: const Text("DASHBOARD", style: TextStyle(fontFamily: "BBH_Sans_Bogle")),
        actions: [
          IconButton(
            onPressed: _changeMonthPicker,
            icon: const Icon(Icons.calendar_month, color: Colors.black),
            tooltip: "Cambiar mes",
          ),
          IconButton(
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh, color: Colors.black),
            tooltip: "Refrescar",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : error.isNotEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _title("Error"),
                            const SizedBox(height: 8),
                            Text(
                              error,
                              style: const TextStyle(color: Colors.red, fontFamily: "BBH_Sans_Bogle"),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.black),
                                onPressed: () => _load(),
                                child: const Text(
                                  "Reintentar",
                                  style: TextStyle(fontFamily: "BBH_Sans_Bogle", fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _title("Bienvenido, ${nombre.toUpperCase()}"),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: green,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    role == "superuser" ? "SUPERUSER" : "MECÁNICO",
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontFamily: "BBH_Sans_Bogle",
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "Mes: $month",
                                  style: const TextStyle(color: Colors.white70, fontFamily: "BBH_Sans_Bogle"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // =========================
                      // MECÁNICO DASHBOARD
                      // =========================
                      if (!isSuper) ...[
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _title("Mi resumen del mes"),
                              const SizedBox(height: 6),
                              _kv("OTs del mes", "${resumenMecanico?["ots"] ?? 0}", valueColor: Colors.white),
                              _kv("Total OT", "\$${(resumenMecanico?["total_ot"] ?? 0).toString()}"),
                              _kv(
                                "Pagado",
                                "\$${(resumenMecanico?["total_pagado"] ?? 0).toString()}",
                                valueColor: Colors.white,
                              ),
                              _kv(
                                "Pendiente",
                                "\$${(resumenMecanico?["pendiente"] ?? 0).toString()}",
                                valueColor: Colors.orangeAccent,
                                onTap: () => Navigator.pushNamed(context, "/ordenes"),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _title("Mis OTs del mes")),
                                  const SizedBox(width: 10),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        "Solo pendientes",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontFamily: "BBH_Sans_Bogle",
                                          fontSize: 12,
                                        ),
                                      ),
                                      Switch(
                                        value: soloPendientes,
                                        activeColor: green,
                                        onChanged: (v) {
                                          setState(() => soloPendientes = v);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              if (listaOtsUI.isEmpty)
                                Text(
                                  soloPendientes ? "No tienes órdenes pendientes en este mes." : "No hay órdenes en este mes.",
                                  style: const TextStyle(color: Colors.white70, fontFamily: "BBH_Sans_Bogle"),
                                )
                              else
                                ...listaOtsUI.take(8).map((ot) {
                                  final id = int.tryParse((ot["id"] ?? "").toString()) ?? 0;
                                  final placa = (ot["placa"] ?? "").toString();

                                  // ✅ usar estado_ui si viene del backend
                                  final estado = _estadoUI(ot);

                                  final total = _money(ot["total"]);
                                  final pagado = _money(ot["pagado"]);

                                  Color estadoColor;
                                  if (estado == "ENTREGADO") {
                                    estadoColor = green;
                                  } else if (estado == "PENDIENTE") {
                                    estadoColor = Colors.orangeAccent;
                                  } else {
                                    estadoColor = green; // RECIBIDO
                                  }

                                  final pendiente = _isPendiente(ot);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: pendiente ? Colors.orangeAccent : Colors.white24),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => DetalleOrdenPage(ordenId: id)),
                                        );
                                      },
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "OT #$id · $placa",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontFamily: "BBH_Sans_Bogle",
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "Total: \$$total · Pagado: \$$pagado",
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontFamily: "BBH_Sans_Bogle",
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            estado,
                                            style: TextStyle(color: estadoColor, fontFamily: "BBH_Sans_Bogle"),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward_ios, color: green, size: 16),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),

                              if (listaOtsUI.length > 8)
                                const Text(
                                  "Mostrando solo las primeras 8. Puedes ver el resto desde Reportes u Órdenes.",
                                  style: TextStyle(color: Colors.white38, fontFamily: "BBH_Sans_Bogle", fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],

                      // =========================
                      // SUPERUSER DASHBOARD
                      // =========================
                      if (isSuper) ...[
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _title("Resumen del taller"),
                              const SizedBox(height: 6),
                              _kv("Ingresos", "\$${_money(resumenTaller?["ingresos"])}"),
                              _kv("Gastos (repuestos)", "\$${_money(resumenTaller?["gastos"])}",
                                  valueColor: Colors.white70),
                              _kv("Utilidad", "\$${_money(resumenTaller?["utilidad"])}", valueColor: Colors.white),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _title("Mecánicos (tap para ver OTs)"),
                              const SizedBox(height: 10),
                              if (reporteMecanicos.isEmpty)
                                const Text(
                                  "No hay datos para este mes.",
                                  style: TextStyle(color: Colors.white70, fontFamily: "BBH_Sans_Bogle"),
                                )
                              else
                                ...reporteMecanicos.map((r) {
                                  final mid = int.tryParse((r["mechanic_id"] ?? "").toString()) ?? 0;
                                  final nom = (r["mechanic_nombre"] ?? "Mecánico").toString();

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white24),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => OtsMecanicoMesPage(
                                              mechanicId: mid,
                                              mechanicNombre: nom,
                                              month: month,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "$nom (ID: $mid)",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontFamily: "BBH_Sans_Bogle",
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text("OTs: ${r["ots"] ?? 0}",
                                              style: const TextStyle(color: Colors.white70, fontFamily: "BBH_Sans_Bogle")),
                                          const SizedBox(height: 6),
                                          Text("Total OT: \$${_money(r["total_ot"])}",
                                              style: const TextStyle(color: green, fontFamily: "BBH_Sans_Bogle")),
                                          Text("Pagado (mes): \$${_money(r["total_pagado_mes"])}",
                                              style: const TextStyle(color: Colors.white70, fontFamily: "BBH_Sans_Bogle")),
                                          Text("Gastos: \$${_money(r["total_gastos"])}",
                                              style: const TextStyle(color: Colors.white70, fontFamily: "BBH_Sans_Bogle")),
                                          const SizedBox(height: 6),
                                          Text("Utilidad estimada: \$${_money(r["utilidad_estimada"])}",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontFamily: "BBH_Sans_Bogle",
                                                fontWeight: FontWeight.bold,
                                              )),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _title("Accesos rápidos"),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _quickBtn("Órdenes", Icons.assignment, () => Navigator.pushNamed(context, "/ordenes")),
                                _quickBtn("Vehículos", Icons.directions_car, () => Navigator.pushNamed(context, "/vehiculos")),
                                _quickBtn("Escanear QR", Icons.qr_code_scanner, () => Navigator.pushNamed(context, "/scanqr")),
                                _quickBtn("Perfil", Icons.person, () => Navigator.pushNamed(context, "/perfil")),
                                if (isSuper) _quickBtn("Reportes", Icons.bar_chart, () => Navigator.pushNamed(context, "/reportes")),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
      ),
    );
  }

  Widget _quickBtn(String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: green),
          borderRadius: BorderRadius.circular(14),
          color: Colors.black,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: green),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: "BBH_Sans_Bogle",
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
