class OutfitItem {
  final String outfitId;
  final String garmentId;

  const OutfitItem({required this.outfitId, required this.garmentId});

  Map<String, Object?> toMap() => {
    'outfit_id': outfitId,
    'garment_id': garmentId,
  };

  factory OutfitItem.fromMap(Map<String, Object?> map) => OutfitItem(
    outfitId: map['outfit_id'] as String,
    garmentId: map['garment_id'] as String,
  );
}
