--[[
  Niveaux de bâtiments : point d'entrée de l'étape data (requis par data.lua).

  Centre de commandement (15 niveaux = 15 époques) et niveaux 2 à 30 des 6 autres familles.
  - prototypes/levels/common.lua : tout ce qui n'est pas visuel (statistiques, objets, noms, groupes de
    remplacement, traductions) et l'INTERFACE des fichiers de famille (documentée en tête du fichier) ;
  - prototypes/levels/<famille>.lua : le visuel de la famille, par niveau et par époque (lots V3) ;
  - prototypes/levels/style.lua : le style COMMUN des 7 familles par époque (palette ; un seul propriétaire) ;
  - shared/levels/config.lua : données et règles (pur Lua, testées hors jeu) ;
  - script/levels/ : runtime (chantiers, plafond, ouvriers, panneau « Évolution »).
]]

require("prototypes.levels.common").generate()
