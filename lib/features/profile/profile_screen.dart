import 'package:flutter/material.dart';
import '../../core/settings/app_settings.dart';
import '../assistant/settings/ai_settings_controller.dart';
import '../backup/backup_controller.dart';

class ProfileScreen extends StatelessWidget {
  final AppSettings settings;
  final AiSettingsController aiSettings;
  final BackupController backupController;
  const ProfileScreen({
    super.key,
    required this.settings,
    required this.aiSettings,
    required this.backupController,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          const Text(
            'Profil',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
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
                        Text(
                          'Alex',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text('Profil local WardrobeOS'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _Tile(
            icon: Icons.accessibility_new,
            title: 'Morphologie & proportions',
          ),
          _Tile(icon: Icons.style_outlined, title: 'Préférences de style'),
          _Tile(icon: Icons.notifications_none, title: 'Notifications'),
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text(
                'Mode sombre',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              value: settings.darkMode,
              onChanged: settings.setDarkMode,
            ),
          ),
          _BackupSettings(controller: backupController),
          _WardrobeGptSettings(controller: aiSettings),
          _Tile(icon: Icons.info_outline, title: 'À propos'),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'WardrobeOS Sprint 2 · Premium UI',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupSettings extends StatelessWidget {
  final BackupController controller;
  const _BackupSettings({required this.controller});

  Future<void> _confirmRestore(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurer la sauvegarde ?'),
        content: const Text(
          'Cette opération remplacera les données actuelles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.restoreBackup();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '💾 Sauvegarde',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              controller.lastBackupAt == null
                  ? 'Dernière sauvegarde : aucune'
                  : 'Dernière sauvegarde : ${controller.lastBackupAt!.toLocal()}',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: controller.busy ? null : controller.createBackup,
              icon: const Icon(Icons.save_alt),
              label: const Text('Créer une sauvegarde'),
            ),
            OutlinedButton.icon(
              onPressed:
                  controller.busy ? null : () => _confirmRestore(context),
              icon: const Icon(Icons.settings_backup_restore),
              label: const Text('Restaurer une sauvegarde'),
            ),
            if (controller.busy) const LinearProgressIndicator(),
            if (controller.result != null) ...[
              const SizedBox(height: 8),
              Text(controller.result!),
            ],
          ],
        ),
      ),
    ),
  );
}

class _WardrobeGptSettings extends StatefulWidget {
  final AiSettingsController controller;

  const _WardrobeGptSettings({required this.controller});

  @override
  State<_WardrobeGptSettings> createState() => _WardrobeGptSettingsState();
}

class _WardrobeGptSettingsState extends State<_WardrobeGptSettings> {
  final _apiKeyController = TextEditingController();
  bool _obscureKey = true;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    try {
      await widget.controller.save(_apiKeyController.text);
      _apiKeyController.clear();
      _show('Clé API enregistrée');
    } catch (_) {
      _show('Saisissez une clé API OpenAI valide.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final busy = widget.controller.busy;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '🤖 WardrobeGPT',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Statut IA : '
                  '${widget.controller.configured ? "Connectée" : "Non configurée"}',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Clé API OpenAI',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed:
                          () => setState(() => _obscureKey = !_obscureKey),
                      icon: Icon(
                        _obscureKey ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy ? null : _save,
                  child: const Text('Enregistrer'),
                ),
                OutlinedButton(
                  onPressed:
                      busy
                          ? null
                          : () async =>
                              _show(await widget.controller.testConnection()),
                  child: const Text('Tester la connexion'),
                ),
                TextButton(
                  onPressed:
                      busy || !widget.controller.configured
                          ? null
                          : () async {
                            await widget.controller.delete();
                            _show('Clé API supprimée');
                          },
                  child: const Text('Supprimer la clé'),
                ),
              ],
            ),
          ),
        );
      },
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
