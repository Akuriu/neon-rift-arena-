# NEON RIFT ARENA 2.0.0 — rapport de build

Le projet livré part de l’archive V1 et utilise **Godot 4.6.3 stable / Compatibility**. La livraison contient deux archives.

| Archive | Contenu |
| --- | --- |
| NEON_RIFT_ARENA_V2_Windows_x64.zip | **NeonRiftArenaV2.exe** avec moteur Windows x64 et PCK intégré, guide de lancement, licences |
| NEON_RIFT_ARENA_V2_Sources.zip | Projet Godot modifiable, **build/NeonRiftArenaV2.pck**, ressources, scripts de tests et documentation |

Sur Windows, extrayez le ZIP et ouvrez **NeonRiftArenaV2.exe**. Pour développer, ouvrez **project.godot** dans Godot Standard et appuyez sur **F5**.

## Contrôles

- Import des ressources et export release Windows x64 réussis avec les modèles officiels 4.6.3. Exécutable vérifié en **PE32+ x86-64**.
- Tests des sources avec `python tools/run_tests.py --godot godot`. Les résultats et la portée des scénarios sont dans le [rapport QA](docs/V2_QA_REPORT.md).
- Paquet intégré et PCK autonome lus par Godot Linux dans un dossier sans sources. Les deux ont ouvert le menu, le salon, la boutique et le stand de Cryo Foundry, puis tiré avec l’Eclipse Rail.
- Rendu, temps d’image et mémoire relevés sous Mesa llvmpipe. [Mesures](docs/V2_PERFORMANCE.md)

L’exécution Windows native, le débit et les temps d’image sur Intel N150, ainsi que la connexion Internet entre réseaux distincts restent à valider. La Défense du réacteur, le mode Extraction à objectifs, le matchmaking public et les comptes cloud restent des extensions. L’extraction volontaire avec bilan appartient au mode Infini livré.

Les commandes de reconstruction sont dans le [README](README.md). Les licences figurent dans [CREDITS.md](CREDITS.md) et dans l’archive Windows.

## Empreintes des binaires livrés

```text
b85f7b97e9f7424d5b4fe827709475a2f129e6aaab3163a8be5a5a398fd2aee7  NeonRiftArenaV2.pck
c39b7f97058acc9ea784caf9ea870e6aa72a23b15e40d8918b7f945732f459c5  NeonRiftArenaV2.exe
```

Depuis un dossier sans projet, `godot --main-pack` peut charger chacun de ces deux fichiers. Le script `tests/export_smoke.gd` permet de rejouer le contrôle avec l’option `--script` et son chemin absolu. Utilisez un dossier utilisateur jetable pour la validation.
