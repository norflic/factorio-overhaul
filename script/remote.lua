--[[
  Interface distante "factorio-overhaul" : pilotage sans joueur (tests automatisés en moteur réel,
  scénarios, autres mods). Utilisée par le mod de test fo-autotest (tools/autotest/).

    remote.call("factorio-overhaul", "war_start", n, soldats, ingenieurs, distance) -> bool
    remote.call("factorio-overhaul", "war_fund", MU)                              -> factions financées
    remote.call("factorio-overhaul", "companions_spawn", n, rayon)                 -> nombre créé
    remote.call("factorio-overhaul", "profiler", true|false)
    remote.call("factorio-overhaul", "reset_stats")
    remote.call("factorio-overhaul", "log_report", etiquette)   -- écrit bench + guerre dans le journal
]]

local Profiler = require("script.core.profiler")
local Bench = require("script.companion.bench")
local War = require("script.faction.war")
local F = require("shared.faction.config")
local State = require("script.faction.state")
local Director = require("script.td.director") -- require interdit dans un gestionnaire d'événement
local Team = require("script.team.team")
local Levels = require("script.levels.levels")
local Storage = require("script.core.storage")

local function surface() return game.surfaces[1] end

--- Lot V3-T : emprise et place d'un aperçu ou d'une amélioration, en données simples (aucune fonction, aucune
--- référence interne) : resize = { from, to } (côtés) ; position = centre retenu (nil : aucune place) ;
--- candidate = rang de la position retenue dans l'ordre de préférence ; contour = carré de la position À
--- MONTRER { x0, y0, x1, y1 } (celui que dessine un refus : la plus facile à libérer, correction V3-T, défaut 8) ;
--- contour_candidate = son rang ; blockers = ce qui la bloque (noms d'entités, « tile:<nom> » pour une tuile),
--- trié.
local function room_fields(out, info)
  if not (info and info.resize) then return out end
  out.resize = { from = info.resize.from, to = info.resize.to }
  local room = info.room
  if room then
    local c, p = room.chosen, room.target or room.preferred
    out.position = c and { x = c.x, y = c.y } or nil
    out.candidate = room.index
    out.contour_candidate = room.target_index
    out.contour = p and { x0 = p.box.x0, y0 = p.box.y0, x1 = p.box.x1, y1 = p.box.y1 } or nil
    out.blockers = Levels.blocker_names(p)
    -- Lot V3-T2 (corrections) : points de jeu servis relevés (« drop:iron-chest@x,y », « pipe:… »), dans l'ordre.
    local pts = {}
    for _, q in ipairs(room.points or {}) do pts[#pts + 1] = q.kind .. ":" .. q.entity.name .. "@" .. q.x .. "," .. q.y end
    out.points = pts
  end
  return out
end

--- Nombre de clés d'une table (nil : 0) ; le compte ne dépend pas de l'ordre de parcours.
local function count_keys(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

local function log_lines(lines)
  for _, line in ipairs(lines) do log(line) end
end

remote.add_interface("factorio-overhaul", {
  war_start = function(n, soldiers, engineers, distance)
    local s = surface()
    local ok = War.start_at(s, game.forces.player.get_spawn_position(s), n or 4, soldiers or 100, engineers or 10, distance or F.defaults.distance)
    return ok and true or false
  end,
  war_fund = function(amount)
    return War.fund(amount or 1000)
  end,
  war_option = function(key, value)
    local s = State.war().settings
    if s then s[key] = value end
    return s ~= nil
  end,
  companions_spawn = function(n, radius)
    local s = surface()
    return Bench.spawn_at(s, game.forces.player.get_spawn_position(s), game.forces.player, nil, n or 20, "wander", radius or 32)
  end,
  -- Mode défense de tours : "on" [délai en secondes] | "off" | "next" | "status" -> état
  waves = function(action, delay_s)
    if action == "on" then Director.start(delay_s and math.floor(delay_s * 60) or nil)
    elseif action == "off" then Director.stop()
    elseif action == "next" then Director.next() end
    local st = Director.state()
    return { active = st.active, wave = st.wave, phase = st.phase, alive = st.alive, kills = st.stats.kills, cleared = st.stats.cleared, leaked = st.stats.leaked }
  end,
  -- Équipe du joueur (coffre d'équipe) : ligne d'état, ou nil s'il n'y en a pas.
  team_status = function()
    local f = State.faction("player")
    if not (f and f.hq and f.hq.valid) then return nil end
    return Team.status_line(f)
  end,
  -- Points d'intérêt (lecture seule) pour la revue visuelle : QG et avant-postes des factions et de
  -- l'équipe du joueur. Le mod de test n'a pas accès à `global` de ce mod (une table par mod).
  points_of_interest = function()
    local function team(f)
      if not (f and f.hq and f.hq.valid) then return nil end
      local t = { key = f.key or "player", hq = { x = f.hq_pos.x, y = f.hq_pos.y }, outposts = {} }
      local ids = {}
      for oid in pairs(f.outposts or {}) do ids[#ids + 1] = oid end
      table.sort(ids)
      for _, oid in ipairs(ids) do
        local o = f.outposts[oid]
        t.outposts[#t.outposts + 1] = { kind = o.kind, pos = { x = o.pos.x, y = o.pos.y } }
      end
      return t
    end
    local out = { factions = {} }
    for _, id in ipairs(State.alive()) do
      local t = team(State.faction(id))
      if t then out.factions[#out.factions + 1] = t end
    end
    out.player = team(State.faction("player"))
    return out
  end,
  -- Niveaux (session 5 ; amélioration instantanée depuis le lot V2c) : améliorer sans joueur (paiement : centre
  -- de commandement). Renvoie { ok, reason } ; reason = "done" en cas de succès, sinon le motif du refus
  -- ("max", "no-cc", "cc-too-low", "cc-families" (condition Q16 du centre), "no-resources", "unknown-item"…) ;
  -- pour le centre, blocking = familles qui bloquent et condition_level = niveau visé. Lot V3-T : entity = le
  -- bâtiment amélioré (nil en cas de refus) ; changement d'emprise : resize, position, candidate, contour,
  -- blockers (room_fields ci-dessus) ; refus faute de place : reason = "no-room" (rien n'est payé, le contour
  -- est dessiné pour la force du bâtiment).
  levels_upgrade = function(entity)
    local ok, reason, info, new = Levels.start(entity, nil)
    return room_fields({ ok = ok, reason = reason, blocking = info and info.blocking,
      condition_level = info and info.condition_level, entity = new }, info)
  end,
  -- Lot V3-T : aperçu sans rien payer ni dessiner (banc) : { ok, reason, level, next } + room_fields.
  levels_preview = function(entity)
    local info = Levels.preview(entity, nil, true)
    if not info then return nil end
    return room_fields({ ok = info.ok, reason = info.reason, level = info.level, next = info.next }, info)
  end,
  levels_row = function(entity)
    return Levels.start_row(entity, nil)
  end,
  levels_status = function(force_name)
    local force = game.forces[force_name or "player"]
    local st = Storage.ns("levels")
    local x = st.stats
    -- Lot V3-T : resized (remplacements par script à une autre taille), room_refused (refus « no-room »),
    -- contours (contours dessinés), forced (chantiers hérités posés sans place), resize_failed, refunds,
    -- spilled (objets renversés au sol par un transfert : 0 attendu), wires_lost, migrated, overlap_kept ;
    -- corrections V3-T : ghosts_removed (fantômes recouverts retirés), ground_moved / ground_left (objets au sol
    -- sortis du bâtiment agrandi / laissés faute de place).
    return { cc_level = Levels.cc_level(force), upgrades = x.upgrades, lost = x.lost, fallback = x.fallback or 0,
             resized = x.resized or 0, room_refused = x.room_refused or 0, contours = x.contours or 0,
             forced = x.forced or 0, resize_failed = x.resize_failed or 0, refunds = x.refunds or 0,
             spilled = x.spilled or 0, wires_lost = x.wires_lost or 0, migrated = x.migrated or 0,
             overlap_kept = x.overlap_kept or 0, ghosts_removed = x.ghosts_removed or 0,
             ground_moved = x.ground_moved or 0, ground_left = x.ground_left or 0,
             -- Lot V3-T2 : progressions de fabrication reposées après agrandissement (resume_later), et en attente.
             resumed = x.resumed or 0, pending = count_keys(st.pending),
             -- Corrections V3-T2 : fluide d'une fabrication en cours non rendu (boîte pleine ; 0 attendu), doublons
             -- superposés hérités d'avant 0.4.3 relevés à la migration (Levels.find_stacked).
             fluid_lost = x.fluid_lost or 0, stacked = x.stacked or 0,
             -- Suite H-T3 : relevé des emprises gardé dans la sauvegarde (global.fo.levels.footprints, copie : nombres
             -- seulement ; nil dans une sauvegarde d'avant V3-T pas encore migrée) et son écart à la table du mod
             -- chargé (true : la migration n'a pas encore tourné). Lu par le banc de migration en moteur réel
             -- (tools/autotest/fo-autotest/scenarios/ht3-migration.lua) : le global d'un mod est illisible des
             -- autres (F35).
             footprints = st.footprints, footprints_stale = Levels.footprints_stale() }
  end,
  -- Correction V3-T2 (défaut 13, H-L1) : coût de l'abonnement on_tick de Levels.resume_progress, mesuré par le banc
  -- (n appels de suite dans un LuaProfiler, écrit au journal ; la mesure ne pilote rien).
  levels_bench_resume = function(n)
    local p = game.create_profiler()
    for _ = 1, n or 1 do Levels.resume_progress() end
    p.stop()
    log({ "", "[FO-LEVELS] banc resume_progress : " .. (n or 1) .. " appels, en attente " .. count_keys(Storage.ns("levels").pending) .. " : ", p })
  end,
  profiler = function(on)
    Profiler.set_enabled(on and true or false, game.tick)
  end,
  reset_stats = function()
    Bench.reset_stats(game.tick)
  end,
  log_report = function(label)
    log("[FO-AUTOTEST] ===== " .. tostring(label) .. " (tick " .. game.tick .. ") =====")
    local lines, prof_lines = Bench.report_lines(game.tick)
    log_lines(lines)
    log_lines(prof_lines)
    log_lines(War.status_lines(game.tick))
  end,
})

return {}
