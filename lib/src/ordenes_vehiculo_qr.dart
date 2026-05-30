import 'package:flutter/material.dart';
import 'api_service.dart';
import 'orden_model.dart';

class OrdenesVehiculoQrPage extends StatefulWidget {
  final String qrToken; // token del vehículo escaneado
  final String? placa;  // opcional solo para mostrar en título

  const OrdenesVehiculoQrPage({
    super.key,
    required this.qrToken,
    this.placa,
  });

  @override
  State<OrdenesVehiculoQrPage> createState() => _OrdenesVehiculoQrPageState();
}

class _OrdenesVehiculoQrPageState extends State<OrdenesVehiculoQrPage> {
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
      final data = await ApiService.obtenerOtsPorQrToken(widget.qrToken);
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
      case 'PENDIENTE':
        return Colors.orange;
      case 'ENTREGADO':
        return Colors.green;
      default:
        return Colors.white54;
    }
  }

  String _estadoUI(OrdenTrabajo o) {
    // Si tu modelo ya trae estado_ui, úsalo.
    // Si no, cae a o.estado.
    // (ajusta si tu OrdenTrabajo lo guarda con otro nombre)
    final any = o as dynamic;
    final s = (any.estadoUi ?? any.estado_ui ?? o.estado)?.toString();
    return (s == null || s.isEmpty) ? o.estado : s;
  }

  @override
  Widget build(BuildContext context) {
    final placaTitulo = (widget.placa != null && widget.placa!.trim().isNotEmpty)
        ? widget.placa!.toUpperCase()
        : "Vehículo";

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'OTs de $placaTitulo',
          style: const TextStyle(fontFamily: 'BBH_Sans_Bogle', color: Colors.black),
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
                        'Este vehículo no tiene OTs aún.',
                        style: TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: ordenes.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white24),
                      itemBuilder: (_, i) {
                        final o = ordenes[i];
                        final estado = _estadoUI(o);

                        return ListTile(
                          title: Text(
                            'OT #${o.id} — Placa: ${o.placa}',
                            style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                          ),
                          subtitle: Text(
                            'Estado: $estado | Pago: ${o.pagoEstado} | Total: \$${o.total.toStringAsFixed(2)}',
                            style: TextStyle(color: _colorEstado(estado), fontFamily: 'BBH_Sans_Bogle'),
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
