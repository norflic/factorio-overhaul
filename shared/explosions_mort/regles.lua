--[[
  Lot X10, Q5 (7/11 ; le DC, par QCM, 17 h 40 : « Allégés loin de vous seulement (Recommandé) ») : EXPLOSIONS DE MORT des
  unités recréées par script près d'un joueur seulement. Lua PUR, lu aux deux étapes (prototypes/explosions_mort.lua au
  data-final-fixes, script/world/explosions_mort.lua au jeu). Critères validés par le lead le 7/11 (C1 à C7,
  fo-logs\2026-11-07_X10\MOTEUR.md §14).

  L'explosion de mort d'une unité (sang des biters et des soldats, explosion des robots) est un effet du PROTOTYPE : le
  moteur la crée partout, même à 600 tuiles de tout joueur, avec ses particules. Au data-final-fixes, `dying_explosion` est
  retiré des prototypes de type M.TYPES et remplacé par un effet `script` ajouté à `dying_trigger_effect`, dont
  l'identifiant PORTE les noms des explosions (« fo-mort|blood-explosion-big ») : LuaEntityPrototype n'a pas
  `dying_explosion` au jeu (runtime-api.json 1.1.91). Au jeu, l'explosion n'est recréée, au même point, que si un joueur
  connecté est à moins de RAYON tuiles (distance de Tchebychev). Le cadavre (`corpse`) reste partout : seule l'explosion
  change. Les effets déjà présents dans `dying_trigger_effect` (feu de l'Ignée : c'est du JEU) restent, devant.

  PÉRIMÈTRE (lead, 7/11 : « unités et vers seulement, nos tourelles exclues ») : toutes les `unit` ; parmi les `turret`,
  les VERS seulement, reconnus à leurs drapeaux (« placeable-enemy » sans « player-creation »). Le type `turret` porte aussi
  nos tourelles expérimentales (`prototypes/experimentaux.lua`, « crachat » : « placeable-player », « player-creation »),
  dont la mort a été dessinée avec le DC (lot A4, F157) : elles ne sont pas touchées.

  RAYON = 224 : le DC joue en 3 840 × 2 160 ; au zoom 0,3, la demi-largeur vue fait 3 840 ÷ (32 × 0,3) ÷ 2 = 200 tuiles.
  Relevé des joueurs toutes les RELEVE ticks (état du jeu, gardé dans global : déterministe en multijoueur).
  Sans relevé (nil) ou sans joueur connecté (liste vide) : PROCHE, l'explosion est créée comme en vanilla (même sens que
  R.proche de shared/tirs/regles.lua ; les bancs sans joueur ne changent pas).

    M.noms_explosion(de)   noms d'un `dying_explosion` de prototype, ou nil si sa forme n'est pas sûre (décalage…)
    M.effect_id(noms)      « fo-mort|a|b »
    M.noms(effect_id)      noms portés par un identifiant de ce lot, ou nil
    M.avec_effet(dte, noms) `dying_trigger_effect` complété par l'effet script
    M.cible(t, p)          le prototype p de type t est-il du lot ? (unités ; vers, pas nos tourelles)
    M.habiller(p)          transforme un prototype (data) ; rend ses noms, ou nil s'il est laissé au moteur
    M.hors_grille(x)       donne « placeable-off-grid » au prototype d'explosion x (rend true s'il l'ajoute)
    M.proche(joueurs, s, x, y, r)  un joueur relevé est-il à moins de r tuiles du point, sur la surface s ?
]]

local M = {}

M.PREFIXE = "fo-mort|"
M.RAYON = 224
M.RELEVE = 60
M.TYPES = { "turret", "unit" } -- trié ; « turret » filtré par M.cible (vers seulement)

local function a_drapeau(p, f)
  local fl = p.flags
  if type(fl) ~= "table" then return false end
  for i = 1, #fl do if fl[i] == f then return true end end
  return false
end

