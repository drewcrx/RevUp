import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);

const _kOtro = "Otro";

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
  final cilindrajeController   = TextEditingController();

  String? _colorSeleccionado;
  String? _tipoVehiculoSeleccionado;
  String? _combustibleSeleccionado;
  String? _transmisionSeleccionada;
  bool    _enviando = false;

  // ── Catálogos (Fase 1) ────────────────────────────────────────────────────
  bool _cargandoCatalogos = true;
  List<Map<String, dynamic>> _marcasCat = [];
  List<Map<String, dynamic>> _modelosCat = [];
  List<String> _coloresCat = [];
  List<String> _tiposCat = [];
  List<String> _combustiblesCat = [];
  List<String> _transmisionesCat = [];

  String? _marcaSeleccionada;
  String? _modeloSeleccionado;
  bool get _marcaEsOtro => _marcaSeleccionada == _kOtro;
  bool get _modeloEsOtro => _modeloSeleccionado == _kOtro;

  // ── Propietario (normalizado — puede elegir uno existente o escribir uno nuevo) ──
  int? _propietarioIdSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    setState(() => _cargandoCatalogos = true);
    try {
      final marcasF        = ApiService.obtenerMarcas();
      final coloresF       = ApiService.obtenerCatalogoItems('color');
      final tiposF         = ApiService.obtenerCatalogoItems('tipo_vehiculo');
      final combustiblesF  = ApiService.obtenerCatalogoItems('combustible');
      final transmisionesF = ApiService.obtenerCatalogoItems('transmision');

      final marcas        = await marcasF;
      final colores        = await coloresF;
      final tipos           = await tiposF;
      final combustibles     = await combustiblesF;
      final transmisiones    = await transmisionesF;

      if (!mounted) return;
      setState(() {
        _marcasCat = marcas;
        _coloresCat = colores;
        _tiposCat = tipos;
        _combustiblesCat = combustibles;
        _transmisionesCat = transmisiones;
      });
    } catch (_) {
      // Si los catálogos no cargan, el usuario igual puede escribir todo
      // manualmente eligiendo "Otro" — no bloquea el formulario.
    } finally {
      if (mounted) setState(() => _cargandoCatalogos = false);
    }
  }

  Future<void> _onMarcaChanged(String? v) async {
    setState(() {
      _marcaSeleccionada = v;
      _modeloSeleccionado = null;
      _modelosCat = [];
      modeloController.clear();
      if (v != null && v != _kOtro) {
        marcaController.text = v;
      } else {
        marcaController.clear();
      }
    });

    if (v != null && v != _kOtro) {
      final marca = _marcasCat.firstWhere((m) => m['nombre'] == v,
        orElse: () => {});
      final marcaId = marca['id'];
      if (marcaId != null) {
        try {
          final modelos = await ApiService.obtenerModelos(marcaId as int);
          if (!mounted) return;
          setState(() => _modelosCat = modelos);
        } catch (_) {}
      }
    }
  }

  void _onModeloChanged(String? v) {
    setState(() {
      _modeloSeleccionado = v;
      if (v != null && v != _kOtro) {
        modeloController.text = v;
      } else {
        modeloController.clear();
      }
    });
  }

  Timer? _busquedaDebounce;

  Future<void> _buscarPropietarioExistente() async {
    final buscarCtrl = TextEditingController();
    List<Map<String, dynamic>> resultados = [];
    bool cargando = true;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) {
          Future<void> buscar(String q) async {
            setS(() => cargando = true);
            try {
              final r = await ApiService.buscarPropietarios(q);
              resultados = r;
            } catch (_) {
              resultados = [];
            } finally {
              if (ctx2.mounted) setS(() => cargando = false);
            }
          }

          if (cargando && resultados.isEmpty) {
            // primera carga (lista inicial sin filtro)
            buscar("");
          }

          return Container(
            padding: EdgeInsets.only(
              left: 18, right: 18, top: 18,
              bottom: MediaQuery.of(ctx2).viewInsets.bottom + 18),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx2).size.height * 0.75),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1420),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.person_search_rounded, color: _kBlue, size: 18),
                const SizedBox(width: 8),
                const Text("Buscar propietario", style: TextStyle(
                  fontFamily: 'Ubuntu', color: _kWhite,
                  fontWeight: FontWeight.w700, fontSize: 15)),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: buscarCtrl,
                autofocus: true,
                style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
                decoration: _dec("Nombre o teléfono", Icons.search_rounded),
                onChanged: (v) {
                  _busquedaDebounce?.cancel();
                  _busquedaDebounce = Timer(const Duration(milliseconds: 350),
                    () => buscar(v.trim()));
                },
              ),
              const SizedBox(height: 10),
              Flexible(
                child: cargando
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue))))
                    : resultados.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text("Sin resultados — puedes escribir uno nuevo abajo",
                              style: TextStyle(fontFamily: 'Ubuntu',
                                color: _kWhite.withOpacity(0.35), fontSize: 12)))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: resultados.length,
                            itemBuilder: (_, i) {
                              final p = resultados[i];
                              final nombre = (p['nombre'] ?? '').toString();
                              final tel = (p['telefono'] ?? '').toString();
                              final nVeh = int.tryParse((p['vehiculos_count'] ?? '0').toString()) ?? 0;
                              return ListTile(
                                dense: true,
                                leading: Icon(Icons.person_rounded, color: _kBlue.withOpacity(0.6), size: 20),
                                title: Text(nombre, style: const TextStyle(
                                  fontFamily: 'Ubuntu', color: _kWhite, fontSize: 13)),
                                subtitle: Text(
                                  [if (tel.isNotEmpty) tel, "$nVeh vehículo${nVeh == 1 ? '' : 's'}"].join(" · "),
                                  style: TextStyle(fontFamily: 'Ubuntu',
                                    color: _kWhite.withOpacity(0.35), fontSize: 11)),
                                onTap: () {
                                  setState(() {
                                    _propietarioIdSeleccionado = int.tryParse(p['id'].toString());
                                    propietarioController.text = nombre;
                                    telefonoController.text = tel;
                                  });
                                  Navigator.pop(ctx2);
                                },
                              );
                            },
                          ),
              ),
            ]),
          );
        },
      ),
    );
    buscarCtrl.dispose();
  }

  @override
  void dispose() {
    _busquedaDebounce?.cancel();
    marcaController.dispose();
    modeloController.dispose();
    placaController.dispose();
    kilometrajeController.dispose();
    ultimaVisitaController.dispose();
    anioController.dispose();
    propietarioController.dispose();
    telefonoController.dispose();
    notaController.dispose();
    cilindrajeController.dispose();
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
    final cilindraje   = cilindrajeController.text.trim();
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
      propietarioId: _propietarioIdSeleccionado,
      propietarioNombre: propietario, propietarioTelefono: telefono,
      notaIngreso: nota.isEmpty ? null : nota,
      tipoVehiculo: _tipoVehiculoSeleccionado!,
      tipoCombustible: _combustibleSeleccionado,
      transmision: _transmisionSeleccionada,
      cilindraje: cilindraje.isEmpty ? null : cilindraje,
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
            fontFamily: 'Ubuntu', color: _kWhite, fontSize: 13),
            overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: onChanged,
      );

  // ── Marca / Modelo (dependientes, con opción "Otro" para texto libre) ──────
  Widget _campoMarca() {
    if (_marcaEsOtro) {
      return _field(marcaController, "Marca (escríbela)",
        Icons.branding_watermark_rounded);
    }
    return _dropdown<String>("Marca", Icons.branding_watermark_rounded,
      _marcaSeleccionada,
      [..._marcasCat.map((m) => m['nombre'] as String), _kOtro],
      _onMarcaChanged);
  }

  Widget _campoModelo() {
    if (_marcaEsOtro || _modeloEsOtro) {
      return _field(modeloController, "Modelo (escríbelo)",
        Icons.car_repair_rounded);
    }
    if (_marcaSeleccionada == null) {
      return _dropdown<String>("Modelo (elige marca primero)",
        Icons.car_repair_rounded, null, const [], (_) {});
    }
    return _dropdown<String>("Modelo", Icons.car_repair_rounded,
      _modeloSeleccionado,
      [..._modelosCat.map((m) => m['nombre'] as String), _kOtro],
      _onModeloChanged);
  }

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

          if (_cargandoCatalogos)
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 30, height: 30,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)),
              const SizedBox(height: 12),
              Text("Cargando catálogos...", style: TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.30), fontSize: 12)),
            ]))
          else
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Sección: Identificación ────────────────────────────────
              _section("Identificación", Icons.directions_car_rounded),
              _campoMarca(),
              const SizedBox(height: 12),
              _campoModelo(),
              const SizedBox(height: 12),
              _field(placaController,  "Placa",  Icons.pin_rounded),
              const SizedBox(height: 12),
              _dropdown("Tipo de vehículo", Icons.category_rounded,
                _tipoVehiculoSeleccionado, _tiposCat,
                (v) => setState(() => _tipoVehiculoSeleccionado = v)),

              // ── Sección: Detalles ──────────────────────────────────────
              _section("Detalles del vehículo", Icons.tune_rounded),
              Row(children: [
                Expanded(child: _field(anioController, "Año", Icons.calendar_today_rounded,
                  keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _dropdown("Color", Icons.palette_rounded,
                  _colorSeleccionado, _coloresCat,
                  (v) => setState(() => _colorSeleccionado = v))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _dropdown("Combustible", Icons.local_gas_station_rounded,
                  _combustibleSeleccionado, _combustiblesCat,
                  (v) => setState(() => _combustibleSeleccionado = v))),
                const SizedBox(width: 12),
                Expanded(child: _dropdown("Transmisión", Icons.settings_rounded,
                  _transmisionSeleccionada, _transmisionesCat,
                  (v) => setState(() => _transmisionSeleccionada = v))),
              ]),
              const SizedBox(height: 12),
              _field(cilindrajeController, "Cilindraje (opcional)",
                Icons.speed_outlined),
              const SizedBox(height: 12),
              _field(kilometrajeController, "Kilometraje", Icons.speed_rounded,
                keyboard: TextInputType.number),
              const SizedBox(height: 12),
              _dateField(ultimaVisitaController, "Última visita",
                Icons.event_rounded, _elegirUltimaVisita),

              // ── Sección: Propietario ───────────────────────────────────
              _section("Propietario", Icons.person_rounded),
              GestureDetector(
                onTap: _buscarPropietarioExistente,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _kBlue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBlue.withOpacity(0.22)),
                  ),
                  child: Row(children: [
                    Icon(Icons.person_search_rounded, color: _kBlue.withOpacity(0.85), size: 17),
                    const SizedBox(width: 8),
                    Text(_propietarioIdSeleccionado != null
                        ? "Propietario existente seleccionado"
                        : "Buscar propietario existente",
                      style: TextStyle(fontFamily: 'Ubuntu',
                        color: _propietarioIdSeleccionado != null ? _kBlue : _kWhite.withOpacity(0.55),
                        fontWeight: FontWeight.w700, fontSize: 12)),
                    const Spacer(),
                    if (_propietarioIdSeleccionado != null)
                      Icon(Icons.check_circle_rounded, color: _kBlue.withOpacity(0.8), size: 16),
                  ]),
                ),
              ),
              TextField(
                controller: propietarioController,
                onChanged: (_) => setState(() => _propietarioIdSeleccionado = null),
                style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
                decoration: _dec("Nombre del propietario", Icons.badge_outlined),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telefonoController,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() => _propietarioIdSeleccionado = null),
                style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
                decoration: _dec("Teléfono", Icons.phone_rounded),
              ),

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
