--[[
  Lot L9 (sonder avant de décider, minerai d'abord) : test hors jeu de shared/team/lot_minerai.lua. Lancer depuis la racine du mod :
    lua5.2 tests/lot_minerai_test.lua   -> [L9] BILAN : N OK, 0 ECHEC(S)
  Mutants : substitution unique dans le source du module, rechargé ; la suite doit ÉCHOUER. Coût : instructions (debug.sethook).
  Ressources FICTIVES (r_commun, r_rare) : la règle ne connaît aucun nom du jeu.
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/team/lot_minerai.lua"
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[L9] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local SRC = read(PATH)
local function load_mod(src) return assert(load(src, "=" .. PATH, "t", _ENV))() end

local SEUILS = { min_tiles = 24, tiles = { r_rare = 4 }, amount = { r_profond = 100000 } }

local function suite(Lm)
  local bad = {}
  local function want(ok, msg) if not ok then bad[#bad + 1] = msg end end
  -- 1. Seuils PAR RESSOURCE, lus en données.
  local role, res = Lm.role({ res = { r_commun = 23 } }, SEUILS)
  want(role == "general", "23 tuiles d'une ressource commune : lot general")
  role, res = Lm.role({ res = { r_commun = 24 } }, SEUILS)
  want(role == "minerai" and res == "r_commun", "24 tuiles : minerai")
  role, res = Lm.role({ res = { r_rare = 5 } }, SEUILS)
  want(role == "minerai" and res == "r_rare", "ressource rare : 5 tuiles suffisent (seuil lu en donnees)")
  role = Lm.role({ res = { r_profond = 3 }, amount = { r_profond = 150000 } }, SEUILS)
  want(role == "minerai", "quantite au-dessus du seuil : minerai meme a 3 tuiles (G42)")
  role = Lm.role({ res = { r_profond = 3 }, amount = { r_profond = 90000 } }, SEUILS)
  want(role == "general", "quantite sous le seuil, 3 tuiles : general")
  role = Lm.role({ res = { r_commun = 30 } }, nil)
  want(role == "minerai", "sans seuils : defaut de 24 tuiles")
  -- 2. Principal : le plus de tuiles, puis le nom.
  local _, main, list = Lm.role({ res = { r_b = 40, r_a = 40, r_c = 60 } }, SEUILS)
  want(main == "r_c" and #list == 3 and list[2].res == "r_a", "minerai principal trie (tuiles, puis nom)")
  -- 3. Réservé à l'extraction et à la fonte.
  want(Lm.allows("minerai", "extraction") and Lm.allows("minerai", "fonte"), "extraction et fonte permises sur le minerai")
  want(not Lm.allows("minerai", "fabrique"), "fabrique refusee sur le minerai")
  want(not Lm.allows("minerai", "energie"), "energie refusee sur le minerai")
  want(Lm.allows("general", "fabrique"), "fabrique permise sur un lot general")
  want(not Lm.allows("general", "inconnue"), "sorte inconnue refusee (garde fermee)")
  -- 4. États essayés : jamais de repli d'une fabrique sur un gisement ; la fonte s'y replie.
  local fab = Lm.states_for("fabrique")
  local fab_g = false
  for _, s in ipairs(fab) do if s.gisement then fab_g = true end end
  want(#fab == 1 and fab[1].libre and fab[1].defricher and not fab_g, "fabrique : lots libres seulement")
  local fo = Lm.states_for("fonte")
  want(#fo == 2 and fo[1].libre and fo[2].gisement, "fonte : libres puis gisement")
  local ex = Lm.states_for("extraction")
  want(#ex == 1 and ex[1].gisement, "extraction : gisement")
  want(#Lm.states_for("inconnue") == 0, "sorte inconnue : aucun etat")
  fab[1].gisement = true
  local fab2 = Lm.states_for("fabrique")
  want(not fab2[1].gisement, "states_for rend des copies")
  -- 5. Le relevé précède la décision.
  want(Lm.needs_survey({}, 100, nil, nil) == true, "jamais releve : relever")
  want(Lm.needs_survey({ tick = 50 }, 100, nil, nil) == false, "releve recent : pas de releve")
  want(Lm.needs_survey({ tick = 50 }, 100, 60, nil) == true, "evenement apres le releve : relever")
  want(Lm.needs_survey({ tick = 50 }, 100, 40, nil) == false, "evenement avant le releve : pas de releve")
  want(Lm.needs_survey({ tick = 50 }, 20000, nil, 18000) == true, "releve trop ancien : relever")
  want(Lm.needs_survey({ tick = 50 }, 18050, nil, 18000) == false, "age egal au maximum : pas de releve")
  -- 6. Réservations à la croissance : lots neufs de minerai, ni pris ni réservés, triés par clé.
  local lots = {
    { key = "2:0", s = { res = { r_commun = 40 } } },
    { key = "1:0", s = { res = { r_rare = 6 } } },
    { key = "0:1", s = { res = { r_commun = 10 } } },
    { key = "3:0", s = { res = { r_commun = 50 } }, used = 7 },
    { key = "4:0", s = { res = { r_commun = 50 } }, reserved = true },
  }
  local rv = Lm.reserve(lots, SEUILS)
  want(#rv == 2 and rv[1].key == "1:0" and rv[1].res == "r_rare" and rv[2].key == "2:0", "reservations : 1:0 (rare) et 2:0, triees")
  -- 7. Déterminisme.
  local a, b = Lm.reserve(lots, SEUILS), Lm.reserve(lots, SEUILS)
  want(#a == #b and a[1].key == b[1].key and a[2].key == b[2].key, "deterministe")
  return bad
end

local Lm = require("shared.team.lot_minerai")
local bad = suite(Lm)
for _, m in ipairs(bad) do check(false, m) end
check(#bad == 0, "suite du module")
print(string.format("[L9] suite : %d defaut(s)", #bad))

local MUTANTS = {
  { "fabrique permise sur le minerai", "if role == \"minerai\" and not Lm.ON_ORE[kind] then", "if false then" },
  { "fonte refusee sur le minerai", "Lm.ON_ORE = { extraction = true, fonte = true }", "Lm.ON_ORE = { extraction = true }" },
  { "repli d'une fabrique sur un gisement", "fabrique = { { libre = true, defricher = true } },", "fabrique = { { libre = true, defricher = true }, { gisement = true } }," },
  { "seuil unique (pas de seuil par ressource)", "if n > 0 and n >= (st[r] or def) then why = \"tuiles\"", "if n > 0 and n >= def then why = \"tuiles\"" },
  { "quantite ignoree", "elseif sa[r] and q >= sa[r] then why = \"quantite\" end", "end" },
  { "sorte inconnue permise", "if not Lm.KINDS[kind] then return false, \"sorte inconnue (garde fermee)\" end", "" },
  { "evenement apres le releve ignore", "if type(ev_tick) == \"number\" and ev_tick > t then", "if false then" },
  { "lot jamais releve accepte", "if type(t) ~= \"number\" then return true, \"jamais releve\" end", "if type(t) ~= \"number\" then return false end" },
  { "age maximal ignore", "if type(max_age) == \"number\" and type(tick) == \"number\" and tick - t > max_age then", "if false then" },
  { "lot deja pris reserve", "if not l.used and not l.reserved then", "if not l.reserved then" },
  { "principal sans departage par le nom", "return a.res < b.res", "return a.res > b.res" },
  { "copies partagees (states_for rend la table)", "for _, set in ipairs(Lm.STATES[kind] or {}) do\n    local c = {}\n    for _, k in ipairs(sorted_keys(set)) do c[k] = set[k] end\n    out[#out + 1] = c", "for _, set in ipairs(Lm.STATES[kind] or {}) do\n    out[#out + 1] = set" },
}
local refused = 0
for _, m in ipairs(MUTANTS) do
  local s, n = SRC:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")))
  if n ~= 1 then
    check(false, "mutant introuvable (" .. n .. " substitution(s)) : " .. m[1])
  else
    local ok, Lmm = pcall(load_mod, s)
    local ran, sb = false, nil
    if ok then ran, sb = pcall(suite, Lmm) end
    local killed = (not ok) or (not ran) or (#sb > 0)
    if killed then refused = refused + 1 else print("[L9] mutant NON refuse : " .. m[1]) end
    check(killed, "mutant refuse : " .. m[1])
  end
end
print(string.format("[L9] mutants refuses : %d sur %d", refused, #MUTANTS))

local function instr(fn, n)
  local worst = 0
  for _ = 1, n do
    local c = 0
    debug.sethook(function() c = c + 1 end, "", 1)
    fn()
    debug.sethook()
    if c > worst then worst = c end
  end
  return worst
end
local s3 = { res = { r_a = 40, r_b = 12, r_c = 30 }, amount = { r_a = 5000 } }
local wr = instr(function() Lm.role(s3, SEUILS) end, 50)
local wa = instr(function() Lm.allows("minerai", "fabrique") end, 50)
local ws = instr(function() Lm.needs_survey({ tick = 50 }, 100, 60, 18000) end, 50)
local lots = {}
for i = 1, 25 do lots[i] = { key = "k" .. i, s = { res = { r_a = (i * 7) % 50, r_b = (i * 3) % 30 } } } end
local wv = instr(function() Lm.reserve(lots, SEUILS) end, 10)
print(string.format("[L9] cout : Lm.role (3 ressources) %d instructions ; Lm.allows %d ; Lm.needs_survey %d ; Lm.reserve (25 lots) %d (sethook, compte de 1)", wr, wa, ws, wv))
check(wr <= 1500 and wa <= 60 and ws <= 60 and wv <= 20000, "cout borne (role <= 1 500, allows <= 60, needs_survey <= 60, reserve 25 lots <= 20 000)")

print(string.format("[L9] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
