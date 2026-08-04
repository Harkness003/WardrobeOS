import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../data/image_storage_service.dart';
import '../../models/garment.dart';
import '../../models/garment_photo.dart';
import '../../models/thermal_profile_calculator.dart';
import '../../widgets/garment_image.dart';
import 'wardrobe_controller.dart';

/// Complete review sheet used both after AI analysis and when editing a garment.
class GarmentFormScreen extends StatefulWidget {
  final WardrobeController controller;
  final Garment? garment;
  /// A populated, not-yet-persisted garment produced by the scanner.
  final bool isDraft;
  const GarmentFormScreen({super.key, required this.controller, this.garment, this.isDraft = false});

  @override
  State<GarmentFormScreen> createState() => _GarmentFormScreenState();
}

class _GarmentFormScreenState extends State<GarmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _name, _brand, _color, _size, _otherMaterial,
      _otherUse, _otherCategory, _otherSubCategory, _composition,
      _minTemp, _maxTemp, _notes;
  late String _category;
  String? _subCategory, _material;
  late Set<String> _styles, _seasons, _uses;
  bool? _rain, _heat;
  String? _imagePath;
  bool _saving = false;

  static const categories = ['Hauts', 'Chemises', 'Vestes', 'Bas', 'Chaussures', 'Accessoires', 'Autre'];
  static const subCategories = <String, List<String>>{
    'Hauts': ['T-shirt', 'Polo', 'Pull', 'Sweat', 'Cardigan', 'Débardeur'],
    'Chemises': ['Chemise habillée', 'Chemise casual', 'Surchemise', 'Blouse'],
    'Vestes': ['Blazer', 'Manteau', 'Parka', 'Imperméable', 'Doudoune', 'Veste légère'],
    'Bas': ['Jean', 'Pantalon', 'Short', 'Jupe', 'Legging'],
    'Chaussures': ['Baskets', 'Boots', 'Chaussures habillées', 'Sandales', 'Randonnée'],
    'Accessoires': ['Sac', 'Ceinture', 'Écharpe', 'Bonnet', 'Chapeau', 'Gants'],
    'Autre': ['Autre'],
  };
  static const materials = ['Coton', 'Laine', 'Mérinos', 'Cachemire', 'Lin', 'Polyester', 'Viscose', 'Denim', 'Cuir', 'Daim', 'Nylon', 'Soie', 'Mélange', 'Autre...'];
  static const styles = ['Casual', 'Smart Casual', 'Business', 'Business Casual', 'Chic', 'Streetwear', 'Workwear', 'Sport', 'Outdoor', 'Vintage', 'Minimaliste', 'Preppy', 'Classique', 'Élégant'];
  static const uses = ['Quotidien', 'Travail', 'Soirée', 'Sport', 'Voyage', 'Randonnée', 'Maison', 'Vacances', 'Autre...'];
  static const seasons = Garment.availableSeasons;

  @override
  void initState() {
    super.initState();
    final g = widget.garment;
    _name = TextEditingController(text: g?.name ?? '');
    _brand = TextEditingController(text: g?.brand ?? '');
    _color = TextEditingController(text: g?.couleurPrincipale ?? g?.color ?? '');
    _size = TextEditingController(text: g?.size ?? '');
    _notes = TextEditingController(text: g?.notes ?? '');
    _composition = TextEditingController(text: g?.composition ?? '');
    final hasCustomCategory = g != null && !categories.contains(g.category);
    _otherCategory = TextEditingController(text: hasCustomCategory ? g.category : '');
    _otherSubCategory = TextEditingController(text: hasCustomCategory ? g.sousCategorie ?? '' : '');
    _minTemp = TextEditingController(text: g?.thermalProfile?.standaloneMinC.toString() ?? '');
    _maxTemp = TextEditingController(text: g?.thermalProfile?.standaloneMaxC.toString() ?? '');
    _category = hasCustomCategory ? 'Autre' : (categories.contains(g?.category) ? g!.category : categories.first);
    _subCategory = _choice(g?.sousCategorie, subCategories[_category]!);
    final existingMaterial = g?.matierePrincipale ?? g?.material;
    _material = _choice(existingMaterial, materials);
    _otherMaterial = TextEditingController(text: _material == null ? existingMaterial ?? '' : '');
    final existingUses = g?.effectiveOccasions ?? const <String>[];
    _uses = existingUses.where(uses.contains).toSet();
    final customUses = existingUses.where((value) => !uses.contains(value)).toList();
    if (customUses.isNotEmpty) _uses.add('Autre...');
    _otherUse = TextEditingController(text: customUses.join(', '));
    _styles = g == null ? <String>{} : {g.effectiveStyleAnalysis.register, ...g.effectiveStyleAnalysis.secondaryStyles}.where(styles.contains).toSet();
    _seasons = {...?g?.effectiveSeasons}; // Never select all seasons by default.
    _rain = g?.compatiblePluie;
    _heat = g?.compatibleChaleur;
    _imagePath = g == null || g.effectivePhotos.isEmpty ? null : g.effectivePhotos.first.path;
  }

  static String? _choice(String? value, List<String> values) => values.contains(value) ? value : null;
  String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
  double? _number(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in [_name, _brand, _color, _size, _otherMaterial, _otherUse, _otherCategory, _otherSubCategory, _composition, _minTemp, _maxTemp, _notes]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _chooseImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 88, maxWidth: 1800);
    if (picked == null) return;
    final path = await ImageStorageService.persist(picked.path);
    if (_imagePath != null && _imagePath != (widget.garment == null || widget.garment!.effectivePhotos.isEmpty ? null : widget.garment!.effectivePhotos.first.path)) await ImageStorageService.remove(_imagePath);
    if (mounted) setState(() => _imagePath = path);
  }

  Future<void> _imageActions() => showModalBottomSheet<void>(
    context: context, showDragHandle: true,
    builder: (context) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Prendre une photo'), onTap: () { Navigator.pop(context); _chooseImage(ImageSource.camera); }),
      ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Changer la photo'), onTap: () { Navigator.pop(context); _chooseImage(ImageSource.gallery); }),
      if (_imagePath != null) ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Supprimer la photo'), onTap: () async { Navigator.pop(context); if (_imagePath != (widget.garment == null || widget.garment!.effectivePhotos.isEmpty ? null : widget.garment!.effectivePhotos.first.path)) await ImageStorageService.remove(_imagePath); if (mounted) setState(() => _imagePath = null); }),
    ])),
  );

  Future<void> _showHelp() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .72,
      maxChildSize: .92,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('Aide à la saisie', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Retrouvez ici les repères utilisés dans les fiches. Vous pouvez toujours choisir « Autre… » pour saisir votre propre valeur.'),
          const SizedBox(height: 16),
          _HelpSection(title: 'Styles', icon: Icons.style_outlined, values: styles, description: 'L’esthétique générale de la pièce, par exemple Casual, Business ou Streetwear.'),
          _HelpSection(title: 'Matières', icon: Icons.texture_outlined, values: materials.where((value) => value != 'Autre...').toList(), description: 'La fibre ou le textile principal. Consultez l’étiquette de composition en cas de doute.'),
          _HelpSection(title: 'Formalités', icon: Icons.business_center_outlined, values: const ['Casual', 'Smart Casual', 'Business', 'Formel', 'Sport'], description: 'Le niveau de tenue attendu, du plus décontracté au plus habillé.'),
          _HelpSection(title: 'Occasions', icon: Icons.event_available_outlined, values: uses.where((value) => value != 'Autre...').toList(), description: 'Les contextes dans lesquels vous porteriez naturellement cette pièce.'),
        ],
      ),
    ),
  );



  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final min = _number(_minTemp), max = _number(_maxTemp);
    if (min != null && max != null && min > max) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La température minimale doit être inférieure au maximum.'))); return; }
    setState(() => _saving = true);
    final old = widget.garment;
    final now = DateTime.now();
    final material = _material == 'Autre...' ? _text(_otherMaterial) : _material;
    final selectedUses = _uses.where((value) => value != 'Autre...').toList();
    if (_uses.contains('Autre...')) {
      selectedUses.addAll(
        _otherUse.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
    }
    final uniqueUses = selectedUses.toSet().toList();
    final composition = _text(_composition);
    final thermalInput = ThermalProfileInput(
      category: _category == 'Autre' ? (_text(_otherCategory) ?? 'Autre') : _category,
      subcategory: _subCategory == 'Autre' ? _text(_otherSubCategory) : _subCategory,
      material: material,
      composition: composition,
      lining: composition?.toLowerCase().contains('doublure') == true ? 'doublure' : null,
      fit: old?.coupe ?? old?.fit,
      thickness: old?.texture,
      detectedFeatures: [
        if (old?.typePrecis != null) old!.typePrecis!,
        if (old?.motif != null) old!.motif!,
        if (old?.typeFermeture != null) old!.typeFermeture!,
      ],
    );
    final thermalProfile = const ThermalProfileCalculator().ensureCurrent(
      thermalInput,
      old?.thermalProfile,
      calculatedAt: now,
    );
    final garment = Garment(
      id: old?.id ?? const Uuid().v4(), name: _name.text.trim(), category: _category == 'Autre' ? (_text(_otherCategory) ?? 'Autre') : _category,
      brand: _text(_brand), color: _text(_color), material: material, size: _text(_size), notes: _text(_notes),
      photos: _imagePath == null ? const [] : [GarmentPhoto(id: old?.effectivePhotos.firstOrNull?.id ?? const Uuid().v4(), path: _imagePath!, type: GarmentPhotoType.primary, createdAt: old?.effectivePhotos.firstOrNull?.createdAt ?? now)],
      sousCategorie: _subCategory == 'Autre' ? _text(_otherSubCategory) : _subCategory, couleurPrincipale: _text(_color), matierePrincipale: material,
      typePrecis: old?.typePrecis, superposable: old?.superposable,
      saisons: _seasons.toList(),
      occasions: uniqueUses.isEmpty ? null : uniqueUses,
      compatiblePluie: thermalProfile.rainCompatibility.name != 'none',
      compatibleChaleur: thermalProfile.breathability.name == 'high',
      layerType: switch (thermalProfile.primaryRole.name) {
        'base' => 'Couche de base',
        'outer' => 'Couche extérieure',
        _ => 'Couche intermédiaire',
      },
      thermalProfile: thermalProfile,
      descriptionIA: old?.descriptionIA, couleursSecondaires: old?.couleursSecondaires, motif: old?.motif, texture: old?.texture,
      logoVisible: old?.logoVisible, niveauFormalite: old?.niveauFormalite, coupe: old?.coupe, longueur: old?.longueur,
      longueurManches: old?.longueurManches, typeCol: old?.typeCol, typeFermeture: old?.typeFermeture,
      matieresSecondaires: old?.matieresSecondaires, confianceMatiere: old?.confianceMatiere, etatVisuel: old?.etatVisuel,
      usureVisible: old?.usureVisible, defautsVisibles: old?.defautsVisibles, confianceGlobale: old?.confianceGlobale,
      avertissementsIA: old?.avertissementsIA, pointsForts: old?.pointsForts,
      pointsFaibles: old?.pointsFaibles, conseils: old?.conseils, verdict: old?.verdict, couleursCompatibles: old?.couleursCompatibles,
      couleursMoinsAdaptees: old?.couleursMoinsAdaptees, basCompatibles: old?.basCompatibles, chaussuresCompatibles: old?.chaussuresCompatibles,
      explicationPolyvalence: old?.explicationPolyvalence, occasionsDeconseillees: old?.occasionsDeconseillees,
      compositionEstimee: old?.compositionEstimee, lavage: old?.lavage, sechage: old?.sechage, repassage: old?.repassage,
      nettoyage: old?.nettoyage, boulochage: old?.boulochage, taches: old?.taches, limitesAnalyse: old?.limitesAnalyse,
      condition: old?.condition, purchasePrice: old?.purchasePrice, purchaseDate: old?.purchaseDate, lastWorn: old?.lastWorn,
      fit: old?.fit, composition: composition, wearCount: old?.wearCount ?? 0, isFavorite: old?.isFavorite ?? false,
      createdAt: old?.createdAt ?? now, updatedAt: now,
    );
    try { await widget.controller.save(garment, isNew: old == null || widget.isDraft); if (mounted) Navigator.pop(context, true); }
    catch (e) { if (mounted) { setState(() => _saving = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Impossible d'enregistrer : $e"))); } }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.garment == null || widget.isDraft ? 'Valider la fiche' : 'Modifier la pièce'),
      actions: [IconButton(onPressed: _showHelp, tooltip: 'Aide sur les champs', icon: const Icon(Icons.help_outline))],
    ),
    body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
      GestureDetector(onTap: _imageActions, child: Stack(children: [GarmentImage(imagePath: _imagePath, width: double.infinity, height: 270, borderRadius: BorderRadius.circular(26)), Positioned(right: 12, bottom: 12, child: FilledButton.tonalIcon(onPressed: _imageActions, icon: const Icon(Icons.camera_alt_outlined), label: Text(_imagePath == null ? 'Ajouter' : 'Actions photo')))])),
      const SizedBox(height: 18),
      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nom *', helperText: 'Proposé par l’IA · corrigez seulement si nécessaire'), validator: (v) => v == null || v.trim().isEmpty ? 'Le nom est obligatoire' : null),
      const SizedBox(height: 10), TextFormField(controller: _brand, decoration: const InputDecoration(labelText: 'Marque')),
      const SizedBox(height: 10), DropdownButtonFormField(value: _category, decoration: const InputDecoration(labelText: 'Catégorie'), items: categories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() { _category = v!; _subCategory = null; })),
      if (_category == 'Autre') ...[const SizedBox(height: 10), TextFormField(controller: _otherCategory, decoration: const InputDecoration(labelText: 'Votre catégorie *'), validator: (v) => v == null || v.trim().isEmpty ? 'Précisez la catégorie' : null)],
      const SizedBox(height: 10), DropdownButtonFormField<String>(value: _subCategory, decoration: const InputDecoration(labelText: 'Sous-catégorie'), items: subCategories[_category]!.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _subCategory = v)),
      if (_subCategory == 'Autre') ...[const SizedBox(height: 10), TextFormField(controller: _otherSubCategory, decoration: const InputDecoration(labelText: 'Votre sous-catégorie *'), validator: (v) => v == null || v.trim().isEmpty ? 'Précisez la sous-catégorie' : null)],
      const SizedBox(height: 10), TextFormField(controller: _color, decoration: const InputDecoration(labelText: 'Couleur')),
      const SizedBox(height: 10), DropdownButtonFormField<String>(value: _material, decoration: const InputDecoration(labelText: 'Matière'), items: materials.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _material = v)),
      if (_material == 'Autre...') ...[const SizedBox(height: 10), TextFormField(controller: _otherMaterial, decoration: const InputDecoration(labelText: 'Votre matière *'), validator: (v) => v == null || v.trim().isEmpty ? 'Précisez la matière' : null)],
      const SizedBox(height: 10), TextFormField(controller: _composition, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Composition textile', helperText: 'Tissu principal, doublure et rembourrage · pourcentages modifiables')),
      const SizedBox(height: 18), _MultiChoice(label: 'Styles', values: styles, selected: _styles, onChanged: (v) => setState(() => _styles = v)),
      const SizedBox(height: 10), _MultiChoice(label: 'Saisons', values: seasons, selected: _seasons, onChanged: (v) => setState(() => _seasons = v)),
      const SizedBox(height: 10), _MultiChoice(label: 'Utilisations', values: uses, selected: _uses, onChanged: (v) => setState(() => _uses = v)),
      if (_uses.contains('Autre...')) ...[const SizedBox(height: 10), TextFormField(controller: _otherUse, decoration: const InputDecoration(labelText: 'Vos occasions *', helperText: 'Séparez plusieurs occasions par des virgules'), validator: (v) => v == null || v.trim().isEmpty ? 'Précisez au moins une occasion' : null)],
      const SizedBox(height: 10), TextFormField(controller: _size, decoration: const InputDecoration(labelText: 'Taille (facultative)', helperText: 'Jamais estimée par l’IA')),
      const SizedBox(height: 18), Row(children: [Expanded(child: _Temperature(controller: _minTemp, label: 'Temp. min')), const SizedBox(width: 10), Expanded(child: _Temperature(controller: _maxTemp, label: 'Temp. max'))]),
      const SizedBox(height: 10), _TriState(label: 'Compatible pluie', value: _rain, onChanged: (v) => setState(() => _rain = v)),
      _TriState(label: 'Compatible chaleur', value: _heat, onChanged: (v) => setState(() => _heat = v)),
      const SizedBox(height: 10), TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
      const SizedBox(height: 24), FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58)), onPressed: _saving ? null : _save, icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check), label: const Text('Enregistrer la fiche')),
    ])),
  );
}

