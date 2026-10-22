--[[
  Niveaux : « LIBÉRER LA PLACE » (lot V3-T3 ; Q-T2-1, réponse du Directeur Créatif le 22/10 à 21 h 06 : « QT21
  option B », soit, telle que posée dans le chat : « On garde la règle, et j'ajoute un bouton "libérer la place". Il
  marque les gêneurs à démonter par les robots et pose des fantômes pour les reconstruire décalés. »).
  Pur Lua, testable hors jeu (tests/levels_test.lua). Lu par script/levels/free.lua (Free.free_room, aussi
  Levels.free_room), qui relève la scène autour du bâtiment, appelle C.plan pour chaque candidate, puis exécute le
  plan retenu (marques de démontage, fantômes).

  La règle Q24 ne change pas : le bâtiment ne grandit que quand la place est libre. Ce module ne fait que dire QUOI
  démonter et OÙ reposer chaque gêneur, pour UNE candidate ; script/levels/free.lua essaie d'abord celle que montre
  déjà le contour (shared/levels/footprint.lua, F.evaluate : target, la plus facile à libérer), puis les autres dans
  le même ordre (correction V3-T3, défaut 12 : la plus facile n'est pas toujours libérable), et n'exécute qu'un plan
  COMPLET (ok : rien de signalé ; correction, défaut 10 : un plan partiel déplacerait des bras pour rien).

  =====================================================================================================
  RÈGLE DE DÉCALAGE (lot V3-T3), mot pour mot :
  Chaque gêneur (entité dont la boîte de collision chevauche celle du nouveau bâtiment) est traité selon sa sorte ;
  rien n'est jamais détruit : il est MARQUÉ à démonter (robots, ou le joueur à la main), et, si on sait le reposer,
  un FANTÔME le reconstruit décalé, même nom, même orientation, à une place libre (aucune entité restante, aucun
  autre fantôme, aucune tuile bloquante, hors du nouveau carré).
    1. Sortie minimale : un gêneur sort du nouveau carré par le côté le plus proche (décalage entier d, en tuiles,
       le plus petit) ; à égalité, le côté qui s'éloigne du centre du carré, puis l'ordre fixe nord, est, sud, ouest.
       Si cette place n'est pas libre, les autres sorties sont essayées dans le même ordre (sauf pour un bras).
    2. BRAS (inserter) : il doit servir le bâtiment (un de ses deux points dans l'ancienne boîte de collision ; sinon
       c'est le bras d'un voisin : signalé). Il est décalé de d le long de SON axe, vers l'extérieur, et son point
       côté bâtiment doit tomber dans le nouveau carré (géométrie lue sur l'entité : F87, F92). Son AUTRE point
       (prise ou dépôt) suit du même décalage, avec ce qui le servait :
         - rien : le bras seul ;
         - un petit contenant (coffre…) : décalé de d lui aussi ;
         - un convoyeur droit dont la ligne suit l'axe du bras (ligne qui finit au bras) : la ligne est RACCOURCIE
           des tuiles que le bras reprend, à condition qu'elle continue au-delà (le nouveau point y tombe) ;
         - un convoyeur droit dont la ligne longe le bâtiment (perpendiculaire à l'axe du bras) : la ligne fait une
           BOSSE vers l'extérieur sur la longueur nécessaire (tuile amont tournée vers l'extérieur, tuiles décalées,
           retour sur la tuile aval, qui devient un virage : la ligne reste continue, moteur réel E56) ;
         - autre chose (bâtiment, convoyeur en virage, souterrain…) : gardé seulement si le nouveau point est encore
           dans sa boîte ; sinon le bras est signalé.
       Plusieurs bras qui reprennent la même ligne du même côté font une seule bosse.
    3. CONVOYEUR ou TUYAU dans le nouveau carré (pas comme partenaire d'un bras) : ligne qui sort du carré dans son
       propre axe et ne continue que d'un côté : RACCOURCIE (tuiles du carré démontées, rien à reposer) ; convoyeur
       qui longe le côté : BOSSE (règle 2) ; autre cas (ligne qui traverse le carré, embranchement, tuyau qui longe,
       souterrain, séparateur) : signalé. Décaler une seule tuile d'une ligne la casserait : jamais fait.
    4. POTEAU : sortie minimale (règle 1), seulement si chaque fil de cuivre reste à portée (distance au plus la plus
       petite des deux portées) ET si rien de ce qu'il alimentait ne sort de toute zone d'alimentation (correction
       V3-T3) : chaque entité électrique de la scène (et le bâtiment agrandi, s'il est électrique) qui touchait sa
       zone doit toucher sa nouvelle zone ou celle d'un autre poteau resté ou reposé ; sinon signalé.
    5. MUR et PORTE : chaque tuile du carré sort par le côté le plus proche ; une tuile qui arriverait sur un mur
       resté en place le pousse lui aussi (mur épais, 3 rangées au plus) ; la ligne est REFERMÉE : au bout de chaque
       tronçon décalé, des murs de liaison (le mur de base de la famille, que le joueur fabrique : un mur de niveau
       ne s'obtient que par amélioration) relient le tronçon au mur resté en place. Liaison impossible : la ligne est
       laissée ouverte et c'est dit (avertissement).
    6. PETITS objets (coffre, lampe, combinateurs, haut-parleur, interrupteur) : sortie minimale (règle 1). Un coffre
       qui sert un point de jeu du bâtiment (dépôt d'une foreuse) suit ce point (décalé du déplacement du point).
    7. ARBRE, ROCHER : marqués à démonter, rien à reposer.
    8. Tout le reste (bâtiment voisin, autre force, falaise, véhicule…) et l'eau : SIGNALÉS (à retirer à la main),
       jamais marqués. Un seul gêneur signalé suffit à refuser toute la demande (rien n'est marqué, aucun fantôme) :
       correction V3-T3, défaut 10.
  Contrôles communs : un bras resté en place (d'un voisin) dont un point tombe sur une tuile démontée sans
  remplaçant interdit le groupe (il serait privé) ; chaque groupe (un gêneur et ce qu'il entraîne) est tout ou rien :
  s'il ne tient pas, ses gêneurs sont signalés et rien de lui n'est marqué. Ordre déterministe : bras, puis lignes,
  puis murs, puis le reste, chacun trié par position (y, puis x, puis nom).
  Correction V3-T3 (défauts 1 et 21) : un gêneur déjà réservé par une AUTRE demande en attente (marqué ou porteur
  d'un de ses fantômes : `reserved`) est signalé ; une tuile de ligne, l'amont ou l'aval d'une bosse, ou le partenaire
  d'un bras déjà marqué à démonter (par le joueur ou une autre demande) fait échouer son groupe (signalé) : le mod ne
  s'approprie jamais une marque qui n'est pas la sienne ; aucun fantôme n'est posé dans le carré réservé d'une autre
  demande (`reserved_boxes`). Plan COMPLET seulement (voir plus haut) : `ok` = rien de signalé.
  =====================================================================================================

  Conventions : directions du moteur 1.1.91 (defines.direction : nord 0, est 2, sud 4, ouest 6) ; boîtes
  { x0, y0, x1, y1 } en coordonnées de carte ; carré de tuiles { x0, y0, x1, y1 } entier, demi-ouvert (comme
  shared/levels/footprint.lua) ; chevauchement STRICT (le contact bord à bord ne compte pas, F96).
]]

local Foot = require("shared.levels.footprint")

local C = {}

C.EPS = 1e-6
--- Tolérance des positions du moteur (virgule fixe 1/256, F92, F98).
C.TOL = 1 / 64
--- Au plus tant de gêneurs marqués par une demande (au-delà : refus, la demande serait illisible).
C.MAX_MARKS = 64
--- Mur épais : au plus tant de murs poussés à la suite.
C.WALL_CHAIN = 3

--- Vecteurs unitaires des directions (y vers le bas : le nord est y négatif).
C.DIRV = { [0] = { x = 0, y = -1 }, [2] = { x = 1, y = 0 }, [4] = { x = 0, y = 1 }, [6] = { x = -1, y = 0 } }
--- Ordre fixe des sorties à égalité : nord, est, sud, ouest.
C.ORDER = { 0, 2, 4, 6 }

function C.vec_dir(v)
  if v.y < 0 then return 0 elseif v.x > 0 then return 2 elseif v.y > 0 then return 4 end
  return 6
end

local function z(v) return v == 0 and 0 or v end

--- Sorte d'un gêneur, d'après son type moteur (et sa force : `foreign` = autre force non neutre).
local KIND = {
  inserter = "arm",
  ["transport-belt"] = "belt",
  pipe = "pipe",
  ["electric-pole"] = "pole",
  wall = "wall", gate = "wall",
  container = "small", ["logistic-container"] = "small", lamp = "small", ["constant-combinator"] = "small",
  ["arithmetic-combinator"] = "small", ["decider-combinator"] = "small", ["power-switch"] = "small",
  ["programmable-speaker"] = "small",
  tree = "natural", ["simple-entity"] = "natural",
  ["entity-ghost"] = "ghost",
}
C.KIND = KIND

--- Types de convoyeurs (une tuile de l'un d'eux près d'une ligne qu'on raccourcit ou qu'on bosse la rend complexe).
C.BELTISH = { ["transport-belt"] = true, ["underground-belt"] = true, splitter = true, ["linked-belt"] = true,
  loader = true, ["loader-1x1"] = true }

function C.kind(etype, foreign)
  if foreign and etype ~= "entity-ghost" then return "fixed" end
  return KIND[etype] or "fixed"
end

--- Carré de tuiles couvert par une boîte de collision (tolérance F98).
function C.tiles(box)
  return { x0 = math.floor(box.x0 + C.TOL), y0 = math.floor(box.y0 + C.TOL),
           x1 = math.ceil(box.x1 - C.TOL), y1 = math.ceil(box.y1 - C.TOL) }
end

local function shift_box(b, sx, sy)
  return { x0 = b.x0 + sx, y0 = b.y0 + sy, x1 = b.x1 + sx, y1 = b.y1 + sy }
end
C.shift_box = shift_box

local function tile_key(x, y) return math.floor(x) .. "," .. math.floor(y) end

local function inside_box(b, x, y)
  return x > b.x0 + C.EPS and x < b.x1 - C.EPS and y > b.y0 + C.EPS and y < b.y1 - C.EPS
end

--- Le point (x, y) tombe-t-il sur une tuile du carré de tuiles B ?
local function point_in_tiles(B, x, y)
  local tx, ty = math.floor(x + C.EPS), math.floor(y + C.EPS)
  return tx >= B.x0 and tx < B.x1 and ty >= B.y0 and ty < B.y1
end
C.point_in_tiles = point_in_tiles

--- Profondeur de sortie d'un carré de tuiles T hors du carré B dans la direction d (0 si déjà dehors de ce côté).
function C.exit_depth(B, T, d)
  if d == 0 then return math.max(0, T.y1 - B.y0) end
  if d == 4 then return math.max(0, B.y1 - T.y0) end
  if d == 6 then return math.max(0, T.x1 - B.x0) end
  return math.max(0, B.x1 - T.x0)
end

--- Sorties d'un carré de tuiles T hors de B, dans l'ordre de la règle 1 : { {dir, d} } (d > 0).
function C.exits(B, T)
  local cx, cy = (B.x0 + B.x1) / 2, (B.y0 + B.y1) / 2
  local tx, ty = (T.x0 + T.x1) / 2, (T.y0 + T.y1) / 2
  local out = {}
  for rank, dir in ipairs(C.ORDER) do
    local d = C.exit_depth(B, T, dir)
    local v = C.DIRV[dir]
    local away = ((tx - cx) * v.x + (ty - cy) * v.y) > C.EPS and 0 or 1
    if d > 0 then out[#out + 1] = { dir = dir, d = d, away = away, rank = rank } end
  end
  table.sort(out, function(p, q)
    if p.d ~= q.d then return p.d < q.d end
    if p.away ~= q.away then return p.away < q.away end
    return p.rank < q.rank
  end)
  return out
end

---------------------------------------------------------------------------------------------------
-- Scène : index des entités par tuile, occupation
---------------------------------------------------------------------------------------------------
--- Prépare la scène : tri déterministe, carrés de tuiles, index des convoyeurs et tuyaux par tuile.
local function index_scene(input)
  local S = { recs = {}, belt_at = {}, pipe_at = {}, beltish_at = {}, wall_at = {}, by_id = {} }
  for _, r in ipairs(input.scene or {}) do
    r.tb = r.tb or C.tiles(r.box)
    S.by_id[r.id] = r
    S.recs[#S.recs + 1] = r
    if r.kind ~= "ghost" then
      local k = tile_key(r.x, r.y)
      if r.type == "transport-belt" then S.belt_at[k] = r end
      if r.type == "pipe" then S.pipe_at[k] = r end
      if r.kind == "wall" then S.wall_at[k] = r end
      if C.BELTISH[r.type] then
        for tx = r.tb.x0, r.tb.x1 - 1 do
          for ty = r.tb.y0, r.tb.y1 - 1 do S.beltish_at[tx .. "," .. ty] = r end
        end
      end
    end
  end
  S.tiles = {}
  for _, t in ipairs(input.tiles or {}) do S.tiles[#S.tiles + 1] = { x0 = t.x, y0 = t.y, x1 = t.x + 1, y1 = t.y + 1, name = t.name } end
  return S
end

local function belt_tile(S, x, y) return S.belt_at[tile_key(x, y)] end

--- Entrées d'une tuile de convoyeur `r` : arrière (convoyeur derrière, même direction ou tourné vers elle) et côtés
--- (convoyeurs qui pointent vers elle depuis un côté). Seuls les convoyeurs simples sont lus.
local function belt_inputs(S, r)
  local f = C.DIRV[r.dir]
  local back, sides = false, 0
  local b = belt_tile(S, r.x - f.x, r.y - f.y)
  if b then
    local v = C.DIRV[b.dir]
    if b.x + v.x == r.x and b.y + v.y == r.y then back = true end
  end
  for _, s in ipairs({ { x = -f.y, y = f.x }, { x = f.y, y = -f.x } }) do
    local o = belt_tile(S, r.x + s.x, r.y + s.y)
    if o then
      local v = C.DIRV[o.dir]
      if math.abs(o.x + v.x - r.x) < C.EPS and math.abs(o.y + v.y - r.y) < C.EPS then sides = sides + 1 end
    end
  end
  return back, sides
end

--- Un convoyeur est-il DROIT (pas un virage : un virage n'a pas d'entrée arrière et une seule entrée de côté) ?
function C.belt_straight(S, r)
  local back, sides = belt_inputs(S, r)
  return back or sides ~= 1
end

--- Occupation : rectangles de collision des entités restées en place, des fantômes prévus, du nouveau carré et des
--- tuiles bloquantes. Renvoie l'occupant (enregistrement, ou une étiquette) qui chevauche `rect`, sinon nil.
local function occupant(S, P, rect, ignore)
  if Foot.overlap(rect, P.B) then return "carre" end
  if P.old and Foot.overlap(rect, P.old) then return "batiment" end
  -- Correction V3-T3 (défaut 1) : carré réservé d'une autre demande en attente (son bâtiment y grandira).
  for _, b in ipairs(P.reserved) do
    if Foot.overlap(rect, b) then return "carre reserve" end
  end
  for _, t in ipairs(S.tiles) do
    if Foot.overlap(rect, t) then return "tuile:" .. tostring(t.name) end
  end
  for _, r in ipairs(S.recs) do
    if not P.vacated[r.id] and not (ignore and ignore[r.id]) and Foot.overlap(rect, r.box) then return r end
  end
  for _, g in ipairs(P.ghosts) do
    if Foot.overlap(rect, g.box) then return "fantome:" .. g.name end
  end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Groupes : un gêneur et ce qu'il entraîne, tout ou rien
---------------------------------------------------------------------------------------------------
local function new_group(kind, of)
  return { kind = kind, of = of, marks = {}, ghosts = {}, vacate = {}, members = { of }, notes = {} }
end

local function g_mark(G, r)
  if not G.vacate[r.id] then
    G.vacate[r.id] = true
    G.marks[#G.marks + 1] = r.id
  end
end

--- Fantôme de `name` centré en (x, y), direction dir, boîte de collision = `rel` (boîte relative au centre).
local function g_ghost(G, name, x, y, dir, rel, of)
  G.ghosts[#G.ghosts + 1] = { name = name, x = z(x), y = z(y), dir = dir or 0, of = of,
    box = { x0 = x + rel.x0, y0 = y + rel.y0, x1 = x + rel.x1, y1 = y + rel.y1 } }
end

local function rel_box(r)
  return { x0 = r.box.x0 - r.x, y0 = r.box.y0 - r.y, x1 = r.box.x1 - r.x, y1 = r.box.y1 - r.y }
end

--- Le groupe tient-il ? Places libres (fantômes entre eux compris), aucun bras resté en place privé d'un point.
local function g_check(S, P, G)
  -- Places : chaque fantôme contre l'occupation actuelle, en ignorant ce que le groupe démonte.
  for i, g in ipairs(G.ghosts) do
    local occ = occupant(S, P, g.box, G.vacate)
    if occ then return false, "place prise (" .. (type(occ) == "table" and occ.name or occ) .. ")" end
    for j = 1, i - 1 do
      if Foot.overlap(g.box, G.ghosts[j].box) then return false, "fantomes superposes" end
    end
  end
  -- Bras restés en place (voisins) : un point sur une entité démontée sans remplaçant sur la même tuile. Liste
  -- ordonnée G.marks (correction V3-T3, défaut 7 : jamais l'ordre de pairs, le motif rendu en dépend).
  for _, id in ipairs(G.marks) do
    local v = S.by_id[id]
    local replaced = false
    for _, g in ipairs(G.ghosts) do
      if v.type == "transport-belt" and g.name == v.name and math.abs(g.x - v.x) < C.EPS and math.abs(g.y - v.y) < C.EPS then replaced = true end
    end
    if not replaced then
      for _, a in ipairs(S.recs) do
        if a.kind == "arm" and not P.vacated[a.id] and not G.vacate[a.id] and a.pick and a.drop
            and (inside_box(v.box, a.pick.x, a.pick.y) or inside_box(v.box, a.drop.x, a.drop.y)) then
          return false, "bras voisin prive (" .. a.name .. ")"
        end
      end
    end
  end
  return true
end

local function commit(P, G)
  for _, id in ipairs(G.marks) do
    P.vacated[id] = true
    P.marks[#P.marks + 1] = id
  end
  for _, g in ipairs(G.ghosts) do P.ghosts[#P.ghosts + 1] = g end
  for _, id in ipairs(G.members) do P.done[id] = true end
  P.groups[#P.groups + 1] = G
end

--- Signale un gêneur (à retirer à la main) : seulement les entités qui bloquent la candidate (ou servent un point de
--- jeu) ; une tuile de convoyeur entraînée par un bras n'est pas un gêneur.
local function signal(P, id, why)
  if P.done[id] or not P.blocker[id] then return end
  P.done[id] = true
  P.signals[#P.signals + 1] = { id = id, why = why }
end

--- Groupe tenté : commit s'il tient, sinon chaque membre est signalé avec le motif.
local function try_group(S, P, G)
  local ok, why = g_check(S, P, G)
  if ok then commit(P, G) return true end
  for _, id in ipairs(G.members) do signal(P, id, why) end
  return false, why
end

---------------------------------------------------------------------------------------------------
-- Lignes de convoyeurs et de tuyaux
---------------------------------------------------------------------------------------------------
--- Raccourcissement d'une ligne qui suit l'axe u (règles 2 et 3) : depuis `first` (la tuile la plus proche du
--- bâtiment), les tuiles de la ligne vers +u qui chevauchent `zone` (rectangles) sont démontées ; la ligne doit
--- continuer au-delà (`keep` : nombre de tuiles qui doivent rester, 1 au moins), ne pas continuer vers −u, et aucune
--- tuile démontée ne doit recevoir de côté. Renvoie la liste des tuiles démontées et la première tuile gardée, ou nil
--- et le motif.
local function shorten(S, first, u, zones, pipe)
  local at = pipe and S.pipe_at or S.belt_at
  local function same(r)
    if not r then return false end
    if pipe then return true end
    return r.dir == first.dir and C.belt_straight(S, r)
  end
  local behind = at[tile_key(first.x - u.x, first.y - u.y)]
  if behind and same(behind) then return nil, "ligne qui continue des deux cotes" end
  local cut, cur = {}, first
  for _ = 1, 16 do
    local hit = false
    for _, zr in ipairs(zones) do if Foot.overlap(cur.box, zr) then hit = true end end
    if not hit then break end
    -- Correction V3-T3 (défaut 21) : une tuile déjà marquée (joueur, autre demande) n'est jamais reprise par le mod.
    if cur.marked then return nil, "tuile deja marquee" end
    -- Côtés : aucun convoyeur ni tuyau ne doit s'y raccorder (embranchement, chargement par le côté).
    for _, s in ipairs({ { x = -u.y, y = u.x }, { x = u.y, y = -u.x } }) do
      local o = at[tile_key(cur.x + s.x, cur.y + s.y)]
      if o then
        if pipe then return nil, "embranchement" end
        local v = C.DIRV[o.dir]
        if math.abs(o.x + v.x - cur.x) < C.EPS and math.abs(o.y + v.y - cur.y) < C.EPS then return nil, "chargement par le cote" end
      end
    end
    cut[#cut + 1] = cur
    local nxt = at[tile_key(cur.x + u.x, cur.y + u.y)]
    if not same(nxt) then return nil, "ligne qui ne continue pas au-dela" end
    if nxt.marked then return nil, "tuile deja marquee" end
    cur = nxt
  end
  if #cut == 0 then return nil, "rien a raccourcir" end
  return cut, cur
end

--- Bosse d'une ligne de convoyeurs droits qui longe le bâtiment (règle 2) : `run` = tuiles consécutives de la ligne,
--- dans le sens du flux ; u = vers l'extérieur ; d = profondeur. Ajoute marques et fantômes au groupe, ou renvoie
--- false et le motif.
local function bump(S, G, run, u, d)
  local P1 = run[1]
  local f = C.DIRV[P1.dir]
  local first, last = run[1], run[#run]
  local function belt_near(x, y) return S.beltish_at[tile_key(x, y)] end
  local U = belt_tile(S, first.x - f.x, first.y - f.y)
  local W = belt_tile(S, last.x + f.x, last.y + f.y)
  local Ub, Wb = belt_near(first.x - f.x, first.y - f.y), belt_near(last.x + f.x, last.y + f.y)
  if Ub and Ub ~= U then return false, "amont complexe (" .. Ub.name .. ")" end
  if Wb and Wb ~= W then return false, "aval complexe (" .. Wb.name .. ")" end
  if U and not (U.dir == P1.dir and C.belt_straight(S, U)) then return false, "amont en virage" end
  if W and not (W.dir == P1.dir and C.belt_straight(S, W)) then return false, "aval en virage" end
  -- Correction V3-T3 (défaut 21) : amont, aval ou tuile de la ligne déjà marqués (joueur, autre demande) : le mod ne
  -- les reprend pas (une marque qui n'est pas la sienne ne serait jamais annulée par lui).
  if (U and U.marked) or (W and W.marked) then return false, "tuile deja marquee" end
  for _, t in ipairs(run) do
    if t.marked then return false, "tuile deja marquee" end
    if t.dir ~= P1.dir or not C.belt_straight(S, t) then return false, "ligne en virage" end
    -- Côté bâtiment de chaque tuile démontée : aucun convoyeur qui s'y raccorde.
    local o = belt_near(t.x - u.x, t.y - u.y)
    if o then return false, "convoyeur raccorde cote batiment" end
  end
  -- Amont et aval : rien côté bâtiment (l'amont tourne vers l'extérieur, l'aval devient un virage).
  if U then
    local _, sides = belt_inputs(S, U)
    if sides > 0 or belt_near(U.x - u.x, U.y - u.y) then return false, "amont entoure" end
  end
  if W then
    local _, sides = belt_inputs(S, W)
    if sides > 0 or belt_near(W.x - u.x, W.y - u.y) then return false, "aval entoure" end
  end
  local rel = rel_box(P1)
  local du, dmu, df = C.vec_dir(u), C.vec_dir({ x = -u.x, y = -u.y }), P1.dir
  if U then
    g_mark(G, U)
    g_ghost(G, U.name, U.x, U.y, du, rel, U.id)
    for k = 1, d - 1 do g_ghost(G, U.name, U.x + k * u.x, U.y + k * u.y, du, rel, U.id) end
    g_ghost(G, U.name, U.x + d * u.x, U.y + d * u.y, df, rel, U.id)
  end
  for _, t in ipairs(run) do
    g_mark(G, t)
    g_ghost(G, t.name, t.x + d * u.x, t.y + d * u.y, df, rel, t.id)
  end
  if W then
    g_ghost(G, W.name, W.x + d * u.x, W.y + d * u.y, dmu, rel, W.id)
    for k = d - 1, 1, -1 do g_ghost(G, W.name, W.x + k * u.x, W.y + k * u.y, dmu, rel, W.id) end
  end
  G.notes[#G.notes + 1] = "bosse"
  return true
end

--- Tuiles consécutives de la ligne de `r` (même direction, convoyeurs simples) de `a` à `b` (positions le long de
--- f, comprises) ; nil si un trou ou une autre direction.
local function line_span(S, r, lo, hi)
  local f = C.DIRV[r.dir]
  local out = {}
  -- Coordonnée le long de f : x pour une ligne est-ouest, y pour une ligne nord-sud ; lo, hi en coordonnées.
  local step = (f.x + f.y) > 0 and 1 or -1
  local from, to = lo, hi
  if step < 0 then from, to = hi, lo end
  for c = from, to, step do
    local x, y = r.x, r.y
    if f.x ~= 0 then x = c else y = c end
    local t = belt_tile(S, x, y)
    if not (t and t.dir == r.dir) then return nil end
    out[#out + 1] = t
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Zone d'alimentation d'un poteau décalé (correction V3-T3, règle 4)
---------------------------------------------------------------------------------------------------
local function supply_square(x, y, d)
  return { x0 = x - d, y0 = y - d, x1 = x + d, y1 = y + d }
end

--- Le poteau `r` du groupe G, reposé en (nx, ny), laisse-t-il alimenté tout ce qu'il alimentait ? Chaque entité
--- électrique de la scène restée en place (r.powered), chaque fantôme prévu d'une entité électrique, et le bâtiment
--- agrandi (P.powered_box, s'il est électrique), qui touchaient l'ancienne zone, doivent toucher la nouvelle zone ou
--- celle d'un autre poteau resté en place ou reposé (fantôme). Un poteau hors de la scène n'est pas vu : le contrôle
--- est prudent (il peut refuser à tort, jamais accepter à tort pour ce qu'il voit). Renvoie true, ou false et le motif.
function C.supply_kept(S, P, G, r, nx, ny)
  local d = r.supply
  if not d or d <= 0 then return true end
  local old = supply_square(r.x, r.y, d)
  local areas = { supply_square(nx, ny, d) }
  for _, o in ipairs(S.recs) do
    if o.kind == "pole" and o.id ~= r.id and o.supply and not P.vacated[o.id] and not G.vacate[o.id] then
      areas[#areas + 1] = supply_square(o.x, o.y, o.supply)
    end
  end
  for _, g in ipairs(P.ghosts) do
    if g.supply then areas[#areas + 1] = supply_square(g.x, g.y, g.supply) end
  end
  local function covered(box)
    for _, a in ipairs(areas) do if Foot.overlap(box, a) then return true end end
    return false
  end
  for _, o in ipairs(S.recs) do
    if o.powered and o.kind ~= "ghost" and not P.vacated[o.id] and not G.vacate[o.id] and Foot.overlap(o.box, old) and not covered(o.box) then
      return false, "alimentation perdue (" .. o.name .. ")"
    end
  end
  for _, g in ipairs(P.ghosts) do
    local o = g.of and S.by_id[g.of]
    if o and o.powered and Foot.overlap(g.box, old) and not covered(g.box) then
      return false, "alimentation perdue (" .. g.name .. ")"
    end
  end
  if P.powered_box and P.old and Foot.overlap(P.old, old) and not covered(P.powered_box) then
    return false, "alimentation perdue (batiment)"
  end
  return true
end

---------------------------------------------------------------------------------------------------
-- Plan
---------------------------------------------------------------------------------------------------
--- input = {
---   new_box  = carré de tuiles du nouveau bâtiment (la candidate À MONTRER),
---   old_rect = boîte de collision actuelle du bâtiment (carte),
---   scene    = { enregistrements } : id, name, type, kind, x, y, dir, box ; bras : pick, drop ; poteau : reach,
---              wires = { {x, y, reach, id} } ; une entité marquée à démonter par quelqu'un d'autre : marked,
---   blockers = { id } (entités qui bloquent la candidate), moved = { {id, old = {x, y}, new = {x, y}} } (entités
---              qui servent un point de jeu qui sortirait), tiles = { {x, y, name} } (tuiles bloquantes de la
---              candidate) ou nil, area_tiles = tuiles bloquantes autour (eau) pour les places des fantômes,
---   connector = nom du mur de liaison (mur de base de la famille),
---   Correction V3-T3 : reserved_boxes = carrés réservés par les AUTRES demandes en attente (aucun fantôme n'y va) ;
---   missing = { {name, x, y} } gênes de la candidate absentes de la scène (signalées) ; powered_box = boîte de
---   collision du bâtiment agrandi s'il est électrique (règle 4) ; dans la scène : reserved (entité réservée par une
---   autre demande), powered (entité électrique), supply (zone d'alimentation d'un poteau, demi-côté).
--- }
--- Renvoie { groups, marks (ids), ghosts ({name, x, y, dir, of, box}), signals ({id, why} ; id = nil pour une
--- tuile ou une gêne hors du relevé : tile ou missing), warnings, ok (rien de signalé) }.
function C.plan(input)
  local S = index_scene({ scene = input.scene, tiles = input.area_tiles })
  local B = input.new_box
  local old = input.old_rect
  local P = { B = B, old = old, vacated = {}, done = {}, marks = {}, ghosts = {}, groups = {}, signals = {}, warnings = {},
    reserved = input.reserved_boxes or {}, powered_box = input.powered_box }

  -- Gêneurs, triés (y, x, nom) ; ceux déjà marqués par quelqu'un d'autre partent quand même (rien à reposer :
  -- le joueur les a voulus démontés), ils ne sont ni marqués ni reposés par le mod.
  local list = {}
  for _, id in ipairs(input.blockers or {}) do
    local r = S.by_id[id]
    if r then list[#list + 1] = r end
  end
  table.sort(list, function(a, b)
    if a.y ~= b.y then return a.y < b.y end
    if a.x ~= b.x then return a.x < b.x end
    return a.name < b.name
  end)
  P.blocker = {}
  for _, r in ipairs(list) do
    P.blocker[r.id] = true
  end
  for _, m in ipairs(input.moved or {}) do P.blocker[m.id] = true end
  for _, r in ipairs(list) do
    -- Correction V3-T3 (défaut 1) : réservé par une autre demande en attente (marqué par elle, ou fantôme à elle) :
    -- signalé ; deux demandes ne se partagent jamais un gêneur.
    if r.reserved then
      signal(P, r.id, "reserve par une autre demande")
    elseif r.marked then
      P.done[r.id] = true; P.vacated[r.id] = true
    end
  end
  -- Entités qui ne figurent pas dans la scène (relevé incomplet : défauts 2 et 20) : signalées par l'appelant
  -- (input.missing = { {name, x, y} }), jamais ignorées.
  for _, m in ipairs(input.missing or {}) do
    P.signals[#P.signals + 1] = { missing = { name = m.name, x = m.x, y = m.y }, why = "hors du releve" }
  end

  -- Tuiles bloquantes de la candidate : signalées (eau : à remblayer).
  for _, t in ipairs(input.tiles or {}) do
    P.signals[#P.signals + 1] = { tile = { x = t.x, y = t.y, name = t.name }, why = "tuile" }
  end

  -- 1. Bras -------------------------------------------------------------------------------------------
  local intents = {}
  for _, r in ipairs(list) do
    if not P.done[r.id] and r.kind == "arm" then
      local it = { arm = r }
      if not (r.pick and r.drop) then
        signal(P, r.id, "bras sans geometrie")
      else
        local mach, outer
        if inside_box(old, r.drop.x, r.drop.y) then mach, outer = r.drop, r.pick
        elseif inside_box(old, r.pick.x, r.pick.y) then mach, outer = r.pick, r.drop end
        if not mach then
          signal(P, r.id, "bras d'un voisin")
        else
          local vx, vy = outer.x - mach.x, outer.y - mach.y
          local u
          if math.abs(vx) > math.abs(vy) then u = { x = vx > 0 and 1 or -1, y = 0 } else u = { x = 0, y = vy > 0 and 1 or -1 } end
          local d = C.exit_depth(B, r.tb, C.vec_dir(u))
          it.u, it.d, it.mach, it.outer = u, d, mach, outer
          -- Partenaire : ce qui couvre le point extérieur (hors du bras lui-même).
          for _, o in ipairs(S.recs) do
            if o.kind ~= "ghost" and o.id ~= r.id and inside_box(o.box, outer.x, outer.y) then it.partner = o break end
          end
          if d <= 0 then
            signal(P, r.id, "bras hors de l'axe")
          else
            intents[#intents + 1] = it
          end
        end
      end
    end
  end
  -- Bras dont le partenaire est un convoyeur droit qui longe le bâtiment : regroupés par ligne (une bosse).
  local clusters, ckeys = {}, {}
  for _, it in ipairs(intents) do
    local p, u = it.partner, it.u
    -- Partenaire marqué : traité avec les autres bras (signalé, voir plus bas).
    if p and p.type == "transport-belt" and not p.marked then
      local f = C.DIRV[p.dir]
      if f.x * u.x + f.y * u.y == 0 then
        local key = p.dir .. ":" .. C.vec_dir(u) .. ":" .. (f.x ~= 0 and math.floor(p.y) or math.floor(p.x))
        if not clusters[key] then clusters[key] = { intents = {}, line = p, u = u, d = 0 }; ckeys[#ckeys + 1] = key end
        local cl = clusters[key]
        cl.intents[#cl.intents + 1] = it
        if it.d > cl.d then cl.d = it.d end
        it.cluster = cl
      end
    end
  end
  for _, key in ipairs(ckeys) do
    local cl = clusters[key]
    local p, u, d = cl.line, cl.u, cl.d
    local f = C.DIRV[p.dir]
    local G = new_group("bras+bosse", cl.intents[1].arm.id)
    G.members = {}
    local ok, why = true, nil
    -- Tuiles nécessaires : le partenaire de chaque bras, et toute tuile de la ligne dans le carré ou sous un bras décalé.
    local lo, hi
    local function need(c) if not lo or c < lo then lo = c end if not hi or c > hi then hi = c end end
    for _, it in ipairs(cl.intents) do
      local a = it.arm
      G.members[#G.members + 1] = a.id
      local sx, sy = d * u.x, d * u.y
      if not point_in_tiles(B, it.mach.x + sx, it.mach.y + sy) then ok, why = false, "bras : son point ne tomberait pas dans le batiment" end
      need(f.x ~= 0 and it.partner.x or it.partner.y)
      g_mark(G, a)
      g_ghost(G, a.name, a.x + sx, a.y + sy, a.dir, rel_box(a), a.id)
    end
    -- Tuiles de la ligne qui gênent (dans le carré, ou sous un bras décalé).
    local zones = { { x0 = B.x0, y0 = B.y0, x1 = B.x1, y1 = B.y1 } }
    for _, g in ipairs(G.ghosts) do zones[#zones + 1] = g.box end
    for _, t in ipairs(S.recs) do
      if t.type == "transport-belt" and t.dir == p.dir and ((f.x ~= 0 and math.abs(t.y - p.y) < C.EPS) or (f.y ~= 0 and math.abs(t.x - p.x) < C.EPS)) then
        for _, zr in ipairs(zones) do
          if Foot.overlap(t.box, zr) then need(f.x ~= 0 and t.x or t.y) end
        end
      end
    end
    local run = ok and line_span(S, p, lo, hi)
    if ok and not run then ok, why = false, "ligne interrompue" end
    if ok then
      for _, t in ipairs(run) do G.members[#G.members + 1] = t.id end
      ok, why = bump(S, G, run, u, d)
    end
    if ok then try_group(S, P, G) else for _, id in ipairs(G.members) do signal(P, id, why) end end
  end
  -- Autres bras : partenaire absent, petit contenant, ligne dans l'axe, ou partenaire assez grand.
  for _, it in ipairs(intents) do
    local a = it.arm
    if not it.cluster and not P.done[a.id] then
      local u, d, p = it.u, it.d, it.partner
      local sx, sy = d * u.x, d * u.y
      local G = new_group("bras", a.id)
      local ok, why = true, nil
      if not point_in_tiles(B, it.mach.x + sx, it.mach.y + sy) then ok, why = false, "bras : son point ne tomberait pas dans le batiment" end
      -- Correction V3-T3 (défaut 21) : partenaire déjà marqué (joueur, autre demande) : le bras ne serait plus servi
      -- là où il arrive, et la marque n'est pas celle du mod : signalé.
      if ok and p and p.marked then ok, why = false, "partenaire deja marque (" .. p.name .. ")" end
      g_mark(G, a)
      g_ghost(G, a.name, a.x + sx, a.y + sy, a.dir, rel_box(a), a.id)
      if ok and p and not p.marked then
        local nx, ny = it.outer.x + sx, it.outer.y + sy
        if p.kind == "small" then
          G.members[#G.members + 1] = p.id
          g_mark(G, p)
          g_ghost(G, p.name, p.x + sx, p.y + sy, p.dir, rel_box(p), p.id)
        elseif (p.type == "transport-belt" and C.belt_straight(S, p)) or p.type == "pipe" then
          -- Ligne dans l'axe du bras : raccourcie des tuiles que le bras décalé reprend.
          local cut, keep = shorten(S, p, u, { G.ghosts[1].box, { x0 = B.x0, y0 = B.y0, x1 = B.x1, y1 = B.y1 } }, p.type == "pipe")
          if not cut then
            ok, why = false, "ligne : " .. tostring(keep)
          elseif not inside_box(keep.box, nx, ny) then
            ok, why = false, "ligne : le nouveau point ne tombe pas sur la ligne"
          else
            for _, t in ipairs(cut) do G.members[#G.members + 1] = t.id; g_mark(G, t) end
            G.notes[#G.notes + 1] = "ligne raccourcie de " .. #cut
          end
        elseif not inside_box(p.box, nx, ny) then
          ok, why = false, "bras : son autre point ne serait plus servi (" .. p.name .. ")"
        end
      end
      if ok then try_group(S, P, G) else for _, id in ipairs(G.members) do signal(P, id, why) end end
    end
  end

  -- 2. Lignes dans le carré (convoyeurs, tuyaux) ---------------------------------------------------------
  local Bbox = { x0 = B.x0, y0 = B.y0, x1 = B.x1, y1 = B.y1 }
  for _, r in ipairs(list) do
    if not P.done[r.id] and (r.kind == "belt" or r.kind == "pipe") then
      local pipe = r.kind == "pipe"
      local why = "ligne"
      local done = false
      if not pipe and not C.belt_straight(S, r) then
        why = "convoyeur en virage"
      else
        local f = (not pipe) and C.DIRV[r.dir] or nil
        local at = pipe and S.pipe_at or S.belt_at
        for _, ex in ipairs(C.exits(B, r.tb)) do
          local u = C.DIRV[ex.dir]
          local G = new_group(pipe and "tuyau" or "convoyeur", r.id)
          local ok, w = false, nil
          if f == nil or (f.x * u.x + f.y * u.y ~= 0) then
            -- Ligne dans l'axe de la sortie : raccourcie depuis sa tuile du carré la plus éloignée de la sortie.
            local first = r
            for _ = 1, 16 do
              local prev = at[tile_key(first.x - u.x, first.y - u.y)]
              if prev and (pipe or prev.dir == r.dir) and Foot.overlap(prev.box, Bbox) then first = prev else break end
            end
            local cut, keep = shorten(S, first, u, { Bbox }, pipe)
            if cut then
              G.members = {}
              for _, t in ipairs(cut) do G.members[#G.members + 1] = t.id; g_mark(G, t) end
              G.notes[#G.notes + 1] = "ligne raccourcie de " .. #cut
              ok = true
            else
              w = keep
            end
          elseif not pipe then
            -- Convoyeur qui longe le côté : bosse de toutes ses tuiles du carré, profondeur = la plus grande sortie.
            local lo, hi, d = nil, nil, 0
            for _, t in ipairs(S.recs) do
              if t.type == "transport-belt" and t.dir == r.dir and ((f.x ~= 0 and math.abs(t.y - r.y) < C.EPS) or (f.y ~= 0 and math.abs(t.x - r.x) < C.EPS))
                  and Foot.overlap(t.box, Bbox) then
                local c = f.x ~= 0 and t.x or t.y
                if not lo or c < lo then lo = c end
                if not hi or c > hi then hi = c end
                local dt = C.exit_depth(B, t.tb, ex.dir)
                if dt > d then d = dt end
              end
            end
            local run = lo and line_span(S, r, lo, hi)
            if run and d > 0 then
              G.members = {}
              for _, t in ipairs(run) do G.members[#G.members + 1] = t.id end
              ok, w = bump(S, G, run, u, d)
            else
              w = "ligne interrompue"
            end
          else
            w = "tuyau qui longe le batiment"
          end
          if ok then
            local okc, whyc = g_check(S, P, G)
            if okc then
              commit(P, G)
              P.done[r.id] = true
              done = true
              break
            end
            w = whyc
          end
          why = w or why
        end
      end
      if not done then signal(P, r.id, why) end
    end
  end

  -- 3. Murs ---------------------------------------------------------------------------------------------
  -- Couloirs : murs du carré qui sortent du même côté sur la même colonne (sortie nord ou sud) ou la même rangée
  -- (est ou ouest) ; un couloir se décale d'un bloc, de la plus grande profondeur de ses murs (l'épaisseur est
  -- gardée), et pousse les murs restés en place sur sa route (mur épais, C.WALL_CHAIN au plus).
  local lanes, lkeys = {}, {}
  for _, r in ipairs(list) do
    if not P.done[r.id] and r.kind == "wall" then
      local ex = C.exits(B, r.tb)[1]
      local u = C.DIRV[ex.dir]
      local key = ex.dir .. ":" .. (u.x == 0 and math.floor(r.x) or math.floor(r.y))
      if not lanes[key] then lanes[key] = { dir = ex.dir, d = 0, walls = {} }; lkeys[#lkeys + 1] = key end
      local L = lanes[key]
      L.walls[#L.walls + 1] = r
      if ex.d > L.d then L.d = ex.d end
    end
  end
  if #lkeys > 0 then
    local G = new_group("murs", lanes[lkeys[1]].walls[1].id)
    G.members = {}
    local moving, order, bad = {}, {}, nil
    for _, key in ipairs(lkeys) do
      local L = lanes[key]
      local u = C.DIRV[L.dir]
      for _, w in ipairs(L.walls) do
        moving[w.id] = { dir = L.dir, d = L.d }
        order[#order + 1] = w
      end
      -- Murs restés en place sur la route : poussés du même décalage.
      local pushed = 0
      local again = true
      while again do
        again = false
        for _, w in ipairs(order) do
          local m = moving[w.id]
          if m.dir == L.dir then
            local dest = S.wall_at[tile_key(w.x + m.d * u.x, w.y + m.d * u.y)]
            if dest and not moving[dest.id] and not dest.marked then
              pushed = pushed + 1
              if pushed > C.WALL_CHAIN * #L.walls then bad = "mur trop epais" break end
              moving[dest.id] = { dir = L.dir, d = L.d }
              order[#order + 1] = dest
              again = true
            end
          end
        end
        if bad then break end
      end
      if bad then break end
    end
    if bad then
      for _, key in ipairs(lkeys) do for _, w in ipairs(lanes[key].walls) do signal(P, w.id, bad) end end
    else
      local planned = {}
      for _, w in ipairs(order) do
        local m = moving[w.id]
        local u = C.DIRV[m.dir]
        G.members[#G.members + 1] = w.id
        g_mark(G, w)
        g_ghost(G, w.name, w.x + m.d * u.x, w.y + m.d * u.y, w.dir, rel_box(w), w.id)
        planned[tile_key(w.x + m.d * u.x, w.y + m.d * u.y)] = true
      end
      -- Liaisons (ligne refermée) : un mur décalé et son voisin le long de la ligne (resté en place, ou décalé moins
      -- loin dans le même sens) sont reliés par des murs de liaison sur la colonne du voisin.
      local conn_rel = rel_box(order[1])
      local open = 0
      for _, w in ipairs(order) do
        local m = moving[w.id]
        local u = C.DIRV[m.dir]
        for _, s in ipairs({ { x = -u.y, y = u.x }, { x = u.y, y = -u.x } }) do
          local n = S.wall_at[tile_key(w.x + s.x, w.y + s.y)]
          local from
          if n and not n.marked then
            local mn = moving[n.id]
            if not mn then from = 1 elseif mn.dir == m.dir and mn.d < m.d then from = mn.d + 1 end
          end
          if from then
            for k = from, m.d do
              local cx, cy = n.x + k * u.x, n.y + k * u.y
              local key = tile_key(cx, cy)
              local here = S.wall_at[key]
              if not ((here and not moving[here.id]) or planned[key]) then
                local box = { x0 = cx + conn_rel.x0, y0 = cy + conn_rel.y0, x1 = cx + conn_rel.x1, y1 = cy + conn_rel.y1 }
                local clash = occupant(S, P, box, G.vacate) ~= nil
                for _, g in ipairs(G.ghosts) do if Foot.overlap(box, g.box) then clash = true end end
                if clash then
                  open = open + 1
                else
                  planned[key] = true
                  g_ghost(G, input.connector or w.name, cx, cy, 0, conn_rel, nil)
                end
              end
            end
          end
        end
      end
      if open > 0 then P.warnings[#P.warnings + 1] = { id = order[1].id, why = "ligne de murs laissee ouverte (" .. open .. " liaison(s) impossible(s))" } end
      try_group(S, P, G)
    end
  end

  -- 4. Le reste ------------------------------------------------------------------------------------------
  local moved_by_id = {}
  for _, m in ipairs(input.moved or {}) do moved_by_id[m.id] = m end
  for _, r in ipairs(list) do
    if not P.done[r.id] then
      if r.kind == "natural" then
        local G = new_group("naturel", r.id)
        g_mark(G, r)
        try_group(S, P, G)
      elseif r.kind == "pole" or r.kind == "small" then
        local okp, last = false, "aucune sortie libre"
        for _, ex in ipairs(C.exits(B, r.tb)) do
          local u = C.DIRV[ex.dir]
          local sx, sy = ex.d * u.x, ex.d * u.y
          local G = new_group(r.kind == "pole" and "poteau" or "petit", r.id)
          g_mark(G, r)
          g_ghost(G, r.name, r.x + sx, r.y + sy, r.dir, rel_box(r), r.id)
          local reach_ok = true
          if r.kind == "pole" then
            for _, w in ipairs(r.wires or {}) do
              local wx, wy = w.x, w.y
              local dx, dy = r.x + sx - wx, r.y + sy - wy
              local lim = math.min(w.reach or 0, r.reach or 0)
              if dx * dx + dy * dy > lim * lim + C.EPS then reach_ok = false end
            end
          end
          local supply_ok, supply_why = true, nil
          if reach_ok and r.kind == "pole" then
            supply_ok, supply_why = C.supply_kept(S, P, G, r, r.x + sx, r.y + sy)
            if supply_ok then G.ghosts[#G.ghosts].supply = r.supply end
          end
          if not reach_ok then
            last = "fil hors de portee"
          elseif not supply_ok then
            last = supply_why
          else
            local okc, why = g_check(S, P, G)
            if okc then commit(P, G) okp = true break end
            last = why
          end
        end
        if not okp then signal(P, r.id, last) end
      else
        signal(P, r.id, r.kind == "fixed" and "a retirer a la main" or r.kind)
      end
    end
  end
  -- Entités qui servent un point de jeu (dépôt d'une foreuse, raccord) : un petit contenant suit le point.
  for _, m in ipairs(input.moved or {}) do
    local r = S.by_id[m.id]
    if r and not P.done[r.id] and not r.marked then
      local sx, sy = m.new.x - m.old.x, m.new.y - m.old.y
      local rx, ry = math.floor(sx + 0.5), math.floor(sy + 0.5)
      if r.kind == "small" and math.abs(sx - rx) < C.TOL and math.abs(sy - ry) < C.TOL then
        local G = new_group("point", r.id)
        g_mark(G, r)
        g_ghost(G, r.name, r.x + rx, r.y + ry, r.dir, rel_box(r), r.id)
        try_group(S, P, G)
      else
        signal(P, r.id, "point de jeu (" .. r.name .. ") : a refaire a la main")
      end
    end
  end

  if #P.marks > C.MAX_MARKS then
    return { groups = {}, marks = {}, ghosts = {}, signals = { { why = "trop de geneurs (" .. #P.marks .. ")" } }, warnings = {}, ok = false, too_many = true }
  end
  local ghosts = {}
  for _, g in ipairs(P.ghosts) do ghosts[#ghosts + 1] = g end
  return { groups = P.groups, marks = P.marks, ghosts = ghosts, signals = P.signals, warnings = P.warnings,
           ok = #P.signals == 0 }
end

--- Choix de la candidate à libérer (correction V3-T3, défaut 12) : `cands` = candidates évaluées par
--- shared/levels/footprint.lua (F.evaluate : tiles, entities, moved), `target` = indice de celle que montre le contour,
--- `plan_of(i)` = plan de la candidate i (C.plan), ou nil si elle est exclue (carré réservé par une autre demande).
--- Ordre d'essai : la candidate du contour d'abord, puis les autres dans l'ordre « la plus facile à libérer » de
--- footprint.lua (sans tuile bloquante, le moins de gêneurs, le moins de tuiles, le rang). Retenue : la première dont
--- le plan est COMPLET (ok). Renvoie l'indice retenu (ou nil), son plan, et le plan de la candidate du contour (à
--- montrer en cas de refus ; nil si elle est exclue).
function C.choose(cands, target, plan_of)
  local order = {}
  for i = 1, #cands do order[#order + 1] = i end
  local function key(i)
    local c = cands[i]
    local nt = #(c.tiles or {})
    return nt > 0 and 1 or 0, #(c.entities or {}) + #(c.moved or {}), nt
  end
  table.sort(order, function(a, b)
    if a == target then return b ~= target end
    if b == target then return false end
    local ta, ea, na = key(a)
    local tb, eb, nb = key(b)
    if ta ~= tb then return ta < tb end
    if ea ~= eb then return ea < eb end
    if na ~= nb then return na < nb end
    return a < b
  end)
  local shown
  for _, i in ipairs(order) do
    local p = plan_of(i)
    if i == target then shown = p end
    if p and p.ok and not p.too_many then return i, p, shown end
  end
  return nil, nil, shown
end

return C
