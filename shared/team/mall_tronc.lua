--[[
  Lot MALL, tranche 3 (docs/MALL.md §2.2, §2.3, directive du DC du 9/11 : « un bus qui alimente, pas des quais remplis à la main ») : le TRONC du mall et ses PRISES. Règle PURE :
  aucune API du jeu, aucun nom d'objet. Testée hors jeu : tests/mall_tronc_test.lua.

  Repère : celui de la rangée 1 (shared/team/mall_rangee.lua), coordonnées ABSOLUES (y ne dépend pas de la rangée : une rangée j commence en y = 15 (j − 1)).
  Le tronc : K lignes verticales (vers le sud), UN objet par ligne (les deux voies), à l'ouest de la tête des rangées. Ligne k : colonne Mt.XL(k) = −8 − 3 (k − 1). Trois colonnes par ligne :
  la ligne, la sortie de son répartiteur (xL + 1), l'entrée du souterrain vers l'est (xL + 2). Une ligne monte jusqu'en Y_TOP = −3 ; ses quais de tête (un coffre et un bras par ranger, à
  l'ouest) en y = −1 et y = −3 et, plus tard, les arrivées de tapis (fin de tranche : une arrivée de tapis se pose sur la tuile la plus haute de la ligne).

  Une PRISE vers un tapis de rangée à la hauteur Y (ya = 6 + 15 (j − 1) pour le tapis A, yb = ya + 1 pour le tapis B) :
    répartiteur vers le sud sur (xL, Y − 1) et (xL + 1, Y − 1), sa sortie gauche continue la ligne ; sa sortie droite, en (xL + 1, Y), est un tapis qui tourne vers l'est ;
    pour la ligne 1, ce tapis est en x = −7 : c'est le premier tapis de l'amenée de la rangée. Pour une ligne plus à l'ouest : l'entrée d'un souterrain en (xL + 2, Y), qui passe sous les
    lignes plus proches et ressort en x = −7 : portée lue au prototype, xL(3) + 2 = −12 → −7 : distance 5, le souterrain jaune (max_distance 5) l'atteint.
    Amenée : de x = −6 à x = −1 à la même hauteur, vers l'est : les cellules de la rangée la prolongent.
  Une rangée alimentée par le tronc porte un objet par tapis (voies = { A, A, B, B }) ; A vient de la ligne de plus petit numéro (sinon la sortie du souterrain de A tombait sur le répartiteur
  de la ligne 1 de B). Toutes les lignes existantes descendent jusqu'à yb de la rangée demandée : on ajoute, on ne remplace rien.
  Déterminisme : listes en ordre fixe, aucun pairs.
]]

local Mt = {}

Mt.KMAX = 3
Mt.Y_TOP = -3
Mt.WEST = 16        -- tuiles à l'ouest de x = 0 : la ligne 3 (x = −14) et ses coffres de tête (x = −16)
Mt.NORTH = 3        -- tuiles au nord de y = 0
Mt.EXIT_X = -7      -- abscisse de la sortie des souterrains et de la curve de la ligne 1
Mt.LEAD_FROM = -6   -- premier tapis de l'amenée (jusqu'à x = −1)
Mt.YA0, Mt.YB0 = 6, 7

function Mt.XL(k) return -8 - 3 * (k - 1) end

