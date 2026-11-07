--[[
  Lot S7 (X10, queue de la vue ; critères : fo-logs/2026-11-07_X10/S7_CRITERES.md) : DANGER d'un avant-poste = un nid ou un ver
  (force « enemy », types unit-spawner et turret) à moins de `radius` tuiles de son accès. Même question que la recherche d'avant,
  `count_entities_filtered{position, radius, force = "enemy", type = { "unit-spawner", "turret" }, limit = 1} > 0`, posée deux fois
  dans le même tick T de la pensée E1 : par la vue (script/team/team.lua, view:2, avant-postes dont une tournée est en jeu) et par
  les pôles (script/team/poles.lua, tous les avant-postes, pour le fond).

  CONTRAT : D.near rend TOUJOURS ce que rendait la recherche au même instant (ombre de tests/x10_s7_test.lua). Deux mémoires, sans
  aucune limite :
    1. même tick, même position, même rayon : le résultat déjà lu (rien ne pose ni n'ôte un nid entre la vue et les pôles d'une
       même pensée) ;
    2. un danger TROUVÉ est gardé d'une pensée à l'autre tant que son TÉMOIN (l'entité rendue par find_entities_filtered{..., limit = 1})
       est valide, à la même position et au même rayon, et SEULEMENT si ce témoin est FIXE (type de FIXE : nid, ver ou tourelle
       ennemie) : il ne bouge pas et ne change pas de force ; quelle que soit la façon dont il disparaît (mort, destroy, set_tiles), il
       devient invalide et le danger est recompté. Un témoin MOBILE (unité, si la recherche en rendait un) a pu sortir du rayon en
       restant valide : il n'est jamais gardé d'une pensée à l'autre (exigence du lead, 7/11 ; cas et mutant dans tests/x10_s7_test.lua).
  Une ABSENCE de danger n'est jamais gardée d'une pensée à l'autre : un nid posé sans événement (banc, autre mod) ne laisse aucun
  décalage.

  État : f.danger_ap = { [id d'avant-poste] = { x, y, r, t, hit, w } } (w : entité témoin FIXE ou nil), dans global ; les avant-postes
  disparus sont retirés par D.prune. D.ENABLED = false : la recherche d'avant à chaque appel (témoin des bancs).
]]
local State = require("script.faction.state")

local D = {}

D.ENABLED = true
local TYPES = { "unit-spawner", "turret" }
-- Types dont une entité ne bouge jamais : seul un témoin de ces types garde le danger d'une pensée à l'autre.
local FIXE = { ["unit-spawner"] = true, ["turret"] = true }

--- Nid ou ver à moins de `radius` tuiles de `pos` (avant-poste `oid` de l'équipe `f`), à `tick`.
function D.near(f, surface, oid, pos, tick, radius)
  if not D.ENABLED then
    return surface.count_entities_filtered({ position = pos, radius = radius, force = "enemy", type = TYPES, limit = 1 }) > 0
  end
  local mem = f.danger_ap
  if not mem then
    mem = {}
    f.danger_ap = mem
  end
  local m = mem[oid]
  if m and m.x == pos.x and m.y == pos.y and m.r == radius then
    if m.t == tick then return m.hit end
    if m.hit and m.w and m.w.valid then
      m.t = tick
      return true
    end
  end
  local w = surface.find_entities_filtered({ position = pos, radius = radius, force = "enemy", type = TYPES, limit = 1 })[1]
  -- (même tick : la réponse vaut quel que soit le témoin, aucune entité ne bouge pendant le script ; d'une pensée à l'autre : témoin fixe seulement)
  mem[oid] = { x = pos.x, y = pos.y, r = radius, t = tick, hit = w ~= nil, w = (w and FIXE[w.type]) and w or nil }
  return w ~= nil
end

--- Retire la mémoire des avant-postes qui n'existent plus (appelé par la vue, une fois par pensée).
function D.prune(f)
  local mem = f.danger_ap
  if not mem then return end
  local outposts = f.outposts or {}
  for _, oid in ipairs(State.sorted_keys(mem)) do
    if not outposts[oid] then mem[oid] = nil end
  end
end

return D
