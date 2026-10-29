--[[
  Journal d'époque (piste SCENARIOS, nuit du 29 au 30/10) : règles PURES, testables hors jeu (tests/scenario_test.lua).
  Design : docs/SCENARIOS_DESIGN.md §3.

  Ce que le joueur lit à chaque époque k (1 à 15) :
    - le Codex k (textes du scénario approuvé X0, shared/content/epochs.lua ; clés fo-journal.codex-k) ;
    - les OBJECTIFS de l'époque, tous DÉRIVÉS des données du jeu (aucune liste de noms écrite ici) :
        centre  : passer le centre à l'époque k+1, coût exact L.cost (absent à l'époque 15) ;
        cap     : plafond des bâtiments, L.building_cap(k) ;
        resource: les gisements de l'époque : ressource d'exploration du jalon X0 et ressources garanties de
                  shared/content/world.lua (W.resources[clé].epoch == k, dans l'ordre W.resource_order), filtrées par un prédicat `exists` (le
                  prototype doit exister en jeu : la fumerolle, la galène… prévues par X0 n'apparaissent pas) ;
        chart   : cartographier N chunks (jalon d'exploration X0, s'il en a un) ;
        gate    : la Porte (époque 15 seulement ; « à venir » tant qu'elle n'existe pas) ;
        threat  : la menace de l'époque (clé fo-journal.threat-k).
  Annonce : une force annonce l'époque k la PREMIÈRE fois que son centre l'atteint ; jamais deux fois ; un centre
  qui redescend (détruit, reconstruit) ne rejoue rien ; un saut de plusieurs époques n'annonce que la dernière.
  Aucun effet sur l'équilibre : rien n'est donné, rien n'est exigé.
]]

local L = require("shared.levels.config")
local X = require("shared.content.epochs")
local W = require("shared.content.world")

local J = {}

J.MAX = 15
J.LOCALE = "fo-journal"
J.KINDS = { "centre", "cap", "resource", "chart", "gate", "threat" }

local CC = L.by_key.command

--- Acte de l'époque k (1 à 4), lu dans X.acts.
function J.act_of(k)
  for _, a in ipairs(X.acts) do
    if k >= a.epochs[1] and k <= a.epochs[2] then return a.n end
  end
  return nil
end

--- Clé de l'époque k pour son nom (fo-epochs.name-<clé>), celle des niveaux (L.epochs).
function J.epoch_key(k)
  local e = L.epochs[k]
  return e and e.key or nil
end

--- Ressources candidates de l'époque k, dans l'ordre : jalon X0 d'abord, puis garanties de world.lua. Sans doublon.
function J.resource_candidates(k)
  local out, seen = {}, {}
  local function add(name)
    if name and not seen[name] then seen[name] = true; out[#out + 1] = name end
  end
  local ep = X.epochs[k]
  local ex = ep and ep.milestones and ep.milestones.exploration
  if ex and ex.resource then add(ex.resource) end
  for _, key in ipairs(W.resource_order) do -- W.resources est indexé par clé : on suit l'ordre écrit (déterminisme)
    local r = W.resources[key]
    if r and r.epoch == k then add(r.resource) end
  end
  return out
end

--- Cible de cartographie (chunks) de l'époque k, ou nil.
function J.chart_target(k)
  local ep = X.epochs[k]
  local ex = ep and ep.milestones and ep.milestones.exploration
  return ex and ex.chart or nil
end

--- Objectifs de l'époque k : liste ordonnée d'enregistrements { kind = …, … }. `exists(nom)` dit si un prototype
--- de ressource existe en jeu (nil : tout existe, pour les tests).
function J.objectives(k, exists)
  assert(type(k) == "number" and k >= 1 and k <= J.MAX, "époque hors bornes")
  local out = {}
  if k < J.MAX then
    out[#out + 1] = { kind = "centre", target = k + 1, cost = L.cost(CC, k + 1) }
  end
  out[#out + 1] = { kind = "cap", level = L.building_cap(k) }
  for _, name in ipairs(J.resource_candidates(k)) do
    if exists == nil or exists(name) then out[#out + 1] = { kind = "resource", name = name } end
  end
  local chart = J.chart_target(k)
  if chart then out[#out + 1] = { kind = "chart", chunks = chart } end
  if k == J.MAX then out[#out + 1] = { kind = "gate" } end
  out[#out + 1] = { kind = "threat", epoch = k }
  return out
end

--- Annonce : `reached` = plus haute époque déjà annoncée pour la force (0 ou nil : aucune) ; `level` = époque
--- actuelle de son centre (0 : pas de centre, ou épave). Renvoie (époque à annoncer ou nil, nouveau `reached`).
function J.decide(reached, level)
  reached = reached or 0
  level = level or 0
  if level > J.MAX then level = J.MAX end
  if level > reached then return level, level end
  return nil, reached
end

--- Époque à afficher pour /fo-journal [k] : `arg` (texte de la commande, peut être nil), `reached`. Renvoie
--- (époque, nil) ou (nil, raison) : "none" (aucune époque atteinte), "invalid", "not-reached".
function J.pick(arg, reached)
  reached = reached or 0
  if arg == nil or arg:match("^%s*$") then
    if reached < 1 then return nil, "none" end
    return reached, nil
  end
  local n = tonumber(arg:match("^%s*(%d+)%s*$") or "")
  if not n or n < 1 or n > J.MAX then return nil, "invalid" end
  if n > reached then return nil, "not-reached" end
  return n, nil
end

--- Clés de locale (section fo-journal) qu'utilise le journal pour l'époque k : codex, menace, acte.
function J.keys_of(k)
  return { "codex-" .. k, "threat-" .. k, "act-" .. J.act_of(k) }
end

return J
