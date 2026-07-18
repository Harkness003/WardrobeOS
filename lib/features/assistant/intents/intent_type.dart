enum AssistantIntentType {
  dailyOutfit('Tenue quotidienne'),
  weatherOutfit('Tenue selon la météo'),
  eventOutfit('Tenue pour un événement'),
  wardrobeAnalysis('Analyse du dressing'),
  forgottenGarments('Vêtements oubliés'),
  shoppingAdvice("Conseil d'achat"),
  generalQuestion('Question générale');

  const AssistantIntentType(this.label);

  final String label;
}
