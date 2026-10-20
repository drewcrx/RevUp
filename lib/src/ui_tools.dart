import 'dart:math';
import 'package:flutter/material.dart';

double? parseImporte(String text) {
  final value = text.trim();
  if (!RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(value)) return null;
  final number = double.tryParse(value.replaceAll(',', '.'));
  return number != null && number.isFinite && number <= 9999999999.99
      ? number
      : null;
}

String dinero(dynamic value) =>
    '\$${(double.tryParse('$value') ?? 0).toStringAsFixed(2)}';
String nuevaOperacion() {
  final random = Random.secure();
  return List.generate(
    32,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Espera también la retirada del overlay antes de liberar controladores.
Future<T?> showStableDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    barrierDismissible: false,
  );
  final result = await Navigator.of(context).push(route);
  await route.completed;
  return result;
}

Future<bool> confirmar(
  BuildContext context,
  String title,
  String message, {
  String action = 'Confirmar',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class ProtegerFormulario extends StatefulWidget {
  final bool Function() tieneCambios;
  final bool guardando;
  final Widget child;
  const ProtegerFormulario({
    super.key,
    required this.tieneCambios,
    required this.child,
    this.guardando = false,
  });
  @override
  State<ProtegerFormulario> createState() => _ProtegerFormularioState();
}

class _ProtegerFormularioState extends State<ProtegerFormulario> {
  bool _salir = false;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _salir || (!widget.guardando && !widget.tieneCambios()),
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || widget.guardando) return;
      if (await confirmar(
            context,
            'Datos sin guardar',
            'Si sales se perderán los cambios de este formulario.',
            action: 'Salir',
          ) &&
          mounted) {
        setState(() => _salir = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, result);
        });
      }
    },
    child: widget.child,
  );
}
