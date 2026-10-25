-- Scénario greffé du lot F3-B (25/10) : LA MACHINE D'ASSEMBLAGE des 15 âges en jeu, 30 niveaux, de jour et de nuit, EN
-- MARCHE, et ses raccords de tuyau. Sur le modèle de f2-fours (lot F2-B).
--   & "<racine>\fo-autotest.bat" nopause 400 f3-assembleurs "<source>"     (contrôles, sans images)
--   & "<racine>\fo-captures.bat" f3-assembleurs "<source>"                  (captures, sans son)
-- Grille : une rangée par ère (5), six machines par rangée (trois âges, niveau impair puis pair), alimentées (source
-- invisible du mod de test), recette d'engrenages et plaques de fer : elles TRAVAILLENT (lueur rejouée, lumière).
-- Rangée des raccords : une machine par emprise (3, 4, 5, 6 : niveaux 3, 7, 13, 19), un tuyau posé à chacun de ses
-- raccords : la bride dessinée doit être au tuyau (x = 0 aux côtés impairs, −0,5 aux côtés pairs).
-- Captures : chaque ère au zoom 1, de jour et de nuit ; chaque âge (impair et pair côte à côte) au zoom 2, de jour et de
-- nuit ; la rangée des raccords au zoom 2. Table : fo-shots/f3-assembleurs-sites.tsv.

local X0, Y0 = 3200, 3000
local GAP = 2

local function emprise(n)
  local e = math.floor((n + 1) / 2)
  if e <= 3 then return 3 elseif e <= 6 then return 4 elseif e <= 9 then return 5 end
  return 6
end
local function nom(n) return n == 1 and "assembling-machine-2" or ("fo-lvl-assembler-" .. n) end

return {
  description = "F3-B : machines d'assemblage des 15 ages en marche (30 niveaux), jour et nuit, raccords de tuyau",
  base = nil,
  check_tick = 300,
  shots_delay = 320,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.sites, st.raccords = {}, {}
    ctx.prepare_area(X0 - 12, Y0 - 12, X0 + 80, Y0 + 80, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy",
        area = { { X0 - 150, Y0 - 150 }, { X0 + 220, Y0 + 220 } } })) do
      en.destroy()
    end
    local src = ctx.power(X0 + 30, Y0 + 30)
    ctx.check(src ~= nil, "alimentation invisible du mod de test", src and "posee" or "prototypes absents")
    local y = Y0
    for ere = 1, 5 do
      local side = emprise((ere - 1) * 6 + 1)
      local x = X0
      for i = 1, 6 do
        local n = (ere - 1) * 6 + i
        local age = math.floor((n + 1) / 2)
        local px = x + side / 2
        local py = y + side / 2
        local m = s.create_entity({ name = nom(n), position = { px, py }, force = "player" })
        if m then
          pcall(function() m.set_recipe("iron-gear-wheel") end)
          m.insert({ name = "iron-plate", count = 200 })
        end
        st.sites[#st.sites + 1] = { n = n, age = age, ere = ere, m = m, x = px, y = py, side = side }
        x = x + side + GAP
      end
      y = y + side + 4
    end
    -- rangée des raccords : un tuyau à chaque raccord
    local x = X0
    y = y + 2
    for _, n in ipairs({ 3, 7, 13, 19 }) do
      local side = emprise(n)
      local px, py = x + side / 2, y + side / 2
      local m = s.create_entity({ name = nom(n), position = { px, py }, force = "player" })
      local r = { n = n, side = side, m = m, x = px, y = py, tuyaux = {}, dx = {} }
      if m then
        for i = 1, #m.fluidbox do
          for _, pc in ipairs(m.fluidbox.get_pipe_connections(i)) do
            r.dx[#r.dx + 1] = pc.position.x - px
            local t = s.create_entity({ name = "pipe", position = pc.target_position, force = "player" })
            if t then r.tuyaux[#r.tuyaux + 1] = t end
          end
        end
      end
      st.raccords[#st.raccords + 1] = r
      x = x + side + 4
    end
    local poses = 0
    for _, c in ipairs(st.sites) do if c.m then poses = poses + 1 end end
    ctx.check(poses == 30, "machines posees (30 niveaux)", poses .. " / 30")
    local bon, detail = 0, {}
    for _, r in ipairs(st.raccords) do
      local attendu = (r.side % 2 == 1) and 0 or -0.5
      local ok = #r.dx == 2 and #r.tuyaux == 2
      for _, d in ipairs(r.dx) do ok = ok and math.abs(d - attendu) < 0.01 end
      if ok then bon = bon + 1 end
      detail[#detail + 1] = string.format("%dx%d : %d raccord(s) en x = %s (attendu %.1f), %d tuyau(x)", r.side, r.side,
        #r.dx, table.concat((function() local t = {} for _, d in ipairs(r.dx) do t[#t + 1] = string.format("%.2f", d)
        end return t end)(), ","), attendu, #r.tuyaux)
    end
    ctx.check(bon == 4, "raccords de tuyau au milieu des bords (x = 0 impair, -0,5 pair : brides dessinees)",
      table.concat(detail, " ; "))
  end,

  finish = function(ctx)
    local st = ctx.state()
    local marche, ko = 0, {}
    for _, c in ipairs(st.sites) do
      if c.m and c.m.valid and c.m.status == defines.entity_status.working then
        marche = marche + 1
      else
        ko[#ko + 1] = tostring(c.n)
      end
    end
    ctx.check(marche == 30, "machines en marche au tick 300", marche .. " / 30" ..
      (#ko > 0 and (" ; a l'arret : " .. table.concat(ko, ",")) or ""))
    local roues = 0
    for _, c in ipairs(st.sites) do
      if c.m and c.m.valid then roues = roues + c.m.get_inventory(defines.inventory.assembling_machine_output)
          .get_item_count("iron-gear-wheel") + c.m.products_finished end
    end
    ctx.check(roues > 0, "engrenages produits", tostring(roues))
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
    local r1, r4 = st.raccords[1], st.raccords[#st.raccords]
    local x0, x1 = r1.x - r1.side / 2, r4.x + r4.side / 2
    local cx, cy = (x0 + x1) / 2, r4.y
    add("raccords-z2", cx, cy, 2, 0, { res = { math.ceil((x1 - x0 + 3) * 64), math.ceil((r4.side + 5) * 64) },
      info = false, aa = true })
    L[#L + 1] = string.format("raccords-z2\t0\t0\t0\t%.2f\t%.2f\traccords", cx, cy)
    game.write_file("fo-shots/f3-assembleurs-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
