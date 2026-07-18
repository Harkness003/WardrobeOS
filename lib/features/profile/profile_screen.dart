import 'package:flutter/material.dart';
import '../../core/settings/app_settings.dart';

class ProfileScreen extends StatelessWidget {
  final AppSettings settings;
  const ProfileScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          const Text('Profil', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 18),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(radius: 31, child: Icon(Icons.person, size: 32)),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alex', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        Text('Profil local WardrobeOS'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _Tile(icon: Icons.accessibility_new, title: 'Morphologie & proportions'),
          _Tile(icon: Icons.style_outlined, title: 'Préférences de style'),
          _Tile(icon: Icons.notifications_none, title: 'Notifications'),
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Mode sombre', style: TextStyle(fontWeight: FontWeight.w800)),
              value: settings.darkMode,
              onChanged: settings.setDarkMode,
            ),
          ),
          _Tile(icon: Icons.cloud_outlined, title: 'Sauvegarde & export'),
          _Tile(icon: Icons.info_outline, title: 'À propos'),
          const SizedBox(height: 18),
          Center(child: Text('WardrobeOS Sprint 2 · Premium UI', style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  const _Tile({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
