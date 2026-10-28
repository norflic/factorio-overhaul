--[[
  Lot RESEAU-VIVANT (29/10) : MESURE À VIDE du réseau électrique d'une force, hors BILAN, à ajouter au rapport de
  scenarios/fonction_common.lua (genre « reseau » et « poteau »). Aucune lecture n'entre dans un BILAN ; rien n'est écrit
  dans la partie. Ce fichier ne touche pas au mod : il lit.

  Ce que la mesure répond (docs/PORTES_MESURES.md : jamais un seuil avant d'avoir vu la distribution) :
   - PAIRES serrées : paires de poteaux de MÊME nom à moins de 2 tuiles l'un de l'autre (centre à centre) ;
   - POTEAUX REDONDANTS (définition FONCTIONNELLE, la même que R.loss de shared/team/reseau.lua) : un poteau d'une
     composante qui touche une centrale est redondant quand son retrait seul ne change pas l'ensemble des consommateurs
     alimentés ; `glouton` = nombre de poteaux qu'on peut retirer l'un après l'autre sans rien éteindre (une passe, ordre
     d'indice : un minorant du maximum) ;
   - CONSOMMATEURS : posés, sous AUCUNE aire de poteau (sans_poteau), couverts mais sur une composante sans centrale
     (ilots), alimentés (couverts par une composante qui touche une centrale) ;
   - COMPOSANTES du réseau de poteaux, avec ou sans centrale.
  Modèle : un consommateur est couvert quand sa boîte chevauche (surface strictement positive) l'aire d'un poteau ; les fils
  sont ceux du moteur (neighbours.copper) ; une centrale (machine à vapeur) est couverte de la même façon.
  Pur sauf Z.read (qui lit le moteur) : testé hors jeu par tools/autotest/tests/test_fonction_reseau.lua.
]]

local Z = {}

Z.PAIR_DIST = 2.0
Z.EPS = 1e-6
Z.MAX_POLES = 600   -- au-delà, le glouton est sauté (coût) : la ligne le dit

local floor = math.floor

--- Recouvrement strictement positif de la boîte b par l'aire d'alimentation du poteau p.
local function covers(p, b)
  local s, e = p.supply, Z.EPS
  return b.x0 < p.x + s - e and b.x1 > p.x - s + e and b.y0 < p.y + s - e and b.y1 > p.y - s + e
end
Z.covers = covers

local function gk(cx, cy) return (cx + 100000) * 200003 + (cy + 100000) end

--- Mesure. poles[i] = { x, y, name, supply, nb = { indices des voisins par fil } } ; cons[k] et prods[k] = boîtes
--- { x0, y0, x1, y1 }. Rend la table des mesures (voir le haut du fichier).
function Z.measure(poles, cons, prods)
  local n = #poles
  local R = { poles = n, cons = #cons, prods = #prods }

  -- paires serrées (même nom, centre à centre < PAIR_DIST ; et < 1,01 : poteaux contigus)
  local grid = {}
  for i = 1, n do
    local k = gk(floor(poles[i].x / Z.PAIR_DIST), floor(poles[i].y / Z.PAIR_DIST))
    local g = grid[k]
    if not g then g = {}; grid[k] = g end
    g[#g + 1] = i
  end
  local pairs2, pairs1 = 0, 0
  local in_pair = {}
  for i = 1, n do
    local p = poles[i]
    local cx, cy = floor(p.x / Z.PAIR_DIST), floor(p.y / Z.PAIR_DIST)
    for dx = -1, 1 do
      for dy = -1, 1 do
        local g = grid[gk(cx + dx, cy + dy)]
        if g then
          for _, j in ipairs(g) do
            if j > i and poles[j].name == p.name then
              local d2 = (p.x - poles[j].x) ^ 2 + (p.y - poles[j].y) ^ 2
              if d2 < Z.PAIR_DIST * Z.PAIR_DIST - Z.EPS then
                pairs2 = pairs2 + 1
                in_pair[i], in_pair[j] = true, true
                if d2 < 1.01 * 1.01 then pairs1 = pairs1 + 1 end
              end
            end
          end
        end
      end
    end
  end
  R.pairs_lt2, R.pairs_lt1 = pairs2, pairs1
  local ip = 0
  for i = 1, n do if in_pair[i] then ip = ip + 1 end end
  R.poles_in_pair = ip
  R.in_pair = in_pair

  -- couvertures
  local cover_c, cover_p = {}, {}
  for k, b in ipairs(cons) do
    local l = {}
    for i = 1, n do if covers(poles[i], b) then l[#l + 1] = i end end
    cover_c[k] = l
  end
  for k, b in ipairs(prods) do
    local l = {}
    for i = 1, n do if covers(poles[i], b) then l[#l + 1] = i end end
    cover_p[k] = l
  end

  -- évaluation : composantes sans les poteaux de `gone`, consommateurs alimentés (couverts par une composante à centrale)
  local function eval(gone)
    local comp, nc = {}, 0
    local stack = {}
    for s = 1, n do
      if not gone[s] and not comp[s] then
        nc = nc + 1
        comp[s] = nc
        stack[1] = s
        local top = 1
        while top > 0 do
          local v = stack[top]
          top = top - 1
          for _, w in ipairs(poles[v].nb or {}) do
            if not gone[w] and not comp[w] then comp[w] = nc; top = top + 1; stack[top] = w end
          end
        end
      end
    end
    local touch = {}
    for k = 1, #prods do
      for _, i in ipairs(cover_p[k]) do if not gone[i] then touch[comp[i]] = true end end
    end
    local powered, cov, ils = 0, 0, 0
    for k = 1, #cons do
      local live, any = false, false
      for _, i in ipairs(cover_c[k]) do
        if not gone[i] then
          any = true
          if touch[comp[i]] then live = true break end
        end
      end
      if live then powered = powered + 1 elseif any then ils = ils + 1 end
      if any then cov = cov + 1 end
    end
    return powered, cov, ils, comp, nc, touch
  end

  R.eval = eval -- lot RESEAU-VIVANT : pour choisir un poteau pivot dans les scénarios d'événement (reseau-detruit)
  local powered, covered, islands, comp, nc, touch = eval({})
  R.powered = powered
  R.sans_poteau = #cons - covered
  R.ilots = islands
  R.comps = nc
  local live_comps = 0
  for c = 1, nc do if touch[c] then live_comps = live_comps + 1 end end
  R.comps_gen = live_comps
  local live = {}
  local n_live = 0
  for i = 1, n do
    if touch[comp[i]] then live[#live + 1] = i; n_live = n_live + 1 end
  end
  R.poles_live = n_live
  R.poles_hors_service = n - n_live
  R.poles_per_powered = powered > 0 and n_live / powered or 0

  -- redondance : retrait seul, puis glouton (une passe, ordre d'indice)
  if n_live > Z.MAX_POLES then
    R.skipped = true
    R.single, R.glouton = -1, -1
    return R
  end
  local single = 0
  local removable = {}
  for _, i in ipairs(live) do
    local pw = eval({ [i] = true })
    if pw == powered then single = single + 1; removable[i] = true end
  end
  local gone, glouton = {}, 0
  for _, i in ipairs(live) do
    if removable[i] then
      gone[i] = true
      local pw = eval(gone)
      if pw == powered then glouton = glouton + 1 else gone[i] = nil end
    end
  end
  R.single, R.glouton = single, glouton
  R.removable = removable
  R.gone = gone
  R.comp = comp
  return R
end

---------------------------------------------------------------------------------------------------
-- Lecture du moteur
---------------------------------------------------------------------------------------------------
local function box_of(e)
  local b = e.bounding_box
  return { x0 = b.left_top.x, y0 = b.left_top.y, x1 = b.right_bottom.x, y1 = b.right_bottom.y }
end

--- Lit les poteaux, consommateurs (listes d'entités) et centrales de la force. `cons_ents` et `prod_ents` : listes d'entités
--- du moteur. Rend poles (au format de Z.measure), cons, prods, et la liste d'entités de poteaux (même ordre).
function Z.read(s, force, cons_ents, prod_ents)
  local ents = s.find_entities_filtered({ force = force, type = "electric-pole" })
  table.sort(ents, function(a, b) return a.unit_number < b.unit_number end)
  local idx = {}
  for i, e in ipairs(ents) do idx[e.unit_number] = i end
  local poles = {}
  for i, e in ipairs(ents) do
    local nb = {}
    local ok, nbs = pcall(function() return e.neighbours end)
    local copper = ok and nbs and nbs.copper or {}
    for _, o in ipairs(copper) do
      local j = o.valid and idx[o.unit_number]
      if j then nb[#nb + 1] = j end
    end
    table.sort(nb)
    poles[i] = { x = e.position.x, y = e.position.y, name = e.name, supply = e.prototype.supply_area_distance or 2.5, nb = nb,
      unit = e.unit_number }
  end
  local cons, prods = {}, {}
  for _, e in ipairs(cons_ents) do if e.valid then cons[#cons + 1] = box_of(e) end end
  for _, e in ipairs(prod_ents) do if e.valid then prods[#prods + 1] = box_of(e) end end
  return poles, cons, prods, ents
end

local function f2(x) return string.format("%.2f", x) end

--- Ligne de rapport (valeurs sans espace) pour une mesure.
function Z.line(R)
  return string.format(
    "poteaux=%d en_service=%d hors_service=%d paires_lt2=%d paires_lt1=%d poteaux_en_paire=%d redondants_seuls=%d redondants_glouton=%d"
    .. " conso=%d alimentes=%d sans_poteau=%d ilots=%d composantes=%d composantes_centrale=%d poteaux_par_alimente=%s%s",
    R.poles, R.poles_live, R.poles_hors_service, R.pairs_lt2, R.pairs_lt1, R.poles_in_pair, R.single, R.glouton, R.cons,
    R.powered, R.sans_poteau, R.ilots, R.comps, R.comps_gen, f2(R.poles_per_powered), R.skipped and " glouton_saute=1" or "")
end

return Z
