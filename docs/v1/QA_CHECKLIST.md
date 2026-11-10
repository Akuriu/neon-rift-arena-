# Vérification de NEON RIFT — ARENA

Les tests s’exécutent avec **Godot 4.6.3 stable** sous Linux x86-64. Les tests de jeu avancent la physique à 60 Hz. Un pilote scripté utilise les déplacements et le tir du jeu. Il oriente la caméra vers des cibles en vue et sélectionne un module entre les vagues. La cadence du pilote de test est spécifique à l’automatisation.

| Parcours | Difficulté | Résultat de la partie de test |
| --- | --- | --- |
| Survie · Reactor Court | Découverte | Victoire, 41 unités, 5 modules, 3 phases du boss, 13 985 points |
| Survie · Skyline Depot | Découverte | Victoire, 41 unités, 5 modules, 3 phases du boss, 13 835 points |
| Survie · Reactor Court | Standard | Victoire, 41 unités, 14 628 points |
| Survie · Skyline Depot | Expert | Victoire, 41 unités, 14 001 points |
| Défi · Reactor Court | Standard | Victoire, 15 unités en 19,52 s de combat, 5 563 points |
| Défi · Skyline Depot | Standard | Victoire, 15 unités en 18,68 s de combat, 5 572 points |

## Régression fonctionnelle

- [x] Import depuis les sources, écran titre, sélection, arène et lancement depuis le paquet PCK.
- [x] AZERTY, QWERTY, réaffectation, saut, sprint, glissade, collisions et accès à une rampe.
- [x] Dégâts du Pulse et du Volt, trois impulsions de Prism, charge et collision de Nova, blocage par le décor.
- [x] Cibles mobiles, réapparition, réarmement et absence de défaite en Entraînement.
- [x] Arrivée des robots et changement de vague, sélection de module, boss, victoire, défaite et bilan.
- [x] Pause réelle, reprise, trois redémarrages, confirmation et retour au menu.
- [x] Chronomètre qui termine le Défi à 90 s et Défi gagné sur les deux arènes.
- [x] Application des réglages vidéo et audio, sauvegarde des touches et relecture du classement.
- [x] Profil volontairement corrompu dans un dossier isolé, récupération de la révision précédente puis valeurs d’origine.
- [x] Rendu en fenêtre, clics sur les boutons, capture et libération de la souris, mouvement de visée.
- [x] Changement 960 × 540, bascule plein écran, retour en 1280 × 720 et inspection du menu, du HUD et de la pause dans une fenêtre 1920 × 1080.
- [x] Signal audio capturé sur le bus Master et boucles musicales de durée complète.

Les tests dirigés utilisent des positions contrôlées pour les collisions et les armes, une injection de dégâts pour la défaite et une valeur de départ proche de 90 s pour tester l’expiration. Les parties gagnées du tableau utilisent les déplacements et tirs normaux du pilote de test.

## Commandes reproductibles

Depuis le dossier qui contient **project.godot**, sous Linux. Les variables ci-dessous isolent la sauvegarde des tests.

    export XDG_DATA_HOME="$(mktemp -d)"
    export NEON_QA_ISOLATED=1
    godot --headless --path . --editor --import
    godot --headless --path . --fixed-fps 60 --script res://tests/regression.gd
    godot --headless --path . --fixed-fps 60 --script res://tests/survival.gd -- survival reactor discovery
    godot --headless --path . --fixed-fps 60 --script res://tests/survival.gd -- survival skyline discovery
    godot --headless --path . --fixed-fps 60 --script res://tests/survival.gd -- trial reactor standard
    godot --headless --path . --fixed-fps 60 --script res://tests/survival.gd -- trial skyline standard

Le test suivant nécessite une session graphique. Les 51 assertions de régression et les 10 assertions du test en fenêtre ont réussi. Mesa llvmpipe a signalé que son pilote ne permettait pas de modifier la V-Sync pendant le test.

    godot --path . --script res://tests/render_check.gd

## Vérifications restantes

Exécution native du lanceur .bat et de l’export .exe sous Windows, ainsi que fréquence d’images et confort de jeu sur Intel N150. Le moteur a refusé l’export .exe dans l’environnement de développement faute des modèles Windows. L’export du paquet PCK a abouti et le jeu a démarré à partir de ce paquet dans un dossier séparé.
