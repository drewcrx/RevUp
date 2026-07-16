import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'api_service.dart';
import 'password_utils.dart';

// ─── Painter: velocímetro + líneas de velocidad (compartido) ─────────────────
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
      arcPaint.color = const Color(0xFF1E90FF).withOpacity(0.07 + i * 0.03);
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
      const r1 = 138.0;
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
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
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

// ─── Register Page ────────────────────────────────────────────────────────────
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _nombreController      = TextEditingController();
  final _correoController      = TextEditingController();
  final _usuarioController     = TextEditingController();
  final _passwordController    = TextEditingController();
  final _confirmPwController   = TextEditingController();

  bool _loading       = false;
  bool _obscurePw     = true;
  bool _obscureConfirm = true;

  // Paleta
  static const kBlue     = Color(0xFF1E90FF);
  static const kBlueDark = Color(0xFF0A5FCC);
  static const kWhite    = Color(0xFFF0F4FF);
  static const kBg       = Color(0xFF04060D);

  // Animaciones escalonadas — header + 5 campos + botón = 7 bloques
  late AnimationController _entryCtr;
  final List<Animation<double>>  _fadeAnims  = [];
  final List<Animation<Offset>>  _slideAnims = [];

  static const _totalBlocks = 7; // header, campo×5, botón-bloque

  @override
  void initState() {
    super.initState();
    _entryCtr = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Cada bloque ocupa un 20% del timeline con solapamiento del 10%
    for (int i = 0; i < _totalBlocks; i++) {
      final start = (i * 0.13).clamp(0.0, 0.85);
      final end   = (start + 0.30).clamp(0.0, 1.0);

      _fadeAnims.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _entryCtr,
            curve: Interval(start, end, curve: Curves.easeIn),
          ),
        ),
      );
      _slideAnims.add(
        Tween<Offset>(begin: const Offset(0, 0.28), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryCtr,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        ),
      );
    }

    _entryCtr.forward();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    _confirmPwController.dispose();
    _entryCtr.dispose();
    super.dispose();
  }

  // ── Validaciones ───────────────────────────────────────────────────────────
  bool _isEmailValid(String s) {
    final v = s.trim();
    return v.contains('@') && v.contains('.') &&
        !v.startsWith('@') && !v.endsWith('@');
  }

  Future<void> _doRegister() async {
    final nombre   = _nombreController.text.trim();
    final correo   = _correoController.text.trim();
    final usuario  = _usuarioController.text.trim();
    final password = _passwordController.text.trim();
    final confirm  = _confirmPwController.text.trim();

    void snack(String msg, {bool error = true}) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Ubuntu')),
        backgroundColor: error ? Colors.red.shade900 : kBlueDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }

    if ([nombre, correo, usuario, password, confirm].any((e) => e.isEmpty)) {
      snack('Completa todos los campos'); return;
    }
    if (!_isEmailValid(correo)) {
      snack('Ingresa un correo válido'); return;
    }
    if (usuario.length < 3) {
      snack('El usuario debe tener al menos 3 caracteres'); return;
    }
    final errorPassword = validarPasswordFuerte(password);
    if (errorPassword != null) {
      snack(errorPassword); return;
    }
    if (password != confirm) {
      snack('Las contraseñas no coinciden'); return;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          'Cuenta creada. Revisa tu correo para activarla.',
          style: TextStyle(fontFamily: 'Ubuntu'),
        ),
        backgroundColor: kBlueDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ));
      _passwordController.clear();
      _confirmPwController.clear();
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error, style: const TextStyle(fontFamily: 'Ubuntu')),
      backgroundColor: Colors.red.shade900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Decoración de campos ───────────────────────────────────────────────────
  InputDecoration _dec(String label, IconData icon) => InputDecoration(
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
          borderSide: BorderSide(color: kBlue.withOpacity(0.3)),
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

  // ── Widget animado por bloque ──────────────────────────────────────────────
  Widget _animated(int index, Widget child) => SlideTransition(
        position: _slideAnims[index],
        child: FadeTransition(opacity: _fadeAnims[index], child: child),
      );

  // ── Campo con toggle de visibilidad opcional ───────────────────────────────
  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    bool obscureValue = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure ? obscureValue : false,
      style: const TextStyle(
          fontFamily: 'Ubuntu', color: kWhite, fontSize: 14, letterSpacing: 0.4),
      decoration: _dec(label, icon).copyWith(
        suffixIcon: obscure
            ? GestureDetector(
                onTap: onToggleObscure,
                child: Icon(
                  obscureValue
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: kBlue.withOpacity(0.55),
                  size: 20,
                ),
              )
            : null,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        fontFamily: 'Ubuntu',
        textTheme: const TextTheme().apply(fontFamily: 'Ubuntu'),
      ),
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: kBlue, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Regístrate",
            style: TextStyle(
              fontFamily: 'Ubuntu',
              color: kWhite,
              fontSize: 16,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  kBlue.withOpacity(0.25),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            // — Gradiente fondo —
            Positioned.fill(
              child: const DecoratedBox(
                decoration: BoxDecoration(
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

            // — Halos —
            Positioned(
              top: -160, right: -120,
              child: Container(
                width: 420, height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    kBlue.withOpacity(0.11),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Positioned(
              bottom: -80, left: -60,
              child: Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    kBlueDark.withOpacity(0.12),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),

            // — Fondo animado —
            const Positioned.fill(child: AnimatedRacingBackground()),

            // — Contenido —
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      // 0 — Header con ícono
                      _animated(
                        0,
                        Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 110, height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(colors: [
                                      kBlue.withOpacity(0.18),
                                      Colors.transparent,
                                    ]),
                                  ),
                                ),
                                Container(
                                  width: 78, height: 78,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: kBlue.withOpacity(0.08),
                                    border: Border.all(
                                      color: kBlue.withOpacity(0.28),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person_add_alt_1_rounded,
                                    color: kBlue,
                                    size: 34,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Únete a RevUp",
                              style: TextStyle(
                                fontFamily: 'Ubuntu',
                                color: kWhite,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Crea tu cuenta y toma el control.",
                              style: TextStyle(
                                fontFamily: 'Ubuntu',
                                color: kWhite.withOpacity(0.40),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // 1 — Nombre
                      _animated(1,
                        _field(
                          controller: _nombreController,
                          label: "Nombre completo",
                          icon: Icons.badge_outlined,
                          keyboardType: TextInputType.name,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2 — Correo
                      _animated(2,
                        _field(
                          controller: _correoController,
                          label: "Correo electrónico",
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3 — Usuario
                      _animated(3,
                        _field(
                          controller: _usuarioController,
                          label: "Nombre de usuario",
                          icon: Icons.alternate_email_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4 — Contraseña
                      _animated(4,
                        _field(
                          controller: _passwordController,
                          label: "Contraseña",
                          icon: Icons.lock_outline_rounded,
                          obscure: true,
                          obscureValue: _obscurePw,
                          onToggleObscure: () =>
                              setState(() => _obscurePw = !_obscurePw),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(kPasswordHint, style: TextStyle(
                          fontFamily: 'Ubuntu', color: kWhite.withOpacity(0.30),
                          fontSize: 11)),
                      ),
                      const SizedBox(height: 14),

                      // 5 — Confirmar contraseña
                      _animated(5,
                        _field(
                          controller: _confirmPwController,
                          label: "Confirmar contraseña",
                          icon: Icons.lock_reset_rounded,
                          obscure: true,
                          obscureValue: _obscureConfirm,
                          onToggleObscure: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // 6 — Botón + link login
                      _animated(
                        6,
                        Column(
                          children: [
                            // Botón principal
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
                                  color: _loading ? Colors.white10 : null,
                                  boxShadow: _loading
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: kBlue.withOpacity(0.38),
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
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _loading ? null : _doRegister,
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22, height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          "CREAR CUENTA",
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

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: kBlue.withOpacity(0.12),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  child: Text(
                                    "o",
                                    style: TextStyle(
                                      fontFamily: 'Ubuntu',
                                      color: kBlue.withOpacity(0.3),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: kBlue.withOpacity(0.12),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Link a login
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "¿Ya tienes cuenta?  ",
                                  style: TextStyle(
                                    fontFamily: 'Ubuntu',
                                    color: kWhite.withOpacity(0.35),
                                    fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pushReplacementNamed(
                                      context, '/login'),
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

                            const SizedBox(height: 8),
                          ],
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