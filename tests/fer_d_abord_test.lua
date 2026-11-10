--[[
  Lot FER-D-ABORD : banc HORS JEU de Th.iron_waits / Th.raw_holds / Th.iron_clock / Th.fuel_short (shared/team/thermique.lua) et de leur branchement
  dans start_next (script/team/migration_champ.lua, contrôle de texte). Lancement : lua5.2 tests/fer_d_abord_test.lua (depuis la racine du mod).
  Cas mesuré (graine 123456789, votre équipe) : « avant-poste 1 (iron) : migration en veille (plaques) » toute la partie pendant que les bandes de
  charbon et de pierre (tier 1, sans garde de plaques) partent : 10 foreuses de fer sur 1 935 tuiles à 60 et 100 min.
  Gardes (demande du lead, 9/11) : (1) sortie BORNÉE : la retenue cesse après Th.CFG.iron_hold_max ticks sans départ d'une bande de fer ;
  (2) le combustible n'est pas affamé : si son manque est mesuré (stock sous l'horizon de consommation), sa bande n'est pas retenue.
]]
package.path = "./?.lua;" .. package.path
local Th = require("shared.team.thermique")
local passes, failures = 0, 0
local QUIET = false
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1 if not QUIET then print("  ECHEC : " .. m) end end end

local MAX, GAP = Th.CFG.iron_hold_max, Th.CFG.iron_hold_gap

local function body()
  QUIET = true
  local f0 = failures
  check(Th.iron_waits(0, "plaques") == true, "m1 tier 0 refuse faute de plaques")
  check(Th.iron_waits(1, "plaques") == false, "m2 tier 1 : pas une attente de fer")
  check(Th.iron_waits(0, "courant") == false, "m3 autre cause de refus")
  check(Th.iron_waits(nil, "plaques") == true, "m4 tier absent = 0")
  local function holds(c) local h, w = Th.raw_holds(c) return h, w end
  local base = { tier = 1, wanted = false, iron_waiting = true, fuel = false, fuel_short = false, since = 1000, now = 2000 }
  local function with(k, v) local c = {} for a, b in pairs(base) do c[a] = b end c[k] = v return c end
  local h, w = holds(base)
  check(h == true and w == "retenue", "m5 brut retenu")
  check(holds(with("wanted", true)) == false, "m6 brut VOULU : jamais retenu")
  check(holds(with("tier", 0)) == false, "m7 tier 0 jamais retenu")
  check(holds(with("iron_waiting", false)) == false, "m8 rien n'attend : brut libre")
  check(holds(with("iron_waiting", nil)) == false, "m9 drapeau absent")
  -- garde 1 : sortie bornée
  check(holds(with("now", 1000 + MAX - 1)) == true, "m10 juste avant la borne : retenu")
  h, w = holds(with("now", 1000 + MAX))
  check(h == false and w == "expire", "m11 a la borne : retenue levee, raison expire")
  check(holds(with("now", 1000 + 3 * MAX)) == false, "m12 bien apres la borne : levee")
  check(holds(with("since", nil)) == true, "m13 horloge absente : retenue (premiere pensee)")
  -- garde 2 : le combustible n'est pas affamé
  h, w = holds(with("fuel", true))
  check(h == true and w == "retenue", "m14 combustible sans manque mesure : retenu comme les autres")
  local fc = with("fuel", true) fc.fuel_short = true
  h, w = holds(fc)
  check(h == false and w == "combustible", "m15 combustible en manque : jamais retenu")
  check(holds(with("fuel_short", true)) == true, "m16 manque de combustible : la pierre reste retenue")
  -- manque mesuré
  local hz = Th.CFG.horizon
  check(Th.fuel_short(0, 2) == true, "m17 stock nul, consommation : manque")
  check(Th.fuel_short(2 * hz, 2) == false, "m18 stock = horizon : pas de manque")
  check(Th.fuel_short(2 * hz - 1, 2) == true, "m19 sous l'horizon : manque")
  check(Th.fuel_short(0, 0) == false, "m20 sans consommation lue : pas de manque mesure")
  check(Th.fuel_short(nil, nil) == false, "m21 mesures absentes : pas de manque")
  check(Th.fuel_starved(0, 2, 0) == false, "m21b affame : aucun brûleur a sec, pas affame")
  check(Th.fuel_starved(0, 2, 1) == true, "m21c affame : stock nul et un brûleur a sec")
  check(Th.fuel_starved(2 * hz, 2, 5) == false, "m21d affame : stock qui ponte l'horizon, pas affame")
  -- horloge
  local s, l = Th.iron_clock(nil, nil, true, 500)
  check(s == 500 and l == 500, "m22 premier refus : l'horloge part")
  s, l = Th.iron_clock(500, 500, true, 800)
  check(s == 500 and l == 800, "m23 refus suivant : since garde, last avance")
  s, l = Th.iron_clock(500, 800, true, 800 + GAP + 1)
  check(s == 800 + GAP + 1 and l == s, "m24 trou plus long que le gap : l'horloge repart")
  s, l = Th.iron_clock(500, 800, false, 800 + GAP)
  check(s == 500 and l == 800, "m25 pas d'attente mais gap non ecoule : horloge gardee")
  s, l = Th.iron_clock(500, 800, false, 800 + GAP + 1)
  check(s == nil and l == nil, "m26 pas d'attente depuis plus que le gap : horloge eteinte")
  s, l = Th.iron_clock(nil, nil, false, 800)
  check(s == nil and l == nil, "m27 rien : rien")
  -- la retenue ne dure jamais plus de MAX tant que les refus se suivent (simulation d'une impasse : le fer n'atteint jamais 150)
  local since, last, released = nil, nil, nil
  for t = 0, 3 * MAX, 600 do
    since, last = Th.iron_clock(since, last, true, t)
    if not holds({ tier = 1, wanted = false, iron_waiting = true, since = since, now = t }) then released = released or t end
  end
  check(released ~= nil and released <= MAX, "m28 impasse simulee : les bandes brutes repartent au plus tard a la borne")
  QUIET = false
  return failures - f0
