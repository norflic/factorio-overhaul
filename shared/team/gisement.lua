--[[
  GISEMENTS (retour du DC du 31/10 en jouant la 0.6.27 : « le cuivre est oublié, le gisement est à côté », « les foreuses
  thermiques occupent le gisement et ne fonctionnent plus », « il ne faut pas s'arrêter à 80 % du champ »). Règles PURES :
  aucune API Factorio, aucun nom d'objet (tests/gisement_test.lua).

  G.rows(order, outposts, smelters, stock, need) -> lignes de G.penurie : minerai ET plaque d'un même type d'avant-poste ensemble.
  G.penurie(rows)                 -> matières les plus en manque PAR RAPPORT AU BESOIN (toutes les matières, fondues ou non).
  G.passent(pen, focus)              -> matières en manque que la retenue de la pile laisse passer.
  G.band(theta)                   -> bande de couverture d'un objet (0 = rien, G.BAND_MAX = couvert).
  G.reorder(list, band_of)        -> les options de matière passent par bande de pénurie, les autres gardent leur place.
  G.site_redundant(site, opened)  -> un gisement voisin du même minerai a encore des places : pas d'avant-poste de plus.
  G.verdict(d, cfg)               -> foreuse à combustion : garder, remplacer, ravitailler ou retirer (lot DECOUPLAGE : plus de
                                   « rebrancher » : aucun four n'est reposé au dépôt d'une foreuse).
  G.lot_for_ore(l, res, min)      -> un lot du treillis porte ce minerai : il sert de gisement, même si son état dit autre chose.
  G.forbid_pairs(s)               -> plus de paire foreuse + four posée sur le minerai quand l'électrique est possible.
  Déterminisme : listes triées, égalités par nom, aucun `pairs` décisionnel, aucun temps mesuré.
]]

local G = {}

G.BAND = 0.25            -- largeur d'une bande de couverture (rapport production + stock / besoin)
G.BAND_MAX = 4           -- couverture complète (rapport >= 1)
G.STARVE_THETA = 0.5     -- sous ce rapport, la matière MANQUE (la pile laisse passer son investissement de production)
G.NEED_FLOOR_PCT = 50    -- besoin plancher : part du plus grand besoin ; une matière oubliée (besoin nul) manque quand même
G.RICH_PCT = 5           -- besoin plancher : part du stock de la matière la mieux pourvue (déséquilibre 9 300 / 45, même sans besoin compté)
G.COVER_LOW = 0.3        -- dernier essai d'une foreuse électrique en bord de gisement (son débit ne dépend pas du nombre de tuiles)
G.ORE_SCAN = 5 * 3600    -- ticks entre deux relevés des lots pour un minerai que le treillis ne trouve pas
G.NEAR = 96              -- tuiles : un gisement ouvert à moins de cela d'un site rend un avant-poste inutile
G.IDLE = 5 * 3600        -- ticks à l'arrêt avant qu'une foreuse soit jugée
G.RETIRE = 15 * 3600     -- ticks à l'arrêt avant retrait si un remplacement électrique n'est pas prêt
G.HARD = 40 * 3600       -- ticks à l'arrêt : retrait même si le remplacement est « prêt » (il n'a pas eu lieu)

local floor, max, min = math.floor, math.max, math.min

