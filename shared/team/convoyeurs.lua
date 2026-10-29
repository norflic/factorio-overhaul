--[[
  CONVOYEURS (lot CONVOYEURS, remarque 6 du DC : « verifier qu'il y a des niveaux aussi de convoyeurs ») : règle PURE du
  choix du tapis par les équipes de PNJ. Aucun nom d'objet : la liste des tapis vient des données du jeu (prototypes de
  type transport-belt, vitesse `belt_speed`), la disponibilité de la technologie est un prédicat `usable(nom)` fourni par
  l'appelant (recette débloquée pour la force). Tests : tests/convoyeurs_test.lua.

    C.sorted(belts)                       copie triée par vitesse puis nom, entrées invalides retirées
    C.capacity(speed)                     débit d'UNE voie en objets/s (belt_speed × 240 : 0,03125 → 7,5/s)
    C.pick(belts, usable, need, opts)     tapis d'un nouveau tracé : le meilleur disponible (opts.need_only : le plus lent
                                          qui suffit à `need`, objets/s sur une voie)
    C.saturated(flow, speed)              le débit voulu approche-t-il la capacité d'une voie ?
    C.upgrade_target(belts, usable, cur, flow)   niveau SUPÉRIEUR disponible quand le tapis `cur` sature, sinon nil
    C.next_batch(list, from, max)         indices (au plus `max`) des tuiles bâties de nom `from` à remplacer
]]

local C = {}

C.LANE_FACTOR = 240   -- objets/s par unité de belt_speed et par voie (8 objets par tuile pour 2 voies, 60 ticks/s, / 2)
C.MARGIN = 0.9        -- part de la capacité comptée utilisable (un tapis ne se remplit jamais à 100 %)
C.SATURATION = 0.8    -- un tapis sature quand le débit voulu dépasse cette part de sa capacité de voie

function C.capacity(speed) return (speed or 0) * C.LANE_FACTOR end

--- Copie triée (vitesse croissante, nom pour départager) des entrées { name, speed } valides.
function C.sorted(belts)
  local out = {}
  for _, b in ipairs(belts or {}) do
    if type(b.name) == "string" and type(b.speed) == "number" and b.speed > 0 then out[#out + 1] = b end
  end
  table.sort(out, function(a, b)
    if a.speed ~= b.speed then return a.speed < b.speed end
    return a.name < b.name
  end)
  return out
end

local function usable_list(belts, usable)
  local out = {}
  for _, b in ipairs(C.sorted(belts)) do
    if not usable or usable(b.name) then out[#out + 1] = b end
  end
  return out
end

--- Tapis d'un nouveau tracé. `need` (objets/s sur une voie) n'est lu qu'avec opts.need_only : le plus lent disponible dont
--- la capacité (× C.MARGIN) suffit, à défaut le plus rapide. Sinon : le plus rapide disponible. Rend nom, vitesse ; nil
--- quand aucun tapis n'est disponible.
function C.pick(belts, usable, need, opts)
  local list = usable_list(belts, usable)
  if #list == 0 then return nil end
  if opts and opts.need_only and need then
    for _, b in ipairs(list) do
      if C.capacity(b.speed) * C.MARGIN + 1e-9 >= need then return b.name, b.speed end
    end
  end
  local last = list[#list]
  return last.name, last.speed
end

function C.saturated(flow, speed)
  return (flow or 0) >= C.SATURATION * C.capacity(speed) - 1e-9
end

--- Amélioration sur place : le niveau supérieur disponible (le suivant en vitesse, celui qui a une vitesse STRICTEMENT plus
--- grande) quand le tapis `cur` sature à `flow` ; nil sinon (tapis inconnu, déjà le meilleur, pas de saturation).
function C.upgrade_target(belts, usable, cur, flow)
  local all = C.sorted(belts)
  local cs
  for _, b in ipairs(all) do if b.name == cur then cs = b.speed end end
  if not cs or not C.saturated(flow, cs) then return nil end
  for _, b in ipairs(usable_list(belts, usable)) do
    if b.speed > cs then return b.name, b.speed end
  end
  return nil
end

--- Indices (ordre de la liste, au plus `max`) des entrées bâties dont le nom est `from`. list[i] = { name, built }.
function C.next_batch(list, from, max)
  local out = {}
  for i, e in ipairs(list or {}) do
    if #out >= max then break end
    if e.name == from and e.built then out[#out + 1] = i end
  end
  return out
end

return C
