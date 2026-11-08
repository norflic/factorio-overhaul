--[[
  Lot MALL, tranche 1 (docs/MALL.md §2.1, §3, §4 ; directive du DC du 8/11 vers 18 h 30 : « l'IA doit centraliser sa production […]
  un véritable "Mall" […] une zone dense ») : choix du SECTEUR du mall et état « interconnexions de survie établies ». Règle PURE :
  aucune API du jeu, aucun nom d'objet (le terrain arrive en masques par case, l'état en booléens) ; testée hors jeu :
  tests/mall_plan_test.lua (mutants, coût mesuré par debug.sethook).

  GRILLE : le terrain autour du QG en CASES de Mp.CELL × Mp.CELL tuiles (8 : un quart de chunk), n × n cases, origine (gx0, gy0) au
  coin d'un chunk. Chaque case porte un MASQUE (bits) : Mp.EAU, Mp.MINERAI, Mp.BATI (bâtiment, falaise, tuile réservée par un projet,
  couloir d'accès), Mp.INCONNU (chunk non généré, ou pas encore lu), Mp.ARBRE (arbre ou rocher : défrichable). Les quatre premiers
  rendent la case INTERDITE. Stockage : une chaîne par rangée (un caractère par case : string.char(48 + masque)), sérialisable et petite.

  Mp.choose(grid, o) : la meilleure FENÊTRE carrée de o.size cases dont le centre est à o.radius tuiles au plus du QG (Chebyshev), sans
  case interdite, hors du lot du QG (o.keep_out). Score = 10 × étendue − 3 × distance − arbres ÷ 4 (en cases) : étendue = cases libres
  au-delà de la fenêtre, dans la meilleure des 4 directions (bande de la largeur de la fenêtre, au plus Mp.EXT cases) ; distance = de
  Manhattan, du centre de la fenêtre au QG ; arbres = cases défrichables de la fenêtre. Égalités : distance, puis y, puis x. Rend
  { i0, j0, size, x0, y0, x1, y1, dir, ext, d, soft, score } ou nil et le décompte des causes de rejet (eau, minerai, bati, inconnu).
  Direction (`dir`, 0 N, 2 E, 4 S, 6 O) : celle de la plus grande étendue ; à égalité, celle qui s'éloigne le plus du QG, puis 2, 4, 6, 0.
  C'est le sens où le tronc du mall grandira ; sa tête est du côté opposé.

  Mp.etat(inp) : état S (docs/MALL.md §3) : S1 centrale qui produit, S2 une source automatisée finie par plaque fondue, S3 pas de crise,
  S4 un assembleur utilisable. Rend { ok, code, cause } ; la cause est un texte fixe (journal [FO-MALL]).

  Déterminisme : boucles en ordre fixe (j puis i), aucun pairs, aucune trigonométrie, entiers seulement.
]]

local Mp = {}

Mp.CELL = 8                 -- tuiles par côté de case (un quart de chunk)
Mp.CHUNK = 32
Mp.READ_CHUNKS = 7          -- chunks lus de chaque côté du chunk du QG (15 × 15 chunks, 60 × 60 cases)
Mp.EXT = 8                  -- cases d'étendue au plus (64 tuiles) lues au-delà de la fenêtre
Mp.STEP = 2                 -- pas des fenêtres essayées, en cases (16 tuiles : le secteur n'a pas besoin d'être placé à la tuile)
-- essais, dans l'ordre : (côté de la fenêtre en cases, rayon en tuiles). 8 cases = 64 tuiles : 4 places de rangées le long du tronc,
-- rangées de 3 à 4 cellules de chaque côté ; 6 cases = 48 tuiles quand le terrain proche est encombré.
Mp.TRIES = { { size = 8, radius = 84 }, { size = 6, radius = 84 }, { size = 6, radius = 112 } }

Mp.EAU, Mp.MINERAI, Mp.BATI, Mp.INCONNU, Mp.ARBRE = 1, 2, 4, 8, 16
Mp.INTERDIT = 1 + 2 + 4 + 8
local CAT = { { bit = 1, name = "eau" }, { bit = 2, name = "minerai" }, { bit = 4, name = "bati" }, { bit = 8, name = "inconnu" } }
Mp.CAT = CAT

local floor, abs, max, min = math.floor, math.abs, math.max, math.min

local function has(mask, bit) return floor(mask / bit) % 2 == 1 end
Mp.has = has

