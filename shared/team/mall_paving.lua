--[[
  PAVAGE DU MALL (lot MALL-PAVAGE ; directive du DC du 9/11 : « éradiquer l'espacement mort »). Lua PUR : aucune API du jeu,
  aucun nom d'objet (la taille de la machine est fournie par l'appelant, lue dans M.spec ; les cellules portent des SORTES,
  pas des prototypes). Banc : lua5.2 tests/mall_paving_test.lua.

  MESURE (journal V0676-K, Écarlate, QG (339, −340)) : les rangées du SECTEUR du mall sont déjà contiguës (machines en
  x = 359,5 ; rangée 2 en y = −378,5, rangée 3 en y = −393,5 : pas 15 = LARGE 14 + 1 de passage). L'espacement mort vient
  des BLOCS de la capitalisation (gabarit « bloc-<machine>-<n> », 11 × 14 avec 2 têtes de 3 : 17 tuiles sur les 24 du lot),
  posés UN PAR LOT du treillis (pas 28 = 24 + rue de 4 ; script/team/build.lua, candidates : « not l.used ») : bloc d'Écarlate
  au lot −2:0 en x = 280..294, lot −1:0 vide, QG au lot 0:0 (x ≥ 327). Entre deux blocs voisins : 28 − 11 = 17 tuiles (jusqu'à
  28 − 8 = 20 pour un bloc de 2 colonnes), soit « les 20 tuiles ».

  RUBAN (Mp.pattern) : deux rangées de machines face à face, corridor central de 2 ou 3 convoyeurs, bras d'entrée depuis le
  corridor, bras de sortie vers des coffres EXTÉRIEURS, poteaux dans les passages ; coordonnées relatives à l'origine (coin
  nord-ouest), x vers l'est, y vers le sud. Pour une machine 3 × 3 et 2 convoyeurs (n = 2 machines par rangée) :

        x : 0 1 2 3 4 5 6 7         (7 = passage vers la section suivante : un poteau, un ouvrier)
    y 0     . C . . . C . .         C coffre (sortie, hors du ruban)
      1     . ^ . . . ^ .           ^ bras de sortie (prend au sud, pose au nord dans le coffre)
      2     A A A . A A A           A machine nord (3 × 3)
      3     A A A P A A A P         P poteau (dans le passage entre deux machines, puis dans le gap de section)
      4     A A A . A A A
      5     . v . . . v .           v bras d'entrée (prend au sud, sur le corridor)
      6     > > > > > > >           corridor : convoyeur 1 (entrée au bout ouest, x = 0)
      7     > > > > > > >           corridor : convoyeur 2
      8     . ^ . . . ^ .           ^ bras d'entrée sud (prend au nord)
      9     B B B . B B B           B machine sud
     10     B B B P B B B P
     11     B B B . B B B
     12     . v . . . v .           v bras de sortie sud (prend au nord dans la machine, pose au sud)
     13     . C . . . C .           C coffre (sortie)

  Emprise : w = n × (mw + 1) − 1, h = 2 × mh + 6 + convoyeurs (14 pour 3 × 3 et 2 convoyeurs : la hauteur du bloc de
  patrons.lua, P.bloc). Convention des directions : celle du moteur (0 nord, 2 est, 4 sud, 6 ouest) ; pour un bras, `dir` est
  le côté où il PREND (un bras « sud » prend au sud et pose au nord) ; `reach` (1 ou 2) : portée du bras (bras long pour le
  second convoyeur).

  DUPLICATION EN SÉRIE (Mp.next_offset, Mp.compact) : la section suivante se colle à la terminaison de la précédente le long de
  l'axe, à `gap` tuiles (Mp.GAP = 1 ; au-delà de Mp.GAP_MAX = 2, c'est l'espacement mort : contrat rompu, erreur).
  Mp.pave_origin : la même règle dans un LOT déjà occupé (câblage dans script/team/build.lua, place_module).
]]

local Mp = {}
local floor, max = math.floor, math.max

Mp.GAP = 1      -- passage entre deux sections voisines : un poteau ou un ouvrier
Mp.GAP_MAX = 2  -- au-delà : espacement mort (contrat)
Mp.N, Mp.E, Mp.S, Mp.W = 0, 2, 4, 6
local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
Mp.DV = DV

local function is_int(v) return type(v) == "number" and v == floor(v) end
local function fail(fmt, ...) return nil, "contrat : " .. string.format(fmt, ...) end

