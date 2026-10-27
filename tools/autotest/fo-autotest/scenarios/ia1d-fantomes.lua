--[[
  Lot IA1-d : diagnostic des fantômes posés par script (centrale refusée au banc ia1-build-plaine, 25/10).
  Pour chaque bâtiment non carré du plan directeur (chaudière 3 × 2, machine à vapeur 3 × 5) dans les 4 directions, à
  la position que calcule le plan (centre de l'emprise tournée) : le fantôme créé par create_entity{entity-ghost},
  sa position et sa boîte réelles, ce que trouve find_entities_filtered{position, radius = 0.3}, can_place_entity
  (ghost_revive, script_ghost) avant et après la pose, puis le bâtiment ravivé (position, boîte). Même chose avec
  create_entity du bâtiment réel (témoin).
  Lancement : fo-autotest.bat nopause 120 ia1d-fantomes <source> ; journal : [FO-IA1D-FANTOMES].
]]

local CASES = {
  -- nom, largeur et hauteur de l'emprise en direction nord (tuiles)
  { "boiler", 3, 2 },
  { "steam-engine", 3, 5 },
  { "offshore-pump", 1, 1 },
}

local DIRS = { 0, 2, 4, 6 }

local function fmt(p) return string.format("(%g, %g)", p.x, p.y) end
local function fbox(b)
  return string.format("[%g, %g ; %g, %g]", b.left_top.x, b.left_top.y, b.right_bottom.x, b.right_bottom.y)
end

return {
  description = "IA1-d : fantômes de bâtiments non carrés posés par script (diagnostic de la centrale)",
  check_tick = 60,

  init = function(ctx)
    local s = ctx.surface()
    local x0, y0 = 300, 300
    s.request_to_generate_chunks({ x0, y0 }, 2)
    s.force_generate_chunk_requests()
    local area = { { x0 - 20, y0 - 20 }, { x0 + 60, y0 + 60 } }
    for _, e in ipairs(s.find_entities_filtered({ area = area })) do
      if e.valid and e.type ~= "character" then e.destroy() end
    end
    local tiles = {}
    for y = y0 - 20, y0 + 59 do for x = x0 - 20, x0 + 59 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
    s.set_tiles(tiles, true)
    local proto = game.entity_prototypes
    for _, c in ipairs(CASES) do
      local pr = proto[c[1]]
      ctx.log(string.format("prototype %s : tile_width %s tile_height %s, collision %s", c[1], tostring(pr.tile_width),
        tostring(pr.tile_height), fbox(pr.collision_box)))
    end
    local row = 0
    local mismatches = 0
    for _, c in ipairs(CASES) do
      if c[1] ~= "offshore-pump" then
        for _, d in ipairs(DIRS) do
          local w, h = c[2], c[3]
          if d == 2 or d == 6 then w, h = h, w end
          -- coin nord-ouest entier de l'emprise, centre comme le plan (shared/team/plan.lua) : coin + taille / 2
          local cx, cy = x0 + 12 * (d / 2), y0 + 12 * row
          local want = { x = cx + w / 2, y = cy + h / 2 }
          local before_g = s.can_place_entity({ name = c[1], position = want, direction = d, force = "player",
            build_check_type = defines.build_check_type.ghost_revive })
          local before_s = s.can_place_entity({ name = c[1], position = want, direction = d, force = "player",
            build_check_type = defines.build_check_type.script_ghost })
          local gh = s.create_entity({ name = "entity-ghost", inner_name = c[1], position = want, direction = d,
            force = "player", expires = false })
          if not gh then
            ctx.log(string.format("%s dir %d voulu %s : fantome NON cree", c[1], d, fmt(want)))
          else
            local found = 0
            for _, g in ipairs(s.find_entities_filtered({ position = want, radius = 0.3, name = "entity-ghost", force = "player" })) do
              if g.ghost_name == c[1] then found = found + 1 end
            end
            local after_g = s.can_place_entity({ name = c[1], position = want, direction = d, force = "player",
              build_check_type = defines.build_check_type.ghost_revive })
            local dx, dy = gh.position.x - want.x, gh.position.y - want.y
            local moved = math.abs(dx) > 0.01 or math.abs(dy) > 0.01 or gh.direction ~= d
            if moved then mismatches = mismatches + 1 end
            ctx.log(string.format("%s dir %d voulu %s : fantome %s dir %d boite %s ; trouve (rayon 0.3) %d ; place avant ghost_revive %s script_ghost %s, apres ghost_revive %s%s",
              c[1], d, fmt(want), fmt(gh.position), gh.direction, fbox(gh.bounding_box), found, tostring(before_g),
              tostring(before_s), tostring(after_g), moved and " ; DECALE" or ""))
            local _, ent = gh.revive({ raise_revive = false })
            if ent and ent.valid then
              ctx.log(string.format("   ravive : %s dir %d boite %s", fmt(ent.position), ent.direction, fbox(ent.bounding_box)))
              ent.destroy()
            else
              ctx.log("   ravivage refuse")
            end
          end
          -- témoin : bâtiment réel
          local real = s.create_entity({ name = c[1], position = want, direction = d, force = "player" })
          if real then
            ctx.log(string.format("   reel (create_entity) : %s dir %d boite %s", fmt(real.position), real.direction, fbox(real.bounding_box)))
            real.destroy()
          end
        end
        row = row + 1
      end
    end
    ctx.state().mismatches = mismatches
  end,

  finish = function(ctx)
    ctx.log("fantomes decales ou tournes par le moteur : " .. tostring(ctx.state().mismatches))
    ctx.check(true, "diagnostic joue")
  end,
}
