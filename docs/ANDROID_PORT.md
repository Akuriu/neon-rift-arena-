# Portage Android natif

L’export **Android** utilise le même projet Godot 4.6.3 Standard, le rendu Compatibility, la logique FPS, la sauvegarde locale et le protocole coop que Windows. Le paquet de débogage est `com.neonrift.arena`, version 3.0.0, code 300. Il contient les bibliothèques **arm64-v8a** et **x86_64**. Le minimum déclaré est API 24 et la cible est API 36. La validation physique est détaillée dans `ANDROID_TESTS.md`.

## Installation et commandes

Transférez l’APK sur le téléphone, ouvrez-le dans le gestionnaire de fichiers et suivez le dialogue d’installation d’Android. Sur un appareil de développement déjà connecté à ADB, `adb install NEON_RIFT_ARENA_V3_Android_debug.apk` installe le paquet.

Le jeu s’ouvre en paysage. Glissez sur la partie libre de l’écran pour viser. Le joystick, le tir et la visée acceptent plusieurs doigts en même temps. Les commandes affichent saut, sprint, glissade, gadget, recharge, interaction, zoom, changement d’arme, journal et pause. Le zoom manuel ×2 / ×4 est celui du Rail. **Paramètres → Tactile** règle les axes, la zone morte, la main, les vibrations facultatives et la disposition de chaque commande.

Le profil mobile réduit la résolution interne à 64 %, limite le nombre de robots et les effets, et démarre à 45 FPS maximum. Les plafonds 30, 45 et 60 sont disponibles. La densité des effets et le confort de caméra sont réglables. Les mesures PC et le profil mobile ne permettent pas de déduire les performances d’un téléphone.

## Reconstruction

1. Installez Godot **4.6.3 Standard** et ses modèles officiels. Le modèle `android_debug.apk` est indispensable au preset de cette livraison.
2. Configurez **Java SDK Path** et **Android SDK Path** dans les paramètres de l’éditeur. L’export de cette livraison a utilisé OpenJDK 21, Android SDK Platform 36, Platform Tools et Build Tools 36.0.0.
3. Configurez un certificat de débogage local dans Godot ou par ses variables d’environnement `GODOT_ANDROID_KEYSTORE_DEBUG_PATH`, `GODOT_ANDROID_KEYSTORE_DEBUG_USER` et `GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD`.
4. Créez `build` et lancez `godot --headless --path . --export-debug Android build/NEON_RIFT_ARENA_V3_Android_debug.apk`.

L’export utilise les modèles précompilés sans build Gradle. Pour un AAB, installez le modèle de build Android, activez Gradle et sélectionnez AAB. Utilisez une clé de publication protégée dans votre environnement. [Documentation Godot pour Android](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html) · [Cible SDK dans Godot 4.6.3](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/android/export/export_plugin.cpp)

## Portabilité et données

Les modes de fenêtre, la capture de souris et les réglages de résolution PC sont séparés du chemin Android. La simulation réutilise les actions InputMap. L’interface prend en compte la zone sûre signalée par Android. Une suspension demande la pause du solo, relâche les doigts, met en pause les pistes et force l’écriture des réglages en attente. En coop, l’hôte continue et une suspension prolongée peut interrompre la connexion.

La sauvegarde `user://pilot_profile.json` utilise le même schéma sur PC et Android. Elle reste locale dans le répertoire de l’application. Le transfert manuel dépend de l’accès au répertoire d’application. Le jeu ne comporte aucun transfert de profil automatique. Le réseau utilise Internet pour les salons directs et le vibreur est facultatif.
