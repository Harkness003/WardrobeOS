import 'package:flutter/material.dart';

import '../../models/garment.dart';
import '../../models/style_analysis.dart';
import '../../models/wear_history.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/garment_image.dart';
import 'garment_form_screen.dart';
import 'wardrobe_controller.dart';
import 'reanalysis/garment_reanalysis_models.dart';
import 'reanalysis/garment_reanalysis_service.dart';
import '../styles/style_detail_screen.dart';
import '../styles/style_repository.dart';

String? _cleanDisplayText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) { return null; }
  final normalized = trimmed.toLowerCase();
  if (normalized == 'null' ||
      normalized == 'n/a' ||
      normalized == 'vide' ||
      normalized == 'inconnu' ||
      normalized == 'inconnue') {
    return null;
  }
  return trimmed;
}

List<String> _cleanDisplayList(Iterable<String>? values) =>
    (values ?? const <String>[])
        .map(_cleanDisplayText)
        .whereType<String>()
        .toSet()
        .toList(growable: false);

String _styleName(AppLocalizations l10n, String id) =>
    l10n.catalogEntry('style', id)['name'] as String? ??
    l10n.text('ui.unknownCatalogValue', fallback: 'Unknown');

String _fieldLabel(String field) => const {
  'name': 'Nom', 'category': 'Catégorie', 'color': 'Couleur',
  'material': 'Matière', 'season': 'Saison', 'brand': 'Marque',
  'composition': 'Composition', 'style': 'Style',
}[field] ?? field;

class _AiComparisonDialog extends StatefulWidget {
  final GarmentReanalysisProposal preview;
  const _AiComparisonDialog({required this.preview});

  @override
  State<_AiComparisonDialog> createState() => _AiComparisonDialogState();
}

