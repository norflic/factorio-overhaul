-- Scénario greffé du lot F2-B (25/10) : LE FOUR des 15 âges en jeu, 30 niveaux, de jour et de nuit, EN MARCHE.
--   & "<racine>\fo-autotest.bat" nopause 400 f2-fours "<source>"     (contrôles, sans images)
--   & "<racine>\fo-captures.bat" f2-fours "<source>"                  (captures, sans son)
-- Grille : une rangée par ère (5), six fours par rangée (trois âges, niveau impair puis pair), chacun nourri de charbon
-- et de minerai de fer pour qu'il CHAUFFE (feu de la gueule, lueur, halo, fumée : working_visualisations).
-- Captures : chaque ère au zoom 1, de jour et de nuit ; chaque âge (niveau impair et pair côte à côte) au zoom 2, de
-- jour et de nuit. Table : fo-shots/f2-fours-sites.tsv.

local X0, Y0 = 3200, 3000
local GAP = 2

local function emprise(n) return 2 + math.floor((n - 1) / 6) end
local function nom(n) return n == 1 and "steel-furnace" or ("fo-lvl-furnace-" .. n) end

return {
  description = "F2-B : fours des 15 ages en marche (30 niveaux), jour et nuit",
  base = nil,
  check_tick = 300,
  shots_delay = 320,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.sites = {}
    ctx.prepare_area(X0 - 12, Y0 - 12, X0 + 70, Y0 + 5 * 12 + 12, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy",
        area = { { X0 - 150, Y0 - 150 }, { X0 + 220, Y0 + 220 } } })) do
      en.destroy()
    end
    local y = Y0
    for ere = 1, 5 do
      local side = emprise((ere - 1) * 6 + 1)
      local x = X0
      for i = 1, 6 do
        local n = (ere - 1) * 6 + i
        local age = math.floor((n + 1) / 2)
        local px = x + side / 2
        local py = y + side / 2
        local f = s.create_entity({ name = nom(n), position = { px, py }, force = "player" })
        if f then
          f.insert({ name = "coal", count = 50 })
          f.get_inventory(defines.inventory.furnace_source).insert({ name = "iron-ore", count = 50 })
        end
        st.sites[#st.sites + 1] = { n = n, age = age, ere = ere, f = f, x = px, y = py, side = side }
        x = x + side + GAP
      end
      y = y + side + 4
    end
    local poses = 0
    for _, c in ipairs(st.sites) do if c.f then poses = poses + 1 end end
    ctx.check(poses == 30, "fours poses (30 niveaux)", poses .. " / 30")
  end,

  finish = function(ctx)
    local st = ctx.state()
    local marche, ko = 0, {}
    for _, c in ipairs(st.sites) do
      if c.f and c.f.valid and c.f.status == defines.entity_status.working then
        marche = marche + 1
      else
        ko[#ko + 1] = tostring(c.n)
      end
    end
    ctx.check(marche == 30, "fours en marche (chauffent) au tick 300", marche .. " / 30" ..
      (#ko > 0 and (" ; a l'arret : " .. table.concat(ko, ",")) or ""))
    local fer = 0
    for _, c in ipairs(st.sites) do
      if c.f and c.f.valid then fer = fer + c.f.get_inventory(defines.inventory.furnace_result).get_item_count("iron-plate") end
    end
    ctx.check(fer > 0, "plaques de fer produites", tostring(fer))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local L = { "capture\tniveau\tage\tnuit\tx\ty\tgenre" }
    local rangs = {}
    for _, c in ipairs(st.sites) do
      rangs[c.ere] = rangs[c.ere] or {}
      table.insert(rangs[c.ere], c)
    end
    for ere = 1, 5 do
      local r = rangs[ere]
      local x0, x1 = r[1].x - r[1].side / 2, r[#r].x + r[#r].side / 2
      local cx, cy = (x0 + x1) / 2, r[1].y - 0.5
      local w = math.ceil((x1 - x0 + 4) * 32)
      local h = math.ceil((r[1].side + 5) * 32)
      for _, nuit in ipairs({ false, true }) do
        local nm = string.format("ere%d-z1-%s", ere, nuit and "nuit" or "jour")
        add(nm, cx, cy, 1, nuit and 0.5 or 0, { res = { w, h }, info = false, aa = true })
        L[#L + 1] = string.format("%s\t0\t0\t%d\t%.2f\t%.2f\tere", nm, nuit and 1 or 0, cx, cy)
      end
    end
    for i = 1, #st.sites, 2 do
      local a, b = st.sites[i], st.sites[i + 1]
      local cx, cy = (a.x + b.x) / 2, a.y - 0.5
      local w = math.ceil((b.x - a.x + a.side + 3) * 64)
      local h = math.ceil((a.side + 4) * 64)
      for _, nuit in ipairs({ false, true }) do
        local nm = string.format("age%02d-z2-%s", a.age, nuit and "nuit" or "jour")
        add(nm, cx, cy, 2, nuit and 0.5 or 0, { res = { w, h }, info = false, aa = true })
        L[#L + 1] = string.format("%s\t%d\t%d\t%d\t%.2f\t%.2f\tage", nm, a.n, a.age, nuit and 1 or 0, cx, cy)
      end
    end
    game.write_file("fo-shots/f2-fours-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
