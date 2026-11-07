--[[
  Lot VIDEO-REFUS (C6) : test hors jeu de shared/ai3/refus.lua.
    §1 chaque raison réelle des refus de Ca.decide tombe dans la bonne sorte (textes copiés des appels de refuse) ;
    §2 somme exacte : Rf.total = nombre de refus, pour une liste mêlée ; chaque sorte compte juste ;
    §3 ordre fixe : Rf.SORTS, clés du décompte, et ordre de la ligne [FO-CAPI-REFUS] ;
    §4 liste vide : toutes les sortes à 0, total 0 ;
    §5 mutant (sur le source) : une sorte oubliée dans la somme doit être vue par §2.
  Usage : lua5.2 tests/refus_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local Rf = require("shared.ai3.refus")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[FO-REFUS-TEST] ECHEC : " .. msg) end
end

-- §1 raisons réelles (copiées des appels refuse / cap_ok / Pe / Pr de shared/ai3 et script/ai3)
local CASES = {
  { "confirmation : attend la premiere production (fer)", "confirmation" },
  { "rang : fer-plaque (rang 1) d'abord", "rang" },
  { "anti-repetition : fer-plaque pose au tour precedent", "rang" },
  { "bras : 3 chantier(s) ouvert(s) au plus pour 5 module(s)", "portes" },
  { "transport sature : charbon", "portes" },
  { "repetition : meme objet qu'a la decision precedente (signal en retard sur la pose)", "portes" },
  { "budget : 12.5 MU > 4.0", "budget" },
  { "impayable : fer-plaque", "budget" },
  { "retour 120.0 min > 60.0", "budget" },
  { "bras : 9.0 PNJ-s > 2.0", "bras" },
  { "plafond", "plafond" },
  { "plafond fer-plaque : demande saturee", "plafond" },
  { "ordres ouverts : entree absente", "plafond" },
  { "aucune place", "emplacements" },
  { "gisement voisin a des places (d1)", "emplacements" },
  { "gisements ouverts pas couverts (kappa 300 pour mille < 500)", "emplacements" },
  { "entree fer-plaque d'abord (couverte a 200 pour mille)", "goulot amont" },
  { "entree 3 insuffisante (arrivee des foreuses)", "goulot amont" },
  { "manque sous une demi-machine (0.4/min)", "goulot amont" },
  { "menace : leviers du QG seulement", "autre" },
  { "danger", "autre" },
  { "courant insuffisant", "autre" },
  { "aucune machine disponible (crafting)", "autre" },
  { "laboratoires affames (300 pour mille) : les packs d'abord", "autre" },
  { "gain nul", "autre" },
  { "limite : fluide (water)", "autre" },
}
for _, c in ipairs(CASES) do
  check(Rf.sort_of(c[1]) == c[2], "§1 « " .. c[1] .. " » -> " .. Rf.sort_of(c[1]) .. " au lieu de " .. c[2])
end

-- §2 somme exacte sur une liste mêlée
local refus = {}
for _, c in ipairs(CASES) do refus[#refus + 1] = { key = c[1], why = c[1] } end
local counts = Rf.count(refus)
check(Rf.total(counts) == #refus, "§2 somme des sortes = nombre de refus (" .. Rf.total(counts) .. " contre " .. #refus .. ")")
local expect = {}
for _, c in ipairs(CASES) do expect[c[2]] = (expect[c[2]] or 0) + 1 end
for _, name in ipairs(Rf.SORTS) do
  check(counts[name] == (expect[name] or 0), "§2 sorte « " .. name .. " » : " .. tostring(counts[name]) .. " au lieu de " .. tostring(expect[name] or 0))
end

-- §3 ordre fixe
local want = { "goulot amont", "budget", "bras", "plafond", "confirmation", "emplacements", "rang", "portes", "autre" }
check(#Rf.SORTS == #want, "§3 neuf sortes")
for i, name in ipairs(want) do check(Rf.SORTS[i] == name, "§3 position " .. i .. " = " .. name) end
local line = Rf.line("F1", 12, refus)
check(line == "[FO-CAPI-REFUS] F1 minute 12 : goulot amont " .. counts["goulot amont"] .. ", budget " .. counts.budget .. ", bras " .. counts.bras
  .. ", plafond " .. counts.plafond .. ", confirmation " .. counts.confirmation .. ", emplacements " .. counts.emplacements
  .. ", rang " .. counts.rang .. ", portes " .. counts.portes .. ", autre " .. counts.autre .. " ; total " .. #refus, "§3 format de la ligne")

-- §4 liste vide
local empty = Rf.count({})
check(Rf.total(empty) == 0 and empty.budget == 0 and empty.autre == 0, "§4 liste vide : tout à 0")
check(Rf.line("F2", 0, nil):find("total 0", 1, true) ~= nil, "§4 ligne sans refus : total 0")

-- §5 mutant : la somme oublie « autre » ; §2 doit le voir
local src = assert(io.open("shared/ai3/refus.lua", "rb")):read("*a")
local a, b = src:find("for _, name in ipairs(Rf.SORTS) do n = n + (counts[name] or 0) end", 1, true)
if a then
  local mut = src:sub(1, a - 1) .. "for _, name in ipairs(Rf.SORTS) do if name ~= \"autre\" then n = n + (counts[name] or 0) end end" .. src:sub(b + 1)
  local Rm = assert(load(mut, "@shared/ai3/refus.lua"))()
  local cm = Rm.count(refus)
  check(Rm.total(cm) ~= #refus, "§5 mutant (somme sans « autre ») refusé")
  -- le mutant doit aussi échouer sur §2 : somme différente du nombre de refus
  local caught = Rm.total(cm) ~= #refus
  print(string.format("[FO-REFUS-TEST] mutant somme sans « autre » : %s", caught and "refusé" or "SURVIVANT"))
else
  fail = fail + 1; print("[FO-REFUS-TEST] ECHEC : §5 motif du mutant absent du source")
end

print(string.format("[FO-REFUS-TEST] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
