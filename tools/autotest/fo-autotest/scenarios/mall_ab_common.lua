--[[
  A/B du seuil S2 du mall (lot MALL, demande de l'intégrateur le 9/11) : la partie etape1-geants, avec le réglage fo-war-mall-s2-debit allumé ou éteint, et un relevé par minute
  [FO-MALL-AB] : plaques produites, objets du mall, machines, avant-postes. Couverture électrique : lignes [FO-GEANTS] de la partie. Lecture : tools/autotest/mall_ab.py.
  Lancement : banc.py --graine N --out <archive> --qui mall -- 324000 mall-ab-<on|off> <source>
]]

local base0 = require("scenarios/etape1-geants")

local KEYS = { "player", "scarlet", "azure", "amber", "emerald" }

return function(on)
  local base = {}
  for k, v in pairs(base0) do base[k] = v end
  local init0, tick0 = base0.init, base0.tick
  base.description = "MALL A/B : etape1-geants, seuil S2 au debit " .. (on and "ALLUME" or "ETEINT")

  base.init = function(ctx)
    if init0 then init0(ctx) end
    ctx.check(ctx.call("war_setting", "fo-war-mall-s2-debit", on) == on, "reglage fo-war-mall-s2-debit = " .. tostring(on))
  end

  base.tick = function(ctx, e)
    if tick0 then tick0(ctx, e) end
    if e.tick % 3600 ~= 0 or e.tick < 3600 then return end
    local minute = e.tick / 3600
    local idx = defines.flow_precision_index.one_minute
    for _, key in ipairs(KEYS) do
      local r = ctx.remote("fo-mall", "report", key)
      if r then
        local fo = game.forces[r.team_force or ""]
        local fer, cuivre = -1, -1
        if fo then
          local st = fo.item_production_statistics
          fer = st.get_flow_count({ name = "iron-plate", input = true, precision_index = idx })
          cuivre = st.get_flow_count({ name = "copper-plate", input = true, precision_index = idx })
        end
        local fab = r.fab or {}
        ctx.log(string.format("[FO-MALL-AB] %s minute %d | fer %.1f/min cuivre %.1f/min | mall : objets %d, coffres %d, machines %d, rangees %d | avant-postes %d | S %s", key, minute, fer, cuivre,
          fab.made or 0, fab.chests or 0, fab.machines or 0, #(r.rows or {}), r.outposts or 0, tostring(r.pret == true)))
      end
    end
  end

  return base
end
