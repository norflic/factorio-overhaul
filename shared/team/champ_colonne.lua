--[[
  FONDERIE (lot FONDERIE, retour du DC du 2/11 au soir) : COLONNE de fours nourrie par TAPIS, combustible compris. PUR : aucune API
  Factorio, aucun nom d'objet (tailles, portées, débits et disponibilités arrivent en DONNÉES) ; lu par shared/team/champ.lua.

  Le DC : « il faut tout le temps remplir n/2 coffres de charbons + n/2 coffres de cuivre pour n fours [...] les IA "oublient" de
  remplir les coffres et la fonderie entière cesse de fonctionner » ; « Regardez les paterns en ligne » ; « Faites attention aux
  passages sous-terrain et aux splitters (si pas recherchés) ».

  Motif retenu (colonne classique de Factorio 1.1 : une voie de minerai, une voie de charbon, un bras par four qui prend sur les deux
  voies, plaques sur un tapis de sortie). Lot COLONNE-DOUBLE (DC, 11/11 : « deux rangées de fours qui se déversent sur une ligne de
  sortie centrale, le minerai par le tapis collecteur continu ») : la colonne est DOUBLE, deux demi-colonnes face à face qui partagent
  la ligne de plaques ; chaque rangée est nourrie par le collecteur d'une bande (la bande d'en face, Co.half : miroir, son collecteur
  décalé de `jog` rangées en col 0). Une colonne double et ses deux voies de charbon tiennent dans deux pas de bande (2 fs + 8 < 2 pas).
  Demi-colonne (rangées en sf ; la demi-colonne d'en face a sf opposé, sa rangée « fs + 3 » tombe sur la même ligne de plaques) :
      col :  0   1   2 ...                              K bras de quai
      b-sf   .  [c↓] [c←][c←][c←] ...                   voie de charbon (vient du tronc, au bout de la colonne)
      b     [↑] [H→] [→][→][→] ...                      tête H : minerai chargé par le côté fours, charbon par l'autre
      b+sf  [→] [↑]  [b][P][b][ ] ...                   bras d'entrée (prennent sur le tapis), poteaux entre eux
      ...            [four][four] ...                   fours (fs × fs)
      +fs+2          [b][P][b][ ] ... [b][b][P][b][b]   bras de sortie (four -> tapis), puis bras du quai (tapis -> coffre)
      +fs+3          [→][→][→][→] ... [→][→][→][→][→]   tapis de plaques, jusqu'au quai
      +fs+1 (quai)                     [c][c] [c][c]    coffres de sortie côte à côte, au bout (un seul arrêt de collecte)
  (repère : col le long de u depuis s_edge dans le sens `side` ; sf = Co.SF, côté des fours en v). Le minerai arrive par le tapis de
  la bande (deux voies), fait un détour d'une tuile et se charge par le CÔTÉ sur une seule voie de la tête : le groupe de foreuses
  ne dépasse pas une voie (shared/team/champ.lua). Le charbon arrive par l'autre côté sur l'autre voie. Four électrique : ni tête ni
  charbon, le tapis de la bande continue tout droit (deux voies).

  Charbon (Co.network) : une LIGNE de foreuses électriques sur le gisement de charbon le plus proche (Co.coal_line), un tapis tracé
  jusqu'au TRONC (Co.route, A* : souterrains seulement si débloqués, pour passer sous un obstacle ; sinon contournement), le tronc
  derrière le bout des colonnes, une dérivation par colonne : RÉPARTITEUR si débloqué, sinon BRAS tapis -> tapis. Repli quand aucun
  charbon n'est joignable : un coffre de tête par colonne (mode « coffre », un seul coffre à garnir par colonne, pas un par deux fours).
  Déterminisme : listes triées, entiers, tas à départage par clé, aucun `pairs`, aucune trigonométrie.
]]

local Co = {}

Co.SF = -1             -- côté des fours en travers (v) : vers la rangée de poteaux `pr` de la bande
Co.PICKUP = 0.85       -- un bras qui prend sur un tapis (shared/team/modules.lua, M.BELT_PICKUP)
Co.FUEL = 0.0225       -- charbon/s d'un four sans donnée (90 kW, 4 MJ)
Co.MIN_COAL = 3        -- tuiles de charbon au moins dans la zone d'une foreuse de la ligne
Co.WINDOW = 24         -- demi-côté de la fenêtre du gisement de charbon lue autour de la tuile la plus proche du tronc
Co.UG_COST = 3         -- surcoût d'une paire de souterrains (préférés seulement pour passer un obstacle ou couper un détour)
Co.SOFT_COST = 8       -- surcoût d'un tapis posé sur un arbre ou un rocher (lot-20261020, emerald : 2 arbres de marais jamais coupés ont
                       -- bloqué 2 h le chantier d'une bande ; le tracé contourne la forêt, ou passe dessous par souterrain)
Co.ROUTE_CAP = 200000  -- états développés au plus par tracé
Co.ROUTE_STATES = 12000 -- 0.7.107 : plafond d états du tracé de charbon d une colonne (48 x ROUTE_MAX ; 5000 perdait 10 tracés valides de champ_colonne_test ; un échec coûtait 200000 états)
Co.ROUTE_W = 1.2       -- A* pondéré (heuristique × 1,2) : un tracé de 300 tuiles reste sous le plafond (lot2-20261020 : charbon à ~190 tuiles)
Co.DEPOSITS = 3        -- gisements de charbon essayés (le plus proche peut être couvert par les paires thermiques de l'équipe)
Co.ROUTE_MAX = 250     -- tuiles de tracé au plus ; au-delà, coffre de tête. (Proposé à ~120 le 3/11 ; mesuré hors jeu : un charbon à 60-70 tuiles
                       -- du champ donne des tracés de 136 à 207 tuiles, le tracé contournant le champ et ses colonnes : 120 renvoyait presque
                       -- tout au coffre de tête. Ce qui faisait attendre les bandes au lot3 était le charbon à 320 tuiles posé par la bande.)
Co.ROUTE_MARGIN = 12   -- tuiles autour de la boîte départ, arrivée et zone interdite
Co.TRUNK_TRIES = 8     -- colonnes de tronc essayées au-delà du bout des colonnes
Co.EXT = 3             -- (s41 sortie-bus) tuiles de trop-plein au-delà du quai : le moins qui donne deux tuiles avec un tapis derrière et devant
Co.COAL_MARGIN = 1.25  -- la ligne extrait au moins 1,25 × le charbon brûlé (banc fonderie-banc, 3/11)
-- (banc-2, 3/11, mesuré colonne par colonne) une ligne au plus juste laisse les DERNIÈRES colonnes du tronc sans charbon tant que les
-- dérivations d'amont prennent plus que leur besoin pour remplir leurs voies : la ligne couvre donc ce que les dérivations PEUVENT
-- prendre, (colonnes - 1) × débit d'un bras sur tapis + le besoin de la dernière (servie par le bout du tronc)

local D4 = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } } -- N, E, S, O
local function didx(du, dv) for i, d in ipairs(D4) do if d[1] == du and d[2] == dv then return i end end return nil end
Co.didx = didx
Co.D4 = D4

---------------------------------------------------------------------------------------------------
-- 1. La colonne
---------------------------------------------------------------------------------------------------
--- Rangées d'une demi-colonne, en décalage de v depuis son tapis de minerai b (sf : côté des fours, Co.SF par défaut).
function Co.rows(fs, sf)
  sf = sf or Co.SF
  return { ins = sf, f_lo = math.min(2 * sf, (fs + 1) * sf), out = (fs + 2) * sf, obelt = (fs + 3) * sf, chest = (fs + 1) * sf, coal = -sf }
end

--- Charbon/s d'un four.
function Co.fuel_rate(f) return (f and f.fuel) and (f.fuel_rate or Co.FUEL) or 0 end

--- Coffres du quai : plaques/s de `count` fours sur ce qu'un bras prend sur un tapis.
function Co.bay_size(spec, count)
  local f = spec.furnace
  local plates = count * f.rate * (f.yield or 1)
  local cap = ((spec.inserter and spec.inserter.rate) or 0.83) * Co.PICKUP
  return math.max(1, math.ceil(plates / cap - 1e-9)), plates
end

--- Lot COLONNE-DOUBLE : forme d'une demi-colonne de colonne double pour un pas de bande `pitch`. facing : la demi-colonne d'en face
--- (miroir ; jog : rangées, en v, du collecteur de la bande à la rangée de son minerai, pour que les deux demi-colonnes partagent la ligne
--- de plaques). lead = 1 : la tête des deux demi-colonnes commence en col 1 (col 0 : le collecteur, décalé ou tout droit), leurs fours
--- face à face. nil quand la colonne double et ses deux voies de charbon ne tiennent pas dans deux pas de bande (demi-colonne seule).
function Co.half(spec, pitch, facing)
  local span = 2 * spec.furnace.size + 6 -- d'une rangée de minerai à l'autre : bras, four, bras, plaques, bras, four, bras
  if span + 2 >= 2 * pitch then return nil end
  if facing then return { mirror = true, jog = (span - pitch) * Co.SF, lead = 1 } end
  return { mirror = false, jog = 0, lead = 1 }
