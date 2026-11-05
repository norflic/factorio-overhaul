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

function Re.away_pick(map, tick, p, ep, range, B)
  local ex, ey = p.x - ep.x, p.y - ep.y
  local el = math.sqrt(ex * ex + ey * ey)
  if el < 1 then ex, ey, el = 1, 0, 1 end
  local ux, uy = ex / el, ey / el
  local L = Re.away_distance(range)
  local dirs = away_dirs(ux, uy)
  local m0 = D.exact_parts(map, p.x, p.y, tick).mobile
  -- Menaces fixes et morts PROCHES (au plus L + leur rayon du PNJ), poids décrus calculés une fois.
  local fx, fy, fr2, fp2, fw = {}, {}, {}, {}, {}
  for _, t in ipairs(map.threats or {}) do
    local K = D.KINDS[t.k] or D.KINDS.unit
    local r = t.r + D.EXACT_MARGIN
    local dx, dy = t.x - p.x, t.y - p.y
    local dd = dx * dx + dy * dy
    if dd <= (L + r) * (L + r) then
      local i = #fx + 1
      fx[i], fy[i], fr2[i], fp2[i] = t.x, t.y, r * r, dd
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
  local best, best_k, best_v, safe = nil, nil, nil, 0
  for _, k in ipairs(AWAY_PREF) do
    local vx, vy = dirs[k][1], dirs[k][2]
    -- Rapproche de l'ennemi : (ep − p)·v > 0 (au-delà d'une tolérance de calcul).
    if (-ex) * vx + (-ey) * vy <= 1e-9 * el then
      local worst, dead = 0, {}
      local nd = 0
      local s = Re.AWAY_STEP
      while true do
        if s > L then s = L end
        local qx, qy = p.x + s * vx, p.y + s * vy
        local v = 0
        for i = 1, #fx do
          local dx, dy = fx[i] - qx, fy[i] - qy
          local dq = dx * dx + dy * dy
          if dq <= fr2[i] and (fp2[i] > fr2[i] or dq < fp2[i]) then v = v + fw[i] end
        end
        local mq = D.exact_parts(map, qx, qy, tick).mobile
        if mq > m0 then v = v + (mq - m0) end
        if v > worst then worst = v end
        for i = 1, #mx do
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
        if best_v == nil or worst < best_v then best, best_k, best_v = { x = p.x + L * vx, y = p.y + L * vy }, k, worst end
      end
    end
  end
  return best, { k = best_k, danger = best_v, safe = safe }
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

--- Plus grande distance de CENTRE à centre d'où le profil `a` atteint une cible de demi-boîte (hx, hy). Centre à centre : sa
--- portée. Boîte à boîte : la zone d'atteinte est un carré arrondi (somme des demi-boîtes S, plus la portée), le plus loin dans la
--- DIAGONALE, où les coins se font face : portée + |S|. MESURÉ (partie 0.6.51, [FO-QG-TOURELLE]) : une mitrailleuse du QG (± 0,7)
--- tuée depuis 21,2 tuiles par un mitrailleur (portée 20, ± 0,2) : au-delà des 20,9 de l'axe, en deçà des 21,27 de la diagonale.
function Re.reach_on(a, hx, hy)
  if not a.bb then return a.r end
  local sx, sy = a.hx + (hx or 0), a.hy + (hy or 0)
  return a.r + math.sqrt(sx * sx + sy * sy)
end

--- Écart (tuiles) de l'ennemi `e` sur la tourelle `t` (profils) : le plus grand, sur toutes les directions, de « distance de centre
--- à centre d'où e frappe t » moins « distance d'où t frappe e ». > Re.RANGE_EPS : e peut frapper t hors de sa portée (débordée).
--- Zones d'atteinte : disque (centre à centre) ou carré arrondi (boîte à boîte, même somme S des demi-boîtes pour les deux). Les
--- deux zones sont convexes et symétriques ; l'écart le plus grand est sur l'axe ou la diagonale :
---   même mode : e.r − t.r ; e en boîte, t au centre : e.r + |S| − t.r (diagonale) ; e au centre, t en boîte : e.r − (t.r + min(Sx, Sy)) (axe).
function Re.gap(e, t)
  if e.bb == t.bb then return e.r - t.r end
  local sx, sy = e.hx + t.hx, e.hy + t.hy
  if e.bb then return e.r + math.sqrt(sx * sx + sy * sy) - t.r end
  return e.r - (t.r + math.min(sx, sy))
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

--- Relecture (revue-danger, 18 h 12, point 4) : une tourelle (position x, y et profil) COUVRE le point pt si elle y frappe ce qui s'y
--- tient (demi-boîte (px, py), 0 par défaut) : sa portée de centre à centre ; en boîte à boîte, plus la plus petite somme des
--- demi-boîtes (l'axe, le moins favorable). Portée inconnue : ne couvre rien.
function Re.covers(t, pt, px, py)
  if type(t) ~= "table" or type(t.r) ~= "number" then return false end
  local reach = t.r
  if t.bb then reach = reach + math.min((t.hx or 0) + (px or 0), (t.hy or 0) + (py or 0)) end
  local dx, dy = t.x - pt.x, t.y - pt.y
  return dx * dx + dy * dy <= reach * reach
end

--- Jugement du point de ralliement (point 4) : au lieu de toutes les tourelles à Re.RALLY_R tuiles du coffre, seules celles qui
--- MARCHENT (t.ok ~= false : munitions, courant, fluide ; lu par le script) et qui COUVRENT le point comptent. Rend "couvert" (au
--- moins une qu'aucun ennemi ne déborde, ou portée ennemie inconnue), "deborde" (toutes débordées) ou "sans-tourelle" (pas de
--- point, ou aucune tourelle qui marche ne le couvre : s'y rallier ne protège de rien), puis le nombre de tourelles jugées.
function Re.rally_judge(enemies, turrets, rally, px, py)
  if not rally then return "sans-tourelle", 0 end
  local judged = {}
  for _, t in ipairs(turrets or {}) do
    if type(t) == "table" and t.ok ~= false and Re.covers(t, rally, px, py) then judged[#judged + 1] = t end
  end
  if #judged == 0 then return "sans-tourelle", 0 end
  if Re.outranges(enemies, judged) then return "deborde", #judged end
  return "couvert", #judged
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
  if s.armed and ((s.allies or 0) + 1) * 1000 >= Re.engage_ratio(p, s.agressivite) * n then
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
