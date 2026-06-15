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
  await Session.loadSession();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  String _initialRoute() {
    final hasToken = (Session.token != null && Session.token!.trim().isNotEmpty);
    final hasUser  = (Session.user  != null);
    return (hasToken && hasUser) ? '/inicio' : '/login';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RevUp',

      // ── Tema global RevUp ──────────────────────────────────────────────────
      theme: ThemeData(
        fontFamily: 'Ubuntu',
        scaffoldBackgroundColor: const Color(0xFF04060D),
        primaryColor: const Color(0xFF1E90FF),
        colorScheme: const ColorScheme.dark(
          primary:   Color(0xFF1E90FF),
          secondary: Color(0xFF0A5FCC),
          surface:   Color(0xFF080E1A),
          error:     Colors.redAccent,
        ),

        // AppBar — cada página lo sobreescribe con su propio diseño,
        // pero esto evita que alguna página sin estilo propio use el verde viejo
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF060B18),
          foregroundColor: Color(0xFFF0F4FF),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Ubuntu',
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 2,
            color: Color(0xFFF0F4FF),
          ),
          iconTheme: IconThemeData(color: Color(0xFF1E90FF)),
        ),

        // Texto global
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            fontFamily: 'Ubuntu',
            color: Color(0xFFF0F4FF),
            fontSize: 15,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Ubuntu',
            color: Color(0x99F0F4FF),   // kWhite al 60%
            fontSize: 13,
          ),
          bodySmall: TextStyle(
            fontFamily: 'Ubuntu',
            color: Color(0x66F0F4FF),   // kWhite al 40%
            fontSize: 11,
          ),
        ),

        // Inputs globales
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E90FF).withOpacity(0.05),
          labelStyle: TextStyle(
            fontFamily: 'Ubuntu',
            color: const Color(0xFF1E90FF).withOpacity(0.85),
            fontSize: 13,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: const Color(0xFF1E90FF).withOpacity(0.25)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1E90FF), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
        ),

        // SnackBar global
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF0A5FCC),
          contentTextStyle: const TextStyle(
            fontFamily: 'Ubuntu', color: Colors.white, fontSize: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        ),

        // Switch global
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? const Color(0xFF1E90FF)
                : const Color(0xFFF0F4FF).withOpacity(0.30)),
          trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? const Color(0xFF1E90FF).withOpacity(0.25)
                : const Color(0xFFF0F4FF).withOpacity(0.08)),
        ),

        // Progress indicator global
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF1E90FF),
        ),

        // Divider global
        dividerTheme: DividerThemeData(
          color: const Color(0xFF1E90FF).withOpacity(0.10),
          thickness: 1,
        ),

        useMaterial3: true,
      ),

      // ── Rutas ─────────────────────────────────────────────────────────────
      initialRoute: _initialRoute(),

      routes: {
        '/login':            (_) => const LoginPage(),
        '/register':         (_) => const RegisterPage(),
        '/inicio':           (_) => const InicioPage(),
        '/perfil':           (_) => const PerfilPage(),
        '/editarperfil':     (_) => const EditarPerfilPage(),
        '/vehiculos':        (_) => const VehiculosPage(),
        '/agregar_vehiculo': (_) => const AgregarVehiculoPage(),
        '/scanqr':           (_) => ScanQRPage(),
        '/detalle_qr':       (_) => const DetalleQRPage(),
        '/forgot_password':  (_) => const ForgotPasswordPage(),
        '/forgot_username':  (_) => const ForgotUsernamePage(),
        '/ordenes':          (_) => const OrdenesPage(),
        '/nueva_orden':      (_) => const NuevaOrdenPage(),
        '/reportes':         (_) => const ReportesPage(),
      },

      onGenerateRoute: (settings) {
        if (settings.name == '/detalle_orden') {
          final args = settings.arguments;

          if (args is int) {
            return MaterialPageRoute(
              builder: (_) => DetalleOrdenPage(ordenId: args));
          }

          if (args is String) {
            final id = int.tryParse(args);
            if (id != null) {
              return MaterialPageRoute(
                builder: (_) => DetalleOrdenPage(ordenId: id));
            }
          }

          // Fallback de error — también con el nuevo estilo
          return MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: const Color(0xFF04060D),
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: const Text("ERROR",
                  style: TextStyle(
                    fontFamily: 'Ubuntu', color: Color(0xFFF0F4FF),
                    fontWeight: FontWeight.w800, letterSpacing: 2)),
              ),
              body: Center(
                child: Text(
                  "Falta ordenId para abrir Detalle OT",
                  style: TextStyle(
                    fontFamily: 'Ubuntu',
                    color: Colors.redAccent.withOpacity(0.70),
                    fontSize: 13),
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