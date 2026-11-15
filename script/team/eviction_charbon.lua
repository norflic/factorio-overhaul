--[[
  Lot ENERGIE-0916 : retrait des foreuses et coffres d'avant-poste du minerai `item` dans un lot du treillis, au profit du projet
  d'alimentation d'une centrale (règle pure : shared/team/eviction_charbon.lua). Même geste que le remplacement thermique
  (script/team/foreuse_swap.lua, revert_one) : plus « possédée » avant le retrait, entité et contenu minés vers le stock de l'équipe,
  listes de l'avant-poste compactées. Les tuiles libérées sont ensuite réservées par le plan du projet (PlacesQG.is_reserved) : aucun
  avant-poste ne s'y repose.
]]

local State = require("script.faction.state")
local Stock = require("script.team.stock")
local Ev = require("shared.team.eviction_charbon")

local R = {}

local function compact(o)
  local kd, ks = {}, {}
  for _, d in ipairs(o.drill_list or {}) do if d.valid then kd[#kd + 1] = d end end
  for _, s in ipairs(o.sinks or {}) do if s.valid then ks[#ks + 1] = s end end
  local lost = #(o.drill_list or {}) - #kd
  o.drill_list, o.sinks = kd, ks
  o.drills = math.max(0, (o.drills or 0) - lost)
end

--- Entités (foreuses, coffres) des avant-postes de `item` dont le centre est dans `rect`, triées (Ev.inside).
local function pick_of(f, item, rect)
  local list = {}
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    if o and o.kind == item then
      for _, d in ipairs(o.drill_list or {}) do
        if d.valid then list[#list + 1] = { x = d.position.x, y = d.position.y, kind = "drill", e = d, o = o } end
      end
      for _, s in ipairs(o.sinks or {}) do
        if s.valid then list[#list + 1] = { x = s.position.x, y = s.position.y, kind = "sink", e = s, o = o } end
      end
    end
  end
  return Ev.inside(list, rect)
end

--- Tuiles (clés tkey) couvertes par ces entités, et leur nombre d'entités : l'essai à blanc du placement les compte libres.
function R.tiles(f, item, rect, tkey)
  local set = {}
  local pick = pick_of(f, item, rect)
  for _, it in ipairs(pick) do
    local bb = it.e.bounding_box
    for ty = math.floor(bb.left_top.y + 0.01), math.ceil(bb.right_bottom.y - 0.01) - 1 do
      for tx = math.floor(bb.left_top.x + 0.01), math.ceil(bb.right_bottom.x - 0.01) - 1 do set[tkey(tx, ty)] = true end
    end
  end
  return set, #pick
end

--- Journal : aucun lot ne tient la ligne, rien n'est retiré.
function R.vain(f, p, tried, tick)
  local b = f.build
  b.evict_logs = (b.evict_logs or 0) + 1
  if b.evict_logs <= Ev.LOGS then
    log(Ev.line_vain({ team = f.key or "player", pid = p.id, plant = p.spec and p.spec.alim, tried = tried, tick = tick }))
  end
end

--- Retire du lot `rect` les foreuses et coffres des avant-postes de `item`. Rend le nombre d'entités retirées.
function R.lot(f, item, rect, p, tick)
  local pick = pick_of(f, item, rect)
  if #pick == 0 then return 0 end
  local nd, ns, kept, touched, tids = 0, 0, 0, {}, {}
  local invs = Stock.inventories(f)
  for _, it in ipairs(pick) do
    local e = it.e
    if e.valid then
      local unit = e.unit_number
      if unit then State.disown(unit) end
      local mined = false
      for _, inv in ipairs(invs) do
        if inv and inv.valid and e.mine({ inventory = inv, force = false, raise_destroyed = true }) then mined = true break end
      end
      if mined then
        if it.kind == "drill" then nd = nd + 1 else ns = ns + 1 end
        if not touched[it.o.id] then touched[it.o.id] = it.o; tids[#tids + 1] = it.o.id end
      else
        if e.valid then State.own(e, f.id, it.kind, it.o.id) end
        kept = kept + 1
      end
    end
  end
  table.sort(tids)
  for _, id in ipairs(tids) do compact(touched[id]) end
  local b = f.build
  b.evict_logs = (b.evict_logs or 0) + 1
  if b.evict_logs <= Ev.LOGS then
    log(Ev.line({ team = f.key or "player", pid = p.id, plant = p.spec and p.spec.alim, x0 = rect.x0, y0 = rect.y0, drills = nd, sinks = ns,
      kept = kept, tick = tick }))
  end
  return nd + ns
end

return R
