-- Scénario greffé du lot DA-ATELIERS (4/11) : les bâtiments d'atelier « à part » EN JEU, en marche, de jour et de nuit, et les
-- raccords de fluide de la torchère dans ses 4 rotations (preuve demandée par le lead : chaque tronçon de pipe_picture tombe sur le
-- point de connexion du prototype, un tuyau vanilla y est posé).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui da-ateliers -- 400 da-ateliers <source>              (contrôles)
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --qui da-ateliers -- 400 da-ateliers <source>   (captures)
-- Rangée 1 : torchère tournée N, E, S, O, recette « fo-flare-ethylene », tuyau vanilla au raccord puis tuyau infini (éthylène) :
-- elle BRÛLE (flamme fire-flame, lumières). Rangée 2 : concasseur (charbon, pierre), broyeur à mâchoires (pierre), et à côté, à la
-- même échelle, assembleur 2, four en pierre et usine chimique vanilla. Source d'énergie invisible du mod de test.

local X0, Y0 = 4200, 3000
local DIRS = { { "n", defines.direction.north }, { "e", defines.direction.east }, { "s", defines.direction.south }, { "o", defines.direction.west } }

local function activer(recettes)
  for _, r in ipairs(recettes) do
    local p = game.forces.player.recipes[r]
    if p then p.enabled = true end
  end
end

