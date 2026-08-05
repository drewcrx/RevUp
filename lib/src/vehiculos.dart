import 'package:flutter/material.dart';
import 'vehiculo_model.dart';
import 'api_service.dart';
import 'detalle_vehiculo.dart';
import 'nueva_orden.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);

class VehiculosPage extends StatefulWidget {
  const VehiculosPage({super.key});
  @override
  State<VehiculosPage> createState() => _VehiculosPageState();
}

class _VehiculosPageState extends State<VehiculosPage> {
  // ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
  late Future<List<Vehiculo>> _vehiculosFuture;

  final TextEditingController _searchCtrl = TextEditingController();
  String _fMarca = "Todos";
  String _fColor = "Todos";
  String _fAnio  = "Todos";
  String _fTipo  = "Todos";

  List<Vehiculo> _all      = [];
  List<Vehiculo> _filtered = [];

  List<String> _marcas  = const ["Todos"];
  List<String> _colores = const ["Todos"];
  List<String> _anios   = const ["Todos"];
  List<String> _tipos   = const ["Todos"];

  bool _initializedFromSnapshot = false;

  @override
  void initState() {
    super.initState();
    _loadVehiculos();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilters);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadVehiculos() {
    _vehiculosFuture = ApiService.obtenerVehiculos();
    _initializedFromSnapshot = false;
  }

  Future<void> _refrescarLista() async => setState(() => _loadVehiculos());

