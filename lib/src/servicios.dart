import 'package:flutter/material.dart';

class ServiciosPage extends StatelessWidget {
  const ServiciosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> servicios = [
      {
        'titulo': 'Cambio de Aceite',
        'descripcion': 'Reemplazo completo de aceite y filtro del motor.',
        'icono': Icons.oil_barrel,
      },
      {
        'titulo': 'Alineación y Balanceo',
        'descripcion': 'Corrección de ángulos de las ruedas para mejorar la estabilidad.',
        'icono': Icons.settings,
      },
      {
        'titulo': 'Mantenimiento de Frenos',
        'descripcion': 'Revisión y cambio de pastillas, discos y líquido de freno.',
        'icono': Icons.car_repair,
      },
      {
        'titulo': 'Revisión Eléctrica',
        'descripcion': 'Diagnóstico y reparación de fallas eléctricas del vehículo.',
        'icono': Icons.electrical_services,
      },
      {
        'titulo': 'Cambio de Batería',
        'descripcion': 'Reemplazo de batería y comprobación del sistema de carga.',
        'icono': Icons.battery_charging_full,
      },
      {
        'titulo': 'Diagnóstico por Scanner',
        'descripcion': 'Lectura y análisis de códigos de falla con equipo especializado.',
        'icono': Icons.search,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          'Servicios',
          style: TextStyle(
            fontFamily: 'BBH_Sans_Bogle',
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: servicios.length,
        itemBuilder: (context, index) {
          final servicio = servicios[index];
          return Card(
            color: Colors.green.withOpacity(0.1),
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: ListTile(
              leading: Icon(servicio['icono'], color: Colors.green),
              title: Text(
                servicio['titulo'],
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'BBH_Sans_Bogle',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Text(
                servicio['descripcion'],
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'BBH_Sans_Bogle',
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
