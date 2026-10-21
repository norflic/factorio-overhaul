-- Imprime la table des paliers (Markdown) depuis shared/balance_model.lua.
-- Usage, depuis la racine du mod :   lua5.2 tools/print_balance.lua

package.path = "./?.lua;" .. package.path
local M = require("shared.balance_model")

local rows, issues = M.derive()
print("| Palier | Tapis (items/s) | speed | ρ (MU/item) | Φ tapis (MU/s) | ×Φ | MU/s par machine | items/s par machine | kJ/MU | kW par machine | MW par tapis | Mouvements / 1000 MU |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|")
for _, r in ipairs(rows) do
  print(string.format("| T%d | %d | %.5f | %d | %d | ×%.0f | %.2f | %.2f | %.0f | %.0f | %.1f | %.0f |",
    r.tier, r.belt_items, r.belt_speed, r.density, r.phi, r.phi_ratio, r.machine_mu, r.machine_items,
    r.energy_kj_per_mu, r.machine_kw, r.belt_mw, r.handoffs_per_kmu))
end
print("")
if #issues == 0 then
  print("Contraintes moteur : toutes respectées.")
else
  for _, s in ipairs(issues) do print("- " .. s) end
end
