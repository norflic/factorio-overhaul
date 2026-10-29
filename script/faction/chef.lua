--[[
  Chef d'une faction (lot IA2-a) : exécution de la pensée pure de shared/faction/chef.lua.

  - Une pensée par minute (C.PERIOD), dans la pensée du commandant (voie fo-commander) : vue (économie, stock,
    armée, menaces, adversaires VUS), tirage du seuil d'attaque entre factions (flux de la faction, IA2-0), décision
    du chef, ligne publiée « [FO-STRAT] posture ».
  - BROUILLARD (D-16, « brouillard partout ») : le chef ne connaît d'une rivale que ce que ses yeux ont vu : avant-
    postes et tourelles à moins de VISION_HQ tuiles de son QG, VISION_OUTPOST de ses avant-postes, VISION_GROUP de ses
    groupes en route ; groupes rivaux en route passés dans ce champ (armée sortie, menace). Les QG rivaux (positions
    de départ) sont connus. Ce qui a été vu est retenu SEEN_TTL ticks. La défense estimée d'une rivale vient de ces
    seules observations (+ ce que la mémoire a appris des attaques repoussées). Le repérage PvP du joueur (IA0) n'est
    PAS changé (garanties de pvp_test) : le chef ne lit pas le joueur en v0.
  - Attaques : cible = la rivale choisie par le chef ; côté d'arrivée tiré parmi les 3 meilleurs octants
    (rassemblement avancé à C.SIDE_RADIUS tuiles de la cible) ; raids. Issue d'une attaque (fin de l'attaque du
    groupe) : mémoire du chef et ligne « [FO-STRAT] issue ».
  - Partie existante (sans chef) : état créé à la première pensée, flux du chef tiré de la graine (sel 200 + id).

  Flux : `f.chef.stream` = Tr.new_stream(graine, 200 + id) (sels 200 à 299 : chef d'IA2-a ; 0 à 99 : IA2-0 ;
  100 à 199 : réservés à IA2-b). Le multiplicateur du seuil (f.attack_jitter) reste tiré dans f.rng (IA2-0), à
  chaque pensée du chef en plus de chaque attaque contre une faction.
]]

local Events = require("script.core.events")
local Profiler = require("script.core.profiler")
local F = require("shared.faction.config")
local S = require("shared.faction.strategy")
local C = require("shared.faction.chef")
local Tr = require("shared.faction.traits")
local State = require("script.faction.state")
local Stock = require("script.team.stock") -- lot COFFRE : stock = coffre du QG + annexes
local Character = require("script.faction.character")
local Military = require("script.faction.military")
local Sites = require("script.faction.sites")
local A = require("shared.faction.adversaire")

local Chef = {}

Chef.SALT = 200
local VISION_HQ = 160
local VISION_OUTPOST = 128
local VISION_GROUP = 96
local SEEN_TTL = 30 * 3600
local TURRET_NEAR = 24
local LOSS_WINDOW = 10 -- pensées (minutes) pour les soldats perdus récents

local function draw_of(st)
  return function(n) return Tr.range(st.stream, 1, n) end
end

--- État du chef d'une faction (créé à la première lecture : partie neuve ou existante).
function Chef.state(f, tick)
  if not f.chef then
    f.chef = C.new(Tr.new_stream(Character.map_seed(), Chef.SALT + f.id), tick or 0)
    f.chef.seen = {}
    f.chef.loss_hist = {}
    f.chef.outposts_lost_seen = f.stats and f.stats.outposts_lost or 0
  end
  return f.chef
end

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

