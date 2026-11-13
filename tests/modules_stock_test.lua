--[[
  Lot MODULES-POSES : test hors jeu de shared/ai3/modules_stock.lua (disposition du stock de modules) et de son runtime
  script/ai3/modules_stock.lua (tables simples, aucun moteur).

    §1 réserve et promesses : sous la réserve rien ; promis aux ordres ouverts = retiré ;
    §2 classement : l'objet qui manque d'abord, puis la plus grande sortie par module ; égalité exacte par la clé ;
    §3 honnêteté : effet ou recette non permis, emplacements pleins ou partiels, entrée absente (vitesse inutile), aucun gain ;
    §4 courant, menace, lieu dangereux, repli, clé déjà ouverte ; plafonds (machines par ordre, ordres par décision) ;
    §5 déterminisme (ordre des groupes inversé, deux passes) ; données changées (tous les noms renommés) ;
    §6 runtime : ordre ajouté à cs.open (même forme que le levier), entretien (stock pris ailleurs), pile survivre, journal ;
    §7 mutants : chaque garde retirée est vue par au moins un contrôle.
  Usage : lua5.2 tests/modules_stock_test.lua   (depuis la racine du mod)
  Ce fichier est du TEST : il nomme les prototypes (comme le moteur) ; la règle n'en voit rien.
]]

package.path = "./?.lua;" .. package.path
local C = require("tests.leviers_common")
local Ca = require("shared.ai3.capitalisation")
local Ms = require("shared.ai3.modules_stock")

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[MODULES-POSES] ECHEC : " .. msg) end
  end
end

local D0 = C.data()
local AM2 = "assembling-machine-2"

local function units(n, base)
  local u = {}
  for i = 1, n do u[i] = { x = 10 + i * 4, y = 10, u = (base or 1000) + i } end
  return u
end
local function group(recipe, n, over)
  local g = { entity = AM2, recipe = recipe, n = n, where = "qg", mods = nil, sig = "-", units = units(n) }
  for k, v in pairs(over or {}) do g[k] = v end
  return g
end
local function view(over)
  local v = { stock = { ["speed-module"] = 50 }, committed = {}, machines = { group("copper-cable", 10) }, drills = {},
    short = {}, supply = function() return true end, taken = {}, power_room_kw = 100000 }
  for k, x in pairs(over or {}) do v[k] = x end
  if over and over.no_power then v.power_room_kw = nil end
  return v
