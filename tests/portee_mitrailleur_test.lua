--[[
  MISE À JOUR PORTEE-SOLDATS (décision du DC du 8/11 vers 11 h 45 : « réduire… la range des soldats… enlever 30 % ») : la portée du
  mitrailleur vaut désormais 16 × F.SOLDIER_RANGE_FACTOR (0,65) = 10,4 ; la mitrailleuse de base (18) le DÉBORDE donc de 6,61 en
  diagonale (6,9 dans l'axe). §1 et §3 suivent ce réglage ; le texte ci-dessous est celui du 7/11, gardé pour l'historique.
  Décision du DC (QCM-7/11, relayée par le lead le 7/11 à 10 h 58) : la portée du mitrailleur des factions passe de 20 à 16,
  « comme le fusilier » (shared/faction/config.lua, F.soldiers.gunner.range).
  Pourquoi (EFFONDREMENT, RAPPORT §8 et §9.2) : les soldats des factions tirent en « boîte à boîte » (prototypes/faction.lua,
  range_mode), les tourelles du mod de centre à centre (défaut du moteur). En boîte à boîte, l'atteinte la plus longue est en
  DIAGONALE : portée + |S|, S = somme des demi-boîtes (0,2 + 0,7 = 0,9 sur chaque axe, |S| = 1,27). À 20, le mitrailleur frappait
  la mitrailleuse de base (18) depuis 21,27 tuiles (MESURÉ en partie : 21,2), hors de sa portée. À 16, il la frappe au plus depuis
  17,27.
  Modèle « boîte » (point C, 8846d342, 8/11) : au centre à centre, la tourelle atteint la BOÎTE de sa cible, pas son centre
  (MESURÉ, voir MARGE). La mitrailleuse de base frappe donc le mitrailleur (± 0,2) depuis 18 + 0,2·√2 = 18,28 en diagonale :
  marge 1,01 tuile en diagonale, 1,3 dans l'axe (18,2 contre 16,9). Annoncé au DC le 7/11 à l'ancien modèle (la tourelle visait
  le centre) : 0,73 en diagonale, 1,1 dans l'axe.
    §1 la donnée : mitrailleur 16, égal au fusilier ;
    §2 l'étape data RÉELLE (tests/datastage/harness.lua --dump-final) : le mitrailleur livré (faction et votre équipe) et la
       mitrailleuse de base, tels que le jeu les charge ;
    §3 la marge : Re.gap (shared/ai3/reaction.lua) et un oracle indépendant par force brute (720 directions), qui calcule DANS
       CHAQUE DIRECTION l'atteinte de chacun sur l'autre (distances de boîte, sans reach_box ni fonction d'appui) ;
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

-- Marge (tuile) de la mitrailleuse de base (18, centre à centre, ± 0,7) sur le mitrailleur (16, boîte à boîte, ± 0,2), modèle
-- « boîte ». MESURE MOTEUR qui la fonde : banc portee-diagonale, arène A (fo-logs/2026-11-05_CORR-RALLIEMENT/portee-diagonale-e0e42a60,
-- benchmark.log, « FAIT A ») : la fo-lvl-gun-9 (portée 21,7, centre à centre) touche un mitrailleur arrêté en (15,81 ; −15,21), à
-- 21,933 tuiles de son centre (au-delà de sa portée) ; de son centre à la BOÎTE du mitrailleur, il y a 21,656 ≤ 21,7. Le centre à
-- centre atteint donc la boîte de la cible (ou son rayon : variante non départagée, MÊME résultat en diagonale ; dans l'axe, le
-- rayon donnerait 1,38 au lieu de 1,3).
--   diagonale : tourelle 18 + 0,2·√2 = 18,283 ; mitrailleur 10,4 + 0,9·√2 = 11,673 ; marge 6,610 (= 7,6 − 0,7·√2) ;
--   axe : tourelle 18,2 ; mitrailleur 11,3 ; marge 6,9.
-- (Au 7/11, mitrailleur à 16 : marge 1,010 en diagonale, 1,3 dans l'axe ; annoncé au DC à l'ancien modèle : 0,73 et 1,1.)
local MARGE = 7.6 - 0.7 * math.sqrt(2)
local MARGE_AXE = 6.9
local TOL = 0.005

--- Oracle : atteinte de CENTRE à centre, dans la direction (c, s), d'un tireur de portée r sur une cible quand les demi-boîtes
--- écartées valent (sx, sy) : plus grande distance d telle que la distance entre les deux boîtes, aux centres écartés de d·(c, s),
--- reste ≤ r ; dichotomie (60 pas). Écrit en distances, sans reach_box ni fonction d'appui (indépendant de Re.gap).
local function radial(r, sx, sy, c, s)
  local lo, hi = 0, r + sx + sy + 2
  for _ = 1, 60 do
    local mid = (lo + hi) / 2
    local gx = math.max(0, math.abs(mid * c) - sx)
    local gy = math.max(0, math.abs(mid * s) - sy)
    if gx * gx + gy * gy <= r * r then lo = mid else hi = mid end
  end
  return lo
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
--- Modèle « boîte » de l'oracle : `a` frappe `b` quand la distance de SA boîte (boîte à boîte) ou de SON centre (centre à centre)
--- à la BOÎTE de b est ≤ a.r (mesure de MARGE) ; demi-boîtes écartées = celle de b, plus celle de a en boîte à boîte.
function P.span(a, b) return b.hx + (a.bb and a.hx or 0), b.hy + (a.bb and a.hy or 0) end
--- Dans la direction deg (degrés) : atteinte de t sur e moins atteinte de e sur t, puis les deux atteintes.
function P.at(e, t, deg)
  local a = deg * math.pi / 180
  local c, s = math.cos(a), math.sin(a)
  local ex, ey = P.span(e, t)
  local tx, ty = P.span(t, e)
  local re, rt = radial(e.r, ex, ey, c, s), radial(t.r, tx, ty, c, s)
  return rt - re, re, rt
end
--- Marge par force brute : la plus petite, sur 720 directions, de (atteinte de t sur e) − (atteinte de e sur t). Rend la marge, la
--- direction (degrés) où elle est la plus petite et les deux atteintes dans cette direction.
function P.margin(e, t)
  local best, bdeg, be, bt
  for k = 0, 719 do
    local m, re, rt = P.at(e, t, k / 2)
    if not best or m < best - 1e-9 then best, bdeg, be, bt = m, k / 2, re, rt end
  end
  return best, bdeg, be, bt
end

local function suite(cfg)
  section("§1 la donnée (shared/faction/config.lua)")
  local g, rf, rk = cfg.soldiers.gunner, cfg.soldiers.rifleman, cfg.soldiers.rocketeer
  local FAC = cfg.SOLDIER_RANGE_FACTOR
  check(FAC == 0.65, "facteur de portée des soldats (décision du DC du 8/11) : " .. tostring(FAC))
  check(g.range == 16 * FAC, "mitrailleur : portée 16 × facteur = 10,4 (décision du DC, 8/11) : " .. tostring(g.range))
  check(g.range == rf.range, "« comme le fusilier » : " .. tostring(g.range) .. " = " .. tostring(rf.range))
  check(rk.range == 26 * FAC, "grenadier : portée 26 × facteur = 16,9 : " .. tostring(rk.range))

  section("§3 la marge : la mitrailleuse de base déborde le mitrailleur, en diagonale (portée réduite, 8/11)")
  local e, t = P.gunner(g.range), P.turret()
  local gap = Re.gap(e, t)
  check(gap < -Re.RANGE_EPS, string.format("Re.gap(mitrailleur, mitrailleuse de base) < 0 : %.3f (la tourelle n'est PAS débordée)", gap))
  check(math.abs(-gap - MARGE) < TOL, string.format("marge en diagonale = %.3f (modèle boîte : %.2f)", -gap, MARGE))
  local m, deg, re, rt = P.margin(e, t)
  check(math.abs(m - MARGE) < TOL and math.abs(m + gap) < TOL and math.abs(deg % 90 - 45) < 1e-9,
    string.format("oracle (720 directions, modèle boîte) : marge %.3f au plus juste, à %.1f° (diagonale attendue), = −Re.gap (%.3f) : "
      .. "le mitrailleur atteint la mitrailleuse depuis %.3f, elle le frappe depuis %.3f", m, deg, -gap, re, rt))
  local ma, rea, rta = P.at(e, t, 0)
  check(math.abs(ma - MARGE_AXE) < TOL,
    string.format("dans l'axe : marge %.3f (%.1f attendu) : mitrailleur %.3f, tourelle %.3f", ma, MARGE_AXE, rea, rta))
  check(Re.turret_outranged({ e }, t) == false and Re.outranges({ e }, { t, t }) == false,
    "Re.outranges : des mitrailleurs ne débordent plus les mitrailleuses de base du QG")
  local g20 = Re.gap(P.gunner(20), t)
  check(math.abs(g20 - 2.99) < TOL and math.abs(g20 + P.margin(P.gunner(20), t)) < TOL and Re.outranges({ P.gunner(20) }, { t }) == true,
    string.format("rappel : à 20 (avant), la mitrailleuse de base était débordée de %.3f (2,99 au modèle boîte ; 3,27 à l'ancien)", g20))
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
  local c = { soldiers = {}, SOLDIER_RANGE_FACTOR = F.SOLDIER_RANGE_FACTOR }
  for k, v in pairs(F.soldiers) do c.soldiers[k] = v end
  local g = {}
  for k, v in pairs(F.soldiers.gunner) do g[k] = v end
  g.range = range
  c.soldiers.gunner = g
  return c
end
mutant("portée d'avant le facteur (16)", cfg_with(16))
mutant("portée arrondie (11, au lieu de 10,4)", cfg_with(11))
mutant("facteur 0,7 (portée 11,2) au lieu de 0,65", cfg_with(11.2))
mutant("mitrailleur compté au centre (diagonale oubliée)", F, function()
  P.gunner = function(r) return Re.profile(r, nil, { { -0.2, -0.2 }, { 0.2, 0.2 } }) end
end)
mutant("axe seulement (Re.gap sans la diagonale)", F, function()
  Re.gap = function(e, t) return e.r + math.min(e.hx + t.hx, e.hy + t.hy) - t.r end
end)
mutant("oracle sur l'axe seul", F, function()
  P.margin = function(e, t) local m, re, rt = P.at(e, t, 0) return m, 0, re, rt end
end)
mutant("oracle à l'ancien modèle (la tourelle vise le centre du mitrailleur)", F, function()
  P.span = function(a, b) if a.bb then return a.hx + b.hx, a.hy + b.hy end return 0, 0 end
end)
mutant("Re.gap à l'ancien modèle (8846d342 annulé : S = 0 au centre à centre)", F, function()
  Re.gap = function(e, t)
    local sx, sy = e.hx + t.hx, e.hy + t.hy
    return e.r + math.sqrt(sx * sx + sy * sy) - t.r
  end
end)
mutant("oracle d'une seule atteinte (celle du mitrailleur, contre la portée nue de la tourelle)", F, function()
  P.at = function(e, t, deg)
    local a = deg * math.pi / 180
    local ex, ey = P.span(e, t)
    local re = radial(e.r, ex, ey, math.cos(a), math.sin(a))
    return t.r - re, re, t.r
  end
end)
mutant("boîte de la tourelle oubliée", F, function()
  P.turret = function() return Re.profile(18, nil, nil) end
end)

print(string.format("[PORTEE-MITRAILLEUR] MUTANTS : %d / %d refusés", killed, total))
print(string.format("[PORTEE-MITRAILLEUR] BILAN : %d OK, %d ECHEC(S)%s", passes, failures + (total - killed),
  base_fail > 0 and " (suite de base en échec)" or ""))
os.exit((failures == 0 and killed == total) and 0 or 1)
