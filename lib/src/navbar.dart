import 'dart:convert';
import 'package:flutter/material.dart';
import 'session.dart';
import 'login_page.dart';

class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  String nombre = "Usuario";
  String correo = "";
  String? avatarB64;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await Session.loadUser();
    if (!mounted) return;

    setState(() {
      nombre = (u?['nombre'] ?? 'Usuario').toString();
      correo = (u?['correo'] ?? '').toString();
      avatarB64 = u?['avatar_b64']?.toString();
    });
  }

  // ✅ MISMO COMPORTAMIENTO QUE EDITAR PERFIL:
  // - Si no hay avatar => null (se muestra Icon(Icons.person))
  // - Si hay base64 => MemoryImage
  ImageProvider? _avatarProvider() {
    final b64 = (avatarB64 ?? '').trim();
    if (b64.isEmpty) return null;

    final cleaned = b64.contains(',') ? b64.split(',').last : b64;

    try {
      final bytes = base64Decode(cleaned);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  Widget _avatar() {
    final img = _avatarProvider();

    return CircleAvatar(
      radius: 36,
      backgroundColor: Colors.black,
      backgroundImage: img,
      child: img == null
          ? const Icon(Icons.person, size: 42, color: Colors.white70)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF000000),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              nombre,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'BBH_Sans_Bogle',
                fontWeight: FontWeight.bold,
              ),
            ),
            accountEmail: Text(
              correo,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'BBH_Sans_Bogle',
              ),
            ),
            currentAccountPicture: _avatar(),
            decoration: const BoxDecoration(
              color: Color(0xFF00A86B),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildDrawerItem(icon: Icons.home, text: "Inicio", context: context, routeName: "/inicio"),
                _buildDrawerItem(icon: Icons.person, text: "Perfil", context: context, routeName: "/perfil"),
                _buildDrawerItem(icon: Icons.car_repair, text: "Vehículos", context: context, routeName: "/vehiculos"),
                _buildDrawerItem(icon: Icons.assignment, text: "Órdenes (OT)", context: context, routeName: "/ordenes"),
                _buildDrawerItem(icon: Icons.bar_chart, text: "Reportes", context: context, routeName: "/reportes"),
              ],
            ),
          ),
          const Divider(color: Colors.white54),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.exit_to_app, color: Colors.white),
                label: const Text(
                  "Cerrar sesión",
                  style: TextStyle(
                    fontFamily: 'BBH_Sans_Bogle',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        ],
      ),
    );
  }

  ListTile _buildDrawerItem({
    required IconData icon,
    required String text,
    required BuildContext context,
    required String routeName,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF00A86B)),
      title: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'BBH_Sans_Bogle',
          fontSize: 16,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, routeName);
      },
    );
  }
}