end
print("== regle")
body()
local c = 0
debug.sethook(function() c = c + 1 end, "", 1000)
local cc = { tier = 1, wanted = false, iron_waiting = true, since = 0, now = 10 }
for i = 1, 1000 do Th.iron_waits(i % 2, "plaques") Th.raw_holds(cc) Th.iron_clock(0, 0, true, i) Th.fuel_short(i, 2) end
debug.sethook()
check(c < 200, "cout : moins de 200 instructions par lot de 4 appels (" .. c .. ")")
print("== branchement (texte de start_next)")
local f = io.open("script/team/migration_champ.lua", "rb")
local mig = f:read("*a")
f:close()
check(mig:find("Th.raw_holds({ tier = it.tier, wanted = it.wanted, iron_waiting = iron_waiting, fuel = is_fuel, fuel_short = short,", 1, true) ~= nil, "le gisement brut est retenu par Th.raw_holds")
check(mig:find("if Th.iron_waits(it.tier, why) then -- lot FER-D-ABORD", 1, true) ~= nil, "le refus « plaques » d'un gisement de plaques leve le drapeau")
check(mig:find("Th.iron_clock(ms.iron_since, ms.iron_last, true, tick)", 1, true) ~= nil, "l'horloge avance au refus « plaques »")
check(mig:find("short = Th.fuel_starved(free[spec.product] or 0, burn, dry_n)", 1, true) ~= nil, "le manque de combustible est mesure au stock, au plancher et aux brûleurs a sec")
check(mig:find("if (it.tier or 0) == 0 then ms.iron_since, ms.iron_last, ms.iron_note = nil, nil, nil end", 1, true) ~= nil, "le depart d'une bande de fer remet l'horloge a zero")
local a = mig:find("local iron_waiting = false", 1, true)
local b = mig:find("Th.raw_holds({ tier", 1, true)
local d = mig:find("if Th.iron_waits(it.tier", 1, true)
check(a and b and d and a < b and b < d, "drapeau pose avant la boucle, lu en tete de boucle, ecrit apres Mg.start_ok")
check(mig:find('why_hold == "expire"', 1, true) ~= nil and mig:find("retenue des bandes brutes levee apres", 1, true) ~= nil, "la levee de la retenue est ecrite au journal")
check(mig:find('why_hold == "combustible"', 1, true) ~= nil and mig:find("le combustible manque", 1, true) ~= nil, "le combustible non retenu est ecrit au journal")
print("== plancher du combustible de la retenue (F481, lot AVANT-POSTES-RAPIDES)")
-- Cas mesuré (V0680-B, 1618033988, votre équipe) : avant-poste 2 (charbon) « bande brute neuve retenue » de 6,3 à 90 min ; brûleurs à sec 28 à 45 min,
-- 26 à 75 min ; centrale à sec = générateurs à 0 objet/s. Le manque lisait les seuls générateurs : jamais « combustible », toujours retenu.
local Mc = require("shared.team.migration_combustible")
local function plancher_cas(McX)
  local bad = 0
  local function ok(c, m) if not c then bad = bad + 1; if not QUIET then print("  ECHEC : " .. m) end end end
  local fl = McX.floor(0, { { kw = 150, n = 70 } }, 4000)   -- centrale à sec, 70 brûleurs de 150 kW, combustible de 4 MJ
  ok(fl > 2.6 - 1e-6 and fl < 2.63, "p1 plancher = brûleurs à pleine cadence quand la centrale est à sec (" .. tostring(fl) .. ")")
  ok(Th.fuel_short(0, fl) == true, "p2 stock nul sous le plancher des brûleurs : manque")
  ok(Th.fuel_short(0, 0) == false, "p3 (rappel du défaut) générateurs seuls à 0 : aucun manque lu")
  local h, w = Th.raw_holds({ tier = 1, wanted = false, iron_waiting = true, fuel = true, fuel_short = Th.fuel_short(0, fl), since = 0, now = 60 })
  ok(h == false and w == "combustible", "p4 bande de combustible jamais retenue quand les brûleurs manquent")
  local g = McX.floor(0.35, {}, 4000)
  ok(math.abs(g - 0.35) < 1e-9, "p5 générateurs seuls : le plancher est leur consommation mesurée")
  ok(McX.floor(0.35, { { kw = 90, n = 10 } }, 4000) > 0.35 + 0.2, "p6 générateurs + brûleurs : les deux s'ajoutent")
  -- 2e cycle (panel AVP-P du 1er : fer 72 495 contre 100 075) : en ouverture le stock est nul et le plancher à pleine cadence > 0, mais aucun brûleur
  -- n'est à sec : pas d'affamement, la retenue tient ; dès qu'un brûleur vital est mesuré à sec, la bande de combustible part
  ok(Th.fuel_starved(0, fl, 0) == false, "p7 ouverture : stock nul, aucun brûleur a sec : pas affame (retenue)")
  ok(Th.fuel_starved(0, fl, 3) == true, "p8 stock nul et 3 brûleurs a sec : affame")
  ok(Th.fuel_starved(1e6, fl, 3) == false, "p9 stock qui ponte l'horizon : pas affame malgre des brûleurs a sec")
  ok(Th.fuel_starved(0, 0, 3) == false, "p10 sans plancher lu : pas affame")
  return bad
