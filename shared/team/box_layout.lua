--[[
  Lot BOX-LAYOUT (directive du DC du 9/11) : URBANISME PAR GABARITS RÉSERVÉS.
  Quand une ligne d'assembleurs ou de fours est posée tôt, le quadrillage réserve l'EMPREINTE DE L'ÂGE CIBLE (3×3 réservé
  même si l'on pose un four 2×2 aujourd'hui) ; bras et convoyeurs sont posés sur la LIGNE D'INTERFACE de l'empreinte cible,
  pour absorber le gabarit final sans déplacement ultérieur ; avant tout agrandissement, garde-fou anti-collision : la
  règle pure décide « upgrade » ou « ajourne » depuis un résultat de can_place_entity FOURNI par le moteur (jamais appelé ici).

  Règles PURES : aucun moteur, aucun `game`, aucun nom d'objet du jeu. Les tailles { w, h } sont lues par l'appelant dans
  M.spec(name) de shared/team/modules.lua (champs w, h ; niveaux : côté de L.footprint, shared/levels/config.lua L.footprints).
  Convention de grille : une cellule { x, y, w, h } = coin nord-ouest (x, y) en tuiles entières, w vers l'est, h vers le sud ;
  une case est désignée par la clé Bl.key(x, y) = "x,y".

  Centrage déterministe : la machine actuelle est centrée dans la cellule réservée, les différences impaires arrondies vers le
  coin haut-gauche (marge nord/ouest = ⌊d/2⌋, marge sud/est = ⌈d/2⌉). L'agrandissement futur (Bl.grown) applique la même règle
  à l'envers : le nouveau bâtiment CONTIENT l'ancien et ne sort jamais de la cellule réservée.

  LIMITE PHYSIQUE de l'interface (Bl.interface) : un bras de portée 1 posé contre le bord de l'empreinte CIBLE n'atteint que la
  première case de la cellule ; il touche la machine actuelle seulement si sa marge de ce côté vaut 0 ; marge 1 : bras LONG
  (portée 2) ; marge ≥ 2 : aucun bras n'y arrive (impossible = true). Avec le centrage haut-gauche, une différence de 1 par
  axe (2×2 → 3×3) laisse l'entrée (nord) à portée courte et la sortie (sud) à portée longue ; une différence de 2 (3×3 → 5×5)
  exige un bras long des deux côtés ; au-delà de 3, un côté est hors de portée : le gabarit n'est pas évolutif sans déplacement.

  Déterminisme : aucun `pairs`, aucun temps ; mêmes entrées, même sortie ; les listes de conflits sont triées (x puis y).
]]

local Bl = {}

Bl.UPGRADE, Bl.AJOURNE = "upgrade", "ajourne"
Bl.REACH_SHORT, Bl.REACH_LONG = 1, 2 -- portées d'un bras ordinaire et d'un bras long (tuiles)

--- Clé d'une case.
function Bl.key(x, y) return x .. "," .. y end

local function dim(t, k) return (t and type(t[k]) == "number") and t[k] or 0 end

--- Empreinte RÉSERVÉE { w, h } : maximum par axe de la machine posée aujourd'hui et de celle de l'âge cible. `target` nil :
--- l'empreinte actuelle (rien à réserver de plus). Jamais nil.
function Bl.footprint(now, target)
  if not target then target = now end
  if not now then now = target end
  return { w = math.max(dim(now, "w"), dim(target, "w")), h = math.max(dim(now, "h"), dim(target, "h")) }
end

--- Marges (nord, sud) ou (ouest, est) d'une longueur `inner` centrée dans `outer` : impair arrondi vers le haut-gauche.
local function margins(outer, inner)
  local d = math.max(0, outer - inner)
  local a = math.floor(d / 2)
  return a, d - a
end

--- Position relative (coin nord-ouest, { x, y }) d'une machine `size` centrée dans la cellule `cell` { w, h } (les champs x, y
--- de la cellule, s'ils existent, ne sont pas ajoutés : offsets purs). Différence impaire : vers le haut-gauche.
function Bl.anchor_of(cell, size)
  local mx = margins(dim(cell, "w"), dim(size, "w"))
  local my = margins(dim(cell, "h"), dim(size, "h"))
  return { x = mx, y = my }
