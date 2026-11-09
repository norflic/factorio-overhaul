--[[
  Lot COMBUSTIBLE-MIGRATION (9/11, retour du lead : « le QG ne doit jamais tomber sans combustible à cause d'une migration »). PUR : aucune API
  Factorio, aucun nom d'objet (le combustible est une étiquette lue par l'exécutant, les kW et la valeur du combustible arrivent en DONNÉES) ; testé
  hors jeu par tests/migration_combustible_test.lua (mutants). Exécutant : script/team/migration_champ.lua (th_context, step_project, step_build).

  Défaut MESURÉ (fo-logs/2026-11-09_INTEG-NORMAL/carte-g123456789-52b5db3a, votre équipe, Normal) : à 33,0 min la migration retire les 10 paires thermiques
  de l'avant-poste de CHARBON 2 (« partie retirée, projet 7 ») pour une bande électrique de 134 entités dont 0 est bâtie ; le plancher de la protection
  (Th.cut_ok, floor = fuel_burn) ne lit que les GÉNÉRATEURS (centrale à 0 % de charge : plancher ~0) et ignore les brûleurs de l'équipe (70 foreuses
  thermiques et leurs fours) : « plancher-tenu », la coupe passe ; deux paires restantes sont tuées par des ennemis à 33,2 min, l'avant-poste est perdu,
  la migration ne suit plus rien (« avant-poste perdu, projet 7 laissé au plan ») ; charbon thermique 0 dès 35 min, QG sans charbon, brûleurs à sec
  (foreuse_comb no_fuel 408/1203 à 40 min, 826/1122 à 50, 960/1140 à 80), fer de 431 à 28 par minute entre 40 et 90 min. Même chaîne sur « off »
  (123456789, 600 %) : avant-poste de charbon 5, 8 paires retirées à ~26 min pour une bande jamais bâtie.

  Règles (deux, indépendantes) :
  1. Mc.floor / Mc.cut_ok : le plancher du combustible est ce que BRÛLENT les générateurs ET les brûleurs de l'équipe (à pleine cadence : borne haute).
     Retirer les paires d'une bande de combustible n'est permis que si la bande est constructible maintenant (`ready` : matières réservées, pas
     d'ennemi) ET que le stock couvre le manque pendant le chantier : stock >= max(0, plancher - reste) x durée du chantier (Mc.CFG.build_s, borné haut :
     18 à 26 min observées). Sinon la coupe ATTEND, paires en place (Th.verdict : au bout de Th.CFG.critical_wait la demande est annulée et redemandée
     plus tard : jamais une impasse, une bande bloquée par ses propres paires n'existe pas puisque la demande tombe d'elle-même).
  2. Mc.low : après un retrait, le stock de combustible ne tient pas Mc.CFG.horizon secondes du plancher : le retour en arrière (shared/team/
     migration_retour.lua, R.decide) se décide au seuil court R.CFG.stall_fuel au lieu de R.CFG.stall.

  Aucun `pairs` décisionnel, aucun hasard, aucun temps mesuré.
]]

local M = {}

M.CFG = {
  build_s = 26 * 60, -- s : durée du chantier d'une bande que le stock doit pouvoir ponter (borne haute des 18 à 26 min observées)
  horizon = 10 * 60, -- s : stock minimal, en secondes de plancher, sous lequel le combustible « manque » après un retrait (même seuil que Th.CFG.horizon)
}

local EPS = 1e-9

--- Plancher de combustible (objets/s) : `gen` = objets/s brûlés par les générateurs (mesuré), `burners` = { { kw, n }, ... } (puissance de combustion
--- d'un brûleur de l'équipe et leur nombre), `fuel_kj` = énergie d'un objet de combustible (kJ). Borne haute : les brûleurs à pleine cadence.
function M.floor(gen, burners, fuel_kj)
  local total = math.max(0, gen or 0)
  if not (fuel_kj and fuel_kj > 0) then return total end
  for _, b in ipairs(burners or {}) do
    total = total + math.max(0, b.kw or 0) * math.max(0, b.n or 0) / fuel_kj
  end
  return total
end

--- Le retrait des paires d'une bande est-il permis ? c = { fuel (l'avant-poste produit le combustible de l'équipe), ready (bande constructible
--- maintenant), rest (objets/s qui restent après la coupe : thermique alimenté + électrique en marche, tous gisements du minerai), floor (M.floor),
--- stock (combustible libre au coffre et aux annexes) }. Rend (vrai/faux, raison). Hors combustible : la règle ne dit rien (toujours vrai).
function M.cut_ok(c, cfg)
  cfg = cfg or M.CFG
  if not c.fuel then return true, "hors-combustible" end
  if not c.ready then return false, "pas-constructible" end
  local deficit = math.max(0, (c.floor or 0) - math.max(0, c.rest or 0))
  if deficit <= EPS then return true, "plancher-tenu" end
  if (c.stock or 0) + EPS >= deficit * cfg.build_s then return true, "stock-couvre" end
  return false, "stock-insuffisant"
end

--- Le combustible manque-t-il ? Le stock ne tient pas cfg.horizon secondes du plancher. Sans plancher : non.
function M.low(stock, floor, cfg)
  cfg = cfg or M.CFG
  if (floor or 0) <= EPS then return false end
  return (stock or 0) + EPS < floor * cfg.horizon
end

return M
