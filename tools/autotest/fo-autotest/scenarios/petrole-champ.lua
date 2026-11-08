--[[
  Lot PETROLE-RANGEE : micro-banc EN MOTEUR RÉEL de l'extension d'un site de pétrole (script/ai3/petrole.lua : extend_site, freeze_ext,
  step_ext ; shared/ai3/fluides.lua : Fl.ext_step ; shared/ai3/collecteur.lua). Un champ de 30 puits (les 2 premiers déjà équipés par un
  site FICTIF « fini » adopté par remote fo-petrole.ext_bench, un puits noyé sous un étang) est posé près du QG d'une faction ; la
  faction reçoit les technologies et le kit (chevalets, tuyaux, poteaux) comme petrole-site. Chaîne observée : Pet.think -> extend_site
  (demande) -> plan en tranches (collecteur droit, embranchements, ligne principale) -> réserve -> fantômes -> ravivage par les PNJ ->
  chevalets posés, raccordés (fluidbox) et alimentés (réseau électrique). Journal : [FO-PETROLE-CHAMP] (relevés) et les lignes
  [FO-PETROLE] du mod. Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui petrole-rangee -- 9000 petrole-champ <source>
]]

local SETUP, BATCH = 400, 30
local TECHS = { "automation", "electronics", "logistic-science-pack", "steel-processing", "automation-2", "engine",
  "fluid-handling", "oil-processing", "plastics", "advanced-electronics", "sulfur-processing", "chemical-science-pack",
  "electric-energy-distribution-1", "logistics" }
local KIT = { { "pumpjack", 40 }, { "pipe", 900 }, { "medium-electric-pole", 160 }, { "small-electric-pole", 80 }, { "iron-plate", 400 },
  { "iron-gear-wheel", 100 }, { "steel-plate", 100 }, { "inserter", 20 }, { "iron-chest", 20 }, { "boiler", 2 },
  { "steam-engine", 4 }, { "offshore-pump", 3 }, { "coal", 400 } }
local WELLS = 30

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

local function census(s, force)
  local pj = s.find_entities_filtered({ name = "pumpjack", force = force })
  local linked, powered = 0, 0
  for _, e in ipairs(pj) do
    if #e.fluidbox.get_connections(1) > 0 then linked = linked + 1 end
    if e.electric_network_id ~= nil then powered = powered + 1 end
  end
  return #pj, linked, powered
end

