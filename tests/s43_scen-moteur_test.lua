-- s43 scen-moteur : format déclaratif des scénarios en boucle fermée (shared/scenarios/format.lua).
-- Usage : lua5.2 tests/s43_scen-moteur_test.lua (depuis la racine du mod).
package.path = "./?.lua;" .. package.path
local F = require("shared.scenarios.format")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

-- 1. Les scénarios livrés sont valides.
for _, id in ipairs({ "famine_fer_attaque" }) do
  local s = require("shared.scenarios." .. id)
  local e = F.valider(s)
  check(e == nil, id .. " valide : " .. tostring(e))
  check(F.ticks(s) == s.duree_min * 3600 + 600, id .. " ticks")
end

-- 2. Défauts détectés.
local base = {
  nom = "x", duree_min = 10, description = { fr = "a", en = "b" },
  theorie = { { id = "a", texte = { fr = "a", en = "a" }, predicat = { type = "seuil", champ = "c", minute = 5, op = "<=", valeur = 1 } } },
}
check(F.valider(base) == nil, "base valide")
local function variant(f)
  local s = { nom = base.nom, duree_min = base.duree_min, description = base.description,
    theorie = { { id = "a", texte = base.theorie[1].texte, predicat = {} } } }
  for k, v in pairs(base.theorie[1].predicat) do s.theorie[1].predicat[k] = v end
  f(s)
  return F.valider(s)
end
check(variant(function(s) s.nom = "Nom Faux" end) ~= nil, "nom refusé")
check(variant(function(s) s.theorie[1].predicat.op = "=" end) ~= nil, "op refusé")
check(variant(function(s) s.theorie[1].predicat.minute = 11 end) ~= nil, "jugé après la durée")
check(variant(function(s) s.mise_en_scene = { { minute = 3, action = "inonder" } } end) ~= nil, "action inconnue")
check(variant(function(s) s.theorie[2] = s.theorie[1] end) ~= nil, "id en double")
check(variant(function(s) s.theorie[1].predicat = { type = "avant", premier = { type = "seuil" }, second = {} } end) ~= nil,
  "avant sans atteint")

-- 3. Évaluation sur des relevés synthétiques (famine à 20, retour à 24, avant-poste à 26).
local rel = {}
for m = 1, 31 do
  rel[m] = { ["prod:iron-plate"] = 0, avant_postes = 2, pnj_inactifs = 0, tourelles_vides = 0, qg_vie = 1 }
end
local cum = 0
for m = 1, 31 do
  local d = (m >= 20 and m < 24) and 10 or 100
  cum = cum + d
  rel[m]["prod:iron-plate"] = cum
  F.deriver(rel, m, { "iron-plate" })
end
for m = 26, 31 do rel[m].avant_postes = 3 end
rel[20]["stock:iron-plate"] = 0
check(rel[1]["debit:iron-plate"] == nil and rel[5]["debit:iron-plate"] == 100, "débit dérivé")

local s = require("shared.scenarios.famine_fer_attaque")
local by = {}
for _, att in ipairs(s.theorie) do by[att.id] = att end
local e, o = F.juger(by["fer-revenu"].predicat, rel)
check(e == "OK" and o == 3, "fer revenu en 3 min : " .. e .. " " .. tostring(o))
e = F.juger(by["fer-avant-expansion"].predicat, rel)
check(e == "OK", "fer avant expansion : " .. e)
for m = 22, 31 do rel[m].avant_postes = 3 end
e = F.juger(by["fer-avant-expansion"].predicat, rel)
check(e == "ECHEC", "expansion avant le fer : " .. e)
e = F.juger(by["famine-posee"].predicat, rel)
check(e == "OK", "famine posée")
e = F.juger(by["zero-idle-journal"].predicat, rel)
check(e == "EN ATTENTE", "ligne : en attente du lanceur")
rel[25].tourelles_vides = 2
e, o = F.juger(by["tourelles-reapprovisionnees"].predicat, rel)
check(e == "ECHEC" and o == 2, "tourelle vide détectée")
rel[23].qg_vie = 0
check(F.juger(by["qg-tenu"].predicat, rel) == "ECHEC", "QG détruit")
-- fer jamais revenu
for m = 21, 31 do rel[m]["debit:iron-plate"] = 5 end
check(F.juger(by["fer-revenu"].predicat, rel) == "ECHEC", "fer jamais revenu")
check(F.juger(by["fer-avant-expansion"].predicat, rel) == "ECHEC", "avant : premier jamais atteint")

-- 4. Lignes du journal.
local l = F.ligne_attendu(s, 30, by["fer-revenu"], "scarlet", "OK", 3, 90)
check(l == "[FO-SCEN] famine-fer-attaque min 30 | attendu fer-revenu@scarlet : OK delai 3 min (attendu debit:iron-plate >= 90)", l)
l = F.ligne_attendu(s, 25, by["tourelles-reapprovisionnees"], "azure", "ECHEC", 2, 0)
check(l == "[FO-SCEN] famine-fer-attaque min 25 | attendu tourelles-reapprovisionnees@azure : ECHEC 2 (attendu <= 0)", l)
l = F.ligne_releve(s, 3, "amber", { b = 1.5, a = 2 })
check(l == "[FO-SCEN] famine-fer-attaque releve min 3 amber | a=2 b=1.50", l)
check(#F.actions_a(s, 20) == 2 and #F.actions_a(s, 19) == 0, "actions à la minute 20")
local eq = F.equipes({ equipes = { "player", "azure" } }, { "scarlet", "player", "azure" })
check(#eq == 2 and eq[1] == "azure" and eq[2] == "player", "équipes filtrées et triées")
check(F.a_detruire({ part = 0.5 }, 5) == 3 and F.a_detruire({ n = 9 }, 4) == 4, "a_detruire")

print(string.format("s43 scen-moteur : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
