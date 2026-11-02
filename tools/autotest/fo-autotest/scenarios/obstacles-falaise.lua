--[[
  Scénario GREFFÉ « obstacles-falaise » (lot OBSTACLES, 2/11) : relève, au moteur réel, l'EMPRISE DE COLLISION de chacune des 20
  orientations de falaise, tuile par tuile (can_place_entity d'un tapis), pour la comparer au modèle pur
  shared/team/falaise.lua. Le modèle doit couvrir TOUTES les tuiles que le moteur refuse (un manque = un projet bloqué) ; ses
  tuiles en trop (le moteur les accepte) sont comptées, sans être une faute (union prudente des rectangles tournés).

  Lancement : banc.py --qui OBSTACLES -- 120 obstacles-falaise <source>   (ou fo-autotest.bat nopause 120 obstacles-falaise "<source>")
  Lecture   : lua5.2 tools/autotest/obstacles_falaise.lua "<archive>\benchmark.log"
              → « [OBSTACLES-FALAISE] BILAN : … » ; code 0 si aucun manque.

  Journal du scénario (une ligne par falaise) :
    FALAISE o=<orientation> cx=<x> cy=<y> bb=<x0>,<y0>,<x1>,<y1> bloque=<tx>:<ty>,<tx>:<ty>,…
  où bloque = tuiles (indices ABSOLUS du moteur, fenêtre de 14 × 14 tuiles autour du centre) où can_place_entity d'un
  transport-belt est faux, et bb = LuaEntity::bounding_box (la boîte générique, pour mémoire).
]]
local X0, Y0, PAS = 2400, 3600, 14
local ORIENTATIONS = {
  "west-to-east", "north-to-south", "east-to-west", "south-to-north",
  "west-to-north", "north-to-east", "east-to-south", "south-to-west",
  "west-to-south", "north-to-west", "east-to-north", "south-to-east",
  "west-to-none", "none-to-east", "north-to-none", "none-to-south",
  "east-to-none", "none-to-west", "south-to-none", "none-to-north",
}
local COLS = 5
local R = 7 -- fenêtre : de -7 à +6 tuiles autour de la tuile du centre

local function centre(i)
  local col, lig = (i - 1) % COLS, math.floor((i - 1) / COLS)
  return X0 + col * PAS, Y0 + lig * PAS + 0.5 -- les falaises se posent à (entier ; demi-entier), comme celles du terrain
end

return {
  description = "obstacles-falaise : emprise de collision des 20 orientations de falaise, tuile par tuile (modele pur a comparer)",
  check_tick = 60,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    ctx.prepare_area(X0 - 20, Y0 - 20, X0 + COLS * PAS + 10, Y0 + 4 * PAS + 10, "grass-1")
    for _, e in ipairs(s.find_entities_filtered({ area = { { X0 - 150, Y0 - 150 }, { X0 + 250, Y0 + 250 } }, force = "enemy" })) do
      e.destroy()
    end
    st.falaises = {}
    local poses = 0
    for i, o in ipairs(ORIENTATIONS) do
      local cx, cy = centre(i)
      local c = s.create_entity({ name = "cliff", position = { cx, cy }, cliff_orientation = o, force = "neutral" })
      st.falaises[i] = { o = o, cx = cx, cy = cy, e = c }
      if c then poses = poses + 1 end
    end
    ctx.check(poses == #ORIENTATIONS, "20 falaises posees (une par orientation)", poses)
  end,

  finish = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local lues, relues = 0, 0
    for _, fa in ipairs(st.falaises or {}) do
      local c = fa.e
      if c and c.valid then
        lues = lues + 1
        if c.cliff_orientation == fa.o then relues = relues + 1 end
        local bb = c.bounding_box
        local fx, fy = math.floor(c.position.x), math.floor(c.position.y)
        local bl = {}
        for ty = fy - R, fy + R - 1 do
          for tx = fx - R, fx + R - 1 do
            if not s.can_place_entity({ name = "transport-belt", position = { tx + 0.5, ty + 0.5 }, direction = defines.direction.east, force = "player" }) then
              bl[#bl + 1] = tx .. ":" .. ty
            end
          end
        end
        ctx.log(string.format("FALAISE o=%s cx=%g cy=%g bb=%g,%g,%g,%g bloque=%s", c.cliff_orientation, c.position.x, c.position.y,
          bb.left_top.x, bb.left_top.y, bb.right_bottom.x, bb.right_bottom.y, table.concat(bl, ",")))
        ctx.check(#bl >= 2, "falaise " .. fa.o .. " : le moteur refuse au moins 2 tuiles au tapis", #bl)
      end
    end
    ctx.check(lues == #ORIENTATIONS, "20 falaises relues au controle", lues)
    ctx.check(relues == #ORIENTATIONS, "l'orientation relue est celle demandee (cliff_orientation)", relues)
  end,
}
