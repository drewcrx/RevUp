import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api_service.dart';
import 'vehiculo_model.dart';
import 'qr_utils.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kWhite    = Color(0xFFF0F4FF);
const _kBg       = Color(0xFF04060D);
const _kCard     = Color(0xFF080E1A);

class DetalleVehiculoPage extends StatefulWidget {
  final Vehiculo vehiculo;
  const DetalleVehiculoPage({super.key, required this.vehiculo});
  @override
  State<DetalleVehiculoPage> createState() => _DetalleVehiculoPageState();
}

class _DetalleVehiculoPageState extends State<DetalleVehiculoPage> {
  // ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
  bool _imprimiendo    = false;
  final _kmCtrl        = TextEditingController();
  bool  _actualizandoKm = false;
  int   _kmActual       = 0;

  @override
  void initState() {
    super.initState();
    _kmActual     = widget.vehiculo.kilometraje;
    _kmCtrl.text  = _kmActual.toString();
  }

  @override
  void dispose() { _kmCtrl.dispose(); super.dispose(); }

  String _datoStr(dynamic v, {String fallback = "—"}) {
    final s = (v ?? "").toString().trim();
    return s.isEmpty ? fallback : s;
  }

  Future<void> _actualizarKilometraje() async {
    if (_actualizandoKm) return;
    final nuevoKm = int.tryParse(_kmCtrl.text.trim());
    if (nuevoKm == null || nuevoKm <= 0) {
      _snack('Ingresa un kilometraje válido', error: true);
      return;
    }
    setState(() => _actualizandoKm = true);
    try {
      final ultima = widget.vehiculo.ultimaVisita?.toIso8601String() ?? "";
      final ok = await ApiService.actualizarVehiculo(
        placa: widget.vehiculo.placa, kilometraje: nuevoKm, ultimaVisita: ultima);
      if (!mounted) return;
      if (ok) {
        setState(() => _kmActual = nuevoKm);
        _snack('Kilometraje actualizado ✅');
      } else {
        _snack('No se pudo actualizar el kilometraje', error: true);
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _actualizandoKm = false);
    }
  }

  double _mm(double v) => v * 2.8346456693;
  PdfPageFormat get _sticker50x80 => PdfPageFormat(_mm(50), _mm(80));
  PdfPageFormat get _thermal80    => PdfPageFormat(_mm(80), _mm(80));
  PdfPageFormat get _thermal58    => PdfPageFormat(_mm(58), _mm(80));

