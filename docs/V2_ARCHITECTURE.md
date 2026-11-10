# Architecture V2

**App.tscn** instancie le menu, le service de coop et la scène de session. La session reste la source de vérité du solo. En coop, la session de l’hôte exécute la même simulation et le client applique les états reçus.

| Composant | Responsabilité |
| --- | --- |
| `game/waves/generator.gd` | Vagues reproductibles, budget borné, escortes, boss et difficulté |
| `game/wave_director.gd` | Préparation, combat, intermission, campagne, victoire ou défaite |
| `game/session.gd` | Cycle de la scène, robots, dégâts, récompenses, gadgets, inventaire de terrain et recyclage |
| `game/weapons/catalog.gd` et `game/arsenal.gd` | Données et comportements des armes, chaleur, réserves, charge et lunette |
| `game/economy/field_wallet.gd` | Portefeuille par pilote, prix, contrôles et identifiants de transactions |
| `services/profile.gd` et `services/prefs.gd` | Progression, inventaire et migration. Sauvegarde avec verrou, fichier temporaire relu et sauvegarde de secours |
| `network/coop.gd` et `network/replication.gd` | Salon, règles d’autorité, reconnexion, messages de phase et instantanés comprimés |
| `ui` | Menus, équipements, réglages, HUD, bilan et salon |

Le paquet ne contient ni tests ni cache de l’éditeur. Les données peuvent être modifiées dans les catalogues GDScript et les cartes sont construites depuis des primitives, shaders et collisions du moteur. Le script `tools/synth_audio.py` régénère les échantillons originaux.

Le portefeuille n’engage un débit que si le solde et le stock sont valides. Un effet refusé rembourse immédiatement. La progression permanente et le classement s’enregistrent dans le même document. La transaction restaure l’état mémoire si l’écriture échoue. Un identifiant de partie déjà réglé est refusé.
