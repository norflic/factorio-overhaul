--[[
  Lot PD-CENTREQG (D20 ; le DC, 29/10, 14 h : « jumeler le centre de commandement et le QG de faction qui est en fait le
  même bâtiment […] le QG de faction, c'est le centre de commandement, et on l'améliore »). Fusion LOGIQUE (le visuel
  est en pause : CENTRE-FUSEE) : le QG d'une faction EST son centre de commandement.

  Deux entités, un seul bâtiment :
    - le CORPS : l'épave fo-faction-hq (f.hq), inchangée : 25 000 PV, coffre du stock, propriétaire « hq » (sa perte
      élimine la faction), étiquette, recrutement, annexes ; aucun de ses lecteurs ne change ;
    - le CENTRE LIÉ : le centre de commandement de la famille des niveaux (fo-command-center-N), posé avec le QG à sa
      fondation, au niveau 1, gratuit (les IA n'ont pas d'épave à réparer, Q17). Il PORTE le niveau d'époque
      (Levels.cc(force), Levels.cc_level(force)) et s'améliore par le mécanisme du joueur (Levels.start, payé par le coffre
      du QG : script/ai3/capital.lua, quand fo-war-capital est allumé). Il est INDESTRUCTIBLE et non minable : il ne
      meurt qu'avec le corps (élimination, déménagement), jamais seul.
  Lien : f.centre_qg = numéro d'unité du centre lié (dans l'état de la guerre ; nombres seulement).
  Votre équipe (f.is_player) n'est pas touchée : votre centre est le vôtre (épave réparée, script/levels/centre.lua).

  Points d'entrée :
    - CQ.ensure(f, why) : à la fondation (war.lua, found_hq), à la migration (on_configuration_changed : sauvegarde 0.6.18,
      QG existant RELIÉ au centre déjà posé par CAPITAL, ou nouveau centre de niveau 1 ; le corps et son coffre ne sont
      jamais touchés) et à la veille des étiquettes (war.lua, toutes les 600 ticks : filet si le lien s'est perdu) ;
    - CQ.release / CQ.relink : autour de Levels.start (capital.lua) : le centre redevient destructible et minable le temps
      du remplacement (remplacement rapide moteur ou agrandissement par script), puis le NOUVEAU centre est relié ;
    - CQ.drop(f, why) : le corps est perdu (élimination) ou défait (déménagement) : le centre lié part avec lui
      (destroy, raise_destroy : le module des niveaux oublie le centre de la force).
  Journal : [FO-CENTRE-QG] (une ligne par lien, pose, échec de place, amélioration, chute).
  Le module des niveaux est lu à l'appel (package.loaded) : il est chargé après les factions (control.lua) ; absent (bancs
  hors jeu sans niveaux), rien n'est posé.
  Déterminisme : factions par numéro trié, places essayées dans un ordre fixe, aucun hasard.
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local L = require("shared.levels.config")

local CQ = {}

-- Places essayées autour du QG, dans l'ordre (les mêmes que celles de l'ancien « poser le centre » de CAPITAL,
-- Capital.CENTER_OFFSETS : hors du lot (0, 0) du treillis, des rangées de fours et de laboratoires et des annexes).
CQ.OFFSETS = { { 0, 14 }, { 14, 0 }, { -14, 0 }, { 0, -14 }, { 14, 14 }, { -14, 14 } }
CQ.SEARCH = 12

local CFAM = L.by_key.command

local function levels() return package.loaded["script.levels.levels"] end

local function force_of(f)
  return f and f.force and game.forces[f.force] or nil
end

--- Centre de commandement (lié) de la faction, valide, ou nil. Votre équipe : nil.
function CQ.centre(f)
  local Lv = levels()
  if not (Lv and f and not f.is_player) then return nil end
  local force = force_of(f)
  return force and Lv.cc(force) or nil
end

--- Niveau d'époque porté par le QG de la faction (0 : pas de centre).
function CQ.level(f)
  local Lv = levels()
  if not (Lv and f and not f.is_player) then return 0 end
  local force = force_of(f)
  return force and Lv.cc_level(force) or 0
end

local function lock(e)
  e.destructible = false
  e.minable = false
end

local function where(e)
  local p = e.position
  return string.format("(%d, %d)", math.floor(p.x), math.floor(p.y))
end

--- Relie `e` (centre de commandement de la force) au QG de `f`.
function CQ.link(f, e, why)
  lock(e)
  local was = f.centre_qg
  f.centre_qg = e.unit_number
  f.centre_qg_fail = nil
  if was ~= e.unit_number then
    local _, n = L.parse(e.name)
    log(string.format("[FO-CENTRE-QG] %s : QG relie au centre de commandement %s (niveau %d) en %s, cause %s, tick %d",
      f.key or "?", tostring(e.unit_number), n or 0, where(e), why or "?", game.tick))
  end
end

