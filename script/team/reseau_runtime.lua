--[[
  RÉSEAU ÉLECTRIQUE (lot RESEAU) : branche la règle pure shared/team/reseau.lua sur les équipes réelles. Constat du DC :
  une seule centrale pour toute la base, des convoyeurs pleins faute de courant, des zones sans poteau jamais vues, un
  poteau détruit jamais remplacé (« problème de connexité, théorie des graphes »).

  Un RELEVÉ par équipe (toutes celles qui ont un plan directeur, factions et votre équipe), toutes les Rt.PERIOD ticks,
  étalé sur plusieurs ticks et payé en jetons de travail (Tokens, budget partagé du mod : K10) :
    poteaux (surface entière, portée de fil et aire d'alimentation lues aux PROTOTYPES) → producteurs (types de prototypes
    à production et sans consommation, priorité d'usage « primaire en sortie » ou « solaire ») → consommateurs (types de
    prototypes à consommation électrique, par morceaux de 32 × 32 autour du QG, des avant-postes et des poteaux) →
    analyse pure par tranches (R.job_step) → application → poteaux pivots (R.pivot_step, tranches).
  Aucun nom d'objet : les types viennent d'un parcours des prototypes (une fois par chargement), les puissances et portées
  des prototypes, l'état « affamé » du statut du moteur (manque de courant).

  APPLICATION (comportement par défaut, rien à allumer) :
    1. PUBLICATION (f.reseau.report, interface « fo-reseau », Rt.report) : composantes, bâtiments hors de toute aire
       regroupés en ZONES non couvertes, îlots sans producteur, affamés, charge de la production, poteaux pivots, et deux
       contrôles contre le moteur (les composantes du modèle = les réseaux du moteur ; « hors de portée » du modèle =
       « sans réseau » du moteur) : c'est la preuve que le modèle voit ce que voit le jeu ;
    2. REMISE EN ÉTAT : un poteau de nos projets MORT (on_entity_died) n'est relevé que si cela rallume un bâtiment
       (R.repair : plus court chemin, élagage) ; le plan devient un petit projet du plan directeur (fantômes, PNJ, objets
       du coffre : la machinerie de Build, sans toucher à ses fonctions), 3 essais par poteau ;
    3. CAPACITÉ : la charge de la production (lissée sur 3 relevés) plus la puissance des modules électriques demandés
       mais pas bâtis ; à 80 % (R.ALERT) deux relevés de suite, une centrale de plus est demandée AVANT la saturation, dans
       le rapport des prototypes (unités = boucle de la centrale existante, une à la fois, 3 min d'attente entre deux) ;
       les bras de cette centrale passent à l'électrique par shared/team/bras.lua / script/team/plant_arms.lua (lot
       PLANDIR), appelés tels quels.
  NON fait (déclaré) : poser de NOUVEAUX poteaux pour couvrir une zone (elle est seulement publiée) ; remplacer un poteau
  dont l'emplacement est pris par un autre (3 essais puis abandon) ; production solaire observée (seules les machines
  génératrices ont un relevé de production).
  État : f.reseau (nombres et listes triées seulement). Les entités du relevé vivent en variables locales du fichier : un
  chargement de sauvegarde reprend un relevé neuf.
]]

local Events = require("script.core.events")
local Profiler = require("script.core.profiler")
local State = require("script.faction.state")
local Stock = require("script.team.stock")
local Tokens = require("script.team.tokens")
local Build = require("script.team.build")
local PlantArms = require("script.team.plant_arms")
local M = require("shared.team.modules")
local R = require("shared.team.reseau")

local Rt = {}

