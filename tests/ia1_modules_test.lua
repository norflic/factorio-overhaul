--[[
  Tests hors jeu des gabarits de modules (shared/team/modules.lua, lot IA1-c, docs/EQUIPES_PNJ.md §6.4).
  Usage, depuis la racine du mod :   lua5.2 tests/ia1_modules_test.lua

  Vérifie : recettes du modèle contre tests/fixtures/recipes.lua (vanilla + mod) ; flot maximal ; catalogue (blocs
  des époques 1 à 4 : fer, cuivre, circuits verts, packs rouges et verts, vapeur, chevalet, raffinerie, usine
  chimique) contrôlé sans erreur ; emprises ≤ 24 × 24 ; époques calculées sur X0 ; emprises ACTUELLES des bâtiments
  à niveaux (L.footprint) ; rotations (même nominal dans les 4 sens, chevalets refusés) ; déterminisme (double
  génération, sérialisation canonique) ; chiffres du §6.4 ; MUTANTS : chaque défaut injecté (chevauchement, bras
  retourné, piquage retiré, fluides mêlés, poteau retiré, port retourné, liaison affaiblie, voies mêlées, emprise trop
  grande, points d'appui retirés, catégorie impossible, nominal falsifié, foreuse retournée, bâtiments à niveaux posés
  au pas du niveau 1…) doit être refusé par le contrôle avec la bonne raison.
]]

package.path = "./?.lua;" .. package.path
local M = require("shared.team.modules")
local L = require("shared.levels.config")
local RECIPES = require("tests.fixtures.recipes")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local function deep(v)
  if type(v) ~= "table" then return v end
  local o = {}
  for k, x in pairs(v) do o[k] = deep(x) end
  return o
end
local function any_match(errs, pat)
  for _, e in ipairs(errs) do if e:find(pat, 1, true) then return true end end
  return false
end
local function first(errs) return errs[1] or "(aucune erreur)" end

---------------------------------------------------------------------------------------------------
section("Recettes du modèle contre tests/fixtures/recipes.lua")
for _, name in ipairs(M.recipe_names()) do
  local r, f = M.RECIPES[name], RECIPES[name]
  check(f ~= nil, "recette " .. name .. " présente dans la fixture")
  if f then
    check(math.abs(f.energy - r.time) < 1e-9, name .. " : durée " .. tostring(f.energy) .. " = " .. r.time)
    check(f.category == r.category or (f.category == nil and r.category == "crafting"), name .. " : catégorie " .. tostring(f.category))
    local function same(a, b)
      if #a ~= #b then return false end
      for i = 1, #a do
        if a[i].name ~= b[i].name or a[i].amount ~= b[i].amount then return false end
        if (a[i].type == "fluid") ~= (b[i].fluid == true) then return false end
      end
      return true
    end
    -- ordre des ingrédients : celui de data/base (il fixe les boîtes à fluide des recettes sans fluidbox_index)
    check(same(f.ingredients, r.ingredients), name .. " : ingrédients (ordre compris)")
    check(same(f.products, r.products), name .. " : produits")
  end
end

---------------------------------------------------------------------------------------------------
section("Flot maximal")
check(M.maxflow(4, { { 1, 2, 3 }, { 2, 3, 2 }, { 3, 4, 5 }, { 1, 3, 1 } }, 1, 4) == 3, "flot 3 sur le graphe en losange")
check(M.maxflow(3, { { 1, 2, math.huge }, { 2, 3, 1 } }, 1, 3) == 1, "capacité infinie bornée par l'arête suivante")
check(M.maxflow(4, { { 1, 2, 1 }, { 3, 4, 1 } }, 1, 4) == 0, "graphe coupé : flot nul")
check(math.abs(M.maxflow(5, { { 1, 2, 0.5 }, { 1, 3, 0.25 }, { 2, 4, 1 }, { 3, 4, 1 }, { 4, 5, 0.6 } }, 1, 5) - 0.6) < 1e-12, "flot fractionnaire borné par le puits")

