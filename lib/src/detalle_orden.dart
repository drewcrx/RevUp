import 'package:flutter/material.dart';
import 'api_service.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kBlueGlow = Color(0xFF00BFFF);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);
const _kCard     = Color(0xFF080E1A);

class DetalleOrdenPage extends StatefulWidget {
  final int ordenId;
  const DetalleOrdenPage({super.key, required this.ordenId});
  @override
  State<DetalleOrdenPage> createState() => _DetalleOrdenPageState();
}

class _DetalleOrdenPageState extends State<DetalleOrdenPage> {
  // ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
  bool   loading = true;
  String? error;
  Map<String, dynamic>? data;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final res = await ApiService.obtenerDetalleOrden(widget.ordenId);
      setState(() { data = res; loading = false; });
    } catch (e) {
      setState(() { error = e.toString(); loading = false; });
    }
  }

  Map<String, dynamic> get ot =>
      (data?['ot'] as Map<String, dynamic>? ?? {});
  List<Map<String, dynamic>> get servicios =>
      (data?['servicios'] as List? ?? []).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get repuestos =>
      (data?['repuestos'] as List? ?? []).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get pagos =>
      (data?['pagos'] as List? ?? []).cast<Map<String, dynamic>>();

  String _money(dynamic v) {
    final n = double.tryParse(v?.toString() ?? "0") ?? 0;
    return "\$${n.toStringAsFixed(2)}";
  }

  // ── Diálogo: agregar servicio ─────────────────────────────────────────────
  Future<void> _showAddServicio() async {
    final descCtrl  = TextEditingController();
    final precCtrl  = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => _Dialog(
        title: "Agregar servicio",
        icon: Icons.build_circle_rounded,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(descCtrl,  "Descripción",         Icons.description_rounded),
          const SizedBox(height: 12),
          _dialogField(precCtrl,  "Precio (mano de obra)", Icons.attach_money_rounded,
            keyboard: TextInputType.number),
        ]),
        onCancel: () => Navigator.pop(ctx),
        onConfirm: () async {
          final desc  = descCtrl.text.trim();
          final precio = double.tryParse(precCtrl.text.trim()) ?? 0;
          if (desc.isEmpty) { _snack("Ingresa una descripción", error: true); return; }
          try {
            await ApiService.agregarServicioOT(
              ordenId: widget.ordenId, descripcion: desc, precio: precio);
            if (!mounted) return;
            Navigator.pop(ctx);
            await _load();
          } catch (e) { if (!mounted) return; _snack(e.toString(), error: true); }
        },
      ),
    );
    descCtrl.dispose(); precCtrl.dispose();
  }

  // ── Diálogo: agregar repuesto ─────────────────────────────────────────────
  Future<void> _showAddRepuesto() async {
    final nomCtrl  = TextEditingController();
    final cantCtrl = TextEditingController(text: "1");
    final cosCtrl  = TextEditingController();
    final preCtrl  = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => _Dialog(
        title: "Agregar repuesto",
        icon: Icons.settings_rounded,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(nomCtrl,  "Nombre del repuesto",      Icons.inventory_2_rounded),
          const SizedBox(height: 12),
          _dialogField(cantCtrl, "Cantidad",                 Icons.numbers_rounded,
            keyboard: TextInputType.number),
          const SizedBox(height: 12),
          _dialogField(cosCtrl,  "Costo unitario (gasto)",   Icons.trending_down_rounded,
            keyboard: TextInputType.number),
          const SizedBox(height: 12),
          _dialogField(preCtrl,  "Precio unitario (cliente)", Icons.sell_rounded,
            keyboard: TextInputType.number),
        ]),
        onCancel: () => Navigator.pop(ctx),
        onConfirm: () async {
          final nombre   = nomCtrl.text.trim();
          final cantidad = int.tryParse(cantCtrl.text.trim()) ?? 1;
          final costo    = double.tryParse(cosCtrl.text.trim()) ?? 0;
          final precio   = double.tryParse(preCtrl.text.trim()) ?? 0;
          if (nombre.isEmpty)  { _snack("Ingresa el nombre del repuesto", error: true); return; }
          if (cantidad <= 0)   { _snack("Cantidad inválida", error: true); return; }
          try {
            await ApiService.agregarRepuestoOT(
              ordenId: widget.ordenId, nombre: nombre,
              cantidad: cantidad, costoUnitario: costo, precioUnitario: precio);
            if (!mounted) return;
            Navigator.pop(ctx);
            await _load();
          } catch (e) { if (!mounted) return; _snack(e.toString(), error: true); }
        },
      ),
    );
    nomCtrl.dispose(); cantCtrl.dispose(); cosCtrl.dispose(); preCtrl.dispose();
  }

  // ── Diálogo: registrar pago ───────────────────────────────────────────────
  Future<void> _showPago() async {
    final montoCtrl = TextEditingController();
    String metodo   = "EFECTIVO";

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => _Dialog(
          title: "Registrar pago",
          icon: Icons.payments_rounded,
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(montoCtrl, "Monto", Icons.attach_money_rounded,
              keyboard: TextInputType.number),
            const SizedBox(height: 12),
            // Selector de método
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBlue.withOpacity(0.25)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: metodo,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0D1420),
                  iconEnabledColor: _kBlue,
                  style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
                  items: const [
                    DropdownMenuItem(value: "EFECTIVO",      child: Text("Efectivo")),
                    DropdownMenuItem(value: "TRANSFERENCIA", child: Text("Transferencia")),
                    DropdownMenuItem(value: "TARJETA",       child: Text("Tarjeta")),
                  ],
                  onChanged: (v) => setS(() => metodo = v ?? "EFECTIVO"),
                ),
              ),
            ),
          ]),
          onCancel: () => Navigator.pop(ctx),
          onConfirm: () async {
            final monto = double.tryParse(montoCtrl.text.trim()) ?? 0;
            if (monto <= 0) { _snack("Monto inválido", error: true); return; }
            try {
              await ApiService.registrarPagoOT(
                ordenId: widget.ordenId, monto: monto, metodo: metodo);
              if (!mounted) return;
              Navigator.pop(ctx);
              await _load();
            } catch (e) { if (!mounted) return; _snack(e.toString(), error: true); }
          },
        ),
      ),
    );
    montoCtrl.dispose();
  }

  // ── Cerrar OT ─────────────────────────────────────────────────────────────
  Future<void> _cerrarOT() async {
    try {
      await ApiService.cerrarOT(widget.ordenId);
      if (!mounted) return;
      await _load();
      _snack("OT marcada como ENTREGADO");
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), error: true);
    }
  }
  // ═════════════════════════════════════════════════════════════════════════ //

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Ubuntu')),
      backgroundColor: error ? Colors.red.shade900 : _kBlueDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Campo de diálogo ──────────────────────────────────────────────────────
  Widget _dialogField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType keyboard = TextInputType.text}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontFamily: 'Ubuntu',
            color: _kBlue.withOpacity(0.85), fontSize: 12),
          prefixIcon: Icon(icon, color: _kBlue.withOpacity(0.70), size: 18),
          filled: true, fillColor: _kBlue.withOpacity(0.05),
          contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _kBlue.withOpacity(0.22))),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBlue, width: 1.5)),
        ),
      );

  // ── Sección con título ────────────────────────────────────────────────────
  Widget _section(String title, int count, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(width: 3, height: 16,
        decoration: BoxDecoration(color: _kBlue,
          borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Icon(icon, color: _kBlue, size: 15),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(
        fontFamily: 'Ubuntu', color: _kWhite,
        fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: _kBlue.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _kBlue.withOpacity(0.28))),
        child: Text("$count", style: const TextStyle(
          fontFamily: 'Ubuntu', color: _kBlue,
          fontWeight: FontWeight.w700, fontSize: 10))),
    ]),
  );

  // ── Card ──────────────────────────────────────────────────────────────────
  Widget _card({required Widget child, Color? border}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: (border ?? _kBlue).withOpacity(0.13))),
    child: child,
  );

  // ── Divider interno ───────────────────────────────────────────────────────
  Widget _div() => Divider(height: 16, thickness: 1,
    color: _kBlue.withOpacity(0.07));

  // ── Color semántico de estado ─────────────────────────────────────────────
  Color _estadoColor(String e) {
    switch (e.toUpperCase()) {
      case 'RECIBIDO':    return _kBlueGlow;
      case 'DIAGNOSTICO': return Colors.amberAccent;
      case 'REPARACION':  return Colors.orangeAccent;
      case 'LISTO':       return Colors.lightGreenAccent;
      case 'ENTREGADO':   return Colors.greenAccent;
      default:            return _kWhite;
    }
  }

  // ── Botón de acción ───────────────────────────────────────────────────────
  Widget _actionBtn(String label, IconData icon, VoidCallback? onTap,
      {bool outline = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: (onTap == null || outline) ? null
                : const LinearGradient(
                    colors: [Color(0xFF2AA0FF), _kBlueDark]),
            border: outline
                ? Border.all(color: _kBlue.withOpacity(0.30))
                : null,
            color: outline ? _kBlue.withOpacity(0.06)
                : onTap == null ? Colors.white10 : null,
            boxShadow: (onTap != null && !outline) ? [BoxShadow(
              color: _kBlue.withOpacity(0.28),
              blurRadius: 10, offset: const Offset(0, 3))] : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: onTap == null
                ? _kWhite.withOpacity(0.25) : Colors.white, size: 16),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(
              fontFamily: 'Ubuntu',
              color: onTap == null ? _kWhite.withOpacity(0.25) : Colors.white,
              fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final placa      = (ot['placa']      ?? '').toString();
    final estado     = (ot['estado']     ?? '').toString().toUpperCase();
    final pagoEstado = (ot['pago_estado'] ?? '').toString();
    final symptoms   = (ot['symptoms']   ?? '').toString();
    final total      = ot['total'] ?? 0;
    final kmRaw      = ot['kilometraje_ot'];
    final int? km    = kmRaw is int ? kmRaw : int.tryParse(kmRaw?.toString() ?? "");
    final eColor     = _estadoColor(estado);
    final entregado  = estado == "ENTREGADO";

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
                Colors.transparent, _kBlue.withOpacity(0.35),
                Colors.transparent]))),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kBlue, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
              decoration: const BoxDecoration(
                color: _kBlue, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text("DETALLE OT", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 2)),
          ]),
          centerTitle: true,
          actions: [
            if (km != null && km > 0)
              Center(child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kBlue.withOpacity(0.28))),
                  child: Text("$km km", style: const TextStyle(
                    fontFamily: 'Ubuntu', color: _kBlue,
                    fontWeight: FontWeight.w700, fontSize: 11))),
              )),
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                color: _kBlue, size: 20),
              tooltip: "Refrescar",
              onPressed: _load,
            ),
          ],
        ),

        // ── Body ────────────────────────────────────────────────────────────
        body: Stack(children: [
          Positioned.fill(child: const DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF060B18), _kBg, Color(0xFF030509)]),
          ))),
          Positioned(top: -80, right: -60, child: Container(
            width: 220, height: 220,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _kBlue.withOpacity(0.07), Colors.transparent])),
          )),

          if (loading)
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 30, height: 30,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)),
              const SizedBox(height: 12),
              Text("Cargando orden...", style: TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.28),
                fontSize: 12)),
            ]))

          else if (error != null)
            Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: _card(border: Colors.redAccent,
                child: Column(children: [
                  const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 28),
                  const SizedBox(height: 10),
                  Text(error!, textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Ubuntu',
                      color: _kWhite.withOpacity(0.50), fontSize: 12)),
                  const SizedBox(height: 14),
                  _actionBtn("Reintentar",
                    Icons.refresh_rounded, _load),
                ])),
            ))

          else
            ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
              children: [

                // ── Cabecera OT ──────────────────────────────────────────
                _card(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Placa + ID
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _kBlue.withOpacity(0.30))),
                      child: Text(placa, style: const TextStyle(
                        fontFamily: 'Ubuntu', color: _kBlue,
                        fontWeight: FontWeight.w800, fontSize: 16,
                        letterSpacing: 1.2))),
                    const SizedBox(width: 10),
                    Text("OT #${widget.ordenId}",
                      style: TextStyle(fontFamily: 'Ubuntu',
                        color: _kWhite.withOpacity(0.35), fontSize: 12)),
                  ]),
                  const SizedBox(height: 12),
                  // Estado + pago en chips
                  Row(children: [
                    _statusChip(estado, eColor),
                    const SizedBox(width: 8),
                    _statusChip(pagoEstado,
                      pagoEstado.toUpperCase().contains("PEND")
                          ? Colors.orangeAccent : Colors.greenAccent),
                  ]),
                  _div(),
                  // Síntomas
                  Row(children: [
                    const Icon(Icons.report_problem_rounded,
                      color: _kBlue, size: 14),
                    const SizedBox(width: 6),
                    Text("Síntomas del cliente", style: const TextStyle(
                      fontFamily: 'Ubuntu', color: _kWhite,
                      fontWeight: FontWeight.w600, fontSize: 12)),
                  ]),
                  const SizedBox(height: 6),
                  Text(symptoms.isEmpty ? "—" : symptoms,
                    style: TextStyle(fontFamily: 'Ubuntu',
                      color: _kWhite.withOpacity(0.55),
                      fontSize: 13, height: 1.5)),
                ])),

                // ── Botones de acción ────────────────────────────────────
                _card(child: Column(children: [
                  Row(children: [
                    Expanded(child: _actionBtn("Agregar servicio",
                      Icons.build_circle_rounded, _showAddServicio)),
                    const SizedBox(width: 10),
                    Expanded(child: _actionBtn("Agregar repuesto",
                      Icons.settings_rounded, _showAddRepuesto)),
                  ]),
                  const SizedBox(height: 10),
                  _actionBtn("Registrar pago",
                    Icons.payments_rounded, _showPago, outline: true),
                ])),

                // ── Servicios ────────────────────────────────────────────
                _card(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _section("Servicios", servicios.length,
                    Icons.build_rounded),
                  if (servicios.isEmpty)
                    _emptyRow("Sin servicios registrados")
                  else
                    ...servicios.map((s) {
                      final desc  = (s['descripcion'] ?? '').toString();
                      final prec  = _money(s['precio']);
                      return _lineRow(desc, prec, Icons.check_circle_outline_rounded);
                    }),
                ])),

                // ── Repuestos ────────────────────────────────────────────
                _card(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _section("Repuestos", repuestos.length,
                    Icons.inventory_2_rounded),
                  if (repuestos.isEmpty)
                    _emptyRow("Sin repuestos registrados")
                  else
                    ...repuestos.map((r) {
                      final nombre = (r['nombre'] ?? '').toString();
                      final cant   = (r['cantidad'] ?? 1).toString();
                      final pUnit  = double.tryParse(
                        r['precio_unitario']?.toString() ?? "0") ?? 0;
                      final linea  = "\$${(pUnit * (int.tryParse(cant) ?? 1)).toStringAsFixed(2)}";
                      return _lineRow(
                        "$nombre  ×$cant",
                        linea,
                        Icons.settings_outlined,
                        sub: "Unitario \$${pUnit.toStringAsFixed(2)}",
                      );
                    }),
                ])),

                // ── Pagos ─────────────────────────────────────────────────
                _card(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _section("Pagos", pagos.length,
                    Icons.payments_rounded),
                  if (pagos.isEmpty)
                    _emptyRow("Sin pagos registrados")
                  else
                    ...pagos.map((p) {
                      final monto  = _money(p['monto']);
                      final metodo = (p['metodo'] ?? '').toString();
                      final icon   = metodo == "TRANSFERENCIA"
                          ? Icons.swap_horiz_rounded
                          : metodo == "TARJETA"
                              ? Icons.credit_card_rounded
                              : Icons.payments_rounded;
                      return _lineRow(metodo, monto, icon,
                        valueColor: Colors.greenAccent);
                    }),
                ])),

                // ── Resumen financiero ────────────────────────────────────
                _card(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                      color: _kBlue, size: 15),
                    const SizedBox(width: 6),
                    const Text("Total", style: TextStyle(
                      fontFamily: 'Ubuntu', color: _kWhite,
                      fontWeight: FontWeight.w700, fontSize: 13)),
                    const Spacer(),
                    Text(_money(total), style: const TextStyle(
                      fontFamily: 'Ubuntu', color: _kBlue,
                      fontWeight: FontWeight.w900, fontSize: 20)),
                  ]),
                ])),

                // ── Cerrar OT ─────────────────────────────────────────────
                GestureDetector(
                  onTap: entregado ? null : _cerrarOT,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: entregado ? null
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2AA0FF), _kBlueDark]),
                      color: entregado ? Colors.white10 : null,
                      boxShadow: entregado ? null : [BoxShadow(
                        color: _kBlue.withOpacity(0.35),
                        blurRadius: 14, offset: const Offset(0, 4))],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(
                        entregado
                            ? Icons.check_circle_rounded
                            : Icons.done_all_rounded,
                        color: entregado
                            ? Colors.greenAccent.withOpacity(0.50)
                            : Colors.white,
                        size: 18),
                      const SizedBox(width: 8),
                      Text(
                        entregado ? "YA ENTREGADA" : "CERRAR OT — ENTREGAR",
                        style: TextStyle(
                          fontFamily: 'Ubuntu',
                          color: entregado
                              ? _kWhite.withOpacity(0.25) : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13, letterSpacing: 1.5)),
                    ]),
                  ),
                ),
              ],
            ),
        ]),
      ),
    );
  }

  // ── Chip de estado ─────────────────────────────────────────────────────────
  Widget _statusChip(String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.10),
      border: Border.all(color: c.withOpacity(0.30)),
      borderRadius: BorderRadius.circular(7)),
    child: Text(label, style: TextStyle(
      fontFamily: 'Ubuntu', color: c,
      fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
  );

  // ── Fila de ítem ──────────────────────────────────────────────────────────
  Widget _lineRow(String label, String value, IconData icon,
      {String? sub, Color? valueColor}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: _kBlue.withOpacity(0.50), size: 15),
        const SizedBox(width: 10),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(
            fontFamily: 'Ubuntu', color: _kWhite,
            fontWeight: FontWeight.w600, fontSize: 13)),
          if (sub != null) Text(sub, style: TextStyle(
            fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.35),
            fontSize: 11)),
        ])),
        Text(value, style: TextStyle(
          fontFamily: 'Ubuntu',
          color: valueColor ?? _kBlue,
          fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );

  // ── Fila vacía ────────────────────────────────────────────────────────────
  Widget _emptyRow(String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Center(child: Text(msg, style: TextStyle(
      fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.25),
      fontSize: 12))),
  );
}

// ─── Diálogo reutilizable RevUp ───────────────────────────────────────────────
class _Dialog extends StatelessWidget {
  final String   title;
  final IconData icon;
  final Widget   content;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _Dialog({
    required this.title, required this.icon,
    required this.content,
    required this.onCancel, required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1420),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBlue.withOpacity(0.18))),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Título
          Row(children: [
            Icon(icon, color: _kBlue, size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
          Divider(height: 20, color: _kBlue.withOpacity(0.10)),
          // Contenido
          content,
          const SizedBox(height: 20),
          // Botones
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: onCancel,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBlue.withOpacity(0.25)),
                  color: _kBlue.withOpacity(0.05)),
                child: Center(child: Text("Cancelar", style: TextStyle(
                  fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.50),
                  fontWeight: FontWeight.w600, fontSize: 13))),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: onConfirm,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2AA0FF), _kBlueDark]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: _kBlue.withOpacity(0.28),
                    blurRadius: 8, offset: const Offset(0, 3))]),
                child: const Center(child: Text("Guardar", style: TextStyle(
                  fontFamily: 'Ubuntu', color: Colors.white,
                  fontWeight: FontWeight.w700, fontSize: 13))),
              ),
            )),
          ]),
        ]),
      ),
    );
  }
}