--[[
  Lot DANGER-ACTIF : contrôle SENS du scénario da-meute (tools/autotest/fo-autotest/scenarios/da_meute_common.lua), hors jeu.
  Décision B du lead (7/11 ; fo-logs/2026-11-04_DANGER-ACTIF/CRITERES.md, « SENS : sonde et reformulation ») : SENS compte un but de tâche hors
  défense du QG, dans la zone de la meute, plus près d'elle que le PNJ à son départ, et qui n'est PAS exactement une case du QG (home_spot +
  Scale.HOME_SLOTS, étape « home » de script/team/worker.lua) ; il exige aussi 0 relevé de PNJ à moins de 12 tuiles de la meute.
  Faux moteur (ctx, surface, remote « agents ») et PNJ synthétiques ; le scénario est joué tick par tick jusqu'à son contrôle.
    T0  cas mesurés (archives da-meute-90a3f390 et da-meute-sonde-0656) : retours de l'ouest sur des cases du QG -> vert ;
    M1  départ du coffre vers (30, 6.5), à 2,5 tuiles de la meute -> rouge ;
    M2  retour de l'ouest vers (10.5, 6.5), à 4 tuiles du coffre, qui n'est PAS une case du QG -> rouge ;
    M3  retour de l'ouest sur la case du QG 1 -> vert ;
    M4  retour sur la case du QG 1 qui passe à 7,5 tuiles de la meute -> rouge (relevé) ;
    M6  départ du coffre vers (0, 6.5), à l'opposé de la meute mais dans sa zone (s'éloigne) -> vert ;
    M5  cases du QG illisibles (module du mod introuvable) -> rouge partout (SENS non jugeable).
  Mutants du source (chacun doit faire échouer au moins un cas) : sans « contact == 0 », sans l'exclusion des cases du QG, sans la
  comparaison au départ.
  Usage (racine du mod) : lua5.2 tests/da_meute_sens_test.lua [racine du mod] [fichier du scenario]
]]
-- Arguments facultatifs : racine du mod (défaut « . »), puis un autre fichier de scénario (brouillon).
local ROOT = arg[1] or "."
local SRC_PATH = arg[2] or (ROOT .. "/tools/autotest/fo-autotest/scenarios/da_meute_common.lua")

local root_ok = true
-- Comme le jeu : « __factorio-overhaul__/x/y » se lit à la racine du mod ; les require internes du module (« shared.team.org ») se lisent à
-- la racine du mod de test, où ils n'existent pas : le scénario doit les précharger.
table.insert(package.searchers, 2, function(name)
  local rel = name:match("^__factorio%-overhaul__/(.+)$")
  if not rel then return nil end
  if not root_ok then return "\n\tmodule du mod refuse (cas M5)" end
  local fn, err = loadfile(ROOT .. "/" .. rel .. ".lua")
  if not fn then return "\n\t" .. tostring(err) end
  return fn
end)
local saved_path = package.path

local f = assert(io.open(SRC_PATH, "rb"))
local SRC = f:read("*a")
f:close()

local HQ = { x = 6.5, y = 6.5 } -- coffre ; meute en (32.5, 6.5) ; case du QG estimée (6.5, 9.5) (le faux moteur rend la case demandée)
local WEST = { x = -93, y = 112 }
local tick_now = 0
_G.game = {
  forces = { player = { get_spawn_position = function() return { x = 0, y = 0 } end } },
  entity_prototypes = { ["medium-biter"] = { vision_distance = 30 } },
}
setmetatable(game, { __index = function(_, k) if k == "tick" then return tick_now end end })

local function walk(from, to, t0, t1, t)
  if t <= t0 then return from end
  if t >= t1 then return to end
  local u = (t - t0) / (t1 - t0)
  return { x = from.x + (to.x - from.x) * u, y = from.y + (to.y - from.y) * u }
end

local function back_from_west(id, goal)
  return function(t)
    local p = walk(WEST, goal, 3000, 5000, t)
    return { id = id, x = p.x, y = p.y, task = "mine", final = t >= 3000 and goal or { x = -120, y = 140 } }
  end
end

local function from_hq(id, goal)
  return function(t)
    local p = walk(HQ, goal, 4000, 9000, t)
    return { id = id, x = p.x, y = p.y, task = t >= 4000 and "mine" or nil, final = t >= 4000 and goal or nil }
  end
end

local CASES = {
  { key = "T0", name = "retours de l'ouest sur les cases du QG 1, 8 et 9 (cas mesures)", green = true,
    pnj = { back_from_west(1, { x = 9.0, y = 9.5 }), back_from_west(7, { x = 8.25, y = 7.75 }), back_from_west(8, { x = 10.875, y = 10.625 }) } },
  { key = "M1", name = "depart du coffre vers (30, 6.5), a 2.5 tuiles de la meute", green = false, pnj = { from_hq(2, { x = 30, y = 6.5 }) } },
  { key = "M2", name = "retour de l'ouest vers (10.5, 6.5), hors case du QG", green = false, pnj = { back_from_west(3, { x = 10.5, y = 6.5 }) } },
  { key = "M3", name = "retour de l'ouest sur la case du QG 1", green = true, pnj = { back_from_west(4, { x = 9.0, y = 9.5 }) } },
  { key = "M4", name = "retour sur la case du QG 1 qui passe a 7.5 tuiles de la meute", green = false,
    pnj = { function(t)
      local near = { x = 25, y = 6.5 }
      local p = t < 3000 and { x = 45, y = 6.5 } or (t < 3600 and near or walk(near, { x = 9.0, y = 9.5 }, 3600, 4400, t))
      return { id = 5, x = p.x, y = p.y, task = "mine", final = t < 3000 and { x = 60, y = 6.5 } or { x = 9.0, y = 9.5 } }
    end } },
  { key = "M6", name = "depart du coffre vers (0, 6.5), dans la zone mais a l'oppose de la meute", green = true, pnj = { from_hq(6, { x = 0, y = 6.5 }) } },
}

