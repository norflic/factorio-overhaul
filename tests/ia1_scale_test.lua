--[[
  Tests hors jeu du lot IA1-a « Échelle 30 » (docs/EQUIPES_PNJ.md §16 ; shared/team/scale.lua).
  Usage, depuis la racine du mod :   lua5.2 tests/ia1_scale_test.lua

  Vérifie : réglages (défauts, bornes, lecture d'un réglage absent), plafond « 30 dès l'époque 1 » (Q-IA1-2 (2)),
  effectif de départ, coût d'une recrue, cases du QG (au moins 36, distinctes, espacées, exactes en virgule fixe),
  directions des gisements identiques à l'ancien calcul trigonométrique, aucune trigonométrie restante dans
  worker.lua et team.lua, prise de tâche en un passage identique à l'ancien Board.claim (tableaux tirés au
  hasard), correctif `pairs` du cerveau (besoins de stock dans l'ordre des noms), règle de recrutement du
  cerveau (stock, garde d'agents, secours), mesures publiées (inactivité réelle et au-delà du carnet,
  séparées), puis, moteur simulé : guerre lancée sans nombre d'ouvriers (réglage 30), montée à 30 payée par le
  stock, cases uniques, plafond d'émission des demandes de chemin (2 par tick, 6 en vol), déterminisme.
]]

package.path = "./?.lua;" .. package.path
local S = require("shared.team.scale")
local O = require("shared.team.org")
local T = require("shared.team.config")
local Planner = require("shared.team.planner")
local Book = require("shared.team.book")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

---------------------------------------------------------------------------------------------------
section("Réglages : défauts et bornes (docs §11, commande du lot)")
local want = {
  -- Fusion avec 0.4.15 : réglages de la guerre (déclarés par settings/faction.lua), défauts de 0.4.15 gardés.
  ["fo-war-factions"] = { 2, 2, 4 }, ["fo-war-workers"] = { 30, 1, 60 }, ["fo-player-team-npc-max"] = { 30, 6, 60 },
  ["fo-npc-start"] = { 8, 2, 30 }, ["fo-agents-max"] = { 300, 50, 600 }, ["fo-path-issue-per-tick"] = { 2, 1, 6 },
  ["fo-recruit-idle-max"] = { 0, 0, 60 }, -- correction IA1-a : frein par le travail
}
local seen = 0
for _, s in ipairs(S.SETTINGS) do
  local w = want[s.name]
  check(w ~= nil, "réglage attendu : " .. s.name)
  if w then
    seen = seen + 1
    check(s.default == w[1] and s.min == w[2] and s.max == w[3],
      string.format("%s : %d (%d à %d)", s.name, s.default, s.min, s.max))
  end
end
check(seen == 7, "7 réglages déclarés (" .. seen .. ")")
check(S.read("fo-war-workers", function() error("absent") end) == 30, "réglage absent : défaut")
check(S.read("fo-war-workers", function() return nil end) == 30, "réglage nil : défaut")
check(S.read("fo-war-workers", function() return 100 end) == 60, "valeur bornée au maximum")
-- Un seul réglage par sens : aucun doublon d'IA1-a, les deux réglages de la guerre déclarés par faction.lua.
local declared = {}
for _, s in ipairs(S.SETTINGS) do if s.declared_in then declared[#declared + 1] = s.name end end
check(table.concat(declared, ",") == "fo-war-factions,fo-war-workers", "réglages déclarés par settings/faction.lua")
check(S.spec("fo-war-factions").max == require("shared.faction.config").MAX_FACTIONS, "factions au plus = F.MAX_FACTIONS")
check(not pcall(S.spec, "fo-team-npc-max") and not pcall(S.spec, "fo-factions"), "anciens réglages d'IA1-a retirés")
check(S.read("fo-npc-start", function() return 1 end) == 2, "valeur bornée au minimum")
check(S.read("fo-npc-start", function() return 12.7 end) == 12, "valeur entière")

---------------------------------------------------------------------------------------------------
section("Effectifs : « 30 dès l'époque 1 », départ, coût d'une recrue")
for epoch = 1, 15 do
  check(S.cap(epoch, 30) == 30, "plafond 30 à l'époque " .. epoch)
end
check(S.cap(1, 60) == 60 and S.cap(1, 6) == 6, "plafond = maximum réglé (6 et 60)")
check(S.start_headcount(8, 30) == 8, "départ 8 pour 30")
check(S.start_headcount(8, 6) == 6, "départ borné par le maximum (6)")
check(S.start_headcount(30, 30) == 30, "départ 30 (option 3 de Q-IA1-2, par réglage)")
local c29 = S.recruit_cost(29)
local iron29
for _, it in ipairs(c29) do if it[1] == "iron-plate" then iron29 = it[2] end end
check(iron29 == 39, "recrue à 29 PNJ : 39 plaques de fer en plus du kit (docs §9)")
-- Montée 8 -> 30 : 22 recrues, 627 fer hors kits (docs §1, Q-IA1-2).
local iron = 0
for n = 8, 29 do iron = iron + 10 + n end
check(iron == 627, "montée 8 -> 30 : 627 plaques de fer hors kits (" .. iron .. ")")

---------------------------------------------------------------------------------------------------
section("Cases du QG : table constante")
local slots = S.HOME_SLOTS
check(#slots >= S.SLOTS_REQUIRED and S.SLOTS_REQUIRED == 36, "au moins 36 cases (" .. #slots .. ")")
local min_d, dup, exact = 99, 0, true
for i = 1, #slots do
  local a = slots[i]
  if a[1] * 8 ~= math.floor(a[1] * 8) or a[2] * 8 ~= math.floor(a[2] * 8) then exact = false end
  for j = i + 1, #slots do
    local b = slots[j]
    local dx, dy = a[1] - b[1], a[2] - b[2]
    local d = math.sqrt(dx * dx + dy * dy)
    if d < min_d then min_d = d end
    if d == 0 then dup = dup + 1 end
  end
end
check(dup == 0, "cases distinctes")
check(min_d >= 1.5, string.format("écart minimal entre cases >= 1,5 tuile (%.2f)", min_d))
check(exact, "coordonnées multiples de 1/8 (exactes en virgule fixe 1/256, F92)")
local owner, bad = {}, {}
bad[1], bad[3] = true, true
owner[2] = 7
check(S.free_slot(bad, owner) == 4, "première case libre : ni bloquée ni prise")

---------------------------------------------------------------------------------------------------
section("Gisements de départ : directions constantes = ancien calcul")
local ANGLES = { 0.35, 1.9, 3.45, 5.0, 2.7, 4.2, 5.8, 1.1 }
local same = true
for i, a in ipairs(ANGLES) do
  local d = S.SEED_OFFSETS[i]
  if d[1] ~= math.cos(a) * 46 or d[2] ~= math.sin(a) * 46 then same = false end
end
check(same and #S.SEED_OFFSETS == 8, "8 directions identiques au bit près à cos/sin × 46")

section("Aucune trigonométrie restante (worker.lua, team.lua)")
for _, path in ipairs({ "script/team/worker.lua", "script/team/team.lua" }) do
  local fh = io.open(path, "r")
  local src = fh:read("*a")
  fh:close()
  local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find("math%.cos") and not code:find("math%.sin") and not code:find("math%.pi"), path .. " sans cos/sin/pi")
end

---------------------------------------------------------------------------------------------------
section("Prise de tâche en un passage = ancien Board.claim")
-- Ancien Board.claim (avant IA1-a) : clés triées, la plus haute priorité, à égalité la plus petite clé.
local function old_claim(tasks)
  local ks = {}
  for k in pairs(tasks) do ks[#ks + 1] = k end
  table.sort(ks)
  local best
  for _, k in ipairs(ks) do
    local t = tasks[k]
    if not t.worker and (not best or t.prio > best.prio) then best = t end
  end
  return best
end
local KINDS = { "craft", "build", "extend", "service", "refill", "fortify", "smelters", "smelt", "mine" }
local PRIOS = { 25, 30, 35, 40, 45, 50, 52, 55, 60, 65, 70, 75, 78, 80, 85, 90, 95 }
local seed = 12345
local function rnd(n)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed % n + 1
end
local agree, draws = 0, 2000
for _ = 1, draws do
  local tasks, list = {}, {}
  for i = 1, rnd(40) - 1 do
    local key = KINDS[rnd(#KINDS)] .. ":" .. rnd(30)
    if not tasks[key] then
      local t = { key = key, kind = key:match("^[^:]+"), prio = PRIOS[rnd(#PRIOS)] }
      if rnd(4) == 1 then t.worker = 1 end
      tasks[key] = t
    end
  end
  local ks = {}
  for k in pairs(tasks) do ks[#ks + 1] = k end
  table.sort(ks)
  for _, k in ipairs(ks) do list[#list + 1] = tasks[k] end
  O.sort_tasks(list)
  local i = O.pick_task({ role = "generalist" }, list)
  local new = i and list[i] or nil
  if new == old_claim(tasks) then agree = agree + 1 end
end
check(agree == draws, string.format("même tâche que l'ancien Board.claim sur %d tableaux tirés (%d)", draws, agree))

---------------------------------------------------------------------------------------------------
section("Cerveau : besoins de stock dans l'ordre des noms (correctif pairs)")
local book = Book.new(dofile("tests/fixtures/recipes.lua"))
local function base_view(over)
  local v = {
    tech = 0, personality = "balanced", done = {}, deferred = {}, stock = {}, incoming = {},
    outposts = {}, pending = {}, sites = {}, smelters = 0, smelters_pending = 0, smelter_task = false,
    smelter_output = 0, smelter_fuel_low = false, smelter_coal = 0, turret_groups = {},
    soldiers = 0, soldiers_max = 100, workers = 8, workers_max = 30, workers_idle = 0, threatened = false, open = {},
  }
  for k, x in pairs(over or {}) do v[k] = x end
  return v
end
-- Deux tables de besoins identiques construites dans des ordres différents (et perturbées par des clés
-- ajoutées puis retirées) : l'ordre de `pairs` peut différer, le plan ne doit pas.
local stockA = {}
stockA["stone-brick"] = 10; stockA["firearm-magazine"] = 5; stockA["iron-gear-wheel"] = 7
local stockB = {}
for i = 1, 40 do stockB["x" .. i] = i end
stockB["iron-gear-wheel"] = 7; stockB["firearm-magazine"] = 5; stockB["stone-brick"] = 10
for i = 1, 40 do stockB["x" .. i] = nil end
local plates = { ["iron-plate"] = 400, ["copper-plate"] = 100, coal = 100, stone = 100 }
local p1 = Planner.plan(base_view({ ladder = { { key = "multi", need = { stock = stockA } } }, no_research = true, stock = plates }), book)
local p2 = Planner.plan(base_view({ ladder = { { key = "multi", need = { stock = stockB } } }, no_research = true, stock = plates }), book)
local function keys_of(plan)
  local out = {}
  for _, t in ipairs(plan.tasks) do out[#out + 1] = t.key end
  local m = {}
  for _, x in ipairs(plan.missing) do m[#m + 1] = x[1] .. "x" .. x[2] end
  return table.concat(out, ",") .. "|" .. table.concat(m, ",")
end
check(keys_of(p1) == keys_of(p2), "deux pensées identiques : mêmes tâches et mêmes manques")
local crafts = {}
for _, t in ipairs(p1.tasks) do if t.kind == "craft" and t.tag == "objectif" then crafts[#crafts + 1] = t.item end end
check(#crafts >= 2, "plusieurs objets de stock servis (" .. table.concat(crafts, ",") .. ")")

section("Cerveau : recrutement (stock, garde d'agents, secours)")
local cost = S.recruit_cost(8)
local rich = { ["iron-plate"] = 500, pistol = 3, ["firearm-magazine"] = 50, coal = 100 }
local pr = Planner.plan(base_view({ stock = rich, workers_wanted = 30, recruit_cost = cost }), book)
check(pr.recruit_workers == 1 and not pr.recruit_unarmed, "stock suffisant : une recrue payée")
local pb = Planner.plan(base_view({ stock = rich, workers_wanted = 30, recruit_cost = cost, recruit_blocked = true }), book)
check(not pb.recruit_workers and pb.recruit_blocked, "garde d'agents : aucune recrue")
local p0 = Planner.plan(base_view({ workers = 0, workers_wanted = 30, recruit_cost = cost, recruit_blocked = true }), book)
check(p0.recruit_workers == 1 and p0.recruit_unarmed, "garde d'agents, équipe vide : embauche de secours sans arme")
local pf = Planner.plan(base_view({ workers = 30, stock = rich, workers_wanted = 30, recruit_cost = S.recruit_cost(30) }), book)
check(not pf.recruit_workers, "plafond atteint : aucune recrue")
local poor = Planner.plan(base_view({ stock = { ["iron-plate"] = 20 }, workers_wanted = 30, recruit_cost = cost }), book)
check(not poor.recruit_workers, "stock insuffisant : pas de recrue (le stock freine)")
local legacy = Planner.plan(base_view({ stock = rich, workers = 1, workers_max = 10 }), book)
check(legacy.recruit_workers == 1, "vue sans champs IA1-a : règle d'avant (2 + avant-postes)")

section("Cerveau : survie d'une faction décimée (lot IA2-a2, view.emergency)")
local em = { floor = 8, rebuild = true }
local plates2 = { ["iron-plate"] = 400, ["copper-plate"] = 50, coal = 100 }
local pe = Planner.plan(base_view({ workers = 1, stock = plates2, workers_wanted = 30, recruit_cost = cost, emergency = em }), book)
local uses_ok = false
for _, it in ipairs(pe.recruit_uses or {}) do if it[1] == "iron-plate" and it[2] > 0 then uses_ok = true end end
check(pe.recruit_workers == 1 and not pe.recruit_unarmed and uses_ok, "1 ouvrier sur 8, plaques au stock : recrue équipée au QG avec les plaques")
local pn = Planner.plan(base_view({ workers = 1, stock = plates2, workers_wanted = 30, recruit_cost = cost }), book)
check(not pn.recruit_workers, "même vue sans view.emergency (équipe du joueur, tests d'avant) : règle d'avant, pas de recrue")
local pm = Planner.plan(base_view({ workers = 1, smelters = 2, stock = { coal = 100 }, workers_wanted = 30, recruit_cost = cost, emergency = em }), book)
local mine90 = false
for _, t in ipairs(pm.tasks) do if t.key == "mine:iron-ore" and t.prio == 90 then mine90 = true end end
check(pm.recruit_workers == 1 and pm.recruit_unarmed and mine90, "sans plaques : 2e ouvrier sans arme et minage du fer à la main (priorité 90)")
local pg = Planner.plan(base_view({ workers = 8, soldiers = 0, done = { army = true }, stock = plates2, emergency = em }), book)
check(pg.train and pg.train.count == 5 and pg.train.uses ~= nil, "reconstruction, 0 soldat : un lot de 5 soldats équipés au QG (" .. tostring(pg.train and pg.train.unit) .. ")")
local stone = { stone = 100, coal = 100 }
local ps = Planner.plan(base_view({ workers = 8, smelters = 0, stock = stone, emergency = { floor = 8, rebuild = true } }), book)
local smelt_task, furnace_craft = false, false
for _, t in ipairs(ps.tasks) do
  if t.key == "smelters" and t.prio == 92 then smelt_task = true end
  if t.kind == "craft" and t.item == "stone-furnace" and t.prio == 92 then furnace_craft = true end
end
check(ps.emergency_smelters and (smelt_task or furnace_craft), "fonderie du QG détruite : reposée en priorité 92 (fours fabriqués avec la pierre du stock)")
local pq = Planner.plan(base_view({ workers = 8, soldiers = 0, done = { army = true }, stock = plates2, emergency = { floor = 8, rebuild = false } }), book)
check(not (pq.train and pq.train.uses), "hors reconstruction et sans menace : pas de garde équipée au QG")

section("Cerveau : frein par le travail (correction IA1-a, fo-recruit-idle-max)")
check(S.recruit_held(1, 0) and not S.recruit_held(0, 0), "limite 0 : un seul PNJ inactif retient la recrue")
check(not S.recruit_held(30, 60) and not S.recruit_held(60, 60), "limite 60 : jamais de frein (seul le stock freine)")
check(S.recruit_held(3, 2) and not S.recruit_held(2, 2), "limite 2 : frein au-delà de 2 inactifs")
check(S.recruit_held(1, nil), "limite absente : défaut du réglage (0)")
-- Plancher (correction 3) : sous l'effectif de départ, jamais de frein (reconstruction après des pertes).
check(not S.recruit_held(1, 0, 1, 8) and not S.recruit_held(7, 0, 7, 8), "plancher : 1 ou 7 PNJ sur 8, pas de frein")
check(S.recruit_held(1, 0, 8, 8) and S.recruit_held(2, 0, 12, 8), "plancher atteint (8, 12 PNJ) : frein")
check(S.recruit_held(1, 0, 1, nil), "plancher absent : règle d'avant")
local ph = Planner.plan(base_view({ stock = rich, workers_wanted = 30, recruit_cost = cost, recruit_held = true }), book)
check(not ph.recruit_workers and ph.recruit_held, "frein : aucune recrue malgré le stock")
local craft_recruit = false
local poor_h = Planner.plan(base_view({ stock = { ["iron-plate"] = 300, ["copper-plate"] = 100 }, workers_wanted = 30,
  recruit_cost = cost, recruit_held = true }), book)
for _, t in ipairs(poor_h.tasks) do if t.tag == "ouvrier" then craft_recruit = true end end
local poor_f = Planner.plan(base_view({ stock = { ["iron-plate"] = 300, ["copper-plate"] = 100 }, workers_wanted = 30,
  recruit_cost = cost }), book)
local craft_free = false
for _, t in ipairs(poor_f.tasks) do if t.tag == "ouvrier" then craft_free = true end end
check(craft_free and not craft_recruit, "frein : l'équipement d'une recrue n'est plus fabriqué (sans frein : fabriqué)")
local p0h = Planner.plan(base_view({ workers = 0, workers_wanted = 30, recruit_cost = cost, recruit_held = true }), book)
check(p0h.recruit_workers == 1 and p0h.recruit_unarmed, "frein, équipe vide : embauche de secours conservée")

---------------------------------------------------------------------------------------------------
section("Mesures publiées : inactivité réelle et au-delà du carnet, séparées")
local m0 = S.metrics({}, 30, 30, "equilibre", false, 0)
check(m0.surplus == 30 and m0.idle == 30 and m0.idle_pct == 100, "aucun travail : 30 au-delà du carnet, 30 inactifs")
local busy = {}
for i = 1, 30 do busy[i] = { kind = "garrison", worker = i, claimed = 0 } end -- 300 s chacune, en cours
local m1 = S.metrics(busy, 30, 0, "equilibre", false, 0)
check(m1.idle == 0 and m1.surplus == 0, "30 tâches longues en cours : 0 inactif, 0 au-delà du carnet")
local m2 = S.metrics(busy, 30, 0, "equilibre", false, 290 * 60)
check(m2.idle == 0 and m2.surplus > 0, "mêmes tâches presque finies : 0 inactif mais " .. m2.surplus .. " au-delà du carnet")

---------------------------------------------------------------------------------------------------
section("Moteur simulé : guerre lancée sans nombre d'ouvriers (réglage 30)")
local M = require("tests.mock_engine")
local function patches() -- même carte que tests/war_test.lua (gisements autour des 4 QG à 320 tuiles)
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end
local function run_war(minutes, brake)
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0 })
  -- Banc d'échelle : frein par le travail levé (60 = seul le stock freine), comme le scénario ia1-scale.
  M.world().settings["fo-recruit-idle-max"] = brake or 60
  M.world().settings["fo-war-workers"] = 30 -- défaut 4 (0.4.15) : le banc d'échelle règle 30
  local ok = remote.call("factorio-overhaul", "war_start", 4, 100, nil, 320)
  check(ok == true, "war_start sans nombre d'ouvriers")
  local w = global.fo.war
  check(w.settings.npc_from_setting == true and w.settings.engineers_max == 30, "taille suivie du réglage (30)")
  local start = 0
  for _, f in ipairs(w.factions) do start = start + f.engineers_count end
  check(start == 32, "8 PNJ par faction au départ (" .. start .. ")")
  remote.call("factorio-overhaul", "war_fund", 3000)
  local okr, err = pcall(M.run_ticks, minutes * 3600)
  check(okr, "simulation sans erreur (" .. tostring(err) .. ")")
  return w
end
local w = run_war(12)
local all30, uniq, paid = true, true, true
for _, f in ipairs(w.factions) do
  if f.engineers_count < 27 then all30 = false end
  print(string.format("  %s : %d PNJ, %d recrues payées, garde %d", f.key, f.engineers_count, f.stats.recruited or 0, f.stats.recruit_guard or 0))
  local used = {}
  for _, id in ipairs(require("script.faction.state").sorted_keys(f.engineers)) do
    local a = require("script.companion.registry").get(id)
    if a then
      if not a.slot or used[a.slot] then uniq = false end
      if a.slot then used[a.slot] = true end
    end
  end
  if (f.stats.recruited or 0) < f.engineers_count - 8 then paid = false end
end
check(all30, "chaque faction atteint au moins 27 PNJ (90 % de 30) en 12 min, stock financé")
check(uniq, "une case du QG par PNJ vivant (aucun partage)")
check(paid, "toute recrue au-delà des 8 de départ est payée")
local rows = remote.call("fo-ia1", "teams")
check(#rows == 4 and rows[1].thinks > 0 and rows[1].last ~= nil, "interface fo-ia1 : 4 équipes mesurées")
local path = remote.call("fo-ia1", "path")
check(path.inflight_max <= 6, "au plus 6 demandes de chemin en vol (" .. path.inflight_max .. ")")
check(pcall(M.serialize, global), "global sérialisable")

section("Moteur simulé : frein par le travail par défaut (correction IA1-a)")
do
  local wb = run_war(12, 0)
  local held, paid_b, max_n = 0, 0, 0
  for _, f in ipairs(wb.factions) do
    held = held + (f.stats.recruit_held or 0)
    paid_b = paid_b + (f.stats.recruited or 0)
    max_n = math.max(max_n, f.engineers_count)
    print(string.format("  %s : %d PNJ, %d recrues payées, frein %d, fer au QG %d", f.key, f.engineers_count,
      f.stats.recruited or 0, f.stats.recruit_held or 0, f.hq.get_item_count("iron-plate")))
  end
  check(held > 0, "le frein retient des recrues (" .. held .. " pensées)")
  check(paid_b < 4 * 22, "le frein limite la montée : " .. paid_b .. " recrues payées sur 88 possibles")
  local rows_b = remote.call("fo-ia1", "teams")
  check(rows_b[1].held ~= nil and rows_b[1].held >= 0, "interface fo-ia1 : champ « held » publié")
  local v = remote.call("fo-ia1", "set_setting", "fo-recruit-idle-max", 99)
  check(v == 60, "set_setting borne la valeur (99 -> " .. tostring(v) .. ")")
  check(remote.call("fo-ia1", "set_setting", "fo-pvp-difficulty", 1) == nil, "set_setting refuse un réglage hors équipes")
  -- Plancher (correction 3) : une faction décimée à 1 PNJ, frein à 0 : le frein ne la retient plus (sous son
  -- départ, 8). Avant IA2-a2, avec ou sans frein (60), la faction restait à 1 PNJ en 6 min, pistolet de la recrue
  -- jamais fabriqué (défaut d'avant IA1-a, NOTES.md du lot, § 6.8) ; corrigé au lot IA2-a2 (survie).
  remote.call("fo-ia1", "set_setting", "fo-recruit-idle-max", 0)
  local f = wb.factions[1]
  local ids = require("script.faction.state").sorted_keys(f.engineers)
  for i = 2, #ids do
    local a = global.fo.companion.agents[ids[i]]
    if a and a.entity.valid then a.entity.die() end
  end
  M.run_ticks(2)
  local after_kill = f.engineers_count
  remote.call("factorio-overhaul", "war_fund", 3000)
  local held0, rec0 = f.stats.recruit_held or 0, f.stats.recruited or 0
  check(pcall(M.run_ticks, 6 * 3600), "simulation sans erreur après les pertes")
  print(string.format("  faction décimée : %d PNJ après les pertes, %d après 6 min ; recrues %d -> %d ; pistolets %d",
    after_kill, f.engineers_count, rec0, f.stats.recruited or 0, f.hq.get_item_count("pistol")))
  -- Lot IA2-a2 (survie) : sous son départ, la recrue est équipée au QG avec les plaques du stock ; la faction
  -- décimée se reconstruit (avant : 1 PNJ après 6 min, pistolet jamais fabriqué). Le frein reprend au-dessus du
  -- départ : on contrôle la reconstruction et les recrues d'urgence, plus l'immobilité du frein.
  -- Lot IA2-b : une recrue sous le plancher peut aussi être payée avec un kit déjà au stock (recrue ordinaire) ; on
  -- exige donc 7 recrues au moins (1 -> 8) dont au moins une par la survie, et non 7 recrues de survie (carte du lot :
  -- 1 -> 14 PNJ, 13 recrues dont 6 de survie ; 1 -> 11, 10 dont 7 avant).
  check(after_kill == 1 and f.engineers_count >= 8 and (f.stats.recruited or 0) - rec0 >= 7
    and (f.stats.emergency_recruits or 0) >= 1,
    "plancher et survie : la faction décimée se reconstruit au-delà de son départ (1 -> " .. f.engineers_count
    .. " PNJ en 6 min, " .. tostring(f.stats.emergency_recruits or 0) .. " recrues équipées au QG)")
end

section("Moteur simulé : au plus 2 demandes émises par tick")
do
  local PathService = require("script.core.path_service")
  local got = 0
  PathService.register_handler("ia1-test", function() got = got + 1 end)
  local before = global.fo.path.stats.issued
  -- 20 demandes d'un coup : un tick n'en émet que 2.
  for i = 1, 20 do
    PathService.request("ia1-test", i, { surface = 1, proto = "fo-companion", start = { x = 0, y = 0 },
      goal = { x = 50 + i, y = 0 }, force = "player", radius = 1, flags = {}, res = 0 })
  end
  M.run_ticks(1)
  local issued1 = global.fo.path.stats.issued - before
  check(issued1 <= 2, "1 tick : au plus 2 émissions (" .. issued1 .. ")")
  M.run_ticks(60)
  check(global.fo.path.stats.inflight_max <= 6, "en vol : jamais plus de 6")
end

section("Déterminisme : deux guerres identiques")
local function snapshot()
  local w2 = run_war(3)
  local parts = {}
  for _, f in ipairs(w2.factions) do
    parts[#parts + 1] = f.key .. ":" .. f.engineers_count .. ":" .. (f.stats.recruited or 0) .. ":" .. f.hq.get_item_count("iron-plate")
  end
  return table.concat(parts, ";")
end
local s1, s2 = snapshot(), snapshot()
check(s1 == s2, "même état après 3 min (" .. s1 .. ")")

---------------------------------------------------------------------------------------------------
section("Cases du QG : une entité qui TOUCHE seulement la case ne la bloque pas (F96, mineur 9)")
do
  M.new_game({})
  local surface = game.surfaces[1]
  local Worker = require("script.team.worker")
  -- Case 1 (2,5 ; 0) : zone x de 2 à 3. Coffre (boîte ±0,35) en x = 3,35 : bord gauche en x = 3 exactement.
  surface.create_entity({ name = "iron-chest", position = { x = 3.35, y = 0 }, force = "player" })
  -- Case 5 (−2,5 ; 0) : zone x de −3 à −2. Coffre en x = −2,4 : boîte de −2,75 à −2,05, chevauchement réel.
  surface.create_entity({ name = "iron-chest", position = { x = -2.4, y = 0 }, force = "player" })
  local touch = surface.count_entities_filtered({ area = { { 2, -0.5 }, { 3, 0.5 } }, collision_mask = "object-layer" })
  check(touch == 1, "la recherche par zone rend le coffre qui touche la case 1 (F96 : " .. touch .. ")")
  local f = { home_spot = { x = 0, y = 0 } }
  f.slot_owner, f.slot_bad, f.slot_cursor = {}, {}, 0
  Worker.check_slots(f, surface)
  check(not f.slot_bad[1], "case 1 libre : le coffre ne fait que la toucher")
  check(f.slot_bad[5] == true, "case 5 bloquée : chevauchement réel")
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
