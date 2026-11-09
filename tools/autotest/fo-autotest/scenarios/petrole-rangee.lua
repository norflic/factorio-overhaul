--[[
  Lot PETROLE-RANGEE, étape 2 : micro-banc EN MOTEUR RÉEL de la RANGÉE de modules sur bus (script/ai3/petrole.lua : rangee_check, freeze_rangee,
  step_rangee ; shared/ai3/rangee_fluides.lua ; Fl.ext_step mode rangée). Le site de base est FICTIF (adopté « fini » par remote
  fo-petrole.ext_bench) mais fait de VRAIES entités : chevalet, tuyau de brut, raffinerie, usine du plastique, tuyaux de gaz, bras, coffres. Six autres
  chevalets sont posés sur leurs puits (débit de brut : 7 chevalets = 70 unités/s contre 20 pour un module : 3 modules). Chaîne observée :
  Pet.think -> rangee_check (débit contre consommation, lus aux prototypes) -> chantier de rangée (plan pur : pas, bus, copies) -> réserve -> ravivage
  par les PNJ -> raffineries et usines posées, brut du bus relié à chaque raffinerie (un seul système de fluide), courant.
  Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui petrole-rangee -- 15000 petrole-rangee <source>
  Journal : [FO-PETROLE-RANGEE] (relevés) et les lignes [FO-PETROLE] du mod.
]]

local SETUP = 400
local TECHS = { "automation", "electronics", "logistic-science-pack", "steel-processing", "automation-2", "engine",
  "fluid-handling", "oil-processing", "plastics", "advanced-electronics", "sulfur-processing", "chemical-science-pack",
  "electric-energy-distribution-1", "logistics" }
local KIT = { { "oil-refinery", 6 }, { "chemical-plant", 6 }, { "pipe", 900 }, { "medium-electric-pole", 160 }, { "small-electric-pole", 80 },
  { "inserter", 30 }, { "iron-chest", 30 }, { "pumpjack", 10 }, { "iron-plate", 400 }, { "iron-gear-wheel", 100 }, { "steel-plate", 100 },
  { "boiler", 2 }, { "steam-engine", 4 }, { "offshore-pump", 3 }, { "coal", 400 } }

