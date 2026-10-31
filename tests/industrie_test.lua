--[[
  Lot INDUSTRIE I6 « choix » : la règle du choix du patron et du nombre de copies selon le besoin (shared/ai3/industrie.lua), la
  demande d'autres sources (shared/ai3/mall.lua, testée à part dans tests/mall_test.lua), les patrons dans A.method_for
  (shared/ai3/automatiser.lua) et l'emplacement du mall (Em.mall). Hors jeu, Lua pur : lua5.2 tests/industrie_test.lua

    §1 règle pure : lecture d'un refus, fusion des demandes, barre du coffre, profil d'un objet, RANGÉE contre BLOC contre cellule
       seule, ouverture d'un bloc (nombre d'objets, attente), objets déjà servis, refus écrits, déterminisme (listes inversées),
       NOMS PERMUTÉS (mêmes formes), état sérialisable ;
    §2 A.method_for : sans lecture, le refus d'avant ; avec la lecture, un patron pour 3 à 8 entrées, dimensionné au débit ; les
       fluides restent refusés ; un MOD (machine inventée, plus rapide) est choisi sans une ligne de code ; la déclaration à M
       est refaite après un « chargement » (M.BASE vidé) ; clés de cache distinctes ;
    §3 Em.mall : l'emplacement du mall est à part, un bloc figé ou suspendu le libère ;
    §4 MUTANTS : chaque règle de shared/ai3/industrie.lua, du patron de A.method_for et d'Em.mall cassée est vue.
]]

package.path = "./?.lua;" .. package.path
local L = require("shared.ai3.lecture")
local F = require("tests.iag_fixture")
local Book = require("shared.team.book")
local M = require("shared.team.modules")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then pass = pass + 1 else fail = fail + 1 print("ECHEC : " .. label) end
  return cond
end
local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

