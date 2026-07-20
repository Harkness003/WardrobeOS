import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../data/image_storage_service.dart';
import '../../models/garment.dart';
import '../../widgets/garment_image.dart';
import 'wardrobe_controller.dart';

class GarmentFormScreen extends StatefulWidget {
  final WardrobeController controller;
  final Garment? garment;

  const GarmentFormScreen({super.key, required this.controller, this.garment});

  @override
  State<GarmentFormScreen> createState() => _GarmentFormScreenState();
}

class _GarmentFormScreenState extends State<GarmentFormScreen> {
  final formKey = GlobalKey<FormState>();
  final picker = ImagePicker();

  late final TextEditingController name;
  late final TextEditingController brand;
  late final TextEditingController color;
  late final TextEditingController material;
  late final TextEditingController price;
  late final TextEditingController size;
  late final TextEditingController composition;
  late final TextEditingController notes;
  late final Map<String, TextEditingController> richFields;

  late String category;
  late String season;
  late String style;
  late String occasion;
  late String condition;
  late String fit;
  DateTime? purchaseDate;
  String? imagePath;
  bool favorite = false;
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
  static const styles = [
    'Non défini',
    'Casual',
    'Smart casual',
    'Business',
    'Minimaliste',
    'Streetwear',
    'Sport',
    'Élégant',
  ];
  static const occasions = [
    'Non définie',
    'Quotidien',
    'Travail',
    'Soirée',
    'Cérémonie',
    'Vacances',
    'Sport',
  ];
  static const conditions = [
    'Non défini',
    'Neuf',
    'Excellent',
    'Bon',
    'Usé',
    'À réparer',
  ];
  static const fits = [
    'Non définie',
    'Slim',
    'Regular',
    'Relaxed',
    'Oversize',
    'Ajustée',
  ];

  @override
  void initState() {
    super.initState();
    final g = widget.garment;
    name = TextEditingController(text: g?.name ?? '');
    brand = TextEditingController(text: g?.brand ?? '');
    color = TextEditingController(text: g?.color ?? '');
    material = TextEditingController(text: g?.material ?? '');
    price = TextEditingController(
      text:
          g?.purchasePrice == null
              ? ''
              : g!.purchasePrice!.toStringAsFixed(
                g.purchasePrice! % 1 == 0 ? 0 : 2,
              ),
    );
    size = TextEditingController(text: g?.size ?? '');
    composition = TextEditingController(text: g?.composition ?? '');
    notes = TextEditingController(text: g?.notes ?? '');
    richFields = {
      'sousCategorie': TextEditingController(text: g?.sousCategorie?.toString() ?? ''),
      'typePrecis': TextEditingController(text: g?.typePrecis?.toString() ?? ''),
      'descriptionIA': TextEditingController(text: g?.descriptionIA?.toString() ?? ''),
      'couleurPrincipale': TextEditingController(text: g?.couleurPrincipale?.toString() ?? ''),
      'couleursSecondaires': TextEditingController(text: g?.couleursSecondaires?.join(', ') ?? ''),
      'motif': TextEditingController(text: g?.motif?.toString() ?? ''),
      'texture': TextEditingController(text: g?.texture?.toString() ?? ''),
      'logoVisible': TextEditingController(text: g?.logoVisible == null ? '' : (g!.logoVisible! ? 'oui' : 'non')),
      'stylePrincipal': TextEditingController(text: g?.stylePrincipal?.toString() ?? ''),
      'stylesSecondaires': TextEditingController(text: g?.stylesSecondaires?.join(', ') ?? ''),
      'niveauFormalite': TextEditingController(text: g?.niveauFormalite?.toString() ?? ''),
      'coupe': TextEditingController(text: g?.coupe?.toString() ?? ''),
      'longueur': TextEditingController(text: g?.longueur?.toString() ?? ''),
      'longueurManches': TextEditingController(text: g?.longueurManches?.toString() ?? ''),
      'typeCol': TextEditingController(text: g?.typeCol?.toString() ?? ''),
      'typeFermeture': TextEditingController(text: g?.typeFermeture?.toString() ?? ''),
      'matierePrincipale': TextEditingController(text: g?.matierePrincipale?.toString() ?? ''),
      'matieresSecondaires': TextEditingController(text: g?.matieresSecondaires?.join(', ') ?? ''),
      'confianceMatiere': TextEditingController(text: g?.confianceMatiere?.toString() ?? ''),
      'saisons': TextEditingController(text: g?.saisons?.join(', ') ?? ''),
      'occasions': TextEditingController(text: g?.occasions?.join(', ') ?? ''),
      'temperatureMinimum': TextEditingController(text: g?.temperatureMinimum?.toString() ?? ''),
      'temperatureMaximum': TextEditingController(text: g?.temperatureMaximum?.toString() ?? ''),
      'compatiblePluie': TextEditingController(text: g?.compatiblePluie == null ? '' : (g!.compatiblePluie! ? 'oui' : 'non')),
      'compatibleChaleur': TextEditingController(text: g?.compatibleChaleur == null ? '' : (g!.compatibleChaleur! ? 'oui' : 'non')),
      'superposable': TextEditingController(text: g?.superposable == null ? '' : (g!.superposable! ? 'oui' : 'non')),
      'etatVisuel': TextEditingController(text: g?.etatVisuel?.toString() ?? ''),
      'usureVisible': TextEditingController(text: g?.usureVisible?.toString() ?? ''),
      'defautsVisibles': TextEditingController(text: g?.defautsVisibles?.join(', ') ?? ''),
      'confianceGlobale': TextEditingController(text: g?.confianceGlobale?.toString() ?? ''),
      'avertissementsIA': TextEditingController(text: g?.avertissementsIA?.join(', ') ?? ''),
    };
    category = _safeValue(g?.category, categories, 'Hauts');
    season = _safeValue(g?.season, seasons, 'Toute saison');
    style = _safeValue(g?.style, styles, 'Non défini');
    occasion = _safeValue(g?.occasion, occasions, 'Non définie');
    condition = _safeValue(g?.condition, conditions, 'Non défini');
    fit = _safeValue(g?.fit, fits, 'Non définie');
    purchaseDate = g?.purchaseDate;
    imagePath = g?.imagePath;
    favorite = g?.isFavorite ?? false;
  }

