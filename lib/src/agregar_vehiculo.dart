import 'package:flutter/material.dart';
import 'api_service.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);

class AgregarVehiculoPage extends StatefulWidget {
  const AgregarVehiculoPage({super.key});
  @override
  State<AgregarVehiculoPage> createState() => _AgregarVehiculoPageState();
}

class _AgregarVehiculoPageState extends State<AgregarVehiculoPage> {
  // ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
  final marcaController        = TextEditingController();
  final modeloController       = TextEditingController();
  final placaController        = TextEditingController();
  final kilometrajeController  = TextEditingController();
  final ultimaVisitaController = TextEditingController();
  final anioController         = TextEditingController();
  final propietarioController  = TextEditingController();
  final telefonoController     = TextEditingController();
  final notaController         = TextEditingController();

  String? _colorSeleccionado;
  String? _tipoVehiculoSeleccionado;
  bool    _enviando = false;

  final _colores = const [
    "Blanco", "Negro", "Rojo", "Azul", "Plomo",
    "Plateado", "Amarillo", "Verde", "Otro",
  ];

  final _tiposVehiculo = const [
    "Sedán", "Hatchback", "SUV", "Pickup / Camioneta",
    "Coupé", "Van / Minivan", "Camión liviano", "Otro",
  ];

  @override
  void dispose() {
    marcaController.dispose();
    modeloController.dispose();
    placaController.dispose();
    kilometrajeController.dispose();
    ultimaVisitaController.dispose();
    anioController.dispose();
    propietarioController.dispose();
    telefonoController.dispose();
    notaController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final marca        = marcaController.text.trim();
    final modelo       = modeloController.text.trim();
    final placa        = placaController.text.trim().toUpperCase();
    final anioTxt      = anioController.text.trim();
    final propietario  = propietarioController.text.trim();
    final telefono     = telefonoController.text.trim();
    final kilometraje  = kilometrajeController.text.trim();
    final ultimaVisita = ultimaVisitaController.text.trim();
    final nota         = notaController.text.trim();
    final anio         = int.tryParse(anioTxt);

    if (marca.isEmpty || modelo.isEmpty || placa.isEmpty ||
        _tipoVehiculoSeleccionado == null || anio == null ||
        _colorSeleccionado == null || propietario.isEmpty ||
        telefono.isEmpty || kilometraje.isEmpty || ultimaVisita.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Completa todos los campos obligatorios',
          style: TextStyle(fontFamily: 'Ubuntu')),
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    setState(() => _enviando = true);

    final exito = await ApiService.agregarVehiculo(
      marca: marca, modelo: modelo, placa: placa,
      kilometraje: kilometraje, ultimaVisita: ultimaVisita,
      anio: anio, color: _colorSeleccionado!,
      propietarioNombre: propietario, propietarioTelefono: telefono,
      notaIngreso: nota.isEmpty ? null : nota,
      tipoVehiculo: _tipoVehiculoSeleccionado!,
    );

    setState(() => _enviando = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        exito ? 'Vehículo agregado correctamente' : 'Error al guardar',
        style: const TextStyle(fontFamily: 'Ubuntu')),
      backgroundColor: exito ? _kBlueDark : Colors.red.shade900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));

    if (exito) Navigator.pop(context);
  }
  // ═════════════════════════════════════════════════════════════════════════ //

  // ── Decoración de campos ───────────────────────────────────────────────────
  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      fontFamily: 'Ubuntu', color: _kBlue.withOpacity(0.85),
      fontSize: 13, letterSpacing: 0.6),
    prefixIcon: Icon(icon, color: _kBlue.withOpacity(0.75), size: 20),
    filled: true,
    fillColor: _kBlue.withOpacity(0.05),
    contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: BorderSide(color: _kBlue.withOpacity(0.25))),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: _kBlue, width: 1.5)),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: Colors.redAccent)),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
  );

  InputDecoration _decDrop(String label, IconData icon) => _dec(label, icon).copyWith(
    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
  );

  // ── Sección con título ─────────────────────────────────────────────────────
  Widget _section(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(children: [
      Container(width: 3, height: 16,
        decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Icon(icon, color: _kBlue, size: 15),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(
        fontFamily: 'Ubuntu', color: _kWhite,
        fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.3)),
    ]),
  );

  // ── Campo de texto ─────────────────────────────────────────────────────────
  Widget _field(TextEditingController ctrl, String label, IconData icon, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
  }) => TextField(
    controller: ctrl,
    keyboardType: keyboard,
    maxLines: maxLines,
    maxLength: maxLength,
    style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
    decoration: _dec(label, icon),
  );

  // ── Selector de fecha (evita que escriban mal el formato) ────────────────
  Future<void> _elegirUltimaVisita() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000, 1, 1),
      lastDate: now,
      helpText: "Última visita al taller",
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _kBlue, onPrimary: Colors.white,
            surface: Color(0xFF0D1420), onSurface: _kWhite,
          ),
          dialogBackgroundColor: const Color(0xFF0D1420),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    setState(() => ultimaVisitaController.text = "$y-$m-$d");
  }

  Widget _dateField(TextEditingController ctrl, String label, IconData icon,
      VoidCallback onTap) => TextField(
    controller: ctrl,
    readOnly: true,
    onTap: onTap,
    style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
    decoration: _dec(label, icon).copyWith(
      suffixIcon: Icon(Icons.arrow_drop_down_rounded,
        color: _kBlue.withOpacity(0.7)),
    ),
  );

  // ── Dropdown ───────────────────────────────────────────────────────────────
  Widget _dropdown<T>(String label, IconData icon, T? value,
      List<T> items, ValueChanged<T?> onChanged) =>
      DropdownButtonFormField<T>(
        value: value,
        dropdownColor: const Color(0xFF0D1420),
        style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: _kBlue.withOpacity(0.7)),
        decoration: _decDrop(label, icon),
        items: items.map((t) => DropdownMenuItem<T>(
          value: t,
          child: Text(t.toString(), style: const TextStyle(
            fontFamily: 'Ubuntu', color: _kWhite, fontSize: 13)),
        )).toList(),
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
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
            onPressed: _enviando ? null : () => Navigator.pop(context),
          ),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
              decoration: const BoxDecoration(color: _kBlue, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text("AGREGAR VEHÍCULO", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 2)),
          ]),
          centerTitle: true,
        ),

        // ── Body ────────────────────────────────────────────────────────────
        body: Stack(children: [
          Positioned.fill(child: const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF060B18), _kBg, Color(0xFF030509)]),
          ))),
          Positioned(top: -100, right: -80, child: Container(
            width: 260, height: 260,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_kBlue.withOpacity(0.07), Colors.transparent])),
          )),

          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Sección: Identificación ────────────────────────────────
              _section("Identificación", Icons.directions_car_rounded),
              _field(marcaController,  "Marca",  Icons.branding_watermark_rounded),
              const SizedBox(height: 12),
              _field(modeloController, "Modelo", Icons.car_repair_rounded),
              const SizedBox(height: 12),
              _field(placaController,  "Placa",  Icons.pin_rounded),
              const SizedBox(height: 12),
              _dropdown("Tipo de vehículo", Icons.category_rounded,
                _tipoVehiculoSeleccionado, _tiposVehiculo,
                (v) => setState(() => _tipoVehiculoSeleccionado = v)),

              // ── Sección: Detalles ──────────────────────────────────────
              _section("Detalles del vehículo", Icons.tune_rounded),
              Row(children: [
                Expanded(child: _field(anioController, "Año", Icons.calendar_today_rounded,
                  keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _dropdown("Color", Icons.palette_rounded,
                  _colorSeleccionado, _colores,
                  (v) => setState(() => _colorSeleccionado = v))),
              ]),
              const SizedBox(height: 12),
              _field(kilometrajeController, "Kilometraje", Icons.speed_rounded,
                keyboard: TextInputType.number),
              const SizedBox(height: 12),
              _dateField(ultimaVisitaController, "Última visita",
                Icons.event_rounded, _elegirUltimaVisita),

              // ── Sección: Propietario ───────────────────────────────────
              _section("Propietario", Icons.person_rounded),
              _field(propietarioController, "Nombre del propietario",
                Icons.badge_outlined),
              const SizedBox(height: 12),
              _field(telefonoController, "Teléfono", Icons.phone_rounded,
                keyboard: TextInputType.phone),

              // ── Sección: Notas ─────────────────────────────────────────
              _section("Nota de ingreso", Icons.notes_rounded),
              _field(notaController, "Nota (opcional)", Icons.edit_note_rounded,
                maxLines: 3, maxLength: 300),

              const SizedBox(height: 28),

              // ── Botones ────────────────────────────────────────────────
              Row(children: [
                // Cancelar
                Expanded(child: GestureDetector(
                  onTap: _enviando ? null : () => Navigator.pop(context),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBlue.withOpacity(0.28)),
                      color: _kBlue.withOpacity(0.05),
                    ),
                    child: Center(child: Text("CANCELAR", style: TextStyle(
                      fontFamily: 'Ubuntu',
                      color: _kWhite.withOpacity(0.50),
                      fontWeight: FontWeight.w700,
                      fontSize: 13, letterSpacing: 1.5))),
                  ),
                )),

                const SizedBox(width: 12),

                // Guardar
                Expanded(child: GestureDetector(
                  onTap: _enviando ? null : _guardar,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: _enviando ? null
                          : const LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [Color(0xFF2AA0FF), _kBlueDark]),
                      color: _enviando ? Colors.white10 : null,
                      boxShadow: _enviando ? null : [BoxShadow(
                        color: _kBlue.withOpacity(0.36),
                        blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: Center(child: _enviando
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                        : const Text("GUARDAR", style: TextStyle(
                            fontFamily: 'Ubuntu', color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13, letterSpacing: 2))),
                  ),
                )),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}