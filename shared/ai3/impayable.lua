--[[
  Lot RB-FLUIDE (1/11) : la RECHERCHE IMPAYABLE. Règle PURE (aucune API Factorio, AUCUN nom d'objet : anti-échelle de tests/iag_test.lua ;
  tests/ai3_impayable_test.lua). Partie de 4 h du lot C4 : `military-3` tient le laboratoire de 45 à 202 min parce que son pack n'est jamais
  fabriqué ; la garde existante (script/ai3/general.lua, « PLAYER_STALL ») ne valait que pour le JOUEUR.

  Règle (celle du joueur, étendue aux factions et complétée de deux sorties) :
    1. ARRÊT : une recherche qui n'a payé AUCUNE unité depuis Im.STALL ticks est lâchée ; les autres passent pendant Im.PAUSE ticks ; on retient
       les packs qui MANQUAIENT (stock inférieur à ce qu'une unité coûte).
    2. RETOUR : avant la fin de la pause, la recherche revient dès que chacun de ces packs est au stock pour au moins Im.UNITS unités (ou le reste
       de la recherche s'il est plus court) : « le pack est produit ». Jamais sur une seule unité : sinon elle repartirait pour s'arrêter de nouveau.
    2 bis. PACK RETENU (lot LABOS-ARRET) : pendant la pause, les autres recherches qui demandent un pack retenu sont écartées aussi (Im.blocked_by_packs) :
       sans cela, 63 lâchers sur 86 passaient à une recherche qui attendait le même pack (fo-logs/2026-11-12_PACK-OSCILLE).
    3. RIEN D'AUTRE DE PAYABLE : si, toutes les autres écartées, aucune recherche n'est payable, la recherche lâchée depuis le plus longtemps revient
       (le laboratoire ne reste pas oisif) et la garde ne la reprend plus avant Im.PAUSE ticks (`grace`) : au plus un retour par pause, aucune
       oscillation.
  État de l'appelant (nombres et chaînes seulement, sérialisable) : st.stalled[tech] = tick de fin de pause (forme de l'ancienne garde),
  st.stall_packs[tech] = liste triée de packs, st.grace[tech] = tick avant lequel la garde ne rejoue pas.
  Déterminisme : listes triées, aucun pairs décisionnel, aucune horloge mesurée.
]]

local Im = {}

local min = math.min

Im.STALL = 3 * 3600   -- sans unité payée depuis 3 min (audit point 29 : les labos ne restent plus 8 à 10 min à l'arrêt)
Im.PAUSE = 30 * 3600  -- les autres recherches passent 30 min au plus
Im.UNITS = 5          -- unités de pack au stock pour revenir avant la fin de la pause

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Ticks écoulés depuis la dernière unité payée de la recherche en cours (ou son début) ; nil s'il n'y en a pas.
function Im.idle(lab, tick)
  if not (lab and lab.tech) then return nil end
  return tick - (lab.paid_tick or lab.started or tick)
end

--- Faut-il lâcher la recherche en cours ? `done` : la technologie est faite ; `grace` : tick avant lequel la garde ne rejoue pas (nil : aucun).
function Im.should_stall(lab, tick, done, grace)
  if not (lab and lab.tech) or done or lab.stalled then return false end
  if grace ~= nil and tick < grace then return false end
  return Im.idle(lab, tick) > Im.STALL
end

--- Packs qui manquent au stock pour UNE unité : `ingredients` = { { pack, n } }, `stock` = { [pack] = n }. Liste triée.
function Im.missing(ingredients, stock)
  local out = {}
  for _, ing in ipairs(ingredients or {}) do
    if (stock[ing[1]] or 0) < ing[2] then out[#out + 1] = ing[1] end
  end
  table.sort(out)
  return out
end

--- Lâche `tech` : pause jusqu'à tick + Im.PAUSE, packs manquants retenus.
function Im.stall(st, tech, tick, packs)
  st.stalled = st.stalled or {}
  st.stall_packs = st.stall_packs or {}
  st.stalled[tech] = tick + Im.PAUSE
  st.stall_packs[tech] = packs or {}
end

--- Les packs retenus de `tech` sont-ils au stock pour assez d'unités ? `ingredients` = { { pack, n } } de la technologie, `remaining` = unités qui restent.
function Im.released(st, tech, ingredients, stock, remaining)
  local packs = st.stall_packs and st.stall_packs[tech]
  if not packs or #packs == 0 then return false end
  local units = min(Im.UNITS, math.max(1, remaining or Im.UNITS))
  local need = {}
  for _, ing in ipairs(ingredients or {}) do need[ing[1]] = ing[2] end
  for _, p in ipairs(packs) do
    if (stock[p] or 0) < (need[p] or 1) * units then return false end
  end
  return true
end

--- Les recherches écartées à ce tick : { [tech] = vrai }. Une pause finie, ou un retour (Im.released), l'efface. `ingredients_of(tech)` et
--- `remaining_of(tech)` : fonctions de l'appelant ; `stock` : { [pack] = n }.
function Im.active(st, tick, ingredients_of, remaining_of, stock)
  local out = {}
  for _, t in ipairs(sorted_keys(st.stalled)) do
    if tick >= st.stalled[t] or Im.released(st, t, ingredients_of(t), stock, remaining_of(t)) then
      st.stalled[t] = nil
      if st.stall_packs then st.stall_packs[t] = nil end
    else
      out[t] = true
    end
  end
  return out
end

--- Lot LABOS-ARRET (B4) : une recherche est lâchée pour les PACKS qui lui manquent ; toute autre recherche qui en demande un attendrait le même pack.
--- Rend { [tech] = vrai } des recherches de `techs` (liste triée) dont un ingrédient est retenu par une recherche lâchée encore écartée (`active`,
--- rendu d'Im.active), sauf `except` (la recherche de la défense, jamais écartée). Le retour (Im.released) ou la fin de la pause lève l'écart.
function Im.blocked_by_packs(st, active, techs, ingredients_of, except)
  local held = {}
  for _, t in ipairs(sorted_keys(active)) do
    for _, p in ipairs((st.stall_packs or {})[t] or {}) do held[p] = true end
  end
  local out = {}
  if next(held) == nil then return out end
  for _, t in ipairs(techs or {}) do
    if t ~= except then
      for _, ing in ipairs(ingredients_of(t) or {}) do
        if held[ing[1]] then out[t] = true break end
      end
    end
  end
  return out
end

--- Rien d'autre de payable : rend la recherche lâchée depuis le plus longtemps (fin de pause la plus proche, puis le nom), l'enlève des pauses et
--- pose sa `grace` ; nil s'il n'y en a aucune.
function Im.lift(st, tick)
  local best
  for _, t in ipairs(sorted_keys(st.stalled)) do
    if best == nil or st.stalled[t] < st.stalled[best] then best = t end
  end
  if not best then return nil end
  st.stalled[best] = nil
  if st.stall_packs then st.stall_packs[best] = nil end
  st.grace = st.grace or {}
  st.grace[best] = tick + Im.PAUSE
  return best
end

--- Nettoie les `grace` finies (état borné). Rend le nombre retiré.
function Im.expire_grace(st, tick)
  local n = 0
  for _, t in ipairs(sorted_keys(st.grace)) do
    if tick >= st.grace[t] then
      st.grace[t] = nil
      n = n + 1
    end
  end
  return n
end

return Im
