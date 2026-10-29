--[[
  Lot NETTOYAGE-SITE (29/10, arbitrage du DC : « Oui, lancer le lot ») : exécution de l'opération qui libère le gisement PROCHE
  bloqué par des nids (règles pures : shared/ai3/nettoyage.lua). Appelé par le passage des rôles des soldats
  (script/ai3/soldats.lua, pass) AVANT l'attribution des rôles : les soldats pris par l'opération sont retirés de la liste
  attribuée (aucun autre rôle ne les reprend), et tant qu'une opération est préparée ou en cours, les expéditions lointaines
  sont retirées des menaces candidates (Nt.filter_threats).

  Chaîne : signal f.site_blocked (script/faction/sites.lua, report) -> Nts.pass (décision Nt.decide) -> rassemblement
  (Nt.rally, commande go_to_location) -> attaque (Nt.next_target, attack_area) -> nettoyé (aucun ennemi à Nt.R tuiles du site,
  lu au moteur) -> Sites.unblock (blocage levé, site de nouveau examiné et remis en réserve, signal retiré) -> les ouvriers
  puisent le site proche (Sites.find -> find_by_value).

  État (global, carte de l'équipe de script/ai3/comportement.lua, t.sd) — un lecteur pour chacun :
    sd.nt       = { res, x, y, d, phase, ids, n0, need, t0, t_phase, rally, tkey }  -> lu ici (Nts.pass : phases, soldats pris)
    sd.nt_cool  = { { x, y, until } }      -> lu ici (Nt.candidates -> Nt.cooled : site non retenté après retraite ou abandon)
    sd.nt_wait  = { [ressource] = motif }  -> lu ici (journal : une ligne par CHANGEMENT de motif d'attente)
    sd.nt_check = { [ressource] = tick }   -> lu ici (Nt.decide : re-vérification d'un site hostile sans nid connu, RECHECK)
    t.stats.nt_* (compteurs)               -> lus par le bilan des mesures (t.stats, script/ai3/comportement.lua)
  Journal [FO-NETTOYAGE] : une ligne par cause (prepare, attente <motif>, rassemblement, attaque, nettoye, re-bloque, retraite,
  abandon, annule, reverifie), au plus LOG_MAX lignes par équipe.
]]

local State = require("script.faction.state")
local Sites = require("script.faction.sites")
local K = require("shared.ai3.carte")
local D = require("shared.ai3.danger")
local Sd = require("shared.ai3.soldats")
local Nt = require("shared.ai3.nettoyage")
local C = require("script.ai3.comportement")

local Nts = {}

Nts.LOG_MAX = 300
local ENEMY_TYPES = { "unit-spawner", "turret" }
local ENEMY_FORCE = "enemy"

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

local function say(f, t, fmt, ...)
  t.stats.nt_logged = (t.stats.nt_logged or 0) + 1
  if t.stats.nt_logged > Nts.LOG_MAX then return end
  log(string.format("[FO-NETTOYAGE] %s " .. fmt, tostring(f.key), ...))
end

local function inc(t, k) t.stats[k] = (t.stats[k] or 0) + 1 end

--- Soldats vivants de l'opération (dans l'ordre de op.ids), morts, et soldats repris par un groupe du chef (sortis sans mort).
local function census(op, soldiers)
  local alive, dead, kept = {}, 0, {}
  for _, id in ipairs(op.ids) do
    local s = soldiers[id]
    if not (s and s.entity and s.entity.valid) then
      dead = dead + 1
      kept[#kept + 1] = id
    elseif not s.group then
      alive[#alive + 1] = id
      kept[#kept + 1] = id
    end
  end
  op.ids = kept -- un soldat repris par une attaque du chef quitte l'opération (ni vivant ni mort ici)
  return alive, dead
end

--- Fin de l'opération : les survivants rentrent et se reposent (Sd.REST), plus aucun drapeau de rôle lointain.
local function release(f, sd, op, soldiers, per, tick, command)
  for _, id in ipairs(op.ids) do
    local s, ps = soldiers[id], per[id]
    if s and s.entity and s.entity.valid and not s.group then
      command(s.entity, { role = "home" }, f)
      s.ia3k = nil
      if ps then
        ps.role, ps.key, ps.escort = nil, nil, nil
        ps.rest_until = tick + Sd.REST
      end
    end
  end
  sd.nt = nil
end

--- Ennemis (nids et vers d'abord, sinon toute unité) à moins de Nt.R tuiles du site, lus au moteur : les soldats sont sur place.
local function enemies_at(surface, site)
  local left = surface.count_entities_filtered({ position = site, radius = Nt.R, force = ENEMY_FORCE })
  local pts = {}
  if left > 0 then
    local list = surface.find_entities_filtered({ position = site, radius = Nt.R, force = ENEMY_FORCE, type = ENEMY_TYPES, limit = 24 })
    if #list == 0 then list = surface.find_entities_filtered({ position = site, radius = Nt.R, force = ENEMY_FORCE, limit = 8 }) end
    for _, e in ipairs(list) do pts[#pts + 1] = { x = e.position.x, y = e.position.y } end
  end
  return left, pts
end

--- Centre des soldats vivants (point de départ du choix de cible).
local function centroid(alive, soldiers, fallback)
  local sx, sy, n = 0, 0, 0
  for _, id in ipairs(alive) do
    local p = soldiers[id].entity.position
    sx, sy, n = sx + p.x, sy + p.y, n + 1
  end
  if n == 0 then return fallback end
  return { x = sx / n, y = sy / n }
end

--- Une opération en cours avance d'un pas. Rend vrai si elle est toujours en cours.
local function advance(f, t, sd, soldiers, per, surface, tick, ctx)
  local op = sd.nt
  local alive, dead = census(op, soldiers)
  local site = { x = op.x, y = op.y }
  local obs = { tick = tick, alive = #alive, dead = dead, present = 0 }
  if op.phase == "rassemble" then
    -- Annulée avant l'attaque si le site n'est plus bloqué (blocage échu, besoin disparu) ou si le QG est menacé.
    local sig = (f.site_blocked or {})[op.res]
    local needed = ((f.site_needs or {})[op.res] or 0) > 0
    if ctx.threatened or not sig or not needed then
      local why = ctx.threatened and "qg-menace" or (not sig and "site-plus-bloque" or "besoin-disparu")
      say(f, t, "annule tick %d %s : (%d, %d) avant l'attaque, motif %s ; %d soldat(s) rentrent", tick, op.res,
        math.floor(op.x), math.floor(op.y), why, #alive)
      inc(t, "nt_cancel")
      release(f, sd, op, soldiers, per, tick, ctx.command)
      return false
    end
    for _, id in ipairs(alive) do
      if d2(soldiers[id].entity.position, op.rally) <= Nt.GATHER_R * Nt.GATHER_R then obs.present = obs.present + 1 end
    end
  else
    local left, pts = enemies_at(surface, site)
    obs.left = left
    op.pts = pts
  end
  local nxt = Nt.step(op, obs)
  if nxt == "attaque" and op.phase == "rassemble" then
    op.phase, op.t_phase = "attaque", tick
    inc(t, "nt_attack")
    say(f, t, "attaque tick %d %s : (%d, %d), %d soldat(s) vivant(s) dont %d au rassemblement (%d, %d) apres %.1f min", tick,
      op.res, math.floor(op.x), math.floor(op.y), #alive, obs.present, math.floor(op.rally.x), math.floor(op.rally.y),
      (tick - op.t0) / 3600)
    local left, pts = enemies_at(surface, site)
    obs.left, op.pts = left, pts
  elseif nxt == "nettoye" then
    -- Les soldats sur place ont tout vu : la carte de connaissance et la carte du danger oublient le champ.
    local km = f.ai3f and f.ai3f.m
    local forgot = km and K.forget_enemies(km, op.x, op.y, Nt.R) or 0
    D.forget_unseen(t.map, op.x, op.y, Nt.R + 2, nil)
    local u = Sites.unblock(f, surface, site, op.res, tick)
    inc(t, "nt_cleared")
    if u.still then inc(t, "nt_reblocked") end
    say(f, t, "nettoye tick %d %s : (%d, %d) a %d tuiles du QG en %.1f min, %d mort(s) sur %d ; %d point(s) oublie(s) de la carte ; site %s ; %d site(s) admissible(s)%s",
      tick, op.res, math.floor(op.x), math.floor(op.y), op.d, (tick - op.t0) / 3600, dead, op.n0, forgot,
      u.in_reserve and "en reserve" or "non remis en reserve (examen refuse)", u.n or 0,
      u.still and " ; RE-BLOQUE (signal encore pose)" or " ; signal retire")
    if u.still then
      say(f, t, "re-bloque tick %d %s : (%d, %d) bloque de nouveau apres le nettoyage (ennemi revenu ou autre motif)", tick,
        op.res, math.floor(op.x), math.floor(op.y))
    end
    say(f, t, "retour tick %d %s : %d soldat(s) rentrent au QG", tick, op.res, #alive)
    release(f, sd, op, soldiers, per, tick, ctx.command)
    ctx.cleared = site
    return false
  elseif nxt == "retraite" or nxt == "abandon" then
    sd.nt_cool = sd.nt_cool or {}
    sd.nt_cool[#sd.nt_cool + 1] = { x = op.x, y = op.y, ["until"] = tick + Nt.COOL }
    inc(t, nxt == "retraite" and "nt_retreat" or "nt_abandon")
    say(f, t, "%s tick %d %s : (%d, %d), %d mort(s) sur %d, %s ennemi(s) encore a %d tuiles ; site non retente %.0f min", nxt, tick,
      op.res, math.floor(op.x), math.floor(op.y), dead, op.n0, tostring(obs.left or "?"), Nt.R, Nt.COOL / 3600)
    release(f, sd, op, soldiers, per, tick, ctx.command)
    return false
  end
  -- Commandes : rassemblement (une fois), puis attaque de la cible la plus proche des soldats (relancée quand elle change).
  if op.phase == "attaque" then
    local target = Nt.next_target(op.pts, centroid(alive, soldiers, op.rally))
    if target then
      local key = math.floor(target.x) .. ":" .. math.floor(target.y)
      if key ~= op.tkey then
        op.tkey = key
        for _, id in ipairs(alive) do
          ctx.command(soldiers[id].entity, { role = "clear", x = target.x, y = target.y }, f)
          if per[id] then per[id].key = "nettoyage-site:" .. key end
        end
      end
    end
  end
  return true
end

--- Début d'une opération : les `take` soldats disponibles les plus proches du site (distance, puis numéro).
local function launch(f, t, sd, dec, avail, soldiers, per, tick, ctx)
  local c = dec.site
  local ranked = {}
  for _, s in ipairs(avail) do ranked[#ranked + 1] = { s = s, d = d2(s, c) } end
  table.sort(ranked, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.s.id < b.s.id end)
  local km = f.ai3f and f.ai3f.m
  local rally = Nt.rally(f.hq_pos, c, function(x, y)
    if not km then return true end
    local n, w = K.enemies_near(km, x, y, Sd.SAFE_R)
    return n + w == 0
  end)
  local ids = {}
  for i = 1, math.min(dec.take, #ranked) do
    local id = ranked[i].s.id
    ids[#ids + 1] = id
    local s, ps = soldiers[id], per[id]
    ctx.command(s.entity, { role = "guard", x = rally.x, y = rally.y }, f)
    s.ia3k = "clear" -- drapeau lu par le rappel du chef (military.lua) : rôle qui éloigne légitimement du QG
    ps.role, ps.key, ps.escort = "nettoyage-site", "nettoyage-site:rally", nil
    C.label_entity(ps, s.entity, "nettoyage", tick, t.stats)
  end
  sd.nt = { res = c.resource, x = c.x, y = c.y, d = c.d, phase = "rassemble", ids = ids, n0 = #ids, need = dec.need, t0 = tick,
    t_phase = tick, rally = { x = rally.x, y = rally.y } }
  inc(t, "nt_ops")
  say(f, t, "prepare tick %d %s : site proche (%d, %d) a %d tuiles du QG bloque (%s), %d nid(s) et %d ver(s) connus ; effectif estime %d, %d soldat(s) pris sur %d au QG (reserve gardee %d) ; rassemblement en (%d, %d)%s",
    tick, c.resource, math.floor(c.x), math.floor(c.y), c.d, tostring(c.why), c.nests, c.worms, dec.need, #ids, dec.home,
    dec.reserve, math.floor(rally.x), math.floor(rally.y), rally.at_hq and " (au QG)" or "")
end

--- Passage pour la faction f (script/ai3/soldats.lua, pass). list = soldiers sans groupe { id, x, y, role, rest_until } triés
--- par id ; ctx = { threatened, km, command = command_for de soldats.lua, expedition = sd.clearing }. Rend { taken = { [id] =
--- true }, n, hold, site, cleared } (cleared : site nettoyé ou trouvé libre à ce passage ; ses menaces sont retirées par l'appelant).
function Nts.pass(f, t, sd, list, soldiers, per, surface, tick, ctx)
  local out = { taken = {}, n = 0, hold = false }
  if sd.nt then
    if advance(f, t, sd, soldiers, per, surface, tick, ctx) then
      for _, id in ipairs(sd.nt.ids) do out.taken[id] = true out.n = out.n + 1 end
      out.hold, out.site = true, { x = sd.nt.x, y = sd.nt.y }
      return out
    end
    out.cleared = ctx.cleared
  end
  local cool = {}
  for _, c in ipairs(sd.nt_cool or {}) do if tick < c["until"] then cool[#cool + 1] = c end end
  sd.nt_cool = cool
  local cands = Nt.candidates(f.site_blocked, f.site_needs, tick, cool)
  if #cands == 0 then
    sd.nt_wait = nil
    return out
  end
  local km = ctx.km
  for _, c in ipairs(cands) do
    c.nests, c.worms = 0, 0
    if km then c.nests, c.worms = K.enemies_near(km, c.x, c.y, Nt.R) end
    c.seen = km ~= nil and K.seen_xy(km, c.x, c.y)
  end
  -- Soldats disponibles au QG : sans groupe, près du QG, ni au repos ni pris par une défense, une escorte, une chasse ou un
  -- nettoyage en cours (sd.clearing).
  local avail = {}
  for _, s in ipairs(list) do
    local busy = s.role == "escort" or s.role == "defense" or s.role == "hunt" or s.role == "clear"
    if not busy and not (s.rest_until and tick < s.rest_until) and d2(s, f.hq_pos) <= Sd.NEAR_HQ * Sd.NEAR_HQ then
      avail[#avail + 1] = s
    end
  end
  sd.nt_check = sd.nt_check or {}
  local dec = Nt.decide({ cands = cands, home = #avail, threatened = ctx.threatened, busy = false, checked = sd.nt_check, tick = tick,
    expedition = ctx.expedition })
  sd.nt_wait = sd.nt_wait or {}
  for _, nt in ipairs(dec.notes or {}) do
    local r = nt.site.resource
    if sd.nt_wait[r] ~= nt.reason then
      sd.nt_wait[r] = nt.reason
      say(f, t, "attente tick %d %s : site proche (%d, %d) a %d tuiles bloque (%s), motif %s (aucune operation)", tick, r,
        math.floor(nt.site.x), math.floor(nt.site.y), nt.site.d, tostring(nt.site.why), nt.reason)
    end
  end
  if dec.action == "lancer" then
    sd.nt_wait[dec.site.resource] = nil
    launch(f, t, sd, dec, avail, soldiers, per, tick, ctx)
    for _, id in ipairs(sd.nt.ids) do out.taken[id] = true out.n = out.n + 1 end
    out.hold, out.site = true, { x = sd.nt.x, y = sd.nt.y }
  elseif dec.action == "attendre" then
    local r = dec.site.resource
    inc(t, "nt_wait_" .. dec.reason)
    if sd.nt_wait[r] ~= dec.reason then
      sd.nt_wait[r] = dec.reason
      say(f, t, "attente tick %d %s : site proche (%d, %d) a %d tuiles bloque (%s), %d nid(s) et %d ver(s) connus, effectif estime %d, %d soldat(s) au QG dont %d engageable(s) (reserve %d) : motif %s",
        tick, r, math.floor(dec.site.x), math.floor(dec.site.y), dec.site.d, tostring(dec.site.why), dec.site.nests,
        dec.site.worms, dec.need, dec.home, dec.surplus, dec.reserve, dec.reason)
    end
    out.hold = Nt.holds(dec)
    out.site = { x = dec.site.x, y = dec.site.y }
  elseif dec.action == "reverifier" then
    local c = dec.site
    sd.nt_check[c.resource] = tick
    sd.nt_wait[c.resource] = nil
    local u = Sites.unblock(f, surface, c, c.resource, tick)
    if not u.still then out.cleared = { x = c.x, y = c.y } end
    inc(t, u.still and "nt_recheck_blocked" or "nt_recheck_free")
    say(f, t, "reverifie tick %d %s : site proche (%d, %d) a %d tuiles bloque (hostile) sans nid ni ver connu ; nouvel examen : %s",
      tick, c.resource, math.floor(c.x), math.floor(c.y), c.d, u.still and "toujours bloque (ennemi present)" or
      (u.in_reserve and "libre, site en reserve" or "libre, examen refuse"))
  end
  return out
end

return Nts
