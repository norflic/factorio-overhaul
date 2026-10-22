--[[
  Scénario GREFFÉ « t2-migration » (lot V3-T2, 22/10) : MIGRATION D'UNE VRAIE SAUVEGARDE 0.4.2 vers 0.4.3 en moteur
  réel, quand TOUTES les familles grandissent (Q-S1 : oui). Format : tools/autotest/README.md §4 ; double source :
  §1.1 du même fichier (FO_CREATE_SRC = export de main c4d37e5, version 0.4.2, où seule la mitrailleuse grandit).

  Phase « création » (source 0.4.2) : init() pose, à l'ANCIENNE taille (laser et four 2×2, foreuse et assembleur 3×3,
  centre 4×4), et relève tout dans l'état du greffon (donc dans la sauvegarde) :
    - force « fo-t2-libre », SANS énergie (contenu immobile, comparé exactement) : pour chaque famille, un niveau 7
      libre, un niveau élevé libre (laser et four 25 → 6×6, foreuse et assembleur 19 → 6×6), une PAIRE de niveau 7
      collée ; contenu : munitions de laser impossibles, donc victimes et dégâts ; four : charbon et plaques ;
      foreuse : réglages du circuit ; assembleur : recette, plaques, engrenages, modules ; PV entamés ; une
      mitrailleuse 7 témoin (déjà 3×3 en 0.4.2 : ne doit pas bouger) ;
    - centres : 15 (force « fo-t2 », 4×4 → 8×8, place libre), 10 (force « fo-t2-c7 », 4×4 → 7×7, coffre garni, place
      libre), 6 (force « fo-t2-c5 », 4×4 → 5×5, un bras sur chaque côté) ;
    - USINE DENSE typique (force « fo-t2 », alimentée) : 6 assembleurs 8 collés (bras d'entrée au nord depuis des
      coffres infinis, bras de sortie au sud vers un convoyeur) ; colonne de 6 fours 8 (bras d'entrée à l'ouest depuis
      des coffres infinis, bras de sortie à l'est vers un convoyeur) ; 6 foreuses 8 en deux rangées face à face autour
      d'un convoyeur, sur le minerai ; 6 lasers 8 collés derrière un mur.
  Phase « benchmark » (source 0.4.3) : tick() contrôle au tick ACT (le moteur a appelé on_configuration_changed au
  chargement : Levels.repair a migré), puis finish() (tick CHECK) vérifie la durée : l'usine dense tourne encore
  (machines laissées hors grille comprises), le filet n'a rien rejoué.
  Classement d'un bâtiment (déduit de l'état final, comparé au journal du mod) : REPOSÉ (autre entité, sur la grille,
  contient l'ancien carré), DÉJÀ EN PLACE (même entité, sur la grille, aucun chevauchement), LAISSÉ (même entité, hors
  grille ou chevauchant : « chevauchement toléré »). Journal : lignes « JOURNAL ATTENDU », comparées hors jeu par
  tools/autotest/ht3_journal.py --tag FO-T2-MIGRATION.
]]

local LV = require("__factorio-overhaul__/shared/levels/config")
local has_foot, Foot = pcall(require, "__factorio-overhaul__/shared/levels/footprint")
if not has_foot then Foot = nil end

local ACT = 90
local CHECK = 600
local X0, Y0, X1, Y1 = 296, 240, 440, 312
local F_LIBRE, F_MAIN, F_C7, F_C5 = "fo-t2-libre", "fo-t2", "fo-t2-c7", "fo-t2-c5"
local LZ, FU, DR, AS, CC, G = LV.by_key.laser, LV.by_key.furnace, LV.by_key.drill, LV.by_key.assembler, LV.by_key.command, LV.by_key.gun
local N, E, S, W = defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west

