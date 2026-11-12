--[[
  Lot CC-PETROLE (F492) : test hors jeu du départ PROGRESSIF d'une extension de champ de puits (shared/team/chantier_progressif.lua,
  Cp.ready_lead et l'aiguillage de Cp.go), mutants de la règle, et relecture du câblage (build.lua, petrole.lua) dans la source.
  Mesure d'origine (playtest 0.6.87 du DC, graine 3592985581) : site de brut du joueur fini à 62,9 min avec 2 chevalets sur 15 puits ;
  extension (projet 37 : 11 chevalets, 89 tuyaux, 13 poteaux) en « reserve:materiaux » jusqu'à 93,7 min, 0 entité bâtie sur 113.
  Usage : lua5.2 tests/petrole_progressif_test.lua   (depuis la racine du mod)
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
-- 1. Règle pure (noms neutres : la règle ne connaît que le rôle « tête » donné par le plan)
---------------------------------------------------------------------------------------------------
-- le projet 37 : 11 extracteurs, 89 conduites, 14 poteaux (13 + 1 de ligne)
local NEED = { ["a-tete"] = 11, ["b-conduite"] = 89, ["c-poteau"] = 14 }
local LEAD = { ["a-tete"] = true }
local AT73 = { ["a-tete"] = 0, ["b-conduite"] = 89, ["c-poteau"] = 14 }  -- conduites et poteaux réunis, aucun extracteur
local AT76 = { ["a-tete"] = 1, ["b-conduite"] = 89, ["c-poteau"] = 14 }  -- le premier extracteur remis à 76,3 min

local function ext(need, stock, extra)
  local p = { state = "reserve", spec = { site = "petrole", ext = true, base = 26 }, need = need, stock = stock, lead = LEAD }
  for k, v in pairs(extra or {}) do p[k] = v end
  return p
end

local function suite(Cp)
  local ok, bad = 0, {}
  local function c(cond, m) if cond then ok = ok + 1 else bad[#bad + 1] = m end end
  -- la mesure
  local g73, d73 = Cp.ready_lead(NEED, AT73, LEAD)
  c(g73 == false, "73 min : aucun extracteur réservé, l'extension attend")
  c(#d73.short == 1 and d73.short[1][1] == "a-tete" and d73.short[1][2] == 1, "73 min : le manque nommé est un extracteur")
  local g76, d76 = Cp.ready_lead(NEED, AT76, LEAD)
  c(g76 == true, "76 min : un extracteur réservé, l'extension part (au lieu de 0 entité bâtie à 93,7 min)")
  c(d76.pieces == 104 and d76.total == 114, "pièces comptées 104/114 (" .. tostring(d76.pieces) .. "/" .. tostring(d76.total) .. ")")
  c(Cp.ready(NEED, AT76) == false, "le tout-ou-rien d'avant (Cp.ready) refuse encore à 76 min : 8 extracteurs au plancher")
  -- plancher commun des autres objets
  c(Cp.ready_lead(NEED, { ["a-tete"] = 1, ["b-conduite"] = 59, ["c-poteau"] = 14 }, LEAD) == false, "59 conduites sur 89 (plancher 60) : attend")
  c(Cp.ready_lead(NEED, { ["a-tete"] = 1, ["b-conduite"] = 60, ["c-poteau"] = 14 }, LEAD) == true, "60 conduites sur 89 : part")
  c(Cp.ready_lead(NEED, { ["a-tete"] = 1, ["b-conduite"] = 89, ["c-poteau"] = 9 }, LEAD) == false, "9 poteaux sur 14 (plancher 10) : attend")
  c(Cp.ready_lead(NEED, { ["a-tete"] = 11, ["b-conduite"] = 89, ["c-poteau"] = 14 }, LEAD) == true, "réserve complète : part")
  -- tête
  c(Cp.ready_lead({ ["a-tete"] = 1, ["b-conduite"] = 3 }, { ["a-tete"] = 1, ["b-conduite"] = 3 }, LEAD) == true, "un extracteur demandé, réservé : part")
  c(Cp.ready_lead({ ["a-tete"] = 1, ["b-conduite"] = 3 }, { ["b-conduite"] = 3 }, LEAD) == false, "un extracteur demandé, absent : attend")
  c(Cp.ready_lead(NEED, AT76, {}) == false, "aucun objet de tête désigné : pas un champ de puits, tout-ou-rien gardé")
  c(Cp.ready_lead({ ["b-conduite"] = 89 }, { ["b-conduite"] = 89 }, LEAD) == false, "tête désignée mais non demandée (déjà bâtie) : non")
  c(Cp.ready_lead({}, {}, LEAD) == false, "kit vide : non")
  c(Cp.ready_lead(NEED, { ["a-tete"] = 40, ["b-conduite"] = 89, ["c-poteau"] = 14 }, LEAD) == true, "réserve au-delà du besoin : part")
  local _, dx = Cp.ready_lead(NEED, { ["a-tete"] = 40, ["b-conduite"] = 89, ["c-poteau"] = 14 }, LEAD)
  c(dx.pieces == 114, "réserve bornée au besoin (" .. tostring(dx.pieces) .. ")")
  c(Cp.ready_lead(NEED, AT76, LEAD) == Cp.ready_lead(NEED, AT76, LEAD), "déterministe")
  -- aiguillage de Cp.go
  c(Cp.go(ext(NEED, AT76)) == true, "Cp.go : extension de champ en réserve, un extracteur réservé : part")
  c(Cp.go(ext(NEED, AT73)) == false, "Cp.go : extension sans extracteur : attend")
  local g1, w1 = Cp.go(ext(NEED, AT76, { state = "chantier" })) c(g1 == false and w1 == "etat", "Cp.go : hors état reserve : non")
  local g2, w2 = Cp.go(ext(NEED, AT76, { reopened = 3 })) c(g2 == false and w2 == "rouvert", "Cp.go : extension rouverte : Rr.partial_go la couvre")
  local g3, w3 = Cp.go({ state = "reserve", spec = { site = "petrole", rangee = true, ext = true }, need = NEED, stock = AT76, lead = LEAD })
  c(g3 == false and w3 == "pas une bande", "Cp.go : rangée de modules : tout-ou-rien gardé (" .. tostring(w3) .. ")")
  local g4 = Cp.go({ state = "reserve", spec = { site = "petrole" }, need = NEED, stock = AT76, lead = LEAD })
  c(g4 == false, "Cp.go : site de base (sans ext) : tout-ou-rien gardé")
  local g5 = Cp.go({ state = "reserve", spec = { site = "petrole", ext = "oui" }, need = NEED, stock = AT76, lead = LEAD })
  c(g5 == false, "Cp.go : ext doit valoir true")
  -- la bande garde sa règle
  local NB = { x = 3 }
  c(Cp.go({ state = "reserve", spec = { champ = { oid = 1, pr = 2 } }, need = NB, stock = { x = 2 } }) == true, "bande neuve : règle d'avant inchangée")
  return ok, bad
end

local Cp0 = assert(load_rule(SRC))
local ok0, bad0 = suite(Cp0)
for _, b in ipairs(bad0) do fail = fail + 1 print("  ECHEC : " .. b) end
pass = pass + ok0
print(string.format("[PETROLE-PROGRESSIF] règle : %d OK, %d ECHEC(S)", ok0, #bad0))

---------------------------------------------------------------------------------------------------
-- 2. Mutants (chacun doit faire échouer au moins un contrôle)
---------------------------------------------------------------------------------------------------
local DISPATCH = "  if s and s.ext == true and not s.rangee then return Cp.ready_lead(p.need or {}, p.stock or {}, p.lead or {}) end -- lot CC-PETROLE\n"
local REOPEN = "  if p.reopened and p.reopened ~= 0 then return false, \"rouvert\" end\n"
-- Lot SORTIE-PLAQUES : bloc de la garde du dégel (commentaires compris), tiré tel quel de la source
local DEGEL = SRC:match("\n(  %-%- Lot SORTIE%-PLAQUES %(B5%).-  if s and s%.degel and not p%.degele then return false, \"degel\" end\n)") or "<degel introuvable>"
local MUTANTS = {
  { "aiguillage retiré (tout-ou-rien d'avant)", DISPATCH, "" },
  { "rangée de modules acceptée", "if s and s.ext == true and not s.rangee then", "if s and s.ext == true then" },
  { "ext non strict", "if s and s.ext == true and not s.rangee then", "if s and s.ext and not s.rangee then" },
  { "aucun extracteur exigé", "Cp.LEAD_MIN = 1 ", "Cp.LEAD_MIN = 0 " },
  { "extracteurs au plancher commun", "        fl = math.min(Cp.LEAD_MIN, n)\n", "" },
  { "autres objets exigés en entier", "      local fl = Cp.floor(n)\n      if lead[it] then", "      local fl = n\n      if lead[it] then" },
  { "tête non exigée dans le besoin", "return #short == 0 and leads > 0, {", "return #short == 0, {" },
  { "réserve non bornée au besoin",
    "      local have = math.min(math.floor(tonumber(stock[it]) or 0), n)\n      pieces, total = pieces + have, total + n\n      local fl = Cp.floor(n)\n      if lead[it] then",
    "      local have = math.floor(tonumber(stock[it]) or 0)\n      pieces, total = pieces + have, total + n\n      local fl = Cp.floor(n)\n      if lead[it] then" },
  -- (lot SORTIE-PLAQUES : la garde du dégel s'intercale entre p.spec et l'aiguillage ; seule la garde du rouvert descend)
  { "aiguillage avant la garde du rouvert", REOPEN .. "  local s = p.spec\n" .. DEGEL .. DISPATCH, "  local s = p.spec\n" .. DEGEL .. DISPATCH .. REOPEN },
}
local refused = 0
for _, mu in ipairs(MUTANTS) do
  local a, b = SRC:find(mu[2], 1, true)
  local a2 = a and SRC:find(mu[2], b + 1, true)
  if not a or a2 then
    fail = fail + 1 print("  ECHEC : mutant introuvable ou ambigu : " .. mu[1])
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
print(string.format("[PETROLE-PROGRESSIF] mutants refusés : %d sur %d", refused, #MUTANTS))

---------------------------------------------------------------------------------------------------
-- 3. Câblage relu dans la source
---------------------------------------------------------------------------------------------------
local B = read("script/team/build.lua")
local a = B:find("local function lead_items(p)", 1, true)
check(a ~= nil, "build.lua : lead_items défini")
local seg = a and B:sub(a, a + 400) or ""
check(seg:find("if not (p.spec and p.spec.ext) then return nil end", 1, true), "lead_items : nil hors extension (la bande garde sa règle)")
check(seg:find('e.role == "extracteur" and e.item and not e.built', 1, true), "lead_items : rôle « extracteur » du plan, objet qui le pose, pas encore bâti")
check(B:find("stock = p.stock, lead = lead_items(p) })", 1, true), "état reserve : les objets de tête sont passés à Build.Cp.go")
check(a and a < (B:find("prog, pd = Build.Cp.go(", 1, true) or 0), "lead_items défini avant son appel")
check(B:find('p.spec.ext and "extension de champ de puits"', 1, true), "journal [FO-CHANTIER-PROGRESSIF] : l'extension est nommée")
local P = read("script/ai3/petrole.lua")
check(P:find('if not (br and (br.state == "reserve" or br.progressif)) then return end', 1, true), "Pet.wanted : une extension partie garde ses manques voulus par la recherche")
check(P:find('local id = Build.request(f, { site = "petrole", ext = true, base = s.id', 1, true), "extend_site demande l'extension avec ext = true")
check(not P:find("rangee = true, ext = true", 1, true) and not P:find("ext = true, rangee = true", 1, true), "une rangée n'est jamais demandée avec ext")
local Fl = read("shared/ai3/fluides.lua")
check(select(2, Fl:gsub('role = "extracteur"', "")) >= 2, "les plans du site et de l'extension posent le rôle « extracteur »")
check(B:find("role = e.role", 1, true), "build.lua garde le rôle des entités d'un plan de site")
-- aucun nom d'objet du jeu dans la règle
check(not SRC:find("pumpjack") and not SRC:find('"pipe') and not SRC:find("medium%-electric%-pole"), "aucun nom d'objet en dur dans la règle")

print(string.format("[PETROLE-PROGRESSIF] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
