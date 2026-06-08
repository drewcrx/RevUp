import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'api_service.dart';

// ─── Painter: velocímetro + líneas de velocidad (igual al login) ─────────────
class RacingBackgroundPainter extends CustomPainter {
  final double progress;
  RacingBackgroundPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);

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

    final arcCenter = Offset(size.width + 40, -40);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final radius = 110.0 + i * 38;
      final sweepProgress = (progress + i * 0.15) % 1.0;
      arcPaint.color =
          const Color(0xFF1E90FF).withOpacity(0.07 + i * 0.03);
      canvas.drawArc(
        Rect.fromCircle(center: arcCenter, radius: radius),
        math.pi * 0.6,
        math.pi * 0.9 * sweepProgress,
        false,
        arcPaint,
      );
    }

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

// ─── Fondo animado ────────────────────────────────────────────────────────────
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

// ─── Forgot Password Page ─────────────────────────────────────────────────────
class ForgotUsernamePage extends StatefulWidget {
  const ForgotUsernamePage({super.key});
  @override
  State<ForgotUsernamePage> createState() => _ForgotUsernamePageState();
}

class _ForgotUsernamePageState extends State<ForgotUsernamePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false; // muestra feedback de éxito inline

  // Paleta idéntica al login
  static const kBlue     = Color(0xFF1E90FF);
  static const kBlueDark = Color(0xFF0A5FCC);
  static const kWhite    = Color(0xFFF0F4FF);
  static const kBg       = Color(0xFF04060D);

  // Animaciones de entrada
  late AnimationController _entryCtr;
  late Animation<double> _iconScale;
  late Animation<double> _iconFade;
  late Animation<Offset> _formSlide;
  late Animation<double> _formFade;
  late Animation<Offset> _btnSlide;
  late Animation<double> _btnFade;

  @override
  void initState() {
    super.initState();
    _entryCtr = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _iconScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtr,
          curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)),
    );
    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtr,
          curve: const Interval(0.0, 0.32, curve: Curves.easeIn)),
    );
    _formSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _entryCtr,
          curve: const Interval(0.30, 0.70, curve: Curves.easeOutCubic)),
    );
    _formFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtr,
          curve: const Interval(0.30, 0.65, curve: Curves.easeIn)),
    );
    _btnSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _entryCtr,
          curve: const Interval(0.60, 1.0, curve: Curves.easeOutCubic)),
    );
    _btnFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtr,
          curve: const Interval(0.60, 0.95, curve: Curves.easeIn)),
    );

    _entryCtr.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _entryCtr.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontFamily: 'Ubuntu',
        color: kBlue.withOpacity(0.85),
        fontSize: 13,
        letterSpacing: 0.8,
      ),
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
      errorStyle: const TextStyle(
          fontFamily: 'Ubuntu', color: Colors.redAccent, fontSize: 11),
    );
  }

  Future<void> _send() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _loading = true);

    final correo = _emailController.text.trim();
    final msg = await ApiService.forgotUsername(correo: correo);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _sent = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg ?? "Si el correo existe, te enviamos un enlace.",
          style: const TextStyle(fontFamily: 'Ubuntu'),
        ),
        backgroundColor: kBlueDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
        // AppBar translúcido coherente con el fondo
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: kBlue, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Recuperar usuario",
            style: TextStyle(
              fontFamily: 'Ubuntu',
              color: kWhite,
              fontSize: 16,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          // Línea inferior sutil
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    kBlue.withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
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

            // — Halo azul superior derecha —
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

            // — Fondo animado —
            const Positioned.fill(child: AnimatedRacingBackground()),

            // — Contenido —
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // — Ícono animado (candado con glow) —
                        FadeTransition(
                          opacity: _iconFade,
                          child: ScaleTransition(
                            scale: _iconScale,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glow
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        kBlue.withOpacity(0.20),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                // Círculo con borde
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: kBlue.withOpacity(0.08),
                                    border: Border.all(
                                      color: kBlue.withOpacity(0.30),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.manage_accounts_rounded,
                                    color: kBlue,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // — Título y descripción —
                        SlideTransition(
                          position: _formSlide,
                          child: FadeTransition(
                            opacity: _formFade,
                            child: Column(
                              children: [
                                const Text(
                                  "¿Olvidaste tu usuario?",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Ubuntu',
                                    color: kWhite,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "Ingresa tu correo registrado y te enviaremos tu nombre de usuario.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Ubuntu',
                                    color: kWhite.withOpacity(0.45),
                                    fontSize: 13,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // — Campo email —
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(
                                    fontFamily: 'Ubuntu',
                                    color: kWhite,
                                    fontSize: 14,
                                    letterSpacing: 0.4,
                                  ),
                                  decoration: _fieldDecoration(
                                      "Correo electrónico",
                                      Icons.email_outlined),
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) return 'Ingresa tu correo';
                                    if (!s.contains('@') || !s.contains('.')) {
                                      return 'Correo inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // — Botón + volver —
                        SlideTransition(
                          position: _btnSlide,
                          child: FadeTransition(
                            opacity: _btnFade,
                            child: Column(
                              children: [
                                // Botón principal
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(10),
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
                                      color: _loading
                                          ? Colors.white10
                                          : null,
                                      boxShadow: _loading
                                          ? null
                                          : [
                                              BoxShadow(
                                                color:
                                                    kBlue.withOpacity(0.40),
                                                blurRadius: 22,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: _loading ? null : _send,
                                      child: _loading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              "ENVIAR USUARIO",
                                              style: TextStyle(
                                                fontFamily: 'Ubuntu',
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14,
                                                letterSpacing: 2.2,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Volver al login
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "¿Ya lo recordaste?  ",
                                      style: TextStyle(
                                        fontFamily: 'Ubuntu',
                                        color: kWhite.withOpacity(0.35),
                                        fontSize: 13,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          Navigator.pop(context),
                                      child: const Text(
                                        "Inicia sesión",
                                        style: TextStyle(
                                          fontFamily: 'Ubuntu',
                                          color: kBlue,
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
            ),
          ],
        ),
      ),
    );
  }
}