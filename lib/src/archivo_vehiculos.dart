import 'package:flutter/material.dart';
import 'api_service.dart';
import 'vehiculo_model.dart';
import 'detalle_vehiculo.dart';

class ArchivoVehiculosPage extends StatefulWidget {
  const ArchivoVehiculosPage({super.key});
  @override
  State<ArchivoVehiculosPage> createState() => _ArchivoVehiculosPageState();
}

class _ArchivoVehiculosPageState extends State<ArchivoVehiculosPage> {
  late Future<List<Vehiculo>> _future;
  @override
  void initState() {
    super.initState();
    _future = ApiService.obtenerVehiculosArchivados();
  }

  void _load() {
    setState(() => _future = ApiService.obtenerVehiculosArchivados());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Vehículos archivados'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Vehiculo>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: TextButton(
              onPressed: _load,
              child: const Text('No se pudo cargar. Reintentar'),
            ),
          );
        final vehicles = snapshot.data ?? [];
        if (vehicles.isEmpty)
          return const Center(child: Text('No hay vehículos archivados'));
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'El archivo conserva las órdenes, fotografías y pagos. Restaura un vehículo para registrar una nueva visita.',
              ),
            ),
            for (final v in vehicles)
              ListTile(
                title: Text('${v.placa} · ${v.marca} ${v.modelo}'),
                subtitle: Text(v.propietarioNombre ?? ''),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetalleVehiculoPage(vehiculo: v),
                  ),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    try {
                      await ApiService.restaurarVehiculo(v.placa);
                      if (mounted) _load();
                    } catch (e) {
                      if (context.mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                  child: const Text('Restaurar'),
                ),
              ),
          ],
        );
      },
    ),
  );
}
