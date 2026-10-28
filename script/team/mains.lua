--[[
  LOT MAINS (runtime) : ce que les PNJ d'une équipe font À LA MAIN, et quand le fond s'en abstient (règle pure :
  shared/team/mains.lua).

  1. Mesure : crochet de fin de tâche (Board.finish) ; une ligne « [FO-MAINS] » toutes les 10 minutes par équipe (cumul
     depuis le début de la partie, étiquettes « genre:détail », « + » = fond, « @origine », « #sat »).
  2. Décision : Mains.skips(f, tick, workers) rend les ressources à ne pas MINER et les plaques à ne pas FONDRE de fond,
     parce que les machines les fournissent (saturation, module fini, débit automatique mesuré). Le débit est lu à la
     minute dans les statistiques de production de la force (production − minage à la main des PNJ) ; aucune décision
     n'est pilotée par un temps mesuré (la minute est celle du jeu).
  État : f.team.mains = { acc, last, flow = { [produit] = { last, ring, hand, hu, hs } }, min, why }.
]]

local State = require("script.faction.state")
local T = require("shared.team.config")
local B = require("shared.ai3.buts")
local Br = require("shared.ai3.bras")
local Mains = require("shared.team.mains")

local M = {}
M.PERIOD = 10 -- minutes entre deux lignes de mesure

local CHAINS = Mains.chains(T)
local PRODUCT_OF = {} -- ressource -> produit de son avant-poste
for _, ch in ipairs(CHAINS) do PRODUCT_OF[ch.resource] = ch.product end

local function minutes(f, tick)
  local war = State.war()
  return (tick - (f.started or (war and war.started) or 0)) / 3600
end

local function state_of(f)
  local st = f.team.mains
  if not st then st = { acc = {}, last = 0, flow = {}, min = -1, why = "" }; f.team.mains = st end
  return st
end

--- Fin d'une tâche (réussie ou non) de l'équipe `f`.
function M.on_done(f, task, ok, tick)
  if not (f and f.team and task) then return end
  local st = state_of(f)
  local secs = task.claimed and (tick - task.claimed) / 60 or 0
  local units = Mains.units(task)
  local label = Mains.label(task, function(oid)
    local o = f.outposts and f.outposts[oid]
    local spec = o and T.outposts[o.kind]
    return spec and spec.product or nil
  end, function(tk)
    -- minage de l'entrée d'une plaque, ou fonte de plaques : la plaque est-elle saturée au cerveau (f.team.ia3.saturated) ?
    local sat = f.team.ia3 and f.team.ia3.saturated or {}
    if tk.kind == "mine" then
      local p = PRODUCT_OF[tk.resource]
      return p ~= nil and sat[p] == true
    elseif tk.kind == "smelt" then
      local any = false
      for _, p in ipairs(Mains.sorted_keys(tk.smelt)) do
        if sat[p] ~= true then return false end
        any = true
      end
      return any
    end
    return false
  end)
  Mains.add(st.acc, label, ok, secs, units)
  -- minage à la main réussi : unités retirées du débit « automatique » du produit (la fonte au QG les compte aux machines)
  if ok and task.kind == "mine" and PRODUCT_OF[task.resource] then
    local fl = st.flow[PRODUCT_OF[task.resource]]
    if not fl then fl = { last = nil, ring = {}, hand = 0 }; st.flow[PRODUCT_OF[task.resource]] = fl end
    fl.hand = (fl.hand or 0) + units
    fl.hu, fl.hs = (fl.hu or 0) + units, (fl.hs or 0) + secs -- rendement d'un PNJ au minage (unités, secondes)
  end
  local m = math.floor(minutes(f, tick) / M.PERIOD)
  if m > st.last then
    st.last = m
    log(string.format("[FO-MAINS] %s minute %d | %s", f.key or "player", m * M.PERIOD, Mains.format(st.acc)))
  end
end

--- Une mesure par minute de jeu : production des machines (statistiques de la force) et minage à la main de chaque produit.
local function sample(f, st, tick)
  local minute = math.floor(tick / 3600)
  if st.min == minute then return end
  st.min = minute
  local force = game.forces[f.force]
  local stats = nil
  pcall(function() stats = force and force.item_production_statistics end)
  for _, ch in ipairs(CHAINS) do
    local fl = st.flow[ch.product]
    if not fl then fl = { last = nil, ring = {}, hand = 0 }; st.flow[ch.product] = fl end
    local n = nil
    if stats then pcall(function() n = stats.get_input_count(ch.product) end) end
    if n then
      if fl.last then
        fl.ring[#fl.ring + 1] = { total = math.max(0, n - fl.last), hand = fl.hand or 0 }
        while #fl.ring > Mains.COVER_MIN do table.remove(fl.ring, 1) end
      end
      fl.last = n
    end
    fl.hand = 0
  end
end

--- Matières à ne pas travailler à la main de fond : mine_skip { [ressource] = raison }, smelt_skip { [plaque] = raison }.
function M.skips(f, tick, workers, stock)
  local st = state_of(f)
  sample(f, st, tick)
  local ia = f.team.ia3
  local floor = Br.need_floor(workers or f.engineers_count or 0, B.NEED_FLOOR)
  local c = { saturated = ia and ia.saturated or {}, modules = ia and ia.covered or {}, need = {}, flow = {}, hand = {}, stock = stock }
  for _, ch in ipairs(CHAINS) do
    c.need[ch.product] = math.max(floor, ia and ia.need and ia.need[ch.product] or 0)
    local fl = st.flow[ch.product]
    if fl then
      local rate, n = Mains.auto_flow(fl.ring)
      c.flow[ch.product] = { rate = rate, n = n }
      c.hand[ch.product] = Mains.hand_rate(fl.hu, fl.hs)
    end
  end
  local mine, smelt = Mains.skips(CHAINS, c)
  -- journal : seulement quand l'ensemble change
  local parts = {}
  for _, k in ipairs(Mains.sorted_keys(mine)) do parts[#parts + 1] = k .. "=" .. mine[k] end
  for _, k in ipairs(Mains.sorted_keys(smelt)) do parts[#parts + 1] = "fonte:" .. k .. "=" .. smelt[k] end
  local why = table.concat(parts, " ")
  if why ~= st.why then
    st.why = why
    log(string.format("[FO-MAINS] %s minute %.0f | fond sans minage ni fonte a la main de : [%s]", f.key or "player",
      minutes(f, tick), why))
  end
  return mine, smelt
end

---------------------------------------------------------------------------------------------------
-- Interface distante de LECTURE (bancs) : fo-mains.status(clé d'équipe)
---------------------------------------------------------------------------------------------------
local function team_of(key)
  if key == "player" then return State.faction("player") end
  local war = State.war()
  for _, id in ipairs(State.sorted_keys(war and war.factions)) do
    local f = war.factions[id]
    if f.key == key then return f end
  end
  return nil
end

remote.add_interface("fo-mains", {
  --- { acc = texte des étiquettes, why = matières couvertes, flow = { [produit] = { rate, n } }, open = { « genre:détail » = n }
  --- (tâches de FOND libres, non prises, qui minent ou fondent), rows = { étiquette = { ok, ko, secs, units } } }
  status = function(key)
    local f = team_of(key)
    if not (f and f.team) then return nil end
    local st = f.team.mains
    if not st then return nil end
    local out = { acc = Mains.format(st.acc), why = st.why, flow = {}, open = {}, rows = {} }
    for _, p in ipairs(Mains.sorted_keys(st.flow)) do
      local rate, n = Mains.auto_flow(st.flow[p].ring)
      out.flow[p] = { rate = rate, n = n }
    end
    for _, lab in ipairs(Mains.sorted_keys(st.acc)) do out.rows[lab] = st.acc[lab] end
    local board = f.team.board
    for _, tk in ipairs(board and board.list or {}) do
      if tk.fond and not tk.worker and (tk.kind == "mine" or tk.kind == "smelt") then
        local lab = Mains.label(tk)
        out.open[lab] = (out.open[lab] or 0) + 1
      end
    end
    return out
  end,
})

return M
