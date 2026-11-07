--[[
  Lot L12, partie 3 : runtime de la MENACE TENUE d'une équipe (règle pure : shared/team/menace_equipe.lua). Décision du lead (7/11 vers
  18 h 25) : un état SÉPARÉ, lu SEULEMENT par la décision de capitalisation ; f.threatened_until et view.threatened ne changent pas (leurs
  16 lecteurs : fo-logs/2026-11-07_VIDEO-AUTOMATISATION/PLAN_L12C.md, à étendre lecteur par lecteur, chacun mesuré).
  Appelé UNE fois par pensée par Team.view (script/team/team.lua), factions et votre équipe ; rend view.threat_held.
  Lit : f.threat_loss_t (tick de la dernière perte près du QG, écrit par script/faction/commander.lua à côté de f.threatened_until) et les
  tourelles armées du QG (dernier recensement frais de la prévision, Prev.qg_view, comme MenaceQg).
  Écrit : f.threat_held (état de la règle : nombres et booléens ; absent d'une ancienne sauvegarde : état neuf). Rien d'autre.
  Journal : [FO-MENACE] à l'entrée, à la sortie (cause : « calme + tourelles » ou « plafond ») et à chaque nouvelle perte pendant la menace.
]]

local Me = require("shared.team.menace_equipe")
local Prev = require("script.ai3.prevision")

local MenaceEq = {}

MenaceEq.FRESH = 3 * 3600 -- ticks : recensement du QG encore valable (comme SurvieQg.FRESH, script/team/survie_qg.lua:26)
MenaceEq.LOGS = 200       -- lignes [FO-MENACE] au plus par équipe

local function armed_of(f, tick)
  local v = Prev.qg_view(f)
  local q = v and v.qg
  if q and tick - (q.tick or 0) <= MenaceEq.FRESH then return (q.armed or 0) > 0 or (q.ammo or 0) > 0 end
  return false
end

--- Une pensée : rend vrai si la menace de l'équipe est TENUE (règle de shared/team/menace_equipe.lua).
function MenaceEq.observe(f, tick)
  local st = f.threat_held
  if not st then st = Me.new() f.threat_held = st end
  local armed = armed_of(f, tick)
  local on, ev, cause = Me.update(st, { tick = tick, loss_t = f.threat_loss_t, armed = armed })
  if ev then
    st.logs = (st.logs or 0) + 1
    if st.logs <= MenaceEq.LOGS then
      log(string.format("[FO-MENACE] %s : %s a %.1f min : %s (derniere perte il y a %.0f s, QG %s) ; %s",
        tostring(f.key or (f.is_player and "player") or "?"),
        (ev == "entree" and "MENACE TENUE") or (ev == "sortie" and "menace levee") or "nouvelle perte", tick / 3600, tostring(cause),
        (tick - (st.loss_t or tick)) / 60, armed and "defendu (tourelle armee ou chargeurs)" or "sans tourelle armee", Me.describe(st)))
    end
  end
  return on
end

return MenaceEq
