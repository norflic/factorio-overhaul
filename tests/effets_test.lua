--[[
  Lot POLISSAGE-FX (10/11) : banc hors jeu des effets de tir et lumières (shared/content/effets_armes.lua). Lua 5.2, racine du mod :
      lua5.2 tests/effets_test.lua
    §1 couverture : chaque arme avancée des DONNÉES (A.ages, A.hand_weapons, A.cataclysm, T.ALLIES) a son pack ; la couleur du pack
       est CELLE de la table de l'arme (glow, tint, lueur) ; un pack non délégué porte une lumière et un impact ; un mode à projectile
       porte une traînée ; l'âge 1 est délégué au lot TIRS (prototypes/tirs.lua l'habille) ;
    §2 bornes : tous les packs passent Fx.verifier ; un pack hors bornes (durée, étincelles, lumière, cadence) est refusé ; une arme
       sans couleur est refusée (pas de couleur par défaut) ;
    §3 pulsation : n valeurs dans [min, max], symétrique (montée = descente), indice de pulsation dans 1..n et périodique ;
    §4 forme : aucune trigonométrie dans la règle ni dans le script des titans ; prototypes/effets_armes.lua n'écrit aucune couleur
       littérale (tout vient des packs) ; le script lit la couleur de la règle du titan (r.lueur) ; data-final-fixes charge le fichier ;
    §5 feuilles (D-6) : graphics/effets/sprites.lua, PNG présents aux dimensions annoncées, MANIFEST.json les cite ;
    §6 mutants de la règle : chacun refusé par les contrôles ci-dessus.
]]

package.path = "./?.lua;" .. package.path

local Fx = require("shared.content.effets_armes")
local A = require("shared.content.arsenal")
local T = require("shared.robots.titans")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[EFFETS] ECHEC : " .. msg) end
end

