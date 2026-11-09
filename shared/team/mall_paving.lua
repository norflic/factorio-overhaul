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

return Mp
