--[[
  Lot L12, partie 1 : runtime de l'hystérésis de la menace sur le QG (règle pure : shared/team/menace_qg.lua). Appelé UNE fois par pensée
  par Team.view (script/team/team.lua, votre équipe seulement, comme avant). Lit : un comptage d'unités ennemies autour du coffre (un seul
  appel du moteur par pensée, rayon selon l'état) et les tourelles armées du QG (dernier recensement de la prévision, Prev.qg_view,
  frais : SurvieQg.FRESH comme la retenue des recrues). Écrit : f.team.hq_menace (état de H : nombres et booléens, vit dans la
  sauvegarde ; absent d'une ancienne sauvegarde : état neuf). Journal : [FO-QG-MENACE] à l'entrée et à la sortie.
]]

local T = require("shared.team.config")
local Mq = require("shared.team.menace_qg")
local Prev = require("script.ai3.prevision")

local MenaceQg = {}

MenaceQg.FRESH = 3 * 3600 -- ticks : recensement du QG encore valable (comme SurvieQg.FRESH, script/team/survie_qg.lua:26)

--- Tourelles armées du QG au dernier recensement frais (0 sans recensement).
local function armed_of(f, tick)
  local v = Prev.qg_view(f)
  if v and v.qg and tick - (v.qg.tick or 0) <= MenaceQg.FRESH then return v.qg.armed or 0 end
  return 0
end

--- Une pensée : rend vrai si le QG est menacé (hystérésis). f.hq doit être valide (l'appelant le vérifie).
function MenaceQg.observe(f, tick)
  local st = f.team.hq_menace
  if not st then st = Mq.new() f.team.hq_menace = st end
  local surface = f.hq.surface
  local found_in = surface.count_entities_filtered({ position = f.hq_pos, radius = T.hq_threat_radius, force = "enemy", type = "unit",
    limit = 1 }) > 0
  local found_out = found_in
  if Mq.needs_outer(st, found_in) then
    found_out = surface.count_entities_filtered({ position = f.hq_pos, radius = Mq.EXIT_RADIUS, force = "enemy", type = "unit",
      limit = 1 }) > 0
  end
  local since = st.since_in or 0
  local on, ev = Mq.update(st, found_in, found_out, armed_of(f, tick) > 0)
  if ev == "entree" or ev == "sortie" then
    log(string.format("[FO-QG-MENACE] %s : %s a %.1f min%s ; %s", tostring(f.key or (f.is_player and "player") or "?"),
      ev == "entree" and "QG MENACE" or "menace levee", tick / 3600,
      (ev == "sortie" and found_out) and string.format(" (borne : aucune unite sous %d tuiles depuis %d pensee(s))", T.hq_threat_radius, since + 1) or "",
      Mq.describe(st)))
  end
  return on
end

return MenaceQg
