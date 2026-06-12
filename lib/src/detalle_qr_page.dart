import 'package:flutter/material.dart';
import 'vehiculo_model.dart';
import 'detalle_vehiculo.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);

// ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
List<Vehiculo> listaVehiculos = [
  Vehiculo(
    placa: "ABC123", marca: "Toyota", modelo: "Corolla",
    kilometraje: 0, ultimaVisita: DateTime.now(), arreglos: [],
  ),
  Vehiculo(
    placa: "XYZ987", marca: "Hyundai", modelo: "Tucson",
    kilometraje: 0, ultimaVisita: DateTime.now(), arreglos: [],
  ),
];

class DetalleQRPage extends StatelessWidget {
  const DetalleQRPage({super.key});

  Vehiculo? buscarVehiculo(String placa) {
    try {
      return listaVehiculos.firstWhere(
        (v) => v.placa.toUpperCase() == placa.toUpperCase());
    } catch (_) { return null; }
  }
  // ═════════════════════════════════════════════════════════════════════════ //

  @override
  Widget build(BuildContext context) {
    final String   qrData            = ModalRoute.of(context)!.settings.arguments as String;
    final Vehiculo? vehiculoEncontrado = buscarVehiculo(qrData);

    return Theme(
      data: ThemeData(fontFamily: 'Ubuntu',
        textTheme: const TextTheme().apply(fontFamily: 'Ubuntu')),
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
            Container(width: 6, height: 6,
              decoration: const BoxDecoration(color: _kBlue, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text("RESULTADO QR", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 2.5)),
          ]),
          centerTitle: true,
        ),

        // ── Body ────────────────────────────────────────────────────────────
        body: Stack(children: [
          // Fondo
          Positioned.fill(child: const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF060B18), _kBg, Color(0xFF030509)]),
          ))),
          Positioned(top: -80, right: -60, child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _kBlue.withOpacity(0.08), Colors.transparent])),
          )),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: vehiculoEncontrado != null
                  ? _mostrarVehiculo(context, vehiculoEncontrado)
                  : _mostrarError(qrData),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Vehículo encontrado ────────────────────────────────────────────────────
  Widget _mostrarVehiculo(BuildContext context, Vehiculo vehiculo) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Ícono de éxito con glow
      Stack(alignment: Alignment.center, children: [
        Container(width: 100, height: 100,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _kBlue.withOpacity(0.15), Colors.transparent]))),
        Container(width: 76, height: 76,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: _kBlue.withOpacity(0.10),
            border: Border.all(color: _kBlue.withOpacity(0.30), width: 1.5)),
          child: const Icon(Icons.qr_code_scanner_rounded,
            color: _kBlue, size: 34)),
      ]),

      const SizedBox(height: 20),

      Text("Vehículo encontrado", style: const TextStyle(
        fontFamily: 'Ubuntu', color: _kWhite,
        fontWeight: FontWeight.w700, fontSize: 18)),
      const SizedBox(height: 6),
      Text("QR leído correctamente", style: TextStyle(
        fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.35), fontSize: 12)),

      const SizedBox(height: 28),

      // Card del vehículo
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF080E1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBlue.withOpacity(0.16)),
          boxShadow: [BoxShadow(
            color: _kBlue.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          // Avatar vehículo
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF2AA0FF), _kBlueDark]),
              boxShadow: [BoxShadow(
                color: _kBlue.withOpacity(0.28), blurRadius: 12)],
            ),
            child: const Icon(Icons.directions_car_rounded,
              color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${vehiculo.marca} ${vehiculo.modelo}",
              style: const TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite,
                fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kBlue.withOpacity(0.30)),
              ),
              child: Text(vehiculo.placa, style: const TextStyle(
                fontFamily: 'Ubuntu', color: _kBlue,
                fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2)),
            ),
          ])),
        ]),
      ),

      const SizedBox(height: 20),

      // Botón abrir detalle
      GestureDetector(
        onTap: () => Navigator.push(context,
          MaterialPageRoute(
            builder: (_) => DetalleVehiculoPage(vehiculo: vehiculo))),
        child: Container(
          width: double.infinity, height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF2AA0FF), _kBlueDark]),
            boxShadow: [BoxShadow(
              color: _kBlue.withOpacity(0.38),
              blurRadius: 18, offset: const Offset(0, 5))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Text("VER DETALLE", style: TextStyle(
              fontFamily: 'Ubuntu', color: Colors.white,
              fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
          ]),
        ),
      ),
    ]);
  }

  // ── Error: vehículo no encontrado ──────────────────────────────────────────
  Widget _mostrarError(String data) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Ícono de error con glow rojo
      Stack(alignment: Alignment.center, children: [
        Container(width: 100, height: 100,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              Colors.redAccent.withOpacity(0.12), Colors.transparent]))),
        Container(width: 76, height: 76,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: Colors.redAccent.withOpacity(0.08),
            border: Border.all(color: Colors.redAccent.withOpacity(0.28), width: 1.5)),
          child: const Icon(Icons.search_off_rounded,
            color: Colors.redAccent, size: 34)),
      ]),

      const SizedBox(height: 20),

      const Text("Vehículo no encontrado", style: TextStyle(
        fontFamily: 'Ubuntu', color: _kWhite,
        fontWeight: FontWeight.w700, fontSize: 18)),
      const SizedBox(height: 6),
      Text("El código escaneado no coincide con ningún vehículo registrado",
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Ubuntu',
          color: _kWhite.withOpacity(0.35), fontSize: 12, height: 1.5)),

      const SizedBox(height: 28),

      // Chip con el código escaneado
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withOpacity(0.18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.qr_code_rounded,
              color: Colors.redAccent.withOpacity(0.60), size: 14),
            const SizedBox(width: 6),
            Text("Código escaneado", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.38),
              fontSize: 11, letterSpacing: 0.3)),
          ]),
          const SizedBox(height: 8),
          Text(data, style: TextStyle(
            fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.65),
            fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.5)),
        ]),
      ),

      const SizedBox(height: 20),

      // Botón volver
      GestureDetector(
        onTap: () {},   // el pop lo maneja el AppBar; este botón puede usarse para reintentar
        child: Container(
          width: double.infinity, height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _kBlue.withOpacity(0.28)),
            color: _kBlue.withOpacity(0.06),
          ),
          child: Center(child: Text("ESCANEAR OTRO", style: TextStyle(
            fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.55),
            fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1.5))),
        ),
      ),
    ]);
  }
}