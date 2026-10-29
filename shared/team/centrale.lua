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

--- Un relevé : power et capacity en J/tick (production totale et capacité des machines à vapeur bâties). Rend vrai quand la
--- saturation dure depuis C.SAT_CHECKS relevés. Une capacité nulle ou une production nulle (panne : 0 < 80 % de la capacité) n'est pas une demande.
function C.observe(st, power, capacity)
  if capacity > 0 and power >= C.SAT * capacity then st.sat = (st.sat or 0) + 1 else st.sat = 0 end
  st.saturated = st.sat >= C.SAT_CHECKS
  return st.saturated
end

--- Nombre de chaudières de la centrale à demander, ou (nil, raison). n : { done = centrales finies, pending = centrales en
--- projet (ni finies ni refusées), refused = demandes de croissance refusées, hold = repli de l'équipe, cool = pause après un abandon, off = règle coupée }.
function C.growth(st, n)
  if n.off then return nil, "regle coupee" end
  if not st.saturated then return nil, "pas saturee" end
  if n.pending > 0 then return nil, "un chantier de centrale est ouvert" end
  if n.done < 1 then return nil, "aucune centrale finie" end
  if n.done >= C.MAX_PLANTS then return nil, "plafond de centrales" end
  if (n.refused or 0) >= C.MAX_REFUSED then return nil, "plan refuse " .. C.MAX_REFUSED .. " fois" end
  if n.hold and (st.sat or 0) < C.HOLD_PASS then return nil, "repli de l'equipe (manque de matiere)" end
  if n.cool then return nil, "pause apres une centrale refusee ou abandonnee" end
  if (st.requests or 0) >= C.MAX_REQUESTS then return nil, "trop de demandes" end
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

--- La demande est partie : la saturation est à remesurer avec la nouvelle capacité.
function C.requested(st)
  st.sat, st.saturated = 0, false
  st.requests = (st.requests or 0) + 1
end

--- Une centrale de plus dont la réserve de matériaux reste incomplète depuis `waited` ticks est abandonnée (crise de matière :
--- les pièces réservées retournent au coffre pour les autres chantiers).
function C.stale(state, reason, waited)
  return state == "reserve" and reason == "materiaux" and waited >= C.STALE
end

return C
