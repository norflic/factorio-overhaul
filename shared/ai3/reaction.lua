--[[
  Lot IA3-k : RÉACTION d'un PNJ qui voit un ennemi (C2), PEUR (C3), ENGAGEMENT d'un ouvrier armé en surnombre (C4)
  (docs/IA3K_COMPORTEMENTS.md §5). PUR (tests/ia3k_reaction_test.lua).

  Entrée s = {
    hp        vie (pour mille du maximum)       armed   arme ET munitions
    kind      genre de l'ennemi le plus proche (shared/ai3/danger.lua, D.KINDS)
    dist      distance à lui (tuiles)           range   sa portée (tuiles)
    on_route  il est à portée + marge du trajet restant
    enemies   force ennemie près de lui (pesée : moyen déchiqueteur = 1)   allies  alliés armés à moins de 16 tuiles
    walking   le PNJ marche                     prudence, agressivite (pour mille ; 1 000 neutre)
    repeats   arrêts et détours déjà faits devant des unités dans cette tournée
    backs     demi-tours déjà faits devant des unités (mémoire de Re.BACK_MEMORY ticks, tenue par le script)
  }
  Sortie : action, raison. Actions : "none" (rien : la case est seulement marquée), "flee" (fuite vers la tourelle amie
  ou le QG le plus proche), "back" (demi-tour : la tâche est rendue), "detour" (arrêt puis nouvel itinéraire), "stop"
  (arrêt de STOP_TICKS puis nouvel itinéraire), "engage" (combat sur place).
]]

local D = require("shared.ai3.danger")

local Re = {}

Re.MARGIN = 8
Re.STOP_TICKS = 180
Re.REPEATS = 2     -- arrêts ou détours devant des unités dans la même tournée avant de renoncer
Re.BACKS = 1       -- demi-tours déjà faits devant des unités avant que le suivant devienne une FUITE avec refuge
Re.BACK_MEMORY = 3600 -- ticks : au-delà, les demi-tours passés sont oubliés (un autre groupe, une autre tournée)
Re.AWAY_EXTRA = 24 -- tuiles : marge ajoutée à (portée + MARGIN) pour s'éloigner d'unités quand le QG est de leur côté
Re.HOME_CONE = 0.5 -- cosinus : l'ennemi est « du côté du QG » s'il est dans ce cône (60°) vers le QG et plus près que lui
Re.IDLE_LOOK = 180   -- ticks : un PNJ armé, sain et à l'arrêt regarde autour de lui au plus toutes les 3 s (étalé par numéro)
Re.ISOLATED = 1.5    -- force pesée au plus : un ennemi « isolé » qu'un ouvrier armé peut chasser ; au-delà, il ne tient pas seul
Re.EXEMPT = { garrison = true, fortify = true } -- tâches de défense : jamais rappelées ni mises à l'abri quand elles sont armées
Re.RALLY_R = 40      -- tuiles : les tourelles à moins de 40 tuiles du QG sont celles qui le défendent
Re.RALLY_BEHIND = 10 -- tuiles : le point de ralliement est 10 tuiles derrière le centre des tourelles, côté coffre
Re.OUTRUN = 0.9      -- l'ennemi est distancé s'il va à au plus 90 % de la vitesse du PNJ
Re.SITE_RATIO = 1000 -- lot DANGER-ACTIF (DC 4/11, 19 h 12 : « ... ou en défendant ») : rapport de force exigé pour s'engager sur un site de l'équipe
                     -- attaqué (soldats alertés) : la parité, au lieu de 1 500 à 3 000
Re.FEAR_BASE = 400  -- 40 % de vie (IA_ATTENDUS C3)
Re.FEAR_MAX = 550

--- Seuil de la peur (pour mille de vie) : 400 pour un neutre ou un audacieux, jusqu'à 550 pour un prudent.
function Re.fear(prudence)
  local t = math.floor(Re.FEAR_BASE * (prudence or 1000) / 900)
  if t < Re.FEAR_BASE then return Re.FEAR_BASE end
  if t > Re.FEAR_MAX then return Re.FEAR_MAX end
  return t
end

