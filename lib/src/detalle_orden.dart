import 'package:flutter/material.dart';
import 'api_service.dart';

class DetalleOrdenPage extends StatefulWidget {
  final int ordenId;
  const DetalleOrdenPage({super.key, required this.ordenId});

  @override
  State<DetalleOrdenPage> createState() => _DetalleOrdenPageState();
}

class _DetalleOrdenPageState extends State<DetalleOrdenPage> {
  bool loading = true;
  String? error;
  Map<String, dynamic>? data;

  static const green = Colors.green;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await ApiService.obtenerDetalleOrden(widget.ordenId);
      setState(() {
        data = res;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Map<String, dynamic> get ot => (data?['ot'] as Map<String, dynamic>? ?? {});
  List<Map<String, dynamic>> get servicios =>
      (data?['servicios'] as List? ?? []).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get repuestos =>
      (data?['repuestos'] as List? ?? []).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get pagos =>
      (data?['pagos'] as List? ?? []).cast<Map<String, dynamic>>();

  String _money(dynamic v) {
    final n = double.tryParse(v?.toString() ?? "0") ?? 0;
    return "\$${n.toStringAsFixed(2)}";
  }

  Future<void> _showAddServicio() async {
    final descCtrl = TextEditingController();
    final precioCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Agregar servicio",
            style: TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
              decoration: const InputDecoration(
                labelText: "Descripción",
                labelStyle: TextStyle(color: green, fontFamily: 'BBH_Sans_Bogle'),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: green)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: green, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: precioCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
              decoration: const InputDecoration(
                labelText: "Precio (mano de obra)",
                labelStyle: TextStyle(color: green, fontFamily: 'BBH_Sans_Bogle'),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: green)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: green, width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.black),
            onPressed: () async {
              final desc = descCtrl.text.trim();
              final precio = double.tryParse(precioCtrl.text.trim()) ?? 0;

              if (desc.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ingresa una descripción"), backgroundColor: Colors.red),
                );
                return;
              }

              try {
                await ApiService.agregarServicioOT(
                  ordenId: widget.ordenId,
                  descripcion: desc,
                  precio: precio,
                );
                if (!mounted) return;
                Navigator.pop(ctx);
                await _load();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Guardar",
                style: TextStyle(fontFamily: 'BBH_Sans_Bogle', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddRepuesto() async {
    final nombreCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController(text: "1");
    final costoCtrl = TextEditingController();
    final precioCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Agregar repuesto",
            style: TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                decoration: const InputDecoration(
                  labelText: "Nombre del repuesto",
                  labelStyle: TextStyle(color: green, fontFamily: 'BBH_Sans_Bogle'),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: green)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: green, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cantidadCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                decoration: const InputDecoration(
                  labelText: "Cantidad",
                  labelStyle: TextStyle(color: green, fontFamily: 'BBH_Sans_Bogle'),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: green)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: green, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costoCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                decoration: const InputDecoration(
                  labelText: "Costo unitario (gasto)",
                  labelStyle: TextStyle(color: green, fontFamily: 'BBH_Sans_Bogle'),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: green)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: green, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: precioCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                decoration: const InputDecoration(
                  labelText: "Precio unitario (cliente)",
                  labelStyle: TextStyle(color: green, fontFamily: 'BBH_Sans_Bogle'),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: green)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: green, width: 1.5)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.black),
            onPressed: () async {
              final nombre = nombreCtrl.text.trim();
              final cantidad = int.tryParse(cantidadCtrl.text.trim()) ?? 1;
              final costo = double.tryParse(costoCtrl.text.trim()) ?? 0;
              final precio = double.tryParse(precioCtrl.text.trim()) ?? 0;

              if (nombre.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ingresa el nombre del repuesto"), backgroundColor: Colors.red),
                );
                return;
              }
              if (cantidad <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Cantidad inválida"), backgroundColor: Colors.red),
                );
                return;
              }

              try {
                await ApiService.agregarRepuestoOT(
                  ordenId: widget.ordenId,
                  nombre: nombre,
                  cantidad: cantidad,
                  costoUnitario: costo,
                  precioUnitario: precio,
                );
                if (!mounted) return;
                Navigator.pop(ctx);
                await _load();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Guardar",
                style: TextStyle(fontFamily: 'BBH_Sans_Bogle', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showPago() async {
    final montoCtrl = TextEditingController();
    String metodo = "EFECTIVO";

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Registrar pago",
            style: TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: montoCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
              decoration: const InputDecoration(
                labelText: "Monto",
                labelStyle: TextStyle(color: green, fontFamily: 'BBH_Sans_Bogle'),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: green)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: green, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: metodo,
              dropdownColor: Colors.black,
              style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
              decoration: const InputDecoration(
                labelText: "Método",
                labelStyle: TextStyle(color: green, fontFamily: 'BBH_Sans_Bogle'),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: green)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: green, width: 1.5)),
              ),
              items: const [
                DropdownMenuItem(value: "EFECTIVO", child: Text("EFECTIVO")),
                DropdownMenuItem(value: "TRANSFERENCIA", child: Text("TRANSFERENCIA")),
                DropdownMenuItem(value: "TARJETA", child: Text("TARJETA")),
              ],
              onChanged: (v) => metodo = v ?? "EFECTIVO",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: green),
            onPressed: () async {
              final monto = double.tryParse(montoCtrl.text.trim()) ?? 0;
              if (monto <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Monto inválido"), backgroundColor: Colors.red),
                );
                return;
              }

              try {
                await ApiService.registrarPagoOT(
                  ordenId: widget.ordenId,
                  monto: monto,
                  metodo: metodo,
                );
                if (!mounted) return;
                Navigator.pop(ctx);
                await _load();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Registrar",
                style: TextStyle(fontFamily: 'BBH_Sans_Bogle', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _cerrarOT() async {
  try {
    await ApiService.cerrarOT(widget.ordenId);
    if (!mounted) return;

    await _load();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("OT marcada como ENTREGADO"),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
    );
  }
}




  @override
  Widget build(BuildContext context) {
    final placa = (ot['placa'] ?? '').toString();
    final estado = (ot['estado'] ?? '').toString();
    final pagoEstado = (ot['pago_estado'] ?? '').toString();
    final symptoms = (ot['symptoms'] ?? '').toString();
    final total = ot['total'] ?? 0;
    final kmOtRaw = ot['kilometraje_ot'];
    final int? kmOt = (kmOtRaw is int)
        ? kmOtRaw
        : int.tryParse(kmOtRaw?.toString() ?? "");

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: green,
        foregroundColor: Colors.black,
        title: const Text("DETALLE OT",
            style: TextStyle(fontFamily: 'BBH_Sans_Bogle', fontWeight: FontWeight.bold)),
        actions: [
          Builder(
            builder: (_) {
              final kmRaw = ot['kilometraje_ot'];
              final km = (kmRaw is int)
                  ? kmRaw
                  : int.tryParse(kmRaw?.toString() ?? "");

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        (km == null || km <= 0) ? "— km" : "$km km",
                        style: const TextStyle(
                          fontFamily: 'BBH_Sans_Bogle',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: "Refrescar",
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: green))
          : (error != null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red, fontFamily: 'BBH_Sans_Bogle'),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      Text("PLACA: $placa",
                          style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'BBH_Sans_Bogle',
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text("ESTADO: $estado | PAGO: $pagoEstado",
                          style: const TextStyle(
                              color: green, fontFamily: 'BBH_Sans_Bogle', fontSize: 14)),
                      const SizedBox(height: 16),

                      const Text("SÍNTOMAS (CLIENTE):",
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'BBH_Sans_Bogle',
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(symptoms,
                          style: const TextStyle(
                              color: Colors.white70, fontFamily: 'BBH_Sans_Bogle')),
                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: green,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _showAddServicio,
                              child: const Text("AGREGAR SERVICIO",
                                  style: TextStyle(
                                      fontFamily: 'BBH_Sans_Bogle', fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: green,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _showAddRepuesto,
                              child: const Text("AGREGAR REPUESTO",
                                  style: TextStyle(
                                      fontFamily: 'BBH_Sans_Bogle', fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _showPago,
                        child: const Text("REGISTRAR PAGO",
                            style: TextStyle(
                                fontFamily: 'BBH_Sans_Bogle', fontWeight: FontWeight.bold)),
                      ),

                      const SizedBox(height: 18),
                      const Divider(color: Colors.white24),

                      Text("SERVICIOS (${servicios.length})",
                          style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'BBH_Sans_Bogle',
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...servicios.map((s) {
                        final desc = (s['descripcion'] ?? '').toString();
                        final precio = _money(s['precio']);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(desc,
                              style: const TextStyle(
                                  color: Colors.white, fontFamily: 'BBH_Sans_Bogle')),
                          trailing: Text(precio,
                              style: const TextStyle(
                                  color: green, fontFamily: 'BBH_Sans_Bogle')),
                        );
                      }),

                      const Divider(color: Colors.white24),

                      Text("REPUESTOS (${repuestos.length})",
                          style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'BBH_Sans_Bogle',
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...repuestos.map((r) {
                        final nombre = (r['nombre'] ?? '').toString();
                        final cant = (r['cantidad'] ?? 1).toString();
                        final pUnit = _money(r['precio_unitario']);
                        final linea = "\$${((double.tryParse(r['precio_unitario']?.toString() ?? "0") ?? 0) *
                                (int.tryParse(cant) ?? 1))
                            .toStringAsFixed(2)}";
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text("$nombre (x$cant)",
                              style: const TextStyle(
                                  color: Colors.white, fontFamily: 'BBH_Sans_Bogle')),
                          subtitle: Text("Precio unitario: $pUnit",
                              style: const TextStyle(
                                  color: Colors.white70, fontFamily: 'BBH_Sans_Bogle')),
                          trailing: Text(linea,
                              style: const TextStyle(
                                  color: green, fontFamily: 'BBH_Sans_Bogle')),
                        );
                      }),

                      const Divider(color: Colors.white24),

                      Text("PAGOS (${pagos.length})",
                          style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'BBH_Sans_Bogle',
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...pagos.map((p) {
                        final monto = _money(p['monto']);
                        final metodo = (p['metodo'] ?? '').toString();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(metodo,
                              style: const TextStyle(
                                  color: Colors.white, fontFamily: 'BBH_Sans_Bogle')),
                          trailing: Text(monto,
                              style: const TextStyle(
                                  color: green, fontFamily: 'BBH_Sans_Bogle')),
                        );
                      }),

                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24),

                      Text("TOTAL: ${_money(total)}",
                          style: const TextStyle(
                              color: green,
                              fontFamily: 'BBH_Sans_Bogle',
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),

                      const SizedBox(height: 14),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: estado == "ENTREGADO" ? null : _cerrarOT,
                        child: const Text("CERRAR OT (ENTREGAR)",
                            style: TextStyle(
                                fontFamily: 'BBH_Sans_Bogle', fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
    );
  }
}
