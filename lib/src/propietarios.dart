import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'detalle_propietario.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);
const _kCard     = Color(0xFF080E1A);

class PropietariosPage extends StatefulWidget {
  const PropietariosPage({super.key});
  @override
  State<PropietariosPage> createState() => _PropietariosPageState();
}

class _PropietariosPageState extends State<PropietariosPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool loading = true;
  String? error;
  List<Map<String, dynamic>> propietarios = [];

  @override
  void initState() {
    super.initState();
    _buscar("");
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String q) async {
    setState(() { loading = true; error = null; });
    try {
      final r = await ApiService.buscarPropietarios(q);
      if (!mounted) return;
      setState(() => propietarios = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _buscar(v.trim()));
  }

  Future<void> _abrirDetalle(int id) async {
    await Navigator.push(context,
      MaterialPageRoute(builder: (_) => DetallePropietarioPage(propietarioId: id)));
    _buscar(_searchCtrl.text.trim());
  }

  Future<void> _crearPropietario() async {
    final nombreCtrl = TextEditingController();
    final telCtrl = TextEditingController();
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
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Nuevo propietario", style: TextStyle(fontFamily: 'Ubuntu',
                color: _kWhite, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 16),
              TextField(
                controller: nombreCtrl, autofocus: true,
                style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
                decoration: InputDecoration(
                  labelText: "Nombre",
                  labelStyle: TextStyle(fontFamily: 'Ubuntu', color: _kBlue.withOpacity(0.8), fontSize: 12),
                  filled: true, fillColor: _kBlue.withOpacity(0.05),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _kBlue.withOpacity(0.22))),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBlue, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telCtrl, keyboardType: TextInputType.phone,
                style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
                decoration: InputDecoration(
                  labelText: "Teléfono (opcional)",
                  labelStyle: TextStyle(fontFamily: 'Ubuntu', color: _kBlue.withOpacity(0.8), fontSize: 12),
                  filled: true, fillColor: _kBlue.withOpacity(0.05),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _kBlue.withOpacity(0.22))),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBlue, width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 44,
                child: GestureDetector(
                  onTap: guardando ? null : () async {
                    final n = nombreCtrl.text.trim();
                    if (n.isEmpty) return;
                    setS(() => guardando = true);
                    try {
                      await ApiService.crearPropietario(
                        nombre: n, telefono: telCtrl.text.trim());
                      if (!mounted) return;
                      Navigator.pop(ctx2);
                      _buscar(_searchCtrl.text.trim());
                    } catch (e) {
                      setS(() => guardando = false);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(colors: [Color(0xFF2AA0FF), _kBlueDark])),
                    child: Center(child: guardando
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("CREAR", style: TextStyle(
                            fontFamily: 'Ubuntu', color: Colors.white,
                            fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1))),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    nombreCtrl.dispose();
    telCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
              decoration: const BoxDecoration(color: _kBlue, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text("CLIENTES", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 2)),
          ]),
          centerTitle: true,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _crearPropietario,
          backgroundColor: _kBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.person_add_rounded),
          label: const Text("Nuevo", style: TextStyle(
            fontFamily: 'Ubuntu', fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        body: Stack(children: [
          Positioned.fill(child: const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF060B18), _kBg, Color(0xFF030509)]),
          ))),
          Positioned(top: -120, right: -80, child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_kBlue.withOpacity(0.08), Colors.transparent])),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: _kBlue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBlue.withOpacity(0.28), width: 1),
                ),
                child: Row(children: [
                  Icon(Icons.search_rounded, color: _kBlue.withOpacity(0.7), size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Buscar por nombre, teléfono o cédula...",
                      hintStyle: TextStyle(fontFamily: 'Ubuntu',
                        color: _kWhite.withOpacity(0.28), fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  )),
                ]),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: loading
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 32, height: 32,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: _kBlue)),
                        const SizedBox(height: 12),
                        Text("Buscando...", style: TextStyle(
                          fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.35), fontSize: 13)),
                      ]))
                    : error != null
                        ? Center(child: Text(error!, style: TextStyle(
                            fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.5), fontSize: 12)))
                        : propietarios.isEmpty
                            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.people_outline_rounded,
                                  color: _kWhite.withOpacity(0.15), size: 40),
                                const SizedBox(height: 10),
                                Text("Sin propietarios registrados todavía",
                                  style: TextStyle(fontFamily: 'Ubuntu',
                                    color: _kWhite.withOpacity(0.35), fontSize: 13)),
                              ]))
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 90),
                                itemCount: propietarios.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, i) => _propietarioCard(propietarios[i]),
                              ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _propietarioCard(Map<String, dynamic> p) {
    final id = int.tryParse((p['id'] ?? '').toString());
    final nombre = (p['nombre'] ?? '').toString();
    final tel = (p['telefono'] ?? '').toString();
    final nVeh = int.tryParse((p['vehiculos_count'] ?? '0').toString()) ?? 0;
    final initial = nombre.isNotEmpty ? nombre[0].toUpperCase() : "?";

    return GestureDetector(
      onTap: id == null ? null : () => _abrirDetalle(id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBlue.withOpacity(0.14)),
        ),
        child: Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF2AA0FF), _kBlueDark]),
            ),
            child: Center(child: Text(initial, style: const TextStyle(
              fontFamily: 'Ubuntu', color: Colors.white,
              fontWeight: FontWeight.w800, fontSize: 16)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: const TextStyle(fontFamily: 'Ubuntu',
              color: _kWhite, fontWeight: FontWeight.w700, fontSize: 14)),
            if (tel.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.phone_rounded, color: _kWhite.withOpacity(0.35), size: 12),
                const SizedBox(width: 4),
                Text(tel, style: TextStyle(fontFamily: 'Ubuntu',
                  color: _kWhite.withOpacity(0.45), fontSize: 12)),
              ]),
            ],
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _kBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.directions_car_rounded, color: _kBlue.withOpacity(0.8), size: 12),
              const SizedBox(width: 4),
              Text("$nVeh", style: const TextStyle(fontFamily: 'Ubuntu',
                color: _kBlue, fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: _kBlue.withOpacity(0.35), size: 18),
        ]),
      ),
    );
  }
}
