import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'session.dart';
import 'api_service.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);
const _kCard     = Color(0xFF080E1A);

class EditarPerfilPage extends StatefulWidget {
  const EditarPerfilPage({super.key});
  @override
  State<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<EditarPerfilPage> {
  // ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
  final _formKey = GlobalKey<FormState>();
  final _picker  = ImagePicker();

  late TextEditingController _nombreCtrl;
  String  correo    = '';
  String? avatarB64;
  bool    saving    = false;

  @override
  void initState() {
    super.initState();
    final u = Session.user;
    _nombreCtrl = TextEditingController(text: (u?['nombre'] ?? '').toString());
    correo      = (u?['correo'] ?? '').toString();
    avatarB64   = u?['avatar_b64']?.toString();
  }

  @override
  void dispose() { _nombreCtrl.dispose(); super.dispose(); }

  ImageProvider? _avatarProvider() {
    final b64raw = (avatarB64 ?? '').trim();
    if (b64raw.isEmpty) return null;
    final cleaned = b64raw.contains(',') ? b64raw.split(',').last : b64raw;
    try { return MemoryImage(base64Decode(cleaned)); } catch (_) { return null; }
  }

  Future<void> _pickAvatar() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      setState(() => avatarB64 = base64Encode(bytes));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("No se pudo seleccionar imagen: $e",
          style: const TextStyle(fontFamily: 'Ubuntu')),
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final nuevoNombre = _nombreCtrl.text.trim();
      if (nuevoNombre.isEmpty) throw Exception("Nombre inválido");
      await ApiService.actualizarPerfil(nombre: nuevoNombre, avatarB64: avatarB64 ?? '');
      await Session.updateNombre(nuevoNombre);
      await Session.updateAvatarB64(avatarB64);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Perfil actualizado",
          style: TextStyle(fontFamily: 'Ubuntu')),
        backgroundColor: _kBlueDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString(), style: const TextStyle(fontFamily: 'Ubuntu')),
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
  // ═════════════════════════════════════════════════════════════════════════ //

  InputDecoration _fieldDec(String label, IconData icon, {bool readOnly = false}) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Ubuntu',
          color: readOnly ? _kWhite.withOpacity(0.25) : _kBlue.withOpacity(0.85),
          fontSize: 13, letterSpacing: 0.8),
        prefixIcon: Icon(icon,
          color: readOnly ? _kWhite.withOpacity(0.20) : _kBlue.withOpacity(0.75),
          size: 20),
        filled: true,
        fillColor: readOnly ? _kWhite.withOpacity(0.02) : _kBlue.withOpacity(0.06),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(
            color: readOnly ? _kWhite.withOpacity(0.08) : _kBlue.withOpacity(0.28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: _kBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(
          fontFamily: 'Ubuntu', color: Colors.redAccent, fontSize: 11),
      );

  @override
  Widget build(BuildContext context) {
    final avatar  = _avatarProvider();
    final initial = _nombreCtrl.text.isNotEmpty
        ? _nombreCtrl.text[0].toUpperCase() : "U";

    return Theme(
      data: ThemeData(
        fontFamily: 'Ubuntu',
        textTheme: const TextTheme().apply(fontFamily: 'Ubuntu')),
      child: Scaffold(
        backgroundColor: _kBg,

        // ── AppBar ──────────────────────────────────────────────────────────
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0A1628), Color(0xFF060B18)]),
          )),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent, _kBlue.withOpacity(0.35), Colors.transparent]))),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kBlue, size: 20),
            onPressed: saving ? null : () => Navigator.pop(context, false),
          ),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
              decoration: const BoxDecoration(color: _kBlue, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text("EDITAR PERFIL", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 2)),
          ]),
          centerTitle: true,
        ),

        // ── Body ────────────────────────────────────────────────────────────
        body: Stack(children: [
          Positioned.fill(child: const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF060B18), _kBg, Color(0xFF030509)]),
          ))),
          Positioned(top: -100, right: -80, child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_kBlue.withOpacity(0.07), Colors.transparent])),
          )),

          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
              children: [

                // ── Avatar ────────────────────────────────────────────────
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      // Glow
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: _kBlue.withOpacity(0.22),
                            blurRadius: 28, spreadRadius: 2)],
                        ),
                      ),
                      // Avatar
                      Container(
                        width: 110, height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: avatar == null
                              ? const LinearGradient(
                                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                                  colors: [Color(0xFF2AA0FF), _kBlueDark])
                              : null,
                          border: Border.all(color: _kBlue.withOpacity(0.30), width: 2),
                        ),
                        child: avatar != null
                            ? ClipOval(child: Image(image: avatar, fit: BoxFit.cover))
                            : Center(child: Text(initial, style: const TextStyle(
                                fontFamily: 'Ubuntu', color: Colors.white,
                                fontWeight: FontWeight.w800, fontSize: 42))),
                      ),
                      // Botón editar
                      Positioned(
                        right: 0, bottom: 2,
                        child: GestureDetector(
                          onTap: _pickAvatar,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2AA0FF), _kBlueDark]),
                              border: Border.all(color: _kBg, width: 2),
                              boxShadow: [BoxShadow(
                                color: _kBlue.withOpacity(0.40), blurRadius: 8)],
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 17),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Texto guía bajo el avatar
                Center(child: Text(
                  "Toca el ícono para cambiar foto",
                  style: TextStyle(
                    fontFamily: 'Ubuntu',
                    color: _kWhite.withOpacity(0.28), fontSize: 11),
                )),

                const SizedBox(height: 30),

                // ── Campo nombre ─────────────────────────────────────────
                TextFormField(
                  controller: _nombreCtrl,
                  style: const TextStyle(
                    fontFamily: 'Ubuntu', color: _kWhite,
                    fontSize: 14, letterSpacing: 0.4),
                  decoration: _fieldDec("Nombre", Icons.person_outline_rounded),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Ingresa tu nombre";
                    if (v.trim().length < 2) return "Nombre muy corto";
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // ── Campo correo (solo lectura) ───────────────────────────
                TextFormField(
                  initialValue: correo,
                  readOnly: true,
                  style: TextStyle(
                    fontFamily: 'Ubuntu',
                    color: _kWhite.withOpacity(0.35), fontSize: 14),
                  decoration: _fieldDec(
                    "Correo (solo lectura)", Icons.email_outlined, readOnly: true),
                ),

                const SizedBox(height: 10),

                // Nota correo
                Row(children: [
                  Icon(Icons.info_outline_rounded,
                    color: _kWhite.withOpacity(0.20), size: 13),
                  const SizedBox(width: 5),
                  Text("El correo no puede modificarse",
                    style: TextStyle(
                      fontFamily: 'Ubuntu',
                      color: _kWhite.withOpacity(0.22), fontSize: 11)),
                ]),

                const SizedBox(height: 32),

                // ── Botones ───────────────────────────────────────────────
                Row(children: [
                  // Cancelar
                  Expanded(child: GestureDetector(
                    onTap: saving ? null : () => Navigator.pop(context, false),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBlue.withOpacity(0.30), width: 1),
                        color: _kBlue.withOpacity(0.06),
                      ),
                      child: Center(child: Text("CANCELAR", style: TextStyle(
                        fontFamily: 'Ubuntu',
                        color: _kWhite.withOpacity(0.55),
                        fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1.5))),
                    ),
                  )),

                  const SizedBox(width: 12),

                  // Guardar
                  Expanded(child: GestureDetector(
                    onTap: saving ? null : _guardar,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: saving
                            ? null
                            : const LinearGradient(
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                                colors: [Color(0xFF2AA0FF), _kBlueDark]),
                        color: saving ? Colors.white10 : null,
                        boxShadow: saving ? null : [BoxShadow(
                          color: _kBlue.withOpacity(0.38),
                          blurRadius: 16, offset: const Offset(0, 4))],
                      ),
                      child: Center(child: saving
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                          : const Text("GUARDAR", style: TextStyle(
                              fontFamily: 'Ubuntu', color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13, letterSpacing: 2))),
                    ),
                  )),
                ]),

                // Nota web
                if (kIsWeb) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBlue.withOpacity(0.12)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.info_outline_rounded, color: _kBlue.withOpacity(0.50), size: 15),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        "En web la foto se guarda como base64 en la sesión, no como archivo local.",
                        style: TextStyle(
                          fontFamily: 'Ubuntu',
                          color: _kWhite.withOpacity(0.28), fontSize: 11, height: 1.5),
                      )),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}