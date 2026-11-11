--[[
  Lot CORR-ENERGIE : croissance de la centrale à vapeur (remarque 10 du DC : « ajouter des usines de production d'électricité si
  besoin »). PUR (aucune API Factorio, aucun nom d'objet), testé hors jeu par tests/centrale_test.lua.

  Une centrale figée à une chaudière et deux machines (1,8 MW) sature dès les premiers modules (mesuré : 24 334 et 30 000 J/tick
  de 30 000 possibles, 28/10) : au-delà, les machines électriques restent sans courant. Règle : tant que les machines à vapeur
  produisent au moins C.SAT de leur capacité pendant C.SAT_CHECKS relevés de suite, UNE centrale de plus (C.BOILERS chaudière
  et ses machines) est demandée au plan directeur, comme la première. Garde-fous : un seul chantier de centrale à la fois,
  C.MAX_PLANTS centrales finies au plus, C.MAX_REFUSED refus de plan au plus (au-delà, le site manque : on cesse d'insister),
  jamais pendant le repli de l'équipe (crise de matière : des réserves affamées), réglage de banc pour couper la règle.

  Lot ENERGIE-CROISSANCE (retour du DC du 29/10 sur la 0.6.18 : « je remarque qu'ils ont un déficit en électricité. Ils n'ont pas
  augmenté […] la production d'électricité », « il y en a pas assez d'électricité, c'est un peu bête ») : journal de sa partie,
  Écarlate, centrale saturée à 83,3 min (30 000 J/tick sur 30 000), deux centrales de plus refusées « pas de lot » en 30 s (la seule
  eau est l'étang garanti, déjà pris), puis « plan refuse deux fois » : PLUS JAMAIS de centrale de plus, saturée encore à 95 et
  132 min. Désormais : (1) la centrale de plus peut partager la rive d'une centrale finie (script/team/build.lua, candidates) ;
  (2) un refus n'est plus définitif : pause de C.COOL, puis nouvel essai, jusqu'à C.MAX_REFUSED refus ; (3) le repli de l'équipe
  ne retient plus la centrale quand la saturation dure C.HOLD_PASS relevés (le courant qui manque arrête la production : c'est
  un besoin de production, pas une amélioration) ; (4) plafonds relevés (C.MAX_PLANTS, C.MAX_REQUESTS).
]]
local Cv = require("shared.team.champ_vapeur") -- lot ENERGIE : taille du champ de machines à vapeur
local C = {}

C.SAT = 0.8          -- part de la capacité au-delà de laquelle la centrale est saturée (la demande atteint la production)
C.SAT_CHECKS = 6     -- relevés (5 s) de suite : 30 s
C.MAX_PLANTS = 6     -- centrales finies au plus par équipe (lot ENERGIE-CROISSANCE : 3 -> 6, soit 10,8 MW)
C.MAX_REFUSED = 5    -- demandes de centrale refusées par le plan (pas de rive libre) avant d'y renoncer (lot ENERGIE-CROISSANCE : 2 -> 5, une pause C.COOL après chacune)
C.BOILERS = 1        -- chaudières de la centrale demandée (2 machines à vapeur chacune)
C.MAX_REQUESTS = 15  -- demandes de centrale de plus, au total, sur toute la partie d'une équipe (borne des abandons et des pertes ; 6 -> 15)
C.STALE = 108000     -- ticks (30 min) d'une réserve de matériaux incomplète au bout desquels la centrale de plus est abandonnée
C.COOL = 36000       -- ticks (10 min) de pause après un abandon ou un refus du plan (lot ENERGIE-CROISSANCE : aussi après un refus)
C.HOLD_PASS = 60     -- relevés (5 min) de saturation au-delà desquels le repli de l'équipe ne retient plus la centrale de plus
C.STALE_REASON = "delai" -- raison du projet annulé (ne compte pas comme un refus du plan)

-- Lot TV-ENERGIE (G65, TODO_VIDEO.md l.242 : « Crise d'énergie et rien d'autre : Small Power Station […] éviter d'attendre la recherche
-- pendant une crise » ; quote du DC du 31/10 dans champ_vapeur.lua : « pas all-in à un endroit », centrale de secours séparée). En CRISE, la
-- centrale demandée n'est plus un champ de 2 à 6 chaudières (cher, lent à réunir quand la matière manque justement) mais une UNITÉ DE SECOURS :
-- C.SECOURS_BOILERS chaudière (2 machines à vapeur, le plus petit gabarit), projet DISTINCT (marqué secours, rive libre ailleurs : le plan
-- exclut déjà la rive du projet rouvert), prioritaire. Jamais de croissance en crise : tant que la crise dure, aucune autre taille ; elle
-- reprend (saturation, avance) une fois la capacité revenue. Au plus C.SECOURS_MAX unités de secours par crise (la reconstruction sur place
-- continue ; la crise finie, le compte repart de zéro).
C.SECOURS_BOILERS = 1
C.SECOURS_MAX = 3

-- Lot TV-ENERGIE (diagnostic azure) : DÉFICIT de kW (kW retenus par la capitalisation avec de l'épargne qui dort, S.deficit) : la centrale de plus
-- est demandée après C.DEFICIT_CHECKS relevés de suite (15 s), à la taille du déficit (C.deficit_size), une seule à la fois (garde « chantier ouvert »).
C.DEFICIT_CHECKS = 3

-- Lot VIDEO-L12, partie 2 (fo-logs/2026-11-07_VIDEO-AUTOMATISATION/PLAN_L6_L10_L12.md §3.3, point 2 ; gist l.48-53) : HYSTÉRÉSIS. Avant, un
-- seul relevé sous C.SAT effaçait la saturation (seuil unique : une charge qui oscille autour de 80 % allumait et éteignait la saturation, et
-- remettait à zéro la durée qui lève le repli, C.HOLD_PASS). Une centrale SATURÉE le reste tant qu'elle produit au moins C.SAT_EXIT de sa
-- capacité ; l'entrée ne change pas (C.SAT pendant C.SAT_CHECKS relevés). C.requested (la demande partie) remesure toujours : le chantier
-- ouvert retient déjà une deuxième demande (C.growth, n.pending), et la centrale posée change la capacité : la mesure qui suit la pose
-- décide d'une centrale de plus (pas de double commande, V77).
C.SAT_EXIT = 0.7

--- Un relevé : power et capacity en J/tick (production totale et capacité des machines à vapeur bâties). Rend vrai quand la
--- saturation dure depuis C.SAT_CHECKS relevés, et tant qu'ensuite la production reste au moins à C.SAT_EXIT de la capacité. Une
--- capacité nulle ou une production nulle (panne : 0 < 70 % de la capacité) n'est pas une demande.
function C.observe(st, power, capacity)
  local lim = st.saturated and C.SAT_EXIT or C.SAT
  if capacity > 0 and power >= lim * capacity then st.sat = (st.sat or 0) + 1 else st.sat = 0 end
  st.saturated = (st.saturated and st.sat > 0) or st.sat >= C.SAT_CHECKS
  return st.saturated
end

--- Lot TV-ENERGIE (G65) : l'équipe est-elle en CRISE d'énergie ? Deux causes : la centrale est PERDUE (n.lost : machines détruites, Cv.lost) ;
--- ou la saturation dure depuis C.HOLD_PASS relevés PENDANT le repli de l'équipe (crise de matière : n.hold, les réserves sont affamées, un
--- champ entier ne se réunirait pas). Rend vrai/faux et la cause ("perte" | "repli" | nil).
function C.crisis(st, n)
  if n.lost then return true, "perte" end
  if (st.sat or 0) >= C.HOLD_PASS and n.hold then return true, "repli" end
  return false, nil
end

--- Suivi du déficit de kW. st : mémoire { def_n } ; flag : il y a un déficit à ce relevé. Rend vrai quand il dure depuis C.DEFICIT_CHECKS relevés.
function C.deficit_track(st, flag)
  if flag then st.def_n = (st.def_n or 0) + 1 else st.def_n = 0 end
  return st.def_n >= C.DEFICIT_CHECKS
end

--- Chaudières pour couvrir `kw` kW de déficit (boiler_kw : puissance d'une chaudière ; nil/0 : C.BOILERS). Au moins 1, au plus Cv.MAX_FIELD, une de moins
--- par refus du plan (shrink), bornée par la voie de tapis (lane_cap).
function C.deficit_size(kw, boiler_kw, shrink, lane_cap)
  if not (boiler_kw and boiler_kw > 0 and kw and kw > 0) then return C.BOILERS end
  local nb = math.min(Cv.MAX_FIELD, math.max(1, math.ceil(kw / boiler_kw - 1e-9)))
  if lane_cap and lane_cap >= 1 then nb = math.min(nb, math.floor(lane_cap)) end
  return math.max(1, nb - math.max(0, shrink or 0))
end

-- Lot ELECTRIQUE (e, lead 8/11 : partie du DC 0.6.66, 7 125 puis 8 730 kW retenus pendant qu'un seul chantier d'une chaudière, 1 800 kW,
-- bloquait toute autre demande « un chantier de centrale est ouvert ») : au plus C.MAX_PARALLEL chantiers à la fois quand le déficit installé
-- dépasse ce que les chantiers ouverts apporteront (n.pending_kw, kW nominaux de leurs machines). Sans n.pending_kw (appels d'avant) : un seul.
C.MAX_PARALLEL = 2

-- Lot CC-ENERGIE (F491, partie du DC sur la 0.6.87, graine 3592985581 : « 16 MW de capacité pour 650 kW » ; journal : player 16 200 kW de
-- capacité pour 781 kW produits a 93 min, emerald 14 400 pour 3 297, amber 9 000 pour 114, chaque équipe 5 400 kW a 21 min pour 0 a 180 kW).
-- Cause : les déclencheurs de croissance (déficit de kW retenus par la capitalisation, avance sur les chantiers, chantier en parallèle) se
-- lisent en kW NOMINAUX de machines voulues, jamais rapportés a la demande MESURÉE : 8 610 kW retenus a 12,6 min ont fait demander deux
-- centrales pendant que la centrale finie produisait 0 kW sur 1 800. Règle du DC : aucune chaudière ni machine a vapeur de plus tant que
-- demande / capacité < C.GROW_LOAD. n.load (C.grow_load) : production mesurée des machines vivantes sur la capacité bâtie vivante + celle
-- des centrales neuves en chantier ; nil quand aucune capacité n'existe (première centrale, perte totale : la demande ne se mesure pas).
C.GROW_LOAD = 0.75
C.LOAD_REASON = "demande mesuree sous 75 % de la capacite"

--- Charge de la croissance (0 a 1+ ; nil sans capacité) : used_j = J/tick produits par les machines a vapeur vivantes (centrales finies et
--- rouvertes), built_j = leur capacité vivante, pending_j = capacité nominale des centrales NEUVES en chantier (une reconstruction ne
--- compte que ses machines vivantes : si elle n'aboutit pas, la perte se constate, Cv.lost).
function C.grow_load(used_j, built_j, pending_j)
  local cap = math.max(0, built_j or 0) + math.max(0, pending_j or 0)
  if cap <= 0 then return nil end
  return math.max(0, used_j or 0) / cap
end

--- kW de déficit que les chantiers ouverts ne couvrent pas, si un chantier de plus est permis ; nil sinon (aucun chantier ouvert, plafond de
--- chantiers, déficit pas installé, capacité des chantiers inconnue ou suffisante).
function C.parallel_kw(st, n)
  local p = n.pending or 0
  if p <= 0 or p >= C.MAX_PARALLEL or n.pending_kw == nil then return nil end
  if not ((n.deficit_kw or 0) > 0 and (st.def_n or 0) >= C.DEFICIT_CHECKS) then return nil end
  local left = n.deficit_kw - n.pending_kw
  if left <= 0 then return nil end
  return left
end

--- Lot P0-CENTRALE : la demande engagee (kW) depasse-t-elle la capacite batie (kW) ? Faux sans l'une des deux mesures.
function C.engaged_over(engaged_kw, cap_kw)
  return engaged_kw ~= nil and cap_kw ~= nil and cap_kw > 0 and engaged_kw > cap_kw
end

--- Nombre de chaudières de la centrale à demander, ou (nil, raison). n : { done = centrales finies, pending = centrales en
--- projet (ni finies ni refusées), refused = demandes de croissance refusées, hold = repli de l'équipe, cool = pause après un abandon, off = règle coupée }.
function C.growth(st, n)
  if n.off then return nil, "regle coupee" end
  -- lot ENERGIE (2/11) : `anticipate` (shared/team/sante_centrale.lua : production + chantiers + modules retenus >= 70 % de la capacité) demande la
  -- centrale AVANT la saturation ; tous les garde-fous suivants (chantier ouvert, plafonds, pauses, repli) valent aussi pour elle
  local deficit = (n.deficit_kw or 0) > 0 and (st.def_n or 0) >= C.DEFICIT_CHECKS -- lot TV-ENERGIE : déficit de kW installé
  if not st.saturated and not n.lost and not n.anticipate and not deficit then return nil, "pas saturee" end
  -- lot CC-ENERGIE (F491) : quel que soit le déclencheur, rien tant que la demande mesurée reste sous C.GROW_LOAD de la capacité
  if n.load ~= nil and n.load < C.GROW_LOAD and not C.engaged_over(n.engaged_kw, n.cap_kw) then return nil, C.LOAD_REASON end
  -- lot P0-CENTRALE (partie du DC 0.7.3 : « courant insuffisant : 2528 kW pris sur 1800 kW », centrale figee) : la production mesuree plafonne
  -- a la capacite (et sous elle quand les machines attendent leur courant) ; une demande ENGAGEE (n.engaged_kw : production + consommateurs
  -- en chantier ou retenus) au-dela de la capacite batie (n.cap_kw) compte comme une charge de 100 %
  -- lot ENERGIE (relecture) : la reconstruction qui n'aboutit pas ne retient pas le champ de remplacement (« si on y arrive vraiment pas, on
  -- le fait ailleurs ») ; n.rebuilding : ceux de n.pending qui sont des centrales rouvertes
  if n.lost then
    if n.pending - (n.rebuilding or 0) > 0 then return nil, "un chantier de centrale est ouvert" end
  else
    -- lot ELECTRIQUE (e) : un chantier de PLUS quand le déficit installé dépasse la capacité des chantiers ouverts (C.parallel_kw)
    if n.pending > 0 and not C.parallel_kw(st, n) then return nil, "un chantier de centrale est ouvert" end
    if n.done < 1 then return nil, "aucune centrale finie" end
  end
  if n.done >= C.MAX_PLANTS then return nil, "plafond de centrales" end
  if (n.refused or 0) >= C.MAX_REFUSED then return nil, "plan refuse " .. C.MAX_REFUSED .. " fois" end
  if n.hold and (st.sat or 0) < C.HOLD_PASS and not n.lost then return nil, "repli de l'equipe (manque de matiere)" end
  if n.cool then return nil, "pause apres une centrale refusee ou abandonnee" end
  -- lot FIX-P1 : plus de borne C.MAX_REQUESTS sur la partie (elle bloquait la croissance électrique pour toujours) ; C.COOL et C.MAX_REFUSED bornent
  -- lot TV-ENERGIE (G65) : en crise, l'unité de secours (la plus petite), jamais le champ ; plafonnée par crise (n.secours_n)
  if C.crisis(st, n) then
    if (n.secours_n or 0) >= C.SECOURS_MAX then return nil, "unites de secours epuisees pour cette crise" end
    return C.SECOURS_BOILERS
  end
  -- lot ELECTRIQUE (e) : chantier en parallèle, à la taille du déficit que les chantiers ouverts ne couvrent pas
  if not n.lost and n.pending > 0 then return C.deficit_size(C.parallel_kw(st, n), n.boiler_kw, n.refused, n.lane_cap) end
  -- lot TV-ENERGIE : déficit de kW sans saturation ni avance : la taille du déficit, pas celle du champ ordinaire
  if deficit and not st.saturated and not n.anticipate then return C.deficit_size(n.deficit_kw, n.boiler_kw, n.refused, n.lane_cap) end
  -- lot ENERGIE : un CHAMP (une rangée de chaudières, un seul tapis) dimensionné sur les chaudières vivantes, au lieu d'une chaudière
  -- isolée ; sans la mesure (n.built absent : anciens appels, bancs), C.BOILERS comme avant
  if n.built ~= nil then return Cv.boilers_for(n.built, n.refused, n.lane_cap) end
  return C.BOILERS
end

--- Lot ENERGIE-CROISSANCE : `refused` = refus du plan comptés à ce relevé. Un refus NOUVEAU (le compte a monté depuis le relevé
--- précédent, st.refused_n) ouvre une pause de C.COOL ticks (st.cool_until), après laquelle la croissance réessaie. Une partie
--- sauvegardée avant le lot (st.refused_n absent, refus déjà comptés) reçoit une pause, puis réessaie. Rend vrai si une pause s'ouvre.
function C.after_refusal(st, refused, tick)
  local new = refused > (st.refused_n or 0)
  st.refused_n = refused
  if new then st.cool_until = math.max(st.cool_until or 0, tick + C.COOL) end
  return new
end

--- Part de la capacité produite (0 à 1 ; nil sans capacité) : la satisfaction lue au journal (la demande au-delà de la capacité
--- n'est pas mesurable : une centrale saturée produit sa capacité).
function C.load(power, capacity)
  if not capacity or capacity <= 0 then return nil end
  return math.min(1, (power or 0) / capacity)
end

-- (Lot FUITES-PILE, vague 10 : C.MAX_PONDS et C.pond_allowed retirés, code mort depuis 0.6.21 : plus aucun étang posé par le mod,
-- décision du DC D-24 (1), script/team/build.lua.)

--- La demande est partie : la saturation est à remesurer avec la nouvelle capacité.
function C.requested(st)
  st.sat, st.saturated = 0, false
  st.def_n = 0 -- lot TV-ENERGIE : le déficit de kW se remesure aussi
  st.requests = (st.requests or 0) + 1
end

--- Une centrale de plus dont la réserve de matériaux reste incomplète depuis `waited` ticks est abandonnée (crise de matière :
--- les pièces réservées retournent au coffre pour les autres chantiers).
function C.stale(state, reason, waited)
  return state == "reserve" and reason == "materiaux" and waited >= C.STALE
end

return C
