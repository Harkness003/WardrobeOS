class OutfitItem {
  final String outfitId;
  final String garmentId;

  const OutfitItem({required this.outfitId, required this.garmentId});

  Map<String, Object?> toMap() => {
    'outfit_id': outfitId,
    'garment_id': garmentId,
  };

  factory OutfitItem.fromMap(Map<String, Object?> map) {
    final outfitId = map['outfit_id'];
    final garmentId = map['garment_id'];
    return OutfitItem(
      outfitId: outfitId is String ? outfitId : '',
      garmentId: garmentId is String ? garmentId : '',
    );
  }
}
