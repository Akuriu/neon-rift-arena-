# Mesures de référence · v0.0.7a

Révision de départ `46b39c1064e02bad23ad406c311831cbd56a5a5e`, tête de `feature/v0.0.7` et de la PR #2. La PR #2 est empilée sur la PR #1, et les deux sont en brouillon. Le tag `v0.0.7a` pointe sur ce commit. La branche `release/v0.0.7a` ajoute le workflow de publication. Les deux releases v0.0.7 sont des Preview.

## Banc local

Godot 4.6.3. Les profils et répertoires de cache sont jetables. Les nombres de cette page décrivent Linux sur ce banc. N150, Honor 400 Lite et liaison Wi-Fi réelle sont `NOT_TESTED_PHYSICAL`.

| Essai | Résultat de référence |
| --- | --- |
| `python3 tools/run_tests.py --suite all` | Code retour 0. 601 contrôles distincts après déduplication des 8 lignes de scénarios réseau. Coop 2/4 et serveur dédié inclus. |
| Chargement synchrone de `App.tscn`, 3 processus headless | 587 à 747 ms. Temps chronométré autour de `load`. |
| Construction de l’accueil, 3 processus headless | 79 à 88 ms. 433 nœuds au total, autoloads compris. |
| Jouer, Paramètres, carte Dépôt en Entraînement | 32–48 ms, 15–21 ms et 90–116 ms sur le thread principal, respectivement. |
| Première image de l’accueil, fenêtre 1280 × 720 Faible | 4 088 ms depuis la demande de la scène par le banc, dont 718 ms jusqu’à `scene_changed`. Première compilation OpenGL incluse. |
| Accueil au repos, fenêtre identique | 90 images après 10 images écartées. P50 34,92 ms, P95 37,82 ms, P99 42,48 ms. 289 appels de dessin médians, 49,31 Mio mémoire statique du moteur. |

Le test en fenêtre utilise Mesa llvmpipe 25.0.7 avec quatre threads, Xorg dummy et le profil Faible. Le timing démarre après initialisation du moteur, avant demande de la scène. Un seul passage fenêtré de référence. Les comparatifs suivants doivent conserver le scénario, le profil et la résolution. Le débit logiciel ne prédit pas les FPS des appareils cibles.

## Chemins chauds

- `App.tscn` contient un nœud et `ui/app.gd` compte 1 236 lignes. Ses préchargements entraînent `Session.tscn` et les modules de jeu. `_ready` construit immédiatement l’accueil et le Dépôt 3D, puis prend la caméra.
- `_new_screen` reconstruit la vue et le fond. `ui/skin.gd` place les contrôles en coordonnées 1280 × 720. Accueil et éditeur tactile s’élargissent avec le ratio. Jouer, Classique/Gun Game, Parkour et Carrière ont déjà leurs modules. Pause, options, HUD, lobby, arsenal et bilan passent par App et ses sous-vues.
- L’ancien accueil a une caméra orbitale et un fondu entrant de 150 ms sur PC. Les portraits, l’aperçu d’arme, les poses du pilote et le HUD ont déjà leurs propres mécanismes. Le rendu 3D de fond continue derrière plusieurs pages opaques.
- `Prefs` vérifie le profil et applique les commandes. `Art` connecte les préférences et met les matériaux en cache lors du premier usage. `Sounds` chargeait 45 WAV et créait 28 lecteurs avant la première image. Les bus sont Master, Musique, SFX et Ambiance. Les WAV sont originaux et la génération est dans `tools/synth_audio.py`.
- Les cartes sont assemblées à l’exécution. Les décors répétés passent par les lots de géométrie de `game/fabric.gd`. Les shaders de ciel et de sol s’exécutent en Compatibility. L’Arena supprime les collisions de son décor de menu et conserve le paysage. Le HUD et les commandes tactiles dessinent une partie des éléments via `_draw`.

## Budgets initiaux

- Sur le banc commun, comparer les percentiles, le nombre de dessins et la mémoire par scénario. Le chemin avant la première image doit éviter la banque audio, la construction de la carte et les shaders de décor.
- Contrôle matériel à faire en Faible sur Intel N150, avec un objectif de 16,7 ms par image. Contrôle en Ultra faible sur Honor 400 Lite avec un objectif de 33,3 ms, puis 22,2 ms si la charge le permet.
- Garder les surfaces de menu majoritairement statiques, borner les animations au contrôle ou au panneau concerné et mesurer toute nouvelle vue 3D.

Documentation vérifiée pour Godot 4.6. [Chargement asynchrone](https://docs.godotengine.org/en/4.6/tutorials/io/background_loading.html) · [ResourceLoader](https://docs.godotengine.org/en/4.6/classes/class_resourceloader.html) · [Optimisation 3D](https://docs.godotengine.org/en/4.6/tutorials/performance/optimizing_3d_performance.html) · [Compilation des shaders](https://docs.godotengine.org/en/4.6/tutorials/performance/pipeline_compilations.html).

## Rendu à douze bots · lot de regroupement

Médianes de trois processus par révision sur Godot 4.6.3, Mesa llvmpipe, 1280 × 720 Faible. Réacteur, graine 7114, douze bots figés et caméra identique, VSync désactivée. Chaque passage mesure 120 images après 22 images d’échauffement. Le banc décrit le rendu, avec les bots et la simulation figés.

| Mesure | Avant · `e10f852` | Après · `1c9acba` |
| --- | ---: | ---: |
| P50 | 33,74 ms | 32,00 ms |
| P95 | 45,37 ms | 39,12 ms |
| P99 | 52,94 ms | 42,76 ms |
| Appels de dessin | 522 | 381 |
| Primitives | 40 154 | 40 154 |
| Mémoire statique du moteur | 55,12 Mio | 53,09 Mio |

Sur la même image 720p, 138 pixels diffèrent d’au plus 3 valeurs par canal après le regroupement. La médiane historique de la v0.0.7a était de 40,90 ms au P95. Les valeurs absolues varient avec la charge du banc. Les gains sur l’Intel N150 et le Honor 400 Lite restent à mesurer.

Pour reproduire le JSON, utiliser une fenêtre et un profil jetable avec `NEON_QA_ISOLATED=1`, puis lancer `godot --audio-driver Dummy --script res://tests/combat_render_benchmark.gd -- 0 1`. Pour comparer une révision antérieure, passer le chemin absolu du même script à `--script` et le répertoire de la révision à `--path`.
