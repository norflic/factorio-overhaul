--[[
  Lot UPS-HYGIENE (Mode Démon du DC, 10/11) : zone d'une équipe (shared/team/zone_equipe.lua, script/team/zone_equipe.lua) et son
  câblage dans les relevés de l'hygiène et des balises.
    §1 règle pure : rect_of_points, rect_around, merge (touchent, chevauchent, chaîne au point fixe, disjoints), clip, box_tiles, cost, area ;
    §2 moteur script/team/zone_equipe.lua sur un moteur minimal : rectangles d'une équipe (projets, QG, avant-postes, chaîne des foreuses,
       remplaçant en attente), fusion, rognage, mémo d'un tick, repli sans plan ni QG, Zone.find (dédoublonnage, repli boîte), tkey_xy ;
    §3 câblage textuel : hygiene.lua et balises_teinte.lua relèvent par Zone.find / Zone.rects, plus par la boîte entière ;
    §4 mutants (source modifiée, rechargée) : chacun doit être détecté par un contrôle de §1/§2.
  Lancer : lua5.2 tests/zone_equipe_test.lua
]]
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function section(name) print("== " .. name) end
local function slurp(path) local fh = assert(io.open(path, "rb")) local s = fh:read("*a") fh:close() return s end

local Ze = require("shared.team.zone_equipe")

section("§1 règle pure")
---------------------------------------------------------------------------------------------------
local r = Ze.rect_of_points({ { x = 10.5, y = 4.5 }, { x = 12.5, y = 9.5 }, { 3, 7 } }, 0)
check(r.x0 == 3 and r.y0 == 4 and r.x1 == 14 and r.y1 == 11, "rect_of_points : boîte entière des points, tuiles entières, x1/y1 exclus")
local rm = Ze.rect_of_points({ { x = 10.5, y = 4.5 } }, 9)
check(rm.x0 == 1 and rm.y0 == -5 and rm.x1 == 21 and rm.y1 == 15, "rect_of_points : marge de 9 de chaque côté")
check(Ze.rect_of_points({}, 3) == nil and Ze.rect_of_points(nil, 3) == nil, "sans point : nil")
local ra = Ze.rect_around(100, 50, 8, 2)
check(ra.x0 == 90 and ra.y0 == 40 and ra.x1 == 111 and ra.y1 == 61, "rect_around : centre ± (rayon + marge)")

