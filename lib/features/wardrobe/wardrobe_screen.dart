import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/garment.dart';
import '../../widgets/garment_image.dart';
import '../../widgets/app_feedback.dart';
import '../scanner/scanner_screen.dart';
import '../scanner/wardrobe_import_screen.dart';
import 'garment_detail_screen.dart';
import 'garment_form_screen.dart';
import 'wardrobe_controller.dart';
import 'wardrobe_selection.dart';
import 'reanalysis/garment_reanalysis_service.dart';

class WardrobeScreen extends StatefulWidget {
  final GarmentReanalysisService reanalysisService;
  const WardrobeScreen({super.key, required this.reanalysisService});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final controller = WardrobeController();
  final searchController = TextEditingController();
  final scrollController = ScrollController();
  final selection = WardrobeSelection();

  static const seasons = [
    'Printemps',
    'Été',
    'Automne',
    'Hiver',
    'Toute saison',
  ];

  final categories = const [
    'Tout',
    'Hauts',
    'Chemises',
    'Vestes',
    'Bas',
    'Chaussures',
    'Accessoires',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    controller.addListener(_refresh);
    controller.load();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    controller.dispose();
    searchController.dispose();
    scrollController.dispose();
    selection.dispose();
    super.dispose();
  }

  void _onGarmentTap(Garment garment) {
    if (selection.isActive) {
      selection.toggle(garment.id);
    } else {
      _openDetail(garment);
    }
  }

  Future<void> _runSelectionAction(SelectionAction action) async {
    switch (action) {
      case SelectionAction.delete:
        await _deleteSelection();
    }
  }

