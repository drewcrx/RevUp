import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'session.dart';

class EditarPerfilPage extends StatefulWidget {
  const EditarPerfilPage({super.key});

  @override
  State<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<EditarPerfilPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  static const green = Color(0xFF4CAF50);

  late TextEditingController _nombreCtrl;
  String correo = '';
  String? avatarB64;

  bool saving = false;

  @override
  void initState() {
    super.initState();
    final u = Session.user;
    _nombreCtrl = TextEditingController(text: (u?['nombre'] ?? '').toString());
    correo = (u?['correo'] ?? '').toString();
    avatarB64 = u?['avatar_b64']?.toString();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  ImageProvider? _avatarProvider() {
    final b64raw = (avatarB64 ?? '').trim();
    if (b64raw.isEmpty) return null;

    final cleaned = b64raw.contains(',') ? b64raw.split(',').last : b64raw;

    try {
      final bytes = base64Decode(cleaned);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // reduce peso
        maxWidth: 800,
      );

      if (xfile == null) return;

      // Funciona en web y móvil
      final bytes = await xfile.readAsBytes();
      final b64 = base64Encode(bytes);

      setState(() => avatarB64 = b64);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo seleccionar imagen: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => saving = true);

    try {
      final nuevoNombre = _nombreCtrl.text.trim();
      if (nuevoNombre.isEmpty) {
        throw Exception("Nombre inválido");
      }

      // Actualiza sesión local (y persistente)
      await Session.updateNombre(nuevoNombre);
      await Session.updateAvatarB64(avatarB64);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Perfil actualizado"),
          backgroundColor: green,
        ),
      );

      Navigator.pop(context, true); // clave: devuelve 'true' para recargar Perfil
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarProvider();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: green,
        foregroundColor: Colors.black,
        title: const Text(
          'EDITAR PERFIL',
          style: TextStyle(fontFamily: 'BBH_Sans_Bogle', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 8),

              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.black,
                      backgroundImage: avatar,
                      child: avatar == null
                          ? const Icon(Icons.person, size: 60, color: Colors.white70)
                          : null,
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: InkWell(
                        onTap: _pickAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              TextFormField(
                controller: _nombreCtrl,
                style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                decoration: InputDecoration(
                  labelText: 'Nombre del mecánico',
                  labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'BBH_Sans_Bogle'),
                  prefixIcon: const Icon(Icons.person, color: green),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: green, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: green, width: 2),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Ingresa tu nombre";
                  if (v.trim().length < 2) return "Nombre muy corto";
                  return null;
                },
              ),

              const SizedBox(height: 18),

              TextFormField(
                initialValue: correo,
                readOnly: true,
                style: const TextStyle(color: Colors.white70, fontFamily: 'BBH_Sans_Bogle'),
                decoration: InputDecoration(
                  labelText: 'Correo (solo lectura)',
                  labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'BBH_Sans_Bogle'),
                  prefixIcon: const Icon(Icons.email, color: green),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24, width: 1.2),
                  ),
                ),
              ),

              const SizedBox(height: 26),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: green,
                        side: const BorderSide(color: green, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: saving ? null : () => Navigator.pop(context, false),
                      child: const Text(
                        'CANCELAR',
                        style: TextStyle(fontFamily: 'BBH_Sans_Bogle', fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: saving ? null : _guardar,
                      child: Text(
                        saving ? 'GUARDANDO...' : 'GUARDAR',
                        style: const TextStyle(fontFamily: 'BBH_Sans_Bogle', fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),

              if (kIsWeb) ...[
                const SizedBox(height: 18),
                const Text(
                  "Nota: en web la foto se guarda como base64 en la sesión (no como archivo local).",
                  style: TextStyle(color: Colors.white38, fontFamily: 'BBH_Sans_Bogle', fontSize: 12),
                  textAlign: TextAlign.center,
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}
