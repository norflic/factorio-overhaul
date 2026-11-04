--[[
  Lot MUNITIONS, essai 2 : les BALLES PERFORANTES dès que la recette est ouverte (partie du DC 0.6.46 : « military-2 » faite à 116 min, les
  tourelles ne recevaient que le chargeur de base). Votre équipe, recette des balles perforantes OUVERTE à l'init, coffre avec 2 000 fer,
  1 000 cuivre, 200 acier, 30 chargeurs de base ; 4 mitrailleuses du QG à 10 chargeurs de base chacune. Aucune vague.
    - règle d'avant (main) : Outposts.ammo_name rend toujours le chargeur de base ; aucune tourelle sous 8 : aucune recharge ;
    - règle du lot : Mu.best_ammo choisit les balles perforantes (recette ouverte, fabricables : acier au coffre), le planificateur les fait
      fabriquer, la tournée les porte et ÉCHANGE le chargeur de base dans la tourelle (une seule case).
  Contrôle à 5 min (tick 18 000) : chacune des 4 tourelles contient des balles perforantes (au moins 20). Journal : [FO-MUNITIONS-PERFORANTES]
  (et la ligne [FO-MUNITIONS] « munition des tourelles ... -> ... » du mod).
]]

local AX = 2000
local CHECK = 18000
local BEST = "piercing-rounds-magazine"

local function content(tu)
  local inv = tu.get_inventory(defines.inventory.turret_ammo)
  local best, base = inv.get_item_count(BEST), inv.get_item_count("firearm-magazine")
  return best, base
end

return {
  description = "MUNITIONS : balles perforantes fabriquees et portees des que la recette est ouverte",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(AX - 60, -150, AX + 200, 150, "grass-1")
    local r = game.forces.player.recipes[BEST]
    if r then r.enabled = true end
    ctx.check(r ~= nil and r.enabled == true, "recette des balles perforantes ouverte")
    local chest = s.create_entity({ name = "fo-team-chest", position = { AX, 0 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if chest then
      for _, it in ipairs({ { "iron-plate", 2000 }, { "copper-plate", 1000 }, { "steel-plate", 200 }, { "coal", 400 }, { "stone", 200 },
        { "pistol", 8 }, { "firearm-magazine", 30 } }) do
        chest.insert({ name = it[1], count = it[2] })
      end
    end
    st.turrets = {}
    for _, p in ipairs({ { 8, -8 }, { 8, 8 }, { -8, -8 }, { -8, 8 } }) do
      local tu = s.create_entity({ name = "gun-turret", position = { AX + p[1], p[2] }, force = "player", raise_built = true })
      if tu then
        tu.insert({ name = "firearm-magazine", count = 10 })
        st.turrets[#st.turrets + 1] = tu
        if remote.interfaces["fo-s1"] then ctx.remote("fo-s1", "own_turret", "player", tu) end
      end
    end
    ctx.check(#st.turrets == 4, "4 mitrailleuses de QG posees (10 chargeurs de base chacune)")
  end,

  tick = function(ctx, e)
    local t = e.tick
    if t % 1800 ~= 0 or t == 0 then return end
    local st = ctx.state()
    local best, base, full = 0, 0, 0
    for _, tu in ipairs(st.turrets or {}) do
      if tu.valid then
        local b, f = content(tu)
        best, base = best + b, base + f
        if b >= 20 then full = full + 1 end
      end
    end
    if full == 4 and not st.done_tick then st.done_tick = t end
    ctx.log(string.format("minute %.1f : perforantes %d, base %d, tourelles a 20 perforantes ou plus %d", t / 3600, best, base, full))
  end,

  finish = function(ctx)
    local st = ctx.state()
    local each, low, n = {}, 1000000, 0
    for _, tu in ipairs(st.turrets or {}) do
      if tu.valid then
        local b, f = content(tu)
        n = n + 1
        each[#each + 1] = b .. "p/" .. f .. "b"
        if b < low then low = b end
      end
    end
    ctx.log(string.format("FAIT a %.1f min : %d tourelle(s) (%s), toutes a 20 perforantes ou plus a la minute %s", CHECK / 3600, n,
      table.concat(each, ","), st.done_tick and string.format("%.1f", st.done_tick / 3600) or "jamais"))
    ctx.check(n == 4, "les 4 tourelles sont la", n)
    ctx.check(n == 4 and low >= 20, "chaque tourelle contient au moins 20 balles perforantes", low)
  end,
}
