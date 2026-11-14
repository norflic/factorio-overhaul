--[[
  CHAMP (lot CHAMP, retour du DC du 2/11, points 1, 2, 3, 12, 13, 14) : plan d'un champ de minerai en RANGÉES RÉPÉTÉES.
  PUR : aucune API Factorio, aucun nom d'objet (tailles, portées et débits arrivent en DONNÉES : tests/iag_test.lua §8 bis).

  Le DC : « rangée poteaux électriques, rangée foreuses vers le bas, rangée convoyeur, rangée foreuses vers le haut, rangée
  poteaux électriques [...] et puis après on répète » ; « les convoyeurs qui passent en plein milieu du champ [...] ils pourraient
  juste retourner en arrière » ; « problème de minimisation, maximisation de l'espace, maximisation des foreuses électriques ».

  Géométrie (espace (u, v) : u le long des rangées = l'axe LONG du champ, v en travers). Une BANDE de pas 2 × côté + 2 :
    pr          rangée de poteaux (partagée avec la bande voisine), poteaux sur un TREILLIS fixe le long de u (pas ≤ fils,
                ≤ côté + 2 × portée : toute foreuse en touche un) : bâtir le champ bande par bande ne double aucun poteau
    pr+1..      foreuses tournées vers le tapis
    b = pr+c+1  tapis, qui sort par le bout du champ le plus proche du site de fonderie ; jamais à travers le champ
    ..pr+2c+1   foreuses tournées vers le tapis
  Les zones de minage (côté + 2 × portée) se recouvrent sur les rangées de poteaux et de tapis : tout le gisement est miné.
  Couloirs de passage : tous les CFG.corridor tuiles, deux colonnes sans foreuse (minées quand même) ; rangées de poteaux praticables.
  Débit : un tapis porte au plus voie / débit foreuses par côté (le plus lent des tapis donnés qui suffit) ; au-delà, la bande se
  coupe en deux groupes qui sortent chacun par SON bout ; le milieu attend un tapis plus rapide. Fonderie : shared/team/champ_fonderie.lua.

  Ch.plan(spec) -> plan, ou nil et raison. spec :
    ore      liste plate { x1, y1, x2, y2, ... } des tuiles de minerai (coins nord-ouest, entiers)
    blocked  { [Ch.key(x, y)] = true } : rien ne s'y pose (eau, falaise, bâtiment d'autrui)
    mine     { [Ch.key(x, y)] = true } : tuiles de NOS bâtiments du champ (paires à retirer, bandes déjà posées) : libres pour le plan
    foreign  { [Ch.key(x, y)] = true } ou nil : tuiles d'une AUTRE ressource que la foreuse sait miner (lot MELANGE, retour du DC du
             3/11 : « les minerais de charbon prennent la place des minerais de fer sur les convoyeurs ») : aucune foreuse dont la zone
             en touche une (la rangée se décale d'une tuile et réessaie ; shared/team/melange.lua)
    drill    { size, reach, rate }        côté, portée de minage au-delà du corps, objets/s
    pole     { reach, wire }              tuiles couvertes de part et d'autre (entier), portée des fils
    belts    { { lane = objets/s }, ... } du plus lent au plus rapide
    furnace  { size, rate, fuel } ou nil (coffres) ; inserter { rate } (mode coffres)
    target   { x, y }   site de fonderie (QG) : bout de sortie
    max_side foreuses par côté que le premier bout d'une bande prend (nil : la voie la plus rapide) ; le second bout prend le reste
    frame    cadre figé d'un plan précédent (plan.frame) : mêmes axe, phase, sortie, bords, décalages ; only = { [pr] = true } : ces
             bandes seulement (avec frame)
  plan = { axis, exit, frame, ents = { { kind, x, y, size, dir, band, group, pr, role, belt, module } }, bands, stats }
    kind : "foreuse" | "tapis" | "poteau" | "four" | "bras" | "coffre" ; dir 0 N, 2 E, 4 S, 6 O (foreuse : vers sa sortie ; tapis :
    sens de marche ; bras : côté où il PREND, convention de shared/team/modules.lua) ; role d'un coffre : "sortie" | "combustible".
  Déterminisme : listes triées, entiers, aucun `pairs` dans une décision, aucune trigonométrie.
]]

local Fd = require("shared.team.champ_fonderie")
local Co = require("shared.team.champ_colonne") -- lot FONDERIE : colonne nourrie par tapis, charbon compris
local Mel = require("shared.team.melange") -- lot MELANGE : zone d'une foreuse qui touche une autre ressource minable

local Ch = {}

Ch.CFG = {
  min_ore = 3,        -- tuiles de minerai au moins dans la zone d'une foreuse
  corridor = 32,      -- tuiles le long des rangées entre deux couloirs de passage (0 : aucun)
  gap = 2,            -- tuiles libres entre le bout du champ et la fonderie (passage)
  shift = 24,         -- tuiles dont la fonderie peut reculer pour trouver sa place (12 : bandes vides en jeu, la place prise par un autre chantier)
  both_ends = true,   -- une bande trop longue pour un tapis sort aussi par l'autre bout
  -- (lot FONDERIE, 3/11, le DC en 0.6.41 : « rien n'est automatique, rien n'est scalable ») une colonne d'un cadre neuf SANS voie de charbon
  -- (tracé sans chemin, pas de place pour le tronc) est REFUSÉE au lieu de retomber sur un coffre de tête à remplir ; le plan est refait
  -- sans elle (lot DECOUPLAGE : ses foreuses restent, tapis collecteur seul), au plus refuse_passes fois
  refuse_coffre = true,
  refuse_passes = 4,
  -- (lot FONDERIE, 3/11, décision du lead) le refus ne vaut que s'il garde au moins cette part des FOURS du champ (lot DECOUPLAGE : les
  -- foreuses restent toujours ; avant, la part des foreuses : le refus réduisait un champ d'azure de 41 foreuses à 4) ; sinon le cadre garde
  -- ses colonnes au coffre de tête (combustible)
  refuse_min = 0.5,
  -- (revue-fonderie, 3/11) un cadre neuf qui garde un coffre de tête ou refuse une colonne est aussi essayé dans l'autre ordre des côtés
  both_orders = true,
  eps = 1e-9,
}

function Ch.key(x, y) return (x + 50000) * 100000 + (y + 50000) end
Ch.BRIDGE_TRIES = 24 -- (lot FONDERIE) paires de poteaux essayées pour relier deux réseaux (bridge)
Ch.furnaces_for = Fd.furnaces_for

--- F555 : débit (objets/s) qu'un tapis de voie `lane` livre à la fonderie d'un groupe de n + s foreuses à `rate` : tout sur une voie
--- (colonne à combustible : l'autre voie porte le charbon), sinon une voie par côté. Les fours se dimensionnent sur ce débit.
function Ch.delivered(n, s, rate, lane, one_lane)
  if one_lane then return math.min((n + s) * rate, lane) end
  return math.min(n * rate, lane) + math.min(s * rate, lane)
end

--- Foreuses par côté qu'une voie porte.
function Ch.lane_drills(lane, rate)
  if not (lane and rate and rate > 0) then return 0 end
  return math.floor(lane / rate + Ch.CFG.eps)
end

local DIRS = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }

--- Lectures du champ dans le repère de l'axe : minerai, place libre, tuiles prises par le plan (clés en x, y).
-- s52 bandes : les lectures (fonctions) du contexte sont posées par bind sur ses SEULES données (c.axis, c.taken, c.ore, c.ore_uv,
-- c.foreign, c.resources, c.blocked, c.mine) : un plan repris d'une étape à l'autre (Ch.once_step) garde le contexte sans fonction
-- (unbind) et le relie au début de l'étape suivante, mêmes réponses
local CTX_FN = { "xy", "uv", "is_ore", "is_foreign", "is_resource", "free", "take", "dir" }
local function bind(c)
  if c.axis == "x" then
    c.xy = function(u, v) return u, v end
    c.uv = function(x, y) return x, y end
  else
    c.xy = function(u, v) return v, u end
    c.uv = function(x, y) return y, x end
  end
  local ore_uv = c.ore_uv
  c.is_ore = function(u, v) return ore_uv[Ch.key(u, v)] == true end
  -- lot MELANGE : une tuile d'une autre ressource minable (jamais une tuile du minerai visé : celui-ci gagne s'il y est aussi)
  c.is_foreign = function(u, v) local x, y = c.xy(u, v); local k = Ch.key(x, y); return c.foreign[k] == true and not c.ore[k] end
  -- F500 (directive du DC du 10/11, 22 h) : toute ressource sous l'emprise d'une fonderie, le minerai visé comme celui d'un autre gisement
  -- lot TAMPON-MINERAI (emerald, graine 271828182 : 16 fours et 30 bras de la colonne du fer n° 1 posés sur le fer n° 2, voisin) : le MÊME
  -- minerai d'un autre gisement n'est ni `ore` (ce gisement) ni `foreign` (autre nom) ; spec.resources = toutes les tuiles de ressource lues
  local all = c.resources
  c.is_resource = function(u, v)
    if c.is_ore(u, v) or c.is_foreign(u, v) then return true end
    local x, y = c.xy(u, v)
    return all[Ch.key(x, y)] == true
  end
  c.free = function(u, v)
    local x, y = c.xy(u, v)
    local k = Ch.key(x, y)
    return not c.taken[k] and (c.mine[k] or not c.blocked[k])
  end
  c.take = function(u, v) local x, y = c.xy(u, v); c.taken[Ch.key(x, y)] = true end
  c.dir = function(du, dv)
    local dx, dy = c.xy(du, dv)
    for _, d in ipairs({ 0, 2, 4, 6 }) do if DIRS[d][1] == dx and DIRS[d][2] == dy then return d end end
    return 0
  end
  return c
end
local function unbind(c) for _, k in ipairs(CTX_FN) do c[k] = nil end end

