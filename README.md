# Rifle Arena

**[Télécharger v0.0.5 Alpha pour Windows ou Android](https://github.com/Akuriu/neon-rift-arena-/releases/tag/v0.0.5-alpha)**

FPS d’arène en solo contre des bots, avec un stand d’entraînement et un mode survie en coop. Les sept cartes reprennent des lieux comme un dépôt de fret, une chaufferie, une gare et un quartier en brique. L’arsenal comprend huit armes, dont la carabine AR-24, le pistolet P9 Rafale et le fusil à pompe M7.

## Jouer

- **Windows 64 bits** — extraire `RifleArena_Windows_x64.zip` et ouvrir `RifleArena.exe`. Le moteur Godot est inclus. La progression Windows utilise le dossier existant `%APPDATA%\NeonRiftArena`.
- **Android** — ouvrir `RifleArena_Android_alpha.apk` sur le téléphone. Android peut demander d’autoriser l’installation depuis l’application qui a ouvert le fichier. L’APK s’installe sous le nom **Rifle Arena Alpha**, à côté de la v0.0.4, avec un profil local séparé.
- **Coop** — créer un salon privé pour 2 à 4 joueurs en Survie ou Infini. Les joueurs utilisent la même version du jeu. Le port par défaut est UDP 24562. Voir [le guide réseau](docs/V3_NETWORK.md) pour les connexions directes.

## Commandes tactiles

| Action | Geste |
| --- | --- |
| Se déplacer | Utiliser le joystick. |
| Sprinter | Toucher Sprint pour activer la course. Le réglage reste actif quand on lâche le joystick. Retoucher Sprint pour revenir à la marche. |
| Regarder | Glisser à droite de l’écran ou sur le bouton de tir. |
| Tirer et viser | Maintenir le bouton de tir. Toucher la petite mire pour basculer en visée. |
| Sauter, s’accroupir ou glisser | Toucher la flèche pour sauter. Glisser dessus vers le bas pour s’accroupir, ou pour glisser en sprint. |
| Utiliser le gadget | Glisser sur la flèche vers le côté. |
| Recharger et changer d’arme | Toucher le compteur de munitions ou l’icône à deux flèches. |

Dans **Paramètres → Tactile**, on peut inverser la disposition pour gaucher, déplacer les commandes, afficher la disposition complète ou désactiver l’aide à la visée. L’aide ne change jamais la direction de la caméra toute seule. Elle ralentit le geste à proximité d’une cible visible.

## Développement

Le projet s’ouvre avec **Godot 4.6.3 Standard**, rendu Compatibility. Ouvrir `project.godot` et appuyer sur **F5**.

```sh
python3 tools/run_tests.py --suite all
```

[GitHub Actions](.github/workflows/release-alpha.yml) exporte le ZIP Windows et l’APK, exécute le programme Windows et installe puis lance l’APK dans l’émulateur Android avant publication. Les anciennes versions sont accessibles dans [Releases](https://github.com/Akuriu/neon-rift-arena-/releases).

Voir les [crédits et licences](CREDITS.md).
