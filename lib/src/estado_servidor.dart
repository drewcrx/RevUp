import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class EstadoServidor extends StatefulWidget {
  const EstadoServidor({super.key});
  @override
  State<EstadoServidor> createState() => _EstadoServidorState();
}

class _EstadoServidorState extends State<EstadoServidor>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool? _online;
  bool _checking = false;
  DateTime? _checked;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    bool online = false;
    try {
      final response = await ApiService.client
          .get(Uri.parse('${ApiService.baseUrl}/health'))
          .timeout(const Duration(seconds: 5));
      online =
          response.statusCode == 200 && jsonDecode(response.body)['ok'] == true;
    } catch (_) {}
    if (mounted)
      setState(() {
        _online = online;
        _checked = DateTime.now();
        _checking = false;
      });
  }

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(
      Icons.circle,
      size: 10,
      color: _online == null
          ? Colors.blueGrey
          : _online!
          ? Colors.greenAccent
          : Colors.orangeAccent,
    ),
    title: Text(
      _online == null
          ? 'Comprobando servidor'
          : _online!
          ? 'Servidor disponible'
          : 'Servidor sin conexión',
      style: const TextStyle(fontSize: 12),
    ),
    subtitle: _checked == null
        ? null
        : Text(
            'Comprobado ${_checked!.hour.toString().padLeft(2, '0')}:${_checked!.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 10),
          ),
    trailing: IconButton(
      tooltip: 'Comprobar conexión',
      onPressed: _check,
      icon: const Icon(Icons.refresh, size: 18),
    ),
  );
}
