# RC2.1 — Audit du moteur de tenues

## Génération

| Consommateur | Entrée | Générateur | Sortie |
| --- | --- | --- | --- |
| Tenues | Dressing courant | `OutfitGenerationEngine` | `OutfitGenerationProposal` |
| Daily Brief | Dressing, météo et préférences | `OutfitGenerationEngine` | `OutfitGenerationProposal` |
| Agenda | Dressing, événement, météo et préférences | `OutfitGenerationEngine` | `OutfitGenerationProposal`, puis tenue planifiée persistée |
| WardrobeGPT | Intention, dressing et météo | `OutfitGenerationEngine` | `OutfitGenerationProposal` fourni au LLM comme fait immuable |

`RecommendationEngine` reste un calculateur interne injecté dans
`OutfitGenerationEngine`. Ce n'est pas un point d'entrée de composition pour les
écrans. La superposition, le classement, la rotation et la déduplication restent
dans le moteur canonique.

## Transformations

- Daily Brief conserve directement la liste de propositions, sans DTO local.
- WardrobeGPT sérialise les propositions dans son prompt uniquement pour les
  expliquer ; il lui est explicitement interdit de sélectionner ou remplacer une
  pièce.
- Agenda persiste l'`Outfit` contenu dans la proposition pour conserver le cycle
  de vie d'une planification. L'écran reconstruit seulement l'enveloppe de
  présentation depuis la tenue et ses raisons persistées.
- Tenues persiste directement l'`Outfit` de la proposition lors de l'action
  d'enregistrement.

## Présentation

`OutfitProposalCard` est l'unique présentation des propositions générées dans
Daily Brief, Agenda, WardrobeGPT et Tenues. Les cartes locales du Daily Brief et
le détail textuel de l'Agenda ont été retirés.

## Éléments historiques supprimés

- `OutfitRecommendationEngine` et ses DTO `OutfitCandidate`,
  `OutfitRecommendationRequest` et `OutfitRecommendationResult` ;
- la façade `OutfitEngine` ;
- les tests dédiés à l'adaptateur supprimé.

## Limites avant RC3

- Les tenues déjà enregistrées et les planifications restent des modèles de
  persistance (`Outfit` et `PlannedOutfit`), pas des propositions générées.
- Agenda ne persiste pas séparément la valeur numérique du score ; la carte
  utilise la confiance globale enregistrée dans l'`Outfit`.
- L'action d'enregistrement est disponible dans Tenues. Les autres surfaces
  n'exposent une action que lorsque leur parcours possède déjà une commande de
  sauvegarde ou de confirmation.
