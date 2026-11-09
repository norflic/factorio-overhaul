--[[
  Lot PETROLE-RANGEE : micro-banc EN MOTEUR RÉEL de l'extension d'un site de pétrole (script/ai3/petrole.lua : extend_site, freeze_ext,
  step_ext ; shared/ai3/fluides.lua : Fl.ext_step ; shared/ai3/collecteur.lua). Un champ de 30 puits (les 2 premiers déjà équipés par un
  site FICTIF « fini » adopté par remote fo-petrole.ext_bench, un puits noyé sous un étang) est posé près du QG d'une faction ; la
  faction reçoit les technologies et le kit (chevalets, tuyaux, poteaux) comme petrole-site. Chaîne observée : Pet.think -> extend_site
  (demande) -> plan en tranches (collecteur droit, embranchements, ligne principale) -> réserve -> fantômes -> ravivage par les PNJ ->
  chevalets posés, raccordés (fluidbox) et alimentés (réseau électrique). Journal : [FO-PETROLE-CHAMP] (relevés) et les lignes
  [FO-PETROLE] du mod. Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui petrole-rangee -- 41000 petrole-champ <source>
]]

local SETUP, BATCH, POWER = 400, 30, 16000
local TECHS = { "automation", "electronics", "logistic-science-pack", "steel-processing", "automation-2", "engine",
  "fluid-handling", "oil-processing", "plastics", "advanced-electronics", "sulfur-processing", "chemical-science-pack",
  "electric-energy-distribution-1", "logistics" }
local KIT = { { "pumpjack", 40 }, { "pipe", 900 }, { "medium-electric-pole", 160 }, { "small-electric-pole", 80 }, { "iron-plate", 400 },
  { "iron-gear-wheel", 100 }, { "steel-plate", 100 }, { "inserter", 20 }, { "iron-chest", 20 }, { "boiler", 2 },
  { "steam-engine", 4 }, { "offshore-pump", 3 }, { "coal", 400 } }
local WELLS = 30

