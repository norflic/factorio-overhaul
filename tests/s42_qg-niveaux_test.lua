--[[
  Lot S42 QG-NIVEAUX (chantier 2.3 du DC, partie du 13/11 : centre resté au niveau 1 chez 3 factions sur 4 et dans votre équipe).
  Test hors jeu de la règle pure (shared/ai3/capital.lua) sur les données réelles des niveaux (shared/levels/config.lua).

    §1 chaîne du centre DEVANT (ctx.lead) : en mode blocs, avec un bloc de production payable au stock, le bâtiment de la famille qui
       bloque le centre (Q16) est le but ; sans ctx.lead (comportement d'avant), il ne l'est pas ;
    §2 borne : la clé rangée dans lead.done retombe à son rang ordinaire ; Cap.lead_step (début, cumul, borne, cible changée) ;
    §3 un bâtiment refusé par l'exécutant (ctx.exclude) cède la chaîne à un autre de sa famille ;
    §4 centre payable dont tout le coût dort au stock (ctx.cash) : il est le but, servi comme un travail court ; coût incomplet : non ;
    §5 déterminisme (relevé inversé).
  Usage : lua5.2 tests/s42_qg-niveaux_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local L = require("shared.levels.config")
local Cap = require("shared.ai3.capital")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    print("[S42-QG-NIVEAUX] ECHEC : " .. msg)
  end
  return cond
end

-- Prototypes simulés des niveaux, calculés comme l'étape data (même montage que tests/capital_test.lua).
local BASE = {
  gun = { role = "militaire", health = 400, dmg = 1, cooldown = 10 },
  laser = { role = "militaire", health = 1000, dmg = 1, cooldown = 40 },
  wall = { role = "militaire", health = 350 },
  drill = { role = "foreuse", health = 300, speed = 0.5 },
  furnace = { role = "fabrique", health = 300, speed = 2 },
  assembler = { role = "fabrique", health = 350, speed = 0.75 },
}
local CC = Cap.center_family(L)
local cache = {}
for _, fam in ipairs(L.families) do
  for n = 1, fam.max do
    local name = L.name(fam, n)
    if fam == CC then
      cache[name] = { role = "logistique", health = 3000, item = name }
    else
      local b = BASE[fam.key]
      local p = { role = b.role, item = name }
      for _, st in ipairs(fam.stats) do
        local leaf = st.path[#st.path]
        if leaf == "max_health" then p.health = L.apply_stat(st, b.health, n) end
        if leaf == "damage_modifier" then p.dmg = L.apply_stat(st, b.dmg, n) end
        if leaf == "crafting_speed" or leaf == "mining_speed" then p.speed = L.apply_stat(st, b.speed, n) end
      end
      p.health = p.health or b.health
      p.speed = p.speed or b.speed
      if b.cooldown then p.dps = (p.dmg or 1) / b.cooldown end
      cache[name] = p
    end
  end
end
local function proto(name) return cache[name] end
local function unit_cost() return 3 end -- tout objet s'obtient (coût unitaire égal : seul l'ordre compte ici)

local GUN, DRILL, FURN = L.by_key.gun, L.by_key.drill, L.by_key.furnace
local function ents(fam, levels, start_id, block, working)
  local out = {}
  for i, n in ipairs(levels) do
    out[#out + 1] = { id = start_id + i, name = L.name(fam, n), working = working or false, block = block or "qg" }
  end
  return out
end
local function join(...)
  local out = {}
  for _, l in ipairs({ ... }) do for _, e in ipairs(l) do out[#out + 1] = e end end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end
local function ctx(over)
  local c = { proto = proto, unit_cost = unit_cost, stock = {}, weights = {}, tick = 0 }
  for k, v in pairs(over or {}) do c[k] = v end
  return c
end
local function stock_for(...)
  local s = {}
  for _, cost in ipairs({ ... }) do
    for _, it in ipairs(cost) do s[it[1]] = (s[it[1]] or 0) + it[2] * 40 end
  end
  return s
end
local center1 = { id = 1, name = L.name(CC, 1) }

-- §1 Tourelles au niveau exigé, foreuses au niveau exigé pour l'une et bloc de foreuses payable au stock, fours au niveau 1 : le
-- centre est bloqué par les fours ; le stock ne contient PAS le coût du four (il faut le fabriquer).
local furn_cost = L.cost(FURN, 2)
local drill_stock = stock_for(L.cost(DRILL, 2), L.cost(DRILL, 3))
for _, it in ipairs(furn_cost) do drill_stock[it[1]] = nil end
local function list1()
  return join(ents(GUN, { 2, 2 }, 100), ents(DRILL, { 2, 1, 1, 1 }, 200, "p7", true), ents(FURN, { 1, 1 }, 300, "p9", true))
end
local furn_key = FURN.key .. ":2:301"
do
  local before = Cap.choose(L, { list = list1(), center = center1 }, ctx({ blocs = true, stock = drill_stock }))
  local blocked_cc = false
  for _, b in ipairs(before.blocked) do if b.center then blocked_cc = true end end
  check(blocked_cc, "§1 montage : le centre est bloqué par la condition Q16")
  check(before.key ~= furn_key, "§1 témoin (sans ctx.lead) : le four de la chaîne n'est pas le but (" .. tostring(before.key) .. ")")
  local d = Cap.choose(L, { list = list1(), center = center1 }, ctx({ blocs = true, stock = drill_stock, lead = { done = {} } }))
  check(d.key == furn_key, "§1 chaîne devant : le four qui bloque le centre est le but (" .. tostring(d.key) .. ")")
  check(d.chain ~= nil and d.lead == true and d.all_in == false, "§1 le but porte la chaîne, il est devant, son coût n'est pas au stock")
  local g = Cap.goal(d, {})
  check(g and g.opens == true and g.target == furn_key, "§1 le but au cerveau ouvre le centre (g.opens : coût demandé à la fabrication)")
  local n_cost = 0
  for i, it in ipairs(g.cost) do
    n_cost = n_cost + 1
    check(it[1] == furn_cost[i][1] and it[2] == furn_cost[i][2], "§1 coût du but = L.cost du niveau suivant (objet " .. i .. ")")
  end
  check(n_cost == #furn_cost and n_cost > 0, "§1 coût complet")
end

-- §2 Borne.
do
  local d = Cap.choose(L, { list = list1(), center = center1 },
    ctx({ blocs = true, stock = drill_stock, lead = { done = { [furn_key] = true } } }))
  check(d.key ~= furn_key and not d.lead, "§2 borne atteinte : le four retombe à son rang ordinaire (" .. tostring(d.key) .. ")")
  local gate = "c:2:1"
  local st, ev = Cap.lead_step(nil, { key = "a", chain = {}, lead = true }, gate, 100)
  check(ev == "debut" and st.gate == gate and st.spent.a == 0 and st.key == "a", "§2 pas 1 : début")
  st, ev = Cap.lead_step(st, { key = "a", chain = {}, lead = true }, gate, 100 + Cap.LEAD_TICKS - 1)
  check(ev == nil and st.spent.a == Cap.LEAD_TICKS - 1 and not st.done.a, "§2 pas 2 : cumul sous la borne")
  st, ev = Cap.lead_step(st, { key = "b" }, gate, 100 + Cap.LEAD_TICKS + 500)
  check(ev == nil and st.key == nil and st.spent.a == Cap.LEAD_TICKS - 1, "§2 autre but : le compte ne court pas")
  st, ev = Cap.lead_step(st, { key = "a", chain = {}, lead = true }, gate, 100 + Cap.LEAD_TICKS + 900)
  check(ev == nil and st.spent.a == Cap.LEAD_TICKS - 1, "§2 reprise : l'intervalle hors but n'est pas compté")
  st, ev = Cap.lead_step(st, { key = "a", chain = {}, lead = true }, gate, 100 + Cap.LEAD_TICKS + 901)
  check(ev == "borne" and st.done.a == true and st.key == nil, "§2 borne : la clé est rangée, sans réarmement")
  st, ev = Cap.lead_step(st, { key = "a", chain = {} }, gate, 100 + 2 * Cap.LEAD_TICKS)
  check(ev == nil and st.done.a == true, "§2 après la borne : plus d'événement")
  st, ev = Cap.lead_step(st, { key = "a", chain = {}, lead = true }, "c:3:9", 5)
  check(ev == "debut" and st.done.a == nil and st.gate == "c:3:9", "§2 cible du centre changée : l'état repart de zéro")
  local none = Cap.lead_step(st, { key = "a" }, nil, 6)
  check(none == nil, "§2 sans centre visé : aucun état")
end

-- §3 Refus récent du bâtiment de la chaîne : un autre four de la famille la porte.
do
  local d = Cap.choose(L, { list = list1(), center = center1 },
    ctx({ blocs = true, stock = drill_stock, lead = { done = {} }, exclude = { [furn_key] = true } }))
  check(d.key == FURN.key .. ":2:302", "§3 four refusé : l'autre four porte la chaîne (" .. tostring(d.key) .. ")")
end

-- §4 Centre payable (toutes les familles au niveau exigé) : coût entier au stock -> but, travail court.
do
  local list = join(ents(GUN, { 2, 2, 1, 1, 1, 1 }, 100), ents(DRILL, { 2, 1, 1 }, 200, "p7", true))
  local cc_cost = L.cost(CC, 2)
  local full = stock_for(cc_cost, L.cost(GUN, 2), L.cost(DRILL, 2))
  local key = CC.key .. ":2:1"
  local before = Cap.choose(L, { list = list, center = center1 }, ctx({ blocs = true, stock = full }))
  check(before.key ~= key, "§4 témoin (sans ctx.cash) : le centre attend la règle des reports (" .. tostring(before.key) .. ")")
  local d = Cap.choose(L, { list = list, center = center1 }, ctx({ blocs = true, stock = full, cash = true, lead = { done = {} } }))
  check(d.key == key and d.center and d.cash == true and not d.starved, "§4 coût au stock : le centre est le but (" .. tostring(d.key) .. ")")
  local g = Cap.goal(d, {})
  check(g and g.short == true and g.center == true and not g.ahead, "§4 but servi comme un travail court, sans état collant")
  local part = {}
  for k, v in pairs(full) do part[k] = v end
  part[cc_cost[1][1]] = cc_cost[1][2] - 1
  local d2 = Cap.choose(L, { list = list, center = center1 }, ctx({ blocs = true, stock = part, cash = true, lead = { done = {} } }))
  check(d2.key ~= key and not d2.cash, "§4 un objet manque au stock : le centre n'est pas le but par cette règle (" .. tostring(d2.key) .. ")")
  -- Centre bloqué par Q16 : jamais le but, même le coût au stock.
  local d3 = Cap.choose(L, { list = list1(), center = center1 }, ctx({ blocs = true, stock = full, cash = true, lead = { done = {} } }))
  check(not d3.center and not d3.cash, "§4 centre bloqué par la condition : la règle ne s'applique pas")
end

-- §5 Déterminisme : relevé inversé, même décision.
do
  local a = Cap.choose(L, { list = list1(), center = center1 }, ctx({ blocs = true, stock = drill_stock, lead = { done = {} }, cash = true }))
  local rev = {}
  for _, e in ipairs(list1()) do table.insert(rev, 1, e) end
  local b = Cap.choose(L, { list = rev, center = center1 }, ctx({ blocs = true, stock = drill_stock, lead = { done = {} }, cash = true }))
  check(a.key == b.key and a.score == b.score, "§5 relevé inversé : même but (" .. tostring(a.key) .. " / " .. tostring(b.key) .. ")")
end

print(string.format("[S42-QG-NIVEAUX] %d OK, %d ECHEC", pass, fail))
if fail > 0 then os.exit(1) end
