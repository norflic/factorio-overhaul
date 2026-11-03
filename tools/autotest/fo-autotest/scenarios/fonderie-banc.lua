--[[
  Lot FONDERIE (retour du DC du 2/11 au soir) : colonnes de fours nourries par TAPIS (shared/team/champ_colonne.lua) posées TELLES QUELLES
  en moteur réel, SANS charbon dans les fours et SANS coffre de combustible : le charbon ne vient que de la ligne de foreuses posée sur le
  gisement de charbon et de son tapis. Deux cas :
    - « voie »       : fer, disque de rayon 12, charbon au nord-est ; ni répartiteur ni souterrain (dérivation par bras) ;
    - « logistique » : cuivre, disque de rayon 12, charbon derrière une rivière de 3 tuiles (eau posée avant tout) ; répartiteur et
                       souterrain débloqués (le tracé passe SOUS la rivière).
  Plus H-FONDERIE-1 : le fantôme d'un souterrain créé avec type = "output", ravivé, est-il une sortie ?
  Mesures sur la fenêtre T1 = 9 000 -> T2 = 12 600 (1 min), critères de fo-logs/2026-11-02_FONDERIE/CRITERES.md (écrits avant).
  Lancement (après « reprise » seulement) : py -3.9 -B tools/autotest/banc.py --out <archive> --qui FONDERIE -- 12700 fonderie-banc <source>.
  Journal : [FO-FONDERIE-BANC].
]]
package.loaded["shared.team.champ_fonderie"] = package.loaded["shared.team.champ_fonderie"] or require("__factorio-overhaul__/shared/team/champ_fonderie")
package.loaded["shared.team.champ_colonne"] = package.loaded["shared.team.champ_colonne"] or require("__factorio-overhaul__/shared/team/champ_colonne")
package.loaded["shared.team.champ"] = package.loaded["shared.team.champ"] or require("__factorio-overhaul__/shared/team/champ")
local Ch = package.loaded["shared.team.champ"]
local Co = package.loaded["shared.team.champ_colonne"]
local Cv = require("__factorio-overhaul__/shared/team/champ_verif")

local X0, Y0 = 6200, 3000
local T1 = 9000
local NAMES = { foreuse = "electric-mining-drill", tapis = "transport-belt", poteau = "small-electric-pole", four = "stone-furnace",
  bras = "inserter", coffre = "iron-chest", souterrain = "underground-belt", repartiteur = "splitter" }

local function data(ore, plate)
  local dp = game.entity_prototypes[NAMES.foreuse]
  local rp = game.entity_prototypes[ore]
  local cr = game.entity_prototypes["coal"]
  local pp = game.entity_prototypes[NAMES.poteau]
  local bp = game.entity_prototypes[NAMES.tapis]
  local fp = game.entity_prototypes[NAMES.four]
  local ap = game.entity_prototypes[NAMES.bras]
  local up = game.entity_prototypes[NAMES.souterrain]
  local rec = game.recipe_prototypes[plate]
  local fv = game.item_prototypes["coal"].fuel_value
  return {
    drill = { size = dp.tile_width, reach = math.floor((2 * dp.mining_drill_radius - dp.tile_width) / 2 + 0.5),
      rate = dp.mining_speed / rp.mineable_properties.mining_time },
    coal_rate = dp.mining_speed / cr.mineable_properties.mining_time,
    pole = { reach = math.floor(pp.supply_area_distance - 0.5 + 1e-6), wire = pp.max_wire_distance },
    belts = { { lane = bp.belt_speed * 240 } },
    furnace = { size = fp.tile_width, rate = fp.crafting_speed / rec.energy, fuel = fp.burner_prototype ~= nil,
      fuel_rate = fp.energy_usage * 60 / fv },
    inserter = { rate = ap.inserter_rotation_speed * 60 },
    ug = up.max_underground_distance,
  }
end

