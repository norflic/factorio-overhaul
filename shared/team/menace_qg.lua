--[[
  Lot L12, partie 1 (feuille de route « Factorio Automated », fo-logs/2026-11-07_VIDEO-AUTOMATISATION/PLAN_L6_L10_L12.md §3.3, point 1) :
  HYSTÉRÉSIS DE LA MENACE SUR LE QG (`hq_threat`, script/team/team.lua, Team.view). Règle PURE (aucune API, aucun nom d'objet) ; elle
  s'appuie sur la règle générique shared/ai3/hysteresis.lua (H). Testée hors jeu : tests/menace_qg_test.lua.

  Avant (0.6.58, lu) : `hq_threat` = « au moins une unité ennemie à moins de T.hq_threat_radius (48) tuiles du coffre » à CETTE pensée ;
  seuil unique, sans mémoire : un biter qui fait des allers-retours autour de 48 tuiles allumait et éteignait à chaque pensée la garde de
  toute l'équipe (script/team/poles.lua, fond coupé), la retenue des recrues (QGSURVIE, script/team/survie_qg.lua) et R0 « qg »
  (shared/ai3/pile.lua:433).

  Règle :
    - ENTRÉE : une unité ennemie à moins de `r_in` (T.hq_threat_radius = 48) tuiles du coffre ;
    - MAINTIEN : tant qu'une unité reste à moins de Mq.EXIT_RADIUS (64) tuiles, la menace dure ;
    - SORTIE : plus aucune unité à moins de 64 tuiles pendant Mq.EXIT_THINKS (2) pensées DE SUITE (600 ticks à 300 ticks la pensée) ;
    - BESOIN (verrou de H) : vrai dès l'entrée, levé à la première pensée qui SUIT l'entrée où le QG a une tourelle armée (`armed`) ; journal seulement,
      aucune décision ne le lit dans cette partie.
  Une seule recherche par pensée : le rayon sondé dépend de l'état (Mq.probe_radius) : 48 hors menace, 64 en menace.
  Mesure codée pour H.update_haut(st, niveau, 1, 1, ...) : niveau 2 = unité vue au rayon d'entrée (hors menace), 1 = unité vue au rayon
  de sortie (en menace), 0 = rien.
  Déterminisme : aucune table parcourue, aucun hasard, aucun temps mesuré ; la cadence est celle de la pensée (ticks de jeu).
]]

local H = require("shared.ai3.hysteresis")

local Mq = {}

Mq.EXIT_RADIUS = 64  -- tuiles : la menace dure tant qu'une unité reste à cette distance du coffre
Mq.EXIT_THINKS = 2   -- pensées de suite sans unité à Mq.EXIT_RADIUS avant la sortie

function Mq.new() return H.new() end

--- Rayon à sonder à cette pensée : r_in hors menace, max(r_in, Mq.EXIT_RADIUS) en menace.
function Mq.probe_radius(st, r_in)
  if st and st.crise then return math.max(r_in, Mq.EXIT_RADIUS) end
  return r_in
end

--- Une pensée. found = une unité ennemie a été vue au rayon de Mq.probe_radius ; armed = le QG a une tourelle armée. Rend
--- (menace, evenement de H).
function Mq.update(st, found, armed)
  local lvl = 0
  if found then lvl = st.crise and 1 or 2 end
  local _, ev = H.update_haut(st, lvl, 1, 1, armed and true or false, { sortie_n = Mq.EXIT_THINKS })
  return st.crise, ev
end

Mq.describe = H.describe

return Mq
