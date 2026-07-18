import 'package:flutter/material.dart';

import '../../models/garment.dart';
import '../../widgets/garment_image.dart';
import 'garment_form_screen.dart';
import 'wardrobe_controller.dart';

class GarmentDetailScreen extends StatefulWidget {
  final WardrobeController controller;
  final Garment garment;

  const GarmentDetailScreen({
    super.key,
    required this.controller,
    required this.garment,
  });

  @override
  State<GarmentDetailScreen> createState() => _GarmentDetailScreenState();
}

class _GarmentDetailScreenState extends State<GarmentDetailScreen> {
  late Garment garment;

  @override
  void initState() {
    super.initState();
    garment = widget.garment;
  }

  Future<void> edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GarmentFormScreen(
          controller: widget.controller,
          garment: garment,
        ),
      ),
    );
    if (changed == true) _refreshGarment();
  }

  void _refreshGarment() {
    final match = widget.controller.garments.where((item) => item.id == garment.id);
    if (match.isNotEmpty && mounted) {
      setState(() => garment = match.first);
    }
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> toggleFavorite() async {
    await widget.controller.toggleFavorite(garment);
    _refreshGarment();
  }

  @override
  Widget build(BuildContext context) {
    final identityChips = [
      garment.category,
      garment.color,
      garment.material,
      garment.season,
      garment.style,
      garment.occasion,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();

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
              if (value == 'delete') remove();
            },
            itemBuilder: (_) => const [
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
          Hero(
            tag: 'garment-${garment.id}',
            child: GarmentImage(
              imagePath: garment.imagePath,
              width: double.infinity,
              height: 390,
              borderRadius: BorderRadius.circular(32),
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
                tooltip: garment.isFavorite
                    ? 'Retirer des favoris'
                    : 'Ajouter aux favoris',
                onPressed: toggleFavorite,
                icon: Icon(
                  garment.isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
              ),
            ],
          ),
          if (identityChips.isNotEmpty) ...[
            const SizedBox(height: 17),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: identityChips
                  .map((value) => Chip(label: Text(value)))
                  .toList(),
            ),
          ],
          const SizedBox(height: 26),
          const _SectionTitle('Informations'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.checkroom_outlined,
                  label: 'Catégorie',
                  value: garment.category,
                ),
                if (_hasText(garment.size))
                  _InfoTile(
                    icon: Icons.straighten_outlined,
                    label: 'Taille',
                    value: garment.size!,
                  ),
                if (_hasText(garment.fit))
                  _InfoTile(
                    icon: Icons.accessibility_new_outlined,
                    label: 'Coupe',
                    value: garment.fit!,
                  ),
                if (_hasText(garment.composition))
                  _InfoTile(
                    icon: Icons.science_outlined,
                    label: 'Composition',
                    value: garment.composition!,
                    multiline: true,
                  ),
                if (_hasText(garment.condition))
                  _InfoTile(
                    icon: Icons.verified_outlined,
                    label: 'État',
                    value: garment.condition!,
                  ),
              ],
            ),
          ),
          if (garment.purchasePrice != null || garment.purchaseDate != null) ...[
            const SizedBox(height: 24),
            const _SectionTitle('Achat'),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  if (garment.purchasePrice != null)
                    _InfoTile(
                      icon: Icons.euro_outlined,
                      label: "Prix d'achat",
                      value: _formatPrice(garment.purchasePrice!),
                    ),
                  if (garment.purchaseDate != null)
                    _InfoTile(
                      icon: Icons.calendar_month_outlined,
                      label: "Date d'achat",
                      value: _formatDate(garment.purchaseDate!),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const _SectionTitle('Utilisation'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.repeat_outlined,
                  label: 'Nombre de ports',
                  value: '${garment.wearCount}',
                ),
                _InfoTile(
                  icon: Icons.history_outlined,
                  label: 'Dernier port',
                  value: garment.lastWorn == null
                      ? 'Jamais renseigné'
                      : _formatDate(garment.lastWorn!),
                ),
                if (garment.purchasePrice != null && garment.wearCount > 0)
                  _InfoTile(
                    icon: Icons.calculate_outlined,
                    label: 'Coût par port',
                    value: _formatPrice(
                      garment.purchasePrice! / garment.wearCount,
                    ),
                  ),
              ],
            ),
          ),
          if (_hasText(garment.notes)) ...[
            const SizedBox(height: 24),
            const _SectionTitle('Notes'),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(garment.notes!),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: edit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier cette pièce'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "L'enregistrement d'un port arrive à l'étape suivante.",
                  ),
                ),
              );
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text("Je l'ai portée aujourd'hui"),
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

  static bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String _formatPrice(double value) {
    final decimals = value % 1 == 0 ? 0 : 2;
    return '${value.toStringAsFixed(decimals).replaceAll('.', ',')} €';
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
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
