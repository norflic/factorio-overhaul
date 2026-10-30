--[[
  Lot MAIN-ET-INTERMEDIAIRES, côté RUNTIME (règle pure : shared/team/intermediaires.lua ; demandes D09 et D10 du DC).

  Une fois par pensée d'équipe (script/team/team.lua, après le plan directeur et la reconstruction, AVANT l'attribution des
  tâches par le marché) :
    D09  pour chaque type d'avant-poste (T.OUTPOST_ORDER) : débit des MACHINES de son produit (ressource extraite aux statistiques
         de la force pour une faction, part de la main retirée, convertie en produit ; modules finis mesurés de l'équipe, f.team.ia3e.mods[].rate_meas, pour les
         deux équipes : la force « player » compte aussi l'usine du joueur humain, elle n'est pas lue). Au-delà du seuil, les
         tâches LIBRES de minage à la main de sa ressource sont retirées du tableau (planificateur, cerveau, manque de plaques,
         reconstruction), et le travail de fond ne les propose plus (script/team/poles.lua lit Inter.mine_skip : fond et renfort
         de fer du lot FER-EQUIPE). Exemptés : le mode survie (Survie.on) et les tâches « survie: » et « crise: ». Les tâches
         déjà prises vont à leur terme.
    D10  pour chaque module de l'équipe (f.team.ia3e.mods) dont le produit n'est pas une plaque fondue ni la centrale : plafond
         du stock (I.cap) ; au-delà, les tâches LIBRES de remplissage de ses quais d'entrée (Build, mode « fill ») sont retirées et
         ses matières ne sont plus fabriquées pour lui (script/ai3/automatisation.lua lit Inter.over).
  État : f.team.inter (nombres, chaînes, booléens ; créé ici, en événement, jamais à on_load). Sauvegardes d'avant le lot :
  rien à migrer (état créé à la première pensée ; lecture sans état = aucune décision changée).
  Journal : [FO-MAIN-FOURNIE] (D09) et [FO-INTERMEDIAIRE] (D10), une ligne par changement de décision.
  Déterminisme : listes triées (T.OUTPOST_ORDER, ordre des modules, State.sorted_keys), statistiques du moteur identiques chez
  tous les pairs, aucun temps mesuré.
]]

local T = require("shared.team.config")
local I = require("shared.team.intermediaires")
local Fond = require("shared.team.fond")
local State = require("script.faction.state")
local Board = require("script.team.board")
local Build = require("script.team.build")
local Stock = require("script.team.stock")
local Survie = require("script.team.survie")

local Inter = {}

