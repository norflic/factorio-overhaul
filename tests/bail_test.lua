--[[
  Lot ETAGE4 (4/11) : test hors jeu de shared/team/bail.lua (bail des tournées prises).
    §1 progrès : première lecture, autre étape, autre état, déplacement (cumulé), rien ; §2 bail échu (types à bail seulement, seuil) ;
    §3 tournée vivante (libre récente, prise qui progresse ; absente, oubliée, prise sans progrès : non) ; §4 cas mesuré d'Émeraude (41 min
    sans progrès) rejoué pensée par pensée ; §5 câblage, §5 bis le moniteur joué sur des doublures (Émeraude, combat, PNJ qui tient autre chose, M2, pause,
    autres tâches mesurées, interrupteur) et ses mutants (m6) ; §6 mutants de la règle ; §7 aucun nom d'objet. Worker.release_stuck au moteur
    simulé : tests/bail_moteur_test.lua.
  Usage : lua5.2 tests/bail_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/bail.lua")
local function load_bl(src)
  local fn = load(src, "=bl", "t")
  if not fn then return nil end
  local ok, m = pcall(fn)
  return ok and m or nil
end

local ok_n, bad = 0, 0
local function check(name, cond)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[BAIL] ECHEC : " .. name) end
end

local function suite(Bl)
  local res = {}
  local function c(name, cond) res[#res + 1] = { name, cond and true or false } end
  -- §1 sans but (règle de l'essai 1)
  local p, s = Bl.progress(nil, { pc = 2, state = "walk", x = 10, y = 5 }, 100)
  c("premiere lecture : progres, 0", s == 0 and p.t == 100 and p.pc == 2 and p.state == "walk")
  local p2, s2 = Bl.progress(p, { pc = 2, state = "walk", x = 10.3, y = 5.2 }, 400)
  c("immobile : pas de progres, temps qui court", s2 == 300 and p2.t == 100)
  local p3, s3 = Bl.progress(p2, { pc = 3, state = "walk", x = 10.3, y = 5.2 }, 700)
  c("autre etape : progres", s3 == 0 and p3.t == 700 and p3.pc == 3)
  local p4, s4 = Bl.progress(p3, { pc = 3, state = "step", x = 10.3, y = 5.2 }, 800)
  c("autre etat : progres", s4 == 0 and p4.t == 800)
  local p5, s5 = Bl.progress(p4, { pc = 3, state = "step", x = 10.3 + Bl.MOVE, y = 5.2 }, 900)
  c("sans but : deplacement d'une tuile = progres", s5 == 0 and p5.t == 900)
  local q = { pc = 1, state = "walk", x = 0, y = 0, t = 0 }
  local q1, t1 = Bl.progress(q, { pc = 1, state = "walk", x = 0.6, y = 0 }, 300)
  local q2, t2 = Bl.progress(q1, { pc = 1, state = "walk", x = 1.2, y = 0 }, 600)
  c("sans but : reptation cumulee = progres", t1 == 300 and t2 == 0 and q2.t == 600)
  local _, t3 = Bl.progress(q, { pc = 1, state = "walk", x = 0, y = Bl.MOVE - 0.01 }, 300)
  c("sans but : juste sous une tuile : pas de progres", t3 == 300)
  -- §1 bis avec but (M1) : seule l'approche plus près que jamais compte
  local g0 = Bl.progress(nil, { pc = 3, state = "walk", x = 0, y = 0, gx = 20, gy = 0 }, 0)
  c("avec but : premiere lecture, meilleure distance 20", math.abs((g0.best or -1) - 20) < 1e-9)
  local g1, u1 = Bl.progress(g0, { pc = 3, state = "walk", x = 5, y = 0, gx = 20, gy = 0 }, 300)
  c("avec but : s'approche de 5 tuiles = progres", u1 == 0 and math.abs(g1.best - 15) < 1e-9 and g1.t == 300)
  local g2, u2 = Bl.progress(g1, { pc = 3, state = "walk", x = 5, y = 12, gx = 20, gy = 0 }, 600)
  c("avec but : bouge de 12 tuiles sans s'approcher = PAS de progres (tourne en rond)", u2 == 300 and g2.t == 300)
  local _, u3 = Bl.progress(g2, { pc = 3, state = "walk", x = 1, y = 0, gx = 20, gy = 0 }, 900)
  c("avec but : revient en arriere (plus loin que le meilleur) = pas de progres", u3 == 600)
  local _, u4 = Bl.progress(g1, { pc = 3, state = "walk", x = 5 + Bl.MOVE - 0.01, y = 0, gx = 20, gy = 0 }, 600)
  c("avec but : approche juste sous une tuile = pas de progres", u4 == 300)
  local _, u4b = Bl.progress(g1, { pc = 3, state = "walk", x = 5 + Bl.MOVE, y = 0, gx = 20, gy = 0 }, 600)
  c("avec but : approche d'exactement une tuile = progres", u4b == 0)
  local g5, u5 = Bl.progress(g2, { pc = 3, state = "walk", x = 5, y = 12, gx = 40, gy = 40 }, 1200)
  c("avec but : autre but (point de passage suivant) = progres", u5 == 0 and g5.t == 1200 and g5.gx == 40)
  local _, u6 = Bl.progress(g1, { pc = 3, state = "walk", x = 5, y = 0, gx = 20 + Bl.GOAL_EPS / 2, gy = 0 }, 600)
  c("avec but : but qui bouge d'un rien = meme but", u6 == 300)
  local _, u7 = Bl.progress(g1, { pc = 3, state = "walk", x = 5, y = 0 }, 600)
  c("but perdu (nil) : regle sans but, immobile = pas de progres", u7 == 300)
  -- §2 bail échu
  c("tournee sans progres depuis le bail : echu", Bl.expired("service", Bl.LEASE) == true)
  c("juste sous le bail : non", Bl.expired("service", Bl.LEASE - 1) == false)
  c("fabrication : jamais", Bl.expired("craft", 1e9, 1e9, true) == false)
  c("garde : jamais", Bl.expired("garrison", 1e9, 1e9, true) == false)
  c("bail de 2 min au plus (une tournee normale marche ou agit)", Bl.LEASE <= 2 * 3600 and Bl.LEASE >= 3600)
  c("avant l'acte : tenue maximale echue meme en progressant", Bl.expired("service", 0, Bl.MAX_HOLD, true) == true)
  c("avant l'acte : juste sous la tenue maximale : non", Bl.expired("service", 0, Bl.MAX_HOLD - 1, true) == false)
  c("apres l'acte (retour, travail fait) : la tenue maximale ne coupe pas", Bl.expired("service", 0, 1e9, false) == false)
  c("apres l'acte : sans progres, le bail coupe quand meme", Bl.expired("service", Bl.LEASE, 0, false) == true)
  c("tenue maximale entre le bail et 5 min", Bl.MAX_HOLD >= Bl.LEASE and Bl.MAX_HOLD <= 5 * 3600)
  -- §3 tournée vivante
  local stale = 5 * 3600
  c("libre recente : vivante", Bl.alive("libre", 10, nil, stale) == true)
  c("libre oubliee : non", Bl.alive("libre", stale, nil, stale) == false)
  c("prise qui progresse : vivante", Bl.alive("prise", nil, 0, stale) == true)
  c("prise sans progres depuis le bail : non", Bl.alive("prise", nil, Bl.LEASE, stale) == false)
  c("prise avant l'acte, tenue trop longue : non", Bl.alive("prise", nil, 0, stale, Bl.MAX_HOLD, true) == false)
  c("prise avant l'acte, tenue courte : vivante", Bl.alive("prise", nil, 0, stale, Bl.MAX_HOLD - 1, true) == true)
  c("prise apres l'acte, longue mais progresse : vivante", Bl.alive("prise", nil, 0, stale, 1e9, false) == true)
  c("absente : non", Bl.alive(nil, nil, nil, stale) == false)
  -- §4 Émeraude (fd-croiss-123456789) : prise à 18,7 min, PNJ immobile près de son but ; une pensée toutes les 300 ticks
  local rec, stall, released = nil, 0, nil
  for tick = 67320, 67320 + 41 * 3600, 300 do
    rec, stall = Bl.progress(rec, { pc = 2, state = "walk", x = -179.4, y = 488.6, gx = -175.5, gy = 488.5 }, tick)
    if Bl.expired("service", stall, tick - 67320, true) then released = tick break end
  end
  c("Emeraude : rendue au bail (2 min apres la prise, et non 41 min)", released ~= nil and released - 67320 <= Bl.LEASE + 300)
  -- Tourne autour de son but sans s'approcher (après l'acte : seule l'approche compte) : rendue au bail
  local rec2, st2, rel2 = nil, 0, nil
  local ring = { { 10, 0 }, { 0, 10 }, { -10, 0 }, { 0, -10 } }
  for k = 0, 60 do
    local tick = k * 300
    local pos = ring[(k % 4) + 1]
    rec2, st2 = Bl.progress(rec2, { pc = 3, state = "walk", x = pos[1], y = pos[2], gx = 0, gy = 0 }, tick)
    if Bl.expired("service", st2, 0, false) then rel2 = tick break end
  end
  c("tourne en rond a 10 tuiles du but : rendue au bail", rel2 ~= nil and rel2 <= Bl.LEASE + 300)
  -- §1 ter combat et fuite (m5)
  c("ni comportement ni tir : pas au combat", Bl.busy(nil, nil, 100) == false and Bl.busy({}, false, 100) == false)
  c("autodefense qui tire : au combat", Bl.busy(nil, true, 100) == true)
  c("arret engage en cours : au combat", Bl.busy({ hold = 500 }, nil, 499) == true)
  c("arret engage fini : non", Bl.busy({ hold = 500 }, nil, 500) == false)
  c("arret d'ALERTE : pas un combat", Bl.busy({ hold = 500, hold_stop = true }, nil, 400) == false)
  c("fuite en cours : oui", Bl.busy({ refuge = { x = 0, y = 0 }, flee_t = 0 }, nil, Bl.FLEE_MAX - 1) == true)
  c("fuite plus longue que Bl.FLEE_MAX : recompte", Bl.busy({ refuge = { x = 0, y = 0 }, flee_t = 0 }, nil, Bl.FLEE_MAX) == false)
  c("refuge atteint (efface) : plus en fuite", Bl.busy({ flee_t = 0 }, nil, 10) == false)
  c("fuite bornee entre 1 et 5 min", Bl.FLEE_MAX >= 3600 and Bl.FLEE_MAX <= 5 * 3600)
  local w0 = { pc = 2, state = "walk", x = 0, y = 0, t = 0 }
  local w1, z1 = Bl.progress(w0, { pc = 2, state = "walk", x = 0, y = 0, busy = true }, 600)
  c("au combat : le temps ne compte pas (progres)", z1 == 0 and w1.t == 600)
  local fight, fstall, frel = nil, 0, nil
  for tick = 0, 20 * 3600, 300 do
    fight, fstall = Bl.progress(fight, { pc = 2, state = "walk", x = 5, y = 5, gx = 50, gy = 5, busy = tick < 10 * 3600 }, tick)
    if Bl.expired("service", fstall, 0, false) then frel = tick break end
  end
  c("combat sur place de 10 min : rendue seulement un bail apres la fin du combat", frel ~= nil and frel >= 10 * 3600 + Bl.LEASE - 300
    and frel <= 10 * 3600 + Bl.LEASE + 300)
  -- §2 bis tenue hors combat (m5) ; bails de suite et pause (m4)
  c("tenue : au combat, l'origine avance du temps passe", Bl.held_base(100, 400, 700, true) == 400)
  c("tenue : hors combat, l'origine reste", Bl.held_base(100, 400, 700, false) == 100)
  c("tenue : premiere pensee (pas de precedente), l'origine reste", Bl.held_base(100, nil, 700, true) == 100)
  c("bails : premier = 1", Bl.count(nil, false) == 1)
  c("bails : de suite, sans reussite entre deux : +1", Bl.count(1, false) == 2)
  c("bails : apres une tournee reussie : repart a 1", Bl.count(5, true) == 1)
  c("pause : pas au premier bail", Bl.pause(1) == false)
  c("pause : au deuxieme bail de suite", Bl.pause(2) == true and Bl.pause(nil) == false)
  c("pause entre 5 et 15 min", Bl.PAUSE_TICKS >= 5 * 3600 and Bl.PAUSE_TICKS <= 15 * 3600)
  return res
end

local Bl = assert(load_bl(SRC), "module illisible")
for _, r in ipairs(suite(Bl)) do check(r[1], r[2]) end

-- §5 câblage (textes) : pensée d'équipe, tableau, lecteur des tournées
local M = read("script/team/bail.lua")
local TM = read("script/team/team.lua")
local BD = read("script/team/board.lua")
local SO = read("script/team/sorties.lua")
check("pensee d'equipe : bail juste apres la synchronisation", (TM:find("Board.sync(f, plan.tasks", 1, true) or 1e9) < (TM:find("Bail.think(f, tick)", 1, true) or 0)
  and (TM:find("Bail.think(f, tick)", 1, true) or 1e9) < (TM:find("Board.assign(f, tick)", 1, true) or 0))
check("tableau (m4) : Board.finish ne raccourcit pas une pause", BD:find("b.cooldown[task.key] = math.max(tick + delay, b.cooldown[task.key] or 0)", 1, true) ~= nil)
check("lecteur (m3) : tournee abandonnee = absente", SO:find("if not t or t.fail or t.bailed then return nil, nil, nil, nil, nil end", 1, true) ~= nil)
check("lecteur : tenue hors combat (t.hold_t)", SO:find("tick - (t.hold_t or t.claimed or tick)", 1, true) ~= nil)

-- §5 bis le MONITEUR (script/team/bail.lua) joué sur des doublures : tableau, registre, PNJ, crochet des comportements, Worker.release_stuck
-- (doublure fidèle : 1re fois abandon, programme « rentrer », motif gardé ; 2e fois dégagé, tâche finie). Revue du lead (m6) : les mutants de la
-- couche script doivent mourir.
local function sorted(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

local function harness(msrc)
  local env = { logs = {}, finished = {}, released = {}, agents = {}, board = { tasks = {}, cooldown = {} }, k = {}, hook_on = false }
  local Board = {
    get = function() return env.board end,
    finish = function(f, t, ok, tick)
      local holder
      for _, id in ipairs(sorted(env.agents)) do if env.agents[id].task == t then holder = id end end
      env.finished[#env.finished + 1] = { key = t.key, ok = ok, tick = tick, holder = holder, fail = t.fail }
      if env.board.tasks[t.key] == t then env.board.tasks[t.key] = nil end
    end,
  }
  local Wk = {
    hook = { enabled = function() return env.hook_on end, astate = function(a) return env.k[a.id] end },
    release_stuck = function(agent, f, tick)
      local task = agent.task
      env.released[#env.released + 1] = { id = agent.id, tick = tick }
      if task and not task.bailed then
        task.bailed = true
        task.fail = task.fail or "bail"
        agent.steps, agent.pc, agent.state = { { "home" } }, 1, "step"
        return "abandon"
      end
      if task then task.fail = task.fail or "bail" end
      Board.finish(f, task, false, tick)
      agent.task, agent.steps, agent.pc, agent.state = nil, nil, nil, "idle"
      return "degage"
    end,
  }
  local stubs = {
    ["shared.team.bail"] = assert(load_bl(SRC)),
    ["script.faction.state"] = { sorted_keys = sorted },
    ["script.companion.registry"] = { get = function(id) return env.agents[id] end },
    ["script.team.board"] = Board,
    ["script.team.worker"] = Wk,
  }
  local saved = {}
  for name, v in pairs(stubs) do saved[name] = package.loaded[name] package.loaded[name] = v end
  local fn = load(msrc, "=moniteur", "t")
  local ok, B = false, nil
  if fn then ok, B = pcall(fn) end
  for name in pairs(stubs) do package.loaded[name] = saved[name] end
  if not ok or type(B) ~= "table" then return nil end
  env.B = B
  env.f = { key = "emerald", team = {}, stats = {}, outposts = { [1] = { flux_fails = 0 } } }
  -- PNJ d'Émeraude mesuré (fd-croiss-123456789) : immobile près de son but, étape 2 de 4 (aller), l'acte après.
  function env.npc(id, steps, pc)
    local a = { id = id, state = "walk", pc = pc or 2, steps = steps or { { "goto" }, { "goto" }, { "act" }, { "home" } },
      goal = { x = -175.5, y = 488.5 }, entity = { valid = true, position = { x = -179.4, y = 488.6 } } }
    env.agents[id] = a
    return a
  end
  function env.task(key, kind, worker, tick)
    local t = { key = key, kind = kind, worker = worker, claimed = tick or 0, outpost = 1 }
    env.board.tasks[key] = t
    if worker and env.agents[worker] then env.agents[worker].task = t end
    return t
  end
  function env.run(from, to, each)
    local log0 = log
    log = function(s) env.logs[#env.logs + 1] = s end
    local okr, err = pcall(function()
      for tick = from, to, 300 do
        if each then each(tick) end
        B.think(env.f, tick)
      end
    end)
    log = log0
    return okr, err
  end
  function env.has(pat)
    for _, s in ipairs(env.logs) do if s:find(pat, 1, true) then return true end end
    return false
  end
  return env
end

local function monitor_suite(msrc)
  local res = {}
  local function c(name, cond) res[#res + 1] = { name, cond and true or false } end
  -- A. Émeraude : immobile avant l'acte : abandon au bail, PUIS dégagé un bail entier après l'abandon (pas plus tôt : la tenue maximale ne
  -- s'applique plus au retour) ; le journal dit l'état d'AVANT.
  local E = harness(msrc)
  if not E then c("moniteur chargeable", false) return res end
  E.npc(7)
  E.task("service:1", "service", 7, 0)
  local okA = E.run(300, 20 * 3600)
  local r1, r2 = E.released[1], E.released[2]
  c("A : abandon au bail (2 min, et non 41)", okA and r1 ~= nil and r1.tick <= Bl.LEASE + 300)
  c("A : degage un bail entier apres l'abandon, pas avant", r2 ~= nil and r2.tick - r1.tick >= Bl.LEASE - 300 and r2.tick - r1.tick <= Bl.LEASE + 300)
  c("A : tache finie une seule fois, en echec", #E.finished == 1 and E.finished[1].ok == false)
  c("A : le journal dit l'etat d'AVANT le bail (etape 2/4, aller)", E.has("etape 2/4 (goto)"))
  c("A : premier bail compte, pas de pause", (E.board.bail_n or {})["service:1"] == 1 and E.board.cooldown["service:1"] == nil)
  -- B. Combat sur place 10 min (crochet allumé, arrêt « engage » renouvelé), avant l'acte : rien n'est rendu pendant le combat (ni sans progrès,
  -- ni tenue trop longue) ; rendue un bail après la fin du combat.
  local C = harness(msrc)
  C.hook_on = true
  C.npc(7)
  C.task("service:1", "service", 7, 0)
  C.run(300, 20 * 3600, function(tick) C.k[7] = tick < 10 * 3600 and { hold = tick + 120 } or {} end)
  local c1 = C.released[1]
  c("B : rien de rendu pendant 10 min de combat", c1 ~= nil and c1.tick >= 10 * 3600)
  c("B : rendue un bail apres la fin du combat", c1 ~= nil and c1.tick <= 10 * 3600 + Bl.LEASE + 300)
  -- C. PNJ qui tient AUTRE CHOSE : la tâche est rendue sans toucher à sa vraie tâche.
  local O = harness(msrc)
  local a = O.npc(7)
  O.task("service:1", "service", 7, 0)
  local other = { key = "mine:9", kind = "mine", worker = 7 }
  a.task = other
  O.run(300, 300)
  c("C : PNJ qui tient autre chose : tache rendue des la 1re pensee", #O.finished == 1 and O.finished[1].key == "service:1" and #O.released == 0)
  c("C : sa vraie tache n'est pas touchee", a.task == other and a.steps ~= nil)
  -- D. Entité perdue, le PNJ tient encore la tâche (M2) : il ne la tient plus quand Board.finish est appelé.
  local D2 = harness(msrc)
  local d = D2.npc(7)
  D2.task("service:1", "service", 7, 0)
  d.entity.valid = false
  D2.run(300, 300)
  c("D (M2) : tache rendue, le PNJ ne la tient plus a Board.finish", #D2.finished == 1 and D2.finished[1].holder == nil and d.task == nil)
  -- E. Pause (m4) : 2e bail de suite sans tournée réussie entre deux : pause ; après une tournée réussie : pas de pause.
  local P = harness(msrc)
  P.npc(7)
  P.task("service:1", "service", 7, 0)
  P.run(300, Bl.LEASE + 300)
  P.board.tasks["service:1"] = nil
  P.f.outposts[1].flux_fails = 1 -- la tournée abandonnée a fini en échec
  P.npc(7)
  P.task("service:1", "service", 7, 3 * 3600)
  P.run(3 * 3600 + 300, 3 * 3600 + Bl.LEASE + 300)
  local cd = P.board.cooldown["service:1"]
  c("E : 2e bail de suite : tournee en pause Bl.PAUSE_TICKS", cd ~= nil and cd >= 3 * 3600 + Bl.PAUSE_TICKS and P.has("en pause"))
  local Q = harness(msrc)
  Q.npc(7)
  Q.task("service:1", "service", 7, 0)
  Q.run(300, Bl.LEASE + 300)
  Q.board.tasks["service:1"] = nil
  Q.f.outposts[1].flux_fails = 0 -- une tournée a réussi entre deux
  Q.npc(7)
  Q.task("service:1", "service", 7, 3 * 3600)
  Q.run(3 * 3600 + 300, 3 * 3600 + Bl.LEASE + 300)
  c("E : bail apres une tournee reussie : pas de pause", Q.board.cooldown["service:1"] == nil and (Q.board.bail_n or {})["service:1"] == 1)
  -- F. AUTRE type de tâche tenue sans progrès : mesurée (lecture seule), jamais rendue ; une ligne, un compte ; bilan à 10 min.
  local G = harness(msrc)
  G.npc(8, { { "goto" }, { "wait" } }, 2)
  G.task("garrison:3", "garrison", 8, 0)
  G.run(300, 11 * 3600)
  local r = (G.f.stats.bail_autres or {}).garrison
  c("F : autre tache : jamais rendue", #G.released == 0 and #G.finished == 0)
  c("F : mesuree une fois (type, duree)", r ~= nil and r.n == 1 and r.max >= 9 * 3600 and G.has("MESURE (lecture seule) garrison:3"))
  c("F : bilan a 10 min", G.has("BILAN a 10 min") and G.has("garrison 1 (max"))
  -- G. Interrupteur de banc.
  local I = harness(msrc)
  I.f.team.bail_regle = false
  I.npc(7)
  I.task("service:1", "service", 7, 0)
  I.run(300, 10 * 3600)
  c("G : interrupteur coupe : rien", #I.released == 0 and #I.finished == 0)
  return res
end

for _, r in ipairs(monitor_suite(M)) do check("moniteur : " .. r[1], r[2]) end

local MMUTANTS = {
  { "sans PNJ sans agent.task == t (m6)", "if not (agent and e and e.valid and agent.task == t) then\n    -- Le PNJ", "if not (agent and e and e.valid) then\n    -- Le PNJ" },
  { "M2 retire", "if agent and agent.task == t then agent.task, agent.steps, agent.pc = nil, nil, nil end", "" },
  { "combat compte (m5)", "local busy = Bl.busy(k_of(agent), agent.shooting, tick)", "local busy = false" },
  { "tenue : combat compte (m5)", "t.hold_t = Bl.held_base(t.hold_t or t.claimed or tick, t.seen, tick, busy)", "t.hold_t = t.hold_t or t.claimed or tick" },
  { "tenue avant l'acte meme au retour", "t.pre_act = B.pre_act(agent)", "t.pre_act = true" },
  { "etat decrit APRES le bail", "local desc = describe(agent, tick)\n  local how = Worker.release_stuck(agent, f, tick)",
    "local how = Worker.release_stuck(agent, f, tick)\n  local desc = describe(agent, tick)" },
  { "bails jamais comptes (m4)", "if how == \"abandon\" then count_bail(f, b, t, tick) end", "" },
  { "reussite ignoree (m4)", "not (o and (o.flux_fails or 0) > 0)", "false" },
  { "pause sans effet (m4)", "b.cooldown[t.key] = math.max(b.cooldown[t.key] or 0, tick + Bl.PAUSE_TICKS)", "" },
  { "autres taches rendues", "if Bl.KINDS[t.kind] then n = n + lease(f, b, t, tick) else measure(f, t, tick) end", "n = n + lease(f, b, t, tick)" },
  { "mesure comptee a chaque pensee", "if t.bail_vu then return end", "" },
  { "interrupteur ignore", "if not (f.team and f.team.bail_regle ~= false) then return 0 end", "" },
}
local mref, mkept = 0, {}
for _, m in ipairs(MMUTANTS) do
  local a, b = M:find(m[2], 1, true)
  if not a then
    mkept[#mkept + 1] = m[1] .. " (motif introuvable)"
  else
    local seen = false
    local okm, res = pcall(monitor_suite, M:sub(1, a - 1) .. m[3] .. M:sub(b + 1))
    if not okm then seen = true else for _, r in ipairs(res) do if not r[2] then seen = true break end end end
    if seen then mref = mref + 1 else mkept[#mkept + 1] = m[1] end
  end
end
check(string.format("moniteur : mutants refuses %d/%d%s", mref, #MMUTANTS, #mkept > 0 and (" ; survivants : " .. table.concat(mkept, ", ")) or ""),
  mref == #MMUTANTS)

-- §6 mutants
local MUTANTS = {
  { "etape ignoree", "prev.pc ~= cur.pc or prev.state ~= cur.state then", "prev.state ~= cur.state then" },
  { "etat ignore", "prev.pc ~= cur.pc or prev.state ~= cur.state then", "prev.pc ~= cur.pc then" },
  { "combat compte comme temps sans progres (m5)", "cur.busy == true or ", "" },
  { "arret d'alerte = combat", "k.hold_stop == nil and ", "" },
  { "tir ignore", "if shooting == true then return true end", "" },
  { "fuite sans fin", "num(tick) - num(k.flee_t) < Bl.FLEE_MAX", "true" },
  { "tenue : combat compte (m5)", "if busy == true and last ~= nil then return num(base) + (num(tick) - num(last)) end", "" },
  { "bails jamais remis a zero (m4)", "if reset then return 1 end", "" },
  { "pause des le premier bail (m4)", "return num(n) >= Bl.HOLD_AFTER", "return num(n) >= 1" },
  { "sans but : deplacement ignore", "if dx * dx + dy * dy >= Bl.MOVE * Bl.MOVE then return fresh(cur, tick) end", "" },
  { "but : tout deplacement compte (essai 1)", "if d <= num(prev.best) - Bl.MOVE then", "if true then" },
  { "but : nouveau but ignore", "if prev.gx == nil or math.abs(num(prev.gx) - num(cur.gx)) + math.abs(num(prev.gy) - num(cur.gy)) > Bl.GOAL_EPS then", "if prev.gx == nil then" },
  { "but : meilleure distance oubliee", "best = d, t = tick }, 0", "best = num(prev.best), t = tick }, 0" },
  { "but : approche stricte", "if d <= num(prev.best) - Bl.MOVE then", "if d < num(prev.best) - Bl.MOVE then" },
  { "temps sans progres remis a zero", "    return prev, tick - num(prev.t)\n  end\n  local dx", "    return prev, 0\n  end\n  local dx" },
  { "bail sur tous les types", "if Bl.KINDS[kind] ~= true then return false end", "" },
  { "bail strict", "if num(stall) >= Bl.LEASE then return true end", "if num(stall) > Bl.LEASE then return true end" },
  { "tenue maximale ignoree", "return pre_act == true and num(held) >= Bl.MAX_HOLD", "return false" },
  { "tenue maximale apres l'acte aussi (essai 2)", "return pre_act == true and num(held) >= Bl.MAX_HOLD", "return num(held) >= Bl.MAX_HOLD" },
  { "bail de 41 min", "Bl.LEASE = 2 * 3600", "Bl.LEASE = 41 * 3600" },
  { "prise toujours vivante (avant ETAGE4)", "if state == \"prise\" then return not Bl.expired(\"service\", stall, held, pre_act) end", "if state == \"prise\" then return true end" },
  { "libre jamais oubliee", "if state == \"libre\" then return num(free_age) < num(stale) end", "if state == \"libre\" then return true end" },
  { "absente vivante", "  return false\nend\n\nreturn Bl", "  return true\nend\n\nreturn Bl" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local mut = load_bl(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    local seen = mut == nil
    if not seen then
      local ok, res = pcall(suite, mut)
      if not ok then seen = true else
        for _, r in ipairs(res) do if not r[2] then seen = true break end end
      end
    end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, #MUTANTS, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUTANTS)

-- §7 aucun nom d'objet du jeu dans le module
local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
local found = {}
for _, n in ipairs({ "coal", "stone", "iron", "copper", "chest", "furnace", "drill", "plate", "ore" }) do
  if code:find('"' .. n, 1, true) or code:find(n .. '"', 1, true) then found[#found + 1] = n end
end
check("aucun nom d'objet dans le module" .. (#found > 0 and (" : " .. table.concat(found, ",")) or ""), #found == 0)

print(string.format("[BAIL] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
