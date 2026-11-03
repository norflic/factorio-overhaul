--[[
  Revue-fonderie, point 7 (3/11) : le projet LIÉ du réseau du charbon d'une bande découpée (script/team/migration_champ.lua, begin_band :
  Sa.split au-delà de Champ.CFG.band_max) n'avait pas de lecteur : son identifiant n'était que journalisé. Refusé, rien ne le redemandait (la
  colonne marchait à l'amorce puis s'arrêtait) ; la bande annulée après le plan du projet lié, il restait orphelin.

  Règle pure (aucune lecture du moteur, aucun état gardé : tout se relit dans les projets du plan directeur) :
    - projets liés groupés par (bande, côté) ;
    - bande absente ou refusée : chaque projet lié encore annulable (attente, plan, réserve) est ANNULÉ ;
    - bande vivante, et AUCUN projet lié vivant pour ce côté (tous refusés) : il est REDEMANDÉ, au plus Ln.MAX_TRIES projets refusés par
      (bande, côté) ; au-delà, rien (le refus est écrit au journal).
  Rend { cancel = { id, ... }, rerequest = { id du dernier refusé, ... } }, triés.
]]
local Ln = {}

Ln.MAX_TRIES = 3
Ln.CANCELLABLE = { attente = true, plan = true, reserve = true }

--- items : { { id, state, band, side, band_state } } (band_state nil : bande absente du plan directeur).
function Ln.decide(items)
  local groups, keys = {}, {}
  for _, it in ipairs(items or {}) do
    local k = tostring(it.band) .. ":" .. tostring(it.side)
    if not groups[k] then groups[k] = { band = it.band, side = it.side, band_state = it.band_state, list = {} }; keys[#keys + 1] = k end
    local g = groups[k]
    g.list[#g.list + 1] = it
  end
  table.sort(keys)
  local out = { cancel = {}, rerequest = {} }
  for _, k in ipairs(keys) do
    local g = groups[k]
    table.sort(g.list, function(a, b) return a.id < b.id end)
    local dead = g.band_state == nil or g.band_state == "refuse"
    if dead then
      for _, it in ipairs(g.list) do if Ln.CANCELLABLE[it.state] then out.cancel[#out.cancel + 1] = it.id end end
    else
      local alive, refused, last = false, 0, nil
      for _, it in ipairs(g.list) do
        if it.state == "refuse" then refused = refused + 1; last = it.id else alive = true end
      end
      if not alive and refused > 0 and refused < Ln.MAX_TRIES then out.rerequest[#out.rerequest + 1] = last end
    end
  end
  table.sort(out.cancel)
  table.sort(out.rerequest)
  return out
end

return Ln