  Future<pw.Font?> _loadProjectFont() async {
    try {
      final fontData = await rootBundle.load('fonts/BBHSansBogle-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (_) { return null; }
  }

  pw.Widget _buildStickerWidget({
    required Uint8List qrBytes, required String placa,
    required String marcaModelo, required int year,
    pw.Font? font, required double widthPt, required double heightPt,
  }) {
    final green = PdfColor.fromInt(0xFF1E90FF);
    final black = PdfColor.fromInt(0xFF000000);
    final white = PdfColor.fromInt(0xFFFFFFFF);
    final baseStyle = pw.TextStyle(font: font, color: black);
    final boldStyle = pw.TextStyle(font: font, color: black, fontWeight: pw.FontWeight.bold);
    final usableWidth = widthPt - 16;
    final qrSize = (usableWidth - 12 - 2).clamp(80.0, 130.0).toDouble();

    return pw.Container(
      width: widthPt, height: heightPt,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: white, borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: green, width: 2),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          decoration: pw.BoxDecoration(
            color: green, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Text('REVUP $year', textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: font, color: white, fontSize: 10,
              fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1, color: green),
            borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Image(pw.MemoryImage(qrBytes), width: qrSize, height: qrSize),
        ),
        pw.Spacer(),
        pw.Text(placa, textAlign: pw.TextAlign.center,
          style: boldStyle.copyWith(fontSize: 16)),
        pw.SizedBox(height: 4),
        pw.Text(marcaModelo, textAlign: pw.TextAlign.center,
          style: baseStyle.copyWith(fontSize: 10), maxLines: 2),
      ]),
    );
  }

  Future<Uint8List> _generateQrPngBytes(String data) async {
    final qrPainter = QrPainter(data: data, version: QrVersions.auto, gapless: true);
    final ui.Image image = await qrPainter.toImage(350);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _printSingleSticker({
    required String qrData, required PdfPageFormat pageFormat, required pw.Font? font}) async {
    final pdf = pw.Document();
    final qrBytes = await _generateQrPngBytes(qrData);
    final year = DateTime.now().year;
    final bool isExact = (pageFormat.width == _sticker50x80.width) &&
        (pageFormat.height == _sticker50x80.height);
    final pageMargin = isExact ? pw.EdgeInsets.zero : const pw.EdgeInsets.all(8);
    final contentW = pageFormat.width  - pageMargin.horizontal;
    final contentH = pageFormat.height - pageMargin.vertical;
    pdf.addPage(pw.Page(
      pageFormat: pageFormat, margin: pageMargin,
      theme: font != null ? pw.ThemeData.withFont(base: font, bold: font) : pw.ThemeData(),
      build: (_) => pw.Center(child: _buildStickerWidget(
        qrBytes: qrBytes, placa: widget.vehiculo.placa,
        marcaModelo: '${widget.vehiculo.marca} ${widget.vehiculo.modelo}',
        year: year, font: font, widthPt: contentW, heightPt: contentH)),
    ));
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Future<void> _printStickersA4({
    required String qrData, required int copies, required pw.Font? font}) async {
    final pdf = pw.Document();
    final qrBytes = await _generateQrPngBytes(qrData);
    final year = DateTime.now().year;
    const cols = 3; const rows = 3; const perPage = cols * rows;
    const spacing = 12.0; const runSpacing = 12.0;
    final totalPages = (copies / perPage).ceil();
    for (int page = 0; page < totalPages; page++) {
      final start = page * perPage;
      final end   = (start + perPage) > copies ? copies : (start + perPage);
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: font != null ? pw.ThemeData.withFont(base: font, bold: font) : pw.ThemeData(),
        build: (_) => pw.Center(child: pw.Wrap(
          spacing: spacing, runSpacing: runSpacing,
          children: List.generate(end - start, (_) => _buildStickerWidget(
            qrBytes: qrBytes, placa: widget.vehiculo.placa,
            marcaModelo: '${widget.vehiculo.marca} ${widget.vehiculo.modelo}',
            year: year, font: font,
            widthPt: _sticker50x80.width, heightPt: _sticker50x80.height)),
        )),
      ));
    }
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Future<void> _mostrarOpcionesImpresion() async {
    if (_imprimiendo) return;
    final qrData = (widget.vehiculo.qrToken != null && widget.vehiculo.qrToken!.isNotEmpty)
        ? qrUrlParaToken(widget.vehiculo.qrToken!) : widget.vehiculo.placa;
    final font = await _loadProjectFont();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: _kBlue.withOpacity(0.18)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _kBlue.withOpacity(0.25),
              borderRadius: BorderRadius.circular(4))),
          Row(children: [
            const Icon(Icons.print_rounded, color: _kBlue, size: 18),
            const SizedBox(width: 8),
            const Text("Opciones de impresión", style: TextStyle(
              fontFamily: 'Ubuntu', color: _kWhite,
              fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
          Divider(height: 20, color: _kBlue.withOpacity(0.10)),
          _printTile(
            icon: Icons.label_rounded,
            title: "Sticker individual (50×80 mm)",
            subtitle: "Ideal para imprimir 1 etiqueta",
            onTap: () async {
              Navigator.pop(context);
              await _runPrintJob(() => _printSingleSticker(
                  qrData: qrData, pageFormat: _sticker50x80, font: font));
            },
          ),
          _printTile(
            icon: Icons.description_rounded,
            title: "Hoja A4 — 9 stickers por hoja",
            subtitle: "Imprime varias etiquetas para recortar",
            onTap: () async {
              Navigator.pop(context);
              final copias = await _pedirCopiasA4();
              if (copias == null) return;
              await _runPrintJob(() => _printStickersA4(
                  qrData: qrData, copies: copias, font: font));
            },
          ),
          _printTile(
            icon: Icons.receipt_long_rounded,
            title: "Térmica rollo 80 mm",
            subtitle: "Centra el sticker 50×80 en rollo 80 mm",
            onTap: () async {
              Navigator.pop(context);
              await _runPrintJob(() => _printSingleSticker(
                  qrData: qrData, pageFormat: _thermal80, font: font));
            },
          ),
          _printTile(
            icon: Icons.receipt_rounded,
            title: "Térmica rollo 58 mm",
            subtitle: "Centra el sticker 50×80 en rollo 58 mm",
            onTap: () async {
              Navigator.pop(context);
              await _runPrintJob(() => _printSingleSticker(
                  qrData: qrData, pageFormat: _thermal58, font: font));
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _runPrintJob(Future<void> Function() job) async {
    if (_imprimiendo) return;
    setState(() => _imprimiendo = true);
    try {
      await job();
    } catch (e) {
      if (!mounted) return;
      _snack('Error al imprimir: $e', error: true);
    } finally {
      if (mounted) setState(() => _imprimiendo = false);
    }
  }

  Future<int?> _pedirCopiasA4() async {
    final controller = TextEditingController(text: '9');
    final result = await showDialog<int>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBlue.withOpacity(0.18)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.copy_rounded, color: _kBlue, size: 18),
              const SizedBox(width: 8),
              const Text("Copias para A4", style: TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite,
                fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontFamily: 'Ubuntu', color: _kWhite, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Ej: 9, 18, 27...",
                hintStyle: TextStyle(fontFamily: 'Ubuntu',
                  color: _kWhite.withOpacity(0.25), fontSize: 13),
                filled: true,
                fillColor: _kBlue.withOpacity(0.06),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _kBlue.withOpacity(0.25))),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBlue, width: 1.5)),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBlue.withOpacity(0.25)),
                    color: _kBlue.withOpacity(0.05),
                  ),
                  child: Center(child: Text("Cancelar", style: TextStyle(
                    fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.50),
                    fontWeight: FontWeight.w600, fontSize: 13))),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () {
                  final v = int.tryParse(controller.text.trim());
                  if (v == null || v <= 0) {
                    _snack('Ingresa un número válido', error: true);
                    return;
                  }
                  Navigator.pop(context, v);
                },
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2AA0FF), _kBlueDark]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: _kBlue.withOpacity(0.30),
                      blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: const Center(child: Text("Aceptar", style: TextStyle(
                    fontFamily: 'Ubuntu', color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 13))),
                ),
              )),
            ]),
          ]),
        ),
      ),
    );
    controller.dispose();
    return result;
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

  // ── Tile de opción de impresión ────────────────────────────────────────────
  Widget _printTile({
    required IconData icon, required String title,
    required String subtitle, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _kBlue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBlue.withOpacity(0.12)),
          ),
          child: Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: _kBlue.withOpacity(0.12)),
              child: Icon(icon, color: _kBlue, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite,
                fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.35),
                fontSize: 11)),
            ])),
            Icon(Icons.chevron_right_rounded,
              color: _kBlue.withOpacity(0.35), size: 18),
          ]),
        ),
      );

  // ── Fila de dato ───────────────────────────────────────────────────────────
  Widget _dato(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110, child: Text(label, style: TextStyle(
        fontFamily: 'Ubuntu', color: _kWhite.withOpacity(0.40),
        fontSize: 12, fontWeight: FontWeight.w600))),
      Expanded(child: Text(value, style: const TextStyle(
        fontFamily: 'Ubuntu', color: _kWhite,
        fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );

  // ── Cabecera de sección ────────────────────────────────────────────────────
  Widget _secHeader(String title, {IconData? icon, Color? color}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(children: [
      Container(width: 3, height: 16,
        decoration: BoxDecoration(
          color: color ?? _kBlue, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      if (icon != null) ...[
        Icon(icon, color: color ?? _kBlue, size: 15), const SizedBox(width: 6)],
      Text(title, style: const TextStyle(
        fontFamily: 'Ubuntu', color: _kWhite,
        fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.3)),
    ]),
  );

  // ── Tarjeta de sección ─────────────────────────────────────────────────────
  Widget _card({required Widget child, Color? border}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: (border ?? _kBlue).withOpacity(0.14)),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final qrData = (widget.vehiculo.qrToken != null &&
            widget.vehiculo.qrToken!.isNotEmpty)
        ? qrUrlParaToken(widget.vehiculo.qrToken!)
        : widget.vehiculo.placa;

    final anio        = widget.vehiculo.anio?.toString() ?? "—";
    final color       = _datoStr(widget.vehiculo.color);
    final tipo        = _datoStr(widget.vehiculo.tipoVehiculo);
    final propietario = _datoStr(widget.vehiculo.propietarioNombre);
    final telefono    = _datoStr(widget.vehiculo.propietarioTelefono);
    final nota        = _datoStr(widget.vehiculo.notaIngreso);
    final initial     = widget.vehiculo.marca.isNotEmpty
        ? widget.vehiculo.marca[0].toUpperCase() : "V";

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
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kBlue, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
              decoration: const BoxDecoration(
                color: _kBlue, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(child: Text(
              "${widget.vehiculo.marca} ${widget.vehiculo.modelo}".toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Ubuntu', color: _kWhite,
                fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.5),
            )),
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
          Positioned(top: -80, right: -60, child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _kBlue.withOpacity(0.07), Colors.transparent])),
          )),

          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [

              // ── QR + botón imprimir ──────────────────────────────────────
              _card(child: Column(children: [
                _secHeader("Código QR del vehículo",
                  icon: Icons.qr_code_rounded),
                // QR centrado con fondo blanco redondeado
                Center(child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                      color: _kBlue.withOpacity(0.25),
                      blurRadius: 20, spreadRadius: 2)],
                  ),
                  child: QrImageView(
                    data: qrData, size: 180,
                    backgroundColor: Colors.white),
                )),
                const SizedBox(height: 16),
                // Botón imprimir
                GestureDetector(
                  onTap: _imprimiendo ? null : _mostrarOpcionesImpresion,
                  child: Container(
                    height: 46, width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: _imprimiendo ? null
                          : const LinearGradient(
                              colors: [Color(0xFF2AA0FF), _kBlueDark]),
                      color: _imprimiendo ? Colors.white10 : null,
                      boxShadow: _imprimiendo ? null : [BoxShadow(
                        color: _kBlue.withOpacity(0.32),
                        blurRadius: 14, offset: const Offset(0, 4))],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(
                        _imprimiendo
                          ? Icons.hourglass_top_rounded
                          : Icons.print_rounded,
                        color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      _imprimiendo
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                          : const Text("IMPRIMIR QR", style: TextStyle(
                              fontFamily: 'Ubuntu', color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13, letterSpacing: 1.8)),
                    ]),
                  ),
                ),
              ])),

              // ── Datos del vehículo ───────────────────────────────────────
              _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                _secHeader("Datos del vehículo",
                  icon: Icons.directions_car_rounded),
                // Avatar + placa
                Row(children: [
                  Container(width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF2AA0FF), _kBlueDark]),
                      boxShadow: [BoxShadow(
                        color: _kBlue.withOpacity(0.28), blurRadius: 10)],
                    ),
                    child: Center(child: Text(initial, style: const TextStyle(
                      fontFamily: 'Ubuntu', color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 20))),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      "${widget.vehiculo.marca} ${widget.vehiculo.modelo}",
                      style: const TextStyle(
                        fontFamily: 'Ubuntu', color: _kWhite,
                        fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _kBlue.withOpacity(0.30)),
                      ),
                      child: Text(widget.vehiculo.placa, style: const TextStyle(
                        fontFamily: 'Ubuntu', color: _kBlue,
                        fontWeight: FontWeight.w800, fontSize: 13,
                        letterSpacing: 1.2))),
                  ]),
                ]),
                Divider(height: 20, color: _kBlue.withOpacity(0.08)),
                _dato("Tipo",         tipo),
                _dato("Año",          anio),
                _dato("Color",        color),
                _dato("Kilometraje",  "$_kmActual km"),
                _dato("Última visita",
                  _datoStr(widget.vehiculo.ultimaVisita)),
                Divider(height: 20, color: _kBlue.withOpacity(0.08)),

                // Campo actualizar km
                Row(children: [
                  const Icon(Icons.speed_rounded, color: _kBlue, size: 15),
                  const SizedBox(width: 6),
                  Text("Actualizar kilometraje", style: const TextStyle(
                    fontFamily: 'Ubuntu', color: _kWhite,
                    fontWeight: FontWeight.w600, fontSize: 12)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _kmCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontFamily: 'Ubuntu',
                      color: _kWhite, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Ej: 85000",
                      hintStyle: TextStyle(fontFamily: 'Ubuntu',
                        color: _kWhite.withOpacity(0.22), fontSize: 13),
                      filled: true, fillColor: _kBlue.withOpacity(0.06),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _kBlue.withOpacity(0.25))),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: _kBlue, width: 1.5)),
                    ),
                  )),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _actualizandoKm ? null : _actualizarKilometraje,
                    child: Container(
                      height: 46, width: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: _actualizandoKm ? null
                            : const LinearGradient(
                                colors: [Color(0xFF2AA0FF), _kBlueDark]),
                        color: _actualizandoKm ? Colors.white10 : null,
                        boxShadow: _actualizandoKm ? null : [BoxShadow(
                          color: _kBlue.withOpacity(0.28), blurRadius: 8)],
                      ),
                      child: _actualizandoKm
                          ? const Center(child: SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)))
                          : const Icon(Icons.save_rounded,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ]),
              ])),

              // ── Propietario ──────────────────────────────────────────────
              _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                _secHeader("Propietario", icon: Icons.person_rounded),
                _dato("Nombre",   propietario),
                _dato("Teléfono", telefono),
              ])),

              // ── Nota de ingreso (solo si existe) ─────────────────────────
              if (nota != "—")
                _card(
                  border: Colors.orangeAccent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _secHeader("Nota de ingreso",
                        icon: Icons.sticky_note_2_rounded,
                        color: Colors.orangeAccent),
                      Text(nota, style: TextStyle(
                        fontFamily: 'Ubuntu',
                        color: _kWhite.withOpacity(0.75),
                        fontSize: 13, height: 1.5)),
                    ],
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}