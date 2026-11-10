# Coop locale et serveur dédié

Le protocole **3** étend les salons ENet existants à 2–4 pilotes. Chaque joueur doit utiliser la V3. Les vagues, les modules de terrain, les achats et le résultat sont calculés par l’hôte. Le tampon de rendu distant conserve jusqu’à six snapshots, avec une lecture retardée d’environ 120 ms. La visée locale est appliquée dès l’événement d’entrée.

## Réseau local

1. L’hôte ouvre **Coop**, choisit la carte, le mode, la difficulté et le port UDP, puis clique sur **Héberger**.
2. Les invités saisissent l’adresse IP locale de l’hôte et le même port. Le port par défaut est **24562 UDP**. Le code du salon est facultatif.
3. Tous les pilotes se déclarent prêts. L’hôte lance la partie.

Sur un seul ordinateur, utilisez `127.0.0.1` et des profils de test isolés. Sur plusieurs machines, utilisez l’adresse réseau locale de l’hôte. Si les appareils se voient mais que la connexion échoue, vérifiez le port et l’isolation des appareils sur le Wi-Fi invité.

## Serveur dédié

```sh
godot --headless --path . -- --server --port=24562 --mode=short --map=skyline --difficulty=standard
```

Le même mécanisme est disponible avec le moteur et le PCK. L’hôte dédié attend des pilotes et les options de salon peuvent être fixées au démarrage. Une fenêtre de reconnexion est disponible lorsque le client quitte puis rejoint avec son jeton de session.

## Accès distant

Hors LAN, l’hôte doit être joignable sur son port UDP. La configuration dépend du routeur, du pare-feu et de l’accès Internet. Un hébergement joignable ou un relais externe peut être nécessaire. Validation de cette livraison sur localhost, avec processus distincts. La coop du FPS Classique et la validation WAN restent des étapes séparées.
