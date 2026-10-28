--[[
  Lot IA3-b « personne n'attend » : MANQUE DE PLAQUES (PUR, aucune API Factorio). Branché derrière le réglage
  fo-war-ia3-marche (script/team/board.lua, Board.sync).

  Constat du DC (25/10 vers 18 h 40, capture fo-logs\2026-10-25_DC-captures\pnj-inactifs-fer-ignore.png) : « Objectif :
  Charbon — il manque : 62 Plaque de fer », une dizaine de PNJ attendent au coffre, un gisement de fer proche n'est pas
  exploité ; « ils farment de la pierre et du charbon […] ils en ont a foison » (18 h 45).
  Cause (lecture du code, shared/team/planner.lua §5) : le cerveau ne fait miner le minerai d'une plaque qui manque que
  s'il y a des fours au QG (view.smelters > 0) ; votre équipe n'en a aucun au départ (seules les factions en reçoivent,
  script/team/team.lua) ; et une seule tâche de minage par minerai (clé `mine:<minerai>`, IA3-DIAG C3 d). Le fond
  (shared/team/fond.lua) ne mine alors que charbon et pierre, même en surplus.

  X.tasks(view, missing, ctx) -> tâches du CERVEAU (pas de fond) à ajouter au tableau :
    1. une plaque manque et le QG a moins de X.SMELTERS fours (X.SMELTERS_MAX pour un manque d'au moins X.SMELT_MORE) :
       poser les fours au QG (tâche « smelters », comme la survie des factions) avec les fours et le charbon du coffre ;
       sans fours au coffre, les fabriquer (pierre) ;
    2. une plaque manque, aucun avant-poste ne la produit, et des fours existent (ou vont être posés) : PLUSIEURS PNJ
       minent son minerai (clés `manque:mine:<minerai>:<k>`) : k = max(manque / X.PER_MINER, mineurs au travail + PNJ
       inactifs + 1), au plus X.MINERS_MAX et l'effectif, en comptant les minages déjà au tableau pour ce minerai ; le
       cerveau fond ensuite (tournée « smelt » du planificateur, qui la propose dès qu'un four existe).
  X.need(view, missing) -> { [ressource] = facteur } pour la note des tâches d'extraction (M.need_factor).

  view = { smelters, smelters_pending, stock (LIBRE), outposts = { {kind}, ... }, workers }
  missing = { [plaque] = n } (plan.missing et plan.smelt du planificateur, voir Board.sync)
  ctx = { keys = { [clé] = vrai } (tâches au tableau ou en pause), mines = { [minerai] = tâches de minage au tableau },
          book (shared/team/book.lua : fabrication des fours) }
  Déterminisme : plaques dans un ordre fixe (X.PLATES) ; aucun pairs dans une décision.
]]

local T = require("shared.team.config")
local M = require("shared.ai3.marche")
local R = require("shared.ai3.reglages") -- lot IA-G : cibles de stock du marché (déplacées, inchangées)

local X = {}

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

-- Lot IA-G : plaques DÉDUITES des tables de l'exécutant (avant-postes dont le produit se fond au QG, dans leur ordre) :
-- { plaque, minerai, type d'avant-poste } ; sur les données d'aujourd'hui, fer puis cuivre, comme avant.
X.PLATES = {}
for _, kind in ipairs(T.OUTPOST_ORDER) do
  local spec = T.outposts[kind]
  local input = T.smelter_inputs[spec.product]
  if input and input[1] == spec.resource then X.PLATES[#X.PLATES + 1] = { spec.product, spec.resource, kind } end
end
X.SMELTERS = 2        -- fours posés au QG quand une plaque manque (T.hq_smelters)
X.SMELTERS_MAX = 4    -- … et 4 pour un manque d'au moins X.SMELT_MORE plaques
X.SMELT_MORE = 50
X.PER_MINER = 20      -- plaques manquantes par mineur (manque 62 : 4 mineurs au moins)
X.MINERS_MAX = 6
X.MINE_MIN = 25       -- un mineur rapporte au moins 25 minerais
X.MINE_MAX = 50
X.PRIO = 75           -- au-dessus des fabrications d'objectif (50) : sans plaque, aucun objectif n'avance
X.MINE_PRIO = 45      -- comme le minage du planificateur sans avant-poste
-- Besoin prévu de chaque matière (stock libre au-delà : surplus, M.NEED_SURPLUS) ; mêmes niveaux que le minage de fond
-- (shared/team/fond.lua, F.MINE_TARGETS).
X.TARGET = R.MARCHE_CIBLES

local function has_kind(view, kind)
  for _, o in ipairs(view.outposts or {}) do if o.kind == kind then return true end end
  return false
end

function X.tasks(view, missing, ctx)
  ctx = ctx or {}
  local keys = ctx.keys or {}
  local free = view.stock or {}
  local out = {}
  -- Seules comptent les plaques qui manquent SANS avant-poste qui les produise (avec un avant-poste, on attend sa
  -- tournée : règle du planificateur).
  local most = 0
  for _, p in ipairs(X.PLATES) do
    local n = missing[p[1]] or 0
    if n > most and not has_kind(view, p[3]) then most = n end
  end
  if most <= 0 then return out end
  local smelters = (view.smelters or 0) + (view.smelters_pending or 0)
  -- Lot IA-V2 : sous le cerveau par besoins (ctx.no_smelters), les fours du QG sont l'affaire de son approvisionnement
  -- (shared/ai3/projets.lua, P.supply, même règle de 2 ou 4 fours) : deux producteurs fabriquaient chacun leurs fours
  -- et vidaient la pierre du coffre (moteur réel, ia3b-fer, 27/10 : pierre à 0 en 2 min, 62 plaques à 9,0 min contre
  -- 4,7 min sans le cerveau). Ici, seulement les mineurs.
  local placing = false
  if ctx.no_smelters then
    smelters = math.max(1, smelters)
  else
  -- Fours voulus : X.SMELTERS, X.SMELTERS_MAX pour un gros manque (premier essai en moteur réel, 25/10 : 2 fours
  -- fondent 37 plaques par minute, le minerai attendait au coffre).
  local want = most >= X.SMELT_MORE and X.SMELTERS_MAX or X.SMELTERS
  if smelters < want then
    local n0 = want - smelters
    -- Les fours du coffre sont posés tout de suite (avec leur charbon), les autres fabriqués (pierre) en parallèle.
    local put = math.min(n0, math.max(0, free[T.SMELTER] or 0), math.floor(math.max(0, free[T.fuel] or 0) / T.fuel_per_burner))
    if put > 0 then
      if not keys["smelters"] then
        out[#out + 1] = { key = "smelters", kind = "smelters", prio = X.PRIO, count = put,
          items = { { T.SMELTER, put }, { T.fuel, T.fuel_per_burner * put } }, manque = true }
      end
      placing = true
    end
    if put < n0 and ctx.book and ctx.book:handcraftable(T.SMELTER) then
      local n = n0 - math.max(0, free[T.SMELTER] or 0)
      local key = "craft:" .. T.SMELTER .. ":manque:1"
      -- Les mineurs partent PENDANT que les fours se fabriquent (parallélisme demandé par le DC).
      if keys[key] then placing = true end
      if n > 0 and not keys[key] then
        local avail = {}
        -- Les fours déjà au coffre sont comptés dans n : le plan ne doit pas les « prendre » (besoin d'accumulation).
        -- Lot IA-G : tout le stock libre (au lieu d'une liste de trois matières écrite à la main) ; le plan du livre ne
        -- prend que ce que la recette du four demande.
        for _, k in ipairs(sorted_keys(free)) do if k ~= T.SMELTER then avail[k] = math.max(0, free[k] or 0) end end
        local plan = ctx.book:plan({ { T.SMELTER, n } }, avail)
        if next(plan.raw) == nil then
          local ks = {}
          for k in pairs(plan.uses) do ks[#ks + 1] = k end
          table.sort(ks)
          local uses = {}
          for _, k in ipairs(ks) do uses[#uses + 1] = { k, plan.uses[k] } end
          out[#out + 1] = { key = key, kind = "craft", prio = X.PRIO, item = T.SMELTER, count = n, steps = plan.crafts,
            uses = uses, tag = "manque", manque = true }
          placing = true
        end
      end
    end
  end
  end
  if smelters == 0 and not placing then return out end
  -- Lot IA-V2 : sous le cerveau par besoins, seulement le GOULOT (la plaque sans avant-poste qui manque le plus), comme
  -- son approvisionnement (shared/ai3/projets.lua) : deux plaques au même rang se partageaient les mineurs.
  local only = nil
  if ctx.no_smelters then
    local worst = 0
    for _, p in ipairs(X.PLATES) do
      local n = missing[p[1]] or 0
      if n > worst and not has_kind(view, p[3]) then only, worst = p[1], n end
    end
  end
  for _, p in ipairs(X.PLATES) do
    local short, ore, kind = missing[p[1]] or 0, p[2], p[3]
    if only and p[1] ~= only then short = 0 end
    -- Le minerai déjà au coffre couvre le manque : c'est la fonte qui manque, pas le minage (aucun mineur de plus).
    if short > 0 and not has_kind(view, kind) and (free[ore] or 0) < short then
      -- Mineurs : un par X.PER_MINER plaques qui manquent, et TOUT PNJ inactif de plus (« aucun n'attend au coffre tant
      -- qu'il manque une plaque », DC 18 h 40), plus UNE tâche d'avance (le mineur qui revient en reprend une tout de
      -- suite, sans attendre la pensée suivante : premier essai, 16 % de PNJ sans tâche pendant le manque) ; au plus
      -- X.MINERS_MAX et l'effectif.
      local base_k = math.ceil(short / X.PER_MINER)
      local taken = (ctx.mines_taken and ctx.mines_taken[ore]) or 0
      local k = math.max(base_k, taken + (view.workers_idle or 0) + 1)
      k = math.min(k, X.MINERS_MAX, math.max(1, view.workers or 0))
      local have = (ctx.mines and ctx.mines[ore]) or 0
      local count = math.max(X.MINE_MIN, math.min(X.MINE_MAX, math.ceil(short / base_k)))
      local i = 0
      while have < k and i < X.MINERS_MAX do
        i = i + 1
        local key = "manque:mine:" .. ore .. ":" .. i
        if not keys[key] then
          out[#out + 1] = { key = key, kind = "mine", prio = X.MINE_PRIO, resource = ore, count = count, manque = true,
            prudent = true } -- lot IA-V2 : pas de minage à moins de 40 tuiles d'un nid ou d'un ver (worker.lua)
          have = have + 1
        end
      end
    end
  end
  return out
end

--- Facteur de besoin de chaque matière extraite (minage, tournée d'un avant-poste) et de la fonte (plaques) : manque du
--- cerveau, surplus ou normal (M.need_factor). Le minerai d'une plaque qui manque est « en manque » tant que le minerai
--- du coffre ne couvre pas le manque ; au-delà, c'est la fonte (facteur de la plaque) qui passe devant le minage.
function X.need(view, missing)
  local free = view.stock or {}
  local out = {}
  local short = {}
  for _, p in ipairs(X.PLATES) do
    local n = missing[p[1]] or 0
    if n > 0 then
      short[p[1]] = true
      if (free[p[2]] or 0) < n then short[p[2]] = true end
    end
  end
  local mats = {} -- lot IA-G : ressources et produits des avant-postes (tables de l'exécutant), triés
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    mats[T.outposts[kind].resource] = true
    mats[T.outposts[kind].product] = true
  end
  for _, r in ipairs(sorted_keys(mats)) do
    local want = X.TARGET[r] or 0
    out[r] = M.need_factor(free[r] or 0, want, short[r] or (missing[r] or 0) > 0)
  end
  return out
end

return X
