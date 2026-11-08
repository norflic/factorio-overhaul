--[[
  Lot L12, partie 3 (décisions du lead, 7/11 vers 18 h 15 puis 18 h 25 : choix (b) avec un plafond, dans un état SÉPARÉ) : la MENACE TENUE
  d'une équipe (factions et votre équipe), f.threat_held, exposée en view.threat_held et lue SEULEMENT par la décision de capitalisation
  (script/ai3/capitalisation.lua, build_input). f.threatened_until et view.threatened (16 lecteurs) ne changent pas. Règle PURE (aucune
  API, aucun nom d'objet), sur la règle générique shared/ai3/hysteresis.lua (H). Testée hors jeu : tests/menace_equipe_test.lua.

  Avant (lu) : une perte à moins de THREAT_RADIUS (90) tuiles du QG posait f.threatened_until = tick + D.THREAT_TICKS (900 ticks, 15 s,
  script/faction/commander.lua:229) ; la menace tombait seule 15 s après la dernière perte, que le QG soit défendu ou non (levée par une
  échéance, avant tout correctif).

  Règle (une mesure par pensée de l'équipe, Team.view) :
    - ENTRÉE   une perte près du QG il y a moins de D.THREAT_TICKS (comme avant) ;
    - MAINTIEN tant qu'une perte est récente, ou que le QG n'a aucune tourelle armée (ni chargeur) ;
    - SORTIE   « calme + tourelles » : Me.CALM_THINKS pensées DE SUITE sans perte récente ET avec une tourelle armée au QG ;
               « plafond » : Me.CAP_TICKS ticks depuis la DERNIÈRE perte, tourelles ou non (sans plafond, une équipe sans munitions
               resterait menacée pour toujours, l'évolution coupée) ;
    - « nouvelle perte » pendant la menace : journal seulement (la menace dure, les compteurs repartent).
  Le plafond court depuis la dernière perte, pas depuis l'entrée : une attaque qui dure (une perte toutes les 2 min) garde la menace.

  Pourquoi Me.CAP_TICKS = 18 000 (5 min), SUPPOSÉ, à mesurer par les durées des lignes FO-MENACE du journal :
    - la menace tenue ferme les gisements à la capitalisation (Ca.usable) ; une équipe SANS tourelle armée est celle qui a le plus besoin
      de fer pour ses chargeurs : au-delà de quelques minutes, la coupure l'affamerait ; 5 min bornent le coût à 20 fois la fenêtre
      d'avant (15 s), par attaque ;
    - c'est la durée « durable » déjà retenue ailleurs : minuteur de stabilité de L10 (gist l.506-511, Pl.TICKS), entrée et sortie du
      mode survie (Sv.SHORT_TICKS, Sv.EXIT_TICKS) ;
    - plus court (1 à 2 min), une vague qui revient après une pause rouvrirait la menace à chaque fois (bascules au journal).
  Pourquoi Me.CALM_THINKS = 2 : comme la sortie de la menace sur le QG (Mq.EXIT_THINKS) : 600 ticks de calme après la fenêtre de 15 s,
  soit 25 à 30 s sans perte pour une équipe défendue (15 s avant : presque le même rythme).
  Rend (menace, evenement, cause) ; evenement : "entree", "sortie", "perte" (nouvelle perte pendant la menace) ou nil ; cause : "perte",
  "calme + tourelles", "plafond", "nouvelle perte".
  Déterminisme : aucune table parcourue, aucun hasard, aucun temps mesuré ; ticks de jeu.
]]

local H = require("shared.ai3.hysteresis")
local Dc = require("shared.team.defchoix")

local Me = {}

Me.THREAT_TICKS = Dc.THREAT_TICKS -- 900 : une perte est « récente » pendant ce temps (une seule source, comme commander.lua)
Me.CALM_THINKS = 2                -- pensées de suite calmes ET défendues avant la sortie
Me.CAP_TICKS = 18000              -- ticks depuis la dernière perte : sortie, tourelles ou non (plafond)

function Me.new() return H.new() end

--- Une pensée. a = { tick, loss_t (tick de la dernière perte près du QG ; nil : aucune), armed (le QG a une tourelle armée ou des
--- chargeurs ; faux sans recensement : garde fermée, seule la sortie par le plafond reste) }.
function Me.update(st, a)
  local tick = a.tick
  local new_loss = a.loss_t ~= nil and a.loss_t ~= st.loss_t
  if a.loss_t ~= nil then st.loss_t = a.loss_t end
  local since = st.loss_t ~= nil and (tick - st.loss_t) or nil
  local recent = since ~= nil and since < Me.THREAT_TICKS
  local capped = st.crise and since ~= nil and since >= Me.CAP_TICKS
  local lvl, opts = 0, { sortie_n = Me.CALM_THINKS }
  if recent then lvl = 2
  elseif capped then opts = { sortie_n = 1 } -- plafond : sortie à cette pensée
  elseif not a.armed then lvl = 1 end
  local was = st.crise
  local _, ev = H.update_haut(st, lvl, 1, 1, a.armed and true or false, opts)
  if ev == "entree" then return st.crise, "entree", "perte" end
  if ev == "sortie" then return st.crise, "sortie", capped and "plafond" or "calme + tourelles" end
  if was and st.crise and new_loss then return st.crise, "perte", "nouvelle perte" end
  if st.crise and not a.armed then return st.crise, nil, "tourelles non recensees : menace gardee" end -- lot TV-GARDES (W04) : refus ecrit (aucun evenement)
  return st.crise, nil, nil
end

Me.describe = H.describe

return Me
