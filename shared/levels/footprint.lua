--[[
  Niveaux : EMPRISE AU SOL qui grandit avec les époques (lot V3-T ; Q23 et Q24 du Directeur Créatif).
  Pur Lua : géométrie des carrés de tuiles, testable hors jeu (tests/levels_test.lua). Aucune dépendance :
  la TABLE des côtés (par famille et par niveau) vit dans shared/levels/config.lua (L.footprints,
  L.footprint) ; ce module ne fait que la géométrie. Lu par prototypes/levels/common.lua (boîtes des
  prototypes) et script/levels/levels.lua (place, position, contour, migration).

  Q24 (22/10, 7 h 40) : « agrandissement sur place si la place autour est libre ; sinon l'amélioration est
  refusée et le contour nécessaire s'affiche. »

  Conventions :
  - un CARRÉ de tuiles est { x0, y0, x1, y1 } en coordonnées de carte ENTIÈRES, demi-ouvert : il couvre les
    tuiles x0 .. x1 - 1 et y0 .. y1 - 1 ; son côté est x1 - x0 ;
  - le CENTRE d'un bâtiment de côté pair tombe sur un coin de tuile (x entier), celui d'un côté impair au
    milieu d'une tuile (x + 0,5) : c'est la parité du moteur (F41) ;
  - boîtes des prototypes au style vanilla : sélection = le carré exact (± côté / 2), collision = le carré
    réduit de MARGIN = 0,3 tuile de chaque côté (mitrailleuse 2×2 : ± 0,7 ; machine 3×3 : ± 1,2 ; roboport
    4×4 : ± 1,7, relevés par tests/datastage/harness.lua --dump-proto). La marge laisse passer le joueur entre
    deux bâtiments et rend inoffensif le contact bord à bord.

  =====================================================================================================
  RÈGLE DE POSITION (lot V3-T), mot pour mot :
  Le nouveau bâtiment (côté b) CONTIENT l'ancien (côté a, a ≤ b), aligné sur la grille des tuiles. Les
  positions candidates sont tous les carrés b × b qui contiennent le carré a × a de l'ancien, soit
  (b − a + 1)² positions. Ordre de préférence, DÉTERMINISTE :
    1. la plus centrée d'abord : le plus petit écart dx² + dy² entre le centre du nouveau carré et celui de
       l'ancien ;
    2. à écart égal, un ordre fixe qui dépend de la parité du côté visé : côté IMPAIR, le nord d'abord puis
       l'ouest (dy croissant, puis dx croissant) ; côté PAIR, le sud d'abord puis l'est (dy décroissant,
       puis dx décroissant).
  La première position LIBRE est retenue. Aucune n'est libre : l'amélioration est refusée (motif
  « no-room »), rien n'est payé, et le contour de la position PRÉFÉRÉE (la première de la liste) s'affiche
  avec ce qui la bloque.
  Conséquence voulue de l'alternance : en montant d'une taille à la fois (2 → 3 → 4 → 5 → 6), le bâtiment
  se décale d'une demi-tuile vers le nord-ouest aux tailles impaires et revient sur son centre d'ORIGINE aux
  tailles paires (sans elle, il dériverait d'une tuile et demie vers le nord-ouest en quatre étapes).
  Côté plus petit (b < a ; migration seulement, si la table venait à rétrécir) : le nouveau carré est
  CONTENU dans l'ancien, même ordre.
  =====================================================================================================

  Ce qui bloque une position (décidé ici, appliqué par script/levels/levels.lua) :
  - une TUILE du carré qui entre en collision avec le masque du nouveau prototype (eau, eau profonde, hors
    carte : couches « water-tile », « player-layer »… selon le masque) ;
  - une ENTITÉ dont la boîte de collision touche la boîte de collision du nouveau bâtiment ET dont le masque
    partage une couche avec le sien, SAUF l'ancien bâtiment lui-même et les types que le moteur pousse ou
    laisse sous un bâtiment posé (personnage : écarté par create_entity{move_stuck_players = true} ; unité ;
    objet au sol, qui reste ramassable) ;
  - jamais une ressource (couche « resource-layer », absente du masque des bâtiments : une foreuse se pose sur
    le minerai), ni un décor (les décors du nouveau carré sont retirés, comme sous un bâtiment posé à la main).
]]

local F = {}

--- Marge de collision (tuile) : boîte de collision = carré exact réduit de MARGIN de chaque côté.
F.MARGIN = 0.3
--- Tolérance des comparaisons de boîtes (contact bord à bord = pas de collision).
F.EPS = 1e-6

local function round(v) return math.floor(v + 0.5) end

--- Côté d'un carré de tuiles.
function F.side(box) return box.x1 - box.x0 end

--- Carré de tuiles d'un bâtiment de côté `side` centré en `pos` ({x, y}) : aligné sur la grille (arrondi au
--- plus proche si la position ne l'est pas, cas d'une sauvegarde dont le prototype a changé de taille).
function F.tile_box(pos, side)
  local x0 = round(pos.x - side / 2)
  local y0 = round(pos.y - side / 2)
  return { x0 = x0, y0 = y0, x1 = x0 + side, y1 = y0 + side }
end

--- Centre d'un carré : { x, y }.
function F.center(box)
  return { x = (box.x0 + box.x1) / 2, y = (box.y0 + box.y1) / 2 }
end

--- La position est-elle sur la grille d'un bâtiment de côté `side` (parité du moteur) ?
function F.aligned(pos, side)
  local c = F.center(F.tile_box(pos, side))
  return math.abs(c.x - pos.x) < F.EPS and math.abs(c.y - pos.y) < F.EPS
