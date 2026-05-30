import 'package:flutter/material.dart';
import 'api_service.dart';

class NuevaOrdenPage extends StatefulWidget {
  final String? placaInicial;

  const NuevaOrdenPage({super.key, this.placaInicial});

  @override
  State<NuevaOrdenPage> createState() => _NuevaOrdenPageState();
}

class _NuevaOrdenPageState extends State<NuevaOrdenPage> {
  final _placa = TextEditingController();
  final _symptoms = TextEditingController();
  bool loading = false;

  bool get _placaBloqueada =>
      widget.placaInicial != null && widget.placaInicial!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();

    if (_placaBloqueada) {
      _placa.text = widget.placaInicial!.trim().toUpperCase();
    }
  }

  @override
  void dispose() {
    _placa.dispose();
    _symptoms.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final placa = _placa.text.trim().toUpperCase();
    final symptoms = _symptoms.text.trim();

    if (placa.isEmpty || symptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa placa y síntomas'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await ApiService.crearOrden(placa: placa, symptoms: symptoms);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Nueva OT',
          style: TextStyle(fontFamily: 'BBH_Sans_Bogle', color: Colors.black),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _placa,
              enabled: !_placaBloqueada, // ✅ bloquea si viene desde Vehículos
              style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
              decoration: InputDecoration(
                labelText: 'Placa',
                labelStyle: const TextStyle(color: Colors.green),
                enabledBorder:
                    const OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                focusedBorder:
                    const OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                disabledBorder:
                    const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                hintText: _placaBloqueada ? null : 'Ej: PBC1234',
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _symptoms,
              maxLines: 6,
              style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
              decoration: const InputDecoration(
                labelText: 'Síntomas reportados por el cliente',
                labelStyle: TextStyle(color: Colors.green),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.black,
                ),
                onPressed: loading ? null : _crear,
                child: Text(
                  loading ? 'Creando...' : 'Crear Orden',
                  style: const TextStyle(
                    fontFamily: 'BBH_Sans_Bogle',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