---------------------------------------------------------------------------------------------------
-- 1. Grille
---------------------------------------------------------------------------------------------------
--- Grille de n × n cases, toutes INCONNUES, dont le coin nord-ouest est la tuile (gx0, gy0).
function Mp.grid(gx0, gy0, n)
  local row = string.rep(string.char(48 + Mp.INCONNU), n)
  local rows = {}
  for j = 1, n do rows[j] = row end
  return { gx0 = gx0, gy0 = gy0, n = n, rows = rows }
end

--- Grille centrée sur le chunk du QG (qx, qy en tuiles) : (2 × Mp.READ_CHUNKS + 1)² chunks.
function Mp.grid_around(qx, qy)
  local cx, cy = floor(qx / Mp.CHUNK), floor(qy / Mp.CHUNK)
  local per = Mp.CHUNK / Mp.CELL
  local nch = 2 * Mp.READ_CHUNKS + 1
  return Mp.grid((cx - Mp.READ_CHUNKS) * Mp.CHUNK, (cy - Mp.READ_CHUNKS) * Mp.CHUNK, nch * per), cx - Mp.READ_CHUNKS, cy - Mp.READ_CHUNKS, nch
end

--- Masque de la case (i, j), 0-indexée ; hors grille : INCONNU.
function Mp.get(g, i, j)
  if i < 0 or j < 0 or i >= g.n or j >= g.n then return Mp.INCONNU end
  return g.rows[j + 1]:byte(i + 1) - 48
end

--- Écrit les masques d'une rangée de cases (i0..i0 + #masks − 1, j).
function Mp.set_run(g, i0, j, masks)
  local r = g.rows[j + 1]
  local chars = {}
  for k, m in ipairs(masks) do chars[k] = string.char(48 + m) end
  g.rows[j + 1] = r:sub(1, i0) .. table.concat(chars) .. r:sub(i0 + #masks + 1)
end

function Mp.set(g, i, j, m) Mp.set_run(g, i, j, { m }) end

--- Masque d'une case d'après ses relevés (vrais ou faux).
function Mp.mask(eau, minerai, bati, inconnu, arbre)
  return (eau and Mp.EAU or 0) + (minerai and Mp.MINERAI or 0) + (bati and Mp.BATI or 0) + (inconnu and Mp.INCONNU or 0)
    + (arbre and Mp.ARBRE or 0)
end

---------------------------------------------------------------------------------------------------
-- 2. Choix de la fenêtre
---------------------------------------------------------------------------------------------------
-- Sommes préfixées : un tableau plat de (n + 1)² entrées (index j * (n + 1) + i) des cases dont le masque a un bit de `bits`
-- (somme de bits : une case compte une fois si elle a l'un d'eux).
local function prefix(g, bits)
  local n = g.n
  local w = n + 1
  local s = {}
  for i = 0, n do s[i] = 0 end
  local flag = {}
  for m = 0, 31 do
    local hit = false
    local b = 1
    while b <= 16 do
      if floor(bits / b) % 2 == 1 and floor(m / b) % 2 == 1 then hit = true end
      b = b * 2
    end
    flag[48 + m] = hit and 1 or 0
  end
  for j = 1, n do
    local row = g.rows[j]
    local base, prev = j * w, (j - 1) * w
    s[base] = 0
    local acc = 0
    for i = 1, n do
      acc = acc + flag[row:byte(i)]
      s[base + i] = s[prev + i] + acc
    end
  end
  return s
end
Mp._prefix = prefix

-- Nombre de cases marquées dans le rectangle [i0, i1) × [j0, j1) (bornes ramenées dans la grille).
local function count(s, n, i0, j0, i1, j1)
  if i0 < 0 then i0 = 0 end
  if j0 < 0 then j0 = 0 end
  if i1 > n then i1 = n end
  if j1 > n then j1 = n end
  if i1 <= i0 or j1 <= j0 then return 0 end
  local w = n + 1
  return s[j1 * w + i1] - s[j0 * w + i1] - s[j1 * w + i0] + s[j0 * w + i0]
end
Mp._count = count

-- Bande de k cases au-delà de la fenêtre (i0, j0, size) dans la direction d : rectangle [a0, a1) × [b0, b1), ou nil hors grille.
local function band(n, i0, j0, size, d, k0, k1)
  local a0, b0, a1, b1
  if d == 2 then a0, b0, a1, b1 = i0 + size + k0 - 1, j0, i0 + size + k1, j0 + size
  elseif d == 6 then a0, b0, a1, b1 = i0 - k1, j0, i0 - k0 + 1, j0 + size
  elseif d == 4 then a0, b0, a1, b1 = i0, j0 + size + k0 - 1, i0 + size, j0 + size + k1
  else a0, b0, a1, b1 = i0, j0 - k1, i0 + size, j0 - k0 + 1 end
  if a0 < 0 or b0 < 0 or a1 > n or b1 > n then return nil end
  return a0, b0, a1, b1
end

-- Étendue (cases) d'une bande de largeur `size` au-delà de la fenêtre dans la direction d, au plus `cap` ; hors grille : arrêt (le
-- bord de la grille compte comme inconnu). La bande entière d'abord (terrain ouvert : un seul compte), sinon case par case.
local function extent(bad, n, i0, j0, size, d, cap)
  local a0, b0, a1, b1 = band(n, i0, j0, size, d, 1, cap)
  if a0 and count(bad, n, a0, b0, a1, b1) == 0 then return cap end
  local e = 0
  for k = 1, cap do
    a0, b0, a1, b1 = band(n, i0, j0, size, d, k, k)
    if not a0 or count(bad, n, a0, b0, a1, b1) > 0 then break end
    e = k
  end
  return e
