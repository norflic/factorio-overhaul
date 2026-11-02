--[[
  Lot MALL « ravitaillement » (retour du DC du 2/11, point 9 : « il y a toujours pas d'alimentation réelle de fer directement dans un mall
  [...] toutes les constructions doivent être alimentées en permanence à la main [...] ça utilise des workers pour aucune raison et ça met
  beaucoup de production à l'arrêt »). Règle PURE : aucune API du jeu, AUCUN nom d'objet ni de bâtiment (le test iag_test l'interdit) ;
  testée hors jeu (tests/ravitaillement_test.lua) et lue par shared/team/liaison.lua (appariement, tracé, prix) et script/team/build.lua
  (portage de secours).

  Constat chiffré (témoin main 0.6.35, fo-logs/2026-11-02_MALL/RAPPORT.md) : l'équipe Azure a porté 99 voyages (11 911 objets) vers les quais de
  ses malls entre 25 et 56 min, soit 93 % de tout son portage, et AUCUN quai de mall n'a eu de tapis : la liaison de quai (lot INDUSTRIE I7)
  ne trouvait pas de coffre de sortie qui porte l'objet (cause « sans-sortie » : la sortie d'un mall encore vide ou à plusieurs objets) ou
  le trouvait à plus de 40 tuiles (cause « loin » : un mall tient l'emplacement du QG, une fonderie le gisement), puis le prix (retour sous
  90 min) refusait les quais de faible débit.

  La règle (une LIGNE par ressource d'entrée d'un mall, depuis la sortie la plus proche qui porte l'objet) :
    1. Portée : un quai de mall se relie à une sortie jusqu'à Rv.SPAN tuiles (Manhattan), par un tapis d'au plus Rv.LEN tuiles. Le détour
       reste borné par Li.route_ok. Au-delà, le portage à la main continue (l'ancien mode est le secours, il ne change pas).
    2. Prix : un mall dure toute la partie ; le retour d'une ligne de mall est jugé sur Rv.TMAX minutes (4 fois Li.TMAX), pas sur 90.
    3. Partage : une sortie sert jusqu'à Rv.FAN quais de mall (deux bras de côtés différents, un seul quai pour les autres modules).
    4. Portage à la main : une ligne FINIE réduit le seuil du portage à Rv.rescue_low(low) : le PNJ ne porte plus que pour le démarrage (la ligne
       n'existe pas encore) et le secours (le coffre est presque vide, donc la ligne ne suit plus).
  Déterminisme : entiers et fractions fixes, aucun pairs, aucune horloge mesurée.
]]

local Rv = {}

Rv.SPAN = 72        -- tuiles (Manhattan) entre la sortie et le quai d'un mall (Li.MAX_SPAN : 40 pour les autres modules)
Rv.LEN = 96         -- tuiles de tapis au plus pour un quai de mall (Li.MAX_LEN : 48)
Rv.TMAX = 360       -- minutes : retour accepté d'une ligne de mall (Li.TMAX : 90)
Rv.FAN = 2          -- quais de mall servis au plus par un même coffre de sortie
Rv.RESCUE_DIV = 3   -- le portage de secours d'un quai relié part au tiers du seuil ordinaire

--- Le quai est-il celui d'un mall ? (d.mall posé par le relevé : projet « patron » ou « bloc »)
function Rv.is_mall(d) return d ~= nil and d.mall == true end

--- Portée (tuiles) d'une paire pour ce quai ; `base` : la portée des autres modules.
function Rv.span_max(d, base) return Rv.is_mall(d) and math.max(base, Rv.SPAN) or base end

--- Longueur de tapis permise pour ce quai ; `base` : celle des autres modules.
function Rv.len_max(d, base) return Rv.is_mall(d) and math.max(base, Rv.LEN) or base end

--- Retour accepté (minutes) d'une liaison pour ce quai ; `base` : Li.TMAX.
function Rv.tmax(d, base) return Rv.is_mall(d) and math.max(base, Rv.TMAX) or base end

--- Quais servis au plus par une même sortie, vu du quai qui choisit : Rv.FAN pour un mall, 1 sinon.
function Rv.fan(d) return Rv.is_mall(d) and Rv.FAN or 1 end

--- Liaisons déjà tirées depuis cette sortie : `s.taken` (relevé), sinon 1 si `s.linked` (ancienne forme), sinon 0.
function Rv.taken(s)
  if s.taken ~= nil then return s.taken end
  return s.linked and 1 or 0
end

--- Seuil du portage à la main (objets au coffre d'entrée) : `low` (Build.QUAI_LOW) sans ligne finie, le tiers (au moins 1) avec une ligne finie.
--- Au-dessus du seuil, aucune tâche de portage n'est émise.
function Rv.rescue_low(low, line_done)
  if not line_done then return low end
  return math.max(1, math.floor(low / Rv.RESCUE_DIV))
end

--- Le PNJ doit-il porter à ce quai ? n : objets au coffre ; have : stock du QG ; low : Build.QUAI_LOW ; line_done : ligne finie.
function Rv.hand_due(n, have, low, line_done)
  return n < Rv.rescue_low(low, line_done) and (have or 0) > 0
end

return Rv
