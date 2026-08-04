import 'package:flutter/material.dart';
import 'style_detail_screen.dart';
import 'personal_style_form_screen.dart';
import 'style_repository.dart';
import 'style_enrichment_service.dart';
import '../../models/personal_style.dart';
import '../../widgets/content_state.dart';

class StyleLibraryScreen extends StatefulWidget {
  final StyleRepository repository;
  final StyleEnrichmentService? enrichment;
  const StyleLibraryScreen({super.key, required this.repository, this.enrichment});
  @override State<StyleLibraryScreen> createState() => _StyleLibraryScreenState();
}
class _StyleLibraryScreenState extends State<StyleLibraryScreen> {
  String query = '';
  late Future<List<LibraryStyle>> _styles;
  @override void initState() { super.initState(); _reload(); }
  void _reload() => _styles = widget.repository.all();
  void _refresh() => setState(_reload);
  Future<void> open(LibraryStyle style) async => Navigator.push(context,
    MaterialPageRoute(builder: (_) => StyleDetailScreen(style: style, repository: widget.repository)));
  Future<void> create() async { await Navigator.push(context, MaterialPageRoute(
    builder: (_) => PersonalStyleFormScreen(repository: widget.repository, enrichment: widget.enrichment))); _refresh(); }
  Future<void> edit(LibraryStyle style) async {
    final value = PersonalStyle(id: style.id, name: style.name,
      description: style.description, examples: style.examples,
      characteristics: style.characteristics, colors: style.colors,
      materials: style.materials, occasions: style.occasions,
      typicalPieces: style.typicalPieces);
    await Navigator.push(context, MaterialPageRoute(builder: (_) =>
      PersonalStyleFormScreen(repository: widget.repository, initial: value,
        enrichment: widget.enrichment)));
    _refresh();
  }
  Future<void> remove(LibraryStyle style) async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Supprimer ce style ?'), content: Text('« ${style.name} » sera supprimé définitivement.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer'))]));
    if (confirmed == true) { await widget.repository.delete(style.id); _refresh(); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bibliothèque des styles')),
    floatingActionButton: FloatingActionButton.extended(onPressed: create, icon: const Icon(Icons.add), label: const Text('Style personnel')),
    body: Column(children: [Padding(padding: const EdgeInsets.all(16), child: SearchBar(
      hintText: 'Nom, synonyme, définition…', leading: const Icon(Icons.search), onChanged: (v) => setState(() => query = v))),
      Expanded(child: FutureBuilder<List<LibraryStyle>>(future: _styles, builder: (_, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: ContentState.loading(
          title: 'Chargement des styles', message: 'Préparation du catalogue et de ses définitions…'));
        if (snapshot.hasError) return Center(child: ContentState.error(
          title: 'Catalogue indisponible', message: 'Les styles n’ont pas pu être chargés.', onAction: _refresh));
        final values = snapshot.data!.where((e) => StyleCatalog.matches(e, query)).toList();
        if (values.isEmpty) return Center(child: ContentState.empty(
          title: query.trim().isEmpty ? 'Bibliothèque vide' : 'Aucun style trouvé',
          message: query.trim().isEmpty ? 'Crée ton premier style personnel pour commencer.' : 'Essaie un autre nom, synonyme ou mot de la définition.',
          actionLabel: query.trim().isEmpty ? 'Créer un style' : 'Effacer la recherche',
          onAction: query.trim().isEmpty ? create : () => setState(() => query = '')));
        return ListView.builder(itemCount: values.length, itemBuilder: (_, index) { final style = values[index];
          return ListTile(key: Key('style-${style.id}'), title: Text(style.name), subtitle: Text(style.definition, maxLines: 2),
            leading: Icon(style.isSystem ? Icons.lock_outline : Icons.person_outline), onTap: () => open(style),
            trailing: style.isSystem ? null : PopupMenuButton<String>(onSelected: (action) async {
              if (action == 'edit') await edit(style);
              if (action == 'delete') await remove(style);
            }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(value: 'delete', child: Text('Supprimer'))])); });
      }))]));
}
