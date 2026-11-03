--[[
  Lot DEPENSES (3/11) : runtime de la règle pure shared/ai3/depenses.lua (le stock qui DORT déclenche des dépenses).
  Appelé par la capitalisation (script/ai3/capitalisation.lua, decide) une fois par cycle et par équipe : lit le stock libre HORS
  BESOIN évalué (script/ai3/reserve.lua), la production mesurée (cs.flows, statistiques de la force) et l'amélioration en cours
  (f.team.capital.current) ; garde l'état dans f.team.depenses (nombres, chaînes et tables : sauvegarde ; créé au premier appel,
  rien à migrer).
  Leviers lus par les autres modules :
    - Dep.mark (script/ai3/cerveau.lua) : le but « amélioration » de fond peut faire fabriquer ses intermédiaires sans bras libre
      (g.depense, lu par Cap.emit) ;
    - Dep.slots (script/ai3/capitalisation.lua, Capi.slots) : emplacements de chantier de plus (Em.slots, `bonus`) ;
    - Dep.defense (lecture seule, pour le périmètre) : plaques accordées à la défense, sur la demande écrite dans
      f.team.depenses.defense_want (au plus Dp.DEF_PCT % du stock qui dort ; sans demande : 0, la capacité prend le reste).
  Interrupteur : f.team.depenses.on = false (rien n'est offert ; les horloges sont oubliées au pas suivant).
]]

local Dp = require("shared.ai3.depenses")
local Rsv = require("script.ai3.reserve")

local Dep = {}

Dep.FRESH = 3 * 3600 -- ticks : un résultat plus vieux n'est plus appliqué (capitalisation arrêtée, équipe sans QG)

local function state_of(f)
  local t = f.team
  if type(t.depenses) ~= "table" then t.depenses = { on = true, st = Dp.new() } end
  return t.depenses
end

local function fresh(f, tick)
  local d = f and f.team and f.team.depenses
  if type(d) ~= "table" or d.on == false or not d.res or not d.res_tick then return nil end
  if tick and tick - d.res_tick > Dep.FRESH then return nil end
  return d.res
end

--- Un pas : products = liste ordonnée des produits des fonderies (chaînes) ; cs.flows = { [objet] = { made } } du cycle.
function Dep.think(f, cs, tick, products, minutes)
  if not (f and f.team) then return nil end
  local d = state_of(f)
  local rin = Rsv.input(f, tick)
  local flows = (cs and cs.flows) or {}
  local plate = {}
  for _, p in ipairs(products or {}) do plate[p] = true end
  local list = {}
  for _, p in ipairs(products or {}) do
    local free = (rin and rin.free and rin.free[p]) or 0
    -- Sans besoin évalué (réglage maître éteint, état périmé) : aucun excédent, la survie n'est pas jugée.
    local missing = (rin == nil) or ((rin.missing and (rin.missing[p] or 0)) or 0) > 0
    list[#list + 1] = { key = p, free = free, made = (flows[p] and flows[p].made) or 0, missing = missing }
  end
  local dem = {}
  local cur = f.team.capital and f.team.capital.current
  if cur and cur.cost then
    local plates = Dp.cost_plates(cur.cost, function(item) return plate[item] and 1 or 2 end)
    if cur.center then dem.centre = plates else dem.intermediaires = plates end
  end
  -- Défense : la demande du périmètre (f.team.depenses.defense_want, plaques, écrite par le lot qui gère le budget de défense),
  -- bornée à Dp.DEF_PCT % par la règle. Personne ne la demande (0) : rien n'est retenu pour elle, la capacité prend le reste
  -- (une offre que personne ne lit laisserait dormir 30 % du stock).
  dem.defense = math.max(0, tonumber(d.defense_want) or 0)
  local res
  d.st, res = Dp.step(d.st, { on = d.on ~= false, tick = tick, products = list, demands = dem })
  d.res, d.res_tick = res, tick
  if d.on ~= false then
    log(string.format("[FO-DEPENSES] %s minute %d | %s%s", f.key or "?", math.floor((minutes or 0) + 0.5), res.why,
      cur and (" | but '" .. tostring(cur.key) .. "'") or ""))
  end
  return res
end

--- Emplacements de chantier de plus (0 : règle éteinte ou rien ne dort).
function Dep.slots(f, tick)
  local r = fresh(f, tick)
  return (r and r.slots) or 0
end

--- Plaques offertes à la défense (lecture seule ; 0 : rien ne dort).
function Dep.defense(f, tick)
  local r = fresh(f, tick)
  return (r and r.defense) or 0
end

--- Marque le but « amélioration » de fond (bâtiment, pas le centre) : ses intermédiaires peuvent se fabriquer sans bras libre
--- quand le stock dort (Cap.emit lit g.depense). Rend le but.
function Dep.mark(f, goal)
  if type(goal) ~= "table" or goal.center then return goal end
  local r = fresh(f, game and game.tick or nil)
  -- L'excédent qui dort, par produit (prêté au stock virtuel par Cap.emit le temps du dépliage) ; nil : rien ne dort.
  local lent = nil
  if r and r.upgrade then
    lent = {}
    local ks = {}
    for k in next, (r.per or {}) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do lent[k] = math.floor(r.per[k]) end
  end
  goal.depense = lent
  return goal
end

return Dep