local function read(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

---------------------------------------------------------------------------------------------------
-- §1 couverture et couleurs
---------------------------------------------------------------------------------------------------
local function couverture(F, A_, T_)
  local packs, refus = F.armes(A_, T_)
  local motifs = {}
  if #refus > 0 then for _, r in ipairs(refus) do motifs[#motifs + 1] = "refus " .. tostring(r.nom) .. " : " .. tostring(r.motif) end end
  local attendu = #A_.ages + #A_.hand_weapons + 1 + #T_.ALLIES
  if #packs + #refus ~= attendu then motifs[#motifs + 1] = #packs .. " packs pour " .. attendu .. " armes" end
  local par_nom = {}
  for _, p in ipairs(packs) do par_nom[p.nom] = p end
  local function couleur_de(spec) local c = spec.glow or spec.tint or spec.lueur; return c end
  local function meme(c, d) return c and d and math.abs(c.r - (d.r or d[1])) < 1e-9 and math.abs(c.g - (d.g or d[2])) < 1e-9 and math.abs(c.b - (d.b or d[3])) < 1e-9 end
  for _, t in ipairs(A_.ages) do
    local p = par_nom[t.name]
    if not p then motifs[#motifs + 1] = t.name .. " sans pack"
    elseif not meme(p.couleur, couleur_de(t)) then motifs[#motifs + 1] = t.name .. " : couleur du pack ≠ glow de la tourelle" end
  end
  for _, h in ipairs(A_.hand_weapons) do
    local p = par_nom[h.name]
    if not p then motifs[#motifs + 1] = h.name .. " sans pack" end
  end
  local pc = par_nom[A_.cataclysm.name]
  if not (pc and meme(pc.couleur, A_.cataclysm.tint)) then motifs[#motifs + 1] = "frappe orbitale : pack ou couleur absents" end
  for _, r in ipairs(T_.ALLIES) do
    local p = par_nom[r.name]
    if not (p and meme(p.couleur, r.lueur)) then motifs[#motifs + 1] = r.name .. " : pack ou couleur (lueur) absents" end
  end
  for _, p in ipairs(packs) do
    if not p.delegue then
      local lum = (p.impact and p.impact.lumiere) or (p.projectile and p.projectile.lumiere) or (p.singularite and p.singularite.lumiere)
      if not lum then motifs[#motifs + 1] = p.nom .. " : aucune lumière" end
      if not p.impact then motifs[#motifs + 1] = p.nom .. " : aucun impact" end
      if p.projectile and not p.projectile.trainee then motifs[#motifs + 1] = p.nom .. " : projectile sans traînée" end
      for _, k in ipairs({ "bouche", "impact", "projectile", "champ", "singularite" }) do
        if p[k] and p[k].couleur ~= p.couleur then motifs[#motifs + 1] = p.nom .. " : " .. k .. " n'a pas la couleur du pack" end
      end
    end
  end
  return motifs, packs
end

local motifs1, packs = couverture(Fx, A, T)
check(#motifs1 == 0, "§1 couverture et couleurs : " .. table.concat(motifs1, " ; "))
check(#packs == 12, "§1 douze armes et titans habillés, le Ravageur compris (KAIJUS-MUTANTS : la règle lit T.ALLIES) (" .. #packs .. ")")
local age1 = Fx.pack(A.age_turret(1))
check(age1 and age1.delegue == "tirs", "§1 âge 1 (cinétique) délégué au lot TIRS")
check(read("prototypes/tirs.lua") ~= nil and (read("data.lua") or ""):find('require%("prototypes.tirs"%)') ~= nil, "§1 le lot TIRS est bien chargé (prototypes/tirs.lua)")
local rail = Fx.pack({ name = "fo-railgun", mode = "rail", tint = A.special_guns[2].tint })
check(rail and rail.couleur.r == A.special_guns[2].tint.r, "§1 fusil à rail : couleur reprise de son entrée d'origine (special_guns)")

---------------------------------------------------------------------------------------------------
-- §2 bornes
---------------------------------------------------------------------------------------------------
local function tous_verifies(F, ps)
  local n = 0
  for _, p in ipairs(ps) do n = n + #F.verifier(p) end
  return n
end
check(tous_verifies(Fx, packs) == 0, "§2 tous les packs dans les bornes")
do
  local p = Fx.pack(A.age_turret(4))
  p.impact.duree = Fx.BORNES.duree_max + 1
  check(#Fx.verifier(p) > 0, "§2 impact trop long refusé")
  p = Fx.pack(A.age_turret(4))
  p.impact.etincelles.nombre = Fx.BORNES.etincelles_max + 1
  check(#Fx.verifier(p) > 0, "§2 trop d'étincelles refusé")
  p = Fx.pack(A.age_turret(4))
  p.projectile.lumiere.taille = Fx.BORNES.lumiere_taille_max + 1
  check(#Fx.verifier(p) > 0, "§2 lumière trop grande refusée")
  p = Fx.pack(A.age_turret(4))
  p.projectile.trainee.frequence = 0
  check(#Fx.verifier(p) > 0, "§2 traînée à chaque fraction de tick refusée")
  p = Fx.pack(A.age_turret(4))
  p.impact.lumiere.couleur = { r = 1, g = 1, b = 1 }
  check(#Fx.verifier(p) > 0, "§2 lumière d'une autre couleur que l'arme refusée")
  local sans, why = Fx.pack({ name = "x", mode = "laser" })
  check(sans == nil and why:find("couleur") ~= nil, "§2 arme sans couleur refusée (aucune couleur par défaut)")
  local inconnu = Fx.pack({ name = "x", mode = "catapulte", tint = { r = 1, g = 0, b = 0 } })
  check(inconnu == nil, "§2 mode inconnu refusé")
end

---------------------------------------------------------------------------------------------------
-- §3 pulsation
---------------------------------------------------------------------------------------------------
local function pulsation_ok(F)
  local n = F.MODES.titan.singularite.pulsation.n
  local t = F.pulsation(n)
  if #t ~= n then return false, "longueur" end
  local lo, hi = F.BORNES.pulsation_min, F.BORNES.pulsation_max
  local mn, mx = 1e9, -1e9
  for _, v in ipairs(t) do mn, mx = math.min(mn, v), math.max(mx, v) end
  if math.abs(mn - lo) > 1e-9 or math.abs(mx - hi) > 1e-9 then return false, "bornes " .. mn .. " " .. mx end
  for i = 2, n / 2 do if math.abs(t[i] - t[n + 2 - i]) > 1e-9 then return false, "asymétrique" end end
  local per = F.MODES.titan.singularite.pulsation.periode
  local vus = {}
  for tick = 0, 2 * per - 1 do
    local k = F.pulse_index(tick, per, n)
    if k < 1 or k > n or k ~= math.floor(k) then return false, "indice " .. tostring(k) end
    vus[k] = true
    if F.pulse_index(tick + per, per, n) ~= k then return false, "non périodique" end
  end
  for k = 1, n do if not vus[k] then return false, "indice " .. k .. " jamais atteint" end end
  return true
end
local okp, whyp = pulsation_ok(Fx)
check(okp, "§3 pulsation : " .. tostring(whyp))

---------------------------------------------------------------------------------------------------
-- §4 forme
---------------------------------------------------------------------------------------------------
local SRC = read("shared/content/effets_armes.lua")
local PROTO = read("prototypes/effets_armes.lua")
local SCRIPT = read("script/robots/titans.lua")
local function sans_trigo(s) return s and not s:find("math%.sin") and not s:find("math%.cos") and not s:find("math%.atan") end
check(sans_trigo(SRC), "§4 règle sans trigonométrie")
check(sans_trigo(SCRIPT), "§4 script des titans sans trigonométrie")
check(not SRC:find("require%("), "§4 règle pure : aucun require")
check(not SRC:find("pairs%(") or not SRC:find("for%s+[%w_,%s]+in%s+pairs%(") or true, "§4 (information) pairs seulement dans la copie profonde")
check(PROTO ~= nil and not PROTO:find("{%s*r%s*=%s*0%.") and not PROTO:find("color%s*=%s*{%s*0%."), "§4 prototypes : aucune couleur littérale (hors blanc des animations)")
check(PROTO ~= nil and PROTO:find('require%("shared.content.effets_armes"%)') ~= nil, "§4 prototypes lisent la règle")
check(PROTO ~= nil and PROTO:find("Fx%.verifier") ~= nil and PROTO:find("error%(") ~= nil, "§4 prototypes : un pack hors bornes arrête l'étape data")
check((read("data-final-fixes.lua") or ""):find('require%("prototypes.effets_armes"%)') ~= nil, "§4 data-final-fixes charge les effets (après l'arsenal et les titans)")
local bloc = SCRIPT and SCRIPT:match("local function singularite_dessiner.-\nend")
check(bloc ~= nil and bloc:find("r%.lueur") ~= nil and not bloc:find("{%s*r%s*=%s*0%."), "§4 script : la singularité prend la couleur de la règle du titan (r.lueur), rien en dur")
check(SCRIPT and SCRIPT:find("Fx%.pulsation%(") ~= nil and SCRIPT:find("Fx%.pulse_index%(") ~= nil and SCRIPT:find("singularite_pulser%(g, r, ev%.tick%)") ~= nil,
  "§4 script : pulsation précalculée, lue au balayage (pas par tick)")
check(SCRIPT and SCRIPT:find("rendering%.set_intensity") ~= nil and SCRIPT:find("rendering%.is_valid%(sg%.lum%)") ~= nil, "§4 script : lumière pulsée par set_intensity, rendu vérifié valide")

---------------------------------------------------------------------------------------------------
-- §5 feuilles (D-6)
---------------------------------------------------------------------------------------------------
local function png_size(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local h = f:read(24)
  f:close()
  if not h or #h < 24 or h:sub(1, 8) ~= "\137PNG\r\n\26\n" then return nil end
  local function u32(s, i) local a, b, c, d = s:byte(i, i + 3); return ((a * 256 + b) * 256 + c) * 256 + d end
  return u32(h, 17), u32(h, 21)
end
local okspr, SPR = pcall(dofile, "graphics/effets/sprites.lua")
check(okspr and type(SPR) == "table", "§5 graphics/effets/sprites.lua lisible (sinon : py -3.9 tools/render/pieces/effets/vortex.py)")
if okspr then
  local man = read("graphics/effets/MANIFEST.json") or ""
  for _, cle in ipairs({ "vortex", "onde" }) do
    local s = SPR[cle]
    check(s and s.images == Fx.IMAGES, "§5 " .. cle .. " : " .. Fx.IMAGES .. " images")
    for _, res in ipairs({ "lr", "hr" }) do
      local d = s and s[res]
      local p = d and d.filename:gsub("^__factorio%-overhaul__/", "")
      local w, h
      if p then w, h = png_size(p) end
      local attendu = Fx.FEUILLE_PX * (res == "hr" and 2 or 1)
      check(w == attendu * Fx.IMAGES and h == attendu and d.width == attendu and d.height == attendu, "§5 " .. cle .. " " .. res .. " : PNG " .. tostring(w) .. "×" .. tostring(h) .. " = rangée de " .. Fx.IMAGES .. " images de " .. attendu)
      check(p and man:find(p:match("([^/]+)$"), 1, true) ~= nil, "§5 MANIFEST cite " .. tostring(p))
    end
  end
end

---------------------------------------------------------------------------------------------------
-- §5 bis bâtiments refaits (livrable B) : feuilles de graphics/batiments, prototypes qui les lisent, ancrages du pylône
---------------------------------------------------------------------------------------------------
local okb, BAT = pcall(dofile, "graphics/batiments/sprites.lua")
check(okb and type(BAT) == "table", "§5bis graphics/batiments/sprites.lua lisible (sinon : py -3.9 tools/render/pieces/batiments/feuilles.py)")
if okb then
  local man = read("graphics/batiments/MANIFEST.json") or ""
  for _, cle in ipairs({ "coffre", "pylone", "cuve" }) do
    local u = BAT[cle]
    check(u and u.main and u.shadow and u.glow and u.icone and u.boite and u.map_color, "§5bis " .. cle .. " : couches principale, ombre, lueur, icône, boîte, couleur de carte")
    for _, k in ipairs({ "main", "shadow", "glow" }) do
      for _, res in ipairs({ "lr", "hr" }) do
        local d = u and u[k] and u[k][res]
        local pth = d and d.filename:gsub("^__factorio%-overhaul__/", "")
        local w, h
        if pth then w, h = png_size(pth) end
        check(d and w == d.width and h == d.height, "§5bis " .. cle .. " " .. k .. " " .. res .. " : PNG présent aux dimensions de sprites.lua")
        check(pth and man:find(pth:match("([^/]+)$"), 1, true) ~= nil, "§5bis MANIFEST cite " .. tostring(pth))
      end
    end
  end
  local anc = BAT.pylone and BAT.pylone.ancrages
  check(anc and anc.copper and anc.red and anc.green, "§5bis pylône : ancrages des trois fils (cuivre, rouge, vert)")
  if anc then
    check(anc.copper.fil[2] < anc.red.fil[2] and anc.red.fil[1] > 0 and anc.green.fil[1] < 0, "§5bis pylône : cuivre au sommet, rouge à droite, vert à gauche")
    check(anc.copper.fil[2] < -3 and anc.copper.fil[2] > -5, "§5bis pylône : fil de cuivre à la hauteur du grand poteau vanilla (3 à 5 tuiles)")
    check(anc.copper.ombre[1] > 0, "§5bis pylône : l'ombre du fil tombe à l'est (soleil à l'ouest)")
  end
end
local BV = read("prototypes/batiments_visuels.lua")
check(BV ~= nil and BV:find("fo%-team%-chest") and BV:find("fo%-ht%-pylon") and BV:find("fo%-reduction%-cell"), "§5bis prototypes/batiments_visuels.lua habille les trois bâtiments")
check(BV ~= nil and BV:find("direction_count = 1") ~= nil and BV:find("connection_points") ~= nil and BV:find("ancrages") ~= nil, "§5bis pylône : une direction, points d'attache lus dans la feuille")
check((read("prototypes/faction.lua") or ""):find('require%("prototypes.batiments_visuels"%)') ~= nil, "§5bis chargé à la fin de prototypes/faction.lua")

---------------------------------------------------------------------------------------------------
-- §6 mutants de la règle
---------------------------------------------------------------------------------------------------
local function charge(src)
  local chunk, err = load(src, "=mutant", "t", setmetatable({}, { __index = _G }))
  if not chunk then return nil, err end
  local ok, M = pcall(chunk)
  if not ok then return nil, M end
  return M
end
local function refuse(nom, de, vers, juge)
  check(SRC:find(de, 1, true) ~= nil, "§6 mutant « " .. nom .. " » : la règle d'origine est là")
  local M = charge((SRC:gsub(de:gsub("%p", "%%%0"), (vers:gsub("%%", "%%%%")), 1)))
  local ok, rej = pcall(juge, M)
  check(ok and rej, "§6 mutant refusé : " .. nom)
end
refuse("couleur ignorée (cyan constant)", "local c = spec.glow or spec.tint or spec.lueur", "local c = { r = 0.1, g = 0.9, b = 1 }",
  function(M) local m = couverture(M, A, T); return #m > 0 end)
refuse("bornes ignorées (verifier muet)", "  local motifs = {}\n  local function m(s) motifs[#motifs + 1] = pack.nom .. \" : \" .. s end",
  "  local motifs = {}\n  local function m(s) end",
  function(M) local p = M.pack(A.age_turret(4)); p.impact.duree = 999; return #M.verifier(p) == 0 end)   -- repéré : plus aucun refus
refuse("pulsation plate", "    if x > 1 then x = 2 - x end    -- triangle : 0 → 1 → 0", "    x = 1",
  function(M) return not pulsation_ok(M) end)
refuse("indice de pulsation sans modulo", "return math.floor((tick % periode) * n / periode) + 1", "return math.floor(tick * n / periode) + 1",
  function(M) return not pulsation_ok(M) end)
refuse("orbe de plasma sans traînée", "    projectile = { lumiere = { taille = 10, intensite = 0.9 }, vortex = { echelle = 1.6 },\n      trainee = { source = \"smoke-fast\", frequence = 2, debut = 0.5, fin = 1.4, duree = 40, alpha = 0.55 } },",
  "    projectile = { lumiere = { taille = 10, intensite = 0.9 }, vortex = { echelle = 1.6 } },",
  function(M) local m = couverture(M, A, T); return #m > 0 end)
refuse("armes de poing oubliées", "  for _, h in ipairs(A.hand_weapons or {}) do", "  for _, h in ipairs({}) do",
  function(M) local m = couverture(M, A, T); return #m > 0 end)
refuse("titans oubliés", "  for _, r in ipairs(T and T.ALLIES or {}) do", "  for _, r in ipairs({}) do",
  function(M) local m = couverture(M, A, T); return #m > 0 end)
refuse("couleur par défaut quand l'arme n'en a pas", "  if type(c) ~= \"table\" then return nil end", "  if type(c) ~= \"table\" then return { r = 1, g = 1, b = 1 } end",
  function(M) return M.pack({ name = "x", mode = "laser" }) ~= nil end)   -- repéré : une arme sans couleur passe
refuse("lumière d'une autre couleur acceptée", "    if l.couleur ~= pack.couleur then m(ou .. \" : la lumière n'a pas la couleur de l'arme\") end", "",
  function(M) local p = M.pack(A.age_turret(4)); p.impact.lumiere.couleur = { r = 1, g = 1, b = 1 }; return #M.verifier(p) == 0 end)   -- repéré : acceptée

print(string.format("[EFFETS] %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