-- Bascule (aucun réglage de carte : settings.lua est un fichier de l'intégrateur). false : décisions d'avant le lot.
Inter.ENABLED = true

local function state_of(f)
  local t = f.team
  t.inter = t.inter or { skip = {}, over = {}, dropped_mine = 0, dropped_fill = 0 }
  return t.inter
end

--- D09 (lecture seule, sans état créé) : ressources dont le minage à la main est coupé, { [ressource] = vrai }.
function Inter.mine_skip(f)
  local s = Inter.ENABLED and f and f.team and f.team.inter
  return (s and s.skip) or {}
end

--- D10 (lecture seule) : le module de ce produit ne doit-il plus être nourri ?
function Inter.over(f, product)
  local s = Inter.ENABLED and f and f.team and f.team.inter
  return (s and s.over and s.over[product]) == true
end

local function minutes(f, tick)
  local war = State.war()
  return (tick - (f.started or (war and war.started) or 0)) / 3600
end

-- Débit produit par minute aux statistiques de la force (nil : illisible).
local function stat_flow(f, item)
  local force = game.forces[f.force]
  local n = nil
  pcall(function()
    n = force.item_production_statistics.get_flow_count({ name = item, input = true,
      precision_index = defines.flow_precision_index.one_minute })
  end)
  if type(n) ~= "number" then return nil end
  return n
end

local function mods_of(f)
  return (f.team.ia3e and f.team.ia3e.mods) or {}
end

---------------------------------------------------------------------------------------------------
-- D09
---------------------------------------------------------------------------------------------------
local function d09(f, s, list, tick, survie)
  -- PNJ au minage à la main en ce moment, par ressource ; débit mesuré des modules finis, par produit.
  local hand = {}
  for _, t in ipairs(list) do
    if t.worker and t.kind == "mine" and t.resource then hand[t.resource] = (hand[t.resource] or 0) + 1 end
  end
  local mod_rate = {}
  for _, m in ipairs(mods_of(f)) do
    if m.state == "fini" and m.product then mod_rate[m.product] = (mod_rate[m.product] or 0) + (m.rate_meas or 0) end
  end
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local spec = T.outposts[kind]
    local res, prod = spec.resource, spec.product
    local input = T.smelter_inputs[prod]
    local per_ore = (input and input[1] == res and input[2] and input[2] > 0) and (1 / input[2]) or 1
    if prod == res or (input and input[1] == res) then
      local flow = I.machine_flow({ stat = (not f.is_player) and stat_flow(f, res) or nil, modules = mod_rate[prod],
        hand_miners = hand[res], per_ore = per_ore })
      local prev = s.skip[res] == true
      local now = I.hand_useless(prev, { flow = flow, survie = survie })
      if now ~= prev then
        s.skip[res] = now or nil
        log(string.format("[FO-MAIN-FOURNIE] %s : minage a la main de %s %s : machines %.0f/min (coupe a %d, repris sous %d)%s, taches libres retirees %d en tout a %.1f min",
          f.key or "player", res, now and "COUPE" or "repris", flow, I.MARGINAL * I.HAND_RATE, math.floor(I.MARGINAL * I.HAND_RATE * I.OFF),
          (survie and not now) and " [mode survie]" or "", s.dropped_mine, minutes(f, tick)))
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- D10
---------------------------------------------------------------------------------------------------
local function reserve_of(f, item)
  for _, r in ipairs(f.is_player and Fond.PLAYER_RESERVE or Fond.RESERVE) do
    if r[1] == item then return r[3] or r[2] or 0 end
  end
  return 0
end

local function d10(f, s, list, tick)
  local mods = mods_of(f)
  -- Produits suivis : modules nourris depuis le coffre (ni plaque fondue, ni centrale), dans l'ordre des modules.
  local products, seen = {}, {}
  for _, m in ipairs(mods) do
    local p = m.product
    if p and p ~= "centrale" and T.smelter_inputs[p] == nil and (m.state == "fini" or m.state == "chantier") and not seen[p] then
      seen[p] = true
      products[#products + 1] = p
    end
  end
  table.sort(products)
  -- Quais d'entrée des modules finis : nombre de modules qui prennent chaque objet.
  local feeders = {}
  if f.build then
    for _, m in ipairs(mods) do
      if m.state == "fini" then
        local b = Build.brief(f, m.id)
        for _, it in ipairs(b and b.quais or {}) do feeders[it] = (feeders[it] or 0) + 1 end
      end
    end
  end
  -- Demande des tâches ouvertes (objets réservés, pas encore pris).
  local demand = {}
  for _, t in ipairs(list) do
    if not t.took then
      for _, it in ipairs(t.items or t.uses or {}) do
        if seen[it[1]] then demand[it[1]] = (demand[it[1]] or 0) + (it[2] or 0) end
      end
    end
  end
  local bilan = f.team.ia3 and f.team.ia3.bilan and f.team.ia3.bilan.items or {}
  for _, p in ipairs(products) do
    local cons = bilan[p] and bilan[p].c or 0
    local a = { cons = cons, demand = demand[p], feeders = feeders[p], reserve = reserve_of(f, p) }
    local cap = I.cap(a)
    local have = (f.hq and f.hq.valid) and Stock.count(f, p) or 0
    local prev = s.over[p] == true
    local now = I.over(prev, have, cap)
    if now ~= prev then
      s.over[p] = now or nil
      log(string.format("[FO-INTERMEDIAIRE] %s : %s %s : stock %d, plafond %d (conso %.1f/min x %d min, demande %d, modules consommateurs %d, reserve %d ; repris sous %d), remplissages retires %d en tout a %.1f min",
        f.key or "player", p, now and "AU PLAFOND, module(s) plus nourri(s)" or "sous le plafond, module(s) de nouveau nourri(s)",
        have, cap, cons, I.HORIZON, a.demand or 0, a.feeders or 0, a.reserve, math.floor(cap * I.RESUME), s.dropped_fill, minutes(f, tick)))
    end
  end
  -- Produits qui ne sont plus suivis (module retiré) : décision oubliée.
  for _, p in ipairs(State.sorted_keys(s.over)) do if not seen[p] then s.over[p] = nil end end
end

---------------------------------------------------------------------------------------------------
-- Pensée
---------------------------------------------------------------------------------------------------
function Inter.think(f, tick)
  if not (Inter.ENABLED and f and f.team) then return 0 end
  local s = state_of(f)
  local list = Board.get(f).list or {}
  local survie = Survie.on(f)
  d09(f, s, list, tick, survie)
  d10(f, s, list, tick)
  -- Produit de chaque module (id -> produit), pour les remplissages de quais.
  local product_of = {}
  for _, m in ipairs(mods_of(f)) do if m.id then product_of[m.id] = m.product end end
  local skip, over = s.skip, s.over
  -- Rien de coupé ni au plafond (cas courant) : pas de parcours trié du tableau (Board.drop_free trie toutes les clés).
  -- `next` ne sert qu'à tester le vide : aucune décision ne dépend de l'ordre.
  if next(over) == nil and (survie or next(skip) == nil) then return 0 end
  local nm, nf = 0, 0
  local n = Board.drop_free(f, function(t)
    if t.kind == "mine" and t.resource and skip[t.resource] and not survie and not I.exempt_key(t.key) then
      nm = nm + 1
      return false
    end
    if t.kind == "carry" and t.ia1d and t.ia1d.mode == "fill" then
      local p = product_of[t.ia1d.pid]
      if p and over[p] then
        nf = nf + 1
        return false
      end
    end
    return true
  end)
  s.dropped_mine = s.dropped_mine + nm
  s.dropped_fill = s.dropped_fill + nf
  return n
end

return Inter
