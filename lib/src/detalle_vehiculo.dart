import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api_service.dart';
import 'vehiculo_model.dart';

class DetalleVehiculoPage extends StatefulWidget {
  final Vehiculo vehiculo;

  const DetalleVehiculoPage({super.key, required this.vehiculo});

  @override
  State<DetalleVehiculoPage> createState() => _DetalleVehiculoPageState();
}

class _DetalleVehiculoPageState extends State<DetalleVehiculoPage> {
  bool _imprimiendo = false;

  // ====== actualizar kilometraje ======
  final _kmCtrl = TextEditingController();
  bool _actualizandoKm = false;
  int _kmActual = 0;

  @override
  void initState() {
    super.initState();
    _kmActual = (widget.vehiculo.kilometraje);
    _kmCtrl.text = _kmActual.toString();
  }

  @override
  void dispose() {
    _kmCtrl.dispose();
    super.dispose();
  }

  String _datoStr(dynamic v, {String fallback = "—"}) {
    final s = (v ?? "").toString().trim();
    return s.isEmpty ? fallback : s;
  }

  Widget _dato(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'BBH_Sans_Bogle',
            fontSize: 14,
          ),
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(color: Color(0xFF00A86B)),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _actualizarKilometraje() async {
    if (_actualizandoKm) return;

    final nuevoKm = int.tryParse(_kmCtrl.text.trim());
    if (nuevoKm == null || nuevoKm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un kilometraje válido'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _actualizandoKm = true);

    try {
      final ultima = widget.vehiculo.ultimaVisita?.toIso8601String() ?? "";

      final ok = await ApiService.actualizarVehiculo(
        placa: widget.vehiculo.placa,
        kilometraje: nuevoKm,
        ultimaVisita: ultima,
      );

      if (!mounted) return;

      if (ok) {
        setState(() {
          _kmActual = nuevoKm;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kilometraje actualizado ✅'), backgroundColor: Color(0xFF00A86B)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el kilometraje'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (!mounted) return;
      setState(() => _actualizandoKm = false);
    }
  }

  // ================== IMPRESIÓN ==================

  double _mm(double v) => v * 2.8346456693;

  PdfPageFormat get _sticker50x80 => PdfPageFormat(_mm(50), _mm(80));
  PdfPageFormat get _thermal80 => PdfPageFormat(_mm(80), _mm(80));
  PdfPageFormat get _thermal58 => PdfPageFormat(_mm(58), _mm(80));

  Future<pw.Font?> _loadProjectFont() async {
    try {
      final fontData = await rootBundle.load('fonts/BBHSansBogle-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (_) {
      return null;
    }
  }

  pw.Widget _buildStickerWidget({
    required Uint8List qrBytes,
    required String placa,
    required String marcaModelo,
    required int year,
    pw.Font? font,
    required double widthPt,
    required double heightPt,
  }) {
    final green = PdfColor.fromInt(0xFF00A86B);
    final black = PdfColor.fromInt(0xFF000000);
    final white = PdfColor.fromInt(0xFFFFFFFF);

    final baseStyle = pw.TextStyle(font: font, color: black);
    final boldStyle = pw.TextStyle(font: font, color: black, fontWeight: pw.FontWeight.bold);

    final usableWidth = widthPt - 16;
    final framePadding = 6.0;
    final frameBorder = 1.0;

    final qrSize = (usableWidth - (framePadding * 2) - (frameBorder * 2))
        .clamp(80.0, 130.0)
        .toDouble();

    return pw.Container(
      width: widthPt,
      height: heightPt,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: green, width: 2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            decoration: pw.BoxDecoration(
              color: green,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'BACKFIRE $year',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: font,
                color: white,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1, color: green),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Image(
              pw.MemoryImage(qrBytes),
              width: qrSize,
              height: qrSize,
            ),
          ),
          pw.Spacer(),
          pw.Text(placa, textAlign: pw.TextAlign.center, style: boldStyle.copyWith(fontSize: 16)),
          pw.SizedBox(height: 4),
          pw.Text(
            marcaModelo,
            textAlign: pw.TextAlign.center,
            style: baseStyle.copyWith(fontSize: 10),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _generateQrPngBytes(String data) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
    );

    final ui.Image image = await qrPainter.toImage(350);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _printSingleSticker({
    required String qrData,
    required PdfPageFormat pageFormat,
    required pw.Font? font,
  }) async {
    final pdf = pw.Document();
    final qrBytes = await _generateQrPngBytes(qrData);

    final year = DateTime.now().year;
    final placa = widget.vehiculo.placa;
    final marcaModelo = '${widget.vehiculo.marca} ${widget.vehiculo.modelo}';

    final bool isExactSticker50x80 =
        (pageFormat.width == _sticker50x80.width) && (pageFormat.height == _sticker50x80.height);

    final pw.EdgeInsets pageMargin = isExactSticker50x80 ? pw.EdgeInsets.zero : const pw.EdgeInsets.all(8);

    final double contentW = pageFormat.width - pageMargin.horizontal;
    final double contentH = pageFormat.height - pageMargin.vertical;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pageMargin,
        theme: font != null ? pw.ThemeData.withFont(base: font, bold: font) : pw.ThemeData(),
        build: (context) {
          return pw.Center(
            child: _buildStickerWidget(
              qrBytes: qrBytes,
              placa: placa,
              marcaModelo: marcaModelo,
              year: year,
              font: font,
              widthPt: contentW,
              heightPt: contentH,
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Future<void> _printStickersA4({
    required String qrData,
    required int copies,
    required pw.Font? font,
  }) async {
    final pdf = pw.Document();
    final qrBytes = await _generateQrPngBytes(qrData);

    final year = DateTime.now().year;
    final placa = widget.vehiculo.placa;
    final marcaModelo = '${widget.vehiculo.marca} ${widget.vehiculo.modelo}';

    final stickerW = _sticker50x80.width;
    final stickerH = _sticker50x80.height;

    const cols = 3;
    const rows = 3;
    const perPage = cols * rows;

    const spacing = 12.0;
    const runSpacing = 12.0;

    final totalPages = (copies / perPage).ceil();

    for (int page = 0; page < totalPages; page++) {
      final start = page * perPage;
      final end = (start + perPage) > copies ? copies : (start + perPage);
      final countThisPage = end - start;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          theme: font != null ? pw.ThemeData.withFont(base: font, bold: font) : pw.ThemeData(),
          build: (context) {
            return pw.Center(
              child: pw.Wrap(
                spacing: spacing,
                runSpacing: runSpacing,
                children: List.generate(countThisPage, (_) {
                  return _buildStickerWidget(
                    qrBytes: qrBytes,
                    placa: placa,
                    marcaModelo: marcaModelo,
                    year: year,
                    font: font,
                    widthPt: stickerW,
                    heightPt: stickerH,
                  );
                }),
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Future<void> _mostrarOpcionesImpresion() async {
    if (_imprimiendo) return;

    final qrData =
        (widget.vehiculo.qrToken != null && widget.vehiculo.qrToken!.isNotEmpty)
            ? widget.vehiculo.qrToken!
            : widget.vehiculo.placa;

    final font = await _loadProjectFont();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const Text(
                'Opciones de impresión',
                style: TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle', fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.local_offer, color: Color(0xFF00A86B)),
                title: const Text(
                  'Sticker individual (50×80mm)',
                  style: TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                ),
                subtitle: const Text('Ideal para imprimir 1 etiqueta.', style: TextStyle(color: Colors.white70)),
                onTap: () async {
                  Navigator.pop(context);
                  await _runPrintJob(() async {
                    await _printSingleSticker(qrData: qrData, pageFormat: _sticker50x80, font: font);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.description, color: Color(0xFF00A86B)),
                title: const Text(
                  'Hoja A4 (9 stickers por hoja)',
                  style: TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                ),
                subtitle: const Text('Imprime varias etiquetas para recortar.', style: TextStyle(color: Colors.white70)),
                onTap: () async {
                  Navigator.pop(context);
                  final copias = await _pedirCopiasA4();
                  if (copias == null) return;

                  await _runPrintJob(() async {
                    await _printStickersA4(qrData: qrData, copies: copias, font: font);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.print, color: Color(0xFF00A86B)),
                title: const Text(
                  'Impresora térmica (rollo 80mm)',
                  style: TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                ),
                subtitle: const Text('Centra el sticker 50×80 en rollo 80mm.', style: TextStyle(color: Colors.white70)),
                onTap: () async {
                  Navigator.pop(context);
                  await _runPrintJob(() async {
                    await _printSingleSticker(qrData: qrData, pageFormat: _thermal80, font: font);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long, color: Color(0xFF00A86B)),
                title: const Text(
                  'Impresora térmica (rollo 58mm)',
                  style: TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                ),
                subtitle: const Text('Centra el sticker 50×80 en rollo 58mm.', style: TextStyle(color: Colors.white70)),
                onTap: () async {
                  Navigator.pop(context);
                  await _runPrintJob(() async {
                    await _printSingleSticker(qrData: qrData, pageFormat: _thermal58, font: font);
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runPrintJob(Future<void> Function() job) async {
    if (_imprimiendo) return;
    setState(() => _imprimiendo = true);

    try {
      await job();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al imprimir: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (!mounted) return;
      setState(() => _imprimiendo = false);
    }
  }

  Future<int?> _pedirCopiasA4() async {
    final controller = TextEditingController(text: '9');

    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Copias para A4', style: TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ej: 9, 18, 27...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.red, fontFamily: 'BBH_Sans_Bogle')),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              if (v == null || v <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa un número válido'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(context, v);
            },
            child: const Text('Aceptar', style: TextStyle(color: Colors.green, fontFamily: 'BBH_Sans_Bogle')),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final qrData =
        (widget.vehiculo.qrToken != null && widget.vehiculo.qrToken!.isNotEmpty)
            ? widget.vehiculo.qrToken!
            : widget.vehiculo.placa;

    final anio = widget.vehiculo.anio?.toString() ?? "—";
    final color = _datoStr(widget.vehiculo.color);
    final tipo = _datoStr(widget.vehiculo.tipoVehiculo);
    final propietario = _datoStr(widget.vehiculo.propietarioNombre);
    final telefono = _datoStr(widget.vehiculo.propietarioTelefono);
    final nota = _datoStr(widget.vehiculo.notaIngreso);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A86B),
        title: Text(
          '${widget.vehiculo.marca} ${widget.vehiculo.modelo}',
          style: const TextStyle(fontFamily: 'BBH_Sans_Bogle'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // QR + Botón imprimir
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.35),
                      blurRadius: 12,
                      spreadRadius: 3,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrImageView(
                      data: qrData,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _imprimiendo ? null : _mostrarOpcionesImpresion,
                      icon: Icon(_imprimiendo ? Icons.hourglass_top : Icons.print),
                      label: Text(
                        _imprimiendo ? 'Imprimiendo...' : 'Imprimir QR',
                        style: const TextStyle(fontFamily: 'BBH_Sans_Bogle'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // DATOS DEL VEHÍCULO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00A86B)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "DATOS DEL VEHÍCULO",
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'BBH_Sans_Bogle',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _dato("Marca", _datoStr(widget.vehiculo.marca)),
                  _dato("Modelo", _datoStr(widget.vehiculo.modelo)),
                  _dato("Placa", _datoStr(widget.vehiculo.placa)),
                  _dato("Tipo", tipo),
                  _dato("Año", anio),
                  _dato("Color", color),
                  _dato("Kilometraje", "$_kmActual km"),
                  _dato("Última visita", _datoStr(widget.vehiculo.ultimaVisita)),

                  const SizedBox(height: 14),

                  TextField(
                    controller: _kmCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Actualizar kilometraje",
                      labelStyle: TextStyle(color: Color(0xFF00A86B)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF00A86B)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF00A86B), width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  ElevatedButton.icon(
                    onPressed: _actualizandoKm ? null : _actualizarKilometraje,
                    icon: Icon(_actualizandoKm ? Icons.hourglass_top : Icons.save),
                    label: Text(
                      _actualizandoKm ? "Actualizando..." : "ACTUALIZAR KILOMETRAJE",
                      style: const TextStyle(fontFamily: 'BBH_Sans_Bogle', fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A86B),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // DATOS DEL PROPIETARIO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "DATOS DEL PROPIETARIO",
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'BBH_Sans_Bogle',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _dato("Propietario", propietario),
                  _dato("Teléfono", telefono),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // NOTA DE INGRESO
            if (nota != "—")
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.6)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "NOTA DE INGRESO",
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontFamily: 'BBH_Sans_Bogle',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      nota,
                      style: const TextStyle(color: Colors.white, fontFamily: 'BBH_Sans_Bogle'),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            Center(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00A86B),
                  side: const BorderSide(color: Color(0xFF00A86B)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'ATRÁS',
                  style: TextStyle(fontFamily: 'BBH_Sans_Bogle', fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