--- Lignes de G.penurie, depuis les DONNÉES (shared/team/config.lua) : une ligne par type d'avant-poste, minerai et produit ensemble (les
--- clés d'`outposts` sont des TYPES, pas des objets) ; puis une ligne par produit de fonderie (`smelters`, liste triée) qui n'y est pas encore (sans plancher : un
--- produit que personne ne demande ne manque pas). need : le plus grand des deux besoins (l'un se déduit de l'autre, ils ne s'ajoutent pas).
function G.rows(order, outposts, smelters, stock, need)
  stock, need = stock or {}, need or {}
  local rows, seen = {}, {}
  for _, kind in ipairs(order or {}) do
    local sp = outposts[kind]
    local res, prod = sp.resource, sp.product
    local items, have = { res }, stock[res] or 0
    local nd = need[res] or 0
    if prod ~= res then
      items[2] = prod
      have = have + (stock[prod] or 0)
      nd = max(nd, need[prod] or 0)
    end
    seen[res], seen[prod] = true, true
    rows[#rows + 1] = { item = res, items = items, have = have, need = nd }
  end
  for _, p in ipairs(smelters or {}) do
    if not seen[p] then rows[#rows + 1] = { item = p, items = { p }, have = stock[p] or 0, need = need[p] or 0, no_floor = true } end
  end
  return rows
end

--- rows = { { item, items (facultatif : autres objets de la matière, ex. sa plaque), have, need, no_floor } } dans un ordre quelconque.
--- Rend { theta = { [objet] = rapport }, starved = { [objet] = true }, ranking = { objet... } } ; classement : rapport croissant,
--- égalité par nom. Le besoin plancher (NEED_FLOOR_PCT du plus grand besoin) fait manquer une matière dont personne ne parle.
function G.penurie(rows)
  local top, rich = 0, 0
  for _, r in ipairs(rows or {}) do
    top = max(top, r.need or 0)
    if not r.no_floor then rich = max(rich, r.have or 0) end
  end
  local floor_need = max(top * G.NEED_FLOOR_PCT / 100, rich * G.RICH_PCT / 100)
  local list, theta, starved = {}, {}, {}
  for _, r in ipairs(rows or {}) do
    local need = r.no_floor and (r.need or 0) or max(r.need or 0, floor_need)
    if need > 0 then
      local th = (r.have or 0) / need
      theta[r.item] = th
      list[#list + 1] = { item = r.item, theta = th }
      if th < G.STARVE_THETA then
        starved[r.item] = true
        for _, it in ipairs(r.items or {}) do starved[it] = true end
      end
      for _, it in ipairs(r.items or {}) do theta[it] = th end -- (lu par G.passent : la plaque a le rapport de sa matière)
    end
  end
  table.sort(list, function(a, b)
    if a.theta ~= b.theta then return a.theta < b.theta end
    return a.item < b.item
  end)
  local ranking = {}
  for _, e in ipairs(list) do ranking[#ranking + 1] = e.item end
  return { theta = theta, starved = starved, ranking = ranking }
end

--- Pile retenue : les matières en manque qui passent sa porte. Pas celle qu'une matière d'un cadre ouvert (`focus`) devance, plus en manque
--- qu'elle : ses foreuses se paient sur ce que la défense attend (fer à 60, tourelles à faire, cuivre à 60 : le fer d'abord). Le cuivre à 45
--- devant un fer à 9 300 passe. pen : résultat de G.penurie. Rend { [objet] = true } ; minimum d'un ensemble, aucun ordre lu.
function G.passent(pen, focus)
  local worst
  for k, on in next, focus or {} do
    local th = on and pen.theta[k]
    if th and (worst == nil or th < worst) then worst = th end
  end
  local out = {}
  for k in next, pen.starved do
    if worst == nil or (pen.theta[k] or 0) <= worst then out[k] = true end
  end
  return out
end

--- Bande d'un rapport de couverture : 0 (rien) à G.BAND_MAX (couvert). nil : G.BAND_MAX (objet sans besoin).
function G.band(theta)
  if theta == nil then return G.BAND_MAX end
  return floor(max(0, min(1, theta)) / G.BAND + 1e-9)
end

--- list : options déjà triées (meilleur retour d'abord). band_of(option) rend la bande d'une option de MATIÈRE, nil pour les autres
--- (laboratoires, courant, leviers) qui gardent leur PLACE. Les places des options de matière sont redistribuées par bande croissante
--- (la matière la plus en manque d'abord), l'ordre d'origine départageant. Rend une liste neuve.
function G.reorder(list, band_of)
  local slots, mats = {}, {}
  for i, o in ipairs(list) do
    local b = band_of(o)
    if b ~= nil then
      slots[#slots + 1] = i
      mats[#mats + 1] = { o = o, band = b, rank = i }
    end
  end
  table.sort(mats, function(a, b)
    if a.band ~= b.band then return a.band < b.band end
    return a.rank < b.rank
  end)
  local out = {}
  for i, o in ipairs(list) do out[i] = o end
  for k, i in ipairs(slots) do out[i] = mats[k].o end
  return out
end

--- site = { x, y }, opened = { { x, y, free, blocked, danger } } (gisements du MÊME minerai déjà ouverts). Rend (vrai, gisement)
--- quand l'un d'eux a des places, n'est ni interdit ni en danger, et se trouve à moins de G.NEAR du site. Coordonnées absentes :
--- faux (rien n'est supposé).
function G.site_redundant(site, opened, near)
  near = near or G.NEAR
  if not (site and site.x and site.y) then return false end
  local best, best_d
  for _, f in ipairs(opened or {}) do
    if f.x and f.y and (f.free or 0) > 0 and not f.blocked and not f.danger then
      local d = max(math.abs(f.x - site.x), math.abs(f.y - site.y))
      if d <= near and (best_d == nil or d < best_d) then best, best_d = f, d end
    end
  end
  return best ~= nil, best
end

--- d = { idle (ticks à l'arrêt, 0 si elle travaille), dead (plus de minerai), sink ("ok", "manque", "plein"), ready (un remplacement électrique est prêt), elec (l'électrique est possible : objet et courant), starved
--- (sa matière manque), no_fuel (elle ou son four sans combustible), can_fuel (combustible au stock) }. Rend (verdict, raison).
--- DC, 31/10 : « si jamais ils peuvent pas changer, au minimum qu'ils utilisent leur gisement » : on ne retire que si l'électrique peut
--- prendre la place, jamais une foreuse d'une matière en manque (sauf minerai épuisé) ; sinon elle est remise en marche.
function G.verdict(d, cfg)
  cfg = cfg or G
  if (d.idle or 0) < cfg.IDLE then return "garder", "travaille ou arret court" end
  if d.dead then return "retirer", "gisement epuise sous la foreuse" end
  local can_change = d.elec or d.ready
  local fuelable = d.no_fuel and d.can_fuel
  if fuelable and d.starved then return "ravitailler", "matiere en manque : combustible du stock" end
  if d.ready and d.idle < cfg.HARD then return "remplacer", "remplacement electrique pret" end
  if fuelable and not can_change then return "ravitailler", "pas d'electrique possible : combustible du stock" end
  if d.starved then return "garder", "matiere en manque : on ne retire pas sa production" end
  if can_change and d.idle >= cfg.RETIRE then return "retirer", "a l'arret et l'electrique peut prendre la place" end
  return "garder", can_change and "arret a surveiller" or "pas d'electrique possible : elle reste"
end

--- s = { sink_furnace (le réceptacle du minerai est un four), swap_done (électriques sur CET avant-poste), swap_ready, retired (paires retirées
--- de CET avant-poste), starved (sa matière manque) } : plus de paire foreuse + four posée sur le minerai quand l'électrique a pris ce
--- champ. Jamais pour une matière en manque (DC : « au minimum les foreuses thermiques ») : un refus du plan directeur ne doit pas la bloquer.
function G.forbid_pairs(s)
  if not (s and s.sink_furnace) or s.starved then return false end
  return (s.swap_done or 0) > 0 or (s.swap_ready or 0) > 0 or (s.retired or 0) > 0
end

--- l = lot du treillis { i, j, state, reason, used, out, ore, ore_n, ores } : porte-t-il assez de ce minerai pour une ligne de foreuses ?
--- Son état décrit le lot à son premier relevé et pour UNE ressource : une falaise, une flaque ou un minerai voisin plus abondant (ex. lot
--- à cheval sur deux gisements) le faisaient oublier alors que P.fit raisonne à la tuile. Jamais le lot du QG, un nid, un lot contesté.
function G.lot_for_ore(l, res, min_tiles)
  if not (l and res) or l.used or l.out or (l.i == 0 and l.j == 0) then return false end
  if l.state == "inconnu" then return false end
  if l.state == "refuse" and l.reason ~= "falaise" and l.reason ~= "eau" then return false end
  local n = (l.ores and l.ores[res]) or (l.ore == res and l.ore_n) or 0
  return n >= min_tiles
end

return G
