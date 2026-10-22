--[[
  Scénario GREFFÉ « t3-migration » (lot V3-T3, 22/10) : « LIBÉRER LA PLACE » pour un bâtiment laissé HORS GRILLE par
  une VRAIE migration (F76, F86), en moteur réel. Double source OBLIGATOIRE (tools/autotest/README.md §1.1) :
  FO_CREATE_SRC = <racine>\fo-logs\2026-10-22_V3T2\src-0.4.2 (git archive c4d37e5, version 0.4.2 : l'assembleur 8 y
  est un 3×3). Un bâtiment posé par script est toujours recalé sur la grille (create_entity ET teleport, moteur réel
  22/10, essai E56) : seule une migration fabrique un bâtiment hors grille.

  Création (0.4.2) : rangée dense de deux assembleurs 8 (3×3) collés, bras au nord (entrée, convoyeur de plaques
  au-delà) et au sud (sortie, convoyeur au-delà), colonne est libre ; centre 15 de la force « fo-t3m » loin de là.
  Benchmark (0.4.4, ce lot) : la migration a LAISSÉ l'assembleur M hors grille (4×4 sur la position d'un 3×3, ses
  bras gênent toutes les positions) ; son amélioration 8 → 9 (même côté, remise sur la grille) est refusée
  (« no-room ») ; « libérer la place » marque le bras sud et deux tuiles du convoyeur sud, pose les fantômes (bras une
  tuile au sud, bosse) ; le banc mine les marques ; le mod remet M sur la grille au niveau 9 de lui-même ; le banc
  construit les fantômes ; l'usine remarche.
]]

local LV = require("__factorio-overhaul__/shared/levels/config")

local AS, CC = LV.by_key.assembler, LV.by_key.command
local N, E, W = defines.direction.north, defines.direction.east, defines.direction.west
local X0, Y0 = 300, 240
local FORCE = "fo-t3m"
local ACT, MINE, BUILD, CHECK = 90, 150, 250, 900

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

local function put(s, f, name, x, y, dir)
  return s.create_entity({ name = name, position = { x, y }, direction = dir, force = f, raise_built = true })
end

local function proto_side(name)
  local b = game.entity_prototypes[name].selection_box
  return b.right_bottom.x - b.left_top.x
end

local function zone()
  return { { X0, Y0 }, { X0 + 32, Y0 + 24 } }
end

