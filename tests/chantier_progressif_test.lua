--[[
  Lot EXPANSION-LOINTAINE : test hors jeu de la règle pure shared/team/chantier_progressif.lua (plancher par objet, départ d'une bande
  neuve sans toute sa matière), mutants de la règle, et relecture du câblage (build.lua, stock.lua, sources.lua, amorce) dans la source.
  Mesure d'origine : graine 123456789, bande 393 d'Azur en « reserve:materiaux » de 24 à 64 min avec 283 pièces sur 311 au coffre.
  Usage : lua5.2 tests/chantier_progressif_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 print("  ECHEC : " .. m) end end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end

local SRC = read("shared/team/chantier_progressif.lua")
local function load_rule(src)
  local fn, err = load(src, "=chantier_progressif", "t")
  if not fn then return nil, err end
  local ok, m = pcall(fn)
  if not ok then return nil, m end
  return m
end

---------------------------------------------------------------------------------------------------
-- 1. Règle pure
---------------------------------------------------------------------------------------------------
local function band(need, stock, extra)
  local p = { state = "reserve", spec = { champ = { oid = 3, pr = 393 } }, need = need, stock = stock }
  for k, v in pairs(extra or {}) do p[k] = v end
  return p
end

-- la mesure : 149 tapis, 52 bras, 51 poteaux, 13 foreuses, 21 fours, 25 divers ; au coffre : tout sauf 18 tapis, 4 foreuses, 4 bras (285/311)
local NEED = { ["a-tapis"] = 149, ["b-bras"] = 52, ["c-poteau"] = 51, ["d-foreuse"] = 13, ["e-four"] = 21, ["f-divers"] = 25 }
local STOCK30 = { ["a-tapis"] = 131, ["b-bras"] = 48, ["c-poteau"] = 51, ["d-foreuse"] = 9, ["e-four"] = 21, ["f-divers"] = 25 }

local function suite(Cp)
  local ok, bad = 0, {}
  local function c(cond, m) if cond then ok = ok + 1 else bad[#bad + 1] = m end end
  -- plancher
  c(Cp.floor(0) == 0, "plancher de 0 = 0")
  c(Cp.floor(1) == 1, "un objet demande une fois est attendu en entier")
  c(Cp.floor(2) == 2, "deux : les deux")
  c(Cp.floor(3) == 2, "trois : deux")
  c(Cp.floor(18) == 12, "18 : 12")
  c(Cp.floor(149) == 100, "149 : 100")
  c(Cp.floor(-4) == 0 and Cp.floor("x") == 0, "négatif ou non numérique : 0")
  -- couverture
  local go, d = Cp.ready(NEED, STOCK30)
  c(go == true, "la bande 393 à 285/311 (chaque objet au plancher) part")
  c(d.pieces == 285 and d.total == 311, "pièces comptées 283/311 (" .. tostring(d.pieces) .. "/" .. tostring(d.total) .. ")")
  c(#d.short == 0, "aucun objet sous le plancher")
  local go2, d2 = Cp.ready(NEED, { ["a-tapis"] = 149, ["b-bras"] = 52, ["c-poteau"] = 51, ["d-foreuse"] = 8, ["e-four"] = 21, ["f-divers"] = 25 })
  c(go2 == false and #d2.short == 1 and d2.short[1][1] == "d-foreuse" and d2.short[1][2] == 1, "8 foreuses sur 13 (plancher 9) : refus nommé, manque 1")
  c(Cp.ready(NEED, {}) == false, "coffre vide : refus")
  c(Cp.ready({}, {}) == false, "kit vide : refus (rien à poser)")
  c(Cp.ready({ x = 1 }, { x = 0 }) == false and Cp.ready({ x = 1 }, { x = 1 }) == true, "un objet unique : attendu en entier")
  c(Cp.ready({ x = 3 }, { x = 2 }) == true and Cp.ready({ x = 3 }, { x = 1 }) == false, "3 demandés : part à 2, pas à 1")
  c(Cp.ready(NEED, { ["a-tapis"] = 131, ["b-bras"] = 48, ["c-poteau"] = 51, ["d-foreuse"] = 7, ["e-four"] = 21, ["f-divers"] = 25 }) == false, "7 foreuses sur 13 (la mesure à 64 min) : sous le plancher 9, la production attend")
  c(Cp.ready(NEED, STOCK30) == Cp.ready(NEED, STOCK30), "déterministe")
  local _, d3 = Cp.ready({ x = 10 }, { x = 50 })
  c(d3.pieces == 10, "réserve au-delà du besoin bornée au besoin")
  -- Cp.go : garde-fous
  c(Cp.go(band(NEED, STOCK30)) == true, "bande neuve en réserve au plancher : part")
  local g1, w1 = Cp.go(band(NEED, STOCK30, { state = "chantier" })) c(g1 == false and w1 == "etat", "hors état reserve : non (" .. tostring(w1) .. ")")
  local g2, w2 = Cp.go(band(NEED, STOCK30, { reopened = 1 })) c(g2 == false and w2 == "rouvert", "projet rouvert : non (Rr.partial_go le couvre)")
  local g3, w3 = Cp.go({ state = "reserve", spec = { gen = "smelter" }, need = NEED, stock = STOCK30 }) c(g3 == false and w3 == "pas une bande", "module du capital : non")
  c(Cp.go(band(NEED, STOCK30, { reopened = 0 })) == true, "reopened = 0 vaut non rouvert")
  local g4, w4 = Cp.go({ state = "reserve", spec = { champ = { oid = 1, pr = -30, coal = -1, link = 4 } }, need = NEED, stock = STOCK30 })
  c(g4 == false and w4 == "reseau de charbon", "réseau du charbon lié à une bande : tout-ou-rien gardé (" .. tostring(w4) .. ")")
  local g5, w5 = Cp.go({ state = "reserve", spec = { champ = { oid = 1, pr = -30, coal = 1 } }, need = NEED, stock = STOCK30 })
  c(g5 == false and w5 == "reseau de charbon", "réseau du charbon autonome : tout-ou-rien gardé")
  c(Cp.go(nil) == false, "nil : non")
  -- Lot SORTIE-PLAQUES (B5, graine 2507543475, 60 min) : scarlet, bande -349 (projet 6, 23 fours de pierre) partie à 29,4 min avec 433/466
  -- pièces ; le degel retire aussitôt ses 11 paires thermiques (son fer) ; 21 tapis de sa voie de charbon jamais posés (manque transport-belt 33
  -- jusqu'à 60 min), 23 fours sans charbon dès 40 min, fer 0/min et 1 plaque au QG à 50 min, 14 foreuses de fer arrêtées « sortie pleine ».
  -- Une bande qui doit dégeler un champ qui produit garde le tout-ou-rien (comme Rr.partial_go dans build.lua) ; dégelée, elle part.
  local DG = { oid = 3, tiles = { 1, 2 } }
  local g6, w6 = Cp.go({ state = "reserve", spec = { champ = { oid = 3, pr = -349 }, degel = DG }, need = NEED, stock = STOCK30 })
  c(g6 == false and w6 == "degel", "bande à dégeler, réserve au plancher : tout-ou-rien gardé (" .. tostring(w6) .. ")")
  c(Cp.go({ state = "reserve", spec = { champ = { oid = 3, pr = -349 }, degel = DG }, degele = true, need = NEED, stock = STOCK30 }) == true,
    "bande déjà dégelée, réserve au plancher : part")
  c(Cp.go({ state = "reserve", spec = { champ = { oid = 3, pr = -349 } }, need = NEED, stock = STOCK30 }) == true, "bande sans champ à dégeler : part")
  -- texte
  local s = Cp.describe(d2)
  c(s:find("^306/311 pieces reservees") and s:find("d%-foreuse x1"), "texte du journal : " .. s)
  return ok, bad
end

local Cp0 = assert(load_rule(SRC))
local ok0, bad0 = suite(Cp0)
for _, b in ipairs(bad0) do fail = fail + 1 print("  ECHEC : " .. b) end
pass = pass + ok0
print(string.format("[CHANTIER-PROGRESSIF] règle : %d OK, %d ECHEC(S)", ok0, #bad0))

---------------------------------------------------------------------------------------------------
-- 2. Mutants (chacun doit faire échouer au moins un contrôle)
---------------------------------------------------------------------------------------------------
local MUTANTS = {
  { "part = 1 (tout-ou-rien d'avant)", "Cp.SHARE = 2 / 3", "Cp.SHARE = 1" },
  { "plancher arrondi en dessous", "return math.ceil(n * Cp.SHARE - 1e-9)", "return math.floor(n * Cp.SHARE)" },
  { "plancher strict (<=)", "if have < fl then short", "if have <= fl then short" },
  { "réserve non bornée au besoin", "local have = math.min(math.floor(tonumber(stock[it]) or 0), n)", "local have = math.floor(tonumber(stock[it]) or 0)" },
  { "kit vide accepté", "return #short == 0 and total > 0, {", "return #short == 0, {" },
  { "projet rouvert accepté", 'if p.reopened and p.reopened ~= 0 then return false, "rouvert" end', "" },
  { "tout projet accepté (pas seulement une bande)", 'if not c then return false, "pas une bande" end', 'c = c or {}' },
  { "état ignoré", 'if not (p and p.state == "reserve") then return false, "etat" end', 'if not p then return false, "etat" end' },
  { "un seul objet sous le plancher toléré", "return #short == 0 and total > 0, {", "return #short <= 1 and total > 0, {" },
  { "réseau du charbon accepté", 'if c.coal ~= nil or c.link ~= nil then return false, "reseau de charbon" end', "" },
  { "degel ignoré (SORTIE-PLAQUES)", 'if s and s.degel and not p.degele then return false, "degel" end', "" },
  { "degel jamais levé (SORTIE-PLAQUES)", 'if s and s.degel and not p.degele then return false, "degel" end', 'if s and s.degel then return false, "degel" end' },
  { "réseau lié accepté (coal seul refusé)", 'if c.coal ~= nil or c.link ~= nil then return false, "reseau de charbon" end', 'if c.coal ~= nil and c.link == nil then return false, "reseau de charbon" end' },
}
local refused = 0
for _, mu in ipairs(MUTANTS) do
  local a, b = SRC:find(mu[2], 1, true)
  if not a then
    fail = fail + 1 print("  ECHEC : mutant introuvable : " .. mu[1])
  else
    local M = load_rule(SRC:sub(1, a - 1) .. mu[3] .. SRC:sub(b + 1))
    local caught = (M == nil)
    if M then
      local okm, _, badm = pcall(suite, M)
      caught = (not okm) or (type(badm) ~= "table") or (#badm > 0)
    end
    if caught then refused = refused + 1 else fail = fail + 1 print("  ECHEC : mutant survivant : " .. mu[1]) end
  end
end
pass = pass + refused
print(string.format("[CHANTIER-PROGRESSIF] mutants refusés : %d sur %d", refused, #MUTANTS))

---------------------------------------------------------------------------------------------------
-- 3. Câblage relu dans la source (un seul écrivain de p.progressif ; lecteurs du manque qui suivent la bande partie)
---------------------------------------------------------------------------------------------------
local B = read("script/team/build.lua")
check(B:find('Build.Cp = require("shared.team.chantier_progressif")', 1, true), "build.lua charge la règle (champ de Build)")
check(B:find("local full, need = reserve(f, p)", 1, true) and B:find("prog, pd = Build.Cp.go({ state = p.state, reopened = p.reopened, degele = p.degele, spec = p.spec, need = need, stock = p.stock", 1, true),
  "état reserve : la règle est consultée avec le besoin et la réserve du projet")
check(B:find("if full or prog then", 1, true), "départ sur réserve complète OU plancher atteint")
local _, nwrites = B:gsub("p%.progressif = true", "")
check(nwrites == 1, "un seul écrivain de p.progressif (" .. nwrites .. ")")
check(B:find("[FO-CHANTIER-PROGRESSIF]", 1, true), "journal du départ progressif")
check(B:find("if (p.reopened or p.progressif or (p.spec and p.spec.lg)) and tick >= (p.miss_next or 0)", 1, true), "refresh_missing suit une bande partie sans toute sa matière")
check(B:find("local free = (Rr.partial_go(p) or p.progressif) and free_of and free_of() or nil", 1, true), "batch_tasks : pas de voyage pour un lot sans aucun objet au coffre")
check(B:find("progressif = p.progressif or nil,", 1, true), "Build.status / Build.brief exposent le drapeau")
-- la réserve de la bande en degel reste gardée : le départ progressif passe aussi par le degel
local a = B:find("if full or prog then", 1, true)
local seg = B:sub(a, a + 600)
check(seg:find('if p.spec.degel and not p.degele then', 1, true) and seg:find('p.reason, p.reserve_next = "degel", tick + 60', 1, true), "degel conservé avant le chantier (paires thermiques retirées d'abord)")
local S = read("script/team/stock.lua")
check(S:find('(p.state == "reserve" or p.progressif) and not p.abandoned and p.missing', 1, true), "stock.lua : le manque d'une bande partie compte au ramassage")
local So = read("script/team/sources.lua")
check(So:find('(p.state == "reserve" or p.progressif) and not p.abandoned and p.missing', 1, true), "sources.lua : cause d'inactivité")
local Ar = read("script/ai3/amorce_rt.lua")
check(Ar:find("(Sw.rebuilding(p) or p.progressif)", 1, true) and Ar:find("progressif = p.progressif or nil }", 1, true), "amorce_rt : la bande partie est servie en direct")
local Am = read("shared/ai3/amorce.lua")
check(Am:find('(p.state == "reserve" or p.progressif == true)', 1, true), "amorce : passe 2 pour la bande partie")
-- la règle pure ne nomme aucun objet du jeu
check(not SRC:find("transport%-belt") and not SRC:find("electric%-mining%-drill") and not SRC:find("inserter"), "aucun nom d'objet en dur dans la règle")

print(string.format("[CHANTIER-PROGRESSIF] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
