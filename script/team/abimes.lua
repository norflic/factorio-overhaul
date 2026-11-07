--[[
  Lot PERF4 (tt:repair, accordé par le lead le 7/11 ; critères : fo-logs\2026-11-05_PERF4\CRITERES.md) : ENSEMBLE DES
  ENDOMMAGÉES par équipe, à la place de la recherche sur TOUTE la surface de Recon.repair_think (script/team/reconstruction.lua).
  MESURÉ sur la sauvegarde du DC (B0-avant-detail) : la recherche coûtait 13,3 ms par pensée de faction et 20,1 ms par pensée de
  votre équipe. C0-coups : les tourelles et l'infrastructure des équipes reçoivent 0,68 coup par seconde de jeu, environ 8 µs par
  coup dans le gestionnaire.

  CONTRAT : à chaque relevé, Ab.damaged(f, surface, types) rend les MÊMES entités que l'ancien code. L'ancien code faisait
  surface.find_entities_filtered{force = f.force, type = types}, puis gardait les entités à santé < 1. L'ordre ne compte pas :
  Rc.repair_batch trie par santé, puis par clé nom@x,y.

  ENTRÉES de f.abimes.set ([unit_number] = entité) :
    1. un coup reçu : on_entity_damaged avec final_health > 0. script/team/reparation.lua appelle Ab.note. Le filtre du moteur,
       commun à tout le mod, réunit Rp.filter_types et Ab.filter_types (les tourelles en étaient absentes).
    2. toute POSE d'une entité de ces types, même à pleine santé (on_built_entity, on_robot_built_entity,
       script_raised_built, script_raised_revive). Raison : le mod écrit la santé JUSTE APRÈS
       create_entity{raise_built = true} (niveaux, capital), donc la santé est relue au relevé.
    3. un RELEVÉ COMPLET (l'ancienne recherche) au premier relevé d'une équipe sur une surface, quand f.abimes est absent :
       partie d'avant ce lot, ou après on_configuration_changed. Celui-ci efface f.abimes, car une santé max changée par les
       données ne lève aucun événement.

  AU RELEVÉ : parcours de l'ensemble trié par unit_number. Sont retirées les entités invalides, celles d'une autre force et
  celles à pleine santé.

  LIMITES, dites telles quelles. Trois cas ne sont pas vus : une santé BAISSÉE par écriture directe (LuaEntity.health) sans pose,
  une force changée par script ou par fusion, et une entité abîmée CLONÉE (on_entity_cloned, éditeur ou autre mod). Le mod ne
  fait rien de cela ; relevé du 7/11 :
    - les écritures de santé sont des réparations, ou viennent juste après une pose raise_built ;
    - il n'écrit jamais LuaEntity.force ;
    - il n'appelle pas merge_forces.
  Un autre mod qui le ferait ne serait vu qu'au prochain relevé complet (on_configuration_changed).

  Coût d'un relevé : O(entités endommagées de l'équipe) au lieu de O(entités de ces types sur la surface). État : f.abimes =
  { set = { [unit_number] = LuaEntity }, ready = { [surface.index] = true } }, dans la table de l'équipe.

  Ab.ENABLED = false rend l'ancienne recherche (témoin des bancs). Le moteur simulé l'éteint quand il ne lève pas
  on_entity_damaged (tests/mock_engine.lua, opts.raise_damaged).
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local Recon = require("script.team.reconstruction")
local Ac = require("shared.team.actif")
local R = require("shared.ai3.reglages")

local Ab = {}

Ab.ENABLED = true

-- Types relevés : tourelles (Ac.REPAIR_TYPES, toutes les équipes) et infrastructure électrique (R.INFRA_TYPES, votre équipe
-- seulement : Recon.repair_think ne la relève que pour elle). Calculés une fois au chargement du fichier.
local TRACKED = {}
for _, t in ipairs(Ac.REPAIR_TYPES) do TRACKED[t] = "tourelle" end
for t in next, R.INFRA_TYPES do TRACKED[t] = "infra" end
local TYPES = {}
for t in next, TRACKED do TYPES[#TYPES + 1] = t end
table.sort(TYPES)
Ab.TRACKED = TRACKED

--- Types à ajouter au filtre moteur de on_entity_damaged (triés, copie).
function Ab.filter_types()
  local out = {}
  for i, t in ipairs(TYPES) do out[i] = t end
  return out
end

local function team_of(force_name)
  local f = State.by_force(force_name)
  if f then return f end
  local p = State.faction("player")
  if p and p.force == force_name then return p end
  return nil
end

local function sorted_units(set)
  local ks = {}
  for u in next, set do ks[#ks + 1] = u end
  table.sort(ks)
  return ks
end

--- Entité `ent` de type `etype` (un type relevé) touchée ou posée : notée dans l'ensemble de son équipe. Rien tant que l'équipe
--- n'a pas fait son relevé complet : ce relevé verra l'entité.
function Ab.note(ent, etype)
  local f = team_of(ent.force.name)
  local ab = f and f.abimes
  if not ab then return end
  if TRACKED[etype] == "infra" and not f.is_player then return end
  local u = ent.unit_number
  if u then ab.set[u] = ent end
end

--- Pose d'une entité (événements de pose) : notée si son type est relevé ; la santé est relue au relevé.
function Ab.built(e)
  local ent = e.created_entity or e.entity
  if not (ent and ent.valid) then return end
  local etype = ent.type
  if TRACKED[etype] then Ab.note(ent, etype) end
end

for _, id in ipairs({ defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.script_raised_built,
  defines.events.script_raised_revive }) do
  Events.on(id, function(e) Ab.built(e) end)
end

--- Relevé complet (l'ancienne recherche) de l'équipe sur `surface` : toutes ses entités des types relevés à santé < 1.
function Ab.full_scan(f, surface)
  local ab = f.abimes
  if not ab then
    ab = { set = {}, ready = {} }
    f.abimes = ab
  end
  local types = f.is_player and TYPES or Ac.REPAIR_TYPES
  for _, e in ipairs(surface.find_entities_filtered({ force = f.force, type = types })) do
    local u = e.valid and e.unit_number
    local r = u and e.get_health_ratio()
    if r and r < 1 then ab.set[u] = e end
  end
  ab.ready[surface.index] = true
  return ab
end

--- Entités endommagées (santé < 1) de l'équipe `f`, des types `types`, sur `surface`, triées par unit_number. Retire au passage
--- de l'ensemble les entités invalides, d'une autre force ou à pleine santé.
function Ab.damaged(f, surface, types)
  if not Ab.ENABLED then return surface.find_entities_filtered({ force = f.force, type = types }) end
  local ab = f.abimes
  local idx = surface.index
  if not (ab and ab.ready[idx]) then ab = Ab.full_scan(f, surface) end
  local want = {}
  for _, t in ipairs(types) do want[t] = true end
  local set, out = ab.set, {}
  for _, u in ipairs(sorted_units(set)) do
    local e = set[u]
    if not (e.valid and e.force.name == f.force) then
      set[u] = nil
    else
      local r = e.get_health_ratio()
      if not r or r >= 1 then
        set[u] = nil
      elseif want[e.type] and e.surface.index == idx then
        out[#out + 1] = e
      end
    end
  end
  return out
end

Recon.damaged = Ab.damaged

-- Données changées (santé max d'un prototype, autre mod) : aucun événement par entité. Relevé complet au prochain relevé.
Events.on_configuration_changed(function()
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f then f.abimes = nil end
  end
  local p = State.faction("player")
  if p then p.abimes = nil end
end)

return Ab
