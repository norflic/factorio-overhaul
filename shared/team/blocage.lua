--[[
  Lot FACTIONS-BLOQUEES « une équipe qui ne progresse plus » (retour du DC, 29/10, 1 h 30 de partie sur 0.6.13 : « elles
  avancent pas », « c'est très désorganisé »). PUR : aucune API Factorio, aucun nom d'objet du jeu ; testé hors jeu
  (tests/blocage_test.lua).

  Cause mesurée sur les deux parties archivées de 60 min (fo-logs/2026-10-29_VAGUE2/FUMEE, journal [FO-IA1D]) : les tourelles
  posées autour d'un avant-poste (Outposts.fortify_at) ignoraient les tuiles RÉSERVÉES par le plan directeur ; un tapis
  planifié passait sous une tourelle de la même équipe et son fantôme restait refusé « occupe » (30 refus sur 20261020,
  fonderie d'Azure à 111 entités sur 113 de 36 min à la fin ; même défaut sur 1618033988, fonderie bloquée de 37 min à la fin).

  Quatre règles :
  - `spots` : les positions voisines d'un emplacement de tourelle, dans un ordre fixe (anneaux de 3 tuiles, sans trigonométrie) ;
  - `first_free` : la première position trouvée par le moteur qui n'est pas réservée ;
  - `own_blockers` : parmi les entités qui occupent l'emprise d'un fantôme refusé, sont-elles TOUTES des tourelles de l'équipe ?
    (alors elles s'enlèvent : la pose des tourelles évite désormais la place) ;
  - `stall` : un projet qui n'avance plus depuis `limit` ticks, signalé UNE fois par cause (journal [FO-BLOQUE]).
  Aucun `pairs`, aucun hasard, aucun temps mesuré.
]]

local Bl = {}

Bl.RING = 3            -- tuiles : écart des anneaux de repli autour d'un emplacement de tourelle
Bl.RINGS = 3           -- nombre d'anneaux (3, 6, 9 tuiles)
Bl.STALL_TICKS = 36000 -- 10 min sans progrès : l'équipe est dite bloquée

--- Positions candidates autour de (x, y) : le point lui-même, puis 8 points par anneau (E, O, S, N, puis les diagonales).
--- Liste de { x, y }, ordre fixe.
function Bl.spots(x, y)
  local out = { { x = x, y = y } }
  local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 } }
  for r = 1, Bl.RINGS do
    local d = Bl.RING * r
    for _, v in ipairs(dirs) do out[#out + 1] = { x = x + v[1] * d, y = y + v[2] * d } end
  end
  return out
end

--- Première position libre : `find(spot)` rend la position que le moteur accepte près de `spot` (ou nil) ; `reserved(pos)` dit si
--- elle recouvre une tuile réservée par un projet. Une même position trouvée deux fois n'est testée qu'une fois. Rend pos, ou nil.
function Bl.first_free(spots, find, reserved)
  local seen = {}
  for _, s in ipairs(spots) do
    local pos = find(s)
    if pos then
      local k = pos.x .. ":" .. pos.y
      if not seen[k] then
        seen[k] = true
        if not (reserved and reserved(pos)) then return pos end
      end
    end
  end
  return nil
end

--- `list` : entités { name, force } sur l'emprise d'un fantôme refusé. Vrai si elle n'est pas vide et ne porte que des entités
--- de `force` nommées `name` (la tourelle de l'équipe) : ce ne sont ni des arbres, ni des falaises, ni un bâtiment du plan.
function Bl.own_blockers(list, force, name)
  if #list == 0 then return false end
  for _, x in ipairs(list) do
    if x.force ~= force or x.name ~= name then return false end
  end
  return true
end

--- Cause d'un projet qui n'avance pas, en un mot stable (une même cause = une seule ligne de journal par équipe).
function Bl.cause(state, reason)
  local r = tostring(reason or "")
  if state == "bloque" then
    local why = r:match("^fantome refuse %(([%w%-]+)") or r
    return "fantome:" .. why
  end
  if r ~= "" then return tostring(state) .. ":" .. (r:match("^([^%(%[;,:]+)") or r) end
  return tostring(state)
end

--- Suivi du progrès d'un projet. `rec` = { sig, since, said = { [cause] = true } } (nil au premier appel) ; `sig` = signature
--- du progrès (entités bâties, état) ; `tick` = tick courant. Rend (rec, say) : `say` est la cause à écrire une fois, ou nil.
--- Un progrès (signature changée) remet l'horloge à zéro mais garde les causes déjà dites : une cause revenue plus tard
--- n'est pas redite (une ligne par équipe et par cause).
function Bl.stall(rec, sig, cause, tick, limit)
  limit = limit or Bl.STALL_TICKS
  if not rec then return { sig = sig, since = tick, said = {} }, nil end
  if rec.sig ~= sig then
    rec.sig, rec.since = sig, tick
    return rec, nil
  end
  if tick - rec.since >= limit and not rec.said[cause] then
    rec.said[cause] = true
    return rec, cause
  end
  return rec, nil
end

return Bl
