# Suivi des anomalies

| ID | Priorité | Reproduction et cause | Vérification | État |
| --- | --- | --- | --- | --- |
| RA-01 | P0 | Mettre `{"version":{},"settings":{"layout":1}}` dans un profil jetable. Le constructeur `int(Dictionary)` interrompt `Prefs.load_disk` avant `apply_keys`. Le lancement reproduit `Invalid call. Nonexistent 'int' constructor.` et `InputMap.has_action("fire") == false`. | `tests/profile_recovery.gd`. 11 contrôles réussis. Conservation du contenu corrompu par SHA-256, récupération v5 et profil neuf compris. | Corrigé par le commit qui introduit ce test. |
| RA-02 | P1 | Lancer v0.0.7a avec caches neufs. Le chargement des prérequis de la scène et des 45 WAV précède la première image. | Mesures `BASELINE.md`. Comparer première image et menu interactif sur le même banc. | Mesuré. Traitement au lot B. |
| RA-03 | P1 | Ouvrir Jouer, les paramètres ou l’arsenal depuis l’accueil. La scène 3D de fond et sa caméra restent actives. | Comparer les dessins de l’accueil puis des sous-menus. | Observé dans le code. Traitement au lot D. |
| RA-04 | P1 | Démarrer une partie en fenêtre depuis la sélection. La carte est construite d’un bloc pendant le callback du bouton. | Mesure headless de construction, puis test de fenêtre du chargement et des relances. | Mesuré. Traitement au lot B. |

Les campagnes de navigation rapide, de reprise Android, d’endurance fenêtrée et de réseau sur appareils restent à exécuter.