Rt.PERIOD = 1800            -- ticks entre la fin d'un relevé et le début du suivant (30 s)
Rt.STEP = 20                -- période du moteur
Rt.POLES_PER_SLICE = 120    -- poteaux lus par tranche
Rt.CHUNKS_PER_SLICE = 2     -- morceaux de 32 × 32 lus par tranche
Rt.PROTOS_PER_SLICE = 600   -- prototypes classés par tranche (une fois)
Rt.WORK = 400               -- unités de travail de l'analyse pure par tranche
Rt.TOKENS = 12              -- jetons demandés par tranche
Rt.TOKENS_PLAN = 200        -- jetons du plan de réparation (une grosse opération par tick pour tout le mod)
Rt.HQ_CHUNKS = 3            -- rayon (morceaux) relevé autour du QG
Rt.SITE_CHUNKS = 1          -- rayon (morceaux) autour d'un avant-poste ou d'un poteau
Rt.CHUNKS_MAX = 400
Rt.ZONE_GAP = 4             -- écart (tuiles) qui sépare deux zones non couvertes
Rt.ZONES_KEPT = 12
Rt.PIVOTS_KEPT = 5
Rt.HIST = 3                 -- relevés sur lesquels la charge est lissée
Rt.CONFIRM = 2              -- relevés d'alerte de suite avant d'agrandir
Rt.PLANT_COOLDOWN = 10800   -- ticks (3 min) après la fin d'une centrale de plus avant d'en juger une autre
Rt.REPAIR_DELAY = 600       -- ticks entre la mort d'un poteau et l'ordre de le relever
Rt.REPAIR_TRIES = 3
Rt.DIED_TTL = 30 * 3600     -- un poteau mort est oublié après 30 min
Rt.DIED_KEPT = 200
Rt.LOG_EVERY = 5 * 3600     -- une ligne de journal par équipe et par 5 min (plus à chaque changement d'état)
Rt.KW = 0.06                -- J/tick -> kW

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) == "number"
  end)
  return ks
end

---------------------------------------------------------------------------------------------------
-- Prototypes (variables locales : recalculées après un chargement, jamais dans global)
---------------------------------------------------------------------------------------------------
local PROTO_POLE, PROTO_POWER = {}, {} -- nom -> { wire, supply } ; nom -> { use, prod } (kW)
local KINDS = nil           -- { prod = { types }, cons = { types }, done }
local kinds_work = nil      -- { names, i, prod = {}, cons = {} }

local PRODUCER_PRIORITY = { ["primary-output"] = true, ["solar"] = true }

