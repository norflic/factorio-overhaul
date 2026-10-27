-- Scénario greffé du lot F4-B (27/10) : LA FOREUSE ÉLECTRIQUE des 15 âges en jeu, 30 niveaux, posés sur du minerai de
-- fer, EN MARCHE, qui extraient (un coffre au point de dépôt de chacune), de jour et de nuit, et les 4 directions. Sur le
-- modèle de f3-assembleurs (lot F3-B).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui F4-B -- 800 f4-foreuses <source>          (contrôles)
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui F4-B --captures -- 800 f4-foreuses <source>  (captures)
-- Grille : une rangée par ère (5), six foreuses par rangée (trois âges, niveau impair puis pair), tournées vers le nord.
-- Bloc des directions : une rangée par emprise et par ère (niveaux 3, 7, 13, 19, 29), la même foreuse tournée vers le
-- nord, l'est, le sud et l'ouest. Point de dépôt contrôlé (x = 0 aux côtés impairs, −0,5 aux côtés pairs, vers le nord :
-- la goulotte DESSINÉE y est). Captures : chaque ère au zoom 1, de jour et de nuit ; chaque âge (impair et pair côte à
-- côte) au zoom 2, de jour et de nuit ; le bloc des directions au zoom 1. Table : fo-shots/f4-foreuses-sites.tsv.

local X0, Y0 = 3200, 3000
local GAP = 4
local DIRS = { defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west }

local function emprise(n)
  local e = math.floor((n + 1) / 2)
  if e <= 3 then return 3 elseif e <= 6 then return 4 elseif e <= 9 then return 5 end
  return 6
end
local function nom(n) return n == 1 and "electric-mining-drill" or ("fo-lvl-drill-" .. n) end

-- minerai sur toute la zone de minage (et un peu plus), quantité large
local function minerai(s, px, py, n)
  local r = game.entity_prototypes[nom(n)].mining_drill_radius + 0.5
  for x = math.floor(px - r), math.ceil(px + r) - 1 do
    for y = math.floor(py - r), math.ceil(py + r) - 1 do
      if s.count_entities_filtered({ area = { { x + 0.1, y + 0.1 }, { x + 0.9, y + 0.9 } }, type = "resource" }) == 0 then
        s.create_entity({ name = "iron-ore", position = { x + 0.5, y + 0.5 }, amount = 50000 })
      end
    end
  end
end

local function poser(s, n, px, py, dir)
  minerai(s, px, py, n)
  local m = s.create_entity({ name = nom(n), position = { px, py }, direction = dir, force = "player" })
  local coffre
  if m then
    coffre = s.create_entity({ name = "wooden-chest", position = m.drop_position, force = "player" })
  end
  return m, coffre
end