end

local DIRS = { 2, 4, 6, 0 }
local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }

--- o = { size (cases), radius (tuiles), qx, qy (QG, tuiles), keep_out = { x0, y0, x1, y1 } (tuiles, x1/y1 exclus) ou nil, ext (cases) }.
--- Seules les fenêtres dont le centre est dans le rayon sont parcourues (bornes calculées, pas de rejet un à un).
function Mp.choose(g, o)
  local n, C = g.n, Mp.CELL
  local size = o.size
  local cap = o.ext or Mp.EXT
  local any = prefix(g, Mp.INTERDIT)
  local soft = prefix(g, Mp.ARBRE)
  local half = size * C / 2
  -- centre de la fenêtre i0 : gx0 + i0 * C + half, dans [qx − radius, qx + radius]
  local i_lo = math.ceil((o.qx - o.radius - half - g.gx0) / C)
  local i_hi = floor((o.qx + o.radius - half - g.gx0) / C)
  local j_lo = math.ceil((o.qy - o.radius - half - g.gy0) / C)
  local j_hi = floor((o.qy + o.radius - half - g.gy0) / C)
  i_lo, j_lo = max(0, i_lo), max(0, j_lo)
  i_hi, j_hi = min(n - size, i_hi), min(n - size, j_hi)
  local best
  local rejected = 0
  local ko = o.keep_out
  local step = o.step or Mp.STEP
  for j0 = j_lo, j_hi, step do
    for i0 = i_lo, i_hi, step do
      local x0, y0 = g.gx0 + i0 * C, g.gy0 + j0 * C
      if ko and x0 < ko.x1 and x0 + size * C > ko.x0 and y0 < ko.y1 and y0 + size * C > ko.y0 then
        rejected = rejected + 1
      elseif count(any, n, i0, j0, i0 + size, j0 + size) > 0 then
        rejected = rejected + 1
      else
        local cxw, cyw = x0 + half, y0 + half
        local ex, dir, away = -1, nil, nil
        for _, d in ipairs(DIRS) do
          local e = extent(any, n, i0, j0, size, d, cap)
          local a = DV[d][1] * (cxw - o.qx) + DV[d][2] * (cyw - o.qy)
          if e > ex or (e == ex and a > away) then ex, dir, away = e, d, a end
        end
        local dist = floor((abs(cxw - o.qx) + abs(cyw - o.qy)) / C)
        local nsoft = count(soft, n, i0, j0, i0 + size, j0 + size)
        local score = 10 * ex - 3 * dist - floor(nsoft / 4)
        local better = not best or score > best.score
          or (score == best.score and (dist * C < best.d or (dist * C == best.d and (j0 < best.j0 or (j0 == best.j0 and i0 < best.i0)))))
        if better then
          best = { i0 = i0, j0 = j0, size = size, x0 = x0, y0 = y0, x1 = x0 + size * C, y1 = y0 + size * C, dir = dir, ext = ex * C,
            d = dist * C, soft = nsoft, score = score }
        end
      end
    end
  end
  if best then return best end
  return nil, Mp.tally(g, o, i_lo, j_lo, i_hi, j_hi)
end

