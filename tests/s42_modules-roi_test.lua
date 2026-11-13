--[[
  Lot S42 MODULES-ROI : test hors jeu de shared/ai3/modules_roi.lua (productivité ou vitesse par machine, passe de l'équipe,
  souhaits de fabrication) et de son câblage dans script/ai3/modules_stock.lua (tables simples, aucun moteur).

    §1 famille, admission, état d'un groupe ;
    §2 Roi.choose : chaque état, coût en matière de la recette, limitation, pose partielle, souhait et retour ;
    §3 Roi.plan : sans réserve, pose partielle, machine qui attend ses entrées, repli sur le stock, bornes, déterminisme,
       données changées (tous les noms renommés) ;
    §4 runtime : ordre de stock, ordre de fabrication (un seul ouvert, manque gardé), coffre vide ;
    §5 mutants ; aucun nom du jeu dans la règle.
  Usage : lua5.2 tests/s42_modules-roi_test.lua   (depuis la racine du mod)
  Ce fichier est du TEST : il nomme les prototypes (comme le moteur) ; la règle n'en voit rien.
]]

package.path = "./?.lua;" .. package.path
local C = require("tests.leviers_common")
local Ca = require("shared.ai3.capitalisation")
local Ms = require("shared.ai3.modules_stock")
local Roi = require("shared.ai3.modules_roi")

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[S42-MODULES-ROI] ECHEC : " .. msg) end
  end
end

local D0 = C.data()
local AM2, FOUR, FOR = "assembling-machine-2", "electric-furnace", "electric-mining-drill"
local SP, PR, PR2 = "speed-module", "productivity-module", "productivity-module-2"

---------------------------------------------------------------------------------------------------
-- §1 famille, admission, état
---------------------------------------------------------------------------------------------------
check(Roi.family({ productivity = 10, speed = -2 }) == Roi.PROD, "§1 famille productivite")
check(Roi.family({ speed = 20, consumption = 12 }) == Roi.SPEED, "§1 famille vitesse")
check(Roi.family({ consumption = -30 }) == nil and Roi.family(nil) == nil, "§1 module sans vitesse ni productivite : aucune famille")
do
  local m = { eff = { productivity = 10, speed = -2 }, limit = { a = true } }
  check(Roi.fits(m, { productivity = true, speed = true }, "a"), "§1 admis : effets permis, recette dans la limitation")
  check(not Roi.fits(m, { productivity = true, speed = true }, "b"), "§1 refuse : recette hors de la limitation")
  check(not Roi.fits(m, { speed = true }, "a"), "§1 refuse : effet non permis")
  check(Roi.fits(m, { productivity = true, speed = true }, nil), "§1 foreuse (sans recette) : la limitation ne joue pas")
end
check(Roi.state(nil) == Roi.S_NONE and Roi.state({ sampled = 0 }) == Roi.S_NONE, "§1 etat : non lu")
check(Roi.state({ sampled = 3, working = 3 }) == Roi.S_RUN, "§1 etat : tourne")
check(Roi.state({ sampled = 3, working = 3, loads = 3, bott = 2 }) == Roi.S_NECK, "§1 etat : goulot (entrees pleines, sortie vide)")
check(Roi.state({ sampled = 3, working = 3, loads = 3, bott = 1 }) == Roi.S_RUN, "§1 etat : goulot minoritaire = tourne")
check(Roi.state({ sampled = 3, working = 0, short_in = 2 }) == Roi.S_IN, "§1 etat : attend ses entrees")
check(Roi.state({ sampled = 3, working = 0, full = 3 }) == Roi.S_OUT, "§1 etat : sortie pleine")
check(Roi.state({ sampled = 3, working = 0 }) == Roi.S_STOP, "§1 etat : arret")

