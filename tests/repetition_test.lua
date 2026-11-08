--[[
  Tests hors jeu du lot FONTE-MULTI (répétition de la ligne de foreuses, saturation d'un gisement). Usage, depuis la racine du mod :
      lua5.2 tests/repetition_test.lua
  1. règle pure (shared/team/repetition.lua) : zone minée, minerai restant, taille de la ligne suivante, lignes voulues, convergence ;
  2. exécutant (script/team/build.lua) au moteur simulé réduit : zone minée d'une vraie ligne de 7 paires = Rg.area, minerai restant,
     la première ligne d'un gisement est mesurée comme avant (même table), la deuxième ne compte plus le minerai déjà miné ;
  3. câblage (lecture des sources) et mutants de la règle.
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end

local Rg = require("shared.team.rangees")
local M = require("shared.team.modules")
local RP_SRC = read("shared/team/repetition.lua")
local function load_rp(src) return assert(load(src, "=repetition", "t"))() end
local Rp = load_rp(RP_SRC)
local key = function(x, y) return x .. "," .. y end

---------------------------------------------------------------------------------------------------
section("1. Règle pure")
---------------------------------------------------------------------------------------------------
do
  local zone = {}
  check(Rp.zone_add(zone, 0, 0, 3, 1, key) == 25, "une foreuse 3x3 de portée 1 mine 5x5 = 25 tuiles")
  check(Rp.zone_add(zone, 0, 0, 3, 1, key) == 0, "la même foreuse ne compte pas deux fois")
  check(Rp.zone_add(zone, 3, 0, 3, 1, key) == 15, "une foreuse voisine ajoute 5 x 3 tuiles (deux colonnes en commun)")
  check(Rp.zone_add(nil, 0, 0, 3, 1, key) == 0 and Rp.zone_add({}, "a", 0, 3, 1, key) == 0 and Rp.zone_add({}, 0, 0, 0, 1, key) == 0, "entrées illisibles : rien")
  local ores = { axis = "x", foreign = { z = true } }
  local keys = {}
  for y = 0, 9 do for x = 0, 9 do local k = key(x, y); ores[k] = true; keys[#keys + 1] = k end end
  local z = {}
  Rp.zone_add(z, 2, 2, 3, 1, key) -- 5x5 = 25 tuiles
  local fr, n = Rp.fresh(ores, z, keys)
  check(n == 75, "100 tuiles de minerai - 25 minées = 75 (obtenu " .. tostring(n) .. ")")
  check(fr.axis == "x" and fr.foreign == ores.foreign, "axe et ressources étrangères gardés")
  check(fr[key(2, 2)] == nil and fr[key(0, 0)] == true and ores[key(2, 2)] == true, "tuile minée retirée de la copie, l'original intact")
  local fr2, n2 = Rp.fresh(ores, nil, keys)
  check(n2 == 100 and fr2[key(5, 5)], "sans zone : tout le minerai")
  -- échelle de couvertures
  local side, reach = 3, 1
  local full = Rg.area(side, 7, reach)
  check(full == 207, "ligne pleine de 7 paires : 207 tuiles")
  local n7, c7 = Rp.size_next(full, side, reach, { 0.8, 0.5, 0.3 }, 7)
  check(n7 >= 5 and c7 == 0.8, "207 tuiles de minerai : une ligne longue à 80 % (obtenu " .. n7 .. ")")
  local nb, cb = Rp.size_next(60, side, reach, { 0.8, 0.5, 0.3 }, 7)
  check(nb >= 1 and cb == 0.8, "60 tuiles : une ligne courte à 80 %")
  local nl, cl = Rp.size_next(30, side, reach, { 0.8, 0.5, 0.3 }, 7)
  check(nl >= 1 and cl and cl < 0.8, "30 tuiles : seule l'échelle basse (bord de gisement) pose une paire (cover " .. tostring(cl) .. ")")
  local n0, c0 = Rp.size_next(5, side, reach, { 0.8, 0.5, 0.3 }, 7)
  check(n0 == 0 and c0 == nil, "5 tuiles : rien")
  check(select(1, Rp.size_next(0, side, reach, { 0.8 }, 7)) == 0 and select(1, Rp.size_next(100, side, reach, nil, 7)) == 0 and select(1, Rp.size_next(nil, side, reach, { 0.8 }, 7)) == 0, "entrées vides ou illisibles : 0")
  -- lignes voulues : table de cas
  local per = 165
  local function lw(over)
    local s = { field = 600, covered = 0, per_line = per, free = 600, min_free = 8 }
    for k, v in pairs(over or {}) do s[k] = v end
    return Rp.lines_wanted(s)
  end
  local l, why = lw()
  check(l == 4 and why == "ok", "600 tuiles, rien de couvert : 4 lignes de 165 (obtenu " .. l .. " " .. why .. ")")
  l, why = lw({ covered = 330 }); check(l == 2 and why == "ok", "330 couvertes : 2 lignes de plus")
  l, why = lw({ covered = 596 }); check(l == 0 and why == "sature", "596/600 : saturé (bruit de bord)")
  l, why = lw({ free = 3 }); check(l == 0 and why == "reste_trop_petit", "3 tuiles libres : le reste est trop petit")
  l, why = lw({ last_gain = 2 }); check(l == 0 and why == "sans_progres", "la dernière ligne n'a rien apporté : on s'arrête")
  l, why = lw({ last_gain = 140 }); check(l >= 1 and why == "ok", "la dernière ligne a apporté 140 tuiles : on continue")
  l, why = lw({ field = 5000, free = 5000 }); check(l == Rp.MAX_LINES and why == "plafond", "5000 tuiles : plafond de sûreté")
  l, why = lw({ in_flight = 2 }); check(l == 2 and why == "ok", "2 lignes déjà demandées comptent pour 2 x per_line")
  l, why = lw({ free = 100 }); check(l == 1 and why == "ok", "100 tuiles libres : au plus 1 ligne (pas plus de lignes que de minerai libre)")
  l, why = lw({ field = 0 }); check(l == 0 and why == "invalide", "gisement vide : invalide")
  l, why = Rp.lines_wanted(nil); check(l == 0 and why == "invalide", "pas d'entrée : invalide")
  l, why = lw({ target = 0.5, covered = 330 }); check(l == 0 and why == "sature", "cible 50 % atteinte : saturé")
  -- convergence : chaque ligne apporte min(per_line, restant) ; arrêt en moins de MAX_LINES + 1 pas, jamais sans fin
  for _, field in ipairs({ 100, 300, 600, 1000, 1300 }) do
    local covered, steps, last = 0, 0, nil
    while steps < 40 do
      local n = Rp.lines_wanted({ field = field, covered = covered, per_line = per, free = field - covered, min_free = 8, last_gain = last })
      if n == 0 then break end
      local gain = math.min(per, field - covered) * n
      covered = covered + gain; last = gain; steps = steps + 1
    end
    check(steps <= Rp.MAX_LINES + 1 and field - covered <= Rp.EPS_TILES, string.format("gisement de %d tuiles : saturé en %d pas (couvert %d)", field, steps, covered))
  end
  check(Rp.TARGET == 1.0 and Rp.MAX_LINES == 8 and Rp.MIN_GAIN > 0 and Rp.EPS_TILES > 0, "constantes")
end

---------------------------------------------------------------------------------------------------
section("2. Exécutant au moteur simulé réduit (script/team/build.lua)")
---------------------------------------------------------------------------------------------------
local Mk = require("tests.mock_engine")
Mk.new_game({})
local Build = require("script.team.build")
local P = require("shared.team.plan")
local real_log = log
log = function() end

local ORE = "iron-ore"
local function drill_ents(pm, ox, oy)
  local gd = M.GEN.drills(ORE, pm)
  local inst = M.instantiate(gd, 0, ox, oy)
  local out = {}
  for _, e in ipairs(inst.entities) do out[#out + 1] = { name = e.name, x = e.position.x, y = e.position.y, dir = e.direction or 0, part = 2 } end
  return out
end
local function team(projects) return { key = "t", force = "player", build = { projects = projects or {}, order = {}, occ = {}, lots = {} } } end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

do
  local f = team({})
  check(count(Build.zone_mined(f)) == 0, "aucun projet : aucune zone minée")
  local ents = drill_ents(7, 0, 0)
  local f2 = team({ [7] = { id = 7, state = "fini", ents = ents } })
  local cnt = count(Build.zone_mined(f2))
  local nd = 0
  for _, e in ipairs(ents) do if M.spec(e.name).kind == "drill" then nd = nd + 1 end end
  check(nd == 14, "la ligne de 7 paires compte 14 foreuses (obtenu " .. nd .. ")")
  check(cnt == Rg.area(3, 7, 1), "zone minée de la ligne de 7 paires = Rg.area (207) : obtenu " .. cnt)
  local f3 = team({ [7] = { id = 7, state = "fini", abandoned = true, ents = ents }, [8] = { id = 8, state = "refuse", ents = ents } })
  check(count(Build.zone_mined(f3)) == 0, "projet abandonné ou refusé : sa zone ne compte pas")
  local half, held = {}, {}
  for i, e in ipairs(ents) do if i % 2 == 0 then half[#half + 1] = e else held[#held + 1] = e end end
  local f4 = team({ [7] = { id = 7, state = "fini", ents = half, ligne = { held = held } } })
  check(count(Build.zone_mined(f4)) == cnt, "pièces en attente comprises : même zone que la ligne entière")
  -- minerai : un champ de 30 x 30 autour de la ligne
  local ores = {}
  for y = -10, 19 do for x = -10, 19 do ores[P.tkey(x, y)] = true end end
  ores.axis = "y"
  local rect = { x0 = -10, y0 = -10, x1 = 20, y1 = 20 }
  local same, n_first = Build.fresh_ores(team({}), rect, ores)
  check(same == ores and n_first == 900, "première ligne du gisement : la même table, 900 tuiles (mesurée comme avant)")
  local fr, nf = Build.fresh_ores(f2, rect, ores)
  check(fr ~= ores and nf and nf < 900 and 900 - nf <= cnt and 900 - nf > 0, "deuxième ligne : le minerai déjà miné est retiré (" .. tostring(nf) .. " restantes sur 900, zone " .. cnt .. ")")
  check(fr.axis == "y", "l'axe du gisement est gardé")
  local n_all = Rg.pairs_for_tiles(900, 3, 1, 0.8, 7)
  local n_rest = Build.Rep.size_next(nf, 3, 1, { 0.8 }, 7)
  check(n_all == 7 and n_rest == 7, "champ de 900 tuiles : la deuxième ligne tient encore 7 paires sur " .. nf .. " tuiles restantes (" .. n_rest .. ")")
  -- un petit champ saturé par la première ligne : plus rien pour la deuxième
  local small = {}
  for k in pairs(Build.zone_mined(f2)) do small[k] = true end
  local fs, ns = Build.fresh_ores(f2, { x0 = -30, y0 = -30, x1 = 60, y1 = 60 }, small)
  check(ns == 0 and select(1, Build.Rep.size_next(ns, 3, 1, { 0.8, 0.5, 0.3 }, 7)) == 0, "champ entièrement miné par la première ligne : 0 tuile restante, aucune ligne de plus (" .. tostring(ns) .. ")")
  Build.REPETITION = false
  check(Build.fresh_ores(f2, rect, ores) == ores, "Build.REPETITION = false : la table d'origine, comme avant")
  Build.REPETITION = true
  -- invalidation de la mémoire du tick quand un plan de plus est posé
  local f5 = team({ [7] = { id = 7, state = "fini", ents = ents } })
  local ca = count(Build.zone_mined(f5))
  f5.build.projects[8] = { id = 8, state = "plan", ents = drill_ents(7, 0, 40) }
  local cb = count(Build.zone_mined(f5))
  check(cb == 2 * ca, "un plan posé dans le même tick agrandit la zone (" .. ca .. " -> " .. cb .. ")")
end
log = real_log

---------------------------------------------------------------------------------------------------
section("3. Câblage et mutants")
---------------------------------------------------------------------------------------------------
local BSRC = read("script/team/build.lua")
do
  check(BSRC:find('Build.Rep = require("shared.team.repetition")', 1, true) ~= nil, "build.lua charge la règle (champ de Build, pas une locale)")
  check(BSRC:find('if res and g.gen == "drills" and Build.REPETITION then', 1, true) ~= nil
    and BSRC:find("fopts.ore = fr", 1, true) ~= nil, "place_module : la ligne de foreuses se pose sur le minerai restant")
  check(BSRC:find("local fr, nf = Build.fresh_ores(f, rect, ores)\n      if fr ~= ores then ores = fr;", 1, true) ~= nil, "line_rows : la ligne se dimensionne sur le minerai restant")
  check(BSRC:find("[FO-REPETITION]", 1, true) ~= nil, "journal [FO-REPETITION]")
  local n_locals = 0
  for line in BSRC:gmatch("[^\n]+") do if line:find("^local ") then n_locals = n_locals + 1 end end
  check(n_locals <= 199, "build.lua : au plus 199 locales de bloc principal (obtenu " .. n_locals .. ", limite Lua 200)")
  check(not RP_SRC:find("[^i]pairs%(") and not RP_SRC:find("global[%.%[]") and not RP_SRC:find("game%.") and not RP_SRC:find("os%.clock"), "règle pure : aucun pairs, aucun global, aucune API moteur, aucun temps")
end
do
  local function suite(R)
    local bad = 0
    local function ck(c) if not c then bad = bad + 1 end end
    local z = {}
    ck(R.zone_add(z, 0, 0, 3, 1, key) == 25 and R.zone_add(z, 0, 0, 3, 1, key) == 0)
    local ores, keys = {}, {}
    for y = 0, 9 do for x = 0, 9 do local k = key(x, y); ores[k] = true; keys[#keys + 1] = k end end
    local zz = {}
    R.zone_add(zz, 2, 2, 3, 1, key)
    local _, n = R.fresh(ores, zz, keys)
    ck(n == 75)
    ck(select(1, R.size_next(30, 3, 1, { 0.8, 0.5, 0.3 }, 7)) >= 1)
    ck(select(1, R.size_next(5, 3, 1, { 0.8, 0.5, 0.3 }, 7)) == 0)
    local function lw(o) local s = { field = 600, covered = 0, per_line = 165, free = 600, min_free = 8 } for k, v in pairs(o or {}) do s[k] = v end return R.lines_wanted(s) end
    local l, w = lw(); ck(l == 4 and w == "ok")
    l, w = lw({ covered = 596 }); ck(l == 0 and w == "sature")
    l, w = lw({ free = 3 }); ck(l == 0 and w == "reste_trop_petit")
    l, w = lw({ last_gain = 2 }); ck(l == 0 and w == "sans_progres")
    l, w = lw({ field = 5000, free = 5000 }); ck(l == R.MAX_LINES and w == "plafond")
    l, w = lw({ in_flight = 2 }); ck(l == 2)
    l, w = lw({ free = 100 }); ck(l == 1)
    l, w = lw({ field = 0 }); ck(l == 0 and w == "invalide")
    return bad
  end
  check(suite(Rp) == 0, "la suite des mutants passe sur la règle réelle")
  local mutants = {
    { "la zone ignore la portée", "for ty = ty0 - reach, ty0 + side - 1 + reach do\n    for tx = tx0 - reach, tx0 + side - 1 + reach do", "for ty = ty0, ty0 + side - 1 do\n    for tx = tx0, tx0 + side - 1 do" },
    { "tuile minée comptée deux fois", "if not zone[k] then zone[k] = true; n = n + 1 end", "zone[k] = true; n = n + 1" },
    { "le minerai déjà miné n'est pas retiré", "if ores[k] and not (zone and zone[k]) then", "if ores[k] then" },
    { "échelle de couvertures sans repli", "for _, cv in ipairs(covers or {}) do", "for _, cv in ipairs({ (covers or {})[1] }) do" },
    { "saturé jamais déclaré", "if rest <= (num(s.eps) and s.eps or Rp.EPS_TILES) then return 0, \"sature\" end", "" },
    { "reste trop petit ignoré", "if num(s.free) and s.free < (num(s.min_free) and s.min_free or Rp.EPS_TILES) then return 0, \"reste_trop_petit\" end", "" },
    { "garde-fou sans progrès retiré", "if num(s.last_gain) and s.last_gain < (num(s.min_gain) and s.min_gain or Rp.MIN_GAIN) then return 0, \"sans_progres\" end", "" },
    { "plafond retiré", "if n > cap then return cap, \"plafond\" end", "" },
    { "lignes en vol ignorées", "- (num(s.in_flight) and s.in_flight or 0) * s.per_line", "" },
    { "plus de lignes que de minerai libre", "if num(s.free) then n = min(n, max(1, ceil(s.free / s.per_line - EPS))) end", "" },
  }
  local killed = 0
  for _, m in ipairs(mutants) do
    local i = RP_SRC:find(m[2], 1, true)
    if not i then
      check(false, "mutant « " .. m[1] .. " » : texte introuvable dans repetition.lua")
    else
      local src = RP_SRC:sub(1, i - 1) .. m[3] .. RP_SRC:sub(i + #m[2])
      local ok, R = pcall(load_rp, src)
      local bad = ok and suite(R) or 1
      if bad > 0 then killed = killed + 1 else print("  mutant survivant : " .. m[1]) end
    end
  end
  check(killed == #mutants, "mutants refusés : " .. killed .. " sur " .. #mutants)
  print(string.format("[REPETITION] mutants : %d refusés sur %d", killed, #mutants))
end

print(string.format("[REPETITION] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
