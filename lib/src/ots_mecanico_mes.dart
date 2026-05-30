import 'package:flutter/material.dart';
import 'api_service.dart';
import 'detalle_orden.dart';
import 'session.dart';

class OtsMecanicoMesPage extends StatefulWidget {
  final int mechanicId;
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
  late Future<List<Map<String, dynamic>>> future;

  int _currentUserIdOrThrow() {
    final u = Session.user;
    final id = u?['id'];
    if (id == null) {
      throw Exception("No hay sesión activa (user.id es null)");
    }
    return int.parse(id.toString());
  }

  String _money(dynamic v) {
    if (v == null) return "0.00";
    return v.toString();
  }

  @override
  void initState() {
    super.initState();

    final myId = _currentUserIdOrThrow();

    // ✅ Si piden mis OTs, usamos el endpoint de mecánico (no requiere superuser)
    if (widget.mechanicId == myId) {
      future = ApiService.obtenerMisOtsDelMes(month: widget.month);
    } else {
      // ✅ Si piden OTs de otro mecánico, usamos el endpoint que permite superuser
      future = ApiService.obtenerOtsMecanicoMes(
        mechanicId: widget.mechanicId,
        month: widget.month,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.black,
        title: Text(
          '${widget.mechanicNombre} · ${widget.month}',
          style: const TextStyle(fontFamily: 'BBH_Sans_Bogle'),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final ots = snapshot.data ?? [];
          if (ots.isEmpty) {
            return const Center(
              child: Text(
                'No hay órdenes en este mes',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: ots.length,
            itemBuilder: (_, i) {
              final ot = ots[i];
              return Card(
                color: Colors.black,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.green),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    'OT #${ot["id"]} · ${ot["placa"]}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'BBH_Sans_Bogle',
                    ),
                  ),
                  subtitle: Text(
                    'Total: \$${_money(ot["total"])} · Pagado: \$${_money(ot["pagado"])}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: Text(
                    (ot["estado"] ?? "").toString(),
                    style: const TextStyle(color: Colors.green),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetalleOrdenPage(
                          ordenId: int.parse(ot["id"].toString()),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