--- Classe les prototypes par tranches : types qui produisent (source électrique en sortie, sans consommation) et types qui
--- consomment. Rend vrai quand c'est fini.
local function classify_step()
  if KINDS then return true end
  if not kinds_work then
    local names = {}
    for name in pairs(game.entity_prototypes) do names[#names + 1] = name end
    table.sort(names)
    kinds_work = { names = names, i = 1, prod = {}, cons = {} }
  end
  local w = kinds_work
  local last = math.min(w.i + Rt.PROTOS_PER_SLICE - 1, #w.names)
  for i = w.i, last do
    local ep = game.entity_prototypes[w.names[i]]
    local src = ep and ep.electric_energy_source_prototype
    if src then
      local use, prod = ep.max_energy_usage or 0, ep.max_energy_production or 0
      if use > 0 then
        w.cons[ep.type] = true
      elseif prod > 0 and PRODUCER_PRIORITY[src.usage_priority] then
        w.prod[ep.type] = true
      end
    end
  end
  w.i = last + 1
  if w.i > #w.names then
    KINDS = { prod = sorted_keys(w.prod), cons = sorted_keys(w.cons) }
    kinds_work = nil
    return true
  end
  return false
end

local function pole_proto(name)
  local d = PROTO_POLE[name]
  if not d then
    local ep = game.entity_prototypes[name]
    d = { wire = ep.max_wire_distance or 0, supply = ep.supply_area_distance or 0 }
    PROTO_POLE[name] = d
  end
  return d
end

local function power_proto(name)
  local d = PROTO_POWER[name]
  if not d then
    local ep = game.entity_prototypes[name]
    d = { use = (ep.max_energy_usage or 0) * Rt.KW, prod = (ep.max_energy_production or 0) * Rt.KW }
    PROTO_POWER[name] = d
  end
  return d
end

---------------------------------------------------------------------------------------------------
-- État
---------------------------------------------------------------------------------------------------
local SURVEY = {}           -- clé d'équipe -> relevé en cours (entités locales : pas dans global)

local function key_of(f) return f.is_player and "player" or tostring(f.key or f.id) end

local function state_of(f)
  if not f.reseau then
    f.reseau = { next = 0, died = {}, repairs = {}, plants = {}, hist = {}, alerts = 0, ext_after = 0, stats = {
      surveys = 0, repairs_made = 0, repairs_abandoned = 0, plants_asked = 0, poles_lost = 0 } }
  end
  return f.reseau
end

local function team_list()
  local out = {}
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and f.build and f.hq and f.hq.valid then out[#out + 1] = f end
  end
  local pf = State.faction("player")
  if pf and pf.build and pf.hq and pf.hq.valid then out[#out + 1] = pf end
  return out
end

local function surface_of(f) return f.hq.surface end

local function pkey(x, y) return math.floor(x * 2 + 0.5) .. ":" .. math.floor(y * 2 + 0.5) end

---------------------------------------------------------------------------------------------------
-- Relevé
---------------------------------------------------------------------------------------------------
local function chunk_list(f, poles)
  local seen, list = {}, {}
  local function add(cx, cy)
    local k = cx .. ":" .. cy
    if not seen[k] then seen[k] = true; list[#list + 1] = { cx, cy } end
  end
  local hx, hy = math.floor(f.hq.position.x / 32), math.floor(f.hq.position.y / 32)
  for dx = -Rt.HQ_CHUNKS, Rt.HQ_CHUNKS do
    for dy = -Rt.HQ_CHUNKS, Rt.HQ_CHUNKS do add(hx + dx, hy + dy) end
  end
  for _, id in ipairs(sorted_keys(f.outposts or {})) do
    local o = f.outposts[id]
    local pos = type(o) == "table" and o.pos
    if type(pos) == "table" and pos.x and pos.y then
      local cx, cy = math.floor(pos.x / 32), math.floor(pos.y / 32)
      for dx = -Rt.SITE_CHUNKS, Rt.SITE_CHUNKS do
        for dy = -Rt.SITE_CHUNKS, Rt.SITE_CHUNKS do add(cx + dx, cy + dy) end
      end
    end
  end
  for _, p in ipairs(poles) do
    local cx, cy = math.floor(p.x / 32), math.floor(p.y / 32)
    for dx = -Rt.SITE_CHUNKS, Rt.SITE_CHUNKS do
      for dy = -Rt.SITE_CHUNKS, Rt.SITE_CHUNKS do add(cx + dx, cy + dy) end
    end
  end
  table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] < b[2] end return a[1] < b[1] end)
  while #list > Rt.CHUNKS_MAX do list[#list] = nil end
  return list
end

local function consumer_record(e)
  local d = power_proto(e.name)
  if d.use <= 0 then return nil end
  local bb = e.bounding_box
  local st = e.status
  local starved = st == defines.entity_status.low_power or st == defines.entity_status.no_power
  return { id = e.unit_number, name = e.name, x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y,
    kw = d.use, starved = starved, net = e.electric_network_id }
end

local function producer_record(e)
  local d = power_proto(e.name)
  if d.prod <= 0 then return nil end
  local bb = e.bounding_box
  local out
  if e.type == "generator" then out = e.energy_generated_last_tick * Rt.KW end
  return { id = e.unit_number, name = e.name, x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y,
    kw = d.prod, out_kw = out }
end

--- Un pas du relevé de l'équipe. Rend vrai quand le relevé est fini (résultats dans S.A).
local function survey_step(f, S, tick)
  local surface = surface_of(f)
  if S.stage == "poles" then
    if not S.list then
      S.list = surface.find_entities_filtered({ type = "electric-pole", force = f.force })
      S.i, S.poles = 1, {}
    end
    local last = math.min(S.i + Rt.POLES_PER_SLICE - 1, #S.list)
    for i = S.i, last do
      local e = S.list[i]
      if e.valid then
        local d = pole_proto(e.name)
        S.poles[#S.poles + 1] = { id = e.unit_number, name = e.name, x = e.position.x, y = e.position.y, wire = d.wire,
          supply = d.supply, net = e.electric_network_id }
      end
    end
    S.i = last + 1
    if S.i > #S.list then
      -- ordre fixe : par position (les indices du modèle ne dépendent pas de l'ordre du moteur)
      table.sort(S.poles, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
      S.list, S.stage = nil, "prods"
    end
  elseif S.stage == "prods" then
    S.prods = {}
    if #KINDS.prod > 0 then
      local list = surface.find_entities_filtered({ type = KINDS.prod, force = f.force })
      for _, e in ipairs(list) do
        local r = e.valid and producer_record(e)
        if r then S.prods[#S.prods + 1] = r end
      end
      table.sort(S.prods, function(a, b) return a.id < b.id end)
    end
    S.stage = "chunks"
  elseif S.stage == "chunks" then
    if not S.chunks then
      S.chunks, S.ci, S.cons, S.seen = chunk_list(f, S.poles), 1, {}, {}
    end
    local last = math.min(S.ci + Rt.CHUNKS_PER_SLICE - 1, #S.chunks)
    for i = S.ci, last do
      local c = S.chunks[i]
      local list = surface.find_entities_filtered({ area = { { c[1] * 32, c[2] * 32 }, { c[1] * 32 + 32, c[2] * 32 + 32 } },
        type = KINDS.cons, force = f.force })
      for _, e in ipairs(list) do
        if e.valid and not S.seen[e.unit_number] then
          S.seen[e.unit_number] = true
          local r = consumer_record(e)
          if r then S.cons[#S.cons + 1] = r end
        end
      end
    end
    S.ci = last + 1
    if S.ci > #S.chunks then
      table.sort(S.cons, function(a, b) return a.id < b.id end)
      S.seen, S.chunks = nil, nil
      S.net = { poles = S.poles, consumers = S.cons, producers = S.prods }
      S.job = R.job(S.net)
      S.stage = "analyse"
    end
  elseif S.stage == "analyse" then
    if R.job_step(S.job, Rt.WORK) then
      S.A = S.job.A
      S.stage = "apply"
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Application
---------------------------------------------------------------------------------------------------
--- Contrôles contre le moteur : composantes du modèle contre réseaux du moteur, « hors de portée » contre « sans réseau ».
local function engine_check(S, A)
  local by_comp, by_net = {}, {}
  local split, merge = 0, 0
  for i, p in ipairs(S.poles) do
    if p.net then
      local c = A.comp[i]
      by_comp[c] = by_comp[c] or {}
      by_comp[c][p.net] = true
      by_net[p.net] = by_net[p.net] or {}
      by_net[p.net][c] = true
    end
  end
  for _, c in ipairs(sorted_keys(by_comp)) do
    local n = 0
    for _ in pairs(by_comp[c]) do n = n + 1 end -- compte seulement
    if n > 1 then split = split + 1 end
  end
  for _, nid in ipairs(sorted_keys(by_net)) do
    local n = 0
    for _ in pairs(by_net[nid]) do n = n + 1 end
    if n > 1 then merge = merge + 1 end
  end
  local cover_bad = 0
  local uncov = {}
  for _, k in ipairs(A.uncovered) do uncov[k] = true end
  for k, c in ipairs(S.cons) do
    local model_covered = not uncov[k]
    local engine_covered = c.net ~= nil
    if model_covered ~= engine_covered then cover_bad = cover_bad + 1 end
  end
  return { comp_split = split, comp_merge = merge, cover_disagree = cover_bad }
end

local function template_power_kw(spec)
  local fn = spec and spec.gen and M.GEN[spec.gen]
  if not fn then return 0 end
  local ok, g = pcall(fn, table.unpack(spec.args or {}))
  return (ok and g and g.power_kw) or 0
end

--- Puissance d'une unité de la centrale existante (production lue aux prototypes des pièces d'un gabarit d'une unité).
local function plant_unit(spec)
  local fn = spec and spec.gen and M.GEN[spec.gen]
  if not fn then return nil end
  local ok, g = pcall(fn, 1)
  if not (ok and g and g.entities) then return nil end
  local kw = 0
  for _, e in ipairs(g.entities) do
    local ep = game.entity_prototypes[e.name]
    if ep and (ep.max_energy_production or 0) > 0 then kw = kw + ep.max_energy_production * Rt.KW end
  end
  if kw <= 0 then kw = g.electric_out_kw or 0 end
  local ext = g.extensions and g.extensions[1]
  return { kw = kw, max = ext and ext.max or 1 }
end

local function open_state(s) return s ~= "fini" and s ~= "refuse" and s ~= "bloque" end

--- Demande une centrale de plus (retourne l'identifiant du projet ou nil).
local function ask_plant(f, rs, base, n, tick, why)
  local b = f.build
  local spec = {}
  for k, v in pairs(base.spec) do spec[k] = v end -- copie du gabarit de la centrale (clés lues telles quelles)
  spec.args = { n }
  spec.extra = true
  spec.prio = Build.PRIO + 5
  local pt = base.parts[1]
  if pt and pt.ox then spec.near = { x = pt.ox + (pt.w or 0) / 2, y = pt.oy + (pt.h or 0) / 2 } end
  local id = Build.request(f, spec)
  if id then
    rs.plants[#rs.plants + 1] = { pid = id, asked = tick, n = n, arms = nil }
    rs.stats.plants_asked = rs.stats.plants_asked + 1
    log(string.format("[FO-RESEAU] %s : centrale de plus demandee (projet %d, %d unite(s)) : %s", f.key or "player", id, n, why))
  end
  return id
end

--- Capacité : verdict et agrandissement.
local function capacity_step(f, rs, A, tick, report)
  local b = f.build
  local cap = R.capacity(A)
  cap.out_kw = R.push(rs.hist, cap.out_kw, Rt.HIST)
  local base = b.plant and b.projects[b.plant]
  local unit = base and plant_unit(base.spec)
  -- puissance des modules électriques demandés, pas bâtis (mémoire par projet : un gabarit ne se refait pas à chaque relevé)
  rs.plan_kw = rs.plan_kw or {}
  local plan = 0
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and open_state(p.state) and p.spec and p.spec.gen and not p.spec.extra and p.id ~= b.plant then
      if rs.plan_kw[pid] == nil then rs.plan_kw[pid] = template_power_kw(p.spec) end
      plan = plan + rs.plan_kw[pid]
    end
  end
  local v = R.verdict(cap, { unit_kw = unit and unit.kw, plan_kw = plan, alert = rs.alert })
  report.level, report.load, report.projected, report.add, report.need_kw = v.level, v.load, v.projected, v.add, v.need_kw
  report.prod_kw, report.out_kw, report.dem_kw, report.plan_kw, report.unit_kw = cap.prod_kw, cap.out_kw, cap.dem_kw, plan, unit and unit.kw or 0
  report.starved, report.starved_kw = cap.starved, cap.starved_kw
  if v.level == "alerte" or v.level == "sature" then rs.alerts = rs.alerts + 1 else rs.alerts = 0 end
  -- une centrale de plus : la centrale de base finie, aucune autre en cours, attente après la précédente, alerte confirmée
  local open_ext = false
  for _, e in ipairs(rs.plants) do
    local p = b.projects[e.pid]
    if p and open_state(p.state) then open_ext = true end
  end
  if base and base.state == "fini" and unit and v.add > 0 and rs.alerts >= Rt.CONFIRM and not open_ext and tick >= rs.ext_after
      and Tokens.take(f, tick, Build.COST_PLAN) then
    ask_plant(f, rs, base, math.max(1, math.min(v.add, unit.max)), tick, v.why)
    rs.alerts = 0
  end
  report.plant_open = open_ext
  return v
end

--- Poteaux de nos projets, bâtis, absents du relevé et morts depuis assez longtemps : candidats à la remise en état.
local function lost_poles(f, rs, S, tick)
  local present = {}
  for _, p in ipairs(S.poles) do present[p.name .. "@" .. pkey(p.x, p.y)] = true end
  local died = {}
  for _, d in ipairs(rs.died) do died[d.name .. "@" .. pkey(d.x, d.y)] = d end
  local b = f.build
  local out, seen = {}, {}
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and p.state ~= "refuse" then
      for _, e in ipairs(p.ents) do
        if e.built and e.anchor and e.item then
          local k = e.name .. "@" .. pkey(e.x, e.y)
          local d = died[k]
          if d and not present[k] and not seen[k] and tick - d.tick >= Rt.REPAIR_DELAY then
            local ep = game.entity_prototypes[e.name]
            if ep and ep.type == "electric-pole" then
              local rec = rs.repairs[k]
              if not (rec and (rec.tries or 0) >= Rt.REPAIR_TRIES) and not (rec and rec.pid and b.projects[rec.pid] and open_state(b.projects[rec.pid].state)) then
                seen[k] = true
                local pd = pole_proto(e.name)
                out[#out + 1] = { key = k, ent = e, x = e.x, y = e.y, wire = pd.wire, supply = pd.supply, cost = 1 }
              end
            end
          end
        end
      end
    end
  end
  table.sort(out, function(a, c) if a.y ~= c.y then return a.y < c.y end if a.x ~= c.x then return a.x < c.x end return a.key < c.key end)
  return out
end

--- Remise en état : plan pur, puis petit projet du plan directeur (fantômes, PNJ).
local function repair_step(f, rs, S, A, tick, report)
  local lost = lost_poles(f, rs, S, tick)
  report.lost = #lost
  if #lost == 0 then return end
  if not Tokens.take(f, tick, Rt.TOKENS_PLAN) then return end
  local plan = R.repair(S.net, lost)
  report.repair_targets, report.repair_chosen = plan.targets, #plan.chosen
  if #plan.chosen == 0 then return end
  local b = f.build
  local id = Build.request(f, { repair = true, prio = Build.PRIO + 25, domain = "infrastructures" })
  if not id then return end
  local p = b.projects[id]
  p.ents, p.obst_keys = {}, {}
  for _, j in ipairs(plan.chosen) do
    local c, e = lost[j], lost[j].ent
    p.ents[#p.ents + 1] = { name = e.name, x = e.x, y = e.y, dir = e.dir or 0, role = "reparation", item = e.item, anchor = e.anchor,
      ax = e.ax, ay = e.ay, built = false }
    local rec = rs.repairs[c.key] or { tries = 0 }
    rec.tries, rec.pid, rec.tick = rec.tries + 1, id, tick
    rs.repairs[c.key] = rec
    if rec.tries >= Rt.REPAIR_TRIES then rs.stats.repairs_abandoned = rs.stats.repairs_abandoned + 1 end
  end
  p.state, p.started = "reserve", tick
  rs.stats.repairs_made = rs.stats.repairs_made + 1
  rs.stats.poles_lost = rs.stats.poles_lost + #plan.chosen
  log(string.format("[FO-RESEAU] %s : %d poteau(x) perdu(s), %d a relever pour rallumer %d batiment(s) (projet %d)", f.key or "player",
    #lost, #plan.chosen, plan.restored, id))
end

local function apply(f, S, tick)
  local rs = state_of(f)
  local A = S.A
  local report = { tick = tick, poles = #S.poles, comps = A.ncomp, consumers = #S.cons, producers = #S.prods, powered = A.n_powered,
    uncovered = #A.uncovered, orphans = #A.orphans, islands = #A.islands, dead_ends = #A.dead }
  report.check = engine_check(S, A)
  -- zones non couvertes
  local items = {}
  for _, k in ipairs(A.uncovered) do
    local c = S.cons[k]
    items[#items + 1] = { x0 = c.x0, y0 = c.y0, x1 = c.x1, y1 = c.y1, kw = c.kw }
  end
  local zones = R.zones(items, Rt.ZONE_GAP)
  report.zones = {}
  for i = 1, math.min(#zones, Rt.ZONES_KEPT) do
    local z = zones[i]
    report.zones[i] = { x0 = z.x0, y0 = z.y0, x1 = z.x1, y1 = z.y1, n = z.n, kw = z.kw }
  end
  report.n_zones = #zones
  -- îlots sans producteur
  report.island_list = {}
  for i, c in ipairs(A.islands) do
    if i > Rt.ZONES_KEPT then break end
    local s = A.comps[c]
    report.island_list[i] = { poles = s.poles, consumers = s.n_cons, kw = s.dem_kw }
  end
  local v = capacity_step(f, rs, A, tick, report)
  repair_step(f, rs, S, A, tick, report)
  rs.stats.surveys = rs.stats.surveys + 1
  rs.report = report
  S.pivots = R.pivot_job(S.net, A)
  S.stage = "pivots"
  if rs.last_log == nil or tick - rs.last_log >= Rt.LOG_EVERY or rs.last_level ~= v.level then
    rs.last_log, rs.last_level = tick, v.level
    log(string.format("[FO-RESEAU] %s : %d poteau(x) en %d composante(s) ; %d batiment(s) electriques, %d alimente(s), %d hors de portee (%d zone(s)), %d en ilot, %d affame(s) ; production %.0f kW (charge %.0f %%, projetee %.0f %%) -> %s ; moteur : %d scission(s), %d fusion(s), %d desaccord(s) de couverture",
      f.key or "player", report.poles, report.comps, report.consumers, report.powered, report.uncovered, report.n_zones, report.orphans,
      report.starved or 0, report.prod_kw or 0, (report.load or 0) * 100, (report.projected or 0) * 100, v.level, report.check.comp_split,
      report.check.comp_merge, report.check.cover_disagree))
  end
end

local function finish_pivots(f, S)
  local rs = state_of(f)
  local top = {}
  for i = 1, math.min(#S.pivots.out, Rt.PIVOTS_KEPT) do
    local o = S.pivots.out[i]
    local p = S.poles[o.pole]
    top[i] = { x = p.x, y = p.y, n = o.n, kw = o.kw, islands = o.islands, articulation = o.art }
  end
  if rs.report then rs.report.pivots, rs.report.n_pivots = top, #S.pivots.out end
end

---------------------------------------------------------------------------------------------------
-- Boucle
---------------------------------------------------------------------------------------------------
--- Bras des centrales de plus : mêmes règles que la centrale de base (plant_arms), état propre à chacune.
local function step_extra_plants(f, rs, tick)
  local b = f.build
  local surface = surface_of(f)
  for _, e in ipairs(rs.plants) do
    local p = b.projects[e.pid]
    if p and p.state == "fini" then
      e.finished = e.finished or tick
      local saved = b.plant_arms
      b.plant_arms = e.arms
      PlantArms.step(f, surface, p, tick)
      e.arms = b.plant_arms
      b.plant_arms = saved
      if tick >= (rs.ext_after or 0) and not e.cooled then
        e.cooled = true
        rs.ext_after = math.max(rs.ext_after or 0, e.finished + Rt.PLANT_COOLDOWN)
      end
    end
  end
end

local function step_team(f, tick)
  local rs = state_of(f)
  step_extra_plants(f, rs, tick)
  local key = key_of(f)
  local S = SURVEY[key]
  if not S then
    if tick < rs.next then return end
    S = { stage = "poles" }
    SURVEY[key] = S
  end
  if not Tokens.take(f, tick, Rt.TOKENS) then return end
  if S.stage == "apply" then
    apply(f, S, tick)
    return
  elseif S.stage == "pivots" then
    if R.pivot_step(S.pivots, Rt.WORK) then
      finish_pivots(f, S)
      SURVEY[key] = nil
      rs.next = tick + Rt.PERIOD
    end
    return
  end
  survey_step(f, S, tick)
end

Events.on_nth_tick(Rt.STEP, function(e)
  local teams = team_list()
  if #teams == 0 then return end
  Profiler.start("reseau")
  if classify_step() then
    for _, f in ipairs(teams) do step_team(f, e.tick) end
  end
  Profiler.stop("reseau")
end)

-- Un poteau d'une équipe meurt : sa place est notée (la remise en état ne relève que les morts, jamais un poteau repris).
Events.on(defines.events.on_entity_died, function(e)
  local ent = e.entity
  if not (ent and ent.valid and ent.type == "electric-pole") then return end
  local fname = ent.force and ent.force.name
  for _, f in ipairs(team_list()) do
    if f.force == fname then
      local rs = state_of(f)
      rs.died[#rs.died + 1] = { x = ent.position.x, y = ent.position.y, name = ent.name, tick = game.tick }
      -- oublis : les plus anciens, ou périmés
      local keep = {}
      for _, d in ipairs(rs.died) do if game.tick - d.tick < Rt.DIED_TTL then keep[#keep + 1] = d end end
      while #keep > Rt.DIED_KEPT do table.remove(keep, 1) end
      rs.died = keep
    end
  end
end)

---------------------------------------------------------------------------------------------------
-- Lecture
---------------------------------------------------------------------------------------------------
--- Dernier relevé publié d'une équipe (copie superficielle) ou nil.
function Rt.report(f)
  return f and f.reseau and f.reseau.report or nil
end

--- Zones non couvertes du dernier relevé : liste de { x0, y0, x1, y1, n, kw } (lecture par le cerveau).
function Rt.uncovered_zones(f)
  local r = Rt.report(f)
  return r and r.zones or {}
end

local function team_of_key(key)
  for _, f in ipairs(team_list()) do
    if key_of(f) == tostring(key) then return f end
  end
  return nil
end

remote.add_interface("fo-reseau", {
  --- Dernier relevé publié d'une équipe.
  report = function(key)
    local f = team_of_key(key)
    return f and Rt.report(f) or nil
  end,
  --- État de la remise en état et des centrales de plus.
  state = function(key)
    local f = team_of_key(key)
    local rs = f and f.reseau
    if not rs then return nil end
    local plants = {}
    for _, e in ipairs(rs.plants) do
      local p = f.build.projects[e.pid]
      plants[#plants + 1] = { pid = e.pid, n = e.n, state = p and p.state or "?", asked = e.asked, finished = e.finished }
    end
    local repairs = {}
    for _, k in ipairs(sorted_keys(rs.repairs)) do
      local r = rs.repairs[k]
      local p = r.pid and f.build.projects[r.pid]
      repairs[#repairs + 1] = { key = k, tries = r.tries, pid = r.pid, state = p and p.state or "?" }
    end
    return { stats = rs.stats, plants = plants, repairs = repairs, died = #rs.died, alerts = rs.alerts, alert = rs.alert or R.ALERT,
      next = rs.next, ext_after = rs.ext_after }
  end,
  --- Relevé immédiat (banc) ; alert : seuil d'alerte d'essai (nil : 0,8).
  survey_now = function(key, alert)
    local f = team_of_key(key)
    if not f then return false end
    local rs = state_of(f)
    rs.next = 0
    if alert ~= nil then rs.alert = alert end
    return true
  end,
})

return Rt