local function marked()
  local out = {}
  for _, e in ipairs(game.surfaces[1].find_entities_filtered({ area = zone() })) do
    if e.valid and e.type ~= "entity-ghost" and e.to_be_deconstructed() then out[#out + 1] = e end
  end
  return out
end

local function ghosts()
  return game.surfaces[1].find_entities_filtered({ area = zone(), type = "entity-ghost" })
end

local function list_text(list, ghost)
  local t = {}
  for _, e in ipairs(list) do t[#t + 1] = string.format("%s@%g,%g/%d", ghost and e.ghost_name or e.name, e.position.x, e.position.y, e.direction or 0) end
  table.sort(t)
  return table.concat(t, " ")
end

local function find_one(name, x, y)
  for _, e in ipairs(game.surfaces[1].find_entities_filtered({ name = name, position = { x, y }, force = FORCE })) do
    if near(e.position.x, x) and near(e.position.y, y) then return e end
  end
  return nil
end

return {
  description = "V3-T3 : liberer la place d'une machine laissee hors grille par une vraie migration depuis 0.4.2",
  base = nil,
  check_tick = CHECK,
  shots_delay = 100,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    st.version_create = script.active_mods["factorio-overhaul"]
    local a8 = proto_side(LV.name(AS, 8))
    if a8 ~= 3 then
      ctx.fail("phase de creation avec une source 0.4.2 (assembleur 8 en 3x3)", "assembleur 8 deja en " .. a8 .. "x" .. a8 .. " : lancer avec FO_CREATE_SRC")
      st.invalid = true
      return
    end
    ctx.prepare_area(X0 - 8, Y0 - 8, X0 + 60, Y0 + 40, "grass-1")
    for _, en in ipairs(s.find_entities_filtered({ area = { { X0 - 64, Y0 - 64 }, { X0 + 124, Y0 + 104 } }, force = "enemy" })) do
      if en.valid then en.destroy() end
    end
    local f = make_force(FORCE)
    f.recipes["iron-gear-wheel"].enabled = true
    ctx.power(X0 + 24, Y0 + 16, f)
    st.cc = put(s, f, LV.name(CC, 15), X0 + 46, Y0 + 12)
    local ox, oy = X0, Y0
    st.m = put(s, f, LV.name(AS, 8), ox + 16.5, oy + 10.5, N)
    st.w = put(s, f, LV.name(AS, 8), ox + 13.5, oy + 10.5, N)
    for _, m in ipairs({ st.m, st.w }) do if m then m.set_recipe("iron-gear-wheel") end end
    st.m_in = put(s, f, "inserter", ox + 16.5, oy + 8.5, N)
    st.m_out = put(s, f, "inserter", ox + 16.5, oy + 12.5, N)
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
    st.out_chest = put(s, f, "iron-chest", ox + 24.5, oy + 13.5)
    st.m_unit = st.m and st.m.unit_number
    ctx.log("creation : factorio-overhaul " .. tostring(st.version_create) .. ", assembleur 8 en 3x3 ; M en " .. fmt(st.m and st.m.position))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if st.invalid then return end
    local s = ctx.surface()
    if e.tick == ACT then
      st.robot = game.create_inventory(100)
      local m = st.m
      local ver = script.active_mods["factorio-overhaul"]
      local side = proto_side(LV.name(AS, 8))
      local aligned = m and m.valid and (math.abs(m.position.x - math.floor(m.position.x)) < 1e-6)
      ctx.check(m and m.valid and m.unit_number == st.m_unit and side == 4 and not aligned,
        "migration " .. tostring(st.version_create) .. " -> " .. tostring(ver) .. " : l'assembleur 8 (desormais 4x4) est LAISSE hors grille (ses bras genent toutes les positions)",
        string.format("M en %s, cote %d", fmt(m and m.position), side))
      local cc = s.find_entities_filtered({ name = LV.name(CC, 15), force = FORCE })[1]
      st.cc = cc
      local inv = cc and cc.get_inventory(defines.inventory.chest)
      if not inv then ctx.fail("centre 15 de " .. FORCE .. " introuvable") return end
      for _, c in ipairs(LV.cost(AS, 9)) do inv.insert({ name = c[1], count = c[2] }) end
      local before = {}
      for _, c in ipairs(LV.cost(AS, 9)) do before[c[1]] = inv.get_item_count(c[1]) end
      st.before = before
      local r0 = ctx.call("levels_upgrade", m)
      local unpaid = true
      for k, v in pairs(before) do if inv.get_item_count(k) ~= v then unpaid = false end end
      ctx.check(not r0.ok and r0.reason == "no-room" and m.valid and unpaid,
        "machine hors grille, amelioration 8 -> 9 (remise sur la grille) : refus « no-room », cout non paye (comportement d'avant, sans clic)",
        tostring(r0.reason) .. " ; contour rang " .. tostring(r0.contour_candidate) .. " ; gene : " .. table.concat(r0.blockers or {}, ","))
      local r = ctx.call("levels_free_room", m)
      local mk, gh = marked(), ghosts()
      ctx.log("marques " .. list_text(mk) .. " ; fantomes " .. list_text(gh, true))
      local ox, oy = X0, Y0
      ctx.check(r.ok and r.reason == "pending" and #r.signalled == 0 and #mk == 3 and st.m_out.to_be_deconstructed() and #gh == 5,
        "liberer la place : bras sud et 2 tuiles du convoyeur sud marques, 5 fantomes (bras une tuile au sud, bosse), rien a retirer a la main",
        string.format("%s ; carre %s ; %s", tostring(r.reason), r.box and (r.box.x0 .. "," .. r.box.y0 .. "-" .. r.box.x1 .. "," .. r.box.y1) or "?", list_text(gh, true)))
      st.box = r.box
    elseif e.tick == MINE then
      local n = 0
      for _, en in ipairs(marked()) do
        if en.mine({ inventory = st.robot, raise_destroyed = true }) then n = n + 1 end
      end
      st.mined = n
    elseif e.tick == BUILD then
      local b = st.box
      local cx, cy = b and (b.x0 + b.x1) / 2, b and (b.y0 + b.y1) / 2
      local m9 = b and find_one(LV.name(AS, 9), cx, cy)
      local inv = st.cc and st.cc.valid and st.cc.get_inventory(defines.inventory.chest)
      local paid = inv ~= nil
      for _, c in ipairs(LV.cost(AS, 9)) do if inv and st.before[c[1]] - inv.get_item_count(c[1]) ~= c[2] then paid = false end end
      st.m9 = m9
      ctx.check(st.mined == 3 and m9 and m9.valid and not st.m.valid and paid and math.abs(m9.position.x - math.floor(m9.position.x)) < 1e-6,
        "gêneurs mines : la machine est REMISE SUR LA GRILLE au niveau 9 d'elle-meme, a la position du contour, cout paye a ce moment-la",
        string.format("%d mine(s) ; niveau 9 en %s ; paye %s", st.mined or -1, fmt(m9 and m9.position), tostring(paid)))
      st.robot.insert({ name = "transport-belt", count = 2 })
      local built, refused = 0, {}
      for _, g in ipairs(ghosts()) do
        local ok = s.can_place_entity({ name = g.ghost_name, position = g.position, direction = g.direction, force = g.force,
          build_check_type = defines.build_check_type.ghost_revive })
        if not ok then refused[#refused + 1] = g.ghost_name end
        local item = g.ghost_prototype.items_to_place_this[1]
        if st.robot.remove({ name = item.name, count = 1 }) == 1 then
          local _, ent = g.revive({ raise_revive = true })
          if ent then built = built + 1 end
        end
      end
      local left = 0
      for k, v in pairs(st.robot.get_contents()) do
        local ip = game.item_prototypes[k]
        if ip and ip.place_result then left = left + v end
      end
      ctx.check(built == 5 and #refused == 0 and left == 0, "fantomes construits (5), places libres, objets du robot tous employes",
        built .. " construits ; refuses : " .. table.concat(refused, ","))
      st.done0 = m9 and m9.valid and m9.products_finished or 0
      st.out0 = st.out_chest.get_item_count("iron-gear-wheel")
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if st.invalid then return end
    local m9 = st.m9
    local b = st.box
    local arm_out = b and find_one("inserter", X0 + 16.5, Y0 + 13.5)
    local made = m9 and m9.valid and (m9.products_finished - (st.done0 or 0)) or -1
    ctx.check(m9 and m9.valid and arm_out and arm_out.pickup_target == m9 and st.m_in.valid and st.m_in.drop_target == m9 and made >= 3
      and st.out_chest.get_item_count("iron-gear-wheel") > (st.out0 or 0),
      "l'usine REMARCHE apres la remise sur la grille (bras d'entree et bras sud repose servent la machine 4x4, engrenages au coffre)",
      string.format("fabrications %d ; bras sud %s -> %s", made, arm_out and fmt(arm_out.position) or "absent", arm_out and arm_out.pickup_target and arm_out.pickup_target.name or "rien"))
    local lv = ctx.call("levels_status", FORCE)
    ctx.check(lv.spilled == 0 and lv.resize_failed == 0 and lv.forced == 0 and lv.fallback == 0, "aucun objet renverse, aucun echec, aucun placement force, 0 secours")
    ctx.log(string.format("versions : creation %s, benchmark %s", tostring(st.version_create), tostring(script.active_mods["factorio-overhaul"])))
  end,

  shots = function(ctx, add)
    add("hors-grille-liberee", X0 + 17, Y0 + 11, 1.6, 0)
  end,
}
