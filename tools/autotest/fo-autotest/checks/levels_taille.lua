--[[
  Contrôles GREFFÉS au banc « content » (lot V3-T) : EMPRISE CROISSANTE des niveaux de la mitrailleuse, en moteur
  réel. Format : tools/autotest/README.md §4 ; listé dans checks/index.lua.

  Q24 (22/10, 7 h 40) : « agrandissement sur place si la place autour est libre ; sinon l'amélioration est refusée
  et le contour nécessaire s'affiche. » Règle de position et géométrie : shared/levels/footprint.lua ; table :
  shared/levels/config.lua (L.footprints) ; runtime : script/levels/levels.lua. Les valeurs attendues viennent de
  ces fichiers (jamais d'une copie).

  Déroulé :
  - setup (création de la carte) : force « fo-lv-taille » au centre 15, zone du greffon pavée d'herbe, bâtiments et
    obstacles posés ; aucun appel d'amélioration ici (les compteurs globaux du banc content, « 12 améliorations »
    au tick 300, ne doivent pas bouger) ;
  - tick : du tick 250 au tick 2500, toutes les 250 ticks, la mitrailleuse bloquée est re-tentée (refus sans
    paiement) pour que le contour reste visible pendant une session avec images ; au tick ACT (après les contrôles
    de niveaux du banc content, 300 à 1545), tous les contrôles d'agrandissement ;
  - verify (tick 3000) : prototypes des 30 niveaux, contours effacés par le moteur (le dernier, dessiné au tick
    2500 pour 300 ticks, a disparu), compteurs.
  Corrections V3-T : fantôme de mur recouvert par A (retiré ; le compteur dit si c'est le moteur ou le script),
  objet au sol de P sorti du bâtiment (téléporté à côté), minerai réel sous P (ne bloque pas), cas W (eau au nord,
  coffre au sud : le contour montre la position sud-ouest, où l'agrandissement passe une fois le coffre retiré).
  Hors de portée de ce banc (pas de joueur en mode benchmark) : le panneau et son aperçu au sol ; la migration
  d'une vraie sauvegarde.
]]

local LV = require("__factorio-overhaul__/shared/levels/config")
local Foot = require("__factorio-overhaul__/shared/levels/footprint")

local ACT = 1700
local FORCE = "fo-lv-taille"
local G = LV.by_key.gun

local function test_force()
  local f = game.forces[FORCE] or game.create_force(FORCE)
  for _, other in ipairs({ "player", "enemy" }) do
    f.set_cease_fire(other, true)
    game.forces[other].set_cease_fire(f, true)
  end
  return f
end

--- Range `times` fois le coût du niveau n dans l'inventaire ; true si tout est entré.
local function stock(inv, n, times)
  local all = true
  for _, c in ipairs(LV.cost(G, n)) do
    local want = c[2] * (times or 1)
    if inv.insert({ name = c[1], count = want }) < want then all = false end
  end
  return all
end

local function near(a, b) return math.abs(a - b) < 1e-6 end
--- Boîtes : le moteur peut les ranger en virgule fixe (1/256 de tuile) ; tolérance d'un 64e de tuile.
local function close(a, b) return math.abs(a - b) < 1 / 64 end

--- Rectangles de rendu du mod (type « rectangle ») dont le coin nord-ouest est dans la zone.
local function rectangles(z)
  local out = {}
  for _, id in ipairs(rendering.get_all_ids("factorio-overhaul")) do
    if rendering.get_type(id) == "rectangle" then
      local lt = rendering.get_left_top(id).position
      local rb = rendering.get_right_bottom(id).position
      if lt and rb and lt.x >= z.x0 and lt.x < z.x1 and lt.y >= z.y0 and lt.y < z.y1 then
        out[#out + 1] = { id = id, x0 = lt.x, y0 = lt.y, x1 = rb.x, y1 = rb.y }
      end
    end
  end
  return out
end

--- Rectangle de `list` exactement sur `box`, le plus récent (plus longue durée restante : une tentative répétée
--- plus ancienne peut encore être affichée).
local function find_rect(list, box)
  local best, best_ttl
  for _, r in ipairs(list) do
    if near(r.x0, box.x0) and near(r.y0, box.y0) and near(r.x1, box.x1) and near(r.y1, box.y1) then
      local ttl = rendering.get_time_to_live(r.id)
      if not best or ttl > best_ttl then best, best_ttl = r, ttl end
    end
  end
  return best
end

local function status(ctx) return ctx.call("levels_status", FORCE) end

--- Carré attendu après agrandissement de `pos` (côté a) au côté b : candidate de rang k de la règle.
local function expected(pos, a, b, k)
  return Foot.candidates(Foot.tile_box(pos, a), b)[k or 1]
end

return {
  setup = function(ctx)
    ctx.prepare_zone("grass-1")
    local z, s = ctx.zone, ctx.surface()
    local f = test_force()
    local st = ctx.state()
    local cc = s.create_entity({ name = LV.name(LV.by_key.command, 15), position = { z.x0 + 6, z.y0 + 6 }, force = f, raise_built = true })
    local inv = cc and cc.get_inventory(defines.inventory.chest)
    ctx.check(cc ~= nil and ctx.call("levels_status", FORCE).cc_level == 15, "centre 15 de la force de test enregistre")
    st.cc = cc
    -- Coût du niveau 7 rangé une fois pour la tentative répétée (jamais payée : refus « no-room »).
    if inv then stock(inv, 7, 1) end
    local y = z.y0 + 10
    -- A : place libre (+ un fantôme de mur dans le nouveau carré). B : mur au nord, coffre au sud. C : eau au
    -- nord et au sud. D : mur dans le coin nord-ouest seulement. P : personnage, objet au sol et minerai dans le
    -- nouveau carré. W : eau au nord, coffre au sud (candidate montrée). E : chaîne 6 -> 30.
    local function gun(x, yy, ammo, kind)
      local g = s.create_entity({ name = LV.name(G, 6), position = { x, yy }, force = f })
      if g and ammo then g.insert({ name = kind or "firearm-magazine", count = ammo }) end
      return g
    end
    st.a = gun(z.x0 + 26, y, 10)
    if st.a then st.a.health = st.a.prototype.max_health / 2 end
    st.b = gun(z.x0 + 46, y, 10)
    s.create_entity({ name = "stone-wall", position = { z.x0 + 45.5, y - 1.5 }, force = f })
    s.create_entity({ name = "iron-chest", position = { z.x0 + 45.5, y + 1.5 }, force = f })
    st.c = gun(z.x0 + 66, y, 5)
    s.set_tiles({ { name = "water", position = { z.x0 + 65, y - 2 } }, { name = "water", position = { z.x0 + 65, y + 1 } } })
    st.d = gun(z.x0 + 86, y, 7)
    s.create_entity({ name = "stone-wall", position = { z.x0 + 84.5, y - 1.5 }, force = f })
    st.p = gun(z.x0 + 106, y, 2)
    st.walker = s.create_entity({ name = "character", position = { z.x0 + 105.2, y - 1.4 }, force = f })
    st.ground = s.create_entity({ name = "item-on-ground", position = { z.x0 + 106.5, y - 1.5 }, stack = { name = "iron-plate", count = 3 } })
    st.e = gun(z.x0 + 26, z.y0 + 50, 20, "uranium-rounds-magazine")
    st.y = y
    -- Corrections V3-T : fantôme de mur dans le nouveau carré de A (défaut 5), minerai sous la position
    -- préférée de P (défaut 14), cas W (défaut 8).
    st.ghost = s.create_entity({ name = "entity-ghost", inner_name = "stone-wall", position = { z.x0 + 25.5, y - 1.5 }, force = f })
    st.ore = s.create_entity({ name = "iron-ore", position = { z.x0 + 104.5, y + 0.5 }, amount = 50 })
    local y2 = z.y0 + 30
    st.w = gun(z.x0 + 46, y2, 4)
    s.set_tiles({ { name = "water", position = { z.x0 + 45, y2 - 2 } }, { name = "water", position = { z.x0 + 46, y2 - 2 } } })
    st.wchest = s.create_entity({ name = "iron-chest", position = { z.x0 + 45.5, y2 + 1.5 }, force = f })
    ctx.check(st.a and st.b and st.c and st.d and st.p and st.e and st.walker and st.ground and st.ghost and st.ore and st.w and st.wchest,
      "mitrailleuses niveau 6 et obstacles poses (mur, coffre, eau, personnage, objet au sol, fantome, minerai)")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    -- Tentative répétée sur la mitrailleuse bloquée : le contour (300 ticks) reste visible en continu.
    if e.tick >= 250 and e.tick <= 2500 and e.tick % 250 == 0 and st.b and st.b.valid then
      ctx.call("levels_upgrade", st.b)
    end
    if e.tick ~= ACT or st.done then return end
    st.done = true
    local z, s = ctx.zone, ctx.surface()
    local inv = st.cc and st.cc.valid and st.cc.get_inventory(defines.inventory.chest)
    if not inv then
      ctx.fail("centre de la force de test introuvable au tick " .. ACT)
      return
    end
    local s0 = status(ctx)

    -- A. Place libre : 6 -> 7 (2x2 -> 3x3).
    stock(inv, 7, 1)
    local pos_a = st.a.position
    local want = expected(pos_a, 2, 3)
    local ghost_before = st.ghost and st.ghost.valid
    local ra = ctx.call("levels_upgrade", st.a)
    local a7 = ra.entity
    ctx.check(ra.ok and ra.reason == "done" and a7 and a7.valid and a7.name == LV.name(G, 7) and not st.a.valid,
      "place libre : mitrailleuse 6 -> 7 agrandie aussitot", tostring(ra.reason))
    if a7 and a7.valid then
      local bb, sel = a7.bounding_box, a7.prototype.selection_box
      local rect = Foot.collision_rect(want.box)
      ctx.check(near(a7.position.x, want.x) and near(a7.position.y, want.y) and ra.candidate == 1
        and close(bb.left_top.x, rect.x0) and close(bb.right_bottom.y, rect.y1)
        and close(sel.right_bottom.x - sel.left_top.x, 3),
        "nouvelle emprise 3x3 a la position preferee (contient l'ancienne, nord-ouest)",
        string.format("%.1f, %.1f ; collision %.2f..%.2f", a7.position.x, a7.position.y, bb.left_top.x, bb.right_bottom.x))
      local ammo = a7.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine")
      ctx.check(ammo == 10, "munitions transferees", ammo .. " chargeurs")
      ctx.check(math.abs(a7.get_health_ratio() - 0.5) < 0.01, "PV en proportion",
        string.format("%.0f / %.0f", a7.health, a7.prototype.max_health))
      local dropped = s.count_entities_filtered({ area = { { pos_a.x - 4, pos_a.y - 4 }, { pos_a.x + 4, pos_a.y + 4 } }, name = "item-on-ground" })
      ctx.check(dropped == 0 and inv.get_item_count(LV.name(G, 6)) == 0, "objet de l'ancien niveau disparu (ni au sol, ni dans le centre)")
    end
    local s1 = status(ctx)
    ctx.check(s1.resized == s0.resized + 1 and s1.fallback == s0.fallback and s1.spilled == 0,
      "remplacement par script compte, 0 secours manuel, rien renverse",
      string.format("resized %d, fallback %d, spilled %d", s1.resized, s1.fallback, s1.spilled))
    -- Fantôme recouvert (défaut 5) : retiré. Le compteur dit QUI l'a retiré : 1 = notre script (le moteur ne
    -- retire rien sous un create_entity sans fast_replace), 0 = le moteur l'avait déjà retiré.
    local by_script = s1.ghosts_removed - s0.ghosts_removed
    ctx.check(ghost_before and not st.ghost.valid, "fantome de mur present juste avant, retire par l'agrandissement",
      by_script == 1 and "retire par le script (le moteur l'avait laisse)" or ("retire par le moteur (script : " .. by_script .. ")"))

    -- B. Mur au nord et coffre au sud : refus, rien payé, contour.
    stock(inv, 7, 1)
    local before = {}
    for _, c in ipairs(LV.cost(G, 7)) do before[c[1]] = inv.get_item_count(c[1]) end
    local rb = ctx.call("levels_upgrade", st.b)
    local unpaid = true
    for _, c in ipairs(LV.cost(G, 7)) do if inv.get_item_count(c[1]) ~= before[c[1]] then unpaid = false end end
    ctx.check(not rb.ok and rb.reason == "no-room" and st.b.valid and st.b.get_item_count("firearm-magazine") == 10,
      "mur au nord, coffre au sud : refus motif « no-room », mitrailleuse intacte", tostring(rb.reason))
    ctx.check(unpaid, "refus : cout NON paye (place verifiee avant le paiement)")
    local pref = expected(st.b.position, 2, 3)
    local rects = rectangles(z)
    local main = find_rect(rects, pref.box)
    local bl = table.concat(rb.blockers or {}, ",")
    ctx.check(main ~= nil and rb.contour and rb.contour.x0 == pref.box.x0 and rb.contour.y1 == pref.box.y1,
      "contour necessaire dessine (carre 3x3 de la position preferee)",
      main and string.format("(%d, %d) -> (%d, %d), %d rectangle(s) dans la zone, gene : %s", main.x0, main.y0, main.x1, main.y1, #rects, bl) or "introuvable")
    if main then
      local forces = rendering.get_forces(main.id)
      local ttl = rendering.get_time_to_live(main.id)
      -- Rectangles dessinés PAR CET APPEL (durée restante entière) : le contour et le mur surligné.
      local fresh, wall_marked = 0, false
      local wx, wy = st.b.position.x - 0.5, st.b.position.y - 1.5
      for _, r in ipairs(rects) do
        if rendering.get_time_to_live(r.id) == ttl then
          fresh = fresh + 1
          if r.x0 < wx and r.x1 > wx and r.y0 < wy and r.y1 > wy and r.x1 - r.x0 < 1 then wall_marked = true end
        end
      end
      ctx.check(forces and #forces == 1 and forces[1].name == FORCE and ttl == 300 and fresh == 2 and wall_marked,
        "contour visible de la seule force du batiment, dessine par ce refus pour 300 ticks, mur bloquant surligne",
        "reste " .. tostring(ttl) .. " ticks ; " .. fresh .. " rectangle(s) de ce refus")
    end
    ctx.check(bl:find("stone-wall", 1, true) ~= nil and status(ctx).contours > s1.contours,
      "entite bloquante signalee (mur) et contour compte", bl)

    -- C. Eau au nord et au sud : refus.
    stock(inv, 7, 1)
    local rc = ctx.call("levels_upgrade", st.c)
    ctx.check(not rc.ok and rc.reason == "no-room" and st.c.valid and table.concat(rc.blockers or {}, ","):find("tile:water", 1, true),
      "eau au nord et au sud : refus « no-room », eau signalee", tostring(rc.reason) .. " ; " .. table.concat(rc.blockers or {}, ","))

    -- D. Mur dans le coin nord-ouest : la 2e position (nord-est) est retenue.
    stock(inv, 7, 1)
    local alt = expected(st.d.position, 2, 3, 2)
    local rd = ctx.call("levels_upgrade", st.d)
    ctx.check(rd.ok and rd.candidate == 2 and rd.entity and near(rd.entity.position.x, alt.x) and near(rd.entity.position.y, alt.y)
      and rd.entity.get_item_count("firearm-magazine") == 7,
      "position preferee bloquee, 2e libre : agrandissement a la position alternative (nord-est)",
      rd.entity and string.format("%.1f, %.1f (rang %s)", rd.entity.position.x, rd.entity.position.y, tostring(rd.candidate)) or tostring(rd.reason))

    -- P. Personnage et objet au sol dans le nouveau carré : ne bloquent pas ; le personnage est écarté.
    stock(inv, 7, 1)
    local rp = ctx.call("levels_upgrade", st.p)
    local p7 = rp.entity
    local walker_out = false
    if p7 and p7.valid and st.walker.valid then
      local a, b = p7.bounding_box, st.walker.bounding_box
      walker_out = not (a.left_top.x < b.right_bottom.x and b.left_top.x < a.right_bottom.x
        and a.left_top.y < b.right_bottom.y and b.left_top.y < a.right_bottom.y)
    end
    ctx.check(rp.ok and rp.candidate == 1 and walker_out and st.ground.valid and st.ore.valid,
      "personnage ecarte par le moteur (move_stuck_players), objet au sol et minerai : aucun ne bloque",
      st.walker.valid and string.format("personnage en %.2f, %.2f", st.walker.position.x, st.walker.position.y) or tostring(rp.reason))
    -- Objet au sol (défaut 4) : sorti du bâtiment agrandi, à portée de ramassage depuis son bord.
    if p7 and p7.valid and st.ground.valid then
      local a, g = p7.bounding_box, st.ground.position
      local inside = g.x > a.left_top.x and g.x < a.right_bottom.x and g.y > a.left_top.y and g.y < a.right_bottom.y
      local dx = math.max(a.left_top.x - g.x, 0, g.x - a.right_bottom.x)
      local dy = math.max(a.left_top.y - g.y, 0, g.y - a.right_bottom.y)
      local sp = status(ctx)
      ctx.check(not inside and math.sqrt(dx * dx + dy * dy) < 1.5 and sp.ground_moved >= 1 and sp.ground_left == 0,
        "objet au sol sorti du batiment agrandi (teleporte a cote, ramassable), compte",
        string.format("objet en %.2f, %.2f ; boite %.2f..%.2f ; deplaces %d", g.x, g.y, a.left_top.x, a.right_bottom.x, sp.ground_moved))
    end

    -- W. Eau au nord, coffre au sud (défaut 8) : le contour montre la candidate SUD-OUEST (gênée par le coffre
    -- seul), pas la préférée dans l'eau ; sans le coffre, l'agrandissement passe là.
    stock(inv, 7, 1)
    local tw = expected(st.w.position, 2, 3, 3)
    local rw = ctx.call("levels_upgrade", st.w)
    local mw = find_rect(rectangles(z), tw.box)
    ctx.check(not rw.ok and rw.reason == "no-room" and rw.contour_candidate == 3 and rw.contour and rw.contour.x0 == tw.box.x0
      and rw.contour.y0 == tw.box.y0 and mw ~= nil and table.concat(rw.blockers or {}, ",") == "iron-chest",
      "eau au nord, coffre au sud : contour sur la position sud-ouest (genee par le coffre seul), pas sur l'eau",
      tostring(rw.reason) .. " ; rang " .. tostring(rw.contour_candidate) .. " ; gene : " .. table.concat(rw.blockers or {}, ","))
    st.wchest.destroy()
    local rw2 = ctx.call("levels_upgrade", st.w)
    ctx.check(rw2.ok and rw2.candidate == 3 and rw2.entity and near(rw2.entity.position.x, tw.x) and near(rw2.entity.position.y, tw.y)
      and rw2.entity.get_item_count("firearm-magazine") == 4,
      "coffre retire : agrandissement a la position que le contour indiquait (sud-ouest)",
      rw2.entity and string.format("%.1f, %.1f (rang %s)", rw2.entity.position.x, rw2.entity.position.y, tostring(rw2.candidate)) or tostring(rw2.reason))

    -- E. Chaîne 6 -> 30 : 24 améliorations dont 4 agrandissements ; retour au centre d'origine en 6x6.
    local cur, origin = st.e, st.e.position
    local s2 = status(ctx)
    local chain_ok, why, trail = true, nil, {}
    for n = 7, 30 do
      stock(inv, n, 1)
      local r = ctx.call("levels_upgrade", cur)
      if not (r.ok and r.entity and r.entity.valid) then chain_ok, why = false, n .. " : " .. tostring(r.reason) break end
      cur = r.entity
      if n == 7 or n == 13 or n == 19 or n == 25 then trail[#trail + 1] = string.format("%g,%g", cur.position.x, cur.position.y) end
    end
    local s3 = status(ctx)
    ctx.check(chain_ok and cur.name == LV.name(G, 30) and s3.resized == s2.resized + 4 and s3.fallback == s2.fallback,
      "chaine 6 -> 30 : 24 ameliorations, 4 agrandissements, le reste en remplacement rapide (0 secours)",
      why or string.format("resized +%d, fallback +%d", s3.resized - s2.resized, s3.fallback - s2.fallback))
    if chain_ok then
      local sel = cur.prototype.selection_box
      local ammo = cur.get_inventory(defines.inventory.turret_ammo).get_item_count("uranium-rounds-magazine")
      ctx.check(close(sel.right_bottom.x - sel.left_top.x, 6) and near(cur.position.x, origin.x) and near(cur.position.y, origin.y)
        and ammo == 20, "niveau 30 en 6x6, revenu au centre d'origine, munitions conservees",
        table.concat(trail, " ") .. " ; " .. ammo .. " chargeurs")
    end
    st.final = cur
  end,

  verify = function(ctx)
    local st = ctx.state()
    -- Prototypes des 30 niveaux : emprise de la table, portée complétée, même groupe de remplacement (F39).
    local bad = {}
    for n = 1, G.max do
      local p = game.entity_prototypes[LV.name(G, n)]
      local side = LV.footprint(G, n)
      local sel, col = p.selection_box, p.collision_box
      local range = p.attack_parameters and p.attack_parameters.range
      local want_range = LV.apply_stat(G.stats[3], 18, n) + LV.range_bonus(G, n)
      if not (close(sel.right_bottom.x - sel.left_top.x, side) and close(col.right_bottom.x - col.left_top.x, side - 2 * Foot.MARGIN)
          and range and math.abs(range - want_range) < 1e-4 and p.fast_replaceable_group == "fo-lvl-gun") then
        bad[#bad + 1] = n .. ":" .. string.format("%.2f/%.2f/%.2f", sel.right_bottom.x - sel.left_top.x, col.right_bottom.x - col.left_top.x, range or -1)
      end
    end
    ctx.check(#bad == 0, "prototypes : emprise 2x2 -> 6x6 par ere, collision au style vanilla, portee + (cote - 2) / 2, meme groupe",
      #bad > 0 and table.concat(bad, " ") or "30 niveaux")
    ctx.check(st.done == true and st.final and st.final.valid, "controles d'agrandissement joues au tick " .. ACT)
    local left = rectangles(ctx.zone)
    ctx.check(#left == 0, "contours effaces par le moteur (duree limitee : rien ne reste 500 ticks apres la derniere tentative)",
      #left .. " rectangle(s)")
    local s = status(ctx)
    ctx.check(s.spilled == 0 and s.resize_failed == 0 and s.forced == 0 and s.ground_left == 0,
      "aucun objet renverse, aucun echec de remplacement, aucun placement force, aucun objet laisse sous un batiment",
      string.format("contours %d, refus %d, agrandissements %d, fantomes retires %d, objets sortis %d", s.contours, s.room_refused,
        s.resized, s.ghosts_removed, s.ground_moved))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if st.b and st.b.valid then
      local p = st.b.position
      add("contour-refus", p.x, p.y - 0.5, 1.6, 0)
      add("contour-refus-nuit", p.x, p.y - 0.5, 1.6, 0.5)
    end
    local z = ctx.zone
    add("agrandissements", z.x0 + 60, z.y0 + 20, 0.5, 0)
  end,
}