end

--- Position relative de la machine ACTUELLE `now` dans la cellule réservée. `cell` nil : la cellule est Bl.footprint(now, target).
--- Garantie : la machine cible, centrée par la même règle, contient l'actuelle et reste dans la cellule (voir Bl.grown).
function Bl.anchor(cell, now, target)
  cell = cell or Bl.footprint(now, target)
  return Bl.anchor_of(cell, now)
end

--- Pas entre deux couloirs de convoyeurs pour un ruban à deux rangées face à face : h cible × 2 + belts (largeur du couloir,
--- défaut 1) + 2 (un bras de chaque côté) + gap (passage libre, défaut 0). Nombre entier, jamais nil.
function Bl.pitch(target, belts, gap)
  return dim(target, "h") * 2 + (belts or 1) + 2 + (gap or 0)
end

--- Un bras de l'interface : posé contre le bord de l'empreinte CIBLE, la case qu'il atteint est à `margin` cases de la machine
--- actuelle. margin 0 : portée courte ; 1 : bras long ; ≥ 2 : hors de portée (impossible).
local function arm(x, y, margin)
  local reach = margin + 1
  return {
    x = x, y = y, margin = margin,
    long = margin >= 1,
    impossible = reach > Bl.REACH_LONG,
    reach = math.min(reach, Bl.REACH_LONG),
  }
end

--- LIGNE D'INTERFACE de l'empreinte cible : offsets (relatifs au coin nord-ouest de la cellule réservée) du bras d'entrée (au
--- nord, y = −1) et du bras de sortie (au sud, y = h), sur la colonne centrale de l'empreinte cible (arrondie vers l'ouest).
--- `now` (machine actuelle, défaut = target) sert à qualifier chaque bras : long (marge 1) ou impossible (marge ≥ 2).
--- Rend { w, h, ["in"] = bras, out = bras, long = un bras long au moins, impossible = un bras hors de portée, ok = aucun }.
function Bl.interface(target, now)
  local cell = Bl.footprint(now, target)
  now = now or target
  local cx = math.floor((cell.w - 1) / 2)
  local north, south = margins(cell.h, dim(now, "h"))
  local a_in, a_out = arm(cx, -1, north), arm(cx, cell.h, south)
  return {
    w = cell.w, h = cell.h,
    ["in"] = a_in, out = a_out,
    long = a_in.long or a_out.long,
    impossible = a_in.impossible or a_out.impossible,
    ok = not (a_in.impossible or a_out.impossible),
  }
end

--- Lot ILOTS-COLONNES (directive du DC du 10/11, P4 : « cellule réservée pour les îlots industriels structurés en colonnes ») : COLONNE
--- DE LIAISON entre deux cellules réservées voisines (chaque machine passe des objets à sa voisine par un bras posé dans la colonne qui
--- sépare les cellules). La colonne est la ligne d'interface EST de la cellule (x = cell.w, hors de toute cellule : aucun agrandissement
--- ne l'atteint, aucun bras à déplacer au rétrofit) ; de là, un bras doit atteindre la machine ACTUELLE de cette cellule (sa marge est
--- + 1) et celle de la voisine (sa marge ouest + 1, même géométrie). Rend { x, to_west, to_east, reach (le plus grand des deux), long
--- (reach ≥ REACH_LONG : bras long), impossible (reach > REACH_LONG : aucun bras n'y arrive, îlot non réservable), rows = hauteur de la
--- machine actuelle (lignes de la colonne qui la touchent), row0 = sa marge nord }. Pur, jamais nil.
function Bl.link(cell, now)
  local a = Bl.anchor_of(cell, now)
  local to_west = dim(cell, "w") - a.x - dim(now, "w") + 1
  local to_east = a.x + 1
  local reach = math.max(to_west, to_east)
  return { x = dim(cell, "w"), to_west = to_west, to_east = to_east, reach = reach, long = reach >= Bl.REACH_LONG,
    impossible = reach > Bl.REACH_LONG, rows = dim(now, "h"), row0 = a.y }
end

--- Rectangle { x, y, w, h } qu'occupera la machine agrandie à `new_size` depuis la cellule `cell` (machine actuelle) : le
--- nouveau bâtiment contient l'ancien, débordement d'une différence impaire vers le sud-est (inverse exact de Bl.anchor).
function Bl.grown(cell, new_size)
  local a = Bl.anchor_of(new_size, cell)
  return { x = cell.x - a.x, y = cell.y - a.y, w = math.max(dim(cell, "w"), dim(new_size, "w")), h = math.max(dim(cell, "h"), dim(new_size, "h")) }
end

--- Les cases d'un rectangle appartiennent-elles à un autre ? (test d'intersection de rectangles, entiers)
local function overlaps(a, b)
  return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local function cmp_xy(a, b)
  if a[1] ~= b[1] then return a[1] < b[1] end
  return a[2] < b[2]
