--[[
  Tests hors jeu de l'espace et de l'enceinte des équipes de PNJ (lot ESPACE, shared/team/enceinte.lua, pur).
  Usage, depuis la racine du mod :   lua5.2 tests/enceinte_test.lua
  Vérifie : géométrie de l'anneau (au-delà du treillis, jamais dedans), ouvertures sur les rues principales, tuiles
  écartées, décompte exact (formule = anneau), croissance et enceinte (cas limites), fabrication au coffre, déterminisme.
]]
package.path = "./?.lua;" .. package.path
local E = require("shared.team.enceinte")
local P = require("shared.team.plan")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

local lat = P.lattice({ x = 100.5, y = -40.5 })

-- 1. Géométrie : aucune tuile de mur dans le treillis (lots et rues du rayon r), distance exacte au bord
for r = 1, 5 do
  local ring = E.ring(lat, r)
  local lo_x, hi_x = lat.ox - (28 * r + 16), lat.ox + 28 * r + 15
  local lo_y, hi_y = lat.oy - (28 * r + 16), lat.oy + 28 * r + 15
  local inside, minx, maxx = 0, math.huge, -math.huge
  for _, w in ipairs(ring.walls) do
    if w.tx >= lo_x and w.tx <= hi_x and w.ty >= lo_y and w.ty <= hi_y then inside = inside + 1 end
    minx, maxx = math.min(minx, w.tx), math.max(maxx, w.tx)
  end
  check(inside == 0, "r=" .. r .. " : aucun mur dans le treillis (" .. inside .. ")")
  check(minx == lo_x - E.GAP - 1 and maxx == hi_x + E.GAP + 1, "r=" .. r .. " : le mur est a GAP+1 du bord (x " .. minx .. ".." .. maxx .. ")")
  -- le treillis réel : tous les tronçons de segs_within(r) sont dans le carré [lo, hi], et touchent ses bords
  local ok, touch = true, 0
  for _, key in ipairs(P.segs_within(r)) do
    local x0, y0, x1, y1 = P.seg_rect(lat, key)
    if x0 < lo_x or y0 < lo_y or x1 - 1 > hi_x or y1 - 1 > hi_y then ok = false end
    if x0 == lo_x or y0 == lo_y or x1 - 1 == hi_x or y1 - 1 == hi_y then touch = touch + 1 end
  end
  check(ok and touch > 0, "r=" .. r .. " : le bord du treillis calcule colle a segs_within")
  -- les lots aussi
  local lots_ok = true
  for _, l in ipairs(P.lots_within(r)) do
    local x0, y0, x1, y1 = P.lot_rect(lat, l.i, l.j)
    if x0 < lo_x or y0 < lo_y or x1 - 1 > hi_x or y1 - 1 > hi_y then lots_ok = false end
  end
  check(lots_ok, "r=" .. r .. " : tous les lots sont dans le treillis")
  check(#ring.walls == E.max_walls(r), "r=" .. r .. " : formule max_walls = anneau (" .. #ring.walls .. " / " .. E.max_walls(r) .. ")")
  check(ring.gates == 4 * #E.MAIN_STREETS * E.STREET, "r=" .. r .. " : 4 cotes x 2 rues x 4 tuiles d'ouverture (" .. ring.gates .. ")")
  local seen, dup = {}, 0
  for _, w in ipairs(ring.walls) do local k = P.tkey(w.tx, w.ty); if seen[k] then dup = dup + 1 end seen[k] = true end
  check(dup == 0, "r=" .. r .. " : aucune tuile en double")
end

-- 2. Ouvertures : le prolongement exact des rues principales (le lot 0:0 borde les rues -1 et 0) est ouvert, rien d'autre
do
  local ring = E.ring(lat, 3)
  local x0, y0, x1, y1 = table.unpack(ring.bounds)
  local set = {}
  for _, w in ipairs(ring.walls) do set[P.tkey(w.tx, w.ty)] = true end
  local function gate_x(tx)
    for _, m in ipairs({ -1, 0 }) do
      local a = lat.ox + 28 * m + 12
      if tx >= a and tx < a + 4 then return true end
    end
    return false
  end
  local bad = 0
  for tx = x0, x1 do
    if gate_x(tx) == (set[P.tkey(tx, y0)] == true) then bad = bad + 1 end -- ouvert <=> pas de mur
  end
  check(bad == 0, "cote nord : mur partout sauf sur les 2 rues principales (" .. bad .. " ecarts)")
  -- les rues principales du lot du QG : tronçons v:0:j (colonne 0) et v:-1:j (colonne -1)
  local ax0, _, ax1 = P.seg_rect(lat, P.seg_key("v", 0, 0))
  local bx0, _, bx1 = P.seg_rect(lat, P.seg_key("v", -1, 0))
  check(gate_x(ax0) and gate_x(ax1 - 1) and not gate_x(ax0 - 1) and not gate_x(ax1), "l'ouverture a la largeur exacte de la rue v:0:j")
  check(gate_x(bx0) and gate_x(bx1 - 1) and not gate_x(bx0 - 1) and not gate_x(bx1), "l'ouverture a la largeur exacte de la rue v:-1:j")
  -- idem pour les rangées (côtés ouest et est)
  local gy_ok = true
  for ty = y0 + 1, y1 - 1 do
    local g = false
    for _, m in ipairs({ -1, 0 }) do local a = lat.oy + 28 * m + 12; if ty >= a and ty < a + 4 then g = true end end
    if g == (set[P.tkey(x0, ty)] == true) or g == (set[P.tkey(x1, ty)] == true) then gy_ok = false end
  end
  check(gy_ok, "cotes ouest et est : memes ouvertures sur les rangees -1 et 0")
  check(set[P.tkey(x0, y0)] and set[P.tkey(x1, y0)] and set[P.tkey(x0, y1)] and set[P.tkey(x1, y1)], "les 4 coins sont murs")
end

-- 3. Tuiles écartées (eau, ressource) : jamais murées, comptées par raison
do
  local full = E.ring(lat, 2)
  local x0, y0 = table.unpack(full.bounds)
  local water = {}
  for tx = x0 + 10, x0 + 19 do water[P.tkey(tx, y0)] = true end
  local ore = P.tkey(x0, y0 + 30)
  local ring = E.ring(lat, 2, { skip = function(tx, ty)
    local k = P.tkey(tx, ty)
    if water[k] then return "eau" end
    if k == ore then return "ressource" end
    return nil
  end })
  check(ring.skipped["eau"] == 10 and ring.skipped["ressource"] == 1, "eau et ressource ecartees et comptees")
  check(#ring.walls == #full.walls - 11, "11 murs de moins")
  local on_water = 0
  for _, w in ipairs(ring.walls) do if water[P.tkey(w.tx, w.ty)] or P.tkey(w.tx, w.ty) == ore then on_water = on_water + 1 end end
  check(on_water == 0, "aucun mur sur l'eau ni sur la ressource")
  local again = E.ring(lat, 2)
  local same = #again.walls == #full.walls
  for i, w in ipairs(again.walls) do if w.tx ~= full.walls[i].tx or w.ty ~= full.walls[i].ty then same = false end end
  check(same, "deterministe (deux appels, meme liste ordonnee)")
end

-- 4. Croissance et enceinte : cas limites
do
  local base = { radius = 3, rmax = 5, pending = 0, free = 1, busy = 1, done = 2, enc = false }
  local function with(t)
    local o = {}
    for _, k in ipairs({ "radius", "rmax", "pending", "free", "busy", "done", "enc" }) do o[k] = base[k] end
    for k, v in next, t do o[k] = v end
    return o
  end
  check(E.grow_due(base) == true, "croit : peu de place, peu de chantiers, un projet fini")
  check(E.grow_due(with({ free = E.GROW_FREE_MIN })) == false, "ne croit pas avec assez de place libre")
  check(E.grow_due(with({ free = E.GROW_FREE_MIN - 1 })) == true, "croit juste sous le seuil")
  check(E.grow_due(with({ radius = 5 })) == false, "ne croit pas au rayon maximal")
  check(E.grow_due(with({ pending = 3 })) == false, "ne croit pas pendant l'evaluation du rayon")
  check(E.grow_due(with({ busy = E.BUSY_MAX + 1 })) == false, "ne croit pas surcharge de chantiers")
  check(E.grow_due(with({ busy = E.BUSY_MAX })) == true, "croit a la limite de charge")
  check(E.grow_due(with({ done = 0 })) == false, "ne croit pas sans projet fini")
  check(E.grow_due(with({ enc = true })) == false, "ne croit plus apres l'enceinte")
  check(E.enclosure_due(with({ done = E.MIN_PROJECTS, free = 5 })) == true, "enceinte : base mure, place libre")
  check(E.enclosure_due(with({ done = E.MIN_PROJECTS - 1, free = 5 })) == false, "enceinte : base trop jeune")
  check(E.enclosure_due(with({ done = E.MIN_PROJECTS, free = 0 })) == false, "enceinte : la croissance passe d'abord")
  check(E.enclosure_due(with({ done = E.MIN_PROJECTS, free = 0, radius = 5 })) == true, "enceinte : rayon maximal, plus de croissance possible")
  check(E.enclosure_due(with({ done = E.MIN_PROJECTS, free = 5, enc = true })) == false, "enceinte : une seule")
  check(E.enclosure_due(with({ done = E.MIN_PROJECTS, free = 5, pending = 1 })) == false, "enceinte : attend l'evaluation")
  -- la croissance et l'enceinte ne sont jamais voulues ensemble, et au rayon maximal l'une des deux l'est (sauf base jeune)
  local both, neither_mature = 0, 0
  for free = 0, 6 do
    for radius = 1, 5 do
      for done = 0, 7 do
        for busy = 0, 4 do
          local i = with({ free = free, radius = radius, done = done, busy = busy })
          if E.grow_due(i) and E.enclosure_due(i) then both = both + 1 end
          if radius == 5 and done >= E.MIN_PROJECTS and not E.enclosure_due(i) then neither_mature = neither_mature + 1 end
        end
      end
    end
  end
  check(both == 0, "jamais croissance ET enceinte ensemble")
  check(neither_mature == 0, "au rayon maximal et base mure, l'enceinte est toujours voulue (pas de blocage)")
end

-- 5. Lots libres : le lot du QG, les lots pris, refusés et écartés ne comptent pas
do
  local lots = {
    ["0:0"] = { i = 0, j = 0, state = "libre" },
    ["1:0"] = { i = 1, j = 0, state = "libre" },
    ["2:0"] = { i = 2, j = 0, state = "defricher" },
    ["3:0"] = { i = 3, j = 0, state = "libre", used = 4 },
    ["4:0"] = { i = 4, j = 0, state = "refuse" },
    ["5:0"] = { i = 5, j = 0, state = "gisement" },
    ["6:0"] = { i = 6, j = 0, state = "libre", bad = 2 },
    ["7:0"] = { i = 7, j = 0, state = "libre", bad = 1 },
    ["8:0"] = { i = 8, j = 0, state = "inconnu" },
  }
  check(E.free_count(lots) == 3, "free_count : 3 lots utilisables (" .. E.free_count(lots) .. ")")
  check(E.free_count({}) == 0 and E.free_count(nil) == 0, "free_count : vide")
end

-- 6. Fabrication au coffre
do
  local stock = { brick = 12, x = 3 }
  local function count(n) return stock[n] or 0 end
  check(E.crafts_possible({ { name = "brick", amount = 5 } }, count) == 2, "12 briques : 2 fabrications de 5")
  check(E.crafts_possible({ { name = "brick", amount = 5 }, { name = "x", amount = 2 } }, count) == 1, "limite par le plus rare")
  check(E.crafts_possible({ { name = "absent", amount = 1 } }, count) == 0, "ingredient absent : 0")
  check(E.crafts_possible({}, count) == 0, "recette sans ingredient : 0 (jamais illimite)")
  check(E.crafts_to_run(7, 1, 100) == 7 and E.crafts_to_run(7, 1, 3) == 3 and E.crafts_to_run(0, 1, 5) == 0, "crafts_to_run")
  check(E.crafts_to_run(5, 2, 100) == 3, "crafts_to_run : arrondi vers le haut pour une recette qui rend 2")
  check(E.affordable(10, 4, 6) and not E.affordable(10, 4, 5), "affordable : exact")
end

print(string.format("[ENCEINTE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
