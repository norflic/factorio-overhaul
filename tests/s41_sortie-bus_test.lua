--[[
  s41 sortie-bus : trop-plein du quai d'une colonne de fours (Co.EXT tuiles de la ligne de plaques au-delà du dernier bras du quai,
  déclarées sources de piquage). Pur, aucune API Factorio. Usage, depuis la racine du mod :   lua5.2 tests/s41_sortie-bus_test.lua
  1. Co.layout : sans `ext`, la colonne d'avant le lot, pièce pour pièce ; avec, les mêmes pièces + ext tapis droits, sans collision ;
  2. Co.place : place libre -> trop-plein ; place qui manque au-delà du quai -> pas de trop-plein, plan identique à celui d'avant ;
     cadre figé sans `ext` -> plan d'avant ; avec -> rejoué ;
  3. champ entier (Ch.plan) : contrôle champ_verif vert, aucune tuile portée par deux pièces, cadre rejoué identique.
]]
package.path = "./?.lua;" .. package.path
local Ch = require("shared.team.champ")
local Co = require("shared.team.champ_colonne")
local Cv = require("shared.team.champ_verif")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

local SPEC = { furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 }, inserter = { rate = 0.83 }, pole = { reach = 2, wire = 7.5 } }
local function sig(e) return string.format("%s|%d|%d|%d|%d|%d|%s", e.kind, e.u, e.v, e.size, e.du, e.dv, tostring(e.role)) end
local function sigs(list) local t = {}; for i, e in ipairs(list) do t[i] = sig(e) end; return table.concat(t, ";") end
local function overlaps(list)
  local seen, n = {}, 0
  for _, e in ipairs(list) do
    for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do
      local k = u .. ":" .. v
      if seen[k] then n = n + 1 end
      seen[k] = true
    end end
  end
  return n
end

