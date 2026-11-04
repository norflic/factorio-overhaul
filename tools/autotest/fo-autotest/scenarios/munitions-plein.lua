--[[
  Lot MUNITIONS (retour du DC du 3/11, 0.6.46 : « les tourelles n'étaient pas chargées complètement ») : le QG du DC à 140,2 min, en petit.
  Votre équipe, un coffre RICHE (8 000 fer, 2 000 cuivre, 100 chargeurs) et 8 mitrailleuses du QG à moitié vides, chargées comme le
  recensement du journal du DC : 20, 20, 20, 15, 15, 10, 10, 10 (120 chargeurs). Aucune vague.
    - règle d'avant (main) : aucune tourelle sous 8 chargeurs, aucune recharge : 120 chargeurs pour toujours (prouvé hors jeu,
      tests/munitions_test.lua §2 et §3, « vue sans relevé ») ;
    - règle du lot : fer 8 000 >= 8 tourelles x 30 x 4 : cible riche 50 par tourelle ; les 8 tourelles sous 38 (75 %) sont rechargées au plein,
      la tournée part avec le stock (prise partielle) et le reste se fabrique à la main.
  Mesures toutes les 30 s ; contrôle à 5 min (tick 18 000) : chaque tourelle >= 38 chargeurs et minute à laquelle toutes y sont.
  Journal : [FO-MUNITIONS-PLEIN] (et [FO-MUNITIONS] du mod).
]]

local AX = 2000
local START = { 20, 20, 20, 15, 15, 10, 10, 10 }
local TOP = 38 -- Mu.top(50) : 75 % de la cible riche
local CHECK = 18000

return {
  description = "MUNITIONS : 8 tourelles du QG a moitie vides, coffre riche : toutes rechargees au plein en 5 min",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(AX - 60, -150, AX + 200, 150, "grass-1")
    local chest = s.create_entity({ name = "fo-team-chest", position = { AX, 0 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if chest then
      for _, it in ipairs({ { "iron-plate", 8000 }, { "copper-plate", 2000 }, { "coal", 400 }, { "stone", 200 }, { "pistol", 8 },
        { "firearm-magazine", 100 } }) do
        chest.insert({ name = it[1], count = it[2] })
      end
    end
    st.turrets = {}
    local pos = { { 8, -8 }, { 8, 8 }, { -8, -8 }, { -8, 8 }, { 12, 0 }, { -12, 0 }, { 0, 12 }, { 0, -12 } }
    for i, p in ipairs(pos) do
      local tu = s.create_entity({ name = "gun-turret", position = { AX + p[1], p[2] }, force = "player", raise_built = true })
      if tu then
        tu.insert({ name = "firearm-magazine", count = START[i] })
        st.turrets[#st.turrets + 1] = tu
        if remote.interfaces["fo-s1"] then ctx.remote("fo-s1", "own_turret", "player", tu) end
      end
    end
    ctx.check(#st.turrets == 8, "8 mitrailleuses de QG posees (120 chargeurs)")
  end,

  tick = function(ctx, e)
    local t = e.tick
    if t % 1800 ~= 0 or t == 0 then return end
    local st = ctx.state()
    local sum, low, n = 0, 1000000, 0
    for _, tu in ipairs(st.turrets or {}) do
      if tu.valid then
        local a = tu.get_inventory(defines.inventory.turret_ammo).get_item_count()
        sum, n = sum + a, n + 1
        if a < low then low = a end
      end
    end
    if n == 8 and low >= TOP and not st.full_tick then st.full_tick = t end
    ctx.log(string.format("minute %.1f : %d tourelle(s), %d chargeur(s), la moins chargee %d", t / 3600, n, sum, n > 0 and low or 0))
  end,

  finish = function(ctx)
    local st = ctx.state()
    local sum, low, n = 0, 1000000, 0
    local each = {}
    for _, tu in ipairs(st.turrets or {}) do
      if tu.valid then
        local a = tu.get_inventory(defines.inventory.turret_ammo).get_item_count()
        sum, n = sum + a, n + 1
        each[#each + 1] = tostring(a)
        if a < low then low = a end
      end
    end
    ctx.log(string.format("FAIT a %.1f min : %d tourelle(s), %d chargeur(s) (%s), toutes >= %d a la minute %s", CHECK / 3600, n, sum,
      table.concat(each, ","), TOP, st.full_tick and string.format("%.1f", st.full_tick / 3600) or "jamais"))
    ctx.check(n == 8, "les 8 tourelles sont la", n)
    ctx.check(n == 8 and low >= TOP, "chaque tourelle a au moins " .. TOP .. " chargeurs (cible riche 50, 75 %)", low)
    ctx.check(sum >= 8 * TOP, "chargeurs dans les tourelles >= " .. (8 * TOP) .. " (120 au depart)", sum)
  end,
}
