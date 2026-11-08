--[[
  Lot X10, Q5 (7/11 ; le DC : « Allégés loin de vous seulement ») : explosions de mort des UNITÉS recréées près d'un joueur
  seulement. Le prototype (prototypes/explosions_mort.lua) n'a plus de `dying_explosion` ; sa mort lève
  on_script_trigger_effect avec l'identifiant « fo-mort|<noms> » (shared/explosions_mort/regles.lua). Ici :
    1. relevé des joueurs connectés toutes les M.RELEVE ticks (global : identique sur toutes les machines) ;
    2. à chaque mort, si un joueur relevé est à moins de M.RAYON tuiles (Tchebychev) : create_entity de chaque explosion
       au point de la mort ; sinon rien (compteur `loin`).
  Réglage de banc (interface « fo-explosions-mort ») : `actif(false)` recrée l'explosion partout, comme le moteur (témoin A/B).
  Les autres effets `script` (tirs des chargeurs, robots expérimentaux) passent en une lecture de table.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local M = require("shared.explosions_mort.regles")

-- [effect_id] = noms, ou false si l'effet n'est pas de ce lot. Fonction pure de la chaîne : le cache ne change aucune
-- décision (rien du jeu n'y entre), il évite une coupe de chaîne par effet des autres lots (salves des chargeurs).
local NOMS = {}

Storage.declare("explosions_mort", function()
  return { actif = true, joueurs = nil, crees = 0, ratees = 0, loin = 0, sans_point = 0 }
end)

local function S() return Storage.ns("explosions_mort") end

--- Relevé des joueurs connectés (état du jeu), dans l'ordre de la liste du moteur.
local function releve()
  local s = S()
  if not s then return end
  local j = {}
  for _, p in ipairs(game.connected_players) do
    local pos = p.position
    j[#j + 1] = { s = p.surface.index, x = pos.x, y = pos.y }
  end
  s.joueurs = j
end

local function sur_effet(e)
  local id = e.effect_id
  if id == nil then return end
  local noms = NOMS[id]
  if noms == nil then
    noms = M.noms(id) or false
    NOMS[id] = noms
  end
  if not noms then return end
  local s = S()
  if not s then return end
  local pos = e.target_position or e.source_position
  if not pos then
    local ent = e.source_entity or e.target_entity
    pos = ent and ent.valid and ent.position
  end
  if not pos then
    s.sans_point = s.sans_point + 1
    return
  end
  if s.actif and not M.proche(s.joueurs, e.surface_index, pos.x, pos.y, M.RAYON) then
    s.loin = s.loin + 1
    return
  end
  local surface = game.get_surface(e.surface_index)
  if not surface then return end
  for i = 1, #noms do
    if surface.create_entity({ name = noms[i], position = pos }) then s.crees = s.crees + 1 else s.ratees = s.ratees + 1 end
  end
end

Events.on(defines.events.on_script_trigger_effect, sur_effet)
Events.on_nth_tick(M.RELEVE, releve)

remote.add_interface("fo-explosions-mort", {
  --- Compteurs : explosions créées et ratées, morts loin de tout joueur, morts sans point ; relevé (nombre de joueurs, -1
  --- avant le premier) ; réglage actif. Avant la création de l'espace « explosions_mort » (sauvegarde d'avant ce lot, jusqu'à son
  --- on_configuration_changed ; moteur réel, 7/11 : le on_init d'un mod ajouté passe AVANT) : tout à 0, actif nil.
  stats = function()
    local s = S()
    if not s then return { actif = nil, crees = 0, ratees = 0, loin = 0, sans_point = 0, joueurs = -1 } end
    return { actif = s.actif, crees = s.crees, ratees = s.ratees, loin = s.loin, sans_point = s.sans_point,
      joueurs = s.joueurs and #s.joueurs or -1 }
  end,
  --- true : règle de distance (défaut) ; false : explosion partout, comme le moteur (témoin de banc).
  actif = function(v)
    local s = S()
    if s then s.actif = v and true or false end
  end,
  --- Relevé des joueurs tout de suite (bancs : après un téléport).
  releve = function() releve() end,
})
