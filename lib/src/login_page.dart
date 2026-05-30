import 'package:flutter/material.dart';
import 'api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();

  static const green = Colors.green;
  bool _loading = false;

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _loading = true);

    final identidad = _identityController.text.trim();
    final password = _passwordController.text.trim();

    // Backend acepta usuario O correo (mismo campo)
    final error = await ApiService.loginUsuario(
      usuario: identidad,
      password: password,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    // ✅ Login OK
    if (error == null) {
      Navigator.pushReplacementNamed(context, '/inicio');
      return;
    }

    final lower = error.toLowerCase();

    // ✅ Caso: cuenta no verificada
    if (lower.contains("no verificada")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Cuenta no verificada. ¿Reenviar enlace de activación?"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: "REENVIAR",
            textColor: Colors.white,
            onPressed: () async {
              final correo = _identityController.text.trim();

              // Solo reenviamos si parece correo
              if (!correo.contains("@")) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Ingresa tu correo para reenviar el enlace."),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final msg = await ApiService.resendVerification(correo: correo);
              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg ?? "Si el correo existe, te enviamos el enlace."),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    // ❌ Otros errores
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themed = Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
              fontFamily: 'BBH_Sans_Bogle',
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: green, fontFamily: 'BBH_Sans_Bogle'),
          errorStyle: TextStyle(color: Colors.red, fontFamily: 'BBH_Sans_Bogle'),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: green),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: green, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red, width: 1.5),
          ),
        ),
      ),
      child: _buildForm(context),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(child: themed),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/2.png', height: 300),
          const SizedBox(height: 30),

          // Usuario o correo
          TextFormField(
            controller: _identityController,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'BBH_Sans_Bogle',
            ),
            decoration: const InputDecoration(
              labelText: "Usuario o correo",
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa tu usuario o correo';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Contraseña
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'BBH_Sans_Bogle',
            ),
            decoration: const InputDecoration(
              labelText: "Contraseña",
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'Por favor ingresa tu contraseña';
              if (v.length < 6) return 'Debe tener al menos 6 caracteres';
              return null;
            },
          ),

          const SizedBox(height: 30),

          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: _loading ? null : _doLogin,
            child: Text(
              _loading ? "Ingresando..." : "Iniciar sesión",
              style: const TextStyle(
                fontFamily: 'BBH_Sans_Bogle',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 15),

          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/forgot_password'),
            child: const Text(
              "¿Olvidaste tu contraseña?",
              style: TextStyle(
                color: Colors.green,
                fontFamily: 'BBH_Sans_Bogle',
                fontSize: 15,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/forgot_username'),
            child: const Text(
              "¿Olvidaste tu usuario?",
              style: TextStyle(
                color: Colors.green,
                fontFamily: 'BBH_Sans_Bogle',
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/register'),
            child: const Text(
              "¿No tienes cuenta? Regístrate",
              style: TextStyle(
                color: Colors.green,
                fontFamily: 'BBH_Sans_Bogle',
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
