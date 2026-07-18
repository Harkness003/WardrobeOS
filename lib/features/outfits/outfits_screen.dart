import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/outfit.dart';
import '../../widgets/garment_image.dart';
import 'outfit_form_screen.dart';
import 'outfits_controller.dart';

class OutfitsScreen extends StatefulWidget {
  const OutfitsScreen({super.key});

  @override
  State<OutfitsScreen> createState() => _OutfitsScreenState();
}

class _OutfitsScreenState extends State<OutfitsScreen> {
  final controller = OutfitsController();
  final Set<String> _recordingOutfitIds = {};

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
    super.dispose();
  }

  Future<void> _open([Outfit? outfit]) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OutfitFormScreen(controller: controller, outfit: outfit),
      ),
    );
  }

  Future<void> _recordWear(Outfit outfit) async {
    if (_recordingOutfitIds.contains(outfit.id)) return;
    setState(() => _recordingOutfitIds.add(outfit.id));
    try {
      final recorded = await controller.recordWear(outfit);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            recorded
                ? 'Tenue enregistrée avec succès.'
                : "Impossible d'enregistrer cette tenue.",
          ),
        ),
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
      if (mounted) setState(() => _recordingOutfitIds.remove(outfit.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        icon: const Icon(Icons.add),
        label: const Text('Créer'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mes tenues',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${controller.outfits.length} tenue${controller.outfits.length > 1 ? 's' : ''}',
                  ),
                ],
              ),
            ),
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
    if (controller.error != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: controller.load,
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
        ),
      );
    }
    if (controller.outfits.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.style_outlined, size: 64, color: AppTheme.gold),
              SizedBox(height: 16),
              Text(
                'Aucune tenue enregistrée',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 7),
              Text(
                'Regroupe les pièces de ton dressing pour créer une tenue.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
        children: [
          const Text(
            'Suggestions du jour',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...controller.suggestions.map(_suggestionCard),
          const SizedBox(height: 14),
          const Text(
            'Toutes les tenues',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...controller.outfits.map(_outfitCard),
        ],
      ),
    );
  }

  Widget _suggestionCard(Outfit outfit) {
    final garments = controller.garmentsByOutfit[outfit.id] ?? [];
    final recording = _recordingOutfitIds.contains(outfit.id);
    final lastWornLabel = outfit.lastWorn == null
        ? '🔥 Jamais portée'
        : 'Portée il y a ${OutfitsController.suggestionScore(outfit)} jours';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _open(outfit),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _ThumbnailGrid(paths: garments.map((g) => g.imagePath).toList()),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outfit.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${garments.length} vêtement${garments.length > 1 ? 's' : ''}',
                    ),
                    const SizedBox(height: 3),
                    Text(lastWornLabel),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: recording ? null : () => _recordWear(outfit),
                child: recording
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Porter'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _outfitCard(Outfit outfit) {
    final garments = controller.garmentsByOutfit[outfit.id] ?? [];
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _open(outfit),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _ThumbnailGrid(paths: garments.map((g) => g.imagePath).toList()),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            outfit.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (outfit.favorite)
                          const Icon(
                            Icons.favorite,
                            color: AppTheme.gold,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${garments.length} vêtement${garments.length > 1 ? 's' : ''}',
                    ),
                    const SizedBox(height: 3),
                    Text('Portée ${outfit.timesWorn} fois'),
                    Text(
                      outfit.lastWorn == null
                          ? 'Jamais portée'
                          : 'Dernière fois : ${_date(outfit.lastWorn!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  static String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _ThumbnailGrid extends StatelessWidget {
  final List<String?> paths;

  const _ThumbnailGrid({required this.paths});

  @override
  Widget build(BuildContext context) {
    final visible = paths.take(4).toList();
    return SizedBox(
      width: 84,
      height: 84,
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        children: List.generate(
          4,
          (index) => GarmentImage(
            imagePath: index < visible.length ? visible[index] : null,
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ),
    );
  }
}
