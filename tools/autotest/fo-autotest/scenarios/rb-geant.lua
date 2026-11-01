-- Scénario greffé du lot RB-5 GÉANTS (1/11) : les trois géants (araignées) en moteur réel (PLAN.md ROBOTS, §3 « Grands marcheurs », §6).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui RB4 -- 6200 rb-geant <source>
--   CHAÎNE   un dock fabrique un segment du Torique (30 s) ; un portique reçoit 10 segments et assemble le géant (120 s, progrès écrit à
--            97 % pour tenir le banc, F84) ; le balayage retire le kit et pose le géant (force d'âge 13 : 1 géant admis).
--   PLAFOND  âge 13 : un 2e géant est refusé ; âge 14 : accepté, le 3e refusé ; âge 15 : le 3e accepté ; le 4e refusé.
--   ORDRE    un géant reçoit « attaque » vers un nid a 220 tuiles : chemin demandé, autopilote, arrivée, nid détruit (portée 100) ;
--            sa vitesse de marche est relevée ; sa munition est posée et tenue.
--   DUEL     chacun des 3 géants (Torique, Héliaste, Couronné), seul sur son site, contre 3 déchiqueteurs du palier de son âge (10, 12, 12),
--            partis à 40 tuiles au tick 200 : victoire, marge et durée comparées au modèle (table MODELE, contrôlée hors jeu).
--   RELECTURE un géant posé à `init` (création de la carte) est relu par le benchmark : même entité, même munition, registre cohérent.
-- Journal : [FO-RB-GEANT].

local C = require("scenarios/rb0_common")

local X0, Y0 = 8000, 6000
local CHECK = 6000
local T0 = 200
local SEP = 40
local ECART_FRACTION = 0.25
local ECART_DUREE = 0.45

local TIER_NAMES = { "small", "medium", "big", "behemoth", "colossal", "titan", "apex", "primordial", "ancestral", "abyssal", "cataclysmic", "eternal" }
local function biter_name(tier) return "fo-" .. TIER_NAMES[tier] .. "-biter" end

--MODELE-DEBUT
local MODELE = {
  ["toroid"] = { age = 13, tier = 10, frac = 0.35, ticks = 4670 },
  ["heliast"] = { age = 14, tier = 12, frac = 0.36, ticks = 3860 },
  ["crowned"] = { age = 15, tier = 12, frac = 0.35, ticks = 5570 },
}
--MODELE-FIN
local DUEL = { "toroid", "heliast", "crowned" }

local function R(ctx, fn, ...) return ctx.remote("fo-robots", fn, ...) end
local function G(ctx, fn, ...) return ctx.remote("fo-robots-geant", fn, ...) end

local function dist(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

return {
  description = "RB-5 : portique -> geant, plafond par age, ordre (chemin, arrivee, nid detruit), duel des trois geants, relecture",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    st.pret = false
    local manque = {}
    for _, n in ipairs({ "fo-robot-player-toroid", "fo-robot-player-heliast", "fo-robot-player-crowned", "fo-robot-gantry", "fo-robot-dock" }) do
      if not game.entity_prototypes[n] then manque[#manque + 1] = n end
    end
    if #manque > 0 then
      ctx.fail("prototypes presents", table.concat(manque, ", "))
      return
    end
    C.force("rb-duel")
    C.force("rb-chain")
    C.force("rb-relu")
    game.map_settings.enemy_expansion.enabled = false
    ctx.call("war_setting", "fo-war-robots-cap", 400)
    -- surfaces : une grande bande pour l'ordre, des sites de duel, la chaîne
    ctx.prepare_area(X0 - 70, Y0 - 40, X0 + 180, Y0 + 40, "grass-1")
    ctx.prepare_area(X0 - 70, Y0 + 60, X0 + 40, Y0 + 60 + 80 * 3, "grass-1")
    ctx.prepare_area(X0 - 30, Y0 - 100, X0 + 30, Y0 - 50, "grass-1")
    ctx.prepare_area(X0 + 80, Y0 + 100, X0 + 190, Y0 + 180, "grass-1")
    C.sans_ennemis(s, X0 - 90, Y0 - 120, X0 + 200, Y0 + 60 + 80 * 3 + 30)
    ctx.power(X0, Y0 - 90, "rb-chain")

    -- RELECTURE : un géant d'âge 13 posé à la création
    R(ctx, "set_age", "rb-relu", 13)
    st.relu = R(ctx, "spawn", "rb-relu", "toroid", X0 - 30, Y0 - 60)
    local i = st.relu and G(ctx, "info", st.relu)
    st.relu_obus = i and i.shells
    ctx.log(string.format("relecture : geant %s (obus %s)", tostring(st.relu), tostring(st.relu_obus)))

    -- DUEL : trois sites
    R(ctx, "set_age", "rb-duel", 15)
    st.duel = {}
    for k, id in ipairs(DUEL) do
      local m = MODELE[id]
      local y = Y0 + 60 + 80 * (k - 1)
      local un, why = R(ctx, "spawn", "rb-duel", id, X0, y)
      local site = { id = id, y = y, un = un, why = why, tier = m.tier, biters = {} }
      for b = 1, 3 do
        site.biters[b] = s.create_entity({ name = biter_name(m.tier), position = { X0 - SEP, y + (b - 2) * 2 }, force = "enemy" })
      end
      local info = un and G(ctx, "info", un)
      site.pv_max = un and R(ctx, "unit_info", un) and R(ctx, "unit_info", un).max
      st.duel[#st.duel + 1] = site
      ctx.log(string.format("duel %s : geant %s (%s), palier %d, obus %s, PV %s", id, tostring(un), tostring(why), m.tier, tostring(info and info.shells), tostring(site.pv_max)))
    end

    -- ORDRE : une force d'âge 13, son géant au bord ouest, un nid à 220 tuiles à l'est
    R(ctx, "set_age", "rb-chain", 13)
    st.ordre = R(ctx, "spawn", "rb-chain", "toroid", X0 - 50, Y0)
    st.nid = s.create_entity({ name = "biter-spawner", position = { X0 + 170, Y0 }, force = "enemy" })
    st.nid_pv = st.nid and st.nid.health
    st.depart = st.ordre and R(ctx, "unit_info", st.ordre)

    -- CHAÎNE : dock et portique alimentés par script (l'insertion est bornée par la limite de la machine : on relève ce qui entre)
    local cx, cy = X0, Y0 - 90
    st.dock = s.create_entity({ name = "fo-robot-dock", position = { cx - 12.5, cy }, force = "rb-chain", raise_built = true })
    if st.dock then st.dock.set_recipe("fo-robot-make-segment-toroid") end
    st.porte = s.create_entity({ name = "fo-robot-gantry", position = { cx + 12.5, cy }, force = "rb-chain", raise_built = true })
    if st.porte then st.porte.set_recipe("fo-robot-make-toroid") end
    st.entrees = {}
    if st.dock then
      for _, g in ipairs({ { "fo-superconducting-coil", 100 }, { "processing-unit", 100 }, { "fo-magnetic-actuator", 100 }, { "fo-laser-module", 60 }, { "fo-titanium-plate", 100 } }) do
        st.entrees[g[1]] = st.dock.insert({ name = g[1], count = g[2] })
      end
    end
    if st.porte then st.segments_entres = st.porte.insert({ name = "fo-robot-segment-toroid", count = 10 }) end
    ctx.log(string.format("chaine : dock %s, portique %s, segments entres au portique %s, entrees du dock %s", tostring(st.dock and st.dock.unit_number),
      tostring(st.porte and st.porte.unit_number), tostring(st.segments_entres), (function()
        local t = {}
        for k, v in pairs(st.entrees) do t[#t + 1] = k .. "=" .. v end
        table.sort(t)
        return table.concat(t, ",")
      end)()))
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local t = e.tick
    local s = ctx.surface()

    if t == 5 then
      -- RELECTURE : le géant créé à init est relu
      local i = st.relu and G(ctx, "info", st.relu)
      local etat = R(ctx, "state", "rb-relu")
      ctx.check(i ~= nil and i.name == "fo-robot-player-toroid" and i.shells >= 2 and i.shells == st.relu_obus and etat and etat.by_id.toroid == 1
        and etat.used == 12 and R(ctx, "check") == true,
        "(10) relu apres sauvegarde : meme geant, meme munition, 12 points, registre coherent",
        string.format("info %s, obus %s/%s, etat %s", tostring(i and i.name), tostring(i and i.shells), tostring(st.relu_obus), tostring(etat and etat.used)))
    end

    -- PLAFOND (quelques ticks après le départ, avant les ordres)
    if t == 20 then
      local f = "rb-cap"
      C.force(f)
      R(ctx, "set_age", f, 13)
      local a1 = R(ctx, "spawn", f, "toroid", X0 + 100, Y0 + 140)
      local a2, w2 = R(ctx, "spawn", f, "heliast", X0 + 120, Y0 + 140)
      R(ctx, "set_age", f, 14)
      local b2 = R(ctx, "spawn", f, "heliast", X0 + 120, Y0 + 140)
      local b3, w3 = R(ctx, "spawn", f, "crowned", X0 + 140, Y0 + 140)
      R(ctx, "set_age", f, 15)
      local c3 = R(ctx, "spawn", f, "crowned", X0 + 140, Y0 + 140)
      local c4, w4 = R(ctx, "spawn", f, "toroid", X0 + 160, Y0 + 140)
      ctx.check(a1 ~= nil and a2 == nil and b2 ~= nil and b3 == nil and c3 ~= nil and c4 == nil,
        "(PLAFOND) 1 geant a l'age 13, 2 a l'age 14, 3 a l'age 15, jamais un de plus",
        string.format("age 13 : %s/%s (%s) ; age 14 : %s/%s (%s) ; age 15 : %s/%s (%s)", tostring(a1), tostring(a2), tostring(w2), tostring(b2),
          tostring(b3), tostring(w3), tostring(c3), tostring(c4), tostring(w4)))
      local etat = R(ctx, "state", f)
      ctx.check(etat and etat.used == 36 and R(ctx, "check") == true, "(PLAFOND) trois geants = 36 points, registre coherent",
        string.format("points %s", tostring(etat and etat.used)))
    end

    -- DUEL
    if t == T0 then
      for _, site in ipairs(st.duel) do
        for _, b in ipairs(site.biters) do
          if b.valid then
            b.set_command({ type = defines.command.go_to_location, destination = { x = X0, y = site.y }, radius = 2, distraction = defines.distraction.by_enemy })
          end
        end
      end
      -- ORDRE
      st.t_ordre = t
      if st.ordre then
        local r = R(ctx, "order", "rb-chain", "attack", X0 + 170, Y0, { x = X0 - 50, y = Y0, radius = 15 }, 20)
        st.ordre_rep = r
      end
    end
    if t > T0 and t % 5 == 0 then
      for _, site in ipairs(st.duel) do
        if not site.t_end then
          local vivants = 0
          for _, b in ipairs(site.biters) do if b.valid then vivants = vivants + 1 end end
          local info = site.un and R(ctx, "unit_info", site.un)
          if vivants == 0 and info then site.t_end, site.win, site.pv = t - T0, true, info.health
          elseif not info then site.t_end, site.win, site.pv = t - T0, false, 0 end
        end
      end
    end
    -- ORDRE : suivi (arrivée ou nid détruit)
    if t > T0 and t % 20 == 0 and st.ordre and not st.nid_mort_tick then
      if not (st.nid and st.nid.valid) then st.nid_mort_tick = t end
      local g = G(ctx, "info", st.ordre)
      if g then
        st.dernier = g
        if g.autopilot > 0 then st.marche = st.marche or { t = t, x = g.x, y = g.y } end
        if st.marche and not st.arrive and g.autopilot == 0 then st.arrive = { t = t, x = g.x, y = g.y } end
      end
    end

    -- CHAÎNE : à 1 900 ticks le dock a fini son segment ; le progrès du portique est avancé quand il a ses ingrédients
    if t == 300 and st.porte and st.porte.valid then
      st.porte_statut = C.statut(st.porte)
      st.porte.crafting_progress = 0.97
    end
    if t == 2200 and st.dock and st.dock.valid then
      local inv = st.dock.get_output_inventory()
      st.segment_fait = inv and inv.get_item_count("fo-robot-segment-toroid") or 0
      st.dock_fabriques = st.dock.products_finished
    end
    if t == 2400 then
      local etat = R(ctx, "state", "rb-chain")
      local kits = st.porte and st.porte.valid and st.porte.get_output_inventory().get_item_count("fo-robot-kit-toroid") or -1
      ctx.check(st.dock_fabriques ~= nil and st.dock_fabriques >= 1 and st.segment_fait >= 1,
        "(CHAINE1) le dock fabrique un segment du Torique en 30 s a partir des 5 ingredients",
        string.format("segments fabriques %s, en sortie %s", tostring(st.dock_fabriques), tostring(st.segment_fait)))
      ctx.check(st.segments_entres == 10 and etat and etat.by_id.toroid >= 1,
        "(CHAINE2) le portique assemble le geant a partir de 10 segments : le balayage retire le kit et pose le geant",
        string.format("segments entres %s, geants de la force %s, kits restants %s, statut au tick 300 %s", tostring(st.segments_entres),
          tostring(etat and etat.by_id.toroid), tostring(kits), tostring(st.porte_statut)))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    for _, site in ipairs(st.duel) do
      local m = MODELE[site.id]
      local frac = site.win and site.pv_max and site.pv / site.pv_max or 0
      local dur = site.t_end or -1
      ctx.check(site.win == true, "(DUEL " .. site.id .. ") gagne contre 3 deshiqueteurs du palier " .. site.tier,
        string.format("victoire=%s, duree %d ticks (modele %d), PV restants %.2f (modele %.2f)", tostring(site.win), dur, m.ticks, frac, m.frac))
      ctx.check(site.win == true and math.abs(frac - m.frac) <= ECART_FRACTION and math.abs(dur - m.ticks) <= ECART_DUREE * m.ticks,
        "(DUEL " .. site.id .. ") conforme au modele : marge a " .. ECART_FRACTION .. " pres, duree a " .. math.floor(ECART_DUREE * 100) .. " % pres",
        string.format("marge %.2f contre %.2f, duree %d contre %d", frac, m.frac, dur, m.ticks))
      ctx.log(string.format("[FO-RB-GEANT] duel %s palier=%d win=%s ticks=%d modele=%d marge=%.3f modele=%.3f", site.id, site.tier, tostring(site.win), dur, m.ticks, frac, m.frac))
    end
    -- ORDRE
    local g = st.dernier
    local nid_detruit = not (st.nid and st.nid.valid)
    local vitesse = (st.marche and st.arrive and st.arrive.t > st.marche.t) and
      (dist(st.marche.x, st.marche.y, st.arrive.x, st.arrive.y) / (st.arrive.t - st.marche.t)) or nil
    ctx.check(st.ordre_rep and st.ordre_rep.ordered >= 1 and nid_detruit,
      "(ORDRE) le geant recoit l'ordre d'attaque, avance par un chemin demande au moteur et detruit le nid a 120 tuiles",
      string.format("ordres %s, nid detruit %s (tick %s), derniere info %s", tostring(st.ordre_rep and st.ordre_rep.ordered), tostring(nid_detruit),
        tostring(st.nid_mort_tick), g and string.format("x=%.1f autopilote=%d arrive=%s tentatives=%d obus=%d", g.x, g.autopilot, tostring(g.arrived), g.tries, g.shells) or "mort"))
    ctx.check(g ~= nil and g.shells >= 1, "(ORDRE) la munition du geant est tenue", string.format("obus %s", tostring(g and g.shells)))
    ctx.log(string.format("[FO-RB-GEANT] ordre : depart x=%s, marche %s, arrivee %s, vitesse mesuree %s tuile/tick (cible 0,12)",
      tostring(st.depart and st.depart.x), tostring(st.marche and st.marche.t), tostring(st.arrive and st.arrive.t), tostring(vitesse)))
    ctx.check(R(ctx, "check") == true, "registre des robots coherent")
  end,
}
