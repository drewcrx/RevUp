import 'package:flutter/material.dart';

import 'src/inicio.dart';
import 'src/perfil.dart';
import 'src/vehiculos.dart';
import 'src/editar_perfil.dart';
import 'src/agregar_vehiculo.dart';
import 'src/scan_qr_page.dart';
import 'src/detalle_qr_page.dart';
import 'src/login_page.dart';
import 'src/register_page.dart';
import 'src/forgot_password_page.dart';
import 'src/forgot_username_page.dart';
import 'src/ordenes.dart';
import 'src/nueva_orden.dart';
import 'src/detalle_orden.dart';
import 'src/reportes_page.dart';
import 'src/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Cargar user + token guardados (SharedPreferences)
  await Session.loadSession();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  String _initialRoute() {
    // ✅ Si hay token y user cargados => entrar directo al inicio
    final hasToken = (Session.token != null && Session.token!.trim().isNotEmpty);
    final hasUser = (Session.user != null);

    return (hasToken && hasUser) ? '/inicio' : '/login';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Backfire',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFF00A86B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF00A86B),
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'BBH_Sans_Bogle',
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            fontFamily: 'BBH_Sans_Bogle',
            color: Colors.white,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'BBH_Sans_Bogle',
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ),

      // ✅ AQUÍ está lo importante:
      initialRoute: _initialRoute(),

      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/inicio': (context) => const InicioPage(),
        '/perfil': (context) => const PerfilPage(),
        '/editarperfil': (context) => const EditarPerfilPage(),
        '/vehiculos': (context) => const VehiculosPage(),
        '/agregar_vehiculo': (context) => const AgregarVehiculoPage(),
        '/scanqr': (context) => ScanQRPage(),
        '/detalle_qr': (context) => const DetalleQRPage(),
        '/forgot_password': (context) => const ForgotPasswordPage(),
        '/forgot_username': (context) => const ForgotUsernamePage(),
        '/ordenes': (_) => const OrdenesPage(),
        '/nueva_orden': (_) => const NuevaOrdenPage(),
        '/reportes': (context) => const ReportesPage(),
      },

      onGenerateRoute: (settings) {
        if (settings.name == '/detalle_orden') {
          final args = settings.arguments;

          if (args is int) {
            return MaterialPageRoute(
              builder: (_) => DetalleOrdenPage(ordenId: args),
            );
          }

          if (args is String) {
            final id = int.tryParse(args);
            if (id != null) {
              return MaterialPageRoute(
                builder: (_) => DetalleOrdenPage(ordenId: id),
              );
            }
          }

          return MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.green,
                foregroundColor: Colors.black,
                title: const Text("ERROR"),
              ),
              body: const Center(
                child: Text(
                  "Falta ordenId para abrir Detalle OT",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        return null;
      },
    );
  }
}
