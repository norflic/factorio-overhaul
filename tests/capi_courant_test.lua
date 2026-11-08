--[[
  Étape 5a de VIDEO-INTEG (RD_LOG F391 : input.power n'était jamais rempli en jeu) : le courant des centrales finies arrive à la décision
  de la capitalisation, au moteur simulé (tests/mock_engine.lua). Le mock n'a ni centrale ni plan directeur pour les factions : pour la
  faction 1, la vraie Capi.power_input reçoit un relevé de PA.watch (capacité 1 500 J/tick) et une centrale « fini » posés par le banc.
    §1 faction 1 : l'entrée de Ca.decide_begin porte input.power = { have_kw = 90 (1 500 J/tick × 60 / 1000), used_kw = 36 (600 J/tick
       mesurés + 0,6 × les chantiers, vue de la porte du plan directeur) }, plant absent ; une ligne [FO-CAPI-KW] « capacite 90 kW » ;
    §2 faction 2 (témoin, aucune centrale) : input.power absent, aucune ligne [FO-CAPI-KW] ;
    §3 mutant (Capi.MUT.sans_courant) : §1 échoue.
  Ce n'est pas une preuve en jeu. Usage : lua5.2 tests/capi_courant_test.lua   (depuis la racine du mod ; environ 30 s)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[CAPI-COURANT] ECHEC : " .. msg) end
end
local function say(s) print("[CAPI-COURANT] " .. s) end
local function W() return M.world() end
local MIN = 3600

-- Gisements larges, comme tests/capi_moteur_test.lua.
local function patches()
  local out = {}
  local d = 0.7071
  local corners = { { d, -d }, { d, d }, { -d, d }, { -d, -d } }
  local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
    { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
  for _, c in ipairs(corners) do
    local hx, hy = c[1] * 320, c[2] * 320
    local names = { "coal", "iron-ore", "copper-ore", "stone" }
    for ri, r in ipairs({ 40, 64, 88 }) do
      for di, v in ipairs(dirs) do
        out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] }
      end
    end
  end
  return out
end

local function count(text)
  local n = 0
  for _, l in ipairs(W().logs) do if l:find(text, 1, true) then n = n + 1 end end
  return n
end

