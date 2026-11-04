--[[
  Lot PERIMETRE2 : banc HORS JEU de la règle pure shared/team/garde_site.lua (groupes de tourelles par site, budget, anneau de murs des
  avant-postes attaqués, usine du joueur). Lancement : lua5.2 tests/garde_site_test.lua (racine du mod). Mutants : chacun doit faire échouer
  au moins un contrôle.
]]
package.path = "./?.lua;" .. package.path
local function read_src(path) local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s end
local SRC = read_src("shared/team/garde_site.lua")
local function load_gs(src) return assert(load(src, "@shared.team.garde_site"))() end
local function near(a, b) return math.abs(a - b) < 1e-6 end
local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

local function suite(Gs)
  local fails, n = {}, 0
  local function check(c, m) n = n + 1 if not c then fails[#fails + 1] = m end end
  -- G1 taille du groupe
  check(Gs.want(nil) == 3 and Gs.want(0) == 3 and Gs.want(15) == 3 and Gs.want(16) == 4 and Gs.want(25) == 5 and Gs.want(152) == 6,
    "taille du groupe : 3 au moins, une de plus par 5 ennemis, 6 au plus")
  check(Gs.wave_live(100, 100 + 30 * 3600) and not Gs.wave_live(100, 101 + 30 * 3600) and not Gs.wave_live(nil, 5), "vague oubliée après 30 min")
  -- direction
  local nx, ny = Gs.dir({ x = 100, y = 0 }, { { x = 100, y = 40, w = 1 } }, { x = 0, y = 0 })
  check(near(nx, 0) and near(ny, 1), "direction vers la menace")
  local ox, oy = Gs.dir({ x = 100, y = 0 }, { { x = 100, y = 200, w = 1 } }, { x = 0, y = 0 })
  check(near(ox, 1) and near(oy, 0), "menace au-delà de 64 tuiles ignorée : vers l'extérieur (du QG au site)")
  local zx, zy = Gs.dir({ x = 0, y = 0 }, {}, { x = 0, y = 0 })
  check(near(zx, 0) and near(zy, -1), "site au QG sans menace : nord")
  -- emplacements : groupe serré, voisins à 7 (>= 6), tous à moins de 9 du centre du groupe
  local g, sp = Gs.spots({ x = 100, y = 0 }, 0, 1)
  check(near(g.x, 100) and near(g.y, 6), "centre du groupe à 6 tuiles du site, du côté de la menace")
  check(#sp == 7 and near(sp[1].x, 100) and near(sp[1].y, 6), "7 emplacements, le centre d'abord")
  check(near(dist(sp[2], sp[3]), 14) and near(dist(sp[1], sp[2]), 7) and near(sp[2].y, 6), "puis la paire en travers à 7 tuiles (une ligne face à la menace)")
  local minpair, maxr = 1e9, 0
  for i = 1, #sp do
    maxr = math.max(maxr, dist(sp[i], g))
    for j = i + 1, #sp do minpair = math.min(minpair, dist(sp[i], sp[j])) end
  end
  check(minpair >= 6 - 1e-9 and maxr <= 9 + 1e-9, "écart >= 6 entre emplacements, tous à 9 tuiles au plus (" .. minpair .. ", " .. maxr .. ")")
  check(Gs.accepts(g, g.x + 10, g.y) and not Gs.accepts(g, g.x + 10.1, g.y), "pose refusée au-delà de 10 tuiles du groupe")
  -- ordre de service
  local sites = { { key = "a", have = 1, want = 3, wave = 0, w = 50 }, { key = "b", have = 1, want = 4, wave = 18, w = 5 },
    { key = "c", have = 3, want = 3, wave = 40, w = 9 }, { key = "d", have = 0, want = 3, wave = 0, w = 50 } }
  local p, served, tot = Gs.pick(sites)
  check(p and p.key == "b" and served == 1 and tot == 4, "site attaqué d'abord, site servi compté")
  local p2 = Gs.pick(sites, { b = true })
  check(p2 and p2.key == "a", "repos sauté ; à poids égal, la clé")
  -- G2 budget
  local b1, s1 = Gs.budget({ granted = 500, iron = 5000, unit = 120, want = 6 })
  check(b1 == 4 and s1 == "depenses", "DEPENSES : le fer accordé seul paie (500 / 120 = 4)")
  check(Gs.budget({ granted = 500, iron = 1999, unit = 120, want = 6 }) == 0, "rien sous 2 000 de fer, même accordé")
  local b2, s2 = Gs.budget({ iron = 9000, free = 8000, unit = 120, held = 10, want = 6 })
  check(b2 == 6 and s2 == "repli", "repli : 30 % de 8 000 = 20 tourelles, 10 déjà là, 6 voulues")
  check(Gs.budget({ iron = 9000, free = 8000, unit = 120, held = 19, want = 6 }) == 1, "repli : moins les tourelles déjà posées")
  check(Gs.budget({ granted = 0, iron = 9000, free = 8000, unit = 120, want = 6 }) == 0, "DEPENSES présent sans accord : rien (pas de double compte)")
  check(Gs.budget({ iron = 9000, free = 8000, unit = 0, want = 6 }) == 0, "coût inconnu : rien")
  local wt = Gs.want_table("fer", 3, 120, "pierre", 50)
  check(wt.fer == 360 and wt.pierre == 500, "demande écrite : fer des tourelles, pierre des murs")
  -- G3 anneau
  local r = Gs.ring({ x0 = 0, y0 = 0, x1 = 9, y1 = 9 }, { x = 5, y = -100 })
  local cnt = 0
  for _, s in ipairs(r.order) do cnt = cnt + #r.runs[s] end
  check(r.gate == "n" and r.box[1] == -4 and r.box[3] == 13, "anneau à 3 tuiles des bâtiments, porte au nord (vers le QG)")
  check(cnt == 4 * 17 - 3, "anneau fermé moins la porte de 3 tuiles (" .. cnt .. ")")
  local gate_hole = true
  for _, t in ipairs(r.runs.n) do if t.ty == -4 and t.tx >= 3 and t.tx <= 5 then gate_hole = false end end
  check(gate_hole, "porte au milieu du côté nord")
  local claimed = {}
  local seg = Gs.next_segment(r, claimed, 40)
  check(seg and seg.side == "n" and #seg.walls == 15, "segment 1 : le côté nord (18 tuiles) sans la porte (3)")
  for _, w in ipairs(seg.walls) do claimed[Gs.tkey(w.tx, w.ty)] = true end
  local seg2 = Gs.next_segment(r, claimed, 10, function(tx, ty) return ty == 0 end)
  local refused = false
  for _, w in ipairs(seg2 and seg2.walls or {}) do if w.ty == 0 then refused = true end end
  check(seg2 and seg2.side == "e" and #seg2.walls == 10 and not refused, "segment 2 : côté est, au plus le plafond, tuiles refusées sautées")
  local s3, why3 = Gs.next_segment(r, claimed, 5)
  check(s3 == nil and why3 == "stock", "plafond sous 8 tuiles : attente de stock")
  -- usine du joueur
  check(Gs.in_player_zone(10, 10, { { x0 = 15, y0 = 15, x1 = 17, y1 = 17 } }) and not Gs.in_player_zone(8, 10, { { x0 = 15, y0 = 15, x1 = 17, y1 = 17 } }),
    "usine du joueur : 6 tuiles autour de ses bâtiments")
  return fails, n
end

local fails, total = suite(load_gs(SRC))
for _, m in ipairs(fails) do print("  ECHEC : " .. m) end
local passes, failures = total - #fails, #fails
local function mutate(old, new)
  local a, b = SRC:find(old, 1, true)
  if not a then return nil end
  return SRC:sub(1, a - 1) .. new .. SRC:sub(b + 1)
end
local mutants = {
  { "groupe de 2", "Gs.GROUP_MIN = 3 ", "Gs.GROUP_MIN = 2 " },
  { "groupe sans plafond", "if n > Gs.GROUP_MAX then n = Gs.GROUP_MAX end", "" },
  { "vague jamais oubliée", "return wave_tick ~= nil and tick - wave_tick <= Gs.WAVE_TICKS", "return wave_tick ~= nil" },
  { "groupe du côté du QG", "local gx, gy = site.x + Gs.GROUP_DIST * nx, site.y + Gs.GROUP_DIST * ny", "local gx, gy = site.x - Gs.GROUP_DIST * nx, site.y - Gs.GROUP_DIST * ny" },
  { "emplacements serrés à 3,5", "local a, c = i * Gs.SPOT_STEP, j * Gs.SPOT_STEP * 2", "local a, c = i * Gs.SPOT_STEP, j * Gs.SPOT_STEP" },
  { "trame sans quinconce", "if (i + j) % 2 == 0 and r2 <= Gs.SPOT_R * Gs.SPOT_R then", "if r2 <= Gs.SPOT_R * Gs.SPOT_R then" },
  { "sites attaqués pas d'abord", "if (a.wave or 0) ~= (b.wave or 0) then return (a.wave or 0) > (b.wave or 0) end", "" },
  { "repos ignoré", "elseif not pick and not (rest and rest[s.key]) then pick = s end", "elseif not pick then pick = s end" },
  { "pas de seuil de richesse", "if unit <= 0 or (s.iron or 0) < (s.rich or Gs.RICH_IRON) then return 0, \"pauvre\" end", "if unit <= 0 then return 0, \"pauvre\" end" },
  { "double compte (repli en plus de DEPENSES)", "if s.granted ~= nil then", "if s.granted ~= nil and s.granted > 0 then" },
  { "repli sans les tourelles posées", "/ (100 * unit)) - (s.held or 0)", "/ (100 * unit))" },
  { "porte murée", "if side == gside and math.abs(pos - mid) <= half then return end", "" },
  { "porte à l'opposé du QG", "gside = dx >= 0 and \"e\" or \"o\" else gside = dy >= 0 and \"s\" or \"n\" end", "gside = dx >= 0 and \"o\" or \"e\" else gside = dy >= 0 and \"n\" or \"s\" end" },
  { "anneau collé aux bâtiments", "Gs.WALL_MARGIN = 3 ", "Gs.WALL_MARGIN = 0 " },
  { "tuiles refusées murées", "if not claimed[tkey(t.tx, t.ty)] and not (skip and skip(t.tx, t.ty)) then", "if not claimed[tkey(t.tx, t.ty)] then" },
  { "segment sans plancher", "if n < math.min(#free, Gs.SEG_MIN) then return nil, \"stock\" end", "if n <= 0 then return nil, \"stock\" end" },
  { "usine du joueur collée", "Gs.PLAYER_GAP = 6 ", "Gs.PLAYER_GAP = 0 " },
}
local killed = 0
for _, m in ipairs(mutants) do
  local txt = mutate(m[2], m[3])
  if not txt then failures = failures + 1 print("  ECHEC : mutant « " .. m[1] .. " » : texte introuvable")
  else
    local ok, f = pcall(function() return (suite(load_gs(txt))) end)
    if (not ok) or #f > 0 then killed = killed + 1 passes = passes + 1 else failures = failures + 1 print("  ECHEC : mutant « " .. m[1] .. " » non détecté") end
  end
end
print(string.format("[GARDE-SITE] mutants refusés : %d sur %d", killed, #mutants))
print(string.format("[GARDE-SITE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
