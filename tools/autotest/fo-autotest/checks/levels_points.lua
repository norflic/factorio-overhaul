--[[
  Contrôles GREFFÉS au banc « content » (lot V3-T2, corrections du correcteur) : POINTS DE JEU des machines qui
  grandissent, et fabrications en cours à travers le remplacement rapide moteur. Format : tools/autotest/README.md §4 ;
  listé dans checks/index.lua. Le même module sert au scénario greffé « t2-machines » (contrôles plus tôt, captures).

  Défauts 1 et 6 du correcteur : le point de dépôt d'une foreuse et les raccords de tuyau sont posés une fois par
  prototype (orientation nord) et tournés par le moteur ; sur un côté pair, un point « au milieu » d'un bord est
  décalé d'une demi-tuile. La règle de position ne connaissant pas la direction, une foreuse tournée vers le SUD ou
  l'OUEST déposait à côté de son coffre après l'agrandissement (et un assembleur à fluide perdait son tuyau), sans
  refus ni message. Correction : règle des points servis (shared/levels/points.lua ; script/levels/levels.lua,
  Levels.served_points). Ici, en moteur réel :
  A. 12 foreuses (4 orientations × passages 6 → 7, 12 → 13, 18 → 19 : 3×3 → 4×4, 4×4 → 5×5, 5×5 → 6×6) qui déposent
     dans un coffre, et 12 assembleurs à fluide (mêmes orientations et passages) raccordés à un tuyau infini : après
     l'agrandissement, le MÊME coffre reçoit le minerai, le MÊME tuyau alimente la machine (fabrication qui avance).
  B. Refus : foreuse tournée vers le sud dont la seule position qui garde le dépôt est prise (murs) : refus
     « no-room », coût non payé, contour au nord-est et le coffre désigné comme point servi (« point:iron-chest »).
     Murs à la place des arbres du test hors jeu. Assembleur cerné (voisins et bras) gardé tel quel : refus. Les deux sont re-tentés toutes les 250 ticks
     jusqu'au tick 2500 (contours visibles dans une session avec images).
  C. Défaut 5 : fabrication en cours à travers le REMPLACEMENT RAPIDE moteur (même taille) : four 7 → 8 (fer) et
     assembleur à moteurs 7 → 8 (acier) : bilan de matière et progression. Défaut 15 (chemin normal) : four 6 → 7 par
     script au tick ACT, puis 7 → 8 par le moteur au tick ACT + 1 : bilan de fer.
  D. Défaut 10 : assembleur en « sortie pleine » agrandi 6 → 7 : bilan de fer (plaques + 2 × engrenages) constant.
     F84 rejoué (défaut 13) : écrire crafting_progress sur un assembleur à l'arrêt, sans ingrédients : relevé.
  E. H-L1 (défaut 13) : coût de l'abonnement on_tick de Levels.resume_progress (100 000 appels, liste vide), au journal.
  X. Deux défauts trouvés par ce greffon au premier essai (22/10, 18 h 46 ; témoin sur le code d'avant : archive
     fo-logs6-10-22_V3T2	emoin-be0ee03-points) : un bâtiment remplacé PAR SCRIPT n'était plus raccordé au tuyau
     que l'ancien occupait (12 assembleurs sur 12) ; un assembleur tourné vers l'est, le sud ou l'ouest revenait au
     nord (créé sans recette, il n'est pas orientable). Expérience des remèdes (rien, update_connections du nouveau ou
     du tuyau, téléport sur place de l'un ou de l'autre) et contrôle que le mod refait le raccord seul.
  Barre rouge du coffre du centre (défaut 3) : centre 3 d'une force à part, barre à 5 cases, agrandi 4×4 → 5×5.
]]

local LV = require("__factorio-overhaul__/shared/levels/config")
local Foot = require("__factorio-overhaul__/shared/levels/footprint")

local M = {}

M.ACT = 1760 -- après levels_machines (1750)
M.RETRY_EVERY, M.RETRY_LAST = 250, 2500
local FORCE = "fo-lv-pts"
local AS, DR, FU = LV.by_key.assembler, LV.by_key.drill, LV.by_key.furnace
local SLOW = "engine-unit"
local DIRS = { "north", "east", "south", "west" }
local STEPS = { 6, 12, 18 }

local function make_force(name)
  local f = game.forces[name] or game.create_force(name)
  for _, other in ipairs({ "player", "enemy" }) do
    f.set_cease_fire(other, true)
    game.forces[other].set_cease_fire(f, true)
  end
  return f
end

local function fmt(p) return p and string.format("%g, %g", p.x, p.y) or "-" end

local function stock(inv, family, n)
  for _, c in ipairs(LV.cost(family, n)) do inv.insert({ name = c[1], count = c[2] }) end
end

--- Coordonnée de centre d'un bâtiment de côté `side` posé autour de (x, y) entiers (parité du moteur).
local function at(v, side) return side % 2 == 1 and v + 0.5 or v end

