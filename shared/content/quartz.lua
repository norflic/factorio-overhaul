--[[
  Lot X3-MINERAIS (30/10) : le QUARTZ FILONIEN et la FONDERIE DE PUCES d'X3 (chaîne A, âge 10) EN JEU, comme VOIES :
    quartz → creuset de quartz fondu (four à arc) ; silicium pur + creuset → lingot (tireuse de cristal, Czochralski) ;
    lingot + poudre de cristal + eau → 40 TRANCHES SCIÉES (taillerie ; variante de la tranche de la salle blanche) ;
    résine époxy + huile légère + soufre → résine photosensible ; verre + tungstène + circuit avancé → photomasque ;
    laser à cristal (taillé, lentilles, bobines, ALUMINIUM) → lithographe à cristal ;
    tranches + masque + résine photosensible + acide → TRANCHES GRAVÉES (lithographe) ;
    tranches gravées + 2 CARTES IMPRIMÉES (étain) + circuits → PROCESSEUR GRAVÉ (variante du processeur vanilla).
  Les plaques d'étain et d'aluminium (piste RESSOURCES, 0.6.22) servent ainsi à l'âge 10 : l'étain par la carte imprimée de
  chaque processeur gravé, l'aluminium par le laser de chaque lithographe.

  Lua PUR (tests/quartz_test.lua) ; prototypes : prototypes/quartz.lua ; gisement : shared/content/world.lua (quartz).
  Rien n'est inventé : noms, recettes, bâtiments et technologie viennent de shared/content/x3.lua (règle « des voies, jamais
  une porte » : aucune recette vanilla ni d'X0 n'est touchée, le quartz n'est pas encore obligatoire). DEUX écarts, déclarés :
    1. le laser à cristal (X3 : âge 7, technologie « Servomécanismes », absente du jeu car elle ouvre le drone laser, D-20 (2)
       non conçu) est ouvert par la fonderie de puces, son seul usage en jeu ; la fonderie prend pour prérequis ceux des
       servomécanismes qui sont en jeu (aluminium, circuits imprimés) et la taillerie (lentilles du laser) ;
    2. le module de mémoire et la carte graphique (X3, même technologie) NE sont PAS mis en jeu : leur seul débouché est le
       centre de calcul (chaîne B), dont le « calcul » est à refaire par script (D-20 (4)) : ils seraient des objets sans usage.
  D-20 (1) (décision du DC, R-QCM-27a : « fonderie de puces OBLIGATOIRE à l'âge 10 ») n'est PAS appliquée ici : la rendre
  obligatoire rend aussi obligatoires la cassitérite (carte imprimée du processeur gravé) et la bauxite (laser du lithographe)
  et change le chemin des PNJ ; c'est une question au DC (rapport du lot), puis un lot court (Q.MANDATORY_STEP).
]]

local X3 = require("shared.content.x3")
local C = require("shared.content.crafts")
local Sn = require("shared.content.tin")
local B = require("shared.content.bauxite")

local Q = {}

Q.ORE = "fo-vein-quartz"
Q.ITEMS = { "fo-quartz-crucible", "fo-silicon-ingot", "fo-photomask", "fo-etched-wafer", "fo-crystal-laser" }
Q.FLUIDS = { "fo-photoresist" }
-- Recettes d'X3 mises en jeu (ordre d'affichage). variant : la recette rend un objet déjà en jeu par une autre voie.
Q.RECIPES = {
  { name = "fo-quartz-crucible" },
  { name = "fo-silicon-ingot" },
  { name = "fo-wafer-sawing", variant = "fo-silicon-wafer" },
  { name = "fo-photoresist" },
  { name = "fo-photomask" },
  { name = "fo-crystal-laser" },
  { name = "fo-etched-wafer" },
  { name = "fo-etched-processor", variant = "processing-unit" },
}
-- Recettes d'X3 de la même technologie laissées hors jeu (écart 2 ci-dessus).
Q.LEFT_OUT = { "fo-memory-module", "fo-graphics-card" }
-- Bâtiments (X3) : visuel PROVISOIRE, copies teintées (X3 : « copie teintée de la centrifugeuse », « d'assembling-machine-3,
-- étirée en 4 × 4 »). side : côté de la machine copiée (les images sont mises à l'échelle du côté d'X3).
Q.BUILDINGS = {
  { name = "fo-crystal-puller", copy = { "assembling-machine", "centrifuge" }, side = 3, tint = { r = 0.86, g = 0.90, b = 1.00 } },
  { name = "fo-crystal-lithograph", copy = { "assembling-machine", "assembling-machine-3" }, side = 3,
    tint = { r = 0.70, g = 0.88, b = 1.00 } },
}
-- Technologie d'X3 (âge 10). Unités : X3 ne les chiffre pas ; 400, celles de la technologie de l'âge 10 la plus chère du lot
-- AMELIO-CRAFTS (fo-silicon), règle QX9 par C.tech_count (même règle que la piste BAUXITE).
Q.TECHS = {
  { name = "fo-chip-foundry", x3 = "fo-chip-foundry", epoch = 10, count = 400, time = 30,
    -- X3 : fo-silicon, fo-servo-mechanisms ; les prérequis des servomécanismes en jeu (aluminium, circuits imprimés) ; la
    -- taillerie (lentilles et cristal taillé du laser) ; les processeurs vanilla (recette du lithographe).
    prerequisites = { "fo-silicon", "fo-aluminium", "fo-printed-circuits", "fo-lapidary", "advanced-electronics-2" },
    unlocks = { "fo-quartz-crucible", "fo-crystal-puller", "fo-silicon-ingot", "fo-wafer-sawing", "fo-photoresist", "fo-photomask",
                "fo-crystal-laser", "fo-crystal-lithograph", "fo-etched-wafer", "fo-etched-processor" } },
}
-- Pour D-20 (1), le jour où le DC le confirme : les recettes à retirer de leurs technologies à l'âge 10 pour que le processeur
-- passe par la fonderie (proposition, non appliquée ; rien ne lit ce champ en jeu).
Q.MANDATORY_STEP = {
  hide = { "processing-unit", "fo-cleanroom-processor" },
  becomes_mandatory = { "fo-vein-quartz", "fo-cassiterite", "fo-bauxite" },
  why_fr = "le processeur gravé demande 2 cartes imprimées (étain) et le lithographe un laser à cristal (aluminium)",
}

