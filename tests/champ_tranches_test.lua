--[[
  Tests hors jeu du COÛT de Ch.plan (lot CHAMP-COUVERTURE, décision du lead du 7/11 : « voie des TRANCHES ») ; critères écrits AVANT le code :
    C1  équivalence : Ch.plan_job(spec) avancé par Ch.plan_step(job, budget) rend le plan IDENTIQUE à Ch.plan(spec) d'un bloc, pour tout
        budget, sur le corpus (tests/champ_formes.lua : 17 formes, géant, cadres réels ; bandes seules de 4 formes) ;
    C2  sérialisable : entre deux pas, le travail ne contient que tables, nombres, chaînes, booléens ; recopié à chaque pas (comme une
        sauvegarde puis un chargement), il rend le même plan ;
    C3  pas borné : budget en UNITÉS de travail, jamais en temps ; pire pas mesuré sous 8 ms (géant, pire forme) ; mesuré en
        INSTRUCTIONS de la machine Lua (debug.sethook : déterministe, insensible à la charge du PC), borné à 250 000 au budget
        Ch.STEP_BUDGET, et converti en temps à la cadence du PC (bloc du géant sans compteur, le plus court de 2 passages) ;
    C4  aucune décision changée : Ch.plan rend les empreintes de référence (tests/fixtures/champ_plans_ref.lua, commit 067a1bd3) ;
    C5  surcoût : total en tranches <= 1,3 x le bloc (en instructions) ;
    C6  mutants vus par C1 ou C2 (le vrai module rend la référence sur les mêmes essais).
  Usage, depuis la racine du mod :   lua5.2 tests/champ_tranches_test.lua [--court]
]]
package.path = "./?.lua;" .. package.path

local Ch = require("shared.team.champ")
local Fm = require("tests.champ_formes")
local Sr = require("tests.champ_plan_serial")
local REF = dofile("tests/fixtures/champ_plans_ref.lua")

local short = arg[1] == "--court"
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local ref_by = {}
for _, r in ipairs(REF) do ref_by[r.name] = r end
local QUICK = { ["disque r30"] = true, ["r30 + lacs aux deux bouts"] = true, ["joueur 271828182"] = true }