local function put(s, f, family, n, x, y, dir)
  return s.create_entity({ name = LV.name(family, n), position = { x = x, y = y }, direction = dir, force = f, raise_built = true })
end

local function ins(s, f, x, y, dir)
  return s.create_entity({ name = "inserter", position = { x = x, y = y }, direction = dir, force = f, raise_built = true })
end

local function chest(s, f, x, y)
  return s.create_entity({ name = "iron-chest", position = { x = x, y = y }, force = f, raise_built = true })
end

local function held(insr, item)
  local h = insr and insr.valid and insr.held_stack
  return (h and h.valid_for_read and h.name == item) and h.count or 0
end

--- Le point est-il dans la boîte de collision de l'entité ?
local function inside(e, p)
  local b = e.bounding_box
  return p.x >= b.left_top.x - 1e-6 and p.x <= b.right_bottom.x + 1e-6 and p.y >= b.left_top.y - 1e-6 and p.y <= b.right_bottom.y + 1e-6
end

--- Connexion de la boîte 1 de `a` à l'entité `owner` (tuyau) ?
local function piped(a, owner)
  if not (a and a.valid and owner and owner.valid) then return false end
  for _, c in ipairs(a.fluidbox.get_pipe_connections(1) or {}) do
    if c.target and c.target.owner == owner then return true end
  end
  return false
end

