-- Lot CENTRALE : etape1-guide (même partie, mêmes relevés) + un relevé de la CONNEXION ÉLECTRIQUE de chaque faction toutes
-- les 5 min : générateurs, réseaux électriques distincts qui portent un générateur ou un poteau de la faction, poteaux sur le
-- réseau du premier générateur, puissance produite au dernier tick (« la centrale est reliée au treillis et produit »).
-- Ligne : [FO-CENTRALE] reseau minute N | <faction> | generateurs=.. reseaux=.. poteaux_total=.. poteaux_sur_reseau_centrale=..
--         plus_loin_poteau_de_ligne=.. kW_produits=..
local base = require("scenarios/etape1-guide")
local tick0 = base.tick
local MIN = 3600
local TAG = "[FO-CENTRALE] "

base.description = (base.description or "") .. " + relevé de la connexion électrique des centrales"

local function factions()
  local out = {}
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = row end
  end
  return out
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick > 0 and e.tick % (5 * MIN) == 0 then
    local s = ctx.surface()
    for _, r in ipairs(factions()) do
      local gens = s.find_entities_filtered({ force = r.force, type = "generator" })
      local poles = s.find_entities_filtered({ force = r.force, type = "electric-pole" })
      local nets, first = {}, nil
      local kw = 0
      for _, g in ipairs(gens) do
        nets[g.electric_network_id or -1] = true
        first = first or g.electric_network_id
        kw = kw + (g.energy_generated_last_tick or 0) * 60 / 1000
      end
      local on, far = 0, 0
      local gx, gy
      if gens[1] then gx, gy = gens[1].position.x, gens[1].position.y end
      for _, p in ipairs(poles) do
        nets[p.electric_network_id or -1] = true
        if first and p.electric_network_id == first then
          on = on + 1
          if gx then far = math.max(far, math.sqrt((p.position.x - gx) ^ 2 + (p.position.y - gy) ^ 2)) end
        end
      end
      local n = 0
      for _ in pairs(nets) do n = n + 1 end
      log(TAG .. string.format("reseau minute %d | %s | generateurs=%d reseaux=%d poteaux_total=%d poteaux_sur_reseau_centrale=%d plus_loin_poteau_de_ligne=%.0f kW_produits=%.0f",
        e.tick / MIN, r.key, #gens, n, #poles, on, far, kw))
    end
  end
end

return base
