--[[
  Banc hors jeu du lot ICONES-DISTINCTES (11/11, mandat du DC du 10/11, 22 h 20, chantier A §3) : cinq métaux qui montraient
  tous la plaque d'acier vanilla teintée (« une silhouette confuse de poutre d'acier ») ont leur icône dédiée.
  Usage, depuis la racine du mod :   lua5.2 tests/metaux_icones_test.lua

  1. COUVERTURE : la tôle magnétique et les trois billettes (shared/content/crafts.lua) et la plaque de titane
     (shared/content/titanium.lua) sont dans graphics/metaux/icones/icones.lua, sans nom en trop.
  2. FICHIERS : chaque PNG existe, a la taille d'une bande vanilla (64 px, 4 mipmaps : 120 x 64), et les cinq sont DIFFÉRENTS
     (deux octets égaux = deux silhouettes confondues), sans fichier orphelin.
  3. BRANCHEMENT : crafts.lua et titanium.lua lisent prototypes/metaux_icones.lua, l'icône dédiée passe avant la copie teintée,
     et elle n'emporte plus la feuille vanilla teintée au sol (`pictures`).
  4. MUTANTS : chaque altération doit faire échouer au moins un contrôle.
  Les sommes sha256 : tools/render/pieces/metaux/icones.py --manifeste ; la lecture par le moteur : règle « images » du harness.
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local Cr = require("shared.content.crafts")
local Ti = require("shared.content.titanium")

local MOD = "__factorio-overhaul__/"
local RACINE = "graphics/metaux/icones/"
local ATTENDUS = {
  { "crafts", Cr.ITEMS, { "fo-magnetic-steel", "fo-iron-plate-r8", "fo-copper-plate-r8", "fo-tungsten-plate-r8" } },
  { "titanium", Ti.ITEMS, { "fo-titanium-plate" } },
}

local function lire(chemin)
  local f = io.open(chemin, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function taille_png(octets)
  if not octets or #octets < 24 or octets:sub(2, 4) ~= "PNG" or octets:sub(13, 16) ~= "IHDR" then return nil end
  local function u32(i)
    local a, b, c, d = octets:byte(i, i + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return u32(17), u32(21)
end

local function trie(t)
  local k = {}
  for n in pairs(t) do k[#k + 1] = n end
  table.sort(k)
  return k
end

--- PNG du dossier des icônes (cmd sous Windows, ls ailleurs ; même lecture que tests/robotique_icones_test.lua).
local function ls_reel()
  local out = {}
  for _, cmd in ipairs({ 'dir /b "' .. RACINE:gsub("/", "\\") .. '" 2>nul', 'ls "' .. RACINE .. '" 2>/dev/null' }) do
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

--- Noms attendus ; rend (ensemble, absents de leurs données).
local function attendus(liste)
  local ens, abs = {}, {}
  for _, a in ipairs(liste) do
    local dans = {}
    for _, n in ipairs(a[2]) do dans[n] = true end
    for _, n in ipairs(a[3]) do
      ens[n] = true
      if not dans[n] then abs[#abs + 1] = a[1] .. ":" .. n end
    end
  end
  return ens, abs
end

--- Nombre d'écarts entre la table d'icônes et les attendus, les fichiers et le dossier.
local function verifier(ico, ens, lecteur, ls, muet)
  local e = 0
  local function ecart(m) e = e + 1; if not muet then print("  ÉCART : " .. m) end end
  local vus = {}
  for _, n in ipairs(trie(ens)) do
    local i = ico.item[n]
    if not i then ecart("icône absente " .. n)
    else
      if i.icon ~= MOD .. RACINE .. n .. ".png" then ecart("chemin " .. n) end
      if i.icon_size ~= 64 or i.icon_mipmaps ~= 4 then ecart("format " .. n) end
      local b = lecteur(RACINE .. n .. ".png")
      local w, h = taille_png(b)
      if w ~= 120 or h ~= 64 then ecart("bande " .. n .. " " .. tostring(w) .. "x" .. tostring(h)) end
      if b then
        if vus[b] then ecart("icônes identiques " .. vus[b] .. " et " .. n) end
        vus[b] = n
      end
    end
  end
  for _, n in ipairs(trie(ico.item)) do if not ens[n] then ecart("nom en trop " .. n) end end
  for _, f in ipairs(ls()) do
    if f:match("%.png$") and not ens[f:sub(1, -5)] then ecart("fichier orphelin " .. f) end
  end
  return e
end

local ICO = dofile(RACINE .. "icones.lua")
local ENS, ABS = attendus(ATTENDUS)

section("1. Couverture")
check(#ABS == 0, "chaque objet dessiné existe dans ses données (" .. table.concat(ABS, ", ") .. ")")
check(#trie(ENS) == 5, "cinq objets dessinés")
section("2. Fichiers")
check(#ls_reel() == 5, "le dossier des icônes se lit et compte cinq PNG")
check(verifier(ICO, ENS, lire, ls_reel) == 0, "table, bandes et dossier conformes, cinq icônes différentes")

section("3. Branchement des prototypes")
local REQ = 'require%("prototypes%.metaux_icones"%)'
local BRANCHES = {
  { "prototypes/crafts.lua", "Vis%.icones_objet%(name%) or Mx%.icones_objet%(name%)" },
  { "prototypes/titanium.lua", "icons = vis or icon_of%(" },
}
local function branchement(lecteur)
  local e = 0
  for _, b in ipairs(BRANCHES) do
    local s = lecteur(b[1]) or ""
    local function n(m) local k = 0 for _ in s:gmatch(m) do k = k + 1 end return k end
    if n(REQ) ~= 1 then e = e + 1 end
    if n(b[2]) ~= 1 then e = e + 1 end
    if n("if src%.pictures and not vis then") ~= 1 then e = e + 1 end
  end
  local t = lecteur("prototypes/titanium.lua") or ""
  if not t:find("local vis = Mx.icones_objet(name)", 1, true) then e = e + 1 end
  return e
end
check(branchement(lire) == 0, "crafts.lua et titanium.lua lisent les icônes des métaux avant la copie teintée, sans feuille au sol teintée")

section("4. Mutants")
local function copie(t)
  local c = { item = {} }
  for k, v in pairs(t.item) do c.item[k] = { icon = v.icon, icon_size = v.icon_size, icon_mipmaps = v.icon_mipmaps } end
  return c
end
local mutants = {
  { "icône de la tôle retirée", function(c) c.item["fo-magnetic-steel"] = nil end },
  { "nom en trop", function(c) c.item["fo-inconnu"] = { icon = MOD .. RACINE .. "fo-inconnu.png", icon_size = 64, icon_mipmaps = 4 } end },
  { "mauvais chemin (cuivre sur le fichier du fer)", function(c) c.item["fo-copper-plate-r8"].icon = MOD .. RACINE .. "fo-iron-plate-r8.png" end },
  { "mauvais nombre de mipmaps", function(c) c.item["fo-titanium-plate"].icon_mipmaps = 3 end },
}
for _, m in ipairs(mutants) do
  local c = copie(ICO)
  m[2](c)
  check(verifier(c, ENS, lire, ls_reel, true) > 0, "mutant non détecté : " .. m[1])
end
local function lecteur_sans(nom) return function(ch) if ch:find(nom, 1, true) then return nil end return lire(ch) end end
local function lecteur_copie(de, vers)
  return function(ch) if ch:find(vers, 1, true) then return lire(RACINE .. de .. ".png") end return lire(ch) end
end
check(verifier(ICO, ENS, lecteur_sans("fo-tungsten-plate-r8"), ls_reel, true) > 0, "mutant non détecté : fichier absent")
check(verifier(ICO, ENS, lecteur_copie("fo-iron-plate-r8", "fo-tungsten-plate-r8"), ls_reel, true) > 0,
  "mutant non détecté : deux métaux avec la même icône")
check(verifier(ICO, ENS, lire, function() local l = ls_reel(); l[#l + 1] = "orphelin.png"; return l end, true) > 0,
  "mutant non détecté : fichier orphelin")
local _, abs = attendus({ { "crafts", Cr.ITEMS, { "fo-billette-fantome" } } })
check(#abs == 1, "mutant non détecté : objet dessiné absent de ses données")
check(branchement(function(ch)
  local s = lire(ch)
  if ch == "prototypes/titanium.lua" and s then s = s:gsub("if src%.pictures and not vis then", "if src.pictures then") end
  return s
end) > 0, "mutant non détecté : feuille au sol teintée gardée malgré l'icône dédiée")
check(branchement(function(ch)
  local s = lire(ch)
  if ch == "prototypes/crafts.lua" and s then s = s:gsub(" or Mx%.icones_objet%(name%)", "") end
  return s
end) > 0, "mutant non détecté : crafts.lua ne lit plus les icônes des métaux")

print(string.format("[METAUX-ICONES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
