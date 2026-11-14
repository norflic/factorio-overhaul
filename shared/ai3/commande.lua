--[[
  Lot s43 UX-COMMANDE (pilier B, agent 5) : les ORDRES du joueur à son équipe d'IA, sans micro-gestion. PUR (aucune API Factorio,
  aucun nom d'objet ni de bâtiment : les types d'avant-poste et leurs ressources viennent de shared/team/config.lua par l'appelant).

  Trois sortes d'ordres, rangés dans l'état de l'équipe (f.team.commande, tables simples, entiers et chaînes) :
    orientation  « aucune » (défaut), « expansion » (Expansion économique), « amelioration » (Amélioration massive),
                 « defense » (Défense / Offensive) : un pourcentage BORNÉ appliqué aux poids des familles des buts
                 (B.weights, 500 à 2 000 pour mille) : Co.weights ;
    gisement     une zone (centre, rayon) et sa ressource : un but d'extraction de valeur Co.ORDER_VALUE pour son type
                 d'avant-poste (Co.goals) et, au choix du site, les sites de la réserve DANS la zone passent d'abord (Co.prefer,
                 Co.restrict) ; l'ordre est rempli quand un avant-poste de ce type est posé dans la zone (Co.resolve) ;
    liaison      une zone : les paires quai / sortie dont un bout est dans la zone passent d'abord au relevé des liaisons
                 (Co.prefer_pairs) ; l'ordre reste tant que le joueur ne l'annule pas.
  Ces règles sont celles de TOUTE équipe (chemin des factions : buts, choix du site, relevé des liaisons) ; seule l'interface du joueur en écrit.
  Déterminisme : listes dans l'ordre de pose (numéros croissants), tris stables par indice, aucun pairs, aucun hasard.
]]

local Co = {}

Co.ORIENTATIONS = { "aucune", "economie", "defense", "expansion", "recherche", "amelioration" } -- s44 : Économie et Recherche ajoutées
-- Pourcentage appliqué au poids de chaque famille (absent : 100). Bornes : Co.PCT_MIN à Co.PCT_MAX, puis le poids final dans
-- [w_min, w_max] (ceux de B.weights) : une orientation ne sort jamais le cerveau de sa plage.
Co.PCT = {
  aucune = {},
  expansion = { extraction = 160, capital = 120, recherche = 90, defense = 85, armee = 80 },
  amelioration = { capital = 160, recherche = 150, extraction = 90, armee = 80 },
  defense = { defense = 170, armee = 170, extraction = 90, capital = 85, recherche = 85 },
  economie = { capital = 160, extraction = 130, recherche = 90, defense = 85, armee = 80 },
  recherche = { recherche = 180, capital = 110, extraction = 90, defense = 90, armee = 80 },
}
-- s44 commande-cablage : orientations qui lèvent « la production d'abord » (shared/team/priorite.lua) dans la capitalisation : sans
-- cela, la part de la défense et de l'armée y valait 0 pour votre équipe et « Défense » ne changeait rien (journal du DC, d=0 a=0).
Co.LIFT_PF = { defense = true }

--- « La production d'abord » après l'orientation : levée par une orientation de Co.LIFT_PF, inchangée sinon.
function Co.production_first(pf, orient)
  if pf and Co.LIFT_PF[orient or "aucune"] then return false end
  return pf
end
Co.PCT_MIN, Co.PCT_MAX = 50, 200
Co.ORDER_VALUE = 88   -- but d'un gisement désigné : sous l'amorçage du fer (92) et du charbon (90), au-dessus de la croissance (55)
Co.MAX_ORDERS = 8     -- ordres vivants au plus (gisements et liaisons ensemble)
Co.R_MIN, Co.R_MAX = 8, 96 -- rayon d'une zone (tuiles)
Co.DONE_MARGIN = 16   -- un avant-poste posé à rayon + 16 tuiles du centre remplit l'ordre de gisement
Co.SITE_MARGIN = 24   -- un site de la réserve (centre de sonde, à un demi-chunk près) à rayon + 24 tuiles est dans la zone

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

function Co.valid_orientation(o)
  for _, k in ipairs(Co.ORIENTATIONS) do if k == o then return true end end
  return false
end

