--[[
  N100-IMPASSES (cycle 0.9.10 ; DC : « problèmes de chemins entre les fonderies et les foreuses »). Test PUR de la classe d'un tapis chargé
  sans sortie (tools/autotest/fo-autotest/scenarios/cul_classe.lua), lue par la sonde [FO-CUL-DE-SAC] / [FO-CUL-CLASSE] (scenarios/jalons_common.lua).

  Chaîne (A4, garde trop large) : la sonde comptait « cul-de-sac » tout tapis sans sortie, chargé (6 objets ou plus), dont aucun bras ne prend
  sur la DERNIÈRE tuile. Banc fo-logs/2026-11-16_n100-impasses-1 (graine 4251870853, 90 min, code 0.9.9) : 26 cas à 90 min, tous des bouts de
  lignes d'alimentation (11 lignes de blocs d'assembleurs finies contre un bras de quai, 6 lignes de rangées et de packs, 4 entrées du mall,
  2 troncs du charbon, 2 trop-pleins de plaques, 1 bande de charbon vers ses coffres) : l'amont de chacune a des preneurs, le plein jusqu'au
  bout est l'état normal. Coupe : la classe lit les bras qui prennent sur TOUTE la ligne, la suite planifiée non posée, la case retenue.
  Mutant : la règle sans les preneurs (la sonde d'avant) -> une ligne d'alimentation compte comme impasse.
  Lancement (racine du mod) : lua5.2 tests/n100_impasses_test.lua   -> [N100-IMPASSES] BILAN : N OK, 0 ECHEC(S)
]]
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1; print("[N100-IMPASSES] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local PATH = "tools/autotest/fo-autotest/scenarios/cul_classe.lua"
local SRC = read(PATH)
local function load_cc(src) return assert(load(src, "=" .. PATH, "t", _ENV))() end
local function sub1(src, a, b, name)
  local i, j = src:find(a, 1, true)
  assert(i, "mutant introuvable : " .. name)
  assert(not src:find(a, j + 1, true), "mutant ambigu : " .. name)
  return src:sub(1, i - 1) .. b .. src:sub(j + 1)
end

-- Cas relevés au banc (valeurs de [FO-CUL-DETAIL], minute 60 et 90)
local CASES = {
  -- scarlet (163.5,-575.5), projet 45 (bloc d'assembleurs) : ligne d'engrenages et de plaques finie contre le bras du quai ; bras de machines en amont
  { name = "bloc d'assembleurs, fin contre le quai", c = { preneurs = 3, occ_suiv = 45, propre = 45 }, want = "alimentation" },
  -- scarlet (393.5,-655.5), projet 68 (réseau du charbon) : tronc plein, case suivante retenue par le cadre ; bras de dérivation en amont
  { name = "tronc du charbon, bras de derivation", c = { preneurs = 2, occ_suiv = "cadre:100001", propre = 68 }, want = "alimentation" },
  -- joueur (-130.5,-17.5) à 60 min, projet 22 en chantier : le tapis suivant est au plan, pas encore posé
  { name = "suite au plan pas encore posee", c = { suite_a_poser = true, preneurs = 0, occ_suiv = 22, propre = 22 }, want = "chantier" },
  -- même tronc sans aucun preneur : la case suivante retenue par le cadre pour une bande à venir
  { name = "tronc sans preneur, case retenue par le cadre", c = { preneurs = 0, occ_suiv = "cadre:100001", propre = 68 }, want = "retenue" },
  -- ligne sans preneur ni suite : vraie impasse (la matière ne va nulle part)
  { name = "ligne sans preneur ni suite", c = { preneurs = 0, occ_suiv = nil, propre = 54 }, want = "impasse" },
  { name = "ligne sans preneur, case suivante a son propre projet", c = { preneurs = 0, occ_suiv = 54, propre = 54 }, want = "impasse" },
  -- entrée de souterrain sans sortie appariée
  { name = "souterrain ampute", c = { souterrain_seul = true, preneurs = 4 }, want = "souterrain_ampute" },
  { name = "souterrain dont la sortie est au plan non posee", c = { souterrain_seul = true, suite_a_poser = true }, want = "chantier" },
}

local function battery(Cc, quiet)
  local bad = 0
  for _, t in ipairs(CASES) do
    local got = Cc.classe(t.c)
    if got ~= t.want then
      bad = bad + 1
      if not quiet then check(false, t.name .. " : " .. tostring(got) .. " au lieu de " .. t.want) end
    elseif not quiet then check(true, t.name) end
  end
  return bad
end

-- 1. la règle livrée
local Cc = load_cc(SRC)
battery(Cc, false)
local known = {}
for _, c in ipairs(Cc.CLASSES) do known[c] = true end
for _, t in ipairs(CASES) do check(known[t.want] == true, "classe annoncee dans CLASSES : " .. t.want) end
check(#Cc.CLASSES == 5, "cinq classes")

-- 2. déterminisme : deux passes, mêmes réponses
local a, b = {}, {}
for i, t in ipairs(CASES) do a[i] = Cc.classe(t.c) end
for i, t in ipairs(CASES) do b[i] = Cc.classe(t.c) end
check(table.concat(a, ",") == table.concat(b, ","), "deux passes identiques")

-- 3. mutant : la sonde d'avant (aucun regard sur les preneurs de la ligne) -> des lignes d'alimentation comptées comme impasses
local MUT = sub1(SRC, '  if (c.preneurs or 0) > 0 then return "alimentation" end\n', "", "preneurs")
local Cm = load_cc(MUT)
local mbad = battery(Cm, true)
print(string.format("[N100-IMPASSES] mutant (preneurs ignores) : %d cas sur %d mal classes", mbad, #CASES))
check(mbad > 0, "mutant : une ligne d'alimentation devient une impasse ou une case retenue")
check(Cm.classe(CASES[1].c) ~= "alimentation", "mutant : le bloc d'assembleurs n'est plus une ligne d'alimentation")

-- 4. la sonde lit la règle et compte les preneurs sur TOUTE la ligne (pas seulement la dernière tuile)
local SONDE = read("tools/autotest/fo-autotest/scenarios/jalons_common.lua")
check(SONDE:find('require("scenarios/cul_classe")', 1, true) ~= nil, "la sonde charge la regle")
check(SONDE:find("Cc.classe({ suite_a_poser = pending, souterrain_seul = ug, preneurs = nt", 1, true) ~= nil, "la sonde passe les preneurs de la ligne")
check(SONDE:find("local nt = takers(s, force, tiles, box)", 1, true) ~= nil, "preneurs comptes sur les tuiles de la ligne")
check(SONDE:find("[FO-CUL-CLASSE]", 1, true) ~= nil, "ligne de compte par classe")
-- l'interface de lecture du plan existe dans le mod (lecture seule)
local RM = read("script/team/ia1_remote.lua")
check(RM:find("plan_at = function(key, x, y)", 1, true) ~= nil, "remote fo-ia1.plan_at")

print(string.format("[N100-IMPASSES] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
