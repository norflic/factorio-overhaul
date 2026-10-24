-- Scénario greffé du lot IA1-0 (24/10) : levée des risques moteur des équipes de PNJ organisées
-- (docs/EQUIPES_PNJ.md §14 et §16), en moteur réel, SANS prototype de test (mod livré tel quel) :
--   & "<racine>\fo-autotest.bat" nopause 1800 ia1-risques "<source>"
--   py -3.9 tools/autotest/ia1/risques.py "<racine>\fo-autotest"      (verdicts, coûts unitaires de R4)
--
-- Le BILAN ne compte que des contrôles de PROTOCOLE (mise en place, témoins qui doivent tenir pour que
-- l'expérience vaille). Les réponses aux questions ouvertes sont des lignes « VERDICT Rk : OUI|NON … » HORS
-- bilan : un « non » est un résultat, pas un échec. risques.py exige les 6 verdicts (R1, R2, R3, R4, R5, R7).
--
-- R1 (tick 250) : amélioration d'un bâtiment de niveau par un PNJ porteur du coût, SANS `character` (contrôle de
--   F39 dans ce cas) : four en acier (niveau 1) → fo-lvl-furnace-2, assembleur 2 → fo-lvl-assembler-2, en marche.
--   Variante A : le coût est retiré de l'inventaire du PNJ, puis create_entity{fast_replace, spill = false,
--   raise_built} sans character ni player (ce que fera Levels.upgrade_with, lot V2c/IA1-f) ;
--   variante B : la même avec character = PNJ (l'appel INTERDIT par le §5.1 : on mesure le danger) ;
--   variante M : le chemin du mod, remote levels_upgrade (paiement par un centre de commandement de la force).
--   Objets de niveau comptés sur TOUTE la carte (inventaires des personnages, coffres, machines, objets au sol)
--   avant et après chaque variante.
-- R2 : un roboport de « player » (votre équipe : les PNJ de votre équipe sont dans votre force) et ses robots
--   bâtissent-ils les fantômes posés par script pour « player », avec les objets du réseau ? Et ceux d'une force IA
--   posés dans sa zone ? (La visibilité des fantômes d'une autre force se juge sur les captures d'ia1-carte.)
-- R3 : le roboport d'une force IA (sans joueur) bâtit-il ses fantômes, et ses robots logistiques livrent-ils un
--   coffre demandeur ? Et les fantômes de « player » posés dans sa zone ?
-- R4 (ticks 400, 500, 600 : 3 répétitions ; banc épinglé sur les cœurs P par fo-autotest.bat, F30) : coût unitaire,
--   au LuaProfiler, des appels d'évaluation d'un lot de 24 × 24, de can_place_entity (script_ghost), de la pose
--   d'un fantôme, du ravivage AVEC les gestionnaires du mod (raise_revive : niveaux) et SANS, du retrait de l'objet
--   porté. Le journal donne des durées totales ; risques.py les divise.
-- R5 (ticks 60 à 1260) : modificateurs character_* sur un personnage SANS joueur, et addition à ceux de la force :
--   5 variantes (témoin « character » vanilla, témoin corps des PNJ, modificateurs du rang 5 « léger »,
--   modificateurs de force seuls, les deux) ; fabrication de 20 engrenages, 120 ticks de course, minage du fer.
-- R7 (tick 10) : coffres liés (linked-chest, link_id) : partage par force ? 2 forces, même link_id.

local LV = require("__factorio-overhaul__/shared/levels/config")

local CHECK = 1700
local T_R7 = 10
local T_R5 = 60
local RUN_TICKS = 120
local MINE_TICKS = 1200
local CRAFT_N = 20      -- engrenages (0,5 s) : met en évidence le tick de plus par fabrication (essai 1)
local LONG = "solar-panel" -- 10 s, fabrication à la main : l'arrondi d'un tick y pèse moins de 0,2 %
local LONG_N = 2
local T_R1 = 250
local R4_TICKS = { 400, 500, 600, 700, 800 }
local R4_N = 1000
local R4_G = 200 -- fantômes par série (grille 20 × 10, pas de 4 tuiles)

-- Rang 5, profil « léger » (shared/team/org.lua, O.RANK_BONUS[5] ; non requis : org.lua requiert shared.team.config,
-- introuvable depuis le mod de test) : fabrication +2,0 (× 3), minage +1,5 (× 2,5), course +0,15, +40 cases.
local PERSO = { craft = 2.0, mine = 1.5, run = 0.15, inv = 40 }
-- Modificateurs de force de la variante « force » (LuaForce, valeurs rondes, distinctes des personnels). Course +0,5 :
-- la vitesse est arrondie au 1/256 de tuile par tick (essai 1 : 0,15 → 38/256) ; avec +0,15 de part et d'autre, addition
-- (49,9/256) et produit (50,8/256) tombaient sur la même valeur arrondie ; avec +0,5 : 63,4/256 contre 66,2/256.
local FORCE_MOD = { craft = 1.0, mine = 1.0, run = 0.5, inv = 10 }

local FORCES = { "ia1-r1", "ia1-r1m", "ia1-fac", "ia1-r5", "ia1-r5f" }

-- Zones (toutes loin des 3 sites garantis de nauvis et des zones des greffons du banc content).
local R1 = { x0 = 1200, y0 = 1196, x1 = 1262, y1 = 1232 }
local R2 = { x0 = 1290, y0 = 1190, x1 = 1390, y1 = 1270, rp = { 1340, 1230 } }
local R3 = { x0 = 1490, y0 = 1190, x1 = 1590, y1 = 1270, rp = { 1540, 1230 } }
local R7 = { x0 = 1200, y0 = 1290, x1 = 1240, y1 = 1310 }
local R5 = { x0 = 1290, y0 = 1286, x1 = 1380, y1 = 1336 }
local R4 = { x0 = 1600, y0 = 1296, x1 = 1690, y1 = 1394 }
local R4_EMPTY = { x0 = 1720, y0 = 1300, x1 = 1744, y1 = 1324 }
local NATURE_Y = 1700

local function force(name) return game.forces[name] or game.create_force(name) end

local function sorted_keys(t)
  local k = {}
  for n in pairs(t) do k[#k + 1] = n end
  table.sort(k)
  return k
end

--- Contenu de toutes les inventaires d'une entité, en texte trié (« index:objet=n,… »).
local function contents(e)
  local out = {}
  for i = 1, e.get_max_inventory_index() do
    local inv = e.get_inventory(i)
    if inv then
      local c = inv.get_contents()
      for _, n in ipairs(sorted_keys(c)) do out[#out + 1] = i .. ":" .. n .. "=" .. c[n] end
    end
  end
  return table.concat(out, ",")
end

local CENSUS_TYPES = { "character", "container", "logistic-container", "linked-container", "furnace",
  "assembling-machine", "item-entity", "roboport", "car", "inserter" }

--- Objets de niveau (L.parse) sur TOUTE la surface : inventaires, objets au sol, mains des bras. { [nom] = n }.
local function level_items(s)
  local by = {}
  local function add(n, c)
    if LV.parse(n) then by[n] = (by[n] or 0) + c end
  end
  for _, e in ipairs(s.find_entities_filtered({ type = CENSUS_TYPES })) do
    if e.type == "item-entity" then
      local st = e.stack
      if st and st.valid_for_read then add(st.name, st.count) end
    elseif e.type == "inserter" then
      local st = e.held_stack
      if st and st.valid_for_read then add(st.name, st.count) end
    else
      for i = 1, e.get_max_inventory_index() do
        local inv = e.get_inventory(i)
        if inv then
          local c = inv.get_contents()
          for _, n in ipairs(sorted_keys(c)) do add(n, c[n]) end
        end
      end
    end
  end
  return by
end

--- Écarts entre deux relevés d'objets de niveau : texte trié et somme des écarts (valeurs absolues).
local function census_delta(a, b)
  local names, seen = {}, {}
  for n in pairs(a) do if not seen[n] then seen[n] = true; names[#names + 1] = n end end
  for n in pairs(b) do if not seen[n] then seen[n] = true; names[#names + 1] = n end end
  table.sort(names)
  local parts, total = {}, 0
  for _, n in ipairs(names) do
    local d = (b[n] or 0) - (a[n] or 0)
    if d ~= 0 then
      parts[#parts + 1] = n .. (d > 0 and "+" or "") .. d
      total = total + math.abs(d)
    end
  end
  return (#parts > 0 and table.concat(parts, ", ") or "aucun"), total
end

local function recipe_of(e)
  local r = e.get_recipe()
  if r then return r.name end
  if e.type == "furnace" and e.previous_recipe then return "prev:" .. e.previous_recipe.name end
  return "aucune"
end

local function enemies_away(s, box)
  local n = 0
  for _, e in ipairs(s.find_entities_filtered({ force = "enemy", area = { { box[1], box[2] }, { box[3], box[4] } } })) do
    e.destroy()
    n = n + 1
  end
  return n
end

---------------------------------------------------------------------------------------------------
-- Mise en place (on_init, pendant --create)
---------------------------------------------------------------------------------------------------
local function setup_forces(ctx)
  local all = { "player", "enemy" }
  for _, n in ipairs(FORCES) do
    force(n)
    all[#all + 1] = n
  end
  for _, a in ipairs(all) do
    for _, b in ipairs(all) do
      if a ~= b then game.forces[a].set_cease_fire(b, true) end
    end
  end
  for _, n in ipairs({ "ia1-r5", "ia1-r5f", "ia1-r1", "ia1-r1m" }) do
    for _, rn in ipairs({ "iron-gear-wheel", LONG }) do
      local r = game.forces[n].recipes[rn]
      if r then r.enabled = true end
    end
  end
  local f = game.forces["ia1-r5f"]
  f.manual_crafting_speed_modifier = FORCE_MOD.craft
  f.manual_mining_speed_modifier = FORCE_MOD.mine
  f.character_running_speed_modifier = FORCE_MOD.run
  f.character_inventory_slots_bonus = FORCE_MOD.inv
  ctx.log(string.format("forces creees : %s ; ia1-r5f : fabrication +%.2f, minage +%.2f, course +%.2f, cases +%d",
    table.concat(FORCES, ", "), f.manual_crafting_speed_modifier, f.manual_mining_speed_modifier,
    f.character_running_speed_modifier, f.character_inventory_slots_bonus))
end

local function npc(s, x, y, f, items)
  local c = s.create_entity({ name = "fo-companion", position = { x, y }, force = f })
  if c and items then
    for _, it in ipairs(items) do c.get_main_inventory().insert({ name = it[1], count = it[2] }) end
  end
  return c
end

local function setup_r1(ctx, st, s)
  ctx.prepare_area(R1.x0, R1.y0, R1.x1, R1.y1, "grass-1")
  ctx.power(1240, 1210, "ia1-r1")
  local fur, asm = LV.by_key.furnace, LV.by_key.assembler
  local cost_f, cost_a = LV.cost(fur, 2), LV.cost(asm, 2)
  st.r1 = { cost_f = cost_f, cost_a = cost_a, cases = {} }
  local function furnace(id, x, f, variant)
    local e = s.create_entity({ name = LV.name(fur, 1), position = { x, 1210 }, force = f })
    if e then
      e.insert({ name = "coal", count = 20 })
      e.insert({ name = "iron-ore", count = 30 })
    end
    local who = variant ~= "M" and npc(s, x, 1214.5, f, cost_f) or nil
    st.r1.cases[#st.r1.cases + 1] = { id = id, variant = variant, e = e, npc = who, cost = cost_f,
      to = LV.name(fur, 2), force = f }
  end
  local function assembler(id, x, f, variant)
    local e = s.create_entity({ name = LV.name(asm, 1), position = { x, 1210.5 }, force = f })
    if e then
      e.set_recipe("iron-gear-wheel")
      e.insert({ name = "iron-plate", count = 40 })
    end
    local who = npc(s, x, 1215.5, f, cost_a)
    st.r1.cases[#st.r1.cases + 1] = { id = id, variant = variant, e = e, npc = who, cost = cost_a,
      to = LV.name(asm, 2), force = f }
  end
  furnace("four-A", 1206, "ia1-r1", "A")
  furnace("four-B", 1214, "ia1-r1", "B")
  furnace("four-M", 1222, "ia1-r1m", "M")
  assembler("assembleur-A", 1238.5, "ia1-r1", "A")
  assembler("assembleur-B", 1246.5, "ia1-r1", "B")
  -- Variante M : centre de commandement de la force ia1-r1m (raise_built : le mod le retient), garni du coût.
  local cc = s.create_entity({ name = LV.name(LV.by_key.command, 1), position = { 1222, 1224 }, force = "ia1-r1m",
    raise_built = true })
  if cc then
    for _, c in ipairs(cost_f) do cc.insert({ name = c[1], count = c[2] }) end
  end
  st.r1.cc = cc
  local placed = 0
  for _, c in ipairs(st.r1.cases) do
    if c.e and (c.variant == "M" or c.npc) then placed = placed + 1 end
  end
  local cs = {}
  for _, c in ipairs(cost_f) do cs[#cs + 1] = c[2] .. " " .. c[1] end
  local ca = {}
  for _, c in ipairs(cost_a) do ca[#ca + 1] = c[2] .. " " .. c[1] end
  ctx.check(placed == 5 and cc ~= nil, "R1 : 3 fours, 2 assembleurs, 4 PNJ porteurs et un centre poses",
    placed .. "/5 ; centre " .. tostring(cc ~= nil) .. " ; cout four 2 : " .. table.concat(cs, ", ")
    .. " ; cout assembleur 2 : " .. table.concat(ca, ", "))
end

local function setup_robots(ctx, st, s, Z, own, other, logistics)
  ctx.prepare_area(Z.x0, Z.y0, Z.x1, Z.y1, "grass-1")
  ctx.power(Z.rp[1], Z.rp[2], own)
  local rp = s.create_entity({ name = "roboport", position = Z.rp, force = own })
  if rp then
    rp.insert({ name = "construction-robot", count = 10 })
    if logistics then rp.insert({ name = "logistic-robot", count = 5 }) end
  end
  local store = s.create_entity({ name = "logistic-chest-storage", position = { Z.rp[1] - 3.5, Z.rp[2] - 3.5 }, force = own })
  if store then store.insert({ name = "stone-furnace", count = 10 }) end
  local cx = Z.rp[1]
  local z = { rp = rp, store = store, own = {}, other = {} }
  for k = 0, 2 do
    local p = { cx + 10 + 4 * k, Z.rp[2] - 10 }
    z.own[#z.own + 1] = { pos = p, g = s.create_entity({ name = "entity-ghost", inner_name = "stone-furnace", position = p,
      force = own, expires = false }) }
  end
  for k = 0, 1 do
    local p = { cx + 10 + 4 * k, Z.rp[2] + 10 }
    z.other[#z.other + 1] = { pos = p, g = s.create_entity({ name = "entity-ghost", inner_name = "stone-furnace",
      position = p, force = other, expires = false }) }
  end
  if logistics then
    z.prov = s.create_entity({ name = "logistic-chest-passive-provider", position = { cx - 9.5, Z.rp[2] + 6.5 }, force = own })
    if z.prov then z.prov.insert({ name = "iron-plate", count = 100 }) end
    z.req = s.create_entity({ name = "logistic-chest-requester", position = { cx - 5.5, Z.rp[2] + 6.5 }, force = own })
    if z.req then z.req.set_request_slot({ name = "iron-plate", count = 50 }, 1) end
  end
  local ghosts = 0
  for _, g in ipairs(z.own) do if g.g then ghosts = ghosts + 1 end end
  for _, g in ipairs(z.other) do if g.g then ghosts = ghosts + 1 end end
  ctx.check(rp ~= nil and store ~= nil and ghosts == 5 and (not logistics or (z.prov and z.req)),
    "R" .. (logistics and "3" or "2") .. " : roboport de " .. own .. ", robots, stock et fantomes poses",
    "roboport " .. tostring(rp ~= nil) .. ", stockage " .. tostring(store ~= nil) .. ", fantomes " .. ghosts
      .. "/5 (3 de " .. own .. ", 2 de " .. other .. ")")
  return z
end

local function setup_r7(ctx, st, s)
  ctx.prepare_area(R7.x0, R7.y0, R7.x1, R7.y1, "grass-1")
  if not game.entity_prototypes["linked-chest"] then
    ctx.fail("R7 : prototype linked-chest present", "absent")
    return
  end
  local function chest(x, f, id)
    local e = s.create_entity({ name = "linked-chest", position = { x, 1300.5 }, force = f })
    if e then e.link_id = id end
    return e
  end
  st.r7 = { a = chest(1205.5, "player", 7), b = chest(1210.5, "player", 7), e = chest(1215.5, "player", 8),
    c = chest(1220.5, "ia1-fac", 7), d = chest(1225.5, "ia1-fac", 7) }
  local r = st.r7
  ctx.check(r.a and r.b and r.c and r.d and r.e and r.a.link_id == 7 and r.c.link_id == 7 and r.e.link_id == 8,
    "R7 : 5 coffres lies poses (player 7, 7, 8 ; ia1-fac 7, 7)",
    "link_id lus : " .. tostring(r.a and r.a.link_id) .. ", " .. tostring(r.b and r.b.link_id) .. ", "
      .. tostring(r.e and r.e.link_id) .. ", " .. tostring(r.c and r.c.link_id) .. ", " .. tostring(r.d and r.d.link_id))
end

local VARIANTS = {
  { id = "temoin-vanilla", proto = "character", force = "ia1-r5", perso = false },
  { id = "temoin", proto = "fo-companion", force = "ia1-r5", perso = false },
  { id = "perso", proto = "fo-companion", force = "ia1-r5", perso = true },
  { id = "force", proto = "fo-companion", force = "ia1-r5f", perso = false },
  { id = "force+perso", proto = "fo-companion", force = "ia1-r5f", perso = true },
}

local function setup_r5(ctx, st, s)
  ctx.prepare_area(R5.x0, R5.y0, R5.x1, R5.y1, "grass-1")
  st.r5 = {}
  local made = 0
  for i, v in ipairs(VARIANTS) do
    local y = R5.y0 + 4 + 9 * (i - 1)
    local function body(x, yy)
      local c = s.create_entity({ name = v.proto, position = { x, yy }, force = v.force })
      if c and v.perso then
        c.character_crafting_speed_modifier = PERSO.craft
        c.character_mining_speed_modifier = PERSO.mine
        c.character_running_speed_modifier = PERSO.run
        c.character_inventory_slots_bonus = PERSO.inv
      end
      if c then made = made + 1 end
      return c
    end
    local run = body(1295.5, y + 0.5)
    local craft = body(1340.5, y + 3.5)
    local craft2 = body(1348.5, y + 3.5)
    local mine = body(1360.5, y + 6.5)
    local ore = s.create_entity({ name = "iron-ore", position = { 1362.5, y + 6.5 }, amount = 100000 })
    if craft then craft.get_main_inventory().insert({ name = "iron-plate", count = 2 * CRAFT_N }) end
    local rp = game.recipe_prototypes[LONG]
    if craft2 and rp then
      for _, ing in ipairs(rp.ingredients) do
        if ing.type == "item" then craft2.get_main_inventory().insert({ name = ing.name, count = ing.amount * LONG_N }) end
      end
    end
    st.r5[i] = { id = v.id, v = v, run = run, craft = craft, craft2 = craft2, mine = mine, ore = ore, craft_t = {},
      craft2_t = {}, mine_t = {} }
  end
  local rp = game.recipe_prototypes[LONG]
  ctx.check(made == 4 * #VARIANTS and rp ~= nil and rp.category == "crafting",
    "R5 : 20 personnages sans joueur poses (5 variantes x course, 2 fabrications, minage) ; recette longue a la main",
    made .. "/20 ; " .. LONG .. " : " .. tostring(rp and rp.category) .. ", " .. tostring(rp and rp.energy) .. " s")
end

local function setup_r4(ctx, st, s)
  ctx.prepare_area(R4.x0, R4.y0, R4.x1, R4.y1, "grass-1")
  ctx.prepare_area(R4_EMPTY.x0 - 6, R4_EMPTY.y0 - 6, R4_EMPTY.x1 + 6, R4_EMPTY.y1 + 6, "grass-1")
  -- Lot « naturel » : parmi 8 carrés de 24 × 24 générés, celui qui a le plus d'arbres (coût d'évaluation réaliste).
  for k = 0, 7 do s.request_to_generate_chunks({ x = 1812 + 32 * k, y = NATURE_Y + 12 }, 1) end
  s.force_generate_chunk_requests()
  local best, best_n
  for k = 0, 7 do
    local a = { { 1800 + 32 * k, NATURE_Y }, { 1824 + 32 * k, NATURE_Y + 24 } }
    local n = s.count_entities_filtered({ area = a, type = "tree" })
    if not best_n or n > best_n then best, best_n = a, n end
  end
  st.r4 = { nature = best, porter = npc(s, 1645.5, 1347.5, "ia1-r1", { { "assembling-machine-2", #R4_TICKS * R4_G } }),
    stock = npc(s, 1655.5, 1347.5, "ia1-r1", { { "iron-plate", 1000 } }), reps = {} }
  local a = best
  ctx.log(string.format("R4 lot naturel [%d,%d]-[%d,%d] : %d arbre(s), %d tuile(s) d'eau, %d falaise(s), %d ressource(s), "
    .. "%d entite(s) en tout", a[1][1], a[1][2], a[2][1], a[2][2], best_n,
    s.count_tiles_filtered({ area = a, collision_mask = "water-tile" }), s.count_entities_filtered({ area = a, type = "cliff" }),
    s.count_entities_filtered({ area = a, type = "resource" }), s.count_entities_filtered({ area = a })))
  local carried = st.r4.porter and st.r4.porter.get_item_count("assembling-machine-2") or 0
  ctx.check(carried == #R4_TICKS * R4_G and st.r4.stock ~= nil, "R4 : PNJ porteur pose, un assembleur 2 par ravivage mesure",
    carried .. " assembleurs pour " .. #R4_TICKS .. " x " .. R4_G .. " ravivages")
end

---------------------------------------------------------------------------------------------------
-- R7 : coffres liés
---------------------------------------------------------------------------------------------------
local function play_r7(ctx, st)
  local r = st.r7
  if not (r and r.a and r.a.valid) then return end
  r.a.insert({ name = "iron-plate", count = 10 })
  local seen = { b = r.b.get_item_count("iron-plate"), e = r.e.get_item_count("iron-plate"),
    c = r.c.get_item_count("iron-plate"), d = r.d.get_item_count("iron-plate") }
  r.c.insert({ name = "coal", count = 5 })
  local coal = { d = r.d.get_item_count("coal"), a = r.a.get_item_count("coal"), b = r.b.get_item_count("coal") }
  ctx.check(seen.b == 10, "R7 temoin : meme force, meme link_id : inventaire partage (player A -> B)",
    "10 plaques mises en A, B en voit " .. seen.b)
  local per_force = seen.c == 0 and seen.d == 0 and coal.d == 5 and coal.a == 0 and coal.b == 0
  local other_id = seen.e == 0
  ctx.log(string.format("VERDICT R7 : %s : le partage est %s ; 10 plaques en player/7 A : B (player/7) %d, E (player/8) %d, "
    .. "C (ia1-fac/7) %d, D (ia1-fac/7) %d ; 5 charbons en ia1-fac/7 C : D %d, A %d, B %d ; repli : %s",
    per_force and "OUI" or "NON", per_force and "PAR FORCE (meme link_id, autre force : rien)" or "ENTRE FORCES",
    seen.b, seen.e, seen.c, seen.d, coal.d, coal.a, coal.b,
    per_force and "aucun (un link_id par force suffit ; porteurs seuls par defaut, D-14)" or "porteurs seuls"))
  ctx.check(other_id, "R7 temoin : autre link_id, meme force : rien de partage", "E (player/8) voit " .. seen.e)
end

---------------------------------------------------------------------------------------------------
-- R1 : amélioration par un PNJ
---------------------------------------------------------------------------------------------------
local function snapshot(e)
  return { name = e.name, contents = contents(e), recipe = recipe_of(e), progress = e.crafting_progress,
    finished = e.products_finished, pos = { x = e.position.x, y = e.position.y } }
end

local function play_r1(ctx, st)
  local s = ctx.surface()
  local verdict_ok, notes = true, {}
  for _, c in ipairs(st.r1.cases) do
    if not (c.e and c.e.valid) then
      ctx.fail("R1 " .. c.id .. " : batiment present au tick " .. T_R1, "absent")
    else
      local before = snapshot(c.e)
      local census0 = level_items(s)
      local paid, new, reason
      if c.variant == "M" then
        local cc_before = contents(st.r1.cc)
        local r = ctx.call("levels_upgrade", c.e)
        new, reason = r and r.entity, r and r.reason
        paid = cc_before .. " -> " .. (st.r1.cc.valid and contents(st.r1.cc) or "?")
      else
        local inv = c.npc.get_main_inventory()
        local removed = {}
        for _, it in ipairs(c.cost) do removed[#removed + 1] = inv.remove({ name = it[1], count = it[2] }) == it[2] end
        local all = true
        for _, b in ipairs(removed) do all = all and b end
        ctx.check(all, "R1 " .. c.id .. " : cout retire de l'inventaire du PNJ", contents(c.npc))
        new = s.create_entity({ name = c.to, position = before.pos, direction = c.e.direction, force = c.force,
          fast_replace = true, spill = false, raise_built = true, create_build_effect_smoke = false,
          character = (c.variant == "B") and c.npc or nil })
        reason = "create_entity"
        paid = "PNJ : " .. contents(c.npc)
      end
      local census1 = level_items(s)
      local delta, dsum = census_delta(census0, census1)
      local ok_new = new and new.valid and new.name == c.to
      local old_gone = not c.e.valid
      ctx.check(ok_new and old_gone, "R1 " .. c.id .. " : " .. before.name .. " remplace par " .. c.to
        .. (c.variant == "B" and " (avec character)" or (c.variant == "M" and " (levels_upgrade du mod)" or " (sans character)")),
        "nouveau " .. tostring(ok_new) .. ", ancien detruit " .. tostring(old_gone) .. ", " .. tostring(reason))
      if ok_new then
        local after = snapshot(new)
        local same = after.contents == before.contents and after.recipe == before.recipe
        local line = string.format("MESURE R1 %s (variante %s) : contenu avant [%s] apres [%s] ; recette %s -> %s ; "
          .. "progression %.3f -> %.3f ; produits finis %d -> %d ; objets de niveau sur la carte : %s ; paiement : %s",
          c.id, c.variant, before.contents, after.contents, before.recipe, after.recipe, before.progress or -1,
          after.progress or -1, before.finished or -1, after.finished or -1, delta, paid)
        ctx.log(line)
        if c.variant ~= "B" then
          verdict_ok = verdict_ok and same and dsum == 0
          notes[#notes + 1] = string.format("%s : contenu %s, recette %s, objets de niveau en trop %d", c.id,
            after.contents == before.contents and "garde" or "CHANGE", after.recipe == before.recipe and "gardee" or "CHANGEE", dsum)
        else
          notes[#notes + 1] = string.format("%s (character=, INTERDIT) : objets de niveau %s", c.id, delta)
        end
        c.new = new
      else
        verdict_ok = false
      end
    end
  end
  local stats = ctx.call("levels_status", "ia1-r1m")
  notes[#notes + 1] = "fallback du mod " .. tostring(stats and stats.fallback)
  if stats and stats.fallback ~= 0 then verdict_ok = false end
  ctx.log("VERDICT R1 : " .. (verdict_ok and "OUI" or "NON") .. " : " .. table.concat(notes, " ; ")
    .. " ; repli : " .. (verdict_ok and "aucun (create_entity{fast_replace, spill = false, raise_built} SANS character)"
      or "reinsertion manuelle comptee (fallback, exige a 0)"))
end

---------------------------------------------------------------------------------------------------
-- R2, R3 : robots
---------------------------------------------------------------------------------------------------
local function built_at(s, pos, f)
  return s.find_entity("stone-furnace", pos) ~= nil and s.find_entity("stone-furnace", pos).force.name == f
end

local function poll_robots(st, tick, s)
  for _, key in ipairs({ "r2", "r3" }) do
    local z = st[key]
    if z then
      for _, list in ipairs({ z.own, z.other }) do
        for _, g in ipairs(list) do
          if not g.t and g.g and not g.g.valid and s.find_entity("stone-furnace", g.pos) then g.t = tick end
        end
      end
      if z.req and z.req.valid then
        local n = z.req.get_item_count("iron-plate")
        if not z.req_first and n > 0 then z.req_first = tick end
        if not z.req_t and n >= 50 then z.req_t = tick end
        if tick == 600 or tick == 1200 then z["req_" .. tick] = n end
      end
    end
  end
end

local function finish_robots(ctx, st, key, own, other)
  local s = ctx.surface()
  local z = st[key]
  if not z then return end
  local net = z.rp and z.rp.valid and z.rp.logistic_network
  local nrob = net and net.all_construction_robots or 0
  ctx.check(z.rp and z.rp.valid and z.rp.energy > 0 and nrob == 10,
    key:upper() .. " temoin : roboport de " .. own .. " alimente, 10 robots de construction au reseau",
    "energie " .. string.format("%.0f", z.rp and z.rp.energy or -1) .. " J, robots " .. nrob)
  local own_built, own_t = 0, {}
  for _, g in ipairs(z.own) do
    if built_at(s, g.pos, own) then own_built = own_built + 1 end
    own_t[#own_t + 1] = tostring(g.t or "jamais")
  end
  local other_built, other_ghost, other_t = 0, 0, {}
  for _, g in ipairs(z.other) do
    if built_at(s, g.pos, other) then other_built = other_built + 1 end
    if g.g and g.g.valid then other_ghost = other_ghost + 1 end
    other_t[#other_t + 1] = tostring(g.t or "jamais")
  end
  local stock = z.store and z.store.valid and z.store.get_item_count("stone-furnace") or -1
  local line = string.format("%d/3 fantomes de %s batis (ticks %s), stock du reseau 10 -> %d fours ; %d/2 fantomes de %s "
    .. "batis dans la zone de %s (ticks %s, %d encore fantomes)", own_built, own, table.concat(own_t, ", "), stock,
    other_built, other, own, table.concat(other_t, ", "), other_ghost)
  if key == "r2" then
    ctx.log(string.format("VERDICT R2 : %s : %s ; vos robots (force player) batissent les fantomes poses par script pour "
      .. "player avec les objets du reseau : %s ; fantomes d'une force IA dans votre zone : %s ; visibilite des fantomes "
      .. "d'une autre force : captures ia1-carte ; repli : %s", own_built == 3 and stock == 7 and "OUI" or "NON", line,
      own_built == 3 and stock == 7 and "oui" or "non", other_built == 0 and "ignores" or "BATIS",
      own_built == 3 and "aucun pour la construction (equipe du joueur = force player)"
        or "votre equipe : pose juste a temps, un module a la fois"))
  else
    local req = z.req and z.req.valid and z.req.get_item_count("iron-plate") or -1
    local prov = z.prov and z.prov.valid and z.prov.get_item_count("iron-plate") or -1
    -- Plaques en vol (portées par un robot) au tick du contrôle : req + prov peut rester sous 100, jamais au-dessus.
    local ok = own_built == 3 and stock == 7 and req > 0 and req + prov <= 100
    local f = game.forces[own]
    ctx.log(string.format("VERDICT R3 : %s : %s ; logistique : coffre demandeur 0 -> %d/50 plaques (premiere livraison au tick "
      .. "%s ; %s au tick 600, %s au tick 1200 ; 50 atteint au tick %s), fournisseur 100 -> %d, robots logistiques %d (charge "
      .. "par robot : 1 + bonus %d de la force) ; repli : %s", ok and "OUI" or "NON", line, req, tostring(z.req_first or "jamais"),
      tostring(z.req_600), tostring(z.req_1200), tostring(z.req_t or "jamais"), prov, net and net.all_logistic_robots or 0,
      f.worker_robots_storage_bonus, ok and "aucun (roboports des IA utilisables a l'epoque 10)" or "rester sur les PNJ"))
  end
end

---------------------------------------------------------------------------------------------------
-- R4 : coûts unitaires (LuaProfiler ; durées TOTALES au journal, divisées par risques.py)
---------------------------------------------------------------------------------------------------
local function measure(ctx, label, n, rep, fn)
  local p = game.create_profiler()
  local res = fn(n)
  p.stop()
  log({ "", ctx.tag, " R4\t", label, "\tn=", tostring(n), "\trep=", tostring(rep), "\t", p })
  return res
end

local function grid(k, i)
  -- k = 1 : série S1 ; k = 2 : série S2. i de 1 à R4_G. Assembleur 3 × 3 : centre en x,5.
  local col, row = (i - 1) % 20, math.floor((i - 1) / 20)
  return { R4.x0 + 2.5 + 4 * col, R4.y0 + 6.5 + 4 * row + (k == 2 and 50 or 0) }
end

local function r4_eval(ctx, st, rep)
  local s = ctx.surface()
  local empty = { { R4_EMPTY.x0, R4_EMPTY.y0 }, { R4_EMPTY.x1, R4_EMPTY.y1 } }
  local nat = st.r4.nature
  measure(ctx, "etalon_calib", 200000, rep, function(n)
    local x = 0
    for i = 1, n do x = x + (i % 7) * 0.5 end
    return x
  end)
  measure(ctx, "boucle_vide", R4_N, rep, function(n)
    local x = 0
    for _ = 1, n do x = x + 1 end
    return x
  end)
  local f_empty = { area = empty, limit = 1 }
  measure(ctx, "count_entities_lot_vide", R4_N, rep, function(n)
    local x = 0
    for _ = 1, n do x = x + s.count_entities_filtered(f_empty) end
    return x
  end)
  local f_nat = { area = nat, limit = 1 }
  measure(ctx, "count_entities_lot_naturel", R4_N, rep, function(n)
    local x = 0
    for _ = 1, n do x = x + s.count_entities_filtered(f_nat) end
    return x
  end)
  local f_water = { area = nat, collision_mask = "water-tile", limit = 1 }
  measure(ctx, "count_tiles_eau_lot_naturel", R4_N, rep, function(n)
    local x = 0
    for _ = 1, n do x = x + s.count_tiles_filtered(f_water) end
    return x
  end)
  local f_cliff = { area = nat, type = "cliff", limit = 1 }
  measure(ctx, "count_falaises_lot_naturel", R4_N, rep, function(n)
    local x = 0
    for _ = 1, n do x = x + s.count_entities_filtered(f_cliff) end
    return x
  end)
  local f_res = { area = nat, type = "resource", limit = 1 }
  measure(ctx, "count_ressources_lot_naturel", R4_N, rep, function(n)
    local x = 0
    for _ = 1, n do x = x + s.count_entities_filtered(f_res) end
    return x
  end)
  local f_force = { area = nat, force = { "enemy", "neutral" }, invert = true, limit = 1 }
  measure(ctx, "count_autre_force_lot_naturel", R4_N, rep, function(n)
    local x = 0
    for _ = 1, n do x = x + s.count_entities_filtered(f_force) end
    return x
  end)
  local f_tree = { area = nat, type = { "tree", "simple-entity" } }
  local trees = measure(ctx, "count_arbres_rochers_sans_limite_lot_naturel", R4_N, rep, function(n)
    local x = 0
    for _ = 1, n do x = s.count_entities_filtered(f_tree) end
    return x
  end)
  local cpos = { R4_EMPTY.x0 + 12.5, R4_EMPTY.y0 + 12.5 }
  local ghost_check = defines.build_check_type.script_ghost
  local can = measure(ctx, "can_place_script_ghost", R4_N, rep, function(n)
    local ok = 0
    for _ = 1, n do
      if s.can_place_entity({ name = "assembling-machine-2", position = cpos, force = "ia1-r1",
        build_check_type = ghost_check }) then ok = ok + 1 end
    end
    return ok
  end)
  ctx.check(can == R4_N, "R4 rep " .. rep .. " : can_place_entity (script_ghost) vrai sur le lot vide", can .. "/" .. R4_N
    .. " ; arbres et rochers du lot naturel " .. tostring(trees))
  -- Pose des fantômes : S1 = can_place + create (raise_built = false) ; S2 = create seul, raise_built = true.
  st.r4.reps[rep] = { s1 = {}, s2 = {} }
  local R = st.r4.reps[rep]
  local made1 = measure(ctx, "pose_fantome_can_place_create", R4_G, rep, function(n)
    local m = 0
    for i = 1, n do
      local p = grid(1, i)
      if s.can_place_entity({ name = "assembling-machine-2", position = p, force = "ia1-r1",
        build_check_type = defines.build_check_type.script_ghost }) then
        local g = s.create_entity({ name = "entity-ghost", inner_name = "assembling-machine-2", position = p,
          force = "ia1-r1", expires = false })
        if g then m = m + 1; R.s1[m] = g end
      end
    end
    return m
  end)
  local made2 = measure(ctx, "pose_fantome_create_raise_built", R4_G, rep, function(n)
    local m = 0
    for i = 1, n do
      local g = s.create_entity({ name = "entity-ghost", inner_name = "assembling-machine-2", position = grid(2, i),
        force = "ia1-r1", expires = false, raise_built = true })
      if g then m = m + 1; R.s2[m] = g end
    end
    return m
  end)
  ctx.check(made1 == R4_G and made2 == R4_G, "R4 rep " .. rep .. " : 2 x " .. R4_G .. " fantomes poses",
    made1 .. " + " .. made2)
end

local function r4_revive(ctx, st, rep)
  local R = st.r4.reps[rep]
  local inv = st.r4.porter.get_main_inventory()
  local stock = st.r4.stock.get_main_inventory()
  local item0 = inv.get_item_count("assembling-machine-2")
  local rev1 = measure(ctx, "ravivage_retrait_objet_avec_gestionnaires", R4_G, rep, function(n)
    local m = 0
    for i = 1, n do
      local g = R.s1[i]
      if g and g.valid and inv.remove({ name = "assembling-machine-2", count = 1 }) == 1 then
        local _, e = g.revive({ raise_revive = true })
        if e then m = m + 1; R.s1[i] = e end
      end
    end
    return m
  end)
  local rev2 = measure(ctx, "ravivage_sans_gestionnaires", R4_G, rep, function(n)
    local m = 0
    for i = 1, n do
      local g = R.s2[i]
      if g and g.valid then
        local _, e = g.revive({ raise_revive = false })
        if e then m = m + 1; R.s2[i] = e end
      end
    end
    return m
  end)
  local rm = measure(ctx, "retrait_objet_seul", R4_G, rep, function(n)
    local m = 0
    for _ = 1, n do m = m + stock.remove({ name = "iron-plate", count = 1 }) end
    return m
  end)
  stock.insert({ name = "iron-plate", count = rm })
  ctx.check(rev1 == R4_G and rev2 == R4_G and item0 - inv.get_item_count("assembling-machine-2") == R4_G,
    "R4 rep " .. rep .. " : 2 x " .. R4_G .. " fantomes ravives, " .. R4_G .. " objets retires au porteur",
    rev1 .. " + " .. rev2 .. " ; objets retires " .. (item0 - inv.get_item_count("assembling-machine-2")))
end

local function r4_busy_and_clear(ctx, st, rep)
  local s = ctx.surface()
  local busy = { area = { { R4.x0, R4.y0 }, { R4.x0 + 24, R4.y0 + 24 } }, limit = 1 }
  local n = measure(ctx, "count_entities_lot_occupe", R4_N, rep, function(k)
    local x = 0
    for _ = 1, k do x = x + s.count_entities_filtered(busy) end
    return x
  end)
  ctx.check(n == R4_N, "R4 rep " .. rep .. " : le lot occupe compte une entite a chaque appel", n .. "/" .. R4_N)
  local R = st.r4.reps[rep]
  for _, list in ipairs({ R.s1, R.s2 }) do
    for _, e in ipairs(list) do if e and e.valid then e.destroy() end end
  end
  st.r4.reps[rep] = { done = true }
end

---------------------------------------------------------------------------------------------------
-- R5 : modificateurs
---------------------------------------------------------------------------------------------------
local function tick_r5(st, t)
  local dt = t - T_R5
  for _, c in ipairs(st.r5 or {}) do
    if dt == 0 then
      if c.run then c.x0 = c.run.position.x end
      if c.craft then
        c.craft_started = c.craft.begin_crafting({ count = CRAFT_N, recipe = "iron-gear-wheel", silent = true })
      end
      if c.craft2 then
        c.craft2_started = c.craft2.begin_crafting({ count = LONG_N, recipe = LONG, silent = true })
      end
      c.mine0 = c.mine and c.mine.get_item_count("iron-ore") or 0
    end
    if dt >= 0 and dt < RUN_TICKS and c.run then
      c.run.walking_state = { walking = true, direction = defines.direction.east }
    elseif dt == RUN_TICKS and c.run then
      c.x1 = c.run.position.x
      c.run.walking_state = { walking = false, direction = defines.direction.east }
    end
    if dt >= 0 and dt < MINE_TICKS and c.mine and c.ore and c.ore.valid then
      c.mine.update_selected_entity(c.ore.position)
      c.mine.mining_state = { mining = true, position = c.ore.position }
      local n = c.mine.get_item_count("iron-ore") - c.mine0
      while n > #c.mine_t do c.mine_t[#c.mine_t + 1] = t end
    elseif dt == MINE_TICKS and c.mine then
      c.mine.mining_state = { mining = false }
    end
    if dt >= 0 and c.craft and #c.craft_t < CRAFT_N and dt <= 2000 then
      local n = c.craft.get_item_count("iron-gear-wheel")
      while n > #c.craft_t do c.craft_t[#c.craft_t + 1] = t end
    end
    if dt >= 0 and c.craft2 and #c.craft2_t < LONG_N and dt <= 2000 then
      local n = c.craft2.get_item_count(LONG)
      while n > #c.craft2_t do c.craft2_t[#c.craft2_t + 1] = t end
    end
  end
end

-- Modèle de mesure (essai 1, 24/10 10 h 36) : le moteur compte en ticks entiers et arrondit.
--   fabrication et minage : une unité prend la durée nominale (énergie × 60 ÷ multiplicateur) ou UN tick de plus
--     (engrenage à × 1 : 31 ticks au lieu de 30 ; à × 6 : 5 ticks) : on accepte [E − 0,05 ; E + 1,05] ;
--   course : la vitesse par tick est arrondie au 1/256 de tuile (0,15 → 38/256) : on accepte |v − E| ≤ 1/256 ;
--   inventaire : égalité exacte.
local function fits(kind, measured, expected)
  if kind == "run" then return math.abs(measured - expected) <= 1.0 end
  if kind == "inv" then return measured == expected end
  return measured >= expected - 0.05 and measured <= expected + 1.05
end

local function finish_r5(ctx, st)
  local cp = game.entity_prototypes["fo-companion"]
  local vp = game.entity_prototypes["character"]
  local gear = game.recipe_prototypes["iron-gear-wheel"]
  local long = game.recipe_prototypes[LONG]
  local mtime = game.entity_prototypes["iron-ore"].mineable_properties.mining_time
  ctx.log(string.format("R5 prototypes : fo-companion course %.4f minage %.3f cases %d ; character course %.4f minage %.3f "
    .. "cases %d ; engrenage %.2f s ; %s %.2f s ; minerai de fer %.2f s", cp.running_speed, cp.mining_speed,
    cp.get_inventory_size(defines.inventory.character_main), vp.running_speed, vp.mining_speed,
    vp.get_inventory_size(defines.inventory.character_main), gear.energy, LONG, long.energy, mtime))
  -- Grandeurs mesurées : ticks par unité (fabrication longue, engrenage, minerai), vitesse de course en 1/256 de tuile par
  -- tick, cases.
  local m = {}
  for i, c in ipairs(st.r5) do
    local proto = game.entity_prototypes[c.v.proto]
    local r = { id = c.id, proto = proto }
    if #c.craft2_t == LONG_N then r.long = (c.craft2_t[LONG_N] - T_R5) / LONG_N end
    if #c.craft_t == CRAFT_N then r.gear = (c.craft_t[CRAFT_N] - T_R5) / CRAFT_N end
    if c.x0 and c.x1 then r.run = (c.x1 - c.x0) / RUN_TICKS * 256 end
    local k = #c.mine_t
    if k >= 3 then r.mine = (c.mine_t[k] - c.mine_t[2]) / (k - 2); r.ores = k end
    r.inv = c.mine and #c.mine.get_main_inventory() or -1
    r.inv0 = proto.get_inventory_size(defines.inventory.character_main)
    m[i] = r
    ctx.log(string.format("MESURE R5 %s : %s %.2f ticks/unite (%d sur %d, file lancee %s) ; engrenage %.2f ticks/unite (%d sur %d) ; "
      .. "course %.3f/256 tuile/tick (%.4f tuiles en %d ticks) ; minage %.2f ticks/minerai (%s minerais en %d ticks) ; cases %d "
      .. "(prototype %d)", c.id, LONG, r.long or -1, #c.craft2_t, LONG_N, tostring(c.craft2_started), r.gear or -1, #c.craft_t,
      CRAFT_N, r.run or -1, (c.x1 or 0) - (c.x0 or 0), RUN_TICKS, r.mine or -1, tostring(r.ores), MINE_TICKS, r.inv, r.inv0))
  end
  local ok_all = true
  for _, r in ipairs(m) do ok_all = ok_all and r.long and r.gear and r.run and r.mine and r.inv > 0 and true or false end
  ctx.check(ok_all, "R5 : mesures obtenues pour les 5 variantes (2 " .. LONG .. ", 20 engrenages, course, 3 minerais ou plus)", "")
  if not ok_all then
    ctx.log("VERDICT R5 : NON : mesures incompletes")
    return
  end
  --- Valeurs attendues pour des multiplicateurs (fabrication, minage, course) et un bonus de cases.
  local function expect(r, mc, mm, mr, inv)
    return { long = long.energy * 60 / mc, gear = gear.energy * 60 / mc, mine = mtime * 60 / (r.proto.mining_speed * mm),
      run = r.proto.running_speed * mr * 256, inv = r.inv0 + inv }
  end
  local PROPS = { "long", "gear", "mine", "run", "inv" }
  local function kind(p) return (p == "long" or p == "gear") and "craft" or p end
  --- Propriétés qui ne correspondent pas à `e` (liste vide : tout correspond).
  local function misfits(r, e)
    local bad = {}
    for _, p in ipairs(PROPS) do
      if not fits(kind(p), r[p], e[p]) then bad[#bad + 1] = string.format("%s %.2f/%.2f", p, r[p], e[p]) end
    end
    return bad
  end
  local v, t, p, f, fp = m[1], m[2], m[3], m[4], m[5]
  local same = v.long == t.long and v.gear == t.gear and v.run == t.run and v.mine == t.mine and v.inv == t.inv
  ctx.check(same, "R5 temoin : le corps des PNJ (fo-companion) egale exactement le personnage du joueur sans bonus",
    string.format("%s %.2f/%.2f, engrenage %.2f/%.2f, course %.3f/%.3f, minage %.2f/%.2f, cases %d/%d", LONG, t.long, v.long,
      t.gear, v.gear, t.run, v.run, t.mine, v.mine, t.inv, v.inv))
  local bad_t = misfits(t, expect(t, 1, 1, 1, 0))
  ctx.check(#bad_t == 0, "R5 temoin : sans aucun bonus, durees et vitesse nominales (au tick ou au 1/256 pres)",
    #bad_t == 0 and "conforme" or table.concat(bad_t, ", "))
  local bad_p = misfits(p, expect(p, 1 + PERSO.craft, 1 + PERSO.mine, 1 + PERSO.run, PERSO.inv))
  local bad_f = misfits(f, expect(f, 1 + FORCE_MOD.craft, 1 + FORCE_MOD.mine, 1 + FORCE_MOD.run, FORCE_MOD.inv))
  -- Force + personnage : règle propriété par propriété (addition ou produit).
  local e_add = expect(fp, 1 + FORCE_MOD.craft + PERSO.craft, 1 + FORCE_MOD.mine + PERSO.mine, 1 + FORCE_MOD.run + PERSO.run,
    FORCE_MOD.inv + PERSO.inv)
  local e_mul = expect(fp, (1 + FORCE_MOD.craft) * (1 + PERSO.craft), (1 + FORCE_MOD.mine) * (1 + PERSO.mine),
    (1 + FORCE_MOD.run) * (1 + PERSO.run), FORCE_MOD.inv + PERSO.inv)
  local rules = {}
  for _, pr in ipairs(PROPS) do
    local a, b = fits(kind(pr), fp[pr], e_add[pr]), fits(kind(pr), fp[pr], e_mul[pr])
    local word = (a and b) and "les deux (indiscernables)" or (a and "ADDITION" or (b and "PRODUIT" or "AUCUNE"))
    rules[#rules + 1] = string.format("%s %s (mesure %.2f ; addition %.2f ; produit %.2f)", pr, word, fp[pr], e_add[pr], e_mul[pr])
  end
  local acts = #bad_p == 0
  ctx.log(string.format("VERDICT R5 : %s : modificateurs du personnage sans joueur (rang 5 leger : x%.1f, x%.1f, +%.2f, +%d) %s%s ; "
    .. "modificateurs de force seuls (x%.1f, x%.1f, +%.2f, +%d) %s%s ; force + personnage, regle par propriete : %s ; repli : %s",
    acts and "OUI" or "NON", 1 + PERSO.craft, 1 + PERSO.mine, PERSO.run, PERSO.inv, acts and "AGISSENT" or "N'AGISSENT PAS",
    #bad_p == 0 and "" or (" (" .. table.concat(bad_p, ", ") .. ")"), 1 + FORCE_MOD.craft, 1 + FORCE_MOD.mine, FORCE_MOD.run,
    FORCE_MOD.inv, #bad_f == 0 and "agissent" or "N'AGISSENT PAS comme prevu",
    #bad_f == 0 and "" or (" (" .. table.concat(bad_f, ", ") .. ")"), table.concat(rules, " ; "),
    acts and "aucun (modificateurs PAR PERSONNAGE ; ne jamais ecrire ceux de la force, qui touchent le joueur)"
      or "modificateurs de force pour les factions, jamais pour votre equipe"))
end

---------------------------------------------------------------------------------------------------
return {
  description = "IA1-0 : levee des risques moteur R1 a R5 et R7 (EQUIPES_PNJ.md section 14)",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.pret = false
    game.map_settings.enemy_expansion.enabled = false
    game.map_settings.pollution.enabled = false
    setup_forces(ctx)
    setup_r1(ctx, st, s)
    st.r2 = setup_robots(ctx, st, s, R2, "player", "ia1-fac", false)
    st.r3 = setup_robots(ctx, st, s, R3, "ia1-fac", "player", true)
    setup_r7(ctx, st, s)
    setup_r5(ctx, st, s)
    setup_r4(ctx, st, s)
    local n = enemies_away(s, { 1100, 1100, 2100, 1900 })
    ctx.log("entites ennemies retirees autour des zones : " .. n)
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local t = e.tick
    if t == T_R7 then play_r7(ctx, st) end
    tick_r5(st, t)
    if t == T_R1 then play_r1(ctx, st) end
    for rep, t4 in ipairs(R4_TICKS) do
      if t == t4 then r4_eval(ctx, st, rep) end
      if t == t4 + 20 then r4_revive(ctx, st, rep) end
      if t == t4 + 30 then r4_busy_and_clear(ctx, st, rep) end
    end
    if t % 10 == 0 and t <= CHECK then poll_robots(st, t, ctx.surface()) end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    finish_robots(ctx, st, "r2", "player", "ia1-fac")
    finish_robots(ctx, st, "r3", "ia1-fac", "player")
    finish_r5(ctx, st)
    ctx.log("VERDICT R4 : MESURE : durees au journal (lignes R4), couts unitaires par tools/autotest/ia1/risques.py")
  end,
}