  Future<void> _deleteSelection() async {
    final selected = controller.garments
        .where((garment) => selection.contains(garment.id))
        .toList(growable: false);
    if (selected.isEmpty) {
      selection.clear();
      return;
    }

    final count = selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Supprimer $count vêtements ?'),
        content: const Text('Cette action est irréversible. Les vêtements et leurs photos locales seront supprimés définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      for (final garment in selected) {
        await controller.delete(garment, refresh: false);
      }
      selection.clear();
      await controller.load();
    } catch (_) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        'Certains vêtements n’ont pas pu être supprimés. Vérifie le dressing puis réessaie.',
      );
      await controller.load();
    }
  }

  Future<void> _showAddOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                    title: Text(
                      'Ajouter une pièce',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Text('Choisis la méthode la plus rapide.'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.document_scanner_outlined),
                    title: const Text('Ajouter un vêtement'),
                    subtitle: const Text(
                      'Photo et pré-remplissage automatique',
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final added = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScannerScreen(),
                        ),
                      );
                      if (added == true) await controller.load();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.collections_outlined),
                    title: const Text('Importer mon dressing'),
                    subtitle: const Text('Photographier plusieurs vêtements sans attendre'),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await Navigator.push<void>(context, MaterialPageRoute(
                        builder: (_) => const WardrobeImportScreen()));
                      await controller.load();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_note_outlined),
                    title: const Text('Ajout manuel'),
                    subtitle: const Text('Remplir directement la fiche'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openForm();
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _openForm([Garment? garment]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => GarmentFormScreen(controller: controller, garment: garment),
      ),
    );
  }

  Future<void> _openDetail(Garment garment) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                GarmentDetailScreen(controller: controller, garment: garment, reanalysisService: widget.reanalysisService),
      ),
    );
  }

  Future<void> _showAdvancedFilters() async {
    String selectedSeason = controller.season;
    final brand = TextEditingController(text: controller.brand);
    final color = TextEditingController(text: controller.color);
    final material = TextEditingController(text: controller.material);
    final style = TextEditingController(text: controller.style);
    final occasion = TextEditingController(text: controller.occasion);

    final action = await showModalBottomSheet<_FilterAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (context, setSheetState) => AnimatedPadding(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Filtres avancés',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue:
                              selectedSeason.isEmpty ? null : selectedSeason,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Saison',
                          ),
                          hint: const Text('Toutes les saisons'),
                          items:
                              seasons
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (value) => setSheetState(
                                () => selectedSeason = value ?? '',
                              ),
                        ),
                        const SizedBox(height: 12),
                        _FilterTextField(controller: brand, label: 'Marque'),
                        const SizedBox(height: 12),
                        _FilterTextField(controller: color, label: 'Couleur'),
                        const SizedBox(height: 12),
                        _FilterTextField(
                          controller: material,
                          label: 'Matière',
                        ),
                        const SizedBox(height: 12),
                        _FilterTextField(controller: style, label: 'Style'),
                        const SizedBox(height: 12),
                        _FilterTextField(
                          controller: occasion,
                          label: 'Occasion',
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed:
                              () => Navigator.pop(
                                sheetContext,
                                _FilterAction.apply,
                              ),
                          child: const Text('Appliquer'),
                        ),
                        TextButton(
                          onPressed:
                              () => Navigator.pop(
                                sheetContext,
                                _FilterAction.reset,
                              ),
                          child: const Text('Réinitialiser les filtres'),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );

    if (action == _FilterAction.apply) {
      await controller.applyAdvancedFilters(
        season: selectedSeason,
        brand: brand.text,
        color: color.text,
        material: material.text,
        style: style.text,
        occasion: occasion.text,
      );
    } else if (action == _FilterAction.reset) {
      await controller.resetAdvancedFilters();
    }
    brand.dispose();
    color.dispose();
    material.dispose();
    style.dispose();
    occasion.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !selection.isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selection.isActive) selection.clear();
      },
      child: Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: ValueListenableBuilder<Set<String>>(
        valueListenable: selection,
        builder: (_, selected, __) => selected.isEmpty
            ? FloatingActionButton.extended(
                onPressed: _showAddOptions,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              )
            : const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder<Set<String>>(
              valueListenable: selection,
              builder: (_, selected, __) => selected.isEmpty
                  ? _normalHeader()
                  : _selectionHeader(selected.length),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: TextField(
                controller: searchController,
                onChanged: controller.setSearch,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Nom, marque ou couleur',
                  suffixIcon: IconButton(
                    tooltip: 'Filtres avancés',
                    onPressed: _showAdvancedFilters,
                    icon: Badge(
                      isLabelVisible: controller.advancedFilterCount > 0,
                      label: Text('${controller.advancedFilterCount}'),
                      child: const Icon(Icons.tune),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, index) {
                  final item = categories[index];
                  return ChoiceChip(
                    label: Text(item),
                    selected: controller.category == item,
                    onSelected: (_) => controller.setCategory(item),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: categories.length,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(child: _body()),
          ],
        ),
      ),
      ),
    );
  }

  Widget _normalHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
        child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mon dressing',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${controller.garments.length} pièce${controller.garments.length > 1 ? 's' : ''} affichée${controller.garments.length > 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Favoris uniquement',
                    onPressed: controller.toggleFavoritesFilter,
                    icon: Icon(
                      controller.favoritesOnly
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
                  ),
                ],
              ),
            );

  Widget _selectionHeader(int count) => Semantics(
        liveRegion: true,
        label: '$count vêtement${count > 1 ? 's' : ''} sélectionné${count > 1 ? 's' : ''}',
        child: SizedBox(
          height: 56,
          child: Row(children: [
            IconButton(
              tooltip: 'Quitter la sélection',
              onPressed: selection.clear,
              icon: const Icon(Icons.close),
            ),
            Expanded(child: Text(
              '$count sélectionné${count > 1 ? 's' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            )),
            IconButton.filledTonal(
              tooltip: 'Supprimer la sélection',
              onPressed: () => _runSelectionAction(SelectionAction.delete),
              icon: const Icon(Icons.delete_outline),
            ),
            PopupMenuButton<String>(
              tooltip: 'Plus d’actions',
              onSelected: (value) {
                if (value == 'all') {
                  selection.selectAll(controller.garments.map((garment) => garment.id));
                } else {
                  selection.clear();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'all', child: Text('Tout sélectionner')),
                PopupMenuItem(value: 'clear', child: Text('Tout désélectionner')),
              ],
            ),
          ]),
        ),
      );

  Widget _body() {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.garments.isEmpty) {
      final noSearch =
          controller.search.isEmpty &&
          controller.category == 'Tout' &&
          !controller.favoritesOnly &&
          controller.advancedFilterCount == 0;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.checkroom_outlined,
                  size: 48,
                  color: AppTheme.gold,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                noSearch ? 'Ton dressing est vide' : 'Aucune pièce trouvée',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                noSearch
                    ? 'Ajoute ta première pièce pour commencer à construire ton dressing intelligent.'
                    : 'Essaie une autre recherche ou modifie les filtres.',
                textAlign: TextAlign.center,
              ),
              if (noSearch) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: 230,
                  child: FilledButton.icon(
                    onPressed: _showAddOptions,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une pièce'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: GridView.builder(
          controller: scrollController,
          key: ValueKey(
            '${controller.category}-${controller.search}-${controller.favoritesOnly}-${controller.season}-${controller.brand}-${controller.color}-${controller.material}-${controller.style}-${controller.occasion}',
          ),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
          itemCount: controller.garments.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: .68,
            crossAxisSpacing: 13,
            mainAxisSpacing: 13,
          ),
          itemBuilder: (_, index) {
            final garment = controller.garments[index];
            return ValueListenableBuilder<Set<String>>(
              valueListenable: selection,
              child: _GarmentCardContent(
                garment: garment,
                onFavorite: () => selection.isActive
                    ? selection.toggle(garment.id)
                    : controller.toggleFavorite(garment),
              ),
              builder: (_, selected, child) => _GarmentCard(
                garment: garment,
                selected: selected.contains(garment.id),
                selectionActive: selected.isNotEmpty,
                onTap: () => _onGarmentTap(garment),
                onLongPress: () => selection.select(garment.id),
                child: child!,
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _FilterAction { apply, reset }

class _FilterTextField extends StatelessWidget {
  const _FilterTextField({
    required this.controller,
    required this.label,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    textInputAction: textInputAction,
    decoration: InputDecoration(labelText: label),
  );
}

class _GarmentCard extends StatelessWidget {
  final Garment garment;
  final bool selected;
  final bool selectionActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget child;

  const _GarmentCard({
    required this.garment,
    required this.selected,
    required this.selectionActive,
    required this.onTap,
    required this.onLongPress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      label: '${garment.name}, ${selected ? 'sélectionné' : 'non sélectionné'}',
      onLongPress: onLongPress,
      child: Hero(
        tag: 'garment-${garment.id}',
        child: Material(
          color: Colors.transparent,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: selected
                  ? const BorderSide(color: AppTheme.gold, width: 3)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  if (selectionActive)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Material(
                        color: selected ? AppTheme.gold : Colors.black54,
                        shape: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(
                            selected ? Icons.check : Icons.circle_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GarmentCardContent extends StatelessWidget {
  const _GarmentCardContent({required this.garment, required this.onFavorite});

  final Garment garment;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GarmentImage(
                        imagePath: (garment.effectivePhotos.isEmpty ? null : garment.effectivePhotos.first.path),
                        borderRadius: BorderRadius.zero,
                      ),
                      Positioned(
                        top: 9,
                        right: 9,
                        child: IconButton.filledTonal(
                          onPressed: onFavorite,
                          icon: Icon(
                            garment.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 19,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            garment.category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        garment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          garment.brand,
                          garment.color,
                        ].where((e) => e != null && e.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            );
}
