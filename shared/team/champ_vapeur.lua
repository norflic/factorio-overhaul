--[[
  Lot ENERGIE (champ de machines a vapeur ; retour du DC du 31/10 sur la 0.6.27) : « un espece de champ de machines a vapeur pour
  qu'en fait le charbon il arrive que d'un cote pour eviter de le split un peu partout », « il n'y a pas d'apport automatique de
  charbon », « si ca se fait detruire, autant on essaie de reconstruire, si on y arrive vraiment pas, on le fait ailleurs », « pas
  all-in a un endroit » (centrale de secours separee).

  Mesure (journaux du DC, 31/10) : 31 demandes du projet d'alimentation de la centrale (lot CHARBON-CENTRALE), 0 centrale nourrie par
  des foreuses : 17 refus « foreuses : trop loin » (le tapis du gisement a la tete d'alimentation tient dans une boite de 120 tuiles
  au plus, script/team/build.lua Build.plan_drills), 12 « foreuses : minerai » (le gisement de charbon est hors du treillis : le
  treillis ne grandissait pas pour l'alimentation), 1 plan accepte (ambre, tapis de 142 tuiles) reste en « reserve:materiaux ».

  Regles PURES (aucune API Factorio, aucun nom d'objet ; testees hors jeu par tests/champ_vapeur_test.lua, avec mutants) :
  1. TAILLE DU CHAMP (Cv.boilers_for) : la croissance demande un CHAMP (une rangee de Cv.MIN_FIELD a Cv.MAX_FIELD chaudieres nourries
     par UN tapis qui entre d'un seul cote, gabarit steam(nb)), pas une chaudiere isolee dont chaque coffre demanderait son propre
     apport ; reduit d'une chaudiere par refus du plan (un lot trop petit), borne par ce qu'une voie de tapis porte.
  2. PORTEE DU TAPIS (Cv.reach) : l'alimentation d'une centrale peut depasser la boite de 120 tuiles du tapis ordinaire, jusqu'a
     Cv.MAX_SPAN tuiles ; au-dela, « trop loin » reste vrai. Lot VAPEUR-RELAIS (11/11) : le tapis long est UN SEUL trace continu, celui
     du tapis ordinaire (Tdr.trace : souterrains sous les autres flux, par tranches, preuve de purete), plus de troncons relies par des
     points de passage fixes sur la droite (« relais : point de passage » des qu'un quartier bati couvrait le milieu, aucun souterrain).
  3. REFUS DE L'ALIMENTATION (Cv.after_refusal) : « minerai » (gisement hors du treillis) fait GRANDIR le treillis au lieu d'attendre ;
     « trop loin » n'arrive plus qu'au-dela du relais.
  4. PERTE (Cv.lost) : des machines a vapeur detruites qui ne sont pas revenues apres Cv.LOSS_CHECKS releves (la reconstruction
     sur place n'aboutit pas) demandent un champ de remplacement, qui se pose sur une AUTRE rive libre (le plan directeur exclut deja
     la rive occupee par le projet rouvert).
]]
local Cv = {}

Cv.MIN_FIELD = 2        -- chaudieres d'un champ demande par la croissance (au moins)
Cv.MAX_FIELD = 6        -- chaudieres d'un champ (au plus : 20 tuiles de large, un lot en compte 24)
Cv.GROW_FRAC = 0.5      -- le champ de plus ajoute au moins cette part des chaudieres deja bâties
Cv.MARGIN = 12          -- marge de la boite du tapis (celle de script/team/build.lua, Build.plan_drills)
Cv.BOX_DIRECT = 120     -- boite du tapis ordinaire (script/team/build.lua, Build.plan_drills)
Cv.MAX_SPAN = 360       -- tuiles au plus du depart a l'arrivee (axe dominant) d'un tapis d'alimentation
Cv.LOSS_FRAC = 0.5      -- part de la capacite prevue en dessous de laquelle la centrale est dite perdue
Cv.LOSS_CHECKS = 120    -- releves (5 s) de perte de suite avant le remplacement : 10 min
Cv.LOSS_CHECKS_TOTAL = 36 -- lot ENERGIE (2/11) : perte TOTALE (plus aucune machine vivante : toute la base sans courant, Scarlet a 57,3 min,
                          -- 129 consommateurs sur 136 a 60 min) : 3 min, le temps qu'une reconstruction sur place aboutisse sinon

--- Chaudieres bâties vivantes -> chaudieres du champ a demander. built : chaudieres vivantes (nil : inconnu) ; shrink : refus du plan
--- deja subis (une chaudiere de moins par refus, jamais moins de 1) ; lane_cap : chaudieres qu'une voie de tapis nourrit (nil : sans borne).
function Cv.boilers_for(built, shrink, lane_cap)
  local nb = math.max(Cv.MIN_FIELD, math.ceil((built or 0) * Cv.GROW_FRAC - 1e-9))
  nb = math.min(nb, Cv.MAX_FIELD)
  if lane_cap and lane_cap >= 1 then nb = math.min(nb, math.floor(lane_cap)) end
  nb = nb - math.max(0, shrink or 0)
  return math.max(1, nb)
end

--- Chaudieres qu'une voie de tapis nourrit : debit de la voie (objets/s), puissance de combustion d'une chaudiere (kW), energie du
--- combustible (kJ). 0 si une donnee manque.
function Cv.lane_cap(lane_rate, boiler_kw, coal_kj)
  if not (lane_rate and lane_rate > 0 and boiler_kw and boiler_kw > 0 and coal_kj and coal_kj > 0) then return 0 end
  return math.floor(lane_rate / (boiler_kw / coal_kj) + 1e-9)
end

--- Boite (largeur, hauteur) du tapis de s a a, marge comprise (celle du tapis ordinaire : 12 de chaque cote).
function Cv.box(sx, sy, ax, ay, margin)
  margin = margin or Cv.MARGIN
  return math.abs(ax - sx) + 2 * margin + 1, math.abs(ay - sy) + 2 * margin + 1
end

--- Portee du tapis de s a a. Rend "direct" (la boite tient dans Cv.BOX_DIRECT : tapis ordinaire), "long" (au-dela, jusqu'a Cv.MAX_SPAN
--- tuiles : le meme trace, dans la boite entiere), ou nil et la raison (« trop loin »).
function Cv.reach(sx, sy, ax, ay)
  local w, h = Cv.box(sx, sy, ax, ay)
  if w <= Cv.BOX_DIRECT and h <= Cv.BOX_DIRECT then return "direct" end
  if math.max(math.abs(ax - sx), math.abs(ay - sy)) > Cv.MAX_SPAN then return nil, "trop loin" end
  return "long"
end

--- Refus du projet d'alimentation (raison rendue par le plan, ex. « foreuses : minerai ») -> action : "grandir" (gisement hors du
--- treillis : le treillis grandit), "attendre" (autre raison : pause ordinaire du lot CHARBON-CENTRALE).
function Cv.after_refusal(reason, can_grow)
  reason = tostring(reason or "")
  if can_grow and (reason:find("minerai", 1, true) or reason:find("hors du treillis", 1, true)) then return "grandir" end
  return "attendre"
end

--- Perte de la centrale. st : memoire { lost } ; planned, alive : capacite prevue et capacite des machines vivantes (J/tick). Rend vrai
--- quand la perte dure depuis Cv.LOSS_CHECKS releves ; un champ de remplacement est alors demande (et le compte repart de zero).
--- Lot TV-ENERGIE (G65) : la capacité vivante est-elle sous Cv.LOSS_FRAC de la capacité prévue (état, sans compteur) ? Fin de la crise : faux.
function Cv.down(planned, alive)
  return (planned and planned > 0 and (alive or 0) < planned * Cv.LOSS_FRAC) and true or false
end

function Cv.lost(st, planned, alive)
  if Cv.down(planned, alive) then st.lost = (st.lost or 0) + 1 else st.lost = 0 end
  local need = (planned and planned > 0 and (alive or 0) <= 0) and Cv.LOSS_CHECKS_TOTAL or Cv.LOSS_CHECKS
  if st.lost >= need then st.lost = 0 return true end
  return false
end

--- Ligne du journal [FO-CHAMP-VAPEUR] (une seule mise en forme, pour la lire au banc). ev = { team, kind, tick, ... }.
function Cv.line(ev)
  local min = (ev.tick or 0) / 3600
  if ev.kind == "champ" then
    return string.format("[FO-CHAMP-VAPEUR] %s : champ de %d chaudiere(s) demande a %.1f min (%d vivantes, %d refus du plan, %s)",
      tostring(ev.team), ev.nb or 0, min, ev.built or 0, ev.refused or 0, tostring(ev.why or "saturation"))
  elseif ev.kind == "grandir" then
    return string.format("[FO-CHAMP-VAPEUR] %s : projet %s, gisement de charbon hors du treillis (%s) : le treillis grandit (rayon %d) a %.1f min",
      tostring(ev.team), tostring(ev.project), tostring(ev.why), ev.radius or 0, min)
  elseif ev.kind == "perte" then
    return string.format("[FO-CHAMP-VAPEUR] %s : centrale perdue a %.1f min (%.0f sur %.0f J/tick prevus vivants depuis %d releves) : champ de remplacement de %d chaudiere(s) sur une autre rive",
      tostring(ev.team), min, ev.alive or 0, ev.planned or 0, Cv.LOSS_CHECKS, ev.nb or 0)
  end
  return "[FO-CHAMP-VAPEUR] " .. tostring(ev.team) .. " : " .. tostring(ev.kind)
end

return Cv
