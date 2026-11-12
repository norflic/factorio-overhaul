--[[
  Lot NAV2 (3/11) : test hors jeu de shared/team/acces_champ.lua (point d'accès d'un avant-poste atteignable depuis l'extérieur).
    §1 règle : accès ouvert gardé ; poche fermée (emprises, eau) : tuile atteignable la plus proche, départage fixe ; accès recouvert ;
       contact en diagonale = fermé (modèle prudent) ; garde-fous ;
    §2 champ du banc nav2-marge (moteur réel, carte relevée au tick 119 : 45 foreuses, 45 coffres) : le but y est dans une poche, la
       règle le sort du champ ;
    §3 câblage dans script/team/worker.lua et interrupteur de banc ; §4 mutants ; §5 aucun nom d'objet dans le module.
  Usage : lua5.2 tests/acces_champ_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/acces_champ.lua")
local function load_a(src)
  local fn = load(src, "=acces", "t")
  if not fn then return nil end
  local ok, m = pcall(fn)
  return ok and m or nil
end

local ok_n, bad = 0, 0
local function check(name, cond)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[ACCES] ECHEC : " .. name) end
end

-- Carte du banc nav2-marge (fo-logs/2026-11-03_NAV2/marge-1, [FO-NAV2-MARGE] carte 01 à 23) : '#' centre de tuile bloqué pour le
-- corps, '.' libre, 'G' le but (tuile recouverte : le but libre du moteur est un coin entre emprises, (53.0, 7.0)).
local MAP = {
  "............#..........", "............##.........", "........#.#.##.........", "........#####.#.#......",
  "........##########.....", ".....#.#.#.########.#..", ".....########.#.#.####.", ".....########.########.",
  ".....#.#.#.#.######.#..", "...#.#################.", "...##############.####.", "...########G##..######.",
  ".....#############.##..", ".....##########.###....", ".....################..", ".....###############...",
  ".......##########.###..", ".......#############...", "........#.#######......", "...........##..........",
  ".......................", ".......................", ".......................",
}
local function map_tiles()
  local t = {}
  for r, row in ipairs(MAP) do
    for col = 1, #row do
      local ch = row:sub(col, col)
      if ch == "#" or ch == "G" then t[#t + 1] = { x = col - 12, y = r - 12 } end
    end
  end
  return t
end
local function map_at(x, y)
  local row = MAP[y + 12]
  return row and row:sub(x + 12, x + 12) or nil
end

local function suite(A)
  local res = {}
  local function c(name, cond) res[#res + 1] = { name, cond and true or false } end
  local function at(r, x, y) return r and math.abs(r.x - x) < 1e-9 and math.abs(r.y - y) < 1e-9 end
  -- §1
  local rr = A.rect({ { 2.3, 2.3, 3.7, 3.7 } }, { x = 0, y = 0 }, 3)
  c("rectangle : emprises et point, elargi de la marge", rr[1] == -3 and rr[2] == -3 and rr[3] == 6 and rr[4] == 6)
  local r = A.reach({ { 5.3, 5.3, 6.7, 6.7 } }, {}, { x = 0.5, y = 0.5 }, { -3, -3, 10, 10 })
  c("acces ouvert garde", r.moved == false and r.enclosed == false and at(r, 0.5, 0.5) and r.reached > 0)
  local ring = {}
  for x = -1, 1 do for y = -1, 1 do if x ~= 0 or y ~= 0 then ring[#ring + 1] = { x + 0.2, y + 0.2, x + 0.8, y + 0.8 } end end end
  r = A.reach(ring, {}, { x = 0.5, y = 0.5 }, { -4, -4, 4, 4 })
  c("poche fermee par des emprises : but deplace hors de la poche (depart : y puis x)", r.moved and r.enclosed and at(r, 0.5, -1.5))
  local plus = { { 1.1, 0.1, 1.9, 0.9 }, { -0.9, 0.1, -0.1, 0.9 }, { 0.1, 1.1, 0.9, 1.9 }, { 0.1, -0.9, 0.9, -0.1 } }
  r = A.reach(plus, {}, { x = 0.5, y = 0.5 }, { -4, -4, 4, 4 })
  c("contact en diagonale seulement : ferme (modele prudent), tuile en coin choisie", r.moved and at(r, -0.5, -0.5))
  r = A.reach({ { 0.15, 0.15, 0.85, 0.85 } }, {}, { x = 0.5, y = 0.5 }, { -4, -4, 4, 4 })
  c("acces recouvert par une emprise : tuile voisine", r.moved and at(r, 0.5, -0.5))
  r = A.reach({ { 0, 0, 1, 1 } }, {}, { x = 1.5, y = 0.5 }, { -4, -4, 4, 4 })
  c("contact par le bord : la tuile voisine reste libre (F96)", r.moved == false)
  local water = {}
  for x = -1, 1 do for y = -1, 1 do if x ~= 0 or y ~= 0 then water[#water + 1] = { x = x, y = y } end end end
  r = A.reach({}, water, { x = 0.5, y = 0.5 }, { -4, -4, 4, 4 })
  c("poche fermee par l'eau : but deplace", r.moved and at(r, 0.5, -1.5))
  r = A.reach(ring, {}, { x = 0.5, y = 0.5 }, { -1000, -1000, 1000, 1000 })
  c("rectangle trop grand : acces tel quel", r.moved == false and at(r, 0.5, 0.5))
  local all = {}
  for x = -2, 2 do for y = -2, 2 do if x ~= 0 or y ~= 0 then all[#all + 1] = { x = x, y = y } end end end
  r = A.reach({}, all, { x = 0.5, y = 0.5 }, { -2, -2, 2, 2 })
  c("aucune tuile atteignable : acces tel quel, ferme", r.moved == false and r.enclosed == true and r.reached == 0)
  -- §2 champ du banc
  local tiles = map_tiles()
  r = A.reach({}, tiles, { x = 0.0, y = 0.0 }, { -11, -11, 11, 11 })
  local tx, ty = r.x and math.floor(r.x), r.y and math.floor(r.y)
  c("champ du banc : le but est dans une poche, il est deplace", r.moved and r.enclosed)
  c("champ du banc : la tuile choisie est libre", map_at(tx, ty) == ".")
  local d = math.sqrt(r.x * r.x + r.y * r.y)
  c("champ du banc : a moins de 9 tuiles du but (au bord du champ)", d <= 9)
  local r2 = A.reach({}, tiles, { x = 0.0, y = 0.0 }, { -11, -11, 11, 11 })
  c("deterministe", r2.x == r.x and r2.y == r.y and r2.reached == r.reached)
  res.field = r
  -- Suite NAV2 : champ passé à l'électrique. Les listes de l'avant-poste n'ont plus qu'une paire (à 2 tuiles de l'accès) ; le champ de
  -- l'équipe (anneau d'emprises de rayon 4 autour de l'accès) n'y est pas. Rectangle des seules listes : son bord tombe DANS l'anneau,
  -- la poche n'est pas vue ; rectangle des bâtiments de l'équipe : vue.
  local own = { { 2.1, 0.1, 2.9, 0.9 } }
  local fieldb = {}
  for x = -4, 4 do for y = -4, 4 do
    if math.max(math.abs(x), math.abs(y)) == 4 then fieldb[#fieldb + 1] = { x + 0.1, y + 0.1, x + 0.9, y + 0.9 } end
  end end
  local allb = {}
  for _, b in ipairs(own) do allb[#allb + 1] = b end
  for _, b in ipairs(fieldb) do allb[#allb + 1] = b end
  local small = A.rect(own, { x = 0.5, y = 0.5 }, A.MARGIN)
  local rs = A.reach(allb, {}, { x = 0.5, y = 0.5 }, small)
  c("champ electrique, rectangle des seules listes : poche non vue (le defaut corrige)", rs.moved == false)
  local big = A.rect(allb, { x = 0.5, y = 0.5 }, A.MARGIN)
  local rb = A.reach(allb, {}, { x = 0.5, y = 0.5 }, big)
  c("champ electrique, rectangle des batiments de l'equipe : but hors de l'anneau", rb.moved and math.max(math.abs(math.floor(rb.x)), math.abs(math.floor(rb.y))) >= 5)
  return res
end

local A0 = assert(load_a(SRC), "module illisible")
local base = suite(A0)
for _, r in ipairs(base) do check(r[1], r[2]) end
if base.field then
  print(string.format("[ACCES] champ du banc : but (0,0) deplace en (%.1f, %.1f), %.1f tuile(s), %d tuile(s) atteignable(s)",
    base.field.x, base.field.y, math.sqrt(base.field.x ^ 2 + base.field.y ^ 2), base.field.reached))
end

-- §3 câblage
local W = read("script/team/worker.lua")
check("worker charge la regle", W:find('require("shared.team.acces_champ")', 1, true) ~= nil)
check("acces(o, f) appelle la regle avec le rectangle", W:find("Acc.reach(boxes, tiles, base, rect)", 1, true) ~= nil
  and W:find("Acc.rect(own_boxes, base, Acc.MARGIN)", 1, true) ~= nil)
local n_calls = select(2, W:gsub("local function access%(o, f%)", ""):gsub("access%(o, f%)", ""))
-- (AUTO-FINANCEMENT, 72e21264 : sixième marche, l'agrandissement autofinancé qui prend ses plaques aux fours de l'avant-poste)
check("les 6 marches vers un avant-poste (agrandir, autofinancement, garder, tournee, recharger, fortifier) passent par la regle", n_calls == 6)
check("plus aucun access(o) sans equipe", W:gsub("access%(o, f%)", ""):find("access%(o%)") == nil)
check("obstacles : masque du corps, eau, types mobiles exclus", W:find('collision_mask = "player-layer"', 1, true) ~= nil
  and W:find('collision_mask = "water-tile"', 1, true) ~= nil and W:find("not ACC_MOVING[e.type]", 1, true) ~= nil)
check("interrupteur (regle coupee : 0.6.42)", W:find("f.team.acces_off", 1, true) ~= nil)
check("journal [FO-NAV-ACCES]", W:find("[FO-NAV-ACCES]", 1, true) ~= nil)
check("rectangle : batiments de l'equipe a FIELD_RADIUS du centre", W:find("radius = Acc.FIELD_RADIUS, force = own[1].force", 1, true) ~= nil)
check("FIELD_RADIUS = rayon d'agrandissement", (function()
  local P = dofile("shared/team/pose_paires.lua")
  return A0.FIELD_RADIUS == P.EXTEND_RADIUS
end)())
check("porte exclue des obstacles (le pathfinder la traverse)", W:find("gate = true", 1, true) ~= nil)
check("diagnostic [FO-NAV-FORTIFY] (8 lignes par equipe)", W:find("[FO-NAV-FORTIFY]", 1, true) ~= nil and W:find("(f.stats.nav_fort or 0) < 8", 1, true) ~= nil)
check("interface de banc set_regle_acces", read("script/team/ia1_remote.lua"):find("set_regle_acces = function(key, on)", 1, true) ~= nil)

-- §4 mutants
local MUTANTS = {
  { "8-voisinage", "local DIRS = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }", "local DIRS = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 }, { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 } }" },
  { "tuiles bloquees traversees", "if seen[k] or blocked[k] then return end", "if seen[k] then return end" },
  { "eau ignoree", "for _, t in ipairs(tiles or {}) do", "for _, t in ipairs({}) do" },
  { "departage inverse", "(c[2] < best[2] or (c[2] == best[2] and c[1] < best[1]))", "(c[2] > best[2] or (c[2] == best[2] and c[1] > best[1]))" },
  { "poche laissee telle quelle", "if not best then return", "if true then return" },
  { "acces libre pris pour atteint", "if seen[key(ax, ay)] then", "if not blocked[key(ax, ay)] then" },
  { "garde-fou du rectangle absent", "x1 - x0 > A.MAX_SIDE or y1 - y0 > A.MAX_SIDE", "false" },
  { "marge du rectangle oubliee", "math.floor(lx) - margin, math.floor(ty) - margin, math.ceil(rx) - 1 + margin, math.ceil(by) - 1 + margin",
    "math.floor(lx), math.floor(ty), math.ceil(rx) - 1, math.ceil(by) - 1" },
  { "centre de tuile oublie", "return { x = best[1] + 0.5, y = best[2] + 0.5, moved = true", "return { x = best[1], y = best[2], moved = true" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif absent)"
  else
    local mod = load_a(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    local seen = mod == nil
    if not seen then
      local ok, res = pcall(suite, mod)
      if not ok then seen = true else for _, r in ipairs(res) do if not r[2] then seen = true break end end end
    end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, #MUTANTS, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""), refused == #MUTANTS)

-- §5 aucun nom d'objet du jeu dans le module (commentaires exclus)
local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
local names = { "coal", "stone", "iron", "copper", "chest", "furnace", "drill", "plate", "ore", "character", "water", "player" }
local found = {}
for _, n in ipairs(names) do if code:find(n, 1, true) then found[#found + 1] = n end end
check("aucun nom d'objet dans le module" .. (#found > 0 and (" : " .. table.concat(found, ",")) or ""), #found == 0)

print(string.format("[ACCES] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
