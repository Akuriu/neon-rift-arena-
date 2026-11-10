# Coop privée et serveur dédié

## Héberger et rejoindre

1. Tous les pilotes lancent NEON RIFT ARENA **2.0**.
2. L’hôte ouvre **Coop · 2–4**, règle le port, le nombre de places et éventuellement le code privé, puis clique **Héberger**. Il communique son IP locale et le port affichés.
3. Les autres pilotes entrent cette adresse, le même port et le code, puis cliquent **Rejoindre**.
4. Les invités indiquent qu’ils sont prêts. L’hôte démarre avec au moins deux pilotes prêts.

Le port par défaut est **24562 UDP**. Pour un essai sur le même PC, ouvrez deux processus et rejoignez **127.0.0.1**. Sur deux ordinateurs du même réseau, utilisez l’adresse locale de l’hôte. Sur deux réseaux distincts, l’hôte doit disposer d’une adresse et d’un port UDP accessibles. Selon la connexion, cela implique une règle de pare-feu et une redirection UDP vers l’hôte. Le CGNAT de certains accès peut empêcher la connexion entrante directe. [Documentation ENet de Godot](https://docs.godotengine.org/en/4.6/tutorials/networking/high_level_multiplayer.html)

## Règles de partie

Le serveur décide des mouvements, dégâts, apparitions, achats et résultats. Le client transmet l’intention de commande et interpole les acteurs à partir des instantanés reçus. La visée locale reste immédiate. Les achats et transitions utilisent des messages fiables. Les positions et effets utilisent le flux non fiable d’ENet.

Un pilote hors combat revient à l’intermission si l’équipe sécurise la vague. La boutique ouvre 55 secondes ou jusqu’à ce que tous les pilotes soient prêts. Une connexion en cours de combat est refusée et l’intermission accepte les nouvelles connexions. Après une coupure, une instance qui rejoint le même hôte conserve son équipement et son solde au moyen d’un jeton temporaire, valable pendant deux vagues et deux minutes au maximum. Les crédits manqués pendant l’absence restent liés aux pilotes présents.

Le code sert au contrôle d’entrée d’un salon privé. Les profils et bilans sont locaux. La fermeture de l’hôte rend la connexion et son état de partie aux clients, qui retournent au salon avec un message.

## Mode dédié

Avec les sources importées, démarrez le serveur depuis la racine du projet.

```sh
godot --headless --path . -- --server --port=24562 --map=reactor --mode=survival --difficulty=standard
```

Cartes valides `reactor`, `skyline`, `cryo`. Modes `survival`, `short`, `endless`. Difficultés `discovery`, `standard`, `expert`. L’option `--code=VALEUR` protège l’entrée. Le serveur démarre quand au moins deux clients sont prêts. Il ouvre de nouveau le salon après le départ du dernier pilote.

## Périmètre de validation

Les suites reproductibles ont utilisé plusieurs processus sur **127.0.0.1**. Elles vérifient deux et quatre pilotes, la vague 6 puis la vague 7, les achats, une reconnexion, les entrées invalides et la fermeture de l’hôte. Le scénario dédié vérifie le démarrage sans joueur hôte. Les connexions entre machines sur un LAN et depuis un autre réseau restent à vérifier. Le matchmaking public, la découverte LAN automatique, les relais et les comptes cloud sont reportés.