end
local function text(orders, refus)
  local t = {}
  for _, o in ipairs(orders) do
    t[#t + 1] = string.format("%s|%s|n%d|per%d|%s|out%.4f|kw%.4f|c%d", o.key, o.module, o.n, o.per, o.item, o.d_out, o.d_kw, o.class)
  end
  for _, r in ipairs(refus) do t[#t + 1] = "R:" .. r.key .. "|" .. tostring(r.module) .. "|" .. r.why end
  return table.concat(t, "\n")
end
local function plan(v, MsX, D)
  local orders, refus, info = (MsX or Ms).plan(Ca, D or D0, v)
  return orders, refus, info
end
local function find(orders, pat)
  for _, o in ipairs(orders) do if o.key:find(pat, 1, true) then return o end end
  return nil
end

---------------------------------------------------------------------------------------------------
-- §1 réserve et promesses
---------------------------------------------------------------------------------------------------
do
  check(Ms.available(50, 0, 4) == 46, "§1 disponible = stock - reserve")
  check(Ms.available(3, 0, 4) == 0, "§1 sous la reserve : 0")
  check(Ms.available(50, 40, 4) == 6, "§1 promis aux ordres ouverts retire")
  check(Ms.available(50, 60, 4) == 0, "§1 jamais negatif")
  check(Ms.available(nil, nil, nil) == 0, "§1 sans stock : 0")
  local o, r, info = plan(view({ stock = { ["speed-module"] = 4 } }))
  check(#o == 0 and info.free_total == 0, "§1 stock egal a la reserve : aucun ordre")
  o = plan(view({ stock = { ["speed-module"] = 6 } }))
  check(#o == 1 and o[1].n == 1 and o[1].per == 2, "§1 6 modules : 1 machine x 2 modules (reserve 4)")
  local o1, r1 = plan(view({ stock = { ["speed-module"] = 5 } }))
  check(#o1 == 0 and #r1 == 1 and r1[1].key == "-", "§1 5 modules (1 disponible pour 2 emplacements) : refus ecrit, rien de pose : " .. text(o1, r1))
  o1, r1 = plan(view({ stock = { ["speed-module"] = 50 }, machines = {} }))
  check(#o1 == 0 and #r1 == 1 and r1[1].key == "-", "§1 aucune machine : refus ecrit")
  o = plan(view({ stock = { ["speed-module"] = 50 }, committed = { ["speed-module"] = 44 } }))
  check(#o == 1 and o[1].n == 1, "§1 50 au coffre dont 44 promis : reste 2, 1 machine")
  o = plan(view({ stock = {} }))
  check(#o == 0, "§1 coffre vide : aucun ordre")
  o = plan(view({ stock = { ["speed-module"] = 50 }, reserve = 0 }))
  check(o[1] and o[1].n == 10 and o[1].per == 2, "§1 reserve 0 : 10 machines x 2 = 20 modules")
end

---------------------------------------------------------------------------------------------------
-- §2 classement
---------------------------------------------------------------------------------------------------
do
  local v = view({ machines = { group("iron-gear-wheel", 10), group("copper-cable", 10) }, short = { ["copper-cable"] = 5 },
    stock = { ["speed-module"] = 24 } })
  local o = plan(v)
  check(#o == 1 and o[1].item == "copper-cable" and o[1].class == Ms.CLASS_SHORT, "§2 l'objet qui manque d'abord (et seul : 20 modules disponibles)")
  check(o[1] and o[1].n == 10 and o[1].per == 2, "§2 ... 10 machines x 2 modules")
  -- sans manque : la plus grande sortie par module (cable : 180/min de base, engrenage : moins)
  local o2 = plan(view({ machines = { group("iron-gear-wheel", 10), group("copper-cable", 10) }, stock = { ["speed-module"] = 24 } }))
  check(o2[1] and o2[1].item == "copper-cable", "§2 sans manque : plus grande sortie par module d'abord")
  check(o2[1] and o2[1].class == Ms.CLASS_PLAIN, "§2 classe 2 sans manque")
  -- vitesse-2 (+30) plus forte que vitesse (+20) a la meme machine
  local o3 = plan(view({ stock = { ["speed-module"] = 30, ["speed-module-2"] = 30 } }))
  check(o3[1] and o3[1].module == "speed-module-2", "§2 le module le plus fort d'abord")
  -- repli sur l'autre module quand le premier est epuise
  local o4 = plan(view({ machines = { group("copper-cable", 2), group("iron-gear-wheel", 2) }, stock = { ["speed-module"] = 20, ["speed-module-2"] = 8 } }))
  check(#o4 == 2, "§2 deux groupes, deux ordres")
  check(o4[1].module == "speed-module-2" and o4[2].module == "speed-module", "§2 module epuise : le groupe suivant prend l'autre sorte")
  -- productivite : la barème D-17 donne un gain de sortie sur une recette permise
  local o5 = plan(view({ stock = { ["productivity-module"] = 20 } }))
  check(o5[1] and o5[1].module == "productivity-module" and o5[1].d_out > 0, "§2 productivite sur une recette permise")
end

---------------------------------------------------------------------------------------------------
-- §3 honnêteté
---------------------------------------------------------------------------------------------------
do
  -- recette hors de la liste du module de productivite : jamais pose
  local o, r = plan(view({ machines = { group("inserter", 4) }, stock = { ["productivity-module"] = 30 } }))
  check(#o == 0, "§3 recette non permise : aucun module de productivite")
  check(#r == 1 and r[1].why:find("non permis", 1, true) ~= nil, "§3 la cause est ecrite : " .. text(o, r))
  -- la vitesse y va
  o = plan(view({ machines = { group("inserter", 4) }, stock = { ["productivity-module"] = 30, ["speed-module"] = 30 } }))
  check(#o == 1 and o[1].module == "speed-module", "§3 meme machine : la vitesse est permise")
  -- emplacements pleins
  o = plan(view({ machines = { group("copper-cable", 4, { mods = { ["speed-module"] = 2 }, sig = "speed-module*2" }) } }))
  check(#o == 0, "§3 emplacements pleins : rien")
  -- emplacements partiels : per = libres
  o = plan(view({ machines = { group("copper-cable", 4, { mods = { ["speed-module"] = 1 }, sig = "speed-module*1" }) } }))
  check(#o == 1 and o[1].per == 1 and o[1].n == 4, "§3 un emplacement libre : per = 1")
  -- machine sans emplacements
  o = plan(view({ machines = { group("copper-cable", 4, { entity = "stone-furnace" }) } }))
  check(#o == 0, "§3 machine sans emplacements : rien")
  -- vitesse sans entree servie : refusee ; productivite acceptee
  local supply = function(item) return item ~= "copper-plate" end
  o, r = plan(view({ supply = supply }))
  check(#o == 0 and #r == 1 and r[1].why:find("manque", 1, true) ~= nil, "§3 entree absente : la vitesse n'ajouterait rien : " .. text(o, r))
  o = plan(view({ supply = supply, stock = { ["speed-module"] = 50, ["productivity-module"] = 50 } }))
  check(#o == 1 and o[1].module == "productivity-module", "§3 entree absente : la productivite reste permise")
  -- aucun gain : un module sans effet sur la sortie
  local D1 = C.data(function(d) for _, e in ipairs(d.entities) do if e.name == AM2 then e.speed = 0 end end end)
  o, r = plan(view(), nil, D1)
  check(#o == 0 and #r == 1 and r[1].why:find("aucun gain", 1, true) ~= nil, "§3 machine sans sortie : aucun gain, cause ecrite : " .. text(o, r))
  -- foreuse : productivite d'une foreuse, jamais de fluide
  local drill = { entity = "electric-mining-drill", resource = "iron-ore", deposit = "d1", n = 6, mods = nil, sig = "-", units = units(6, 2000) }
  o = plan(view({ machines = {}, drills = { drill }, stock = { ["speed-module"] = 20 } }))
  check(#o == 1 and o[1].resource == "iron-ore" and o[1].deposit == "d1" and o[1].per == 3, "§3 foreuse : 3 emplacements")
  check(o[1] and o[1].recipe == nil, "§3 foreuse : pas de recette")
end

-- machine arretee, foreuse qui tourne (lot MODULES-POSES, precision du DC : « sur les foreuses »)
do
  local stopped = group("copper-cable", 6, { run = { sampled = 6, working = 0, stop = "waiting_for_space_in_destination" } })
  local o, r = plan(view({ machines = { stopped } }))
  check(#o == 0 and #r == 1 and r[1].why:find("arretee", 1, true) ~= nil and r[1].why:find("waiting_for_space", 1, true) ~= nil,
    "§3b machine arretee : rien, cause ecrite : " .. text(o, r))
  o = plan(view({ machines = { group("copper-cable", 6, { run = { sampled = 6, working = 2 } }) } }))
  check(#o == 1, "§3b une machine qui travaille un peu est equipee")
  o = plan(view({ machines = { group("copper-cable", 6, { run = { sampled = 0, working = 0 } }) } }))
  check(#o == 1, "§3b statut non lu : comme avant")
  local drill = { entity = "electric-mining-drill", resource = "iron-ore", deposit = "d1", n = 6, sig = "-", units = units(6, 2000) }
  o = plan(view({ machines = { group("copper-cable", 4) }, drills = { drill }, stock = { ["speed-module"] = 14 } }))
  check(#o == 1 and o[1].resource == "iron-ore" and o[1].class == Ms.CLASS_DRILL, "§3b une foreuse qui tourne passe avant une machine sans manque")
  o = plan(view({ machines = { group("copper-cable", 4) }, drills = { drill }, short = { ["copper-cable"] = 3 }, stock = { ["speed-module"] = 14 } }))
  check(#o == 1 and o[1].item == "copper-cable", "§3b l'objet qui manque passe avant la foreuse")
  local dstop = {}
  for k, x in pairs(drill) do dstop[k] = x end
  dstop.run = { sampled = 6, working = 0, stop = "waiting_for_space_in_destination" }
  o = plan(view({ machines = {}, drills = { dstop } }))
  check(#o == 0, "§3b foreuse sans debouche (waiting_for_space) : rien")
end

---------------------------------------------------------------------------------------------------
-- §4 courant, menace, danger, repli, doublons, plafonds
---------------------------------------------------------------------------------------------------
do
  local o, r = plan(view({ no_power = true }))
  check(#o == 0 and #r >= 1 and r[1].why:find("courant non lu", 1, true) ~= nil, "§4 courant non lu : machine electrique refusee")
  -- marge non lue : reseau observe sans manque -> petits pas ; reseau en manque -> rien
  local okrun = { sampled = 6, working = 6, starved = 0 }
  o = plan(view({ no_power = true, machines = { group("copper-cable", 10, { run = okrun }) }, stock = { ["speed-module"] = 100 } }))
  check(#o == 1 and o[1].n == Ms.UNREAD_BATCH, "§4 marge non lue, reseau sans manque : au plus UNREAD_BATCH machines")
  o, r = plan(view({ no_power = true, machines = { group("copper-cable", 10, { run = { sampled = 6, working = 3, starved = 2, stop = "low_power" } }) } }))
  check(#o == 0 and r[1] and r[1].why:find("reseau en manque", 1, true) ~= nil, "§4 marge non lue, reseau en manque : refus ecrit : " .. text(o, r))
  o = plan(view({ power_room_kw = 0 }))
  check(#o == 0, "§4 aucune marge de courant : rien")
  local one = plan(view({ power_room_kw = 100000, machines = { group("copper-cable", 1) } }))
  local kw1 = one[1] and one[1].d_kw or 0
  check(kw1 > 0, "§4 le courant de plus d'une machine est positif (barème D-17)")
  o = plan(view({ power_room_kw = kw1 * 3 + 0.01 }))
  check(o[1] and o[1].n == 3, "§4 la marge borne le nombre de machines (3)")
  o = plan(view({ machines = { group("copper-cable", 10, { where = "loin" }) }, threat = true }))
  check(#o == 0, "§4 hors du QG sous menace : rien")
  o = plan(view({ machines = { group("copper-cable", 10, { where = "loin" }) }, threat = false }))
  check(#o == 1 and o[1].where == "loin" and o[1].deposit == "loin", "§4 hors du QG sans menace : permis")
  o = plan(view({ machines = { group("copper-cable", 10, { where = "d7" }) }, danger = { d7 = true } }))
  check(#o == 0, "§4 lieu dangereux : rien")
  o = plan(view({ machines = { group("copper-cable", 10) }, threat = true }))
  check(#o == 1, "§4 au QG, la menace ne ferme pas la pose")
  local key = Ms.key(group("copper-cable", 10), false, "qg")
  o = plan(view({ held = function(k) return k == key and "repli apres 1 refus" or nil end }))
  check(#o == 0, "§4 cle en repli : attend")
  o = plan(view({ taken = { [key] = true } }))
  check(#o == 0, "§4 cle deja ouverte : aucun doublon")
  o = plan(view({ machines = { group("copper-cable", 40) }, stock = { ["speed-module"] = 500 } }))
  check(o[1] and o[1].n == Ms.BATCH_MAX, "§4 au plus BATCH_MAX machines par ordre")
  local gs = {}
  for i = 1, 6 do gs[i] = group("copper-cable", 3, { where = "w" .. i }) end
  o = plan(view({ machines = gs, stock = { ["speed-module"] = 500 } }))
  check(#o == Ms.MAX_ORDERS, "§4 au plus MAX_ORDERS ordres par decision")
  o = plan(view({ machines = gs, stock = { ["speed-module"] = 500 }, max_orders = 5 }))
  check(#o == 5, "§4 plafond reglable")
  -- jamais plus de modules que le stock disponible, tous groupes confondus
  o = plan(view({ machines = gs, stock = { ["speed-module"] = 18 } }))
  local used = 0
  for _, x in ipairs(o) do used = used + x.n * x.per end
  check(used <= 14, "§4 le total pose ne depasse pas le stock moins la reserve (" .. used .. ")")
  check(used == 14, "§4 ... et l'utilise (14 sur 14)")
end

---------------------------------------------------------------------------------------------------
-- §5 déterminisme et données changées
---------------------------------------------------------------------------------------------------
do
  local gs = {}
  for i = 1, 5 do gs[i] = group(i % 2 == 0 and "copper-cable" or "iron-gear-wheel", 3 + i, { where = "w" .. i }) end
  local rev = {}
  for i = #gs, 1, -1 do rev[#rev + 1] = gs[i] end
  local a = text(plan(view({ machines = gs, stock = { ["speed-module"] = 60 } })))
  local b = text(plan(view({ machines = rev, stock = { ["speed-module"] = 60 } })))
  local c = text(plan(view({ machines = gs, stock = { ["speed-module"] = 60 } })))
  check(a == c, "§5 deux passes identiques")
  check(a == b, "§5 l'ordre des groupes du releve ne change pas la decision")
  -- TOUS les noms changes (objets, recettes, machines, ressources, modules, recettes permises) : memes ordres au renommage pres
  local d0 = C.dump()
  local map = C.name_map(d0)
  local unmap = {}
  for _, k in ipairs(C.sorted_keys(map)) do unmap[map[k]] = k end
  local d2 = C.rename(d0, map)
  local exec2 = {}
  for _, k in ipairs(C.sorted_keys(C.EXEC)) do exec2[map[k]] = true end
  local Da = Ca.data(d0, { exec = C.EXEC, exec_roles = C.ROLES })
  local Db = Ca.data(d2, { exec = exec2, exec_roles = C.ROLES })
  local va = view({ machines = { group("copper-cable", 8), group("iron-gear-wheel", 6) }, short = { ["copper-cable"] = 3 },
    stock = { ["speed-module"] = 30, ["productivity-module"] = 30 } })
  local vb = view({ machines = { group(map["copper-cable"], 8, { entity = map[AM2] }), group(map["iron-gear-wheel"], 6, { entity = map[AM2] }) },
    short = { [map["copper-cable"]] = 3 }, stock = { [map["speed-module"]] = 30, [map["productivity-module"]] = 30 } })
  local oa = plan(va, nil, Da)
  local ob = plan(vb, nil, Db)
  check(#oa >= 1 and #oa == #ob, "§5 renommage : meme nombre d'ordres (" .. #oa .. " et " .. #ob .. ")")
  local same = #oa == #ob
  for i = 1, math.min(#oa, #ob) do
    local ka = ob[i].key:gsub("[%w%-_]+", function(w) return unmap[w] or w end)
    if ka ~= oa[i].key or unmap[ob[i].module] ~= oa[i].module or ob[i].n ~= oa[i].n or ob[i].per ~= oa[i].per
      or math.abs(ob[i].d_out - oa[i].d_out) > 1e-9 then same = false end
  end
  check(same, "§5 renommage : memes cles, modules, nombres et sorties au renommage pres")
end

---------------------------------------------------------------------------------------------------
-- §6 runtime (tables simples)
---------------------------------------------------------------------------------------------------
local RT = require("script.ai3.modules_stock")
RT.ROI = false -- lot S42 MODULES-ROI : ce test couvre l'ancienne regle (Ms.plan) ; la passe ROI a son test (tests/s42_modules-roi_test.lua)
local Pi = require("shared.ai3.pile")
local logged = {}
log = function(s) logged[#logged + 1] = s end
local function lines(pat)
  local n = 0
  for _, l in ipairs(logged) do if l:find(pat, 1, true) then n = n + 1 end end
  return n
end

local function team(over)
  local f = { key = "azure", started = 0, team = { ia3 = { short = {}, pile = { hold = false, top = Pi.AMELIORER } } } }
  for k, x in pairs(over or {}) do f[k] = x end
  return f
end
local function cstate(machines)
  return { open = {}, scan = { tick = 600, machines = machines or { group("copper-cable", 10) }, drills = {} }, deps = {}, flows = {},
    orders = 0, stats = {} }
end
local function ctx(stockn, extra)
  local counts = type(stockn) == "table" and stockn or { ["speed-module"] = stockn }
  counts["copper-plate"], counts["iron-plate"] = counts["copper-plate"] or 1000, counts["iron-plate"] or 1000 -- entrees servies
  local c = { Ca = Ca, D = D0, minutes = function(_, t) return t / 3600 end, held = function() return nil end,
    count = function(item) return counts[item] or 0 end, power = function() return { have_kw = 100000, used_kw = 0 } end, threat = false,
    counts = counts }
  for k, x in pairs(extra or {}) do c[k] = x end
  return c
end

do
  local f, cs, c = team(), cstate(), ctx(50)
  local n = RT.think(f, cs, 600, c)
  check(n == 1 and #cs.open == 1, "§6 un ordre de stock ajoute a cs.open")
  local rec = cs.open[1]
  check(rec.exec == "equiper" and rec.kind == "equiper" and rec.stock == true, "§6 forme du levier : exec/kind equiper, stock")
  check(rec.module == "speed-module" and rec.per == 2 and #rec.targets == 10 and rec.n_left == 10, "§6 10 machines x 2 modules")
  check(rec.targets[1].u == 1001 and rec.targets[1].entity == AM2 and rec.targets[1].x ~= nil, "§6 cibles (unite, position, entite)")
  check(#rec.done == 0 and rec.inserted == 0 and type(rec.missing) == "table" and #rec.missing == 0, "§6 rien pose encore, rien a fabriquer")
  check(rec.d_item == "copper-cable" and rec.d_out > 0 and rec.announced.d_out == rec.d_out, "§6 sortie annoncee")
  check(lines("[FO-MODULES] azure : ordre equiper:") == 1, "§6 journal : une ligne d'ordre")
  -- meme releve : pas de nouvelle disposition
  check(RT.think(f, cs, 700, c) == 0 and #cs.open == 1, "§6 un releve = une disposition")
  -- releve suivant : la cle est ouverte, aucun doublon
  cs.scan.tick = 4200
  check(RT.think(f, cs, 4200, c) == 0 and #cs.open == 1, "§6 cle ouverte : pas de doublon au releve suivant")
  -- entretien : les modules de la tache sont en route (coffre 50 -> 7) : le suivi ecrit un manque, l'ordre de stock l'efface (jamais de fabrication)
  c.counts["speed-module"] = 7
  rec.missing = { { "speed-module", 13 } }
  RT.think(f, cs, 4300, c)
  check(#rec.missing == 0, "§6 manque efface : un ordre de stock ne fait jamais fabriquer de module")
  check(rec.n_left == 10 and #rec.targets == 10, "§6 ... et l'ordre garde ses machines (le PNJ porte deja les modules)")
end
do
  -- pile survivre : rien, une seule ligne
  logged = {}
  local f = team()
  f.team.ia3.pile = { hold = true, top = Pi.SURVIVRE }
  local cs, c = cstate(), ctx(50)
  check(RT.think(f, cs, 600, c) == 0 and #cs.open == 0, "§6 pile survivre : aucun ordre")
  cs.scan.tick = 4200
  RT.think(f, cs, 4200, c)
  check(lines("pile survivre") == 1, "§6 pile survivre : la cause n'est ecrite qu'une fois")
  f.team.ia3.pile = { hold = true, top = Pi.ADAPTER }
  cs.scan.tick = 7800
  check(RT.think(f, cs, 7800, c) == 1, "§6 pile 'adapter' (retenue R1) : la pose reste permise")
  local ok = RT.gate(f)
  check(ok == true, "§6 gate : permis sous adapter")
  f.team.ia3.pile = { hold = true, top = Pi.SURVIVRE }
  check(select(1, RT.gate(f)) == false, "§6 gate : refuse sous survivre")
  f.team.ia3.pile = nil
  check(select(1, RT.gate(f)) == true, "§6 gate : permis sans pile")
  -- sous la reserve : une ligne, une fois
  logged = {}
  local f2, cs2, c2 = team(), cstate(), ctx(3)
  RT.think(f2, cs2, 600, c2)
  cs2.scan.tick = 4200
  RT.think(f2, cs2, 4200, c2)
  check(lines("sous la reserve") == 1, "§6 sous la reserve : une ligne, une fois")
  -- coffre vide : silence
  logged = {}
  local f3, cs3, c3 = team(), cstate(), ctx(0)
  RT.think(f3, cs3, 600, c3)
  check(#logged == 0, "§6 coffre vide : aucune ligne")
  -- refus ecrit une fois avec sa cause
  logged = {}
  local f4, cs4 = team(), cstate({ group("inserter", 4) })
  local c4 = ctx({ ["productivity-module"] = 40 })
  RT.think(f4, cs4, 600, c4)
  cs4.scan.tick = 4200
  RT.think(f4, cs4, 4200, c4)
  check(lines("[FO-MODULES] azure : refus equiper:") == 1, "§6 refus de machine : une ligne, une fois")
  check(lines("non permis") == 1, "§6 ... avec la cause (effet ou recette non permis)")
  -- statut : une machine arretee ne recoit rien (runtime)
  logged = {}
  local f7, cs7 = team(), cstate({ group("copper-cable", 4), group("iron-gear-wheel", 4, { units = units(4, 3000) }) })
  local c7 = ctx(50, { status = function(_, u) return u.u <= 1004 and "waiting_for_space_in_destination" or "working" end })
  RT.think(f7, cs7, 600, c7)
  check(#cs7.open == 1 and cs7.open[1].item == "iron-gear-wheel", "§6 statut lu : seule la machine qui travaille est equipee")
  check(lines("machine arretee : waiting_for_space_in_destination") == 1, "§6 ... et la cause d'arret est au journal")
  -- unites arretees d'un groupe qui travaille en partie : elles ne sont pas des cibles
  logged = {}
  local f8, cs8 = team(), cstate({ group("copper-cable", 4) })
  local c8 = ctx(50, { status = function(_, u) return (u.u == 1001 or u.u == 1003) and "item_ingredient_shortage" or "working" end })
  RT.think(f8, cs8, 600, c8)
  local tg = cs8.open[1] and cs8.open[1].targets or {}
  check(#tg == 2 and tg[1].u == 1002 and tg[2].u == 1004, "§6 seules les unites qui travaillent sont des cibles (1002 et 1004)")
  -- reglage eteint
  RT.ENABLED = false
  local f5, cs5 = team(), cstate()
  check(RT.think(f5, cs5, 600, ctx(50)) == 0 and #cs5.open == 0, "§6 reglage eteint : rien")
  RT.ENABLED = true
  -- les enregistrements ne portent aucune fonction ni entite (global)
  local f6, cs6 = team(), cstate()
  RT.think(f6, cs6, 600, ctx(50))
  local function pure(v, depth)
    if depth > 6 then return true end
    if type(v) == "function" or type(v) == "userdata" then return false end
    if type(v) == "table" then
      for _, x in pairs(v) do if not pure(x, depth + 1) then return false end end
    end
    return true
  end
  check(pure(cs6, 0), "§6 aucune fonction dans cs (global)")
end

---------------------------------------------------------------------------------------------------
-- §7 mutants
---------------------------------------------------------------------------------------------------
local function read_all(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local MS_SRC = read_all("shared/ai3/modules_stock.lua")

local function scenes()
  local gs = {}
  for i = 1, 6 do gs[i] = group("copper-cable", 3, { where = "w" .. i }) end
  local key = Ms.key(group("copper-cable", 10), false, "qg")
  local sc = {}
  local function add(v, MsX) sc[#sc + 1] = function(M) return text(plan(v(), M)) end end
  add(function() return view({ stock = { ["speed-module"] = 4 } }) end)
  add(function() return view({ stock = { ["speed-module"] = 50 }, committed = { ["speed-module"] = 44 } }) end)
  add(function() return view({ machines = { group("inserter", 4) }, stock = { ["productivity-module"] = 30 } }) end)
  add(function() return view({ machines = { group("iron-gear-wheel", 10), group("copper-cable", 10) }, short = { ["iron-gear-wheel"] = 5 }, stock = { ["speed-module"] = 24 } }) end)
  add(function() return view({ machines = { group("iron-gear-wheel", 10), group("copper-cable", 10) }, stock = { ["speed-module"] = 24 } }) end)
  add(function() return view({ stock = { ["speed-module"] = 30, ["speed-module-2"] = 30 } }) end)
  add(function() return view({ supply = function(item) return item ~= "copper-plate" end }) end)
  add(function() return view({ no_power = true }) end)
  add(function() return view({ power_room_kw = 20 }) end)
  add(function() return view({ no_power = true, machines = { group("copper-cable", 10, { run = { sampled = 6, working = 6, starved = 0 } }) }, stock = { ["speed-module"] = 100 } }) end)
  add(function() return view({ no_power = true, machines = { group("copper-cable", 10, { run = { sampled = 6, working = 3, starved = 2, stop = "low_power" } }) } }) end)
  add(function() return view({ machines = { group("copper-cable", 10, { where = "loin" }) }, threat = true }) end)
  add(function() return view({ machines = { group("copper-cable", 10, { where = "d7" }) }, danger = { d7 = true } }) end)
  add(function() return view({ held = function(k) return k == key and "repli" or nil end }) end)
  add(function() return view({ taken = { [key] = true } }) end)
  add(function() return view({ machines = { group("copper-cable", 40) }, stock = { ["speed-module"] = 500 } }) end)
  add(function() return view({ machines = gs, stock = { ["speed-module"] = 500 } }) end)
  add(function() return view({ machines = gs, stock = { ["speed-module"] = 18 } }) end)
  add(function() return view({ machines = { group("copper-cable", 4, { mods = { ["speed-module"] = 2 }, sig = "speed-module*2" }) } }) end)
  add(function() return view({ machines = { group("copper-cable", 4, { mods = { ["speed-module"] = 1 }, sig = "speed-module*1" }) } }) end)
  add(function() return view({ machines = { group("copper-cable", 2), group("iron-gear-wheel", 2) }, stock = { ["speed-module"] = 20, ["speed-module-2"] = 8 } }) end)
  add(function() return view({ machines = { group("copper-cable", 6, { units = {} }) } }) end)
  add(function() return view({ machines = { group("copper-cable", 6, { run = { sampled = 6, working = 0, stop = "x" } }) } }) end)
  add(function() return view({ machines = { group("copper-cable", 4) }, drills = { { entity = "electric-mining-drill", resource = "iron-ore", deposit = "d1", n = 6, sig = "-", units = units(6, 2000) } }, stock = { ["speed-module"] = 14 } }) end)
  sc[#sc + 1] = function(M)
    local D1 = C.data(function(d) for _, e in ipairs(d.entities) do if e.name == AM2 then e.speed = 0 end end end)
    return text(plan(view(), M, D1))
  end
  return sc
end

local function fingerprint(M)
  local out = {}
  for _, s in ipairs(scenes()) do
    local ok, t = pcall(s, M)
    out[#out + 1] = ok and t or ("ERR:" .. tostring(t))
  end
  return table.concat(out, "\n--\n")
end

local base_fp = fingerprint(Ms)

local function mutant(old, new)
  local i, j = MS_SRC:find(old, 1, true)
  assert(i, "mutant : motif introuvable : " .. old)
  assert(not MS_SRC:find(old, j + 1, true), "mutant : motif ambigu : " .. old)
  local src = MS_SRC:sub(1, i - 1) .. new .. MS_SRC:sub(j + 1)
  local chunk = assert(load(src, "@modules_stock_mutant"))
  return chunk()
end

local n_mut, n_caught = 0, 0
local function M(name, old, new)
  n_mut = n_mut + 1
  local MsX = mutant(old, new)
  if fingerprint(MsX) ~= base_fp then n_caught = n_caught + 1
  elseif not quiet then print("[MODULES-POSES] mutant NON refuse : " .. name) end
end

M("reserve ignoree", "local n = (stock or 0) - (committed or 0) - (reserve or Ms.RESERVE)", "local n = (stock or 0) - (committed or 0)")
M("promis aux ordres ouverts ignores", "local n = (stock or 0) - (committed or 0) - (reserve or Ms.RESERVE)", "local n = (stock or 0) - (reserve or Ms.RESERVE)")
M("effet ou recette non permis ignore", "if not Lv.fits(L, m, sl, (not is_drill) and r.name or nil) then", "if false then")
M("classe 'objet qui manque' ignoree", "if a.class ~= b.class then return a.class < b.class end", "")
M("sortie par module en ordre inverse", "return a.gain_module > b.gain_module", "return a.gain_module < b.gain_module")
M("entree absente non exigee", "if not ing.fluid and not served(ing.name) then", "if false then")
M("courant non lu accepte sans statut", "if not run or (run.sampled or 0) == 0 then", "if false then")
M("reseau en manque accepte (courant non lu)", "elseif (run.starved or 0) > 0 then", "elseif false then")
M("courant non lu : pas de petits pas", "k = math.min(k, Ms.UNREAD_BATCH)", "")
M("marge de courant ignoree", "if fit < k then k = fit end", "")
M("menace ignoree", "if v.threat then refuse(key, nil, \"menace : machines du QG seulement\") return end", "")
M("lieu dangereux ignore", "if (v.danger or {})[where] then", "if false then")
M("repli ignore", "if held then refuse(key, nil, held) return end", "")
M("cle deja ouverte ignoree", "if taken[key] then return end", "")
M("machines par ordre non bornees", "math.min(o.units, Ms.BATCH_MAX, math.floor(avail[o.nm] / o.free))", "math.min(o.units, math.floor(avail[o.nm] / o.free))")
M("ordres par decision non bornes", "if #orders >= max_orders then break end", "")
M("modules non decomptes entre ordres", "avail[o.nm] = avail[o.nm] - k * o.free", "")
M("emplacements pleins ignores", "if free <= 0 then return end", "")
M("aucun gain de sortie accepte", "if per_machine <= Ms.EPS then", "if false then")
M("module de vitesse sans disponibilite suffisante", "if avail[nm] >= free then", "if avail[nm] >= 0 then")
M("unites du releve ignorees", "if nunits <= 0 then return end", "")
M("machine arretee equipee", "if g.run and (g.run.sampled or 0) > 0 and (g.run.working or 0) == 0 then", "if false then")
M("foreuse sans classe propre", "or (is_drill and Ms.CLASS_DRILL or Ms.CLASS_PLAIN)", "or Ms.CLASS_PLAIN")
M("tri par cle supprime", "if a.key ~= b.key then return a.key < b.key end\n    return a.nm < b.nm", "return a.nm < b.nm")
check(n_caught == n_mut, string.format("§7 mutants : %d refuses sur %d", n_caught, n_mut))

-- porte de la pile (mutant de la fonction pure)
do
  local MsX = mutant("if top_survive then", "if false then")
  check(MsX.gate(true) == true and Ms.gate(true) == false, "§7 mutant : la porte 'survivre' retiree est vue")
end

print(string.format("[MODULES-POSES] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refuses sur %d)", pass, fail, n_caught, n_mut))
os.exit(fail == 0 and 0 or 1)
