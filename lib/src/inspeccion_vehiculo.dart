import 'dart:math' as math;

import 'package:flutter/material.dart';

const _azul = Color(0xFF1E90FF);
const _naranja = Colors.orangeAccent;
const _texto = Color(0xFFF0F4FF);
const _fondo = Color(0xFF080E1A);

class ZonaVehiculo {
  final String nombre;
  final double x;
  final double y;

  const ZonaVehiculo(this.nombre, this.x, this.y);
}

// Coordenadas sobre los renders originales de 1536 × 1024. Los nombres y
// las vistas conservan las claves de los daños ya guardados en la API.
// Izquierda/derecha se refieren siempre al vehículo, visto desde el conductor.
const zonasVehiculo = <String, List<ZonaVehiculo>>{
  'frontal': [
    ZonaVehiculo('Parabrisas', 0.50, 0.26),
    ZonaVehiculo('Faro izquierdo', 0.76, 0.53),
    ZonaVehiculo('Faro derecho', 0.24, 0.53),
    ZonaVehiculo('Capó', 0.50, 0.44),
    ZonaVehiculo('Rejilla', 0.37, 0.61),
    ZonaVehiculo('Parachoques delantero', 0.69, 0.76),
    ZonaVehiculo('Placa delantera', 0.50, 0.71),
  ],
  'posterior': [
    ZonaVehiculo('Luneta', 0.50, 0.27),
    ZonaVehiculo('Stop izquierdo', 0.27, 0.48),
    ZonaVehiculo('Stop derecho', 0.73, 0.48),
    ZonaVehiculo('Baúl / compuerta', 0.62, 0.40),
    ZonaVehiculo('Parachoques posterior', 0.68, 0.68),
    ZonaVehiculo('Placa posterior', 0.50, 0.53),
  ],
  'lateral_izquierdo': [
    ZonaVehiculo('Techo', 0.53, 0.28),
    ZonaVehiculo('Espejo', 0.36, 0.40),
    ZonaVehiculo('Guardafango delantero', 0.17, 0.49),
    ZonaVehiculo('Puerta delantera', 0.42, 0.54),
    ZonaVehiculo('Puerta posterior', 0.63, 0.54),
    ZonaVehiculo('Guardafango posterior', 0.84, 0.51),
    ZonaVehiculo('Llanta delantera', 0.20, 0.63),
    ZonaVehiculo('Llanta posterior', 0.77, 0.63),
  ],
  'lateral_derecho': [
    ZonaVehiculo('Techo', 0.47, 0.28),
    ZonaVehiculo('Espejo', 0.64, 0.40),
    ZonaVehiculo('Guardafango delantero', 0.83, 0.49),
    ZonaVehiculo('Puerta delantera', 0.58, 0.54),
    ZonaVehiculo('Puerta posterior', 0.37, 0.54),
    ZonaVehiculo('Guardafango posterior', 0.16, 0.51),
    ZonaVehiculo('Llanta delantera', 0.80, 0.63),
    ZonaVehiculo('Llanta posterior', 0.23, 0.63),
  ],
  'superior': [
    ZonaVehiculo('Capó', 0.50, 0.14),
    ZonaVehiculo('Parabrisas', 0.50, 0.28),
    ZonaVehiculo('Techo', 0.50, 0.50),
    ZonaVehiculo('Luneta', 0.50, 0.72),
    ZonaVehiculo('Baúl', 0.50, 0.83),
  ],
};

/// Vistas de un sedán de referencia con selección de piezas sobre el render.
/// Imagen y marcadores comparten recorte y transformación, también con zoom.
class MapaVehiculoInspeccion extends StatelessWidget {
  final String vista;
  final String nombreVista;
  final Map<String, int> danosPorZona;
  final ValueChanged<String> onZonaTap;

  const MapaVehiculoInspeccion({
    super.key,
    required this.vista,
    required this.nombreVista,
    required this.danosPorZona,
    required this.onZonaTap,
  });

