--[[
  FAMINE-FER, partie moteur (règle pure : shared/team/famine_cle.lua). Lit l'état de la migration de l'avant-poste (f.migration), l'état du projet de sa
  bande (f.build) et le manque de sa matière par rapport au besoin (f.team.ia3.starved, écrit par la pensée) ; ne modifie rien.
  Lecteurs : script/faction/outposts.lua (Outposts.extend : l'extension thermique reste permise), script/team/team.lua (la vue de l'équipe ne
  marque pas l'avant-poste « plein » : le cerveau peut lui commander l'extension).
]]
local T = require("shared.team.config")
local Fam = require("shared.team.famine_cle")
local Rs = require("shared.ai3.reserve") -- 0.6.75 : le besoin évalué (noyau, écrit par la pensée) : la plaque clé qui manque aux projets en réserve

local Famine = {}

--- La plaque clé manque-t-elle ? Deux grandeurs, une seule question : le manque de la pensée (f.team.ia3.starved) OU le manque du besoin
--- évalué (noyau.missing : ce que la bande en « reserve:materiaux », la défense et les recrues attendent et que le stock ne couvre pas).
--- 0.6.75 : sans la seconde, la famine se refermait à 27 min (graine 1618033988) avec 887 plaques manquantes au noyau.
local function key_missing(f, spec, tick)
  local ia3 = f.team and f.team.ia3
  local sv = ia3 and ia3.starved
  local starved = sv ~= nil and (sv[spec.product] == true or sv[spec.resource] == true)
  local t = tick or (game and game.tick) or 0
  local rin = ia3 and Rs.input(ia3.noyau, t)
  local missing = rin and rin.missing and (rin.missing[spec.product] or 0) or 0
  return starved, missing
end

--- L'extension thermique de l'avant-poste `o` (plaque clé seulement) reste-t-elle permise malgré sa migration en cours ?
local IDLE_STATES = { plan = true, reserve = true, attente = true, demande = true } -- (avant tout fantôme posé)
--- 0.7.114 (F678) : la bande migrée de l'avant-poste `o` n'a-t-elle encore RIEN bâti (projet en attente de sa matière) ? Rend vrai/faux, bâties.
local function band_idle(f, o)
  local ms = f.migration
  local st = ms and ms.o and ms.o[o.id]
  local p = st and st.pid and f.build and f.build.projects and f.build.projects[st.pid]
  local built = 0
  for _, e in ipairs(p and p.ents or {}) do if e.built then built = built + 1 end end
  return p ~= nil and built == 0 and IDLE_STATES[p.state or ""] == true, built, p, st
end

function Famine.open(f, o, tick)
  if not (f and o and o.migr == "en cours") then return false end
  local spec = T.outposts[o.kind]
  -- 0.7.114 (F678, cause de l'amorçage lent) : une bande demandée gelait l'avant-poste ET tout son gisement dès la demande (o.full, extension
  -- thermique et remplacement sur place coupés) alors qu'elle attendait sa matière 10 à 20 min (banc JALONS30 : thermiques figées de 18,9 à
  -- 30 min, fours à vide) : tant que la bande n'a rien bâti, l'avant-poste continue de croître, toute ressource, famine ou non. Les tuiles du
  -- plan de la bande sont réservées (PlacesQG.is_reserved, Build.reserved_entity) : aucune paire ne se pose sur son emprise.
  local idle, built, p, st = band_idle(f, o)
  if idle then return true end
  if not (spec and spec.product == T.outposts.iron.product) then return false end
  local starved, missing = key_missing(f, spec, tick)
  -- s43 regr-fer2 : ticks sans progrès de la bande (suivi du retour en arrière, st.pg = { built, since }, écrit par script/team/migration_champ.lua)
  local t = tick or (game and game.tick) or 0
  local stalled = (st and st.pg and st.pg.since) and math.max(0, t - st.pg.since) or 0
  return Fam.open({ starved = starved, missing = missing, migr = o.migr, built = built, project = p and p.state, stalled = stalled })
end

--- Lot FORCE-0674 : l'avant-poste `o` produit-il la plaque clé, et cette matière manque-t-elle ? (lu par Planner.no_go par la vue)
function Famine.key_starved(f, o, tick)
  local spec = f and o and T.outposts[o.kind]
  if not (spec and spec.product == T.outposts.iron.product) then return false end
  local starved, missing = key_missing(f, spec, tick)
  return starved or missing > 0
end

--- Lot CRAFT-ROLE : la plaque clé manque-t-elle à l'ÉQUIPE (même question, sans avant-poste) ? Lu par la place de marché
--- (script/team/board.lua, market_npc) : en famine, le plafond de fabrications en arrière-plan ne retient plus une fabrication libre.
function Famine.team_starved(f, tick)
  if not (f and f.team) then return false end
  local starved, missing = key_missing(f, T.outposts.iron, tick)
  return starved or missing > 0
end

Famine.band_idle = function(f, o) return (band_idle(f, o)) end -- (lu par script/team/foreuse_swap.lua)

return Famine
