import 'package:flutter/material.dart';
import 'vehiculo_model.dart';
import 'detalle_vehiculo.dart';

List<Vehiculo> listaVehiculos = [
  Vehiculo(
    placa: "ABC123",
    marca: "Toyota",
    modelo: "Corolla",
    kilometraje: 0,
    ultimaVisita: DateTime.now(),
    arreglos: [],
  ),
  Vehiculo(
    placa: "XYZ987",
    marca: "Hyundai",
    modelo: "Tucson",
    kilometraje: 0,
    ultimaVisita: DateTime.now(),
    arreglos: [],
  ),
];

class DetalleQRPage extends StatelessWidget {
  const DetalleQRPage({super.key});

  Vehiculo? buscarVehiculo(String placa) {
    try {
      return listaVehiculos.firstWhere(
        (v) => v.placa.toUpperCase() == placa.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String qrData = ModalRoute.of(context)!.settings.arguments as String;
    final Vehiculo? vehiculoEncontrado = buscarVehiculo(qrData);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A86B),
        title: const Text(
          "Datos del Vehículo",
          style: TextStyle(
            fontFamily: "BBH_Sans_Bogle",
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: vehiculoEncontrado != null
              ? _mostrarVehiculo(context, vehiculoEncontrado)
              : _mostrarError(qrData),
        ),
      ),
    );
  }

  Widget _mostrarVehiculo(BuildContext context, Vehiculo vehiculo) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00A86B),
        foregroundColor: Colors.black,
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleVehiculoPage(vehiculo: vehiculo),
          ),
        );
      },
      child: Text(
        "Abrir vehículo: ${vehiculo.marca} ${vehiculo.modelo}",
        style: const TextStyle(fontFamily: "BBH_Sans_Bogle"),
      ),
    );
  }

  Widget _mostrarError(String data) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error, color: Colors.red, size: 50),
        const SizedBox(height: 20),
        const Text(
          "Vehículo no encontrado",
          style: TextStyle(
              fontFamily: "BBH_Sans_Bogle", color: Colors.red, fontSize: 20),
        ),
        const SizedBox(height: 10),
        Text(
          "Código escaneado:\n$data",
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white70, fontFamily: "BBH_Sans_Bogle"),
        ),
      ],
    );
  }
}
