enum RequestedPhotoType {
  compositionLabel,
  back,
  fabricCloseUp,
  collar,
  cuffs,
  lining,
  buttons,
  zipper,
  sole,
  interior,
  wear,
  padding,
  logo,
  other;

  static RequestedPhotoType fromWireValue(String? value) => switch (value) {
    'composition_label' => compositionLabel,
    'back' => back,
    'fabric_close_up' => fabricCloseUp,
    'collar' => collar,
    'cuffs' => cuffs,
    'lining' => lining,
    'buttons' => buttons,
    'zipper' => zipper,
    'sole' => sole,
    'interior' => interior,
    'wear' => wear,
    'padding' => padding,
    'logo' => logo,
    _ => other,
  };
}

class RequestedPhoto {
  final RequestedPhotoType type;
  final String instruction;
  final String reason;
  final List<String> targetFields;

  /// Product features that will actually consume the requested evidence.
  /// An empty list means that the photo has no business value and must not be
  /// requested by the pipeline.
  List<String> get consumers => targetFields.expand((field) => switch (field) {
        'material' || 'lining' || 'padding' => const ['fiche matière', 'profil thermique'],
        'season' => const ['saisons', 'profil thermique'],
        'wear' => const ['état de la fiche'],
        'preciseType' || 'collar' || 'cuffs' || 'backCut' || 'texture' => const ['sous-catégorie', 'conseils de style'],
        'visibleBrand' => const ['marque de la fiche'],
        _ => const <String>[],
      }).toSet().toList(growable: false);

  const RequestedPhoto({
    required this.type,
    required this.instruction,
    required this.reason,
    this.targetFields = const [],
  });
}
