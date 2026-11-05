--[[
  Lot EXPERIMENTAUX-PUISSANCE (5/11) : COÛT en Lua de « frapper tout dans la zone » (moteur simulé, hors jeu). Lua 5.2, depuis la racine :
      lua5.2 tests/echelle_cout.lua
  Une salve de zone se fait en trois temps, comme le fera script/robots/experimentaux_geants.lua :
    1. recherche des entités ennemies dans le rayon (ici : parcours d'une liste, comme tests/mock_engine.lua ; en jeu, la recherche du
       moteur, en C++, n'est PAS mesurée ici) et filtre (valide, PV, destructible) ;
    2. plan : tri par distance puis identifiant, plafond Ech.PLAFOND (shared/robots/echelle.lua) ;
    3. dégâts par tranches de Ech.TRANCHE entités par tick (en jeu, `damage` et les morts coûtent en C++ : NON mesuré ici).
  Ce banc borne la part Lua : il échoue si une tranche dépasse en moyenne 0,5 ms ou si le plan d'une salve dépasse 25 ms (jusqu'à 10 000
  entités dans 90 tuiles ; moyennes sur 20 salves, os.clock n'ayant qu'une milliseconde de résolution sous Windows). La part du moteur se mesure en jeu (banc à faire, garde levée).
]]

package.path = "./?.lua;" .. package.path
local Ech = require("shared.robots.echelle")

local seed = 12345
local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end

--- Monde simulé : n entités ennemies dans un disque de rayon r (plus des entités hors du disque, à écarter).
local function monde(n, r)
  local out = {}
  for i = 1, n do
    local a, d = rnd() * 6.2831853, math.sqrt(rnd()) * r * 1.2
    local e = { valid = true, destructible = true, health = 600 + (i % 7) * 100, unit_number = i }
    e.position = { x = d * math.cos(a), y = d * math.sin(a) }
    e.damage = function(self, amount) self.health = self.health - amount; if self.health <= 0 then self.valid = false end return amount end
    out[i] = e
  end
  return out
end

--- Recherche simulée (parcours linéaire, comme le moteur simulé) : entités valides du disque.
local function chercher(ents, c, r)
  local out = {}
  local r2 = r * r
  for i, e in ipairs(ents) do
    if e.valid and e.health and e.destructible then
      local dx, dy = e.position.x - c.x, e.position.y - c.y
      if dx * dx + dy * dy <= r2 then out[#out + 1] = { x = e.position.x, y = e.position.y, id = e.unit_number or (1e9 + i), e = e } end
    end
  end
  return out
end

local REP = 20 -- os.clock n'a qu'une milliseconde de résolution sous Windows : on répète et on divise

local function mesure(n, r, salve)
  local rech, tri, tranches, nt, dans, traitees = 0, 0, 0, 0, 0, 0
  for _ = 1, REP do
    local ents = monde(n, r)
    local c = { x = 0, y = 0 }
    local t0 = os.clock()
    local cands = chercher(ents, c, r)
    local t1 = os.clock()
    local plan = Ech.plan(cands, c)
    local t2 = os.clock()
    for k = 1, Ech.ticks(#plan) do
      local a, b = Ech.tranche(k, #plan)
      for i = a, b do
        local e = plan[i].e
        if e.valid then e:damage(salve) end
      end
    end
    local t3 = os.clock()
    rech, tri, tranches = rech + (t1 - t0), tri + (t2 - t1), tranches + (t3 - t2)
    nt, dans, traitees = nt + Ech.ticks(#plan), #cands, #plan
  end
  return { n = n, dans = dans, plan = traitees, recherche = rech / REP * 1000, tri = tri / REP * 1000, ticks = nt / REP,
           tranche = (nt > 0 and tranches / nt or 0) * 1000 }
end

local fail = 0
print(string.format("[ECHELLE-COUT] tranche %d entités par tick, plafond %d par salve, cadence de zone %d ticks ; moyennes sur %d salves",
  Ech.TRANCHE, Ech.PLAFOND, Ech.CADENCE_ZONE, REP))
print("[ECHELLE-COUT] entités | dans la zone | traitées | recherche simulée (ms/salve) | tri (ms/salve) | ticks | tranche (ms/tick)")
for _, n in ipairs({ 1000, 3000, 6000, 10000 }) do
  local w = mesure(n, 90, Ech.salve(15, "laser"))
  print(string.format("[ECHELLE-COUT] %d | %d | %d | %.2f | %.2f | %d | %.3f", w.n, w.dans, w.plan, w.recherche, w.tri, w.ticks, w.tranche))
  if w.tranche > 0.5 then fail = fail + 1; print("[ECHELLE-COUT] ECHEC tranche au-delà de 0,5 ms") end
  if w.tri + w.recherche > 25 then fail = fail + 1; print("[ECHELLE-COUT] ECHEC plan d'une salve au-delà de 25 ms") end
end
print(string.format("[ECHELLE-COUT] BILAN : %s", fail == 0 and "OK (part Lua bornée)" or (fail .. " ECHEC(S)")))
os.exit(fail == 0 and 0 or 1)
