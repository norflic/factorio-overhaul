--[[
  Tests hors jeu du lot PD-ESPACEMENT (D07, DC 28/10 14 h 45 : « les tourelles couvrent pas assez d'espace […] une tourelle à
  deux cases d'une autre » ; 28/10 soir : « couvrir un max de périmètre utile »).
  Usage :  lua5.2 tests/espacement_test.lua
  Partie PURE (shared/team/pose_tourelles.lua) : Pose.gap, Pose.spaced, Pose.nearest, Pose.min_gap, Pose.choose avec `gap`
  (règle d'avant sans `gap`, ensemble espacé préféré, contre un évaluateur indépendant sur 300 instances).
  Partie BRANCHEMENT (script/faction/outposts.lua, moteur factice avec collisions 2 x 2) : la pose commune (Outposts.fortify,
  Outposts.fortify_at : QG, avant-postes, front, îlots, garde de centrale) ne serre plus une tourelle contre une autre ; passe 2
  au plancher quand la place est trop petite ; tuiles réservées toujours respectées ; tourelles d'un AUTRE poste respectées ;
  déterminisme ; journal [FO-TOUR-ECART] avec sa cause ; MUTANTS refusés.
]]
package.path = "./?.lua;" .. package.path
defines = { direction = { north = 0, east = 2, south = 4, west = 6 }, inventory = { chest = 1 } }
local logs = {}
function log(s) logs[#logs + 1] = s end
package.loaded["script.faction.state"] = { own = function() end, sorted_keys = function(t) local k = {} for a in pairs(t) do k[#k + 1] = a end table.sort(k) return k end }
package.loaded["script.faction.sites"] = {}
package.loaded["script.ai3.places_qg"] = {}

local passes, failures = 0, 0
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. m) end end
local function section(n) print("== " .. n) end

local Pose = require("shared.team.pose_tourelles")
local Outposts = require("script.faction.outposts")
_G.game = { entity_prototypes = { ["gun-turret"] = { turret_range = 18 } } }

local function d(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

-- Générateur déterministe.
local seed = 4242
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648 return seed % n end

---------------------------------------------------------------------------------------------------
section("1. Pose.gap : écart voulu selon la portée")
check(Pose.gap(18) == 6, "portée 18 : 6")
check(Pose.gap(nil) == 6 and Pose.gap(0) == 6, "portée inconnue : Pose.GAP")
check(Pose.gap(12) == 4, "portée 12 : 4")
check(Pose.gap(6) == Pose.GAP_MIN, "portée 6 : jamais sous le plancher")
check(Pose.gap(100) == Pose.GAP, "portée 100 : Pose.GAP au plus")

section("2. Pose.spaced, nearest, min_gap")
local L = { { x = 0, y = 0 }, { x = 10, y = 0 } }
check(Pose.spaced(6, 0, { { x = 0, y = 0 } }, 6), "à 6 pile : espacé")
check(not Pose.spaced(5.9, 0, { { x = 0, y = 0 } }, 6), "à 5,9 : serré")
check(Pose.spaced(6 - 1 / 512, 0, { { x = 0, y = 0 } }, 6), "à 6 - 1/512 (virgule fixe du moteur) : espacé")
check(Pose.spaced(1, 1, {}, 6) and Pose.spaced(1, 1, L, nil) and Pose.spaced(1, 1, L, 0), "liste vide ou écart nul : espacé")
check(Pose.nearest(4, 0, L) == 4 and Pose.nearest(0, 0, {}) == nil, "nearest")
check(Pose.min_gap(L) == 10 and Pose.min_gap({ L[1] }) == nil, "min_gap")

---------------------------------------------------------------------------------------------------
local OFF = { { 7, 7 }, { -7, -7 }, { 7, -7 }, { -7, 7 }, { 9, 0 }, { -9, 0 }, { 0, 9 }, { 0, -9 } }
local function ring() local c = {} for i, o in ipairs(OFF) do c[i] = { x = o[1], y = o[2] } end return c end

section("3. Sans `gap` : la règle d'avant, à l'identique (400 plans aléatoires)")
do
  local same = true
  for _ = 1, 400 do
    local assets, existing = {}, {}
    for _ = 1, 1 + rnd(8) do assets[#assets + 1] = { x = rnd(41) - 20, y = rnd(41) - 20, w = 1 + rnd(9) } end
    for _ = 1, rnd(3) do existing[#existing + 1] = { x = rnd(31) - 15, y = rnd(31) - 15 } end
    local k = 1 + rnd(4)
    local a = Pose.choose({ candidates = ring(), assets = assets, range = 18, existing = existing, count = k })
    local b = Pose.choose({ candidates = ring(), assets = assets, range = 18, existing = existing, count = k, gap = 0 })
    if table.concat(a.order, ",") ~= table.concat(b.order, ",") or a.viol ~= 0 then same = false end
  end
  check(same, "gap nil ou 0 : même ordre, aucune paire serrée comptée")
  -- les 8 emplacements d'avant sont tous à l'écart l'un de l'autre : sans tourelle existante, `gap` = 6 ne change rien
  local same6 = true
  for _ = 1, 400 do
    local assets = {}
    for _ = 1, 1 + rnd(8) do assets[#assets + 1] = { x = rnd(41) - 20, y = rnd(41) - 20, w = 1 + rnd(9) } end
    local k = 1 + rnd(8)
    local a = Pose.choose({ candidates = ring(), assets = assets, range = 18, count = k })
    local b = Pose.choose({ candidates = ring(), assets = assets, range = 18, count = k, gap = 6 })
    if table.concat(a.order, ",") ~= table.concat(b.order, ",") then same6 = false end
  end
  check(same6, "8 emplacements d'avant, aucune tourelle existante : gap 6 ne change pas le choix")
  check(Pose.min_gap(ring()) > 7.2, "plus petit écart des 8 emplacements d'avant > 7,2")
end

section("4. Une tourelle déjà là : l'emplacement serré contre elle n'est plus pris (le défaut vu par le DC)")
do
  -- tourelle existante en (7,7) ; le moteur a replié l'emplacement (7,7) sur (9,7), à 2 tuiles d'elle
  local cands = ring()
  cands[1] = { x = 9, y = 7 }
  local assets = { { x = 0, y = 0, w = 9 }, { x = 20, y = 14, w = 50 } } -- gros bâtiment au sud-est : (9,7) le couvre le mieux
  local old = Pose.choose({ candidates = cands, assets = assets, range = 18, existing = { { x = 7, y = 7 } }, count = 1 })
  local new = Pose.choose({ candidates = cands, assets = assets, range = 18, existing = { { x = 7, y = 7 } }, count = 1, gap = 6 })
  check(old.order[1] == 1, "règle d'avant : (9,7), à 2 tuiles de la tourelle existante (témoin du défaut)")
  check(new.order[1] ~= 1 and new.viol == 0, "avec l'écart : un autre emplacement, aucune paire serrée")
  check(d(cands[new.order[1]], { x = 7, y = 7 }) >= 6, "la tourelle choisie est à 6 tuiles au moins de l'existante")
  check(new.order[#new.order] == 1, "l'emplacement serré passe en dernier (repli seulement)")
  -- sans bâtiment : l'ordre de repli met aussi le serré à la fin
  local nob = Pose.choose({ candidates = cands, assets = {}, range = 18, existing = { { x = 7, y = 7 } }, count = 2, gap = 6 })
  check(nob.order[1] == 2 and nob.order[#nob.order] == 1, "sans bâtiment : ordre d'avant, le serré à la fin")
end

section("5. Contre un évaluateur indépendant (300 instances) : jamais serré quand un ensemble espacé existe")
do
  local function combos(n, k, fn)
    local set = {}
    local function rec(s, depth)
      if depth > k then fn(set) return end
      for i = s, n - (k - depth) do set[depth] = i; rec(i + 1, depth + 1) end
      set[depth] = nil
    end
    rec(1, 1)
  end
  local ok_all, cover_ok = true, true
  for _ = 1, 300 do
    local cands = {}
    for _ = 1, 4 + rnd(5) do cands[#cands + 1] = { x = rnd(25) - 12, y = rnd(25) - 12 } end
    local existing = {}
    for _ = 1, rnd(3) do existing[#existing + 1] = { x = rnd(25) - 12, y = rnd(25) - 12 } end
    local assets = {}
    for _ = 1, 1 + rnd(6) do assets[#assets + 1] = { x = rnd(51) - 25, y = rnd(51) - 25, w = 1 + rnd(5) } end
    local k = 1 + rnd(3)
    if k > #cands then k = #cands end
    local r = Pose.choose({ candidates = cands, assets = assets, range = 18, existing = existing, count = k, gap = 6 })
    -- évaluateur : un ensemble de taille k sans paire serrée existe-t-il ? meilleure aire parmi eux ?
    local feasible, best = false, -1
    combos(#cands, k, function(set)
      local bad = false
      for a = 1, #set do
        for b = a + 1, #set do if d(cands[set[a]], cands[set[b]]) < 6 - 1e-9 then bad = true end end
        for _, t in ipairs(existing) do if d(cands[set[a]], t) < 6 - 1e-9 then bad = true end end
      end
      if not bad then
        feasible = true
        local pts = {}
        for _, t in ipairs(existing) do pts[#pts + 1] = t end
        local s0 = Pose.covered(assets, pts, 18)
        for _, i in ipairs(set) do pts[#pts + 1] = cands[i] end
        local s = Pose.covered(assets, pts, 18) - s0
        if s > best then best = s end
      end
    end)
    if feasible and r.viol ~= 0 then ok_all = false end
    if feasible and r.score ~= best then cover_ok = false end
  end
  check(ok_all, "un ensemble espacé existe : l'ensemble choisi n'a aucune paire serrée")
  check(cover_ok, "parmi les ensembles espacés : l'aire couverte est la meilleure (exact, force brute)")
end

---------------------------------------------------------------------------------------------------
-- Moteur factice : tourelles 2 x 2 (centres sur les coins de tuile), collision des emprises, repli en spirale comme le moteur.
local function world(opts)
  opts = opts or {}
  local turrets = {}
  for _, p in ipairs(opts.pre or {}) do
    turrets[#turrets + 1] = { name = "gun-turret", type = "ammo-turret", position = { x = p.x, y = p.y }, valid = true, pre = true }
  end
  local surface = {}
  local function free(x, y)
    for _, t in ipairs(turrets) do
      if math.abs(t.position.x - x) < 2 and math.abs(t.position.y - y) < 2 then return false end
    end
    for _, b in ipairs(opts.blocks or {}) do
      if math.abs(b.x - x) < 1.5 and math.abs(b.y - y) < 1.5 then return false end
    end
    return true
  end
  local SPIRAL = { { 0, 0 } }
  for r = 1, 4 do
    for _, v in ipairs({ { r, 0 }, { -r, 0 }, { 0, r }, { 0, -r }, { r, r }, { -r, -r }, { r, -r }, { -r, r } }) do SPIRAL[#SPIRAL + 1] = v end
  end
  surface.find_non_colliding_position = function(_, c)
    local x0, y0 = math.floor(c.x + 0.5), math.floor(c.y + 0.5)
    for _, v in ipairs(SPIRAL) do
      if free(x0 + v[1], y0 + v[2]) then return { x = x0 + v[1], y = y0 + v[2] } end
    end
    return nil
  end
  surface.find_entities_filtered = function(q)
    local is_t = q.name ~= nil
    if type(q.type) == "table" then for _, ty in ipairs(q.type) do if ty == "ammo-turret" then is_t = true end end end
    if is_t then
      local out = {}
      for _, t in ipairs(turrets) do out[#out + 1] = t end
      return out
    end
    return opts.buildings or {}
  end
  surface.create_entity = function(q)
    if not free(q.position.x, q.position.y) then return nil end
    local e = { name = q.name, type = "ammo-turret", position = { x = q.position.x, y = q.position.y }, unit_number = 2000 + #turrets,
      valid = true, get_item_count = function() return 0 end, insert = function() end }
    turrets[#turrets + 1] = e
    return e
  end
  return surface, turrets
end
local function carrier(n) local c = { n = n }
  c.get_item_count = function(name) return name == "gun-turret" and c.n or 0 end
  c.remove = function(q) if q.name == "gun-turret" then c.n = c.n - q.count end return q.count end
  return c
end
local function fac() return { force = "f1", key = "A", id = 1, turrets = {}, outposts = {}, stats = {} } end
local function new_ones(turrets) local o = {} for _, t in ipairs(turrets) do if not t.pre then o[#o + 1] = t.position end end return o end
local function all_pos(turrets) local o = {} for _, t in ipairs(turrets) do o[#o + 1] = t.position end return o end
local function last_ecart() for i = #logs, 1, -1 do if logs[i]:find("%[FO%-TOUR%-ECART%]") then return logs[i] end end end

-- Scènes réutilisées par les mutants (rendent vrai si le comportement voulu est là).
local SCENES = {}
-- A. Avant-poste qui a déjà ses 2 tourelles (7,7) et (-7,-7) ; on en pose 2 de plus (défendre d'abord, puis agrandissement) :
--    jamais à moins de 6 tuiles d'une autre.
SCENES.A = function()
  local s, turrets = world({ pre = { { x = 7, y = 7 }, { x = -7, y = -7 } },
    buildings = { { position = { x = 0, y = 0 }, type = "mining-drill", bounding_box = { left_top = { x = -1.5, y = -1.5 }, right_bottom = { x = 1.5, y = 1.5 } } } } })
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 2, carrier(5))
  return n == 2 and Pose.min_gap(all_pos(turrets)) >= 6, n, turrets
end
-- B. Garde de centrale : zone acceptée petite (disque de rayon 3 autour de (0,0)), 3 tourelles voulues, emplacements serrés :
--    la passe 1 n'en loge pas 3 à 6 tuiles, la passe 2 (plancher 3) les pose toutes, jamais collées.
SCENES.B = function()
  local s, turrets = world({})
  local sites = { { x = 3, y = 0 }, { x = 2, y = 2 }, { x = 0, y = 3 }, { x = -3, y = 0 } }
  local acc = function(p) return p.x * p.x + p.y * p.y <= 9 end
  local n = Outposts.fortify_at(fac(), s, "plant", sites, 3, carrier(3), acc)
  local g = Pose.min_gap(all_pos(turrets))
  return n == 3 and g ~= nil and g >= Pose.GAP_MIN, n, turrets
end
-- C. Front : deux tourelles d'un autre poste (QG) près de la cellule ; les nouvelles du front s'en écartent.
SCENES.C = function()
  local s, turrets = world({ pre = { { x = 6, y = 0 }, { x = 0, y = 6 } } })
  local sites = { { x = 6, y = 0 }, { x = 4, y = 4 }, { x = 0, y = 6 }, { x = -6, y = 0 }, { x = 0, y = -6 } }
  local acc = function(p) return p.x * p.x + p.y * p.y <= 100 end
  local n = Outposts.fortify_at(fac(), s, "o5", sites, 2, carrier(2), acc)
  return n == 2 and Pose.min_gap(all_pos(turrets)) >= 6, n, turrets
end

section("6. Avant-poste déjà défendu : pas de tourelle serrée contre une autre (scène A)")
do
  logs = {}
  local ok, n, turrets = SCENES.A()
  check(ok, string.format("2 posées (%d), plus petit écart >= 6 (%.1f)", n, Pose.min_gap(all_pos(turrets)) or -1))
  local l = last_ecart()
  check(l and l:find("cause") == nil and l:find(": ecart ;"), "journal [FO-TOUR-ECART] cause « ecart »")
end

section("7. Garde de centrale serrée : passe 2 au plancher, le nombre voulu reste posé (scène B)")
do
  logs = {}
  local ok, n, turrets = SCENES.B()
  check(ok, string.format("3 posées (%d), jamais collées (écart %.1f >= %g)", n, Pose.min_gap(all_pos(turrets)) or -1, Pose.GAP_MIN))
  local l = last_ecart()
  check(l and l:find(": plancher ;"), "journal [FO-TOUR-ECART] cause « plancher »")
  check(l and l:find("poste plant"), "le journal nomme le poste")
end

section("8. Place impossible même au plancher : moins posées, pas d'erreur, cause « manque »")
do
  logs = {}
  local s, turrets = world({})
  local acc = function(p) return math.abs(p.x) <= 1 and math.abs(p.y) <= 1 end
  local c = carrier(3)
  local n = Outposts.fortify_at(fac(), s, "plant", { { x = 0, y = 0 }, { x = 1, y = 0 } }, 3, c, acc)
  check(n == 1 and c.n == 2, "une seule posée, deux restent au porteur")
  local l = last_ecart()
  check(l and (l:find(": manque%-ecart ;") or l:find(": manque%-place ;")), "journal [FO-TOUR-ECART] cause « manque-... » : " .. tostring(l))
end

do
  -- deux places dans la zone, à 2 tuiles l'une de l'autre : la seconde est refusée pour l'écart (jamais collées)
  logs = {}
  local s, turrets = world({})
  local n = Outposts.fortify_at(fac(), s, "o2", { { x = 0, y = 0 }, { x = 2, y = 0 } }, 2, carrier(2),
    function(p) return math.abs(p.y) < 0.5 and p.x >= 0 and p.x <= 2 end)
  local l = last_ecart()
  check(n == 1 and l and l:find(": manque%-ecart ;"), "places à 2 tuiles : une seule posée, cause « manque-ecart »")
end

section("9. Front : les tourelles d'un AUTRE poste comptent (scène C)")
do
  local ok, n, turrets = SCENES.C()
  check(ok, string.format("2 posées (%d), écart >= 6 avec celles du QG (%.1f)", n, Pose.min_gap(all_pos(turrets)) or -1))
end

section("10. Tuiles réservées du plan : toujours respectées (passe 1 et passe 2)")
do
  local s, turrets = world({})
  local save = Outposts.reserved
  Outposts.reserved = function(_, _, q) return q.x > 0 end -- tout l'est réservé (tapis planifiés)
  local n = Outposts.fortify_at(fac(), s, "o1", { { x = 3, y = 0 }, { x = 6, y = 0 }, { x = -3, y = 0 }, { x = -3, y = 3 } }, 3, carrier(3),
    function(p) return p.x * p.x + p.y * p.y <= 100 end)
  Outposts.reserved = save
  local bad = false
  for _, p in ipairs(new_ones(turrets)) do if p.x > 0 then bad = true end end
  check(n >= 1 and not bad, string.format("%d posée(s), aucune sur une tuile réservée", n))
end

section("11. Déterminisme : deux poses identiques, mêmes positions")
do
  local _, _, t1 = SCENES.A()
  local _, _, t2 = SCENES.A()
  local a, b = {}, {}
  for _, p in ipairs(all_pos(t1)) do a[#a + 1] = p.x .. ":" .. p.y end
  for _, p in ipairs(all_pos(t2)) do b[#b + 1] = p.x .. ":" .. p.y end
  check(table.concat(a, ",") == table.concat(b, ","), "mêmes positions")
end

section("12. Journal borné : Outposts.ECART_LOGS lignes au plus par équipe")
do
  logs = {}
  local f = fac()
  for _ = 1, Outposts.ECART_LOGS + 5 do
    local s = world({})
    Outposts.fortify_at(f, s, "o1", { { x = 0, y = 0 } }, 1, carrier(1))
  end
  local k = 0
  for _, l in ipairs(logs) do if l:find("%[FO%-TOUR%-ECART%]") then k = k + 1 end end
  check(k == Outposts.ECART_LOGS, "lignes " .. k)
end

section("13. Règle pure : pas de pairs, pas de nom d'objet du jeu")
do
  local fh = io.open("shared/team/pose_tourelles.lua", "r")
  local src = fh:read("*a"); fh:close()
  local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find("[^i]pairs%("), "aucun pairs")
  check(not code:find("gun%-turret") and not code:find("\"[%w]+%-[%w%-]+\""), "aucun nom d'objet")
end

section("14. MUTANTS (chacun doit faire échouer une scène)")
do
  local function all_ok() return SCENES.A() and SCENES.B() and SCENES.C() end
  check(all_ok(), "témoin : les trois scènes passent")
  local G, GM = Pose.GAP, Pose.GAP_MIN
  -- M1 : aucun écart (comportement d'avant le lot)
  Pose.GAP, Pose.GAP_MIN = 0, 0
  check(not all_ok(), "M1 écart nul refusé")
  Pose.GAP, Pose.GAP_MIN = G, GM
  -- M2 : pas de seconde passe (plancher = écart voulu)
  Pose.GAP_MIN = 6
  check(not SCENES.B(), "M2 sans passe au plancher refusé")
  Pose.GAP_MIN = GM
  -- M3 : spaced toujours vrai
  local sp = Pose.spaced
  Pose.spaced = function() return true end
  check(not all_ok(), "M3 contrôle d'écart inerte refusé")
  Pose.spaced = sp
  -- M4 : tourelles des autres postes ignorées
  local tn = Outposts.turrets_near
  Outposts.turrets_near = function() return {} end
  check(not SCENES.C(), "M4 tourelles existantes ignorées refusé")
  Outposts.turrets_near = tn
  check(all_ok(), "témoin rétabli")
end

print(string.format("[ESPACEMENT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
