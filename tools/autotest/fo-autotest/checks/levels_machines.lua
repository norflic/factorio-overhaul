--[[
  Contrôles GREFFÉS au banc « content » (lot V3-T2) : EMPRISE CROISSANTE des machines de production, du laser et du
  centre de commandement, en moteur réel. Format : tools/autotest/README.md §4 ; listé dans checks/index.lua. Le
  même module sert au scénario greffé « t2-machines » (scenarios/t2-machines.lua : mêmes contrôles plus tôt, pour
  les captures).

  Q23 (22/10, 7 h 20) : « les dernières machines pour construire, elles sont de taille, je sais pas moi 6 par six » ;
  Q24 (22/10, 7 h 40) : « agrandissement sur place si la place autour est libre ; sinon l'amélioration est refusée
  et le contour nécessaire s'affiche » ; Q-S1 (22/10, 16 h 45 : oui) : l'échelle vaut pour TOUTES les familles,
  plafond 6×6 pour les machines, centre 4×4 → 8×8, mur inchangé.
  Table : shared/levels/config.lua (L.footprints) ; règle de position : shared/levels/footprint.lua ; runtime :
  script/levels/levels.lua. Les valeurs attendues viennent de ces fichiers (jamais d'une copie).

  Trois sections (zone du greffon : 128 × 96 tuiles) :
  A. Place libre, transfert réel du contenu et points de jeu (rangée y0 + 22) :
     - assembleur 6 → 7 (3×3 → 4×4) : recette, ingrédients, produits, eau de la boîte à fluide, modules, PV ; puis
       un tuyau infini posé au NOUVEAU raccord (lu sur l'entité) l'alimente vraiment (fluide reçu, produits en
       hausse) ; un bras à l'ouest le nourrissait : il vise la nouvelle machine (F79) et la nourrit encore ;
     - foreuse 6 → 7 : réglages et fil du circuit (la condition de marche lit le combinateur par le fil : un fil
       perdu arrêterait la foreuse), progression ; dépôt au nouveau point dans le même coffre, minerai en hausse ;
     - foreuse 6 → 7 SANS minerai sous sa zone d'avant, un seul minerai dans la bande que seule la zone agrandie
       couvre : elle le mine après l'agrandissement (zone d'extraction réellement agrandie) ;
     - four 6 → 7 (2×2 → 3×3) : combustible, entrée, sortie, progression, chaleur du brûleur ; un bras au nord
       bloque les deux positions nord : la 3e (sud-ouest) est retenue ; le bras vise le nouveau four et le nourrit ;
     - laser 6 → 7 : énergie du tampon, victimes et dégâts infligés, PV ; portée corrigée (L.range_bonus).
  B. Usine dense (rangée y0 + 50) : pour chaque famille, le bâtiment du milieu d'une rangée serrée (assembleurs
     collés avec bras et convoyeurs au nord et au sud ; colonne de fours avec bras et convoyeurs ; foreuses collées
     devant leur convoyeur ; lasers collés derrière un mur ; centre 3 entouré de bras et de coffres, force à part) :
     refus « no-room », coût NON payé, contour dessiné ; puis ce que le contour désigne est retiré (exactement les
     gênes annoncées) et l'agrandissement passe à la position du contour.
  C. Chaînes (rangée y0 + 78) : laser, foreuse, four et assembleur de 6 à 30, centre de 1 à 15 (force à part) :
     chaque changement de taille par script, chaque pas à taille égale en remplacement rapide moteur (F39), 0 secours.
  verify (tick 3000 du banc content) : ce qui se mesure dans la durée (fabrication, extraction, bras), prototypes
  des 5 familles sur tous leurs niveaux, contours effacés, compteurs.
  Hors de portée (pas de joueur en mode benchmark) : le panneau et son aperçu au sol.
]]

local LV = require("__factorio-overhaul__/shared/levels/config")
local Foot = require("__factorio-overhaul__/shared/levels/footprint")

local M = {}

M.ACT = 1750 -- après les contrôles de niveaux du banc content (300 à 1545) et ceux de levels_taille (1700)
local FORCE, FORCE_CC1, FORCE_CC2 = "fo-lv-mach", "fo-lv-mach-cc", "fo-lv-mach-cc2"
local AS, DR, FU, LZ, CC = LV.by_key.assembler, LV.by_key.drill, LV.by_key.furnace, LV.by_key.laser, LV.by_key.command
local MODULE = "speed-module"
local RECIPE = "fill-water-barrel"
local SLOW = "engine-unit" -- 10 s par fabrication : la machine est en pleine fabrication au tick ACT

local function make_force(name)
  local f = game.forces[name] or game.create_force(name)
  for _, other in ipairs({ "player", "enemy" }) do
    f.set_cease_fire(other, true)
    game.forces[other].set_cease_fire(f, true)
  end
  return f
end

