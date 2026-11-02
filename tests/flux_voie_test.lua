--[[
  Tests hors jeu du lot FLUX-VOIE (retour du DC du 2/11 sur 0.6.34, point 15 : « deux rangées de charbon [...] le fer ne peut pas
  descendre » ; pur, aucune API Factorio). Usage, depuis la racine du mod :   lua5.2 tests/flux_voie_test.lua

  Cause établie : le moteur fait miner à une foreuse TOUT ce que couvre sa zone ; P.fit ne comptait que les tuiles du minerai visé
  (opts.ore) : une ligne de foreuses de fer dont la zone recouvre une tuile de charbon met du charbon sur la voie du minerai de la
  fonderie, il s'y accumule (les fours n'en prennent que leur combustible) et la voie se bouche.

  1. P.fit refuse une ligne dont la zone recouvre une tuile étrangère (opts.foreign) ; raison « minerai mele » ;
  2. sans tuile étrangère (nil, vide), le placement est identique à celui d'avant ;
  3. le placement rendu ne recouvre AUCUNE tuile étrangère (vérifié sur les tuiles minées du gabarit tourné) ;
  4. tolérance explicite (foreign_max) ;
  5. mutants : la règle retirée ou faussée est refusée.
]]
package.path = "./?.lua;" .. package.path

local P = require("shared.team.plan")
local M = require("shared.team.modules")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local lat = P.lattice({ x = 0.5, y = 0.5 })
local x0, y0, x1, y1 = P.lot_rect(lat, 3, 3)
local rect = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2

local function full_ore()
  local ore = {}
  for y = y0, y1 - 1 do for x = x0, x1 - 1 do ore[P.tkey(x, y)] = true end end
  return ore
end

--- Tuiles minées du gabarit tourné de k quarts de tour, posé en (ox, oy) : combien portent une tuile étrangère.
local function foreign_under(g, fit, foreign)
  local r = fit.k == 0 and g or M.rotate(g, fit.k)
  local n = 0
  for _, t in ipairs(M.resource_tiles(r)) do
    if not t.well and foreign[P.tkey(fit.ox + t[1], fit.oy + t[2])] then n = n + 1 end
  end
  return n
end

local g = M.GEN.drills("iron-ore", 3)
assert(g, "gabarit de foreuses")
local ore = full_ore()
local toward = { x = cx, y = cy + 70 }

