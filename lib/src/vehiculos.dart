import 'package:flutter/material.dart';
import 'vehiculo_model.dart';
import 'api_service.dart';
import 'detalle_vehiculo.dart';
import 'nueva_orden.dart';

class VehiculosPage extends StatefulWidget {
  const VehiculosPage({super.key});

  @override
  State<VehiculosPage> createState() => _VehiculosPageState();
}

class _VehiculosPageState extends State<VehiculosPage> {
  late Future<List<Vehiculo>> _vehiculosFuture;

  // ====== Búsqueda + filtros ======
  final TextEditingController _searchCtrl = TextEditingController();
  String _fMarca = "Todos";
  String _fColor = "Todos";
  String _fAnio = "Todos";
  String _fTipo = "Todos";

  // Cache local
  List<Vehiculo> _all = [];
  List<Vehiculo> _filtered = [];

  // Opciones filtros
  List<String> _marcas = const ["Todos"];
  List<String> _colores = const ["Todos"];
  List<String> _anios = const ["Todos"];
  List<String> _tipos = const ["Todos"];

  // Para evitar setState durante build
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
    _initializedFromSnapshot = false; // importante al refrescar
  }

  Future<void> _refrescarLista() async {
    setState(() {
      _loadVehiculos();
    });
  }

  Future<void> _irACrearOTDesdeVehiculo(Vehiculo v) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NuevaOrdenPage(placaInicial: v.placa),
      ),
    );
    await _refrescarLista();
  }

  // =========================
  // Helpers: lectura segura (sin romper modelo)
  // =========================
  String _safeLower(String? s) => (s ?? "").trim().toLowerCase();

  String _getColor(Vehiculo v) {
    try {
      final dynamic dv = v;
      return (dv.color?.toString() ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  String _getTipo(Vehiculo v) {
  try {
    final dynamic dv = v;
    return (dv.tipoVehiculo?.toString() ?? '').trim();
  } catch (_) {
    return '';
  }
}


  String _getPropietario(Vehiculo v) {
    try {
      final dynamic dv = v;
      return (dv.propietario?.toString() ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  String _getTelefono(Vehiculo v) {
    try {
      final dynamic dv = v;
      return (dv.telefono?.toString() ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  String _getNotaIngreso(Vehiculo v) {
    try {
      final dynamic dv = v;
      return (dv.notaIngreso?.toString() ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  int? _getAnio(Vehiculo v) {
    try {
      final dynamic dv = v;
      final a = dv.anio;
      if (a is int) return a;
      return int.tryParse((a ?? "").toString());
    } catch (_) {
      return null;
    }
  }

  String _title(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t.split(" ").map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(" ");
  }

  // =========================
  // Construir opciones de filtros (SIN setState)
  // =========================
  void _buildFilterOptionsNoSetState(List<Vehiculo> lista) {
    final marcas = <String>{};
    final colores = <String>{};
    final anios = <String>{};
    final tipos = <String>{};

    for (final v in lista) {
      final m = v.marca.trim();
      if (m.isNotEmpty) marcas.add(_title(m));

      final t = _getTipo(v).trim();
      if (t.isNotEmpty) tipos.add(_title(t));

      final c = _getColor(v).trim();
      if (c.isNotEmpty) colores.add(_title(c));

      final a = _getAnio(v);
      if (a != null && a > 1900 && a < 3000) anios.add(a.toString());
    }

    final marcasSorted = marcas.toList()..sort();
    final tiposSorted = tipos.toList()..sort();
    final coloresSorted = colores.toList()..sort();
    final aniosSorted = anios.toList()
      ..sort((a, b) => int.parse(b).compareTo(int.parse(a))); // desc

    _marcas = ["Todos", ...marcasSorted];
    _tipos = ["Todos", ...tiposSorted];
    _colores = ["Todos", ...coloresSorted];
    _anios = ["Todos", ...aniosSorted];

    if (!_marcas.contains(_fMarca)) _fMarca = "Todos";
    if (!_tipos.contains(_fTipo)) _fTipo = "Todos";
    if (!_colores.contains(_fColor)) _fColor = "Todos";
    if (!_anios.contains(_fAnio)) _fAnio = "Todos";
  }

  // =========================
  // Aplicar filtros
  // =========================
  void _applyFilters() {
    final q = _safeLower(_searchCtrl.text);

    List<Vehiculo> res = List<Vehiculo>.from(_all);

    // Dropdowns
    if (_fMarca != "Todos") {
      final fm = _safeLower(_fMarca);
      res = res.where((v) => _safeLower(v.marca) == fm).toList();
    }

    if (_fTipo != "Todos") {
      final ft = _safeLower(_fTipo);
      res = res.where((v) => _safeLower(_getTipo(v)) == ft).toList();
    }

    if (_fColor != "Todos") {
      final fc = _safeLower(_fColor);
      res = res.where((v) => _safeLower(_getColor(v)) == fc).toList();
    }

    if (_fAnio != "Todos") {
      final fa = int.tryParse(_fAnio);
      res = res.where((v) => _getAnio(v) == fa).toList();
    }

    // Búsqueda “contains” multi-campo
    if (q.isNotEmpty) {
      res = res.where((v) {
        final fields = <String>[
          v.marca,
          v.modelo,
          v.placa,
          _getColor(v),
          _getTipo(v),
          _getPropietario(v),
          _getTelefono(v),
          _getNotaIngreso(v),
          (_getAnio(v) ?? "").toString(),
        ].map((e) => _safeLower(e.toString())).toList();

        return fields.any((f) => f.contains(q));
      }).toList();
    }

    // Orden por placa
    res.sort((a, b) => a.placa.toUpperCase().compareTo(b.placa.toUpperCase()));

    if (!mounted) return;
    setState(() => _filtered = res);
  }

  void _resetFilters() {
    _searchCtrl.clear();
    setState(() {
      _fMarca = "Todos";
      _fTipo = "Todos";
      _fColor = "Todos";
      _fAnio = "Todos";
      _filtered = List<Vehiculo>.from(_all);
    });
  }

  // =========================
  // UI: buscador + filtros
  // =========================
  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF00A86B).withOpacity(0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF00A86B)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                  decoration: const InputDecoration(
                    hintText: "Buscar por placa, marca, modelo, color, propietario...",
                    hintStyle: TextStyle(color: Colors.white54, fontFamily: 'BBH_Sans_Bogle'),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_searchCtrl.text.trim().isNotEmpty ||
                  _fMarca != "Todos" ||
                  _fColor != "Todos" ||
                  _fAnio != "Todos")
                IconButton(
                  tooltip: "Limpiar",
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.clear, color: Colors.white70),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _drop("Marca", _fMarca, _marcas, (v) {
              setState(() => _fMarca = v);
              _applyFilters();
            })),
            const SizedBox(width: 10),
            Expanded(child: _drop("Año", _fAnio, _anios, (v) {
              setState(() => _fAnio = v);
              _applyFilters();
            })),
            const SizedBox(width: 10),
            Expanded(child: _drop("Color", _fColor, _colores, (v) {
              setState(() => _fColor = v);
              _applyFilters();
            })),
            const SizedBox(width: 10),
            Expanded(child: _drop("Tipo", _fTipo, _tipos, (v) {
              setState(() => _fTipo = v);
              _applyFilters();
            })),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Mostrando: ${_filtered.length} / ${_all.length}",
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'BBH_Sans_Bogle',
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _drop(String label, String value, List<String> items, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00A86B).withOpacity(0.45)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : "Todos",
          isExpanded: true,
          dropdownColor: Colors.black,
          iconEnabledColor: const Color(0xFF00A86B),
          style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle', fontSize: 13),
          items: items
              .map((e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text("$label: $e", overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ),
    );
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Vehículos', style: TextStyle(fontFamily: 'BBH_Sans_Bogle')),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lista de Vehículos',
              style: TextStyle(
                fontSize: 20,
                color: Color(0xFF00A86B),
                fontFamily: 'BBH_Sans_Bogle',
              ),
            ),
            const SizedBox(height: 10),

            _buildSearchAndFilters(),
            const SizedBox(height: 10),

            Expanded(
              child: FutureBuilder<List<Vehiculo>>(
                future: _vehiculosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                    );
                  }

                  final lista = snapshot.data ?? [];

                  // ✅ Inicializamos UNA SOLA VEZ cuando llega la data (sin setState aquí)
                  if (!_initializedFromSnapshot) {
                    _initializedFromSnapshot = true;

                    _all = List<Vehiculo>.from(lista);
                    _filtered = List<Vehiculo>.from(lista);
                    _buildFilterOptionsNoSetState(lista);

                    // Aplicar filtros después del frame (ya es seguro setState)
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _applyFilters();
                    });
                  }

                  if (_filtered.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refrescarLista,
                      child: ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Text('No hay resultados con esos filtros',
                                style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refrescarLista,
                    child: ListView.builder(
                      itemCount: _filtered.length,
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

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A86B),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Atrás', style: TextStyle(fontFamily: 'BBH_Sans_Bogle', fontSize: 16)),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: const Color(0xFF00A86B),
                    side: const BorderSide(color: Colors.green, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                  ),
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/agregar_vehiculo');
                    _refrescarLista();
                  },
                  child: const Text('Agregar vehículo',
                      style: TextStyle(fontFamily: 'BBH_Sans_Bogle', fontSize: 16)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VehiculoItem extends StatelessWidget {
  final Vehiculo vehiculo;
  final Future<void> Function() onEliminar;
  final VoidCallback onCrearOT;

  const _VehiculoItem({
    required this.vehiculo,
    required this.onEliminar,
    required this.onCrearOT,
  });

  String _getColor(Vehiculo v) {
    try {
      final dynamic dv = v;
      return (dv.color?.toString() ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  String _getPropietario(Vehiculo v) {
    try {
      final dynamic dv = v;
      return (dv.propietario?.toString() ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  String _getTelefono(Vehiculo v) {
    try {
      final dynamic dv = v;
      return (dv.telefono?.toString() ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  int? _getAnio(Vehiculo v) {
    try {
      final dynamic dv = v;
      final a = dv.anio;
      if (a is int) return a;
      return int.tryParse((a ?? "").toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(vehiculo);
    final propietario = _getPropietario(vehiculo);
    final tel = _getTelefono(vehiculo);
    final anio = _getAnio(vehiculo);

    return Card(
      color: Colors.green.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: const Icon(Icons.directions_car, color: Colors.green),
        title: Text(
          '${vehiculo.marca} ${vehiculo.modelo}${anio != null ? " ($anio)" : ""}',
          style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Placa: ${vehiculo.placa}  •  Color: ${color.isEmpty ? "—" : color}',
              style: const TextStyle(color: Colors.white70, fontFamily: 'BBH_Sans_Bogle'),
            ),
            const SizedBox(height: 2),
            Text(
              'Propietario: ${propietario.isEmpty ? "—" : propietario}  •  Tel: ${tel.isEmpty ? "—" : tel}',
              style: const TextStyle(color: Colors.white70, fontFamily: 'BBH_Sans_Bogle'),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: const Color(0xFF00A86B),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onCrearOT,
              child: const Text("OT",
                  style: TextStyle(fontFamily: 'BBH_Sans_Bogle', fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () async {
                final confirmado = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.black,
                    title: const Text("Confirmar eliminación",
                        style: TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle')),
                    content: const Text("¿Seguro que deseas eliminar este vehículo?",
                        style: TextStyle(color: Colors.white70, fontFamily: 'BBH_Sans_Bogle')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancelar",
                            style: TextStyle(color: Colors.green, fontFamily: 'BBH_Sans_Bogle')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Eliminar",
                            style: TextStyle(color: Colors.redAccent, fontFamily: 'BBH_Sans_Bogle')),
                      ),
                    ],
                  ),
                );

                if (confirmado == true) {
                  final exito = await ApiService.eliminarVehiculoPorPlaca(vehiculo.placa);

                  if (exito) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Vehículo eliminado correctamente"), backgroundColor: Colors.green),
                    );
                    await onEliminar();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Error al eliminar"), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.green, size: 16),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetalleVehiculoPage(vehiculo: vehiculo)),
          );
        },
      ),
    );
  }
}