--- Joue le scénario (texte source `src`) sur un cas ; rend le contrôle SENS { ok, detail } ou nil.
local function play(src, case)
  local checks, st = {}, {}
  local surface = {
    find_entities_filtered = function() return {} end,
    create_entity = function(e)
      if e.name == "fo-team-chest" then return { valid = true, position = { x = HQ.x, y = HQ.y }, insert = function() return 1 end } end
      local u = { valid = true }
      u.destroy = function() u.valid = false end
      return u
    end,
    find_non_colliding_position = function(_, p) return { x = p.x, y = p.y } end,
  }
  local ctx = {
    state = function() return st end,
    surface = function() return surface end,
    log = function() end,
    check = function(ok, name, detail) checks[#checks + 1] = { ok = ok and true or false, name = name, detail = detail } end,
    fail = function(name, detail) checks[#checks + 1] = { ok = false, name = name, detail = detail } end,
    call = function(name, _, b) if name == "war_setting" then return b end return true end,
    remote = function(iface, fn, _, b)
      if iface == "fo-ia1" and fn == "set_setting" then return b end
      if iface == "fo-ia3k" and fn == "agents" then
        local out = {}
        for _, g in ipairs(case.pnj) do out[#out + 1] = g(tick_now) end
        return out
      end
      if iface == "fo-ia1" and fn == "teams" then return { { key = "player", lost = 0 } } end
      if iface == "fo-ia3k" and fn == "status" then return { stats = { dact = {} } } end
      return nil
    end,
  }
  package.loaded["shared.team.config"], package.loaded["shared.team.org"] = nil, nil
  for _, k in ipairs({ "__factorio-overhaul__/shared/team/config", "__factorio-overhaul__/shared/team/org", "__factorio-overhaul__/shared/team/scale" }) do
    package.loaded[k] = nil
  end
  package.path = "" -- require internes : racine du mod de test, vide
  local chunk = assert(load(src, "=da_meute_common.lua"))
  local sc = chunk()({ tag = "DA-MEUTE", description = "test hors jeu" })
  package.path = saved_path
  tick_now = 0
  sc.init(ctx)
  for t = 1, sc.check_tick do
    tick_now = t
    sc.tick(ctx, { tick = t })
  end
  sc.finish(ctx)
  for _, c in ipairs(checks) do if c.name:sub(1, 4) == "SENS" then return c end end
  return nil
end

local ok_n, bad_n = 0, 0
local function check(cond, label, detail)
  if cond then ok_n = ok_n + 1 else bad_n = bad_n + 1 end
  print(string.format("[DA-MEUTE-SENS] %s %s%s", cond and "OK   " or "ECHEC", label, detail and (" : " .. tostring(detail)) or ""))
end

--- Rend le nombre de cas dont le verdict n'est pas celui attendu (attendu rouge partout si `all_red`).
local function run_cases(src, all_red, report)
  local wrong = 0
  for _, case in ipairs(CASES) do
    local c = play(src, case)
    local want = case.green and not all_red
    local good = c ~= nil and c.ok == want
    if not good then wrong = wrong + 1 end
    if report then
      check(good, string.format("%s%s %s : SENS %s (attendu %s)", all_red and "M5/" or "", case.key, case.name,
        c and (c.ok and "vert" or "rouge") or "absent", want and "vert" or "rouge"), c and c.detail)
    end
  end
  return wrong
end

-- 1. Le scénario tel quel.
check(SRC:find("st.contact == 0", 1, true) ~= nil, "le controle SENS exige contact == 0 (source)")
run_cases(SRC, false, true)
-- 2. M5 : module du mod introuvable.
root_ok = false
run_cases(SRC, true, true)
root_ok = true

-- 3. Mutants du source : chacun doit être refusé (au moins un cas faux).
local MUTANTS = {
  { "sans contact == 0", " and st.toward == 0 and st.contact == 0,", " and st.toward == 0," },
  { "sans exclusion des cases du QG", "local slot = sonde_case(st.home_spot, a.final)\n", "local slot = nil\n" },
  { "sans comparaison au depart", "and dep and df < d2(dep, st.c) and", "and dep and" },
}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then
    check(false, "mutant " .. m[1] .. " : texte introuvable dans le source")
  else
    local mut = SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1)
    local wrong = run_cases(mut, false, false)
    check(wrong > 0, "mutant " .. m[1] .. " refuse", wrong .. " cas faux")
  end
end

print(string.format("[DA-MEUTE-SENS] BILAN : %d OK, %d ECHEC(S)", ok_n, bad_n))
os.exit(bad_n == 0 and 0 or 1)
