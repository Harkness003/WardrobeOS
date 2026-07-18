import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/garment.dart';
import '../../models/outfit.dart';
import '../../widgets/garment_image.dart';
import '../wardrobe/wardrobe_controller.dart';
import 'outfits_controller.dart';

class OutfitFormScreen extends StatefulWidget {
  final OutfitsController controller;
  final Outfit? outfit;

  const OutfitFormScreen({super.key, required this.controller, this.outfit});

  @override
  State<OutfitFormScreen> createState() => _OutfitFormScreenState();
}

class _OutfitFormScreenState extends State<OutfitFormScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final Set<String> selectedIds;
  late final Map<String, Garment> selectedGarments;
  late final Set<String> originalIds;
  String? season;
  bool favorite = false;
  bool saving = false;
  bool recordingWear = false;
  Outfit? currentOutfit;

  static const seasons = [
    'Printemps',
    'Été',
    'Automne',
    'Hiver',
    'Toute saison',
  ];

  @override
  void initState() {
    super.initState();
    final outfit = widget.outfit;
    currentOutfit = outfit;
    nameController = TextEditingController(text: outfit?.name);
    season = outfit?.season;
    favorite = outfit?.favorite ?? false;
    originalIds =
        widget.controller.garmentsByOutfit[outfit?.id]
            ?.map((garment) => garment.id)
            .toSet() ??
        {};
    selectedIds = {...originalIds};
    selectedGarments = {
      for (final garment
          in widget.controller.garmentsByOutfit[outfit?.id] ?? <Garment>[])
        garment.id: garment,
    };
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _chooseGarments() async {
    final result = await Navigator.push<List<Garment>>(
      context,
      MaterialPageRoute(
        builder:
            (_) => GarmentSelectionScreen(
              initialGarments: selectedGarments.values.toList(),
            ),
      ),
    );
    if (result != null) {
      setState(() {
        selectedGarments
          ..clear()
          ..addEntries(result.map((garment) => MapEntry(garment.id, garment)));
        selectedIds
          ..clear()
          ..addAll(selectedGarments.keys);
      });
    }
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate() || saving) return;
    setState(() => saving = true);
    try {
      final now = DateTime.now();
      final existing = currentOutfit;
      if (existing == null) {
        await widget.controller.create(
          Outfit(
            id: const Uuid().v4(),
            name: nameController.text.trim(),
            season: season,
            favorite: favorite,
            createdAt: now,
            updatedAt: now,
          ),
          selectedIds,
        );
      } else {
        await widget.controller.update(
          existing.copyWith(
            name: nameController.text.trim(),
            season: season,
            favorite: favorite,
            updatedAt: now,
          ),
          originalIds,
          selectedIds,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _delete() async {
    final outfit = currentOutfit;
    if (outfit == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Supprimer cette tenue ?'),
            content: Text('« ${outfit.name} » sera supprimée définitivement.'),
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
      await widget.controller.delete(outfit);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _recordWear() async {
    final outfit = currentOutfit;
    if (outfit == null || selectedIds.isEmpty || recordingWear) return;
    setState(() => recordingWear = true);
    try {
      final recorded = await widget.controller.recordWear(outfit);
      if (!mounted) return;
      if (!recorded) {
        setState(() {
          selectedIds.clear();
          selectedGarments.clear();
        });
        return;
      }
      final refreshedOutfits = widget.controller.outfits.where(
        (candidate) => candidate.id == outfit.id,
      );
      currentOutfit = refreshedOutfits.isEmpty ? null : refreshedOutfits.first;
      final refreshedGarments =
          widget.controller.garmentsByOutfit[outfit.id] ?? <Garment>[];
      setState(() {
        selectedGarments
          ..clear()
          ..addEntries(
            refreshedGarments.map((item) => MapEntry(item.id, item)),
          );
        selectedIds
          ..clear()
          ..addAll(selectedGarments.keys);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenue enregistrée avec succès.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible d'enregistrer cette tenue."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => recordingWear = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final knownGarments = selectedGarments.values.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.outfit == null ? 'Créer une tenue' : 'Modifier la tenue',
        ),
        actions: [
          if (widget.outfit != null)
            IconButton(
              tooltip: 'Supprimer',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
          children: [
            if (currentOutfit != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Portée ${currentOutfit!.timesWorn} fois',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        currentOutfit!.lastWorn == null
                            ? 'Jamais portée'
                            : _formatDate(currentOutfit!.lastWorn!),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    selectedIds.isEmpty || recordingWear ? null : _recordWear,
                icon:
                    recordingWear
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.checkroom),
                label: const Text('Porter cette tenue'),
              ),
              const SizedBox(height: 18),
            ],
            TextFormField(
              controller: nameController,
              autofocus: widget.outfit == null,
              decoration: const InputDecoration(
                labelText: 'Nom de la tenue',
                prefixIcon: Icon(Icons.style_outlined),
              ),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Donne un nom à cette tenue.'
                          : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: season,
              decoration: const InputDecoration(
                labelText: 'Saison (facultatif)',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              items:
                  seasons
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => season = value),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              value: favorite,
              onChanged: (value) => setState(() => favorite = value),
              title: const Text('Tenue favorite'),
              secondary: Icon(
                favorite ? Icons.favorite : Icons.favorite_border,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Vêtements (${selectedIds.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _chooseGarments,
                  icon: const Icon(Icons.add),
                  label: const Text('Choisir'),
                ),
              ],
            ),
            if (selectedIds.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Text(
                    'Aucun vêtement sélectionné.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...knownGarments.map(
                (garment) => Card(
                  child: ListTile(
                    leading: GarmentImage(
                      imagePath: garment.imagePath,
                      width: 48,
                      height: 48,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(garment.name),
                    subtitle: Text(garment.category),
                    trailing: IconButton(
                      tooltip: 'Retirer',
                      onPressed:
                          () => setState(() {
                            selectedIds.remove(garment.id);
                            selectedGarments.remove(garment.id);
                          }),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: saving ? null : _save,
              icon:
                  saving
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.save_outlined),
              label: Text(
                widget.outfit == null ? 'Créer la tenue' : 'Enregistrer',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class GarmentSelectionScreen extends StatefulWidget {
  final List<Garment> initialGarments;

  const GarmentSelectionScreen({super.key, required this.initialGarments});

  @override
  State<GarmentSelectionScreen> createState() => _GarmentSelectionScreenState();
}

class _GarmentSelectionScreenState extends State<GarmentSelectionScreen> {
  final controller = WardrobeController();
  late final Map<String, Garment> selectedGarments;
  static const categories = [
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
    selectedGarments = {
      for (final garment in widget.initialGarments) garment.id: garment,
    };
    controller.addListener(_refresh);
    controller.load();
  }

  void _refresh() {
    for (final garment in controller.garments) {
      if (selectedGarments.containsKey(garment.id)) {
        selectedGarments[garment.id] = garment;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Choisir des vêtements'),
      actions: [
        TextButton(
          onPressed:
              () => Navigator.pop(context, selectedGarments.values.toList()),
          child: Text('Valider (${selectedGarments.length})'),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: controller.setSearch,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Nom, marque ou couleur',
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder:
                (_, index) => ChoiceChip(
                  label: Text(categories[index]),
                  selected: controller.category == categories[index],
                  onSelected: (_) => controller.setCategory(categories[index]),
                ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child:
              controller.loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                    itemCount: controller.garments.length,
                    itemBuilder: (_, index) {
                      final garment = controller.garments[index];
                      return CheckboxListTile(
                        value: selectedGarments.containsKey(garment.id),
                        onChanged:
                            (selected) => setState(() {
                              selected == true
                                  ? selectedGarments[garment.id] = garment
                                  : selectedGarments.remove(garment.id);
                            }),
                        secondary: GarmentImage(
                          imagePath: garment.imagePath,
                          width: 52,
                          height: 52,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(garment.name),
                        subtitle: Text(garment.category),
                      );
                    },
                  ),
        ),
      ],
    ),
  );
}