--- Nom d'un état d'entité (defines.entity_status), pour le journal.
local function status_name(v)
  if v == nil then return "aucun" end
  local names = {}
  for k in pairs(defines.entity_status) do names[#names + 1] = k end
  table.sort(names)
  for _, k in ipairs(names) do if defines.entity_status[k] == v then return k end end
  return tostring(v)
end
M.status_name = status_name

local function near(a, b) return math.abs(a - b) < 1e-6 end
--- Boîtes rangées en virgule fixe par le moteur (1/256 de tuile) : tolérance d'un 64e de tuile.
local function close(a, b) return math.abs(a - b) < 1 / 64 end
local function fmt(p) return string.format("%g, %g", p.x, p.y) end

--- Range une fois le coût du niveau n de la famille ; true si tout est entré.
local function stock(inv, family, n)
  local all = true
  for _, c in ipairs(LV.cost(family, n)) do
    if inv.insert({ name = c[1], count = c[2] }) < c[2] then all = false end
  end
  return all
end

--- Relevé des quantités des objets du coût du niveau n dans `inv`.
local function counts(inv, family, n)
  local t = {}
  for _, c in ipairs(LV.cost(family, n)) do t[c[1]] = inv.get_item_count(c[1]) end
  return t
end

local function same_counts(a, b)
  for k, v in pairs(a) do if b[k] ~= v then return false end end
  return true
end

--- Candidate de rang k de la règle pour passer du carré de côté a autour de `pos` au côté b.
local function expected(pos, a, b, k)
  return Foot.candidates(Foot.tile_box(pos, a), b)[k or 1]
end

--- Le bâtiment `e` occupe-t-il exactement la candidate `c` (position et boîte de sélection) ?
local function at_candidate(e, c, side)
  if not (e and e.valid and c) then return false end
  local sel = e.prototype.selection_box
  return near(e.position.x, c.x) and near(e.position.y, c.y) and close(sel.right_bottom.x - sel.left_top.x, side)
end

--- Rectangles de rendu du mod dont le coin nord-ouest est dans la zone.
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

local function has_rect(list, box)
  for _, r in ipairs(list) do
    if near(r.x0, box.x0) and near(r.y0, box.y0) and near(r.x1, box.x1) and near(r.y1, box.y1) then return true end
  end
  return false
end

--- Couches d'un masque (dictionnaire) partagées avec un autre masque ?
local function shares(a, b)
  if not (a and b) then return false end
  local keys = {}
  for k in pairs(a) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do if b[k] then return true end end
  return false
end

local SKIP = { character = true, unit = true, ["item-entity"] = true, ["entity-ghost"] = true, resource = true }

--- Retire ce qui gêne la position du contour `box` (carré de tuiles) pour le prototype `name` : les entités dont la
--- boîte touche la boîte de collision du carré et qui partagent une couche avec le prototype, sauf `self`. Renvoie
--- la liste triée de leurs noms (à comparer aux gênes annoncées par le refus).
local function free_contour(s, self, box, name)
  local rect = Foot.collision_rect(box)
  local mask = game.entity_prototypes[name].collision_mask
  local gone = {}
  for _, e in ipairs(s.find_entities_filtered({ area = { { rect.x0, rect.y0 }, { rect.x1, rect.y1 } } })) do
    if e.valid and e ~= self and not SKIP[e.type] and shares(mask, e.prototype.collision_mask) then
      local bb = e.bounding_box
      if Foot.overlap(rect, { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y }) then
        gone[#gone + 1] = e.name
        e.destroy()
      end
    end
  end
  table.sort(gone)
  return gone
end

local function ins(s, f, x, y, dir)
  return s.create_entity({ name = "inserter", position = { x, y }, direction = dir, force = f, raise_built = true })
end

local function belt(s, f, x, y, dir)
  return s.create_entity({ name = "transport-belt", position = { x, y }, direction = dir, force = f, raise_built = true })
end

local function ore(s, x, y, amount)
  return s.create_entity({ name = "iron-ore", position = { x, y }, amount = amount })
end

local function put(s, f, family, n, x, y, dir)
  return s.create_entity({ name = LV.name(family, n), position = { x, y }, direction = dir, force = f, raise_built = true })
end

---------------------------------------------------------------------------------------------------
-- Installation (création de la carte)
---------------------------------------------------------------------------------------------------
function M.setup(ctx)
  local z, s = ctx.zone, ctx.surface()
  local st = ctx.state()
  local f = make_force(FORCE)
  for _, r in ipairs({ RECIPE, SLOW, "iron-gear-wheel" }) do if f.recipes[r] then f.recipes[r].enabled = true end end
  local N, E, S, W = defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west
  local x0, y0 = z.x0, z.y0
  st.cc = s.create_entity({ name = LV.name(CC, 15), position = { x0 + 6, y0 + 6 }, force = f, raise_built = true })
  ctx.power(x0 + 64, y0 + 48, f)
  local made = {}
  local function keep(key, e) st[key] = e; if e then made[#made + 1] = key end; return e end

  -- A. Place libre ----------------------------------------------------------------------------------
  local ya = y0 + 22.5
  -- Assembleur (centre de tuile : côté 3) ; bras à l'ouest qui prend dans un coffre.
  local a = keep("as", put(s, f, AS, 6, x0 + 16.5, ya, N))
  if a then
    a.set_recipe(RECIPE)
    a.get_inventory(defines.inventory.assembling_machine_input).insert({ name = "empty-barrel", count = 20 })
    a.get_inventory(defines.inventory.assembling_machine_output).insert({ name = "water-barrel", count = 3 })
    if game.item_prototypes[MODULE] then a.get_inventory(defines.inventory.assembling_machine_modules).insert({ name = MODULE, count = 2 }) end
    a.fluidbox[1] = { name = "water", amount = 30 } -- moins que les 50 d'une fabrication : rien ne se fabrique
    a.health = a.prototype.max_health * 0.6
  end
  keep("as_ins", ins(s, f, x0 + 14.5, ya, W))
  local chest_a = keep("as_chest", s.create_entity({ name = "iron-chest", position = { x0 + 13.5, ya }, force = f, raise_built = true }))
  if chest_a then chest_a.insert({ name = "empty-barrel", count = 100 }) end
  -- Foreuse D1 sur un gisement 5×5, coffre au point de dépôt, combinateur relié par un fil rouge (condition A > 0).
  local xd = x0 + 32.5
  for dx = -2, 2 do for dy = -2, 2 do ore(s, xd + dx, ya + dy, 5000) end end
  local d1 = keep("d1", put(s, f, DR, 6, xd, ya, N))
  local comb = keep("d1_comb", s.create_entity({ name = "constant-combinator", position = { xd - 3, ya - 3 }, force = f, raise_built = true }))
  if d1 and comb then
    keep("d1_chest", s.create_entity({ name = "iron-chest", position = d1.drop_position, force = f, raise_built = true }))
    comb.get_or_create_control_behavior().set_signal(1, { signal = { type = "virtual", name = "signal-A" }, count = 5 })
    st.d1_wire = d1.connect_neighbour({ wire = defines.wire_type.red, target_entity = comb })
    local cb = d1.get_or_create_control_behavior()
    cb.circuit_enable_disable = true
    cb.circuit_condition = { condition = { comparator = ">", first_signal = { type = "virtual", name = "signal-A" }, constant = 0 } }
    cb.circuit_read_resources = true
    cb.resource_read_mode = defines.control_behavior.mining_drill.resource_read_mode.entire_patch
    d1.health = d1.prototype.max_health * 0.7
  end
  -- Foreuse D2 sans minerai sous sa zone : un seul minerai, dans la bande que seule la zone agrandie couvre.
  local xd2 = x0 + 52.5
  local d2 = keep("d2", put(s, f, DR, 6, xd2, ya, N))
  if d2 then
    keep("d2_chest", s.create_entity({ name = "iron-chest", position = d2.drop_position, force = f, raise_built = true }))
    -- Zone de la 4×4 retenue (rang 1) : centre + rayon du prototype du niveau 7 ; zone de la 3×3 : rayon du 6.
    local c7 = expected(d2.position, 3, 4)
    local r7 = game.entity_prototypes[LV.name(DR, 7)].mining_drill_radius
    local r6 = d2.prototype.mining_drill_radius
    -- Tuile au coin sud-est de la zone agrandie (son centre doit être dans la nouvelle zone, hors de l'ancienne).
    local ox, oy = math.floor(c7.x + r7) + 0.5, math.floor(c7.y + r7) + 0.5
    st.d2_ore_pos = { x = ox, y = oy }
    st.d2_ore_inside_old = math.abs(ox - d2.position.x) <= r6 + 0.1 and math.abs(oy - d2.position.y) <= r6 + 0.1
    keep("d2_ore", ore(s, ox, oy, 5000))
  end
  -- Four : combustible et minerai, bras au nord qui prend dans un coffre (bloque les deux positions nord).
  local xf = x0 + 72
  local fu = keep("fu", put(s, f, FU, 6, xf, ya - 0.5))
  if fu then
    fu.get_inventory(defines.inventory.fuel).insert({ name = "coal", count = 10 })
    fu.get_inventory(defines.inventory.furnace_source).insert({ name = "iron-ore", count = 5 })
    fu.health = fu.prototype.max_health * 0.8
  end
  keep("fu_ins", ins(s, f, xf - 0.5, ya - 2, N))
  local chest_f = keep("fu_chest", s.create_entity({ name = "iron-chest", position = { xf - 0.5, ya - 3 }, force = f, raise_built = true }))
  if chest_f then chest_f.insert({ name = "iron-ore", count = 200 }) end
  -- Laser : victimes et dégâts infligés inscrits, PV à moitié (énergie : tampon chargé par le réseau invisible).
  local lz = keep("lz", put(s, f, LZ, 6, x0 + 92, ya - 0.5))
  if lz then
    lz.kills = 7
    lz.damage_dealt = 1234.5
    lz.health = lz.prototype.max_health * 0.5
  end
  -- Assembleur EN FABRICATION au tick ACT (moteurs : 10 s par fabrication, nourri par un bras) : bilan de matière
  -- (une fabrication en cours a déjà pris ses ingrédients ; le transfert ne doit ni les perdre ni en créer).
  local a2 = keep("as2", put(s, f, AS, 6, x0 + 112.5, ya, N))
  if a2 then a2.set_recipe(SLOW) end
  keep("as2_ins", ins(s, f, x0 + 110.5, ya, W))
  local chest_a2 = keep("as2_chest", s.create_entity({ name = "iron-chest", position = { x0 + 109.5, ya }, force = f, raise_built = true }))
  if chest_a2 then
    chest_a2.insert({ name = "steel-plate", count = 100 })
    chest_a2.insert({ name = "iron-gear-wheel", count = 100 })
    chest_a2.insert({ name = "pipe", count = 200 })
  end
  -- Sortie : bras au nord vers un coffre (une machine à engrenages sans sortie s'arrêtait « sortie pleine » à 4
  -- engrenages, observé au premier essai).
  keep("as2_out", ins(s, f, x0 + 112.5, ya - 2, S))
  keep("as2_outchest", s.create_entity({ name = "iron-chest", position = { x0 + 112.5, ya - 3 }, force = f, raise_built = true }))
  ctx.check(#made == 18, "A : assembleurs, 2 foreuses, four et laser de niveau 6 poses avec bras, coffres, combinateur et minerai",
    #made .. " objets ; minerai de D2 en " .. (st.d2_ore_pos and fmt(st.d2_ore_pos) or "?") .. (st.d2_ore_inside_old and " (DANS l'ancienne zone)" or " (hors de l'ancienne zone)"))
  -- Les cibles d'un bras ne sont calculées qu'à sa première mise à jour (au tick ACT : contrôle « avant ») ; ici, ses
  -- points de prise et de dépôt.
  ctx.check(st.as_ins and st.fu_ins and st.d1_wire == true,
    "A : bras de l'assembleur (ouest) et du four (nord) poses, fil rouge foreuse-combinateur pose",
    string.format("bras assembleur %s -> %s, bras four %s -> %s", st.as_ins and fmt(st.as_ins.pickup_position) or "-",
      st.as_ins and fmt(st.as_ins.drop_position) or "-", st.fu_ins and fmt(st.fu_ins.pickup_position) or "-", st.fu_ins and fmt(st.fu_ins.drop_position) or "-"))

  -- B. Usine dense --------------------------------------------------------------------------------------
  local yb = y0 + 50.5
  st.dense = {}
  -- B1 : trois assembleurs collés, bras au nord (entrée) et au sud (sortie), convoyeurs au-delà.
  for i = 0, 2 do
    local x = x0 + 16.5 + 3 * i
    local m = put(s, f, AS, 6, x, yb, N)
    if m then m.set_recipe("iron-gear-wheel") end
    ins(s, f, x, yb - 2, N)
    ins(s, f, x, yb + 2, N)
    if i == 1 then st.dense.as = m end
  end
  for x = x0 + 14.5, x0 + 24.5 do belt(s, f, x, yb - 3, E); belt(s, f, x, yb + 3, E) end
  -- B2 : colonne de trois fours, bras à l'ouest (entrée) et à l'est (sortie), convoyeurs au-delà.
  local xc = x0 + 42
  for i = 0, 2 do
    local y = yb - 1.5 + 2 * i
    local m = put(s, f, FU, 6, xc, y)
    ins(s, f, xc - 1.5, y - 0.5, W)
    ins(s, f, xc + 1.5, y + 0.5, W)
    if i == 1 then st.dense.fu = m end
  end
  for y = yb - 3, yb + 4 do belt(s, f, xc - 2.5, y, S); belt(s, f, xc + 2.5, y, S) end
  -- B3 : trois foreuses collées devant leur convoyeur (au nord), sur le minerai.
  local xr = x0 + 56.5
  for dx = -2, 10 do for dy = -1, 2 do ore(s, xr + dx, yb + dy, 5000) end end
  for i = 0, 2 do
    local m = put(s, f, DR, 6, xr + 3 * i, yb, N)
    if i == 1 then st.dense.dr = m end
  end
  for x = xr - 2, xr + 8 do belt(s, f, x, yb - 2, E) end
  -- B4 : trois lasers collés derrière une ligne de murs.
  local xl = x0 + 76
  for i = 0, 2 do
    local m = put(s, f, LZ, 6, xl + 2 * i, yb - 0.5)
    if i == 1 then st.dense.lz = m end
  end
  for x = xl - 3.5, xl + 5.5 do s.create_entity({ name = "stone-wall", position = { x, yb - 3 }, force = f, raise_built = true }) end
  -- B5 : centre 3 (4×4) d'une force à part, un bras sur chaque côté (comme une usine qui le remplit), coffres derrière.
  local f2 = make_force(FORCE_CC2)
  local xcc = x0 + 100
  local c2 = s.create_entity({ name = LV.name(CC, 3), position = { xcc, yb + 0.5 }, force = f2, raise_built = true })
  st.dense.cc = c2
  if c2 then stock(c2.get_inventory(defines.inventory.chest), CC, 4) end
  ins(s, f2, xcc - 0.5, yb - 2, N)
  s.create_entity({ name = "iron-chest", position = { xcc - 0.5, yb - 3 }, force = f2 })
  ins(s, f2, xcc + 0.5, yb + 3, S)
  s.create_entity({ name = "iron-chest", position = { xcc + 0.5, yb + 4 }, force = f2 })
  ins(s, f2, xcc - 2.5, yb, W)
  s.create_entity({ name = "iron-chest", position = { xcc - 3.5, yb }, force = f2 })
  ins(s, f2, xcc + 2.5, yb + 1, E)
  s.create_entity({ name = "iron-chest", position = { xcc + 3.5, yb + 1 }, force = f2 })
  ctx.check(st.dense.as and st.dense.fu and st.dense.dr and st.dense.lz and st.dense.cc,
    "B : usine dense posee (assembleurs, fours, foreuses, lasers colles, bras et convoyeurs ; centre 3 entoure de bras)")

  -- C. Chaînes --------------------------------------------------------------------------------------------
  local yc = y0 + 78
  st.chain = {
    { key = "laser", e = put(s, f, LZ, 6, x0 + 16, yc) },
    { key = "drill", e = put(s, f, DR, 6, x0 + 30.5, yc + 0.5) },
    { key = "furnace", e = put(s, f, FU, 6, x0 + 44, yc) },
    { key = "assembler", e = put(s, f, AS, 6, x0 + 58.5, yc + 0.5) },
  }
  local cf = st.chain[3].e
  if cf then cf.get_inventory(defines.inventory.fuel).insert({ name = "coal", count = 5 }) end
  local ca = st.chain[4].e
  if ca then
    ca.set_recipe("iron-gear-wheel")
    ca.insert({ name = "iron-plate", count = 10 })
  end
  local f1 = make_force(FORCE_CC1)
  st.cc_chain = s.create_entity({ name = LV.name(CC, 1), position = { x0 + 78, yc }, force = f1, raise_built = true })
  if st.cc_chain then
    local inv = st.cc_chain.get_inventory(defines.inventory.chest)
    inv.insert({ name = "wooden-chest", count = 9 })
    inv.insert({ name = "coal", count = 50 })
  end
  ctx.check(st.chain[1].e and st.chain[2].e and st.chain[3].e and st.chain[4].e and st.cc_chain,
    "C : laser, foreuse, four et assembleur au niveau 6, centre 1 d'une force a part, poses pour les chaines")
end

---------------------------------------------------------------------------------------------------
-- Agrandissements (tick ACT)
---------------------------------------------------------------------------------------------------
local function status(ctx) return ctx.call("levels_status", FORCE) end

--- Amélioration d'un bâtiment du niveau n au niveau n + 1 avec le coût rangé dans le centre de la force.
local function up(ctx, e, inv)
  local family, n = LV.parse(e.name)
  stock(inv, family, n + 1)
  return ctx.call("levels_upgrade", e)
end

--- Objets `item` dans la main d'un bras.
local function held(insr, item)
  local h = insr and insr.valid and insr.held_stack
  return (h and h.valid_for_read and h.name == item) and h.count or 0
end

--- Bilan de fer du four : minerai du coffre, de l'entrée et de la main du bras, plaques, plus 1 pour une fusion en
--- cours (son minerai est déjà pris). Constant dans le temps tant que rien ne se perd.
function M.iron_balance(st, f)
  local crafting = f.is_crafting() and 1 or 0
  return st.fu_chest.get_item_count("iron-ore") + f.get_inventory(defines.inventory.furnace_source).get_item_count("iron-ore")
    + f.get_inventory(defines.inventory.furnace_result).get_item_count("iron-plate") + crafting + held(st.fu_ins, "iron-ore"), crafting
end

--- Bilan d'acier de l'assembleur à moteurs (1 plaque d'acier par moteur, 1 pour une fabrication en cours) : coffre,
--- entrée, main des deux bras, moteurs de la sortie et du coffre de sortie.
function M.steel_balance(st, a)
  local crafting = a.is_crafting() and 1 or 0
  return st.as2_chest.get_item_count("steel-plate") + a.get_inventory(defines.inventory.assembling_machine_input).get_item_count("steel-plate")
    + a.get_inventory(defines.inventory.assembling_machine_output).get_item_count("engine-unit") + crafting
    + held(st.as2_ins, "steel-plate") + held(st.as2_out, "engine-unit") + st.as2_outchest.get_item_count("engine-unit"), crafting
end

local function section_a(ctx, inv)
  local st = ctx.state()
  local s = ctx.surface()
  local s0 = status(ctx)

  -- Avant : les bras nourrissent bien les machines de niveau 6 (cible de dépôt calculée par le moteur).
  ctx.check(st.as_ins.drop_target == st.as and st.fu_ins.drop_target == st.fu,
    "avant : le bras de l'assembleur et celui du four visent leur machine de niveau 6",
    (st.as_ins.drop_target and st.as_ins.drop_target.name or "rien") .. ", " .. (st.fu_ins.drop_target and st.fu_ins.drop_target.name or "rien"))

  -- Assembleur.
  local a = st.as
  local want = expected(a.position, 3, 4)
  local ainv = a.get_inventory(defines.inventory.assembling_machine_input)
  local before = { barrels = ainv.get_item_count("empty-barrel"),
    out = a.get_inventory(defines.inventory.assembling_machine_output).get_item_count("water-barrel"),
    modules = a.get_inventory(defines.inventory.assembling_machine_modules).get_item_count(MODULE),
    water = a.fluidbox[1] and a.fluidbox[1].amount or 0, ratio = a.get_health_ratio() }
  -- Pas d'écriture de crafting_progress ici : sur une machine à l'arrêt, elle crée une fabrication fantôme
  -- (is_crafting() devient vrai sans ingrédients pris ; observé au premier essai, F84). La progression d'une vraie
  -- fabrication en cours est contrôlée sur le four et sur l'assembleur à moteurs.
  before.progress = a.crafting_progress
  local ra = up(ctx, a, inv)
  local a7 = ra.entity
  st.as7 = a7
  ctx.check(ra.ok and a7 and a7.valid and a7.name == LV.name(AS, 7) and not a.valid and ra.candidate == 1 and at_candidate(a7, want, 4),
    "assembleur 6 -> 7 : agrandi sur place en 4x4 a la position preferee (sud-est), ancien objet disparu",
    tostring(ra.reason) .. (a7 and a7.valid and (" en " .. fmt(a7.position) .. " (attendu " .. fmt(want) .. ")") or ""))
  if a7 and a7.valid then
    local r = a7.get_recipe()
    local after = { barrels = a7.get_inventory(defines.inventory.assembling_machine_input).get_item_count("empty-barrel"),
      out = a7.get_inventory(defines.inventory.assembling_machine_output).get_item_count("water-barrel"),
      modules = a7.get_inventory(defines.inventory.assembling_machine_modules).get_item_count(MODULE),
      water = a7.fluidbox[1] and a7.fluidbox[1].amount or 0, progress = a7.crafting_progress, ratio = a7.get_health_ratio() }
    ctx.check(r and r.name == RECIPE and after.barrels == before.barrels and after.out == before.out and after.modules == before.modules
      and math.abs(after.water - before.water) < 1e-6 and math.abs(after.progress - before.progress) < 1e-6
      and math.abs(after.ratio - before.ratio) < 0.01,
      "assembleur : recette, ingredients, produits, eau de la boite a fluide, modules, progression et PV transferes",
      string.format("recette %s ; barils vides %d/%d ; barils pleins %d/%d ; modules %d/%d ; eau %.1f/%.1f ; progression %.2f/%.2f ; PV %.2f/%.2f",
        r and r.name or "aucune", after.barrels, before.barrels, after.out, before.out, after.modules, before.modules, after.water, before.water,
        after.progress, before.progress, after.ratio, before.ratio))
    -- Tuyau infini au NOUVEAU raccord d'entrée (lu sur l'entité : position visée par la connexion).
    local conns = a7.fluidbox.get_pipe_connections(1)
    local c1 = conns and conns[1]
    st.as_pipe_pos = c1 and c1.target_position
    local pipe = c1 and s.create_entity({ name = "infinity-pipe", position = c1.target_position, force = a7.force, raise_built = true })
    if pipe then pipe.set_infinity_pipe_filter({ name = "water", percentage = 1 }) end
    st.as_pipe = pipe
    st.as_done0 = a7.products_finished
    st.as_chest0 = st.as_chest.get_item_count("empty-barrel")
    local box = Foot.collision_rect(Foot.tile_box(a7.position, 4))
    ctx.check(pipe ~= nil and c1 and (c1.target_position.y < box.y0 or c1.target_position.y > box.y1 or c1.target_position.x < box.x0 or c1.target_position.x > box.x1),
      "assembleur : tuyau pose au nouveau raccord d'entree, hors de la boite 4x4",
      c1 and ("raccord " .. fmt(c1.position) .. " -> tuyau en " .. fmt(c1.target_position) .. " ; " .. #conns .. " connexion(s)") or "aucune connexion")
  end

  -- Foreuse D1 : circuit, progression, dépôt.
  local d1 = st.d1
  local wd = expected(d1.position, 3, 4)
  local cb = d1.get_control_behavior()
  local b1 = { prog = d1.mining_progress, ratio = d1.get_health_ratio(), read = cb.circuit_read_resources, mode = cb.resource_read_mode,
    en = cb.circuit_enable_disable, cond = cb.circuit_condition.condition }
  local rd = up(ctx, d1, inv)
  local d7 = rd.entity
  st.d17 = d7
  ctx.check(rd.ok and d7 and d7.valid and not d1.valid and rd.candidate == 1 and at_candidate(d7, wd, 4),
    "foreuse 6 -> 7 : agrandie sur place en 4x4 (sud-est), ancien objet disparu", tostring(rd.reason) .. (d7 and (" en " .. fmt(d7.position)) or ""))
  if d7 and d7.valid then
    local nb = d7.get_control_behavior()
    local red = d7.circuit_connected_entities and d7.circuit_connected_entities.red or {}
    local wired = false
    for _, e in ipairs(red) do if e == st.d1_comb then wired = true end end
    local c = nb and nb.circuit_condition.condition
    ctx.check(nb and nb.circuit_read_resources == b1.read and nb.resource_read_mode == b1.mode and nb.circuit_enable_disable == b1.en
      and c and c.comparator == ">" and c.first_signal and c.first_signal.name == "signal-A" and c.constant == 0 and wired,
      "foreuse : fil rouge vers le combinateur et reglages du circuit transferes (lecture du gisement, condition A > 0)",
      string.format("lecture %s, mode %s, condition %s %s %s, fil %s", tostring(nb and nb.circuit_read_resources), tostring(nb and nb.resource_read_mode),
        c and c.first_signal and c.first_signal.name or "-", c and c.comparator or "-", c and tostring(c.constant) or "-", tostring(wired)))
    ctx.check(math.abs(d7.mining_progress - b1.prog) < 1e-6 and math.abs(d7.get_health_ratio() - b1.ratio) < 0.01,
      "foreuse : progression d'extraction et PV transferes", string.format("progression %.3f/%.3f, PV %.2f/%.2f", d7.mining_progress, b1.prog, d7.get_health_ratio(), b1.ratio))
    st.d1_ore0 = st.d1_chest.get_item_count("iron-ore")
    st.d1_drop = d7.drop_position
  end

  -- Foreuse D2 : zone d'extraction agrandie.
  local d2 = st.d2
  local wd2 = expected(d2.position, 3, 4)
  st.d2_target_before = d2.mining_target and d2.mining_target.valid and fmt(d2.mining_target.position) or "aucune"
  local rd2 = up(ctx, d2, inv)
  st.d27 = rd2.entity
  ctx.check(rd2.ok and st.d27 and st.d27.valid and rd2.candidate == 1 and at_candidate(st.d27, wd2, 4) and st.d2_target_before == "aucune",
    "foreuse sans minerai sous son ancienne zone : agrandie en 4x4 (avant : aucune cible de minage)",
    tostring(rd2.reason) .. " ; cible avant : " .. st.d2_target_before)

  -- Four : combustible, entrée, sortie, progression, brûleur.
  local fu = st.fu
  local wf = expected(fu.position, 2, 3, 3)
  local function snap(e)
    local b = e.burner
    return { fuel = e.get_inventory(defines.inventory.fuel).get_item_count("coal"),
      src = e.get_inventory(defines.inventory.furnace_source).get_item_count("iron-ore"),
      res = e.get_inventory(defines.inventory.furnace_result).get_item_count("iron-plate"),
      prog = e.crafting_progress, burning = b and b.currently_burning and b.currently_burning.name or "-",
      rem = b and b.remaining_burning_fuel or 0, heat = b and b.heat or 0, ratio = e.get_health_ratio() }
  end
  local bf = snap(fu)
  st.fu_balance0, st.fu_crafting0 = M.iron_balance(st, fu)
  local rf = up(ctx, fu, inv)
  local f7 = rf.entity
  st.fu7 = f7
  if f7 and f7.valid then st.fu_balance1 = M.iron_balance(st, f7) end
  ctx.check(rf.ok and f7 and f7.valid and not fu.valid and rf.candidate == 3 and at_candidate(f7, wf, 3),
    "four 6 -> 7 : bras au nord, les deux positions nord bloquees : agrandi en 3x3 a la 3e (sud-ouest)",
    tostring(rf.reason) .. " ; rang " .. tostring(rf.candidate) .. (f7 and (" en " .. fmt(f7.position) .. " (attendu " .. fmt(wf) .. ")") or ""))
  if f7 and f7.valid then
    local af = snap(f7)
    -- Fusion en cours : son minerai (déjà pris par le moteur) est rendu à l'entrée, la progression est reposée au
    -- tick suivant (contrôlée à ACT + 2, M.after).
    ctx.check(af.fuel == bf.fuel and af.src == bf.src + st.fu_crafting0 and af.res == bf.res and af.burning == bf.burning
      and math.abs(af.rem - bf.rem) < 1e-3 and math.abs(af.ratio - bf.ratio) < 0.01 and st.fu_crafting0 == 1 and bf.prog > 0 and bf.rem > 0,
      "four : combustible, minerai (+ celui de la fusion en cours, rendu), plaques, combustible en train de bruler et PV transferes",
      string.format("charbon %d/%d, minerai %d/%d+%d, plaques %d/%d, brule %s/%s (reste %.0f/%.0f J), PV %.2f/%.2f ; progression avant %.3f",
        af.fuel, bf.fuel, af.src, bf.src, st.fu_crafting0, af.res, bf.res, af.burning, bf.burning, af.rem, bf.rem, af.ratio, bf.ratio, bf.prog))
    st.fu_prog0 = bf.prog
    st.fu_res0 = af.res
    st.fu_chest0 = st.fu_chest.get_item_count("iron-ore")
  end

  -- Laser : énergie, statistiques, portée.
  local lz = st.lz
  local wl = expected(lz.position, 2, 3)
  local bl = { energy = lz.energy, kills = lz.kills, dealt = lz.damage_dealt, ratio = lz.get_health_ratio() }
  local rl = up(ctx, lz, inv)
  local l7 = rl.entity
  st.lz7 = l7
  ctx.check(rl.ok and l7 and l7.valid and not lz.valid and rl.candidate == 1 and at_candidate(l7, wl, 3),
    "laser 6 -> 7 : agrandi sur place en 3x3 (nord-ouest), ancien objet disparu", tostring(rl.reason) .. (l7 and (" en " .. fmt(l7.position)) or ""))
  if l7 and l7.valid then
    ctx.check(bl.energy > 0 and math.abs(l7.energy - bl.energy) < 1e-3 and l7.kills == bl.kills and math.abs(l7.damage_dealt - bl.dealt) < 1e-3
      and math.abs(l7.get_health_ratio() - bl.ratio) < 0.01,
      "laser : energie du tampon, victimes, degats infliges et PV transferes",
      string.format("energie %.0f/%.0f J, victimes %d/%d, degats %.1f/%.1f, PV %.2f/%.2f", l7.energy, bl.energy, l7.kills, bl.kills,
        l7.damage_dealt, bl.dealt, l7.get_health_ratio(), bl.ratio))
    local want_range = LV.apply_stat(LZ.stats[3], game.entity_prototypes[LZ.base].turret_range, 7) + LV.range_bonus(LZ, 7)
    ctx.check(math.abs(l7.prototype.turret_range - want_range) < 1e-4 and LV.range_bonus(LZ, 7) == 0.5,
      "laser 7 : portee = statistique du niveau + (3 - 2) / 2 (mesuree depuis le centre)",
      string.format("%.2f (attendu %.2f)", l7.prototype.turret_range, want_range))
  end
  -- Assembleur en pleine fabrication : progression et bilan de plaques.
  local a2 = st.as2
  local wa2 = expected(a2.position, 3, 4)
  local b2 = { prog = a2.crafting_progress, crafting = a2.is_crafting() }
  ctx.log(string.format("assembleur en fabrication au tick %d : etat %s, recette %s, produits %d ; bras etat %s",
    game.tick, status_name(a2.status), tostring(a2.get_recipe() and a2.get_recipe().name), a2.products_finished, status_name(st.as2_ins.status)))
  st.as2_balance0 = M.steel_balance(st, a2)
  local r2 = up(ctx, a2, inv)
  st.as27 = r2.entity
  ctx.check(r2.ok and st.as27 and st.as27.valid and at_candidate(st.as27, wa2, 4) and b2.crafting and b2.prog > 0,
    "assembleur en pleine fabrication 6 -> 7 : agrandi en 4x4", string.format("%s ; avant : fabrication %s, progression %.3f", tostring(r2.reason),
      tostring(b2.crafting), b2.prog))
  if st.as27 and st.as27.valid then
    st.as2_balance1 = M.steel_balance(st, st.as27)
    st.as2_prog = { before = b2.prog, after = st.as27.crafting_progress, crafting_after = st.as27.is_crafting() }
  end
  local s1 = status(ctx)
  ctx.check(s1.resized == s0.resized + 6 and s1.fallback == s0.fallback and s1.spilled == s0.spilled and s1.resize_failed == s0.resize_failed,
    "A : 6 agrandissements par script, 0 secours, rien renverse",
    string.format("resized +%d, fallback +%d, spilled %d", s1.resized - s0.resized, s1.fallback - s0.fallback, s1.spilled))
end

--- Refus « no-room » d'un bâtiment cerné, puis agrandissement après avoir retiré ce que le contour désigne.
local function dense_case(ctx, label, e, pay_inv)
  local s = ctx.surface()
  local family, n = LV.parse(e.name)
  local a, b = LV.footprint(family, n), LV.footprint(family, n + 1)
  stock(pay_inv, family, n + 1)
  local c0 = counts(pay_inv, family, n + 1)
  local r = ctx.call("levels_upgrade", e)
  local unpaid = same_counts(c0, counts(pay_inv, family, n + 1))
  local rects = rectangles(ctx.zone)
  local drawn = r.contour and has_rect(rects, r.contour)
  local bl = table.concat(r.blockers or {}, ",")
  ctx.check(not r.ok and r.reason == "no-room" and e.valid and unpaid and drawn,
    label .. " cerne(e) : refus « no-room », cout NON paye, contour " .. b .. "x" .. b .. " dessine",
    tostring(r.reason) .. " ; contour rang " .. tostring(r.contour_candidate) .. " ; gene : " .. bl)
  if not (r.contour and e.valid) then return end
  local gone = free_contour(s, e, r.contour, LV.name(family, n + 1))
  local want = Foot.candidates(Foot.tile_box(e.position, a), b)[r.contour_candidate]
  local r2 = ctx.call("levels_upgrade", e)
  ctx.check(table.concat(gone, ",") == bl and r2.ok and r2.candidate == r.contour_candidate and at_candidate(r2.entity, want, b),
    label .. " : ce que le contour designait retire (exactement les genes annoncees), agrandissement a la position du contour",
    "retire : " .. table.concat(gone, ",") .. " ; " .. tostring(r2.reason) .. (r2.entity and (" en " .. fmt(r2.entity.position)) or ""))
  return r2.entity
end

--- Chaîne d'améliorations jusqu'au niveau `top` ; inv_of(bâtiment courant) = inventaire qui paie (le coffre du
--- centre change d'entité à chaque pas de la chaîne du centre).
local function chain(ctx, label, e, inv_of, top)
  local family, n0 = LV.parse(e.name)
  local s0 = status(ctx)
  local resizes, cur, why = 0, e, nil
  local trail = {}
  for n = n0 + 1, top do
    if LV.footprint(family, n) ~= LV.footprint(family, n - 1) then resizes = resizes + 1 end
    stock(inv_of(cur), family, n)
    local r = ctx.call("levels_upgrade", cur)
    if not (r.ok and r.entity and r.entity.valid) then why = n .. " : " .. tostring(r.reason) break end
    cur = r.entity
    if LV.footprint(family, n) ~= LV.footprint(family, n - 1) then trail[#trail + 1] = LV.footprint(family, n) .. "@" .. fmt(cur.position) end
  end
  local s1 = status(ctx)
  local sel = cur.valid and cur.prototype.selection_box
  ctx.check(not why and cur.name == LV.name(family, top) and s1.resized - s0.resized == resizes and s1.fallback == s0.fallback
    and close(sel.right_bottom.x - sel.left_top.x, LV.footprint(family, top)),
    label .. " : chaine " .. n0 .. " -> " .. top .. ", " .. resizes .. " agrandissements par script, le reste en remplacement rapide moteur (F39), 0 secours",
    why or (table.concat(trail, " ") .. string.format(" ; resized +%d, fallback +%d", s1.resized - s0.resized, s1.fallback - s0.fallback)))
  return cur, not why
end

function M.act(ctx)
  local st = ctx.state()
  if st.done then return end
  st.done = true
  local inv = st.cc and st.cc.valid and st.cc.get_inventory(defines.inventory.chest)
  if not inv then
    ctx.fail("centre 15 de la force " .. FORCE .. " introuvable")
    return
  end
  section_a(ctx, inv)

  -- B. Usine dense.
  local D = st.dense
  st.dense_after = {
    as = D.as and D.as.valid and dense_case(ctx, "assembleur", D.as, inv),
    fu = D.fu and D.fu.valid and dense_case(ctx, "four", D.fu, inv),
    dr = D.dr and D.dr.valid and dense_case(ctx, "foreuse", D.dr, inv),
    lz = D.lz and D.lz.valid and dense_case(ctx, "laser", D.lz, inv),
    cc = D.cc and D.cc.valid and dense_case(ctx, "centre 3", D.cc, D.cc.get_inventory(defines.inventory.chest)),
  }
  local c2 = st.dense_after.cc
  ctx.check(c2 and c2.valid and c2.name == LV.name(CC, 4) and ctx.call("levels_status", FORCE_CC2).cc_level == 4,
    "centre 3 -> 4 (4x4 -> 5x5) : centre toujours suivi par sa force", c2 and c2.valid and fmt(c2.position) or "introuvable")

  -- C. Chaînes.
  local ca = st.chain[4].e
  local plates0 = ca.get_item_count("iron-plate") + 2 * ca.get_item_count("iron-gear-wheel")
  local fuel0 = st.chain[3].e.get_item_count("coal")
  for _, c in ipairs(st.chain) do
    c.final = chain(ctx, c.key, c.e, function() return inv end, 30)
  end
  local fa, ff = st.chain[4].final, st.chain[3].final
  local recipe = fa.valid and fa.get_recipe()
  ctx.check(recipe and recipe.name == "iron-gear-wheel" and fa.get_item_count("iron-plate") + 2 * fa.get_item_count("iron-gear-wheel") == plates0
    and ff.valid and ff.get_item_count("coal") == fuel0,
    "chaines : recette et contenu de l'assembleur, charbon du four conserves jusqu'au niveau 30",
    string.format("plaques + 2 x engrenages %d/%d, charbon %d/%d", fa.get_item_count("iron-plate") + 2 * fa.get_item_count("iron-gear-wheel"), plates0,
      ff.valid and ff.get_item_count("coal") or -1, fuel0))
  -- Centre 1 -> 15 (force à part, aucune autre famille possédée : la condition Q16 ne bloque pas).
  local cc = st.cc_chain
  local cinv = cc.get_inventory(defines.inventory.chest)
  local wood0, coal0 = cinv.get_item_count("wooden-chest"), cinv.get_item_count("coal")
  local final = chain(ctx, "centre", cc, function(cur) return cur.get_inventory(defines.inventory.chest) end, 15)
  st.cc_final = final
  local fin = final.valid and final.get_inventory(defines.inventory.chest)
  local sel = final.valid and final.prototype.selection_box
  ctx.check(fin and fin.get_item_count("wooden-chest") == wood0 and fin.get_item_count("coal") == coal0
    and ctx.call("levels_status", FORCE_CC1).cc_level == 15 and close(sel.right_bottom.x - sel.left_top.x, 8),
    "centre 15 en 8x8 : contenu du coffre conserve a chaque pas, centre toujours suivi par sa force",
    string.format("coffres %d/%d, charbon %d/%d, cc_level %d", fin and fin.get_item_count("wooden-chest") or -1, wood0,
      fin and fin.get_item_count("coal") or -1, coal0, ctx.call("levels_status", FORCE_CC1).cc_level))
end

--- Deux ticks après ACT : progressions reposées (le mod les repose dans son on_tick du tick ACT + 1, la machine
--- ayant repris sa fabrication à sa mise à jour du tick ACT).
function M.after(ctx)
  local st = ctx.state()
  if st.after_done then return end
  st.after_done = true
  if st.fu7 and st.fu7.valid then st.fu_prog2 = st.fu7.crafting_progress end
  if st.as27 and st.as27.valid then st.as2_prog2 = st.as27.crafting_progress end
  local sp = status(ctx)
  ctx.log(string.format("ACT + 2 (tick %d) : progression four %s, assembleur %s ; progressions reposees %d, en attente %d", game.tick,
    tostring(st.fu_prog2), tostring(st.as2_prog2), sp.resumed or -1, sp.pending or -1))
end

---------------------------------------------------------------------------------------------------
-- Vérification (dans la durée)
---------------------------------------------------------------------------------------------------
--- Prototypes d'une famille sur tous ses niveaux : emprise de la table, collision au style vanilla, groupe du
--- niveau 1 ; points de jeu (raccords de tuyau vers le nord) hors de la boîte et sur un centre de tuile.
local function check_protos(ctx, family)
  local bad = {}
  local p1 = game.entity_prototypes[LV.name(family, 1)]
  local g1 = p1.fast_replaceable_group
  -- Niveaux au côté de base : boîtes du prototype vanilla, jamais retouchées (foreuse ±1,4, four ±0,875 : marges
  -- vanilla différentes de 0,3) ; niveaux agrandis : carré − 0,3 par côté.
  local col1 = p1.collision_box.right_bottom.x - p1.collision_box.left_top.x
  local radius1 = family.key == "drill" and game.entity_prototypes[family.base].mining_drill_radius
  local range1 = family.key == "laser" and game.entity_prototypes[family.base].turret_range
  local seen = {}
  for n = 1, family.max do
    local p = game.entity_prototypes[LV.name(family, n)]
    local side = LV.footprint(family, n)
    local sel, col = p.selection_box, p.collision_box
    local ok
    if side == family.size then
      -- Boîtes du niveau 1 telles quelles (le four en acier vanilla a une sélection de 1,6 × 2).
      local s1 = p1.selection_box
      ok = close(sel.left_top.x, s1.left_top.x) and close(sel.right_bottom.y, s1.right_bottom.y) and close(col.right_bottom.x - col.left_top.x, col1)
    else
      ok = close(sel.right_bottom.x - sel.left_top.x, side) and close(sel.right_bottom.y - sel.left_top.y, side)
        and close(col.right_bottom.x - col.left_top.x, side - 2 * Foot.MARGIN)
    end
    ok = ok and p.fast_replaceable_group == g1
    if radius1 and math.abs(p.mining_drill_radius - (radius1 + (side - family.size) / 2)) > 1e-4 then ok = false end
    if range1 and math.abs(p.turret_range - (LV.apply_stat(family.stats[3], range1, n) + LV.range_bonus(family, n))) > 1e-4 then ok = false end
    local c = side / 2 - Foot.MARGIN
    for _, fb in ipairs(p.fluidbox_prototypes or {}) do
      for _, pc in ipairs(fb.pipe_connections or {}) do
        local v = pc.positions and pc.positions[1]
        if v then
          local x, y = v.x or v[1], v.y or v[2]
          local inside = math.abs(x) <= c + 1e-6 and math.abs(y) <= c + 1e-6
          local centered = math.abs((x + side / 2) % 1 - 0.5) < 1e-6 and math.abs((y + side / 2) % 1 - 0.5) < 1e-6
          if inside or not centered then ok = false end
        end
      end
    end
    if not ok then bad[#bad + 1] = tostring(n) end
    if not seen[side] then seen[side] = n end
  end
  local sides = {}
  for sd = 1, 8 do if seen[sd] then sides[#sides + 1] = sd .. "x" .. sd .. " des " .. seen[sd] end end
  ctx.check(#bad == 0, "prototypes " .. family.key .. " (" .. family.max .. " niveaux) : emprise de la table, collision au style vanilla, meme groupe"
    .. (radius1 and ", rayon d'extraction r + (cote - 3) / 2" or "") .. (range1 and ", portee + (cote - 2) / 2" or "") .. ", raccords hors de la boite",
    #bad > 0 and ("niveaux en defaut : " .. table.concat(bad, " ")) or table.concat(sides, ", "))
end

function M.verify(ctx)
  local st = ctx.state()
  ctx.check(st.done == true, "controles d'agrandissement des machines joues")
  -- Assembleur : tuyau raccordé, eau reçue, fabrication qui avance, bras qui vise et nourrit.
  local a7 = st.as7
  if a7 and a7.valid then
    local c1 = a7.fluidbox.get_pipe_connections(1)[1]
    local linked = c1 and c1.target ~= nil and c1.target.owner == st.as_pipe
    local made = a7.products_finished - (st.as_done0 or 0)
    ctx.check(linked and made >= 2,
      "assembleur 7 : le tuyau pose au nouveau raccord l'alimente vraiment (connexion moteur, fabrication qui avance)",
      string.format("connexion %s ; %d baril(s) rempli(s) depuis l'agrandissement ; eau %.1f", tostring(linked), made,
        a7.fluidbox[1] and a7.fluidbox[1].amount or 0))
    ctx.check(st.as_ins.valid and st.as_ins.drop_target == a7 and st.as_chest.get_item_count("empty-barrel") < st.as_chest0,
      "assembleur 7 : le bras qui le nourrissait vise la nouvelle machine (F79) et la nourrit encore",
      string.format("depot %s -> %s ; coffre %d -> %d barils vides", fmt(st.as_ins.drop_position), st.as_ins.drop_target and st.as_ins.drop_target.name or "rien",
        st.as_chest0 or -1, st.as_chest.get_item_count("empty-barrel")))
  else
    ctx.fail("assembleur 7 introuvable a la verification")
  end
  -- Foreuse D1 : dépôt au nouveau point dans le même coffre, extraction en cours (le circuit l'autorise).
  local d7 = st.d17
  if d7 and d7.valid then
    local got = st.d1_chest.get_item_count("iron-ore") - (st.d1_ore0 or 0)
    ctx.check(d7.drop_target == st.d1_chest and got > 0 and d7.status == defines.entity_status.working,
      "foreuse 7 : depose au nouveau point dans le meme coffre, minerai en hausse, en marche (condition du circuit lue par le fil)",
      string.format("depot en %s -> %s ; +%d minerai ; etat %s", fmt(d7.drop_position), d7.drop_target and d7.drop_target.name or "rien", got,
        tostring(d7.status)))
  else
    ctx.fail("foreuse 7 introuvable a la verification")
  end
  -- Foreuse D2 : mine le minerai que seule la zone agrandie couvre.
  local d27 = st.d27
  if d27 and d27.valid then
    local tgt = d27.mining_target
    local got = st.d2_chest.get_item_count("iron-ore")
    ctx.check(not st.d2_ore_inside_old and tgt and tgt.valid and near(tgt.position.x, st.d2_ore_pos.x) and near(tgt.position.y, st.d2_ore_pos.y) and got > 0,
      "foreuse 7 : sa zone d'extraction couvre la nouvelle surface (mine un minerai hors de l'ancienne zone)",
      string.format("cible %s ; %d minerai(s) au coffre ; rayon %.2f -> %.2f", tgt and tgt.valid and fmt(tgt.position) or "aucune", got,
        game.entity_prototypes[LV.name(DR, 6)].mining_drill_radius, d27.prototype.mining_drill_radius))
  else
    ctx.fail("foreuse 7 (zone) introuvable a la verification")
  end
  -- Four : bras qui vise et nourrit, plaques en hausse.
  local f7 = st.fu7
  if f7 and f7.valid then
    local res = f7.get_inventory(defines.inventory.furnace_result).get_item_count("iron-plate")
    ctx.check(st.fu_ins.valid and st.fu_ins.drop_target == f7 and st.fu_chest.get_item_count("iron-ore") < (st.fu_chest0 or 0) and res > (st.fu_res0 or 0),
      "four 7 : le bras vise le nouveau four (F79) et le nourrit, les plaques montent",
      string.format("depot %s -> %s ; coffre %d -> %d minerais ; plaques %d -> %d", fmt(st.fu_ins.drop_position),
        st.fu_ins.drop_target and st.fu_ins.drop_target.name or "rien", st.fu_chest0 or -1, st.fu_chest.get_item_count("iron-ore"), st.fu_res0 or -1, res))
  else
    ctx.fail("four 7 introuvable a la verification")
  end
  -- Bilans de matière : rien perdu ni créé par l'agrandissement d'une machine en pleine fabrication.
  if f7 and f7.valid then
    local now, crafting = M.iron_balance(st, f7)
    ctx.check(now == st.fu_balance0 and st.fu_balance1 == st.fu_balance0,
      "four : bilan de fer constant a travers l'agrandissement (minerai du coffre, de l'entree et du bras, plaques, fusion en cours)",
      string.format("avant %d (fusion en cours %d), juste apres %s, au tick %d : %d (fusion en cours %d)", st.fu_balance0 or -1, st.fu_crafting0 or -1,
        tostring(st.fu_balance1), game.tick, now, crafting))
  end
  local a27 = st.as27
  if a27 and a27.valid then
    local now, crafting = M.steel_balance(st, a27)
    local p = st.as2_prog or {}
    ctx.check(now == st.as2_balance0 and st.as2_balance1 == st.as2_balance0 and (a27.products_finished > 0 or a27.is_crafting()),
      "assembleur : bilan d'acier constant a travers l'agrandissement en pleine fabrication, la machine travaille ensuite",
      string.format("avant %d, juste apres %s, au tick %d : %d (en cours %d) ; progression %.3f -> %.3f juste apres (fabrication %s), %s a ACT + 2 ; %d moteur(s) depuis",
        st.as2_balance0 or -1, tostring(st.as2_balance1), game.tick, now, crafting, p.before or -1, p.after or -1, tostring(p.crafting_after),
        st.as2_prog2 and string.format("%.3f", st.as2_prog2) or "?", a27.products_finished))
  end
  -- Progressions reposées au tick suivant (resume_later, script/levels/levels.lua), lues à ACT + 2.
  ctx.check(st.after_done and st.fu_prog2 and st.fu_prog0 and st.fu_prog2 >= st.fu_prog0 - 1e-6 and st.fu_prog2 < st.fu_prog0 + 0.05
    and st.as2_prog2 and st.as2_prog and st.as2_prog2 >= st.as2_prog.before - 1e-6 and st.as2_prog2 < st.as2_prog.before + 0.05,
    "progression de la fabrication en cours reposee au tick suivant (four et assembleur agrandis)",
    string.format("four %.3f -> %s, assembleur %.3f -> %s (lus a ACT + 2 ; un tick de travail en plus)", st.fu_prog0 or -1, tostring(st.fu_prog2),
      st.as2_prog and st.as2_prog.before or -1, tostring(st.as2_prog2)))
  local l7 = st.lz7
  ctx.check(l7 and l7.valid and l7.is_connected_to_electric_network() and l7.energy > 0,
    "laser 7 : relie au reseau electrique, tampon charge", l7 and l7.valid and string.format("%.0f J", l7.energy) or "introuvable")
  for _, f in ipairs({ LZ, DR, FU, AS, CC }) do check_protos(ctx, f) end
  local left = rectangles(ctx.zone)
  ctx.check(#left == 0, "contours de la zone effaces par le moteur (duree limitee)", #left .. " rectangle(s)")
  local s = status(ctx)
  ctx.check(s.spilled == 0 and s.resize_failed == 0 and s.forced == 0 and s.ground_left == 0 and s.fallback == 0,
    "aucun objet renverse, aucun echec de remplacement, aucun placement force, 0 secours (compteurs globaux)",
    string.format("agrandissements %d, refus %d, contours %d", s.resized, s.room_refused, s.contours))
end

function M.shots(ctx, add)
  local z = ctx.zone
  add("place-libre", z.x0 + 54, z.y0 + 22, 0.9, 0)
  add("usine-dense", z.x0 + 58, z.y0 + 50, 0.9, 0)
  add("chaines-niveau-30", z.x0 + 48, z.y0 + 78, 0.9, 0)
  add("chaines-niveau-30-nuit", z.x0 + 48, z.y0 + 78, 0.9, 0.5)
end

-- Crochets du banc content.
return {
  module = M,
  setup = function(ctx)
    ctx.prepare_zone("grass-1")
    M.setup(ctx)
  end,
  tick = function(ctx, e)
    if e.tick == M.ACT then M.act(ctx) elseif e.tick == M.ACT + 2 then M.after(ctx) end
  end,
  verify = M.verify,
  shots = M.shots,
}
