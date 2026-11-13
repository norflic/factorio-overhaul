--[[
  Sprint s42, chantier « gisements » (4.2 et 4.3 du DC, partie 0.7.96) : gisement secondaire imbriqué (aucune foreuse dont la zone touche
  l'autre minerai) et essai de l'autre orientation quand le bout des rangées n'a pas de sol neutre pour la fonderie (plan pur,
  shared/team/champ.lua). Gisements synthétiques, aucune API Factorio. Lancement : lua5.2 tests/s42_gisements_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(c, msg) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end end

local Ch = require("shared.team.champ")

local BELTS3 = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } }
local function rect(x0, y0, w, h, into)
  local o = into or {}
  for x = x0, x0 + w - 1 do for y = y0, y0 + h - 1 do o[#o + 1] = x; o[#o + 1] = y end end
  return o
end
local function set_of(list, into)
  local s = into or {}
  for i = 1, #list - 1, 2 do s[Ch.key(list[i], list[i + 1])] = true end
  return s
end
local function spec_of(ore, o)
  o = o or {}
  return { ore = ore, blocked = o.blocked or {}, foreign = o.foreign, resources = o.resources, axis = o.axis,
    drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = BELTS3, furnace = { size = 2, rate = 0.3125, fuel = true }, inserter = { rate = 0.83 }, target = o.target or { x = 1000, y = 0 },
    design = o.design, max_side = 8, logistics = {}, frame = o.frame }
end
local function drills(p)
  local out = {}
  for _, e in ipairs(p.ents) do
    if e.kind == "foreuse" and e.role ~= "charbon" then out[#out + 1] = { math.floor(e.x - 1 + 0.001), math.floor(e.y - 1 + 0.001) } end
  end
  table.sort(out, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
  return out
end
local function sig(p)
  local t = {}
  for _, d in ipairs(drills(p)) do t[#t + 1] = d[1] .. ":" .. d[2] end
  return table.concat(t, " ")
end

-- 1. Gisement imbriqué : cuivre 40 × 32, charbon 8 × 8 au milieu (les deux minables par la même foreuse)
do
  local coal = rect(16, 12, 8, 8)
  local coal_set = set_of(coal)
  local copper = {}
  for x = 0, 39 do for y = 0, 31 do if not coal_set[Ch.key(x, y)] then copper[#copper + 1] = x; copper[#copper + 1] = y end end end
  local sp = spec_of(copper, { foreign = coal_set, resources = set_of(copper, set_of(coal)) })
  local p = Ch.plan(sp)
  check(p ~= nil, "imbrique : un plan")
  if p then
    local ds = drills(p)
    check(#ds >= 20, "imbrique : le cuivre autour du charbon porte des foreuses (" .. #ds .. ")")
    local mixed, mined = 0, {}
    for _, d in ipairs(ds) do
      local touch = false
      for x = d[1] - 1, d[1] + 3 do for y = d[2] - 1, d[2] + 3 do
        if coal_set[Ch.key(x, y)] then touch = true end
        mined[Ch.key(x, y)] = true
      end end
      if touch then mixed = mixed + 1 end
    end
    check(mixed == 0, "imbrique : aucune foreuse dont la zone touche le charbon (" .. mixed .. ")")
    -- le cuivre à plus de 4 tuiles (côté + portée) du charbon est pavé comme sans charbon
    local far, far_mined = 0, 0
    for i = 1, #copper - 1, 2 do
      local x, y = copper[i], copper[i + 1]
      if x < 11 or x > 28 or y < 7 or y > 24 then
        far = far + 1
        if mined[Ch.key(x, y)] then far_mined = far_mined + 1 end
      end
    end
    check(far_mined >= 0.95 * far, "imbrique : cuivre loin du charbon mine (" .. far_mined .. "/" .. far .. ")")
    -- le même plan deux fois (déterminisme)
    check(sig(Ch.plan(sp)) == sig(p), "imbrique : plan deterministe")
    -- vu du charbon : aucune foreuse de charbon dont la zone touche le cuivre
    local pc = Ch.plan(spec_of(coal, { foreign = set_of(copper), resources = set_of(copper, set_of(coal)) }))
    local cop_set, m2 = set_of(copper), 0
    for _, d in ipairs(pc and drills(pc) or {}) do
      for x = d[1] - 1, d[1] + 3 do for y = d[2] - 1, d[2] + 3 do if cop_set[Ch.key(x, y)] then m2 = m2 + 1 end end end
    end
    check(m2 == 0, "imbrique : aucune foreuse de charbon sur le cuivre (" .. m2 .. ")")
  end
end

-- 2. Orientation imposée : spec.axis tourne les rangées ; un cadre figé garde la sienne
do
  local ore = rect(0, 0, 40, 20)
  local px = Ch.plan(spec_of(ore))
  local py = Ch.plan(spec_of(ore, { axis = "y" }))
  check(px and px.axis == "x", "axe : long par defaut (x)")
  check(py and py.axis == "y" and py.frame.axis == "y", "axe : impose (y), ecrit dans le cadre")
  check(Ch.axis_other("x") == "y" and Ch.axis_other("y") == "x", "axe : l'autre")
  if px and py then
    local again = Ch.plan(spec_of(ore, { frame = py.frame, axis = "x" }))
    check(again and again.axis == "y", "axe : le cadre fige l'emporte sur spec.axis")
    check(sig(again) == sig(py), "axe : cadre rejoue a l'identique")
  end
end

-- 3. Bouts des rangées sans sol neutre (un autre gisement borde l'est et l'ouest) : la colonne de fonderie n'a pas de place, des foreuses
--    ne sont pas posées ; l'autre orientation sort au nord ou au sud et en pose plus
do
  local ore = rect(0, 0, 40, 20)
  local res = set_of(ore)
  set_of(rect(-70, -12, 70, 44), res)
  set_of(rect(40, -12, 70, 44), res)
  local a = Ch.plan(spec_of(ore, { design = "colonne", resources = res, target = { x = 20, y = 200 } }))
  check(a ~= nil and a.axis == "x", "bouts : plan sur l'axe long")
  if a then
    check(Ch.axis_retry(a), "bouts : foreuses non posees -> essai de l'autre orientation (" .. tostring(a.stats.orphans) .. ")")
    local b = Ch.plan(spec_of(ore, { design = "colonne", resources = res, target = { x = 20, y = 200 }, axis = Ch.axis_other(a.axis) }))
    check(b ~= nil and b.axis == "y", "bouts : plan sur l'autre axe")
    check(Ch.better_axis(a, b), "bouts : l'autre orientation pose plus de foreuses (" .. Ch.field_drills(a) .. " -> " .. (b and Ch.field_drills(b) or -1) .. ")")
    check(not Ch.better_axis(b, a), "bouts : choix non symetrique")
  end
  -- gisement dégagé : rien à essayer
  local free = Ch.plan(spec_of(ore, { design = "colonne", resources = set_of(ore) }))
  check(free ~= nil and not Ch.axis_retry(free), "degage : pas d'essai (" .. tostring(free and free.stats.orphans) .. " non posee)")
  -- règle du choix : égalité -> axe long ; coffre de tête de plus -> axe long
  local function fake(nd, nc)
    local e = {}
    for _ = 1, nd do e[#e + 1] = { kind = "foreuse" } end
    for _ = 1, nc do e[#e + 1] = { kind = "coffre", role = "combustible" } end
    return { ents = e, stats = {} }
  end
  check(not Ch.better_axis(fake(10, 0), fake(10, 0)), "choix : egalite -> axe long")
  check(Ch.better_axis(fake(10, 1), fake(11, 1)), "choix : plus de foreuses")
  check(not Ch.better_axis(fake(10, 0), fake(15, 1)), "choix : un coffre de tete de plus ne paie pas quelques foreuses")
  check(Ch.better_axis(fake(10, 0), fake(30, 1)), "choix : l'axe long garde moins de la moitie -> l'autre, coffre de tete compris")
  check(not Ch.better_axis(fake(10, 0), nil) and not Ch.axis_retry(nil), "choix : sans second plan")
end

print(string.format("s42 gisements : %d OK, %d echec(s)", passes, failures))
if failures > 0 then os.exit(1) end
