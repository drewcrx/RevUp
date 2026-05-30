import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'api_service.dart';
import 'detalle_vehiculo_desde_qr.dart';

class ScanQRPage extends StatefulWidget {
  const ScanQRPage({super.key});

  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage> with SingleTickerProviderStateMixin {
  bool _processing = false;

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _abrirDetalleDesdeQr(String codigoLeido) async {
    final data = await ApiService.buscarDetallePorQrToken(codigoLeido);

    if (!mounted) return;

    if (data == null) {
      _mostrarNoEncontrado(context, codigoLeido);
      setState(() => _processing = false);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleVehiculoDesdeQrPage(data: data),
      ),
    );

    if (mounted) setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A86B),
        title: const Text(
          "Escanear QR",
          style: TextStyle(fontFamily: "BBH_Sans_Bogle", color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates),
            onDetect: (capture) async {
              if (_processing) return;

              setState(() => _processing = true);

              final rawValue = capture.barcodes.first.rawValue;
              if (rawValue == null || rawValue.trim().isEmpty) {
                setState(() => _processing = false);
                return;
              }

              final codigoLeido = rawValue.trim();
              await _abrirDetalleDesdeQr(codigoLeido);
            },
          ),

          Center(
            child: Stack(
              children: [
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.greenAccent, width: 3),
                    boxShadow: [
                      BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 20, spreadRadius: 2),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _animation,
                  builder: (_, __) {
                    return Positioned(
                      top: 260 * _animation.value,
                      child: Container(
                        width: 260,
                        height: 2,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.greenAccent, Colors.transparent],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _processing ? "Procesando..." : "Escaneando...",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 18,
                  fontFamily: "BBH_Sans_Bogle",
                  shadows: [Shadow(color: Colors.greenAccent, blurRadius: 12)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarNoEncontrado(BuildContext context, String codigo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          "Vehículo no encontrado",
          style: TextStyle(color: Colors.redAccent, fontFamily: "BBH_Sans_Bogle"),
        ),
        content: Text(
          "No existe un vehículo registrado con el QR o placa:\n\n$codigo",
          style: const TextStyle(color: Colors.white, fontFamily: "BBH_Sans_Bogle"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar", style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }
}
