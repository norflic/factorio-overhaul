--[[
  Lot PORTE-BASE (vague 8, arbitrage du DC du 29/10 vers 20 h 50 sur la porte de la défense) : ZONE DE BASE d'une équipe, par
  DENSITÉ DE BÂTIMENTS. PUR : aucune API Factorio, testable hors jeu (tests/porte_base_test.lua).

  Le DC : « oui garder mais il faut faire attention si c'est des pnj qui meurent proche de la base ou à perpète les oies entre un
  avant poste lointain et "la base" qui est en gros la zone où on va dire qu'il "y a des bâtiments" (on peut définir base comme une
  sorte de densité de bâtiment dans un carré de 6x6 par exemple) ».

  Règle :
    1. grille de cases de Base.CELL tuiles ; chaque bâtiment de l'équipe pèse son poids (Base.type_weight : 1, ou 0 pour les
       pièces LINÉAIRES, qui relient des lieux sans en faire une base : tapis, tuyaux, poteaux, murs ; lues par leur RÔLE de
       shared/ai3/reglages.lua, jamais par un nom) ;
    2. une case est DENSE si son poids atteint Base.DENSE ;
    3. composantes connexes (8 voisins) des cases denses ; on GARDE la composante du QG et toute composante de poids total
       >= Base.MIN_W (un groupe de bâtiments : base principale, îlot, avant-poste bâti) ; une paire de tourelles isolée sur une
       route n'est pas une base ;
    4. la case du QG est toujours dans la base ; la zone gardée est élargie de Base.MARGIN case(s) (« proche de la base »).
  Une mort est « dans la base » si sa case est dans la zone élargie.

  Zone (rangée dans global par script/ai3/comportement.lua : nombres et tables seulement) :
    { t = tick du calcul, cells = { [clé] = true }, n = cases de base (marge comprise), dense = cases denses,
      comps = composantes gardées, comps_all = composantes denses, w = poids compté, ents = bâtiments lus, hq = clé du QG }
  Aucun ordre de `pairs` : les composantes sont parcourues sur les clés triées.
]]

local Base = {}

Base.CELL = 8           -- tuiles par côté de case (le DC : « un carré de 6x6 par exemple » ; 8 : 4 cases par chunk, une machine
                        -- 3x3 et ses bras tiennent dans une case)
Base.DENSE = 2          -- poids minimal d'une case dense (une machine et un bras ; une foreuse et sa voisine)
Base.MIN_W = 6          -- poids minimal d'une composante gardée hors du QG (une paire de tourelles : 2, refusée)
Base.MARGIN = 1         -- cases ajoutées autour de la zone gardée (« proche de la base » : 8 tuiles)
Base.SCAN_R = 320       -- rayon (tuiles, carré) du relevé autour du QG ; au-delà, rien n'est « base » (côté prudent)
Base.PERIOD = 3600      -- une zone sert au plus 1 min, puis elle est recalculée (au plus un relevé par minute et par équipe)
Base.OFF = 32768

-- Rôles comptés (shared/ai3/reglages.lua, R.ENTITY_ROLE) : bâtiments qui font un lieu. « logistique » (tapis, bras, poteaux, tuyaux,
-- coffres, radars) et « main » (personnage) ne pèsent rien ; parmi « militaire », les murs et portes (types `wall`, `gate`) non plus.
Base.ROLE_W = { fabrique = 1, foreuse = 1, labo = 1, pompe = 1, chauffe = 1, generateur = 1, militaire = 1 }
Base.LINEAR_TYPES = { wall = true, gate = true }

--- Poids d'un type du moteur, lu par son rôle (table R.ENTITY_ROLE) : 0 ou 1.
function Base.type_weight(ty, roles)
  if Base.LINEAR_TYPES[ty] then return 0 end
  local role = roles and roles[ty]
  return role and Base.ROLE_W[role] or 0
end

