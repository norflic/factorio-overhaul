--[[
  Lot AGEBLOCAGE (retour du DC du 3/11 sur 0.6.46 : « la Ligue Azur est restée en âge 1 ») : la partie du guide dans les RÉGLAGES
  DE LA PARTIE DU DC (journal fo-logs/2026-11-03_RETOUR3/factorio-current.log, ligne [FO-REGLAGES] : fo-war-factions=4,
  fo-war-workers=8, fo-war-soldiers=30, fo-pvp-difficulty=merciless ; graine de sa carte 717152950), pour orienter la
  correction (banc d'orientation, pas un critère : les contrôles du guide sur 2 factions, 4 ouvriers et Facile ne valent pas ici).
  Relevé [FO-AGEBLOCAGE] chaque minute et pour chaque faction : niveau du centre, recherche courante du moteur et son avancement,
  recherche de l'équipe (fo-ia3c), laboratoires et packs dans les laboratoires, packs, engrenages, circuits, bras et tapis dans les
  coffres de la force à 40 tuiles du QG.
  Lancement : banc.py --out <archive> --graine 717152950 --qui AGEBLOCAGE -- 216000 ageblocage-dc <source>
]]

local base = require("scenarios/verif_guide_common")(8)
local init0, tick0, finish0 = base.init, base.tick, base.finish
local ITEMS = { "automation-science-pack", "logistic-science-pack", "military-science-pack", "iron-gear-wheel",
  "electronic-circuit", "inserter", "transport-belt", "iron-plate", "copper-plate", "stone-brick" }
local PACKS = { "automation-science-pack", "logistic-science-pack", "military-science-pack" }

base.description = "AGEBLOCAGE : partie du guide aux reglages du DC (4 factions, 8 ouvriers, Impitoyable), releve des ages et de la recherche"

base.init = function(ctx)
  init0(ctx)
  ctx.check(ctx.remote("factorio-overhaul", "war_setting", "fo-war-factions", 4) == 4, "4 factions (reglage du DC)")
  ctx.check(ctx.remote("fo-pvp", "set_difficulty", "merciless") == true, "difficulte Impitoyable (reglage du DC)")
end

local function teams()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  return ok and rows or {}
end

local function releve(ctx, tick)
  local s = ctx.surface()
  for _, row in ipairs(teams()) do
    local force = game.forces[row.force]
    if force and row.key ~= "player" then
      local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = force, limit = 1 })[1]
      local cc = "?"
      local items, inlab = {}, {}
      if hq and hq.valid then
        local q = hq.position
        local area = { { q.x - 40, q.y - 40 }, { q.x + 40, q.y + 40 } }
        for _, e in ipairs(s.find_entities_filtered({ area = area, force = force, type = "container" })) do
          for _, it in ipairs(ITEMS) do items[it] = (items[it] or 0) + e.get_item_count(it) end
          local n = e.name:match("^fo%-lvl%-command%-(%d+)$")
          if n then cc = n end
        end
      end
      local labs = s.find_entities_filtered({ force = force, type = "lab" })
      for _, l in ipairs(labs) do
        local inv = l.get_inventory(defines.inventory.lab_input)
        if inv then for _, p in ipairs(PACKS) do inlab[p] = (inlab[p] or 0) + inv.get_item_count(p) end end
      end
      local ok, st = pcall(remote.call, "fo-ia3c", "status", row.key)
      local cur = force.current_research
      local parts = {}
      for _, it in ipairs(ITEMS) do parts[#parts + 1] = it .. "=" .. (items[it] or 0) end
      local lp = {}
      for _, p in ipairs(PACKS) do lp[#lp + 1] = p .. "=" .. (inlab[p] or 0) end
      ctx.log(string.format("releve min=%d force=%s centre=%s courante=%s avancement=%.3f equipe=%s labos=%d (moteur %d) | coffres %s | dans les labos %s",
        math.floor(tick / 3600), row.key, cc, cur and cur.name or "-", force.research_progress or 0,
        (ok and st and st.lab) or "-", (ok and st and st.labs) or -1, #labs, table.concat(parts, " "), table.concat(lp, " ")))
    end
  end
end

base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick > 0 and e.tick % 3600 == 0 then releve(ctx, e.tick) end
end

base.finish = function(ctx)
  if finish0 then finish0(ctx) end
end

return base
