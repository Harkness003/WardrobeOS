import 'package:flutter/material.dart';

import '../../models/garment.dart';
import '../../models/wear_history.dart';
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
  bool _recordingWear = false;
  late Future<List<WearHistory>> _wearHistoryFuture;

  @override
  void initState() {
    super.initState();
    garment = widget.garment;
    _wearHistoryFuture = _loadWearHistory();
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

  Future<List<WearHistory>> _loadWearHistory() {
    return widget.controller.getWearHistory(garment.id);
  }

  void _refreshGarment({bool reloadHistory = false}) {
    final match = widget.controller.garments.where(
      (item) => item.id == garment.id,
    );
    if (!mounted) return;

    setState(() {
      if (match.isNotEmpty) garment = match.first;
      if (reloadHistory) _wearHistoryFuture = _loadWearHistory();
    });
  }

  Future<void> recordWear() async {
    if (_recordingWear) return;

    setState(() => _recordingWear = true);

    try {
      final wornAt = await _pickWearDate();
      if (wornAt == null) return;

      final wear = await widget.controller.recordWear(garment, wornAt: wornAt);
      _refreshGarment(reloadHistory: true);

      if (!mounted) return;
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
      if (!mounted) return;
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
      builder: (context) => SafeArea(
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

    if (!mounted || choice == null) return null;
    if (choice == _WearDateChoice.today) return DateTime.now();

    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    if (selectedDate == null) return null;

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

      if (!mounted || !removed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Port annulé.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d’annuler ce port."),
        ),
      );
    }
  }

  Future<void> deleteWear(WearHistory wear) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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

    if (confirmed != true) return;

    try {
      final removed = await widget.controller.deleteWear(garment, wear);
      _refreshGarment(reloadHistory: true);

      if (!mounted || !removed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Port supprimé.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de supprimer ce port.')),
      );
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
          const SizedBox(height: 24),
          const _SectionTitle('Historique des ports'),
          const SizedBox(height: 10),
          _WearHistoryCard(
            wearHistoryFuture: _wearHistoryFuture,
            formatDate: _formatDate,
            formatTime: _formatTime,
            onDelete: deleteWear,
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
            onPressed: _recordingWear ? null : recordWear,
            icon: _recordingWear
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _recordingWear
                  ? 'Enregistrement…'
                  : "Je l'ai portée aujourd'hui",
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

  static bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

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
}

enum _WearDateChoice { today, custom }

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