end

--- La cellule i peut-elle accueillir `new_size` sans empiéter sur `occupied` ({ [Bl.key(x, y)] = true } : tapis, poteaux,
--- autres machines) ni sur les AUTRES cellules de `cells` ? Rend (ok, conflits) : conflits = clés des cases en conflit, triées
--- (x puis y), vide si ok. Pure et déterministe.
function Bl.grow(cells, i, new_size, occupied)
  local cell = cells[i]
  if not cell then return false, {} end
  local r = Bl.grown(cell, new_size)
  occupied = occupied or {}
  local pts = {}
  for y = r.y, r.y + r.h - 1 do
    for x = r.x, r.x + r.w - 1 do
      local inside_old = x >= cell.x and x < cell.x + cell.w and y >= cell.y and y < cell.y + cell.h
      local hit = occupied[Bl.key(x, y)] and not inside_old
      if not hit then
        for j, other in ipairs(cells) do
          if j ~= i and overlaps({ x = x, y = y, w = 1, h = 1 }, other) then hit = true; break end
        end
      end
      if hit then pts[#pts + 1] = { x, y } end
    end
  end
  table.sort(pts, cmp_xy)
  local out = {}
  for k, p in ipairs(pts) do out[k] = Bl.key(p[1], p[2]) end
  return #out == 0, out
end

--- Décision d'agrandissement : "upgrade" si le moteur dit que la nouvelle entité se pose (`can_place`, valeur de
--- can_place_entity) ET que la règle pure n'a vu aucun conflit (`ok`) ; sinon "ajourne" (l'unité attend, la box n'est pas
--- bloquée). Jamais nil : toute valeur autre que `true` compte pour un refus.
function Bl.decide(can_place, ok)
  if can_place == true and ok == true then return Bl.UPGRADE end
  return Bl.AJOURNE
end

--- Cases occupées par les tapis et poteaux d'une ligne ({ belts = { { x, y } }, poles = { { x, y } } }, points { x, y } ou
--- { x = , y = }).
local function occupied_of(line)
  local occ = {}
  for _, list in ipairs({ line.belts or {}, line.poles or {} }) do
    for _, p in ipairs(list) do occ[Bl.key(p[1] or p.x, p[2] or p.y)] = true end
  end
  return occ
end

--- Diagnostic « gabarit non évolutif » d'une ligne déjà posée : pour line = { cells = { { x, y, w, h } }, belts, poles },
--- quelles cellules pourront grandir vers `target` { w, h } sans déplacer tapis ni poteaux (ni chevaucher une voisine).
--- Rend { grow = { { i, rect } }, blocked = { { i, rect, conflit = première clé, conflits } }, evolutif = aucune bloquée }.
function Bl.plan(line, target)
  local occ = occupied_of(line)
  local cells = line.cells or {}
  local out = { grow = {}, blocked = {}, evolutif = true }
  for i, cell in ipairs(cells) do
    local ok, conflits = Bl.grow(cells, i, target, occ)
    local rect = Bl.grown(cell, target)
    if ok then
      out.grow[#out.grow + 1] = { i = i, rect = rect }
    else
      out.blocked[#out.blocked + 1] = { i = i, rect = rect, conflit = conflits[1], conflits = conflits }
      out.evolutif = false
    end
  end
  return out
end

return Bl
