# Audit de la base V2

Le cahier des charges complet compte 1 768 lignes et 221 étapes. Le travail reprend `NEON_RIFT_ARENA_V2_Sources(1).zip`. Son SHA-256 est `e21bfc0dd105f0f8f51c969d18562c0337462483906609bf9f724949153dd1ee`, identique à l’archive source V2 livrée auparavant. Le ZIP a été contrôlé avant extraction pour les doublons, chemins sortants et liens symboliques. Il compte 213 entrées. L’original est conservé. Le commit `30b7ef4` et le tag `v2.0-baseline` donnent la copie de référence.

## Inventaire de départ

| Domaine | V2 contrôlée |
|---|---|
| Scènes | App, Session, Pilot et Drone, dont le contenu est complété en GDScript |
| Code | 41 scripts GDScript et un projet Compatibility pour Godot 4.6.3 |
| Arènes | Reactor Court, Skyline Depot et Cryo Foundry avec collisions et routes d’IA |
| Jeu solo | Survie 20/10, Infini, Défi, Boss Rush et Entraînement |
| Équipements | Pulse-7, Volt Arc, Prism Burst, Nova Charge, Eclipse Rail, Stellar Lance, Ion Repeater, Arc Mortar. Dash et Aegis |
| Adversaires | 12 archétypes procéduraux, dont quatre rencontres majeures |
| Progression | Pièces, XP, maîtrises, contrats locaux, profils et classements dans le schéma 3 |
| Économie de partie | Sept articles d’intermission, améliorations et crédits temporaires |
| Multijoueur | ENet 2–4, transactions côté hôte, reconnexion, code de salon, serveur dédié |
| Son et rendu | 41 échantillons, bus indépendants, shaders de sol et d’horizon, réglages vidéo |
| Tests | 51 contrôles de régression, suites V2, scénarios de survie et captures |

## Points techniques de départ

Le repère de tir et la vue du joueur partageaient les mises à jour de physique. Les modèles d’armes étaient préparés au changement d’arme. La refonte isole la vue de rendu, garde le repère balistique et prépare les maillages du rack au début du niveau. Les trois cartes sont réutilisées avec leur topologie et leurs points d’entrée.

`ui/app.gd` orchestre les écrans. `game/session.gd` coordonne acteurs et collisions. Le directeur détermine les vagues, `game/drone.gd` détermine les comportements, et `network/coop.gd` valide le réseau et les transactions. Les méthodes de sauvegarde atomique et de verrouillage ont été conservées et étendues.

Les 222 assertions de référence incluent la coop à 2, à 4 et un hôte dédié. Les captures V2 et les deux mesures graphiques sont archivées avec la comparaison V3.
