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
    max_side foreuses par côté et par groupe au plus (nil : la voie la plus rapide)
    frame    cadre figé d'un plan précédent (plan.frame) : mêmes axe, phase, sortie, bords, décalages ; only = { [pr] = true } : ces
             bandes seulement (avec frame)
  plan = { axis, exit, frame, ents = { { kind, x, y, size, dir, band, group, pr, role, belt, module } }, bands, stats }
    kind : "foreuse" | "tapis" | "poteau" | "four" | "bras" | "coffre" ; dir 0 N, 2 E, 4 S, 6 O (foreuse : vers sa sortie ; tapis :
    sens de marche ; bras : côté où il PREND, convention de shared/team/modules.lua) ; role d'un coffre : "sortie" | "combustible".
  Déterminisme : listes triées, entiers, aucun `pairs` dans une décision, aucune trigonométrie.
]]

-- (coût, 7/11) bibliothèque en locales du module : les étapes du plan en tranches lisent leurs noms libres dans l'état (_ENV = P)
local ipairs, pairs, next, tostring, tonumber, type = ipairs, pairs, next, tostring, tonumber, type
local math, string, table = math, string, table
local Fd = require("shared.team.champ_fonderie")
local Co = require("shared.team.champ_colonne") -- lot FONDERIE : colonne nourrie par tapis, charbon compris
local Mel = require("shared.team.melange") -- lot MELANGE : zone d'une foreuse qui touche une autre ressource minable
local Cc = require("shared.team.champ_couverture") -- lot CHAMP-COUVERTURE (R2 + R3) : sortie au bout de la bande, fonderie découplée, tapis tracé

local Ch = {}

Ch.CFG = {
  min_ore = 3,        -- tuiles de minerai au moins dans la zone d'une foreuse
  corridor = 32,      -- tuiles le long des rangées entre deux couloirs de passage (0 : aucun)
  gap = 2,            -- tuiles libres entre le bout du champ et la fonderie (passage)
  shift = 24,         -- tuiles dont la fonderie peut reculer pour trouver sa place (12 : bandes vides en jeu, la place prise par un autre chantier)
  both_ends = true,   -- une bande trop longue pour un tapis sort aussi par l'autre bout
  -- (lot FONDERIE, 3/11, le DC en 0.6.41 : « rien n'est automatique, rien n'est scalable ») une colonne d'un cadre neuf SANS voie de charbon
  -- (tracé sans chemin, pas de place pour le tronc) est REFUSÉE au lieu de retomber sur un coffre de tête à remplir ; le plan est refait
  -- sans elle (ses foreuses peuvent aller à l'autre bout de la bande), au plus refuse_passes fois
  refuse_coffre = true,
  refuse_passes = 4,
  -- (lot FONDERIE, 3/11, décision du lead) le refus ne vaut que s'il garde au moins cette part des foreuses du champ (ligne de charbon
  -- exclue) ; sinon le cadre garde ses colonnes au coffre de tête (champ-longue 20261020 : le refus réduisait un champ d'azure de 41
  -- foreuses à 4, de 97 % à 3 % du gisement)
  refuse_min = 0.5,
  -- (revue-fonderie, 3/11) un cadre neuf qui garde un coffre de tête ou refuse une colonne est aussi essayé dans l'autre ordre des côtés
  both_orders = true,
  -- lot CHAMP-COUVERTURE (R2 + R3, 5/11) : un groupe dont le tapis est coupé avant le bout du champ, ou qui n'a pas de place pour sa
  -- fonderie dans l'alignement, sort au bout de SA bande ; sa fonderie se pose où il y a la place et un tapis tracé la rejoint
  -- (shared/team/champ_couverture.lua). Seulement pour un cadre NEUF ; un cadre figé rejoue ses tracés (frame.routed) ou, sans eux
  -- (cadre d'avant le lot), le chemin d'avant. Faux : le chemin d'avant partout (bancs : tests/champ_couverture_test.lua §2).
  decouple = true,
  -- lot CHAMP-COUVERTURE (R1, 7/11) : un cadre NEUF est planifié dans les deux axes, le plus de minerai couvert l'emporte (l'axe long à
  -- égalité). Faux : l'axe long seul, comme avant.
  both_axes = true,
  -- (R1) l'autre axe est essayé avec au plus axis_work fois le travail de l'axe long (unités, J.used : même décision d'un bloc ou en
  -- tranches) ; au-delà il est abandonné, l'axe long gardé. MESURÉ : l'autre axe des grands lacs et de la partie du joueur 271828182 coûte
  -- 6 et 9 fois l'axe long (tracés qui échouent, colonnes refusées) pour un plan moins bon (44,1 et 57,8 % contre 70,3 et 81,6 %)
  axis_work = 1.5,
  eps = 1e-9,
}

function Ch.key(x, y) return (x + 50000) * 100000 + (y + 50000) end
Ch.BRIDGE_TRIES = 24 -- (lot FONDERIE) paires de poteaux essayées pour relier deux réseaux (bridge)
Ch.furnaces_for = Fd.furnaces_for

--- Foreuses par côté qu'une voie porte.
function Ch.lane_drills(lane, rate)
  if not (lane and rate and rate > 0) then return 0 end
  return math.floor(lane / rate + Ch.CFG.eps)
end

local DIRS = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }

--- Lectures du champ dans le repère de l'axe : minerai, place libre, tuiles prises par le plan (clés en x, y).
--- (coût, 7/11, voie des TRANCHES) le contexte en DONNÉES (`cx` : prises, minerai, liste, boîte, mémoires) relevé par morceaux
--- (ctx_fill, CTX_CHUNK tuiles par pas au plus) ; ctx_of(cx, spec) refait ses fonctions à chaque pas. context(spec, axis) : tout d'un coup.
local CTX_CHUNK = 512
local function ctx_new(axis)
  return { axis = axis, taken = {}, ore = {}, list = {}, ore_uv = {}, ore_cols = {}, i = 1,
    box = { u0 = math.huge, v0 = math.huge, u1 = -math.huge, v1 = -math.huge } }
end
local function uv_of(axis)
  if axis == "x" then return function(x, y) return x, y end end
  return function(x, y) return y, x end
