--[[
  n101-pierre : voie d'extraction ÉLECTRIQUE d'une ressource, dérivée des données (A2 : consommateur sans producteur).
  Constat (graine 4251870853, fo-logs/2026-11-16_n100-energie-1 et n100-pierre-1) : la capitalisation ne connaissait que les
  méthodes de fonderie à foreuses de l'exécutant (A.METHODS : une par minerai FONDU) ; une ressource consommée telle quelle
  (sans plaque) n'avait aucune méthode, d'où « foreuse "" (aucune fonderie a foreuses pour ce minerai) » et « extraire:<ressource>
  (aucune foreuse disponible) » ; l'agrandissement thermique étant refusé dès qu'un réseau existe, ses deux paires thermiques
  restaient sa seule source : 0 foreuse électrique de cette ressource à 89 min, chez votre équipe comme chez les factions.
  La règle : une ressource SOLIDE sans fonderie a une méthode « brute » (produit = la ressource, servie par le champ en mode
  coffres) si la foreuse électrique de l'exécutant mine sa catégorie et si un champ sait la poser. Un COMBUSTIBLE (valeur de
  combustible du produit > 0) garde la voie qui est déjà la sienne (migration de ses avant-postes, bandes non bornées, plafond du
  combustible) : la capitalisation ne devient pas un second écrivain de son extraction.
  PUR : aucune API Factorio, aucun nom d'objet (les faits sont lus aux prototypes par l'appelant).
]]
local Vb = {}

--- Méthode d'extraction de `res` : celle de la fonderie (`by_ore[res]`) si elle existe, sinon une méthode brute dérivée de `info`
--- { fluid (ressource fluide), fuel (valeur de combustible du produit, J), mines (la foreuse électrique de l'exécutant mine sa catégorie),
--- champ (un champ sait poser cette ressource) }. Rend la méthode, ou nil et la raison.
function Vb.of(by_ore, res, info)
  local m = by_ore and by_ore[res]
  if m then return m end
  info = info or {}
  if res == nil then return nil, "ressource inconnue" end
  if info.fluid then return nil, "ressource fluide" end
  if (tonumber(info.fuel) or 0) > 0 then return nil, "combustible : voie de la migration de ses avant-postes" end
  if not info.mines then return nil, "aucune foreuse electrique de l'executant ne mine cette ressource" end
  if not info.champ then return nil, "aucun champ ne pose cette ressource" end
  return { product = res, ore = res, raw = true }
end

return Vb
