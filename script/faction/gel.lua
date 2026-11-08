--[[
  Lot X10-GEL, cœur du runtime (fo-logs/2026-11-07_X10/L1_CRITERES.md §3.2, §3.6, §3.8). Les branchements : usines
  (script/faction/gel_usines.lua) et, plus tard, garnisons. LA règle de zone et de réveil est pure : shared/faction/gel.lua.

  Ce module donne aux branchements :
    - Gel.status(e) : le statut d'une entité ; pour une machine FIGÉE par le gel, le statut COMPTABLE (travaille, sans ingrédient,
      sortie pleine, sans combustible, épuisé...) au lieu de `disabled_by_script`. Lu par les lecteurs de décision du §3.6 ; une
      entité non figée rend e.status tel quel (gel éteint : aucun changement) ;
    - Gel.on() : réglage de carte `fo-war-gel` (vrai par défaut ; absent : vrai) ;
    - Gel.players(war) : positions des joueurs connectés de la surface de la guerre (ordre de game.connected_players) ;
    - Gel.input(f, players, army_out) : entrées de faction de la règle (causes de la cadence S10, f.cadence.base_alert compris) ;
    - Gel.spend(tick, n) : budget d'écritures `active` par tick (Gel.WRITES), partagé par les branchements ;
    - Gel.say(key, text) : journal [FO-GEL] borné (Gel.LOGS lignes par clé).
  État (global, namespace « gel ») : vstatus[unit] = statut comptable (nombre defines.entity_status) des machines figées, n_frozen,
  logs ; les branchements y gardent leur propre table (usines : `u`). Le namespace est DÉCLARÉ par script/faction/gel_etat.lua (requis
  par les branchements), pas ici : un lecteur qui ne demande que Gel.status (avant-postes, gisement, réparation, soldats...) ne tire ni
  le stockage ni ses abonnements (8/11 : suites extension_fer_moteur, rebuild_avant_poste et reparation_test, dont les doublures
  d'Events et de Storage n'ont ni on_init ni declare). Sans gel_etat, aucun état : statut du moteur, rien de figé.
]]

local FC = require("shared.faction.config")
local CC = require("script.companion.constants")

local Gel = {}

