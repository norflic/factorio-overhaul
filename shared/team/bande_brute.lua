--- s45 PIERRE : borne d'une bande électrique SANS four (minerai brut employé tel quel, sans plaque à fondre au champ).
--- Journal 0.7.103, emerald : « avant-poste 3 (stone) : bande -430 du champ demandee, projet 6 : 36 foreuse(s) electrique(s), 0 four(s),
--- 1 paire(s) thermique(s) dessous, 1 paire(s) ailleurs » (20 min) puis 1 095/min de pierre extraits pour un besoin de 1,5 à 15/min, pendant que
--- le fer restait bloqué. La migration REMPLACE des paires thermiques ; pour une bande sans four (aucune plaque produite), elle ne pose pas
--- plus de foreuses que de paires qu'elle remplace (au moins une). Une bande voulue par la capitalisation (budget borné par la demande) passe.
--- Règle pure, aucun nom : le rôle « sans four » se lit au plan de la bande (entités de genre « four »).
local M = {}

--- nd : foreuses de la bande ; nf : fours de la bande ; pairs : paires thermiques de l'avant-poste ; wanted : voulue par la capitalisation.
--- Rend ok, plafond.
function M.ok(nd, nf, pairs, wanted)
  nd = tonumber(nd) or 0
  nf = tonumber(nf) or 0
  local cap = math.max(1, math.floor(tonumber(pairs) or 0))
  if wanted or nf > 0 then return true, nil end
  return nd <= cap, cap
end

return M
