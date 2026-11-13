--[[
  Lot s42 diag-joueur (partie du DC en 0.7.96, 13/11, journal de 4 h 15) : banc HORS JEU. Lancement : lua5.2 tests/s42_diag-joueur_test.lua
  (racine du mod).

  Constat : votre équipe (7 836 plaques de fer en 245 min) et l'Ordre Écarlate (8 637) ne produisent plus rien après 49 min.
    - votre équipe : mode survie pendant plus de 3 h, « minages demandes 0 » à chaque bilan [FO-SURVIE] : le minage de survie était
      retiré de la file par la purge de la pioche (Mi.gone, ère électrique) ;
    - Ordre Écarlate : 14 PNJ sur 15 sans tâche, « manque iron-plate 40 », coffre à 0 plaque, aucun ennemi, aucun refus de la porte :
      la survie ne s'ouvrait jamais (Sv.paralysed ne lit que la porte et la menace).

    1. Mi.gone : le minage de survie reste après l'ère électrique ; le minage ordinaire sort toujours ;
    2. Sv.famine et Sv.decide : entrée par famine en paix, bornée (durée, coffre vide, PNJ sans tâche) ; rien de changé sans elle ;
    3. la CHAÎNE lue dans les sources : l'appelant passe `starved`, la tâche de survie porte `survie`.
]]
package.path = "./?.lua;" .. package.path
local Mi = require("shared.team.main_inventaire")
local Sv = require("shared.team.survie")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end
local function read_src(path)
  local fh = assert(io.open(path, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end

local ORE, PLATE = "minerai-x", "plaque-x" -- (noms de banc : la règle ne lit aucun nom)
local function drillable(item) return item == ORE end

---------------------------------------------------------------------------------------------------
section("1. Mi.gone : la pioche de survie reste")
---------------------------------------------------------------------------------------------------
check(Mi.gone({ kind = "mine", resource = ORE }, 1000, drillable) == true, "ère électrique : un minage libre ordinaire sort de la file (inchangé)")
check(Mi.gone({ kind = "mine", resource = ORE, survie = true }, 1000, drillable) == false, "ère électrique : le minage du mode survie reste")
check(Mi.gone({ kind = "mine", resource = ORE, crisis = true }, 1000, drillable) == true, "une tâche de crise sans le mode survie sort toujours (périmètre borné)")
check(Mi.gone({ kind = "mine", resource = ORE }, nil, drillable) == false, "avant l'ère électrique : rien ne sort (inchangé)")
check(Mi.gone({ kind = "mine", resource = ORE, worker = 3 }, 1000, drillable) == false, "une tâche prise finit (inchangé)")
check(Mi.gone({ kind = "mine", resource = "bois" }, 1000, drillable) == false, "un objet que la foreuse n'extrait pas reste (inchangé)")
check(Mi.gone({ kind = "craft", resource = ORE }, 1000, drillable) == false, "une autre tâche n'est pas concernée (inchangé)")

---------------------------------------------------------------------------------------------------
section("2. Sv.famine : entrée en survie sans refus de la porte")
---------------------------------------------------------------------------------------------------
local SHORT = { { PLATE, 40 } }
local function run(a, ticks)
  local st = Sv.new()
  local last
  for _, t in ipairs(ticks) do
    a.tick = t
    last = Sv.decide(st, a)
  end
  return st, last
end
local F = Sv.FAMINE_TICKS
-- le cas de l'Ordre Écarlate : 14 PNJ sur 15 sans tâche, coffre vide, aucun refus, aucune menace
local st1, d1 = run({ short = SHORT, workers = 15, idle = 14, starved = true }, { 0, F - 1 })
check(not st1.on and d1.event == nil, "famine plus courte que Sv.FAMINE_TICKS : pas d'entrée")
local st2, d2 = run({ short = SHORT, workers = 15, idle = 14, starved = true }, { 0, F })
check(st2.on and d2.event == "entree" and d2.para_why == "famine" and st2.cause:find("famine", 1, true) ~= nil,
  "manque durable, coffre vide, 14 PNJ sur 15 sans tâche : ENTRÉE par famine")
local st3 = run({ short = SHORT, workers = 15, idle = 14, starved = false }, { 0, F, 3 * F })
check(not st3.on, "la matière qui manque est encore au coffre : pas d'entrée (règle d'avant)")
local st4 = run({ short = SHORT, workers = 15, idle = 7, starved = true }, { 0, F, 3 * F })
check(not st4.on, "moins de Sv.IDLE_PCT_THREAT % de PNJ sans tâche : l'équipe travaille, pas d'entrée")
local st5 = run({ short = {}, workers = 15, idle = 15, starved = true }, { 0, F, 3 * F })
check(not st5.on, "aucun manque : pas d'entrée, même avec tous les PNJ sans tâche")
local st6 = run({ short = SHORT, workers = 0, idle = 0, starved = true }, { 0, F })
check(not st6.on, "aucun PNJ : pas d'entrée")
-- le manque interrompu repart de zéro
do
  local st = Sv.new()
  Sv.decide(st, { tick = 0, short = SHORT, workers = 15, idle = 14, starved = true })
  Sv.decide(st, { tick = F - 10, short = {}, workers = 15, idle = 14, starved = true })
  local d = Sv.decide(st, { tick = F, short = SHORT, workers = 15, idle = 14, starved = true })
  check(not st.on and d.event == nil, "un manque interrompu repart de zéro (durée CONTINUE)")
end
-- sortie : inchangée (fin de la pénurie, hystérésis)
do
  local st = Sv.new()
  Sv.decide(st, { tick = 0, short = SHORT, workers = 15, idle = 14, starved = true })
  Sv.decide(st, { tick = F, short = SHORT, workers = 15, idle = 14, starved = true })
  check(st.on, "entrée (préparation de la sortie)")
  Sv.decide(st, { tick = F + 100, short = {}, workers = 15, idle = 0 })
  check(st.on, "la fin du manque ne fait pas sortir aussitôt (hystérésis)")
  local d = Sv.decide(st, { tick = F + 100 + Sv.EXIT_TICKS + Sv.MIN_ON, short = {}, workers = 15, idle = 0 })
  check(not st.on and d.event == "sortie", "sortie après Sv.EXIT_TICKS sans manque")
end
-- la paralysie d'avant est intacte
check(not Sv.paralysed(Sv.new(), { workers = 8, idle = 8 }, 0), "Sv.paralysed inchangée : aucun refus, pas menacée, pas paralysée")
check(Sv.famine(Sv.new(), { workers = 8, idle = 8, starved = true }, 10 * F) == false, "Sv.famine sans manque daté : faux")
check(Sv.FAMINE_TICKS >= 2 * Sv.SHORT_TICKS, "la famine en paix attend au moins deux fois le manque durable de la porte")
-- déterminisme
do
  local a, b = run({ short = SHORT, workers = 15, idle = 14, starved = true }, { 0, F, 2 * F }), run({ short = SHORT, workers = 15, idle = 14, starved = true }, { 0, F, 2 * F })
  check(a.on == b.on and a.since == b.since and a.cause == b.cause and a.entries == b.entries, "déterminisme : deux passages, même état")
end

---------------------------------------------------------------------------------------------------
section("3. La chaîne lue dans les sources")
---------------------------------------------------------------------------------------------------
local glue = read_src("script/team/survie.lua")
check(glue:find("starved = starved", 1, true) ~= nil, "script/team/survie.lua passe `starved` à Sv.decide")
check(glue:find('kind = "mine", prio = Sv.PRIO', 1, true) ~= nil and glue:find("danger_radius = Sv.MINE_DANGER_RADIUS, survie = true", 1, true) ~= nil,
  "la tâche de minage du mode survie porte `survie = true` (lu par Mi.gone)")
local board = read_src("script/team/board.lua")
local _, n_gone = board:gsub("Mi%.gone%(", "")
check(n_gone >= 2, "script/team/board.lua : Board.sync et Board.add passent par Mi.gone")
-- mutant : sans l'exemption, le minage de survie sort (le fait observé dans la partie du DC)
do
  local function old_gone(t, era, dr) return era ~= nil and t.kind == "mine" and t.worker == nil and dr(t.resource) == true end
  check(old_gone({ kind = "mine", resource = ORE, survie = true }, 1000, drillable) ~= Mi.gone({ kind = "mine", resource = ORE, survie = true }, 1000, drillable),
    "mutant (règle d'avant) : refusé")
end

print(string.format("[S42-DIAG-JOUEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
