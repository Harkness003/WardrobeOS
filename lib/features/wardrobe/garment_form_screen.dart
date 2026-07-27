import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../data/image_storage_service.dart';
import '../../models/garment.dart';
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
      _otherUse, _minTemp, _maxTemp, _notes;
  late String _category;
  String? _subCategory, _material, _use;
  late Set<String> _styles, _seasons;
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
    _minTemp = TextEditingController(text: g?.temperatureMinimum?.toString() ?? '');
    _maxTemp = TextEditingController(text: g?.temperatureMaximum?.toString() ?? '');
    _category = categories.contains(g?.category) ? g!.category : categories.first;
    _subCategory = _choice(g?.sousCategorie, subCategories[_category]!);
    final existingMaterial = g?.matierePrincipale ?? g?.material;
    _material = _choice(existingMaterial, materials);
    _otherMaterial = TextEditingController(text: _material == null ? existingMaterial ?? '' : '');
    final existingUse = g?.occasions?.isNotEmpty == true ? g!.occasions!.first : g?.occasion;
    _use = _choice(existingUse, uses);
    _otherUse = TextEditingController(text: _use == null ? existingUse ?? '' : '');
    _styles = {...?g?.stylesSecondaires, if (g?.stylePrincipal != null) g!.stylePrincipal!, if (g?.style != null) g!.style!}.where(styles.contains).toSet();
    _seasons = {...?g?.effectiveSeasons}; // Never select all seasons by default.
    _rain = g?.compatiblePluie;
    _heat = g?.compatibleChaleur;
    _imagePath = g?.imagePath;
  }

  static String? _choice(String? value, List<String> values) => values.contains(value) ? value : null;
  String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
  double? _number(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in [_name, _brand, _color, _size, _otherMaterial, _otherUse, _minTemp, _maxTemp, _notes]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _chooseImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 88, maxWidth: 1800);
    if (picked == null) return;
    final path = await ImageStorageService.persist(picked.path);
    if (_imagePath != null && _imagePath != widget.garment?.imagePath) await ImageStorageService.remove(_imagePath);
    if (mounted) setState(() => _imagePath = path);
  }

  Future<void> _imageActions() => showModalBottomSheet<void>(
    context: context, showDragHandle: true,
    builder: (context) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Prendre une photo'), onTap: () { Navigator.pop(context); _chooseImage(ImageSource.camera); }),
      ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Changer la photo'), onTap: () { Navigator.pop(context); _chooseImage(ImageSource.gallery); }),
      if (_imagePath != null) ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Supprimer la photo'), onTap: () async { Navigator.pop(context); if (_imagePath != widget.garment?.imagePath) await ImageStorageService.remove(_imagePath); if (mounted) setState(() => _imagePath = null); }),
    ])),
  );

  String _calculatedLayer() {
    if (_category == 'Vestes') return _subCategory == 'Imperméable' ? 'Couche de protection' : 'Couche extérieure';
    if (_category == 'Hauts' || _category == 'Chemises') return _material == 'Laine' || _material == 'Mérinos' || _material == 'Cachemire' ? 'Couche chaude' : 'Couche de base';
    return 'Couche intermédiaire';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final min = _number(_minTemp), max = _number(_maxTemp);
    if (min != null && max != null && min > max) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La température minimale doit être inférieure au maximum.'))); return; }
    setState(() => _saving = true);
    final old = widget.garment;
    final now = DateTime.now();
    final material = _material == 'Autre...' ? _text(_otherMaterial) : _material;
    final use = _use == 'Autre...' ? _text(_otherUse) : _use;
    final garment = Garment(
      id: old?.id ?? const Uuid().v4(), name: _name.text.trim(), category: _category,
      brand: _text(_brand), color: _text(_color), material: material, size: _text(_size), notes: _text(_notes), imagePath: _imagePath,
      sousCategorie: _subCategory, couleurPrincipale: _text(_color), matierePrincipale: material,
      // Legacy-only values remain persisted although they are no longer shown.
      typePrecis: old?.typePrecis, superposable: old?.superposable,
      style: _styles.isEmpty ? null : _styles.first, stylePrincipal: _styles.isEmpty ? null : _styles.first, stylesSecondaires: _styles.toList(),
      season: _seasons.length == 1 ? _seasons.single : null, saisons: _seasons.toList(),
      occasion: use, occasions: use == null ? null : [use], temperatureMinimum: min, temperatureMaximum: max,
      compatiblePluie: _rain, compatibleChaleur: _heat, layerType: _calculatedLayer(),
      descriptionIA: old?.descriptionIA, couleursSecondaires: old?.couleursSecondaires, motif: old?.motif, texture: old?.texture,
      logoVisible: old?.logoVisible, niveauFormalite: old?.niveauFormalite, coupe: old?.coupe, longueur: old?.longueur,
      longueurManches: old?.longueurManches, typeCol: old?.typeCol, typeFermeture: old?.typeFermeture,
      matieresSecondaires: old?.matieresSecondaires, confianceMatiere: old?.confianceMatiere, etatVisuel: old?.etatVisuel,
      usureVisible: old?.usureVisible, defautsVisibles: old?.defautsVisibles, confianceGlobale: old?.confianceGlobale,
      avertissementsIA: old?.avertissementsIA, resumeStylistique: old?.resumeStylistique, pointsForts: old?.pointsForts,
      pointsFaibles: old?.pointsFaibles, conseils: old?.conseils, verdict: old?.verdict, couleursCompatibles: old?.couleursCompatibles,
      couleursMoinsAdaptees: old?.couleursMoinsAdaptees, basCompatibles: old?.basCompatibles, chaussuresCompatibles: old?.chaussuresCompatibles,
      explicationPolyvalence: old?.explicationPolyvalence, occasionsDeconseillees: old?.occasionsDeconseillees,
      compositionEstimee: old?.compositionEstimee, lavage: old?.lavage, sechage: old?.sechage, repassage: old?.repassage,
      nettoyage: old?.nettoyage, boulochage: old?.boulochage, taches: old?.taches, limitesAnalyse: old?.limitesAnalyse,
      condition: old?.condition, purchasePrice: old?.purchasePrice, purchaseDate: old?.purchaseDate, lastWorn: old?.lastWorn,
      fit: old?.fit, composition: old?.composition, wearCount: old?.wearCount ?? 0, isFavorite: old?.isFavorite ?? false,
      createdAt: old?.createdAt ?? now, updatedAt: now,
    );
    try { await widget.controller.save(garment, isNew: old == null || widget.isDraft); if (mounted) Navigator.pop(context, true); }
    catch (e) { if (mounted) { setState(() => _saving = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Impossible d'enregistrer : $e"))); } }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.garment == null || widget.isDraft ? 'Valider la fiche' : 'Modifier la pièce')),
    body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
      GestureDetector(onTap: _imageActions, child: Stack(children: [GarmentImage(imagePath: _imagePath, width: double.infinity, height: 270, borderRadius: BorderRadius.circular(26)), Positioned(right: 12, bottom: 12, child: FilledButton.tonalIcon(onPressed: _imageActions, icon: const Icon(Icons.camera_alt_outlined), label: Text(_imagePath == null ? 'Ajouter' : 'Actions photo')))])),
      const SizedBox(height: 18),
      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nom *', helperText: 'Proposé par l’IA · corrigez seulement si nécessaire'), validator: (v) => v == null || v.trim().isEmpty ? 'Le nom est obligatoire' : null),
      const SizedBox(height: 10), TextFormField(controller: _brand, decoration: const InputDecoration(labelText: 'Marque')),
      const SizedBox(height: 10), DropdownButtonFormField(value: _category, decoration: const InputDecoration(labelText: 'Catégorie'), items: categories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() { _category = v!; _subCategory = null; })),
      const SizedBox(height: 10), DropdownButtonFormField<String>(value: _subCategory, decoration: const InputDecoration(labelText: 'Sous-catégorie'), items: subCategories[_category]!.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _subCategory = v)),
      const SizedBox(height: 10), TextFormField(controller: _color, decoration: const InputDecoration(labelText: 'Couleur')),
      const SizedBox(height: 10), DropdownButtonFormField<String>(value: _material, decoration: const InputDecoration(labelText: 'Matière'), items: materials.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _material = v)),
      if (_material == 'Autre...') ...[const SizedBox(height: 10), TextFormField(controller: _otherMaterial, decoration: const InputDecoration(labelText: 'Autre matière'))],
      const SizedBox(height: 18), _MultiChoice(label: 'Styles', values: styles, selected: _styles, onChanged: (v) => setState(() => _styles = v)),
      const SizedBox(height: 10), _MultiChoice(label: 'Saisons', values: seasons, selected: _seasons, onChanged: (v) => setState(() => _seasons = v)),
      const SizedBox(height: 10), DropdownButtonFormField<String>(value: _use, decoration: const InputDecoration(labelText: 'Utilisation'), items: uses.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _use = v)),
      if (_use == 'Autre...') ...[const SizedBox(height: 10), TextFormField(controller: _otherUse, decoration: const InputDecoration(labelText: 'Autre utilisation'))],
      const SizedBox(height: 10), TextFormField(controller: _size, decoration: const InputDecoration(labelText: 'Taille (facultative)', helperText: 'Jamais estimée par l’IA')),
      const SizedBox(height: 18), Row(children: [Expanded(child: _Temperature(controller: _minTemp, label: 'Temp. min')), const SizedBox(width: 10), Expanded(child: _Temperature(controller: _maxTemp, label: 'Temp. max'))]),
      const SizedBox(height: 10), _TriState(label: 'Compatible pluie', value: _rain, onChanged: (v) => setState(() => _rain = v)),
      _TriState(label: 'Compatible chaleur', value: _heat, onChanged: (v) => setState(() => _heat = v)),
      const SizedBox(height: 10), TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
      const SizedBox(height: 24), FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check), label: const Text('Enregistrer')),
    ])),
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
