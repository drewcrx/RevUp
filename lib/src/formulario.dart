import 'package:flutter/material.dart';
import 'ui_tools.dart';

class CampoFormulario {
  final String id, label, initial;
  final bool requerido, numero, fecha;
  final int lineas;
  final List<String>? opciones;
  final String? Function(String?)? validator;
  const CampoFormulario(
    this.id,
    this.label, {
    this.initial = '',
    this.requerido = true,
    this.numero = false,
    this.fecha = false,
    this.lineas = 1,
    this.opciones,
    this.validator,
  });
}

class FormularioPage extends StatefulWidget {
  final String title;
  final String? ayuda;
  final List<CampoFormulario> campos;
  final Future<void> Function(Map<String, String>) guardar;
  const FormularioPage({
    super.key,
    required this.title,
    required this.campos,
    required this.guardar,
    this.ayuda,
  });
  @override
  State<FormularioPage> createState() => _FormularioPageState();
}

class _FormularioPageState extends State<FormularioPage> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _ctrl = {
    for (final f in widget.campos) f.id: TextEditingController(text: f.initial),
  };
  bool _dirty = false, _saving = false;
  @override
  void dispose() {
    for (final c in _ctrl.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProtegerFormulario(
    tieneCambios: () => _dirty,
    guardando: _saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: BackButton(
          onPressed: _saving ? null : () => Navigator.maybePop(context),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.ayuda != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(widget.ayuda!),
              ),
            for (final f in widget.campos)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: f.opciones != null
                    ? DropdownButtonFormField<String>(
                        initialValue: f.initial.isEmpty ? null : f.initial,
                        decoration: InputDecoration(labelText: f.label),
                        items: [
                          for (final o in f.opciones!)
                            DropdownMenuItem(value: o, child: Text(o)),
                        ],
                        validator: (v) =>
                            f.requerido && (v == null || v.isEmpty)
                            ? 'Selecciona una opcion'
                            : null,
                        onChanged: _saving
                            ? null
                            : (v) {
                                _ctrl[f.id]!.text = v ?? '';
                                setState(() => _dirty = true);
                              },
                      )
                    : TextFormField(
                        controller: _ctrl[f.id],
                        enabled: !_saving,
                        readOnly: f.fecha,
                        keyboardType: f.numero
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              )
                            : TextInputType.text,
                        maxLines: f.lineas,
                        decoration: InputDecoration(
                          labelText: f.label,
                          suffixIcon: f.fecha
                              ? const Icon(Icons.calendar_month)
                              : null,
                        ),
                        validator:
                            f.validator ??
                            (v) => f.requerido && (v ?? '').trim().isEmpty
                                ? 'Completa este campo'
                                : null,
                        onChanged: (_) => setState(() => _dirty = true),
                        onTap: !f.fecha
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      DateTime.tryParse(_ctrl[f.id]!.text) ??
                                      DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null && mounted)
                                  setState(() {
                                    _ctrl[f.id]!.text =
                                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                    _dirty = true;
                                  });
                              },
                      ),
              ),
            FilledButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      if (!_form.currentState!.validate()) return;
                      FocusScope.of(context).unfocus();
                      setState(() => _saving = true);
                      try {
                        await widget.guardar({
                          for (final e in _ctrl.entries)
                            e.key: e.value.text.trim(),
                        });
                        if (!mounted) return;
                        setState(() {
                          _dirty = false;
                          _saving = false;
                        });
                        Navigator.pop(context, true);
                      } catch (e) {
                        if (mounted) {
                          setState(() => _saving = false);
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    },
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    ),
  );
}