local function put_ore(s, name, shape, amount)
  local flat = {}
  for _, t in ipairs(shape) do
    s.create_entity({ name = name, position = { t[1] + 0.5, t[2] + 0.5 }, amount = amount })
    flat[#flat + 1] = t[1]; flat[#flat + 1] = t[2]
  end
  return flat
end

local function disc(cx, cy, r)
  local out = {}
  for x = cx - r, cx + r do for y = cy - r, cy + r do if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r then out[#out + 1] = { x, y } end end end
  return out
end

local function place(ctx, key, ore, plate, cx, cy, coal_at, logistics, blocked, margin)
  local s = ctx.surface()
  local st = ctx.state()
  local flat = put_ore(s, ore, disc(cx, cy, 12), 50000)
  local coal = put_ore(s, "coal", disc(coal_at[1], coal_at[2], 8), 50000)
  local d = data(ore, plate)
  local spec = { ore = flat, blocked = blocked or {}, drill = d.drill, pole = d.pole, belts = d.belts, furnace = d.furnace,
    inserter = d.inserter, target = { x = cx - 500, y = cy }, max_side = 8, design = "colonne",
    coal = { tiles = coal, rate = d.coal_rate },
    logistics = { splitter = logistics, underground = logistics and d.ug or nil } }
  local m0 = Co.COAL_MARGIN
  Co.COAL_MARGIN = margin or m0
  local plan, why = Ch.plan(spec)
  Co.COAL_MARGIN = m0
  ctx.check(plan ~= nil, key .. " : plan rendu", tostring(why))
  if not plan then return end
  local rep = Cv.verify(plan, spec)
  local cs = {}
  for _, c in ipairs(plan.stats.coal or {}) do cs[#cs + 1] = string.format("cote %+d %s%s", c.side, c.voie and "voie" or "coffre", c.why and (" (" .. c.why .. ")") or "") end
  ctx.log(string.format("[FO-FONDERIE-BANC] %s : %d foreuses, %d fours, %d bras, %d coffres, %d poteaux, %d tapis, %d souterrains, %d repartiteurs ; %s ; %s",
    key, plan.stats.drills, plan.stats.furnaces, plan.stats.inserters, plan.stats.chests, plan.stats.poles, plan.stats.belts,
    plan.stats.undergrounds, plan.stats.splitters, table.concat(cs, ", "), Cv.line(rep)))
  ctx.check(rep.ok, key .. " : plan sans defaut (controle pur, voies des tapis comprises)", Cv.line(rep))
  local made, failed, why_failed = {}, 0, nil
  for _, e in ipairs(plan.ents) do
    local ent = s.create_entity({ name = NAMES[e.kind], position = { e.x, e.y }, direction = e.dir, force = "player", type = e.ug })
    if ent then
      made[#made + 1] = { ent = ent, kind = e.kind, role = e.role, band = e.band, group = e.group }
    else
      failed = failed + 1
      why_failed = why_failed or string.format("%s (%.1f, %.1f)", e.kind, e.x, e.y)
    end
  end
  ctx.check(failed == 0, key .. " : toutes les entites du plan posees", failed .. " refusee(s) sur " .. #plan.ents .. " " .. tostring(why_failed))
  local poles = {}
  for _, m in ipairs(made) do if m.ent.valid and m.ent.type == "electric-pole" then poles[#poles + 1] = m.ent end end
  for _, p in ipairs(poles) do
    for _, q in ipairs(s.find_entities_filtered({ position = p.position, radius = d.pole.wire, type = "electric-pole", force = "player" })) do
      if q ~= p then p.connect_neighbour(q) end
    end
  end
  local west
  for _, p in ipairs(poles) do if not west or p.position.x < west.position.x then west = p end end
  if west then
    local src = ctx.power(west.position.x - 3, west.position.y)
    ctx.check(src ~= nil, key .. " : alimentation invisible du mod de test", src and "posee" or "prototypes absents")
    for _, q in ipairs(s.find_entities_filtered({ position = { west.position.x - 3, west.position.y }, radius = 1, type = "electric-pole" })) do
      q.connect_neighbour(west)
    end
  end
  local cols = 0
  for _, bd in ipairs(plan.bands) do cols = cols + #bd.groups end
  st[key] = { made = made, ore = ore, plate = plate, cx = cx, cy = cy, logistics = logistics, cols = cols, coal_at = coal_at }
end

--- Diagnostic (lead, 3/11 : « où s'arrête le charbon ? », lu sur les entités) : par colonne (bande:groupe), fours dans l'ordre depuis la
--- tête, ceux qui ont du charbon, rang du premier sans charbon, charbon dans les fours (min, max), charbon sur la voie de la colonne et sur
--- sa dérivation ; pour tout le cas : foreuses de charbon par état, charbon extrait, charbon sur le tronc, le tracé et la ligne.
local function diag(ctx, key, when)
  local s = ctx.surface()
  local r = ctx.state()[key]
  if not r then return end
  local S = defines.entity_status
  local cols, keys = {}, {}
  local coal_net, drills = 0, {}
  for _, m in ipairs(r.made) do
    local en = m.ent
    if en.valid then
      local k = (m.band or 0) .. ":" .. (m.group or 0)
      if m.kind == "four" then
        if not cols[k] then cols[k] = { f = {}, lane = 0 }; keys[#keys + 1] = k end
        local fi = en.get_fuel_inventory()
        cols[k].f[#cols[k].f + 1] = { d = math.abs(en.position.x - r.cx), coal = fi and fi.get_item_count("coal") or 0,
          ore = en.get_inventory(defines.inventory.furnace_source).get_item_count(r.ore), st = en.status }
      elseif (m.kind == "tapis" or m.kind == "souterrain" or m.kind == "repartiteur") and m.role == "charbon" then
        local n = 0
        for l = 1, 2 do local tl = en.get_transport_line(l); if tl then n = n + tl.get_item_count("coal") end end
        if (m.band or 0) == 0 then coal_net = coal_net + n else
          if not cols[k] then cols[k] = { f = {}, lane = 0 }; keys[#keys + 1] = k end
          cols[k].lane = cols[k].lane + n
        end
      elseif m.kind == "tapis" and m.role == "colonne" then
        local tl = { en.get_transport_line(1), en.get_transport_line(2) }
        if not cols[k] then cols[k] = { f = {}, lane = 0 }; keys[#keys + 1] = k end
        cols[k].head = (cols[k].head or 0) + tl[1].get_item_count("coal") + tl[2].get_item_count("coal")
      elseif m.kind == "foreuse" and m.role == "charbon" then
        local name = "autre"
        for nm, v in pairs(S) do if v == en.status then name = nm end end
        drills[name] = (drills[name] or 0) + 1
      end
    end
  end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local c = cols[k]
    table.sort(c.f, function(a, b) return a.d < b.d end)
    local with, first, mn, mx, noore = 0, nil, math.huge, 0, 0
    for i, f in ipairs(c.f) do
      if f.coal > 0 then with = with + 1 elseif not first then first = i end
      mn, mx = math.min(mn, f.coal), math.max(mx, f.coal)
      if f.ore == 0 then noore = noore + 1 end
    end
    if #c.f > 0 then
      ctx.log(string.format("[FO-FONDERIE-BANC] DIAG %s t%s colonne %s : fours %d, avec charbon %d, premier sans charbon au rang %s, charbon par four %d..%d, sans minerai %d, charbon sur la voie de la colonne et sa derivation %d, sur la colonne (deux voies) %d",
        key, when, k, #c.f, with, tostring(first or "-"), mn, mx, noore, c.lane, c.head or 0))
    end
  end
  local dk = {}
  for nm in pairs(drills) do dk[#dk + 1] = nm end
  table.sort(dk)
  local dt = {}
  for _, nm in ipairs(dk) do dt[#dt + 1] = nm .. " " .. drills[nm] end
  local left = 0
  for _, e in ipairs(s.find_entities_filtered({ name = "coal", position = { r.coal_at[1], r.coal_at[2] }, radius = 9 })) do left = left + e.amount end
  ctx.log(string.format("[FO-FONDERIE-BANC] DIAG %s t%s : foreuses de charbon [%s], charbon extrait depuis le debut %d, charbon sur le tronc, le trace et la ligne %d",
    key, when, table.concat(dt, ", "), r.coal_total0 and (r.coal_total0 - left) or -1, coal_net))
  if not r.coal_total0 then r.coal_total0 = left end
end

--- Relevé : minerai restant du gisement, plaques dans les coffres de quai, fabrications de chaque four.
local function sample(ctx, key)
  local s = ctx.surface()
  local r = ctx.state()[key]
  if not r then return nil end
  local left = 0
  for _, e in ipairs(s.find_entities_filtered({ name = r.ore, position = { r.cx, r.cy }, radius = 13 })) do left = left + e.amount end
  local plates, made = 0, {}
  for i, m in ipairs(r.made) do
    if m.ent.valid then
      if m.kind == "coffre" and m.role == "sortie" then plates = plates + m.ent.get_item_count(r.plate) end
      if m.kind == "four" then made[i] = m.ent.products_finished end
    end
  end
  return { left = left, plates = plates, made = made }
end

return {
  description = "FONDERIE : colonnes nourries par tapis, charbon par ligne de foreuses (sans coffre), posees en moteur reel",
  base = nil,
  check_tick = 12600,

  init = function(ctx)
    local s = ctx.surface()
    ctx.prepare_area(X0 - 260, Y0 - 120, X0 + 260, Y0 + 420, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 300, Y0 - 150 }, { X0 + 300, Y0 + 300 } } })) do en.destroy() end
    -- rivière de 3 tuiles (eau AVANT les entités, F135), de haut en bas du second cas
    local water, blocked = {}, {}
    for x = X0 + 30, X0 + 32 do
      for y = Y0 + 40, Y0 + 240 do water[#water + 1] = { name = "water", position = { x, y } }; blocked[Ch.key(x, y)] = true end
    end
    s.set_tiles(water)
    place(ctx, "voie", "iron-ore", "iron-plate", X0, Y0, { X0 + 45, Y0 - 45 }, false, nil)
    place(ctx, "logistique", "copper-ore", "copper-plate", X0, Y0 + 140, { X0 + 58, Y0 + 140 }, true, blocked)
    -- diagnostic (3/11) : la géométrie de « voie », ligne de charbon doublée (Co.COAL_MARGIN = 2) : l'amorçage des fours est-il en cause ?
    place(ctx, "marge", "iron-ore", "iron-plate", X0, Y0 + 330, { X0 + 45, Y0 + 285 }, false, nil, 2)
    -- H-FONDERIE-1 : fantôme d'un souterrain posé avec type = "output", ravivé
    local gh = s.create_entity({ name = "entity-ghost", inner_name = NAMES.souterrain, position = { X0 - 200.5, Y0 - 100.5 }, direction = 2,
      force = "player", type = "output", expires = false })
    local ok, got = false, "aucun fantome"
    if gh then
      local _, ent = gh.revive()
      if ent and ent.valid then got = ent.belt_to_ground_type; ok = got == "output" else got = "ravivage refuse" end
    end
    ctx.log("[FO-FONDERIE-BANC] H-FONDERIE-1 : fantome de souterrain cree avec type output, ravive en " .. tostring(got))
    ctx.check(ok, "H-FONDERIE-1 : le fantome d'un souterrain garde son type (sortie)", tostring(got))
  end,

  tick = function(ctx, e)
    if e.tick == 2 then for _, k in ipairs({ "voie", "logistique", "marge" }) do diag(ctx, k, 2) end end
    if e.tick == T1 then
      local st = ctx.state()
      st.t1 = { voie = sample(ctx, "voie"), logistique = sample(ctx, "logistique"), marge = sample(ctx, "marge") }
      for _, k in ipairs({ "voie", "logistique", "marge" }) do diag(ctx, k, T1) end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    for _, k in ipairs({ "voie", "logistique", "marge" }) do diag(ctx, k, 12600) end
    for _, key in ipairs({ "voie", "logistique", "marge" }) do
      local r, a = st[key], st.t1 and st.t1[key]
      local b = sample(ctx, key)
      if r and a and b then
        local S = defines.entity_status
        local furn, nofuel, prod, drills, nopow, coal_d, coal_nopow, fuelchests, ug, ug_paired, sp, nets = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {}
        for i, m in ipairs(r.made) do
          local en = m.ent
          if en.valid then
            if m.kind == "four" then
              furn = furn + 1
              if en.status == S.no_fuel then nofuel = nofuel + 1 end
              if (b.made[i] or 0) - (a.made[i] or 0) > 0 then prod = prod + 1 end
            elseif m.kind == "foreuse" then
              if m.role == "charbon" then
                coal_d = coal_d + 1
                if en.status == S.no_power or en.status == S.low_power then coal_nopow = coal_nopow + 1 end
              else
                drills = drills + 1
                if en.status == S.no_power or en.status == S.low_power then nopow = nopow + 1 end
              end
            elseif m.kind == "coffre" and m.role == "combustible" then
              fuelchests = fuelchests + 1
            elseif m.kind == "souterrain" then
              ug = ug + 1
              if en.neighbours then ug_paired = ug_paired + 1 end
            elseif m.kind == "repartiteur" then
              sp = sp + 1
            elseif m.kind == "poteau" and en.electric_network_id then
              nets[en.electric_network_id] = true
            end
          end
        end
        local n_nets = 0
        for _ in pairs(nets) do n_nets = n_nets + 1 end
        local mined = a.left - b.left
        local plates = b.plates - a.plates
        ctx.log(string.format("[FO-FONDERIE-BANC] %s fenetre %d-%d : fours %d (sans combustible %d, ont produit %d), minerai extrait %d, plaques au quai %d, foreuses %d (sans courant %d), foreuses de charbon %d (sans courant %d), coffres de combustible %d, souterrains %d (lies %d), repartiteurs %d, reseaux %d",
          key, T1, 12600, furn, nofuel, prod, mined, plates, drills, nopow, coal_d, coal_nopow, fuelchests, ug, ug_paired, sp, n_nets))
        ctx.check(n_nets == 1 and nopow == 0 and coal_nopow == 0, key .. " : un seul reseau, aucune foreuse sans courant",
          n_nets .. " reseau(x), " .. nopow .. " + " .. coal_nopow .. " sans courant")
        ctx.check(nofuel == 0, key .. " : C1 fours sans combustible = 0 (aucun PNJ, aucun coffre)", nofuel .. " / " .. furn)
        ctx.check(furn > 0 and prod >= 0.9 * furn, key .. " : C2 fours en marche >= 90 % (ont produit dans la fenetre)", prod .. " / " .. furn)
        ctx.check(mined > 0 and plates >= 0.9 * mined, key .. " : C3 plaques au quai >= minerai extrait x 0,9", plates .. " / " .. mined)
        ctx.check(fuelchests == 0, key .. " : C4 aucun coffre de combustible a garnir", tostring(fuelchests))
        if r.logistics then
          ctx.check(ug >= 2 and ug_paired == ug and sp >= 1, key .. " : C5 souterrains lies sous la riviere, repartiteurs poses",
            ug .. " souterrains, " .. ug_paired .. " lies, " .. sp .. " repartiteurs")
        else
          ctx.check(ug == 0 and sp == 0, key .. " : C5 ni souterrain ni repartiteur sans la recherche", ug .. " / " .. sp)
        end
      else
        ctx.check(false, key .. " : releves", "cas absent")
      end
    end
  end,
}