end
local function cablage(txt)
  local bad = 0
  local a = txt:find("local iron_waiting = false", 1, true)
  local b = txt:find("Th.raw_holds({ tier", 1, true)
  local zone = (a and b and a < b) and txt:sub(a, b) or ""
  if not zone:find("burn = burn or fuel_floor(f, surface)", 1, true) then bad = bad + 1 end
  if zone:find("fuel_burn(f, surface)", 1, true) then bad = bad + 1 end
  if not zone:find("short = Th.fuel_starved(free[spec.product] or 0, burn, dry_n)", 1, true) then bad = bad + 1 end
  if not zone:find("dry_n = dry_n or burners_dry(f)", 1, true) then bad = bad + 1 end
  if not zone:find("if is_fuel then", 1, true) then bad = bad + 1 end
  return bad
end
check(plancher_cas(Mc) == 0, "le plancher de la retenue compte les brûleurs")
check(cablage(mig) == 0, "la retenue FER-D-ABORD mesure le manque au plancher de l'équipe (fuel_floor), pas aux seuls générateurs")
print("== mutants")
local f2 = io.open("shared/team/thermique.lua", "rb")
local src = f2:read("*a")
f2:close()
local mutants = {
  { "tier 1 attend le fer", "return (tier or 0) == 0 and why == \"plaques\"", "return why == \"plaques\"" },
  { "autre cause", "and why == \"plaques\"", "and why ~= nil" },
  { "voulu retenu", "or (c.tier or 0) ~= 1 or c.wanted then", "or (c.tier or 0) ~= 1 then" },
  { "tier 0 retenu", "or (c.tier or 0) ~= 1 or c.wanted then", "or (c.tier or 0) > 1 or c.wanted then" },
  { "drapeau ignore", "if c.iron_waiting ~= true or", "if false or" },
  { "borne ignoree", "if c.since ~= nil and (c.now or 0) - c.since >= cfg.iron_hold_max then", "if false then" },
  { "borne d'un tick trop tard", ">= cfg.iron_hold_max then", "> cfg.iron_hold_max then" },
  { "combustible retenu", "if c.fuel and c.fuel_short then", "if false then" },
  { "toute bande brute exemptee", "if c.fuel and c.fuel_short then", "if c.fuel_short then" },
  { "manque sans consommation", "if (floor or 0) <= EPS then return false end", "if (floor or 0) <= EPS then return true end" },
  { "manque : horizon ignore", "(stock or 0) + EPS < floor * cfg.horizon", "(stock or 0) + EPS < floor" },
  { "horloge jamais reprise", "local live = since ~= nil and last ~= nil and tick - last <= cfg.iron_hold_gap", "local live = since ~= nil and last ~= nil" },
  { "horloge remise a chaque refus", "if live then return since, tick end", "if live then return tick, tick end" },
  { "horloge jamais eteinte", "if live then return since, last end", "if true then return since, last end" },
  { "affame sans brûleur a sec", "return (dry or 0) > 0 and M.fuel_short(stock, floor, cfg)", "return M.fuel_short(stock, floor, cfg)" },
  { "affame sans le stock", "return (dry or 0) > 0 and M.fuel_short(stock, floor, cfg)", "return (dry or 0) > 0" },
}
for _, m in ipairs(mutants) do
  local x, y = src:find(m[2], 1, true)
  if not x then check(false, "motif introuvable : " .. m[1])
  else
    local chunk = load(src:sub(1, x - 1) .. m[3] .. src:sub(y + 1), "=mut", "t")
    local Tm = chunk and chunk()
    if not Tm then check(false, "mutant illisible : " .. m[1])
    else
      local Ta = Th
      Th = Tm
      local p0, f0 = passes, failures
      local n = body()
      passes, failures = p0, f0
      Th = Ta
      QUIET = false
      check(n > 0, "mutant detecte : " .. m[1])
    end
  end
