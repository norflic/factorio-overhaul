-- Lot EXPERIMENTAUX (3/11), palier 3, 2 500 ticks, sans images : les 5 géants en moteur réel.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui EXPERIMENTAUX -- 2500 xp-geants <source>
-- Pour chacun, sur sa propre force (âge fixé à 15 par l'interface « fo-robots », set_age) :
--   (a) la technologie débloque segment et assemblage ; le Dock FABRIQUE un segment ; l'usine de son âge ASSEMBLE le géant
--       (10 segments insérés ; modules de vitesse dans les deux usines pour tenir dans le banc) ;
--   (b) posé (create_entity raise_built), il frappe des cibles hostiles qui ne tirent pas : dégâts du script ET PV perdus relevés ici ;
--       un témoin de SA force au milieu des cibles reste intact ;
--   Trombe : pendant le gel, une cible est arrêtée (active = false), puis rendue ou détruite ; Tournesol : rien de nuit (ticks 1 à 700), tire de jour.
-- Plafond : la force du joueur à l'âge 10 (plafond 1) : un premier Cairn posé, un second REFUSÉ (retiré, objet rendu au sol).
local C = require("scenarios/xp_commun")

local CHECK = 2450
local IDS = { "cairn", "stylet", "trombe", "ixion", "tournesol" }
local USINE = { cairn = "fo-robot-dock", stylet = "fo-robot-dock", trombe = "fo-robot-dock", ixion = "fo-robot-gantry", tournesol = "fo-robot-gantry" }
local NUIT_FIN = 700
local Y = 3600

local function gx(i) return 9000 + (i - 1) * 200 end

local function stats() return remote.call("fo-xp", "stats") end

local function vitesse(m)
  local inv = m and m.valid and m.get_module_inventory()
  if inv then inv.insert({ name = "speed-module-3", count = #inv }) end
end

return {
  description = "EXPERIMENTAUX : les 5 geants, fabrication, effets, plafond, nuit",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    C.forces()
    remote.call("fo-xp", "journal", true)
    local s = ctx.surface()
    s.freeze_daytime = true
    s.daytime = 0.5 -- nuit : le Tournesol ne doit pas tirer
    st.sites = {}
    local cible = game.forces[C.CIBLE]
    for i, id in ipairs(IDS) do
      local x = gx(i)
      ctx.prepare_area(x - 40, Y - 70, x + 80, Y + 80, "dry-dirt")
      for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { x - 100, Y - 120 }, { x + 140, Y + 140 } } })) do en.destroy() end
      local fname = "fo-xp-g-" .. id
      local f = game.forces[fname] or game.create_force(fname)
      cible.set_cease_fire(f, true)
      f.set_cease_fire(cible, false)
      game.forces.enemy.set_cease_fire(f, true)
      f.set_cease_fire(game.forces.enemy, true)
      remote.call("fo-robots", "set_age", fname, 15)
      local site = { id = id, x = x, force = fname, cibles = {}, maxs = {} }
      -- 12 cibles en grille à 22 tuiles à l'est, espacées de 4, plus 2 déchiqueteurs hostiles (Trombe : arrêtés par le gel)
      for gy = 0, 3 do
        for gxx = 0, 2 do
          local e = s.create_entity({ name = "gun-turret", position = { x + 22 + gxx * 4, Y - 6 + gy * 4 }, force = C.CIBLE })
          if e then site.cibles[#site.cibles + 1] = e end
        end
      end
      for k = 1, 2 do
        local b = s.create_entity({ name = "behemoth-biter", position = { x + 20, Y - 12 + k * 4 }, force = C.CIBLE })
        if b then
          b.set_command({ type = defines.command.wander, radius = 1, distraction = defines.distraction.none })
          site.cibles[#site.cibles + 1] = b
        end
      end
      for _, e in ipairs(site.cibles) do site.maxs[#site.maxs + 1] = e.prototype.max_health end
      site.temoin = s.create_entity({ name = "lab", position = { x + 26, Y + 12 }, force = fname })
      -- fabrication : technologie, segment au Dock, assemblage à l'usine de l'âge (10 segments insérés)
      local t = f.technologies["fo-xp-" .. id]
      if t then t.researched = true end
      local seg = f.recipes["fo-xp-make-segment-" .. id]
      local fin = f.recipes["fo-xp-make-" .. id]
      ctx.check(seg and fin and seg.enabled and fin.enabled, id .. " : la technologie debloque segment et assemblage")
      ctx.power(x - 20, Y + 50, fname)
      site.dock = s.create_entity({ name = "fo-robot-dock", position = { x, Y + 50 }, force = f })
      site.fin = s.create_entity({ name = USINE[id], position = { x + 30, Y + 50 }, force = f })
      vitesse(site.dock)
      vitesse(site.fin)
      if site.dock and seg then
        site.dock.set_recipe(seg.name)
        for _, g in ipairs(seg.ingredients) do site.dock.insert({ name = g.name, count = g.amount }) end
      end
      if site.fin and fin then
        site.fin.set_recipe(fin.name)
        site.fin.insert({ name = "fo-xp-segment-" .. id, count = 10 })
      end
      -- le géant
      site.g = s.create_entity({ name = "fo-xp-" .. id, position = { x, Y }, force = f, raise_built = true })
      ctx.check(site.g ~= nil and site.g.valid, id .. " : pose", site.g and site.g.valid and site.g.name or "refuse")
      st.sites[#st.sites + 1] = site
    end
    -- plafond : force du joueur à l'âge 10
    remote.call("fo-robots", "set_age", "player", 10)
    local px = gx(6)
    ctx.prepare_area(px - 20, Y - 40, px + 60, Y + 40, "dry-dirt")
    st.c1 = s.create_entity({ name = "fo-xp-cairn", position = { px, Y }, force = "player", raise_built = true })
    st.c2 = s.create_entity({ name = "fo-xp-cairn", position = { px + 30, Y }, force = "player", raise_built = true })
    st.cap_x = px
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    local s = ctx.surface()
    if t == NUIT_FIN - 10 then
      st.nuit = stats().tournesol.coups
    end
    if t == NUIT_FIN then s.daytime = 0 end
    -- Trombe : relever une cible arrêtée pendant le gel
    if not st.gele then
      for _, site in ipairs(st.sites) do
        if site.id == "trombe" then
          for _, c in ipairs(site.cibles) do
            if c.valid and not c.active then st.gele = { t = t, e = c } end
          end
        end
      end
    elseif not st.degele and st.gele.e.valid == false then
      st.degele = "detruite"
    elseif not st.degele and st.gele.e.active then
      st.degele = "rendue"
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local all = stats()
    for _, site in ipairs(st.sites) do
      local id = site.id
      local sx = all[id]
      ctx.check(site.dock and site.dock.valid and site.dock.products_finished >= 1, id .. " : le Dock fabrique un segment",
        site.dock and site.dock.valid and tostring(site.dock.products_finished) or "?")
      ctx.check(site.fin and site.fin.valid and site.fin.products_finished >= 1, id .. " : l'usine de son age assemble le geant (" .. USINE[id] .. ")",
        site.fin and site.fin.valid and tostring(site.fin.products_finished) or "?")
      local p = 0
      for k, c in ipairs(site.cibles) do
        if c.valid then p = p + (c.prototype.max_health - c.health) else p = p + site.maxs[k] end
      end
      ctx.check(sx.coups >= 1 and sx.degats > 0 and p > 0, id .. " : degats reels sur les cibles",
        string.format("coups %d, degats du script %.0f, cibles %d, tues %d, PV perdus par les cibles %.0f", sx.coups, sx.degats, sx.cibles, sx.tues, p))
      local tm = site.temoin
      ctx.check(tm and tm.valid and tm.health == tm.prototype.max_health, id .. " : temoin de sa force intact au milieu des cibles",
        tm and tm.valid and string.format("%.0f", tm.health) or "detruit")
      ctx.check(site.g and site.g.valid, id .. " : toujours la (personne ne lui tire dessus)")
    end
    ctx.check(st.gele ~= nil and st.degele ~= nil, "trombe : une cible arretee par le gel, puis rendue ou detruite",
      st.gele and string.format("gel au tick %d, puis %s", st.gele.t, tostring(st.degele)) or "aucune cible arretee")
    ctx.check(st.nuit == 0 and all.tournesol.coups >= 1, "tournesol : rien de nuit, tire de jour",
      string.format("de nuit %s, en tout %d", tostring(st.nuit), all.tournesol.coups))
    -- interface lue par robotsjeu (script/robots/armee.lua) : le NOM de la force, une chaîne
    ctx.check(remote.call("fo-xp", "geants", "fo-xp-g-cairn") == 1 and remote.call("fo-xp", "geants", "player") == 1
      and remote.call("fo-xp", "geants", "fo-xp-inconnue") == 0, "interface fo-xp geants : nom de force (chaine)",
      string.format("cairn %s, joueur %s, inconnue %s", tostring(remote.call("fo-xp", "geants", "fo-xp-g-cairn")),
        tostring(remote.call("fo-xp", "geants", "player")), tostring(remote.call("fo-xp", "geants", "fo-xp-inconnue"))))
    local n = ctx.surface().count_entities_filtered({ name = "fo-xp-cairn", force = "player" })
    local sol = ctx.surface().count_entities_filtered({ name = "item-on-ground", position = { st.cap_x + 30, Y }, radius = 6 })
    ctx.check(st.c1 and st.c1.valid and n == 1 and sol >= 1, "plafond : a l'age 10, un Cairn admis, le second refuse (objet rendu au sol)",
      string.format("cairns du joueur %d, objets au sol %d", n, sol))
  end,
}
