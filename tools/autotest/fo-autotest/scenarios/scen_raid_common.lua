--[[
  Sprint s43, pilier A (agent 3, scen-raid) : ASSAUT COORDONNÉ D'UNE FACTION RIVALE SUR UN AVANT-POSTE ISOLÉ.

  THÉORIE (ce qu'un défenseur et un attaquant compétents font ; ce que le scénario mesure) :
    Défenseur :
      D1 DÉTECTER : un bâtiment d'avant-poste touché par une unité adverse est vu tout de suite, à toute distance du QG
         (script/team/reparation.lua on_damaged -> Rep.on_attack -> C.on_alert mode « site », script/ai3/soldats.lua).
      D2 RÉPONDRE EN PROPORTION : des soldats partent vers le site, en nombre qui tient tête à l'escouade vue (pas 4 isolés
         contre 8) ; s'il n'en a pas assez au-dessus de la réserve du QG, il n'en envoie AUCUN (pas de goutte-à-goutte).
      D3 TOURELLES : l'avant-poste a ses tourelles de périmètre (shared/team/perimetre_tourelles.lua) rechargées.
      D4 RECONSTRUIRE : ce qui est détruit revient (ruine gardée, script/team/ruines.lua ; reconstruction en place).
      D5 GARDER L'ÉCONOMIE : un raid loin du QG ne gèle pas le QG (f.threatened_until n'est posé que pour une perte à moins
         de THREAT_RADIUS du QG, script/faction/commander.lua on_died) : les livraisons du QG continuent.
    Attaquant (chef de faction, script/faction/chef.lua) : vise l'avant-poste VU le plus faible (raid, mem.weak), renonce
      au rassemblement si la défense vue a grossi (go / no-go), rentre s'il perd. Cette moitié est jouée par l'IA, pas par
      ce banc : l'escouade posée ici est scriptée (elle ne recule pas) ; elle mesure la DÉFENSE.

  MISE EN SCÈNE : partie du guide (2 factions, 30 soldats, Normal). À la minute M (opts.m ; N = opts.n fusiliers ; puis chaque minute jusqu'à M + 10 si
  personne n'a encore d'avant-poste), la faction A = 1re faction attaque l'avant-poste le plus éloigné du QG de la
  faction B = 2e faction : N fusiliers de A posés à OFF tuiles du site, du côté opposé au QG de B, ordre attack_area.
  Relevé toutes les 2 min jusqu'à +12 min : assaillants vivants, soldats de B à moins de 40 tuiles du site, foreuses de B
  à moins de 30 tuiles (avant / après : pertes puis reconstruction), tourelles de B à moins de 30 tuiles, alertes de site
  de B (envoyées, refusées), fer livré par B (économie du QG).
  Lancement : banc.py --out <archive> --graine <g> --qui s43-scen-raid -- 152000 scen-raid <source> (scen-raid-35 : 206000)
  Journal : [FO-SCEN-RAID].
]]

-- opts = { m = minute de l'assaut, n = taille de l'escouade } (scen-raid.lua : 20, 8 ; scen-raid-35.lua : 35, 16).
return function(opts)
local base = require("scenarios/verif_guide_common")(4)
local TAG = "[FO-SCEN-RAID] "
local init0, tick0 = base.init, base.tick
local MIN = 3600
local M = opts.m           -- minute de l'assaut
local TRY = 10             -- minutes de plus pour trouver un avant-poste
local SPAN = 12            -- minutes de relevé après l'assaut
local N, OFF, R_SITE = opts.n, 28, 30

base.description = string.format("s43 scen-raid : escouade de %d fusiliers d'une faction, minute %d, sur l'avant-poste le plus eloigne de l'autre", N, M)
base.check_tick = (M + TRY + SPAN) * MIN + 600

base.init = function(ctx)
  if init0 then init0(ctx) end
end

