--[[
  Lot AMELIO-CRAFTS : tables de calcul des chaînes en jeu (Markdown), tirées de shared/content/crafts.lua.
    lua5.2 tools/crafts_tables.lua > tables.md
  1. recettes : âge, machine de référence (vitesse), durée, ingrédients, produits, produit principal par minute et par
     machine (sans module), origine (X0, X0 avec écart, X3, hors X0) ;
  2. technologies : âge, packs, unités après l'allègement QX9, prérequis, déblocages ;
  3. bilan matière des variantes contre la recette vanilla de référence (C.bilan : sous-produits du mod gratuits).
]]
package.path = "./?.lua;" .. package.path
local C = require("shared.content.crafts")

local function list(l)
  local o = {}
  for _, i in ipairs(l) do o[#o + 1] = string.format("%g %s", i[2], i[1]) end
  return #o > 0 and table.concat(o, " + ") or "rien"
end

print("## Recettes du lot (débits sans module)\n")
print("| Recette | Âge | Machine (vitesse) | Durée | Ingrédients | Produits | Principal / min / machine | Origine |")
print("|---|---|---|---|---|---|---|---|")
local rates = {}
for _, r in ipairs(C.rates()) do rates[r.recipe] = r end
for _, r in ipairs(C.all_recipes()) do
  local q = rates[r.name]
  local origin = r.x3 and "X3" or (r.x0 and ((#r.subst > 0 or (r.dropped and #r.dropped > 0) or r.ecart) and "X0, écart" or "X0") or "hors X0")
  local rate = q.main and string.format("%.1f %s", q.per_min, q.main) or string.format("puits (%.0f fabrications)", q.per_min)
  print(string.format("| %s | %s | %s (%.2f) | %g s | %s | %s | %s | %s |", r.name, tostring(r.epoch), tostring(q.machine),
    q.speed or 0, r.time, list(r.ingredients), list(r.results), rate, origin))
end

print("\n## Technologies du lot\n")
print("| Technologie | Âge | Packs | Unités (après QX9) | Prérequis | Débloque |")
print("|---|---|---|---|---|---|")
for _, t in ipairs(C.TECHS) do
  local packs = {}
  for _, p in ipairs(C.packs(t.epoch)) do packs[#packs + 1] = (p:gsub("%-science%-pack", "")) end
  print(string.format("| %s | %d | %s | %d × %d s | %s | %s |", t.name, t.epoch, table.concat(packs, ", "), C.tech_count(t), t.time,
    table.concat(t.prerequisites, ", "), table.concat(t.unlocks, ", ")))
end

print("\n## Effet sur les monnaies des niveaux (MU des matières premières, 1 MU = 1 plaque de fer, fluides 0,1)\n")
print("| Âge | Monnaie | Variante | MU vanilla | MU variante | Écart |")
print("|---|---|---|---|---|---|")
for _, r in ipairs(C.currency_impact(require("shared.levels.config").epoch_materials)) do
  print(string.format("| %d | %s | %s | %.2f | %.2f | %+.0f %% |", r.epoch, r.item, r.recipe, r.vanilla_mu, r.variant_mu, 100 * r.delta))
end

print("\n## Bilan matière des variantes (par unité du produit, sous-produits du mod gratuits)\n")
print("| Variante | Produit | Variante : matières | Vanilla : matières | Économise | Coûte en plus |")
print("|---|---|---|---|---|---|")
local function f(t)
  local o = {}
  for _, m in ipairs(C.RAW_ORDER) do if (t[m] or 0) > 0 then o[#o + 1] = string.format("%s %.2f", m, t[m]) end end
  return #o > 0 and table.concat(o, ", ") or "rien"
end
for _, r in ipairs(C.bilan()) do
  print(string.format("| %s | %s | %s | %s | %s | %s |", r.recipe, r.product, f(r.variant), f(r.vanilla),
    table.concat(r.saves, ", "), #r.costs > 0 and table.concat(r.costs, ", ") or "—"))
end
