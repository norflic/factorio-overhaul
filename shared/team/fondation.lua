--[[
  Lot KIT : ce que reçoit une équipe de PNJ à la fondation de son QG. PUR (aucune API Factorio), partagé par le runtime
  (script/team/team.lua, Team.init) et les tests hors jeu.

  Réponse du DC (28/10) : les factions ne reçoivent pas plus de ressources que le joueur principal ; elles récoltent le
  reste. La règle tient donc en UNE fonction pour les deux équipes :
    F.grant(is_player, generous, brain_off)  ->  { chest = { {objet, n}, ... } (triée), smelters = n, hq_turrets = n, unlock0 = bool, worker_kit = { {objet, n}, ... },
                                        start = nombre d'ouvriers de départ (réglage fo-npc-start, lu par l'appelant) }
  - votre équipe : jamais de coffre garni ni de four (le coffre du guide est l'apport manuel du joueur) ;
  - une faction : le MÊME résultat, sauf `generous` (réglage fo-war-kit-genereux, pour les bancs), qui rend l'ancien kit.
  Le kit de l'ouvrier (T.kits.worker) est commun aux deux dans tous les cas. Listes triées par nom (déterminisme).
]]

local T = require("shared.team.config")

local F = {}

F.SETTING = "fo-war-kit-genereux" -- réglage de carte (settings/kit.lua), lu par script/team/team.lua

local function copy_sorted(list)
  local out = {}
  for _, it in ipairs(list or {}) do out[#out + 1] = { it[1], it[2] } end
  table.sort(out, function(a, b) return a[1] < b[1] end)
  return out
end

--- Kit offert à la fondation. `is_player` : votre équipe ; `generous` : kit de test (factions seulement).
function F.grant(is_player, generous, brain_off)
  local give_more = (not is_player) and generous == true
  return {
    chest = copy_sorted(give_more and T.start_kit_generous or T.start_kit),
    smelters = give_more and T.start_smelters_generous or T.start_smelters,
    hq_turrets = is_player and 0 or (give_more and T.start_hq_turrets_generous or T.start_hq_turrets), -- exception faction
    -- technologies du niveau 0 (T.unlocks[0]) : kit généreux, ou faction à l'ancien cerveau (échelle d'objectifs qui les suppose)
    unlock0 = give_more or ((not is_player) and brain_off == true),
    worker_kit = copy_sorted(T.kits.worker),
  }
end

return F
