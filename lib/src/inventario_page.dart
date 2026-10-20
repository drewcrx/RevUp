import 'package:flutter/material.dart';
import 'api_service.dart';
import 'formulario.dart';
import 'ui_tools.dart';

class InventarioPage extends StatefulWidget {
  const InventarioPage({super.key});
  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true, _bajos = false;
  String _query = '', _error = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final rows = await ApiService.taller('inventario') as List;
      if (mounted) setState(() => _items = rows.cast<Map<String, dynamic>>());
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _crear({Map<String, dynamic>? item}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormularioPage(
          title: item == null
              ? 'Nuevo repuesto en inventario'
              : 'Editar repuesto',
          campos: [
            CampoFormulario(
              'nombre',
              'Nombre',
              initial: '${item?['nombre'] ?? ''}',
            ),
            CampoFormulario(
              'sku',
              'Codigo / SKU',
              initial: '${item?['sku'] ?? ''}',
            ),
            if (item == null)
              CampoFormulario(
                'existencias',
                'Existencias iniciales',
                initial: '0',
                numero: true,
                validator: _entero,
              ),
            CampoFormulario(
              'minimo',
              'Alerta de minimo',
              initial: '${item?['minimo'] ?? 0}',
              numero: true,
              validator: _entero,
            ),
            CampoFormulario(
              'costo',
              'Costo unitario',
              initial: '${item?['costo'] ?? ''}',
              numero: true,
              validator: _importe,
            ),
            CampoFormulario(
              'precio',
              'Precio de venta',
              initial: '${item?['precio'] ?? ''}',
              numero: true,
              validator: _importe,
            ),
          ],
          guardar: (v) async {
            await ApiService.taller(
              item == null ? 'inventario' : 'inventario/${item['id']}',
              method: item == null ? 'POST' : 'PUT',
              body: {
                ...v,
                if (item == null) 'existencias': int.parse(v['existencias']!),
                'minimo': int.parse(v['minimo']!),
                'costo': parseImporte(v['costo']!)!,
                'precio': parseImporte(v['precio']!)!,
              },
            );
          },
        ),
      ),
    );
    if (ok == true) await _load();
  }

  String? _entero(String? v) =>
      int.tryParse(v ?? '') != null && int.parse(v!) >= 0
      ? null
      : 'Usa un entero de cero o más';
  String? _importe(String? v) =>
      parseImporte(v ?? '') == null ? 'Importe inválido' : null;
  Future<void> _movimiento(Map<String, dynamic> item) async {
    final operation = nuevaOperacion();
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormularioPage(
          title: 'Movimiento de existencias',
          ayuda:
              '${item['nombre']} · Disponibles: ${item['existencias']}\nCantidad positiva para ingreso, negativa para salida. El motivo quedará registrado.',
          campos: [
            CampoFormulario(
              'cantidad',
              'Cantidad (+ ingreso / − salida)',
              numero: true,
              validator: (v) =>
                  int.tryParse(v ?? '') != null && int.parse(v!) != 0
                  ? null
                  : 'Usa un entero diferente de cero',
            ),
            const CampoFormulario('motivo', 'Motivo'),
          ],
          guardar: (v) async {
            await ApiService.taller(
              'inventario/${item['id']}/movimientos',
              method: 'POST',
              body: {
                ...v,
                'cantidad': int.parse(v['cantidad']!),
                'operacionId': operation,
              },
            );
          },
        ),
      ),
    );
    if (ok == true) await _load();
  }

  Future<void> _historial(Map<String, dynamic> item) async {
    try {
      final rows =
          await ApiService.taller('inventario/${item['id']}/movimientos')
              as List;
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * .7,
            child: Column(
              children: [
                ListTile(title: Text('Movimientos · ${item['nombre']}')),
                Expanded(
                  child: rows.isEmpty
                      ? const Center(child: Text('Sin movimientos'))
                      : ListView(
                          children: [
                            for (final row in rows)
                              ListTile(
                                leading: Text(
                                  '${(row['cantidad'] as num) > 0 ? '+' : ''}${row['cantidad']}',
                                  style: TextStyle(
                                    color: (row['cantidad'] as num) > 0
                                        ? Colors.greenAccent
                                        : Colors.orangeAccent,
                                  ),
                                ),
                                title: Text('${row['motivo']}'),
                                subtitle: Text(
                                  '${row['autor']} · ${DateTime.tryParse('${row['created_at']}')?.toLocal().toString().split('.').first ?? ''}${row['orden_id'] == null ? '' : ' · OT #${row['orden_id']}'}',
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items
        .where(
          (i) =>
              ('${i['nombre']} ${i['sku']}').toLowerCase().contains(
                _query.toLowerCase(),
              ) &&
              (!_bajos || (i['existencias'] as num) <= (i['minimo'] as num)),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _crear(),
        icon: const Icon(Icons.add),
        label: const Text('Repuesto'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nombre o código',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Solo existencias bajas'),
                  value: _bajos,
                  onChanged: (v) => setState(() => _bajos = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                ? Center(
                    child: TextButton(
                      onPressed: _load,
                      child: Text('$_error\nReintentar'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      children: [
                        if (visible.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No hay repuestos para estos filtros. Registra existencias para usarlas en una orden.',
                            ),
                          ),
                        for (final item in visible)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item['nombre']}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${item['existencias']} uds.',
                                        style: TextStyle(
                                          color:
                                              (item['existencias'] as num) <=
                                                  (item['minimo'] as num)
                                              ? Colors.orangeAccent
                                              : Colors.greenAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${item['sku']} · Mínimo ${item['minimo']}\nCosto ${dinero(item['costo'])} · Venta ${dinero(item['precio'])}',
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _movimiento(item),
                                        icon: const Icon(Icons.swap_vert),
                                        label: const Text('Movimiento'),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _historial(item),
                                        icon: const Icon(Icons.history),
                                        label: const Text('Historial'),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _crear(item: item),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Editar'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
