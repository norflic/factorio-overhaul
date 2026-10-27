--[[
  Lot IA3-k : moteur commun des bancs de TOURNÉES en moteur réel (docs/IA3K_COMPORTEMENTS.md §9 ; critères de
  docs/IA_ATTENDUS.md C1, C2, D1). Votre équipe (coffre posé en (2000, 0) dans une zone pavée de 400 × 400 tuiles), cerveau
  RETENU par l'interface « fo-ia3k » (hold : aucune tâche du cerveau, seulement les tournées du banc), 4 couloirs DROITS
  parallèles à l'axe x, de (2010, y) à (2330, y) pour y = -150, -50, 50, 150 (le PNJ rejoint d'abord l'entrée de son
  couloir ; en oblique, le chemin du moteur fait « diagonale puis tout droit » et s'écarte de 75 tuiles de la droite :
  le premier témoin, 29f26a1, l'a montré), un PNJ par couloir et par manche.
    - mode « route » (C2) : quand le PNJ entre dans son couloir, un groupe d'ennemis est posé SUR l'itinéraire qu'il va
      suivre (milieu des deux points de passage de la variation ; milieu du couloir sans le lot) : 2 vers, un nid et 3 petits déchiqueteurs,
      4 déchiqueteurs, ou 2 mitrailleuses ennemies (genre tourné par manche et couloir). Une tournée RÉUSSIT si le PNJ
      n'entre jamais à portée d'un des ennemis posés (portée lue au prototype : tir des vers et des tourelles, VUE des
      déchiqueteurs ; nid : 30), mesurée à leurs positions de départ (un déchiqueteur qui le poursuit ne compte pas).
    - mode « variete » (C1) : aucun ennemi ; l'aller de chaque manche est relevé ; écart latéral MÉDIAN entre les allers
      successifs d'un même couloir (tranches de 8 tuiles, 10 % à 90 % du trajet) et allongement de l'aller.
  Témoin : opts.temoin = réglage fo-war-ia3-comportement éteint à l'init. Journal : [FO-<TAG>].
]]

local C = {}

local AX, AY = 2000, 0
local SX = 2010 -- entrée des couloirs
local DX = 2330
local LANES = { -150, -50, 50, 150 }
local REACT = { alerte = true, detour = true, ["demi-tour"] = true, fuite = true, combat = true }

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

local function proto_range(name)
  local p = game.entity_prototypes[name]
  if not p then return 30 end
  if p.type == "unit-spawner" then return 30 end
  local r = 0
  local ap = p.attack_parameters
  if ap and ap.range then r = ap.range end
  if p.type == "unit" and p.vision_distance and p.vision_distance > r then r = p.vision_distance end
  return r
end

-- Groupes d'ennemis : { nom, dx, dy } autour du point posé.
local CLUSTERS = {
  { name = "vers", list = { { "small-worm-turret", -3, 0 }, { "medium-worm-turret", 3, 2 } } },
  { name = "nid", list = { { "biter-spawner", 0, 0 }, { "small-biter", -5, -4 }, { "small-biter", 5, -4 }, { "small-biter", 0, 6 } } },
  { name = "dechiqueteurs", list = { { "small-biter", -3, -3 }, { "small-biter", 3, -3 }, { "small-biter", -3, 3 }, { "small-biter", 3, 3 } } },
  { name = "tourelles", list = { { "gun-turret", 0, -3 }, { "gun-turret", 0, 3 } } },
}

local function spawn_cluster(s, kind, at)
  local out = {}
  for _, m in ipairs(CLUSTERS[kind].list) do
    local p = s.find_non_colliding_position(m[1], { x = at.x + m[2], y = at.y + m[3] }, 6, 0.5)
    local e = p and s.create_entity({ name = m[1], position = p, force = "enemy" })
    if e then
      if e.type == "unit" then
        e.set_command({ type = defines.command.stop, ticks_to_wait = 1000000, distraction = defines.distraction.by_enemy })
      elseif e.type == "ammo-turret" then
        e.insert({ name = "firearm-magazine", count = 20 })
      end
      out[#out + 1] = { unit = e.unit_number, name = m[1], x = e.position.x, y = e.position.y, r = proto_range(m[1]), ent = e,
        mobile = e.type == "unit" }
    end
  end
  return out
