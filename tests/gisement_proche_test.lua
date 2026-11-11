--[[
  Lot PAVAGE-GEANT, règle R3 du DC (11/11) : « interdiction de planifier un avant-poste distant tant que les gisements majeurs adjacents à
  la base ne sont pas exploités au maximum ». Tests PURS de shared/faction/valeur.lua (V.unfull_distance, V.admissible) et de
  shared/team/mega_fonderie.lua (Mf.decide, entrée `nearer`).
  Usage, depuis la racine du mod :   lua5.2 tests/gisement_proche_test.lua

  Cas mesuré (banc default, graine 2507543475, fo-logs/2026-11-11_PAVAGE-GEANT/avant) : Ambre, fer de départ iron-ore@-338,-307 à 45 tuiles
  du QG, 184/377 tuiles couvertes (488 pour mille, 11 places libres) ; à 29,3 min la méga-fonderie DÉCIDE iron-ore@-205,-600 (1 270 tuiles,
  273 tuiles du QG) et l'avant-poste thermique 6 y est bâti à 30,3 min (« avant-postes iron avec des places : 0 »).
]]

package.path = "./?.lua;" .. package.path
local V = require("shared.faction.valeur")
local Mf = require("shared.team.mega_fonderie")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local HQ = { x = -330, y = -340 }
local function dep(t)
  return { id = t.id, resource = t.resource or "iron-ore", tiles = t.tiles, covered = t.covered, full = t.full, danger = t.danger,
    cx = t.cx, cy = t.cy, x0 = t.cx - 10, y0 = t.cy - 10, x1 = t.cx + 10, y1 = t.cy + 10 }
end
local function dist(x, y) return math.sqrt((x - HQ.x) ^ 2 + (y - HQ.y) ^ 2) end

local home = dep({ id = "iron-ore@-338,-307", tiles = 377, covered = 184, cx = -338, cy = -307 })
local far = dep({ id = "iron-ore@-205,-600", tiles = 1270, covered = 0, cx = -205, cy = -600 })
local far_site = { x = -198, y = -574, resource = "iron-ore" }

section("1. V.unfull_distance : gisement ouvert plus proche pas plein")
do
  local d = V.unfull_distance({ far, home }, "iron-ore", HQ, far_site)
  check(d ~= nil and math.abs(d - dist(-338, -307)) < 1e-9, "fer de depart ouvert, 488 pour mille : distance rendue (" .. tostring(d) .. ")")
  check(V.unfull_distance({ far, home }, "copper-ore", HQ, far_site) == nil, "autre minerai : rien")
  local full = dep({ tiles = 377, covered = 184, cx = -338, cy = -307, full = true })
  check(V.unfull_distance({ far, full }, "iron-ore", HQ, far_site) == nil, "gisement plein (verdict de la capitalisation) : rien")
  local none = dep({ tiles = 377, covered = 0, cx = -338, cy = -307 })
  check(V.unfull_distance({ far, none }, "iron-ore", HQ, far_site) == nil, "gisement connu sans foreuse (pas ouvert) : rien")
  local hostile = dep({ tiles = 377, covered = 184, cx = -338, cy = -307, danger = true })
  check(V.unfull_distance({ far, hostile }, "iron-ore", HQ, far_site) == nil, "gisement en danger : rien")
  check(V.unfull_distance({ far, home }, "iron-ore", HQ, { x = -336, y = -305 }) == nil, "site DANS le gisement ouvert : il s'agrandit, rien")
  check(V.unfull_distance({ home, far }, "iron-ore", HQ, far_site) == V.unfull_distance({ far, home }, "iron-ore", HQ, far_site),
    "ordre de la liste sans effet")
  check(V.unfull_distance(nil, "iron-ore", HQ, far_site) == nil, "aucun gisement recense : rien")
end

section("2. V.admissible : R3 refuse le site lointain")
do
  local d_unfull = V.unfull_distance({ far, home }, "iron-ore", HQ, far_site)
  local ok, why = V.admissible({ value = 150, d_hq = dist(far_site.x, far_site.y) }, nil, d_unfull)
  check(ok == false and why == "proche", "site a 273 tuiles, fer de depart pas plein a 45 : refuse (" .. tostring(why) .. ")")
  check(V.admissible({ value = 150, d_hq = dist(far_site.x, far_site.y) }, nil, nil) == true, "aucun gisement pas plein : admis (regle d'avant)")
  check(V.admissible({ value = 150, d_hq = 20 }, nil, d_unfull) == true, "site PLUS PROCHE que le gisement pas plein : admis")
  local _, w2 = V.admissible({ value = -500, d_hq = 300 }, nil, d_unfull)
  check(w2 == "plancher", "plancher de valeur d'abord (motif inchange)")
end

section("3. Mf.decide : la méga-fonderie attend le gisement proche")
do
  local z = { full_lines = 7, lines = 7, furnaces = 168 }
  local base = { on = true, smeltable = true, size = z, power = true, crisis = false }
  check(Mf.decide(base) == "decider", "sans gisement proche pas plein : decider")
  local nb = {}
  for k, v in pairs(base) do nb[k] = v end
  nb.nearer = true
  local a, why = Mf.decide(nb)
  check(a == "attendre" and why:find("plus proche", 1, true) ~= nil, "gisement ouvert plus proche pas plein : attendre (" .. tostring(why) .. ")")
end

print(string.format("\nResultat : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
