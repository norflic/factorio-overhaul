-- Imprime les tables d'équilibrage du contenu (Markdown) depuis shared/content/*.lua.
-- Usage, depuis la racine du mod :   lua5.2 tools/print_content.lua

package.path = "./?.lua;" .. package.path
local Mo = require("shared.content.modules")
local E = require("shared.content.enemies")

local function pct(x) return string.format("%+.0f %%", x * 100) end

print("### Modules (effet d'UN module)\n")
print("| Palier | Vitesse : vitesse / conso | Productivité : prod / vitesse / conso / pollution | Efficacité : conso / pollution |")
print("|---|---|---|---|")
for k = 1, Mo.TIERS do
  local s, p, e = Mo.families.speed.effects, Mo.families.productivity.effects, Mo.families.effectivity.effects
  print(string.format("| %d%s | %s / %s | %s / %s / %s / %s | %s / %s |", k, k <= Mo.VANILLA_TIERS and " (vanilla)" or "",
    pct(s.speed[k]), pct(s.consumption[k]),
    pct(p.productivity[k]), pct(p.speed[k]), pct(p.consumption[k]), pct(p.pollution[k]),
    pct(e.consumption[k]), pct(e.pollution[k])))
end

print("\n### Machine à 4 emplacements remplis du même module\n")
print("| Palier | Vitesse ×4 : cadence / énergie par produit | Productivité ×4 : produits par cycle / énergie par produit |")
print("|---|---|---|")
for k = 1, Mo.TIERS do
  local ms, mp = Mo.metrics("speed", k), Mo.metrics("productivity", k)
  print(string.format("| %d | ×%.2f / ×%.2f | ×%.2f / ×%.2f |", k, ms.speed, ms.energy_per_output, mp.output / mp.speed, mp.energy_per_output))
end

print("\n### Déchiqueteurs : paliers 5-8 (relatifs au palier 4 vanilla, « énorme »)\n")
print("| Palier | Nom | PV | Dégâts | Vitesse | Résistance +plate/+% | Taille | Pollution pour attaquer |")
print("|---|---|---|---|---|---|---|---|")
local behemoth_hp = { biter = 3000, spitter = 1500 }
for tier = 5, E.TIERS do
  local nt = E.new_tiers[tier]
  print(string.format("| %d | %s | ×%d (déchiqueteur %d, cracheur %d) | ×%d | ×%.2f | +%d / +%d | ×%.2f | ×%.1f |", tier, E.tier_names[tier],
    nt.hp, behemoth_hp.biter * nt.hp, behemoth_hp.spitter * nt.hp, nt.damage, nt.speed, nt.resist, nt.resist, nt.scale / 1.2, nt.poll))
end

print("\n### Courbes d'apparition (évolution → poids)\n")
print("| Palier | Points (évolution : poids) |")
print("|---|---|")
for tier = 1, E.TIERS do
  local pts = {}
  for _, p in ipairs(E.spawn_curves[tier]) do pts[#pts + 1] = string.format("%.2f : %.2f", p[1], p[2]) end
  print(string.format("| %d %s | %s |", tier, E.tier_names[tier], table.concat(pts, " → ")))
end