--- Décompte des causes de rejet (appelé seulement quand aucune fenêtre ne passe : coût hors du cas ordinaire) : pour chaque fenêtre du
--- rayon, chaque catégorie présente compte une fois ; « qg » : fenêtre sur le lot du QG.
function Mp.tally(g, o, i_lo, j_lo, i_hi, j_hi)
  local n, C, size = g.n, Mp.CELL, o.size
  local t = { eau = 0, minerai = 0, bati = 0, inconnu = 0, qg = 0 }
  local pre = {}
  for _, c in ipairs(CAT) do pre[c.name] = prefix(g, c.bit) end
  local ko = o.keep_out
  local step = o.step or Mp.STEP
  for j0 = j_lo, j_hi, step do
    for i0 = i_lo, i_hi, step do
      local x0, y0 = g.gx0 + i0 * C, g.gy0 + j0 * C
      if ko and x0 < ko.x1 and x0 + size * C > ko.x0 and y0 < ko.y1 and y0 + size * C > ko.y0 then
        t.qg = t.qg + 1
      else
        for _, c in ipairs(CAT) do
          if count(pre[c.name], n, i0, j0, i0 + size, j0 + size) > 0 then t[c.name] = t[c.name] + 1 end
        end
      end
    end
  end
  return t
end

--- Cause dominante d'un décompte de rejets (texte fixe) : la catégorie de terrain la plus fréquente, sinon « loin » ou « qg ».
function Mp.dominant(tally)
  local best, bn = nil, 0
  for _, k in ipairs({ "eau", "minerai", "bati", "inconnu", "qg", "loin" }) do
    if (tally[k] or 0) > bn then best, bn = k, tally[k] end
  end
  return best or "aucune fenetre"
end

--- Le rectangle de tuiles r (x0, y0 inclus, x1, y1 exclus) est-il entièrement dans le secteur s ?
function Mp.inside(s, x0, y0, x1, y1)
  return s ~= nil and x0 >= s.x0 and y0 >= s.y0 and x1 <= s.x1 and y1 <= s.y1
end

---------------------------------------------------------------------------------------------------
-- 3. État S (« interconnexions de survie établies »)
---------------------------------------------------------------------------------------------------
--- inp = { plant = bool (S1), plaques = { { item, auto = bool } } triées (S2 : chaque plaque fondue), crise = nil | texte (S3), asm = bool (S4) }.
function Mp.etat(inp)
  inp = inp or {}
  if not inp.plant then return { ok = false, code = "S1", cause = "attente S1 : aucune centrale qui produit" } end
  local missing = {}
  for _, p in ipairs(inp.plaques or {}) do if not p.auto then missing[#missing + 1] = tostring(p.item) end end
  if #(inp.plaques or {}) == 0 then return { ok = false, code = "S2", cause = "attente S2 : aucune plaque fondue connue" } end
  if #missing > 0 then
    return { ok = false, code = "S2", cause = "attente S2 : aucune source automatisee de " .. table.concat(missing, ", ") }
  end
  if inp.crise then return { ok = false, code = "S3", cause = "attente S3 : crise (" .. tostring(inp.crise) .. ")" } end
  if not inp.asm then return { ok = false, code = "S4", cause = "attente S4 : aucun assembleur utilisable" } end
  return { ok = true, code = "S", cause = "S vrai : interconnexions de survie etablies" }
end

---------------------------------------------------------------------------------------------------
-- 4. Journal [FO-MALL] (aucune décision ne le lit)
---------------------------------------------------------------------------------------------------
local DNAME = { [0] = "nord", [2] = "est", [4] = "sud", [6] = "ouest" }
Mp.DNAME = DNAME

function Mp.line_sector(who, s, reserved, minute)
  return string.format("[FO-MALL] %s : SECTEUR (%d, %d)-(%d, %d) %dx%d tuiles, croissance vers %s, libre %d tuiles au-dela, a %d tuiles du QG,"
    .. " %d case(s) d'arbres, %d tuile(s) reservee(s) a %.1f min",
    tostring(who), s.x0, s.y0, s.x1, s.y1, s.x1 - s.x0, s.y1 - s.y0, DNAME[s.dir] or "?", s.ext, s.d, s.soft, reserved, minute)
end

function Mp.line_none(who, radius, tally, minute, retry_min)
  return string.format("[FO-MALL] %s : SECTEUR aucun : aucune fenetre libre a %d tuiles du QG (cause dominante : %s ; fenetres rejetees : eau %d,"
    .. " minerai %d, batiments %d, inconnu %d, lot du QG %d) ; nouvel essai dans %d min a %.1f min",
    tostring(who), radius, Mp.dominant(tally), tally.eau or 0, tally.minerai or 0, tally.bati or 0, tally.inconnu or 0, tally.qg or 0,
    retry_min, minute)
end

function Mp.line_etat(who, e, sector, minute)
  return string.format("[FO-MALL] %s : etat %s (%s) ; secteur %s a %.1f min", tostring(who), e.ok and "PRET" or "attente", e.cause,
    sector and "choisi" or "non choisi", minute)
end

return Mp