class _AiComparisonDialogState extends State<_AiComparisonDialog> {
  final Set<String> accepted = {};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Comparer les modifications'),
    content: SizedBox(
      width: 560,
      child: widget.preview.changes.isEmpty
          ? const Text('L’IA ne propose aucune modification.')
          : ListView(
              shrinkWrap: true,
              children: [
                if (widget.preview.changes.any((item) => item.conflict))
                  const Card(
                    color: Color(0xFFFFF3CD),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('⚠️ Conflit utilisateur : ces valeurs ont été corrigées manuellement et restent conservées par défaut.'),
                    ),
                  ),
                for (final difference in widget.preview.changes)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fieldLabel(difference.field), style: const TextStyle(fontWeight: FontWeight.w900)),
                          if (difference.conflict) const Text('Conflit avec une modification utilisateur', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                          RadioGroup<bool>(
                            groupValue: accepted.contains(difference.field),
                            onChanged: (value) => setState(() {
                              if (value == true) {
                                accepted.add(difference.field);
                              } else {
                                accepted.remove(difference.field);
                              }
                            }),
                            child: Column(children: [
                              RadioListTile<bool>(
                                value: false,
                                title: const Text('Conserver ma valeur'),
                                subtitle: Text('${difference.currentValue ?? '—'}'),
                              ),
                              RadioListTile<bool>(
                                value: true,
                                title: const Text('Accepter la proposition IA'),
                                subtitle: Text('${difference.proposedValue ?? '—'}'),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      TextButton(onPressed: () => setState(() => accepted.clear()), child: const Text('Conserver toutes mes modifications')),
      TextButton(
        onPressed: () => setState(() {
          accepted
            ..clear()
            ..addAll(widget.preview.changes.where((item) => !item.conflict).map((item) => item.field));
        }),
        child: const Text('Accepter tout sans conflit'),
      ),
      FilledButton(onPressed: () => Navigator.pop(context, accepted), child: const Text('Appliquer')),
    ],
  );
}

String? _firstDisplayText(String? preferred, String? fallback) =>
    _cleanDisplayText(preferred) ?? _cleanDisplayText(fallback);

class GarmentDetailScreen extends StatefulWidget {
  final WardrobeController controller;
  final Garment garment;
  final GarmentReanalysisService reanalysisService;

  const GarmentDetailScreen({
    super.key,
    required this.controller,
    required this.garment,
    required this.reanalysisService,
  });

  @override
  State<GarmentDetailScreen> createState() => _GarmentDetailScreenState();
}

class _GarmentDetailScreenState extends State<GarmentDetailScreen> {
  final StyleRepository _styles = StyleCatalog();
  late Garment garment;
  bool _recordingWear = false;
  late Future<List<WearHistory>> _wearHistoryFuture;
  late Future<WearHistory?> _firstWearFuture;

  bool _reanalyzing = false;

  Future<void> _styleHelp(String id) async {
    final style = await _styles.find(id);
    if (!mounted) { return; }
    if (style == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce style n’est pas encore présent dans la bibliothèque.')));
      return;
    }
    final l10n = AppLocalizations.of(context);
    final visibleStyle = style.localized(l10n);
    await showModalBottomSheet<void>(context: context, showDragHandle: true,
      builder: (sheetContext) => Padding(padding: const EdgeInsets.all(20), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(visibleStyle.name, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8),
          Text(_cleanDisplayText(visibleStyle.definition) ?? _cleanDisplayText(visibleStyle.description) ?? l10n.text('ui.descriptionUnavailable', fallback: 'Description unavailable.')),
          if (visibleStyle.characteristics.isNotEmpty) ...[const SizedBox(height: 12), Text('${l10n.text('ui.characteristics')} : ${visibleStyle.characteristics.take(5).join(', ')}')],
          if (visibleStyle.examples.isNotEmpty) ...[const SizedBox(height: 8), Text('${l10n.text('ui.examples', fallback: 'Examples')} : ${visibleStyle.examples.take(4).join(', ')}')],
          if (visibleStyle.colors.isNotEmpty) ...[const SizedBox(height: 8), Text('${l10n.text('ui.associatedColors')} : ${visibleStyle.colors.take(5).join(', ')}')],
          if (visibleStyle.materials.isNotEmpty) ...[const SizedBox(height: 8), Text('${l10n.text('ui.frequentMaterials')} : ${visibleStyle.materials.take(5).join(', ')}')],
          if (visibleStyle.relatedStyleIds.isNotEmpty) ...[const SizedBox(height: 8), Text('${l10n.text('ui.relatedStyles')} : ${visibleStyle.relatedStyleIds.map((id) => _styleName(l10n, id)).take(4).join(', ')}')],
          const SizedBox(height: 12), FilledButton(onPressed: () { Navigator.pop(sheetContext); Navigator.push(context,
            MaterialPageRoute(builder: (_) => StyleDetailScreen(style: style, repository: _styles))); }, child: const Text('Voir la fiche complète')),
        ])));
  }

  Future<void> _editStyleAnalysis() async {
    final all = await _styles.all(); if (!mounted) return;
    final selected = garment.effectiveStyleAnalysis.compatibilities
        .map((value) => value.styleId).toSet();
    final characteristics = TextEditingController(text: garment.effectiveStyleAnalysis.characteristics.join(', '));
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (_, update) => AlertDialog(
      title: const Text('Corriger l’analyse de style'), content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(children: [
        Align(alignment: Alignment.centerLeft, child: Text('Compatibilités (aucun style principal imposé)', style: Theme.of(context).textTheme.titleSmall)),
        ...all.map((e) => CheckboxListTile(dense: true, value: selected.contains(e.id), title: Text(e.name), onChanged: (v) => update(() {
          if (v == true) {
            selected.add(e.id);
          } else {
            selected.remove(e.id);
          }
        }))),
        TextField(controller: characteristics, decoration: const InputDecoration(labelText: 'Caractéristiques (séparées par des virgules)')),
      ]))), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Enregistrer'))])));
    if (saved != true) { return; }
    final old = {for (final value in garment.effectiveStyleAnalysis.compatibilities) value.styleId: value};
    final corrected = garment.effectiveStyleAnalysis.withUserCorrections(
      compatibilities: selected.map((id) => old[id] ?? StyleCompatibility(styleId: id,
        score: 1, confidence: 1, justification: 'Compatibilité ajoutée par l’utilisateur')).toList(),
      characteristics: characteristics.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList());
    await widget.controller.save(garment.copyWith(styleAnalysis: corrected, updatedAt: DateTime.now()), isNew: false);
    _refreshGarment();
  }

  GarmentReanalysisType? get _missingAnalysisType {
    if (!_hasText(garment.sousCategorie)) { return GarmentReanalysisType.category; }
    if (!_hasText(garment.composition) && !_hasText(garment.compositionEstimee)) {
      return GarmentReanalysisType.composition;
    }
    if (garment.styleAnalysis == null) { return GarmentReanalysisType.style; }
    if (garment.thermalProfile == null) { return GarmentReanalysisType.thermal; }
    return null;
  }

  Future<void> _reanalyze() async {
    if (_reanalyzing) { return; }
    final target = _missingAnalysisType;
    if (target == null) {
      _showReanalysisMessage('La fiche contient déjà toutes les informations automatisables.');
      return;
    }
    if (garment.effectivePhotos.isEmpty) {
      _showReanalysisMessage('Ajoutez une photo exploitable pour compléter ces informations.');
      return;
    }
    setState(() => _reanalyzing = true);
    _showReanalysisMessage('Analyse avancée en cours');
    try {
      final proposal = await widget.reanalysisService.propose(
        garment.id,
        target,
      );
      if (!mounted) { return; }
      final accepted = await showDialog<Set<String>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AiComparisonDialog(preview: proposal),
      );
      if (accepted == null) {
        _showReanalysisMessage('Réanalyse annulée. Aucune donnée n’a été modifiée.');
        return;
      }
      await widget.reanalysisService.apply(proposal, accepted);
      await widget.controller.load();
      _refreshGarment();
      if (mounted) { _showReanalysisMessage('Réanalyse terminée. La fiche est à jour.'); }
    } catch (error) {
      if (mounted) { _showReanalysisMessage(error is Exception ? _friendlyReanalysisError(error) : 'Analyse impossible. Tes données sont intactes.'); }
    } finally {
      if (mounted) { setState(() => _reanalyzing = false); }
    }
  }

