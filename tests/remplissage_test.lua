--[[
  Lot REMPLISSAGE : cible de remplissage des quais selon l'abondance du stock. Banc HORS JEU.
  Lancement, depuis la racine du mod : lua5.2 tests/remplissage_test.lua
    1. règle pure (shared/team/remplissage.lua) : stock juste = règle d'avant ; stock abondant = coffre jusqu'à sa capacité réelle,
       part du quai, seuil de relance proportionnel, hystérésis, plein chargement borné par le sac, journal ;
    2. partage : la somme des cibles de tous les quais d'un objet ne dépasse jamais la part du stock ;
    3. colle (script/team/remplissage_glue.lua) sur un moteur de bouchons : relevé du besoin sans doublon de quai, barre du coffre,
       journal [FO-REMPLISSAGE], sac, stock juste = verdict ordinaire inchangé ;
    4. câblage dans build.lua et anti-échelle (aucun nom d'objet) ;
    5. bilan avant / après sur l'exemple de la partie du DC (modèle, imprimé) ;
    6. mutants refusés.
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end
local function read(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end

local Rm = require("shared.team.remplissage")

print("[REMPLISSAGE] 1. regle pure")
do
  -- stock juste : la regle d'avant, a l'identique
  local l = Rm.level({ base_want = 400, base_low = 60, cap = 4800, stock = 3000, need = 12000, nq = 30 })
  check(l.cause == "juste" and l.want == 400 and l.low == 60, "stock juste : 400 / 60")
  -- stock abondant (150 000 pour 30 quais de 400 : 12 000 de besoin)
  l = Rm.level({ base_want = 400, base_low = 60, cap = 4800, stock = 150000, need = 12000, nq = 30 })
  check(l.cause == "abondant", "150 000 pour un besoin de 12 000 : abondant")
  check(l.want == 3500, "cible = 70 % du stock / 30 quais = 3500 (capacite 4800) : " .. tostring(l.want))
  check(l.low == 1400 and l.low > 60, "relance a 40 % de la cible, jamais 60 sur un gros coffre : " .. tostring(l.low))
  -- capacite reelle plus petite (barre) : la cible suit le coffre, pas le stock
  l = Rm.level({ base_want = 400, base_low = 60, cap = 1200, stock = 150000, need = 12000, nq = 30 })
  check(l.want == 1200 and l.cause == "abondant", "coffre sous barre de 1200 : cible 1200")
  -- capacite sous la cible ordinaire : la regle d'avant (jamais en dessous)
  l = Rm.level({ base_want = 400, base_low = 60, cap = 300, stock = 150000, need = 12000, nq = 30 })
  check(l.cause == "juste" and l.want == 400, "coffre plus petit que la cible ordinaire : regle d'avant")
  -- capacite inconnue ou nulle
  l = Rm.level({ base_want = 400, base_low = 60, cap = 0, stock = 150000, need = 12000, nq = 30 })
  check(l.cause == "juste", "coffre sans place : juste")
  -- hysteresis : 3 x le besoin n'est pas abondant en entrant, l'est en restant ; 1,5 x ne l'est plus
  local a = { base_want = 400, base_low = 60, cap = 4800, stock = 36000, need = 12000, nq = 30 }
  check(Rm.level(a).cause ~= "abondant", "3 x le besoin : pas abondant en entrant")
  a.was = true
  check(Rm.level(a).cause == "abondant", "3 x le besoin : abondant quand on l'etait deja")
  a.stock = 18000
  check(Rm.level(a).cause ~= "abondant", "1,5 x le besoin : plus abondant")
  -- part trop petite : rien ne change
  l = Rm.level({ base_want = 400, base_low = 60, cap = 4800, stock = 1700, need = 400, nq = 6 })
  check(l.cause == "juste" and l.want == 400, "part de 198 < 400 : regle d'avant")
  -- entrees degenerees
  l = Rm.level({})
  check(l.cause == "juste" and l.want == 1 and l.low == 1, "entree vide : rien d'absurde")
  l = Rm.level({ base_want = 400, base_low = 60, cap = 4800, stock = 0/0, need = 0, nq = 0 })
  check(l.cause == "juste", "NaN : juste")
  -- plein chargement
  local r = Rm.refill(3500, 1400, 100, 90000, 7600)
  check(r.due and r.count == 3400, "coffre a 100, cible 3500 : 3400 objets (sac de 7600)")
  r = Rm.refill(3500, 1400, 100, 90000, 1500)
  check(r.due and r.count == 1500, "sac de 1500 : un plein chargement, pas plus (la prise stricte echouerait)")
  r = Rm.refill(3500, 1400, 100, 800, 7600)
  check(r.due and r.count == 800, "borne au stock")
  r = Rm.refill(3500, 1400, 1500, 90000, 7600)
  check(not r.due and r.count == 0, "au-dessus de la relance : rien")
  r = Rm.refill(3500, 1400, 100, 0, 7600)
  check(not r.due, "stock vide : rien")
  -- journal
  check(Rm.changed(nil, { cause = "abondant", want = 3500 }), "premiere fois abondant : ligne")
  check(not Rm.changed(nil, { cause = "juste", want = 400 }), "premiere fois juste : silence")
  check(Rm.changed({ cible = 400, cause = "juste" }, { cause = "abondant", want = 3500 }), "juste -> abondant : ligne")
  check(Rm.changed({ cible = 3500, cause = "abondant" }, { cause = "juste", want = 400 }), "abondant -> juste : ligne")
  check(not Rm.changed({ cible = 3500, cause = "abondant" }, { cause = "abondant", want = 3400 }), "bouge de 3 % : silence")
  check(Rm.changed({ cible = 3500, cause = "abondant" }, { cause = "abondant", want = 2500 }), "bouge de 29 % : ligne")
  check(not Rm.changed({ cible = 400, cause = "juste" }, { cause = "juste", want = 900 }), "juste -> juste : silence")
end

print("[REMPLISSAGE] 2. partage")
do
  for _, nq in ipairs({ 1, 2, 7, 30, 59 }) do
    for _, stock in ipairs({ 1000, 9999, 77684, 150000 }) do
      local tot = 0
      for _ = 1, nq do
        local l = Rm.level({ base_want = 400, base_low = 60, cap = 4800, stock = stock, need = 400 * nq, nq = nq, was = true })
        tot = tot + l.want
        if l.cause == "juste" then tot = tot - l.want elseif l.cause == "proportionnel" then tot = tot - 400 end -- s45 : part du stock LIBRE au-dessus de la cible ordinaire -- cible ordinaire : deja dans le besoin, pas une part de plus
      end
      check(tot <= stock * Rm.SHARE_PM / 1000, string.format("somme des cibles hautes <= part du stock (nq %d, stock %d : %d)", nq, stock, tot))
    end
  end
  check(Rm.share(150000, 30) == 3500 and Rm.share(100, 0) == 70, "share : entiers, nq >= 1")
  local s, n = Rm.need({ 400, 90, 400.7 })
  check(s == 890 and n == 3, "need : somme entiere et nombre")
end

-- moteur de bouchons pour la colle
local function make_world(opts)
  opts = opts or {}
  _G.game = {
    tick = opts.tick or 1000,
    entity_prototypes = { character = { get_inventory_size = function() return 80 end } },
    item_prototypes = { thing = { stack_size = 100 }, other = { stack_size = 50 } },
    forces = { f1 = { character_inventory_slots_bonus = opts.bonus or 0 } },
  }
  _G.defines = { inventory = { chest = 1, character_main = 2 } }
  local lines = {}
  _G.log = function(s) lines[#lines + 1] = s end
  return lines
end
local function mk_chest(n, room)
  local c = { n = n }
  c.get_inventory = function()
    return { get_insertable_count = function() return room end }
  end
  return c
end

print("[REMPLISSAGE] 3. colle")
do
  local lines = make_world()
  package.loaded["script.team.remplissage_glue"] = nil
  local G = require("script.team.remplissage_glue")
  local function quais(n, dup)
    local qs = {}
    for k = 1, n do qs[#qs + 1] = { x = k * 3 + 0.5, y = 10.5, item = "thing" } end
    if dup then for k = 1, n do qs[#qs + 1] = { x = k * 3 + 0.5, y = 10.5, item = "thing" } end end
    return qs
  end
  local function world(nq, dup)
    return { key = "f1", force = "f1", stats = {},
      build = { order = { 1, 2 }, projects = { [1] = { id = 1, quais = quais(nq, dup) }, [2] = { id = 2, quais = {} } } } }
  end
  local f = world(30, true) -- 30 quais, chacun note DEUX FOIS (reessai de plan) : compte 30, pas 60
  local p = f.build.projects[1]
  local q = p.quais[1]
  local rord = { due = false, count = 0 }
  -- stock abondant, coffre presque vide : plein chargement borne par le sac
  local r = G.adjust(f, p, 1, q, mk_chest(10, 4790), 10, 150000, nil, rord, 60, 400)
  check(r.due and r.count == 3490, "abondant : 3500 - 10 = 3490 (un sac de 7600) : " .. tostring(r.count))
  check(q.rempl and q.rempl.cause == "abondant" and q.rempl.cible == 3500, "etat du quai : cible 3500 abondant (quais comptes sans doublon)")
  check(#lines == 1 and lines[1]:find("%[FO%-REMPLISSAGE%]") and lines[1]:find("stock abondant") and lines[1]:find("cible 0 %-> 3500"), "journal : une ligne de changement : " .. tostring(lines[1]))
  r = G.adjust(f, p, 1, q, mk_chest(10, 4790), 10, 150000, nil, rord, 60, 400)
  check(#lines == 1, "meme etat : pas de seconde ligne")
  -- sac petit (quand la recherche n'a rien donne et que le corps tient peu) : plein chargement = ce que le sac tient
  make_world({ tick = 2000 }); _G.game.entity_prototypes.character.get_inventory_size = function() return 14 end
  f = world(30, false); p = f.build.projects[1]; q = p.quais[1]
  r = G.adjust(f, p, 1, q, mk_chest(10, 4790), 10, 150000, nil, rord, 60, 400)
  check(r.due and r.count == (14 - Rm.BAG_RESERVE) * 100, "sac de 14 cases : (14 - reserve) x pile = 1000 : " .. tostring(r.count))
  -- barre du coffre : place restante 600 -> cible 610
  make_world({ tick = 3000 }); f = world(30, false); p = f.build.projects[1]; q = p.quais[1]
  r = G.adjust(f, p, 1, q, mk_chest(10, 600), 10, 150000, nil, rord, 60, 400)
  check(q.rempl.cible == 610 and r.count == 600, "barre : cible = contenu + place restante (610), compte 600 : " .. tostring(q.rempl.cible) .. "/" .. tostring(r.count))
  -- stock juste : le verdict ordinaire est rendu tel quel (meme table)
  make_world({ tick = 4000 }); f = world(30, false); p = f.build.projects[1]; q = p.quais[1]
  local ord = { due = true, count = 340 }
  r = G.adjust(f, p, 1, q, mk_chest(50, 4750), 50, 3000, nil, ord, 60, 400)
  check(r == ord, "stock juste : verdict ordinaire inchange")
  check(q.rempl.cause == "juste", "etat : juste")
  -- quota sous forme de minute d'ingredients : la cible ordinaire vient du quota
  make_world({ tick = 5000 }); f = world(30, false); p = f.build.projects[1]; q = p.quais[1]
  local qta = { ins = { [1] = { item = "thing", want = 90, low = 45 } } }
  r = G.adjust(f, p, 1, q, mk_chest(10, 4790), 10, 150000, qta, { due = false, count = 0 }, 60, 400)
  check(q.rw == 90 and r.due, "sous quota : cible ordinaire 90 (q.rw), stock abondant : coffre plein")
  -- relevé mis en cache 300 ticks, refait ensuite
  local c1 = f.build.rempl_cache
  G.adjust(f, p, 1, q, mk_chest(10, 4790), 10, 150000, qta, { due = false, count = 0 }, 60, 400)
  check(f.build.rempl_cache == c1, "releve en cache")
  _G.game.tick = 5000 + G.CACHE_TICKS
  G.adjust(f, p, 1, q, mk_chest(10, 4790), 10, 150000, qta, { due = false, count = 0 }, 60, 400)
  check(f.build.rempl_cache ~= c1, "releve refait apres 300 ticks")
  -- sans coffre lisible : verdict ordinaire
  local bad = { get_inventory = function() return nil end }
  ord = { due = true, count = 7 }
  check(G.adjust(f, p, 1, q, bad, 10, 150000, nil, ord, 60, 400) == ord, "coffre sans inventaire : verdict ordinaire")
  -- plafond du journal
  make_world({ tick = 9000 }); f = world(30, false); f.stats.rempl_logs = G.LOGS; p = f.build.projects[1]; q = p.quais[1]
  local lines2 = {}
  _G.log = function(s) lines2[#lines2 + 1] = s end
  G.adjust(f, p, 1, q, mk_chest(10, 4790), 10, 150000, nil, rord, 60, 400)
  check(#lines2 == 0, "journal plafonne par force")
end

print("[REMPLISSAGE] 4. cablage et anti-echelle")
local BUILD = read("script/team/build.lua")
do
  check(BUILD:find('Build.Rempl = require("script.team.remplissage_glue")', 1, true), "build.lua requiert la colle (champ de Build)")
  local a = BUILD:find("local r = Build.Quotas.refill(qta, i, n, have, Build.QUAI_LOW, Build.QUAI_FILL)", 1, true)
  local b = BUILD:find("r = Build.Rempl.adjust(f, p, i, q, chest, n, have, qta, r, Build.QUAI_LOW, Build.QUAI_FILL)", 1, true)
  check(a and b and b > a and b - a < 200, "adjust suit immediatement le verdict ordinaire dans quai_tasks")
  local names = { "iron%-", "copper", "coal", "stone", "steel", "plate", "gear", "wire" }
  for _, path in ipairs({ "shared/team/remplissage.lua", "script/team/remplissage_glue.lua" }) do
    local s = read(path)
    local code = s:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
    for _, nm in ipairs(names) do check(not code:find(nm), path .. " : aucun nom d'objet (" .. nm .. ")") end
    check(not code:find("%f[%w_]pairs%("), path .. " : aucun pairs")
  end
end

print("[REMPLISSAGE] 5. bilan avant / apres (modele, exemple de la partie du DC)")
do
  -- quai d'engrenages a 1,50/s (journal du 8/11 : « quai 15:q2 (iron-gear-wheel, 1.50/s) »), pile 100, coffre de 48 cases ; l'objet est
  -- ici une matiere de pile 100. Stock : cuivre 77 684 chez l'equipe qui en tient le plus (remote.lua du temoin), 20 quais de cet objet
  -- (HYPOTHESE : le nombre exact n'est pas dans les journaux).
  local rate, nq = 1.5, 20
  local old_per_trip, old_low = 400 - 60, 60
  local old_trips = rate * 3600 / old_per_trip
  local l = Rm.level({ base_want = 400, base_low = 60, cap = 4800, stock = 77684, need = 400 * nq, nq = nq })
  local new_per_trip = l.want - l.low
  local new_trips = rate * 3600 / new_per_trip
  print(string.format("  AVANT : relance sous 60, cible 400, %d objets / tournee -> %.1f tournees fill par heure et par quai ; marge avant panne %.0f s",
    old_per_trip, old_trips, old_low / rate))
  print(string.format("  APRES : cible %d, relance sous %d, %d objets / tournee -> %.1f tournees fill par heure et par quai ; marge avant panne %.0f s",
    l.want, l.low, new_per_trip, new_trips, l.low / rate))
  check(l.cause == "abondant" and new_trips < old_trips / 3, "au moins 3 fois moins de tournees")
end

print("[REMPLISSAGE] 6. mutants")
do
  local src = read("shared/team/remplissage.lua")
  local function load_mut(s)
    local fn = assert(load(s, "remplissage_mutant", "t"))
    return fn()
  end
  local function battery(R)
    local bad = 0
    local function ck(c) if not c then bad = bad + 1 end end
    local l = R.level({ base_want = 400, base_low = 60, cap = 4800, stock = 150000, need = 12000, nq = 30 })
    ck(l.cause == "abondant" and l.want == 3500 and l.low == 1400)
    l = R.level({ base_want = 400, base_low = 60, cap = 4800, stock = 3000, need = 12000, nq = 30 })
    ck(l.cause == "juste" and l.want == 400 and l.low == 60)
    l = R.level({ base_want = 400, base_low = 60, cap = 1200, stock = 150000, need = 12000, nq = 30 })
    ck(l.want == 1200)
    l = R.level({ base_want = 400, base_low = 60, cap = 4800, stock = 36000, need = 12000, nq = 30 })
    ck(l.cause ~= "abondant")
    l = R.level({ base_want = 400, base_low = 60, cap = 4800, stock = 36000, need = 12000, nq = 30, was = true })
    ck(l.cause == "abondant")
    l = R.level({ base_want = 400, base_low = 60, cap = 4800, stock = 18000, need = 12000, nq = 30, was = true })
    ck(l.cause ~= "abondant")
    l = R.level({ base_want = 400, base_low = 60, cap = 300, stock = 150000, need = 12000, nq = 30 })
    ck(l.want == 400 and l.cause == "juste")
    local r = R.refill(3500, 1400, 100, 90000, 1500)
    ck(r.count == 1500)
    r = R.refill(3500, 1400, 100, 800, 7600)
    ck(r.count == 800)
    r = R.refill(3500, 1400, 1500, 90000, 7600)
    ck(not r.due)
    r = R.refill(3500, 1400, 100, 0, 7600)
    ck(not r.due)
    ck(R.changed({ cible = 3500, cause = "abondant" }, { cause = "abondant", want = 2500 }))
    ck(not R.changed({ cible = 3500, cause = "abondant" }, { cause = "abondant", want = 3400 }))
    ck(not R.changed({ cible = 400, cause = "juste" }, { cause = "juste", want = 900 }))
    ck(R.share(150000, 30) == 3500)
    return bad
  end
  check(battery(load_mut(src)) == 0, "temoin nul : la batterie passe sur le module intact")
  local function mut(name, from, to)
    local s, n = src:gsub(from, to, 1)
    assert(n == 1, "mutant sans effet : " .. name)
    local ok, R = pcall(load_mut, s)
    local bad = 1
    if ok then local ok2, b = pcall(battery, R); bad = ok2 and b or 1 end
    check(bad > 0, "mutant refuse : " .. name)
  end
  mut("toujours abondant", "if stock < need %* mult then", "if false then")
  mut("jamais d'hysteresis", "local mult = a.was and R.MULT_OUT or R.MULT_IN", "local mult = R.MULT_IN")
  mut("hysteresis inversee", "local mult = a.was and R.MULT_OUT or R.MULT_IN", "local mult = a.was and R.MULT_IN or R.MULT_OUT")
  mut("capacite du coffre ignoree", "min%(floor%(a%.cap%), bound%)", "bound")
  mut("part du stock ignoree", "min%(floor%(a%.cap%), bound%)", "floor(a.cap)")
  mut("part non divisee entre les quais", "/ max%(1, floor%(num%(nq, 1%)%)%)%)", "/ 1)")
  mut("relance restee a la regle d'avant", "low = min%(want %- 1, max%(bl, ceil%(want %* R%.LOW_PM / 1000%)%)%), cause = \"abondant\"", "low = bl, cause = \"abondant\"")
  mut("part sous la cible ordinaire gardee", "if want <= bw then return ([^\n]-) end %-%- part", "if false then return %1 end -- part")
  mut("sac ignore", "if type%(bag%) == \"number\" and bag >= 1 then c = min%(c, floor%(bag%)%) end", "")
  mut("stock ignore au remplissage", "c = min%(want %- n, have%)", "c = want - n")
  mut("relance ignoree", "if n >= low or have <= 0 then", "if have <= 0 then")
  mut("journal a chaque calcul", "return math%.abs%(b %- a%) %* 1000 >= a %* R%.CHANGE_PM", "return true")
  mut("journal du cas ordinaire", "if lvl%.cause == \"juste\" then return false end", "")
  -- colle : mutants sur le texte
  local gsrc = read("script/team/remplissage_glue.lua")
  local function gmut(name, from, to)
    local s, n = gsrc:gsub(from, to, 1)
    assert(n == 1, "mutant de colle sans effet : " .. name)
    make_world({ tick = 7000 })
    package.loaded["script.team.remplissage_glue"] = nil
    local chunk = assert(load(s, "glue_mutant", "t"))
    local G = chunk()
    local f = { key = "f1", force = "f1", stats = {}, build = { order = { 1 }, projects = { [1] = { id = 1, quais = {} } } } }
    for k = 1, 30 do f.build.projects[1].quais[k] = { x = k * 3 + 0.5, y = 10.5, item = "thing" } end
    for k = 1, 30 do f.build.projects[1].quais[30 + k] = { x = k * 3 + 0.5, y = 10.5, item = "thing" } end
    local q = f.build.projects[1].quais[1]
    local r = G.adjust(f, f.build.projects[1], 1, q, mk_chest(10, 600), 10, 150000, nil, { due = false, count = 0 }, 60, 400)
    local ok = r.due and r.count == 600 and q.rempl.cible == 610
    local r2 = G.adjust(f, f.build.projects[1], 1, q, mk_chest(10, 4790), 10, 150000, nil, { due = false, count = 0 }, 60, 400)
    ok = ok and r2.count == 3490 and q.rempl.cible == 3500
    check(not ok, "mutant de colle refuse : " .. name)
  end
  gmut("quais dupliques comptes deux fois", "if q%.item and not seen%[key%] then", "if q.item then")
  gmut("capacite reelle ignoree", "cap = n %+ inv%.get_insertable_count%(q%.item%)", "cap = 4800")
  package.loaded["script.team.remplissage_glue"] = nil
end

print(string.format("[REMPLISSAGE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
