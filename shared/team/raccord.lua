--[[
  Lot PD-ELEC (demande D05 du DC, 28/10 14 h 45 et 29/10 14 h : « incapables de détecter des zones non couvertes par
  l'électricité » ; objets à 0 d'électricité) : COUVERTURE ÉLECTRIQUE des modules d'une équipe. Règle PURE : aucune API du jeu,
  aucun nom d'objet ; lue hors jeu (tests/raccord_test.lua) et en jeu (script/team/raccord.lua).

  Ce que main faisait déjà (lot CORR-RESEAU, script/team/reseau_vivant.lua) : la centrale perdue est refaite, et les poteaux PERDUS
  qui rallument un îlot sont rouverts. Ce qui manquait : une machine d'un module FINI sans courant alors qu'AUCUN poteau n'a été
  perdu (module jamais relié : nœud de rue d'un projet annulé, maillon trop long, fils jamais tirés ; île). Ici :

  1. RELEVÉ (script) : machines électriques des modules finis, une partie de module par passe (borné par tick) ; une machine est
     « ile » quand son réseau n'a aucune machine génératrice, « sans_reseau » quand elle n'est sous aucun poteau.
  2. GROUPES : les machines d'une même île (même réseau) forment UN groupe, clé « i<plus petit projet> » (stable d'un relevé à
     l'autre, contrairement au numéro de réseau du moteur) ; les machines sans réseau, un groupe par partie de module « u<projet>:<partie> ».
  3. DÉCISION (R.decide) : relier (un projet de raccordement : chaîne de poteaux par la recherche de chemin de 0.6.17/0.6.18, du
     poteau de l'île, ou d'un poteau neuf posé contre la machine, au poteau vivant le plus proche), attendre ou laisser.
  4. CHOIX DES BOUTS (R.best_pair) : la paire (poteau de l'île, poteau vivant) la plus courte, départage y puis x.

  Déterminisme : listes triées, aucun `pairs` dans une décision, aucune trigonométrie, aucune horloge mesurée.
]]

local R = {}

R.PERIOD = 3600          -- ticks entre deux débuts de relevé (1 min)
R.UNITS_PER_PULSE = 1    -- parties de module relevées par passe de Build (Build.PULSE = 5 ticks)
R.CONFIRM = 2            -- relevés de suite où le groupe est vu avant d'agir (une coupure d'un instant ne se raccorde pas)
R.MAX_OPEN = 2           -- raccordements ouverts au plus par équipe
R.MAX_TRIES = 3          -- raccordements tentés au plus pour un même groupe
R.RETRY_AFTER = 30 * 3600 -- ticks : essais épuisés, un essai de plus après 30 min (le réseau a pu s'étendre ; jamais abandonné pour toujours)
R.LOST_NEAR = 32         -- tuiles : un poteau perdu (ou un poteau d'un chantier pas fini) à cette distance laisse la main
R.MAX_DIST = 160         -- tuiles : au-delà, pas de chaîne (le graphe borné de la recherche de chemin n'y suffit plus)
R.ENEMY_R = 28           -- tuiles : jamais de pose avec un ennemi à cette portée du départ
R.LOG_EVERY = 5 * 3600   -- une synthèse au plus par équipe et par 5 min (hors changement)

--- Une machine relevée : "ok", "ile" ou "sans_reseau". net = numéro de réseau (nil : sous aucun poteau), live(net) -> bool
--- (réseau avec au moins une machine génératrice), electric = la machine prend du courant (une machine à combustible : "ok").
function R.classify(net, live, electric)
  if not electric then return "ok" end
  if net == nil then return "sans_reseau" end
  if live(net) then return "ok" end
  return "ile"
end

local function less_pos(a, b)
  if a.y ~= b.y then return a.y < b.y end
  return a.x < b.x
end

--- Groupes d'un relevé. obs = { { pid, part, net, x, y, kind = "ile"|"sans_reseau", box = {x0, y0, x1, y1} } } (ordre quelconque).
--- Rend une liste triée par clé : { key, kind, net, n, pids (triés), x, y (machine la plus au nord-ouest), box (englobante) }.
function R.groups(obs)
  local by, keys = {}, {}
  -- îles : d'abord le plus petit projet de chaque réseau (clé stable)
  local min_pid = {}
  for _, o in ipairs(obs) do
    if o.kind == "ile" then
      if not min_pid[o.net] or o.pid < min_pid[o.net] then min_pid[o.net] = o.pid end
    end
  end
  for _, o in ipairs(obs) do
    local key
    if o.kind == "ile" then key = "i" .. min_pid[o.net] else key = "u" .. o.pid .. ":" .. (o.part or 0) end
    local g = by[key]
    if not g then
      g = { key = key, kind = o.kind, net = o.net, n = 0, pids = {}, seen_pid = {}, x = o.x, y = o.y,
        box = { o.box[1], o.box[2], o.box[3], o.box[4] }, mbox = { o.box[1], o.box[2], o.box[3], o.box[4] } }
      by[key] = g
      keys[#keys + 1] = key
    end
    g.n = g.n + 1
    if not g.seen_pid[o.pid] then g.seen_pid[o.pid] = true; g.pids[#g.pids + 1] = o.pid end
    -- la machine la plus au nord-ouest (et sa boîte : le poteau neuf d'un groupe sans réseau se pose contre elle)
    if less_pos(o, g) then g.x, g.y, g.mbox = o.x, o.y, { o.box[1], o.box[2], o.box[3], o.box[4] } end
    g.box[1], g.box[2] = math.min(g.box[1], o.box[1]), math.min(g.box[2], o.box[2])
    g.box[3], g.box[4] = math.max(g.box[3], o.box[3]), math.max(g.box[4], o.box[4])
  end
  table.sort(keys)
  local out = {}
  for _, k in ipairs(keys) do
    local g = by[k]
    g.seen_pid = nil
    table.sort(g.pids)
    out[#out + 1] = g
  end
  return out
end

--- Décision pour un groupe. inp = { has_live (un réseau alimenté existe), lost (poteaux perdus des projets du groupe ou à
--- R.LOST_NEAR), pending (poteaux pas encore bâtis d'un chantier à R.LOST_NEAR), open (raccordement de CE groupe en cours),
--- open_total (raccordements ouverts de l'équipe), seen (relevés de suite), tries (raccordements déjà tentés), since_try (ticks
--- depuis le dernier essai ; nil : 0, essais épuisés laissés), enemies }.
--- Rend action ("relier" | "attendre" | "laisser"), raison.
function R.decide(inp)
  if not inp.has_live then return "attendre", "aucun reseau alimente (la centrale d'abord : [FO-RESEAU])" end
  if (inp.lost or 0) > 0 then return "laisser", string.format("%d poteau(x) perdu(s) a portee : [FO-RESEAU] les rouvre", inp.lost) end
  if inp.open then return "attendre", "raccordement deja en cours" end
  if (inp.pending or 0) > 0 then return "attendre", string.format("%d poteau(x) d'un chantier voisin pas encore bati(s)", inp.pending) end
  if (inp.seen or 0) < R.CONFIRM then return "attendre", string.format("a confirmer (%d releve(s) sur %d)", inp.seen or 0, R.CONFIRM) end
  if (inp.tries or 0) >= R.MAX_TRIES and (inp.since_try or 0) < R.RETRY_AFTER then
    return "laisser", string.format("%d raccordement(s) tente(s) sans effet (nouvel essai %d min apres le dernier)", inp.tries, R.RETRY_AFTER / 3600)
  end
  if (inp.enemies or 0) > 0 then return "attendre", string.format("ennemi a moins de %d tuiles", R.ENEMY_R) end
  if (inp.open_total or 0) >= R.MAX_OPEN then return "attendre", string.format("%d raccordement(s) deja ouvert(s)", inp.open_total) end
  return "relier", "machines sans courant sans poteau perdu"
end

--- Paire de bouts la plus courte : starts, targets = { { x, y, ... } } ; rend s, t, d (ou nil si aucune paire à max_dist au plus).
--- Départage : distance, puis départ (y, x), puis cible (y, x).
function R.best_pair(starts, targets, max_dist)
  local bs, bt, bd2
  local lim = max_dist and max_dist * max_dist or math.huge
  for _, s in ipairs(starts) do
    for _, t in ipairs(targets) do
      local dx, dy = s.x - t.x, s.y - t.y
      local d2 = dx * dx + dy * dy
      if d2 <= lim then
        local better = not bd2 or d2 < bd2 - 1e-9
        if not better and math.abs(d2 - bd2) <= 1e-9 then
          if less_pos(s, bs) then better = true
          elseif s.x == bs.x and s.y == bs.y and less_pos(t, bt) then better = true end
        end
        if better then bs, bt, bd2 = s, t, d2 end
      end
    end
  end
  if not bs then return nil end
  return bs, bt, math.sqrt(bd2)
end

--- Tuiles candidates d'un poteau NEUF contre une machine sans réseau : l'anneau d'une tuile autour de sa boîte
--- { x0, y0, x1, y1 } (bords de tuiles entiers), centres de tuile, triés par distance à `toward`, puis y, puis x.
--- Un poteau 1 × 1 sur cet anneau couvre la machine (rayon d'alimentation >= 2,5 tuiles pour tous les poteaux du jeu).
function R.ring_tiles(box, toward)
  local x0, y0 = math.floor(box[1]), math.floor(box[2])
  local x1, y1 = math.ceil(box[3]) - 1, math.ceil(box[4]) - 1
  local out = {}
  for ty = y0 - 1, y1 + 1 do
    for tx = x0 - 1, x1 + 1 do
      if tx == x0 - 1 or tx == x1 + 1 or ty == y0 - 1 or ty == y1 + 1 then out[#out + 1] = { x = tx + 0.5, y = ty + 0.5 } end
    end
  end
  table.sort(out, function(a, b)
    local da = (a.x - toward.x) ^ 2 + (a.y - toward.y) ^ 2
    local db = (b.x - toward.x) ^ 2 + (b.y - toward.y) ^ 2
    if da ~= db then return da < db end
    return less_pos(a, b)
  end)
  return out
end

--- Portée de fil d'une chaîne : chaque maillon relie deux poteaux, la chaîne ne dépasse jamais la plus courte des trois portées
--- (départ, cible, poteau neuf).
function R.chain_reach(start_reach, target_reach, new_reach)
  return math.min(start_reach or new_reach, target_reach or new_reach, new_reach)
end

return R
