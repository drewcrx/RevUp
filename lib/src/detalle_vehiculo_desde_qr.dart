import 'package:flutter/material.dart';
import 'api_service.dart';

class DetalleVehiculoDesdeQrPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const DetalleVehiculoDesdeQrPage({super.key, required this.data});

  @override
  State<DetalleVehiculoDesdeQrPage> createState() => _DetalleVehiculoDesdeQrPageState();
}

class _DetalleVehiculoDesdeQrPageState extends State<DetalleVehiculoDesdeQrPage> {
  late final Map<String, dynamic> vehiculo;
  late final String placa;
  late final String token;

  bool loading = false;
  String error = '';
  List<Map<String, dynamic>> ots = [];

  @override
  void initState() {
    super.initState();

    vehiculo = (widget.data["vehiculo"] as Map<String, dynamic>?) ?? {};
    placa = (vehiculo["placa"] ?? "").toString().trim().toUpperCase();
    token = (vehiculo["qr_token"] ?? "").toString().trim();

    _loadOts();
  }

  Future<void> _loadOts() async {
    setState(() {
      loading = true;
      error = '';
      ots = [];
    });

    try {
      // 1) Intento por QR token (si tu backend lo soporta)
      // 2) Si no, fallback por placa (más común)
      final data = await ApiService.obtenerOtsPorQrOTokenOFallback(placa: placa, token: token);
      setState(() => ots = data);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'RECIBIDO':
        return Colors.blueGrey;
      case 'DIAGNOSTICO':
        return Colors.orange;
      case 'REPARACION':
        return Colors.yellow;
      case 'LISTO':
        return Colors.lightGreen;
      case 'ENTREGADO':
        return Colors.green;
      default:
        return Colors.white54;
    }
  }

  String _money(dynamic v) {
    if (v == null) return "0.00";
    final s = v.toString();
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final marca = (vehiculo["marca"] ?? "").toString();
    final modelo = (vehiculo["modelo"] ?? "").toString();
    final km = (vehiculo["kilometraje"] ?? 0).toString();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A86B),
        foregroundColor: Colors.white,
        title: Text(
          "$marca $modelo",
          style: const TextStyle(fontFamily: 'BBH_Sans_Bogle'),
        ),
        actions: [
          IconButton(
            onPressed: _loadOts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "PLACA: $placa",
              style: const TextStyle(
                color: Color(0xFF00A86B),
                fontSize: 18,
                fontFamily: 'BBH_Sans_Bogle',
              ),
            ),
            Text(
              "KM: $km",
              style: const TextStyle(color: Colors.white70, fontFamily: 'BBH_Sans_Bogle'),
            ),
            const SizedBox(height: 14),

            const Text(
              "HISTORIAL DE OTs",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontFamily: 'BBH_Sans_Bogle',
              ),
            ),
            const SizedBox(height: 10),

            if (loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error.isNotEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    error,
                    style: const TextStyle(color: Colors.red, fontFamily: 'BBH_Sans_Bogle'),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (ots.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    "SIN OTs REGISTRADAS",
                    style: TextStyle(color: Colors.white70, fontFamily: 'BBH_Sans_Bogle'),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: ots.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white24),
                  itemBuilder: (_, i) {
                    final o = ots[i];
                    final id = int.tryParse((o['id'] ?? '').toString()) ?? 0;
                    final estado = (o['estado'] ?? '').toString();
                    final pago = (o['pago_estado'] ?? '').toString();
                    final total = (o['total'] ?? 0);

                    return ListTile(
                      title: Text(
                        "OT #$id",
                        style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                      ),
                      subtitle: Text(
                        "Estado: $estado | Pago: $pago | Total: \$${_money(total)}",
                        style: TextStyle(color: _colorEstado(estado), fontFamily: 'BBH_Sans_Bogle'),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF00A86B), size: 18),
                      onTap: () async {
                        // abre tu detalle existente
                        final ok = await Navigator.pushNamed(
                          context,
                          '/detalle_orden',
                          arguments: id,
                        );
                        if (ok == true) {
                          _loadOts();
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
