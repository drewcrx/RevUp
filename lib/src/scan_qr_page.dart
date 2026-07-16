import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'api_service.dart';
import 'detalle_vehiculo_desde_qr.dart';
import 'qr_utils.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kWhite    = Color(0xFFF0F4FF);

class ScanQRPage extends StatefulWidget {
  const ScanQRPage({super.key});
  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage>
    with SingleTickerProviderStateMixin {
  // ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
  bool _processing = false;

  late AnimationController _controller;
  late Animation<double>   _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _abrirDetalleDesdeQr(String codigoLeido) async {
    final data = await ApiService.buscarDetallePorQrToken(codigoLeido);
    if (!mounted) return;
    if (data == null) {
      _mostrarNoEncontrado(context, codigoLeido);
      setState(() => _processing = false);
      return;
    }
    await Navigator.push(context,
      MaterialPageRoute(
        builder: (_) => DetalleVehiculoDesdeQrPage(data: data)));
    if (mounted) setState(() => _processing = false);
  }

  void _mostrarNoEncontrado(BuildContext context, String codigo) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF080E1A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.redAccent.withOpacity(0.28)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.search_off_rounded,
                color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              const Text("Vehículo no encontrado", style: TextStyle(
                fontFamily: 'Ubuntu', color: Colors.redAccent,
                fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
            const SizedBox(height: 12),
            Text(
              "No existe un vehículo registrado con el código:",
              style: TextStyle(fontFamily: 'Ubuntu',
                color: _kWhite.withOpacity(0.45), fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBlue.withOpacity(0.18)),
              ),
              child: Text(codigo, style: const TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite,
                fontWeight: FontWeight.w600, fontSize: 13,
                letterSpacing: 0.5)),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 44, width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2AA0FF), _kBlueDark]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(
                    color: _kBlue.withOpacity(0.28),
                    blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: const Center(child: Text("CERRAR", style: TextStyle(
                  fontFamily: 'Ubuntu', color: Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 13,
                  letterSpacing: 1.5))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
  // ═════════════════════════════════════════════════════════════════════════ //

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(fontFamily: 'Ubuntu',
        textTheme: const TextTheme().apply(fontFamily: 'Ubuntu')),
      child: Scaffold(
        backgroundColor: Colors.black,

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
                Colors.transparent, _kBlue.withOpacity(0.40),
                Colors.transparent]))),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kBlue, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
              decoration: const BoxDecoration(
                color: _kBlue, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text("ESCANEAR QR", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 2.5)),
          ]),
          centerTitle: true,
        ),

        body: Stack(children: [

          // ── Cámara a pantalla completa ────────────────────────────────────
          Positioned.fill(
            child: MobileScanner(
              controller: MobileScannerController(
                detectionSpeed: DetectionSpeed.noDuplicates),
              onDetect: (capture) async {
                if (_processing) return;
                setState(() => _processing = true);
                final rawValue = capture.barcodes.first.rawValue;
                if (rawValue == null || rawValue.trim().isEmpty) {
                  setState(() => _processing = false);
                  return;
                }
                await _abrirDetalleDesdeQr(extraerTokenDeQr(rawValue));
              },
            ),
          ),

          // ── Overlay oscuro en los bordes (vignette) ───────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.75,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.72),
                  ],
                ),
              ),
            ),
          ),

          // ── Marco de escaneo ──────────────────────────────────────────────
          Center(
            child: SizedBox(
              width: 260, height: 260,
              child: Stack(children: [

                // Marco principal con glow azul
                Container(
                  width: 260, height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kBlue, width: 2),
                    boxShadow: [
                      BoxShadow(color: _kBlue.withOpacity(0.45),
                        blurRadius: 24, spreadRadius: 2),
                    ],
                  ),
                ),

                // Esquinas decorativas (más gruesas y destacadas)
                ..._corners(),

                // Línea de escaneo animada
                AnimatedBuilder(
                  animation: _animation,
                  builder: (_, __) => Positioned(
                    top: 260 * _animation.value,
                    child: Container(
                      width: 260, height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          _kBlue,
                          _kBlue.withOpacity(0.8),
                          Colors.transparent,
                        ]),
                        boxShadow: [
                          BoxShadow(color: _kBlue.withOpacity(0.60),
                            blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Estado de procesamiento ────────────────────────────────────────
          Positioned(
            bottom: 60, left: 0, right: 0,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_processing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kBlue)),
                ),
              Text(
                _processing ? "Procesando..." : "Apunta al código QR del vehículo",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Ubuntu',
                  color: _processing ? _kBlue : _kWhite.withOpacity(0.70),
                  fontSize: 13,
                  fontWeight: _processing
                      ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.3,
                  shadows: [Shadow(
                    color: _kBlue.withOpacity(0.50), blurRadius: 12)],
                ),
              ),
            ]),
          ),

          // ── Badge "RevUp" en la esquina superior derecha del marco ─────────
          Center(
            child: Transform.translate(
              offset: const Offset(0, -148),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kBlue.withOpacity(0.90),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [BoxShadow(
                    color: _kBlue.withOpacity(0.40), blurRadius: 10)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.qr_code_scanner_rounded,
                    color: Colors.white, size: 13),
                  const SizedBox(width: 5),
                  const Text("RevUp Scanner", style: TextStyle(
                    fontFamily: 'Ubuntu', color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 11,
                    letterSpacing: 0.5)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Esquinas decorativas del marco de escaneo ─────────────────────────────
  List<Widget> _corners() {
    const size  = 22.0;
    const thick = 3.0;
    const r     = 8.0;

    Widget corner(Alignment a) {
      final isLeft   = a == Alignment.topLeft || a == Alignment.bottomLeft;
      final isTop    = a == Alignment.topLeft || a == Alignment.topRight;
      return Positioned(
        top:    isTop    ? 0 : null,
        bottom: !isTop   ? 0 : null,
        left:   isLeft   ? 0 : null,
        right:  !isLeft  ? 0 : null,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            border: Border(
              top:    isTop    ? BorderSide(color: _kBlue, width: thick) : BorderSide.none,
              bottom: !isTop   ? BorderSide(color: _kBlue, width: thick) : BorderSide.none,
              left:   isLeft   ? BorderSide(color: _kBlue, width: thick) : BorderSide.none,
              right:  !isLeft  ? BorderSide(color: _kBlue, width: thick) : BorderSide.none,
            ),
            borderRadius: BorderRadius.only(
              topLeft:     a == Alignment.topLeft     ? const Radius.circular(r) : Radius.zero,
              topRight:    a == Alignment.topRight    ? const Radius.circular(r) : Radius.zero,
              bottomLeft:  a == Alignment.bottomLeft  ? const Radius.circular(r) : Radius.zero,
              bottomRight: a == Alignment.bottomRight ? const Radius.circular(r) : Radius.zero,
            ),
          ),
        ),
      );
    }

    return [
      corner(Alignment.topLeft),
      corner(Alignment.topRight),
      corner(Alignment.bottomLeft),
      corner(Alignment.bottomRight),
    ];
  }
}