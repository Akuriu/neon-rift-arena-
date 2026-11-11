# Rifle Arena

## v0.0.7-alpha

- La v0.0.7a rétablit le tir au clic gauche et la visée au clic droit sur PC.
- Gun Game local : huit équipements en prêt, progression des bots, victoire au dernier palier, bilan et classement séparé.
- Gun Game propose un ordre mélangé reproductible et un bilan avec tous les participants et les rangs ex æquo.
- Parkour local : trois parcours physiques, checkpoints ordonnés, pénalités, records et HUD mobile dédié.
- Parkour : fantôme optionnel du record, médailles par parcours, nombre d’arrivées et de passages sans retour.
- Atelier interactif solo au Dépôt de fret (Exploration/Entraînement), avec fermeture suspendue si le passage est occupé.
- Monte-charge du Dépôt de fret avec appels au sol et au quai, transport physique, arrêt d’urgence et descente protégée.
- Protection d’apparition des bots, séparation locale et cache des combattants.
- Animations de changement d’arme/recharge prioritaires, ressorts réinitialisés au respawn, attribution des tirs posthumes en Gun Game.
- Réception de saut stable selon la cadence de rendu, mouvement d’arme amorti dans les virages et pas latéraux, et huit silhouettes de recharge distinctes.
- Aperçus d’armes manipulables par glissement et pincement/molette.
- Ouverture des menus : masquage du HUD et libération des commandes.
- Descriptions des menus corrigées, avec une largeur minimale pour le retour à la ligne.
- Menu Jouer en cartes et palette Classic Sand.
- Profil schéma 6 avec copie v5 avant migration.
- APK Preview isolée par build et tentative : installation à côté des anciennes Preview sans conflit de certificat.
- Build Preview uniquement : les validations matérielles et la signature stable restent requises avant publication.

## v0.0.6-alpha

- HUD tactile compact avec six commandes de combat, compteur de munitions tactile, objectif et chronomètre regroupés.
- Joystick progressif sans double zone morte, course réglable et visée tactile indépendante de la densité d’écran. Courbe et plafond de vitesse facultatifs.
- Sprint en bascule conservé à la pause et réinitialisé au KO. Les gestes ambigus ou annulés laissent les commandes au repos.
- Aperçu des commandes plein écran, modes Simple, Complet, Gaucher et Personnalisé, réinitialisation d’un seul bouton.
- Transitions de sprint, de changement d’arme et de recharge amorties. Les pas sont interpolés entre deux ticks physiques.
- Télémétrie P50/P95/P99, temps physique CPU, appels de dessin et mémoire du moteur. Les classements des parties sans bots gardent leurs règles après relecture.
- Contrôles automatiques sur les changements du jeu. Exports Windows et Android issus d’un seul commit, lancement sur les deux plateformes et sommes SHA-256.

La coop conserve le protocole 4. La mise à jour Android sur une installation v0.0.5 dépend de la récupération de la clé de signature d’origine. Voir [le suivi QA](docs/V0.0.6_QA.md).

## v0.0.5-alpha

- Accueil mobile plein écran, sprint à bascule et animations des joueurs et des bots synchronisées en coop.

## 2.0.0 — UPRISING

- Survie étendue à 20 vagues, format 10 vagues, Infini avec extraction et Boss Rush. Le Défi, l’Entraînement et les cartes Reactor Court et Skyline Depot sont conservés.
- Cryo Foundry ajoute des cuves, des lignes de précision et deux passerelles latérales. Skimmer, Medic Drone, Disruptor et Artillery Node rejoignent les robots. Aegis Colossus et Null Architect rejoignent les boss.
- Eclipse Rail, Stellar Lance, Ion Repeater et Arc Mortar portent l’arsenal à huit armes. Ajout du stand de prêt, des lunettes, des réserves, de la maîtrise et de quatre emplacements configurables.
- Crédits de partie et pièces permanentes. Deux boutiques, XP, niveaux, contrats locaux, gadgets, modules et apparences. Migration du profil précédent avec copie de sécurité.
- Coop privée 2–4 par ENet. L’hôte arbitre le combat, les vagues, les achats et les bilans. Reconnexion à l’intermission, achats de terrain synchronisés et serveur dédié sans rendu.
- Préréglage Ultra faible à 64 %, sol simplifié, effets et entités temporaires bornés, télémétrie d’image. Lunette masquable, réticule personnalisable et réglages supplémentaires.
- Tests d’intégration, endurance, rendu, réseau et export. Préréglage Windows x64 avec paquet intégré.

## 1.0.0

Survie six vagues, Défi chronométré et Entraînement. Deux cartes, quatre armes, six archétypes et classements locaux.
