# Validation Android

**TEST SUR TÉLÉPHONE PHYSIQUE NON RÉALISÉ**

| Vérification | Résultat |
|---|---|
| Export Godot | APK de débogage produite avec le modèle officiel 4.6.3 |
| Signature | `apksigner verify` réussi, schémas v2 et v3 |
| Alignement et contenu | `zipalign -c -P 16 4` et CRC ZIP réussis. Bibliothèques ELF 64 bits ARM et x86-64 vérifiées |
| Manifeste | `com.neonrift.arena`, version 3.0.0, API 24 déclarée et cible 36, activité de lancement en paysage |
| Permissions déclarées | Internet pour ENet et vibreur facultatif |
| Commandes | 12 vérifications sous Linux via `--touch` et de vrais événements Godot ScreenTouch et ScreenDrag |
| Cycle de vie | Pause, libération des doigts, écriture de la disposition et reprise simulées |
| Émulateur | Images x86_64 API 35 et API 30 tentées en émulation logicielle. La validation est restée bloquée au démarrage d’Android, avant lancement du jeu |
| Téléphone | Installation, fluidité, chauffe, audio natif, encoches, autonomie et coop Android ↔ PC restent à vérifier |

```sh
python3 tools/run_tests.py --suite solo
apksigner verify --verbose NEON_RIFT_ARENA_V3_Android_debug.apk
zipalign -c -P 16 4 NEON_RIFT_ARENA_V3_Android_debug.apk
```

Le fichier `docs/validation/android-verification.log` contient la vérification du paquet fourni. L’APK est signée pour débogage. Le preset et le projet suffisent pour la reconstruire avec votre propre certificat de développement.