section("1. C4 : Ch.plan rend les empreintes de reference (067a1bd3)")
for _, cs in ipairs(Fm.corpus()) do
  if not short or QUICK[cs.name] then
    local r = ref_by[cs.name]
    local t0 = os.clock()
    local p, why = Ch.plan(cs.spec())
    local dt = os.clock() - t0
    local h, n, ne = Sr.print(p, why)
    check(r and h == r.hash and n == r.len, string.format("%s : empreinte %s (%d car., %d entites) = reference %s (%.2f s)", cs.name, h, n, ne,
      tostring(r and r.hash), dt))
    if r and #r.bands > 0 and p then
      local bad = 0
      for i, bd in ipairs(p.bands) do
        local fr = {}
        for k, v in pairs(p.frame) do fr[k] = v end
        fr.only = { [bd.pr] = true }
        local sp = cs.spec()
        sp.frame = fr
        local q, qwhy = Ch.plan(sp)
        local bh = Sr.print(q, qwhy)
        if not (r.bands[i] and r.bands[i].pr == bd.pr and r.bands[i].hash == bh) then bad = bad + 1 end
      end
      check(bad == 0 and #p.bands == #r.bands, string.format("%s : %d bandes seules, %d differentes de la reference", cs.name, #p.bands, bad))
    end
  end
end

-- outils des sections suivantes -------------------------------------------------------------------
--- Vrai si le travail ne contient que tables (sans métatable), nombres, chaînes, booléens ; sinon faux et le chemin fautif.
local function only_data(v, seen, path)
  local t = type(v)
  if t == "number" or t == "string" or t == "boolean" or t == "nil" then return true end
  if t ~= "table" then return false, path .. " (" .. t .. ")" end
  if getmetatable(v) ~= nil then return false, path .. " (metatable)" end
  if seen[v] then return true end
  seen[v] = true
  for k, x in pairs(v) do
    local tk = type(k)
    if tk ~= "number" and tk ~= "string" and tk ~= "boolean" then return false, path .. "[cle " .. tk .. "]" end
    local ok, where = only_data(x, seen, path .. "." .. tostring(k))
    if not ok then return false, where end
  end
  return true
end
--- Copie du GRAPHE (identités partagées gardées, comme la sauvegarde puis le chargement du jeu).
local function graph_copy(v, seen)
  if type(v) ~= "table" then return v end
  if seen[v] then return seen[v] end
  local out = {}
  seen[v] = out
  for k, x in pairs(v) do out[graph_copy(k, seen)] = graph_copy(x, seen) end
  return out
end
--- Plan en tranches : (plan, raison, pas, pire pas en s, total en s) ; opt.copy : travail recopié à chaque pas ; opt.check : contrôle C2
--- à chaque pas (rend aussi le premier défaut) ; opt.max : pas au plus (mutant qui ne finit pas).
local function stepped(M, spec, budget, opt)
  opt = opt or {}
  local J = M.plan_job(spec)
  local steps, worst, total, bad = 0, 0, 0, nil
  while true do
    local t0 = os.clock()
    local done = M.plan_step(J, budget)
    local dt = os.clock() - t0
    total, steps = total + dt, steps + 1
    if dt > worst then worst = dt end
    if done then break end
    if opt.check and not bad then
      local ok, where = only_data(J, {}, "job")
      if not ok then bad = where end
    end
    if opt.copy then J = graph_copy(J, {}) end
    if opt.max and steps >= opt.max then return nil, "trop de pas", steps, worst, total, bad end
  end
  return J.p, J.why, steps, worst, total, bad
end

section("2. C1 : tranches = bloc, pour tout budget")
do
  local SMALL = { ["disque r11"] = true, ["r12 + eau aux bouts, ouverture de 3"] = true }
  for _, cs in ipairs(Fm.corpus()) do
    if not short or QUICK[cs.name] then
      local r = ref_by[cs.name]
      local budgets = SMALL[cs.name] and { 1, 7, 64, 1000 } or { 64, 1000 }
      if cs.name == "geant 200 x 200" then budgets = { 1000 } end
      for _, B in ipairs(budgets) do
        local p, why, steps = stepped(Ch, cs.spec(), B)
        local h = Sr.print(p, why)
        check(r and h == r.hash, string.format("%s, budget %d : %d pas, empreinte %s = reference %s", cs.name, B, steps, h, tostring(r and r.hash)))
      end
    end
  end
end

section("3. C2 : le travail ne contient que des donnees ; recopie a chaque pas (sauvegarde puis chargement), meme plan")
do
  for _, it in ipairs({ { "disque r20", 64 }, { "r30 + lacs aux deux bouts", 400 }, { "joueur 271828182", 400 } }) do
    if not short or QUICK[it[1]] then
      local cs
      for _, x in ipairs(Fm.corpus()) do if x.name == it[1] then cs = x end end
      local p, why, steps, _, _, bad = stepped(Ch, cs.spec(), it[2], { check = true, copy = true })
      local h = Sr.print(p, why)
      check(bad == nil, string.format("%s, budget %d : %d pas, donnees seules (%s)", it[1], it[2], steps, tostring(bad or "aucun defaut")))
      check(h == ref_by[it[1]].hash, string.format("%s, budget %d, recopie a chaque pas : empreinte %s = reference %s", it[1], it[2], h, ref_by[it[1]].hash))
    end
  end
end

-- comptes en INSTRUCTIONS de la machine Lua (debug.sethook, toutes les 1 000 instructions) : déterministes, insensibles à la charge du PC
local KI = 1000
--- Plan en tranches compté : (plan, raison, pas, pire pas en ki, total en ki, étage du pire pas).
local function counted_steps(M, spec, budget)
  local cnt = 0
  local J = M.plan_job(spec)
  local steps, worst, total, wat = 0, 0, 0, "?"
  debug.sethook(function() cnt = cnt + 1 end, "", KI)
  while true do
    local top = J.stack[#J.stack]
    local where = top.fn .. ":" .. tostring(top.pc)
    local c0 = cnt
    local done = M.plan_step(J, budget)
    local di = cnt - c0
    steps, total = steps + 1, total + di
    if di > worst then worst, wat = di, where end
    if done then break end
  end
  debug.sethook()
  return J.p, J.why, steps, worst, total, wat
end
--- Plan d'un bloc compté : (ki, plan, raison).
local function counted_block(M, spec)
  local cnt = 0
  debug.sethook(function() cnt = cnt + 1 end, "", KI)
  local p, why = M.plan(spec)
  debug.sethook()
  return cnt, p, why
end

local C3_KI, C3_MS, C5_MAX = 250, 8, 1.3
section(string.format("4. C3 et C5 : budget Ch.STEP_BUDGET = %d ; pire pas <= %d ki (instructions Lua) et < %d ms a la cadence de ce PC ; total <= %.1f x le bloc",
  Ch.STEP_BUDGET, C3_KI, C3_MS, C5_MAX))
do
  local by = {}
  for _, cs in ipairs(Fm.corpus()) do by[cs.name] = cs end
  -- cadence du PC : le bloc du géant SANS compteur, le plus court de 2 passages, rapporté à ses instructions comptées
  local geant = by["geant 200 x 200"]
  local gki = counted_block(Ch, geant.spec())
  local tmin = math.huge
  for _ = 1, 2 do
    local t0 = os.clock()
    Ch.plan(geant.spec())
    tmin = math.min(tmin, os.clock() - t0)
  end
  local ns = 1e9 * tmin / (gki * KI)
  print(string.format("  cadence : %.1f ns par instruction (geant d'un bloc : %.2f s, %d ki)", ns, tmin, gki))
  local names = { "geant 200 x 200", "r30 + eau aux bouts, ouverture de 5" }
  if not short then
    names = {}
    for _, cs in ipairs(Fm.corpus()) do names[#names + 1] = cs.name end
  end
  local worst_all, wname = 0, "?"
  for _, name in ipairs(names) do
    local cs = by[name]
    local p, why, steps, worst, total, wat = counted_steps(Ch, cs.spec(), Ch.STEP_BUDGET)
    local blk = counted_block(Ch, cs.spec())
    local h = Sr.print(p, why)
    local ms = worst * KI * ns / 1e6
    check(h == ref_by[name].hash and worst <= C3_KI and ms < C3_MS, string.format("%s : %d pas, pire pas %d ki (%s), %.1f ms, plan = reference : %s",
      name, steps, worst, wat, ms, tostring(h == ref_by[name].hash)))
    check(total <= C5_MAX * blk, string.format("%s : total en tranches %d ki = %.3f x le bloc (%d ki)", name, total, total / blk, blk))
    print(string.format("  %-42s %5d pas, pire %3d ki (%-8s) %4.1f ms, total x%.3f", name, steps, worst, wat, ms, total / blk))
    if worst > worst_all then worst_all, wname = worst, name end
  end
  print(string.format("  pire pas du corpus mesure : %d ki (%s), %.1f ms", worst_all, wname, worst_all * KI * ns / 1e6))
end

-- relais entre réseaux de poteaux : la machine reprenable (Ch.bridge_new / Ch.bridge_run) contre les passes de 067a1bd3, refaites de
-- zéro à chaque relais (tests/fixtures/champ_bridge_ref.lua), sur des cas tirés au hasard (graine fixe) : le corpus n'a qu'un relais
local REFB = dofile("tests/fixtures/champ_bridge_ref.lua")(Ch)
local function bridge_cases()
  local seed = 20261107
  local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end
  local cases = {}
  for ci = 1, 40 do
    local wire = ({ 7.5, 9, 5, 7.5 })[ci % 4 + 1]
    local blocked = {}
    for _ = 1, 1 + rnd(4) do
      local u0, v0 = rnd(70), rnd(70)
      for u = u0, u0 + rnd(12) do for v = v0, v0 + rnd(12) do blocked[Ch.key(u, v)] = true end end
    end
    local poles = {}
    for _ = 1, 2 + rnd(4) do
      -- un réseau : une rangée ou une colonne de poteaux à portée les uns des autres
      local u, v, du, dv = rnd(80), rnd(80), 0, 0
      if rnd(2) == 0 then du = 1 else dv = 1 end
      for _ = 1, 1 + rnd(6) do
        if not blocked[Ch.key(u, v)] then poles[#poles + 1] = { u, v } end
        local step = 2 + rnd(math.floor(wire) - 1)
        u, v = u + du * step, v + dv * step
      end
    end
    if #poles >= 2 then cases[#cases + 1] = { wire = wire, blocked = blocked, poles = poles } end
  end
  return cases
end
local function copy_poles(ps) local o = {}; for i, p in ipairs(ps) do o[i] = { p[1], p[2] } end return o end
local function ctx_for(cs)
  local taken = {}
  return { free = function(u, v) local k = Ch.key(u, v); return not taken[k] and not cs.blocked[k] end,
    take = function(u, v) taken[Ch.key(u, v)] = true end }
end
local function same_list(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i][1] ~= b[i][1] or a[i][2] ~= b[i][2] then return false end end
  return true
end
--- Relais de la machine du module M au budget B (nil : d'un coup), état recopié à chaque pas si copy ; (relais, poteaux).
local function bridge_machine(M, cs, multi, B, copy)
  local poles, c = copy_poles(cs.poles), ctx_for(cs)
  local st = M.bridge_new(multi)
  local spec = { pole = { wire = cs.wire } }
  local guard = 0
  while true do
    guard = guard + 1
    local J = B and { left = B } or nil
    if M.bridge_run(st, c, spec, poles, J) then break end
    if copy then st = graph_copy(st, {}) end
    if guard > 200000 then return nil, nil end
  end
  return st.added, poles
end
--- Vrai si la machine du module M rend les relais des passes d'avant sur tous les cas (budgets d'un coup, 0,5, 3, recopie comprise).
local function bridge_same(M, cases, stats)
  local all = true
  for _, cs in ipairs(cases) do
    for _, multi in ipairs({ false, true }) do
      local spec = { pole = { wire = cs.wire } }
      local p0, c0 = copy_poles(cs.poles), ctx_for(cs)
      local a0 = (multi and REFB.bridge or REFB.bridge_0641)(c0, spec, p0)
      if stats then stats.runs = stats.runs + 1; if #a0 > 0 then stats.with = stats.with + 1 end; stats.relays = stats.relays + #a0 end
      for _, bc in ipairs({ { nil, false }, { 0.5, false }, { 3, true } }) do
        local a1, p1 = bridge_machine(M, cs, multi, bc[1], bc[2])
        if not (a1 and same_list(a0, a1) and same_list(p0, p1)) then all = false end
      end
    end
  end
  return all
end

section("5. relais : machine reprenable = passes d'avant refaites de zero (067a1bd3), cas tires au hasard")
do
  local cases = bridge_cases()
  local stats = { runs = 0, with = 0, relays = 0 }
  local same = bridge_same(Ch, cases, stats)
  check(same, string.format("%d cas x 2 regles x 3 budgets : memes relais, memes poteaux", #cases))
  check(stats.with >= 20, string.format("cas qui posent des relais : %d sur %d (%d relais en tout)", stats.with, stats.runs, stats.relays))
  print(string.format("  %d cas, %d passages des regles d'avant, %d avec relais, %d relais", #cases, stats.runs, stats.with, stats.relays))
end

section("6. C6 : mutants du decoupage, vus par C1 (plan different, ou travail sans fin) ou C2 (fonction dans le travail)")
do
  local function src_of(path) local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s end
  local MODS = { { "shared.team.champ_colonne", "shared/team/champ_colonne.lua" }, { "shared.team.champ_couverture", "shared/team/champ_couverture.lua" },
    { "shared.team.champ", "shared/team/champ.lua" } }
  --- Module de plan rechargé avec UNE source mutée (les modules qui en dépendent rechargés aussi) ; nil si le motif est absent.
  local function mutant(file, pat, rep)
    local saved = {}
    for _, m in ipairs(MODS) do saved[m[1]] = package.loaded[m[1]] end
    local n_sub, M = 0, nil
    local ok, err = pcall(function()
      for _, m in ipairs(MODS) do
        local src = src_of(m[2])
        if m[2] == file then src, n_sub = src:gsub(pat, rep) end
        local mod = assert(load(src, "=" .. m[2] .. (m[2] == file and " (mutant)" or "")))()
        package.loaded[m[1]] = mod
        M = mod
      end
    end)
    for _, m in ipairs(MODS) do package.loaded[m[1]] = saved[m[1]] end
    if not ok then print("  chargement du mutant : " .. tostring(err)) return nil end
    if n_sub ~= 1 then return nil end
    return M
  end
  local by = {}
  for _, cs in ipairs(Fm.corpus()) do by[cs.name] = cs end
  --- Vrai si l'un des essais (forme, budget) ne rend pas le plan de référence (ou ne finit pas, ou plante).
  local function seen_c1(M, tries)
    for _, t in ipairs(tries) do
      local ok, p, why = pcall(stepped, M, by[t[1]].spec(), t[2], { max = 60000 })
      if not ok or not p then return true end
      if Sr.print(p, why) ~= ref_by[t[1]].hash then return true end
    end
    return false
  end
  local muts = {
    { "A* du trace repris de zero a chaque pas", "shared/team/champ_colonne.lua", "if not st%.open then", "if true then",
      { { "r30 + lacs aux deux bouts", 7 } } },
    { "choix de la phase : decalage en cours saute a la reprise", "shared/team/champ.lua", "scan%.o = scan%.o or 0", "scan.o = scan.o and (scan.o + 1) or 0",
      { { "disque r30", 7 }, { "joueur 271828182", 7 } } },
    { "choix de la phase : meilleure phase oubliee a la reprise", "shared/team/champ.lua", "local fr = scan%.frame and F or nil",
      "local fr = scan.frame and F or nil; bands = nil", { { "disque r30", 7 }, { "joueur 271828182", 64 } } },
    -- ligne de charbon : sommes cumulées gardées dans l'état (reprenables, une fois par orientation)
    { "ligne de charbon : sommes refaites a chaque pas (le defaut de la fusion avec la 0.6.58)", "shared/team/champ_colonne.lua",
      "if not sm or sm%.oi ~= st%.oi then", "if true then", { { "disque r30", 64 } } },
    { "ligne de charbon : sommes d'une orientation gardees pour l'autre", "shared/team/champ_colonne.lua",
      "if not sm or sm%.oi ~= st%.oi then", "if not sm then", { { "disque r30", 64 }, { "joueur 271828182", 64 } } },
  }
  -- les mêmes essais avec le VRAI module rendent la référence (sinon un mutant serait « vu » pour une autre raison)
  local done_try = {}
  for _, m in ipairs(muts) do
    for _, t in ipairs(m[5]) do
      local k = t[1] .. "|" .. t[2]
      if not done_try[k] then
        done_try[k] = true
        local p, why, steps = stepped(Ch, by[t[1]].spec(), t[2], { max = 60000 })
        check(p ~= nil and Sr.print(p, why) == ref_by[t[1]].hash, string.format("vrai module, %s, budget %d : %d pas, plan = reference", t[1], t[2], steps))
      end
    end
  end
  for _, m in ipairs(muts) do
    local M = mutant(m[2], m[3], m[4])
    check(M ~= nil and seen_c1(M, m[5]), "mutant vu par C1 : " .. m[1])
  end
  -- relais (le corpus n'en pose qu'un) : vus sur les cas tirés au hasard de la section 5
  do
    local M = mutant("shared/team/champ.lua", "local parent, grid = st%.parent, st%.grid", "st.grid = {}; local parent, grid = st.parent, st.grid")
    check(M ~= nil and not bridge_same(M, bridge_cases()), "mutant vu (section 5) : relais, grille des poteaux oubliee a la reprise")
    local M2 = mutant("shared/team/champ.lua", "if st%.si > #poles then st%.stage, st%.ci, st%.cand = 3, 1, {} end",
      "if st.si > #poles then st.stage, st.ci, st.cand = 3, 2, {} end")
    check(M2 ~= nil and not bridge_same(M2, bridge_cases()), "mutant vu (section 5) : relais, premier poteau du reseau principal saute")
  end
  -- C2 : une fonction gardée dans le travail (les fonctions du cadre « once » retenues entre deux pas)
  do
    local M = mutant("shared/team/champ.lua", "local function kit%(P%)\n  local _ENV = P\n  local K = {}", "local function kit(P)\n  local _ENV = P\n  local K = {}\n  P.kit_garde = K")
    local seen = false
    if M then
      local ok, _, _, _, _, _, bad = pcall(stepped, M, by["disque r20"].spec(), 64, { check = true })
      seen = (not ok) or bad ~= nil
    end
    check(M ~= nil and seen, "mutant vu par C2 : fonctions du cadre gardees dans le travail")
  end
end

print(string.format("[CHAMP-TRANCHES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
