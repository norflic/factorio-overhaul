--[[
  Lot STOCKAGE-VITAL (c), fait moteur (7/11) : un objet posé au sol (item-on-ground) empêche-t-il la pose d'un coffre sur sa tuile ?
  Impasse vue sur la sauvegarde du DC : stock plein, 46 annexes sur 48, coffre en main, aucune pose ; les 2 places restantes du bloc
  sont peut-être sous le disque d'objets répandus. script/ai3/places_qg.lua:40 teste `surface.can_place_entity{ name, position, force }`
  (build_check_type par défaut : ghost_revive, doc 1.1.91).

  Au tick 60, sur des tuiles libres à l'écart du coffre d'équipe (aucun coffre d'équipe n'est posé) :
    T0 témoin : tuile libre, can_place_entity d'un iron-chest (défaut, puis script, puis manual) ;
    T1 : 1 copper-plate au CENTRE de la tuile (create_entity item-on-ground) ; mêmes appels ;
    T2 : 1 copper-plate à 0,35 tuile du centre, dans la tuile ; mêmes appels ;
    T3 : spill_item_stack de 20 copper-plate au centre (comme give en 0.6.53) : can_place_entity sur la tuile du centre ;
    T4 : create_entity{ iron-chest } SANS contrôle sur la tuile de T1 : coffre posé ? objets au sol de la tuile après (gardés, poussés, détruits) ?
  CRITÈRES (écrits AVANT) : S1 le témoin T0 est plaçable (défaut) ; le reste est un RELEVÉ (lignes « FAIT »), sans seuil.
  Banc : `banc.py ... -- 300 sol-place <source>` ; journal : [FO-SOL-PLACE].
]]
local AT = 60

local function free_tile(s, want)
  local q = s.find_non_colliding_position("iron-chest", want, 40, 1)
  if not q then return nil end
  return { x = math.floor(q.x) + 0.5, y = math.floor(q.y) + 0.5 }
end

local function checks(s, p)
  local bt = defines.build_check_type
  local a = s.can_place_entity({ name = "iron-chest", position = p, force = "player" })
  local b = s.can_place_entity({ name = "iron-chest", position = p, force = "player", build_check_type = bt.script })
  local c = s.can_place_entity({ name = "iron-chest", position = p, force = "player", build_check_type = bt.manual })
  return a, b, c
end

local function on_tile(s, p)
  return s.count_entities_filtered({ name = "item-on-ground", area = { { p.x - 0.49, p.y - 0.49 }, { p.x + 0.49, p.y + 0.49 } } })
end

return {
  description = "STOCKAGE-VITAL (c) : un objet au sol empeche-t-il la pose d'un coffre sur sa tuile ?",
  check_tick = AT + 60,

  tick = function(ctx, e)
    if e.tick ~= AT then return end
    local st = ctx.state()
    local s = ctx.surface()
    local c = game.forces.player.get_spawn_position(s)
    local p0 = free_tile(s, { x = c.x + 40, y = c.y + 40 })
    local p1 = p0 and free_tile(s, { x = p0.x + 6, y = p0.y })
    local p2 = p1 and free_tile(s, { x = p1.x + 6, y = p1.y })
    local p3 = p2 and free_tile(s, { x = p2.x + 12, y = p2.y })
    if not (p0 and p1 and p2 and p3) then ctx.log("tuiles libres introuvables") return end
    local a, b, cc = checks(s, p0)
    st.t0 = a
    ctx.log(string.format("FAIT T0 temoin (%.1f, %.1f) : defaut %s, script %s, manual %s", p0.x, p0.y, tostring(a), tostring(b), tostring(cc)))
    s.create_entity({ name = "item-on-ground", position = p1, stack = { name = "copper-plate", count = 1 } })
    a, b, cc = checks(s, p1)
    ctx.log(string.format("FAIT T1 objet au centre (%.1f, %.1f), %d au sol sur la tuile : defaut %s, script %s, manual %s", p1.x, p1.y, on_tile(s, p1),
      tostring(a), tostring(b), tostring(cc)))
    s.create_entity({ name = "item-on-ground", position = { x = p2.x + 0.35, y = p2.y + 0.35 }, stack = { name = "copper-plate", count = 1 } })
    a, b, cc = checks(s, p2)
    ctx.log(string.format("FAIT T2 objet a 0,35 du centre (%.1f, %.1f), %d au sol sur la tuile : defaut %s, script %s, manual %s", p2.x, p2.y,
      on_tile(s, p2), tostring(a), tostring(b), tostring(cc)))
    s.spill_item_stack(p3, { name = "copper-plate", count = 20 }, false)
    a, b, cc = checks(s, p3)
    ctx.log(string.format("FAIT T3 spill de 20 au centre (%.1f, %.1f), %d au sol sur la tuile : defaut %s, script %s, manual %s", p3.x, p3.y,
      on_tile(s, p3), tostring(a), tostring(b), tostring(cc)))
    local before = on_tile(s, p1)
    local chest = s.create_entity({ name = "iron-chest", position = p1, force = "player" })
    local after = on_tile(s, p1)
    local near = s.count_entities_filtered({ name = "item-on-ground", position = p1, radius = 3 })
    ctx.log(string.format("FAIT T4 create_entity sans controle sur la tuile de T1 : coffre %s, au sol sur la tuile %d -> %d, a 3 tuiles %d, contenu du coffre %d",
      tostring(chest and chest.valid), before, after, near, chest and chest.valid and chest.get_item_count("copper-plate") or -1))
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.t0 == true, "S1 temoin : une tuile libre accepte le coffre", tostring(st.t0))
  end,
}
