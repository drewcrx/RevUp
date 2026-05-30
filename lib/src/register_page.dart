import 'package:flutter/material.dart';
import 'api_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isEmailValid(String s) {
    final v = s.trim();
    return v.contains('@') && v.contains('.') && !v.startsWith('@') && !v.endsWith('@');
  }

  Future<void> _doRegister() async {
    final nombre = _nombreController.text.trim();
    final correo = _correoController.text.trim();
    final usuario = _usuarioController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (nombre.isEmpty || correo.isEmpty || usuario.isEmpty || password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!_isEmailValid(correo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un correo válido'), backgroundColor: Colors.red),
      );
      return;
    }

    if (usuario.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El usuario debe tener al menos 3 caracteres'), backgroundColor: Colors.red),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres'), backgroundColor: Colors.red),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _loading = true);

    final error = await ApiService.registrarUsuario(
      nombre: nombre,
      correo: correo,
      usuario: usuario,
      password: password,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta creada. Revisa tu correo para activar tu cuenta.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Limpieza opcional (se ve pro)
      _passwordController.clear();
      _confirmPasswordController.clear();

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    const green = Colors.green;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "REGISTRARSE",
                    style: TextStyle(
                      color: green,
                      fontSize: 30,
                      fontFamily: 'BBH_Sans_Bogle',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),

                  _field(
                    controller: _nombreController,
                    label: "Nombre",
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 20),

                  _field(
                    controller: _correoController,
                    label: "Correo",
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),

                  _field(
                    controller: _usuarioController,
                    label: "Usuario",
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 20),

                  _field(
                    controller: _passwordController,
                    label: "Contraseña",
                    obscure: true,
                  ),
                  const SizedBox(height: 20),

                  _field(
                    controller: _confirmPasswordController,
                    label: "Confirmar contraseña",
                    obscure: true,
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: 240,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: green),
                      onPressed: _loading ? null : _doRegister,
                      child: Text(
                        _loading ? "Creando..." : "Crear cuenta",
                        style: const TextStyle(
                          fontFamily: 'BBH_Sans_Bogle',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text(
                      "¿Ya tienes cuenta? Inicia sesión",
                      style: TextStyle(color: green, fontFamily: 'BBH_Sans_Bogle'),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
  }) {
    const green = Colors.green;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
      decoration: const InputDecoration(
        labelStyle: TextStyle(color: green, fontFamily: 'BBH_Sans_Bogle'),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: green)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: green, width: 1.5)),
      ).copyWith(labelText: label),
    );
  }
}
