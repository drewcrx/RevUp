import 'dart:math' as math;
import 'package:flutter/material.dart';

typedef Pieza3D = ({String vista, String zona});
typedef _V = ({double x, double y, double z});
_V _v(double x, double y, double z) => (x: x, y: y, z: z);
_V _resta(_V a, _V b) => _v(a.x - b.x, a.y - b.y, a.z - b.z);
_V _cruz(_V a, _V b) =>
    _v(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);

class _Cara {
  final List<_V> p;
  final Color color;
  final Pieza3D pieza;
  const _Cara(this.p, this.color, this.pieza);
}

class _Proyectada {
  final Path path;
  final double depth;
  final Color color;
  final Pieza3D pieza;
  const _Proyectada(this.path, this.depth, this.color, this.pieza);
}

/// Malla local de referencia. Cada panel conserva su pieza y coordenadas 3D;
/// selección, iluminación y perspectiva usan la misma transformación de cámara.
class Vehiculo3DPage extends StatefulWidget {
  final String tipoVehiculo;
  final List<Map<String, dynamic>> danos;
  const Vehiculo3DPage({
    super.key,
    this.tipoVehiculo = 'Sedán',
    this.danos = const [],
  });
  @override
  State<Vehiculo3DPage> createState() => _Vehiculo3DPageState();
}

