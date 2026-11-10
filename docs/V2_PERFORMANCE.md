# Performance V2

Godot 4.6.3 Compatibility sur Linux x86-64, AMD EPYC 9V45 et rendu logiciel Mesa llvmpipe 25.0.7 à quatre threads de rendu. Mesures de 180 images après mise en chauffe sur Reactor Court, vague 5 en Expert. La limite FPS et la V-Sync ont été désactivées pour le test. Les variantes V1 et V2 utilisent leurs compositions respectives.

| Scénario | Fenêtre | Échelle 3D | Robots actifs | Médiane | p95 | p99 | Dessins médians |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| V1 Faible, baseline | 1280 × 720 | 76 % | 9 | 22,23 ms | 26,54 ms | — | 220 |
| V2 Faible | 1280 × 720 | 76 % | 9 | 15,77 ms | 17,44 ms | 20,04 ms | 239 |
| V2 Ultra faible | 1280 × 720 | 64 % | 7 | 15,14 ms | 18,58 ms | 21,25 ms | 226 |
| V2 Ultra faible | 960 × 540 | 64 % | 7 | 11,17 ms | 14,68 ms | 17,78 ms | 228 |

Le mode Ultra faible désactive les ombres, réduit les étincelles à 24 %, plafonne à sept les robots simultanés et simplifie le shader du sol. Il conserve les signaux d’attaque, les collisions, les compositions et la résolution du HUD. Faible applique 76 % et 46 % d’étincelles. Moyenne applique 89 % et des ombres courtes. Élevée utilise 100 %, des ombres plus longues et le MSAA 2×.

Les cartes combinent les surfaces statiques par secteur et matériau. Les robots partagent les modèles par archétype et espacent leurs recherches de trajet. Les changements de matériau de leur lentille sont limités aux variations visibles. Les projectiles et effets visuels ont une capacité bornée. L’endurance accélérée a enregistré **48,67 Mio** de mémoire statique moteur à la vague 20 et **49,00 Mio** à la vague 100.

| Coop sur 127.0.0.1 | Taille moyenne d’un instantané comprimé | Maximum | Mémoire statique moteur de l’hôte au bilan |
| --- | ---: | ---: | ---: |
| 2 pilotes | 326 octets | 456 octets | 52,73 Mio |
| 4 pilotes | 417 octets | 575 octets | 53,07 Mio |

Les états complets sont comprimés et diffusés environ 15 fois par seconde. Les commandes de mouvement et de tir sont envoyées environ 30 fois par seconde. Ces tailles portent sur les instantanés et excluent les en-têtes UDP/ENet et les autres messages. Les paquets d’état sont découpés à 1 120 octets de données comprimées si nécessaire.

Pour reproduire le benchmark avec un affichage, définissez `NEON_QA_ISOLATED=1` et `NEON_QA_PROFILE_PATH` vers le chemin absolu d’un dossier vide. Les deux arguments sélectionnent le préréglage et la résolution. `0 1` correspond à Faible 720p et `3 0` à Ultra faible 540p.

```sh
godot --path . --disable-vsync --script res://tests/benchmark.gd -- 0 1
godot --path . --disable-vsync --script res://tests/benchmark.gd -- 3 0
```

La fréquence sur Intel N150 reste à mesurer. Les valeurs de rendu logiciel ne prédisent pas les performances du circuit graphique du portable.
