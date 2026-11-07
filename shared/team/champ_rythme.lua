--[[
  RYTHME DES BANDES (lot CHAMP-COUVERTURE, R5a et R5c, accord du lead du 5/11). PUR : aucune API Factorio, aucun nom d'objet.

  Défaut mesuré (partie du DC du 5/11) : la porte « une bande d'agrandissement (sans paire dessous) n'est demandée que si la plaque libre
  est sous 3 000 » bloquait exactement les champs riches : « emerald : avant-poste 9 : bande -172 sans paire en attente (14209
  copper-plate libres) », « amber : avant-poste 8 : bande -504 [...] (34912 copper-plate libres) », 0 bande demandée sur 5 et 4
  planifiées. Le DC : « on pourrait mettre au moins deux fois plus de foreuses. Ça fait un peu peine quand on voit ça ».

  R5a : la porte ne s'applique qu'à un champ BÂTI à CFG.share au moins (80 %) de son plan ; en dessous, une bande d'agrandissement ne
  garde que les gardes communes (fer libre, pile). R5c : une bande compte au prorata de ses foreuses POSÉES (une bande finie sans ses
  foreuses, posées en dernier et manquantes, ne compte pas pour bâtie).

  Ry.share(bands, total) -> part bâtie (0..1) : bands = { { planned = foreuses de la bande, built = foreuses posées } } des bandes
                            demandées ; total = bandes du cadre (les bandes jamais demandées comptent 0). total <= 0 : 1 (rien à bâtir).
  Ry.ext_wait(c)         -> vrai si la bande attend : c = { under = paires sous la bande, free = plaques libres du produit, wanted =
                            voulue par la capitalisation, share = part bâtie }.
]]

local Ry = {}

Ry.CFG = {
  plates = 3000, -- plaques libres du produit au-delà desquelles un champ déjà bien bâti n'est plus agrandi
  share = 0.8,   -- part bâtie du champ à partir de laquelle la porte des plaques s'applique (« pas d'ultra-maximisation »)
}

function Ry.share(bands, total)
  if not total or total <= 0 then return 1 end
  local s = 0
  for _, b in ipairs(bands or {}) do
    if (b.planned or 0) > 0 then s = s + math.min(1, (b.built or 0) / b.planned) end
  end
  return math.min(1, s / total)
end

function Ry.ext_wait(c)
  if (c.under or 0) > 0 or c.wanted then return false end
  if (c.free or 0) < Ry.CFG.plates then return false end
  return (c.share or 0) >= Ry.CFG.share - 1e-9
end

return Ry
