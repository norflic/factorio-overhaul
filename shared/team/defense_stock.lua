--[[
  Lot DEFENSE-STOCK : les tourelles qui DORMENT au coffre sont POSÉES là où l'ennemi arrive. Règle PURE (aucune API Factorio, aucun nom
  d'objet), déterministe, testée hors jeu par tests/defense_stock_test.lua (avec mutants).

  Constat du DC (8/11, 0.6.65, 3 h de partie) : « ils ont toujours une quantité de tourelles en stock assez impressionnante, qui se
  défendent pas si bien que ça [...] si jamais j'avais pas posé de tourelles moi-même pour la défense, ils se seraient jamais défendus
  correctement. » Mesuré (sauvegarde du DC, 255 min) : scarlet 485 tourelles au coffre, constantes pendant 10 min, pour 39 à 43 posées ;
  cellules attaquées de score 3848 / 2975 / 2395 voulues 5 au plus (shared/team/front.lua F.CELL_CAP), QG à 2 tourelles « voulues 0 ».
  Toute la défense existante est une réponse à une PÉNURIE locale (le manque d'un poste voulu) : le stock n'est jamais une OFFRE.

  Règle : une tourelle au coffre est un bien déjà payé (coût matière 0). Au-dessus d'une petite réserve (S.RESERVE), le surplus est posé,
  par lots (S.LOT par voyage), en GROUPES qui se couvrent (jamais une tourelle isolée : après la pose, au moins S.MIN_GROUP à portée),
  aux lieux que l'ennemi vise, dans l'ordre : QG qui a perdu des tourelles, tourelles d'avance de la prévision, cellules attaquées (les
  plus attaquées d'abord, le groupe grandit avec le score, sans le plafond de 5 du front), avant-postes touchés, laboratoires.
  Le plafond du poste (S.TEAM_CAP tourelles posées par lui) borne le nombre d'entités.

  Entrées de S.plan (table p) :
    stock     = tourelles libres au coffre ; ammo = chargeurs libres ; ammo_each = chargeurs par tourelle à la pose
    placed    = tourelles déjà posées par ce poste (plafond d'équipe)
    zones     = { { key, kind, x, y, score, have, want, hold } } lieux candidats (le caller les relève ; `have` = tourelles à portée,
                `want` facultatif = voulues imposées par la prévision ou le QG, `hold` = vrai : ne PAS servir, cause en `why`)
    rest      = { [clé] = vrai } cellules au repos (pose à zéro, porteur tué)
    avoid     = clé d'une cellule que le front sert en ce moment (pas de course entre les deux postes)
    allow     = function(zone) -> ok, mot : vrai si le moteur autorise ce lieu, sinon faux et la cause en mot fixe (facultatif)
    zones[i].dist / .served = distance au QG (tuiles) et vrai si un avant-poste de l'équipe est à S.SERVED_R tuiles (« loin » sinon)
    turrets   = { { x, y } } toutes les tourelles de l'équipe (emplacements : le plus écarté d'abord)
    pause     = vrai : rien
  Rend { rows, pick, surplus } : rows = une ligne par zone (skip : « servie », « repos », « refus », « course », « plafond »,
  « stock », « groupe », « pause », « tenue », « loin », « munitions »), pick = { key, kind, x, y, score, have, want, count, ammo_each, sites } ou nil.

  Aucun `pairs`, aucune trigonométrie, aucun hasard, aucun temps mesuré.
]]
local Fr = require("shared.team.front")

local S = {}

S.RESERVE = 8          -- tourelles gardées au coffre (QG, remplacements, améliorations de niveau)
S.MIN_GROUP = 3        -- tourelles à portée après la pose : jamais une tourelle isolée
S.GROUP_CAP = 8        -- plafond d'un groupe par lieu
S.PER = 800            -- centièmes de score par tourelle de plus (le front : 400 pour au plus 5)
S.LOT = 4              -- tourelles portées par voyage au plus (un porteur tué en perd moins, F253)
S.TEAM_CAP = 48        -- tourelles posées par ce poste, par équipe
S.AMMO_FULL = 20       -- chargeurs par tourelle (cible ordinaire)
S.AMMO_LOW = 10        -- chargeurs par tourelle quand le coffre n'en a pas assez pour la cible
S.MIN_SCORE = 200      -- centièmes : deux coups pour compter (comme le front)
S.NEAR = 14            -- tuiles : « à portée » (comme le front ; le caller peut passer la portée réelle * 0,8)
S.MAX_DIST = 240       -- tuiles du QG : au-delà, un groupe n'est posé que près d'un avant-poste de l'équipe (les tournées de ravitaillement y passent)
S.SERVED_R = 48        -- tuiles : « près d'un avant-poste » (le caller relève `served`)
S.MALL_MARGIN = 16     -- tourelles au coffre gardées en plus de ce que le poste peut encore poser (montées de niveau, remplacements)
S.PRIO = 70            -- priorité de la tâche de pose (au-dessus des fabrications ordinaires, sous l'agrandissement 85 et les recharges 90)
S.PRIO_URGENT = 88     -- QG qui a perdu des tourelles, prévision d'une vague imminente

-- Ordre de service des genres : plus petit d'abord.
S.TIER = { qg = 1, prevu = 2, attaque = 3, site = 4, couverture = 5 }

--- Priorité de la tâche de pose selon le genre du lieu.
function S.prio(kind)
  if kind == "qg" or kind == "prevu" then return S.PRIO_URGENT end
  return S.PRIO
end

--- Lot s44 TOURELLES-STOCK : porte du planificateur sur la pose du stock. Une tourelle au coffre est déjà payée (coût matière 0) :
--- « production d'abord » (fer gardé pour la production, mode survie-pénurie compris) ne la retient plus quand le lieu est ATTAQUÉ
--- (genres qg, prevu, attaque, site : une perte ou une vague récente) ; il ne retient que la couverture des laboratoires (aucune attaque).
--- Une équipe décimée reste retenue (ses PNJ s'équipent d'abord). Rend nil (pose permise) ou le mot de la cause (« ressources »).
--- Constat (partie du DC 0.7.102, ambre 155,5 à 162 min) : « PRODUCTION d'abord » avec fer 1946, cellules attaquées de score 6462
--- à 0 tourelle sur 5, tourelles tuées à 161,6 min, et aucune ligne « [FO-DEFENSE] reserve » d'ambre de toute la partie.
S.ATTACKED = { qg = true, prevu = true, attaque = true, site = true }
function S.gate(kind, production_first, decimated)
  if decimated then return "ressources" end
  if production_first and not S.ATTACKED[kind] then return "ressources" end
  return nil
end

--- Plafond de stock des tourelles fabriquées d'avance (lu par script/team/intermediaires.lua, D10) : fabriquer au-delà de ce que le
--- poste peut encore poser est du gaspillage. = réserve + places restantes sous le plafond du poste + tourelles réservées par les
--- tâches ouvertes (`demand`) + marge. `placed` : tourelles déjà posées par le poste.
function S.stock_cap(placed, demand)
  local room = S.TEAM_CAP - (placed or 0)
  if room < 0 then room = 0 end
  local d = math.floor(demand or 0)
  if d < 0 then d = 0 end
  return S.RESERVE + room + d + S.MALL_MARGIN
end

--- Surplus : tourelles au-dessus de la réserve.
function S.surplus(stock)
  local s = (stock or 0) - S.RESERVE
  if s < 0 then s = 0 end
  return s
end

--- Tourelles voulues autour d'un lieu : l'imposé (QG, prévision) sinon S.MIN_GROUP plus une par tranche de score, au plus S.GROUP_CAP.
--- Un `want` imposé ne descend jamais sous S.MIN_GROUP (une tourelle de plus à côté de deux n'est pas un groupe de moins).
function S.group_want(kind, score, imposed)
  local w
  if imposed and imposed > 0 then
    w = imposed
  elseif kind == "attaque" then
    w = S.MIN_GROUP + math.floor((score or 0) / S.PER)
  else
    w = S.MIN_GROUP
  end
  if w < S.MIN_GROUP then w = S.MIN_GROUP end
  if w > S.GROUP_CAP then w = S.GROUP_CAP end
  return w
end

--- Chargeurs par tourelle que le coffre paie pour `n` tourelles : la cible si elle est payable, sinon la demi-dose, sinon nil.
function S.ammo_plan(n, ammo)
  if n <= 0 then return nil end
  if (ammo or 0) >= n * S.AMMO_FULL then return S.AMMO_FULL end
  if (ammo or 0) >= n * S.AMMO_LOW then return S.AMMO_LOW end
  return nil
end

--- Taille du lot d'un voyage : le manque du groupe, borné par S.LOT, le surplus, la place sous le plafond et les chargeurs payables.
--- Rend count, ammo_each (0, nil si rien). Réduit n tant que les chargeurs ne paient pas.
function S.lot(missing, surplus, room, ammo)
  local n = math.min(missing or 0, S.LOT, surplus or 0, room or 0)
  while n > 0 do
    local each = S.ammo_plan(n, ammo)
    if each then return n, each end
    n = n - 1
  end
  return 0, nil
end

--- s46 outils : un BASTION désigné par le joueur (zone.ordre) passe avant la réserve : il prend sur tout le stock (pas seulement le
--- surplus) et un groupe d'une tourelle lui suffit (le joueur l'a demandé). Ailleurs, la règle d'avant.
S.ORDER_MIN_GROUP = 1
function S.surplus_for(stock, ordre)
  if ordre then return math.max(0, stock or 0) end
  return S.surplus(stock)
end
function S.min_group(ordre)
  if ordre then return S.ORDER_MIN_GROUP end
  return S.MIN_GROUP
end

--- s46 outils : emplacements d'un bastion, en spirale autour du centre jusqu'au rayon `r` de l'ordre : points d'une grille de pas `step`
--- (au moins 2 tuiles, la tourelle), du plus proche au plus loin (égalité : y puis x). Sans trigonométrie, sans pairs. Au plus ~150
--- points : le pas grandit avec le rayon.
function S.spiral(x, y, r, step)
  r = math.max(0, math.floor(r or 0))
  step = step or math.max(2, math.ceil(r / 7))
  local cx, cy = math.floor(x), math.floor(y)
  local pts = {}
  local k = math.floor(r / step)
  for i = -k, k do
    for j = -k, k do
      local dx, dy = i * step, j * step
      local d2 = dx * dx + dy * dy
      if d2 <= r * r then pts[#pts + 1] = { x = cx + dx, y = cy + dy, d2 = d2 } end
    end
  end
  table.sort(pts, function(a, b)
    if a.d2 ~= b.d2 then return a.d2 < b.d2 end
    if a.y ~= b.y then return a.y < b.y end
    return a.x < b.x
  end)
  local out = {}
  for _, q in ipairs(pts) do out[#out + 1] = { x = q.x, y = q.y } end
  return out
end

local function order(rows)
  table.sort(rows, function(a, b)
    if (a.ordre and true or false) ~= (b.ordre and true or false) then return a.ordre == true end -- s46 : bastion du joueur d'abord
    local ta, tb = S.TIER[a.kind] or 9, S.TIER[b.kind] or 9
    if ta ~= tb then return ta < tb end
    if (a.score or 0) ~= (b.score or 0) then return (a.score or 0) > (b.score or 0) end
    return tostring(a.key) < tostring(b.key)
  end)
end

function S.plan(p)
  local surplus = S.surplus(p.stock)
  local room = S.TEAM_CAP - (p.placed or 0)
  if room < 0 then room = 0 end
  local rows = {}
  for _, z in ipairs(p.zones or {}) do
    local row = { key = z.key, kind = z.kind, x = z.x, y = z.y, score = z.score or 0, have = z.have or 0, dist = z.dist or 0,
      served = z.served and true or false, ordre = z.ordre and true or nil, zr = z.r }
    row.want = S.group_want(z.kind, z.score, z.want)
    row.missing = math.max(0, row.want - row.have)
    if z.hold then row.skip, row.why = "tenue", z.why end
    -- une attaque sous le seuil ne compte pas (bruit) : elle n'est pas servie
    if not row.skip and z.kind == "attaque" and row.score < S.MIN_SCORE then row.skip = "servie" end
    rows[#rows + 1] = row
  end
  order(rows)
  local pick = nil
  for _, r in ipairs(rows) do
    if not r.skip then
      if r.missing <= 0 then
        r.skip = "servie"
      elseif p.pause then
        r.skip = "pause"
      elseif pick then
        r.skip = "suivante" -- un seul lieu par pensée ; le suivant à la pensée d'après
      elseif p.avoid and p.avoid == r.key then
        r.skip = "course"
      elseif p.rest and p.rest[r.key] then
        r.skip = "repos"
      elseif r.dist > S.MAX_DIST and not r.served then
        r.skip = "loin" -- trop loin du QG et hors des tournées d'un avant-poste : le réarmement n'y passerait pas
      elseif room <= 0 then
        r.skip = "plafond"
      elseif S.surplus_for(p.stock, r.ordre) <= 0 then
        r.skip = "stock"
      else
        local ok, why = true, nil
        if p.allow then ok, why = p.allow(r) end
        if not ok then
          r.skip, r.why = "refus", why -- `why` : mot fixe (« ennemi », « sans_batiment », « danger »), jamais un texte libre
        else
          local n, each = S.lot(r.missing, S.surplus_for(p.stock, r.ordre), room, p.ammo)
          if n <= 0 then
            r.skip = "munitions"
          elseif r.have + n < S.min_group(r.ordre) then
            r.skip = "groupe" -- le lot n'en fait pas un groupe : on attend plus de stock plutôt que de poser une tourelle seule
          else
            -- s46 outils : un bastion cherche ses places en spirale dans tout le rayon de l'ordre (ses huit points d'anneau pouvaient tous
            -- tomber sur le minerai ou les arbres : 0 posée, lieu au repos, banc S46-OUTILS-2)
            pick = { key = r.key, kind = r.kind, x = r.x, y = r.y, score = r.score, have = r.have, want = r.want, count = n,
              ammo_each = each, ordre = r.ordre, zr = r.zr,
              sites = r.ordre and S.spiral(r.x, r.y, r.zr or Fr.ACCEPT) or Fr.sites(r.x, r.y, p.turrets) }
          end
        end
      end
    end
  end
  return { rows = rows, pick = pick, surplus = surplus, room = room }
end

return S
