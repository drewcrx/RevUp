import 'package:flutter/material.dart';
import 'api_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _loading = true);

    final correo = _emailController.text.trim();
    final msg = await ApiService.forgotPassword(correo: correo);

    if (!mounted) return;

    setState(() => _loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg ?? "Si el correo existe, te enviamos un enlace."),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const green = Colors.green;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Recuperar Contraseña",
          style: TextStyle(fontFamily: 'BBH_Sans_Bogle', color: Colors.white),
        ),
        backgroundColor: green,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Ingresa tu correo para recibir un enlace de recuperación.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: green,
                      fontSize: 16,
                      fontFamily: 'BBH_Sans_Bogle',
                    ),
                  ),
                  const SizedBox(height: 28),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                    decoration: const InputDecoration(
                      labelText: "Correo electrónico",
                      labelStyle: TextStyle(color: green, fontFamily: 'BBH_Sans_Bogle'),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: green)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: green, width: 1.5)),
                      errorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                      focusedErrorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 1.5)),
                    ),
                    validator: (v) {
                      final s = (v ?? "").trim();
                      if (s.isEmpty) return "Ingresa tu correo";
                      if (!s.contains("@") || !s.contains(".")) return "Correo inválido";
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: 220,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: green),
                      onPressed: _loading ? null : _send,
                      child: Text(
                        _loading ? "Enviando..." : "Enviar",
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
          ),
        ),
      ),
    );
  }
}
