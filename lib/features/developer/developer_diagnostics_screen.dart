import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/diagnostics/diagnostic_service.dart';

class DeveloperDiagnosticsScreen extends StatefulWidget {
  const DeveloperDiagnosticsScreen({super.key});

  @override
  State<DeveloperDiagnosticsScreen> createState() => _DeveloperDiagnosticsScreenState();
}

class _DeveloperDiagnosticsScreenState extends State<DeveloperDiagnosticsScreen> {
  final service = DiagnosticService.instance;
  final Set<AppDiagnosticLevel> levels = AppDiagnosticLevel.values.toSet();
  DiagnosticModule? module;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Centre de diagnostic'),
      actions: [
        IconButton(
          tooltip: 'Exporter un rapport',
          icon: const Icon(Icons.ios_share),
          onPressed: _export,
        ),
        IconButton(
          tooltip: 'Vider l’historique',
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: () => service.clear(module),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        if (!service.enabled) {
          return const Center(child: Text('Le mode développeur est désactivé.'));
        }
        final visible = service.filtered(levels: levels, module: module);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Diagnostic métier', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const Text('Les secrets, prompts, photos, chemins et identifiants privés sont toujours exclus.'),
            const SizedBox(height: 12),
            DropdownButtonFormField<DiagnosticModule?>(
              value: module,
              decoration: const InputDecoration(labelText: 'Module'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tous les modules')),
                ...DiagnosticModule.values.map((value) => DropdownMenuItem(value: value, child: Text(value.label))),
              ],
              onChanged: (value) => setState(() => module = value),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: AppDiagnosticLevel.values.map((level) => FilterChip(
              selected: levels.contains(level), label: Text(level.name.toUpperCase()),
              avatar: Icon(_levelIcon(level), size: 18, color: _levelColor(level)),
              onSelected: (selected) => setState(() => selected ? levels.add(level) : levels.remove(level)),
            )).toList()),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              const Card(child: ListTile(
                leading: Icon(Icons.monitor_heart_outlined),
                title: Text('Aucun diagnostic'),
                subtitle: Text('Utilisez l’application : les prochains résultats métier apparaîtront ici.'),
              )),
            for (final value in visible) _DiagnosticCard(value: value),
          ],
        );
      },
    ),
  );

  Future<void> _export() async {
    await Clipboard.setData(ClipboardData(text: service.exportReport(levels: levels, module: module)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapport anonymisé copié dans le presse-papiers.')),
      );
    }
  }
}

class _DiagnosticCard extends StatelessWidget {
  final DiagnosticEntry value;
  const _DiagnosticCard({required this.value});

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: Icon(_levelIcon(value.level), color: _levelColor(value.level)),
      title: Text('${value.module.label} · ${value.level.name.toUpperCase()}',
        style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${value.summary}\n${_date(value.date)} · ${value.duration.inMilliseconds} ms'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line('État', value.state),
        _line('Source', value.source),
        _line('Version', value.version),
        if (value.reason != null) _line('Raison', value.reason!),
        if (value.warning != null) _line('Avertissement', value.warning!),
        if (value.pipeline.isNotEmpty) ...[
          const Divider(),
          const Text('Pipeline réel', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final step in value.pipeline) ListTile(
            dense: true, contentPadding: EdgeInsets.zero,
            leading: Icon(_levelIcon(step.level), color: _levelColor(step.level)),
            title: Text(step.name),
            subtitle: step.detail == null ? null : Text(step.detail!),
            trailing: Text('${step.duration.inMilliseconds} ms'),
          ),
        ],
        if (value.details.isNotEmpty) ...[
          const Divider(),
          for (final detail in value.details.entries) _line(detail.key, '${detail.value}'),
        ],
      ],
    ),
  );

  static Widget _line(String label, String text) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Text('$label : $text'),
  );

  static String _date(DateTime value) => value.toLocal().toIso8601String().replaceFirst('T', ' ').split('.').first;
}

IconData _levelIcon(AppDiagnosticLevel level) => switch (level) {
  AppDiagnosticLevel.info => Icons.info_outline,
  AppDiagnosticLevel.warning => Icons.warning_amber_rounded,
  AppDiagnosticLevel.error => Icons.cancel_outlined,
  AppDiagnosticLevel.success => Icons.check_circle_outline,
};

Color _levelColor(AppDiagnosticLevel level) => switch (level) {
  AppDiagnosticLevel.info => Colors.blue,
  AppDiagnosticLevel.warning => Colors.orange,
  AppDiagnosticLevel.error => Colors.red,
  AppDiagnosticLevel.success => Colors.green,
};
