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

local Fm = require("tests.champ_formes")
local disc, ellipse, rect, spec_of, shapes = Fm.disc, Fm.ellipse, Fm.rect, Fm.spec_of, Fm.shapes

local function sig(e) return string.format("%s:%.2f:%.2f:%d:%s:%s:%s", e.kind, e.x, e.y, e.dir, tostring(e.band), tostring(e.group), tostring(e.role)) end
local function serial(p)
  if not p then return "nil" end
  local t = { p.axis, tostring(p.exit), tostring(p.phase) }
  for _, e in ipairs(p.ents) do t[#t + 1] = sig(e) end
  return table.concat(t, ";")
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
  -- (coût, 7/11) candidats rangés directement dans l'ordre du tri : même liste que le tri complet d'avant (Cc.candidates_tri)
  do
    local bad, n = 0, 0
    for _, b in ipairs({ 0, 5, -13 }) do
      for _, pitch in ipairs({ 6, 8, 10 }) do
        for _, side in ipairs({ 1, -1 }) do
          for _, ur in ipairs({ {}, { [b + pitch] = true }, { [b] = true, [b - 2 * pitch] = true } }) do
            local x, y = Cc.candidates(b, side, 40, 1, pitch, ur), Cc.candidates_tri(b, side, 40, 1, pitch, ur)
            n = n + 1
            local same = #x == #y
            for i = 1, #x do
              if same and not (x[i].row == y[i].row and x[i].t == y[i].t and x[i].s_edge == y[i].s_edge and x[i].cost == y[i].cost) then same = false end
            end
            if not same then bad = bad + 1 end
          end
        end
      end
    end
    check(bad == 0, string.format("candidats sans tri = tri complet d'avant : %d cas, %d differents", n, bad))
  end
  -- mutants de SOURCE (shared/team/champ.lua chargé modifié)
  local smuts = {
    { "souterrain de bande sans ecarter les foreuses qui deposent dessus", function(src)
        return src:gsub("for _, it in ipairs%(all%) do if not skip%[it%.cu%] then keep%[#keep %+ 1%] = it end end", "for _, it in ipairs(all) do keep[#keep + 1] = it end")
      end, { "r30 + tourelles eparses sur le champ" } },
    { "aucun saut d'obstacle en souterrain", function(src)
        return src:gsub("hop = %(r23 and ug and ug >= 2%) and %(ug %- 1%) or nil", "hop = nil")
      end, { "r30 + tourelles eparses sur le champ" } },
    { "tapis de bande poursuivi jusqu'a la fonderie malgre le trace", function(src)
        return src:gsub("if g%.route then s_end = g%.exit %- g%.side end", "")
      -- (R1, 7/11) formes qui gardent des groupes tracés dans l'axe choisi (les lacs et l'anneau n'en ont plus)
      end, { "r30 + grands lacs (33 a 100)", "r30 + anneau, sans souterrains" } },
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
    -- (R1, 7/11) une forme qui garde des fonderies déplacées dans l'axe choisi (8 sur les grands lacs ; les lacs aux deux bouts n'en ont plus)
    local s = by["r30 + grands lacs (33 a 100)"]
    local sp = spec_of(s.ore, s.o)
    local p = Ch.plan(sp)
    check(Cvm ~= nil and Cvm.verify(p, sp).traverse > 0, "mutant du controle vu : colonne deplacee jugee sur la rangee de sa bande")
  end
end

section("6. R1 : les deux axes planifies ; l'autre axe seulement s'il couvre STRICTEMENT plus, sans reseau coupe ni coffre de tete de plus")
do
  -- axes attendus (MESURÉ le 7/11, chaque forme planifiée dans ses deux axes) : les autres formes gardent l'axe long (x)
  local EXPECT = { ["ellipse 70 x 30"] = "y", ["L 60 x 14 + 14 x 50"] = "x", ["r30 + couloir horizontal"] = "y", ["r30 + lacs aux deux bouts"] = "y",
    ["r12 + eau aux bouts, ouverture de 3"] = "y", ["r30 + eau aux bouts, ouverture de 5"] = "y", ["r30 brut + lacs aux deux bouts"] = "y" }
  local LONG = { ["L 60 x 14 + 14 x 50"] = "y" }
  local function forced(name, axis)
    local s
    for _, x in ipairs(shapes()) do if x.name == name then s = x end end
    local sp = spec_of(s.ore, s.o)
    sp.force_axis = axis
    local p = Ch.plan(sp)
    return p, p and Cv.verify(p, spec_of(s.ore, s.o))
  end
  for _, s in ipairs(shapes()) do
    local r = results[s.name]
    if r then
      local want = EXPECT[s.name] or "x"
      local other = (want == "x") and "y" or "x"
      local _, ro = forced(s.name, other)
      local same = r.p.axis == want and ((r.p.axis_choice ~= nil) == (want ~= (LONG[s.name] or "x")))
      check(same and (not ro or r.rep.elec >= ro.elec - 1e-9 or (ro.unpowered or 0) > 0),
        string.format("%s : axe %s (attendu %s%s), couverture %.1f %% ; l'autre axe %.1f %%", s.name, r.p.axis, want,
          r.p.axis_choice and (", axe long " .. r.p.axis_choice.long) or "", 100 * r.rep.elec, ro and 100 * ro.elec or 0))
    end
  end
  -- stabilité dans l'axe choisi (règle de tests/champ_colonne_test.lua §4) : chaque bande seule, rejouée du cadre (axe compris), ne pose
  -- que des pièces du plan entier (poteaux exceptés : une rangée partagée par deux bandes en a d'autres, bâtie seule) ; toutes les pièces
  -- du plan entier (hors poteaux) sont posées par une bande ; une bande bâtie seule marche seule (un réseau, rien sans courant)
  local function sig(e) return string.format("%s:%.1f:%.1f:%d", e.kind, e.x, e.y, e.dir) end
  local function stab(name, drop_axis)
    local s
    for _, x in ipairs(shapes()) do if x.name == name then s = x end end
    local full = Ch.plan(spec_of(s.ore, s.o))
    local in_full, need, seen = {}, {}, {}
    for _, e in ipairs(full.ents) do
      in_full[sig(e)] = true
      if e.kind ~= "poteau" then need[sig(e)] = true end
    end
    local bad, total, lone_bad = 0, 0, 0
    for _, bd in ipairs(full.bands) do
      local fr = {}
      for k, v in pairs(full.frame) do fr[k] = v end
      fr.only = { [bd.pr] = true }
      if drop_axis then fr.axis = nil end
      local o = {}
      for k, v in pairs(s.o) do o[k] = v end
      local sp = spec_of(s.ore, o)
      sp.frame = fr
      local part = Ch.plan(sp)
      if part and #part.ents > 0 then
        local rp = Cv.verify(part, sp)
        if not (rp.components <= 1 and rp.unpowered == 0 and rp.no_ore == 0 and rp.no_coal == 0 and rp.arms == 0 and rp.drops == 0) then lone_bad = lone_bad + 1 end
      end
      for _, e in ipairs(part and part.ents or {}) do
        total = total + 1
        seen[sig(e)] = true
        if not in_full[sig(e)] and e.kind ~= "poteau" then bad = bad + 1 end
      end
    end
    local missing = 0
    for k in pairs(need) do if not seen[k] then missing = missing + 1 end end
    return bad, total, missing, lone_bad
  end
  for _, n in ipairs({ "ellipse 70 x 30", "r30 + lacs aux deux bouts" }) do
    local bad, total, missing, lone_bad = stab(n, false)
    check(total > 0 and bad == 0 and missing == 0 and lone_bad == 0, string.format("%s (axe court), bandes seules : %d entites, %d absentes du plan entier (poteaux exceptes), %d pieces du plan entier jamais posees, %d bande(s) qui ne marchent pas seules",
      n, total, bad, missing, lone_bad))
  end
  -- mutants : choix inversé, égalité tranchée par l'autre axe, axe absent du cadre
  local function mut(pat, rep)
    local fh = assert(io.open("shared/team/champ.lua", "rb"))
    local src = fh:read("*a")
    fh:close()
    local msrc, n = src:gsub(pat, rep)
    if n ~= 1 then return nil end
    return assert(load(msrc, "=champ_mutant_r1"))()
  end
  local function axis_of(M, name)
    for _, x in ipairs(shapes()) do if x.name == name then local p = M.plan(spec_of(x.ore, x.o)); return p and p.axis end end
  end
  local M1 = mut("local better = qc_ > pc_ and", "local better = qc_ < pc_ and")
  check(M1 ~= nil and axis_of(M1, "ellipse 70 x 30") == "x", "mutant vu : choix inverse (l'ellipse garde l'axe qui couvre le moins)")
  local M2 = mut("local better = qc_ > pc_ and", "local better = qc_ >= pc_ and")
  check(M2 ~= nil and axis_of(M2, "disque r30") == "y", "mutant vu : egalite tranchee par l'autre axe (le disque change d'axe)")
  -- (le mutant « coffres de tête ignorés » est dans tests/champ_colonne_test.lua §3, sur l'ellipse longue au charbon du sud)
  local bad, total, missing = stab("ellipse 70 x 30", true)
  check(bad > 0 or total == 0 or missing > 0, string.format("mutant vu : axe absent du cadre (bandes seules rejouees dans l'axe long : %d entites, %d absentes, %d jamais posees)",
    total, bad, missing))
end

print(string.format("[CHAMP-COUVERTURE] BILAN : %d OK, %d ECHEC(S), %d ecart(s) connu(s)", passes, failures, known))
if failures > 0 then os.exit(1) end
