--[[
  Banc hors jeu du lot DA-ICONES (03/11) : les icônes dédiées de la robotique, suite du lot ICONES-CALCUL.
  Usage, depuis la racine du mod :   lua5.2 tests/robotique_icones_test.lua

  Audit DA du 3/11 (section B) : pièces de robots, circuits, silicium, bobinages, kits, segments et technologies des robots
  n'avaient AUCUN design (objets vanilla teintés). Ce banc garantit qu'aucun ne retombe sur une copie teintée :
  1. COUVERTURE : chaque pièce et technologie de shared/content/robot_parts.lua, chaque kit, segment et technologie de
     shared/content/robots.lua, et les objets dessinés de crafts, tin et superconductors (liste DESSINES, chacun présent dans
     ses données) ont leur icône dans graphics/robotique/icones/icones.lua, sans nom en trop.
  2. FICHIERS : chaque PNG existe et a la taille d'une bande vanilla (objets : 64 px, 4 mipmaps, 120 x 64 ; technologies :
     256 px, 4 mipmaps, 480 x 256), sans fichier orphelin.
  3. BRANCHEMENT : les 5 fichiers de prototypes lisent prototypes/robotique_icones.lua, et une icône dédiée n'emporte plus la
     feuille vanilla teintée posée au sol et sur les tapis (`pictures`).
  4. MUTANTS : 14 altérations, chacune doit faire échouer au moins un contrôle.
  5. KITS : choix du DC (4/11, QCM « Caisse de famille ») : dans prototypes/robots.lua, l'icône de kit DA-ICONES passe AVANT
     l'icône du robot (SPR[r.id].icone, lot RB-V1) ; l'ordre inverse est refusé.
  Les sommes sha256 : tools/render/pieces/robotique/icones.py --manifeste ; la lecture par le moteur : règle « images » du harness.
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local Ro = require("shared.content.robots")
local Pa = require("shared.content.robot_parts")
local Cr = require("shared.content.crafts")
local Sn = require("shared.content.tin")
local Su = require("shared.content.superconductors")

local MOD = "__factorio-overhaul__/"
local OBJ_SIZE, TECH_SIZE, MIPS = 64, 256, 4
local RACINE = "graphics/robotique/"

-- Objets dessinés hors des familles complètes (robots, pièces), par liste de données.
local DESSINES = {
  { "crafts", Cr.ITEMS, { "fo-crystal-oscillator", "fo-metallurgical-silicon", "fo-pure-silicon", "fo-silicon-wafer", "fo-enameled-wire", "fo-coil" } },
  { "tin", Sn.ITEMS, { "fo-printed-circuit-board" } },
  { "superconductors", Su.ITEMS, { "fo-superconducting-tape" } },
}

local function lire(chemin)
  local f = io.open(chemin, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

--- Largeur et hauteur d'un PNG (en-tête IHDR) ; nil si ce n'en est pas un.
local function taille_png(octets)
  if not octets or #octets < 24 or octets:sub(2, 4) ~= "PNG" or octets:sub(13, 16) ~= "IHDR" then return nil end
  local function u32(i)
    local a, b, c, d = octets:byte(i, i + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return u32(17), u32(21)
end

local function largeur_bande(size, mips)
  local w, t = 0, size
  for _ = 1, mips do w = w + t; t = math.floor(t / 2) end
  return w
end

local function trie(t)
  local l = {}
  for k in pairs(t) do l[#l + 1] = k end
  table.sort(l)
  return l
end

--- Noms attendus (objets, technologies), et les écarts des listes DESSINES contre leurs données.
local function attendus(dessines)
  local objets, techs, absents = {}, {}, {}
  for _, n in ipairs(Pa.ITEMS) do objets[n] = true end
  for _, t in ipairs(Pa.TECHS) do techs[t.name] = true end
  -- lot s43-robots : une variante (r.variant) prend l'icône de son parent, teinte (aucun rendu neuf) : ni son kit ni sa technologie
  local variante = {}
  for _, r in ipairs(Ro.ROBOTS) do
    if r.variant then variante[r.id] = true else objets[r.kit] = true end
    if r.segment_item then objets[r.segment_item] = true end
  end
  for _, t in ipairs(Ro.TECHS) do
    if not (t.robots and #t.robots == 1 and variante[t.robots[1]] and not t.factories) then techs[t.name] = true end
  end
  for _, d in ipairs(dessines) do
    local present = {}
    for _, n in ipairs(d[2]) do present[n] = true end
    for _, n in ipairs(d[3]) do
      if present[n] then objets[n] = true else absents[#absents + 1] = d[1] .. "/" .. n end
    end
  end
  return objets, techs, absents
end

--- Contrôles de la table `ico` ; `lecteur(chemin)` rend les octets d'un fichier, `ls(dossier)` ses PNG. Rend le nombre d'écarts.
local function verifier(ico, objets, techs, lecteur, ls, quiet)
  local ecarts = 0
  local function ko(msg)
    ecarts = ecarts + 1
    if not quiet then check(false, msg) end
  end
  local function ok() if not quiet then check(true, "") end end
  for _, n in ipairs(trie(objets)) do if ico.item[n] then ok() else ko("objet sans icône dédiée : " .. n) end end
  for _, n in ipairs(trie(techs)) do if ico.tech[n] then ok() else ko("technologie sans icône dédiée : " .. n) end end
  for _, n in ipairs(trie(ico.item)) do if not objets[n] then ko("icône d'objet sans objet de la robotique : " .. n) end end
  for _, n in ipairs(trie(ico.tech)) do if not techs[n] then ko("icône de technologie sans technologie de la robotique : " .. n) end end
  for _, genre in ipairs({ { "item", "icones", OBJ_SIZE }, { "tech", "tech", TECH_SIZE } }) do
    local dossier = RACINE .. genre[2] .. "/"
    local vus = {}
    for _, n in ipairs(trie(ico[genre[1]])) do
      local i = ico[genre[1]][n]
      local attendu = MOD .. dossier .. n .. ".png"
      if i.icon ~= attendu then ko(n .. " : chemin " .. tostring(i.icon) .. " au lieu de " .. attendu) else ok() end
      if i.icon_size ~= genre[3] or i.icon_mipmaps ~= MIPS then
        ko(n .. " : taille " .. tostring(i.icon_size) .. " / " .. tostring(i.icon_mipmaps) .. " mipmaps au lieu de " .. genre[3] .. " / " .. MIPS)
      else ok() end
      vus[n .. ".png"] = true
      local w, h = taille_png(lecteur(dossier .. n .. ".png"))
      if not w then
        ko(n .. " : fichier absent ou pas un PNG")
      elseif w ~= largeur_bande(genre[3], MIPS) or h ~= genre[3] then
        ko(n .. " : image de " .. w .. " x " .. h .. " au lieu de " .. largeur_bande(genre[3], MIPS) .. " x " .. genre[3])
      else ok() end
    end
    for _, f in ipairs(ls(dossier)) do
      if not vus[f] then ko("fichier orphelin " .. dossier .. f) else ok() end
    end
  end
  return ecarts
end

local function ls_reel(dossier)
  local out = {}
  for _, cmd in ipairs({ 'dir /b "' .. dossier:gsub("/", "\\") .. '" 2>nul', 'ls "' .. dossier .. '" 2>/dev/null' }) do
    local p = io.popen(cmd)
    if p then
      for l in p:lines() do
        l = l:gsub("%s+$", "")
        if l:match("%.png$") then out[#out + 1] = l end
      end
      p:close()
    end
    if #out > 0 then break end
  end
  table.sort(out)
  return out
end

-- Entrées réelles ---------------------------------------------------------------------------------------------------
local ICO = dofile(RACINE .. "icones/icones.lua")
local OBJETS, TECHS, ABSENTS = attendus(DESSINES)

section("1 et 2. Couverture, fichiers et tailles")
check(#ABSENTS == 0, "objets dessinés absents de leurs données : " .. table.concat(ABSENTS, ", "))
check(#trie(OBJETS) == 30, "30 objets attendus (7 pièces, 2 circuits, 6 matières, 12 kits, 3 segments), trouvé " .. #trie(OBJETS))
check(#trie(TECHS) == 15, "15 technologies attendues (3 de pièces, 12 de robots), trouvé " .. #trie(TECHS))
check(verifier(ICO, OBJETS, TECHS, lire, ls_reel, false) == 0, "aucun écart sur les données réelles")

section("3. Branchement des prototypes")
local function compte(chemin, motif)
  local s = lire(chemin) or ""
  local n = 0
  for _ in s:gmatch(motif) do n = n + 1 end
  return n
end
local REQ = 'require%("prototypes%.robotique_icones"%)'
-- prototypes/robots.lua appartient au lot ROBOTSJEU : ses 3 lignes (kits, segments, technologies des robots) sont posées par
-- l'intégrateur à la fusion, après ROBOTSJEU (fo-logs/2026-11-04_DA-ICONES/robots_lua_a_poser.patch). Passer ROBOTS_BRANCHE à
-- true à ce moment-là : le contrôle devient alors strict, comme pour les 4 autres fichiers.
local ROBOTS_BRANCHE = true
local BRANCHES = {
  -- fichier, appels icones_objet, appels icones_tech, garde de `pictures`
  { "prototypes/robot_parts.lua", 1, 1, false },
  { "prototypes/tin.lua", 1, 0, true },
  { "prototypes/crafts.lua", 1, 0, true },
  { "prototypes/superconductors.lua", 1, 0, true },
}
if ROBOTS_BRANCHE then
  BRANCHES[#BRANCHES + 1] = { "prototypes/robots.lua", 2, 1, false }
else
  print("  NOTE : prototypes/robots.lua non branché sur cette branche (kits, segments et technologies des robots gardent la copie teintée en jeu) : à poser à la fusion")
end
--- Icône des kits : la caisse de famille (Vis.icones_objet(r.kit)) EN PREMIER, l'icône du robot (SPR) seulement en repli.
local function kits_caisse_d_abord(s)
  local a = s:find("icons = Vis.icones_objet(r.kit) or", 1, true)
  local b = s:find("SPR[r.id].icone", 1, true)
  local _, n = s:gsub("icons = Vis%.icones_objet%(r%.kit%) or", "")
  return a ~= nil and n == 1 and (b == nil or a < b)
end

local function branchement(lecteur)
  local e = 0
  for _, b in ipairs(BRANCHES) do
    local s = lecteur(b[1]) or ""
    local function n(m) local k = 0 for _ in s:gmatch(m) do k = k + 1 end return k end
    if n(REQ) ~= 1 then e = e + 1 end
    if n("Vis%.icones_objet%(") ~= b[2] then e = e + 1 end
    if n("Vis%.icones_tech%(") ~= b[3] then e = e + 1 end
    if b[4] and n("if src%.pictures and not vis then") ~= 1 then e = e + 1 end
    if b[1] == "prototypes/robots.lua" and not kits_caisse_d_abord(s) then e = e + 1 end
  end
  return e
end
for _, b in ipairs(BRANCHES) do
  check(compte(b[1], REQ) == 1, b[1] .. " charge robotique_icones")
  check(compte(b[1], "Vis%.icones_objet%(") == b[2], b[1] .. " : " .. b[2] .. " appel(s) à icones_objet")
  check(compte(b[1], "Vis%.icones_tech%(") == b[3], b[1] .. " : " .. b[3] .. " appel(s) à icones_tech")
  if b[4] then check(compte(b[1], "if src%.pictures and not vis then") == 1, b[1] .. " : la feuille au sol teintée n'est gardée que sans icône dédiée") end
end
check(branchement(lire) == 0, "branchement complet")

section("4. Mutants")
local function copie(t)
  local c = { item = {}, tech = {} }
  for k, v in pairs(t.item) do c.item[k] = { icon = v.icon, icon_size = v.icon_size, icon_mipmaps = v.icon_mipmaps } end
  for k, v in pairs(t.tech) do c.tech[k] = { icon = v.icon, icon_size = v.icon_size, icon_mipmaps = v.icon_mipmaps } end
  return c
end
local function ens(t) local c = {} for _, k in ipairs(trie(t)) do c[k] = true end return c end
local mutants = {
  { "icône d'un kit retirée", function(c, o, t) c.item["fo-robot-kit-needle"] = nil end },
  { "icône d'un segment retirée", function(c, o, t) c.item["fo-robot-segment-crowned"] = nil end },
  { "icône d'une technologie de robot retirée", function(c, o, t) c.tech["fo-robot-gantry"] = nil end },
  { "nom en trop", function(c, o, t) c.item["fo-inconnu"] = { icon = MOD .. RACINE .. "icones/fo-inconnu.png", icon_size = 64, icon_mipmaps = 4 } end },
  { "mauvais chemin", function(c, o, t) c.item["fo-controller"].icon = MOD .. RACINE .. "icones/fo-guidance-core.png" end },
  { "mauvais nombre de mipmaps", function(c, o, t) c.item["fo-coil"].icon_mipmaps = 3 end },
  { "mauvaise taille de technologie", function(c, o, t) c.tech["fo-magnetic-drive"].icon_size = 64 end },
  { "nouveau robot sans icône", function(c, o, t) o["fo-robot-kit-nouveau"] = true end },
}
for _, m in ipairs(mutants) do
  local c, o, t = copie(ICO), ens(OBJETS), ens(TECHS)
  m[2](c, o, t)
  check(verifier(c, o, t, lire, ls_reel, true) > 0, "mutant non détecté : " .. m[1])
end
local function lecteur_sans(nom) return function(ch) if ch:find(nom, 1, true) then return nil end return lire(ch) end end
local function lecteur_petit(nom)
  return function(ch) if ch:find(nom, 1, true) then return "\137PNG\r\n\26\n\0\0\0\13IHDR\0\0\0\64\0\0\0\64" end return lire(ch) end
end
check(verifier(ICO, OBJETS, TECHS, lecteur_sans("fo-robot-kit-levite"), ls_reel, true) > 0, "mutant non détecté : fichier absent")
check(verifier(ICO, OBJETS, TECHS, lecteur_petit("fo-robot-bay"), ls_reel, true) > 0, "mutant non détecté : bande sans mipmaps")
check(verifier(ICO, OBJETS, TECHS, lire, function(d) local l = ls_reel(d); l[#l + 1] = "orphelin.png"; return l end, true) > 0,
  "mutant non détecté : fichier orphelin")
local _, _, abs = attendus({ { "crafts", Cr.ITEMS, { "fo-silicium-fantome" } } })
check(#abs == 1, "mutant non détecté : objet dessiné absent de ses données")
check(branchement(function(ch)
  local s = lire(ch)
  if ch == "prototypes/crafts.lua" and s then s = s:gsub("if src%.pictures and not vis then", "if src.pictures then") end
  return s
end) > 0, "mutant non détecté : feuille au sol teintée gardée malgré l'icône dédiée")

section("5. Kits : la caisse de famille d'abord (choix du DC)")
if ROBOTS_BRANCHE then
  check(kits_caisse_d_abord(lire("prototypes/robots.lua") or ""), "prototypes/robots.lua : l'icône de kit DA-ICONES passe avant celle du robot")
  -- mutant : l'ancien ordre (l'icône du robot d'abord, la caisse en repli) doit être refusé
  local ancien = [[icons = SPR[r.id] and { { icon = SPR[r.id].icone, icon_size = 64, icon_mipmaps = 4 } }
      or Vis.icones_objet(r.kit) or icons_of("item", r.is_giant and "spidertron" or "engine-unit", ROBOT_TINT[r.id]),]]
  check(not kits_caisse_d_abord(ancien), "mutant non détecté : icône du robot avant la caisse")
end

print(string.format("[ROBOTIQUE-ICONES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