local function teams()
  local ok, rows = pcall(remote.call, "fo-ia1", "teams")
  local out = {}
  for _, row in ipairs(ok and type(rows) == "table" and rows or {}) do out[#out + 1] = row end
  return out
end

local function place_team_chest(ctx)
  local s = ctx.surface()
  local c = game.forces.player.get_spawn_position(s)
  local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
  local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
  if not chest then return false end
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 100 },
    { "pistol", 3 }, { "firearm-magazine", 60 }, { "burner-mining-drill", 8 }, { "stone-furnace", 8 }, { "iron-chest", 4 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  return true
end

--- Raffineries et usines de la force, entrees de brut raccordees, systemes de fluide des entrees de brut.
local function census(s, force)
  local refs = s.find_entities_filtered({ name = "oil-refinery", force = force })
  local plants = s.find_entities_filtered({ name = "chemical-plant", force = force })
  local linked, powered = 0, 0
  local systems, nsys = {}, 0
  for _, r in ipairs(refs) do
    local ok = true
    for i = 1, 2 do
      if #r.fluidbox.get_connections(i) == 0 then ok = false end
      local sid = r.fluidbox.get_fluid_system_id(i)
      if sid and not systems[sid] then systems[sid] = true; nsys = nsys + 1 end
    end
    if ok then linked = linked + 1 end
    if r.electric_network_id ~= nil then powered = powered + 1 end
  end
  for _, p in ipairs(plants) do if p.electric_network_id ~= nil then powered = powered + 1 end end
  return #refs, #plants, linked, powered, nsys
end

return {
  description = "PETROLE-RANGEE etape 2 : rangee de modules sur bus (raffinerie + usine du plastique copiees le long d'un bus de brut)",
  base = nil,
  check_tick = 14750,

  init = function(ctx)
    local st = ctx.state()
    if remote.interfaces["fo-pvp"] then remote.call("fo-pvp", "set_difficulty", "peaceful") end
    st.war = remote.call("factorio-overhaul", "war_start", 2, 30, 30)
    st.chest = place_team_chest(ctx)
    ctx.log("creation : guerre " .. tostring(st.war))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == SETUP then
      local row = nil
      for _, r in ipairs(teams()) do if r.key ~= "player" then row = row or r end end
      if not row then ctx.log("aucune faction") return end
      st.team, st.force = row.key, row.force
      local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = row.force, limit = 1 })[1]
      if not (hq and hq.valid) then ctx.log("pas de QG") return end
      local FX, FY = math.floor(hq.position.x) + 40, math.floor(hq.position.y) - 110
      st.fx, st.fy = FX, FY
      ctx.prepare_area(FX - 20, FY - 20, FX + 110, FY + 70)
      local force = game.forces[row.force]
      for _, t in ipairs(TECHS) do if force.technologies[t] then force.technologies[t].researched = true end end
      for _, rn in ipairs({ "basic-oil-processing", "plastic-bar" }) do if force.recipes[rn] then force.recipes[rn].enabled = true end end
      for _, en in ipairs(s.find_entities_filtered({ area = { { FX - 15, FY - 15 }, { FX + 105, FY + 65 } }, type = { "tree", "simple-entity", "cliff" } })) do
        en.destroy()
      end
      local fix = {}
      for ty = FY - 15, FY + 65 do for tx = FX - 15, FX + 105 do
        local t = s.get_tile(tx, ty)
        if t.valid and t.collides_with("water-tile") then fix[#fix + 1] = { name = "grass-1", position = { tx, ty } } end
      end end
      if #fix > 0 then s.set_tiles(fix, true, false) end
      -- site de base (decalage (+20, +20) du plan de tests/rangee_fluides_test.lua, a (FX, FY))
      local function at(x, y) return { x = FX + x, y = FY + y } end
      local ents = {}
      local function add(name, x, y, dir, role, recipe)
        local ent = s.create_entity({ name = name, position = at(x, y), direction = dir, force = row.force })
        ents[#ents + 1] = { name = name, x = FX + x, y = FY + y, dir = dir or 0, role = role, recipe = recipe }
        return ent
      end
      -- puits du chevalet de base puis chevalet
      s.create_entity({ name = "crude-oil", position = at(29.5, 39.5), amount = 300000 })
      local pj = add("pumpjack", 29.5, 39.5, defines.direction.north, "extracteur")
      for y = 33, 37 do add("pipe", 30.5, y + 0.5, 0, "tuyau") end
      add("pipe", 29.5, 33.5, 0, "tuyau"); add("pipe", 31.5, 33.5, 0, "tuyau")
      local ref = add("oil-refinery", 30.5, 30.5, defines.direction.north, "machine", "basic-oil-processing")
      local plant = add("chemical-plant", 36.5, 30.5, defines.direction.north, "machine", "plastic-bar")
      for x = 28, 37 do add("pipe", x + 0.5, 27.5, 0, "tuyau") end
      add("pipe", 35.5, 28.5, 0, "tuyau"); add("pipe", 37.5, 28.5, 0, "tuyau")
      if ref and ref.valid then ref.set_recipe("basic-oil-processing") end
      if plant and plant.valid then plant.set_recipe("plastic-bar") end
      add("inserter", 36.5, 32.5, defines.direction.south, "bras-entree")
      add("iron-chest", 36.5, 33.5, 0, "quai")
      add("iron-chest", 40.5, 34.5, 0, "sortie")
      st.made = pj ~= nil and ref ~= nil and plant ~= nil
      -- six autres chevalets sur leurs puits, plus loin au nord : le debit de brut les compte (posés, non reliés)
      local extra = 0
      for i = 0, 5 do
        local w = at(10.5 + i * 8, 6.5)
        s.create_entity({ name = "crude-oil", position = w, amount = 300000 })
        if s.create_entity({ name = "pumpjack", position = w, direction = defines.direction.north, force = row.force }) then extra = extra + 1 end
      end
      st.extra = extra
      -- courant du site de base (le banc n'a pas de poteaux : les chevalets, la raffinerie et l'usine du site doivent etre alimentes comme les copies)
      s.create_entity({ name = "medium-electric-pole", position = at(33.5, 35.5), force = row.force })
      local put = 0
      for _, it in ipairs(KIT) do put = put + hq.insert({ name = it[1], count = it[2] }) end
      st.ok_bench = remote.call("fo-petrole", "ext_bench", row.key, { res = "crude-oil", x = FX + 33.5, y = FY + 33.5, ents = ents, items = { "plastic-bar" },
        quais = { { x = FX + 36.5, y = FY + 33.5, item = "coal" } }, outs = { { x = FX + 40.5, y = FY + 34.5 } } })
      ctx.log(string.format("tick %d : site de base reel en (%d, %d), %d chevalets de debit, adopte par %s (%s), kit %d objets", e.tick, FX, FY, extra + 1, row.key, tostring(st.ok_bench), put))
      return
    end
    if not st.team or not st.made then return end
    if e.tick > SETUP and e.tick % 600 == 0 then
      local okp, stt = pcall(remote.call, "fo-petrole", "status", st.team)
      local site
      for _, x in ipairs((okp and stt and stt.sites) or {}) do if x.key == "bench-champ" then site = x end end
      local nr, np, linked, powered, nsys = census(s, st.force)
      local ex = site and site.ext
      st.last = { nr = nr, np = np, linked = linked, powered = powered, nsys = nsys, site = site }
      ctx.log(string.format("[FO-PETROLE-RANGEE] tick %d : raffineries %d usines %d (entrees de brut raccordees %d, machines alimentees %d, systemes de brut %d) | ext_id=%s etat=%s | chantier %s bati %s/%s manques [%s]",
        e.tick, nr, np, linked, powered, nsys, site and tostring(site.ext_id) or "-", site and tostring(site.ext_state) or "-",
        ex and tostring(ex.state) or "-", ex and tostring(ex.built) or "-", ex and tostring(ex.total) or "-", ex and table.concat(ex.missing or {}, ",") or ""))
      if st.first_req == nil and site and site.ext_id then st.first_req = e.tick end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    ctx.check(st.made == true and st.ok_bench == true, "site de base reel pose et adopte", tostring(st.made))
    ctx.check(st.first_req ~= nil, "une rangee de modules est demandee par le site fini", tostring(st.first_req))
    local nr, np, linked, powered, nsys = 0, 0, 0, 0, 0
    if st.force then nr, np, linked, powered, nsys = census(s, st.force) end
    ctx.log(string.format("[FO-PETROLE-RANGEE] FIN : raffineries %d, usines %d, entrees raccordees %d, alimentees %d, systemes de brut %d", nr, np, linked, powered, nsys))
    -- diagnostic : systemes de fluide des entrees de chaque raffinerie, puis des tuyaux regroupes par systeme (n, boite, fluide)
    if st.force then
      for _, r in ipairs(s.find_entities_filtered({ name = "oil-refinery", force = st.force })) do
        local boxes = {}
        for i = 1, #r.fluidbox do
          local pr = r.fluidbox.get_prototype(i)
          if pr and pr.object_name == nil and #pr > 0 then pr = pr[1] end
          boxes[#boxes + 1] = string.format("%d:%s:sys%s:%dc", i, pr and pr.production_type or "?", tostring(r.fluidbox.get_fluid_system_id(i)), #r.fluidbox.get_connections(i))
        end
        ctx.log(string.format("[FO-PETROLE-RANGEE] raffinerie (%.1f, %.1f) dir %s : boites [%s], courant %s", r.position.x, r.position.y,
          tostring(r.direction), table.concat(boxes, " "), tostring(r.electric_network_id)))
      end
      local groups, order = {}, {}
      for _, pp in ipairs(s.find_entities_filtered({ name = "pipe", force = st.force })) do
        local sid = pp.fluidbox.get_fluid_system_id(1) or 0
        local g = groups[sid]
        if not g then g = { n = 0, x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9, fl = {} }; groups[sid] = g; order[#order + 1] = sid end
        g.n = g.n + 1
        g.x0, g.y0 = math.min(g.x0, pp.position.x), math.min(g.y0, pp.position.y)
        g.x1, g.y1 = math.max(g.x1, pp.position.x), math.max(g.y1, pp.position.y)
        for name in pairs(pp.get_fluid_contents()) do g.fl[name] = true end
      end
      table.sort(order)
      for _, sid in ipairs(order) do
        local g = groups[sid]
        local fl = {}
        for name in pairs(g.fl) do fl[#fl + 1] = name end
        table.sort(fl)
        ctx.log(string.format("[FO-PETROLE-RANGEE] systeme %d : %d tuyaux, boite (%.0f, %.0f) - (%.0f, %.0f), fluides [%s]", sid, g.n, g.x0, g.y0, g.x1, g.y1, table.concat(fl, ",")))
      end
      for _, pl in ipairs(s.find_entities_filtered({ name = "chemical-plant", force = st.force })) do
        ctx.log(string.format("[FO-PETROLE-RANGEE] usine (%.1f, %.1f) : courant %s", pl.position.x, pl.position.y, tostring(pl.electric_network_id)))
      end
    end
    ctx.check(nr >= 3, "3 modules : au moins 3 raffineries (1 de base + 2 copies)", tostring(nr))
    ctx.check(np == nr, "autant d'usines que de raffineries", np .. "/" .. nr)
    ctx.check(linked == nr and nr > 0, "chaque raffinerie a ses deux entrees de brut raccordees", linked .. "/" .. nr)
    ctx.check(nsys == 1 and nr > 0, "toutes les entrees de brut sont sur le MEME systeme de fluide (le bus)", tostring(nsys))
    ctx.check(powered >= nr + np, "machines alimentees en courant", powered .. "/" .. (nr + np))
  end,
}
