-- Scénario greffé du lot RB-0 (31/10), essai E3 : `spider-vehicle` SANS conducteur d'une force de faction (PLAN.md §3).
-- À LANCER SUR LA COPIE JETABLE : banc.py ... --qui RB0 -- 2500 rb0-geant <copie>
--
-- Force « rb0 » (en guerre avec « enemy »), jamais de joueur ni de conducteur.
-- (a) TIR AUTOMATIQUE : rb0-spider-1 (4 lance-roquettes vanilla) ; cible = tourelle ennemie SANS munitions à 25 tuiles.
--     a1 vehicle_automatic_targeting_parameters = {sans = vrai, avec = vrai}, 20 roquettes mises par script ;
--     a2 paramètres NON TOUCHÉS (valeur lue au journal), mêmes munitions ; a3 sans = faux ; a4 sans munitions.
-- (b) MARCHE EN LIGNE DROITE (add_autopilot_destination, 60 tuiles vers l'est) : sol libre, eau de 6, 30 tuiles,
--     mur de pierre de 3 rangées, forêt de 20 tuiles, barrière de falaises.
-- (c) CHEMIN PAR SCRIPT : request_path (boîte ±1, masque water-tile) autour d'un fleuve, puis points de passage
--     poussés dans l'autopilote ; comparé à la ligne droite à travers le fleuve.
-- Mesures : tick du premier dégât, roquettes restantes, tick de on_spider_command_completed, position finale,
-- ticks passés AU-DESSUS d'une tuile d'eau (centre du corps).

local C = require("scenarios/rb0_common")

local T0 = 60
local CHECK = 2450
local AX, AY = 4000, 4000      -- site (a)
local BX, BY = 4000, 4200      -- sites (b)
local CX, CY = 4000, 4600      -- site (c)
local S = "rb0-spider-1"

script.on_event(defines.events.on_spider_command_completed, function(e)
  local g = C.g()
  local v = e.vehicle
  if v and v.valid and g.spiders and g.spiders[v.unit_number] then
    local r = g.spiders[v.unit_number]
    r.fini = r.fini or e.tick
    r.n_fini = (r.n_fini or 0) + 1
  end
end)

script.on_event(defines.events.on_script_path_request_finished, function(e)
  local g = C.g()
  if g.requetes and g.requetes[e.id] then
    local n = e.path and #e.path or 0
    g.requetes[e.id].rep = { tick = e.tick, n = n, retry = e.try_again_later, path = e.path }
  end
end)

script.on_event(defines.events.on_entity_died, function(e)
  local en = e.entity
  if en and en.valid and en.name:sub(1, 11) == "rb0-spider-" then
    log(string.format("[FO-RB0-GEANT] MORT %s tick=%d position=%.1f,%.1f cause=%s force_cause=%s", en.name, e.tick, en.position.x, en.position.y,
      e.cause and e.cause.valid and e.cause.name or "aucune", tostring(e.force and e.force.name)))
  end
end)

local function sur_eau(s, p)
  local t = s.get_tile(math.floor(p.x), math.floor(p.y))
  return t.valid and t.collides_with("water-tile")
end

return {
  description = "RB-0 E3 : spider-vehicle sans conducteur : tir auto, marche (eau, mur, foret, falaise), chemin par script",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    st.pret = false
    if not C.exige(ctx, { S }, "rb0-spider-1") then return end
    local s = ctx.surface()
    C.force("rb0")
    game.map_settings.enemy_expansion.enabled = false
    ctx.prepare_area(AX - 20, AY - 20, AX + 140, AY + 140, "grass-1")
    ctx.prepare_area(BX - 20, BY - 20, BX + 140, BY + 330, "grass-1")
    ctx.prepare_area(CX - 20, CY - 70, CX + 140, CY + 90, "grass-1")
    C.sans_ennemis(s, AX - 40, AY - 40, AX + 160, CY + 120)
    local proto = game.entity_prototypes[S]
    ctx.log(string.format("prototype %s : collision_box=%s selection_box=%s military_target=%s is_military_target(proto)=%s",
      S, serpent.line(proto.collision_box), serpent.line(proto.selection_box), "voir entite", tostring(proto.is_military_target)))
    local g = C.g()
    g.spiders, g.requetes = {}, {}
    st.a, st.b, st.c = {}, {}, {}

    -- (a) tir automatique
    local variantes = {
      { id = "a1", params = { auto_target_without_gunner = true, auto_target_with_gunner = true }, ammo = 20 },
      { id = "a2", params = nil, ammo = 20 },
      { id = "a3", params = { auto_target_without_gunner = false, auto_target_with_gunner = true }, ammo = 20 },
      { id = "a4", params = { auto_target_without_gunner = true, auto_target_with_gunner = true }, ammo = 0 },
    }
    for i, v in ipairs(variantes) do
      local y = AY + 30 * (i - 1)
      local sp = s.create_entity({ name = S, position = { AX, y }, force = "rb0" })
      local r = { id = v.id, e = sp, x = AX, y = y }
      if sp then
        g.spiders[sp.unit_number] = r
        r.defaut = serpent.line(sp.vehicle_automatic_targeting_parameters)
        r.mil = tostring(sp.is_military_target)
        if v.params then sp.vehicle_automatic_targeting_parameters = v.params end
        r.params = serpent.line(sp.vehicle_automatic_targeting_parameters)
        local inv = sp.get_inventory(defines.inventory.spider_ammo)
        r.inv_taille = inv and #inv or -1
        r.ammo_ins = v.ammo > 0 and inv and inv.insert({ name = "rocket", count = v.ammo }) or 0
      end
      r.cible = s.create_entity({ name = "gun-turret", position = { AX + 25, y }, force = "enemy" })
      r.pv0 = r.cible and r.cible.health
      st.a[#st.a + 1] = r
    end

    -- (b) marche en ligne droite
    local obst = {
      { id = "b1-libre" },
      { id = "b2-eau6", eau = 6 },
      { id = "b3-eau30", eau = 30 },
      { id = "b4-mur3", mur = 3 },
      { id = "b5-foret", foret = true },
      { id = "b6-falaise", falaise = true },
    }
    local rng = game.create_random_generator(31102026)
    for i, o in ipairs(obst) do
      local y = BY + 50 * (i - 1)
      local x1 = BX + 20
      if o.eau then C.eau(s, x1, y - 40, x1 + o.eau, y + 40, "deepwater") end
      if o.mur then
        for dx = 0, o.mur - 1 do
          for dy = -20, 20 do s.create_entity({ name = "stone-wall", position = { x1 + dx + 0.5, y + dy + 0.5 }, force = "player" }) end
        end
      end
      if o.foret then
        for _ = 1, 160 do
          s.create_entity({ name = "tree-02", position = { x1 + rng(20) - 0.5, y - 10 + rng(20) - 0.5 } })
        end
      end
      if o.falaise then
        local ok = 0
        for k = -6, 6 do
          if s.create_entity({ name = "cliff", position = { x1 + 5, y + 4 * k }, cliff_orientation = "north-to-south" }) then ok = ok + 1 end
        end
        o.falaises_posees = ok
      end
      local sp = s.create_entity({ name = S, position = { BX, y }, force = "rb0" })
      local r = { id = o.id, e = sp, x = BX, y = y, but = { BX + 60, y }, sur_eau = 0, max_x = BX }
      if sp then
        g.spiders[sp.unit_number] = r
      end
      r.o = o
      st.b[#st.b + 1] = r
    end

    -- (c) fleuve de 10 tuiles de large, de y-40 à y+20, terre ferme au sud (y+20 à y+40)
    local rc = {}
    for k = 1, 2 do
      local y = CY + (k - 1) * 0
      local x0 = CX + (k - 1) * 0
      local sp = nil
      rc[k] = { id = k == 1 and "c1-chemin" or "c2-droit", sur_eau = 0 }
    end
    C.eau(s, CX + 20, CY - 45, CX + 30, CY + 20, "deepwater")
    -- deux spiders côte à côte : y = CY (chemin) et y = CY - 10 (ligne droite), même fleuve, buts à x + 50
    local c1 = s.create_entity({ name = S, position = { CX, CY }, force = "rb0" })
    local c2 = s.create_entity({ name = S, position = { CX, CY - 10 }, force = "rb0" })
    rc[1].e, rc[1].but = c1, { CX + 50, CY }
    rc[2].e, rc[2].but = c2, { CX + 50, CY - 10 }
    for k = 1, 2 do
      rc[k].x, rc[k].y = rc[k].e and rc[k].e.position.x, rc[k].e and rc[k].e.position.y
      if rc[k].e then g.spiders[rc[k].e.unit_number] = rc[k] end
      st.c[#st.c + 1] = rc[k]
    end
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local s = ctx.surface()
    local g = C.g()
    local t = e.tick
    if t == T0 then
      for _, r in ipairs(st.b) do
        if r.e and r.e.valid then
          r.e.add_autopilot_destination({ x = r.but[1], y = r.but[2] })
        end
      end
      if st.c[2].e and st.c[2].e.valid then
        st.c[2].e.add_autopilot_destination({ x = st.c[2].but[1], y = st.c[2].but[2] })
      end
      -- (c1) demande de chemin
      local c1 = st.c[1]
      if c1.e and c1.e.valid then
        local id = s.request_path({ bounding_box = { { -1, -1 }, { 1, 1 } }, collision_mask = { "water-tile" },
          start = c1.e.position, goal = { x = c1.but[1], y = c1.but[2] }, force = "rb0", radius = 2,
          pathfind_flags = { cache = false } })
        g.requetes[id] = c1
        c1.req = id
        c1.t_req = t
      end
    end
    -- (c1) points de passage une fois le chemin reçu
    local c1 = st.c[1]
    if c1.req and not c1.queued and g.requetes[c1.req] and g.requetes[c1.req].rep then
      local rep = g.requetes[c1.req].rep
      c1.t_rep = rep.tick
      c1.n_path = rep.n
      c1.retry = rep.retry
      if rep.n > 0 and c1.e and c1.e.valid then
        local pas = 6
        local ajoutes = 0
        for i = pas, rep.n, pas do
          c1.e.add_autopilot_destination(rep.path[i].position)
          ajoutes = ajoutes + 1
        end
        c1.e.add_autopilot_destination(rep.path[rep.n].position)
        c1.ajoutes = ajoutes + 1
        local xs, ys = {}, {}
        for i = 1, rep.n, 12 do xs[#xs + 1] = string.format("%.0f,%.0f", rep.path[i].position.x - CX, rep.path[i].position.y - CY) end
        c1.apercu = table.concat(xs, " ")
        c1.max_y_chemin = -1e9
        for i = 1, rep.n do if rep.path[i].position.y > c1.max_y_chemin then c1.max_y_chemin = rep.path[i].position.y end end
      end
      c1.queued = true
    end
    -- trace de la position des deux araignées du site (c) toutes les 25 ticks
    if t >= T0 and (t - T0) % 25 == 0 and t <= T0 + 400 then
      for _, r in ipairs(st.c) do
        if r.e and r.e.valid then
          r.trace = r.trace or {}
          r.trace[#r.trace + 1] = string.format("%d:%.0f,%.0f", t - T0, r.e.position.x - CX, r.e.position.y - CY)
        end
      end
    end
    -- échantillons
    if t >= T0 then
      for _, r in ipairs(st.b) do
        if r.e and r.e.valid then
          if r.e.position.x > r.max_x then r.max_x = r.e.position.x end
          if t % 10 == 0 and sur_eau(s, r.e.position) then r.sur_eau = r.sur_eau + 10 end
          if t == T0 + 300 or t == T0 + 600 then
            r["x" .. (t - T0)] = r.e.position.x
          end
        end
      end
      for _, r in ipairs(st.c) do
        if r.e and r.e.valid and t % 10 == 0 and sur_eau(s, r.e.position) then r.sur_eau = r.sur_eau + 10 end
      end
      for _, r in ipairs(st.a) do
        if r.e and r.e.valid and r.cible then
          if not r.t_degat and ((r.cible.valid and r.cible.health < r.pv0) or not r.cible.valid) then r.t_degat = t end
          if not r.t_mort and not r.cible.valid then r.t_mort = t end
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    -- (a)
    for _, r in ipairs(st.a) do
      local restant = -1
      if r.e and r.e.valid then
        local inv = r.e.get_inventory(defines.inventory.spider_ammo)
        restant = inv and inv.get_item_count("rocket") or -1
      end
      r.valide = r.e and r.e.valid
      ctx.log(string.format("E3a %s : defaut=%s ecrit=%s military=%s inv_ammo=%d cases, roquettes inserees=%s restantes=%d ; premier degat=%s mort cible=%s PV cible=%s ; araignee valide=%s pv=%s",
        r.id, tostring(r.defaut), tostring(r.params), tostring(r.mil), r.inv_taille or -1, tostring(r.ammo_ins), restant, tostring(r.t_degat and (r.t_degat - T0)),
        tostring(r.t_mort and (r.t_mort - T0)), r.cible and r.cible.valid and C.fmt(r.cible.health, 0) or "detruite", tostring(r.e and r.e.valid), r.e and r.e.valid and C.fmt(r.e.health, 0) or "-"))
    end
    local a1, a2, a3, a4 = st.a[1], st.a[2], st.a[3], st.a[4]
    ctx.check(a1.t_degat ~= nil, "E3 (a1) spider sans conducteur, auto_target_without_gunner = vrai : tire sur la tourelle ennemie",
      tostring(a1.t_degat and (a1.t_degat - T0)))
    ctx.log("E3 (a2) parametres par defaut : tir " .. (a2.t_degat and "OUI" or "NON") .. " ; (a3) sans = faux : tir " ..
      (a3.t_degat and "OUI" or "NON") .. " ; (a4) sans munitions : tir " .. (a4.t_degat and "OUI" or "NON"))
    ctx.check(a4.t_degat == nil, "E3 (a4) sans munitions : aucun tir", tostring(a4.t_degat))
    -- (b)
    for _, r in ipairs(st.b) do
      if r.e and r.e.valid then
        local d = C.dist(r.e.position, { x = r.but[1], y = r.but[2] })
        ctx.log(string.format("E3b %-11s : x300=%s x600=%s max_x=%.1f fin=%s distance_but=%.1f fini(tick)=%s ticks_sur_eau=%d falaises=%s",
          r.id, C.fmt(r.x300, 1), C.fmt(r.x600, 1), r.max_x, C.pos(r.e.position), d, tostring(r.fini and (r.fini - T0)), r.sur_eau, tostring(r.o.falaises_posees)))
      else
        ctx.log("E3b " .. r.id .. " : spider detruit ou absent")
      end
    end
    ctx.check(st.b[1].fini ~= nil, "E3 (b1) sol libre : arrive (on_spider_command_completed)", tostring(st.b[1].fini and (st.b[1].fini - T0)))
    -- (c)
    local c1, c2 = st.c[1], st.c[2]
    ctx.log(string.format("E3c chemin : demande tick %d, reponse tick %s (%s ticks), %s point(s), retry=%s, %s points pousses, y max du chemin=%s",
      c1.t_req or -1, tostring(c1.t_rep), tostring(c1.t_rep and (c1.t_rep - c1.t_req)), tostring(c1.n_path), tostring(c1.retry), tostring(c1.ajoutes), C.fmt(c1.max_y_chemin, 1)))
    for _, r in ipairs({ c1, c2 }) do
      if r.e and r.e.valid then
        ctx.log("E3c trace " .. r.id .. " (tick:dx,dy) " .. table.concat(r.trace or {}, " "))
        ctx.log(string.format("E3c %-9s : fin=%s distance_but=%.1f fini(tick)=%s n_fini=%s ticks_sur_eau=%d", r.id, C.pos(r.e.position),
          C.dist(r.e.position, { x = r.but[1], y = r.but[2] }), tostring(r.fini and (r.fini - T0)), tostring(r.n_fini), r.sur_eau))
      end
    end
    ctx.log("E3c apercu du chemin (1 point sur 12, dx,dy depuis le depart) : " .. tostring(c1.apercu))
    ctx.check(c1.n_path ~= nil and c1.n_path > 0, "E3 (c) request_path rend un chemin pour une boite de spider autour d'un fleuve", tostring(c1.n_path))
  end,
}
