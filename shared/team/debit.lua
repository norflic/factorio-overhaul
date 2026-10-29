--[[
  DEBIT (lot RANGEES-DEBIT, retour du DC du 29/10 vers 21 h 55 en jouant la 0.6.18) : la ligne de foreuses d'une fonderie à
  tapis est dimensionnée par le DÉBIT DU TAPIS COLLECTEUR, plus par un paquet fixe.
  PUR : aucune API Factorio, aucun nom d'objet (vitesse du tapis et débit d'une foreuse arrivent en DONNÉES : tests/iag_test.lua §8).

  Le DC : « ce genre de pack de six, ça peut pas fonctionner. En fait, il faut faire des packs de N et en fonction, un pack de N
  en fonction du débit. Donc 15 objets par seconde, c'est marqué les convoyeurs. Vitesse du minage 0,5 par seconde. [...] huit
  d'un côté, huit de l'autre au lieu d'en avoir six. »

  Une ligne de foreuses (générateur « drills » de shared/team/modules.lua) = n PAIRES, une foreuse de chaque côté du collecteur ;
  chaque côté dépose sur SA voie. Une voie porte C.capacity(belt_speed) objets/s (7,5/s pour belt_speed 0,03125).

  Db.lane_capacity(speed)                    -> objets/s d'une voie d'un tapis de vitesse `speed` (shared/team/convoyeurs.lua).
  Db.belt_pairs(lane_cap, drill_rate, emprise)
                                             -> paires que le collecteur porte : foreuses par côté = voie ÷ débit d'une foreuse
                                                (arrondi par défaut : la voie n'est jamais saturée), borné par `emprise` (le
                                                gabarit : longueur d'un lot) ; 0 si une donnée manque.
]]
local C = require("shared.team.convoyeurs")

local Db = {}

local EPS = 1e-9
local floor, max, min = math.floor, math.max, math.min

function Db.lane_capacity(speed)
  if type(speed) ~= "number" or speed <= 0 then return 0 end
  return C.capacity(speed)
end

function Db.belt_pairs(lane_cap, drill_rate, emprise)
  if type(lane_cap) ~= "number" or type(drill_rate) ~= "number" or lane_cap <= 0 or drill_rate <= 0 then return 0 end
  local per_side = floor(lane_cap / drill_rate + EPS)
  if type(emprise) == "number" then per_side = min(per_side, floor(emprise + EPS)) end
  return max(0, per_side)
end

return Db
