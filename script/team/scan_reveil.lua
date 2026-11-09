--[[
  Lot SCAN-EVENEMENTS (directive du DC du 9/11, « bannissement du H24 ») : les DÉCLENCHEURS ÉVÉNEMENTIELS d'un scan de requalification.
  Ils ne font que POSER un réveil (St.wake sur f.team.scan) ; la passe part au prochain créneau de la voie de l'équipe (script/team/hygiene.lua,
  règle pure shared/team/scan_tranches.lua). Quatre causes, toutes détectées en données pures, par comparaison avec l'état précédent gardé
  dans f.team.scan (nombres et booléens), jamais sur une horloge :
    (a) « recherche » : on_research_finished (abonnement statique) : chaque équipe dont la force a fini la recherche ;
    (b) « stock » : à chaque pensée d'équipe (script/team/team.lua, E6, une ligne), une PIÈCE dont l'objet se pose en entité de TYPE inserter,
        transport-belt ou assembling-machine (types de prototypes : aucun nom) franchit À LA HAUSSE un palier de Sr.CFG.step unités (les 50
        premiers bras, les 50 suivants…) depuis le dernier relevé (f.team.scan.stock[item] = dernier palier) ;
    (c) « energie » : f.build.sante.healthy passe de vrai à faux (coupure d'énergie, script/team/reseau_vivant.lua) ;
    (d) « ressource » : Famine.team_starved(f, tick) passe de faux à vrai (rupture de la plaque clé, script/team/famine_fer.lua).
  Un réveil posé pendant qu'un autre attend ne fait que compter (St.wake) : une seule passe.
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local Famine = require("script.team.famine_fer")
local St = require("shared.team.scan_tranches")

local Sr = {}

Sr.CFG = { step = 50 } -- unités : palier de stock d'une pièce (les 50 premiers bras rapides, puis 100, 150…)
Sr.TYPES = { "inserter", "transport-belt", "assembling-machine" } -- TYPES de prototypes d'entité des pièces surveillées (jamais un nom)

local WATCHED = {}
for _, t in ipairs(Sr.TYPES) do WATCHED[t] = true end
local KIND = {} -- [item] = type de l'entité posée par l'objet, ou false (cache de session : lecture des prototypes, déterministe)

--- Identifiants des équipes dans l'ordre stable des rangs : factions vivantes (ids triés), puis « player » si votre équipe existe.
function Sr.ids()
  local ids = State.alive()
  if State.faction("player") then ids[#ids + 1] = "player" end
  return ids
end

--- L'état des réveils de l'équipe (créé au premier usage) : { wake, served, why, stock = { [item] = palier }, healthy, starved, reveils }.
function Sr.state(f)
  local st = f.team.scan
  if not st then
    st = { stock = {}, reveils = 0 }
    f.team.scan = st
  end
  st.stock = st.stock or {}
  return st
end

--- Pose le réveil `why` sur l'équipe `f` au tick `tick` ; rend vrai s'il est nouveau (faux : un réveil attendait déjà, compté).
function Sr.wake(f, tick, why)
  if not (f and f.team) then return false end
  local st = Sr.state(f)
  local new = St.wake(st, tick, why)
  if new then st.reveils = (st.reveils or 0) + 1 end
  return new
end

--- Type de l'entité posée par l'objet `item` (nil : l'objet ne pose rien). Remplaçable par les tests (aucun `game` hors jeu).
function Sr.kind_of(item)
  local ip = game.item_prototypes[item]
  local pr = ip and ip.place_result
  return pr and pr.type or nil
end

local function kind(item)
  local k = KIND[item]
  if k == nil then
    k = Sr.kind_of(item) or false
    KIND[item] = k
  end
  return k
end

--- Palier (0, 1, 2…) d'une quantité `n` pour le pas `step`.
function Sr.palier(n, step) return math.floor((n or 0) / (step or Sr.CFG.step)) end

--- (b) Palier de stock franchi à la hausse ? `stock` = { [item] = quantité } (le stock libre de la pensée). Met à jour les derniers paliers
--- (à la baisse aussi, sans réveil : un palier redescendu puis repassé compte de nouveau). Rend la liste triée des pièces qui ont monté.
function Sr.stock_crossings(st, stock)
  local names = {}
  for item in pairs(stock or {}) do names[#names + 1] = item end
  table.sort(names)
  local up = {}
  for _, item in ipairs(names) do
    if WATCHED[kind(item)] then
      local p = Sr.palier(stock[item], Sr.CFG.step)
      if p > (st.stock[item] or 0) then up[#up + 1] = item end
      st.stock[item] = p
    end
  end
  return up
end

--- (c) Transition vrai → faux de la santé du réseau électrique (f.build.sante.healthy) ; l'état lu est gardé dans st.healthy.
function Sr.energy_cut(st, healthy)
  local was = st.healthy
  if healthy ~= nil then st.healthy = healthy end
  return was == true and healthy == false
end

--- (d) Transition faux → vrai de la famine de la plaque clé ; l'état lu est gardé dans st.starved.
function Sr.resource_cut(st, starved)
  local was = st.starved
  st.starved = starved == true
  return was == false and starved == true
end

--- Branchement d'une pensée d'équipe (E6) : (b) stock, (c) énergie, (d) ressource, dans cet ordre ; chaque cause vraie pose son réveil
--- (le premier est gardé, les suivants comptés par St.wake : une seule passe). Rend la première cause posée ou nil.
function Sr.think(f, stock, tick)
  if not (f and f.team) then return nil end
  local st = Sr.state(f)
  local sv = f.build and f.build.sante
  local causes = {}
  if #Sr.stock_crossings(st, stock) > 0 then causes[#causes + 1] = "stock" end
  if Sr.energy_cut(st, sv and sv.healthy) then causes[#causes + 1] = "energie" end
  if Sr.resource_cut(st, Famine.team_starved(f, tick)) then causes[#causes + 1] = "ressource" end
  for _, why in ipairs(causes) do Sr.wake(f, tick, why) end
  return causes[1]
end

--- (a) Une recherche de la force `force` est finie : réveil « recherche » sur chaque équipe de cette force. Rend le nombre d'équipes réveillées.
function Sr.research_done(force, tick)
  if not (force and force.valid) then return 0 end
  local n = 0
  for _, id in ipairs(Sr.ids()) do
    local f = State.faction(id)
    if f and f.team and f.force == force.name and Sr.wake(f, tick, "recherche") then n = n + 1 end
  end
  return n
end

Events.on(defines.events.on_research_finished, function(e)
  Sr.research_done(e.research and e.research.force, e.tick or game.tick)
end)

return Sr
