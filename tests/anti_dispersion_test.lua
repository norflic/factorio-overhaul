-- Lot IA-GARDE : garde anti-dispersion (règle du DC du 11/11), règle pure shared/ai3/anti_dispersion.lua.
-- Lancer : lua5.2 tests/anti_dispersion_test.lua
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1; print("ECHEC : " .. msg) end end

local path = "shared/ai3/anti_dispersion.lua"
local fh = assert(io.open(path, "rb")); local SRC = fh:read("*a"); fh:close()
local function load_rule(mut)
  local s = mut and mut(SRC) or SRC
  local f = assert(load(s, "=anti_dispersion"))
  return f()
end

-- Données de banc : la table des types d'avant-poste (forme de shared/team/config.lua T.outposts), et des données CHANGÉES (preuve
-- « rien en dur » : d'autres noms, la même décision).
local KINDS = {
  a = { resource = "r-brut", product = "r-brut" },
  b = { resource = "r-minerai", product = "p-plaque" },
  c = { resource = "r-cuivre", product = "p-cuivre" },
  d = { resource = "r-pierre", product = "r-pierre" },
}
local KINDS2 = {
  x = { resource = "zz-combustible", product = "zz-combustible" },
  y = { resource = "zz-ore", product = "zz-plate" },
}

local function run(Ad)
  local res = {}
  local function put(k, v) res[#res + 1] = k .. "=" .. tostring(v) end
  local sortes = Ad.demarrage(KINDS)
  put("sorte brut", sortes["r-brut"]); put("sorte minerai", sortes["r-minerai"]); put("sorte pierre", sortes["r-pierre"])
  put("sorte petrole", sortes["r-petrole"])
  local s2 = Ad.demarrage(KINDS2)
  put("sorte2 brut", s2["zz-combustible"]); put("sorte2 minerai", s2["zz-ore"])
  -- seuils : chaque côté (1 contre 2 colonnes, 5 contre 6 assembleurs)
  put("1c 6a", Ad.etat(1, 6).ouvert); put("2c 6a", Ad.etat(2, 6).ouvert); put("2c 5a", Ad.etat(2, 5).ouvert)
  put("3c 9a", Ad.etat(3, 9).ouvert); put("0c 0a", Ad.etat(0, 0).ouvert)
  local ferme, ouvert = Ad.etat(1, 5), Ad.etat(2, 6)
  -- pétrole
  put("petrole ferme", (Ad.permet(ferme, "petrole"))); put("petrole ouvert", (Ad.permet(ouvert, "petrole")))
  put("petrole 2c5a", (Ad.permet(Ad.etat(2, 5), "petrole"))); put("petrole 1c6a", (Ad.permet(Ad.etat(1, 6), "petrole")))
  put("petrole sans mesure", (Ad.permet(nil, "petrole")))
  -- exploration lointaine
  put("explo petrole ferme", (Ad.permet(ferme, "exploration", { sorte = sortes["r-petrole"], tenu = false })))
  put("explo petrole ouvert", (Ad.permet(ouvert, "exploration", { sorte = sortes["r-petrole"], tenu = false })))
  put("explo veille ferme", (Ad.permet(ferme, "exploration", { veille = true })))
  put("explo veille ouvert", (Ad.permet(ouvert, "exploration", { veille = true })))
  put("explo fer tenu ferme", (Ad.permet(ferme, "exploration", { sorte = sortes["r-minerai"], tenu = true, manque = true })))
  -- exceptions de démarrage : premier fer, premier cuivre, premier charbon, première pierre, charbon en manque, eau de centrale
  put("explo premier fer", (Ad.permet(ferme, "exploration", { sorte = sortes["r-minerai"], tenu = false })))
  put("explo premier cuivre", (Ad.permet(ferme, "exploration", { sorte = sortes["r-cuivre"], tenu = false })))
  put("explo premier brut", (Ad.permet(ferme, "exploration", { sorte = sortes["r-brut"], tenu = false })))
  put("explo premiere pierre", (Ad.permet(ferme, "exploration", { sorte = sortes["r-pierre"], tenu = false })))
  put("explo brut tenu manque", (Ad.permet(ferme, "exploration", { sorte = sortes["r-brut"], tenu = true, manque = true })))
  put("explo brut tenu sans manque", (Ad.permet(ferme, "exploration", { sorte = sortes["r-brut"], tenu = true, manque = false })))
  put("explo centrale", (Ad.permet(ferme, "exploration", { centrale = true })))
  put("explo2 premier", (Ad.permet(ferme, "exploration", { sorte = s2["zz-ore"], tenu = false })))
  -- sur-stockage
  put("surstock brut ferme", (Ad.permet(ferme, "surstock", { sorte = "brut", manque = false })))
  put("surstock brut ouvert", (Ad.permet(ouvert, "surstock", { sorte = "brut", manque = false })))
  put("surstock brut manque", (Ad.permet(ferme, "surstock", { sorte = "brut", manque = true })))
  put("surstock minerai ferme", (Ad.permet(ferme, "surstock", { sorte = "fondre", manque = false })))
  put("sorte_type brut", Ad.sorte_type(KINDS, "a")); put("sorte_type fondre", Ad.sorte_type(KINDS, "b"))
  -- colonne de fonderie automatisée
  put("col finie active", Ad.colonne({ bande = true, etat = "fini", fours = 5, fours_actifs = 1 }))
  put("col finie froide", Ad.colonne({ bande = true, etat = "fini", fours = 5, fours_actifs = 0 }))
  put("col sans four", Ad.colonne({ bande = true, etat = "fini", fours = 0, fours_actifs = 0 }))
  put("col chantier", Ad.colonne({ bande = true, etat = "chantier", fours = 5, fours_actifs = 3 }))
  put("col reseau charbon", Ad.colonne({ bande = false, etat = "fini", fours = 5, fours_actifs = 3 }))
  -- assembleur actif
  local FOURS = { ["cat-fonte"] = true }
  put("asm travaille", Ad.assembleur({ assembleur = true, recette = "r1", categorie = "cat-a", fours = FOURS, travaille = true }))
  put("asm a fini", Ad.assembleur({ assembleur = true, recette = "r1", categorie = "cat-a", fours = FOURS, travaille = false, fini = 7, fini_avant = 6 }))
  put("asm immobile", Ad.assembleur({ assembleur = true, recette = "r1", categorie = "cat-a", fours = FOURS, travaille = false, fini = 6, fini_avant = 6 }))
  put("asm premiere mesure", Ad.assembleur({ assembleur = true, recette = "r1", categorie = "cat-a", fours = FOURS, travaille = false, fini = 6 }))
  put("asm sans recette", Ad.assembleur({ assembleur = true, recette = nil, travaille = true }))
  put("asm qui fond", Ad.assembleur({ assembleur = true, recette = "r2", categorie = "cat-fonte", fours = FOURS, travaille = true }))
  put("four", Ad.assembleur({ assembleur = false, recette = "r2", categorie = "cat-a", fours = FOURS, travaille = true }))
  -- journal : une ligne aux seuls changements d'état
  local memo = {}
  local l1 = Ad.mesure(memo, Ad.etat(1, 3), "eq", 1.0)
  local l2 = Ad.mesure(memo, Ad.etat(1, 4), "eq", 2.0)
  local l3 = Ad.inhibe(memo, "petrole", "eq", 2.5)
  local l4 = Ad.inhibe(memo, "petrole", "eq", 2.6)
  local l5 = Ad.inhibe(memo, "exploration", "eq", 2.7)
  local l6 = Ad.mesure(memo, Ad.etat(2, 6), "eq", 3.0)
  local l7 = Ad.mesure(memo, Ad.etat(2, 7), "eq", 4.0)
  put("j1", l1 ~= nil); put("j2", l2 ~= nil); put("j3", l3 ~= nil); put("j4", l4 ~= nil); put("j5", l5 ~= nil)
  put("j6", l6 ~= nil); put("j7", l7 ~= nil)
  put("j6 texte", l6 and (l6:find("OUVERT", 1, true) and l6:find("petrole 2", 1, true) and l6:find("exploration lointaine 1", 1, true)) ~= nil)
  put("j1 texte", l1 and (l1:find("FERME", 1, true) and l1:find("colonnes de fonderie automatisees 1/2", 1, true)
    and l1:find("assembleurs actifs 3/6", 1, true)) ~= nil)
  put("j3 texte", l3 and l3:find("premiere decision inhibee : petrole", 1, true) ~= nil)
  put("memo propre", memo.ouvert == true and next(memo.inh) == nil)
  return table.concat(res, ";"), res
end

local Ad = load_rule()
local _, r = run(Ad)
local V = {}
for _, kv in ipairs(r) do local k, v = kv:match("^(.-)=(.*)$"); V[k] = v end
local function is(k, v) check(V[k] == tostring(v), k .. " : attendu " .. tostring(v) .. ", lu " .. tostring(V[k])) end

-- définitions sur les données (et sur des données changées)
is("sorte brut", "brut"); is("sorte minerai", "fondre"); is("sorte pierre", "brut"); is("sorte petrole", nil)
is("sorte2 brut", "brut"); is("sorte2 minerai", "fondre")
-- chaque côté du seuil
is("1c 6a", false); is("2c 6a", true); is("2c 5a", false); is("3c 9a", true); is("0c 0a", false)
-- famille pétrole
is("petrole ferme", false); is("petrole ouvert", true); is("petrole 2c5a", false); is("petrole 1c6a", false)
is("petrole sans mesure", true)
-- famille exploration lointaine
is("explo petrole ferme", false); is("explo petrole ouvert", true); is("explo veille ferme", false); is("explo veille ouvert", true)
is("explo fer tenu ferme", false)
-- exceptions de démarrage
is("explo premier fer", true); is("explo premier cuivre", true); is("explo premier brut", true); is("explo premiere pierre", true)
is("explo brut tenu manque", true); is("explo brut tenu sans manque", false); is("explo centrale", true); is("explo2 premier", true)
-- famille sur-stockage
is("surstock brut ferme", false); is("surstock brut ouvert", true); is("surstock brut manque", true); is("surstock minerai ferme", true)
is("sorte_type brut", "brut"); is("sorte_type fondre", "fondre")
-- colonne
is("col finie active", true); is("col finie froide", false); is("col sans four", false); is("col chantier", false)
is("col reseau charbon", false)
-- assembleur
is("asm travaille", true); is("asm a fini", true); is("asm immobile", false); is("asm premiere mesure", false)
is("asm sans recette", false); is("asm qui fond", false); is("four", false)
-- journal : première mesure, fermeture inchangée muette, première inhibition par famille, ouverture, ouverture inchangée muette
is("j1", true); is("j2", false); is("j3", true); is("j4", false); is("j5", true); is("j6", true); is("j7", false)
is("j6 texte", true); is("j1 texte", true); is("j3 texte", true); is("memo propre", true)

-- déterminisme : deux passages, même sortie
check(run(load_rule()) == run(load_rule()), "deux passages identiques")
-- aucun nom d'objet dans la règle (les noms viennent des données)
check(not SRC:find('"coal"', 1, true) and not SRC:find('"stone"', 1, true) and not SRC:find('"iron', 1, true) and not SRC:find('"crude', 1, true),
  "aucun nom d'objet dans la règle")

-- MUTANTS : chacun doit changer la sortie
local base = run(Ad)
local function differs(mut)
  local okl, M = pcall(load_rule, mut)
  if not okl then return true end
  local okr, out = pcall(run, M)
  return (not okr) or out ~= base
end
local MUT = {
  { "seuil des colonnes à 3", function(s) return (s:gsub("Ad%.COLONNES = 2", "Ad.COLONNES = 3")) end },
  { "seuil des assembleurs à 5", function(s) return (s:gsub("Ad%.ASSEMBLEURS = 6", "Ad.ASSEMBLEURS = 5")) end },
  { "colonnes > au lieu de >=", function(s) return (s:gsub("c >= Ad%.COLONNES", "c > Ad.COLONNES")) end },
  { "ou au lieu de et", function(s) return (s:gsub("c >= Ad%.COLONNES and a >= Ad%.ASSEMBLEURS", "c >= Ad.COLONNES or a >= Ad.ASSEMBLEURS")) end },
  { "pétrole jamais inhibé", function(s) return (s:gsub('if famille == "petrole" then return false, "seuil" end', 'if famille == "petrole" then return true, nil end')) end },
  { "premier gisement oublié", function(s) return (s:gsub('if c%.sorte ~= nil and not c%.tenu then return true, "premier gisement" end', "")) end },
  { "besoin mesuré du brut oublié (exploration)", function(s) return (s:gsub('if c%.sorte == "brut" and c%.manque then return true, "besoin mesure" end', "")) end },
  { "veille permise", function(s) return (s:gsub('return false, "seuil"\n  end\n  if famille == "surstock"', 'return true, nil\n  end\n  if famille == "surstock"')) end },
  { "eau de centrale inhibée", function(s) return (s:gsub('if c%.centrale then return true, "eau de la centrale" end', "")) end },
  { "sur-stockage du minerai à fondre", function(s) return (s:gsub('if c%.sorte ~= "brut" then return true, nil end', "")) end },
  { "besoin mesuré du brut oublié (sur-stockage)", function(s) return (s:gsub('    if c%.manque then return true, "besoin mesure" end\n    return false, "seuil"\n  end\n  return true, nil', '    return false, "seuil"\n  end\n  return true, nil')) end },
  { "colonne froide comptée", function(s) return (s:gsub("and %(b%.fours_actifs or 0%) > 0", "")) end },
  { "four d'assemblage compté", function(s) return (s:gsub("if m%.categorie ~= nil and %(m%.fours or {}%)%[m%.categorie%] then return false end", "")) end },
  { "assembleur immobile compté", function(s) return (s:gsub("%(m%.fini or 0%) > m%.fini_avant", "(m.fini or 0) >= m.fini_avant")) end },
  { "journal à chaque mesure", function(s) return (s:gsub("if avant == etat%.ouvert then return nil end", "")) end },
  { "journal à chaque inhibition", function(s) return (s:gsub("if memo%.dites%[famille%] then return nil end", "")) end },
  { "sorte par nom", function(s) return (s:gsub('%(s%.product == s%.resource%) and "brut" or "fondre"\n', '(s.resource == "coal") and "brut" or "fondre"\n', 1)) end },
}
local refused = 0
for _, m in ipairs(MUT) do
  local d = differs(m[2])
  if d then refused = refused + 1 else print("mutant survivant : " .. m[1]) end
  check(d, "mutant refusé : " .. m[1])
end

print(string.format("[ANTI-DISPERSION] BILAN : %d OK, %d ECHEC(S) (%d mutants refusés sur %d)", ok_n, fail_n, refused, #MUT))
os.exit(fail_n == 0 and 0 or 1)
