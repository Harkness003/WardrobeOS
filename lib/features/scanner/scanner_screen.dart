import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../data/image_storage_service.dart';
import '../../models/garment.dart';
import '../../models/garment_photo.dart';
import '../../models/garment_normalizer.dart';
import '../../models/thermal_profile_calculator.dart';
import '../../widgets/garment_image.dart';
import '../wardrobe/wardrobe_controller.dart';
import '../wardrobe/garment_form_screen.dart';
import '../assistant/settings/api_key_storage.dart';
import 'ai/garment_analysis_exception.dart';
import 'ai/garment_analysis_mapper.dart';
import 'ai/garment_analysis_normalizer.dart';
import 'ai/garment_analysis_request.dart';
import 'ai/garment_analysis_result.dart';
import 'ai/garment_analysis_validator.dart';
import 'ai/garment_image_processing.dart';
import 'ai/normalization/garment_value_normalizer.dart';
import 'ai/openai_garment_vision_analyzer.dart';
import 'ai/analysis_foundations.dart';
import 'conversation/scan_conversation.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final picker = ImagePicker();
  late final OpenAiGarmentVisionAnalyzer scanner;
  final wardrobe = WardrobeController();

  final name = TextEditingController();
  final brand = TextEditingController();
  final color = TextEditingController();
  final material = TextEditingController();

  String category = 'Hauts';
  String season = 'Toute saison';
  String? imagePath;
  final List<String> sessionImagePaths = [];
  GarmentAnalysisResult? result;
  ScanConversationDecision? conversation;
  bool importing = false;
  bool analyzing = false;
  bool saving = false;
  bool imageOwnedByGarment = false;
  String scanStep = '';
  String? enrichmentWarning;
  final scanTimings = <String, Duration>{};

  bool get busy => importing || analyzing || saving;

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

  static const colors = [
    'Noir', 'Blanc', 'Gris', 'Bleu marine', 'Bleu', 'Beige', 'Marron',
    'Camel', 'Vert', 'Kaki', 'Rouge', 'Bordeaux', 'Rose', 'Violet',
    'Jaune', 'Orange',
  ];
  static const materials = [
    'Coton', 'Laine', 'Lin', 'Soie', 'Denim', 'Cuir', 'Textile',
    'Synthétique',
  ];

  @override
  void initState() {
    super.initState();
    scanner = OpenAiGarmentVisionAnalyzer(
      apiKeyStorage: const ApiKeyStorage(),
    );
  }

  @override
  void dispose() {
    for (final path in sessionImagePaths) {
      if (!imageOwnedByGarment) {
        _removeBestEffort(path);
      }
    }
    name.dispose();
    brand.dispose();
    color.dispose();
    material.dispose();
    scanner.close();
    wardrobe.dispose();
    super.dispose();
  }

  Future<void> pick(ImageSource source) async {
    if (busy) return;
    setState(() => importing = true);
    String? persisted;
    try {
      final selected = await picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1800,
      );
      if (!mounted || selected == null) return;

      persisted = await ImageStorageService.persist(selected.path);
      if (!mounted) {
        _removeBestEffort(persisted);
        return;
      }

      final isAdditional = result != null;
      final previousPath = imagePath;
      setState(() {
        imagePath = persisted;
        sessionImagePaths.add(persisted!);
        if (!isAdditional) {
          result = null;
          conversation = null;
        }
      });
      persisted = null; // The screen now owns this copy.
      if (!isAdditional && previousPath != null) {
        sessionImagePaths.remove(previousPath);
        _removeBestEffort(previousPath);
      }
    } catch (_) {
      _removeBestEffort(persisted);
      if (!mounted) return;
      _toast('Impossible d’importer cette photo. Réessaie avec une autre.');
    } finally {
      if (mounted) setState(() => importing = false);
    }

    // Toute photo ajoutée enrichit automatiquement l'analyse cumulée. `busy`
    // empêche deux appels concurrents.
    if (mounted && imagePath != null) await analyze();
  }

  Future<void> chooseSource() async {
    if (busy) return;
    if (imagePath != null && conversation?.requestedPhoto == null) {
      final replace = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Remplacer la photo ?'),
              content: const Text(
                'La photo actuelle sera conservée si le nouvel import échoue.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Remplacer'),
                ),
              ],
            ),
      );
      if (!mounted || replace != true) return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder:
          (_) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Prendre une photo'),
                  subtitle: const Text('Idéalement sur un fond uni'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choisir dans la galerie'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
    );
    if (!mounted || source == null) return;
    await pick(source);
  }

  Future<void> analyze() async {
    if (busy || imagePath == null) return;
    final initialName = name.text;
    final initialBrand = brand.text;
    final initialColor = color.text;
    final initialMaterial = material.text;
    final initialCategory = category;
    final initialSeason = season;
    var enrichmentStarted = false;
    setState(() { analyzing = true; scanStep = 'Préparation de la photo…'; enrichmentWarning = null; });

    try {
      final validation = await const GarmentImageValidator().validateFile(
        imagePath!,
      );
      if (!validation.isValid) {
        throw GarmentAnalysisException(
          GarmentAnalysisError.rejectedImage,
          validation.rejectionReason ?? 'Cette photo ne peut pas être analysée.',
        );
      }
      final bytes = await File(imagePath!).readAsBytes();
      final previousBytes = <Uint8List>[];
      for (final path in sessionImagePaths.where((path) => path != imagePath)) {
        previousBytes.add(await File(path).readAsBytes());
      }
      final request = GarmentAnalysisRequest(
          imageBytes: bytes,
          mimeType:
              GarmentImageValidator.detectMimeType(bytes) ?? 'image/jpeg',
          allowedCategories: categories,
          allowedColors: colors,
          allowedMaterials: materials,
          allowedSeasons: seasons,
          existingValues: {
            if (name.text.trim().isNotEmpty) 'name': name.text.trim(),
            if (brand.text.trim().isNotEmpty) 'brand': brand.text.trim(),
          },
          previousImageBytes: previousBytes,
          previousAnalysis: result?.toJson(),
        );
      setState(() => scanStep = 'Identification du vêtement…');
      final raw = await scanner.analyzeQuick(request);
      final parsingWatch = Stopwatch()..start();
      final validated = const GarmentAnalysisNormalizer().normalize(GarmentAnalysisValidator(
        categoryNormalizer: const GarmentValueNormalizer(categories),
        colorNormalizer: const GarmentValueNormalizer(colors),
        materialNormalizer: const GarmentValueNormalizer(materials),
        seasonNormalizer: const GarmentValueNormalizer(seasons),
      ).validate(raw).analysis);
      if (!validated.isUsableImage) {
        throw GarmentAnalysisException(
          GarmentAnalysisError.rejectedImage,
          validated.rejectionReason ??
              'La photo ne permet pas d’identifier clairement un vêtement.',
        );
      }
      parsingWatch.stop();
      final mergeWatch = Stopwatch()..start();
      final mapped = const GarmentAnalysisMapper(
        categories: categories,
        colors: colors,
        materials: materials,
        seasons: seasons,
      ).map(
        validated,
        current: GarmentFormValues(
          name: name.text,
          category: '',
          color: color.text,
          material: material.text,
          season: '',
          brand: brand.text,
        ),
      );
      if (!mounted) return;
      final decision = const ScanConversationPolicy().evaluate(validated);
      setState(() {
        result = validated;
        conversation = decision;
        if (name.text == initialName || name.text.trim().isEmpty) name.text = mapped.name;
        if (brand.text == initialBrand || brand.text.trim().isEmpty) brand.text = mapped.brand;
        if (color.text == initialColor || color.text.trim().isEmpty) color.text = mapped.color;
        if (material.text == initialMaterial || material.text.trim().isEmpty) material.text = mapped.material;
        if (mapped.category.isNotEmpty && category == initialCategory) category = mapped.category;
        if (mapped.season.isNotEmpty && season == initialSeason) season = mapped.season;
      });
      mergeWatch.stop();
      _recordTimings('quick', parsingWatch.elapsed, mergeWatch.elapsed);
      if (!mounted) return;
      setState(() => scanStep = 'Analyse stylistique en cours…');
      enrichmentStarted = true;
      unawaited(_runEnrichment(request, validated, initialName, initialBrand, initialColor, initialMaterial, initialCategory, initialSeason));
    } on GarmentAnalysisException catch (error) {
      if (!mounted) return;
      _toast(_friendlyAnalysisError(error));
    } catch (_) {
      if (mounted) _toast('Analyse impossible pour le moment. Réessaie.');
    } finally {
      if (mounted && !enrichmentStarted) setState(() => analyzing = false);
    }
  }


  Future<void> _runEnrichment(
    GarmentAnalysisRequest request,
    GarmentAnalysisResult quickResult,
    String initialName,
    String initialBrand,
    String initialColor,
    String initialMaterial,
    String initialCategory,
    String initialSeason,
  ) async {
    try {
      final raw = await scanner.enrich(request.copyWith(phase: GarmentAnalysisPhase.enrichment));
      final parsingWatch = Stopwatch()..start();
      final enriched = const GarmentAnalysisNormalizer().normalize(GarmentAnalysisValidator(
        categoryNormalizer: const GarmentValueNormalizer(categories),
        colorNormalizer: const GarmentValueNormalizer(colors),
        materialNormalizer: const GarmentValueNormalizer(materials),
        seasonNormalizer: const GarmentValueNormalizer(seasons),
      ).validate(raw).analysis);
      parsingWatch.stop();
      if (!enriched.isUsableImage) throw GarmentAnalysisException(GarmentAnalysisError.rejectedImage, enriched.rejectionReason ?? 'Analyse avancée indisponible.');
      final mergeWatch = Stopwatch()..start();
      final merged = _mergeAnalysis(quickResult, enriched);
      final mapped = const GarmentAnalysisMapper(categories: categories, colors: colors, materials: materials, seasons: seasons).map(
        merged,
        current: GarmentFormValues(name: name.text, category: category, color: color.text, material: material.text, season: season, brand: brand.text),
      );
      if (!mounted) return;
      final decision = const ScanConversationPolicy().evaluate(merged);
      setState(() {
        result = merged;
        conversation = decision;
        enrichmentWarning = null;
        if (name.text == initialName || name.text.trim().isEmpty) name.text = mapped.name;
        if (brand.text == initialBrand || brand.text.trim().isEmpty) brand.text = mapped.brand;
        if (color.text == initialColor || color.text.trim().isEmpty) color.text = mapped.color;
        if (material.text == initialMaterial || material.text.trim().isEmpty) material.text = mapped.material;
        if (mapped.category.isNotEmpty && category == initialCategory) category = mapped.category;
        if (mapped.season.isNotEmpty && season == initialSeason) season = mapped.season;
        scanStep = 'Analyse complète';
      });
      mergeWatch.stop();
      _recordTimings('enrichment', parsingWatch.elapsed, mergeWatch.elapsed);
      if (decision.canFinishAutomatically) await _openFullForm();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        enrichmentWarning = 'Analyse avancée indisponible, vous pouvez compléter la fiche.';
        scanStep = 'Vêtement identifié';
      });
    } finally {
      if (mounted) setState(() => analyzing = false);
    }
  }

  GarmentAnalysisResult _mergeAnalysis(GarmentAnalysisResult quick, GarmentAnalysisResult enriched) => enriched.copyWith(
    suggestedName: enriched.suggestedName ?? quick.suggestedName,
    category: enriched.category ?? quick.category,
    preciseType: enriched.preciseType ?? quick.preciseType,
    primaryColor: enriched.primaryColor ?? quick.primaryColor,
    visibleBrand: enriched.visibleBrand ?? quick.visibleBrand,
    globalConfidence: enriched.globalConfidence == 0 ? quick.globalConfidence : enriched.globalConfidence,
    fieldConfidences: {...quick.fieldConfidences, ...enriched.fieldConfidences},
    warnings: {...quick.warnings, ...enriched.warnings}.toList(growable: false),
  );

  void _recordTimings(String phase, Duration parsing, Duration fusion) {
    final timings = scanner.lastTimings;
    setState(() {
      scanTimings['$phase.imagePreparation'] = timings?.imagePreparation ?? Duration.zero;
      scanTimings['$phase.compression'] = timings?.compression ?? Duration.zero;
      scanTimings['$phase.aiCall'] = timings?.aiCall ?? Duration.zero;
      scanTimings['$phase.parsing'] = (timings?.parsing ?? Duration.zero) + parsing;
      scanTimings['$phase.fusion'] = fusion;
      scanTimings['$phase.total'] = (timings?.total ?? Duration.zero) + parsing + fusion;
    });
  }

  String _friendlyAnalysisError(GarmentAnalysisException exception) => switch (
    exception.error
  ) {
    GarmentAnalysisError.missingApiKey =>
      'Configure ta clé OpenAI dans le profil avant de lancer l’analyse.',
    GarmentAnalysisError.invalidApiKey =>
      'La clé configurée n’est pas valide. Vérifie-la dans le profil.',
    GarmentAnalysisError.quotaExceeded =>
      'Le service d’analyse est momentanément indisponible. Réessaie plus tard.',
    GarmentAnalysisError.network =>
      'Aucune connexion disponible. Vérifie ton réseau puis réessaie.',
    GarmentAnalysisError.timeout =>
      'L’analyse prend trop de temps. Réessaie dans quelques instants.',
    GarmentAnalysisError.rejectedImage ||
    GarmentAnalysisError.missingImage ||
    GarmentAnalysisError.unsupportedFormat => exception.message,
    _ => 'Analyse impossible pour le moment. Réessaie.',
  };

  Future<void> _openFullForm() async {
    if (busy) return;
    if (imagePath == null) {
      _toast('Ajoute d’abord une photo.');
      return;
    }

    setState(() => saving = true);
    final now = DateTime.now();
    final composition = _formattedComposition(result?.compositions ?? const []);
    final normalizedType = GarmentNormalizer.normalizeType(
      name: name.text,
      category: category,
      subcategory: result?.preciseType,
      preciseType: result?.preciseType,
    );
    final thermalProfile = const ThermalProfileCalculator().calculate(
      ThermalProfileInput(
        category: normalizedType.category ?? category,
        subcategory: normalizedType.subcategory,
        material: material.text,
        composition: composition,
        lining: result?.compositions.any((value) => value.section == 'lining') == true ? 'doublure détectée' : null,
        detectedFeatures: [
          if (result?.styleSummary != null) result!.styleSummary!,
          ...?result?.fieldMetadata?.keys,
        ],
      ),
      calculatedAt: now,
    );
    final garment = Garment(
      id: const Uuid().v4(),
      name: name.text.trim().isEmpty ? 'Vêtement à identifier' : name.text.trim(),
      category: normalizedType.category ?? category,
      brand: brand.text.trim().isEmpty ? null : brand.text.trim(),
      color: color.text.trim().isEmpty ? null : color.text.trim(),
      material: material.text.trim().isEmpty ? null : material.text.trim(),
      sousCategorie: normalizedType.subcategory,
      typePrecis: normalizedType.preciseType,
      descriptionIA: result?.suggestedName,
      couleurPrincipale: color.text.trim().isEmpty ? null : color.text.trim(),
      matierePrincipale:
          material.text.trim().isEmpty ? null : material.text.trim(),
      matieresSecondaires: result?.compositions
          .where((value) => value.section == 'main')
          .map((value) => value.material)
          .skip(1)
          .toList(growable: false),
      composition: composition,
      saisons: switch (result?.season) {
        final value? => [value],
        null => null,
      },
      compatiblePluie: thermalProfile.rainCompatibility.name != 'none',
      compatibleChaleur: thermalProfile.breathability.name == 'high',
      layerType: switch (thermalProfile.primaryRole.name) {
        'base' => 'Couche de base',
        'outer' => 'Couche extérieure',
        _ => 'Couche intermédiaire',
      },
      thermalProfile: thermalProfile,
      confianceGlobale: result?.globalConfidence,
      avertissementsIA: result?.warnings,
      pointsForts: result?.styleStrengths,
      pointsFaibles: result?.styleWeaknesses,
      conseils: result?.styleAdvice,
      verdict: result?.styleVerdict,
      couleursCompatibles: result?.compatibleColors,
      couleursMoinsAdaptees: result?.lessSuitableColors,
      basCompatibles: result?.compatibleBottoms,
      chaussuresCompatibles: result?.compatibleShoes,
      explicationPolyvalence: result?.versatilityExplanation,
      occasions: _suggestUses(result?.idealOccasions ?? const []),
      occasionsDeconseillees: result?.discouragedOccasions,
      limitesAnalyse: result?.analysisLimitations,
      notes: switch (result) {
        final analysis? =>
          'Suggestions IA vérifiées · confiance ${((analysis.overallConfidence ?? analysis.globalConfidence) * 100).round()} %.',
        null => 'Ajout manuel depuis le scanner.',
      },
      photos: [
        for (var index = 0; index < sessionImagePaths.length; index++)
          GarmentPhoto(
            id: const Uuid().v4(),
            path: sessionImagePaths[index],
            type: index == 0 ? GarmentPhotoType.primary : GarmentPhotoType.other,
            createdAt: now,
          ),
      ],
      lastAnalyzedAt: result == null ? null : now,
      aiAnalysisVersion: result == null
          ? null
          : 'scanner-v1:${OpenAiGarmentVisionAnalyzer.defaultModel}',
      currentAnalysis: result == null
          ? null
          : GarmentAnalysisSnapshot(
              version: 'scanner-v1:${OpenAiGarmentVisionAnalyzer.defaultModel}',
              analyzedAt: now,
              values: result!.toJson().cast<String, Object?>(),
            ),
      createdAt: now,
      updatedAt: now,
    ).withCurrentStyleAnalysis(calculatedAt: now);

    try {
      if (!mounted) return;
      setState(() => saving = false);
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => GarmentFormScreen(
            controller: wardrobe,
            garment: garment,
            isDraft: true,
          ),
        ),
      );
      if (saved == true && mounted) {
        imageOwnedByGarment = true;
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (!mounted) return;
      _toast('Enregistrement impossible. Vérifie la fiche et réessaie.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String? _formattedComposition(List<TextileComposition> values) {
    if (values.isEmpty) return null;
    const labels = {'main': 'Tissu principal', 'lining': 'Doublure', 'padding': 'Rembourrage'};
    final sections = <String, List<TextileComposition>>{};
    for (final value in values) {
      (sections[value.section] ??= []).add(value);
    }
    return sections.entries.map((entry) => '${labels[entry.key] ?? entry.key} : ${entry.value.map((value) => '${value.material}${value.percentage == null ? '' : ' ${value.percentage!.toStringAsFixed(value.percentage! % 1 == 0 ? 0 : 1)} %'}').join(', ')}').join('\n');
  }

  List<String> _suggestUses(List<String> suggestions) {
    const available = [
      'Quotidien', 'Travail', 'Sport', 'Voyage', 'Maison', 'Soirée',
      'Randonnée', 'Vacances',
    ];
    String normalize(String value) => value
        .toLowerCase()
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[àâä]'), 'a');

    return suggestions.map((suggestion) {
      final normalized = normalize(suggestion);
      return available.cast<String?>().firstWhere(
            (value) => normalized.contains(normalize(value!)),
            orElse: () => null,
          ) ??
          suggestion;
    }).toSet().toList();
  }

  void _removeBestEffort(String? path) {
    unawaited(ImageStorageService.remove(path).catchError((_) {}));
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scanner une pièce'),
          actions: [
            IconButton(
              tooltip: 'Conseils photo',
              onPressed:
                  () => showDialog<void>(
                    context: context,
                    builder:
                        (_) => const AlertDialog(
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
              importing: importing,
              onTap: busy ? null : chooseSource,
            ),
            const SizedBox(height: 18),
            if (imagePath == null) ...[
              const _IntroCard(),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy ? null : chooseSource,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Prendre ou choisir une photo'),
              ),
            ] else ...[
              if (conversation case final decision?) ...[
                _ConversationCard(
                  decision: decision,
                  photoCount: sessionImagePaths.length,
                ),
                const SizedBox(height: 14),
              ],
              if (result case final analysis?) ...[
                _DetectedDataCard(analysis: analysis, analyzing: analyzing, step: scanStep, warning: enrichmentWarning),
                const SizedBox(height: 14),
              ],
              if (result?.reliabilitySummary.hasDetails == true) ...[
                _ExpertReliabilityCard(
                  summary: result?.reliabilitySummary,
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : analyze,
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(result == null ? 'Analyser et compléter' : 'Mettre à jour l’analyse'),
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
                      onPressed: busy ? null : chooseSource,
                      icon: const Icon(Icons.photo_camera_back_outlined),
                      label: Text(conversation?.requestedPhoto == null ? 'Changer' : 'Ajouter la photo'),
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
              if (result != null &&
                  conversation?.canFinishAutomatically == false) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: busy ? null : _openFullForm,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Ouvrir et compléter la fiche'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DetectedDataCard extends StatelessWidget {
  final GarmentAnalysisResult analysis;
  final bool analyzing;
  final String step;
  final String? warning;
  const _DetectedDataCard({required this.analysis, this.analyzing = false, this.step = '', this.warning});

  @override
  Widget build(BuildContext context) {
    final type = GarmentNormalizer.normalizeType(
      name: analysis.suggestedName,
      category: analysis.category,
      subcategory: analysis.preciseType,
      preciseType: analysis.preciseType,
    );
    final composition = analysis.compositions.map((item) {
      final percentage = item.percentage == null ? '' : ' ${item.percentage!.toStringAsFixed(item.percentage! % 1 == 0 ? 0 : 1)} %';
      return '${item.material}$percentage';
    }).join(', ');
    final rows = <(String, String?)>[
      ('Nom', analysis.suggestedName),
      ('Marque', analysis.visibleBrand),
      ('Catégorie', type.category),
      ('Sous-catégorie', type.subcategory),
      ('Couleur', analysis.primaryColor),
      ('Matière', analysis.material),
      ('Composition', composition.isEmpty ? null : composition),
      ('Style', analysis.styleSummary),
      ('Occasions', analysis.idealOccasions.join(', ')),
      ('Saison / thermique', analysis.season),
    ].where((row) => row.$2?.trim().isNotEmpty == true);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(step.isEmpty ? 'Fiche détectée' : step, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('${row.$1} · ${row.$2}'),
              ),
            if (analyzing) ...const [
              Divider(height: 20),
              Text('Encore en analyse : matière · composition · StyleAnalysis · ThermalProfile · occasions'),
            ],
            if (warning != null) ...[
              const Divider(height: 20),
              Text(warning!, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w800)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpertReliabilityCard extends StatelessWidget {
  final ReliabilitySummary? summary;

  const _ExpertReliabilityCard({this.summary});

  @override
  Widget build(BuildContext context) {
    final details = summary;
    if (details == null || !details.hasDetails) return const SizedBox.shrink();
    final overall = details.overallConfidence;
    final fields = <String>{
      ...details.fieldConfidences.keys,
      ...details.fieldStatuses.keys,
      ...details.fieldSources.keys,
      ...details.fieldExplanations.keys,
    }.toList(growable: false)..sort();
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.fact_check_outlined, color: AppTheme.gold),
        title: const Text('Fiabilité · mode Expert'),
        subtitle: overall == null
            ? null
            : Text(
                'Confiance globale ${(overall * 100).round()} %',
              ),
        children: fields.map((field) {
          final confidence = details.fieldConfidences[field];
          final status = details.fieldStatuses[field];
          final source = details.fieldSources[field];
          final explanation = details.fieldExplanations[field];
          final qualifiers = [
            if (status != null) status,
            if (source != null) source,
            if (confidence != null) '${(confidence * 100).round()} %',
          ];
          return ListTile(
            dense: true,
            title: Text(field),
            subtitle: explanation == null ? null : Text(explanation),
            trailing: qualifiers.isEmpty ? null : Text(qualifiers.join(' · ')),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final ScanConversationDecision decision;
  final int photoCount;

  const _ConversationCard({
    required this.decision,
    required this.photoCount,
  });

  @override
  Widget build(BuildContext context) {
    final request = decision.requestedPhoto;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.forum_outlined, color: AppTheme.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    photoCount == 1
                        ? 'Première analyse'
                        : 'Analyse mise à jour · $photoCount photos',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...decision.progress.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        item.confirmed
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                        size: 19,
                        color: item.confirmed ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text('${item.label}${item.confirmed ? '' : ' · incertain'}'),
                    ],
                  ),
                )),
            if (request != null) ...[
              const Divider(height: 24),
              Text(request.reason),
              const SizedBox(height: 8),
              Text(
                request.instruction,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoArea extends StatelessWidget {
  final String? imagePath;
  final bool analyzing;
  final bool importing;
  final VoidCallback? onTap;

  const _PhotoArea({
    required this.imagePath,
    required this.analyzing,
    required this.importing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: analyzing || importing ? null : onTap,
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
          if (importing)
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
                      'Import de la photo…',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
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
                      'Étape actuelle : analyse IA…',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Déjà détecté : photo importée\nRecherche : catégorie · couleur · matière · saison\nTu pourras corriger chaque donnée avant l’enregistrement.',
                      textAlign: TextAlign.center,
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
                    'Scanner intelligent',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'L’IA propose une catégorie, une couleur, une matière et une saison. Tu gardes le contrôle et peux tout corriger avant l’enregistrement.',
            ),
          ],
        ),
      ),
    );
  }
}
