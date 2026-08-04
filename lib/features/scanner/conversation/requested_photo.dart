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

  const RequestedPhoto({
    required this.type,
    required this.instruction,
    required this.reason,
    this.targetFields = const [],
  });
}
