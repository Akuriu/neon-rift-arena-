# Validation de la V2

Tests exécutés avec **Godot 4.6.3 stable**, Linux x86-64, profils temporaires séparés. La suite principale se rejoue avec `python tools/run_tests.py --godot godot`. L’option `--logs` garde un journal par scénario et ses sauvegardes de test dans un nouveau dossier.

| Scénario | Résultat attendu et vérifié |
| --- | --- |
| Non-régression V1 | 51 contrôles, dont les commandes, les mouvements, les collisions, les deux cartes, la pause, les relances, les réglages et les records |
| Survie 20 | Cryo Foundry en Découverte. 20 vagues, 19 intermissions, 164 éliminations, 594 tirs et 579 impacts. 80 601 points au bilan |
| Survie 10 | Skyline Depot en Découverte. 10 vagues, 65 éliminations et 24 654 points |
| Défi chronométré | Reactor Court. 15 éliminations en 19,32 s simulées. Expiration à 90 s couverte en régression |
| Boss Rush | Reactor Court. Quatre boss, trois ravitaillements et 19 éliminations |
| Générateur | 3 000 compositions vérifiées. Transitions 6→7, 20→21, 49→50 et 99→100 |
| Endurance Infini | 101 vagues jouées dans la scène avec neutralisations accélérées. Achats, extraction, versement et nettoyage vérifiés |
| Armes | Tir avec les huit armes en Entraînement. Zoom, charge, impact et sortie de visée vérifiés pour les deux snipers |
| Profil et économie | Import d’un ancien JSON, copie V1 exacte, touche G déjà utilisée, mute, record, temporaire tronqué, reçus, nouveau profil et équipement après relecture |
| Coop | Hôte + 1 puis hôte + 3 sur 127.0.0.1, vrais tirs à la vague 6 et transition à 7. Achats autoritaires, rejeu et paramètres invalides, déconnexion et reprise |
| Serveur dédié | Processus sans rendu, deux invités, lancement autonome, premiers spawns et retour au salon après départ |
| Rendu | Fenêtre 720p et 540p, capture souris, plein écran, signal audio mixé, navigation, lunettes et achats |
| Export | Le PCK et le paquet embarqué dans le PE Windows s’ouvrent avec le moteur Linux hors du projet et chargent le menu, la coop, le hangar, Cryo et le Rail |

Les parties solo complètes sont pilotées par un script qui utilise les actions de contrôle et les tirs du joueur. Le test réseau accélère les vagues 1 à 5 et la fin de la vague 7 pour isoler les transitions, puis fait combattre chaque pilote à la vague 6 avec les dégâts du moteur. Le test Infini accélère les neutralisations et observe les paliers, la sauvegarde et le coût mémoire.

Pour les contrôles graphiques, ouvrez une session d’affichage. Préparez un dossier vide et définissez `NEON_QA_ISOLATED=1` et `NEON_QA_PROFILE_PATH` vers son chemin absolu. Lancez depuis les sources.

```sh
godot --path . --script res://tests/render_check.gd
```

L’environnement de test ne dispose ni du portable Intel N150 ni d’une machine Windows native. La connexion réseau est validée en boucle locale et la stabilité sous latence WAN reste à mesurer.