end

--- La bande d'index `i` (pas de bande depuis l'origine du cadre) porte-t-elle la demi-colonne d'en face ? Paires (i, i - Co.SF) : la
--- demi-colonne de la bande i - Co.SF a ses fours du côté Co.SF, vers celle de i.
function Co.is_facing(i) return i % 2 == ((Co.SF < 0) and 0 or 1) end

--- Entités de la demi-colonne { kind, u, v, size, du, dv, role }, longueur et info { far, head_pole, need, plates, bay, mode }.
--- mode : "voie" (charbon par tapis depuis le tronc), "coffre" (coffre de tête), nil pour un four électrique. half : Co.half (demi-colonne
--- d'en face : fours du côté -Co.SF, minerai décalé de half.jog depuis le collecteur b, tête une colonne plus loin), ou nil.
function Co.layout(spec, b, side, s_edge, count, mode, half, ext)
  local f = spec.furnace
  local sf = (half and half.mirror) and -Co.SF or Co.SF
  local fs, R = f.size, spec.pole.reach
  local jog = (half and half.jog) or 0
  local lead = (half and half.lead) or 0 -- colonne 0 : le collecteur (passe de la rangée de la bande à celle du minerai si jog)
  local b_band = b
  b = b + jog
  local rw = Co.rows(fs, sf)
  local fuel = f.fuel
  if fuel and mode == "coffre" and R < 2 then return nil end
  local ents = {}
  local function U(col) return s_edge + side * col end
  local function put(kind, col, row, size, du, dv, role)
    local ua, ub = U(col), U(col + size - 1)
    ents[#ents + 1] = { kind = kind, u = math.min(ua, ub), v = row, size = size, du = du, dv = dv, role = role, col = col }
  end
  local b_ins, b_out, b_ob, b_ch, b_coal = b + rw.ins, b + rw.out, b + rw.obelt, b + rw.chest, b + rw.coal
  local c0 = 2 + lead
  local busy_in, busy_out = {}, {}
  local belt0 = lead
  if lead > 0 then
    if jog ~= 0 then
      local dj = jog > 0 and 1 or -1
      for v = b_band, b - dj, dj do
        put("tapis", 0, v, 1, 0, dj, "tete")
        if v == b_ins then busy_in[0] = true end
        if v == b_out then busy_out[0] = true end
      end
    end
    put("tapis", 0, b, 1, side, 0, "tete")
  end
  local h = lead -- première colonne de la tête
  if fuel then
    put("tapis", h, b, 1, 0, sf, "tete")              -- le minerai quitte la rangée du tapis...
    put("tapis", h, b_ins, 1, side, 0, "tete")        -- ... avance d'une tuile...
    put("tapis", h + 1, b_ins, 1, 0, -sf, "tete")     -- ... et se charge par le côté des fours sur la tête H
    busy_in[h], busy_in[h + 1] = true, true
    put("tapis", h + 1, b_coal, 1, 0, sf, "charbon")  -- le charbon se charge par l'autre côté
    if mode == "coffre" then
      put("tapis", h + 2, b_coal, 1, -side, 0, "charbon")
      put("bras", h + 3, b_coal, 1, side, 0, "charbon")        -- prend au coffre (col h + 4), pose sur le tapis (col h + 2)
      put("coffre", h + 4, b_coal, 1, 0, 0, "combustible")
    end
    belt0 = h + 1
  end
  local need_in = {}
  if fuel and mode == "coffre" then need_in[#need_in + 1] = h + 3 end
  local last_ins = c0
  for k = 0, count - 1 do
    local c = c0 + k * fs
    put("four", c, b + rw.f_lo, fs, 0, 0, nil)
    put("bras", c, b_ins, 1, 0, -sf, nil)    -- prend sur le tapis b, pose dans le four
    put("bras", c, b_out, 1, 0, -sf, nil)    -- prend dans le four, pose sur le tapis de plaques
    busy_in[c], busy_out[c] = true, true
    need_in[#need_in + 1] = c
    last_ins = c
  end
  table.sort(need_in)
  for col = belt0, last_ins do put("tapis", col, b, 1, side, 0, "colonne") end
  -- poteaux : couverture gloutonne d'une rangée (le plus loin possible qui couvre encore le bras), sur les tuiles libres
  local poles = {}
  local function greedy(row, needs, lo, hi, busy)
    local last
    for _, c in ipairs(needs) do
      if not last or math.abs(c - last) > R then
        local p
        for q = math.min(c + R, hi), math.max(c - R, lo), -1 do if not p and not busy[q] then p = q end end
        if not p then return nil end
        busy[p] = true
        poles[#poles + 1] = { col = p, row = row }
        last = p
      end
    end
    return last
  end
  local f_end = c0 + count * fs - 1
  if greedy(b_ins, need_in, fuel and (h + 2) or 0, f_end, busy_in) == nil and #need_in > 0 then return nil end
  local need_out = {}
  for k = 0, count - 1 do need_out[#need_out + 1] = c0 + k * fs end
  local lastp = greedy(b_out, need_out, 0, f_end, busy_out)
  if lastp == nil then return nil end
  -- quai : K bras (tapis -> coffre) au-delà du dernier four, un poteau dès qu'un bras ne serait plus couvert
  local K, plates = Co.bay_size(spec, count)
  local col, placed, last_unit = f_end + 1, 0, f_end
  local function unit(cc)
    put("bras", cc, b_out, 1, 0, sf, nil)        -- prend sur le tapis de plaques, pose dans le coffre
    put("coffre", cc, b_ch, 1, 0, 0, "sortie")
    placed, last_unit = placed + 1, cc
  end
  while placed < K do
    if col - lastp > R then
      local p = col + math.min(R, K - placed)
      for cc = col, p - 1 do unit(cc) end
      poles[#poles + 1] = { col = p, row = b_out }
      lastp, col = p, p + 1
    else
      unit(col)
      col = col + 1
    end
  end
  for cc = c0, last_unit do put("tapis", cc, b_ob, 1, side, 0, "sortie") end
  local far = last_unit
  -- s41 sortie-bus : trop-plein du quai. `ext` tuiles droites de la ligne de plaques au-delà du dernier bras du quai : elles ne se
  -- remplissent que les coffres pleins (surplus vrai). `piq` : tuile avec un tapis derrière ET devant (source de piquage déclarée)
  if ext and ext > 0 then
    for cc = last_unit + 1, last_unit + ext do
      put("tapis", cc, b_ob, 1, side, 0, "sortie")
      ents[#ents].piq = (cc < last_unit + ext) or nil
      ents[#ents].fin = (cc == last_unit + ext) or nil -- s42 bus-direct : bout de la ligne de plaques (départ d'une ligne directe vers le tronc du mall)
    end
    far = last_unit + ext
  end
  local head_pole
  -- poteau de liaison de tête, col 0 de la rangée du charbon (libre dans tous les modes) : la rangée de poteaux de la bande du côté
  -- opposé aux fours le rejoint (sans lui, ses foreuses n'ont de courant que par les relais du plan ENTIER, jamais posés bande par bande)
  poles[#poles + 1] = { col = h, row = b_coal }
  for _, p in ipairs(poles) do
    put("poteau", p.col, p.row, 1, 0, 0, nil)
    far = math.max(far, p.col)
    if p.row == b_out and (not head_pole or p.col < head_pole) then head_pole = p.col end
  end
  if fuel and mode ~= "coffre" then
    for cc = h + 2, far do put("tapis", cc, b_coal, 1, -side, 0, "charbon") end
  end
  local info = { far = far, head_pole = head_pole or 0, need = count * Co.fuel_rate(f), plates = plates, bay = K, mode = fuel and mode or nil,
    b_coal = b_coal, b_link = b_ins, ext = (ext and ext > 0) and ext or nil }
  return ents, far + 1, info
end

--- Colonne d'un groupe : (entités, longueur, s_edge, nombre, info) ou nil. Même contrat que Fd.place (shared/team/champ_fonderie.lua) ;
--- `fixed` = { s_edge, count } rejoue la place du cadre figé (bande seule) sans chercher. half : Co.half ou nil. shared(u, v, e) : la tuile
--- porte déjà la ligne de plaques de la demi-colonne d'en face, dans le sens de e (lot COLONNE-DOUBLE : la ligne centrale est posée une
--- fois ; ces tuiles ne sont pas rendues).
function Co.place(spec, b, side, edge, count, gap, shift, free, is_ore, mode, fixed, half, shared)
  local function common(e) return shared ~= nil and e.kind == "tapis" and e.role == "sortie" and shared(e.u, e.v, e) end
  -- F500 (directive du DC du 10/11, 22 h) : aucune entité de la colonne sur une tuile de ressource (`is_ore` = le minerai visé ET les
  -- autres ressources) ; plus de seconde passe qui acceptait le minerai. Lot DECOUPLAGE : la colonne d'un cadre figé (`fixed`) aussi.
  local function fits(s_edge, list)
    for u = edge + side, s_edge - side, side do if not free(u, b) then return false end end
    for _, e in ipairs(list) do
      if not common(e) then
        for u = e.u, e.u + e.size - 1 do
          for v = e.v, e.v + e.size - 1 do if not free(u, v) or is_ore(u, v) then return false end end
        end
      end
    end
    return true
  end
  local function own(list)
    local out = {}
    for _, e in ipairs(list) do if not common(e) then out[#out + 1] = e end end
    return out
  end
  if fixed then
    -- s41 sortie-bus : le cadre figé rejoue SA forme (fixed.ext ; cadres d'avant le lot : sans trop-plein, plan inchangé)
    local list, len, info = Co.layout(spec, b, side, fixed.s_edge, fixed.count, mode, half, fixed.ext)
    if list and fits(fixed.s_edge, list) then return own(list), len, fixed.s_edge, fixed.count, info end
    return nil
  end
  for t = 0, shift do
    local s_edge = edge + side * (gap + 1 + t)
    local list, len, info = Co.layout(spec, b, side, s_edge, count, mode, half)
    if list and fits(s_edge, list) then
      -- s41 sortie-bus : même place qu'avant le lot ; le trop-plein ne s'ajoute que si ses tuiles tiennent aussi (sinon plan identique)
      local l2, len2, info2 = Co.layout(spec, b, side, s_edge, count, mode, half, Co.EXT)
      if l2 and fits(s_edge, l2) then return own(l2), len2, s_edge, count, info2 end
      return own(list), len, s_edge, count, info
    end
  end
  return nil
end

Co.AWAY_ROUTES = 8      -- (lot FONDERIE-BOUT) tracés essayés au plus pour une colonne ailleurs
Co.AWAY_CAP = 20000     -- états développés au plus par tracé d'une colonne ailleurs

--- Lot FONDERIE-BOUT (attendu du DC, 11/11 : la BOX_FONDERIE sur sol neutre, alimentée DIRECTEMENT par le convoyeur collecteur continu
--- qui sort de la box de minage ; aucun relais coffre -> coffre ni bras intermédiaire). Colonne AILLEURS au bout d'un tapis collecteur
--- seul (groupe g.bare de shared/team/champ.lua) : la même colonne que Co.place (Co.layout, même sens `side`), sur la rangée b + k
--- (|k| <= o.rows), tête à t tuiles (0..o.shift) au-delà de `from`, places essayées de la plus proche à la plus lointaine (|k| + t) ;
--- emprise entière libre et hors ressource (F500) ; puis le tapis de `from` (tuile devant la sortie du collecteur, où le minerai entre dans
--- le sens `side`) jusqu'à la tuile avant la tête, tracé par Co.route (souterrains au croisement d'un autre flux si o.ug).
--- o = { shift, rows, ug, span, box = { u0, v0, u1, v1 } (tuiles lues ; nil : sans borne), tcost }.
--- Rend { list, len, s_edge, b, count, info, route } ou nil, raison.
function Co.away(spec, from, side, count, mode, free, is_ore, o)
  local box = o.box
  local function inb(u, v) return not box or (u >= box.u0 and u <= box.u1 and v >= box.v0 and v <= box.v1) end
  -- la colonne ne dépend de (s_edge, b) que par translation : calculée une fois en (0, 0), ses tuiles décalées pour chaque place
  local base, len, info0 = Co.layout(spec, 0, side, 0, count, mode)
  if not base then return nil, "colonne impossible" end
  local rel = {}
  for _, e in ipairs(base) do
    for u = e.u, e.u + e.size - 1 do for v = e.v, e.v + e.size - 1 do rel[#rel + 1] = { u, v } end end
  end
  local memo = {} -- tuile -> sol neutre libre (lu une fois par appel ; rien n'est pris pendant la recherche)
  local function neutral(u, v)
    local k = Co.tk(u, v)
    local m = memo[k]
    if m == nil then m = inb(u, v) and free(u, v) and not is_ore(u, v); memo[k] = m end
    return m
  end
  local cands = {}
  for k = -o.rows, o.rows do
    for t = 0, o.shift do cands[#cands + 1] = { k = k, t = t, d = math.abs(k) + t } end
  end
  table.sort(cands, function(a, b)
    if a.d ~= b.d then return a.d < b.d end
    if math.abs(a.k) ~= math.abs(b.k) then return math.abs(a.k) < math.abs(b.k) end
    if a.k ~= b.k then return a.k < b.k end
    return a.t < b.t
  end)
  local routes, why = 0, "aucune place sur le sol neutre"
  for _, cd in ipairs(cands) do
    if routes >= Co.AWAY_ROUTES then break end
    local b2, s_edge = from.v + cd.k, from.u + side * (cd.t + 1)
    local fine = true
    for _, r in ipairs(rel) do
      if not neutral(s_edge + r[1], b2 + r[2]) then fine = false break end
    end
    local t = { u = s_edge - side, v = b2 }
    if fine then
      local mine = {}
      for _, r in ipairs(rel) do mine[Co.tk(s_edge + r[1], b2 + r[2])] = true end
      if not mine[Co.tk(t.u, t.v)] then
        routes = routes + 1
        local function rfree(u, v) return inb(u, v) and not mine[Co.tk(u, v)] and free(u, v) end
        local rb = box or { u0 = math.min(from.u, t.u) - Co.ROUTE_MARGIN, u1 = math.max(from.u, t.u) + Co.ROUTE_MARGIN,
          v0 = math.min(from.v, t.v) - Co.ROUTE_MARGIN, v1 = math.max(from.v, t.v) + Co.ROUTE_MARGIN }
        local sd = didx(side, 0)
        local route, rwhy = Co.route({ u = from.u, v = from.v }, sd, t, sd, rfree, o.span, o.ug, rb, Co.AWAY_CAP, o.tcost)
        if route then
          local list = {}
          for _, e in ipairs(base) do
            list[#list + 1] = { kind = e.kind, u = e.u + s_edge, v = e.v + b2, size = e.size, du = e.du, dv = e.dv, role = e.role, col = e.col }
          end
          local info = { far = info0.far, head_pole = info0.head_pole, need = info0.need, plates = info0.plates, bay = info0.bay,
            mode = info0.mode, b_coal = info0.b_coal + b2, b_link = info0.b_link + b2 }
          return { list = list, len = len, s_edge = s_edge, b = b2, count = count, info = info, route = route }
        end
        why = "trace : " .. tostring(rwhy)
      end
    end
  end
  return nil, why
end

---------------------------------------------------------------------------------------------------
-- 2. Tracé d'un tapis avec souterrains (A* sur (tuile, sens d'arrivée, « tout droit imposé »))
---------------------------------------------------------------------------------------------------

local function tk(u, v) return (u + 50000) * 100000 + (v + 50000) end
Co.tk = tk

--- Lot PERF3 (gels de 1 à 3 s de la partie du DC : « trace du charbon : aucun chemin ») : sans chemin, l'A* ci-dessous développe TOUS
--- les états (tuile, sens, tout droit imposé) atteignables depuis `s` avant de conclure ; une sortie de ligne enfermée par ses foreuses,
--- ou une tête de tronc enfermée, coûte ainsi toute la boîte (2,8 s hors jeu pour 300 × 120 tuiles). Preuve RAPIDE et EXACTE de
--- l'impossibilité, sur un graphe de TUILES qui contient celui de l'A* (mêmes conditions de pose, sans les sens ni le passage sous
--- les souterrains posés : il a plus d'arêtes, jamais moins) : deux remplissages bornés, depuis `s` (arêtes de l'A*) et depuis `t`
--- (arêtes inversées) ; si l'un s'épuise sans toucher l'autre bout, aucun état de `t` n'est atteignable, et l'A* aurait rendu
--- « aucun chemin » si les états atteignables tiennent sous le plafond (au plus 4 par tuile sans souterrain, un par sens ; 8 avec : tout
--- droit imposé ou non), « trop long » sinon. Quand la borne ne tranche pas, l'A* tourne comme avant. Rend "aucun chemin" ou nil (rien de prouvé).
--- Tentée UNE fois, quand l'A* a développé Co.PREUVE_APRES états sans conclure (un tracé ordinaire finit bien avant : rien ne change
--- pour lui) ; si rien n'est prouvé, l'A* reprend là où il en était.
Co.EXPANDED = 0         -- s49 opti : compteur d'états développés par Co.route (diagnostic, aucune décision ne le lit)
Co.PREUVE = true        -- (tests : faux = l'A* seul, la référence)
Co.PREUVE_APRES = 2000  -- états développés par l'A* avant la tentative
Co.PREUVE_TUILES = 3000 -- tuiles développées au plus par chacun des deux remplissages
function Co.unreachable(s, t, free, ug, box, cap)
  local fcache = {}
  local function fr(u, v)
    local k = tk(u, v)
    local x = fcache[k]
    if x == nil then x = free(u, v) and true or false; fcache[k] = x end
    return x
  end
  local function inb(u, v) return u >= box.u0 and u <= box.u1 and v >= box.v0 and v <= box.v1 end
  local function is_t(u, v) return u == t.u and v == t.v end
  local function is_s(u, v) return u == s.u and v == s.v end
  -- tuile d'arrivée d'une arête de l'A* (relax) : dans la boîte, libre ou la cible
  local function landing(u, v) return inb(u, v) and (is_t(u, v) or fr(u, v)) end
  -- tuile qui porte un état développable : le départ, ou une tuile d'arrivée qui n'est pas la cible (la cible ne se développe pas)
  local function holder(u, v) return is_s(u, v) or (not is_t(u, v) and landing(u, v)) end
  local fseen, rseen = { [tk(s.u, s.v)] = true }, { [tk(t.u, t.v)] = true }
  local fq, rq = { { s.u, s.v } }, { { t.u, t.v } }
  local fh, rh = 1, 1
  local fn, rn = 1, 1
  local maxk = ug or 0
  local function fstep()
    local x = fq[fh]; fh = fh + 1
    local u, v = x[1], x[2]
    if is_t(u, v) then return end -- la cible ne se développe pas
    for _, d in ipairs(D4) do
      local nu, nv = u + d[1], v + d[2]
      if landing(nu, nv) then
        local k = tk(nu, nv)
        if not fseen[k] then fseen[k] = true; fn = fn + 1; fq[#fq + 1] = { nu, nv } end
      end
      for kk = 2, maxk do
        local mu, mv = u + kk * d[1], v + kk * d[2]
        local yu, yv = mu + d[1], mv + d[2]
        if fr(mu, mv) and not is_t(mu, mv) and landing(yu, yv) then
          local k = tk(yu, yv)
          if not fseen[k] then fseen[k] = true; fn = fn + 1; fq[#fq + 1] = { yu, yv } end
        end
      end
    end
  end
  local function rstep()
    local y = rq[rh]; rh = rh + 1
    local u, v = y[1], y[2]
    for _, d in ipairs(D4) do
      -- arête x -> y avec x = y - d (pas d'un tapis)
      local xu, xv = u - d[1], v - d[2]
      if holder(xu, xv) then
        local k = tk(xu, xv)
        if not rseen[k] then rseen[k] = true; rn = rn + 1; rq[#rq + 1] = { xu, xv } end
      end
      -- paire de souterrains x -> y : sortie m = y - d libre (et pas la cible), x = y - (kk + 1) d
      local mu, mv = u - d[1], v - d[2]
      if maxk >= 2 and fr(mu, mv) and not is_t(mu, mv) then
        for kk = 2, maxk do
          local xu2, xv2 = u - (kk + 1) * d[1], v - (kk + 1) * d[2]
          if holder(xu2, xv2) then
            local k = tk(xu2, xv2)
            if not rseen[k] then rseen[k] = true; rn = rn + 1; rq[#rq + 1] = { xu2, xv2 } end
          end
        end
      end
    end
  end
  local area = (box.u1 - box.u0 + 1) * (box.v1 - box.v0 + 1) + 1
  local per = (maxk >= 2) and 8 or 4 -- états par tuile : sans paire de souterrains, « tout droit imposé » n'existe jamais (m = 0)
  while true do
    local fdone, rdone = fh > #fq, rh > #rq
    if fdone then
      -- remplissage avant épuisé : `t` non atteint, au plus 8 états par tuile atteinte
      if fseen[tk(t.u, t.v)] then return nil end
      if per * fn <= cap then return "aucun chemin" end
      return nil
    end
    if rdone then
      -- remplissage arrière épuisé : `s` ne mène pas à `t` ; états atteignables depuis `s` bornés par la boîte (+ le départ)
      if rseen[tk(s.u, s.v)] then return nil end
      if per * area <= cap then return "aucun chemin" end
      return nil
    end
    -- un bout a touché l'autre : rien ne sera prouvé (le chemin existe peut-être), l'A* reprend
    if fseen[tk(t.u, t.v)] or rseen[tk(s.u, s.v)] then return nil end
    if fn > Co.PREUVE_TUILES and rn > Co.PREUVE_TUILES then return nil end
    if (fn <= rn or rn > Co.PREUVE_TUILES) and fn <= Co.PREUVE_TUILES then fstep() else rstep() end
  end
end

--- Tracé de la tuile `s` (le tapis d'avant y entre par le sens `sd`, index de D4) jusqu'à la tuile `t`, tournée vers `td`.
--- free(u, v) : un tapis peut s'y poser ; span(u, v) : un souterrain peut passer dessous ; ug : écart maximal entre l'entrée et la
--- sortie d'une paire (nil : aucun souterrain) ; box { u0, v0, u1, v1 }. Rend la liste { u, v, d (index), kind = "tapis" |
--- "souterrain", ug = "input" | "output" } dans l'ordre du flux, et le nombre d'états développés ; ou nil, raison.
--- s49 opti : le tracé ci-dessous, à réponses IDENTIQUES à celui de v0.7.107 (banc tests/perf_champ_bench.lua, empreintes des plans) :
--- (1) free, span et tcost lus UNE fois par tuile pendant l'appel (rien n'est pris pendant un tracé : mêmes réponses) ; (2) tas binaire
--- en tableaux parallèles (f, h, k), l'état se relit dans sa clé numérique (aucune table par nœud) ; l'ordre (f, h, k) est STRICT (une
--- clé n'est repoussée qu'à g strictement plus petit, les g sont entiers) : la suite des états sortis du tas ne dépend pas de la forme
--- du tas ; (3) la pièce posée par une arête n'est construite qu'au chemin rendu (avant : deux à trois tables par arête essayée) ;
--- (4) `memo` (facultatif, tenu le temps d'UN Ch.plan) : un tracé de mêmes entrées scalaires dont TOUTES les tuiles lues donnent les
--- mêmes réponses est rendu sans recherche (l'A* est déterministe : mêmes lectures, mêmes réponses, même résultat).
local MEMO_PER_KEY = 6
local function memo_valid(e, free, span, tcost)
  local L = e.fr
  for i = 1, #L, 3 do if (free(L[i], L[i + 1]) and true or false) ~= L[i + 2] then return false end end
  L = e.sp
  for i = 1, #L, 3 do if (span(L[i], L[i + 1]) and true or false) ~= L[i + 2] then return false end end
  L = e.tc
  for i = 1, #L, 3 do if tcost(L[i], L[i + 1]) ~= L[i + 2] then return false end end
  return true
end
local function copy_route(r)
  if not r then return nil end
  local o = {}
  for i, x in ipairs(r) do o[i] = { u = x.u, v = x.v, d = x.d, kind = x.kind, ug = x.ug } end
  return o
end

function Co.route(s, sd, t, td, free, span, ug, box, cap, tcost, memo)
  cap = cap or Co.ROUTE_CAP
  local mkey, mlist
  if memo then
    local parts = { s.u, s.v, sd, t.u, t.v, td, ug, box.u0, box.v0, box.u1, box.v1, cap, span ~= nil, tcost ~= nil, Co.ROUTE_W, Co.UG_COST,
      Co.PREUVE, Co.PREUVE_APRES, Co.PREUVE_TUILES }
    for i = 1, 19 do parts[i] = tostring(parts[i]) end
    mkey = table.concat(parts, ",")
    mlist = memo[mkey]
    if mlist then
      for _, e in ipairs(mlist) do
        if memo_valid(e, free, span, tcost) then
          if e.route then return copy_route(e.route), e.n end
          return nil, e.why
        end
      end
    end
  end
  -- lectures d'une tuile, gardées (et notées pour la mémoire)
  local FR, SP, TC = {}, {}, {}
  local fl, sl, tl = {}, {}, {}
  local free0, span0, tcost0 = free, span, tcost
  free = function(u, v)
    local k = tk(u, v)
    local x = FR[k]
    if x == nil then
      x = free0(u, v) and true or false
      FR[k] = x
      fl[#fl + 1] = u; fl[#fl + 1] = v; fl[#fl + 1] = x
    end
    return x
  end
  if span0 then
    span = function(u, v)
      local k = tk(u, v)
      local x = SP[k]
      if x == nil then
        x = span0(u, v) and true or false
        SP[k] = x
        sl[#sl + 1] = u; sl[#sl + 1] = v; sl[#sl + 1] = x
      end
      return x
    end
  end
  local function tc(u, v) -- coût d'une tuile où se pose une pièce (souterrain : entrée et sortie)
    if not tcost0 then return 1 end
    local k = tk(u, v)
    local x = TC[k]
    if x == nil then
      x = tcost0(u, v)
      TC[k] = x
      tl[#tl + 1] = u; tl[#tl + 1] = v; tl[#tl + 1] = x
    end
    return x
  end
  local function finish(route, why)
    if memo then
      mlist = memo[mkey]
      if not mlist then mlist = {}; memo[mkey] = mlist end
      if #mlist < MEMO_PER_KEY then
        mlist[#mlist + 1] = { fr = fl, sp = sl, tc = tl, route = copy_route(route), why = (not route) and why or nil, n = route and why or nil }
      end
    end
    return route, why
  end
  if not free(s.u, s.v) then return finish(nil, "depart") end
  if not free(t.u, t.v) then return finish(nil, "arrivee") end
  local bu0, bv0, bu1, bv1 = box.u0, box.v0, box.u1, box.v1
  local tu, tv = t.u, t.v
  local W = Co.ROUTE_W
  local abs, floor = math.abs, math.floor
  local function hh(u, v) return (abs(u - tu) + abs(v - tv)) * W end
  -- clé d'un état : tk(u, v) * 10 + (d - 1) * 2 + m (celle de v0.7.107) ; relue : tuile = floor(k / 10), d, m dans k % 10
  local g, pk, pug, closed = {}, {}, {}, {}
  -- tas : tableaux parallèles, ordre (f, h, k) strict
  local HF, HH, HK, hn = {}, {}, {}, 0
  local function push(f, h, k)
    hn = hn + 1
    local i = hn
    while i > 1 do
      local p = floor(i / 2)
      local pf, ph, pkk = HF[p], HH[p], HK[p]
      if pf < f or (pf == f and (ph < h or (ph == h and pkk <= k))) then break end
      HF[i], HH[i], HK[i] = pf, ph, pkk
      i = p
    end
    HF[i], HH[i], HK[i] = f, h, k
  end
  local function pop()
    local k = HK[1]
    local lf, lh, lk = HF[hn], HH[hn], HK[hn]
    HF[hn], HH[hn], HK[hn] = nil, nil, nil
    hn = hn - 1
    if hn > 0 then
      local i = 1
      while true do
        local l = 2 * i
        if l > hn then break end
        local m, mf, mh, mk = l, HF[l], HH[l], HK[l]
        local r = l + 1
        if r <= hn then
          local rf, rh, rk = HF[r], HH[r], HK[r]
          if rf < mf or (rf == mf and (rh < mh or (rh == mh and rk < mk))) then m, mf, mh, mk = r, rf, rh, rk end
        end
        if not (mf < lf or (mf == lf and (mh < lh or (mh == lh and mk < lk)))) then break end
        HF[i], HH[i], HK[i] = mf, mh, mk
        i = m
      end
      HF[i], HH[i], HK[i] = lf, lh, lk
    end
    return k
  end
  local k0 = tk(s.u, s.v) * 10 + (sd - 1) * 2
  g[k0] = 0
  do local h0 = hh(s.u, s.v); push(h0, h0, k0) end
  local expanded = 0
  local function relax(ck, cg, nu, nv, nd, nm, cost, isug)
    if nu < bu0 or nu > bu1 or nv < bv0 or nv > bv1 then return end
    if not (free(nu, nv) or (nu == tu and nv == tv)) then return end
    local nk = tk(nu, nv) * 10 + (nd - 1) * 2 + nm
    if closed[nk] then return end
    local ng = cg + cost
    local og = g[nk]
    if og == nil or ng < og then
      g[nk] = ng
      pk[nk] = ck
      pug[nk] = isug
      local h = hh(nu, nv)
      push(ng + h, h, nk)
    end
  end
  local function tile_of(k)
    local q = floor(k / 10)
    return floor(q / 100000) - 50000, q % 100000 - 50000, floor((k % 10) / 2) + 1, k % 2
  end
  while hn > 0 do
    local ck = pop()
    if not closed[ck] then
      closed[ck] = true
      expanded = expanded + 1
      Co.EXPANDED = Co.EXPANDED + 1 -- s49 opti : états développés, tous tracés (banc tests/perf_champ_bench.lua)
      if expanded > cap then return finish(nil, "trop long") end
      if expanded == Co.PREUVE_APRES and Co.PREUVE then
        local why = Co.unreachable(s, t, free, ug, box, cap) -- lot PERF3 : impossibilité prouvée vite, même réponse que l'A*
        if why then return finish(nil, why) end
      end
      local cu, cv, cd, cm = tile_of(ck)
      local cg = g[ck]
      if cu == tu and cv == tv then
        if cd ~= ((td + 1) % 4) + 1 and (cm == 0 or cd == td) then
          -- chemin : de l'arrivée au départ par les états d'avant, chaque arête rend sa pièce (tapis, ou paire de souterrains)
          local rev = { { u = tu, v = tv, d = td, kind = "tapis" } }
          local k = ck
          while pk[k] do
            local p = pk[k]
            local nu, nv, nd = tile_of(k)
            local pu, pv = tile_of(p)
            if pug[k] then
              local dv = D4[nd]
              rev[#rev + 1] = { u = nu - dv[1], v = nv - dv[2], d = nd, kind = "souterrain", ug = "output" }
              rev[#rev + 1] = { u = pu, v = pv, d = nd, kind = "souterrain", ug = "input" }
            else
              rev[#rev + 1] = { u = pu, v = pv, d = nd, kind = "tapis" }
            end
            k = p
          end
          local out = {}
          for i = #rev, 1, -1 do out[#out + 1] = rev[i] end
          return finish(out, expanded)
        end
      else
        -- tapis posé ici, tout droit ou en virage (jamais demi-tour ; tout droit imposé après une sortie de souterrain)
        local c1 = tc(cu, cv)
        do
          local dv = D4[cd]
          relax(ck, cg, cu + dv[1], cv + dv[2], cd, 0, c1, false)
        end
        if cm == 0 then
          local nd = ((cd - 2) % 4) + 1
          local dv = D4[nd]
          relax(ck, cg, cu + dv[1], cv + dv[2], nd, 0, c1, false)
          nd = (cd % 4) + 1
          dv = D4[nd]
          relax(ck, cg, cu + dv[1], cv + dv[2], nd, 0, c1, false)
        end
        -- paire de souterrains : entrée ici (on y arrive tout droit), sortie k tuiles plus loin, puis tout droit
        if ug then
          local dv = D4[cd]
          local ok_span = true
          for k = 1, ug do
            local mu, mv = cu + k * dv[1], cv + k * dv[2]
            if k >= 2 and ok_span and free(mu, mv) and not (mu == tu and mv == tv) then
              relax(ck, cg, mu + dv[1], mv + dv[2], cd, 1, c1 + tc(mu, mv) + (k - 1) + Co.UG_COST, true)
            end
            if span and not span(mu, mv) then ok_span = false end
          end
        end
      end
    end
  end
  return finish(nil, "aucun chemin")
end

---------------------------------------------------------------------------------------------------
-- 3. Ligne de foreuses sur le charbon
---------------------------------------------------------------------------------------------------
--- Ligne droite de foreuses d'un côté ou des deux côtés d'un tapis (comme une bande du champ), poteaux sur la rangée extérieure de
--- chaque côté : { ents, exit = { u, v, d }, drills } ou nil. coal : liste { {u, v} } ; is_coal(u, v) ; free(u, v) ; d = { size, reach } ;
--- want : foreuses voulues ; target { u, v } : la sortie va vers elle. Choix : le plus de foreuses (au plus `want`), puis la ligne la
--- plus courte et la plus proche de la cible, puis un seul côté.
--- is_foreign(u, v) (lot MELANGE, facultatif) : tuile d'une AUTRE ressource minable ; aucune foreuse dont la zone en touche une (fer ou
--- pierre sur la voie de charbon la bouchent).
function Co.coal_line(coal, is_coal, free, d, want, target, R, wire, per_side, center, is_foreign)
  if #coal == 0 or want < 1 or R < 1 then return nil end
  -- Lot PERF3 : place libre et tuiles étrangères lues UNE fois par tuile pendant l'appel (rien n'est pris ici : mêmes réponses) ;
  -- chaque position de foreuse les relisait toutes, et les rangées voisines se recouvrent
  do
    local f0, fmem = free, {}
    free = function(u, v)
      local k = tk(u, v)
      local x = fmem[k]
      if x == nil then x = f0(u, v) and true or false; fmem[k] = x end
      return x
    end
    if is_foreign then
      local g0, gmem = is_foreign, {}
      is_foreign = function(u, v)
        local k = tk(u, v)
        local x = gmem[k]
        if x == nil then x = g0(u, v) and true or false; gmem[k] = x end
        return x
      end
    end
  end
  local s, r = d.size, d.reach
  local h = math.floor(s / 2)
  -- fenêtre autour de `center`, sinon de la tuile de charbon la plus proche de la cible
  local best, bd = center, nil
  if not best then
    for _, t in ipairs(coal) do
      local dd = math.abs(t[1] - target.u) + math.abs(t[2] - target.v)
      if not bd or dd < bd or (dd == bd and (t[1] < best[1] or (t[1] == best[1] and t[2] < best[2]))) then best, bd = t, dd end
    end
  end
  local W = Co.WINDOW
  local u0, u1, v0, v1 = best[1] - W, best[1] + W, best[2] - W, best[2] + W
  local function cc(u, v) return u >= u0 and u <= u1 and v >= v0 and v <= v1 and is_coal(u, v) end
  local step = math.max(1, math.min(math.floor(wire + 1e-9), s + 2 * R))
  local choice
  local function better(x, y)
    -- (revue-fonderie, 3/11, cadre du joueur, graine 271828182 : sortie enfermée par ses foreuses et une case bloquée devant, « aucun chemin »
    -- dans les deux ordres) une ligne dont la sortie peut partir passe avant une ligne enfermée, qui ne servait jamais
    if x.open ~= y.open then return x.open end
    if x.n ~= y.n then return x.n > y.n end
    if x.score ~= y.score then return x.score < y.score end
    if x.nsides ~= y.nsides then return x.nsides < y.nsides end
    if x.orient ~= y.orient then return x.orient < y.orient end
    if x.l ~= y.l then return x.l < y.l end
    if x.set ~= y.set then return x.set < y.set end
    return x.e < y.e
  end
  for _, orient in ipairs({ "u", "v" }) do
    local function P(a, l) if orient == "u" then return a, l end return l, a end
    local amin, amax, lmin, lmax
    if orient == "u" then amin, amax, lmin, lmax = u0, u1, v0, v1 else amin, amax, lmin, lmax = v0, v1, u0, u1 end
    -- foreuses possibles d'un côté sg de la rangée l (corps sur les rangées l + sg .. l + sg * s), glouton le long de a
    -- Lot PERF3 : SOMMES CUMULÉES 2D, une fois par orientation, de la place occupée, des tuiles étrangères et du charbon sur toute la
    -- fenêtre lue (positions a de amin - s - r à amax + r, zones de a - r à a + s - 1 + r ; rangées l + sg * y, y de 1 - r à s + r,
    -- l de lmin - s à lmax + s) : chaque position se juge en temps constant ; les comptes sont entiers et exacts, la règle (corps
    -- libre, aucune tuile étrangère dans la zone, au moins Co.MIN_COAL tuiles de charbon) est celle d'avant, mêmes réponses
    local X0, X1 = amin - s - 2 * r, amax + s - 1 + 2 * r
    local Y0, Y1 = lmin - 2 * s - r, lmax + 2 * s + r
    local H = Y1 - Y0 + 2
    local NF, FO, CO = {}, {}, {}
    for i = 0, H - 1 do NF[i] = 0; FO[i] = 0; CO[i] = 0 end -- colonne x = X0 - 1 (bord)
    for x = X0, X1 do
      local base, prev = (x - X0 + 1) * H, (x - X0) * H
      NF[base], FO[base], CO[base] = 0, 0, 0 -- rangée y = Y0 - 1 (bord)
      local cnf, cfo, cco = 0, 0, 0
      for y = Y0, Y1 do
        local pu, pv = P(x, y)
        if not free(pu, pv) then cnf = cnf + 1 end
        if is_foreign and is_foreign(pu, pv) then cfo = cfo + 1 end
        if cc(pu, pv) then cco = cco + 1 end
        local j = y - Y0 + 1
        NF[base + j] = NF[prev + j] + cnf
        FO[base + j] = FO[prev + j] + cfo
        CO[base + j] = CO[prev + j] + cco
      end
    end
    local function rect(S, xa, xb, ya, yb)
      local i1, i0 = (xb - X0 + 1) * H, (xa - X0) * H
      local j1, j0 = yb - Y0 + 1, ya - Y0
      return S[i1 + j1] - S[i0 + j1] - S[i1 + j0] + S[i0 + j0]
    end
    local function side_drills(l, sg)
      local A = {}
      local by0, by1, zy0, zy1
      if sg > 0 then by0, by1, zy0, zy1 = l + 1, l + s, l + 1 - r, l + s + r
      else by0, by1, zy0, zy1 = l - s, l - 1, l - s - r, l - 1 + r end
      local a = amin - s - r
      while a <= amax + r do
        local ok = rect(NF, a, a + s - 1, by0, by1) == 0
        local n = 0
        if ok and is_foreign then -- lot MELANGE
          ok = rect(FO, a - r, a + s - 1 + r, zy0, zy1) == 0
        end
        if ok then n = rect(CO, a - r, a + s - 1 + r, zy0, zy1) end
        if ok and n >= Co.MIN_COAL then A[#A + 1] = a; a = a + s else a = a + 1 end
      end
      return A
    end
    for l = lmin - s, lmax + s do
      local per = { [-1] = side_drills(l, -1), [1] = side_drills(l, 1) }
      for set_i, set in ipairs({ { -1 }, { 1 }, { -1, 1 } }) do
        local all = {}
        for _, sg in ipairs(set) do for _, a in ipairs(per[sg]) do all[#all + 1] = { a = a, sg = sg } end end
        if #all > 0 then
          for _, e in ipairs({ 1, -1 }) do
            table.sort(all, function(p, q)
              if p.a ~= q.a then if e > 0 then return p.a > q.a end return p.a < q.a end
              return p.sg < q.sg
            end)
            -- au plus `per_side` foreuses d'un côté : chaque côté dépose sur SA voie
            local pick, cnt = {}, { [-1] = 0, [1] = 0 }
            for _, q in ipairs(all) do
              if #pick < want and (not per_side or cnt[q.sg] < per_side) then pick[#pick + 1] = q; cnt[q.sg] = cnt[q.sg] + 1 end
            end
            local n = #pick
            local lo, hi = math.huge, -math.huge
            for _, q in ipairs(pick) do lo, hi = math.min(lo, q.a + h), math.max(hi, q.a + h) end
            local first, last = (e > 0) and lo or hi, (e > 0) and hi or lo
            local ok = true
            for x = first, last + e, e do local pu, pv = P(x, l); if not free(pu, pv) then ok = false end end
            -- poteaux : rangée extérieure de chaque côté (contre les foreuses), un dès qu'une foreuse n'est plus couverte, relais si trou
            local poles = {}
            for _, sg in ipairs(set) do
              if not ok then break end
              local row = l + sg * (s + 1)
              local list = {}
              for _, q in ipairs(pick) do if q.sg == sg then list[#list + 1] = q.a end end
              table.sort(list)
              local lastp
              local function largest_free(lo2, hi2)
                for x = hi2, lo2, -1 do local pu, pv = P(x, row); if free(pu, pv) then return x end end
                return nil
              end
              for _, q in ipairs(list) do
                -- l'aire d'un poteau en x touche la foreuse [q, q + s - 1] si x ∈ [q - R, q + s - 1 + R]
                if not (lastp and lastp >= q - R and lastp <= q + s - 1 + R) then
                  while ok and lastp and q - R > lastp + step do
                    local x = largest_free(lastp + 1, lastp + step)
                    if not x then ok = false else poles[#poles + 1] = { x, row }; lastp = x end
                  end
                  if not ok then break end
                  local hi2 = q + s - 1 + R
                  if lastp then hi2 = math.min(hi2, lastp + step) end
                  local x = largest_free(q - R, hi2)
                  if not x then ok = false break end
                  poles[#poles + 1] = { x, row }
                  lastp = x
                end
              end
            end
            if ok then
              local eu, ev = P(last + e, l)
              -- sortie ouverte : la case devant la sortie est libre, ou une case latérale libre et hors des foreuses prises
              local open = (function()
                local fu, fv = P(last + 2 * e, l)
                if free(fu, fv) then return true end
                for _, sg in ipairs({ -1, 1 }) do
                  local su, sv = P(last + e, l + sg)
                  local covered = false
                  for _, q in ipairs(pick) do if q.sg == sg and last + e >= q.a and last + e <= q.a + s - 1 then covered = true end end
                  if free(su, sv) and not covered then return true end
                end
                return false
              end)()
              local score = math.abs(eu - target.u) + math.abs(ev - target.v) + math.abs(last - first)
              local cand = { n = n, score = score, nsides = #set, orient = orient, l = l, set = set_i, e = e, pick = pick, poles = poles,
                first = first, last = last, open = open }
              if not choice or better(cand, choice) then choice = cand end
            end
          end
        end
      end
    end
  end
  if not choice then return nil end
  local ch = choice
  local function P(a, l) if ch.orient == "u" then return a, l end return l, a end
  local function V(da, dl) if ch.orient == "u" then return da, dl end return dl, da end
  local ents = {}
  for _, q in ipairs(ch.pick) do
    local pu, pv = P(q.a, ch.l + q.sg)
    local qu, qv = P(q.a + s - 1, ch.l + q.sg * s)
    local du, dv = V(0, -q.sg)
    ents[#ents + 1] = { kind = "foreuse", u = math.min(pu, qu), v = math.min(pv, qv), size = s, du = du, dv = dv, role = "charbon" }
  end
  local bu, bv = V(ch.e, 0)
  for x = ch.first, ch.last, ch.e do
    local pu, pv = P(x, ch.l)
    ents[#ents + 1] = { kind = "tapis", u = pu, v = pv, size = 1, du = bu, dv = bv, role = "charbon", belt = 1 }
  end
  for _, p in ipairs(ch.poles) do
    local pu, pv = P(p[1], p[2])
    ents[#ents + 1] = { kind = "poteau", u = pu, v = pv, size = 1, du = 0, dv = 0, role = "charbon" }
  end
  local eu, ev = P(ch.last + ch.e, ch.l)
  return { ents = ents, exit = { u = eu, v = ev, d = didx(bu, bv) }, drills = #ch.pick }
end

---------------------------------------------------------------------------------------------------
-- 4. Tronc et dérivations d'un côté du champ
---------------------------------------------------------------------------------------------------
--- Pièces PROPRES à une colonne en mode « voie » : prolongement de sa voie de charbon jusqu'au tronc, dérivation (sortie de
--- répartiteur tournée vers la colonne, ou bras tapis -> tapis), poteau de liaison. `col` = { coal_v, link_v, s_edge, far } (rangées de sa voie
--- de charbon et de ses bras d'entrée : info.b_coal, info.b_link de Co.layout), net = { uT, dv, split }.
function Co.branch(col, net, side, wire)
  local out = {}
  local v = col.coal_v
  local function U(c) return col.s_edge + side * c end
  local cT = (net.uT - col.s_edge) * side -- colonne du tronc, en col de cette colonne
  for c = col.far + 1, cT - 2 do out[#out + 1] = { kind = "tapis", u = U(c), v = v, size = 1, du = -side, dv = 0, role = "charbon" } end
  if net.split or col.last then
    out[#out + 1] = { kind = "tapis", u = U(cT - 1), v = v, size = 1, du = -side, dv = 0, role = "charbon" }
  else
    out[#out + 1] = { kind = "bras", u = U(cT - 1), v = v, size = 1, du = side, dv = 0, role = "charbon" } -- prend sur le tronc
  end
  out[#out + 1] = { kind = "poteau", u = U(cT - 1), v = col.link_v, size = 1, du = 0, dv = 0, role = "charbon" }
  -- relais sur la rangée des bras d'entrée (libre au-delà des fours), du bout de la colonne au poteau de dérivation : une colonne plus
  -- courte que la plus longue du côté a son bout loin du tronc (mesuré hors jeu : 7,6 tuiles pour un fil de 7,5)
  local step = math.max(1, math.floor((wire or 7) + 1e-9))
  local c = col.far
  while (cT - 1) - c > step do
    out[#out + 1] = { kind = "poteau", u = U(c), v = col.link_v, size = 1, du = 0, dv = 0, role = "charbon" }
    c = c + step
  end
  if (cT - 1) - c > 0 then out[#out + 1] = { kind = "poteau", u = U(c), v = col.link_v, size = 1, du = 0, dv = 0, role = "charbon" } end
  return out
end

--- Tuiles (u, v) des pièces propres à une colonne (contrôle de place avant de choisir la voie).
local function branch_tiles(col, net, side, wire)
  local t = {}
  for _, e in ipairs(Co.branch(col, net, side, wire)) do t[#t + 1] = { e.u, e.v } end
  return t
end

--- Réseau de charbon d'un côté : cols = { { key, coal_v, link_v, s_edge, far, need } } (colonnes à combustible du côté `side`), env = { free,
--- take, forbid (u, v) -> vrai : zone du champ et des colonnes, interdite au tracé en surface ; span ; coal = { tiles, is_coal, rate } ;
--- drill ; pole ; ug ; split ; bridge(poles) -> relais ; ugs : tuiles de souterrain déjà posées }. Rend
--- { uT, dv, split, ents (pièces communes), modes = { [key] = "voie" | "coffre" }, drills, need, why } ; jamais nil.
function Co.network(cols, side, env)
  local res = { modes = {}, ents = {}, need = 0 }
  for _, c in ipairs(cols) do res.modes[c.key] = "coffre"; res.need = res.need + (c.need or 0) end
  if #cols == 0 then res.why = "aucune colonne" return res end
  local coal = env.coal
  if not (coal and coal.tiles and #coal.tiles > 0 and coal.rate and coal.rate > 0) then res.why = "aucun charbon lu" return res end
  table.sort(cols, function(a, b) return a.coal_v < b.coal_v end)
  local base
  for _, c in ipairs(cols) do
    local u = c.s_edge + side * (c.far + 2)
    if not base or (side > 0 and u > base) or (side < 0 and u < base) then base = u end
  end
  local vmin, vmax = cols[1].coal_v, cols[#cols].coal_v
  local vmid = math.floor((vmin + vmax) / 2)
  local cap = (env.inserter_rate or 0.83) * Co.PICKUP
  local maxn = 0
  for _, c in ipairs(cols) do maxn = math.max(maxn, c.need or 0) end
  local supply = res.need * Co.COAL_MARGIN
  if not env.split then supply = math.max(supply, (#cols - 1) * cap + maxn) end
  local want = math.max(1, math.ceil(supply / coal.rate - 1e-9))
  -- jusqu'à Co.DEPOSITS fenêtres : la tuile de charbon la plus proche de la cible, puis la plus proche HORS des fenêtres déjà prises ;
  -- la ligne qui porte le plus de foreuses (au plus `want`), puis la plus proche
  local target = { u = base + 2 * side, v = vmid }
  local function dist(t) return math.abs(t[1] - target.u) + math.abs(t[2] - target.v) end
  local sorted = {}
  for _, t in ipairs(coal.tiles) do sorted[#sorted + 1] = t end
  table.sort(sorted, function(a, b)
    local da, db = dist(a), dist(b)
    if da ~= db then return da < db end
    if a[1] ~= b[1] then return a[1] < b[1] end
    return a[2] < b[2]
  end)
  local centers = {}
  for _, t in ipairs(sorted) do
    if #centers >= Co.DEPOSITS then break end
    local inside = false
    for _, c in ipairs(centers) do if math.abs(t[1] - c[1]) <= Co.WINDOW and math.abs(t[2] - c[2]) <= Co.WINDOW then inside = true end end
    if not inside then centers[#centers + 1] = t end
  end
  local line, lscore
  local lfree = function(u, v) return env.free(u, v) and not env.forbid(u, v) end
  for _, c in ipairs(centers) do
    local l = Co.coal_line(coal.tiles, coal.is_coal, lfree, env.drill, want, target, env.pole.reach, env.pole.wire, env.lane_drills, c,
      coal.is_foreign)
    if l then
      local sc = math.abs(l.exit.u - target.u) + math.abs(l.exit.v - target.v)
      if not line or l.drills > line.drills or (l.drills == line.drills and sc < lscore) then line, lscore = l, sc end
      if line.drills >= want then break end
    end
  end
  if not line then res.why = "aucune ligne de foreuses sur le charbon" return res end
  local dv = (line.exit.v <= vmid) and 1 or -1
  local first_v, last_v = (dv > 0) and vmin or vmax, (dv > 0) and vmax or vmin
  local v_start = first_v - 2 * dv
  local uT, keep
  for t = 0, Co.TRUNK_TRIES do
    local u = base + side * t
    local ok = true
    for v = v_start, last_v, dv do if not env.free(u, v) then ok = false end end
    if ok then
      local net = { uT = u, dv = dv, split = env.split }
      local kept, dropped = {}, {}
      for _, c in ipairs(cols) do
        local fine, at = true, nil
        for _, tl in ipairs(branch_tiles(c, net, side, env.pole.wire)) do
          if fine and not env.free(tl[1], tl[2]) then fine, at = false, tl end
        end
        if fine and net.split then
          if not env.free(u - side, c.coal_v - dv) then fine, at = false, { u - side, c.coal_v - dv } end
        end
        if fine then kept[#kept + 1] = c else dropped[#dropped + 1] = string.format("bande %s : derivation occupee en (u %d, v %d)", c.key, at[1], at[2]) end
      end
      if #kept > 0 and (not keep or #kept > #keep) then uT, keep, res.dropped = u, kept, dropped end
      if keep and #keep == #cols then break end
    end
  end
  if not uT then res.why = "aucune place pour le tronc" return res end
  -- tronc : de v_start (arrivée du tracé) au dernier embranchement gardé
  table.sort(keep, function(a, b) if dv > 0 then return a.coal_v < b.coal_v end return a.coal_v > b.coal_v end)
  -- ce que la ligne extrait nourrit les premières colonnes du tronc ; les suivantes gardent le coffre de tête (jamais un four sans
  -- charbon en bout de tronc parce que la ligne est trop courte)
  -- colonnes servies : le plus long début du tronc tel que (k - 1) dérivations au plafond d'un bras + le besoin de la k-ième (la dernière,
  -- servie par le bout du tronc) tiennent dans ce que la ligne extrait (avec répartiteurs : la somme des besoins)
  local capa, cum, fed = line.drills * coal.rate, 0, {}
  for i, c in ipairs(keep) do
    cum = cum + (c.need or 0)
    local intake = env.split and cum or ((i - 1) * cap + (c.need or 0))
    if intake > capa + 1e-9 or cum > capa + 1e-9 then break end
    fed[#fed + 1] = c
  end
  if #fed == 0 then res.why = string.format("charbon insuffisant (%d foreuse(s), %.2f/s)", line.drills, capa) return res end
  if #fed < #keep then res.why = string.format("charbon pour %d colonne(s) sur %d (%d foreuse(s), %.2f/s)", #fed, #keep, line.drills, capa) end
  keep = fed
  local last_c = keep[#keep]
  last_v = last_c.coal_v
  for _, c in ipairs(cols) do c.last = nil end
  last_c.last = true
  local ents = {}
  local split_at = {}
  if env.split then
    for i = 1, #keep - 1 do split_at[keep[i].coal_v - dv] = keep[i] end
  end
  local taken = {}
  local function add(e) ents[#ents + 1] = e; for x = e.u, e.u + (e.w or e.size) - 1 do for y = e.v, e.v + (e.h or e.size) - 1 do taken[tk(x, y)] = true end end end
  -- les pièces propres aux colonnes gardées sont réservées avant le tracé et les relais
  local net0 = { uT = uT, dv = dv, split = env.split }
  for _, c in ipairs(keep) do for _, tl in ipairs(branch_tiles(c, net0, side, env.pole.wire)) do taken[tk(tl[1], tl[2])] = true end end
  -- bras de dérivation (sans répartiteur) : un bras porte ce qu'il prend sur un tapis
  res.short = {}
  if not env.split then
    local cap = (env.inserter_rate or 0.83) * Co.PICKUP
    for _, c in ipairs(keep) do
      if not c.last and (c.need or 0) > cap + 1e-9 then res.short[#res.short + 1] = c.key end
    end
  end
  for v = v_start + dv, last_v, dv do
    if split_at[v] then
      add({ kind = "repartiteur", u = math.min(uT, uT - side), v = v, w = 2, h = 1, size = 2, du = 0, dv = dv, role = "charbon" })
    elseif v == last_v then
      add({ kind = "tapis", u = uT, v = v, size = 1, du = -side, dv = 0, role = "charbon" })
    else
      add({ kind = "tapis", u = uT, v = v, size = 1, du = 0, dv = dv, role = "charbon" })
    end
  end
  -- poteaux du tronc (côté extérieur), un en face de chaque poteau de liaison, d'autres où les fils manquent
  local tpoles = { v_start }
  for _, c in ipairs(keep) do tpoles[#tpoles + 1] = c.link_v end
  table.sort(tpoles)
  local wire = math.floor(env.pole.wire + 1e-9)
  local pv = {}
  for i, v in ipairs(tpoles) do
    if i > 1 then
      local p = pv[#pv]
      while v - p > wire do p = p + wire; pv[#pv + 1] = p end
    end
    if pv[#pv] ~= v then pv[#pv + 1] = v end
  end
  for _, v in ipairs(pv) do
    if env.free(uT + side, v) then add({ kind = "poteau", u = uT + side, v = v, size = 1, du = 0, dv = 0, role = "charbon" }) end
  end
  for _, e in ipairs(line.ents) do add(e) end
  -- tracé : de la sortie de la ligne jusqu'à la tête du tronc (tournée vers dv)
  local function rfree(u, v)
    if taken[tk(u, v)] then return false end
    if u == uT and v == v_start then return env.free(u, v) end
    return env.free(u, v) and not env.forbid(u, v)
  end
  local box = { u0 = math.min(line.exit.u, uT, env.box.u0) - Co.ROUTE_MARGIN, u1 = math.max(line.exit.u, uT, env.box.u1) + Co.ROUTE_MARGIN,
    v0 = math.min(line.exit.v, v_start, env.box.v0) - Co.ROUTE_MARGIN, v1 = math.max(line.exit.v, v_start, env.box.v1) + Co.ROUTE_MARGIN }
  local span = function(u, v) return not (env.ugs and env.ugs[tk(u, v)]) end
  local tcost = env.soft and function(u, v) return env.soft(u, v) and (1 + Co.SOFT_COST) or 1 end or nil
  -- s47 : un tracé fait au moins la distance de Manhattan + 1 tuiles ; au-delà de ROUTE_MAX il serait refusé après la recherche
  local man = math.abs(line.exit.u - uT) + math.abs(line.exit.v - v_start)
  if man + 1 > Co.ROUTE_MAX then
    res.why = string.format("trace du charbon trop long (%d tuiles, plafond %d)", man + 1, Co.ROUTE_MAX) return res
  end
  local route, why = Co.route({ u = line.exit.u, v = line.exit.v }, line.exit.d, { u = uT, v = v_start }, didx(0, dv), rfree, span, env.ug, box,
    Co.ROUTE_STATES, tcost)
  if not route then res.why = "trace du charbon : " .. tostring(why) return res end
  if #route > Co.ROUTE_MAX then res.why = string.format("trace du charbon trop long (%d tuiles, plafond %d)", #route, Co.ROUTE_MAX) return res end
  local nug = 0
  for _, r in ipairs(route) do
    local d = D4[r.d]
    add({ kind = r.kind, u = r.u, v = r.v, size = 1, du = d[1], dv = d[2], role = "charbon", ug = r.ug })
    if r.kind == "souterrain" then nug = nug + 1 end
  end
  -- poteaux le long du tracé : un tous les `wire - 1` pas au plus, sur une tuile libre voisine
  local poles = {}
  for _, e in ipairs(ents) do if e.kind == "poteau" then poles[#poles + 1] = { e.u, e.v } end end
  local since = math.huge
  for _, r in ipairs(route) do
    since = since + 1
    if since >= wire - 1 then
      for _, o in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
        local pu, pvv = r.u + o[1], r.v + o[2]
        if since >= wire - 1 and not taken[tk(pu, pvv)] and env.free(pu, pvv) and not env.forbid(pu, pvv) then
          add({ kind = "poteau", u = pu, v = pvv, size = 1, du = 0, dv = 0, role = "charbon" })
          poles[#poles + 1] = { pu, pvv }
          since = 0
        end
      end
    end
  end
  for _, c in ipairs(keep) do poles[#poles + 1] = { uT - side, c.link_v } end
  if env.bridge then
    for _, p in ipairs(env.bridge(poles, function(u, v) return not taken[tk(u, v)] and env.free(u, v) end)) do
      add({ kind = "poteau", u = p[1], v = p[2], size = 1, du = 0, dv = 0, role = "charbon" })
    end
  end
  for _, c in ipairs(keep) do res.modes[c.key] = "voie" end
  res.uT, res.dv, res.split, res.ents, res.drills, res.undergrounds = uT, dv, env.split and true or false, ents, line.drills, nug
  res.v_start, res.route_len = v_start, #route
  return res
end

return Co
