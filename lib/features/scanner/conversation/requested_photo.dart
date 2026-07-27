enum RequestedPhotoType {
  compositionLabel,
  back,
  fabricCloseUp,
  collar,
  cuffs,
  lining,
  buttons,
  zipper,
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
    'logo' => logo,
    _ => other,
  };
}

class RequestedPhoto {
  final RequestedPhotoType type;
  final String instruction;
  final String reason;
  final List<String> targetFields;

  const RequestedPhoto({
    required this.type,
    required this.instruction,
    required this.reason,
    this.targetFields = const [],
  });
}
