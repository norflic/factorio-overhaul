--[[
  Lot STOCKAGE-VITAL (retour du DC en jeu sur 0.6.58, 7/11 : « ils se sont retrouvés avec des coffres remplis de pierres […] ils ont pas
  pensé à poser des coffres […] c'est en posant les coffres à un moment que ça s'est libéré […] les coffres, il faudrait prévoir »).
  Règle PURE (aucun appel au moteur) : le stock d'une équipe (coffre du QG + annexes, script/team/stock.lua) garde de la place aux
  matières VITALES (fer, charbon : T.stock_vital), cesse de ramasser une matière non vitale quand elle est saturée ou que le stock est
  presque plein, et réclame un coffre en URGENCE au-dessus d'un seuil de remplissage, avant la saturation.

    Sg.reserve_slots(size, cfg)                 cases gardées aux matières vitales (cfg.reserve des cases, arrondi au-dessus)
    Sg.new_stacks(item, empty, size, vital, cfg) cases VIDES que `item` peut prendre (vitale : toutes ; sinon au-delà de la réserve)
    Sg.skip(saturated, fill, vital, cfg, short) matières à NE PAS ramasser aux avant-postes : non vitales saturées tant qu'une autre
                                                matière manque (short ~= false : même règle que le cerveau, Ia3.after_poles, et que le
                                                stop_stone de la sortie de spirale, shared/team/spirale.lua, qui s'y ramène), et toutes
                                                les non vitales quand le stock est rempli à cfg.stop_at ou plus (ensemble { [objet] = true })
    Sg.urgent(fill, have_chest, cfg)            vrai : coffre à réclamer en urgence (rempli à cfg.urgent_at ou plus, aucun en main)
  `fill` = cases prises / cases ; `vital` = { [objet] = true } ; `saturated` = { [objet] = true } (cerveau, f.team.ia3.saturated).
  Données : T.stockage (shared/team/config.lua).
]]

local Sg = {}

Sg.DEFAULT = { reserve = 0.15, stop_at = 0.80, urgent_at = 0.80 }

local function cfg_of(cfg) return cfg or Sg.DEFAULT end

function Sg.reserve_slots(size, cfg)
  cfg = cfg_of(cfg)
  if not size or size <= 0 then return 0 end
  return math.ceil(cfg.reserve * size - 1e-9)
end

function Sg.new_stacks(item, empty, size, vital, cfg)
  empty = math.max(0, empty or 0)
  if vital and vital[item] then return empty end
  return math.max(0, empty - Sg.reserve_slots(size, cfg))
end

function Sg.skip(saturated, fill, vital, cfg, short)
  cfg = cfg_of(cfg)
  local out = {}
  vital = vital or {}
  if short ~= false then
    for item in pairs(saturated or {}) do
      if not vital[item] then out[item] = true end
    end
  end
  out.__all_non_vital = (fill or 0) >= cfg.stop_at or nil
  return out
end

--- Vrai si `item` ne doit pas être ramassé selon l'ensemble rendu par Sg.skip.
function Sg.skipped(set, item, vital)
  if not set or (vital and vital[item]) then return false end
  return set[item] == true or set.__all_non_vital == true
end

function Sg.urgent(fill, have_chest, cfg)
  cfg = cfg_of(cfg)
  return (fill or 0) >= cfg.urgent_at and not have_chest
end

--- Rappel pour le coffre urgent (moteur réel, micro-banc stockage-plein v2 du 7/11 : la tâche à 90 restait au tableau 70 s, « inactifs
--- 0/4 », comme chez le DC, « 0 PNJ libre(s), 16 tache(s) libre(s) »). npcs = { { id, busy, prio, exempt, d2 }, ... } ; rend nil si un
--- PNJ est libre (il prendra la tâche) ; sinon l'identifiant du PNJ le plus proche du QG (d2) dont la tâche n'est pas exemptée
--- (défense, coffre urgent) et passe sous urgent_prio ; à distance égale, le plus petit identifiant ; nil si aucun.
function Sg.recall_pick(npcs, urgent_prio)
  local best
  for _, n in ipairs(npcs or {}) do
    if not n.busy then return nil end
  end
  for _, n in ipairs(npcs or {}) do
    if not n.exempt and (n.prio or 0) < urgent_prio then
      if not best or n.d2 < best.d2 or (n.d2 == best.d2 and n.id < best.id) then best = n end
    end
  end
  return best and best.id or nil
end

return Sg
