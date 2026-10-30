--[[
  Lot PREVISION : RUNTIME de l'estimateur UNIQUE de la menace (règles pures : shared/ai3/prevision.lua pour l'estimation,
  shared/ai3/prevision_choix.lua pour les décisions). Une fois par minute et par équipe (factions ET votre équipe), il relève ce
  qu'un JOUEUR verrait (arbitrage du DC, 29/10, 22 h 15 : « comme le joueur ») :
    * l'évolution des biters (infobulle de la carte) et sa vitesse (réglages de carte) ;
    * la pollution AUX nids DÉJÀ VUS (carte de connaissance f.ai3f.m et carte du danger de l'équipe), et aux 4 cases voisines
      quand la case du nid est propre (le nuage de pollution de la carte) ; jamais un nid jamais vu ;
    * les unités ennemies À PORTÉE D'ŒIL de nos sites (K.EYE : QG 160, avant-poste 128 ; champs : 128) ; jamais celles qui
      entourent un nid que personne ne regarde (l'ancien corps d'ARMEE-ANTICIPATION les comptait : retiré) ;
    * nos propres bâtiments : émission de pollution (prototypes, emissions_per_second) et tourelles (dégâts, cadence, portée lus
      aux prototypes de la tourelle et de sa munition) par site : QG, avant-postes, champs ouverts de la capitalisation ;
    * nos pertes au contact (crochet Front.on_loss, posé ici, appelé par script/team/front.lua à la mort d'une pièce).
  Il écrit l'état f.prevision (créé ici, en événement ; nombres, chaînes et tables : global par l'état de guerre) :
    { t, cal (calibration : k d'équipe sous Pv.TEAM, épisodes par site), pc (décisions Pc), est (résumé), hits, kills (unités
      tuées depuis le relevé), nests_prev (nids connus au relevé précédent : garnison), logs, kit_iron, turret_iron, key_item,
      reserve, hp_per_emit, turret_value, log_t }.
  Lecteurs : script/ai3/soldats.lua (armée : Prev.army), script/team/front.lua (tourelles d'avance : Front.prevu, posé ici),
  script/ai3/cerveau.lua (pile : Prev.pile_rows ; capitalisation : Prev.capi_defense), script/team/team.lua (armée visée à moyen
  terme : f.prevision.pc.army_soon).
  Journal [FO-PREVISION] (chaînes brutes, F237) : un état toutes les Prev.LOG_EVERY ticks, une ligne par CHANGEMENT de décision
  et par fait de calibration ; aucune décision ne le lit.
  Coupure de banc : war_option « prevision » = false (aucune prévision : l'armée n'a plus d'alerte, aucun cadre, aucun coût).
  Aucun require en événement ; caches LOCAUX des prototypes (identiques chez tous les pairs, reconstruits à la demande, jamais
  en on_load) ; listes triées ; aucun temps mesuré.
]]

local State = require("script.faction.state")
local K = require("shared.ai3.carte")
local R = require("shared.ai3.reglages")
local T = require("shared.team.config")
local FC = require("shared.faction.config")
local FS = require("shared.faction.strategy")
local Pv = require("shared.ai3.prevision")
local Pc = require("shared.ai3.prevision_choix")
local Stock = require("script.team.stock")
local Planner = require("shared.team.planner") -- soldat que l'équipe FABRIQUE (P.best_unit : échelle des équipements)
local Front = require("script.team.front")
local Events = require("script.core.events")
local C = require("script.ai3.comportement")
local D = require("shared.ai3.danger")

local Prev = {}

Prev.SITE_R = { qg = 48, ap = 24, ch = 20 } -- tuiles : bâtiments d'un site (émission, tourelles)
Prev.EYE = { qg = K.EYE.hq, ap = K.EYE.outpost, ch = K.EYE.outpost }
Prev.CONTACT_R = 48     -- tuiles : unités « au contact » d'un site (vague reçue)
Prev.GARRISON_R = 24    -- tuiles : une unité aussi près d'un nid connu est sa garnison (raid), pas une vague
Prev.LOSS_R = 64        -- tuiles : une perte compte pour le site le plus proche à moins de cela
Prev.OUTPOSTS_MAX = 8   -- avant-postes examinés au plus
Prev.FIELDS_MAX = 6     -- champs ouverts de la capitalisation examinés au plus (hors QG et avant-postes)
Prev.FIELD_SEP = 40     -- tuiles : un champ plus près que cela d'un site déjà compté n'est pas un site de plus
Prev.HITS_MAX = 64      -- pertes gardées entre deux relevés
Prev.KILLS_MAX = 400    -- unités ennemies tuées gardées entre deux relevés (au-delà : comptées sans position, au QG)
Prev.LOG_EVERY = 5 * 3600
Prev.LOGS_MAX = 400     -- lignes de journal par équipe au plus (hors état périodique)

local function get(obj, k)
  local ok, v = pcall(function() return obj[k] end)
  if ok then return v end
  return nil
end

local function sorted_keys(t) return State.sorted_keys(t or {}) end
local function d2(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return dx * dx + dy * dy end
local function minutes(tick) return tick / 3600 end

--- Équipe active ? (coupure de banc : war_option « prevision » = false)
function Prev.enabled()
  local war = State.war()
  local ws = war and war.settings
  return not (ws and ws.prevision == false)
end

---------------------------------------------------------------------------------------------------
-- Caches LOCAUX des prototypes
---------------------------------------------------------------------------------------------------
local kinds_cache = nil
local emit_cache, turret_cache, hp_cache = {}, {}, {}
local POLLUTER_TYPES, TURRET_TYPES, SITE_TYPES = nil, nil, nil

local function types()
  if SITE_TYPES then return end
  POLLUTER_TYPES, TURRET_TYPES, SITE_TYPES = {}, {}, {}
  local tset = {}
  for _, ty in ipairs(R.TURRET_TYPES) do tset[ty] = true end
  for _, ty in ipairs(R.ENTITY_TYPES) do
    local role = R.ENTITY_ROLE[ty]
    if role == "fabrique" or role == "foreuse" or role == "chauffe" then
      POLLUTER_TYPES[ty] = true
      SITE_TYPES[#SITE_TYPES + 1] = ty
    elseif tset[ty] then
      TURRET_TYPES[ty] = true
      SITE_TYPES[#SITE_TYPES + 1] = ty
    end
  end
end

--- Types de nids (Pv.mix) lus aux prototypes `unit-spawner` (type du moteur) : unités, poids par évolution, PV, coût en
--- pollution, vitesse ; cadence au plus (spawn_cooldown).
local function kinds()
  if kinds_cache then return kinds_cache end
  local out = {}
  local ok, list = pcall(function() return game.get_filtered_entity_prototypes({ { filter = "type", type = "unit-spawner" } }) end)
  if ok and list then
    for _, name in ipairs(sorted_keys(list)) do
      local p = list[name]
      local ru = get(p, "result_units") or {}
      local units = {}
      for _, r in ipairs(ru) do
        local up = r.unit and game.entity_prototypes[r.unit]
        if up then
          local pts = {}
          for _, sp in ipairs(r.spawn_points or {}) do
            pts[#pts + 1] = { math.floor((sp.evolution_factor or 0) * 1000 + 0.5), sp.weight or 0 }
          end
          table.sort(pts, function(a, b) return a[1] < b[1] end)
          units[#units + 1] = { hp = get(up, "max_health") or 0, cost = get(up, "pollution_to_join_attack") or 0,
            speed = get(up, "speed") or Pv.SPEED0, pts = pts }
        end
      end
      -- spawn_cooldown { min, max } : `min` est le délai à l'évolution 0 (360), `max` celui à l'évolution 1 (150) (moteur réel,
      -- banc prev-mesure du 30/10 : « min 360 max 150 » pour {360, 150} des données vanilla).
      local cd = get(p, "spawn_cooldown")
      local c0, c1 = cd and cd.min or nil, cd and cd.max or nil
      out[#out + 1] = { units = units, rate_max = (c0 and c0 > 0) and (3600 / c0) or nil,
        rate_max1 = (c1 and c1 > 0) and (3600 / c1) or nil }
    end
  end
  kinds_cache = out
  return out
end

--- Pollution/min d'un PROTOTYPE à pleine marche (borne haute) : emissions_per_second ; à défaut (moteur réel, banc prev-vague
--- du 30/10 : 0 relevé sur des fours), émissions de sa source d'énergie (pollution par joule, combustible ou électrique) × sa
--- consommation maximale (joules par tick). Cache par nom (`name`, sinon celui du prototype). Lu aussi par la capitalisation
--- (défense induite, C12).
function Prev.emit_per_min(p, name)
  local n = name or (p and get(p, "name"))
  if not (p and n) then return 0 end
  local v = emit_cache[n]
  if v == nil then
    v = (get(p, "emissions_per_second") or 0) * 60
    if v <= 0 then
      local bp, ep = get(p, "burner_prototype"), get(p, "electric_energy_source_prototype")
      local per_j = (bp and get(bp, "emissions")) or (ep and get(ep, "emissions")) or 0
      local use = get(p, "max_energy_usage") or get(p, "energy_usage") or 0
      v = per_j * use * 60 * 60
    end
    emit_cache[n] = v
  end
  return v
end

local function emit_of(e) return Prev.emit_per_min(e.prototype, e.name) end

--- Dégâts d'une action de munition (somme des « damage » des effets, répétitions comprises, un niveau d'imbrication).
local function damage_of(action, depth)
  if not action or (depth or 0) > 3 then return 0 end
  local list = action[1] and action or { action }
  local sum = 0
  for _, a in ipairs(list) do
    local rep = a.repeat_count or 1
    local dl = a.action_delivery
    dl = dl and (dl[1] and dl or { dl }) or {}
    for _, d in ipairs(dl) do
      local te = d.target_effects
      te = te and (te[1] and te or { te }) or {}
      for _, ef in ipairs(te) do
        if ef.type == "damage" and ef.damage then sum = sum + (ef.damage.amount or 0) * rep
        elseif ef.type == "nested-result" then sum = sum + damage_of(ef.action, (depth or 0) + 1) * rep end
      end
    end
  end
  return sum
end

--- Tourelle : { dps (par seconde, sans bonus de force), range, cat } lus aux prototypes (munition de l'exécutant pour une
--- tourelle à munitions). Cache par nom.
local function turret_of(name)
  local c = turret_cache[name]
  if c ~= nil then return c or nil end
  c = false
  local p = game.entity_prototypes[name]
  local ap = p and get(p, "attack_parameters")
  if ap and (ap.cooldown or 0) > 0 then
    local dmg, cat = 0, nil
    if ap.ammo_type and ap.ammo_type.action then
      dmg = damage_of(ap.ammo_type.action)
      cat = ap.ammo_type.category
    else
      local ip = game.item_prototypes[T.turret_ammo]
      local ok, at = pcall(function() return ip.get_ammo_type("turret") end)
      if not (ok and at) then ok, at = pcall(function() return ip.get_ammo_type() end) end
      if ok and at then dmg, cat = damage_of(at.action), at.category end
    end
    if dmg > 0 then
      c = { dps = dmg * (ap.damage_modifier or 1) * 60 / ap.cooldown, range = ap.range or 0, cat = cat }
    end
  end
  turret_cache[name] = c
  return c or nil
end

local function hp_of(u)
  local n = u.name
  local v = hp_cache[n]
  if v == nil then
    v = get(u.prototype, "max_health") or 0
    hp_cache[n] = v
  end
  return v
end

--- Bonus de force d'une tourelle (dégâts de la munition, attaque de la tourelle, cadence) ; 1 sans lecture possible.
local function force_mult(force, name, cat)
  if not force then return 1 end
  local m = 1
  if cat then
    local ok, v = pcall(function() return force.get_ammo_damage_modifier(cat) end)
    if ok and v then m = m * (1 + v) end
    local ok3, s = pcall(function() return force.get_gun_speed_modifier(cat) end)
    if ok3 and s then m = m * (1 + s) end
  end
  local ok2, v2 = pcall(function() return force.get_turret_attack_modifier(name) end)
  if ok2 and v2 then m = m * (1 + v2) end
  return m
end

---------------------------------------------------------------------------------------------------
-- État et crochets
---------------------------------------------------------------------------------------------------
local function state(f)
  local st = f.prevision
  if not st then
    st = { cal = {}, pc = Pc.new(), hits = {}, kills = {}, logs = 0 }
    f.prevision = st
  end
  if not st.kills then st.kills = {} end -- état d'une sauvegarde 0.6.24 (créé en événement, au premier usage)
  return st
end

--- Crochet du front : une pièce de l'équipe tuée par un ennemi (script/team/front.lua, on_died). Créé en événement.
Front.on_loss = function(f, pos, tick)
  if not (f and pos) then return end
  local st = state(f)
  if #st.hits < Prev.HITS_MAX then st.hits[#st.hits + 1] = { x = pos.x, y = pos.y } end
end

--- Crochet du front : lignes « tourelles d'avance » (Pc.front_rows) de l'équipe, ou nil.
Front.prevu = function(f)
  local st = f.prevision
  if not (st and st.pc and st.pc.sites) or not Prev.enabled() then return nil end
  local rows = Pc.front_rows(st.pc, sorted_keys(st.pc.sites))
  return #rows > 0 and rows or nil
end

--- Unités ennemies TUÉES par une équipe (lot PREVISION-CALIB : la vague reçue se mesure aussi à ce que nos défenses tuent ; un
--- relevé par minute ne voit presque jamais une vague que les tourelles tuent en quelques secondes). Comme le joueur : une
--- équipe sait ce que ses tourelles et ses soldats ont tué. Rattachées au site le plus proche au relevé suivant.
local function team_of(force_name)
  if force_name == "player" then return State.faction("player") end
  return State.by_force(force_name)
end

Events.on(defines.events.on_entity_died, function(e)
  local ent = e.entity
  if not (ent and ent.valid and ent.type == "unit") then return end
  local killer = e.force
  if not (killer and killer.name ~= ent.force.name and ent.force.name == "enemy") then return end
  if not Prev.enabled() then return end
  local f = team_of(killer.name)
  if not (f and not f.eliminated and f.prevision) then return end
  local st = state(f)
  local hp = get(ent.prototype, "max_health") or 0
  if #st.kills < Prev.KILLS_MAX then
    local p = ent.position
    st.kills[#st.kills + 1] = { x = p.x, y = p.y, hp = hp }
  else
    st.kills_over = (st.kills_over or 0) + hp
  end
end)

---------------------------------------------------------------------------------------------------
-- Relevé
---------------------------------------------------------------------------------------------------
--- Sites de l'équipe : QG, avant-postes (au plus OUTPOSTS_MAX), champs ouverts de la capitalisation (au plus FIELDS_MAX, à
--- plus de FIELD_SEP tuiles d'un site déjà compté). { { key, kind, x, y } } dans cet ordre.
local function sites_of(f)
  local out = { { key = "qg", kind = "qg", x = f.hq_pos.x, y = f.hq_pos.y } }
  local n = 0
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    local p = o and (o.access or o.pos)
    if p and n < Prev.OUTPOSTS_MAX then
      n = n + 1
      out[#out + 1] = { key = "ap" .. tostring(oid), kind = "ap", x = p.x, y = p.y }
    end
  end
  local cs = f.team and f.team.capi
  if cs and cs.deps then
    local open = {}
    for _, dr in ipairs((cs.scan and cs.scan.drills) or {}) do if dr.deposit ~= "?" then open[dr.deposit] = true end end
    local cand = {}
    for _, id in ipairs(sorted_keys(cs.deps)) do
      local d = cs.deps[id]
      if open[id] and d.cx and d.cy then
        cand[#cand + 1] = { id = id, x = d.cx, y = d.cy, dd = d2(d.cx, d.cy, f.hq_pos.x, f.hq_pos.y) }
      end
    end
    table.sort(cand, function(a, b) if a.dd ~= b.dd then return a.dd < b.dd end return tostring(a.id) < tostring(b.id) end)
    local m = 0
    for _, c in ipairs(cand) do
      if m >= Prev.FIELDS_MAX then break end
      local near = false
      for _, s in ipairs(out) do if d2(s.x, s.y, c.x, c.y) < Prev.FIELD_SEP * Prev.FIELD_SEP then near = true break end end
      if not near then
        m = m + 1
        out[#out + 1] = { key = "ch" .. tostring(c.id), kind = "ch", x = c.x, y = c.y }
      end
    end
  end
  return out
end

--- Nids connus (carte de connaissance + carte du danger de l'équipe), dédoublonnés, triés par distance au site le plus proche.
local function nests_of(f, sites, team_map)
  local seen, list = {}, {}
  local function add(x, y)
    local key = math.floor(x) .. "," .. math.floor(y)
    if seen[key] then return end
    local best = nil
    for _, s in ipairs(sites) do
      local dd = d2(x, y, s.x, s.y)
      if not best or dd < best then best = dd end
    end
    if best and best <= Pv.R_ATTR * Pv.R_ATTR then
      seen[key] = true
      list[#list + 1] = { x = x, y = y, dd = best }
    end
  end
  local km = f.ai3f and f.ai3f.m
  if km then
    local far = 0
    for _, s in ipairs(sites) do
      local d = math.sqrt(d2(s.x, s.y, f.hq_pos.x, f.hq_pos.y))
      if d > far then far = d end
    end
    for _, p in ipairs(K.enemy_points(km, f.hq_pos.x, f.hq_pos.y, math.min(800, far + Pv.R_ATTR))) do
      if p.kind == "spawner" then add(p.x, p.y) end
    end
  end
  for _, th in ipairs((team_map and team_map.threats) or {}) do
    if th.k == "spawner" then add(th.x, th.y) end
  end
  table.sort(list, function(a, b)
    if a.dd ~= b.dd then return a.dd < b.dd end
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)
  while #list > Pv.NESTS_MAX do list[#list] = nil end
  return list
end

local function map_settings()
  local ms = get(game, "map_settings")
  local ug = ms and ms.unit_group
  local ee = ms and ms.enemy_evolution
  local po = ms and ms.pollution
  local gather = {
    min = ((ug and ug.min_group_gathering_time) or 3600) / 3600,
    max = ((ug and ug.max_group_gathering_time) or 36000) / 3600,
    size = (ug and ug.max_unit_group_size) or 200,
  }
  local evo_on = not (ee and ee.enabled == false)
  local tf = evo_on and ((ee and ee.time_factor) or 0) or 0
  local pf = evo_on and ((ee and ee.pollution_factor) or 0) or 0
  local poll_on = not (po and po.enabled == false)
  local diff = math.floor(((po and po.diffusion_ratio) or (Pv.DIFF0 / 1000)) * 1000 + 0.5)
  local sat = (po and po.min_to_diffuse) or Pv.SAT0
  return gather, tf, pf, poll_on, diff, sat
end

--- Coûts au livre de recettes (de la pensée du cerveau, quand elle le donne) : fer d'une recrue et d'une tourelle garnie.
local function costs(st, f, opts)
  if not (opts and opts.book) then return end
  local book = opts.book
  local key = opts.key_item or st.key_item
  if not key then return end
  st.key_item = key
  local kit = T.kits[Planner.best_unit(f.tech or 0)]
  if kit then
    local ok, raw = pcall(function() return book:raw_cost(kit) end)
    if ok and raw then st.kit_iron = raw[key] or 0 end
  end
  local ok2, raw2 = pcall(function() return book:raw_cost({ { T.turret, 1 }, { T.turret_ammo, T.defend_ammo } }) end)
  if ok2 and raw2 then st.turret_iron = raw2[key] or 0 end
  st.reserve = math.max(T.defend_iron_floor or 0, opts.iron_floor or 0)
end

--- Le relevé et la décision (au plus une fois par Pv.PERIOD ticks). opts = { book, key_item, iron_floor, production_first,
--- recruit_ok } (pensée du cerveau) ou nil (passage des soldats). Rend l'état f.prevision (ou nil : coupure, pas de QG).
function Prev.think(f, tick, opts)
  if not (f and f.hq and f.hq.valid and f.hq_pos) or f.eliminated or not Prev.enabled() then return nil end
  local st = state(f)
  costs(st, f, opts)
  if opts and opts.production_first ~= nil then st.production_first = opts.production_first end
  if opts and opts.recruit_ok ~= nil then st.recruit_ok = opts.recruit_ok end
  if st.t and tick - st.t < Pv.PERIOD then return st end
  st.t = tick
  types()
  local surface = f.hq.surface
  local force = game.forces[f.force]
  local enemy = game.forces["enemy"]
  local gather, tf, pf, poll_on, diff, sat = map_settings()
  local team_map = C.team(f).map
  -- 1. Sites : bâtiments (émission, tourelles).
  local sites = sites_of(f)
  local best_turret = nil
  for _, s in ipairs(sites) do
    s.emit, s.dps, s.dpsr, s.turrets, s.seen, s.contact, s.vx, s.vy = 0, 0, 0, 0, 0, 0, 0, 0
    local r = Prev.SITE_R[s.kind]
    for _, e in ipairs(surface.find_entities_filtered({ position = { x = s.x, y = s.y }, radius = r, force = f.force, type = SITE_TYPES })) do
      if e.valid then
        if POLLUTER_TYPES[e.type] then
          s.emit = s.emit + emit_of(e)
        elseif TURRET_TYPES[e.type] then
          s.turrets = s.turrets + 1
          local tp = turret_of(e.name)
          if tp then
            local dps = tp.dps * force_mult(force, e.name, tp.cat)
            s.dps, s.dpsr = s.dps + dps, s.dpsr + dps * tp.range
          end
        end
      end
    end
  end
  -- Tourelle de l'exécutant (celle que l'équipe pose) : valeur d'une tourelle de plus.
  local tp = turret_of(T.turret)
  if tp then best_turret = { dps = tp.dps * force_mult(force, T.turret, tp.cat), range = tp.range } end
  -- 2. Nids CONNUS de l'équipe (carte de connaissance et carte du danger ; jamais un nid jamais vu).
  local known = nests_of(f, sites, team_map)
  -- 2 bis. Unités ennemies VUES à portée d'œil d'un site (biters seulement), chacune au site le plus proche.
  local units = {}
  local seen_ids = {}
  for _, s in ipairs(sites) do
    for _, u in ipairs(surface.find_enemy_units({ x = s.x, y = s.y }, Prev.EYE[s.kind], f.force)) do
      if u.valid and u.force and u.force.name == "enemy" then
        local id = u.unit_number or 0
        if not seen_ids[id] then
          seen_ids[id] = true
          local p = u.position
          units[#units + 1] = { id = id, x = p.x, y = p.y, hp = hp_of(u) }
        end
      end
    end
  end
  table.sort(units, function(a, b) return a.id < b.id end)
  -- Garnison : une unité à moins de Prev.GARRISON_R tuiles d'un nid CONNU défend le nid (elle compte pour un raid, Prev.seen_weight) ;
  -- elle n'est pas une vague (moteur réel, banc prev-vague du 30/10 : les unités nées avec 6 nids vus à 110 tuiles du QG
  -- faisaient une « vague vue » de 21 420 PV). La vague qui se forme à partir de la pollution est celle du modèle.
  for _, u in ipairs(units) do
    for _, n in ipairs(known) do
      if d2(u.x, u.y, n.x, n.y) <= Prev.GARRISON_R * Prev.GARRISON_R then u.garrison = true break end
    end
  end
  for _, u in ipairs(units) do
    local best, bd = nil, nil
    if not u.garrison then
      for _, s in ipairs(sites) do
        local dd = d2(u.x, u.y, s.x, s.y)
        if dd <= Prev.EYE[s.kind] ^ 2 and (not bd or dd < bd) then best, bd = s, dd end
      end
    end
    if best then
      best.seen = best.seen + u.hp
      best.vx, best.vy = best.vx + u.hp * u.x, best.vy + u.hp * u.y
      if bd <= Prev.CONTACT_R * Prev.CONTACT_R then best.contact = best.contact + u.hp end
    end
  end
  st.units = units -- lu par l'armée (défenseurs VUS d'un champ) jusqu'au relevé suivant
  -- 3. Pollution qui atteint les nids connus.
  local nests = {}
  if poll_on then
    for _, n in ipairs(known) do
      local c = math.floor(surface.get_pollution({ x = n.x, y = n.y }) or 0)
      local nb = 0
      if c < sat then
        -- Seules les voisines au-dessus du seuil de diffusion envoient de la pollution (doc 1.1.91, min_to_diffuse).
        for _, dxy in ipairs({ { 32, 0 }, { -32, 0 }, { 0, 32 }, { 0, -32 } }) do
          local v = math.floor(surface.get_pollution({ x = n.x + dxy[1], y = n.y + dxy[2] }) or 0)
          if v >= sat then nb = nb + v end
        end
      end
      nests[#nests + 1] = { x = n.x, y = n.y, c = c, nb = nb }
    end
  end
  -- 4. QG rivaux connus (les QG sont connus de tous, comme le point de départ du joueur).
  local rivals = {}
  local war = State.war()
  for _, id in ipairs(sorted_keys(war and war.factions)) do
    local g = war.factions[id]
    if g ~= f and not g.eliminated and g.hq_pos then rivals[#rivals + 1] = { x = g.hq_pos.x, y = g.hq_pos.y } end
  end
  local pl = State.faction("player")
  if pl and pl ~= f and pl.hq_pos then rivals[#rivals + 1] = { x = pl.hq_pos.x, y = pl.hq_pos.y } end
  -- 5. Estimation.
  local emit = 0
  for _, s in ipairs(sites) do emit = emit + s.emit end
  local kfac, floors = {}, {}
  local kteam = Pv.k_of(st.cal)
  for _, s in ipairs(sites) do
    kfac[s.key] = kteam
    floors[s.key] = st.cal[s.key] and st.cal[s.key].floor or nil
  end
  local evo = enemy and math.floor((get(enemy, "evolution_factor") or 0) * 1000 + 0.5) or 0
  local est = Pv.estimate({ evo = evo, g = tf * 60 + pf * emit, kinds = kinds(), gather = gather, diff = diff, sat = sat, sites = sites,
    nests = nests, rivals = rivals, k = kfac, floor = floors })
  -- 6. Calibration (faits : contact, pertes, fenêtre du moteur).
  local losses = {}
  for _, h in ipairs(st.hits) do
    local best, bd = nil, nil
    for _, s in ipairs(sites) do
      local dd = d2(h.x, h.y, s.x, s.y)
      if dd <= Prev.LOSS_R * Prev.LOSS_R and (not bd or dd < bd) then best, bd = s, dd end
    end
    if best then losses[best.key] = (losses[best.key] or 0) + 1 end
  end
  st.hits = {}
  -- Unités tuées : la garnison d'un nid connu (de ce relevé ou du précédent : un nid détruit pendant la minute en fait partie)
  -- n'est pas une vague reçue (relecture PREVISION-CALIB : un raid ou le nettoyage d'un champ près d'un site faisait un RATÉ,
  -- donc un plancher et un cadre « préparer », pour des unités qui défendaient leur nid).
  local guard = {}
  for _, n in ipairs(known) do guard[#guard + 1] = { x = n.x, y = n.y } end
  for _, n in ipairs(st.nests_prev or {}) do guard[#guard + 1] = n end
  local killed = Pv.kills_by_site(st.kills, sites, guard, Prev.LOSS_R, Prev.GARRISON_R)
  if (st.kills_over or 0) > 0 then killed.qg = (killed.qg or 0) + st.kills_over end
  st.kills, st.kills_over = {}, nil
  local nprev = {}
  for _, n in ipairs(known) do nprev[#nprev + 1] = { x = n.x, y = n.y } end
  st.nests_prev = nprev -- nombres seulement (état d'une sauvegarde 0.6.24 : absent, créé ici)
  local facts, keys = {}, {}
  local hbar = est.mix and est.mix.hbar or 0
  for _, o in ipairs(est.sites) do
    keys[#keys + 1] = o.key
    local travel = (o.eta and o.eta - gather.min) or 0
    facts[o.key] = { pred_raw = o.wraw5 or 0, contact = o.contact, killed = killed[o.key] or 0, losses = losses[o.key] or 0, hbar = hbar,
      window = gather.max * 2 + travel, source = o.rate > 0 or o.wvu > 0 }
  end
  table.sort(keys)
  local cal_evs = Pv.calibrate(st.cal, keys, facts, tick)
  if #cal_evs > 0 then
    -- Derniers faits de calibration (lus par les bancs : status) ; copie de nombres et de chaînes.
    st.cal_last = {}
    for _, e in ipairs(cal_evs) do
      st.cal_last[#st.cal_last + 1] = { key = e.key, kind = e.kind, pred = e.pred, recv = e.recv, seen = e.seen, killed = e.killed,
        lost = e.lost, k0 = e.k0, k1 = e.k1, censored = e.censored, tick = tick }
    end
  end
  -- 7. Décisions.
  local soldiers = f.soldiers_count or 0
  local smax = (not f.is_player) and ((war and war.settings and war.settings.soldiers_max) or 0) or 0
  local sdps = 0
  if smax > 0 then
    local key = Planner.best_unit(f.tech or 0)
    local sp = FC.soldiers[key]
    sdps = sp.damage * 60 / sp.cooldown * FS.soldier_strength(key, f.tech or 0, f.upgrades or 0)
      / FS.soldier_strength(key, 0, 0)
  end
  local sv = Pv.soldier_value(sdps)
  local tv = best_turret and Pv.turrets_value(best_turret.dps, best_turret.dps * best_turret.range, est.mix and est.mix.speed) or 0
  local front = {}
  local fm = f.front_mem
  for _, r in ipairs((fm and fm.rows) or {}) do
    if type(r.key) == "string" and r.key:sub(1, 5) == "prev:" then front[r.key:sub(6)] = r.skip or "servie" end
  end
  local iron = st.key_item and Stock.count(f, st.key_item) or 0
  -- Équipements complets du meilleur soldat déjà au coffre (payés : hors du budget de fer).
  local kits_stock = 0
  if smax > 0 then
    local kit = T.kits[Planner.best_unit(f.tech or 0)]
    if kit then
      kits_stock = math.huge
      for _, it in ipairs(kit) do kits_stock = math.min(kits_stock, math.floor(Stock.count(f, it[1]) / it[2])) end
    end
  end
  Pc.update(st.pc, est, { soldiers = soldiers, soldiers_max = smax, soldier_value = sv, mobile = soldiers * sv,
    turret_value = tv, turret_stock = Stock.count(f, T.turret), iron = iron, reserve = st.reserve or T.defend_iron_floor,
    kit_iron = st.kit_iron, kits_stock = kits_stock, turret_iron = st.turret_iron, production_first = st.production_first, recruit_ok = st.recruit_ok,
    front = front }, tick)
  st.turret_value, st.soldier_value = tv, sv
  st.hp_per_emit = Pv.hp_per_emit(est, gather)
  st.est = { evo = evo, evo15 = est.evo15, emit = emit, absorbed = est.absorbed, reach = est.reach, nests = est.nests_used,
    known = #known, hbar = hbar, poll_c = 0, poll_nb = 0, pbar = est.mix and est.mix.pbar or 0, rate = est.rate, units = #units, gather = gather }
  st.est.sat, st.est.nsat = sat, 0
  for _, n in ipairs(nests) do
    st.est.poll_c, st.est.poll_nb = st.est.poll_c + n.c, st.est.poll_nb + n.nb
    if n.c >= sat then st.est.nsat = st.est.nsat + 1 end
  end
  st.est.k = Pv.k_of(st.cal)
  st.view = Prev.slim(est) -- estimation du relevé (lue par l'armée : porte du raid, champs chauds) ; copie sans références partagées
  Prev.journal(f, st, est, cal_evs, tick)
  return st
end

---------------------------------------------------------------------------------------------------
-- Lecteurs
---------------------------------------------------------------------------------------------------
--- Copie de l'estimation gardée dans l'état (global) : sites et contributions des nids, unité moyenne ; aucune table partagée.
function Prev.slim(est)
  local out = { sites = {}, mix = est.mix and { pbar = est.mix.pbar, hbar = est.mix.hbar, speed = est.mix.speed } or nil }
  for _, o in ipairs(est.sites) do
    local ns = {}
    for _, n in ipairs(o.nests) do ns[#ns + 1] = { i = n.i, u = n.u, x = n.x, y = n.y, dist = n.dist } end
    out.sites[#out.sites + 1] = { key = o.key, x = o.x, y = o.y, rate = o.rate, w5 = o.w5, w15 = o.w15, eta = o.eta, d = o.d,
      tx = o.tx, ty = o.ty, nests = ns }
  end
  return out
end

--- Lignes de la pile (cadre « preparer ») de l'équipe, ou nil.
function Prev.pile_rows(f)
  local st = f.prevision
  if not (st and st.pc and Prev.enabled()) then return nil end
  local rows = Pc.pile_rows(st.pc, sorted_keys(st.pc.sites))
  return #rows > 0 and rows or nil
end

--- Défense induite pour la capitalisation : { hp_per_emit, turret_value } ou nil.
function Prev.capi_defense(f)
  local st = f.prevision
  if not (st and Prev.enabled() and (st.hp_per_emit or 0) > 0 and (st.turret_value or 0) > 0) then return nil end
  return { hp_per_emit = st.hp_per_emit, turret_value = st.turret_value, marge = Pc.MARGE }
end

--- Poids (moyen déchiqueteur = 1, comme le regard des PNJ) des défenseurs VUS à moins de r tuiles de (x, y).
function Prev.seen_weight(f, x, y, r)
  local st = f.prevision
  local w = 0
  for _, u in ipairs((st and st.units) or {}) do
    if d2(u.x, u.y, x, y) <= r * r then w = w + u.hp / 75 end
  end
  return w
end

---------------------------------------------------------------------------------------------------
-- Journal [FO-PREVISION]
---------------------------------------------------------------------------------------------------
local function n0(x) return math.floor((x or 0) + 0.5) end

local function site_text(s, o)
  return string.format("%s : vague %d PV a 5 min / %d a 15 min (vus %d), defense %d PV (%d tourelle(s)), rapport %.2f, echeance %s",
    o.key, n0(o.w5), n0(o.w15), n0(o.wvu), n0(s and s.dtot or o.d), o.turrets or 0, (s and s.rho or 0) / 1000,
    o.eta and string.format("%.1f min", o.eta) or "aucune")
end

function Prev.journal(f, st, est, cal_evs, tick)
  local who = tostring(f.key or "player")
  local pc = st.pc
  local function line(s)
    if st.logs < Prev.LOGS_MAX then
      st.logs = st.logs + 1
      log("[FO-PREVISION] " .. who .. " " .. string.format("%.1f min", minutes(tick)) .. " " .. s)
    end
  end
  -- Faits de calibration (un par cause).
  for _, e in ipairs(cal_evs) do
    if e.kind == "vague" then
      line(string.format("BILAN vague %s : prevue %d PV, recue %d PV (vue %d, tuee %d, pertes %d%s) (k equipe %.2f -> %.2f)", e.key,
        n0(e.pred), n0(e.recv), n0(e.seen), n0(e.killed), n0(e.lost), e.censored and " ; borne basse, k ne peut que monter" or "",
        e.k0 / 1000, e.k1 / 1000))
    elseif e.kind == "rate" then
      line(string.format("RATE %s : attaque de %d PV sans vague prevue (vue %d, tuee %d, pertes %d) (k equipe %.2f inchange, plancher de menace %d PV)",
        e.key, n0(e.recv), n0(e.seen), n0(e.killed), n0(e.lost), e.k0 / 1000, n0(e.recv)))
    else
      line(string.format("FAUSSE ALERTE %s : vague prevue de %d PV non venue dans la fenetre du moteur (k equipe %.2f -> %.2f)", e.key,
        n0(e.pred), e.k0 / 1000, e.k1 / 1000))
    end
  end
  -- Décisions (une ligne par changement).
  for _, e in ipairs(pc.events or {}) do
    if e.kind == "ouvert" then
      line(string.format("DECIDE : PREPARER %s ouvert (vague %d PV dans %.1f min contre defense %d PV : %.2fx >= %.2fx) ; tourelles %d -> %d",
        e.key, n0(e.w5), e.eta or 0, n0(e.d), e.rho / 1000, Pc.RHO_IN / 1000, e.have, e.want))
    elseif e.kind == "ferme" then
      line(string.format("DECIDE : PREPARER %s ferme (vague %d PV, defense %d PV : cible %.2fx atteinte ou vague retombee)",
        e.key, n0(e.w5), n0(e.d), Pc.MARGE / 1000))
    elseif e.kind == "insurmontable" then
      line(string.format("DECIDE : %s INSURMONTABLE (vague %d PV contre %d PV reunissables au mieux) : aucun gel, repli au QG",
        e.key, n0(e.w5), n0(e.dmax)))
    elseif e.kind == "tenable" then
      line(string.format("DECIDE : %s de nouveau tenable (vague %d PV, %d PV reunissables)", e.key, n0(e.w5), n0(e.dmax)))
    elseif e.kind == "armee" then
      line(string.format("DECIDE : armee %s, besoin %d -> %d soldat(s)%s (budget : fer au-dessus de la reserve %d, recrue %s de fer)",
        e.alert and "en alerte" or "sans alerte", e.was, e.need, e.key and (" contre la vague de " .. e.key) or "",
        n0(st.reserve), tostring(st.kit_iron and n0(st.kit_iron) or "?")))
    elseif e.kind == "premiere" then
      line(string.format("DECIDE : premiere vague %s (avant : %s) : reserve mobile et regroupement de ce cote", tostring(e.key),
        tostring(e.was)))
    end
  end
  -- État périodique.
  if tick - (st.log_t or -Prev.LOG_EVERY) >= Prev.LOG_EVERY then
    st.log_t = tick
    local parts = {}
    for _, o in ipairs(est.sites) do
      if o.w15 > 0 or o.turrets > 0 or o.key == "qg" then parts[#parts + 1] = site_text(pc.sites[o.key], o) end
    end
    local e = st.est
    log(string.format("[FO-PREVISION] %s %.1f min ETAT evo %.3f (%.3f a 15 min) | %d nid(s) connu(s), %d nous visent (pollution recue %d/min sur %d/min emise, part %d pour mille ; cases des nids %d, %d au-dessus du seuil %d, voisines au-dessus %d ; k equipe %.2f) | unite moyenne %d PV, %d de pollution | %d unite(s) vue(s) | %s | armee : alerte %s, besoin %d, a 15 min %d | defense induite %.2f PV par pollution/min",
      who, minutes(tick), e.evo / 1000, e.evo15 / 1000, e.known, e.nests, n0(e.absorbed), n0(e.emit), e.reach, n0(e.poll_c), e.nsat or 0,
      n0(e.sat), n0(e.poll_nb), (e.k or Pv.K0) / 1000, n0(e.hbar), n0(e.pbar),
      e.units, #parts > 0 and table.concat(parts, " ; ") or "aucun site", tostring(pc.alert), pc.army_need or 0, pc.army_soon or 0,
      st.hp_per_emit or 0))
  end
end

---------------------------------------------------------------------------------------------------
-- Interface des bancs (lecture, et un nid « vu » posé par le banc comme un regard l'aurait fait)
---------------------------------------------------------------------------------------------------
local function team_by_key(key)
  if key == "player" then return State.faction("player") end
  local war = State.war()
  for _, id in ipairs(sorted_keys(war and war.factions)) do
    local f = war.factions[id]
    if f.key == key then return f end
  end
  return nil
end

local function status(f)
  local st = f and f.prevision
  if not st then return nil end
  local out = { alert = st.pc.alert, need = st.pc.army_need, soon = st.pc.army_soon, first = st.pc.first, sites = {}, k = {},
    est = st.est, turret_value = st.turret_value, soldier_value = st.soldier_value, hp_per_emit = st.hp_per_emit }
  for _, k in ipairs(sorted_keys(st.pc.sites)) do
    local s = st.pc.sites[k]
    out.sites[k] = { prep = s.prep, insurm = s.insurm, w5 = s.w5, w15 = s.w15, d = s.d, dtot = s.dtot, rho = s.rho, eta = s.eta,
      have = s.have, want = s.want, exec = s.exec, nohold = s.nohold, why = s.why }
  end
  local kteam = Pv.k_of(st.cal)
  for _, k in ipairs(sorted_keys(st.pc.sites)) do out.k[k] = kteam end
  out.kteam = kteam
  out.cal_last = st.cal_last
  local rows = Prev.pile_rows(f)
  out.pile_rows = rows and #rows or 0
  local fr = Front.prevu(f)
  out.front_rows = fr and #fr or 0
  return out
end

remote.add_interface("fo-prevision", {
  --- Équipes vivantes : { { key, x, y } } (QG).
  teams = function()
    local out = {}
    local war = State.war()
    for _, id in ipairs(sorted_keys(war and war.factions)) do
      local f = war.factions[id]
      if not f.eliminated and f.hq_pos then out[#out + 1] = { key = f.key, x = f.hq_pos.x, y = f.hq_pos.y } end
    end
    return out
  end,
  --- Banc : un nid VU par l'équipe (entre dans sa carte du danger, comme le regard d'un PNJ en marche).
  know_nest = function(key, x, y)
    local f = team_by_key(key)
    if not f then return false end
    D.mark_seen(C.team(f).map, x, y, "spawner", nil, game.tick)
    return true
  end,
  --- Relevé immédiat (le suivant attendrait sa minute) ; rend l'état.
  relook = function(key)
    local f = team_by_key(key)
    if not f then return nil end
    if f.prevision then f.prevision.t = nil end
    Prev.think(f, game.tick)
    return status(f)
  end,
  status = function(key) return status(team_by_key(key)) end,
})

return Prev
