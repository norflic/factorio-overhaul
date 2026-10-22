--[[
  Scénario GREFFÉ « t3-libere » (lot V3-T3, 22/10) : bouton « LIBÉRER LA PLACE » en moteur réel (Q-T2-1, réponse du
  Directeur Créatif : « QT21 option B »). Format : tools/autotest/README.md §4. Sans double source (le cas hors grille
  après une vraie migration est le scénario t3-migration, en double source).

  Règle Q24 inchangée : sans clic, refus « no-room » et contour (cas D). Au clic (interface distante levels_free_room,
  comme le bouton du panneau) : gêneurs MARQUÉS à démonter, FANTÔMES décalés, demande d'agrandissement en attente.
  Le banc joue ensuite les robots : il MINE les entités marquées (LuaEntity.mine, dans un inventaire « robot » : rien
  ne se perd), le mod agrandit le bâtiment de lui-même à sa vérification périodique, puis le banc construit les
  fantômes (revive, en retirant de l'inventaire « robot » l'objet que le robot aurait porté) et vérifie que l'usine
  REMARCHE.

  Cas (force « fo-t3 », centre 15 qui paie ; force « fo-t3p », centre 15 VIDE, pour le paiement impossible) :
    A. usine dense : assembleur 6 (3×3) bordé d'un bras au nord (entrée, convoyeur de plaques au-delà) et d'un bras au
       sud (sortie, convoyeur au-delà), voisin collé à l'ouest (même disposition), poteau moyen à l'est relié à un
       autre poteau. 3×3 → 4×4 : candidate sud-est ; bras sud reposé une tuile au sud, convoyeur sud en bosse, poteau
       décalé d'une tuile à l'est ;
    B1. mitrailleuse 6 (2×2) collée à un mur au nord, nourrie par un bras au sud (convoyeur de munitions au-delà),
       voisine collée à l'ouest (Q-T3). 2×2 → 3×3 : candidate sud-est ; bras et convoyeur en bosse ;
    B2. mitrailleuse 6 collée à un mur ÉPAIS (deux rangées de murs de niveau 7) au nord, eau au sud, voisine à l'ouest :
       candidate nord-est (la candidate évite l'eau) ; murs décalés (épaisseur gardée), ligne refermée par des murs de
       liaison ;
    C1. comme A, puis « Annuler » tout de suite : marques et fantômes du mod retirés, un fantôme et une marque du
       joueur posés avant, intacts ;
    C2. comme A, le bras sud démonté (groupe commencé), puis « Annuler » : le groupe commencé est gardé entier, le
       poteau (groupe non commencé) est rendu ;
    D. comme B1, SANS clic : refus, rien de marqué ni de posé, rien ne change ;
    E. comme B1 sans voisine, force au centre vide : la place se libère, le coût manque : message, la demande attend ;
       le coût arrive : l'agrandissement se fait.
]]

local LV = require("__factorio-overhaul__/shared/levels/config")
local Foot = require("__factorio-overhaul__/shared/levels/footprint")

local AS, G, WALL, CC = LV.by_key.assembler, LV.by_key.gun, LV.by_key.wall, LV.by_key.command
local N, E, S, W = defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west
local ZX0, ZY0, ZX1, ZY1 = 300, 240, 412, 340
local FORCE, FORCE_P = "fo-t3", "fo-t3p"
local ACT, MINE, GROW, BUILD, PAY_E, CHECK = 60, 400, 470, 500, 530, 1400
local AREA = {
  A = { ZX0, ZY0 }, C1 = { ZX0 + 36, ZY0 }, C2 = { ZX0 + 72, ZY0 },
  B1 = { ZX0, ZY0 + 30 }, B2 = { ZX0 + 36, ZY0 + 30 }, D = { ZX0 + 72, ZY0 + 30 },
  E = { ZX0, ZY0 + 60 },
}
local AREA_KEYS = { "A", "C1", "C2", "B1", "B2", "D", "E" }

local function fmt(p) return p and string.format("%g, %g", p.x, p.y) or "nil" end
local function near(a, b) return math.abs(a - b) < 1 / 64 end

local function make_force(name)
  local f = game.forces[name] or game.create_force(name)
  for _, other in ipairs({ "player", "enemy" }) do
    f.set_cease_fire(other, true)
    game.forces[other].set_cease_fire(f, true)
  end
  return f
end

local function zone_box(key)
  local o = AREA[key]
  return { { o[1], o[2] }, { o[1] + 32, o[2] + 28 } }
end

local function put(s, f, name, x, y, dir)
  return s.create_entity({ name = name, position = { x, y }, direction = dir, force = f, raise_built = true })
end

---------------------------------------------------------------------------------------------------
-- Dispositions
---------------------------------------------------------------------------------------------------
--- Usine dense (A, C1, C2) : renvoie les entités utiles.
local function build_dense(s, f, key)
  local o = AREA[key]
  local ox, oy = o[1], o[2]
  local t = {}
  t.m = put(s, f, LV.name(AS, 6), ox + 16.5, oy + 10.5, N)
  t.w = put(s, f, LV.name(AS, 6), ox + 13.5, oy + 10.5, N)
  for _, m in ipairs({ t.m, t.w }) do if m then m.set_recipe("iron-gear-wheel") end end
  t.m_in = put(s, f, "inserter", ox + 16.5, oy + 8.5, N)
  t.m_out = put(s, f, "inserter", ox + 16.5, oy + 12.5, N)
  put(s, f, "inserter", ox + 13.5, oy + 8.5, N)
  put(s, f, "inserter", ox + 13.5, oy + 12.5, N)
  for x = ox + 10.5, ox + 22.5 do
    put(s, f, "transport-belt", x, oy + 7.5, E)
    put(s, f, "transport-belt", x, oy + 13.5, E)
  end
  local src = put(s, f, "infinity-chest", ox + 10.5, oy + 5.5)
  if src then src.set_infinity_container_filter(1, { name = "iron-plate", count = 50, mode = "at-least" }) end
  put(s, f, "fast-inserter", ox + 10.5, oy + 6.5, N)
  put(s, f, "inserter", ox + 23.5, oy + 13.5, W)
  t.out_chest = put(s, f, "iron-chest", ox + 24.5, oy + 13.5)
  t.pole = put(s, f, "medium-electric-pole", ox + 18.5, oy + 10.5)
  t.pole2 = put(s, f, "medium-electric-pole", ox + 24.5, oy + 10.5)
  return t
end

--- Mitrailleuse nourrie par un bras (B1, D, E) ; voisine collée à l'ouest si `neighbour`.
local function build_turret_arm(s, f, key, neighbour)
  local o = AREA[key]
  local ox, oy = o[1], o[2]
  local t = {}
  t.g = put(s, f, LV.name(G, 6), ox + 20, oy + 10)
  if neighbour then
    t.n = put(s, f, LV.name(G, 6), ox + 18, oy + 10)
    put(s, f, "inserter", ox + 18.5, oy + 11.5, S)
  end
  for x = ox + 15.5, ox + 25.5 do put(s, f, LV.name(WALL, 7), x, oy + 8.5) end
  t.arm = put(s, f, "inserter", ox + 20.5, oy + 11.5, S)
  for x = ox + 15.5, ox + 25.5 do put(s, f, "transport-belt", x, oy + 12.5, E) end
  local src = put(s, f, "infinity-chest", ox + 15.5, oy + 14.5)
  if src then src.set_infinity_container_filter(1, { name = "firearm-magazine", count = 50, mode = "at-least" }) end
  put(s, f, "inserter", ox + 15.5, oy + 13.5, S)
  return t
end

--- Mitrailleuse collée à un mur épais, eau au sud (B2).
local function build_turret_wall(s, f, key)
  local o = AREA[key]
  local ox, oy = o[1], o[2]
  local t = {}
  local water = {}
  for x = ox + 16, ox + 24 do for y = oy + 11, oy + 12 do water[#water + 1] = { name = "water", position = { x, y } } end end
  s.set_tiles(water)
  t.g = put(s, f, LV.name(G, 6), ox + 20, oy + 10)
  if t.g then t.g.insert({ name = "firearm-magazine", count = 10 }) end
  t.n = put(s, f, LV.name(G, 6), ox + 18, oy + 10)
  for x = ox + 15.5, ox + 25.5 do
    put(s, f, LV.name(WALL, 7), x, oy + 8.5)
    put(s, f, LV.name(WALL, 7), x, oy + 7.5)
  end
  return t
end

---------------------------------------------------------------------------------------------------
-- Relevés
---------------------------------------------------------------------------------------------------
local function in_zone(key, filter)
  local s = game.surfaces[1]
  return s.find_entities_filtered({ area = zone_box(key), type = filter and filter.type })
end

local function marked(key)
  local out = {}
  for _, e in ipairs(in_zone(key)) do
    if e.valid and e.type ~= "entity-ghost" and e.to_be_deconstructed() then out[#out + 1] = e end
  end
  return out
end

local function ghosts(key)
  return in_zone(key, { type = "entity-ghost" })
end

local function list_text(list, ghost)
  local t = {}
  for _, e in ipairs(list) do
    t[#t + 1] = string.format("%s@%g,%g/%d", ghost and e.ghost_name or e.name, e.position.x, e.position.y, e.direction or 0)
  end
  table.sort(t)
  return table.concat(t, " ")
end

local function has_ghost(list, name, x, y, dir)
  for _, g in ipairs(list) do
    if g.valid and g.ghost_name == name and near(g.position.x, x) and near(g.position.y, y) and (dir == nil or g.direction == dir) then return true end
  end
  return false
end

local function cost_counts(inv, list)
  local t = {}
  for _, c in ipairs(list) do t[c[1]] = inv.get_item_count(c[1]) end
  return t
end

local function same(a, b)
  for k, v in pairs(a) do if b[k] ~= v then return false end end
  return true
end

--- Contenu d'un inventaire, texte trié.
local function inv_text(inv)
  local c = inv.get_contents()
  local t = {}
  for k, v in pairs(c) do t[#t + 1] = k .. "=" .. v end
  table.sort(t)
  return table.concat(t, " ")
end

--- Objets portés par une entité (convoyeur : ses deux lignes ; bras : sa main ; inventaires).
local function carried(e, into)
  if e.type == "transport-belt" then
    for i = 1, 2 do
      for k, v in pairs(e.get_transport_line(i).get_contents()) do into[k] = (into[k] or 0) + v end
    end
  elseif e.type == "inserter" then
    local h = e.held_stack
    if h and h.valid_for_read then into[h.name] = (into[h.name] or 0) + h.count end
  end
  for i = 1, 10 do
    local inv = e.get_inventory(i)
    if inv then for k, v in pairs(inv.get_contents()) do into[k] = (into[k] or 0) + v end end
  end
end

--- Le banc joue les robots : mine chaque entité marquée de la zone dans l'inventaire « robot ». Renvoie le relevé
--- attendu (objets des entités + objets portés) et le nombre d'entités minées.
local function robots_mine(st, key)
  local want, n = {}, 0
  for _, e in ipairs(marked(key)) do
    if e.valid then
      for _, it in ipairs(e.prototype.items_to_place_this or {}) do
        want[it.name] = (want[it.name] or 0) + (it.count or 1)
        break
      end
      carried(e, want)
      local ok = e.mine({ inventory = st.robot, raise_destroyed = true })
      if ok then n = n + 1 end
    end
  end
  return want, n
end

--- Le banc construit les fantômes de la zone (revive) en retirant de l'inventaire « robot » l'objet de chacun.
--- Renvoie construits, manquants, places refusées (can_place_entity du moteur, juste avant).
local function robots_build(st, key)
  local s = game.surfaces[1]
  local built, missing, refused = 0, 0, {}
  for _, g in ipairs(ghosts(key)) do
    if g.valid then
      local item = g.ghost_prototype.items_to_place_this[1]
      local ok_place = s.can_place_entity({ name = g.ghost_name, position = g.position, direction = g.direction, force = g.force,
        build_check_type = defines.build_check_type.ghost_revive })
      if not ok_place then refused[#refused + 1] = g.ghost_name .. "@" .. fmt(g.position) end
      if item and st.robot.remove({ name = item.name, count = item.count or 1 }) >= (item.count or 1) then
        local _, ent = g.revive({ raise_revive = true })
        if ent then built = built + 1 else missing = missing + 1 end
      else
        missing = missing + 1
      end
    end
  end
  return built, missing, refused
end

--- Murs de la zone reliés (4-voisinage) de l'extrémité ouest à l'extrémité est de la ligne ?
local function wall_closed(key, y0, x_west, x_east)
  local s = game.surfaces[1]
  local tiles = {}
  for _, w in ipairs(in_zone(key, { type = "wall" })) do tiles[math.floor(w.position.x) .. "," .. math.floor(w.position.y)] = true end
  local start = math.floor(x_west) .. "," .. math.floor(y0)
  local goal = math.floor(x_east) .. "," .. math.floor(y0)
  if not tiles[start] then return false end
  local seen, queue = { [start] = true }, { start }
  while #queue > 0 do
    local k = table.remove(queue, 1)
    if k == goal then return true end
    local x, y = k:match("^(-?%d+),(-?%d+)$")
    x, y = tonumber(x), tonumber(y)
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local nk = (x + d[1]) .. "," .. (y + d[2])
      if tiles[nk] and not seen[nk] then seen[nk] = true; queue[#queue + 1] = nk end
    end
  end
  return false
end

local function find_one(name, x, y, force)
  local list = game.surfaces[1].find_entities_filtered({ name = name, position = { x, y }, force = force })
  for _, e in ipairs(list) do
    if near(e.position.x, x) and near(e.position.y, y) then return e end
  end
  return nil
end

local function stock(inv, family, n)
  for _, c in ipairs(LV.cost(family, n)) do inv.insert({ name = c[1], count = c[2] }) end
end

---------------------------------------------------------------------------------------------------
-- Scénario
---------------------------------------------------------------------------------------------------
return {
  description = "V3-T3 : liberer la place (marques, fantomes decales, agrandissement en attente, annulation)",
  base = nil,
  check_tick = CHECK,
  shots_delay = 100, -- après le clic (tick 60) : contour, marques, fantômes ; avant les robots (tick 400)

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(ZX0 - 8, ZY0 - 8, ZX1 + 8, ZY1 + 8, "grass-1")
    local foes = 0
    for _, en in ipairs(s.find_entities_filtered({ area = { { ZX0 - 64, ZY0 - 64 }, { ZX1 + 64, ZY1 + 64 } }, force = "enemy" })) do
      if en.valid then en.destroy(); foes = foes + 1 end
    end
    ctx.log("ennemis retires autour de la zone : " .. foes)
    local f = make_force(FORCE)
    local fp = make_force(FORCE_P)
    for _, force in ipairs({ f, fp }) do force.recipes["iron-gear-wheel"].enabled = true end
    ctx.power(ZX0 + 56, ZY0 + 50, f)
    ctx.power(ZX0 + 56, ZY0 + 50, fp)
    st.cc = put(s, f, LV.name(CC, 15), ZX0 + 100, ZY0 + 70)
    st.ccp = put(s, fp, LV.name(CC, 15), ZX0 + 100, ZY0 + 85)
    st.A = build_dense(s, f, "A")
    st.C1 = build_dense(s, f, "C1")
    st.C2 = build_dense(s, f, "C2")
    st.B1 = build_turret_arm(s, f, "B1", true)
    st.B2 = build_turret_wall(s, f, "B2")
    st.D = build_turret_arm(s, f, "D", true)
    st.E = build_turret_arm(s, fp, "E", false)
    -- C1 : un fantôme et une marque de démontage DU JOUEUR (pas du mod), dans la scène relevée par le mod.
    local o = AREA.C1
    st.c1_lamp_ghost = s.create_entity({ name = "entity-ghost", inner_name = "small-lamp", position = { o[1] + 21.5, o[2] + 16.5 }, force = f })
    st.c1_chest = put(s, f, "wooden-chest", o[1] + 22.5, o[2] + 16.5)
    if st.c1_chest then st.c1_chest.order_deconstruction(f) end
    local ok = st.A.m and st.C1.m and st.C2.m and st.B1.g and st.B2.g and st.D.g and st.E.g and st.cc and st.ccp
    ctx.check(ok and true or false, "dispositions posees (usine dense x3, tourelles collees au mur x4, centres 15)")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == ACT then
      st.robot = game.create_inventory(400)
      local inv = st.cc.get_inventory(defines.inventory.chest)
      -- Coûts : A (assembleur 7), B1 et B2 (mitrailleuse 7), D (refus seulement).
      stock(inv, AS, 7); stock(inv, G, 7); stock(inv, G, 7); stock(inv, G, 7)
      for _, c in ipairs(LV.cost(AS, 7)) do inv.insert({ name = c[1], count = c[2] }) end -- C1, C2 (jamais payés)
      for _, c in ipairs(LV.cost(AS, 7)) do inv.insert({ name = c[1], count = c[2] }) end
      local all = {}
      for _, l in ipairs({ LV.cost(AS, 7), LV.cost(G, 7) }) do for _, c in ipairs(l) do all[#all + 1] = c end end
      st.cost_list = all
      st.cc0 = cost_counts(inv, all)
      -- Unités de toutes les entités des zones avant le clic (aucune ne doit disparaître du fait du mod).
      st.units0 = {}
      for _, key in ipairs(AREA_KEYS) do
        for _, en in ipairs(in_zone(key)) do if en.valid and en.unit_number and en.type ~= "entity-ghost" then st.units0[#st.units0 + 1] = en.unit_number end end
      end
      table.sort(st.units0)

      -- D : sans clic, comportement d'avant (refus « no-room », contour, rien payé).
      local rD = ctx.call("levels_upgrade", st.D.g)
      ctx.check(not rD.ok and rD.reason == "no-room" and st.D.g.valid and #marked("D") == 0 and #ghosts("D") == 0,
        "D (sans clic) : refus « no-room », rien de marque, aucun fantome (regle Q24 inchangee)",
        tostring(rD.reason) .. " ; gene : " .. table.concat(rD.blockers or {}, ","))
      -- A : le refus d'abord (comme avant), puis le clic.
      local rA0 = ctx.call("levels_upgrade", st.A.m)
      ctx.check(not rA0.ok and rA0.reason == "no-room" and same(st.cc0, cost_counts(inv, all)),
        "A : amelioration refusee faute de place (no-room), cout NON paye", tostring(rA0.reason) .. " ; contour rang " .. tostring(rA0.contour_candidate))
      local rA = ctx.call("levels_free_room", st.A.m)
      st.rA = rA
      local o = AREA.A
      local ox, oy = o[1], o[2]
      local gA = ghosts("A")
      local mA = marked("A")
      ctx.log("A : marques " .. list_text(mA) .. " ; fantomes " .. list_text(gA, true))
      ctx.check(rA.ok and rA.reason == "pending" and rA.box.x0 == ox + 15 and rA.box.y0 == oy + 9 and rA.box.x1 == ox + 19 and rA.box.y1 == oy + 13
        and #rA.signalled == 0,
        "A : liberer la place accepte, candidate du contour (sud-est), rien a retirer a la main",
        tostring(rA.reason) .. " ; carre " .. (rA.box and (rA.box.x0 .. "," .. rA.box.y0 .. "-" .. rA.box.x1 .. "," .. rA.box.y1) or "?"))
      ctx.check(#mA == 4 and st.A.m_out.to_be_deconstructed() and st.A.pole.to_be_deconstructed()
        and find_one("transport-belt", ox + 15.5, oy + 13.5, FORCE).to_be_deconstructed()
        and find_one("transport-belt", ox + 16.5, oy + 13.5, FORCE).to_be_deconstructed(),
        "A : gêneurs MARQUES a demonter (to_be_deconstructed) : bras sud, poteau, 2 tuiles du convoyeur sud (sous le bras, amont)", list_text(mA))
      ctx.check(#gA == 6 and has_ghost(gA, "inserter", ox + 16.5, oy + 13.5, N) and has_ghost(gA, "transport-belt", ox + 15.5, oy + 13.5, S)
        and has_ghost(gA, "transport-belt", ox + 15.5, oy + 14.5, E) and has_ghost(gA, "transport-belt", ox + 16.5, oy + 14.5, E)
        and has_ghost(gA, "transport-belt", ox + 17.5, oy + 14.5, N) and has_ghost(gA, "medium-electric-pole", ox + 19.5, oy + 10.5),
        "A : fantomes aux bonnes positions (bras une tuile au sud meme orientation, bosse du convoyeur, poteau une tuile a l'est)", list_text(gA, true))
      ctx.check(st.A.m.valid and same(st.cc0, cost_counts(inv, all)), "A : rien n'est paye au clic, le batiment reste en place")

      -- B1 : mitrailleuse collée au mur, nourrie par un bras.
      local rB1 = ctx.call("levels_free_room", st.B1.g)
      local ob = AREA.B1
      local gB1 = ghosts("B1")
      ctx.log("B1 : marques " .. list_text(marked("B1")) .. " ; fantomes " .. list_text(gB1, true))
      ctx.check(rB1.ok and #rB1.signalled == 0 and #marked("B1") == 3 and st.B1.arm.to_be_deconstructed() and #gB1 == 5
        and has_ghost(gB1, "inserter", ob[1] + 20.5, ob[2] + 12.5, S) and has_ghost(gB1, "transport-belt", ob[1] + 19.5, ob[2] + 12.5, S)
        and has_ghost(gB1, "transport-belt", ob[1] + 21.5, ob[2] + 13.5, N),
        "B1 (tourelle collee au mur, Q-T3) : bras marque et repose une tuile au sud, convoyeur de munitions en bosse ; mur intact",
        tostring(rB1.reason) .. " ; " .. list_text(gB1, true))
      -- B2 : mur épais, eau au sud.
      local rB2 = ctx.call("levels_free_room", st.B2.g)
      local o2 = AREA.B2
      local gB2 = ghosts("B2")
      ctx.log("B2 : marques " .. list_text(marked("B2")) .. " ; fantomes " .. list_text(gB2, true) .. " ; avertissements " .. table.concat(rB2.warnings or {}, " | "))
      ctx.check(rB2.ok and #rB2.signalled == 0 and rB2.box.y0 == o2[2] + 8 and rB2.box.x0 == o2[1] + 19 and #marked("B2") == 6 and #gB2 == 8
        and has_ghost(gB2, LV.name(WALL, 7), o2[1] + 20.5, o2[2] + 6.5) and has_ghost(gB2, LV.name(WALL, 1), o2[1] + 18.5, o2[2] + 6.5)
        and has_ghost(gB2, LV.name(WALL, 1), o2[1] + 22.5, o2[2] + 6.5) and #(rB2.warnings or {}) == 0,
        "B2 (mur epais, eau au sud) : candidate nord-est (evite l'eau), 6 murs decales (epaisseur gardee), 2 murs de liaison au mur de base",
        list_text(gB2, true))

      -- C1 : liberer puis annuler tout de suite.
      local rC1 = ctx.call("levels_free_room", st.C1.m)
      local nm, ng = #marked("C1"), #ghosts("C1")
      local cancel1 = ctx.call("levels_free_cancel", st.C1.m)
      local gC1 = ghosts("C1")
      local mC1 = marked("C1")
      ctx.check(rC1.ok and nm == 5 and ng == 7 and cancel1 and cancel1.unmarked == 4 and cancel1.removed == 6 and cancel1.kept == 0
        and not st.C1.m_out.to_be_deconstructed() and not st.C1.pole.to_be_deconstructed()
        and #mC1 == 1 and mC1[1] == st.c1_chest and #gC1 == 1 and gC1[1] == st.c1_lamp_ghost,
        "C1 : Annuler retire les 4 marques et les 6 fantomes du mod ; la marque et le fantome du joueur restent",
        string.format("avant : %d marques, %d fantomes ; annule : %s, %s retires, %s gardes ; apres : %s ; %s", nm, ng,
          tostring(cancel1 and cancel1.unmarked), tostring(cancel1 and cancel1.removed), tostring(cancel1 and cancel1.kept), list_text(mC1), list_text(gC1, true)))

      -- C2 : liberer, le bras sud démonté (groupe commencé), puis annuler.
      local rC2 = ctx.call("levels_free_room", st.C2.m)
      st.C2.m_out.mine({ inventory = st.robot, raise_destroyed = true })
      local cancel2 = ctx.call("levels_free_cancel", st.C2.m)
      local gC2 = ghosts("C2")
      local mC2 = marked("C2")
      ctx.check(rC2.ok and cancel2 and cancel2.unmarked == 1 and cancel2.removed == 1 and cancel2.kept == 5 and #gC2 == 5 and #mC2 == 2
        and not st.C2.pole.to_be_deconstructed(),
        "C2 : groupe commence (bras demonte) GARDE entier (5 fantomes, 2 marques), groupe du poteau rendu (marque annulee, fantome retire)",
        string.format("annule : %s, retires %s, gardes %s ; apres : %s ; %s", tostring(cancel2 and cancel2.unmarked), tostring(cancel2 and cancel2.removed),
          tostring(cancel2 and cancel2.kept), list_text(mC2), list_text(gC2, true)))
      -- Le robot du banc rend l'objet du bras de C2 (hors bilan des zones A, B1, B2, E).
      st.robot.remove({ name = "inserter", count = 1 })
      st.robot.clear()

      -- E : force au centre VIDE (paiement impossible au moment de l'agrandissement).
      local rE = ctx.call("levels_free_room", st.E.g)
      ctx.check(rE.ok and rE.reason == "pending" and #marked("E") == 3,
        "E (centre vide) : liberer la place accepte meme si le cout manque (il n'est paye qu'a l'agrandissement)", tostring(rE.reason))
      -- Observation moteur (F103 provisoire, rien de contrôlé) : un fantôme posé par script SUR une entité marquée
      -- (convoyeur tourné) ; la marque annulée : le fantôme reste-t-il ? Puis même pose, l'entité minée : reste-t-il ?
      do
        local f = game.forces[FORCE]
        local bx, by = ZX0 + 84.5, ZY0 + 75.5
        local b1 = put(s, f, "transport-belt", bx, by, E)
        b1.order_deconstruction(f)
        local g1 = s.create_entity({ name = "entity-ghost", inner_name = "transport-belt", position = { bx, by }, direction = S, force = f, expires = false })
        b1.cancel_deconstruction(f)
        local b2 = put(s, f, "transport-belt", bx + 2, by, E)
        b2.order_deconstruction(f)
        local g2 = s.create_entity({ name = "entity-ghost", inner_name = "transport-belt", position = { bx + 2, by }, direction = S, force = f, expires = false })
        local inv = game.create_inventory(4)
        b2.mine({ inventory = inv })
        ctx.log("OBSERVATION F103 : fantome sur un convoyeur marque, marque annulee -> fantome " .. tostring(g1 and g1.valid)
          .. " ; convoyeur mine -> fantome " .. tostring(g2 and g2.valid))
        if g2 and g2.valid then g2.destroy() end
        if g1 and g1.valid then g1.destroy() end
        if b1.valid then b1.destroy() end
        inv.destroy()
      end
      local status = ctx.call("levels_free_status")
      ctx.check(#status.requests == 4, "4 demandes en attente (A, B1, B2, E), dans l'ordre de creation",
        string.format("%d demandes, stats : demandes %d, marques %d, fantomes %d, annulees %d", #status.requests, status.stats.requests or -1,
          status.stats.marked or -1, status.stats.ghosts or -1, status.stats.cancelled or -1))
      -- Aucune entité détruite par le mod (seul le bras de C2, miné par le banc, manque).
      local now = {}
      for _, key in ipairs(AREA_KEYS) do
        for _, en in ipairs(in_zone(key)) do if en.valid and en.unit_number and en.type ~= "entity-ghost" then now[en.unit_number] = true end end
      end
      local gone = 0
      for _, u in ipairs(st.units0) do if not now[u] then gone = gone + 1 end end
      ctx.check(gone == 1, "aucune entite detruite par le mod au clic ni a l'annulation (seul le bras de C2, mine par le banc, manque)", gone .. " disparue(s)")
    elseif e.tick == ACT + 120 then
      -- La demande attend : rien ne bouge tant que la place est prise.
      ctx.check(st.A.m.valid and st.B1.g.valid and #ctx.call("levels_free_status").requests == 4,
        "attente : tant que la place est prise, aucun agrandissement (verifications periodiques sans effet)")
    elseif e.tick == MINE then
      st.want, st.mined = {}, 0
      for _, key in ipairs({ "A", "B1", "B2", "E" }) do
        local want, n = robots_mine(st, key)
        for k, v in pairs(want) do st.want[k] = (st.want[k] or 0) + v end
        st.mined = st.mined + n
      end
      local inv_now = st.robot.get_contents()
      local ok = true
      for k, v in pairs(st.want) do if inv_now[k] ~= v then ok = false end end
      for k, v in pairs(inv_now) do if st.want[k] ~= v then ok = false end end
      ctx.check(ok and st.mined == 16, "robots du banc : 16 gêneurs marques mines, tout dans l'inventaire (objets des entites et objets portes)",
        st.mined .. " mine(s) ; " .. inv_text(st.robot))
      st.cc1 = cost_counts(st.cc.get_inventory(defines.inventory.chest), st.cost_list)
    elseif e.tick == GROW then
      local o = AREA.A
      local mA = find_one(LV.name(AS, 7), o[1] + 17, o[2] + 11, FORCE)
      local ob, o2, oe = AREA.B1, AREA.B2, AREA.E
      local gB1 = find_one(LV.name(G, 7), ob[1] + 20.5, ob[2] + 10.5, FORCE)
      local gB2 = find_one(LV.name(G, 7), o2[1] + 20.5, o2[2] + 9.5, FORCE)
      st.A7, st.B17, st.B27 = mA, gB1, gB2
      local inv = st.cc.get_inventory(defines.inventory.chest)
      local after = cost_counts(inv, st.cost_list)
      local paid = true
      local want = {}
      for _, c in ipairs(LV.cost(AS, 7)) do want[c[1]] = (want[c[1]] or 0) + c[2] end
      for _, c in ipairs(LV.cost(G, 7)) do want[c[1]] = (want[c[1]] or 0) + 2 * c[2] end
      for k, v in pairs(want) do if st.cc1[k] - after[k] ~= v then paid = false end end
      local status = ctx.call("levels_free_status")
      ctx.check(mA and gB1 and gB2 and not st.A.m.valid and not st.B1.g.valid and not st.B2.g.valid and paid,
        "place liberee : A, B1 et B2 agrandis D'EUX-MEMES (assembleur 4x4, mitrailleuses 3x3, a la position du contour), cout paye a ce moment-la",
        string.format("A7 %s, B1-7 %s, B2-7 %s ; paye %s ; demandes restantes %d", fmt(mA and mA.position), fmt(gB1 and gB1.position), fmt(gB2 and gB2.position),
          tostring(paid), #status.requests))
      local stE = status.requests[1]
      ctx.check(#status.requests == 1 and stE and stE.warned ~= nil and st.E.g.valid,
        "E : place libre mais cout manquant : pas d'agrandissement, message, la demande attend", stE and ("prevenu au tick " .. tostring(stE.warned)) or "aucune demande")
    elseif e.tick == BUILD then
      -- Robots du banc : objets en plus que les fantômes demandent (2 convoyeurs par bosse, 2 murs de liaison).
      st.robot.insert({ name = "transport-belt", count = 6 })
      st.robot.insert({ name = LV.name(WALL, 1), count = 2 })
      local tot, miss, refused = 0, 0, {}
      for _, key in ipairs({ "A", "B1", "B2", "E" }) do
        local b, m, r = robots_build(st, key)
        tot, miss = tot + b, miss + m
        for _, x in ipairs(r) do refused[#refused + 1] = x end
      end
      local left = st.robot.get_contents()
      local placeable = 0
      for k, v in pairs(left) do
        local ip = game.item_prototypes[k]
        if ip and ip.place_result then placeable = placeable + v end
      end
      ctx.check(tot == 24 and miss == 0 and #refused == 0 and placeable == 0,
        "fantomes construits (revive) : 24 (A 6, B1 5, B2 8, E 5), chacun a une place libre au moment de construire (can_place_entity du moteur), chaque objet du robot employe (rien de perdu, rien en trop)",
        string.format("%d construits, %d manquants, places refusees : %s ; reste au robot : %s", tot, miss, #refused > 0 and table.concat(refused, " ") or "aucune", inv_text(st.robot)))
      local A7 = st.A7
      st.A7_done0 = A7 and A7.valid and A7.products_finished or 0
      st.A_out0 = st.A.out_chest.get_item_count("iron-gear-wheel")
      -- Munitions de la mitrailleuse agrandie mises de côté (elle était pleine) : celles qu'on y trouvera ensuite viennent
      -- du bras reposé.
      st.trash = game.create_inventory(20)
      st.B1_ammo0 = 0
      if st.B17 and st.B17.valid then
        local n = st.B17.get_item_count("firearm-magazine")
        if n > 0 then st.trash.insert({ name = "firearm-magazine", count = st.B17.remove_item({ name = "firearm-magazine", count = n }) }) end
        st.B1_ammo0 = st.B17.get_item_count("firearm-magazine")
      end
    elseif e.tick == PAY_E then
      -- E : le coût arrive au centre ; la demande se fait à la vérification suivante.
      stock(st.ccp.get_inventory(defines.inventory.chest), G, 7)
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local o = AREA.A
    local ox, oy = o[1], o[2]
    local A7 = st.A7
    local arm_out = find_one("inserter", ox + 16.5, oy + 13.5, FORCE)
    local arm_in = st.A.m_in
    local made = A7 and A7.valid and (A7.products_finished - (st.A7_done0 or 0)) or -1
    local kept_out = A7 and A7.valid and A7.get_inventory(defines.inventory.assembling_machine_output).get_item_count("iron-gear-wheel") or -1
    local out = st.A.out_chest.get_item_count("iron-gear-wheel") - (st.A_out0 or 0)
    ctx.check(A7 and A7.valid and arm_out and arm_out.pickup_target == A7 and arm_out.drop_target and arm_out.drop_target.type == "transport-belt"
      and arm_in.valid and arm_in.drop_target == A7 and made >= 3 and out >= 3 and kept_out < made,
      "A : l'usine REMARCHE (bras d'entree nourrit l'assembleur 4x4, bras sud repose prend dans la machine et depose sur la bosse, engrenages au coffre de sortie)",
      string.format("fabrications depuis la reconstruction %d (restees dans la machine %d), engrenages au coffre +%d ; bras sud %s -> %s / %s", made, kept_out, out,
        arm_out and fmt(arm_out.position) or "absent", arm_out and arm_out.pickup_target and arm_out.pickup_target.name or "rien",
        arm_out and arm_out.drop_target and arm_out.drop_target.name or "rien"))
    local pole = find_one("medium-electric-pole", ox + 19.5, oy + 10.5, FORCE)
    local linked = false
    for _, n in ipairs(pole and pole.neighbours.copper or {}) do if n == st.A.pole2 then linked = true end end
    ctx.check(pole and linked, "A : poteau reconstruit une tuile a l'est, relie a son voisin (fil de cuivre refait par le moteur)")
    local wn = st.A.w
    ctx.check(wn.valid and wn.products_finished > 0, "A : le voisin collé (signale, jamais marque) fabrique toujours", wn.valid and tostring(wn.products_finished) or "absent")
    -- B1 : le bras reposé nourrit la mitrailleuse agrandie.
    local ob = AREA.B1
    local armB = find_one("inserter", ob[1] + 20.5, ob[2] + 12.5, FORCE)
    local ammo = st.B17 and st.B17.valid and st.B17.get_item_count("firearm-magazine") or -1
    ctx.check(armB and st.B17 and st.B17.valid and armB.drop_target == st.B17 and armB.pickup_target and armB.pickup_target.type == "transport-belt"
      and ammo > (st.B1_ammo0 or 0),
      "B1 : le bras repose prend sur la bosse et nourrit la mitrailleuse 3x3 (munitions en hausse)",
      string.format("munitions %d -> %d ; bras %s", st.B1_ammo0 or -1, ammo, armB and fmt(armB.position) or "absent"))
    local o2 = AREA.B2
    ctx.check(st.B27 and st.B27.valid and wall_closed("B2", o2[2] + 8.5, o2[1] + 15.5, o2[1] + 25.5) and wall_closed("B2", o2[2] + 7.5, o2[1] + 15.5, o2[1] + 25.5),
      "B2 : mur referme (les deux rangees relient toujours leurs extremites, par la bosse et les liaisons)")
    local oe = AREA.E
    local gE = find_one(LV.name(G, 7), oe[1] + 19.5, oe[2] + 10.5, FORCE_P)
    local status = ctx.call("levels_free_status")
    ctx.check(gE and not st.E.g.valid and #status.requests == 0,
      "E : le cout arrive, l'agrandissement en attente se fait a la verification suivante", gE and fmt(gE.position) or "absent")
    -- D : toujours rien.
    ctx.check(st.D.g.valid and #marked("D") == 0 and #ghosts("D") == 0, "D (sans clic) : rien n'a change en 1400 ticks")
    local lv = ctx.call("levels_status", FORCE)
    ctx.check(lv.spilled == 0 and lv.resize_failed == 0 and lv.forced == 0 and lv.fallback == 0 and lv.ground_left == 0,
      "aucun objet renverse, aucun echec de remplacement, aucun placement force (compteurs du mod)",
      string.format("agrandissements %d, refus %d", lv.resized, lv.room_refused))
    ctx.log(string.format("stats liberer la place : %s", (function()
      local t = {}
      for k, v in pairs(status.stats) do t[#t + 1] = k .. "=" .. v end
      table.sort(t)
      return table.concat(t, " ")
    end)()))
  end,

  shots = function(ctx, add)
    local o, ob, o2 = AREA.A, AREA.B1, AREA.B2
    add("usine-dense-liberee", o[1] + 17, o[2] + 11, 1.6, 0)
    add("tourelle-bras-liberee", ob[1] + 20, ob[2] + 11, 1.6, 0)
    add("tourelle-mur-epais-liberee", o2[1] + 20, o2[2] + 9, 1.6, 0)
  end,
}
