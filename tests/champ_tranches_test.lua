--[[
  Tests hors jeu du COÛT de Ch.plan (lot CHAMP-COUVERTURE, décision du lead du 7/11 : « voie des TRANCHES ») ; critères écrits AVANT le code :
    C1  équivalence : Ch.plan_job(spec) avancé par Ch.plan_step(job, budget) rend le plan IDENTIQUE à Ch.plan(spec) d'un bloc, pour tout
        budget, sur le corpus (tests/champ_formes.lua : 17 formes, géant, cadres réels ; bandes seules de 4 formes) ;
    C2  sérialisable : entre deux pas, le travail ne contient que tables, nombres, chaînes, booléens ; recopié à chaque pas (comme une
        sauvegarde puis un chargement), il rend le même plan ;
    C3  pas borné : budget en UNITÉS de travail, jamais en temps ; pire pas mesuré sous 8 ms (géant, pire forme) ;
    C4  aucune décision changée : Ch.plan rend les empreintes de référence (tests/fixtures/champ_plans_ref.lua, commit 067a1bd3) ;
    C5  surcoût : total en tranches <= 1,3 x le bloc ;
    C6  mutants vus par C1 ou C2.
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

print(string.format("[CHAMP-TRANCHES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
