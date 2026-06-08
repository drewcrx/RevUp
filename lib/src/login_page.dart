import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'api_service.dart';

// ─── Painter: velocímetro + líneas de velocidad ──────────────────────────────
class RacingBackgroundPainter extends CustomPainter {
  final double progress;
  RacingBackgroundPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);

    // Líneas de velocidad (streaks)
    final streakPaint = Paint()..strokeCap = StrokeCap.round;
    for (int i = 0; i < 22; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final len = 50.0 + rng.nextDouble() * 130;
      final pulse = math.sin(progress * math.pi * 2 + i * 0.5) * 0.5 + 0.5;
      final opacity = (0.03 + rng.nextDouble() * 0.07) * pulse;

      streakPaint
        ..color = Color.lerp(
          const Color(0xFF1E90FF),
          const Color(0xFF00BFFF),
          rng.nextDouble(),
        )!.withOpacity(opacity)
        ..strokeWidth = 0.6 + rng.nextDouble() * 1.8;

      canvas.drawLine(
        Offset(x, y),
        Offset(x - len, y + len * 0.08),
        streakPaint,
      );
    }

    // Arco de velocímetro decorativo (esquina superior derecha)
    final arcCenter = Offset(size.width + 40, -40);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final radius = 110.0 + i * 38;
      final sweepProgress = (progress + i * 0.15) % 1.0;
      final opacity = 0.07 + i * 0.03;
      arcPaint.color = const Color(0xFF1E90FF).withOpacity(opacity);

      canvas.drawArc(
        Rect.fromCircle(center: arcCenter, radius: radius),
        math.pi * 0.6,
        math.pi * 0.9 * sweepProgress,
        false,
        arcPaint,
      );
    }

    // Marcas de velocímetro (ticks)
    final tickPaint = Paint()
      ..color = const Color(0xFF1E90FF).withOpacity(0.12)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 12; i++) {
      final angle = math.pi * 0.6 + (math.pi * 0.9 / 11) * i;
      final r1 = 138.0;
      final r2 = i % 3 == 0 ? 126.0 : 131.0;
      canvas.drawLine(
        Offset(arcCenter.dx + math.cos(angle) * r1,
            arcCenter.dy + math.sin(angle) * r1),
        Offset(arcCenter.dx + math.cos(angle) * r2,
            arcCenter.dy + math.sin(angle) * r2),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(RacingBackgroundPainter old) => old.progress != progress;
}

// ─── Fondo animado ─────────────────────────────────────────────────────────
class AnimatedRacingBackground extends StatefulWidget {
  const AnimatedRacingBackground({super.key});
  @override
  State<AnimatedRacingBackground> createState() =>
      _AnimatedRacingBackgroundState();
}

class _AnimatedRacingBackgroundState extends State<AnimatedRacingBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: RacingBackgroundPainter(_ctrl.value),
          size: Size.infinite,
        ),
      );
}

