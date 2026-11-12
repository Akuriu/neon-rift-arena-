# Suivi de la refonte

| Lot | État | Vérification et reste à faire |
| --- | --- | --- |
| A · Audit et données | En place | Baseline Linux, reproduction du bug de profil et 11 contrôles de récupération. Les appareils cibles restent à mesurer. |
| B · Démarrage et cartes | En place en solo et en coop | `boot_flow.gd`, `map_loading.gd`, `coop_loading.gd`, `polish_render.gd`. Le compteur suit les surfaces assemblées. Le serveur dédié conserve son démarrage direct. |
| C · Motion et navigation | En place sur les composants partagés | Boutons réactifs, surface de navigation retargetable, focus et onglet Accessibilité. `ui_motion.gd` couvre quatre cadences simulées et le retour de focus. |
| D · Écrans | Accueil, Jouer, réglages, pause, HUD, arsenal, lobby, bilan et progression retravaillés | Score et XP vérifiés après un résultat du moteur. Progression de niveau, contrats et état vide du classement rendus en fenêtre. |
| E · 3D et présentation | Sept cartes, trois parcours et ouverture en 3D | L’ouverture dévoile la vue jouable et respecte le mouvement réduit. Voir `ART_PASS.md` pour la direction artistique et `BASELINE.md` pour les mesures. |
| F · Audio et VFX | Première passe livrée | 48 sons, dont trois cues d’interface originaux, fondu croisé d’ambiance, impacts et pool par qualité. `ui_audio.gd` et `vfx_budget.gd`. |
| G · Profilage | Banc et tests automatisés | `combat_render_benchmark.gd` compare le rendu de douze bots. Les surfaces des personnages et de l’équipement sont groupées par finition, avec leurs couleurs et leurs poses. |
| H · Preview | Version de travail v0.0.7b Alpha | La CI exige l’arrivée au menu de l’EXE et de l’APK Preview. Elle produit les captures et les installateurs avec leurs SHA-256. Les résultats du commit exact sont suivis dans la PR #3. |

Le 11 novembre 2026, le test en fenêtre du lot B a capturé la première image, le menu, Jouer, le chargement du Dépôt et la pause. Sur ce passage à 1280 × 720 avec Mesa llvmpipe, la première composition arrive à 556 ms et le menu interactif à 1 864 ms depuis la demande de scène du banc. La référence affichait l’accueil à 4 088 ms. Ces passages uniques comprennent les premières compilations du rendu. L’itération de comparaison doit être répétée isolément. Les captures sont tirées du viewport Godot.

Le protocole ENet 4 conserve ses RPC. L’état de vague et le bilan fiables sont appliqués après l’attachement du client. La déconnexion et l’annulation libèrent la scène partielle. La génération initiale du plan, les collisions et la compilation OpenGL restent à mesurer sur les appareils cibles. Le budget de 3 ms s’applique entre deux surfaces assemblées.

Honor 400 Lite, Intel N150 et Wi-Fi PC/téléphone sont `NOT_TESTED_PHYSICAL`. La publication officielle dépend toujours de la clé Android d’origine et de la validation matérielle.
