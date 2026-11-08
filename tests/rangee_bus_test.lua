--[[
  Fichier commun RANGÉE EXTENSIBLE (propriétaire MEGA-FONDERIE, 8/11) : test hors jeu de shared/team/rangee_bus.lua. Depuis la racine :
    lua5.2 tests/rangee_bus_test.lua   -> [RANGEE-BUS] BILAN : N OK, 0 ECHEC(S)
  (1) coins des modules dans les 4 sens ; (2) étendue : obstacle infranchissable, arbres à défricher, réponse inconnue, n_max, budget et
  reprise ; (3) demande, débit des lignes, croissance jamais en baisse ; (4) mutants.
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/team/rangee_bus.lua"
local pass, fail = 0, 0
local function check(ok, msg) if ok then pass = pass + 1 else fail = fail + 1 print("[RANGEE-BUS] ECHEC : " .. msg) end end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local SRC = read(PATH)
local function load_mod(src) return assert(load(src, "=" .. PATH, "t", _ENV))() end

local function suite(Rb)
  local bad, n = {}, 0
  local function want(ok, msg) n = n + 1; if not ok then bad[#bad + 1] = msg end end
  -- 1. Coins
  local x, y = Rb.origine(1, 10, 20, "x", 1, 4); want(x == 10 and y == 20, "module 1, est : au depart")
  x, y = Rb.origine(3, 10, 20, "x", 1, 4); want(x == 18 and y == 20, "module 3, est : 2 pas plus loin")
  x, y = Rb.origine(1, 10, 20, "x", -1, 4); want(x == 7 and y == 20, "module 1, ouest : finit sur la tuile de depart")
  x, y = Rb.origine(2, 10, 20, "x", -1, 4); want(x == 3, "module 2, ouest")
  x, y = Rb.origine(2, 10, 20, "y", 1, 5); want(x == 10 and y == 25, "module 2, sud")
  x, y = Rb.origine(2, 10, 20, "y", -1, 5); want(x == 10 and y == 11, "module 2, nord")
  -- 2. Étendue : un lac à x = 30..31 (y quelconque), des arbres en (13, 21) et (22, 20), une falaise au nord
  local function tuile(tx, ty)
    if tx >= 30 and tx <= 31 then return "bloque:eau" end
    if ty <= 5 then return "bloque:falaise" end
    if (tx == 13 and ty == 21) or (tx == 22 and ty == 20) then return "defricher" end
    return "libre"
  end
  local e = Rb.extent({ x = 10, y = 20, axe = "x", sens = 1, pas = 4, largeur = 3, n_max = 50, tuile = tuile })
  want(e.n == 5 and e.stop == "obstacle:eau", "est : 5 modules avant le lac (" .. e.n .. ", " .. tostring(e.stop) .. ")")
  want(#e.defricher == 2 and e.defricher[1][1] == 13 and e.defricher[2][1] == 22, "arbres : a defricher, la rangee continue")
  local e2 = Rb.extent({ x = 10, y = 20, axe = "x", sens = 1, pas = 4, largeur = 3, n_max = 3, tuile = tuile })
  want(e2.n == 3 and e2.stop == "n_max" and e2.lues == 36, "n_max : 3 modules, 36 tuiles lues")
  local e3 = Rb.extent({ x = 10, y = 20, axe = "y", sens = -1, pas = 4, largeur = 3, n_max = 50, tuile = tuile })
  want(e3.n == 3 and e3.stop == "obstacle:falaise", "nord : 3 modules avant la falaise (" .. e3.n .. ")")
  local e4 = Rb.extent({ x = 10, y = 20, axe = "x", sens = 1, pas = 4, largeur = 3, n_max = 50, tuile = function() return nil end })
  want(e4.n == 0 and e4.stop == "obstacle:inconnu", "reponse inconnue : garde fermee")
  local e5 = Rb.extent({ x = 10, y = 20, axe = "x", sens = 1, pas = 4, largeur = 3, n_max = 50, tuile = function() return "bloque:" end })
  want(e5.n == 0 and e5.stop == "obstacle:inconnu", "cause vide : inconnue")
  -- budget et reprise : même résultat qu'en une passe
  local b1 = Rb.extent({ x = 10, y = 20, axe = "x", sens = 1, pas = 4, largeur = 3, n_max = 50, tuile = tuile, budget = 25 })
  want(b1.n == 2 and b1.stop == "budget" and b1.lues == 24, "budget de 25 tuiles : 2 modules, arret budget")
  local b2 = Rb.extent({ x = 10, y = 20, axe = "x", sens = 1, pas = 4, largeur = 3, n_max = 50, tuile = tuile, debut = b1.n + 1 })
  want(b2.n == 5 and b2.stop == "obstacle:eau" and #b1.defricher + #b2.defricher == 2, "reprise au module 3 : meme fin qu'en une passe")
  want(Rb.extent(nil).stop == "invalide" and Rb.extent({ x = 0, y = 0, pas = 0, largeur = 1, n_max = 1, tuile = tuile }).stop == "invalide",
    "entrees invalides")
  want(Rb.extent({ x = 0, y = 0, pas = 2, largeur = 2, n_max = 0, tuile = tuile }).n == 0, "n_max nul : aucun module")
  -- un obstacle dans la largeur seulement arrête aussi (la rangée ne se pose pas à moitié)
  local e6 = Rb.extent({ x = 0, y = 0, axe = "x", sens = 1, pas = 2, largeur = 4, n_max = 9,
    tuile = function(tx, ty) return (tx == 5 and ty == 3) and "bloque:batiment" or "libre" end })
  want(e6.n == 2 and e6.stop == "obstacle:batiment", "obstacle sur le bord du module 3 : 2 modules")
  -- axe y : la largeur est en x ; un bâtiment juste à côté de la rangée (x = largeur) ne l'arrête pas
  local e7 = Rb.extent({ x = 0, y = 0, axe = "y", sens = 1, pas = 4, largeur = 3, n_max = 5,
    tuile = function(tx, ty) return (tx == 3) and "bloque:batiment" or "libre" end })
  want(e7.n == 5 and e7.stop == "n_max", "axe y : un batiment a cote de la rangee ne l'arrete pas (" .. e7.n .. ")")
  -- 3. Demande, débit, croissance
  want(Rb.count(41.5, 7.5) == 6 and Rb.count(15, 7.5) == 2 and Rb.count(15.0000000001, 7.5) == 2, "demande : plafond (tolerance)")
  want(Rb.count(41.5, 7.5, 4) == 4 and Rb.count(0, 7.5) == 0 and Rb.count(5, 0) == 0 and Rb.count(0 / 0, 1) == 0, "demande : bornes")
  local c, k = Rb.capacite({ 15, 7.5, 30 }, { 1, 2, 0 })
  want(c == 3 and k == 2, "capacite : la ligne 2 borne (7,5 / 2 = 3)")
  c, k = Rb.capacite({ 15 }, {})
  want(c == nil and k == nil, "capacite : aucune ligne consommee, aucune borne")
  c = Rb.capacite({}, { 1 })
  want(c == 0, "capacite : ligne absente, rien")
  local g = Rb.croissance({ n = 0, voulu = 6, extent = 9, stop = "n_max", cap = 8 })
  want(g.cible == 6 and g.cause == "demande couverte", "croissance : la demande borne")
  g = Rb.croissance({ n = 0, voulu = 6, extent = 4, stop = "obstacle:eau", cap = 8 })
  want(g.cible == 4 and g.cause == "obstacle:eau", "croissance : le lac borne")
  g = Rb.croissance({ n = 0, voulu = 6, extent = 9, stop = "n_max", cap = 3 })
  want(g.cible == 3 and g.cause == "debit:ligne", "croissance : le debit borne")
  g = Rb.croissance({ n = 5, prev = 6, voulu = 2, extent = 9, cap = 8 })
  want(g.cible == 6 and g.cause:find("jamais en baisse", 1, true) == 1, "croissance : jamais en baisse")
  g = Rb.croissance({ voulu = 6, extent = 9 })
  want(g.cible == 6, "croissance : sans borne de debit")
  return bad, n
end

local Rb = require("shared.team.rangee_bus")
local bad, nwant = suite(Rb)
for _, m in ipairs(bad) do check(false, m) end
pass = pass + nwant - #bad

-- coût : rangée de 200 modules de 10 × 40 (80 000 tuiles) relue en passes de 4 000 tuiles : chaque passe bornée
do
  local free = function() return "libre" end
  local worst, start, passes = 0, 1, 0
  while true do
    local c = 0
    debug.sethook(function() c = c + 1 end, "", 1000)
    local e = Rb.extent({ x = 0, y = 0, axe = "x", sens = 1, pas = 10, largeur = 40, n_max = 200, tuile = free, debut = start, budget = 4000 })
    debug.sethook()
    passes = passes + 1
    if c > worst then worst = c end
    if e.stop ~= "budget" then check(e.n == 200, "passes bornees : 200 modules au bout") break end
    start = e.n + 1
  end
  print(string.format("[RANGEE-BUS] cout : %d passe(s) de 4 000 tuiles, pire passe %d milliers d'instructions", passes, worst))
  check(passes == 20 and worst <= 120, "passes de 4 000 tuiles : 20 passes, au plus 120 k instructions chacune")
end

local MUTANTS = {
  { "sens ouest decale", "local a = (sens == -1) and (-k * pas + 1) or ((k - 1) * pas)", "local a = (sens == -1) and (-k * pas) or ((k - 1) * pas)" },
  { "arbre bloque", 'if t == "defricher" then here[#here + 1] = { tx, ty }', 'if false then here[#here + 1] = { tx, ty }' },
  { "inconnu libre", 'elseif t ~= "libre" then', 'elseif t ~= "libre" and t ~= nil then' },
  { "budget ignore", "if budget and lues + pas * larg > budget then", "if false then" },
  { "reprise au debut", "local k0 = max(1, floor((r.debut or 1) + EPS))", "local k0 = 1" },
  { "axe y comme x", 'if r.axe == "y" then tx, ty = x0 + j, y0 + i else', 'if false then tx, ty = x0 + j, y0 + i else' },
  { "demande arrondie en bas", "local n = ceil(demande / offre - EPS)", "local n = floor(demande / offre + EPS)" },
  { "capacite par la plus forte", "if not best or n < best then best, which = n, k end", "if not best or n > best then best, which = n, k end" },
  { "rangee qui retrecit", "if cible < floor_n then", "if false then" },
  { "debit ignore", "if cap and cap < cible then", "if false then" },
  { "defricher d'un module refuse", "for _, t in ipairs(here) do out.defricher[#out.defricher + 1] = t end", "" },
}
local refused = 0
for _, m in ipairs(MUTANTS) do
  local s2, n = SRC:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")))
  if n ~= 1 then check(false, "mutant introuvable (" .. n .. ") : " .. m[1])
  else
    local ok, Mm = pcall(load_mod, s2)
    local ran, sb = false, nil
    if ok then ran, sb = pcall(suite, Mm) end
    local killed = (not ok) or (not ran) or (#sb > 0)
    if killed then refused = refused + 1 else print("[RANGEE-BUS] mutant NON refuse : " .. m[1]) end
    check(killed, "mutant refuse : " .. m[1])
  end
end
print(string.format("[RANGEE-BUS] mutants refuses : %d sur %d", refused, #MUTANTS))
print(string.format("[RANGEE-BUS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
