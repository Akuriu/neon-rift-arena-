# NEON RIFT ARENA V3 · Rapport des 221 étapes

**151 terminées · 65 partielles · 4 non réalisées · 1 non testable.**

Ce rapport reprend les titres du cahier des charges et distingue le code livré, les vérifications réalisées et leurs limites. Les tests graphiques ont tourné sous Linux avec Godot 4.6.3. Les mesures de performance utilisent le rendu logiciel Mesa llvmpipe.

Les fichiers et résultats détaillés sont regroupés dans V3_AUDIT, V3_QA_REPORT, V3_PERFORMANCE et ANDROID_TESTS. **TEST SUR TÉLÉPHONE PHYSIQUE NON RÉALISÉ.**

| Étape | Cahier des charges | Statut | Réalisation, preuve ou limite |
|---:|---|---|---|
| 001 | Inventaire reproductible | Terminé | Archive V2 validée et identifiée par SHA-256. Inventaire dans V3_AUDIT et commit v2.0-baseline. |
| 002 | Audit des fonctionnalités | Terminé | Modes, huit armes, profil, boutique, serveur et coop recensés et exercés dans la baseline. |
| 003 | Audit des sensations | Partiel | Caméra liée à la physique et reconstruction de modèle repérées. Pas de mesure de latence matérielle V2. |
| 004 | Audit des scripts critiques | Terminé | App, Session, Player, Arsenal, Drone, Coop et Prefs revus. Dépendances dans V3_HANDOFF. |
| 005 | Audit des contenus | Terminé | Inventaire des scènes, armes, robots, sons, cartes et sauvegardes dans V3_AUDIT. |
| 006 | Audit des scènes réelles | Terminé | App, Session, Pilot et Drone ouverts par les tests et les captures. |
| 007 | Baseline automatisée | Terminé | 222 assertions de baseline V2 passées, y compris salons et serveur. |
| 008 | Baseline visuelle | Terminé | Captures des trois cartes, du menu, de l’arsenal et des armes de la V2. |
| 009 | Baseline de performances | Terminé | Deux mesures reproductibles avant refonte dans V3_PERFORMANCE. |
| 010 | Plan de livraison exécutable | Terminé | Jalons de référence, jeu, QA et export exécutés, avec reprise Git locale. |
| 011 | Système de styles indépendants | Terminé | Autoload Art et règles Classic séparés. Quatre thèmes utilisables dans le même match. |
| 012 | Style Classique / Normal | Terminé | Matériaux mats, ciel diurne, végétation, émissions très basses. Captures de comparaison. |
| 013 | Style Néon remasterisé | Terminé | Palette Néon indépendante et intensité réglable. Captures des mêmes cartes. |
| 014 | Style Cinématique | Terminé | Palette de coucher de soleil, matériaux ardoise et soleil chaud. |
| 015 | Style Coloré Arcade | Terminé | Palette Arcade avec pigments plus vifs et fonds clairs. |
| 016 | Palette par matériau | Terminé | Matériaux partagés et variantes calculées dans art/direction.gd et Fabric.Batch. |
| 017 | Harmonies calculées | Partiel | Harmonies calculées par luminosité et température. Aucun audit perceptuel automatisé. |
| 018 | Lisibilité en action | Partiel | HUD contrasté, signal de danger, marqueurs d’équipe par forme et couleur. Pas de panel utilisateur. |
| 019 | Personnalisation indépendante | Terminé | Teinte HUD, réticule, émissions, contraste, météo et brume contrôlables séparément. |
| 020 | Transition esthétique contrôlée | Partiel | Interpolation de matières sur 0,23 s. Le ciel et les réglages d’environnement basculent directement. |
| 021 | Audit des modèles procéduraux | Terminé | Modèles procéduraux, caches et géométries V2 recensés dans l’audit. |
| 022 | Bibliothèque de matériaux | Terminé | Bibliothèque Fabric partagée et familles de matières dans Art. |
| 023 | Bibliothèque d'accessoires | Partiel | Accessoires partagés dans frontiers.gd et scenery.gd. Bibliothèque d’édition manuelle limitée. |
| 024 | Architecture crédible | Terminé | Soutes, façades et quais fonctionnels. Sept cartes explorées dans v3_modes. |
| 025 | Sol vivant | Terminé | Sol antialiasé, joints et variation de détail. Chemin naturel pour les ruines. |
| 026 | Décors naturels non néon | Terminé | Végétation, sous-bois et formes minérales dans le décor de jour. |
| 027 | Silhouettes d'armes retravaillées | Partiel | Huit silhouettes V2 conservées et pièces animables. Refonte intégrale de tous les maillages non réalisée. |
| 028 | Robots lisibles | Terminé | Robots distinguables par formes, lentilles, marche, vol et anticipation. |
| 029 | Pipeline d'import optionnel | Non réalisé | Pipeline glTF/Blender dédié non ajouté. Géométrie générée nativement par Godot. |
| 030 | Densité de détail hiérarchisée | Partiel | Géométrie groupée par secteur et LOD de membres. Pas de comparaison exhaustive par distance. |
| 031 | Environnements par thème | Terminé | Environment, lumière et matières définis par carte et thème. |
| 032 | Ciel naturel | Terminé | Gradient, lumière solaire et nuages légers avec chemin simplifié Faible/Ultra. |
| 033 | Matériaux PBR cohérents | Partiel | Rugosité et métal calibrés. Aucun ensemble de textures PBR importées. |
| 034 | Ombres économes | Terminé | Ombres de soleil limitées selon le preset. Pas d’ombres dynamiques en Faible/Ultra. |
| 035 | Lumières d'accent localisées | Partiel | Accents matérialisés et signalétique. Les nouvelles cartes n’ajoutent pas de lumières locales coûteuses. |
| 036 | Ambient occlusion de substitution | Non réalisé | Occlusion ambiante précalculée spécifique non mise en œuvre. |
| 037 | Brume et profondeur | Terminé | Brume réglable en Moyenne/Élevée et valeurs distinctes par carte. |
| 038 | Météo facultative | Partiel | Poussière et neige optionnelles implémentées et limitées par preset. Pas de mesure longue avec météo. |
| 039 | Anti-crénelage maîtrisé | Partiel | Joints antialiasés et MSAA 2× en Élevée. Pas de mesure exhaustive du scintillement. |
| 040 | Validation multi-résolution | Terminé | Régression graphique 960×540 et 1280×720, bascule plein écran et retour fenêtré. |
| 041 | Pipeline d'input stable | Terminé | InputMap partagé, événements de visée directs, repère balistique conservé. |
| 042 | Accélération progressive maîtrisée | Terminé | Accélération vectorielle, freinage sol et contrôle en l’air dans locomotion.gd. |
| 043 | Sprint lisible | Terminé | Sprint, pose et FOV réglables. Régression déplacement et transitions. |
| 044 | Glissade soignée | Terminé | Glissade avec courbe de vitesse et arrêt sur obstacle frontal. |
| 045 | Accroupissement sans saut caméra | Terminé | Capsule et hauteur séparées. Test de plafond bas et redressement dans v3_feeling. |
| 046 | Saut confortable | Terminé | Tampon de saut et délai de bord de marche. Régression saut et atterrissage. |
| 047 | Dash fiable | Terminé | Dash dans la direction choisie et arrêt contre obstacle. Régression gadget et déplacement. |
| 048 | Marches et pentes | Partiel | Rampes existantes et nouvelles. Aucun système additionnel de franchissement automatique d’escaliers. |
| 049 | Absence de micro-tremblement | Partiel | Position physique interpolée et direction directe. Pas de mesure instrumentée de micro-tremblement. |
| 050 | Paramètres de mouvement | Terminé | Sprint et accroupissement en maintien ou bascule. Sensibilité, confort, FOV et glissade. |
| 051 | Rig caméra séparé | Terminé | Caméra de présentation distincte du point de tir, test v3_feeling. |
| 052 | Interpolation dépendante du temps | Terminé | Amortissements exponentiels dépendants du delta de rendu. |
| 053 | Idle subtil | Terminé | Pose de repos à courbes progressives et mouvement réglable. |
| 054 | Walk bob de qualité | Terminé | Oscillation liée à la distance parcourue. Désactivable. |
| 055 | Landing feedback | Terminé | Atterrissage avec ressort borné et intensité réglable. |
| 056 | Strafe et inclinaison | Terminé | Inclinaison latérale visuelle, repère de tir indépendant. |
| 057 | Collision arme/décor | Terminé | Rétraction face aux obstacles et origine de traînée protégée par raycast. |
| 058 | Transitions de vue | Terminé | Visée et retour de lunette amortis, zoom Rail ×2 et ×4 vérifié. |
| 059 | Vue troisième personne en coop | Terminé | Avatar des pilotes distants avec poses répliquées dans les tests coop. |
| 060 | Mode confort caméra | Terminé | Caméra stable, confort, flashs et particules séparément réglables. |
| 061 | Machine à états d'animation | Terminé | Machine à états et courbes dans game/weapons/view_animation.gd. |
| 062 | Animation d'équipement | Terminé | Cache du modèle et transitions. 24 swaps contrôlés, une seule arme visible. |
| 063 | Reload en plusieurs phases | Terminé | Ouverture, manipulation de cellule, fermeture. Test d’annulation sans double transfert. |
| 064 | Tir animés individualisés | Terminé | Profils d’impulsion de huit armes, liés à leur famille et à leur cadence. |
| 065 | Charge d'énergie lisible | Terminé | Pose de charge, mouvement de noyau et annulation vérifiée. |
| 066 | Surchauffe expressive | Terminé | Pose de surchauffe, jauge et choix d’effets de confort. |
| 067 | Inspections authentiques | Partiel | Inspection par arme avec interruption. Matrice complète de transitions non automatisée. |
| 068 | Animation d'ADS | Terminé | Lunette progressive, FOV et masque de zoom vérifiés. |
| 069 | Animations à la troisième personne | Partiel | Bras, sprint, glissade, dash, ADS et recharge distants. Pas de montage de poses manuel filmé. |
| 070 | Outils pour ajuster le feeling | Terminé | Tables de réglage documentées, scène d’entraînement et scénarios v3_feeling. |
| 071 | Architecture arme data-driven | Terminé | Catalogue data-driven et présentations séparées. Identifiants V2 stables. |
| 072 | Conserver les huit originelles | Terminé | Huit armes V2 testables au stand, vérifiées par les régressions et captures. |
| 073 | Familles complémentaires | Partiel | Huit familles et variantes d’origine retravaillées. Aucun nouvel identifiant d’arme. |
| 074 | Snipers plus satisfaisants | Terminé | Eclipse et Stellar conservés. ADS, projectile, charge, pénétration visuelle du masque vérifiés. |
| 075 | Équipements secondaires | Partiel | Dash et Aegis conservés avec corrections d’animation. Nouveaux gadgets reportés. |
| 076 | Accessoires cosmétiques | Partiel | Deux nouvelles finitions et prévisualisation. Pas de système d’attaches indépendantes. |
| 077 | Gestion des munitions | Terminé | Chargeurs, réserve, surchauffe et interruptions gardés. Annulation de recharge testée. |
| 078 | Loadout intuitif | Terminé | Quatre emplacements, essais, profils rapides et restauration du choix personnel. |
| 079 | Statistiques comparables | Terminé | Comparaison impact, chargeur et cadence dans le hangar. |
| 080 | Validation d'équilibrage | Partiel | Tests de flux et essais sur cibles. Pas de campagne quantitative DPS/TTC des huit armes. |
| 081 | Hiérarchie du feedback | Terminé | Réticule, touches, dégâts, neutralisation et télégraphes ont des signaux séparés. |
| 082 | Effets de bouche d'énergie | Partiel | Impulsion de tir, pièces animées et émissions atténuables. Effets sur mesure par famille incomplets. |
| 083 | Traces et faisceaux | Terminé | Faisceaux distincts et traces empêchées de traverser un obstacle proche. |
| 084 | Impacts de matériaux | Partiel | Poussière sur terrain et étincelles pour impacts. Classification détaillée des matières non ajoutée. |
| 085 | Feedback de cible | Terminé | Réactions des robots, confirmation de touche et chiffres réglables. |
| 086 | Feedback d'élimination | Terminé | Chute mécanique et étincelles. Robots éliminés retirés du décompte immédiatement. |
| 087 | Explosions fictives optimisées | Terminé | Anneaux et débris simulés via pool borné, sans modification de dégâts. |
| 088 | Décalage VFX versus gameplay | Terminé | Effets visuels distincts du raycast, de l’explosion et de l’autorité réseau. |
| 089 | Feedback de dégâts reçus | Terminé | Intégrité, bouclier, direction du dégât et intensité visuelle réglable. |
| 090 | Profils de qualité FX | Terminé | Densité par preset et réduction indépendante des particules. v3_field valide les signaux essentiels. |
| 091 | Audit des 12 archétypes | Terminé | Douze archétypes V2 relevés dans Catalog, générateur et modèles. |
| 092 | Cerveau en états clairs | Terminé | Arrivée, poursuite, anticipation et récupération dans Drone. Cibles solo et équipes séparées. |
| 093 | Chemins robustes | Terminé | Routes et dégagement des points des sept cartes vérifiés par v3_modes. |
| 094 | Visibilité équitable | Partiel | Raycasts de visibilité et pénalisation des spawns visibles. Pas de playtest humain systématique. |
| 095 | Déplacements distincts | Terminé | Poursuite, retrait, flanc et esquive selon archétype. |
| 096 | Attaques télégraphiées | Terminé | Marquage, son et délai de préparation conservés. Animation de corps ajoutée. |
| 097 | Difficulté intelligente | Partiel | Découverte, Standard, Expert, caps et mutateurs. Pas d’adaptation à la compétence du joueur. |
| 098 | Coordination modérée | Partiel | Médics réparent et bots cherchent zones et adversaires. Pas de tactique de groupe nouvelle. |
| 099 | Boss avec phases utiles | Terminé | Phases, variations d’attaque et quatre boss conservés. Boss Rush exécuté. |
| 100 | Mode débogage IA | Non réalisé | Overlay de chemins et de décisions IA non ajouté. |
| 101 | Rig d'animation robot | Terminé | Rig de membres généré et attaché aux coques procédurales. |
| 102 | Cycle locomotion | Terminé | Cadence dépendante de la vitesse, marche et vol distincts. |
| 103 | Transitions de direction | Terminé | Virages amortis et inclinaison dans les changements de direction. |
| 104 | Préparation d'attaque | Terminé | Anticipation avec inclinaison et pose stabilisée avant attaque. |
| 105 | Réactions aux impacts | Terminé | Impact modifie lentille, coque et pose sans altérer le timing des dégâts. |
| 106 | Destruction non gore | Terminé | Effondrement mécanique de courte durée avec suppression différée. |
| 107 | Variations par type | Terminé | Variations de largeur, poids et vitesse pour coques légères, lourdes et flottantes. |
| 108 | Animation à bas FPS | Partiel | Courbes basées sur delta et rafraîchissement lointain réduit. Pas d’enregistrement vidéo multi-FPS. |
| 109 | Articulation des armes de robots | Partiel | Lentilles, coques et anticipation bougent. Pas de rig indépendant de tourelle pour chaque type. |
| 110 | Bibliothèque réutilisable | Terminé | Maillage de membre et courbes partagés, cache de coques et LOD. |
| 111 | Mode FPS Classique indépendant | Terminé | Match sans vagues, points, temps, victoire, défaite, égalité, retour au menu. |
| 112 | Escarmouche solo contre bots | Terminé | 0, 1 et 12 bots vérifiés, cap Ultra de 7. |
| 113 | Match à équipes | Terminé | Deux équipes identifiables et protection de tir allié testée. |
| 114 | Capture de points | Terminé | Zone centrale capturable, contrôle contesté, points et résultat. |
| 115 | Domination de zone | Terminé | Trois zones, cumul du score, fin au score ou au temps. |
| 116 | Entraînement avancé | Terminé | Stand configurable avec positions, cibles fixes/mobiles/aériennes et chrono. v3_field. |
| 117 | Mode Exploration | Terminé | Exploration sans adversaires des sept cartes, retour au menu. |
| 118 | Mode Détente | Partiel | Détente à cinq vagues et difficulté douce dédiée. Pédagogie contextuelle limitée. |
| 119 | Match personnalisé | Partiel | Mode, style, carte, bots, durée, score et graine. Fréquence de réapparition fixe. |
| 120 | Résultats propres à chaque mode | Terminé | Bilans et catégories distincts, records séparés par règles et relecture JSON vérifiée. |
| 121 | Vagues V2 conservées | Terminé | Suites Survie 10/20, chrono, Boss Rush et 100 transitions réexécutées. |
| 122 | Variantes de vagues | Terminé | Douze familles observées sur 200 définitions en v3_field. |
| 123 | Alternance du rythme | Terminé | Tempo alterné après vague 20. Les compositions 1–20 restent stables. |
| 124 | Mini-objectifs de vague | Terminé | Relais de terminal optionnel, crédits uniques. Vérifié avec test de présence. |
| 125 | Mutateurs transparents | Terminé | Quatre mutateurs annoncés et reproductibles. Effets bornés. |
| 126 | Événements environnementaux | Partiel | Éclairage d’urgence sans variation de collision. Pas de portes dynamiques. |
| 127 | Boss sans répétition mécanique | Partiel | Phases V2 gardées et escortes déterministes. Pas de variantes de boss spécifiques à chaque carte. |
| 128 | Choix de parcours | Terminé | Choix risque/récompense entre deux vagues, même session et équipement. |
| 129 | Intermissions utiles | Terminé | Résumé, prévision, choix de module, stocks et reprise explicite. Tests de ravitaillement. |
| 130 | Mode Infini enrichi | Terminé | Paliers 25/50/75/100, finition Aurore et extraction. 100 vagues accélérées et règlement unique. |
| 131 | Reactor Court retravaillée | Partiel | Reactor Court rematérialisée et repères de contrôle. La topologie originale est conservée. |
| 132 | Skyline Depot retravaillée | Partiel | Skyline Depot rematérialisée et éclairage d’aube. La topologie originale est conservée. |
| 133 | Cryo Foundry retravaillée | Partiel | Cryo Foundry rematérialisée, ambiance froide, brume et neige. Pas de nouvelle section. |
| 134 | Carte Base Militaire Fictionnelle | Terminé | Bastion Relay jouable, rampes, base et antenne de transmissions fictive. |
| 135 | Carte Ville Stylisée | Terminé | Meridian District jouable, façades, place et couloirs latéraux. |
| 136 | Carte Forêt / Ruines | Terminé | Ashgrove Ruins jouable, clairière, ruines franchissables et couvert végétal. |
| 137 | Carte Station Intérieure | Terminé | Transit Hall jouable, toit, quais et rampes. |
| 138 | Échelle et couverture | Partiel | Empreintes, lignes et circulation validées. Pas de relevé humain intégral des positions dominantes. |
| 139 | Spawn et anti-camping | Terminé | Distance aux acteurs et pénalité de visibilité pour réapparitions classiques. Test de redéploiement. |
| 140 | Prévisualisation des maps | Terminé | Captures des sept cartes visibles avant lancement. |
| 141 | Séparation économique | Terminé | CR de terrain et pièces de pilote isolés dans deux services. |
| 142 | Boutique d'intermission moderne | Partiel | Sept offres, quantités et épuisement visibles. Pas de filtre de rôle distinct. |
| 143 | Boutique permanente premium | Terminé | Catégories, aperçu, comparaison, configurations et solde. |
| 144 | Récompenses lisibles | Partiel | Gains finaux, reçus et récompenses lisibles. Pas de ventilation complète par source dans chaque bilan. |
| 145 | Contrats renouvelables | Terminé | Contrats locaux, état conservé face au recul de date, réclamation idempotente. |
| 146 | Déblocages par progression | Partiel | Finition de palier et équipements au prix local. Pas de chronométrage humain moyen. |
| 147 | Préconfigurations de magasin | Terminé | Quatre configurations rapides et une configuration sauvegardée, objets acquis uniquement. |
| 148 | Historique de transactions local | Terminé | 48 reçus bornés, débit double refusé. Migration et relecture vérifiées. |
| 149 | Récompenses cosmétiques uniquement facultatives | Partiel | Finitions et succès optionnels, entièrement locaux. Pas de nouvelles poses cosmétiques. |
| 150 | Équilibrage multi-modes | Terminé | Cent résultats synthétiques calculés sur cinq modes et trois difficultés. Chiffres dans V3_QA_REPORT. |
| 151 | Niveaux de pilote | Terminé | Courbe V2 conservée et XP avant prochain niveau. Migration de 870 XP vérifiée. |
| 152 | Maîtrise par arme | Partiel | Maîtrise affichée et historique stable. Pas de récompense cosmétique individuelle pour chaque arme. |
| 153 | Arbre de spécialisation | Partiel | Préréglages réversibles de talents via modules existants. Pas d’arbre ramifié. |
| 154 | Défis de compétence | Partiel | Défi de précision, objectifs et défis hebdomadaires. Catalogue d’esquive/support incomplet. |
| 155 | Succès locaux | Terminé | Succès obtenus une seule fois, avec paliers d’endurance et finitions. |
| 156 | Statistiques détaillées | Terminé | Statistiques par mode, durée, objectifs, défaites et arènes. JSON borné. |
| 157 | Historique des parties | Terminé | 32 parties et conditions rejouables. Vérification de la graine et des règles. |
| 158 | Profil cosmétique | Partiel | Nom, finitions d’armes et de pilote. Pas d’éditeur de bannière et pose. |
| 159 | Challenges hebdomadaires hors ligne | Terminé | Défi hebdomadaire UTC déterministe, crédit unique et persistant. |
| 160 | Respect du temps du joueur | Terminé | Formats de 5 à 15 min, longs, solo hors ligne, transactions synchrones. |
| 161 | Architecture UI éditable | Partiel | Nouveaux écrans séparés en modules. Écrans historiques App encore largement programmatiques. |
| 162 | Mise en page responsive | Partiel | Mise à l’échelle et marges Android. Vérification 16:9 et deux résolutions sur PC. |
| 163 | Menu principal haut de gamme | Terminé | Menu avec arène vivante, accès direct au Classique et thème à portée. |
| 164 | HUD focalisé sur le combat | Terminé | HUD de scores, contrôle, chrono, rechargement et précision adapté aux modes. |
| 165 | Animations UI naturelles | Terminé | Transition animée des écrans, désactivable, sans bloquer l’entrée. |
| 166 | Lunette lisible | Terminé | Lunette de contraste et ombre réglable. Vérifiée avec rendu en fenêtre. |
| 167 | Boutique navigable au clavier | Terminé | Focus conservé dans la liste et défilement suivi au clavier. |
| 168 | Journal de partie | Terminé | Journal de partie, transactions et résumé d’opération. |
| 169 | Rapport de fin riche | Terminé | Durée, précision, éliminations, score, rival, décès et gains par mode. |
| 170 | Microcopy en français impeccable | Partiel | Interface et documents français. Relecture éditoriale externe non réalisée. |
| 171 | Mixage audio cohérent | Terminé | Bus séparés, niveaux persistants et signal réellement capturé. |
| 172 | Bruitages d'équipements distincts | Partiel | Huit tirs distincts et mécaniques de charge. Plusieurs sons de recharge restent partagés. |
| 173 | Spatialisation efficace | Terminé | Atténuation et priorité des sources proches dans le pool 3D. |
| 174 | Ambiance par carte | Terminé | Vent, feuillage, station, ambiance froide et réacteur. Volume indépendant. |
| 175 | Musique adaptative | Terminé | Fondu entre menu, combat et boss. Signaux de victoire/défaite distincts. |
| 176 | Sous-titrage des informations | Partiel | Informations clés à l’écran. Pas de sous-titrage complet de tous les sons. |
| 177 | Alertes sonores contrôlables | Terminé | Commandes d’alertes, impacts et musique dynamique persistantes. |
| 178 | Animations du menu | Partiel | Orbite lente et fondu de menu désactivables. Pas de mesure comparative de consommation. |
| 179 | Sensibilité au clignotement | Terminé | Effets facultatifs à zéro, avertissements essentiels gardés. v3_field. |
| 180 | Accessibilité générale | Partiel | Confort, réticule, contraste, HUD et commandes. Pas de réglage global de toutes les polices. |
| 181 | Conserver ENet V2 | Terminé | Coop2, coop4 et serveur dédié exercés avec ENet. |
| 182 | Contrat réseau versionné | Terminé | Protocole 3, rejet de version et contrôle de taille et d’enveloppe. |
| 183 | Prediction visuelle légère | Partiel | Visée immédiate et présentation amortie. Pas de prédiction de position locale côté client. |
| 184 | Interpolation des autres pilotes | Terminé | Tampon jusqu’à six snapshots. Tests d’angle, perte, discontinuité et clients. |
| 185 | Animation répliquée | Partiel | Pose d’armes et mouvement à distance répliqués. RTT artificiel et animation de mort distante complète à valider. |
| 186 | Boutique coop cohérente | Terminé | Soldes, reçus, doubles achats et reprise d’intermission testés. |
| 187 | Salons ergonomiques | Partiel | Salon, prêts, carte, erreurs, adresse et aide LAN. Pas d’affichage de latence par pilote. |
| 188 | Déconnexions propres | Partiel | Reconnexion pendant intermission et fin d’hôte testées. Matrice de déconnexion exhaustive absente. |
| 189 | Connexions Internet réalistes | Terminé | Guide LAN/Internet et limites explicites dans V3_NETWORK. WAN non testé. |
| 190 | Coop du nouveau mode Classique | Non réalisé | Coop Classique non implémentée. Les nouveaux formats sont locaux. |
| 191 | Profil matériel de référence | Non testable | Intel N150 et 8 Go réels indisponibles. Mesures Linux llvmpipe. |
| 192 | Objectifs frametime | Partiel | p50/p95/p99 mesurés. Budget 60 FPS et performances matérielles à valider. |
| 193 | Mode ultra-performance | Terminé | Ultra faible 64 %, ombres/brume coupées, pool réduit, 7 bots. Mesure séparée. |
| 194 | Goulots CPU ciblés | Terminé | Raycasts réutilisés, animation lointaine décimée et effets actifs seuls parcourus. |
| 195 | Goulots GPU ciblés | Partiel | Ciel en calcul au sommet en Faible/Ultra et sol simplifié. p95 Faible encore supérieur à la référence V2. |
| 196 | Pool d'objets robuste | Terminé | Projectiles et effets réutilisés, rafale et anneaux bornés. |
| 197 | Navigation à budget | Partiel | Décisions échelonnées et AStar réutilisé. Pas d’ordonnanceur global de requêtes. |
| 198 | Animation LOD | Terminé | Maillages de membres à distance limitée et cadence réduite loin du pilote. |
| 199 | Gestion du chargement | Partiel | Armes préparées au lancement, coques et matières mises en cache. Pas de transition asynchrone complète. |
| 200 | Télémétrie exploitable | Terminé | HUD télémétrie, protocole instrumenté et CSV de mesure dans docs. |
| 201 | Tests de non-régression | Terminé | 51 tests V1 conservés avec deux attentes audio adaptées. Suites V2 et V3 relancées. |
| 202 | Tests animations | Partiel | 24 swaps, recharge, Nova, ADS ×4, plafond, pause et reconnexion. Tous les cas A–H séparés non couverts. |
| 203 | Tests des nouvelles cartes | Partiel | Spawns et connexions des sept arènes vérifiés, rendu de chaque carte. Circuit manuel complet absent. |
| 204 | Tests pour les thèmes | Terminé | Quatre thèmes capturés sur les trois cartes originales. Options et styles persistants. |
| 205 | Tests de progression | Terminé | Migration V1 et V2, sauvegarde de secours, achat unique, corruption et reprise testés. |
| 206 | Tests de la boutique | Terminé | Stocks, insuffisance, rejeu du jeton, absence de double débit et reçus coop. |
| 207 | Tests des modes | Terminé | Intégration des modes V2 et nouveaux formats, résultats classiques et stand. |
| 208 | Tests de stabilité prolongés | Partiel | 100 vagues accélérées et suivi de mémoire. Pas de 30–60 min continues sur matériel de jeu. |
| 209 | Tests orientés joueur | Partiel | Clics réels dans la fenêtre et exercices automatisés. Pas de session humaine continue de 15 min. |
| 210 | Rapport vérifiable | Terminé | Rapports, journaux de validation, captures et CSV joints aux sources. |
| 211 | Branche de travail propre | Terminé | Git local initialisé, baseline taguée et branche de refonte. Archive d’origine intacte. |
| 212 | Refactor incrémental | Partiel | Modules caméra, règles, carrière, tactile, FX et réseau extraits. App et Session gardent de l’orchestration. |
| 213 | Compatibilité moteur | Terminé | Godot 4.6.3 Standard utilisé à l’import, à l’exécution et aux exports. |
| 214 | Build source vérifiable | Terminé | Projet complet et licences, import depuis copie propre. Paquet testé hors du dossier source. |
| 215 | Export Windows x64 | Partiel | EXE x64 autonome généré, PE et PCK intégrés vérifiés. PCK joué sous Linux, Windows natif indisponible. |
| 216 | Installation simple | Terminé | ZIP Windows, guide rapide, lanceur direct et réglages AZERTY/QWERTY. |
| 217 | Configuration portable | Terminé | Solo local, chemins Godot, aucune dépendance à un service ou à un compte. |
| 218 | Diagnostics au joueur | Partiel | Diagnostics de profil et de réseau, guides d’export et vidéo. Pas d’écran moteur personnalisé pour chaque échec GPU. |
| 219 | Rapport final honnête | Terminé | Statut explicite et preuve ou limite pour chacune des 221 étapes. |
| 220 | Passage de relais | Terminé | Instructions de modification, test, benchmark, Git et export dans V3_HANDOFF et README. |
| 221 | Portage Android APK natif, commandes tactiles, fluidité mobile et double export PC/mobile (PRIORITÉ APRÈS LA BASE V3 STABLE) | Partiel | Tactile multi-doigts et éditeur validés dans Godot. APK native signée et vérifiée statiquement. Émulateur bloqué avant lancement, téléphone physique indisponible. |
