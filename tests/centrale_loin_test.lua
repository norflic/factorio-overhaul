--[[
  Tests hors jeu de la CENTRALE LOINTAINE (lot PD-CENTRALE, décision du DC D-24 (1) : étang garanti supprimé, centrale à
  l'eau la plus proche atteignable reliée par une ligne de poteaux).
  Usage, depuis la racine du mod :   lua5.2 tests/centrale_loin_test.lua

    1. règles pures (shared/team/centrale_loin.lua) : rives (profondeur de 2 tuiles, mare refusée, ordre, écart, filtre),
       secteurs (ordre, épuisés, distance), carré d'essai hors du treillis, carrefour de bord, point d'appui ;
    2. ligne de 300 tuiles par shared/team/poteaux.lua : le budget du lot la trouve, le budget par défaut la refuse
       (« couloir trop grand ») ; une rivière plus étroite que la portée est enjambée ; un lac est contourné ;
    3. partie moteur (script/team/centrale_loin.lua) sur un moteur SIMULÉ minimal (tuiles d'eau, chunks générés) et le VRAI
       gabarit de la centrale (M.GEN.steam) : la centrale est posée à la rive la plus proche hors du treillis ; carte de
       connaissance (eau vue, secteur à nids écarté) ; aucune eau : refus ; budget de passe : « loin » ; ligne : portée, aucune
       tuile d'eau, points d'appui à sec ; terrain non généré : génération demandée, attente ; rive écartée ; déterminisme ;
    4. build.lua : make_pond et l'étang posé par set_tiles ont disparu, la recherche lointaine est branchée pour toutes les
       équipes, l'attente « loin » est traitée ;
    5. mutants : 6 variantes fautives refusées par la même batterie.
]]

package.path = "./?.lua;" .. package.path

local P = require("shared.team.plan")
local M = require("shared.team.modules")
local Q = require("shared.team.poteaux")
local Cl = require("shared.team.centrale_loin")
local K = require("shared.ai3.carte")

local LOGS = {}
_G.log = function(s) LOGS[#LOGS + 1] = s end

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end

local function rect_water(x0, y0, x1, y1) -- tuiles [x0, x1] × [y0, y1] inclus
  return function(tx, ty) return tx >= x0 and tx <= x1 and ty >= y0 and ty <= y1 end
end

---------------------------------------------------------------------------------------------------
-- Batterie des règles pures (rejouée sur les mutants)
---------------------------------------------------------------------------------------------------
local function battery_pure(C, quiet)
  local ok = true
  local function chk(c, m) if not quiet then check(c, m) end; ok = ok and c end
  -- 1a. rives d'un lac de 10 × 10 (x 20..29, y 0..9) : la plus proche du QG (0, 0) est à l'ouest, face à l'est
  local lake = rect_water(20, 29, 0, 9)
  lake = rect_water(20, 0, 29, 9)
  local s = C.shores(lake, { x0 = 10, y0 = -5, x1 = 40, y1 = 15 }, { x = 0, y = 0 })
  chk(#s >= 4, "rives d'un lac : au moins 4 (" .. #s .. ")")
  chk(s[1] and s[1].x == 19 and s[1].dir == 2, "rive la plus proche : tuile (19, y) a l'ouest du lac, pompe vers l'est")
  local spaced = true
  for i = 1, #s do for j = i + 1, #s do
    if math.max(math.abs(s[i].x - s[j].x), math.abs(s[i].y - s[j].y)) < C.SHORE_GAP then spaced = false end
  end end
  chk(spaced, "rives espacees d'au moins SHORE_GAP")
  local sorted = true
  for i = 2, #s do if s[i].d < s[i - 1].d then sorted = false end end
  chk(sorted, "rives triees par distance au QG")
  -- 1b. une mare d'une tuile et un filet d'eau d'une tuile de large ne sont pas des rives (la pompe demande 2 tuiles devant)
  chk(#C.shores(rect_water(5, 5, 5, 5), { x0 = 0, y0 = 0, x1 = 10, y1 = 10 }, { x = 0, y = 0 }) == 0, "mare d'une tuile : aucune rive")
  chk(#C.shores(rect_water(5, -20, 5, 20), { x0 = 0, y0 = -5, x1 = 10, y1 = 5 }, { x = 0, y = 0 }) == 0, "filet d'eau d'une tuile de large : aucune rive")
  -- 1c. filtre (hors du treillis)
  local s2 = C.shores(lake, { x0 = 10, y0 = -5, x1 = 40, y1 = 15 }, { x = 0, y = 0 }, { keep = function(tx) return tx >= 25 end })
  local kept = true
  for _, r in ipairs(s2) do if r.x < 25 then kept = false end end
  chk(#s2 >= 1 and kept, "filtre : seules les rives gardees")
  -- 1d. secteurs : distance, épuisés écartés, au-delà de MAX_DIST écartés
  local list = { { key = 3, x = 300, y = 0 }, { key = 1, x = 100, y = 0 }, { key = 2, x = 0, y = 100 }, { key = 4, x = 9000, y = 0 },
    { key = 5, x = 50, y = 0 } }
  local o = C.order_sectors(list, { x = 0, y = 0 }, { [5] = true })
  chk(#o == 3 and o[1].key == 1 and o[2].key == 2 and o[3].key == 3, "secteurs : par distance puis cle, epuises et lointains ecartes")
  -- 1e. carré d'essai hors du treillis : la rive est à plus de WINDOW / 2 du carré des lots
  local ext = { x0 = -100, y0 = -100, x1 = 100, y1 = 100 }
  chk(not C.outside(ext, 0, 0) and not C.outside(ext, 100 + C.WINDOW / 2 - 1, 0) and C.outside(ext, 100 + C.WINDOW / 2, 0)
    and C.outside(ext, -100 - C.WINDOW / 2 - 1, 0), "hors du treillis : marge d'un demi-carre d'essai")
  -- 1f. carrefour de bord
  local ci, cj = C.clamp_node(3, 9, -1)
  chk(ci == 3 and cj == -1 and C.is_far(3, 9, -1) and not C.is_far(3, 3, -3), "carrefour ramene au bord du treillis")
  -- 1g. point d'appui : le plus proche, déterministe ; nil s'il n'y en a pas
  local ax, ay = C.anchor_spot(function(tx, ty) return tx >= 3 end, 0.5, 0.5, 6)
  chk(ax == 3.5 and ay == 0.5, "point d'appui : tuile libre la plus proche (" .. tostring(ax) .. ", " .. tostring(ay) .. ")")
  chk(C.anchor_spot(function() return false end, 0.5, 0.5, 4) == nil, "point d'appui : aucun, nil")
  -- 2. ligne longue : budget du lot contre budget par défaut
  local function free_dry(water) return function(x, y) return not water(math.floor(x), math.floor(y)) end end
  local a, b = { x = 300.5, y = 0.5 }, { x = 0.5, y = 0.5 }
  local opts = C.path_opts(300, 7.5)
  local chain = P.pole_chain(a, b, 7.5, false, free_dry(function() return false end), nil, opts)
  chk(chain ~= nil and #chain <= 43, "ligne de 300 tuiles en terrain libre : au plus 43 poteaux (pas entier de 7 tuiles : 42) (" .. tostring(chain and #chain) .. ")")
  -- rivière nord-sud de 5 tuiles (x 150..154) : enjambée
  local river = rect_water(150, -1000, 154, 1000)
  local c2 = Q.path(a, b, 7.5, false, free_dry(river), nil, opts)
  local dry = c2 ~= nil
  for _, p in ipairs(c2 or {}) do if river(math.floor(p.x), math.floor(p.y)) then dry = false end end
  chk(dry, "riviere de 5 tuiles enjambee, aucun poteau dans l'eau")
  -- lac de 40 × 40 sur la ligne droite : contourné
  local lake2 = rect_water(130, -20, 170, 20)
  local c3 = Q.path(a, b, 7.5, false, free_dry(lake2), nil, opts)
  local d3, why3 = Q.path(a, b, 7.5, false, free_dry(lake2), nil, nil)
  chk(d3 == nil and why3 ~= nil, "le meme contournement est refuse au budget par defaut (" .. tostring(why3) .. ") : le budget du lot est necessaire")
  local dry3, reach3 = c3 ~= nil, true
  local prev = a
  for _, p in ipairs(c3 or {}) do
    if lake2(math.floor(p.x), math.floor(p.y)) then dry3 = false end
    if (p.x - prev.x) ^ 2 + (p.y - prev.y) ^ 2 > 7.5 * 7.5 + 1e-6 then reach3 = false end
    prev = p
  end
  if c3 and (prev.x - b.x) ^ 2 + (prev.y - b.y) ^ 2 > 7.5 * 7.5 + 1e-6 then reach3 = false end
  chk(dry3 and reach3, "lac de 40 x 40 contourne, chaque maillon a portee")
  return ok
end

section("1-2. regles pures et ligne longue")
battery_pure(Cl, false)

---------------------------------------------------------------------------------------------------
-- 3. Partie moteur sur un moteur simulé minimal
---------------------------------------------------------------------------------------------------
section("3. partie moteur (moteur simule)")
package.loaded["script.team.centrale_loin"] = nil
local Far = require("script.team.centrale_loin")

local function make_surface(water, opts)
  opts = opts or {}
  local S = { requested = {}, finds = 0 }
  function S.is_chunk_generated(c)
    local cx, cy = c[1] or c.x, c[2] or c.y
    if opts.hole and opts.hole(cx, cy) and not S.requested[cx .. ":" .. cy] then return false end
    return true
  end
  function S.request_to_generate_chunks(pos, r)
    local cx, cy = math.floor(pos[1] / 32), math.floor(pos[2] / 32)
    S.requested[cx .. ":" .. cy] = true
  end
  local function each(area, fn)
    for ty = math.floor(area[1][2]), math.ceil(area[2][2]) - 1 do
      for tx = math.floor(area[1][1]), math.ceil(area[2][1]) - 1 do fn(tx, ty) end
    end
  end
  function S.find_tiles_filtered(q)
    S.finds = S.finds + 1
    local out = {}
    each(q.area, function(tx, ty) if water(tx, ty) then out[#out + 1] = { position = { x = tx, y = ty } } end end)
    return out
  end
  function S.count_tiles_filtered(q)
    local n = 0
    each(q.area, function(tx, ty) if water(tx, ty) then n = n + 1 end end)
    if q.limit and n > q.limit then n = q.limit end
    return n
  end
  return S
end

local function make_team(radius, ai3f)
  return { key = "test", build = { lat = { ox = 0, oy = 0 }, radius = radius, occ = {} }, ai3f = ai3f }
end

local function masks_reader(water)
  return function(f, surface, x0, y0, x1, y1)
    local w = {}
    for ty = y0, y1 - 1 do for tx = x0, x1 - 1 do if water(tx, ty) then w[P.tkey(tx, ty)] = true end end end
    return { water = w, blocked = {}, clear = {}, rect = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 },
      free = function(tx, ty) local k = P.tkey(tx, ty) return not w[k] and not f.build.occ[k] end }
  end
end

local G = M.GEN.steam(1)
check(G ~= nil and G.water and #G.water > 0, "gabarit reel de la centrale (avec sa pompe de rive)")

-- Lac à l'est, hors du treillis de rayon 2 (lots de -2 à 2 : x de -68 à 80) ; un autre plus loin à l'ouest.
local east = rect_water(230, -30, 290, 30)
local west = rect_water(-400, -30, -340, 30)
local function both(tx, ty) return east(tx, ty) or west(tx, ty) end

local function place_once(water, team, surface, tick)
  local main, why, wait
  for _ = 1, 40 do
    main, why, wait = Far.place(team, surface, G, { read_masks = masks_reader(water), tick = tick or 0, why = "pas de lot" })
    if main or wait ~= "loin" then break end
  end
  return main, why, wait
end

LOGS = {}
local f1 = make_team(2)
local s1 = make_surface(both)
local m1, w1 = place_once(both, f1, s1)
check(m1 ~= nil, "centrale posee hors du treillis (" .. tostring(w1) .. ")")
if m1 then
  check(m1.far and m1.far.x == 229, "rive la plus proche : bord ouest du lac de l'est (x = 229 ; " .. tostring(m1.far and m1.far.x) .. ")")
  check(m1.lot == nil and m1.inst and #m1.inst.entities > 0, "placement sans lot, entites instanciees")
  local wet_pump = false
  for _, e in ipairs(m1.inst.entities) do
    if e.name == "offshore-pump" then
      local v = ({ [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } })[e.direction or 0]
      wet_pump = east(math.floor(e.position.x) + v[1], math.floor(e.position.y) + v[2])
    end
  end
  check(wet_pump, "la pompe de rive regarde l'eau")
  local dry = true
  for _, e in ipairs(m1.inst.entities) do
    if e.name ~= "offshore-pump" and east(math.floor(e.position.x), math.floor(e.position.y)) then dry = false end
  end
  check(dry, "aucune autre entite de la centrale sur l'eau")
end
local found_log = false
for _, l in ipairs(LOGS) do if l:find("^%[FO%-CENTRALE%-LOIN%] test : centrale posee a la rive") then found_log = true end end
check(found_log, "journal [FO-CENTRALE-LOIN] de la pose")

-- déterminisme
local m1b = place_once(both, make_team(2), make_surface(both))
check(m1 and m1b and m1.ox == m1b.ox and m1.oy == m1b.oy and m1.k == m1b.k, "deux recherches identiques : meme placement")

-- rive écartée : la recherche suivante prend une autre rive
if m1 then
  local p = { id = 7, far = m1.far }
  check(Far.reject(f1, p, "pompe refusee") == true, "rive ecartee")
  local m2 = place_once(both, f1, s1)
  check(m2 and m2.far and m2.far.key ~= m1.far.key, "apres l'ecart : une autre rive (" .. tostring(m2 and m2.far and m2.far.key) .. ")")
end

-- aucune eau : refus (pas d'attente infinie), journal
LOGS = {}
local none = function() return false end
local m0, why0, wait0 = place_once(none, make_team(2), make_surface(none))
check(m0 == nil and wait0 == nil and why0 == "pas d'eau atteignable", "aucune eau : centrale refusee (" .. tostring(why0) .. ")")
local nolog = false
for _, l in ipairs(LOGS) do if l:find("aucune eau atteignable", 1, true) then nolog = true end end
check(nolog, "journal [FO-CENTRALE-LOIN] du refus")

-- budget de passe : le premier appel sur une grande carte rend « loin » (sondage en cours), sans poser
local fb = make_team(2)
local _, wb1, wwb = Far.place(fb, make_surface(both), G, { read_masks = masks_reader(both), tick = 0, why = "x" })
check(wwb == "loin", "budget de la passe : recherche en cours (" .. tostring(wb1) .. ")")

-- carte de connaissance : l'eau vue seulement ; un secteur à nids écarté
local m = K.new()
local kE = K.key(math.floor(250 / 64), 0)
local kW = K.key(math.floor(-370 / 64), 0)
K.record(m, kE, 0, { water = true, nests = { { x = 260, y = 10 } } })
K.record(m, kW, 0, { water = true })
local fk = make_team(2, { m = m })
local mk = place_once(both, fk, make_surface(both))
check(mk and mk.far and mk.far.x < 0, "carte : le lac de l'est (nids vus) est ecarte, celui de l'ouest est pris (" .. tostring(mk and mk.far and mk.far.x) .. ")")
local m_none = K.new()
K.record(m_none, K.key(0, 0), 0, {})
local mnone, wnone = place_once(both, make_team(2, { m = m_none }), make_surface(both))
check(mnone == nil and wnone == "pas d'eau atteignable", "carte sans eau vue : refus (aucun regard omniscient)")

-- ligne : de la centrale au carrefour de bord, à portée, à sec, points d'appui à sec
if m1 then
  local fL = make_team(2)
  local goal = { x = 60.5, y = 0.5 }
  local a = { x = m1.ox + 0.5, y = m1.oy + 0.5 }
  local chain = Far.line(fL, make_surface(both), { id = 3, far = m1.far }, a, goal, 7.5, {}, {}, masks_reader(both))
  check(chain ~= nil and #chain > 0 and #chain <= Cl.MAX_POLES, "ligne de poteaux tracee (" .. tostring(chain and #chain) .. ")")
  local okr, dry, anchors = true, true, true
  local prev = a
  for _, c in ipairs(chain or {}) do
    if (c.x - prev.x) ^ 2 + (c.y - prev.y) ^ 2 > 7.5 * 7.5 + 1e-6 then okr = false end
    if both(math.floor(c.x), math.floor(c.y)) then dry = false end
    if not c.anchor or both(math.floor(c.ax), math.floor(c.ay)) or (c.ax - c.x) ^ 2 + (c.ay - c.y) ^ 2 > 7 * 7 then anchors = false end
    prev = c
  end
  if chain and (prev.x - goal.x) ^ 2 + (prev.y - goal.y) ^ 2 > 7.5 * 7.5 + 1e-6 then okr = false end
  check(okr, "chaque maillon a portee, le dernier atteint le carrefour")
  check(dry, "aucun poteau de ligne sur l'eau")
  check(anchors, "chaque poteau a un point d'appui a sec, a portee")
  -- terrain non généré au milieu : génération demandée, attente (poll), pas d'écart de rive
  local holes = make_surface(both, { hole = function(cx) return cx == 4 end })
  local pH = { id = 4, far = m1.far }
  local fH = make_team(2)
  local cH, wH, waitH = Far.line(fH, holes, pH, a, goal, 7.5, {}, {}, masks_reader(both))
  local nreq = 0
  for _ in pairs(holes.requested) do nreq = nreq + 1 end
  check(cH == nil and waitH == "loin" and pH.far_poll == Cl.POLL and nreq > 0, "terrain non genere : generation demandee, attente (" .. tostring(wH) .. ")")
  check(not (fH.build.far and fH.build.far.bad[m1.far.key]), "terrain non genere : la rive n'est pas ecartee")
  -- ligne impossible (centrale enfermée par l'eau à plus d'une portée) : rive écartée
  local moat = function(tx, ty) return both(tx, ty) or (math.abs(tx - a.x) <= 20 and math.abs(ty - a.y) <= 20 and (math.max(math.abs(tx - a.x), math.abs(ty - a.y)) >= 8)) end
  local fI = make_team(2)
  local cI, wI, waitI = Far.line(fI, make_surface(moat), { id = 5, far = m1.far }, a, goal, 7.5, {}, {}, masks_reader(moat))
  check(cI == nil and waitI == "loin" and fI.build.far and fI.build.far.bad[m1.far.key], "ligne impossible : rive ecartee (" .. tostring(wI) .. ")")
end

---------------------------------------------------------------------------------------------------
-- 4. build.lua : l'étang garanti a disparu, la recherche lointaine est branchée
---------------------------------------------------------------------------------------------------
section("4. build.lua")
local fh = io.open("script/team/build.lua", "r")
local src = fh:read("*a")
fh:close()
check(src:find("local function make_pond", 1, true) == nil and src:find("make_pond(", 1, true) == nil, "make_pond retire (D-24)")
check(src:find('name = "water"', 1, true) == nil, "plus aucune tuile d'eau posee par le plan directeur")
check(src:find("Far.place(f, surface, g,", 1, true) ~= nil, "plan_project appelle la recherche lointaine")
check(src:find("if not is_plant then return false, why end", 1, true) ~= nil and src:find("is_plant and not f.is_player", 1, true) == nil,
  "toutes les equipes (votre equipe comprise)")
check(src:find('elseif wait == "loin" then', 1, true) ~= nil, "advance traite l'attente « loin »")
check(src:find("Far.line(f, surface, p,", 1, true) ~= nil and src:find("Cl.is_far(b.radius, mi, mj)", 1, true) ~= nil,
  "plan_power relie la centrale lointaine par Far.line")
check(src:find("if main.lot then b.lots[main.lot].used = p.id end", 1, true) ~= nil, "placement sans lot garde")
local fs = io.open("script/team/centrale_loin.lua", "r")
local fsrc = fs:read("*a")
fs:close()
check(fsrc:find("global", 1, true) == nil or fsrc:find("global%.") == nil, "aucun acces direct a global")
check(fsrc:find("require", 1, true) and not fsrc:find("function[^\n]*\n[^\n]*require%("), "require seulement au chargement")

---------------------------------------------------------------------------------------------------
-- 5. Mutants : la batterie pure les refuse tous
---------------------------------------------------------------------------------------------------
section("5. mutants")
local function clone(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end
local mutants = {
  { "rive sans profondeur de 2 tuiles", function(C)
    local orig = C.shores
    C.shores = function(isw, area, toward, opts)
      return orig(function(tx, ty) return isw(tx, ty) or isw(tx - 1, ty) or isw(tx + 1, ty) or isw(tx, ty - 1) or isw(tx, ty + 1) end, area, toward, opts)
    end end },
  { "secteurs epuises non ecartes", function(C) local o = C.order_sectors; C.order_sectors = function(l, h) return o(l, h, nil) end end },
  { "carre d'essai sans marge", function(C) C.outside = function(ext, x, y) return x < ext.x0 or x >= ext.x1 or y < ext.y0 or y >= ext.y1 end end },
  { "budget par defaut", function(C) C.path_opts = function() return nil end end },
  { "carrefour non ramene", function(C) C.clamp_node = function(R, i, j) return i, j end end },
  { "point d'appui le plus lointain", function(C) local o = C.anchor_spot; C.anchor_spot = function(st, x, y, r)
    for k = r, 0, -1 do local ax, ay = o(function(tx, ty) return st(tx, ty) and math.max(math.abs(tx - math.floor(x)), math.abs(ty - math.floor(y))) == k end, x, y, r) if ax then return ax, ay end end
    return nil end end },
}
local killed = 0
for _, mu in ipairs(mutants) do
  local C = clone(Cl)
  mu[2](C)
  local ok = battery_pure(C, true)
  if not ok then killed = killed + 1 else print("  mutant survivant : " .. mu[1]) end
end
check(killed == #mutants, string.format("mutants refuses : %d / %d", killed, #mutants))

print(string.format("[CENTRALE-LOIN] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