--- Points de vue de la faction : { x, y, r2 } (QG, avant-postes, groupes en route).
local function eyes(f)
  local list = {}
  if f.hq_pos then list[#list + 1] = { x = f.hq_pos.x, y = f.hq_pos.y, r2 = VISION_HQ * VISION_HQ } end
  for _, oid in ipairs(State.sorted_keys(f.outposts)) do
    local p = f.outposts[oid].pos
    list[#list + 1] = { x = p.x, y = p.y, r2 = VISION_OUTPOST * VISION_OUTPOST }
  end
  for _, gid in ipairs(State.sorted_keys(f.groups)) do
    local g = f.groups[gid]
    if g.group and g.group.valid then
      local p = g.group.position
      list[#list + 1] = { x = p.x, y = p.y, r2 = VISION_GROUP * VISION_GROUP }
    end
  end
  return list
end

local function seen_by(list, p)
  for _, e in ipairs(list) do
    if d2(e, p) <= e.r2 then return true end
  end
  return false
end

--- Observation des rivales (brouillard) : met à jour f.chef.seen et renvoie la liste des rivales pour la vue pure,
--- plus enemy_near (un groupe rival en route vu chez nous).
function Chef.observe(f, tick)
  local st = Chef.state(f, tick)
  local war = State.war()
  local my = eyes(f)
  local rivals, enemy_near = {}, false
  local tn2 = TURRET_NEAR * TURRET_NEAR
  for _, rid in ipairs(State.alive()) do
    if rid ~= f.id then
      local r = war.factions[rid]
      local mem = st.seen[rid] or {}
      st.seen[rid] = mem
      -- Avant-postes vus maintenant, tourelles proches de chacun.
      local seen_n, turrets_n, weak, weak_t, weak_d = 0, 0, nil, nil, nil
      local turret_list = {}
      for _, tid in ipairs(State.sorted_keys(r.turrets or {})) do
        local t = r.turrets[tid]
        if t and t.valid then turret_list[#turret_list + 1] = t.position end
      end
      for _, oid in ipairs(State.sorted_keys(r.outposts or {})) do
        local p = r.outposts[oid].pos
        if seen_by(my, p) then
          seen_n = seen_n + 1
          local nt = 0
          for _, tp in ipairs(turret_list) do if d2(tp, p) <= tn2 then nt = nt + 1 end end
          turrets_n = turrets_n + nt
          local dh = r.hq_pos and d2(p, r.hq_pos) or 0
          if not weak or nt < weak_t or (nt == weak_t and dh > weak_d) then weak, weak_t, weak_d = p, nt, dh end
        end
      end
      -- Groupes rivaux en route vus (armée sortie ; menace s'ils sont chez nous).
      local army_out, army_seen = false, 0
      for _, gid in ipairs(State.sorted_keys(r.groups or {})) do
        local g = r.groups[gid]
        if g.state == "attack" and g.group and g.group.valid then
          local gp = g.group.position
          if seen_by(my, gp) then
            army_out = true
            local n = #g.group.members
            if n > army_seen then army_seen = n end
            if g.target_faction == f.id then
              enemy_near = true
              -- Lot IA2-c : attaque REÇUE de cette rivale, comptée une fois par groupe vu.
              mem.recv_gids = mem.recv_gids or {}
              local known = false
              for _, x in ipairs(mem.recv_gids) do if x == gid then known = true break end end
              if not known then
                mem.recv_gids[#mem.recv_gids + 1] = gid
                while #mem.recv_gids > 8 do table.remove(mem.recv_gids, 1) end
                C.record_received(st, rid, tick)
              end
            end
          end
        end
      end
      if seen_n > 0 then
        mem.outposts, mem.turrets, mem.tick = seen_n, turrets_n, tick
        mem.weak = { x = weak.x, y = weak.y, turrets = weak_t }
      elseif mem.tick and tick - mem.tick > SEEN_TTL then
        mem.outposts, mem.turrets, mem.weak, mem.tick = nil, nil, nil, nil
      end
      if army_seen > (mem.army or 0) then mem.army = army_seen end
      local outposts = mem.outposts or 0
      local strength = S.soldier_strength(F.best_soldier(r.tech or 0), r.tech or 0, r.upgrades or 0)
      local defense
      if outposts > 0 then
        defense = 8 * math.min(mem.turrets or 0, 2 * outposts) / outposts + 0.3 * (mem.army or 0) * strength
      else
        defense = 8 * F.military.hq_turrets + (mem.army or 0) * strength
      end
      mem.defense = defense
      -- Lot IA2-c : MODÈLE de la rivale (shared/faction/adversaire.lua) : relevé par pensée (avant-postes vus, comptés
      -- comme 2 unités de territoire, tourelles vues), attaques reçues d'elle, nos attaques qu'elle a repoussées.
      A.snap(mem, { tick = tick, units = 2 * outposts, turrets = mem.turrets or 0 })
      local repulsed = 0
      for _, a in ipairs(st.attacks) do
        if a.target == rid and (a.outcome == "repoussee" or a.outcome == "aneantie") then repulsed = repulsed + 1 end
      end
      local style = A.classify({ units = 2 * outposts, turrets = mem.turrets or 0, growth = A.growth(mem, tick),
        hits = C.received_recent(st, rid, tick, A.HIT_WINDOW), repulsed = repulsed })
      if style ~= (mem.style or "inconnu") then
        log(string.format("[FO-STRAT] modele tick %d %s -> %s : style %s (avant %s) : avant-postes vus %d, tourelles vues %d, croissance %d, attaques recues %d, repoussees %d",
          tick, f.key, r.key, style, mem.style or "inconnu", outposts, mem.turrets or 0, A.growth(mem, tick),
          C.received_recent(st, rid, tick, A.HIT_WINDOW), repulsed))
      end
      mem.style = style
      local aim = mem.weak or r.hq_pos
      rivals[#rivals + 1] = {
        id = rid, outposts_seen = outposts, defense = defense, army_out = army_out, style = style,
        weak = mem.weak ~= nil, weak_turrets = mem.weak and mem.weak.turrets or nil,
        dist = (aim and f.hq_pos) and math.floor(math.sqrt(d2(aim, f.hq_pos))) or 600,
        reachable = not Military.target_unreachable(f, rid, tick),
        bare = (r.outposts_count or 0) == 0, -- lot IA2-a2 : QG nu (même donnée que Military.target_of)
      }
    end
  end
  return rivals, enemy_near
end

local function stock(f, name)
  if not (f.hq and f.hq.valid) then return 0 end
  return Stock.count(f, name)
end

local function count_keys(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

--- Avant-postes sans tourelle.
local function unprotected(f)
  local has = {}
  for _, tid in ipairs(State.sorted_keys(f.turrets or {})) do
    local o = State.owner(tid)
    if o and o.oid then has[o.oid] = true end
  end
  local n = 0
  for _, oid in ipairs(State.sorted_keys(f.outposts)) do if not has[oid] then n = n + 1 end end
  return n
end

--- Vue pure du chef.
function Chef.view(f, tick)
  local st = Chef.state(f, tick)
  local war = State.war()
  local ch = Character.of(f)
  local rivals, enemy_near = Chef.observe(f, tick)
  -- Soldats perdus pendant les LOSS_WINDOW dernières pensées.
  local lost_now = f.stats.soldiers_lost or 0
  local hist = st.loss_hist
  hist[#hist + 1] = lost_now
  while #hist > LOSS_WINDOW + 1 do table.remove(hist, 1) end
  local smax = war.settings and war.settings.soldiers_max or F.defaults.soldiers_max
  local scale = f.team and f.team.scale and f.team.scale.last
  return {
    tick = tick, minutes = math.floor((tick - (war.started or 0)) / 3600), traits = ch.traits,
    outposts = f.outposts_count, desired = S.desired_outposts(f.tech or 0, ch.greed or 1),
    sites = f.prospects and #f.prospects or 0,
    best_site = Sites.best_value(f, tick), -- lot IA2-b : meilleur site connu par la carte de valeur (nil : aucun)
    iron = stock(f, "iron-plate"), copper = stock(f, "copper-plate"), coal = stock(f, "coal"), stone = stock(f, "stone"),
    tech = f.tech or 0, workers = f.engineers_count or 0, idle = scale and scale.idle or 0,
    goals = count_keys(f.team and f.team.done),
    soldiers = f.soldiers_count or 0, garrison = Military.garrison_near(f),
    army_target = S.army_target(ch, smax),
    strength = S.soldier_strength(F.best_soldier(f.tech or 0), f.tech or 0, f.upgrades or 0),
    reserve = 0, unprotected = unprotected(f),
    threatened = tick < (f.threatened_until or 0), soldiers_lost = lost_now - hist[1], enemy_near = enemy_near,
    rivals = rivals,
    -- Lot IA2-a2 (survie) : effectif de départ des ouvriers (plancher, publié par le cerveau d'équipe) et objectif
    -- « armée » atteint.
    floor = f.team and f.team.floor or nil, army_done = (f.team and f.team.done and f.team.done["army"]) and true or false,
  }
end

local function mix_text(d)
  local parts = {}
  for k, m in ipairs(d.mix) do
    local name = k == 1 and "dominante" or (k == 2 and "2e" or "3e")
    parts[#parts + 1] = string.format("%s %s (%d, %d %%)", name, m.key, m.score, math.floor(m.w / 10 + 0.5))
  end
  return table.concat(parts, ", ")
end

--- Pensée du chef (appelée par le commandant ; ne fait rien avant l'échéance).
function Chef.think(f, tick)
  local st = Chef.state(f, tick)
  if tick < (st.next_think or 0) then return nil end
  st.next_think = tick + C.PERIOD
  Profiler.start("faction:chef")
  -- Sites perdus depuis la pensée précédente (mémoire, menace, rancune envers le dernier destructeur vu).
  local lost = (f.stats.outposts_lost or 0) - (st.outposts_lost_seen or 0)
  for _ = 1, lost do C.record_loss(st, tick, st.last_killer) end
  st.outposts_lost_seen = f.stats.outposts_lost or 0
  -- Lot IA2-a : seuil de la prochaine attaque entre factions RE-TIRÉ à chaque pensée (avant IA2-a : seulement après
  -- une attaque, d'où un bâtisseur bloqué toute la partie par un premier tirage haut).
  Character.redraw(f)
  local v = Chef.view(f, tick)
  v.jitter = f.attack_jitter
  local d = C.think(st, v, draw_of(st))
  st.last_threat = d.threat -- lot VEILLE : menace de la dernière pensée (lue par script/ai3/exploration.lua et script/faction/veille.lua)
  log(string.format("[FO-STRAT] posture tick %d %s : %s, raison %s, menace %d, mult %d, cible %s, raid %s%s",
    tick, f.key, mix_text(d), (d.reason:gsub(" ", "_")), d.threat, d.war_mult,
    d.target and (State.faction(d.target) and State.faction(d.target).key or tostring(d.target)) or "-",
    d.raid and tostring(d.raid) or "-", d.changed and ", changement" or ""))
  -- Lot IA2-a2 : rivales battues à cette pensée (satiété) et trêve (toutes les rivales atteignables épargnées).
  for _, s in ipairs(d.sated_new or {}) do
    local t = State.faction(s.id)
    log(string.format("[FO-STRAT] satiete tick %d %s -> %s : battue (%d tues), epargnee %d min", tick, f.key,
      t and t.key or tostring(s.id), s.kills, math.floor((s.until_t - tick) / 3600)))
  end
  if d.hold ~= (st.hold_logged or false) then
    st.hold_logged = d.hold
    log(string.format("[FO-STRAT] treve tick %d %s : %s", tick, f.key, d.hold and "debut (rivales epargnees)" or "fin"))
  end
  Profiler.stop("faction:chef")
  return d
end

--- Cible rivale choisie par le chef (faction vivante et atteignable), ou nil.
function Chef.target(f, tick)
  local st = f.chef
  if not (st and st.target) then return nil end
  local t = State.faction(st.target)
  if not t or t.eliminated or Military.target_unreachable(f, t.id, tick) then return nil end
  return t
end

--- Défense estimée d'une rivale (brouillard + mémoire), ou nil sans observation.
function Chef.defense(f, tid)
  local st = f.chef
  local mem = st and st.seen and st.seen[tid]
  if not mem or not mem.defense then return nil end
  return mem.defense + (st.extra_defense[tid] or 0)
end

--- Lot IA2-a2 : un de nos groupes (hors raid) est-il encore en phase d'attaque contre la faction `tid` ?
function Chef.engaged(f, tid)
  for _, gid in ipairs(State.sorted_keys(f.groups or {})) do
    local g = f.groups[gid]
    if g.state == "attack" and g.target_faction == tid and not g.raid and g.group and g.group.valid then return true end
  end
  return false
end

--- Champs de la vue de décision (S.decide) : multiplicateur, raid.
function Chef.decision_fields(f, target, tick)
  local st = f.chef
  if not st then return nil end
  local raid, raid_defense = nil, nil
  if st.raid and not st.hold and target and st.raid_target == target.id then
    local mem = st.seen and st.seen[target.id]
    if mem and mem.weak then
      raid = st.raid
      raid_defense = 8 * (mem.weak.turrets or 0)
    end
  end
  -- Lot IA2-a2 : trêve (rivales épargnées par satiété) seulement si la rivale désignée est bien celle du chef ; et UNE
  -- VAGUE À LA FOIS : pas de nouvelle attaque ni de raid contre une rivale tant qu'un de nos groupes l'attaque encore
  -- (le chef attend l'issue). 1er essai du lot (moteur réel, graine 3141592653) : Azur lançait 32, puis 19, puis 17
  -- soldats contre Ambre en 5 min, avant l'issue de la première vague.
  -- Satiété lue À L'INSTANT (pas seulement à la pensée du chef) : 2e essai du lot (moteur réel, graine 20261020),
  -- Écarlate relançait 32 soldats contre Azur au tick même de l'issue « réussie » de la vague précédente.
  local tr = Character.of(f).traits or {}
  local hold = (st.hold and target and st.target == target.id)
    or (target and (Chef.engaged(f, target.id)
      or C.sated(st, { id = target.id, bare = (target.outposts_count or 0) == 0 }, tr, tick or 0))) or nil
  -- Lot ARMEE : attaque sans effet contre cette cible (attente croissante) ou hors de la portée déjà atteinte.
  local vain = target and target.id ~= "player" and C.vain_hold(st, target.id, tick or 0, Chef.distance(f, target)) or nil
  if (vain or false) ~= (st.vain_logged or false) then
    st.vain_logged = vain or nil
    local v = target and st.vain and st.vain[target.id]
    log(string.format("[FO-STRAT] vain tick %d %s -> %s : %s", tick or 0, f.key, target and target.key or "-",
      vain and string.format("%s (%d sans effet de suite, reprise au tick %d, portee atteinte %s sur %s tuiles)", vain,
        v and v.n or 0, v and v.ok_at or 0, v and v.reach and tostring(math.floor(v.reach)) or "-",
        v and v.dist and tostring(math.floor(v.dist)) or "-") or "fin"))
  end
  -- hold_rival : à un niveau agressif, aucune attaque ni raid contre la rivale (trêve, vague en cours, sans effet).
  -- Champ distinct de `hold` : le chemin contre le joueur (S.decide) et la campagne de pvp_test ne le lisent pas.
  return { war_mult = st.war_mult, raid = raid, raid_defense = raid_defense, posture = st.dominant, hold = hold,
    vain = vain, hold_rival = (hold or vain) and true or nil }
end

--- Lot ARMEE : distance (tuiles) de notre QG à celui de la cible (même mesure à l'envoi et à la décision).
function Chef.distance(f, target)
  local a, b = f.hq_pos, target and target.hq_pos
  if not (a and b) then return nil end
  return math.sqrt(d2(a, b))
end

--- Options d'une attaque contre une rivale : point visé (raid : l'avant-poste vu le plus faible), rassemblement
--- avancé (octant tiré parmi les 3 meilleurs), règle appliquée. nil sans chef.
function Chef.attack_opts(f, target, attack, tick)
  local st = f.chef
  if not st or not target or target.id == "player" then return nil end
  local tp
  if attack.raid then
    local mem = st.seen and st.seen[target.id]
    tp = mem and mem.weak and { x = mem.weak.x, y = mem.weak.y } or nil
  end
  if not tp then
    -- Lot IA2-a2 : périphérie d'abord (C.target_point) ; avant : l'avant-poste le plus proche de notre QG
    -- (Military.target_of), souvent dans la zone de départ de la rivale, à 45 tuiles de son QG.
    local list = {}
    for _, oid in ipairs(State.sorted_keys(target.outposts or {})) do list[#list + 1] = target.outposts[oid].pos end
    tp = C.target_point(list, target.hq_pos, f.hq_pos) or Military.target_of(target, f.hq_pos)
  end
  local ch = Character.of(f)
  -- Lot IA2-c : défense VUE par côté autour du point visé (tourelles de la rivale dans le champ de nos yeux).
  local my = eyes(f)
  local turrets = {}
  for _, tid in ipairs(State.sorted_keys(target.turrets or {})) do
    local t = target.turrets[tid]
    if t and t.valid then
      local p = t.position
      if d2(p, tp) <= A.DEF_RADIUS * A.DEF_RADIUS and seen_by(my, p) then turrets[#turrets + 1] = { x = p.x, y = p.y } end
    end
  end
  local sides = A.side_defense(turrets, tp, A.DEF_RADIUS)
  local o = C.pick_side(st, target.id, f.hq_pos.x - tp.x, f.hq_pos.y - tp.y, ch.traits and ch.traits.ruse or 1000, draw_of(st), sides)
  local dir = C.DIRS[o]
  local approach = { x = tp.x + dir[1] * C.SIDE_RADIUS, y = tp.y + dir[2] * C.SIDE_RADIUS }
  local mx = 0
  for k = 0, 7 do if sides[k] > mx then mx = sides[k] end end
  return { target = tp, approach = approach, octant = o, raid = attack.raid or nil, rule = attack.rule,
    side_def = sides[o], side_max = mx }
end

--- Lot IA2-c : GO / NO-GO au rassemblement avancé contre une rivale. Ce que le groupe voit maintenant (il est à
--- 56 tuiles du point visé, champ de 96) : tourelles de la rivale à 24 tuiles du point, soldats de la rivale à
--- 40 tuiles. Renonce si cette défense a grossi (≥ 1,5 × l'estimation du départ + 1 tourelle) et que la force du
--- groupe n'atteint plus 1,3 × elle (règle d'attaque entre factions).
function Chef.rally(f, g, tick)
  local t = State.faction(g.target_faction)
  if not t or t.eliminated then return true end
  local tp = g.target
  local nt = 0
  for _, tid in ipairs(State.sorted_keys(t.turrets or {})) do
    local e = t.turrets[tid]
    if e and e.valid and d2(e.position, tp) <= 24 * 24 then nt = nt + 1 end
  end
  local ns = 0
  for _, sid in ipairs(State.sorted_keys(t.soldiers or {})) do
    local s = t.soldiers[sid]
    if s.entity and s.entity.valid and d2(s.entity.position, tp) <= 40 * 40 then ns = ns + 1 end
  end
  local seen = 8 * nt + ns * S.soldier_strength(F.best_soldier(t.tech or 0), t.tech or 0, t.upgrades or 0)
  local n = #g.group.members
  local force = n * S.soldier_strength(F.best_soldier(f.tech or 0), f.tech or 0, f.upgrades or 0)
  local go = A.go(force, 1.3, g.launch_def or 0, seen)
  g.seen_def = seen
  log(string.format("[FO-STRAT] rassemblement tick %d %s -> %s : %s, defense vue %d (depart %d), force %d, %d soldats, octant %s",
    tick, f.key, t.key, go and "go" or "renonce", math.floor(seen), math.floor(g.launch_def or 0), math.floor(force), n,
    tostring(g.octant)))
  return go
end

---------------------------------------------------------------------------------------------------
-- Crochets du module militaire : départ et fin d'une attaque
---------------------------------------------------------------------------------------------------
Military.on_chef_launch = function(f, target_faction, n, rp, tick, gid)
  if target_faction.id == "player" or not f.chef then return end
  C.record_attack(f.chef, { target = target_faction.id, octant = rp.octant or -1, n = n, tick = tick, gid = gid,
    raid = rp.raid, dist = Chef.distance(f, target_faction) })
  if rp.raid then f.chef.raid = nil end
end

--- Fin de la phase d'attaque d'un groupe (retour ordonné, ou groupe vidé) : issue de l'attaque. `alive` : soldats
--- partis encore vivants (groupe ou garnison) ; un groupe vidé dont la moitié au moins vit encore a été DÉFAIT par
--- le moteur (F174), issue « dissous », sans leçon pour la mémoire.
Military.on_attack_ended = function(f, g, survivors, tick, alive)
  if not f.chef or g.target_faction == "player" or not g.target then return end
  local t = State.faction(g.target_faction)
  local standing = false
  if t and not t.eliminated then
    if t.hq_pos and d2(t.hq_pos, g.target) <= 16 * 16 then
      standing = t.hq ~= nil and t.hq.valid
    else
      for _, oid in ipairs(State.sorted_keys(t.outposts or {})) do
        if d2(t.outposts[oid].pos, g.target) <= 16 * 16 then standing = true break end
      end
    end
  end
  local outcome
  if g.renonce then
    outcome = "renonce" -- lot IA2-c : le groupe a renoncé au rassemblement avancé
  elseif not standing then
    outcome = "reussie"
  elseif survivors > 0 then
    outcome = "repoussee"
  elseif alive and alive * 2 >= (g.size or 0) and (g.size or 0) > 0 then
    outcome = "dissous"
  else
    outcome = "aneantie"
  end
  local reach = g.reach2 and math.sqrt(g.reach2) or nil -- lot ARMEE : point le plus éloigné du QG où le groupe a été vu
  local a = C.record_outcome(f.chef, g.gid, outcome, g.size, survivors, tick, g.seen_def, reach)
  log(string.format("[FO-STRAT] issue tick %d %s -> %s : %s, %d envoyes, %d survivants, octant %s%s, vivants %s, portee %s sur %s tuiles",
    tick, f.key, t and t.key or tostring(g.target_faction), outcome, g.size or 0, survivors,
    a and tostring(a.octant) or "-", a and a.raid and ", raid" or "", alive and tostring(alive) or "-",
    reach and tostring(math.floor(reach)) or "-", a and a.dist and tostring(math.floor(a.dist)) or "-"))
  if a and outcome == "reussie" then
    log(string.format("[FO-STRAT] satiete tick %d %s -> %s : battue (attaque reussie), epargnee %d min", tick, f.key,
      t and t.key or tostring(g.target_faction), math.floor(C.SATIETY / 3600)))
  end
end

---------------------------------------------------------------------------------------------------
-- Rancune : qui détruit nos bâtiments et nos soldats
---------------------------------------------------------------------------------------------------
Events.on(defines.events.on_entity_died, function(e)
  local war = State.war()
  if not war.active then return end
  local ent = e.entity
  if not (ent and ent.valid) then return end
  local f = State.by_force(ent.force.name)
  if not f then return end
  -- Lot IA2-a2 : qui détruit le QG d'une faction (anéantissement) : force du tueur, ou « aucune ».
  if ent.unit_number and f.hq and f.hq.valid and ent.unit_number == f.hq.unit_number then
    log(string.format("[FO-STRAT] qg detruit tick %d %s par %s", e.tick, f.key, e.force and e.force.name or "aucune"))
  end
  local killer = e.force
  if not killer then return end
  local k = State.by_force(killer.name)
  -- Lot IA2-a2 : un soldat ou un ouvrier de f tué par la faction k (satiété du vainqueur, C.record_kill).
  if k and k.id ~= f.id and k.chef and (ent.type == "unit" or ent.type == "character") then C.record_kill(k.chef, f.id, 1) end
  if not f.chef then return end
  local by = k and k.id or (killer.name == "player" and "player" or nil)
  if not by or by == f.id then return end
  C.record_hit(f.chef, by)
  local owner = ent.unit_number and State.owner(ent.unit_number)
  if owner and owner.kind == "drill" then f.chef.last_killer = by end
end)

return Chef
