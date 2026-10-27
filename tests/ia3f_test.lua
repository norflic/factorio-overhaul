--[[
  Lot IA3-f (exploration sous brouillard) : test hors jeu de l'EXÉCUTION (script/ai3/exploration.lua) dans le moteur
  simulé (tests/mock_engine.lua). Les règles pures sont dans tests/ai3_carte_test.lua.

  Ce qu'il prouve (moteur simulé : chemins droits, aucun ennemi à fuir, tout est généré) :
    1. votre équipe (cas du DC, 25/10 vers 18 h 45) : charbon et pierre près du coffre, FER à 260 tuiles, hors de vue au
       départ : carte ouverte, tour du propriétaire, fer VU puis site retenu puis avant-poste de fer construit ; aucun
       avant-poste ni site dans un secteur jamais vu ; aucun éclaireur mort ; état sérialisable ;
    2. le même cas, brouillard coupé (comportement d'avant le lot) : avant-poste de fer plus tôt (prospection omnisciente)
       et aucune carte : la bascule rend bien l'avant ;
    3. minage d'appoint au-delà de 96 tuiles : un gisement CONNU à 140 tuiles est choisi (crochet Worker.far_mine) ;
       inconnu : demande d'exploration « minage » ;
    4. factions : étape « explore » du cerveau (interface fo-ia3f) pour une ressource jamais vue (« crude-oil » à
       620 tuiles) : trouvée, demande fermée, l'éclaireur rentre ; prospection seulement dans les secteurs vus ;
    5. déterminisme : deux parties identiques donnent la même carte et les mêmes dates.

  Usage : lua5.2 tests/ia3f_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[IA3F] ECHEC : " .. msg) end
end
local function W() return M.world() end

local function count_logs(pat)
  local n = 0
  for _, l in ipairs(W().logs) do if l:find(pat, 1, true) then n = n + 1 end end
  return n
end

local function first_log(pat)
  for _, l in ipairs(W().logs) do if l:find(pat, 1, true) then return l end end
  return nil
end

---------------------------------------------------------------------------------------------------
-- 1 et 2. Votre équipe, fer hors de vue
---------------------------------------------------------------------------------------------------
-- 242 tuiles du coffre : hors de l'œil du QG (160 + 32). À 23 tuiles du centre de son secteur : le moteur simulé ne rend
-- un gisement qu'à 36 tuiles au plus du centre de la zone demandée (approximation par un disque).
local IRON = { x = 176, y = 176 }

local function pteam_world(fog)
  local patches = {
    { x = 40, y = 10, name = "coal" }, { x = -30, y = 40, name = "stone" }, { x = 10, y = -45, name = "copper-ore" },
    { x = IRON.x, y = IRON.y, name = "iron-ore" },
  }
  M.new_game({ patches = patches, p_busy = 0, p_nopath = 0, p_lost = 0 })
  if fog == false then remote.call("fo-ia3f", "set_fog", false) end
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
    { "pistol", 2 }, { "firearm-magazine", 40 }, { "burner-mining-drill", 12 }, { "stone-furnace", 12 }, { "iron-chest", 4 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  return global.fo.pteam.team
end

local function iron_outpost_tick(f, limit)
  for t = 1, limit / 600 do
    M.run_ticks(600)
    for _, oid in ipairs(require("script.faction.state").sorted_keys(f.outposts)) do
      local o = f.outposts[oid]
      if o.kind == "iron" then return t * 600, o end
    end
  end
  return nil
end

local K = require("shared.ai3.carte")
local f = pteam_world(true)
local ok, t_iron, o_iron = pcall(iron_outpost_tick, f, 20 * 3600)
check(ok, "votre équipe : simulation sans erreur (" .. tostring(t_iron) .. ")")
local k = f.ai3f
check(k ~= nil and k.m.n > 0, "carte de connaissance ouverte (" .. (k and k.m.n or 0) .. " secteurs vus)")
check(K.seen_xy(k.m, 5, 5) ~= nil and K.seen_xy(k.m, 40, 10) ~= nil, "le QG et le charbon voisin sont vus")
check(count_logs("[FO-IA3F] player : eclaireur") >= 1 and (k.tour.state == "done" or k.tour.state == "todo"),
  "tour du propriétaire parti (" .. k.tour.state .. ")")
local found = k.m.found["iron-ore"]
check(found ~= nil, "fer hors de vue au départ, VU ensuite (" .. tostring(found and found / 3600) .. " min)")
check(found and found > 600, "fer pas connu au premier coup d'œil (vu à " .. tostring(found) .. " ticks)")
check(t_iron ~= nil and o_iron and (o_iron.pos.x - IRON.x) ^ 2 + (o_iron.pos.y - IRON.y) ^ 2 < 40 * 40,
  "avant-poste de fer construit sur le gisement trouvé (" .. tostring(t_iron and t_iron / 3600) .. " min)")
check(t_iron and found and t_iron - found <= 10 * 3600, "exploité moins de 10 min après la découverte")
local st = remote.call("fo-ia3f", "status")
local rep
for _, r in ipairs(st.teams) do if r.key == "player" then rep = r end end
check(rep and rep.audit_bad == 0 and rep.audit_ok >= 1, "aucun avant-poste dans un secteur jamais vu (" ..
  tostring(rep and rep.audit_ok) .. " contrôlés)")
local unseen = 0
for _, s in ipairs(remote.call("fo-ia3f", "prospects", "player")) do if not s.seen then unseen = unseen + 1 end end
check(unseen == 0, "aucun site en réserve dans un secteur jamais vu")
check(rep and rep.deaths == 0, "aucun éclaireur mort")
check(pcall(M.serialize, global), "global sérialisable")
local t_fog_found, t_fog_iron = found, t_iron
print(string.format("  avec brouillard : fer vu à %.1f min, avant-poste de fer à %s min, %d secteurs vus, %d regards",
  (found or 0) / 3600, tostring(t_iron and t_iron / 3600), k.m.n, st.stats.looks))

-- 2. Brouillard coupé : comportement d'avant le lot.
f = pteam_world(false)
local ok2, t_iron2 = pcall(iron_outpost_tick, f, 20 * 3600)
check(ok2 and t_iron2 ~= nil, "sans brouillard : avant-poste de fer construit (" .. tostring(t_iron2 and t_iron2 / 3600) .. " min)")
check(f.ai3f == nil and remote.call("fo-ia3f", "status").stats.looks == 0, "sans brouillard : aucune carte, aucun regard")
-- Lot IA-V2 : avec le cerveau par besoins (allumé par défaut), le gisement VU est retenu dès qu'il est vu
-- (Sites.probe_at) : l'avant-poste sous brouillard peut venir AVANT la prospection omnisciente (1,2 contre 1,7 min au
-- moteur simulé, 27/10). Le contrôle garde le critère de la conception (§6.2) : au plus 5 min plus tard qu'avant le lot.
check(t_iron2 and t_fog_iron and t_fog_iron <= t_iron2 + 5 * 3600,
  "avec brouillard, l'avant-poste de fer au plus 5 min plus tard que sans (critère §6.2)")
print(string.format("  sans brouillard : avant-poste de fer à %s min (avec : %s min)", tostring(t_iron2 and t_iron2 / 3600),
  tostring(t_fog_iron and t_fog_iron / 3600)))

---------------------------------------------------------------------------------------------------
-- 3. Minage d'appoint au-delà de 96 tuiles
---------------------------------------------------------------------------------------------------
do
  M.new_game({ patches = { { x = 40, y = 10, name = "coal" }, { x = 100, y = 100, name = "iron-ore" } }, p_busy = 0, p_nopath = 0, p_lost = 0 })
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  chest.insert({ name = "pistol", count = 2 })
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  M.run_ticks(600)
  local pf = global.fo.pteam.team
  local Worker = require("script.team.worker")
  local task = { kind = "mine", key = "mine:iron-ore", resource = "iron-ore", count = 20 }
  local steps = Worker.program(pf, task, s, game.tick)
  check(steps ~= nil and task.target and (task.target.x - 100) ^ 2 + (task.target.y - 100) ^ 2 < 30 * 30,
    "minage d'appoint : gisement connu à 134 tuiles choisi (" .. tostring(task.target and task.target.x) .. ")")
  local t2 = { kind = "mine", key = "mine:copper-ore", resource = "copper-ore", count = 20 }
  check(Worker.program(pf, t2, s, game.tick) == nil and pf.ai3f.req["copper-ore"] ~= nil and pf.ai3f.req["copper-ore"].why == "minage",
    "ressource inconnue : pas de minage, exploration demandée (minage)")
  local t3 = { kind = "mine", key = "mine:iron-ore", resource = "iron-ore", count = 20, fond = true, radius = 96 }
  check(Worker.program(pf, t3, s, game.tick) == nil, "minage de FOND : jamais au-delà de son rayon")
end

---------------------------------------------------------------------------------------------------
-- 4. Factions : étape « explore » du cerveau pour une ressource jamais vue
---------------------------------------------------------------------------------------------------
local function faction_world()
  local out = {}
  local d = 0.7071
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for ci, c in ipairs({ { d, -d }, { d, d }, { -d, d }, { -d, -d } }) do
    local hx, hy = c[1] * 320, c[2] * 320
    for i, v in ipairs({ { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }) do
      out[#out + 1] = { x = hx + v[1] * 50, y = hy + v[2] * 50, name = names[i] }
    end
  end
  -- Pétrole loin du QG nord-est (226, -226) : à 620 tuiles vers l'est-nord-est.
  out[#out + 1] = { x = 820, y = -400, name = "crude-oil", amount = 300000 }
  M.new_game({ patches = out, p_busy = 0, p_nopath = 0, p_lost = 0 })
  check(remote.call("factorio-overhaul", "war_start", 4, 20, 4, 320) == true, "guerre lancée (4 factions, 4 PNJ)")
end

local function run_oil()
  faction_world()
  M.run_ticks(3 * 3600)
  local war = global.fo.war
  local f1 = war.factions[1]
  local asked = remote.call("fo-ia3f", "request", f1.key, "crude-oil")
  local t0 = game.tick
  local found
  for _ = 1, 30 * 6 do
    M.run_ticks(600)
    if f1.ai3f and f1.ai3f.m.found["crude-oil"] then found = f1.ai3f.m.found["crude-oil"] break end
  end
  return f1, asked, t0, found
end

local f1, asked, t0, oil = run_oil()
check(asked == "demande", "étape explore : demande ouverte (" .. tostring(asked) .. ")")
check(oil ~= nil and oil - t0 <= 30 * 3600, "pétrole trouvé moins de 30 min après l'étape explore (" ..
  tostring(oil and (oil - t0) / 3600) .. " min)")
check(f1.ai3f.req["crude-oil"] == nil and count_logs("exploration crude-oil : trouve") >= 1, "demande fermée « trouvé »")
M.run_ticks(2 * 3600)
check(f1.ai3f.ex == nil or f1.ai3f.ex.res ~= "crude-oil", "l'éclaireur du pétrole est rentré")
local bad = 0
for _, ff in pairs(global.fo.war.factions) do
  for _, s in ipairs(ff.prospects or {}) do
    if ff.ai3f and not K.seen_xy(ff.ai3f.m, s.x, s.y) and not s.seeded then bad = bad + 1 end
  end
end
check(bad == 0, "factions : aucun site en réserve dans un secteur jamais vu")
local st4 = remote.call("fo-ia3f", "status")
local abad = 0
for _, r in ipairs(st4.teams) do abad = abad + (r.audit_bad or 0) end
check(abad == 0, "factions : aucun avant-poste dans un secteur jamais vu")
check(pcall(M.serialize, global), "global sérialisable (factions)")
local logline = first_log("premier gisement de crude-oil")
print("  " .. tostring(logline))

-- 5. Déterminisme : la même partie deux fois.
local snap1 = { n = f1.ai3f.m.n, oil = oil, looks = st4.stats.looks }
local f1b, _, _, oilb = run_oil()
M.run_ticks(2 * 3600)
local st5 = remote.call("fo-ia3f", "status")
check(oilb == snap1.oil and f1b.ai3f.m.n == snap1.n and st5.stats.looks == snap1.looks,
  string.format("déterminisme : même date du pétrole (%s / %s), mêmes secteurs (%d / %d), mêmes regards (%d / %d)",
    tostring(snap1.oil), tostring(oilb), snap1.n, f1b.ai3f.m.n, snap1.looks, st5.stats.looks))

print(string.format("[IA3F] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
