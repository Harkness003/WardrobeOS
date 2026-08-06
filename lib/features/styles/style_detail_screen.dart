import 'package:flutter/material.dart';
import 'style_repository.dart';
import '../../l10n/app_localizations.dart';

class StyleDetailScreen extends StatelessWidget {
  final LibraryStyle style;
  final StyleRepository repository;
  const StyleDetailScreen({super.key, required this.style, required this.repository});
  @override Widget build(BuildContext context) {
    final visibleStyle = style.localized(AppLocalizations.of(context));
    return Scaffold(
    appBar: AppBar(title: Text(visibleStyle.name)),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Chip(label: Text(AppLocalizations.of(context).text(visibleStyle.isSystem ? 'ui.systemStyle' : 'ui.personalStyle'))),
      const SizedBox(height: 12), Text(visibleStyle.definition, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12), Text(visibleStyle.description),
      _Section(AppLocalizations.of(context).text('ui.characteristics'), visibleStyle.characteristics),
      _Section(AppLocalizations.of(context).text('ui.associatedColors'), visibleStyle.colors),
      _Section(AppLocalizations.of(context).text('ui.frequentMaterials'), visibleStyle.materials),
      _Section(AppLocalizations.of(context).text('ui.occasions'), visibleStyle.occasions),
      _Section(AppLocalizations.of(context).text('ui.typicalPieces'), visibleStyle.typicalPieces),
      _Relations(title: AppLocalizations.of(context).text('ui.relatedStyles'), ids: visibleStyle.relatedStyleIds, repository: repository),
      _Relations(title: AppLocalizations.of(context).text('ui.oppositeStyles'), ids: visibleStyle.oppositeStyleIds, repository: repository),
    ]));
  }
}
class _Section extends StatelessWidget {
  final String title; final List<String> values;
  const _Section(this.title, this.values);
  @override Widget build(BuildContext context) => values.isEmpty ? const SizedBox.shrink() : Padding(
    padding: const EdgeInsets.only(top: 22), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: values.map((e) => Chip(label: Text(e))).toList())]));
}
class _Relations extends StatelessWidget {
  final String title; final List<String> ids; final StyleRepository repository;
  const _Relations({required this.title, required this.ids, required this.repository});
  @override Widget build(BuildContext context) => ids.isEmpty ? const SizedBox.shrink() : FutureBuilder<List<LibraryStyle?>>(
    future: Future.wait(ids.map(repository.find)), builder: (_, snapshot) => _Section(title,
      snapshot.data?.whereType<LibraryStyle>().map((e) => e.localized(AppLocalizations.of(context)).name).toList() ?? const []));
}
