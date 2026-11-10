# Audit de la V1

Source inspectée intégralement avant les changements, **NEON_RIFT_ARENA_1.0(1).zip**. L’archive a été vérifiée et comparée à la première livraison V1. Les deux étaient identiques octet par octet.

```text
SHA-256 fb0c1f52aa6ff452cd45a447e309d7fdf7f6b6555180a5de259bfa78b7076e49
```

| Système | État observé | Continuité V2 |
| --- | --- | --- |
| Entrée du jeu | App.tscn, menu, pause, sélection et réglages | Même scène d’entrée et jeu solo hors ligne |
| Vagues | Six compositions fixes, paliers 3 et 6 | Directeur conservé, générateur déterministe et nouveaux paliers |
| Combat | Pulse-7, Volt Arc, Prism Burst, Nova Charge | Les quatre armes de départ, leurs identifiants et le même clavier |
| Arènes | Reactor Court et Skyline Depot, géométrie procédurale | Les deux routes et points de départ, plus Cryo Foundry |
| Entraînement et défi | Quatre cibles recyclées et 15 cibles en 90 s | Modes conservés, stand étendu à toutes les armes |
| IA | Scout, Sentinel, Bulwark, Specter, Apex, Warden | Six archétypes conservés et six ajouts |
| Sauvegarde | JSON schéma 2, préférences, affectations et records par arène | Lecture historique, sauvegarde schéma 3 et copie V1 |
| Économie | Modules d’intermission, absence de monnaie | Modules conservés, deux monnaies et deux magasins |
| Réseau | Jeu solo | Hôte autoritaire et clients ENet dans le même projet |
| Rendu | Compatibility, maillages combinés par secteur, trois niveaux vidéo | Quatre niveaux, caches, pool de projectiles et télémétrie |

La V1 a passé **51 contrôles de régression**. La Survie V1 a atteint le bilan après 41 robots, avec 13 985 points et 55,2 secondes de simulation. Le benchmark 720p Faible a donné 22,23 ms en médiane, 26,54 ms au p95 et 220 appels de dessin avec 9 robots. Les méthodes et l’environnement sont décrits dans le [rapport de performance](V2_PERFORMANCE.md).
