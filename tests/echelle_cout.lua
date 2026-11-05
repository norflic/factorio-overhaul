--[[
  Lot EXPERIMENTAUX-PUISSANCE (5/11) : COÛT en Lua de « frapper tout dans la zone », EN MS PAR TICK AU PIRE (demande du lead, 21 h 40 :
  « Mesure au moteur simulé avec 1 000 à 10 000 entités : je veux les ms par tick au pire »). Hors jeu, Lua 5.2, depuis la racine :
      lua5.2 tests/echelle_cout.lua
  Une salve de zone se fait, comme dans script/robots/experimentaux_geants.lua, en ticks SÉPARÉS :
    tick 0      : UNE recherche d'entités du moteur (find_entities_filtered, C++) : aucune boucle Lua. Ici, une recherche simulée (parcours
                  d'une liste, comme tests/mock_engine.lua) est donnée pour mémoire, HORS du pire tick Lua ;
    ticks 1..m  : rangement par anneaux (Ech.poser), au plus Ech.LOT_RANGEMENT entités par tick ;
    ticks m+1.. : dégâts, au plus Ech.TRANCHE entités par tick, lues en parcourant les anneaux (Ech.suivants : aucune copie de la file) ;
                  en jeu, `damage` et les morts coûtent en C++ : NON mesuré ici.
  Pire tick Lua = max(un lot de rangement, une tranche). Chaque temps est une moyenne sur REP répétitions du MÊME
  travail (os.clock n'a qu'une milliseconde de résolution sous Windows).
  LIMITE : les entités simulées sont des tables Lua ; en jeu, lire valid, health, destructible et position passe par le pont C++ (4 lectures
  par entité rangée). Ce coût du pont et celui du moteur (recherche, dégâts, morts) se mesurent en jeu : banc xp-zone et analyze.py --spikes.
  Le banc échoue si le pire tick Lua dépasse 1 ms ou si une salve demande plus de Ech.CADENCE_ZONE ticks (deux salves d'un géant ne se
  chevauchent pas).
]]

package.path = "./?.lua;" .. package.path
local Ech = require("shared.robots.echelle")

local seed = 12345
local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end

--- Monde simulé : n entités ennemies dans un disque de rayon 1,2 r (une part hors de la zone, à écarter par la recherche).
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

--- Recherche simulée : les entités du disque (ce que rend find_entities_filtered{position, radius} en jeu).
local function chercher(ents, c, r)
  local out = {}
  local r2 = r * r
  for _, e in ipairs(ents) do
    local dx, dy = e.position.x - c.x, e.position.y - c.y
    if dx * dx + dy * dy <= r2 then out[#out + 1] = e end
  end
  return out
end

--- Un lot de rangement, comme zone_ranger : filtre, lecture de la position, Ech.poser.
local function ranger_lot(p, found, i, b)
  for k = i, b do
    local x = found[k]
    if x.valid and x.health and x.destructible then
      local q = x.position
      Ech.poser(p, q.x, q.y, x)
    end
  end
end

local REP = 20

local function mesure(n, r, salve)
  local ents = monde(n, r)
  local c = { x = 0, y = 0 }
  -- recherche simulée (pour mémoire)
  local t0 = os.clock()
  local found
  for _ = 1, REP do found = chercher(ents, c, r) end
  local rech = (os.clock() - t0) / REP
  local nf = #found
  local lots = math.max(1, math.ceil(nf / Ech.LOT_RANGEMENT))
  -- rangement : salve entière REP fois, divisée par le nombre de lots
  local p
  t0 = os.clock()
  for _ = 1, REP do
    p = Ech.nouveau_plan(c)
    local i = 1
    while i <= nf do
      local b = math.min(nf, i + Ech.LOT_RANGEMENT - 1)
      ranger_lot(p, found, i, b)
      i = b + 1
    end
  end
  local lot = (os.clock() - t0) / REP / lots
  local nl = math.min(nf, Ech.PLAFOND)
  local nt = Ech.ticks(nl)
  -- tranches de dégâts : REP salves sur des mondes neufs, temps par tranche
  local ttr = 0
  for _ = 1, REP do
    local w = monde(n, r)
    local f = chercher(w, c, r)
    local q = Ech.nouveau_plan(c)
    ranger_lot(q, f, 1, #f)
    local cur = Ech.curseur()
    local t1 = os.clock()
    local nb = 0
    repeat
      local l, fini = Ech.suivants(q, cur, Ech.TRANCHE)
      nb = nb + 1
      for _, e in ipairs(l) do
        if e.valid then e:damage(salve) end
      end
    until fini
    ttr = ttr + (os.clock() - t1) / nb
  end
  local tranche = ttr / REP
  local pire = math.max(lot, tranche)
  return { n = n, dans = nf, plan = nl, recherche = rech * 1000, lots = lots, lot = lot * 1000,
           tranches = nt, tranche = tranche * 1000, pire = pire * 1000, ticks = 1 + lots + nt }
end

local fail = 0
print(string.format("[ECHELLE-COUT] rangement %d entités par tick, tranche %d coups par tick, plafond %d par salve, cadence de zone %d ticks ;"
  .. " moyennes sur %d répétitions", Ech.LOT_RANGEMENT, Ech.TRANCHE, Ech.PLAFOND, Ech.CADENCE_ZONE, REP))
print("[ECHELLE-COUT] entités | dans la zone | frappées | recherche simulée ms (moteur en jeu) | lots | ms/lot | tranches"
  .. " | ms/tranche | PIRE TICK LUA ms | ticks par salve")
for _, n in ipairs({ 1000, 2000, 3000, 6000, 10000 }) do
  local w = mesure(n, 90, Ech.salve(15, "laser"))
  print(string.format("[ECHELLE-COUT] %d | %d | %d | %.2f | %d | %.3f | %d | %.3f | %.3f | %d", w.n, w.dans, w.plan, w.recherche,
    w.lots, w.lot, w.tranches, w.tranche, w.pire, w.ticks))
  if w.pire > 1 then fail = fail + 1; print("[ECHELLE-COUT] ECHEC pire tick Lua au-delà de 1 ms") end
  if w.ticks > Ech.CADENCE_ZONE then fail = fail + 1; print("[ECHELLE-COUT] ECHEC une salve dure plus que la cadence de zone") end
end
print(string.format("[ECHELLE-COUT] BILAN : %s", fail == 0 and "OK (pire tick Lua borné ; pont C++ et moteur : banc xp-zone en jeu)"
  or (fail .. " ECHEC(S)")))
os.exit(fail == 0 and 0 or 1)
