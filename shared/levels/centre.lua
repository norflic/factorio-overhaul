--[[
  Centre de commandement : ÉTAT « ÉPAVE » puis réparé (lot CENTRE-JEU, 29/10 ; remarque 7 du DC : « je pensais que
  c'était le QG du vaisseau et on peut le réparer, ensuite l'améliorer, passer les âges »).

  Pur Lua (aucune dépendance moteur) : règles seules, testées hors jeu par tests/centre_test.lua. Le runtime est
  dans script/levels/centre.lua.

  Règles (défauts de docs/QUESTIONS_DC.md n°17 et n°3, en attendant les réponses du DC) :
  - Le centre du joueur existe dès le départ en état ÉPAVE (une fois par équipe, à la création du premier joueur).
  - Une ÉPAVE n'est pas utilisable : niveau EFFECTIF 0, donc aucun plafond de niveau pour les autres familles
    (L.building_cap(0) = 1) et aucune amélioration du centre.
  - Réparer : une action du joueur, payée sur SON inventaire. Coût = paquets de réparation + la moitié des
    matériaux de l'âge 1 du passage 1 → 2 (lus à la table des coûts du centre : L.cost, jamais recopiés ici).
  - Réparé, le centre est le niveau 1 : les 15 niveaux s'améliorent comme avant.
  - Les IA (équipes, factions) ne dépendent pas de la réparation : leur état n'est jamais « épave » (seul le
    runtime pose l'état, et seulement pour la force du premier joueur).
  - Migration : un état absent veut dire « réparé » (une sauvegarde 0.6.11 n'a aucun état).
]]

local C = {}

--- Objet « paquet de réparation » du coût et nombre exigé (réglages de la règle, pas des noms de jeu en dur ailleurs).
C.PACK_ITEM = "repair-pack"
C.PACK_COUNT = 10
--- Part du coût du passage 1 → 2 du centre exigée en matériaux (0 < part ≤ 1).
C.MATERIAL_SHARE = 0.5
--- Part de la santé maximale que garde l'épave (visible dans la barre de vie) ; la réparation rend 100 %.
C.WRECK_HEALTH = 0.4
--- Où naît l'épave du joueur : décalage par rapport au joueur et rayon de recherche d'une place libre (tuiles).
C.START_OFFSET = { x = 8, y = 0 }
C.START_RADIUS = 32

--- Coût de réparation : liste ordonnée { {objet, quantité}, ... } (NOUVELLE liste à chaque appel), lue à `Lcfg`
--- (shared/levels/config.lua) : paquets, puis chaque ligne du coût 1 → 2 du centre × MATERIAL_SHARE, arrondie comme
--- le reste du mod (Lcfg.round_nice), au moins 1.
function C.repair_cost(Lcfg)
  local out = { { C.PACK_ITEM, C.PACK_COUNT } }
  local fam = Lcfg.by_key.command
  for _, c in ipairs(Lcfg.cost(fam, 2)) do
    if c[1] ~= C.PACK_ITEM then
      local q = Lcfg.round_nice(c[2] * C.MATERIAL_SHARE)
      out[#out + 1] = { c[1], math.max(1, q) }
    end
  end
  return out
end

--- Niveau EFFECTIF d'un centre : 0 tant que c'est une épave, sinon son niveau réel.
function C.effective_level(level, wrecked)
  if wrecked then return 0 end
  return level or 0
end

--- Une épave doit-elle naître au départ de cette équipe ? Oui s'il n'y a aucun centre, si le départ n'a pas déjà
--- eu lieu et s'il n'est pas coupé (scénarios de banc).
function C.should_start(has_cc, started, disabled)
  return (not has_cc) and (not started) and (not disabled)
end

--- Manque pour payer `cost` : liste { {objet, il_manque} } (vide si payable). `have` : fonction objet → quantité.
function C.missing(cost, have)
  local m = {}
  for _, c in ipairs(cost) do
    local h = have(c[1]) or 0
    if h < c[2] then m[#m + 1] = { c[1], c[2] - h } end
  end
  return m
end

--- Décision pure d'une réparation. state : { wrecked = bool, is_centre = bool } ; renvoie ok, raison (nil si ok).
--- Raisons : "not-centre", "not-wreck", "no-player", "unknown-item" (un objet du coût n'existe pas), "no-resources".
function C.can_repair(state, cost, have, exists, has_payer)
  if not state.is_centre then return false, "not-centre" end
  if not state.wrecked then return false, "not-wreck" end
  if not has_payer then return false, "no-player" end
  for _, c in ipairs(cost) do
    if not exists(c[1]) then return false, "unknown-item" end
  end
  if #C.missing(cost, have) > 0 then return false, "no-resources" end
  return true
end

return C
