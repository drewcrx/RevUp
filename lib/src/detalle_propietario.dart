import 'package:flutter/material.dart';
import 'api_service.dart';
import 'detalle_vehiculo.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);
const _kCard     = Color(0xFF080E1A);

class DetallePropietarioPage extends StatefulWidget {
  final int propietarioId;
  const DetallePropietarioPage({super.key, required this.propietarioId});
  @override
  State<DetallePropietarioPage> createState() => _DetallePropietarioPageState();
}

class _DetallePropietarioPageState extends State<DetallePropietarioPage> {
  bool loading = true;
  String? error;
  Map<String, dynamic>? data;
  bool _abriendoVehiculo = false;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { loading = true; error = null; });
    try {
      final d = await ApiService.obtenerPropietario(widget.propietarioId);
      if (!mounted) return;
      setState(() => data = d);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Ubuntu')),
      backgroundColor: error ? Colors.red.shade900 : _kBlueDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _editar() async {
    final d = data;
    if (d == null) return;
    final nombreCtrl = TextEditingController(text: (d['nombre'] ?? '').toString());
    final telCtrl = TextEditingController(text: (d['telefono'] ?? '').toString());
    final cedCtrl = TextEditingController(text: (d['cedula'] ?? '').toString());
    final emailCtrl = TextEditingController(text: (d['email'] ?? '').toString());
    bool guardando = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1420),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kBlue.withOpacity(0.18))),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Editar propietario", style: TextStyle(fontFamily: 'Ubuntu',
                  color: _kWhite, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text("Los cambios se aplican a todos sus vehículos.",
                  style: TextStyle(fontFamily: 'Ubuntu',
                    color: _kWhite.withOpacity(0.35), fontSize: 11)),
                const SizedBox(height: 16),
                _campo(nombreCtrl, "Nombre"),
                const SizedBox(height: 12),
                _campo(telCtrl, "Teléfono", keyboard: TextInputType.phone),
                const SizedBox(height: 12),
                _campo(cedCtrl, "Cédula (opcional)"),
                const SizedBox(height: 12),
                _campo(emailCtrl, "Email (opcional)", keyboard: TextInputType.emailAddress),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 44,
                  child: GestureDetector(
                    onTap: guardando ? null : () async {
                      final n = nombreCtrl.text.trim();
                      if (n.isEmpty) { _snack('El nombre no puede quedar vacío', error: true); return; }
                      setS(() => guardando = true);
                      try {
                        await ApiService.actualizarPropietario(
                          id: widget.propietarioId, nombre: n,
                          telefono: telCtrl.text.trim(), cedula: cedCtrl.text.trim(),
                          email: emailCtrl.text.trim());
                        if (!mounted) return;
                        Navigator.pop(ctx2);
                        _cargar();
                        _snack('Propietario actualizado ✅');
                      } catch (e) {
                        setS(() => guardando = false);
                        _snack('Error: $e', error: true);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(colors: [Color(0xFF2AA0FF), _kBlueDark])),
                      child: Center(child: guardando
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text("GUARDAR", style: TextStyle(
                              fontFamily: 'Ubuntu', color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1))),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    nombreCtrl.dispose();
    telCtrl.dispose();
    cedCtrl.dispose();
    emailCtrl.dispose();
  }

  Widget _campo(TextEditingController ctrl, String label, {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: 'Ubuntu', color: _kBlue.withOpacity(0.8), fontSize: 12),
        filled: true, fillColor: _kBlue.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _kBlue.withOpacity(0.22))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBlue, width: 1.5)),
      ),
    );
  }

  Future<void> _abrirVehiculo(String placa) async {
    if (_abriendoVehiculo) return;
    setState(() => _abriendoVehiculo = true);
    try {
      final v = await ApiService.buscarPorPlaca(placa);
      if (!mounted) return;
      if (v == null) { _snack('No se pudo abrir el vehículo', error: true); return; }
      await Navigator.push(context,
        MaterialPageRoute(builder: (_) => DetalleVehiculoPage(vehiculo: v)));
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _abriendoVehiculo = false);
    }
  }

  Widget _dato(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 90, child: Text(label, style: TextStyle(
        fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.40),
        fontSize: 12, fontWeight: FontWeight.w600))),
      Expanded(child: Text(value, style: const TextStyle(
        fontFamily: 'Ubuntu', color: _kWhite,
        fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final d = data;
    final nombre = (d?['nombre'] ?? '').toString();
    final telefono = (d?['telefono'] ?? '').toString();
    final cedula = (d?['cedula'] ?? '').toString();
    final email = (d?['email'] ?? '').toString();
    final vehiculos = (d?['vehiculos'] as List? ?? []).cast<Map<String, dynamic>>();
    final initial = nombre.isNotEmpty ? nombre[0].toUpperCase() : "?";
    // El backend solo entrega el detalle completo (y permite editar) si ya
    // hay un vehículo en común con este mecánico, o es superuser.
    final relacionado = d?['relacionado'] == true;

    return Theme(
      data: ThemeData(fontFamily: 'Ubuntu', textTheme: const TextTheme().apply(fontFamily: 'Ubuntu')),
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0D1E3A), Color(0xFF060B18)]),
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
          title: const Text("PROPIETARIO", style: TextStyle(
            fontFamily: 'Ubuntu', color: _kWhite,
            fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.5)),
          centerTitle: true,
          actions: [
            if (d != null && relacionado)
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: _kBlue, size: 20),
                tooltip: "Editar",
                onPressed: _editar,
              ),
          ],
        ),
        body: Stack(children: [
          Positioned.fill(child: const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF060B18), _kBg, Color(0xFF030509)]),
          ))),
          if (loading)
            Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue))
          else if (error != null)
            Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
                const SizedBox(height: 10),
                Text(error!, textAlign: TextAlign.center, style: TextStyle(
                  fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.5), fontSize: 12)),
                const SizedBox(height: 14),
                TextButton(onPressed: _cargar, child: const Text("Reintentar",
                  style: TextStyle(fontFamily: 'Ubuntu', color: _kBlue))),
              ]),
            ))
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kBlue.withOpacity(0.14))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 48, height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [Color(0xFF2AA0FF), _kBlueDark])),
                        child: Center(child: Text(initial, style: const TextStyle(
                          fontFamily: 'Ubuntu', color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 20)))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(nombre, style: const TextStyle(
                        fontFamily: 'Ubuntu', color: _kWhite,
                        fontWeight: FontWeight.w700, fontSize: 16))),
                    ]),
                    Divider(height: 22, color: _kBlue.withOpacity(0.08)),
                    _dato("Teléfono", telefono.isEmpty ? "—" : telefono),
                    _dato("Cédula", cedula.isEmpty ? "—" : cedula),
                    _dato("Email", email.isEmpty ? "—" : email),
                  ]),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Container(width: 3, height: 16,
                    decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  Text("Vehículos (${vehiculos.length})", style: const TextStyle(
                    fontFamily: 'Ubuntu', color: _kWhite,
                    fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
                const SizedBox(height: 10),
                if (vehiculos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text("Este propietario no tiene vehículos registrados.",
                      style: TextStyle(fontFamily: 'Ubuntu',
                        color: _kWhite.withOpacity(0.35), fontSize: 12)),
                  )
                else
                  ...vehiculos.map((v) => _vehiculoRow(v)),
              ],
            ),
        ]),
      ),
    );
  }

  Widget _vehiculoRow(Map<String, dynamic> v) {
    final placa = (v['placa'] ?? '').toString();
    final marcaModelo = [v['marca'], v['modelo']].where((s) => (s ?? '').toString().isNotEmpty).join(" ");
    final detalles = [v['anio'], v['color']].where((s) => (s ?? '').toString().isNotEmpty).join(" · ");

    return GestureDetector(
      onTap: () => _abrirVehiculo(placa),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _kBlue.withOpacity(0.14))),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _kBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kBlue.withOpacity(0.30))),
            child: Text(placa, style: const TextStyle(
              fontFamily: 'Ubuntu', color: _kBlue,
              fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(marcaModelo.isEmpty ? "Vehículo" : marcaModelo, style: const TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite, fontWeight: FontWeight.w600, fontSize: 13)),
            if (detalles.isNotEmpty)
              Text(detalles, style: TextStyle(fontFamily: 'Ubuntu',
                color: _kWhite.withOpacity(0.40), fontSize: 11)),
          ])),
          Icon(Icons.chevron_right_rounded, color: _kBlue.withOpacity(0.35), size: 18),
        ]),
      ),
    );
  }
}
