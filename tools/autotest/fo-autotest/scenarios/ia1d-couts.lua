--[[
  Lot IA1-d : coût réel d'un ravivage de fantôme par script (gestionnaires du mod compris : raise_revive = true), par
  type de bâtiment du plan directeur, pour recaler les jetons de travail (Build.COST_REVIVE, Build.COST_REVIVE_POLE).
  40 fantômes par type sur une plaine vidée ; LuaProfiler autour des 40 ravivages ; le journal écrit la durée totale
  (« Duration: x ms »), à diviser par 40. Témoin : 40 create_entity du même bâtiment (sans fantôme, raise_built).
  Lancement : fo-autotest.bat nopause 200 ia1d-couts <source> ; journal : [FO-IA1D-COUTS].
]]

local N = 40
local TYPES = {
  { "stone-furnace", 2 }, { "electric-mining-drill", 3 }, { "inserter", 1 }, { "burner-inserter", 1 },
  { "transport-belt", 1 }, { "iron-chest", 1 }, { "medium-electric-pole", 1 }, { "big-electric-pole", 2 },
  { "boiler", 3 }, { "steam-engine", 5 },
}

return {
  description = "IA1-d : coût d'un ravivage de fantôme par type (jetons de travail)",
  check_tick = 120,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick ~= 30 or st.done then return end
    st.done = true
    local s = ctx.surface()
    local x0, y0 = 500, 500
    s.request_to_generate_chunks({ x0 + 60, y0 + 60 }, 4)
    s.force_generate_chunk_requests()
    local area = { { x0 - 10, y0 - 10 }, { x0 + 200, y0 + 260 } }
    for _, en in ipairs(s.find_entities_filtered({ area = area })) do
      if en.valid and en.type ~= "character" then en.destroy() end
    end
    local tiles = {}
    for y = y0 - 10, y0 + 259 do for x = x0 - 10, x0 + 199 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
    s.set_tiles(tiles, true)
    local row = 0
    for _, ty in ipairs(TYPES) do
      local name, side = ty[1], ty[2]
      local pitch = side + 2
      local ghosts, pos = {}, {}
      for k = 0, N - 1 do
        local px = x0 + (k % 20) * pitch + side / 2
        local py = y0 + row + math.floor(k / 20) * pitch + (name == "steam-engine" and 2.5 or side / 2)
        pos[#pos + 1] = { px, py }
        ghosts[#ghosts + 1] = s.create_entity({ name = "entity-ghost", inner_name = name, position = { px, py }, force = "player", expires = false })
      end
      local prof = game.create_profiler()
      local ok = 0
      for _, g in ipairs(ghosts) do
        if g and g.valid then
          local _, ent = g.revive({ raise_revive = true })
          if ent then ok = ok + 1 end
        end
      end
      prof.stop()
      log({ "", "[FO-IA1D-COUTS] ravivage ", name, " x", tostring(ok), " (raise_revive) : ", prof })
      -- témoin : bâtiments posés directement (à côté), raise_built
      local prof2 = game.create_profiler()
      local ok2 = 0
      for _, p in ipairs(pos) do
        local en = s.create_entity({ name = name, position = { p[1], p[2] + 2 * pitch + (name == "steam-engine" and 6 or 0) }, force = "player", raise_built = true })
        if en then ok2 = ok2 + 1 end
      end
      prof2.stop()
      log({ "", "[FO-IA1D-COUTS] create_entity ", name, " x", tostring(ok2), " (raise_built) : ", prof2 })
      row = row + 4 * pitch + (name == "steam-engine" and 14 or 0)
    end
    -- relevé type « read_masks » : eau + entités de la couche objets sur 56 × 56 tuiles
    local prof3 = game.create_profiler()
    local n = 0
    for _ = 1, 10 do
      local wt = s.find_tiles_filtered({ area = { { x0, y0 }, { x0 + 56, y0 + 56 } }, collision_mask = "water-tile" })
      local ob = s.find_entities_filtered({ area = { { x0, y0 }, { x0 + 56, y0 + 56 } }, collision_mask = "object-layer" })
      n = n + #wt + #ob
    end
    prof3.stop()
    log({ "", "[FO-IA1D-COUTS] releve 56 x 56 (eau + objets) x10, " .. n .. " resultats : ", prof3 })
  end,

  finish = function(ctx)
    ctx.check(ctx.state().done == true, "mesures jouees")
  end,
}
