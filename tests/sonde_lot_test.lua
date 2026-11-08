--[[
  Lot TV-PLACE, G37 : test hors jeu de shared/team/sonde_lot.lua (sonde de 30 x 30 autour d'un lot, lot en bord de gisement).
    lua5.2 tests/sonde_lot_test.lua   -> [SONDE-LOT] BILAN : N OK, 0 ECHEC(S)
  Mutants : substitution unique dans le source, rechargé ; la suite doit ECHOUER. Ressources FICTIVES (r_commun, r_rare).
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/team/sonde_lot.lua"
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[SONDE-LOT] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local SRC = read(PATH)
local function load_mod(src) return assert(load(src, "=" .. PATH, "t", _ENV))() end
local SEUILS = { min_tiles = 24, tiles = { r_rare = 4 }, amount = {}, sum = 1000000 }

local function suite(Sl)
  local bad, n = {}, 0
  local function want(ok, msg) n = n + 1 if not ok then bad[#bad + 1] = msg end end
  -- 1. Géométrie : 24 x 24 -> 30 x 30 centré, le treillis ne bouge pas.
  want(Sl.SIZE == 30, "sonde de 30")
  want(Sl.margin(24) == 3, "marge de 3 pour un lot de 24")
  want(Sl.margin(30) == 0 and Sl.margin(40) == 0, "un lot deja large comme la sonde (ou plus) : aucune marge, jamais negative")
  local x0, y0, x1, y1 = Sl.rect(100, -50, 124, -26)
  want(x0 == 97 and y0 == -53 and x1 == 127 and y1 == -23, "rect 30 x 30 centre sur le lot (97,-53)-(127,-23)")
  want((x1 - x0) == 30 and (y1 - y0) == 30, "la sonde fait 30 de cote")
  local a0, b0, a1, b1 = Sl.rect(0, 0, 24, 24)
  want(a0 == -3 and b0 == -3 and a1 == 27 and b1 == 27, "rect a l'origine")
  -- 2. Bord de gisement.
  local m, nw, ni = Sl.edge({ res = {} }, { res = { r_commun = 30 } }, SEUILS)
  want(m == "r_commun" and nw == 30 and ni == 0, "aucun minerai dans le lot, 30 tuiles dans la sonde : bord")
  m = Sl.edge({ res = { r_commun = 5 } }, { res = { r_commun = 23 } }, SEUILS)
  want(m == nil, "23 tuiles dans la sonde : sous le seuil, pas un bord")
  m = Sl.edge({ res = { r_commun = 24 } }, { res = { r_commun = 40 } }, SEUILS)
  want(m == nil, "le lot est deja de minerai : c'est un gisement, pas un bord")
  m = Sl.edge({ res = { r_commun = 10 } }, { res = { r_commun = 10 } }, SEUILS)
  want(m == nil, "rien de plus au-dela du lot")
  m, nw, ni = Sl.edge({ res = { r_commun = 10 } }, { res = { r_commun = 26 } }, SEUILS)
  want(m == "r_commun" and nw == 26 and ni == 10, "10 dans le lot, 26 dans la sonde : bord (compte rendu)")
  m = Sl.edge({ res = {} }, { res = { r_rare = 5 } }, SEUILS)
  want(m == "r_rare", "ressource rare : seuil par ressource lu en donnees")
  m = Sl.edge({ res = {} }, { res = { r_commun = 24 }, amount = {} }, nil)
  want(m == "r_commun", "sans seuils : defaut de 24 tuiles")
  m = Sl.edge({ res = { r_a = 20 }, amount = { r_a = 100 } }, { res = { r_a = 20, r_b = 5 }, amount = { r_a = 100, r_b = 1500000 } }, SEUILS)
  want(m == nil, "le minerai principal n'a pas de tuile de plus au-dela du lot : pas un bord")
  m = Sl.edge({ res = {} }, nil, SEUILS)
  want(m == nil, "sans sonde : rien")
  m = Sl.edge(nil, { res = { r_commun = 30 } }, SEUILS)
  want(m == "r_commun", "relevé du lot absent : traité comme vide")
  m = Sl.edge({ res = {} }, { res = { r_a = 600, r_b = 600 }, amount = { r_a = 600000, r_b = 600001 } }, SEUILS)
  want(m == "r_a" or m == "r_b", "somme des quantites au-dessus du seuil de somme : bord")
  -- 3. Sortes admises.
  want(Sl.allows(nil, "fabrique") == true, "fabrique sur un lot ordinaire")
  want(Sl.allows("r_commun", "fabrique") == false, "fabrique refusee sur un bord")
  want(Sl.allows("r_commun", "fonte") == true and Sl.allows("r_commun", "extraction") == true, "fonte et extraction admises sur un bord")
  want(Sl.allows("r_commun", "inconnue") == false and Sl.allows(nil, "inconnue") == false, "sorte inconnue : refus")
  -- 4. États : la marque no_edge ne touche que la fabrique.
  local fab = Sl.states_for("fabrique")
  want(#fab == 1 and fab[1].libre and fab[1].defricher and fab[1].no_edge == true and not fab[1].gisement, "fabrique : lots libres, marque no_edge")
  local fo = Sl.states_for("fonte")
  want(#fo == 2 and fo[1].no_edge == nil and fo[2].gisement and fo[2].no_edge == nil, "fonte : ni marque, ni perte du repli sur gisement")
  local ex = Sl.states_for("extraction")
  want(#ex == 1 and ex[1].gisement and ex[1].no_edge == nil, "extraction : gisement sans marque")
  local en = Sl.states_for("energie")
  want(#en == 1 and en[1].rive and en[1].no_edge == nil, "energie : rive sans marque")
  want(#Sl.states_for("inconnue") == 0, "sorte inconnue : aucun etat")
  fab[1].gisement = true
  want(not Sl.states_for("fabrique")[1].gisement, "copies : la table rendue n'est pas partagee")
  -- 5. Déterminisme.
  local r1 = { Sl.rect(5, 6, 29, 30) }
  local r2 = { Sl.rect(5, 6, 29, 30) }
  want(r1[1] == r2[1] and r1[4] == r2[4], "deterministe")
  return bad, n
end

local bad, n = suite(load_mod(SRC))
for _, m in ipairs(bad) do check(false, m) end
pass = pass + (n - #bad)

-- Mutants : chacun doit être refusé par la suite.
local MUTANTS = {
  { "Sl.SIZE = 30", "Sl.SIZE = 24" },
  { "Sl.SIZE = 30", "Sl.SIZE = 32" },
  { "if m < 0 then m = 0 end", "" },
  { "return x0 - mx, y0 - my, x1 + mx, y1 + my", "return x0 - mx, y0 - my, x1 + mx + 1, y1 + my" },
  { "if Lm.role(inner or {}, seuils) == \"minerai\" then return nil end", "" },
  { "if n_wide <= n_in then return nil end", "" },
  { "if edge and not Sl.KIND_EDGE_OK[kind] then", "if false then" },
  { "KIND_EDGE_OK = { extraction = true, fonte = true, energie = true }", "KIND_EDGE_OK = { extraction = true, energie = true }" },
  { "if kind == \"fabrique\" then", "if kind == \"fonte\" then" },
}
local killed = 0
for i, mu in ipairs(MUTANTS) do
  local s, e = SRC:find(mu[1], 1, true)
  if not s then
    check(false, "mutant " .. i .. " : motif introuvable")
  else
    local src2 = SRC:sub(1, s - 1) .. mu[2] .. SRC:sub(e + 1)
    local ok, mod = pcall(load_mod, src2)
    local survived = ok and #(suite(mod)) == 0
    if survived then check(false, "mutant " .. i .. " survit : " .. mu[1]) else killed = killed + 1 end
  end
end
pass = pass + killed
print(string.format("[SONDE-LOT] BILAN : %d OK, %d ECHEC(S) (dont %d mutants sur %d refuses)", pass, fail, killed, #MUTANTS))
os.exit(fail == 0 and 0 or 1)
