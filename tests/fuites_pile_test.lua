--[[
  Lot FUITES-PILE (vague 10) : banc HORS JEU des chemins qui contournaient la pile de priorité (shared/ai3/pile.lua, 0.6.19 ; DC
  29/10 : « on répare + protège (donc on s'adapte) et ensuite on continue et on améliore […] la pile de priorité ne s'applique pas
  qu'aux IA mais aussi au cerveau principal »). Lancement, depuis la racine du mod :
    lua5.2 tests/fuites_pile_test.lua

  Sections :
    1. porte pure (Pi.porte) : pile vide ; R1 suspend capital, capi, recherche, migration, amélioration des tapis ; exceptions :
       objet d'un cadre ouvert (focus), investissement de production d'une matière qui manque ; réparer jamais suspendu (même sous
       R0) ; familles d'un module (reconstruction, agrandissement, neuf, capitalisation, migration) et d'un ordre de la
       capitalisation ; refus notés une fois par épisode, bornés, oubliés quand la pile se vide ;
    2. reconstruction contre agrandissement (Sw.rebuilding, fuite b) : rouvert après sa dernière fin, jamais fini, pas d'agrandissement
       d'une ligne déjà réparée, murs rouverts sans date ; Sw.project_needs et Rr.partial_go suivent ;
    3. buts des modules (A.goals) : famille portée, module en reconstruction avant le neuf du même produit ;
    4. pensée pure (C.think) sous une retenue : module NEUF suspendu (refus noté), module EN RECONSTRUCTION gardé, module neuf d'une
       matière d'un cadre ouvert gardé ; pile vidée : le module neuf revient ;
    5. exécutant au moteur simulé réduit (script/team/build.lua) : réserve d'un module neuf suspendue (objets rendus, manques effacés,
       raison « pile », journal [FO-PILE] une fois), module rouvert pour reconstruction et pas d'agrandissement jamais suspendus,
       agrandissement de ligne suspendu (pièces plus demandées), pile vide : rien de suspendu ; famille posée sur un projet d'avant le
       lot (Build.tag) ;
    6. câblage (lecture des sources) : capitalisation (ordres neufs, pose de modules, ordre suspendu qui ne vieillit pas), automatisation
       (familles, horloge de réserve arrêtée, pièces d'agrandissement), plan directeur (réserve, ligne, tapis), migration ;
    7. mutants.
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local S = require("shared.team.scale")
local recipes = dofile("tests/fixtures/recipes.lua")
local book = Book.new(recipes)

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end
local function read(path) local fh = assert(io.open(path, "rb")) local s = fh:read("*a") fh:close() return s end

local IRON, ORE = T.outposts.iron.product, T.outposts.iron.resource
local NEW_PRODUCT = "stone-brick" -- produit d'un module neuf qu'aucune tourelle ne demande (fixture)

---------------------------------------------------------------------------------------------------
-- La batterie (rejouée sous chaque mutant).
---------------------------------------------------------------------------------------------------
local function battery(Pi, C, B, A, Sw, Rr)
  local SRC = { [ORE] = true, [IRON] = true }
  local function sig(over)
    local s = { sources = SRC, inputs = { [IRON] = ORE }, raw_need = {}, posts = {}, repair = {} }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
  end
  local hq = { id = "hq", have = 0, want = 4, why = "fer", raw = { [IRON] = 40 } }

  section("1. Porte pure (Pi.porte)")
  local empty = Pi.update(Pi.new(), sig(), 0)
  check(Pi.porte(empty, "capital", NEW_PRODUCT) == true and Pi.porte(empty, "upgrade") == true, "pile vide : tout passe")
  local st = Pi.update(Pi.new(), sig({ posts = { hq }, raw_need = { [IRON] = { n = 40, prio = 90 } } }), 0)
  check(st.hold and st.top == Pi.ADAPTER, "QG sous son minimum : la pile retient au rang s'adapter")
  local all_off = true
  for _, fam in ipairs({ "capital", "capi", "recherche", "migration", "upgrade", "foreuses" }) do
    if Pi.porte(st, fam, NEW_PRODUCT) then all_off = false end
  end
  check(all_off, "R1 : capital, capi, recherche, migration, tapis, foreuses suspendus pour un objet hors des cadres")
  local ok, why = Pi.porte(st, "capital", NEW_PRODUCT)
  check(not ok and type(why) == "string" and why:find("suspendu", 1, true) ~= nil, "le refus porte sa raison (" .. tostring(why) .. ")")
  check(Pi.porte(st, "capital", IRON) == true, "un module neuf d'une matière d'un cadre ouvert (fer des tourelles) passe")
  check(Pi.porte(st, "capital", NEW_PRODUCT, true) == true and Pi.porte(st, "capi", NEW_PRODUCT, true) == true
    and Pi.porte(st, "invest", NEW_PRODUCT, true) == true,
    "investissement de production d'une matière qui MANQUE : permis (« on investit dans la production de plus de ressources »)")
  check(Pi.porte(st, "recherche", NEW_PRODUCT, true) == false and Pi.porte(st, "upgrade", nil, true) == false
    and Pi.porte(st, "migration", NEW_PRODUCT, true) == false,
    "un manque n'ouvre ni la recherche, ni l'amélioration des tapis, ni la migration")
  check(Pi.porte(st, "reparer", NEW_PRODUCT) == true, "réparer n'est jamais suspendu")
  local s0 = Pi.update(Pi.new(), sig({ survive = "effectif" }), 0)
  check(s0.top == Pi.SURVIVRE and Pi.porte(s0, "reparer", NEW_PRODUCT) == true and Pi.porte(s0, "capital", NEW_PRODUCT) == false,
    "sous R0 aussi : réparer passe, l'amélioration non")
  check(Pi.module_family(true, true, true, "migration") == "reparer", "famille : reconstruction d'abord (même agrandie, capi ou migration)")
  check(Pi.module_family(false, false, false, "migration") == "migration", "famille : migration du champ")
  check(Pi.module_family(false, true, true, nil) == "invest", "famille : pas d'agrandissement d'une ligne = investissement")
  check(Pi.module_family(false, false, true, nil) == "capi" and Pi.module_family(false, false, nil, nil) == "capital",
    "famille : module neuf de la capitalisation, module neuf ordinaire")
  check(Pi.order_family("labos") == "recherche" and Pi.order_family("packs") == "recherche" and Pi.order_family("techno") == "recherche"
    and Pi.order_family("couvrir") == "capi" and Pi.order_family("equiper") == "capi", "familles des ordres de la capitalisation")
  -- refus notés
  local rs = Pi.update(Pi.new(), sig({ posts = { hq } }), 0)
  check(Pi.suspend(rs, "k1", "a") == true and Pi.suspend(rs, "k1", "a") == false and Pi.suspend(rs, "k2", "b") == true,
    "un refus est noté une fois par clé et par épisode")
  check(#rs.refus_out == 2 and rs.refus_n == 2 and rs.refus_out[1]:find("k1", 1, true) == 1, "refus en attente du journal, dans l'ordre")
  for i = 1, Pi.REFUS_OUT_MAX + 5 do Pi.suspend(rs, "b" .. i, "x") end
  check(#rs.refus_out == Pi.REFUS_OUT_MAX and (rs.refus_lost or 0) == 7, "refus en attente bornés (Pi.REFUS_OUT_MAX), le reste compté")
  Pi.update(rs, sig({ posts = { hq } }), 300)
  check(rs.refus and rs.refus.k1, "pile toujours retenue : les refus déjà écrits ne se répètent pas")
  Pi.update(rs, sig(), 600)
  check(rs.refus == nil and Pi.suspend(rs, "k1", "a") == true, "pile vidée : épisode fini, un refus futur est de nouveau écrit")

  section("2. Reconstruction contre agrandissement (Sw.rebuilding)")
  check(Sw.rebuilding({ reopened = 1, reopened_tick = 500, finished = 400 }) == true, "rouvert APRÈS sa fin : reconstruction")
  check(Sw.rebuilding({ reopened = 1, reopened_tick = 500 }) == true, "rouvert pendant sa construction (jamais fini) : reconstruction")
  check(Sw.rebuilding({ reopened = 2, reopened_tick = 500, finished = 900 }) == false,
    "agrandissement d'une ligne réparée une fois (date de réouverture d'AVANT la dernière fin) : pas une reconstruction")
  check(Sw.rebuilding({ reopened = 1 }) == false and Sw.rebuilding(nil) == false and Sw.rebuilding({ reopened_tick = 5 }) == false,
    "murs rouverts sans date, projet absent, jamais rouvert : pas une reconstruction")
  local grown = { reopened = 2, reopened_tick = 500, finished = 900, state = "reserve", stock = {},
    ents = { { built = false, item = "stone-furnace" } } }
  check(#Sw.project_needs(grown) == 0, "Sw.project_needs : un agrandissement ne retient pas les améliorations")
  grown.reopened_tick = 1000
  check(#Sw.project_needs(grown) == 1, "Sw.project_needs : une vraie reconstruction, si")
  check(Rr.partial_go({ reopened = 2, reopened_tick = 500, finished = 900 }) == false
    and Rr.partial_go({ reopened = 1, reopened_tick = 1000, finished = 900 }) == true,
    "Rr.partial_go : chantier sans toute sa matière pour une reconstruction seulement")

  section("3. Buts des modules (A.goals)")
  local auto = { mods = {
    { product = NEW_PRODUCT, state = "reserve", missing = { { "stone-furnace", 2 } }, pile = "capital" },
    { product = NEW_PRODUCT, state = "reserve", missing = { { "iron-gear-wheel", 3 } }, pile = "reparer" },
    { product = IRON, state = "reserve", missing = {}, pile = "capital" },
    { product = "centrale", state = "reserve", missing = {} },
  } }
  local gs = A.goals({}, auto, nil, nil)
  local by = {}
  for _, g in ipairs(gs) do by[g.key] = g end
  check(by["auto:" .. NEW_PRODUCT] and by["auto:" .. NEW_PRODUCT].pile == "reparer"
    and by["auto:" .. NEW_PRODUCT].missing[1][1] == "iron-gear-wheel",
    "deux modules du même produit : le but est celui de la RECONSTRUCTION (ses pièces à refaire)")
  check(by["auto:" .. IRON] and by["auto:" .. IRON].pile == "capital", "la famille du module neuf est portée par son but")
  check(by["auto:centrale"] and by["auto:centrale"].pile == nil, "centrale : aucune famille (jamais suspendue)")

  section("4. Pensée pure (C.think) sous une retenue")
  local function view(over)
    local v = {
      tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {}, outposts = {},
      pending = {}, sites = {}, smelters = 2, smelters_pending = 0, smelter_task = false, smelter_output = 0,
      smelter_fuel_low = false, smelter_coal = 0, turret_groups = {}, soldiers = 0, soldiers_max = 0, workers = 10,
      workers_max = 30, workers_idle = 2, threatened = false, open = {}, workers_wanted = 10, no_research = true,
      ladder = T.player_ladder, hq_turrets = 0, defend_first = true, is_player = true,
    }
    for k, x in pairs(over or {}) do v[k] = x end
    if v.recruit_cost == nil then v.recruit_cost = S.recruit_cost(v.workers) end
    return v
  end
  local function op(id, kind)
    return { id = id, kind = kind, drills = T.outposts[kind].drills, full = false, turrets = 8, coal_needed = 0, fuel_low = false,
      output = 0, idle_ticks = 0, has_task = false, has_fortify = false }
  end
  local outs = { op(1, "iron"), op(2, "coal"), op(3, "copper") }
  local stock = { [IRON] = 60, [T.outposts.copper.product] = 200, [T.turret_ammo] = 100, [T.fuel] = 400, stone = 300 }
  local function has_project(stc, key)
    for _, p in ipairs(stc.projects or {}) do if p.key == key then return true end end
    return false
  end
  local function ctx(tick, mods)
    return { tick = tick, is_player = true, weights = B.weights({}, nil), reach = { [ORE] = 60, [T.fuel] = 60 },
      auto = { mods = mods, cap = {}, covered = {}, feeds = {} } }
  end
  local new_mod = { product = NEW_PRODUCT, state = "reserve", missing = { { "stone-furnace", 4 } }, pile = "capital" }
  local sst = C.new_state(0)
  sst.targets = { iron = 1, coal = 1, copper = 1, stone = 0 }
  sst.iron2_set = true
  C.think(view({ outposts = outs, stock = stock }), book, sst, ctx(0, { new_mod }))
  check(sst.pile.hold and not has_project(sst, "auto:" .. NEW_PRODUCT),
    "QG sans tourelles : le module NEUF n'ouvre pas de projet (ses fours ne sont pas fabriqués)")
  check(sst.pile.refus and sst.pile.refus["auto:" .. NEW_PRODUCT], "son refus est noté pour le journal [FO-PILE]")
  local rst = C.new_state(0)
  rst.targets = { iron = 1, coal = 1, copper = 1, stone = 0 }
  rst.iron2_set = true
  local rebuilt = { product = NEW_PRODUCT, state = "reserve", missing = { { "stone-furnace", 4 } }, pile = "reparer" }
  C.think(view({ outposts = outs, stock = stock }), book, rst, ctx(0, { rebuilt }))
  check(rst.pile.hold and has_project(rst, "auto:" .. NEW_PRODUCT), "même retenue : le module EN RECONSTRUCTION garde son projet")
  local ist = C.new_state(0)
  ist.targets = { iron = 1, coal = 1, copper = 1, stone = 0 }
  ist.iron2_set = true
  C.think(view({ outposts = outs, stock = stock }), book, ist, ctx(0, { { product = IRON, state = "reserve",
    missing = { { "stone-furnace", 4 } }, pile = "capital" } }))
  check(ist.pile.hold and has_project(ist, "auto:" .. IRON), "un module neuf du fer des tourelles (cadre ouvert) passe")
  local rich = {}
  for k, n in pairs(stock) do rich[k] = n end
  rich[IRON] = 900
  C.think(view({ outposts = outs, stock = rich, hq_turrets = T.defend_hq }), book, sst, ctx(3000, { new_mod }))
  check(not sst.pile.hold and has_project(sst, "auto:" .. NEW_PRODUCT), "QG pourvu : la pile se vide, le module neuf reprend")
end

---------------------------------------------------------------------------------------------------
-- Chargement (normal ou muté).
---------------------------------------------------------------------------------------------------
local MODS = { "shared.ai3.pile", "shared.ai3.buts", "shared.ai3.cerveau", "shared.ai3.automatiser", "shared.team.rebuild_sweep",
  "shared.team.rebuild_rapide" }
local function fresh(mut)
  for _, m in ipairs(MODS) do package.loaded[m] = nil end
  if mut then
    local src = read(mut.file)
    local i, j = src:find(mut.from, 1, true)
    assert(i, "mutant introuvable : " .. mut.name)
    assert(not src:find(mut.from, j + 1, true), "mutant ambigu : " .. mut.name)
    src = src:sub(1, i - 1) .. mut.to .. src:sub(j + 1)
    package.loaded[mut.mod] = assert(load(src, "@" .. mut.file))()
  end
  return require("shared.ai3.pile"), require("shared.ai3.cerveau"), require("shared.ai3.buts"), require("shared.ai3.automatiser"),
    require("shared.team.rebuild_sweep"), require("shared.team.rebuild_rapide")
end

battery(fresh(nil))

---------------------------------------------------------------------------------------------------
section("5. Exécutant au moteur simulé réduit (script/team/build.lua)")
---------------------------------------------------------------------------------------------------
local Mk = require("tests.mock_engine")
Mk.new_game({})
local Build = require("script.team.build")
local Stock = require("script.team.stock")
local Pi5 = require("shared.ai3.pile")
local real_log, real_insert = log, Stock.insert
local LOGS = {}
log = function(s) LOGS[#LOGS + 1] = s end
local COFFRE = {}
Stock.insert = function(_, it, n) COFFRE[it] = (COFFRE[it] or 0) + n return n end
local function n_logs(pat)
  local n = 0
  for _, l in ipairs(LOGS) do if l:find(pat, 1, true) then n = n + 1 end end
  return n
end
local function team(hold, focus, short)
  local st = Pi5.new()
  st.hold, st.top, st.focus = hold, hold and Pi5.ADAPTER or Pi5.AMELIORER, focus or {}
  return { key = "fx", force = "fx", started = 0, hq = { valid = true }, team = { ia3 = { pile = st, short = short or {} } },
    build = { order = {}, projects = {} } }
end
do
  local f = team(true)
  local p = { id = 3, state = "reserve", spec = { pile = "capital", product = NEW_PRODUCT }, stock = { ["stone-furnace"] = 3 },
    missing = { { "stone-furnace", 5 } }, ents = {} }
  check(Build.reserve_suspended(f, p, 100) == true, "module neuf pendant une retenue : réserve suspendue")
  check((COFFRE["stone-furnace"] or 0) == 3 and (p.stock["stone-furnace"] or 0) == 0, "les objets déjà réservés sont rendus au coffre")
  check(#p.missing == 0 and p.reason == "pile" and p.reserve_next == 160, "manques effacés (aucun but ne les fabrique), raison « pile »")
  check(n_logs("[FO-PILE] fx : refus : projet:3") == 1, "journal [FO-PILE] : une ligne de refus")
  Build.reserve_suspended(f, p, 200)
  check(n_logs("[FO-PILE] fx : refus : projet:3") == 1, "le même refus n'est pas réécrit pendant le même épisode")
  local rp = { id = 4, state = "reserve", spec = { pile = "capital", product = NEW_PRODUCT }, stock = {}, missing = {}, ents = {},
    reopened = 1, reopened_tick = 500, finished = 400 }
  check(Build.reserve_suspended(f, rp, 600) == false, "module rouvert pour reconstruction : jamais suspendu")
  local gp = { id = 5, state = "reserve", spec = { pile = "capital", product = NEW_PRODUCT }, stock = {}, missing = {}, ents = {},
    reopened = 2, reopened_tick = 500, finished = 900, ligne = {} }
  check(Build.reserve_suspended(f, gp, 1000) == false,
    "pas d'agrandissement déjà ouvert : sa réserve n'est pas suspendue (la ligne ne servirait plus ses quais)")
  local ep = { id = 6, state = "reserve", spec = { enceinte = true }, stock = {}, missing = {}, ents = {} }
  check(Build.reserve_suspended(f, ep, 1000) == false, "projet sans famille (enceinte, centrale, raccord) : jamais suspendu")
  local fp = { id = 7, state = "reserve", spec = { pile = "capital", product = IRON }, stock = {}, missing = {}, ents = {} }
  check(Build.reserve_suspended(team(true, { [IRON] = true }), fp, 1000) == false, "module neuf d'une matière d'un cadre ouvert : passe")
  check(Build.reserve_suspended(team(true, {}, { [IRON] = 5 }), fp, 1000) == false, "module neuf d'une matière qui manque : passe")
  check(Build.reserve_suspended(team(true, {}, { [NEW_PRODUCT] = 5 }), fp, 1000) == true, "un manque d'une AUTRE matière ne l'ouvre pas")
  check(Build.reserve_suspended(team(false), p, 1000) == false, "pile vide : rien de suspendu")
  local mp = { id = 8, state = "reserve", spec = { pile = "migration" }, stock = {}, missing = {}, ents = {} }
  check(Build.reserve_suspended(team(true), mp, 1000) == true, "ligne d'une migration pas encore en chantier : réserve suspendue")
  -- agrandissement d'une ligne finie
  local ln = { ore = ORE, missing = { { "stone-furnace", 2 } } }
  local lp = { id = 9, state = "fini", spec = { product = NEW_PRODUCT } }
  check(Build.grow_suspended(f, lp, ln, 1000) == true and ln.missing == nil, "agrandissement suspendu, pièces du pas plus demandées")
  check(n_logs("[FO-PILE] fx : refus : ligne:9") == 1, "journal [FO-PILE] du refus de l'agrandissement")
  check(Build.grow_suspended(team(true, { [NEW_PRODUCT] = true }), lp, { ore = ORE }, 1000) == false, "agrandissement d'une matière d'un cadre : passe")
  check(Build.grow_suspended(team(false), lp, { ore = ORE }, 1000) == false, "pile vide : l'agrandissement passe")
  -- projet d'avant le lot (sauvegarde 0.6.21) : famille posée une fois
  local tf = team(false)
  tf.build.projects[11] = { id = 11, spec = { gen = "smelter" } }
  check(Build.tag(tf, 11, "capi", NEW_PRODUCT) == true and tf.build.projects[11].spec.pile == "capi"
    and tf.build.projects[11].spec.product == NEW_PRODUCT, "Build.tag : famille et produit posés sur un projet d'avant le lot")
  check(Build.tag(tf, 11, "capital", "x") == false and tf.build.projects[11].spec.pile == "capi", "Build.tag : un projet marqué n'est pas changé")
  check(Build.tag(tf, 99, "capital", "x") == false, "Build.tag : projet absent")
end
log, Stock.insert = real_log, real_insert

---------------------------------------------------------------------------------------------------
section("6. Câblage (lecture des sources)")
---------------------------------------------------------------------------------------------------
local capi = read("script/ai3/capitalisation.lua")
local auto = read("script/ai3/automatisation.lua")
local build = read("script/team/build.lua")
local mig = read("script/team/migration_champ.lua")
local cerv = read("shared/ai3/cerveau.lua")
local prt = read("script/team/pile.lua")
local function has(src, s, msg) check(src:find(s, 1, true) ~= nil, msg) end
has(capi, "local allowed, pwhy = pile_ok(f, o)", "capitalisation : chaque ordre neuf passe par la porte de la pile (fuite a)")
has(capi, "if allowed then rec, why = execute(f, cs, o, view, book, tick, research)", "capitalisation : ordre refusé : aucun exécutant")
has(capi, "PileRt.refuse(f, \"capi:\" .. tostring(o.key)", "capitalisation : refus au journal [FO-PILE]")
has(capi, "if allowed and (o.kind == \"equiper\" or o.kind == \"techno\") then hold(cs, o.key, why, tick) end",
  "capitalisation : un refus de la pile ne met pas l'ordre en repli")
has(capi, "eq_ok, eq_why = PileRt.porte_any(f, \"capi\", { rec.d_item })", "capitalisation : pose de modules suspendue pendant une retenue")
has(capi, "if m.reason == \"pile\" then rec.progress_tick = tick end", "capitalisation : un module suspendu ne fait pas échouer son ordre")
has(auto, "pile = Pi.module_family(m.rebuild, m.grow_step, m.capi, nil) }", "automatisation : famille de chaque module (fuite b)")
has(auto, "m.rebuild, m.grow_step = s.rebuilding or nil, s.growth or nil", "automatisation : reconstruction et agrandissement relus au plan")
has(auto, "if state == \"reserve\" and s.reason == \"pile\" then m.reserve_since, m.reserve_left = tick, nil end",
  "automatisation : une réserve suspendue n'est pas annulée « materiaux introuvables »")
has(auto, "pile = rq.capi and \"capi\" or \"capital\", product = rq.product,", "automatisation : famille et produit portés par la demande")
has(auto, "local grow_ok = (s and s.grow and #s.grow > 0) and PileRt.porte(f, \"invest\", m.product) or false",
  "automatisation : pièces d'agrandissement plus fabriquées pendant une retenue")
has(build, "if Build.reserve_suspended(f, p, tick) then return end", "plan directeur : la réserve passe par la porte")
has(build, "if not Build.grow_suspended(f, p, ln, tick) and ligne_one(f, surface, p, ln, cfg, tick) then return end",
  "plan directeur : l'agrandissement des lignes passe par la porte")
has(build, "local conv_ok, conv_why = PileRt.porte(f, \"upgrade\", nil)", "plan directeur : amélioration des tapis suspendue")
has(build, "rebuilding = rebuilding, growth =", "plan directeur : Build.brief distingue reconstruction et agrandissement")
has(mig, "pile = \"migration\" }", "migration du champ : famille posée sur sa demande")
has(cerv, "Pi.suspend(pile, g.key, \"module neuf du plan directeur (\"", "pensée : refus d'un module neuf noté")
has(prt, "if Rule.rebuilding(q) and Rule.HOLD_STATES[q.state] then", "pile : le cadre « réparer:plan » ne compte que les reconstructions")
has(prt, "PileRt.flush(f, tick) -- lot FUITES-PILE", "pile : refus de la pensée écrits au journal")
has(read("shared/team/rebuild_rapide.lua"), "return Sw.rebuilding(p)", "Rr.partial_go : reconstruction seulement")
-- anti-échelle (iag_test §8 : aucun nom d'objet dans shared/ai3 et script/ai3 ; « gate » est un objet du jeu)
for _, path in ipairs({ "shared/ai3/pile.lua", "shared/ai3/cerveau.lua", "shared/ai3/automatiser.lua" }) do
  local code = read(path):gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  check(code:find("%f[%w_]gate%f[^%w_]") == nil, path .. " : aucun « gate » (nom d'objet du jeu)")
end

local base_pass, base_fail = passes, failures

section("7. Mutants")
local MUTANTS = {
  { name = "porte toujours ouverte", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "  if short and Pi.INVEST_FAMILIES[family] then return true, nil end\n  return false,",
    to = "  if true then return true, nil end\n  return false," },
  { name = "pas d'exception investissement", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "  if short and Pi.INVEST_FAMILIES[family] then return true, nil end\n", to = "" },
  { name = "réparer suspendu sous R0", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "  if rank <= Pi.ADAPTER then return true, nil end\n", to = "" },
  { name = "reconstruction prise pour un agrandissement", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "  if rebuilding then return \"reparer\" end\n", to = "" },
  { name = "refus réécrits sans fin", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "  if st.refus[key] then return false end\n", to = "" },
  { name = "refus jamais oubliés", mod = "shared.ai3.pile", file = "shared/ai3/pile.lua",
    from = "  if not hold then st.refus = nil end", to = "" },
  { name = "agrandissement = reconstruction (date jamais comparée)", mod = "shared.team.rebuild_sweep", file = "shared/team/rebuild_sweep.lua",
    from = "(q.finished == nil or q.reopened_tick >= q.finished)", to = "true" },
  { name = "module neuf avant la reconstruction", mod = "shared.ai3.automatiser", file = "shared/ai3/automatiser.lua",
    from = "for _, m in ipairs(auto.mods or {}) do if m.pile == \"reparer\" then ordered[#ordered + 1] = m end end",
    to = "for _, m in ipairs(auto.mods or {}) do if false then ordered[#ordered + 1] = m end end" },
  { name = "famille non portée", mod = "shared.ai3.automatiser", file = "shared/ai3/automatiser.lua",
    from = "reason = m.reason, pile = m.pile,", to = "reason = m.reason," },
  { name = "pensée sans porte des modules", mod = "shared.ai3.cerveau", file = "shared/ai3/cerveau.lua",
    from = "elseif g.kind == \"module\" and g.pile then", to = "elseif false then" },
}
local killed = 0
quiet = true
for _, m in ipairs(MUTANTS) do
  local f0 = failures
  local ok, err = pcall(function() battery(fresh(m)) end)
  local dead = (not ok) or failures > f0
  if dead then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. m.name) end
  if not ok then print("  (mutant « " .. m.name .. " » : erreur " .. tostring(err) .. ")") end
end
quiet = false
fresh(nil)
passes, failures = base_pass, base_fail
check(killed == #MUTANTS, "mutants refusés : " .. killed .. " sur " .. #MUTANTS)
print(string.format("[FUITES-PILE] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, #MUTANTS))
os.exit(failures == 0 and 0 or 1)