print("== 1. Co.layout")
for _, mode in ipairs({ "voie", "coffre" }) do
  for _, count in ipairs({ 1, 6, 24 }) do
    local name = mode .. " " .. count .. " fours"
    local a, la, ia = Co.layout(SPEC, 0, 1, 0, count, mode)
    local z = Co.layout(SPEC, 0, 1, 0, count, mode, nil, 0)
    local b, lb, ib = Co.layout(SPEC, 0, 1, 0, count, mode, nil, Co.EXT)
    check(a and b and z, name .. " : colonnes rendues")
    check(sigs(a) == sigs(z) and ia.ext == nil, name .. " : ext absent ou nul = colonne d'avant le lot")
    check(overlaps(b) == 0, name .. " : aucune tuile portée par deux pièces (" .. overlaps(b) .. ")")
    -- les pièces d'avant y sont toutes ; les pièces neuves : Co.EXT tapis de plaques droits au-delà du quai, puis la voie de charbon allongée
    local old = {}
    for _, e in ipairs(a) do old[sig(e)] = true end
    local kept, extra, piq, coal = 0, {}, 0, 0
    for _, e in ipairs(b) do
      if old[sig(e)] then kept = kept + 1
      elseif e.role == "charbon" then coal = coal + 1
      else extra[#extra + 1] = e; if e.piq then piq = piq + 1 end end
    end
    check(kept == #a, name .. " : toutes les pièces d'avant gardées")
    check(#extra == Co.EXT and piq == Co.EXT - 1, name .. " : " .. Co.EXT .. " tuiles de trop-plein dont " .. (Co.EXT - 1) .. " déclarées (" .. #extra .. ", " .. piq .. ")")
    local chest_max = -math.huge
    for _, e in ipairs(a) do if e.kind == "coffre" and e.role == "sortie" then chest_max = math.max(chest_max, e.u) end end
    local row
    for i, e in ipairs(extra) do
      row = row or e.v
      check(e.kind == "tapis" and e.role == "sortie" and e.du == 1 and e.dv == 0 and e.v == row and e.u == chest_max + i, name .. " : trop-plein droit, à la suite du quai")
    end
    check(lb == la + Co.EXT and ib.far == ia.far + Co.EXT and ib.ext == Co.EXT and ib.bay == ia.bay, name .. " : longueur et bout décalés de Co.EXT, quai inchangé")
    check(coal == (mode == "voie" and Co.EXT or 0), name .. " : voie de charbon allongée d'autant (" .. coal .. ")")
  end
end

print("== 2. Co.place")
local function no_ore() return false end
local count = 6
local base = Co.layout(SPEC, 0, 1, 3, count, "voie")
local ext = Co.layout(SPEC, 0, 1, 3, count, "voie", nil, Co.EXT)
local l1, _, s1, _, i1 = Co.place(SPEC, 0, 1, 0, count, 2, 0, function() return true end, no_ore, "voie", nil)
check(l1 and s1 == 3 and i1.ext == Co.EXT and sigs(l1) == sigs(ext), "place libre : colonne avec trop-plein, à la même place")
-- la place manque au-delà du quai : chaque tuile propre au plan avec trop-plein prise tour à tour
local only = {}
do
  local old = {}
  for _, e in ipairs(base) do old[e.u .. ":" .. e.v] = true end
  for _, e in ipairs(ext) do if not old[e.u .. ":" .. e.v] then only[#only + 1] = e end end
end
check(#only > 0, "tuiles propres au trop-plein trouvées")
for _, t in ipairs(only) do
  local l2, _, s2, _, i2 = Co.place(SPEC, 0, 1, 0, count, 2, 0, function(u, v) return not (u == t.u and v == t.v) end, no_ore, "voie", nil)
  check(l2 and s2 == 3 and i2.ext == nil and sigs(l2) == sigs(base), string.format("tuile (%d, %d) prise : colonne posée sans trop-plein, plan d'avant", t.u, t.v))
end
do -- ressource sous le trop-plein (F500) : pas de trop-plein non plus
  local t = only[1]
  local l2, _, _, _, i2 = Co.place(SPEC, 0, 1, 0, count, 2, 0, function() return true end, function(u, v) return u == t.u and v == t.v end, "voie", nil)
  check(l2 and i2.ext == nil and sigs(l2) == sigs(base), "ressource sous le trop-plein : plan d'avant")
end
local lf, _, _, _, inf = Co.place(SPEC, 0, 1, 0, count, 2, 0, function() return true end, no_ore, "voie", { s_edge = 3, count = count })
check(lf and inf.ext == nil and sigs(lf) == sigs(base), "cadre figé d'avant le lot (sans ext) : plan d'avant, même place libre")
local lg, _, _, _, ing = Co.place(SPEC, 0, 1, 0, count, 2, 0, function() return true end, no_ore, "voie", { s_edge = 3, count = count, ext = Co.EXT })
check(lg and ing.ext == Co.EXT and sigs(lg) == sigs(ext), "cadre figé avec ext : trop-plein rejoué")

print("== 3. champ entier")
local function disc(cx, cy, r, out)
  out = out or {}
  for x = cx - r, cx + r do for y = cy - r, cy + r do if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r then out[#out + 1] = x; out[#out + 1] = y end end end
  return out
end
local function spec_of(ore, coal, frame, electric)
  return { ore = ore, blocked = {}, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = { { lane = 7.5 }, { lane = 15 }, { lane = 22.5 } },
    furnace = electric and { size = 2, rate = 0.625, fuel = false } or { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 },
    inserter = { rate = 0.83 }, target = { x = 1000, y = 0 }, max_side = 8, frame = frame, design = "colonne",
    coal = coal and { tiles = coal, rate = 0.5 } or nil, logistics = {} }
end
local function tile_dups(p)
  local seen, n = {}, 0
  for _, e in ipairs(p.ents) do
    local w, h = e.w or e.size, e.h or e.size
    for x = math.floor(e.x - w / 2 + 0.01), math.floor(e.x + w / 2 - 0.01) do
      for y = math.floor(e.y - h / 2 + 0.01), math.floor(e.y + h / 2 - 0.01) do
        local k = x .. ":" .. y
        if seen[k] then n = n + 1 end
        seen[k] = true
      end
    end
  end
  return n
end
local function plan_sig(p)
  local t = {}
  for i, e in ipairs(p.ents) do t[i] = string.format("%s|%.1f|%.1f|%d|%s|%s", e.kind, e.x, e.y, e.dir or 0, tostring(e.role), tostring(e.piq)) end
  table.sort(t)
  return table.concat(t, ";")
end
for _, c in ipairs({ { "disque 12, charbon proche", disc(0, 0, 12), disc(60, 30, 7) }, { "disque 20, charbon proche", disc(0, 0, 20), disc(70, -40, 8) },
  { "disque 14, fours électriques", disc(0, 0, 14), nil, true } }) do
  local name = c[1]
  local sp = spec_of(c[2], c[3], nil, c[4])
  local p = Ch.plan(sp)
  check(p ~= nil, name .. " : plan rendu")
  if p then
    local rep = Cv.verify(p, sp)
    check(rep.ok, name .. " : contrôle " .. Cv.line(rep))
    check(tile_dups(p) == 0, name .. " : aucune tuile portée par deux pièces (" .. tile_dups(p) .. ")")
    local piq, bad = 0, 0
    for _, e in ipairs(p.ents) do if e.piq then piq = piq + 1; if not (e.kind == "tapis" and e.role == "sortie") then bad = bad + 1 end end end
    check(piq > 0 and bad == 0, name .. " : tuiles de trop-plein déclarées sur la ligne de plaques (" .. piq .. ")")
    local sp2 = spec_of(c[2], c[3], p.frame, c[4])
    local p2 = Ch.plan(sp2)
    check(p2 ~= nil and plan_sig(p2) == plan_sig(p), name .. " : cadre figé rejoué à l'identique")
    print(string.format("  %s : %d pièces, %d tuiles de trop-plein déclarées, %s", name, #p.ents, piq, Cv.line(rep)))
  end
end

print(string.format("s41 sortie-bus : %d OK, %d ECHEC", passes, failures))
if failures > 0 then os.exit(1) end
