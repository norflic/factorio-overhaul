--[[
  Lot PLANDIR : croissance de la centrale à vapeur. PUR (aucune API Factorio), testé hors jeu par tests/centrale_test.lua.

  Une centrale figée à une chaudière et deux machines (1,8 MW) sature dès les premiers modules (mesuré : 24 334 et 30 000 J/tick
  de 30 000 possibles, 28/10). Règle : tant que les machines à vapeur produisent au moins C.SAT de leur capacité pendant
  C.SAT_CHECKS relevés de suite, une centrale de plus est demandée (un seul chantier de centrale à la fois, C.MAX_PLANTS au
  plus), de la taille de ce qui existe (la capacité double), bornée par l'extension du gabarit.
]]
local C = {}

C.SAT = 0.8          -- part de la capacité au-delà de laquelle la centrale est saturée (demande 80 % de la production)
C.SAT_CHECKS = 6     -- relevés (5 s) de suite : 30 s
C.MAX_PLANTS = 3     -- centrales au plus par équipe

--- Un relevé : power et capacity en J/tick (production totale et capacité des machines à vapeur bâties). Rend vrai quand la
--- saturation dure depuis C.SAT_CHECKS relevés.
function C.observe(st, power, capacity)
  if capacity > 0 and power >= C.SAT * capacity then st.sat = (st.sat or 0) + 1 else st.sat = 0 end
  st.saturated = st.sat >= C.SAT_CHECKS
  return st.saturated
end

--- Taille (chaudières) de la centrale à demander, ou nil. done : centrales finies ; pending : centrales en projet (ni finies
--- ni refusées) ; boilers : chaudières bâties ; ext_max : plus grande taille du gabarit.
function C.growth(st, done, pending, boilers, ext_max)
  if not st.saturated or pending > 0 or done < 1 or done >= C.MAX_PLANTS then return nil end
  return math.max(1, math.min(ext_max or 1, boilers))
end

--- La demande est partie : la saturation est à remesurer avec la nouvelle capacité.
function C.requested(st)
  st.sat, st.saturated = 0, false
end

return C
