import 'package:flutter/material.dart';
import 'style_repository.dart';

class StyleDetailScreen extends StatelessWidget {
  final LibraryStyle style;
  final StyleRepository repository;
  const StyleDetailScreen({super.key, required this.style, required this.repository});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(style.name)),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Chip(label: Text(style.isSystem ? 'Style système' : 'Style personnel')),
      const SizedBox(height: 12), Text(style.definition, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12), Text(style.description),
      _Section('Caractéristiques', style.characteristics),
      _Section('Couleurs associées', style.colors),
      _Section('Matières fréquentes', style.materials),
      _Section('Occasions adaptées', style.occasions),
      _Section('Pièces typiques', style.typicalPieces),
      _Relations(title: 'Styles proches', ids: style.relatedStyleIds, repository: repository),
      _Relations(title: 'Styles opposés', ids: style.oppositeStyleIds, repository: repository),
    ]));
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
      snapshot.data?.whereType<LibraryStyle>().map((e) => e.name).toList() ?? const []));
}
