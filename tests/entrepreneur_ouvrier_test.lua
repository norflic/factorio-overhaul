--[[
  tests/entrepreneur_ouvrier_test.lua — ouvrier dédié du chantier entrepreneur (shared/team/entrepreneur_ouvrier.lua).
  Usage : lua5.2 tests/entrepreneur_ouvrier_test.lua
]]
package.path = "./?.lua;" .. package.path
local Eo = require("shared.team.entrepreneur_ouvrier")

local ok, ko = 0, 0
local function check(cond, msg)
  if cond then ok = ok + 1 else ko = ko + 1; print("ECHEC : " .. msg) end
end

-- §1 projet vivant : plus petit numéro entrepreneur non fini
do
  local pr = {
    [7] = { spec = { entrepreneur = true }, state = "fini" },
    [12] = { spec = { entrepreneur = true }, state = "chantier" },
    [9] = { spec = { entrepreneur = true }, state = "reserve" },
    [3] = { spec = {}, state = "chantier" },
  }
  check(Eo.live_pid(pr) == 9, "live_pid : 9 (7 fini, 3 non entrepreneur)")
  pr[9].state = "fini"
  check(Eo.live_pid(pr) == 12, "live_pid : 12 apres la fin de 9")
  check(Eo.live_pid({}) == nil, "live_pid : aucun projet")
end

-- §2 fiche : lien, garde de l'ouvrier, reprise s'il meurt, libération
do
  local rec, ev = Eo.step(nil, 9, { 5, 2, 8 }, { [5] = true, [2] = true, [8] = true }, 100)
  check(rec and rec.pid == 9 and rec.wid == 2 and #ev == 1 and ev[1][1] == "lie", "lie : plus petit numero vivant (2)")
  rec, ev = Eo.step(rec, 9, { 5, 2, 8, 1 }, { [5] = true, [2] = true, [8] = true, [1] = true }, 160)
  check(rec.wid == 2 and #ev == 0, "ouvrier courant garde (pas de bascule vers 1)")
  rec, ev = Eo.step(rec, 9, { 5, 2, 8, 1 }, { [5] = true, [8] = true, [1] = true }, 220)
  check(rec.wid == 1 and ev[1][1] == "relie", "ouvrier mort : relie au plus petit vivant (1)")
  local old = rec
  rec, ev = Eo.step(rec, nil, {}, {}, 300)
  check(rec == nil and #ev == 1 and ev[1][1] == "libere" and old.t_end == 300, "projet fini : libere")
  rec, ev = Eo.step(old, 12, { 4 }, { [4] = true }, 400)
  check(rec.pid == 12 and rec.wid == 4 and ev[1][1] == "libere" and ev[2][1] == "lie", "projet suivant : libere puis lie")
  rec = Eo.step(nil, 9, { 3 }, {}, 1)
  check(rec and rec.wid == nil, "aucun ouvrier vivant : fiche sans ouvrier (rien de bloque)")
end

-- §3 prise : seulement les tâches libres du projet, dans l'ordre de la liste ; sinon nil (prise ordinaire)
do
  local a = { key = "craft:x" }
  local b = { key = "ia1d:5:b:1", ia1d = { pid = 5 } }
  local c = { key = "ia1d:9:b:1", ia1d = { pid = 9 }, worker = 3 }
  local d = { key = "ia1d:9:b:2", ia1d = { pid = 9 } }
  local e = { key = "ia1d:9:c:1", ia1d = { pid = 9 } }
  local list = { a, b, c, d, e }
  local tasks = {}
  for _, t in ipairs(list) do tasks[t.key] = t end
  check(Eo.pick(list, tasks, 9) == 4, "pick : premiere tache libre du projet 9 (d)")
  check(Eo.pick(list, tasks, 9, function(t) return t ~= d end) == 5, "pick : matiere refusee, la suivante (e)")
  tasks[d.key], tasks[e.key] = nil, nil
  check(Eo.pick(list, tasks, 9) == nil, "pick : plus rien au tableau -> nil (prise ordinaire)")
  check(Eo.pick(list, tasks, 7) == nil, "pick : projet sans tache -> nil")
end

-- §4 bilan
do
  local rec = Eo.step(nil, 9, { 2 }, { [2] = true }, 0)
  check(Eo.note_claim(rec, { ia1d = { pid = 9 } }, 50) and rec.t_first == 50, "premiere prise datee")
  Eo.note_claim(rec, { ia1d = { pid = 9 } }, 80)
  check(rec.t_first == 50 and rec.claims == 2, "date de premiere prise gardee")
  check(not Eo.note_claim(rec, { ia1d = { pid = 4 } }, 90), "prise d'un autre projet ignoree")
  Eo.note_done(rec, { ia1d = { pid = 9 } }, 2, true, 100)
  Eo.note_done(rec, { ia1d = { pid = 9 } }, 6, true, 110)
  Eo.note_done(rec, { ia1d = { pid = 9 } }, 2, false, 120)
  check(not Eo.note_done(rec, { kind = "craft" }, 2, true, 130), "tache hors projet ignoree")
  check(rec.own == 1 and rec.other == 1 and rec.fail == 1, "bilan : 1 par l'ouvrier, 1 par un autre, 1 echec")
end

-- §5 déterminisme : même entrée, même fiche (ordre des numéros indifférent)
do
  local r1 = Eo.step(nil, 3, { 9, 4, 6 }, { [9] = true, [4] = true, [6] = true }, 0)
  local r2 = Eo.step(nil, 3, { 6, 9, 4 }, { [9] = true, [4] = true, [6] = true }, 0)
  check(r1.wid == r2.wid and r1.wid == 4, "ordre des numeros indifferent")
end

print(string.format("entrepreneur_ouvrier_test : %d OK, %d ECHEC", ok, ko))
os.exit(ko == 0 and 0 or 1)
