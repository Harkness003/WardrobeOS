/// Coefficients de compatibilité utilisés par tout le moteur.
///
/// Leur somme vaut 100 afin que le score final soit directement exprimé en
/// pourcentage. Une configuration différente peut être injectée sans modifier
/// les règles métier.
class RecommendationWeights {
  final double style;
  final double formality;
  final double season;
  final double temperature;
  final double color;
  final double material;
  final double layering;
  final double occasion;

  const RecommendationWeights({
    this.style = 18,
    this.formality = 14,
    this.season = 12,
    this.temperature = 14,
    this.color = 16,
    this.material = 8,
    this.layering = 8,
    this.occasion = 10,
  }) : assert(style >= 0),
       assert(formality >= 0),
       assert(season >= 0),
       assert(temperature >= 0),
       assert(color >= 0),
       assert(material >= 0),
       assert(layering >= 0),
       assert(occasion >= 0);

  double get total =>
      style +
      formality +
      season +
      temperature +
      color +
      material +
      layering +
      occasion;
}
