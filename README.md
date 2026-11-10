# NEON RIFT ARENA V3 · COMPLETE REFORGE

FPS d’arène hors ligne et en coop privée pour 2 à 4 joueurs. Cette version part des sources Godot de la V2 et conserve ses armes, sa progression locale, ses boss, son serveur dédié et ses modes.

## Jouer

- **Windows x64.** Décompressez l’archive Windows dans un dossier puis ouvrez **NeonRiftArenaV3.exe**. Le jeu est contenu dans l’exécutable.
- **Projet.** Décompressez l’archive des sources, importez **project.godot** dans **Godot 4.6.3 Standard**, puis appuyez sur **F5**. Le paquet **build/NeonRiftArenaV3.pck** peut aussi être lancé via **JOUER_WINDOWS.bat** avec le moteur Godot.
- **Android.** L’APK de débogage est une application Godot native en paysage avec commandes tactiles. Consultez [l’installation et les limites de validation](docs/ANDROID_PORT.md).

Le solo fonctionne sans connexion et conserve sa progression entre les parties. Les **CR** de terrain expirent à la fin d’une opération. Les **pièces du pilote** et l’XP sont enregistrées dans le profil local à la clôture.

## Modes

| Mode | Fonctionnement |
|---|---|
| Survie 20 | Vingt vagues, quatre boss et choix d’extraction ou de prolongation en Infini |
| Survie 10 | Dix vagues avec ravitaillement et deux boss |
| Infini | Renforts continus, mutateurs et paliers 25, 50, 75, 100. Extraction entre deux vagues |
| Défi chronométré | Quinze robots en 90 secondes |
| Boss Rush | Quatre boss et trois ravitaillements |
| Entraînement | Huit armes en prêt. Dans Pause, sélectionnez des cibles fixes, mobiles ou aériennes, une distance et un chrono |
| FPS Classique | Match chacun pour soi contre bots. Sélection du score, du temps, de la graine et de l’effectif |
| Équipes | Escarmouche avec alliés, adversaires, score d’équipe et réapparition |
| Capture et Domination | Un point ou trois points de contrôle avec contestation |
| Exploration et Détente | Visite libre des arènes ou cinq vagues à rythme modéré. Sessions libres |

Reactor Court, Skyline Depot et Cryo Foundry restent accessibles. Bastion Relay, Meridian District, Ashgrove Ruins et Transit Hall ajoutent une base, une place urbaine, des ruines en forêt et une station couverte. La sélection montre une capture issue de chaque carte.

Le style **Classique / Normal** est actif au premier lancement. **Néon raffiné**, **Cinématique** et **Arcade coloré** sont accessibles dans le menu et les paramètres. Le style est indépendant des règles de match.

## Commandes et confort

| Action | Clavier et souris |
|---|---|
| Se déplacer | ZQSD ou WASD selon la disposition |
| Regarder, tirer, viser | Souris, clic gauche, clic droit |
| Saut, sprint, accroupissement | Espace, Maj, Ctrl |
| Recharger, interagir, gadget | R, E, G |
| Armes, zoom du Rail | 1–4 ou molette. En visée Rail, molette pour ×2 / ×4 |
| Inspecter, journal, pause | I, Tab, Échap |

Les paramètres permettent de réassigner le clavier et de régler le FOV, le contraste, le HUD, la lunette, la sensibilité, les mouvements de caméra, les effets et les volumes. Sur Android, utilisez **Paramètres → Tactile → Modifier la disposition** pour déplacer et redimensionner chaque commande. Le profil mobile démarre en Ultra Léger, à 45 images par seconde maximum.

## Profil, arsenal et boutiques

La boutique du pilote présente les armes en 3D, leurs caractéristiques, leur maîtrise et leur comparaison avec l’emplacement choisi. Les armes sont essayables au stand. La configuration rapide équipe les objets possédés, avec quatre préréglages et une configuration personnelle enregistrable.

Le profil regroupe statistiques par mode, contrats quotidiens, défi hebdomadaire, succès, 32 bilans rejouables et 48 reçus. La migration préserve le profil V2 et crée une copie `pilot_profile.v2.json` au premier enregistrement. Godot utilise `user://`. Sous Windows, le dossier de profil est habituellement `%APPDATA%\NeonRiftArena`.

## Coop privée

Choisissez **Coop**, hébergez un salon ou entrez l’adresse et le port de l’hôte. Les pilotes se déclarent prêts avant le départ. Les modes Survie, Patrouille et Infini restent disponibles. L’hôte arbitre les vagues, dégâts et achats. Tous les joueurs utilisent le protocole V3. Voir [connexion locale et serveur dédié](docs/V3_NETWORK.md).

## Vérifier et reconstruire

```sh
python3 tools/run_tests.py --suite all
godot --headless --path . --export-release "Windows x64" build/NeonRiftArenaV3.exe
godot --headless --path . --export-debug Android build/NEON_RIFT_ARENA_V3_Android_debug.apk
```

Créez le dossier `build` et installez les modèles d’export **4.6.3 Standard** avant de reconstruire. Python 3 sert uniquement au banc de tests. Pour les tests avec interface et son, voir [la validation](docs/V3_QA_REPORT.md). Pour reprendre le développement et l’historique Git, voir [le passage de relais](docs/V3_HANDOFF.md).

[221 étapes](docs/V3_RAPPORT_221.md) · [Performances](docs/V3_PERFORMANCE.md) · [Direction artistique](docs/V3_ART_DIRECTION.md) · [Changements V3](CHANGELOG_V3.md) · [Crédits](CREDITS.md)
