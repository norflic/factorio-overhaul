--[[
  Lot PERIMETRE : banc HORS JEU de la CHAÎNE complète, moteur simulé (tests/mock_engine.lua). Lancement : lua5.2 tests/perimetre_moteur_test.lua
  (racine du mod). Votre équipe riche (coffre : fer, cuivre, tourelles, chargeurs), une base de test : une chaîne de fours vers l'est jusqu'à
  une grappe d'assembleurs à 60 tuiles, une grappe de fours au sud (reliée par une ligne de fours) :
    1. relevé : anneau 1 né, postes « point » aux grappes non couvertes, mesure au journal ;
    2. le planificateur ouvre une tâche « fortify » du poste « perim » ; un PNJ pose des GROUPES (au moins 2 tourelles à moins de 8 tuiles du
       centre d'un poste, à portée l'une de l'autre) ;
    3. budget : coffre pauvre (fer sous le plancher + coût / 15 %) : aucune tourelle du périmètre ;
    4. interrupteur coupé : la mesure seule (aucun poste, aucune pose), même chiffres de tourelles que sans le lot ;
    5. déterminisme : deux passages identiques.
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 90, y = math.sin(a) * 90, name = names[i % 4 + 1] }
  end
  return out
end

local function build(s, name, x, y)
  local e = s.create_entity({ name = name, position = { x = x, y = y }, force = "player" })
  return e
end

local function run(opts)
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  game.forces.player.technologies["gun-turret"].researched = true
  W().prototypes["gun-turret"].turret_range = 18
  local T = require("shared.team.config")
  T.perimetre_on = opts.on ~= false
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", opts.iron or 9000 }, { "copper-plate", 3000 }, { "coal", 400 }, { "stone", 100 }, { "pistol", 2 },
    { "firearm-magazine", 400 }, { "gun-turret", opts.turrets or 0 } }) do
    if it[2] > 0 then chest.insert({ name = it[1], count = it[2] }) end
  end
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  if opts.forced ~= nil then opts.forced_ok = remote.call("fo-perimetre", "set_enabled", "player", opts.forced) end
  -- base de test : chaîne de fours vers l'est (reliée au QG de proche en proche), grappe d'assembleurs à 60 tuiles ; idem au sud
  for _, x in ipairs({ 20, 30, 40, 50 }) do build(s, "stone-furnace", x, 5) end
  for _, p in ipairs({ { 62, 0 }, { 66, 0 }, { 62, 4 }, { 66, 4 } }) do build(s, "assembling-machine-1", p[1], p[2]) end
  for _, y in ipairs({ 25, 35, 45 }) do build(s, "stone-furnace", 5, y) end
  for _, p in ipairs({ { 0, 60 }, { 4, 60 }, { 8, 60 } }) do build(s, "stone-furnace", p[1], p[2]) end
  M.run_ticks(opts.ticks or 30000)
  local logs = {}
  for _, l in ipairs(W().logs) do if l:find("[FO-PERIMETRE]", 1, true) then logs[#logs + 1] = l end end
  local turrets = {}
  for _, e in ipairs(W().entities) do
    if e.valid and e.name == "gun-turret" and e.force and e.force.name == "player" then turrets[#turrets + 1] = { x = e.position.x, y = e.position.y } end
  end
  table.sort(turrets, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  local f = global.fo.pteam.team
  return { logs = logs, turrets = turrets, perim = f and f.perim, forced_ok = opts.forced_ok }
end

local function count(logs, a, b)
  local n = 0
  for _, l in ipairs(logs) do if l:find(a, 1, true) and (not b or l:find(b, 1, true)) then n = n + 1 end end
  return n
end

local function near_count(turrets, x, y, r)
  local n = 0
  for _, t in ipairs(turrets) do if (t.x - x) ^ 2 + (t.y - y) ^ 2 <= r * r then n = n + 1 end end
  return n
end

section("1-2. Équipe riche : anneau, postes, groupes posés")
local a = run({ iron = 9000, turrets = 12 })
for i = 1, math.min(#a.logs, 14) do print("    " .. a.logs[i]:sub(1, 230)) end
check(count(a.logs, "anneau 1 ne") == 1, "anneau 1 né une fois (" .. count(a.logs, "anneau 1 ne") .. ")")
check(count(a.logs, "mesure a ") >= 2, "mesure au journal toutes les 5 min (" .. count(a.logs, "mesure a ") .. ")")
check(count(a.logs, "postes aux points sensibles") >= 1, "postes aux points sensibles créés")
check(count(a.logs, "pose de 2 tourelle(s)") + count(a.logs, "pose de 3 tourelle(s)") >= 2, "au moins deux groupes posés")
local st = a.perim
local grouped, isolated_posts = 0, 0
for _, p in ipairs(st and st.posts or {}) do
  local n = near_count(a.turrets, p.x, p.y, 8)
  if n >= 2 then grouped = grouped + 1 elseif n == 1 and p.kind == "point" then isolated_posts = isolated_posts + 1 end
end
check(grouped >= 2, "au moins 2 postes avec un groupe d'au moins 2 tourelles à moins de 8 tuiles (" .. grouped .. ")")
check(near_count(a.turrets, 64, 2, 14.4) >= 2, "grappe d'assembleurs couverte par un groupe (" .. near_count(a.turrets, 64, 2, 14.4) .. ")")
check(near_count(a.turrets, 4, 60, 14.4) >= 2, "grappe de fours du sud couverte par un groupe (" .. near_count(a.turrets, 4, 60, 14.4) .. ")")
local last = a.logs[#a.logs] or ""
local cov = 0
for _, l in ipairs(a.logs) do local c = l:match("couverture armee (%d+) %%") if c then cov = tonumber(c) end end
check(cov >= 80, "couverture armée finale >= 80 % (" .. cov .. ")")

section("3. Budget : coffre pauvre, aucune tourelle du périmètre")
local b = run({ iron = 400, turrets = 0, ticks = 20000 })
check(count(b.logs, "pose de ") == 0, "aucune pose du périmètre sous le budget (" .. count(b.logs, "pose de ") .. ")")

section("4. Interrupteur coupé : la mesure seule")
local c = run({ iron = 9000, turrets = 12, on = false, ticks = 20000 })
check(count(c.logs, "mesure a ") >= 2 and count(c.logs, "regle eteinte") >= 2, "mesure au journal, règle éteinte")
check(count(c.logs, "anneau") == count(c.logs, "anneaux 0") and count(c.logs, "pose de ") == 0, "aucun anneau, aucune pose")

local c2 = run({ iron = 9000, turrets = 12, forced = false, ticks = 20000 })
check(c2.forced_ok == true and count(c2.logs, "regle forcee false") == 1, "banc témoin : règle forcée éteinte par l'interface")
check(count(c2.logs, "regle eteinte") >= 2 and count(c2.logs, "pose de ") == 0 and #c2.turrets == #c.turrets, "forcée éteinte : la mesure seule, mêmes tourelles qu'interrupteur coupé")

section("5. Déterminisme")
local d = run({ iron = 9000, turrets = 12 })
local same = #d.turrets == #a.turrets and #d.logs == #a.logs
for i = 1, math.min(#d.logs, #a.logs) do if d.logs[i] ~= a.logs[i] then same = false end end
check(same, "deux passages identiques (journal et tourelles)")

print(string.format("[PERIMETRE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
