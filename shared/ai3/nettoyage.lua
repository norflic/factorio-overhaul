--[[
  Lot NETTOYAGE-SITE (29/10, arbitrage du DC : « Oui, lancer le lot ») : opération militaire qui libère le gisement PROCHE
  bloqué par des nids. PUR (aucune API Factorio, aucun nom d'objet : les ressources sont des chaînes opaques), testé hors jeu
  par tests/nettoyage_test.lua (règles, mutants, moteur simulé).

  Entrée : le signal `f.site_blocked[ressource]` (script/faction/sites.lua, lot SITE-PROCHE), posé tant qu'un site proche d'une
  ressource est bloqué ET que des sites plus lointains de la même ressource sont suspendus à cause de lui. Les nids et vers
  CONNUS autour du site viennent de la carte de connaissance (shared/ai3/carte.lua, K.enemy_points).

  Règles (« les ressources d'abord », sans vider la défense du QG, sans opération suicide) :
    * candidat : ressource encore demandée (f.site_needs), blocage non échu, site hors refroidissement ; le plus PROCHE du QG
      d'abord (puis la ressource, ordre fixe) ;
    * effectif estimé d'après la force du champ : Nt.need(nids, vers) = BASE + PER_NEST × nids + PER_WORM × vers ;
    * on n'engage que le SURPLUS des soldats au QG (shared/ai3/soldats.lua, Sd.surplus : la réserve Sd.reserve reste au QG) ;
      effectif insuffisant, champ trop fort ou QG menacé : on ATTEND, et le motif est rendu (journalisé par l'appelant) ;
    * opération en 3 temps : RASSEMBLEMENT hors de portée des vers (Nt.rally), ATTAQUE nid par nid (Nt.next_target), RETOUR ;
      retraite si plus de la moitié de la force de départ est morte (Sd.retreat), abandon au bout de ATTACK_TICKS ;
    * pendant qu'une opération est préparée (attente d'effectif) ou en cours, elle passe AVANT les expéditions lointaines des
      soldats (Nt.filter_threats retire les champs plus lointains que le site, et ceux du site lui-même) ;
    * site bloqué « hostile » sans aucun nid ni ver connu dans un secteur déjà vu : il est RE-VÉRIFIÉ (nouvel examen par la
      prospection) au plus une fois par RECHECK ticks, sans soldat ; un blocage sans nid et d'un autre motif (injoignable,
      écarté, perte) n'est pas militaire : rien.
  Entrées triées, aucun ordre de `pairs`, racines carrées seulement.
]]

local Sd = require("shared.ai3.soldats")

local Nt = {}

Nt.R = 48               -- rayon du site examiné (= ENEMY_CLEARANCE de script/faction/sites.lua : rayon qui le déclare hostile)
Nt.BASE = 4             -- soldats de base d'une opération
Nt.PER_NEST = 2         -- par nid connu
Nt.PER_WORM = 2         -- par ver connu (il tire à distance : autant qu'un nid)
Nt.MAX_NEED = 30        -- au-delà : champ trop fort pour une opération, on attend (pas d'opération suicide)
Nt.STANDOFF = 24        -- le rassemblement se tient à au moins R + STANDOFF tuiles du site (hors de portée des vers)
Nt.STEP_BACK = 16       -- pas de recul du rassemblement vers le QG quand le point n'est pas sûr
Nt.GATHER_R = 16        -- un soldat à moins de 16 tuiles du point de rassemblement est « présent »
Nt.GATHER_SHARE = 750   -- pour mille des soldats vivants présents : l'attaque part
Nt.GATHER_TICKS = 2 * 3600
Nt.ATTACK_TICKS = 6 * 3600
Nt.COOL = 20 * 3600     -- site non retenté après une retraite ou un abandon (comme Sd.RETREAT_COOL)
Nt.RECHECK = 5 * 3600   -- re-vérification d'un site « hostile » sans nid connu
Nt.NEAR_SITE = 8        -- marge : un champ de menaces à moins de R + 8 tuiles du site appartient à l'opération

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

--- Soldats nécessaires contre `nests` nids et `worms` vers connus (monotone, au moins BASE + un ennemi).
function Nt.need(nests, worms)
  return Nt.BASE + Nt.PER_NEST * (nests or 0) + Nt.PER_WORM * (worms or 0)
end

--- Le site (x, y) est-il en refroidissement au tick donné ? cool = { { x, y, ["until"] } }.
function Nt.cooled(cool, site, tick)
  for _, c in ipairs(cool or {}) do
    if tick < c["until"] and d2(c, site) <= Nt.NEAR_SITE * Nt.NEAR_SITE then return true end
  end
  return false
end

--- Candidats : blocked = { [ressource] = { x, y, why, until_tick, d_blocked, n } } (signal de sites.lua), needs = { [ressource]
--- = n } (f.site_needs), cool (Nt.cooled). Rend { { resource, x, y, d, why, until_tick } } triés par distance au QG puis par
--- ressource. Clés lues dans l'ordre trié.
function Nt.candidates(blocked, needs, tick, cool)
  local keys = {}
  for k in pairs(blocked or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  local out = {}
  for _, res in ipairs(keys) do
    local s = blocked[res]
    if type(s) == "table" and type(s.x) == "number" and type(s.y) == "number" and (s.until_tick or 0) > tick
      and (s.n or 0) > 0 and ((needs or {})[res] or 0) > 0 and not Nt.cooled(cool, s, tick) then
      out[#out + 1] = { resource = res, x = s.x, y = s.y, d = s.d_blocked or 0, why = s.why, until_tick = s.until_tick }
    end
  end
  table.sort(out, function(a, b)
    if a.d ~= b.d then return a.d < b.d end
    return a.resource < b.resource
  end)
  return out
end

--- Décision (aucune opération en cours). input = {
---   cands = Nt.candidates(...) dont chacun porte nests, worms (connus à moins de Nt.R tuiles) et seen (secteur vu),
---   home = soldats sans groupe près du QG, ni au repos ni pris par une défense, une escorte ou un nettoyage,
---   threatened = vrai si le QG est menacé ou une alerte est ouverte, busy = vrai si une opération est déjà en cours,
---   expedition = { x, y } | nil (expédition des soldats en cours : si elle vise le champ du site, on la laisse finir),
---   checked = { [ressource] = tick de la dernière re-vérification }, tick }.
--- Rend { action = "lancer" | "attendre" | "reverifier" | "rien", site, reason, need, take, surplus, reserve, notes }.
--- `notes` : candidats écartés avant le site retenu ({ site, reason }) pour le journal.
function Nt.decide(input)
  local notes = {}
  if input.busy then return { action = "rien", reason = "operation-en-cours", notes = notes } end
  local tick = input.tick or 0
  for _, c in ipairs(input.cands or {}) do
    local k = (c.nests or 0) + (c.worms or 0)
    if k == 0 then
      if c.why == "hostile" and c.seen then
        local last = (input.checked or {})[c.resource]
        if not last or tick - last >= Nt.RECHECK then
          return { action = "reverifier", site = c, reason = "aucun-nid-connu", notes = notes }
        end
        notes[#notes + 1] = { site = c, reason = "reverifie-recemment" }
      else
        notes[#notes + 1] = { site = c, reason = c.seen and "non-militaire" or "secteur-non-vu" }
      end
    else
      local home = input.home or 0
      local need = Nt.need(c.nests, c.worms)
      local surplus = Sd.surplus(home)
      local out = { site = c, need = need, surplus = surplus, reserve = home - surplus, home = home, notes = notes }
      local ex = input.expedition
      local near = Nt.R + Nt.NEAR_SITE
      if input.threatened then
        out.action, out.reason = "attendre", "qg-menace"
      elseif ex and d2(ex, c) <= near * near then
        out.action, out.reason = "attendre", "expedition-sur-site"
      elseif need > Nt.MAX_NEED then
        out.action, out.reason = "attendre", "trop-fort"
      elseif need > surplus then
        out.action, out.reason = "attendre", "effectif"
      else
        out.action, out.reason, out.take = "lancer", "effectif-suffisant", need
      end
      return out
    end
  end
  return { action = "rien", reason = #notes > 0 and notes[1].reason or "aucun-site-bloque", notes = notes }
end

--- L'attente bloque-t-elle les expéditions lointaines (priorité au site proche) ? Seulement l'attente d'EFFECTIF : un champ
--- trop fort ou un QG menacé ne doivent pas geler les autres missions des soldats.
function Nt.holds(decision)
  return decision ~= nil and (decision.action == "lancer" or (decision.action == "attendre" and decision.reason == "effectif"))
end

--- Point de rassemblement sur le segment QG -> site, à au moins R + STANDOFF tuiles du site ; plus près du QG que cela :
--- le QG. `safe(x, y)` (facultatif) : un point non sûr recule de STEP_BACK tuiles vers le QG (jusqu'au QG).
function Nt.rally(hq, site, safe)
  local dx, dy = site.x - hq.x, site.y - hq.y
  local d = math.sqrt(dx * dx + dy * dy)
  local keep = Nt.R + Nt.STANDOFF
  local along = d - keep
  while along > 0 do
    local x, y = hq.x + dx * along / d, hq.y + dy * along / d
    if not safe or safe(x, y) then return { x = x, y = y, at_hq = false } end
    along = along - Nt.STEP_BACK
  end
  return { x = hq.x, y = hq.y, at_hq = true }
end

--- Prochaine cible : le point (nid ou ver, { x, y }) le plus proche de `from` (distance, puis x, puis y), ou nil.
function Nt.next_target(points, from)
  local best, bd = nil, nil
  for _, p in ipairs(points or {}) do
    local d = d2(p, from)
    if not best or d < bd or (d == bd and (p.x < best.x or (p.x == best.x and p.y < best.y))) then best, bd = p, d end
  end
  return best
end

--- Phase suivante d'une opération. op = { phase = "rassemble" | "attaque", n0, t_phase } ; obs = { tick, alive, dead,
--- present (vivants au rassemblement), left (nids et vers encore debout à moins de R du site, lus au moteur ; nil hors de
--- l'attaque) }. Rend la phase : "rassemble", "attaque", "nettoye", "retraite", "abandon".
function Nt.step(op, obs)
  local tick = obs.tick or 0
  if Sd.retreat(op.n0, obs.dead or 0) or (obs.alive or 0) == 0 then return "retraite" end
  if op.phase == "rassemble" then
    if (obs.present or 0) * 1000 >= Nt.GATHER_SHARE * obs.alive or tick - (op.t_phase or 0) >= Nt.GATHER_TICKS then
      return "attaque"
    end
    return "rassemble"
  end
  if obs.left ~= nil and obs.left == 0 then return "nettoye" end
  if tick - (op.t_phase or 0) >= Nt.ATTACK_TICKS then return "abandon" end
  return "attaque"
end

--- Priorité au site proche : retire des groupes de menaces des soldats (Sd.clusters, déjà triés) ceux plus LOINTAINS du QG que
--- le site (les expéditions lointaines) et ceux du site lui-même (à moins de R + NEAR_SITE tuiles : c'est l'opération qui les
--- traite). Les groupes plus proches du QG que le site restent (une menace près du QG passe toujours avant).
function Nt.filter_threats(clusters, hq, site)
  local out = {}
  local ds = d2(site, hq)
  local r = Nt.R + Nt.NEAR_SITE
  for _, c in ipairs(clusters or {}) do
    if d2(c, hq) <= ds and d2(c, site) > r * r then out[#out + 1] = c end
  end
  return out
end

--- Champ du site nettoyé : retire des groupes de menaces ceux à moins de R + NEAR_SITE tuiles du site (ils ont été lus avant
--- le nettoyage ; sans cela, une expédition repartait aussitôt vers les nids détruits).
function Nt.drop_site(clusters, site)
  local out = {}
  local r = Nt.R + Nt.NEAR_SITE
  for _, c in ipairs(clusters or {}) do
    if d2(c, site) > r * r then out[#out + 1] = c end
  end
  return out
end

return Nt
