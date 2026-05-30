import 'package:flutter/material.dart';
import 'api_service.dart';
import 'ots_mecanico_mes.dart';
import 'session.dart';
import 'detalle_orden.dart';


class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  final _monthCtrl = TextEditingController();

  bool loading = false;
  String error = '';

  // Para la lista: puede ser lista de mecánicos (superuser) o lista de OTs (mecánico)
  List<Map<String, dynamic>> rows = [];

  // Resumen: puede ser global (superuser) o personal (mecánico)
  Map<String, dynamic>? resumen;

  // Modo actual
  bool isSuper = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    _monthCtrl.text = "${now.year}-$m";

    isSuper = _isSuperuser();
    _load();
  }

  @override
  void dispose() {
    _monthCtrl.dispose();
    super.dispose();
  }

  bool _isSuperuser() {
    final u = Session.user;
    if (u == null) return false;

    final role = (u['role'] ?? u['rol'] ?? u['tipo'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    return role == 'superuser';
  }

  int _currentUserIdOrThrow() {
    final u = Session.user;
    final id = u?['id'];
    if (id == null) throw Exception("No hay sesión activa (user.id es null)");
    return int.parse(id.toString());
  }

  String _money(dynamic v) {
    if (v == null) return "0.00";
    return v.toString();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final month = _monthCtrl.text.trim();
      if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(month)) {
        throw Exception("Mes inválido. Usa formato YYYY-MM (ej: 2026-02)");
      }

      // recalcula por si cambió sesión
      isSuper = _isSuperuser();

      if (isSuper) {
        // ✅ SUPERUSER: resumen global + lista por mecánicos
        final r = await ApiService.obtenerResumenMensual(month: month);
        final data = await ApiService.obtenerReporteMecanicos(month: month);

        setState(() {
          resumen = r;
          rows = data;
        });
      } else {
        // ✅ MECÁNICO: mi resumen + mis OTs del mes
        final r = await ApiService.obtenerMiResumenMensual(month: month);
        final ots = await ApiService.obtenerMisOtsDelMes(month: month);

        setState(() {
          resumen = r;
          rows = ots;
        });
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  void _onTapRow(Map<String, dynamic> r) {
    if (isSuper) {
      // SUPERUSER → ver OTs del mecánico seleccionado
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtsMecanicoMesPage(
            mechanicId: r["mechanic_id"],
            mechanicNombre: r["mechanic_nombre"] ?? "Mecánico",
            month: _monthCtrl.text.trim(),
          ),
        ),
      );
    } else {
      // MECÁNICO → abrir detalle directo de la OT
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetalleOrdenPage(
            ordenId: int.parse(r["id"].toString()),
          ),
        ),
      );
    }
  }

  Widget _buildResumenCard() {
    if (resumen == null) return const SizedBox.shrink();

    final titulo = isSuper ? "RESUMEN DEL TALLER" : "MI RESUMEN (MES)";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'BBH_Sans_Bogle',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Ingresos: \$${_money(resumen!['ingresos'])}",
            style: const TextStyle(color: Colors.green),
          ),
          Text(
            "Gastos: \$${_money(resumen!['gastos'])}",
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            "Utilidad: \$${_money(resumen!['utilidad'])}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowCard(Map<String, dynamic> r) {
    if (isSuper) {
      // Card por mecánico (como lo tenías)
      return InkWell(
        onTap: () => _onTapRow(r),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${r["mechanic_nombre"] ?? "Mecánico"} (ID: ${r["mechanic_id"]})",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text("OTs: ${r["ots"] ?? 0}", style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              Text("Total OT: \$${_money(r["total_ot"])}", style: const TextStyle(color: Colors.green)),
              Text("Pagado (mes): \$${_money(r["total_pagado_mes"])}",
                  style: const TextStyle(color: Colors.white70)),
              Text("Gastos (repuestos): \$${_money(r["total_gastos"])}",
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              Text(
                "Utilidad estimada: \$${_money(r["utilidad_estimada"])}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    // Card por OT (mecánico)
    final id = r["id"];
    final placa = (r["placa"] ?? "").toString();
    final estado = (r["estado"] ?? "").toString();
    final total = r["total"];
    final pagado = r["pagado"];
    final createdAt = (r["created_at"] ?? "").toString();

    return InkWell(
      onTap: () => _onTapRow(r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "OT #$id — $placa",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text("Estado: $estado", style: const TextStyle(color: Colors.white70)),
            Text("Fecha: $createdAt", style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text("Total: \$${_money(total)}", style: const TextStyle(color: Colors.green)),
            Text("Pagado: \$${_money(pagado)}", style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.black,
        title: const Text(
          "REPORTES",
          style: TextStyle(fontFamily: 'BBH_Sans_Bogle'),
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _monthCtrl,
                    style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                    decoration: const InputDecoration(
                      labelText: "Mes (YYYY-MM)",
                      labelStyle: TextStyle(color: Colors.green, fontFamily: 'BBH_Sans_Bogle'),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: loading ? null : _load,
                  child: const Text(
                    "VER",
                    style: TextStyle(
                      fontFamily: 'BBH_Sans_Bogle',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: CircularProgressIndicator(),
              )
            else if (error.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  error,
                  style: const TextStyle(color: Colors.red, fontFamily: 'BBH_Sans_Bogle'),
                ),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    _buildResumenCard(),
                    ...rows.map(_buildRowCard).toList(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
