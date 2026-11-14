--[[
  Lot REMPLISSAGE (retour du DC du 8/11, 0.6.65) : « les coffres ils sont jamais remplis au max, donc en plus il faut les remplir
  régulièrement [...] quand on a 150 000 [cuivre] répartis dans tous les coffres, je pense que on peut se permettre de mettre des coffres
  pleins pour les petits îlots [...] pour éviter que la production elle se stoppe complètement. »

  Règle PURE de la CIBLE de remplissage d'un quai (coffre d'entrée d'un module du plan directeur), à la suite de la règle ordinaire
  (script/team/build.lua quai_tasks : Build.QUAI_LOW = 60, Build.QUAI_FILL = 400, ou la minute d'ingrédients du lot VIDEO L4) :
    - stock JUSTE : la cible ordinaire, à l'identique (R.level rend base_want et base_low) ;
    - stock ABONDANT (au moins R.MULT_IN fois le besoin ordinaire de TOUS les quais de l'objet) : la cible monte jusqu'à la capacité
      RÉELLE du coffre (lue par l'appelant : contenu + place restante, barre respectée, F95), bornée par la PART du quai (R.SHARE_PM ‰ du
      stock partagés entre les quais de l'objet : aucun quai ne vide le stock aux dépens des autres) ; le seuil de relance monte avec la cible
      (R.LOW_PM ‰ de la cible) : on revient avant que le coffre soit vide ;
    - HYSTÉRÉSIS : un quai abondant le reste jusqu'à ce que le stock retombe sous R.MULT_OUT fois le besoin (pas de va-et-vient) ;
    - un voyage porte un plein chargement (R.refill borne le compte par la capacité du sac, que l'appelant lit) : au-delà, la tâche
      « prendre » stricte du PNJ échouerait chaque fois.
  Aucun nom d'objet, aucune API du jeu, aucun `pairs` décisionnel, entiers seulement : testé hors jeu (tests/remplissage_test.lua).
]]

local R = {}

R.MULT_IN = 4       -- abondant : stock >= 4 x le besoin ordinaire de tous les quais de l'objet
R.MULT_OUT = 2      -- un quai abondant le reste jusqu'à stock < 2 x ce besoin
R.SHARE_PM = 700    -- ‰ du stock qu'on accepte de répartir dans les coffres (le reste sert aux fabrications du QG)
R.LOW_PM = 400      -- ‰ : seuil de relance d'un coffre à cible haute (cible x 0,4)
R.BAG_RESERVE = 4   -- cases du sac gardées libres (lues par l'appelant : slots - BAG_RESERVE)
R.CHANGE_PM = 250   -- ‰ : une ligne de journal quand la cible bouge d'au moins ce rapport (ou quand la cause change)

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

local function num(v, d) if type(v) == "number" and v == v then return v end return d or 0 end

--- Besoin ordinaire total d'un objet : somme des cibles ordinaires de ses quais (liste d'entiers). Rend (somme, nombre de quais).
function R.need(wants)
  local s, n = 0, 0
  for _, w in ipairs(wants or {}) do s, n = s + max(0, floor(num(w))), n + 1 end
  return s, n
end

--- Part du stock accordée à CHAQUE quai de l'objet (borne par quai) : SHARE_PM ‰ du stock / nombre de quais.
function R.share(stock, nq)
  return floor(max(0, num(stock)) * R.SHARE_PM / 1000 / max(1, floor(num(nq, 1))))
end

--- Niveau de remplissage d'un quai. a = {
---   base_want, base_low : cible et seuil ordinaires (règle d'avant le lot) ;
---   cap : capacité RÉELLE du coffre pour l'objet (contenu + place restante, barre respectée) ;
---   stock : stock de l'objet ; need : besoin ordinaire total de ses quais ; nq : nombre de ses quais ;
---   was : le quai était abondant au dernier calcul }.
--- Rend { want, low, cause = "abondant" | "juste", bound }.
--- Lot s45 BUFFERS : entre le besoin ordinaire (seuil de sécurité) et l'abondance (R.MULT_IN x le besoin), la cible ne retombe plus
--- d'un bloc à la minute d'ingrédients : le stock LIBRE (stock - besoin ordinaire de tous les quais de l'objet, qui reste réservé)
--- est partagé (R.SHARE_PM ‰, par quai) au-dessus de la cible ordinaire, borné par la place du coffre. Sous le besoin : à l'identique.
--- Rend { want, low, cause = "proportionnel" | "juste", bound }.
function R.proportional(bw, bl, cap, stock, need, nq)
  if stock <= need then return { want = bw, low = bl, cause = "juste", bound = 0 } end
  local bound = bw + R.share(stock - need, nq)
  local want = max(bw, min(cap, bound))
  if want <= bw then return { want = bw, low = bl, cause = "juste", bound = bound } end
  return { want = want, low = min(want - 1, max(bl, ceil(want * R.LOW_PM / 1000))), cause = "proportionnel", bound = bound }
end

function R.level(a)
  local bw = max(1, floor(num(a.base_want, 1)))
  local bl = max(1, floor(num(a.base_low, 1)))
  local stock, nq = max(0, num(a.stock)), max(1, floor(num(a.nq, 1)))
  local need = max(bw, floor(num(a.need)))
  local mult = a.was and R.MULT_OUT or R.MULT_IN
  if num(a.cap) <= 0 then return { want = bw, low = bl, cause = "juste", bound = 0 } end
  if stock < need * mult then return R.proportional(bw, bl, floor(a.cap), stock, need, nq) end
  local bound = R.share(stock, nq)
  local want = max(bw, min(floor(a.cap), bound))
  if want <= bw then return { want = bw, low = bl, cause = "juste", bound = bound } end -- part trop petite : rien ne change
  return { want = want, low = min(want - 1, max(bl, ceil(want * R.LOW_PM / 1000))), cause = "abondant", bound = bound }
end

--- Tournée de remplissage : n objets au coffre, have au stock, bag = capacité du sac en objets (nil : sans borne).
--- Rend { due, count } : dû sous `low`, jusqu'à `want`, borné au stock et au sac.
function R.refill(want, low, n, have, bag)
  n, have = max(0, num(n)), max(0, num(have))
  if n >= low or have <= 0 then return { due = false, count = 0 } end
  local c = min(want - n, have)
  if type(bag) == "number" and bag >= 1 then c = min(c, floor(bag)) end
  c = max(0, floor(c))
  return { due = c > 0, count = c }
end

--- Faut-il écrire une ligne de journal ? prev = { cible, cause } du dernier calcul (nil : premier), lvl = résultat de R.level.
--- Oui à la première fois seulement si la cause n'est pas « juste » (le cas ordinaire ne dit rien), quand la cause change, ou quand la cible
--- change d'au moins R.CHANGE_PM ‰.
function R.changed(prev, lvl)
  if not prev then return lvl.cause ~= "juste" end
  if prev.cause ~= lvl.cause then return true end
  if lvl.cause == "juste" then return false end
  local a, b = max(1, num(prev.cible, 1)), lvl.want
  return math.abs(b - a) * 1000 >= a * R.CHANGE_PM
end

return R
