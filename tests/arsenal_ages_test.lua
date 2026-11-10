--[[
  Banc pur du lot ARMES-AGES (9/11) : la lignée Bastion décrite par les DONNÉES (shared/content/arsenal.lua, A.ages), les armes
  de poing (A.hand_weapons) et la frappe orbitale (A.cataclysm).
    lua5.2 tests/arsenal_ages_test.lua      -> [ARMES-AGES] BILAN : N OK, 0 ECHEC(S)
  Règles vérifiées (puis leurs mutants : mode dupliqué, coût décroissant, locale manquante) :
  1. quatre âges, un MODE distinct par âge (champ `mode` dans les données, dans A.MODES), âges 1 à 4 dans l'ordre, un âge
     d'armement = une ère des niveaux (A.AGE_EPOCHS = L.ERA_EPOCHS) ;
  2. les coûts croissent strictement avec l'âge : recherche (tech.count), nombre de packs (non décroissant) et valeur des
     ingrédients de la recette (table de valeurs : L.item_value des niveaux + objets vanilla relevés ici) ;
  3. chaque entrée a sa locale FR ET EN (nom et description de l'entité ou de l'objet, nom et description de la technologie),
     lues dans locale/<lang>/armes_ages.cfg et locale/<lang>/factorio-overhaul.cfg (le fusil à rail de la session 4).
]]
package.path = "./?.lua;" .. package.path

local A = require("shared.content.arsenal")
local L = require("shared.levels.config")

local ok, ko = 0, 0
local function check(c, quoi, detail)
  if c then ok = ok + 1 else ko = ko + 1; print("ECHEC  " .. quoi .. (detail and (" : " .. tostring(detail)) or "")) end
end

