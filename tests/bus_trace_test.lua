--[[
  Lot RESEAU-GRAPHE, tracé du tronc de bus PAR TRANCHES (shared/team/traversee.lua, ctx.slice / ctx.resume ; script/team/liaison.lua, Liaison.plan) :
  « pire cas borné ». Cause : un tronc de 220 tuiles en A* exact prenait 2,1 s d'un seul tick (revue-s, partie du DC), jusqu'à ~10 s au pire.
    §1 une passe ne dépasse jamais PASS_MAX instructions (compte par debug.sethook, déterministe), sur terrain libre, forêt, rue ;
    §2 la recherche par tranches rend EXACTEMENT le tracé de la recherche d'un coup (même heuristique) ;
    §3 le total des passes est borné (plafond d'états : « trop long » ; cible emmurée : « aucun chemin » ou « trop long », jamais d'attente sans fin) ;
    §4 branchement lu comme texte (poids, plafond, tranche, sortie au premier échec, pas de diagnostic) ; §5 mutants.
  Usage : lua5.2 tests/bus_trace_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end

local PASS_MAX = 600000 -- instructions par passe (~5 ms au plus : 250 états × ~1000 instructions, plus le tas et la reprise)
local SLICE, WEIGHT, MAXS = 250, 1.4, 8000

local SRC = read("shared/team/traversee.lua")
local function load_tv(src)
  local chunk = assert(load(src, "@traversee", "t", setmetatable({}, { __index = _G })))
  return chunk()
end

-- terrains : cost(x, y) -> nil (interdit) ou coût
local function field(kind, sx, sy, tx, ty)
  local seed = 2024
  local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648 return seed / 2147483648 end
  local blocked = {}
  local x0, x1, y0, y1 = math.min(sx, tx) - 6, math.max(sx, tx) + 6, math.min(sy, ty) - 6, math.max(sy, ty) + 6
  local dens = ({ foret15 = 0.15, foret30 = 0.30, foret40 = 0.40 })[kind] or 0
  for x = x0, x1 do
    for y = y0, y1 do
      if dens > 0 and rnd() < dens then blocked[x .. ":" .. y] = true end
      if kind == "emmure" and math.max(math.abs(x - tx), math.abs(y - ty)) == 2 then blocked[x .. ":" .. y] = true end
    end
  end
  blocked[sx .. ":" .. sy], blocked[tx .. ":" .. ty] = nil, nil
  local cost = function(x, y)
    if blocked[x .. ":" .. y] then return nil end
    if kind == "rue" and y >= sy + 8 and y <= sy + 9 then return 3 end -- une rue plus chère dans la boîte
    return 1
  end
  return cost, { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end

--- Une recherche par tranches : rend tiles|nil, raison, passes, plus grand nombre d'instructions d'une passe.
local function sliced(Tv, kind, sx, sy, tx, ty, slice)
  local cost, bounds = field(kind, sx, sy, tx, ty)
  local resume, passes, worst = nil, 0, 0
  while passes < 400 do
    passes = passes + 1
    local n = 0
    debug.sethook(function() n = n + 1 end, "", 1000)
    local tiles, info, st = Tv.route({ x = sx, y = sy }, { x = tx, y = ty }, 2, bounds, cost,
      { weight = WEIGHT, max = MAXS, sd = 2, slice = slice, resume = resume, no_detour = true })
    debug.sethook()
    if n * 1000 > worst then worst = n * 1000 end
    if tiles then return tiles, info, passes, worst end
    if info ~= "pending" then return nil, info, passes, worst end
    resume = st
  end
  return nil, "jamais fini", passes, worst
end

local Tv = load_tv(SRC)
local cases = { { "libre", 0, 0, 220, 14 }, { "rue", 0, 0, 220, 14 }, { "foret15", 0, 0, 220, 14 }, { "foret30", 0, 0, 220, 14 }, { "foret40", 0, 0, 200, 25 }, { "emmure", 0, 0, 200, 90 } }
local worst_all, passes_all = 0, 0
for _, c in ipairs(cases) do
  local tiles, info, passes, worst = sliced(Tv, c[1], c[2], c[3], c[4], c[5], SLICE)
  worst_all = math.max(worst_all, worst)
  passes_all = math.max(passes_all, passes)
  check(worst <= PASS_MAX, string.format("1.%s une passe <= %d instructions (pire passe : %d, %d passes, %s)", c[1], PASS_MAX, worst, passes,
    tiles and ("tracé de " .. #tiles) or tostring(info)))
  local cost, bounds = field(c[1], c[2], c[3], c[4], c[5])
  local whole = Tv.route({ x = c[2], y = c[3] }, { x = c[4], y = c[5] }, 2, bounds, cost, { weight = WEIGHT, max = MAXS, sd = 2, no_detour = true })
  local same = (whole == nil) == (tiles == nil)
  if same and whole then
    same = #whole == #tiles
    for i = 1, #whole do if same and (whole[i].x ~= tiles[i].x or whole[i].y ~= tiles[i].y or whole[i].dir ~= tiles[i].dir) then same = false end end
  end
  check(same, "2." .. c[1] .. " le tracé par tranches est celui de la recherche d'un coup")
end
check(passes_all <= MAXS / SLICE + 2, "3.1 le total des passes est borné par le plafond d'états (" .. passes_all .. " passes)")

do
  local tiles, info, passes, worst = sliced(Tv, "emmure", 0, 0, 200, 90, SLICE)
  check(tiles == nil and (info == "aucun chemin" or info == "trop long") and passes <= MAXS / SLICE + 2,
    "3.2 cible emmurée : refus (" .. tostring(info) .. ") en " .. passes .. " passes, jamais d'attente sans fin")
  check(worst <= PASS_MAX, "3.3 même la pire passe d'un refus reste bornée (" .. worst .. " instructions)")
end

-- §4 branchement lu comme texte
local LIA, TRV, BUS = read("script/team/liaison.lua"), read("script/team/traversee.lua"), read("script/team/bus.lua")
check(LIA:find("ropts.weight, ropts.max, ropts.slice, ropts.no_detour, ropts.no_diag = Bus.WEIGHT, Bus.MAX_STATES, Bus.SLICE, true, true", 1, true) ~= nil,
  "4.1 Liaison.plan : tronc de bus = poids, plafond, tranche, ni détour ni diagnostic")
check(LIA:find('return false, "liaison: trace du tronc en cours', 1, true) ~= nil and LIA:find('"calcul"', 1, true) ~= nil,
  "4.2 une tranche finie rend `calcul` (le projet reste en plan)")
check(LIA:find('why == "aucun chemin" or why == "trop long") then break end', 1, true) ~= nil, "4.3 sortie de la boucle des bouts au premier aucun chemin / trop long")
check(TRV:find("and not opts.no_diag then", 1, true) ~= nil, "4.4 Trav.route : pas de Tv.diagnose pour un tronc de bus")
check(BUS:find("Bus.WEIGHT = 1.4", 1, true) ~= nil and BUS:find("Bus.SLICE = 250", 1, true) ~= nil and BUS:find("Bus.MAX_STATES = 8000", 1, true) ~= nil,
  "4.5 constantes du bus (poids 1,4, tranche 250, plafond 8000)")

-- §5 mutants : chacun doit être refusé
local function mutant(label, a, b)
  local s, n = SRC:gsub(a, function() return b end, 1)
  if n == 0 then check(false, "5 mutant introuvable : " .. label) return end
  local Tm = load_tv(s)
  local refused = false
  for _, c in ipairs(cases) do
    local tiles, info, passes, worst = sliced(Tm, c[1], c[2], c[3], c[4], c[5], SLICE)
    if worst > PASS_MAX or passes > MAXS / SLICE + 2 or (tiles == nil and info ~= "trop long" and info ~= "aucun chemin") then refused = true end
  end
  check(refused, "5 mutant refusé : " .. label)
end
mutant("tranche ignorée", "if slice_end and expanded >= slice_end then", "if false then")
mutant("plafond d'états ignoré", 'if expanded > cap then return nil, "trop long", expanded end', "")
mutant("tranche × 40", "local slice_end = ctx.slice and %(expanded %+ ctx.slice%) or nil", "local slice_end = ctx.slice and (expanded + ctx.slice * 40) or nil")

print(string.format("[BUS-TRACE] pire passe mesurée : %d instructions (borne %d) ; plus longue recherche : %d passes", worst_all, PASS_MAX, passes_all))
print(string.format("[BUS-TRACE] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