end

--- Boîtes de prototype (format de l'étape data, { {x, y}, {x, y} }) d'un bâtiment de côté `side` : collision,
--- sélection.
function F.proto_boxes(side, margin)
  local h = side / 2
  local c = h - (margin or F.MARGIN)
  return { { -c, -c }, { c, c } }, { { -h, -h }, { h, h } }
end

--- Boîte de collision (coordonnées de carte) d'un bâtiment qui occupe le carré `box`.
function F.collision_rect(box, margin)
  local m = margin or F.MARGIN
  return { x0 = box.x0 + m, y0 = box.y0 + m, x1 = box.x1 - m, y1 = box.y1 - m }
end

--- Deux rectangles { x0, y0, x1, y1 } se chevauchent-ils (strictement : le contact bord à bord ne compte pas) ?
function F.overlap(a, b)
  return a.x0 < b.x1 - F.EPS and b.x0 < a.x1 - F.EPS and a.y0 < b.y1 - F.EPS and b.y0 < a.y1 - F.EPS
end

--- `outer` contient-il `inner` (carrés de tuiles) ?
function F.contains(outer, inner)
  return outer.x0 <= inner.x0 and outer.y0 <= inner.y0 and outer.x1 >= inner.x1 and outer.y1 >= inner.y1
end

--- Positions candidates pour passer du carré `old` au côté `side`, dans l'ORDRE DE PRÉFÉRENCE (règle en
--- tête du fichier). Chaque candidate : { box, x, y (centre), dx, dy (écart au centre de l'ancien), d2 }.
function F.candidates(old, side)
  local a = F.side(old)
  local oc = F.center(old)
  local list = {}
  local lo_x, hi_x, lo_y, hi_y
  if side >= a then
    lo_x, hi_x, lo_y, hi_y = old.x1 - side, old.x0, old.y1 - side, old.y0
  else
    lo_x, hi_x, lo_y, hi_y = old.x0, old.x1 - side, old.y0, old.y1 - side
  end
  for y0 = lo_y, hi_y do
    for x0 = lo_x, hi_x do
      local box = { x0 = x0, y0 = y0, x1 = x0 + side, y1 = y0 + side }
      local c = F.center(box)
      local dx, dy = c.x - oc.x, c.y - oc.y
      list[#list + 1] = { box = box, x = c.x, y = c.y, dx = dx, dy = dy, d2 = dx * dx + dy * dy }
    end
  end
  -- dx et dy sont des multiples de 0,5 : d2 est exact (multiples de 0,25), les égalités sont franches. Les
  -- candidates ont des (dx, dy) tous différents : l'ordre est total.
  local odd = side % 2 == 1
  table.sort(list, function(p, q)
    if p.d2 ~= q.d2 then return p.d2 < q.d2 end
    if odd then
      if p.dy ~= q.dy then return p.dy < q.dy end
      return p.dx < q.dx
    end
    if p.dy ~= q.dy then return p.dy > q.dy end
    return p.dx > q.dx
  end)
  return list
end

--- Rectangle de recherche : réunion de toutes les candidates (une seule requête au moteur pour toutes).
function F.search_box(old, side)
  local a = F.side(old)
  if side >= a then
    return { x0 = old.x1 - side, y0 = old.y1 - side, x1 = old.x0 + side, y1 = old.y0 + side }
  end
  return { x0 = old.x0, y0 = old.y0, x1 = old.x1, y1 = old.y1 }
end

--- Évalue les candidates dans l'ordre. tiles : tuiles bloquantes { {x, y, name} } (coin nord-ouest de la
--- tuile) ; blockers : entités bloquantes { {box = {x0, y0, x1, y1} (boîte de collision, carte), name, ...} }.
--- Chaque candidate évaluée reçoit `tiles` et `entities` (ce qui la touche, dans l'ordre des listes) et `free`.
--- Renvoie { index, chosen (nil si aucune libre), preferred (= candidates[1]), candidates } ; l'évaluation
--- s'arrête à la première libre (la préférée est toujours évaluée).
function F.evaluate(cands, tiles, blockers, margin)
  local res = { candidates = cands, preferred = cands[1] }
  for i, c in ipairs(cands) do
    local rect = F.collision_rect(c.box, margin)
    local ht, he = {}, {}
    for _, t in ipairs(tiles or {}) do
      if t.x >= c.box.x0 and t.x < c.box.x1 and t.y >= c.box.y0 and t.y < c.box.y1 then ht[#ht + 1] = t end
    end
    for _, b in ipairs(blockers or {}) do
      if F.overlap(rect, b.box) then he[#he + 1] = b end
    end
    c.tiles, c.entities, c.free = ht, he, (#ht == 0 and #he == 0)
    if c.free then
      res.index, res.chosen = i, c
      return res
    end
  end
  return res
end

--- Différences entre deux relevés d'emprise { [clé] = { côté du niveau 1, côté du niveau 2, ... } }, dans
--- l'ordre de `keys` puis des niveaux : { {key, level, from, to} }. `old` absent pour une clé ou un niveau :
--- `default(clé)` (côté d'une sauvegarde d'avant le lot V3-T : le côté de base de la famille).
function F.diff(old, new, keys, default)
  local out = {}
  for _, k in ipairs(keys) do
    local o, n = old and old[k], new[k]
    for lv = 1, #n do
      local from = (o and o[lv]) or default(k)
      if from ~= n[lv] then out[#out + 1] = { key = k, level = lv, from = from, to = n[lv] } end
    end
  end
  return out
end

return F
