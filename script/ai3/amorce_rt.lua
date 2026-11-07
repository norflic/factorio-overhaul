--[[
  Lot VIDEO L7, branchement (INTEGRATION_VIDEO.md étape 10) : la colle entre le runtime et la règle pure de l'amorce
  (shared/ai3/amorce.lua, Am, qui étend le mall Ml sans le modifier).
    - AmRt.seed (appelé par Ind.think, script/ai3/industrie.lua, avant Ml.sources) : la liste de matériel des Am.K prochains projets
      du plan directeur (pièces planifiées pas encore posées, moins ce que le projet a déjà pris : le calcul de Stock.demand), moins le
      stock BRUT du coffre (Stock.count : la liste est brute, le stock libre en retire déjà les réservations), devient la graine du mall.
    - AmRt.observe (appelé par le relevé de la capitalisation, juste après Cf.step de L5) : la 1re production est l'événement
      `confirmed_now` de la confirmation (L5 : produits finis de CHAQUE machine), JAMAIS les statistiques de la force. Piège de la force
      partagée : votre équipe EST la force du joueur, et ce que le joueur fabrique à la main entre dans
      force.item_production_statistics ; lues là, ces fabrications passeraient pour celles d'une machine et la main des PNJ serait
      retirée sans qu'aucune machine ait produit. La main des PNJ (compteurs de l'automatisation, f.team.ia3e.hand_all : hors des
      statistiques, F244) nourrit le compteur d'amorce. Le verrou tombe quand plus aucune unité du carnet de L5 ne fabrique l'objet.
  État : ml.amorce (règle), cs.amorce_hand (dernier relevé des compteurs de la main) : nombres et chaînes, aucune fonction.
  Aucun nom d'objet (anti-échelle de tests/iag_test.lua §8). Testé hors jeu : tests/amorce_glue_test.lua.
]]

local Am = require("shared.ai3.amorce")
local Ml = require("shared.ai3.mall")

local AmRt = {}
AmRt.Am = Am

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

--- Projets du plan directeur à servir, dans l'ordre de la file, avec leur liste de matériel (pièces pas encore posées, moins p.stock).
--- Les projets finis, refusés, ou dont toutes les pièces sont posées n'y sont pas.
function AmRt.projects(f)
  local b = f.build
  local out = {}
  if not (b and b.order and b.projects) then return out end
  for _, id in ipairs(b.order) do
    local p = b.projects[id]
    if p and p.state ~= "fini" and p.state ~= "refuse" then
      local need = {}
      for _, e in ipairs(p.ents or {}) do
        if not e.built and e.item then need[e.item] = (need[e.item] or 0) + 1 end
      end
      local bom, any = {}, false
      for _, it in ipairs(sorted_keys(need)) do
        local n = need[it] - ((p.stock or {})[it] or 0)
        if n > 0 then bom[it] = n; any = true end
      end
      if any then out[#out + 1] = { id = id, bom = bom } end
    end
  end
  return out
end

--- (a) La graine. count(item) = stock BRUT (Stock.count). Rend la liste semée (Am.seed).
function AmRt.seed(f, ml, tick, book, count)
  local projets = AmRt.projects(f)
  local have = {}
  local seen = {}
  for i = 1, math.min(Am.K, #projets) do
    for _, it in ipairs(sorted_keys(projets[i].bom)) do
      if not seen[it] then seen[it] = true; have[it] = count(it) or 0 end
    end
  end
  return Am.seed(ml, tick, projets, have, book, Ml)
end

--- (b) et (c) Relevé : cfr = résultat de Cf.step (L5) ; book = carnet de la confirmation (cs.cf). Rend les retraits de ce relevé.
function AmRt.observe(f, cs, ml, cfr, book, tick)
  if not (ml and cfr) then return {} end
  -- la main des PNJ depuis le relevé précédent (compteurs cumulés : le premier relevé ne fait que poser la base)
  local ha = (f.team and f.team.ia3e and f.team.ia3e.hand_all) or {}
  local prev = cs.amorce_hand
  local flows = {}
  local now = {}
  for _, k in ipairs(sorted_keys(ha)) do
    now[k] = ha[k]
    local d = (ha[k] or 0) - ((prev or {})[k] or 0)
    if prev and prev[k] ~= nil and d > 0 then flows[k] = { made = d, hand = d } end
  end
  cs.amorce_hand = now
  -- la 1re production d'une MACHINE : une unité confirmée à ce relevé (produits finis de la machine), jamais la force
  for _, ev in ipairs(cfr.confirmed_now or {}) do
    if ev.item then
      local fl = flows[ev.item] or { made = 0, hand = 0 }
      fl.made = (fl.hand or 0) + 1
      flows[ev.item] = fl
    end
  end
  -- objets qu'une unité du carnet fabrique encore (engagée, confirmée, arrêtée) : le verrou des autres tombe
  local alive = {}
  for _, id in ipairs((book and book.list) or {}) do
    local u = book.ids and book.ids[id]
    if u and u.item then alive[u.item] = true end
  end
  return Am.observe(ml, tick, flows, alive)
end

--- Lignes [FO-AMORCE] des retraits.
function AmRt.lines(f, ml, retraits, minutes)
  local out = {}
  for _, r in ipairs(retraits or {}) do
    out[#out + 1] = string.format("[FO-AMORCE] %s : %s a %.1f min", f.key or "?", Am.describe(r, ml), minutes or 0)
  end
  return out
end

return AmRt