  String _friendlyReanalysisError(Exception error) {
    final text = error.toString();
    if (text.contains('photo') || text.contains('Photo')) { return 'Photos manquantes ou illisibles. Tes données sont intactes.'; }
    if (text.contains('annul')) { return 'Réanalyse annulée. Aucune donnée n’a été modifiée.'; }
    return 'Erreur IA : analyse impossible pour le moment. Tes données sont intactes.';
  }

  void _showReanalysisMessage(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  void initState() {
    super.initState();
    garment = widget.garment;
    _wearHistoryFuture = _loadWearHistory();
    _firstWearFuture = _loadFirstWear();
  }

  Future<void> edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) => GarmentFormScreen(
              controller: widget.controller,
              garment: garment,
            ),
      ),
    );
    if (changed == true) { _refreshGarment(); }
  }

  void _openPhoto() {
    if (!_hasText((garment.effectivePhotos.isEmpty ? null : garment.effectivePhotos.first.path))) { return; }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: GarmentImage(
                    imagePath: (garment.effectivePhotos.isEmpty ? null : garment.effectivePhotos.first.path),
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: IconButton.filled(
                tooltip: 'Fermer',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<WearHistory>> _loadWearHistory() {
    return widget.controller.getWearHistory(garment.id);
  }

  Future<WearHistory?> _loadFirstWear() {
    return widget.controller.getFirstWear(garment.id);
  }

  void _refreshGarment({bool reloadHistory = false}) {
    final match = widget.controller.garments.where(
      (item) => item.id == garment.id,
    );
    if (!mounted) { return; }

    setState(() {
      if (match.isNotEmpty) { garment = match.first; }
      if (reloadHistory) {
        _wearHistoryFuture = _loadWearHistory();
        _firstWearFuture = _loadFirstWear();
      }
    });
  }

  Future<void> recordWear() async {
    if (_recordingWear) { return; }

    setState(() => _recordingWear = true);

    try {
      final wornAt = await _pickWearDate();
      if (wornAt == null) { return; }

      final wear = await widget.controller.recordWear(garment, wornAt: wornAt);
      _refreshGarment(reloadHistory: true);

      if (!mounted) { return; }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Port enregistré le ${_formatDate(wear.wornAt)}.'),
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () => undoWear(wear),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Impossible d’enregistrer ce port. Réessaie dans quelques instants.",
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _recordingWear = false);
      }
    }
  }

  Future<DateTime?> _pickWearDate() async {
    final choice = await showModalBottomSheet<_WearDateChoice>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.today_outlined),
                  title: const Text('Aujourd’hui'),
                  onTap: () => Navigator.pop(context, _WearDateChoice.today),
                ),
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Choisir une date'),
                  onTap: () => Navigator.pop(context, _WearDateChoice.custom),
                ),
              ],
            ),
          ),
    );

    if (!mounted || choice == null) { return null; }
    if (choice == _WearDateChoice.today) { return DateTime.now(); }

    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    if (selectedDate == null) { return null; }

    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }

  Future<void> undoWear(WearHistory wear) async {
    try {
      final removed = await widget.controller.deleteWear(garment, wear);
      _refreshGarment(reloadHistory: true);

      if (!mounted || !removed) { return; }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Port annulé.')));
    } catch (_) {
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d’annuler ce port.")),
      );
    }
  }

  Future<void> deleteWear(WearHistory wear) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Supprimer ce port ?'),
            content: Text(
              'Le port du ${_formatDate(wear.wornAt)} à ${_formatTime(wear.wornAt)} sera supprimé définitivement.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );

    if (confirmed != true) { return; }

    try {
      final removed = await widget.controller.deleteWear(garment, wear);
      _refreshGarment(reloadHistory: true);

      if (!mounted || !removed) { return; }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Port supprimé.')));
    } catch (_) {
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de supprimer ce port.')),
      );
    }
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Supprimer cette pièce ?'),
            content: const Text(
              'Le vêtement et sa photo locale seront supprimés définitivement.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await widget.controller.delete(garment);
      if (mounted) { Navigator.pop(context, true); }
    }
  }

  Future<void> toggleFavorite() async {
    await widget.controller.toggleFavorite(garment);
    _refreshGarment();
  }

  @override
  Widget build(BuildContext context) {
    final identityChips =
        [
              garment.category,
              garment.sousCategorie,
              garment.couleurPrincipale ?? garment.color,
              garment.matierePrincipale ?? garment.material,
            ]
            .whereType<String>()
            .map(_cleanText)
            .whereType<String>()
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de la pièce'),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            onPressed: edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') { remove(); }
            },
            itemBuilder:
                (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline),
                        SizedBox(width: 10),
                        Text('Supprimer'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 34),
        children: [
          GestureDetector(
            onTap: _openPhoto,
            child: Hero(
              tag: 'garment-${garment.id}',
              child: GarmentImage(
                imagePath: (garment.effectivePhotos.isEmpty ? null : garment.effectivePhotos.first.path),
                width: double.infinity,
                height: 390,
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      garment.name,
                      style: const TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.8,
                      ),
                    ),
                    if (_hasText(garment.brand)) ...[
                      const SizedBox(height: 4),
                      Text(
                        garment.brand!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip:
                    garment.isFavorite
                        ? 'Retirer des favoris'
                        : 'Ajouter aux favoris',
                onPressed: toggleFavorite,
                icon: Icon(
                  garment.isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: edit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier cette pièce'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _reanalyzing ? null : _reanalyze,
            icon: _reanalyzing
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: const Text('Compléter automatiquement'),
          ),
          if (identityChips.isNotEmpty) ...[
            const SizedBox(height: 17),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  identityChips
                      .map((value) => Chip(label: Text(value)))
                      .toList(),
            ),
          ],
          const SizedBox(height: 16),
          _AdvancedSection(
            title: 'Analyse de l’IA',
            icon: Icons.auto_awesome_outlined,
            children: [
              if (garment.styleAnalysis != null) ...[
                Row(children: [const Expanded(child: Text('Compatibilités estimées', style: TextStyle(fontWeight: FontWeight.w800))),
                  IconButton(tooltip: 'Corriger les hypothèses', onPressed: _editStyleAnalysis, icon: const Icon(Icons.edit_outlined))]),
                FutureBuilder<List<LibraryStyle?>>(future: Future.wait(
                  garment.effectiveStyleAnalysis.compatibilities.map((value) => _styles.find(value.styleId)),
                ), builder: (_, snapshot) => Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final style in snapshot.data?.whereType<LibraryStyle>() ?? const <LibraryStyle>[])
                    ActionChip(avatar: const Icon(Icons.info_outline, size: 18), label: Text(style.localized(AppLocalizations.of(context)).name), onPressed: () => _styleHelp(style.id)),
                ])),
              ],
              _AiGarmentDetails(garment: garment),
            ],
          ),
          if (garment.thermalProfile != null) _AdvancedSection(
            title: 'Propriétés thermiques', icon: Icons.thermostat_outlined,
            children: [_ThermalSummary(garment: garment)],
          ),
          _AdvancedSection(
            title: 'Historique', icon: Icons.history,
            children: [
              _GarmentStatsGrid(garment: garment, firstWearFuture: _firstWearFuture,
                formatDate: _formatDate, formatPrice: _formatPrice,
                formatCalendarAge: _formatCalendarAge, daysSinceLastWearLabel: _daysSinceLastWearLabel),
              _WearHistoryCard(wearHistoryFuture: _wearHistoryFuture, formatDate: _formatDate,
                formatTime: _formatTime, onDelete: deleteWear),
            ],
          ),
          if (garment.effectivePhotos.length > 1) _AdvancedSection(
            title: 'Photos complémentaires', icon: Icons.photo_library_outlined,
            children: [Wrap(spacing: 8, runSpacing: 8, children: garment.effectivePhotos.skip(1).map((photo) =>
              GarmentImage(imagePath: photo.path, width: 96, height: 96, borderRadius: BorderRadius.circular(14))).toList())],
          ),
          if (_hasText(garment.notes) || _hasText(garment.composition) || _hasText(garment.size)) _AdvancedSection(
            title: 'Notes et informations avancées', icon: Icons.notes_outlined,
            children: [
              if (_hasText(garment.size)) _InfoTile(icon: Icons.straighten, label: 'Taille', value: garment.size!),
              if (_hasText(garment.composition)) _InfoTile(icon: Icons.science_outlined, label: 'Composition', value: garment.composition!, multiline: true),
              if (_hasText(garment.notes)) Padding(padding: const EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text(garment.notes!))),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _recordingWear ? null : recordWear,
            icon:
                _recordingWear
                    ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.check_circle_outline),
            label: Text(
              _recordingWear ? 'Enregistrement…' : "Je l'ai portée aujourd'hui",
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _hasText(String? value) => _cleanText(value) != null;

  static String? _cleanText(String? value) => _cleanDisplayText(value);

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatPrice(double value) {
    final decimals = value % 1 == 0 ? 0 : 2;
    return '${value.toStringAsFixed(decimals).replaceAll('.', ',')} €';
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _daysSinceLastWearLabel(DateTime? lastWorn) {
    if (lastWorn == null) { return 'Jamais porté'; }

    final today = _dateOnly(DateTime.now());
    final lastWearDay = _dateOnly(lastWorn);
    final days = today.difference(lastWearDay).inDays;
    if (days <= 0) { return 'Aujourd’hui'; }
    if (days == 1) { return '1 jour'; }
    return '$days jours';
  }

  static String _formatCalendarAge(DateTime since) {
    final today = _dateOnly(DateTime.now());
    final start = _dateOnly(since);
    final days = today.difference(start).inDays;

    if (days <= 0) { return 'Aujourd’hui'; }
    if (days == 1) { return '1 jour'; }
    if (days < 30) { return '$days jours'; }

    final months = days ~/ 30;
    if (months < 12) { return months == 1 ? '1 mois' : '$months mois'; }

    final years = days ~/ 365;
    final remainingMonths = (days % 365) ~/ 30;
    if (remainingMonths == 0) { return years == 1 ? '1 an' : '$years ans'; }
    final yearLabel = years == 1 ? '1 an' : '$years ans';
    final monthLabel =
        remainingMonths == 1 ? '1 mois' : '$remainingMonths mois';
    return '$yearLabel $monthLabel';
  }
}

enum _WearDateChoice { today, custom }

class _AdvancedSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _AdvancedSection({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: PageStorageKey<String>('garment-section-$title'),
      initiallyExpanded: false,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      children: children,
    ),
  );
}