Gel.SETTING = "fo-war-gel"
Gel.WRITES = 600 -- écritures `active` au plus par tick, tous branchements confondus (réveil d'une faction : 1 à 2 ticks)
Gel.LOGS = 40    -- lignes [FO-GEL] au plus par clé (faction, sujet)

-- Accès à l'état, posé une fois au chargement par gel_etat.lua (Gel.bind_state) ; par défaut : aucun état.
local STATE = { get = function() return nil end }

--- État du lot (nil tant que le stockage n'est pas créé : on_init d'un mod ajouté à une sauvegarde passe avant notre
--- on_configuration_changed ; nil aussi sans gel_etat.lua).
function Gel.state()
  return STATE.get()
end

--- Posé par script/faction/gel_etat.lua au chargement (jamais pendant un événement).
function Gel.bind_state(fn)
  STATE.get = fn
end

--- Réglage de carte (vrai par défaut ; un réglage absent laisse le gel allumé).
function Gel.on()
  local s = settings.global[Gel.SETTING]
  return not (s ~= nil and s.value == false)
end

--- Statut d'une entité : le statut comptable si le gel la tient figée, sinon le statut du moteur.
function Gel.status(e)
  if not (e and e.valid) then return nil end -- entité invalide : nil, sans erreur (lecteurs protégés : capitalisation.lua)
  if e.active ~= false then return e.status end -- une entité active n'est pas figée par le gel (et le stockage n'est pas lu)
  local g = Gel.state() -- nil avant la création du stockage (on_init d'un mod ajouté à une sauvegarde) : statut du moteur
  if g and g.n_frozen > 0 then
    local u = e.unit_number
    local v = u and g.vstatus[u]
    if v then return v end
  end
  return e.status
end

--- L'entité est-elle figée par le gel (active = false posé par ce lot) ? Pour les lecteurs qui veulent la sauter ou ne pas faire
--- avancer une horloge de confirmation (le statut comptable reste préférable : Gel.status).
function Gel.frozen(e)
  if not (e and e.valid) or e.active ~= false then return false end
  local g = Gel.state()
  if not (g and g.n_frozen > 0) then return false end
  local u = e.unit_number
  return u ~= nil and g.vstatus[u] ~= nil
end

--- Positions des joueurs connectés de la surface `surface_index` (ordre du moteur).
function Gel.players(surface_index)
  local out = {}
  for _, p in ipairs(game.connected_players) do
    if p.valid and p.surface and p.surface.index == surface_index then
      local pos = p.position
      out[#out + 1] = { x = pos.x, y = pos.y }
    end
  end
  return out
end

--- Entrées de faction de la règle commune : les MÊMES que la cadence S10 (cadence_input de script/faction/commander.lua) ; `army_out`
--- = Commander.army_out(f), passé par l'appelant (ce fichier est requis par military.lua, que commander.lua requiert : pas de cycle).
function Gel.input(f, players, army_out)
  return { is_player = f.is_player, players = players, threatened_until = f.threatened_until, attack_t = f.attack_alert_t,
    hit_t = f.hit_t, lost_t = f.lost_t, base_alert = f.cadence and f.cadence.base_alert or nil, army_out = army_out,
    off = not Gel.on() }
end

-- Budget d'écritures du tick courant (local : remis à zéro à chaque tick, aucune donnée gardée entre deux ticks).
local budget_tick, budget_used = -1, 0

--- Réserve n écritures sur le budget du tick ; rend le nombre accordé (0 à n).
function Gel.spend(tick, n)
  if tick ~= budget_tick then budget_tick, budget_used = tick, 0 end
  local ok = math.max(0, math.min(n, Gel.WRITES - budget_used))
  budget_used = budget_used + ok
  return ok
end

--- Journal borné : au plus Gel.LOGS lignes par clé.
function Gel.say(key, text)
  local g = Gel.state()
  if not g then return end
  local n = (g.logs[key] or 0) + 1
  g.logs[key] = n
  if n <= Gel.LOGS then log("[FO-GEL] " .. text) end
end

--- Statut comptable d'une machine figée (nom d'un defines.entity_status, rendu par shared/faction/gel_compta.lua).
function Gel.set_status(e, name)
  local g = Gel.state()
  if not g then return end
  local S = defines.entity_status
  if name == "no_ingredients" and e.type == "assembling-machine" then name = "item_ingredient_shortage" end
  g.vstatus[e.unit_number] = S[name] or S.working
end

function Gel.clear_status(unit)
  local g = Gel.state()
  if g then g.vstatus[unit] = nil end
end

--- Noms des soldats des factions (prototypes/faction.lua) : les seuls que le gel des garnisons peut figer (ni robots, ni votre
--- équipe). Table de fichier : elle ne dépend que du code et des données.
Gel.SOLDIER_NAMES = {}
for _, fa in ipairs(FC.factions) do
  for _, k in ipairs(FC.soldier_order) do Gel.SOLDIER_NAMES[FC.unit_name(fa.key, k)] = true end
end

--- Noms ajoutés au filtre de on_entity_damaged du mod (script/team/reparation.lua, Q11) : les soldats des factions et le corps des PNJ,
--- triés. Un coup reçu par l'un d'eux réveille la garnison figée de son équipe au tick même (script/faction/gel_garnisons.lua).
function Gel.filter_names()
  local out = {}
  for n in next, Gel.SOLDIER_NAMES do out[#out + 1] = n end
  table.sort(out)
  out[#out + 1] = CC.BODY
  return out
end

--- Garnisons (Q10) : réveil d'un soldat figé, posé par script/faction/gel_garnisons.lua (nil sans lui).
Gel.wake_unit = nil

--- Crochet d'UNE ligne avant toute commande donnée à un soldat (script/ai3/soldats.lua, compound ; script/faction/military.lua,
--- add_member) : un soldat figé par le gel est réveillé au tick même, avant de recevoir son ordre. Deux lectures (valid, active).
function Gel.before_command(u)
  if Gel.wake_unit and u and u.valid and u.active == false then Gel.wake_unit(u, "ordre") end
end

return Gel
