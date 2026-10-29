# Questions pour le DC (nuit du 28/10)

Une ligne par question : sujet, option par defaut retenue, chiffres, effet. Rien ici n est applique sans reponse.

## Questions ouvertes (audit du 28/10 soir ; rien n'est appliqué sans réponse)

1. **ENCEINTE / ESPACE** (« murailles, entourer sa base, s'étendre ») : aucun fichier de scénario n'existe (docs/SCENARIO_EPOQUES.md est le scénario de contenu). Voulez-vous (A) une enceinte complète de murs avec portes aux rues, élargie quand la base s'étend, ou (B) des murs et tourelles seulement sur les axes de menace connus ? Défaut retenu : B (moins de fer, pas de blocage des chemins). Seuils d'âge et de ressource à fixer par vous.
2. **TAPIS-NIVEAUX** (« niveaux de convoyeurs, stacker ») : voulez-vous (A) seulement que les PNJ choisissent le meilleur tapis déjà débloqué (jaune, rouge, bleu), ou (B) de nouveaux niveaux propres au mod avec compaction ×4 (D-17, palier B1) ? Défaut : A d'abord, B après votre verdict visuel.
3. **CENTRE-QG** : le « centre de commandement » (container niveaux 1-15) et le « QG du vaisseau » (épave `fo-faction-hq`, 25 000 PV) sont deux objets. Voulez-vous que le QG du vaisseau soit réparable et améliorable par âge avec un style par âge (images pour votre verdict), ou que ce soit le centre ? Défaut : ne rien coder avant votre réponse.
4. **BILAN production − consommation** : le « bénéfice » se mesure-t-il en valeur (MU de la capitalisation) ou en quantité physique par ressource ? Défaut : valeur MU, avec le déficit physique par ressource en secours.
5. **Milice de votre équipe de PNJ** : doit-elle avoir quelques soldats / une escorte comme les factions (parité demandée) ? Elle n'en a aucun aujourd'hui (`soldiers_max = 0`), ce qui explique l'attente indéfinie devant les meutes. Défaut : factions d'abord, milice du joueur (2 à 4 soldats) en second temps.
6. **Poteaux de reconstruction** : voulez-vous que les PNJ refassent aussi ce que VOUS avez posé et qui est détruit ? Défaut : oui pour les poteaux, chaudières et machines à vapeur de l'équipe, pas pour vos coffres.
7. **Refill des fours** : combien de matière accepte-t-on d'immobiliser dans les fours ? Défaut : de quoi tenir environ 10 minutes de fonte (pas plus).
8. **Générateurs** : les factions doivent-elles poser du solaire et du nucléaire (deux gabarits de pose en plus de la vapeur) quand ils sont débloqués ? Défaut : oui, choix déduit des prototypes, vapeur en repli.

9. **STOCKAGE (rapport STOCK-ECHELLE, 29/10)** : à 60 min le stock n'est jamais plein (maximum 0,64 ; annexes 1 à 9 pour votre équipe) ; l'extrapolation donne le plafond (864 cases) vers la minute 158 à 183 sur 2 graines et plus de 780 min sur 3. Aucun code changé. Question : à la 6e heure de votre partie, le coffre du QG et ses annexes étaient-ils pleins, et combien d'annexes ? La réponse tranche si le lot de 7 h (coffre d'acier en donnée, compteur de dépôts refusés, relevé après 60 min) se justifie. Défaut mesuré, faible : quand tout est plein, les PNJ gardent dans leur inventaire ce qu'ils ne peuvent plus déposer (1 à 2 cases/PNJ, contre 0,25 à 0,8 pour le témoin).