---------------------------------------------------------------------------------------------------
-- §2 Roi.choose (noms neutres : la règle ne lit que les effets)
---------------------------------------------------------------------------------------------------
local function mods(hs, hp, over)
  local l = {
    { name = "v", eff = { speed = 20, consumption = 12 }, have = hs, cost = 300, craftable = true },
    { name = "p", eff = { productivity = 10, speed = -2, consumption = 6 }, limit = { cher = true, temps = true }, have = hp, cost = 300, craftable = true },
  }
  for _, m in ipairs(over or {}) do l[#l + 1] = m end
  return l
end
local ALL = { speed = true, productivity = true, consumption = true }
local function mc(over)
  local m = { slots = 2, filled = 0, allowed = ALL, recipe = "cher", c = 10, v_out = 10, v_in = 9, state = Roi.S_RUN, cands = mods(10, 10) }
  for k, x in pairs(over or {}) do m[k] = x end
  return m
end
do
  local r = Roi.choose(mc())
  check(r.family == Roi.PROD and r.module == "p" and r.n == 2, "§2 recette faite surtout de matiere : productivite")
  r = Roi.choose(mc({ recipe = "temps", v_in = 1 }))
  check(r.family == Roi.SPEED and r.module == "v", "§2 recette faite surtout de temps de machine : vitesse")
  r = Roi.choose(mc({ state = Roi.S_NECK }))
  check(r.family == Roi.SPEED and r.module == "v", "§2 goulot (entrees pleines, sortie vide) : vitesse, meme pour une recette chere")
  r = Roi.choose(mc({ state = Roi.S_IN }))
  check(r.family == Roi.PROD and r.module == "p", "§2 attend ses entrees : productivite")
  r = Roi.choose(mc({ state = Roi.S_IN, recipe = "autre" }))
  check(r.family == nil and r.module == nil and r.want == nil, "§2 attend ses entrees, recette hors limitation : rien (la vitesse n'ajoute rien)")
  r = Roi.choose(mc({ recipe = "autre" }))
  check(r.family == Roi.SPEED and r.module == "v", "§2 recette hors limitation : vitesse")
  r = Roi.choose(mc({ state = Roi.S_OUT }))
  check(r.module == nil and r.want == nil, "§2 sortie pleine : rien")
  r = Roi.choose(mc({ state = Roi.S_STOP }))
  check(r.module == nil and r.want == nil, "§2 arret : rien")
  r = Roi.choose(mc({ filled = 2 }))
  check(r.module == nil and r.want == nil, "§2 emplacements pleins : rien")
  r = Roi.choose(mc({ allowed = { speed = true, consumption = true } }))
  check(r.family == Roi.SPEED, "§2 productivite non permise par la machine : vitesse")
  r = Roi.choose(mc({ cands = mods(10, 1) }))
  check(r.family == Roi.PROD and r.n == 1, "§2 pose partielle : 1 module au stock pour 2 emplacements")
  r = Roi.choose(mc({ cands = mods(10, 0) }))
  check(r.family == Roi.PROD and r.module == nil and r.want and r.want.module == "p" and r.want.n == 2, "§2 famille decidee avant le stock : souhait de productivite")
  local gain = 10 * (10 * (96 * 120 - 10000) / 10000 - 9 * (96 - 100) / 100)
  check(r.want and math.abs(r.want.gain - gain) < 1e-9 and math.abs(r.want.payback - 2 * 300 / gain) < 1e-9, "§2 retour = cout des modules / gain par minute")
  local l = mods(10, 0)
  l[2].craftable = nil
  r = Roi.choose(mc({ cands = l }))
  check(r.family == Roi.PROD and r.want == nil, "§2 module non fabricable : aucun souhait")
  -- deux modules de productivité : le meilleur au stock ; souhait : le retour le plus court
  local two = mods(0, 3, { { name = "p2", eff = { productivity = 15, speed = -5, consumption = 9 }, limit = { cher = true }, have = 3, cost = 2000, craftable = true } })
  r = Roi.choose(mc({ cands = two }))
  check(r.module == "p2", "§2 au stock : le module de plus grand gain")
  two[2].have, two[3].have = 0, 0
  r = Roi.choose(mc({ cands = two }))
  check(r.want and r.want.module == "p", "§2 souhait : le retour le plus court (le module cher attend)")
  -- valeurs non lues : la limitation des données décide
  r = Roi.choose(mc({ v_out = false and 0 or nil }))
  check(r.family == Roi.PROD, "§2 valeurs non lues, recette admise : productivite")
  r = Roi.choose(mc({ v_out = nil, recipe = "autre" }))
  check(r.family == Roi.SPEED, "§2 valeurs non lues, recette hors limitation : vitesse")
  -- ordre de la liste indifférent
  local a = Roi.choose(mc())
  local rev = mods(10, 10)
  rev[1], rev[2] = rev[2], rev[1]
  local b = Roi.choose(mc({ cands = rev }))
  check(a.module == b.module and a.n == b.n and a.gain == b.gain, "§2 ordre des modules indifferent")
end

---------------------------------------------------------------------------------------------------
-- §3 Roi.plan (données du relevé de test)
---------------------------------------------------------------------------------------------------
local function units(n, base)
  local u = {}
  for i = 1, n do u[i] = { x = 10 + i * 4, y = 10, u = (base or 1000) + i } end
  return u
end
local RUN = { sampled = 3, working = 3 }
local NECK = { sampled = 3, working = 3, loads = 3, bott = 3 }
local IN = { sampled = 3, working = 0, short_in = 3, stop = "item_ingredient_shortage" }
local OUT = { sampled = 3, working = 0, full = 3, stop = "full_output" }
local function group(entity, recipe, n, run, over)
  local g = { entity = entity, recipe = recipe, n = n, where = "qg", units = units(n), run = run }
  if run == IN then g.units, g.units_in = {}, units(n) end
  for k, x in pairs(over or {}) do g[k] = x end
  return g
end
local function view(over)
  local v = { stock = { [SP] = 50, [PR] = 50 }, committed = {}, machines = { group(AM2, "electronic-circuit", 3, RUN) }, drills = {},
    short = {}, supply = function() return true end, taken = {}, power_room_kw = 100000,
    made = function() return true end, craftable = function() return true end }
  for k, x in pairs(over or {}) do v[k] = x end
  return v
end
local function text(orders, refus, wants)
  local t = {}
  for _, o in ipairs(orders) do t[#t + 1] = string.format("O|%s|%s|n%d|per%d|%s|%.6f|%.6f", o.key, o.module, o.n, o.per, o.family, o.d_out, o.d_kw) end
  for _, o in ipairs(wants or {}) do t[#t + 1] = string.format("W|%s|%s|n%d|per%d|%.6f", o.key, o.module, o.n, o.per, o.payback) end
  for _, r in ipairs(refus) do t[#t + 1] = "R|" .. r.key .. "|" .. tostring(r.module) .. "|" .. r.why end
  return table.concat(t, "\n")
end
local function plan(v, RoiX, D) return (RoiX or Roi).plan(Ca, D or D0, v) end

do
  local o, r, info, w = plan(view())
  check(#o == 1 and o[1].module == PR and o[1].family == Roi.PROD and o[1].n == 3 and o[1].per == 2 and o[1].stock == true and #w == 0,
    "§3 circuits qui tournent : productivite depuis le stock, 3 machines x 2")
  check(o[1].kind == "equiper" and o[1].entity == AM2 and o[1].d_item == "electronic-circuit" and o[1].d_out > 0 and type(o[1].why) == "string",
    "§3 meme forme d'ordre que la disposition du stock")
  o = plan(view({ machines = { group(AM2, "electronic-circuit", 3, NECK) } }))
  check(#o == 1 and o[1].module == SP and o[1].family == Roi.SPEED, "§3 circuits en goulot : vitesse")
  o = plan(view({ machines = { group(AM2, "pipe", 3, RUN) } }))
  check(#o == 1 and o[1].module == SP, "§3 recette hors limitation : vitesse")
  -- sans réserve et pose partielle : 3 modules au coffre, tous posés (l'ancienne règle en gardait 4 et exigeait une machine entière)
  o, r, info = plan(view({ stock = { [PR] = 3 } }))
  check(#o == 1 and o[1].n == 1 and o[1].per == 2 and info.avail[PR] == 3, "§3 3 modules, aucune reserve : une machine x 2")
  local oms = Ms.plan(Ca, D0, view({ stock = { [PR] = 3 } }))
  check(#oms == 0, "§3 ... l'ancienne regle ne posait rien (reserve de 4)")
  o = plan(view({ stock = { [PR] = 1 } }))
  check(#o == 1 and o[1].n == 1 and o[1].per == 1, "§3 1 module : pose partielle (1 sur 2 emplacements)")
  o = plan(view({ stock = { [PR] = 50 }, committed = { [PR] = 49 } }))
  check(#o == 1 and o[1].per == 1 and o[1].n == 1, "§3 promis aux ordres ouverts retires du stock")
  -- attend ses entrées
  o, r = plan(view({ machines = { group(AM2, "electronic-circuit", 3, IN) } }))
  check(#o == 1 and o[1].module == PR and o[1].n == 3, "§3 attend ses entrees, debit mesure : productivite (l'ancienne regle refusait)")
  o, r = plan(view({ machines = { group(AM2, "electronic-circuit", 3, IN) }, made = function() return false end }))
  check(#o == 0 and r[1] and r[1].why:find("aucun debit mesure", 1, true), "§3 attend ses entrees sans debit mesure : refus (chaine morte)")
  o, r = plan(view({ machines = { group(AM2, "pipe", 3, IN) } }))
  check(#o == 0 and #r == 1, "§3 attend ses entrees, recette hors limitation : refus")
  o, r = plan(view({ machines = { group(AM2, "electronic-circuit", 3, OUT) } }))
  check(#o == 0 and r[1] and r[1].why:find("full_output", 1, true), "§3 sortie pleine : refus avec la cause")
  -- vitesse : l'entrée doit être servie, sauf goulot observé
  o, r = plan(view({ machines = { group(AM2, "pipe", 3, RUN) }, supply = function() return false end }))
  check(#o == 0 and r[1] and r[1].why:find("vitesse inutile", 1, true), "§3 vitesse sans entree servie : refus")
  o = plan(view({ machines = { group(AM2, "pipe", 3, NECK) }, supply = function() return false end }))
  check(#o == 1 and o[1].module == SP, "§3 goulot observe : la vitesse est posee (les entrees sont pleines)")
  -- souhait de fabrication
  local w
  o, r, info, w = plan(view({ stock = {} }))
  check(#o == 0 and #w == 1 and w[1].module == PR and w[1].stock == nil and w[1].payback > 0 and w[1].payback <= Roi.HORIZON_MIN,
    "§3 rien au stock : souhait de fabrication rentable")
  check(w[1].n * w[1].per <= math.max(Roi.WANT_MODULES, w[1].per), "§3 souhait borne en modules")
  o, r, info, w = plan(view({ stock = {}, horizon = 1 }))
  check(#o == 0 and #w == 0 and r[1] and r[1].why:find("retour", 1, true), "§3 retour au-dela de l'horizon : refus ecrit")
  o, r, info, w = plan(view({ stock = {}, craftable = function() return false end }))
  check(#o == 0 and #w == 0, "§3 module non fabricable : aucun souhait")
  o, r, info, w = plan(view({ stock = {}, max_wants = 0 }))
  check(#w == 0, "§3 max_wants = 0 : aucun souhait")
  o, r, info, w = plan(view({ stock = {}, machines = { group(AM2, "electronic-circuit", 3, IN) } }))
  check(#o == 0 and #w == 0, "§3 attend ses entrees : jamais de souhait de fabrication")
  o, r, info, w = plan(view({ stock = {}, machines = { group(AM2, "electronic-circuit", 3, RUN), group(AM2, "copper-cable", 3, RUN) } }))
  check(#w == 1 and w[1].recipe == "electronic-circuit", "§3 un souhait par passe : le retour le plus court")
  -- repli sur le stock : la famille choisie n'est ni au coffre ni rentable à fabriquer
  o, r, info, w = plan(view({ stock = { [SP] = 10 }, horizon = 1 }))
  check(#o == 1 and o[1].module == SP and o[1].why:find("repli sur le stock", 1, true) and #w == 0, "§3 repli sur le stock : la vitesse qui dort est posee")
  o, r, info, w = plan(view({ stock = { [SP] = 10 } }))
  check(#o == 0 and #w == 1 and w[1].module == PR, "§3 fabrication rentable : la vitesse attend, la productivite est demandee")
  -- foreuse
  local dg = { entity = FOR, resource = "iron-ore", n = 2, deposit = nil, units = units(2, 2000), run = { sampled = 2, working = 2 } }
  o = plan(view({ machines = {}, drills = { dg } }))
  check(#o == 1 and o[1].resource == "iron-ore" and o[1].n == 2, "§3 foreuse qui tourne : equipee")
  -- bornes : ordres par passe, machines par ordre, courant
  local many = {}
  for i, rc in ipairs({ "electronic-circuit", "copper-cable", "iron-gear-wheel", "automation-science-pack", "pipe" }) do many[i] = group(AM2, rc, 20, RUN) end
  o = plan(view({ stock = { [SP] = 500, [PR] = 500 }, machines = many }))
  check(#o == Ms.MAX_ORDERS, "§3 borne : ordres par passe")
  local okb = true
  for _, x in ipairs(o) do if x.n > Ms.BATCH_MAX then okb = false end end
  check(okb, "§3 borne : machines par ordre")
  o, r = plan(view({ power_room_kw = 0 }))
  check(#o == 0 and r[1] and r[1].why:find("courant insuffisant", 1, true), "§3 courant insuffisant : refus")
  o = plan(view({ taken = { [Ms.key(view().machines[1], false, "qg")] = true } }))
  check(#o == 0, "§3 cle deja ouverte : rien")
  o, r = plan(view({ held = function() return "repli : essai" end }))
  check(#o == 0 and r[1] and r[1].why == "repli : essai", "§3 cle en repli : refus")
  -- stock partagé entre ordres : jamais plus que le stock
  o = plan(view({ stock = { [PR] = 7 }, machines = many }))
  local used = 0
  for _, x in ipairs(o) do used = used + x.n * x.per end
  check(used <= 7 and used >= 6, "§3 le total pose ne depasse pas le stock (" .. used .. ")")
  -- déterminisme : ordre des groupes inversé, deux passes
  local rev = {}
  for i = #many, 1, -1 do rev[#rev + 1] = many[i] end
  local t1 = text(plan(view({ stock = { [SP] = 30, [PR] = 9 }, machines = many })))
  local t2 = text(plan(view({ stock = { [SP] = 30, [PR] = 9 }, machines = rev })))
  local t3 = text(plan(view({ stock = { [SP] = 30, [PR] = 9 }, machines = many })))
  check(t1 == t2 and t1 == t3 and #t1 > 0, "§3 determinisme : ordre des groupes indifferent, deux passes identiques")
end

-- données changées : tous les noms renommés, mêmes décisions aux noms près
do
  local d0 = C.dump()
  local map = C.name_map(d0)
  local d2 = C.rename(d0, map)
  local exec2 = {}
  for _, k in ipairs(C.sorted_keys(C.EXEC)) do exec2[map[k]] = true end
  local Db = Ca.data(d2, { exec = exec2, exec_roles = C.ROLES })
  local function nm(x) return map[x] end
  local function both(st, stock, rc)
    local s2 = {}
    for _, k in ipairs(C.sorted_keys(stock)) do s2[nm(k)] = stock[k] end
    local o1, _, _, w1 = plan(view({ stock = stock, machines = { group(AM2, rc, 3, st) } }))
    local o2, _, _, w2 = plan(view({ stock = s2, machines = { group(nm(AM2), nm(rc), 3, st) } }), nil, Db)
    local a, b = o1[1] or w1[1], o2[1] or w2[1]
    if not a or not b then return a == nil and b == nil, a ~= nil end
    return nm(a.module) == b.module and a.n == b.n and a.per == b.per and a.family == b.family and a.stock == b.stock
      and math.abs(a.d_out - b.d_out) < 1e-9, true
  end
  local same, some = true, 0
  for _, st in ipairs({ RUN, NECK, IN }) do
    for _, rc in ipairs({ "electronic-circuit", "pipe", "copper-cable" }) do
      for _, stock in ipairs({ { [SP] = 50, [PR] = 50 }, {}, { [SP] = 5 } }) do
        local ok, any = both(st, stock, rc)
        if not ok then same = false end
        if any then some = some + 1 end
      end
    end
  end
  check(same and some >= 10, "§3 donnees renommees (tous les noms) : memes decisions aux noms pres (" .. some .. " cas)")
end

---------------------------------------------------------------------------------------------------
-- §4 runtime (tables simples)
---------------------------------------------------------------------------------------------------
local RT = require("script.ai3.modules_stock")
local Pi = require("shared.ai3.pile")
local logged = {}
log = function(s) logged[#logged + 1] = s end
local function lines(pat)
  local n = 0
  for _, l in ipairs(logged) do if l:find(pat, 1, true) then n = n + 1 end end
  return n
end
local function team()
  return { key = "azure", started = 0, team = { ia3 = { short = {}, pile = { hold = false, top = Pi.AMELIORER } } } }
end
local function plain(entity, recipe, n) return { entity = entity, recipe = recipe, n = n, where = "qg", units = units(n) } end
local function cstate(machines)
  return { open = {}, scan = { tick = 600, machines = machines or { plain(AM2, "electronic-circuit", 3) }, drills = {} }, deps = {},
    flows = { ["electronic-circuit"] = { made = 5 } }, orders = 0, stats = {} }
end
local function ctx(counts, extra)
  counts["copper-plate"], counts["iron-plate"], counts["copper-cable"] = 1000, 1000, 1000
  local c = { Ca = Ca, D = D0, minutes = function(_, t) return t / 3600 end, held = function() return nil end,
    count = function(item) return counts[item] or 0 end, power = function() return { have_kw = 100000, used_kw = 0 } end, threat = false,
    counts = counts, craftable = function() return true end, status = function() return "working" end }
  for k, x in pairs(extra or {}) do c[k] = x end
  return c
end
check(RT.ROI == true, "§4 la passe ROI est le comportement par defaut")
do
  logged = {}
  local f, cs, c = team(), cstate(), ctx({ [PR] = 3 })
  check(RT.think(f, cs, 600, c) == 1 and #cs.open == 1, "§4 3 modules au coffre : un ordre de stock (aucune reserve)")
  local rec = cs.open[1]
  check(rec.stock == true and rec.module == PR and rec.per == 2 and #rec.targets == 1 and rec.exec == "equiper", "§4 ordre de stock : 1 machine x 2")
  check(lines("[FO-MODULES] azure : ordre equiper:") == 1, "§4 journal : une ligne d'ordre")
  for _, x in pairs(rec) do check(type(x) ~= "function", "§4 aucune fonction dans l'ordre") end
  check(rec.units == nil, "§4 l'ordre garde ses cibles, pas le releve")
end
do
  -- machine qui attend ses entrées : cibles = les unités en attente
  logged = {}
  local f, cs = team(), cstate()
  local c = ctx({ [PR] = 10 }, { status = function() return "item_ingredient_shortage" end })
  check(RT.think(f, cs, 600, c) == 1 and cs.open[1].module == PR and #cs.open[1].targets == 3, "§4 attend ses entrees : productivite posee sur les 3 machines")
  local f2, cs2 = team(), cstate()
  cs2.flows = {}
  local c2 = ctx({ [PR] = 10 }, { status = function() return "item_ingredient_shortage" end })
  c2.counts["electronic-circuit"] = 0
  check(RT.think(f2, cs2, 600, c2) == 0, "§4 attend ses entrees, aucun debit mesure : rien")
  local f3, cs3 = team(), cstate()
  check(RT.think(f3, cs3, 600, ctx({ [PR] = 10 }, { status = function() return "full_output" end })) == 0, "§4 sortie pleine : rien")
  -- goulot observé par la charge
  local f4, cs4 = team(), cstate()
  local c4 = ctx({ [PR] = 10, [SP] = 10 }, { status = function() return "working", { in_full = true, out_empty = true } end })
  check(RT.think(f4, cs4, 600, c4) == 1 and cs4.open[1].module == SP, "§4 goulot observe (entrees pleines, sortie vide) : vitesse")
  local f5, cs5 = team(), cstate()
  local c5 = ctx({ [PR] = 10, [SP] = 10 }, { status = function() return "working", { in_full = true, out_empty = false } end })
  check(RT.think(f5, cs5, 600, c5) == 1 and cs5.open[1].module == PR, "§4 la sortie s'accumule : pas un goulot, productivite")
end
do
  -- coffre vide : ordre de fabrication, un seul ouvert, manque gardé
  logged = {}
  local f, cs, c = team(), cstate({ plain(AM2, "electronic-circuit", 3), plain(AM2, "copper-cable", 3) }), ctx({})
  check(RT.think(f, cs, 600, c) == 1 and #cs.open == 1, "§4 coffre vide, module fabricable : un ordre de fabrication")
  local rec = cs.open[1]
  check(rec.stock == nil and rec.exec == "equiper" and rec.module == PR and rec.n_left == #rec.targets and #rec.targets >= 1, "§4 ordre de fabrication (non 'stock')")
  check(lines("fabrication :") == 1, "§4 journal : la ligne dit 'fabrication'")
  rec.missing = { { PR, 4 } }
  cs.scan.tick = 4200
  check(RT.think(f, cs, 4200, c) == 0 and #cs.open == 1, "§4 un seul ordre de fabrication ouvert a la fois")
  check(#rec.missing == 1, "§4 le manque d'un ordre de fabrication est garde (le cerveau fabrique)")
  -- les modules arrivent : promis à l'ordre de fabrication, pas reposés ailleurs
  c.counts[PR] = rec.n_left * rec.per
  cs.scan.tick = 7800
  check(RT.think(f, cs, 7800, c) == 0 and #cs.open == 1, "§4 modules livres : promis a l'ordre ouvert, aucun doublon")
  -- non fabricable : silence
  logged = {}
  local f2, cs2 = team(), cstate()
  check(RT.think(f2, cs2, 600, ctx({}, { craftable = function() return false end })) == 0 and #logged == 0, "§4 coffre vide, rien de fabricable : silence")
  local f3, cs3 = team(), cstate()
  local c3 = ctx({})
  c3.craftable = nil
  check(RT.think(f3, cs3, 600, c3) == 0, "§4 sans lecture des recettes : aucun ordre de fabrication")
  -- pile survivre
  local f4, cs4 = team(), cstate()
  f4.team.ia3.pile = { hold = true, top = Pi.SURVIVRE }
  check(RT.think(f4, cs4, 600, ctx({ [PR] = 10 })) == 0 and #cs4.open == 0, "§4 pile survivre : rien")
end

---------------------------------------------------------------------------------------------------
-- §5 mutants ; aucun nom du jeu dans la règle
---------------------------------------------------------------------------------------------------
local fh = assert(io.open("shared/ai3/modules_roi.lua", "rb"))
local SRC = fh:read("*a")
fh:close()
local function mutant(old, new)
  local i, j = SRC:find(old, 1, true)
  if not i then return nil end
  local src = SRC:sub(1, i - 1) .. new .. SRC:sub(j + 1)
  return assert(load(src, "@modules_roi_mutant"))()
end
local function fingerprint(R)
  local t = {}
  local function add(v, D) t[#t + 1] = text(plan(v, R, D)) local _, _, _, w = plan(v, R, D) t[#t + 1] = text({}, {}, w) end
  for _, st in ipairs({ Roi.S_RUN, Roi.S_NECK, Roi.S_IN }) do
    local r1 = R.choose(mc({ state = st, allowed = { speed = true, consumption = true } }))
    local r2 = R.choose(mc({ state = st, cands = mods(10, 1) }))
    t[#t + 1] = table.concat({ tostring(r1.family), tostring(r1.module), tostring(r2.module), tostring(r2.n) }, "|")
  end
  add(view())
  add(view({ stock = { [PR] = 1 } }))
  add(view({ machines = { group(AM2, "electronic-circuit", 3, NECK) } }))
  add(view({ machines = { group(AM2, "electronic-circuit", 3, IN) } }))
  add(view({ machines = { group(AM2, "electronic-circuit", 3, IN) }, made = function() return false end }))
  add(view({ machines = { group(AM2, "electronic-circuit", 3, IN) }, stock = {} }))
  add(view({ machines = { group(AM2, "electronic-circuit", 3, OUT) } }))
  add(view({ machines = { group(AM2, "pipe", 3, RUN) } }))
  add(view({ machines = { group(AM2, "pipe", 3, IN) }, stock = { [SP] = 9 } }))
  add(view({ machines = { group(AM2, "pipe", 3, RUN) }, supply = function() return false end }))
  add(view({ machines = { group(FOUR, "iron-plate", 3, RUN) } }))
  add(view({ stock = { [PR] = 3 } }))
  add(view({ stock = {} }))
  add(view({ stock = {}, horizon = 1 }))
  add(view({ stock = { [SP] = 10 }, horizon = 1 }))
  add(view({ stock = {}, craftable = function() return false end }))
  add(view({ stock = {}, machines = { group(AM2, "electronic-circuit", 3, RUN), group(AM2, "copper-cable", 3, RUN) } }))
  add(view({ stock = {}, machines = { group(AM2, "electronic-circuit", 20, RUN) } }))
  add(view({ power_room_kw = 0 }))
  add(view({ stock = { [PR] = 7 }, machines = { group(AM2, "electronic-circuit", 20, RUN), group(AM2, "copper-cable", 20, RUN) } }))
  add(view({ stock = { [PR] = 500 }, machines = { group(AM2, "electronic-circuit", 20, RUN) } }))
  add(view({ threat = true, machines = { group(AM2, "electronic-circuit", 3, RUN, { where = "loin" }) } }))
  add(view({ taken = { [Ms.key(view().machines[1], false, "qg")] = true } }))
  add(view({ held = function() return "repli" end }))
  return table.concat(t, "\n--\n")
end
local base_fp = fingerprint(Roi)
check(base_fp == fingerprint(Roi), "§5 empreinte stable")
local n_mut, n_caught = 0, 0
local function M(name, old, new)
  n_mut = n_mut + 1
  local R = mutant(old, new)
  if not R then
    if not quiet then print("[S42-MODULES-ROI] mutant introuvable : " .. name) end
    return
  end
  local ok, fp = pcall(fingerprint, R)
  if not ok or fp ~= base_fp then n_caught = n_caught + 1
  elseif not quiet then print("[S42-MODULES-ROI] mutant NON refuse : " .. name) end
end
M("entrees payees ignorees (toujours la sortie brute)", "- v_in * (s1 - s0) / 100)", ")")
M("goulot traite comme 'tourne'", "if state == Roi.S_NECK then return c * v_out * (s1 * p1 - s0 * p0) / 10000 end", "")
M("attente d'entrees : vitesse admise", "if state == Roi.S_IN then\n    if not any_prod then", "if false then\n    if not any_prod then")
M("limitation ignoree", "if recipe and m.limit and not m.limit[recipe] then return false end", "")
M("effet non permis ignore", "if (allowed or {})[k] ~= true then return false end", "")
M("sortie pleine equipee", "if state == Roi.S_OUT or state == Roi.S_STOP then\n      refuse(", "if false then\n      refuse(")
M("chaine morte equipee", "if not (v.made and v.made(item)) then", "if false then")
M("pose partielle retiree", "local o = eval(m, math.min(free, math.floor(m.have)))", "local o = eval(m, free)")
M("souhait sans horizon", "elseif state ~= Roi.S_IN and sel.payback <= horizon then", "elseif state ~= Roi.S_IN then")
M("souhait pour une machine qui attend ses entrees", "elseif state ~= Roi.S_IN and sel.payback <= horizon then", "elseif sel.payback <= horizon then")
M("module non fabricable souhaite", "if o.fam == family and o.m.craftable and", "if o.fam == family and")
M("souhaits non bornes", "if #out_w >= (v.max_wants or Roi.MAX_WANTS) then break end", "")
M("souhait non borne en modules", "math.max(1, math.floor((v.want_modules or Roi.WANT_MODULES) / o.per))", "o.nunits")
M("repli sur le stock retire", "if alt.module then", "if false then")
M("vitesse sans entree servie", "if not ing.fluid and not served(ing.name) then\n          refuse(", "if false then\n          refuse(")
M("courant ignore", "if k < 1 then return 0, \"courant insuffisant", "if false then return 0, \"courant insuffisant")
M("modules non decomptes entre ordres", "avail[o.nm] = avail[o.nm] - k * o.per", "")
M("machines par ordre non bornees", "local k = math.min(o.nunits, Ms.BATCH_MAX, math.floor(avail[o.nm] / o.per))", "local k = math.min(o.nunits, math.floor(avail[o.nm] / o.per))")
M("menace ignoree", "if v.threat then refuse(key, nil, \"menace : machines du QG seulement\") return end", "")
M("cle deja ouverte ignoree", "if taken[key] then return end", "")
M("repli ignore", "if held then refuse(key, nil, held) return end", "")
M("reserve remise", "Roi.RESERVE = 0", "Roi.RESERVE = 4")
check(n_caught == n_mut, string.format("§5 mutants : %d refuses sur %d", n_caught, n_mut))

-- aucun nom du jeu entre guillemets dans la règle (les noms des données de test : modules, recettes, machines)
do
  local names = {}
  for _, nm in ipairs(D0.lv.cand) do names[#names + 1] = nm end
  for _, rn in ipairs(D0.recipe_list or {}) do names[#names + 1] = rn end
  for _, e in ipairs(C.sorted_keys(D0.lv.slots)) do names[#names + 1] = e end
  local hits = 0
  for _, nm in ipairs(names) do
    if SRC:find('"' .. nm .. '"', 1, true) then hits = hits + 1 end
  end
  check(#names > 10 and hits == 0, "§5 aucun nom de module, de recette ni de machine dans la regle (" .. hits .. ")")
end

print(string.format("[S42-MODULES-ROI] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refuses sur %d)", pass, fail, n_caught, n_mut))
os.exit(fail == 0 and 0 or 1)