---------------------------------------------------------------------------------------------------
section("Catalogue : contrôle de chaque gabarit")
local cat = M.catalogue()
check(#cat >= 20, "au moins 20 gabarits (" .. #cat .. ")")
local by = {}
for _, g in ipairs(cat) do
  check(by[g.key] == nil, "clé unique : " .. g.key)
  by[g.key] = g
  local errs, rep = M.check(g)
  check(#errs == 0, g.key .. " sans erreur : " .. first(errs))
  check(g.w <= 24 and g.h <= 24, g.key .. " : emprise " .. g.w .. "×" .. g.h .. " ≤ 24×24")
  check(g.epoch >= 1 and g.epoch <= 4, g.key .. " : époque " .. g.epoch .. " (1 à 4)")
  local n_out = 0
  for _ in pairs(g.nominal) do n_out = n_out + 1 end
  check(n_out > 0 or g.labs ~= nil, g.key .. " : un débit nominal")
  check(#g.anchors > 0, g.key .. " : points d'appui")
  check(#g.unlocks > 0, g.key .. " : recettes à débloquer listées")
  for _, p in ipairs(g.ports) do check(g.entities[p.ent] ~= nil, g.key .. " : port vers une entité") end
end
-- blocs demandés (époques 1 à 4)
local wanted = {
  { "avant-poste-fer", "iron-plate" }, { "avant-poste-cuivre", "copper-plate" },
  { "fonderie-fer-pierre", "iron-plate" }, { "fonderie-cuivre-pierre", "copper-plate" }, { "fonderie-fer-acier", "iron-plate" },
  { "foreuses-fer", "iron-ore" }, { "foreuses-cuivre", "copper-ore" }, { "foreuses-charbon", "coal" },
  { "circuits-verts", "electronic-circuit" }, { "packs-rouges", "automation-science-pack" },
  { "packs-verts", "logistic-science-pack" }, { "centrale-vapeur-2", "electricity-kw" },
  { "chevalets-4", "crude-oil" }, { "raffinerie-2", "petroleum-gas" }, { "plastique-2", "plastic-bar" },
  { "soufre-2", "sulfur" }, { "petrole-plastique", "plastic-bar" }, { "moteurs", "engine-unit" },
  { "circuits-rouges", "advanced-circuit" }, { "engrenages", "iron-gear-wheel" },
}
for _, w in ipairs(wanted) do
  local g = by[w[1]]
  check(g ~= nil and (g.nominal[w[2]] or 0) > 0, "bloc demandé : " .. w[1] .. " produit " .. w[2])
end
check(by["labos-4"] and by["labos-4"].inputs["automation-science-pack"] > 0, "bloc labos : consomme des packs rouges")
-- époques (X0) : un bloc pour les époques 1, 3 et 4 ; l'époque 2 n'en a pas en propre (voir NOTES : acier sans
-- électricité = foreuse et four à combustion, déjà l'avant-poste ; le four en acier exige des bras électriques)
local ep = {}
for _, g in ipairs(cat) do ep[g.epoch] = (ep[g.epoch] or 0) + 1 end
check((ep[1] or 0) >= 2 and (ep[3] or 0) >= 8 and (ep[4] or 0) >= 6, string.format("époques : 1→%d, 3→%d, 4→%d", ep[1] or 0, ep[3] or 0, ep[4] or 0))
check(by["avant-poste-fer"].epoch == 1, "avant-poste à combustion : époque 1")
check(by["centrale-vapeur-2"].epoch == 3, "centrale à vapeur : époque 3")
check(by["chevalets-4"].epoch == 4 and by["raffinerie-2"].epoch == 4 and by["plastique-2"].epoch == 4, "pétrole et chimie : époque 4")
check(by["fonderie-fer-acier"].epoch == 3, "fonderie électrique : époque 3 (électricité), même en fours en acier (époque 2)")
check(by["fonderie-fer-acier-n7"].epoch == 4, "four au niveau 7 : époque 4 (L.epoch_of)")

---------------------------------------------------------------------------------------------------
section("Débits nominaux (chiffres vanilla, EQUIPES_PNJ §6.1 et §6.4)")
local function near(a, b) return math.abs(a - b) < 1e-9 end
check(near(by["fonderie-fer-pierre"].nominal["iron-plate"], 16 / 3.2), "16 fours en pierre : 5 plaques/s")
check(near(by["fonderie-fer-acier"].nominal["iron-plate"], 10 * 2 / 3.2), "10 fours en acier : 6,25 plaques/s")
check(near(by["foreuses-fer"].nominal["iron-ore"], 12 * 0.5), "12 foreuses électriques : 6 minerais/s")
check(near(by["circuits-verts"].nominal["electronic-circuit"], 3), "îlot C K C K C : 3 circuits/s (2 assembleurs 2, rapport 3:2)")
check(near(by["circuits-rouges"].nominal["advanced-circuit"], 4 * 0.125), "4 assembleurs 2 de circuits rouges : 0,125/s chacun")
check(near(by["centrale-vapeur-2"].nominal["electricity-kw"], 3600), "2 chaudières, 4 machines : 3,6 MW")
check(near(by["centrale-vapeur-2"].inputs["coal"], 2 * 1800 / 4000), "centrale : 0,45 charbon/s par chaudière")
check(near(by["chevalets-4"].nominal["crude-oil"], 40), "4 chevalets à 100 % : 40 brut/s")
check(near(by["raffinerie-2"].nominal["petroleum-gas"], 18) and near(by["raffinerie-2"].inputs["crude-oil"], 40), "2 raffineries de base : 18 gaz/s pour 40 brut/s")
check(near(by["plastique-2"].nominal["plastic-bar"], 4) and near(by["plastique-2"].inputs["petroleum-gas"], 40), "2 usines de plastique : 4/s pour 40 gaz/s")
check(near(by["soufre-2"].nominal["sulfur"], 4) and near(by["soufre-2"].inputs["water"], 60), "2 usines de soufre : 4/s pour 60 eau/s et 60 gaz/s")
check(near(by["petrole-plastique"].nominal["plastic-bar"], 0.9), "pétrole sur place : 9 gaz/s → 0,9 plastique/s (usine à 45 %)")
check(near(by["packs-rouges"].nominal["automation-science-pack"], 0.75), "5 assembleurs de packs rouges : 0,75/s")
check(near(by["packs-verts"].nominal["logistic-science-pack"], 0.625), "5 assembleurs de packs verts : 0,625/s")
check(near(by["avant-poste-fer"].nominal["iron-plate"], 1.5), "6 paires foreuse à combustion → four : 1,5 plaque/s (foreuse limitante)")
check(near(by["moteurs"].nominal["engine-unit"], 0.15), "2 assembleurs de moteurs : 0,15/s")
check(near(M.power_kw("assembling-machine-2"), 155), "assembleur 2 : 150 kW + ponction 5 kW")
-- §6.4 : « colonne de 24 fours en pierre : 7,5 plaques/s » tient sur une voie de minerai ; « en acier : 15/s »
-- n'y tient PAS (une voie de 7,5/s) : le contrôle doit le dire.
local s24 = M.GEN.smelter("stone-furnace", "iron-ore", 12)
local e24 = M.check(s24)
check(#e24 == 0 and near(s24.nominal["iron-plate"], 7.5), "24 fours en pierre : 7,5 plaques/s, contrôle vert (" .. first(e24) .. ")")
local ok24, steel24 = pcall(M.GEN.smelter, "steel-furnace", "iron-ore", 12)
local esteel = ok24 and M.check(steel24) or { tostring(steel24) }
check(any_match(esteel, "débit de iron-ore"), "24 fours en acier (15/s) sur une seule voie de minerai : refusé (" .. first(esteel) .. ")")

---------------------------------------------------------------------------------------------------
section("Bâtiments à niveaux : emprises ACTUELLES (L.footprints, 0.4.3)")
for _, fam in ipairs({ "furnace", "assembler", "drill" }) do
  local f = L.by_key[fam]
  for _, n in ipairs({ 1, 2, 6, 7, 8, 12, 13, 19, 25, 30 }) do
    local name = L.name(f, n)
    local sp = M.spec(name)
    check(sp ~= nil and sp.w == L.footprint(f, n) and sp.h == L.footprint(f, n), name .. " : côté " .. tostring(sp and sp.w) .. " = L.footprint " .. L.footprint(f, n))
  end
end
local a7 = M.spec(L.name(L.by_key.assembler, 7))
check(near(a7.speed, 0.75 * (1 + 0.08 * 6)), "assembleur niveau 7 : vitesse 0,75 × 1,48")
local d7 = M.spec(L.name(L.by_key.drill, 7))
check(near(d7.drop[1], -0.5) and near(d7.drop[2], -2.35) and near(d7.radius, 2.99), "foreuse niveau 7 (4×4) : dépôt (−0,5 ; −2,35), rayon 2,99 (règle de shared/levels/points.lua)")
check(by["circuits-verts-n7"].w == 24 and by["circuits-verts-n7"].entities[1] ~= nil, "îlot de circuits au niveau 7 : 24 de large (machines 4×4)")
for _, key in ipairs({ "fonderie-fer-acier-n7", "foreuses-fer-n7", "circuits-verts-n7" }) do
  local lv = false
  for _, e in ipairs(by[key].entities) do if e.name:find("^fo%-lvl%-") then lv = true end end
  check(lv, key .. " : pose de vrais bâtiments à niveaux (fo-lvl-*)")
end
-- mutant : bâtiments du niveau 7 posés au pas du niveau 1 (3 + 1) : chevauchement
do
  local g = deep(by["circuits-verts"])
  for _, e in ipairs(g.entities) do
    if e.name == "assembling-machine-2" then e.name = L.name(L.by_key.assembler, 7); e.x, e.y = e.x + 0.5, e.y + 0.5 end
  end
  local errs = M.check(g)
  check(any_match(errs, "chevauchement"), "mutant : assembleurs 4×4 au pas du 3×3 refusés (" .. first(errs) .. ")")
end
-- mutant : four de niveau 13 (4×4) dans la colonne du niveau 7 (3×3)
do
  local g = deep(by["fonderie-fer-acier-n7"])
  for _, e in ipairs(g.entities) do
    if e.name == L.name(L.by_key.furnace, 7) then e.name = L.name(L.by_key.furnace, 13); e.x, e.y = e.x + 0.5, e.y + 0.5; break end
  end
  local errs = M.check(g)
  check(any_match(errs, "chevauchement") or any_match(errs, "rien"), "mutant : un four 4×4 glissé dans une colonne de 3×3 refusé (" .. first(errs) .. ")")
end

---------------------------------------------------------------------------------------------------
section("Rotations (matrices entières)")
for _, g in ipairs(cat) do
  for k = 1, 3 do
    local r, why = M.rotate(g, k)
    if g.no_rotate then
      check(r == nil and why ~= nil, g.key .. " : rotation refusée (" .. tostring(why) .. ")")
    else
      local errs, rep = M.check(r)
      check(#errs == 0, g.key .. " tourné de " .. k .. " quart(s) : " .. first(errs))
      local same = true
      for it, v in pairs(g.nominal) do if not near(rep.outputs[it] or 0, v) then same = false end end
      check(same, g.key .. " tourné de " .. k .. " : même débit nominal")
      check((k % 2 == 1 and r.w == g.h and r.h == g.w) or (k % 2 == 0 and r.w == g.w and r.h == g.h), g.key .. " tourné : emprise échangée")
    end
  end
  if not g.no_rotate then
    local r4 = M.rotate(M.rotate(M.rotate(M.rotate(g, 1), 1), 1), 1)
    r4.rotation = g.rotation
    check(M.serialize(r4.entities) == M.serialize(g.entities), g.key .. " : quatre quarts de tour = identité")
  end
end
do
  local inst = M.instantiate(by["circuits-verts"], 1, 100, -40)
  local g1 = M.rotate(by["circuits-verts"], 1)
  check(inst.entities[1].position.x == 100 + g1.entities[1].x and inst.entities[1].position.y == -40 + g1.entities[1].y, "instanciation : décalage entier ajouté aux coordonnées tournées")
  check(inst.w == by["circuits-verts"].h, "instanciation tournée : largeur = hauteur du gabarit")
end

---------------------------------------------------------------------------------------------------
section("Déterminisme")
do
  local a = M.serialize({ M.GEN.circuits(), M.GEN.green_packs(), M.GEN.sulfur(2), M.GEN.steam(2), M.GEN.drills("iron-ore", 6) })
  local b = M.serialize({ M.GEN.circuits(), M.GEN.green_packs(), M.GEN.sulfur(2), M.GEN.steam(2), M.GEN.drills("iron-ore", 6) })
  check(a == b, "double génération : sérialisation identique (" .. #a .. " octets)")
  local all = M.serialize(cat)
  local h = 0
  for i = 1, #all do h = (h * 31 + all:byte(i)) % 4294967291 end
  print(string.format("   empreinte du catalogue : %d gabarits, %d octets, %.0f", #cat, #all, h))
  local e1 = M.check(by["packs-verts"])
  local e2 = M.check(deep(by["packs-verts"]))
  check(#e1 == #e2, "contrôle d'une copie profonde : même résultat")
  for _, g in ipairs(cat) do
    for _, e in ipairs(g.entities) do
      if type(e.x) ~= "number" or (e.x * 2) % 1 ~= 0 or (e.y * 2) % 1 ~= 0 then check(false, g.key .. " : coordonnée non demi-entière") end
    end
  end
  check(true, "coordonnées demi-entières (exactes en binaire)")
end

---------------------------------------------------------------------------------------------------
section("Contrôle : voies, fluides, électricité, ports (constats sur le catalogue)")
do
  local _, rep = M.check(by["packs-verts"])
  local lanes
  for pi, p in ipairs(by["packs-verts"].ports) do if p.io == "out" then lanes = rep.lanes[pi] end end
  check(lanes and #lanes[1] == 1 and #lanes[2] == 0 or (lanes and #lanes[2] == 1), "packs verts : une seule voie en sortie (packs)")
  -- jonction : bras et convoyeurs sur deux voies différentes
  local g = by["packs-verts"]
  local jn
  for i, e in ipairs(g.entities) do if e.name == "transport-belt" and e.dir == M.S and e.x == 5.5 and e.y == 6.5 then jn = i end end
  check(jn ~= nil, "packs verts : tuile de jonction trouvée")
  local _, rj = M.analyze(g), nil
  local _, r2 = M.check(g)
  local _ = r2
  local _, rep2 = M.check(g)
  check(rep2 ~= nil, "packs verts : analyse complète")
  local _, rs = M.check(by["soufre-2"])
  local fl = {}
  for _, n in ipairs(rs.fluid_nets) do if n.fluid then fl[n.fluid] = (fl[n.fluid] or 0) + 1 end end
  check(fl["water"] == 1 and fl["petroleum-gas"] == 1, "soufre : un seul réseau d'eau et un seul de gaz (souterrains croisés)")
  local _, rr = M.check(by["raffinerie-2"])
  local nets = 0
  for _, n in ipairs(rr.fluid_nets) do if n.boxes >= 2 then nets = nets + 1 end end
  check(nets == 2, "raffinerie : 2 réseaux raccordés (brut, gaz), raccords inutilisés libres (" .. nets .. ")")
  local _, rv = M.check(by["centrale-vapeur-2"])
  local steam = 0
  for _, n in ipairs(rv.fluid_nets) do if n.fluid == "steam" then steam = steam + 1 end end
  check(steam == 2, "centrale : un réseau de vapeur par chaudière (2)")
end

---------------------------------------------------------------------------------------------------
section("Mutants : le contrôle refuse chaque défaut injecté")
local function mutant(name, key, fn, pattern)
  local g = deep(by[key])
  local ok, why = pcall(fn, g)
  if not ok then check(false, "mutant « " .. name .. " » : " .. tostring(why)); return end
  local errs = M.check(g)
  check(#errs > 0 and (not pattern or any_match(errs, pattern)), "mutant « " .. name .. " » refusé (" .. first(errs) .. ")")
end
local function find(g, pred) for i, e in ipairs(g.entities) do if pred(e, i) then return i, e end end end
local function idx_of_port(g, io, kind) for pi, p in ipairs(g.ports) do if p.io == io and (not kind or p.kind == kind) then return pi, p end end end

mutant("chevauchement", "engrenages", function(g)
  local _, a = find(g, function(e) return e.name == "assembling-machine-2" end)
  local i, b = find(g, function(e, j) return e.name == "assembling-machine-2" and e.x ~= a.x end)
  b.x = a.x + 1
end, "chevauchement")
mutant("bras retourné", "circuits-verts", function(g)
  local _, e = find(g, function(x) return x.name == "fast-inserter" and x.dir == M.N and x.y == 1.5 end)
  e.dir = M.S
end)
mutant("piquage de brut retiré", "raffinerie-2", function(g)
  local i = find(g, function(e) return e.name == "pipe" and e.y == 7.5 end)
  table.remove(g.entities, i)
  for _, p in ipairs(g.ports) do if p.ent > i then p.ent = p.ent - 1 end end
  if g.power_pole and g.power_pole > i then g.power_pole = g.power_pole - 1 end
end, "non raccordée")
mutant("fluides mêlés (souterrain remplacé par un tuyau)", "soufre-2", function(g)
  -- souterrain de gaz qui passe sous le piquage d'eau suivant : en tuyau, il touche les deux
  local _, e = find(g, function(x) return x.name == "pipe-to-ground" and x.x == 5.5 and x.y == 1.5 end)
  e.name = "pipe"
end, "mêlés")
mutant("poteau retiré", "fonderie-fer-pierre", function(g)
  local i = find(g, function(e) return e.name == "medium-electric-pole" end)
  -- remplacer par un coffre (indices inchangés)
  g.entities[i].name = "wooden-chest"
end, "poteaux")
mutant("tapis de sortie retourné", "engrenages", function(g)
  local _, p = idx_of_port(g, "out", "tapis")
  g.entities[p.ent].dir = M.W
end)
mutant("liaison affaiblie (bras rapide → bras simple)", "circuits-verts", function(g)
  for _, e in ipairs(g.entities) do if e.name == "fast-inserter" and (e.dir == M.W or e.dir == M.E) then e.name = "inserter" end end
end, "débit de copper-cable")
mutant("bras de sortie trop lent", "engrenages", function(g)
  for _, e in ipairs(g.entities) do if e.name == "fast-inserter" and e.y == 5.5 then e.name = "burner-inserter" end end
end)
mutant("voies mêlées (jonction remplacée par un tapis droit)", "packs-verts", function(g)
  for _, e in ipairs(g.entities) do
    if e.name == "transport-belt" and e.y == 6.5 and e.x > 5.5 and e.x < 11 then e.dir = M.E end
  end
  for _, e in ipairs(g.entities) do if e.name == "transport-belt" and e.y == 6.5 and e.x == 5.5 then e.dir = M.E end end
end)
mutant("emprise trop grande", "engrenages", function(g) g.w = 30 end, "emprise")
mutant("points d'appui retirés", "circuits-verts-n7", function(g) g.anchors = { { x = -2, y = -2 } } end, "point d'appui")
mutant("catégorie impossible", "engrenages", function(g)
  local _, e = find(g, function(x) return x.name == "assembling-machine-2" end)
  e.recipe = "basic-oil-processing"
end, "catégorie")
mutant("nominal falsifié", "circuits-verts", function(g) g.nominal["electronic-circuit"] = 4 end, "débit nominal")
mutant("foreuse retournée", "foreuses-fer", function(g)
  local _, e = find(g, function(x) return x.name == "electric-mining-drill" end)
  e.dir = M.W
end)
mutant("pompe de rive retirée", "centrale-vapeur-2", function(g)
  local _, e = find(g, function(x) return x.name == "offshore-pump" end)
  e.name = "wooden-chest"
end)
mutant("eau non déclarée devant la pompe", "centrale-vapeur-2", function(g) g.water = {} end, "rive")
mutant("bras à combustion sur un convoyeur de sortie", "engrenages", function(g)
  local _, e = find(g, function(x) return x.name == "fast-inserter" and x.y == 5.5 end)
  e.name = "burner-inserter"
end, "combustion")
mutant("hors de la grille", "moteurs", function(g)
  local _, e = find(g, function(x) return x.name == "assembling-machine-2" end)
  e.x = e.x + 0.5
end, "grille")
mutant("chevalet sans collecteur", "chevalets-4", function(g)
  for _, e in ipairs(g.entities) do if e.name == "pipe" and e.x == 2.5 then e.name = "wooden-chest" end end
end, "non raccordée")
mutant("usine chimique tournée (raccords au sud)", "plastique-2", function(g)
  local _, e = find(g, function(x) return x.name == "chemical-plant" end)
  e.dir = M.S
end)
mutant("labo sans bras", "labos-4", function(g)
  for _, e in ipairs(g.entities) do if e.name == "inserter" then e.name = "wooden-chest" end end
end, "débit")
mutant("port d'entrée à l'intérieur", "plastique-2", function(g)
  local _, p = idx_of_port(g, "in", "tapis")
  local e = g.entities[p.ent]
  e.dir = M.W
end)
mutant("centrale sans charbon", "centrale-vapeur-2", function(g)
  for _, p in ipairs(g.ports) do if p.kind == "tapis" then p.lanes = { nil, nil } end end
end, "coal")

---------------------------------------------------------------------------------------------------
section("Ressources, fils, conduites (R8)")
do
  local rt = M.resource_tiles(by["foreuses-fer"])
  check(#rt >= 12 * 9, "foreuses : tuiles de minerai sous les zones d'extraction (" .. #rt .. ")")
  local wells = 0
  for _, t in ipairs(M.resource_tiles(by["chevalets-4"])) do if t.well then wells = wells + 1 end end
  check(wells == 4, "chevalets : un puits par chevalet")
  for _, key in ipairs({ "fonderie-fer-pierre", "circuits-verts", "plastique-2", "centrale-vapeur-2" }) do
    local g = by[key]
    local np = 0
    for _, e in ipairs(g.entities) do if M.spec(e.name).kind == "pole" then np = np + 1 end end
    check(#M.wires(g) == np - 1, key .. " : arbre de fils (" .. #M.wires(g) .. " fils pour " .. np .. " poteaux)")
  end
  local prev = math.huge
  local mono = true
  for _, r in ipairs(M.PIPE_FLOW) do if r[2] > prev then mono = false end; prev = r[2] end
  check(mono, "table des débits de conduite décroissante (" .. M.PIPE_FLOW_SOURCE .. ")")
  local worst = 0
  for _, g in ipairs(cat) do
    local _, rep = M.check(g)
    for _, n in ipairs(rep.fluid_nets or {}) do
      if n.demand > 0 and n.pipes > 0 then worst = math.max(worst, n.demand / M.pipe_capacity(n.pipes)) end
    end
  end
  check(worst < 0.2, string.format("R8 : conduite la plus chargée des gabarits à %.1f %% de sa capacité (table %s)", 100 * worst, M.PIPE_FLOW_SOURCE))
end

print(string.format("\nBILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
