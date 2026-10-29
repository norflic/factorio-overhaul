--[[
  Tests hors jeu du lot AGENCEMENT, partie FOREUSES EN RANGEES (retour du DC du 29/10 en jouant la 0.6.16 : « on veut des rangées
  de foreuses en fait »). Pur, aucune API Factorio.   Usage, depuis la racine du mod :   lua5.2 tests/rangees_test.lua

  1. la formule de zone minée = les tuiles que le gabarit « drills » mine vraiment (M.resource_tiles), pour 1 à 7 paires ;
  2. nombre de paires que porte un gisement (tuiles de minerai d'un lot), contre P.fit sur des gisements compacts réels :
     l'estimation ne promet jamais une ligne que P.fit refuse à la couverture visée ;
  3. rangées de fours ↔ paires de foreuses : arrondis, jamais de four privé de minerai ;
  4. échelle de tailles et essais : la couverture visée d'abord, puis exactement l'ancien parcours (n, n−1, … 1) ;
  5. mutants : chaque règle faussée est refusée par les contrôles ci-dessus.
]]
package.path = "./?.lua;" .. package.path

local P = require("shared.team.plan")
local M = require("shared.team.modules")
local Rg = require("shared.team.rangees")
local T = require("shared.team.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local dsp = M.spec(T.DRILL_ELECTRIC)
local reach = Rg.reach(dsp.radius, dsp.w)

--- Les contrôles, sur la table de règles `R` (la vraie ou un mutant) ; rend le nombre d'échecs qu'ils ont relevé.
local function suite(R, verbose)
  local bad = 0
  local function ck(cond, msg)
    if not cond then bad = bad + 1; if verbose then print("  ECHEC : " .. msg) end end
  end
  -- 1. zone minée : la formule contre le gabarit réel
  local r = R.reach(dsp.radius, dsp.w)
  ck(r == 1, "portée de minage de la foreuse électrique : 1 tuile (" .. tostring(r) .. ")")
  for n = 1, 7 do
    local g = M.GEN.drills("iron-ore", n)
    ck(g ~= nil and #M.resource_tiles(g) == R.area(dsp.w, n, r), "zone minée de " .. n .. " paire(s) = tuiles du gabarit")
  end
  ck(R.area(3, 2, 1) > R.area(3, 1, 1), "la zone croît avec la ligne")
  -- 2. paires que porte un gisement
  ck(R.pairs_for_tiles(0, 3, 1, 0.8, 7) == 0, "aucune tuile : aucune paire")
  ck(R.pairs_for_tiles(nil, 3, 1, 0.8, 7) == 0, "tuiles inconnues : aucune paire")
  ck(R.pairs_for_tiles(30, 3, 1, 0.8, 7) == 0, "30 tuiles : même une paire (9 × 5 × 0,8 = 36) ne tient pas")
  ck(R.pairs_for_tiles(36, 3, 1, 0.8, 7) == 1, "36 tuiles : une paire pile")
  ck(R.pairs_for_tiles(100, 3, 1, 0.8, 7) == 3, "100 tuiles : 3 paires")
  ck(R.pairs_for_tiles(576, 3, 1, 0.8, 7) == 7, "un lot plein : borné par la ligne (7)")
  ck(R.pairs_for_tiles(576, 3, 1, 0.8, 4) == 4, "borné par max_pairs")
  ck(R.pairs_for_tiles(100, 3, 1, 0.6, 7) >= R.pairs_for_tiles(100, 3, 1, 0.8, 7), "une couverture plus basse ne donne jamais moins")
  local prev = 0
  for t = 0, 600, 12 do
    local n = R.pairs_for_tiles(t, 3, 1, 0.8, 7)
    ck(n >= prev, "monotone en tuiles (" .. t .. ")")
    prev = n
  end
  -- 3. rangées ↔ paires
  ck(R.rows_for_pairs(6, 0.5, 0.3125) == 9, "6 paires nourrissent 9 rangées de fours de pierre")
  ck(R.pairs_for_rows(9, 0.5, 0.3125) == 6, "9 rangées demandent 6 paires")
  ck(R.rows_for_pairs(0, 0.5, 0.3125) == 0 and R.pairs_for_rows(0, 0.5, 0.3125) == 0, "rien en entrée, rien en sortie")
  ck(R.rows_for_pairs(3, 0, 0.3125) == 0 and R.pairs_for_rows(3, 0.5, 0) == 0, "débit nul : 0 (pas de division par zéro)")
  for p = 1, 20 do
    local rows = R.rows_for_pairs(p, 0.5, 0.3125)
    ck(rows == 0 or R.pairs_for_rows(rows, 0.5, 0.3125) <= p, "jamais un four privé de minerai (" .. p .. " paires)")
  end
  for rows = 1, 20 do
    ck(R.rows_for_pairs(R.pairs_for_rows(rows, 0.5, 0.3125), 0.5, 0.3125) >= rows, "les paires voulues nourrissent les rangées (" .. rows .. ")")
  end
  -- 4. échelle et essais
  local function ladder(t, b) return R.ladder(t, b, 3) end
  local l = ladder(7, 3)
  ck(#l == 3 and l[1] == 7 and l[2] == 5 and l[3] == 3, "échelle 7 → 5 → 3")
  l = ladder(7, 1)
  ck(l[1] == 7 and l[#l] == 1 and #l <= 3, "échelle jusqu'à 1")
  for top = 1, 8 do for bottom = 1, top do
    local lad = ladder(top, bottom)
    local okd = lad[1] == top and #lad <= 3 and lad[#lad] >= bottom
    for i = 2, #lad do okd = okd and lad[i] < lad[i - 1] end
    ck(okd, string.format("échelle (%d, %d) décroissante, bornée", top, bottom))
  end end
  l = ladder(2, 5)
  ck(#l == 1 and l[1] == 5, "sommet sous le plancher : le plancher")
  local a = R.attempts(7, 4, {})
  ck(a[1].n == 7 and a[1].cover == 0.8, "premier essai : la plus longue ligne à 80 %")
  local k = 0
  while a[k + 1] and a[k + 1].cover do k = k + 1 end
  ck(k >= 1 and k <= 3, "au plus 3 essais à la couverture visée")
  local tail = {}
  for i = k + 1, #a do tail[#tail + 1] = a[i] end
  local okt = #tail == 7
  for i, e in ipairs(tail) do okt = okt and e.n == 8 - i and e.cover == nil end
  ck(okt, "ensuite exactement l'ancien parcours : 7, 6, … 1 à la couverture minimale")
  local a2 = R.attempts(3, 1, { high = 0.9 })
  ck(a2[1].cover == 0.9, "la couverture visée est un réglage")
  ck(#R.attempts(0, 0, nil) >= 1 and R.attempts(0, 0, nil)[1].n >= 1, "sommet absurde : au moins un essai, d'au moins 1 paire")
  return bad
end

section("1 à 4. Règles contre les gabarits réels")
do
  local bad = suite(Rg, true)
  check(bad == 0, "la suite de contrôles passe sur les règles réelles (" .. bad .. " échec(s))")
end

section("2 bis. L'estimation par comptage est une BORNE HAUTE de ce que P.fit accepte (gisements compacts)")
do
  local lat = P.lattice({ x = 0.5, y = 0.5 })
  local x0, y0, x1, y1 = P.lot_rect(lat, 3, 3)
  local rect = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  local accepted, rejected = 0, 0
  -- gisement compact w × h (tuiles) posé au milieu du lot ; pour chaque ligne de 1 à 7 paires : si P.fit l'accepte à 80 %, le
  -- comptage de tuiles l'annonçait (condition nécessaire : 80 % de la zone minée porte du minerai donc le lot en compte au moins
  -- autant). L'inverse est faux (forme du gisement) : plan_drills redescend, et line_rows vérifie avec P.fit lui-même.
  for _, w in ipairs({ 5, 9, 10, 12, 16, 20, 24 }) do
    for _, h in ipairs({ 4, 6, 9, 12, 15, 18, 22 }) do
      local ore = {}
      local gx0, gy0 = x0 + math.floor((24 - w) / 2), y0 + math.floor((24 - h) / 2)
      for y = gy0, gy0 + h - 1 do for x = gx0, gx0 + w - 1 do ore[P.tkey(x, y)] = true end end
      local ub = Rg.pairs_for_tiles(w * h, dsp.w, reach, 0.8, 7)
      for n = 1, 7 do
        local fit = P.fit(M.GEN.drills("iron-ore", n), rect, { ore = ore, cover_min = 0.8, free = function() return true end })
        if fit then
          accepted = accepted + 1
          check(n <= ub, string.format("gisement %d×%d : P.fit accepte %d paire(s) à 80 %% mais le comptage n'en annonce que %d", w, h, n, ub))
        else
          rejected = rejected + 1
        end
      end
    end
  end
  check(accepted >= 20 and rejected >= 20, "assez de cas des deux côtés (" .. accepted .. " acceptés, " .. rejected .. " refusés)")
end

section("2 ter. cover_min de P.fit")
do
  local lat = P.lattice({ x = 0.5, y = 0.5 })
  local x0, y0, x1, y1 = P.lot_rect(lat, 3, 3)
  local rect = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  -- gisement : la moitié nord d'une ligne de 6 paires seulement (couverture ≈ 0,6 de 6 paires)
  local g = M.GEN.drills("iron-ore", 6)
  local ore = {}
  for y = y0 + 1, y0 + 12 do for x = x0 + 4, x0 + 14 do ore[P.tkey(x, y)] = true end end
  local lo = P.fit(g, rect, { ore = ore })
  local hi = P.fit(g, rect, { ore = ore, cover_min = 0.8 })
  check(lo ~= nil and lo.cover >= P.DRILL_COVER - 1e-9, "couverture minimale du plan : ligne acceptée (" .. tostring(lo and lo.cover) .. ")")
  check(hi == nil or hi.cover >= 0.8 - 1e-9, "à 80 % visés, jamais une ligne moins couverte")
  local def = P.fit(g, rect, { ore = ore, cover_min = nil })
  check(def and lo and def.ox == lo.ox and def.oy == lo.oy and def.k == lo.k, "sans cover_min : exactement le placement d'avant")
end

section("5. Mutants")
do
  local mutants = {
    { "zone : portée oubliée", function(R) R.area = function(s, n, rc) return (2 * s + 1) * (n * s) end end },
    { "zone : largeur d'un seul côté", function(R) R.area = function(s, n, rc) return (s + 1 + 2 * rc) * (n * s + 2 * rc) end end },
    { "paires : inégalité stricte", function(R) R.pairs_for_tiles = function(t, s, rc, c, mx)
        if type(t) ~= "number" or t <= 0 then return 0 end
        local best = 0
        for n = 1, mx do if c * R.area(s, n, rc) < t then best = n else break end end
        return best end end },
    { "paires : couverture ignorée", function(R) R.pairs_for_tiles = function(t, s, rc, c, mx)
        if type(t) ~= "number" or t <= 0 then return 0 end
        local best = 0
        for n = 1, mx do if R.area(s, n, rc) <= t then best = n else break end end
        return best end end },
    { "paires : pas de borne", function(R) R.pairs_for_tiles = function(t, s, rc, c, mx)
        if type(t) ~= "number" or t <= 0 then return 0 end
        local best = 0
        for n = 1, 64 do if c * R.area(s, n, rc) <= t then best = n else break end end
        return best end end },
    { "rangées : arrondi par excès", function(R) R.rows_for_pairs = function(p, dr, cap)
        if p <= 0 or dr <= 0 or cap <= 0 then return 0 end
        return math.ceil(p * dr / cap - 1e-9) end end },
    { "paires : arrondi par défaut", function(R) R.pairs_for_rows = function(rows, dr, cap)
        if rows <= 0 or dr <= 0 or cap <= 0 then return 0 end
        return math.max(1, math.floor(rows * cap / dr + 1e-9)) end end },
    { "échelle : croissante", function(R) R.ladder = function(top, bottom) return { bottom, top } end end },
    { "essais : pas de repli à la couverture minimale", function(R) R.attempts = function(top, bottom, covers)
        local out = {}
        for _, n in ipairs(R.ladder(top, bottom, 3)) do out[#out + 1] = { n = n, cover = 0.8 } end
        return out end end },
    { "essais : repli qui oublie la plus petite ligne", function(R) R.attempts = function(top, bottom, covers)
        local out = {}
        for _, n in ipairs(R.ladder(top, bottom, 3)) do out[#out + 1] = { n = n, cover = 0.8 } end
        for n = top, 2, -1 do out[#out + 1] = { n = n } end
        return out end end },
    { "portée : toujours 0", function(R) R.reach = function() return 0 end end },
  }
  local survivors = 0
  for _, m in ipairs(mutants) do
    local R = {}
    for k, v in pairs(Rg) do R[k] = v end
    m[2](R)
    local bad = suite(R, false)
    check(bad > 0, "mutant refusé : " .. m[1])
    if bad == 0 then survivors = survivors + 1 end
  end
  check(survivors == 0, "aucun mutant survivant")
  print(string.format("[RANGEES] mutants : %d refusés sur %d", #mutants - survivors, #mutants))
end

print(string.format("[RANGEES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