--- Gap vérifié (nil : Mp.GAP) ; hors de [0, Mp.GAP_MAX] : erreur de contrat (l'espacement mort ne revient pas en silence).
function Mp.gap_of(gap)
  if gap == nil then return Mp.GAP end
  if not is_int(gap) or gap < 0 or gap > Mp.GAP_MAX then
    error(string.format("contrat : gap %s hors de [0, %d]", tostring(gap), Mp.GAP_MAX), 3)
  end
  return gap
end

--- Boîte { x0, y0, x1, y1 } (x1, y1 exclus) depuis { x0, y0, x1, y1 } ou { x, y, w, h } ; erreur de contrat sinon.
local function box_of(b)
  local x0, y0 = b and (b.x0 or b.x), b and (b.y0 or b.y)
  local x1 = b and (b.x1 or (x0 and b.w and x0 + b.w))
  local y1 = b and (b.y1 or (y0 and b.h and y0 + b.h))
  if not (is_int(x0) and is_int(y0) and is_int(x1) and is_int(y1)) or x1 < x0 or y1 < y0 then
    error("contrat : boite { x0, y0, x1, y1 } ou { x, y, w, h } attendue", 3)
  end
  return { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end

---------------------------------------------------------------------------------------------------
-- (a) Le gabarit RUBAN
---------------------------------------------------------------------------------------------------

--- Lignes du ruban (du nord au sud) pour une machine de hauteur mh et `belts` convoyeurs.
local function rows_of(mh, belts)
  local r = { chest_n = 0, out_n = 1, asm_n = 2 }
  r.in_n = r.asm_n + mh
  r.belt0 = r.in_n + 1
  r.in_s = r.belt0 + belts
  r.asm_s = r.in_s + 1
  r.out_s = r.asm_s + mh
  r.chest_s = r.out_s + 1
  r.h = r.chest_s + 1
  return r
end

--- Une colonne de machines (nord et sud) à l'abscisse x0 ; ajoute les cellules et les sorties.
local function add_column(pat, x0, mw, mh, r, belts, last, gap)
  local cells, outs = pat.cells, pat.outputs
  local function add(kind, dx, dy, dir, extra)
    local c = { kind = kind, dx = dx, dy = dy, dir = dir, w = 1, h = 1 }
    if extra then for k, v in pairs(extra) do c[k] = v end end -- (copie de champs : l'ordre est sans effet)
    cells[#cells + 1] = c
  end
  local xa = x0 + floor((mw - 1) / 2) -- colonne du bras : centre de la machine
  local xb = (mw >= 2) and (xa + 1) or nil -- bras long (second convoyeur), à côté du premier
  -- nord : coffre, bras de sortie, machine, bras d'entrée (tous « prennent au sud »)
  add("chest", xa, r.chest_n)
  add("arm_out", xa, r.out_n, Mp.S)
  add("asm", x0, r.asm_n, nil, { w = mw, h = mh })
  add("arm_in", xa, r.in_n, Mp.S)
  if xb and belts >= 2 and mh >= 2 then add("arm_in", xb, r.in_n, Mp.S, { reach = 2 }) end
  outs[#outs + 1] = { dx = xa, dy = r.chest_n }
  -- sud (miroir) : les bras « prennent au nord »
  add("arm_in", xa, r.in_s, Mp.N)
  if xb and belts >= 2 and mh >= 2 then add("arm_in", xb, r.in_s, Mp.N, { reach = 2 }) end
  add("asm", x0, r.asm_s, nil, { w = mw, h = mh })
  add("arm_out", xa, r.out_s, Mp.N)
  add("chest", xa, r.chest_s)
  outs[#outs + 1] = { dx = xa, dy = r.chest_s }
  -- poteaux dans le passage à l'est de la colonne (entre deux machines ; dans le gap de section pour la dernière, si gap ≥ 1)
  if not last or gap >= 1 then
    add("pole", x0 + mw, r.asm_n + floor(mh / 2))
    add("pole", x0 + mw, r.asm_s + floor(mh / 2))
  end
end

--- Gabarit RUBAN en coordonnées relatives. cfg = { asm = { w, h } (taille de la machine, lue par l'appelant dans M.spec),
--- belts = 2 | 3 (défaut 2), n = machines par rangée (défaut 1), gap (défaut Mp.GAP) }. Rend { cells = { { kind, dx, dy, dir,
--- w, h, reach } }, w, h, inputs = { { dx, dy } } (bout amont de chaque convoyeur), outputs = { { dx, dy } } (coffres), gap,
--- belts, n, asm } ou nil, raison. Sortes : asm, belt, arm_in, arm_out, chest, pole.
function Mp.pattern(cfg)
  local asm = type(cfg) == "table" and cfg.asm or nil
  if not asm or not is_int(asm.w) or not is_int(asm.h) or asm.w < 1 or asm.h < 1 then return fail("cfg.asm = { w, h } entiers ≥ 1 attendus") end
  local belts = cfg.belts or 2
  if belts ~= 2 and belts ~= 3 then return fail("corridor de 2 ou 3 convoyeurs (%s)", tostring(cfg.belts)) end
  local n = cfg.n or 1
  if not is_int(n) or n < 1 then return fail("n = machines par rangée, entier ≥ 1 (%s)", tostring(cfg.n)) end
  local gap = Mp.gap_of(cfg.gap)
  local mw, mh = asm.w, asm.h
  local r = rows_of(mh, belts)
  local W = n * (mw + 1) - 1
  local pat = { cells = {}, inputs = {}, outputs = {}, w = W, h = r.h, gap = gap, belts = belts, n = n, asm = { w = mw, h = mh } }
  for k = 0, belts - 1 do
    local y = r.belt0 + k
    for x = 0, W - 1 do pat.cells[#pat.cells + 1] = { kind = "belt", dx = x, dy = y, dir = Mp.E, w = 1, h = 1 } end
    pat.inputs[#pat.inputs + 1] = { dx = 0, dy = y }
  end
  for i = 0, n - 1 do add_column(pat, i * (mw + 1), mw, mh, r, belts, i == n - 1, gap) end
  return pat
end

---------------------------------------------------------------------------------------------------
-- (b) (c) Duplication en série : origines contiguës
---------------------------------------------------------------------------------------------------

--- Origine de la section suivante, collée à la fin de `prev` ({ x0, y0, x1, y1 } exclusifs ou { x, y, w, h }) le long de
--- `axis` ("x" : à l'est, "y" : au sud), à `gap` tuiles (défaut Mp.GAP ; > Mp.GAP_MAX : erreur de contrat). Rend { x, y }.
function Mp.next_offset(prev, axis, gap)
  gap = Mp.gap_of(gap)
  local b = box_of(prev)
  if axis == "x" then return { x = b.x1 + gap, y = b.y0 } end
  if axis == "y" then return { x = b.x0, y = b.y1 + gap } end
  error("contrat : axe « x » ou « y » attendu (" .. tostring(axis) .. ")", 2)
end

--- Pour une liste de blocs { w, h } le long de `axis` (défaut "x") : origines contiguës ({ x, y }, la première en (0, 0)),
--- largeur totale le long de l'axe (somme + gaps) et emprise en travers (le plus grand). Rend { origins, w, h, n }.
--- Déterministe : l'ordre de la liste est l'ordre des origines.
function Mp.compact(blocks, gap, axis)
  gap = Mp.gap_of(gap)
  axis = axis or "x"
  if axis ~= "x" and axis ~= "y" then error("contrat : axe « x » ou « y » attendu (" .. tostring(axis) .. ")", 2) end
  local origins, along, across = {}, 0, 0
  for i, b in ipairs(blocks or {}) do
    if not (is_int(b.w) and is_int(b.h) and b.w > 0 and b.h > 0) then error(string.format("contrat : bloc %d sans { w, h } entiers > 0", i), 2) end
    if i > 1 then along = along + gap end
    if axis == "x" then
      origins[i] = { x = along, y = 0 }
      along, across = along + b.w, max(across, b.h)
    else
      origins[i] = { x = 0, y = along }
      along, across = along + b.h, max(across, b.w)
    end
  end
  if axis == "x" then return { origins = origins, w = along, h = across, n = #origins } end
  return { origins = origins, w = across, h = along, n = #origins }
end

---------------------------------------------------------------------------------------------------
-- (d) Validation pure du gabarit
---------------------------------------------------------------------------------------------------

local function key(x, y) return x .. ":" .. y end

--- Pose les cellules sur une grille ; nil, raison au premier chevauchement ou à la première cellule hors emprise (un poteau
--- peut occuper le passage : dx < w + gap).
local function occupy(pat)
  local occ, W, H, gap = {}, pat.w, pat.h, pat.gap or 0
  for i, c in ipairs(pat.cells) do
    local cw, ch = c.w or 1, c.h or 1
    local xmax = (c.kind == "pole") and (W + gap) or W
    if not (is_int(c.dx) and is_int(c.dy)) or c.dx < 0 or c.dy < 0 or c.dx + cw > xmax or c.dy + ch > H then
      return nil, string.format("cellule %d (%s) hors emprise en (%s, %s)", i, tostring(c.kind), tostring(c.dx), tostring(c.dy))
    end
    for y = c.dy, c.dy + ch - 1 do
      for x = c.dx, c.dx + cw - 1 do
        local k = key(x, y)
        if occ[k] then return nil, string.format("chevauchement en (%d, %d) : %s sur %s", x, y, c.kind, occ[k].kind) end
        occ[k] = c
      end
    end
  end
  return occ
end

--- Un bras : ce qu'il prend et où il pose (tuiles à `reach` de lui, de part et d'autre).
local function arm_ends(occ, a)
  local v = DV[a.dir]
  if not v then return nil, nil, string.format("bras (%s, %s) sans direction", tostring(a.dx), tostring(a.dy)) end
  local r = a.reach or 1
  return occ[key(a.dx + r * v[1], a.dy + r * v[2])], occ[key(a.dx - r * v[1], a.dy - r * v[2])]
end

--- Validation : aucune cellule ne se chevauche ni ne sort de l'emprise, chaque machine a un bras d'entrée qui prend sur un
--- convoyeur du corridor et un bras de sortie qui pose dans un coffre. Rend true, ou false, raison.
function Mp.check(pat)
  if type(pat) ~= "table" or type(pat.cells) ~= "table" or not is_int(pat.w) or not is_int(pat.h) then return false, "gabarit sans cellules ou sans emprise" end
  local occ, why = occupy(pat)
  if not occ then return false, why end
  local asms, fed, out = {}, {}, {}
  for _, c in ipairs(pat.cells) do if c.kind == "asm" then asms[#asms + 1] = c end end
  if #asms == 0 then return false, "aucune machine" end
  for _, a in ipairs(pat.cells) do
    if a.kind == "arm_in" or a.kind == "arm_out" then
      local pick, drop, bad = arm_ends(occ, a)
      if bad then return false, bad end
      if a.kind == "arm_in" then
        if not (pick and pick.kind == "belt") then return false, string.format("bras d'entrée (%d, %d) ne prend sur aucun convoyeur", a.dx, a.dy) end
        if not (drop and drop.kind == "asm") then return false, string.format("bras d'entrée (%d, %d) ne pose dans aucune machine", a.dx, a.dy) end
        fed[drop] = true
      else
        if not (pick and pick.kind == "asm") then return false, string.format("bras de sortie (%d, %d) ne prend dans aucune machine", a.dx, a.dy) end
        if not (drop and drop.kind == "chest") then return false, string.format("bras de sortie (%d, %d) ne pose dans aucun coffre", a.dx, a.dy) end
        out[pick] = true
      end
    end
  end
  for i, m in ipairs(asms) do
    if not fed[m] then return false, string.format("machine %d (%d, %d) sans bras d'entrée depuis le corridor", i, m.dx, m.dy) end
    if not out[m] then return false, string.format("machine %d (%d, %d) sans bras de sortie vers un coffre", i, m.dx, m.dy) end
  end
  return true
end

---------------------------------------------------------------------------------------------------
-- (e) Pavage d'un lot déjà occupé (câblage : script/team/build.lua, place_module)
---------------------------------------------------------------------------------------------------

--- Origine de la section suivante dans un lot où un bloc est déjà posé : collée à `prev` (emprise dans le lot du bloc
--- précédent, têtes comprises) le long de x, sinon de y. need = { w, h, lead = { x0, y0, x1, y1 } } : corps du gabarit et
--- débords de ses têtes relatifs à son origine (lead.x0 ≤ 0, lead.x1 ≥ w ; défaut : le corps seul). rect = le lot (x1, y1
--- exclus) ; margin : tuiles libres entre le corps et les rues (les têtes peuvent toucher le bord, comme P.fit).
--- Rend { x, y, axis } ou nil, raison. Pur et déterministe.
function Mp.pave_origin(prev, need, rect, gap, margin)
  gap = Mp.gap_of(gap)
  margin = margin or 0
  local pb, lot = box_of(prev), box_of(rect)
  if not (need and is_int(need.w) and is_int(need.h)) then error("contrat : need = { w, h } attendu", 2) end
  local lead = need.lead or { x0 = 0, y0 = 0, x1 = need.w, y1 = need.h }
  local function fits(o)
    if o.x < lot.x0 + margin or o.y < lot.y0 + margin or o.x + need.w > lot.x1 - margin or o.y + need.h > lot.y1 - margin then return false end
    return o.x + lead.x0 >= lot.x0 and o.y + lead.y0 >= lot.y0 and o.x + lead.x1 <= lot.x1 and o.y + lead.y1 <= lot.y1
  end
  for _, axis in ipairs({ "x", "y" }) do
    local fo = Mp.next_offset(pb, axis, gap) -- origine de la nouvelle EMPRISE (têtes comprises)
    local o = { x = fo.x - lead.x0, y = fo.y - lead.y0, axis = axis }
    if fits(o) then return o end
  end
  return nil, string.format("lot plein : %d x %d (debords %d..%d, %d..%d) ne tient ni a l'est ni au sud de (%d, %d)-(%d, %d)",
    need.w, need.h, lead.x0, lead.x1, lead.y0, lead.y1, pb.x0, pb.y0, pb.x1, pb.y1)
end

---------------------------------------------------------------------------------------------------
-- (f) Série au-delà du lot : la rue est franchie par un SOUTERRAIN (lot MALL-RUE ; décision du DC, carte blanche : « si une
--     extension de mall dépasse le lot et rencontre une rue de la grille de ville, n'interromps pas la chaîne : enjambe la rue
--     par des convoyeurs souterrains »)
---------------------------------------------------------------------------------------------------
--  Grille des lots : lots = { pitch, lot, ox, oy } ; le lot i le long de x occupe [ox + pitch × i, ox + pitch × i + lot), la rue
--  les `pitch − lot` tuiles qui suivent (P.PITCH 28, P.LOT 24, P.STREET 4 ; ox = lat.ox − P.HALF). Rue : street = { w (défaut
--  pitch − lot), underground_reach (portée du souterrain débloqué : écart maximal entre l'entrée et la sortie, la
--  max_underground_distance du prototype, lue par script/team/traversee.lua) }.
--  Franchissement : l'ENTRÉE sur la dernière tuile du lot, la SORTIE sur la première tuile du lot suivant (écart = w + 1, qui doit
--  tenir dans la portée ; convention de shared/team/traversee.lua : 2 ≤ écart ≤ maxd) ; le corps de la section suivante à Mp.MARGE
--  de la rue, derrière la sortie ; une RALLONGE de tapis relie la fin du corridor précédent à l'entrée ; un RACCORD de tapis comble
--  le gap entre deux sections d'un même lot. Rien d'autre ne touche la rue : coffres et poteaux restent dans les lots.

Mp.MARGE = 1 -- tuiles libres entre le corps d'une section et la rue (la marge de P.fit) ; la sortie du souterrain, elle, touche le bord

--- Rue normalisée : { w, reach } ou erreur de contrat.
local function street_of(lots, street)
  local w = (type(street) == "table" and street.w) or (type(street) == "number" and street) or (lots.pitch - lots.lot)
  local reach = type(street) == "table" and (street.underground_reach or street.reach) or nil
  if not is_int(w) or w < 1 or w > lots.pitch - lots.lot then error(string.format("contrat : rue de %s tuiles hors de [1, %d]", tostring(w), lots.pitch - lots.lot), 3) end
  return { w = w, reach = reach }
end

--- Grille normalisée ; erreur de contrat si pitch ≤ lot.
local function lots_of(lots)
  if type(lots) ~= "table" or not is_int(lots.pitch) or not is_int(lots.lot) or lots.lot < 1 or lots.pitch <= lots.lot then
    error("contrat : lots = { pitch, lot } entiers, pitch > lot ≥ 1 attendus", 3)
  end
  return { pitch = lots.pitch, lot = lots.lot, ox = lots.ox or 0, oy = lots.oy or 0 }
end

--- Indice du lot qui porte la coordonnée `v` le long d'un axe d'origine `o` ; nil si `v` est sur la rue.
local function lot_index(L, v, o)
  local i = floor((v - o) / L.pitch)
  if (v - o) - i * L.pitch >= L.lot then return nil end
  return i
end

--- Indice du lot qui porte tout l'intervalle [a0, a1) ; nil si l'intervalle touche une rue ou deux lots.
local function lot_of_span(L, a0, a1, o)
  local i, j = lot_index(L, a0, o), lot_index(L, a1 - 1, o)
  if i and j and i == j then return i end
  return nil
end

--- Accès le long de l'axe (« a ») et en travers (« c ») d'un point ou d'une boîte.
local function axes_of(axis)
  if axis == "x" then return { a = "x", c = "y", w = "w", h = "h", oa = "ox", oc = "oy", dir = Mp.E } end
  if axis == "y" then return { a = "y", c = "x", w = "h", h = "w", oa = "oy", oc = "ox", dir = Mp.S } end
  error("contrat : axe « x » ou « y » attendu (" .. tostring(axis) .. ")", 3)
end

--- Point { x, y } depuis (a, c) selon l'axe.
local function pt(A, a, c) if A.a == "x" then return { x = a, y = c } end return { x = c, y = a } end

--- Tailles des n sections : `n` entier (toutes de la taille de origin) ou liste de { w, h }.
local function sizes_of(origin, n)
  local out = {}
  if is_int(n) then
    if n < 1 then error("contrat : n ≥ 1 attendu", 3) end
    for i = 1, n do out[i] = { w = origin.w, h = origin.h } end
  elseif type(n) == "table" and #n >= 1 then
    for i, s in ipairs(n) do
      if not (is_int(s.w) and is_int(s.h) and s.w > 0 and s.h > 0) then error(string.format("contrat : section %d sans { w, h } entiers > 0", i), 3) end
      out[i] = { w = s.w, h = s.h }
    end
  else error("contrat : n = entier ou liste de { w, h } attendu", 3) end
  return out
end

--- Les origines de `n` sections en série le long de `axis` depuis `origin` = { x, y, w, h, belts = { décalages en travers des
--- convoyeurs du corridor } }, dans la grille `lots`, à `gap` tuiles l'une de l'autre, en franchissant les rues (`street`) par un
--- souterrain par voie. Rend { sections = { { x, y, w, h, lot = { i, j } } }, traversees = { { entree = { x, y }, sortie = { x, y },
--- voie = k, dir, ecart, rallonge = { { x, y } }, section = indice de la section servie } }, raccords = { { x, y, voie } }, axis, belts }
--- ou nil, cause (portée insuffisante ou inconnue, section 1 sur une rue). Pur et déterministe.
function Mp.serie(origin, n, axis, lots, gap, street)
  gap = Mp.gap_of(gap)
  local A, L = axes_of(axis), lots_of(lots)
  local S = street_of(L, street)
  if type(origin) ~= "table" or not is_int(origin.x) or not is_int(origin.y) then error("contrat : origin = { x, y, w, h } attendu", 2) end
  local sizes = sizes_of(origin, n)
  local belts = origin.belts or {}
  local a0, c0 = origin[A.a], origin[A.c]
  local oa, oc = L[A.oa], L[A.oc]
  local i = lot_of_span(L, a0, a0 + sizes[1][A.w], oa)
  local j = lot_of_span(L, c0, c0 + sizes[1][A.h], oc)
  if not i or not j then return nil, string.format("section 1 sur une rue ou a cheval sur deux lots (%d, %d)", origin.x, origin.y) end
  local function lot_pair(ia) if A.a == "x" then return { i = ia, j = j } end return { i = j, j = ia } end
  local res = { sections = {}, traversees = {}, raccords = {}, axis = axis, belts = belts }
  local function push(a, sz, ia)
    local p = pt(A, a, c0)
    res.sections[#res.sections + 1] = { x = p.x, y = p.y, w = sz.w, h = sz.h, lot = lot_pair(ia) }
  end
  push(a0, sizes[1], i)
  local prev_end = a0 + sizes[1][A.w]
  for k = 2, #sizes do
    local sz = sizes[k]
    local lot_end = oa + L.pitch * i + L.lot
    local start = prev_end + gap
    if start + sz[A.w] <= lot_end - Mp.MARGE then
      -- même lot : collée, le gap comblé par un raccord sur chaque voie
      for _, bk in ipairs(belts) do
        for a = prev_end, start - 1 do local p = pt(A, a, c0 + bk); res.raccords[#res.raccords + 1] = { x = p.x, y = p.y, voie = bk } end
      end
      push(start, sz, i)
    else
      -- de l'autre côté de la rue : entrée sur la dernière tuile du lot, sortie sur la première du suivant
      if prev_end > lot_end - 1 then return nil, string.format("section %d : aucune tuile du lot pour l'entree du souterrain", k - 1) end
      local a_in, a_out = lot_end - 1, lot_end + S.w
      local ecart = a_out - a_in
      if not S.reach then return nil, string.format("portee inconnue : la rue de %d tuiles exige un souterrain d'ecart %d", S.w, ecart) end
      if ecart > S.reach or ecart < 2 then return nil, string.format("portee insuffisante : souterrain d'ecart %d (rue de %d) pour une portee de %d", ecart, S.w, S.reach) end
      i = i + 1
      start = a_out + Mp.MARGE
      for _, bk in ipairs(belts) do
        local t = { entree = pt(A, a_in, c0 + bk), sortie = pt(A, a_out, c0 + bk), voie = bk, dir = A.dir, ecart = ecart, rallonge = {}, section = k }
        for a = prev_end, a_in - 1 do t.rallonge[#t.rallonge + 1] = pt(A, a, c0 + bk) end
        for a = a_out + 1, start - 1 do t.rallonge[#t.rallonge + 1] = pt(A, a, c0 + bk) end
        res.traversees[#res.traversees + 1] = t
      end
      push(start, sz, i)
    end
    prev_end = start + sz[A.w]
  end
  return res
end

--- Une tuile (a, c) est-elle dans une section ? Rend l'indice ou nil.
local function section_at(res, A, a, c)
  for idx, s in ipairs(res.sections) do
    if a >= s[A.a] and a < s[A.a] + s[A.w] and c >= s[A.c] and c < s[A.c] + s[A.h] then return idx end
  end
  return nil
end

--- Vérification pure d'une série (Mp.serie ou toute série du même format) dans la grille `lots` : aucune cellule de section ni
--- raccord sur la rue, aucun chevauchement, chaque souterrain d'un bord de lot au bord du lot suivant dans la portée, et le
--- corridor continu de bout en bout sur chaque voie (sections, raccords, rallonges, souterrains). Rend true ou false, raison.
function Mp.check_serie(res, lots, street)
  if type(res) ~= "table" or type(res.sections) ~= "table" or #res.sections == 0 then return false, "serie sans section" end
  local A, L = axes_of(res.axis or "x"), lots_of(lots)
  local S = street_of(L, street)
  local oa, oc = L[A.oa], L[A.oc]
  for idx, s in ipairs(res.sections) do
    if not lot_of_span(L, s[A.a], s[A.a] + s[A.w], oa) or not lot_of_span(L, s[A.c], s[A.c] + s[A.h], oc) then
      return false, string.format("section %d sur la rue en (%d, %d)", idx, s.x, s.y)
    end
    for jdx = 1, idx - 1 do
      local o = res.sections[jdx]
      if s.x < o.x + o.w and o.x < s.x + s.w and s.y < o.y + o.h and o.y < s.y + s.h then return false, string.format("sections %d et %d se chevauchent", jdx, idx) end
    end
  end
  local cover = {} -- [voie] = { [a] = true } : tuiles du corridor hors sections
  local function mark(bk, a) cover[bk] = cover[bk] or {}; cover[bk][a] = true end
  for _, r in ipairs(res.raccords or {}) do
    if not lot_index(L, r[A.a], oa) or not lot_index(L, r[A.c], oc) then return false, string.format("raccord sur la rue en (%d, %d)", r.x, r.y) end
    if section_at(res, A, r[A.a], r[A.c]) then return false, string.format("raccord dans une section en (%d, %d)", r.x, r.y) end
    mark(r.voie, r[A.a])
  end
  for ti, t in ipairs(res.traversees or {}) do
    local ai, ao = t.entree[A.a], t.sortie[A.a]
    if t.entree[A.c] ~= t.sortie[A.c] then return false, string.format("souterrain %d : entree et sortie sur deux voies", ti) end
    local li = lot_index(L, ai, oa)
    if not li or ai ~= oa + L.pitch * li + L.lot - 1 then return false, string.format("souterrain %d : entree hors du bord du lot (%d)", ti, ai) end
    if ao ~= oa + L.pitch * (li + 1) then return false, string.format("souterrain %d : sortie hors du bord du lot suivant (%d)", ti, ao) end
    if not S.reach or ao - ai > S.reach or ao - ai < 2 then return false, string.format("souterrain %d : ecart %d hors de la portee %s", ti, ao - ai, tostring(S.reach)) end
    for _, r in ipairs(t.rallonge or {}) do
      if not lot_index(L, r[A.a], oa) then return false, string.format("rallonge sur la rue en (%d, %d)", r.x, r.y) end
      mark(t.voie, r[A.a])
    end
    for a = ai, ao do mark(t.voie, a) end
  end
  local first, last = res.sections[1], res.sections[#res.sections]
  for _, bk in ipairs(res.belts or {}) do
    local c = first[A.c] + bk
    for a = first[A.a], last[A.a] + last[A.w] - 1 do
      if not section_at(res, A, a, c) and not (cover[bk] and cover[bk][a]) then
        local p = pt(A, a, c)
        return false, string.format("corridor coupe en (%d, %d), voie %d", p.x, p.y, bk)
      end
    end
  end
  return true
end

---------------------------------------------------------------------------------------------------
-- (g) Série dans les QUATRE directions (lot MALL-DIRECTIONS, directive du DC du 10/11) : Mp.serie et Mp.check_serie travaillent
--     le long de +x (est) ou +y (sud). Vers l'ouest ou le nord, la grille et l'origine sont REFLÉTÉES le long de l'axe
--     (tuile a <-> −a − 1, lot i <-> −i, origine des lots oa <-> −(oa + lot)), la série est calculée, puis reflétée en retour :
--     mêmes règles, mêmes refus, aucune seconde géométrie. Pur et déterministe.
---------------------------------------------------------------------------------------------------
local AXIS_OF = { [Mp.E] = "x", [Mp.S] = "y", [Mp.W] = "x", [Mp.N] = "y" }

local function mirror_lots(L, A)
  local out = { pitch = L.pitch, lot = L.lot, ox = L.ox, oy = L.oy }
  out[A.oa] = -(L[A.oa] + L.lot)
  return out
end

--- Reflet d'un point { x, y } (tuile) le long de l'axe a : a <-> −a − 1.
local function mirror_pt(p, A)
  local q = { x = p.x, y = p.y }
  q[A.a] = -p[A.a] - 1
  return q
end

local function mirror_res(res, A, dir)
  local out = { sections = {}, traversees = {}, raccords = {}, axis = res.axis, belts = res.belts, dir = dir }
  for i, s in ipairs(res.sections) do
    local t = { x = s.x, y = s.y, w = s.w, h = s.h, lot = { i = s.lot.i, j = s.lot.j } }
    t[A.a] = -(s[A.a] + s[A.w])
    if A.a == "x" then t.lot.i = -s.lot.i else t.lot.j = -s.lot.j end
    out.sections[i] = t
  end
  for i, t in ipairs(res.traversees) do
    local r = { entree = mirror_pt(t.entree, A), sortie = mirror_pt(t.sortie, A), voie = t.voie, dir = dir, ecart = t.ecart, rallonge = {}, section = t.section }
    for j, q in ipairs(t.rallonge) do r.rallonge[j] = mirror_pt(q, A) end
    out.traversees[i] = r
  end
  for i, r in ipairs(res.raccords) do
    local q = mirror_pt(r, A)
    out.raccords[i] = { x = q.x, y = q.y, voie = r.voie }
  end
  return out
end

--- Mp.serie dans la direction `dir` (0 N, 2 E, 4 S, 6 O) : mêmes arguments et même résultat que Mp.serie (plus `dir`), les
--- traversées orientées vers `dir`. Vers l'est et le sud : Mp.serie tel quel.
function Mp.serie_dir(origin, n, dir, lots, gap, street)
  local axis = AXIS_OF[dir]
  if not axis then error("contrat : direction 0, 2, 4 ou 6 attendue (" .. tostring(dir) .. ")", 2) end
  if dir == Mp.E or dir == Mp.S then
    local res, why = Mp.serie(origin, n, axis, lots, gap, street)
    if res then res.dir = dir end
    return res, why
  end
  local A, L = axes_of(axis), lots_of(lots)
  if type(origin) ~= "table" or not is_int(origin.x) or not is_int(origin.y) then error("contrat : origin = { x, y, w, h } attendu", 2) end
  local o2 = { x = origin.x, y = origin.y, w = origin.w, h = origin.h, belts = origin.belts }
  o2[A.a] = -(origin[A.a] + origin[A.w])
  local res, why = Mp.serie(o2, n, axis, mirror_lots(L, A), gap, street)
  if not res then return nil, why end
  return mirror_res(res, A, dir)
end

--- Mp.check_serie pour une série de Mp.serie_dir (res.dir) : vers l'ouest ou le nord, la série et la grille sont reflétées
--- vers l'axe positif puis vérifiées par Mp.check_serie.
function Mp.check_serie_dir(res, lots, street)
  if type(res) ~= "table" then return false, "serie absente" end
  local dir = res.dir or Mp.E
  if dir == Mp.E or dir == Mp.S then return Mp.check_serie(res, lots, street) end
  local A, L = axes_of(AXIS_OF[dir]), lots_of(lots)
  local back = mirror_res(res, A, dir == Mp.W and Mp.E or Mp.S)
  back.dir = nil
  return Mp.check_serie(back, mirror_lots(L, A), street)
end

--- Mp.pave_origin dans la direction d'une série : la section suivante est collée à `prev` DU CÔTÉ où la série avance (est : à
--- l'est ; ouest : à l'ouest ; sud : au sud ; nord : au nord), même ligne en travers ; need = { w, h, lead } comme Mp.pave_origin.
--- Rend { x, y, axis, dir } ou nil, raison.
function Mp.pave_origin_dir(prev, need, rect, gap, margin, dir)
  if dir == nil or dir == Mp.E then return Mp.pave_origin(prev, need, rect, gap, margin) end
  if not AXIS_OF[dir] then error("contrat : direction 0, 2, 4 ou 6 attendue (" .. tostring(dir) .. ")", 2) end
  gap = Mp.gap_of(gap)
  margin = margin or 0
  local pb, lot = box_of(prev), box_of(rect)
  if not (need and is_int(need.w) and is_int(need.h)) then error("contrat : need = { w, h } attendu", 2) end
  local lead = need.lead or { x0 = 0, y0 = 0, x1 = need.w, y1 = need.h }
  local lw, lh = lead.x1 - lead.x0, lead.y1 - lead.y0 -- emprise têtes comprises
  local fo
  if dir == Mp.S then fo = { x = pb.x0, y = pb.y1 + gap }
  elseif dir == Mp.W then fo = { x = pb.x0 - gap - lw, y = pb.y0 }
  else fo = { x = pb.x0, y = pb.y0 - gap - lh } end
  local o = { x = fo.x - lead.x0, y = fo.y - lead.y0, axis = AXIS_OF[dir], dir = dir }
  local ok = o.x >= lot.x0 + margin and o.y >= lot.y0 + margin and o.x + need.w <= lot.x1 - margin and o.y + need.h <= lot.y1 - margin
    and o.x + lead.x0 >= lot.x0 and o.y + lead.y0 >= lot.y0 and o.x + lead.x1 <= lot.x1 and o.y + lead.y1 <= lot.y1
  if ok then return o end
  return nil, string.format("lot plein : %d x %d ne tient pas du cote %d de (%d, %d)-(%d, %d)", need.w, need.h, dir, pb.x0, pb.y0, pb.x1, pb.y1)
end

return Mp
