--[[
  Tests hors jeu du lot FONDERIES (retour du DC du 29/10 après 1 h 30 de partie sur 0.6.13 ; pur, aucune API Factorio).
  Usage, depuis la racine du mod :   lua5.2 tests/fonte_test.lua

  1. orientation : la tête d'alimentation d'une fonderie à tapis est tournée VERS le gisement, la colonne de fours
     s'étend à l'opposé (« l'input le plus proche du gisement, puis ligne droite de fours, dans un sens unique, vers
     l'extérieur, sans revenir vers l'intérieur ») ; sans consigne `head_toward`, le placement d'avant est inchangé ;
  2. équilibre : nombre de fours voulu d'après le débit d'entrée réel (shared/team/fonte.lua).
]]
package.path = "./?.lua;" .. package.path

local P = require("shared.team.plan")
local M = require("shared.team.modules")
local Fonte = require("shared.team.fonte")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local lat = P.lattice({ x = 0.5, y = 0.5 })
local x0, y0, x1, y1 = P.lot_rect(lat, 3, 3)
local rect = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2

--- Pose le gabarit rotated selon P.fit ; rend { tip = {x, y} (bout de la tête d'alimentation), c = centre, out = vecteur
--- unitaire du côté tête, fit }.
local function placed(g, opts)
  local fit = P.fit(g, rect, opts)
  if not fit then return nil end
  local r = fit.k == 0 and g or M.rotate(g, fit.k)
  local inst = M.instantiate(r, 0, fit.ox, fit.oy)
  local port
  for _, p in ipairs(P.belt_ports(inst)) do if p.io == "in" then port = p break end end
  local v = P.DV[port.dir]
  return { tip = { x = port.x - P.FEED_DEPTH * v[1] + 0.5, y = port.y - P.FEED_DEPTH * v[2] + 0.5 },
    c = { x = fit.ox + r.w / 2, y = fit.oy + r.h / 2 }, out = { -v[1], -v[2] }, fit = fit, w = r.w, h = r.h }
end

section("1. Orientation : la tête regarde le gisement")
do
  local g = M.GEN.smelter("stone-furnace", "iron-ore", 4)
  local dirs = { N = { 0, -1 }, E = { 1, 0 }, S = { 0, 1 }, W = { -1, 0 } }
  local ks = {}
  for _, name in ipairs({ "N", "E", "S", "W" }) do
    local d = dirs[name]
    local toward = { x = cx + d[1] * 70, y = cy + d[2] * 70 }
    local r = placed(g, { toward = toward, head_toward = toward })
    check(r ~= nil, "gisement au " .. name .. " : fonderie placée")
    if r then
      ks[#ks + 1] = r.fit.k
      -- la tête (côté entrée) est tournée vers le gisement : sa direction sortante est celle du gisement
      check(r.out[1] == d[1] and r.out[2] == d[2], "gisement au " .. name .. " : la tête regarde le gisement (sortant " .. r.out[1] .. "," .. r.out[2] .. ")")
      -- le bout de tête est plus près du gisement que le centre de la colonne (jamais de retour vers l'intérieur)
      local dt = math.abs(r.tip.x - toward.x) + math.abs(r.tip.y - toward.y)
      local dc = math.abs(r.c.x - toward.x) + math.abs(r.c.y - toward.y)
      check(dt < dc, "gisement au " .. name .. " : la tête est du côté du gisement (" .. dt .. " < " .. dc .. ")")
    end
  end
  -- sans consigne : le comportement d'avant (inchangé, tête au nord pour un gabarit non tourné)
  local toward = { x = cx, y = cy + 70 }
  local a = P.fit(g, rect, { toward = toward })
  local b = P.fit(g, rect, { toward = toward, head_toward = nil })
  check(a and b and a.k == b.k and a.ox == b.ox and a.oy == b.oy, "sans consigne : placement identique")
  -- déterminisme
  local t1 = placed(g, { toward = toward, head_toward = toward })
  local t2 = placed(g, { toward = toward, head_toward = toward })
  check(t1 and t2 and t1.fit.k == t2.fit.k and t1.fit.ox == t2.fit.ox and t1.fit.oy == t2.fit.oy, "déterministe")
  -- un gabarit sans port d'entrée tapis garde son placement même avec la consigne
  local drills = M.GEN.drills("iron-ore", 3)
  local ore = {}
  for y = y0, y1 - 1 do for x = x0, x1 - 1 do ore[P.tkey(x, y)] = true end end
  local d1 = P.fit(drills, rect, { ore = ore, toward = toward })
  local d2 = P.fit(drills, rect, { ore = ore, toward = toward, head_toward = toward })
  check(d1 and d2 and d1.k == d2.k and d1.ox == d2.ox and d1.oy == d2.oy, "gabarit sans port d'entrée : placement inchangé")
end

section("2. Équilibre : fours voulus d'après le débit d'entrée")
do
  -- un four de pierre : 0,3125 plaque/s (3,2 s ÷ vitesse 1) ; une foreuse électrique : 0,5 minerai/s
  local cap, drill = 1 / 3.2, 0.5
  check(Fonte.furnaces_wanted(0, cap, 20) == 0, "aucune entrée : aucun four")
  check(Fonte.furnaces_wanted(drill, cap, 20) == 2, "1 foreuse : 2 fours (0,5 / 0,3125)")
  check(Fonte.furnaces_wanted(4 * drill, cap, 20) == 7, "4 foreuses : 7 fours")
  check(Fonte.furnaces_wanted(100, cap, 20) == 20, "borné par l'emprise")
  check(Fonte.furnaces_wanted(drill, 0, 20) == 0, "four sans capacité : 0")
  -- des fours qui ne couvriraient pas leur entrée : pas de fraction de four perdue sur un flottant
  check(Fonte.furnaces_wanted(cap * 5, cap, 20) == 5, "entrée = 5 fours pile : 5 (pas 6)")
  local function d(entree, fours, foreuses)
    return Fonte.balance({ input = entree, capacity = cap, furnaces = fours, max_furnaces = 20, drills = foreuses, drill_rate = drill, max_drills = 12 })
  end
  local ok = d(2.5, 8, 5)
  check(ok.action == "equilibre", "entrée = capacité : équilibre (" .. ok.action .. ")")
  local trop = d(4.0, 8, 8)
  check(trop.action == "ajouter_fours" and trop.furnaces == 13, "trop d'entrée : ajouter des fours jusqu'à 13 (" .. trop.action .. " " .. tostring(trop.furnaces) .. ")")
  local plein = Fonte.balance({ input = 8, capacity = cap, furnaces = 18, max_furnaces = 20, drills = 16, drill_rate = drill, max_drills = 16 })
  check(plein.action == "retirer_foreuses" and plein.drills == 12 and plein.furnaces == 20, "emprise pleine : on retire des foreuses (" .. plein.action .. " " .. tostring(plein.drills) .. ")")
  local peu = d(1.0, 8, 2)
  check(peu.action == "ajouter_foreuses" and peu.drills == 5, "fours en trop, foreuses possibles : ajouter des foreuses (" .. peu.action .. " " .. tostring(peu.drills) .. ")")
  local peu2 = Fonte.balance({ input = 1.0, capacity = cap, furnaces = 8, max_furnaces = 20, drills = 2, drill_rate = drill, max_drills = 2 })
  check(peu2.action == "retirer_fours" and peu2.furnaces == 4, "fours en trop, foreuses au maximum : retirer des fours (" .. peu2.action .. " " .. tostring(peu2.furnaces) .. ")")
  check(Fonte.balance({ input = 0, capacity = cap, furnaces = 8, max_furnaces = 20, drills = 0, drill_rate = drill, max_drills = 0 }).action == "sans_entree", "aucune entrée : sans_entree")
  check(Fonte.balance({ input = 1, capacity = 0, furnaces = 8, max_furnaces = 20, drills = 1, drill_rate = drill, max_drills = 1 }).action == "invalide", "capacité nulle : invalide")
end

print(string.format("[FONTE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
