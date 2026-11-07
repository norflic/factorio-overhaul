--[[
  Lot IA3-k : banc HORS JEU du branchement (script/ai3/comportement.lua sur script/team/worker.lua), moteur simulé.
  Votre équipe (coffre posé), cerveau retenu par l'interface « fo-ia3k » (hold), tournées injectées :
    - variation (C1) : tournées vers le même but par des points de passage différents ;
    - ver posé sur la route (C2) : vu, marqué, détour ; le PNJ ne passe jamais à sa portée ;
    - peur (C3) : PNJ blessé près d'une unité ennemie : fuite (refuge, tâche rendue) ; prudent avant audacieux ;
    - morts (C5) : porte d'une tâche vers un lieu de 1 puis 2 morts : attente ;
    - étiquettes (D1) ; réglage éteint : aucun effet ; déterminisme (deux passages identiques) ; global sérialisable.
  Le moteur simulé n'a pas de recherche d'ennemis : find_nearest_enemy est remplacé ici par une recherche réelle sur
  ses entités (force « enemy »).
  Lancement : lua5.2 tests/ia3k_moteur_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

local function enemy_search()
  local s = game.surfaces[1]
  s.find_nearest_enemy = function(t)
    assert(t.position and t.max_distance and t.force, "find_nearest_enemy : arguments")
    local best, bd
    for _, e in ipairs(W().entities) do
      if e.valid and e.force and e.force.name == "enemy" then
        local dx, dy = e._x - t.position.x, e._y - t.position.y
        local d = dx * dx + dy * dy
        if d <= t.max_distance * t.max_distance and (not bd or d < bd) then best, bd = e, d end
      end
    end
    return best
  end
end

local function setup(opts)
  opts = opts or {}
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, ia3k = opts.ia3k })
  -- Après la fusion d'IA-V2 (lot IA3-f) : éclaireurs et tour du QG coupés (ils prennent les PNJ libres des tournées du
  -- banc) ; interface absente sur main : rien ne change.
  if W().remote["fo-ia3f"] then remote.call("fo-ia3f", "set_fog", false) end
  W().prototypes["small-worm-turret"] = { type = "turret", max_health = 200,
    collision_box = { left_top = { x = -0.9, y = -0.8 }, right_bottom = { x = 0.9, y = 0.8 } },
    attack_parameters = { range = 25 } }
  enemy_search()
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "coal", 200 }, { "pistol", 2 }, { "firearm-magazine", 40 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  check(remote.call("fo-ia3k", "hold", "player", true) == true, "cerveau retenu (hold)")
  M.run_ticks(600) -- les PNJ rentrent au coffre, sans tâche
  return global.fo.pteam.team
end

local function agent_ids(f)
  local ids = {}
  for id in pairs(f.engineers) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

local function pos_of(id)
  local a = require("script.companion.registry").get(id)
  return a and a.entity.valid and a.entity.position or nil
end

--- Joue une tournée de l'agent `id` vers (x, y) ; renvoie la liste des positions (toutes les 10 ticks) et la fin.
local function play_trip(id, x, y, max_ticks)
  local n = remote.call("fo-ia3k", "trip", "player", id, x, y, 30)
  local pts = {}
  local Registry = require("script.companion.registry")
  local t = 0
  while t < (max_ticks or 6000) do
    M.run_ticks(10)
    t = t + 10
    local a = Registry.get(id)
    if not a then break end
    local p = a.entity.position
    pts[#pts + 1] = { x = p.x, y = p.y }
    if not a.task and t > 120 then break end
  end
  -- Positions de l'ALLER seul (jusqu'à 5 tuiles du but).
  local out = {}
  for _, p in ipairs(pts) do
    out[#out + 1] = p
    local dx, dy = p.x - x, p.y - y
    if dx * dx + dy * dy <= 25 then break end
  end
  return pts, n, out
end

local function min_d(pts, x, y)
  local m = 1e9
  for _, p in ipairs(pts) do
    local dx, dy = p.x - x, p.y - y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < m then m = d end
  end
  return m
end

---------------------------------------------------------------------------------------------------
section("Variation des tournées (C1)")
local f = setup()
-- Lot CORR-RALLIEMENT : portée d'attaque de la mitrailleuse au prototype simulé (18, comme le jeu), posée AVANT tout regard : la
-- profil d'attaque est gardé en cache par nom de prototype (script/ai3/comportement.lua, M.attack_profile).
W().prototypes["gun-turret"].attack_parameters = { range = 18 }
local ids = agent_ids(f)
check(#ids >= 2, "au moins 2 PNJ (" .. #ids .. ")")
local R = require("shared.ai3.route")
local S0, G0 = { x = 5, y = 5 }, { x = 125, y = 5 }
local trips = {}
for k = 1, 8 do
  local _, _, out = play_trip(ids[1], G0.x, G0.y, 4000)
  trips[k] = out
end
local wide, meds = 0, {}
for k = 1, 7 do
  local med = R.median_gap(S0, G0, trips[k], trips[k + 1], 8)
  meds[#meds + 1] = string.format("%.1f", med)
  if med >= 4 then wide = wide + 1 end
end
local st = remote.call("fo-ia3k", "status", "player")
check(st.stats.via >= 8, "points de passage de variation tirés (" .. tostring(st.stats.via) .. ")")
check(wide >= 4, "écart médian ≥ 4 tuiles entre allers successifs : " .. wide .. " sur 7 (" .. table.concat(meds, " ") .. ")")
local reached, long_ok = 0, true
for k = 1, 8 do
  if min_d(trips[k], G0.x, G0.y) <= 5 then reached = reached + 1 end
  local L = 0
  for i = 2, #trips[k] do L = L + R.dist(trips[k][i - 1].x, trips[k][i - 1].y, trips[k][i].x, trips[k][i].y) end
  if L > 1.15 * 120 + 10 then long_ok = false end
end
check(reached == 8, "les 8 allers arrivent au but (" .. reached .. ")")
check(long_ok, "aucun aller allongé de plus de 15 % (+ 10 tuiles d'arrivée)")

---------------------------------------------------------------------------------------------------
section("Ver sur la route : vu, marqué, détour (C2)")
local s = game.surfaces[1]
-- Le ver est posé SUR l'itinéraire tiré (entre les deux points de passage de la variation), une fois la tournée partie.
local WX, WY = 165, 5
local function trip_with_worm(id, gx, gy)
  local Reg = require("script.companion.registry")
  remote.call("fo-ia3k", "trip", "player", id, gx, gy, 30)
  M.run_ticks(5)
  local a = global.fo.ia3k.agents[id]
  if a and a.pts and #a.pts == 2 then
    WX, WY = (a.pts[1].x + a.pts[2].x) / 2, (a.pts[1].y + a.pts[2].y) / 2
  end
  local w = s.create_entity({ name = "small-worm-turret", position = { x = WX, y = WY }, force = "enemy" })
  local pts = {}
  for _ = 1, 900 do
    M.run_ticks(10)
    local ag = Reg.get(id)
    if not ag then break end
    local p = ag.entity.position
    pts[#pts + 1] = { x = p.x, y = p.y }
    if not ag.task then break end
  end
  return pts, w
end
local pts, worm = trip_with_worm(ids[2], 325, 5)
check(worm ~= nil and worm.type == "turret", string.format("ver posé sur l'itinéraire tiré, en (%.0f, %.0f)", WX, WY))
st = remote.call("fo-ia3k", "status", "player")
check((st.stats.seen.worm or 0) >= 1, "ver vu (" .. tostring(st.stats.seen.worm) .. " regard(s))")
check((st.stats.actions.detour or 0) >= 1, "détour décidé (" .. tostring(st.stats.actions.detour) .. ")")
check(st.summary.worms == 1, "ver retenu sur la carte de l'équipe")
local md = min_d(pts, WX, WY)
check(md > 25, "le PNJ n'entre jamais à portée du ver (25 tuiles) : au plus près " .. string.format("%.1f", md))
check(min_d(pts, 325, 5) <= 5, "il arrive quand même au but par le détour")
local labels = 0
for _, r in pairs(W().renders) do
  if type(r.text) == "table" and r.text[1] == "fo-ia3k.etat-detour" then labels = labels + 1 end
end
check(labels >= 1, "état « Détour » affiché au-dessus du PNJ (D1)")
-- Deuxième tournée : le ver est connu, l'itinéraire l'évite d'emblée (A*), sans nouvel arrêt.
local d0 = st.stats.actions.detour or 0
local pts2 = play_trip(ids[2], 325, 5, 9000)
st = remote.call("fo-ia3k", "status", "player")
check(st.stats.astar >= 1, "itinéraire calculé autour du ver connu (A* " .. tostring(st.stats.astar) .. ")")
check(min_d(pts2, WX, WY) > 25, "deuxième tournée : jamais à portée (" .. string.format("%.1f", min_d(pts2, WX, WY)) .. ")")
check((st.stats.actions.detour or 0) == d0, "deuxième tournée sans nouvel arrêt (route déjà sûre)")
check((st.stats.chained or 0) > 0, "tronçons enchaînés sans arrêt (" .. tostring(st.stats.chained) .. ")")

---------------------------------------------------------------------------------------------------
section("Peur (C3)")
local Registry = require("script.companion.registry")
local victim = Registry.get(ids[3])
remote.call("fo-ia3k", "trip", "player", ids[3], -150, 5, 600)
M.run_ticks(600) -- à plus de 32 tuiles du QG (près du QG, on se bat groupés : contrôle plus bas)
local vp = victim.entity.position
local biter = s.create_entity({ name = "small-biter", position = { x = vp.x - 12, y = vp.y }, force = "enemy" })
victim.entity.health = 80 -- 32 % de vie
local t0 = game.tick
local fled_at
for _ = 1, 12 do
  M.run_ticks(10)
  local a = global.fo.ia3k.agents[ids[3]]
  if a and a.refuge and not fled_at then fled_at = game.tick end
end
check(fled_at ~= nil and fled_at - t0 <= 60, "fuite engagée en ≤ 1 s (" .. tostring(fled_at and fled_at - t0) .. " ticks)")
check(victim.task and victim.task.fail == "fuite", "la tournée est rendue (fuite)")
st = remote.call("fo-ia3k", "status", "player")
check((st.stats.actions.flee or 0) >= 1 and st.stats.refuges >= 1, "fuite comptée, refuge choisi")
biter.destroy()
-- Près du QG, sans tourelle : un ouvrier blessé face à une unité ne fuit pas seul, il se bat sur place (groupés).
local homer = Registry.get(ids[6])
local hp0 = homer.entity.position
local b2 = s.create_entity({ name = "small-biter", position = { x = hp0.x + 6, y = hp0.y }, force = "enemy" })
local fl0 = remote.call("fo-ia3k", "status", "player").stats.actions.flee or 0
local en0 = remote.call("fo-ia3k", "status", "player").stats.actions.engage or 0
homer.entity.health = 80
M.run_ticks(130)
st = remote.call("fo-ia3k", "status", "player")
check((st.stats.actions.flee or 0) == fl0 and (st.stats.actions.engage or 0) > en0,
  "près du QG sans tourelle : combat sur place, pas de fuite isolée")
b2.destroy()

---------------------------------------------------------------------------------------------------
section("Mémoire des morts (C5) : la porte")
local C = require("script.ai3.comportement")
remote.call("fo-ia3k", "forget", "player") -- carte remise à zéro : les combats ci-dessus ont marqué les abords du QG
local ag = Registry.get(ids[4])
local task = { key = "test:service", kind = "service" }
local steps = { { "home" }, { "goto", { x = -5, y = 140 }, 3 }, { "act", "service" }, { "home" } }
check(C.gate(f, ag, task, steps, game.tick) == false, "cerveau retenu : la porte refuse (banc)")
remote.call("fo-ia3k", "hold", "player", false)
check(C.gate(f, ag, task, steps, game.tick) == true, "trajet sûr : la tâche part")
remote.call("fo-ia3k", "death", "player", -5, 130)
-- Lot DANGER-ACTIF (DC 4/11 19 h 10 et 19 h 12 : « ils continuent de travailler en évitant le danger » ; avant : attente) : 1 ou 2 morts sur la route, sans escorte :
-- le PNJ PART par le chemin du moindre danger, risque accepté (réflexes gardés), jamais une attente.
check(C.gate(f, ag, task, steps, game.tick) == true and C.astate(ag).risk == true,
  "DANGER-ACTIF : 1 mort près du but, pas d'escorte possible : le PNJ part (risque accepté), il n'attend plus")
remote.call("fo-ia3k", "death", "player", 0, 135)
-- 2 morts de l'heure sur le chemin (docs/IA_ATTENDUS.md C5 : au plus 2 morts au même endroit par heure) : pas de marche suicide, mais plus d'attente non plus :
-- la tâche est MISE DE CÔTÉ (raison « danger-but », pause bornée) et le PNJ prend une autre tâche.
task.fail = nil
check(C.gate(f, ag, task, steps, game.tick) == false and task.fail == require("shared.team.danger_actif").ASIDE_FAIL,
  "DANGER-ACTIF : 2 morts dans l'heure : tâche mise de côté (pas de marche suicide), le PNJ prend une autre tâche (avant : attente d'une heure)")
M.run_ticks(61 * 3600)
check(C.gate(f, ag, task, steps, game.tick) == true, "une heure plus tard : la tâche repart")
-- Lot COMPAGNONS-ACTIFS (DC 29/10 : « la peur c'est bien, mais pour fuir si jamais ils se font attaquer. Mais sinon il faut revenir ») :
-- une tâche PROCHE du QG (but à 140 tuiles, moins de C.SAFE_RADIUS) aux morts toutes plus anciennes que Ac.FEAR_TICKS repart sans attendre
-- l'heure ; l'attaque en cours (morts récentes) la retient toujours. Le cas LOINTAIN (morts anciennes, but à 283 tuiles) est D-B plus bas.
do
  local Ac = require("shared.team.actif")
  remote.call("fo-ia3k", "forget", "player")
  remote.call("fo-ia3k", "death", "player", -5, 130)
  remote.call("fo-ia3k", "death", "player", 0, 135)
  local ta = game.tick
  check(C.gate(f, ag, { key = "test:actif", kind = "service" }, steps, ta + 60) == false and C.astate(ag).calm == nil,
    "COMPAGNONS-ACTIFS : 2 morts il y a 1 s près du but proche (attaque en cours) : tâche mise de côté, pas « au calme » (DANGER-ACTIF : autre tâche au lieu de l'attente)")
  local ca0 = (global.fo.ia3k.teams["player"].actif or { calm = 0 }).calm
  check(C.gate(f, ag, { key = "test:actif", kind = "service" }, steps, ta + Ac.FEAR_TICKS + 60) == true,
    "COMPAGNONS-ACTIFS : 2 morts de plus de 1 min, aucune menace connue, but proche : la tâche repart (avant : 1 h d'attente)")
  check(global.fo.ia3k.teams["player"].actif.calm == ca0 + 1, "COMPAGNONS-ACTIFS : porte comptée (bilan [FO-ACTIF])")
  check(C.astate(ag).calm == true, "COMPAGNONS-ACTIFS (relecture) : départ « au calme » noté sur le PNJ (lu par M.leg et le recontrôle d'époque)")
  remote.call("fo-ia3k", "mark", "player", -5, 142, "worm", 25)
  check(C.gate(f, ag, { key = "test:actif2", kind = "service" }, steps, ta + Ac.FEAR_TICKS + 120) == false,
    "COMPAGNONS-ACTIFS : morts anciennes mais but à portée d'un ver connu : tâche mise de côté (DANGER-ACTIF : autre tâche, la menace reste jugée)")
  check(C.astate(ag).calm == nil, "COMPAGNONS-ACTIFS (relecture) : refus : plus de départ « au calme » sur le PNJ")
  remote.call("fo-ia3k", "forget", "player")
end
-- Pas d'escalade vers un but À PORTÉE d'un ver connu (11 tuiles d'un ver de portée 25) : refusé à chaque fois.
remote.call("fo-ia3k", "mark", "player", 160, -140, "worm", 25)
local steps_in = { { "home" }, { "goto", { x = 165, y = -150 }, 3 }, { "act", "service" }, { "home" } }
local refused_in = 0
for _ = 1, 8 do
  if not C.gate(f, ag, { key = "test:service-in", kind = "service" }, steps_in, game.tick) then refused_in = refused_in + 1 end
end
check(refused_in == 8, "but à portée d'un ver connu : jamais d'escalade, tâche mise de côté à chaque fois (" .. refused_in .. " refus sur 8)")
do -- DANGER-ACTIF : la tâche mise de côté porte sa raison (pause bornée) et le ver du but est signalé aux soldats
  local mk = { key = "test:aside", kind = "service" }
  C.gate(f, ag, mk, steps_in, game.tick)
  local Da = require("shared.team.danger_actif")
  local Ac = require("shared.team.actif")
  check(mk.fail == Da.ASIDE_FAIL and Ac.retry(mk.fail, false, 1800) == Da.ASIDE_TICKS, "DANGER-ACTIF : tâche mise de côté : raison « danger-but », pause bornée " .. Da.ASIDE_TICKS .. " ticks")
  local blocked_th = false
  for _, th in ipairs(global.fo.ia3k.teams["player"].map.threats) do if th.b then blocked_th = true end end
  check(blocked_th, "DANGER-ACTIF : le ver du but est signalé aux soldats (nettoyage)")
end
remote.call("fo-ia3k", "forget", "player")
-- Escalade : une destination HORS de portée mais entourée de vers VUS (sans mort ; tout trajet passe à leur portée) est
-- refusée W fois (W = 4 pour un neutre), puis la tâche part (risque accepté), et les vers qui bloquent sont signalés
-- (nettoyage par la garnison quel que soit le caractère).
local gx, gy = 120, -200 -- autre case que le but précédent (les attentes se comptent par case de destination)
local ring = { { 40, 0 }, { 28, 28 }, { 0, 40 }, { -28, 28 }, { -40, 0 }, { -28, -28 }, { 0, -40 }, { 28, -28 } }
for _, o in ipairs(ring) do remote.call("fo-ia3k", "mark", "player", gx + o[1], gy + o[2], "worm", 25) end
local steps2 = { { "home" }, { "goto", { x = gx, y = gy }, 3 }, { "act", "service" }, { "home" } }
local refusals, went = 0, false
for _ = 1, 8 do
  if C.gate(f, ag, { key = "test:service2", kind = "service" }, steps2, game.tick) then went = true break end
  refusals = refusals + 1
end
-- Lot DANGER-ACTIF (DC 4/11 19 h 10 et 19 h 12) : destination HORS de portée mais entourée de vers : plus d'attente (avant : 4 refus puis escalade, passe-droit de 5 min,
-- étiquette « Trop dangereux » au 2e refus) ; le PNJ part tout de suite par le chemin du moindre danger, risque accepté, étiquette « contourne ».
-- Relecture du lead (5/11, B1) : une destination HORS de portée mais ENTOURÉE de vers (tout chemin passe à portée d'une menace fixe) n'est plus attendue ni escaladée
-- (avant : 4 refus puis escalade, passe-droit de 5 min, étiquette « Trop dangereux » au 2e refus) ; partir ferait un demi-tour à portée, un abandon « danger » et un
-- retour au tableau 600 ticks plus tard, sans fin : la tâche est MISE DE CÔTÉ (raison « danger-but », pause bornée), le PNJ prend une autre tâche, et les vers
-- QUI BLOQUENT LA ROUTE sont signalés aux soldats (nettoyage), ce que le contrôle « le ver qui bloque est signalé aux soldats » de main exigeait.
local Dax = require("shared.team.danger_actif")
local tstats = global.fo.ia3k.teams["player"].stats
local esc0, pd0 = tstats.escalade or 0, tstats.passe_droit or 0
local t_esc = game.tick
local asides = 0
for i = 1, 8 do
  local tk = { key = "test:service2", kind = "service" }
  if C.gate(f, ag, tk, steps2, t_esc + i * 400) == false and tk.fail == Dax.ASIDE_FAIL then asides = asides + 1 end
end
check(asides == 8, "DANGER-ACTIF : route entourée de vers, but libre : mise de côté à chaque appel, jamais de départ ni d'attente (" .. asides .. " sur 8)")
check(global.fo.ia3k.agents[ag.id].risk ~= true, "DANGER-ACTIF : aucune tournée partie en « risque accepté » à travers l'anneau de vers")
local blocking = false
for _, th in ipairs(global.fo.ia3k.teams["player"].map.threats) do if th.b then blocking = true end end
check(blocking, "le ver qui bloque est signalé aux soldats")
check((tstats.escalade or 0) == esc0 and (tstats.passe_droit or 0) == pd0, "DANGER-ACTIF : ni escalade ni passe-droit")
check((tstats.labels.attente or 0) == 0, "DANGER-ACTIF : jamais d'étiquette « Trop dangereux »")
check(require("shared.team.actif").retry(Dax.ASIDE_FAIL, false, 1800) == Dax.ASIDE_TICKS, "DANGER-ACTIF : pause bornée avant de reprendre la tâche mise de côté")
local C_rest = tstats.dact or {}
check((C_rest.aside or 0) >= 8, "DANGER-ACTIF : mises de côté comptées au bilan")
local gx3, gy3 = -150, -200
for _, o in ipairs(ring) do remote.call("fo-ia3k", "mark", "player", gx3 + o[1], gy3 + o[2], "worm", 25) end
local steps3 = { { "home" }, { "goto", { x = gx3, y = gy3 }, 3 }, { "act", "service" }, { "home" } }
local tt = t_esc + 3 * C.PASS_TICKS
check(C.gate(f, ag, { key = "test:service3", kind = "service" }, steps3, tt) == false and C.gate(f, ag, { key = "test:service3", kind = "service" }, steps3, tt + 400) == false,
  "DANGER-ACTIF : second but entouré de vers : mis de côté aux deux appels (aucune attente, aucune étiquette)")
-- Lot INTEG-DEFENSE D-B, revu au lot PORTE-BASE (arbitrage du DC, 29/10) : une tâche de DÉFENSE (fortify, refill) dont les morts de la
-- route sont TOUTES dans la zone de base (densité de bâtiments, shared/ai3/base.lua) part tout de suite : la base se défend. Une mort HORS
-- de la base (route vers un lieu sans bâtiments) garde la règle d'IA3-k : refus à chaque fois, sans escalade. Une autre tâche garde la
-- règle partout ; un but À PORTÉE d'une menace connue reste refusé même pour la défense.
remote.call("fo-ia3k", "forget", "player")
local gx4, gy4 = 200, 200
local ilot = {}
for ix = -1, 1 do
  for iy = -1, 1 do
    ilot[#ilot + 1] = game.surfaces[1].create_entity({ name = "assembling-machine-1", position = { x = gx4 + ix * 3, y = gy4 + iy * 3 }, force = "player" })
  end
end
local logs0 = #W().logs
local bz = remote.call("fo-ia3k", "base", "player", true, gx4, gy4)
-- (les sections d'avant ont bâti des avant-postes : foreuses, fours, tourelles ; ils comptent aussi)
check(bz.inside == true and bz.ents >= 9 and bz.comps >= 2, "PORTE-BASE : îlot de 9 machines autour du but : zone de base (" .. bz.n .. " cases, " .. bz.comps .. " composante(s), " .. bz.ents .. " bâtiments)")
check(remote.call("fo-ia3k", "base", "player", false, 100, 100).inside == false, "PORTE-BASE : la route à mi-chemin n'est pas la base")
local base_log = false
for i = logs0 + 1, #W().logs do if W().logs[i]:find("[FO-BASE] player : zone de base", 1, true) then base_log = true end end
check(base_log, "PORTE-BASE : journal [FO-BASE] de la taille de la zone")
remote.call("fo-ia3k", "death", "player", gx4, gy4 - 5)
remote.call("fo-ia3k", "death", "player", gx4 - 5, gy4)
local steps4 = { { "home" }, { "goto", { x = gx4, y = gy4 }, 3 }, { "act", "fortify" }, { "home" } }
local t4 = t_esc + 6 * C.PASS_TICKS
local refused_service = 0
for i = 1, 10 do
  if not C.gate(f, ag, { key = "test:service4", kind = "service" }, steps4, t4 + i) then refused_service = refused_service + 1 end
end
check(refused_service == 10, "D-B : 2 morts au but, tâche ordinaire : mise de côté à chaque fois, DANGER-ACTIF : autre tâche et non attente (" .. refused_service .. " sur 10)")
local pz0 = (remote.call("fo-ia3k", "base", "player").porte_zone["base:go"] or 0)
local base_went = C.gate(f, ag, { key = "test:fortify4", kind = "fortify", defend = true }, steps4, t4 + 101)
local pz = remote.call("fo-ia3k", "base", "player").porte_zone
check(base_went == true and (pz["base:go"] or 0) == pz0 + 1,
  "PORTE-BASE : 2 morts DANS la base, tâche « fortify » : départ au premier appel, compté base:go")
check(global.fo.ia3k.agents[ag.id].risk ~= true, "PORTE-BASE : départ ordinaire (pas une escalade, pas de « risque accepté »)")
local cause_log = false
for i = logs0 + 1, #W().logs do if W().logs[i]:find("la base se defend", 1, true) then cause_log = true end end
check(cause_log, "PORTE-BASE : journal [FO-BASE] de la cause (la base se défend)")
-- Une mort de plus HORS de la zone, sur la route (40 tuiles avant le but en diagonale, au-delà de la marge de 3 cases) : plus
-- d'exemption, refus sans escalade. Une mort JUSTE devant l'îlot (20 tuiles) reste « proche de la base » (relecture PORTE-BASE).
check(remote.call("fo-ia3k", "base", "player", false, gx4, gy4 - 22).inside == true, "PORTE-BASE : 22 tuiles devant l'îlot : proche de la base (marge)")
remote.call("fo-ia3k", "death", "player", gx4 - 40, gy4 - 40)
local mix_ref = 0
for i = 1, 10 do
  if not C.gate(f, ag, { key = "test:fortify4b", kind = "fortify", defend = true }, steps4, t4 + 200 + i) then mix_ref = mix_ref + 1 end
end
check(mix_ref == 10, "PORTE-BASE : 2 morts dans la base + 1 hors d'elle sur la route : défense mise de côté à chaque fois, DANGER-ACTIF : autre tâche et non attente (" .. mix_ref .. " sur 10)")
check((remote.call("fo-ia3k", "base", "player").porte_zone["hors:wait"] or 0) >= 10, "PORTE-BASE : refus comptés hors:wait")
for _, en in ipairs(ilot) do en.destroy() end
-- Même but SANS bâtiments (îlot détruit, zone recalculée) : les morts sont « à perpète », la défense ne part plus (avant ce lot : 4 attentes
-- puis départ, risque accepté).
remote.call("fo-ia3k", "forget", "player")
remote.call("fo-ia3k", "base", "player", true)
remote.call("fo-ia3k", "death", "player", gx4, gy4 - 5)
remote.call("fo-ia3k", "death", "player", gx4 - 5, gy4)
local def_ref = 0
local ed0 = tstats.escalade_defense or 0
for i = 1, 10 do
  if not C.gate(f, ag, { key = "test:fortify4c", kind = "fortify", defend = true }, steps4, t4 + 400 + i) then def_ref = def_ref + 1 end
end
check(def_ref == 10 and (tstats.escalade_defense or 0) == ed0,
  "PORTE-BASE : 2 morts HORS de la base, tâche « fortify » : mise de côté à chaque fois (DANGER-ACTIF : autre tâche et non attente), aucune escalade (" .. def_ref .. " sur 10)")
local hors_log = false
for i = logs0 + 1, #W().logs do if W().logs[i]:find("prudence gardee", 1, true) then hors_log = true end end
check(hors_log, "PORTE-BASE : journal [FO-BASE] de la cause (route meurtrière hors de la base)")
local logs1 = #W().logs
C.gate_report(f, t4 + 1000)
local bilan = nil
for i = logs1 + 1, #W().logs do if W().logs[i]:find("[FO-BASE] player : bilan", 1, true) then bilan = W().logs[i] end end
check(bilan ~= nil and bilan:find("base:go 1", 1, true) ~= nil and bilan:find("hors:wait", 1, true) ~= nil,
  "PORTE-BASE : bilan [FO-BASE] avec les compteurs de la porte par zone (" .. tostring(bilan) .. ")")
local gx5, gy5 = -200, 200
remote.call("fo-ia3k", "death", "player", gx5, gy5 - 5)
remote.call("fo-ia3k", "death", "player", gx5 - 5, gy5)
remote.call("fo-ia3k", "mark", "player", gx5 + 3, gy5 + 3, "worm", 25) -- le but est À PORTÉE d'un ver connu
local steps5 = { { "home" }, { "goto", { x = gx5, y = gy5 }, 3 }, { "act", "fortify" }, { "home" } }
local ref5 = 0
for i = 1, 10 do
  if not C.gate(f, ag, { key = "test:refill5", kind = "refill" }, steps5, game.tick + i) then ref5 = ref5 + 1 end
end
check(ref5 == 10, "D-B : but à portée d'une menace FIXE connue : la défense n'y va pas, tâche mise de côté (" .. ref5 .. " sur 10)")
remote.call("fo-ia3k", "forget", "player")
-- Lot DANGER-ACTIF (DC 4/11, 19 h 12 : « ... ou en défendant ») : un bâtiment de l'équipe touché par une force adverse (crochet Rep.on_attack, posé par
-- script/ai3/soldats.lua) alerte les soldats TOUT DE SUITE, sans ouvrier sur place ; un PNJ à moins de Da.SITE_R de l'alerte est « sur le site attaqué »
-- (Re.SITE_RATIO : l'ouvrier armé se défend), un autre non.
do
  local Rep = require("script.team.reparation")
  local Dax = require("shared.team.danger_actif")
  local s_sold, s_n = f.soldiers, f.soldiers_count
  f.soldiers, f.soldiers_count = f.soldiers or {}, 2
  local tm = C.team(f)
  local n0 = (tm.stats.dact or {}).site_alerts or 0
  local pos = { x = f.hq_pos.x + 40, y = f.hq_pos.y }
  check(type(Rep.on_attack) == "function", "DANGER-ACTIF : crochet d'alerte posé sur le bâtiment touché")
  Rep.on_attack(f, pos, game.tick)
  check(((tm.stats.dact or {}).site_alerts or 0) == n0 + 1 and #(tm.alerts or {}) >= 1, "DANGER-ACTIF : bâtiment touché : alerte des soldats tout de suite (sans ouvrier sur place)")
  -- Lead 19 h 40 : l'alerte vaut pour tout site de l'équipe, quelle que soit sa distance au QG (avant : refusée au-delà de 226 tuiles), et se compte à part.
  local far0 = (tm.stats.dact or {}).site_alerts_far or 0
  local far = { x = f.hq_pos.x + 500, y = f.hq_pos.y }
  Rep.on_attack(f, far, game.tick + 600)
  check(((tm.stats.dact or {}).site_alerts_far or 0) == far0 + 1 and ((tm.stats.dact or {}).site_alerts or 0) == n0 + 2,
    "DANGER-ACTIF : site à 500 tuiles du QG : alerte des soldats, comptée « au-delà de 226 tuiles »")
  check(C.on_alert(f, { x = f.hq_pos.x + 600, y = f.hq_pos.y }, "unit", game.tick + 1200) == false, "alerte d'un PNJ en fuite : toujours limitée à 226 tuiles du QG (inchangé)")
  check(Dax.site_alert(tm.alerts, { x = pos.x + 10, y = pos.y }, game.tick) == true and Dax.site_alert(tm.alerts, { x = pos.x + 80, y = pos.y }, game.tick) == false,
    "DANGER-ACTIF : un PNJ à 10 tuiles du site attaqué est « sur le site » (il se défend), un PNJ à 80 tuiles non")
  f.soldiers, f.soldiers_count = s_sold, s_n
end
-- Lot DANGER-ACTIF (DC 4/11, 19 h 25) : mise à l'abri. Menace à 30 tuiles du QG (à portée de ses tourelles) : le ralliement ne prend QUE l'ouvrier exposé (à 15 tuiles
-- de la menace) ; celui qui est à 130 tuiles d'elle (100 du QG) continue son travail, et il est compté « épargné ».
do
  local SDm = require("script.ai3.soldats")
  local tm = C.team(f)
  local hq = f.hq_pos
  local near, away = Registry.get(ids[1]), Registry.get(ids[2])
  near.task, away.task = { key = "test:abri-a", kind = "service" }, { key = "test:abri-b", kind = "service" }
  near.entity.teleport({ x = hq.x + 45, y = hq.y })
  away.entity.teleport({ x = hq.x - 100, y = hq.y })
  local tt = game.tick + 100000
  local sp0 = (tm.stats.dact or {}).spared or 0
  SDm.shelter(f, tm, { x = hq.x + 30, y = hq.y }, tt, "rally", { x = hq.x, y = hq.y + 10 }, 30)
  check(C.astate(near).shelter_t == tt, "DANGER-ACTIF : l'ouvrier exposé (15 tuiles de la menace) est rallié")
  check(C.astate(away).shelter_t ~= tt and ((tm.stats.dact or {}).spared or 0) >= sp0 + 1, "DANGER-ACTIF : l'ouvrier à 130 tuiles de la menace continue son travail (compté épargné)")
  check(((tm.stats.dact or {}).shelter_n or 0) >= 1 and ((tm.stats.dact or {}).shelter_dmax or 0) <= 62, "DANGER-ACTIF : abris comptés avec leur distance à la menace (jamais au-delà de la portée + marges)")
  check(near.steps and near.steps[2] and near.steps[2][1] == "home" and near.steps[1][1] == "goto", "DANGER-ACTIF : plus d'attente fixe au refuge (aller puis retour)")
end
-- Lot DANGER-ACTIF, 2e essai (5/11 ; verif-guide 271828182, essai 2 : 7 repos de plus de 30 s pendant la vague de 46 min) : une MEUTE marquée à 26 tuiles à
-- l'est de la case du QG couvre le QG (zone 40 tuiles). Avant : tout trajet parti du QG (B1) et la garde du QG étaient mis de côté, il ne restait aucune
-- tâche. Après : sortir à l'opposé part (une ligne de journal), aller vers la meute reste mis de côté, la garde du QG part (défense de la base) ; une mort
-- pendant une tâche ainsi partie est comptée.
do
  remote.call("fo-ia3k", "forget", "player")
  local Dax = require("shared.team.danger_actif")
  local tm = C.team(f)
  local home = f.home_spot or f.hq_pos
  local mx, my = home.x + 26, home.y
  remote.call("fo-ia3k", "mark", "player", mx, my, "pack", 36)
  local tz = game.tick + 1
  ag.entity.teleport({ x = home.x, y = home.y })
  local da0 = tm.stats.dact or {}
  local go0, def0, as0 = da0.rel_go or 0, da0.rel_def or 0, da0.aside or 0
  local logs0 = #W().logs
  local west = { key = "test:meute-ouest", kind = "service" }
  local wsteps = { { "home" }, { "goto", { x = home.x - 70, y = home.y }, 3 }, { "act", "service" }, { "home" } }
  check(C.gate(f, ag, west, wsteps, tz) == true and C.astate(ag).risk == true and west.fail == nil,
    "DANGER-ACTIF 2e essai : meute qui couvre le QG, tâche à l'opposé : le PNJ part (avant : mise de côté, aucune tâche)")
  check((tm.stats.dact.rel_go or 0) == go0 + 1 and C.astate(ag).rel_key == west.key, "DANGER-ACTIF 2e essai : départ compté « danger ajouté », tâche notée sur le PNJ")
  local line = nil
  for i = logs0 + 1, #W().logs do if W().logs[i]:find("[FO-DANGER-ACTIF] player : PNJ " .. ag.id .. " part (sortie de zone)", 1, true) then line = W().logs[i] end end
  check(line ~= nil, "DANGER-ACTIF 2e essai : une ligne de journal par départ (" .. tostring(line) .. ")")
  local east = { key = "test:meute-est", kind = "service" }
  local esteps = { { "home" }, { "goto", { x = home.x + 45, y = home.y }, 3 }, { "act", "service" }, { "home" } }
  check(C.gate(f, ag, east, esteps, tz + 1) == false and east.fail == Dax.ASIDE_FAIL and (tm.stats.dact.aside or 0) == as0 + 1,
    "DANGER-ACTIF 2e essai : tâche VERS la meute (but à 19 tuiles d'elle, le départ à 26) : mise de côté (jamais vers une attaque en cours)")
  check(C.astate(ag).rel_key == nil, "DANGER-ACTIF 2e essai : mise de côté : plus de tâche « danger ajouté » sur le PNJ")
  -- Garde du QG : le PNJ est 8 tuiles plus loin de la meute que la case du QG (le but s'enfonce de 8 tuiles) : seule la défense de la base le laisse partir.
  local gv = Registry.get(ids[3])
  gv.entity.teleport({ x = home.x - 8, y = home.y })
  -- Relecture de revue-danger : la défense de la base n'est exemptée de la meute que pour un PNJ ARMÉ (munitions chargées, M.has_ammo), garde comprise.
  local gammo = gv.entity.get_inventory(defines.inventory.character_ammo)
  gammo.clear()
  gammo.insert({ name = "firearm-magazine", count = 10 })
  local garde = { key = "test:meute-garde", kind = "garrison", post = "hq" }
  local gsteps = { { "goto", { x = home.x, y = home.y }, 6 }, { "wait", 600 }, { "home" } }
  check(C.gate(f, gv, garde, gsteps, tz + 2) == true and garde.fail == nil and (tm.stats.dact.rel_def or 0) == def0 + 1,
    "DANGER-ACTIF 2e essai : garde du QG sous la meute par un PNJ armé : départ (défense de la base, R-QCM-25c (b)), compté")
  local rsteps = { { "home" }, { "goto", { x = home.x + 40, y = home.y }, 6 }, { "act", "refill" }, { "home" } }
  local esc_goal = { key = "test:meute-recharge", kind = "refill", group = "hq" }
  check(C.gate(f, gv, esc_goal, rsteps, tz + 3) == true,
    "DANGER-ACTIF 2e essai : recharge dans la base vers la meute par un PNJ ARMÉ : départ (la défense va à l'attaque qu'elle défend)")
  gammo.clear()
  local rf_d = { key = "test:meute-recharge-desarme", kind = "refill", group = "hq" }
  check(C.gate(f, gv, rf_d, rsteps, tz + 3) == false and rf_d.fail == Dax.ASIDE_FAIL,
    "DANGER-ACTIF 2e essai : la même recharge par un DÉSARMÉ : mise de côté (exempté de l'abri, il partirait en plein raid sans réflexe)")
  local fo_d = { key = "test:meute-pose-desarme", kind = "fortify" }
  check(C.gate(f, gv, fo_d, { { "home" }, { "goto", { x = home.x + 40, y = home.y }, 5 }, { "act", "fortify" }, { "home" } }, tz + 3) == false
    and fo_d.fail == Dax.ASIDE_FAIL, "DANGER-ACTIF 2e essai : pose de tourelles vers la meute par un DÉSARMÉ : mise de côté")
  local gd = { key = "test:meute-garde-desarme", kind = "garrison", post = "hq" }
  check(C.gate(f, gv, gd, gsteps, tz + 3) == false and gd.fail == Dax.ASIDE_FAIL,
    "DANGER-ACTIF 2e essai : garde par un PNJ sans munitions CHARGÉES : mise de côté")
  -- Relecture du lead : chargeurs dans le SAC, arme vide : la place de marché ne donne plus la garde (avant : comptés dans tous les inventaires).
  local Bd = require("script.team.board")
  local gmain = gv.entity.get_inventory(defines.inventory.character_main)
  gmain.insert({ name = "firearm-magazine", count = 20 })
  local np = Bd.market_npc(gv)
  check(gv.entity.get_item_count("firearm-magazine") >= 20 and np.cannot ~= nil and np.cannot.garrison == true and Bd.has_ammo(gv.entity) == false,
    "DANGER-ACTIF 2e essai : chargeurs dans le sac, arme vide : pas de garde à la place de marché (même règle que la porte)")
  local gs = { key = "test:meute-garde-sac", kind = "garrison", post = "hq" }
  check(C.gate(f, gv, gs, gsteps, tz + 3) == false and gs.fail == Dax.ASIDE_FAIL,
    "DANGER-ACTIF 2e essai : chargeurs dans le sac, arme vide, garde sous une meute : mise de côté")
  gmain.remove({ name = "firearm-magazine", count = 20 })
  gammo.insert({ name = "firearm-magazine", count = 10 })
  check(Bd.market_npc(gv).cannot == nil or Bd.market_npc(gv).cannot.garrison ~= true, "DANGER-ACTIF 2e essai : arme chargée : la garde est permise")
  -- (A) seulement pour une MEUTE et seulement DANS la base (zone de PORTE-BASE, M.base_zone : case du QG et marge de 24 tuiles, amas de bâtiments).
  remote.call("fo-ia3k", "forget", "player")
  remote.call("fo-ia3k", "mark", "player", home.x + 10, home.y, "worm", 25)
  gv.entity.teleport({ x = home.x - 30, y = home.y }) -- départ hors de la zone du ver (40 tuiles, zone 29)
  local garde_v = { key = "test:ver-garde", kind = "garrison", post = "hq" }
  check(C.gate(f, gv, garde_v, gsteps, tz + 5) == false and garde_v.fail == Dax.ASIDE_FAIL,
    "DANGER-ACTIF 2e essai : garde du QG sous un VER (menace fixe au but) : mise de côté, la défense de la base ne vaut que pour une meute")
  remote.call("fo-ia3k", "forget", "player")
  local og = { x = home.x + 150, y = home.y - 150 }
  check(remote.call("fo-ia3k", "base", "player", true, og.x, og.y).inside == false, "DANGER-ACTIF 2e essai : (150, -150) du QG : hors de la base")
  remote.call("fo-ia3k", "mark", "player", og.x + 5, og.y, "pack", 30)
  gv.entity.teleport({ x = home.x, y = home.y })
  local rf = { key = "test:meute-hors-base", kind = "refill", group = "a1" }
  check(C.gate(f, gv, rf, { { "home" }, { "goto", og, 6 }, { "act", "refill" }, { "home" } }, tz + 6) == false and rf.fail == Dax.ASIDE_FAIL,
    "DANGER-ACTIF 2e essai : recharge HORS de la base sous une meute : mise de côté (jamais vers une attaque en cours hors de la base)")
  remote.call("fo-ia3k", "forget", "player")
  remote.call("fo-ia3k", "mark", "player", mx, my, "pack", 36)
  gv.entity.teleport({ x = home.x - 8, y = home.y })
  -- Mort pendant une tâche partie ainsi : comptée.
  check(C.gate(f, gv, garde, gsteps, tz + 4) == true, "garde repartie")
  local rd0 = tm.stats.dact.rel_dead or 0
  gv.task = garde
  gv.death_cause, gv.death_pos = "medium-biter/enemy:physical", { x = home.x - 4, y = home.y }
  Registry.remove(ids[3], true)
  check((tm.stats.dact.rel_dead or 0) == rd0 + 1, "DANGER-ACTIF 2e essai : mort pendant une tâche partie par le danger ajouté : comptée")
  local logs1 = #W().logs
  C.gate_report(f, tz + 10 * C.REPORT_EVERY)
  local bil = nil
  for i = logs1 + 1, #W().logs do if W().logs[i]:find("[FO-DANGER-ACTIF] player : bilan", 1, true) then bil = W().logs[i] end end
  check(bil ~= nil and bil:find("departs par le danger ajoute", 1, true) ~= nil and bil:find("tues en route 1", 1, true) ~= nil,
    "DANGER-ACTIF 2e essai : bilan avec les départs par le danger ajouté et les morts en route (" .. tostring(bil and bil:sub(-140)) .. ")")
  remote.call("fo-ia3k", "forget", "player")
end
-- Lot DANGER-ACTIF (reprise) : la règle des morts au but (B2, Da.DEATHS_GOAL) garde l'exemption de COMPAGNONS-ACTIFS (tâche proche aux morts toutes
-- anciennes : on revient agir) sous le garde-fou de FER-MARQUE (Fa.DEATHS_MAX). Ici la porte refuse pour des cases mobiles sur la route (« marque ») et le
-- but a 2 morts anciennes : départ ; à 3 morts anciennes : mise de côté (pas de marche suicide).
do
  local Ac = require("shared.team.actif")
  local Dax = require("shared.team.danger_actif")
  local home = f.home_spot or f.hq_pos
  ag.entity.teleport({ x = home.x, y = home.y })
  local cg = { x = home.x - 5, y = home.y + 120 }
  local csteps = { { "home" }, { "goto", { x = cg.x, y = cg.y }, 3 }, { "act", "service" }, { "home" } }
  remote.call("fo-ia3k", "forget", "player")
  remote.call("fo-ia3k", "death", "player", cg.x, cg.y - 6)
  remote.call("fo-ia3k", "death", "player", cg.x + 4, cg.y - 3)
  for _ = 1, 3 do remote.call("fo-ia3k", "mark", "player", home.x - 2, home.y + 60, "unit", 16) end
  local tc = game.tick + Ac.FEAR_TICKS + 60
  local t2 = { key = "test:calme-2", kind = "service" }
  check(C.gate(f, ag, t2, csteps, tc) == true and t2.fail == nil and C.astate(ag).calm == true,
    "DANGER-ACTIF : 2 morts anciennes au but proche, cases mobiles sur la route : départ au calme (COMPAGNONS-ACTIFS), pas de mise de côté")
  remote.call("fo-ia3k", "death", "player", cg.x - 3, cg.y + 2)
  local t3 = { key = "test:calme-3", kind = "service" }
  check(C.gate(f, ag, t3, csteps, game.tick + Ac.FEAR_TICKS + 60) == false and t3.fail == Dax.ASIDE_FAIL,
    "DANGER-ACTIF : 3 morts anciennes au but (garde-fou de FER-MARQUE) : mise de côté")
  remote.call("fo-ia3k", "forget", "player")
end
-- C5 « change de site » : un minage vers un gisement gardé par un ver va miner une autre tuile du même minerai.
local ip = { x = math.cos(math.pi / 6) * 60, y = math.sin(math.pi / 6) * 60 } -- gisement de fer du moteur simulé
remote.call("fo-ia3k", "mark", "player", ip.x, ip.y, "worm", 25)
local mt = { key = "test:mine", kind = "mine", resource = "iron-ore", radius = 96, target = { x = ip.x, y = ip.y } }
local msteps = { { "home" }, { "goto", { x = ip.x, y = ip.y }, 1.5 }, { "mine", "iron-ore", 10 }, { "home" } }
ag.entity.teleport({ x = 0, y = 10 }) -- le trajet jugé part du coffre (le PNJ a travaillé pendant l'heure simulée)
local mok = C.gate(f, ag, mt, msteps, game.tick)
local ng = msteps[2][2]
check(mok == true and R.dist(ng.x, ng.y, ip.x, ip.y) > 40, string.format("minage reciblé hors de la zone du ver (%.0f, %.0f)", ng.x, ng.y))
-- Lot DANGER-ACTIF (2e essai, reprise du travail laissé par l'agent précédent) : une ESCORTE possible ne contourne pas la mise de côté d'un but sous une menace
-- fixe (B3) ; un minage ainsi mis de côté cherche aussi un autre site (C5 « ou change de site ») au lieu d'attendre la fin de sa pause.
do
  local ef, re = C.escort_free, C.request_escort
  C.escort_free = function() return 4 end
  C.request_escort = function() return true end
  local mt2 = { key = "test:mine-escorte", kind = "mine", resource = "iron-ore", radius = 96, target = { x = ip.x, y = ip.y } }
  local msteps2 = { { "home" }, { "goto", { x = ip.x, y = ip.y }, 1.5 }, { "mine", "iron-ore", 10 }, { "home" } }
  local r0 = C.team(f).stats.retarget or 0
  local ok2 = C.gate(f, ag, mt2, msteps2, game.tick + 1)
  local ng2 = msteps2[2][2]
  check(ok2 == true and R.dist(ng2.x, ng2.y, ip.x, ip.y) > 40 and (C.team(f).stats.retarget or 0) == r0 + 1,
    string.format("DANGER-ACTIF : minage sous un ver, escorte possible : reciblé hors de la zone du ver (%.0f, %.0f), pas mis de côté", ng2.x, ng2.y))
  C.escort_free, C.request_escort = ef, re
end
remote.call("fo-ia3k", "hold", "player", true)
-- Mort réelle d'un PNJ (cause ennemie) : marquée par le crochet du registre.
local d_before = remote.call("fo-ia3k", "status", "player").stats.deaths
local dv = Registry.get(ids[5])
dv.death_cause, dv.death_pos = "small-biter/enemy:physical", { x = 40, y = 90 }
Registry.remove(ids[5], true)
st = remote.call("fo-ia3k", "status", "player")
check(st.stats.deaths == d_before + 1 and st.summary.deaths >= 1, "mort d'un PNJ marquée sur la carte de l'équipe")
check(pcall(M.serialize, global), "global sérialisable (aucune fonction)")
-- Yeux fixes : une menace connue dans le champ du QG (160 tuiles) qui n'y est plus est oubliée ; hors champ, gardée.
remote.call("fo-ia3k", "mark", "player", 40, 40, "worm", 25)
remote.call("fo-ia3k", "mark", "player", 600, 0, "worm", 25)
M.run_ticks(1300)
local near_gone, far_kept = true, false
for _, th in ipairs(remote.call("fo-ia3k", "danger", "player").threats) do
  if R.dist(th.x, th.y, 40, 40) < 3 then near_gone = false end
  if R.dist(th.x, th.y, 600, 0) < 3 then far_kept = true end
end
check(near_gone, "menace disparue dans le champ du QG : oubliée (yeux fixes)")
check(far_kept, "menace hors du champ des yeux fixes : gardée (brouillard)")

---------------------------------------------------------------------------------------------------
section("QG : tourelles débordées en portée (lot CORR-RALLIEMENT)")
-- Partie du DC rejouée (graine 717152950) : des mitrailleurs de faction (portée 20, vitesse 0,11) tuent les mitrailleuses du
-- QG (portée 18) hors de leur portée pendant que les PNJ s'y rallient. Ici : la réponse du QG (script/ai3/soldats.lua, C7) à
-- 5 unités de MÊME vue (30) et de même vitesse, qui ne diffèrent que par leur portée d'ATTAQUE (20 ou 1) ; puis la règle
-- éteinte par l'interrupteur du banc témoin.
-- Prototypes de test et mitrailleuse du QG GARNIE (point 4 de la relecture : une tourelle vide ne protège pas le ralliement), puis
-- une vague de 5 unités à 30 tuiles ; rend les écarts de compteurs de l'équipe (stats ia3k). Sert aussi au mutant du point 5.
local function corr_arena(f, s)
  local P = W().prototypes
  -- La réponse du QG (script/ai3/soldats.lua) lit la vitesse du personnage VANILLA (game.entity_prototypes["character"], 0,15 en
  -- jeu) ; le moteur simulé n'a que « fo-companion » : on lui donne celui du jeu (table du jeu simulé, game.entity_prototypes).
  local EP = game.entity_prototypes
  local cp = EP["character"] or { type = "character", max_health = 250 } -- (une entrée sans vitesse peut déjà exister)
  if cp.running_speed == nil then cp.running_speed = 0.15 end
  EP["character"] = cp
  local sb = P["small-biter"]
  -- Relecture (revue-danger, 18 h 12) : les soldats des factions tirent en boîte à boîte (prototypes/faction.lua) ; « fo-test-17-5 »
  -- (portée 17,5 < 18) déborde quand même la mitrailleuse (± 0,7) : il atteint sa boîte depuis 17,5 + |(0,9 ; 0,9)| = 18,77 en diagonale,
  -- elle n'atteint la sienne (± 0,2) que depuis 18 + 0,28 = 18,28 (Re.gap 0,49). Point (C), 7/11 (MESURÉ en portee-diagonale A : au centre
  -- à centre, la tourelle atteint la BOÎTE de sa cible) : l'ancien soldat de portée 17 (écart 17 − 18 + 0,99 = −0,01) ne la déborde
  -- plus ; la portée passe à 17,5 pour garder l'intention du cas (fo-logs/2026-11-05_EFFONDREMENT/CRITERES.md, point (C)).
  for _, u in ipairs({ { "fo-test-gunner", 20 }, { "fo-test-biter", 1 }, { "fo-test-17-5", 17.5 } }) do
    P[u[1]] = { type = "unit", max_health = 600, speed = 0.11, vision_distance = 30,
      attack_parameters = { range = u[2], range_mode = "bounding-box-to-bounding-box" },
      collision_box = sb.collision_box, collision_mask = sb.collision_mask }
  end
  local hq = f.hq_pos or { x = 5, y = 5 }
  P["gun-turret"].attack_parameters = P["gun-turret"].attack_parameters or { range = 18 }
  local tu = s.create_entity({ name = "gun-turret", position = { x = hq.x + 8, y = hq.y }, force = "player" })
  if tu then tu.insert({ name = "firearm-magazine", count = 10 }) end
  -- `ticks` : durée de la vague (défaut 65 : au moins deux réponses du QG, SD.PERIOD = 30 ticks). `hurt` : les PNJ à moins de
  -- 32 tuiles du QG sont blessés (10 points) au début de la vague et tous les 50 ticks : un PNJ près du QG ne regarde que blessé
  -- (comportement.lua, M.HOME_SAFE ; remarque 9 de la relecture), seul cas où la branche PAR PNJ de M.sense est jouée.
  -- Rend une table d'écarts de compteurs : d.hq_rally, d.outranged…
  local function wave(name, on, prep, ticks, hurt)
    remote.call("fo-ia3k", "debordement", on)
    if prep then prep() end
    local st0 = remote.call("fo-ia3k", "status", "player").stats
    local us = {}
    for k = 0, 4 do
      us[#us + 1] = s.create_entity({ name = name, position = { x = hq.x + 30, y = hq.y - 4 + 2 * k }, force = "enemy" })
    end
    local Reg = require("script.companion.registry")
    local left = ticks or 65
    while left > 0 do
      if hurt then
        for _, id in ipairs(agent_ids(f)) do
          local ag = Reg.get(id)
          local e = ag and ag.entity
          if e and e.valid and (e.position.x - hq.x) ^ 2 + (e.position.y - hq.y) ^ 2 <= 32 * 32 and e.health > 60 then
            e.damage(10, game.forces.enemy)
          end
        end
      end
      local step = math.min(50, left)
      M.run_ticks(step)
      left = left - step
    end
    local st1 = remote.call("fo-ia3k", "status", "player").stats
    for _, u in ipairs(us) do if u and u.valid then u.destroy() end end
    M.run_ticks(5)
    return setmetatable({}, { __index = function(_, k) return (st1[k] or 0) - (st0[k] or 0) end })
  end
  return hq, tu, wave
end

do
  local hq, tu, wave0 = corr_arena(f, s)
  check(tu ~= nil, "mitrailleuse du QG posée et garnie")
  local function wave(name, on, prep)
    local d = wave0(name, on, prep)
    return d.hq_rally, d.hq_away, d.hq_outranged, d.shelter_away, d.away_none
  end
  local r, a, o, sa, an = wave("fo-test-gunner", true)
  check(o > 0 and a > 0 and r == 0, string.format(
    "portée d'attaque 20 contre la mitrailleuse (18) : éloignement, aucun ralliement (rally %d, away %d, débordé %d)", r, a, o))
  check(sa > 0 and an == 0, string.format(
    "éloignement jugé (Re.away_pick) : des PNJ partent, carte sans danger (partis %d, sans direction sûre %d)", sa, an))
  r, a, o = wave("fo-test-biter", true)
  check(o == 0 and r > 0 and a == 0, string.format(
    "même vue (30), portée d'attaque 1 : ralliement inchangé, la vue ne compte pas (rally %d, away %d, débordé %d)", r, a, o))
  r, a, o = wave("fo-test-17-5", true)
  check(o > 0 and a > 0 and r == 0, string.format(
    "portée 17,5 en boîte à boîte (18,77 au centre) contre 18 (18,28 sur sa boîte) : éloignement, profil lu au prototype (rally %d, away %d, débordé %d)", r, a, o))
  r, a, o = wave("fo-test-gunner", false)
  check(o == 0 and r > 0 and a == 0, string.format(
    "règle éteinte (interrupteur du banc témoin) : ralliement comme avant (rally %d, away %d, débordé %d)", r, a, o))
  remote.call("fo-ia3k", "debordement", true)
  -- Point 4 de la relecture : des tourelles VIDES ne protègent plus le point : pas de ralliement, même contre des mordeurs. Le QG
  -- simulé a 4 mitrailleuses garnies en plus de celle du banc : toutes sont vidées, puis regarnies.
  local home = f.home_spot or f.hq_pos
  local emptied = {}
  for _, t in ipairs(s.find_entities_filtered({ position = home, radius = 40, force = "player", type = "ammo-turret" })) do
    local inv = t.get_inventory(defines.inventory.turret_ammo)
    local n = inv.get_item_count("firearm-magazine")
    if n > 0 then inv.remove({ name = "firearm-magazine", count = n }) end
    emptied[#emptied + 1] = { t, n }
  end
  local dv = wave0("fo-test-biter", true)
  check(#emptied >= 2 and dv.hq_rally == 0 and dv.hq_rally_bare > 0 and dv.hq_outranged == 0, string.format(
    "%d mitrailleuses du QG vides : pas de ralliement contre des mordeurs (rally %d, sans tourelle %d, débordé %d)",
    #emptied, dv.hq_rally, dv.hq_rally_bare, dv.hq_outranged))
  for _, it in ipairs(emptied) do if it[2] > 0 then it[1].insert({ name = "firearm-magazine", count = it[2] }) end end
  local dk = wave0("fo-test-biter", true)
  check(dk.hq_rally > 0 and dk.hq_rally_bare == 0, string.format(
    "regarnies : ralliement de nouveau (rally %d, sans tourelle %d)", dk.hq_rally, dk.hq_rally_bare))
  -- Seconde relecture, point B : lecture de l'entité par turret_works (entités FACTICES : le moteur simulé n'a ni laser ni
  -- lance-flammes) ; règle pure : Re.turret_ready (ia3k_reaction_test).
  do
    local Cw = require("script.ai3.comportement")
    local S = defines.entity_status
    local function laser(energy, status) return { type = "electric-turret", name = "fo-test-laser", energy = energy, status = status,
      prototype = { attack_parameters = { ammo_type = { energy_consumption = 800000 } } } } end
    check(Cw.turret_works(laser(900000, S.working)) == true and Cw.turret_works(laser(500000, S.working)) == false,
      "laser : réserve d'un tir lue au prototype (0,8 MJ) : 0,9 oui, 0,5 non")
    check(Cw.turret_works(laser(900000, S.low_power)) == false and Cw.turret_works(laser(900000, S.no_power)) == false
      and Cw.turret_works(laser(900000, S.not_plugged_in_electric_network)) == false, "laser : statut sans courant ou faible : non")
    check(Cw.turret_works({ type = "fluid-turret", name = "fo-test-flamme", fluidbox = { { name = "light-oil", amount = 30 } } }) == true
      and Cw.turret_works({ type = "fluid-turret", name = "fo-test-flamme", fluidbox = {} }) == false,
      "lance-flammes : fluide lu dans la boîte à fluide")
  end
  -- Point 5 de la relecture : la branche PAR PNJ (M.sense, près du QG : t.stats.outranged, qg_pnj_<réponse>), sur 200 ticks
  -- (chaque PNJ au repos regarde au moins une fois). Mutant « outranged forcé à faux dans M.sense » : section suivante.
  M.run_ticks(2400) -- les PNJ partis aux vagues d'avant rentrent
  local dg = wave0("fo-test-gunner", true, nil, 200, true)
  check(dg.outranged > 0 and dg.qg_pnj_rally == 0, string.format(
    "par PNJ, mitrailleurs (20) : débordé %d fois, aucun ralliement (rally %d, away %d, stand %d)",
    dg.outranged, dg.qg_pnj_rally, dg.qg_pnj_away, dg.qg_pnj_stand))
  M.run_ticks(2400)
  local db = wave0("fo-test-biter", true, nil, 200, true)
  check(db.outranged == 0 and db.qg_pnj_rally > 0, string.format(
    "par PNJ, mordeurs (1) : jamais débordé (%d), ralliement (%d)", db.outranged, db.qg_pnj_rally))
  -- Point 3 de la relecture : vers marqués sur la carte de l'équipe dans les 5 directions qui éloignent de l'ennemi (à 44 tuiles
  -- du coffre) : aucune direction sûre, personne ne part (« stand »). Les PNJ partis aux vagues d'avant rentrent d'abord.
  M.run_ticks(2400)
  do
    local D = require("shared.ai3.danger")
    local tm = require("script.ai3.comportement").team(f)
    local saved_threats = {}
    for i, th in ipairs(tm.map.threats) do saved_threats[i] = th end
    local ch = f.home_spot or f.hq_pos
    local blocked = function()
      for _, w in ipairs({ { -44, 0 }, { -31, -31 }, { -31, 31 }, { 0, -44 }, { 0, 44 } }) do
        D.mark_seen(tm.map, ch.x + w[1], ch.y + w[2], "worm", 30, game.tick)
      end
    end
    -- Les PNJ sont ramenés au coffre (à 3 tuiles au plus) : les vers, à 44 tuiles, barrent leurs 5 directions.
    local Reg = require("script.companion.registry")
    for i, id in ipairs(agent_ids(f)) do
      local ag = Reg.get(id)
      if ag and ag.entity.valid then ag.entity.teleport({ x = ch.x + (i % 7) - 3, y = ch.y + math.floor(i / 7) % 7 - 3 }) end
    end
    local r4, a4, o4, sa4, an4 = wave("fo-test-gunner", true, blocked)
    check(a4 > 0 and an4 > 0 and sa4 == 0, string.format(
      "vers dans les 5 directions qui éloignent : personne ne part, on se bat groupés (away %d, partis %d, sans direction sûre %d)",
      a4, sa4, an4))
    -- Seconde relecture (point A, coût) : l'échec est noté par PNJ (a.away_t, SD.SHELTER_TICKS) : la vague dure 2 passages de la
    -- mise à l'abri (65 ticks), chaque PNJ n'est jugé qu'une fois (sans le mémo : une fois par passage).
    local npnj = #agent_ids(f)
    check(an4 <= npnj, string.format("échec noté : au plus un calcul par PNJ en 2 passages (%d pour %d PNJ)", an4, npnj))
    tm.map.threats = saved_threats
  end
  -- Point 2 de la relecture : le refuge d'un désarmé (M.refuge) écarte une tourelle que le groupe déborde (profils lus aux
  -- prototypes : Re.refuge_ok). Mitrailleuse du QG à 18 tuiles de l'ennemi, PNJ entre les deux, une autre à 56 tuiles.
  local C = require("script.ai3.comportement")
  local ep = { x = hq.x + 26, y = hq.y }
  local tu2 = s.create_entity({ name = "gun-turret", position = { x = hq.x - 30, y = hq.y }, force = "player" })
  local saved_turrets = f.turrets
  f.turrets = { [tu.unit_number] = tu, [tu2.unit_number] = tu2 }
  local function foes_of(name)
    local u = s.create_entity({ name = name, position = ep, force = "enemy" })
    local q = C.foe_profiles({ u })
    u.destroy()
    return q
  end
  local p0 = { x = hq.x + 15, y = hq.y }
  local behind = C.refuge(f, p0, ep, nil, nil)
  local with17 = C.refuge(f, p0, ep, nil, foes_of("fo-test-17-5"))
  local with_biter = C.refuge(f, p0, ep, nil, foes_of("fo-test-biter"))
  local home = f.home_spot or f.hq_pos
  local hx, hy = home.x - tu.position.x, home.y - tu.position.y
  local hl = math.sqrt(hx * hx + hy * hy)
  local bx, by = tu.position.x + 3 * hx / hl, tu.position.y + 3 * hy / hl -- 3 tuiles derrière la tourelle, côté QG
  local near_tu = function(q) return q and math.abs(q.x - bx) < 0.5 and math.abs(q.y - by) < 0.5 end
  check(near_tu(behind) and near_tu(with_biter), "refuge : 3 tuiles derrière la mitrailleuse du QG (sans profil, ou mordeur)")
  check(with17 and not near_tu(with17), string.format(
    "refuge : la mitrailleuse débordée (portée 17,5 en boîte à boîte, à 18 tuiles) est écartée (refuge %.1f, %.1f)",
    with17 and with17.x or 0, with17 and with17.y or 0))
  -- Seconde relecture, point E : sans tourelle, le QG menacé, le repli du refuge passe par Re.away_pick (et non plus 24 tuiles
  -- en ligne droite) ; aucune direction sûre : pas de refuge (nil, "stand") ; règle éteinte : la ligne droite d'avant.
  do
    local Dm = require("shared.ai3.danger")
    local tm = C.team(f)
    local saved_threats = {}
    for i, th in ipairs(tm.map.threats) do saved_threats[i] = th end
    f.turrets = {}
    local hm = f.home_spot or f.hq_pos
    local pe, ee = { x = hm.x + 3, y = hm.y }, { x = hm.x + 13, y = hm.y }
    local q1 = C.refuge(f, pe, ee, nil, nil, game.tick)
    check(q1 ~= nil and q1.x < pe.x - 30, string.format("sans tourelle, QG menacé : éloignement jugé (%.1f tuiles à l'ouest)",
      q1 and pe.x - q1.x or -1))
    for _, w in ipairs({ { -44, 0 }, { -31, -31 }, { -31, 31 }, { 0, -44 }, { 0, 44 } }) do
      Dm.mark_seen(tm.map, pe.x + w[1], pe.y + w[2], "worm", 30, game.tick)
    end
    local q2, why2 = C.refuge(f, pe, ee, nil, nil, game.tick)
    check(q2 == nil and why2 == "stand", "vers dans les 5 directions : pas de refuge (stand), pas de ligne droite sur eux")
    remote.call("fo-ia3k", "debordement", false)
    local q3 = C.refuge(f, pe, ee, nil, nil, game.tick)
    remote.call("fo-ia3k", "debordement", true)
    check(q3 ~= nil and math.abs(q3.x - (pe.x - 24)) < 1e-6, "règle éteinte : 24 tuiles à l'opposé, comme avant")
    tm.map.threats = saved_threats
  end
  f.turrets = saved_turrets
  if tu2 and tu2.valid then tu2.destroy() end
  if tu and tu.valid then tu.destroy() end
end

---------------------------------------------------------------------------------------------------
section("Mutant : « outranged forcé à faux dans M.sense » (lot CORR-RALLIEMENT, point 5)")
-- script/ai3/comportement.lua relu, la ligne de M.sense « outranged = verdict ~= "couvert" » remplacée par « outranged = false »,
-- le module chargé à sa place (package.preload) dans une partie neuve ; la vague de mitrailleurs doit alors montrer un ralliement
-- par PNJ et aucun débordement : le contrôle « par PNJ » de la section précédente le refuse.
do
  local fh = assert(io.open("script/ai3/comportement.lua", "rb"))
  local src = fh:read("*a")
  fh:close()
  local old = 'outranged = verdict ~= "couvert"'
  local a, b = src:find(old, 1, true)
  check(a ~= nil and src:find(old, b + 1, true) == nil, "mutant : motif unique dans comportement.lua (M.sense)")
  if a then
    local msrc = src:sub(1, a - 1) .. "outranged = false" .. src:sub(b + 1)
    package.preload["script.ai3.comportement"] = function() return assert(load(msrc, "=comportement-mutant", "t"))() end
    local fm = setup()
    local _, tum, wavem = corr_arena(fm, game.surfaces[1])
    local dm = wavem("fo-test-gunner", true, nil, 200, true)
    package.preload["script.ai3.comportement"] = nil
    local refused = not (dm.outranged > 0 and dm.qg_pnj_rally == 0)
    check(refused and dm.qg_pnj_rally > 0 and dm.hq_outranged > 0, string.format(
      "mutant refusé : par PNJ, débordé %d, ralliement %d (la réponse de l'équipe, hors M.sense, déborde encore : %d)",
      dm.outranged, dm.qg_pnj_rally, dm.hq_outranged))
    if tum and tum.valid then tum.destroy() end
  end
end

---------------------------------------------------------------------------------------------------
section("Tenue de l'éloignement : QG débordé, personne n'y rentre (lot CORR-RALLIEMENT, 7/11)")
-- RAPPORT EFFONDREMENT §12 : arrivés au point d'éloignement, les PNJ RENTRAIENT au QG débordé (étape « home » de la marche, « rentrer au QG »
-- du PNJ sans tâche, retour « faute de mieux » de M.leg) et mouraient sur leurs cases. Critères écrits AVANT : CRITERES.md (EFFONDREMENT),
-- « TENUE de l'éloignement ». T1 : un PNJ sorti de portée n'y revient pas pendant la vague ; T2 : retour repris au plus TENUE_N ticks après
-- la vague ; T3 : dépôt dans une annexe hors de portée, sinon attente ; T4 : la même règle pour un ouvrier de faction. Mutants : section suivante.
local Da = require("shared.team.danger_actif")
-- Critère T2 (CRITERES.md EFFONDREMENT, « TENUE », borne corrigée le 7/11 avec l'accord du lead : 660 écrit d'abord oubliait une pensée) :
-- SD.SHELTER_TICKS + 2 x fo-companion-brain-period (l'état meurt, la pensée « idle » donne l'étape home, la pensée « step » la lance), LUS dans le code.
local TENUE_N = require("script.ai3.soldats").SHELTER_TICKS + 2 * require("script.core.config").get("brain_period")
local TENUE_WAVE = 3000
--- Joue la tenue sur une partie neuve (vague de mitrailleurs de portée 20 à 30 tuiles du QG, annexe hors de portée). Rend les mesures.
--- Durée de la vague (TENUE_WAVE) : une marche d'éloignement (le point est à une centaine de tuiles de la menace dans ce moteur simulé) PLUS le
--- retour à pied d'un PNJ qui rentrerait (sans quoi les mutants n'auraient pas le temps de revenir à portée et ne seraient pas jugés).
local function tenue_run()
  local ft = setup()
  local st = game.surfaces[1]
  local Cm = require("script.ai3.comportement")
  local Reg = require("script.companion.registry")
  local hq = ft.hq_pos
  local home = ft.home_spot or hq
  local P = W().prototypes
  local EP = game.entity_prototypes
  local cp = EP["character"] or { type = "character", max_health = 250 }
  if cp.running_speed == nil then cp.running_speed = 0.15 end
  EP["character"] = cp
  local sb = P["small-biter"]
  P["fo-test-gunner"] = { type = "unit", max_health = 600, speed = 0.11, vision_distance = 30,
    attack_parameters = { range = 20, range_mode = "bounding-box-to-bounding-box" }, collision_box = sb.collision_box, collision_mask = sb.collision_mask }
  P["gun-turret"].attack_parameters = P["gun-turret"].attack_parameters or { range = 18 }
  local tu = st.create_entity({ name = "gun-turret", position = { x = hq.x + 8, y = hq.y }, force = "player" })
  if tu then tu.insert({ name = "firearm-magazine", count = 10 }) end
  remote.call("fo-ia3k", "debordement", true)
  local out = { back_in = 0, left = 0 }
  local us = {}
  for k = 0, 4 do us[#us + 1] = st.create_entity({ name = "fo-test-gunner", position = { x = hq.x + 30, y = hq.y - 4 + 2 * k }, force = "enemy" }) end
  local th = { x = hq.x + 30, y = hq.y }
  -- Portée de la mise à l'abri, lue comme le code (soldats.lua : Re.away_distance de la portée rendue par C.classify) : T1 juge le retour à portée
  -- avec la MÊME portée que celle qui déclenche les marches.
  local _, rng = Cm.classify(us[1])
  local reach = require("shared.ai3.reaction").away_distance(rng)
  out.reach = reach
  -- T3 : un PNJ à l'ouest, chargé, qui doit déposer pendant « away » ; annexe hors de portée (à 100 tuiles de la menace).
  local carrier = agent_ids(ft)[1]
  local annex = st.create_entity({ name = "iron-chest", position = { x = hq.x - 70, y = hq.y }, force = "player" })
  ft.annex = { annex }
  local out_of_reach = {} -- [id] = vrai dès qu'il a été vu hors de portée (fin de sa marche) : T1 compte ensuite tout retour à portée
  local t = 0
  while t < TENUE_WAVE do
    M.run_ticks(10)
    t = t + 10
    if t == 300 then
      local ag = Reg.get(carrier)
      if ag and ag.entity.valid then
        ag.entity.teleport({ x = hq.x - 60, y = hq.y })
        ag.entity.get_inventory(defines.inventory.character_main).insert({ name = "iron-ore", count = 30 })
        out.trip = remote.call("fo-ia3k", "trip", "player", carrier, hq.x - 62, hq.y, 30, nil, nil, "mine")
      end
    end
    for _, id in ipairs(agent_ids(ft)) do
      local ag = Reg.get(id)
      local e = ag and ag.entity
      if e and e.valid and not (ag.task and Da.DEFENSE_KINDS[ag.task.kind]) then
        local exp = Da.exposed(e.position, th, reach)
        if not exp and not out_of_reach[id] then out_of_reach[id], out.left = true, out.left + 1 end
        if exp and out_of_reach[id] then out.back_in = out.back_in + 1 end
      end
    end
  end
  out.away_set = remote.call("fo-ia3k", "status", "player").stats.away_set or 0
  out.annex_ore = annex.valid and annex.get_item_count("iron-ore") or -1
  local agc = Reg.get(carrier)
  out.carrier_ore = agc and agc.entity.valid and agc.entity.get_inventory(defines.inventory.character_main).get_item_count("iron-ore") or -1
  -- T2 : la vague part au tick t0 ; relevé à chaque tick du premier tick où chaque PNJ a repris son retour (but = une case du QG, ou au QG).
  for _, u in ipairs(us) do if u and u.valid then u.destroy() end end
  local t0 = game.tick
  local ring = 0
  for _, o in ipairs(require("shared.team.scale").HOME_SLOTS) do ring = math.max(ring, math.sqrt(o[1] * o[1] + o[2] * o[2])) end
  local function in_ring(q) return q ~= nil and (q.x - home.x) ^ 2 + (q.y - home.y) ^ 2 <= (ring + 0.01) ^ 2 end
  local resumed, ids = {}, agent_ids(ft)
  for _ = 1, TENUE_N + 600 do
    M.run_ticks(1)
    for _, id in ipairs(ids) do
      local ag = Reg.get(id)
      if not resumed[id] and ag and ag.entity.valid and (in_ring(ag.entity.position) or in_ring(Cm.astate(ag).final)) then
        resumed[id] = game.tick - t0
      end
    end
    if game.tick - t0 == 300 then
      out.waiting_300 = 0
      for _, id in ipairs(ids) do if not resumed[id] then out.waiting_300 = out.waiting_300 + 1 end end
    end
  end
  out.worst, out.missing = 0, 0
  for _, id in ipairs(ids) do
    if resumed[id] then out.worst = math.max(out.worst, resumed[id]) else out.missing = out.missing + 1 end
  end
  out.n = #ids
  if tu and tu.valid then tu.destroy() end
  if annex.valid then annex.destroy() end
  return out
end

do
  local r = tenue_run()
  check(r.away_set > 0, string.format("état « away » posé par la réponse du QG (%d décisions)", r.away_set))
  check(r.left > 0 and r.back_in == 0, string.format(
    "T1 : %d PNJ sortis de portée, aucun n'y revient pendant la vague (%d relevés de retour à portée)", r.left, r.back_in))
  check(r.annex_ore >= 30 and r.carrier_ore == 0, string.format(
    "T3 : le PNJ chargé dépose dans l'annexe hors de portée (annexe %d minerai, sac %d), sans rentrer", r.annex_ore, r.carrier_ore))
  check((r.waiting_300 or 0) > 0, string.format("T2 : 300 ticks après la vague, l'état vit encore : %d PNJ toujours au loin", r.waiting_300 or 0))
  check(r.missing == 0 and r.worst <= TENUE_N, string.format(
    "T2 : chaque PNJ a repris son retour au plus %d ticks après la vague (le plus tard : %d ticks, jamais : %d sur %d)", TENUE_N, r.worst, r.missing, r.n))
end

-- T3 sans coffre sûr et T4 (faction) : état « away » posé à la main dans la MÊME table que hq_threat (M.team(f).away), menace à 20 tuiles du QG
-- (le coffre du QG exposé, aucune annexe) ; un ouvrier chargé à 70 tuiles à l'ouest doit déposer : il attend ; un ouvrier sans tâche au loin ne
-- rentre pas ; l'état retiré, les deux rentrent et le minerai est déposé.
local function hold_case(ff, key, chk)
  chk = chk or check
  local res = {}
  local Cm = require("script.ai3.comportement")
  local Reg = require("script.companion.registry")
  local Wk = require("script.team.worker")
  local hq = ff.hq_pos
  local ids = agent_ids(ff)
  chk(#ids >= 2, key .. " : au moins deux ouvriers")
  remote.call("fo-ia3k", "hold", key, true)
  ff.annex = {}
  local a1, a2 = Reg.get(ids[1]), Reg.get(ids[2])
  for _, ag in ipairs({ a1, a2 }) do if ag.task then Wk.abort(ag, ff, game.tick, "banc") end end
  local tm = Cm.team(ff)
  tm.away = { x = hq.x + 20, y = hq.y, reach = 52, ["until"] = game.tick + 100000 }
  a1.entity.teleport({ x = hq.x - 70, y = hq.y })
  a2.entity.teleport({ x = hq.x - 70, y = hq.y + 6 })
  local inv1 = a1.entity.get_inventory(defines.inventory.character_main)
  local ore0 = inv1.get_item_count("iron-ore")
  inv1.insert({ name = "iron-ore", count = 20 })
  -- Relecture revue-0659 : le PNJ sans tâche porte aussi quelque chose. À sac vide, le « home » qu'il recevrait sans (b) serait sauté par
  -- (a) et il resterait libre : le mutant (b) ne se verrait plus ; chargé, il attendrait à ce « home » (c) et ne serait plus libre.
  if key == "player" then a2.entity.get_inventory(defines.inventory.character_main).insert({ name = "copper-ore", count = 5 }) end
  local del0 = (ff.team and ff.team.delivered and ff.team.delivered["iron-ore"]) or 0
  -- Étape « home » donnée directement (une faction redonne une tâche à un ouvrier libre : la tournée du banc serait refusée).
  a1.task, a1.steps, a1.pc, a1.failed = nil, { { "home" } }, 1, nil
  require("script.core.fsm").set(Cm.MACHINE, a1, "step", game.tick)
  local trip = true
  M.run_ticks(900)
  local p1, p2 = a1.entity.position, a2.entity.position
  local ore1 = inv1.get_item_count("iron-ore")
  local del1 = (ff.team and ff.team.delivered and ff.team.delivered["iron-ore"]) or 0
  -- (un travail de fond peut AJOUTER du minerai au sac pendant l'attente : on juge « rien déposé », pas un compte exact)
  chk(trip and ore1 >= ore0 + 20 and del1 == del0 and p1.x < hq.x - 60, string.format(
    "%s : chargé, sans coffre hors de portée : rien déposé, il reste au loin (attente bornée, puis sac gardé ; minerai %d, au moins %d ; livré %d -> %d ; à %.0f tuiles du QG)", key, ore1,
    ore0 + 20, del0, del1, hq.x - p1.x))
  if key == "player" then -- une faction redonne une tâche à son ouvrier libre : le cas « sans tâche » n'existe que chez votre équipe retenue
    chk(p2.x < hq.x - 60, string.format("%s : sans tâche, au loin, il ne rentre pas pendant « away » (à %.0f tuiles du QG)", key, hq.x - p2.x))
    -- (b) : il reste LIBRE (prêt à prendre une tâche), et non arrêté sur une étape « home » en attente (que (1) tiendrait aussi au loin).
    local stp = a2.steps and a2.steps[a2.pc]
    res.free = a2.state == "idle" and not (stp and stp[1] == "home")
    chk(res.free, string.format("%s : sans tâche, il reste libre pour une tâche (état %s, étape %s)", key, tostring(a2.state), tostring(stp and stp[1])))
  end
  tm.away = nil
  -- Plus courte distance au QG pendant le retour (une faction renvoie ensuite son ouvrier au travail).
  local d1, d2v = 1e9, 1e9
  for _ = 1, (TENUE_N + 1200) / 30 do
    M.run_ticks(30)
    local q1, q2 = a1.entity.position, a2.entity.position
    d1 = math.min(d1, math.sqrt((q1.x - hq.x) ^ 2 + (q1.y - hq.y) ^ 2))
    d2v = math.min(d2v, math.sqrt((q2.x - hq.x) ^ 2 + (q2.y - hq.y) ^ 2))
  end
  if key ~= "player" then d2v = 0 end -- (ouvrier de faction au travail : seul l'ouvrier chargé est jugé)
  local del2 = (ff.team and ff.team.delivered and ff.team.delivered["iron-ore"]) or 0
  chk(d1 < 15 and d2v < 15 and del2 >= del1 + 20, string.format(
    "%s : « away » fini, les deux rentrent et le minerai est déposé (au plus près : %.0f et %.0f tuiles du QG ; livré %d -> %d)", key, d1, d2v, del1, del2))
  return res
end

do
  local fp = setup()
  hold_case(fp, "player")
  -- T4 : une faction de la partie /fo-war du moteur simulé (même worker.lua, même comportement.lua).
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  if W().remote["fo-ia3f"] then remote.call("fo-ia3f", "set_fog", false) end
  enemy_search()
  M.command("fo-war", "start 2 0 8 320") -- 2 factions, 0 soldat, 8 ouvriers
  M.run_ticks(600)
  local State = require("script.faction.state")
  local alive = State.alive()
  local fac = alive[1] and State.faction(alive[1])
  check(fac ~= nil and fac.key ~= "player", "faction de la partie /fo-war")
  if fac then hold_case(fac, fac.key) end
end

-- Relecture revue-0659 (7/11) : l'attente « away » sans coffre sûr arrêtait TOUTE l'équipe (presque tout programme commence par « home »).
-- Critères écrits AVANT (CRITERES.md EFFONDREMENT, « TENUE, correction ») : un campeur qui déborde (portée 20) reste CAMP_TICKS à 30 tuiles
-- du QG, sans annexe (aucun coffre sûr) ; l'équipe NON retenue continue ses tâches loin du QG (C1) ; aucun PNJ n'attend plus que la borne
-- (C2) ; aucun PNJ à sac vide n'attend (C3).
local CAMP_TICKS = 36000 -- 10 min (demande de la relecture)
--- Moteur simulé : face à un campeur, l'équipe de 9 PNJ armés y répond « stand » (garnison), pas « away » (diagnostic du 7/11,
--- scratchpad/diag_camper3.lua : 7 PNJ en garnison, 2 au minage). L'état « away » est donc posé directement pour toute la durée, dans la
--- MÊME table que hq_threat (M.team(f).away), comme hold_case : c'est ce que produirait un campeur qui déborde, renouvelé 10 min. Aucun
--- coffre n'est sûr : le coffre du QG est à portée (menace à 20 tuiles, atteinte 52), et il n'y a aucune annexe. L'équipe n'est pas
--- retenue. Au tick 120, chaque PNJ hors défense reçoit { home, goto à 60 tuiles à l'ouest, home }, comme les programmes du tableau
--- qui commencent par « home ». Le premier porte 20 minerais (cas (c)). Avant le correctif, tous restaient au premier « home ».
local function camper_run(ticks)
  local fc = setup()
  local Reg = require("script.companion.registry")
  local Wk = require("script.team.worker")
  local Cm = require("script.ai3.comportement")
  local hq = fc.hq_pos
  remote.call("fo-ia3k", "hold", "player", false) -- l'équipe prend ses tâches (setup la retient)
  fc.annex = {}
  local tm = Cm.team(fc)
  tm.away = { x = hq.x + 20, y = hq.y, reach = 52, ["until"] = game.tick + ticks + 600 }
  local ok0 = 0
  for _, s0 in pairs(fc.team.task_stats or {}) do ok0 = ok0 + (s0.ok or 0) end
  local out = { maxwait = 0, empty_wait = 0, injected = 0, arrived = 0, arr = {} }
  local goal = { x = hq.x - 60, y = hq.y }
  local inj = {}
  local t = 0
  while t < ticks do
    M.run_ticks(10)
    t = t + 10
    if t == 120 then
      local first = true
      for _, id in ipairs(agent_ids(fc)) do
        local ag = Reg.get(id)
        if ag and ag.entity.valid and not (ag.task and Da.DEFENSE_KINDS[ag.task.kind]) then
          if ag.task then Wk.abort(ag, fc, game.tick, "banc") end
          if first then ag.entity.get_inventory(defines.inventory.character_main).insert({ name = "iron-ore", count = 20 }) first = false end
          ag.task, ag.steps, ag.pc, ag.failed = nil, { { "home" }, { "goto", goal, 1.5 }, { "home" } }, 1, nil
          require("script.core.fsm").set(Cm.MACHINE, ag, "step", game.tick)
          inj[#inj + 1] = id
        end
      end
      out.injected = #inj
    end
    for _, id in ipairs(inj) do
      local ag = Reg.get(id)
      local q = ag and ag.entity.valid and ag.entity.position
      if q and not out.arr[id] and (q.x - goal.x) ^ 2 + (q.y - goal.y) ^ 2 <= 3 * 3 then out.arr[id] = true out.arrived = out.arrived + 1 end
    end
    for _, id in ipairs(agent_ids(fc)) do
      local ag = Reg.get(id)
      if ag and ag.entity.valid and ag.away_wait then
        out.maxwait = math.max(out.maxwait, game.tick - ag.away_wait)
        if not Wk._has_deposit(ag) then out.empty_wait = out.empty_wait + 1 end
      end
    end
  end
  local ok1 = 0
  for _, s1 in pairs(fc.team.task_stats or {}) do ok1 = ok1 + (s1.ok or 0) end
  out.done = ok1 - ok0
  out.live = Cm.away_state(fc, game.tick) ~= nil
  out.tenue = fc.team.tenue or {}
  tm.away = nil
  return out
end

do
  local Wk = require("script.team.worker")
  check(Wk.AWAY_WAIT_TICKS == require("script.ai3.soldats").SHELTER_TICKS,
    string.format("borne de l'attente « away » = SD.SHELTER_TICKS (%s = %s)", tostring(Wk.AWAY_WAIT_TICKS), tostring(require("script.ai3.soldats").SHELTER_TICKS)))
  local r = camper_run(CAMP_TICKS)
  local bound = Wk.AWAY_WAIT_TICKS + require("script.core.config").get("brain_period")
  check(r.live, "état « away » vivant pendant les 10 min (posé dans la table de hq_threat)")
  -- C1 (critère corrigé, CRITERES.md : « du minerai miné » était impossible dans ce moteur simulé, qui ne réussit aucun minage à la main) :
  -- tous les programmes injectés qui commencent par « home » arrivent au loin pendant le campeur.
  check(r.injected >= 2 and r.arrived == r.injected, string.format(
    "C1 : sans coffre sûr, l'équipe continue ses tâches loin du QG (%d programmes « home, goto, home » injectés, %d arrivés à 60 tuiles ; %d tâches du tableau finies, lu)",
    r.injected, r.arrived, r.done))
  check(r.maxwait <= bound, string.format("C2 : aucun PNJ n'attend plus que la borne (le plus long : %d ticks, borne %d)", r.maxwait, bound))
  check(r.empty_wait == 0, string.format("C3 : aucun PNJ à sac vide en attente (%d relevés)", r.empty_wait))
  print(string.format("  (tenue, journal : %d « home » sautés, %d sacs gardés après la borne, %d tâches abandonnées « away »)",
    r.tenue.skip or 0, r.tenue.kept or 0, r.tenue.abort or 0))
end

---------------------------------------------------------------------------------------------------
section("Mutants de la tenue (chacun refusé)")
-- Source relue, un motif remplacé, le module chargé à sa place (package.preload) dans une partie neuve.
local function tenue_mutant(path, modname, old, new, runner)
  local fh = assert(io.open(path, "rb"))
  local src = fh:read("*a")
  fh:close()
  local a, b = src:find(old, 1, true)
  if not (a and src:find(old, b + 1, true) == nil) then return nil end
  local msrc = src:sub(1, a - 1) .. new .. src:sub(b + 1)
  package.preload[modname] = function() return assert(load(msrc, "=" .. modname .. "-mutant", "t"))() end
  local ok, r = pcall(runner or tenue_run)
  package.preload[modname] = nil
  if not ok then print("  (mutant : erreur " .. tostring(r) .. ")") return { crashed = true } end
  return r
end
do
  local m1 = tenue_mutant("script/ai3/soldats.lua", "script.ai3.soldats", 'if resp == "away" and C.outrange_on() then', "if false then")
  check(m1 ~= nil and (m1.crashed or m1.back_in > 0), string.format(
    "mutant « sans tenue » (état jamais posé) refusé : des PNJ reviennent à portée (%s relevés)", m1 and tostring(m1.back_in) or "motif absent"))
  local m2 = tenue_mutant("script/team/worker.lua", "script.team.worker", 'local away = kind == "home" and away_state(f, tick) or nil', "local away = nil")
  check(m2 ~= nil and (m2.crashed or m2.back_in > 0 or m2.annex_ore < 30), string.format(
    "mutant « dépôt sans tenue » (étape home ignore « away ») refusé (retours à portée %s, annexe %s)",
    m2 and tostring(m2.back_in) or "?", m2 and tostring(m2.annex_ore) or "motif absent"))
  -- (b) : le PNJ sans tâche qui « rentre » pendant « away » est tenu au loin par (1), mais il n'est plus LIBRE (étape home en attente).
  do
    local fh = assert(io.open("script/team/worker.lua", "rb"))
    local src = fh:read("*a")
    fh:close()
    local old = "and not agent.nav and not away_state(f, tick) then"
    local a, b = src:find(old, 1, true)
    local res3
    if a and src:find(old, b + 1, true) == nil then
      local msrc = src:sub(1, a - 1) .. "and not agent.nav then" .. src:sub(b + 1)
      package.preload["script.team.worker"] = function() return assert(load(msrc, "=worker-mutant", "t"))() end
      local ok, r = pcall(function() local fm = setup() return hold_case(fm, "player", function() end) end)
      package.preload["script.team.worker"] = nil
      res3 = ok and r or { crashed = true }
    end
    check(res3 ~= nil and (res3.crashed or res3.free == false), string.format(
      "mutant « sans tâche rentre » (b) refusé : le PNJ n'est plus libre (libre : %s)", res3 and tostring(res3.free) or "motif absent"))
  end
  -- T2 : un retour qui reprend une pensée trop tard (état prolongé d'une période du cerveau), ou jamais (état sans fin) : T2 rouge.
  local m4 = tenue_mutant("script/ai3/soldats.lua", "script.ai3.soldats", '["until"] = tick + SD.SHELTER_TICKS }', '["until"] = tick + SD.SHELTER_TICKS + 60 }')
  check(m4 ~= nil and (m4.crashed or m4.missing > 0 or m4.worst > TENUE_N), string.format(
    "mutant « retour à la 3e pensée » refusé par T2 (le plus tard %s ticks, borne %d)", m4 and tostring(m4.worst) or "motif absent", TENUE_N))
  local m5 = tenue_mutant("shared/team/danger_actif.lua", "shared.team.danger_actif", 'return w ~= nil and tick < (w["until"] or -1)', "return w ~= nil")
  check(m5 ~= nil and (m5.crashed or m5.missing > 0 or m5.worst > TENUE_N), string.format(
    "mutant « état sans fin » refusé par T2 (jamais repris : %s)", m5 and tostring(m5.missing) or "motif absent"))
  -- Relecture revue-0659 : la borne de l'attente et le saut du « home » à sac vide (campeur court : 3 000 ticks suffisent à les voir).
  local cbound = require("script.team.worker").AWAY_WAIT_TICKS + require("script.core.config").get("brain_period")
  local m6 = tenue_mutant("script/team/worker.lua", "script.team.worker", "if tick - agent.away_wait < Worker.AWAY_WAIT_TICKS then return end",
    "do return end", function() return camper_run(3000) end)
  check(m6 ~= nil and (m6.crashed or m6.maxwait > cbound), string.format(
    "mutant « borne ignorée » refusé par C2 (attente la plus longue %s ticks, borne %d)", m6 and tostring(m6.maxwait) or "motif absent", cbound))
  local m7 = tenue_mutant("script/team/worker.lua", "script.team.worker", "local carry = has_deposit(agent)", "local carry = true",
    function() return camper_run(3000) end)
  check(m7 ~= nil and (m7.crashed or m7.empty_wait > 0), string.format(
    "mutant « home de début non sauté » refusé par C3 (%s relevés de PNJ à sac vide en attente)", m7 and tostring(m7.empty_wait) or "motif absent"))
end

---------------------------------------------------------------------------------------------------
section("Réglage éteint : aucun effet")
local f2 = setup({ ia3k = false })
local ids2 = agent_ids(f2)
s = game.surfaces[1]
s.create_entity({ name = "small-worm-turret", position = { x = 165, y = 5 }, force = "enemy" })
local pts3 = play_trip(ids2[1], 325, 5, 9000)
st = remote.call("fo-ia3k", "status", "player")
check(st.enabled == false and st.stats.looks == 0 and st.stats.plans == 0, "aucun regard, aucun itinéraire")
check(min_d(pts3, 165, 5) < 5, "sans le lot, le PNJ passe sur le ver (témoin : " .. string.format("%.1f", min_d(pts3, 165, 5)) .. ")")

---------------------------------------------------------------------------------------------------
section("Déterminisme : deux passages identiques")
local function run_once()
  local ff = setup()
  local ii = agent_ids(ff)
  game.surfaces[1].create_entity({ name = "small-worm-turret", position = { x = 165, y = 5 }, force = "enemy" })
  local out = {}
  for k = 1, 3 do
    local p = play_trip(ii[1], 325, 5, 9000)
    out[#out + 1] = string.format("%.3f,%.3f,%d", p[#p].x, p[#p].y, #p)
  end
  return table.concat(out, ";") .. "|" .. M.serialize(global.fo.ia3k.teams)
end
local r1, r2 = run_once(), run_once()
check(r1 == r2, "mêmes trajets et même carte du danger aux deux passages")

print(string.format("[IA3K-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
