--[[
  COFFRES DU JOUEUR (lot COFFRES-JOUEUR) — PUR (aucune API Factorio), testé par tests/coffres_joueur_test.lua.

  Remarque du DC en partie (5/11, essai 0.6.53) : « j'ai posé des coffres et j'ai fait une fonderie. Les ressources dans les
  coffres que j'ai posés n'ont jamais été utilisées, jamais, pas une fois. Et du coup, ça pose problème parce que du coup, ça veut
  dire qu'ils n'utilisent pas les ressources. »

  Avant : le stock de votre équipe = coffre du QG + annexes posées par l'équipe (script/team/stock.lua) ; aucun autre coffre n'est
  jamais lu. Désormais un coffre de la force du joueur compte dans le stock de votre équipe, en LECTURE et en PRISE (et en DÉPÔT
  pour un coffre ordinaire sans bras : CJ.deposit_ok), quand :
    - il a été posé (ou réglé) par un JOUEUR (dernier utilisateur connu) : les coffres posés par l'équipe (QG, annexes, modules du
      plan directeur, sorties d'avant-poste) ont déjà leurs tournées ;
    - il est dans la BASE : zone du départ (lot QG-ZONE, toute la base reliée au départ) ou à HOME_RADIUS d'un point du départ ;
    - ce n'est pas un coffre logistique DEMANDEUR ou TAMPON (requester, buffer : le joueur y fait venir des objets pour un usage) ;
    - aucun bras ne PREND dedans : c'est le tampon d'une chaîne du joueur, le vider l'affamerait (le coffre de SORTIE d'une
      fonderie du joueur, où les bras déposent, compte : c'est le cas du DC) ;
    - ce n'est pas la réception d'une foreuse adoptée (avant-poste de l'équipe, lot PARITE : ses tournées la vident déjà).
  Pas d'exception pour la barre rouge (elle ne limite que les dépôts) ni pour le filtre d'un coffre de stockage logistique (les
  robots y rangent, l'équipe peut y prendre).

  Ordre de prise : coffre du QG, annexes, puis coffres du joueur, du plus proche du QG au plus lointain (numéro d'unité à égalité).
  Les coffres VIDES sont examinés aussi (un coffre vide posé à la main, ou qui remplace une annexe, sert au DÉPÔT : CJ.deposit_ok).
  Coût borné : SCAN coffres examinés au plus par liste (les plus proches du QG, non vides), MAX retenus ; liste refaite toutes les
  REFRESH ticks.
]]

local CJ = {}

CJ.EXCLUDED_MODES = { requester = true, buffer = true }
CJ.SCAN = 96       -- coffres non vides examinés au plus (les plus proches du QG) : une recherche de bras chacun
CJ.MAX = 32        -- coffres retenus au plus : chaque lecture du stock en lit autant (get_item_count, get_contents)
CJ.REFRESH = 3600  -- liste refaite au plus toutes les minutes

CJ.REASONS = { "stock", "equipe", "hors-base", "demande", "tampon", "avant-poste" }

--- Verdict pour un coffre `c` = { by_player, in_base, mode (mode logistique ou nil), feeds (un bras y prend), adopted } :
--- retenu (bool), motif (un de CJ.REASONS).
function CJ.verdict(c)
  if c.adopted then return false, "avant-poste" end
  if not c.by_player then return false, "equipe" end
  if not c.in_base then return false, "hors-base" end
  if c.mode and CJ.EXCLUDED_MODES[c.mode] then return false, "demande" end
  if c.feeds then return false, "tampon" end
  return true, "stock"
end

--- DÉPÔT (signalement du DC du 5/11, 21 h 47 : un coffre en acier vide posé PAR-DESSUS une annexe en fer, l'équipe « pleine » quand
--- même) : un coffre retenu pour la prise reçoit aussi les dépôts de l'équipe quand c'est un coffre ORDINAIRE (`kind` = "container",
--- pas un logistique : les robots y ont leurs règles) et qu'aucun bras n'y DÉPOSE (`drops` : la sortie d'une chaîne du joueur ne se
--- remplit pas d'autre chose). Un coffre posé à la main, ou qui en remplace un de l'équipe, en est un.
function CJ.deposit_ok(c)
  local ok = CJ.verdict(c)
  return ok and c.kind == "container" and not c.drops
end

--- Tri des candidats { id (numéro d'unité), d2 (distance² au QG) } : du plus proche au plus lointain, numéro à égalité.
function CJ.order(list)
  table.sort(list, function(a, b)
    if a.d2 ~= b.d2 then return a.d2 < b.d2 end
    return a.id < b.id
  end)
  return list
end

--- Coffres retenus parmi `list` (déjà examinés : champs de CJ.verdict), dans l'ordre de CJ.order, MAX au plus. Rend la liste
--- retenue, le compte par motif { [motif] = n } (motifs de CJ.REASONS ; « plafond » pour les retenus au-delà de MAX) et la sous-liste
--- des coffres de DÉPÔT (CJ.deposit_ok, même ordre).
function CJ.select(list, max)
  CJ.order(list)
  local keep, why, depot = {}, {}, {}
  for _, c in ipairs(list) do
    local ok, r = CJ.verdict(c)
    if ok and #keep >= (max or CJ.MAX) then ok, r = false, "plafond" end
    why[r] = (why[r] or 0) + 1
    if ok then
      keep[#keep + 1] = c
      if CJ.deposit_ok(c) then depot[#depot + 1] = c end
    end
  end
  return keep, why, depot
end

return CJ
