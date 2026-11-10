# Architecture

**Godot 4.6.3 et GDScript.** Les corps physiques, la capture souris et l’interface sont gérés par Godot. Le rendu Compatibility utilise OpenGL avec une géométrie et des shaders légers. Les ressources sont locales.

| Système | Entrée | Responsabilité |
| --- | --- | --- |
| Application | scenes/App.tscn, ui/app.gd | Cycle des écrans, aperçu 3D du menu, pause, relance et enregistrement du résultat |
| Session | scenes/Session.tscn, game/session.gd | Assemble carte, pilote, IA et directeur, gère les rayons, les objets et le score |
| Arènes | game/arena.gd, game/skyline.gd | Constructions paramétriques, obstacles, zones de préparation et alcôves d’apparition |
| Déplacement | game/player.gd | Corps capsule, accélération, saut tamponné, sprint, accroupissement, glissade et caméra |
| Équipements | game/arsenal.gd, game/catalog.gd | Cadence, recharge, chaleur, données d’équilibrage et modèles à l’écran |
| Robots | game/drone.gd, game/routes.gd | États d’arrivée, poursuite, télégraphie et récupération, grille A* et collisions |
| Directeur | game/wave_director.gd | Préparation, vagues, défis, choix du module et fin de partie |
| Profil | services/prefs.gd | Application des options, schéma versionné, validation, fichier temporaire et révision de secours |
| Audio | services/sounds.gd | Quatre volumes, voix 2D et 3D réutilisées, musiques et ambiance en boucle |
| Art | game/fabric.gd, game/robot_models.gd, game/weapon_models.gd | Géométrie modulaire regroupée, modèles réutilisés, palette et volumes 3D |

Les couches physiques 1, 2 et 4 représentent le décor, le pilote et les robots. Les tirs instantanés s’arrêtent à la première collision. Chaque projectile balaie son déplacement entre deux images physiques. Un impact de Nova vérifie la visibilité de chaque cible dans la zone.

Le directeur reçoit les apparitions et neutralisations de la session. Une neutralisation change l’état du robot avant d’émettre son signal, ce qui protège le score et les récompenses. Les sessions, leurs chronos et leurs enfants temporaires disparaissent ensemble à la relance. Les résultats arrivent après le décompte du dernier tir.
