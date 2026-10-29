--[[
  Lot VEILLE (essai 2, 29/10) : ÉTAT, COMPTEURS et BILANS de la reconnaissance régulière des factions (règles pures :
  shared/faction/veille.lua ; mission : script/ai3/exploration.lua, kind « explore » avec ex.veille).

  Demande du Directeur Créatif (D-24) : « elles doivent aussi faire de la reconnaissance comme un joueur ». L'essai 1 envoyait un soldat d'un
  vivier (environ 500 plaques pour 10 éclaireurs, 7,4 tourelles de moins) : parqué. Ici un OUVRIER LIBRE de la faction part à intervalle par
  la voie d'exploration d'IA3-f, sans kit ni soldat. La visée des attaques n'est pas touchée.

  Ce module tient, dans f.veille (nombres seulement) : le délai du prochain départ, le nombre de missions arrivées (rayon croissant), le
  dernier octant, les compteurs (partis, arrivés, fuites, perdus, chemins ratés, durée d'absence des ouvriers) et les refus par raison
  (une pensée de la voie d'exploration = une unité), publiés toutes les 10 min par la ligne `[FO-VEILLE] bilan`.

  Crochets posés par script/ai3/exploration.lua : Veille.known(f), Veille.pick_goal(f, tick, rayon, dernier octant).
  Bancs de mesure : remote factorio-overhaul / veille_options { on = false } éteint la veille (témoin sur la MÊME source).
]]

local V = require("shared.faction.veille")
local Character = require("script.faction.character")

local Veille = {}

local REPORT_EVERY = 10 * 3600

Veille.on = true -- bancs de mesure SEULEMENT : témoin sans veille, même source
Veille.known = nil
Veille.pick_goal = nil

function Veille.state(f)
  if not f.veille then
    f.veille = { next_at = V.START, trips = 0, last_oct = -1, sent = 0, arrived = 0, fled = 0, lost = 0, nopath = 0, other = 0, away = 0,
      refus = {}, last_report = 0 }
  end
  return f.veille
end

--- La veille est-elle allumée ? (bancs de mesure : éteinte pour le témoin)
function Veille.enabled() return Veille.on end

--- Un refus, compté par raison.
function Veille.refuse(f, reason)
  if not Veille.on then return end
  local vs = Veille.state(f)
  vs.refus[reason] = (vs.refus[reason] or 0) + 1
end

--- Une mission de veille part (un ouvrier libre).
function Veille.on_start(f, tick)
  local vs = Veille.state(f)
  local ch = Character.of(f)
  vs.sent = vs.sent + 1
  vs.next_at = tick + V.interval(ch.traits and ch.traits.curiosite, (f.chef and f.chef.last_threat) or 0)
  f.stats.veille_scouts = (f.stats.veille_scouts or 0) + 1
  log(string.format("[FO-VEILLE] depart tick %d %s : ouvrier libre, mission %d, rayon %d, prochain depart dans %d min", tick, f.key, vs.sent,
    V.radius(vs.trips), math.floor((vs.next_at - tick) / 3600)))
end

--- Le but est choisi (première surveillance de la mission).
function Veille.on_goal(f, tick, g, radius)
  log(string.format("[FO-VEILLE] but tick %d %s : secteur (%d, %d), octant %d, %d tuiles du QG, rayon %d, %d candidat(s)", tick, f.key,
    math.floor(g.x), math.floor(g.y), g.octant, math.floor(g.dh), radius, g.n or 0))
end

--- Fin d'une mission de veille : `why` = fini (but vu), fuite, perdu, chemin, rien, duree, danger. Le rayon grandit quand le but est vu
--- ou qu'il n'y avait plus de but dans la bande ; une fuite ou un chemin raté garde le rayon (le secteur est écarté par la carte).
function Veille.on_end(f, tick, duration, why)
  local vs = Veille.state(f)
  vs.away = vs.away + duration
  if why == "fini" then
    vs.trips = vs.trips + 1
    vs.arrived = vs.arrived + 1
  elseif why == "rien" then
    vs.trips = vs.trips + 1
    Veille.refuse(f, "aucun secteur")
  elseif why == "fuite" then
    vs.fled = vs.fled + 1
  elseif why == "perdu" then
    vs.lost = vs.lost + 1
    f.stats.veille_lost = (f.stats.veille_lost or 0) + 1
    -- Un ouvrier perdu : délai doublé avant la prochaine veille.
    vs.next_at = math.max(vs.next_at, tick + 2 * V.interval(nil, 0))
  elseif why == "chemin" then
    vs.nopath = vs.nopath + 1
  else
    vs.other = vs.other + 1
  end
  log(string.format("[FO-VEILLE] fin tick %d %s : %s apres %.1f min, rayon suivant %d", tick, f.key, why, duration / 3600,
    V.radius(vs.trips)))
end

--- Bilan toutes les 10 min par faction (appelé par le commandant à chaque pensée ; une ligne par période). Publié aussi veille éteinte
--- (témoin) : le relevé de secteurs reconnus est le même.
function Veille.report(f, tick)
  local vs = Veille.state(f)
  if tick - vs.last_report < REPORT_EVERY then return end
  vs.last_report = tick
  local keys = {}
  for r in pairs(vs.refus) do keys[#keys + 1] = r end
  table.sort(keys)
  local parts = {}
  for _, r in ipairs(keys) do parts[#parts + 1] = r:gsub(" ", "_") .. "=" .. vs.refus[r] end
  log(string.format("[FO-VEILLE] bilan tick %d %s minute %d : partis %d, arrives %d, fuites %d, perdus %d, chemins %d, autres %d, "
    .. "ouvrier absent %.1f min, rayon %d, secteurs reconnus %s, veille %s, refus {%s}", tick, f.key, math.floor(tick / 3600), vs.sent,
    vs.arrived, vs.fled, vs.lost, vs.nopath, vs.other, vs.away / 3600, V.radius(vs.trips),
    tostring(Veille.known and Veille.known(f) or "?"), Veille.on and "allumee" or "eteinte", table.concat(parts, " ")))
end

return Veille
