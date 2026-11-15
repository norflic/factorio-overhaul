-- Lot RECONSTRUCTION-0716 : partie JALONS de 30 min (voir jalons_common.lua) ; à la minute 10, toutes les foreuses de l'avant-poste
-- de CHARBON de votre équipe sont détruites (LuaEntity.die par la force « enemy », comme une attaque de biters) : la ruine
-- ([FO-RUINE]) doit refaire le champ. Chaque minute ensuite, ligne [FO-SCEN-RUINE] : foreuses de l'équipe à moins de R tuiles du site.
-- Témoin (`avec` faux) : la fabrication des foreuses des ruines est coupée (remote fo-recon.set_ruin_craft(false)).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --graine G --carte-max --mgs tools/autotest/carte_dc_mgs.json -- 108400 ruine-charbon <source>
-- `vide` : à la destruction, les objets des foreuses détruites sont aussi retirés des coffres de l'équipe (cas « sans objet au stock »).
return function(avec, vide)
local base = require("scenarios/jalons_common")(30)
local MIN = 3600
local TAG = "[FO-SCEN-RUINE] "
local M = 10
local R = 24
local site, force, killed, at = nil, nil, 0, nil

local function team_force()
  for _, row in ipairs(remote.call("fo-ia1", "teams") or {}) do
    if row.key == "player" then return row.force end
  end
  return nil
end

local function drills_near(s)
  if not (site and force) then return 0, 0 end
  local list = s.find_entities_filtered({ type = "mining-drill", force = force, area = { { site.x - R, site.y - R }, { site.x + R, site.y + R } } })
  local run = 0
  for _, d in ipairs(list) do if d.status == defines.entity_status.working then run = run + 1 end end
  return #list, run
end

local function strike(ctx, tick)
  local s = ctx.surface()
  force = team_force()
  local poi = remote.call("factorio-overhaul", "points_of_interest")
  local p = poi and poi.player
  for _, o in ipairs((p and p.outposts) or {}) do
    if o.kind == "coal" then site = o.pos break end
  end
  if not (site and force) then
    log(TAG .. string.format("pas d'avant-poste de charbon a %.1f min (force %s) : nouvel essai", tick / MIN, tostring(force)))
    return false
  end
  local list = s.find_entities_filtered({ type = "mining-drill", force = force, area = { { site.x - R, site.y - R }, { site.x + R, site.y + R } } })
  table.sort(list, function(a, b) return a.unit_number < b.unit_number end)
  killed = 0
  local names = {}
  for _, d in ipairs(list) do
    local its = d.prototype.items_to_place_this
    if its and its[1] then names[#names + 1] = its[1].name end
  end
  for _, d in ipairs(list) do
    if d.valid then d.die("enemy") killed = killed + 1 end
  end
  at = tick
  if vide then
    local gone = 0
    local cs = s.find_entities_filtered({ type = "container", force = force })
    table.sort(cs, function(a, b) return a.unit_number < b.unit_number end)
    for _, c in ipairs(cs) do
      for _, nm in ipairs(names) do gone = gone + c.remove_item({ name = nm, count = 100000 }) end
    end
    log(TAG .. string.format("stock vide : %d objet(s) de foreuse retire(s) des coffres de l'equipe", gone))
  end
  log(TAG .. string.format("%s : avant-poste de charbon en (%.0f, %.0f) : %d foreuse(s) detruite(s) a %.1f min", avec and "avec" or "TEMOIN",
    site.x, site.y, killed, tick / MIN))
  return killed > 0
end

local init0, tick0 = base.init, base.tick
base.description = "RUINE-CHARBON : partie JALONS 30 min, foreuses de l'avant-poste de charbon de votre equipe detruites a 10 min" ..
  (avec and "" or " (TEMOIN : sans fabrication des foreuses des ruines)")
base.init = function(ctx)
  init0(ctx)
  if not avec then remote.call("fo-recon", "set_ruin_craft", false) end
end
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick % MIN ~= 0 or e.tick == 0 then return end
  if not avec then remote.call("fo-recon", "set_ruin_craft", false) end
  local minute = e.tick / MIN
  if not at and minute >= M and minute <= 20 then
    local ok, res = pcall(strike, ctx, e.tick)
    if not ok then log(TAG .. "ERREUR " .. tostring(res)) end
  elseif at then
    local n, run = drills_near(ctx.surface())
    log(TAG .. string.format("%s minute %d : %d foreuse(s) de l'equipe sur le site (%d en marche) ; detruites %d a %.1f min", avec and "avec" or "TEMOIN",
      minute, n, run, killed, at / MIN))
  end
end
return base
end
