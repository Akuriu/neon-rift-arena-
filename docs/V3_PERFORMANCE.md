# Performances et limites de mesure

Les mesures utilisent Godot 4.6.3, Linux x86_64, OpenGL Compatibility et le rendu logiciel Mesa llvmpipe avec quatre threads. Les chiffres portent sur le moteur dans cet environnement. Intel N150, Windows natif et téléphone physique restent à mesurer.

Le banc ouvre Reactor Court, lance la vague 5 en Expert, attend 8,8 s, fait pivoter la caméra et tire sur 180 images. La limite d’images est levée. Xorg signale que le pilote ne permet pas de modifier le mode de synchronisation verticale. Les mesures de percentile utilisent les temps réels entre images, sans extrapolation vers un autre GPU.

| Build et preset | Surface | Échelle | Robots | p50 ms | p95 ms | p99 ms | Appels dessin médians | Mémoire moteur MiB |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| V2 Faible | 1280×720 | 76 % | 9 | 24,13 | 28,92 | 34,78 | 235 | 47,7 |
| V3 Faible | 1280×720 | 76 % | 9 | 25,42 | 32,10 | 50,03 | 243 | 50,7 |
| V2 Ultra faible | 960×540 | 64 % | 7 | 16,13 | 21,24 | 23,85 | 226 | 49,1 |
| V3 Ultra faible | 960×540 | 64 % | 7 | 17,10 | 21,46 | 25,48 | 232 | 51,7 |

L’itération intermédiaire V3 Faible mesurait 38,60 ms au p95. La simplification du ciel, des matières, de la brume et du sol a ramené ce percentile à 32,10 ms. Le coût supplémentaire face à la V2 reste visible en Faible. En Ultra faible, le p95 se situe à 0,22 ms de la V2 dans ce scénario. Ces mesures n’établissent pas une tenue à 60 FPS sur Intel N150.

Les effets et projectiles sont mis en pool. Les mises à jour d’animation se raréfient avec la distance. Les requêtes de rayon réutilisent leur objet et les décisions de trajectoire sont espacées entre robots. L’endurance headless observe une variation de 0,32 MiB de mémoire statique moteur de la vague 20 à la vague 100. Cette mesure concerne une session accélérée.

## Reproduire

Dans un environnement graphique, créez un profil de test temporaire, puis lancez le banc avec le preset et l’index de résolution souhaités.

```sh
qa_profile="$(mktemp -d)"
NEON_QA_ISOLATED=1 NEON_QA_PROFILE_PATH="$qa_profile" XDG_DATA_HOME="$qa_profile" \
  godot --path . --disable-vsync --script res://tests/benchmark.gd -- 0 1
```

Les arguments `3 0` exécutent le scénario Ultra faible en 960×540. Le CSV est dans `docs/validation/benchmark.csv`.
