--[[
  CHAMP-COUVERTURE (R2 + R3, accord du lead du 5/11) : foreuses posées d'abord, fonderie DÉCOUPLÉE. PUR : aucune API Factorio, aucun nom
  d'objet ; lu par shared/team/champ.lua (plan_once).

  Le DC (5/11) : « si jamais il y a un obstacle, il peut pas se faire et du coup, il ne place pas les foreuses [...] Alors qu'en soit, les
  foreuses en fait, bah on les place quand même [...] on se démerde pour après les envoyer dans une fonderie ». Mesuré hors jeu sur la
  règle d'essai-a (fo-logs/2026-11-05_CHAMP-COUVERTURE/mesure_essai-a.txt) : un disque r30 tombe de 80,9 % à 48,5 % (anneau de tourelles
  hors du minerai), 23,0 % (lacs au-delà des deux bouts), 0 % (eau aux bouts, ouverture) : le tapis d'un groupe devait être libre depuis
  le bout GLOBAL du champ, et sa fonderie tenir dans l'alignement exact de la bande, sinon le groupe entier était retiré.

  Règle (appliquée par plan_once seulement quand le chemin d'avant échoue ou coupe des foreuses : un champ propre garde son plan) :
    R2  le groupe sort au bout de SA bande (Cc.local_edge) : son tapis n'est libre que le long de sa bande ;
    R3  sa fonderie (colonne ou quai de coffres) se pose où il y a la place, au-delà du bout du champ de son côté, sur une rangée de
        bande voisine ou plus loin (Cc.candidates), et un TAPIS TRACÉ (Co.route, A* qui contourne, souterrains si débloqués) relie la
        sortie de la bande à l'entrée de la fonderie ; le tracé n'entre jamais dans le rectangle d'une bande (foreuses, tapis, poteaux).
  Déterminisme : candidats triés (coût, rangée, décalage), aucun `pairs`, aucune trigonométrie.
]]

local Co = require("shared.team.champ_colonne")
local Fd = require("shared.team.champ_fonderie")

local Cc = {}

Cc.CFG = {
  rows = 8,      -- rangées de bande essayées de part et d'autre de la bande (pas des bandes) pour la fonderie déplacée
  shift = 48,    -- tuiles de recul au plus au-delà du bout du champ
  tries = 6,     -- emplacements essayés par le tracé (A*), du moins coûteux au plus coûteux
  per_row = 2,   -- emplacements au plus par rangée parmi ces essais
  fast_layout = true, -- emprise de la fonderie décalée depuis l'origine (même résultat que la disposition refaite à chaque candidat)
  cap = 60000,   -- états développés au plus par tracé
  margin = 16,   -- tuiles autour de la sortie et de l'entrée où le tracé cherche
  trim = 2,      -- foreuses retirées au plus du bout de la bande quand sa sortie est bouchée (tourelle, eau juste après la bande)
}

--- Tuile de sortie de la bande du côté `side` : juste après sa foreuse la plus loin de ce côté (rangée du tapis), ou nil.
function Cc.local_edge(bd, side, size)
  local e
  for _, l in ipairs({ bd.n, bd.s }) do
    for _, a in ipairs(l) do
      local x = side > 0 and (a + size - 1) or a
      if not e or (side > 0 and x > e) or (side < 0 and x < e) then e = x end
    end
  end
  if not e then return nil end
  return e + side
end

