-- Sprint s43 (parite) : la partie du DC (lancement automatique, 4 factions, 30 ouvriers) avec VOTRE ÉQUIPE fondée d'office et jouée
-- SANS humain (aucun personnage : le banc tourne sans joueur connecté). Mesure : plaques de fer produites par force toutes les 10 min.
-- banc.py --qui s43-parite -- 216600 s43-parite-seule <source> ; lecture : lignes [FO-PARITE-FER].
local base = require("scenarios/verif_guide_common")(30, true)
local EVERY = 36000
local TAG = "[FO-PARITE-FER] "

local function plates(force)
  local f = game.forces[force]
  return f and f.item_production_statistics.get_input_count("iron-plate") or -1
end

local function report(ctx, tick)
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  local parts = {}
  for _, r in ipairs(ok and rows or {}) do
    parts[#parts + 1] = string.format("%s=%d (n=%d)", tostring(r.key), plates(r.force), r.n or -1)
  end
  ctx.log(TAG .. string.format("minute %d | %s", math.floor(tick / 3600), table.concat(parts, " ")))
end

local init0, tick0, finish0 = base.init, base.tick, base.finish
base.description = "s43 parite : votre equipe seule (sans humain) + 4 factions, fer produit par force toutes les 10 min"
base.check_tick = 216000
base.init = function(ctx)
  init0(ctx)
  ctx.check(ctx.remote("factorio-overhaul", "war_setting", "fo-war-factions", 4) == 4, "4 factions")
end
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick > 0 and e.tick % EVERY == 0 then report(ctx, e.tick) end
end
base.finish = function(ctx)
  report(ctx, game.tick)
  finish0(ctx)
end
return base
