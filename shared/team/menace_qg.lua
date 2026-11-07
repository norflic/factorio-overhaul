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
    - BORNE : entre 48 et 64 tuiles, le maintien ne dure que si une unité est revenue sous 48 tuiles dans les Mq.HOLD_THINKS (6)
      dernières pensées ; sinon, sortie à cette pensée.
  Recherches du moteur : une par pensée hors menace (rayon 48) ; en menace, une à 48, plus une à 64 seulement si rien n'est à 48
  (Mq.needs_outer).
  Mesure codée pour H.update_haut(st, niveau, 1, 1, ...) : niveau 2 = unité vue au rayon d'entrée (hors menace), 1 = unité qui tient la
  menace (en menace), 0 = rien (ou borne échue).
  Déterminisme : aucune table parcourue, aucun hasard, aucun temps mesuré ; la cadence est celle de la pensée (ticks de jeu).
]]

local H = require("shared.ai3.hysteresis")

local Mq = {}

Mq.EXIT_RADIUS = 64  -- tuiles : la menace dure tant qu'une unité reste à cette distance du coffre
Mq.EXIT_THINKS = 2   -- pensées de suite sans unité à Mq.EXIT_RADIUS avant la sortie
-- BORNE du maintien (acceptation du lead, 7/11 vers 17 h : « le DC veut ses 12 ouvriers ») : entre r_in et Mq.EXIT_RADIUS, la menace ne
-- dure que si une unité est revenue sous r_in au moins une fois dans les Mq.HOLD_THINKS dernières pensées ; sinon, sortie. Sans elle, un
-- nid entre 48 et 64 tuiles du coffre tenait la menace ouverte sans fin (fond coupé, toute l'équipe au coffre, recrues retenues).
Mq.HOLD_THINKS = 6   -- pensées (30 s à 300 ticks la pensée) : donnée, non mesurée en partie

function Mq.new() local st = H.new() st.since_in = 0 return st end

--- Faut-il sonder aussi le rayon de sortie à cette pensée ? Seulement en menace et sans unité au rayon d'entrée.
function Mq.needs_outer(st, found_in)
  return (st and st.crise and not found_in) and true or false
end

--- Une pensée. found_in = une unité ennemie à r_in tuiles ou moins ; found_out = une unité à Mq.EXIT_RADIUS ou moins (lu seulement
--- quand Mq.needs_outer le demande ; sinon found_out = found_in) ; armed = le QG a une tourelle armée. Rend (menace, evenement de H).
function Mq.update(st, found_in, found_out, armed)
  st.since_in = st.since_in or 0
  local lvl, opts = 0, { sortie_n = Mq.EXIT_THINKS }
  if found_in then
    lvl = st.crise and 1 or 2
    st.since_in = 0
  elseif st.crise then
    st.since_in = st.since_in + 1
    if found_out then
      if st.since_in >= Mq.HOLD_THINKS then opts = { sortie_n = 1 } -- borne échue : sortie à cette pensée
      else lvl = 1 end
    end
  end
  local _, ev = H.update_haut(st, lvl, 1, 1, armed and true or false, opts)
  if not st.crise then st.since_in = 0 end
  return st.crise, ev
end

Mq.describe = H.describe

return Mq