---------------------------------------------------------------------------------------------------
-- Index d'X3
---------------------------------------------------------------------------------------------------
local item_by, recipe_by, building_by, tech_by = {}, {}, {}, {}
for _, it in ipairs(X3.items) do item_by[it.name] = it end
for _, r in ipairs(X3.recipes) do if not recipe_by[r.name] then recipe_by[r.name] = r end end
for _, b in ipairs(X3.buildings) do building_by[b.name] = b end
for _, t in ipairs(X3.technologies) do tech_by[t.name] = t end

function Q.x3_item(n) return item_by[n] end
function Q.recipe(n) return assert(recipe_by[n], "quartz : recette X3 absente " .. n) end
function Q.building(n) return assert(building_by[n], "quartz : bâtiment X3 absent " .. n) end
function Q.x3_tech(n) return tech_by[n] end
function Q.x3_resource(n)
  for _, r in ipairs(X3.resources) do if r.name == n then return r end end
end

local IN_GAME = { [Q.ORE] = true }
for _, n in ipairs(Q.ITEMS) do IN_GAME[n] = true end
for _, n in ipairs(Q.FLUIDS) do IN_GAME[n] = true end
for _, b in ipairs(Q.BUILDINGS) do IN_GAME[b.name] = true end

--- En jeu avec ce lot (et l'étain, la bauxite, CRAFTS, X1) ?
function Q.present(name)
  return IN_GAME[name] == true or Sn.present(name) or B.present(name) or C.present(name)
end

--- Est-ce un fluide d'X3 ? (nil : pas un objet d'X3)
function Q.is_fluid(name)
  local it = item_by[name]
  if it then return it.type == "fluid" end
  return nil
end

--- Toutes les recettes du lot : procédés, puis bâtiments.
function Q.all_recipes()
  local out = {}
  for _, rr in ipairs(Q.RECIPES) do out[#out + 1] = { name = rr.name, variant = rr.variant } end
  for _, b in ipairs(Q.BUILDINGS) do out[#out + 1] = { name = b.name, building = true } end
  return out
end

--- Unités et packs de la technologie (règles du lot AMELIO-CRAFTS).
function Q.tech_count(t) return C.tech_count(t) end
function Q.packs(k) return C.packs(k) end

local function ing(r, n)
  for _, i in ipairs(r.ingredients) do if i[1] == n then return i[2] end end
  return 0
end

--- Bilan par processeur gravé (une fabrication de chaque à la proportion) : tranches gravées, cartes imprimées, plaques
--- d'étain, tranches de silicium, masques, résine ; contre la voie de la salle blanche (X0) : circuits économisés.
function Q.per_etched_processor()
  local ep = Q.recipe("fo-etched-processor")
  local ew = Q.recipe("fo-etched-wafer")
  local pcb = Q.recipe("fo-printed-circuit-board")
  local n = ep.results[1][2]
  local etched = ing(ep, "fo-etched-wafer") / n
  local boards = ing(ep, "fo-printed-circuit-board") / n
  local per_ew = ew.results[1][2]
  local tin = boards * ing(pcb, "fo-tin-plate") / pcb.results[1][2]
  return {
    etched_wafer = etched, pcb = boards, tin = tin,
    wafer = etched * ing(ew, "fo-silicon-wafer") / per_ew,
    photomask = etched * ing(ew, "fo-photomask") / per_ew,
    photoresist = etched * ing(ew, "fo-photoresist") / per_ew,
    green = ing(ep, "electronic-circuit") / n, red = ing(ep, "advanced-circuit") / n,
  }
end

--- Bilan par tranche sciée : quartz (par le creuset), silicium pur, poudre de cristal, eau.
function Q.per_sawn_wafer()
  local saw = Q.recipe("fo-wafer-sawing")
  local ingot = Q.recipe("fo-silicon-ingot")
  local cru = Q.recipe("fo-quartz-crucible")
  local w = saw.results[1][2]
  local ingots = ing(saw, "fo-silicon-ingot") / w
  local crucibles = ingots * ing(ingot, "fo-quartz-crucible") / ingot.results[1][2]
  return {
    ingot = ingots, crucible = crucibles, quartz = crucibles * ing(cru, "fo-vein-quartz") / cru.results[1][2],
    pure_silicon = ingots * ing(ingot, "fo-pure-silicon") / ingot.results[1][2],
    powder = ing(saw, "fo-crystal-powder") / w, water = ing(saw, "water") / w,
  }
end

return Q
