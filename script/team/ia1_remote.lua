--[[
  Interface distante « fo-ia1 » (lot IA1-a, docs/EQUIPES_PNJ.md §16) : mesures des équipes de PNJ (lecture ; une
  seule écriture, set_setting, pour les bancs), pour les bancs (le mod de test n'a pas accès à `global` de ce mod) et pour l'interface du lot IA1-b.

    remote.call("fo-ia1", "teams") -> { { key, force, n, max, wanted, recruited, guard, thinks, n_sum,
                                          idle_sum, surplus_sum, backlog_sum, last = { n, idle, idle_pct,
                                          backlog_s, surplus }, produced_mu, produced = { [objet] = n },
                                          delivered = { [objet] = n }, nav_fail, goal_moved, rescued,
                                          slots_bad, slots_owned }, ... }  factions vivantes (ordre des id), puis
                                          votre équipe (clé « player ») si elle existe ;
    remote.call("fo-ia1", "path")  -> statistiques du service de chemins (demandes, émissions, réussites,
                                       échecs par cause, au plus haut : demandes en vol, file) + agents riches.
    remote.call("fo-ia1", "set_setting", name, value) -> valeur lue (correction IA1-a : bancs seulement ; un
                                       réglage des équipes, S.SETTINGS ; nil sinon).
  Une seule écriture (set_setting) ; aucune fonction ni objet du moteur dans les résultats. `held` : pensées où
  le frein par le travail (fo-recruit-idle-max) a retenu une recrue.
]]

local Storage = require("script.core.storage")
local State = require("script.faction.state")
local Stock = require("script.team.stock") -- lot COFFRE : stock = coffre du QG + annexes
local Registry = require("script.companion.registry")
local Scale = require("shared.team.scale")
local Team = require("script.team.team")
local Poles = require("script.team.poles")
local Config = require("script.core.config")
local Outposts = require("script.faction.outposts") -- lot FOURS (bancs : fours posés, interrupteur, compteurs de visites)
local Build = require("script.team.build") -- lot ÉTAGE 5 (bancs : couloir d'un accès écrit) ; déjà chargé par script/team/worker.lua
local T = require("shared.team.config")
local Pl = require("shared.team.plan") -- lot FOREUSES-THERMIQUES (bancs : clé de tuile des couloirs, couloir_hits)
local Board = require("script.team.board") -- lots FOREUSES-THERMIQUES (collect_probe) et COLLECTE (état des tâches de collecte) ; déjà chargé par team.lua
local Src = require("script.team.sources") -- lot MINAGE-MAIN (bancs : état des sorties et des décisions)
local Rt = require("shared.team.repli_thermique") -- lot FOREUSES-THERMIQUES, partie C (bancs : réglage effectif du repli, set_repli)
local RegT = require("script.team.registre_types") -- lot UPS : registre des machines par force et par type (plus de recherche sur toute la surface)

-- Lot IA1-b (docs §8.6, pilotage sans clic) :
--   team_status(key)                 -> état d'organisation publié (Poles.status) ou nil ;
--   set_orientation(key, o)          -> points normalisés { e, b, t } ou nil (préréglage, table ou liste) ;
--   inject_crisis(key, n, ticks, res) -> vrai : n tâches de minage d'extraction rouvertes pendant `ticks` (bancs) ;
--   kill_npc(key, id)                -> vrai si le PNJ de cette équipe a été retiré (mort simulée, bancs).
-- Les autres verbes du §8.6 (set_target, add_zone, resurrect, promote) arrivent avec IA1-e1, IA1-g et IA1-h.
local function team_of(key)
  if key == "player" then return State.faction("player") end
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and (f.key == key or id == key) then return f end
  end
  return nil
end

local PRODUCED = { "iron-plate", "copper-plate", "coal", "stone", "iron-ore", "copper-ore" }

local function copy_fields(src, names)
  local out = {}
  for _, k in ipairs(names) do out[k] = (src and src[k]) or 0 end
  return out
end

local function team_row(f)
  if not (f and f.team and f.hq and f.hq.valid) then return nil end
  local acc = f.team.scale or {}
  local st = f.stats or {}
  local row = {
    key = f.key or "player", force = f.force, n = f.engineers_count or 0, max = Team.npc_max(f),
    recruited = st.recruited or 0, guard = st.recruit_guard or 0, held = st.recruit_held or 0,
    thinks = acc.thinks or 0, n_sum = acc.n_sum or 0, idle_sum = acc.idle_sum or 0,
    surplus_sum = acc.surplus_sum or 0, backlog_sum = acc.backlog_sum or 0,
    last = acc.last and copy_fields(acc.last, { "n", "idle", "idle_pct", "backlog_s", "surplus" }) or nil,
    delivered = copy_fields(f.team.delivered, PRODUCED),
    collected = f.team.collected or 0, mined = st.mined or 0,
    nav_fail = st.nav_fail or 0, goal_moved = st.goal_moved or 0, rescued = st.rescued or 0,
    soldiers = f.soldiers_count or 0, tech = f.tech or 0, outposts = f.outposts_count or 0,
    -- Lot IA1-b2 (mesures) : PNJ perdus (toutes causes, puis tués par les ennemis), tourelles vivantes, fer du QG.
    lost = st.engineers_lost or 0, lost_enemy = st.lost_enemy or 0, iron = Stock.count(f, "iron-plate"),
    idle_rien = (f.team.idle_why or {}).rien or 0, idle_bloque = (f.team.idle_why or {}).bloque or 0,
    idle_manque = (f.team.idle_why or {}).manque or 0,
    -- Lot IA3-d : règle d'effectif d'une faction (dernière pensée) : raison, recrues de croissance, travail en attente.
    eff_reason = (f.team.effectif and f.team.effectif.last_d and f.team.effectif.last_d.reason) or "",
    eff_grown = (f.team.effectif and f.team.effectif.grown) or 0,
    eff_waiting = (f.team.effectif and f.team.effectif.last_d and f.team.effectif.last_d.waiting) or 0,
    eff_hands = (f.team.effectif and f.team.effectif.last_d and f.team.effectif.last_d.hands) or 0,
  }
  local turrets, defended, hq_t = 0, {}, 0
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t.valid then
      turrets = turrets + 1
      local owner = State.owner(id)
      if owner and owner.oid then defended[owner.oid] = true else hq_t = hq_t + 1 end
    end
  end
  local def_n = 0
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do if defended[oid] then def_n = def_n + 1 end end
  row.turrets, row.outposts_defended, row.hq_turrets = turrets, def_n, hq_t
  -- Production de la force (statistiques du moteur : aucune entité parcourue).
  local force = game.forces[f.force]
  local produced, mu = {}, 0
  -- Lecture protégée : le moteur simulé des tests hors jeu n'a pas de statistiques de production.
  local ok = force and pcall(function()
    local stats = force.item_production_statistics
    for _, name in ipairs(PRODUCED) do produced[name] = stats.get_input_count(name) end
  end)
  if ok then
    for _, it in ipairs(Scale.MU_ITEMS) do mu = mu + (produced[it[1]] or 0) * it[2] end
  else
    produced, mu = {}, -1
  end
  row.produced, row.produced_mu = produced, mu
  local bad, owned = 0, 0
  for i = 1, #Scale.HOME_SLOTS do
    if f.slot_bad and f.slot_bad[i] then bad = bad + 1 end
    if f.slot_owner and f.slot_owner[i] ~= nil then owned = owned + 1 end
  end
  row.slots_bad, row.slots_owned = bad, owned
  return row
end

remote.add_interface("fo-ia1", {
  teams = function()
    local out = {}
    for _, id in ipairs(State.alive()) do
      local r = team_row(State.faction(id))
      if r then out[#out + 1] = r end
    end
    local r = team_row(State.faction("player"))
    if r then out[#out + 1] = r end
    return out
  end,
  path = function()
    local P = Storage.ns("path")
    local st = P.stats
    local out = {}
    for _, k in ipairs({ "requested", "issued", "ok", "fail", "retry", "timeout", "dropped", "latency_sum",
      "fail_start", "fail_water", "fail_blocked", "fail_other", "start_moved", "inflight_max", "queue_max",
      "issued_tick_max" }) do
      out[k] = st[k] or 0
    end
    out.queued = P.tail - P.head + 1
    out.inflight = P.inflight_count
    out.agents = Registry.count()
    return out
  end,
  -- Correction IA1-a : SEULE écriture de l'interface, pour les bancs (un mod ne peut écrire que SES réglages :
  -- le mod de test passe par ici). Réglages des équipes seulement (S.SETTINGS) ; valeur bornée par Scale.read.
  -- Rend la valeur lue ensuite, ou nil si le réglage n'est pas un réglage des équipes.
  set_setting = function(name, value)
    local known = false
    for _, s in ipairs(Scale.SETTINGS) do if s.name == name then known = true end end
    if not known or type(value) ~= "number" then return nil end
    local v = Scale.read(name, function() return value end)
    settings.global[name] = { value = v }
    Config.invalidate()
    return Scale.read(name, function(n) return settings.global[n].value end)
  end,
  -- Lot FOURS (bancs seulement) : interrupteur de la règle de charge des fours et de tournée de fonte utile (faux : le comportement
  -- de 0.6.10, pour les témoins) ; compteurs de visites de la fonderie ; pose de n fours au QG (le banc les fabrique).
  set_regle_four = function(key, on)
    if type(on) ~= "boolean" then return nil end
    if key == "*" then -- toutes les équipes vivantes (factions et la vôtre), pour le témoin d'une partie entière
      local n = 0
      local list = { State.faction("player") }
      for _, id in ipairs(State.alive()) do list[#list + 1] = State.faction(id) end
      for _, f in ipairs(list) do
        if f and f.team then
          f.team.four_regle = on
          n = n + 1
        end
      end
      return n
    end
    local f = team_of(key)
    if not (f and f.team) then return nil end
    f.team.four_regle = on
    return Outposts.four_rule(f)
  end,
  -- Lot BRIQUES (bancs seulement) : interrupteur de la règle de partage des fours (vrai par défaut ; faux = comportement de 0.6.37,
  -- pour les témoins). Clé « * » : toutes les équipes vivantes.
  set_regle_partage = function(key, on)
    if type(on) ~= "boolean" then return nil end
    if key == "*" then
      local n = 0
      local list = { State.faction("player") }
      for _, id in ipairs(State.alive()) do list[#list + 1] = State.faction(id) end
      for _, f in ipairs(list) do
        if f and f.team then
          f.team.partage_regle = on
          n = n + 1
        end
      end
      return n
    end
    local f = team_of(key)
    if not (f and f.team) then return nil end
    f.team.partage_regle = on
    return Outposts.partage_rule(f)
  end,
  -- Lot BRIQUES (bancs seulement) : demande de fonte imposée { [produit] = n } ajoutée à celle du plan à chaque pensée (nil : retirée) ;
  -- `only` vrai : elle REMPLACE celle du plan.
  bench_smelt_demand = function(key, demand, only)
    local f = team_of(key)
    if not (f and f.team) then return nil end
    if demand ~= nil and type(demand) ~= "table" then return nil end
    f.team.bench_smelt = demand
    f.team.bench_smelt_seul = only == true or nil -- vrai : la demande du plan est remplacee, et non complétée
    return true
  end,
  smelt_stats = function(key)
    local f = team_of(key)
    if not (f and f.team) then return nil end
    local m = (f.stats and f.stats.smelt) or {}
    return { visits = m.visits or 0, empty = m.empty or 0, loaded = m.loaded or 0, collected = m.collected or 0,
      fueled = m.fueled or 0, freed = m.freed or 0, smelters = #Outposts.smelters(f), rule = Outposts.four_rule(f) }
  end,
  bench_smelters = function(key, n)
    local f = team_of(key)
    local chest = f and (f.hq or f.chest)
    if not (chest and chest.valid) or type(n) ~= "number" then return nil end
    local tmp = game.create_inventory(4)
    tmp.insert({ name = T.SMELTER, count = n })
    tmp.insert({ name = T.fuel, count = T.fuel_per_burner * n })
    local placed = Outposts.place_smelters(f, chest.surface, n, tmp)
    tmp.destroy()
    return placed
  end,
  -- Lot CHARBON-MAIN (bancs seulement) : pose un avant-poste `kind` de l'équipe autour de (x, y), comme un PNJ (Outposts.build), SANS
  -- combustible (foreuses à sec). Rend { id, drills, sinks } ou nil.
  -- Lot ÉTAGE 5 : (ax, ay) facultatifs : point d'accès (là où se tiendrait le bâtisseur, worker.lua ACTS.build) ; sans eux, aucun accès écrit.
  bench_outpost = function(key, kind, x, y, ax, ay)
    local f = team_of(key)
    local chest = f and (f.hq or f.chest)
    local spec = T.outposts[kind]
    if not (chest and chest.valid and spec) or type(x) ~= "number" or type(y) ~= "number" then return nil end
    local tmp = game.create_inventory(8)
    tmp.insert({ name = T.DRILL, count = spec.drills })
    tmp.insert({ name = spec.sink, count = spec.drills })
    local o = Outposts.build(f, chest.surface, kind, { x = x, y = y }, tmp)
    tmp.destroy()
    if not o then return nil end
    if type(ax) == "number" and type(ay) == "number" then
      o.access = { x = ax, y = ay }
      Build.couloirs_reset(f)
    end
    return { id = o.id, drills = #o.drill_list, sinks = #o.sinks }
  end,
  -- Lot FOREUSES-THERMIQUES (bancs seulement) : chaine de poteaux du remplacement sur place allumee (vrai, defaut) ou coupee (faux :
  -- comportement de 0.6.53, temoin du micro-scenario foreuses-chaine). Rend l'etat lu, ou nil.
  -- Lot FOREUSES-THERMIQUES (bancs seulement) : entites `name` de l'equipe posees sur une tuile de couloir d'acces (Build.couloirs). Rend le
  -- nombre, ou nil.
  couloir_hits = function(key, name)
    local f = team_of(key)
    local chest = f and (f.hq or f.chest)
    if not (chest and chest.valid) or type(name) ~= "string" then return nil end
    local cor = Build.couloirs(f)
    local n = 0
    for _, e in ipairs(chest.surface.find_entities_filtered({ name = name, force = f.force })) do
      if cor[Pl.tkey(math.floor(e.position.x), math.floor(e.position.y))] then n = n + 1 end
    end
    return n
  end,
  -- Lot FOREUSES-THERMIQUES (bancs seulement) : etat du remplacement sur place (f.swap) en une chaine lisible, ou nil.
  swap_state = function(key)
    local f = team_of(key)
    local st = f and f.swap
    if not st then return "aucun releve" end
    local w = {}
    for _, k in ipairs(State.sorted_keys(st.why or {})) do w[#w + 1] = k .. "=" .. st.why[k] end
    return string.format("faites=%d chaine=%d poteaux=%d echanges=%d pretes=%d melange=%d echecs=%d refus=%s", st.done or 0, st.chained or 0, st.poles or 0, st.exchanged or 0,
      st.ready or 0, st.mixed or 0, st.failed or 0, #w > 0 and table.concat(w, ",") or "-")
  end,
  -- Lot FOREUSES-THERMIQUES (A), bancs seulement : foreuses des avant-postes de l'equipe (thermique = a bruleur, sinon electrique),
  -- electriques reliees a un reseau et au travail, poteaux poses par le remplacement (o.swap_poles) et ceux sur un couloir d'acces, et la
  -- liste « unit_number x y reliee travaille dans_recepteur statut » des electriques (ordre des avant-postes trie ; 1 ou 0 ; statut :
  -- defines.entity_status). Rend une table, ou nil.
  swap_outposts = function(key)
    local f = team_of(key)
    if not (f and f.outposts) then return nil end
    local cor = Build.couloirs(f)
    local r = { outposts = 0, burners = 0, electrics = 0, connected = 0, working = 0, poles = 0, poles_cor = 0, list = {} }
    for _, oid in ipairs(State.sorted_keys(f.outposts)) do
      local o = f.outposts[oid]
      r.outposts = r.outposts + 1
      for _, d in ipairs(o.drill_list or {}) do
        if d.valid then
          if d.burner then
            r.burners = r.burners + 1
          else
            r.electrics = r.electrics + 1
            local c = d.is_connected_to_electric_network() and 1 or 0
            local w = d.status == defines.entity_status.working and 1 or 0
            local t = d.drop_target
            local k = (t and t.valid and (t.type == "furnace" or t.type == "container")) and 1 or 0
            r.connected, r.working = r.connected + c, r.working + w
            r.list[#r.list + 1] = string.format("%d %.1f %.1f %d %d %d %d", d.unit_number or 0, d.position.x, d.position.y, c, w, k, d.status or -1)
          end
        end
      end
      for _, p in ipairs(o.swap_poles or {}) do
        if p.valid then
          r.poles = r.poles + 1
          if cor[Pl.tkey(math.floor(p.position.x), math.floor(p.position.y))] then r.poles_cor = r.poles_cor + 1 end
        end
      end
    end
    return r
  end,
  -- Lot FOREUSES-THERMIQUES (bancs seulement, mesure du lead du 7/11 : la collecte s'arrete-t-elle parce que le stockage est plein ?).
  -- LECTURE seule. stock : coffres (QG + annexes), cases, cases vides, place libre / en stock pour chaque produit et minerai des
  -- avant-postes (T.outposts), age du dernier depot refuse (f.refused_at, -1 : aucun). outposts : par avant-poste, production en attente,
  -- receptacles pleins, foreuses a sec, tournee ouverte, age de la tournee libre, echecs du flux, et histogrammes « statut:nombre » des
  -- thermiques, des electriques et des receptacles (defines.entity_status). workers : « id:tache:cases vides/cases » de chaque PNJ.
  collect_probe = function(key)
    local f = team_of(key)
    if not (f and f.hq and f.hq.valid) then return nil end
    local tick = game.tick
    local function hist(h)
      local ks, out = {}, {}
      for k in pairs(h) do ks[#ks + 1] = k end
      table.sort(ks)
      for _, k in ipairs(ks) do out[#out + 1] = k .. ":" .. h[k] end
      return table.concat(out, ",")
    end
    local invs = Stock.inventories(f)
    local slots, empty = 0, 0
    for _, inv in ipairs(invs) do slots, empty = slots + #inv, empty + inv.count_empty_stacks() end
    local items, seen_it = {}, {}
    for _, k in ipairs(T.OUTPOST_ORDER) do
      local sp = T.outposts[k]
      for _, it in ipairs({ sp.product, sp.resource }) do
        if it and not seen_it[it] and game.item_prototypes[it] then seen_it[it] = true; items[#items + 1] = it end
      end
    end
    local room = {}
    for _, it in ipairs(items) do
      local n = 0
      for _, inv in ipairs(invs) do n = n + inv.get_insertable_count(it) end
      room[#room + 1] = it .. "=" .. n .. "/" .. Stock.count(f, it)
    end
    local r = { tick = tick, outposts = {}, workers = {},
      stock = { chests = #invs, slots = slots, empty = empty, room = table.concat(room, " "), refused_ago = f.refused_at and (tick - f.refused_at) or -1 } }
    for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
      local o = f.outposts[oid]
      local st = Outposts.status(o, tick)
      local hb, he, hs = {}, {}, {}
      for _, d in ipairs(o.drill_list or {}) do
        if d.valid then
          local h = d.burner and hb or he
          h[d.status or -1] = (h[d.status or -1] or 0) + 1
        end
      end
      for _, s in ipairs(o.sinks or {}) do if s.valid then hs[s.status or -1] = (hs[s.status or -1] or 0) + 1 end end
      r.outposts[#r.outposts + 1] = { id = oid, kind = o.kind or "?", output = st.output, stuck = st.stuck, dry = st.dry, fuel_low = st.fuel_low and 1 or 0,
        idle_s = math.floor((st.idle_ticks or 0) / 60), task = Board.has(f, "service:" .. oid) and 1 or 0,
        free_age = Board.free_age(f, "service:" .. oid, tick) or -1, fails = o.flux_fails or 0, migr = o.migr or "-",
        burners = hist(hb), electrics = hist(he), sinks = hist(hs) }
    end
    for _, id in ipairs(State.sorted_keys(f.engineers or {})) do
      local a = Registry.get(id)
      if a and a.entity and a.entity.valid then
        local inv = a.entity.get_main_inventory()
        r.workers[#r.workers + 1] = string.format("%s:%s:%d/%d", tostring(id), tostring((a.task and a.task.kind) or a.state or "?"),
          inv and inv.count_empty_stacks() or -1, inv and #inv or -1)
      end
    end
    return r
  end,
  -- Lot FOREUSES-THERMIQUES (bancs seulement, revue du lead (4), 7/11) : enregistre `ent` (poteau pose par le banc) comme piece de l'equipe
  -- (State.own) : seul un poteau de l'equipe sert de source a la chaine. Rend vrai, ou nil.
  bench_own = function(key, ent)
    local f = team_of(key)
    if not (f and ent and ent.valid and ent.unit_number) then return nil end
    State.own(ent, f.id, "pole")
    return true
  end,
  set_regle_chaine = function(key, on)
    if type(on) ~= "boolean" then return nil end
    local f = team_of(key)
    if not (f and f.team) then return nil end
    f.team.chaine_off = not on
    return on
  end,
  -- Lot FOREUSES-THERMIQUES, partie C (bancs seulement) : réglage du repli thermique de l'équipe (f.team.repli, lu par Swap.repli ;
  -- shared/team/repli_thermique.lua, Rt.cfg) : `on` (faux : témoin, règle éteinte), wait, hold, every (ticks), per_pass ; nil : défaut.
  -- Rend le réglage effectif en une chaîne, ou nil.
  set_repli = function(key, on, wait, hold, every, per_pass)
    local f = team_of(key)
    if not (f and f.team) or (on ~= nil and type(on) ~= "boolean") then return nil end
    f.team.repli = { on = on, wait = wait, hold = hold, every = every, per_pass = per_pass }
    local c = Rt.cfg(f.team.repli)
    return string.format("on=%s wait=%d hold=%d every=%d per_pass=%d", tostring(c.on), c.wait, c.hold, c.every, c.per_pass)
  end,
  -- Partie C (bancs seulement) : état du repli de l'équipe : replis faits, attentes par raison, et par avant-poste (ordre trié)
  -- « numéro:électriques:sans courant:début de la panne (-1 : aucune) ». Rend une chaîne, ou nil.
  repli_state = function(key)
    local f = team_of(key)
    if not (f and f.outposts) then return nil end
    local rp = f.swap and f.swap.repli
    local w, op = {}, {}
    for _, k in ipairs(State.sorted_keys(rp and rp.why or {})) do w[#w + 1] = k .. "=" .. rp.why[k] end
    for _, oid in ipairs(State.sorted_keys(f.outposts)) do
      local o = f.outposts[oid]
      op[#op + 1] = string.format("%s:%d:%d:%d", tostring(oid), o.electric or 0, o.unpowered or 0, o.dark_since or -1)
    end
    return string.format("replis=%d attentes=%s avant-postes=%s", rp and rp.done or 0, #w > 0 and table.concat(w, ",") or "-", table.concat(op, " "))
  end,
  -- Lot NAV2 (bancs seulement) : agrandit `rounds` fois l'avant-poste `oid` (Outposts.extend, objets fournis) : champ DENSE comme une
  -- partie longue (29 foreuses chez Écarlate). Rend le nombre de foreuses de l'avant-poste, ou nil.
  bench_extend = function(key, oid, rounds)
    local f = team_of(key)
    local o = f and f.outposts and f.outposts[oid]
    local chest = f and (f.hq or f.chest)
    if not (o and chest and chest.valid) or type(rounds) ~= "number" then return nil end
    local spec = T.outposts[o.kind]
    for _ = 1, math.min(rounds, 20) do
      local tmp = game.create_inventory(8)
      tmp.insert({ name = T.DRILL, count = spec.drills })
      tmp.insert({ name = spec.sink, count = spec.drills })
      local n = Outposts.extend(f, chest.surface, o, tmp)
      tmp.destroy()
      if n == 0 then break end
    end
    return o.drills
  end,
  -- Lot NAV2 (bancs seulement) : délai croissant des tâches au chemin raté (shared/team/repli_chemin.lua) allumé (vrai, défaut) ou coupé
  -- (faux : 0.6.42, témoin). Rend l'état lu, ou nil.
  set_regle_repli = function(key, on)
    if type(on) ~= "boolean" then return nil end
    local f = team_of(key)
    if not (f and f.team) then return nil end
    f.team.repli_off = not on
    return on
  end,
  -- Lot NAV2 (bancs seulement) : point d'accès atteignable d'un avant-poste (shared/team/acces_champ.lua) allumé (vrai, défaut) ou coupé
  -- (faux : comportement de 0.6.42, témoin). Clé « * » : toutes les équipes vivantes. Rend l'état lu, ou le nombre d'équipes touchées.
  set_regle_acces = function(key, on)
    if type(on) ~= "boolean" then return nil end
    local list = {}
    if key == "*" then
      list[1] = State.faction("player")
      for _, id in ipairs(State.alive()) do list[#list + 1] = State.faction(id) end
    else
      list[1] = team_of(key)
    end
    local n = 0
    for _, f in ipairs(list) do
      if f and f.team then
        f.team.acces_off = not on
        for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do f.outposts[oid].acces_cache = nil end
        n = n + 1
      end
    end
    if key ~= "*" then
      if n > 0 then return on end
      return nil
    end
    return n
  end,
  -- Lot ÉTAGE 5 (bancs seulement) : couloir d'accès réservé des avant-postes (shared/team/couloir.lua) allumé (vrai, défaut) ou coupé (faux :
  -- comportement d'avant, témoin). Clé « * » : toutes les équipes vivantes. Rend l'état lu, ou le nombre d'équipes touchées.
  set_regle_couloir = function(key, on)
    if type(on) ~= "boolean" then return nil end
    local list = {}
    if key == "*" then
      list[1] = State.faction("player")
      for _, id in ipairs(State.alive()) do list[#list + 1] = State.faction(id) end
    else
      list[1] = team_of(key)
    end
    local n = 0
    for _, f in ipairs(list) do
      if f and f.team then
        f.team.couloir_off = not on
        n = n + 1
      end
    end
    if key ~= "*" then
      if n > 0 then return on end
      return nil
    end
    return n
  end,
  -- Lot CHARBON-MAIN (bancs seulement) : règle « sorties d'abord » (shared/team/sorties_main.lua) allumée (vrai, défaut) ou coupée (faux :
  -- le comportement de 0.6.41, témoin). Clé « * » : toutes les équipes vivantes. Rend le nombre d'équipes touchées, ou l'état lu.
  set_regle_sorties = function(key, on)
    if type(on) ~= "boolean" then return nil end
    local list = {}
    if key == "*" then
      list[1] = State.faction("player")
      for _, id in ipairs(State.alive()) do list[#list + 1] = State.faction(id) end
    else
      list[1] = team_of(key)
    end
    local n = 0
    for _, f in ipairs(list) do
      if f and f.team then
        f.team.sorties_regle = on
        n = n + 1
      end
    end
    if key ~= "*" then
      if n > 0 then return on end
      return nil
    end
    return n
  end,
  team_status = function(key)
    local f = team_of(key)
    return f and f.team and Poles.status(f) or nil
  end,
  set_orientation = function(key, o)
    local f = team_of(key)
    if not (f and f.team) then return nil end
    return Poles.set_orientation(f, o)
  end,
  inject_crisis = function(key, n, ticks, resource)
    local f = team_of(key)
    if not (f and f.team) or type(n) ~= "number" or type(ticks) ~= "number" then return false end
    return Poles.inject_crisis(f, math.max(1, math.min(40, math.floor(n))), math.max(60, math.floor(ticks)), resource)
  end,
  -- Lot INDUSTRIE I2 (bancs seulement) : file sûre des PNJ sans tâche allumée (vrai) ou éteinte (faux, témoin de 0.6.28) ;
  -- clé « * » : toutes les équipes vivantes. Rend le nombre d'équipes touchées (ou l'état lu pour une clé).
  set_sur = function(key, on)
    if type(on) ~= "boolean" then return nil end
    if key == "*" then
      local n = 0
      local list = { State.faction("player") }
      for _, id in ipairs(State.alive()) do list[#list + 1] = State.faction(id) end
      for _, f in ipairs(list) do
        if f and f.team then
          Poles.set_sur(f, on)
          n = n + 1
        end
      end
      return n
    end
    local f = team_of(key)
    if not (f and f.team) then return nil end
    return Poles.set_sur(f, on)
  end,
  -- Lot COLLECTE (bancs seulement, scenarios/collecte-fer.lua) : l'équipe `key` est réduite à `keep` PNJ, son coffre vidé de fer, et un projet
  -- « fini » de banc tient les coffres de sortie `spots` = { { x, y, plaques }, ... } (coffres de fer posés ici, garnis de plaques de fer).
  -- Rend { project, kept, iron, outs } ou nil. Aucune règle du lot n'est nommée ici : la même interface sert le témoin.
  bench_collecte = function(key, keep, spots)
    local f = team_of(key)
    if not (f and f.team and f.hq and f.hq.valid and type(keep) == "number" and type(spots) == "table") then return nil end
    local ids = State.sorted_keys(f.engineers or {})
    for i = #ids, keep + 1, -1 do Registry.remove(ids[i], true) end
    local fe = T.outposts.iron.product
    local have = Stock.count(f, fe)
    if have > 0 then Stock.remove(f, fe, have) end
    local surface = f.hq.surface
    local id = Build.request(f, { bench = "collecte" })
    local p = f.build and f.build.projects[id]
    if not p then return nil end
    p.state, p.finished, p.counted = "fini", game.tick, true
    for _, s in ipairs(spots) do
      local c = surface.create_entity({ name = T.outposts.coal.sink, position = { x = s[1], y = s[2] }, force = f.force })
      RegT.note(c) -- lot UPS : pose sans événement, notée au registre des machines
      if c then
        c.get_inventory(defines.inventory.chest).insert({ name = fe, count = s[3] })
        p.outs[#p.outs + 1] = { x = c.position.x, y = c.position.y }
      end
    end
    return { project = id, kept = math.min(#ids, keep), iron = Stock.count(f, fe), outs = #p.outs }
  end,
  -- Lot COLLECTE (bancs seulement) : état des tâches ia1d:<projet>:o:<i> au tableau ({ prio, critical, prise }), et, si la règle du lot existe,
  -- ses choix (f.team.collecte : picked, refused). Lecture seule.
  -- Lot MINAGE-MAIN (bancs seulement) : scène du micro-banc « minage-sources » : l'équipe est réduite à `keep` PNJ et ses plaques de fer sont
  -- retirées du coffre (fer libre 0). Rend { kept, iron }.
  bench_sources = function(key, keep)
    local f = team_of(key)
    if not (f and f.team and f.hq and f.hq.valid and type(keep) == "number") then return nil end
    local ids = State.sorted_keys(f.engineers or {})
    for i = #ids, keep + 1, -1 do Registry.remove(ids[i], true) end
    local fe = T.outposts.iron.product
    local have = Stock.count(f, fe)
    if have > 0 then Stock.remove(f, fe, have) end
    return { kept = math.min(#ids, keep), iron = Stock.count(f, fe) }
  end,
  -- Lot MINAGE-MAIN (bancs seulement) : interrupteur de la règle des sources (témoin : false = comportement d'avant le lot).
  set_regle_sources = function(key, on)
    local f = team_of(key)
    if not (f and f.team) then return nil end
    if on == false then f.team.sources_regle = false else f.team.sources_regle = nil end
    return f.team.sources_regle ~= false
  end,
  -- Lot MINAGE-MAIN (bancs seulement, lecture seule) : registre des sorties, décisions, compteurs de la garde du minage à la main, tournées.
  sources_state = function(key)
    local f = team_of(key)
    if not (f and f.team) then return nil end
    local st = f.team.sources
    local b = Board.get(f)
    local fetch_free, fetch_taken = 0, 0
    for _, k in ipairs(State.sorted_keys(b.tasks)) do
      local t = b.tasks[k]
      if t.kind == "fetch" then if t.worker then fetch_taken = fetch_taken + 1 else fetch_free = fetch_free + 1 end end
    end
    local ts = f.team.task_stats or {}
    local hand = {}
    for _, r in ipairs(State.sorted_keys(st and st.hand or {})) do hand[r] = { ok = st.hand[r].ok, no = st.hand[r].no } end
    local dec = {}
    for _, r in ipairs(State.sorted_keys(st and st.dec or {})) do
      local d = st.dec[r]
      dec[r] = string.format("%s:%s:%s:%s", tostring(d.act), tostring(d.item), tostring(d.uid), tostring(d.why))
    end
    return { rule = st ~= nil and f.team.sources_regle ~= false, chests = st and st.nchests or 0, sorties = st and #Src.list(f, "sortie") or 0,
      scanned = st and st.scanned or false, trips = st and st.trips or 0, fetched = st and st.fetched or 0, empty = st and st.empty or 0,
      dropped = st and st.dropped or 0, hand = hand, dec = dec, fetch_free = fetch_free, fetch_taken = fetch_taken,
      mine_ok = ts.mine and ts.mine.ok or 0, mine_fail = ts.mine and ts.mine.fail or 0, fetch_ok = ts.fetch and ts.fetch.ok or 0,
      fetch_fail = ts.fetch and ts.fetch.fail or 0, engineers = f.engineers_count or 0, floor = f.team.floor or 0,
      iron = Stock.count(f, T.outposts.iron.product), main_sources = f.stats and f.stats.main_sources or 0 }
  end,
  collecte_state = function(key, pid)
    local f = team_of(key)
    if not (f and f.team) then return nil end
    local tasks = {}
    local b = Board.get(f)
    for i = 1, 20 do
      local t = b.tasks["ia1d:" .. tostring(pid) .. ":o:" .. i]
      if t then tasks[i] = { prio = t.prio, critical = t.critical == true, prise = t.worker ~= nil, urgent = t.urgent_collect == true } end
    end
    local c = f.team.collecte
    local refused = {}
    if c and c.refused then for _, k in ipairs(State.sorted_keys(c.refused)) do refused[#refused + 1] = k end end
    local picked = {}
    if c and c.picked then for _, k in ipairs(State.sorted_keys(c.picked)) do picked[#picked + 1] = k end end
    -- PNJ : état et tâche tenue ; tâches libres en tête de liste ; raisons des prises vides (profileur allumé seulement)
    local npcs = {}
    for _, id in ipairs(State.sorted_keys(f.engineers or {})) do
      local ag = Registry.get(id)
      if ag then npcs[#npcs + 1] = tostring(id) .. ":" .. tostring(ag.state) .. ":" .. tostring(ag.task and ag.task.key or "-") end
    end
    local free = {}
    for _, t in ipairs(b.list or {}) do
      if not t.worker and #free < 6 then free[#free + 1] = string.format("%s p%d%s", tostring(t.key), t.prio or 0, t.fond and " fond" or "") end
    end
    local miss = {}
    if b.miss and b.miss.why then for _, k in ipairs(State.sorted_keys(b.miss.why)) do miss[#miss + 1] = k .. "=" .. b.miss.why[k] end end
    return { tasks = tasks, rule = c ~= nil, picked = picked, refused = refused, engineers = f.engineers_count or 0,
      floor = f.team.floor or 0, iron = Stock.count(f, T.outposts.iron.product), npcs = npcs, free = free, miss = miss }
  end,
  kill_npc = function(key, id)
    local f = team_of(key)
    if not (f and f.engineers and f.engineers[id]) then return false end
    Registry.remove(id, true)
    return true
  end,
  -- Lot STOCKAGE-VITAL (bancs seulement) : coût de Stock.insert compté en INSTRUCTIONS de la machine Lua (crochet de compte de
  -- debug.sethook, période 1 : déterministe, indépendant de la charge du PC ; jamais os.clock) et en APPELS de fonctions (Lua et
  -- moteur : un appel au moteur compte pour 1, son travail interne n'est pas mesuré). Dépôt de `n` `item`, `reps` fois ; chaque
  -- dépôt est repris aussitôt, hors du compte (le stock revient à son état). Le crochet d'avant et les dates de refus sont remis.
  -- Rend { hook = vrai, instr = instructions par appel, calls = appels par appel, put = objets déposés au total, reps, inventaires,
  -- annexes } ou { hook = false } quand la bibliothèque debug n'a pas sethook. Un coffre d'annexe n'est pas mesuré (il serait posé).
  stock_cost = function(key, item, n, reps)
    local f = team_of(key)
    if not (f and f.hq and f.hq.valid) or type(item) ~= "string" or (Stock.ANNEX_ITEM and Stock.ANNEX_ITEM(item)) then return nil end
    local dbg = rawget(_G, "debug")
    if not (type(dbg) == "table" and type(dbg.sethook) == "function" and type(dbg.gethook) == "function") then return { hook = false } end
    reps = math.max(1, math.min(1000, math.floor(tonumber(reps) or 100)))
    n = math.max(1, math.floor(tonumber(n) or 1))
    local old_fn, old_mask, old_count = dbg.gethook()
    local saved_at, saved_log = f.refused_at, f.refused_log
    local ni, nc, put = 0, 0, 0
    local function hook(ev) if ev == "count" then ni = ni + 1 else nc = nc + 1 end end
    local dep = { reserve = true } -- comme le dépôt d'un PNJ (script/team/worker.lua) : la réserve des vitales s'applique
    for _ = 1, reps do
      dbg.sethook(hook, "c", 1)
      local p = Stock.insert(f, item, n, dep)
      dbg.sethook()
      put = put + p
      if p > 0 then Stock.remove(f, item, p) end
    end
    if old_fn then dbg.sethook(old_fn, old_mask, old_count) end
    f.refused_at, f.refused_log = saved_at, saved_log
    -- Lecture seule, pour le banc : verdicts du ramassage (Stock.skip_fn) et compteurs du coffre urgent (nil avant le lot).
    local skip = Stock.skip_fn and Stock.skip_fn(f)
    local st = f.stats or {}
    local fill_used, fill_size = Stock.fill(f)
    return { hook = true, fill_used = fill_used, fill_size = fill_size, instr = ni / reps, calls = nc / reps, put = put, reps = reps, inventaires = #Stock.inventories(f),
      annexes = #Stock.annexes(f), skip_item = skip and skip(item) or false, skip_fn = skip ~= nil,
      stock_logs = st.stock_logs, annex_placed = st.annex_placed, annex_held = st.annex_held,
      why = f.stock_why and f.stock_why.why or nil, refused = st.refused,
      ground_taken = st.ground_taken, ground_passes = st.ground_passes, -- lot STOCKAGE-VITAL : objets au sol du QG repris (Stock.pick_ground)
      -- lot STOCKAGE-VITAL (C1, C2 de DIAG_CONSO) : cumuls des deux compteurs et contenu du stock (ce qui ENTRE, par différence)
      refused_calls = st.refused_calls, claims = st.claims, claim_full = st.claim_full, contents = Stock.contents(f) }
  end,
})

return {}
