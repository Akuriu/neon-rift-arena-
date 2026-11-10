# Reprendre le projet

## Sources et Git

L’archive contient les scènes, les ressources, les tests et un bundle Git. Pour récupérer l’historique dans un dossier de travail propre, ouvrez un terminal dans l’archive décompressée.

```sh
git bundle list-heads NEON_RIFT_ARENA_V3.bundle
git clone -b main NEON_RIFT_ARENA_V3.bundle neon-rift-arena
cd neon-rift-arena
git tag
```

`v2.0-baseline` pointe vers le projet d’origine. Les exports, clés, profils, caches et journaux privés sont exclus du suivi Git. Pour lier un dépôt GitHub que vous avez créé, utilisez `git remote add github URL_DU_DEPOT`, puis `git push -u github main`. Les fichiers restent utilisables en local.

## Architecture

- `scenes/App.tscn` instancie l’application, `game/session.gd` relie arène, acteurs, réglages et direction de match. `game/modes/classic.gd` arbitre les matchs classiques. `game/wave_director.gd` arbitre les vagues.
- `game/player/locomotion.gd` contrôle le corps. `game/player/camera_rig.gd` lit sa position interpolée et garde la direction du tir séparée de la présentation.
- `game/arsenal.gd` contient les règles de chargeur, chaleur et tir. Les courbes de présentation sont dans `game/weapons/view_animation.gd`.
- `services/prefs.gd` valide et écrit atomiquement les préférences et le profil. `services/career.gd` borne les historiques et les défis.
- `network/coop.gd` transporte les messages ENet. `network/replication.gd` vérifie les enveloppes et `network/snapshot_track.gd` interpole les pilotes distants.
- `ui/screens` contient les écrans Classique et Carrière. `ui/mobile` contient le rendu et l’éditeur des commandes. Les deux plateformes utilisent les mêmes actions de simulation.

## Modifier les contenus

Un style se règle dans `art/direction.gd`, avec les matières du sol et du ciel sous `assets/art`. Testez les quatre styles avec la même graine et les mêmes contrôles. Ajoutez une arme via `game/weapons/catalog.gd` en conservant les identifiants existants. Complétez son modèle, ses courbes, ses poses réseau, ses sons et le test du stand.

Pour une carte, étendez `game/arena.gd` et ajoutez l’identifiant au catalogue, aux préférences et à la construction de session. Définissez départ, console, apparitions, cibles, zones et empreintes de collision. Vérifiez leur accès avec `v3_modes.gd` et ajoutez sa capture dans `assets/maps`.

## Tests et exports

Lancez `python3 tools/run_tests.py --suite all` après import. Les scripts sous `tests` emploient des profils temporaires. Lancez `render_check.gd` et `benchmark.gd` dans un environnement graphique. Les commandes et les chiffres exacts figurent dans les rapports QA et performances. Pour reconstruire Windows et Android, utilisez les presets de `export_presets.cfg`.

Le rapport des 221 étapes identifie les travaux et validations restants, dont la coop Classique, les mesures sur Intel N150 et la validation Android sur téléphone.
