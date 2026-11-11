# Suivi des anomalies

| ID | Priorité | Reproduction et cause | Vérification | État |
| --- | --- | --- | --- | --- |
| RA-01 | P0 | Mettre `{"version":{},"settings":{"layout":1}}` dans un profil jetable. Le constructeur `int(Dictionary)` interrompt `Prefs.load_disk` avant `apply_keys`. Le lancement reproduit `Invalid call. Nonexistent 'int' constructor.` et `InputMap.has_action("fire") == false`. | `tests/profile_recovery.gd`. 11 contrôles réussis. Conservation du contenu corrompu par SHA-256, récupération v5 et profil neuf compris. | Corrigé par le commit qui introduit ce test. |
| RA-02 | P1 | Lancer v0.0.7a avec caches neufs. Le chargement des prérequis de la scène et des 45 WAV précède la première image. | `tests/boot_flow.gd` et `tests/polish_render.gd`. Première composition rendue avant lecture de la scène et des boucles audio. | Bootstrap et lecture audio à la demande livrés au lot B. |
| RA-03 | P1 | Ouvrir Jouer, les paramètres ou l’arsenal depuis l’accueil. La scène 3D de fond et sa caméra restent actives. | Le fond 3D est réservé aux qualités Moyenne et Élevée et libéré en quittant l’accueil. | Traitement initial au lot B. |
| RA-04 | P1 | Démarrer une partie en fenêtre depuis la sélection. La carte est construite d’un bloc pendant le callback du bouton. | `tests/map_loading.gd` et `tests/polish_render.gd`. Chargement visible, requête unique, annulation et remplacement de la session. | Transition solo livrée au lot B. La construction procédurale reste sur le thread principal. |
| RA-05 | P1 | Ouvrir la saisie d’une touche. Le panneau d’origine n’interceptait que les clics sur son rectangle, ce qui laissait les onglets derrière accessibles. | `tests/ui_motion.gd` couvre la garde d’onglet, l’interception et la restauration du focus. | Modale plein écran au lot C. |
| RA-06 | P1 | Remplir le pool d’effets en Élevée puis passer en Ultra faible. Les emplacements supérieurs au nouveau budget restaient visibles et le curseur pouvait en sélectionner un. | `tests/vfx_budget.gd` exerce 149 effets, la réduction à 64, le retour au repos et la densité nulle. | Corrigé au lot F. |

Les campagnes de navigation rapide, de reprise Android, d’endurance fenêtrée et de réseau sur appareils restent à exécuter.