class _ThermalSummary extends StatelessWidget {
  final Garment garment;
  const _ThermalSummary({required this.garment});
  @override
  Widget build(BuildContext context) {
    final profile = garment.thermalProfile!;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      Chip(label: Text(garment.layerType ?? 'Couche intermédiaire')),
      Chip(label: Text('Isolation ${profile.insulation.name}')),
      if (profile.windProtection.name != 'none') const Chip(label: Text('Protège du vent')),
      if (profile.rainCompatibility.name != 'none') const Chip(label: Text('Protège de la pluie')),
    ]);
  }
}

class _AiGarmentDetails extends StatelessWidget {
  final Garment garment;

  const _AiGarmentDetails({required this.garment});

  @override
  Widget build(BuildContext context) {
    final styleEntries = <_AiDetailEntry>[
      if (garment.styleAnalysis != null) ...[
        _AiDetailEntry.list('Compatible avec', garment.effectiveStyleAnalysis.compatibilities.map((value) =>
          '${_styleName(AppLocalizations.of(context), value.styleId)} · ${(value.score * 100).round()} % — ${value.justification}')),
      ],
      _AiDetailEntry.list('Points forts', garment.pointsForts),
      _AiDetailEntry.list('Points faibles', garment.pointsFaibles),
      _AiDetailEntry.list('Conseils', garment.conseils),
      _AiDetailEntry.text('Verdict', garment.verdict),
      _AiDetailEntry.text(
        'Explication de la polyvalence',
        garment.explicationPolyvalence,
      ),
    ];
    final associations = <_AiDetailEntry>[
      _AiDetailEntry.list('Couleurs compatibles', garment.couleursCompatibles),
      _AiDetailEntry.list(
        'Couleurs moins adaptées',
        garment.couleursMoinsAdaptees,
      ),
      _AiDetailEntry.list('Bas compatibles', garment.basCompatibles),
      _AiDetailEntry.list(
        'Chaussures compatibles',
        garment.chaussuresCompatibles,
      ),
    ];
    final characteristics = <_AiDetailEntry>[
      _AiDetailEntry.text('Type précis', garment.typePrecis),
      _AiDetailEntry.text(
        'Couleur principale',
        _firstDisplayText(garment.couleurPrincipale, garment.color),
      ),
      _AiDetailEntry.list(
        'Couleurs secondaires',
        garment.couleursSecondaires,
      ),
      _AiDetailEntry.text(
        'Matière principale',
        _firstDisplayText(garment.matierePrincipale, garment.material),
      ),
      _AiDetailEntry.list(
        'Matières secondaires',
        garment.matieresSecondaires,
      ),
      _AiDetailEntry.text('Composition estimée', garment.compositionEstimee),
    ];
    final care = <_AiDetailEntry>[
      _AiDetailEntry.text('Lavage', garment.lavage),
      _AiDetailEntry.text('Séchage', garment.sechage),
      _AiDetailEntry.text('Repassage', garment.repassage),
      _AiDetailEntry.text('Nettoyage', garment.nettoyage),
    ];
    final condition = <_AiDetailEntry>[
      _AiDetailEntry.text('Usure', garment.usureVisible),
      _AiDetailEntry.text('Boulochage', garment.boulochage),
      _AiDetailEntry.text('Taches', garment.taches),
      _AiDetailEntry.list('Défauts visibles', garment.defautsVisibles),
    ];
    final limits = <_AiDetailEntry>[
      _AiDetailEntry.text(
        'Confiance globale',
        garment.confianceGlobale == null
            ? null
            : '${(garment.confianceGlobale! * 100).round()} %',
      ),
      _AiDetailEntry.list('Avertissements IA', garment.avertissementsIA),
      _AiDetailEntry.list('Limites de l’analyse', garment.limitesAnalyse),
    ];
    final groups = <(_AiDetailGroup, List<_AiDetailEntry>)>[
      (
        const _AiDetailGroup(
          'Analyse stylistique',
          Icons.auto_awesome_outlined,
        ),
        styleEntries,
      ),
      (
        const _AiDetailGroup('Associations', Icons.checkroom_outlined),
        associations,
      ),
      (
        const _AiDetailGroup('Caractéristiques IA', Icons.palette_outlined),
        characteristics,
      ),
      (
        const _AiDetailGroup(
          'Entretien',
          Icons.local_laundry_service_outlined,
        ),
        care,
      ),
      (
        const _AiDetailGroup('État observé', Icons.visibility_outlined),
        condition,
      ),
      (const _AiDetailGroup('Fiabilité', Icons.info_outline), limits),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        const _SectionTitle('Analyse IA'),
        const SizedBox(height: 10),
        for (final group in groups.where((group) => group.$2.any((entry) => entry.isNotEmpty))) ...[
          _AiDetailCard(group: group.$1, entries: group.$2.where((entry) => entry.isNotEmpty).toList()),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AiDetailGroup {
  final String title;
  final IconData icon;

  const _AiDetailGroup(this.title, this.icon);
}

class _AiDetailEntry {
  final String label;
  final List<String> values;

  _AiDetailEntry.text(this.label, String? value)
    : values = _cleanDisplayList(value == null ? const [] : [value]);

  _AiDetailEntry.list(this.label, Iterable<String>? values)
    : values = _cleanDisplayList(values);

  bool get isNotEmpty => values.isNotEmpty;
}

class _AiDetailCard extends StatelessWidget {
  final _AiDetailGroup group;
  final List<_AiDetailEntry> entries;

  const _AiDetailCard({required this.group, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(group.icon, size: 21),
                const SizedBox(width: 10),
                Text(
                  group.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < entries.length; index++) ...[
              _AiDetailRow(entry: entries[index]),
              if (index < entries.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiDetailRow extends StatelessWidget {
  final _AiDetailEntry entry;

  const _AiDetailRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 5),
        if (entry.values.length == 1)
          Text(entry.values.single)
        else if (entry.values.isEmpty)
          const Text('Information non disponible.')
        else
          for (final value in entry.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('• $value'),
            ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
    );
  }
}

class _GarmentStatsGrid extends StatelessWidget {
  final Garment garment;
  final Future<WearHistory?> firstWearFuture;
  final String Function(DateTime date) formatDate;
  final String Function(double value) formatPrice;
  final String Function(DateTime date) formatCalendarAge;
  final String Function(DateTime? date) daysSinceLastWearLabel;

  const _GarmentStatsGrid({
    required this.garment,
    required this.firstWearFuture,
    required this.formatDate,
    required this.formatPrice,
    required this.formatCalendarAge,
    required this.daysSinceLastWearLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final costPerWear =
        garment.purchasePrice == null || garment.wearCount == 0
            ? 'Non disponible'
            : formatPrice(garment.purchasePrice! / garment.wearCount);
    final ageStart = garment.purchaseDate ?? garment.createdAt;

    return FutureBuilder<WearHistory?>(
      future: firstWearFuture,
      builder: (context, snapshot) {
        final firstWear = snapshot.data?.wornAt;
        final firstWearLabel =
            snapshot.connectionState == ConnectionState.waiting
                ? 'Chargement…'
                : firstWear == null
                ? 'Jamais porté'
                : formatDate(firstWear);

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 700 ? 3 : 2;

            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.18,
              children: [
                _StatCard(
                  icon: Icons.repeat_outlined,
                  label: 'Total ports',
                  value: '${garment.wearCount}',
                  color: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                ),
                _StatCard(
                  icon: Icons.event_available_outlined,
                  label: 'Premier port',
                  value: firstWearLabel,
                  color: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.onSecondaryContainer,
                ),
                _StatCard(
                  icon: Icons.history_outlined,
                  label: 'Dernier port',
                  value:
                      garment.lastWorn == null
                          ? 'Jamais porté'
                          : formatDate(garment.lastWorn!),
                  color: colorScheme.tertiaryContainer,
                  foregroundColor: colorScheme.onTertiaryContainer,
                ),
                _StatCard(
                  icon: Icons.today_outlined,
                  label: 'Depuis dernier port',
                  value: daysSinceLastWearLabel(garment.lastWorn),
                  color: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                _StatCard(
                  icon: Icons.calculate_outlined,
                  label: 'Coût par port',
                  value: costPerWear,
                  color: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                _StatCard(
                  icon: Icons.hourglass_bottom_outlined,
                  label: 'Ancienneté dressing',
                  value: formatCalendarAge(ageStart),
                  color: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color foregroundColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foregroundColor, size: 22),
            const Spacer(),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foregroundColor.withValues(alpha: .78),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 21),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WearHistoryCard extends StatelessWidget {
  final Future<List<WearHistory>> wearHistoryFuture;
  final String Function(DateTime date) formatDate;
  final String Function(DateTime date) formatTime;
  final ValueChanged<WearHistory> onDelete;

  const _WearHistoryCard({
    required this.wearHistoryFuture,
    required this.formatDate,
    required this.formatTime,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<List<WearHistory>>(
        future: wearHistoryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(17),
              child: Text('Impossible de charger l’historique des ports.'),
            );
          }

          final history = snapshot.data ?? const <WearHistory>[];
          if (history.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(17),
              child: Text('Aucun port enregistré pour ce vêtement.'),
            );
          }

          return Column(
            children: [
              for (var index = 0; index < history.length; index++) ...[
                _WearHistoryTile(
                  wear: history[index],
                  formatDate: formatDate,
                  formatTime: formatTime,
                  onDelete: onDelete,
                ),
                if (index < history.length - 1) const Divider(height: 1),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WearHistoryTile extends StatelessWidget {
  final WearHistory wear;
  final String Function(DateTime date) formatDate;
  final String Function(DateTime date) formatTime;
  final ValueChanged<WearHistory> onDelete;

  const _WearHistoryTile({
    required this.wear,
    required this.formatDate,
    required this.formatTime,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.event_available_outlined),
      title: Text(formatDate(wear.wornAt)),
      subtitle: Text(formatTime(wear.wornAt)),
      trailing: IconButton(
        tooltip: 'Supprimer ce port',
        onPressed: () => onDelete(wear),
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}
