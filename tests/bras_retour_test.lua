--[[
  Tests hors jeu du lot PLANDIR : migration des bras de la centrale (shared/team/bras_retour.lua). Usage :
  lua5.2 tests/bras_retour_test.lua
  Cas : bras électrique marqué (repassé), déjà à combustion (intact), bras du joueur ou d'un module non marqué (intact), centrale
  entièrement convertie, entrées vides, idempotence ; MUTANTS.
]]
package.path = "./?.lua;" .. package.path
local B = require("shared.team.bras_retour")
local M = require("shared.team.modules")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local BURNER = M.BURNER_ARM
check(BURNER ~= nil, "le bras à combustion est lu aux données")
-- noms de bras électriques lus aux données (aucun nom écrit dans ce test)
local ELEC = M.ELECTRIC_ARM
check(ELEC ~= nil and ELEC ~= BURNER, "un bras électrique de portée 1 existe aux données")

local function plant()
  return {
    { name = "engine-a", x = 1, y = 1 },
    { name = ELEC, x = 2, y = 2, was_burner = true, item = ELEC, role = "quai-bras" },
    { name = BURNER, x = 3, y = 3, item = BURNER },
    { name = ELEC, x = 4, y = 4, was_burner = true, item = ELEC },
    { name = ELEC, x = 5, y = 5 },                               -- bras d'un module / du joueur : jamais marqué
    { name = BURNER, x = 6, y = 6, was_burner = true },          -- marqué mais déjà à combustion (reste d'un retour manuel)
  }
end

section("1. Choix des entrées")
local list = B.to_restore(plant(), BURNER)
check(#list == 2 and list[1] == 2 and list[2] == 4, "les deux bras électriques marqués sont à repasser (indices 2 et 4)")
check(#B.to_restore({}, BURNER) == 0 and #B.to_restore(nil, BURNER) == 0, "aucune entrée : rien")
local all = {}
for i = 1, 5 do all[i] = { name = ELEC, was_burner = true } end
check(#B.to_restore(all, BURNER) == 5, "centrale entièrement convertie : les 5 bras")
local none = { { name = BURNER }, { name = ELEC } }
check(#B.to_restore(none, BURNER) == 0, "déjà à combustion ou électrique non marqué : intacts")

section("2. Passage et idempotence")
local p = plant()
for _, i in ipairs(B.to_restore(p, BURNER)) do B.restored(p[i], BURNER) end
check(p[2].name == BURNER and p[2].item == BURNER and p[2].was_burner == nil and p[2].role == "quai-bras", "entrée renommée, marque levée, rôle gardé")
check(p[4].name == BURNER and p[4].was_burner == nil, "second bras renommé")
check(p[5].name == ELEC and p[5].was_burner == nil, "le bras non marqué reste électrique")
check(p[1].name == "engine-a" and p[3].name == BURNER, "les autres entrées ne bougent pas")
check(B.remaining(p, BURNER) == 0, "rien ne reste à faire")
check(#B.to_restore(p, BURNER) == 0, "second passage : rien (idempotent)")
local partial = plant()
B.restored(partial[2], BURNER)
check(B.remaining(partial, BURNER) == 1, "un bras repassé sur deux : un reste (le relevé suivant reprend)")

section("3. Mutants")
do
  -- mutant : la marque est ignorée (tout bras électrique serait repassé, bras du joueur compris)
  local function to_restore_mut(entries, burner)
    local out = {}
    for i, e in ipairs(entries) do if e.name ~= burner and e.name ~= "engine-a" then out[#out + 1] = i end end
    return out
  end
  local good, mut = B.to_restore(plant(), BURNER), to_restore_mut(plant(), BURNER)
  check(#mut > #good, "mutant « marque ignorée » : détecté (touche aussi le bras non marqué, " .. #mut .. " contre " .. #good .. ")")
  local q2 = plant()
  q2[2].name = ELEC
  check(B.remaining(q2, BURNER) >= 1, "mutant « nom non changé » : détecté (il resterait du travail)")
end

print(string.format("[BRAS-RETOUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
