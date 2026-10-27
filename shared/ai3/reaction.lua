--[[
  Lot IA3-k : RÉACTION d'un PNJ qui voit un ennemi (C2), PEUR (C3), ENGAGEMENT d'un ouvrier armé en surnombre (C4)
  (docs/IA3K_COMPORTEMENTS.md §5). PUR (tests/ia3k_reaction_test.lua).

  Entrée s = {
    hp        vie (pour mille du maximum)       armed   arme ET munitions
    kind      genre de l'ennemi le plus proche (shared/ai3/danger.lua, D.KINDS)
    dist      distance à lui (tuiles)           range   sa portée (tuiles)
    on_route  il est à portée + marge du trajet restant
    enemies   force ennemie près de lui (pesée : moyen déchiqueteur = 1)   allies  alliés armés à moins de 16 tuiles
    walking   le PNJ marche                     prudence, agressivite (pour mille ; 1 000 neutre)
  }
  Sortie : action, raison. Actions : "none" (rien : la case est seulement marquée), "flee" (fuite vers la tourelle amie
  ou le QG le plus proche), "back" (demi-tour : la tâche est rendue), "detour" (arrêt puis nouvel itinéraire), "stop"
  (arrêt de STOP_TICKS puis nouvel itinéraire), "engage" (combat sur place).
]]

local D = require("shared.ai3.danger")

local Re = {}

Re.MARGIN = 8
Re.STOP_TICKS = 180
Re.FEAR_BASE = 400  -- 40 % de vie (IA_ATTENDUS C3)
Re.FEAR_MAX = 550

--- Seuil de la peur (pour mille de vie) : 400 pour un neutre ou un audacieux, jusqu'à 550 pour un prudent.
function Re.fear(prudence)
  local t = math.floor(Re.FEAR_BASE * (prudence or 1000) / 900)
  if t < Re.FEAR_BASE then return Re.FEAR_BASE end
  if t > Re.FEAR_MAX then return Re.FEAR_MAX end
  return t
end

--- Rayon du regard (tuiles, autour d'un point LOOK_AHEAD tuiles devant le PNJ) : 28 (audacieux) à 40 (prudent).
Re.LOOK_AHEAD = 16
function Re.look_radius(prudence)
  local p = prudence or 1000
  local r = 28 + math.floor((p - 562) * 12 / 688)
  if r < 28 then return 28 end
  if r > 40 then return 40 end
  return r
end

--- Rapport de force voulu pour engager (pour mille) : 1 500 (agressif) à 3 000 (prudent).
function Re.engage_ratio(prudence, agressivite)
  local r = math.floor(2000 * (prudence or 1000) / math.max(1, agressivite or 1000))
  if r < 1500 then return 1500 end
  if r > 3000 then return 3000 end
  return r
end

--- Distance de fuite d'un PNJ sans arme : il part dès qu'un ennemi est à moins de ce rayon (24 à 36 selon la prudence).
function Re.flee_unarmed(prudence)
  local r = 24 + math.floor(((prudence or 1000) - 562) * 12 / 688)
  if r < 24 then return 24 end
  if r > 36 then return 36 end
  return r
end

function Re.decide(s)
  if not s.kind then return "none", "rien" end
  local K = D.KINDS[s.kind] or D.KINDS.unit
  local range = s.range or K.r
  local p = s.prudence or 1000
  local dist = s.dist or 1e9
  -- Peur (C3) : blessé sous le seuil ou sans munitions, et l'ennemi est à portée (+ marge).
  local hurt = (s.hp or 1000) < Re.fear(p)
  if not s.armed then
    if dist <= math.max(range + Re.MARGIN, Re.flee_unarmed(p)) then return "flee", "desarme" end
  elseif hurt and dist <= range + Re.MARGIN then
    return "flee", "blesse"
  end
  if K.fixed then
    -- Ver, nid, tourelle : on ne passe pas à sa portée.
    if dist <= range + 2 then return "back", "a-portee" end
    if s.walking and (s.on_route or dist <= range + Re.MARGIN) then return "detour", "sur-la-route" end
    return "none", "vu"
  end
  -- Unités et personnages : se battre en surnombre ; sinon, selon leur portée utile (leur VUE pour une unité) : au-delà
  -- de portée + marge, s'arrêter (elles passent peut-être) ; entre portée et portée + marge, se détourner tout de suite ;
  -- à portée, partir.
  local n = math.max(0.2, s.enemies or 1) -- force PESÉE (moyen déchiqueteur = 1)
  if s.armed and ((s.allies or 0) + 1) * 1000 >= Re.engage_ratio(p, s.agressivite) * n then
    if dist <= range + Re.MARGIN or s.on_route then return "engage", "surnombre" end
    return "none", "vu"
  end
  if dist > range + Re.MARGIN then
    if s.walking and s.on_route then return "stop", "sur-la-route" end
    return "none", "vu"
  end
  if dist > range then
    if s.walking then return "detour", "proche" end
    return "flee", "proche"
  end
  if s.walking then return "back", "trop-pres" end
  return "flee", "trop-pres"
end

-- Étiquette visible (D1) de chaque action (clé de locale/*/ia3k.cfg, section fo-ia3k).
Re.LABEL = {
  flee = "fuite", back = "demi-tour", detour = "detour", stop = "alerte", engage = "combat",
}

return Re
