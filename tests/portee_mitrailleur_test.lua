--[[
  Décision du DC (QCM-7/11, relayée par le lead le 7/11 à 10 h 58) : la portée du mitrailleur des factions passe de 20 à 16,
  « comme le fusilier » (shared/faction/config.lua, F.soldiers.gunner.range).
  Pourquoi (EFFONDREMENT, RAPPORT §8 et §9.2) : les soldats des factions tirent en « boîte à boîte » (prototypes/faction.lua,
  range_mode), les tourelles du mod de centre à centre (défaut du moteur). En boîte à boîte, l'atteinte la plus longue est en
  DIAGONALE : portée + |S|, S = somme des demi-boîtes (0,2 + 0,7 = 0,9 sur chaque axe, |S| = 1,27). À 20, le mitrailleur frappait
  la mitrailleuse de base (18) depuis 21,27 tuiles (MESURÉ en partie : 21,2), hors de sa portée. À 16, il la frappe au plus depuis
  17,27 : la mitrailleuse de base le touche avant, avec 0,73 tuile de marge en diagonale (1,1 dans l'axe).
    §1 la donnée : mitrailleur 16, égal au fusilier ;
    §2 l'étape data RÉELLE (tests/datastage/harness.lua --dump-final) : le mitrailleur livré (faction et votre équipe) et la
       mitrailleuse de base, tels que le jeu les charge ;
    §3 la marge : Re.gap (shared/ai3/reaction.lua) et un oracle indépendant par force brute (720 directions) ;
    §4 mutants : chaque erreur possible du calcul ou de la donnée est vue.
  Lancement : lua5.2 tests/portee_mitrailleur_test.lua (depuis la racine du mod ; quelques secondes).
]]
package.path = "./?.lua;" .. package.path
local F = require("shared.faction.config")
local Re = require("shared.ai3.reaction")

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
end
local function section(name) if not quiet then print("== " .. name) end end

local MARGE = 0.73 -- marge annoncée au DC (tuile), en diagonale
local TOL = 0.005

--- Oracle indépendant de Re.gap : plus grande distance de centre à centre d'où un tireur de portée r en boîte à boîte atteint
--- une cible, S = (sx, sy) somme des demi-boîtes ; 720 directions, dichotomie sur la distance entre les deux boîtes.
local function brute_reach(r, sx, sy)
  local best = 0
  for k = 0, 719 do
    local c, s = math.cos(k * math.pi / 360), math.sin(k * math.pi / 360)
    local lo, hi = 0, r + sx + sy + 2
    for _ = 1, 60 do
      local mid = (lo + hi) / 2
      local gx = math.max(0, math.abs(mid * c) - sx)
      local gy = math.max(0, math.abs(mid * s) - sy)
      if gx * gx + gy * gy <= r * r then lo = mid else hi = mid end
    end
    if lo > best then best = lo end
  end
  return best
end

--- Données du jeu (comme tests/levels_test.lua) : FO_DATA_DIR, sinon relatif à la racine du mod ou d'un worktree.
local function data_dir()
  local cands = {}
  if os.getenv("FO_DATA_DIR") then cands[#cands + 1] = os.getenv("FO_DATA_DIR") end
  cands[#cands + 1] = "../../data"
  cands[#cands + 1] = "../../../../../data"
  for _, d in ipairs(cands) do
    local fh = io.open(d .. "/base/prototypes/technology.lua", "rb")
    if fh then fh:close() return d end
  end
  return nil
end

--- Prototype final livré par le mod (harness --dump-final) : { range, mode, hx, hy } lus au texte, ou nil.
local function final_profile(dd, what)
  local lua = (arg and arg[-1]) or "lua5.2"
  -- (7/11, PC chargé par d'autres agents : io.popen du harness rend parfois une sortie VIDE, 1 fois sur 2 lancements de suite,
  -- alors que le même harness lancé à la main rend 0 ; on relance au plus 3 fois, puis la sortie vide est un ECHEC écrit)
  local out = ""
  for _ = 1, 3 do
    local ph = io.popen(lua .. ' tests/datastage/harness.lua "' .. dd .. '" . --dump-final ' .. what .. ' 2>&1', "r")
    out = ph and ph:read("*a") or ""
    if ph then ph:close() end
    if #out > 0 then break end
  end
  if #out == 0 then return nil, "harness muet 3 fois" end
  local ap = out:match("\n  attack_parameters = (%b{})")
  local col = out:match("\n  collision_box = (%b{})")
  if not (ap and col) then return nil, out:sub(1, 300) end
  local range = tonumber(ap:match("\n    range = ([%-%d%.]+)"))
  local mode = ap:match('\n    range_mode = "([^"]+)"')
  local nums = {}
  for v in col:gmatch("= ([%-%d%.]+)") do nums[#nums + 1] = tonumber(v) end
  if #nums ~= 4 then return nil, "boite illisible" end
  return { range = range, mode = mode, hx = math.abs(nums[3] - nums[1]) / 2, hy = math.abs(nums[4] - nums[2]) / 2 }
end

-- profils du calcul (remplaçables par les mutants)
local P = {}
function P.gunner(range) return Re.profile(range, Re.BB, { { -0.2, -0.2 }, { 0.2, 0.2 } }) end
function P.turret() return Re.profile(18, nil, { { -0.7, -0.7 }, { 0.7, 0.7 } }) end
function P.reach(e, t) return brute_reach(e.r, e.hx + t.hx, e.hy + t.hy) end

local function suite(cfg)
  section("§1 la donnée (shared/faction/config.lua)")
  local g, rf = cfg.soldiers.gunner, cfg.soldiers.rifleman
  check(g.range == 16, "mitrailleur : portée 16 (décision du DC, QCM-7/11) : " .. tostring(g.range))
  check(g.range == rf.range, "« comme le fusilier » : " .. tostring(g.range) .. " = " .. tostring(rf.range))

  section("§3 la marge : la mitrailleuse de base touche le mitrailleur avant d'être touchée, en diagonale")
  local e, t = P.gunner(g.range), P.turret()
  local gap = Re.gap(e, t)
  check(gap < -Re.RANGE_EPS, string.format("Re.gap(mitrailleur, mitrailleuse de base) < 0 : %.3f (la tourelle n'est PAS débordée)", gap))
  check(math.abs(-gap - MARGE) < TOL, string.format("marge en diagonale = %.2f (annoncée au DC : %.2f)", -gap, MARGE))
  local reach = P.reach(e, t)
  check(math.abs(reach - (t.r - MARGE)) < TOL and reach < t.r,
    string.format("oracle (720 directions) : le mitrailleur atteint la mitrailleuse depuis %.3f au plus, elle le frappe à %.1f", reach, t.r))
  local axis = e.r + math.min(e.hx + t.hx, e.hy + t.hy)
  check(math.abs((t.r - axis) - 1.1) < TOL, string.format("dans l'axe : marge %.2f (1,1 annoncé)", t.r - axis))
  check(Re.turret_outranged({ e }, t) == false and Re.outranges({ e }, { t, t }) == false,
    "Re.outranges : des mitrailleurs ne débordent plus les mitrailleuses de base du QG")
  check(Re.gap(P.gunner(20), t) > 3.2 and Re.outranges({ P.gunner(20) }, { t }) == true,
    "rappel : à 20 (avant), la mitrailleuse de base était débordée de 3,27")
end

suite(F)

section("§2 l'étape data RÉELLE (harness --dump-final)")
local dd = data_dir()
if not dd then
  check(false, "données du jeu introuvables (FO_DATA_DIR)")
else
  for _, owner in ipairs({ "scarlet", F.player_army.key }) do
    local name = F.unit_name(owner, "gunner")
    local u, why = final_profile(dd, "unit/" .. name)
    check(u and u.range == F.soldiers.gunner.range and u.mode == Re.BB and math.abs(u.hx - 0.2) < 1e-9 and math.abs(u.hy - 0.2) < 1e-9,
      name .. " livré : portée " .. tostring(u and u.range) .. ", " .. tostring(u and u.mode) .. ", boîte ± " .. tostring(u and u.hx)
      .. (u and "" or (" (" .. tostring(why) .. ")")))
  end
  local tu, why = final_profile(dd, "ammo-turret/gun-turret")
  check(tu and tu.range == 18 and (tu.mode == nil or tu.mode == "center-to-center") and math.abs(tu.hx - 0.7) < 1e-9,
    "gun-turret livrée : portée " .. tostring(tu and tu.range) .. ", centre à centre (" .. tostring(tu and tu.mode) .. "), boîte ± "
    .. tostring(tu and tu.hx) .. (tu and "" or (" (" .. tostring(why) .. ")")))
end
local base_fail = failures

-- §4 mutants (chacun doit faire échouer la suite)
local killed, total = 0, 0
local function mutant(name, cfg, apply)
  total = total + 1
  local saved = {}
  for k, v in pairs(P) do saved[k] = v end
  local sg = Re.gap
  if apply then apply() end
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(suite, cfg)
  quiet = false
  for k, v in pairs(saved) do P[k] = v end
  Re.gap = sg
  local caught = (failures > f0) or not ok
  passes, failures = p0, f0
  if caught then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. name) end
end
local function cfg_with(range)
  local c = { soldiers = {} }
  for k, v in pairs(F.soldiers) do c.soldiers[k] = v end
  local g = {}
  for k, v in pairs(F.soldiers.gunner) do g[k] = v end
  g.range = range
  c.soldiers.gunner = g
  return c
end
mutant("portée d'avant (20)", cfg_with(20))
mutant("portée 17 (débordée de 0,27 en diagonale)", cfg_with(17))
mutant("portée 15 (marge 1,73 : pas celle annoncée)", cfg_with(15))
mutant("mitrailleur compté au centre (diagonale oubliée)", F, function()
  P.gunner = function(r) return Re.profile(r, nil, { { -0.2, -0.2 }, { 0.2, 0.2 } }) end
end)
mutant("axe seulement (Re.gap sans la diagonale)", F, function()
  Re.gap = function(e, t) return e.r + math.min(e.hx + t.hx, e.hy + t.hy) - t.r end
end)
mutant("oracle sur l'axe seul", F, function()
  P.reach = function(e, t) return e.r + math.min(e.hx + t.hx, e.hy + t.hy) end
end)
mutant("boîte de la tourelle oubliée", F, function()
  P.turret = function() return Re.profile(18, nil, nil) end
end)

print(string.format("[PORTEE-MITRAILLEUR] MUTANTS : %d / %d refusés", killed, total))
print(string.format("[PORTEE-MITRAILLEUR] BILAN : %d OK, %d ECHEC(S)%s", passes, failures + (total - killed),
  base_fail > 0 and " (suite de base en échec)" or ""))
os.exit((failures == 0 and killed == total) and 0 or 1)
