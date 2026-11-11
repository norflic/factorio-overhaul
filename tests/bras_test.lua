--[[
  Tests hors jeu du lot RECHERCHE-BRAS : des bras simples, un débit bridé, le bras rapide ensuite.
  Usage :   lua5.2 tests/bras_test.lua

  Diagnostic (parties neuves 0.6.70 et 0.6.72, votre équipe) : « executant : recherche : fast-inserter » refusait les chaînes de câbles,
  circuits, engrenages et grenades de la minute 9 à 24-27, et le [FO-MALL] des blocs triviaux. Le gabarit choisissait chaque bras sur le
  débit NOMINAL de sa machine (shared/team/modules.lua, G.row) : copper-cable 4 bras rapides, electronic-circuit 8, iron-gear-wheel 4 ;
  or trois bras simples portent ~57 engrenages/min pour une demande de 0,2 à 0,6/min, et le bras rapide exige electronics (27 unités de
  packs faits à la main, 10 à 15 min de plus que nécessaire).

  1. Contexte de bras (M.current_arms, M.with_arms) : le gabarit est refait à la cadence que les bras permis tiennent ; M.check passe ;
     aucun bras rapide ; hors contexte, octet pour octet comme avant.
  2. Règle pure A.choose_arms (shared/ai3/automatiser.lua) : les bras obtenables lus au livre et au coffre, aucun nom écrit.
  3. A.template / A.sized / A.cost sous les bras obtenables ; repli à tous les bras quand les bras lents ne tiennent pas.
  4. Quai (Qd.plan) et branchement (sources de build.lua, capitalisation, automatisation, industrie).
  5. Mutants : chacun refait le défaut et doit faire échouer au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
end
local function section(name) if not quiet then print("== " .. name) end end
local function read_file(path) local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s end

local SMALL = "small-electric-pole"

local function counts(g)
  local c = {}
  for _, e in ipairs(g.entities) do c[e.name] = (c[e.name] or 0) + 1 end
  return c
end

local function out_total(g)
  local t = 0
  for k, v in pairs(g.nominal or {}) do if k ~= "electricity-kw" then t = t + v end end
  return t
end

--- Batterie sur les modules M (vrai ou mutant) et A (automatiser du même jeu).
local function battery(M, A, Qd)
  local slow = { "inserter" }
  local function gen(arms, name, ...)
    return M.with_arms(arms, M.with_pole, SMALL, M.GEN[name], ...)
  end
  section("1. Gabarits sous des bras simples")
  local cases = {
    { "gears", 1 }, { "gears", 3 }, { "circuits" }, { "simple", "copper-cable", 1 }, { "simple", "copper-cable", 2 },
    { "red_packs" }, { "green_packs" }, { "advanced_circuits" }, { "labs", 4, 30 },
  }
  local bridled = 0
  for _, c in ipairs(cases) do
    local name = table.remove(c, 1)
    local label = name .. " " .. table.concat((function() local o = {} for i, v in ipairs(c) do o[i] = tostring(v) end return o end)(), ",")
    local g0 = gen(nil, name, table.unpack(c))
    local g = gen(slow, name, table.unpack(c))
    check(g ~= nil, label .. " : gabarit aux seuls bras simples")
    if g then
      local chk = M.check(g)
      check(#chk == 0, label .. " : M.check vide (" .. tostring(chk[1]) .. ")")
      check((counts(g)["fast-inserter"] or 0) == 0, label .. " : aucun bras rapide")
      check(g.arms and g.arms[1] == "inserter" and #g.arms == 1, label .. " : le gabarit dit ses bras")
      local o0, o1 = out_total(g0), out_total(g)
      check(o1 <= o0 + 1e-9, label .. " : le débit ne dépasse pas le plein (" .. o1 .. " <= " .. o0 .. ")")
      check(o1 > 0.2 * o0 - 1e-9, label .. " : au moins la part minimale M.ARM_F_MIN du plein")
      if (counts(g0)["fast-inserter"] or 0) > 0 then
        bridled = bridled + 1
        check(o1 < o0 - 1e-6, label .. " : cadence BRIDÉE (" .. o1 .. " < " .. o0 .. ")")
        check(g.arm_f and g.arm_f < 1 and g.arm_f >= M.ARM_F_MIN, label .. " : arm_f dans [ARM_F_MIN, 1[")
      end
    end
  end
  check(bridled >= 4, "au moins quatre gabarits exigent le bras rapide au plein débit (" .. bridled .. ")")
  -- le cas du diagnostic : les engrenages tiennent largement la demande mesurée (0,6/min)
  local gg = gen(slow, "gears", 1)
  check(gg and (gg.nominal["iron-gear-wheel"] or 0) * 60 > 30, "engrenages aux bras simples : plus de 30/min (demande mesurée 0,6/min)")

  section("1 bis. Hors contexte, rien ne change")
  local a = M.with_pole(SMALL, M.GEN.gears, 3)
  local b = gen(nil, "gears", 3)
  local c2 = gen(M.ARMS, "gears", 3)
  check(M.serialize(a) == M.serialize(b), "bras nil : gabarit identique octet pour octet")
  check(c2 ~= nil and M.serialize(a) == M.serialize(c2) or (c2 ~= nil and c2.arms ~= nil), "tous les bras : même gabarit (hors le champ arms)")
  check(M.current_arms == nil and M.arm_f == 1 and M.arm_need == nil, "le contexte est rétabli")
  local ok = pcall(M.with_arms, slow, function() error("boum") end)
  check(not ok and M.current_arms == nil and M.arm_f == 1, "le contexte est rétabli même sur erreur")
  check(M.choose_inserters(0.5, false, 3) == "inserter" and M.choose_inserters(1.5, false, 1) == "fast-inserter", "hors contexte : choose_inserters comme avant")
  M.current_arms = slow
  check(M.choose_inserters(1.5, false, 1) == nil and select(2, M.choose_inserters(1.5, false, 3)) == 3, "sous contexte : seuls les bras simples, plus nombreux")
  M.current_arms = nil
  -- extension : le gabarit refait garde ses bras
  local g3 = gen(slow, "gears", 2)
  local ext = g3 and M.extend(g3, 3)
  check(ext ~= nil and ext.arms ~= nil and (counts(ext)["fast-inserter"] or 0) == 0 and #M.check(ext) == 0, "M.extend garde les bras du gabarit")
  -- bras trop lents : refus
  local keep = M.ARM_F_MIN
  M.ARM_F_MIN = 0.99
  local gtoo, why = gen(slow, "gears", 3)
  M.ARM_F_MIN = keep
  check(gtoo == nil and type(why) == "string" and why:find("bras", 1, true), "sous M.ARM_F_MIN : refus avec sa cause")

  section("2. A.choose_arms : les bras obtenables")
  local Book = require("shared.team.book")
  local recipes = dofile("tests/fixtures/recipes.lua")
  local locked = {}
  local book = Book.new(recipes, { allowed = function(n) return not locked[n] end })
  check(A.choose_arms(book, {}) == nil, "tous les bras fabricables : nil (rien à limiter)")
  locked["fast-inserter"] = true
  book = Book.new(recipes, { allowed = function(n) return not locked[n] end })
  local ar = A.choose_arms(book, {})
  check(ar and #ar == 1 and ar[1] == "inserter", "bras rapide fermé : le bras simple seul")
  check(A.choose_arms(book, { ["fast-inserter"] = A.ARM_STOCK }) == nil, "bras rapide au coffre en nombre : tous obtenables")
  local few = A.choose_arms(book, { ["fast-inserter"] = A.ARM_STOCK - 1 })
  check(few and #few == 1, "trop peu de bras rapides au coffre : comptent pour rien")
  locked["inserter"] = true
  book = Book.new(recipes, { allowed = function(n) return not locked[n] end })
  check(A.choose_arms(book, {}) == nil, "aucun bras obtenable : nil (rien ne se bâtit de toute façon)")
  locked["inserter"] = nil

  section("3. A.template, A.sized, A.cost")
  A.reset_cache()
  local meth = A.METHODS[3]
  local full = A.template(meth.gen, meth.args, SMALL)
  local lim = A.template(meth.gen, meth.args, SMALL, slow)
  check(full and (full.items["fast-inserter"] or 0) > 0, "A.template plein : le gabarit des engrenages exige des bras rapides")
  check(lim and (lim.items["fast-inserter"] or 0) == 0 and lim.arms ~= nil, "A.template aux bras simples : aucun bras rapide, résumé « arms »")
  check(lim and full and lim.nominal["iron-gear-wheel"] < full.nominal["iron-gear-wheel"], "le débit nominal du résumé est le débit bridé")
  local sized = A.sized(meth, 30, SMALL, slow)
  check(sized and (sized.items["fast-inserter"] or 0) == 0, "A.sized aux bras simples")
  local _, items = A.cost(meth, lim, { has_plant = true })
  check((items["fast-inserter"] or 0) == 0, "A.cost : aucun bras rapide, quai de sortie compris")
  local _, items0 = A.cost(meth, full, { has_plant = true })
  check((items0["fast-inserter"] or 0) > 0, "A.cost plein : le bras rapide compté comme avant")
  local fake = { items = {}, n_ent = 1, inputs = {}, nominal = { x = 5 }, power_kw = 0, arms = { "inserter" } }
  local _, itf = A.cost({ gen = "simple" }, fake, { has_plant = true })
  check((itf["fast-inserter"] or 0) == 0 and (itf["inserter"] or 0) >= 1, "A.cost : sortie 5/s aux bras simples = bras simples au quai")
  fake.arms = nil
  local _, itf0 = A.cost({ gen = "simple" }, fake, { has_plant = true })
  check((itf0["fast-inserter"] or 0) >= 1, "A.cost : sortie 5/s sans limite = bras rapide au quai")
  -- repli : bras trop lents pour le gabarit => tous les bras (le bras rapide est à rechercher)
  A.reset_cache()
  local keep2 = M.ARM_F_MIN
  M.ARM_F_MIN = 0.99
  local fb = A.template(meth.gen, meth.args, SMALL, slow)
  M.ARM_F_MIN = keep2
  check(fb and fb.arms == nil and (fb.items["fast-inserter"] or 0) > 0, "bras trop lents : repli au gabarit à tous les bras")
  A.reset_cache()

  section("4. Quai d'entrée (Qd)")
  local g = { inputs = { ["iron-plate"] = 1.5 }, ports = { { io = "in", kind = "tapis", lanes = { "iron-plate", "iron-plate" } } }, arms = slow }
  local arm = Qd.arm_for(M, 1.5, 3, slow)
  check(arm == "inserter", "Qd.arm_for : bras permis seuls")
  local arm2, n2 = Qd.arm_for(M, 12.0, 3, slow)
  check(arm2 == "inserter" and n2 == math.min(3, Qd.MAX_ARMS), "Qd.arm_for : trop de débit, le plus rapide des bras permis, au maximum")
  check(Qd.arm_for(M, 1.5, 3) == "fast-inserter", "Qd.arm_for sans limite : comme avant")
  local gb = gen(slow, "gears", 3)
  local pl = gb and Qd.plan(M, gb, nil)
  check(pl and pl.arm == "inserter", "Qd.plan d'un gabarit à bras simples : le quai n'exige pas le bras rapide (" .. tostring(pl and pl.arm) .. ")")
  local g0 = gen(nil, "gears", 3)
  local pl0 = Qd.plan(M, g0, nil)
  check(pl0.arm == "fast-inserter", "Qd.plan d'un gabarit complet : comme avant (" .. tostring(pl0.arm) .. ")")
end

local M0 = require("shared.team.modules")
local A0 = require("shared.ai3.automatiser")
local Qd0 = require("shared.team.quai_debit")
battery(M0, A0, Qd0)

---------------------------------------------------------------------------------------------------
-- 5. Branchement (sources)
---------------------------------------------------------------------------------------------------
local build_src = read_file("script/team/build.lua")
local capi_src = read_file("script/ai3/capitalisation.lua")
local auto_src = read_file("script/ai3/automatisation.lua")
local ind_src = read_file("script/ai3/industrie.lua")
local function has(src, text) return src:find(text, 1, true) ~= nil end
local function wiring(bs, cs, as_, is_)
  section("5. Branchement")
  check(has(bs, "M.with_arms(spec.arms, M.with_pole, spec.pole, fn, table.unpack(args))"), "build.lua template_of : le gabarit se refait sous spec.arms")
  check(has(bs, "M.choose_inserters(per, true, cmax, g.arms)"), "build.lua out_arms : le bras du quai de sortie suit g.arms")
  check(has(cs, "local arms = A.choose_arms(book, stock)") and has(cs, "A.sized(meth, rate, pole, arms)") and has(cs, "A.template(meth.gen, a2, pole, arms)"),
    "capitalisation fit_module : bras obtenables")
  local n = 0
  for _ in cs:gmatch("pole = g%.pole, arms = g%.arms,") do n = n + 1 end
  check(n == 3, "capitalisation : les trois demandes de module portent arms (" .. n .. ")")
  check(has(as_, "arms = A.choose_arms(book, stock)") and has(as_, "pole = rq.pole, arms = rq.arms,"), "automatisation : décision et demande portent les bras")
  check(has(is_, "A.template(gen, args, pole, A.choose_arms(book, stock))") and has(is_, "arms = mod.arms,"), "industrie : patron et bloc portent les bras")
end
wiring(build_src, capi_src, auto_src, ind_src)

---------------------------------------------------------------------------------------------------
-- 6. Mutants
---------------------------------------------------------------------------------------------------
local function sub(src, a, b)
  local i, j = src:find(a, 1, true)
  assert(i, "mutant : repere absent : " .. a)
  return src:sub(1, i - 1) .. b .. src:sub(j + 1)
end
local function load_module(path, src, extra_preload)
  package.loaded[path] = nil
  local name = path:gsub("%.lua$", ""):gsub("/", ".")
  local fn = assert(load(src, "=" .. path))
  -- le module est chargé sous son nom pour que les require internes le retrouvent
  package.loaded[name] = nil
  local mod = fn()
  package.loaded[name] = mod
  return mod
end
local mod_src = read_file("shared/team/modules.lua")
local aut_src = read_file("shared/ai3/automatiser.lua")
local qd_src = read_file("shared/team/quai_debit.lua")

local mutants = {
  { "contexte ignoré : choose_inserters prend toujours tous les bras", "modules",
    sub(mod_src, "allow or M.current_arms or { \"inserter\", \"fast-inserter\" }", "allow or { \"inserter\", \"fast-inserter\" }") },
  { "pas de bridage : la cadence reste à 1", "modules",
    sub(mod_src, "    f = f * M.arm_need\n", "    f = f * 1\n") },
  { "machines non bridées : la cadence de la machine ignore M.arm_f", "modules",
    sub(mod_src, "local rate = m.rate * M.arm_f", "local rate = m.rate") },
  { "liaisons non bridées : le débit des liaisons ignore M.arm_f", "modules",
    -- (ILOTS-COLONNES, 073d7102 : la marge de la liaison vient de Bl.link, g.link.reach - 1, et non plus de g.rs.east)
    sub(mod_src, "side_pick(l.flow * M.arm_f, false, g.slots_n, g.link.reach - 1)", "side_pick(l.flow, false, g.slots_n, g.link.reach - 1)") },
  { "plus de tuile libre pour un poteau (bras jusqu'à la dernière tuile)", "modules",
    sub(mod_src, "g.slots_n = M.current_arms and math.max(1, mw - 1) or mw", "g.slots_n = mw") },
  { "plancher de cadence supprimé", "modules",
    sub(mod_src, "if f < M.ARM_F_MIN then", "if false then") },
  { "le contexte n'est pas rétabli", "modules",
    sub(mod_src, "  M.current_arms, M.arm_f, M.arm_need = pa, pf, pn\n  if not res[1]", "  if not res[1]") },
  { "le gabarit ne dit pas ses bras (une extension les perd)", "modules",
    sub(mod_src, "    g.arms = copy(M.current_arms)\n", "") },
  { "regenerate perd les bras", "modules",
    sub(mod_src, "M.with_arms(g.arms, M.with_pole,", "M.with_arms(nil, M.with_pole,") },
  { "A.choose_arms : toujours nil", "auto",
    sub(aut_src, "if #ok == 0 or #ok == #M.ARMS then return nil end", "do return nil end") },
  { "A.choose_arms : coffre ignoré", "auto",
    sub(aut_src, "(stock[name] or 0) >= A.ARM_STOCK or book:handcraftable(name)", "book:handcraftable(name)") },
  { "A.template ignore les bras", "auto",
    sub(aut_src, "M.with_arms(arms, M.with_pole, pole, fn, table.unpack(args))", "M.with_pole(pole, fn, table.unpack(args))") },
  { "A.cost compte toujours le bras rapide au quai", "auto",
    sub(aut_src, "outn / ports > A.QUAI_RATE and fast_ok and D.PARTS.fast_arm", "outn / ports > A.QUAI_RATE and D.PARTS.fast_arm") },
  { "pas de repli à tous les bras", "auto",
    sub(aut_src, "  if not g and arms then\n    -- lot RECHERCHE-BRAS : les bras obtenables ne tiennent pas", "  if false then\n    -- lot RECHERCHE-BRAS : les bras obtenables ne tiennent pas") },
  { "Qd ignore les bras du gabarit", "qd",
    sub(qd_src, "Qd.arm_for(M, top, max_arms, g.arms)", "Qd.arm_for(M, top, max_arms)") },
  { "build : out_arms ignore g.arms", "wiring",
    sub(build_src, "M.choose_inserters(per, true, cmax, g.arms)", "M.choose_inserters(per, true, cmax)") },
  { "build : template_of ignore spec.arms", "wiring",
    sub(build_src, "M.with_arms(spec.arms, M.with_pole, spec.pole, fn, table.unpack(args))", "M.with_pole(spec.pole, fn, table.unpack(args))") },
  { "capitalisation : la demande perd les bras", "wiring",
    sub(capi_src, "gain = 1, near = near, pole = g.pole, arms = g.arms,", "gain = 1, near = near, pole = g.pole,") },
  { "automatisation : la demande perd les bras", "wiring",
    sub(auto_src, "pole = rq.pole, arms = rq.arms,", "pole = rq.pole,") },
}
local refused = 0
local saved = { modules = package.loaded["shared.team.modules"], auto = package.loaded["shared.ai3.automatiser"], qd = package.loaded["shared.team.quai_debit"] }
for _, m in ipairs(mutants) do
  local before = failures
  quiet = true
  local ok = pcall(function()
    if m[2] == "wiring" then
      local bs, cs, as_ = build_src, capi_src, auto_src
      if m[1]:find("build :", 1, true) then bs = m[3] elseif m[1]:find("capitalisation", 1, true) then cs = m[3] else as_ = m[3] end
      wiring(bs, cs, as_, ind_src)
      return
    end
    -- modules chargés à neuf : un mutant de modules.lua recharge aussi l'automatiser et le quai qui le requièrent
    package.loaded["shared.team.modules"] = nil
    package.loaded["shared.ai3.automatiser"] = nil
    package.loaded["shared.team.quai_debit"] = nil
    local M, A, Qd
    if m[2] == "modules" then
      M = load_module("shared/team/modules.lua", m[3])
      A = dofile("shared/ai3/automatiser.lua")
      Qd = dofile("shared/team/quai_debit.lua")
    elseif m[2] == "auto" then
      M = require("shared.team.modules")
      A = load_module("shared/ai3/automatiser.lua", m[3])
      Qd = dofile("shared/team/quai_debit.lua")
    else
      M = require("shared.team.modules")
      A = dofile("shared/ai3/automatiser.lua")
      Qd = load_module("shared/team/quai_debit.lua", m[3])
    end
    battery(M, A, Qd)
  end)
  quiet = false
  local killed = (failures > before) or not ok
  failures = before
  if killed then refused = refused + 1; passes = passes + 1 else failures = failures + 1; print("  ECHEC : mutant SURVIVANT : " .. m[1]) end
end
package.loaded["shared.team.modules"], package.loaded["shared.ai3.automatiser"], package.loaded["shared.team.quai_debit"] =
  saved.modules, saved.auto, saved.qd
print(string.format("  mutants refuses : %d sur %d", refused, #mutants))

print(string.format("[BRAS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