local function copie(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = copie(v) end
  return c
end

local function read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

---------------------------------------------------------------------------------------------------
-- Règles (pures, sur les données) : chacune rend la liste des motifs d'échec (vide = conforme)
---------------------------------------------------------------------------------------------------
local function verifier_modes(ages, modes)
  local motifs, vus, permis = {}, {}, {}
  for _, m in ipairs(modes) do permis[m] = true end
  for i, t in ipairs(ages) do
    if t.age ~= i then motifs[#motifs + 1] = "âge " .. tostring(t.age) .. " au rang " .. i end
    if type(t.mode) ~= "string" or not permis[t.mode] then
      motifs[#motifs + 1] = tostring(t.name) .. " : mode inconnu « " .. tostring(t.mode) .. " »"
    elseif vus[t.mode] then
      motifs[#motifs + 1] = tostring(t.name) .. " : mode « " .. t.mode .. " » déjà pris par " .. vus[t.mode]
    else
      vus[t.mode] = t.name
    end
  end
  if #ages ~= #modes then motifs[#motifs + 1] = #ages .. " âge(s) pour " .. #modes .. " mode(s)" end
  return motifs
end

--- Valeur d'une recette (unités de matière brute) ; une valeur inconnue est une erreur (table à compléter).
local function valeur_recette(ingredients, valeurs)
  local v = 0
  for _, ing in ipairs(ingredients) do
    local nom, n = ing[1] or ing.name, ing[2] or ing.amount
    if valeurs[nom] == nil then error("valeur inconnue pour l'ingrédient " .. tostring(nom)) end
    v = v + valeurs[nom] * n
  end
  return v
end

local function verifier_couts(ages, valeurs)
  local motifs = {}
  for i = 2, #ages do
    local a, b = ages[i - 1], ages[i]
    if not (b.tech.count > a.tech.count) then
      motifs[#motifs + 1] = b.name .. " : recherche " .. b.tech.count .. " <= " .. a.tech.count .. " (" .. a.name .. ")"
    end
    if #b.tech.packs < #a.tech.packs then
      motifs[#motifs + 1] = b.name .. " : moins de packs de science que " .. a.name
    end
    local va, vb = valeur_recette(a.ingredients, valeurs), valeur_recette(b.ingredients, valeurs)
    if not (vb > va) then
      motifs[#motifs + 1] = string.format("%s : recette %.0f <= %.0f (%s)", b.name, vb, va, a.name)
    end
  end
  return motifs
end

local function verifier_locale(cles, FR, EN)
  local motifs = {}
  for _, k in ipairs(cles) do
    if not FR[k] or FR[k] == "" then motifs[#motifs + 1] = "fr : " .. k end
    if not EN[k] or EN[k] == "" then motifs[#motifs + 1] = "en : " .. k end
  end
  return motifs
end

---------------------------------------------------------------------------------------------------
-- 1. Un mode distinct par âge, âges alignés sur les ères des niveaux
---------------------------------------------------------------------------------------------------
check(type(A.ages) == "table" and #A.ages == 4, "quatre âges d'armement", #(A.ages or {}))
local m = verifier_modes(A.ages, A.MODES)
check(#m == 0, "un mode distinct par âge, dans A.MODES, âges 1 à 4 dans l'ordre", table.concat(m, " ; "))
for i, mode in ipairs({ "cinetique", "laser", "arc", "plasma" }) do
  check(A.ages[i] and A.ages[i].mode == mode, "âge " .. i .. " = " .. mode, A.ages[i] and A.ages[i].mode)
end
check(A.AGE_EPOCHS == L.ERA_EPOCHS, "un âge d'armement = une ère des niveaux (L.ERA_EPOCHS)", L.ERA_EPOCHS)
for _, c in ipairs({ { 1, 1 }, { 3, 1 }, { 4, 2 }, { 6, 2 }, { 7, 3 }, { 9, 3 }, { 10, 4 }, { 12, 4 }, { 15, 4 } }) do
  check(A.age_of_epoch(c[1]) == c[2], "époque " .. c[1] .. " -> âge " .. c[2], A.age_of_epoch(c[1]))
end
for i = 1, 4 do check(A.age_turret(i) == A.ages[i], "A.age_turret(" .. i .. ")") end
check(A.age_turret(5) == nil, "A.age_turret(5) = nil")
-- chaque mode porte sa mécanique dans les données (ce que l'étape data lit)
check(A.ages[1].copy_type == "ammo-turret" and A.ages[1].ammo_category, "cinétique : tourelle à munitions, catégorie de chargeurs")
check(A.ages[2].copy_type == "electric-turret" and A.ages[2].beam and A.ages[2].beam.copy, "laser : tourelle électrique, faisceau copié")
check(A.ages[3].copy_type == "electric-turret" and A.ages[3].arc and #A.ages[3].arc.hops >= 2, "arc : au moins deux sauts")
check(A.ages[4].copy_type == "electric-turret" and A.ages[4].plasma and A.ages[4].plasma.radius > 0, "plasma : projectile à zone")
-- technologies chaînées : chaque âge exige la technologie de l'âge précédent
for i = 2, 4 do
  local prev, found = A.ages[i - 1].tech.name, false
  for _, p in ipairs(A.ages[i].tech.prerequisites) do if p == prev then found = true end end
  check(found, A.ages[i].tech.name .. " exige " .. prev)
end
-- la frappe orbitale est verrouillée derrière la dernière technologie de l'âge 4
local last4, locked = A.ages[4].tech.name, false
for _, p in ipairs(A.cataclysm.tech.prerequisites) do if p == last4 then locked = true end end
check(locked, "frappe orbitale verrouillée derrière " .. last4)
check(A.cataclysm.tech.count > A.ages[4].tech.count, "frappe orbitale : recherche plus chère que l'âge 4")

---------------------------------------------------------------------------------------------------
-- 2. Les coûts croissent avec l'âge
---------------------------------------------------------------------------------------------------
-- Valeurs (unités de matière brute) : celles des niveaux pour les matériaux d'époque et le panier de base ; les objets vanilla
-- composés sont relevés ici d'après leurs recettes (approximations, comme BALANCE_SHEET §12).
local VALEURS = {}
for k, v in pairs(L.item_value) do VALEURS[k] = v end
local VANILLA = {
  ["gun-turret"] = 50, ["laser-turret"] = 700, ["advanced-circuit"] = 25, ["rocket-launcher"] = 60,
  ["energy-shield-equipment"] = 300, ["explosives"] = 6, ["copper-cable"] = 0.5,
  ["fo-armored-wall"] = 120, -- lot ASSAUTS-TITANESQUES : mur blindé (mur renforcé 1 : pierre + 2 acier + 5 béton ; + 4 tungstène)
}
for k, v in pairs(VANILLA) do VALEURS[k] = VALEURS[k] or v end
local okv, motifs_couts = pcall(verifier_couts, A.ages, VALEURS)
check(okv, "valeur connue pour chaque ingrédient de la lignée", not okv and motifs_couts or nil)
check(okv and #motifs_couts == 0, "recherche, packs et recette croissent avec l'âge", okv and table.concat(motifs_couts, " ; ") or nil)
for i, t in ipairs(A.ages) do
  print(string.format("  âge %d %-9s %-13s recherche %5d  packs %d  recette %6.0f MU", i, t.mode, t.name, t.tech.count, #t.tech.packs,
    valeur_recette(t.ingredients, VALEURS)))
end

---------------------------------------------------------------------------------------------------
-- 3. Locales FR et EN
---------------------------------------------------------------------------------------------------
local function cfg(p, t)
  t = t or {}
  local sec = ""
  local s = read(p)
  if not s then return t, false end
  for line in s:gmatch("[^\r\n]+") do
    local sname = line:match("^%[([%w%-_]+)%]$")
    if sname then sec = sname else
      local k, v = line:match("^([%w%-_]+)=(.*)$")
      if k then t[sec .. "." .. k] = v end
    end
  end
  return t, true
end
local FR, EN = {}, {}
for _, f in ipairs({ "armes_ages.cfg", "factorio-overhaul.cfg" }) do
  local _, okfr = cfg("locale/fr/" .. f, FR)
  local _, oken = cfg("locale/en/" .. f, EN)
  check(okfr and oken, "locale/fr et locale/en : " .. f .. " lisibles")
end

local cles = {}
for _, t in ipairs(A.ages) do
  cles[#cles + 1] = "entity-name." .. t.name
  cles[#cles + 1] = "entity-description." .. t.name
  cles[#cles + 1] = "technology-name." .. t.tech.name
  cles[#cles + 1] = "technology-description." .. t.tech.name
end
for _, h in ipairs(A.hand_weapons) do
  cles[#cles + 1] = "item-name." .. h.name
  cles[#cles + 1] = "item-description." .. h.name
  cles[#cles + 1] = "technology-name." .. h.tech.name
  cles[#cles + 1] = "technology-description." .. h.tech.name
  if h.ammo then
    cles[#cles + 1] = "item-name." .. h.ammo
    cles[#cles + 1] = "item-description." .. h.ammo
  end
  if h.remote then
    cles[#cles + 1] = "item-name." .. h.remote
    cles[#cles + 1] = "item-description." .. h.remote
  end
end
cles[#cles + 1] = "item-name." .. A.cataclysm.name
cles[#cles + 1] = "item-description." .. A.cataclysm.name
cles[#cles + 1] = "technology-name." .. A.cataclysm.tech.name
cles[#cles + 1] = "technology-description." .. A.cataclysm.tech.name
local ml = verifier_locale(cles, FR, EN)
check(#ml == 0, #cles .. " clés de locale présentes en FR et en EN", table.concat(ml, " ; "))

-- trois armes de poing, modes distincts, le fusil à rail existe dans l'arsenal spécial (session 4)
check(#A.hand_weapons == 3, "trois armes de poing décrites", #A.hand_weapons)
local hm = {}
for _, h in ipairs(A.hand_weapons) do
  check(not hm[h.mode], "arme de poing : mode « " .. tostring(h.mode) .. " » unique")
  hm[h.mode] = true
end
local rail
for _, g in ipairs(A.special_guns) do if g.name == "fo-railgun" then rail = g end end
check(rail ~= nil and A.hand_weapons[1].existing == "special_guns", "le fusil à rail est l'arme de la session 4 (fo-railgun)")

---------------------------------------------------------------------------------------------------
-- 4. Mutants : chaque règle doit refuser une donnée fautive
---------------------------------------------------------------------------------------------------
do -- mode dupliqué
  local mut = copie(A.ages)
  mut[3].mode = mut[2].mode
  check(#verifier_modes(mut, A.MODES) > 0, "mutant : mode dupliqué refusé")
end
do -- mode hors liste
  local mut = copie(A.ages)
  mut[4].mode = "nucleaire"
  check(#verifier_modes(mut, A.MODES) > 0, "mutant : mode inconnu refusé")
end
do -- recherche décroissante
  local mut = copie(A.ages)
  mut[4].tech.count = mut[3].tech.count
  check(#verifier_couts(mut, VALEURS) > 0, "mutant : recherche non croissante refusée")
end
do -- recette moins chère que l'âge précédent
  local mut = copie(A.ages)
  mut[2].ingredients = { { "iron-plate", 1 } }
  check(#verifier_couts(mut, VALEURS) > 0, "mutant : recette décroissante refusée")
end
do -- locale manquante (FR seulement)
  local FRm = copie(FR)
  FRm["entity-name." .. A.ages[3].name] = nil
  check(#verifier_locale(cles, FRm, EN) > 0, "mutant : locale FR manquante refusée")
  local ENm = copie(EN)
  ENm["technology-description." .. A.cataclysm.tech.name] = ""
  check(#verifier_locale(cles, FR, ENm) > 0, "mutant : locale EN vide refusée")
end

---------------------------------------------------------------------------------------------------
-- 5. Lot ASSAUTS-TITANESQUES (10/11) : la BARRIÈRE ÉNERGÉTIQUE DE PÉRIMÈTRE (A.perimetre) : arme de fin de partie de l'âge 4,
--    mode propre hors de la lignée (« barriere »), tourelle électrique à portée COURTE avec un champ (dégâts + ralentissement),
--    verrouillée derrière la dernière technologie de l'âge 4, plus chère qu'elle en recherche, locale FR et EN complète.
---------------------------------------------------------------------------------------------------
local P = A.perimetre
check(type(P) == "table" and P.age == 4 and P.mode == "barriere", "barrière : âge 4, mode « barriere »")
local mode_libre = true
for _, t in ipairs(A.ages) do if t.mode == P.mode then mode_libre = false end end
check(mode_libre and P.role ~= nil, "barrière : mode hors de la lignée Bastion, rôle déclaré (" .. tostring(P.role) .. ")")
check(P.copy_type == "electric-turret" and P.range <= 5 and P.field and P.field.radius > 0 and P.field.damage > 0 and P.field.slow < 1,
  "barrière : tourelle électrique à portée courte, champ à dégâts et ralentissement")
check(P.buffer and P.input and P.drain and P.energy, "barrière : énergie (tampon, entrée, drain, par décharge) : sans courant, éteinte par le moteur")
local lock4 = false
for _, pre in ipairs(P.tech.prerequisites) do if pre == A.ages[4].tech.name then lock4 = true end end
check(lock4, "barrière : verrouillée derrière " .. A.ages[4].tech.name)
check(P.tech.count > A.ages[4].tech.count and #P.tech.packs >= #A.ages[4].tech.packs, "barrière : recherche plus chère que l'âge 4")
local okp, vp = pcall(valeur_recette, P.ingredients, VALEURS)
-- une borne se pose en LIGNE (une tuile) : chaque borne coûte plus qu'une tourelle de l'âge 1, la recherche porte le prix de fin de partie
check(okp and vp > valeur_recette(A.ages[1].ingredients, VALEURS), "barrière : une borne plus chère qu'une tourelle de l'âge 1 (" .. tostring(okp and math.floor(vp) or vp) .. " MU)")
local cles_p = { "entity-name." .. P.name, "entity-description." .. P.name, "technology-name." .. P.tech.name, "technology-description." .. P.tech.name }
local mlp = verifier_locale(cles_p, FR, EN)
check(#mlp == 0, "barrière : 4 clés de locale en FR et EN", table.concat(mlp, " ; "))
do -- mutants
  local mut = copie(P)
  mut.range = 30
  check(not (mut.range <= 5), "mutant : barrière à longue portée refusée")
  mut = copie(P)
  mut.tech.prerequisites = { "military-4" }
  local l = false
  for _, pre in ipairs(mut.tech.prerequisites) do if pre == A.ages[4].tech.name then l = true end end
  check(not l, "mutant : barrière sans le verrou de l'âge 4 refusée")
  mut = copie(P)
  mut.mode = A.ages[2].mode
  local libre = true
  for _, t in ipairs(A.ages) do if t.mode == mut.mode then libre = false end end
  check(not libre, "mutant : mode de la barrière pris à la lignée refusé")
  local FRm = copie(FR)
  FRm["entity-description." .. P.name] = nil
  check(#verifier_locale(cles_p, FRm, EN) > 0, "mutant : locale FR de la barrière manquante refusée")
end

print(string.format("[ARMES-AGES] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
