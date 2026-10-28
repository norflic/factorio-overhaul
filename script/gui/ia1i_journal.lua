--[[
  Journal de l'interface « Équipe et factions » (lot IA1-i) : une fois par seconde, un RELEVÉ de l'état (nombres et
  chaînes : effectif, recrues, pertes, avant-postes, objectif, recherche, orientation de votre équipe ; guerre et
  relation de chaque faction avec vous) est comparé au précédent (shared/gui/ia1i.lua, M.journal_diff) ; les
  différences deviennent des entrées datées, les 20 dernières gardées.

  Lecture seule de l'état du jeu : rien ici ne décide ni ne change le comportement des équipes ou des factions. Le
  relevé tourne même fenêtre fermée (sinon le journal aurait des trous) ; son coût est celui de quelques lectures de
  champs. Il tourne dans un gestionnaire d'événement (on_nth_tick), donc chez tous les joueurs au même tick :
  le journal (dans `global`, espace « ia1i ») est identique partout.
  Premier relevé (partie neuve ou sauvegarde d'avant le lot) : aucune entrée, pour ne pas inonder le journal.
]]

local Storage = require("script.core.storage")
local State = require("script.faction.state")
local Team = require("script.team.team")
local Poles = require("script.team.poles")
local M = require("shared.gui.ia1i")

local Journal = {}

-- ui : état de la fenêtre par joueur { tab, confirm } ; journal : entrées { tick, kind, a, b, c } ; snap : dernier relevé ;
-- refreshes : contenus d'onglet reconstruits (mesure : aucun quand toutes les fenêtres sont fermées).
Storage.declare("ia1i", function() return { ui = {}, journal = {}, snap = nil, refreshes = 0, panel = { rings = {} } } end)

function Journal.ns() return Storage.ns("ia1i") end

local function team_snap()
  local f = State.faction("player")
  if not (f and f.hq and f.hq.valid and f.team) then return nil end
  local st = f.stats or {}
  local o = Poles.orientation(f)
  return {
    n = f.engineers_count or 0, max = Team.npc_max(f), recruited = st.recruited or 0, lost = st.engineers_lost or 0,
    built = st.outposts_built or 0, outposts_lost = st.outposts_lost or 0, goal = f.team.goal, tech = f.tech or 0,
    orientation = M.current_preset(o),
  }
end

local function war_snap()
  local war = State.war()
  local out = { active = war.active and true or false, factions = {} }
  if not war.active then return out end
  for _, id in ipairs(State.sorted_keys(war.factions)) do
    local f = war.factions[id]
    out.factions[#out.factions + 1] = { key = f.key, declared = (f.pvp and f.pvp.declared) and true or false,
      eliminated = f.eliminated and true or false }
  end
  return out
end

function Journal.snapshot()
  return { team = team_snap(), war = war_snap() }
end

--- Relève l'état et ajoute les différences au journal (appelé une fois par seconde par la fenêtre).
function Journal.sample(tick)
  local ns = Journal.ns()
  if not ns then return end
  local cur = Journal.snapshot()
  if ns.snap then M.journal_push(ns.journal, M.journal_diff(ns.snap, cur), tick) end
  ns.snap = cur
end

--- Entrées, de la plus récente à la plus ancienne, au plus n.
function Journal.recent(n)
  local ns = Journal.ns()
  local out = {}
  if not ns then return out end
  local j = ns.journal
  for i = #j, math.max(1, #j - n + 1), -1 do out[#out + 1] = j[i] end
  return out
end

local function faction_name(key) return { "fo-faction.name-" .. tostring(key) } end
local function preset_name(p) return { "fo-ia1i.preset-" .. tostring(p) } end

--- Texte localisé d'une entrée.
function Journal.text(e)
  local k = e.kind
  local body
  if k == "goal" then
    body = { "fo-ia1i.j-goal", { "fo-team.goal-" .. tostring(e.a) } }
  elseif k == "orientation" then
    body = { "fo-ia1i.j-orientation", preset_name(e.a) }
  elseif k == "declared" or k == "truce" or k == "eliminated" then
    body = { "fo-ia1i.j-" .. k, faction_name(e.a) }
  else
    body = { "fo-ia1i.j-" .. k, tostring(e.a or ""), tostring(e.b or ""), tostring(e.c or "") }
  end
  return { "fo-ia1i.j-line", M.clock(e.tick), body }
end

return Journal