  Future<void> _irACrearOTDesdeVehiculo(Vehiculo v) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => NuevaOrdenPage(placaInicial: v.placa)));
    await _refrescarLista();
  }

  String _safeLower(String? s) => (s ?? "").trim().toLowerCase();
  String _getColor(Vehiculo v)       { try { return ((v as dynamic).color?.toString()        ?? '').trim(); } catch (_) { return ''; } }
  String _getTipo(Vehiculo v)        { try { return ((v as dynamic).tipoVehiculo?.toString() ?? '').trim(); } catch (_) { return ''; } }
  String _getPropietario(Vehiculo v) { try { return ((v as dynamic).propietarioNombre?.toString()  ?? '').trim(); } catch (_) { return ''; } }
  String _getTelefono(Vehiculo v)    { try { return ((v as dynamic).propietarioTelefono?.toString() ?? '').trim(); } catch (_) { return ''; } }
  String _getNotaIngreso(Vehiculo v) { try { return ((v as dynamic).notaIngreso?.toString()  ?? '').trim(); } catch (_) { return ''; } }
  String _getCombustible(Vehiculo v) { try { return ((v as dynamic).tipoCombustible?.toString() ?? '').trim(); } catch (_) { return ''; } }
  String _getTransmision(Vehiculo v) { try { return ((v as dynamic).transmision?.toString()     ?? '').trim(); } catch (_) { return ''; } }
  String _getCilindraje(Vehiculo v)  { try { return ((v as dynamic).cilindraje?.toString()      ?? '').trim(); } catch (_) { return ''; } }
  int? _getAnio(Vehiculo v) {
    try {
      final a = (v as dynamic).anio;
      if (a is int) return a;
      return int.tryParse((a ?? "").toString());
    } catch (_) { return null; }
  }

  String _title(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t.split(" ").map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(" ");
  }

  void _buildFilterOptionsNoSetState(List<Vehiculo> lista) {
    final marcas  = <String>{};
    final colores = <String>{};
    final anios   = <String>{};
    final tipos   = <String>{};
    for (final v in lista) {
      final m = v.marca.trim(); if (m.isNotEmpty) marcas.add(_title(m));
      final t = _getTipo(v).trim();  if (t.isNotEmpty) tipos.add(_title(t));
      final c = _getColor(v).trim(); if (c.isNotEmpty) colores.add(_title(c));
      final a = _getAnio(v); if (a != null && a > 1900 && a < 3000) anios.add(a.toString());
    }
    _marcas  = ["Todos", ...(marcas.toList()..sort())];
    _tipos   = ["Todos", ...(tipos.toList()..sort())];
    _colores = ["Todos", ...(colores.toList()..sort())];
    _anios   = ["Todos", ...(anios.toList()..sort((a, b) => int.parse(b).compareTo(int.parse(a))))];
    if (!_marcas.contains(_fMarca))  _fMarca = "Todos";
    if (!_tipos.contains(_fTipo))    _fTipo  = "Todos";
    if (!_colores.contains(_fColor)) _fColor = "Todos";
    if (!_anios.contains(_fAnio))    _fAnio  = "Todos";
  }

  void _applyFilters() {
    final q = _safeLower(_searchCtrl.text);
    List<Vehiculo> res = List<Vehiculo>.from(_all);
    if (_fMarca != "Todos") { final fm = _safeLower(_fMarca); res = res.where((v) => _safeLower(v.marca) == fm).toList(); }
    if (_fTipo  != "Todos") { final ft = _safeLower(_fTipo);  res = res.where((v) => _safeLower(_getTipo(v)) == ft).toList(); }
    if (_fColor != "Todos") { final fc = _safeLower(_fColor); res = res.where((v) => _safeLower(_getColor(v)) == fc).toList(); }
    if (_fAnio  != "Todos") { final fa = int.tryParse(_fAnio); res = res.where((v) => _getAnio(v) == fa).toList(); }
    if (q.isNotEmpty) {
      res = res.where((v) => [
        v.marca, v.modelo, v.placa, _getColor(v), _getTipo(v),
        _getPropietario(v), _getTelefono(v), _getNotaIngreso(v),
        _getCombustible(v), _getTransmision(v), _getCilindraje(v),
        (_getAnio(v) ?? "").toString(),
      ].map((e) => _safeLower(e)).any((f) => f.contains(q))).toList();
    }
    res.sort((a, b) => a.placa.toUpperCase().compareTo(b.placa.toUpperCase()));
    if (!mounted) return;
    setState(() => _filtered = res);
  }

  void _resetFilters() {
    _searchCtrl.clear();
    setState(() { _fMarca = "Todos"; _fTipo = "Todos"; _fColor = "Todos"; _fAnio = "Todos"; _filtered = List<Vehiculo>.from(_all); });
  }

  bool get _hasActiveFilters =>
      _searchCtrl.text.trim().isNotEmpty || _fMarca != "Todos" || _fColor != "Todos" || _fAnio != "Todos" || _fTipo != "Todos";
  // ═════════════════════════════════════════════════════════════════════════ //

  // ── Dropdown estilizado ────────────────────────────────────────────────────
  Widget _drop(String label, String value, List<String> items, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _kBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBlue.withOpacity(0.25), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : "Todos",
          isExpanded: true,
          dropdownColor: const Color(0xFF0D1420),
          iconEnabledColor: _kBlue,
          style: TextStyle(fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.85), fontSize: 12),
          items: items.map((e) => DropdownMenuItem<String>(
            value: e,
            child: Text("$label: $e", overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Ubuntu', color: e == "Todos" ? _kWhite.withOpacity(0.45) : _kWhite)),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }

  // ── Barra de búsqueda + filtros ────────────────────────────────────────────
  Widget _buildSearchAndFilters() {
    return Column(children: [
      // Search bar
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
            style: TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
            decoration: InputDecoration(
              hintText: "Placa, marca, modelo, propietario...",
              hintStyle: TextStyle(fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.28), fontSize: 13),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          )),
          if (_hasActiveFilters)
            GestureDetector(
              onTap: _resetFilters,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kBlue.withOpacity(0.12),
                ),
                child: const Icon(Icons.close_rounded, color: _kBlue, size: 16),
              ),
            ),
        ]),
      ),

      const SizedBox(height: 10),

      // Dropdowns en 2×2
      Row(children: [
        Expanded(child: _drop("Marca", _fMarca, _marcas, (v) { setState(() => _fMarca = v); _applyFilters(); })),
        const SizedBox(width: 8),
        Expanded(child: _drop("Año",   _fAnio,  _anios,  (v) { setState(() => _fAnio  = v); _applyFilters(); })),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _drop("Color", _fColor, _colores, (v) { setState(() => _fColor = v); _applyFilters(); })),
        const SizedBox(width: 8),
        Expanded(child: _drop("Tipo",  _fTipo,  _tipos,   (v) { setState(() => _fTipo  = v); _applyFilters(); })),
      ]),

      const SizedBox(height: 10),

      // Contador de resultados
      Row(children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(
          color: _kBlue, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(
          "${_filtered.length} de ${_all.length} vehículos",
          style: TextStyle(fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.40), fontSize: 12),
        ),
        if (_hasActiveFilters) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _kBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _kBlue.withOpacity(0.30)),
            ),
            child: const Text("Filtros activos", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kBlue, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(fontFamily: 'Ubuntu', textTheme: const TextTheme().apply(fontFamily: 'Ubuntu')),
      child: Scaffold(
        backgroundColor: _kBg,

        // ── AppBar ────────────────────────────────────────────────────────
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0D1E3A), Color(0xFF060B18)],
            ),
          )),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent, _kBlue.withOpacity(0.35), Colors.transparent,
              ]),
            )),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kBlue, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: _kBlue, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text("VEHÍCULOS", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 2,
            )),
          ]),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _kBlue, size: 22),
              tooltip: "Refrescar",
              onPressed: _refrescarLista,
            ),
          ],
        ),

        // ── FAB: agregar vehículo ─────────────────────────────────────────
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.pushNamed(context, '/agregar_vehiculo');
            _refrescarLista();
          },
          backgroundColor: _kBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.add_rounded),
          label: const Text("Agregar", style: TextStyle(
            fontFamily: 'Ubuntu', fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),

        body: Stack(children: [
          // Fondo
          Positioned.fill(child: const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF060B18), _kBg, Color(0xFF030509)],
            ),
          ))),
          Positioned(top: -120, right: -80, child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_kBlue.withOpacity(0.08), Colors.transparent])),
          )),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              _buildSearchAndFilters(),
              const SizedBox(height: 14),

              Expanded(
                child: FutureBuilder<List<Vehiculo>>(
                  future: _vehiculosFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 32, height: 32,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: _kBlue)),
                        const SizedBox(height: 12),
                        Text("Cargando vehículos...", style: TextStyle(
                          fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.35), fontSize: 13)),
                      ]));
                    }

                    if (snapshot.hasError) {
                      return Center(child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Error: ${snapshot.error}',
                            style: const TextStyle(fontFamily: 'Ubuntu', color: Colors.redAccent, fontSize: 13))),
                        ]),
                      ));
                    }

                    final lista = snapshot.data ?? [];

                    if (!_initializedFromSnapshot) {
                      _initializedFromSnapshot = true;
                      _all = List<Vehiculo>.from(lista);
                      _filtered = List<Vehiculo>.from(lista);
                      _buildFilterOptionsNoSetState(lista);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _applyFilters();
                      });
                    }

                    if (_filtered.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: _refrescarLista,
                        color: _kBlue,
                        backgroundColor: const Color(0xFF0D1420),
                        child: ListView(children: [
                          const SizedBox(height: 80),
                          Center(child: Column(children: [
                            Icon(Icons.directions_car_rounded, color: _kBlue.withOpacity(0.25), size: 48),
                            const SizedBox(height: 12),
                            Text("No hay resultados con esos filtros",
                              style: TextStyle(fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.35), fontSize: 13)),
                          ])),
                        ]),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _refrescarLista,
                      color: _kBlue,
                      backgroundColor: const Color(0xFF0D1420),
                      child: ListView.builder(
                        itemCount: _filtered.length,
                        padding: const EdgeInsets.only(bottom: 100),
                        itemBuilder: (context, index) {
                          final v = _filtered[index];
                          return _VehiculoItem(
                            vehiculo: v,
                            onEliminar: _refrescarLista,
                            onCrearOT: () => _irACrearOTDesdeVehiculo(v),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Item de vehículo ─────────────────────────────────────────────────────────
class _VehiculoItem extends StatelessWidget {
  final Vehiculo vehiculo;
  final Future<void> Function() onEliminar;
  final VoidCallback onCrearOT;

  const _VehiculoItem({
    required this.vehiculo,
    required this.onEliminar,
    required this.onCrearOT,
  });

  // ── Helpers (idénticos al original) ────────────────────────────────────────
  String _getColor(Vehiculo v)       { try { return ((v as dynamic).color?.toString()       ?? '').trim(); } catch (_) { return ''; } }
  String _getPropietario(Vehiculo v) { try { return ((v as dynamic).propietarioNombre?.toString() ?? '').trim(); } catch (_) { return ''; } }
  String _getTelefono(Vehiculo v)    { try { return ((v as dynamic).propietarioTelefono?.toString() ?? '').trim(); } catch (_) { return ''; } }
  int? _getAnio(Vehiculo v) {
    try {
      final a = (v as dynamic).anio;
      if (a is int) return a;
      return int.tryParse((a ?? "").toString());
    } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    final color       = _getColor(vehiculo);
    final propietario = _getPropietario(vehiculo);
    final tel         = _getTelefono(vehiculo);
    final anio        = _getAnio(vehiculo);

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DetalleVehiculoPage(vehiculo: vehiculo))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kBlue.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBlue.withOpacity(0.14), width: 1),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

          // Ícono del vehículo
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF2AA0FF), _kBlueDark],
              ),
              boxShadow: [BoxShadow(color: _kBlue.withOpacity(0.25), blurRadius: 10)],
            ),
            child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 22),
          ),

          const SizedBox(width: 12),

          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Marca + modelo + año
            Text(
              '${vehiculo.marca} ${vehiculo.modelo}${anio != null ? " · $anio" : ""}',
              style: const TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite,
                fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            // Placa destacada
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kBlue.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _kBlue.withOpacity(0.30), width: 1),
                ),
                child: Text(vehiculo.placa, style: const TextStyle(
                  fontFamily: 'Ubuntu', color: _kBlue,
                  fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1,
                )),
              ),
              if (color.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(color, style: TextStyle(
                  fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.45), fontSize: 12)),
              ],
            ]),
            if (propietario.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.person_outline_rounded, color: _kWhite.withOpacity(0.30), size: 13),
                const SizedBox(width: 4),
                Expanded(child: Text(
                  '$propietario${tel.isNotEmpty ? "  ·  $tel" : ""}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.38), fontSize: 12),
                )),
              ]),
            ],
          ])),

          const SizedBox(width: 8),

          // Acciones
          Column(mainAxisSize: MainAxisSize.min, children: [
            // Botón OT
            GestureDetector(
              onTap: onCrearOT,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2AA0FF), _kBlueDark]),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: _kBlue.withOpacity(0.30), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: const Text("OT", style: TextStyle(
                  fontFamily: 'Ubuntu', color: Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
              ),
            ),
            const SizedBox(height: 6),
            // Botón eliminar
            GestureDetector(
              onTap: () async {
                final confirmado = await showDialog<bool>(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1420),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kBlue.withOpacity(0.18), width: 1),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
                          const SizedBox(width: 8),
                          const Text("Confirmar eliminación", style: TextStyle(
                            fontFamily: 'Ubuntu', color: _kWhite,
                            fontWeight: FontWeight.w700, fontSize: 15)),
                        ]),
                        const SizedBox(height: 12),
                        Text("¿Seguro que deseas eliminar este vehículo?",
                          style: TextStyle(fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.55), fontSize: 13)),
                        const SizedBox(height: 22),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text("Cancelar", style: TextStyle(
                              fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.50), fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.pop(context, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.40)),
                              ),
                              child: const Text("Eliminar", style: TextStyle(
                                fontFamily: 'Ubuntu', color: Colors.redAccent,
                                fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                );

                if (confirmado == true) {
                  final exito = await ApiService.eliminarVehiculoPorPlaca(vehiculo.placa);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                      exito ? "Vehículo eliminado correctamente" : "Error al eliminar",
                      style: const TextStyle(fontFamily: 'Ubuntu'),
                    ),
                    backgroundColor: exito ? _kBlueDark : Colors.red.shade900,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                  if (exito) await onEliminar();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.22)),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
              ),
            ),
          ]),

          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: _kBlue.withOpacity(0.40), size: 20),
        ]),
      ),
    );
  }
}