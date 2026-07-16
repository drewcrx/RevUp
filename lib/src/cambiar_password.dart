import 'package:flutter/material.dart';
import 'api_service.dart';
import 'password_utils.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);

class CambiarPasswordPage extends StatefulWidget {
  const CambiarPasswordPage({super.key});
  @override
  State<CambiarPasswordPage> createState() => _CambiarPasswordPageState();
}

class _CambiarPasswordPageState extends State<CambiarPasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _actualCtrl  = TextEditingController();
  final _nuevaCtrl   = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _verActual   = false;
  bool _verNueva    = false;
  bool _verConfirm  = false;
  bool _guardando   = false;

  @override
  void dispose() {
    _actualCtrl.dispose();
    _nuevaCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    final error = await ApiService.cambiarPassword(
      currentPassword: _actualCtrl.text,
      newPassword: _nuevaCtrl.text,
    );
    if (!mounted) return;
    setState(() => _guardando = false);

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Contraseña actualizada correctamente",
          style: TextStyle(fontFamily: 'Ubuntu')),
        backgroundColor: _kBlueDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error, style: const TextStyle(fontFamily: 'Ubuntu')),
      backgroundColor: Colors.red.shade900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  InputDecoration _fieldDec(String label, {
    required bool obscure,
    required VoidCallback onToggle,
  }) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(fontFamily: 'Ubuntu',
      color: _kBlue.withOpacity(0.85), fontSize: 13, letterSpacing: 0.5),
    prefixIcon: Icon(Icons.lock_outline_rounded,
      color: _kBlue.withOpacity(0.75), size: 20),
    suffixIcon: IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        color: _kWhite.withOpacity(0.35), size: 19),
      onPressed: onToggle,
    ),
    filled: true,
    fillColor: _kBlue.withOpacity(0.06),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: BorderSide(color: _kBlue.withOpacity(0.28))),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: _kBlue, width: 1.5)),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: Colors.redAccent)),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
    errorStyle: const TextStyle(fontFamily: 'Ubuntu', color: Colors.redAccent, fontSize: 11),
  );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(fontFamily: 'Ubuntu',
        textTheme: const TextTheme().apply(fontFamily: 'Ubuntu')),
      child: Scaffold(
        backgroundColor: _kBg,

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
            onPressed: _guardando ? null : () => Navigator.pop(context, false),
          ),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
              decoration: const BoxDecoration(color: _kBlue, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text("CAMBIAR CONTRASEÑA", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.8)),
          ]),
          centerTitle: true,
        ),

        body: Stack(children: [
          Positioned.fill(child: const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF060B18), _kBg, Color(0xFF030509)]),
          ))),
          Positioned(top: -80, right: -60, child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_kBlue.withOpacity(0.08), Colors.transparent])),
          )),

          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
              children: [

                Center(child: Column(children: [
                  Container(width: 68, height: 68,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: _kBlue.withOpacity(0.08),
                      border: Border.all(color: _kBlue.withOpacity(0.26), width: 1.5)),
                    child: const Icon(Icons.password_rounded, color: _kBlue, size: 30)),
                  const SizedBox(height: 12),
                  const Text("Actualiza tu contraseña", style: TextStyle(
                    fontFamily: 'Ubuntu', color: _kWhite,
                    fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text("Confirma tu contraseña actual para continuar",
                    style: TextStyle(fontFamily: 'Ubuntu',
                      color: _kWhite.withOpacity(0.38), fontSize: 12)),
                ])),

                const SizedBox(height: 30),

                TextFormField(
                  controller: _actualCtrl,
                  obscureText: !_verActual,
                  style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
                  decoration: _fieldDec("Contraseña actual",
                    obscure: !_verActual,
                    onToggle: () => setState(() => _verActual = !_verActual)),
                  validator: (v) =>
                    (v == null || v.isEmpty) ? "Ingresa tu contraseña actual" : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _nuevaCtrl,
                  obscureText: !_verNueva,
                  style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
                  decoration: _fieldDec("Nueva contraseña",
                    obscure: !_verNueva,
                    onToggle: () => setState(() => _verNueva = !_verNueva)),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Ingresa la nueva contraseña";
                    final err = validarPasswordFuerte(v);
                    if (err != null) return err;
                    if (v == _actualCtrl.text) return "Debe ser distinta a la actual";
                    return null;
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(kPasswordHint, style: TextStyle(
                    fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.30),
                    fontSize: 11)),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: !_verConfirm,
                  style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
                  decoration: _fieldDec("Confirmar nueva contraseña",
                    obscure: !_verConfirm,
                    onToggle: () => setState(() => _verConfirm = !_verConfirm)),
                  validator: (v) =>
                    (v != _nuevaCtrl.text) ? "Las contraseñas no coinciden" : null,
                ),

                const SizedBox(height: 30),

                GestureDetector(
                  onTap: _guardando ? null : _guardar,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: _guardando ? null
                          : const LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [Color(0xFF2AA0FF), _kBlueDark]),
                      color: _guardando ? Colors.white10 : null,
                      boxShadow: _guardando ? null : [BoxShadow(
                        color: _kBlue.withOpacity(0.38),
                        blurRadius: 18, offset: const Offset(0, 5))],
                    ),
                    child: Center(child: _guardando
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                        : const Text("ACTUALIZAR CONTRASEÑA", style: TextStyle(
                            fontFamily: 'Ubuntu', color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13, letterSpacing: 1.5))),
                  ),
                ),

                const SizedBox(height: 18),

                Center(child: TextButton(
                  onPressed: _guardando
                      ? null
                      : () => Navigator.pushNamed(context, '/forgot_password'),
                  child: Text("¿No recuerdas tu contraseña actual? Recupérala por correo",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Ubuntu',
                      color: _kBlue.withOpacity(0.65), fontSize: 12)),
                )),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
