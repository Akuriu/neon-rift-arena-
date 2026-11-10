# Rifle Arena

**v0.0.7 Alpha en développement.** Gun Game et Parkour sont jouables sur la branche `feature/v0.0.7` ; les builds Preview se trouvent dans la [PR #2](https://github.com/Akuriu/neon-rift-arena-/pull/2). La publication officielle reste bloquée par les validations matérielles et la signature Android d’origine. [Téléchargements publiés pour Windows et Android](https://github.com/Akuriu/neon-rift-arena-/releases)

FPS d’arène en solo contre des bots, avec un stand d’entraînement et un mode survie en coop. Les sept cartes reprennent des lieux comme un dépôt de fret, une chaufferie, une gare et un quartier en brique. L’arsenal comprend huit armes, dont la carabine AR-24, le pistolet P9 Rafale et le fusil à pompe M7.

## Jouer

- **Windows 64 bits** — extraire `RifleArena_Windows_x64.zip` et ouvrir `RifleArena.exe`. Le moteur Godot est inclus. La progression Windows utilise le dossier existant `%APPDATA%\NeonRiftArena`.
- **Android** — ouvrir `RifleArena_Android_alpha.apk` sur le téléphone. Android peut demander d’autoriser l’installation depuis l’application qui a ouvert le fichier. L’APK v0.0.6 conserve le paquet `com.riflearena.alpha`. La mise à jour sur la v0.0.5 dépend de la signature d’origine.
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

Dans **Paramètres → Tactile**, choisissez Simple, Complet ou Gaucher. Le mode Personnalisé garde vos positions. L’éditeur propose un aperçu plein écran et permet de rétablir une commande seule. Vous pouvez aussi régler la course du joystick, les deux axes de visée et la vitesse maximale des glissements. L’aide facultative ralentit le geste à proximité d’une cible visible.

## Développement

Le projet s’ouvre avec **Godot 4.6.3 Standard**, rendu Compatibility. Ouvrir `project.godot` et appuyer sur **F5**.

```sh
python3 tools/run_tests.py --suite all
```

[Les vérifications GitHub Actions](.github/workflows/test.yml) testent le jeu et préparent un APK de revue et un ZIP Windows. [La publication](.github/workflows/release-alpha.yml) exige le tag correspondant à `project.godot` et valide les deux installateurs avant de rendre la release visible.

L’APK de revue apparaît sous le nom **Rifle Arena Preview**. Il s’installe à côté de l’Alpha avec son propre profil, pour permettre les essais sur téléphone.

Pour la publication Android, les secrets du dépôt `RIFLE_ANDROID_KEYSTORE` (keystore encodé en Base64), `RIFLE_ANDROID_ALIAS` et `RIFLE_ANDROID_PASSWORD` doivent désigner la clé d’origine. La CI compare les certificats et vérifie l’installation par-dessus l’APK précédente. Gardez le fichier de clé hors du dépôt.

Après les essais matériels du [suivi QA](docs/V0.0.6_QA.md), renseigner la variable GitHub Actions `RIFLE_HARDWARE_QA_TAG` avec le tag validé. Le contrôle de publication exige cette valeur pour chaque nouvelle version.

[Journal des changements](CHANGELOG.md) · [Suivi des essais v0.0.6](docs/V0.0.6_QA.md)

Voir les [crédits et licences](CREDITS.md).
