# Performance

Le jeu utilise le rendu Godot **Compatibility** et démarre en 1280 × 720 avec le préréglage **Faible**. Le HUD garde sa résolution pendant le changement d’échelle 3D.

| Préréglage | Échelle 3D | Ombres directionnelles | Anticrénelage 3D | Densité d’étincelles |
| --- | ---: | --- | --- | ---: |
| Faible | 76 % | Désactivées | Désactivé | 46 % |
| Moyenne | 89 % | Jusqu’à 28 m | Désactivé | 74 % |
| Élevée | 100 % | Jusqu’à 47 m | MSAA 2× | 100 % |

Les lumières décoratives sont matérialisées par de la géométrie lumineuse. La carte regroupe ses surfaces statiques par secteur et matériau, et les drones partagent les meshes d’un même archétype. L’IA recalcule ses routes environ trois fois par seconde. La difficulté borne les unités à 5, 7 ou 9. Les effets utilisent un pool de 120 éléments, les tirs visibles sont bornés et les objets ramassables expirent.

## Mesures

Scène Reactor Court, vague 5 en Expert, 9 unités simultanées, fenêtre 1280 × 720, V-Sync désactivée et 180 images mesurées par préréglage après mise en chauffe. Le pilote est protégé pour maintenir la charge du test.

| Préréglage | Temps médian par image | 95e centile | Appels de dessin médians |
| --- | ---: | ---: | ---: |
| Faible | 22,00 ms | 26,21 ms | 220 |
| Élevée | 78,23 ms | 92,96 ms | 381 |

Mesures en rendu logiciel **Mesa llvmpipe**, quatre threads de rendu sur un hôte AMD EPYC. Elles permettent de comparer les préréglages sur la même machine. La fréquence de 60 FPS ou de 30 FPS sur Intel N150 reste à vérifier sur le portable cible.

Le profil peut être reproduit en session graphique avec un dossier de sauvegarde isolé.

    export XDG_DATA_HOME="$(mktemp -d)"
    export NEON_QA_ISOLATED=1
    godot --path . --disable-vsync --script res://tests/benchmark.gd -- 0
    godot --path . --disable-vsync --script res://tests/benchmark.gd -- 2

Le coût observé augmente avec la résolution 3D, les ombres et l’anticrénelage. Si la mesure sur le portable montre des saccades, relevez d’abord le temps d’image en Faible à 1280 × 720, puis à 960 × 540. Cela aidera à distinguer le coût du rendu de celui des décisions et collisions.
