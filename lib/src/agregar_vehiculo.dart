import 'package:flutter/material.dart';
import 'api_service.dart';

class AgregarVehiculoPage extends StatefulWidget {
  const AgregarVehiculoPage({super.key});

  @override
  State<AgregarVehiculoPage> createState() => _AgregarVehiculoPageState();
}

class _AgregarVehiculoPageState extends State<AgregarVehiculoPage> {
  final marcaController = TextEditingController();
  final modeloController = TextEditingController();
  final placaController = TextEditingController();
  final kilometrajeController = TextEditingController();
  final ultimaVisitaController = TextEditingController();

  // NUEVOS
  final anioController = TextEditingController();
  final propietarioController = TextEditingController();
  final telefonoController = TextEditingController();
  final notaController = TextEditingController();
  String? _colorSeleccionado;

  // ✅ NUEVO
  String? _tipoVehiculoSeleccionado;

  bool _enviando = false;

  final _colores = const [
    "Blanco",
    "Negro",
    "Rojo",
    "Azul",
    "Plomo",
    "Plateado",
    "Amarillo",
    "Verde",
    "Otro",
  ];

  // ✅ NUEVO
  final _tiposVehiculo = const [
    "Sedán",
    "Hatchback",
    "SUV",
    "Pickup / Camioneta",
    "Coupé",
    "Van / Minivan",
    "Camión liviano",
    "Otro",
  ];

  @override
  void dispose() {
    marcaController.dispose();
    modeloController.dispose();
    placaController.dispose();
    kilometrajeController.dispose();
    ultimaVisitaController.dispose();

    anioController.dispose();
    propietarioController.dispose();
    telefonoController.dispose();
    notaController.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.green),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.green),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.green, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Agregar Vehículo',
            style: TextStyle(fontFamily: 'BBH_Sans_Bogle', color: Colors.black)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingrese los datos del vehículo:',
                style: TextStyle(color: Colors.green, fontSize: 18, fontFamily: 'BBH_Sans_Bogle'),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: marcaController,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Marca'),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: modeloController,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Modelo'),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: placaController,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Placa'),
              ),
              const SizedBox(height: 16),

              // ✅ NUEVO: tipo de vehículo
              DropdownButtonFormField<String>(
                value: _tipoVehiculoSeleccionado,
                dropdownColor: Colors.black,
                style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                decoration: _dec('Tipo de vehículo'),
                items: _tiposVehiculo
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, style: const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _tipoVehiculoSeleccionado = v),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: anioController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Año (Ej: 2018)'),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _colorSeleccionado,
                dropdownColor: Colors.black,
                style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                decoration: _dec('Color'),
                items: _colores
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _colorSeleccionado = v),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: propietarioController,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Propietario'),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: telefonoController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Teléfono'),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: kilometrajeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Kilometraje'),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: ultimaVisitaController,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Última visita (YYYY-MM-DD)'),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: notaController,
                maxLines: 3,
                maxLength: 300,
                style: const TextStyle(color: Colors.white),
                decoration: _dec('Nota de ingreso (opcional)'),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 25),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Atrás',
                        style: TextStyle(fontFamily: 'BBH_Sans_Bogle', fontSize: 16)),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 25),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _enviando
                        ? null
                        : () async {
                            final marca = marcaController.text.trim();
                            final modelo = modeloController.text.trim();
                            final placa = placaController.text.trim().toUpperCase();
                            final anioTxt = anioController.text.trim();
                            final propietario = propietarioController.text.trim();
                            final telefono = telefonoController.text.trim();
                            final kilometraje = kilometrajeController.text.trim();
                            final ultimaVisita = ultimaVisitaController.text.trim();
                            final nota = notaController.text.trim();

                            final anio = int.tryParse(anioTxt);

                            if (marca.isEmpty ||
                                modelo.isEmpty ||
                                placa.isEmpty ||
                                _tipoVehiculoSeleccionado == null ||
                                anio == null ||
                                _colorSeleccionado == null ||
                                propietario.isEmpty ||
                                telefono.isEmpty ||
                                kilometraje.isEmpty ||
                                ultimaVisita.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Completa todos los campos obligatorios'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            setState(() => _enviando = true);

                            final exito = await ApiService.agregarVehiculo(
                              marca: marca,
                              modelo: modelo,
                              placa: placa,
                              kilometraje: kilometraje,
                              ultimaVisita: ultimaVisita,
                              anio: anio,
                              color: _colorSeleccionado!,
                              propietarioNombre: propietario,
                              propietarioTelefono: telefono,
                              notaIngreso: nota.isEmpty ? null : nota,

                              // ✅ NUEVO
                              tipoVehiculo: _tipoVehiculoSeleccionado!,
                            );

                            setState(() => _enviando = false);

                            if (!mounted) return;

                            if (exito) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Vehículo agregado correctamente'),
                                    backgroundColor: Colors.green),
                              );
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Error al guardar'), backgroundColor: Colors.red),
                              );
                            }
                          },
                    child: _enviando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                          )
                        : const Text('Guardar',
                            style: TextStyle(fontFamily: 'BBH_Sans_Bogle', fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