--- Types à relever (ceux qui pèsent), dans l'ordre trié de `types` (liste triée de R.ENTITY_TYPES).
function Base.scan_types(types, roles)
  local out = {}
  for _, ty in ipairs(types) do
    if Base.type_weight(ty, roles) > 0 then out[#out + 1] = ty end
  end
  return out
end

function Base.cell(v) return math.floor(v / Base.CELL) end
function Base.key(cx, cy) return (cx + Base.OFF) * 65536 + (cy + Base.OFF) end
function Base.unkey(k)
  local cx = math.floor(k / 65536)
  return cx - Base.OFF, k - cx * 65536 - Base.OFF
end

--- Zone de base. ents = { { x, y, w = poids (1 par défaut) }, ... } (bâtiments de l'équipe) ; hq = { x, y } ; tick.
--- opts (facultatif, bancs) : { dense, min_w, margin }.
function Base.build(ents, hq, tick, opts)
  opts = opts or {}
  local dense_w = opts.dense or Base.DENSE
  local min_w = opts.min_w or Base.MIN_W
  local margin = opts.margin or Base.MARGIN
  local wcell, total = {}, 0
  for _, e in ipairs(ents) do
    local w = e.w or 1
    if w > 0 then
      local k = Base.key(Base.cell(e.x), Base.cell(e.y))
      wcell[k] = (wcell[k] or 0) + w
      total = total + w
    end
  end
  local dense, dkeys = {}, {}
  for k, w in pairs(wcell) do
    if w >= dense_w then dense[k] = true dkeys[#dkeys + 1] = k end
  end
  table.sort(dkeys)
  local hqk = hq and Base.key(Base.cell(hq.x), Base.cell(hq.y)) or nil
  local comp_of, keep, comps_all, comps = {}, {}, 0, 0
  for _, k0 in ipairs(dkeys) do
    if not comp_of[k0] then
      comps_all = comps_all + 1
      local members, w, has_hq = { k0 }, 0, false
      comp_of[k0] = comps_all
      local i = 1
      while i <= #members do
        local k = members[i]
        w = w + wcell[k]
        if k == hqk then has_hq = true end
        local cx, cy = Base.unkey(k)
        for dx = -1, 1 do
          for dy = -1, 1 do
            local nk = Base.key(cx + dx, cy + dy)
            if dense[nk] and not comp_of[nk] then
              comp_of[nk] = comps_all
              members[#members + 1] = nk
            end
          end
        end
        i = i + 1
      end
      -- Le QG touche la composante (case voisine dense) : elle est celle de la base principale.
      if not has_hq and hqk then
        local hx, hy = Base.unkey(hqk)
        for _, k in ipairs(members) do
          local cx, cy = Base.unkey(k)
          if math.abs(cx - hx) <= 1 and math.abs(cy - hy) <= 1 then has_hq = true break end
        end
      end
      if has_hq or w >= min_w then
        comps = comps + 1
        for _, k in ipairs(members) do keep[#keep + 1] = k end
      end
    end
  end
  if hqk then keep[#keep + 1] = hqk end
  local cells, n = {}, 0
  for _, k in ipairs(keep) do
    local cx, cy = Base.unkey(k)
    for dx = -margin, margin do
      for dy = -margin, margin do
        local nk = Base.key(cx + dx, cy + dy)
        if not cells[nk] then cells[nk] = true n = n + 1 end
      end
    end
  end
  return { t = tick or 0, cells = cells, n = n, dense = #dkeys, comps = comps, comps_all = comps_all, w = total, ents = #ents,
    hq = hqk }
end

--- La position (x, y) est-elle dans la zone de base ?
function Base.contains(zone, x, y)
  if not zone then return false end
  return zone.cells[Base.key(Base.cell(x), Base.cell(y))] == true
end

--- La zone doit-elle être recalculée à `tick` ?
function Base.stale(zone, tick)
  return zone == nil or tick - (zone.t or 0) >= Base.PERIOD or tick < (zone.t or 0)
end

--- Morts de l'heure à moins de r tuiles d'une liste de points (même règle que D.deaths_near : morts au QG exclues, chacune comptée
--- une fois), réparties DANS la zone de base et HORS d'elle. deaths = { { x, y, t, home }, ... } ; hour = fenêtre (ticks).
--- Renvoie n_dans, n_hors.
function Base.split_deaths(zone, deaths, pts, r, tick, hour)
  local r2, n_in, n_out = r * r, 0, 0
  for _, d in ipairs(deaths) do
    if tick - d.t < hour and not d.home then
      for _, p in ipairs(pts) do
        local dx, dy = p.x - d.x, p.y - d.y
        if dx * dx + dy * dy <= r2 then
          if Base.contains(zone, d.x, d.y) then n_in = n_in + 1 else n_out = n_out + 1 end
          break
        end
      end
    end
  end
  return n_in, n_out
end

--- Surface de la zone, en tuiles carrées (journal).
function Base.area(zone)
  return zone and zone.n * Base.CELL * Base.CELL or 0
end

return Base
