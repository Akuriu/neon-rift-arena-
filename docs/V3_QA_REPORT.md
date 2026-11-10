# Validation NEON RIFT ARENA V3.0.0

Moteur Godot 4.6.3 Standard. Tests de référence sur une copie V2 isolée. Les binaires de cette livraison proviennent de la révision de jeu `aba6f37`. Les changements suivants concernent la documentation et les assertions de test audio.

## Résultats

| Vérification | Résultat exécuté |
|---|---|
| Baseline V2 | 222 assertions passées, dont les 51 contrôles initiaux |
| V3, `python3 tools/run_tests.py --suite all` | 303 assertions passées, retour 0, aucun FAIL ni erreur GDScript |
| Survie 20, Cryo Foundry | Victoire, 164 robots, 599 tirs, 574 touches |
| Survie 10, Skyline Depot | Victoire, 65 robots, 229 tirs, 220 touches |
| Défi 90 s, Reactor Court | 15 cibles en 17,97 s de simulation |
| Boss Rush, Reactor Court | Quatre boss, trois ravitaillements, 19 robots |
| Infini | 100 vagues accélérées et extraction à versement unique |
| Classique | Victoire, défaite, égalité, réapparition, équipes, capture, domination, sept cartes explorées |
| Mouvement et armes | 24 swaps, rechargement interrompu, charge Nova, ADS ×4 et redressement sous plafond |
| Tactile | 12 assertions sur événements Godot injectés sous Linux, trois doigts simultanés, pause, reprise et disposition persistante |
| Rendu, clics et son | 14 assertions sous Xorg. Changement de résolution, plein écran, souris, stand, lunette, audio et boutique |
| Coop | Deux et quatre processus ENet, version/code refusés, reprise en intermission, transactions et bilan |
| Dédié | Un hôte headless et deux invités, lancement et apparition d’une unité |
| EXE Windows | PE x64 vérifié. Neuf assertions depuis le PCK embarqué, exécuté sous Godot Linux hors des sources |
| APK | Signature et alignement validés, manifeste et ressources inspectés. Voir ANDROID_TESTS |

Les scénarios de survie pilotent les entrées et la visée d’un joueur automatisé. Les suites Classique déclenchent aussi des cas déterministes de fin et de contestation. Les tests coop utilisent localhost. Le mode tactile de bureau utilise `-- --touch`.

## Modifications et corrections de QA

- La vérification du bouton d’écoute recherche le bouton et l’onglet. L’ancienne assertion supposait cinq lignes dans la page, qui contient désormais trois réglages sonores supplémentaires.
- La banque passe de 41 à 45 échantillons. Le test conserve la mesure de la boucle de combat V2 de 13,44 s et vérifie la nouvelle boucle de pression.
- La position d’un projectile peut survivre à son émetteur. Les accès de collision utilisent une référence d’émetteur validée.
- Le test d’élimination classique attend la fin de la protection initiale. Le redéploiement vérifie la protection suivante.
- Un premier import neuf s’est interrompu dans l’import des polices. Une deuxième copie sans cache avec les réglages d’éditeur isolés a importé et exporté l’ensemble. L’archive finale est contrôlée à nouveau après décompression.
- L’export Android a nécessité le profil d’import ETC2/ASTC exigé par ce preset et les Build Tools 36.0.0. L’export et la signature ont ensuite réussi.

## Économie et profils

Les données ci-dessous sont des simulations de formule, avec 20 cas synthétiques par mode et rotation entre les trois difficultés. Elles ne mesurent pas des temps de déblocage humains.

| Mode | Pièces moyennes par cas | XP moyen |
|---|---:|---:|
| Survie 20 | 177,20 | 496,10 |
| Survie 10 | 138,70 | 407,70 |
| Défi | 49,50 | 178,65 |
| Classique | 45,15 | 160,95 |
| Capture | 53,20 | 184,80 |

La migration V2 conserve XP, pièces, équipement, FOV et record. La sauvegarde du schéma 3 est comparée octet pour octet. Le même achat, défi ou bilan répété ne donne qu’un crédit. Le journal conserve 32 bilans et 48 transactions.

Les journaux d’exécution sont dans `docs/validation`. Le tableau des 221 étapes détaille les critères dont la vérification reste partielle.
