--[[
  ROC-097 (DC, 15/11 : « une rangée de foreuses de champ ne doit jamais être rejetée ni tronquée à cause d'un rocher ou d'un arbre »).
  Règles PURES du déblaiement d'une pièce d'un plan de champ juste avant sa pose (script/team/build.lua, place_ghost). Aucune API Factorio,
  aucun nom d'objet : le type et le drapeau de rocher sont lus au prototype par l'appelant.

  Le plan du champ tient déjà arbres et rochers pour des tuiles libres (script/team/champ.lua, blocked_scan : « soft ») ; la pose, elle,
  refusait la pièce « obstacle » tant qu'un PNJ n'avait pas abattu l'arbre : 3 refus et la foreuse de bande était SAUTÉE (Saut.skip,
  rangée tronquée), un tapis ou un poteau refusé 6 fois bloquait la bande entière. Désormais l'obstacle mineur sous l'emprise est retiré
  au moment de la pose, comme Ds.place (script/team/defense_stock.lua) le fait pour ses tourelles.

  Db.minor(kind, rock) : `kind` = type du prototype ; `rock` = prototype.count_as_rock_for_filtered_deconstruction. Vrai pour un arbre
    et pour une entité simple marquée rocher par les données (rochers du jeu, amas de cristaux du mod, copies de rock-big).
  Db.applies(spec) : la pièce appartient-elle à un projet de champ (spec.site == "champ") ?
  Db.lazy(spec) : un projet de champ ne passe plus par l'étape « defrichage » (attendre que les PNJ aient tout abattu) : ses obstacles
    mineurs sont retirés pièce par pièce à la pose ; le reste (entité simple non rocher) reste suivi comme avant (refus « obstacle »).
]]

local Db = {}

function Db.minor(kind, rock)
  if kind == "tree" then return true end
  return kind == "simple-entity" and rock == true
end

function Db.applies(spec)
  return spec ~= nil and spec.site == "champ"
end

function Db.lazy(spec)
  return Db.applies(spec)
end

return Db
