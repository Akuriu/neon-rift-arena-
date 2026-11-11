# Suivi de la refonte

| Lot | État | Vérification et reste à faire |
| --- | --- | --- |
| A · Audit et données | En place | Baseline Linux, reproduction du bug de profil et 11 contrôles de récupération. Les appareils cibles restent à mesurer. |
| B · Démarrage et cartes | En place pour l’ouverture client et les demandes solo | `boot_flow.gd`, `map_loading.gd`, `polish_render.gd`. La simulation du serveur passe par une scène dédiée. La construction des cartes est synchrone sous le masque. La coop conserve son démarrage réseau existant. |
| C · Motion et navigation | En place sur les composants partagés | Boutons réactifs, surface de navigation retargetable, focus et onglet Accessibilité. `ui_motion.gd` couvre quatre cadences simulées et le retour de focus. |
| D · Écrans | Accueil, Jouer, réglages, pause, HUD, arsenal et lobby retravaillés | `ui_navigation.gd` vérifie le cache 3D et la fermeture du salon. Résultats et progression utilisent le thème et les transitions partagés, avec leurs dispositions existantes. |
| E · 3D et présentation | Premier passage sur les sept cartes | Éclairage et matériaux par arène, aperçu rendu des trois parcours, trajectoire de pas et reprise de pose. Voir `ART_PASS.md`. |
| F · Audio et VFX | Première passe livrée | 48 sons, dont trois cues d’interface originaux, fondu croisé d’ambiance, impacts et pool par qualité. `ui_audio.gd` et `vfx_budget.gd`. |
| G · Profilage | Banc et tests automatisés | `boot_benchmark.gd`, `benchmark.gd` et 21 cycles d’entrée, pause, reprise et retour sur les sept cartes. Le serveur ne construit plus le décor ni le pool d’effets de l’arène. |
| H · Preview | Version de travail v0.0.7b Alpha | La CI exige l’arrivée au menu de l’EXE et de l’APK Preview. Elle produit les captures et les installateurs avec leurs SHA-256. Les résultats du commit exact sont suivis dans la PR #3. |

Le 11 novembre 2026, le test en fenêtre du lot B a capturé la première image, le menu, Jouer, le chargement du Dépôt et la pause. Sur ce passage à 1280 × 720 avec Mesa llvmpipe, la première composition arrive à 556 ms et le menu interactif à 1 864 ms depuis la demande de scène du banc. La référence affichait l’accueil à 4 088 ms. Ces passages uniques comprennent les premières compilations du rendu. L’itération de comparaison doit être répétée isolément. Les captures sont tirées du viewport Godot.

Vérification locale d’ENet après séparation du serveur. Deux clients entrent dans la même partie, voient le robot et le serveur revient à son état d’attente. Protocole 4.

Honor 400 Lite, Intel N150 et Wi-Fi PC/téléphone sont `NOT_TESTED_PHYSICAL`. La publication officielle dépend toujours de la clé Android d’origine et de la validation matérielle.