--- La suite de contrôles, rejouée sur la vraie fonction et sur des mutants. Rend le nombre d'échecs.
local function suite(Pl, verbose)
  local bad = 0
  local function ck(cond, msg)
    if not cond then bad = bad + 1; if verbose then print("  ECHEC : " .. msg) end end
  end
  -- 2. sans étranger : placement d'avant
  local base = Pl.fit(g, rect, { ore = ore, toward = toward })
  ck(base ~= nil, "gabarit posé sans étranger")
  local e1 = Pl.fit(g, rect, { ore = ore, toward = toward, foreign = {} })
  local e2 = Pl.fit(g, rect, { ore = ore, toward = toward, foreign = nil })
  ck(base and e1 and e2 and e1.k == base.k and e1.ox == base.ox and e1.oy == base.oy and e2.ox == base.ox, "étranger vide ou absent : placement identique")
  if not base then return bad end
  -- 1 et 3. une tuile de charbon DANS la zone minée du meilleur placement : le placement change (ou est refusé), sans la recouvrir
  local r0 = base.k == 0 and g or M.rotate(g, base.k)
  local tiles = M.resource_tiles(r0)
  local t = tiles[math.floor(#tiles / 2)]
  local foreign = { [P.tkey(base.ox + t[1], base.oy + t[2])] = true }
  local f1, why1 = Pl.fit(g, rect, { ore = ore, toward = toward, foreign = foreign })
  ck(f1 == nil or not (f1.k == base.k and f1.ox == base.ox and f1.oy == base.oy), "la ligne ne reste pas sur la tuile étrangère")
  ck(f1 == nil or foreign_under(g, f1, foreign) == 0, "le placement rendu ne recouvre aucune tuile étrangère")
  -- 1. charbon partout (1 tuile sur 3, motif régulier) : aucune ligne ne tient, raison « minerai mele »
  local dense = {}
  for y = y0 - 3, y1 + 3 do for x = x0 - 3, x1 + 3 do if (x + 2 * y) % 3 == 0 then dense[P.tkey(x, y)] = true end end end
  local f2, why2 = Pl.fit(g, rect, { ore = ore, toward = toward, foreign = dense })
  ck(f2 == nil, "gisement mêlé partout : refusé")
  ck(why2 == "minerai mele", "raison « minerai mele » (" .. tostring(why2) .. ")")
  -- 4. tolérance explicite : la même zone passe si on en tolère assez
  local f3 = Pl.fit(g, rect, { ore = ore, toward = toward, foreign = dense, foreign_max = 1000 })
  ck(f3 ~= nil, "foreign_max assez grand : posé")
  -- une tuile étrangère HORS de toute zone minée (loin du lot) ne gêne pas
  local far = { [P.tkey(x1 + 40, y1 + 40)] = true }
  local f4 = Pl.fit(g, rect, { ore = ore, toward = toward, foreign = far })
  ck(f4 ~= nil and f4.ox == base.ox and f4.oy == base.oy and f4.k == base.k, "étranger hors de la zone : placement inchangé")
  -- déterminisme
  local f5, f6 = Pl.fit(g, rect, { ore = ore, toward = toward, foreign = foreign }), Pl.fit(g, rect, { ore = ore, toward = toward, foreign = foreign })
  ck((f5 == nil) == (f6 == nil) and (f5 == nil or (f5.k == f6.k and f5.ox == f6.ox and f5.oy == f6.oy)), "déterministe")
  return bad
end

section("1 à 4. P.fit et les tuiles étrangères")
do
  local bad = suite(P, true)
  check(bad == 0, "suite sur la vraie fonction : " .. bad .. " échec(s)")
end

section("5. Mutants")
do
  local f = assert(io.open("shared/team/plan.lua", "rb"))
  local src = f:read("*a")
  f:close()
  local function mutant(old, new)
    local a, b = src:find(old, 1, true)
    assert(a, "texte du mutant introuvable : " .. old)
    local chunk = assert(load(src:sub(1, a - 1) .. new .. src:sub(b + 1), "=plan_mutant", "t"))
    return chunk()
  end
  local mutants = {
    { "règle retirée", "if ok and res and opts.foreign and next(opts.foreign) then", "if false then" },
    { "tolérance infinie", "if n > (opts.foreign_max or P.FOREIGN_MAX) then", "if n > 1e9 then" },
    { "étranger compté en moins (une tuile tolérée)", "if n > (opts.foreign_max or P.FOREIGN_MAX) then", "if n > (opts.foreign_max or 1) then" },
    { "mauvaise raison", [[(foreign_rej > 0 and "minerai mele" or "minerai")]], [["minerai"]] },
    { "tuile décalée d'une colonne", "opts.foreign[tkey(ox + t[1], oy + t[2])]", "opts.foreign[tkey(ox + t[1] + 1, oy + t[2])]" },
  }
  local survivors = 0
  for _, m in ipairs(mutants) do
    local ok, Pm = pcall(mutant, m[2], m[3])
    local bad = 0
    if ok and type(Pm) == "table" then bad = suite(Pm, false) else bad = 1 end
    check(bad > 0, "mutant refusé : " .. m[1])
    if bad == 0 then survivors = survivors + 1 end
  end
  check(survivors == 0, "aucun mutant survivant")
  print(string.format("[FLUX-VOIE] mutants : %d refusés sur %d", #mutants - survivors, #mutants))
end

print(string.format("[FLUX-VOIE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
