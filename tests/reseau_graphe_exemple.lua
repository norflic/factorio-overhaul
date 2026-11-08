--[[
  Lot RESEAU-GRAPHE : instances du banc tests/reseau_graphe_test.lua (hors du source de la règle : celui-ci ne nomme aucun objet).

  Ex.instance : base du joueur à 256 min, ordres de grandeur LUS dans les journaux de la sauvegarde du DC (fo-logs\2026-11-08_MESURE-DC) :
    - [FO-IA3E] player minute 256 : débit livré au QG par la fenêtre de 10 min, plaques de fer 358/min, plaques de cuivre 33/min, engrenages
      126/min, tapis 21/min ; [FO-LIAISON] azure : un quai type d'engrenages à 1,5 objet/s, à 54 tuiles du QG, sa sortie à 33 tuiles ;
    - [FO-LIAISON] player : 33 à 50 quais d'entrée, 51 à 65 coffres de sortie, 0 paire possible, 1 quai servi par tapis.
  Les POSITIONS (multiples de 28 : le pas du treillis) et la répartition des débits entre quais sont ILLUSTRATIVES (le journal ne les donne
  pas) : fonderies à 100 tuiles et plus du QG (gisements), modules dans les deux premières couronnes.
]]
local Li = require("shared.team.liaison")
local Rg = require("shared.team.reseau_graphe")

local Ex = {}

local function p(key, item, x, y, rate) return { key = key, item = item, x = x, y = y, rate = rate } end

--- Producteurs et consommateurs (objets/min).
function Ex.instance(extra)
  local inp = {
    hub = { x = 0, y = 0 },
    k = 2,
    producers = {
      p("fer-ouest:o1", "fer", -112, -56, 120), p("fer-ouest:o2", "fer", -112, -28, 120),
      p("fer-est:o1", "fer", 112, -84, 120), p("fer-est:o2", "fer", 112, -56, 120),
      p("cuivre-sud:o1", "cuivre", -28, 112, 40), p("cuivre-sud:o2", "cuivre", 0, 112, 40),
      p("engr:o1", "engr", 28, -56, 90),
    },
    consumers = {
      p("engr:q1", "fer", 28, -28, 180), p("tapis:q1", "fer", 56, 0, 20), p("sci:q1", "fer", 84, 28, 40),
      p("muni:q1", "fer", -28, 28, 30), p("circ:q1", "fer", -28, 56, 33),
      p("circ:q2", "cuivre", -28, 84, 50), p("sci:q2", "cuivre", 84, 84, 20),
      p("tapis:q2", "engr", 56, 28, 45), p("sci:q3", "engr", 84, 56, 45),
    },
  }
  for _, k in ipairs({ "k", "budget", "hub_share", "tmax" }) do
    if extra and extra[k] ~= nil then inp[k] = extra[k] end
  end
  return inp
end

local function pid_of(key) return key:match("^([^:]*)") end

--- Ce que fait la règle ACTUELLE (shared/team/liaison.lua : un quai, UN coffre de sortie du même objet à Li.MAX_SPAN tuiles au plus, un bras
--- de chaque côté) sur la même instance, comptée avec les mêmes trajets évités. Rend { pairs, gain_s_min, served }.
function Ex.current_rule(inp)
  local hs = inp.hub_share or Rg.HUB_SHARE
  local docks, srcs = {}, {}
  for _, c in ipairs(inp.consumers) do
    docks[#docks + 1] = { key = c.key, pid = pid_of(c.key), x = c.x, y = c.y, item = c.item, flow = c.rate / 60 }
  end
  for _, s in ipairs(inp.producers) do
    srcs[#srcs + 1] = { key = s.key, pid = pid_of(s.key), x = s.x, y = s.y, item = s.item }
  end
  local prs = Li.pairs(docks, srcs)
  local gain, served = 0, 0
  for _, pr in ipairs(prs) do
    local d, s = pr.dock, pr.src
    local rate = 0
    for _, c in ipairs(inp.consumers) do if c.key == d.key then rate = c.rate end end
    local sup = 0
    for _, q in ipairs(inp.producers) do if q.key == s.key then sup = q.rate * (1 - hs) end end
    local x = math.min(rate, sup, Rg.ARM_RATE)
    served = served + x
    gain = gain + x * (Rg.leg(math.abs(d.x) + math.abs(d.y), Rg.FILL_BATCH) + Rg.leg(math.abs(s.x) + math.abs(s.y), Rg.COLLECT_BATCH))
  end
  return { pairs = #prs, gain_s_min = gain, served = served }
end

--- Grosse instance déterministe : `n_items` objets, `n_each` producteurs et `n_each` consommateurs (mesure de coût).
function Ex.big(n_items, n_each)
  local lcg = 4242
  local function rnd(n)
    lcg = (lcg * 1103515245 + 12345) % 2147483648
    return lcg % n
  end
  local P, C = {}, {}
  for i = 1, n_each do
    local item = "o" .. string.format("%02d", i % n_items)
    P[#P + 1] = p("p" .. string.format("%03d", i), item, rnd(600) - 300, rnd(600) - 300, 40 + rnd(160))
    C[#C + 1] = p("c" .. string.format("%03d", i), item, rnd(300) - 150, rnd(300) - 150, 20 + rnd(160))
  end
  return { producers = P, consumers = C, hub = { x = 0, y = 0 }, k = 4 }
end

return Ex