--- État vierge (rangé par l'appelant dans f.team.commande).
function Co.new_state()
  return { orient = "aucune", orders = {}, next_id = 1 }
end

--- Poids des familles après l'orientation : copie de `w`, chaque famille × pourcentage borné, puis bornée à [w_min, w_max].
--- Orientation inconnue ou « aucune » : copie inchangée.
function Co.weights(w, orient, w_min, w_max, families)
  local out = {}
  local pct = Co.PCT[orient or "aucune"] or {}
  for _, fam in ipairs(families) do
    local v = (w or {})[fam]
    if v ~= nil then
      local p = clamp(pct[fam] or 100, Co.PCT_MIN, Co.PCT_MAX)
      if p ~= 100 then v = clamp(math.floor(v * p / 100), w_min, w_max) end
      out[fam] = v
    end
  end
  return out
end

--- Zone d'une sélection { {x0, y0}, {x1, y1} } : centre et rayon (demi-diagonale bornée).
function Co.zone(x0, y0, x1, y1)
  local cx, cy = math.floor((x0 + x1) / 2), math.floor((y0 + y1) / 2)
  local dx, dy = math.abs(x1 - x0) / 2, math.abs(y1 - y0) / 2
  local r = math.floor(math.sqrt(dx * dx + dy * dy))
  return cx, cy, clamp(r, Co.R_MIN, Co.R_MAX)
end

--- Ressource majoritaire d'une liste de noms (égalité : le plus petit nom), ou nil.
function Co.majority(names)
  local n, order = {}, {}
  for _, nm in ipairs(names or {}) do
    if n[nm] == nil then n[nm] = 0; order[#order + 1] = nm end
    n[nm] = n[nm] + 1
  end
  table.sort(order)
  local best = nil
  for _, nm in ipairs(order) do if best == nil or n[nm] > n[best] then best = nm end end
  return best
end

--- Type d'avant-poste qui extrait `resource` (premier de `order` dont outposts[k].resource == resource), ou nil.
function Co.kind_of(resource, outposts, order)
  for _, k in ipairs(order or {}) do
    if outposts[k] and outposts[k].resource == resource then return k end
  end
  return nil
end

--- Ajoute un ordre { kind = "gisement" | "liaison" | "amelioration", x, y, r, resource?, outpost?, tick }. Rend son numéro, ou nil et la raison
--- (« plein » : Co.MAX_ORDERS atteint ; « type » : sorte inconnue ; « ressource » : gisement sans type d'avant-poste).
function Co.add(state, o)
  if o.kind ~= "gisement" and o.kind ~= "liaison" and o.kind ~= "amelioration" then return nil, "type" end
  if o.kind == "gisement" and not o.outpost then return nil, "ressource" end
  if #state.orders >= Co.MAX_ORDERS then return nil, "plein" end
  local id = state.next_id
  state.next_id = id + 1
  state.orders[#state.orders + 1] = { id = id, kind = o.kind, x = o.x, y = o.y, r = clamp(o.r or Co.R_MIN, Co.R_MIN, Co.R_MAX),
    resource = o.resource, outpost = o.outpost, tick = o.tick or 0, surface = o.surface,
    a = o.a and { x = o.a.x, y = o.a.y, r = clamp(o.a.r or Co.R_MIN, Co.R_MIN, Co.R_MAX) } or nil,
    after_oid = o.after_oid } -- s44 : dernier numéro d'avant-poste à la pose de l'ordre (Co.resolve ne compte que les suivants)
  return id
end

--- Retire l'ordre `id`. Rend l'ordre retiré ou nil.
function Co.cancel(state, id)
  for i, o in ipairs(state.orders) do
    if o.id == id then return table.remove(state.orders, i) end
  end
  return nil
end

local function inside(o, x, y, margin)
  local dx, dy = x - o.x, y - o.y
  local r = o.r + (margin or 0)
  return dx * dx + dy * dy <= r * r
end
Co.inside = inside

--- Numéros des ordres touchés par une zone (annulation au bouton droit) : le centre de l'ordre dans la zone, ou la zone dans l'ordre.
function Co.hit(state, x0, y0, x1, y1)
  local out = {}
  local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
  for _, o in ipairs(state.orders) do
    if (o.x >= math.min(x0, x1) and o.x <= math.max(x0, x1) and o.y >= math.min(y0, y1) and o.y <= math.max(y0, y1))
      or inside(o, cx, cy) then out[#out + 1] = o.id end
  end
  return out
end

--- Ordres de gisement vivants (données pour le cerveau) : { { id, outpost, resource, x, y, r } }.
function Co.deposits(state)
  local out = {}
  for _, o in ipairs((state or {}).orders or {}) do
    if o.kind == "gisement" then out[#out + 1] = o end
  end
  return out
end

--- Ordres de gisement PRÊTS : ceux dont la zone contient un site de la réserve (même ressource). Seuls ceux-là font un but : sans site
--- dans la zone, le but ferait bâtir ailleurs, à chaque pensée (le site pris par un chantier quitte la réserve : plus de but en double).
function Co.ready(orders, prospects)
  local out = {}
  for _, o in ipairs(orders or {}) do
    if o.kind == "gisement" then
      for _, s in ipairs(prospects or {}) do
        if (o.resource == nil or o.resource == s.resource) and inside(o, s.x, s.y, Co.SITE_MARGIN) then out[#out + 1] = o break end
      end
    end
  end
  return out
end

--- Buts du cerveau après les ordres de gisement : un but d'extraction (« ordre:<type> ») par type désigné, de valeur Co.ORDER_VALUE
--- (× poids d'extraction, bornée à 100) ; un but d'extraction déjà émis pour ce type est relevé à cette valeur s'il est plus bas
--- (et n'est plus « fond » ni « extend_only » : l'ordre demande un NOUVEAU site). Rend la liste (même table, complétée).
function Co.goals(goals, orders, w_ext, products)
  if not orders or #orders == 0 then return goals end
  local v = clamp(math.floor(Co.ORDER_VALUE * (w_ext or 1000) / 1000), 1, 100)
  v = math.max(v, Co.ORDER_VALUE) -- un poids d'extraction bas ne fait pas passer l'ordre du joueur sous sa valeur
  local seen = {}
  for _, o in ipairs(orders) do
    local k = o.outpost
    if k and not seen[k] then
      seen[k] = true
      local hit = false
      for _, g in ipairs(goals) do
        if g.family == "extraction" and g.outpost == k and not g.extend_only then
          hit = true
          if (g.value or 0) < v then g.value = v end
          g.fond, g.ordre = nil, o.id
        end
      end
      if not hit then
        goals[#goals + 1] = { key = "ordre:" .. k, family = "extraction", kind = "outpost", outpost = k, value = v, want = 1,
          why = (products or {})[k], ordre = o.id }
      end
    end
  end
  return goals
end

--- Réserve de sites réordonnée : ceux dans une zone de gisement désignée (même ressource) d'abord, l'ordre relatif gardé. Nouvelle liste.
function Co.prefer(list, orders)
  if not orders or #orders == 0 then return list end
  local first, rest = {}, {}
  for _, s in ipairs(list or {}) do
    local hit = false
    for _, o in ipairs(orders) do
      if o.kind == "gisement" and (o.resource == nil or o.resource == s.resource) and inside(o, s.x, s.y, Co.SITE_MARGIN) then hit = true break end
    end
    if hit then first[#first + 1] = s else rest[#rest + 1] = s end
  end
  if #first == 0 then return list end
  for _, s in ipairs(rest) do first[#first + 1] = s end
  return first
end

--- s44 : le site `s` est-il dans une zone de gisement désignée de sa ressource ? (la garde de distance R3 de Sites.find ne le retient pas)
function Co.designated(s, orders)
  for _, o in ipairs(orders or {}) do
    if o.kind == "gisement" and (o.resource == nil or o.resource == s.resource) and inside(o, s.x, s.y, Co.SITE_MARGIN) then return true end
  end
  return false
end

--- Candidats restreints aux sites d'une zone désignée s'il y en a (choix par valeur des factions) ; sinon la liste telle quelle.
function Co.restrict(cands, orders)
  if not orders or #orders == 0 then return cands end
  local out = {}
  for _, s in ipairs(cands or {}) do
    for _, o in ipairs(orders) do
      if o.kind == "gisement" and (o.resource == nil or o.resource == s.resource) and inside(o, s.x, s.y, Co.SITE_MARGIN) then
        out[#out + 1] = s
        break
      end
    end
  end
  if #out == 0 then return cands end
  return out
end

--- Paires du relevé des liaisons ({ dock = {x, y}, src = {x, y}, … }) : celles dont un bout est dans une zone de liaison d'abord.
function Co.prefer_pairs(pairs_, orders)
  if not orders or #orders == 0 then return pairs_ end
  local first, rest = {}, {}
  for _, pr in ipairs(pairs_ or {}) do
    local hit = false
    for _, o in ipairs(orders) do
      if o.kind == "liaison" and ((pr.dock and inside(o, pr.dock.x, pr.dock.y)) or (pr.src and inside(o, pr.src.x, pr.src.y))) then
        hit = true
        break
      end
    end
    if hit then first[#first + 1] = pr else rest[#rest + 1] = pr end
  end
  if #first == 0 then return pairs_ end
  for _, pr in ipairs(rest) do first[#first + 1] = pr end
  return first
end

--- s44 commande-liaison : paires IMPOSÉES par les ordres de liaison A -> B (o.a = zone de départ, o = zone d'arrivée), en tête du
--- relevé. Par ordre (numéro croissant) : la sortie libre (src, non liée) dans la zone A et le quai libre (dock, non lié) dans la zone
--- B qui portent le même objet, la plus courte distance d'abord (égalité : clés). Rend { { dock, src, span, ordre = id }, ... }.
function Co.forced_pairs(orders, docks, srcs)
  local out = {}
  for _, o in ipairs(orders or {}) do
    if o.kind == "liaison" and o.a then
      local best, bd
      for _, s in ipairs(srcs or {}) do
        if not s.linked and s.item and inside(o.a, s.x, s.y) then
          for _, d in ipairs(docks or {}) do
            if not d.linked and d.item == s.item and inside(o, d.x, d.y) then
              local dist = math.abs(d.x - s.x) + math.abs(d.y - s.y)
              if not best or dist < bd or (dist == bd and (d.key .. s.key) < (best.dock.key .. best.src.key)) then
                best, bd = { dock = d, src = s, span = dist, ordre = o.id }, dist
              end
            end
          end
        end
      end
      if best then out[#out + 1] = best end
    end
  end
  return out
end

--- Lot s44 COMMANDE-UPGRADE : zones d'amélioration prioritaire vivantes { { id, x, y, r, surface } } (ordre de pose). Un bâtiment de
--- l'équipe dans une de ces zones qui a une version supérieure passe en tête des remplacements (Co.upgrade_rank, Cap.replace_candidates)
--- tant que le joueur n'annule pas la zone.
function Co.upgrade_zones(state)
  local out = {}
  for _, o in ipairs((state or {}).orders or {}) do
    if o.kind == "amelioration" then out[#out + 1] = o end
  end
  return out
end

--- Rang d'amélioration d'une position : 0 dans une zone prioritaire, 1 ailleurs (zones absentes ou vides : 1).
function Co.upgrade_rank(zones, x, y)
  if x == nil or y == nil then return 1 end
  for _, o in ipairs(zones or {}) do
    if inside(o, x, y) then return 0 end
  end
  return 1
end

--- Ordres de gisement remplis : un avant-poste ({ kind, x, y, id }) du type demandé à rayon + Co.DONE_MARGIN du centre. Rend la liste des
--- numéros remplis (ordre de pose) ; ne modifie rien. s44 : un avant-poste DÉJÀ là à la pose de l'ordre (id <= o.after_oid) ne le
--- remplit pas (journal du DC 14/11 : ordres 4, 6, 7, 14 « remplis » en 2 s par l'avant-poste 1, rien de neuf construit).
function Co.resolve(state, outposts)
  local out = {}
  for _, o in ipairs(state.orders) do
    if o.kind == "gisement" then
      for _, op in ipairs(outposts or {}) do
        local new = not (o.after_oid and op.id) or op.id > o.after_oid
        if new and op.kind == o.outpost and inside(o, op.x, op.y, Co.DONE_MARGIN) then out[#out + 1] = o.id break end
      end
    end
  end
  return out
end

return Co
