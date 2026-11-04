--[[
  Lot AZURE : trace [FO-CHANTIER-LENT] d'un chantier de bande qui n'avance plus (shared/team/chantier_lent.lua ; exécutant
  script/team/chantier_lent.lua ; vue du tableau Board.stall_view). Lancement : lua5.2 tests/chantier_lent_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local okc, fail = 0, 0
local function check(c, msg) if c then okc = okc + 1 else fail = fail + 1; print("ECHEC : " .. msg) end end
local function read(p) local h = assert(io.open(p, "r")); local s = h:read("*a"); h:close(); return s end

local function run(C)
  local r = {}
  -- 1. roles : seules les pieces ni posees ni sautees ni abandonnees comptent, groupees par role, tri n puis role
  local ents = {
    { role = "champ-tapis", built = false, fails = 0 }, { role = "champ-tapis", built = false, fails = 2, why = "occupe" },
    { role = "champ-tapis", built = true }, { role = "champ-charbon", built = false, fails = 1, why = "obstacle" },
    { role = "champ-charbon", built = false, fails = 0 }, { role = "champ-bras", built = false, skipped = "tourelle" },
    { role = "champ-poteau", built = false, dropped = true }, { role = "champ-four", built = false, fails = 1, why = "obstacle" },
    { built = false },
  }
  local g = C.roles(ents)
  r.c1 = #g == 4 and g[1].role == "champ-charbon" and g[1].n == 2 and g[1].failed == 1 and g[2].role == "champ-tapis" and g[2].n == 2
    and g[2].failed == 1 and g[3].role == "?" and g[4].role == "champ-four" and g[2].why.occupe == 1
  -- 2. motifs totaux : somme sur les roles, tri n decroissant puis motif
  local w = C.whys(g)
  r.c2 = #w == 2 and w[1][1] == "obstacle" and w[1][2] == 2 and w[2][1] == "occupe" and w[2][2] == 1
  -- 3. raison de non-prise : l'ordre des causes
  r.c3 = C.reason({ worker = 4 }) == "prise" and C.reason({ pause = 600, path_n = 3, prenable = false, hinted = true, rank = 1 }) == "pause apres echec"
    and C.reason({ path_n = 2, prenable = false, hinted = true, rank = 1 }) == "chemin rate x2"
    and C.reason({ prenable = false, hinted = true, rank = 1 }) == "matiere non libre"
    and C.reason({ hinted = true, rank = 1 }) == "indiquee a un autre PNJ"
    and C.reason({ rank = 1 }) == "en tete (prise imminente)" and C.reason({ rank = 61 }) == "derriere 60" and C.reason({}) == "hors marche"
  -- 4. prenable nil (tache sans matiere stricte) n'est pas une matiere manquante
  r.c4 = C.reason({ prenable = nil, rank = 3 }) == "derriere 2"
  -- 5. kv : tri n decroissant puis cle, plafond
  local kv = C.kv({ b = 2, a = 2, c = 5, d = 1 }, 3)
  r.c5 = #kv == 3 and kv[1] == "c 5" and kv[2] == "a 2" and kv[3] == "b 2"
  -- 6. ligne : forme complete et plafonds
  local tasks = {}
  for i = 1, 9 do tasks[i] = { kind = "ghost", prio = 82, age_min = 40 + i, rank = 60 + i, of = 98, reason = "derriere " .. (59 + i) } end
  local roles = {}
  for i = 1, 11 do roles[i] = { role = "r" .. string.format("%02d", i), n = 20 - i, failed = 0, why = {} } end
  local line = C.line({ team = "azure", pid = 7, band = 295, state = "chantier", minute = 60.8, cause = "chantier", stall_min = 10, built = 246, total = 575,
    roles = roles, tasks = tasks, tasks_n = 35, oldest_min = 49, ahead = { "craft:90", "mine:71", "craft:85", "carry:61", "x:1", "y:2", "z:3" },
    busy = { ["craft:85"] = 3, ["mine:71"] = 2 }, fails = { danger = 12, chemin = 3 } })
  r.c6 = line:find("^%[FO%-CHANTIER%-LENT%] azure : projet 7 %(bande 295, etat chantier%) a 60%.8 min, sans progres depuis 10 min %(chantier%), 246 entite%(s%) baties sur 575") ~= nil
    and line:find("non posees par role {r01 19 (0 refusee(s)),", 1, true) ~= nil and line:find(", ...}", 1, true) ~= nil and line:find("r09", 1, true) == nil
    and line:find("taches libres du projet 35 (plus vieille 49.0 min)", 1, true) ~= nil and line:find("ghost:82 41.0 min rang 61/98 derriere 60", 1, true) ~= nil
    and line:find("ghost:82 46.0 min rang 66/98", 1, true) ~= nil and line:find("rang 67/98", 1, true) == nil
    and line:find("en tete de file {craft:90, mine:71, craft:85, carry:61, x:1}", 1, true) ~= nil
    and line:find("PNJ occupes {craft:85 3, mine:71 2}", 1, true) ~= nil and line:find("echecs de l'equipe {danger 12, chemin 3}", 1, true) ~= nil
  -- 7. ligne avec raison d'etat et sans tache
  local l2 = C.line({ team = "t", pid = 1, band = 2, state = "bloque", reason = "x", cause = "c", roles = {}, tasks = {}, ahead = {}, busy = {}, fails = {} })
  r.c7 = l2:find("etat bloque/x)", 1, true) ~= nil and l2:find("non posees par role {}", 1, true) ~= nil and l2:find("taches libres du projet 0 (plus vieille 0.0 min) {}", 1, true) ~= nil
  -- 8. determinisme : l'ordre des entrees est sans effet
  local e2 = {}
  for i = #ents, 1, -1 do e2[#e2 + 1] = ents[i] end
  local a, b = C.roles(ents), C.roles(e2)
  local same = #a == #b
  for i = 1, #a do if a[i].role ~= b[i].role or a[i].n ~= b[i].n then same = false end end
  r.c8 = same
  r.c9 = C.LOGS == 12 and C.MAX_TASKS == 6 and C.MAX_ROLES == 8
  return r
end

local C = require("shared.team.chantier_lent")
local R = run(C)
for i = 1, 9 do check(R["c" .. i], "cas " .. i) end

-- branchement (lecture des sources)
local B = read("script/team/build.lua")
check(B:find('local ChantierLent = require("script.team.chantier_lent")', 1, true) ~= nil, "build.lua requiert le collecteur au chargement")
check(B:find("ChantierLent.report(f, p, tick, say, rec)", 1, true) ~= nil, "watch_stall appelle la trace")
check(B:find("e.why = tostring(why)", 1, true) ~= nil, "log_refusal garde le motif de la piece")
local S = read("script/team/chantier_lent.lua")
check(S:find("p.spec.champ", 1, true) ~= nil and S:find("Board.stall_view", 1, true) ~= nil and S:find("C.LOGS", 1, true) ~= nil, "collecteur : bandes seulement, vue du tableau, plafond")
local BD = read("script/team/board.lua")
check(BD:find("function Board.stall_view(f, prefix, tick)", 1, true) ~= nil and BD:find('M.order({ id = 0, role = "generalist" }, b.list, ctx)', 1, true) ~= nil, "Board.stall_view")
-- lecture seule : la vue n'ecrit rien dans le tableau (pas d'affectation a b.tasks / b.cooldown / t.worker)
local view = BD:match("function Board%.stall_view.-\nend\n") or ""
check(view ~= "" and not view:find("b%.tasks%[[^%]]+%]%s*=[^=]") and not view:find("b%.cooldown%[[^%]]+%]%s*=[^=]") and not view:find("%.worker%s*=[^=]"), "Board.stall_view : lecture seule")
check(S:find("global", 1, true) == nil, "le collecteur ne nomme pas global")

-- moteur simulé : la vraie vue du tableau et le vrai collecteur (une ligne par projet et par cause, lecture seule)
do
  local M = require("tests.mock_engine")
  local names, out = { "coal", "iron-ore", "copper-ore", "stone" }, {}
  for i = 0, 11 do local a = i * math.pi / 6; out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] } end
  M.new_game({ patches = out, p_busy = 0.01, p_nopath = 0.01, p_lost = 0, seed = 42 })
  local ch = game.surfaces[1].create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 }, { "pistol", 2 }, { "firearm-magazine", 40 },
    { "burner-mining-drill", 6 }, { "stone-furnace", 6 }, { "iron-chest", 4 } }) do ch.insert({ name = it[1], count = it[2] }) end
  M.world().events[defines.events.on_built_entity]({ created_entity = ch, player_index = 1, tick = game.tick })
  M.run_ticks(1200)
  local Board = require("script.team.board")
  local Cl = require("script.team.chantier_lent")
  local f = global.fo.pteam.team
  local before = {}
  for _, k in ipairs(require("script.faction.state").sorted_keys(Board.get(f).tasks)) do before[#before + 1] = k .. ":" .. tostring(Board.get(f).tasks[k].worker) end
  local v = Board.stall_view(f, "", game.tick)
  check(#v.tasks > 0 and v.n >= #v.tasks and #v.ahead > 0 and v.tasks[1].rank ~= nil, "Board.stall_view : tâches libres classées au marché")
  local after = {}
  for _, k in ipairs(require("script.faction.state").sorted_keys(Board.get(f).tasks)) do after[#after + 1] = k .. ":" .. tostring(Board.get(f).tasks[k].worker) end
  check(table.concat(before, "|") == table.concat(after, "|"), "Board.stall_view ne change aucune tâche")
  f.build = f.build or {} -- (le plan directeur de l'équipe du joueur n'est pas posé dans ce scénario)
  local lines, old = {}, log
  log = function(s) lines[#lines + 1] = s end
  local p = { id = 3, state = "chantier", spec = { champ = { pr = 295 } },
    ents = { { role = "champ-tapis", built = false, fails = 1, why = "occupe" }, { role = "champ-four", built = true } } }
  local a = Cl.report(f, p, game.tick, "chantier", { since = game.tick - 36000 })
  local b = Cl.report(f, p, game.tick, "chantier", { since = game.tick - 36000 })
  local c = Cl.report(f, p, game.tick, "reserve:materiaux", { since = game.tick - 36000 })
  local d = Cl.report(f, { id = 4, state = "chantier", spec = {}, ents = {} }, game.tick, "chantier", {})
  log = old
  check(a == true and b == false and c == true and d == false and #lines == 2, "collecteur : une ligne par projet et par cause, bandes seulement")
  check(lines[1] and lines[1]:find("projet 3 (bande 295, etat chantier)", 1, true) and lines[1]:find("1 entite(s) baties sur 2", 1, true)
    and lines[1]:find("{champ-tapis 1 (1 refusee(s))}", 1, true) and lines[1]:find("refus {occupe 1}", 1, true), "collecteur : ligne lue au tableau réel")
  for i = 1, 14 do Cl.report(f, { id = 100 + i, state = "chantier", spec = { champ = { pr = i } }, ents = {} }, game.tick, "chantier", {}) end
  check(f.build.cl.logs == 12, "collecteur : douze lignes par équipe au plus")
end

-- mutants
local src = read("shared/team/chantier_lent.lua")
local muts = {
  { "sautee comptee", "if not e.built and not e.skipped and not e.dropped then", "if not e.built then" },
  { "refusee jamais comptee", "if (e.fails or 0) > 0 then g.failed", "if (e.fails or 0) > 99 then g.failed" },
  { "pause oubliee", 'if (t.pause or 0) > 0 then return "pause apres echec" end', "" },
  { "matiere nil comptee", "if t.prenable == false then", "if not t.prenable then" },
  { "rang 1 pas en tete", "if t.rank <= 1 then", "if t.rank <= 0 then" },
  { "tri roles par nom", "if a.n ~= b.n then return a.n > b.n end\n    return a.role < b.role", "return a.role < b.role" },
  { "plafond des taches", "if i > C.MAX_TASKS then break end", "if i > 99 then break end" },
  { "chemin apres matiere", 'if (t.path_n or 0) > 0 then return string.format("chemin rate x%d", t.path_n) end\n  if t.prenable == false then return "matiere non libre" end',
    'if t.prenable == false then return "matiere non libre" end\n  if (t.path_n or 0) > 0 then return string.format("chemin rate x%d", t.path_n) end' },
}
local caught = 0
for _, m in ipairs(muts) do
  local s2, n = src:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")), 1)
  assert(n == 1, "mutant introuvable : " .. m[1])
  local M = assert(load(s2))()
  local x = run(M)
  local all = true
  for i = 1, 9 do if not x["c" .. i] then all = false end end
  if not all then caught = caught + 1 else print("mutant survivant : " .. m[1]) end
end
check(caught == #muts, string.format("mutants refuses : %d sur %d", caught, #muts))

print(string.format("[CHANTIER-LENT] BILAN : %d OK, %d ECHEC(S)", okc, fail))
if fail > 0 then os.exit(1) end
