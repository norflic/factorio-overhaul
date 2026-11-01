-- Scénario greffé du lot RB-0 (31/10), essai E9 : araignées « ultra énormes » (le DC : 30 à 50 tuiles à l'écran).
-- À LANCER SUR LA COPIE JETABLE : banc.py ... --qui RB0 -- 2500 rb0-colosse <copie>
--
-- Araignées rb0-spider-2, -3, -5, -5l, -8 (create_spidertron vanilla, échelle 2, 3, 5, 5 (pattes x1,2), 8). Mesures :
--   (a) GÉOMÉTRIE : boîtes du prototype (collision, sélection, dessin), entité créée, étendue réelle des pattes
--       (get_spider_legs : largeur et hauteur du polygone des pieds), find_entities_filtered au bord du corps.
--   (b) TIR : 100 obus par script ; couronne de 9 tourelles ennemies sans munitions à 20, 40, 50, 58, 62, 70, 90, 98 et
--       102 tuiles (angles tous différents) ; une tourelle tuée = à portée. Canons : 45 (-2), 60 (-3, -5, -8), 100 (-5l).
--   (c) MARCHE : 70 tuiles vers l'est, sur sol libre, mur de 3, eau de 10, eau de 30, forêt, falaise (add_autopilot_destination).
--       Vitesse = x à 300 ticks. on_spider_command_completed = arrivée.
--   (d) CHEMIN : request_path pour des boîtes ±1, 3, 3,9, 4,1, 6 dans un mur à trouée de 8 tuiles.
-- Le coût par tick est mesuré à part (rb0-cout-*).

local C = require("scenarios/rb0_common")

local T0 = 60
local CHECK = 2450
local NOMS = { "rb0-spider-2", "rb0-spider-3", "rb0-spider-5", "rb0-spider-5l", "rb0-spider-8" }
local DIST = { 20, 40, 50, 58, 62, 70, 90, 98, 102 }
local TIR_X, TIR_Y, TIR_PAS = 8000, 8000, 260
local MAR_X, MAR_Y, MAR_PAS_Y, MAR_PAS_X = 8400, 8000, 120, 110
local OBST = { "libre", "mur3", "eau10", "eau30", "foret", "falaise" }
local PX, PY = 8000, 9700

script.on_event(defines.events.on_spider_command_completed, function(e)
  local g = C.g()
  local v = e.vehicle
  if v and v.valid and g.spiders and g.spiders[v.unit_number] then
    local r = g.spiders[v.unit_number]
    r.fini = r.fini or e.tick
  end
end)

script.on_event(defines.events.on_script_path_request_finished, function(e)
  local g = C.g()
  if g.requetes and g.requetes[e.id] then
    local r = g.requetes[e.id]
    local n = e.path and #e.path or 0
    r.n = n
    r.retry = e.try_again_later
    r.t_rep = e.tick
    if n > 0 then
      local ymin, ymax = 1e9, -1e9
      for i = 1, n do
        local y = e.path[i].position.y
        if y < ymin then ymin = y end
        if y > ymax then ymax = y end
      end
      r.ymin, r.ymax = ymin, ymax
      r.detruit = false
      for i = 1, n do if e.path[i].needs_destroy_to_reach then r.detruit = true end end
    end
  end
end)

local function etendue_pattes(sp)
  local ok, legs = pcall(function() return sp.get_spider_legs() end)
  if not ok or not legs then return nil end
  local x0, x1, y0, y1 = 1e9, -1e9, 1e9, -1e9
  for _, l in ipairs(legs) do
    if l.valid then
      local p = l.position
      x0, x1, y0, y1 = math.min(x0, p.x), math.max(x1, p.x), math.min(y0, p.y), math.max(y1, p.y)
    end
  end
  return #legs, x1 - x0, y1 - y0
end

local function sur_eau(s, p)
  local t = s.get_tile(math.floor(p.x), math.floor(p.y))
  return t.valid and t.collides_with("water-tile")
end

local function box(b)
  if not b then return "nil" end
  local lt, rb = b.left_top or b[1], b.right_bottom or b[2]
  return string.format("[%.1f,%.1f / %.1f,%.1f]", lt.x or lt[1], lt.y or lt[2], rb.x or rb[1], rb.y or rb[2])
end

return {
  description = "RB-0 E9 : araignees ultra enormes : boites, tir longue portee, marche sur obstacles, chemin d'une grosse boite",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    st.pret = false
    if not C.exige(ctx, NOMS, #NOMS .. " araignees") then return end
    local s = ctx.surface()
    C.force("rb0")
    game.map_settings.enemy_expansion.enabled = false
    local g = C.g()
    g.spiders, g.requetes = {}, {}
    -- terrains
    ctx.prepare_area(TIR_X - 120, TIR_Y - 120, TIR_X + 120, TIR_Y + TIR_PAS * #NOMS, "grass-1")
    ctx.prepare_area(MAR_X - 20, MAR_Y - 70, MAR_X + MAR_PAS_X * #OBST + 80, MAR_Y + MAR_PAS_Y * #NOMS, "grass-1")
    ctx.prepare_area(PX - 20, PY - 80, PX + 140, PY + 80, "grass-1")
    C.sans_ennemis(s, TIR_X - 140, TIR_Y - 140, MAR_X + 900, PY + 120)
    st.tir, st.mar, st.geo, st.chemin = {}, {}, {}, {}
    local rng = game.create_random_generator(9102026)

    for i, nom in ipairs(NOMS) do
      local proto = game.entity_prototypes[nom]
      -- (a)+(b) tir
      local y = TIR_Y + TIR_PAS * (i - 1)
      local sp = s.create_entity({ name = nom, position = { TIR_X, y }, force = "rb0" })
      local r = { nom = nom, e = sp, y = y, tourelles = {} }
      if sp then
        g.spiders[sp.unit_number] = r
        sp.vehicle_automatic_targeting_parameters = { auto_target_without_gunner = true, auto_target_with_gunner = true }
        local inv = sp.get_inventory(defines.inventory.spider_ammo)
        r.obus = inv and inv.insert({ name = "rb0-shell", count = 100 }) or -1
        r.mil = tostring(sp.is_military_target)
        r.bb = sp.bounding_box
      end
      for k, d in ipairs(DIST) do
        local a = math.rad(37 * k + 11)
        local tx, ty = math.floor(TIR_X + d * math.cos(a) + 0.5), math.floor(y + d * math.sin(a) + 0.5)
        local t = s.create_entity({ name = "gun-turret", position = { tx, ty }, force = "enemy" })
        r.tourelles[#r.tourelles + 1] = { e = t, d = d }
      end
      r.proto = string.format("collision=%s selection=%s drawing=%s", box(proto.collision_box), box(proto.selection_box),
        tostring(pcall(function() return proto.drawing_box end) and box(proto.drawing_box) or "illisible"))
      st.tir[#st.tir + 1] = r

      -- (c) marche
      for j, o in ipairs(OBST) do
        local my = MAR_Y + MAR_PAS_Y * (i - 1)
        local mx = MAR_X + MAR_PAS_X * (j - 1)
        local x1 = mx + 25
        if o == "mur3" then
          for dx = 0, 2 do
            for dy = -50, 50 do s.create_entity({ name = "stone-wall", position = { x1 + dx + 0.5, my + dy + 0.5 }, force = "player" }) end
          end
        elseif o == "eau10" then C.eau(s, x1, my - 60, x1 + 10, my + 60, "deepwater")
        elseif o == "eau30" then C.eau(s, x1, my - 60, x1 + 30, my + 60, "deepwater")
        elseif o == "foret" then
          for _ = 1, 300 do s.create_entity({ name = "tree-02", position = { x1 + rng(20) - 0.5, my - 25 + rng(50) - 0.5 } }) end
        elseif o == "falaise" then
          for k = -12, 12 do
            s.create_entity({ name = "cliff", position = { x1 + 5, my + 4 * k }, cliff_orientation = "north-to-south" })
          end
        end
        local sp2 = s.create_entity({ name = nom, position = { mx, my }, force = "rb0" })
        local m = { nom = nom, obst = o, e = sp2, but = { mx + 70, my }, sur_eau = 0, max_x = mx }
        if sp2 then
          g.spiders[sp2.unit_number] = m
        end
        st.mar[#st.mar + 1] = m
      end
    end

    -- (d) chemin : mur à trouée de 8 tuiles, y de PY-40 à PY+40, trouée de PY-4 à PY+4
    for dx = 0, 1 do
      for dy = -40, 39 do
        if dy < -4 or dy >= 4 then s.create_entity({ name = "stone-wall", position = { PX + 40 + dx + 0.5, PY + dy + 0.5 }, force = "player" }) end
      end
    end
    for _, demi in ipairs({ 1, 3, 3.9, 4.1, 6 }) do
      st.chemin[#st.chemin + 1] = { demi = demi }
    end
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local s = ctx.surface()
    local g = C.g()
    local t = e.tick
    if t == T0 then
      for _, m in ipairs(st.mar) do
        if m.e and m.e.valid then m.e.add_autopilot_destination({ x = m.but[1], y = m.but[2] }) end
      end
      for _, c in ipairs(st.chemin) do
        local id = s.request_path({ bounding_box = { { -c.demi, -c.demi }, { c.demi, c.demi } },
          collision_mask = { "water-tile", "player-layer", "object-layer", "item-layer" },
          start = { x = PX, y = PY }, goal = { x = PX + 80, y = PY }, force = "rb0", radius = 2, pathfind_flags = { cache = false } })
        g.requetes[id] = c
        c.t_req = t
      end
    end
    -- géométrie à t = 100 (pattes posées)
    if t == 100 then
      for _, r in ipairs(st.tir) do
        if r.e and r.e.valid then
          r.n_pattes, r.larg, r.haut = etendue_pattes(r.e)
          local sc = tonumber(r.nom:match("rb0%-spider%-(%d+)")) or 1
          local trouves = s.find_entities_filtered({ position = { r.e.position.x + sc * 0.9, r.e.position.y }, radius = 0.3, type = "spider-vehicle" })
          r.trouve_bord = #trouves
          local loin = s.find_entities_filtered({ position = { r.e.position.x + sc * 1.6, r.e.position.y }, radius = 0.3, type = "spider-vehicle" })
          r.trouve_hors = #loin
        end
      end
    end
    if t >= T0 then
      for _, m in ipairs(st.mar) do
        if m.e and m.e.valid then
          if m.e.position.x > m.max_x then m.max_x = m.e.position.x end
          if t % 10 == 0 and sur_eau(s, m.e.position) then m.sur_eau = m.sur_eau + 10 end
          if t == T0 + 300 then m.x300 = m.e.position.x end
        end
      end
      for _, r in ipairs(st.tir) do
        for _, tu in ipairs(r.tourelles) do
          if tu.e and not tu.mort and not tu.e.valid then tu.mort = t end
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    for _, r in ipairs(st.tir) do
      ctx.log(string.format("E9a %-14s : %s ; bounding_box=%s ; military=%s ; pattes=%s etendue=%s x %s ; trouve au bord du corps=%s hors corps=%s",
        r.nom, r.proto, tostring(r.bb and box(r.bb)), tostring(r.mil), tostring(r.n_pattes), C.fmt(r.larg, 1), C.fmt(r.haut, 1),
        tostring(r.trouve_bord), tostring(r.trouve_hors)))
      local l, dmax = {}, 0
      for _, tu in ipairs(r.tourelles) do
        l[#l + 1] = tu.d .. "=" .. (tu.mort and ("tuee@" .. (tu.mort - T0)) or (tu.e and tu.e.valid and "vivante" or "absente"))
        if tu.mort and tu.d > dmax then dmax = tu.d end
      end
      local restant = -1
      if r.e and r.e.valid then
        local inv = r.e.get_inventory(defines.inventory.spider_ammo)
        restant = inv and inv.get_item_count("rb0-shell") or -1
      end
      r.dmax = dmax
      ctx.log(string.format("E9b %-14s : obus inseres=%s restants=%d ; tourelles %s ; plus lointaine tuee = %d", r.nom, tostring(r.obus), restant, table.concat(l, " "), dmax))
    end
    local portee = { ["rb0-spider-2"] = 45, ["rb0-spider-3"] = 60, ["rb0-spider-5"] = 60, ["rb0-spider-5l"] = 100, ["rb0-spider-8"] = 60 }
    for _, r in ipairs(st.tir) do
      ctx.check(r.dmax > 0, "E9b " .. r.nom .. " tire sans conducteur (canon " .. portee[r.nom] .. ")", "plus lointaine tuee " .. r.dmax)
    end
    -- marche
    ctx.log("E9c marche (70 tuiles vers l'est) : araignee ; obstacle ; x a 300 ticks (depart = 0) ; max_x atteint ; arrivee (tick) ; ticks sur l'eau ; position finale")
    for _, m in ipairs(st.mar) do
      if m.e and m.e.valid then
        ctx.log(string.format("E9c %-14s %-8s : v300=%s max=%.1f fini=%s eau=%d fin=%s distance_but=%.1f", m.nom, m.obst,
          m.x300 and C.fmt(m.x300 - (m.but[1] - 70), 1) or "-", m.max_x - (m.but[1] - 70), tostring(m.fini and (m.fini - T0)), m.sur_eau, C.pos(m.e.position),
          C.dist(m.e.position, { x = m.but[1], y = m.but[2] })))
      else
        ctx.log(string.format("E9c %-14s %-8s : absente ou detruite", m.nom, m.obst))
      end
    end
    -- chemin
    for _, c in ipairs(st.chemin) do
      ctx.log(string.format("E9d boite ±%s : %s point(s) retry=%s reponse apres %s ticks ; y du chemin de %s a %s ; passe par un mur=%s", tostring(c.demi),
        tostring(c.n), tostring(c.retry), tostring(c.t_rep and (c.t_rep - c.t_req)), C.fmt(c.ymin, 1), C.fmt(c.ymax, 1), tostring(c.detruit)))
    end
    ctx.check(st.chemin[1].n ~= nil and st.chemin[1].n > 0, "E9d request_path rend un chemin pour la petite boite", tostring(st.chemin[1].n))
  end,
}
