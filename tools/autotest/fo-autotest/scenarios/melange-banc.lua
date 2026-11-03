--[[
  Lot MELANGE (retour du DC du 3/11 : « les minerais de charbon prennent la place des minerais de fer sur les convoyeurs, et peu à peu,
  plus de minerai de fer n'arrive ») : le plan de shared/team/champ.lua posé TEL QUEL en moteur réel, par script, sur trois copies du même
  gisement : un champ de fer (ellipse 61 × 17) qui touche un filon de charbon (disque de rayon 4 à cheval sur son bord sud) et porte une
  enclave de charbon 3 × 3.
    - R « regle »   : plan AVEC les tuiles étrangères (spec.foreign, lues au moteur comme script/team/champ.lua) : aucune foreuse sur une
                      zone mêlée (relu au moteur), pas de charbon sur les tapis, les fours reçoivent du fer pendant les 5 dernières min ;
    - T « temoin »  : plan SANS la règle (comme avant le lot) : des foreuses sur la zone mêlée, du charbon sur les tapis (le banc voit le
                      défaut du DC) ;
    - M « releve »  : plan SANS la règle (bande déjà posée d'une vieille partie), puis au tick 6 000 le relevé du mod (remote fo-melange,
                      même code que le relevé des équipes, script/team/melange.lua) : foreuses mêlées retirées, charbon relevé au stock,
                      tapis propres et fours qui reçoivent du fer pendant les 5 dernières min.
  Contrôle final au tick 30 000 ; fenêtre « 5 min » : du tick 12 000 au tick 30 000. Lancement : banc.py --qui MELANGE -- 30300 melange-banc
  <source>. Journal : [FO-MELANGE-BANC].
]]
package.loaded["shared.team.champ_fonderie"] = package.loaded["shared.team.champ_fonderie"] or require("__factorio-overhaul__/shared/team/champ_fonderie")
package.loaded["shared.team.melange"] = package.loaded["shared.team.melange"] or require("__factorio-overhaul__/shared/team/melange")
package.loaded["shared.team.champ_colonne"] = package.loaded["shared.team.champ_colonne"] or require("__factorio-overhaul__/shared/team/champ_colonne")
package.loaded["shared.team.champ"] = package.loaded["shared.team.champ"] or require("__factorio-overhaul__/shared/team/champ")
local Ch = package.loaded["shared.team.champ"]
local Cv = require("__factorio-overhaul__/shared/team/champ_verif")

local X0, Y0 = 4200, 3000
local DY = 60
local RELEVE, MID, CHECK = 6000, 12000, 30000
local ORE, OTHER, PLATE = "iron-ore", "coal", "iron-plate"
local NAMES = { foreuse = "electric-mining-drill", tapis = "transport-belt", poteau = "small-electric-pole", four = "stone-furnace",
  bras = "inserter", coffre = "iron-chest" }

local function data()
  local dp = game.entity_prototypes[NAMES.foreuse]
  local rp = game.entity_prototypes[ORE]
  local pp = game.entity_prototypes[NAMES.poteau]
  local bp = game.entity_prototypes[NAMES.tapis]
  local fp = game.entity_prototypes[NAMES.four]
  local ap = game.entity_prototypes[NAMES.bras]
  local rec = game.recipe_prototypes[PLATE]
  return {
    drill = { size = dp.tile_width, reach = math.floor((2 * dp.mining_drill_radius - dp.tile_width) / 2 + 0.5),
      rate = dp.mining_speed / rp.mineable_properties.mining_time },
    pole = { reach = math.floor(pp.supply_area_distance - 0.5 + 1e-6), wire = pp.max_wire_distance },
    belts = { { lane = bp.belt_speed * 240 } },
    furnace = { size = fp.tile_width, rate = fp.crafting_speed / rec.energy, fuel = fp.burner_prototype ~= nil },
    inserter = { rate = ap.inserter_rotation_speed * 60 },
    cats = dp.resource_categories or {},
  }
end

--- Gisement : fer sur l'ellipse, charbon sur le disque sud et l'enclave (pris au fer). Rend la liste plate des tuiles de fer.
local function field(s, cx, cy)
  local function coal(x, y)
    if (x - (cx + 6)) ^ 2 + (y - (cy + 9)) ^ 2 <= 16 then return true end
    return x >= cx - 14 and x <= cx - 12 and y >= cy - 1 and y <= cy + 1
  end
  local flat, seen = {}, {}
  for x = cx - 30, cx + 30 do
    for y = cy - 8, cy + 14 do
      local in_iron = ((x - cx) / 30) ^ 2 + ((y - cy) / 8) ^ 2 <= 1
      if coal(x, y) then
        s.create_entity({ name = OTHER, position = { x + 0.5, y + 0.5 }, amount = 20000 })
      elseif in_iron then
        s.create_entity({ name = ORE, position = { x + 0.5, y + 0.5 }, amount = 20000 })
        flat[#flat + 1] = x; flat[#flat + 1] = y
      end
      seen[#seen + 1] = true
    end
  end
  return flat
end

--- Tuiles étrangères lues au moteur (même règle que script/team/champ.lua, foreign_in) : autre ressource, catégorie minable.
local function foreign_of(s, cats, x0, y0, x1, y1)
  local out, n = {}, 0
  for _, r in ipairs(s.find_entities_filtered({ area = { { x0, y0 }, { x1 + 1, y1 + 1 } }, type = "resource" })) do
    if r.name ~= ORE and cats[r.prototype.resource_category] then
      out[Ch.key(math.floor(r.position.x), math.floor(r.position.y))] = true; n = n + 1
    end
  end
  return out, n
end

--- Foreuses posées dont la zone (relue au moteur : centre de la ressource à moins du rayon) contient une autre ressource.
local function mixed(s, drills)
  local n = 0
  for _, d in ipairs(drills) do
    if d.valid then
      local rad = d.prototype.mining_drill_radius
      local p = d.position
      for _, r in ipairs(s.find_entities_filtered({ area = { { p.x - rad, p.y - rad }, { p.x + rad, p.y + rad } }, type = "resource" })) do
        if r.name ~= ORE and math.abs(r.position.x - p.x) < rad and math.abs(r.position.y - p.y) < rad then n = n + 1 break end
      end
    end
  end
  return n
end

local function belt_count(belts, name)
  local n = 0
  for _, b in ipairs(belts) do
    if b.valid then for i = 1, b.get_max_transport_line_index() do n = n + b.get_transport_line(i).get_item_count(name) end end
  end
  return n
end

--- Lot MELANGE2 (B1) : une file de 6 tapis vers l'est, voie 1 chargée de plaques, voie 2 de minerai de fer et de charbon.
local function belt_row(s, x0, y, dir_east)
  local belts = {}
  for i = 0, 5 do
    local b = s.create_entity({ name = NAMES.tapis, position = { x0 + i + 0.5, y + 0.5 }, direction = dir_east, force = "player" })
    if b then belts[#belts + 1] = b end
  end
  local n = { plate = 0, ore = 0, coal = 0 }
  if #belts == 6 then
    local l1, l2 = belts[1].get_transport_line(1), belts[1].get_transport_line(2)
    for _ = 1, 12 do if l1.insert_at_back({ name = PLATE, count = 1 }) then n.plate = n.plate + 1 end end
    for _ = 1, 5 do if l2.insert_at_back({ name = ORE, count = 1 }) then n.ore = n.ore + 1 end end
    for _ = 1, 5 do if l2.insert_at_back({ name = OTHER, count = 1 }) then n.coal = n.coal + 1 end end
  end
  return belts, n
end

local function place(ctx, key, cx, cy, with_rule)
  local s = ctx.surface()
  local st = ctx.state()
  local flat = field(s, cx, cy)
  local d = data()
  local foreign, nf = nil, 0
  if with_rule then foreign, nf = foreign_of(s, d.cats, cx - 40, cy - 20, cx + 40, cy + 25) end
  local spec = { ore = flat, blocked = {}, foreign = foreign, drill = d.drill, pole = d.pole, belts = d.belts, furnace = d.furnace,
    inserter = d.inserter, target = { x = cx - 500, y = cy } }
  local plan, why = Ch.plan(spec)
  ctx.check(plan ~= nil, key .. " : plan rendu", tostring(why))
  if not plan then return end
  local rep = Cv.verify(plan, spec)
  ctx.log(string.format("[FO-MELANGE-BANC] %s : regle %s, %d tuile(s) etrangere(s) lue(s), %d foreuses, %d fours, %d tapis ; %s", key,
    with_rule and "oui" or "non", nf, plan.stats.drills, plan.stats.furnaces, plan.stats.belts, Cv.line(rep)))
  local made, failed = {}, 0
  local r = { drills = {}, belts = {}, furnaces = {}, chests = {} }
  for _, e in ipairs(plan.ents) do
    local ent = s.create_entity({ name = NAMES[e.kind], position = { e.x, e.y }, direction = e.dir, force = "player" })
    if ent then
      made[#made + 1] = ent
      if e.kind == "four" then ent.insert({ name = OTHER, count = 5 }); r.furnaces[#r.furnaces + 1] = ent end
      if e.kind == "coffre" and e.role == "combustible" then ent.insert({ name = OTHER, count = 50 }) end
      if e.kind == "coffre" and e.role == "sortie" then r.chests[#r.chests + 1] = ent end
      if e.kind == "foreuse" then r.drills[#r.drills + 1] = ent end
      if e.kind == "tapis" then r.belts[#r.belts + 1] = ent end
    else
      failed = failed + 1
    end
  end
  ctx.check(failed == 0, key .. " : toutes les entites du plan posees", failed .. " refusee(s) sur " .. #plan.ents)
  local poles = {}
  for _, e in ipairs(made) do if e.valid and e.type == "electric-pole" then poles[#poles + 1] = e end end
  for _, p in ipairs(poles) do
    for _, q in ipairs(s.find_entities_filtered({ position = p.position, radius = d.pole.wire, type = "electric-pole", force = "player" })) do
      if q ~= p then p.connect_neighbour(q) end
    end
  end
  local west
  for _, p in ipairs(poles) do if not west or p.position.x < west.position.x then west = p end end
  if west then
    ctx.power(west.position.x - 3, west.position.y)
    for _, q in ipairs(s.find_entities_filtered({ position = { west.position.x - 3, west.position.y }, radius = 1, type = "electric-pole" })) do
      q.connect_neighbour(west)
    end
  end
  r.mixed0 = mixed(s, r.drills)
  r.n_drills = #r.drills
  r.ratio = d.drill.rate / d.furnace.rate -- fours qu'une foreuse nourrit
  ctx.log(string.format("[FO-MELANGE-BANC] %s : %d foreuses posees, dont %d sur une zone melee (relu au moteur)", key, #r.drills, r.mixed0))
  st[key] = r
end

local function active_since(r)
  local n = 0
  for i, f in ipairs(r.furnaces) do
    if f.valid and (f.products_finished or 0) > (r.mid[i] or 0) then n = n + 1 end
  end
  return n
end

local function plates(r)
  local n = 0
  for _, c in ipairs(r.chests) do if c.valid then n = n + c.get_item_count(PLATE) end end
  return n
end

return {
  description = "MELANGE : champ de fer qui touche du charbon (regle, temoin sans regle, releve d'une bande deja posee)",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    ctx.prepare_area(X0 - 120, Y0 - 40, X0 + 80, Y0 + 2 * DY + 40, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    game.forces.player.set_cease_fire("enemy", true)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 300, Y0 - 150 }, { X0 + 300, Y0 + 2 * DY + 150 } } })) do en.destroy() end
    place(ctx, "R", X0, Y0, true)
    place(ctx, "T", X0, Y0 + DY, false)
    place(ctx, "M", X0, Y0 + 2 * DY, false)
    local st = ctx.state()
    st.hq = s.create_entity({ name = "steel-chest", position = { X0 - 100.5, Y0 + 2 * DY + 0.5 }, force = "player" })
    -- lot MELANGE2 : deux foreuses de gabarit (G), zone 5 x 5 de fer ; la seconde a du charbon dans un coin de sa zone
    do
      local gy = Y0 + 2 * DY + 37
      st.G = { drills = {} }
      for i, cx in ipairs({ X0 - 80, X0 - 70 }) do
        for dx = -2, 2 do
          for dy = -2, 2 do
            local name = (i == 2 and dx == 2 and dy == 2) and OTHER or ORE
            s.create_entity({ name = name, position = { cx + dx + 0.5, gy + dy + 0.5 }, amount = 20000 })
          end
        end
        local d = s.create_entity({ name = NAMES.foreuse, position = { cx + 0.5, gy + 0.5 }, direction = defines.direction.north, force = "player" })
        if d then st.G.drills[#st.G.drills + 1] = d end
      end
      ctx.check(#st.G.drills == 2, "G : deux foreuses de gabarit posees", tostring(#st.G.drills))
    end
    -- lot MELANGE2 (B1) : files de tapis chargées de plaques (A : bande ordinaire ; B : colonne)
    st.PA, st.PB = {}, {}
    st.PA.belts, st.PA.n = belt_row(s, X0 - 90, Y0 + 2 * DY + 30, defines.direction.east)
    st.PB.belts, st.PB.n = belt_row(s, X0 - 90, Y0 + 2 * DY + 33, defines.direction.east)
    ctx.log(string.format("[FO-MELANGE-BANC] P : files de tapis posees (%d et %d tapis), objets inseres A %d plaques %d minerai %d charbon, B %d / %d / %d",
      #st.PA.belts, #st.PB.belts, st.PA.n.plate, st.PA.n.ore, st.PA.n.coal, st.PB.n.plate, st.PB.n.ore, st.PB.n.coal))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == RELEVE then
      for _, k in ipairs({ "R", "T", "M" }) do
        local r = st[k]
        if r then r.coal_releve = belt_count(r.belts, OTHER) end
      end
      local m = st.M
      if m and st.hq and st.hq.valid then
        local ok, res = pcall(remote.call, "fo-melange", "releve", { hq = st.hq, resource = ORE, drills = m.drills, belts = m.belts })
        ctx.check(ok, "M : releve du mod appele (remote fo-melange)", tostring(res))
        if ok then
          m.res = res
          local by = {}
          for _, n in ipairs({ OTHER, ORE }) do by[#by + 1] = n .. " " .. tostring(res.by and res.by[n] or 0) end
          ctx.log(string.format("[FO-MELANGE-BANC] M : releve au tick %d : foreuses verifiees %d, melees %d, retirees %d ; objets releves %d (%s) ; charbon sur les tapis avant : %d",
            e.tick, res.checked, res.mixed, res.removed, res.items, table.concat(by, ", "), m.coal_releve or -1))
        end
      end
      -- lot MELANGE2 : relevé des foreuses de gabarit
      if st.G and st.hq and st.hq.valid and #st.G.drills == 2 then
        local ok, res = pcall(remote.call, "fo-melange", "releve", { hq = st.hq, resource = ORE, gabarit = true, drills = st.G.drills, belts = {} })
        ctx.check(ok, "G : releve du mod appele sur les foreuses de gabarit", tostring(res))
        if ok then
          st.G.res = res
          ctx.log(string.format("[FO-MELANGE-BANC] G : releve : verifiees %d, melees %d, retirees %d ; foreuse saine valide %s, foreuse melee valide %s",
            res.checked, res.mixed, res.removed, tostring(st.G.drills[1].valid), tostring(st.G.drills[2].valid)))
        end
      end
      -- lot MELANGE2 (B1) : le même relevé sur les files de plaques (A ordinaire, B colonne)
      if st.hq and st.hq.valid then
        for _, k in ipairs({ "PA", "PB" }) do
          local r = st[k]
          if r and #r.belts == 6 then
            local ok, res = pcall(remote.call, "fo-melange", "releve", { hq = st.hq, resource = ORE, colonne = (k == "PB"), drills = {}, belts = r.belts })
            ctx.check(ok, k .. " : releve du mod appele sur la file de plaques", tostring(res))
            if ok then
              r.res = res
              r.plates_after = belt_count(r.belts, PLATE)
              r.coal_after = belt_count(r.belts, OTHER)
              r.ore_after = belt_count(r.belts, ORE)
              ctx.log(string.format("[FO-MELANGE-BANC] %s : releve : plaques retirees %d, charbon retire %d, minerai retire %d ; sur les tapis apres : plaques %d, charbon %d, minerai %d",
                k, res.by and res.by[PLATE] or 0, res.by and res.by[OTHER] or 0, res.by and res.by[ORE] or 0, r.plates_after, r.coal_after, r.ore_after))
            end
          end
        end
      end
    elseif e.tick == MID then
      for _, k in ipairs({ "R", "T", "M" }) do
        local r = st[k]
        if r then
          r.mid = {}
          for i, f in ipairs(r.furnaces) do r.mid[i] = f.valid and f.products_finished or 0 end
          r.plates_mid = plates(r)
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    for _, k in ipairs({ "R", "T", "M" }) do
      local r = st[k]
      if r and r.mid then
        r.coal_end = belt_count(r.belts, OTHER)
        r.iron_end = belt_count(r.belts, ORE)
        r.active = active_since(r)
        r.mixed_end = mixed(s, r.drills)
        r.plates_win = plates(r) - (r.plates_mid or 0)
        ctx.log(string.format("[FO-MELANGE-BANC] %s : foreuses %d (zone melee au depart %d, a la fin %d) ; tapis : charbon %d (au tick %d : %s), fer %d ; fours %d, recoivent du fer sur les 5 dernieres min %d ; plaques sorties sur la fenetre %d",
          k, r.n_drills, r.mixed0, r.mixed_end, r.coal_end, RELEVE, tostring(r.coal_releve), r.iron_end, #r.furnaces, r.active, r.plates_win))
      end
    end
    local G = st.G
    if G and G.res then
      ctx.check(G.res.checked == 2 and G.res.mixed == 1 and G.res.removed == 1, "G : gabarit, 2 foreuses lues, 1 mêlee retiree",
        string.format("verifiees %s, melees %s, retirees %s", tostring(G.res.checked), tostring(G.res.mixed), tostring(G.res.removed)))
      ctx.check(G.drills[1].valid and not G.drills[2].valid, "G : la foreuse saine reste, la melee est retiree", "")
      ctx.check(st.hq.valid and st.hq.get_item_count(NAMES.foreuse) >= (st.M and st.M.res and st.M.res.removed or 0) + 1, "G : la foreuse retiree est rendue au stock",
        tostring(st.hq.get_item_count(NAMES.foreuse)))
    end
    for _, k in ipairs({ "PA", "PB" }) do
      local r = st[k]
      if r and r.res then
        local by = r.res.by or {}
        local colonne = (k == "PB")
        ctx.check(r.n.plate >= 6 and (by[PLATE] or 0) == 0 and r.plates_after == r.n.plate, k .. " : aucune plaque retiree par le releve (B1), toutes encore sur les tapis",
          string.format("retirees %s, sur les tapis %s / %d", tostring(by[PLATE]), tostring(r.plates_after), r.n.plate))
        ctx.check((by[ORE] or 0) == 0 and r.ore_after == r.n.ore, k .. " : le minerai de la bande n'est jamais retire", string.format("retire %s", tostring(by[ORE])))
        if colonne then
          ctx.check((by[OTHER] or 0) == 0 and r.coal_after == r.n.coal and r.n.coal > 0, "PB : colonne, le charbon de sa seconde voie est admis",
            string.format("retire %s, reste %s / %d", tostring(by[OTHER]), tostring(r.coal_after), r.n.coal))
        else
          ctx.check((by[OTHER] or 0) == r.n.coal and r.coal_after == 0 and r.n.coal > 0, "PA : bande ordinaire, le charbon reste etranger et est releve",
            string.format("retire %s / %d, reste %s", tostring(by[OTHER]), r.n.coal, tostring(r.coal_after)))
        end
      end
    end
    local R, T, M = st.R, st.T, st.M
    if R and R.mid then
      ctx.check(R.n_drills > 0 and R.mixed0 == 0, "R : regle, aucune foreuse posee sur la zone melee (relu au moteur)", R.mixed0 .. " / " .. R.n_drills)
      ctx.check(R.coal_end == 0, "R : aucun charbon sur les tapis", tostring(R.coal_end))
      ctx.check(#R.furnaces > 0 and R.active >= 0.8 * #R.furnaces, "R : fours qui recoivent du fer pendant 5 min (>= 80 %)", R.active .. " / " .. #R.furnaces)
      ctx.check(R.plates_win > 0, "R : plaques sorties pendant les 5 min", tostring(R.plates_win))
    end
    if T and T.mid then
      ctx.check(T.mixed0 >= 1, "T : temoin sans regle, des foreuses sur la zone melee (le banc voit le defaut)", tostring(T.mixed0))
      ctx.check((T.coal_releve or 0) > 0 or T.coal_end > 0, "T : temoin, du charbon sur les tapis (defaut du DC reproduit)",
        tostring(T.coal_releve) .. " / " .. T.coal_end)
    end
    if M and M.mid then
      local res = M.res or {}
      ctx.check((res.mixed or 0) >= 1 and res.removed == res.mixed and res.mixed == M.mixed0, "M : releve, toutes les foreuses melees retirees",
        string.format("%s melees vues, %s retirees, %d au moteur", tostring(res.mixed), tostring(res.removed), M.mixed0))
      ctx.check(M.mixed_end == 0, "M : plus aucune foreuse sur la zone melee", tostring(M.mixed_end))
      ctx.check((res.by and res.by[OTHER] or 0) > 0 and (res.by and res.by[ORE] or 0) == 0, "M : charbon releve au stock, jamais le fer",
        string.format("charbon %s, fer %s", tostring(res.by and res.by[OTHER]), tostring(res.by and res.by[ORE])))
      ctx.check(M.coal_end == 0, "M : aucun charbon sur les tapis a la fin", tostring(M.coal_end))
      -- (foreuses retirées : la fonderie, taillée pour toutes, reçoit moins ; on compte les fours que les foreuses RESTANTES nourrissent)
      local left = 0
      for _, d in ipairs(M.drills) do if d.valid then left = left + 1 end end
      local fed = math.min(#M.furnaces, math.ceil(left * M.ratio - 1e-9))
      ctx.check(fed > 0 and M.active >= 0.8 * fed, "M : fours qui recoivent du fer pendant 5 min (>= 80 % de ceux que les foreuses restantes nourrissent)",
        string.format("%d actifs / %d nourris (%d fours, %d foreuses restantes)", M.active, fed, #M.furnaces, left))
      local hq = st.hq
      ctx.check(hq and hq.valid and hq.get_item_count(NAMES.foreuse) == (res.removed or -1) + (st.G and st.G.res and st.G.res.removed or 0), "M : foreuses retirees rendues au stock (gabarit G compris)",
        tostring(hq and hq.valid and hq.get_item_count(NAMES.foreuse)))
    end
  end,
}
