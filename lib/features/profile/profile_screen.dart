import 'package:flutter/material.dart';
import '../../core/settings/app_settings.dart';
import '../assistant/settings/ai_settings_controller.dart';
import '../backup/backup_controller.dart';
import '../../weather/location/location_service.dart';
import '../../weather/location/unified_location_service.dart';
import '../styles/style_library_screen.dart';
import '../styles/style_repository.dart';
import '../styles/style_enrichment_service.dart';
import '../../widgets/content_state.dart';
import '../developer/developer_diagnostics_screen.dart';

class ProfileScreen extends StatelessWidget {
  final AppSettings settings;
  final AiSettingsController aiSettings;
  final BackupController backupController;
  final UnifiedLocationService locationService;
  final StyleRepository styleRepository;
  final StyleEnrichmentService styleEnrichment;
  const ProfileScreen({
    super.key,
    required this.settings,
    required this.aiSettings,
    required this.backupController,
    required this.locationService,
    required this.styleRepository,
    required this.styleEnrichment,
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
          _Tile(icon: Icons.style_outlined, title: 'Bibliothèque des styles',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
              StyleLibraryScreen(repository: styleRepository,
                enrichment: aiSettings.configured ? styleEnrichment : null)))),
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
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.developer_mode),
                title: const Text('Mode développeur', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Diagnostics métier locaux et anonymisés'),
                value: settings.developerMode,
                onChanged: settings.setDeveloperMode,
              ),
              if (settings.developerMode)
                ListTile(
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: const Text('Centre de diagnostic'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const DeveloperDiagnosticsScreen(),
                  )),
                ),
            ]),
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
              RadioGroup<LocationMode>(
                groupValue: service.mode,
                onChanged: (value) {
                  if (value == LocationMode.gps) {
                    service.useGps();
                  } else if (value == LocationMode.manual) {
                    service.useManualMode();
                  }
                },
                child: Column(children: [
                  RadioListTile<LocationMode>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Utiliser ma position actuelle'),
                    value: LocationMode.gps,
                  ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(service.mode == LocationMode.gps ? Icons.gps_fixed : Icons.location_city),
                title: Text(service.mode == LocationMode.gps
                    ? 'Source utilisée : position GPS'
                    : manual == null ? 'Source utilisée : ville manuelle non définie' : 'Ville utilisée : ${manual.city}'),
                subtitle: Text(service.mode == LocationMode.gps
                    ? 'La ville sera résolue depuis la position actuelle lors de la météo.'
                    : manual == null ? 'Sélectionne une ville ci-dessous.' : 'Sélection manuelle'),
              ),
                  RadioListTile<LocationMode>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Choisir une ville manuellement'),
                    value: LocationMode.manual,
                  ),
                ]),
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
    final selected = await controller.selectRestore();
    if (!selected || !context.mounted) return;
    final manifest = controller.pendingRestore!.manifest;
    final content = manifest.content.entries
        .where((entry) => entry.value > 0)
        .map((entry) => '${entry.key} : ${entry.value}')
        .join('\n');
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmer la restauration'),
            content: Text(
              'Date : ${manifest.createdAt.toLocal()}\n'
              'Fichier : ${controller.pendingPath}\n'
              'Version : ${manifest.appVersion}\n'
              'Schéma : ${manifest.schemaVersion}\n\n'
              'Contenu :\n${content.isEmpty ? 'Aucune donnée' : content}\n\n'
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
    if (confirmed == true) await controller.confirmRestore();
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
                  controller.lastBackup == null
                      ? 'Dernière sauvegarde : aucune'
                      : 'Dernière sauvegarde\n'
                        'Date : ${controller.lastBackup!.createdAt.toLocal()}\n'
                        'Version : ${controller.lastBackup!.appVersion}\n'
                        'Vêtements : ${controller.lastBackup!.garmentCount}\n'
                        'Photos : ${controller.lastBackup!.photoCount}\n'
                        'Emplacement : ${controller.lastLocation}',
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
                if (controller.busy) const ContentState.loading(
                  title: 'Opération en cours', message: 'Lecture et vérification des données de sauvegarde…'),
                if (controller.result != null) ...[
                  const SizedBox(height: 8),
                  controller.resultIsError
                    ? ContentState.error(title: 'Opération impossible', message: controller.result!, actionLabel: null)
                    : ContentState(kind: ContentStateKind.success, title: '', message: '',
                        child: Semantics(liveRegion: true, child: Card(child: ListTile(
                          leading: const Icon(Icons.check_circle_outline), title: const Text('Opération terminée'),
                          subtitle: Text(controller.result!))))),
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
  final VoidCallback? onTap;
  const _Tile({required this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
