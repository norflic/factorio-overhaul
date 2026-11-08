-- Lot ELECTRIQUE (retour du DC du 8/11, 14 h 30, 0.6.66) : règles pures de shared/team/electrique.lua et leurs mutants.
-- Lancer : lua5.2 tests/electrique_test.lua   (depuis la racine du mod)
package.path = "./?.lua;" .. package.path

local SRC_PATH = "shared/team/electrique.lua"

local function load_module(src)
  local chunk, err = load(src, "=electrique", "t")
  assert(chunk, err)
  return chunk()
end

local function read(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end

local SRC = read(SRC_PATH)
local passes, failures = 0, 0
local function check(c, msg)
  if c then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
end
local function section(t) print("== " .. t) end

-- noms opaques : aucune règle ne lit un nom d'objet
local DRILL = "foreuse-a"

local function suite(E)
  local before = failures
  -- 1. (a) verdict
  do
    local ok_all = { el_live = 1, obtainable = true, plants = 1, poles = true, healthy = true }
    local a, why = E.thermal(ok_all)
    check(a == false and why:find("thermique refusee", 1, true) ~= nil, "1a : centrale finie, foreuse et poteau obtenables : thermique refusee, cause ecrite")
    check(why:find("1 centrale", 1, true) ~= nil, "1a : la cause nomme les centrales finies")
    check(E.thermal({ on = false, el_live = 1, obtainable = true, plants = 1, poles = true }) == true, "1b : regle coupee : thermique permise")
    check(E.thermal({ el_live = 1, obtainable = false, plants = 1, poles = true }) == true, "1c : foreuse electrique pas obtenable : permise")
    check(E.thermal({ el_live = 1, obtainable = true, plants = 0, poles = true }) == true, "1d : aucune centrale finie : permise")
    check(E.thermal({ el_live = 1, obtainable = true, plants = nil, poles = true }) == true, "1d : centrales non lues : permise")
    check(E.thermal({ el_live = 1, obtainable = true, plants = 1, poles = false }) == true, "1e : aucun poteau obtenable : permise")
    check(E.thermal({ el_live = 1, obtainable = true, plants = 1, poles = true, fuel = true, healthy = false }) == true,
      "1f : combustible d'une centrale a l'arret : permise")
    check(E.thermal({ el_live = 1, obtainable = true, plants = 1, poles = true, fuel = true, healthy = true }) == false,
      "1g : combustible, centrale saine : refusee")
    check(E.thermal({ el_live = 1, obtainable = true, plants = 1, poles = true, fuel = false, healthy = false }) == false,
      "1h : autre minerai, centrale a l'arret : refusee (seul le combustible la relance)")
    check(E.thermal({ el_live = 1, obtainable = true, plants = 3, poles = true }) == false, "1i : plusieurs centrales : refusee")
    check(E.thermal(nil) == true, "1j : rien de lu : permise")
    -- correctif d'interblocage (partie neuve 0.6.69, etape1-guide : bascule à 7,7 min, 0 électrique et 6 poteaux tout le long, foreuses
    -- détruites à 15,4 min, reconstruction « build:copper » refusée) : centrale finie, 0 poteau ni bois, rien qui tourne : PERMISE
    local dl = { on = true, obtainable = true, plants = 1, poles = true, healthy = true, el_live = 0, poles_stock = 6, res_live = 0 }
    local okd, whyd = E.thermal(dl)
    check(okd == true and whyd:find("ni poteaux au stock", 1, true) ~= nil, "1l : cas 0.6.69 (0 electrique, 6 poteaux) : reconstruction thermique permise (" .. tostring(whyd) .. ")")
    check(E.thermal({ obtainable = true, plants = 1, poles = true }) == true, "1l : rien de mesure (el_live, poteaux absents) : permise")
    check(E.thermal({ obtainable = true, plants = 1, poles = true, el_live = 0, poles_stock = 12 }) == false,
      "1m : 12 poteaux au stock, rien qui tourne encore : refusee (le gabarit se pose)")
    check(E.thermal({ obtainable = true, plants = 1, poles = true, el_live = 0, poles_stock = 11 }) == true, "1m : 11 poteaux : permise")
    local okr, whyr = E.thermal({ obtainable = true, plants = 1, poles = true, el_live = 0, poles_stock = 40, since = E.CFG.revert })
    check(okr == true and whyr:find("retour thermique", 1, true) ~= nil, "1n : 0 electrique 3 min apres la bascule : retour thermique")
    check(E.thermal({ obtainable = true, plants = 1, poles = true, el_live = 0, poles_stock = 40, since = E.CFG.revert - 1 }) == false,
      "1n : juste avant 3 min : refusee")
    check(E.thermal({ obtainable = true, plants = 1, poles = true, el_live = 2, poles_stock = 0, since = 10 * E.CFG.revert }) == false,
      "1n : des electriques tournent : pas de retour, meme sans poteau au stock")
    local oks, whys = E.thermal({ obtainable = true, plants = 1, poles = true, el_live = 5, res_live = 0 })
    check(oks == true and whys:find("cette ressource", 1, true) ~= nil, "1o : 5 electriques ailleurs, 0 sur cette ressource : permise (jamais affamee)")
    check(E.thermal({ obtainable = true, plants = 1, poles = true, el_live = 5, res_live = 1 }) == false, "1o : une electrique sur cette ressource : refusee")
    -- partie du DC (0.6.66, joueur) : centrale 1 finie à 28,0 min, foreuse électrique fabricable dès le début, poteaux : refusée dès 28 min
    check(E.thermal({ on = true, el_live = 1, obtainable = true, plants = 1, poles = true, healthy = true }) == false, "1k : cas du DC a 28 min : refusee")
  end
  -- 2. foreuses thermiques d'une tâche
  do
    check(E.task_drills({ kind = "extend", items = { { DRILL, 2 }, { "four-b", 2 }, { "comb-c", 10 } } }, DRILL) == 2, "2a : agrandissement de 2 paires : 2")
    check(E.task_drills({ kind = "build", outpost_kind = "t1", items = { { DRILL, 4 }, { "four-b", 4 } } }, DRILL) == 4, "2b : avant-poste neuf de 4 paires : 4")
    check(E.task_drills({ kind = "build", items = { { DRILL, 4 } } }, DRILL) == 0, "2c : build sans type d'avant-poste : hors regle")
    check(E.task_drills({ kind = "craft", item = DRILL, count = 10 }, DRILL) == 10, "2d : fabrication de 10 thermiques : 10")
    check(E.task_drills({ kind = "craft", item = "autre", count = 10 }, DRILL) == 0, "2e : autre fabrication : hors regle")
    check(E.task_drills({ kind = "craft", item = DRILL }, DRILL) == 1, "2f : fabrication sans nombre : 1")
    check(E.task_drills({ kind = "mine", resource = "r" }, DRILL) == 0, "2g : minage : hors regle")
    check(E.task_drills({ kind = "extend" }, DRILL) == 1, "2h : agrandissement sans liste : 1")
    check(E.task_drills({ kind = "extend", items = { { "four-b", 2 } } }, DRILL) == 1, "2i : agrandissement sans foreuse listee : 1")
    check(E.task_drills(nil, DRILL) == 0 and E.task_drills({ kind = "extend" }, nil) == 0, "2j : entrees absentes : 0")
    check(E.task_drills({ kind = "extend", items = { { DRILL, 1 }, { DRILL, 2 } } }, DRILL) == 3, "2k : deux lignes de la foreuse : sommees")
  end
  -- 3. filtre du tableau
  do
    local tasks = {
      { key = "extend:1", kind = "extend", items = { { DRILL, 2 } } },
      { key = "mine:x", kind = "mine" },
      { key = "extend:2", kind = "extend", items = { { DRILL, 2 } }, worker = 7 },
      { key = "build:t1", kind = "build", outpost_kind = "t1", items = { { DRILL, 2 } } },
      { key = "craft:a", kind = "craft", item = DRILL, count = 10 },
      { key = "build:t2", kind = "build", outpost_kind = "t2", items = { { DRILL, 2 } } },
    }
    local kept, refused = E.filter(tasks, DRILL, function(t)
      if t.outpost_kind == "t2" then return true, "exception" end
      return false, "raison-" .. t.key
    end)
    local ks = {}
    for _, t in ipairs(kept) do ks[#ks + 1] = t.key end
    check(table.concat(ks, ",") == "mine:x,extend:2,build:t2", "3a : gardees dans l'ordre : hors regle, prise, permise (" .. table.concat(ks, ",") .. ")")
    check(#refused == 3 and refused[1].task.key == "extend:1" and refused[2].task.key == "build:t1" and refused[3].task.key == "craft:a",
      "3b : refusees dans l'ordre d'arrivee")
    check(refused[1].why == "raison-extend:1" and refused[1].n == 2 and refused[3].n == 10, "3c : cause et nombre de foreuses portes par chaque refus")
    local k2, r2 = E.filter(tasks, DRILL, function() return true end)
    check(#k2 == #tasks and #r2 == 0, "3d : tout permis : tout garde")
    local k3, r3 = E.filter(nil, DRILL, function() return false, "x" end)
    check(#k3 == 0 and #r3 == 0, "3e : liste absente : rien")
  end
  -- 4. (b) quota à la marge de kW
  do
    local n, m = E.swap_quota({ capacity = 1800, used = 1300, committed = 0, kw = 90 })
    check(n == 5 and math.abs(m - 500) < 1e-6, "4a : 1800 - 1300 = 500 kW : 5 electriques (" .. tostring(n) .. ")")
    check(E.swap_quota({ capacity = 1800, used = 1850, committed = 0, kw = 90 }) == 0, "4b : marge negative : 0")
    check(E.swap_quota({ capacity = 900, used = 0, committed = 0, kw = 90 }) == 10, "4c : centrale vide : 900 / 90 = 10")
    check(E.swap_quota({ capacity = 18000, used = 0, committed = 0, kw = 90 }) == E.CFG.block_max, "4d : borne block_max")
    check(E.swap_quota({ capacity = 1800, used = 0, committed = 2000, kw = 90 }) == 6, "4e : chantiers a 0,6 : (1800 - 1200) / 90 = 6")
    -- banc sur la sauvegarde du DC (8/11) : 9 000 kW, 4 797 pris, 2 523 en chantiers : 2 286 kW de marge (bornee a 16 electriques)
    local nd, md = E.swap_quota({ capacity = 9000, used = 4797, committed = 2523, kw = 90 })
    check(nd == E.CFG.block_max and md > 2200, "4k : cas de la sauvegarde du DC : marge positive, quota plein (" .. tostring(md) .. ")")
    local nf, mf = E.swap_quota({ capacity = nil, kw = 90, fallback = 2 })
    check(nf == 2 and mf == nil, "4f : capacite non lue : quota de secours, pas de marge")
    check(E.swap_quota({ capacity = 0, kw = 90, fallback = 99 }) == E.CFG.block_max, "4g : secours borne")
    check(E.swap_quota({ capacity = 1800, used = 0, kw = 0, fallback = 3 }) == 3, "4h : kW d'une foreuse inconnu : secours")
    check(E.swap_quota({ capacity = 1800, used = 1620, committed = 0, kw = 90 }) == 2, "4i : 1800 - 1620 = 180 : exactement 2")
    check(E.swap_quota({ capacity = 0 / 0, kw = 90, fallback = 1 }) == 1, "4j : capacite NaN : secours")
  end
  -- 5. (b) par bloc
  do
    local entries = {
      { id = 10, o = 2 }, { id = 11, o = 2 }, { id = 12, o = 2 }, { id = 13, o = 2 }, { id = 14, o = 2 },
      { id = 3, o = 1 }, { id = 4, o = 1 }, { id = 5, o = 1 },
      { id = 20, o = 3 }, { id = 21, o = 3 }, { id = 22, o = 3 }, { id = 23, o = 3 },
      { id = 99 },
    }
    local function ids(l) local o = {} for _, e in ipairs(l) do o[#o + 1] = e.id end return table.concat(o, ",") end
    local out, fields = E.block(entries, 4)
    check(ids(out) == "3,4,5" and #fields == 1 and fields[1].o == 1 and fields[1].n == 3,
      "5a : quota 4 : le champ 1 entier, le champ 2 (5) ne tient pas (" .. ids(out) .. ")")
    out, fields = E.block(entries, 8)
    check(ids(out) == "3,4,5,10,11,12,13,14" and #fields == 2 and fields[2].o == 2, "5b : quota 8 : champs 1 et 2 entiers")
    out = E.block(entries, 2)
    check(ids(out) == "3,4,5", "5c : quota 2 : le premier champ quand meme entier")
    out, fields = E.block(entries, 0)
    check(#out == 0 and #fields == 0, "5d : quota nul : rien")
    out = E.block(entries, 100)
    check(ids(out) == "3,4,5,10,11,12,13,14,20,21,22,23", "5e : quota large : tous les champs, sans les candidats sans avant-poste, tries par id")
    out, fields = E.block(entries, 12)
    check(#fields == 3 and fields[3].n == 4, "5f : quota exact (3 + 5 + 4) : trois champs")
    check(#E.block(nil, 5) == 0, "5g : liste absente : rien")
    out = E.block({ { id = 31, o = 1 }, { id = 30, o = 1 }, { id = 2, o = 2 }, { id = 1, o = 2 } }, 10)
    check(ids(out) == "1,2,30,31", "5h : candidats rendus tries par id (ordre de S.plan), quel que soit le champ (" .. ids(out) .. ")")
    -- champ sauté (la passe précédente n'y a rien planifié : coal à 111 tuiles sans poteau à portée, partie du DC)
    out, fields = E.block(entries, 4, { [1] = true })
    check(ids(out) == "10,11,12,13,14" and fields[1].o == 2, "5i : champ 1 saute : le champ 2 (entier) a sa place (" .. ids(out) .. ")")
    out = E.block(entries, 100, { [1] = true, [3] = true })
    check(ids(out) == "10,11,12,13,14", "5j : deux champs sautes : le reste seulement")
    out = E.block(entries, 4, { [1] = true, [2] = true, [3] = true })
    check(ids(out) == "3,4,5", "5k : tous sautes : aucun ne l'est (jamais de passe vide par la regle)")
    out = E.block(entries, 4, { [7] = true })
    check(ids(out) == "3,4,5", "5l : saut d'un champ absent : sans effet")
  end
  -- 5 bis. champs sans candidat retenu
  do
    local fields = { { o = 1, n = 3 }, { o = 2, n = 5 }, { o = 3, n = 2 } }
    local owner = { [3] = 1, [4] = 1, [10] = 2, [20] = 3 }
    local idle = E.idle_fields(fields, { { id = 10 }, { id = 4 } }, owner)
    check(table.concat(idle, ",") == "3", "5m : champs 1 et 2 planifies, le 3 non : le 3 est saute")
    check(table.concat(E.idle_fields(fields, {}, owner), ",") == "1,2,3", "5n : rien de planifie : tous")
    check(#E.idle_fields(fields, { { id = 3 }, { id = 10 }, { id = 20 } }, owner) == 0, "5o : tous planifies : aucun")
    check(table.concat(E.idle_fields({ { o = 3 }, { o = 1 } }, {}, owner), ",") == "1,3", "5p : liste triee")
    check(#E.idle_fields(nil, nil, nil) == 0, "5q : rien : rien")
  end
  -- 6. (c) kW prévus
  do
    -- partie du DC : 127 thermiques à 31 min, cadences 0,25 et 0,5, 90 kW, marge nulle
    local short, planned, n = E.planned_kw({ thermals = 127, th_speed = 0.25, el_speed = 0.5, kw = 90, margin = 0 })
    check(n == 64 and planned == 5760 and short == 5760, "6a : 127 thermiques : 64 electriques, 5 760 kW demandes (" .. tostring(short) .. ")")
    check(E.planned_kw({ thermals = 127, th_speed = 0.25, el_speed = 0.5, kw = 90, margin = 6000 }) == 0, "6b : marge suffisante : rien a demander")
    check(E.planned_kw({ thermals = 127, th_speed = 0.25, el_speed = 0.5, kw = 90, margin = 760 }) == 5000, "6c : marge deduite")
    check(E.planned_kw({ thermals = 127, th_speed = 0.25, el_speed = 0.5, kw = 90, margin = -500 }) == 5760, "6d : marge negative comptee 0")
    local s2, p2, n2 = E.planned_kw({ thermals = 10, refused = 4, th_speed = 0.25, el_speed = 0.5, kw = 90 })
    check(n2 == 7 and p2 == 630 and s2 == 630, "6e : paires refusees comptees : (10 + 4) / 2 = 7")
    check(E.planned_kw({ thermals = 3, th_speed = 0.25, el_speed = 0.5, kw = 90 }) == 180, "6f : 3 thermiques : 2 electriques (arrondi au-dessus)")
    check(E.planned_kw({ thermals = 0, refused = 0, th_speed = 0.25, el_speed = 0.5, kw = 90 }) == 0, "6g : rien a convertir : 0")
    check(E.planned_kw({ thermals = 10, th_speed = 0, el_speed = 0.5, kw = 90 }) == 0, "6h : cadence inconnue : 0")
    check(E.planned_kw({ thermals = 10, th_speed = 0.25, el_speed = 0.5, kw = 0 }) == 0, "6i : kW inconnus : 0")
    check(E.planned_kw({ thermals = 4, th_speed = 0.5, el_speed = 0.5, kw = 90 }) == 360, "6j : cadences egales : une pour une")
    check(E.planned_kw(nil) == 0, "6k : rien : 0")
  end
  -- 7. fenêtre des refus
  do
    local log = { { tick = 100, n = 2 }, { tick = 5000, n = 4 }, { tick = 9000, n = 1 }, { tick = 20000, n = 8 } }
    local keep, sum = E.refused_window(log, 9100)
    check(#keep == 2 and sum == 5, "7a : plus de 2 min et futur oublies : 4 + 1 (" .. tostring(sum) .. ")")
    local k2, s2 = E.refused_window(nil, 10)
    check(#k2 == 0 and s2 == 0, "7b : rien : 0")
    local _, s3 = E.refused_window({ { tick = 100, n = 2 } }, 100 + E.CFG.refused_ttl)
    check(s3 == 0, "7c : exactement au bout du delai : oublie")
    local _, s4 = E.refused_window({ { tick = 100, n = 2 } }, 100 + E.CFG.refused_ttl - 1)
    check(s4 == 2, "7d : juste avant le delai : compte")
  end
  return failures - before
end

section("1 a 7. Regle pure")
local E = load_module(SRC)
check(suite(E) == 0, "la batterie passe sur la regle reelle")

section("8. Aucun nom d'objet dans la regle")
do
  local names = { "mining%-drill", "electric%-pole", "stone%-furnace", "iron%-chest", "\"coal\"", "iron%-ore", "copper%-ore" }
  for _, n in ipairs(names) do check(SRC:find(n) == nil, "8 : pas de « " .. n .. " » dans " .. SRC_PATH) end
end

section("8 bis. Branchement au cerveau : projet d'avant-poste bloqué (shared/ai3/projets.lua, EMIT.outpost)")
do
  local Pj = require("shared.ai3.projets")
  local E0 = { view = { pending = {}, thermal_off = { ["type-k"] = "electrique possible" } } }
  local st, cause = Pj.EMIT.outpost(E0, { prio = 50 }, { outpost = "type-k" }, {})
  check(st == "bloque" and cause == "electrique:type-k", "8b : type refuse : projet bloque, cause electrique:<type> (" .. tostring(st) .. ", " .. tostring(cause) .. ")")
  local E1 = { view = { pending = { ["type-k"] = 1 }, thermal_off = { ["type-k"] = "x" } } }
  check(Pj.EMIT.outpost(E1, { prio = 50 }, { outpost = "type-k" }, {}) == "en_cours", "8b : une tache deja ouverte reste en cours (elle finit)")
  local E2 = { view = { pending = {}, thermal_off = { ["type-j"] = "x" } }, open = {}, book = { handcraftable = function() return false end }, avail = {} }
  local ok2, st2, c2 = pcall(Pj.EMIT.outpost, E2, { prio = 50 }, { outpost = "type-k", extend_only = true }, {})
  check(not (ok2 and st2 == "bloque" and tostring(c2):find("electrique", 1, true)), "8b : autre type refuse : celui-ci n'est pas bloque par la regle")
  local psrc = read("shared/ai3/projets.lua")
  check(psrc:find("if view.thermal_off and view.thermal_off[kind] then return \"bloque\", \"electrique:\" .. kind end", 1, true) ~= nil,
    "8b : la porte est dans EMIT.outpost")
end

section("8 bis 2. Petit poteau et bois (d) : A.choose_pole, A.POLE_BATCH, tâches de minage du bois marquées « trees »")
do
  local A = require("shared.ai3.automatiser")
  local Mo = require("shared.team.modules")
  local small = Mo.POLES[1]
  -- livre factice : chaque poteau se fabrique (2 par recette) avec 1 matière naturelle « bois-x » ; le reste n'est pas naturel
  local book = {
    handcraftable = function(_, name) return name == small end,
    natural = function(_, k) return k == "bois-x" end,
    plan = function(_, wants, stock)
      local n = wants[1][2]
      local need = math.ceil(n / 2) - ((stock or {})["bois-x"] or 0)
      return { raw = need > 0 and { ["bois-x"] = need } or {} }
    end,
  }
  check(A.POLE_BATCH == 12, "8d : A.POLE_BATCH = 12 (gabarit de fonderie au petit poteau)")
  check(A.choose_pole(book, { ["bois-x"] = 6 }, {}) == small, "8d : 6 bois au coffre suffisent au gabarit (12 poteaux)")
  check(A.choose_pole(book, { ["bois-x"] = 5 }, {}) ~= small, "8d : 5 bois, rien a portee : pas le petit poteau")
  check(A.choose_pole(book, {}, { ["bois-x"] = 40 }) == small, "8d : bois a portee (arbres) : petit poteau sans stock")
  local psrc = read("shared/ai3/projets.lua")
  check(psrc:find("trees = (ctx.trees and ctx.trees[item]) or nil", 1, true) ~= nil, "8d : la tache de minage du bois porte `trees`")
  local csrc = read("shared/ai3/cerveau.lua")
  check(csrc:find("trees = trees,", 1, true) ~= nil, "8d : le cerveau passe l'ensemble des matieres des arbres a P.supply")
end

section("8 ter. Centrales en parallèle (shared/team/centrale.lua, C.parallel_kw, C.growth)")
local CSRC = read("shared/team/centrale.lua")
local function centrale_suite(C)
  local before = failures
  local st = { def_n = 3 }
  local base = { done = 1, pending = 1, refused = 0, boiler_kw = 1800, deficit_kw = 7125, pending_kw = 1800 }
  local function n_of(over) local n = {} for k, v in pairs(base) do n[k] = v end for k, v in pairs(over or {}) do n[k] = v end return n end
  check(C.parallel_kw(st, n_of()) == 5325, "8c : 7 125 kW de deficit, 1 800 kW en chantier : 5 325 kW restent")
  local nb = C.growth(st, n_of())
  check(nb ~= nil and nb >= 2, "8c : cas du DC (33,9 min) : chantier en parallele de plusieurs chaudieres (" .. tostring(nb) .. ")")
  local nb2, why2 = C.growth(st, n_of({ pending_kw = 9000 }))
  check(nb2 == nil and why2 == "un chantier de centrale est ouvert", "8d : chantier ouvert qui couvre le deficit : pas de second")
  check(C.growth(st, n_of({ pending = 2 })) == nil, "8e : deux chantiers ouverts : plafond")
  local old = n_of()
  old.pending_kw = nil
  check(C.growth(st, old) == nil, "8f : capacite des chantiers inconnue (appels d'avant) : un seul chantier")
  check(C.growth({ def_n = 1 }, n_of()) == nil, "8g : deficit pas encore installe : un seul chantier")
  check(C.parallel_kw({ def_n = 1 }, n_of()) == nil, "8g : parallel_kw : deficit pas installe : nil")
  check(C.growth(st, n_of({ deficit_kw = 3000 })) == 1, "8k : 3 000 kW de deficit, 1 800 en chantier : 1 chaudiere pour les 1 200 restants")
  check(C.growth(st, n_of({ deficit_kw = 0 })) == nil, "8h : pas de deficit : un seul chantier")
  check(C.parallel_kw(st, n_of({ pending = 0 })) == nil, "8i : aucun chantier ouvert : pas de parallele (la regle d'avant s'applique)")
  local nb3 = C.growth(st, n_of({ pending = 0, deficit_kw = 3000 }))
  check(nb3 == 2, "8j : sans chantier ouvert : taille du deficit, comme avant (" .. tostring(nb3) .. ")")
  return failures - before
end
check(centrale_suite(load_module(CSRC)) == 0, "la batterie des centrales passe sur la regle reelle")
do
  local function cmut(from, to)
    local i, j = CSRC:find(from, 1, true)
    assert(i and not CSRC:find(from, j + 1, true), "motif de mutant (centrale) : " .. from)
    return CSRC:sub(1, i - 1) .. to .. CSRC:sub(j + 1)
  end
  local cm = {
    { "parallele : plafond ignore", "if p <= 0 or p >= C.MAX_PARALLEL or n.pending_kw == nil then return nil end", "if p <= 0 or n.pending_kw == nil then return nil end" },
    { "parallele : chantiers ouverts non deduits", "local left = n.deficit_kw - n.pending_kw", "local left = n.deficit_kw" },
    { "parallele : deficit non installe", "if not ((n.deficit_kw or 0) > 0 and (st.def_n or 0) >= C.DEFICIT_CHECKS) then return nil end", "" },
    { "parallele : jamais", "if n.pending > 0 and not C.parallel_kw(st, n) then return nil", "if n.pending > 0 then return nil" },
    { "parallele : taille du deficit entier", "return C.deficit_size(C.parallel_kw(st, n), n.boiler_kw", "return C.deficit_size(n.deficit_kw, n.boiler_kw" },
  }
  for _, mu in ipairs(cm) do
    local ok, M2 = pcall(function() return load_module(cmut(mu[2], mu[3])) end)
    local killed
    if not ok then killed = true else
      local sp, sf = passes, failures
      local silent = print
      _G.print = function() end
      local okr, res = pcall(centrale_suite, M2)
      _G.print = silent
      killed = (not okr) or res > 0
      passes, failures = sp, sf
    end
    check(killed, "mutant refuse (centrale) : " .. mu[1])
  end
end

section("9. Mutants")
local function mutate(from, to)
  local i, j = SRC:find(from, 1, true)
  assert(i, "motif de mutant introuvable : " .. from)
  assert(not SRC:find(from, j + 1, true), "motif de mutant ambigu : " .. from)
  return SRC:sub(1, i - 1) .. to .. SRC:sub(j + 1)
end

local mutants = {
  { "thermal : regle coupee ignoree", "if s.on == false then return true, \"regle coupee\" end", "" },
  { "thermal : obtenable ignore", "if not s.obtainable then return true, \"foreuse electrique pas obtenable\" end", "" },
  { "thermal : centrale ignoree", "if (num(s.plants) or 0) < 1 then return true, \"aucune centrale finie\" end", "" },
  { "thermal : poteaux ignores", "if not s.poles then return true, \"aucun poteau obtenable\" end", "" },
  { "thermal : exception combustible supprimee", "if s.fuel and s.healthy == false then return true", "if false then return true" },
  { "thermal : exception pour tout minerai", "if s.fuel and s.healthy == false then return true", "if s.healthy == false then return true" },
  { "thermal : sans electrique ni poteaux refusee (interblocage 0.6.69)", "  if live <= 0 and stock < cfg.poles_min then\n", "  if false then\n" },
  { "thermal : poteaux au stock ignores", "  if live <= 0 and stock < cfg.poles_min then\n", "  if live <= 0 then\n" },
  { "thermal : jamais de retour thermique", "  if live <= 0 and (num(s.since) or 0) >= cfg.revert then", "  if false then" },
  { "thermal : retour avant le delai", "  if live <= 0 and (num(s.since) or 0) >= cfg.revert then", "  if live <= 0 and (num(s.since) or 0) > 0 then" },
  { "thermal : ressource affamee refusee", "  if s.res_live ~= nil and (num(s.res_live) or 0) <= 0 then", "  if false then" },
  { "thermal : toujours permise", "  return false, string.format(\"electrique possible", "  return true, string.format(\"electrique possible" },
  { "task_drills : craft d'autre objet compte", "    if t.item == drill then return max(1, floor(num(t.count) or 1)) end\n    return 0", "    return max(1, floor(num(t.count) or 1))" },
  { "task_drills : build sans type compte", "if t.kind ~= \"extend\" and not (t.kind == \"build\" and t.outpost_kind ~= nil) then return 0 end", "if t.kind ~= \"extend\" and t.kind ~= \"build\" then return 0 end" },
  { "task_drills : extend ignore", "if t.kind ~= \"extend\" and not (t.kind == \"build\" and t.outpost_kind ~= nil) then return 0 end", "if not (t.kind == \"build\" and t.outpost_kind ~= nil) then return 0 end" },
  { "task_drills : liste vide = 0", "  if n <= 0 then n = 1 end\n", "" },
  { "task_drills : lignes non sommees", "n = n + (num(it[2]) or 0)", "n = (num(it[2]) or 0)" },
  { "filter : tache prise filtree", "local n = (not t.worker) and E.task_drills(t, drill) or 0", "local n = E.task_drills(t, drill)" },
  { "filter : verdict ignore", "if n > 0 then ok, why = verdict(t) end", "if n > 0 then ok, why = false, \"x\" end" },
  { "swap_quota : draw ignore", "local margin = cap - (num(c.used) or 0) - cfg.draw * (num(c.committed) or 0)", "local margin = cap - (num(c.used) or 0) - (num(c.committed) or 0)" },
  { "swap_quota : chantiers ignores", "local margin = cap - (num(c.used) or 0) - cfg.draw * (num(c.committed) or 0)", "local margin = cap - (num(c.used) or 0)" },
  { "swap_quota : draw sur la capacite (bug du 8/11)", "local margin = cap - (num(c.used) or 0) - cfg.draw * (num(c.committed) or 0)", "local margin = cap * cfg.draw - (num(c.used) or 0) - (num(c.committed) or 0)" },
  { "swap_quota : sans borne", "return max(0, min(cfg.block_max, n)), margin", "return max(0, n), margin" },
  { "swap_quota : negatif rendu", "return max(0, min(cfg.block_max, n)), margin", "return min(cfg.block_max, n), margin" },
  { "swap_quota : arrondi au-dessus", "local n = floor(margin / kw + EPS)", "local n = ceil(margin / kw - EPS)" },
  { "swap_quota : secours sans borne", "return min(cfg.block_max, max(0, floor(num(c.fallback) or 0))), nil", "return max(0, floor(num(c.fallback) or 0)), nil" },
  { "block : champ coupe", "if taken > 0 and taken + #list > quota then break end", "" },
  { "block : premier champ refuse s'il depasse", "if taken > 0 and taken + #list > quota then break end", "if taken + #list > quota then break end" },
  { "block : champs dans l'ordre d'arrivee", "  table.sort(ids, function(a, b) return a < b end)\n", "" },
  { "block : quota nul ignore", "if (quota or 0) <= 0 then return out, fields end", "" },
  { "block : sans tri final", "  table.sort(out, function(a, b) return a.id < b.id end)\n  return out, fields", "  return out, fields" },
  { "block : saut ignore", "for _, o in ipairs(all) do if not (skip and skip[o]) then ids[#ids + 1] = o end end", "for _, o in ipairs(all) do ids[#ids + 1] = o end" },
  { "block : tous sautes = passe vide", "  if #ids == 0 then ids = all end\n", "" },
  { "idle_fields : planifies sautes", "if (planned[fl.o] or 0) == 0 then idle[#idle + 1] = fl.o end", "if (planned[fl.o] or 0) > 0 then idle[#idle + 1] = fl.o end" },
  { "idle_fields : sans tri", "  table.sort(idle, function(a, b) return a < b end)\n  return idle", "  return idle" },
  { "planned_kw : marge ignoree", "return max(0, planned - max(0, num(p.margin) or 0)), planned, n_el", "return planned, planned, n_el" },
  { "planned_kw : marge negative ajoutee", "return max(0, planned - max(0, num(p.margin) or 0)), planned, n_el", "return max(0, planned - (num(p.margin) or 0)), planned, n_el" },
  { "planned_kw : refus ignores", "local drills = max(0, num(p.thermals) or 0) + max(0, num(p.refused) or 0)", "local drills = max(0, num(p.thermals) or 0)" },
  { "planned_kw : une pour une", "local n_el = ceil(drills * th / el - EPS)", "local n_el = drills" },
  { "planned_kw : arrondi au-dessous", "local n_el = ceil(drills * th / el - EPS)", "local n_el = floor(drills * th / el + EPS)" },
  { "refused_window : delai ignore", "tick - r.tick < cfg.refused_ttl and tick >= r.tick", "tick >= r.tick" },
  { "refused_window : futur compte", "tick - r.tick < cfg.refused_ttl and tick >= r.tick", "tick - r.tick < cfg.refused_ttl" },
  { "refused_window : delai inclusif", "tick - r.tick < cfg.refused_ttl and tick >= r.tick", "tick - r.tick <= cfg.refused_ttl and tick >= r.tick" },
}

local survivors = 0
for _, mu in ipairs(mutants) do
  local ok, M2 = pcall(function() return load_module(mutate(mu[2], mu[3])) end)
  local killed
  if not ok then
    killed = true
  else
    local saved_pass, saved_fail = passes, failures
    local silent = print
    _G.print = function() end
    local okr, res = pcall(suite, M2)
    _G.print = silent
    killed = (not okr) or res > 0
    passes, failures = saved_pass, saved_fail -- les échecs d'un mutant ne comptent pas
  end
  check(killed, "mutant refuse : " .. mu[1])
  if not killed then survivors = survivors + 1 end
end
print(string.format("[ELECTRIQUE] mutants %d refuses sur %d", #mutants - survivors, #mutants))

print(string.format("[ELECTRIQUE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
