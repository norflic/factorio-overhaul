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
    1. une plaque manque et le QG n'a aucun four : poser X.SMELTERS fours au QG (tâche « smelters », comme la survie
       des factions) avec les fours et le charbon du coffre ; sans fours au coffre, les fabriquer (pierre) ;
    2. une plaque manque, aucun avant-poste ne la produit, et des fours existent (ou vont être posés) : PLUSIEURS PNJ
       minent son minerai (clés `manque:mine:<minerai>:<k>`), k ≤ min(manque / X.PER_MINER, moitié de l'équipe,
       X.MINERS_MAX), en comptant les minages déjà au tableau pour ce minerai ; le cerveau fond ensuite (tournée
       « smelt » du planificateur, qui la propose dès qu'un four existe).
  X.need(view, missing) -> { [ressource] = facteur } pour la note des tâches d'extraction (M.need_factor).

  view = { smelters, smelters_pending, stock (LIBRE), outposts = { {kind}, ... }, workers }
  missing = { [plaque] = n } (plan.missing et plan.smelt du planificateur, voir Board.sync)
  ctx = { keys = { [clé] = vrai } (tâches au tableau ou en pause), mines = { [minerai] = tâches de minage au tableau },
          book (shared/team/book.lua : fabrication des fours) }
  Déterminisme : plaques dans un ordre fixe (X.PLATES) ; aucun pairs dans une décision.
]]

local T = require("shared.team.config")
local M = require("shared.ai3.marche")

local X = {}

X.PLATES = { { "iron-plate", "iron-ore", "iron" }, { "copper-plate", "copper-ore", "copper" } }
X.SMELTERS = 2        -- fours posés au QG quand une plaque manque (T.start_smelters des factions)
X.PER_MINER = 20      -- plaques manquantes par mineur (manque 62 : 4 mineurs, au plus)
X.MINERS_MAX = 6
X.MINE_MIN = 20       -- un mineur rapporte au moins 20 minerais
X.MINE_MAX = 50
X.PRIO = 75           -- au-dessus des fabrications d'objectif (50) : sans plaque, aucun objectif n'avance
X.MINE_PRIO = 45      -- comme le minage du planificateur sans avant-poste
-- Besoin prévu de chaque matière (stock libre au-delà : surplus, M.NEED_SURPLUS) ; mêmes niveaux que le minage de fond
-- (shared/team/fond.lua, F.MINE_TARGETS).
X.TARGET = { coal = 400, stone = 200, ["iron-ore"] = 200, ["copper-ore"] = 100 }

local function has_kind(view, kind)
  for _, o in ipairs(view.outposts or {}) do if o.kind == kind then return true end end
  return false
end

function X.tasks(view, missing, ctx)
  ctx = ctx or {}
  local keys = ctx.keys or {}
  local free = view.stock or {}
  local out = {}
  local any = false
  for _, p in ipairs(X.PLATES) do if (missing[p[1]] or 0) > 0 then any = true end end
  if not any then return out end
  local smelters = (view.smelters or 0) + (view.smelters_pending or 0)
  local placing = false
  if smelters == 0 then
    local fuel = T.fuel_per_burner * X.SMELTERS
    if (free[T.SMELTER] or 0) >= X.SMELTERS and (free[T.fuel] or 0) >= fuel then
      if not keys["smelters"] then
        out[#out + 1] = { key = "smelters", kind = "smelters", prio = X.PRIO, count = X.SMELTERS,
          items = { { T.SMELTER, X.SMELTERS }, { T.fuel, fuel } }, manque = true }
      end
      placing = true
    elseif ctx.book and ctx.book:handcraftable(T.SMELTER) then
      local n = X.SMELTERS - (free[T.SMELTER] or 0)
      local key = "craft:" .. T.SMELTER .. ":manque:1"
      -- Les mineurs partent PENDANT que les fours se fabriquent (parallélisme demandé par le DC).
      if keys[key] then placing = true end
      if n > 0 and not keys[key] then
        local avail = {}
        -- Les fours déjà au coffre sont comptés dans n : le plan ne doit pas les « prendre » (besoin d'accumulation).
        for _, k in ipairs({ "stone", "iron-plate", "copper-plate" }) do avail[k] = math.max(0, free[k] or 0) end
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
  if smelters == 0 and not placing then return out end
  for _, p in ipairs(X.PLATES) do
    local short, ore, kind = missing[p[1]] or 0, p[2], p[3]
    if short > 0 and not has_kind(view, kind) then
      local half = math.max(1, math.floor((view.workers or 0) / 2))
      local k = math.min(math.ceil(short / X.PER_MINER), half, X.MINERS_MAX)
      local have = (ctx.mines and ctx.mines[ore]) or 0
      local count = math.max(X.MINE_MIN, math.min(X.MINE_MAX, math.ceil(short / k)))
      local i = 0
      while have < k and i < X.MINERS_MAX do
        i = i + 1
        local key = "manque:mine:" .. ore .. ":" .. i
        if not keys[key] then
          out[#out + 1] = { key = key, kind = "mine", prio = X.MINE_PRIO, resource = ore, count = count, manque = true }
          have = have + 1
        end
      end
    end
  end
  return out
end

--- Facteur de besoin de chaque matière extraite (minage, tournée d'un avant-poste) : manque du cerveau, surplus ou
--- normal (M.need_factor). Le minerai d'une plaque qui manque est « en manque ».
function X.need(view, missing)
  local free = view.stock or {}
  local out = {}
  local short = {}
  for _, p in ipairs(X.PLATES) do
    if (missing[p[1]] or 0) > 0 then short[p[2]] = true; short[p[1]] = true end
  end
  for _, r in ipairs({ "coal", "stone", "iron-ore", "copper-ore", "iron-plate", "copper-plate" }) do
    local want = X.TARGET[r] or 0
    out[r] = M.need_factor(free[r] or 0, want, short[r] or (missing[r] or 0) > 0)
  end
  return out
end

return X