return {
  description = "F4-B : foreuses electriques des 15 ages en marche sur du minerai (30 niveaux), jour et nuit, 4 directions",
  base = nil,
  check_tick = 600,
  shots_delay = 620,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.sites, st.dirs = {}, {}
    ctx.prepare_area(X0 - 12, Y0 - 12, X0 + 110, Y0 + 70, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy",
        area = { { X0 - 150, Y0 - 150 }, { X0 + 260, Y0 + 220 } } })) do
      en.destroy()
    end
    local src = ctx.power(X0 + 50, Y0 + 30)
    ctx.check(src ~= nil, "alimentation invisible du mod de test", src and "posee" or "prototypes absents")
    local y = Y0
    for ere = 1, 5 do
      local side = emprise((ere - 1) * 6 + 1)
      local x = X0
      for i = 1, 6 do
        local n = (ere - 1) * 6 + i
        local px, py = x + side / 2, y + side / 2
        local m, coffre = poser(s, n, px, py, defines.direction.north)
        st.sites[#st.sites + 1] = { n = n, age = math.floor((n + 1) / 2), ere = ere, m = m, coffre = coffre, x = px,
          y = py, side = side }
        x = x + side + GAP
      end
      y = y + side + 5
    end
    -- bloc des directions, à droite de la grille
    y = Y0
    for _, n in ipairs({ 3, 7, 13, 19, 29 }) do
      local side = emprise(n)
      local x = X0 + 64
      for k = 1, 4 do
        local px, py = x + side / 2, y + side / 2
        local m, coffre = poser(s, n, px, py, DIRS[k])
        st.dirs[#st.dirs + 1] = { n = n, k = k, m = m, coffre = coffre, x = px, y = py, side = side }
        x = x + side + GAP
      end
      y = y + side + 5
    end
    local poses, coffres = 0, 0
    for _, c in ipairs(st.sites) do
      if c.m then poses = poses + 1 end
      if c.coffre then coffres = coffres + 1 end
    end
    ctx.check(poses == 30 and coffres == 30, "foreuses posees sur le minerai (30 niveaux), un coffre au point de depot",
      poses .. " / 30 foreuses, " .. coffres .. " coffres")
    local bonnes = 0
    for _, d in ipairs(st.dirs) do
      if d.m and d.m.direction == DIRS[d.k] then bonnes = bonnes + 1 end
    end
    ctx.check(bonnes == 20, "bloc des directions : 5 emprises x 4 directions", bonnes .. " / 20")
    -- point de dépôt vers le nord : x = 0 (côté impair) ou -0,5 (côté pair), y au-delà du bord nord
    local bon, detail = 0, {}
    for _, c in ipairs(st.sites) do
      if c.m then
        local dx, dy = c.m.drop_position.x - c.x, c.m.drop_position.y - c.y
        local ax = (c.side % 2 == 1) and 0 or -0.5
        if math.abs(dx - ax) < 0.02 and dy < -c.side / 2 then bon = bon + 1
        else detail[#detail + 1] = string.format("niv. %d : (%.2f, %.2f)", c.n, dx, dy) end
      end
    end
    ctx.check(bon == 30, "point de depot au nord a x = 0 (impair) ou -0,5 (pair) : la goulotte dessinee y est",
      bon .. " / 30" .. (#detail > 0 and (" ; " .. table.concat(detail, " ; ")) or ""))
  end,

  finish = function(ctx)
    local st = ctx.state()
    local marche, ko = 0, {}
    for _, c in ipairs(st.sites) do
      if c.m and c.m.valid and c.m.status == defines.entity_status.working then
        marche = marche + 1
      else
        ko[#ko + 1] = tostring(c.n) .. (c.m and c.m.valid and ("=" .. tostring(c.m.status)) or "")
      end
    end
    ctx.check(marche == 30, "foreuses en marche au tick 600", marche .. " / 30" ..
      (#ko > 0 and (" ; a l'arret : " .. table.concat(ko, ",")) or ""))
    local pleins, total, vides = 0, 0, {}
    for _, c in ipairs(st.sites) do
      local q = (c.coffre and c.coffre.valid) and c.coffre.get_item_count("iron-ore") or 0
      total = total + q
      if q > 0 then pleins = pleins + 1 else vides[#vides + 1] = tostring(c.n) end
    end
    ctx.check(pleins == 30, "minerai extrait dans le coffre de chaque foreuse", pleins .. " / 30, " .. total ..
      " minerais" .. (#vides > 0 and (" ; vides : " .. table.concat(vides, ",")) or ""))
    local dm = 0
    for _, d in ipairs(st.dirs) do
      local q = (d.coffre and d.coffre.valid) and d.coffre.get_item_count("iron-ore") or 0
      if d.m and d.m.valid and q > 0 then dm = dm + 1 end
    end
    ctx.check(dm == 20, "bloc des directions : les 20 foreuses extraient dans leur coffre", dm .. " / 20")
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
    for i = 1, #st.dirs, 4 do
      local a, d = st.dirs[i], st.dirs[i + 3]
      local x0, x1 = a.x - a.side / 2, d.x + d.side / 2
      local cx, cy = (x0 + x1) / 2, a.y - 0.5
      local nm = string.format("directions-niv%02d-z1", a.n)
      add(nm, cx, cy, 1, 0, { res = { math.ceil((x1 - x0 + 4) * 32), math.ceil((a.side + 5) * 32) }, info = false,
        aa = true })
      L[#L + 1] = string.format("%s\t%d\t%d\t0\t%.2f\t%.2f\tdirections", nm, a.n, math.floor((a.n + 1) / 2), cx, cy)
    end
    game.write_file("fo-shots/f4-foreuses-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
