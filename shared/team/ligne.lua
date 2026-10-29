--[[
  LIGNE (lot AGENCEMENT, retour du DC du 29/10 en jouant la 0.6.16) : la fonderie à tapis en LONGUE LIGNE extensible.
  PUR : aucune API Factorio, aucun nom d'objet (tout arrive en DONNÉES : tests/iag_test.lua §8).

  Le DC : « il y a un pattern [...] un convoyeur au milieu qui pose du charbon et du fer, deux fours au-dessus, deux fours en
  dessous, et la sortie en plaque de fer se fait dans deux coffres et du coup évidemment c'est pas reproductible. L'idée, ça
  serait d'avoir une longue rangée, une longue ligne et qui se mettent dans des coffres au final, avec évidemment les coffres
  [...] si c'est la source de ressources, plus proche du centre ; [...] dans d'autres flows d'usine, plutôt vers l'extérieur. »
  « C'est un pattern qui peut pas vraiment être recopié en long ou en large. »

  Ce que le code faisait (lu dans shared/team/modules.lua, G.smelter, et script/team/build.lua) : le gabarit est DÉJÀ une colonne
  de rangées de fours de part et d'autre du tapis, mais (1) sa longueur suivait la seule demande (rate), jamais le gisement ni
  le minerai livré : 4 fours, 4 foreuses ; (2) chaque tapis de sortie finissait dans UN bras et UN coffre, dont le débit
  plafonnait la ligne dès 6 rangées (un bras rapide ≈ 1,8 plaque/s contre 0,31 plaque/s par four de pierre) ; (3) les coffres
  étaient toujours au bout opposé au gisement.

  Ligne.sortie_for(use)                  -> "centre" | "exterieur" : où finissent les tapis de sortie et leurs coffres.
  Ligne.rows_fit(lot, margin, head, tail, side)
                                         -> rangées au plus qui tiennent dans un lot (tête d'alimentation derrière, quai devant).
  Ligne.budget_rows(stock, row_cost, share, floor_rows)
                                         -> rangées payables avec une part du stock de plaques (jamais sous floor_rows).
  Ligne.rows_wanted(s)                   -> rangées voulues et sa raison (voir ci-dessous).
  Ligne.fan(count)                       -> disposition des bras et coffres de sortie autour du bout d'un tapis.
]]
local L = {}

local EPS = 1e-9
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

L.MAX_ARMS = 2 -- bras de sortie par tapis : un devant le bout, un sur le côté EXTÉRIEUR (l'autre côté est celui des fours)

--- Où finit la ligne. « La source de ressources de la base » (ce que les PNJ viennent chercher au coffre) : les coffres vers le
--- CENTRE, c'est-à-dire au bout opposé au gisement, du côté de la base (la tête regarde le gisement). Plaques qui nourrissent
--- une usine (use = "usine") : vers l'EXTÉRIEUR, au bout de la tête. Toute autre valeur : le centre (le comportement d'avant).
function L.sortie_for(use)
  if use == "usine" then return "exterieur" end
  return "centre"
end

--- Rangées de fours (côté `side` chacune) qui tiennent dans un lot de `lot` tuiles : de la tête, `head` tuiles d'alimentation
--- derrière le premier four ; du bout, `tail` tuiles de quai ; au moins `margin` de chaque côté (P.fit : le quai doit rester
--- DANS le lot, la marge du corps du module est d'une tuile).
function L.rows_fit(lot, margin, head, tail, side)
  if type(lot) ~= "number" or type(side) ~= "number" or side < 1 then return 0 end
  local h = lot - max(margin or 1, head or 0) - max(margin or 1, tail or 0)
  return max(0, floor(h / side + EPS))
end

--- Rangées que le stock de plaques permet de lancer : `share` du stock ÷ `row_cost` (plaques par rangée de fours avec ses
--- foreuses), jamais moins que `floor_rows` (une équipe sans plaques construit quand même la fonderie qu'elle a demandée).
function L.budget_rows(stock, row_cost, share, floor_rows)
  local base = max(0, floor((floor_rows or 0) + EPS))
  if type(stock) ~= "number" or type(row_cost) ~= "number" or row_cost <= 0 then return base end
  local s = (type(share) == "number" and share > 0) and min(share, 1) or 0
  return max(base, floor(max(0, stock) * s / row_cost + EPS))
end

--- Rangées voulues d'une fonderie à tapis. s :
---   rows_rate     rangées que la DEMANDE exige (débit visé ÷ rendement d'une rangée), au moins 1 ;
---   pairs_dep     paires de foreuses que le gisement le plus proche porte à la couverture visée (shared/team/rangees.lua) ;
---   drill_rate    objets/s d'une foreuse ; cap : objets/s absorbés par UN four ;
---   pairs_line    paires au plus d'UNE ligne de foreuses (un collecteur) ;
---   rows_max      rangées au plus du gabarit (bornes de ses débits et de son emprise) ;
---   rows_fit      rangées au plus qui tiennent dans un lot (Ligne.rows_fit) ;
---   out_ok(rows)  vrai si les bras de sortie suivent `rows` rangées (sinon la ligne serait étranglée par ses coffres) ;
---   budget_rows   rangées payables (Ligne.budget_rows), nil : pas de borne ;
---   grow          faux : la taille de la demande, rien de plus (le comportement d'avant).
--- Rend rows, why : why ∈ "demande" (inchangé), "gisement" (la ligne suit les foreuses que le gisement porte), "budget",
--- "emprise", "sortie" (borne qui a retenu la croissance).
function L.rows_wanted(s)
  local hard = max(1, min(s.rows_max or 1, s.rows_fit or s.rows_max or 1))
  local base = min(max(1, floor((s.rows_rate or 1) + EPS)), hard)
  if not s.grow or (s.pairs_dep or 0) <= 0 then return base, "demande" end
  local pairs_use = min(s.pairs_dep, s.pairs_line or s.pairs_dep)
  local want = floor(pairs_use * (s.drill_rate or 0) / math.max(s.cap or 0, EPS) + EPS) -- rangées que ces foreuses nourrissent
  if want <= base then return base, "demande" end
  local rows, why = want, "gisement"
  if s.rows_max and rows > s.rows_max then rows, why = s.rows_max, "emprise" end
  if s.rows_fit and rows > s.rows_fit then rows, why = s.rows_fit, "emprise" end
  if s.budget_rows and rows > s.budget_rows then rows, why = s.budget_rows, "budget" end
  if s.out_ok then
    while rows > base and not s.out_ok(rows) do rows, why = rows - 1, "sortie" end
  end
  if rows <= base then return base, why == "gisement" and "demande" or why end
  return rows, why
end

--- Disposition des bras et des coffres de sortie autour du DERNIER tuile d'un tapis. Coordonnées (a, l) : `a` le long du
--- sens du tapis (1 = tuile suivante), `l` en travers (1 = du côté EXTÉRIEUR du module). Chaque élément : arm = {a, l} (le bras,
--- qui prend sur le dernier tuile), chest = {a, l} (le coffre où il dépose), drop = {a, l} (sens du dépôt, vecteur unitaire).
--- count = 1 : le quai d'avant (devant le bout) ; 2 : plus un bras sur le côté extérieur.
function L.fan(count)
  local out = { { arm = { 1, 0 }, chest = { 2, 0 }, drop = { 1, 0 } } }
  if (count or 1) >= 2 then out[#out + 1] = { arm = { 0, 1 }, chest = { 0, 2 }, drop = { 0, 1 } } end
  return out
end

return L
