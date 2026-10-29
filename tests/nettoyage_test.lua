--[[
  Tests hors jeu du lot NETTOYAGE-SITE (29/10, arbitrage du DC : « Oui, lancer le lot »).
  Usage, depuis la racine du mod :   lua5.2 tests/nettoyage_test.lua

  Vérifie :
    1. règles pures (shared/ai3/nettoyage.lua) : candidats (besoin, échéance, refroidissement, le plus proche d'abord),
       effectif estimé d'après la force du champ, réserve du QG gardée, attente (effectif, trop fort, QG menacé, expédition
       sur le site), re-vérification d'un site hostile sans nid connu, point de rassemblement hors de portée des vers,
       cible la plus proche, phases (rassemblement, attaque, nettoyé, retraite, abandon), priorité sur les expéditions
       lointaines ; mutants de la source refusés ;
    2. moteur simulé (tests/mock_engine.lua, vrai script/ai3/soldats.lua et script/faction/sites.lua) : site proche bloqué par
       2 nids et 1 ver -> attente d'effectif (journal une fois) -> opération préparée avec le surplus seul -> rassemblement ->
       attaque -> nettoyé -> blocage levé, site proche remis en réserve, signal retiré, puisé par Sites.find ; retraite et
       refroidissement ; QG menacé ; re-vérification ; déterminisme (deux parties, mêmes journaux) ;
    3. sources : branchement dans soldats.lua avant Sd.assign, Nt.R = ENEMY_CLEARANCE de sites.lua.
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local function read(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end

local Sd = require("shared.ai3.soldats")

---------------------------------------------------------------------------------------------------
-- 1. Règles pures
---------------------------------------------------------------------------------------------------
local function props(Nt)
  local out = {}
  local function add(c, name) out[#out + 1] = { c and true or false, name } end
  -- Effectif.
  add(Nt.need(2, 1) > Nt.need(1, 1) and Nt.need(1, 2) > Nt.need(1, 1) and Nt.need(0, 0) >= 4 and Nt.need(2, 1) == 10,
    "effectif estimé : croît avec les nids et les vers (2 nids + 1 ver = 10)")
  -- Candidats.
  local blocked = {
    coal = { x = 100, y = 0, why = "hostile", until_tick = 1000, d_blocked = 100, n = 1 },
    ["iron-ore"] = { x = 50, y = 0, why = "hostile", until_tick = 1000, d_blocked = 50, n = 2 },
    stone = { x = 10, y = 0, why = "hostile", until_tick = 10, d_blocked = 10, n = 1 },     -- échu
    ["copper-ore"] = { x = 20, y = 0, why = "hostile", until_tick = 1000, d_blocked = 20, n = 1 }, -- pas demandé
  }
  local needs = { coal = 1, ["iron-ore"] = 1, stone = 1 }
  local c = Nt.candidates(blocked, needs, 500, {})
  add(#c == 2 and c[1].resource == "iron-ore" and c[2].resource == "coal", "candidats : demandés, non échus, le plus proche d'abord")
  local c2 = Nt.candidates(blocked, needs, 500, { { x = 50, y = 0, ["until"] = 600 } })
  add(#c2 == 1 and c2[1].resource == "coal", "refroidissement : site non retenté")
  local c3 = Nt.candidates(blocked, needs, 700, { { x = 50, y = 0, ["until"] = 600 } })
  add(#c3 == 2, "refroidissement fini : site de nouveau candidat")
  -- Décision.
  local function cand(over)
    local t = { resource = "coal", x = 100, y = 0, d = 100, why = "hostile", nests = 2, worms = 1, seen = true }
    for k, v in pairs(over or {}) do t[k] = v end
    return t
  end
  local d = Nt.decide({ cands = { cand() }, home = 20, tick = 0 })
  add(d.action == "lancer" and d.take == 10 and 20 - d.take >= Sd.reserve(20), "20 soldats au QG : 10 engagés, la réserve reste")
  d = Nt.decide({ cands = { cand() }, home = 17, tick = 0 })
  add(d.action == "attendre" and d.reason == "effectif" and Nt.holds(d), "17 soldats (surplus 9 < 10) : on attend, priorité tenue")
  d = Nt.decide({ cands = { cand() }, home = 6, tick = 0 })
  add(d.action == "attendre" and d.reason == "effectif" and d.surplus == 0, "6 soldats : rien d'engageable (réserve de 8)")
  d = Nt.decide({ cands = { cand() }, home = 40, threatened = true, tick = 0 })
  add(d.action == "attendre" and d.reason == "qg-menace" and not Nt.holds(d), "QG menacé : on attend, sans geler les autres missions")
  d = Nt.decide({ cands = { cand({ nests = 10, worms = 5 }) }, home = 200, tick = 0 })
  add(d.action == "attendre" and d.reason == "trop-fort" and not Nt.holds(d), "champ trop fort (34 > 30) : on attend")
  d = Nt.decide({ cands = { cand() }, home = 40, expedition = { x = 110, y = 5 }, tick = 0 })
  add(d.action == "attendre" and d.reason == "expedition-sur-site", "expédition déjà sur le champ du site : on la laisse finir")
  d = Nt.decide({ cands = { cand() }, home = 40, expedition = { x = -200, y = 0 }, tick = 0 })
  add(d.action == "lancer", "expédition ailleurs : l'opération part")
  d = Nt.decide({ cands = { cand() }, home = 40, busy = true, tick = 0 })
  add(d.action == "rien", "opération en cours : aucune autre")
  d = Nt.decide({ cands = { cand({ nests = 0, worms = 0 }) }, home = 40, tick = 0 })
  add(d.action == "reverifier", "hostile sans nid connu, secteur vu : re-vérification")
  d = Nt.decide({ cands = { cand({ nests = 0, worms = 0 }) }, home = 40, tick = 100, checked = { coal = 0 } })
  add(d.action == "rien" and d.notes[1].reason == "reverifie-recemment", "re-vérification au plus une fois par RECHECK")
  d = Nt.decide({ cands = { cand({ nests = 0, worms = 0 }) }, home = 40, tick = Nt.RECHECK, checked = { coal = 0 } })
  add(d.action == "reverifier", "re-vérification de nouveau après RECHECK")
  d = Nt.decide({ cands = { cand({ nests = 0, worms = 0, why = "injoignable" }) }, home = 40, tick = 0 })
  add(d.action == "rien" and d.notes[1].reason == "non-militaire", "injoignable sans nid : pas d'opération")
  d = Nt.decide({ cands = { cand({ nests = 0, worms = 0, seen = false }) }, home = 40, tick = 0 })
  add(d.action == "rien" and d.notes[1].reason == "secteur-non-vu", "secteur jamais vu : pas d'opération")
  d = Nt.decide({ cands = { cand({ resource = "iron-ore", x = 50, d = 50 }), cand() }, home = 40, tick = 0 })
  add(d.action == "lancer" and d.site.resource == "iron-ore", "deux sites bloqués : le plus proche d'abord")
  d = Nt.decide({ cands = { cand({ resource = "iron-ore", x = 50, d = 50, nests = 0, worms = 0, why = "injoignable" }), cand() },
    home = 40, tick = 0 })
  add(d.action == "lancer" and d.site.resource == "coal" and #d.notes == 1, "proche non militaire écarté (noté), le suivant part")
  -- Rassemblement.
  local r = Nt.rally({ x = 0, y = 0 }, { x = 100, y = 0 })
  add(not r.at_hq and math.abs(r.x - 28) < 1e-9 and r.y == 0 and 100 - r.x >= Nt.R + Nt.STANDOFF,
    "rassemblement à R + STANDOFF du site, sur le segment QG -> site")
  r = Nt.rally({ x = 0, y = 0 }, { x = 50, y = 0 })
  add(r.at_hq and r.x == 0, "site à moins de R + STANDOFF du QG : rassemblement au QG")
  r = Nt.rally({ x = 0, y = 0 }, { x = 100, y = 0 }, function(x) return x <= 20 end)
  add(not r.at_hq and math.abs(r.x - 12) < 1e-9, "point non sûr : recul de STEP_BACK vers le QG")
  -- Cible.
  local tg = Nt.next_target({ { x = 10, y = 0 }, { x = 5, y = 5 }, { x = 5, y = -5 } }, { x = 0, y = 0 })
  add(tg and tg.x == 5 and tg.y == -5, "cible : la plus proche, égalité départagée par x puis y")
  add(Nt.next_target({}, { x = 0, y = 0 }) == nil, "aucune cible : nil")
  -- Phases.
  local op = { phase = "rassemble", n0 = 10, t_phase = 0 }
  add(Nt.step(op, { tick = 100, alive = 10, dead = 0, present = 8 }) == "attaque", "8 sur 10 au rassemblement : attaque")
  add(Nt.step(op, { tick = 100, alive = 10, dead = 0, present = 7 }) == "rassemble", "7 sur 10 : on attend les autres")
  add(Nt.step(op, { tick = Nt.GATHER_TICKS, alive = 10, dead = 0, present = 2 }) == "attaque", "rassemblement trop long : attaque")
  add(Nt.step(op, { tick = 100, alive = 4, dead = 6, present = 4 }) == "retraite", "plus de la moitié morte : retraite")
  local op2 = { phase = "attaque", n0 = 10, t_phase = 0 }
  add(Nt.step(op2, { tick = 100, alive = 9, dead = 1, left = 0 }) == "nettoye", "plus aucun ennemi : nettoyé")
  add(Nt.step(op2, { tick = 100, alive = 9, dead = 1, left = 3 }) == "attaque", "ennemis restants : l'attaque continue")
  add(Nt.step(op2, { tick = Nt.ATTACK_TICKS, alive = 9, dead = 1, left = 3 }) == "abandon", "attaque trop longue : abandon")
  add(Nt.step(op2, { tick = 100, alive = 0, dead = 4, left = 3 }) == "retraite", "plus aucun soldat : fin (retraite)")
  -- Priorité.
  local cl = Nt.filter_threats({ { x = 30, y = 0 }, { x = 200, y = 0 }, { x = 110, y = 10 }, { x = 0, y = 90 } }, { x = 0, y = 0 },
    { x = 100, y = 0 })
  add(#cl == 2 and cl[1].x == 30 and cl[2].y == 90, "priorité : expéditions plus lointaines que le site retirées, champ du site aussi")
  local dr = Nt.drop_site({ { x = 30, y = 0 }, { x = 200, y = 0 }, { x = 110, y = 10 } }, { x = 100, y = 0 })
  add(#dr == 2 and dr[1].x == 30 and dr[2].x == 200, "site nettoyé : son champ retiré des menaces, les autres gardés")
  return out
end

section("Règles pures (shared/ai3/nettoyage.lua)")
local Nt = require("shared.ai3.nettoyage")
for _, p in ipairs(props(Nt)) do check(p[1], p[2]) end

section("Mutants de la source")
local SRC = read("shared/ai3/nettoyage.lua")
local MUTANTS = {
  { "réserve du QG vidée", "local surplus = Sd.surplus(home)", "local surplus = home" },
  { "opération suicide", "elseif need > surplus then", "elseif need > surplus + 99 then" },
  { "le plus lointain d'abord", "    if a.d ~= b.d then return a.d < b.d end\n    return a.resource < b.resource",
    "    if a.d ~= b.d then return a.d > b.d end\n    return a.resource < b.resource" },
  { "effectif sans les nids", "Nt.PER_NEST * (nests or 0)", "0" },
  { "rassemblement au pied du site", "local along = d - keep", "local along = d" },
  { "jamais d'abandon", "if tick - (op.t_phase or 0) >= Nt.ATTACK_TICKS then", "if false then" },
  { "jamais de retraite", "Sd.retreat(op.n0, obs.dead or 0) or ", "" },
  { "pas de priorité", "if d2(c, hq) <= ds and d2(c, site) > r * r then", "if true then" },
  { "blocage échu retenu", "(s.until_tick or 0) > tick", "true" },
  { "QG menacé ignoré", "if input.threatened then", "if false then" },
  { "priorité tenue sur un champ trop fort", 'decision.reason == "effectif"', 'decision.reason ~= "qg-menace"' },
  { "attaque sans rassemblement", "(obs.present or 0) * 1000 >= Nt.GATHER_SHARE * obs.alive", "true" },
  { "nettoyé trop tôt", "if obs.left ~= nil and obs.left == 0 then", "if obs.left ~= nil and obs.left <= 3 then" },
  { "champ trop fort accepté", "elseif need > Nt.MAX_NEED then", "elseif false then" },
  { "re-vérification non militaire", 'if c.why == "hostile" and c.seen then', "if true then" },
  { "besoin ignoré", "and ((needs or {})[res] or 0) > 0", "" },
  { "champ nettoyé gardé", "    if d2(c, site) > r * r then out[#out + 1] = c end", "    out[#out + 1] = c" },
}
local caught = 0
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  local once = a ~= nil and SRC:find(m[2], b + 1, true) == nil
  check(once, "mutant « " .. m[1] .. " » : motif trouvé une seule fois dans la source")
  if once then
    local msrc = SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1)
    local chunk = assert(load(msrc, "=nettoyage_mutant", "t", _G))
    local ok, mod = pcall(chunk)
    local killed = not ok
    if ok then
      local ok2, res = pcall(props, mod)
      if not ok2 then killed = true else
        for _, p in ipairs(res) do if not p[1] then killed = true end end
      end
    end
    check(killed, "mutant « " .. m[1] .. " » refusé")
    if killed then caught = caught + 1 end
  end
end
print(string.format("[NETTOYAGE] mutants refusés : %d sur %d", caught, #MUTANTS))

---------------------------------------------------------------------------------------------------
-- 2. Moteur simulé
---------------------------------------------------------------------------------------------------
section("Opération en moteur simulé (soldats.lua, sites.lua)")
local M = require("tests.mock_engine")

local function scenario(opts)
  opts = opts or {}
  M.new_game({ seed = 4242, patches = {}, p_busy = 0, p_nopath = 0, p_lost = 0 })
  M.command("fo-war", "start 2 100 10 320")
  local W = M.world()
  W.prototypes["fo-test-spawner"] = { type = "unit-spawner", max_health = 350 }
  W.prototypes["fo-test-worm"] = { type = "turret", max_health = 200 }
  local war = global.fo.war
  local State = require("script.faction.state")
  local Sites = require("script.faction.sites")
  local K = require("shared.ai3.carte")
  local SD = require("script.ai3.soldats")
  local C = require("script.ai3.comportement")
  local f = war.factions[1]
  local surface = game.surfaces[war.surface]
  local hq = f.hq_pos
  -- Direction QG -> extérieur (loin du centre et de l'autre QG) : site proche à ~70 tuiles, lointain à ~200.
  local L = math.sqrt(hq.x * hq.x + hq.y * hq.y)
  local ux, uy = hq.x / L, hq.y / L
  local function chunk_center(x, y) return { x = math.floor(x / 32) * 32 + 16, y = math.floor(y / 32) * 32 + 16 } end
  local near = chunk_center(hq.x + ux * 80, hq.y + uy * 80)
  local far = chunk_center(hq.x + ux * 220, hq.y + uy * 220)
  W.patches[#W.patches + 1] = { x = near.x, y = near.y, name = "coal", amount = 500000 }
  W.patches[#W.patches + 1] = { x = far.x, y = far.y, name = "coal", amount = 500000 }
  -- Champ ennemi : 2 nids et 1 ver à moins de 48 tuiles du site proche, plus loin du QG que lui.
  local enemies = {}
  local function enemy(name, dx, dy)
    local e = M.new_entity(name, near.x + ux * dx - uy * dy, near.y + uy * dx + ux * dy, surface, "enemy")
    enemies[#enemies + 1] = e
    return e
  end
  enemy("fo-test-spawner", 20, 6)
  enemy("fo-test-spawner", 24, -8)
  enemy("fo-test-worm", 12, 0)
  -- Carte de connaissance : le secteur du site et les secteurs du champ sont VUS (nids et vers connus).
  f.ai3f = f.ai3f or {}
  f.ai3f.m = f.ai3f.m or K.new()
  local km = f.ai3f.m
  local function record_all(tick)
    local by = {}
    local keys = {}
    local function sec(x, y)
      local k = K.key_of(x, y)
      if not by[k] then by[k] = { nests = {}, worms = {} } keys[#keys + 1] = k end
      return by[k]
    end
    sec(near.x, near.y)
    for _, e in ipairs(enemies) do
      if e.valid then
        local s = sec(e.position.x, e.position.y)
        if e.type == "unit-spawner" then s.nests[#s.nests + 1] = { x = e.position.x, y = e.position.y }
        else s.worms[#s.worms + 1] = { x = e.position.x, y = e.position.y } end
      end
    end
    table.sort(keys)
    for _, k in ipairs(keys) do K.record(km, k, tick, by[k]) end
  end
  record_all(0)
  -- Soldats : aucun groupe, au QG.
  f.soldiers = {}
  local soldier_ids = {}
  local function add_soldiers(n)
    for _ = 1, n do
      local u = M.new_entity("fo-test-soldier", hq.x + 3, hq.y + 3, surface, f.force)
      f.soldiers[u.unit_number] = { entity = u, group = nil }
      soldier_ids[#soldier_ids + 1] = u.unit_number
    end
    f.soldiers_count = #soldier_ids
  end
  -- Besoin et signal : le site proche, examiné, est hostile ; le lointain en réserve est alors suspendu.
  local TK = 600000
  f.site_needs = { coal = 1 }
  f.prospects = { { x = far.x, y = far.y, resource = "coal", radius = 6, rich = 10000000, tiles = 60 } }
  f.traits = nil
  Sites.probe_at(f, surface, near.x, near.y, TK)
  Sites.available(f, "coal", TK)
  return { f = f, W = W, war = war, Sites = Sites, SD = SD, C = C, K = K, km = km, State = State, surface = surface, hq = hq,
    near = near, far = far, enemies = enemies, add_soldiers = add_soldiers, soldier_ids = soldier_ids, TK = TK,
    record_all = record_all }
end

local function logs(W, pat)
  local out = {}
  for _, l in ipairs(W.logs) do if l:find(pat, 1, true) then out[#out + 1] = l end end
  return out
end

local function run_full()
  local S = scenario()
  local f, W, TK = S.f, S.W, S.TK
  local sig = f.site_blocked and f.site_blocked.coal
  check(sig and sig.why == "hostile" and sig.n == 1, "signal f.site_blocked.coal posé (proche hostile, lointain suspendu)")
  local t = S.C.team(f)
  -- (a) 6 soldats : attente d'effectif, journal une fois, aucun soldat pris.
  S.add_soldiers(6)
  S.SD.pass(f, TK + 30)
  S.SD.pass(f, TK + 60)
  local w = logs(W, "[FO-NETTOYAGE]")
  check(#logs(W, "attente tick") == 1 and #logs(W, "motif effectif") == 1, "6 soldats : « attente ... motif effectif » écrit une fois")
  check(t.sd.nt == nil, "6 soldats : aucune opération")
  -- (b) 20 soldats : 10 pris (effectif 2 nids + 1 ver), la réserve reste au QG.
  S.add_soldiers(14)
  S.SD.pass(f, TK + 90)
  local op = t.sd.nt
  check(op and op.phase == "rassemble" and #op.ids == 10 and op.need == 10, "20 soldats : opération préparée, 10 soldats pris")
  check(#logs(W, "[FO-NETTOYAGE]") >= 2 and #logs(W, "prepare tick") == 1, "journal « prepare »")
  local flagged, home = 0, 0
  for _, id in ipairs(S.soldier_ids) do
    if f.soldiers[id].ia3k == "clear" then flagged = flagged + 1 end
  end
  local per = t.sd.per
  for _, id in ipairs(S.soldier_ids) do if per[id] and per[id].role ~= "nettoyage-site" then home = home + 1 end end
  check(flagged == 10 and home == 10 and home >= Sd.reserve(20), "10 soldats au rassemblement (drapeau du chef), 10 restent au QG")
  local dsite = math.sqrt((op.rally.x - S.near.x) ^ 2 + (op.rally.y - S.near.y) ^ 2)
  check(dsite >= Nt.R + Nt.STANDOFF - 1 or (op.rally.x == S.hq.x and op.rally.y == S.hq.y), "rassemblement hors de portée des vers")
  local cmd = f.soldiers[op.ids[1]].entity._command
  check(cmd and cmd.type == defines.command.compound and cmd.commands[1].type == defines.command.go_to_location,
    "commande de rassemblement donnée (go_to_location)")
  -- (c) Soldats au rassemblement : attaque, cible = le plus proche (le ver).
  for _, id in ipairs(op.ids) do
    local e = f.soldiers[id].entity
    e._x, e._y = op.rally.x, op.rally.y
  end
  S.SD.pass(f, TK + 120)
  check(t.sd.nt and t.sd.nt.phase == "attaque" and #logs(W, "attaque tick") == 1, "tous au rassemblement : attaque (journal)")
  local c2 = f.soldiers[op.ids[1]].entity._command
  local tgt = c2 and c2.commands and c2.commands[1]
  check(tgt and tgt.type == defines.command.attack_area and math.abs(tgt.destination.x - S.enemies[3].position.x) < 1e-6,
    "attaque du ver d'abord (le plus proche des soldats)")
  -- (d) Le ver tombe : la cible passe à un nid.
  S.enemies[3].destroy()
  S.SD.pass(f, TK + 150)
  local c3 = f.soldiers[op.ids[1]].entity._command
  check(c3 and c3.commands[1].type == defines.command.attack_area and math.abs(c3.commands[1].destination.x - S.enemies[3].position.x) > 1,
    "ver détruit : nouvelle cible (un nid)")
  -- (e) Tout est détruit : nettoyé, blocage levé, site remis en réserve, signal retiré, soldats rendus.
  S.enemies[1].destroy()
  S.enemies[2].destroy()
  S.SD.pass(f, TK + 180)
  check(t.sd.nt == nil and #logs(W, "nettoye tick") == 1 and #logs(W, "retour tick") == 1, "nettoyé : journal « nettoye » et « retour »")
  check((f.site_blocked or {}).coal == nil and #logs(W, "[FO-SITES] debloque tick") == 1, "signal retiré, « [FO-SITES] debloque »")
  local key = S.State.site_key(S.near)
  check(not (S.war.unreachable or {})[key] and #(f.site_block or {}) == 0, "blocage levé (war.unreachable, f.site_block)")
  local back = false
  for _, s in ipairs(f.prospects) do
    if s.resource == "coal" and (s.x - S.near.x) ^ 2 + (s.y - S.near.y) ^ 2 < 64 then back = true end
  end
  check(back, "site proche remis en réserve")
  local resting = 0
  for _, id in ipairs(S.soldier_ids) do
    if per[id] and per[id].rest_until and per[id].rest_until > TK + 180 and not f.soldiers[id].ia3k then resting = resting + 1 end
  end
  local clear_roles = 0
  for _, id in ipairs(S.soldier_ids) do if per[id] and per[id].role == "clear" then clear_roles = clear_roles + 1 end end
  check(clear_roles == 0 and t.sd.clearing == nil, "aucune expédition relancée vers les nids détruits (champ retiré)")
  check(resting == 10, "les 10 soldats de l'opération rentrent et se reposent (drapeau retiré)")
  check(#S.K.enemy_points(S.km, S.near.x, S.near.y, Nt.R) == 0, "carte de connaissance : le champ est oublié")
  local got = S.Sites.find(f, S.surface, TK + 200, "coal")
  check(got and (got.x - S.near.x) ^ 2 + (got.y - S.near.y) ^ 2 < 64, "les ouvriers puisent le site PROCHE (Sites.find)")
  local out = {}
  for _, l in ipairs(logs(W, "[FO-NETTOYAGE]")) do out[#out + 1] = l end
  return out
end

local first = run_full()
local second = run_full()
check(#first > 0 and table.concat(first, "\n") == table.concat(second, "\n"), "déterminisme : deux parties, mêmes lignes [FO-NETTOYAGE]")
for _, l in ipairs(first) do print("    " .. l) end

section("Retraite et refroidissement (moteur simulé)")
do
  local S = scenario()
  local f, W, TK = S.f, S.W, S.TK
  local t = S.C.team(f)
  S.add_soldiers(20)
  S.SD.pass(f, TK + 30)
  local op = t.sd.nt
  check(op and #op.ids == 10, "opération lancée")
  for i = 1, 6 do f.soldiers[op.ids[i]].entity.destroy() end
  S.SD.pass(f, TK + 60)
  check(t.sd.nt == nil and #logs(W, "retraite tick") == 1, "6 morts sur 10 : retraite (journal)")
  check(t.sd.nt_cool and #t.sd.nt_cool == 1, "site en refroidissement")
  S.SD.pass(f, TK + 90)
  check(t.sd.nt == nil and #logs(W, "prepare tick") == 1, "pas de nouvelle opération pendant le refroidissement")
  S.SD.pass(f, TK + 60 + Nt.COOL)
  check(t.sd.nt ~= nil or #logs(W, "attente tick") >= 1, "refroidissement fini : le site est de nouveau traité (opération ou attente)")
end

section("QG menacé, expédition, re-vérification (moteur simulé)")
do
  local S = scenario()
  local f, W, TK = S.f, S.W, S.TK
  local t = S.C.team(f)
  S.add_soldiers(30)
  t.alerts = { { x = S.hq.x + 10, y = S.hq.y, ["until"] = TK + 10000, n = 4 } }
  S.SD.pass(f, TK + 30)
  check(t.sd.nt == nil and #logs(W, "motif qg-menace") == 1, "alerte ouverte au QG : attente « qg-menace », aucune opération")
  -- L'expédition des soldats (lot CORR-SOLDATS) a pu partir vers le même champ pendant l'alerte (une alerte ne prend que 4
  -- soldats) : on la considère finie, rôles rendus, pour voir l'opération partir.
  t.alerts = {}
  t.sd.clearing = nil
  for _, id in ipairs(S.soldier_ids) do
    local ps = t.sd.per[id]
    if ps then ps.role, ps.key, ps.rest_until = nil, nil, nil end
    f.soldiers[id].ia3k = nil
  end
  S.SD.pass(f, TK + 60)
  check(t.sd.nt ~= nil, "alerte close : l'opération part")
  -- Annulation au rassemblement si le QG est menacé.
  t.alerts = { { x = S.hq.x + 10, y = S.hq.y, ["until"] = TK + 10000, n = 4 } }
  S.SD.pass(f, TK + 90)
  check(t.sd.nt == nil and #logs(W, "annule tick") == 1, "QG menacé pendant le rassemblement : opération annulée (journal)")
end
do
  -- Hostile sans nid connu (ennemis retirés, secteur vu vide) : re-vérification, site libre remis en réserve.
  local S = scenario()
  local f, W, TK = S.f, S.W, S.TK
  for _, e in ipairs(S.enemies) do e.destroy() end
  S.record_all(TK)
  local t = S.C.team(f)
  S.add_soldiers(20)
  S.SD.pass(f, TK + 30)
  check(t.sd.nt == nil and #logs(W, "reverifie tick") == 1 and (f.site_blocked or {}).coal == nil,
    "hostile sans nid connu : re-vérifié, libre, signal retiré, aucun soldat engagé")
end
do
  -- Hostile sans nid connu mais une unité ennemie encore là : re-vérifié, toujours bloqué, pas avant RECHECK.
  local S = scenario()
  local f, W, TK = S.f, S.W, S.TK
  for _, e in ipairs(S.enemies) do e.destroy() end
  S.record_all(TK)
  M.new_entity("small-biter", S.near.x + 3, S.near.y, S.surface, "enemy")
  local t = S.C.team(f)
  S.add_soldiers(20)
  S.SD.pass(f, TK + 30)
  check(#logs(W, "reverifie tick") == 1 and #logs(W, "toujours bloque") == 1 and (f.site_blocked or {}).coal ~= nil,
    "unité ennemie sur le site : toujours bloqué après re-vérification")
  S.SD.pass(f, TK + 60)
  check(#logs(W, "reverifie tick") == 1, "pas de nouvelle re-vérification avant RECHECK")
end
do
  -- Coupure de banc (soldats_offensive = false) : rien.
  local S = scenario()
  S.war.settings = S.war.settings or {}
  S.war.settings.soldats_offensive = false
  S.add_soldiers(30)
  S.SD.pass(S.f, S.TK + 30)
  check(S.C.team(S.f).sd.nt == nil and #logs(S.W, "[FO-NETTOYAGE]") == 0, "coupure soldats_offensive : aucune opération")
end

---------------------------------------------------------------------------------------------------
-- 3. Sources
---------------------------------------------------------------------------------------------------
section("Sources")
do
  local sites = read("script/faction/sites.lua")
  local clr = tonumber(sites:match("local ENEMY_CLEARANCE = (%d+)"))
  check(clr == Nt.R, "Nt.R (" .. Nt.R .. ") = ENEMY_CLEARANCE de sites.lua (" .. tostring(clr) .. ")")
  local sd = read("script/ai3/soldats.lua")
  local a = sd:find("Nts.pass(f, t, sd, list", 1, true)
  local b = sd:find("Sd.assign({", 1, true)
  check(a and b and a < b, "soldats.lua : l'opération passe avant l'attribution des rôles (Sd.assign)")
  check(sd:find("clusters = Nt.filter_threats(clusters", 1, true) ~= nil, "soldats.lua : priorité sur les expéditions lointaines")
  local nts = read("script/ai3/nettoyage.lua")
  check(not nts:find("%f[%w_]pairs%(") and not nts:find("global%."), "script/ai3/nettoyage.lua : aucun pairs, aucun global")
  local nt = read("shared/ai3/nettoyage.lua")
  local code = nt:gsub("%-%-[^\n]*", "")
  check(not code:find("game%.") and not code:find("defines%.") and not code:find("require%(\"script"), "shared/ai3/nettoyage.lua : pur")
end

print(string.format("\n[NETTOYAGE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