local merged = Ze.merge({ { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, { x0 = 10, y0 = 0, x1 = 20, y1 = 10 } })
check(#merged == 1 and merged[1].x0 == 0 and merged[1].x1 == 20, "deux rectangles qui se touchent (bord commun) : fusionnés")
merged = Ze.merge({ { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, { x0 = 5, y0 = 5, x1 = 30, y1 = 8 } })
check(#merged == 1 and merged[1].x1 == 30 and merged[1].y1 == 10, "chevauchement : fusionnés, boîte englobante")
merged = Ze.merge({ { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, { x0 = 50, y0 = 50, x1 = 60, y1 = 60 } })
check(#merged == 2 and merged[1].x0 == 0 and merged[2].x0 == 50, "disjoints : deux rectangles, triés par x0")
-- chaîne : C touche B, B touche A, mais C ne touche pas A : la fusion doit aller au point fixe (A ∪ B ∪ C)
merged = Ze.merge({ { x0 = 40, y0 = 0, x1 = 60, y1 = 10 }, { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, { x0 = 10, y0 = 0, x1 = 40, y1 = 10 } })
check(#merged == 1 and merged[1].x0 == 0 and merged[1].x1 == 60, "chaîne A-B-C : un seul rectangle au point fixe")
-- B est trié avant C mais ne touche A qu'après la fusion de C dans A : une seule passe les laisserait séparés
merged = Ze.merge({ { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, { x0 = 1, y0 = 20, x1 = 2, y1 = 30 }, { x0 = 2, y0 = 10, x1 = 10, y1 = 20 } })
check(#merged == 1 and merged[1].y1 == 30, "point fixe : un voisin examiné avant que le rectangle ne grandisse est repris à la passe suivante")
merged = Ze.merge({ { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, { x0 = 5, y0 = 5, x1 = 8, y1 = 30 } })
check(#merged == 1 and merged[1].y1 == 30 and merged[1].x1 == 10, "chevauchement en y : la boîte englobante prend y1")
-- ordre d'entrée sans effet
local m1 = Ze.merge({ { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, { x0 = 50, y0 = 0, x1 = 60, y1 = 10 }, { x0 = 9, y0 = 0, x1 = 51, y1 = 10 } })
local m2 = Ze.merge({ { x0 = 9, y0 = 0, x1 = 51, y1 = 10 }, { x0 = 50, y0 = 0, x1 = 60, y1 = 10 }, { x0 = 0, y0 = 0, x1 = 10, y1 = 10 } })
check(#m1 == 1 and #m2 == 1 and m1[1].x0 == m2[1].x0 and m1[1].x1 == m2[1].x1, "fusion indépendante de l'ordre d'entrée")
merged = Ze.merge({ { x0 = 0, y0 = 0, x1 = 0, y1 = 10 }, { x0 = 5, y0 = 5, x1 = 6, y1 = 6 } })
check(#merged == 1 and merged[1].x0 == 5, "un rectangle vide (x1 == x0) est ignoré")

local clipped = Ze.clip({ { x0 = -100, y0 = -100, x1 = 10, y1 = 10 }, { x0 = 500, y0 = 500, x1 = 600, y1 = 600 } }, { x0 = -64, y0 = -64, x1 = 128, y1 = 128 })
check(#clipped == 1 and clipped[1].x0 == -64 and clipped[1].y0 == -64 and clipped[1].x1 == 10, "clip : rogné à la boîte, le rectangle hors boîte disparaît")
check(#Ze.clip({ { x0 = 0, y0 = 0, x1 = 1, y1 = 1 } }, nil) == 1, "clip sans boîte : inchangé")
local bt = Ze.box_tiles({ x0 = -2, y0 = -2, x1 = 3, y1 = 3 })
check(bt.x0 == -64 and bt.y0 == -64 and bt.x1 == 128 and bt.y1 == 128, "box_tiles : chunks -2..3 -> tuiles -64..128")
check(Ze.box_tiles(nil) == nil, "box_tiles sans boîte : nil")
check(Ze.cost({ { x0 = 0, y0 = 0, x1 = 32, y1 = 32 } }) == 1, "cost : un chunk exact = 1")
check(Ze.cost({ { x0 = -1, y0 = 0, x1 = 33, y1 = 32 } }) == 3, "cost : déborde d'une tuile de chaque côté en x = 3 chunks")
check(Ze.cost({ { x0 = 0, y0 = 0, x1 = 64, y1 = 64 }, { x0 = 100, y0 = 100, x1 = 101, y1 = 101 } }) == 5, "cost : somme (4 + 1)")
local a = Ze.area({ x0 = 1, y0 = 2, x1 = 3, y1 = 4 })
check(a[1][1] == 1 and a[1][2] == 2 and a[2][1] == 3 and a[2][2] == 4, "area : format du moteur")

section("§2 moteur script/team/zone_equipe.lua sur un moteur minimal")
---------------------------------------------------------------------------------------------------
local chunk_box = { x0 = -4, y0 = -4, x1 = 12, y1 = 12 } -- tuiles -128..416
package.loaded["script.team.boite_chunks"] = { get = function() return chunk_box end }
package.loaded["shared.team.config"] = { seed_radius = { coal = 8, iron = 11, copper = 8, stone = 6 } }
game = { get_filtered_entity_prototypes = function() return { a = { max_wire_distance = 7.5 }, b = { max_wire_distance = 9 }, c = { max_wire_distance = 30 } } end } -- luacheck: ignore
local Zone = require("script.team.zone_equipe")
local P = require("shared.team.plan")
check(Zone.marge() == 31, "marge = portée de fil la plus longue des poteaux (30) + 1, lue aux prototypes : " .. tostring(Zone.marge()))
for _, xy in ipairs({ { 0, 0 }, { 17, -233 }, { -1000, 999 }, { 123456, -123456 } }) do
  local x, y = Zone.tkey_xy(P.tkey(xy[1], xy[2]))
  check(x == xy[1] and y == xy[2], string.format("tkey_xy inverse P.tkey (%d, %d)", xy[1], xy[2]))
end

local f = { key = 1, force = "f1", team = {}, hq_pos = { x = 0, y = 0 },
  build = { order = { 1, 2, 3 }, projects = {
    [1] = { state = "fini", ents = { { name = "p", x = 100, y = 100 }, { name = "p", x = 120, y = 110 } } },
    [2] = { state = "chantier", abandoned = true, ents = { { name = "p", x = 300, y = 300 } } },
    [3] = { state = "fini", ents = {} },
  } },
  outposts = { [7] = { kind = "iron", pos = { x = 200, y = -100 } }, [2] = { kind = "stone", pos = { x = 200, y = -100 } } },
  swap = { pole_pos = { [P.tkey(150, 150)] = true, [P.tkey(152, 150)] = true } },
}
local rects = Zone.rects(f, {}, 1000)
check(rects ~= nil and #rects >= 1, "une équipe avec plan : des rectangles")
local function covers(rs, x, y) for _, q in ipairs(rs) do if x >= q.x0 and x < q.x1 and y >= q.y0 and y < q.y1 then return true end end return false end
check(covers(rects, 100, 100) and covers(rects, 120, 110) and covers(rects, 120 + 30, 110 + 30), "projet 1 couvert, marge de 31 comprise")
check(covers(rects, 300, 300), "projet abandonné couvert (ses poteaux sont encore debout)")
check(covers(rects, 0, 0) and covers(rects, -16 - 31, 0), "QG couvert : rayon 16 + marge")
check(covers(rects, 200 + 11 + 31, -100), "avant-poste couvert : position ± rayon de la sorte (fer : 11) + marge")
check(covers(rects, 151, 150), "chaîne des foreuses couverte")
check(not covers(rects, 400, 400) and not covers(rects, -120, -120), "loin de tout : hors zone")
local n_before = #rects
for i = 1, #rects do
  for j = i + 1, #rects do
    local p, q = rects[i], rects[j]
    check(not (p.x0 <= q.x1 and q.x0 <= p.x1 and p.y0 <= q.y1 and q.y0 <= p.y1), "les rectangles rendus ne se touchent pas")
  end
end
for _, q in ipairs(rects) do check(q.x0 >= -128 and q.y0 >= -128 and q.x1 <= 416 and q.y1 <= 416, "rognés à la boîte des chunks") end
check(Zone.rects(f, {}, 1000) == rects, "mémo d'un tick : même table au même tick")
f.team.hygiene_pending = { new = { 9, 380, 380 } }
check(Zone.rects(f, {}, 1000) == rects, "le mémo ne relit pas l'état dans le même tick")
local rects2 = Zone.rects(f, {}, 1001)
check(rects2 ~= rects and covers(rects2, 380, 380) and n_before <= #rects2 + 1, "tick suivant : recalcul, remplaçant en attente couvert")
local f2 = { key = 2, force = "f2", team = {} }
check(Zone.rects(f2, {}, 1001) == nil, "sans plan ni QG : nil (repli sur la boîte entière)")
check(Zone.cost(nil, chunk_box) == 17 * 17 and Zone.cost({ { x0 = 0, y0 = 0, x1 = 32, y1 = 32 } }, chunk_box) == 1, "cost : boîte entière sans zone, chunks des rectangles sinon")

-- Zone.find : une recherche par rectangle, dédoublonnage par unit_number, repli sur la boîte entière
local queries = {}
local world = { { unit_number = 1, position = { x = 100, y = 100 } }, { unit_number = 2, position = { x = 0, y = 0 } }, { unit_number = 3, position = { x = -120, y = -120 } } }
local surface = { find_entities_filtered = function(q)
  queries[#queries + 1] = q.area
  local out = {}
  for _, e in ipairs(world) do
    local a = q.area
    if not a or (e.position.x >= a[1][1] and e.position.x < a[2][1] and e.position.y >= a[1][2] and e.position.y < a[2][2]) then out[#out + 1] = e end
  end
  return out
end }
local found = Zone.find(surface, { type = "electric-pole", force = "f1" }, rects2, chunk_box)
check(#queries == #rects2, "une recherche par rectangle : " .. #queries)
local ids = {}
for _, e in ipairs(found) do ids[e.unit_number] = (ids[e.unit_number] or 0) + 1 end
check(ids[1] == 1 and ids[2] == 1 and ids[3] == nil, "trouvés : 1 et 2 une fois chacun ; 3 (hors zone) non")
queries = {}
local big = { { x0 = -128, y0 = -128, x1 = 200, y1 = 200 }, { x0 = 50, y0 = 50, x1 = 300, y1 = 300 } } -- se chevauchent (non fusionnés exprès)
found = Zone.find(surface, { type = "electric-pole" }, big, chunk_box)
ids = {}
for _, e in ipairs(found) do ids[e.unit_number] = (ids[e.unit_number] or 0) + 1 end
check(#queries == 2 and ids[1] == 1, "dédoublonnage par unit_number quand deux rectangles couvrent la même entité")
queries = {}
found = Zone.find(surface, { type = "electric-pole" }, nil, chunk_box)
check(#queries == 1 and queries[1][1][1] == -128 and queries[1][2][1] == 416 and #found == 3, "sans zone : une recherche sur la boîte entière")

section("§3 câblage textuel")
---------------------------------------------------------------------------------------------------
local hy = slurp("script/team/hygiene.lua")
local bt_src = slurp("script/team/balises_teinte.lua")
check(hy:find('local Zone = require("script.team.zone_equipe")', 1, true) ~= nil, "hygiene.lua requiert zone_equipe")
check(hy:find("Zone.rects(f, surface, tick)", 1, true) ~= nil and hy:find("Zone.find(surface, q, rects, box)", 1, true) ~= nil, "hygiene.lua relève par Zone.rects / Zone.find")
check(hy:find("Lourd.take(tick, who(f), nil, Zone.cost(rects, box))", 1, true) ~= nil, "hygiene.lua déclare au jeton le coût de la zone")
check(hy:find("box.x0 * 32", 1, true) == nil, "hygiene.lua : plus de zone « boîte entière » construite à la main")
check(bt_src:find('local Zone = require("script.team.zone_equipe")', 1, true) ~= nil, "balises_teinte.lua requiert zone_equipe")
check(bt_src:find("Zone.find(surface, q, Zone.rects(f, surface, tick), box)", 1, true) ~= nil, "balises_teinte.lua relève par Zone.find")
check(bt_src:find("box.x0 * 32", 1, true) == nil, "balises_teinte.lua : plus de zone « boîte entière » construite à la main")
local rt_src = slurp("script/team/zone_equipe.lua")
check(rt_src:find("%f[%w_]global%f[^%w_]") == nil, "zone_equipe.lua (script) ne nomme pas `global`")
check(rt_src:find('"small%-electric%-pole"') == nil and rt_src:find('"medium%-electric%-pole"') == nil and rt_src:find('"big%-electric%-pole"') == nil, "aucun nom de poteau en dur : la marge vient des prototypes")

section("§4 mutants de la règle pure")
---------------------------------------------------------------------------------------------------
local src = slurp("shared/team/zone_equipe.lua")
local function load_mut(fn)
  local s = fn(src)
  if s == src then return nil end
  local chunk = assert(load(s, "zone_equipe_mut", "t"))
  return chunk()
end
local function survives(M)
  -- le même détecteur que §1 : chaîne au point fixe, bord commun, marge, clip, cost
  local ok = true
  local m = M.merge({ { x0 = 40, y0 = 0, x1 = 60, y1 = 10 }, { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, { x0 = 10, y0 = 0, x1 = 40, y1 = 10 } })
  ok = ok and #m == 1 and m[1].x0 == 0 and m[1].x1 == 60
  m = M.merge({ { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, { x0 = 10, y0 = 0, x1 = 20, y1 = 10 } })
  ok = ok and #m == 1
  m = M.merge({ { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, { x0 = 50, y0 = 50, x1 = 60, y1 = 60 } })
  ok = ok and #m == 2 and m[1].x0 == 0
  m = M.merge({ { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, { x0 = 1, y0 = 20, x1 = 2, y1 = 30 }, { x0 = 2, y0 = 10, x1 = 10, y1 = 20 } })
  ok = ok and #m == 1 and m[1].y1 == 30
  m = M.merge({ { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, { x0 = 5, y0 = 5, x1 = 8, y1 = 30 } })
  ok = ok and #m == 1 and m[1].y1 == 30
  local q = M.rect_of_points({ { x = 10.5, y = 4.5 } }, 9)
  ok = ok and q.x0 == 1 and q.y0 == -5 and q.x1 == 21 and q.y1 == 15
  local c = M.clip({ { x0 = -100, y0 = -100, x1 = 10, y1 = 10 }, { x0 = 500, y0 = 500, x1 = 600, y1 = 600 } }, { x0 = -64, y0 = -64, x1 = 128, y1 = 128 })
  ok = ok and #c == 1 and c[1].x0 == -64
  ok = ok and M.cost({ { x0 = -1, y0 = 0, x1 = 33, y1 = 32 } }) == 3
  local b = M.box_tiles({ x0 = -2, y0 = -2, x1 = 3, y1 = 3 })
  ok = ok and b.x0 == -64 and b.x1 == 128
  return ok
end
local MUT = {
  { "fusion sans point fixe (une seule passe)", function(s) return (s:gsub("  while changed do\n    changed = false", "  do\n    changed = false")) end },
  { "bord commun non fusionné (touch strict)", function(s) return (s:gsub("return a%.x0 <= b%.x1 and b%.x0 <= a%.x1 and a%.y0 <= b%.y1 and b%.y0 <= a%.y1", "return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1")) end },
  { "marge ignorée", function(s) return (s:gsub("  marge = marge or 0\n", "  marge = 0\n")) end },
  { "clip sans rognage du bord bas", function(s) return (s:gsub("x0 = math%.max%(r%.x0, box%.x0%)", "x0 = r.x0")) end },
  { "cost : chunks comptés sur une tuile de moins", function(s) return (s:gsub("math%.floor%(%(r%.x1 %- 1%) / c%) %- math%.floor%(r%.x0 / c%) %+ 1", "math.floor((r.x1 - 1) / c) - math.floor(r.x0 / c)")) end },
  { "box_tiles : borne haute non comprise", function(s) return (s:gsub("x1 = %(box%.x1 %+ 1%) %* c", "x1 = box.x1 * c")) end },
  { "fusion : la boîte englobante oublie y1", function(s) return (s:gsub("          if b%.y1 > a%.y1 then a%.y1 = b%.y1 end\n", "")) end },
  { "disjoints fusionnés quand même (touch toujours vrai)", function(s) return (s:gsub("local function touch%(a, b%)\n  return", "local function touch(a, b)\n  do return true end\n  return")) end },
}
local refused = 0
for _, m in ipairs(MUT) do
  local M = load_mut(m[2])
  if not M then
    check(false, "mutant non appliqué : " .. m[1])
  else
    local alive = survives(M)
    check(not alive, "mutant refusé : " .. m[1])
    if not alive then refused = refused + 1 end
  end
end
-- la fusion oublie y1 : détecteur dédié (chevauchement en y)
do
  local M = load_mut(MUT[7][2])
  local m = M and M.merge({ { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, { x0 = 5, y0 = 5, x1 = 8, y1 = 30 } })
  check(m and (#m ~= 1 or m[1].y1 ~= 30), "mutant « y1 oublié » visible sur un chevauchement en y")
end

print(string.format("[ZONE-EQUIPE] BILAN : %d OK, %d ECHEC(S) (%d mutants refusés sur %d)", ok_n, fail_n, refused, #MUT))
os.exit(fail_n == 0 and 0 or 1)
