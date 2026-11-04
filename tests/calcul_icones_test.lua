--[[
  Banc hors jeu du lot ICONES-CALCUL (03/11) : les icônes dédiées de la chaîne du calcul.
  Usage, depuis la racine du mod :   lua5.2 tests/calcul_icones_test.lua

  Le DC (3/11) : « tous les circuits type puce logique, puce mémoire de RAM, DRAM, SRAM, carte mère, carte graphique [...] n'ont
  pas de design particulier, c'est juste des teintes différentes des circuits électriques de base ». Ce banc garantit que plus
  aucun objet, fluide, baie ni technologie de la chaîne du calcul ne retombe sur une copie vanilla teintée :
  1. COUVERTURE : tout nom de shared/content/compute.lua et compute_chain.lua (objets, fluides, baies, technologies) a son
     icône dans graphics/calcul/icones/icones.lua, et la table ne contient aucun nom en trop.
  2. FICHIERS : chaque PNG existe, sa taille est celle d'une bande vanilla (objets : 64 px, 4 mipmaps, 120 x 64 ;
     technologies : 256 px, 4 mipmaps, 480 x 256), sans fichier orphelin dans les deux dossiers.
  3. BRANCHEMENT : prototypes/compute.lua et compute_v2.lua lisent prototypes/calcul_icones.lua pour chaque famille.
  4. MUTANTS : 10 altérations des entrées, chacune doit faire échouer au moins un contrôle.
  La somme sha256 de chaque PNG est tenue par tools/render/pieces/calcul/icones.py --manifeste ; la lecture des fichiers par le
  moteur, par la règle « images » de tests/datastage/harness.lua (fichier manquant ou rectangle hors image).
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local Cp = require("shared.content.compute")
local Cv = require("shared.content.compute_chain")

local MOD = "__factorio-overhaul__/"
local OBJ_SIZE, TECH_SIZE, MIPS = 64, 256, 4

local function lire(chemin)
  local f = io.open(chemin, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

--- Largeur et hauteur d'un PNG, lues dans son en-tête IHDR ; nil si ce n'en est pas un.
local function taille_png(octets)
  if not octets or #octets < 24 or octets:sub(2, 4) ~= "PNG" or octets:sub(13, 16) ~= "IHDR" then return nil end
  local function u32(i)
    local a, b, c, d = octets:byte(i, i + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return u32(17), u32(21)
end

--- Largeur d'une bande vanilla : la taille, puis la moitié, le quart, etc.
local function largeur_bande(size, mips)
  local w, t = 0, size
  for _ = 1, mips do w = w + t; t = math.floor(t / 2) end
  return w
end

local function ensemble(listes)
  local s = {}
  for _, l in ipairs(listes) do for _, e in ipairs(l) do s[e.name] = true end end
  return s
end

local function noms_techs()
  local s = {}
  for _, t in ipairs(Cp.TECHS) do s[t.name] = true end
  for _, t in ipairs(Cv.TECHS) do if t.new then s[t.name] = true end end
  return s
end

--- Contrôles de la table `ico` contre les noms attendus ; `lecteur(chemin)` rend les octets d'un fichier ; `ls(dossier)` la liste de ses PNG.
--- Rend le nombre d'écarts trouvés (les mutants s'en servent).
local function verifier(ico, objets, techs, lecteur, ls, quiet)
  local ecarts = 0
  local function ko(msg)
    ecarts = ecarts + 1
    if not quiet then check(false, msg) end
  end
  local function ok()
    if not quiet then check(true, "") end
  end
  for _, n in ipairs((function() local l = {} for k in pairs(objets) do l[#l + 1] = k end table.sort(l) return l end)()) do
    if ico.item[n] then ok() else ko("objet, fluide ou baie sans icône dédiée : " .. n) end
  end
  for _, n in ipairs((function() local l = {} for k in pairs(techs) do l[#l + 1] = k end table.sort(l) return l end)()) do
    if ico.tech[n] then ok() else ko("technologie sans icône dédiée : " .. n) end
  end
  for n in pairs(ico.item) do if not objets[n] then ko("icône d'objet sans objet du calcul : " .. n) end end
  for n in pairs(ico.tech) do if not techs[n] then ko("icône de technologie sans technologie du calcul : " .. n) end end

  local attendus = { ["graphics/calcul/icones/"] = {}, ["graphics/calcul/tech/"] = {} }
  for _, genre in ipairs({ { "item", "icones", OBJ_SIZE }, { "tech", "tech", TECH_SIZE } }) do
    local dossier = "graphics/calcul/" .. genre[2] .. "/"
    local noms = {}
    for n in pairs(ico[genre[1]]) do noms[#noms + 1] = n end
    table.sort(noms)
    for _, n in ipairs(noms) do
      local i = ico[genre[1]][n]
      local attendu = MOD .. dossier .. n .. ".png"
      if i.icon ~= attendu then ko(n .. " : chemin " .. tostring(i.icon) .. " au lieu de " .. attendu) else ok() end
      if i.icon_size ~= genre[3] or i.icon_mipmaps ~= MIPS then
        ko(n .. " : taille " .. tostring(i.icon_size) .. " / " .. tostring(i.icon_mipmaps) .. " mipmaps au lieu de " .. genre[3] .. " / " .. MIPS)
      else ok() end
      attendus[dossier][n .. ".png"] = true
      local w, h = taille_png(lecteur(dossier .. n .. ".png"))
      if not w then
        ko(n .. " : fichier absent ou pas un PNG")
      elseif w ~= largeur_bande(genre[3], MIPS) or h ~= genre[3] then
        ko(n .. " : image de " .. w .. " x " .. h .. " au lieu de " .. largeur_bande(genre[3], MIPS) .. " x " .. genre[3])
      else ok() end
    end
    for _, f in ipairs(ls(dossier)) do
      if not attendus[dossier][f] then ko("fichier orphelin " .. dossier .. f) else ok() end
    end
  end
  return ecarts
end

-- Entrées réelles ---------------------------------------------------------------------------------------------------
local ICO = dofile("graphics/calcul/icones/icones.lua")
local OBJETS = ensemble({ Cp.ITEMS, Cp.FLUIDS, Cv.ITEMS, Cv.FLUIDS, Cv.RACKS })
local TECHS = noms_techs()

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
  return out
end
local function lecteur_reel(chemin) return lire(chemin) end

section("1 et 2. Couverture, fichiers et tailles")
local n_obj, n_tech = 0, 0
for _ in pairs(OBJETS) do n_obj = n_obj + 1 end
for _ in pairs(TECHS) do n_tech = n_tech + 1 end
check(n_obj == 32, "32 objets, fluides et baies attendus dans les données, trouvé " .. n_obj)
check(n_tech == 7, "7 technologies attendues dans les données, trouvé " .. n_tech)
local ecarts = verifier(ICO, OBJETS, TECHS, lecteur_reel, ls_reel, false)
check(ecarts == 0, "aucun écart sur les données réelles")

section("3. Branchement des prototypes")
local function contient(chemin, motif)
  local s = lire(chemin) or ""
  local n = 0
  for _ in s:gmatch(motif) do n = n + 1 end
  return n
end
check(contient("prototypes/compute.lua", 'require%("prototypes%.calcul_icones"%)') == 1, "compute.lua charge calcul_icones")
check(contient("prototypes/compute_v2.lua", 'require%("prototypes%.calcul_icones"%)') == 1, "compute_v2.lua charge calcul_icones")
check(contient("prototypes/compute.lua", "Vis%.icones_objet%(") == 2, "compute.lua : objets et fluides branchés (2 appels)")
check(contient("prototypes/compute.lua", "Vis%.icones_tech%(") == 1, "compute.lua : technologies branchées")
check(contient("prototypes/compute_v2.lua", "Vis%.icones_objet%(") == 3, "compute_v2.lua : objets, fluides et baies branchés (3 appels)")
check(contient("prototypes/compute_v2.lua", "Vis%.icones_tech%(") == 1, "compute_v2.lua : technologies branchées")

section("4. Mutants")
local function copie(t)
  local c = { item = {}, tech = {} }
  for k, v in pairs(t.item) do c.item[k] = { icon = v.icon, icon_size = v.icon_size, icon_mipmaps = v.icon_mipmaps } end
  for k, v in pairs(t.tech) do c.tech[k] = { icon = v.icon, icon_size = v.icon_size, icon_mipmaps = v.icon_mipmaps } end
  return c
end
local function ordre(t)
  local l = {}
  for k in pairs(t) do l[#l + 1] = k end
  table.sort(l)
  return l
end
local mutants = {
  { "une icône d'objet retirée", function(c, o, t) c.item["fo-logic-die"] = nil end },
  { "une icône de technologie retirée", function(c, o, t) c.tech["fo-wafer-fab"] = nil end },
  { "un nom en trop", function(c, o, t) c.item["fo-inconnu"] = { icon = MOD .. "graphics/calcul/icones/fo-inconnu.png", icon_size = 64, icon_mipmaps = 4 } end },
  { "mauvais chemin", function(c, o, t) c.item["fo-dram-die"].icon = MOD .. "graphics/calcul/icones/fo-sram-die.png" end },
  { "mauvais nombre de mipmaps", function(c, o, t) c.item["fo-motherboard"].icon_mipmaps = 3 end },
  { "mauvaise taille de technologie", function(c, o, t) c.tech["fo-chip-foundry"].icon_size = 128 end },
  { "un objet du calcul sans icône dédiée", function(c, o, t) o["fo-nouveau-circuit"] = true end },
}
for _, m in ipairs(mutants) do
  local c = copie(ICO)
  local o, t = {}, {}
  for _, k in ipairs(ordre(OBJETS)) do o[k] = true end
  for _, k in ipairs(ordre(TECHS)) do t[k] = true end
  m[2](c, o, t)
  local e = verifier(c, o, t, lecteur_reel, ls_reel, true)
  check(e > 0, "mutant non détecté : " .. m[1])
end
-- Fichier absent, fichier tronqué et fichier orphelin : même contrôle, lecteurs truqués.
local function lecteur_sans(nom) return function(ch) if ch:find(nom, 1, true) then return nil end return lire(ch) end end
local function lecteur_petit(nom) return function(ch) if ch:find(nom, 1, true) then return "\137PNG\r\n\26\n\0\0\0\13IHDR\0\0\0\10\0\0\0\10" end return lire(ch) end end
check(verifier(ICO, OBJETS, TECHS, lecteur_sans("fo-heat-sink"), ls_reel, true) > 0, "mutant non détecté : fichier absent")
check(verifier(ICO, OBJETS, TECHS, lecteur_petit("fo-photomask"), ls_reel, true) > 0, "mutant non détecté : image trop petite")
check(verifier(ICO, OBJETS, TECHS, lecteur_reel, function(d) local l = ls_reel(d); l[#l + 1] = "orphelin.png"; return l end, true) > 0,
  "mutant non détecté : fichier orphelin")

print(string.format("[ICONES-CALCUL] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