end

local function destroy_cluster(s, members)
  for _, m in ipairs(members) do
    for _, e in ipairs(s.find_entities_filtered({ position = { m.x, m.y }, radius = 80, force = "enemy", name = m.name })) do
      if e.valid then e.destroy() end
    end
  end
end

local function median(t)
  if #t == 0 then return 0 end
  local c = {}
  for i, v in ipairs(t) do c[i] = v end
  table.sort(c)
  local n = #c
  if n % 2 == 1 then return c[(n + 1) / 2] end
  return (c[n / 2] + c[n / 2 + 1]) / 2
end

--- Écart latéral médian entre deux allers (même mesure que shared/ai3/route.lua, R.median_gap).
local function median_gap(S, G, a, b)
  local D0 = math.sqrt(d2(S, G))
  local ux, uy = (G.x - S.x) / D0, (G.y - S.y) / D0
  local function prof(list)
    local acc = {}
    for _, p in ipairs(list) do
      local along = (p.x - S.x) * ux + (p.y - S.y) * uy
      local lat = (p.y - S.y) * ux - (p.x - S.x) * uy
      local k = math.floor(along / 8)
      local e = acc[k]
      if e then e.s, e.n = e.s + lat, e.n + 1 else acc[k] = { s = lat, n = 1 } end
    end
    return acc
  end
  local pa, pb = prof(a), prof(b)
  local gaps = {}
  for k = -100, 200 do
    if pa[k] and pb[k] then
      local mid = (k + 0.5) * 8
      if mid >= 0.1 * D0 and mid <= 0.9 * D0 then gaps[#gaps + 1] = math.abs(pa[k].s / pa[k].n - pb[k].s / pb[k].n) end
    end
  end
  return median(gaps), #gaps
end

function C.trips(opts)
  local TAG = opts.tag
  local ROUND = opts.round or 9000
  local ROUNDS = opts.rounds or 6
  local START = 600
  local CHECK = START + ROUNDS * ROUND + 60
  local mode = opts.mode or "route"

  local function team_agents(ctx)
    return ctx.remote("fo-ia3k", "agents", "player") or {}
  end

  return {
    description = opts.description,
    check_tick = CHECK,
    -- Captures (session avec images) : au tick SHOTS (manche 1, quand les PNJ voient les ennemis posés), une capture
    -- centrée sur chaque PNJ en tournée (état visible au-dessus de lui), puis une vue d'ensemble de chaque groupe d'ennemis.
    shots_delay = opts.shots_delay or 2300,
    shots = function(ctx, add)
      local st = ctx.state()
      local n = 0
      for _, a in ipairs(ctx.remote("fo-ia3k", "agents", "player") or {}) do
        if a.task or a.state == "walk" then
          n = n + 1
          add(string.format("pnj%d-%s", a.id, a.label or "marche"), a.x, a.y - 2, 0.9, 0)
        end
      end
      for _, tr in ipairs((st.cur and st.cur.trips) or {}) do
        if tr.at then add(string.format("couloir%d-ennemis", tr.k), tr.at.x - 30, tr.at.y, 0.45, 0) end
      end
      ctx.log(string.format("captures demandees au tick %d : %d PNJ en tournee", game.tick, n))
    end,

    init = function(ctx)
      local s = ctx.surface()
      local st = ctx.state()
      ctx.prepare_area(AX - 20, AY - 200, DX + 50, AY + 200, "grass-1")
      if opts.temoin then
        local v = ctx.call("war_setting", "fo-war-ia3-comportement", false)
        ctx.check(v == false, "temoin : reglage fo-war-ia3-comportement eteint", tostring(v))
      else
        local v = ctx.call("war_setting", "fo-war-ia3-comportement", true)
        ctx.check(v == true, "reglage fo-war-ia3-comportement allume", tostring(v))
      end
      ctx.call("profiler", true)
      local chest = s.create_entity({ name = "fo-team-chest", position = { AX, AY }, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose en (2000, 0)")
      if chest then
        for _, it in ipairs({ { "iron-plate", 300 }, { "coal", 100 }, { "pistol", 8 }, { "firearm-magazine", 100 } }) do
          chest.insert({ name = it[1], count = it[2] })
        end
      end
      ctx.check(ctx.remote("fo-ia3k", "hold", "player", true) == true, "cerveau de l'equipe retenu (tournees du banc seules)")
      st.rounds, st.trips, st.cur, st.labels_ttl, st.labels_seen = 0, {}, nil, 0, 0
    end,

    tick = function(ctx, e)
      local t = e.tick
      local st = ctx.state()
      local s = ctx.surface()
      local r = math.floor((t - START) / ROUND) + 1
      local in_round = t - START - (r - 1) * ROUND
      if t < START or r > ROUNDS then return end
      -- Départ d'une manche.
      if in_round == 0 then
        st.rounds = r
        -- Manches indépendantes : la carte du danger est remise à zéro (les groupes détruits en fin de manche, jamais revus,
        -- resteraient en mémoire : l'A* contournerait des fantômes).
        ctx.remote("fo-ia3k", "forget", "player")
        local idle = {}
        for _, a in ipairs(team_agents(ctx)) do if not a.task and a.state ~= "walk" then idle[#idle + 1] = a end end
        local cur = { r = r, trips = {} }
        for k, y in ipairs(LANES) do
          local a = idle[k]
          if a then
            -- Le PNJ rejoint d'abord l'ENTRÉE de son couloir (SX, y), puis le parcourt jusqu'à (DX, y) : un couloir parallèle à
            -- un axe, où le chemin du moteur est vraiment droit (en oblique, il fait « diagonale puis tout droit »).
            local n = ctx.remote("fo-ia3k", "trip", "player", a.id, DX, y, 60, SX, y)
            if n then
              cur.trips[#cur.trips + 1] = { k = k, id = a.id, n = n, start = { x = SX, y = y }, goal = { x = DX, y = y },
                min = {}, out = {}, outdone = false, reacts = {}, last_lt = a.label_t, dead = false, cluster = nil,
                in_lane = false }
            end
          end
        end
        st.cur = cur
        ctx.log(string.format("manche %d : %d tournee(s) lancee(s) (%d PNJ sans tache)", r, #cur.trips, #idle))
        return
      end
      local cur = st.cur
      if not cur then return end
      -- Entrée dans le couloir : le PNJ a atteint l'entrée et vise le bout (lot : son itinéraire tiré est connu), ou, sans
      -- le lot, il a dépassé l'entrée. Les ennemis sont posés alors, au milieu de l'itinéraire qu'il va suivre.
      local by = {}
      for _, a in ipairs(team_agents(ctx)) do by[a.id] = a end
      for _, tr in ipairs(cur.trips) do
        local a = by[tr.id]
        if a and not tr.in_lane then
          local aim = a.final and math.abs(a.final.x - DX) < 1 and math.abs(a.final.y - tr.goal.y) < 1
          if (aim and a.pts) or (not aim and a.x >= SX + 2 and math.abs(a.y - tr.goal.y) <= 6 and a.task) then
            tr.in_lane = t
            if mode == "route" then
              -- Point de l'itinéraire PRÉVU (entrée, points de passage, bout) à mi-couloir (x = (SX + DX) / 2).
              local MX = (SX + DX) / 2
              local at = { x = MX, y = tr.goal.y }
              if aim and #a.pts >= 1 then
                local chain = { { x = a.x, y = a.y } }
                for _, q in ipairs(a.pts) do chain[#chain + 1] = q end
                chain[#chain + 1] = tr.goal
                for i = 1, #chain - 1 do
                  local p1, p2 = chain[i], chain[i + 1]
                  if (p1.x - MX) * (p2.x - MX) <= 0 and p1.x ~= p2.x then
                    local u = (MX - p1.x) / (p2.x - p1.x)
                    at = { x = MX, y = p1.y + u * (p2.y - p1.y) }
                    break
                  end
                end
              end
              tr.kind = (r + tr.k) % #CLUSTERS + 1
              tr.cluster = spawn_cluster(s, tr.kind, at)
              if #tr.cluster == 0 then tr.cluster = nil end -- rien n'a pu être posé : tournée sans ennemi
              tr.at = at
            end
          end
        end
      end
      -- Relevés toutes les 10 ticks.
      if t % 10 == 0 then
        for _, tr in ipairs(cur.trips) do
          local a = by[tr.id]
          if not a then
            tr.dead = true
          else
            local p = { x = a.x, y = a.y }
            if tr.in_lane and not tr.outdone then
              tr.out[#tr.out + 1] = p
              if d2(p, tr.goal) <= 36 then tr.outdone = true end
            end
            -- Distance aux ennemis À LEUR POSTE : une unité qui a quitté le sien (elle poursuit un autre PNJ, ou charge) ne
            -- compte pas (ce n'est pas le PNJ qui entre dans sa portée) ; un ennemi détruit non plus.
            for i, m in ipairs(tr.cluster or {}) do
              local e = m.ent
              local q = nil
              if e and e.valid then
                if not m.mobile then q = m
                elseif d2(e.position, m) <= 144 then q = e.position end
              end
              if q then
                local dd = math.sqrt(d2(p, q))
                if not tr.min[i] or dd < tr.min[i] then tr.min[i] = dd end
                if dd - m.r <= 30 then tr.met = true end
              end
              -- ZONE FIXE (critère d'IA_ATTENDUS C2) : disque de portée autour de la position de DÉPART de l'ennemi. Entrer
              -- dedans, c'est le PNJ qui y va (un déchiqueteur qui charge ne déplace pas la zone).
              local ds = math.sqrt(d2(p, m))
              tr.smin = tr.smin or {}
              if not tr.smin[i] or ds < tr.smin[i] then tr.smin[i] = ds end
              if ds < m.r and not tr.first_in then tr.first_in = t end
            end
            if a.label_t and a.label_t ~= tr.last_lt then
              tr.last_lt = a.label_t
              if REACT[a.label] then
                local md = 1e9
                for _, m in ipairs(tr.cluster or {}) do md = math.min(md, math.sqrt(d2(p, m)) - m.r) end
                tr.reacts[#tr.reacts + 1] = { l = a.label, t = a.label_t, margin = md }
              end
            end
          end
        end
        -- Étiquettes visibles (D1) : textes du mod au-dessus des PNJ ; durée de vie RELEVÉE (première et dernière vue).
        st.lab = st.lab or {}
        local alive = {}
        for _, id in ipairs(rendering.get_all_ids("factorio-overhaul")) do
          if rendering.get_type(id) == "text" then
            local txt = rendering.get_text(id)
            if type(txt) == "table" and type(txt[1]) == "string" and txt[1]:sub(1, 13) == "fo-ia3k.etat-" then
              alive[id] = true
              local l = st.lab[id]
              if not l then
                l = { first = t, key = txt[1]:sub(14) }
                st.lab[id] = l
              end
              l.last = t
            end
          end
        end
        for id, l in pairs(st.lab) do
          if not alive[id] then
            st.labels_seen = st.labels_seen + 1
            -- vue de « first » à « last » (relevés toutes les 10 ticks) : durée ≥ last - first + 10 - 10
            if l.last - l.first + 10 >= 120 then st.labels_ttl = st.labels_ttl + 1 else
              st.labels_short = (st.labels_short or 0) + 1
            end
            st.lab_keys = st.lab_keys or {}
            st.lab_keys[l.key] = (st.lab_keys[l.key] or 0) + 1
            st.lab[id] = nil
          end
        end
      end
      -- Fin de manche : bilan des tournées, ennemis retirés.
      if in_round == ROUND - 30 then
        for _, tr in ipairs(cur.trips) do
          local entered, worst = false, 1e9
          for i, m in ipairs(tr.cluster or {}) do
            local dd = tr.min[i] or 1e9
            if dd < m.r then entered = true end
            worst = math.min(worst, dd - m.r)
          end
          tr.entered = entered
          tr.worst = worst
          -- Critère C2 : zone fixe jamais entrée, ou première réaction (arrêt, détour, demi-tour) AVANT d'y entrer et hors de
          -- portée ; « traverse » : entrée dans la zone APRÈS avoir réagi (zone vue occupée).
          local zone_in = tr.first_in ~= nil
          local r1 = tr.reacts[1]
          tr.react_before = r1 ~= nil and r1.margin > 0 and (not tr.first_in or r1.t < tr.first_in)
          tr.c2 = (not zone_in) or tr.react_before
          tr.cross = zone_in and r1 ~= nil and r1.t < tr.first_in
          local zmin = 1e9
          for i, m in ipairs(tr.cluster or {}) do zmin = math.min(zmin, ((tr.smin or {})[i] or 1e9) - m.r) end
          local L = 0
          for i = 2, #tr.out do L = L + math.sqrt(d2(tr.out[i - 1], tr.out[i])) end
          tr.len = L
          tr.direct = math.sqrt(d2(tr.start, tr.goal))
          local rl = {}
          for _, x in ipairs(tr.reacts) do rl[#rl + 1] = string.format("%s@%d(%+.0f)", x.l, x.t, x.margin) end
          ctx.log(string.format("manche %d couloir %d PNJ %d %s : %s, marge min %+.1f (zone fixe %+.1f, %s), aller %.0f / %.0f tuiles%s, reactions %s",
            r, tr.k, tr.id, tr.cluster and (CLUSTERS[tr.kind].name .. (tr.met and "" or " (jamais rencontres)")) or "-", tr.cluster and (entered and "ENTRE a portee" or "jamais a portee") or "sans ennemi",
            worst < 1e8 and worst or 0, zmin < 1e8 and zmin or 0, tr.c2 and "C2 tenu" or "C2 MANQUE", L, tr.direct,
            tr.outdone and "" or " (but non atteint)", #rl > 0 and table.concat(rl, " ") or "aucune"))
          if tr.cluster then destroy_cluster(s, tr.cluster) end
          st.trips[#st.trips + 1] = { r = r, k = tr.k, id = tr.id, entered = tr.entered, dead = tr.dead, reacts = #tr.reacts,
            enemies = tr.cluster ~= nil, met = tr.met or false, c2 = tr.c2, cross = tr.cross, outdone = tr.outdone, len = tr.len, direct = tr.direct, out = tr.out,
            start = tr.start, goal = tr.goal, kind = tr.kind }
        end
        st.cur = nil
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local stv = ctx.remote("fo-ia3k", "status", "player")
      if stv then
        local acts = {}
        for _, k in ipairs({ "detour", "stop", "back", "flee", "engage" }) do acts[#acts + 1] = k .. "=" .. tostring(stv.stats.actions[k] or 0) end
        ctx.log(string.format("FAIT mod : regards %d, itineraires %d (A* %d, variation %d, bloques %d), actions %s, morts marquees %d, etiquettes %d",
          stv.stats.looks, stv.stats.plans, stv.stats.astar, stv.stats.via, stv.stats.blocked, table.concat(acts, " "),
          stv.stats.deaths, (function() local n = 0 for _, v in pairs(stv.stats.labels) do n = n + v end return n end)()))
      end
      -- Tournées qui ont RENCONTRÉ des ennemis à leur poste (à moins de leur portée + 30 tuiles) : celles du critère.
      local n, ok, dead, reacted, posed, c2, cross = 0, 0, 0, 0, 0, 0, 0
      for _, tr in ipairs(st.trips) do
        if tr.enemies then posed = posed + 1 end
        if tr.enemies and tr.met then
          n = n + 1
          if not tr.entered then ok = ok + 1 end
          if tr.c2 then c2 = c2 + 1 end
          if tr.cross then cross = cross + 1 end
          if tr.dead then dead = dead + 1 end
          if tr.reacts > 0 then reacted = reacted + 1 end
        end
      end
      if mode == "route" then
        local pct = n > 0 and math.floor(100 * ok / n + 0.5) or 0
        ctx.log(string.format("FAIT %d tournees avec ennemis poses, %d les ont rencontres : C2 (arret ou detour avant la zone de portee) %d, entrees dans une zone vue occupee %d ; jamais a portee des ennemis a leur poste (plus strict) %d (%d %%), %d avec reaction visible, %d PNJ tues",
          posed, n, c2, cross, ok, pct, reacted, dead))
        ctx.check(n >= 16, "au moins 16 tournees ont rencontre des ennemis poses sur leur route", n)
        if opts.temoin then
          ctx.check(true, string.format("temoin (sans le lot) : C2 %d / %d, jamais a portee %d %%, %d tues (mesure)", c2, n, pct, dead))
        else
          ctx.check(n > 0 and c2 * 10 >= n * 9, "C2 : >= 90 % des PNJ changent de route ou s'arretent avant d'entrer a portee",
            string.format("%d / %d", c2, n))
          ctx.check(cross == 0, "C2 : aucun PNJ n'entre dans une zone vue occupee", cross)
          ctx.check(reacted * 10 >= n * 9, "C2 : une reaction visible (alerte, detour, demi-tour) dans >= 90 % des tournees qui les rencontrent",
            string.format("%d / %d", reacted, n))
          local keys = {}
          for k, v in pairs(st.lab_keys or {}) do keys[#keys + 1] = k .. "=" .. v end
          table.sort(keys)
          ctx.check(st.labels_seen > 0 and st.labels_ttl == st.labels_seen, "D1 : etats visibles au-dessus des PNJ, chacun >= 2 s",
            string.format("%d etats vus en entier, %d a >= 120 ticks (%s)", st.labels_seen, st.labels_ttl, table.concat(keys, " ")))
        end
      else
        -- Variété (C1) : allers successifs d'un même couloir.
        local by = {}
        for _, tr in ipairs(st.trips) do
          by[tr.k] = by[tr.k] or {}
          by[tr.k][#by[tr.k] + 1] = tr
        end
        local pairs_n, wide, long_ok, meds = 0, 0, 0, {}
        local trips_n = 0
        for k = 1, #LANES do
          local list = by[k] or {}
          for i, tr in ipairs(list) do
            if tr.outdone then
              trips_n = trips_n + 1
              if tr.len <= 1.15 * tr.direct + 6 then long_ok = long_ok + 1 end
            end
            local prev = list[i - 1]
            if prev and prev.outdone and tr.outdone then
              local G = tr.goal
              local m = median_gap(tr.start, G, prev.out, tr.out)
              pairs_n = pairs_n + 1
              if m >= 4 then wide = wide + 1 end
              meds[#meds + 1] = string.format("%.1f", m)
            end
          end
        end
        ctx.log(string.format("FAIT C1 : %d paires d'allers successifs, ecart median >= 4 tuiles dans %d ; ecarts : %s ; %d allers sur %d allonges de <= 15 %%",
          pairs_n, wide, table.concat(meds, " "), long_ok, trips_n))
        ctx.check(pairs_n >= 12, "au moins 12 paires d'allers mesurees", pairs_n)
        if opts.temoin then
          ctx.check(true, string.format("temoin (sans le lot) : ecart >= 4 tuiles dans %d paires sur %d (mesure)", wide, pairs_n))
        else
          ctx.check(pairs_n > 0 and wide * 2 >= pairs_n, "C1 : ecart lateral median >= 4 tuiles dans >= 50 % des paires",
            string.format("%d / %d", wide, pairs_n))
          ctx.check(trips_n > 0 and long_ok == trips_n, "C1 : aucun aller allonge de plus de 15 %", string.format("%d / %d", long_ok, trips_n))
        end
      end
    end,
  }
end

return C
