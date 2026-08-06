# RC7.7 — Modèle thermique physique

## A. Avant

`ThermalProfile` stockait quatre bornes (`standaloneMinC`, `standaloneMaxC`,
`layeredMinC`, `layeredMaxC`) et une contribution exprimée en degrés. Le
calculateur attribuait une plage à une pièce par règles de nom. Le
`RecommendationEngine` jugeait chaque pièce contre cette plage, puis
`OutfitGenerationEngine` reconstruisait une autre plage pour la tenue. Le
formulaire permettait en outre de modifier les températures. La décision était
donc répartie et décrivait implicitement une « température du vêtement ».

## B. Après

`ThermalProfile` v3 est exclusivement descriptif. `ThermalProfileCalculator`
combine catégorie et sous-catégorie (construction de base), puis matières,
épaisseur, doublure, coupe, construction, longueur, ouverture et indices du
scanner/IA (raffinements). Une matière ne remplace jamais la classification de
la pièce : par exemple, la laine augmente l'isolation de la construction
identifiée, le lin augmente la respirabilité, un textile synthétique sèche
vite, et une membrane renforce vent/pluie.

`OutfitGenerationEngine.evaluateThermal` est l'unique décision thermique. Il
additionne l'isolation des couches réellement présentes, agrège leur
respirabilité et inspecte uniquement la couche extérieure pour le vent et la
pluie. La cible dépend de la température ressentie, de l'activité et du moment
de la journée. L'humidité chaude pénalise une faible respirabilité. Les verdicts
sont : idéal, trop chaud, trop léger, pluie insuffisante, couche extérieure
manquante et isolation excessive. Les raisons déterministes sont produites par
ce moteur, jamais par le LLM.

## C. Propriétés retenues et consommateurs

| Propriété | Consommateur métier |
|---|---|
| isolation, épaisseur | isolation cumulée et synthèse de fiche |
| respirabilité | confort par forte chaleur/humidité |
| protection vent | validation de la couche extérieure par vent |
| protection pluie | validation de la couche extérieure sous pluie |
| résistance humidité, vitesse de séchage | caractérisation matière, prête pour durée d'exposition RC7.8 |
| rôle et compatibilité de couche | ordre/superposition réelle |
| couvrance, poids, ouverture | estimation physique de construction et synthèse ; raffinements de cible futurs |

## D. Historique isolé

Les quatre plages standalone/layered, le niveau thermique redondant et la
contribution en degrés ont disparu du modèle sérialisé, des formulaires et du
runtime. `ThermalProfile.decode` est le seul endroit qui lit encore
`thermalContributionC` afin de migrer un JSON v1/v2 vers une isolation v3 ; la
ré-émission ne contient aucune température. Les corrections de recommandation
mini/maxi ont également été retirées.

## E. Flux canonique

```text
Scanner (catégorie, construction, matières, indices IA)
  ↓ ThermalProfileCalculator
ThermalProfile v3 (propriétés physiques persistées)
  ↓
OutfitGenerationEngine (combinaison + météo + activité + moment)
  ↓ raisons et verdict déterministes
Daily (réutilise le même OutfitGenerationEngine)
  ↓ proposition canonique
WardrobeGPT / outils assistant (relaient la proposition ; aucune explication thermique LLM)
```

`RecommendationEngine` demeure le pré-classeur existant pour style, formalité,
rotation et compatibilité des couches. Il ne décide plus qu'une pièce isolée est
adaptée à une température.

## F. Scénarios de validation métier

* **T-shirt seul, chaleur** : isolation faible, respirabilité élevée ; adapté.
* **T-shirt seul, froid** : trop léger ; demande une couche isolante.
* **T-shirt + pull** : le pull augmente explicitement l'isolation cumulée.
* **Pull + trench, vent/pluie** : isolation du pull, protection extérieure du trench.
* **Chemise + blazer, douceur** : faible isolation cumulée, superposition valide ; pluie non couverte.
* **Doudoune** : très isolante ; hiver froid adapté, forte chaleur = isolation excessive.
* **Manteau laine** : isolation/couvrance fortes et coupe-vent, pluie seulement limitée.
* **Imperméable** : pluie couverte mais isolation très faible ; une couche isolante reste requise au froid.
* **Vent** : absence d'outer protecteur = `missingOuterLayer`.
* **Forte chaleur** : accumulation isolante = `tooWarm`/`excessiveInsulation`.
* **Été humide** : faible respirabilité cumulée explicitement pénalisée.
* **Hiver sec** : priorité à l'isolation cumulée, sans exigence pluie.

## G. Limites avant RC7.8

L'activité reste un indice contextuel simple et Daily utilise une valeur neutre
faute de signal capteur. Le moment distingue jour/soir sans prévision horaire.
La durée/intensité de pluie, l'exposition au vent, la thermorégulation
personnelle et les zones corporelles ne sont pas encore modélisées. La
résistance à l'humidité, le séchage, la couvrance, le poids et l'ouverture sont
persistés mais seuls les premiers critères indispensables participent
pleinement au score ; leur calibration massive devra s'appuyer sur les données
d'import RC7.8 plutôt que sur de nouvelles plages de température.
