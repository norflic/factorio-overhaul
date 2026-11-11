--[[
  Banc hors jeu du lot MEGA-BOURDON (11/11, mandat du DC du 10/11, 22 h 20, chantier A §2 : « une déclinaison lourde, massive et menaçante
  du bourdon, dotée d'armes lourdes intégrées et de blindages angulaires taillés »).
  Usage, depuis la racine du mod :   lua5.2 tests/megabourdon_test.lua

  1. VARIANTES : nom, relais et poids au plafond du Bourdon et du Méga-Bourdon (shared/robots/bourdon.lua) ; le plafond demande DEUX places
     libres au Méga-Bourdon, une au Bourdon (comportement d'avant inchangé).
  2. ARME : les casemates tirent l'orbe du Bastion d'armement 4 (portée, portée minimale, cadence, vitesse, rayon repris tels quels), aux
     dégâts de la salve de l'âge 15 (Ech.salve, règle E3) partagée entre les CANONS et dans les proportions de l'orbe Bastion.
  3. FABRICATION : un Bourdon plus une seconde fois sa matière, deux fois son temps ; technologie après celle du Bourdon, deux fois son coût.
  4. BRANCHEMENT : le prototype (PV doublés, orbe, objet, relais, recette, technologie), le script (compte pondéré, relais et sortie du
     Méga-Bourdon, casemates appelées une fois posée, plafond pondéré) et les textes FR et EN existent.
  5. FEUILLES : graphics/robots/megabourdon/sprites.lua a le corps, ses lueurs (dont le vortex cyan), l'ombre et 4 bouches.
  6. MUTANTS : chaque altération des règles ou du branchement fait échouer au moins un contrôle.
  Lot ART-MEGA2 (ordre du DC du 11/11, 9 h 47 : « une taille strictement 2 fois supérieure, minimum 200 % à 250 % de l'échelle du Bourdon ») :
  ÉCHELLE dans les règles (B.MEGA.ECHELLE entre 2 et 2,5 ; chaînes, ancres, battant et boîtes homothétiques), dans le branchement (le script
  prend l'échelle des feuilles, le prototype agrandit ses boîtes et déclare un sprite par tuile, que le script dessine ensemble) et dans les feuilles (sprites.lua à
  l'échelle des règles, corps à cette échelle mesuré contre le Bourdon, aucun fichier au-delà de 4096 px, les tuiles pavent leur image).
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local function lire(chemin)
  local f = io.open(chemin, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local A = require("shared.content.arsenal")
local Ech = require("shared.robots.echelle")
local SRC_B = lire("shared/robots/bourdon.lua")

--- Charge le module des règles depuis son texte (éventuellement muté).
local function charge(texte)
  local f = assert(load(texte, "=bourdon", "t", setmetatable({}, { __index = _G })))
  return f()
end

--- Les contrôles des règles ; rend le nombre d'échecs qu'ils ont produits.
local function regles(B, muet)
  local avant = failures
  local ck = muet and function(c) if not c then failures = failures + 1 else passes = passes + 1 end end or check
  -- 1. variantes
  ck(B.variante("fo-bourdon") == "bourdon", "variante du Bourdon")
  ck(B.variante("fo-mega-bourdon") == "mega", "variante du Méga-Bourdon")
  ck(B.variante("fo-titan-juggernaut") == nil, "une autre entité n'est pas une cloche")
  ck(B.nom_de("mega") == "fo-mega-bourdon" and B.nom_de(nil) == "fo-bourdon" and B.nom_de("bourdon") == "fo-bourdon", "nom par variante")
  ck(B.nom_de("autre") == nil, "variante inconnue : pas de nom")
  ck(B.poids("fo-bourdon") == 1, "le Bourdon compte pour un géant")
  ck(B.poids("fo-mega-bourdon") == 2, "le Méga-Bourdon compte pour deux géants")
  ck(B.poids("fo-autre") == 0, "une autre entité ne compte pas")
  ck(B.variante_pose("fo-bourdon-pose") == "bourdon" and B.variante_pose("fo-mega-bourdon-pose") == "mega", "relais par variante")
  ck(B.variante_pose("fo-bourdon-item") == nil, "l'objet n'est pas un relais")
  -- plafond pondéré
  ck(B.peut_poser({ actif = true, geants = 2, admis = 3 }) == true, "Bourdon : 2 géants sur 3, une place libre : il descend")
  ck(B.peut_poser({ actif = true, geants = 3, admis = 3 }) == false, "Bourdon : plafond atteint")
  ck(B.peut_poser({ actif = true, geants = 2, admis = 3, poids = 2 }) == false, "Méga-Bourdon : une seule place libre, il ne descend pas")
  ck(B.peut_poser({ actif = true, geants = 1, admis = 3, poids = 2 }) == true, "Méga-Bourdon : deux places libres, il descend")
  ck(B.peut_poser({ actif = false, geants = 0, admis = 3, poids = 2 }) == false, "robots éteints")
  ck(B.sortie({ objets = 1, actif = true, geants = 2, admis = 3, poids = 2 }) == false, "sortie du Portique pondérée")
  ck(B.sortie({ objets = 1, actif = true, geants = 1, admis = 3, poids = 2 }) == true, "sortie du Portique : deux places")
  -- 2. arme
  local spec = A.age_turret(B.MEGA.ARME_AGE)
  local sl, se = Ech.salve(B.AGE, "laser"), Ech.salve(B.AGE, "explosion")
  local a = B.arme_mega(spec, sl, se)
  ck(type(a) == "table", "arme calculée")
  if type(a) == "table" then
    local P = spec.plasma
    local tot = P.direct + P.area.laser + P.area.explosion
    local n = B.MEGA.CANONS
    ck(a.portee == spec.range and a.portee_min == spec.min_range and a.recharge == spec.cooldown, "portée et cadence de l'orbe Bastion")
    ck(a.vitesse == P.speed and a.rayon == P.radius, "vitesse et rayon de l'orbe Bastion")
    ck(a.direct == math.ceil(sl * P.direct / tot / n), "coup direct : part de la salve de l'âge 15 par casemate")
    ck(a.zone_laser == math.ceil(sl * P.area.laser / tot / n), "zone laser : part de la salve laser")
    ck(a.zone_explosion == math.ceil(se * P.area.explosion / tot / n), "zone d'explosion : part de la salve d'explosion")
    ck(a.direct > P.direct and a.zone_laser > P.area.laser, "plus lourde que l'orbe du Bastion")
    -- une volée des 4 casemates livre (à l'arrondi près) la salve de l'âge
    local volee_l = n * (a.direct + a.zone_laser)
    ck(math.abs(volee_l - sl * (P.direct + P.area.laser) / tot) <= n, "volée : la part laser de la salve")
  end
  ck(B.arme_mega(nil, sl, se) == nil and B.arme_mega(spec, nil, se) == nil, "arme : entrées invalides")
  -- quinconce
  local vus = {}
  local ok = true
  for k = 1, B.MEGA.CANONS do
    local d = B.decalage_canon(k, 0, spec.cooldown)
    if d < 0 or d >= spec.cooldown or vus[d] then ok = false end
    vus[d] = true
  end
  ck(ok, "les casemates tirent en quinconce dans la recharge")
  -- tourelles : 16 directions, nord = 0, sens des aiguilles ; un cran par le plus court chemin ; bouche au bout des canons
  ck(B.direction16(0, -1) == 0 and B.direction16(1, 0) == 4 and B.direction16(0, 1) == 8 and B.direction16(-1, 0) == 12, "directions cardinales")
  ck(B.direction16(1, -1) == 2 and B.direction16(-1, -1) == 14 and B.direction16(-1, 1) == 10, "directions diagonales")
  ck(B.direction16(0, 0) == nil and B.direction16(nil, 1) == nil, "vecteur nul : pas de direction")
  ck(B.pas_tourelle(0, 15) == 15 and B.pas_tourelle(15, 0) == 0, "un cran par le plus court chemin, en passant le nord")
  ck(B.pas_tourelle(0, 8) == 1, "demi-tour : sens des aiguilles")
  ck(B.pas_tourelle(14, 2) == 15 and B.pas_tourelle(2, 14) == 1, "plus court chemin des deux côtés")
  ck(B.pas_tourelle(5, 5) == 5, "alignée : elle reste")
  local bx0, by0 = B.bouche(0)
  local bx4, by4 = B.bouche(4)
  ck(math.abs(bx0) < 1e-9 and math.abs(by0 + B.MEGA.CANON_L * B.COS45) < 1e-6, "bouche vers le nord : raccourcie par la vue")
  ck(math.abs(bx4 - B.MEGA.CANON_L) < 1e-6 and math.abs(by4) < 1e-6, "bouche vers l'est : longueur pleine")
  ck(B.MEGA.TOURNE == math.ceil((1 / B.MEGA.N_DIR) / 0.01), "un cran au pas de la tourelle laser vanilla (0,01 tour par tick)")
  -- 3. fabrication
  local F = B.FAB_MEGA
  ck(F.temps == 2 * B.FAB.temps, "temps : deux fois celui du Bourdon")
  ck(F.ingredients[1][1] == B.OBJET and F.ingredients[1][2] == 1, "un Bourdon en premier ingrédient")
  ck(#F.ingredients == #B.FAB.ingredients + 1, "plus la matière du Bourdon")
  local meme = true
  for i, g in ipairs(B.FAB.ingredients) do
    local h = F.ingredients[i + 1]
    if not (h and h[1] == g[1] and h[2] == g[2] and h[2] <= 100) then meme = false end
  end
  ck(meme, "matière du Bourdon une seconde fois (au plus 100 de chaque, RB0-1)")
  ck(B.TECH_MEGA.count == 2 * B.TECH.count and B.TECH_MEGA.epoch == B.AGE and B.TECH_MEGA.time == B.TECH.time, "technologie : deux fois le coût, même âge")
  ck(B.TECH_MEGA.prerequisites[1] == B.TECHNO and #B.TECH_MEGA.prerequisites == 1, "technologie après celle du Bourdon")
  -- échelle (lot ART-MEGA2)
  local k = B.MEGA.ECHELLE
  ck(type(k) == "number" and k >= 2.0 and k <= 2.5, "échelle du Méga-Bourdon : de 200 à 250 % du Bourdon (ordre du DC)")
  ck(B.echelle("mega") == k and B.echelle("bourdon") == 1 and B.echelle(nil) == 1, "échelle par variante")
  local function pres(a, b) return math.abs(a - b) < 1e-6 end
  local homo = true
  for i = 1, #B.ANCRES do
    local gx, gy = B.sol(i, k)
    if not (pres(gx, B.ANCRES[i].sol[1] * k) and pres(gy, B.ANCRES[i].sol[2] * k)) then homo = false end
    for _, ex in ipairs({ 0, 0.5, 1 }) do
      local x1, y1 = B.bas_chaine(i, ex)
      local xk, yk = B.bas_chaine(i, ex, k)
      if not (pres(xk, x1 * k) and pres(yk, y1 * k)) then homo = false end
      local c1x, c1y = B.centre_chaine(i, x1, y1)
      local ckx, cky = B.centre_chaine(i, xk, yk, k)
      if not (pres(ckx, c1x * k) and pres(cky, c1y * k)) then homo = false end
      local a1x, a1y = B.ancre_depuis_bas(x1, y1)
      local akx, aky = B.ancre_depuis_bas(xk, yk, k)
      if not (pres(akx, a1x * k) and pres(aky, a1y * k)) then homo = false end
    end
  end
  ck(homo, "ancres, chaînes et sol homothétiques à l'échelle du Méga-Bourdon")
  local bx1, by1 = B.centre_battant(1.5, -10, 0.03)
  local bxk, byk = B.centre_battant(1.5 * k, -10 * k, 0.03, k)
  ck(pres(bxk, bx1 * k) and pres(byk, by1 * k), "battant : pivot et feuille à l'échelle")
  local bo = B.boite_mega({ { -11, -44 }, { 11, 0 } })
  ck(pres(bo[1][1], -11 * k) and pres(bo[1][2], -44 * k) and pres(bo[2][1], 11 * k) and bo[2][2] == 0, "boîte du Méga-Bourdon : celle du Bourdon à l'échelle")
  return failures - avant
end

section("1-3. règles (shared/robots/bourdon.lua)")
local B = charge(SRC_B)
regles(B)

section("4. branchement")
local PROTO = lire("prototypes/bourdon.lua") or ""
local SCRIPT = lire("script/robots/bourdon.lua") or ""
local function branche(proto, script, muet)
  local avant = failures
  local ck = muet and function(c) if not c then failures = failures + 1 else passes = passes + 1 end end or check
  ck(proto:find("mega.max_health = Bm.pv_mega(VEHICULE.max_health)", 1, true) ~= nil, "prototype : PV doublés depuis le Bourdon")
  ck(proto:find("mega.name = Bm.MEGA.NOM", 1, true) ~= nil, "prototype : le véhicule du Méga-Bourdon")
  ck(proto:find("orbe.name = Bm.MEGA.ORBE", 1, true) ~= nil, "prototype : l'orbe des casemates")
  ck(proto:find("Bm.arme_mega(spec, Ech2.salve(Bm.AGE, \"laser\"), Ech2.salve(Bm.AGE, \"explosion\"))", 1, true) ~= nil, "prototype : dégâts par la règle")
  ck(proto:find("type = \"recipe\", name = Bm.MEGA.RECETTE", 1, true) ~= nil, "prototype : recette")
  ck(proto:find("name = Bm.TECH_MEGA.name", 1, true) ~= nil, "prototype : technologie")
  ck(proto:find("type = \"simple-entity-with-owner\", name = Bm.MEGA.POSE", 1, true) ~= nil, "prototype : relais")
  ck(script:find("n = n + B.poids(b.e.name)", 1, true) ~= nil, "script : compte pondéré au plafond")
  ck(script:find("if not (e and e.valid and B.variante_pose(e.name)) then return end", 1, true) ~= nil, "script : relais des deux cloches")
  ck(script:find("return sortie_une(usine, inv, rally, \"mega\", B.MEGA.OBJET)", 1, true) ~= nil, "script : sortie du Portique du Méga-Bourdon")
  ck(script:find("if b.v == \"mega\" and b.e.valid and b.phase == \"pose\" then tir_canons(b, tick) end", 1, true) ~= nil,
    "script : casemates appelées, cloche posée")
  ck(script:find("poids = B.poids(B.nom_de(v)) }) then", 1, true) ~= nil, "script : plafond pondéré à la pose")
  ck(script:find("name = B.MEGA.ORBE", 1, true) ~= nil, "script : les casemates tirent l'orbe")
  ck(script:find("if tick >= b.canons_t[k] and t.d == t.vise then", 1, true) ~= nil, "script : une tourelle tire une fois alignée")
  ck(script:find("t.d = B.pas_tourelle(t.d, t.vise)", 1, true) ~= nil, "script : la tourelle tourne d'un cran vers sa cible")
  ck(script:find("for k, t in ipairs(b.tourelles) do place_tourelle(b, k, t) end", 1, true) ~= nil, "script : les tourelles suivent la cloche")
  -- lot ART-MEGA2 : échelle
  ck(script:find("if b and b.v == \"mega\" then return tonumber(SPRM.echelle) or 1 end", 1, true) ~= nil, "script : échelle prise des feuilles")
  ck(script:find("local bx, by = B.bas_chaine(i, ex, k)", 1, true) ~= nil, "script : ancres placées à l'échelle")
  ck(script:find("B.centre_battant(sb[1] * k, sb[2] * k, o, k)", 1, true) ~= nil, "script : battant à l'échelle")
  ck(script:find("{ orientation = a.o, x_scale = 1.25 * k, y_scale = k }", 1, true) ~= nil, "script : chaînes agrandies")
  ck(proto:find("mega.selection_box = Bm.boite_mega(VEHICULE.selection_box)", 1, true) ~= nil, "prototype : boîte de sélection à l'échelle")
  ck(proto:find("mega.drawing_box = Bm.boite_mega(VEHICULE.drawing_box)", 1, true) ~= nil, "prototype : boîte de dessin à l'échelle")
  ck(proto:find("pm.hr_version = bloc(th, s)", 1, true) ~= nil and proto:find("pm.name = Bm.MEGA.NOM .. \"-\" .. k .. \"-t\" .. i", 1, true) ~= nil,
    "prototype : un sprite par tuile, hr compris")
  ck(script:find("ids[i] = rendering.draw_sprite({ sprite = n .. \"-t\" .. i", 1, true) ~= nil, "script : les tuiles d'une couche dessinées ensemble")
  ck(script:find("cible_couche(id, f, e, sh[1], sh[2] - d)", 1, true) ~= nil, "script : les tuiles suivent la cloche")
  return failures - avant
end
branche(PROTO, SCRIPT)
for _, lang in ipairs({ "fr", "en" }) do
  local t = lire("locale/" .. lang .. "/bourdon.cfg") or ""
  for _, cle in ipairs({ "fo-mega-bourdon=", "fo-mega-bourdon-item=", "fo-robot-mega-bourdon=" }) do
    check(t:find("\n" .. cle, 1, true) ~= nil, "texte " .. lang .. " : " .. cle)
  end
end

section("5. feuilles (graphics/robots/megabourdon/sprites.lua)")
local okS, SPRM = pcall(dofile, "graphics/robots/megabourdon/sprites.lua")
check(okS and type(SPRM) == "table", "sprites.lua du Méga-Bourdon")
if okS and type(SPRM) == "table" then
  for _, k in ipairs({ "corps", "vitrail", "cristal", "vortex", "corps-ombre" }) do
    local e = SPRM[k]
    check(type(e) == "table" and e.hr and e.lr and type(e.shift) == "table", "feuille " .. k)
  end
  check(SPRM.vortex and SPRM.vortex.blend == "additive" and SPRM.vortex.lueur == true, "vortex en lueur additive")
  check(SPRM["corps-ombre"] and SPRM["corps-ombre"].ombre == true, "ombre marquée ombre")
  check(type(SPRM.canons) == "table" and #SPRM.canons == 4, "4 pivots de tourelles")
  check(type(SPRM.canons_sol) == "table" and #SPRM.canons_sol == 4, "4 pieds de pivots")
  local toutes = true
  for k = 0, 15 do
    local a, l = SPRM[string.format("tourelle-%02d", k)], SPRM[string.format("tourelle-lueur-%02d", k)]
    if not (type(a) == "table" and a.hr and type(l) == "table" and l.blend == "additive") then toutes = false end
  end
  check(toutes, "16 directions de tourelle, et leur lueur cyan")
  if type(SPRM.canons) == "table" then
    local hauts = true
    for _, c in ipairs(SPRM.canons) do
      if not (type(c[1]) == "number" and type(c[2]) == "number" and c[2] < -10) then hauts = false end
    end
    check(hauts, "pivots sur les épaules de la cloche (au-dessus du sol, dans sa largeur)")
  end
  -- lot ART-MEGA2 : échelle et tuiles
  local k = SPRM.echelle or 1
  check(SPRM.echelle == B.MEGA.ECHELLE, "feuilles rendues à l'échelle des règles (sprites.lua, echelle = B.MEGA.ECHELLE)")
  local SPRB = dofile("graphics/robots/bourdon/sprites.lua")
  local function haut(e) return e.hr.height * e.hr.scale / 32 end
  local r = haut(SPRM.corps) / haut(SPRB.corps)
  print(string.format("  corps : %.1f tuiles de haut, Bourdon %.1f : %.0f %%", haut(SPRM.corps), haut(SPRB.corps), 100 * r))
  check(math.abs(r - k) < 0.15 * k, "corps à l'échelle des feuilles (hauteur mesurée)")
  local tuiles_ok, n_t = true, 0
  for cle, e in pairs(SPRM) do
    if type(e) == "table" and e.hr then
      for _, res in ipairs({ "hr", "lr" }) do
        local f = e[res]
        if f.tuiles then
          local aire = 0
          for _, t in ipairs(f.tuiles) do
            n_t = n_t + 1
            if not (t.width <= 4096 and t.height <= 4096 and t.scale == f.scale and type(t.decal) == "table") then tuiles_ok = false end
            aire = aire + t.width * t.height
          end
          if aire ~= f.width * f.height then tuiles_ok = false end
          if #e.hr.tuiles ~= #e.lr.tuiles then tuiles_ok = false end
        elseif not (f.width <= 4096 and f.height <= 4096) then
          tuiles_ok = false
        end
      end
    end
  end
  check(tuiles_ok, "aucun fichier au-delà de 4096 px ; les tuiles pavent leur image (" .. n_t .. " tuiles)")
  if type(SPRM.canons) == "table" then
    local larges = true
    for _, c in ipairs(SPRM.canons) do
      if not (math.abs(c[1]) < 25 * k) then larges = false end
    end
    check(larges, "pivots dans la largeur de la cloche à l'échelle")
  end
end

section("6. mutants")
local MUTANTS = {
  { "poids du Méga-Bourdon à 1", "GEANTS = 2,", "GEANTS = 1," },
  { "plafond sans le poids", "return (p.geants or 0) + (p.poids or 1) <= (p.admis or 0)", "return (p.geants or 0) < (p.admis or 0)" },
  { "sortie sans le poids", "admis = p.admis, poids = p.poids })", "admis = p.admis })" },
  { "coup direct non partagé", "direct = math.ceil(salve_laser * P.direct / tot / n),", "direct = math.ceil(salve_laser * P.direct / tot),"} ,
  { "zone d'explosion sur la salve laser", "zone_explosion = math.ceil(salve_explosion * P.area.explosion / tot / n),",
    "zone_explosion = math.ceil(salve_laser * P.area.explosion / tot / n)," },
  { "cadence inventée", "recharge = spec.cooldown,", "recharge = 30," },
  { "fabrication sans le Bourdon", "local ings = { { B.OBJET, 1 } }", "local ings = {}" },
  { "technologie sans prérequis", "prerequisites = { B.TECHNO } }", "prerequisites = {} }" },
  { "relais du Méga-Bourdon oublié", "if nom == B.MEGA.POSE then return \"mega\" end", "" },
  { "tourelle : demi-tour à contresens", "if (c - d) % n <= n / 2 then return (d + 1) % n end", "if (c - d) % n < n / 2 then return (d + 1) % n end" },
  { "tourelle : sens inversé", "local v = dx * sn - dy * c", "local v = dx * sn + dy * c" },
  { "tourelle : bouche non raccourcie", "return sn * B.MEGA.CANON_L, -c * B.MEGA.CANON_L * B.COS45", "return sn * B.MEGA.CANON_L, -c * B.MEGA.CANON_L" },
  { "quinconce perdu", "return ((k - 1) * math.floor(recharge / n) + (id or 0) * 7) % recharge", "return ((id or 0) * 7) % recharge" },
  { "échelle du Bourdon gardée", "ECHELLE = 2.2,", "ECHELLE = 1.0," },
  { "Méga-Bourdon sans échelle", "if v == \"mega\" then return B.MEGA.ECHELLE end", "" },
  { "ancre posée à l'échelle 1", "local qx, qy = a.sol[1] * k, (a.sol[2] - B.ANCRE_TETE) * k", "local qx, qy = a.sol[1], a.sol[2] - B.ANCRE_TETE" },
  { "chaîne courte", "local h = B.CHAINE_LONG * (k or 1) / 2", "local h = B.CHAINE_LONG / 2" },
  { "pivot du battant fixe", "local px, py = B.PIVOT[1] * k, B.PIVOT[2] * k", "local px, py = B.PIVOT[1], B.PIVOT[2]" },
  { "boîte non agrandie", "local k = B.MEGA.ECHELLE\n  return", "local k = 1\n  return" },
}
local refuses = 0
for _, m in ipairs(MUTANTS) do
  local nom, de, vers = m[1], m[2], m[3]
  local i, j = SRC_B:find(de, 1, true)
  if not i then
    check(false, "mutant introuvable : " .. nom)
  else
    local src = SRC_B:sub(1, i - 1) .. vers .. SRC_B:sub(j + 1)
    local ok, Bm = pcall(charge, src)
    local f0, p0 = failures, passes
    local echecs = ok and regles(Bm, true) or 1
    failures, passes = f0, p0
    check(echecs > 0, "mutant refusé : " .. nom)
    if echecs > 0 then refuses = refuses + 1 end
  end
end
local MUTANTS_BR = {
  { "script", "compte non pondéré", "n = n + B.poids(b.e.name)", "n = n + 1" },
  { "script", "casemates jamais appelées", "if b.v == \"mega\" and b.e.valid and b.phase == \"pose\" then tir_canons(b, tick) end", "" },
  { "script", "tir sans alignement", "if tick >= b.canons_t[k] and t.d == t.vise then", "if tick >= b.canons_t[k] then" },
  { "proto", "PV du Bourdon", "mega.max_health = Bm.pv_mega(VEHICULE.max_health)", "mega.max_health = VEHICULE.max_health" },
  { "script", "ancres du Bourdon", "local bx, by = B.bas_chaine(i, ex, k)", "local bx, by = B.bas_chaine(i, ex)" },
  { "script", "échelle oubliée", "if b and b.v == \"mega\" then return tonumber(SPRM.echelle) or 1 end", "" },
  { "proto", "sélection du Bourdon", "mega.selection_box = Bm.boite_mega(VEHICULE.selection_box)", "" },
  { "proto", "tuiles sans hr", "pm.hr_version = bloc(th, s)", "" },
  { "script", "tuiles immobiles", "cible_couche(id, f, e, sh[1], sh[2] - d)", "rendering.set_target(id, e, { sh[1], sh[2] - d })" },
}
for _, m in ipairs(MUTANTS_BR) do
  local quoi, nom, de, vers = m[1], m[2], m[3], m[4]
  local p, s = PROTO, SCRIPT
  local cible = quoi == "proto" and p or s
  local i, j = cible:find(de, 1, true)
  if not i then
    check(false, "mutant introuvable : " .. nom)
  else
    local mut = cible:sub(1, i - 1) .. vers .. cible:sub(j + 1)
    if quoi == "proto" then p = mut else s = mut end
    local f0, p0 = failures, passes
    local echecs = branche(p, s, true)
    failures, passes = f0, p0
    check(echecs > 0, "mutant refusé : " .. nom)
    if echecs > 0 then refuses = refuses + 1 end
  end
end
print(string.format("  %d mutants refusés sur %d", refuses, #MUTANTS + #MUTANTS_BR))

print(string.format("[MEGA-BOURDON] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
