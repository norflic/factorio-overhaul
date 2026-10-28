--[[
  Lot RECON : la partie de etape1-guide (216 300 ticks = 60 min, aux réglages livrés), inchangée, plus un relevé toutes les
  3 minutes de l'armée de chaque faction ([FO-RECON-GUIDE] : soldats, tourelles, ouvriers) et, si le mod a la
  reconnaissance (lot RECON), de ce que chaque faction sait des autres. Sert au tableau avant / après : le MÊME scénario
  tourne sur la source du lot et sur une copie de main 0.6.5 (témoin).
  Lancement : banc.py --out <archive> --graine <g> --qui RECON<g> -- 216300 recon-guide <source>.
]]
local base = require("scenarios/etape1-guide")
local tick0 = base.tick
local TAG = "[FO-RECON-GUIDE] "

base.description = base.description .. " -- releve de l'armee toutes les 3 min (lot RECON)"
base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  if e.tick == 0 or e.tick % (3 * 3600) ~= 0 then return end
  local s = ctx.surface()
  local parts = {}
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then
      parts[#parts + 1] = string.format("%s soldats=%d tourelles=%d ouvriers=%d", row.key,
        s.count_entities_filtered({ type = "unit", force = row.force }),
        s.count_entities_filtered({ type = "ammo-turret", force = row.force }),
        s.count_entities_filtered({ type = "character", force = row.force }))
    end
  end
  log(TAG .. string.format("minute %d | %s", e.tick / 3600, table.concat(parts, " | ")))
  if remote.interfaces["factorio-overhaul"] and e.tick % (12 * 3600) == 0 then
    local ok, r = pcall(remote.call, "factorio-overhaul", "recon_status")
    if ok and r then
      local rows = {}
      for _, f in ipairs(r.factions) do
        local rs = {}
        for _, x in ipairs(f.rivals) do rs[#rs + 1] = x.key .. " " .. x.status end
        rows[#rows + 1] = string.format("%s attaques=%d eclaireurs=%d perdus=%d refus=%d [%s]", f.key, f.attacks, f.scouts, f.lost,
          f.refused, table.concat(rs, "; "))
      end
      log(TAG .. string.format("savoir minute %d | %s", e.tick / 3600, table.concat(rows, " | ")))
    end
  end
end
return base
