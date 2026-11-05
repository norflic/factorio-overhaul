--[[
  Lot STOCKAGE (essai 2), banc court : « bloc saturé, un anneau s'ouvre, rien au sol » (remarque du DC du 5/11 : « une limite en fait de coffres
  posés [...] les ressources se posent par terre »). Écrit, NON lancé (le DC joue) ; BILAN attendu : fo-logs/2026-11-05_STOCKAGE/CRITERES.md.
    - tick 0 : coffre de votre équipe en (2500, 0) (face sud du bloc : y >= 0) ; 5 coffres en fer et 4 750 pierres : 96 cases sur 96 ;
      un MUR sur chacune des 48 places du bloc d'avant (colonnes -11..11 tous les 2, rangées +5..+11 tous les 2) : aucune place libre ;
    - la règle du lot (script/team/stock.lua, Sg.decide) : bloc plein, rien à améliorer -> anneau 2 (rangées +13..+19) -> coffre en fer posé ;
      les dépôts refusés attendent (f.stock_pending) au lieu d'aller au sol ;
    - tick 3 600 : contrôle : au moins un coffre en fer de votre force dans l'anneau 2 ; aucun objet au sol à moins de 40 tuiles du QG.
  Témoin (règle d'avant) : aucun coffre (« bloque », tests/stockage_test.lua §1), objets refusés perdus ou au sol.
  Journal : [FO-STOCKAGE-ANNEAU] (et [FO-STOCKAGE] / [FO-ANNEXE] du mod).
]]

local AX = 2500
local CHECK = 3600

local function ring2_chests(s)
  local n = 0
  for _, e in ipairs(s.find_entities_filtered({ name = "iron-chest", force = "player",
      area = { { AX - 12, 12.5 }, { AX + 12, 19.6 } } })) do
    if e.valid then n = n + 1 end
  end
  return n
end

local function ground_items(s)
  return #s.find_entities_filtered({ type = "item-entity", area = { { AX - 40, -40 }, { AX + 40, 40 } } })
end

return {
  description = "STOCKAGE : bloc des annexes sature, un anneau s'ouvre, rien au sol",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(AX - 60, -60, AX + 60, 60, "grass-1")
    local chest = s.create_entity({ name = "fo-team-chest", position = { AX, 0 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if chest then
      chest.insert({ name = "iron-chest", count = 5 })
      chest.insert({ name = "stone", count = 4750 })
      st.slots_used = #chest.get_inventory(defines.inventory.chest) - chest.get_inventory(defines.inventory.chest).count_empty_stacks()
    end
    local walls = 0
    for dx = -11, 11, 2 do
      for r = 5, 11, 2 do
        local w = s.create_entity({ name = "stone-wall", position = { AX + dx, r }, force = "player" })
        if w then walls = walls + 1 end
      end
    end
    st.walls = walls
    ctx.check(walls == 48 and (st.slots_used or 0) >= 95, "48 places du bloc occupees par des murs, coffre plein", walls .. " murs, " ..
      tostring(st.slots_used) .. " cases")
  end,

  tick = function(ctx, e)
    if e.tick % 600 == 0 and e.tick > 0 then
      local s = ctx.surface()
      ctx.log(string.format("tick %d : coffres en fer dans l'anneau 2 %d, objets au sol %d", e.tick, ring2_chests(s), ground_items(s)))
    end
  end,

  finish = function(ctx)
    local s = ctx.surface()
    local n2, g = ring2_chests(s), ground_items(s)
    ctx.log(string.format("FAIT : coffres en fer dans l'anneau 2 : %d ; objets au sol a moins de 40 tuiles : %d", n2, g))
    ctx.check(n2 >= 1, "un anneau s'est ouvert : au moins un coffre en fer dans l'anneau 2", n2)
    ctx.check(g == 0, "rien au sol autour du QG", g)
  end,
}
