--[[
  Lot X10-CHEMINS (L5) : banc HORS JEU du service de chemins (fo-logs/2026-11-07_X10/CHEMINS_CRITERES.md §1.2).
    1. Règle pure (shared/nav/chemins.lua) : table de vérité de Ch.precheck, rayon contrôlé, couche, chunks du disque ;
    2. JUSTESSE sur 2 000 disques tirés d'une graine (tuiles d'eau et de terre, rayons de 1 à 24) : la règle ne refuse JAMAIS un
       but qui a une tuile de terre à moins de `radius` (point le plus proche de la tuile), quelle que soit la façon dont le moteur
       compte une tuile dans un disque (centre, recouvrement, tuile entière) ; UTILITÉ : elle refuse tout disque tout eau ;
    3. service au moteur simulé (script/core/path_service.lua) : but au milieu d'un lac refusé SANS demande au moteur, « no_path »
       livré au tick même ; but au bord du lac demandé ; chunk non généré, prototype sans « player-layer » : demandés ;
    4. mutants, qui DOIVENT être vus : marge retirée, `invert` oublié, refus pour un prototype sans la couche, départ refusé au
       lieu d'être demandé sans marge, refus non livré au gestionnaire.
  Lancement : lua5.2 tests/chemins_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
end
local function section(name) if not quiet then print("== " .. name) end end

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

--- Remplace exactement UNE occurrence de `old` dans `src` (texte brut) ; erreur sinon.
local function patch(src, old, new)
  local i, j = src:find(old, 1, true)
  assert(i, "mutant : texte introuvable : " .. old)
  assert(not src:find(old, j + 1, true), "mutant : texte en double : " .. old)
  return src:sub(1, i - 1) .. new .. src:sub(j + 1)
end

local CH_SRC = read("shared/nav/chemins.lua")
local PS_SRC = read("script/core/path_service.lua")

--- Installe des sources (mutées ou non) : package.preload, que M.load_mod ne vide pas.
local function install(ch_src, ps_src)
  package.preload["shared.nav.chemins"] = ch_src and function() return assert(load(ch_src, "=chemins_mutant", "t"))() end or nil
  package.preload["script.core.path_service"] = ps_src and function() return assert(load(ps_src, "=path_service_mutant", "t"))() end or nil
  package.loaded["shared.nav.chemins"] = nil
  package.loaded["script.core.path_service"] = nil
end

---------------------------------------------------------------------------------------------------
-- 1. Règle pure
---------------------------------------------------------------------------------------------------
local function pure_checks(Ch)
  section("Règle pure : table de vérité de Ch.precheck")
  check(Ch.check_radius(2) == 3.5 and Ch.check_radius(nil) == 2.5, "rayon contrôlé = radius + 1,5 (radius par défaut 1)")
  check(Ch.checks_goal({ "player-layer", "train-layer" }) and not Ch.checks_goal({ "object-layer" }) and not Ch.checks_goal(nil),
    "le contrôle du but ne vaut que pour un masque qui a player-layer")
  local P = Ch.precheck
  check(P({ goal_land = 0, goal_blocking = 3, goal_generated = true, pad = 0.15 }) == "refuse_water", "disque sans terre, chunks générés : refus")
  check(P({ goal_land = 0, goal_blocking = 3, goal_generated = false, pad = 0.15 }) == "request", "chunk non généré : demandé")
  check(P({ goal_land = 0, goal_blocking = 0, goal_generated = true, pad = 0.15 }) == "request", "aucune tuile vue (faux moteur) : demandé")
  check(P({ goal_land = 1, goal_blocking = 3, goal_generated = true, pad = 0.15 }) == "request", "une tuile de terre : demandé")
  check(P({ pad = 0.15 }) == "request", "pas de contrôle du but (prototype sans la couche) : demandé")
  check(P({ goal_land = 2, start_blocked = true, start_free_bare = true, pad = 0.15 }) == "unpad", "départ bloqué élargi, libre nu : sans marge")
  check(P({ goal_land = 2, start_blocked = true, start_free_bare = false, pad = 0.15 }) == "request", "départ bloqué même nu : demandé quand même")
  check(P({ goal_land = 2, start_blocked = true, start_free_bare = true, pad = 0 }) == "request", "marge déjà nulle : demandé")
  check(P({ goal_land = 0, goal_blocking = 1, goal_generated = true, start_blocked = true, start_free_bare = true, pad = 0.15 }) == "refuse_water",
    "but impossible ET départ bloqué : refus (le but suffit)")
  local cs = Ch.disc_chunks(31, -1, 3.5)
  check(#cs == 4 and cs[1][1] == 0 and cs[1][2] == -1 and cs[4][1] == 1 and cs[4][2] == 0, "chunks du disque : (0,-1) (1,-1) (0,0) (1,0)")
end

---------------------------------------------------------------------------------------------------
-- 2. Justesse et utilité sur des disques tirés d'une graine
---------------------------------------------------------------------------------------------------
local function lcg(seed)
  local s = seed
  return function(n)
    s = (s * 1103515245 + 12345) % 2147483648
    return math.floor(s / 65536) % n -- bits de poids fort (les bits faibles d'un tel générateur bouclent)
  end
end

--- Distance du but au point le plus proche de la tuile (tx, ty), et au coin le plus loin.
local function near_far(tx, ty, gx, gy)
  local nx = math.max(tx, math.min(gx, tx + 1))
  local ny = math.max(ty, math.min(gy, ty + 1))
  local fx = math.max(math.abs(gx - tx), math.abs(gx - tx - 1))
  local fy = math.max(math.abs(gy - ty), math.abs(gy - ty - 1))
  return math.sqrt((gx - nx) ^ 2 + (gy - ny) ^ 2), math.sqrt(fx * fx + fy * fy)
end

--- Tuiles comptées par le moteur dans le disque (gx, gy, R), selon la façon de compter : "centre", "recouvre", "entiere".
local function engine_count(water, gx, gy, R, mode, want_land)
  local n = 0
  for ty = math.floor(gy - R) - 1, math.floor(gy + R) + 1 do
    for tx = math.floor(gx - R) - 1, math.floor(gx + R) + 1 do
      local inside
      if mode == "centre" then
        inside = (tx + 0.5 - gx) ^ 2 + (ty + 0.5 - gy) ^ 2 <= R * R
      else
        local nd, fd = near_far(tx, ty, gx, gy)
        inside = (mode == "recouvre") and nd <= R or fd <= R
      end
      if inside and (water(tx, ty) ~= want_land) then n = n + 1 end
    end
  end
  return n
end

local function soundness(Ch, label)
  section("Justesse et utilité sur 2 000 disques " .. (label or ""))
  local rnd = lcg(20261107)
  local bad, refused, alleau, alleau_refused = 0, 0, 0, 0
  local first_bad
  for case = 1, 2000 do
    local radius = 1 + rnd(2300) / 100              -- 1 à 24
    local gx, gy = rnd(4000) / 100 - 20, rnd(4000) / 100 - 20
    local lake = rnd(4)                             -- 0 : îlots épars ; 1 à 3 : lac de rayon croissant autour du but
    local lr = radius + (lake - 1) * 2 + rnd(300) / 100
    local salt = rnd(1000000)
    local function water(tx, ty)
      if lake == 0 then return ((tx * 7919 + ty * 104729 + salt) % 10) < 7 end
      return (tx + 0.5 - gx) ^ 2 + (ty + 0.5 - gy) ^ 2 <= lr * lr
    end
    -- Référence : une tuile de terre a un point à moins de `radius` du but (fin de chemin possible).
    local possible = false
    for ty = math.floor(gy - radius) - 1, math.floor(gy + radius) + 1 do
      for tx = math.floor(gx - radius) - 1, math.floor(gx + radius) + 1 do
        if not water(tx, ty) and near_far(tx, ty, gx, gy) <= radius then possible = true end
      end
    end
    -- Disque tout eau au rayon contrôlé (toutes façons de compter) : doit être refusé.
    local R = Ch.check_radius(radius)
    local any_land_R = engine_count(water, gx, gy, R, "recouvre", true) > 0
    for _, mode in ipairs({ "centre", "recouvre", "entiere" }) do
      local land = engine_count(water, gx, gy, R, mode, true)
      local blocking = engine_count(water, gx, gy, R, mode, false)
      local act = Ch.precheck({ goal_land = land, goal_blocking = blocking, goal_generated = true, pad = 0.15 })
      if act == "refuse_water" then
        refused = refused + 1
        if possible then
          bad = bad + 1
          first_bad = first_bad or string.format("cas %d mode %s rayon %.2f but (%.2f, %.2f)", case, mode, radius, gx, gy)
        end
      end
      if not any_land_R and mode == "recouvre" then
        alleau = alleau + 1
        if act == "refuse_water" then alleau_refused = alleau_refused + 1 end
      end
    end
  end
  check(bad == 0, "aucun refus d'un but joignable (3 façons de compter) ; premier contre-exemple : " .. tostring(first_bad))
  check(alleau > 50 and alleau_refused == alleau, string.format("tout disque tout eau au rayon contrôlé est refusé (%d sur %d)", alleau_refused, alleau))
  check(refused > 0, "des refus ont lieu (" .. refused .. ")")
  return bad, alleau_refused, alleau
end

---------------------------------------------------------------------------------------------------
-- 3. Service au moteur simulé
---------------------------------------------------------------------------------------------------
local LAKE = { x = 200, y = 0, r = 12 }
local function lake_tile(x, y)
  local dx, dy = x + 0.5 - LAKE.x, y + 0.5 - LAKE.y
  if dx * dx + dy * dy <= LAKE.r * LAKE.r then return "water" end
  return "grass-1"
end

local function service_checks()
  section("Service au moteur simulé : refus sans demande au moteur")
  M.new_game({ tile_at = lake_tile, water_paths = true })
  local W = M.world()
  W.prototypes["x10-sans-couche"] = { type = "unit", max_health = 10,
    collision_box = { left_top = { x = -0.2, y = -0.2 }, right_bottom = { x = 0.2, y = 0.2 } }, collision_mask = { ["object-layer"] = true } }
  local PS = package.loaded["script.core.path_service"]
  local got = {}
  PS.register_handler("x10-test", function(owner, path, ticket, reason, tick) got[#got + 1] = { owner = owner, path = path, reason = reason, tick = tick } end)
  local function req(owner, goal, proto, radius)
    return PS.request("x10-test", owner, { surface = 1, proto = proto or "fo-companion", pad = 0.15, start = { x = 150, y = 0 },
      goal = goal, force = "player", radius = radius or 2, flags = { cache = true }, res = 0 })
  end
  local before = W.path_requests or 0
  req(1, { x = LAKE.x, y = LAKE.y })
  local t0 = game.tick
  M.run_ticks(1)
  local st = remote.call("fo-chemins", "stats")
  check((W.path_requests or 0) == before, "but au milieu du lac : aucune demande au moteur")
  check(#got == 1 and got[1].reason == "no_path" and got[1].tick == t0 + 1, "« no_path » livré au gestionnaire au tick même")
  check(st.refused_water == 1, "refus compté (refused_water = 1) : " .. tostring(st.refused_water))
  -- Bord du lac : le disque de rayon 3,5 a de la terre.
  req(2, { x = LAKE.x - LAKE.r + 1, y = LAKE.y })
  M.run_ticks(1)
  check((W.path_requests or 0) == before + 1, "but au bord du lac : demandé au moteur")
  -- Chunk non généré : demandé (on ne refuse pas sur une inconnue).
  local surf = game.surfaces[1]
  local gen = surf.is_chunk_generated
  surf.is_chunk_generated = function(c) if c.x == 6 and c.y == 0 then return false end return gen(c) end
  req(3, { x = LAKE.x, y = LAKE.y })
  M.run_ticks(1)
  surf.is_chunk_generated = gen
  check((W.path_requests or 0) == before + 2, "chunk du disque non généré : demandé au moteur")
  -- Prototype sans « player-layer » : pas de contrôle.
  req(4, { x = LAKE.x, y = LAKE.y }, "x10-sans-couche")
  M.run_ticks(1)
  check((W.path_requests or 0) == before + 3, "prototype sans player-layer : demandé au moteur")
  M.run_ticks(10)
  local fails = 0
  for _, g in ipairs(got) do if g.reason == "no_path" then fails = fails + 1 end end
  check(#got == 4, "les 4 demandes ont une réponse (" .. #got .. ")")
  check((W.water_requests or 0) >= 2, "le moteur simulé fait échouer les demandes vers le lac (" .. tostring(W.water_requests) .. ")")
  check(remote.call("fo-chemins", "stats").refused_water == 1, "un seul refus en tout")
  -- Journal : allumé, une ligne par demande ; éteint par défaut.
  check(remote.call("fo-chemins", "journal", true) == true, "journal allumé par l'interface")
  local nlog = #W.logs
  req(5, { x = LAKE.x, y = LAKE.y })
  req(6, { x = 100, y = 0 })
  M.run_ticks(6)
  local j = 0
  for i = nlog + 1, #W.logs do if tostring(W.logs[i]):find("[FO-CHEMINS-J]", 1, true) then j = j + 1 end end
  check(j == 3, "journal : refus, émission et fin (3 lignes) : " .. j)
  remote.call("fo-chemins", "journal", false)
end

---------------------------------------------------------------------------------------------------
-- Déroulé : sources du dépôt, puis mutants
---------------------------------------------------------------------------------------------------
install(nil, nil)
local Ch = require("shared.nav.chemins")
pure_checks(Ch)
soundness(Ch)
service_checks()

local function run_quiet(fn)
  local p0, f0 = passes, failures
  quiet = true
  local ok, err = pcall(fn)
  quiet = false
  local by_check = failures > f0
  passes, failures = p0, f0
  return by_check, (not ok) and err or nil
end

section("Mutants (chacun DOIT faire échouer un contrôle)")
local MUTANTS = {
  { "marge de 1,5 retirée", function()
    install(patch(CH_SRC, "Ch.MARGIN = 1.5", "Ch.MARGIN = 0"), nil)
    soundness(require("shared.nav.chemins"))
  end },
  { "invert oublié", function()
    install(nil, patch(PS_SRC, "collision_mask = Ch.LAYER, invert = true, limit = 1 })", "collision_mask = Ch.LAYER, limit = 1 })"))
    service_checks()
  end },
  { "refus pour un prototype sans player-layer", function()
    install(patch(CH_SRC, "    if layers[i] == Ch.LAYER then return true end", "    do return true end"), nil)
    service_checks()
  end },
  { "départ refusé au lieu d'être demandé sans marge", function()
    install(patch(CH_SRC, "then return \"unpad\" end", "then return \"refuse_water\" end"), nil)
    pure_checks(require("shared.nav.chemins"))
  end },
  { "refus non livré au gestionnaire", function()
    install(nil, patch(PS_SRC, "      jlog(P, \"R\", req, tick, \"eau\")\n      deliver(req, nil, \"no_path\", tick)", "      jlog(P, \"R\", req, tick, \"eau\")"))
    service_checks()
  end },
}
local seen_n, crash_n = 0, 0
for _, m in ipairs(MUTANTS) do
  local by_check, err = run_quiet(m[2])
  -- Vu par un CONTRÔLE (pas par un plantage : un plantage ne dit pas que le banc regarde la bonne chose).
  check(by_check, "mutant vu par un contrôle : " .. m[1] .. (err and (" (plantage : " .. tostring(err):sub(1, 160) .. ")") or ""))
  if by_check then seen_n = seen_n + 1 end
  if err then crash_n = crash_n + 1 end
end
install(nil, nil)
print(string.format("[X10-CHEMINS] mutants vus : %d sur %d par un contrôle (%d plantage(s))", seen_n, #MUTANTS, crash_n))

print(string.format("[X10-CHEMINS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