return {
  description = "DA-ATELIERS : torchere (4 rotations, raccords, flamme), concasseur et broyeur en marche, voisins vanilla, jour et nuit",
  base = nil,
  check_tick = 300,
  shots_delay = 330,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.torcheres, st.machines = {}, {}
    ctx.prepare_area(X0 - 14, Y0 - 14, X0 + 50, Y0 + 30, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 150, Y0 - 150 }, { X0 + 200, Y0 + 200 } } })) do
      en.destroy()
    end
    local src = ctx.power(X0 + 18, Y0 + 9)
    ctx.check(src ~= nil, "alimentation invisible du mod de test", src and "posee" or "prototypes absents")
    activer({ "fo-flare-ethylene", "fo-sand" })
    -- rangée 1 : torchère dans ses 4 rotations ; tuyau vanilla au raccord, tuyau infini au-delà
    local proto = game.entity_prototypes["fo-flare-stack"]
    local pc = proto.fluidbox_prototypes[1].pipe_connections[1]
    for i, d in ipairs(DIRS) do
      local px, py = X0 + (i - 1) * 7 + 1, Y0 + 1
      local m = s.create_entity({ name = "fo-flare-stack", position = { px, py }, force = "player", direction = d[2],
                                  recipe = "fo-flare-ethylene" })
      local q = pc.positions[(d[2] / 2) + 1]
      local t = { dir = d[1], m = m, x = px, y = py, q = { q.x, q.y } }
      if m then
        local ox, oy = (q.x > 0.6 and 1) or (q.x < -0.6 and -1) or 0, (q.y > 0.6 and 1) or (q.y < -0.6 and -1) or 0
        t.tuyau = s.create_entity({ name = "pipe", position = { px + q.x, py + q.y }, force = "player" })
        local inf = s.create_entity({ name = "infinity-pipe", position = { px + q.x + ox, py + q.y + oy }, force = "player" })
        if inf then inf.set_infinity_pipe_filter({ name = "fo-ethylene", percentage = 1 }) end
      end
      st.torcheres[#st.torcheres + 1] = t
    end
    -- rangée 2 : concasseur, broyeur, voisins vanilla
    local y2 = Y0 + 9
    local function poser(nom, x, y, recette, items)
      local m = s.create_entity({ name = nom, position = { x, y }, force = "player", recipe = recette })
      if m then
        for _, it in ipairs(items or {}) do m.insert(it) end
      end
      st.machines[#st.machines + 1] = { nom = nom, m = m, x = x, y = y }
      return m
    end
    poser("fo-crusher", X0 + 1, y2 + 1, "fo-sand", { { name = "coal", count = 50 }, { name = "stone", count = 100 } })
    poser("fo-jaw-crusher", X0 + 5.5, y2 + 1.5, "fo-sand", { { name = "stone", count = 200 } })
    poser("assembling-machine-2", X0 + 10.5, y2 + 1.5, "iron-gear-wheel", { { name = "iron-plate", count = 100 } })
    poser("stone-furnace", X0 + 14, y2 + 1, nil, { { name = "coal", count = 20 }, { name = "iron-ore", count = 50 } })
    poser("chemical-plant", X0 + 17.5, y2 + 1.5, nil, {})
    local n = 0
    for _, t in ipairs(st.torcheres) do if t.m and t.tuyau then n = n + 1 end end
    ctx.check(n == 4, "torcheres posees dans les 4 rotations, tuyau vanilla au raccord", n .. " / 4")
    local mp = 0
    for _, m in ipairs(st.machines) do if m.m then mp = mp + 1 end end
    ctx.check(mp == #st.machines, "concasseur, broyeur et voisins vanilla poses", mp .. " / " .. #st.machines)
  end,

  finish = function(ctx)
    local st = ctx.state()
    local raccordes, marche, detail = 0, 0, {}
    for _, t in ipairs(st.torcheres) do
      local ok = false
      if t.m and t.m.valid and t.tuyau and t.tuyau.valid then
        for _, c in ipairs(t.m.fluidbox.get_connections(1)) do
          if c.owner and c.owner.valid and c.owner.unit_number == t.tuyau.unit_number then ok = true end
        end
        if t.m.status == defines.entity_status.working then marche = marche + 1 end
      end
      if ok then raccordes = raccordes + 1 end
      detail[#detail + 1] = string.format("%s : raccord (%.1f ; %.1f) %s", t.dir, t.q[1], t.q[2], ok and "relie" or "NON RELIE")
    end
    ctx.check(raccordes == 4, "raccord de chaque rotation relie au tuyau vanilla (point de connexion du prototype)", table.concat(detail, " ; "))
    ctx.check(marche == 4, "torcheres en marche (elles brulent)", marche .. " / 4")
    local en = {}
    for _, m in ipairs(st.machines) do
      if m.nom == "fo-crusher" or m.nom == "fo-jaw-crusher" then
        local ok = m.m and m.m.valid and m.m.status == defines.entity_status.working
        en[#en + 1] = m.nom .. (ok and " en marche" or (" : " .. tostring(m.m and m.m.valid and m.m.status)))
        ctx.check(ok, m.nom .. " en marche", en[#en])
      end
    end
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local t1, t4 = st.torcheres[1], st.torcheres[#st.torcheres]
    local cx, cy = (t1.x + t4.x) / 2, t1.y - 2.2
    local L = { "capture\tzoom\tnuit\tx\ty" }
    for _, nuit in ipairs({ false, true }) do
      local nm = "torcheres-4-rotations-z2-" .. (nuit and "nuit" or "jour")
      add(nm, cx, cy, 2, nuit and 0.5 or 0, { res = { 1760, 640 }, info = false, aa = true })
      L[#L + 1] = string.format("%s\t2\t%d\t%.2f\t%.2f", nm, nuit and 1 or 0, cx, cy)
    end
    -- raccords de près : chaque rotation au zoom 2, avec son tuyau vanilla
    for _, t in ipairs(st.torcheres) do
      local nm = "torchere-raccord-" .. t.dir .. "-z2"
      add(nm, t.x + t.q[1] * 0.5, t.y + t.q[2] * 0.5, 2, 0, { res = { 384, 384 }, info = false, aa = true })
      L[#L + 1] = string.format("%s\t2\t0\t%.2f\t%.2f", nm, t.x, t.y)
    end
    local m1, m5 = st.machines[1], st.machines[#st.machines]
    local mx, my = (m1.x + m5.x) / 2, m1.y - 0.6
    for _, nuit in ipairs({ false, true }) do
      for _, z in ipairs({ 2, 1 }) do
        local nm = string.format("carriere-et-vanilla-z%d-%s", z, nuit and "nuit" or "jour")
        add(nm, mx, my, z, nuit and 0.5 or 0, { res = { z == 2 and 1600 or 800, z == 2 and 480 or 240 }, info = false, aa = true })
        L[#L + 1] = string.format("%s\t%d\t%d\t%.2f\t%.2f", nm, z, nuit and 1 or 0, mx, my)
      end
    end
    add("vue-ensemble-z1-jour", (t1.x + m5.x) / 2, (t1.y + m5.y) / 2 - 1.5, 1, 0, { res = { 960, 560 }, info = false, aa = true })
    L[#L + 1] = "vue-ensemble-z1-jour\t1\t0\t0\t0"
    game.write_file("fo-shots/da-ateliers-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