local function factions(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-cadence", "list") or {}) do
    if r.hq then out[#out + 1] = r end
  end
  return out
end

local function d2(a, b) local dx, dy = a.x - b.x, a.y - b.y return dx * dx + dy * dy end

local function count_near(s, force, pos, r, typ)
  return s.count_entities_filtered({ position = pos, radius = r, force = force, type = typ })
end

local function delivered_iron(ctx, key)
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key == key then return (r.delivered and r.delivered["iron-plate"]) or 0 end
  end
  return -1
end

local function dact(ctx, key)
  local st = ctx.remote("fo-ia3k", "status", key)
  return (st and st.stats and st.stats.dact) or {}
end

local function sample(ctx, st, label)
  local s = ctx.surface()
  local r = st.raid
  local alive = 0
  for _, u in ipairs(r.units or {}) do if u.valid then alive = alive + 1 end end
  local da = dact(ctx, r.def)
  local line = string.format("%s | assaillants %d/%d | soldats %s a <40 : %d | foreuses <%d : %d (avant %d) | tourelles <%d : %d (avant %d)"
    .. " | alertes site %d (loin %d) envoyees %d refusees %d critiques %d par la reserve %d | fer livre %s %d (+%d depuis l'assaut) | QG menace %s",
    label, alive, r.sent, r.def, count_near(s, r.dforce, r.pos, 40, "unit"), R_SITE,
    count_near(s, r.dforce, r.pos, R_SITE, "mining-drill"), r.drills0, R_SITE,
    count_near(s, r.dforce, r.pos, R_SITE, { "ammo-turret", "electric-turret", "fluid-turret" }), r.tur0,
    da.site_alerts or 0, da.site_alerts_far or 0, da.site_sent or 0, da.site_refused or 0, da.site_critical or 0, da.site_reserve_sent or 0, r.def,
    delivered_iron(ctx, r.def), delivered_iron(ctx, r.def) - r.iron0, tostring(r.hq_threat or "-"))
  log(TAG .. line)
  r.last = { alive = alive, drills = count_near(s, r.dforce, r.pos, R_SITE, "mining-drill"),
    def_near = count_near(s, r.dforce, r.pos, 40, "unit"), sent = da.site_sent or 0, refused = da.site_refused or 0,
    alerts = da.site_alerts or 0 }
  r.min_drills = math.min(r.min_drills or r.drills0, r.last.drills)
  r.max_def = math.max(r.max_def or 0, r.last.def_near)
end

local function launch(ctx, st, tick)
  local fs = factions(ctx)
  if #fs < 2 then return false end
  local A, B = fs[1], fs[2]
  local s = ctx.surface()
  local best, bd = nil, -1
  for _, d in ipairs(s.find_entities_filtered({ type = "mining-drill", force = B.force })) do
    local p = d.position
    local k = d2(p, B.hq)
    if k > bd or (k == bd and (p.x < best.x or (p.x == best.x and p.y < best.y))) then best, bd = { x = p.x, y = p.y }, k end
  end
  if not best or bd < 40 * 40 then
    log(TAG .. string.format("minute %d : %s n'a pas d'avant-poste a plus de 40 tuiles du QG (foreuse la plus loin : %s)",
      tick / MIN, B.key, best and string.format("%d tuiles", math.floor(math.sqrt(bd))) or "aucune"))
    return false
  end
  local dist = math.sqrt(bd)
  local ux, uy = (best.x - B.hq.x) / dist, (best.y - B.hq.y) / dist
  local c = { x = best.x + ux * OFF, y = best.y + uy * OFF }
  local name = "fo-" .. A.key .. "-rifleman"
  local units = {}
  for i = 1, N do
    local spot = s.find_non_colliding_position(name, { c.x - uy * (i - 4.5) * 1.5, c.y + ux * (i - 4.5) * 1.5 }, 8, 0.5)
    local u = spot and s.create_entity({ name = name, position = spot, force = A.force })
    if u then
      u.set_command({ type = defines.command.attack_area, destination = best, radius = 20, distraction = defines.distraction.by_enemy })
      units[#units + 1] = u
    end
  end
  st.raid = { att = A.key, def = B.key, dforce = B.force, pos = best, hq = { x = B.hq.x, y = B.hq.y }, dist = math.floor(dist), units = units, sent = #units,
    t0 = tick, drills0 = count_near(s, B.force, best, R_SITE, "mining-drill"),
    tur0 = count_near(s, B.force, best, R_SITE, { "ammo-turret", "electric-turret", "fluid-turret" }),
    iron0 = delivered_iron(ctx, B.key), soldiers0 = s.count_entities_filtered({ type = "unit", force = B.force }) }
  log(TAG .. string.format("ASSAUT minute %d : %s -> avant-poste de %s en (%d, %d), %d tuiles de son QG | %d %s poses a %d tuiles"
    .. " | %s : %d unites en tout, foreuses du site %d, tourelles du site %d",
    tick / MIN, A.key, B.key, math.floor(best.x), math.floor(best.y), st.raid.dist, #units, name, OFF, B.key,
    st.raid.soldiers0, st.raid.drills0, st.raid.tur0))
  return true
end

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  local st = ctx.state()
  if e.tick % MIN ~= 0 then
    if st.raid and e.tick % 120 == 0 then
      local s = ctx.surface()
      -- Lieu de disparition de chaque assaillant (distance au site et au QG du défenseur : tourelle du site ou QG).
      st.raid.seen = st.raid.seen or {}
      for i, u in ipairs(st.raid.units or {}) do
        if u.valid then
          st.raid.seen[i] = { x = u.position.x, y = u.position.y }
        elseif st.raid.seen[i] and not st.raid.seen[i].gone then
          local p = st.raid.seen[i]
          p.gone = true
          log(TAG .. string.format("assaillant %d disparu %.1f s apres l'assaut, vu en dernier en (%d, %d) : %d tuiles du site, %d du QG de %s",
            i, (e.tick - st.raid.t0) / 60, math.floor(p.x), math.floor(p.y), math.floor(math.sqrt(d2(p, st.raid.pos))),
            math.floor(math.sqrt(d2(p, st.raid.hq))), st.raid.def))
        end
      end
      local n = count_near(s, st.raid.dforce, st.raid.pos, 40, "unit")
      if n > (st.raid.max_def or 0) then st.raid.max_def = n end
      if not st.raid.first_def and n > 0 then
        st.raid.first_def = e.tick
        log(TAG .. string.format("premier defenseur sur le site %.1f s apres l'assaut", (e.tick - st.raid.t0) / 60))
      end
    end
    return
  end
  local m = e.tick / MIN
  if not st.raid and m >= M and m <= M + TRY then launch(ctx, st, e.tick) end
  if st.raid and (e.tick - st.raid.t0) % (2 * MIN) == 0 and e.tick > st.raid.t0 and e.tick - st.raid.t0 <= SPAN * MIN then
    sample(ctx, st, string.format("+%d min", (e.tick - st.raid.t0) / MIN))
  end
end

base.finish = function(ctx)
  local st = ctx.state()
  local r = st.raid
  ctx.check(r ~= nil, "assaut lance (avant-poste trouve)")
  if not r then return end
  ctx.check(r.sent >= N - 1, "escouade posee", r.sent)
  local l = r.last or {}
  -- MESURES (le verdict est la théorie : D1 à D5) ; les contrôles exigés sont seulement ceux de la mise en scène.
  log(TAG .. string.format("BILAN D1 detecte : %s (alertes site %d) | D2 defenseurs au plus %d sur le site, premier a %s s, envoyees %d refusees %d"
    .. " | assaillants restants %d/%d | D4 foreuses %d -> min %d -> %d | D5 fer livre +%d pendant l'assaut",
    tostring((l.alerts or 0) > 0), l.alerts or 0, r.max_def or 0,
    r.first_def and string.format("%.1f", (r.first_def - r.t0) / 60) or "jamais", l.sent or 0, l.refused or 0, l.alive or -1, r.sent,
    r.drills0, r.min_drills or r.drills0, l.drills or -1, delivered_iron(ctx, r.def) - r.iron0))
  r.units = nil
end

return base
end