local function run(mutant)
  M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
  M.load_mod()
  local Ca = package.loaded["shared.ai3.capitalisation"]
  local Capi = package.loaded["script.ai3.capitalisation"]
  local out = { p1 = 0, p1_ok = 0, p2 = 0, d1 = 0, d2 = 0, ok = true }
  local f1, f2 = nil, nil
  local begin = Ca.decide_begin
  Ca.decide_begin = function(input, st)
    -- la décision de la faction 1 : celle dont l'entrée lit le relevé posé par le banc (aucune autre n'a de courant)
    if input.power ~= nil then
      out.p1 = out.p1 + 1
      if input.power.have_kw == 90 and math.abs((input.power.used_kw or -1) - 36) < 1e-9 and input.power.plant == nil then
        out.p1_ok = out.p1_ok + 1
      end
    end
    return begin(input, st)
  end
  -- Le mock n'a ni centrale ni plan directeur pour les factions (f.build reste nil) : pour la faction 1, la VRAIE Capi.power_input lit
  -- un relevé de PA.watch (1 500 J/tick) et une centrale « fini » posés ici ; les autres équipes passent telles quelles.
  local power_input = Capi.power_input
  -- relevé de PA.watch : capacité 1 500 J/tick (90 kW), 600 J/tick produits (36 kW) ; un consommateur en chantier de 500 kW (porte :
  -- admis, pas fini) pour le cas `chantier`
  local function fake(cap, works)
    local b = { order = {}, projects = {}, grow = { capacity = cap, power = 600 } }
    if works then
      b.order[1] = 7
      b.projects[7] = { id = 7, state = "chantier", admitted = true, power_kw = 500, ents = {} }
    end
    return { key = "banc", build = b }
  end
  local P = function(cap, state, works) return power_input(fake(cap, works), state) end
  local u90, uw = P(1500, "fini"), P(1500, "fini", true)
  out.unit = u90 ~= nil and u90.have_kw == 90 and math.abs((u90.used_kw or -1) - 36) < 1e-9 and u90.plant == nil
    and uw ~= nil and math.abs((uw.used_kw or -1) - (36 + 0.6 * 500)) < 1e-9
    and P(1500, "chantier") == nil
    -- lot VIDEO-COUVERTURE 5 (W02) : centrale finie mais capacité NON LUE (texte, rien) = relevé vide, la garde de la règle se ferme
    and type(P("x", "fini")) == "table" and next(P("x", "fini")) == nil and type(power_input({}, "fini")) == "table" and next(power_input({}, "fini")) == nil
  -- lot 5b : capacité ≤ 0 (centrale finie, plus de machine à vapeur) = relevé vide, comme une capacité non lue ; mutant : l'ancien nil
  local z, neg = P(0, "fini"), P(-5, "fini")
  Capi.MUT.cap_ouvert = true
  local zm = P(0, "fini")
  Capi.MUT.cap_ouvert = nil
  out.cap0 = type(z) == "table" and next(z) == nil and type(neg) == "table" and next(neg) == nil and zm == nil
  out.unit_txt = string.format("used_kw %s, avec 500 kW en chantier %s", tostring(u90 and u90.used_kw), tostring(uw and uw.used_kw))
  Capi.power_input = function(f, plant_state)
    if f1 and f == f1 then return P(1500, "fini") end
    return power_input(f, plant_state)
  end
  if mutant then Capi.MUT.sans_courant = true end
  M.dispatch(W().on_init)
  M.command("fo-war", "start 2 30 30 320")
  local ok, err = pcall(M.run_ticks, 30)
  f1, f2 = global.fo.war.factions[1], global.fo.war.factions[2]
  out.k1, out.k2 = f1 and f1.key or "?", f2 and f2.key or "?"
  if ok then ok, err = pcall(M.run_ticks, 4 * MIN) end
  out.ok, out.err = ok, err
  out.kw1 = count("[FO-CAPI-KW] " .. out.k1 .. " : capacite 90 kW")
  out.kw2 = count("[FO-CAPI-KW] " .. out.k2 .. " :")
  local c1, c2 = f1 and f1.team and f1.team.capi, f2 and f2.team and f2.team.capi
  out.d1, out.d2 = c1 and c1.decisions or 0, c2 and c2.decisions or 0
  Ca.decide_begin = begin
  Capi.power_input = power_input
  Capi.MUT.sans_courant = nil
  return out
end

local function slurp(path) local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s end
local WIRED = slurp("script/ai3/capitalisation.lua"):find("power = Capi.power_input(f, plant_state),", 1, true) ~= nil

local function verdict(o, quiet)
  o.wired = WIRED
  local ok = {
    o.ok and o.unit and o.wired and o.cap0,
    o.p1 >= 2 and o.p1_ok == o.p1 and o.kw1 >= 2,
    o.d2 >= 2 and o.kw2 == 0,
  }
  local msgs = {
    string.format("partie sans erreur (%s) ; Capi.power_input : 90 kW pour 1 500 J/tick a une centrale finie, vue de la porte = mesure + 0,6 x chantiers (%s : %s), nil sinon (releve VIDE si la capacite est non lue ou <= 0 : %s) ; build_input la lit (%s)",
      tostring(o.err), tostring(o.unit), tostring(o.unit_txt), tostring(o.cap0), tostring(o.wired)),
    string.format("§1 faction %s : %d decision(s) avec input.power, %d a { have_kw = 90, used_kw = 36 } sans plant ; %d ligne(s) [FO-CAPI-KW] « capacite 90 kW »",
      o.k1, o.p1, o.p1_ok, o.kw1),
    string.format("§2 temoin %s : %d decision(s), %d ligne(s) [FO-CAPI-KW]", o.k2, o.d2, o.kw2),
  }
  local all = true
  for i = 1, #ok do
    if not quiet then check(ok[i], msgs[i]) end
    all = all and ok[i]
  end
  return all
end

local a = run(false)
say(string.format("§1-2 faction %s : %d decisions (%d avec courant), %d lignes [FO-CAPI-KW] ; temoin %s : %d decisions", a.k1, a.d1, a.p1, a.kw1,
  a.k2, a.d2))
verdict(a, false)

local b = run(true)
say(string.format("§3 mutant : %d decision(s) avec courant, %d lignes [FO-CAPI-KW]", b.p1, b.kw1))
check(not verdict(b, true), "§3 mutant refuse : courant jamais donne a la decision")

print(string.format("[CAPI-COURANT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
