--[[
  Lot X10-S0 (7/11) : portées fines de mesure, SANS aucune décision changée. Critères écrits avant le code :
  fo-logs\2026-11-07_X10\S0_CRITERES.md.

  Partie du moteur simulé : 4 factions et votre équipe (coffre posé, guerre financée), pensée en étapes, plan directeur.
  - P2 : la même partie, profileur ÉTEINT puis en DÉTAIL : journal (hors lignes de mesure, comme perf3.py --decisions
    --sans-profileur) et global (hors l'espace « prof ») identiques.
  - P3 : en détail, à CHAQUE tick, toute portée (start, stop, fstart, fstop, et donc fwrap) se ferme sous son nom, au sommet de la
    pile, dans le tick où elle s'ouvre ; pile vide en fin de tick. Les portées nouvelles du lot vues au moins une fois (liste dite).
    Les compteurs (Profiler.fcount) arrivent dans la ligne [FO-PERF3-T].
  - P4 : mutants qui DOIVENT être vus : fstart sans fstop (P3), fermeture sous un autre nom (P3), fwrap qui avale sa valeur (P2).
  - P1 (deux appels, pas dans ce fichier) : `lua5.2 tests/x10_s0_test.lua digest <sortie>` sur x10-s0 et sur la base (profileur
    éteint) : les deux sorties doivent être IDENTIQUES (journal entier et global).

  Usage : lua5.2 tests/x10_s0_test.lua [minutes = 3]        (depuis la racine du mod ; environ 3 min)
          lua5.2 tests/x10_s0_test.lua digest <fichier> [minutes = 3]
]]
package.path = "./?.lua;" .. package.path
local DIGEST = arg[1] == "digest"
local minutes = tonumber(DIGEST and arg[3] or arg[1]) or 3
local M = require("tests.mock_engine")

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 print("OK     " .. msg) else fail_n = fail_n + 1 print("ECHEC : " .. msg) end
end

local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

--- Source d'un module, changée (mutant) : `subs` = { { ancien, nouveau }, ... }, chaque ancien présent UNE fois exactement.
local function mutated(path, subs)
  local fh = assert(io.open(path, "rb"))
  local src = fh:read("*a")
  fh:close()
  for _, s in ipairs(subs) do
    local a, b = src:find(s[1], 1, true)
    assert(a, "mutant : texte absent de " .. path .. " : " .. s[1])
    assert(not src:find(s[1], b + 1, true), "mutant : texte présent plusieurs fois dans " .. path .. " : " .. s[1])
    src = src:sub(1, a - 1) .. s[2] .. src:sub(b + 1)
  end
  return src
end

local MUTANTS = {
  sans_fermeture = { "script.team.build", "script/team/build.lua", { { 'Profiler.fstop("e2:rues")', '' } } },
  autre_nom = { "script.team.build", "script/team/build.lua", { { 'Profiler.fstop("e2:board")', 'Profiler.fstop("e2:bord")' } } },
  fwrap_avale = { "script.core.profiler", "script/core/profiler.lua", { { "  Profiler.fstop(name)\n  return r\nend",
    "  Profiler.fstop(name)\n  return nil\nend" } } },
}

-- Lignes de MESURE (absentes des décisions) : celles que perf3.py --decisions --sans-profileur retire.
local MESURE = { "[FO-PERF3-T]", "[FO-TRACE]", "[FO-CALIB]", "[FO-PERF3-DUMP]", "Profiler", "[FO-IA3K]", "[FO-ATTACK]", "[FO-TD]" }
local function decision_lines(logs)
  local out = {}
  for _, l in ipairs(logs) do
    local keep = true
    for _, m in ipairs(MESURE) do if l:find(m, 1, true) then keep = false break end end
    if keep then out[#out + 1] = l end
  end
  return out
end

-- Fermetures de portées jamais ouvertes, connues d'avant ce lot : script/team/build.lua (advance, état « plan ») ferme les quatre
-- parties du plan après un retour anticipé de plan_project, qu'elles aient été ouvertes ou non. Comptées à part, pas une faute.
local ORPHELINES_CONNUES = { ["build:plan:place"] = true, ["build:plan:feed"] = true, ["build:plan:power"] = true,
  ["build:plan:anchors"] = true }

--- Joue la partie. prof : nil (éteint) ou "detail". mutant : nom de MUTANTS ou nil. Rend { logs, glob, nest }.
local function play(prof, mins, mutant)
  for _, m in pairs(MUTANTS) do package.preload[m[1]] = nil end
  local mut = mutant and MUTANTS[mutant]
  if mut then
    local src = mutated(mut[2], mut[3])
    package.preload[mut[1]] = function(name) return assert(load(src, "=" .. mut[2]))(name) end
  end
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0, ia3e = true, capi = true })
  local W = M.world()
  for _, p in pairs(W.prototypes) do if p.has_flag == nil then p.has_flag = function() return false end end end
  W.settings["fo-recruit-idle-max"] = 60
  W.settings["fo-war-workers"] = 30
  local Team = require("script.team.team")
  local Profiler = require("script.core.profiler")
  Team.ETAPES = true
  assert(remote.call("factorio-overhaul", "war_start", 4, 100, nil, 320) == true)
  remote.call("factorio-overhaul", "war_fund", 3000)
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W.events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  -- Plan directeur de toutes les équipes, comme dans la partie du DC (même montage que tests/decoupage_pensee_test.lua)
  local Build = require("script.team.build")
  local State = require("script.faction.state")
  M.run_ticks(120)
  local all = {}
  for _, id in ipairs(State.alive()) do all[#all + 1] = State.faction(id) end
  all[#all + 1] = State.faction("player")
  for _, f in ipairs(all) do
    if f and f.hq and f.hq.valid then
      Build.enable(f, { radius = 3 })
      Build.plant(f)
      Build.request(f, { gen = "gears", args = { 2, "assembling-machine-1" }, feed = true, prio = 60 })
      Build.request(f, { gen = "simple", args = { "iron-gear-wheel", 1, "assembling-machine-1" }, feed = true, prio = 55 })
    end
  end

  -- Imbrication (P3) : enveloppes posées sur la table du profileur (tous les modules l'appellent par cette table).
  local nest = { opened = 0, bad_close = 0, orphan = 0, orphan_known = 0, left = 0, seen = {}, first = nil, counters = 0,
    fwrap_calls = 0, fwrap_values = 0, fwrap_bad = 0 }
  local stack, cur = {}, -1
  local function tick_check()
    if game.tick ~= cur then
      if #stack > 0 then
        nest.left = nest.left + #stack
        nest.first = nest.first or ("tick " .. cur .. " : laissée(s) ouverte(s) : " .. table.concat(stack, ", "))
      end
      stack, cur = {}, game.tick
    end
  end
  local function open(name)
    tick_check()
    nest.opened = nest.opened + 1
    nest.seen[name] = true
    stack[#stack + 1] = name
  end
  local function close(name)
    tick_check()
    if stack[#stack] == name then
      stack[#stack] = nil
      return
    end
    for i = #stack, 1, -1 do
      if stack[i] == name then
        nest.bad_close = nest.bad_close + 1
        nest.first = nest.first or ("tick " .. game.tick .. " : " .. name .. " fermée sous " .. tostring(stack[#stack]))
        for k = #stack, i, -1 do stack[k] = nil end
        return
      end
    end
    if ORPHELINES_CONNUES[name] then nest.orphan_known = nest.orphan_known + 1 else
      nest.orphan = nest.orphan + 1
      nest.first = nest.first or ("tick " .. game.tick .. " : " .. name .. " fermée sans être ouverte")
    end
  end
  if prof == "detail" then
    local o_start, o_stop, o_fstart, o_fstop = Profiler.start, Profiler.stop, Profiler.fstart, Profiler.fstop
    Profiler.start = function(name, ...)
      local p = global.fo.prof
      if p and p.enabled then open(name) end
      return o_start(name, ...)
    end
    Profiler.stop = function(name, ...)
      local p = global.fo.prof
      if p and p.enabled then close(name) end
      return o_stop(name, ...)
    end
    Profiler.fstart = function(name, ...)
      if Profiler.fine() then open(name) end
      return o_fstart(name, ...)
    end
    Profiler.fstop = function(name, ...)
      if Profiler.fine() then close(name) end
      return o_fstop(name, ...)
    end
    -- fwrap TRANSPARENT : il rend exactement ce que rend la fonction enveloppée (espion appelé à sa place : la fonction n'est appelée
    -- qu'une fois, comme sans l'enveloppe ; rien d'autre ne change). Ajout du 7/11, 18 h 40 : P2 seul ne voyait pas le mutant
    -- « fwrap avale sa valeur » en 2 min de partie simulée (fo-logs/2026-11-07_X10/S0_CRITERES.md §3, P4).
    local o_fwrap = Profiler.fwrap
    Profiler.fwrap = function(name, fn, ...)
      local inner
      local r = o_fwrap(name, function(...) inner = fn(...) return inner end, ...)
      nest.fwrap_calls = nest.fwrap_calls + 1
      if inner ~= nil then nest.fwrap_values = nest.fwrap_values + 1 end
      if r ~= inner then
        nest.fwrap_bad = nest.fwrap_bad + 1
        nest.first = nest.first or ("tick " .. game.tick .. " : fwrap " .. name .. " rend " .. tostring(r) .. " au lieu de " .. tostring(inner))
      end
      return r
    end
    Profiler.set_enabled(true, game.tick, "detail")
  end

  local total = mins * 3600
  if prof == "detail" then
    for _ = 1, total do M.run_ticks(1) end
    if #stack > 0 then -- (dernier tick : pile vide attendue)
      nest.left = nest.left + #stack
      nest.first = nest.first or ("fin : laissée(s) ouverte(s) : " .. table.concat(stack, ", "))
    end
  else
    for _ = 1, total / 60 do M.run_ticks(60) end
  end
  for _, l in ipairs(W.logs) do
    if l:find("[FO-PERF3-T]", 1, true) and l:find(" #stock:", 1, true) then nest.counters = nest.counters + 1 end
  end
  -- Hors global : l'espace « prof » (le profileur lui-même) et les cumuls de mesure b.miss du tableau, écrits seulement profileur
  -- allumé et lus par le bilan [FO-PRISE-VIDE] (script/team/board.lua:622, lot DANGER-ACTIF, avant ce lot).
  local saved_prof = global.fo.prof
  global.fo.prof = nil
  local misses = {}
  for _, f in ipairs(all) do
    local bd = f and f.team and f.team.board
    if bd then misses[#misses + 1] = { bd, bd.miss }; bd.miss = nil end
  end
  local glob = M.serialize(global)
  global.fo.prof = saved_prof
  for _, m in ipairs(misses) do m[1].miss = m[2] end
  local St = package.loaded["script.team.stock"]
  local ec = St and St.engine_calls or {}
  return { logs = W.logs, glob = glob, nest = nest, ec = { count = ec.count or 0, contents = ec.contents or 0, annexes = ec.annexes or 0 } }
end

local function first_diff(a, b)
  for i = 1, math.max(#a, #b) do
    if a[i] ~= b[i] then return string.format("ligne %d : [%s] / [%s]", i, tostring(a[i]):sub(1, 160), tostring(b[i]):sub(1, 160)) end
  end
  return nil
end

if DIGEST then
  local r = play(nil, minutes)
  local fh = assert(io.open(arg[2], "wb"))
  fh:write(table.concat(r.logs, "\n"), "\n=== GLOBAL ===\n", r.glob, "\n")
  fh:close()
  print(string.format("[X10-S0] empreinte écrite : %s (%d ligne(s) de journal, global %d octets)", arg[2], #r.logs, #r.glob))
  os.exit(0)
end

local t0 = os.clock()
local det = play("detail", minutes)
local off = play(nil, minutes)
print(string.format("[X10-S0] parties de %d min : détail %d ligne(s) de journal, éteint %d (%.0f s)", minutes, #det.logs, #off.logs,
  os.clock() - t0))

-- P2 : décisions égales
local dl, ol = decision_lines(det.logs), decision_lines(off.logs)
local d1 = first_diff(dl, ol)
if d1 then print("   premier écart : " .. d1) end
check(#ol > 100 and d1 == nil, string.format("P2 : journal des décisions identique, détail contre éteint (%d ligne(s))", #ol))
check(det.glob == off.glob, "P2 : global identique (hors « prof »), détail contre éteint")

-- P3 : imbrication
local n = det.nest
print(string.format("[X10-S0] portées : %d ouvertures, %d fermeture(s) hors du sommet, %d orpheline(s), %d orpheline(s) connue(s), %d laissée(s) ouverte(s)",
  n.opened, n.bad_close, n.orphan, n.orphan_known, n.left))
if n.first then print("   premier défaut : " .. n.first) end
check(n.opened > 1000, "P3 : des portées ouvertes en mode détail (" .. n.opened .. ")")
check(n.bad_close == 0 and n.orphan == 0 and n.left == 0, "P3 : chaque portée se ferme sous son nom, au sommet de la pile, dans son tick")
check(n.counters > 0, "P3 : compteurs « #stock:... » dans les lignes [FO-PERF3-T] (" .. n.counters .. " ligne(s))")
check(det.ec.count > 0 and det.ec.contents > 0 and off.ec.count + off.ec.contents + off.ec.annexes == 0,
  string.format("P3 : Stock.engine_calls tenu au détail (get_item_count %d, get_inventory et get_contents %d, .valid des annexes %d), rien profileur éteint",
    det.ec.count, det.ec.contents, det.ec.annexes))
check(n.fwrap_values > 0 and n.fwrap_bad == 0, string.format("P3 : fwrap rend la valeur de la fonction enveloppée (%d appel(s), %d valeur(s) non nulle(s), %d écart(s))",
  n.fwrap_calls, n.fwrap_values, n.fwrap_bad))
local NOUVELLES = {
  "bp:p-attente", "bp:p-plan", "bp:p-reserve", "bp:p-defrichage", "bp:p-fantomes", "bp:p-chantier", "bp:p-raccordement", "bp:reprise",
  "e2:batch", "e2:quai", "e2:rues", "e2:board", "e2:conv", "e2:ligne", "e2:espace",
  "view:defchoix", "view:2-danger", "view:5-queue", "view:5-fours", "view:5-burn", "view:5-survieqg", "view:5-front", "view:5-garde",
  "view:5-ilots", "view:5-hqpost", "view:5-ironflow", "view:5-orphelins",
  "foswap:releve", "foswap:plan", "foswap:poses", "foswap:fab",
  "mig:rapport", "mig:melange", "mig:creneaux", "mig:balayage", "mig:depart",
  "recon:sweep", "recon:ruines", "recon:releve", "recon:poteaux", "recon:secours", "spares:secours", "spares:poteaux",
  "census:find", "census:idx", "census:bfs", "scan:find", "scan:liste", "scan:types", "scan:graines", "cov:find",
}
local seen, unseen = 0, {}
for _, nm in ipairs(NOUVELLES) do if n.seen[nm] then seen = seen + 1 else unseen[#unseen + 1] = nm end end
local per_handler = {}
for nm in pairs(n.seen) do if nm:find("@", 1, true) then per_handler[#per_handler + 1] = nm end end
table.sort(per_handler)
print(string.format("[X10-S0] portées nouvelles vues : %d sur %d ; non atteintes par la partie simulée : %s", seen, #NOUVELLES,
  #unseen > 0 and table.concat(unseen, ", ") or "aucune"))
print(string.format("[X10-S0] sous-portées par gestionnaire : %d (exemples : %s)", #per_handler,
  table.concat({ per_handler[1] or "-", per_handler[2] or "-", per_handler[3] or "-" }, ", ")))
local CORE = { "e2:rues", "e2:board", "e2:conv", "e2:ligne", "e2:espace", "view:5-queue", "view:5-front", "view:5-garde",
  "recon:sweep", "spares:secours" }
local core_ok = true
for _, nm in ipairs(CORE) do if not n.seen[nm] then core_ok = false end end
check(core_ok, "P3 : les portées du cœur (E2, fin de la vue, E3) sont toutes vues")
check(#per_handler >= 5, "P3 : sous-portées par gestionnaire d'événement vues (" .. #per_handler .. ")")

-- P4 : mutants
local mm = 1 -- (les trois mutants se voient dès la première minute)
local a = play("detail", mm, "sans_fermeture")
check(a.nest.left + a.nest.bad_close > 0, string.format("P4 : mutant « fstart sans fstop » vu (%d laissée(s), %d fermeture(s) hors du sommet)",
  a.nest.left, a.nest.bad_close))
local b = play("detail", mm, "autre_nom")
check(b.nest.orphan + b.nest.bad_close + b.nest.left > 0, string.format("P4 : mutant « fermée sous un autre nom » vu (%d orpheline(s), %d laissée(s))",
  b.nest.orphan, b.nest.left))
local okc, c = pcall(play, "detail", mm, "fwrap_avale")
check((not okc) or c.nest.fwrap_bad > 0, string.format("P4 : mutant « fwrap avale sa valeur » vu (%s)",
  (not okc) and ("la partie plante : " .. tostring(c):sub(1, 100)) or (c.nest.fwrap_bad .. " écart(s) de valeur rendue")))

-- P3 (compte double, ajout du 7/11 vers 19 h) : au détail, une fermeture SANS ouverture ne compte rien. Avant, elle ajoutait une seconde
-- fois la durée de la dernière ouverture fermée du même tick (build.lua ferme les quatre parties du plan après un retour anticipé :
-- 160 fois en 3 min de partie simulée). Instance NEUVE du profileur, chargée de la source du disque (ou mutée) ; les add comptés.
local function adds_of(src)
  local Storage = require("script.core.storage")
  local o_decl = Storage.declare
  Storage.declare = function() end -- l'espace « prof » existe déjà : l'instance neuve lit le même
  local P = assert(load(src, "=script/core/profiler.lua"))("script.core.profiler")
  Storage.declare = o_decl
  local orig = game.create_profiler
  local adds = 0
  game.create_profiler = function(...)
    local p = orig(...)
    p.add = function() adds = adds + 1 end
    return p
  end
  local ok, err = pcall(function()
    P.set_enabled(true, game.tick, "detail")
    P.start("x10:essai"); P.stop("x10:essai"); P.stop("x10:essai")
    P.fstart("x10:fin"); P.fstop("x10:fin"); P.fstop("x10:fin")
    P.set_enabled(false, game.tick)
  end)
  game.create_profiler = orig
  assert(ok, err)
  return adds
end
local prof_src = mutated("script/core/profiler.lua", {})
local n_ok = adds_of(prof_src)
check(n_ok == 2, "P3 : une fermeture sans ouverture ne compte rien au détail (" .. n_ok .. " ajout(s) pour 2 ouvertures, attendu 2)")
local n_mut = adds_of(mutated("script/core/profiler.lua", { { "  if not (m and DT.live[name]) then return end\n  DT.live[name] = nil\n",
  "  if not m then return end\n" } }))
check(n_mut ~= 2, "P4 : mutant « fermeture sans ouverture comptée » vu (" .. n_mut .. " ajout(s))")

print(string.format("[X10-S0] BILAN : %d OK%s", ok_n, fail_n > 0 and (", " .. fail_n .. " ECHEC(S)") or ""))
os.exit(fail_n == 0 and 0 or 1)
