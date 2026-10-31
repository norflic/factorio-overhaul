--[[
  GISEMENTS (retour du DC du 31/10 en jouant la 0.6.27 : « le cuivre est oublié, le gisement est à côté », « les foreuses
  thermiques occupent le gisement et ne fonctionnent plus », « il ne faut pas s'arrêter à 80 % du champ »). Règles PURES :
  aucune API Factorio, aucun nom d'objet (tests/gisement_test.lua).

  G.penurie(rows)                 -> matières les plus en manque PAR RAPPORT AU BESOIN (toutes les matières, fondues ou non).
  G.band(theta)                   -> bande de couverture d'un objet (0 = rien, G.BAND_MAX = couvert).
  G.reorder(list, band_of)        -> les options de matière passent par bande de pénurie, les autres gardent leur place.
  G.site_redundant(site, opened)  -> un gisement voisin du même minerai a encore des places : pas d'avant-poste de plus.
  G.verdict(d, cfg)               -> foreuse à combustion : garder, remplacer, rebrancher ou retirer.
  G.forbid_pairs(s)               -> plus de paire foreuse + four posée sur le minerai quand l'électrique est possible.
  Déterminisme : listes triées, égalités par nom, aucun `pairs` décisionnel, aucun temps mesuré.
]]

local G = {}

G.BAND = 0.25            -- largeur d'une bande de couverture (rapport production + stock / besoin)
G.BAND_MAX = 4           -- couverture complète (rapport >= 1)
G.STARVE_THETA = 0.5     -- sous ce rapport, la matière MANQUE (la pile laisse passer son investissement de production)
G.NEED_FLOOR_PCT = 50    -- besoin plancher : part du plus grand besoin ; une matière oubliée (besoin nul) manque quand même
G.NEAR = 96              -- tuiles : un gisement ouvert à moins de cela d'un site rend un avant-poste inutile
G.IDLE = 5 * 3600        -- ticks à l'arrêt avant qu'une foreuse soit jugée
G.RETIRE = 15 * 3600     -- ticks à l'arrêt avant retrait si un remplacement électrique n'est pas prêt
G.HARD = 40 * 3600       -- ticks à l'arrêt : retrait même si le remplacement est « prêt » (il n'a pas eu lieu)

local floor, max, min = math.floor, math.max, math.min

--- rows = { { item, items (facultatif : autres objets de la matière, ex. sa plaque), have, need } } dans un ordre quelconque.
--- Rend { theta = { [objet] = rapport }, starved = { [objet] = true }, ranking = { objet... } } ; classement : rapport croissant,
--- égalité par nom. Le besoin plancher (NEED_FLOOR_PCT du plus grand besoin) fait manquer une matière dont personne ne parle.
function G.penurie(rows)
  local top = 0
  for _, r in ipairs(rows or {}) do top = max(top, r.need or 0) end
  local floor_need = top * G.NEED_FLOOR_PCT / 100
  local list, theta, starved = {}, {}, {}
  for _, r in ipairs(rows or {}) do
    local need = max(r.need or 0, floor_need)
    if need > 0 then
      local th = (r.have or 0) / need
      theta[r.item] = th
      list[#list + 1] = { item = r.item, theta = th }
      if th < G.STARVE_THETA then
        starved[r.item] = true
        for _, it in ipairs(r.items or {}) do starved[it] = true end
      end
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

--- d = { idle (ticks à l'arrêt, 0 si elle travaille), dead (plus de minerai), sink ("ok", "manque", "plein"), can_sink (un
--- réceptacle est au stock), ready (un remplacement électrique est prêt) }. Rend (verdict, raison).
function G.verdict(d, cfg)
  cfg = cfg or G
  if (d.idle or 0) < cfg.IDLE then return "garder", "travaille ou arret court" end
  if d.dead then return "retirer", "gisement epuise sous la foreuse" end
  if d.sink == "manque" and d.can_sink then return "rebrancher", "plus de four : reposer un recepteur" end
  if d.ready and d.idle < cfg.HARD then return "remplacer", "remplacement electrique pret" end
  if d.idle >= cfg.RETIRE then return "retirer", "a l'arret et sans remplacement" end
  return "garder", "arret a surveiller"
end

--- s = { sink_furnace (le réceptacle du minerai est un four), swap_done, swap_ready, retired } : plus de paire foreuse + four posée sur
--- le minerai quand l'électrique est possible (foreuses remplacées ou prêtes à l'être) ou a déjà dû retirer des paires.
function G.forbid_pairs(s)
  if not (s and s.sink_furnace) then return false end
  return (s.swap_done or 0) > 0 or (s.swap_ready or 0) > 0 or (s.retired or 0) > 0
end

return G
