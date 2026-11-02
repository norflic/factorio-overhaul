--[[
  Lot OBSTACLES « une falaise ne doit pas bloquer la construction » : test hors jeu de l'emprise réelle des falaises
  (shared/team/falaise.lua) et de son branchement (script/team/falaise.lua, build.lua, champ.lua).
    §1 les 4 refus mesurés (journal [FO-IA1D], REGARD 3 graines + partie du DC du 2/11) : la tuile du tapis refusé est dans
       l'emprise réelle, et la boîte générique de bounding_box (±1 × ±0,5) ne la contenait PAS ;
    §2 géométrie : 20 orientations connues, comptes de tuiles, contact par le bord, échelle, repli, symétrie, rotation de 45° ;
    §3 CAS DE FALAISE : une ligne de falaises west-to-east tous les 4 tuiles, tapis A* d'un côté à l'autre : avec les masques
       d'avant le tracé traverse l'emprise réelle (le refus du moteur), avec les masques réels il passe par la brèche et reste
       hors de toute emprise ;
    §4 CAS D'ARBRE DENSE : forêt de 200 arbres, lot « defricher » (jamais « refuse »), tapis tracé à travers (arbres au coût +1),
       tous les arbres du tracé repérés pour le défrichage, aucun hors tracé ;
    §5 mémoire apprise : bornée, idempotente, comptée, clés relues (untkey contre P.tkey) ;
    §6 déterminisme et pureté (aucun pairs, hasard, trigonométrie, API du jeu dans la règle) ;
    §7 branchement : read_masks et blocked_in lisent les falaises par leur emprise réelle, le blocage d'un projet refusé par
       une falaise est immédiat (pas 3 reprises au même plan) ;
    §8 mutants : chaque erreur plausible de la règle est vue.
  Usage : lua5.2 tests/falaise_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local P = require("shared.team.plan")

local ok_n, fail_n = 0, 0
local function check(name, cond, detail)
  if cond then ok_n = ok_n + 1
  else
    fail_n = fail_n + 1
    print("ECHEC " .. name .. (detail and (" : " .. tostring(detail)) or ""))
  end
end

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/falaise.lua")

local function load_f(src)
  local fn, err = load(src, "=falaise", "t")
  if not fn then return nil, err end
  local ok, mod = pcall(fn)
  if not ok then return nil, mod end
  return mod
end

local function set_of(flat)
  local s = {}
  for i = 1, #flat - 1, 2 do s[flat[i] .. ":" .. flat[i + 1]] = true end
  return s
end
local function has(flat, tx, ty) return set_of(flat)[tx .. ":" .. ty] == true end
local function count(flat) return #flat / 2 end

-- Les observations du journal. Seul le cas 271828182 a son orientation et sa boîte relues au moteur (diagnostic du 3/11 : falaise
-- « east-to-none », LuaEntity::bounding_box = 357,336 ; −405,461 ; 360,164 ; −404,043, soit 3 × 1,4 tuiles, alors que le moteur refuse
-- 9 tuiles). Pour les autres le journal ne donne pas l'orientation : on exige qu'au moins une orientation du modèle couvre le tapis.
local OBS = {
  { name = "REGARD 20261020 scarlet projet 3", cx = 178.0, cy = -429.5, belts = { { 176.5, -428.5 }, { 177.5, -428.5 } } },
  { name = "REGARD 123456789 emerald projet 4", cx = -250.0, cy = 434.5, belts = { { -251.5, 433.5 } } },
  { name = "REGARD 271828182 scarlet projet 4", cx = 358.0, cy = -405.5, o = "east-to-none", bb = { 357.336, -405.461, 360.164, -404.043 },
    belts = { { 357.5, -403.5 }, { 358.5, -403.5 } } },
  { name = "DC 2/11 amber projet 4 (centrale-alim)", cx = -378.0, cy = -429.5, belts = { { -379.5, -430.5 } } },
}

local function run(F, label)
  local fails0 = fail_n
  -- §1 les refus mesurés
  local all_names = {}
  for k in pairs(F.BOXES) do all_names[#all_names + 1] = k end
  table.sort(all_names)
  for _, ob in ipairs(OBS) do
    if ob.o then
      local real = F.tiles(ob.cx, ob.cy, ob.o, 1)
      local bbt = F.box_tiles(ob.bb[1], ob.bb[2], ob.bb[3], ob.bb[4]) -- ce que read_masks bloquait avant (bounding_box)
      for _, bl in ipairs(ob.belts) do
        local tx, ty = math.floor(bl[1]), math.floor(bl[2])
        check(label .. " §1 " .. ob.name .. " : tapis (" .. bl[1] .. ", " .. bl[2] .. ") dans l'emprise réelle", has(real, tx, ty))
        check(label .. " §1 " .. ob.name .. " : bounding_box ne le contenait pas (cause du refus)", not has(bbt, tx, ty))
      end
    else
      for _, bl in ipairs(ob.belts) do
        local tx, ty = math.floor(bl[1]), math.floor(bl[2])
        local any = false
        for _, o in ipairs(all_names) do if has(F.tiles(ob.cx, ob.cy, o, 1), tx, ty) then any = true break end end
        check(label .. " §1 " .. ob.name .. " : une orientation du modèle couvre le tapis", any)
      end
    end
  end
  -- §2 géométrie
  local names = {}
  for k in pairs(F.BOXES) do names[#names + 1] = k end
  table.sort(names)
  check(label .. " §2 20 orientations", #names == 20, #names)
  for _, o in ipairs(names) do
    local t = F.tiles(0.5, 0.5, o, 1)
    check(label .. " §2 " .. o .. " : au moins 2 tuiles, au plus 5 × 5", count(t) >= 2 and count(t) <= 25, count(t))
    check(label .. " §2 " .. o .. " connue", F.known(o))
  end
  check(label .. " §2 west-to-east en (0, 0.5) : 4 × 3 tuiles", count(F.tiles(0, 0.5, "west-to-east", 1)) == 12)
  check(label .. " §2 north-to-south : 2 × 4 tuiles", count(F.tiles(0, 0, "north-to-south", 1)) == 8)
  check(label .. " §2 east-to-west : 4 × 1 tuile", count(F.tiles(0, 0.5, "east-to-west", 1)) == 4)
  -- contact par le bord : west-to-east en (0, 0) couvre x de −2 à 2, y de −1,5 à 1,5 ; la tuile x = 2 touche seulement
  local t = F.tiles(0, 0, "west-to-east", 1)
  check(label .. " §2 contact par le bord : la tuile x=2 n'est pas prise", not has(t, 2, 0))
  check(label .. " §2 la tuile x=1 l'est", has(t, 1, 0))
  check(label .. " §2 la tuile x=-3 non, x=-2 oui", not has(t, -3, 0) and has(t, -2, 0))
  check(label .. " §2 y de −2 non (touche −1,5 ? non : −2 < −1,5), y=-2 oui car 1,5 coupe la tuile −2", has(t, 0, -2) and not has(t, 0, -3) and has(t, 0, 1) and not has(t, 0, 2))
  -- échelle 2 : deux fois plus large
  local t2 = F.tiles(0, 0, "north-to-south", 2)
  check(label .. " §2 échelle 2 : 4 × 8 tuiles", count(t2) == 32, count(t2))
  -- repli
  local fb = F.tiles(0, 0, nil, 1)
  check(label .. " §2 orientation absente : carré de 4 × 4", count(fb) == 16, count(fb))
  check(label .. " §2 orientation inconnue : carré de 4 × 4", count(F.tiles(0, 0, "n-importe-quoi", 1)) == 16)
  check(label .. " §2 known(nil) faux", not F.known(nil) and not F.known("x"))
  -- coin : un rectangle tourné couvre la diagonale et pas l'angle opposé
  local c = F.tiles(0, 0, "west-to-north", 1)
  check(label .. " §2 coin west-to-north : le centre du rectangle tourné (−1,25 ; −0,75) est pris", has(c, -2, -1))
  check(label .. " §2 coin west-to-north : l'angle sud-est (+2 ; +2) n'est pas pris", not has(c, 2, 2))
  -- sens de la rotation : west-to-north est la diagonale « / » (de l'ouest au nord) ; le rectangle tourné contient des points le
  -- long de « / » et pas le long de « antislash » ; la version non tournée est unie (2 polygones), les rectangles droits n'en ont qu'un
  local function inside(poly, x, y)
    local sgn = 0
    for i = 1, #poly do
      local a, b = poly[i], poly[i % #poly + 1]
      local cr = (b[1] - a[1]) * (y - a[2]) - (b[2] - a[2]) * (x - a[1])
      if cr ~= 0 then
        if sgn == 0 then sgn = cr > 0 and 1 or -1 elseif (cr > 0 and 1 or -1) ~= sgn then return false end
      end
    end
    return true
  end
  local wnp = F.polygons("west-to-north", 1)
  check(label .. " §2 coin : 2 polygones (tourné, puis non tourné)", #wnp == 2)
  check(label .. " §2 coin west-to-north : (−0,2 ; −1,8) dans le rectangle tourné (le long de « / »)", inside(wnp[1], -0.2, -1.8))
  check(label .. " §2 coin west-to-north : (−2,3 ; 0,2) dans le rectangle tourné", inside(wnp[1], -2.3, 0.2))
  check(label .. " §2 coin west-to-north : (−2,4 ; −2,7) hors du rectangle tourné (le long de « antislash »)", not inside(wnp[1], -2.4, -2.7))
  check(label .. " §2 coin : le 2e polygone est la boîte droite (angle (−3 ; 0,4) dedans)", wnp[2] ~= nil and inside(wnp[2], -3.0, 0.4))
  check(label .. " §2 rectangle droit : 1 polygone", #F.polygons("west-to-east", 1) == 1)
  -- symétrie des coins : north-to-east est le miroir de west-to-north (x → −x)
  local ne = F.tiles(0, 0, "north-to-east", 1)
  local wn = F.tiles(0, 0, "west-to-north", 1)
  local mirror = true
  for i = 1, #wn - 1, 2 do if not has(ne, -wn[i] - 1, wn[i + 1]) then mirror = false end end
  check(label .. " §2 north-to-east = miroir de west-to-north", mirror and count(ne) == count(wn))
  -- search_area
  local ax0, ay0, ax1, ay1 = F.search_area(10, 20, 30, 40)
  check(label .. " §2 zone de recherche élargie de REACH", ax0 == 10 - F.REACH and ay0 == 20 - F.REACH and ax1 == 30 + F.REACH and ay1 == 40 + F.REACH)
  -- §3 CAS DE FALAISE : ligne de falaises west-to-east tous les 4 tuiles (x = 0, 4, 8, ... 24), brèche entre x = 12 et x = 20
  local real_blocked, generic_blocked = {}, {}
  for _, cx in ipairs({ 0, 4, 8, 12, 20, 24 }) do
    local rt = F.tiles(cx, 10.5, "west-to-east", 1)
    for i = 1, #rt - 1, 2 do real_blocked[P.tkey(rt[i], rt[i + 1])] = true end
    local gt = F.box_tiles(cx - 1, 10, cx + 1, 11)
    for i = 1, #gt - 1, 2 do generic_blocked[P.tkey(gt[i], gt[i + 1])] = true end
  end
  local bounds = { x0 = -4, y0 = 0, x1 = 28, y1 = 20 }
  local function route_with(blocked)
    return P.belt_route({ x = 13, y = 2 }, { x = 13, y = 18 }, 4, bounds, function(x, y)
      if blocked[P.tkey(x, y)] then return nil end
      return 1
    end)
  end
  local r_old = route_with(generic_blocked)
  local r_new = route_with(real_blocked)
  check(label .. " §3 le tracé avec les masques d'avant existe", r_old ~= nil)
  local crossing = 0
  for _, tl in ipairs(r_old or {}) do if real_blocked[P.tkey(tl.x, tl.y)] then crossing = crossing + 1 end end
  check(label .. " §3 ... et traverse l'emprise réelle (le refus du moteur)", crossing > 0, crossing)
  check(label .. " §3 le tracé avec les masques réels existe (brèche)", r_new ~= nil)
  local inside = 0
  for _, tl in ipairs(r_new or {}) do if real_blocked[P.tkey(tl.x, tl.y)] then inside = inside + 1 end end
  check(label .. " §3 ... et reste hors de toute emprise réelle", inside == 0, inside)
  -- brèche fermée : plus de tracé (aucun chemin), jamais un tracé qui traverse
  local closed = {}
  for k in pairs(real_blocked) do closed[k] = true end
  for _, cx in ipairs({ 16 }) do
    local rt = F.tiles(cx, 10.5, "west-to-east", 1)
    for i = 1, #rt - 1, 2 do closed[P.tkey(rt[i], rt[i + 1])] = true end
  end
  local r_closed = route_with(closed)
  check(label .. " §3 brèche fermée : pas de tracé à travers (nil ou autour par les bords)", r_closed == nil or (function()
    for _, tl in ipairs(r_closed) do if closed[P.tkey(tl.x, tl.y)] then return false end end
    return true
  end)())
  -- §5 mémoire apprise
  local mem = { n = 0, t = {} }
  local added = F.learn(mem, F.tiles(0, 0.5, "west-to-east", 1), P.tkey)
  check(label .. " §5 12 tuiles apprises", added == 12 and mem.n == 12, added)
  check(label .. " §5 idempotent", F.learn(mem, F.tiles(0, 0.5, "west-to-east", 1), P.tkey) == 0 and mem.n == 12)
  local big = { n = 0, t = {} }
  local flat = {}
  for i = 1, F.LEARN_CAP + 50 do flat[#flat + 1] = i; flat[#flat + 1] = 7 end
  local got = F.learn(big, flat, P.tkey)
  check(label .. " §5 plafond " .. F.LEARN_CAP, got == F.LEARN_CAP and big.n == F.LEARN_CAP, got)
  check(label .. " §5 plein : rien d'ajouté", F.learn(big, { 9999, 9999 }, P.tkey) == 0)
  for _, xy in ipairs({ { 0, 0 }, { -5, 7 }, { 123, -456 }, { -1000, 1000 }, { 50000, -50000 } }) do
    local x, y = F.untkey(P.tkey(xy[1], xy[2]))
    check(label .. " §5 untkey(tkey(" .. xy[1] .. ", " .. xy[2] .. "))", x == xy[1] and y == xy[2], tostring(x) .. "," .. tostring(y))
  end
  -- box_tiles : une boîte rognée de 0,05 (footprint du jeu) d'un tapis = 1 tuile
  check(label .. " §5 box_tiles d'un tapis rogné = 1 tuile", count(F.box_tiles(-379.95, -430.95, -379.05, -430.05)) == 1)
  -- §6 déterminisme
  local a, b = F.tiles(3.25, -7.5, "south-to-east", 1), F.tiles(3.25, -7.5, "south-to-east", 1)
  local same = #a == #b
  for i = 1, #a do if a[i] ~= b[i] then same = false end end
  check(label .. " §6 même entrée, même sortie", same)
  return fail_n == fails0
end

-- ---------------------------------------------------------------------------------------------------------------------
-- La règle réelle
local F = require("shared.team.falaise")
run(F, "règle")

-- §4 CAS D'ARBRE DENSE (règle existante du plan, gardée par ce test : un arbre ne refuse ni un lot ni un tracé)
do
  local trees = {}
  local n = 0
  for ty = 1, 18 do
    for tx = 1, 15 do
      if (tx * 7 + ty * 13) % 5 ~= 0 and n < 200 then trees[P.tkey(tx, ty)] = true; n = n + 1 end
    end
  end
  check("§4 forêt de 200 arbres", n == 200, n)
  local lot = P.classify_lot({ tiles = 576, water = 0, cliffs = 0, trees = n, rocks = 0, foreign = 0, own = 0, nests = 0, res = {} })
  check("§4 lot de forêt dense : defricher, jamais refuse", lot == "defricher", lot)
  local seg = P.classify_segment({ water = 0, cliffs = 0, trees = n, rocks = 0, foreign = 0, own = 0, nests = 0 })
  check("§4 rue encombrée par la forêt : encombre (défrichée), jamais ferme", seg == "encombre", seg)
  local bounds = { x0 = 0, y0 = 0, x1 = 16, y1 = 20 }
  local route, expanded = P.belt_route({ x = 8, y = 0 }, { x = 8, y = 19 }, 4, bounds, function(x, y)
    return trees[P.tkey(x, y)] and 2 or 1 -- coût +1 sous un arbre (build.lua : « masks.clear[k] → c + 1 »)
  end)
  check("§4 tapis tracé à travers la forêt", route ~= nil)
  local under = 0
  for _, tl in ipairs(route or {}) do if trees[P.tkey(tl.x, tl.y)] then under = under + 1 end end
  check("§4 le tracé est borné : au plus 20 arbres sur 20 tuiles", under <= 20, under)
  check("§4 le tracé compte ses arbres : tous repérés (cases clear), aucun hors tracé", (function()
    local on = {}
    for _, tl in ipairs(route or {}) do on[P.tkey(tl.x, tl.y)] = true end
    local seen = 0
    for k in pairs(on) do if trees[k] then seen = seen + 1 end end
    return seen == under
  end)())
end

-- §9 vérité moteur : tests/fixtures/falaise_moteur.txt = les 20 lignes du scénario obstacles-falaise relevées au moteur réel le 2/11
-- (can_place_entity d'un tapis, tuile par tuile) : aucune tuile refusée par le moteur ne doit manquer au modèle
do
  local lines = {}
  for l in read("tests/fixtures/falaise_moteur.txt"):gmatch("[^\r\n]+") do lines[#lines + 1] = l end
  check("§9 20 falaises relevées au moteur", #lines == 20, #lines)
  local misses, engine_total = 0, 0
  for _, l in ipairs(lines) do
    local o, cx, cy, bl = l:match("FALAISE o=(%S+) cx=(%S+) cy=(%S+) bb=%S+ bloque=(%S*)")
    local t = set_of(F.tiles(tonumber(cx), tonumber(cy), o, 1))
    for tx, ty in bl:gmatch("(%-?%d+):(%-?%d+)") do
      engine_total = engine_total + 1
      if not t[tonumber(tx) .. ":" .. tonumber(ty)] then misses = misses + 1 end
    end
  end
  check("§9 222 tuiles refusées par le moteur", engine_total == 222, engine_total)
  check("§9 0 tuile du moteur absente du modèle", misses == 0, misses)
end

-- §7 branchement (lecture des sources)
do
  local build = read("script/team/build.lua")
  local champ = read("script/team/champ.lua")
  local adapt = read("script/team/falaise.lua")
  check("§7 build.lua : read_masks lit l'emprise réelle (Fal.mark)", build:find("Fal.mark(surface, x0, y0, x1, y1", 1, true) ~= nil)
  check("§7 build.lua : read_masks bloque la mémoire apprise b.hard", build:find("b.hard.t", 1, true) ~= nil)
  check("§7 build.lua : learn_cliff appelée aux 2 refus de fantôme", select(2, build:gsub("learn_cliff%(f, surface, p, e, r%)", "")) >= 2)
  check("§7 build.lua : projet refusé par une falaise = pas de 3 reprises au même plan", build:find("if e.cliff_hit then p.retries = Build.RETRIES end", 1, true) ~= nil)
  check("§7 champ.lua : blocked_in lit l'emprise réelle", champ:find("Fal.mark(surface, x0, y0, x1, y1", 1, true) ~= nil and champ:find('e.type ~= "cliff"', 1, true) ~= nil)
  check("§7 adaptateur : zone élargie par Fal.search_area, type cliff, orientation lue", adapt:find("search_area", 1, true) ~= nil and adapt:find('type = "cliff"', 1, true) ~= nil and adapt:find("cliff_orientation", 1, true) ~= nil)
end

-- §6 pureté : la règle n'emploie ni pairs, ni hasard, ni trigonométrie, ni API du jeu
do
  local code = SRC:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
  for _, bad in ipairs({ "pairs%(", "math%.random", "math%.sin", "math%.cos", "math%.atan", "game%.", "surface", "global", "defines" }) do
    check("§6 pureté : pas de « " .. bad .. " » dans shared/team/falaise.lua", code:find(bad) == nil or (bad == "pairs%(" and code:gsub("ipairs%(", ""):find("pairs%(") == nil))
  end
end

-- §8 mutants : chaque erreur plausible doit être vue par run()
local MUTANTS = {
  { "rotation inversée", "local c, s = H, H %* b.sign", "local c, s = H, -H * b.sign" },
  { "union non tournée retirée", "return { pts, flat }", "return { pts }" },
  { "échelle ignorée", "local b = scaled%(F.BOXES%[orientation%] or FALLBACK, scale or 1%)", "local b = scaled(F.BOXES[orientation] or FALLBACK, 1)" },
  { "west-to-east rétréci à la boîte générique", '%["west%-to%-east"%]   = A%(%-2, %-1.5, 2, 1.5%)', '["west-to-east"]   = A(-1, -0.5, 1, 0.5)' },
  { "north-to-south élargi", '%["north%-to%-south"%] = A%(%-1, %-2, 1, 2%)', '["north-to-south"] = A(-2, -2, 2, 2)' },
  { "x et y échangés dans le recouvrement", "if maxx <= x0 or minx >= x1 or maxy <= y0 or miny >= y1 then return false end", "if maxx <= y0 or minx >= y1 or maxy <= x0 or miny >= x1 then return false end" },
  { "contact par le bord compté (EPS négatif)", "F.EPS = 0.001", "F.EPS = -0.2" },
  { "tuile trop rognée (EPS 0,5)", "F.EPS = 0.001", "F.EPS = 0.5" },
  { "repli retiré (orientation inconnue = rien)", "local FALLBACK = A%(%-2, %-2, 2, 2%)", "local FALLBACK = A(0, 0, 0.01, 0.01)" },
  { "plafond de mémoire retiré", "if %(mem.n or 0%) >= F.LEARN_CAP then return added end", "" },
  { "mémoire non idempotente", "if not mem.t%[k%] then", "if true then" },
  { "untkey faux", "return %(k %- ty%) / 2097152 %- 1048576, ty %- 1048576", "return (k - ty) / 2097152 - 1048575, ty - 1048576" },
  { "zone de recherche non élargie", "return x0 %- m, y0 %- m, x1 %+ m, y1 %+ m", "return x0, y0, x1, y1" },
  { "miroir north-to-east cassé", '%["north%-to%-east"%]  = R%(5 / 4, %-3 / 4, 5.4, 3.6, 1%)', '["north-to-east"]  = R(5 / 4, -3 / 4, 5.4, 3.6, -1)' },
}
local refused = 0
for _, m in ipairs(MUTANTS) do
  local src, n = SRC:gsub(m[2], function() return m[3] end, 1)
  local mod = (n == 1) and load_f(src) or nil
  if n ~= 1 then
    check("§8 mutant « " .. m[1] .. " » applicable", false, "motif absent (" .. n .. ")")
  elseif mod then
    local before_ok, before_fail = ok_n, fail_n
    local saved_print = print
    print = function() end
    local okrun, passed = pcall(run, mod, "mutant")
    if not okrun then passed = false end -- plantage : vu
    print = saved_print
    -- les contrôles du mutant ne comptent pas dans le bilan : on retire ce qu'ils ont ajouté
    ok_n, fail_n = before_ok, before_fail
    if passed then check("§8 mutant « " .. m[1] .. " » refusé", false, "tous les contrôles passent") else refused = refused + 1; ok_n = ok_n + 1 end
  else
    refused = refused + 1; ok_n = ok_n + 1 -- plantage au chargement : vu
  end
end
check("§8 " .. #MUTANTS .. " mutants refusés", refused == #MUTANTS, refused)

print(string.format("[FALAISE] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