--- Rayon du regard (tuiles, autour d'un point LOOK_AHEAD tuiles devant le PNJ) : 40 (audacieux) à 56 (prudent).
-- Portée : voir une zone de gros ver (38 + 10) ou de béhémoth (48 + 10) avant d'y entrer : un gros ver naturel a tué 2 PNJ
-- en tournée avec un regard de 35 autour d'un point 16 tuiles devant (banc final-3958412 route-123456789).
Re.LOOK_AHEAD = 20
Re.LOOK_MIN = 40
Re.LOOK_MAX = 56
function Re.look_radius(prudence)
  local p = prudence or 1000
  local r = Re.LOOK_MIN + math.floor((p - 562) * (Re.LOOK_MAX - Re.LOOK_MIN) / 688)
  if r < Re.LOOK_MIN then return Re.LOOK_MIN end
  if r > Re.LOOK_MAX then return Re.LOOK_MAX end
  return r
end

--- Rapport de force voulu pour engager (pour mille) : 1 500 (agressif) à 3 000 (prudent).
function Re.engage_ratio(prudence, agressivite)
  local r = math.floor(2000 * (prudence or 1000) / math.max(1, agressivite or 1000))
  if r < 1500 then return 1500 end
  if r > 3000 then return 3000 end
  return r
end

--- Distance de fuite d'un PNJ sans arme : il part dès qu'un ennemi est à moins de ce rayon (24 à 36 selon la prudence).
function Re.flee_unarmed(prudence)
  local r = 24 + math.floor(((prudence or 1000) - 562) * 12 / 688)
  if r < 24 then return 24 end
  if r > 36 then return 36 end
  return r
end

--- Le regard périodique d'un PNJ armé, sain et à l'arrêt est-il dû ? `last` : tick du dernier (nil : jamais). Le premier est
-- décalé par le numéro du PNJ (53 est premier avec 180) : les PNJ d'une équipe ne regardent pas tous au même tick.
function Re.idle_look_due(tick, last, id)
  local from = last or -(((id or 0) * 53) % Re.IDLE_LOOK)
  return tick - from >= Re.IDLE_LOOK
end

--- Une tâche de défense (garnison, fortification, `defend`) n'est jamais rappelée ni mise à l'abri par la sécurité d'équipe.
function Re.recall_exempt(kind, defend)
  return Re.EXEMPT[kind] == true or defend == true
end

--- Une unité mobile vue pendant un ARRÊT (alerte) a-t-elle franchi portée + marge ? L'arrêt est alors rompu : le PNJ
-- ne reste pas aveugle 180 ticks devant des soldats qui marchent sur lui (banc fusion-60, PNJ 7 : 38 tuiles à l'arrêt,
-- 22 à la sortie de l'arrêt, tué 2 regards plus tard).
function Re.breach(kind, dist, range)
  local K = D.KINDS[kind] or D.KINDS.unit
  if K.fixed then return false end
  return (dist or 1e9) <= (range or K.r) + Re.MARGIN
end

--- Distance de fuite quand aucun refuge n'est du bon côté : portée de l'ennemi (lue au prototype) + marge + Re.AWAY_EXTRA.
function Re.away_distance(range)
  return (range or D.KINDS.unit.r) + Re.MARGIN + Re.AWAY_EXTRA
end

--- Refuge « loin de la menace » : si l'ennemi (ep) est du côté du QG (home) depuis le PNJ (p) et plus près que lui, courir
-- au QG, c'est courir sur l'ennemi. Rend alors le point à Re.away_distance(range) à l'opposé de l'ennemi, sinon nil.
function Re.away_point(p, home, ep, range)
  if not Re.on_the_way(p, home, ep) then return nil end
  return Re.away_from(p, ep, range)
end

--- Le point à Re.away_distance(range) de p, à l'opposé de l'ennemi (ep ; confondu avec p : vers l'est).
function Re.away_from(p, ep, range)
  local ex, ey = ep.x - p.x, ep.y - p.y
  local el = math.sqrt(ex * ex + ey * ey)
  if el < 1 then ex, ey, el = -1, 0, 1 end
  local d = Re.away_distance(range)
  return { x = p.x - d * ex / el, y = p.y - d * ey / el }
end

--- Relecture (revue-danger, 18 h 12, point 3) : « s'éloigner » en ligne droite (Re.away_from, ~62 tuiles, marchées sans itinéraire :
--- M.leg rend a.refuge tel quel) peut mener sur un ver, un nid, une autre meute ou là où des PNJ sont morts. Le cas devient
--- fréquent : tous les soldats des factions sont plus lents que 0,9 × 0,15, donc « distancés ». Huit directions, à 45° l'une de
--- l'autre à partir de l'opposé de l'ennemi, chacune jugée sur la carte du danger D de l'équipe (échantillons tous les
--- Re.AWAY_STEP tuiles jusqu'à Re.away_distance(range)) :
---   - une direction qui RAPPROCHE de l'ennemi (le trajet passe plus près de lui que le PNJ ne l'est) n'est jamais prise
---     (trois sur huit : à 135° et 180° de l'opposé) ;
---   - DANGER AJOUTÉ seulement (le PNJ fuit d'un endroit dangereux : ce qu'il a déjà autour de lui ne départage rien) : une
---     menace FIXE (ver, nid, tourelle, meute) dont la zone (portée + D.EXACT_MARGIN) contient déjà le PNJ ne compte qu'aux
---     points plus près d'elle que lui ; de même une MORT de l'heure (rayon D.DEATH_R, comptée une fois) ; les cases MOBILES
---     comptent pour ce qu'elles ont de plus que celle du PNJ ;
---   - SÛRE : aucune mort ajoutée et, en chaque point, menaces fixes + mobiles ajoutées < B (seuil de blocage, D.block).
--- Rend le point de la plus sûre (danger le plus bas, puis l'ordre 0°, +45°, −45°, +90°, −90°), ou nil si aucune n'est sûre
--- (le PNJ se bat alors groupé : « stand »). Second retour : { k = indice de la direction (0 à 7, sens trigonométrique de 45°),
--- danger = danger ajouté le plus haut, safe = nombre de directions sûres }.
Re.AWAY_STEP = 4
local ROT = math.sqrt(0.5)
local AWAY_PREF = { 0, 1, 7, 2, 6, 3, 5, 4 } -- ordre de préférence des directions (k × 45°)

local function away_dirs(ux, uy)
  local v = { [0] = { ux, uy } }
  for k = 1, 7 do
    local x, y = v[k - 1][1], v[k - 1][2]
    v[k] = { (x - y) * ROT, (x + y) * ROT } -- + 45°
  end
  return v
end

--- Relecture (seconde, point A : COÛT). Case mobile lue directement (map.cells et la décroissance de D.dec10, la formule de
--- danger.lua, sans la table de D.exact_parts), mémorisée par case pour l'appel (ou le passage : `mob`) ; menaces et morts
--- filtrées PAR DIRECTION (distance au segment au plus leur rayon : les autres n'y touchent aucun point). Mêmes résultats que la
--- version 878d3594 (tests/ia3k_reaction_test.lua : 400 cartes tirées au sort, référence recopiée).
local function mobile_at(map, tick, mob, x, y)
  local k = D.key(D.cell(x), D.cell(y))
  local m = mob[k]
  if m == nil then
    local c = map.cells[k]
    m = c and math.floor(c.m * D.dec10(tick - c.t) / 1000) or 0
    mob[k] = m
  end
  return m
end
Re.mobile_at = mobile_at

--- Direction de fuite (vecteur unitaire { x, y }) ou nil ; second retour : { k, danger, safe }. `mob` : mémo des cases mobiles
--- (facultatif ; valable pour une seule carte et un seul tick).
function Re.away_dir(map, tick, p, ep, range, B, mob)
  mob = mob or {}
  local ex, ey = p.x - ep.x, p.y - ep.y
  local el = math.sqrt(ex * ex + ey * ey)
  if el < 1 then ex, ey, el = 1, 0, 1 end
  local ux, uy = ex / el, ey / el
  local L = Re.away_distance(range)
  local dirs = away_dirs(ux, uy)
  local m0 = mobile_at(map, tick, mob, p.x, p.y)
  -- Menaces fixes et morts PROCHES (au plus L + leur rayon du PNJ), poids décrus calculés une fois.
  local fx, fy, fr2, fp2, fw, fr = {}, {}, {}, {}, {}, {}
  for _, t in ipairs(map.threats or {}) do
    local K = D.KINDS[t.k] or D.KINDS.unit
    local r = t.r + D.EXACT_MARGIN
    local dx, dy = t.x - p.x, t.y - p.y
    local dd = dx * dx + dy * dy
    if dd <= (L + r) * (L + r) then
      local i = #fx + 1
      fx[i], fy[i], fr2[i], fp2[i], fr[i] = t.x, t.y, r * r, dd, r
      fw[i] = math.floor(K.w * (K.fast and D.dec10(tick - t.t) or D.dec2(tick - t.t)) / 1000)
    end
  end
  local mx, my, mp2 = {}, {}, {}
  local R2 = D.DEATH_R * D.DEATH_R
  for _, d in ipairs(map.deaths or {}) do
    if not d.home and tick - d.t < D.HOUR then
      local dx, dy = d.x - p.x, d.y - p.y
      local dd = dx * dx + dy * dy
      if dd <= (L + D.DEATH_R) * (L + D.DEATH_R) then
        local i = #mx + 1
        mx[i], my[i], mp2[i] = d.x, d.y, dd
      end
    end
  end
  -- Distance² d'un point (cx, cy) au segment [p, p + L·v].
  local function seg2(cx, cy, vx, vy)
    local s = (cx - p.x) * vx + (cy - p.y) * vy
    if s < 0 then s = 0 elseif s > L then s = L end
    local qx, qy = p.x + s * vx - cx, p.y + s * vy - cy
    return qx * qx + qy * qy
  end
  local best, best_k, best_v, safe = nil, nil, nil, 0
  for _, k in ipairs(AWAY_PREF) do
    local vx, vy = dirs[k][1], dirs[k][2]
    -- Rapproche de l'ennemi : (ep − p)·v > 0 (au-delà d'une tolérance de calcul).
    if (-ex) * vx + (-ey) * vy <= 1e-9 * el then
      local ti, di = {}, {}
      for i = 1, #fx do if seg2(fx[i], fy[i], vx, vy) <= fr2[i] then ti[#ti + 1] = i end end
      for i = 1, #mx do if seg2(mx[i], my[i], vx, vy) <= R2 then di[#di + 1] = i end end
      local worst, dead = 0, {}
      local nd = 0
      local s = Re.AWAY_STEP
      while true do
        if s > L then s = L end
        local qx, qy = p.x + s * vx, p.y + s * vy
        local v = 0
        for _, i in ipairs(ti) do
          local dx, dy = fx[i] - qx, fy[i] - qy
          local dq = dx * dx + dy * dy
          if dq <= fr2[i] and (fp2[i] > fr2[i] or dq < fp2[i]) then v = v + fw[i] end
        end
        local mq = mobile_at(map, tick, mob, qx, qy)
        if mq > m0 then v = v + (mq - m0) end
        if v > worst then worst = v end
        for _, i in ipairs(di) do
          if not dead[i] then
            local dx, dy = mx[i] - qx, my[i] - qy
            local dq = dx * dx + dy * dy
            if dq <= R2 and (mp2[i] > R2 or dq < mp2[i]) then dead[i], nd = true, nd + 1 end
          end
        end
        if s >= L then break end
        s = s + Re.AWAY_STEP
      end
      if nd == 0 and worst < (B or D.block(1000)) then
        safe = safe + 1
        if best_v == nil or worst < best_v then best, best_k, best_v = { x = vx, y = vy }, k, worst end
      end
    end
  end
  return best, { k = best_k, danger = best_v, safe = safe }
end

function Re.away_pick(map, tick, p, ep, range, B, mob)
  local v, info = Re.away_dir(map, tick, p, ep, range, B, mob)
  if not v then return nil, info end
  local L = Re.away_distance(range)
  return { x = p.x + L * v.x, y = p.y + L * v.y }, info
end

--- Mémo d'un PASSAGE de la mise à l'abri (une carte, un tick) : directions par case de 16 tuiles, cases mobiles.
function Re.away_cache() return { dirs = {}, mob = {} } end

--- « S'éloigner » dans un passage : les PNJ d'une même case de la carte (16 tuiles) prennent la direction calculée pour le premier
--- d'entre eux (ordre des numéros : déterministe), si elle ne les RAPPROCHE pas de l'ennemi (sinon, calcul propre, non mémorisé) ;
--- aucune direction sûre pour la case : nil pour tous. Rend le point, ou nil.
function Re.away_pass(cache, map, tick, p, ep, range, B)
  local key = D.key(D.cell(p.x), D.cell(p.y))
  local c = cache.dirs[key]
  local L = Re.away_distance(range)
  if c == false then return nil end
  if c then
    local ex, ey = ep.x - p.x, ep.y - p.y
    if ex * c.x + ey * c.y <= 1e-9 * math.sqrt(ex * ex + ey * ey) then return { x = p.x + L * c.x, y = p.y + L * c.y } end
    local v = Re.away_dir(map, tick, p, ep, range, B, cache.mob)
    return v and { x = p.x + L * v.x, y = p.y + L * v.y } or nil
  end
  local v = Re.away_dir(map, tick, p, ep, range, B, cache.mob)
  cache.dirs[key] = v or false
  return v and { x = p.x + L * v.x, y = p.y + L * v.y } or nil
end

--- L'ennemi (ep) est-il SUR LE CHEMIN de p vers target ? Dans le cône Re.HOME_CONE vers la cible et plus près qu'elle.
function Re.on_the_way(p, target, ep)
  local hx, hy = target.x - p.x, target.y - p.y
  local ex, ey = ep.x - p.x, ep.y - p.y
  local hl, el = math.sqrt(hx * hx + hy * hy), math.sqrt(ex * ex + ey * ey)
  if hl < 1 or el < 1 or el >= hl then return false end
  return hx * ex + hy * ey >= Re.HOME_CONE * hl * el
end

--- Point de RALLIEMENT d'un QG attaqué : derrière ses tourelles. `turrets` : { {x, y}, ... } (toutes, valides) ; seules celles à
-- moins de Re.RALLY_R tuiles de `home` comptent (les tourelles du QG, pas celles d'un avant-poste). Le point est à
-- Re.RALLY_BEHIND tuiles derrière le CENTRE de ces tourelles, du côté de `home` (coffre) ; nil sans tourelle du QG.
function Re.rally_point(turrets, home)
  local sx, sy, n = 0, 0, 0
  for _, t in ipairs(turrets or {}) do
    local dx, dy = t.x - home.x, t.y - home.y
    if dx * dx + dy * dy <= Re.RALLY_R * Re.RALLY_R then sx, sy, n = sx + t.x, sy + t.y, n + 1 end
  end
  if n == 0 then return nil end
  local cx, cy = sx / n, sy / n
  local hx, hy = home.x - cx, home.y - cy
  local L = math.sqrt(hx * hx + hy * hy)
  if L < 1 then return { x = cx, y = cy } end
  return { x = cx + Re.RALLY_BEHIND * hx / L, y = cy + Re.RALLY_BEHIND * hy / L }
end

--- Un PNJ à pied peut-il distancer l'ennemi ? (vitesses lues aux prototypes ; ennemi inconnu : non)
function Re.outrun(enemy_speed, own_speed)
  if not enemy_speed or not own_speed then return false end
  return enemy_speed <= own_speed * Re.OUTRUN
end

--- Lot CORR-RALLIEMENT (EFFONDREMENT, 5/11) : l'ennemi DÉBORDE-t-il les tourelles du QG ? Partie du DC rejouée (graine
-- 717152950) : des soldats des factions de portée 20 tuent les tourelles du QG (portée 18) de 19 à 21 tuiles, hors de leur
-- portée, puis les PNJ ralliés sous elles (13 à 51 PNJ selon la trajectoire).
-- Relecture (revue-danger, 5/11, 18 h 12) : les portées BRUTES ne se comparent pas. Les soldats des factions tirent en « boîte à
-- boîte » (prototypes/faction.lua, range_mode), les tourelles de centre à centre (défaut du moteur). Tout est ramené au CENTRE,
-- tourelle par tourelle, à partir de PROFILS lus aux prototypes (portée, mode, boîte de collision).
Re.BB = "bounding-box-to-bounding-box"
Re.RANGE_EPS = 1e-6 -- tuile : à atteinte égale, chacun frappe l'autre (pas de débordement)

--- PROFIL d'attaque d'une unité ou d'une tourelle : { r = portée (attack_parameters.range), bb = vrai si range_mode vaut
--- « bounding-box-to-bounding-box » (sinon centre à centre, le défaut du moteur), hx, hy = demi-largeurs de la boîte de collision
--- (formats { left_top, right_bottom } du jeu et { {x, y}, {x, y} } de l'étape data ; sans boîte : 0) }. nil sans portée connue.
function Re.profile(range, mode, box)
  if type(range) ~= "number" then return nil end
  local hx, hy = 0, 0
  if type(box) == "table" then
    local lt, rb = box.left_top or box[1], box.right_bottom or box[2]
    if type(lt) == "table" and type(rb) == "table" then
      local x0, y0, x1, y1 = lt.x or lt[1], lt.y or lt[2], rb.x or rb[1], rb.y or rb[2]
      if x0 and y0 and x1 and y1 then hx, hy = math.abs(x1 - x0) / 2, math.abs(y1 - y0) / 2 end
    end
  end
  return { r = range, bb = mode == Re.BB, hx = hx, hy = hy }
end

--- Point (C), 7/11 : demi-boîte S de la ZONE D'ATTEINTE du profil `a` sur une cible de demi-boîte (hx, hy). La zone est le rectangle
--- ± S élargi de la portée (carré arrondi) : `a` frappe la cible quand le centre de celle-ci y est. S = demi-boîte de la cible, plus
--- celle de `a` en boîte à boîte. MESURÉ (banc portee-diagonale, arène A, fo-logs/2026-11-05_CORR-RALLIEMENT/portee-diagonale-e0e42a60) :
--- au « centre à centre », l'attaquant atteint la BOÎTE de sa cible. La fo-lvl-gun-9 (portée 21,7, centre à centre) touche un
--- mitrailleur (± 0,2) arrêté à 21,933 tuiles de centre à centre en diagonale ; de son centre à la boîte du mitrailleur, il y a 21,656.
--- (Avant : S = 0 au centre à centre, la tourelle n'atteignait que 21,7.) Variante non départagée : le rayon de la cible, qui donne le
--- même résultat en diagonale.
local function reach_box(a, hx, hy)
  local sx, sy = hx or 0, hy or 0
  if a.bb then sx, sy = sx + (a.hx or 0), sy + (a.hy or 0) end
  return sx, sy
end

--- Plus grande distance de CENTRE à centre d'où le profil `a` atteint une cible de demi-boîte (hx, hy) : dans la DIAGONALE, où les
--- coins se font face, portée + |S| (reach_box). MESURÉ (partie 0.6.51, [FO-QG-TOURELLE]) : une mitrailleuse du QG (± 0,7) tuée
--- depuis 21,2 tuiles par un mitrailleur (portée 20, ± 0,2) : au-delà des 20,9 de l'axe, en deçà des 21,27 de la diagonale.
function Re.reach_on(a, hx, hy)
  local sx, sy = reach_box(a, hx, hy)
  return a.r + math.sqrt(sx * sx + sy * sy)
end

--- Écart (tuiles) de l'ennemi `e` sur la tourelle `t` (profils). > Re.RANGE_EPS : e peut frapper t d'un endroit d'où t ne le frappe
--- pas (débordée), c'est-à-dire que la zone d'atteinte de e sur t (reach_box(e, t)) n'est pas dans celle de t sur e (reach_box(t, e)).
--- Deux carrés arrondis convexes, centrés au même point : l'un est dans l'autre si et seulement si leurs fonctions d'appui
--- (h(u) = Sx·|ux| + Sy·|uy| + portée) le sont dans toutes les directions. Écart = le plus grand h_e(u) − h_t(u) :
--- (e.r − t.r) + max sur u ≥ 0, |u| = 1, de Δ·u, avec Δ = S_e − S_t = (t au centre ? demi-boîte de t : 0) − (e au centre ? demi-boîte
--- de e : 0). Le max vaut |Δ⁺| si une composante de Δ est positive, sinon la plus grande des deux.
--- Avec S = 0 au centre à centre (modèle d'avant), cette formule rend exactement les trois d'avant : e.r − t.r (même mode),
--- e.r + |S| − t.r (e en boîte, t au centre), e.r − (t.r + min(Sx, Sy)) (e au centre, t en boîte).
function Re.gap(e, t)
  local dx = (t.bb and 0 or (t.hx or 0)) - (e.bb and 0 or (e.hx or 0))
  local dy = (t.bb and 0 or (t.hy or 0)) - (e.bb and 0 or (e.hy or 0))
  local m
  if dx > 0 or dy > 0 then
    local px, py = math.max(dx, 0), math.max(dy, 0)
    m = math.sqrt(px * px + py * py)
  else
    m = math.max(dx, dy)
  end
  return e.r - t.r + m
end

--- La tourelle `t` (profil) est-elle débordée par au moins un des ennemis (liste de profils) ?
function Re.turret_outranged(enemies, t)
  for _, e in ipairs(enemies or {}) do
    if type(e) == "table" and type(e.r) == "number" and Re.gap(e, t) > Re.RANGE_EPS then return true end
  end
  return false
end

--- Les tourelles (profils) sont-elles TOUTES débordées par le groupe ennemi (profils), tourelle par tourelle ? Une tourelle
--- qu'aucun ennemi ne déborde protège encore (une laser de 24 contre des mitrailleurs de 20). Faux sans ennemi de portée connue
--- (personnage : son arme n'est pas au prototype) ou sans tourelle de portée connue (la règle d'avant).
function Re.outranges(enemies, turrets)
  local known = false
  for _, e in ipairs(enemies or {}) do
    if type(e) == "table" and type(e.r) == "number" then known = true break end
  end
  if not known then return false end
  local n = 0
  for _, t in ipairs(turrets or {}) do
    if type(t) == "table" and type(t.r) == "number" then
      n = n + 1
      if not Re.turret_outranged(enemies, t) then return false end
    end
  end
  return n > 0
end

--- Seconde relecture (point B) : une tourelle MARCHE-t-elle ? s = { type, ammo (munitions présentes), energy (réserve, J), shot (énergie
--- d'un tir, J : attack_parameters.ammo_type.energy_consumption ; nil si inconnue), off (statut no_power, low_power ou
--- not_plugged_in_electric_network), fluid (quantité de fluide) }. Laser : statut alimenté ET réserve d'au moins un tir (une réserve
--- non nulle mais sous le coût d'un tir ne tire pas : « energy > 0 » la comptait en marche). Lance-flammes : du fluide. Autres : oui.
function Re.turret_ready(s)
  local ty = s.type
  if ty == "ammo-turret" then return s.ammo == true end
  if ty == "electric-turret" then
    if s.off then return false end
    local e = s.energy or 0
    if type(s.shot) == "number" and s.shot > 0 then return e >= s.shot end
    return e > 0
  end
  if ty == "fluid-turret" then return (s.fluid or 0) > 0 end
  return true
end

--- Relecture (revue-danger, 18 h 12, point 4) : une tourelle (position x, y et profil) COUVRE le point pt si elle y frappe ce qui s'y
--- tient (demi-boîte (px, py), 0 par défaut) : sa portée, plus la plus petite composante de S (reach_box : l'axe, le moins
--- favorable ; point (C) : la demi-boîte de la cible compte aussi au centre à centre). Portée inconnue : ne couvre rien.
function Re.covers(t, pt, px, py)
  if type(t) ~= "table" or type(t.r) ~= "number" then return false end
  local sx, sy = reach_box(t, px, py)
  local reach = t.r + math.min(sx, sy)
  local dx, dy = t.x - pt.x, t.y - pt.y
  return dx * dx + dy * dy <= reach * reach
end

--- Jugement du point de ralliement (point 4) : au lieu de toutes les tourelles à Re.RALLY_R tuiles du coffre, seules celles qui
--- MARCHENT (t.ok ~= false : munitions, courant, fluide ; lu par le script) et qui COUVRENT le point comptent. Rend "couvert" (au
--- moins une qu'aucun ennemi ne déborde, ou portée ennemie inconnue), "deborde" (toutes débordées) ou "sans-tourelle" (pas de
--- point, ou aucune tourelle qui marche ne le couvre : s'y rallier ne protège de rien), puis le nombre de tourelles jugées.
--- Seconde relecture (point C) : « couvrir le point » n'est pas « protéger le point ». Endroit d'où l'ennemi e frappe le point de
--- ralliement (PNJ de demi-boîte (px, py)) : sa position ep s'il l'atteint déjà, sinon le point de son trajet (en ligne droite vers le
--- point) à son atteinte Re.reach_on(e, px, py). Pour des mordeurs, tout près du point ; pour un mitrailleur, à 20,3 tuiles.
function Re.firing_spot(e, rally, ep, px, py)
  local reach = Re.reach_on(e, px, py)
  local dx, dy = ep.x - rally.x, ep.y - rally.y
  local L = math.sqrt(dx * dx + dy * dy)
  if L <= reach then return { x = ep.x, y = ep.y } end
  return { x = rally.x + reach * dx / L, y = rally.y + reach * dy / L }
end

--- La tourelle t (qui marche et couvre le point) le PROTÈGE-t-elle contre le groupe (profils) ? Aucun ennemi ne la déborde, et elle
--- atteint l'endroit d'où chacun frappe le point (Re.firing_spot ; ep inconnu : la règle du point 4 seule).
function Re.protects(t, enemies, rally, ep, px, py)
  for _, e in ipairs(enemies or {}) do
    if type(e) == "table" and type(e.r) == "number" then
      if Re.gap(e, t) > Re.RANGE_EPS then return false end
      if ep and not Re.covers(t, Re.firing_spot(e, rally, ep, px, py), e.hx, e.hy) then return false end
    end
  end
  return true
end

--- `ep` (seconde relecture, point C) : position de la menace ; une tourelle jugée ne compte que si elle PROTÈGE le point (Re.protects).
--- Verdicts : "couvert", "deborde" (toutes débordées), "hors-portee" (aucune débordée partout, mais aucune n'atteint l'endroit d'où
--- l'ennemi frappe le point), "sans-tourelle".
function Re.rally_judge(enemies, turrets, rally, px, py, ep)
  if not rally then return "sans-tourelle", 0 end
  local judged = {}
  for _, t in ipairs(turrets or {}) do
    if type(t) == "table" and t.ok ~= false and Re.covers(t, rally, px, py) then judged[#judged + 1] = t end
  end
  if #judged == 0 then return "sans-tourelle", 0 end
  for _, t in ipairs(judged) do
    if Re.protects(t, enemies, rally, ep, px, py) then return "couvert", #judged end
  end
  if Re.outranges(enemies, judged) then return "deborde", #judged end
  return "hors-portee", #judged
end

--- Relecture (revue-danger, 18 h 12, point 2) : une tourelle amie (profil q, position tp) est-elle encore un REFUGE devant le
--- groupe ennemi (profils) vu en ep ? Non si un ennemi la DÉBORDE (Re.gap) et qu'elle est à moins de son atteinte (Re.reach_on)
--- plus Re.MARGIN : il la détruit hors de sa portée, puis les désarmés abrités derrière elle. Tourelle de portée inconnue, ou aucun
--- ennemi de portée connue : oui (la règle d'avant).
function Re.refuge_ok(enemies, q, tp, ep)
  if type(q) ~= "table" or type(q.r) ~= "number" then return true end
  local dx, dy = tp.x - ep.x, tp.y - ep.y
  local dd = dx * dx + dy * dy
  for _, e in ipairs(enemies or {}) do
    if type(e) == "table" and type(e.r) == "number" and Re.gap(e, q) > Re.RANGE_EPS then
      local lim = Re.reach_on(e, q.hx, q.hy) + Re.MARGIN
      if dd <= lim * lim then return false end
    end
  end
  return true
end

--- Réponse d'un QG menacé par des UNITÉS (C7, lot FUITE) : "stand" (assez nombreux : on se bat, groupés), "rally" (derrière
-- les tourelles du QG : elles tirent pendant que les ennemis s'y heurtent), "away" (loin de l'ennemi, qu'on distance, sans
-- tourelle), sinon "stand" (fuir ne sert à rien : on se bat groupés). Mesuré (banc ia3k-vague-lente) : s'éloigner AVEC des
-- tourelles au QG est pire que se rallier (l'ennemi suit les PNJ loin des tourelles : 8 perdus, 1 ennemi tué sur 10).
-- Lot CORR-RALLIEMENT : des tourelles que l'ennemi DÉBORDE en portée (i.outranged, Re.outranges) ne protègent pas le point de
-- ralliement : on fait comme sans tourelle (« away » si on le distance, sinon « stand »).
-- i = { allies (armés près du QG, soi compris), force (pesée), prudence, agressivite, rally (point | nil), outrun (bool),
--       outranged (bool | nil) }.
function Re.hq_response(i)
  local need = Re.engage_ratio(i.prudence, i.agressivite) * math.max(0.2, i.force or 1)
  if (i.allies or 0) * 1000 >= need then return "stand" end
  if i.rally and not i.outranged then return "rally" end
  if i.outrun then return "away" end
  return "stand"
end

--- Sprint 40 (défense, p1) : le rôle d'un soldat l'éloigne-t-il LÉGITIMEMENT du QG ? (drapeau lu par le rappel du chef, military.lua : un soldat
--- lointain sans ce drapeau est ramené). Escorte et nettoyage : toujours. Garde, DÉFENSE et CHASSE : quand leur point est loin du QG (`far`) ; une
--- alerte de site est admise à toute distance du QG (lot DANGER-ACTIF), ses défenseurs étaient rappelés en route (drapeau jamais posé).
function Re.far_role(role, far)
  if role == "escort" or role == "clear" then return true end
  if far and (role == "guard" or role == "defense" or role == "hunt") then return true end
  return false
end

function Re.decide(s)
  if not s.kind then return "none", "rien" end
  local K = D.KINDS[s.kind] or D.KINDS.unit
  local range = s.range or K.r
  local p = s.prudence or 1000
  local dist = s.dist or 1e9
  -- Peur (C3) : blessé sous le seuil ou sans munitions, et l'ennemi est à portée (+ marge).
  local hurt = (s.hp or 1000) < Re.fear(p)
  if not s.armed then
    if dist <= math.max(range + Re.MARGIN, Re.flee_unarmed(p)) then return "flee", "desarme" end
  elseif hurt and dist <= range + Re.MARGIN then
    return "flee", "blesse"
  end
  if K.fixed then
    -- Ver, nid, tourelle : on ne passe pas à sa portée.
    if dist <= range + 2 then return "back", "a-portee" end
    if s.walking and (s.on_route or dist <= range + Re.MARGIN) then return "detour", "sur-la-route" end
    return "none", "vu"
  end
  -- Unités et personnages : se battre en surnombre ; sinon, selon leur portée utile (leur VUE pour une unité) : au-delà
  -- de portée + marge, s'arrêter (elles passent peut-être) ; entre portée et portée + marge, se détourner tout de suite ;
  -- à portée, partir.
  -- Demi-tour devant des unités ; le deuxième (Re.BACKS déjà faits) est une FUITE avec refuge : survie avant tâche.
  local function pull(why)
    if (s.backs or 0) >= Re.BACKS then return "flee", "poursuivi" end
    return "back", why
  end
  local n = math.max(0.2, s.enemies or 1) -- force PESÉE (moyen déchiqueteur = 1)
  local need = Re.engage_ratio(p, s.agressivite)
  if s.site_alert and need > Re.SITE_RATIO then need = Re.SITE_RATIO end -- DANGER-ACTIF : sur un site attaqué, l'ouvrier armé tient à parité
  if s.armed and ((s.allies or 0) + 1) * 1000 >= need * n then
    if dist <= range + Re.MARGIN or s.on_route then return "engage", "surnombre" end
    return "none", "vu"
  end
  -- Des unités qui reviennent sur la route après REPEATS arrêts ou détours de la même tournée (un nid gardé, des
  -- déchiqueteurs qui rôdent) : on renonce, demi-tour.
  local insist = (s.repeats or 0) >= Re.REPEATS
  if dist > range + Re.MARGIN then
    if s.walking and s.on_route then
      if insist then return pull("insiste") end
      return "stop", "sur-la-route"
    end
    return "none", "vu"
  end
  if dist > range then
    if s.walking then
      if insist then return pull("insiste") end
      return "detour", "proche"
    end
    return "flee", "proche"
  end
  if s.walking then return pull("trop-pres") end
  return "flee", "trop-pres"
end

-- Étiquette visible (D1) de chaque action (clé de locale/*/ia3k.cfg, section fo-ia3k).
Re.LABEL = {
  flee = "fuite", back = "demi-tour", detour = "detour", stop = "alerte", engage = "combat",
}

return Re
