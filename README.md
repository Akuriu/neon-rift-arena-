# NEON RIFT ARENA 2.0 — UPRISING

FPS d’arène 3D en français. Combattez les robots en solo ou avec deux à quatre pilotes, équipez-vous entre les vagues et débloquez des armes au hangar.

## Jouer sous Windows

1. Décompressez **NEON_RIFT_ARENA_V2_Windows_x64.zip**.
2. Double-cliquez sur **NeonRiftArenaV2.exe** dans le dossier extrait. Le moteur et les ressources du jeu sont intégrés.

Pour modifier le jeu, décompressez **NEON_RIFT_ARENA_V2_Sources.zip**, importez **project.godot** dans Godot **4.6.3 Standard** puis lancez avec **F5**. Le paquet **build/NeonRiftArenaV2.pck** peut aussi être ouvert en glissant l’exécutable Godot sur **JOUER_WINDOWS.bat**.

## Parties

| Mode | Objectif |
| --- | --- |
| Survie 20 | Vaincre les quatre boss, puis encaisser la victoire ou continuer avec le même équipement en Infini |
| Survie 10 | Terminer un format court avec deux boss |
| Infini | Tenir le plus longtemps possible et encaisser le bilan à l’intermission |
| Défi chronométré | Éliminer 15 robots en 90 secondes |
| Boss Rush | Vaincre les quatre boss et leur escorte sur quatre manches |
| Entraînement | Essayer les huit armes et réarmer les cibles à la console de départ |
| Coop | Héberger ou rejoindre Survie 20, Survie 10 ou Infini par IP et port UDP |

Choisissez **Reactor Court**, **Skyline Depot** ou **Cryo Foundry**. Une graine facultative reproduit les compositions à carte, difficulté et taille d’équipe identiques.

## Équipement et progression

Les **crédits de partie** achètent soins, munitions et améliorations à l’intermission. Les **pièces du pilote**, versées au bilan et pour les contrats, achètent des armes, gadgets, modules et apparences au hangar. Les achats permanents et les quatre emplacements sont sauvegardés. Le bouton **Tester au stand** prête une arme verrouillée.

**ZQSD** par défaut, souris pour viser, clic gauche pour tirer, clic droit pour la lunette. **1–4** ou molette sélectionnent l’arme. La molette choisit ×2 ou ×4 pendant la visée de l’Eclipse Rail. Maintenez puis relâchez le clic gauche pour tirer avec la Nova ou la Stellar Lance. **R** recharge, **G** active le gadget, **I** inspecte l’arme, **E** interagit et **Tab** affiche le journal. [Commandes complètes](docs/CONTROLS.md)

Les réglages, records et déblocages sont dans **%APPDATA%\NeonRiftArena\pilot_profile.json** sur Windows. La première écriture V2 garde une copie du profil V1 dans **pilot_profile.v1.json**. Les scores historiques restent associés à leur mode et leur arène.

## Coop et réglages vidéo

Ouvrez **Coop · 2–4**. Un pilote héberge, les autres entrent son adresse IP et le port affiché. Le port par défaut est **24562 UDP**. L’hôte choisit la carte, le mode et la difficulté. Chaque pilote indique qu’il est prêt. [Connexion et serveur dédié](docs/NETWORKING.md)

Pour un portable modeste, choisissez **Ultra faible**, **960 × 540** et **30 FPS** dans **Paramètres → Vidéo**. Le HUD garde sa résolution. Les temps d’image et l’environnement mesurés sont détaillés dans le [rapport de performance](docs/V2_PERFORMANCE.md).

## Vérifier et reconstruire

Depuis la racine du projet, avec Godot 4.6.3 et Python 3 accessibles en ligne de commande.

```sh
python tools/run_tests.py --godot godot
```

L’option `--godot` accepte le chemin de Godot. Les tests créent des profils temporaires séparés. Les suites `solo`, `coop2`, `coop4` et `dedicated` peuvent être lancées avec `--suite`.

Pour reconstruire l’exécutable, installez les modèles d’export 4.6.3 dans Godot puis exportez le préréglage **Windows x64** en mode release.

```sh
godot --headless --path . --editor --import
godot --headless --path . --export-pack "Windows x64" build/NeonRiftArenaV2.pck
godot --headless --path . --export-release "Windows x64" build/NeonRiftArenaV2.exe
```

[Rapport de build](BUILD_REPORT.md) · [Validation](docs/V2_QA_REPORT.md) · [Changements](CHANGELOG.md) · [Crédits](CREDITS.md)