--- Le QG de `f` porte un centre lié : relie le centre déjà là, ou en pose un de niveau 1. Rend l'entité et l'état
--- (« lie », « pose ») ou nil et le motif (« hors », « sans-qg », « sans-niveaux », « place »).
function CQ.ensure(f, why)
  if not f or f.is_player or f.eliminated then return nil, "hors" end
  if not (f.hq and f.hq.valid and f.hq_pos) then return nil, "sans-qg" end
  local Lv = levels()
  if not Lv then return nil, "sans-niveaux" end
  local force = force_of(f)
  if not force then return nil, "hors" end
  local cc = Lv.cc(force)
  if cc then
    if f.centre_qg ~= cc.unit_number or cc.destructible or cc.minable then CQ.link(f, cc, why) end
    return cc, "lie"
  end
  local surface = f.hq.surface
  local name = L.name(CFAM, 1)
  for _, off in ipairs(CQ.OFFSETS) do
    local pos = surface.find_non_colliding_position(name, { x = f.hq_pos.x + off[1], y = f.hq_pos.y + off[2] }, CQ.SEARCH, 1)
    if pos then
      local e = surface.create_entity({ name = name, position = pos, force = force, raise_built = true })
      if e and e.valid and Lv.cc(force) == e then
        log(string.format("[FO-CENTRE-QG] %s : centre de commandement de niveau 1 pose avec le QG en %s, cause %s, tick %d",
          f.key or "?", where(e), why or "?", game.tick))
        CQ.link(f, e, why)
        return e, "pose"
      end
    end
  end
  if not f.centre_qg_fail then
    f.centre_qg_fail = true
    log(string.format("[FO-CENTRE-QG] %s : AUCUNE place pour le centre de commandement autour du QG (%d, %d), cause %s, tick %d",
      f.key or "?", math.floor(f.hq_pos.x), math.floor(f.hq_pos.y), why or "?", game.tick))
  end
  return nil, "place"
end

--- Avant Levels.start sur le centre lié : remplacement possible (le moteur et le script retirent l'ancien centre).
function CQ.release(f, e)
  if f and not f.is_player and e and e.valid and f.centre_qg == e.unit_number then
    e.destructible = true
    e.minable = true
  end
end

--- Après Levels.start : relie le centre courant de la force (le nouveau si l'amélioration a eu lieu, l'ancien sinon).
function CQ.relink(f, why)
  local e = CQ.centre(f)
  if e then CQ.link(f, e, why) end
  return e
end

--- Le corps du QG est perdu ou défait : le centre lié part avec lui.
function CQ.drop(f, why)
  local e = CQ.centre(f)
  f.centre_qg = nil
  if not e then return false end
  local _, n = L.parse(e.name)
  log(string.format("[FO-CENTRE-QG] %s : centre de commandement (niveau %d) retire avec le QG, cause %s, tick %d",
    f.key or "?", n or 0, why or "?", game.tick))
  e.destroy({ raise_destroy = true })
  return true
end

--- Toutes les factions vivantes de la guerre active (votre équipe exceptée), par numéro.
local function each_faction(fn)
  local war = State.war()
  if not (war and war.active and war.factions) then return end
  for _, id in ipairs(State.sorted_keys(war.factions)) do
    local f = war.factions[id]
    if f and not f.is_player and not f.eliminated then fn(f) end
  end
end
CQ.each_faction = each_faction

-- Migration (sauvegarde d'avant le lot, 0.6.18 et plus ancienne) : chaque QG vivant est relié au centre déjà posé par CAPITAL
-- ou reçoit un centre de niveau 1. Le corps du QG (et donc son coffre) n'est jamais touché.
Events.on_configuration_changed(function()
  each_faction(function(f) CQ.ensure(f, "migration") end)
end)

---------------------------------------------------------------------------------------------------
-- Interface distante (bancs) : lecture, et amélioration du centre lié par le chemin de CAPITAL
---------------------------------------------------------------------------------------------------
local function find(key)
  local out
  each_faction(function(f) if f.key == key then out = f end end)
  return out
end

remote.add_interface("fo-centre-qg", {
  status = function()
    local out = {}
    each_faction(function(f)
      local e = CQ.centre(f)
      out[#out + 1] = { key = f.key, force = f.force, hq = f.hq and f.hq.valid and f.hq.unit_number or nil,
        centre = e and e.unit_number or nil, name = e and e.name or nil, level = CQ.level(f), linked = f.centre_qg,
        destructible = e and e.destructible, minable = e and e.minable }
    end)
    return out
  end,
  -- Aperçu de l'amélioration suivante du centre lié (Levels.preview, recensement complet) : ok, motif, coût, familles bloquantes.
  preview = function(key)
    local f = find(key)
    local Lv = levels()
    local e = f and CQ.centre(f)
    if not (e and Lv) then return nil end
    local info = Lv.preview(e, nil, true) or {}
    return { ok = info.ok, reason = info.reason, cost = info.cost, blocking = info.blocking, level = CQ.level(f) }
  end,
  -- Même chemin que l'exécutant de CAPITAL (script/ai3/capital.lua) : payé par le coffre du QG et ses annexes.
  upgrade = function(key)
    local f = find(key)
    local Lv = levels()
    local Stock = package.loaded["script.team.stock"]
    if not (f and Lv and Stock) then return false, "inconnu" end
    local e = CQ.centre(f)
    if not e then return false, "sans-centre" end
    CQ.release(f, e)
    local ok, why = Lv.start(e, nil, { inventories = Stock.inventories(f) })
    CQ.relink(f, ok and "amelioration" or "amelioration-refusee")
    log(string.format("[FO-CENTRE-QG] %s : amelioration du centre demandee par un banc : %s (%s), niveau %d", f.key or "?",
      ok and "faite" or "refusee", tostring(why), CQ.level(f)))
    return ok, why
  end,
})

return CQ