--- Ligne neuve : { k, item, y_to } (y_to = dernière tuile de la ligne déjà prévue, nil tant que rien n'est prévu).
function Mt.ligne(k, item) return { k = k, item = item, y_to = nil } end

--- Portée qu'il faut à la ligne k : distance de la sortie à l'entrée du souterrain (jaune = 5).
function Mt.portee(k) return Mt.EXIT_X - (Mt.XL(k) + 2) end

--- La rangée `row` (row.bus = { a = k_A, b = k_B ou nil }) : hauteurs de ses deux tapis (canoniques, absolues).
local function heights(row)
  local o = (row.j - 1) * 15
  return Mt.YA0 + o, Mt.YB0 + o
end
Mt.heights = heights

--- Entités de la TÊTE de la ligne (k, item) : tapis de y = −3 à −1, bras et coffres de quai en y = −1 et y = −3, poteau entre les deux. Rend { ents, quais }.
function Mt.tete_ligne(k, item, names)
  local x = Mt.XL(k)
  local ents, quais = {}, {}
  for y = Mt.Y_TOP, -1 do ents[#ents + 1] = { name = names.tapis, x = x + 0.5, y = y + 0.5, dir = 4, role = "mall-tronc", carries = { item } } end
  for _, y in ipairs({ -1, -3 }) do
    ents[#ents + 1] = { name = names.bras, x = x - 0.5, y = y + 0.5, dir = 6, role = "quai-bras" } -- prend à l'ouest, dépose sur la ligne
    ents[#ents + 1] = { name = names.coffre, x = x - 1.5, y = y + 0.5, dir = 0, role = "quai", item = item }
    quais[#quais + 1] = { x = x - 1.5, y = y + 0.5, item = item }
  end
  ents[#ents + 1] = { name = names.poteau, x = x - 0.5, y = -1.5, dir = 0, role = "mall-poteau" }
  return { ents = ents, quais = quais }
end

--- Prises et amenée d'un tapis de rangée à la hauteur Y depuis la ligne k. item = objet de la ligne. Rend la liste d'entités (hors tuiles de la ligne : le répartiteur les remplace).
local function prise(k, item, Y, names)
  local ents = {}
  local x = Mt.XL(k)
  local route = { { x = x + 1, y = Y, dir = 2 } }
  if k > 1 then
    route[#route + 1] = { x = x + 2, y = Y, dir = 2, ug = "input" }
    route[#route + 1] = { x = Mt.EXIT_X, y = Y, dir = 2, ug = "output" }
  end
  for lx = Mt.LEAD_FROM, -1 do route[#route + 1] = { x = lx, y = Y, dir = 2 } end
  -- répartiteur vers le sud sur les tuiles (x, Y − 1) et (x + 1, Y − 1) : centre en (x + 1, Y − 0,5)
  ents[#ents + 1] = { name = names.repartiteur, x = x + 1, y = Y - 1 + 0.5, dir = 4, role = "mall-prise", carries = { item } }
  ents[#ents + 1] = { name = names.tapis, x = x + 1.5, y = Y + 0.5, dir = 2, role = "mall-prise", carries = { item } } -- sortie droite du répartiteur, tourne vers l'est
  if k > 1 then
    ents[#ents + 1] = { name = names.souterrain, x = x + 2.5, y = Y + 0.5, dir = 2, role = "mall-prise", carries = { item }, type = "input" }
    ents[#ents + 1] = { name = names.souterrain, x = Mt.EXIT_X + 0.5, y = Y + 0.5, dir = 2, role = "mall-prise", carries = { item }, type = "output" }
  end
  for lx = Mt.LEAD_FROM, -1 do ents[#ents + 1] = { name = names.tapis, x = lx + 0.5, y = Y + 0.5, dir = 2, role = "mall-amenee", carries = { item } } end
  return ents, route
end

--- Section du tronc pour la rangée `row` : prolonge chaque ligne jusqu'à yb, pose les prises des deux tapis, l'amenée. lines = liste de { k, item, y_to } (toutes les lignes existantes) ;
--- names = { tapis, bras, coffre, poteau, repartiteur, souterrain }. N'écrit RIEN dans `lines` ; rend { ents, quais, y_to = { [k] = y }, routes }, les poteaux de liaison compris pour la rangée 1
--- (entre la tête des lignes et le premier poteau de cellule). routes = liste { item, tiles = { x, y, dir, ug } } dans l'ordre du flux, contiguës (une ligne est coupée au répartiteur) :
--- le contrôle de pureté (shared/team/purete.lua, Pu.check). opts.sans_reinjection (s42 bus-continu) : sans le quai de réinjection (ses tuiles sont prises dans le monde : la section se pose
--- quand même, la ligne reste continue). Les pièces du quai de réinjection portent reinj = true.
function Mt.section(lines, row, names, opts)
  local ents, quais = {}, {}
  local ya, yb = heights(row)
  local split_y = {} -- y du répartiteur par ligne (prise de la rangée) : nil sans prise
  if row.bus.a then split_y[row.bus.a] = ya - 1 end
  if row.bus.b then split_y[row.bus.b] = yb - 1 end
  local y_to, routes = {}, {}
  local premiere = true -- première section du tronc : aucune ligne n'est encore posée
  for _, ln in ipairs(lines) do if ln.y_to then premiere = false end end
  local function flush(seg, item)
    if #seg > 0 then routes[#routes + 1] = { item = item, tiles = seg } end
  end
  for _, ln in ipairs(lines) do
    local x = Mt.XL(ln.k)
    local start = ln.y_to and (ln.y_to + 1) or 0
    if not ln.y_to then
      local t = Mt.tete_ligne(ln.k, ln.item, names)
      for _, e in ipairs(t.ents) do ents[#ents + 1] = e end
      for _, q in ipairs(t.quais) do quais[#quais + 1] = q end
    end
    for y = start, yb do
      if y ~= split_y[ln.k] then ents[#ents + 1] = { name = names.tapis, x = x + 0.5, y = y + 0.5, dir = 4, role = "mall-tronc", carries = { ln.item } } end
    end
    y_to[ln.k] = yb
    local seg = {}
    for y = ln.y_to and start or Mt.Y_TOP, yb do
      if y == split_y[ln.k] then
        flush(seg, ln.item)
        seg = {}
      else
        seg[#seg + 1] = { x = x, y = y, dir = 4 }
      end
    end
    flush(seg, ln.item)
  end
  local function item_of(k) for _, ln in ipairs(lines) do if ln.k == k then return ln.item end end end
  local function poser(k, Y)
    local list, route = prise(k, item_of(k), Y, names)
    for _, e in ipairs(list) do ents[#ents + 1] = e end
    flush(route, item_of(k))
  end
  if row.bus.a then poser(row.bus.a, ya) end
  if row.bus.b then poser(row.bus.b, yb) end
  -- RÉINJECTION (s41) : une ligne déjà posée (donc déjà dérivée par une rangée d'avant) que CETTE rangée dérive encore reçoit un quai de plus (bras et coffre à l'ouest, comme à la tête),
  -- dans la tuile de passage au nord de la rangée, en amont de la prise : sans lui, la tête (deux bras) nourrissait seule toutes les prises et le débit en aval tombait de moitié à chacune.
  -- Poteaux : deux relais depuis le poteau de passage (3,5) puis un poteau par ligne, de la ligne 1 à la plus lointaine réinjectée (fils ≤ 5,1 tuiles). Rien n'est remplacé.
  do
    local kmax = 0
    for _, ln in ipairs(lines) do if ln.y_to and split_y[ln.k] and ln.k > kmax then kmax = ln.k end end
    if kmax > 0 and not (opts and opts.sans_reinjection) then
      local yp = (row.j - 1) * 15 - 1
      ents[#ents + 1] = { name = names.poteau, x = -1.5, y = yp + 0.5, dir = 0, role = "mall-poteau", reinj = true }
      ents[#ents + 1] = { name = names.poteau, x = -6.5, y = yp + 0.5, dir = 0, role = "mall-poteau", reinj = true }
      for _, ln in ipairs(lines) do
        if ln.k <= kmax then
          local x = Mt.XL(ln.k)
          ents[#ents + 1] = { name = names.poteau, x = x - 0.5, y = yp - 0.5, dir = 0, role = "mall-poteau", reinj = true }
          if ln.y_to and split_y[ln.k] then
            ents[#ents + 1] = { name = names.bras, x = x - 0.5, y = yp + 0.5, dir = 6, role = "quai-bras", reinj = true }
            ents[#ents + 1] = { name = names.coffre, x = x - 1.5, y = yp + 0.5, dir = 0, role = "quai", item = ln.item, reinj = true }
            quais[#quais + 1] = { x = x - 1.5, y = yp + 0.5, item = ln.item }
          end
        end
      end
    end
  end
  if row.j > 1 then
    -- (comme la tête d'une rangée à quais) relais vers la rangée précédente, dans la tuile de passage
    ents[#ents + 1] = { name = names.poteau, x = 3.5, y = (row.j - 1) * 15 - 0.5, dir = 0, role = "mall-poteau" }
    -- tronc commencé au-delà de la première rangée (les rangées d'avant sont à quais) : relais au nord de la rangée 1, à portée de fil du poteau de sa tête (−4,5 ; 4,5). Une ligne ajoutée à un tronc
    -- existant se raccorde au poteau de la ligne voisine.
    if premiere then ents[#ents + 1] = { name = names.poteau, x = -4.5, y = -1.5, dir = 0, role = "mall-poteau" } end
  else
    -- liaison de poteaux entre la tête des lignes (poteau de la ligne 1, x = −8,5, y = −1,5) et le premier poteau de cellule (3,5 ; 3,5) : fils ≤ 5,7 tuiles
    ents[#ents + 1] = { name = names.poteau, x = -4.5, y = -1.5, dir = 0, role = "mall-poteau" }
    ents[#ents + 1] = { name = names.poteau, x = -0.5, y = 2.5, dir = 0, role = "mall-poteau" }
  end
  return { ents = ents, quais = quais, y_to = y_to, routes = routes }
end

--- (s41 raccord-mall) Vrai si cette tuile de la PLACE du tronc (x de −WEST à −1, y ≥ Y_TOP, repère canonique) n'est utilisée par aucune ligne, tête, prise, amenée ni quai de réinjection, quel que
--- soit le nombre de lignes et de rangées : une chaîne de poteaux peut y passer. La place entière était fermée au raccord : 16 tuiles de profondeur entre les têtes des rangées et la base, plus
--- que la portée d'un fil : aucune rangée ne rejoignait le réseau (partie du DC 0.7.95 : rangées 1, 2 et 3 refusées « sans chaine »). Ouvert : la tuile entre les deux coffres de chaque tête ;
--- à l'ouest de la dernière ligne (y ≥ 0) ; les trois tuiles au nord de la tuile de passage (y mod 15 = 11 à 13 : sous les prises, y mod 15 = 5 à 7), hors colonnes des lignes et hors des
--- tuiles de tête (x ≥ LEAD_FROM, laissées aux rangées à quais).
--- (s42 bus-continu) La tuile de PASSAGE elle-même (y mod 15 = 14) est RÉSERVÉE au quai de réinjection (bras en xL − 1, coffre en xL − 2, relais en −7 et −2), avec la tuile de son poteau
--- (xL − 1, y mod 15 = 13) : un poteau de chaîne posé là faisait refuser « obstacle » la section de la rangée suivante. Le couloir de la chaîne passe une à trois tuiles plus au nord. Pur.
function Mt.place_libre(rx, ry)
  if rx >= 0 or rx < -Mt.WEST or ry < Mt.Y_TOP then return false end
  local ligne, coffre, bras = false, false, false
  for k = 1, Mt.KMAX do
    if rx == Mt.XL(k) then ligne = true end
    if rx == Mt.XL(k) - 1 then bras = true end
    if rx == Mt.XL(k) - 2 then coffre = true end
  end
  if ry < 0 then return coffre and ry == Mt.Y_TOP + 1 end
  local m = ry % 15
  if m == 14 or (m == 13 and bras) then return false end
  if rx < Mt.XL(Mt.KMAX) then return true end
  return m >= 11 and rx < Mt.LEAD_FROM and not ligne
end

return Mt
