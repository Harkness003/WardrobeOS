import 'package:flutter/material.dart';
import '../../core/settings/app_settings.dart';
import '../assistant/settings/ai_settings_controller.dart';
import '../backup/backup_controller.dart';
import '../../weather/location/location_service.dart';
import '../../weather/location/unified_location_service.dart';
import '../wardrobe/ai_reanalysis_controller.dart';

class ProfileScreen extends StatelessWidget {
  final AppSettings settings;
  final AiSettingsController aiSettings;
  final BackupController backupController;
  final UnifiedLocationService locationService;
  final AiReanalysisController reanalysisController;
  const ProfileScreen({
    super.key,
    required this.settings,
    required this.aiSettings,
    required this.backupController,
    required this.locationService,
    required this.reanalysisController,
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
          _AiReanalysisSettings(controller: reanalysisController),
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

class _AiReanalysisSettings extends StatefulWidget {
  final AiReanalysisController controller;
  const _AiReanalysisSettings({required this.controller});

  @override
  State<_AiReanalysisSettings> createState() => _AiReanalysisSettingsState();
}

class _AiReanalysisSettingsState extends State<_AiReanalysisSettings> {
  AiReanalysisScope scope = AiReanalysisScope.all;
  (int, int)? estimate;
  bool estimating = false;

  Future<void> _estimate() async {
    setState(() => estimating = true);
    final value = await widget.controller.estimate(scope);
    if (mounted) setState(() { estimate = value; estimating = false; });
  }

  Future<void> _run() async {
    if (estimate == null) await _estimate();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lancer la réanalyse IA ?'),
        content: Text('${estimate!.$1} fiches concernées\nEnviron ${estimate!.$2} appels IA'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lancer')),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.runGlobal(scope);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final report = widget.controller.lastReport;
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Réanalyse IA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              DropdownButtonFormField<AiReanalysisScope>(
                initialValue: scope,
                decoration: const InputDecoration(labelText: 'Périmètre'),
                items: const [
                  DropdownMenuItem(value: AiReanalysisScope.all, child: Text('Tout le dressing')),
                  DropdownMenuItem(value: AiReanalysisScope.old, child: Text('Uniquement les fiches anciennes')),
                  DropdownMenuItem(value: AiReanalysisScope.style, child: Text('Uniquement le style')),
                  DropdownMenuItem(value: AiReanalysisScope.thermal, child: Text('Uniquement le thermique')),
                  DropdownMenuItem(value: AiReanalysisScope.composition, child: Text('Uniquement la composition')),
                ],
                onChanged: widget.controller.busy ? null : (value) => setState(() { scope = value!; estimate = null; }),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: estimating || widget.controller.busy ? null : _estimate, icon: const Icon(Icons.calculate_outlined), label: const Text('Calculer les fiches concernées')),
              if (estimate != null) Text('${estimate!.$1} fiches concernées · environ ${estimate!.$2} appels IA'),
              FilledButton.icon(onPressed: widget.controller.busy ? null : _run, icon: const Icon(Icons.auto_awesome), label: const Text('Réanalyser')),
              if (widget.controller.busy) ...[
                const LinearProgressIndicator(),
                Text(_profileStep(widget.controller.step), textAlign: TextAlign.center),
              ],
              if (report != null) Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Réussites : ${report.successes}\nÉchecs : ${report.failures}\nDurée : ${report.duration.inSeconds} s${report.errors.isEmpty ? '' : '\nErreurs :\n${report.errors.join('\n')}'}'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _profileStep(AiReanalysisStep step) => switch (step) {
  AiReanalysisStep.preparing => 'Préparation…',
  AiReanalysisStep.analyzing => 'Analyse…',
  AiReanalysisStep.comparing => 'Comparaison…',
  AiReanalysisStep.completed => 'Terminé',
  AiReanalysisStep.idle => '',
};

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