--- Le prototype p (type t) est-il du lot ? Toute `unit` ; une `turret` seulement si c'est un ver : « placeable-enemy » et
--- pas « player-creation » (nos tourelles expérimentales sont « player-creation »).
function M.cible(t, p)
  if t == "unit" then return true end
  if t == "turret" then return a_drapeau(p, "placeable-enemy") and not a_drapeau(p, "player-creation") end
  return false
end

--- Noms d'explosion d'un `dying_explosion` de prototype : chaîne, liste de chaînes, { name = … } ou liste de { name = … }
--- SANS autre champ. Rend nil si la forme n'est pas sûre (décalage, champ inconnu, nom vide ou portant « | ») : le
--- prototype est alors laissé tel quel.
function M.noms_explosion(de)
  if type(de) == "string" then de = { de } end
  if type(de) ~= "table" then return nil end
  if de.name ~= nil then de = { de } end
  local out = {}
  for i = 1, #de do
    local x = de[i]
    if type(x) == "table" then
      for k in pairs(x) do if k ~= "name" then return nil end end -- offset ou autre : forme laissée au moteur
      x = x.name
    end
    if type(x) ~= "string" or x == "" or x:find("|", 1, true) then return nil end
    out[#out + 1] = x
  end
  return #out > 0 and out or nil
end

function M.effect_id(noms)
  return M.PREFIXE .. table.concat(noms, "|")
end

--- Noms d'explosion portés par un effect_id ; nil si ce n'est pas un effet de ce lot.
function M.noms(effect_id)
  if type(effect_id) ~= "string" or effect_id:sub(1, #M.PREFIXE) ~= M.PREFIXE then return nil end
  local out = {}
  for n in effect_id:sub(#M.PREFIXE + 1):gmatch("[^|]+") do out[#out + 1] = n end
  return #out > 0 and out or nil
end

--- `dying_trigger_effect` complété par l'effet script ; l'existant est gardé, devant (feu de l'Ignée, etc.).
function M.avec_effet(dte, noms)
  local eff = { type = "script", effect_id = M.effect_id(noms) }
  if dte == nil then return { eff } end
  if dte.type ~= nil then return { dte, eff } end
  local out = {}
  for i = 1, #dte do out[i] = dte[i] end
  out[#out + 1] = eff
  return out
end

--- Habille un prototype (étape data) : rend ses noms d'explosion, ou nil s'il n'a pas d'explosion sûre (inchangé).
function M.habiller(p)
  local noms = M.noms_explosion(p.dying_explosion)
  if not noms then return nil end
  p.dying_trigger_effect = M.avec_effet(p.dying_trigger_effect, noms)
  p.dying_explosion = nil
  return noms
end

--- Moteur réel, 7/11 (identité C8) : create_entity par script RECALE sur la grille une explosion sans le drapeau
--- « placeable-off-grid » (écart mesuré (0,285, 0,035) puis (−0,215, −0,465) : point entier), alors que le moteur crée son
--- `dying_explosion` au point exact, et ses déclencheurs aussi hors de la grille (« explosion-hit », sans ce drapeau, vu
--- à (0,086, 0,984) du ver). Le drapeau ne change donc que la pose par script. Rend true s'il est ajouté.
function M.hors_grille(x)
  local fl = x.flags
  if type(fl) ~= "table" then fl = {}; x.flags = fl end
  for i = 1, #fl do if fl[i] == "placeable-off-grid" then return false end end
  fl[#fl + 1] = "placeable-off-grid"
  return true
end

--- Un joueur relevé est-il à moins de r tuiles (Tchebychev, bornes comprises) du point, sur la surface s ?
--- joueurs = { { s = index de surface, x = …, y = … }, … } ; nil (pas encore de relevé) ou vide : proche.
function M.proche(joueurs, s, x, y, r)
  if joueurs == nil or #joueurs == 0 then return true end
  for i = 1, #joueurs do
    local j = joueurs[i]
    if j.s == s and j.x - r <= x and x <= j.x + r and j.y - r <= y and y <= j.y + r then return true end
  end
  return false
end

return M
