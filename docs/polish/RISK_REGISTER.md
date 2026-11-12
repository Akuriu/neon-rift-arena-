# Risques à vérifier par lot

| Risque | Contrôle prévu |
| --- | --- |
| Changement de scène principale et chemin des RPC ENet | Conserver `/root/NeonRift/Coop` et vérifier hôte dédié, déconnexion et reconnexion sur le protocole 4. |
| Écritures sur des profils anciens, illisibles ou concurrents | Profils jetables, contrôle des empreintes, archives avant remplacement et migration v5 → v6. |
| Chargement en arrière-plan ou annulation qui laisse une session obsolète | Tester le début, l’erreur, la relance et les clics répétés. Construire et attacher les nœuds sur le thread principal. |
| Capture de touches ou de doigts pendant une transition | Tester souris, clavier, retour, perte de focus, tactile injecté et zones sûres. |
| Menu et compilation de shader sur Compatibility | Banc logiciel commun et test sur matériel ciblé. Conserver le rendu Compatibility. |
| Distribution Android | Les APK de revue ont un paquet isolé. Garder les vérifications de clé d’origine et de validation matérielle pour la publication officielle. |
