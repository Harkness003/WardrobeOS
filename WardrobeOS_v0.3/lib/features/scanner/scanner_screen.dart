import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../data/image_storage_service.dart';
import '../../models/garment.dart';
import '../../widgets/garment_image.dart';
import '../wardrobe/wardrobe_controller.dart';
import 'garment_scan_result.dart';
import 'garment_scanner_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final picker = ImagePicker();
  final scanner = GarmentScannerService();
  final wardrobe = WardrobeController();

  final name = TextEditingController();
  final brand = TextEditingController();
  final color = TextEditingController();
  final material = TextEditingController();

  String category = 'Hauts';
  String season = 'Toute saison';
  String? imagePath;
  GarmentScanResult? result;
  bool analyzing = false;
  bool saving = false;

  static const categories = [
    'Hauts',
    'Chemises',
    'Vestes',
    'Bas',
    'Chaussures',
    'Accessoires',
    'Autre',
  ];

  static const seasons = [
    'Toute saison',
    'Printemps',
    'Été',
    'Automne',
    'Hiver',
  ];

  @override
  void dispose() {
    name.dispose();
    brand.dispose();
    color.dispose();
    material.dispose();
    wardrobe.dispose();
    super.dispose();
  }

  Future<void> pick(ImageSource source) async {
    final selected = await picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1800,
    );
    if (selected == null) return;

    final persisted = await ImageStorageService.persist(selected.path);
    if (imagePath != null) await ImageStorageService.remove(imagePath);

    setState(() {
      imagePath = persisted;
      result = null;
    });
    await analyze();
  }

  Future<void> chooseSource() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Prendre une photo'),
              subtitle: const Text('Idéalement sur un fond uni'),
              onTap: () {
                Navigator.pop(context);
                pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.pop(context);
                pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> analyze() async {
    if (imagePath == null) return;
    setState(() => analyzing = true);

    try {
      final scan = await scanner.analyze(imagePath!);
      if (!mounted) return;
      setState(() {
        result = scan;
        name.text = scan.suggestedName;
        category = scan.category;
        color.text = scan.color;
        material.text = scan.material;
        season = scan.season;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Analyse impossible. Tu peux compléter la fiche manuellement. ($error)',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => analyzing = false);
    }
  }

  Future<void> save() async {
    if (imagePath == null) {
      _toast('Ajoute d’abord une photo.');
      return;
    }
    if (name.text.trim().isEmpty) {
      _toast('Donne un nom à la pièce.');
      return;
    }

    setState(() => saving = true);
    final now = DateTime.now();
    final garment = Garment(
      id: const Uuid().v4(),
      name: name.text.trim(),
      category: category,
      brand: brand.text.trim().isEmpty ? null : brand.text.trim(),
      color: color.text.trim().isEmpty ? null : color.text.trim(),
      material: material.text.trim().isEmpty ? null : material.text.trim(),
      season: season,
      notes: result == null
          ? 'Ajout manuel depuis le scanner.'
          : 'Analyse locale bêta · confiance ${(result!.confidence * 100).round()} %.',
      imagePath: imagePath,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await wardrobe.save(garment, isNew: true);
      imagePath = null; // The saved garment now owns the image.
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pièce ajoutée au dressing.')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner une pièce'),
        actions: [
          IconButton(
            tooltip: 'Conseils photo',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(
                title: Text('Pour une meilleure analyse'),
                content: Text(
                  'Photographie une seule pièce, bien éclairée, à plat ou sur un cintre, avec un fond aussi neutre que possible.',
                ),
              ),
            ),
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
        children: [
          _PhotoArea(
            imagePath: imagePath,
            analyzing: analyzing,
            onTap: chooseSource,
          ),
          const SizedBox(height: 18),
          if (imagePath == null) ...[
            const _IntroCard(),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: chooseSource,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Prendre ou choisir une photo'),
            ),
          ] else ...[
            if (result != null) _AnalysisSummary(result: result!),
            if (result != null) const SizedBox(height: 14),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Nom de la pièce',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: brand,
              decoration: const InputDecoration(
                labelText: 'Marque (facultatif)',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: categories
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => category = value!),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: color,
              decoration: const InputDecoration(
                labelText: 'Couleur',
                prefixIcon: Icon(Icons.palette_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: material,
              decoration: const InputDecoration(
                labelText: 'Matière',
                prefixIcon: Icon(Icons.texture_outlined),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: season,
              decoration: const InputDecoration(
                labelText: 'Saison',
                prefixIcon: Icon(Icons.calendar_month_outlined),
              ),
              items: seasons
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => season = value!),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: analyzing ? null : analyze,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réanalyser'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: chooseSource,
                    icon: const Icon(Icons.photo_camera_back_outlined),
                    label: const Text('Changer'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: saving || analyzing ? null : save,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                saving ? 'Ajout en cours…' : 'Valider et ajouter au dressing',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoArea extends StatelessWidget {
  final String? imagePath;
  final bool analyzing;
  final VoidCallback onTap;

  const _PhotoArea({
    required this.imagePath,
    required this.analyzing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: analyzing ? null : onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GarmentImage(
            imagePath: imagePath,
            width: double.infinity,
            height: 330,
            borderRadius: BorderRadius.circular(32),
          ),
          if (imagePath == null)
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.document_scanner_outlined,
                  size: 65,
                  color: AppTheme.gold,
                ),
                SizedBox(height: 12),
                Text(
                  'Appuie pour ajouter une photo',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          if (analyzing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .58),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppTheme.gold),
                    SizedBox(height: 18),
                    Text(
                      'Analyse locale en cours…',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Catégorie · couleur · matière · saison',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(19),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: AppTheme.gold),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Scanner intelligent — bêta',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'L’analyse s’effectue directement sur ton téléphone. Elle propose une catégorie, une couleur, une matière et une saison, puis te laisse tout corriger avant l’enregistrement.',
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisSummary extends StatelessWidget {
  final GarmentScanResult result;
  const _AnalysisSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    final confidence = (result.confidence * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.gold),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Suggestion générée',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Chip(label: Text('$confidence %')),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: result.confidence,
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
              color: AppTheme.gold,
            ),
            if (result.labels.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Indices détectés : ${result.labels.take(4).join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Vérifie les informations : l’analyse peut se tromper.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