  Future<void> _ampliar(BuildContext context) async {
    final zona = await showDialog<String>(
      context: context,
      builder: (_) => _VehiculoAmpliado(
        vista: vista,
        nombreVista: nombreVista,
        danosPorZona: danosPorZona,
      ),
    );
    if (context.mounted && zona != null) onZonaTap(zona);
  }

  @override
  Widget build(BuildContext context) {
    final afectadas = danosPorZona.values.where((n) => n > 0).length;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _fondo,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _azul.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.directions_car_filled_rounded,
                  color: _azul,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mapa de carrocería',
                        style: TextStyle(
                          color: _texto,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$nombreVista · ${zonasVehiculo[vista]!.length} zonas',
                        style: TextStyle(
                          color: _texto.withValues(alpha: 0.55),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ampliar vehículo',
                  onPressed: () => _ampliar(context),
                  icon: const Icon(
                    Icons.open_in_full_rounded,
                    color: _azul,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          _ProyeccionVehiculo(
            key: ValueKey(vista),
            vista: vista,
            danosPorZona: danosPorZona,
            onZonaTap: onZonaTap,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _LeyendaVehiculo(),
                const SizedBox(height: 10),
                Text(
                  afectadas == 0
                      ? 'Sin daños registrados en esta vista'
                      : '$afectadas ${afectadas == 1 ? 'zona con daños' : 'zonas con daños'} en esta vista',
                  style: TextStyle(
                    color: afectadas > 0
                        ? _naranja
                        : _texto.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sedán de referencia · Toca una pieza para inspeccionarla',
                  style: TextStyle(
                    color: _texto.withValues(alpha: 0.40),
                    fontSize: 10,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeyendaVehiculo extends StatelessWidget {
  const _LeyendaVehiculo();

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 8,
    children: [
      for (final item in [
        (color: _azul, label: 'Seleccionar pieza'),
        (color: _naranja, label: 'Daño registrado'),
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              item.label,
              style: TextStyle(
                color: _texto.withValues(alpha: 0.65),
                fontSize: 10,
              ),
            ),
          ],
        ),
    ],
  );
}

class _ProyeccionVehiculo extends StatelessWidget {
  final String vista;
  final Map<String, int> danosPorZona;
  final ValueChanged<String> onZonaTap;

  const _ProyeccionVehiculo({
    super.key,
    required this.vista,
    required this.danosPorZona,
    required this.onZonaTap,
  });

  static double proporcion(String vista) => vista == 'superior' ? 0.85 : 1.5;

  @override
  Widget build(BuildContext context) {
    final lateral = vista.startsWith('lateral_');
    final asset =
        'assets/images/inspeccion/sedan_${lateral ? 'lateral' : vista}.png';
    return AspectRatio(
      aspectRatio: proporcion(vista),
      child: LayoutBuilder(
        builder: (context, bounds) {
          // La vista superior recorta solo el fondo de los lados del original.
          // Se aplica el mismo BoxFit a las coordenadas de todas las piezas.
          const original = Size(1536, 1024);
          final size = bounds.biggest;
          final fit = applyBoxFit(BoxFit.cover, original, size);
          final recorte = Alignment.center.inscribe(
            fit.source,
            Offset.zero & original,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: Transform.flip(
                    flipX: vista == 'lateral_derecho',
                    child: Image.asset(
                      asset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(
                          Icons.directions_car_rounded,
                          color: _azul,
                          size: 72,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              for (final zona in zonasVehiculo[vista]!)
                Positioned(
                  left:
                      ((zona.x * original.width - recorte.left) /
                                  recorte.width *
                                  size.width -
                              22)
                          .clamp(0.0, math.max(0.0, size.width - 44)),
                  top:
                      ((zona.y * original.height - recorte.top) /
                                  recorte.height *
                                  size.height -
                              22)
                          .clamp(0.0, math.max(0.0, size.height - 44)),
                  child: _MarcadorZona(
                    zona: zona.nombre,
                    cantidad: danosPorZona[zona.nombre] ?? 0,
                    onTap: () => onZonaTap(zona.nombre),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MarcadorZona extends StatelessWidget {
  final String zona;
  final int cantidad;
  final VoidCallback onTap;

  const _MarcadorZona({
    required this.zona,
    required this.cantidad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = cantidad > 0 ? _naranja : _azul;
    final label =
        '$zona · ${cantidad > 0 ? '$cantidad ${cantidad == 1 ? 'daño' : 'daños'}' : 'Sin daños registrados'}';
    return Semantics(
      label: label,
      onTap: onTap,
      button: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            key: ValueKey('zona-$zona'),
            onTap: onTap,
            excludeFromSemantics: true,
            radius: 22,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF06101F).withValues(alpha: 0.90),
                    border: Border.all(color: color, width: 1.6),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.28),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: cantidad > 0
                        ? Text(
                            '$cantidad',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : Icon(Icons.add_rounded, color: color, size: 17),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VehiculoAmpliado extends StatefulWidget {
  final String vista;
  final String nombreVista;
  final Map<String, int> danosPorZona;

  const _VehiculoAmpliado({
    required this.vista,
    required this.nombreVista,
    required this.danosPorZona,
  });

  @override
  State<_VehiculoAmpliado> createState() => _VehiculoAmpliadoState();
}

class _VehiculoAmpliadoState extends State<_VehiculoAmpliado> {
  final _transformacion = TransformationController();
  Size _viewport = Size.zero;

  @override
  void dispose() {
    _transformacion.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final actual = _transformacion.value;
    final escala = actual.getMaxScaleOnAxis();
    final nueva = (escala * factor).clamp(1.0, 4.0);
    if (nueva == 1) {
      _transformacion.value = Matrix4.identity();
      return;
    }
    final centro = _viewport.center(Offset.zero);
    final desplazamiento = Offset(
      actual.getTranslation().x,
      actual.getTranslation().y,
    );
    final destino = centro - (centro - desplazamiento) * (nueva / escala);
    _transformacion.value = Matrix4.diagonal3Values(nueva, nueva, 1)
      ..setTranslationRaw(destino.dx, destino.dy, 0);
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    backgroundColor: _fondo,
    child: Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        foregroundColor: _texto,
        leading: IconButton(
          tooltip: 'Cerrar ampliación',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(
          'Vista ${widget.nombreVista.toLowerCase()}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: _LeyendaVehiculo(),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bounds) {
                  _viewport = bounds.biggest;
                  final ancho = math.min(
                    bounds.maxWidth,
                    bounds.maxHeight *
                        _ProyeccionVehiculo.proporcion(widget.vista),
                  );
                  return InteractiveViewer(
                    transformationController: _transformacion,
                    minScale: 1,
                    maxScale: 4,
                    boundaryMargin: const EdgeInsets.all(80),
                    child: Center(
                      child: SizedBox(
                        width: ancho,
                        child: _ProyeccionVehiculo(
                          vista: widget.vista,
                          danosPorZona: widget.danosPorZona,
                          onZonaTap: (zona) => Navigator.pop(context, zona),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Pellizca para acercar · Arrastra para mover · Toca una pieza',
                textAlign: TextAlign.center,
                style: TextStyle(color: _texto, fontSize: 11, height: 1.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Alejar',
                    onPressed: () => _zoom(1 / 1.5),
                    icon: const Icon(Icons.remove_rounded, color: _azul),
                  ),
                  TextButton.icon(
                    onPressed: () => _transformacion.value = Matrix4.identity(),
                    icon: const Icon(
                      Icons.center_focus_strong_rounded,
                      size: 18,
                    ),
                    label: const Text('Restablecer'),
                    style: TextButton.styleFrom(foregroundColor: _azul),
                  ),
                  IconButton(
                    tooltip: 'Acercar',
                    onPressed: () => _zoom(1.5),
                    icon: const Icon(Icons.add_rounded, color: _azul),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