local STATUS = {}
for name, v in pairs(defines.entity_status) do STATUS[v] = name end

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
  check_tick = 24750,

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
      -- les deux puits du site de base, puis 28 autres (suite congruentielle, au moins 5 tuiles d ecart)
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
      st.wells_list = wells
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
      -- puits d'evacuation du brut (tuyau infini qui retire le brut) au bout de la ligne : le debit extrait est alors celui du reseau, sans contre-pression
      local sink = s.create_entity({ name = "infinity-pipe", position = { mx + 0.5, cy + 7.5 }, force = row.force })
      if sink and sink.valid then sink.set_infinity_pipe_filter({ name = "crude-oil", percentage = 0, mode = "remove" }) end
      st.sink = sink ~= nil
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
    if e.tick == POWER then
      -- courant du banc : la centrale de l'equipe n'est pas finie ; une interface d'energie (10 MW) est posee dans la zone d'un poteau du champ
      local poles = s.find_entities_filtered({ name = { "medium-electric-pole", "small-electric-pole" }, force = st.force })
      local best
      for _, pl in ipairs(poles) do
        if pl.valid and (not best or pl.unit_number < best.unit_number) then best = pl end
      end
      if best then
        local pos = s.find_non_colliding_position("electric-energy-interface", { best.position.x + 2, best.position.y + 2 }, 8, 0.5)
        local eei = pos and s.create_entity({ name = "electric-energy-interface", position = pos, force = st.force })
        if eei and eei.valid then
          eei.power_production = 1e7 / 60
          eei.electric_buffer_size = 1e7
          st.power_tick = e.tick
          st.fs0 = game.forces[st.force].fluid_production_statistics.get_input_count("crude-oil")
        end
      end
      ctx.log(string.format("[FO-PETROLE-CHAMP] tick %d : courant pose (%s), poteaux de l'equipe %d, puits d'evacuation %s", e.tick, tostring(st.power_tick ~= nil), #poles, tostring(st.sink)))
    end
    if e.tick > SETUP and e.tick % 600 == 0 then
      local okp, stt = pcall(remote.call, "fo-petrole", "status", st.team)
      local site
      for _, x in ipairs((okp and stt and stt.sites) or {}) do if x.key == "bench-champ" then site = x end end
      local n, linked, powered = census(s, st.force)
      st.last = { n = n, linked = linked, powered = powered, site = site }
      st.timeline = st.timeline or {}
      st.timeline[#st.timeline + 1] = { tick = e.tick, n = n }
      local ex = site and site.ext
      ctx.log(string.format("[FO-PETROLE-CHAMP] tick %d : chevalets %d (raccordes %d, alimentes %d) | site ext_id=%s etat=%s exts=%s cov=%s/%s | chantier %s bati %s/%s manques [%s]",
        e.tick, n, linked, powered, site and tostring(site.ext_id) or "-", site and tostring(site.ext_state) or "-",
        site and site.exts and tostring(#site.exts) or "0", site and site.cov and tostring(site.cov.eq) or "-", site and site.cov and tostring(site.cov.total) or "-",
        ex and tostring(ex.state) or "-", ex and tostring(ex.built) or "-", ex and tostring(ex.total) or "-", ex and table.concat(ex.missing or {}, ",") or ""))
      if st.power_tick and e.tick > st.power_tick then
        -- diagnostic du debit : statuts des chevalets, remplissage moyen des tuyaux, brut extrait depuis le dernier releve
        local names, cnt = {}, {}
        for _, pj in ipairs(s.find_entities_filtered({ name = "pumpjack", force = st.force })) do
          local nm = STATUS[pj.status] or tostring(pj.status)
          if not cnt[nm] then cnt[nm] = 0; names[#names + 1] = nm end
          cnt[nm] = cnt[nm] + 1
        end
        table.sort(names)
        local parts = {}
        for _, nm in ipairs(names) do parts[#parts + 1] = nm .. "=" .. cnt[nm] end
        local tot, np, mx = 0, 0, 0
        for _, pp in ipairs(s.find_entities_filtered({ name = "pipe", force = st.force })) do
          local c = pp.fluidbox[1]
          local a = c and c.amount or 0
          tot, np, mx = tot + a, np + 1, math.max(mx, a)
        end
        local now = game.forces[st.force].fluid_production_statistics.get_input_count("crude-oil")
        local d = now - (st.fs_prev or st.fs0 or now)
        st.fs_prev = now
        ctx.log(string.format("[FO-PETROLE-CHAMP] debit tick %d : %.1f unites/s sur 10 s ; chevalets [%s] ; tuyaux %d remplis a %.1f en moyenne (max %.1f)", e.tick, d / 10, table.concat(parts, " "), np, np > 0 and tot / np or 0, mx))
      end
      if st.first_req == nil and site and (site.ext_id or (site.exts and #site.exts > 0)) then st.first_req = e.tick end
      if site and site.ext_plan and not st.plan then st.plan = site.ext_plan end
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
    -- le PLAN rend compte de chaque puits hors base : equipe par l'extension, ou ecarte AVEC sa cause ; rien de differe
    local plan = st.plan
    ctx.check(plan ~= nil and plan.n + plan.skipped + plan.deferred == (st.wells or 0) - 2 and plan.deferred == 0 and plan.n >= 25,
      "le plan d'extension rend compte de chaque puits hors base : equipe ou ecarte avec sa cause (>= 25 equipes, aucun differe)",
      plan and string.format("n %s ecartes %s differes %s total %s", tostring(plan.n), tostring(plan.skipped), tostring(plan.deferred), tostring(plan.total)) or "pas de plan")
    -- 100 % des puits ATTEIGNABLES : tout puits sans chevalet a, a la fin, de l'eau ou un batiment sur son emprise 3 x 3 (releve au moteur)
    local free_unequipped, blocked_list = 0, {}
    for _, w in ipairs(st.wells_list or {}) do
      if not s.find_entities_filtered({ name = "pumpjack", position = w, radius = 1.5 })[1] then
        local why
        local wt = s.get_tile(math.floor(w.x), math.floor(w.y))
        if wt.valid and wt.collides_with("water-tile") then why = "eau" end
        for _, en in ipairs(s.find_entities_filtered({ area = { { w.x - 2.5, w.y - 2.5 }, { w.x + 2.5, w.y + 2.5 } } })) do
          if en.name ~= "crude-oil" and not why then
            local bb = en.bounding_box
            if bb.left_top.x < w.x + 1.49 and bb.right_bottom.x > w.x - 1.49 and bb.left_top.y < w.y + 1.49 and bb.right_bottom.y > w.y - 1.49 then why = en.name end
          end
        end
        if why then blocked_list[#blocked_list + 1] = string.format("(%.1f, %.1f) %s", w.x, w.y, why) else free_unequipped = free_unequipped + 1 end
      end
    end
    ctx.log("[FO-PETROLE-CHAMP] puits sans chevalet et justifies par l'emprise : " .. table.concat(blocked_list, " ; "))
    ctx.check(free_unequipped == 0, "100 % des puits atteignables equipes : aucun puits libre (ni eau ni batiment sur son emprise) sans chevalet", tostring(free_unequipped))
    ctx.check(plan ~= nil and n >= plan.n + 2, "le chantier est fini : chevalets = ceux du plan + les 2 de base", n .. " chevalets, plan " .. tostring(plan and plan.n))
    -- FONCTION : part des chevalets qui travaillent, reseau electrique unique, brut reellement extrait depuis la mise sous tension
    local working, nets, netn = 0, {}, 0
    for _, pj in ipairs(s.find_entities_filtered({ name = "pumpjack", force = st.force or "player" })) do
      if pj.status == defines.entity_status.working then working = working + 1 end
      local nid = pj.electric_network_id
      if nid and not nets[nid] then nets[nid] = true; netn = netn + 1 end
    end
    local secs = st.power_tick and (game.tick - st.power_tick) / 60 or 0
    local got = st.fs0 and (game.forces[st.force].fluid_production_statistics.get_input_count("crude-oil") - st.fs0) or 0
    local theo = n * 10 * secs
    ctx.log(string.format("[FO-PETROLE-CHAMP] FONCTION : chevalets en travail %d / %d, reseaux electriques %d, brut extrait %.0f unites en %.0f s (theorique %.0f, %.0f %%)",
      working, n, netn, got, secs, theo, theo > 0 and 100 * got / theo or 0))
    ctx.check(n > 0 and working >= math.ceil(0.9 * n), "au moins 90 % des chevalets poses travaillent (part des puits exploites)", working .. "/" .. n)
    ctx.check(netn == 1, "tous les chevalets sont dans UN SEUL reseau electrique", tostring(netn))
    ctx.check(theo > 0 and got >= 0.6 * theo, "le brut extrait atteint 60 % du debit theorique (chevalets x 10/s x duree sous tension)", string.format("%.0f / %.0f", got, theo))
    ctx.check(linked == n and n > 0, "chaque chevalet est raccorde a un tuyau", linked .. "/" .. n)
    ctx.check(powered >= n - 1 and n > 0, "les chevalets poses sont alimentes (1 en retard au plus)", powered .. "/" .. n)
    -- le puits noye n'est pas equipe
    local drown = st.drown
    local bad = drown and s.find_entities_filtered({ name = "pumpjack", position = drown, radius = 1.5 })[1] or nil
    ctx.check(bad == nil, "le puits noye n'a pas de chevalet", bad and "equipe" or "ok")
    -- diagnostic : ce qui occupe l'emprise de chaque puits SANS chevalet a la fin (cause d'un ecart du plan)
    for _, w in ipairs(st.wells_list or {}) do
      if not s.find_entities_filtered({ name = "pumpjack", position = w, radius = 1.5 })[1] then
        local names = {}
        for _, en in ipairs(s.find_entities_filtered({ area = { { w.x - 2.5, w.y - 2.5 }, { w.x + 2.5, w.y + 2.5 } } })) do
          if en.name ~= "crude-oil" then names[#names + 1] = en.name .. (en.name == "entity-ghost" and ("/" .. en.ghost_name) or "") end
        end
        local tile = s.get_tile(math.floor(w.x), math.floor(w.y))
        ctx.log(string.format("[FO-PETROLE-CHAMP] puits SANS chevalet (%.1f, %.1f) : tuile %s, entites autour [%s]", w.x, w.y, tile.valid and tile.name or "?", table.concat(names, ",")))
      end
    end
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
