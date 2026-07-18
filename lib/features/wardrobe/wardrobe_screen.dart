import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/garment.dart';
import '../../widgets/garment_image.dart';
import '../scanner/scanner_screen.dart';
import 'garment_detail_screen.dart';
import 'garment_form_screen.dart';
import 'wardrobe_controller.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final controller = WardrobeController();
  final searchController = TextEditingController();

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
    super.dispose();
  }

  Future<void> _showAddOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Ajouter une pièce',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                subtitle: Text('Choisis la méthode la plus rapide.'),
              ),
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: const Text('Scanner un vêtement'),
                subtitle: const Text('Photo et pré-remplissage automatique'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final added = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const ScannerScreen()),
                  );
                  if (added == true) await controller.load();
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
        builder: (_) => GarmentFormScreen(
          controller: controller,
          garment: garment,
        ),
      ),
    );
  }

  Future<void> _openDetail(Garment garment) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GarmentDetailScreen(
          controller: controller,
          garment: garment,
        ),
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
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => AnimatedPadding(
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue:
                      selectedSeason.isEmpty ? null : selectedSeason,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Saison'),
                  hint: const Text('Toutes les saisons'),
                  items: seasons
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (value) => setSheetState(
                    () => selectedSeason = value ?? '',
                  ),
                ),
                const SizedBox(height: 12),
                _FilterTextField(controller: brand, label: 'Marque'),
                const SizedBox(height: 12),
                _FilterTextField(controller: color, label: 'Couleur'),
                const SizedBox(height: 12),
                _FilterTextField(controller: material, label: 'Matière'),
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
                  onPressed: () => Navigator.pop(
                    sheetContext,
                    _FilterAction.apply,
                  ),
                  child: const Text('Appliquer'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
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
    );
  }

  Widget _body() {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.garments.isEmpty) {
      final noSearch = controller.search.isEmpty &&
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
            return _GarmentCard(
              garment: garment,
              onTap: () => _openDetail(garment),
              onFavorite: () => controller.toggleFavorite(garment),
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
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _GarmentCard({
    required this.garment,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'garment-${garment.id}',
      child: Material(
        color: Colors.transparent,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GarmentImage(
                        imagePath: garment.imagePath,
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
            ),
          ),
        ),
      ),
    );
  }
}