end
--- Relevé du minerai, morceau par morceau ; vrai quand il est fini. J (facultatif) : budget du travail (une unité par Ch.UNITS.ore tuiles).
local function ctx_fill(cx, spec, J)
  local o = spec.ore
  local uv = uv_of(cx.axis)
  local ore, list, ore_uv, box = cx.ore, cx.list, cx.ore_uv, cx.box
  while cx.i <= #o - 1 do
    if J and J.left <= 0 then return false end
    local stop = math.min(#o - 1, cx.i + 2 * (CTX_CHUNK - 1))
    -- Lot PERF3 : le minerai aussi en clés du repère de l'axe (u, v) : is_ore sans changement de repère (même réponse : xy et uv sont
    -- deux bijections inverses l'une de l'autre ; c.ore n'est plus modifié après ce relevé)
    for i = cx.i, stop, 2 do
      local k = Ch.key(o[i], o[i + 1])
      if not ore[k] then
        ore[k] = true
        local u, v = uv(o[i], o[i + 1])
        list[#list + 1] = { u, v }
        ore_uv[Ch.key(u, v)] = true
        -- boîte du minerai (même valeur que relevée sur la liste après coup : min et max ne dépendent pas de l'ordre)
        box.u0, box.u1 = math.min(box.u0, u), math.max(box.u1, u)
        box.v0, box.v1 = math.min(box.v0, v), math.max(box.v1, v)
      end
    end
    if J then Co.spend(J, (stop - cx.i + 2) / 2 * Ch.UNITS.ore) end
    cx.i = stop + 2
  end
  return true
end
local function ctx_of(cx, spec)
  local c = { taken = cx.taken, blocked = spec.blocked or {}, mine = spec.mine or {}, ore = cx.ore, list = cx.list, foreign = spec.foreign or {},
    ore_cols = cx.ore_cols }
  if cx.axis == "x" then
    c.xy = function(u, v) return u, v end
    c.uv = function(x, y) return x, y end
  else
    c.xy = function(u, v) return v, u end
    c.uv = function(x, y) return y, x end
  end
  local ore_uv = cx.ore_uv
  c.is_ore = function(u, v) return ore_uv[Ch.key(u, v)] == true end
  c.ore_uv = ore_uv
  -- lot MELANGE : une tuile d'une autre ressource minable (jamais une tuile du minerai visé : celui-ci gagne s'il y est aussi)
  c.has_foreign = next(c.foreign) ~= nil
  c.is_foreign = function(u, v) local x, y = c.xy(u, v); local k = Ch.key(x, y); return c.foreign[k] == true and not c.ore[k] end
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

local function corridor_col(origin, u)
  local n = Ch.CFG.corridor
  if not n or n <= 0 then return false end
  local r = (u - origin) % n
  return r == n - 2 or r == n - 1
end

--- Foreuses d'une rangée (corps sur les rangées row..row+s-1), parcours glouton au décalage o. Rend { u0 } et le minerai miné.
--- (lot CHAMP-COUVERTURE, R1, 7/11) prow : rangée des poteaux de ces foreuses, quand elle n'est pas libre de bout en bout ; une foreuse
--- dont aucune tuile de cette rangée n'est libre à portée d'un poteau (eau, couloir de passage) n'aurait jamais de courant : refusée.
--- MESURÉ avant : « r30 + couloir horizontal », 14 foreuses sans courant (le couloir sur une rangée de poteaux) ; l'autre axe de
--- « r12 + eau aux bouts, ouverture de 3 », 1. nil : aucune condition (rangée propre : même plan qu'avant).
local function row_drills(c, spec, row, umin, umax, origin, o, fm, prow)
  local s, r = spec.drill.size, spec.drill.reach
  local R = spec.pole.reach
  local out, mined = {}, 0
  local counted = -math.huge -- dernière colonne dont le minerai est compté dans `mined`
  -- Lot PERF3 : place libre lue UNE fois par tuile (la fenêtre glisse d'une tuile, et les décalages et les rangées d'une même passe de
  -- l'étape « choix de la phase » relisent les mêmes tuiles) : `fm`, mémoire de cette étape, où rien n'est pris (c.taken inchangé) :
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
    if ok and prow then
      local pole = false
      for u = a - R, a + s - 1 + R do if c_free(u, prow) then pole = true break end end
      if not pole then ok = false end
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

--- Groupe d'une bande du côté `side` : foreuses prises depuis le bord, au plus `cap` par côté, tant que le tapis est libre jusqu'au
--- bord et (second groupe) en deçà de la coupe `limit` du premier. Rend { n, s, cut } (cut : centre de la foreuse la plus loin).
--- (lot CHAMP-COUVERTURE, R2) `hop` : un obstacle d'au plus `hop` tuiles sur la rangée du tapis est sauté par une paire de souterrains
--- (g.hops = { { inp, out } }) ; une foreuse qui déposerait sur un souterrain ou sur l'obstacle n'est pas prise. nil : comme avant.
local function take_group(c, spec, band, side, cap, edge, used, limit, total, hop)
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
  local hops, skip = {}, {}
  while (side > 0 and u >= far) or (side < 0 and u <= far) do
    if not c.free(u, band.b) then
      -- (lot CHAMP-COUVERTURE) obstacle court : entrée du souterrain avant lui (dans le sens du tapis), sortie après lui
      local w = 0
      if hop then while w <= hop and not c.free(u - side * w, band.b) do w = w + 1 end end
      local inp, out = u - side * w, u + side
      if hop and w >= 1 and w <= hop and c.free(inp, band.b) and c.free(out, band.b) and ((side > 0 and inp >= far) or (side < 0 and inp <= far)) then
        hops[#hops + 1] = { inp = inp, out = out }
        skip[inp], skip[out] = true, true
        for k = 0, w - 1 do skip[u - side * k] = true end
        u = inp - side
      else
        if not stop or not beyond(u, stop) then stop = u end
        break
      end
    else
      u = u - side
    end
  end
  local g, cnt = { n = {}, s = {} }, { n = 0, s = 0 }
  if hop then
    -- (lot CHAMP-COUVERTURE) foreuses qui déposeraient sur un souterrain ou sur l'obstacle : écartées (le reste de la bande passe)
    local keep = {}
    for _, it in ipairs(all) do if not skip[it.cu] then keep[#keep + 1] = it end end
    all = keep
  end
  for i, it in ipairs(all) do
    -- (lot FONDERIE) `total` : foreuses du groupe au plus, deux côtés compris (la colonne charge tout le minerai sur une voie)
    if (stop and beyond(it.cu, stop)) or cnt[it.side] >= cap or (total and cnt.n + cnt.s >= total) then break end
    cnt[it.side] = cnt[it.side] + 1
    g[it.side][#g[it.side] + 1] = it.a
    g.cut = it.cu
    -- l'autre côté au même centre ne passe plus : la coupe recule (deux tapis ne partagent jamais une tuile)
    local nx = all[i + 1]
    if nx and nx.cu == it.cu and (cnt[nx.side] >= cap or (total and cnt.n + cnt.s >= total)) then
      g[it.side][#g[it.side]] = nil
      g.cut = nil
      for j = i - 1, 1, -1 do if all[j].cu ~= it.cu then g.cut = all[j].cu break end end
      break
    end
  end
  if #g.n + #g.s == 0 or not g.cut then return nil end
  if #hops > 0 then
    g.hops = {}
    for _, h in ipairs(hops) do
      if (side > 0 and h.inp >= g.cut) or (side < 0 and h.inp <= g.cut) then g.hops[#g.hops + 1] = h end
    end
  end
  return g
end

--- Poteaux de la rangée `row` sur le treillis (u ≡ origin mod P) : un par foreuse non couverte, des relais où les fils manquent,
--- puis jusqu'aux colonnes de poteaux des fonderies `reach_to`. Rend la liste triée des u.
--- Pas du treillis des poteaux le long d'une rangée : au plus la portée des fils, au plus côté + 2 × portée (toute foreuse en touche un).
function Ch.lattice_step(spec)
  return math.max(1, math.min(math.floor(spec.pole.wire + Ch.CFG.eps), spec.drill.size + 2 * spec.pole.reach))
end

local function row_poles(c, spec, row, drills, origin, reach_to, pre)
  local R, s = spec.pole.reach, spec.drill.size
  local P = Ch.lattice_step(spec)
  local function lattice_at_or_after(u) return u + ((origin - u) % P) end
  local set, list = {}, {}
  -- (lot CHAMP-COUVERTURE) poteaux de liaison d'un tracé déjà sur la rangée : comptés comme posés (ni repris ni doublés)
  for _, u in ipairs(pre or {}) do set[u] = true end
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
        while math.abs(goal - u) > R and guard < 400 do
          guard = guard + 1
          local want = u + dir * P
          if (dir > 0 and want > goal) or (dir < 0 and want < goal) then want = goal end
          local lo, hi = math.min(u + dir, want), math.max(u + dir, want)
          local got = try(lo, hi, want)
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
--- Deux règles : bridge_0641 (motif à coffres, 0.6.41 : la paire la plus proche, poteaux pris au fil de la chaîne, un échec arrête
--- tout) et, lot FONDERIE, la colonne à tapis (les Ch.BRIDGE_TRIES paires les plus proches, essayées dans l'ordre ; avant, seule la
--- plus proche l'était, et un échec arrêtait tout : deux rangées de poteaux d'une ligne de charbon à 8 tuiles ont leur milieu sur le
--- tapis et les foreuses, aucun relais possible là, mais au bout de la ligne oui).
--- (coût, 7/11, voie des TRANCHES) machine REPRENABLE : br_new(multi), br_run(st, c, spec, poles, J) avance tant que J.left > 0 et rend
--- vrai à la fin (st.added). Avant, chaque passe refaisait les réseaux de zéro (tous les poteaux, à chaque relais posé : 1,4 million
--- d'instructions par passe sur le géant 200 x 200). Ici le poteau k est uni aux poteaux d'avant à portée de fil (grille de cases de la
--- portée), puis rangé, une fois pour toutes ; les poteaux d'une chaîne posée s'ajoutent à la suite. Les réseaux sont les composantes du
--- graphe « à portée de fil », qui ne dépendent pas de l'ordre des unions : mêmes réseaux, même réseau du premier poteau, mêmes listes
--- ins / outs (indices croissants), mêmes paires dans le même ordre (égalités comprises), mêmes chaînes (contrôle : C1 et C4 de
--- tests/champ_tranches_test.lua).
local BR_CHUNK = 256 -- poteaux classés (réseau principal ou non) par morceau
local function br_root(parent, i) while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end return i end
local function br_new(multi) return { multi = multi and true or false, added = {}, parent = {}, grid = {}, k = 1, pass = 1, stage = 1 } end
local function br_next(st)
  st.ins, st.outs, st.cand, st.best, st.ba, st.bb, st.si, st.ci, st.cj = nil, nil, nil, nil, nil, nil, nil, nil, nil
  st.pass = st.pass + 1
  -- (R1) au plafond des passes, des réseaux peuvent rester séparés : compté comme tel
  if st.pass > 60 then st.stage, st.split = 0, true else st.stage = 1 end
end
local function br_run(st, c, spec, poles, J)
  local wire = spec.pole.wire
  local w2 = wire * wire + Ch.CFG.eps
  local cell = math.max(1, math.ceil(wire))
  local U = Ch.UNITS
  local parent, grid = st.parent, st.grid
  while st.stage ~= 0 do
    if J and J.left <= 0 then return false end
    if st.stage == 1 then
      -- réseaux : le poteau k uni aux poteaux d'avant à portée, puis rangé dans la grille
      local k = st.k
      if k > #poles then
        st.stage, st.si, st.ins, st.outs = 2, 1, {}, {}
      else
        local p = poles[k]
        local p1, p2 = p[1], p[2]
        parent[k] = k
        local gx, gy = math.floor(p1 / cell), math.floor(p2 / cell)
        for dx = -1, 1 do
          for dy = -1, 1 do
            for _, j in ipairs(grid[Ch.key(gx + dx, gy + dy)] or {}) do
              local q = poles[j]
              if (p1 - q[1]) ^ 2 + (p2 - q[2]) ^ 2 <= w2 then
                local a, b = br_root(parent, k), br_root(parent, j)
                if a ~= b then parent[a] = b end
              end
            end
          end
        end
        local gk = Ch.key(gx, gy)
        local cl = grid[gk]
        if not cl then cl = {}; grid[gk] = cl end
        cl[#cl + 1] = k
        st.k = k + 1
        if J then Co.spend(J, U.br_pole) end
      end
    elseif st.stage == 2 then
      -- poteaux du réseau du premier poteau (ins) et des autres (outs), indices croissants
      local main = br_root(parent, 1)
      local stop = math.min(#poles, st.si + BR_CHUNK - 1)
      local ins, outs = st.ins, st.outs
      for i = st.si, stop do if br_root(parent, i) == main then ins[#ins + 1] = i else outs[#outs + 1] = i end end
      if J then Co.spend(J, (stop - st.si + 1) * U.br_split) end
      st.si = stop + 1
      if st.si > #poles then st.stage, st.ci, st.cand = 3, 1, {} end
    elseif st.stage == 3 then
      -- paires (poteau du réseau principal, poteau d'un autre) : les plus proches, un poteau du réseau principal par morceau
      local i = st.ins[st.ci]
      if not i then
        st.stage, st.cj = 4, 1
      else
        local p = poles[i]
        local p1, p2 = p[1], p[2]
        local outs = st.outs
        if st.multi then
          local cand, tries = st.cand, Ch.BRIDGE_TRIES
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
        else
          for _, j in ipairs(outs) do
            local q = poles[j]
            local d2 = (p1 - q[1]) ^ 2 + (p2 - q[2]) ^ 2
            if not st.best or d2 < st.best then st.best, st.ba, st.bb = d2, i, j end
          end
        end
        st.ci = st.ci + 1
        if J then Co.spend(J, (1 + #outs) * U.br_pair) end
      end
    elseif st.multi then
      -- chaîne de relais d'une paire, essayée dans l'ordre ; posée seulement entière (une paire par morceau)
      local cd = st.cand[st.cj]
      if not cd then
        st.stage = 0
      else
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
        if J then Co.spend(J, (1 + math.max(n, 0)) * U.br_try) end
        if ok and (prev[1] - b[1]) ^ 2 + (prev[2] - b[2]) ^ 2 <= w2 then
          for _, put in ipairs(chain) do
            c.take(put[1], put[2])
            poles[#poles + 1] = put
            st.added[#st.added + 1] = put
          end
          br_next(st)
        else
          st.cj = st.cj + 1
        end
      end
    else
      -- bridge_0641 : la paire la plus proche, poteaux pris au fil de la chaîne ; un échec arrête tout
      if not st.best then
        st.stage = 0
      else
        local a, b = poles[st.ba], poles[st.bb]
        local dist = math.sqrt(st.best)
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
          st.added[#st.added + 1] = put
          prev = put
        end
        if J then Co.spend(J, (1 + math.max(n, 0)) * U.br_try) end
        if ok then br_next(st) else st.stage = 0 end
      end
    end
  end
  -- (R1) réseaux encore séparés à la fin : des poteaux hors du réseau du premier (aucune chaîne posée entre eux)
  if st.outs and #st.outs > 0 then st.split = true end
  st.parent, st.grid, st.ins, st.outs, st.cand = nil, nil, nil, nil, nil
  return true
end
local function bridge(c, spec, poles)
  local st = br_new(true)
  br_run(st, c, spec, poles, nil)
  return st.added
end
Ch.bridge_new, Ch.bridge_run = br_new, br_run -- (tests) la machine des relais, contrôlée contre les passes d'avant

---------------------------------------------------------------------------------------------------
-- Plan en TRANCHES (coût, 7/11 ; décision du lead : « voie des TRANCHES »). Ch.plan_job(spec) rend un TRAVAIL fait de DONNÉES seules ;
-- Ch.plan_step(job, budget) le fait avancer d'au plus `budget` unités de travail environ (jamais du temps : déterminisme) et rend vrai
-- quand le plan est prêt (job.p, job.why). Ch.plan(spec) est la boucle jusqu'au bout : une seule règle, mêmes décisions.
-- Le travail est une PILE de cadres : « plan » (deux ordres des côtés du charbon), « order » (refus des colonnes au coffre de tête),
-- « pushed » (colonne déplacée reposée au-delà), « once » (UN plan, par étapes). Dans une étape de « once », `local _ENV = P` : les
-- noms libres sont les champs du cadre P (l'état gardé) ; les fonctions (place libre, émission, rectangles des bandes...) sont refaites à
-- chaque pas depuis ces données (kit) et jamais gardées : le travail se sauvegarde (tests/champ_tranches_test.lua, C2).
---------------------------------------------------------------------------------------------------
-- unités de travail (calibrées hors jeu : tests/champ_tranches_test.lua, C3) ; un pas s'arrête à la première borne d'unité de travail
-- atteinte quand le budget est épuisé
Ch.UNITS = { ore = 1 / 8, row = 1 / 6, band = 30, take = 2, ent = 1 / 16, pole_row = 6, pending = 9, cols = 4, side = 10,
  axis = 1 / 40, br_pole = 0.26, br_split = 0.035, br_pair = 0.026, br_try = 2.6, emit = 0.3, cov = 0.6 }
-- Budget d'un pas en jeu (unités ; une unité vaut environ 1 000 instructions Lua, calibrée hors jeu machine par machine). Mesuré hors jeu
-- (tests/champ_tranches_test.lua, C3) : pire pas 211 000 instructions sur le corpus (environ 2,6 ms à 12 ns par instruction, PC au repos),
-- morceau indivisible le plus gros 92 000 ; surcoût du découpage 0,3 à 0,9 %.
Ch.STEP_BUDGET = 50

local spend = function(J, n) Co.spend(J, n) end
local ENT_CHUNK = 512 -- entités lues par morceau (étapes 11 et 14)
local function out_of(J) return J.left <= 0 end

--- Fonctions du cadre « once » refaites à chaque pas : contexte, émission, rectangles des bandes, souterrains posés, charbon, pose d'un
--- groupe et émission d'une bande. Rien de ce qu'elles rendent n'est gardé dans P (seulement leurs effets sur les données).
local function kit(P)
  local _ENV = P
  local K = {}
  local c = ctx_of(cx, spec)
  K.c = c
  function K.emit(kind, u, v, size, du, dv, bi, gi, pr, role, belt, module)
    local x, y = c.xy(u, v)
    local x2, y2 = c.xy(u + size - 1, v + size - 1)
    ents[#ents + 1] = { kind = kind, x = math.min(x, x2) + size / 2, y = math.min(y, y2) + size / 2, size = size,
      dir = (du ~= 0 or dv ~= 0) and c.dir(du, dv) or 0, band = bi, group = gi, pr = pr, role = role, belt = belt, module = module }
  end
  -- (lot FONDERIE) une entité de la colonne ou du réseau de charbon : rectangle w × h (répartiteur), sens de souterrain
  function K.emit_e(e, bi, gi, pr, belt)
    local w, h = e.w or e.size, e.h or e.size
    local xa, ya = c.xy(e.u, e.v)
    local xb, yb = c.xy(e.u + w - 1, e.v + h - 1)
    local x0, x1, y0, y1 = math.min(xa, xb), math.max(xa, xb), math.min(ya, yb), math.max(ya, yb)
    local o = { kind = e.kind, x = (x0 + x1 + 1) / 2, y = (y0 + y1 + 1) / 2, size = e.size,
      dir = (e.du ~= 0 or e.dv ~= 0) and c.dir(e.du, e.dv) or 0, band = bi, group = gi, pr = pr, role = e.role, belt = belt, ug = e.ug }
    if e.w then o.w, o.h = x1 - x0 + 1, y1 - y0 + 1 end
    ents[#ents + 1] = o
  end
  -- rectangles des bandes : relevés une fois (rd, données, à la fin de l'étape 5), la fonction refaite à chaque pas
  if bands and r23 then K.forbid = Cc.rects_fn(rd) end
  if ugs_set then K.span = function(u, v) return not ugs_set[Co.tk(u, v)] end end
  if coal_uv then K.not_coal = function(u, v) return not coal_uv[Co.tk(u, v)] end end
  function K.commit(bd, st, side, g, flow, list, len, s_edge, count, info, routed)
    for _, a in ipairs(g.n) do st.used[a .. "n"] = true end
    for _, a in ipairs(g.s) do st.used[a .. "s"] = true end
    for _, e in ipairs(list) do for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do c.take(u, v) end end end
    g.side, g.flow, g.s_edge, g.len, g.count, g.list, g.info = side, flow, s_edge, len, count, list, info
    g.row = routed and routed.row or bd.b
    used_rows[side][g.row] = true
    if routed then
      -- lot CHAMP-COUVERTURE : emprise de la fonderie déplacée (quai : son tapis compris) et tapis tracé, pris
      for _, t in ipairs(routed.tiles) do c.take(t[1], t[2]) end
      for _, t in ipairs(routed.route) do c.take(t.u, t.v) end
      for _, t in ipairs(routed.poles or {}) do c.take(t[1], t[2]) end
      g.route, g.link = routed.route, routed.poles or {}
      n_routed = n_routed + 1
      route_max = math.max(route_max, #routed.route)
      if routed.row ~= bd.b then n_moved = n_moved + 1 end
      if routed_frame then
        local rf = { row = routed.row, s_edge = routed.s_edge, count = count, mode = (colonne and info) and info.mode or nil, tiles = {}, route = {},
          trim = g.trim, poles = {} }
        for _, t in ipairs(routed.tiles) do rf.tiles[#rf.tiles + 1] = { t[1], t[2] } end
        for _, t in ipairs(routed.poles or {}) do rf.poles[#rf.poles + 1] = { t[1], t[2] } end
        for _, t in ipairs(routed.route) do
          rf.route[#rf.route + 1] = { t.u, t.v, t.d, t.kind == "souterrain" and 1 or 0, (t.ug == "input" and 1) or (t.ug == "output" and 2) or 0 }
        end
        routed_frame[tostring(bd.pr)] = routed_frame[tostring(bd.pr)] or {}
        routed_frame[tostring(bd.pr)][tostring(side)] = rf
      end
    end
    g.belt = #spec.belts
    local need_lane = fuelled and (#g.n + #g.s) or math.max(#g.n, #g.s)
    for i, bt in ipairs(spec.belts) do
      if Ch.lane_drills(bt.lane, d.rate) >= need_lane then g.belt = i break end
    end
    st.groups[#st.groups + 1] = g
    st.limit = g.cut
  end
  -- émission des groupes from..#st.groups d'une bande (foreuses, tapis de la bande, tracé, fonderie ou colonne en attente du charbon)
  function K.emit_groups(bi, bd, st, from)
    local emit, emit_e = K.emit, K.emit_e
    local bo = st.bo
    for gi = from, #st.groups do
      local g = st.groups[gi]
      for _, a in ipairs(g.n) do emit("foreuse", a, bd.pr + 1, d.size, 0, 1, bi, gi, bd.pr) end
      for _, a in ipairs(g.s) do emit("foreuse", a, bd.b + 1, d.size, 0, -1, bi, gi, bd.pr) end
      -- tapis de la bande : jusqu'au bout de la fonderie (motif à coffres), jusqu'à la tête de la colonne (lot FONDERIE)
      local s_end = colonne and (g.s_edge - g.side) or (g.s_edge + g.side * (g.len - 1))
      -- lot CHAMP-COUVERTURE : groupe tracé : le tapis de la bande s'arrête à sa sortie, le tracé (rôle « trace ») rejoint la fonderie
      if g.route then s_end = g.exit - g.side end
      local nb = 0
      -- (lot CHAMP-COUVERTURE) souterrains de la bande : entrée, sortie, et l'obstacle entre eux (rien n'y est posé)
      local hin, hout, hskip = {}, {}, {}
      for _, h in ipairs(g.hops or {}) do
        hin[h.inp], hout[h.out] = true, true
        for u = h.inp + g.side, h.out - g.side, g.side do hskip[u] = true end
      end
      for u = g.cut, s_end, g.side do
        if hin[u] or hout[u] then
          c.take(u, bd.b)
          emit_e({ kind = "souterrain", u = u, v = bd.b, size = 1, du = g.side, dv = 0, role = colonne and "bande" or nil,
            ug = hin[u] and "input" or "output" }, bi, gi, bd.pr, g.belt)
          nb = nb + 1
        elseif not hskip[u] then
          c.take(u, bd.b)
          emit("tapis", u, bd.b, 1, g.side, 0, bi, gi, bd.pr, colonne and "bande" or nil, g.belt)
          nb = nb + 1
        end
      end
      if g.route then
        for _, t in ipairs(g.route) do
          local dv4 = Co.D4[t.d]
          emit_e({ kind = t.kind, u = t.u, v = t.v, size = 1, du = dv4[1], dv = dv4[2], role = "trace", ug = t.ug }, bi, gi, bd.pr, g.belt)
          nb = nb + 1
        end
        -- poteaux de liaison du tracé (Cc.link_poles) : la fonderie déplacée est dans le réseau de sa bande, bâtie seule comprise
        for _, t in ipairs(g.link or {}) do emit("poteau", t[1], t[2], 1, 0, 0, bi, gi, bd.pr, "lien") end
        if not colonne then
          -- quai déplacé : son tapis, sur sa rangée
          for k = 0, g.len - 1 do emit("tapis", g.s_edge + g.side * k, g.row, 1, g.side, 0, bi, gi, bd.pr, "colonne", g.belt) end
        end
      end
      if colonne then
        pending[#pending + 1] = { bi = bi, gi = gi, pr = bd.pr, b = g.row, g = g }
      else
        for _, e in ipairs(g.list) do emit(e.kind, e.u, e.v, e.size, e.du, e.dv, bi, gi, bd.pr, e.role, nil, e.module) end
      end
      local capa = Fd.capacity(spec, g.count)
      flow_all, cap_all = flow_all + g.flow, cap_all + capa
      bo.groups[#bo.groups + 1] = { side = g.side, drills = #g.n + #g.s, per_side = math.max(#g.n, #g.s), flow = g.flow, belt = g.belt,
        count = g.count, capacity = capa, belt_tiles = nb, s_edge = g.s_edge, len = g.len, cut = g.cut,
        -- (lot CHAMP-COUVERTURE) fonderie déplacée : hors des rangées de poteaux de la bande, reliée par les relais (bridge)
        pole_u = (not g.route) and (g.s_edge + g.side * (colonne and g.info.head_pole or Fd.pole_col(spec))) or nil,
        pole_u2 = ((not g.route) and colonne) and g.s_edge or nil, -- (lot FONDERIE) poteau de liaison de tête, rejoint par la rangée pr + pas
        row = g.row, routed = g.route ~= nil, route_len = g.route and #g.route or nil }
    end
  end
  return K
end

local ONCE = {}

-- 1. contrôles des données, axe, contexte à relever
ONCE[#ONCE + 1] = function(P, J)
  local _ENV = P
  if not (spec and spec.ore and #spec.ore >= 2 and spec.drill and spec.pole and spec.belts and #spec.belts > 0) then p, why = nil, "donnees" return "end" end
  d, F = spec.drill, spec.frame
  -- lot FONDERIE : colonne à tapis (shared/team/champ_colonne.lua) pour un cadre neuf qui la demande ; un cadre figé garde SON motif
  -- (un cadre d'une sauvegarde 0.6.38 n'a pas `design` : ses bandes gardent la fonderie à coffres, rien n'est migré)
  colonne = spec.furnace ~= nil and ((F and F.design) or (not F and spec.design)) == "colonne"
  if spec.furnace and spec.furnace.size > d.size - 1 then p, why = nil, "four trop grand pour la bande" return "end" end
  if colonne then
    if spec.furnace.size < 2 then p, why = nil, "four trop petit pour les poteaux de la colonne" return "end" end
  else
    if spec.furnace and spec.furnace.fuel and spec.furnace.size < 2 then p, why = nil, "four trop petit pour son coffre de combustible" return "end" end
    if spec.furnace and 2 * spec.furnace.size + 3 > spec.pole.wire + Ch.CFG.eps then p, why = nil, "portee des poteaux" return "end" end
  end
  -- un cadre figé rejoue son axe ; (R1) le second plan d'un cadre neuf est fait dans l'axe imposé par le cadre « axes »
  if F and F.axis then axis = F.axis elseif spec.force_axis then axis = spec.force_axis end
  return true
end

-- 1 bis. axe le plus long du gisement (long_axis), relevé par morceaux de CTX_CHUNK tuiles ; contexte à relever
ONCE[#ONCE + 1] = function(P, J)
  local _ENV = P
  if not axis then
    local o = spec.ore
    la = la or { i = 1, x0 = math.huge, y0 = math.huge, x1 = -math.huge, y1 = -math.huge }
    while la.i <= #o - 1 do
      if out_of(J) then return false end
      local stop = math.min(#o - 1, la.i + 2 * (CTX_CHUNK - 1))
      local x0, y0, x1, y1 = la.x0, la.y0, la.x1, la.y1
      for i = la.i, stop, 2 do
        x0, x1 = math.min(x0, o[i]), math.max(x1, o[i])
        y0, y1 = math.min(y0, o[i + 1]), math.max(y1, o[i + 1])
      end
      la.x0, la.y0, la.x1, la.y1 = x0, y0, x1, y1
      spend(J, (stop - la.i + 2) / 2 * Ch.UNITS.axis)
      la.i = stop + 2
    end
    axis = (la.y1 - la.y0 > la.x1 - la.x0) and "y" or "x"
    la = nil
  end
  cx = ctx_new(axis)
  return true
end

-- 2. relevé du minerai (par morceaux), boîte, choix de la phase à préparer
ONCE[#ONCE + 1] = function(P, J)
  local _ENV = P
  if not ctx_fill(cx, spec, J) then return false end
  box = cx.box
  origin = (F and F.origin) or box.u0
  pitch = 2 * d.size + 2
  if F and F.phase then
    phase = F.phase
    box.v0 = F.v0 or box.v0
    scan = { phs = { phase }, k = 1, frame = true, pclean = {} }
  else
    local phs = {}
    for ph = 0, pitch - 1 do phs[#phs + 1] = ph end
    scan = { phs = phs, k = 1, fm = {}, rm = {}, pclean = {} }
  end
  return true
end

-- 3. choix de la phase : phase par phase, bande par bande, et pour chaque bande ses deux rangées décalage par décalage (une rangée de
-- foreuses pour un décalage par unité de travail ; cadre figé : sa phase seule, sans les mémoires partagées). Règle d'avant (best_row) :
-- le plus de minerai miné, puis le moins de foreuses, puis le plus petit décalage ; une rangée vue par deux phases (nord de l'une, sud
-- d'une autre) garde son résultat (scan.rm ; mesuré : le choix de la phase faisait 60 % du plan du géant 200 x 200).
ONCE[#ONCE + 1] = function(P, J)
  local _ENV = P
  local c = ctx_of(cx, spec)
  local fr = scan.frame and F or nil
  local row_cost = (box.u1 - box.u0 + 10) * Ch.UNITS.row
  while scan.k <= #scan.phs do
    local ph = scan.phs[scan.k]
    if scan.pr == nil then
      scan.pr, scan.bs, scan.total = box.v0 - ph, {}, 0
      if fr then scan.fm = {} end
    end
    while scan.pr <= box.v1 do
      local pr = scan.pr
      if not (fr and fr.only) or fr.only[pr] then
        local off = fr and fr.offsets and fr.offsets[tostring(pr)]
        while (scan.part or 1) <= 2 do
          local part = scan.part or 1
          local row = (part == 1) and (pr + 1) or (pr + d.size + 2)
          local fixed = off and off[part]
          -- (R1) rangée des poteaux de ces foreuses (pr au nord, pr + pas au sud) : libre de bout en bout (relevé une fois), ou la condition
          -- de row_drills ; une rangée propre garde la mémoire partagée d'avant (même plan, même coût)
          local prow = (part == 1) and pr or (pr + pitch)
          local pc = scan.pclean[prow]
          if pc == nil then
            if out_of(J) then return false end
            local R = spec.pole.reach
            pc = true
            for u = box.u0 - d.reach - d.size - R, box.u1 + d.reach + d.size + R do if not c.free(u, prow) then pc = false break end end
            scan.pclean[prow] = pc
            spend(J, row_cost * 0.3)
          end
          local cond = (not pc) and prow or nil
          local mkey = cond and (row .. ":" .. cond) or row
          local memo = (fixed == nil and scan.rm) and scan.rm[mkey] or nil
          if not memo then
            scan.o = scan.o or 0
            while scan.o <= d.size - 1 do
              if out_of(J) then return false end
              local o = scan.o
              if fixed == nil or fixed == o then
                local l, m = row_drills(c, spec, row, box.u0, box.u1, origin, o, scan.fm, cond)
                if not scan.cb or m > scan.cbm or (m == scan.cbm and #l < #scan.cb) then scan.cb, scan.cbm, scan.cbo = l, m, o end
                spend(J, row_cost)
              end
              scan.o = o + 1
            end
            memo = { scan.cb, scan.cbm, scan.cbo }
            if fixed == nil and scan.rm then scan.rm[mkey] = memo end
          end
          if part == 1 then scan.nb = memo else scan.sb = memo end
          scan.cb, scan.cbm, scan.cbo, scan.o = nil, nil, nil, nil
          scan.part = part + 1
        end
        local nl, nm, on = scan.nb[1], scan.nb[2], scan.nb[3]
        local sl, sm, os_ = scan.sb[1], scan.sb[2], scan.sb[3]
        if #nl + #sl > 0 then
          scan.bs[#scan.bs + 1] = { pr = pr, b = pr + d.size + 1, n = nl, s = sl, on = on, os = os_ }
          scan.total = scan.total + nm + sm
        end
        scan.part, scan.nb, scan.sb = nil, nil, nil
      end
      scan.pr = pr + pitch
    end
    if fr then
      bands = scan.bs
    elseif not bands or scan.total > bt then
      bands, bt, phase = scan.bs, scan.total, ph
    end
    scan.k, scan.pr = scan.k + 1, nil
  end
  scan = nil
  ti = 1
  return true
end

-- 4. tuiles des foreuses des bandes, prises
ONCE[#ONCE + 1] = function(P, J)
  local _ENV = P
  local c = ctx_of(cx, spec)
  while ti <= #bands do
    if out_of(J) then return false end
    local bd = bands[ti]
    for _, a in ipairs(bd.n) do for u = a, a + d.size - 1 do for v = bd.pr + 1, bd.pr + d.size do c.take(u, v) end end end
    for _, a in ipairs(bd.s) do for u = a, a + d.size - 1 do for v = bd.b + 1, bd.b + d.size do c.take(u, v) end end end
    spend(J, (#bd.n + #bd.s) * Ch.UNITS.take)
    ti = ti + 1
  end
  ti = nil
  return true
end

-- 5. bords, sortie, débits, états de la passe 1 et de la passe 2 (lot CHAMP-COUVERTURE), réservations d'un cadre figé
ONCE[#ONCE + 1] = function(P, J)
  local _ENV = P
  local c = ctx_of(cx, spec)
  umin, umax = box.u0, box.u1
  for _, bd in ipairs(bands) do
    for _, l in ipairs({ bd.n, bd.s }) do for _, a in ipairs(l) do umin = math.min(umin, a); umax = math.max(umax, a + d.size - 1) end end
  end
  if F and F.umin then umin, umax = F.umin, F.umax end
  exit = (F and F.exit) or 1
  if not (F and F.exit) and spec.target then
    local tu = c.uv(spec.target.x, spec.target.y)
    if math.abs(tu - umin) < math.abs(tu - umax) then exit = -1 end
  end
  cap = Ch.lane_drills(spec.belts[#spec.belts].lane, d.rate)
  if spec.max_side then cap = math.min(cap, spec.max_side) end
  if cap < 1 then p, why = nil, "tapis trop lent pour une foreuse" return "end" end
  -- lot FONDERIE : avec du combustible, la tête charge tout le minerai sur UNE voie (l'autre porte le charbon) : le groupe entier tient
  -- dans une voie du tapis le plus rapide
  fuelled = colonne and spec.furnace.fuel
  total = fuelled and Ch.lane_drills(spec.belts[#spec.belts].lane, d.rate) or nil
  ents, out_bands = {}, {}
  capped, flow_all, cap_all, no_smelter = 0, 0, 0, 0
  offsets = {}
  pending = {} -- (lot FONDERIE) colonnes posées, émises après le choix de leur charbon
  -- lot CHAMP-COUVERTURE (R2 + R3) : découplage pour un cadre neuf ; un cadre figé rejoue frame.routed (absent : cadre d'avant le lot)
  decouple_new = Ch.CFG.decouple and not F
  r23 = (decouple_new or (F and F.routed)) and true or false
  routed_frame = r23 and {} or nil
  used_rows = { [1] = {}, [-1] = {} }
  n_routed, route_max, n_moved, why_routed = 0, 0, 0, {}
  ug = spec.logistics and spec.logistics.underground or nil
  ugs_set = {}
  for _, k in ipairs(spec.ug_tiles or {}) do local u, v = c.uv(k[1], k[2]); ugs_set[Co.tk(u, v)] = true end
  -- (lot CHAMP-COUVERTURE) une fonderie déplacée ne se pose jamais sur le charbon lu pour les colonnes (sa ligne de foreuses en a besoin)
  coal_uv = {}
  if spec.coal and spec.coal.tiles then
    for i = 1, #spec.coal.tiles - 1, 2 do local u, v = c.uv(spec.coal.tiles[i], spec.coal.tiles[i + 1]); coal_uv[Co.tk(u, v)] = true end
  end
  -- (lot CHAMP-COUVERTURE, R2) obstacles courts de la rangée du tapis sautés en souterrain, souterrains débloqués et cadre du lot seulement
  hop = (r23 and ug and ug >= 2) and (ug - 1) or nil
  -- cadre figé : les fonderies déplacées et les tracés des AUTRES bandes sont réservés (bande seule : ils ne sont pas posés ici)
  if F and F.routed and F.only then
    local pks = {}
    for k in pairs(F.routed) do pks[#pks + 1] = k end
    table.sort(pks, function(a, b) return tonumber(a) < tonumber(b) end)
    for _, pk in ipairs(pks) do
      if not F.only[tonumber(pk)] then
        for _, sk in ipairs({ "1", "-1" }) do
          local rf = F.routed[pk][sk]
          if rf then
            for _, t in ipairs(rf.tiles or {}) do c.take(t[1], t[2]) end
            for _, t in ipairs(rf.route or {}) do c.take(t[1], t[2]) end
            for _, t in ipairs(rf.poles or {}) do c.take(t[1], t[2]) end
          end
        end
      end
    end
  end
  -- lot CHAMP-COUVERTURE (R2 + R3) : DEUX PASSES. Passe 1 : le chemin d'avant, bande par bande ; un côté qui réussit est posé tel quel,
  -- tapis compris (un champ propre garde son plan, entité par entité). Passe 2 : les côtés où il a échoué, sortie au bout de la bande et
  -- fonderie déplacée, quand tout ce que la passe 1 pose est déjà pris : une fonderie déplacée ne prend jamais la place d'un groupe du
  -- chemin d'avant (en une passe, mesuré sur la partie du joueur 271828182 : 59 foreuses au lieu de 63, la colonne déplacée de la bande 8
  -- avait pris la rangée de la bande 16).
  sides = Ch.CFG.both_ends and { exit, -exit } or { exit }
  bstate = {}
  bi1 = 1
  if r23 then rd = Cc.rects_data(bands, d.size, spec.pole.reach, pitch) end
  spend(J, #bands * Ch.UNITS.take)
  return true
end

-- 6. passe 1 : le chemin d'avant, bande par bande et côté par côté ; la place d'une colonne d'un cadre neuf (Co.place_new / run) est
-- cherchée un recul par unité
ONCE[#ONCE + 1] = function(P, J)
  local _ENV = P
  local K = kit(P)
  local c = K.c
  while bi1 <= #bands do
    local bi, bd = bi1, bands[bi1]
    local st = bstate[bi]
    if not st then
      if out_of(J) then return false end
      offsets[tostring(bd.pr)] = { bd.on, bd.os }
      st = { used = {}, groups = {}, limit = nil, later = {}, bo = { pr = bd.pr, b = bd.b, groups = {} } }
      bstate[bi] = st
      p1 = { si = 1 }
    end
    while p1.si <= #sides do
      local side = sides[p1.si]
      local edge = side > 0 and umax or umin
      local rfix = F and F.routed and F.routed[tostring(bd.pr)] and F.routed[tostring(bd.pr)][tostring(side)]
      local refused_here = spec.refuse and spec.refuse[tostring(bd.pr) .. ":" .. tostring(side)]
      local fc = F and F.cols and F.cols[tostring(bd.pr)] and F.cols[tostring(bd.pr)][tostring(side)]
      -- (lot CHAMP-COUVERTURE) la passe 2 n'est ouverte qu'au cadre neuf du lot ou au côté tracé d'un cadre figé, jamais à un côté refusé
      local routable = (rfix or decouple_new) and not refused_here and not (fc and fc.mode == "refusee")
      if rfix and routable then
        st.later[#st.later + 1] = { side = side }
      else
        local g = p1.g
        if g == nil then
          if out_of(J) then return false end
          g = take_group(c, spec, bd, side, cap, edge, st.used, st.limit, total, hop) or false
          p1.g = g
          spend(J, Ch.UNITS.side)
          -- place de la colonne d'un cadre neuf : cherchée par morceaux (même appel que Co.place sans `fixed`)
          if g and colonne and Co.FAST_PLACE and not ((fc and fc.mode == "refusee") or refused_here) and not (F and F.cols) then
            p1.pst = Co.place_new(spec, bd.b, side, edge, Fd.count(spec, (#g.n + #g.s) * d.rate), Ch.CFG.gap, Ch.CFG.shift,
              fuelled and "voie" or nil)
          end
        end
        g = g or nil
        local list, len, s_edge, count, info
        local flow
        if g and p1.pst then
          flow = (#g.n + #g.s) * d.rate
          if not Co.place_run(p1.pst, spec, c.free, c.is_ore, J) then return false end
          local ps = p1.pst
          list, len, s_edge, count, info = ps.list, ps.len, ps.s_edge, ps.count, ps.info
        elseif g then
          flow = (#g.n + #g.s) * d.rate
          if colonne then
            local fixed = fc
            local refused = (fixed and fixed.mode == "refusee") or refused_here
            if refused then
              list = nil -- (lot FONDERIE) colonne refusée : pas de voie de charbon
            elseif not (F and F.cols) or fixed then
              local mode = fuelled and ((fixed and fixed.mode) or "voie") or nil
              list, len, s_edge, count, info = Co.place(spec, bd.b, side, edge, Fd.count(spec, flow), Ch.CFG.gap, Ch.CFG.shift, c.free,
                c.is_ore, mode, fixed)
            end
          else
            list, len, s_edge, count = Fd.place(spec, bd.b, side, edge, flow, Ch.CFG.gap, Ch.CFG.shift, c.free, c.is_ore)
          end
        end
        if g and list then
          K.commit(bd, st, side, g, flow, list, len, s_edge, count, info, nil)
        elseif routable then
          st.later[#st.later + 1] = { side = side, had_group = g ~= nil }
        elseif g then
          no_smelter = no_smelter + 1
        end
      end
      p1 = { si = p1.si + 1 }
    end
    K.emit_groups(bi, bd, st, 1)
    out_bands[#out_bands + 1] = st.bo
    spend(J, Ch.UNITS.band + (#bd.n + #bd.s))
    bi1, p1 = bi1 + 1, nil
  end
  bi1 = nil
  p2 = { bi = 1, li = 1 }
  return true
end

-- 7. passe 2 : les côtés où le chemin d'avant a échoué, bande par bande, dans l'ordre des côtés ; chaque côté (Cc.trim, place, tracé
-- A*) est reprenable (route_side d'avant, état dans p2.rs)
ONCE[#ONCE + 1] = function(P, J)
  local _ENV = P
  local K = kit(P)
  local c = K.c
  while p2.bi <= #bands do
    local bi, bd = p2.bi, bands[p2.bi]
    local st = bstate[bi]
    if #st.later > 0 then
      if not p2.from then p2.from = #st.groups + 1 end
      while p2.li <= #st.later do
        if out_of(J) then return false end
        local it = st.later[p2.li]
        local side = it.side
        -- (lot CHAMP-COUVERTURE, R2 + R3) côté rejoué d'un cadre figé (rfix) ou côté où le chemin d'avant a échoué : sortie au bout de la
        -- bande (Cc.local_edge), fonderie déplacée, tapis tracé ; la sortie bouchée juste après la bande (tourelle, eau) recule d'une
        -- foreuse à la fois (Cc.trim)
        local edge = side > 0 and umax or umin
        local rfix = F and F.routed and F.routed[tostring(bd.pr)] and F.routed[tostring(bd.pr)][tostring(side)]
        if not p2.rs then
          p2.rs = { k = rfix and (rfix.trim or 0) or 0, k1 = rfix and (rfix.trim or 0) or Cc.CFG.trim }
        end
        local rs = p2.rs
        local placed = false
        while not placed and rs.k <= rs.k1 do
          local k = rs.k
          if not rs.gl then
            local bt, le = Cc.trim(bd, side, d.size, k)
            local gl = le and take_group(c, spec, bt, side, cap, le, st.used, st.limit, total, hop)
            spend(J, Ch.UNITS.side)
            if gl then
              local fl = (#gl.n + #gl.s) * d.rate
              local cnt = rfix and rfix.count or Fd.count(spec, fl)
              local mode = (colonne and fuelled) and ((rfix and rfix.mode) or "voie") or nil
              rs.gl, rs.le, rs.fl, rs.cnt, rs.mode = gl, le, fl, cnt, mode
              if not rfix then
                rs.pst = Cc.place_new({ spec = spec, colonne = colonne, mode = mode, b = bd.b, side = side, edge = edge, exit = le,
                  count = cnt, gap = Ch.CFG.gap, pitch = pitch, used_rows = used_rows[side], ug = ug, own = { pr = bd.pr, side = side, exit = le },
                  beyond = spec.push and spec.push[tostring(bd.pr) .. ":" .. tostring(side)] })
              end
            end
          end
          if rs.gl then
            local r, why_k
            if rfix then
              local l2, ln2, inf2, tiles2 = Cc.layout(spec, colonne, rfix.row, side, rfix.s_edge, rs.cnt, rs.mode)
              local ok = l2 ~= nil
              for _, t in ipairs(ok and tiles2 or {}) do if ok and not c.free(t[1], t[2]) then ok = false end end
              local rt = {}
              for _, t in ipairs(rfix.route or {}) do
                if ok and not c.free(t[1], t[2]) then ok = false end
                rt[#rt + 1] = { u = t[1], v = t[2], d = t[3], kind = t[4] == 1 and "souterrain" or "tapis",
                  ug = (t[5] == 1 and "input") or (t[5] == 2 and "output") or nil }
              end
              local lp = {}
              for _, t in ipairs(rfix.poles or {}) do
                if ok and not c.free(t[1], t[2]) then ok = false end
                lp[#lp + 1] = { t[1], t[2] }
              end
              if ok then r = { list = l2, len = ln2, info = inf2, row = rfix.row, s_edge = rfix.s_edge, route = rt, tiles = tiles2, poles = lp } end
            else
              local fns = { free = function(u, v) return c.free(u, v) and K.not_coal(u, v) end, is_ore = c.is_ore, forbid = K.forbid, span = K.span }
              if not Cc.place_run(rs.pst, fns, J) then return false end
              r, why_k = rs.pst.res, rs.pst.why
            end
            if r then
              local gl = rs.gl
              gl.exit, gl.trim = rs.le, k
              K.commit(bd, st, side, gl, rs.fl, r.list, r.len, r.s_edge, rs.cnt, r.info, r)
              placed = true
            else
              rs.last_why = why_k or rs.last_why
            end
          end
          rs.gl, rs.le, rs.fl, rs.cnt, rs.mode, rs.pst = nil, nil, nil, nil, nil, nil
          if not placed then rs.k = k + 1 end
        end
        if not placed then
          if rs.last_why then
            why_routed[#why_routed + 1] = string.format("bande %d cote %s : %s", bd.pr, side > 0 and "+" or "-", rs.last_why)
          end
          if it.had_group then no_smelter = no_smelter + 1 end
        end
        p2.rs = nil
        p2.li = p2.li + 1
      end
      K.emit_groups(bi, bd, st, p2.from)
    end
    p2.bi, p2.li, p2.from = p2.bi + 1, 1, nil
  end
  p2 = nil
  for bi, bd in ipairs(bands) do
    local st = bstate[bi]
    for _, l in ipairs({ { bd.n, "n" }, { bd.s, "s" } }) do
      for _, a in ipairs(l[1]) do if not st.used[a .. l[2]] then capped = capped + 1 end end
    end
  end
  -- lot FONDERIE : charbon des colonnes, un réseau par côté du champ (cadre neuf : calculé ; bande seule : rejoué du cadre)
  cols_frame, coal_frame, coal_stats = nil, nil, {}
  fallback = nil -- (lot FONDERIE) colonnes d'un cadre neuf retombées sur le coffre de tête : { pr, side, why }
  cut = {}
  return true
end

--- Données du réseau du charbon d'un cadre neuf (zone interdite au tracé, charbon, souterrains posés) ; l'env de Co.network en est refait.
local function coal_env(P, c)
  local _ENV = P
  local zone = cz.zone
  local zrects = cz.zrects
  local function in_zone(u, v)
    if not zrects then return u >= zone.u0 - 1 and u <= zone.u1 + 1 and v >= zone.v0 - 1 and v <= zone.v1 + 1 end
    for _, r in ipairs(zrects) do
      if u >= r.u0 - 1 and u <= r.u1 + 1 and v >= r.v0 - 1 and v <= r.v1 + 1 then return true end
    end
    return false
  end
  local coal_set, coal_list = cz.coal_set, cz.coal_list
  local co = spec.coal
  local lg = spec.logistics or {}
  return {
    free = c.free, coal = { tiles = coal_list, is_coal = function(u, v) return coal_set[Co.tk(u, v)] == true end, rate = co and co.rate,
      -- lot MELANGE : tuiles d'une autre ressource minable autour du charbon (le minerai du champ compris)
      is_foreign = co and co.foreign and function(u, v)
        if coal_set[Co.tk(u, v)] then return false end
        local x, y = c.xy(u, v)
        return co.foreign[Ch.key(x, y)] == true
      end or nil },
    forbid = in_zone,
    -- (banc-2, 3/11) pas de répartiteur sur le tronc même débloqué : la cascade 50/50 n'a pas de plafond par colonne, les dernières
    -- attendent que les tampons d'amont se remplissent (mesuré : 12, 6, 4 et 4 fours garnis le long du tronc) ; le bras de
    -- dérivation, lui, borne la prise de chaque colonne. Les souterrains restent (passer sous un obstacle).
    drill = d, pole = spec.pole, ug = lg.underground, split = false, ugs = cz.ugs, box = zone,
    inserter_rate = spec.inserter and spec.inserter.rate,
    soft = spec.soft and function(u, v) local x, y = c.xy(u, v); return spec.soft[Ch.key(x, y)] == true end or nil,
    lane_drills = co and co.rate and Ch.lane_drills(spec.belts[1].lane, co.rate) or nil,
    bridge = function(poles, free)
      local extra = {}
      local cc = { free = function(u, v) return not extra[Co.tk(u, v)] and free(u, v) end, take = function(u, v) extra[Co.tk(u, v)] = true end }
      return bridge(cc, spec, poles)
    end,
  }
end

-- 8. réseau du charbon de chaque côté (Co.network reprenable), ou rejoué du cadre figé
ONCE[#ONCE + 1] = function(P, J)
  local _ENV = P
  if not colonne then return true end
  local c = ctx_of(cx, spec)
  if not nets then
    cols_frame, coal_frame = {}, {}
    nets = {}
    if fuelled and not F then
      local zone = { u0 = math.huge, u1 = -math.huge, v0 = math.huge, v1 = -math.huge }
      local function grow(u, v) zone.u0, zone.u1 = math.min(zone.u0, u), math.max(zone.u1, u); zone.v0, zone.v1 = math.min(zone.v0, v), math.max(zone.v1, v) end
      grow(umin, box.v0 - pitch); grow(umax, box.v1 + pitch)
      for _, it in ipairs(pending) do
        grow(it.g.s_edge, it.b); grow(it.g.s_edge + it.g.side * it.g.info.far, it.b)
      end
      -- (lot CHAMP-COUVERTURE) avec des colonnes déplacées, la zone interdite au tracé du charbon est le champ ET chaque colonne, pas leur
      -- boîte commune (une colonne passée au-delà d'une rivière avalait le gisement de charbon dans la boîte : 0 charbon extrait, mesuré
      -- au banc « rivière avec souterrains » de tests/champ_colonne_test.lua) ; sans colonne déplacée, la boîte d'avant, à l'identique
      local zrects = nil
      if n_routed > 0 then
        zrects = { { u0 = umin, u1 = umax, v0 = box.v0 - pitch, v1 = box.v1 + pitch } }
        for _, it in ipairs(pending) do
          local ua, ub = it.g.s_edge, it.g.s_edge + it.g.side * it.g.info.far
          zrects[#zrects + 1] = { u0 = math.min(ua, ub), u1 = math.max(ua, ub), v0 = it.b - spec.furnace.size - 3, v1 = it.b + 1 }
        end
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
      cz = { zone = zone, zrects = zrects, coal_set = coal_set, coal_list = coal_list, ugs = ugs }
      -- (revue-fonderie, 3/11) ordre des côtés : le premier réseau prend ses tuiles, le second ne croise son tracé qu'en souterrain ;
      -- spec.coal_first (posé par Ch.plan) fait passer l'autre côté d'abord
      local first = spec.coal_first or exit
      net = { sides = { first, -first }, k = 1 }
      spend(J, #coal_list * Ch.UNITS.take)
    elseif F and F.coal then
      for _, side in ipairs({ exit, -exit }) do
        local cf = F.coal[tostring(side)]
        if cf then nets[side] = { uT = cf.uT, dv = cf.dv, split = cf.split, ents = cf.ents or {}, last = cf.last, why = cf.why } end
      end
    end
  end
  while net and net.k <= #net.sides do
    local side = net.sides[net.k]
    if not net.st then
      local cols = {}
      for _, it in ipairs(pending) do
        if it.g.side == side then
          cols[#cols + 1] = { key = tostring(it.pr), b = it.b, s_edge = it.g.s_edge, far = it.g.info.far, need = it.g.info.need }
        end
      end
      if #cols > 0 then net.st = Co.network_new(cols, side) end
    end
    if net.st then
      if out_of(J) then return false end
      if not Co.network_run(net.st, coal_env(P, c), J) then return false end
      local cols = net.st.cols
      nets[side] = net.st.res
      local nt = nets[side]
      -- le réseau prend ses tuiles (poteaux des rangées et relais du champ ne s'y posent pas)
      for _, e in ipairs(nt.ents) do
        for u = e.u, e.u + (e.w or e.size) - 1 do for v = e.v, e.v + (e.h or e.size) - 1 do c.take(u, v) end end
      end
      local last_key
      for _, cl in ipairs(cols) do if cl.last then last_key = cl.key end end
      local why = nt.why
      if nt.dropped and #nt.dropped > 0 then why = (why and (why .. " ; ") or "") .. table.concat(nt.dropped, " ; ") end
      coal_frame[tostring(side)] = { uT = nt.uT, dv = nt.dv, split = nt.split, last = last_key, ents = nt.ents, why = why,
        drills = nt.drills, undergrounds = nt.undergrounds }
      net.st = nil
    end
    net.k = net.k + 1
  end
  net, cz = nil, nil
  shared_done = {}
  fallback = {}
  pi = 1
  return true
end

-- 9. colonnes : mode (voie ou coffre de tête), replis, dérivations (une colonne par morceau), pièces communes du réseau d'un côté (par
-- morceaux de ENT_CHUNK / 8 entités, émises à la suite de la première colonne du côté, comme avant)
ONCE[#ONCE + 1] = function(P, J)
  local _ENV = P
  if not colonne then return true end
  local K = kit(P)
  local c, emit_e = K.c, K.emit_e
  while pi <= #pending do
    local it = pending[pi]
    local g = it.g
    local key = tostring(it.pr)
    local nt = nets[g.side]
    if not pa then
    if out_of(J) then return false end
    local n_emit = 0
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
      -- (lot CHAMP-COUVERTURE) colonne déplacée posée en deçà d'un obstacle que le tronc, au-delà des autres colonnes du côté, met entre
      -- elle et lui (mesuré : « ligne voisine, avec souterrains » de tests/champ_colonne_test.lua, dérivation sur la ligne)
      local at = g.route and nt and nt.dropped_at and nt.dropped_at[key]
      if at then cut[#cut + 1] = { pr = it.pr, side = g.side, u = at[1] } end
    end
    if mode == "coffre" and g.info.mode == "voie" then
      -- repli : le coffre de tête (ses tuiles sont dans celles de la voie, déjà prises)
      local list, len, info = Co.layout(spec, it.b, g.side, g.s_edge, g.count, "coffre")
      g.list, g.info = list, info
      g.len = math.min(g.len, len)
    end
    for _, e in ipairs(g.list) do emit_e(e, it.bi, it.gi, it.pr, e.kind == "tapis" and (e.role == "charbon" and 1 or g.belt) or nil) end
    n_emit = n_emit + #g.list
    if mode == "voie" and nt and nt.uT then
      local cf = (F and F.cols) and nt or coal_frame[tostring(g.side)]
      local col = { b = it.b, s_edge = g.s_edge, far = g.info.far, last = (cf and cf.last) == key }
      for _, e in ipairs(Co.branch(col, nt, g.side, spec.pole.wire)) do
        for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do c.take(u, v) end end
        emit_e(e, it.bi, it.gi, it.pr, e.kind == "tapis" and 1 or nil)
        n_emit = n_emit + 1
      end
      if not shared_done[g.side] then
        shared_done[g.side] = true
        shq = 1
      end
    end
    pa, pmode = true, mode
    spend(J, Ch.UNITS.pending + n_emit * Ch.UNITS.emit)
    end
    if shq then
      -- (projet séparé, 3/11) pièces COMMUNES du réseau du charbon d'un côté, marquées : le runtime les pose dans le projet « réseau du
      -- charbon » de ce côté, pas dans la bande
      while shq <= #nt.ents do
        if out_of(J) then return false end
        local stop = math.min(#nt.ents, shq + ENT_CHUNK / 8 - 1)
        for i = shq, stop do
          local e = nt.ents[i]
          emit_e(e, 0, 0, nil, (e.kind == "tapis" or e.kind == "souterrain" or e.kind == "repartiteur") and 1 or nil)
          ents[#ents].coalnet = g.side
        end
        spend(J, (stop - shq + 1) * Ch.UNITS.emit)
        shq = stop + 1
      end
      shq = nil
    end
    local mode = pmode
    pa, pmode = nil, nil
    cols_frame[key] = cols_frame[key] or {}
    cols_frame[key][tostring(g.side)] = { s_edge = g.s_edge, count = g.count, mode = mode }
    g.mode = mode
    local og = out_bands[it.bi] and out_bands[it.bi].groups[it.gi]
    if og then og.mode = (mode == "voie" and nt and nt.uT) and "voie" or mode end
    pi = pi + 1
  end
  pi = nil
  for _, side in ipairs({ exit, -exit }) do
    local nt = nets[side]
    if nt then
      local why = nt.why
      if nt.dropped and #nt.dropped > 0 then why = (why and (why .. " ; ") or "") .. table.concat(nt.dropped, " ; ") end
      coal_stats[#coal_stats + 1] = { side = side, voie = nt.uT ~= nil, why = why, drills = nt.drills, undergrounds = nt.undergrounds, split = nt.split }
    end
  end
  if F and F.coal then coal_frame = F.coal end
  -- bande seule : les colonnes des AUTRES bandes du cadre sont réservées (non posées) avant les poteaux des rangées, qui les
  -- contournent comme dans le plan entier (sinon un poteau prolongé prendrait la tuile d'un bras d'une colonne voisine à venir)
  if F and F.cols then
    local keys = {}
    for k in pairs(F.cols) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tonumber(a) < tonumber(b) end)
    fck, fci = keys, 1
  end
  return true
end

-- 10. bande seule : colonnes des autres bandes réservées (une clé de bande par unité)
ONCE[#ONCE + 1] = function(P, J)
  local _ENV = P
  if not fck then return true end
  local c = ctx_of(cx, spec)
  while fci <= #fck do
    if out_of(J) then return false end
    local k = fck[fci]
    for _, sk in ipairs({ "1", "-1" }) do
      local fc = F.cols[k][sk]
      -- (lot CHAMP-COUVERTURE) une colonne déplacée est réservée avec son tracé (F.routed, avant les bandes)
      local moved = F.routed and F.routed[k] and F.routed[k][sk]
      if fc and fc.mode ~= "refusee" and not moved and not (F.only and F.only[tonumber(k)]) then
        local l = Co.layout(spec, tonumber(k) + d.size + 1, tonumber(sk), fc.s_edge, fc.count, fc.mode)
        for _, e in ipairs(l or {}) do
          for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do c.take(u, v) end end
        end
      end
    end
    spend(J, Ch.UNITS.cols)
    fci = fci + 1
  end
  fck, fci = nil, nil
  return true
end

-- 11. rangées de poteaux à poser (une bande par unité), poteaux déjà émis (par morceaux de ENT_CHUNK entités), poteaux de liaison des
-- tracés (une bande par unité)
ONCE[#ONCE + 1] = function(P, J)
  local _ENV = P
  local c = ctx_of(cx, spec)
  -- poteaux des rangées : la rangée pr couvre le haut de sa bande et le bas de la bande d'avant ; elle va jusqu'aux fonderies (lot
  -- FONDERIE : seule la rangée pr, du côté des fours, va jusqu'à la colonne ; l'autre passerait sur la colonne de la bande voisine)
  if not s11 then s11 = { ph = 1, i = 1 }; rows, row_list, reach_to = {}, {}, {} end
  if s11.ph == 1 then
    while s11.i <= #bands do
      if out_of(J) then return false end
      local bi = s11.i
      local bd, bo = bands[bi], out_bands[bi]
      if #bo.groups > 0 then
        for _, it in ipairs({ { bd.pr, bd.n, bd.pr, "pole_u" }, { bd.pr + pitch, bd.s, bd.pr, colonne and "pole_u2" or "pole_u" } }) do
          local row = it[1]
          if not rows[row] then rows[row] = {}; reach_to[row] = {}; row_list[#row_list + 1] = { row = row, pr = it[3] } end
          for _, a in ipairs(it[2]) do rows[row][#rows[row] + 1] = a end
          for _, g in ipairs(bo.groups) do reach_to[row][#reach_to[row] + 1] = g[it[4]] end
        end
      end
      spend(J, 1 + (#bd.n + #bd.s + #bo.groups) * Ch.UNITS.ent)
      s11.i = bi + 1
    end
    table.sort(row_list, function(p_, q) return p_.row < q.row end)
    all_poles = {}
    s11.ph, s11.i = 2, 1
  end
  if s11.ph == 2 then
    while s11.i <= #ents do
      if out_of(J) then return false end
      local stop = math.min(#ents, s11.i + ENT_CHUNK - 1)
      for i = s11.i, stop do
        local e = ents[i]
        if e.kind == "poteau" then local u, v = c.uv(math.floor(e.x), math.floor(e.y)); all_poles[#all_poles + 1] = { u, v } end
      end
      spend(J, (stop - s11.i + 1) * Ch.UNITS.ent)
      s11.i = stop + 1
    end
    link_on = {}
    s11.ph, s11.i = 3, 1
  end
  while s11.i <= #bands do
    if out_of(J) then return false end
    for _, g in ipairs(bstate[s11.i].groups) do
      for _, t in ipairs(g.link or {}) do link_on[t[2]] = link_on[t[2]] or {}; link_on[t[2]][#link_on[t[2]] + 1] = t[1] end
    end
    spend(J, 1)
    s11.i = s11.i + 1
  end
  s11 = nil
  ri = 1
  return true
end

-- 12. poteaux des rangées, une rangée par unité
ONCE[#ONCE + 1] = function(P, J)
  local _ENV = P
  local K = kit(P)
  local c, emit = K.c, K.emit
  while ri <= #row_list do
    if out_of(J) then return false end
    local r = row_list[ri]
    table.sort(reach_to[r.row])
    for _, u in ipairs(row_poles(c, spec, r.row, rows[r.row], origin, reach_to[r.row], link_on[r.row])) do
      emit("poteau", u, r.row, 1, 0, 0, 0, 0, r.pr)
      all_poles[#all_poles + 1] = { u, r.row }
    end
    spend(J, Ch.UNITS.pole_row + #rows[r.row])
    ri = ri + 1
  end
  ri = nil
  if not (F and F.only) and #all_poles > 1 then
    -- (lot CHAMP-COUVERTURE) un plan à coffres qui a des fonderies déplacées prend aussi les relais à plusieurs paires : ses quais sont loin
    -- des rangées de poteaux (12 réseaux sur le disque à coffres entre deux lacs avec bridge_0641)
    br = br_new(colonne or n_routed > 0)
  end
  return true
end

-- 13. relais entre réseaux de poteaux (br_run reprenable : un poteau, un morceau de classement, une paire ou une chaîne par unité)
ONCE[#ONCE + 1] = function(P, J)
  local _ENV = P
  if not br then return true end
  local K = kit(P)
  local c, emit = K.c, K.emit
  if not br_run(br, c, spec, all_poles, J) then return false end
  for _, p_ in ipairs(br.added) do emit("poteau", p_[1], p_[2], 1, 0, 0, 0, 0, nil, "relais") end
  br_split = br.split or nil
  br = nil
  return true
end

-- 14. comptes, cadre, plan rendu
ONCE[#ONCE + 1] = function(P, J)
  local _ENV = P
  -- comptes par sorte, et ceux des règles des cadres « pushed », « order » et « plan » (Ch.head_chests, Ch.field_drills : n.hc, n.fd),
  -- relevés ici par morceaux au lieu d'un parcours d'un coup de p.ents à chaque comparaison
  if not s14 then
    s14 = { i = 1, hc = 0, fd = 0, n = { foreuse = 0, poteau = 0, tapis = 0, four = 0, bras = 0, coffre = 0, souterrain = 0, repartiteur = 0 } }
  end
  while s14.i <= #ents do
    if out_of(J) then return false end
    local stop = math.min(#ents, s14.i + ENT_CHUNK - 1)
    local cnt = s14.n
    for i = s14.i, stop do
      local e = ents[i]
      local k = e.kind
      cnt[k] = cnt[k] + 1
      if k == "coffre" and e.role == "combustible" then s14.hc = s14.hc + 1
      elseif k == "foreuse" and e.role ~= "charbon" then s14.fd = s14.fd + 1 end
    end
    spend(J, (stop - s14.i + 1) * Ch.UNITS.ent)
    s14.i = stop + 1
  end
  local n = s14.n
  nc = { hc = s14.hc, fd = s14.fd, split = br_split or nil } -- split : (R1) réseaux de poteaux restés séparés
  s14 = nil
  local frame = { axis = axis, phase = phase, exit = exit, origin = origin, umin = umin, umax = umax, v0 = box.v0, offsets = offsets }
  if colonne then frame.design, frame.cols, frame.coal = "colonne", cols_frame, coal_frame
  elseif spec.design and not F then frame.design = "coffres" end -- cadre neuf sans four (charbon, pierre) : distinct d'un cadre d'avant le lot
  -- lot CHAMP-COUVERTURE : fonderies déplacées et tracés (une bande seule les rejoue ; présent, même vide, sur tout cadre neuf du lot)
  if routed_frame then frame.routed = routed_frame end
  local band_drills = 0
  for _, bd in ipairs(bands) do band_drills = band_drills + #bd.n + #bd.s end
  p, why = {
    axis = axis, exit = exit, phase = phase, pitch = pitch, ents = ents, bands = out_bands, design = colonne and "colonne" or nil,
    fallback = fallback,
    fuelled = fuelled or nil,
    why_routed = why_routed, -- (lot CHAMP-COUVERTURE) groupes sans fonderie déplacée possible, et pourquoi
    cut = cut, -- (lot CHAMP-COUVERTURE) colonnes déplacées dont la dérivation du charbon est coupée : { pr, side, u } (plan_pushed)
    frame = frame,
    stats = { tiles = #cx.list, drills = n.foreuse, poles = n.poteau, belts = n.tapis, furnaces = n.four, inserters = n.bras,
      chests = n.coffre, capped = capped, flow = flow_all, capacity = cap_all, umin = umin, umax = umax, no_smelter = no_smelter,
      undergrounds = n.souterrain, splitters = n.repartiteur, coal = coal_stats,
      routed = n_routed, route_max = route_max, moved = n_moved, -- (lot CHAMP-COUVERTURE) groupes tracés, plus long tracé, fonderies sur une autre rangée
      band_drills = band_drills },
  }, nil
  return "end"
end

local RUN = {}
local function push(J, fr) J.stack[#J.stack + 1] = fr; return "call" end
--- Ch.better_order(a, b) sur les comptes relevés à l'étape finale de « once » (an, bn : { hc = coffres de tête, fd = foreuses du champ }) :
--- même règle, sans reparcourir les entités des deux plans.
local function better_n(a, an, b, bn)
  if not b then return false end
  if not a then return true end
  if an.hc ~= bn.hc then return bn.hc < an.hc end
  return bn.fd > an.fd
end
local function copy_spec(spec) local sp = {}; for k, v in pairs(spec) do sp[k] = v end; return sp end

--- « once » : un plan (plan_once d'avant), étape par étape.
function RUN.once(J, P)
  while true do
    -- une étape commence sur un budget non épuisé (son travail d'entrée compte dans le pas suivant, pas dans celui qui finit)
    if J.left <= 0 then return "pause" end
    -- (R1) essai de l'autre axe au-delà de son travail permis : abandonné (le travail fait est le même d'un bloc ou en tranches)
    if J.cap and (J.used or 0) > J.cap.limit then return "abort" end
    local r = ONCE[P.pc](P, J)
    if r == false then return "pause" end
    if r == "end" then
      -- le cadre n'est plus qu'un résultat : son état de travail est rendu (il ne voyage plus dans la sauvegarde)
      local p, why, spec, nc = P.p, P.why, P.spec, P.nc
      for k in pairs(P) do P[k] = nil end
      P.fn, P.p, P.why, P.spec, P.n = "once", p, why, spec, nc
      return "ret"
    end
    P.pc = P.pc + 1
  end
end

--- « pushed » : (lot CHAMP-COUVERTURE) plan d'un champ dont une colonne déplacée a sa dérivation du charbon coupée (plan.cut) : refait
--- UNE fois, ces colonnes posées au-delà de la tuile occupée (spec.push, lu par Cc.place_routed) ; le meilleur des deux est gardé
--- (Ch.better_order : le moins de coffres de tête, puis le plus de foreuses). Sans colonne coupée, ou cadre figé : le plan tel quel.
function RUN.pushed(J, fr)
  if fr.pc == 1 then fr.pc = 2 return push(J, { fn = "once", pc = 1, spec = fr.spec }) end
  if fr.pc == 2 then
    local p, why, spec = fr.got_p, fr.got_why, fr.spec
    fr.p, fr.why, fr.n = p, why, fr.got_n
    if spec.frame or spec.push or not (p and p.cut and #p.cut > 0) then return "ret" end
    local sp = copy_spec(spec)
    sp.push = {}
    for _, x in ipairs(p.cut) do sp.push[tostring(x.pr) .. ":" .. tostring(x.side)] = x.u end
    fr.pc = 3
    return push(J, { fn = "once", pc = 1, spec = sp })
  end
  local q, qwhy, p = fr.got_p, fr.got_why, fr.p
  if better_n(p, fr.n, q, fr.got_n) then
    q.pushed = #p.cut
    fr.p, fr.why, fr.n = q, qwhy, fr.got_n
  end
  return "ret"
end

--- « order » : Lot FONDERIE : un cadre NEUF en colonne à combustible ne garde aucune colonne retombée sur le coffre de tête : elles sont
--- refusées (spec.refuse) et le plan est refait sans elles, au plus CFG.refuse_passes fois ; le cadre les note « refusee ».
function RUN.order(J, fr)
  local spec = fr.spec
  if fr.pc == 1 then fr.pc = 2 return push(J, { fn = "pushed", pc = 1, spec = spec }) end
  if fr.pc == 2 then
    local p, why = fr.got_p, fr.got_why
    fr.p, fr.why, fr.n = p, why, fr.got_n
    if not (Ch.CFG.refuse_coffre and p and p.design == "colonne" and p.fuelled and not spec.frame) then return "ret" end
    if not (p.fallback and #p.fallback > 0) then return "ret" end
    fr.p0, fr.why0, fr.n0 = p, why, fr.n -- plan avec les colonnes au coffre de tête (0.6.42) : gardé si le refus coûte trop
    fr.refuse, fr.refused, fr.pass = {}, {}, 1
    fr.pc = 3
  end
  if fr.pc == 4 then
    fr.p, fr.why, fr.n = fr.got_p, fr.got_why, fr.got_n
    if fr.p then fr.pass, fr.pc = fr.pass + 1, 3 else fr.pc = 5 end
  end
  if fr.pc == 3 then
    local p = fr.p
    if fr.pass > Ch.CFG.refuse_passes or not (p.fallback and #p.fallback > 0) then
      fr.pc = 5
    else
      for _, x in ipairs(p.fallback) do
        local k = tostring(x.pr) .. ":" .. tostring(x.side)
        if not fr.refuse[k] then fr.refuse[k] = true; fr.refused[#fr.refused + 1] = x end
      end
      local sp = copy_spec(spec)
      sp.refuse = fr.refuse
      fr.pc = 4
      return push(J, { fn = "pushed", pc = 1, spec = sp })
    end
  end
  -- refus impossible (plan vide, ou replis encore là après les passes) : il coûte tout le champ
  local p, p0 = fr.p, fr.p0
  local after = (p and not (p.fallback and #p.fallback > 0)) and fr.n.fd or 0
  local keep, cost = Ch.refuse_keeps(fr.n0.fd, after)
  if not keep then
    p0.coffre_cost, p0.coffre_cols = cost, #p0.fallback
    fr.p, fr.why, fr.n = p0, fr.why0, fr.n0
    return "ret"
  end
  local refused = fr.refused
  table.sort(refused, function(a, b) if a.pr ~= b.pr then return a.pr < b.pr end return a.side < b.side end)
  p.refused, p.refuse_cost = refused, cost
  if p.frame.cols then
    for _, x in ipairs(refused) do
      local key = tostring(x.pr)
      p.frame.cols[key] = p.frame.cols[key] or {}
      p.frame.cols[key][tostring(x.side)] = { mode = "refusee" }
    end
  end
  return "ret"
end

--- « plan » : (revue-fonderie, 3/11) un cadre NEUF en colonne à combustible qui garde un coffre de tête ou refuse une colonne est aussi
--- calculé dans l'autre ordre des côtés du réseau du charbon ; le meilleur est gardé.
function RUN.plan(J, fr)
  local spec = fr.spec
  if fr.pc == 1 then fr.pc = 2 return push(J, { fn = "order", pc = 1, spec = spec }) end
  if fr.pc == 2 then
    local p, why = fr.got_p, fr.got_why
    fr.p, fr.why, fr.n = p, why, fr.got_n
    if not (Ch.CFG.both_orders and p and p.design == "colonne" and p.fuelled and not spec.frame and not spec.coal_first) then return "ret" end
    if fr.n.hc == 0 and not (p.refused and #p.refused > 0) then return "ret" end
    local sp = copy_spec(spec)
    sp.coal_first = -p.exit
    fr.pc = 3
    return push(J, { fn = "order", pc = 1, spec = sp })
  end
  local q, qwhy, p = fr.got_p, fr.got_why, fr.p
  if better_n(p, fr.n, q, fr.got_n) then
    q.order_swapped = { chests = fr.n.hc, drills = fr.n.fd }
    fr.p, fr.why, fr.n = q, qwhy, fr.got_n
  end
  return "ret"
end

--- Tuiles de minerai couvertes par les zones de minage des foreuses du CHAMP (la ligne de charbon exclue) : le compte de Cv.verify (elec).
--- (R1) relevé par morceaux dans le cadre « axes » : st = { i, ore, cov, n, ei } ; ore_set d'abord, puis les foreuses d'un plan.
local COV_CHUNK = 256
local function cov_run(st, spec, p, J)
  local o = spec.ore
  if not st.ore_done then
    while st.i <= #o - 1 do
      if J.left <= 0 then return false end
      local stop = math.min(#o - 1, st.i + 2 * (CTX_CHUNK - 1))
      for i = st.i, stop, 2 do st.ore[Ch.key(o[i], o[i + 1])] = true end
      Co.spend(J, (stop - st.i + 2) / 2 * Ch.UNITS.axis)
      st.i = stop + 2
    end
    st.ore_done = true
  end
  local r, ore, cov, ents = spec.drill.reach, st.ore, st.cov, p.ents
  while st.ei <= #ents do
    if J.left <= 0 then return false end
    local stop = math.min(#ents, st.ei + COV_CHUNK - 1)
    local nd = 0
    for i = st.ei, stop do
      local e = ents[i]
      if e.kind == "foreuse" and e.role ~= "charbon" then
        nd = nd + 1
        local w = e.w or e.size
        local h = e.h or e.size
        local x0, y0 = math.floor(e.x - w / 2 + 0.5), math.floor(e.y - h / 2 + 0.5)
        for x = x0 - r, x0 + e.size - 1 + r do
          for y = y0 - r, y0 + e.size - 1 + r do
            local k = Ch.key(x, y)
            if ore[k] and not cov[k] then cov[k] = true; st.n = st.n + 1 end
          end
        end
      end
    end
    Co.spend(J, (stop - st.ei + 1) * Ch.UNITS.ent + nd * Ch.UNITS.cov)
    st.ei = stop + 1
  end
  return true
end

--- « axes » : (lot CHAMP-COUVERTURE, R1) un cadre NEUF est planifié dans ses deux axes ; le plus de tuiles de minerai couvertes par les
--- zones des foreuses du champ l'emporte, l'axe long (le plan d'avant) à égalité. Un cadre figé (spec.frame, son axe est rejoué) ou un
--- axe imposé : le plan tel quel. Le plan de l'autre axe, gardé, porte axis_choice = { long, long_cov, cov } (journal).
function RUN.axes(J, fr)
  local spec = fr.spec
  if fr.pc == 1 then
    fr.pc = (spec.frame or spec.force_axis or not Ch.CFG.both_axes) and 9 or 2
    fr.w0 = J.used or 0
    return push(J, { fn = "plan", pc = 1, spec = spec })
  end
  if fr.pc == 9 then fr.p, fr.why, fr.n = fr.got_p, fr.got_why, fr.got_n return "ret" end
  if fr.pc == 2 then
    fr.p, fr.why, fr.n = fr.got_p, fr.got_why, fr.got_n
    -- sans plan (données, four, tapis : rien qui dépende de l'axe), rien à comparer
    if not fr.p then return "ret" end
    local sp = copy_spec(spec)
    sp.force_axis = (fr.p.axis == "x") and "y" or "x"
    -- travail permis à l'autre axe : axis_work fois celui de l'axe long
    local used = J.used or 0
    fr.limit = used + Ch.CFG.axis_work * (used - fr.w0)
    J.cap = { limit = fr.limit, depth = #J.stack }
    fr.pc = 3
    return push(J, { fn = "plan", pc = 1, spec = sp })
  end
  if fr.pc == 3 then
    J.cap = nil
    fr.q, fr.qwhy, fr.qn = fr.got_p, fr.got_why, fr.got_n
    -- abandonné en route, ou fini au-delà du travail permis (même décision d'un bloc ou en tranches) : l'axe long
    if fr.got_abort or (J.used or 0) > fr.limit then fr.q, fr.qwhy, fr.qn = nil, nil, nil end
    fr.got_abort = nil
    if not fr.q then fr.q, fr.qwhy, fr.qn = nil, nil, nil return "ret" end
    fr.cp = { i = 1, ore = {}, cov = {}, n = 0, ei = 1 }
    fr.pc = 4
  end
  if fr.pc == 4 then
    if not cov_run(fr.cp, spec, fr.p, J) then return "pause" end
    -- le relevé du minerai sert aux deux plans
    fr.cq = { i = fr.cp.i, ore = fr.cp.ore, ore_done = true, cov = {}, n = 0, ei = 1 }
    fr.cp.ore, fr.cp.cov = nil, nil
    fr.pc = 5
  end
  if not cov_run(fr.cq, spec, fr.q, J) then return "pause" end
  -- (décision du lead, 7/11) l'autre axe ne l'emporte que s'il couvre STRICTEMENT plus de minerai ; et jamais s'il est pire sur le
  -- réseau de poteaux (mesuré : le lac et la rivière de tests/champ_test.lua, « eau », laissent deux réseaux dans l'autre axe) ou sur
  -- les coffres de tête (mesuré : l'ellipse longue au charbon du sud de tests/champ_colonne_test.lua en garde 17 dans son axe court).
  -- À égalité ou en dessous : l'axe long, son plan identique entité par entité
  local pc_, qc_ = fr.cp.n, fr.cq.n
  local ps, qs = (fr.n and fr.n.split) and true or false, (fr.qn and fr.qn.split) and true or false
  local ph, qh = fr.n and fr.n.hc or 0, fr.qn and fr.qn.hc or 0
  -- (les coffres de tête ne se comptent qu'en colonne : dans le motif à coffres, chaque four a son coffre de combustible)
  local better = qc_ > pc_ and (ps or not qs) and (fr.p.design ~= "colonne" or qh <= ph)
  if better then
    fr.q.axis_choice = { long = fr.p.axis, long_cov = pc_, cov = qc_ }
    fr.p, fr.why, fr.n = fr.q, fr.qwhy, fr.qn
  end
  fr.q, fr.qwhy, fr.qn, fr.cp, fr.cq = nil, nil, nil, nil, nil
  return "ret"
end

--- Travail du plan d'un champ (voir l'en-tête de cette partie) : { stack, done, p, why }, données seules.
function Ch.plan_job(spec)
  return { stack = { { fn = "axes", pc = 1, spec = spec } }, done = false }
end

--- Fait avancer le travail d'au plus `budget` unités (nil : jusqu'au bout) ; rend vrai quand le plan est prêt (job.p, job.why).
--- Le pas s'arrête à la première borne de travail atteinte une fois le budget épuisé : un pas coûte le budget plus au plus une unité de
--- travail (une bande, une rangée, une colonne, une passe de relais, une place balayée, un état de l'A*).
function Ch.plan_step(J, budget)
  if J.done then return true end
  J.left = budget or math.huge
  local left0 = J.left
  while true do
    local fr = J.stack[#J.stack]
    local r = RUN[fr.fn](J, fr)
    if r == "pause" then J.spent, J.left = left0 - J.left, nil return false end
    if r == "abort" then
      -- (R1) l'essai de l'autre axe est abandonné : ses cadres sont retirés, le cadre « axes » reprend sans lui
      while #J.stack > J.cap.depth do J.stack[#J.stack] = nil end
      J.stack[#J.stack].got_abort = true
      J.cap = nil
    end
    if r == "ret" then
      J.stack[#J.stack] = nil
      local parent = J.stack[#J.stack]
      if parent then
        parent.got_p, parent.got_why, parent.got_n = fr.p, fr.why, fr.n
      else
        J.p, J.why, J.done, J.spent, J.left = fr.p, fr.why, true, left0 - J.left, nil
        return true
      end
    end
  end
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

--- Règle pure (lot FONDERIE, 3/11) : le refus des colonnes sans voie de charbon est-il gardé ? before / after : foreuses du champ avec le
--- coffre de tête / avec le refus. Rend (gardé, coût en % des foreuses perdues, arrondi).
function Ch.refuse_keeps(before, after, min)
  if before <= 0 then return true, 0 end
  local cost = math.floor((1 - after / before) * 100 + 0.5)
  return after >= (min or Ch.CFG.refuse_min) * before - 1e-9, cost
end

--- Coffres de tête (combustible) d'un plan.
function Ch.head_chests(p)
  local n = 0
  for _, e in ipairs(p and p.ents or {}) do if e.kind == "coffre" and e.role == "combustible" then n = n + 1 end end
  return n
end

--- Règle pure (revue-fonderie, 3/11) : des deux ordres des côtés du réseau du charbon, le meilleur plan : le moins de coffres de tête,
--- puis le plus de foreuses du champ ; à égalité, le premier (ordre habituel). Rend vrai si `b` est meilleur que `a`.
function Ch.better_order(a, b)
  if not b then return false end
  if not a then return true end
  local ca, cb = Ch.head_chests(a), Ch.head_chests(b)
  if ca ~= cb then return cb < ca end
  return Ch.field_drills(b) > Ch.field_drills(a)
end

--- Plan du champ. (revue-fonderie, 3/11 : 3 champs de fer sur environ 10 gardaient des coffres de tête, le côté calculé en second ne
--- croisant pas le tracé du premier sans souterrain ; rejoué hors jeu sur le cadre de scarlet, graine 20261020 : côté + « aucun chemin »,
--- 4 coffres de tête ; l'autre ordre : 0 coffre, une colonne refusée de l'autre côté, 13 % des foreuses) un cadre NEUF en colonne à
--- combustible qui garde un coffre de tête ou refuse une colonne est aussi calculé dans l'autre ordre des côtés ; le meilleur est gardé.
function Ch.plan(spec)
  local J = Ch.plan_job(spec)
  Ch.plan_step(J, nil)
  return J.p, J.why
end

return Ch
