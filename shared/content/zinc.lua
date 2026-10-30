--[[
  Lot AMELIO-RESSOURCES, piste ZINC (30/10) : la voie du laiton d'X3 (âge 3, Vapeur) EN JEU : blende + charbon → PLAQUE DE
  ZINC + laitier (cornue au four à coke) ; cuivre + zinc → LAITON (haut fourneau) ; verre + engrenages + laiton → 2
  MANOMÈTRES À TUBE DE BOURDON (variante d'X3 : le tube de laiton remplace le tuyau ; la voie d'X0 reste). Le manomètre
  sert en jeu à la torchère (AMELIO-CRAFTS) et au capteur géothermique (piste GÉOTHERMIE).
  Lua PUR (tests/zinc_test.lua) ; prototypes : prototypes/zinc.lua ; gisement : shared/content/world.lua (sphalerite).

  Rien n'est inventé : tout vient de shared/content/x3.lua, déblocages compris (X3.extends : la technologie « Verrerie »
  d'AMELIO-CRAFTS débloque aussi les trois recettes, sans rien demander de plus).
]]

local X3 = require("shared.content.x3")
local C = require("shared.content.crafts")

local Z = {}

Z.ORE = "fo-sphalerite"
Z.ITEMS = { "fo-zinc-plate", "fo-brass" }
Z.RECIPES = {
  { name = "fo-zinc-retort" },
  { name = "fo-brass" },
  { name = "fo-manometer-brass", variant = "fo-manometer" },
}

local item_by, recipe_by, extend_by = {}, {}, {}
for _, it in ipairs(X3.items) do item_by[it.name] = it end
for _, r in ipairs(X3.recipes) do if not recipe_by[r.name] then recipe_by[r.name] = r end end
for _, e in ipairs(X3.extends) do extend_by[e.tech] = e end

--- Technologie d'avant étendue (X3.extends) : la verrerie d'AMELIO-CRAFTS.
Z.EXTEND = assert(extend_by["fo-glassworks"], "zinc : X3.extends sans fo-glassworks")

function Z.x3_item(n) return item_by[n] end
function Z.recipe(n) return assert(recipe_by[n], "zinc : recette X3 absente " .. n) end
function Z.x3_resource(n)
  for _, r in ipairs(X3.resources) do if r.name == n then return r end end
end

local IN_GAME = { [Z.ORE] = true }
for _, n in ipairs(Z.ITEMS) do IN_GAME[n] = true end
function Z.present(name) return IN_GAME[name] == true or C.present(name) end

--- Bilan par manomètre de la variante : laiton, zinc, blende, cuivre (une fabrication de chaque à la proportion), et le
--- tuyau économisé contre la voie d'X0 (1 tuyau par manomètre).
function Z.per_manometer()
  local m = Z.recipe("fo-manometer-brass")
  local b = Z.recipe("fo-brass")
  local zr = Z.recipe("fo-zinc-retort")
  local function ing(r, n) for _, i in ipairs(r.ingredients) do if i[1] == n then return i[2] end end return 0 end
  local brass = ing(m, "fo-brass") / m.results[1][2]
  local zinc = brass * ing(b, "fo-zinc-plate") / b.results[1][2]
  local copper = brass * ing(b, "copper-plate") / b.results[1][2]
  local ore = zinc * ing(zr, "fo-sphalerite") / zr.results[1][2]
  return { brass = brass, zinc = zinc, copper = copper, sphalerite = ore, glass = ing(m, "fo-glass") / m.results[1][2] }
end

return Z
