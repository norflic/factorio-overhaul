--[[
  Tests hors jeu du lot CHAMP-COUVERTURE (R2 + R3, puis R4 + R1) : couverture du plan pur Ch.plan sur des formes construites, avec la
  spec du jeu (foreuse 3 x 3 de portée 1 à 0,5 /s, poteau de portée 2 et fil 7,5, tapis jaune seul, 8 foreuses par côté, four de pierre au
  charbon, colonne, charbon à ~35 tuiles ; ou coffres pour un minerai brut). Cibles : fo-logs/2026-11-05_CHAMP-COUVERTURE/PROPOSITION.md §3
  (valeurs d'essai-a mesurées dans mesure_essai-a.txt). Pur, aucune API Factorio.
  Usage, depuis la racine du mod :   lua5.2 tests/champ_couverture_test.lua [--court]
  1. formes avec obstacles HORS du minerai (anneau de tourelles, lacs, eau avec ouverture) et SUR le champ (tourelles, rivière, couloir) :
     couverture >= cible ; contrôle Cv.verify sans défaut ;
  2. champs propres : plan IDENTIQUE à celui de la règle sans découplage (Ch.CFG.decouple = false : le chemin d'avant le lot) ;
  3. stabilité (chaque bande planifiée seule depuis le cadre figé = la même bande du plan entier), déterminisme ;
  4. temps du plan.
]]
package.path = "./?.lua;" .. package.path

local Ch = require("shared.team.champ")
local Cv = require("shared.team.champ_verif")

local short = arg[1] == "--court"
local passes, failures, known = 0, 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
--- Écart CONNU (compté à part, comme tests/levels_test.lua) : cible non atteinte, cause mesurée et écrite.
local function known_gap(cond, msg, why)
  if cond then passes = passes + 1 else known = known + 1; print("  ECART CONNU : " .. msg .. " -- " .. why) end
end

local function disc(cx, cy, r, skip, out)
  out = out or {}
  for x = cx - r, cx + r do for y = cy - r, cy + r do
    if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r and not (skip and skip(x, y)) then out[#out + 1] = x; out[#out + 1] = y end
  end end
  return out
end
local function ellipse(a, b)
  local o = {}
  for x = -a, a do for y = -b, b do if (x / a) ^ 2 + (y / b) ^ 2 <= 1 then o[#o + 1] = x; o[#o + 1] = y end end end
  return o
end
local function rect(x0, y0, w, h, out)
  out = out or {}
  for x = x0, x0 + w - 1 do for y = y0, y0 + h - 1 do out[#out + 1] = x; out[#out + 1] = y end end
  return out
end

--- Spec du jeu (voir l'en-tête). o.brut : minerai porté brut (coffres) ; o.blocked ; o.target.
local function spec_of(ore, o)
  o = o or {}
  local sp = { ore = ore, blocked = o.blocked or {}, mine = {}, foreign = {}, drill = { size = 3, reach = 1, rate = 0.5 }, pole = { reach = 2, wire = 7.5 },
    belts = { { lane = 7.5 } }, inserter = { rate = 0.83 }, target = o.target or { x = 0, y = 400 }, max_side = 8,
    logistics = { splitter = false, underground = (o.ug ~= false) and (o.ug or 5) or nil } }
  if not o.brut then
    sp.furnace = { size = 2, rate = 0.3125, fuel = true, fuel_rate = 0.0225 }
    sp.design = "colonne"
    local bx, by = 0, 0
    for i = 1, #ore - 1, 2 do bx = math.max(bx, ore[i]); by = math.max(by, ore[i + 1]) end
    -- charbon : gisement de rayon 12 (452 tuiles) à ~45 tuiles en diagonale du coin du champ (au-delà des fonderies déplacées : la zone
    -- interdite au tracé du charbon est la boîte du champ ET des colonnes)
    sp.coal = { tiles = disc(bx + 45, by + 45, 12), rate = 0.5, foreign = {} }
    sp.soft, sp.ug_tiles = {}, {}
  end
  return sp
end

local function sig(e) return string.format("%s:%.2f:%.2f:%d:%s:%s:%s", e.kind, e.x, e.y, e.dir, tostring(e.band), tostring(e.group), tostring(e.role)) end
local function serial(p)
  if not p then return "nil" end
  local t = { p.axis, tostring(p.exit), tostring(p.phase) }
  for _, e in ipairs(p.ents) do t[#t + 1] = sig(e) end
  return table.concat(t, ";")
end

--- Formes (nom, minerai, options, cible de couverture, valeur d'essai-a).
local function shapes()
  local L = {}
  local function add(name, ore, o, target, before) L[#L + 1] = { name = name, ore = ore, o = o or {}, target = target, before = before } end
  add("disque r11", disc(0, 0, 11), nil, 0.98, 1.000)
  add("disque r20", disc(0, 0, 20), nil, 0.97, 0.990)
  add("disque r30", disc(0, 0, 30), nil, 0.80, 0.809)
  add("ellipse 70 x 30", ellipse(35, 15), nil, 0.73, 0.737)
  do
    local Lr = rect(0, 0, 60, 14)
    rect(0, 14, 14, 50, Lr)
    add("L 60 x 14 + 14 x 50", Lr, nil, 0.82, 0.826)
  end
  do
    local b = {}
    for x = -40, 40 do for y = 0, 1 do b[Ch.key(x, y)] = "couloir" end end
    add("r30 + couloir horizontal", disc(0, 0, 30), { blocked = b }, 0.77, 0.774)
  end
  do
    local b, w = {}, {}
    for x = -40, 40 do for y = -40, 40 do if math.abs(x - y) <= 2 then b[Ch.key(x, y)] = "eau"; w[Ch.key(x, y)] = true end end end
    -- (écart connu : la rivière fait 5 tuiles ; un souterrain jaune n'en saute que 4 ; le long tronçon d'une bande coupée n'a alors
    -- qu'une sortie et porte au plus une voie de tête de colonne, 15 foreuses au tapis jaune)
    add("r30 + riviere diagonale", disc(0, 0, 30, function(x, y) return w[Ch.key(x, y)] end), { blocked = b, known = "riviere de 5 tuiles, souterrain jaune de portee 5 (4 tuiles sautees) : le troncon long n'a qu'une sortie, 15 foreuses au plus" }, 0.75, 0.681)
    add("r30 + riviere, souterrain rapide (portee 7)", disc(0, 0, 30, function(x, y) return w[Ch.key(x, y)] end), { blocked = b, ug = 7 }, 0.75, nil)
  end
  do
    local b = {}
    for x = -36, 36, 12 do for y = -36, 36, 12 do for dx = 0, 1 do for dy = 0, 1 do b[Ch.key(x + dx, y + dy)] = "gun-turret" end end end end
    add("r30 + tourelles eparses sur le champ", disc(0, 0, 30), { blocked = b }, 0.72, 0.615)
  end
  do
    local b = {}
    for x = -40, 40 do for y = -40, 40 do
      local d2 = x * x + y * y
      if d2 >= 34 * 34 and d2 < 35 * 35 and (x + y) % 8 == 0 then for dx = 0, 1 do for dy = 0, 1 do b[Ch.key(x + dx, y + dy)] = "gun-turret" end end end
    end end
    add("r30 + anneau de tourelles (r34)", disc(0, 0, 30), { blocked = b }, 0.76, 0.485)
    -- sans souterrain débloqué (début de partie) : la sortie bouchée par une tourelle recule d'une foreuse (Cc.trim)
    add("r30 + anneau, sans souterrains", disc(0, 0, 30), { blocked = b, ug = false }, 0.75, nil)
  end
  -- (écart connu, mesuré le 7/11, accordé par le lead) entre le bout du champ et un lac, le couloir x = ±32 n'a qu'une tuile (x = ±31 : les
  -- foreuses du bout ; x = ±33 : le lac) : le tapis tracé l'occupe et aucun petit poteau ne s'y pose (fil 7,5 ; rangées de poteaux à 8 tuiles).
  -- La colonne déplacée d'une bande entre les lacs n'a de courant que par une AUTRE bande : refusée (une bande se bâtit seule en jeu).
  local LACS = "couloir d'une tuile entre le champ et le lac : aucun petit poteau de liaison (fil 7,5 < 8 tuiles entre rangees) ; "
    .. "colonne deplacee sans courant si sa bande est batie seule, donc refusee"
  do
    local b = {}
    for x = 33, 60 do for y = -15, 15 do b[Ch.key(x, y)] = "eau"; b[Ch.key(-x, y)] = "eau" end end
    add("r30 + lacs aux deux bouts", disc(0, 0, 30), { blocked = b, known = LACS }, 0.75, 0.230)
    -- lacs plus longs que le recul de la fonderie (48 tuiles) : elle passe sur une autre rangée de bande
    local b2 = {}
    for x = 33, 100 do for y = -15, 15 do b2[Ch.key(x, y)] = "eau"; b2[Ch.key(-x, y)] = "eau" end end
    add("r30 + grands lacs (33 a 100)", disc(0, 0, 30), { blocked = b2, known = LACS }, 0.75, nil)
  end
  do
    local b = {}
    for x = 14, 50 do for y = -20, 20 do if math.abs(y) > 1 then b[Ch.key(x, y)] = "eau"; b[Ch.key(-x, y)] = "eau" end end end
    add("r12 + eau aux bouts, ouverture de 3", disc(0, 0, 12), { blocked = b }, 0.85, 0.000)
  end
  do
    local b = {}
    for x = 33, 70 do for y = -40, 40 do if math.abs(y) > 2 then b[Ch.key(x, y)] = "eau"; b[Ch.key(-x, y)] = "eau" end end end
    add("r30 + eau aux bouts, ouverture de 5", disc(0, 0, 30), { blocked = b }, 0.70, 0.000)
  end
  add("r30 brut (coffres)", disc(0, 0, 30), { brut = true }, 0.84, 0.848)
  do
    local b = {}
    for x = 33, 60 do for y = -15, 15 do b[Ch.key(x, y)] = "eau"; b[Ch.key(-x, y)] = "eau" end end
    add("r30 brut + lacs aux deux bouts", disc(0, 0, 30), { blocked = b, brut = true, known = LACS }, 0.75, nil)
  end
  return L
end

local CLEAN = { ["disque r11"] = true, ["disque r20"] = true, ["disque r30"] = true, ["ellipse 70 x 30"] = true, ["L 60 x 14 + 14 x 50"] = true,
  ["r30 brut (coffres)"] = true }

local results = {}
section("1. couverture des formes (cible : PROPOSITION.md §3)")
for _, s in ipairs(shapes()) do
  if not short or CLEAN[s.name] or s.name:find("lacs") then
    local sp = spec_of(s.ore, s.o)
    local t0 = os.clock()
    local p, why = Ch.plan(sp)
    local dt = os.clock() - t0
    if not p then
      check(false, s.name .. " : plan refuse (" .. tostring(why) .. ")")
    else
      local rep = Cv.verify(p, sp)
      -- la règle sans découplage (chemin d'avant le lot) sur la même forme : référence des défauts déjà là (couloir : 14 sans courant)
      local saved = Ch.CFG.decouple
      Ch.CFG.decouple = false
      local sp0 = spec_of(s.ore, s.o)
      local p0 = Ch.plan(sp0)
      Ch.CFG.decouple = saved
      local rep0 = p0 and Cv.verify(p0, sp0) or {}
      results[s.name] = { p = p, sp = sp, rep = rep }
      print(string.format("  %-40s couverture %5.1f %% (essai-a %s, cible %.0f %%), %3d foreuses de bande, coupees %3d, sans fonderie %2d, %.2f s",
        s.name, 100 * rep.elec, s.before and string.format("%.1f %%", 100 * s.before) or "-", 100 * s.target, p.stats.band_drills or 0,
        p.stats.capped or 0, p.stats.no_smelter or 0, dt))
      if s.o.known then
        known_gap(rep.elec >= s.target - 1e-9, string.format("%s : couverture %.1f %% >= %.0f %%", s.name, 100 * rep.elec, 100 * s.target), s.o.known)
      else
        check(rep.elec >= s.target - 1e-9, string.format("%s : couverture %.1f %% >= %.0f %%", s.name, 100 * rep.elec, 100 * s.target))
      end
      check(rep.elec >= (rep0.elec or 0) - 1e-9, string.format("%s : jamais moins couvert que sans decouplage (%.1f %%)", s.name, 100 * (rep0.elec or 0)))
      -- aucun défaut de plus que la règle sans découplage (0 sur toutes les formes, sauf ceux déjà là)
      local bad = {}
      for _, k in ipairs({ "overlaps", "blocked", "unpowered", "traverse", "inside", "drops", "arms", "starved", "no_ore", "no_coal", "no_plate", "mixed",
        "junction" }) do
        if (rep[k] or 0) > (rep0[k] or 0) then bad[#bad + 1] = string.format("%s %d (sans decouplage %d)", k, rep[k], rep0[k] or 0) end
      end
      if (rep.components or 0) > math.max(1, rep0.components or 0) then bad[#bad + 1] = "reseaux " .. rep.components end
      check(#bad == 0, s.name .. " : aucun defaut de plus (" .. table.concat(bad, ", ") .. ")")
    end
  end
end

section("2. champs propres : plan identique a la regle sans decouplage")
for _, s in ipairs(shapes()) do
  if CLEAN[s.name] and results[s.name] then
    local saved = Ch.CFG.decouple
    Ch.CFG.decouple = false
    local q = Ch.plan(spec_of(s.ore, s.o))
    Ch.CFG.decouple = saved
    check(serial(q) == serial(results[s.name].p), s.name .. " : plan identique entite par entite (" .. #results[s.name].p.ents .. " entites)")
  end
end

section("3. stabilite et determinisme")
-- (comme tests/champ_test.lua §3 : une entité est sa sorte, sa place et son sens ; le numéro de bande diffère entre plan entier et bande seule)
local function place(e) return string.format("%s:%.2f:%.2f:%d", e.kind, e.x, e.y, e.dir) end
local function stability(s)
  local sp = spec_of(s.ore, s.o)
  local full = Ch.plan(sp)
  local in_full = {}
  for _, e in ipairs(full.ents) do in_full[place(e)] = true end
  local bad, total, poles, nb = 0, 0, 0, 0
  for _, bd in ipairs(full.bands) do
    if #bd.groups > 0 then
      nb = nb + 1
      local fr = {}
      for k, v in pairs(full.frame) do fr[k] = v end
      fr.only = { [bd.pr] = true }
      local o2 = {}
      for k, v in pairs(s.o) do o2[k] = v end
      local sp2 = spec_of(s.ore, o2)
      sp2.frame = fr
      local part = Ch.plan(sp2)
      for _, e in ipairs(part and part.ents or {}) do
        total = total + 1
        if not in_full[place(e)] then
          -- poteau de RANGÉE (rôle nil) : classe déjà présente sur essai-0653 (la rangée d'une bande seule va jusqu'à la colonne de l'autre côté)
          if e.kind == "poteau" and e.role == nil then poles = poles + 1 else bad = bad + 1 end
        end
      end
    end
  end
  return bad, total, poles, nb
end
for _, s in ipairs(shapes()) do
  if (not short) and (s.name:find("lacs aux deux bouts") or s.name:find("anneau") or s.name:find("eparses") or s.name == "disque r20") then
    -- (la règle d'avant le lot laisse déjà des POTEAUX DE RANGÉE de bande seule hors du plan entier : 4 sur le disque r20, un par bande au
    -- plus ; ils ne sont pas comptés comme défaut du lot, toute autre entité absente l'est)
    local bad, total, poles, nb = stability(s)
    check(total > 0 and bad == 0 and poles <= nb, string.format("%s : bandes seules, %d entites, %d absentes du plan entier hors poteaux de rangee, %d poteau(x) de rangee (%d bandes)",
      s.name, total, bad, poles, nb))
    local a = serial(Ch.plan(spec_of(s.ore, s.o)))
    local b = serial(Ch.plan(spec_of(s.ore, s.o)))
    check(a == b, s.name .. " : deux plans identiques")
  end
end

section("4. temps")
do
  -- (coût, 7/11) emprise de la fonderie décalée depuis l'origine : plan IDENTIQUE à la disposition refaite à chaque candidat
  local Cc = require("shared.team.champ_couverture")
  for _, s in ipairs(shapes()) do
    if s.name:find("lacs") or s.name:find("ouverture") or s.name:find("sans souterrains") or s.name:find("eparses") then
      if not short or s.name == "r30 + lacs aux deux bouts" then
        local t0 = os.clock()
        local a = serial(Ch.plan(spec_of(s.ore, s.o)))
        local t_fast = os.clock() - t0
        Cc.CFG.fast_layout = false
        t0 = os.clock()
        local b = serial(Ch.plan(spec_of(s.ore, s.o)))
        local t_slow = os.clock() - t0
        Cc.CFG.fast_layout = true
        check(a == b, string.format("%s : emprise decalee, plan identique (%.2f s, refaite a chaque candidat %.2f s)", s.name, t_fast, t_slow))
      end
    end
  end
  -- translation pure, relue sur Co.layout et Fd.layout (deux côtés, voie et coffre de tête)
  local okT = true
  local sp = spec_of(disc(0, 0, 11), {})
  local spb = spec_of(disc(0, 0, 11), { brut = true })
  for _, side in ipairs({ 1, -1 }) do
    for _, it in ipairs({ { sp, true, "voie" }, { sp, true, "coffre" }, { spb, false, nil } }) do
      local _, _, _, t0 = Cc.layout(it[1], it[2], 0, side, 0, 5, it[3])
      for _, pos in ipairs({ { 7, -13 }, { -40, 22 }, { 3, 3 } }) do
        local _, _, _, t1 = Cc.layout(it[1], it[2], pos[2], side, pos[1], 5, it[3])
        if not t0 or not t1 or #t0 ~= #t1 then okT = false else
          for i = 1, #t0 do if t0[i][1] + pos[1] ~= t1[i][1] or t0[i][2] + pos[2] ~= t1[i][2] then okT = false end end
        end
      end
    end
  end
  check(okT, "Co.layout et Fd.layout : l'emprise ne depend de la place que par translation")
end
if not short then
  -- temps RELATIF (le PC est partagé avec d'autres bancs) : la règle avec découplage contre la règle sans, sur le même champ, à la suite
  local function timed(dec)
    local saved = Ch.CFG.decouple
    Ch.CFG.decouple = dec
    local t0 = os.clock()
    Ch.plan(spec_of(rect(0, 0, 200, 200)))
    Ch.CFG.decouple = saved
    return os.clock() - t0
  end
  local t_old, t_new = timed(false), timed(true)
  print(string.format("  geant 200 x 200 : %.2f s sans decouplage, %.2f s avec", t_old, t_new))
  check(t_new <= 2 * t_old + 0.2, string.format("geant 200 x 200 : %.2f s <= 2 x %.2f s", t_new, t_old))
end

section("5. mutants")
do
  local Cc = require("shared.team.champ_couverture")
  local by = {}
  for _, s in ipairs(shapes()) do by[s.name] = s end
  --- Couverture et défauts d'une forme avec le module de plan `M` (le vrai, ou une source mutante).
  local function run_with(M, name)
    local s = by[name]
    local sp = spec_of(s.ore, s.o)
    local ok, p = pcall(M.plan, sp)
    if not ok or not p then return nil end
    return Cv.verify(p, sp), p
  end
  local function seen_by(M, names)
    for _, n in ipairs(names) do
      local rep = run_with(M, n)
      if not rep then return true end
      -- forme à écart connu : le mutant doit faire MOINS que le vrai module (sa cible n'est pas atteinte, elle ne prouverait rien)
      local thr = by[n].target
      if by[n].o.known and results[n] then thr = results[n].rep.elec end
      if rep.elec < thr - 1e-9 then return true end
      for _, k in ipairs({ "overlaps", "blocked", "unpowered", "drops", "arms", "starved", "no_ore", "junction" }) do if (rep[k] or 0) > 0 then return true end end
    end
    return false
  end
  local function mutant_module(fn)
    local fh = assert(io.open("shared/team/champ.lua", "rb"))
    local src = fh:read("*a")
    fh:close()
    local msrc, n = fn(src)
    if n == 0 then return nil end
    return assert(load(msrc, "=champ_mutant"))()
  end
  local muts = {
    { "decouplage eteint (chemin d'avant partout)", function() local o = Ch.CFG.decouple; Ch.CFG.decouple = false; return function() Ch.CFG.decouple = o end end,
      { "r30 + anneau de tourelles (r34)", "r30 + lacs aux deux bouts" } },
    { "sortie jamais reculee (Cc.CFG.trim = 0)", function() local o = Cc.CFG.trim; Cc.CFG.trim = 0; return function() Cc.CFG.trim = o end end,
      { "r30 + anneau, sans souterrains" } },
    { "fonderie deplacee sur une seule rangee (j = 0)", function() local o = Cc.CFG.rows; Cc.CFG.rows = 0; return function() Cc.CFG.rows = o end end,
      { "r30 + grands lacs (33 a 100)" } },
  }
  for _, m in ipairs(muts) do
    local undo = m[2]()
    local seen = seen_by(Ch, m[3])
    undo()
    check(seen, "mutant vu : " .. m[1])
  end
  -- rectangles des bandes (zone interdite au tracé) : règle pure relue
  do
    local f = Cc.rects({ { pr = 0, b = 4, n = { 10, 13 }, s = { 10 } }, { pr = 8, b = 12, n = { 0 }, s = { 3, 6 } } }, 3, 2, 8)
    check(f(10, 0) and f(15, 4) and f(12, 8) and f(0, 9) and f(8, 16), "rectangles : foreuses, tapis et rangees de poteaux des bandes interdits")
    check(not f(9, 4) and not f(16, 4) and not f(-1, 12) and not f(9, 12) and not f(10, -1), "rectangles : au-dela des foreuses, libre")
    check(f(15, 2) and not f(15, 2, { pr = 0, side = 1, exit = 14 }) and f(13, 2, { pr = 0, side = 1, exit = 14 }) and f(5, 10, { pr = 0, side = 1, exit = 14 }),
      "rectangles : la bande du groupe est libre au-dela de sa sortie, et elle seule")
  end
  -- mutants de SOURCE (shared/team/champ.lua chargé modifié)
  local smuts = {
    { "souterrain de bande sans ecarter les foreuses qui deposent dessus", function(src)
        return src:gsub("for _, it in ipairs%(all%) do if not skip%[it%.cu%] then keep%[#keep %+ 1%] = it end end", "for _, it in ipairs(all) do keep[#keep + 1] = it end")
      end, { "r30 + tourelles eparses sur le champ" } },
    { "aucun saut d'obstacle en souterrain", function(src)
        return src:gsub("local hop = %(%(decouple_new or %(F and F%.routed%)%) and ug and ug >= 2%) and %(ug %- 1%) or nil", "local hop = nil")
      end, { "r30 + tourelles eparses sur le champ" } },
    { "tapis de bande poursuivi jusqu'a la fonderie malgre le trace", function(src)
        return src:gsub("if g%.route then s_end = g%.exit %- g%.side end", "")
      end, { "r30 + lacs aux deux bouts", "r30 + anneau de tourelles (r34)" } },
  }
  for _, m in ipairs(smuts) do
    local M = mutant_module(m[2])
    check(M ~= nil and seen_by(M, m[3]), "mutant de source vu : " .. m[1])
  end
  -- mutant du CONTRÔLE : la colonne d'un groupe tracé jugée sur la rangée de la bande -> « tapis hors bande »
  do
    local fh = assert(io.open("shared/team/champ_verif.lua", "rb"))
    local src = fh:read("*a")
    fh:close()
    local msrc, n = src:gsub("local row = %(e%.role == \"colonne\" and g and g%.row%) or %(bd and bd%.b%)", "local row = bd and bd.b")
    local Cvm = n > 0 and assert(load(msrc, "=champ_verif_mutant"))() or nil
    local s = by["r30 + lacs aux deux bouts"]
    local sp = spec_of(s.ore, s.o)
    local p = Ch.plan(sp)
    check(Cvm ~= nil and Cvm.verify(p, sp).traverse > 0, "mutant du controle vu : colonne deplacee jugee sur la rangee de sa bande")
  end
end

print(string.format("[CHAMP-COUVERTURE] BILAN : %d OK, %d ECHEC(S), %d ecart(s) connu(s)", passes, failures, known))
if failures > 0 then os.exit(1) end
