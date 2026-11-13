--[[
  Lot PARITE : le DÉPART de votre équipe de PNJ, comme celui d'une faction. PUR (aucune API Factorio, aucun nom d'objet) ; l'exécution
  est script/team/player_team.lua (coffre et tourelles) et script/faction/war.lua (lancement).

  Retour du DC (2/11, point 19) : « il faut crafter un coffre d'équipe [...] toutes les autres IA sont spawn et ont déjà des [tourelles]
  pour se défendre, et moi j'ai rien [...] on est censé avoir les mêmes décisions générales, non ? ». Sa règle du 28/10 : les factions ne
  reçoivent pas plus que le joueur. Décision prise en son nom : PARITÉ DE DÉPART.

    * le coffre d'équipe est posé d'office quand la guerre part par un chemin HUMAIN (réglage de carte « lancer la guerre au début »,
      commande /fo-war start, bouton de la fenêtre) et qu'aucune équipe n'existe : D.chest_due ; fabriquer un coffre reste possible ;
    * l'équipe naît avec les tourelles de QG d'une faction (shared/team/fondation.lua, hq_turrets), UNE SEULE FOIS par partie :
      D.turrets_due (un coffre perdu puis refabriqué ne les redonne pas) ;
    * une équipe DÉJÀ lancée à la montée de version ne reçoit rien d'office : D.migrate_offered.

  Déterminisme : aucune mesure de temps, aucun ordre de pairs.
]]

local D = {}

-- Emplacements des tourelles de QG autour du centre du QG (tuiles), dans l'ordre de pose. Mêmes valeurs qu'avant le lot (script/faction/war.lua).
D.HQ_OFFSETS = { { 12, 0 }, { -12, 0 }, { 0, 10 }, { 0, -10 } }

-- Décalage du coffre posé d'office par rapport au point de départ du joueur (tuiles) : à portée de main, sans être sur le joueur.
D.CHEST_OFFSET = { 6, 6 }

--- Lot s41 spawn-joueur (partie du DC, 12/11 : coffre posé en (6, 6) sur un gisement, 0 tourelle de QG sur 4, aucun coffre du stock) : places
--- essayées pour le coffre d'office, décalages depuis le point de départ, de la plus proche à la plus lointaine ; la première reste
--- CHEST_OFFSET. CHEST_CLEAR : demi-côté (tuiles) du carré autour du coffre où l'on compte les ressources (le bloc des annexes).
D.CHEST_SPOTS = { { 6, 6 }, { 6, -8 }, { -8, 6 }, { -8, -8 }, { 16, 0 }, { 0, 16 }, { -16, 0 }, { 0, -16 },
  { 16, 16 }, { 16, -16 }, { -16, 16 }, { -16, -16 }, { 26, 0 }, { 0, 26 }, { -26, 0 }, { 0, -26 } }
D.CHEST_CLEAR = 11

--- Place du coffre d'office : cands = liste ORDONNÉE de { pos = place libre ou nil, ore = ressources autour }. Rend le rang de la première
--- place libre sans ressource ; à défaut celui de la place libre qui en a le moins (la première à égalité) ; nil si aucune place libre.
function D.pick_chest(cands)
  local best
  for i, c in ipairs(cands or {}) do
    if c.pos then
      if (c.ore or 0) <= 0 then return i end
      if not best or c.ore < cands[best].ore then best = i end
    end
  end
  return best
end

--- Le départ a-t-il déjà été offert ? `v` = la valeur gardée dans la sauvegarde : faux = partie neuve (à offrir), vrai = offert, ABSENT
--- (nil) = sauvegarde d'avant le lot : une équipe déjà lancée ne reçoit rien d'office, même si la migration n'a pas tourné.
function D.is_offered(v)
  return v ~= false
end

--- Le coffre d'équipe doit-il être posé d'office ? c = { human = chemin de lancement humain, team = une équipe existe, offered = départ déjà offert }.
--- Rend (vrai/faux, motif).
function D.chest_due(c)
  if not c.human then return false, "lancement-banc" end -- les bancs (remote war_start) posent leur coffre eux-mêmes
  if c.team then return false, "equipe-existe" end
  if c.offered then return false, "deja-offert" end -- une équipe a déjà eu son départ : le coffre perdu se refabrique
  return true, "depart"
end

--- Nombre de tourelles de QG à offrir à la fondation de l'équipe. c = { grant = tourelles de la règle de fondation, offered = déjà offert }.
function D.turrets_due(c)
  if c.offered then return 0 end
  return math.max(0, c.grant or 0)
end

--- Marque « départ offert » d'une partie existante (migration) : une équipe déjà lancée ne reçoit rien d'office. c = { team, offered }
--- (offered : nil = jamais écrit). Rend la valeur à écrire.
function D.migrate_offered(c)
  if c.offered ~= nil then return c.offered end
  return c.team and true or false
end

--- Tourelles à poser : les D.HQ_OFFSETS dans l'ordre, au plus `n` (liste de { dx, dy }).
function D.offsets(n)
  local out = {}
  for i = 1, math.min(#D.HQ_OFFSETS, math.max(0, n or 0)) do out[i] = { D.HQ_OFFSETS[i][1], D.HQ_OFFSETS[i][2] } end
  return out
end

return D
