--[[
  Lot NIDS : banc HORS JEU du branchement (script/ai3/soldats.lua sur shared/ai3/nids.lua), moteur simulé. Une faction (la
  première de la guerre) reçoit 20 soldats, des nids ennemis (entités « unit-spawner » de force enemy) et une carte de
  connaissance où ces nids sont (ou ne sont pas) VUS :
    - lancement : l'opération part avec le besoin de la règle et garde sa garnison ;
    - nid inconnu de la faction : aucune opération ; réglage éteint : aucune opération ;
    - nids détruits : opération finie par l'état du moteur, nids effacés de la carte de connaissance, aucune relance ;
    - pertes de 40 % : repli, attente de 5 min, puis nouvelle opération plus grosse ;
    - délai dépassé : abandon et attente ; incident subi : un nid trop faible devient une cible ; déterminisme.
  Lancement : lua5.2 tests/nids_moteur_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

local F, K, Nd, Military, C, Sd, State

local function fresh(opts)
  opts = opts or {}
  M.new_game({ patches = {}, p_busy = 0, p_nopath = 0, p_lost = 0, nids = opts.nids })
  F, K, Nd, Sd = require("shared.faction.config"), require("shared.ai3.carte"), require("shared.ai3.nids"), require("shared.ai3.soldats")
  Military, C, State = require("script.faction.military"), require("script.ai3.comportement"), require("script.faction.state")
  M.command("fo-war", "start 2 60 6 320")
  M.run_ticks(3600 * 2)
  local f = global.fo.war.factions[1]
  local s = game.surfaces[1]
  Military.train(f, s, F.best_soldier(f.tech), opts.soldiers or 20)
  W().prototypes["biter-spawner"] = { type = "unit-spawner", max_health = 350,
    collision_box = { left_top = { x = -2, y = -2 }, right_bottom = { x = 2, y = 2 } } }
  local hx, hy = f.hq_pos.x, f.hq_pos.y
  local nests = {}
  local list = opts.nests or { { 120, 0 }, { 130, 10 } }
  for i, d in ipairs(list) do
    nests[i] = s.create_entity({ name = "biter-spawner", position = { x = hx + d[1], y = hy + d[2] }, force = "enemy" })
  end
  if opts.known ~= false then
    local pts = {}
    for _, d in ipairs(list) do pts[#pts + 1] = { x = hx + d[1], y = hy + d[2] } end
    K.record(f.ai3f.m, K.key_of(pts[1].x, pts[1].y), game.tick, { nests = pts })
  end
  return f, s, nests
end

local function team(f) return C.team(f) end
local function stats(f) return (team(f).nids or {}).stats or {} end
local function op(f) return team(f).sd and team(f).sd.nop end
local function nests_known(f)
  local n = Nd.known(f.ai3f.m, { { x = f.hq_pos.x, y = f.hq_pos.y } }, 400)
  return #n
end

---------------------------------------------------------------------------------------------------
section("Lancement")
local f = fresh()
M.run_ticks(3600)
local o = op(f)
check(stats(f).ops == 1 and o ~= nil, "une opération part vers les nids vus (ops " .. tostring(stats(f).ops) .. ")")
check(o and o.engaged == Sd.clear_need(2), "engagés = besoin de la règle pour 2 nids (" .. tostring(o and o.engaged) .. ")")
check(o and o.engaged <= 20 - Nd.reserve(20), "la garnison gardée (" .. Nd.reserve(20) .. ") n'est pas entamée")
local st = remote.call("fo-nids", "status", f.key)
check(st.enabled and st.menacing == 1 and #st.sites == 1 and st.sites[1].sp == 2 and st.op ~= nil, "interface fo-nids : 1 site menaçant, opération en cours")
local clearing = 0
for _, ps in pairs(team(f).sd.per) do if ps.role == "clear" then clearing = clearing + 1 end end
check(o and clearing == o.engaged, "les engagés portent le rôle de nettoyage (" .. clearing .. ")")
M.run_ticks(1200)
check(stats(f).ops == 1, "toujours une seule opération à la fois")

section("Nid inconnu, réglage éteint")
local f2 = fresh({ known = false })
M.run_ticks(3600 * 3)
check((stats(f2).ops or 0) == 0, "nid non vu par la faction : aucune opération")
local f3 = fresh({ nids = false })
M.run_ticks(3600 * 3)
check((stats(f3).ops or 0) == 0 and op(f3) == nil, "réglage fo-war-nids éteint : aucune opération")
check(remote.call("fo-nids", "status", f3.key).enabled == false, "interface : réglage éteint")

section("Nids détruits : fin lue au moteur")
local f4, _, n4 = fresh()
M.run_ticks(3600)
check(op(f4) ~= nil, "opération lancée")
for _, e in ipairs(n4) do e.destroy() end
M.run_ticks(1800)
check(stats(f4).done == 1 and op(f4) == nil, "plus de nid au moteur : opération terminée (done " .. tostring(stats(f4).done) .. ")")
check(nests_known(f4) == 0, "les nids détruits sont effacés de la carte de connaissance")
check(#team(f4).nids.holds == 0, "aucune attente après une victoire")
M.run_ticks(3600 * 4)
check(stats(f4).ops == 1, "aucune nouvelle opération vers un nid détruit")

section("Pertes de 40 % : repli, attente, nouvelle opération plus grosse")
local f5 = fresh()
M.run_ticks(3600)
local o5 = op(f5)
local need0 = o5.engaged
local killed = 0
for _, id in ipairs(o5.ids) do
  if killed < math.ceil(need0 * 0.4) then
    f5.soldiers[id].entity.destroy()
    killed = killed + 1
  end
end
M.run_ticks(600)
check(stats(f5).retreat == 1 and op(f5) == nil, "40 % de morts : repli (retreat " .. tostring(stats(f5).retreat) .. ")")
check(#team(f5).nids.holds == 1 and team(f5).nids.holds[1].fails == 1, "attente ouverte, 1 échec")
local until1 = team(f5).nids.holds[1]["until"]
check(until1 - game.tick > 4 * 3600 and until1 - game.tick <= 5 * 3600, "attente d'environ 5 min (" .. (until1 - game.tick) .. " ticks restants)")
M.run_ticks(3600 * 3)
check(stats(f5).ops == 1, "pendant l'attente : aucune nouvelle opération")
M.run_ticks(3600 * 3)
check(stats(f5).ops == 2 and op(f5) ~= nil, "attente écoulée : nouvelle opération (ops " .. tostring(stats(f5).ops) .. ")")
check(op(f5) and op(f5).engaged > need0 and op(f5).fails == 1, "plus de soldats après un échec (" .. tostring(op(f5) and op(f5).engaged) .. " contre " .. need0 .. ")")

section("Délai dépassé")
local f6 = fresh()
M.run_ticks(3600)
check(op(f6) ~= nil, "opération lancée")
M.run_ticks(3600 * 6)
check(stats(f6).timeout == 1 and #team(f6).nids.holds == 1, "les nids restent, délai dépassé : abandon et attente (timeout " .. tostring(stats(f6).timeout) .. ")")

section("Incident subi")
local f7 = fresh({ nests = { { 195, 0 } } })
M.run_ticks(3600 * 3)
check((stats(f7).ops or 0) == 0, "nid à 195 tuiles du QG, aucun incident : trop faible")
local fake = { valid = true, type = "ammo-turret", position = { x = f7.hq_pos.x + 150, y = f7.hq_pos.y }, force = game.forces[f7.force] }
W().events[defines.events.on_entity_died]({ entity = fake, force = game.forces.enemy, tick = game.tick })
check((stats(f7).incidents or 0) == 1, "mort d'une tourelle de la faction par l'ennemi : incident compté")
M.run_ticks(3600 * 2)
check(stats(f7).ops == 1, "le même nid, qui a frappé : opération lancée (ops " .. tostring(stats(f7).ops) .. ")")
local f8 = fresh({ nests = { { 195, 0 } } })
W().events[defines.events.on_entity_died]({ entity = { valid = true, type = "ammo-turret",
  position = { x = f8.hq_pos.x + 150, y = f8.hq_pos.y }, force = game.forces[f8.force] }, force = game.forces.player, tick = game.tick })
check((stats(f8).incidents or 0) == 0, "détruit par une force qui n'est pas l'ennemi : aucun incident")

section("Déterminisme")
local function summary()
  local ff = fresh()
  M.run_ticks(3600 * 3)
  local s2 = stats(ff)
  return string.format("%s/%s/%s/%s/%s", tostring(s2.ops), tostring(s2.engaged), tostring(s2.done), tostring(s2.timeout),
    tostring(op(ff) and op(ff).engaged))
end
local a = summary()
local b = summary()
check(a == b, "deux parties identiques : mêmes opérations (" .. a .. " / " .. b .. ")")

print(string.format("[NIDS-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