  static String _safeValue(
    String? value,
    List<String> allowed,
    String fallback,
  ) {
    return value != null && allowed.contains(value) ? value : fallback;
  }

  @override
  void dispose() {
    name.dispose();
    brand.dispose();
    color.dispose();
    material.dispose();
    price.dispose();
    size.dispose();
    composition.dispose();
    notes.dispose();
    for (final controller in richFields.values) { controller.dispose(); }
    super.dispose();
  }

  Future<void> chooseImage(ImageSource source) async {
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (picked == null) return;
    final persisted = await ImageStorageService.persist(picked.path);
    if (imagePath != null && imagePath != widget.garment?.imagePath) {
      await ImageStorageService.remove(imagePath);
    }
    if (mounted) setState(() => imagePath = persisted);
  }

  Future<void> showImageSource() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (_) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Prendre une photo'),
                  onTap: () {
                    Navigator.pop(context);
                    chooseImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choisir dans la galerie'),
                  onTap: () {
                    Navigator.pop(context);
                    chooseImage(ImageSource.gallery);
                  },
                ),
                if (imagePath != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Retirer la photo'),
                    onTap: () async {
                      Navigator.pop(context);
                      if (imagePath != widget.garment?.imagePath) {
                        await ImageStorageService.remove(imagePath);
                      }
                      if (mounted) setState(() => imagePath = null);
                    },
                  ),
              ],
            ),
          ),
    );
  }

  Future<void> pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: purchaseDate ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
      helpText: "Date d'achat",
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (picked != null && mounted) {
      setState(() => purchaseDate = picked);
    }
  }

  double? _parsePrice() {
    final normalized = price.text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  String? _optionalChoice(String value, String emptyValue) {
    return value == emptyValue ? null : value;
  }


  String? _rich(String key) => _optional(richFields[key]!);
  List<String>? _richList(String key) {
    final values = richFields[key]!.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    return values.isEmpty ? null : values;
  }
  double? _richDouble(String key) => double.tryParse(richFields[key]!.text.trim().replaceAll(',', '.'));
  bool? _richBool(String key) {
    final value = richFields[key]!.text.trim().toLowerCase();
    if (value.isEmpty) return null;
    return value == 'oui' || value == 'true' || value == '1';
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);

    try {
      final now = DateTime.now();
      final old = widget.garment;
      final garment = Garment(
        id: old?.id ?? const Uuid().v4(),
        name: name.text.trim(),
        category: category,
        brand: _optional(brand),
        color: _optional(color),
        material: _optional(material),
        season: season,
        style: _optionalChoice(style, 'Non défini'),
        occasion: _optionalChoice(occasion, 'Non définie'),
        condition: _optionalChoice(condition, 'Non défini'),
        sousCategorie: _rich('sousCategorie'),
        typePrecis: _rich('typePrecis'),
        descriptionIA: _rich('descriptionIA'),
        couleurPrincipale: _rich('couleurPrincipale'),
        couleursSecondaires: _richList('couleursSecondaires'),
        motif: _rich('motif'),
        texture: _rich('texture'),
        logoVisible: _richBool('logoVisible'),
        stylePrincipal: _rich('stylePrincipal'),
        stylesSecondaires: _richList('stylesSecondaires'),
        niveauFormalite: _rich('niveauFormalite'),
        coupe: _rich('coupe'),
        longueur: _rich('longueur'),
        longueurManches: _rich('longueurManches'),
        typeCol: _rich('typeCol'),
        typeFermeture: _rich('typeFermeture'),
        matierePrincipale: _rich('matierePrincipale'),
        matieresSecondaires: _richList('matieresSecondaires'),
        confianceMatiere: _richDouble('confianceMatiere'),
        saisons: _richList('saisons'),
        occasions: _richList('occasions'),
        temperatureMinimum: _richDouble('temperatureMinimum'),
        temperatureMaximum: _richDouble('temperatureMaximum'),
        compatiblePluie: _richBool('compatiblePluie'),
        compatibleChaleur: _richBool('compatibleChaleur'),
        superposable: _richBool('superposable'),
        etatVisuel: _rich('etatVisuel'),
        usureVisible: _rich('usureVisible'),
        defautsVisibles: _richList('defautsVisibles'),
        confianceGlobale: _richDouble('confianceGlobale'),
        avertissementsIA: _richList('avertissementsIA'),
        purchasePrice: _parsePrice(),
        purchaseDate: purchaseDate,
        wearCount: old?.wearCount ?? 0,
        lastWorn: old?.lastWorn,
        size: _optional(size),
        fit: _optionalChoice(fit, 'Non définie'),
        composition: _optional(composition),
        notes: _optional(notes),
        imagePath: imagePath,
        isFavorite: favorite,
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
      );

      final businessError = garment.validate();
      if (businessError != null) throw FormatException(businessError);
      await widget.controller.save(garment, isNew: old == null);
      if (old?.imagePath != null && old!.imagePath != imagePath) {
        await ImageStorageService.remove(old.imagePath);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible d'enregistrer : $error")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.garment != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Modifier la pièce' : 'Nouvelle pièce'),
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            children: [
              GestureDetector(
                onTap: showImageSource,
                child: Stack(
                  children: [
                    GarmentImage(
                      imagePath: imagePath,
                      width: double.infinity,
                      height: 270,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FilledButton.tonalIcon(
                        onPressed: showImageSource,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(
                          imagePath == null ? 'Ajouter une photo' : 'Changer',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _FormSectionTitle(
                icon: Icons.checkroom_outlined,
                title: 'Informations principales',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nom *'),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Le nom est obligatoire'
                            : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: brand,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Marque'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items:
                    categories
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                onChanged: (value) => setState(() => category = value!),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: color,
                      decoration: const InputDecoration(labelText: 'Couleur'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: material,
                      decoration: const InputDecoration(labelText: 'Matière'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _FormSectionTitle(
                icon: Icons.tune_outlined,
                title: 'Style et usage',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: season,
                decoration: const InputDecoration(labelText: 'Saison'),
                items:
                    seasons
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                onChanged: (value) => setState(() => season = value!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: style,
                decoration: const InputDecoration(labelText: 'Style'),
                items:
                    styles
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                onChanged: (value) => setState(() => style = value!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: occasion,
                decoration: const InputDecoration(labelText: 'Occasion'),
                items:
                    occasions
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                onChanged: (value) => setState(() => occasion = value!),
              ),
              const SizedBox(height: 22),
              const _FormSectionTitle(
                icon: Icons.straighten_outlined,
                title: 'Taille et composition',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: size,
                      decoration: const InputDecoration(labelText: 'Taille'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: fit,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Coupe'),
                      items:
                          fits
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                      onChanged: (value) => setState(() => fit = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: composition,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Composition',
                  hintText: 'Ex. 100 % coton',
                ),
              ),
              const SizedBox(height: 22),
              const _FormSectionTitle(
                icon: Icons.receipt_long_outlined,
                title: 'Achat et état',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: condition,
                decoration: const InputDecoration(labelText: 'État'),
                items:
                    conditions
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                onChanged: (value) => setState(() => condition = value!),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                decoration: const InputDecoration(
                  labelText: "Prix d'achat",
                  suffixText: '€',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  return _parsePrice() == null ? 'Prix invalide' : null;
                },
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: pickPurchaseDate,
                borderRadius: BorderRadius.circular(18),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: "Date d'achat",
                    suffixIcon:
                        purchaseDate == null
                            ? const Icon(Icons.calendar_month_outlined)
                            : IconButton(
                              tooltip: 'Effacer la date',
                              onPressed:
                                  () => setState(() => purchaseDate = null),
                              icon: const Icon(Icons.close),
                            ),
                  ),
                  child: Text(
                    purchaseDate == null
                        ? 'Non renseignée'
                        : _formatDate(purchaseDate!),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const _FormSectionTitle(
                icon: Icons.notes_outlined,
                title: 'Notes',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notes,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes personnelles',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                title: const Text('Informations', style: TextStyle(fontWeight: FontWeight.w800)),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                    TextFormField(controller: richFields['sousCategorie'], decoration: const InputDecoration(labelText: 'Sous-catégorie', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['typePrecis'], decoration: const InputDecoration(labelText: 'Type précis', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['descriptionIA'], decoration: const InputDecoration(labelText: 'Description IA', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                ],
              ),
              ExpansionTile(
                title: const Text('Apparence', style: TextStyle(fontWeight: FontWeight.w800)),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                    TextFormField(controller: richFields['couleurPrincipale'], decoration: const InputDecoration(labelText: 'Couleur principale', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['couleursSecondaires'], decoration: const InputDecoration(labelText: 'Couleurs secondaires (séparées par des virgules)', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['motif'], decoration: const InputDecoration(labelText: 'Motif', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['texture'], decoration: const InputDecoration(labelText: 'Texture', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['logoVisible'], decoration: const InputDecoration(labelText: 'Logo visible (oui/non)', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                ],
              ),
              ExpansionTile(
                title: const Text('Style', style: TextStyle(fontWeight: FontWeight.w800)),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                    TextFormField(controller: richFields['stylePrincipal'], decoration: const InputDecoration(labelText: 'Style principal', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['stylesSecondaires'], decoration: const InputDecoration(labelText: 'Styles secondaires (séparés par des virgules)', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['niveauFormalite'], decoration: const InputDecoration(labelText: 'Niveau de formalité', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['coupe'], decoration: const InputDecoration(labelText: 'Coupe', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['longueur'], decoration: const InputDecoration(labelText: 'Longueur', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['longueurManches'], decoration: const InputDecoration(labelText: 'Longueur des manches', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['typeCol'], decoration: const InputDecoration(labelText: 'Type de col', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['typeFermeture'], decoration: const InputDecoration(labelText: 'Type de fermeture', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                ],
              ),
              ExpansionTile(
                title: const Text('Matière', style: TextStyle(fontWeight: FontWeight.w800)),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                    TextFormField(controller: richFields['matierePrincipale'], decoration: const InputDecoration(labelText: 'Matière principale', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['matieresSecondaires'], decoration: const InputDecoration(labelText: 'Matières secondaires (séparées par des virgules)', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['confianceMatiere'], decoration: const InputDecoration(labelText: 'Confiance matière (0 à 1)', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                ],
              ),
              ExpansionTile(
                title: const Text('Utilisation', style: TextStyle(fontWeight: FontWeight.w800)),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                    TextFormField(controller: richFields['saisons'], decoration: const InputDecoration(labelText: 'Saisons (séparées par des virgules)', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['occasions'], decoration: const InputDecoration(labelText: 'Occasions (séparées par des virgules)', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['temperatureMinimum'], decoration: const InputDecoration(labelText: 'Température minimum', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['temperatureMaximum'], decoration: const InputDecoration(labelText: 'Température maximum', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['compatiblePluie'], decoration: const InputDecoration(labelText: 'Compatible pluie (oui/non)', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['compatibleChaleur'], decoration: const InputDecoration(labelText: 'Compatible chaleur (oui/non)', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['superposable'], decoration: const InputDecoration(labelText: 'Superposable (oui/non)', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                ],
              ),
              ExpansionTile(
                title: const Text('État', style: TextStyle(fontWeight: FontWeight.w800)),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                    TextFormField(controller: richFields['etatVisuel'], decoration: const InputDecoration(labelText: 'État visuel', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['usureVisible'], decoration: const InputDecoration(labelText: 'Usure visible', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['defautsVisibles'], decoration: const InputDecoration(labelText: 'Défauts visibles (séparés par des virgules)', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                ],
              ),
              ExpansionTile(
                title: const Text('Analyse IA', style: TextStyle(fontWeight: FontWeight.w800)),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                    TextFormField(controller: richFields['confianceGlobale'], decoration: const InputDecoration(labelText: 'Confiance globale (0 à 1)', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                    TextFormField(controller: richFields['avertissementsIA'], decoration: const InputDecoration(labelText: 'Avertissements IA (séparés par des virgules)', helperText: 'Suggestion IA · modifiable')),
                    const SizedBox(height: 10),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Ajouter aux favoris',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                value: favorite,
                onChanged: (value) => setState(() => favorite = value),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon:
                    saving
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.save_outlined),
                label: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _FormSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _FormSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
