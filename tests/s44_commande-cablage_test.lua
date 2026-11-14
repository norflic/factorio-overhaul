--[[
  s44 commande-cablage : l'état écrit par le panneau « Commandement » (f.team.commande, comme script/gui/commande.lua) est bien lu par
  le cerveau : poids des familles (Co.weights, script/ai3/cerveau.lua), caractère de la capitalisation (Ca.character, avec
  Co.production_first comme script/ai3/capitalisation.lua), et un ordre de gisement n'est rempli que par un avant-poste NÉ après lui.
  lua5.2 tests/s44_commande-cablage_test.lua
]]
package.path = "./?.lua;" .. package.path
local Co = require("shared.ai3.commande")
local B = require("shared.ai3.buts")
local Ca = require("shared.ai3.capitalisation")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("ECHEC : " .. msg) end
end

-- Le handler (clic d'orientation) écrit cstate(f).orient = k dans f.team.commande.
local f = { team = { commande = Co.new_state() } }
local function click(k) if Co.valid_orientation(k) then f.team.commande.orient = k end end

-- Les quatre orientations demandées par le DC existent, avec leurs textes FR et EN.
local function read(path) local h = io.open(path, "r"); local s = h:read("*a"); h:close(); return s end
local fr, en = read("locale/fr/commande.cfg"), read("locale/en/commande.cfg")
for _, k in ipairs({ "economie", "defense", "expansion", "recherche" }) do
  check(Co.valid_orientation(k), "orientation " .. k)
  check(fr:find("\nor%-" .. k .. "=") and fr:find("\nor%-" .. k .. "%-aide=") ~= nil, "texte FR " .. k)
  check(en:find("\nor%-" .. k .. "=") and en:find("\nor%-" .. k .. "%-aide=") ~= nil, "texte EN " .. k)
end

-- Lecteur du cerveau (Ia3.plan_a) : w = Co.weights(B.weights(...), t.commande.orient, ...).
local function brain_w()
  local w = B.weights(nil, nil, false)
  local cmd = f.team.commande
  if cmd then w = Co.weights(w, cmd.orient, B.W_MIN, B.W_MAX, B.FAMILIES) end
  return w
end
local w0 = brain_w()
click("recherche"); local wr = brain_w()
check(wr.recherche > w0.recherche and wr.armee < w0.armee, "Recherche : poids recherche monte, armée baisse")
click("economie"); local we = brain_w()
check(we.capital > w0.capital and we.extraction > w0.extraction, "Économie : capital et extraction montent")
click("expansion"); local wx = brain_w()
check(wx.extraction > we.extraction, "Expansion : extraction au-dessus d'Économie")

-- Capitalisation de votre équipe : « production d'abord » (cas du journal, d=0 a=0) ; Défense la lève.
local pf = true
local function capi_ch()
  local p = Co.production_first(pf, f.team.commande.orient)
  return Ca.character(nil, brain_w(), false, p, nil)
end
click("aucune"); local c0 = capi_ch()
check(c0.delta == 0 and c0.alpha == 0, "sans orientation : production d'abord, défense 0")
click("defense"); local cd = capi_ch()
check(cd.delta > 0 and cd.alpha > 0, "Défense : part défense et armée > 0 (" .. cd.delta .. ", " .. cd.alpha .. ")")
click("amelioration"); local ca = capi_ch()
check(ca.s > c0.s, "Amélioration : réinvestissement s monte (" .. c0.s .. " -> " .. ca.s .. ")")
check(Co.production_first(false, "defense") == false and Co.production_first(true, "economie") == true, "levée bornée à Défense")

-- Gisement prioritaire : l'avant-poste déjà là (numéro 1) ne remplit plus l'ordre ; un avant-poste neuf (numéro 4) le remplit.
local cs = f.team.commande
local id = Co.add(cs, { kind = "gisement", x = 0, y = -23, r = 27, resource = "r1", outpost = "k1", tick = 195661, after_oid = 3 })
check(id ~= nil and cs.orders[#cs.orders].after_oid == 3, "ordre posé avec le dernier numéro d'avant-poste")
check(#Co.resolve(cs, { { id = 1, kind = "k1", x = 2, y = -20 } }) == 0, "avant-poste ancien dans la zone : pas rempli")
check(#Co.resolve(cs, { { id = 1, kind = "k1", x = 2, y = -20 }, { id = 4, kind = "k1", x = 5, y = -25 } }) == 1, "avant-poste neuf : rempli")
-- Ordre d'une ancienne sauvegarde (sans after_oid) : règle d'avant.
cs.orders[#cs.orders].after_oid = nil
check(#Co.resolve(cs, { { id = 1, kind = "k1", x = 2, y = -20 } }) == 1, "ordre sans after_oid : règle d'avant")
-- Le but du cerveau reste émis tant que l'ordre vit (site en réserve dans la zone).
check(#Co.ready(Co.deposits(cs), { { resource = "r1", x = 4, y = -30 } }) == 1, "ordre prêt : but émis")

print(string.format("s44 commande-cablage : %d OK, %d echec(s)", passes, failures))
if failures > 0 then os.exit(1) end
