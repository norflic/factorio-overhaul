--[[
  JETONS DE TRAVAIL GLOBAUX (lot IA1-b, docs/EQUIPES_PNJ.md §12, O.share_tokens) : un budget d'unités de travail
  PAR TICK POUR TOUT LE MOD (O.TICK_BUDGET = 400), partagé à tour de rôle entre les équipes vivantes (factions dans
  l'ordre de leurs id, puis votre équipe ; l'équipe servie la première tourne à chaque tick). Une opération coûteuse
  d'une équipe (aujourd'hui : une prise de tâche, qui construit le programme de l'ouvrier ; demain : fantômes,
  nœuds d'A*, évaluations de lots, lots IA1-d et IA1-e2) demande ses unités ; refusée, elle attend la pensée
  suivante du PNJ.
  Le registre n'est valable que pour le tick en cours (remis à zéro au premier appel d'un tick) : il n'a pas à être
  sauvegardé, et un client qui rejoint la partie entre deux ticks calcule les mêmes parts que le serveur.
  Coûts : estimations (R4 non étalonné, docs §21) ; refus comptés par équipe (f.team.org.stats.token_refused).
]]

local O = require("shared.team.org")
local State = require("script.faction.state")

local Tokens = {}

Tokens.COST_CLAIM = 20 -- une prise de tâche (programme d'étapes, recherche de minerai comprise) : estimé

local ledger = { tick = -1, used = {}, grant = nil, big = nil }

local function team_keys()
  local keys = {}
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and f.team then keys[#keys + 1] = f.key or id end
  end
  local p = State.faction("player")
  if p and p.team then keys[#keys + 1] = "player" end
  return keys
end

--- Prend `units` jetons pour l'équipe `f` au tick `tick`. Rend vrai si la part de l'équipe le permet.
function Tokens.take(f, tick, units)
  if ledger.tick ~= tick then
    ledger.tick, ledger.used, ledger.grant, ledger.big = tick, {}, nil, nil
  end
  if not ledger.grant then
    local keys = team_keys()
    local demands = {}
    for i = 1, #keys do demands[i] = O.TICK_BUDGET end
    local g = #keys > 0 and O.share_tokens(O.TICK_BUDGET, demands, tick % #keys + 1) or {}
    ledger.grant = {}
    for i, k in ipairs(keys) do ledger.grant[k] = g[i] end
  end
  local k = f.is_player and "player" or (f.key or f.id)
  local used = ledger.used[k] or 0
  local grant = ledger.grant[k]
  if grant == nil then grant = O.TICK_BUDGET end -- équipe inconnue du partage (fondée pendant ce tick)
  -- Lot IA3-e : une opération plus chère que la part d'une équipe (plan d'un module 200, poteau ravivé 300, contre 100
  -- par équipe à 4 factions) ne passait JAMAIS : chantiers des factions figés (moteur simulé, sonde du 27/10 : PNJ
  -- arrêtés au point d'appui avec leurs poteaux). Elle passe si l'équipe n'a encore rien pris à ce tick et qu'aucune
  -- autre grosse opération n'a eu lieu à ce tick (une seule pour tout le mod, dans la limite du budget du mod).
  if units > grant and used == 0 and ledger.big == nil and units <= O.TICK_BUDGET then
    ledger.used[k] = units
    ledger.big = k
    return true
  end
  if used + units > grant then
    if f.team and f.team.org then f.team.org.stats.token_refused = f.team.org.stats.token_refused + 1 end
    return false
  end
  ledger.used[k] = used + units
  return true
end

return Tokens
