# RC5 — Bibliothèque des styles

## Audit et architecture finale

`StyleAnalysis` reste l’unique valeur stylistique d’un vêtement : il conserve séparément les suggestions du classifieur et les corrections utilisateur. `StyleTaxonomy.entries` complète le référentiel canonique existant avec les métadonnées éditoriales, sans créer de nouveaux identifiants. `StyleCatalog`, implémentation de `StyleRepository`, fusionne à la lecture les entrées système immuables et les styles personnels persistés séparément dans le stockage sécurisé.

Le flux est donc : **StyleTaxonomy (système) + PersonalStyle (utilisateur) → StyleRepository/StyleCatalog → bibliothèque, aide contextuelle et sélecteurs → identifiants de StyleAnalysis**. Le parseur d’intentions résout lui aussi les noms et synonymes vers ces identifiants canoniques. Le moteur de génération de tenues n’a pas été modifié.

## Interface

La bibliothèque, accessible depuis Profil, recherche sans distinction de casse ou d’accents dans le nom, les synonymes, la définition, la description et les caractéristiques. La fiche détail résout les relations en noms lisibles. Les styles système n’offrent aucune commande de mutation ; les styles personnels peuvent être créés, modifiés et supprimés après confirmation.

Sur une fiche vêtement, les identifiants du `StyleAnalysis` sont résolus par le repository. Un appui ou un appui long ouvre définition, exemples et caractéristiques, puis permet d’accéder à la fiche complète. L’éditeur met à jour uniquement les champs `user*` de `StyleAnalysis` et conserve suggestion, preuves, versions, empreinte et date de calcul.

## IA

Quand une clé IA est configurée, le formulaire personnel affiche « Enrichir avec l’IA ». Le service produit une proposition JSON affichée avant toute mutation. Refuser ne change aucun champ ; accepter remplit le brouillon, qui doit encore être enregistré explicitement.

## Limites avant RC6

- améliorer l’édition visuelle des listes éditoriales enrichies (couleurs, matières et occasions) ;
- ajouter tri, regroupements et favoris dans une bibliothèque volumineuse ;
- afficher un libellé canonique dans tous les anciens contrôles multi-sélection tout en conservant l’identifiant en valeur ;
- prévoir une stratégie explicite de remplacement avant suppression d’un style personnel encore référencé par des vêtements ;
- étendre la couverture widget des dialogues IA et de correction de vêtement avec les dépendances d’application injectées.
