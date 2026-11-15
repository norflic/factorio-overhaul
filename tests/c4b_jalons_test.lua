--[[
  Lot c4b (preuve du CHANTIER 4) : jalon « tache » (première tâche du tableau qui sert l'ordre, Co.task_hits) et jalon « route » de Maj+E
  (l'ouvrier qui va au point A compte : avant, il ne tombait qu'au retour de la tournée au QG). Batteries + mutants.
  Lancement, depuis la racine du mod : lua5.2 tests/c4b_jalons_test.lua
]]
package.path = "./?.lua;" .. package.path
local ok, ko = 0, 0
local function check(c, msg) if c then ok = ok + 1 else ko = ko + 1; print("  ECHEC : " .. msg) end end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end
local function mutant(path, pat, rep)
  local s2, n = read(path):gsub(pat, rep, 1)
  if n ~= 1 then return nil end
  return assert(load(s2, "=" .. path .. "(mutant)"))()
end

local function battery(Co)
  local fails = 0
  local function ck(c) if not c then fails = fails + 1 end end
  local A = { kind = "gisement", x = 0, y = 0, r = 10, tick = 1000, band_fid = 100004 }
  -- tâche du projet de la bande de l'ordre, même hors de la zone, même née avant : oui
  ck(Co.task_hits(A, { ia1d = { pid = 50, ax = 300, ay = 300 }, created = 10 }, 50))
  -- tâche d'un autre projet hors zone : non
  ck(not Co.task_hits(A, { ia1d = { pid = 35, ax = 300, ay = 300 }, created = 2000 }, 50))
  -- tâche née après l'ordre, ancre dans la zone : oui ; née avant : non
  ck(Co.task_hits(A, { ia1d = { pid = 9, ax = 3, ay = 4 }, created = 1000 }, nil))
  ck(not Co.task_hits(A, { ia1d = { pid = 9, ax = 3, ay = 4 }, created = 999 }, nil))
  -- liaison : tournée prioritaire de l'avant-poste du point A ; tâche née après l'ordre au point A
  local E = { kind = "liaison", x = 100, y = 0, r = 8, tick = 500, a = { x = 0, y = 0, r = 8 }, tour = { oid = 3 } }
  ck(Co.task_hits(E, { kind = "service", outpost = 3, created = 1 }, nil))
  ck(not Co.task_hits(E, { kind = "service", outpost = 4, created = 600 }, nil))
  ck(Co.task_hits(E, { kind = "build", pos = { x = 2, y = 1 }, created = 600 }, nil))
  -- bastion : tâche « fortify » née après l'ordre, posée dans la zone
  local R = { kind = "bastion", x = 60, y = 0, r = 10, tick = 100 }
  ck(Co.task_hits(R, { kind = "fortify", pos = { x = 62, y = 1 }, created = 160 }, nil))
  ck(Co.task_hits(R, { kind = "craft", key = "ia3:0:craft:gun-turret:tourelle:1", created = 160 }, nil))
  ck(not Co.task_hits(R, { kind = "craft", key = "ia3:0:craft:gun-turret:tourelle:1", created = 50 }, nil))
  -- amélioration : tâche du kit (tag amelio) née après l'ordre
  local Z = { kind = "amelioration", x = 0, y = 0, r = 29, tick = 100 }
  ck(Co.task_hits(Z, { kind = "craft", tag = "amelio", created = 200 }, nil))
  ck(not Co.task_hits(Z, { kind = "craft", tag = "amelio", created = 50 }, nil))
  -- jalons : « tache » en tête ; une route vaut une tâche
  ck(Co.MILESTONES[1] == "tache")
  local o = { tick = 0 }
  local news = Co.progress(o, { tache = true, route = true }, 120)
  ck(o.t_tache == 120 and news[1] and news[1].what == "tache" and news[2].what == "route")
  o = { tick = 0 }
  Co.progress(o, { tache = true }, 30)
  ck(o.t_tache == 30 and o.t_route == nil)
  return fails
end

local Co = require("shared.ai3.commande")
check(battery(Co) == 0, "1. Co.task_hits / jalon tache")
local m1 = mutant("shared/ai3/commande.lua", "if band_pid ~= nil and ia and ia%.pid == band_pid then return true end", "")
check(m1 ~= nil and battery(m1) > 0, "1. mutant (tâche de la bande d'ordre ignorée) : la batterie échoue")
local m2 = mutant("shared/ai3/commande.lua", " or %(o%.a and inside%(o%.a, p%[1%], p%[2%], Co%.DONE_MARGIN%)%)", "")
check(m2 ~= nil and battery(m2) > 0, "1. mutant (point A d'une liaison ignoré) : la batterie échoue")
local m3 = mutant("shared/ai3/commande.lua", "if %(t%.created or %-1%) < %(o%.tick or 0%) then return false end", "")
local m4 = mutant("shared/ai3/commande.lua", "if o%.kind == \"bastion\" and t%.kind == \"craft\"", "if false and t.kind == \"craft\"")
check(m4 ~= nil and battery(m4) > 0, "1. mutant (fabrication des tourelles du bastion ignorée) : la batterie échoue")
check(m3 ~= nil and battery(m3) > 0, "1. mutant (tâches nées avant l'ordre comptées) : la batterie échoue")

local CMD = read("script/gui/commande.lua")
check(CMD:find("or (o.a and Co.inside(o.a, p[1], p[2], Co.DONE_MARGIN)) then", 1, true) ~= nil, "2. route de Maj+E : l'ouvrier vers le point A compte")
check(CMD:find("first_t = first_task(f, o)", 1, true) ~= nil and CMD:find("(obs.route or o.t_route or o.t_kit) then obs.tache = true end", 1, true) ~= nil,
  "2. jalon tache relevé dans track_step (une route vaut une tâche)")
check(read("locale/fr/commande.cfg"):find("jalon-tache=", 1, true) and read("locale/en/commande.cfg"):find("jalon-tache=", 1, true), "2. jalon tache traduit FR et EN")
local MC = read("script/team/migration_champ.lua")
check(MC:find('mark("t_susp")', 1, true) and MC:find('mark("t_ent")', 1, true), "3. réveil et suspension datés par ordre (t_ent, t_susp)")
print(string.format("[C4B-JALONS] BILAN : %d OK, %d ECHEC(S)", ok, ko))
if ko > 0 then os.exit(1) end
