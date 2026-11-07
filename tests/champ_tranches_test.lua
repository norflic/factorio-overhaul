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

print(string.format("[CHAMP-TRANCHES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
