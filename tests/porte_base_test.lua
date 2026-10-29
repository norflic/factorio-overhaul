--[[
  Lot PORTE-BASE : banc PUR de la zone de base par densité de bâtiments (shared/ai3/base.lua) et de la répartition des morts
  dans / hors de la base (Base.split_deaths), lue par la porte de la défense (script/ai3/comportement.lua, M.gate).
  Lancement : lua5.2 tests/porte_base_test.lua (depuis la racine du mod). Mutants : chaque règle cassée fait échouer au moins
  un contrôle.
]]
package.path = "./?.lua;" .. package.path
local Base = require("shared.ai3.base")
local Rg = require("shared.ai3.reglages")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 if not quiet then print("  ECHEC : " .. msg) end end
end

local function machines(cx, cy, n, step)
  -- n bâtiments en carré autour de (cx, cy), au pas `step` (3 : machines 3x3 jointives)
  local out, side = {}, math.ceil(math.sqrt(n))
  for i = 0, n - 1 do
    out[#out + 1] = { x = cx + (i % side) * step, y = cy + math.floor(i / side) * step, w = 1 }
  end
  return out
end
local function concat(...)
  local out = {}
  for _, l in ipairs({ ... }) do for _, e in ipairs(l) do out[#out + 1] = e end end
  return out
end

local function all_checks()
  local HQ = { x = 0.5, y = 0.5 }
  -- 1. Poids par rôle (aucun nom) : fabriques, foreuses, tourelles 1 ; tapis, bras, poteaux, tuyaux (logistique), murs 0.
  check(Base.type_weight("assembling-machine", Rg.ENTITY_ROLE) == 1, "poids : machine d'assemblage 1")
  check(Base.type_weight("mining-drill", Rg.ENTITY_ROLE) == 1, "poids : foreuse 1")
  check(Base.type_weight("ammo-turret", Rg.ENTITY_ROLE) == 1, "poids : tourelle 1")
  check(Base.type_weight("transport-belt", Rg.ENTITY_ROLE) == 0, "poids : tapis 0 (linéaire)")
  check(Base.type_weight("electric-pole", Rg.ENTITY_ROLE) == 0, "poids : poteau 0 (linéaire)")
  check(Base.type_weight("wall", Rg.ENTITY_ROLE) == 0, "poids : mur 0 (linéaire)")
  check(Base.type_weight("character", Rg.ENTITY_ROLE) == 0, "poids : personnage 0")
  check(Base.type_weight("inconnu", Rg.ENTITY_ROLE) == 0, "poids : type inconnu 0")
  local st = Base.scan_types(Rg.ENTITY_TYPES, Rg.ENTITY_ROLE)
  local has_belt, has_furnace = false, false
  for _, ty in ipairs(st) do
    if ty == "transport-belt" then has_belt = true end
    if ty == "furnace" then has_furnace = true end
  end
  check(has_furnace and not has_belt, "types relevés : fours oui, tapis non (" .. #st .. " types)")

  -- 2. QG seul (aucun bâtiment) : la case du QG et sa marge (3 x 3 cases).
  local z0 = Base.build({}, HQ, 10)
  check(z0.n == 9 and Base.contains(z0, 1, 1) and Base.contains(z0, -7, -7) and not Base.contains(z0, 17, 1),
    "QG seul : 9 cases (" .. z0.n .. "), le QG dedans, 17 tuiles plus loin dehors")

  -- 3. Base principale : 16 machines jointives autour du QG ; avant-poste bâti de 8 machines à 200 tuiles ; paire de tourelles
  --    isolée sur la route (x = 100) ; ligne de tapis (poids 0) et machines espacées d'une case sur deux entre les deux.
  local main = machines(2, 2, 16, 3)
  local outpost = machines(200, 0, 8, 3)
  local pair = { { x = 100, y = 2, w = 1 }, { x = 102, y = 2, w = 1 } }
  local belts = {}
  for x = 20, 190 do belts[#belts + 1] = { x = x + 0.5, y = 1.5, w = 0 } end
  local sparse = {}
  for x = 40, 180, 16 do sparse[#sparse + 1] = { x = x, y = 40, w = 1 } end
  local ents = concat(main, outpost, pair, belts, sparse)
  local z = Base.build(ents, HQ, 100)
  check(Base.contains(z, 5, 5) and Base.contains(z, 11, 11), "base principale dans la zone")
  check(Base.contains(z, 203, 3), "avant-poste bâti (8 machines) : îlot de base")
  check(not Base.contains(z, 101, 2), "paire de tourelles isolée (poids 2 < " .. Base.MIN_W .. ") : pas une base")
  check(not Base.contains(z, 60, 1.5) and not Base.contains(z, 150, 1.5), "ligne de tapis : pas une base (à perpète entre les deux)")
  check(not Base.contains(z, 72, 40), "machines espacées d'une case sur deux : aucune case dense")
  check(z.comps == 2, "2 composantes gardées (QG et avant-poste) (" .. z.comps .. ")")
  check(z.comps_all == 3, "3 composantes denses (dont la paire de tourelles) (" .. z.comps_all .. ")")
  check(z.ents == #ents and z.w == #main + #outpost + #pair + #sparse, "bâtiments lus et poids compté")

  -- 4. Marge : une case autour de la zone gardée (« proche de la base »), pas deux.
  -- La base principale couvre les cases 0..1 (x de 2 à 11) : la case 2 (16-23) est dans la marge, la case 3 (24-31) non.
  check(Base.contains(z, 20, 5) and not Base.contains(z, 28, 5), "marge d'une case : 20 dedans, 28 dehors")

  -- 5. Déterminisme : ordre d'entrée inversé, même zone.
  local rev = {}
  for i = #ents, 1, -1 do rev[#rev + 1] = ents[i] end
  local zr = Base.build(rev, HQ, 100)
  local same = zr.n == z.n and zr.comps == z.comps and zr.dense == z.dense
  for k in pairs(z.cells) do if not zr.cells[k] then same = false end end
  check(same, "ordre des bâtiments inversé : même zone")

  -- 6. Connexité par la diagonale : deux groupes de 4 machines en cases diagonales (poids 4 chacun, 8 ensemble >= MIN_W).
  local diag = concat(machines(400, 400, 4, 2), machines(408, 408, 4, 2))
  local zd = Base.build(diag, HQ, 0)
  check(Base.contains(zd, 401, 401) and Base.contains(zd, 409, 409) and zd.comps == 1,
    "deux cases denses en diagonale : une composante (poids 8) gardée")
  local zs = Base.build(machines(400, 400, 4, 2), HQ, 0)
  check(not Base.contains(zs, 401, 401), "une case dense seule de poids 4 : pas gardée")

  -- 7. Composante VOISINE du QG gardée même légère (le QG en fait partie).
  local zq = Base.build({ { x = 9, y = 1, w = 1 }, { x = 10, y = 2, w = 1 } }, HQ, 0)
  check(zq.comps == 1 and Base.contains(zq, 20, 1) and not Base.contains(zq, 25, 1), "paire voisine du QG : base principale (marge comprise)")

  -- 8. Répartition des morts de l'heure le long d'une route (r = 32) : dans la base, hors d'elle, au QG (exclue), trop vieille.
  local H = 216000
  local pts = { { x = 0, y = 0 }, { x = 100, y = 0 }, { x = 200, y = 0 } }
  local deaths = {
    { x = 6, y = 6, t = 1000 },              -- base principale
    { x = 100, y = 10, t = 1000 },           -- route, près de la paire de tourelles (pas une base)
    { x = 205, y = 5, t = 1000 },            -- avant-poste bâti
    { x = 1, y = 1, t = 1000, home = true }, -- au QG : exclue (règle d'IA3-k)
    { x = 150, y = 0, t = -H },              -- hors de l'heure
    { x = 100, y = 200, t = 1000 },          -- loin de la route
  }
  local n_in, n_out = Base.split_deaths(z, deaths, pts, 32, 2000, H)
  check(n_in == 2 and n_out == 1, "morts : 2 dans la base, 1 hors (" .. n_in .. ", " .. n_out .. ")")
  local i2, o2 = Base.split_deaths(z, { { x = 6, y = 6, t = 1000 }, { x = 8, y = 8, t = 1000 } }, pts, 32, 2000, H)
  check(i2 == 2 and o2 == 0, "deux morts dans la base, aucune hors")
  local i3, o3 = Base.split_deaths(nil, { { x = 6, y = 6, t = 1000 } }, pts, 32, 2000, H)
  check(i3 == 0 and o3 == 1, "sans zone : toute mort est hors de la base (côté prudent)")

  -- 9. Cache : une zone sert Base.PERIOD ticks.
  check(Base.stale(nil, 0) and not Base.stale(z, 100 + Base.PERIOD - 1) and Base.stale(z, 100 + Base.PERIOD) and Base.stale(z, 50),
    "zone périmée après Base.PERIOD ticks (ou tick antérieur)")
  check(Base.area(z) == z.n * Base.CELL * Base.CELL, "surface en tuiles carrées")

  -- 10. Clés : aller-retour en coordonnées négatives.
  local okk = true
  for _, c in ipairs({ { 0, 0 }, { -1, -1 }, { -300, 250 }, { 12, -40 } }) do
    local cx, cy = Base.unkey(Base.key(c[1], c[2]))
    if cx ~= c[1] or cy ~= c[2] then okk = false end
  end
  check(okk, "clés de case : aller-retour")
end

all_checks()
print(string.format("[PORTE-BASE] contrôles : %d OK, %d ECHEC(S)", passes, failures))

-- Mutants : chaque règle cassée doit faire échouer au moins un contrôle.
local function mutant(name, apply)
  local saved = {}
  for k, v in pairs(Base) do saved[k] = v end
  local saved_role = {}
  for k, v in pairs(Base.ROLE_W) do saved_role[k] = v end
  apply()
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(all_checks)
  quiet = false
  local caught = (not ok) or failures > f0
  passes, failures = p0, f0
  for k in pairs(Base) do Base[k] = nil end
  for k, v in pairs(saved) do Base[k] = v end
  for k in pairs(Base.ROLE_W) do Base.ROLE_W[k] = nil end
  for k, v in pairs(saved_role) do Base.ROLE_W[k] = v end
  return caught, name
end

local mutants = {
  { "seuil de densité à 1", function() Base.DENSE = 1 end },
  { "aucune composante minimale", function() Base.MIN_W = 0 end },
  { "pas de marge", function() Base.MARGIN = 0 end },
  { "marge de 2 cases", function() Base.MARGIN = 2 end },
  { "murs comptés", function() Base.LINEAR_TYPES = {} end },
  { "logistique comptée", function() Base.ROLE_W.logistique = 1 end },
  { "QG hors de la zone", function()
    local b = Base.build
    Base.build = function(ents, hq, tick, opts) return b(ents, nil, tick, opts) end
  end },
  { "toute mort dans la base", function() Base.contains = function() return true end end },
  { "morts au QG comptées", function()
    Base.split_deaths = function(zone, deaths, pts, r, tick, hour)
      local r2, a, b = r * r, 0, 0
      for _, d in ipairs(deaths) do
        if tick - d.t < hour then
          for _, p in ipairs(pts) do
            local dx, dy = p.x - d.x, p.y - d.y
            if dx * dx + dy * dy <= r2 then
              if zone and zone.cells[Base.key(Base.cell(d.x), Base.cell(d.y))] then a = a + 1 else b = b + 1 end
              break
            end
          end
        end
      end
      return a, b
    end
  end },
  { "connexité sans diagonale", function()
    local b = Base.build
    Base.build = function(ents, hq, tick, opts)
      -- seules les composantes à une case : poids d'une case contre MIN_W
      local z = b(ents, hq, tick, opts)
      local per = {}
      for _, e in ipairs(ents) do
        local k = Base.key(Base.cell(e.x), Base.cell(e.y))
        per[k] = (per[k] or 0) + (e.w or 1)
      end
      local hk = hq and Base.key(Base.cell(hq.x), Base.cell(hq.y))
      for k, w in pairs(per) do
        if w < Base.MIN_W and k ~= hk then
          local cx, cy = Base.unkey(k)
          local near_hq = false
          if hk then
            local hx, hy = Base.unkey(hk)
            near_hq = math.abs(cx - hx) <= 2 and math.abs(cy - hy) <= 2
          end
          if not near_hq then
            for dx = -1, 1 do for dy = -1, 1 do z.cells[Base.key(cx + dx, cy + dy)] = nil end end
          end
        end
      end
      return z
    end
  end },
}
local caught_n = 0
for _, m in ipairs(mutants) do
  local caught, name = mutant(m[1], m[2])
  check(caught, "mutant non détecté : " .. name)
  if caught then caught_n = caught_n + 1 end
end
print(string.format("[PORTE-BASE] mutants : %d/%d détectés", caught_n, #mutants))
print(string.format("[PORTE-BASE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
