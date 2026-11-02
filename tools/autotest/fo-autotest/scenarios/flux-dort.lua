-- Lot FLUX : la partie de dc-croissance (60 min, 3 factions + votre équipe, sans images) ET, à la fin, d'où viennent les plaques qui
-- dorment dans les fours (diagnostic, lecture seule) : pour chaque force, les fours dont la sortie tient >= 30 objets et qui ne
-- travaillent pas, classés par ce qui les entoure (foreuse = sortie d'avant-poste, bras ou tapis = ligne de fonderie, QG).
-- banc.py --qui FLUX -- 216000 flux-dort <source>
local base = require("scenarios/dc_evolution_common")(214000)
local finish0 = base.finish
local function teams()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  return ok and rows or {}
end
base.finish = function(ctx)
  local s = ctx.surface()
  for _, row in ipairs(teams()) do
    local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = row.force, limit = 1 })[1]
    local classes, total, top = {}, 0, {}
    for _, e in ipairs(s.find_entities_filtered({ type = "furnace", force = row.force })) do
      if e.valid then
        local inv = e.get_output_inventory()
        local n = inv and inv.get_item_count() or 0
        local st = e.status
        if n >= 30 and st ~= defines.entity_status.working then
          local cls = "isole"
          local near = s.find_entities_filtered({ position = e.position, radius = 3.2, type = { "mining-drill", "inserter", "transport-belt", "container" } })
          local has = {}
          for _, x in ipairs(near) do has[x.type] = (has[x.type] or 0) + 1 end
          if hq and hq.valid and (e.position.x - hq.position.x) ^ 2 + (e.position.y - hq.position.y) ^ 2 <= 30 * 30 then cls = "qg"
          elseif has["mining-drill"] then cls = "foreuse"
          elseif has["inserter"] or has["transport-belt"] then cls = "ligne" end
          local c = classes[cls] or { n = 0, plates = 0 }
          classes[cls] = c
          c.n, c.plates, total = c.n + 1, c.plates + n, total + n
          if #top < 4 then top[#top + 1] = string.format("(%d,%d) %s %d %s", e.position.x, e.position.y, cls, n, tostring(st)) end
        end
      end
    end
    local parts = {}
    for _, k in ipairs({ "foreuse", "ligne", "qg", "isole" }) do
      local c = classes[k]
      if c then parts[#parts + 1] = string.format("%s %d four(s) %d objets", k, c.n, c.plates) end
    end
    ctx.log(string.format("[FO-FLUX-DORT] %s : %d objets dans %s ; exemples %s", row.key, total, #parts > 0 and table.concat(parts, " ; ") or "aucun four a l'arret",
      table.concat(top, " | ")))
  end
  finish0(ctx)
end
return base