---------------------------------------------------------------------------------------------------
-- Installation
---------------------------------------------------------------------------------------------------
function M.setup(ctx)
  local z, s = ctx.zone, ctx.surface()
  local st = ctx.state()
  local f = make_force(FORCE)
  for _, r in ipairs({ "fill-water-barrel", SLOW, "iron-gear-wheel" }) do if f.recipes[r] then f.recipes[r].enabled = true end end
  local x0, y0 = z.x0, z.y0
  ctx.power(x0 + 64, y0 + 48, f)
  st.cc = s.create_entity({ name = LV.name(LV.by_key.command, 15), position = { x0 + 120, y0 + 88 }, force = f, raise_built = true })

  -- A. Orientations : foreuses (colonnes 0 à 3) et assembleurs (colonnes 4 à 7), une rangée par passage.
  st.drills, st.asms = {}, {}
  for row, n in ipairs(STEPS) do
    local side = LV.footprint(DR, n)
    local yc = y0 + 8 + (row - 1) * 16
    for col, dname in ipairs(DIRS) do
      local dir = defines.direction[dname]
      local xd = x0 + 6 + (col - 1) * 14
      -- Gisement 12×12 sous la foreuse (la zone 6×6 du niveau 19 fait 8×8).
      for dx = -6, 5 do for dy = -6, 5 do s.create_entity({ name = "iron-ore", position = { xd + dx + 0.5, yc + dy + 0.5 }, amount = 5000 }) end end
      local d = put(s, f, DR, n, at(xd, side), at(yc, side), dir)
      local c = d and chest(s, f, d.drop_position.x, d.drop_position.y)
      st.drills[#st.drills + 1] = { e = d, chest = c, dir = dname, n = n }
      local xa = x0 + 62 + (col - 1) * 14
      -- Recette donnée à la création : sans recette à fluide, un assembleur n'est pas orientable et create_entity
      -- ignore la direction (premier essai : les 12 assembleurs tournés vers le nord).
      local a = s.create_entity({ name = LV.name(AS, n), position = { x = at(xa, LV.footprint(AS, n)), y = at(yc, LV.footprint(AS, n)) },
        direction = dir, force = f, raise_built = true, recipe = "fill-water-barrel" })
      local pipe
      if a then
        local conn = a.fluidbox.get_pipe_connections(1)[1]
        pipe = conn and s.create_entity({ name = "infinity-pipe", position = conn.target_position, force = f, raise_built = true })
        if pipe then pipe.set_infinity_pipe_filter({ name = "water", percentage = 1 }) end
      end
      st.asms[#st.asms + 1] = { e = a, pipe = pipe, dir = dname, n = n }
    end
  end
  local placed, wired = 0, 0
  for _, d in ipairs(st.drills) do if d.e and d.chest then placed = placed + 1 end end
  local dirs_ok = 0
  for _, a in ipairs(st.asms) do
    if a.e and a.pipe and piped(a.e, a.pipe) then wired = wired + 1 end
    if a.e and a.e.direction == defines.direction[a.dir] then dirs_ok = dirs_ok + 1 end
  end
  ctx.check(dirs_ok == 12, "A : les 12 assembleurs ont l'orientation demandee (recette a fluide donnee a la creation)", dirs_ok .. "/12")
  ctx.check(placed == 12 and wired == 12, "A : 12 foreuses (4 orientations, niveaux 6, 12, 18) avec un coffre au point de depot, 12 assembleurs a fluide raccordes a un tuyau infini",
    placed .. " foreuses, " .. wired .. " assembleurs raccordes")

  -- B. Refus : foreuse 6 tournée vers le sud, coffre au dépôt, murs au nord-ouest et au sud-est du coffre.
  local yb = y0 + 56
  local xb = x0 + 8.5
  for dx = -4, 4 do for dy = -4, 4 do s.create_entity({ name = "iron-ore", position = { xb + dx, yb + 0.5 + dy }, amount = 5000 }) end end
  local db = put(s, f, DR, 6, xb, yb + 0.5, defines.direction.south)
  st.ref_drill = db
  st.ref_chest = db and chest(s, f, db.drop_position.x, db.drop_position.y)
  -- Murs (boîte centrée ± 0,49, connue) aux mêmes places que les arbres du test hors jeu (tests/levels_test.lua §8 c).
  s.create_entity({ name = "stone-wall", position = { xb - 2, yb - 1.5 }, force = f })
  s.create_entity({ name = "stone-wall", position = { xb + 1, yb + 2.5 }, force = f })
  -- Assembleur 6 cerné : voisins collés à l'est et à l'ouest, bras au nord et au sud.
  local xa = x0 + 30.5
  for i = -1, 1 do
    local m = put(s, f, AS, 6, xa + 3 * i, yb + 0.5, defines.direction.north)
    if m then m.set_recipe("iron-gear-wheel") end
    ins(s, f, xa + 3 * i, yb - 1.5, defines.direction.north)
    ins(s, f, xa + 3 * i, yb + 2.5, defines.direction.north)
    if i == 0 then st.ref_asm = m end
  end
  ctx.check(st.ref_drill and st.ref_chest and st.ref_asm, "B : foreuse tournee vers le sud (coffre au depot, murs) et assembleur cerne poses pour les refus")

  -- C. Remplacement rapide en pleine fabrication : four 7 (3×3) nourri par un bras, assembleur 7 (4×4) à moteurs.
  local yc = y0 + 74
  local xf = x0 + 10.5
  local f7 = put(s, f, FU, 7, xf, yc + 0.5)
  if f7 then f7.get_inventory(defines.inventory.fuel).insert({ name = "coal", count = 20 }) end
  st.f7, st.f7_ins, st.f7_chest = f7, ins(s, f, xf, yc - 1.5, defines.direction.north), chest(s, f, xf, yc - 2.5)
  st.f7_chest.insert({ name = "iron-ore", count = 200 })
  -- Four 6 (2×2) : 6 → 7 par script au tick ACT, puis 7 → 8 par le moteur au tick ACT + 1.
  local xg = x0 + 24
  local f6 = put(s, f, FU, 6, xg, yc)
  if f6 then f6.get_inventory(defines.inventory.fuel).insert({ name = "coal", count = 20 }) end
  st.f6, st.f6_ins, st.f6_chest = f6, ins(s, f, xg - 0.5, yc - 1.5, defines.direction.north), chest(s, f, xg - 0.5, yc - 2.5)
  st.f6_chest.insert({ name = "iron-ore", count = 200 })
  -- Assembleur 7 (4×4, coordonnées entières) à moteurs : bras d'entrée à l'ouest, de sortie au nord.
  local xm = x0 + 40
  local a7 = put(s, f, AS, 7, xm, yc, defines.direction.north)
  if a7 then
    a7.set_recipe(SLOW)
    a7.insert({ name = "steel-plate", count = 1 })
    a7.insert({ name = "iron-gear-wheel", count = 1 })
    a7.insert({ name = "pipe", count = 2 })
  end
  st.a7 = a7
  st.a7_ins = ins(s, f, xm - 2.5, yc - 0.5, defines.direction.west)
  st.a7_chest = chest(s, f, xm - 3.5, yc - 0.5)
  st.a7_chest.insert({ name = "steel-plate", count = 100 })
  st.a7_chest.insert({ name = "iron-gear-wheel", count = 100 })
  st.a7_chest.insert({ name = "pipe", count = 200 })
  st.a7_out = ins(s, f, xm - 0.5, yc - 2.5, defines.direction.south)
  st.a7_outchest = chest(s, f, xm - 0.5, yc - 3.5)

  -- D. Assembleur 6 en sortie pleine (100 engrenages, 20 plaques) ; assembleur 6 à l'arrêt sans ingrédients (F84).
  local xo = x0 + 56.5
  local full = put(s, f, AS, 6, xo, yc + 0.5, defines.direction.north)
  if full then
    full.set_recipe("iron-gear-wheel")
    full.get_inventory(defines.inventory.assembling_machine_output).insert({ name = "iron-gear-wheel", count = 100 })
    full.get_inventory(defines.inventory.assembling_machine_input).insert({ name = "iron-plate", count = 20 })
  end
  st.full = full
  local idle = put(s, f, AS, 6, x0 + 66.5, yc + 0.5, defines.direction.north)
  if idle then idle.set_recipe("iron-gear-wheel") end
  st.idle = idle
  -- Défaut 3 : centre 3 (4×4) d'une force à part, coût du niveau 4 rangé, PUIS barre rouge posée à 5 cases.
  local fb = make_force(FORCE .. "-cc")
  local c3 = s.create_entity({ name = LV.name(LV.by_key.command, 3), position = { x0 + 100, y0 + 62 }, force = fb, raise_built = true })
  if c3 then
    local ci = c3.get_inventory(defines.inventory.chest)
    stock(ci, LV.by_key.command, 4)
    ci.set_bar(5)
  end
  st.bar_cc = c3
  -- X. Expérience (premier essai du 22/10, 18 h 46 : les 12 assembleurs agrandis par script n'étaient plus raccordés
  -- au tuyau resté en place) : 5 assembleurs 6 au nord avec un tuyau infini au raccord d'entrée ; après l'agrandissement
  -- par le mod, variantes appliquées par le banc : rien ; update_connections() du nouveau ; du tuyau ; téléport du
  -- nouveau sur place ; du tuyau sur place.
  st.xp = {}
  for k, v in ipairs({ "rien", "machine.update_connections", "tuyau.update_connections", "machine.teleport", "tuyau.teleport" }) do
    local xa = x0 + 6.5 + (k - 1) * 10
    local m = put(s, f, AS, 6, xa, y0 + 88.5, defines.direction.north)
    local pipe
    if m then
      m.set_recipe("fill-water-barrel")
      local conn = m.fluidbox.get_pipe_connections(1)[1]
      pipe = conn and s.create_entity({ name = "infinity-pipe", position = conn.target_position, force = f, raise_built = true })
      if pipe then pipe.set_infinity_pipe_filter({ name = "water", percentage = 1 }) end
    end
    st.xp[#st.xp + 1] = { e = m, pipe = pipe, variant = v }
  end
  ctx.check(st.f7 and st.f6 and st.a7 and st.full and st.idle and st.cc,
    "C/D : four 7, four 6, assembleur 7 a moteurs, assembleur en sortie pleine, assembleur a l'arret poses ; centre 15 de la force")
end

---------------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------------
local function up(ctx, e)
  local st = ctx.state()
  local family, n = LV.parse(e.name)
  stock(st.cc.get_inventory(defines.inventory.chest), family, n + 1)
  return ctx.call("levels_upgrade", e)
end

local function iron(st, f, insr, ch)
  local crafting = f.is_crafting() and 1 or 0
  return ch.get_item_count("iron-ore") + f.get_inventory(defines.inventory.furnace_source).get_item_count("iron-ore")
    + f.get_inventory(defines.inventory.furnace_result).get_item_count("iron-plate") + crafting + held(insr, "iron-ore"), crafting
end

local function steel(st, a)
  local crafting = a.is_crafting() and 1 or 0
  return st.a7_chest.get_item_count("steel-plate") + a.get_inventory(defines.inventory.assembling_machine_input).get_item_count("steel-plate")
    + a.get_inventory(defines.inventory.assembling_machine_output).get_item_count("engine-unit") + crafting
    + held(st.a7_ins, "steel-plate") + held(st.a7_out, "engine-unit") + st.a7_outchest.get_item_count("engine-unit"), crafting
end

local function plates(a)
  local crafting = a.is_crafting() and 2 or 0
  return a.get_item_count("iron-plate") + 2 * a.get_item_count("iron-gear-wheel") + crafting
end

--- Refus attendus (B), rejouables pour les captures. Renvoie les deux résultats.
function M.refusals(ctx)
  local st = ctx.state()
  local inv = st.cc.get_inventory(defines.inventory.chest)
  local rd = st.ref_drill and st.ref_drill.valid and up(ctx, st.ref_drill)
  local ra = st.ref_asm and st.ref_asm.valid and up(ctx, st.ref_asm)
  return rd, ra, inv
end

function M.act(ctx)
  local st = ctx.state()
  if st.done then return end
  st.done = true
  if not (st.cc and st.cc.valid) then
    ctx.fail("centre 15 de la force " .. FORCE .. " introuvable")
    return
  end
  -- A. Foreuses et assembleurs, 4 orientations.
  local bad_d, ranks_d = {}, {}
  for _, d in ipairs(st.drills) do
    if d.e and d.e.valid then
      -- Point de dépôt dans le coffre avant (drop_target n'est calculé qu'au premier minerai : à 0,75/s, pas encore au
      -- tick 60 du scénario t2-machines).
      local was = inside(d.chest, d.e.drop_position)
      local old_pos, old_drop = d.e.position, d.e.drop_position
      local r = up(ctx, d.e)
      ctx.log(string.format("foreuse %s %d : %s depot %s, coffre %s ; %s rang %s -> %s depot %s ; points servis %s",
        d.dir, d.n, fmt(old_pos), fmt(old_drop), fmt(d.chest.position), tostring(r.reason), tostring(r.candidate),
        fmt(r.entity and r.entity.valid and r.entity.position), fmt(r.entity and r.entity.valid and r.entity.drop_position),
        table.concat(r.points or {}, " ")))
      d.new, d.rank, d.reason = r.entity, r.candidate, r.reason
      local ok = was and r.ok and d.new and d.new.valid and inside(d.chest, d.new.drop_position)
      d.ore0 = d.chest.get_item_count("iron-ore")
      ranks_d[#ranks_d + 1] = d.dir .. d.n .. ":" .. tostring(d.rank)
      if not ok then bad_d[#bad_d + 1] = d.dir .. " " .. d.n .. " (" .. tostring(r.reason) .. ", depot " .. fmt(d.new and d.new.valid and d.new.drop_position) .. ")" end
    end
  end
  ctx.check(#bad_d == 0, "A : 12 foreuses agrandies (4 orientations, 3 passages) : le nouveau point de depot est DANS le meme coffre",
    #bad_d > 0 and table.concat(bad_d, " ; ") or ("rangs " .. table.concat(ranks_d, " ")))
  local bad_a, ranks_a = {}, {}
  for _, a in ipairs(st.asms) do
    if a.e and a.e.valid then
      local was = piped(a.e, a.pipe)
      local old_pos = a.e.position
      local r = up(ctx, a.e)
      ctx.log(string.format("assembleur %s %d : %s, tuyau %s ; %s rang %s -> %s ; raccorde apres : %s ; points servis %s",
        a.dir, a.n, fmt(old_pos), fmt(a.pipe and a.pipe.position), tostring(r.reason), tostring(r.candidate),
        fmt(r.entity and r.entity.valid and r.entity.position), tostring(piped(r.entity, a.pipe)), table.concat(r.points or {}, " ")))
      a.new, a.rank = r.entity, r.candidate
      ranks_a[#ranks_a + 1] = a.dir .. a.n .. ":" .. tostring(a.rank)
      if a.new and a.new.valid then
        a.new.get_inventory(defines.inventory.assembling_machine_input).insert({ name = "empty-barrel", count = 10 })
        a.done0 = a.new.products_finished
      end
      if not (was and r.ok and a.new and a.new.valid and a.new.direction == defines.direction[a.dir]) then
        bad_a[#bad_a + 1] = a.dir .. " " .. a.n .. " (" .. tostring(r.reason) .. ", direction " .. tostring(a.new and a.new.valid and a.new.direction) .. ")"
      end
    end
  end
  ctx.check(#bad_a == 0, "A : 12 assembleurs a fluide raccordes agrandis (4 orientations, 3 passages), orientation gardee",
    #bad_a > 0 and table.concat(bad_a, " ; ") or ("rangs " .. table.concat(ranks_a, " ")))

  -- X. Expérience des raccords.
  local xs = {}
  for _, x in ipairs(st.xp or {}) do
    if x.e and x.e.valid then
      local before = piped(x.e, x.pipe)
      local r = up(ctx, x.e)
      local n = r.entity
      local after = piped(n, x.pipe)
      local ok, err = true, nil
      if n and n.valid then
        if x.variant == "machine.update_connections" then ok, err = pcall(function() n.update_connections() end)
        elseif x.variant == "tuyau.update_connections" then ok, err = pcall(function() x.pipe.update_connections() end)
        elseif x.variant == "machine.teleport" then ok, err = pcall(function() return n.teleport(n.position) end)
        elseif x.variant == "tuyau.teleport" then ok, err = pcall(function() return x.pipe.teleport(x.pipe.position) end) end
      end
      x.new = n
      x.fixed = piped(n, x.pipe)
      xs[#xs + 1] = string.format("%s : avant %s, apres agrandissement %s, apres variante %s%s", x.variant, tostring(before), tostring(after),
        tostring(x.fixed), ok and "" or (" (erreur " .. tostring(err) .. ")"))
    end
  end
  ctx.log("EXPERIENCE raccords (tick " .. game.tick .. ") : " .. table.concat(xs, " | "))
  -- Avant la correction (archive temoin-be0ee03-points) : « rien » non raccordé, seuls les téléports raccordaient ; le
  -- mod téléporte désormais lui-même le nouveau bâtiment sur place.
  local x1 = st.xp and st.xp[1]
  ctx.check(x1 and x1.new and x1.new.valid and piped(x1.new, x1.pipe),
    "X : assembleur agrandi par script, tuyau en place, sans rien de plus : raccorde (le mod refait le raccord)", xs[1] or "?")

  -- B. Refus (coût rangé d'abord : un refus ne doit rien prélever).
  local inv = st.cc.get_inventory(defines.inventory.chest)
  stock(inv, DR, 7)
  stock(inv, AS, 7)
  local c0 = inv.get_contents()
  local rd, ra = M.refusals(ctx)
  local c1 = inv.get_contents()
  local unpaid = true
  for _, fam in ipairs({ DR, AS }) do
    for _, c in ipairs(LV.cost(fam, 7)) do
      -- M.refusals range encore une fois le coût de chacun : 1 coût de plus par objet et par famille, rien de moins.
      local extra = 0
      for _, g in ipairs({ DR, AS }) do for _, k in ipairs(LV.cost(g, 7)) do if k[1] == c[1] then extra = extra + k[2] end end end
      if (c1[c[1]] or 0) ~= (c0[c[1]] or 0) + extra then unpaid = false end
    end
  end
  local names_d = rd and table.concat(rd.blockers or {}, ",") or "?"
  ctx.check(unpaid, "B : refus sans paiement (contenu du centre = avant + couts ranges)")
  ctx.check(rd and not rd.ok and rd.reason == "no-room" and st.ref_drill.valid and rd.contour_candidate == 3 and names_d == "point:iron-chest",
    "B : foreuse tournee vers le sud, seule position qui garde le depot prise : refus « no-room », contour au nord-est, le coffre designe comme point servi",
    tostring(rd and rd.reason) .. " ; rang " .. tostring(rd and rd.contour_candidate) .. " ; gene : " .. names_d)
  ctx.check(ra and not ra.ok and ra.reason == "no-room" and st.ref_asm.valid,
    "B : assembleur cerne (voisins, bras) : refus « no-room »", tostring(ra and ra.reason) .. " ; gene : " .. table.concat(ra and ra.blockers or {}, ","))
  st.refused_cost_ok = true

  -- C. Remplacement rapide en pleine fabrication.
  local f7 = st.f7
  st.f7_b0, st.f7_c0 = iron(st, f7, st.f7_ins, st.f7_chest)
  st.f7_p0 = f7.crafting_progress
  local r7 = up(ctx, f7)
  st.f8 = r7.entity
  if st.f8 and st.f8.valid then
    st.f7_b1 = iron(st, st.f8, st.f7_ins, st.f7_chest)
    st.f7_p1 = st.f8.crafting_progress
  end
  ctx.check(r7.ok and st.f8 and st.f8.valid and not f7.valid and r7.resize == nil and st.f7_c0 == 1,
    "C : four 7 -> 8 EN PLEINE FUSION par le remplacement rapide moteur (meme taille 3x3)",
    string.format("%s ; fusion en cours %s, progression %.3f -> %s", tostring(r7.reason), tostring(st.f7_c0), st.f7_p0 or -1, tostring(st.f7_p1)))
  local a7 = st.a7
  st.a7_b0, st.a7_c0 = steel(st, a7)
  st.a7_p0 = a7.crafting_progress
  local ra7 = up(ctx, a7)
  st.a8 = ra7.entity
  if st.a8 and st.a8.valid then
    st.a7_b1 = steel(st, st.a8)
    st.a7_p1 = st.a8.crafting_progress
  end
  ctx.check(ra7.ok and st.a8 and st.a8.valid and ra7.resize == nil and st.a7_c0 == 1,
    "C : assembleur a moteurs 7 -> 8 EN PLEINE FABRICATION par le remplacement rapide moteur (meme taille 4x4)",
    string.format("%s ; fabrication en cours %s, progression %.3f -> %s", tostring(ra7.reason), tostring(st.a7_c0), st.a7_p0 or -1, tostring(st.a7_p1)))
  -- Four 6 : 6 -> 7 par script maintenant, 7 -> 8 par le moteur au tick suivant.
  st.f6_b0, st.f6_c0 = iron(st, st.f6, st.f6_ins, st.f6_chest)
  local r6 = up(ctx, st.f6)
  st.f6b = r6.entity
  ctx.check(r6.ok and st.f6b and st.f6b.valid and r6.resize ~= nil and st.f6_c0 == 1,
    "C : four 6 -> 7 en pleine fusion, par script (2x2 -> 3x3) au tick ACT", tostring(r6.reason))

  -- Défaut 3 : barre rouge du coffre du centre à travers l'agrandissement 4×4 -> 5×5 (par script).
  local c3 = st.bar_cc
  if c3 and c3.valid then
    local i3 = c3.get_inventory(defines.inventory.chest)
    local n3 = #i3
    local rc = ctx.call("levels_upgrade", c3)
    local c4 = rc.entity
    local i4 = c4 and c4.valid and c4.get_inventory(defines.inventory.chest)
    ctx.check(rc.ok and rc.resize and i4 and i4.get_bar() == 5 and #i4 > n3,
      "centre 3 -> 4 (4x4 -> 5x5, par script) : barre rouge du coffre (limite des bras, 5 cases) gardee",
      string.format("%s ; barre %s ; cases %d -> %s", tostring(rc.reason), tostring(i4 and i4.get_bar()), n3, tostring(i4 and #i4)))
  else
    ctx.fail("centre 3 de la barre introuvable")
  end
  -- D. Sortie pleine, puis F84.
  local full = st.full
  st.full_status = full.status
  st.full_crafting = full.is_crafting()
  st.full_p0 = full.crafting_progress
  st.full_b0 = plates(full)
  local rf = up(ctx, full)
  st.full7 = rf.entity
  ctx.log(string.format("sortie pleine au tick %d : etat %s, fabrication %s, progression %.3f, bilan %d ; amelioration %s",
    game.tick, tostring(st.full_status), tostring(st.full_crafting), st.full_p0 or -1, st.full_b0, tostring(rf.reason)))
  -- Premier essai (22/10, 18 h 46) : en « sortie pleine », la machine est EN fabrication (is_crafting vrai) avec une
  -- progression de 1,000 (fabrication finie, produit pas encore sorti) : le transfert la traite comme une fabrication
  -- en cours (ingrédients rendus, progression reposée) ; le bilan (verify) dit si rien n'est créé ni perdu.
  ctx.check(rf.ok and st.full7 and st.full7.valid and st.full_status == defines.entity_status.full_output,
    "D : assembleur en sortie pleine (100 engrenages) agrandi 6 -> 7", string.format("etat %s ; fabrication %s ; progression %.3f",
      tostring(st.full_status), tostring(st.full_crafting), st.full_p0 or -1))
  local idle = st.idle
  local was = idle.is_crafting()
  idle.crafting_progress = 0.25
  st.f84 = { before = was, after = idle.is_crafting(), progress = idle.crafting_progress, plates = idle.get_item_count("iron-plate"),
    gears = idle.get_item_count("iron-gear-wheel"), done = idle.products_finished }
  ctx.log(string.format("F84 rejoue : assembleur a l'arret sans ingredients, crafting_progress ecrit a 0,25 : is_crafting %s -> %s, progression relue %.3f, plaques %d, engrenages %d",
    tostring(was), tostring(st.f84.after), st.f84.progress, st.f84.plates, st.f84.gears))
end

--- Tick ACT + 1 : four 7 (issu du script au tick ACT, la fusion a repris) -> 8 par le moteur.
function M.after1(ctx)
  local st = ctx.state()
  if st.after1 then return end
  st.after1 = true
  local f = st.f6b
  if not (f and f.valid) then return end
  st.f6_p1 = f.crafting_progress
  local r = up(ctx, f)
  st.f6c = r.entity
  ctx.check(r.ok and st.f6c and st.f6c.valid and r.resize == nil,
    "C : le meme four 7 -> 8 par le remplacement rapide moteur au tick ACT + 1", string.format("%s ; progression au tick ACT + 1 : %.3f", tostring(r.reason), st.f6_p1 or -1))
end

function M.after2(ctx)
  local st = ctx.state()
  if st.after2 then return end
  st.after2 = true
  st.f8_p2 = st.f8 and st.f8.valid and st.f8.crafting_progress
  st.a8_p2 = st.a8 and st.a8.valid and st.a8.crafting_progress
  st.f6_p2 = st.f6c and st.f6c.valid and st.f6c.crafting_progress
  ctx.log(string.format("ACT + 2 : progression four 8 %s (avant %.3f), assembleur 8 %s (avant %.3f), four 6->7->8 %s",
    tostring(st.f8_p2), st.f7_p0 or -1, tostring(st.a8_p2), st.a7_p0 or -1, tostring(st.f6_p2)))
  local xs = {}
  for _, x in ipairs(st.xp or {}) do xs[#xs + 1] = x.variant .. " " .. tostring(piped(x.new, x.pipe)) end
  ctx.log("EXPERIENCE raccords a ACT + 2 : " .. table.concat(xs, " | "))
  -- E. Coût de l'abonnement on_tick de la reprise de progression (liste vide), au journal.
  ctx.call("levels_bench_resume", 100000)
  local idle = st.idle
  st.f84.later = { crafting = idle.is_crafting(), progress = idle.crafting_progress, gears = idle.get_item_count("iron-gear-wheel"),
    done = idle.products_finished }
end

function M.tick(ctx, e)
  if e.tick == M.ACT then M.act(ctx)
  elseif e.tick == M.ACT + 1 then M.after1(ctx)
  elseif e.tick == M.ACT + 2 then M.after2(ctx)
  elseif e.tick > M.ACT and e.tick <= M.RETRY_LAST and (e.tick - M.ACT) % M.RETRY_EVERY == 0 then
    M.refusals(ctx)
  end
end

---------------------------------------------------------------------------------------------------
-- Vérification
---------------------------------------------------------------------------------------------------
function M.verify(ctx)
  local st = ctx.state()
  ctx.check(st.done == true, "controles des points de jeu joues")
  -- A. Même coffre, minerai en hausse ; même tuyau, fabrication qui avance.
  local bad, got = {}, {}
  for _, d in ipairs(st.drills or {}) do
    local n = d.new
    local more = d.chest.get_item_count("iron-ore") - (d.ore0 or 0)
    if not (n and n.valid and n.drop_target == d.chest and more > 0) then
      bad[#bad + 1] = d.dir .. d.n .. " (" .. (n and n.valid and n.drop_target and n.drop_target.name or "rien") .. ", +" .. more .. ")"
    end
    got[#got + 1] = d.dir .. d.n .. " +" .. more
  end
  ctx.check(#bad == 0, "A : chaque foreuse agrandie depose dans le MEME coffre (cible moteur), minerai en hausse, 4 orientations x 3 passages",
    #bad > 0 and table.concat(bad, " ; ") or table.concat(got, ", "))
  bad, got = {}, {}
  for _, a in ipairs(st.asms or {}) do
    local n = a.new
    local made = n and n.valid and (n.products_finished - (a.done0 or 0)) or -1
    if not (n and n.valid and piped(n, a.pipe) and made >= 2) then bad[#bad + 1] = a.dir .. a.n .. " (" .. made .. ")" end
    got[#got + 1] = a.dir .. a.n .. " " .. made
  end
  ctx.check(#bad == 0, "A : chaque assembleur agrandi est alimente par le MEME tuyau (connexion moteur, barils remplis), 4 orientations x 3 passages",
    #bad > 0 and table.concat(bad, " ; ") or table.concat(got, ", "))
  -- C. Bilans à travers le remplacement rapide.
  if st.f8 and st.f8.valid then
    local now, c = iron(st, st.f8, st.f7_ins, st.f7_chest)
    ctx.check(now == st.f7_b0 and st.f7_b1 == st.f7_b0,
      "C : four 7 -> 8 (remplacement rapide, en pleine fusion) : bilan de fer constant",
      string.format("avant %d, juste apres %s, au tick %d : %d (en cours %d) ; progression %.3f -> %s juste apres, %s a ACT + 2",
        st.f7_b0 or -1, tostring(st.f7_b1), game.tick, now, c, st.f7_p0 or -1, tostring(st.f7_p1), tostring(st.f8_p2)))
  else
    ctx.fail("four 8 introuvable a la verification")
  end
  if st.a8 and st.a8.valid then
    local now, c = steel(st, st.a8)
    ctx.check(now == st.a7_b0 and st.a7_b1 == st.a7_b0,
      "C : assembleur 7 -> 8 (remplacement rapide, en pleine fabrication) : bilan d'acier constant",
      string.format("avant %d, juste apres %s, au tick %d : %d (en cours %d) ; progression %.3f -> %s juste apres, %s a ACT + 2",
        st.a7_b0 or -1, tostring(st.a7_b1), game.tick, now, c, st.a7_p0 or -1, tostring(st.a7_p1), tostring(st.a8_p2)))
  else
    ctx.fail("assembleur 8 introuvable a la verification")
  end
  if st.f6c and st.f6c.valid then
    local now, c = iron(st, st.f6c, st.f6_ins, st.f6_chest)
    ctx.check(now == st.f6_b0, "C : four 6 -> 7 (script, tick ACT) -> 8 (moteur, tick ACT + 1) : bilan de fer constant",
      string.format("avant %d, au tick %d : %d (en cours %d) ; progression a ACT + 1 : %s, a ACT + 2 : %s", st.f6_b0 or -1, game.tick, now, c,
        tostring(st.f6_p1), tostring(st.f6_p2)))
  else
    ctx.fail("four 6 -> 8 introuvable a la verification")
  end
  -- D. Sortie pleine : bilan ; F84 : relevé.
  if st.full7 and st.full7.valid then
    ctx.check(plates(st.full7) == st.full_b0, "D : assembleur en sortie pleine agrandi : bilan de fer (plaques + 2 x engrenages) constant, aucune fabrication gratuite",
      string.format("avant %d, au tick %d : %d ; etat %s", st.full_b0, game.tick, plates(st.full7), tostring(st.full7.status)))
  end
  local f84 = st.f84 or {}
  local later = f84.later or {}
  ctx.log(string.format("F84 (releve) : a l'ecriture is_crafting %s -> %s ; au tick ACT + 2 : fabrication %s, progression %s, engrenages %s, produits %s ; au tick %d : engrenages %d, produits %d",
    tostring(f84.before), tostring(f84.after), tostring(later.crafting), tostring(later.progress), tostring(later.gears), tostring(later.done),
    game.tick, st.idle.get_item_count("iron-gear-wheel"), st.idle.products_finished))
  ctx.check(f84.before == false and f84.after == true,
    "F84 rejoue : ecrire crafting_progress sur un assembleur a l'arret sans ingredients rend is_crafting() vrai (fait moteur releve)",
    string.format("%s -> %s ; engrenages au tick %d : %d (aucun ingredient)", tostring(f84.before), tostring(f84.after), game.tick, st.idle.get_item_count("iron-gear-wheel")))
  -- Compteurs.
  local s = ctx.call("levels_status", FORCE)
  ctx.check(s.spilled == 0 and s.fluid_lost == 0 and s.resize_failed == 0 and s.forced == 0,
    "aucun objet renverse, aucun fluide perdu, aucun echec, aucun placement force (compteurs globaux)",
    string.format("agrandissements %d, reprises %d, en attente %d", s.resized, s.resumed, s.pending))
end

function M.shots(ctx, add)
  local z = ctx.zone
  add("points-orientations", z.x0 + 56, z.y0 + 26, 0.45, 0)
  add("points-refus", z.x0 + 20, z.y0 + 56, 1.4, 0)
end

return {
  module = M,
  setup = function(ctx)
    ctx.prepare_zone("grass-1")
    M.setup(ctx)
  end,
  tick = M.tick,
  verify = M.verify,
  shots = M.shots,
}