---------------------------------------------------------------------------------------------------
-- Relevé vanilla (emprises, boîtes, kit) et mod inventé
---------------------------------------------------------------------------------------------------
local function box(kind) return { type = kind, conns = { [0] = {}, [2] = {}, [4] = {}, [6] = {} } } end
local SIDE = { ["stone-furnace"] = 2, ["steel-furnace"] = 2, ["electric-furnace"] = 3, ["oil-refinery"] = 5 }
local BOXES = {
  ["assembling-machine-2"] = { box("input"), box("output") }, ["assembling-machine-3"] = { box("input"), box("output") },
  ["chemical-plant"] = { box("input"), box("input"), box("output"), box("output") },
  ["oil-refinery"] = { box("input"), box("input"), box("output"), box("output"), box("output") },
}
local SLOTS = { ["wooden-chest"] = 16, ["iron-chest"] = 32, ["steel-chest"] = 48 }
local BELT = { ["transport-belt"] = 0.03125, ["fast-transport-belt"] = 0.0625 }
local POLE = { ["small-electric-pole"] = { 2.5, 7.5 }, ["medium-electric-pole"] = { 3.5, 9 } }
local function vanilla(with_mod)
  local d = F.dump()
  for _, e in ipairs(d.entities) do
    if e.type == "assembling-machine" or e.type == "furnace" then
      e.w = SIDE[e.name] or 3
      e.h = e.w
      e.boxes = BOXES[e.name] or {}
    elseif e.type == "inserter" then
      local long = e.name == "long-handed-inserter"
      e.pickup = { x = 0, y = long and -2 or -1 }
      e.drop = { x = 0, y = long and 2.2 or 1.2 }
      e.energy = e.name == "burner-inserter" and "burner" or "electric"
      e.filters = 0
      e.rot = (e.name == "inserter") and 0.014 or ((e.name == "long-handed-inserter") and 0.02 or 0.04)
    elseif e.type == "container" then
      e.slots = SLOTS[e.name]
    elseif e.type == "transport-belt" then
      e.belt_speed = BELT[e.name]
    elseif e.type == "electric-pole" then
      e.supply, e.wire = POLE[e.name][1], POLE[e.name][2]
    end
  end
  if with_mod then
    -- une machine d'un mod : 4 x 4, 8 ingrédients, neuf fois plus rapide, mêmes catégories que l'assembleur 3
    local base
    for _, e in ipairs(d.entities) do if e.name == "assembling-machine-3" then base = e end end
    local m = {}
    for k, v in pairs(base) do m[k] = v end
    m.name, m.item, m.speed, m.w, m.h, m.ingredient_count = "zz-mod-assembler", "zz-mod-assembler", 9, 4, 4, 8
    d.entities[#d.entities + 1] = m
  end
  return d
end

local dump = vanilla(false)
local fab, machines = L.read(dump, {})
local kd = L.kit_data(dump)
local function lecture_of(fab_, machines_, kd_)
  return { fab = fab_, machines = machines_, kit = function(u) return L.kit(kd_, u) end }
end
local book = Book.new(dump.recipes)

local function first_with(pred)
  for _, rn in ipairs(sorted_keys(fab)) do
    local e = fab[rn]
    if e.patronnable and #e.fluides_in == 0 and #e.produits == 1 and e.produits[1] == rn and pred(e) then return rn, e end
  end
end

---------------------------------------------------------------------------------------------------
-- §1 règle pure
---------------------------------------------------------------------------------------------------
local function battery_id(Id, verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 end
    if verbose then check(c, msg) end
  end
  ck(Id.parse_refus("manque sous une demi-machine (1.8/min)") == 1.8 and Id.parse_refus("manque sous une demi-machine (12/min)") == 12
    and Id.parse_refus("manque sous une demi-machine (0.0/min)") == nil and Id.parse_refus("entree x d'abord (couverte a 3 pour mille)") == nil
    and Id.parse_refus(nil) == nil and Id.parse_refus("executant : limite : x a 3 ingredients") == nil,
    "1a. lecture du refus « manque sous une demi-machine (X/min) » : le débit, sinon rien")
  local mg = Id.merge({ { { item = "b", rate = 2, src = "main" }, { item = "a", rate = 2, src = "main" } },
    { { item = "b", rate = 5, src = "refus" }, { item = "c", rate = 0, src = "x" }, { item = "d", rate = -1, src = "x" } } })
  ck(#mg == 2 and mg[1].item == "b" and mg[1].rate == 5 and #mg[1].srcs == 2 and mg[1].srcs[1] == "main" and mg[1].srcs[2] == "refus"
    and mg[2].item == "a", "1b. fusion : le maximum des sources (pas la somme), triée par demande puis nom, demande nulle écartée")
  ck(Id.barre(3, 100, 32) == 1 and Id.barre(30, 100, 32) == 3 and Id.barre(30, 100, 2) == 2 and Id.barre(0, 100, 32) == 1
    and Id.barre(30, nil, 100) == 100, "1c. barre du coffre : cases pour " .. Id.HORIZON_MIN .. " minutes de demande, de 1 aux cases du coffre")
  local gt = "gun-turret"
  local pr, why = Id.profile(fab, gt, nil)
  ck(pr and pr.recipe == gt and pr.s == 3 and pr.machine.entity == "assembling-machine-3" and pr.par_min > 0, "1d. profil d'un objet à 3 entrées : la machine la plus rapide")
  local only1 = { ["assembling-machine-2"] = true }
  local pr1 = Id.profile(fab, gt, only1)
  ck(pr1 and pr1.machine.entity == "assembling-machine-2" and pr1.par_min <= pr.par_min, "1e. machine utilisable : seule la deuxième, pas la plus rapide du jeu")
  local pn, whyn = Id.profile(fab, "plastic-bar", nil)
  ck(pn == nil and whyn:find("limite", 1, true) ~= nil, "1f. un objet à fluide sans boîte : refus écrit « limite »")
  local pu, whyu = Id.profile(fab, "objet-inconnu", nil)
  ck(pu == nil and whyu:find("aucune recette", 1, true) ~= nil, "1g. objet sans recette : refus écrit")
  local pz, whyz = Id.profile(fab, gt, {})
  ck(pz == nil and whyz:find("recherche", 1, true) ~= nil, "1h. aucune machine utilisable : « recherche »")
  -- décisions
  local par = pr.par_min
  local st = { first = {} }
  local function decide(sources, tick, served)
    return Id.decide(st, { tick = tick, sources = { sources }, fab = fab, served = served, usable = nil, bloc_max = 8 })
  end
  local out = decide({ { item = gt, rate = par, src = "main" } }, 100)
  ck(#out.rows == 1 and out.rows[1].item == gt and out.rows[1].n == 2 and #out.blocs == 0 and #out.wait == 0,
    "1i. un débit qui veut 2 machines : une RANGÉE de 2 copies (" .. #out.rows .. ")")
  local out2 = decide({ { item = gt, rate = par * 0.2, src = "refus" } }, 200)
  ck(#out2.rows == 0 and #out2.wait == 1 and #out2.blocs == 0, "1j. 0,4 machine voulue : ni rangée ni bloc encore (un seul objet), il attend")
  local out2b = decide({ { item = gt, rate = par * 0.3, src = "refus" } }, 250)
  ck(#out2b.rows == 1 and out2b.rows[1].n == 1 and #out2b.wait == 0, "1j2. 0,3 machine de demande, 0,6 avec l'avance : une rangée d'une copie (le seuil se lit sur la capacité visée)")
  local stw = { first = {} }
  local lw = Id.profile(fab, "iron-chest", nil)
  local srcw = { { item = "iron-chest", rate = lw.par_min * 0.05, src = "refus" } }
  Id.decide(stw, { tick = 5, sources = { srcw }, fab = fab, bloc_max = 8 })
  local had = stw.first["iron-chest"]
  Id.decide(stw, { tick = 9, sources = { {} }, fab = fab, bloc_max = 8 })
  ck(had == 5 and stw.first["iron-chest"] == nil, "1j3. un objet qui n'est plus demandé oublie son attente")
  -- trois objets sous une demi-machine : un bloc
  local lows = {}
  for _, it in ipairs({ "firearm-magazine", "iron-chest", "iron-gear-wheel", "pipe" }) do
    local p = Id.profile(fab, it, nil)
    lows[#lows + 1] = { item = it, rate = p.par_min * 0.1, src = "refus" }
  end
  local st2 = { first = {} }
  local o3 = Id.decide(st2, { tick = 300, sources = { lows }, fab = fab, bloc_max = 8 })
  ck(#o3.rows == 0 and #o3.blocs >= 1, "1k. des objets sous une demi-machine : un BLOC partagé (" .. #o3.blocs .. ")")
  local in_blocs = 0
  for _, b in ipairs(o3.blocs) do in_blocs = in_blocs + #b.items end
  ck(in_blocs + #o3.wait + #o3.seuls == #lows - #o3.refus, "1l. chaque objet est placé une fois : bloc, attente ou cellule seule")
  local st3 = { first = {} }
  local o4 = Id.decide(st3, { tick = 400, sources = { { lows[1], lows[2] } }, fab = fab, bloc_max = 8 })
  ck(#o4.blocs == 0 and #o4.wait == 2, "1m. deux objets seulement : pas de bloc (" .. Id.GROUP_MIN .. " au moins), ils attendent")
  local o5 = Id.decide(st3, { tick = 400 + Id.GROUP_WAIT, sources = { { lows[1], lows[2] } }, fab = fab, bloc_max = 8 })
  ck(#o5.blocs == 1 and #o5.blocs[1].items == 2, "1n. après " .. Id.GROUP_WAIT .. " ticks, le bloc s'ouvre pour les deux (personne n'attend sans fin)")
  local o6 = Id.decide({ first = {} }, { tick = 10, sources = { lows }, fab = fab, bloc_max = 2 })
  local full = false
  for _, b in ipairs(o6.blocs) do if #b.items == 2 then full = true end end
  ck(full, "1o. un bloc plein (plafond de machines du bloc) s'ouvre sans attendre")
  local o7 = decide({ lows[1], lows[2], lows[3] }, 500, { [lows[1].item] = true })
  local flat = {}
  for _, b in ipairs(o7.blocs) do for _, it in ipairs(b.items) do flat[it] = true end end
  for _, w in ipairs(o7.wait) do flat[w.item] = true end
  ck(not flat[lows[1].item], "1p. un objet déjà servi (machine posée ou module ouvert) n'est pas redécidé")
  local big = first_with(function(e) return e.s > 4 end)
  if big then
    local pb = Id.profile(fab, big, nil)
    local ob = Id.decide({ first = {} }, { tick = 10 + Id.GROUP_WAIT, sources = { { { item = big, rate = pb.par_min * 0.05, src = "refus" } } }, fab = fab, bloc_max = 8 })
    -- l'objet attend d'abord (aucun bloc ne le porte : plus de 4 entrées), puis il devient une cellule seule
    local sb = { first = { [big] = 10 } }
    local ob2 = Id.decide(sb, { tick = 10 + Id.GROUP_WAIT, sources = { { { item = big, rate = pb.par_min * 0.05, src = "refus" } } }, fab = fab, bloc_max = 8 })
    ck(#ob2.seuls == 1 and ob2.seuls[1].item == big and #ob2.blocs == 0, "1q. plus de 4 entrées sous une demi-machine : une cellule seule, une machine (" .. #ob2.seuls .. ")")
    local ob3 = Id.decide({ first = {} }, { tick = 10, sources = { { { item = big, rate = pb.par_min * 0.05, src = "refus" } } }, fab = fab, bloc_max = 8 })
    ck(#ob3.seuls == 0 and #ob3.wait == 1, "1q2. ... mais après l'attente seulement")
  end
  local ofl = decide({ { item = "plastic-bar", rate = 5, src = "refus" }, { item = "objet-inconnu", rate = 5, src = "main" } }, 600)
  ck(#ofl.refus == 2 and ofl.refus[1].item == "objet-inconnu" and ofl.refus[2].item == "plastic-bar", "1r. refus écrits, triés (fluide, sans recette)")
  -- déterminisme : listes inversées
  local rev = {}
  for i = #lows, 1, -1 do rev[#rev + 1] = lows[i] end
  local oa = Id.decide({ first = {} }, { tick = 700, sources = { lows }, fab = fab, bloc_max = 8 })
  local ob_ = Id.decide({ first = {} }, { tick = 700, sources = { rev }, fab = fab, bloc_max = 8 })
  ck(Id.describe(oa) == Id.describe(ob_) and #oa.blocs == #ob_.blocs and (#oa.blocs == 0 or table.concat(oa.blocs[1].items, ",") == table.concat(ob_.blocs[1].items, ",")),
    "1s. déterminisme : mêmes décisions, listes d'entrée inversées")
  local function no_fn(t, seen)
    seen = seen or {}
    if seen[t] then return true end
    seen[t] = true
    for _, v in pairs(t) do
      if type(v) == "function" then return false end
      if type(v) == "table" and not no_fn(v, seen) then return false end
    end
    return true
  end
  ck(no_fn(st) and no_fn(st2), "1t. état sans fonction (sauvegarde)")
  ck(Id.describe(out):find("1 rangee", 1, true) ~= nil, "1u. journal : « 1 rangee »")
  -- NOMS PERMUTÉS : toutes les chaînes du relevé préfixées ; mêmes formes
  local function ren(s) return "pz-" .. s end
  local fab2 = {}
  for _, rn in ipairs(sorted_keys(fab)) do
    local e = fab[rn]
    local c = {}
    for k, v in pairs(e) do c[k] = v end
    c.produits = {}
    for i, p in ipairs(e.produits) do c.produits[i] = ren(p) end
    c.solides = {}
    for i, s in ipairs(e.solides) do c.solides[i] = { name = ren(s.name), amount = s.amount } end
    c.machines = {}
    for i, m in ipairs(e.machines) do
      local mm = {}
      for k, v in pairs(m) do mm[k] = v end
      mm.entity, mm.item = ren(m.entity), ren(m.item)
      c.machines[i] = mm
    end
    fab2[ren(rn)] = c
  end
  local lows2 = {}
  for i, c in ipairs(lows) do lows2[i] = { item = ren(c.item), rate = c.rate, src = c.src } end
  local op = Id.decide({ first = {} }, { tick = 300, sources = { lows2 }, fab = fab2, bloc_max = 8 })
  local shape = function(o) local t = {} for _, b in ipairs(o.blocs) do t[#t + 1] = #b.items end table.sort(t) return table.concat(t, ",") .. "|" .. #o.rows .. "|" .. #o.wait .. "|" .. #o.seuls .. "|" .. #o.refus end
  ck(shape(op) == shape(o3), "1v. noms permutés : mêmes formes (" .. shape(op) .. " contre " .. shape(o3) .. ")")
  return fails
end

print("== 1. Règle pure")
local Id = require("shared.ai3.industrie")
battery_id(Id, true)

---------------------------------------------------------------------------------------------------
-- §2 A.method_for
---------------------------------------------------------------------------------------------------
local function load_auto(path)
  if not path then
    package.loaded["shared.ai3.automatiser"] = nil
    return require("shared.ai3.automatiser")
  end
  return dofile(path)
end

local function battery_auto(A, verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 end
    if verbose then check(c, msg) end
  end
  A.reset_cache()
  A.set_lecture_provider(nil)
  local m0, w0 = A.method_for("gun-turret", book)
  ck(m0 == nil and w0:find("3 ingredients", 1, true) ~= nil, "2a. sans lecture : le refus d'avant (« 3 ingredients »)")
  local lec = lecture_of(fab, machines, kd)
  A.set_lecture_provider(function() return lec end)
  local m1, w1 = A.method_for("gun-turret", book)
  ck(m1 and m1.gen == "patron" and m1.patron and m1.generic and m1.product == "gun-turret", "2b. avec la lecture : un patron pour 3 entrées (" .. tostring(w1) .. ")")
  local g1 = m1 and A.template(m1.gen, m1.args)
  ck(g1 and g1.nominal["gun-turret"] and g1.nominal["gun-turret"] > 0 and g1.ext and g1.ext.max >= 2, "2c. son gabarit passe le contrôle, un débit nominal, une extension")
  local sz, args = A.sized(m1, 3.0)
  ck(sz and args[4] >= 2 and args[4] <= g1.ext.max, "2d. A.sized dimensionne la rangée sur le débit (n = " .. tostring(args and args[4]) .. ")")
  ck(A.method_for("gun-turret", book) == m1, "2e. la même méthode revient (mémo : les mémos aval la retrouvent)")
  local gx, whyx = M.GEN.patron("assembling-machine-2", { name = "x", ingredients = 5, products = 5 }, "tapis", 1, m1.args[5], 0)
  ck(gx == nil and tostring(whyx):find("erreur interne", 1, true) ~= nil, "2e2. une erreur interne du patron devient (nil, raison), elle n'arrête pas le jeu")
  local mc = A.method_for("iron-chest", book)
  ck(mc and mc.patron, "2f. une rangée simple dont le gabarit est refusé (8 plaques par fabrication) cède au patron")
  local mf, wf = A.method_for("plastic-bar", book)
  ck(mf == nil and wf and wf:find("limite", 1, true), "2g. un objet à fluide reste refusé, raison écrite")
  local mg = A.method_for("iron-gear-wheel", book)
  ck(mg and mg.gen == "gears", "2h. un gabarit écrit garde sa place (engrenages)")
  local mm = A.method_for("firearm-magazine", book)
  ck(mm and mm.gen == "simple" and not mm.patron, "2i. un gabarit écrit (chargeur) garde sa place")
  -- recettes que l'exécutant sait lancer
  local runs = A.exec_recipes(dump.recipes)
  ck(runs["assembling-machine-3"] == nil or runs["assembling-machine-3"]["gun-turret"] ~= nil or runs["assembling-machine-2"] ~= nil or true, "2j. (exec_recipes appelée)")
  local found = false
  for _, ent in ipairs(sorted_keys(runs)) do if runs[ent]["gun-turret"] then found = true end end
  ck(found, "2k. l'exécutant sait lancer la recette à 3 entrées (exec_recipes)")
  local ents = A.exec_entities()
  local has_am3 = false
  for _, e in ipairs(ents) do if e == "assembling-machine-3" then has_am3 = true end end
  ck(has_am3, "2l. exec_entities compte les machines des patrons")
  -- le mod : une machine inventée, plus rapide, est choisie sans une ligne de code
  local dm = vanilla(true)
  local fabm, machm = L.read(dm, {})
  local kdm = L.kit_data(dm)
  A.reset_cache()
  local lecm = lecture_of(fabm, machm, kdm)
  A.set_lecture_provider(function() return lecm end)
  local mmod = A.method_for("gun-turret", book)
  ck(mmod and mmod.args[1] == "zz-mod-assembler", "2m. la machine d'un mod (4 x 4, plus rapide) est choisie (" .. tostring(mmod and mmod.args[1]) .. ")")
  local gm = mmod and A.template(mmod.gen, mmod.args)
  ck(gm and gm.n_ent > 0, "2n. son gabarit se construit (machine 4 x 4 déclarée à M)")
  -- « chargement » : M.BASE est reconstruit, la déclaration vient des arguments
  M.BASE["zz-mod-assembler"] = nil
  M.epoch_index()["zz-mod-assembler"] = nil
  A.reset_cache()
  local gm2 = mmod and A.template(mmod.gen, mmod.args)
  ck(gm2 and gm2.n_ent == (gm and gm.n_ent), "2o. après un chargement (M.BASE sans la machine), les arguments la redéclarent")
  -- le BLOC d'un mod : la machine inventée est redéclarée par les arguments du bloc aussi (chargement)
  local kitm = A.patron_kit(lecm, nil)
  local mach = nil
  for _, mm in ipairs(fabm["iron-chest"].machines) do if mm.entity == "zz-mod-assembler" then mach = mm end end
  local recs = {}
  for _, rn in ipairs({ "iron-chest", "iron-stick", "pipe" }) do
    local r = dump.recipes[rn]
    recs[#recs + 1] = { name = rn, category = r.category, energy = r.energy, ingredients = r.ingredients, products = r.products }
  end
  local kb = {}
  for kk, v in pairs(kitm) do kb[kk] = v end
  kb.decl = { kit = kitm.decl.kit, machines = { { machine = mach, categories = { "crafting" } } } }
  M.BASE["zz-mod-assembler"] = nil
  M.epoch_index()["zz-mod-assembler"] = nil
  A.reset_cache()
  local gb, whyb = A.template("bloc", { "zz-mod-assembler", recs, kb, 4 })
  ck(gb and gb.n_ent > 0, "2u. un BLOC avec la machine d'un mod se construit après un chargement (" .. tostring(whyb) .. ")")
  local mu = A.method_for("gun-turret", book, { ["assembling-machine-2"] = true })
  ck(mu and mu.args[1] == "assembling-machine-2", "2p. machine utilisable : la plus rapide débloquée, pas la plus rapide du jeu (" .. tostring(mu and mu.args[1]) .. ")")
  ck(mu ~= mmod, "2q. clés de cache distinctes selon la machine")
  local mnone = A.method_for("gun-turret", book, {})
  ck(mnone and mnone.patron, "2r. aucune machine débloquée : la méthode existe quand même (la recherche qui les débloque est demandée)")
  ck(mu and mu.args[5].coffre == A.exec_chest() and A.exec_chest() ~= nil, "2s. le coffre de sortie d'un patron est celui du plan directeur (lu à P.out_quai)")
  local alt = {}
  for i, a in ipairs(mu.args) do alt[i] = a end
  local kit2 = {}
  for k, v in pairs(mu.args[5]) do kit2[k] = v end
  kit2.bras = "fast-inserter"
  alt[5] = kit2
  local ga, gb = A.template(mu.gen, mu.args), A.template(mu.gen, alt)
  ck(ga and gb and ga ~= gb, "2t. deux kits différents ne partagent pas le même gabarit en mémo")
  A.set_lecture_provider(nil)
  A.reset_cache()
  return fails
end

print("== 2. A.method_for")
local A = require("shared.ai3.automatiser")
battery_auto(A, true)

---------------------------------------------------------------------------------------------------
-- §3 Em.mall
---------------------------------------------------------------------------------------------------
local function battery_em(Em, verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 end
    if verbose then check(c, msg) end
  end
  local s0 = Em.mall({ mods = {}, tick = 0 })
  ck(s0.cap == 1 and s0.room == 1 and not s0.busy, "3a. un emplacement de mall, libre")
  local s1 = Em.mall({ mods = { { key = 1, states = { "chantier" }, progress_tick = 0, opened = 0 } }, tick = 100 })
  ck(s1.room == 0 and s1.busy and s1.counted == 1, "3b. un bloc en chantier tient l'emplacement")
  local s2 = Em.mall({ mods = { { key = 1, states = { "chantier" }, progress_tick = 0, opened = 0 } }, tick = Em.STALL + 10 })
  ck(s2.room == 1 and s2.free == 1, "3c. un bloc figé libère l'emplacement")
  local s3 = Em.mall({ mods = { { key = 1, states = { "reserve" }, opened = 0, pile_tick = 0 } }, tick = Em.PILE_HOLD + 10 })
  ck(s3.room == 1 and s3.free == 1, "3d. un bloc suspendu par la pile libère l'emplacement")
  local s4 = Em.mall({ mods = { { key = 1, states = { "reserve" }, opened = 0 } }, tick = Em.PILE_HOLD + 10 })
  ck(s4.room == 0, "3e. un bloc qui attend sa matière (non suspendu) tient l'emplacement")
  ck(Em.mall({ mods = {}, tick = 0, base = 3 }).cap == 3 and Em.mall(nil).cap == 1, "3f. plafond réglable, entrée vide tolérée")
  -- les fonderies et chaînes ne le consomment pas : Em.slots reste inchangé
  local sl = Em.slots({ base = 2, plates = {}, mods = { { key = 1, states = { "chantier" }, progress_tick = 0, opened = 0 } }, tick = 10 })
  ck(sl.room == 1, "3g. Em.slots ne compte pas le mall (emplacements des fonderies inchangés)")
  return fails
end
print("== 3. Em.mall")
battery_em(require("shared.ai3.emplacements"), true)

---------------------------------------------------------------------------------------------------
-- §4 mutants
---------------------------------------------------------------------------------------------------
print("== 4. Mutants")
local function slurp(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local killed, total = 0, 0
local function mutate(file, from, to, name, runner)
  total = total + 1
  local src = slurp(file)
  local i, j = src:find(from, 1, true)
  if not i then check(false, "mutant '" .. name .. "' : texte introuvable") return end
  local tmp = os.tmpname()
  local f = assert(io.open(tmp, "wb")) f:write(src:sub(1, i - 1) .. to .. src:sub(j + 1)) f:close()
  local ok, n = pcall(runner, tmp)
  os.remove(tmp)
  if not ok or (type(n) == "number" and n > 0) then killed = killed + 1 else check(false, "mutant survivant : " .. name) end
end
local function run_id(tmp) return battery_id(dofile(tmp), false) end
local function run_em(tmp) return battery_em(dofile(tmp), false) end
local function run_auto(tmp)
  -- les générateurs d'origine (le chargement du module les enveloppe : un mutant qui ne les enveloppe pas doit être vu)
  local o = rawget(M.GEN, "patron_orig")
  M.GEN.patron, M.GEN.bloc = o.patron, o.bloc
  local Am = dofile(tmp)
  return battery_auto(Am, false)
end
local ID = "shared/ai3/industrie.lua"
mutate(ID, 'x = why:match("^manque sous une demi%-machine %(([%d%.]+)/min%)")', 'x = why:match("(%d+)")', "refus : n'importe quel nombre", run_id)
mutate(ID, "elseif c.rate > cur.rate then", "elseif c.rate < cur.rate then", "fusion : le minimum", run_id)
mutate(ID, "cur.rate = c.rate\n        end", "cur.rate = cur.rate + c.rate\n        end", "fusion : la somme", run_id)
mutate(ID, "if type(slots) == \"number\" and slots >= 1 and n > slots then n = slots end", "", "barre : plafond du coffre retiré", run_id)
mutate(ID, "for _, m in ipairs(entry and entry.machines or {}) do", "for _, m in ipairs({}) do", "machine : aucune choisie", run_id)
mutate(ID, "if ok then best = m end", "best = best or m", "machine : la plus lente", run_id)
mutate(ID, "if #(e.fluides_in or {}) > 0 then", "if false then", "fluide accepté", run_id)
mutate(ID, "if need >= Id.ROW_MIN - Id.EPS then", "if need >= 0 then", "tout en rangée", run_id)
mutate(ID, "if need >= Id.ROW_MIN - Id.EPS then", "if need >= 100 then", "tout en bloc", run_id)
mutate(ID, "local need = c.rate * Id.LEAD / pr.par_min", "local need = c.rate / pr.par_min", "besoin sans avance (LEAD)", run_id)
mutate(ID, "if #bl.objets >= Id.GROUP_MIN or #bl.objets >= cap or waited >= Id.GROUP_WAIT then", "if true then", "bloc ouvert tout de suite", run_id)
mutate(ID, "if #bl.objets >= Id.GROUP_MIN or #bl.objets >= cap or waited >= Id.GROUP_WAIT then", "if #bl.objets >= Id.GROUP_MIN or #bl.objets >= cap then", "attente sans fin", run_id)
mutate(ID, "if inp.served and inp.served[c.item] then", "if false then", "objet servi redécidé", run_id)
mutate(ID, "if o.s > P.BLOC_VOIES then", "if false then", "plus de 4 entrées dans un bloc", run_id)
mutate(ID, "if waited >= Id.GROUP_WAIT then\n        out.seuls", "if true then\n        out.seuls", "cellule seule sans attente", run_id)
mutate(ID, "return a.rate > b.rate end\n    return a.item < b.item", "return a.rate < b.rate end\n    return a.item < b.item", "fusion : ordre inversé", run_id)
mutate(ID, "and c.rate > Id.EPS then", "then", "demande nulle acceptée", run_id)
mutate(ID, "for _, k in ipairs(sorted_keys(st.first)) do if not seen[k] then st.first[k] = nil end end", "", "attente d'un objet disparu gardée", run_id)
local EM = "shared/ai3/emplacements.lua"
mutate(EM, 'if c == "fige" or c == "pile" then free = free + 1 else counted = counted + 1 end', "counted = counted + 1", "bloc figé tient l'emplacement", run_em)
mutate(EM, "Em.MALL_SLOTS = 1      -- lot", "Em.MALL_SLOTS = 0      -- lot", "aucun emplacement de mall", run_em)
local AU = "shared/ai3/automatiser.lua"
mutate(AU, 'if meth and not (meth.generic and not A.template(meth.gen, meth.args)) then return meth end', "if meth then return meth end", "rangée refusée gardée", run_auto)
mutate(AU, "for i = #ms, 1, -1 do", "for i = 1, #ms do", "patron : la machine la plus lente", run_auto)
mutate(AU, "if #ms == 0 then ms = e.machines end", "", "patron : aucune machine à défaut d'utilisable", run_auto)
mutate(AU, 'if m.patron then add(m.args[1], m.args[2].name) else add(m.args[3], m.args[1].name) end', "add(m.args[3], m.args[1].name)", "exec_recipes : patron oublié", run_auto)
mutate(AU, "if type(kit) == \"table\" then declare(kit.decl) end\n      return Pt.cellule", "return Pt.cellule", "patron : déclaration au chargement oubliée", run_auto)
mutate(AU, "if type(kit) == \"table\" then declare(kit.decl) end\n      return Pt.bloc", "return Pt.bloc", "bloc : déclaration au chargement oubliée", run_auto)
mutate(AU, "local ok, tpl, why = pcall(fn, ...)", "local ok, tpl, why = true, fn(...)", "générateur sans filet (une erreur interne arrête le jeu)", run_auto)
mutate(AU, 'parts[#parts + 1] = "kit{" .. table.concat(ks, ",") .. "}"', 'parts[#parts + 1] = "kit"', "clé de cache : le kit oublié", run_auto)
mutate(AU, 'if chest and M.BASE[chest] and M.BASE[chest].kind == "chest" then names.coffre = chest end', "", "coffre du plan directeur oublié", run_auto)
print(string.format("   mutants refusés : %d / %d", killed, total))
check(killed == total, "tous les mutants refusés")
print(string.format("[INDUSTRIE-I6] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", pass, fail, killed, total))
os.exit(fail == 0 and 0 or 1)
