# Graphismes et animation · v0.0.7b

Les plans de circulation, points d’apparition et collisions gardent la géométrie de simulation. Les nouveaux réservoirs techniques sont en dehors du périmètre jouable et sont purement visuels. Les surfaces de jeu conservent les repères et reçoivent des variations de patine et de joints par secteur.

| Arène | Passage graphique | Dessins en v0.0.7a → v0.0.7b |
| --- | --- | ---: |
| Reactor | Ciel minéral, béton des zones techniques, tours de service | 336 → 334 |
| Dépôt de fret | Soleil plus rasant, acier et gravier chaud, réservoirs hors clôture | 410 → 393 |
| Fonderie | Haze froid, acier bleuté et éclairage d’appoint froid | 206 → 205 |
| Bastion | Éclairage sec, terre claire et usure des zones exposées | 122 → 121 |
| Quartier | Briques et teintes chaudes, joints de chaussée et ciel couvert | 218 → 222 |
| Bosquet | Teintes de sous-bois, chemin et horizon plus chauds | 163 → 156 |
| Gare | Patine froide, joints de dalle et éclairage d’appoint intérieur | 196 → 196 |

Captures de `tests/arena_gallery.gd` en 1280 × 720, préréglage Moyenne, graine 64071 et huit images d’attente. Le point de vue est identique pour chaque paire. Trois parcours Parkour ont aussi été rendus. Les dessins sont le relevé de la dernière image du scénario, dans Mesa llvmpipe. Les valeurs de triangles et de mémoire vidéo matérielle restent à relever.

Le rendu reste Compatibility. Faible et Ultra faible évitent le deuxième échantillonnage de patine du sol et la lumière locale du terminal. Les qualités Moyenne et Élevée utilisent une lumière d’appoint sans ombre par carte. Les ombres directionnelles et les matériaux gardent leur budget de préréglage.

La caméra visuelle amortit le pas avec une courbe continue. Les opérateurs déplacent légèrement le poids du bassin, adoucissent le retour du pied et réinitialisent leur pose visuelle après réapparition. Les calculs de déplacement, de tir et d’autorité réseau conservent leur chemin de simulation.