--- La bande sans ses foreuses dont le corps atteint les k dernières largeurs de foreuse du côté `side` (k = 0 : la bande entière), et sa
--- tuile de sortie (Cc.local_edge) : (bande, sortie) ou (nil, nil) s'il ne reste rien. La bande rendue garde pr et b.
function Cc.trim(bd, side, size, k)
  local e0 = Cc.local_edge(bd, side, size)
  if not e0 then return nil, nil end
  if k == 0 then return bd, e0 end
  local lim = e0 - side * k * size
  local out = { pr = bd.pr, b = bd.b, n = {}, s = {}, on = bd.on, os = bd.os }
  for _, key in ipairs({ "n", "s" }) do
    for _, a in ipairs(bd[key]) do
      if (side > 0 and a + size - 1 < lim) or (side < 0 and a > lim) then out[key][#out[key] + 1] = a end
    end
  end
  local e = Cc.local_edge(out, side, size)
  if not e then return nil, nil end
  return out, e
end

--- Rectangles des bandes (des rangées de poteaux d'un bord à l'autre, entre la première et la dernière colonne de foreuse) : rend
--- forbid(u, v), vrai dans le rectangle d'une bande. Au-delà des foreuses, les rangées d'une bande sont libres pour un tracé : le poteau
--- d'une foreuse du bout trouve toujours sa place sur la rangée de poteaux AU-DESSUS des foreuses (elle est libre entre elles).
function Cc.rects(bands, size, reach, pitch)
  local R = {}
  for _, bd in ipairs(bands) do
    local lo, hi
    for _, l in ipairs({ bd.n, bd.s }) do
      for _, a in ipairs(l) do
        lo = (not lo or a < lo) and a or lo
        hi = (not hi or a + size - 1 > hi) and (a + size - 1) or hi
      end
    end
    if lo then R[#R + 1] = { u0 = lo, u1 = hi, v0 = bd.pr, v1 = bd.pr + pitch, pr = bd.pr } end
  end
  -- own = { pr, side, exit } : la bande du groupe tracé, libre au-delà de sa sortie (foreuses du bout retirées par Cc.trim, jamais posées)
  return function(u, v, own)
    for _, r in ipairs(R) do
      if u >= r.u0 and u <= r.u1 and v >= r.v0 and v <= r.v1 then
        local mine = own and r.pr == own.pr and ((own.side > 0 and u >= own.exit) or (own.side < 0 and u <= own.exit))
        if not mine then return true end
      end
    end
    return false
  end
end

--- Entités et emprise d'une fonderie à la rangée `row`, premier bord `s_edge` : (liste, longueur, info, tuiles { u, v }) ou nil.
--- Colonne (lot FONDERIE) : Co.layout ; quai de coffres ou fours à coffres : Fd.layout, avec son tapis (rangée `row`, longueur `len`).
local function layout(spec, colonne, row, side, s_edge, count, mode)
  local list, len, info
  if colonne then
    list, len, info = Co.layout(spec, row, side, s_edge, count, mode)
  else
    list, len = Fd.layout(spec, row, side, s_edge, count)
  end
  if not list then return nil end
  local tiles = {}
  for _, e in ipairs(list) do
    for u = e.u, e.u + (e.w or e.size) - 1 do for v = e.v, e.v + (e.h or e.size) - 1 do tiles[#tiles + 1] = { u, v } end end
  end
  if not colonne then
    for k = 0, len - 1 do tiles[#tiles + 1] = { s_edge + side * k, row } end
  end
  return list, len, info, tiles
end
Cc.layout = layout

--- Emplacements de fonderie essayés pour un groupe de la bande `b`, du côté `side` (bout du champ `edge`) : rangées de bande b + j × pas
--- (|j| <= CFG.rows, rangées déjà prises de ce côté exclues), recul t (0..CFG.shift) ; triés par coût |rangée - b| + t, puis rangée, puis t.
function Cc.candidates(b, side, edge, gap, pitch, used_rows)
  local out = {}
  for j = -Cc.CFG.rows, Cc.CFG.rows do
    local r = b + j * pitch
    if not used_rows[r] then
      for t = 0, Cc.CFG.shift do
        out[#out + 1] = { row = r, t = t, s_edge = edge + side * (gap + 1 + t), cost = math.abs(r - b) + t }
      end
    end
  end
  table.sort(out, function(x, y)
    if x.cost ~= y.cost then return x.cost < y.cost end
    if x.row ~= y.row then return x.row < y.row end
    return x.t < y.t
  end)
  return out
end

--- Fonderie déplacée et tapis tracé d'un groupe. a = { spec, colonne, mode, b (rangée du tapis de la bande), side, edge (bout du champ de
--- ce côté), exit (tuile de sortie de la bande, u), count, gap, pitch, used_rows, free(u, v), is_ore(u, v), forbid(u, v, own_b, side),
--- ug (portée des souterrains ou nil), span(u, v), own = { pr, side, exit } (la bande du groupe : libre au-delà de sa sortie), beyond (u ou
--- nil : la fonderie commence au-delà, plan refait par plan_pushed) }. Rend { list, len, info, row, s_edge, route = { { u, v, d, kind, ug } } }
--- ou nil, raison.
function Cc.place_routed(a)
  local spec = a.spec
  local fits = {}
  -- (coût, 7/11) emprise de la fonderie calculée UNE fois, à l'origine (rangée 0, premier bord 0) : Co.layout et Fd.layout ne dépendent de
  -- la place que par translation (u = s_edge + side × colonne, v = rangée + décalage ; égalité contrôlée par tests/champ_couverture_test.lua).
  -- Chaque candidat relit ces tuiles décalées et s'arrête à la première prise ; seule une place retenue refait la vraie disposition. Mesuré
  -- avant : jusqu'à 4 606 dispositions par plan (r30, eau aux bouts, ouverture de 5 : 1,1 s sur 2,1 s).
  local btiles = select(4, layout(spec, a.colonne, 0, a.side, 0, a.count, a.mode))
  for pass = 1, 2 do
    if #fits == 0 and btiles then
      local per_row = {}
      for _, c in ipairs(Cc.candidates(a.b, a.side, a.edge, a.gap, a.pitch, a.used_rows)) do
        if #fits >= Cc.CFG.tries then break end
        -- a.beyond (plan refait, dérivation du charbon coupée en u = a.beyond) : la fonderie commence au-delà de cette tuile
        local far_enough = not a.beyond or (a.side > 0 and c.s_edge > a.beyond) or (a.side < 0 and c.s_edge < a.beyond)
        -- au plus CFG.per_row emplacements par rangée : les essais du tracé couvrent plusieurs rangées (derrière un lac, toutes les places
        -- les moins chères d'une même rangée échouent ensemble)
        if far_enough and (per_row[c.row] or 0) < Cc.CFG.per_row then
          -- l'entrée de la fonderie (une tuile avant son premier bord) et son emprise, libres (passe 1 : hors du minerai)
          local entry = { u = c.s_edge - a.side, v = c.row }
          local ok = a.free(entry.u, entry.v) and not a.forbid(entry.u, entry.v)
          -- (Cc.CFG.fast_layout = false : la disposition refaite à chaque candidat, comme avant ; le test compare les deux plans)
          local tl, su, sv = btiles, c.s_edge, c.row
          if not Cc.CFG.fast_layout then tl, su, sv = select(4, layout(spec, a.colonne, c.row, a.side, c.s_edge, a.count, a.mode)), 0, 0 end
          if ok then
            for _, t in ipairs(tl) do
              local u, v = t[1] + su, t[2] + sv
              if not a.free(u, v) or a.forbid(u, v) or (pass == 1 and a.is_ore(u, v)) then ok = false break end
            end
          end
          if ok then
            local list, len, info, tiles = layout(spec, a.colonne, c.row, a.side, c.s_edge, a.count, a.mode)
            fits[#fits + 1] = { c = c, list = list, len = len, info = info, tiles = tiles, entry = entry }
            per_row[c.row] = (per_row[c.row] or 0) + 1
          end
        end
      end
    end
  end
  if #fits == 0 then return nil, "aucune place pour la fonderie" end
  local D = (a.side > 0) and 2 or 4 -- index de Co.D4 : le tapis avance le long de u, dans le sens du groupe
  local why = "trace vers la fonderie : aucun chemin"
  for _, ft in ipairs(fits) do
    local foot = {}
    for _, t in ipairs(ft.tiles) do foot[Co.tk(t[1], t[2])] = true end
    local function rfree(u, v)
      if foot[Co.tk(u, v)] then return false end
      return a.free(u, v) and not a.forbid(u, v, a.own)
    end
    local s = { u = a.exit, v = a.b }
    local box = { u0 = math.min(s.u, ft.entry.u) - Cc.CFG.margin, u1 = math.max(s.u, ft.entry.u) + Cc.CFG.margin,
      v0 = math.min(s.v, ft.entry.v) - Cc.CFG.margin, v1 = math.max(s.v, ft.entry.v) + Cc.CFG.margin }
    local route, w = Co.route(s, D, ft.entry, D, rfree, a.span, a.ug, box, Cc.CFG.cap, nil)
    -- l'A* suit des états (tuile, sens) : un tracé peut repasser sur une tuile qu'il occupe déjà (entrée de souterrain sur son propre
    -- tapis, mesuré sur le disque entre deux lacs) ; un tel tracé est refusé
    if route then
      local seen = {}
      for _, t in ipairs(route) do
        local k = Co.tk(t.u, t.v)
        if seen[k] then route, w = nil, "le trace repasse sur lui-meme" break end
        seen[k] = true
      end
    end
    local poles
    if route then
      local on_route = {}
      for _, t in ipairs(route) do on_route[Co.tk(t.u, t.v)] = true end
      -- (jamais sur la rangée de poteaux d'une AUTRE bande : la bande bâtie seule dépendrait d'une autre. Entre le bout du champ et un
      -- lac, un couloir d'une tuile n'a donc aucune place : mesuré, 17 tuiles du tracé sans voisine libre sur le disque entre deux lacs,
      -- et les rangées de poteaux sont à 8 tuiles pour un fil de 7,5 ; le groupe n'est pas posé)
      poles = Cc.link_poles(route, ft.list, function(u, v) return not on_route[Co.tk(u, v)] and rfree(u, v) end, spec.pole.wire)
      if not poles then route, w = nil, "pas de poteaux le long du trace" end
    end
    if route then
      return { list = ft.list, len = ft.len, info = ft.info, row = ft.c.row, s_edge = ft.c.s_edge, route = route, tiles = ft.tiles, poles = poles }
    end
    why = "trace vers la fonderie : " .. tostring(w)
  end
  return nil, why
end

--- Poteaux de LIAISON le long d'un tapis tracé (lot CHAMP-COUVERTURE) : la fonderie déplacée est reliée au réseau de SA bande par ses
--- propres poteaux, posés avec la bande. Sans eux, une bande bâtie seule (la migration bâtit bande par bande) a sa fonderie dans un
--- second réseau, sans courant (mesuré : bandes -21 et 11 de la rivière sans souterrain, tests/champ_colonne_test.lua, 2 réseaux).
--- route : tuiles du tracé (la première est la sortie de la bande, à 4 tuiles des rangées de poteaux de la bande, au bout de ses foreuses) ;
--- list : pièces de la fonderie (ses poteaux sont le but) ; free(u, v) : tuile libre pour un poteau ; wire : portée des fils.
--- Glouton : un poteau à côté de la sortie, puis, le long du tracé, le plus loin encore à portée du précédent, jusqu'à portée d'un poteau
--- de la fonderie. Voisins essayés dans un ordre fixe. Rend { { u, v } } (vide si la sortie est déjà à portée) ou nil.
local NEAR = { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 },
  { 0, -2 }, { 0, 2 }, { -2, 0 }, { 2, 0 } }
function Cc.link_poles(route, list, free, wire)
  local w2 = wire * wire + 1e-6
  local goal = {}
  for _, e in ipairs(list) do if e.kind == "poteau" then goal[#goal + 1] = { e.u, e.v } end end
  if #goal == 0 then return nil end
  local function reaches(p)
    for _, g in ipairs(goal) do if (p[1] - g[1]) ^ 2 + (p[2] - g[2]) ^ 2 <= w2 then return true end end
    return false
  end
  local taken = {}
  local function spot(i, prev)
    local t = route[i]
    for _, o in ipairs(NEAR) do
      local u, v = t.u + o[1], t.v + o[2]
      if not taken[Co.tk(u, v)] and free(u, v) and (not prev or (u - prev[1]) ^ 2 + (v - prev[2]) ^ 2 <= w2) then return { u, v } end
    end
    return nil
  end
  local out = {}
  local prev = spot(1, nil)
  if not prev then return nil end
  out[1] = prev
  taken[Co.tk(prev[1], prev[2])] = true
  local i = 1
  while not reaches(prev) do
    local best, bi
    for j = #route, i + 1, -1 do
      if not best then
        local p = spot(j, prev)
        if p then best, bi = p, j end
      end
    end
    if not best then return nil end
    out[#out + 1] = best
    taken[Co.tk(best[1], best[2])] = true
    prev, i = best, bi
    if #out > #route + 1 then return nil end
  end
  return out
end

return Cc