return {
  description = "PETROLE-RANGEE : extension d'un site de petrole a tous les puits d'un champ de 30 (collecteur droit, embranchements, ligne principale)",
  base = nil,
  check_tick = 8950,

  init = function(ctx)
    local st = ctx.state()
    if remote.interfaces["fo-pvp"] then remote.call("fo-pvp", "set_difficulty", "peaceful") end
    st.war = remote.call("factorio-overhaul", "war_start", 2, 30, 10)
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
      local FX, FY = math.floor(hq.position.x) + 40, math.floor(hq.position.y) - 70
      st.fx, st.fy = FX, FY
      ctx.prepare_area(FX - 20, FY - 20, FX + 90, FY + 70)
      local force = game.forces[row.force]
      for _, t in ipairs(TECHS) do if force.technologies[t] then force.technologies[t].researched = true end end
      -- nettoyage : aucun arbre, rocher ni falaise dans le champ (le banc mesure la ligne de tuyaux, pas le defrichage)
      for _, en in ipairs(s.find_entities_filtered({ area = { { FX - 15, FY - 15 }, { FX + 85, FY + 65 } }, type = { "tree", "simple-entity", "cliff" } })) do
        en.destroy()
      end
      -- tuiles : tout en terre ferme (l'etang du banc est pose ensuite)
      local fix = {}
      for ty = FY - 15, FY + 65 do for tx = FX - 15, FX + 85 do
        local t = s.get_tile(tx, ty)
        if t.valid and t.collides_with("water-tile") then fix[#fix + 1] = { name = "grass-1", position = { tx, ty } } end
      end end
      if #fix > 0 then s.set_tiles(fix, true, false) end
      -- les deux puits du site de base, puis 28 autres (suite congruentielle, au moins 5 tuiles d'ecart)
      local A, B = { x = FX + 30.5, y = FY + 40.5 }, { x = FX + 36.5, y = FY + 40.5 }
      local wells = { A, B }
      local seed = 20261108
      local function rnd(m) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % m end
      local tries = 0
      while #wells < WELLS and tries < 30000 do
        tries = tries + 1
        local x, y = FX + 3 + rnd(66), FY + 3 + rnd(56)
        local okw = true
        for _, q in ipairs(wells) do if math.abs(q.x - (x + 0.5)) < 5 and math.abs(q.y - (y + 0.5)) < 5 then okw = false end end
        if okw then wells[#wells + 1] = { x = x + 0.5, y = y + 0.5 } end
      end
      for _, w in ipairs(wells) do s.create_entity({ name = "crude-oil", position = w, amount = 300000 }) end
      st.wells = #wells
      -- un etang de 6 x 6 sur le puits n° 9 : puits impossible
      local drown = wells[9]
      local water = {}
      for ty = math.floor(drown.y) - 3, math.floor(drown.y) + 2 do for tx = math.floor(drown.x) - 3, math.floor(drown.x) + 2 do
        water[#water + 1] = { name = "water", position = { tx, ty } }
      end end
      s.set_tiles(water, true, false)
      st.drown = drown
      -- site de base fictif : 2 chevalets plein sud, leur tuyau de brut (7 tuiles), un depart vers le sud (6 tuiles)
      local ents = {}
      local function pump(w)
        local pj = s.create_entity({ name = "pumpjack", position = w, direction = defines.direction.south, force = row.force })
        ents[#ents + 1] = { name = "pumpjack", x = w.x, y = w.y, dir = 4, role = "extracteur" }
        return pj
      end
      local pa, pb = pump(A), pump(B)
      local cy = math.floor(A.y + 2)
      for tx = math.floor(A.x - 1), math.floor(B.x - 1) do
        s.create_entity({ name = "pipe", position = { tx + 0.5, cy + 0.5 }, force = row.force })
        ents[#ents + 1] = { name = "pipe", x = tx + 0.5, y = cy + 0.5, dir = 0, role = "tuyau" }
      end
      local mx = math.floor(A.x - 1) + 3
      for ty = cy + 1, cy + 6 do
        s.create_entity({ name = "pipe", position = { mx + 0.5, ty + 0.5 }, force = row.force })
        ents[#ents + 1] = { name = "pipe", x = mx + 0.5, y = ty + 0.5, dir = 0, role = "tuyau" }
      end
      st.made = pa ~= nil and pb ~= nil
      -- kit au QG
      local put = 0
      for _, it in ipairs(KIT) do put = put + hq.insert({ name = it[1], count = it[2] }) end
      st.ok_bench = remote.call("fo-petrole", "ext_bench", row.key, { res = "crude-oil", x = (A.x + B.x) / 2, y = A.y, ents = ents })
      st.batch = remote.call("fo-petrole", "ext_batch", BATCH)
      ctx.log(string.format("tick %d : champ de %d puits en (%d, %d), site fictif adopte par %s (%s), kit %d objets, lot de %s", e.tick, st.wells, FX, FY,
        row.key, tostring(st.ok_bench), put, tostring(st.batch)))
      return
    end
    if not st.team or not st.made then return end
    if e.tick > SETUP and e.tick % 600 == 0 then
      local okp, stt = pcall(remote.call, "fo-petrole", "status", st.team)
      local site
      for _, x in ipairs((okp and stt and stt.sites) or {}) do if x.key == "bench-champ" then site = x end end
      local n, linked, powered = census(s, st.force)
      st.last = { n = n, linked = linked, powered = powered, site = site }
      st.timeline = st.timeline or {}
      st.timeline[#st.timeline + 1] = { tick = e.tick, n = n }
      ctx.log(string.format("[FO-PETROLE-CHAMP] tick %d : chevalets %d (raccordes %d, alimentes %d) | site ext_id=%s etat=%s exts=%s cov=%s/%s",
        e.tick, n, linked, powered, site and tostring(site.ext_id) or "-", site and tostring(site.ext_state) or "-",
        site and site.exts and tostring(#site.exts) or "0", site and site.cov and tostring(site.cov.eq) or "-", site and site.cov and tostring(site.cov.total) or "-"))
      if st.first_req == nil and site and (site.ext_id or (site.exts and #site.exts > 0)) then st.first_req = e.tick end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    ctx.check(st.made == true and st.ok_bench == true, "champ pose et site fictif adopte", tostring(st.made))
    ctx.check(st.first_req ~= nil, "une extension est demandee par le site fini", tostring(st.first_req))
    local n, linked, powered = 0, 0, 0
    if st.force then n, linked, powered = census(s, st.force) end
    local site = st.last and st.last.site
    local total = site and site.cov and site.cov.total or 0
    ctx.log(string.format("[FO-PETROLE-CHAMP] FIN : chevalets %d, raccordes %d, alimentes %d ; puits du champ %s ; site %s", n, linked, powered, tostring(total),
      site and (tostring(site.ext_state) .. " exts=" .. tostring(site.exts and #site.exts or 0)) or "-"))
    -- 30 puits - 1 noye = 29 equipables ; l'emprise d'un puits peut chevaucher celle de son voisin (ecart minimal 5 : jamais) ; tolerance 2
    ctx.check(n >= 27, "au moins 27 des 29 puits atteignables sont equipes (2 de base + extension)", n .. " chevalets")
    ctx.check(linked == n and n > 0, "chaque chevalet est raccorde a un tuyau", linked .. "/" .. n)
    ctx.check(powered == n and n > 0, "chaque chevalet est dans un reseau electrique", powered .. "/" .. n)
    -- le puits noye n'est pas equipe
    local drown = st.drown
    local bad = drown and s.find_entities_filtered({ name = "pumpjack", position = drown, radius = 1.5 })[1] or nil
    ctx.check(bad == nil, "le puits noye n'a pas de chevalet", bad and "equipe" or "ok")
    -- les tuyaux neufs ne touchent que le reseau de brut : un seul fluide dans tout le champ
    local fl = {}
    for _, p in ipairs(s.find_entities_filtered({ name = "pipe", force = st.force or "player" })) do
      local c = p.get_fluid_contents()
      for name in pairs(c) do fl[name] = true end
    end
    local kinds = 0
    for _ in pairs(fl) do kinds = kinds + 1 end
    ctx.check(kinds <= 1, "un seul fluide dans les tuyaux du champ", tostring(kinds))
  end,
}