local function context(spec, axis)
  local c = { axis = axis, taken = {}, blocked = spec.blocked or {}, mine = spec.mine or {}, ore = {}, list = {}, foreign = spec.foreign or {},
    resources = spec.resources or {} }
  local uv = axis == "x" and function(x, y) return x, y end or function(x, y) return y, x end
  local o = spec.ore
  -- Lot PERF3 : le minerai aussi en clés du repère de l'axe (u, v) : is_ore sans changement de repère (même réponse : xy et uv sont
  -- deux bijections inverses l'une de l'autre ; c.ore n'est plus modifié après ce relevé)
  local ore_uv = {}
  for i = 1, #o - 1, 2 do
    local k = Ch.key(o[i], o[i + 1])
    if not c.ore[k] then
      c.ore[k] = true
      local u, v = uv(o[i], o[i + 1])
      c.list[#c.list + 1] = { u, v }
      ore_uv[Ch.key(u, v)] = true
    end
  end
  c.ore_uv = ore_uv
  c.has_foreign = next(c.foreign) ~= nil
  return bind(c)
end

local function corridor_col(origin, u)
  local n = Ch.CFG.corridor
  if not n or n <= 0 then return false end
  local r = (u - origin) % n
  return r == n - 2 or r == n - 1
end

--- Foreuses d'une rangée (corps sur les rangées row..row+s-1), parcours glouton au décalage o. Rend { u0 } et le minerai miné.
local function row_drills(c, spec, row, umin, umax, origin, o, fm)
  local s, r = spec.drill.size, spec.drill.reach
  local out, mined = {}, 0
  local counted = -math.huge -- dernière colonne dont le minerai est compté dans `mined`
  -- Lot PERF3 : place libre lue UNE fois par tuile (la fenêtre glisse d'une tuile, et les décalages et les rangées d'une même passe de
  -- bands_for relisent les mêmes tuiles) : `fm`, mémoire tenue par bands_for, où rien n'est pris (c.taken inchangé pendant la passe) :
  -- mêmes réponses que c.free
  fm = fm or {}
  local cfree, key = c.free, Ch.key
  local c_free = function(u, v)
    local k = key(u, v)
    local x = fm[k]
    if x == nil then x = cfree(u, v) and true or false; fm[k] = x end
    return x
  end
  local c_is_ore = c.is_ore
  -- corps libre colonne par colonne (s tuiles de la rangée), gardé dans la même mémoire de passe
  fm.cols = fm.cols or {}
  local fcol = fm.cols[row]
  if not fcol then fcol = {}; fm.cols[row] = fcol end
  local function body_free(u)
    local x = fcol[u]
    if x == nil then
      x = true
      for v = row, row + s - 1 do if not c_free(u, v) then x = false break end end
      fcol[u] = x
    end
    return x
  end
  -- Lot PERF3 : minerai de la zone d'une foreuse compté par COLONNES (le minerai ne change pas pendant le plan : sommes gardées dans
  -- le contexte par rangée), au lieu de (s + 2r)² lectures par position : même nombre, entier exact
  c.ore_cols = c.ore_cols or {}
  local cols = c.ore_cols[row]
  if not cols then cols = {}; c.ore_cols[row] = cols end
  local v0, v1 = row - r, row + s - 1 + r
  local function col(u)
    local n = cols[u]
    if n == nil then
      n = 0
      for v = v0, v1 do if c_is_ore(u, v) then n = n + 1 end end
      cols[u] = n
    end
    return n
  end
  -- s41 pavage-trous : décalage o == s = rangée OPTIMALE (programmation dynamique), plus un parcours glouton. Le glouton cale toute la
  -- rangée sur UN décalage : après un couloir de passage ou un obstacle, le tronçon suivant garde ce calage et laisse une colonne de
  -- minerai hors de toute zone (micro-trou). Ici chaque tronçon se cale seul : le plus de minerai miné, puis le plus de foreuses, puis
  -- les positions les plus à gauche. Mêmes gardes qu'en dessous (couloir, corps libre, autre ressource, min_ore). Les cadres déjà
  -- écrits gardent leurs décalages 0..s-1, donc leurs rangées à l'identique.
  if o == s then
    local a0, a1 = umin - r - s + 1, umax + r
    local function fits(a)
      for u = a, a + s - 1 do
        if corridor_col(origin, u) or not body_free(u) then return false end
      end
      if c.has_foreign then
        local x0, y0, x1, y1 = Mel.zone(a, row, s, r)
        if Mel.count(x0, y0, x1, y1, c.is_foreign) > 0 then return false end
      end
      local n = 0
      for u = a - r, a + s - 1 + r do n = n + col(u) end
      return n >= Ch.CFG.min_ore
    end
    local fm_, fc, fp = {}, {}, {} -- par position de la DERNIÈRE foreuse : minerai miné, foreuses, foreuse d'avant
    local pre = {}                 -- meilleure dernière foreuse parmi les positions <= a (zones disjointes de la suivante)
    local function better(m1, c1, m2, c2) return m1 > m2 or (m1 == m2 and c1 > c2) end
    local last
    for a = a0, a1 do
      if fits(a) then
        local full = 0
        for u = a - r, a + s - 1 + r do full = full + col(u) end
        local bm_, bc, bp = full, 1, nil
        local far = pre[a - s - 2 * r]
        if far and better(fm_[far] + full, fc[far] + 1, bm_, bc) then bm_, bc, bp = fm_[far] + full, fc[far] + 1, far end
        for b = math.max(a0, a - s - 2 * r + 1), a - s do
          if fm_[b] then
            local g = 0
            for u = math.max(a - r, b + s + r), a + s - 1 + r do g = g + col(u) end
            if better(fm_[b] + g, fc[b] + 1, bm_, bc) then bm_, bc, bp = fm_[b] + g, fc[b] + 1, b end
          end
        end
        fm_[a], fc[a], fp[a] = bm_, bc, bp
      end
      local q = pre[a - 1]
      if fm_[a] and (not q or better(fm_[a], fc[a], fm_[q], fc[q])) then q = a end
      pre[a] = q
      last = q
    end
    if not last then return out, 0 end
    local rev = {}
    local a = last
    while a do rev[#rev + 1] = a; a = fp[a] end
    for i = #rev, 1, -1 do out[#out + 1] = rev[i] end
    return out, fm_[last]
  end
  local a = umin - r - s + 1 + o
  while a <= umax + r do
    local ok = true
    for u = a, a + s - 1 do
      if ok and (corridor_col(origin, u) or not body_free(u)) then ok = false end
    end
    local n = 0
    -- lot MELANGE : zone qui touche une autre ressource minable -> refusée (la foreuse en déverserait sur le tapis de la bande)
    if ok and c.has_foreign then
      local x0, y0, x1, y1 = Mel.zone(a, row, s, r)
      if Mel.count(x0, y0, x1, y1, c.is_foreign) > 0 then ok = false end
    end
    if ok then
      for u = a - r, a + s - 1 + r do n = n + col(u) end
    end
    if ok and n >= Ch.CFG.min_ore then
      out[#out + 1] = a
      -- Lot PERF3 : minerai miné compté par colonnes ; les zones vont de gauche à droite (a croît), une colonne déjà comptée est
      -- à gauche de la dernière comptée (`counted`) : même total que l'ensemble des tuiles vues d'avant
      for u = math.max(a - r, counted + 1), a + s - 1 + r do mined = mined + col(u) end
      if a + s - 1 + r > counted then counted = a + s - 1 + r end
      a = a + s
    else
      a = a + 1
    end
  end
  return out, mined
end

--- Meilleur décalage d'une rangée (plus de minerai miné, puis moins de foreuses, puis le plus petit), ou le décalage figé `fixed`.
local function best_row(c, spec, row, umin, umax, origin, fixed, fm)
  local best, bm, bo
  for o = 0, spec.drill.size - 1 do
    if fixed == nil or fixed == o then
      local l, m = row_drills(c, spec, row, umin, umax, origin, o, fm)
      if not best or m > bm or (m == bm and #l < #best) then best, bm, bo = l, m, o end
    end
  end
  -- s41 pavage-trous : la rangée optimale (décalage s) ne remplace le meilleur glouton que si elle mine STRICTEMENT plus de minerai
  local so = spec.drill.size
  if fixed == so or (fixed == nil and not spec.no_row_opt) then
    local l, m = row_drills(c, spec, row, umin, umax, origin, so, fm)
    if not best or m > bm then best, bm, bo = l, m, so end
  end
  return best, bm, bo
end

--- Bandes d'une phase : { { pr, b, n = { u0 }, s = { u0 }, on, os } } et minerai miné (somme des rangées).
--- s46 champ-cout : `rows` (recherche de la phase d'un cadre neuf seulement, `frame` nil, rien n'est pris) garde la place libre (fm) et
--- le meilleur décalage de chaque rangée d'une phase à l'autre : les phases ph et ph + s + 1 relisent les mêmes rangées (mêmes réponses).
local function bands_for(c, spec, phase, box, origin, frame, rows)
  local s = spec.drill.size
  local pitch = 2 * s + 2
  local bands, total = {}, 0
  local pr = box.v0 - phase
  local fm = rows and rows.fm or {} -- lot PERF3 : place libre lue une fois par tuile pendant la passe (rien n'y est pris)
  local function row_of(row, fixed)
    if not rows then return best_row(c, spec, row, box.u0, box.u1, origin, fixed, fm) end
    local r = rows[row]
    if not r then r = { best_row(c, spec, row, box.u0, box.u1, origin, nil, fm) }; rows[row] = r end
    return r[1], r[2], r[3]
  end
  while pr <= box.v1 do
    if not (frame and frame.only) or frame.only[pr] then
      local off = frame and frame.offsets and frame.offsets[tostring(pr)]
      local nl, nm, on = row_of(pr + 1, off and off[1])
      local sl, sm, os_ = row_of(pr + s + 2, off and off[2])
      if #nl + #sl > 0 then
        bands[#bands + 1] = { pr = pr, b = pr + s + 1, n = nl, s = sl, on = on, os = os_ }
        total = total + nm + sm
      end
    end
    pr = pr + pitch
  end
  return bands, total
end

--- Groupe d'une bande du côté `side` : foreuses prises depuis le bord tant que le tapis est libre jusqu'au bord et en deçà de la coupe
--- `limit`. Rend { n, s, cut } (cut : centre de la foreuse la plus loin).
--- F555 (DC, partie 0.7.3 : « 2 foreuses sur toute la largeur d'un gisement géant ») : le NOMBRE de foreuses ne dépend que du minerai
--- couvert (la boîte d'extraction) ; aucun plafond tiré de la fonderie (`side`, voie du charbon) : les fours se dimensionnent à part,
--- sur le débit que le tapis livre (Ch.delivered).
local function take_group(c, spec, band, side, edge, used, limit)
  local half = math.floor(spec.drill.size / 2)
  local all = {}
  for _, a in ipairs(band.n) do if not used[a .. "n"] then all[#all + 1] = { a = a, cu = a + half, side = "n" } end end
  for _, a in ipairs(band.s) do if not used[a .. "s"] then all[#all + 1] = { a = a, cu = a + half, side = "s" } end end
  table.sort(all, function(p, q)
    if p.cu ~= q.cu then if side > 0 then return p.cu > q.cu end return p.cu < q.cu end
    return p.side < q.side
  end)
  if #all == 0 then return nil end
  local function beyond(cu, lim) return (side > 0 and cu <= lim) or (side < 0 and cu >= lim) end
  local stop = limit
  local u, far = edge, all[#all].cu
  while (side > 0 and u >= far) or (side < 0 and u <= far) do
    if not c.free(u, band.b) then
      if not stop or not beyond(u, stop) then stop = u end
      break
    end
    u = u - side
  end
  local g, cnt = { n = {}, s = {} }, { n = 0, s = 0 }
  for i, it in ipairs(all) do
    if stop and beyond(it.cu, stop) then break end
    cnt[it.side] = cnt[it.side] + 1
    g[it.side][#g[it.side] + 1] = it.a
    g.cut = it.cu
  end
  if #g.n + #g.s == 0 or not g.cut then return nil end
  return g
end

--- Lot COUPLAGE (règle 1 du DC, 12/11 : « toute ligne de foreuses déclenche assez de fours pour fondre 100 % de son débit brut ») : le
--- groupe `g` (foreuses rangées du bord `side` vers le milieu, comme take_group) réduit aux `k` foreuses les plus près du bord (one_lane :
--- en tout, la voie de charbon prend l'autre voie ; sinon par côté) : celles que `k` fours fondent quand seule une colonne plus courte
--- trouve sa place (bout de bande sans fonderie). Rend le groupe (le même s'il tient), ou nil si k < 1.
function Ch.trim_group(g, side, half, k, one_lane)
  if not g then return nil end
  if k < 1 then return nil end
  if (one_lane and #g.n + #g.s <= k) or (not one_lane and #g.n <= k and #g.s <= k) then return g end
  local all = {}
  for _, a in ipairs(g.n) do all[#all + 1] = { a = a, cu = a + half, side = "n" } end
  for _, a in ipairs(g.s) do all[#all + 1] = { a = a, cu = a + half, side = "s" } end
  table.sort(all, function(p, q)
    if p.cu ~= q.cu then if side > 0 then return p.cu > q.cu end return p.cu < q.cu end
    return p.side < q.side
  end)
  local out, cnt, tot = { n = {}, s = {} }, { n = 0, s = 0 }, 0
  for _, it in ipairs(all) do
    local fits = one_lane and tot < k or (not one_lane and cnt[it.side] < k)
    if fits then
      cnt[it.side], tot = cnt[it.side] + 1, tot + 1
      out[it.side][#out[it.side] + 1] = it.a
      out.cut = it.cu
    end
  end
  if tot == 0 then return nil end
  return out
end

--- Poteaux de la rangée `row` sur le treillis (u ≡ origin mod P) : un par foreuse non couverte, des relais où les fils manquent,
--- puis jusqu'aux colonnes de poteaux des fonderies `reach_to`. Rend la liste triée des u.
--- Pas du treillis des poteaux le long d'une rangée : au plus la portée des fils, au plus côté + 2 × portée (toute foreuse en touche un).
function Ch.lattice_step(spec)
  return math.max(1, math.min(math.floor(spec.pole.wire + Ch.CFG.eps), spec.drill.size + 2 * spec.pole.reach))
end

local function row_poles(c, spec, row, drills, origin, reach_to, known, nknown)
  local R, s = spec.pole.reach, spec.drill.size
  local P = Ch.lattice_step(spec)
  local function lattice_at_or_after(u) return u + ((origin - u) % P) end
  local set, list = {}, {}
  local function add(u) if not set[u] then set[u] = true; list[#list + 1] = u; c.take(u, row) end end
  local function try(lo, hi, prefer)
    if prefer and prefer >= lo and prefer <= hi and (set[prefer] or c.free(prefer, row)) then add(prefer) return prefer end
    for u = lo, hi do if set[u] then return u end end
    for u = lo, hi do if c.free(u, row) then add(u) return u end end
    return nil
  end
  table.sort(drills)
  for _, a in ipairs(drills) do
    local lo, hi = a - R, a + s - 1 + R
    local covered = false
    for u = lo, hi do if set[u] then covered = true end end
    if not covered then try(lo, hi, lattice_at_or_after(lo)) end
  end
  for _, t in ipairs(reach_to) do
    if #list > 0 then
      table.sort(list)
      local first, last = list[1], list[#list]
      local goal = t
      local from = (goal > last) and last or ((goal < first) and first or nil)
      if from then
        local dir = goal > from and 1 or -1
        local u = from
        local guard = 0
        -- s41 pavage-trous : (1) la marche s'arrête dès que le poteau courant tient par un fil un poteau DÉJÀ posé de la fonderie visée
        -- (`known`, à R tuiles au plus du but) : avant, elle avançait jusqu'à R tuiles du but, et le but pris par ce poteau la faisait
        -- poser un poteau par tuile (trois poteaux côte à côte au bout de chaque rangée) ; (2) la tuile voulue prise, on prend la tuile
        -- libre la plus LOIN vers le but, plus la plus proche du poteau d'avant
        local w2 = spec.pole.wire * spec.pole.wire + Ch.CFG.eps
        local function linked(at)
          for i = 1, nknown or 0 do
            local q = known[i]
            if math.abs(q[1] - goal) <= R and (q[1] - at) * (q[1] - at) + (q[2] - row) * (q[2] - row) <= w2 then return true end
          end
          return false
        end
        while math.abs(goal - u) > R and guard < 400 and not linked(u) do
          guard = guard + 1
          local want = u + dir * P
          if (dir > 0 and want > goal) or (dir < 0 and want < goal) then want = goal end
          local got
          if set[want] or c.free(want, row) then add(want); got = want end
          if not got then for x = want - dir, u + dir, -dir do if set[x] then got = x break end end end
          if not got then for x = want - dir, u + dir, -dir do if c.free(x, row) then add(x); got = x break end end end
          if not got then break end
          u = got
        end
      end
    end
  end
  table.sort(list)
  -- relais : deux poteaux voisins trop loin l'un de l'autre
  local wire = math.floor(spec.pole.wire + Ch.CFG.eps)
  local i = 1
  while i < #list do
    if list[i + 1] - list[i] > wire then
      local got = try(list[i] + 1, list[i] + wire, lattice_at_or_after(list[i] + 1))
      if not got then break end
      table.sort(list)
    end
    i = i + 1
  end
  table.sort(list)
  return list
end

--- Relie les réseaux de poteaux séparés (eau, falaise, fonderie reculée) : relais en ligne droite, sur des tuiles libres, du réseau
--- du premier poteau vers le poteau le plus proche d'un autre réseau. `poles` : { { u, v } } (complété en place). Rend les relais.
local function bridge_0641(c, spec, poles)
  local wire = spec.pole.wire
  local w2 = wire * wire + Ch.CFG.eps
  local added = {}
  for _ = 1, 60 do
    local parent = {}
    for i = 1, #poles do parent[i] = i end
    local function root(i) while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end return i end
    local grid = {}
    local cell = math.max(1, math.ceil(wire))
    for i, p in ipairs(poles) do
      local k = Ch.key(math.floor(p[1] / cell), math.floor(p[2] / cell))
      grid[k] = grid[k] or {}
      grid[k][#grid[k] + 1] = i
    end
    for i, p in ipairs(poles) do
      local gx, gy = math.floor(p[1] / cell), math.floor(p[2] / cell)
      for dx = -1, 1 do
        for dy = -1, 1 do
          for _, j in ipairs(grid[Ch.key(gx + dx, gy + dy)] or {}) do
            local q = poles[j]
            if j > i and (p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 <= w2 then
              local a, b = root(i), root(j)
              if a ~= b then parent[a] = b end
            end
          end
        end
      end
    end
    -- Lot PERF3 : racine de chaque poteau calculée UNE fois (avant : root() dans la double boucle, N² appels), puis les mêmes paires
    -- dans le même ordre (i puis j croissants) : même paire retenue, à égalité comprise.
    local main = root(1)
    local ins, outs = {}, {}
    for i = 1, #poles do if root(i) == main then ins[#ins + 1] = i else outs[#outs + 1] = i end end
    local best, ba, bb
    for _, i in ipairs(ins) do
      local p = poles[i]
      local p1, p2 = p[1], p[2]
      for _, j in ipairs(outs) do
        local q = poles[j]
        local d2 = (p1 - q[1]) ^ 2 + (p2 - q[2]) ^ 2
        if not best or d2 < best then best, ba, bb = d2, i, j end
      end
    end
    if not best then return added end
    local a, b = poles[ba], poles[bb]
    local dist = math.sqrt(best)
    local n = math.ceil(dist / (wire - 0.5)) - 1
    local prev = a
    local ok = n >= 1
    for k = 1, n do
      local iu = math.floor(a[1] + (b[1] - a[1]) * k / (n + 1) + 0.5)
      local iv = math.floor(a[2] + (b[2] - a[2]) * k / (n + 1) + 0.5)
      local put
      for r = 0, 3 do
        for du = -r, r do
          for dv = -r, r do
            local u, v = iu + du, iv + dv
            if not put and math.max(math.abs(du), math.abs(dv)) == r and c.free(u, v)
              and (u - prev[1]) ^ 2 + (v - prev[2]) ^ 2 <= w2 then put = { u, v } end
          end
        end
      end
      if not put then ok = false break end
      c.take(put[1], put[2])
      poles[#poles + 1] = put
      added[#added + 1] = put
      prev = put
    end
    if not ok then return added end
  end
  return added
end

-- (lot FONDERIE) relais à plusieurs paires (Ch.BRIDGE_TRIES) pour la colonne à tapis ; le motif à coffres garde bridge_0641, à l'identique
local function bridge(c, spec, poles)
  local wire = spec.pole.wire
  local w2 = wire * wire + Ch.CFG.eps
  local added = {}
  for _ = 1, 60 do
    local parent = {}
    for i = 1, #poles do parent[i] = i end
    local function root(i) while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end return i end
    local grid = {}
    local cell = math.max(1, math.ceil(wire))
    for i, p in ipairs(poles) do
      local k = Ch.key(math.floor(p[1] / cell), math.floor(p[2] / cell))
      grid[k] = grid[k] or {}
      grid[k][#grid[k] + 1] = i
    end
    for i, p in ipairs(poles) do
      local gx, gy = math.floor(p[1] / cell), math.floor(p[2] / cell)
      for dx = -1, 1 do
        for dy = -1, 1 do
          for _, j in ipairs(grid[Ch.key(gx + dx, gy + dy)] or {}) do
            local q = poles[j]
            if j > i and (p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 <= w2 then
              local a, b = root(i), root(j)
              if a ~= b then parent[a] = b end
            end
          end
        end
      end
    end
    local main = root(1)
    -- (lot FONDERIE) les Ch.BRIDGE_TRIES paires (réseau principal, autre réseau) les plus proches, essayées dans l'ordre : avant, seule la plus
    -- proche l'était, et un échec arrêtait tout (deux rangées de poteaux d'une ligne de charbon à 8 tuiles : leur milieu est sur le tapis et
    -- les foreuses, aucun relais possible là, mais au bout de la ligne oui)
    -- Lot PERF3 : racines calculées une fois, mêmes paires dans le même ordre (voir bridge_0641)
    local ins, outs = {}, {}
    for i = 1, #poles do if root(i) == main then ins[#ins + 1] = i else outs[#outs + 1] = i end end
    local cand = {}
    local tries = Ch.BRIDGE_TRIES
    for _, i in ipairs(ins) do
      local p = poles[i]
      local p1, p2 = p[1], p[2]
      for _, j in ipairs(outs) do
        local q = poles[j]
        local d2 = (p1 - q[1]) ^ 2 + (p2 - q[2]) ^ 2
        if #cand < tries or d2 < cand[#cand][1] then
          local pos = #cand + 1
          while pos > 1 and cand[pos - 1][1] > d2 do pos = pos - 1 end
          table.insert(cand, pos, { d2, i, j })
          if #cand > tries then cand[#cand] = nil end
        end
      end
    end
    if #cand == 0 then return added end
    local done = false
    for _, cd in ipairs(cand) do
      if not done then
        local a, b = poles[cd[2]], poles[cd[3]]
        local n = math.ceil(math.sqrt(cd[1]) / (wire - 0.5)) - 1
        local prev, ok, chain, tmp = a, n >= 1, {}, {}
        for k = 1, n do
          if ok then
            local iu = math.floor(a[1] + (b[1] - a[1]) * k / (n + 1) + 0.5)
            local iv = math.floor(a[2] + (b[2] - a[2]) * k / (n + 1) + 0.5)
            local put
            for r = 0, 3 do
              for du = -r, r do
                for dv = -r, r do
                  local u, v = iu + du, iv + dv
                  if not put and math.max(math.abs(du), math.abs(dv)) == r and c.free(u, v) and not tmp[Ch.key(u, v)]
                    and (u - prev[1]) ^ 2 + (v - prev[2]) ^ 2 <= w2 then put = { u, v } end
                end
              end
            end
            if not put then ok = false else chain[#chain + 1] = put; tmp[Ch.key(put[1], put[2])] = true; prev = put end
          end
        end
        if ok and (prev[1] - b[1]) ^ 2 + (prev[2] - b[2]) ^ 2 <= w2 then
          for _, put in ipairs(chain) do
            c.take(put[1], put[2])
            poles[#poles + 1] = put
            added[#added + 1] = put
          end
          done = true
        end
      end
    end
    if not done then return added end
  end
  return added
end

local function long_axis(spec)
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  local o = spec.ore
  for i = 1, #o - 1, 2 do
    x0, x1 = math.min(x0, o[i]), math.max(x1, o[i])
    y0, y1 = math.min(y0, o[i + 1]), math.max(y1, o[i + 1])
  end
  return (y1 - y0 > x1 - x0) and "y" or "x"
end

--- s46 champ-cout : mémoire de la recherche de phase, tenue le temps d'UN Ch.plan (PHASE_MEMO nil hors de lui). Clé : les tables mêmes
--- (identité) du minerai, des obstacles, de la place minée et des autres ressources, l'axe, la foreuse et no_row_opt.
local PHASE_MEMO
local function phase_memo(spec, axis)
  if not PHASE_MEMO then return nil end
  local d = spec.drill
  for _, m in ipairs(PHASE_MEMO) do
    if m.ore == spec.ore and m.blocked == spec.blocked and m.mine == spec.mine and m.foreign == spec.foreign and m.axis == axis
      and m.size == d.size and m.reach == d.reach and m.no_row_opt == (spec.no_row_opt and true or false) then return m end
  end
  local m = { ore = spec.ore, blocked = spec.blocked, mine = spec.mine, foreign = spec.foreign, axis = axis, size = d.size, reach = d.reach,
    no_row_opt = spec.no_row_opt and true or false }
  PHASE_MEMO[#PHASE_MEMO + 1] = m
  return m
end
--- s49 opti : mémoires de calculs refaits à l'identique entre les plan_once d'un même Ch.plan (tracés du charbon, relais), rangées
--- DANS la table PHASE_MEMO (champ nommé : la liste des phases, lue par ipairs, n'en voit rien) : même durée de vie qu'elle, nil hors
--- d'un Ch.plan. Chaque entrée garde les lectures qu'elle a faites et n'est rendue que si elles donnent les mêmes réponses (résultat exact).
local function run_memo(name)
  if not PHASE_MEMO then return nil end
  local m = PHASE_MEMO[name]
  if not m then m = {}; PHASE_MEMO[name] = m end
  return m
end
local function copy_bands(bands)
  local out = {}
  for i, bd in ipairs(bands) do
    local n, s = {}, {}
    for j, a in ipairs(bd.n) do n[j] = a end
    for j, a in ipairs(bd.s) do s[j] = a end
    out[i] = { pr = bd.pr, b = bd.b, n = n, s = s, on = bd.on, os = bd.os }
  end
  return out
end

--- s52 bandes (priorité du DC : gels de 2 à 5 s d'UNE variante du plan sur la carte à 600 %) : plan_once en machine à états reprenable.
--- Ch.once_begin(spec) -> état (tables simples : aucune fonction, le contexte est délié entre deux étapes) ; Ch.once_step(st) fait UNE
--- étape bornée et rend vrai quand le plan est fini ; Ch.once_result(st) -> plan, ou nil et raison. Étapes, dans l'ordre du calcul d'avant :
---   init   contrôles, contexte, boîte (cadre figé : ses bandes ; mémoire de phase : la copie)   1 étape
---   phase  recherche de la phase : UNE phase par étape (0 .. pas - 1)                       pas étapes (cadre neuf, mémoire vide)
---   band   UNE bande par étape : ses groupes, leur colonne (Co.place), le tapis                une étape par bande
---   net    réseau du charbon d'UN côté (Co.network)                                            0 à 2 étapes
---   branch bras des colonnes, replis au coffre de tête, réserves d'un cadre figé              1 étape
---   bare   UN bout de bande sans fonderie (Co.away)                                            une étape par bout
---   poles  poteaux des rangées ; bridge : relais entre réseaux, puis le plan                    2 étapes
--- Ce qui passe d'une étape à l'autre est dans l'état : tuiles prises (contexte), entités émises, bandes rendues, compteurs, colonnes en
--- attente de leur charbon, bouts sans fonderie, réseaux. Chaque étape fait les mêmes calculs, dans le même ordre, que plan_once d'avant :
--- même plan (empreintes de tests/s46_champ-cout_ref.lua, tests/perf_champ_ref.lua, tests/s52_bandes_test.lua).
local function emit(s, kind, u, v, size, du, dv, bi, gi, pr, role, belt, module)
  local c, ents = s.c, s.ents
  local x, y = c.xy(u, v)
  local x2, y2 = c.xy(u + size - 1, v + size - 1)
  ents[#ents + 1] = { kind = kind, x = math.min(x, x2) + size / 2, y = math.min(y, y2) + size / 2, size = size,
    dir = (du ~= 0 or dv ~= 0) and c.dir(du, dv) or 0, band = bi, group = gi, pr = pr, role = role, belt = belt, module = module }
end
-- (lot FONDERIE) une entité de la colonne ou du réseau de charbon : rectangle w × h (répartiteur), sens de souterrain
local function emit_e(s, e, bi, gi, pr, belt)
  local c, ents = s.c, s.ents
  local w, h = e.w or e.size, e.h or e.size
  local xa, ya = c.xy(e.u, e.v)
  local xb, yb = c.xy(e.u + w - 1, e.v + h - 1)
  local x0, x1, y0, y1 = math.min(xa, xb), math.max(xa, xb), math.min(ya, yb), math.max(ya, yb)
  local o = { kind = e.kind, x = (x0 + x1 + 1) / 2, y = (y0 + y1 + 1) / 2, size = e.size,
    dir = (e.du ~= 0 or e.dv ~= 0) and c.dir(e.du, e.dv) or 0, band = bi, group = gi, pr = pr, role = e.role, belt = belt, ug = e.ug, piq = e.piq, fin = e.fin }
  if e.w then o.w, o.h = x1 - x0 + 1, y1 - y0 + 1 end
  ents[#ents + 1] = o
end
local function note_plates(s, list)
  for _, e in ipairs(list) do if e.kind == "tapis" and e.role == "sortie" then s.plate_dir[Co.tk(e.u, e.v)] = e.du end end
end
local function half_of(s, pr, fixed)
  local spec, pitch = s.spec, s.pitch
  -- cadre figé : la forme qu'il a posée (cadres d'avant le lot : demi-colonnes seules)
  if fixed then return fixed.double and Co.half(spec, pitch, fixed.mirror) or nil end
  local i = math.floor((pr - (s.box.v0 - s.phase)) / pitch + 0.5)
  return s.double and Co.half(spec, pitch, Co.is_facing(i) and s.band_at[pr - Co.SF * pitch] == true) or nil
end
local function belt_for(s, g) -- tapis du groupe : le plus lent qui porte ses foreuses
  local spec = s.spec
  local need_lane = s.fuelled and (#g.n + #g.s) or math.max(#g.n, #g.s)
  for i, bt in ipairs(spec.belts) do if Ch.lane_drills(bt.lane, spec.drill.rate) >= need_lane then return i end end
  return #spec.belts
end
local function once_fail(s, why) s.done, s.why = true, why; return true end

local ONCE = {} -- étapes : ONCE[nom](état) rend vrai si l'étape a fait son calcul borné (sinon l'étape suivante part dans le même pas)

function ONCE.init(s)
  local spec = s.spec
  if not (spec and spec.ore and #spec.ore >= 2 and spec.drill and spec.pole and spec.belts and #spec.belts > 0) then return once_fail(s, "donnees") end
  local d, F = spec.drill, spec.frame
  -- lot FONDERIE : colonne à tapis (shared/team/champ_colonne.lua) pour un cadre neuf qui la demande ; un cadre figé garde SON motif
  -- (un cadre d'une sauvegarde 0.6.38 n'a pas `design` : ses bandes gardent la fonderie à coffres, rien n'est migré)
  local colonne = spec.furnace ~= nil and ((F and F.design) or (not F and spec.design)) == "colonne"
  if spec.furnace and spec.furnace.size > d.size - 1 then return once_fail(s, "four trop grand pour la bande") end
  if colonne then
    if spec.furnace.size < 2 then return once_fail(s, "four trop petit pour les poteaux de la colonne") end
  else
    if spec.furnace and spec.furnace.fuel and spec.furnace.size < 2 then return once_fail(s, "four trop petit pour son coffre de combustible") end
    if spec.furnace and 2 * spec.furnace.size + 3 > spec.pole.wire + Ch.CFG.eps then return once_fail(s, "portee des poteaux") end
  end
  -- s42 gisements : spec.axis impose l'orientation d'un cadre NEUF (essai de l'autre orientation, Ch.axis_retry) ; un cadre figé garde la sienne
  local axis = (F and F.axis) or ((spec.axis == "x" or spec.axis == "y") and spec.axis) or long_axis(spec)
  local c = context(spec, axis)
  local box = { u0 = math.huge, v0 = math.huge, u1 = -math.huge, v1 = -math.huge }
  for _, t in ipairs(c.list) do
    box.u0, box.u1 = math.min(box.u0, t[1]), math.max(box.u1, t[1])
    box.v0, box.v1 = math.min(box.v0, t[2]), math.max(box.v1, t[2])
  end
  s.F, s.colonne, s.axis, s.c, s.box = F, colonne, axis, c, box
  s.origin = (F and F.origin) or box.u0
  s.pitch = 2 * d.size + 2
  if F and F.phase then
    s.phase = F.phase
    box.v0 = F.v0 or box.v0
    s.bands = bands_for(c, spec, s.phase, box, s.origin, F)
    s.stage = "setup"
  else
    -- s46 champ-cout : la recherche de la phase ne lit que le minerai, les obstacles et l'axe (rien n'est encore pris) : elle est faite
    -- UNE fois par Ch.plan et par axe (les passes du refus, l'autre ordre des côtés et les rangées gloutonnes la refaisaient à l'identique)
    local m = phase_memo(spec, axis)
    if m and m.bands then
      s.bands, s.phase = copy_bands(m.bands), m.phase
      s.stage = "setup"
    else
      s.m, s.ph, s.rows = m, 0, { fm = {} }
      s.stage = "phase"
    end
  end
  return true
end

function ONCE.phase(s)
  local bs, total = bands_for(s.c, s.spec, s.ph, s.box, s.origin, nil, s.rows)
  if not s.bands or total > s.bt then s.bands, s.bt, s.phase = bs, total, s.ph end
  s.ph = s.ph + 1
  if s.ph > s.pitch - 1 then
    s.bands = copy_bands(s.bands) -- listes propres au plan (une rangée est partagée entre deux phases)
    if s.m then s.m.bands, s.m.phase = copy_bands(s.bands), s.phase end
    s.m, s.ph, s.rows, s.bt = nil, nil, nil, nil
    s.stage = "setup"
  end
  return true
end

function ONCE.setup(s)
  local spec, c, F, box = s.spec, s.c, s.F, s.box
  local d = spec.drill
  for _, bd in ipairs(s.bands) do
    for _, a in ipairs(bd.n) do for u = a, a + d.size - 1 do for v = bd.pr + 1, bd.pr + d.size do c.take(u, v) end end end
    for _, a in ipairs(bd.s) do for u = a, a + d.size - 1 do for v = bd.b + 1, bd.b + d.size do c.take(u, v) end end end
  end
  local umin, umax = box.u0, box.u1
  for _, bd in ipairs(s.bands) do
    for _, l in ipairs({ bd.n, bd.s }) do for _, a in ipairs(l) do umin = math.min(umin, a); umax = math.max(umax, a + d.size - 1) end end
  end
  if F and F.umin then umin, umax = F.umin, F.umax end
  local exit = (F and F.exit) or 1
  if not (F and F.exit) and spec.target then
    local tu = c.uv(spec.target.x, spec.target.y)
    if math.abs(tu - umin) < math.abs(tu - umax) then exit = -1 end
  end
  local lane = spec.belts[#spec.belts].lane
  local cap = Ch.lane_drills(lane, d.rate)
  if spec.max_side then cap = math.min(cap, spec.max_side) end
  if cap < 1 then return once_fail(s, "tapis trop lent pour une foreuse") end
  -- lot FONDERIE : avec du combustible, la tête charge tout le minerai sur UNE voie (l'autre porte le charbon)
  local fuelled = s.colonne and spec.furnace.fuel
  s.umin, s.umax, s.exit, s.lane, s.fuelled = umin, umax, exit, lane, fuelled
  -- F555 : foreuses que le PREMIER bout d'une bande prend (partage entre les deux bouts, jamais un plafond de la bande)
  s.first_k = fuelled and math.min(2 * cap, Ch.lane_drills(lane, d.rate)) or 2 * cap
  s.ents, s.out_bands = {}, {}
  s.capped, s.flow_all, s.cap_all, s.no_smelter = 0, 0, 0, 0
  s.orphans = 0 -- lot COUPLAGE : foreuses d'un bout sans fonderie, non posées
  s.no_smelter_at = nil -- 9/11 : première tuile prise qui empêche la colonne de fonderie d'un groupe (diagnostic du refus « sans place de fonderie »)
  s.offsets = {}
  s.pending = {} -- (lot FONDERIE) colonnes posées, émises après le choix de leur charbon
  s.bare_todo = {} -- (lot DECOUPLAGE) bouts de bande sans place de fonderie : groupes « tapis collecteur seul », formés après les fonderies
  -- lot COLONNE-DOUBLE (DC, 11/11) : une bande sur deux (parité de son rang dans le cadre) porte la demi-colonne d'en face, ses fours vers
  -- ceux de sa voisine ; les deux demi-colonnes d'un même bout partagent la ligne de plaques centrale (plate_dir : tuile -> sens, posée une fois)
  s.double = s.colonne and Co.half(spec, s.pitch, false) ~= nil
  s.band_at = {} -- pr -> vrai : la demi-colonne d'en face n'est posée que si la bande de sa voisine existe (sinon ses poteaux sans voisin)
  for _, bd in ipairs(s.bands) do s.band_at[bd.pr] = true end
  s.plate_dir = {}
  s.bi = 1
  s.stage = "band"
  return false
end

function ONCE.band(s)
  local bi, bd = s.bi, s.bands[s.bi]
  if not bd then s.bi = nil; s.stage = "coal" return false end
  s.bi = bi + 1
  local spec, c, F = s.spec, s.c, s.F
  local d, colonne, exit, umin, umax, lane, fuelled = spec.drill, s.colonne, s.exit, s.umin, s.umax, s.lane, s.fuelled
  local shared_plate = function(u, v, e) return s.plate_dir[Co.tk(u, v)] == e.du end
  s.offsets[tostring(bd.pr)] = { bd.on, bd.os }
  local used, groups = {}, {}
  -- F555 : le premier bout prend `first_k` foreuses (les plus près de son bord), le second bout TOUT le reste, sans plafond ; premier
  -- groupe sans fonderie : le second prend toute la bande
  local cus = {}
  for _, l in ipairs({ bd.n, bd.s }) do for _, a in ipairs(l) do cus[#cus + 1] = a + math.floor(d.size / 2) end end
  table.sort(cus)
  local k = s.first_k
  local limit = nil
  if Ch.CFG.both_ends and #cus > k then
    -- les foreuses que le second bout ne joint pas (son tapis barré avant elles) restent au premier
    local far = exit > 0 and umin or umax
    local u2 = far
    while u2 >= umin and u2 <= umax and c.free(u2, bd.b) do u2 = u2 + exit end
    if exit > 0 then limit = math.min(cus[#cus - k], u2 - 1) else limit = math.max(cus[k + 1], u2 + 1) end
  end
  for _, side in ipairs(Ch.CFG.both_ends and { exit, -exit } or { exit }) do
    local edge = side > 0 and umax or umin
    local g = take_group(c, spec, bd, side, edge, used, limit)
    limit = nil
    if g then
      local flow = Ch.delivered(#g.n, #g.s, d.rate, lane, fuelled)
      local list, len, s_edge, count, info
      local refused, half
      if colonne then
        local fixed = F and F.cols and F.cols[tostring(bd.pr)] and F.cols[tostring(bd.pr)][tostring(side)]
        refused = (fixed and fixed.mode == "refusee") or (spec.refuse and spec.refuse[tostring(bd.pr) .. ":" .. tostring(side)])
        if refused then
          list = nil -- (lot FONDERIE) colonne refusée : pas de voie de charbon
        elseif not (F and F.cols) or fixed then
          local mode = fuelled and ((fixed and fixed.mode) or "voie") or nil
          half = half_of(s, bd.pr, fixed)
          list, len, s_edge, count, info = Co.place(spec, bd.b, side, edge, Fd.count(spec, flow), Ch.CFG.gap, Ch.CFG.shift, c.free,
            c.is_resource, mode, fixed, half, shared_plate, run_memo("places"))
          if not list and not s.no_smelter_at then
            -- diagnostic : la 1re tuile non libre le long du tapis puis dans la colonne, à la place du cadre figé ou à la 1re place essayée
            local s0 = fixed and fixed.s_edge or (edge + side * (Ch.CFG.gap + 1))
            local pu, pv
            for u = edge + side, s0 - side, side do if not pu and not c.free(u, bd.b) then pu, pv = u, bd.b end end
            if not pu then
              local lay = Co.layout(spec, bd.b, side, s0, fixed and fixed.count or Fd.count(spec, flow), mode, half)
              for _, e in ipairs(lay or {}) do
                for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do if not pu and not c.free(u, v) then pu, pv = u, v end end end
              end
            end
            if pu then
              local px, py = c.xy(pu, pv)
              s.no_smelter_at = { x = px, y = py, fixed = fixed ~= nil, band = bd.pr, side = side }
            end
          end
        end
      else
        list, len, s_edge, count = Fd.place(spec, bd.b, side, edge, flow, Ch.CFG.gap, Ch.CFG.shift, c.free, c.is_resource)
      end
      if list then
        for _, a in ipairs(g.n) do used[a .. "n"] = true end
        for _, a in ipairs(g.s) do used[a .. "s"] = true end
        for _, e in ipairs(list) do for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do c.take(u, v) end end end
        if colonne then note_plates(s, list) end
        g.side, g.flow, g.s_edge, g.len, g.count, g.list, g.info, g.half = side, flow, s_edge, len, count, list, info, half
        g.belt = belt_for(s, g)
        groups[#groups + 1] = g
        limit = g.cut
      else
        s.no_smelter = s.no_smelter + 1
        s.bare_todo[#s.bare_todo + 1] = { bi = bi, bd = bd, used = used, side = side, edge = edge, refused = refused and true or nil }
      end
    end
  end
  -- orphans : foreuses de la bande non posées faute de fonderie (lot COUPLAGE) ; lu par l'ordre des bandes (script/team/champ.lua,
  -- Champ.frame) : une bande sans groupe mais à foreuses en attente reste demandée seule plus tard (lot BANDE-GELEE)
  local bo = { pr = bd.pr, b = bd.b, groups = {}, orphans = 0 }
  for _, l in ipairs({ { bd.n, "n" }, { bd.s, "s" } }) do
    for _, a in ipairs(l[1]) do if not used[a .. l[2]] then s.capped = s.capped + 1 end end
  end
  for gi, g in ipairs(groups) do
    for _, a in ipairs(g.n) do emit(s, "foreuse", a, bd.pr + 1, d.size, 0, 1, bi, gi, bd.pr) end
    for _, a in ipairs(g.s) do emit(s, "foreuse", a, bd.b + 1, d.size, 0, -1, bi, gi, bd.pr) end
    -- tapis de la bande : jusqu'au bout de la fonderie (motif à coffres), jusqu'à la tête de la colonne (lot FONDERIE)
    local s_end = colonne and (g.s_edge - g.side) or (g.s_edge + g.side * (g.len - 1))
    local nb = 0
    for u = g.cut, s_end, g.side do
      c.take(u, bd.b)
      emit(s, "tapis", u, bd.b, 1, g.side, 0, bi, gi, bd.pr, colonne and "bande" or nil, g.belt)
      nb = nb + 1
    end
    if colonne then
      s.pending[#s.pending + 1] = { bi = bi, gi = gi, pr = bd.pr, b = bd.b, g = g }
    else
      for _, e in ipairs(g.list) do emit(s, e.kind, e.u, e.v, e.size, e.du, e.dv, bi, gi, bd.pr, e.role, nil, e.module) end
    end
    local capa = Fd.capacity(spec, g.count)
    s.flow_all, s.cap_all = s.flow_all + g.flow, s.cap_all + capa
    bo.groups[#bo.groups + 1] = { side = g.side, drills = #g.n + #g.s, per_side = math.max(#g.n, #g.s), flow = g.flow, belt = g.belt,
      count = g.count, capacity = capa, belt_tiles = nb, s_edge = g.s_edge, len = g.len, cut = g.cut,
      pole_u = g.s_edge + g.side * (colonne and g.info.head_pole or Fd.pole_col(spec)),
      pole_u2 = colonne and g.s_edge or nil, -- (lot FONDERIE) poteau de liaison de tête, rejoint par la rangée pr + pas
      col_b = g.half and (bd.b + g.half.jog) or nil } -- (lot COLONNE-DOUBLE) demi-colonne d'en face : son tapis sur la rangée de son minerai
  end
  s.out_bands[#s.out_bands + 1] = bo
  return true
end

-- lot FONDERIE : charbon des colonnes, un réseau par côté du champ (cadre neuf : calculé ; bande seule : rejoué du cadre)
function ONCE.coal(s)
  local spec, c, F = s.spec, s.c, s.F
  s.coal_stats = {}
  s.fallback = nil -- (lot FONDERIE) colonnes d'un cadre neuf retombées sur le coffre de tête : { pr, side, why }
  if not s.colonne then s.stage = "bare_prep" return false end
  s.cols_frame, s.coal_frame = {}, {}
  s.nets = {}
  if s.fuelled and not F then
    local pitch = s.pitch
    local zone = { u0 = math.huge, u1 = -math.huge, v0 = math.huge, v1 = -math.huge }
    local function grow(u, v) zone.u0, zone.u1 = math.min(zone.u0, u), math.max(zone.u1, u); zone.v0, zone.v1 = math.min(zone.v0, v), math.max(zone.v1, v) end
    grow(s.umin, s.box.v0 - pitch); grow(s.umax, s.box.v1 + pitch)
    for _, it in ipairs(s.pending) do
      grow(it.g.s_edge, it.b); grow(it.g.s_edge + it.g.side * it.g.info.far, it.b)
    end
    local coal_set, coal_list = {}, {}
    local co = spec.coal
    if co and co.tiles then
      for i = 1, #co.tiles - 1, 2 do
        local u, v = c.uv(co.tiles[i], co.tiles[i + 1])
        local k = Co.tk(u, v)
        if not coal_set[k] then coal_set[k] = true; coal_list[#coal_list + 1] = { u, v } end
      end
    end
    local ugs = {}
    for _, k in ipairs(spec.ug_tiles or {}) do local u, v = c.uv(k[1], k[2]); ugs[Co.tk(u, v)] = true end
    s.zone, s.coal_set, s.coal_list, s.ugs = zone, coal_set, coal_list, ugs
    -- (revue-fonderie, 3/11) ordre des côtés : le premier réseau prend ses tuiles, le second ne croise son tracé qu'en souterrain ;
    -- spec.coal_first (posé par Ch.plan) fait passer l'autre côté d'abord
    s.first = spec.coal_first or s.exit
    s.side_i = 1
    s.stage = "net"
  else
    if F and F.coal then
      for _, side in ipairs({ s.exit, -s.exit }) do
        local cf = F.coal[tostring(side)]
        if cf then s.nets[side] = { uT = cf.uT, dv = cf.dv, split = cf.split, ents = cf.ents or {}, last = cf.last, why = cf.why } end
      end
    end
    s.stage = "branch"
  end
  return false
end

function ONCE.net(s)
  local side = s.side_i == 1 and s.first or -s.first
  s.side_i = s.side_i + 1
  if s.side_i > 2 then s.stage = "branch" end
  local spec, c = s.spec, s.c
  local d = spec.drill
  local cols = {}
  for _, it in ipairs(s.pending) do
    if it.g.side == side then
      cols[#cols + 1] = { key = tostring(it.pr), coal_v = it.g.info.b_coal, link_v = it.g.info.b_link, s_edge = it.g.s_edge,
        far = it.g.info.far, need = it.g.info.need }
    end
  end
  if #cols == 0 then return false end
  local co = spec.coal
  local lg = spec.logistics or {}
  local zone, coal_set = s.zone, s.coal_set
  local env = {
    free = c.free, coal = { tiles = s.coal_list, is_coal = function(u, v) return coal_set[Co.tk(u, v)] == true end, rate = co and co.rate,
      -- lot MELANGE : tuiles d'une autre ressource minable autour du charbon (le minerai du champ compris)
      is_foreign = co and co.foreign and function(u, v)
        if coal_set[Co.tk(u, v)] then return false end
        local x, y = c.xy(u, v)
        return co.foreign[Ch.key(x, y)] == true
      end or nil },
    forbid = function(u, v) return u >= zone.u0 - 1 and u <= zone.u1 + 1 and v >= zone.v0 - 1 and v <= zone.v1 + 1 end,
    -- (banc-2, 3/11) pas de répartiteur sur le tronc même débloqué : la cascade 50/50 n'a pas de plafond par colonne, les dernières
    -- attendent que les tampons d'amont se remplissent (mesuré : 12, 6, 4 et 4 fours garnis le long du tronc) ; le bras de
    -- dérivation, lui, borne la prise de chaque colonne. Les souterrains restent (passer sous un obstacle).
    drill = d, pole = spec.pole, ug = lg.underground, split = false, ugs = s.ugs, box = zone,
    inserter_rate = spec.inserter and spec.inserter.rate,
    soft = spec.soft and function(u, v) local x, y = c.xy(u, v); return spec.soft[Ch.key(x, y)] == true end or nil,
    lane_drills = co and co.rate and Ch.lane_drills(spec.belts[1].lane, co.rate) or nil,
    route_memo = run_memo("routes"), line_memo = run_memo("lines"), -- s49 opti : tracés du charbon refaits à l'identique d'un plan_order à l'autre
    bridge = function(poles, free)
      local extra = {}
      local cc = { free = function(u, v) return not extra[Co.tk(u, v)] and free(u, v) end, take = function(u, v) extra[Co.tk(u, v)] = true end }
      return bridge(cc, spec, poles)
    end,
  }
  s.nets[side] = Co.network(cols, side, env)
  local nt = s.nets[side]
  -- le réseau prend ses tuiles (poteaux des rangées et relais du champ ne s'y posent pas)
  for _, e in ipairs(nt.ents) do
    for u = e.u, e.u + (e.w or e.size) - 1 do for v = e.v, e.v + (e.h or e.size) - 1 do c.take(u, v) end end
  end
  local last_key
  for _, cl in ipairs(cols) do if cl.last then last_key = cl.key end end
  local why = nt.why
  if nt.dropped and #nt.dropped > 0 then why = (why and (why .. " ; ") or "") .. table.concat(nt.dropped, " ; ") end
  s.coal_frame[tostring(side)] = { uT = nt.uT, dv = nt.dv, split = nt.split, last = last_key, ents = nt.ents, why = why,
    drills = nt.drills, undergrounds = nt.undergrounds }
  return true
end

function ONCE.branch(s)
  local spec, c, F = s.spec, s.c, s.F
  local d, exit, nets, coal_frame, ents = spec.drill, s.exit, s.nets, s.coal_frame, s.ents
  s.zone, s.coal_set, s.coal_list, s.ugs, s.first, s.side_i = nil, nil, nil, nil, nil, nil
  local shared_done = {}
  local fallback = {}
  s.fallback = fallback
  for _, it in ipairs(s.pending) do
    local g = it.g
    local key = tostring(it.pr)
    local nt = nets[g.side]
    local mode = g.info.mode
    if mode == "voie" then
      if F and F.cols then
        mode = F.cols[key][tostring(g.side)].mode
      else
        mode = (nt and nt.modes and nt.modes[key]) or "coffre"
      end
    end
    if mode == "coffre" and g.info.mode == "voie" and not F then
      local cf = coal_frame[tostring(g.side)]
      fallback[#fallback + 1] = { pr = it.pr, side = g.side, why = (cf and cf.why) or "pas de reseau du charbon" }
    end
    if mode == "coffre" and g.info.mode == "voie" then
      -- repli : le coffre de tête (ses tuiles sont dans celles de la voie, déjà prises)
      local list, len, info = Co.layout(spec, it.b, g.side, g.s_edge, g.count, "coffre", g.half, g.info.ext)
      -- (lot COLONNE-DOUBLE) la ligne de plaques commune n'est rendue que par la demi-colonne qui l'a posée la première
      local kept = {}
      for _, e in ipairs(g.list) do if e.kind == "tapis" and e.role == "sortie" then kept[Co.tk(e.u, e.v)] = true end end
      local own = {}
      for _, e in ipairs(list) do if not (e.kind == "tapis" and e.role == "sortie") or kept[Co.tk(e.u, e.v)] then own[#own + 1] = e end end
      g.list, g.info = own, info
      g.len = math.min(g.len, len)
    end
    for _, e in ipairs(g.list) do
      emit_e(s, e, it.bi, it.gi, it.pr, e.kind == "tapis" and (e.role == "charbon" and 1 or g.belt) or nil)
      -- lot FONDERIE-BLOC : le coffre de tête porte le charbon/s que sa colonne brûle (son quai a un débit : la liaison, le piquage et
      -- l'alimentation de quai le voient ; avant, 0 et « ne_se_paie_pas »)
      if e.kind == "coffre" and e.role == "combustible" then ents[#ents].need = g.info.need end
    end
    if mode == "voie" and nt and nt.uT then
      local cf = (F and F.cols) and nt or coal_frame[tostring(g.side)]
      local col = { coal_v = g.info.b_coal, link_v = g.info.b_link, s_edge = g.s_edge, far = g.info.far, last = (cf and cf.last) == key }
      for _, e in ipairs(Co.branch(col, nt, g.side, spec.pole.wire)) do
        for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do c.take(u, v) end end
        emit_e(s, e, it.bi, it.gi, it.pr, e.kind == "tapis" and 1 or nil)
      end
      if not shared_done[g.side] then
        shared_done[g.side] = true
        -- (projet séparé, 3/11) pièces COMMUNES du réseau du charbon d'un côté, marquées : le runtime les pose dans le projet « réseau du
        -- charbon » de ce côté, pas dans la bande
        for _, e in ipairs(nt.ents) do
          emit_e(s, e, 0, 0, nil, (e.kind == "tapis" or e.kind == "souterrain" or e.kind == "repartiteur") and 1 or nil)
          ents[#ents].coalnet = g.side
        end
      end
    end
    s.cols_frame[key] = s.cols_frame[key] or {}
    s.cols_frame[key][tostring(g.side)] = { s_edge = g.s_edge, count = g.count, mode = mode, double = g.half and true or nil,
      mirror = (g.half and g.half.mirror) or nil, ext = g.info.ext }
    g.mode = mode
    local og = s.out_bands[it.bi] and s.out_bands[it.bi].groups[it.gi]
    if og then og.mode = (mode == "voie" and nt and nt.uT) and "voie" or mode end
  end
  for _, side in ipairs({ exit, -exit }) do
    local nt = nets[side]
    if nt then
      local why = nt.why
      if nt.dropped and #nt.dropped > 0 then why = (why and (why .. " ; ") or "") .. table.concat(nt.dropped, " ; ") end
      s.coal_stats[#s.coal_stats + 1] = { side = side, voie = nt.uT ~= nil, why = why, drills = nt.drills, undergrounds = nt.undergrounds, split = nt.split }
    end
  end
  if F and F.coal then s.coal_frame = F.coal end
  -- bande seule : les colonnes des AUTRES bandes du cadre sont réservées (non posées) avant les poteaux des rangées, qui les
  -- contournent comme dans le plan entier (sinon un poteau prolongé prendrait la tuile d'un bras d'une colonne voisine à venir)
  if F and F.cols then
    local keys = {}
    for k in pairs(F.cols) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tonumber(a) < tonumber(b) end)
    for _, k in ipairs(keys) do
      for _, sk in ipairs({ "1", "-1" }) do
        local fc = F.cols[k][sk]
        if fc and fc.mode ~= "refusee" and not (F.only and F.only[tonumber(k)]) then
          local l = Co.layout(spec, tonumber(k) + d.size + 1, tonumber(sk), fc.s_edge, fc.count, fc.mode,
            fc.double and Co.half(spec, s.pitch, fc.mirror) or nil)
          for _, e in ipairs(l or {}) do
            for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do c.take(u, v) end end
          end
        end
      end
    end
  end
  s.nets = nil
  s.stage = "bare_prep"
  return true
end

-- lot DECOUPLAGE (directive du DC du 11/11 ; maillon prouvé par PAVAGE-GEANT, 0.7.5, graine 2507543475 : émeraude fer, 37 foreuses sur
-- 42 retirées faute de place pour les fours) : une foreuse ne dépend QUE du minerai. Une fois TOUTES les fonderies posées (colonnes ET réseau du charbon :
-- formé plus tôt, son tapis barrait le tracé du charbon, banc 2507543475 : azure fer 58 fours -> 10), les
-- foreuses qu'aucun groupe n'a prises au bout d'une bande sans place de fonderie forment un groupe « tapis collecteur seul » (g.bare :
-- tapis jusqu'au bord du champ, tuile devant sa sortie réservée, aucune fonderie dans ce plan : elle se pose ailleurs sur le sol neutre).
-- lot FONDERIE-BOUT : tuiles lues (spec.window, repère x, y) et souterrains déjà posés, dans le repère (u, v) du plan
function ONCE.bare_prep(s)
  local spec, c = s.spec, s.c
  s.win, s.away_why = nil, nil -- away_why : première raison d'un bout resté sans colonne (journal du plan)
  if spec.window then
    local wu0, wv0 = c.uv(spec.window[1], spec.window[2])
    local wu1, wv1 = c.uv(spec.window[3], spec.window[4])
    s.win = { u0 = math.min(wu0, wu1), v0 = math.min(wv0, wv1), u1 = math.max(wu0, wu1), v1 = math.max(wv0, wv1) }
  end
  s.ug_uv = {}
  for _, k in ipairs(spec.ug_tiles or {}) do local u, v = c.uv(k[1], k[2]); s.ug_uv[Co.tk(u, v)] = true end
  s.ti = 1
  s.stage = "bare"
  return false
end

-- lot COUPLAGE (règles du DC du 12/11 : « toute ligne de foreuses déclenche assez de fours pour fondre 100 % de son débit brut » ; plus
-- aucune foreuse orpheline. Partie du DC 0.7.90 à 190 min : 751 foreuses de champ figées sur 1 396, dont les bandes « tapis collecteur
-- seul » dont le tapis s'arrête dans l'herbe : amber fer, 11 bandes et 249 foreuses sans un four, « aucune place sur le sol neutre ») :
-- un bout de bande sans place de fonderie dans son prolongement ne garde ses foreuses QUE si une colonne les reçoit ailleurs (Co.away),
-- au besoin plus courte (moitié, quart des fours : le groupe est réduit à ce qu'elle fond). Sinon RIEN n'est posé : ni foreuse, ni tapis
-- (leur minerai attend une fonderie). Une colonne refusée faute de voie de charbon (t.refused) n'en reçoit pas : ses foreuses non plus.
function ONCE.bare(s)
  local t = s.bare_todo[s.ti]
  if not t then s.ti, s.ug_uv = nil, nil; s.stage = "poles" return false end
  s.ti = s.ti + 1
  local spec, c = s.spec, s.c
  local d, colonne, fuelled, lane, pitch, win = spec.drill, s.colonne, s.fuelled, s.lane, s.pitch, s.win
  local ug_uv = s.ug_uv
  local half_d = math.floor(d.size / 2)
  local bd, bo = t.bd, s.out_bands[t.bi]
  local g0 = take_group(c, spec, bd, t.side, t.edge, t.used, nil)
  if not g0 then return false end
  -- le tapis finit au bord du champ, ou plus tôt (jamais avant la dernière foreuse) si la tuile devant sa sortie est déjà prise : le
  -- minerai ne tombe sur aucun autre tapis
  local e_end = t.edge
  while e_end ~= g0.cut and not c.free(e_end + t.side, bd.b) do e_end = e_end - t.side end
  local g, aw, aw_why
  if colonne and not t.refused then
    for u = g0.cut, e_end, t.side do c.take(u, bd.b) end -- (le tracé du lien ne repasse pas sur le collecteur)
    local want = Fd.count(spec, Ch.delivered(#g0.n, #g0.s, d.rate, lane, fuelled))
    local counts = { want }
    -- colonne plus courte : four électrique seulement. Une colonne ailleurs à combustible prend un coffre de tête que rien ne garnit
    -- en 60 min (banc partie-reelle-60, graine 123456789 : amber, 2 colonnes courtes, le plan du champ en est changé et 21 fours de la
    -- bande -291 restent sans charbon, fer 405 -> 8 plaques/min en fin de banc)
    for _ = 1, (fuelled and 0 or 2) do
      local n2 = math.ceil(counts[#counts] / 2)
      if n2 >= 1 and n2 < counts[#counts] then counts[#counts + 1] = n2 end
    end
    -- recul : jusqu'au bord des tuiles lues le long de l'axe (sans rectangle connu, celui de Co.place)
    local u0 = e_end + t.side
    local reach = win and math.max(0, t.side > 0 and (win.u1 - u0) or (u0 - win.u0)) or (Ch.CFG.shift + Ch.CFG.gap)
    for _, cnt in ipairs(counts) do
      local gc = g0
      if cnt < want then
        local capa = Fd.capacity(spec, cnt)
        local k = fuelled and math.floor(capa / d.rate + Ch.CFG.eps) or math.floor(capa / (2 * d.rate) + Ch.CFG.eps)
        gc = Ch.trim_group(g0, t.side, half_d, k, fuelled)
      end
      if gc then
        aw, aw_why = Co.away(spec, { u = u0, v = bd.b }, t.side, cnt, fuelled and "coffre" or nil,
          c.free, c.is_resource, { shift = reach, rows = 2 * pitch, ug = (spec.logistics or {}).underground,
            span = function(u, v) return not ug_uv[Co.tk(u, v)] end, box = win })
        if aw then g = gc break end
      end
    end
    if not aw and not s.away_why then s.away_why = string.format("bande %d : %s", bd.pr, tostring(aw_why)) end
  end
  if aw then
    for _, a in ipairs(g.n) do t.used[a .. "n"] = true end
    for _, a in ipairs(g.s) do t.used[a .. "s"] = true end
    s.capped = s.capped - #g.n - #g.s
    local gi = #bo.groups + 1
    for _, a in ipairs(g.n) do emit(s, "foreuse", a, bd.pr + 1, d.size, 0, 1, t.bi, gi, bd.pr) end
    for _, a in ipairs(g.s) do emit(s, "foreuse", a, bd.b + 1, d.size, 0, -1, t.bi, gi, bd.pr) end
    g.belt = belt_for(s, g)
    local nb = 0
    for u = g.cut, e_end, t.side do
      c.take(u, bd.b)
      emit(s, "tapis", u, bd.b, 1, t.side, 0, t.bi, gi, bd.pr, colonne and "bande" or nil, g.belt)
      nb = nb + 1
    end
    local flow = Ch.delivered(#g.n, #g.s, d.rate, lane, fuelled)
    s.flow_all = s.flow_all + flow
    for _, r in ipairs(aw.route) do
      c.take(r.u, r.v)
      local dv = Co.D4[r.d]
      emit_e(s, { kind = r.kind, u = r.u, v = r.v, size = 1, du = dv[1], dv = dv[2], role = "lien", ug = r.ug }, t.bi, gi, bd.pr, g.belt)
    end
    local ents = s.ents
    for _, e in ipairs(aw.list) do
      for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do c.take(u, v) end end
      emit_e(s, e, t.bi, gi, bd.pr, e.kind == "tapis" and (e.role == "charbon" and 1 or g.belt) or nil)
      if e.kind == "coffre" and e.role == "combustible" then ents[#ents].need = aw.info.need end
    end
    local capa = Fd.capacity(spec, aw.count)
    s.cap_all = s.cap_all + capa
    bo.groups[gi] = { side = t.side, drills = #g.n + #g.s, per_side = math.max(#g.n, #g.s), flow = flow, belt = g.belt, count = aw.count,
      capacity = capa, belt_tiles = nb, s_edge = aw.s_edge, len = aw.len, cut = g.cut, pole_u = e_end, pole_u2 = colonne and e_end or nil,
      away = true, col_b = aw.b, mode = aw.info.mode }
  else
    s.orphans = s.orphans + #g0.n + #g0.s -- foreuses NON posées : aucune fonderie ne les recevrait
    bo.orphans = bo.orphans + #g0.n + #g0.s
    -- leurs tuiles (rangée du collecteur, tuile devant sa sortie) restent prises dans ce plan, comme avant le lot : les autres bouts ne
    -- s'y placent pas (même plan qu'avant, foreuses et tapis en moins)
    for u = g0.cut, e_end, t.side do c.take(u, bd.b) end
    c.take(e_end + t.side, bd.b)
  end
  return true
end

-- poteaux des rangées : la rangée pr couvre le haut de sa bande et le bas de la bande d'avant ; elle va jusqu'aux fonderies (lot
-- FONDERIE : seule la rangée pr, du côté des fours, va jusqu'à la colonne ; l'autre passerait sur la colonne de la bande voisine)
function ONCE.poles(s)
  local spec, c, pitch, colonne = s.spec, s.c, s.pitch, s.colonne
  local rows, row_list, reach_to = {}, {}, {}
  for bi, bd in ipairs(s.bands) do
    local bo = s.out_bands[bi]
    if #bo.groups > 0 then
      for _, it in ipairs({ { bd.pr, bd.n, bd.pr, "pole_u" }, { bd.pr + pitch, bd.s, bd.pr, colonne and "pole_u2" or "pole_u" } }) do
        local row = it[1]
        if not rows[row] then rows[row] = {}; reach_to[row] = {}; row_list[#row_list + 1] = { row = row, pr = it[3] } end
        for _, a in ipairs(it[2]) do rows[row][#rows[row] + 1] = a end
        for _, g in ipairs(bo.groups) do reach_to[row][#reach_to[row] + 1] = g[it[4]] end
      end
    end
  end
  table.sort(row_list, function(p, q) return p.row < q.row end)
  local all_poles = {}
  for _, e in ipairs(s.ents) do
    if e.kind == "poteau" then local u, v = c.uv(math.floor(e.x), math.floor(e.y)); all_poles[#all_poles + 1] = { u, v } end
  end
  local nfound = #all_poles -- s41 pavage-trous : les poteaux des fonderies seuls (ceux des rangées s'ajoutent après)
  for _, r in ipairs(row_list) do
    table.sort(reach_to[r.row])
    for _, u in ipairs(row_poles(c, spec, r.row, rows[r.row], s.origin, reach_to[r.row], all_poles, nfound)) do
      emit(s, "poteau", u, r.row, 1, 0, 0, 0, 0, r.pr)
      all_poles[#all_poles + 1] = { u, r.row }
    end
  end
  s.all_poles = all_poles
  s.stage = "bridge"
  return true
end

function ONCE.bridge(s)
  local F, all_poles = s.F, s.all_poles
  s.all_poles = nil
  s.stage = "finish"
  if not (F and F.only) and #all_poles > 1 then
    for _, p in ipairs((s.colonne and bridge or bridge_0641)(s.c, s.spec, all_poles)) do emit(s, "poteau", p[1], p[2], 1, 0, 0, 0, 0, nil, "relais") end
    return true
  end
  return false
end

function ONCE.finish(s)
  local spec, F, colonne, ents, out_bands = s.spec, s.F, s.colonne, s.ents, s.out_bands
  local n = { foreuse = 0, poteau = 0, tapis = 0, four = 0, bras = 0, coffre = 0, souterrain = 0, repartiteur = 0 }
  for _, e in ipairs(ents) do n[e.kind] = n[e.kind] + 1 end
  local frame = { axis = s.axis, phase = s.phase, exit = s.exit, origin = s.origin, umin = s.umin, umax = s.umax, v0 = s.box.v0, offsets = s.offsets }
  if colonne then frame.design, frame.cols, frame.coal = "colonne", s.cols_frame, s.coal_frame
  elseif spec.design and not F then frame.design = "coffres" end -- cadre neuf sans four (charbon, pierre) : distinct d'un cadre d'avant le lot
  local band_drills = 0
  for _, bd in ipairs(s.bands) do band_drills = band_drills + #bd.n + #bd.s end
  -- lot FONDERIE-BOUT : groupes dont la colonne est posée ailleurs / tapis collecteurs seuls (sans fonderie dans ce plan)
  local away, bare = 0, 0
  for _, bo in ipairs(out_bands) do for _, g in ipairs(bo.groups) do if g.away then away = away + 1 end end end
  for _, bo in ipairs(out_bands) do for _, g in ipairs(bo.groups) do if g.bare then bare = bare + 1 end end end
  s.plan = {
    axis = s.axis, exit = s.exit, phase = s.phase, pitch = s.pitch, ents = ents, bands = out_bands, design = colonne and "colonne" or nil,
    fallback = s.fallback,
    fuelled = s.fuelled or nil,
    frame = frame,
    stats = { tiles = #s.c.list, drills = n.foreuse, poles = n.poteau, belts = n.tapis, furnaces = n.four, inserters = n.bras,
      chests = n.coffre, capped = s.capped, flow = s.flow_all, capacity = s.cap_all, umin = s.umin, umax = s.umax, no_smelter = s.no_smelter,
      no_smelter_at = s.no_smelter_at, undergrounds = n.souterrain, splitters = n.repartiteur, coal = s.coal_stats,
      band_drills = band_drills,
      away = away,
      away_why = s.away_why, orphans = s.orphans, -- lot COUPLAGE : foreuses non posées faute de fonderie
      bare = bare },
  }
  s.done = true
  return true
end

Ch.ONCE_STEPS = 0 -- s52 bandes : étapes de plan_once faites (compteur des tests ; jamais lu pour une décision)

function Ch.once_begin(spec) return { spec = spec, stage = "init" } end

--- UNE étape bornée (les étapes sans calcul notable, setup, coal, bare_prep, finish, s'enchaînent à la suivante dans le même appel).
--- Rend vrai quand le plan est fini. Le contexte est relié au début de l'étape et délié à la fin : l'état ne garde aucune fonction.
function Ch.once_step(s)
  if s.done then return true end
  if s.c then bind(s.c) end
  local heavy
  repeat heavy = ONCE[s.stage](s) until heavy or s.done
  if s.c then unbind(s.c) end
  if s.done then s.c = nil end
  Ch.ONCE_STEPS = Ch.ONCE_STEPS + 1
  return s.done == true
end

function Ch.once_result(s)
  if s.plan then return s.plan end
  return nil, s.why
end

local function plan_once(spec)
  local s = Ch.once_begin(spec)
  while not Ch.once_step(s) do end
  return Ch.once_result(s)
end

--- Plan du champ (voir plus haut). Lot FONDERIE : un cadre NEUF en colonne à combustible ne garde aucune colonne retombée sur le coffre de
--- tête : elles sont refusées (spec.refuse) et le plan est refait sans elles ; le cadre les note « refusee » (une bande seule les saute).
--- plan.refused = { { pr, side, why } } (journal « colonne refusee : pas de voie de charbon »).
--- Foreuses du champ d'un plan (la ligne de charbon exclue).
function Ch.field_drills(p)
  local n = 0
  for _, e in ipairs(p and p.ents or {}) do if e.kind == "foreuse" and e.role ~= "charbon" then n = n + 1 end end
  return n
end

--- Règle pure (lot FONDERIE, 3/11) : le refus des colonnes sans voie de charbon est-il gardé ? before / after : fours du champ avec le
--- coffre de tête / avec le refus (lot DECOUPLAGE : les fours, plus les foreuses, qui restent). Rend (gardé, coût en % perdu, arrondi).
function Ch.refuse_keeps(before, after, min)
  if before <= 0 then return true, 0 end
  local cost = math.floor((1 - after / before) * 100 + 0.5)
  return after >= (min or Ch.CFG.refuse_min) * before - 1e-9, cost
end

--- Fours d'un plan.
function Ch.furnaces(p)
  local n = 0
  for _, e in ipairs(p and p.ents or {}) do if e.kind == "four" then n = n + 1 end end
  return n
end

--- s52 bandes : plan_order en machine à états (sur celle de plan_once) : le plan de la spec, puis les passes du refus des colonnes au
--- coffre de tête (au plus Ch.CFG.refuse_passes plan_once de plus), puis le choix (Ch.refuse_keeps). Mêmes calculs, même ordre qu'avant.
--- order_begin(spec) -> état ; order_step(o) : UNE étape de plan_once (et, quand il finit, la décision de la passe suivante) ; vrai à la fin
--- (o.p, o.why : plan et raison).
local function order_begin(spec) return { spec = spec, once = Ch.once_begin(spec), pass = 0 } end
local function order_final(o)
  local p, p0 = o.p, o.p0
  -- refus impossible (plan vide, ou replis encore là après les passes) : il coûte toute la fonderie
  local after = (p and not (p.fallback and #p.fallback > 0)) and Ch.furnaces(p) or 0
  local keep, cost = Ch.refuse_keeps(Ch.furnaces(p0), after)
  if not keep then
    p0.coffre_cost, p0.coffre_cols = cost, #p0.fallback
    o.p, o.why = p0, o.why0
  else
    local refused = o.refused
    table.sort(refused, function(a, b) if a.pr ~= b.pr then return a.pr < b.pr end return a.side < b.side end)
    p.refused, p.refuse_cost = refused, cost
    if p.frame.cols then
      for _, x in ipairs(refused) do
        local key = tostring(x.pr)
        p.frame.cols[key] = p.frame.cols[key] or {}
        p.frame.cols[key][tostring(x.side)] = { mode = "refusee" }
      end
    end
  end
  o.once, o.p0, o.why0, o.refuse, o.refused = nil, nil, nil, nil, nil
  o.done = true
  return true
end
local function order_step(o)
  if o.done then return true end
  if not Ch.once_step(o.once) then return false end
  local p, why = Ch.once_result(o.once)
  local spec = o.spec
  if o.pass == 0 then
    if not (Ch.CFG.refuse_coffre and p and p.design == "colonne" and p.fuelled and not spec.frame) or not (p.fallback and #p.fallback > 0) then
      o.p, o.why, o.once, o.done = p, why, nil, true
      return true
    end
    o.p0, o.why0 = p, why -- plan avec les colonnes au coffre de tête (0.6.42) : gardé si le refus coûte trop
    o.refuse, o.refused = {}, {}
  end
  o.p, o.why = p, why
  if not p or o.pass >= Ch.CFG.refuse_passes or not (p.fallback and #p.fallback > 0) then return order_final(o) end
  o.pass = o.pass + 1
  for _, x in ipairs(p.fallback) do
    local k = tostring(x.pr) .. ":" .. tostring(x.side)
    if not o.refuse[k] then o.refuse[k] = true; o.refused[#o.refused + 1] = x end
  end
  local sp = {}
  for k, v in pairs(spec) do sp[k] = v end
  sp.refuse = o.refuse
  o.once = Ch.once_begin(sp)
  return false
end

local function plan_order(spec)
  local o = order_begin(spec)
  while not order_step(o) do end
  return o.p, o.why
end

--- Coffres de tête (combustible) d'un plan.
function Ch.head_chests(p)
  local n = 0
  for _, e in ipairs(p and p.ents or {}) do if e.kind == "coffre" and e.role == "combustible" then n = n + 1 end end
  return n
end

--- Règle pure (revue-fonderie, 3/11) : des deux ordres des côtés du réseau du charbon, le meilleur plan : le moins de coffres de tête,
--- puis le plus de fours, puis le plus de foreuses du champ ; à égalité, le premier (ordre habituel). Rend vrai si `b` est meilleur que `a`.
--- Lot FONDERIE-BOUT (banc default 20 min, graine 2507543475 : fer d'azur 58 fours -> 10) : le plan qui a moins de coffres ne gagne que
--- s'il garde la part des fours que le refus exige (Ch.refuse_keeps, la même règle que le refus d'une colonne).
function Ch.better_order(a, b)
  if not b then return false end
  if not a then return true end
  local ca, cb = Ch.head_chests(a), Ch.head_chests(b)
  local fa, fb = Ch.furnaces(a), Ch.furnaces(b)
  if ca ~= cb then
    if cb < ca then return (Ch.refuse_keeps(fa, fb)) end
    return not (Ch.refuse_keeps(fb, fa))
  end
  if fa ~= fb then return fb > fa end
  return Ch.field_drills(b) > Ch.field_drills(a)
end

--- Plan du champ. (revue-fonderie, 3/11 : 3 champs de fer sur environ 10 gardaient des coffres de tête, le côté calculé en second ne
--- croisant pas le tracé du premier sans souterrain ; rejoué hors jeu sur le cadre de scarlet, graine 20261020 : côté + « aucun chemin »,
--- 4 coffres de tête ; l'autre ordre : 0 coffre, une colonne refusée de l'autre côté, 13 % des foreuses) un cadre NEUF en colonne à
--- combustible qui garde un coffre de tête ou refuse une colonne est aussi calculé dans l'autre ordre des côtés ; le meilleur est gardé.
-- (plan_both) Vrai si le plan `p` de la spec `s` demande l'autre ordre des côtés : conditions de plan_both, à l'identique.
local function both_wants(s, p)
  if not (Ch.CFG.both_orders and p and p.design == "colonne" and p.fuelled and not s.frame and not s.coal_first) then return false end
  if Ch.head_chests(p) == 0 and not (p.refused and #p.refused > 0) then return false end
  return true
end
-- (plan_both) Choix entre le plan `a` ({ p, why }) et l'autre ordre `b` (nil : pas calculé). `mark` : pose order_swapped (comme plan_both).
local function both_pick(a, b, mark)
  if b and Ch.better_order(a.p, b.p) then
    if mark then b.p.order_swapped = { chests = Ch.head_chests(a.p), drills = Ch.field_drills(a.p) } end
    return b.p, b.why
  end
  return a.p, a.why
end
--- s41 pavage-trous : les rangées optimales (décalage s, row_drills) posent des foreuses là où le glouton laissait un trou ; sur un cadre
--- neuf où ce plan garde un coffre de tête (voie du charbon sans chemin), le plan aux rangées gloutonnes seules est essayé, et gardé
--- s'il a MOINS de coffres de tête (cadre réel du joueur, graine 271828182 : 4 foreuses de plus fermaient une voie du charbon).
-- (plan_rows) Vrai si le plan `p` de la spec `spec` demande le plan aux rangées gloutonnes : conditions de plan_rows, à l'identique.
local function rows_wants(spec, p)
  if spec.frame or spec.no_row_opt or not p or p.design ~= "colonne" or Ch.head_chests(p) == 0 then return false end
  local opt = false
  local s = spec.drill.size
  for _, bd in ipairs(p.bands or {}) do
    local off = p.frame and p.frame.offsets and p.frame.offsets[tostring(bd.pr)]
    if off and (off[1] == s or off[2] == s) then opt = true end
  end
  return opt
end
local function spec_with(spec, k, v)
  local sp = {}
  for kk, vv in pairs(spec) do sp[kk] = vv end -- copie de la spec (pas une décision)
  sp[k] = v
  return sp
end

--- s49 tranches : le plan d'un cadre neuf pas à pas, UN plan_order par pas. Variantes, dans l'ordre de Ch.plan (plan_rows -> plan_both) :
--- 1 = la spec ; 2 = l'autre ordre des côtés de 1 (coal_first = -exit de 1, si plan_both le demande) ; 3 = les rangées gloutonnes
--- (no_row_opt, si plan_rows le demande sur le choix de 1 et 2) ; 4 = l'autre ordre des côtés de 3 (si plan_both le demande sur 3).
--- `res` : variantes déjà calculées, res[i] = { p = plan, why = raison }. Rend (i, spec de la variante i) de la prochaine à calculer,
--- ou nil quand le plan est complet (Ch.plan_pick). Règle pure : aucun calcul de plan, `res` n'est pas modifié.
function Ch.plan_next(spec, res)
  if not res[1] then return 1, spec end
  if not res[2] and both_wants(spec, res[1].p) then return 2, spec_with(spec, "coal_first", -res[1].p.exit) end
  local P = both_pick(res[1], res[2], false)
  if not rows_wants(spec, P) then return nil end
  local s3 = spec_with(spec, "no_row_opt", true)
  if not res[3] then return 3, s3 end
  if not res[4] and both_wants(s3, res[3].p) then return 4, spec_with(s3, "coal_first", -res[3].p.exit) end
  return nil
end

--- s49 tranches : le plan final des variantes calculées (`res`, complet au sens de Ch.plan_next) : les règles de plan_both puis de plan_rows
--- (Ch.better_order, puis MOINS de coffres de tête, Ch.head_chests), à l'identique. Rend plan, raison. Pose order_swapped comme plan_both.
function Ch.plan_pick(spec, res)
  local p, why = both_pick(res[1], res[2], true)
  if not res[3] then return p, why end
  local q, qwhy = both_pick(res[3], res[4], true)
  if q and Ch.head_chests(q) < Ch.head_chests(p) then return q, qwhy end
  return p, why
end

Ch.ORDERS = 0 -- s49 tranches : nombre de plan_order calculés (compteur des tests ; jamais lu pour une décision)

--- s49 tranches : séquence pas à pas. Ch.plan_begin(spec) -> état { spec, res, memo, n, k, cur, inner } ; Ch.plan_step(st) rend vrai
--- quand le plan est complet ; Ch.plan_result(st) -> plan, raison.
--- s52 bandes : un pas = UNE étape de plan_once (Ch.once_step : la recherche d'une phase, une bande, un réseau du charbon, ...) de la
--- variante en cours (st.cur : { i, o = état de plan_order }), plus une variante entière ; mémoire de phase st.memo sur toute la séquence.
--- st.n : variantes finies ; st.k : pas faits ; st.inner : vrai si le pas suivant continue la MÊME variante (lu par le câblage pour
--- l'espacement court, Mig.INNER_GAP ; faux : le pas suivant commence une variante, Mig.STEP_GAP).
function Ch.plan_begin(spec) return { spec = spec, res = {}, memo = {}, n = 0, k = 0, inner = false } end
function Ch.plan_step(st)
  if not st.cur then
    local i, vs = Ch.plan_next(st.spec, st.res)
    if not i then st.inner = false return true end
    st.cur = { i = i, o = order_begin(vs) }
  end
  PHASE_MEMO = st.memo
  local fin = order_step(st.cur.o)
  PHASE_MEMO = nil
  st.k = st.k + 1
  if fin then
    local o = st.cur.o
    Ch.ORDERS = Ch.ORDERS + 1
    st.res[st.cur.i], st.n = { p = o.p, why = o.why }, st.n + 1
    st.cur = nil
  end
  st.inner = st.cur ~= nil
  return st.cur == nil and Ch.plan_next(st.spec, st.res) == nil
end
function Ch.plan_result(st) return Ch.plan_pick(st.spec, st.res) end

--- Plan du champ en un appel : la séquence pas à pas enchaînée (même plan ; jusqu'à 4 plan_order dans l'appel).
function Ch.plan(spec)
  local st = Ch.plan_begin(spec)
  while not Ch.plan_step(st) do end
  return Ch.plan_result(st)
end

--- s42 gisements (chantier 4.3 du DC, partie 0.7.96 : « essayer les deux orientations et garder le plan qui pose le plus de foreuses »).
--- Les rangées suivent l'axe LONG du gisement et la fonderie se pose au bout des rangées : quand ce bout n'a pas de sol neutre (un autre
--- gisement le borde), les foreuses des bandes ne sont pas posées (stats.orphans ; joueur, 6,3 min : cuivre, 100 foreuses non posées sur 215).
--- L'autre orientation sort par un autre bord. Borné : UN essai de plus, sur un cadre neuf seulement, et seulement si des foreuses manquent.
function Ch.axis_other(axis) return axis == "x" and "y" or "x" end

--- Vrai si le plan `p` d'un cadre neuf laisse des foreuses non posées faute de fonderie : l'autre orientation vaut un essai.
function Ch.axis_retry(p)
  return p ~= nil and p.stats ~= nil and (p.stats.orphans or 0) > 0
end

--- Vrai si le plan `b` (autre orientation) remplace `a` (axe long) : STRICTEMENT plus de foreuses du champ posées ; avec des coffres de
--- tête en plus (colonnes à remplir à la main), seulement si l'axe long garde moins que la part que le refus exige (Ch.refuse_keeps, la
--- même règle que le refus d'une colonne et que Ch.better_order) ; à égalité, l'axe long reste (plans d'avant inchangés).
function Ch.better_axis(a, b)
  if not b then return false end
  if not a then return true end
  local da, db = Ch.field_drills(a), Ch.field_drills(b)
  if db <= da then return false end
  if Ch.head_chests(b) <= Ch.head_chests(a) then return true end
  return not (Ch.refuse_keeps(db, da))
end

--- s40 champ p1 : fin de l'ordre des bandes d'un cadre. `nbad` : bandes écartées (plan de bande refusé à l'instant de sa demande) ; `produced` :
--- bandes qui ont produit ; `last` : valeur de `produced` au dernier tour de relecture (nil : aucun tour). Rend vrai si les bandes écartées
--- sont à relire : il y en a, et au moins une bande a produit depuis le dernier tour (un tour sans bande neuve termine : pas de boucle).
function Ch.bad_round(nbad, produced, last)
  return (nbad or 0) > 0 and (produced or 0) > (last or 0)
end

return Ch