class _Vehiculo3DPageState extends State<Vehiculo3DPage> {
  late String _tipo = widget.tipoVehiculo.toLowerCase().contains('suv')
      ? 'SUV'
      : widget.tipoVehiculo.toLowerCase().contains('pickup') ||
            widget.tipoVehiculo.toLowerCase().contains('camioneta')
      ? 'Pickup'
      : 'Sedán';
  late List<_Cara> _malla = _crearAuto(_tipo);
  double _yaw = .65, _pitch = .35, _zoom = 1, _inicioZoom = 1;
  Pieza3D? _seleccion;
  List<_Proyectada> _proyectadas = [];
  void _vista(double yaw, double pitch) {
    setState(() {
      _yaw = yaw;
      _pitch = pitch;
      _zoom = 1;
      _seleccion = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF080E1A),
    appBar: AppBar(
      title: const Text('Vehículo 3D'),
      actions: [
        IconButton(
          tooltip: 'Restablecer vista',
          onPressed: () => _vista(.65, .35),
          icon: const Icon(Icons.center_focus_strong),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Modelo de referencia',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                  ),
                ),
                DropdownButton<String>(
                  value: _tipo,
                  dropdownColor: const Color(0xFF0D1420),
                  items: [
                    for (final t in ['Sedán', 'SUV', 'Pickup'])
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (t) => setState(() {
                    _tipo = t!;
                    _malla = _crearAuto(_tipo);
                    _seleccion = null;
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, bounds) => GestureDetector(
                key: const Key('vehiculo-3d-lienzo'),
                behavior: HitTestBehavior.opaque,
                onScaleStart: (_) => _inicioZoom = _zoom,
                onScaleUpdate: (d) => setState(() {
                  if (d.pointerCount == 1) {
                    _yaw += d.focalPointDelta.dx * .012;
                    _pitch = (_pitch + d.focalPointDelta.dy * .008).clamp(
                      .05,
                      1.50,
                    );
                  }
                  _zoom = (_inicioZoom * d.scale).clamp(.65, 2.5);
                }),
                onTapUp: (d) {
                  for (final face in _proyectadas.reversed) {
                    if (face.path.contains(d.localPosition)) {
                      setState(() => _seleccion = face.pieza);
                      break;
                    }
                  }
                },
                child: CustomPaint(
                  size: bounds.biggest,
                  painter: _AutoPainter(
                    caras: _malla,
                    yaw: _yaw,
                    pitch: _pitch,
                    zoom: _zoom,
                    seleccion: _seleccion,
                    afectadas: widget.danos
                        .map(
                          (d) => (vista: '${d['vista']}', zona: '${d['zona']}'),
                        )
                        .toSet(),
                    onProjected: (faces) => _proyectadas = faces,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () => _vista(0, .25),
                  child: const Text('Frontal'),
                ),
                TextButton(
                  onPressed: () => _vista(math.pi, .25),
                  child: const Text('Posterior'),
                ),
                TextButton(
                  onPressed: () => _vista(math.pi / 2, .25),
                  child: const Text('Izquierdo'),
                ),
                TextButton(
                  onPressed: () => _vista(-math.pi / 2, .25),
                  child: const Text('Derecho'),
                ),
                TextButton(
                  onPressed: () => _vista(0, 1.50),
                  child: const Text('Superior'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Arrastra para girar · Pellizca para acercar · Toca una pieza',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey, fontSize: 11),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _seleccion == null
                ? const Text(
                    'Selecciona una pieza del modelo',
                    style: TextStyle(color: Color(0xFFF0F4FF), fontSize: 12),
                  )
                : FilledButton.icon(
                    key: const Key('inspeccionar-pieza-3d'),
                    onPressed: () => Navigator.pop(context, _seleccion),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: Text('Inspeccionar ${_seleccion!.zona}'),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _AutoPainter extends CustomPainter {
  final List<_Cara> caras;
  final double yaw, pitch, zoom;
  final Pieza3D? seleccion;
  final Set<Pieza3D> afectadas;
  final ValueChanged<List<_Proyectada>> onProjected;
  _AutoPainter({
    required this.caras,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.seleccion,
    required this.afectadas,
    required this.onProjected,
  });
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final ground = Rect.fromCenter(
      center: Offset(size.width * .5, size.height * .75),
      width: size.width * .72,
      height: size.height * .2,
    );
    canvas.drawOval(
      ground,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x552A93E5), Color(0x00080E1A)],
        ).createShader(ground),
    );
    final projected = <_Proyectada>[];
    final cy = math.cos(yaw),
        sy = math.sin(yaw),
        cp = math.cos(pitch),
        sp = math.sin(pitch);
    final scale = math.min(size.width / 5.5, size.height / 3.5) * zoom;
    for (final face in caras) {
      final points = <Offset>[];
      double depth = 0;
      for (final p in face.p) {
        final x = p.x * cy + p.z * sy, z = -p.x * sy + p.z * cy;
        final y = (p.y - .75) * cp + z * sp, d = z * cp - (p.y - .75) * sp;
        final perspective = 7 / (7 + d);
        points.add(
          Offset(
            size.width * .5 + x * scale * perspective,
            size.height * .53 - y * scale * perspective,
          ),
        );
        depth += d;
      }
      final normal = _cruz(
        _resta(face.p[1], face.p[0]),
        _resta(face.p[2], face.p[0]),
      );
      final center = _v(
        face.p.fold(0.0, (sum, p) => sum + p.x) / face.p.length,
        face.p.fold(0.0, (sum, p) => sum + p.y) / face.p.length,
        face.p.fold(0.0, (sum, p) => sum + p.z) / face.p.length,
      );
      final toCamera = _v(
        7 * cp * sy - center.x,
        .75 + 7 * sp - center.y,
        -7 * cp * cy - center.z,
      );
      if (normal.x * toCamera.x +
              normal.y * toCamera.y +
              normal.z * toCamera.z <=
          0)
        continue;
      final norm = math.sqrt(
        normal.x * normal.x + normal.y * normal.y + normal.z * normal.z,
      );
      final lighting = norm < .00001
          ? 0.65
          : (.50 +
                    .42 *
                        ((normal.x * -.35 + normal.y * .85 + normal.z * -.4) /
                                norm)
                            .abs())
                .clamp(.35, 1.0);
      Color base = face.color;
      if (afectadas.contains(face.pieza))
        base = Color.lerp(base, Colors.orangeAccent, .60)!;
      if (seleccion == face.pieza)
        base = Color.lerp(base, const Color(0xFF1E90FF), .65)!;
      final color = Color.fromARGB(
        255,
        (base.r * 255 * lighting).round().clamp(0, 255),
        (base.g * 255 * lighting).round().clamp(0, 255),
        (base.b * 255 * lighting).round().clamp(0, 255),
      );
      final path = Path()..addPolygon(points, true);
      projected.add(
        _Proyectada(path, depth / face.p.length, color, face.pieza),
      );
    }
    projected.sort((a, b) => b.depth.compareTo(a.depth));
    final fill = Paint()..isAntiAlias = false;
    for (final face in projected) {
      canvas.drawPath(face.path, fill..color = face.color);
    }
    onProjected(projected);
  }

  @override
  bool shouldRepaint(covariant _AutoPainter old) =>
      old.caras != caras ||
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.zoom != zoom ||
      old.seleccion != seleccion ||
      old.afectadas != afectadas;
}

List<_Cara> _crearAuto(String tipo) {
  final faces = <_Cara>[];
  const body = Color(0xFFD3E0E8),
      chrome = Color(0xFFB9CAD3),
      glass = Color(0xFF294451),
      rubber = Color(0xFF1B222B),
      trim = Color(0xFF202D38);
  const capo = (vista: 'frontal', zona: 'Capó'),
      techo = (vista: 'superior', zona: 'Techo'),
      frente = (vista: 'frontal', zona: 'Parachoques delantero'),
      atras = (vista: 'posterior', zona: 'Parachoques posterior');
  final suv = tipo == 'SUV', pickup = tipo == 'Pickup';
  final extra = suv
      ? 0.12
      : pickup
      ? 0.09
      : 0.0;
  Pieza3D lado(double side, String zona) =>
      (vista: side > 0 ? 'lateral_izquierdo' : 'lateral_derecho', zona: zona);
  void quad(
    _V a,
    _V b,
    _V c,
    _V d,
    Color color,
    Pieza3D pieza, {
    _V? reference,
  }) {
    double distance(_V a, _V b) => math.sqrt(
      math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2) + math.pow(a.z - b.z, 2),
    );
    if (reference == null && pieza.zona.startsWith('Llanta'))
      reference = _v(
        pieza.vista == 'lateral_izquierdo' ? 0.93 : -0.93,
        .38 + extra,
        pieza.zona.endsWith('delantera') ? -1.42 : 1.42,
      );
    if (reference == null &&
        color == glass &&
        pieza.vista.startsWith('lateral_'))
      reference = _v(0, .65, 0);
    final n =
        ([
                  distance(a, b),
                  distance(b, c),
                  distance(c, d),
                  distance(d, a),
                ].reduce(math.max) /
                .34)
            .ceil()
            .clamp(1, 6);
    _V interpolate(double u, double v) => _v(
      a.x * (1 - u) * (1 - v) +
          b.x * u * (1 - v) +
          c.x * u * v +
          d.x * (1 - u) * v,
      a.y * (1 - u) * (1 - v) +
          b.y * u * (1 - v) +
          c.y * u * v +
          d.y * (1 - u) * v,
      a.z * (1 - u) * (1 - v) +
          b.z * u * (1 - v) +
          c.z * u * v +
          d.z * (1 - u) * v,
    );
    void triangle(List<_V> points) {
      if (reference != null) {
        final normal = _cruz(
          _resta(points[1], points[0]),
          _resta(points[2], points[0]),
        );
        final center = _v(
          points.fold(0.0, (sum, p) => sum + p.x) / 3,
          points.fold(0.0, (sum, p) => sum + p.y) / 3,
          points.fold(0.0, (sum, p) => sum + p.z) / 3,
        );
        if (normal.x * (center.x - reference.x) +
                normal.y * (center.y - reference.y) +
                normal.z * (center.z - reference.z) <
            0)
          points = points.reversed.toList();
      }
      faces.add(_Cara(points, color, pieza));
    }

    for (var i = 0; i < n; i++)
      for (var j = 0; j < n; j++) {
        final p = interpolate(i / n, j / n),
            q = interpolate((i + 1) / n, j / n),
            r = interpolate((i + 1) / n, (j + 1) / n),
            t = interpolate(i / n, (j + 1) / n);
        triangle([p, q, r]);
        triangle([p, r, t]);
      }
  }

  void box(
    double x,
    double y,
    double z,
    double w,
    double h,
    double l,
    Color color,
    Pieza3D pieza,
  ) {
    final a = _v(x - w / 2, y - h / 2, z - l / 2),
        b = _v(x + w / 2, y - h / 2, z - l / 2),
        c = _v(x + w / 2, y + h / 2, z - l / 2),
        d = _v(x - w / 2, y + h / 2, z - l / 2);
    final e = _v(x - w / 2, y - h / 2, z + l / 2),
        f = _v(x + w / 2, y - h / 2, z + l / 2),
        g = _v(x + w / 2, y + h / 2, z + l / 2),
        hh = _v(x - w / 2, y + h / 2, z + l / 2);
    quad(a, b, c, d, color, pieza, reference: _v(x, y, z));
    quad(f, e, hh, g, color, pieza, reference: _v(x, y, z));
    quad(e, a, d, hh, color, pieza, reference: _v(x, y, z));
    quad(b, f, g, c, color, pieza, reference: _v(x, y, z));
    quad(d, c, g, hh, color, pieza, reference: _v(x, y, z));
    quad(e, f, b, a, color, pieza, reference: _v(x, y, z));
  }

  final stations = [
    -2.24,
    -2.08,
    -1.85,
    -1.65,
    -1.42,
    -1.18,
    -.96,
    -.70,
    0.0,
    .65,
    .96,
    1.18,
    1.42,
    1.65,
    1.85,
    2.08,
    2.24,
  ];
  final rings = <List<_V>>[];
  for (final z in stations) {
    final end = (z.abs() / 2.24);
    final width = .96 - .23 * math.pow(end, 7);
    final top = .89 + extra - .25 * math.pow(end, 8);
    final wheelDistance = math.min((z - 1.42).abs(), (z + 1.42).abs());
    final bottom = wheelDistance < .45
        ? 0.38 + extra + math.sqrt(.45 * .45 - wheelDistance * wheelDistance)
        : .27 + extra;
    final middle = bottom + (top - bottom) * .46;
    rings.add([
      _v(-width * .88, bottom, z),
      _v(-width, middle, z),
      _v(-width * .98, top - .04, z),
      _v(-width * .83, top, z),
      _v(width * .83, top, z),
      _v(width * .98, top - .04, z),
      _v(width, middle, z),
      _v(width * .88, bottom, z),
    ]);
  }
  for (var i = 0; i < rings.length - 1; i++) {
    final z = (stations[i] + stations[i + 1]) / 2;
    for (var j = 0; j < 8; j++) {
      if (pickup && z > .65 && j == 3) continue;
      Pieza3D pieza;
      if (j == 3) {
        pieza = z < -.85
            ? capo
            : z > 1.0
            ? (vista: 'posterior', zona: 'Baúl / compuerta')
            : techo;
      } else if (j == 7) {
        pieza = frente;
      } else {
        final side = j < 3 ? -1.0 : 1.0;
        pieza = lado(
          side,
          z < -.95
              ? 'Guardafango delantero'
              : z < .05
              ? 'Puerta delantera'
              : z < 1.0
              ? 'Puerta posterior'
              : 'Guardafango posterior',
        );
      }
      quad(
        rings[i][j],
        rings[i + 1][j],
        rings[i + 1][(j + 1) % 8],
        rings[i][(j + 1) % 8],
        body,
        pieza,
      );
    }
  }
  faces.add(_Cara(rings.first, body, frente));
  faces.add(_Cara(rings.last.reversed.toList(), body, atras));
  // Cabina: pilares y techo curvo; cristales independientes de los paneles.
  final roof = suv
      ? 1.79
      : pickup
      ? 1.64
      : 1.49;
  final rearRoof = pickup
      ? 0.32
      : suv
      ? 1.29
      : .72;
  final rearBase = pickup
      ? 0.64
      : suv
      ? 1.92
      : 1.34;
  final cabin = [
    (z: -.97, y: .88 + extra, w: .80),
    (z: -.38, y: roof, w: .66),
    (z: rearRoof, y: roof, w: .66),
    (z: rearBase, y: .89 + extra, w: .80),
  ];
  for (var i = 0; i < cabin.length - 1; i++) {
    final a = cabin[i], b = cabin[i + 1];
    for (var j = 0; j < 6; j++) {
      final t = j / 5 - 0.5, next = (j + 1) / 5 - 0.5;
      if (j == 5) break;
      final arch = math.sin((j / 5) * math.pi) * .045,
          arch2 = math.sin(((j + 1) / 5) * math.pi) * .045;
      quad(
        _v(a.w * t * 2, a.y + arch, a.z),
        _v(b.w * t * 2, b.y + arch, b.z),
        _v(b.w * next * 2, b.y + arch2, b.z),
        _v(a.w * next * 2, a.y + arch2, a.z),
        i == 1 && (j == 0 || j == 4) ? body : glass,
        i == 0
            ? (vista: 'frontal', zona: 'Parabrisas')
            : i == 2
            ? (vista: 'posterior', zona: 'Luneta')
            : techo,
      );
    }
  }
  for (final side in [-1.0, 1.0]) {
    final front = lado(side, 'Puerta delantera'),
        back = lado(side, 'Puerta posterior');
    quad(
      _v(side * .81, .91 + extra, -.94),
      _v(side * .68, roof - .04, -.36),
      _v(side * .68, roof - .04, .01),
      _v(side * .87, .91 + extra, .01),
      glass,
      front,
    );
    if (!pickup)
      quad(
        _v(side * .87, .91 + extra, .08),
        _v(side * .68, roof - .04, .08),
        _v(side * .68, roof - .04, rearRoof - .04),
        _v(side * .81, .91 + extra, rearBase - .08),
        glass,
        back,
      );
    // Pilar central y bordes de puerta visibles, con grosor real.
    box(side * .865, .91 + extra, .04, .026, .045, .10, trim, front);
    box(side * .935, .78 + extra, -.11, .028, .034, .20, chrome, front);
    if (!pickup)
      box(side * .935, .78 + extra, .90, .028, .034, .20, chrome, back);
    box(
      side * 1.03,
      1.0 + extra,
      -.66,
      .23,
      .12,
      .22,
      body,
      lado(side, 'Espejo'),
    );
    box(
      side * 1.10,
      1.0 + extra,
      -.64,
      .01,
      .08,
      .16,
      glass,
      lado(side, 'Espejo'),
    );
    box(side * .965, .57 + extra, .035, .01, .46, .018, trim, front);
    // Neumáticos, llantas, radios y bujes, con eje transversal.
    for (final z in [-1.42, 1.42]) {
      final pieza = lado(side, z < 0 ? 'Llanta delantera' : 'Llanta posterior');
      final cy = .38 + extra, centerX = side * .93;
      const segments = 24;
      for (var i = 0; i < segments; i++) {
        final a = i * 2 * math.pi / segments,
            b = (i + 1) * 2 * math.pi / segments;
        _V wheel(double x, double angle, double radius) =>
            _v(x, cy + math.sin(angle) * radius, z + math.cos(angle) * radius);
        quad(
          wheel(centerX - .13, a, .39),
          wheel(centerX + .13, a, .39),
          wheel(centerX + .13, b, .39),
          wheel(centerX - .13, b, .39),
          rubber,
          pieza,
        );
        final outside = centerX + side * .135;
        quad(
          wheel(outside, a, .39),
          wheel(outside, b, .39),
          wheel(outside, b, .27),
          wheel(outside, a, .27),
          rubber,
          pieza,
        );
        faces.add(
          _Cara(
            [
              _v(outside, cy, z),
              wheel(outside, a, .265),
              wheel(outside, b, .265),
            ].letWheelSide(side),
            trim,
            pieza,
          ),
        );
        quad(
          wheel(outside + side * .003, a, .27),
          wheel(outside + side * .003, b, .27),
          wheel(outside + side * .003, b, .24),
          wheel(outside + side * .003, a, .24),
          chrome,
          pieza,
        );
      }
      for (var spoke = 0; spoke < 5; spoke++) {
        final a = spoke * 2 * math.pi / 5, x = centerX + side * .141;
        quad(
          _v(x, cy + math.sin(a - .28) * .065, z + math.cos(a - .28) * .065),
          _v(x, cy + math.sin(a + .28) * .065, z + math.cos(a + .28) * .065),
          _v(x, cy + math.sin(a + .09) * .24, z + math.cos(a + .09) * .24),
          _v(x, cy + math.sin(a - .09) * .24, z + math.cos(a - .09) * .24),
          chrome,
          pieza,
        );
      }
      box(centerX + side * .15, cy, z, .018, .10, .10, chrome, pieza);
    }
  }
  // Parrilla, placas, ópticas, luces de posición y paragolpes.
  box(0, .45 + extra, -2.24, .92, .24, .03, trim, (
    vista: 'frontal',
    zona: 'Rejilla',
  ));
  for (var i = 0; i < 4; i++)
    box(0, .37 + extra + i * .05, -2.262, .81, .012, .016, chrome, (
      vista: 'frontal',
      zona: 'Rejilla',
    ));
  box(0, .30 + extra, -2.285, .42, .11, .02, chrome, (
    vista: 'frontal',
    zona: 'Placa delantera',
  ));
  box(0, .46 + extra, 2.245, .42, .12, .02, chrome, (
    vista: 'posterior',
    zona: 'Placa posterior',
  ));
  for (final side in [-1.0, 1.0]) {
    box(side * .56, .65 + extra, -2.15, .41, .12, .17, glass, (
      vista: 'frontal',
      zona: side > 0 ? 'Faro izquierdo' : 'Faro derecho',
    ));
    box(
      side * .56,
      .68 + extra,
      -2.24,
      .34,
      .025,
      .025,
      const Color(0xFFF0FBFF),
      (vista: 'frontal', zona: side > 0 ? 'Faro izquierdo' : 'Faro derecho'),
    );
    box(side * .58, .65 + extra, 2.15, .40, .13, .18, const Color(0xFFEB3449), (
      vista: 'posterior',
      zona: side > 0 ? 'Stop izquierdo' : 'Stop derecho',
    ));
  }
  if (pickup) {
    box(0, .60 + extra, 1.40, 1.58, .055, 1.40, trim, (
      vista: 'superior',
      zona: 'Baúl',
    ));
    for (final side in [-1.0, 1.0])
      box(
        side * .86,
        .87 + extra,
        1.40,
        .13,
        .12,
        1.51,
        body,
        lado(side, 'Guardafango posterior'),
      );
  }
  return faces;
}

extension on List<_V> {
  List<_V> letWheelSide(double side) => side > 0 ? reversed.toList() : this;
}
