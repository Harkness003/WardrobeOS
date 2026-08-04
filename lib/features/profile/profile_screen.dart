import 'package:flutter/material.dart';
import '../../core/settings/app_settings.dart';
import '../assistant/settings/ai_settings_controller.dart';
import '../backup/backup_controller.dart';
import '../../weather/location/location_service.dart';
import '../../weather/location/unified_location_service.dart';

class ProfileScreen extends StatelessWidget {
  final AppSettings settings;
  final AiSettingsController aiSettings;
  final BackupController backupController;
  final UnifiedLocationService locationService;
  const ProfileScreen({
    super.key,
    required this.settings,
    required this.aiSettings,
    required this.backupController,
    required this.locationService,
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
          _LocationSettings(service: locationService),
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

class _LocationSettings extends StatefulWidget {
  final UnifiedLocationService service;
  const _LocationSettings({required this.service});

  @override
  State<_LocationSettings> createState() => _LocationSettingsState();
}

class _LocationSettingsState extends State<_LocationSettings> {
  final _cityController = TextEditingController();
  List<LocationData> _results = const [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.service.searchCities(_cityController.text);
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) _error = 'Aucune ville trouvée.';
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Recherche indisponible. Réessayez.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.service,
    builder: (context, _) {
      final service = widget.service;
      final manual = service.manualLocation;
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('📍 Localisation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              RadioListTile<LocationMode>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Utiliser ma position actuelle'),
                value: LocationMode.gps,
                groupValue: service.mode,
                onChanged: (_) => service.useGps(),
              ),
              RadioListTile<LocationMode>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Choisir une ville manuellement'),
                value: LocationMode.manual,
                groupValue: service.mode,
                onChanged: (_) => service.useManualMode(),
              ),
              if (service.mode == LocationMode.manual) ...[
                TextField(
                  controller: _cityController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText: 'Rechercher une ville',
                    suffixIcon: IconButton(onPressed: _searching ? null : _search, icon: const Icon(Icons.search)),
                  ),
                ),
                if (_searching) const LinearProgressIndicator(),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!)),
                for (final result in _results)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_city),
                    title: Text(result.city),
                    subtitle: Text('${result.latitude.toStringAsFixed(3)}, ${result.longitude.toStringAsFixed(3)}'),
                    onTap: () async {
                      await service.useManualLocation(result);
                      if (mounted) setState(() => _results = const []);
                    },
                  ),
                if (manual != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text('Ville utilisée : ${manual.city}'),
                    trailing: IconButton(
                      tooltip: 'Supprimer la ville',
                      onPressed: service.clearManualLocation,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('Aucune ville définie. Le GPS sera utilisé s’il est disponible.'),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _BackupSettings extends StatelessWidget {
  final BackupController controller;
  const _BackupSettings({required this.controller});

  Future<void> _confirmRestore(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
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
    builder:
        (context, _) => Card(
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
