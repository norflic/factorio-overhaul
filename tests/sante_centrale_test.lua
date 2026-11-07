--[[
  Tests hors jeu du lot ENERGIE (centrale résiliente, retour du DC du 2/11 sur la 0.6.34, points 5 et 11).
  1. Règles pures (shared/team/sante_centrale.lua) : classement des causes, amorce à la main, reconstruction sans progrès, centrale de plus
     avant la saturation, porte des consommateurs, journal ; et mutants.
  2. Le VRAI script/team/sante_centrale.lua (relevé, tâche d'amorce, exécution, porte, croissance) avec un moteur de bouchons.
  3. La croissance (shared/team/centrale.lua) avec `anticipate`.
  4. Chaîne statique : PA.watch -> Sante.observe / Sante.growth -> C.growth ; quai_tasks -> Sante.tasks ; Build.work -> Sante.work ;
     advance -> Sante.gate ; worker.lua : le programme du mode « amorce » prend le charbon au coffre.
  Usage, depuis la racine du mod :   lua5.2 tests/sante_centrale_test.lua
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
end
local function section(name) if not quiet then print("== " .. name) end end

local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
local function has(list, x) for _, v in ipairs(list) do if v == x then return true end end return false end

---------------------------------------------------------------------------------------------------
-- 1. Règles pures
---------------------------------------------------------------------------------------------------
local function battery(S)
  section("1a. Classement des causes")
  local healthy = { boilers = { want = 2, alive = 2, dry = 0 }, arms = { want = 4, alive = 4 }, belts = { want = 8, alive = 8 },
    engines = { want = 4, alive = 4 }, pumps = { want = 1, alive = 1 }, chest = { n = 400, low = 60 } }
  local r = S.classify(healthy)
  check(r.ok and #r.causes == 0 and not r.repair and r.dry == 0, "centrale saine : aucune cause")
  local c = copy(healthy); c.boilers = { want = 2, alive = 2, dry = 1 }
  r = S.classify(c)
  check(not r.ok and r.causes[1] == "chaudiere_a_sec" and r.dry == 1 and not r.repair, "une chaudiere a sec : cause, pas de piece a refaire")
  c = copy(healthy); c.arms = { want = 4, alive = 0 }
  r = S.classify(c)
  check(has(r.causes, "bras_manquants") and r.repair, "bras detruits : cause, reparation a presser")
  c = copy(healthy); c.belts = { want = 8, alive = 5 }
  r = S.classify(c)
  check(has(r.causes, "tapis_manquant") and r.repair, "tapis coupe : cause")
  c = copy(healthy); c.boilers = { want = 2, alive = 1, dry = 1 }; c.engines = { want = 4, alive = 1 }; c.pumps = { want = 1, alive = 0 }
  r = S.classify(c)
  check(r.causes[1] == "chaudiere_a_sec" and r.causes[2] == "chaudiere_detruite" and r.causes[3] == "machines_manquantes" and r.causes[4] == "pompe_manquante",
    "plusieurs causes : de la plus grave a la moins grave")
  c = copy(healthy); c.chest = { n = 10, low = 60 }
  r = S.classify(c)
  check(has(r.causes, "coffre_vide") and not r.repair, "coffre de secours vide : cause sans piece manquante")
  c = copy(healthy); c.chest = nil
  check(S.classify(c).ok, "sans coffre (centrale nourrie par foreuses) : pas de cause de coffre")
  c = copy(healthy); c.arms = { want = 4, alive = 7 }
  check(S.classify(c).ok, "plus de pieces que prevu : jamais une cause")

  section("1b. Chaudieres a sec confirmees")
  local st = {}
  check(not S.confirm(st, 1) and not S.confirm(st, 1) and S.confirm(st, 1), "3 releves de suite : confirme au troisieme")
  check(not S.confirm(st, 0) and st.dry_n == 0, "une chaudiere nourrie remet le compte a zero")
  check(not S.confirm(st, 1) and not S.confirm(st, 1), "il faut de nouveau 3 releves")
  check(S.DRY_CHECKS == 3, "S.DRY_CHECKS = 3 (15 s)")

  section("1c. Amorce a la main")
  local pr = S.prime({}, 1, 5000, 1000)
  check(pr and pr.count == 50 and pr.boilers == 1 and pr.total == 50, "1 chaudiere, beaucoup de stock : 50 charbons")
  pr = S.prime({}, 3, 5000, 1000)
  check(pr and pr.count == 50 and pr.boilers == 3 and pr.total == 150, "3 chaudieres a sec : 50 chacune")
  pr = S.prime({}, 3, 90, 1000)
  check(pr and pr.count == 30 and pr.boilers == 3 and pr.total == 90, "stock de 90 pour 3 chaudieres : 30 chacune")
  pr = S.prime({}, 3, 25, 1000)
  check(pr and pr.count == S.PRIME_MIN and pr.boilers == 2 and pr.total == 20, "stock de 25 pour 3 : 10 chacune pour 2 chaudieres")
  local why
  pr, why = S.prime({}, 2, 5, 1000)
  check(pr == nil and why == "stock de combustible insuffisant", "stock de 5 : pas d'amorce, cause rendue")
  pr, why = S.prime({}, 0, 5000, 1000)
  check(pr == nil and why == "aucune chaudiere a sec", "aucune chaudiere a sec : rien")
  local m = { primed = 1000 }
  pr, why = S.prime(m, 1, 5000, 1000 + S.COOL - 1)
  check(pr == nil and why == "amorce recente", "juste apres une amorce : pas de seconde")
  pr, why = S.prime(m, 1, 5000, 1100)
  check(pr == nil and why == "amorce recente", "100 ticks apres : toujours pas")
  pr = S.prime(m, 1, 5000, 1000 + S.COOL)
  check(pr ~= nil, "S.COOL ticks apres : de nouveau")
  check(S.COOL == 5400, "90 s entre deux amorces")
  check(S.PRIME == 50, "le jet de 50 charbons du DC")
  check(S.PRIO > 91 and S.PRIO == 92, "priorite au-dessus de l'urgence du coffre (91)")

  section("1d. Reconstruction sans progres")
  local sm = {}
  check(not S.stalled(sm, 17, 15, 0), "premier relevé : jamais bloque")
  check(not S.stalled(sm, 17, 15, 17999), "presque 5 min sans progres : pas encore")
  check(S.stalled(sm, 17, 15, 18000), "5 min sans piece reposee : bloquee")
  check(not S.stalled(sm, 17, 16, 18010) and not S.stalled(sm, 17, 16, 18020), "une piece reposee : le compte repart")
  check(S.stalled(sm, 17, 16, 18010 + 18000), "et se rebloque 5 min plus tard")
  check(not S.stalled(sm, 99, 3, 18005), "une autre centrale a sa propre mesure")

  section("1e. Centrale de plus avant la saturation")
  check(not S.anticipate(1000, 0, 0) and not S.anticipate(1000, 0, nil), "sans capacite : jamais")
  check(not S.anticipate(1200, 0, 1800), "66 % : pas encore")
  check(S.anticipate(1260, 0, 1800), "70 % : oui")
  check(S.anticipate(600, 1300, 1800), "production + chantiers en cours (a 60 % de leur puissance nominale) : 76 %")
  check(not S.anticipate(600, 700, 1800), "600 + 60 % de 700 = 56 % : pas encore")
  check(S.DRAW == 0.6, "un module en chantier tire 60 % de sa puissance nominale")
  check(not S.anticipate(0, 0, 1800), "rien : non")
  check(S.ANTICIPATE < 0.8, "avant le seuil de saturation (80 %)")

  section("1e bis. Duree de l'avance")
  local sa = {}
  for i = 1, 5 do check(S.sustain(sa, true) == false, "avance relevé " .. i .. " sur 6 : pas encore") end
  check(S.sustain(sa, true) == true, "6 releves de suite : l'avance est tenue")
  check(S.sustain(sa, false) == false and sa.ant_n == 0, "un releve sous le seuil remet le compte a zero")
  for i = 1, 5 do S.sustain(sa, true) end
  check(S.sustain(sa, false) == false and S.sustain(sa, true) == false, "5 releves puis une rechute : il faut de nouveau 6 releves")
  check(S.ANTICIPATE_CHECKS == 6, "30 s comme la saturation")

  section("1e ter. kW retenus par la capitalisation (etape 5a de VIDEO-INTEG)")
  check(S.capi_kw({ kw = 500, tick = 1000 }, 1000) == 500 and S.capi_kw({ kw = 500, tick = 1000 }, 1000 + S.CAPI_TTL) == 500,
    "retenus a la decision et jusqu'a S.CAPI_TTL : comptes")
  check(S.capi_kw({ kw = 500, tick = 1000 }, 1001 + S.CAPI_TTL) == 0, "plus vieux que S.CAPI_TTL : oublies")
  check(S.capi_kw(nil, 1000) == 0 and S.capi_kw({ kw = 500 }, 1000) == 0 and S.capi_kw({ kw = 0 / 0, tick = 1000 }, 1000) == 0
    and S.capi_kw({ kw = -5, tick = 1000 }, 1000) == 0 and S.capi_kw({ kw = 500, tick = 2000 }, 1000) == 0 and S.capi_kw({ kw = 500, tick = 1000 }, nil) == 0,
    "absent, sans date, invalide, negatif, date du futur, tick absent : 0")
  check(S.CAPI_TTL == 2 * 3600, "valables deux decisions de la capitalisation (une par minute)")
  check(S.anticipate(700, S.capi_kw({ kw = 1000, tick = 0 }, 0), 1800) and not S.anticipate(700, S.capi_kw({ kw = 1000, tick = 0 }, 1 + S.CAPI_TTL), 1800),
    "700 kW + 60 % de 1000 kW retenus par la capitalisation = 72 % : avance ; retenus perimes : 39 %, pas d'avance")

  section("1f. Porte des consommateurs")
  local g = {}
  local ok, w = S.admit(g, { capacity = 1800, used = 0, committed = 0 }, 700, 0)
  check(ok and w == nil, "marge large : admis")
  ok, w = S.admit(g, { capacity = 1800, used = 1000, committed = 0 }, 1100, 100)
  check(ok, "1000 + 60 % de 1100 = 1660 <= 1800 : admis")
  ok, w = S.admit(g, { capacity = 1800, used = 1200, committed = 0 }, 1100, 100)
  check(not ok and w and w:find("courant", 1, true), "1200 + 60 % de 1100 = 1860 > 1800 : retenu, raison « courant »")
  check(g.since == 100, "l'attente commence au premier refus")
  ok = S.admit(g, { capacity = 1800, used = 1200, committed = 0 }, 1100, 100 + 43199)
  check(not ok, "presque 12 min : toujours retenu")
  ok, w = S.admit(g, { capacity = 1800, used = 1200, committed = 0 }, 1100, 100 + 43200)
  check(ok and w == "delai", "12 min : passe quand meme (jamais de blocage definitif)")
  g = {}
  ok = S.admit(g, { capacity = 1800, used = 600, committed = 1500 }, 1000, 0)
  check(not ok, "les consommateurs en chantier comptent : 600 + 60 % de 2500 = 2100 > 1800")
  ok = S.admit(g, { capacity = 1800, used = 600, committed = 400 }, 1000, 0)
  check(ok and g.since == nil, "marge retrouvee : admis, l'attente est effacee")
  ok = S.admit({}, { capacity = 0, used = 0, committed = 0 }, 700, 0)
  check(ok, "aucune centrale finie (capacite nulle) : la porte est ouverte (la centrale precede)")
  ok = S.admit({}, { capacity = 1800, used = 1800, committed = 0 }, 0, 0)
  check(ok, "module sans puissance : admis")
  ok = S.admit({}, { capacity = 1800, used = 1200, committed = 0 }, 1000, 0)
  check(ok, "exactement a la capacite (1200 + 600) : admis")

  section("1g. Journal")
  local l = S.line({ kind = "etat", team = "azure", plant = 17, tick = 3600 * 150, causes = { "chaudiere_a_sec", "bras_manquants" },
    boilers_alive = 1, boilers_want = 2, dry = 1, arms_alive = 0, arms_want = 4, belts_alive = 8, belts_want = 8, engines_alive = 2,
    engines_want = 4, pumps_alive = 1, pumps_want = 1, production = 0, capacity = 1800 })
  check(l:find("^%[FO%-SANTE%-CENTRALE%] azure : centrale 17 a 150.0 min : chaudiere_a_sec %+ bras_manquants") ~= nil, "ligne d'etat : causes ordonnees")
  check(l:find("chaudieres 1/2 dont 1 a sec", 1, true) and l:find("bras 0/4", 1, true), "ligne d'etat : compteurs")
  check(S.line({ kind = "etat", team = "t", plant = 1, tick = 0, causes = {} }):find("saine", 1, true) ~= nil, "centrale saine")
  check(S.line({ kind = "amorce", team = "t", plant = 1, tick = 0, boilers = 2, count = 50, total = 100, stock = 900 }):find("amorce a la main", 1, true) ~= nil, "ligne d'amorce")
  check(S.line({ kind = "retenu", team = "t", project = 9, tick = 0, why = "courant" }):find("projet 9 retenu", 1, true) ~= nil, "ligne de porte")
  check(S.line({ kind = "avance", team = "t", tick = 0, used = 1, committed = 2, capacity = 3 }):find("AVANT la saturation", 1, true) ~= nil, "ligne d'avance")
  check(S.line({ kind = "bloquee", team = "t", plant = 1, tick = 0, waited = 18000, built = 3 }):find("sans progres depuis 300 s", 1, true) ~= nil, "ligne de reconstruction bloquee")
end

local S0 = dofile("shared/team/sante_centrale.lua")
battery(S0)

---------------------------------------------------------------------------------------------------
-- 2. Le vrai script/team/sante_centrale.lua, moteur de bouchons
---------------------------------------------------------------------------------------------------
section("2. Executant (moteur de bouchons)")
local LOG = {}
_G.log = function(s) LOG[#LOG + 1] = s end
_G.game = { tick = 0 }
local COAL = {}
package.loaded["script.team.stock"] = { count = function(f, item) return f.stock or 0 end }
local Sante = dofile("script/team/sante_centrale.lua")
local M = require("shared.team.modules")
local T = require("shared.team.config")
local S = S0

local function new_inv(count)
  local inv = { n = count or 0 }
  function inv.is_empty() return inv.n == 0 end
  function inv.get_item_count() return inv.n end
  function inv.insert(s) inv.n = inv.n + s.count; return s.count end
  function inv.remove(s) inv.n = inv.n - s.count; return s.count end
  return inv
end

local function world()
  local w = { ents = {} }
  function w.add(name, x, y, opts)
    opts = opts or {}
    local e = { valid = true, name = name, force = { name = "fo-azure" }, energy_generated_last_tick = opts.power or 0,
      burner = { remaining_burning_fuel = opts.flame or 0 }, inv = new_inv(opts.fuel or 0) }
    e.get_fuel_inventory = function() return e.inv end
    e.get_item_count = function() return opts.chest or 0 end
    w.ents[name .. "@" .. x .. "," .. y] = e
    return e
  end
  w.surface = {
    find_entity = function(name, pos) return w.ents[name .. "@" .. pos[1] .. "," .. pos[2]] end,
    find_entities_filtered = function(q)
      local out = {}
      for _, e in pairs(w.ents) do if e.is_chest then out[#out + 1] = e end end
      return out
    end,
  }
  return w
end

--- Une centrale de 2 chaudieres : 4 machines, 1 pompe, 4 bras, 6 tapis.
local function plant(w, opts)
  opts = opts or {}
  local p = { id = 17, state = "fini", ents = {}, quais = {} }
  local function put(name, x, y, alive, o, extra)
    local e = { name = name, x = x, y = y }
    if extra then for k, v in pairs(extra) do e[k] = v end end
    p.ents[#p.ents + 1] = e
    if alive then w.add(name, x, y, o) end
  end
  put("boiler", 1, 11, true, { fuel = opts.fuel1 or 0 })
  put("boiler", 4, 11, opts.boiler2 ~= false, { fuel = opts.fuel2 or 0 })
  for k = 0, 1 do
    put("steam-engine", 1 + 3 * k, 6, true, { power = 10 })
    put("steam-engine", 1 + 3 * k, 1, opts.engines_alive ~= false, { power = 10 })
  end
  put("offshore-pump", 0, 12, opts.pump ~= false)
  for k = 0, 3 do put(M.BURNER_ARM, k, 13, opts.arms ~= false) end
  for k = 0, 5 do put("transport-belt", k, 14, opts.belts ~= false) end
  return p
end

local f = { key = "azure", force = "fo-azure", stock = 800, build = { order = {}, projects = {}, grow = {} } }

-- 2a. centrale morte : bras et tapis detruits, 2 chaudieres a sec
local w = world()
local p = plant(w, { arms = false, belts = false })
local res
for i = 1, 3 do
  game.tick = 600 + 300 * i
  res = Sante.observe(f, w.surface, p, game.tick)
end
check(has(res.causes, "chaudiere_a_sec") and has(res.causes, "bras_manquants") and has(res.causes, "tapis_manquant"), "relevé : a sec + bras + tapis manquants")
check(res.c.boilers.want == 2 and res.c.boilers.alive == 2 and res.c.boilers.dry == 2, "2 chaudieres vivantes, 2 a sec")
check(res.c.arms.want == 4 and res.c.arms.alive == 0 and res.c.belts.want == 6 and res.c.belts.alive == 0, "bras 0/4, tapis 0/6")
check(res.c.engines.want == 4 and res.c.engines.alive == 4 and res.c.pumps.alive == 1, "machines et pompe comptees")
check(res.production == 40 * 60 / 1000 * 1 and res.capacity == 4 * 900, "production et capacite en kW (energie lue des machines vivantes)")
local sm = f.build.sante
check(sm.plants[17].prime and sm.plants[17].prime.total == 100 and sm.plants[17].prime.count == 50, "amorce decidee apres 3 releves : 2 x 50")
check(sm.dark > 0, "temps sans courant compte (toutes les chaudieres a sec)")
local said = table.concat(LOG, "\n")
check(said:find("amorce a la main", 1, true) and said:find("chaudiere_a_sec + chaudiere_detruite" , 1, true) == nil, "journal : l'amorce est ecrite")
check(said:find("bras_manquants", 1, true) ~= nil, "journal : l'etat de la centrale est ecrit")

local out = {}
Sante.tasks(f, p, out, function(x, y) return { x = x + 1, y = y + 1 } end)
check(#out == 1 and out[1].prio == S.PRIO and out[1].kind == "carry" and out[1].ia1d.mode == "amorce", "tache d'amorce : carry, mode amorce, priorite S.PRIO")
check(out[1].items[1][1] == T.fuel and out[1].items[1][2] == 100, "la tache prend 100 charbons au coffre du QG")
check(out[1].ia1d.pid == 17 and out[1].ia1d.ax == 2 and out[1].ia1d.ay == 12 and out[1].key == "ia1d:17:amorce", "point d'appui pres de la chaudiere, cle stable")
check(out[1].no_rush == true, "pas d'anti-ruee (urgence comme le coffre)")

-- 2b. le PNJ arrive : il verse dans les chaudieres a sec
local inv = new_inv(100)
check(Sante.work(f, p, w.surface, inv, 9000) == "done", "Sante.work rend done")
check(w.ents["boiler@1,11"].inv.n == 50 and w.ents["boiler@4,11"].inv.n == 50 and inv.n == 0, "50 charbons dans chaque chaudiere, le PNJ n'en garde plus")
check(sm.plants[17].primed == 9000 and sm.plants[17].prime == nil, "amorce notee, tache effacee")
out = {}
Sante.tasks(f, p, out, function(x, y) return { x = x, y = y } end)
check(#out == 0, "plus de tache apres l'amorce")
inv = new_inv(100)
Sante.work(f, p, w.surface, inv, 9500)
check(inv.n == 100, "chaudieres deja alimentees : rien n'est verse")
check(table.concat(LOG, "\n"):find("amorce posee, 100 charbon(s) dans 2 chaudiere(s)", 1, true) ~= nil, "journal : amorce posee")

-- 2c. COOL : une chaudiere qui se revide juste apres n'est pas reamorcee tout de suite
w.ents["boiler@1,11"].inv.n = 0
w.ents["boiler@4,11"].inv.n = 0
for i = 1, 4 do game.tick = 9600 + 300 * i; res = Sante.observe(f, w.surface, p, game.tick) end
check(sm.plants[17].prime == nil, "S.COOL : pas d'amorce 90 s apres la precedente")
game.tick = 9000 + S.COOL + 300
res = Sante.observe(f, w.surface, p, game.tick)
check(sm.plants[17].prime ~= nil, "S.COOL passe : nouvelle amorce")

-- 2d. flamme : une chaudiere sans combustible mais qui brule encore n'est pas a sec
local w2 = world()
local p2 = plant(w2, { fuel1 = 0 })
w2.ents["boiler@1,11"].burner.remaining_burning_fuel = 1000
w2.ents["boiler@4,11"].inv.n = 3
local f2 = { key = "azure", force = "fo-azure", stock = 800, build = { order = {}, projects = {}, grow = {} } }
res = Sante.observe(f2, w2.surface, p2, 1000)
check(res.c.boilers.dry == 0 and not has(res.causes, "chaudiere_a_sec"), "flamme ou combustible : pas a sec")
check(f2.build.sante.dark == 0, "pas de temps sans courant")

-- 2e. stock insuffisant
local f3 = { key = "azure", force = "fo-azure", stock = 4, build = { order = {}, projects = {}, grow = {} } }
local w3 = world()
local p3 = plant(w3)
for i = 1, 3 do res = Sante.observe(f3, w3.surface, p3, 300 * i) end
check(f3.build.sante.plants[17].prime == nil, "stock de 4 charbons : pas de tache")
check(table.concat(LOG, "\n"):find("pas d'amorce (stock de combustible insuffisant)", 1, true) ~= nil, "journal : la cause du refus est dite")

-- 2f. chaudiere detruite : plus de cible a amorcer ; centrale a 1 chaudiere
local f4 = { key = "azure", force = "fo-azure", stock = 800, build = { order = {}, projects = {}, grow = {} } }
local w4 = world()
local p4 = plant(w4, { boiler2 = false })
for i = 1, 3 do res = Sante.observe(f4, w4.surface, p4, 300 * i) end
check(res.c.boilers.want == 2 and res.c.boilers.alive == 1 and has(res.causes, "chaudiere_detruite"), "chaudiere detruite : comptee")
check(f4.build.sante.plants[17].prime.total == 50, "amorce de la seule chaudiere vivante")
-- pieces abandonnees : non comptees
p4.ents[2].gave_up = true
res = Sante.observe(f4, w4.surface, p4, 3000)
check(res.c.boilers.want == 1, "piece abandonnee (gave_up) : plus attendue")

-- 2g. porte des consommateurs
section("2g. Porte")
local function gate_f(cap_j, power_j)
  return { key = "azure", force = "fo-azure", build = { order = {}, projects = {}, grow = { capacity = cap_j, power = power_j } } }
end
local kw_of = function(spec) return spec.kw end
local fg = gate_f(30000, 15000) -- 1800 kW, 900 kW produits
local pa = { id = 5, state = "attente", spec = { kw = 1000 } }
fg.build.projects[5] = pa; fg.build.order[1] = 5
check(Sante.gate(fg, pa, 1000, kw_of) == true and pa.admitted and pa.power_kw == 1000, "900 + 600 <= 1800 : admis, puissance notee")
pa.state = "plan"
local pb = { id = 6, state = "attente", spec = { kw = 1000 } }
fg.build.projects[6] = pb; fg.build.order[2] = 6
check(Sante.gate(fg, pb, 1010, kw_of) == false and pb.reason == "courant" and not pb.admitted, "900 + 600 (en chantier) + 600 > 1800 : retenu")
check(Sante.held(fg) == 1000, "le module retenu compte dans la demande")
do
  -- un projet admis dont le plan attend (retour a « attente ») reste un consommateur en chantier ; un projet rouvert, fini ou refuse, non
  local fc = gate_f(30000, 0)
  local function add(id, st, extra)
    local q = { id = id, state = st, admitted = true, power_kw = 500 }
    if extra then for k, v in pairs(extra) do q[k] = v end end
    fc.build.projects[id] = q; fc.build.order[#fc.build.order + 1] = id
  end
  add(1, "attente"); add(2, "plan"); add(3, "chantier"); add(4, "fini"); add(5, "refuse"); add(6, "bloque"); add(7, "bloque", { retry_at = 5 })
  add(8, "reserve", { reopened = 1 }); add(9, "chantier", { abandoned = true })
  fc.build.projects[10] = { id = 10, state = "attente", power_kw = 500 }; fc.build.order[#fc.build.order + 1] = 10 -- pas admis : compte comme retenu, pas ici
  check(Sante.committed(fc) == 4 * 500, "committed : attente/plan/chantier admis + bloque avec reprise = 4 x 500")
  check(Sante.committed(fc, 1) == 3 * 500, "committed sans le projet juge")
end
do
  -- lot COURANT2 (revue du 3/11, defaut 1) : une bande de champ (spec.site) n'a pas de gabarit ; sa puissance (somme des entites planifiees,
  -- 90 kW la foreuse electrique) compte pour la centrale des que ses fantomes se posent, pas avant (reserve : jusqu'a 90 min de matieres)
  local drills = {}
  for i = 1, 4 do drills[i] = { name = "electric-mining-drill", x = i * 3, y = 0 } end
  drills[5] = { name = "transport-belt", x = 0, y = 5 } -- un tapis ne consomme rien
  local ps = { id = 1, spec = { site = "champ" }, ents = drills }
  check(Sante.site_kw(ps) == 4 * 90, "site_kw : 4 foreuses electriques = 360 kW, le tapis 0")
  check(Sante.site_kw({ spec = { site = "champ" } }) == 0, "site_kw : projet sans entites = 0")
  for _, st in ipairs({ "attente", "plan", "reserve", "defrichage", "bloque", "fini", "refuse" }) do
    local fs = gate_f(30000, 0)
    fs.build.projects[1] = { id = 1, state = st, spec = { site = "champ" }, admitted = true, power_kw = 360 }; fs.build.order[1] = 1
    check(Sante.committed(fs) == 0, "site en '" .. st .. "' : ne pese pas encore sur la centrale")
  end
  for _, st in ipairs({ "fantomes", "chantier", "raccordement" }) do
    local fs = gate_f(30000, 0)
    fs.build.projects[1] = { id = 1, state = st, spec = { site = "champ" }, admitted = true, power_kw = 360 }; fs.build.order[1] = 1
    check(Sante.committed(fs) == 360, "site en '" .. st .. "' : 360 kW comptes")
    check(Sante.committed(fs, 1) == 0, "site en '" .. st .. "' : sans le projet juge, 0")
  end
  -- un module ordinaire (sans spec.site) garde sa regle : « reserve » admis compte
  local fo = gate_f(30000, 0)
  fo.build.projects[2] = { id = 2, state = "reserve", spec = { kw = 500 }, admitted = true, power_kw = 500 }; fo.build.order[1] = 2
  check(Sante.committed(fo) == 500, "module ordinaire en reserve : toujours compte")
  -- chaine statique : build.lua note la puissance du site au plan, avant de quitter l'etat « plan »
  local fh = io.open("script/team/build.lua", "r"); local bsrc = fh:read("*a"); fh:close()
  check(bsrc:find("p.power_kw = Sante.site_kw(p)", 1, true) ~= nil, "build.lua : le plan d'un site note sa puissance")
end
check(table.concat(LOG, "\n"):find("projet 6 retenu", 1, true) ~= nil, "journal : retenu")
local n_logs = #LOG
Sante.gate(fg, pb, 1020, kw_of)
check(#LOG == n_logs, "une seule ligne par module retenu")
pa.state = "fini"
check(Sante.gate(fg, pb, 1030, kw_of) == true and pb.admitted and Sante.held(fg) == 0, "le premier fini et compte dans la production : libere ... ")
fg.build.grow.power = 29000
local pc = { id = 7, state = "attente", spec = { kw = 1000 } }
fg.build.projects[7] = pc; fg.build.order[3] = 7
check(Sante.gate(fg, pc, 2000, kw_of) == false, "centrale saturee : tout module est retenu")
check(Sante.gate(fg, pc, 2000 + S.GATE_WAIT, kw_of) == true, "apres 12 min il passe")
for _, spec in ipairs({ { alim = 1, kw = 9999 }, { raccord = true, kw = 9999 }, { enceinte = true, kw = 9999 }, { liaison = true, kw = 9999 },
  { site = "x", kw = 9999 } }) do
  local pp = { id = 30, state = "attente", spec = spec }
  check(Sante.gate(fg, pp, 3000, kw_of) == true, "jamais retenu : alim/raccord/enceinte/liaison/site")
end
fg.build.plant = 33
fg.build.extra_plants = { 34 }
check(Sante.gate(fg, { id = 33, state = "attente", spec = { kw = 9999 } }, 3000, kw_of) == true, "la premiere centrale n'est jamais retenue")
check(Sante.gate(fg, { id = 34, state = "attente", spec = { kw = 9999 } }, 3000, kw_of) == true, "une centrale de plus n'est jamais retenue")
fg.build.plant, fg.build.extra_plants = nil, nil
local pz = { id = 31, state = "attente", spec = { kw = 0 } }
check(Sante.gate(fg, pz, 3000, kw_of) == true, "module sans puissance : admis")
local pr2 = { id = 32, state = "attente", spec = { kw = 1000 }, reopened = 1 }
check(Sante.gate(fg, pr2, 3000, kw_of) == true, "projet rouvert (reconstruction) : jamais retenu")
local f0 = { key = "azure", force = "fo-azure", build = { order = {}, projects = {}, grow = nil } }
check(Sante.gate(f0, { id = 40, state = "attente", spec = { kw = 1000 } }, 0, kw_of) == true, "pas encore de releve de centrale : ouvert")
check(Sante.gate(gate_f(0, 0), { id = 41, state = "attente", spec = { kw = 1000 } }, 0, kw_of) == true, "aucune machine vivante (capacite 0) : ouvert (rien a juger)")

-- 2h. croissance
section("2h. Croissance")
local fgr = gate_f(30000, 0)
local fin = { id = 1, state = "fini", ents = {} }
local ant, stalled, used, comm, cap
for i = 1, 5 do ant, stalled, used, comm, cap = Sante.growth(fgr, 100, { fin }, 21000, 30000) end
check(ant == false and used == 1260 and cap == 1800 and #stalled == 0, "70 % de la capacite pendant 25 s : pas encore")
ant = Sante.growth(fgr, 100, { fin }, 21000, 30000)
check(ant == true, "70 % de la capacite pendant 30 s : avance")
ant = Sante.growth(fgr, 100, { fin }, 15000, 30000)
check(ant == false and fgr.build.sante.ant_n == 0, "50 % : pas d'avance, le compte repart")
fgr.build.sante.held = { [9] = 1000 }
for i = 1, 6 do ant, _, _, comm = Sante.growth(fgr, 100, { fin }, 15000, 30000) end
check(ant == true and comm == 1000, "50 % + un module retenu de 1000 kW (a 60 %) pendant 30 s : avance")
fgr.build.sante.held = {}
fgr.build.sante.ant_n = 0
-- étape 5a de VIDEO-INTEG : les kW que la capitalisation a retenus faute de courant comptent comme des modules retenus
fgr.team = { capi = { kw_blocked = { kw = 1000, tick = 100 } } }
for i = 1, 6 do ant, _, _, comm = Sante.growth(fgr, 100, { fin }, 15000, 30000) end
check(ant == true and comm == 1000, "50 % + 1000 kW retenus par la capitalisation (a 60 %) pendant 30 s : avance (" .. tostring(comm) .. ")")
ant, _, _, comm = Sante.growth(fgr, 101 + S.CAPI_TTL, { fin }, 15000, 30000)
check(ant == false and comm == 0, "kW retenus plus vieux que S.CAPI_TTL : oublies, pas d'avance (" .. tostring(comm) .. ")")
fgr.team = nil
fgr.build.sante.ant_n = 0
local reo ={ id = 17, state = "chantier", reopened = 1, ents = { { built = true }, { built = false }, { built = false } } }
ant, stalled = Sante.growth(fgr, 100, { fin, reo }, 0, 30000)
check(#stalled == 0, "reconstruction : premier releve, pas bloquee")
ant, stalled = Sante.growth(fgr, 100 + S.STALL, { fin, reo }, 0, 30000)
check(#stalled == 1 and stalled[1] == 17, "reconstruction sans progres depuis 5 min : bloquee")
check(table.concat(LOG, "\n"):find("reconstruction de la centrale 17 sans progres depuis 300 s", 1, true) ~= nil, "journal : reconstruction bloquee")
reo.ents[2].built = true
ant, stalled = Sante.growth(fgr, 100 + S.STALL + 5, { fin, reo }, 0, 30000)
check(#stalled == 0, "une piece reposee : libere")
ant, stalled = Sante.growth(fgr, 100 + S.STALL + 5, { fin, { id = 50, state = "chantier", ents = {} } }, 0, 30000)
check(#stalled == 0, "un chantier neuf (pas rouvert) n'est pas une reconstruction")

-- 2i. temoin des bancs : no_sante coupe l'amorce, la porte et l'avance
section("2i. Temoin no_sante")
do
  local fo = { key = "azure", force = "fo-azure", stock = 800, build = { order = {}, projects = {}, grow = { capacity = 30000, power = 29000 }, opts = { no_sante = true } } }
  local wo = world()
  local po = plant(wo, { arms = false })
  local r
  for i = 1, 4 do r = Sante.observe(fo, wo.surface, po, 300 * i) end
  check(r.c.boilers.dry == 2 and fo.build.sante.plants[17].prime == nil, "no_sante : les chaudieres a sec sont lues, aucune amorce")
  check(has(r.causes, "bras_manquants"), "no_sante : le releve et le journal restent")
  local pg = { id = 8, state = "attente", spec = { kw = 1000 } }
  check(Sante.gate(fo, pg, 0, kw_of) == true, "no_sante : la porte est ouverte meme centrale saturee")
  local ant, st2 = Sante.growth(fo, 0, { fin }, 29000, 30000)
  check(ant == false and #st2 == 0, "no_sante : pas d'avance, pas de reconstruction bloquee")
end

---------------------------------------------------------------------------------------------------
-- 3. La croissance avec `anticipate` (shared/team/centrale.lua)
---------------------------------------------------------------------------------------------------
section("3. C.growth avec anticipate")
local C = dofile("shared/team/centrale.lua")
local st = { sat = 0, saturated = false }
local base = { done = 1, pending = 0, refused = 0, hold = false, cool = false, off = false, built = 1, lane_cap = 6 }
local nb, why = C.growth(st, base)
check(nb == nil and why == "pas saturee", "ni saturee ni avance : rien (comme avant)")
local n2 = copy(base); n2.anticipate = true
nb, why = C.growth(st, n2)
check(nb ~= nil, "avance sans saturation : une centrale est demandee")
n2.pending = 1
nb, why = C.growth(st, n2)
check(nb == nil and why == "un chantier de centrale est ouvert", "avance : un chantier ouvert la retient toujours")
n2.pending = 0; n2.done = 0
nb, why = C.growth(st, n2)
check(nb == nil and why == "aucune centrale finie", "avance : aucune centrale finie, rien")
n2.done = 6
nb, why = C.growth(st, n2)
check(nb == nil and why == "plafond de centrales", "avance : plafond de centrales respecte")
n2.done = 1; n2.cool = true
nb, why = C.growth(st, n2)
check(nb == nil, "avance : la pause apres un refus est respectee")
n2.cool = false; n2.off = true
nb, why = C.growth(st, n2)
check(nb == nil and why == "regle coupee", "avance : reglage de banc qui coupe la regle")
n2.off = false; n2.hold = true
nb, why = C.growth(st, n2)
check(nb == nil, "avance : le repli de l'equipe (crise de matiere) retient l'amelioration")
-- reconstruction bloquee : retiree des chantiers ouverts par l'appelant (pending - bloques)
local n3 = copy(base); n3.anticipate = true; n3.pending = 1 - 1
check(C.growth(st, n3) ~= nil, "reconstruction sans progres retiree du compte des chantiers : la croissance part")

---------------------------------------------------------------------------------------------------
-- 4. Chaîne statique
---------------------------------------------------------------------------------------------------
section("4. Chaine statique")
local function slurp(path) local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s end
local build, arms, worker = slurp("script/team/build.lua"), slurp("script/team/plant_arms.lua"), slurp("script/team/worker.lua")
check(arms:find("Sante.observe(f, surface, p, tick)", 1, true) ~= nil, "PA.watch lit la sante de chaque centrale posee")
check(arms:find("Sante.growth(f, tick, plants, power, capacity + reopened_alive)", 1, true) ~= nil, "PA.watch calcule l'avance et les reconstructions bloquees")
check(slurp("script/team/sante_centrale.lua"):find("S.capi_kw(f.team and f.team.capi and f.team.capi.kw_blocked, tick)", 1, true) ~= nil
  and slurp("script/ai3/capitalisation.lua"):find("cs.kw_blocked = (res.kw and res.kw.blocked > 0) and { kw = res.kw.blocked, tick = tick } or nil", 1, true) ~= nil,
  "etape 5a : la capitalisation date ses kW retenus, Sante.growth les compte")
check(arms:find("pending = pending - ns", 1, true) ~= nil and arms:find("anticipate = anticipate", 1, true) ~= nil, "C.growth recoit chantiers - bloques et l'avance")
check(build:find("name == \"no_sante\"", 1, true) ~= nil, "reglage de banc no_sante (temoin)")
check(build:find("Sante.tasks(f, p, out, function(x, y)", 1, true) ~= nil, "quai_tasks emet la tache d'amorce")
check(build:find("elseif job.mode == \"amorce\" then\n    return Sante.work(f, p, surface, inv, tick)", 1, true) ~= nil, "Build.work execute le mode amorce")
check(build:find("local ok = Sante.gate(f, p, tick, function(spec)", 1, true) ~= nil, "advance passe par la porte des consommateurs")
check(worker:find("j.mode == \"fill\" or j.mode == \"amorce\"", 1, true) ~= nil, "le programme du PNJ prend le charbon au coffre pour l'amorce")
check(slurp("shared/team/centrale.lua"):find("not n.anticipate", 1, true) ~= nil, "C.growth lit `anticipate`")

---------------------------------------------------------------------------------------------------
-- 5. Mutants de la règle pure
---------------------------------------------------------------------------------------------------
section("5. Mutants")
local function mutant(label, edit)
  local Sm = dofile("shared/team/sante_centrale.lua")
  edit(Sm)
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(battery, Sm)
  quiet = false
  local caught = failures > f0 or not ok
  passes, failures = p0, f0
  check(caught, "mutant refuse : " .. label)
end
mutant("jet de 100 charbons", function(X) X.PRIME = 100 end)
mutant("amorce des le premier releve", function(X) X.DRY_CHECKS = 1 end)
mutant("amorce attendue 10 releves", function(X) X.DRY_CHECKS = 10 end)
mutant("priorite sous l'urgence du coffre", function(X) X.PRIO = 90 end)
mutant("pas de pause entre deux amorces", function(X) X.COOL = 0 end)
mutant("amorce meme avec un stock minuscule", function(X) X.PRIME_MIN = 0 end)
mutant("reconstruction jamais bloquee", function(X) X.STALL = 10 ^ 12 end)
mutant("reconstruction bloquee tout de suite", function(X) X.STALL = 0 end)
mutant("avance a 90 %", function(X) X.ANTICIPATE = 0.9 end)
mutant("avance a 30 %", function(X) X.ANTICIPATE = 0.3 end)
mutant("modules en chantier comptes a 100 %", function(X) X.DRAW = 1.0 end)
mutant("modules en chantier comptes a 10 %", function(X) X.DRAW = 0.1 end)
mutant("avance sans duree (un pic suffit)", function(X) X.ANTICIPATE_CHECKS = 1 end)
mutant("avance qui ne tient jamais", function(X) X.ANTICIPATE_CHECKS = 1000 end)
mutant("compte de l'avance jamais remis a zero", function(X)
  X.sustain = function(st, flag) if flag then st.ant_n = (st.ant_n or 0) + 1 end return (st.ant_n or 0) >= X.ANTICIPATE_CHECKS end
end)
mutant("porte qui n'attend jamais", function(X) X.GATE_WAIT = 0 end)
mutant("porte qui bloque a jamais", function(X) X.GATE_WAIT = 10 ^ 12 end)
mutant("porte a 150 % de la capacite", function(X) X.GATE_FRAC = 1.5 end)
mutant("porte a 50 % de la capacite", function(X) X.GATE_FRAC = 0.5 end)
mutant("causes sans ordre de gravite", function(X) X.CAUSES = { "coffre_vide", "pompe_manquante", "machines_manquantes", "tapis_manquant", "bras_manquants", "chaudiere_detruite", "chaudiere_a_sec" } end)
mutant("le coffre de secours vide ignore", function(X)
  local old = X.classify
  X.classify = function(c) local c2 = copy(c); c2.chest = nil; return old(c2) end
end)
mutant("les bras manquants ne demandent pas la reparation", function(X)
  local old = X.classify
  X.classify = function(c) local c2 = copy(c); c2.arms = nil; return old(c2) end
end)
mutant("chaudieres a sec jamais confirmees", function(X) X.confirm = function(st, dry) return false end end)
mutant("compte des releves jamais remis a zero", function(X)
  X.confirm = function(st, dry) if (dry or 0) > 0 then st.dry_n = (st.dry_n or 0) + 1 end return (st.dry_n or 0) >= X.DRY_CHECKS end
end)
mutant("le stock plafonne l'amorce a une chaudiere", function(X)
  local old = X.prime
  X.prime = function(st, dry, stock, tick) return old(st, math.min(dry, 1), stock, tick) end
end)
mutant("la porte ignore les consommateurs en chantier", function(X)
  local old = X.admit
  X.admit = function(st, c, new, tick) local c2 = copy(c); c2.committed = 0; return old(st, c2, new, tick) end
end)
mutant("avance qui ignore les chantiers", function(X)
  local old = X.anticipate
  X.anticipate = function(used, committed, cap) return old(used, 0, cap) end
end)
mutant("kW retenus par la capitalisation ignores", function(X) X.capi_kw = function() return 0 end end)
mutant("kW retenus par la capitalisation jamais oublies", function(X) X.CAPI_TTL = math.huge end)

print(string.format("[SANTE-CENTRALE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