end
print("== mutants du plancher (F481)")
local f3 = io.open("shared/team/migration_combustible.lua", "rb")
local msrc = f3:read("*a")
f3:close()
QUIET = true
for _, m in ipairs({
  { "plancher sans les brûleurs", "total = total + math.max(0, b.kw or 0) * math.max(0, b.n or 0) / fuel_kj", "total = total" },
  { "plancher sans les générateurs", "local total = math.max(0, gen or 0)", "local total = 0" },
}) do
  local x, y = msrc:find(m[2], 1, true)
  if not x then QUIET = false check(false, "motif introuvable : " .. m[1]) QUIET = true
  else
    local McM = load(msrc:sub(1, x - 1) .. m[3] .. msrc:sub(y + 1), "=mutmc", "t")()
    local n = plancher_cas(McM)
    QUIET = false check(n > 0, "mutant detecte : " .. m[1]) QUIET = true
  end
end
for _, m in ipairs({
  { "retour aux seuls générateurs (le défaut)", "burn = burn or fuel_floor(f, surface)", "burn = burn or fuel_burn(f, surface)" },
  { "manque jamais lu", "short = Th.fuel_starved(free[spec.product] or 0, burn, dry_n)", "short = false" },
  { "brûleurs à sec ignorés (le 1er cycle)", "short = Th.fuel_starved(free[spec.product] or 0, burn, dry_n)", "short = Th.fuel_short(free[spec.product] or 0, burn)" },
  { "exemption du combustible retiree", "if is_fuel then", "if false then" },
}) do
  local src2 = mig:gsub(string.char(13), "")
  local a = src2:find("local iron_waiting = false", 1, true) or 1
  local x, y = src2:find(m[2], a, true)
  if not x then QUIET = false check(false, "motif introuvable : " .. m[1]) QUIET = true
  else
    local n = cablage(src2:sub(1, x - 1) .. m[3] .. src2:sub(y + 1))
    QUIET = false check(n > 0, "mutant detecte : " .. m[1]) QUIET = true
  end
end
QUIET = false
print(string.format("[FER-D-ABORD] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