// ─── Login Page ──────────────────────────────────────────────────────────────
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;

  // Paleta sacada del logo
  static const kBlue = Color(0xFF1E90FF);       // azul eléctrico principal
  static const kBlueDark = Color(0xFF0A5FCC);   // azul más oscuro
  static const kBlueGlow = Color(0xFF00BFFF);   // deepskyblue para brillos
  static const kWhite = Color(0xFFF0F4FF);      // blanco ligeramente frío
  static const kBg = Color(0xFF04060D);         // negro azulado profundo

  // Animaciones de entrada
  late AnimationController _entryCtr;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _formSlide;
  late Animation<double> _formFade;
  late Animation<Offset> _btnSlide;
  late Animation<double> _btnFade;

  @override
  void initState() {
    super.initState();
    _entryCtr = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtr,
          curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtr,
          curve: const Interval(0.0, 0.32, curve: Curves.easeIn)),
    );
    _formSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _entryCtr,
          curve: const Interval(0.32, 0.72, curve: Curves.easeOutCubic)),
    );
    _formFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtr,
          curve: const Interval(0.32, 0.68, curve: Curves.easeIn)),
    );
    _btnSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _entryCtr,
          curve: const Interval(0.62, 1.0, curve: Curves.easeOutCubic)),
    );
    _btnFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtr,
          curve: const Interval(0.62, 0.95, curve: Curves.easeIn)),
    );

    _entryCtr.forward();
  }

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    _entryCtr.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontFamily: 'Ubuntu', color: kBlue.withOpacity(0.85), fontSize: 13, letterSpacing: 0.8),
      prefixIcon: Icon(icon, color: kBlue.withOpacity(0.8), size: 20),
      filled: true,
      fillColor: kBlue.withOpacity(0.06),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: kBlue.withOpacity(0.3), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      errorStyle: const TextStyle(fontFamily: 'Ubuntu', color: Colors.redAccent, fontSize: 11),
    );
  }

  Future<void> _doLogin() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _loading = true);

    final error = await ApiService.loginUsuario(
      usuario: _identityController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error == null) {
      Navigator.pushReplacementNamed(context, '/inicio');
      return;
    }

    final lower = error.toLowerCase();
    if (lower.contains("no verificada")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              "Cuenta no verificada. ¿Reenviar enlace de activación?"),
          backgroundColor: Colors.red.shade900,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: "REENVIAR",
            textColor: kBlueGlow,
            onPressed: () async {
              final correo = _identityController.text.trim();
              if (!correo.contains("@")) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Ingresa tu correo para reenviar el enlace."),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              final msg =
                  await ApiService.resendVerification(correo: correo);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text(msg ?? "Si el correo existe, te enviamos el enlace."),
                backgroundColor: kBlueDark,
              ));
            },
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red.shade900));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        fontFamily: 'Ubuntu',
        textTheme: const TextTheme().apply(fontFamily: 'Ubuntu'),
      ),
      child: Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // — Gradiente de fondo —
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF060B18),
                    Color(0xFF04060D),
                    Color(0xFF030509),
                  ],
                ),
              ),
            ),
          ),

          // — Halo azul superior derecha (simula iluminación del logo) —
          Positioned(
            top: -160,
            right: -120,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kBlue.withOpacity(0.13),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // — Halo azul inferior izquierda —
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kBlueDark.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // — Fondo animado (líneas + velocímetro) —
          const Positioned.fill(child: AnimatedRacingBackground()),

          // — Línea horizontal decorativa a 40% del alto —
          Positioned(
            top: MediaQuery.of(context).size.height * 0.38,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    kBlue.withOpacity(0.15),
                    kBlue.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // — Contenido principal —
          Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo animado
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Column(
                          children: [
                            // Glow detrás del logo
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 180,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: kBlue.withOpacity(0.18),
                                        blurRadius: 60,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                                Image.asset(
                                  'assets/images/RevUp2.png',
                                  height: 200,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Tagline
                            Text(
                              "MÁS CONTROL. MÁS RENDIMIENTO.",
                              style: TextStyle(fontFamily: 'Ubuntu', color: kBlue.withOpacity(0.55),
                                fontSize: 10,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Campos
                    SlideTransition(
                      position: _formSlide,
                      child: FadeTransition(
                        opacity: _formFade,
                        child: Column(
                          children: [
                            TextFormField(
                              key: const Key('identityField'),
                              controller: _identityController,
                              style: const TextStyle(fontFamily: 'Ubuntu', color: kWhite, fontSize: 14, letterSpacing: 0.4),
                              decoration: _fieldDecoration(
                                  "Usuario o correo", Icons.person_outline),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Ingresa tu usuario o correo'
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('passwordField'),
                              controller: _passwordController,
                              obscureText: _obscurePass,
                              style: const TextStyle(fontFamily: 'Ubuntu', color: kWhite, fontSize: 14, letterSpacing: 0.4),
                              decoration:
                                  _fieldDecoration("Contraseña", Icons.lock_outline)
                                      .copyWith(
                                suffixIcon: GestureDetector(
                                  onTap: () => setState(
                                      () => _obscurePass = !_obscurePass),
                                  child: Icon(
                                    _obscurePass
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: kBlue.withOpacity(0.55),
                                    size: 20,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                final val = (v ?? '').trim();
                                if (val.isEmpty) return 'Ingresa tu contraseña';
                                if (val.length < 6) return 'Mínimo 6 caracteres';
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.pushNamed(
                                    context, '/forgot_password'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  "¿Olvidaste tu contraseña?",
                                  style: TextStyle(fontFamily: 'Ubuntu', color: kBlue.withOpacity(0.65),
                                    fontSize: 12,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Botón y links
                    SlideTransition(
                      position: _btnSlide,
                      child: FadeTransition(
                        opacity: _btnFade,
                        child: Column(
                          children: [
                            // Botón principal con gradiente azul del logo
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: _loading
                                      ? null
                                      : const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF2AA0FF),
                                            Color(0xFF0A5FCC),
                                          ],
                                        ),
                                  color:
                                      _loading ? Colors.white10 : null,
                                  boxShadow: _loading
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: kBlue.withOpacity(0.40),
                                            blurRadius: 22,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                ),
                                child: ElevatedButton(
                                  key: const Key('loginButton'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _loading ? null : _doLogin,
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          "INICIAR SESIÓN",
                                          style: TextStyle(fontFamily: 'Ubuntu', color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            letterSpacing: 2.2,
                                          ),
                                        ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(
                                        color: kBlue.withOpacity(0.12),
                                        thickness: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  child: Text("o",
                                      style: TextStyle(fontFamily: 'Ubuntu', color: kBlue.withOpacity(0.3),
                                          fontSize: 12)),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: kBlue.withOpacity(0.12),
                                        thickness: 1)),
                              ],
                            ),

                            const SizedBox(height: 14),

                            TextButton(
                              onPressed: () => Navigator.pushNamed(
                                  context, '/forgot_username'),
                              child: Text(
                                "¿Olvidaste tu usuario?",
                                style: TextStyle(fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.38),
                                    fontSize: 13),
                              ),
                            ),

                            const SizedBox(height: 4),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "¿No tienes cuenta?  ",
                                  style: TextStyle(fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.35),
                                      fontSize: 13),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                      context, '/register'),
                                  child: const Text(
                                    "Regístrate",
                                    style: TextStyle(fontFamily: 'Ubuntu', color: kBlue,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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