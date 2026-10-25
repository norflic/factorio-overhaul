--[[
  Scénario GREFFÉ « monde » (lot M0, 23/10) : garantie des monnaies des époques 5, 7 et 8 (tungstène, cristal,
  méthane) en moteur réel, sur PLUSIEURS GRAINES sans modifier fo-autotest.bat (qui fixe la graine 20261020) :
  chaque graine est jouée sur une surface créée par le scénario (game.create_surface avec les réglages de nauvis et
  une autre graine : même générateur que nauvis pour cette graine).

  Lancement (sans double source) : & "<racine>\fo-autotest.bat" nopause 300 monde "<source>"

  Cas joués :
  Lot X1-TITANE (25/10) : 4 ressources garanties (l'ilménite de l'âge 11, avec ses 3 puits de saumure sur le même
  disque de champs de cratères, à 400-900 tuiles) ; exploration des surfaces B et C portée à 29 chunks (928 tuiles).
  - N : nauvis (graine 20261020), garantie posée par le mod lui-même à on_init (partie neuve, tick 0) : 3 sites,
    gisement complet, biome sous le gisement, distances, zone cartographiée et étiquette sur la carte ;
  - A<graine> : surface neuve (rien de généré), garantie comme à on_init : 3 sites posés, mêmes contrôles ;
  - B<graine> : surface explorée (chunks générés jusqu'à 23 chunks du départ), relevé des gisements et biomes
    NATURELS (mesure : la garantie était-elle nécessaire ?), puis garantie comme dans une sauvegarde existante
    (gisements connus comptés) : au moins `count` unités à moins de dmax pour chaque ressource ;
  - C : surface explorée SANS les 3 ressources (contrôles d'autoplacement à taille 0) : tout est posé ;
  - D : obstacles : un coffre du joueur sur le candidat 1 du tungstène, de l'eau sous le candidat 2 : candidat 3
    retenu, coffre et eau intacts.
  - F : filet périodique : au tick 300, le cristal de nauvis est « oublié » (fo-monde.forget, banc seulement) ; au
    tick 600, le filet le retraite (gisements connus comptés : son site garanti suffit, rien n'est reposé).
  Les surfaces de banc sont effacées après usage (mémoire). Il faut au moins 700 ticks (contrôle final au tick 660).
]]

local MONDE = "fo-monde"
local SEEDS = { 1, 42, 123456, 987654321, 3141592653 }
local EXPLORE_RADIUS = 29 -- chunks : 928 tuiles, au-delà de la distance maximale (900 depuis le titane, lot X1-TITANE ; 23 avant)
local T_SEED0, T_SEED_STEP, T_C, T_D, T_TAGS, T_FORGET, CHECK = 10, 10, 70, 80, 200, 300, 660

local function call(fn, ...) return remote.call(MONDE, fn, ...) end

local function spec_of(specs, key)
  for _, s in ipairs(specs) do if s.key == key then return s end end
end

local function new_surface(name, seed, no_resources)
  local mgs = game.surfaces[1].map_gen_settings
  mgs.seed = seed
  if no_resources then
    for _, r in ipairs({ "fo-tungsten-ore", "fo-resonance-crystal", "fo-methane", "fo-ilmenite", "fo-brine", "fo-monazite" }) do
      local c = mgs.autoplace_controls[r] or {}
      mgs.autoplace_controls[r] = { frequency = c.frequency or 1, size = 0, richness = c.richness or 1 }
    end
  end
  if game.surfaces[name] then game.delete_surface(name) end
  return game.create_surface(name, mgs)
end

local function explore(s)
  s.request_to_generate_chunks({ 0, 0 }, EXPLORE_RADIUS)
  s.force_generate_chunk_requests()
end

--- Contrôle d'un site posé (rapport `site` de fo-monde) avec les requêtes du moteur. Renvoie ok, détail.
--- Champ (lot X1-TITANE, ilménite) : aussi les puits de saumure du champ (site.wells), sur le même sol.
local function site_ok(s, spec, site, spawn)
  spawn = spawn or { x = 0, y = 0 }
  local wrong_tile, out_ring = 0, 0
  local function look(e)
    local t = s.get_tile(math.floor(e.position.x), math.floor(e.position.y))
    if t.name ~= spec.tile or t.collides_with("water-tile") then wrong_tile = wrong_tile + 1 end
    local dx, dy = e.position.x - spawn.x, e.position.y - spawn.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < spec.dmin or d > spec.dmax then out_ring = out_ring + 1 end
  end
  local ents = s.find_entities_filtered({ name = spec.resource, position = { site.x + 0.5, site.y + 0.5 }, radius = spec.core_radius + 1.5 })
  local total = 0
  for _, e in ipairs(ents) do
    total = total + e.amount
    look(e)
  end
  local wells_ok, wdetail = true, ""
  if spec.field_wells then
    local w = s.find_entities_filtered({ name = spec.field_wells.resource, position = { site.x + 0.5, site.y + 0.5 }, radius = spec.core_radius + 1.5 })
    for _, e in ipairs(w) do look(e) end
    wells_ok = #w == #spec.field_wells.offsets and #w == (site.wells or -1)
    wdetail = string.format(", puits %s %d (rapport %s)", spec.field_wells.resource, #w, tostring(site.wells))
  end
  local enough = spec.kind == "fluid" and #ents == site.units or total >= spec.min_total
  local ok = #ents == site.entities and total == site.total and wrong_tile == 0 and out_ring == 0 and enough and wells_ok
  return ok, string.format("(%d, %d) a %.1f, essai %d : %d entites (rapport %d), %d (rapport %d), hors biome %d, hors anneau %d%s",
    site.x, site.y, site.dist, site.try, #ents, site.entities, total, site.total, wrong_tile, out_ring, wdetail)
end

--- Unités à moins de dmax (après la garantie) : minerai = quantité / min_total, fluide = puits ; champ : 0 sans tous
--- ses puits (comme G.units_found).
local function units_within(s, spec)
  local total, n, near = 0, 0, math.huge
  for _, e in ipairs(s.find_entities_filtered({ name = spec.resource, position = { 0, 0 }, radius = spec.dmax })) do
    total = total + e.amount
    n = n + 1
    local d = math.sqrt(e.position.x * e.position.x + e.position.y * e.position.y)
    if d < near then near = d end
  end
  local units = spec.kind == "fluid" and n or math.floor(total / spec.min_total)
  if spec.field_wells then
    local w = s.count_entities_filtered({ name = spec.field_wells.resource, position = { 0, 0 }, radius = spec.dmax })
    if w < #spec.field_wells.offsets then units = 0 end
  end
  return units, total, n, near
end

local function check_report(ctx, s, specs, report, label, spawn)
  for _, res in ipairs(report.results) do
    local spec = spec_of(specs, res.key)
    ctx.check(res.ok and #res.sites == (spec.kind == "fluid" and (res.to_place > 0 and 1 or 0) or res.to_place),
      label .. " " .. res.key .. " : " .. res.to_place .. " unite(s) a poser, site(s) poses",
      "trouve " .. res.found .. " ; refus " .. table.concat(res.rejected, ","))
    for _, site in ipairs(res.sites) do
      local ok, detail = site_ok(s, spec, site, spawn)
      ctx.check(ok, label .. " " .. res.key .. " : site complet (gisement, biome dessous, dans l'anneau " .. spec.dmin .. "-" .. spec.dmax .. ")", detail)
    end
  end
end

local function natural_survey(ctx, s, specs, label)
  local parts = {}
  for _, spec in ipairs(specs) do
    local units, total, n, near = units_within(s, spec)
    parts[#parts + 1] = string.format("%s %d unite(s) (%d entites, %d, le plus proche a %s)", spec.key, units, n, total,
      near < math.huge and string.format("%.0f", near) or "-")
  end
  local tiles = {}
  for _, b in ipairs({ "fo-volcanic-ash", "fo-crystal-flats", "fo-toxic-marsh", "fo-crater-fields", "fo-black-sands" }) do
    local c = {}
    for _, r in ipairs({ 200, 500, 700, 900 }) do c[#c + 1] = s.count_tiles_filtered({ position = { 0, 0 }, radius = r, name = b }) end
    tiles[#tiles + 1] = b .. " " .. table.concat(c, "/")
  end
  ctx.log(label .. " NATUREL (avant garantie, a moins de dmax) : " .. table.concat(parts, " ; ") .. " ; tuiles a 200/500/700/900 : " .. table.concat(tiles, " ; "))
end

local function after_guarantee(ctx, s, specs, label)
  for _, spec in ipairs(specs) do
    local units, total, n = units_within(s, spec)
    ctx.check(units >= spec.count, label .. " " .. spec.key .. " : au moins " .. spec.count .. " unite(s) a moins de " .. spec.dmax .. " tuiles apres la garantie",
      units .. " unite(s), " .. n .. " entites, " .. total)
  end
end

return {
  description = "M0 : garantie des monnaies des epoques 5, 7, 8 et 11 (champ de crateres, lot X1-TITANE) sur plusieurs graines",
  check_tick = CHECK,
  shots_delay = CHECK + 20,

  -- Session avec images (fo-captures.bat monde) : les trois sites garantis de nauvis, de jour et de nuit.
  -- Sites relevés au tick 1 (le filet du tick 600 réécrit l'état du cristal sans site : il n'en pose pas).
  shots = function(ctx, add)
    for _, site in ipairs(ctx.state().sites or {}) do
      add("site-" .. site.key .. "-jour", site.x + 0.5, site.y + 0.5, 0.5, 0)
      add("site-" .. site.key .. "-nuit", site.x + 0.5, site.y + 0.5, 0.5, 0.5)
      add("site-" .. site.key .. "-pres", site.x + 0.5, site.y + 0.5, 1.5, 0)
    end
  end,

  init = function(ctx)
    local st = ctx.state()
    st.has_iface = remote.interfaces[MONDE] ~= nil
    ctx.log("init : interface " .. MONDE .. " " .. tostring(st.has_iface) .. ", graine " .. game.surfaces[1].map_gen_settings.seed)
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == 1 then
      local specs = call("specs")
      st.specs = specs
      local status = call("status")
      local s = game.surfaces[1]
      ctx.check(status.runs == 1 and #status.done == #specs, "N : une passe de garantie a la creation de la carte, " .. #specs .. " ressources traitees",
        "passes " .. status.runs .. ", traitees " .. #status.done)
      local sites = {}
      for _, d in ipairs(status.done) do
        local spec = spec_of(specs, d.key)
        ctx.check(d.phase == "init" and d.ok and d.check_natural == false and #d.sites == (spec.kind == "fluid" and 1 or spec.count),
          "N " .. d.key .. " : posee a on_init (tick 0, sans compter les gisements connus)", "phase " .. tostring(d.phase) .. ", refus " .. table.concat(d.rejected, ","))
        for _, site in ipairs(d.sites) do
          local ok, detail = site_ok(s, spec, site, game.forces.player.get_spawn_position(s))
          ctx.check(ok, "N " .. d.key .. " : site complet (gisement, biome dessous, dans l'anneau " .. spec.dmin .. "-" .. spec.dmax .. ")", detail)
          sites[#sites + 1] = { key = d.key, x = site.x, y = site.y, r = spec.site_radius, kind = spec.kind, resource = spec.resource,
            icon = spec.icon or spec.resource }
        end
      end
      st.sites = sites
    end
    for i, seed in ipairs(SEEDS) do
      if e.tick == T_SEED0 + (i - 1) * T_SEED_STEP then
        local specs = st.specs
        -- A : surface neuve, garantie comme à on_init.
        local na = "m0-A" .. seed
        local a = new_surface(na, seed)
        local rep = call("apply", na, { decor = true })
        check_report(ctx, a, specs, rep, "A" .. seed)
        -- B : surface explorée, relevé naturel, puis garantie comme dans une sauvegarde existante.
        local nb = "m0-B" .. seed
        local b = new_surface(nb, seed)
        local prof = game.create_profiler()
        explore(b)
        prof.stop()
        local chunks = 0
        for _ in b.get_chunks() do chunks = chunks + 1 end
        log({ "", ctx.tag .. " B" .. seed .. " exploration (" .. chunks .. " chunks) : ", prof })
        natural_survey(ctx, b, specs, "B" .. seed)
        local repb = call("apply", nb, { check_natural = true, decor = true })
        local placed = {}
        for _, res in ipairs(repb.results) do placed[#placed + 1] = res.key .. " " .. res.to_place end
        ctx.log("B" .. seed .. " garantie (sauvegarde existante) : a poser " .. table.concat(placed, ", "))
        check_report(ctx, b, specs, repb, "B" .. seed)
        after_guarantee(ctx, b, specs, "B" .. seed)
        game.delete_surface(a)
        game.delete_surface(b)
      end
    end
    if e.tick == T_C then
      local specs = st.specs
      local c = new_surface("m0-C", 271828, true)
      explore(c)
      natural_survey(ctx, c, specs, "C (sans les 3 ressources)")
      local before = 0
      for _, spec in ipairs(specs) do before = before + c.count_entities_filtered({ name = spec.resource }) end
      ctx.check(before == 0, "C : la carte n'a aucun gisement des 3 ressources (controles d'autoplacement a 0)", before .. " entites")
      local rep = call("apply", "m0-C", { check_natural = true, decor = true })
      check_report(ctx, c, specs, rep, "C")
      after_guarantee(ctx, c, specs, "C")
      game.delete_surface(c)
    elseif e.tick == T_D then
      local d = new_surface("m0-D", 161803)
      local cands = call("candidates", "m0-D", "tungsten", 3)
      local spec = spec_of(st.specs, "tungsten")
      for k = 1, 2 do
        d.request_to_generate_chunks({ cands[k].x, cands[k].y }, 1)
      end
      d.force_generate_chunk_requests()
      local chest = d.create_entity({ name = "wooden-chest", position = { cands[1].x + 6.5, cands[1].y + 0.5 }, force = "player" })
      local water = {}
      for dx = -1, 1 do
        for dy = -1, 1 do water[#water + 1] = { name = "water", position = { cands[2].x + dx, cands[2].y + dy } } end
      end
      d.set_tiles(water)
      -- Le coffre du joueur ne doit pas être posé sur un gisement ni sur l'eau ; s'il manque, le cas est sans objet.
      ctx.check(chest ~= nil, "D : coffre du joueur pose pres du candidat 1")
      local rep = call("apply", "m0-D", { keys = { "tungsten" } })
      local res = rep.results[1]
      ctx.check(res.ok and res.sites[1] and res.sites[1].try == 3 and table.concat(res.rejected, ",") == "1:batiment,2:sol",
        "D : candidat 1 refuse (batiment du joueur), candidat 2 refuse (eau), candidat 3 retenu",
        "refus " .. table.concat(res.rejected, ",") .. " ; essai " .. tostring(res.sites[1] and res.sites[1].try))
      ctx.check(chest and chest.valid and d.get_tile(cands[2].x, cands[2].y).name == "water", "D : coffre intact, eau intacte")
      if res.sites[1] then
        local ok, detail = site_ok(d, spec, res.sites[1])
        ctx.check(ok, "D : site complet au candidat 3", detail)
      end
      game.delete_surface(d)
    elseif e.tick == T_FORGET then
      -- Filet périodique (600 ticks) : le cristal redevient « à traiter » ; son site garanti existe déjà à moins de
      -- dmax, donc le filet le compte et ne pose rien.
      st.forgot = call("forget", "crystal")
    elseif e.tick == T_TAGS then
      local s = game.surfaces[1]
      local f = game.forces.player
      local status = call("status")
      -- Sonde M0 (16:01) : en --create puis --benchmark, rien n'est jamais cartographié (pas même le chunk 0,0, aucun
      -- on_chunk_charted en 300 ticks). Les étiquettes restent alors en attente : c'est ce qu'on contrôle ici ;
      -- l'étiquette posée se contrôle dans une session où la cartographie tourne (fo-captures.bat monde).
      if not f.is_chunk_charted(s, { 0, 0 }) then
        ctx.log("cartographie inactive dans ce mode (chunk 0,0 non cartographie au tick " .. e.tick .. ")")
        ctx.check(status.tags_pending == #(st.sites or {}) and #f.find_chart_tags(s) == 0,
          "N : sans cartographie, une etiquette en attente par site (posee au premier on_chunk_charted du site)",
          status.tags_pending .. " en attente pour " .. #(st.sites or {}) .. " sites")
        return
      end
      ctx.log("cartographie active : etiquettes en attente " .. status.tags_pending)
      for _, site in ipairs(st.sites or {}) do
        local r = site.r
        local area = { { site.x - r, site.y - r }, { site.x + r + 1, site.y + r + 1 } }
        local tags = f.find_chart_tags(s, area)
        local good = 0
        for _, t in ipairs(tags) do
          if t.icon and t.icon.name == (site.icon or site.resource) then good = good + 1 end
        end
        ctx.check(f.is_chunk_charted(s, { math.floor(site.x / 32), math.floor(site.y / 32) }) and good == 1,
          "N " .. site.key .. " : zone du site cartographiee, une etiquette de la ressource sur la carte",
          #tags .. " etiquette(s), " .. good .. " de la ressource ; en attente : " .. status.tags_pending)
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.has_iface, "interface fo-monde presente des la creation")
    local left = 0
    for _, s in pairs(game.surfaces) do if s.name:find("^m0%-") then left = left + 1 end end
    ctx.check(left == 0, "surfaces de banc effacees", left .. " restante(s)")
    local status = call("status")
    local by = {}
    for _, d in ipairs(status.done) do by[d.key] = d end
    local c = by.crystal
    ctx.check(st.forgot and status.runs == 2 and c and c.phase == "filet" and c.tick == 600 and c.check_natural and c.found >= 1 and c.to_place == 0
      and by.tungsten and by.tungsten.phase == "init" and by.methane and by.methane.phase == "init",
      "N : filet periodique (tick 600) : seul le cristal oublie est retraite, son site garanti est compte, rien n'est repose",
      string.format("passes %d ; cristal %s au tick %s, trouve %s, a poser %s", status.runs, tostring(c and c.phase), tostring(c and c.tick),
        tostring(c and c.found), tostring(c and c.to_place)))
  end,
}
