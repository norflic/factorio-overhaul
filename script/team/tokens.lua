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
--- Lot CC-PLAN-FIGE (F512) : ordre de service des équipes d'une passe périodique (O.serve_order) : le premier servi tourne à chaque passe,
--- et avec lui le gros jeton du tick (ci-dessous, une seule grosse opération pour tout le mod, au premier demandeur).
Tokens.serve_order = O.serve_order

local ledger = { tick = -1, used = {}, grant = nil, big = nil, pose = {} }

local function reset(tick)
  if ledger.tick ~= tick then
    ledger.tick, ledger.used, ledger.grant, ledger.big, ledger.pose = tick, {}, nil, nil, {}
  end
end

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
  reset(tick)
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

--- Lot JETONS (13/11/2026) : jetons de POSE, pour la pièce qu'un PNJ ravive sur un chantier déjà approvisionné (Build.work, mode « build »).
--- Maillon : la part d'une équipe dans Tokens.take est O.TICK_BUDGET / nombre d'équipes (400 / 4 = 100 au banc, 400 / 5 = 80 dans la partie
--- du DC, dont l'équipe du joueur compte), alors que le quota de pose est PAR PENSÉE de PNJ (Build.REVIVE_PER_THINK pièces, 6 × 50 = 300) :
--- deux échelles pour une grandeur. À 5 équipes une pensée posait 1 pièce sur 6 (2 à 4 équipes), le PNJ restait sur le chantier le sac plein
--- (banc partie-reelle-120 : 1 400 à 2 300 pensées sans jeton par équipe, pose = 32 à 37 % du temps des tâches).
--- La pose a donc sa part propre, PAR ÉQUIPE et par tick, qui ne dépend pas du nombre d'équipes : `per_think`, le coût d'une pensée de pose
--- entière (donné par l'appelant : Build.REVIVE_PER_THINK × Build.COST_REVIVE). Au plus une pensée de pose pleine par équipe et par tick :
--- la borne des UPS reste (le nombre total de pièces posées est borné par la matière apportée, seule leur cadence change).
--- Les unités prises sont aussi DÉBITÉES de la part commune de l'équipe à ce tick (plans, fantômes, évaluations passent après, ou au tick
--- suivant) : la pose n'est plus refusée par la part commune, mais elle la consomme comme avant.
function Tokens.take_pose(f, tick, units, per_think)
  reset(tick)
  local k = f.is_player and "player" or (f.key or f.id)
  local used = ledger.pose[k] or 0
  if used + units > per_think then
    if f.team and f.team.org then f.team.org.stats.token_refused = f.team.org.stats.token_refused + 1 end
    return false
  end
  ledger.pose[k] = used + units
  ledger.used[k] = (ledger.used[k] or 0) + units
  return true
end

return Tokens
