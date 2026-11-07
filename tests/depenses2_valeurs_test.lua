--[[
  Lot DEPENSES2 (relecture de 26268e60, réserve sérieuse du lead) : votre équipe ne paie JAMAIS ses soldats avant son fer vital.
  Banc HORS JEU du cerveau pur (shared/ai3/cerveau.lua C.think : la pensée que le runtime appelle, avec B.generate, A.goals, P.update
  et P.emit) ; lancement : lua5.2 tests/depenses2_valeurs_test.lua (depuis la racine du mod).

  Défaut (26268e60) : les buts « armée » de votre équipe reprenaient ceux des factions : premiers soldats à 58 (devant la réserve de
  chargeurs 55, la croissance 55, la fonderie 45), × 1,5 SOUS MENACE (87 : devant la recherche 62, les modules et la centrale d'AUTO 64
  à 90), « minimaux » (jamais retenus par « production d'abord ») ; et une famille PERMANENTE est servie juste après le premier projet
  (P.update), devant tous les autres : un lot de 5 soldats (250 fer) passait avant la centrale.

  1. Valeurs (B.generate) : votre équipe, menace, alerte ou non : B.ARMY_PLAYER (42), pas « minimal », servie tard (`late`) ;
     l'« encore » aussi ; les factions inchangées (87 en guerre, 86 en alerte, minimales).
  2. Cerveau entier (C.think), fer juste, menace, centrale à payer : la centrale (boiler, 2 steam-engine) est fabriquée, le lot de
     soldats attend (manque de fer porté par l'armée, pas par la centrale) ; avec la recherche plafonnée (centrale à 43) aussi.
  3. Le fer revient : le premier lot de soldats est payé (la règle ne les affame pas).
  4. Mutants (texte de shared/ai3/buts.lua et shared/ai3/projets.lua) : × 1,5 rendu, valeur des factions rendue, « minimal » rendu,
     ordre de service d'avant ; chacun doit faire échouer le banc.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local S = require("shared.team.scale")

local passes, failures, quiet = 0, 0, false
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end

local function read(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end
local SRC_B, SRC_P = read("shared/ai3/buts.lua"), read("shared/ai3/projets.lua")

--- Charge buts et projets depuis leur texte (mutants), puis le cerveau qui les lit.
local function load_brain(src_b, src_p)
  package.loaded["shared.ai3.buts"] = assert(load(src_b, "=buts"))()
  package.loaded["shared.ai3.projets"] = assert(load(src_p, "=projets"))()
  package.loaded["shared.ai3.cerveau"] = nil
  local C = require("shared.ai3.cerveau")
  return package.loaded["shared.ai3.buts"], C
end

local book = Book.new(dofile("tests/fixtures/recipes.lua"))
local MAG = "firearm-magazine"

local function view(over)
  local v = {
    tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {}, outposts = {},
    pending = {}, sites = { coal = 1, iron = 1, copper = 1, stone = 1 }, smelters = 2, smelters_pending = 0, smelter_task = false,
    smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0, turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 10,
    workers_max = 30, workers_idle = 10, threatened = false, open = {}, workers_wanted = 10, no_research = true,
    ladder = T.player_ladder, hq_turrets = 0, defend_first = false, is_player = true, army_cap = 30,
  }
  for k, x in pairs(over or {}) do v[k] = x end
  if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
  return v
end
local function op(id, kind, over)
  local o = { id = id, kind = kind, drills = T.outposts[kind].drills, full = true, turrets = 1, coal_needed = 0, fuel_low = false,
    output = 50, idle_ticks = 0, has_task = false, has_fortify = false }
  for k, x in pairs(over or {}) do o[k] = x end
  return o
end
local OUTPOSTS = { op(1, "iron"), op(2, "iron"), op(3, "coal"), op(4, "coal"), op(5, "copper"), op(6, "stone") }
local CENTRALE = { product = "centrale", state = "reserve", missing = { { "boiler", 1 }, { "steam-engine", 2 } }, gain = 0 }

--- Une pensée de votre équipe : `iron` plaques de fer au coffre, menace, centrale à payer (sauf `no_plant`), recherche plafonnée
--- (`research`), armée visée 10 (0 avec `no_army` : la même pensée sans soldats, pour comparer). Rend le plan, l'état et les projets
--- par clé.
local function think(B, C, o)
  local st = C.new_state(0)
  local stock = { ["iron-plate"] = o.iron, ["copper-plate"] = 300, stone = 400, coal = 400, ["stone-furnace"] = 4, [MAG] = 200 }
  local v = view({ stock = stock, outposts = OUTPOSTS, threatened = true, soldiers = o.soldiers or 0 })
  local ctx = { tick = 0, is_player = true, weights = B.weights({}, nil), army_target = o.no_army and 0 or 10, at_war = true,
    reach = { ["iron-ore"] = 60, coal = 60, stone = 60, ["copper-ore"] = 60 },
    auto = (not o.no_plant) and { mods = { CENTRALE } } or nil,
    research = o.research and { tech = "turrets", payable = true, packs = { { "automation-science-pack", 10 } }, iron_cost = 500 } or nil }
  local plan = C.think(v, book, st, ctx)
  local by = {}
  for _, p in ipairs(st.projects) do by[p.key] = p end
  return plan, st, by
end
local function crafted(plan, item)
  local n = 0
  for _, t in ipairs(plan.tasks) do if t.kind == "craft" and t.item == item then n = n + (t.count or 0) end end
  return n
end
local function army_goal(B, s)
  for _, g in ipairs(B.generate(s, { targets = { coal = 1, iron = 1, copper = 1, stone = 1 }, iron2_set = true })) do
    if g.kind == "army" then return g end
  end
  return nil
end
local function s_of(B, o)
  return { is_player = o.pl, workers = 8, soldiers = o.soldiers or 0, soldiers_max = o.pl and 0 or 30, army_cap = 30,
    stock = { [MAG] = 80 }, cap = { coal = 1, iron = 1, copper = 1, stone = 1 }, pending = {}, sites = {}, smelters = 4,
    smelters_pending = 0, weights = B.weights({}, nil), army_target = o.target or 10, economy_done = false, at_war = o.war,
    army_alert = o.alert or false, army_need = o.need or 0 }
end

local function body(B, C)
  section("1. Valeurs des buts « armée »")
  local pw = army_goal(B, s_of(B, { pl = true, war = true }))
  check(pw and pw.value == B.ARMY_PLAYER and pw.value < B.AMMO and pw.value < B.SMELTERS and pw.value < B.RESEARCH_PRE,
    "votre équipe, menace : premiers soldats à B.ARMY_PLAYER, sous chargeurs, fonderie, recherche plafonnée (" .. tostring(pw and pw.value) .. ")")
  check(pw and not pw.minimal and pw.late == true, "votre équipe : ni « minimal » ni servie avant les projets")
  local pa = army_goal(B, s_of(B, { pl = true, war = true, alert = true, need = 8 }))
  check(pa and pa.alert and pa.value == B.ARMY_PLAYER and not pa.minimal and pa.late == true,
    "votre équipe, vague annoncée : même valeur, ni minimale ni avant les projets (" .. tostring(pa and pa.value) .. ")")
  local pm = army_goal(B, s_of(B, { pl = true, war = true, soldiers = 10, target = 16 }))
  check(pm and pm.target == 16 and pm.value <= B.ARMY_PLAYER and pm.late == true,
    "votre équipe, encore (stock qui dort) : pas au-dessus de B.ARMY_PLAYER (" .. tostring(pm and pm.value) .. ")")
  local fw = army_goal(B, s_of(B, { pl = false, war = true, target = 18 }))
  check(fw and fw.value == math.floor(B.ARMY_FIRST * B.ARMY_WAR_PCT / 100) and fw.minimal and not fw.late,
    "factions inchangées : premiers soldats × 1,5 en guerre, minimaux (" .. tostring(fw and fw.value) .. ")")
  local fa = army_goal(B, s_of(B, { pl = false, war = true, alert = true, need = 25, target = 18 }))
  check(fa and fa.value == B.ARMY_ALERT and fa.minimal and not fa.late, "factions inchangées : alerte à B.ARMY_ALERT, minimale")

  section("2. Cerveau entier : fer juste, menace, centrale à payer")
  -- Fer juste : 140 plaques. Le planificateur permanent prend 68 fer (4 foreuses à combustion, 4 coffres) ; la centrale, boiler (4 fer)
  -- et 2 steam-engine (31 fer chacun), 66 ; un lot de 5 fusiliers (submachine-gun et 5 chargeurs chacun), 250.
  local plan, _, by = think(B, C, { iron = 140 })
  local ar, ce = by["armee"], by["auto:centrale"]
  check(ar ~= nil and ce ~= nil, "projets armée et centrale ouverts")
  check(crafted(plan, "steam-engine") == 2 and crafted(plan, "boiler") == 1,
    string.format("la centrale est fabriquée (steam-engine %d sur 2, boiler %d sur 1)", crafted(plan, "steam-engine"), crafted(plan, "boiler")))
  check(ce and ((ce.missing or {})["iron-plate"] or 0) == 0, "la centrale ne manque pas de fer (" .. tostring(ce and (ce.missing or {})["iron-plate"]) .. ")")
  check(ar and ((ar.missing or {})["iron-plate"] or 0) > 0 and plan.train == nil and crafted(plan, "submachine-gun") == 0,
    "le lot de soldats attend : c'est l'armée qui manque de fer (" .. tostring(ar and (ar.missing or {})["iron-plate"]) .. ")")
  -- Comparaison : la même pensée SANS soldats. Les soldats ne prennent rien de ce que la centrale reçoit, même quand la recherche
  -- plafonnée (44) la ramène à 43 et passe devant elle, et même avec moins de fer.
  for _, o in ipairs({ { iron = 140 }, { iron = 140, research = true }, { iron = 100, research = true }, { iron = 100 } }) do
    local pa, _, ba = think(B, C, o)
    local pn = think(B, C, { iron = o.iron, research = o.research, no_army = true })
    local cea = ba["auto:centrale"]
    local miss_a = cea and (cea.missing or {})["iron-plate"] or 0
    check(crafted(pa, "steam-engine") == crafted(pn, "steam-engine") and crafted(pa, "boiler") == crafted(pn, "boiler")
      and ba["armee"] ~= nil and (not o.research or (cea and cea.value > B.ARMY_PLAYER)),
      string.format("fer %d%s : la centrale reçoit autant avec soldats que sans (steam-engine %d contre %d, boiler %d contre %d, manque %d)",
        o.iron, o.research and ", recherche" or "", crafted(pa, "steam-engine"), crafted(pn, "steam-engine"), crafted(pa, "boiler"),
        crafted(pn, "boiler"), miss_a))
  end

  section("3. Le fer revient : le premier lot est payé")
  local plan3, _, by3 = think(B, C, { iron = 900 })
  check(crafted(plan3, "steam-engine") == 2 and ((by3["armee"].missing or {})["iron-plate"] or 0) == 0
    and crafted(plan3, "submachine-gun") >= 1,
    string.format("fer suffisant : centrale ET soldats (submachine-gun %d)", crafted(plan3, "submachine-gun")))
  local plan4 = think(B, C, { iron = 900, no_plant = true })
  check(crafted(plan4, "submachine-gun") >= 1, "sans centrale à payer : le lot de soldats part")
end

local B0, C0 = load_brain(SRC_B, SRC_P)
body(B0, C0)
local main_pass, main_fail = passes, failures

section("4. Mutants")
local killed, total = 0, 0
local function mutant(name, src_b, src_p, old, new)
  total = total + 1
  local which = src_b and "b" or "p"
  local src = src_b or src_p
  local i = src:find(old, 1, true)
  if not i then print("  mutant introuvable : " .. name) return end
  local mut = src:sub(1, i - 1) .. new .. src:sub(i + #old)
  quiet = true
  passes, failures = 0, 0
  local ok = pcall(function()
    local B, C = load_brain(which == "b" and mut or SRC_B, which == "p" and mut or SRC_P)
    body(B, C)
  end)
  quiet = false
  local caught = failures > 0 or not ok
  if caught then killed = killed + 1 end
  print(string.format("  mutant %s : %s", name, caught and "refusé" or "SURVIT"))
end
mutant("× 1,5 rendu à votre équipe", SRC_B, nil, "local pv = pl and math.min(B.ARMY_PLAYER, val(B.ARMY_PLAYER, w.armee)) or nil",
  "local pv = pl and math.floor(B.ARMY_PLAYER * war / 100) or nil")
mutant("valeur des factions rendue", SRC_B, nil, "local pv = pl and math.min(", "local pv = false and math.min(")
mutant("« minimal » rendu", SRC_B, nil, "local minimal = (not pl) or nil", "local minimal = true")
mutant("armée servie juste après le premier projet", nil, SRC_P,
  "if p.goal.late then late[#late + 1] = p else perm[#perm + 1] = p end", "perm[#perm + 1] = p")
mutant("armée de votre équipe sans « late »", SRC_B, nil,
  "permanent = true, minimal = minimal, late = pl or nil }", "permanent = true, minimal = minimal }")
load_brain(SRC_B, SRC_P)

passes, failures = main_pass + killed, main_fail + (total - killed)
print(string.format("[DEPENSES2-VALEURS] BILAN : %d OK, %d ECHEC(S) (dont %d mutants sur %d refusés)", passes, failures, killed, total))
