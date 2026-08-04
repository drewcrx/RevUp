import 'package:flutter/material.dart';
import 'api_service.dart';
import 'inspeccion_danos.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);

class NuevaOrdenPage extends StatefulWidget {
  final String? placaInicial;
  const NuevaOrdenPage({super.key, this.placaInicial});
  @override
  State<NuevaOrdenPage> createState() => _NuevaOrdenPageState();
}

class _NuevaOrdenPageState extends State<NuevaOrdenPage>
    with SingleTickerProviderStateMixin {
  // ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
  final _placa    = TextEditingController();
  final _symptoms = TextEditingController();
  bool  loading   = false;

  bool get _placaBloqueada =>
      widget.placaInicial != null && widget.placaInicial!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_placaBloqueada) _placa.text = widget.placaInicial!.trim().toUpperCase();
    // Animación de entrada
    _entryCtr = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
    _fadeAnim  = CurvedAnimation(parent: _entryCtr,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtr,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)));
    _entryCtr.forward();
  }

  @override
  void dispose() {
    _placa.dispose();
    _symptoms.dispose();
    _entryCtr.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final placa    = _placa.text.trim().toUpperCase();
    final symptoms = _symptoms.text.trim();

    if (placa.isEmpty || symptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Completa placa y síntomas',
          style: TextStyle(fontFamily: 'Ubuntu')),
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    setState(() => loading = true);
    try {
      final ot = await ApiService.crearOrden(placa: placa, symptoms: symptoms);
      if (!mounted) return;
      final ordenId = int.tryParse((ot['id'] ?? '').toString());
      if (ordenId != null) {
        // Primero se registra la OT, luego se documenta el estado del auto
        // (inspección de daños "al ingresar") antes de ver el resto del
        // detalle — así queda constancia desde el primer momento.
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => InspeccionDanosPage(ordenId: ordenId, placa: placa),
        ));
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString(), style: const TextStyle(fontFamily: 'Ubuntu')),
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  // ═════════════════════════════════════════════════════════════════════════ //

  // Animaciones
  late AnimationController _entryCtr;
  late Animation<double>  _fadeAnim;
  late Animation<Offset>  _slideAnim;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(fontFamily: 'Ubuntu',
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
            onPressed: loading ? null : () => Navigator.pop(context),
          ),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
              decoration: const BoxDecoration(color: _kBlue, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text("NUEVA ORDEN", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 2.5)),
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
          // Halo superior derecha
          Positioned(top: -80, right: -60, child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_kBlue.withOpacity(0.08), Colors.transparent])),
          )),

          // Contenido animado
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Ícono de cabecera ──────────────────────────────────
                  Center(child: Column(children: [
                    Stack(alignment: Alignment.center, children: [
                      Container(width: 90, height: 90,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            _kBlue.withOpacity(0.15), Colors.transparent]))),
                      Container(width: 68, height: 68,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          color: _kBlue.withOpacity(0.08),
                          border: Border.all(color: _kBlue.withOpacity(0.26), width: 1.5)),
                        child: const Icon(Icons.assignment_add,
                          color: _kBlue, size: 30)),
                    ]),
                    const SizedBox(height: 12),
                    const Text("Nueva orden de trabajo", style: TextStyle(
                      fontFamily: 'Ubuntu', color: _kWhite,
                      fontWeight: FontWeight.w700, fontSize: 17)),
                    const SizedBox(height: 4),
                    Text("Registra el vehículo y los síntomas reportados",
                      style: TextStyle(fontFamily: 'Ubuntu',
                        color: _kWhite.withOpacity(0.38), fontSize: 12)),
                  ])),

                  const SizedBox(height: 32),

                  // ── Campo: placa ───────────────────────────────────────
                  _fieldLabel("Placa del vehículo", Icons.pin_rounded),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _placa,
                    enabled: !_placaBloqueada,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                      fontFamily: 'Ubuntu',
                      color: _placaBloqueada
                          ? _kWhite.withOpacity(0.45) : _kWhite,
                      fontSize: 14, letterSpacing: 1.5,
                      fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: _placaBloqueada ? null : "Ej: PBC-1234",
                      hintStyle: TextStyle(
                        fontFamily: 'Ubuntu',
                        color: _kWhite.withOpacity(0.25),
                        fontSize: 13, letterSpacing: 0,
                        fontWeight: FontWeight.w400),
                      prefixIcon: Icon(Icons.directions_car_rounded,
                        color: _placaBloqueada
                            ? _kWhite.withOpacity(0.25) : _kBlue.withOpacity(0.75),
                        size: 20),
                      // Badge "desde vehículos" cuando la placa está fija
                      suffixIcon: _placaBloqueada
                          ? Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kBlue.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _kBlue.withOpacity(0.28)),
                              ),
                              child: const Text("fija", style: TextStyle(
                                fontFamily: 'Ubuntu', color: _kBlue,
                                fontSize: 10, fontWeight: FontWeight.w700)),
                            )
                          : null,
                      filled: true,
                      fillColor: _placaBloqueada
                          ? _kWhite.withOpacity(0.02) : _kBlue.withOpacity(0.06),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(
                          color: _placaBloqueada
                              ? _kWhite.withOpacity(0.08)
                              : _kBlue.withOpacity(0.28))),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: const BorderSide(color: _kBlue, width: 1.5)),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(color: _kWhite.withOpacity(0.07))),
                    ),
                  ),

                  // Nota si la placa viene bloqueada
                  if (_placaBloqueada) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.lock_outline_rounded,
                        color: _kWhite.withOpacity(0.22), size: 12),
                      const SizedBox(width: 5),
                      Text("Placa asignada desde el vehículo seleccionado",
                        style: TextStyle(fontFamily: 'Ubuntu',
                          color: _kWhite.withOpacity(0.25), fontSize: 11)),
                    ]),
                  ],

                  const SizedBox(height: 22),

                  // ── Campo: síntomas ────────────────────────────────────
                  _fieldLabel("Síntomas reportados", Icons.report_problem_rounded),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _symptoms,
                    maxLines: 6,
                    style: const TextStyle(
                      fontFamily: 'Ubuntu', color: _kWhite,
                      fontSize: 14, height: 1.5),
                    decoration: InputDecoration(
                      hintText:
                          "Describe los síntomas reportados por el cliente...",
                      hintStyle: TextStyle(
                        fontFamily: 'Ubuntu',
                        color: _kWhite.withOpacity(0.22), fontSize: 13),
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: _kBlue.withOpacity(0.05),
                      contentPadding: const EdgeInsets.all(16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(color: _kBlue.withOpacity(0.22))),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: const BorderSide(color: _kBlue, width: 1.5)),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Botón crear ────────────────────────────────────────
                  GestureDetector(
                    onTap: loading ? null : _crear,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        gradient: loading ? null
                            : const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2AA0FF), _kBlueDark]),
                        color: loading ? Colors.white10 : null,
                        boxShadow: loading ? null : [BoxShadow(
                          color: _kBlue.withOpacity(0.38),
                          blurRadius: 18, offset: const Offset(0, 5))],
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!loading) ...[
                            const Icon(Icons.add_circle_outline_rounded,
                              color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                          ],
                          loading
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                              : const Text("CREAR ORDEN", style: TextStyle(
                                  fontFamily: 'Ubuntu', color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14, letterSpacing: 2.2)),
                        ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Label de campo ─────────────────────────────────────────────────────────
  Widget _fieldLabel(String text, IconData icon) => Row(children: [
    Icon(icon, color: _kBlue, size: 15),
    const SizedBox(width: 7),
    Text(text, style: const TextStyle(
      fontFamily: 'Ubuntu', color: _kWhite,
      fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.2)),
  ]);
}