class _HelpSection extends StatelessWidget {
  final String title, description;
  final IconData icon;
  final List<String> values;
  const _HelpSection({required this.title, required this.icon, required this.values, required this.description});

  @override
  Widget build(BuildContext context) => ExpansionTile(
    leading: Icon(icon),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text(description),
    children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Wrap(spacing: 8, runSpacing: 8, children: values.map((value) => Chip(label: Text(value))).toList()))],
  );
}

class _MultiChoice extends StatelessWidget {
  final String label; final List<String> values; final Set<String> selected; final ValueChanged<Set<String>> onChanged;
  const _MultiChoice({required this.label, required this.values, required this.selected, required this.onChanged});
  @override Widget build(BuildContext context) => InputDecorator(decoration: InputDecoration(labelText: label, helperText: 'Suggestions IA · sélection modifiable'), child: Wrap(spacing: 7, children: values.map((v) => FilterChip(label: Text(v), selected: selected.contains(v), onSelected: (yes) { final next = {...selected}; yes ? next.add(v) : next.remove(v); onChanged(next); })).toList()));
}
class _Temperature extends StatelessWidget {
  final TextEditingController controller; final String label; const _Temperature({required this.controller, required this.label});
  @override Widget build(BuildContext context) => TextFormField(controller: controller, keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9,.]'))], decoration: InputDecoration(labelText: label, suffixText: '°C', helperText: 'Calcul IA'));
}
class _TriState extends StatelessWidget {
  final String label; final bool? value; final ValueChanged<bool?> onChanged; const _TriState({required this.label, required this.value, required this.onChanged});
  @override Widget build(BuildContext context) => DropdownButtonFormField<bool?>(value: value, decoration: InputDecoration(labelText: label, helperText: 'Calcul IA · modifiable'), items: const [DropdownMenuItem(value: null, child: Text('À calculer')), DropdownMenuItem(value: true, child: Text('Oui')), DropdownMenuItem(value: false, child: Text('Non'))], onChanged: onChanged);
}
