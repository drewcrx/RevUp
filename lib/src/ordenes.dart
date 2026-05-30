import 'package:flutter/material.dart';
import 'api_service.dart';
import 'orden_model.dart';

class OrdenesPage extends StatefulWidget {
  const OrdenesPage({super.key});

  @override
  State<OrdenesPage> createState() => _OrdenesPageState();
}

class _OrdenesPageState extends State<OrdenesPage> {
  bool loading = true;
  String error = '';
  List<OrdenTrabajo> ordenes = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final data = await ApiService.obtenerOrdenes(soloMias: true);
      ordenes = data.map((e) => OrdenTrabajo.fromMap(e)).toList();
    } catch (e) {
      error = e.toString();
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'RECIBIDO':
        return Colors.blueGrey;
      case 'DIAGNOSTICO':
        return Colors.orange;
      case 'REPARACION':
        return Colors.yellow;
      case 'LISTO':
        return Colors.lightGreen;
      case 'ENTREGADO':
        return Colors.green;
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Órdenes',
          style: TextStyle(fontFamily: 'BBH_Sans_Bogle', color: Colors.black),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        foregroundColor: Colors.black,
        onPressed: () async {
          final ok = await Navigator.pushNamed(context, '/nueva_orden');
          if (ok == true) _cargar();
        },
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(
                  child: Text(
                    error,
                    style: const TextStyle(color: Colors.red, fontFamily: 'BBH_Sans_Bogle'),
                  ),
                )
              : ordenes.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay órdenes aún.',
                        style: TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: ordenes.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white24),
                      itemBuilder: (_, i) {
                        final o = ordenes[i];
                        return ListTile(
                          title: Text(
                            'Placa: ${o.placa}',
                            style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                          ),
                          subtitle: Text(
                            'Estado: ${o.estado} | Pago: ${o.pagoEstado} | Total: \$${o.total.toStringAsFixed(2)}',
                            style: TextStyle(color: _colorEstado(o.estado), fontFamily: 'BBH_Sans_Bogle'),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.green),
                          onTap: () async {
                            final ok = await Navigator.pushNamed(
                              context,
                              '/detalle_orden',
                              arguments: o.id,
                            );
                            if (ok == true) _cargar();
                          },
                        );
                      },
                    ),
    );
  }
}