--- Ce que le moteur passe à on_configuration_changed (voie de la migration), journalisé.
script.on_configuration_changed(function(data)
  local names, parts = {}, {}
  for name in pairs(data.mod_changes or {}) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local c = data.mod_changes[name]
    parts[#parts + 1] = name .. " " .. tostring(c.old_version) .. " -> " .. tostring(c.new_version)
  end
  global.t2_config = { text = table.concat(parts, ", "), tick = game.tick }
  log("[FO-T2-MIGRATION] on_configuration_changed (tick " .. game.tick .. ") : mod_changes { " .. table.concat(parts, ", ") .. " }")
end)

local function make_force(name)
  local f = game.forces[name] or game.create_force(name)
  for _, other in ipairs({ "player", "enemy" }) do
    f.set_cease_fire(other, true)
    game.forces[other].set_cease_fire(f, true)
  end
  return f
end

local function fmt(p) return string.format("%g, %g", p.x, p.y) end

local function proto_side(name)
  local b = game.entity_prototypes[name].selection_box
  return b.right_bottom.x - b.left_top.x
end

local function box_of(e)
  local bb = e.bounding_box
  return { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y }
end

local function overlap(a, b)
  local eps = 1e-6
  return a.x0 < b.x1 - eps and b.x0 < a.x1 - eps and a.y0 < b.y1 - eps and b.y0 < a.y1 - eps
end

local SKIP = { character = true, unit = true, ["item-entity"] = true, ["entity-ghost"] = true, resource = true,
  ["flying-text"] = true, corpse = true }

--- Ce qui chevauche la boîte de collision de `e` (couches partagées, test strict des boîtes), trié.
local function overlapping(e)
  local s, b, out = e.surface, box_of(e), {}
  local mask = e.prototype.collision_mask
  for _, o in ipairs(s.find_entities_filtered({ area = { { b.x0, b.y0 }, { b.x1, b.y1 } } })) do
    if o.valid and o ~= e and not SKIP[o.type] then
      local shared = false
      local layers = {}
      for layer in pairs(o.prototype.collision_mask or {}) do layers[#layers + 1] = layer end
      table.sort(layers)
      for _, layer in ipairs(layers) do if mask[layer] then shared = true break end end
      if shared and overlap(b, box_of(o)) then out[#out + 1] = o.name .. "@" .. fmt(o.position) end
    end
  end
  table.sort(out)
  return out
end

--- Contenu complet d'un bâtiment, en texte trié (inventaires 1 à 10, boîtes à fluide, recette, réglages, PV).
local function content(e)
  local parts = {}
  for i = 1, 10 do
    local inv = e.get_inventory(i)
    if inv and not inv.is_empty() then
      local c = inv.get_contents()
      local names = {}
      for k in pairs(c) do names[#names + 1] = k end
      table.sort(names)
      for _, k in ipairs(names) do parts[#parts + 1] = "inv" .. i .. ":" .. k .. "=" .. c[k] end
    end
  end
  local fb = e.fluidbox
  for i = 1, fb and #fb or 0 do
    if fb[i] then parts[#parts + 1] = string.format("fluide%d:%s=%.1f", i, fb[i].name, fb[i].amount) end
  end
  if e.type == "assembling-machine" then
    local r = e.get_recipe()
    parts[#parts + 1] = "recette=" .. (r and r.name or "aucune")
  end
  if e.type == "mining-drill" then
    local cb = e.get_control_behavior()
    if cb then
      local c = cb.circuit_condition.condition
      parts[#parts + 1] = string.format("circuit=%s/%s/%s/%s%s%s", tostring(cb.circuit_enable_disable), tostring(cb.circuit_read_resources),
        tostring(cb.resource_read_mode), c.first_signal and c.first_signal.name or "-", c.comparator or "-", tostring(c.constant))
    end
  end
  if e.type == "electric-turret" then parts[#parts + 1] = string.format("victimes=%d,degats=%.1f", e.kills, e.damage_dealt) end
  parts[#parts + 1] = string.format("PV=%.3f", e.get_health_ratio())
  return table.concat(parts, " ")
end

local function put(s, f, family, n, x, y, dir, raise)
  return s.create_entity({ name = LV.name(family, n), position = { x, y }, direction = dir, force = f, raise_built = raise ~= false })
end

local function ins(s, f, x, y, dir)
  return s.create_entity({ name = "inserter", position = { x, y }, direction = dir, force = f, raise_built = true })
end

local function infinity(s, f, x, y, item)
  local c = s.create_entity({ name = "infinity-chest", position = { x, y }, force = f, raise_built = true })
  if c then c.set_infinity_container_filter(1, { name = item, count = 50, mode = "at-least" }) end
  return c
end

local function belt(s, f, x, y, dir)
  return s.create_entity({ name = "transport-belt", position = { x, y }, direction = dir, force = f, raise_built = true })
end

local function belt_items(list)
  local n = 0
  for _, b in ipairs(list) do
    if b.valid then n = n + b.get_transport_line(1).get_item_count() + b.get_transport_line(2).get_item_count() end
  end
  return n
end

--- Relevé d'un bâtiment posé : clé, groupe (libre, dense…), nom, position, numéro, côté avant, contenu.
local function record(st, key, group, e)
  if not e then return end
  st.rec[#st.rec + 1] = { key = key, group = group, name = e.name, x = e.position.x, y = e.position.y, unit = e.unit_number,
    entity = e, side0 = proto_side(e.name), content = content(e), force = e.force.name }
end

return {
  description = "V3-T2 : sauvegarde creee par 0.4.2 (seule la mitrailleuse grandit), migree par 0.4.3 (toutes les familles)",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    st.version_create = script.active_mods["factorio-overhaul"]
    local a7 = proto_side(LV.name(AS, 7))
    ctx.log("creation : factorio-overhaul " .. tostring(st.version_create) .. ", assembleur 7 en " .. a7 .. "x" .. a7)
    if a7 ~= 3 then
      ctx.fail("phase de creation avec une source 0.4.2 (assembleur 7 en 3x3)", "assembleur 7 deja en " .. a7 .. "x" .. a7 .. " : lancer avec FO_CREATE_SRC")
      st.invalid = true
      return
    end
    ctx.prepare_area(X0, Y0, X1, Y1, "grass-1")
    local foes = 0
    for _, en in ipairs(s.find_entities_filtered({ area = { { X0 - 48, Y0 - 48 }, { X1 + 48, Y1 + 48 } }, force = "enemy" })) do
      if en.valid then en.destroy(); foes = foes + 1 end
    end
    ctx.log("ennemis retires autour de la zone : " .. foes)
    st.rec = {}
    local libre = make_force(F_LIBRE)
    local main = make_force(F_MAIN)
    for _, r in ipairs({ "iron-gear-wheel" }) do main.recipes[r].enabled = true; libre.recipes[r].enabled = true end

    -- 1. Cas libres (force sans énergie : contenu immobile).
    local y = Y0 + 10
    local function laser(key, n, x)
      local e = put(s, libre, LZ, n, x, y)
      if e then e.kills = n; e.damage_dealt = 100 * n; e.health = e.prototype.max_health * 0.5 end
      record(st, key, "libre", e)
    end
    local function furnace(key, n, x)
      local e = put(s, libre, FU, n, x, y)
      if e then
        e.get_inventory(defines.inventory.fuel).insert({ name = "coal", count = 10 + n })
        e.get_inventory(defines.inventory.furnace_result).insert({ name = "iron-plate", count = n })
        e.health = e.prototype.max_health * 0.6
      end
      record(st, key, "libre", e)
    end
    local function drill(key, n, x)
      local e = put(s, libre, DR, n, x, y + 0.5)
      if e then
        local cb = e.get_or_create_control_behavior()
        cb.circuit_read_resources = true
        cb.circuit_enable_disable = true
        cb.circuit_condition = { condition = { comparator = "<", first_signal = { type = "item", name = "iron-ore" }, constant = n } }
        e.health = e.prototype.max_health * 0.7
      end
      record(st, key, "libre", e)
    end
    local function assembler(key, n, x)
      local e = put(s, libre, AS, n, x, y + 0.5)
      if e then
        e.set_recipe("iron-gear-wheel")
        -- 1 plaque : un engrenage en demande 2, la machine reste à l'arrêt (premier essai : avec 7 plaques, les
        -- assembleurs « sans énergie » ont fabriqué 3 engrenages avant le contrôle : le réseau invisible de l'usine
        -- dense, d'une autre force, les a alimentés ; relevé ci-dessous par l'énergie des lasers libres).
        e.get_inventory(defines.inventory.assembling_machine_input).insert({ name = "iron-plate", count = 1 })
        e.get_inventory(defines.inventory.assembling_machine_output).insert({ name = "iron-gear-wheel", count = 3 })
        e.get_inventory(defines.inventory.assembling_machine_modules).insert({ name = "speed-module", count = 2 })
        e.health = e.prototype.max_health * 0.8
      end
      record(st, key, "libre", e)
    end
    laser("laser7", 7, X0 + 6); laser("laser25", 25, X0 + 16); laser("laserA", 7, X0 + 26); laser("laserB", 7, X0 + 28)
    furnace("four7", 7, X0 + 38); furnace("four25", 25, X0 + 48); furnace("fourA", 7, X0 + 58); furnace("fourB", 7, X0 + 60)
    drill("foreuse7", 7, X0 + 70.5); drill("foreuse19", 19, X0 + 80.5); drill("foreuseA", 7, X0 + 90.5); drill("foreuseB", 7, X0 + 93.5)
    assembler("assembleur7", 7, X0 + 104.5); assembler("assembleur19", 19, X0 + 114.5); assembler("assembleurA", 7, X0 + 124.5)
    assembler("assembleurB", 7, X0 + 127.5)
    local g7 = put(s, libre, G, 7, X0 + 136.5, y + 0.5)
    if g7 then g7.insert({ name = "firearm-magazine", count = 5 }) end
    record(st, "mitrailleuse7", "temoin", g7)

    -- 2. Centres : 15 (libre), 10 (libre, coffre garni), 6 (cerné de bras).
    local yc = Y0 + 26
    local cc15 = put(s, main, CC, 15, X0 + 14, yc)
    if cc15 then cc15.insert({ name = "iron-plate", count = 150 }) end
    record(st, "centre15", "centre", cc15)
    local c7 = make_force(F_C7)
    local cc10 = put(s, c7, CC, 10, X0 + 34, yc)
    if cc10 then cc10.insert({ name = "wooden-chest", count = 9 }); cc10.insert({ name = "coal", count = 77 }); cc10.health = cc10.prototype.max_health * 0.9 end
    record(st, "centre10", "centre", cc10)
    local c5 = make_force(F_C5)
    local xc = X0 + 54
    local cc6 = put(s, c5, CC, 6, xc, yc)
    if cc6 then cc6.insert({ name = "copper-plate", count = 33 }) end
    record(st, "centre6", "centre", cc6)
    ins(s, c5, xc - 0.5, yc - 2.5, N); s.create_entity({ name = "iron-chest", position = { xc - 0.5, yc - 3.5 }, force = c5 })
    ins(s, c5, xc + 0.5, yc + 2.5, S); s.create_entity({ name = "iron-chest", position = { xc + 0.5, yc + 3.5 }, force = c5 })
    ins(s, c5, xc - 2.5, yc - 0.5, W); s.create_entity({ name = "iron-chest", position = { xc - 3.5, yc - 0.5 }, force = c5 })
    ins(s, c5, xc + 2.5, yc + 0.5, E); s.create_entity({ name = "iron-chest", position = { xc + 3.5, yc + 0.5 }, force = c5 })

    -- 3. Usine dense (force « fo-t2 », alimentée par un réseau invisible).
    ctx.power(X0 + 70, Y0 + 48, main)
    local yd = Y0 + 46
    st.dense = { belts = {} }
    -- Assembleurs : rangée de 6, entrée au nord, sortie au sud sur un convoyeur.
    st.dense.as_ins = {}
    for k = 0, 5 do
      local x = X0 + 10.5 + 3 * k
      local m = put(s, main, AS, 8, x, yd + 0.5, N)
      if m then m.set_recipe("iron-gear-wheel") end
      record(st, "dense-assembleur-" .. (k + 1), "dense", m)
      infinity(s, main, x, yd - 2.5, "iron-plate")
      st.dense.as_ins[#st.dense.as_ins + 1] = ins(s, main, x, yd - 1.5, N)
      st.dense.as_ins[#st.dense.as_ins + 1] = ins(s, main, x, yd + 2.5, N)
    end
    for x = X0 + 9.5, X0 + 27.5 do st.dense.belts[#st.dense.belts + 1] = belt(s, main, x, yd + 3.5, E) end
    -- Fours : colonne de 6, entrée à l'ouest, sortie à l'est sur un convoyeur.
    local xf = X0 + 40
    st.dense.fu_ins = {}
    for k = 0, 5 do
      local yy = yd - 1 + 2 * k
      local m = put(s, main, FU, 8, xf, yy)
      if m then m.get_inventory(defines.inventory.fuel).insert({ name = "coal", count = 50 }) end
      record(st, "dense-four-" .. (k + 1), "dense", m)
      infinity(s, main, xf - 2.5, yy - 0.5, "iron-ore")
      st.dense.fu_ins[#st.dense.fu_ins + 1] = ins(s, main, xf - 1.5, yy - 0.5, W)
      st.dense.fu_ins[#st.dense.fu_ins + 1] = ins(s, main, xf + 1.5, yy - 0.5, W)
    end
    for yy = yd - 3, yd + 11 do st.dense.belts[#st.dense.belts + 1] = belt(s, main, xf + 2.5, yy + 0.5, S) end
    -- Foreuses : deux rangées de 3 face à face autour d'un convoyeur, sur le minerai.
    local xr = X0 + 60.5
    for dx = -2, 10 do for dy = -3, 7 do s.create_entity({ name = "iron-ore", position = { xr + dx, yd + 0.5 + dy }, amount = 5000 }) end end
    for k = 0, 2 do
      record(st, "dense-foreuse-n" .. (k + 1), "dense", put(s, main, DR, 8, xr + 3 * k, yd - 0.5, S))
      record(st, "dense-foreuse-s" .. (k + 1), "dense", put(s, main, DR, 8, xr + 3 * k, yd + 3.5, N))
    end
    for x = xr - 2, xr + 9 do st.dense.belts[#st.dense.belts + 1] = belt(s, main, x, yd + 1.5, E) end
    -- Lasers : rangée de 6 collés derrière un mur.
    local xl = X0 + 82
    for k = 0, 5 do record(st, "dense-laser-" .. (k + 1), "dense", put(s, main, LZ, 8, xl + 2 * k, yd)) end
    for x = xl - 2.5, xl + 11.5 do s.create_entity({ name = "stone-wall", position = { x, yd - 3.5 }, force = main, raise_built = true }) end

    local made = #st.rec
    ctx.check(made == 44, "phase de creation (" .. tostring(st.version_create) .. ") : " .. made .. "/44 batiments poses a l'ancienne taille",
      "16 libres, 1 temoin, 3 centres, 24 dans l'usine dense")
    for _, r in ipairs(st.rec) do
      ctx.log(string.format("pose %s (%s) : %s en %s, n° %d, %dx%d ; %s", r.key, r.group, r.name, fmt(r), r.unit, r.side0, r.side0, r.content))
    end
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if st.invalid or not st.rec then return end
    if not st.first_tick then
      st.first_tick = e.tick
      local s0 = ctx.call("levels_status", F_MAIN)
      st.version_bench = script.active_mods["factorio-overhaul"]
      st.first_stale = s0.footprints_stale
      local cfg = global.t2_config
      ctx.log(string.format("benchmark : premier tick %d, factorio-overhaul %s (creation %s), releve %s, migrated %s, overlap_kept %s ; on_configuration_changed %s",
        e.tick, tostring(st.version_bench), tostring(st.version_create), s0.footprints_stale == nil and "absent" or (s0.footprints_stale and "PERIME" or "a jour"),
        tostring(s0.migrated), tostring(s0.overlap_kept), cfg and ("APPELE (tick " .. cfg.tick .. ") : " .. cfg.text) or "NON appele"))
    end
    if e.tick ~= st.first_tick + ACT or st.done then return end
    st.done = true
    if not Foot then
      ctx.fail("phase benchmark avec une source 0.4.3 (footprint.lua present)")
      return
    end
    local s = ctx.surface()
    local s1 = ctx.call("levels_status", F_MAIN)
    st.s1 = s1

    -- Relevé de la sauvegarde = table, toutes les familles.
    local bad = {}
    for _, f in ipairs(LV.families) do
      local row = s1.footprints and s1.footprints[f.key]
      for n = 1, f.max do
        if not (row and row[n] == LV.footprint(f, n)) then bad[#bad + 1] = f.key .. n end
      end
    end
    ctx.check(s1.footprints_stale == false and #bad == 0, "releve des emprises ecrit et egal a la table (7 familles, tous les niveaux)",
      #bad > 0 and table.concat(bad, " ") or ("premier tick : releve " .. (st.first_stale and "PERIME" or "deja a jour")))

    -- Classement de chaque bâtiment.
    local count = { moved = 0, inplace = 0, kept = 0, same = 0 }
    local by_group = {}
    st.final = {}
    for _, r in ipairs(st.rec) do
      local family, n = LV.parse(r.name)
      local side = LV.footprint(family, n)
      local old = Foot.tile_box({ x = r.x, y = r.y }, r.side0)
      local fin
      if r.entity.valid then
        fin = r.entity
      else
        for _, c in ipairs(s.find_entities_filtered({ area = { { r.x - 8, r.y - 8 }, { r.x + 8, r.y + 8 } }, name = r.name, force = r.force })) do
          if c.unit_number ~= r.unit and Foot.contains(Foot.tile_box(c.position, side), old) then fin = c end
        end
      end
      local kind, detail
      if not fin then
        kind = "perdu"
      else
        local over = overlapping(fin)
        local aligned = Foot.aligned(fin.position, side)
        if side == r.side0 then kind = "same"
        elseif fin.unit_number ~= r.unit then kind = "moved"
        elseif aligned and #over == 0 then kind = "inplace"
        else kind = "kept" end
        local cnow = content(fin)
        detail = string.format("%s -> %s %dx%d en %s ; contenu %s ; chevauche : %s", fmt(r), kind, side, side, fmt(fin.position),
          cnow == r.content and "IDENTIQUE" or ("DIFFERENT (" .. r.content .. " / " .. cnow .. ")"), #over > 0 and table.concat(over, ", ") or "rien")
        st.final[r.key] = { entity = fin, unit = fin.unit_number, x = fin.position.x, y = fin.position.y, kind = kind }
        local okc = true
        if r.group ~= "dense" then okc = (cnow == r.content) end -- usine dense : elle tourne, contenu non figé
        local ok_kind = (kind == "moved" and aligned and #over == 0 and Foot.contains(Foot.tile_box(fin.position, side), old))
          or kind == "inplace" or kind == "kept" or (kind == "same" and fin.unit_number == r.unit and fin.position.x == r.x)
        ctx.check(ok_kind and okc and fin.valid, r.key .. " (" .. r.name .. ", " .. r.side0 .. "x" .. r.side0 .. " -> " .. side .. "x" .. side .. ") : " .. kind
          .. (r.group ~= "dense" and ", contenu et PV conserves" or "") .. (kind == "moved" and ", sur la grille, sans chevauchement" or ""), detail)
      end
      if kind ~= "same" then count[kind] = (count[kind] or 0) + 1 end
      by_group[r.group] = by_group[r.group] or {}
      by_group[r.group][kind] = (by_group[r.group][kind] or 0) + 1
      if kind == "perdu" then ctx.fail(r.key .. " : batiment introuvable apres la migration") end
    end
    st.count = count
    -- Attentes nominatives (cas libres et centres) : la règle les fixe.
    local want = { laser7 = "moved", laser25 = "inplace", four7 = "moved", four25 = "inplace", foreuse7 = "moved", foreuse19 = "moved",
      assembleur7 = "moved", assembleur19 = "moved", mitrailleuse7 = "same", centre15 = "inplace", centre10 = "moved", centre6 = "kept" }
    local wrong = {}
    local keys = {}
    for k in pairs(want) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local f = st.final[k]
      if not (f and f.kind == want[k]) then wrong[#wrong + 1] = k .. "=" .. tostring(f and f.kind) .. "/" .. want[k] end
    end
    ctx.check(#wrong == 0, "cas libres et centres : reposes ou deja en place selon la regle, centre 6 cerne laisse",
      #wrong > 0 and table.concat(wrong, " ") or (#keys .. " cas conformes"))
    -- Paires collées : sans chevauchement entre elles.
    for _, p in ipairs({ { "laserA", "laserB" }, { "fourA", "fourB" }, { "foreuseA", "foreuseB" }, { "assembleurA", "assembleurB" } }) do
      local a, b = st.final[p[1]], st.final[p[2]]
      ctx.check(a and b and a.entity.valid and b.entity.valid and not overlap(box_of(a.entity), box_of(b.entity)) and a.kind == "moved" and b.kind == "moved",
        "paire collee " .. p[1] .. "/" .. p[2] .. " : les deux reposees, sans se chevaucher",
        a and b and (a.kind .. " en " .. fmt(a) .. ", " .. b.kind .. " en " .. fmt(b)) or "introuvable")
    end
    -- Centres suivis par leur force.
    local l15 = ctx.call("levels_status", F_MAIN).cc_level
    local l10 = ctx.call("levels_status", F_C7).cc_level
    local l6 = ctx.call("levels_status", F_C5).cc_level
    ctx.check(l15 == 15 and l10 == 10 and l6 == 6, "centres 15, 10 et 6 toujours suivis par leur force", l15 .. ", " .. l10 .. ", " .. l6)
    -- Usine dense : relevé par famille.
    local dense = {}
    for _, fam in ipairs({ "assembleur", "four", "foreuse", "laser" }) do
      local moved, kept = 0, 0
      for _, r in ipairs(st.rec) do
        if r.group == "dense" and r.key:find("dense-" .. fam, 1, true) then
          local k = st.final[r.key] and st.final[r.key].kind
          if k == "moved" then moved = moved + 1 elseif k == "kept" then kept = kept + 1 end
        end
      end
      dense[#dense + 1] = fam .. " " .. moved .. " reposee(s) / " .. kept .. " laissee(s)"
    end
    st.dense_text = table.concat(dense, " ; ")
    ctx.log("USINE DENSE (24 batiments) : " .. st.dense_text)
    -- Compteurs du mod.
    ctx.check(s1.migrated == count.moved and s1.overlap_kept == count.kept and s1.resized == count.moved,
      string.format("compteurs : %d repose(s) (migrated, resized), %d laisse(s) (overlap_kept) ; %d deja en place", count.moved, count.kept, count.inplace),
      string.format("migrated %d, overlap_kept %d, resized %d", s1.migrated, s1.overlap_kept, s1.resized))
    ctx.check(s1.spilled == 0 and s1.resize_failed == 0 and s1.forced == 0 and s1.ground_left == 0,
      "rien renverse, aucun echec de remplacement, aucun placement force",
      string.format("spilled %d, resize_failed %d, forced %d, ground_left %d", s1.spilled, s1.resize_failed, s1.forced, s1.ground_left))
    local items = s.count_entities_filtered({ area = { { X0, Y0 }, { X1, Y1 } }, type = "item-entity" })
    ctx.check(items == 0, "aucun objet au sol dans la zone", items .. " objet(s)")
    -- Usine dense en marche : mesures de départ (comparées au tick CHECK).
    st.prod0 = {}
    for _, r in ipairs(st.rec) do
      local f = st.final[r.key]
      if r.group == "dense" and f and f.entity.valid and (f.entity.type == "assembling-machine" or f.entity.type == "furnace") then
        st.prod0[r.key] = f.entity.products_finished
      end
    end
    st.belt0 = belt_items(st.dense.belts)
    -- Observation : énergie des lasers de la force SANS réseau à elle (la seule source est le réseau invisible de
    -- « fo-t2 », dont la zone couvre la rangée des cas libres).
    local en = {}
    for _, k in ipairs({ "laser7", "laser25", "laserA", "laserB" }) do
      local f = st.final[k]
      if f and f.entity.valid then
        en[#en + 1] = string.format("%s %.0f J (reseau %s)", k, f.entity.energy, tostring(f.entity.is_connected_to_electric_network()))
      end
    end
    ctx.log("lasers de la force " .. F_LIBRE .. " au tick " .. e.tick .. " : " .. table.concat(en, ", "))
    -- Journal attendu (comparé hors jeu).
    for _, r in ipairs(st.rec) do
      local f = st.final[r.key]
      if f and f.kind == "kept" then ctx.log("JOURNAL ATTENDU : laisse " .. r.name .. " en " .. tostring(r.x) .. ", " .. tostring(r.y)) end
    end
    ctx.log(string.format("JOURNAL ATTENDU : bilan %d %d %d voie %s", count.moved, count.inplace, count.kept, st.first_stale and "filet" or "repair"))
  end,

  finish = function(ctx)
    local st = ctx.state()
    if st.invalid or not st.final then
      ctx.fail("controles de migration joues", st.invalid and "carte invalide" or "tick ACT non atteint")
      return
    end
    -- Filet sans effet une fois le relevé à jour.
    local s2 = ctx.call("levels_status", F_MAIN)
    local moved = {}
    for _, r in ipairs(st.rec) do
      local f = st.final[r.key]
      if f and not (f.entity.valid and f.entity.unit_number == f.unit and f.entity.position.x == f.x and f.entity.position.y == f.y) then
        moved[#moved + 1] = r.key
      end
    end
    ctx.check(#moved == 0 and s2.migrated == st.s1.migrated and s2.overlap_kept == st.s1.overlap_kept and s2.resized == st.s1.resized
      and s2.footprints_stale == false,
      "filet sans effet une fois le releve a jour (jusqu'au tick " .. CHECK .. ") : memes entites, memes positions, compteurs inchanges",
      #moved > 0 and ("bouge : " .. table.concat(moved, ", ")) or string.format("migrated %d, overlap_kept %d", s2.migrated, s2.overlap_kept))
    -- L'usine dense tourne encore, machines laissées hors grille comprises.
    local stalled, kept_work, txt = {}, 0, {}
    for _, r in ipairs(st.rec) do
      local f = st.final[r.key]
      if r.group == "dense" and f and st.prod0[r.key] then
        local made = f.entity.valid and (f.entity.products_finished - st.prod0[r.key]) or -1
        if made <= 0 then stalled[#stalled + 1] = r.key .. "(" .. f.kind .. ")" end
        if f.kind == "kept" and made > 0 then kept_work = kept_work + 1 end
        txt[#txt + 1] = r.key:gsub("dense%-", "") .. "=" .. made
      end
    end
    ctx.check(#stalled == 0, "usine dense : chaque assembleur et chaque four fabrique encore (laisses hors grille compris : " .. kept_work .. ")",
      (#stalled > 0 and ("a l'arret : " .. table.concat(stalled, ", ") .. " ; ") or "") .. table.concat(txt, " "))
    -- Foreuses : en marche, ou en attente de place sur leur convoyeur (le convoyeur sans issue se remplit d'abord à
    -- son bout est : premier essai, les deux foreuses du bout « arrêtées », en fait convoyeur plein) ; cible de
    -- minage et cible de dépôt (le convoyeur) présentes.
    local idle, dtxt = {}, {}
    local ok_status = { [defines.entity_status.working] = true, [defines.entity_status.waiting_for_space_in_destination] = true }
    for _, r in ipairs(st.rec) do
      local f = st.final[r.key]
      if r.group == "dense" and f and f.entity.valid and f.entity.type == "mining-drill" then
        local d = f.entity
        local dt = d.drop_target
        if not (ok_status[d.status] and d.mining_target and dt and dt.type == "transport-belt") then idle[#idle + 1] = r.key .. "(" .. f.kind .. ")" end
        local names = {}
        for k in pairs(defines.entity_status) do names[#names + 1] = k end
        table.sort(names)
        local sname = tostring(d.status)
        for _, k in ipairs(names) do if defines.entity_status[k] == d.status then sname = k end end
        dtxt[#dtxt + 1] = r.key:gsub("dense%-", "") .. "(" .. f.kind .. ")=" .. sname .. "->" .. (dt and dt.name or "rien")
      end
    end
    local belt1 = belt_items(st.dense.belts)
    ctx.check(#idle == 0 and belt1 > st.belt0, "usine dense : foreuses en marche ou en attente de place (laissees comprises), deposant sur le convoyeur, convoyeurs qui recoivent la production",
      (#idle > 0 and ("en defaut : " .. table.concat(idle, ", ") .. " ; ") or "") .. table.concat(dtxt, " ") .. string.format(" ; objets sur les convoyeurs %d -> %d", st.belt0, belt1))
    -- Bras de l'usine dense : chacun vise encore une machine (dépôt ou prise).
    local lost = {}
    for _, list in ipairs({ st.dense.as_ins, st.dense.fu_ins }) do
      for _, i in ipairs(list) do
        if i.valid then
          local dt, pt = i.drop_target, i.pickup_target
          local machine = (dt and (dt.type == "assembling-machine" or dt.type == "furnace")) or (pt and (pt.type == "assembling-machine" or pt.type == "furnace"))
          if not machine then lost[#lost + 1] = fmt(i.position) end
        end
      end
    end
    ctx.check(#lost == 0, "usine dense : chaque bras vise encore sa machine (depot ou prise)", #lost > 0 and table.concat(lost, " ") or "24 bras")
    local lasers = {}
    for _, r in ipairs(st.rec) do
      local f = st.final[r.key]
      if r.group == "dense" and f and f.entity.valid and f.entity.type == "electric-turret" then
        if not (f.entity.is_connected_to_electric_network() and f.entity.energy > 0) then lasers[#lasers + 1] = r.key end
      end
    end
    ctx.check(#lasers == 0, "usine dense : lasers relies au reseau, tampon charge (laisses compris)", #lasers > 0 and table.concat(lasers, ", ") or "6 lasers")
    ctx.log("USINE DENSE (rappel) : " .. tostring(st.dense_text))
    ctx.log(string.format("versions : creation %s, benchmark %s", tostring(st.version_create), tostring(st.version_bench)))
  end,

  shots = function(ctx, add)
    add("migration-libres", X0 + 70, Y0 + 12, 0.7, 0)
    add("migration-usine-dense", X0 + 50, Y0 + 48, 0.8, 0)
  end,
}
