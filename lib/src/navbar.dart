import 'dart:convert';
import 'package:flutter/material.dart';
import 'session.dart';
import 'login_page.dart';

// ─── Paleta RevUp ─────────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E90FF);
const _kBlueDark = Color(0xFF0A5FCC);
const _kBg       = Color(0xFF04060D);
const _kWhite    = Color(0xFFF0F4FF);

class Navbar extends StatefulWidget {
  const Navbar({super.key});
  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  // ════════════════════════ LÓGICA ORIGINAL INTACTA ════════════════════════ //
  String nombre    = "Usuario";
  String correo    = "";
  String? avatarB64;

  @override
  void initState() { super.initState(); _loadUser(); }

  Future<void> _loadUser() async {
    final u = await Session.loadUser();
    if (!mounted) return;
    setState(() {
      nombre    = (u?['nombre']     ?? 'Usuario').toString();
      correo    = (u?['correo']     ?? '').toString();
      avatarB64 = u?['avatar_b64']?.toString();
    });
  }

  ImageProvider? _avatarProvider() {
    final b64 = (avatarB64 ?? '').trim();
    if (b64.isEmpty) return null;
    final cleaned = b64.contains(',') ? b64.split(',').last : b64;
    try { return MemoryImage(base64Decode(cleaned)); } catch (_) { return null; }
  }
  // ═════════════════════════════════════════════════════════════════════════ //

  @override
  Widget build(BuildContext context) {
    final img = _avatarProvider();
    final initial = nombre.isNotEmpty ? nombre[0].toUpperCase() : "U";

    return Theme(
      data: ThemeData(fontFamily: 'Ubuntu'),
      child: Drawer(
        backgroundColor: _kBg,
        width: 290,
        child: Column(
          children: [

            // ── Header ─────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 24,
                bottom: 24, left: 22, right: 22,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D1E3A), Color(0xFF060B18)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: img == null
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF2AA0FF), _kBlueDark],
                                )
                              : null,
                          boxShadow: [BoxShadow(
                            color: _kBlue.withOpacity(0.35),
                            blurRadius: 16, offset: const Offset(0, 4),
                          )],
                        ),
                        child: img != null
                            ? ClipOval(child: Image(image: img, fit: BoxFit.cover))
                            : Center(child: Text(initial, style: const TextStyle(
                                fontFamily: 'Ubuntu', color: Colors.white,
                                fontWeight: FontWeight.w800, fontSize: 28,
                              ))),
                      ),
                      // Indicador de estado online
                      Positioned(
                        right: 2, bottom: 2,
                        child: Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.greenAccent,
                            border: Border.all(color: _kBg, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Nombre
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontFamily: 'Ubuntu', color: _kWhite,
                      fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Correo con ícono
                  Row(children: [
                    Icon(Icons.email_outlined, color: _kBlue.withOpacity(0.6), size: 13),
                    const SizedBox(width: 5),
                    Flexible(child: Text(
                      correo,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Ubuntu',
                        color: _kWhite.withOpacity(0.45),
                        fontSize: 12,
                      ),
                    )),
                  ]),

                  const SizedBox(height: 16),

                  // Línea decorativa
                  Container(height: 1, decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      _kBlue.withOpacity(0.5), _kBlue.withOpacity(0.05),
                    ]),
                  )),
                ],
              ),
            ),

            // ── Items de navegación ─────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0xFF060B18), _kBg],
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  children: [
                    _navItem(context, Icons.dashboard_rounded,     "Inicio",         "/inicio"),
                    _navItem(context, Icons.person_rounded,         "Perfil",         "/perfil"),
                    _navItem(context, Icons.directions_car_rounded, "Vehículos",      "/vehiculos"),
                    _navItem(context, Icons.assignment_rounded,     "Órdenes (OT)",   "/ordenes"),
                    _navItem(context, Icons.bar_chart_rounded,      "Reportes",       "/reportes"),
                  ],
                ),
              ),
            ),

            // ── Cerrar sesión ───────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [_kBg, Color(0xFF060B18)],
                ),
              ),
              child: Column(children: [
                Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent, _kBlue.withOpacity(0.15), Colors.transparent,
                    ]),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1),
                        color: Colors.redAccent.withOpacity(0.07),
                      ),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                        label: const Text(
                          "Cerrar sesión",
                          style: TextStyle(
                            fontFamily: 'Ubuntu', color: Colors.redAccent,
                            fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          await Session.clear();
                          if (!context.mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                            (route) => false,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    "© ${DateTime.now().year} Andrew Carrera",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Ubuntu', fontSize: 10,
                      color: Colors.white24, letterSpacing: 0.3,
                    ),
                  ),
                ),
              ]),
            ),

          ],
        ),
      ),
    );
  }

  // ── Item de navegación ────────────────────────────────────────────────────
  Widget _navItem(BuildContext context, IconData icon, String label, String route) {
    final isCurrent = ModalRoute.of(context)?.settings.name == route;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, route);
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: isCurrent ? _kBlue.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrent ? _kBlue.withOpacity(0.30) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(children: [
              // Ícono con fondo sutil si está activo
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? _kBlue.withOpacity(0.18)
                      : _kWhite.withOpacity(0.05),
                ),
                child: Icon(icon,
                  color: isCurrent ? _kBlue : _kWhite.withOpacity(0.45),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(
                fontFamily: 'Ubuntu',
                color: isCurrent ? _kWhite : _kWhite.withOpacity(0.55),
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              )),
              if (isCurrent) ...[
                const Spacer(),
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kBlue,
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}