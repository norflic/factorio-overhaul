--[[
  Lot DEPENSES2 (4/11) : runtime de shared/ai3/depenses.lua. Appelé par la capitalisation (script/ai3/capitalisation.lua, decide) une fois
  par cycle et par équipe (factions et votre équipe). État : f.team.depenses (nombres et tables ; créé au premier appel, rien à migrer).
  Interface (le budget est À CE LOT ; le périmètre le CONSOMME) :
    - f.team.depenses.defense_want = { [matière] = quantité } : demande de défense, écrite par le périmètre ;
    - Dep.defense(f, tick) -> { [matière] = quantité accordée } (table vide : rien ne dort, règle éteinte ou résultat périmé) ;
    - Dep.labs(f, tick) -> laboratoires de plus voulus par la recherche (script/ai3/cerveau.lua).
  Interrupteur : f.team.depenses.on = false. Journal : [FO-DEPENSES] <équipe> minute <m> | <cause>.
]]

local Dp = require("shared.ai3.depenses")
local Rsv = require("script.ai3.reserve")

local Dep = {}

Dep.FRESH = 3 * 3600

local function state_of(f)
  local t = f.team
  if type(t.depenses) ~= "table" then t.depenses = { on = true, st = Dp.new() } end
  if type(t.depenses.st) ~= "table" then t.depenses.st = Dp.new() end
  return t.depenses
end

local function fresh(f, tick)
  local d = f and f.team and f.team.depenses
  if type(d) ~= "table" or d.on == false or type(d.res) ~= "table" or not d.res_tick then return nil end
  if tick and tick - d.res_tick > Dep.FRESH then return nil end
  return d.res
end

--- products = { { key, def_only } } dans l'ordre (plaques des fonderies, puis matières brutes « défense seule »).
function Dep.think(f, cs, tick, products, minutes)
  if not (f and f.team) then return nil end
  local d = state_of(f)
  local rin = Rsv.input(f, tick)
  local flows = (cs and cs.flows) or {}
  local list = {}
  for _, p in ipairs(products or {}) do
    local k = p.key
    list[#list + 1] = { key = k, def_only = p.def_only, made = (flows[k] and flows[k].made) or 0,
      free = (rin and rin.free and rin.free[k]) or 0,
      missing = (rin == nil) or (((rin.missing and rin.missing[k]) or 0) > 0) }
  end
  local res
  d.st, res = Dp.step(d.st, { on = d.on ~= false, tick = tick, products = list, want = d.defense_want })
  d.res, d.res_tick = res, tick
  if d.on ~= false then
    log(string.format("[FO-DEPENSES] %s minute %d | %s", f.key or "?", math.floor((minutes or 0) + 0.5), res.why))
  end
  return res
end

--- Accordé à la défense, par matière (copie : le lecteur ne peut pas écrire l'état).
function Dep.defense(f, tick)
  local r = fresh(f, tick)
  local out = {}
  if r then
    local ks = {}
    for k in next, (r.defense or {}) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do out[k] = r.defense[k] end
  end
  return out
end

--- Laboratoires de plus voulus (0 : rien ne dort).
function Dep.labs(f, tick)
  local r = fresh(f, tick)
  return (r and r.labs) or 0
end

return Dep
