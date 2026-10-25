--[[
  Scénario GREFFÉ « m0-migration » (lot M0, 23/10) : une VRAIE sauvegarde 0.4.4 (sans garantie des monnaies)
  rechargée avec la source du lot M0. Double source OBLIGATOIRE (tools/autotest/README.md §1.1) :
    $env:FO_CREATE_SRC = "<racine>\fo-logs\2026-10-23_suite\M0\src-0.4.4"   (git archive 93e3d89, version 0.4.4)
    & "<racine>\fo-autotest.bat" nopause 700 m0-migration "<source M0>"
    $env:FO_CREATE_SRC = $null

  Création (0.4.4) : la carte de la graine 20261020 n'a que la zone de départ ; on y pose un coffre du joueur à
  6 tuiles du candidat 2 du tungstène (celui que retient une partie neuve : le candidat 1 est sur l'eau) et on
  relève les entités du joueur.
  Benchmark (M0) : la garantie est posée au chargement, par on_configuration_changed si la version monte, sinon par
  le filet périodique (600 ticks). Contrôles au tick 650 : les 3 ressources traitées une fois, gisements connus
  comptés (sauvegarde existante), sites complets, coffre et entités du joueur intacts, candidat 2 du tungstène
  refusé (« batiment »).
]]

local MONDE = "fo-monde"
local SEED = 20261020
-- Candidat 2 du tungstène pour la graine 20261020 (relevé par le banc « monde » du 23/10 : candidat 1 refusé, sol).
local T2 = { x = -34, y = -361 }
local CHECK = 650

script.on_configuration_changed(function(data)
  local c = data.mod_changes and data.mod_changes["factorio-overhaul"]
  local names = {}
  for name in pairs(data.mod_changes or {}) do names[#names + 1] = name end
  table.sort(names)
  global.m0_config = { tick = game.tick, overhaul = c ~= nil, old = c and c.old_version, new = c and c.new_version }
  log("[FO-M0-MIGRATION] on_configuration_changed (tick " .. game.tick .. ") : factorio-overhaul "
    .. tostring(c and c.old_version) .. " -> " .. tostring(c and c.new_version) .. " ; mod_changes { " .. table.concat(names, ", ")
    .. " } ; mod_startup_settings_changed " .. tostring(data.mod_startup_settings_changed) .. " ; migration_applied "
    .. tostring(data.migration_applied) .. " ; jeu " .. tostring(data.old_version) .. " -> " .. tostring(data.new_version))
end)

local function player_entities(s)
  local list = {}
  for _, e in ipairs(s.find_entities_filtered({ force = "player" })) do
    if e.valid and e.unit_number then list[#list + 1] = e.unit_number end
  end
  table.sort(list)
  return list
end

local function spec_of(specs, key)
  for _, s in ipairs(specs) do if s.key == key then return s end end
end

local function site_ok(s, spec, site)
  local ents = s.find_entities_filtered({ name = spec.resource, position = { site.x + 0.5, site.y + 0.5 }, radius = spec.core_radius + 1.5 })
  local total, wrong = 0, 0
  for _, e in ipairs(ents) do
    total = total + e.amount
    local t = s.get_tile(math.floor(e.position.x), math.floor(e.position.y))
    local d = math.sqrt(e.position.x * e.position.x + e.position.y * e.position.y)
    if t.name ~= spec.tile or d < spec.dmin or d > spec.dmax then wrong = wrong + 1 end
  end
  return #ents == site.entities and total == site.total and wrong == 0,
    string.format("(%d, %d) a %.1f, essai %d : %d entites, %d, hors regle %d", site.x, site.y, site.dist, site.try, #ents, total, wrong)
end

return {
  description = "M0 : sauvegarde 0.4.4 rechargee avec la garantie des monnaies",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    st.version_create = script.active_mods["factorio-overhaul"]
    st.iface_create = remote.interfaces[MONDE] ~= nil
    st.seed = s.map_gen_settings.seed
    s.request_to_generate_chunks({ T2.x, T2.y }, 1)
    s.force_generate_chunk_requests()
    local chest = s.create_entity({ name = "wooden-chest", position = { T2.x + 6.5, T2.y + 0.5 }, force = "player" })
    st.chest = chest and chest.unit_number
    st.player_entities = player_entities(s)
    ctx.log("creation : factorio-overhaul " .. tostring(st.version_create) .. ", interface fo-monde " .. tostring(st.iface_create)
      .. ", graine " .. st.seed .. ", coffre " .. tostring(st.chest) .. ", entites du joueur " .. #st.player_entities)
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local ver = script.active_mods["factorio-overhaul"]
    ctx.check(not st.iface_create and st.seed == SEED and remote.interfaces[MONDE] ~= nil,
      "carte creee SANS garantie (" .. tostring(st.version_create) .. "), rechargee AVEC (" .. tostring(ver) .. ")",
      "interface a la creation " .. tostring(st.iface_create))
    local cfg = global.m0_config
    -- Le moteur appelle on_configuration_changed au chargement de cette carte MÊME sans montée de version (essai du
    -- 23/10, 16:07:34 : mod_changes sans factorio-overhaul) : la voie attendue est « config » dès qu'il est appelé.
    local expected = cfg and "config" or "filet"
    ctx.log("on_configuration_changed : " .. (cfg and string.format("tick %d, factorio-overhaul %s -> %s", cfg.tick, tostring(cfg.old), tostring(cfg.new)) or "non appele")
      .. " ; voie attendue : " .. expected)
    local status = remote.call(MONDE, "status")
    local specs = remote.call(MONDE, "specs")
    -- Lot X1-TITANE : 4 ressources garanties (le champ de cratères de l'ilménite en plus).
    ctx.check(status.runs == 1 and #status.done == #specs, "une seule passe de garantie, " .. #specs .. " ressources traitees",
      "passes " .. status.runs .. ", traitees " .. #status.done)
    for _, d in ipairs(status.done) do
      local spec = spec_of(specs, d.key)
      ctx.check(d.phase == expected and d.check_natural and d.ok and #d.sites == (d.to_place > 0 and (spec.kind == "fluid" and 1 or d.to_place) or 0),
        d.key .. " : posee par la voie « " .. expected .. " », gisements deja connus comptes",
        string.format("phase %s, tick %d, trouve %d (%d), a poser %d, refus %s", tostring(d.phase), d.tick, d.found, d.found_total, d.to_place, table.concat(d.rejected, ",")))
      for _, site in ipairs(d.sites) do
        local ok, detail = site_ok(s, spec, site)
        ctx.check(ok, d.key .. " : site complet (gisement sur le biome, dans l'anneau)", detail)
      end
    end
    local cands = remote.call(MONDE, "candidates", "nauvis", "tungsten", 2)
    local t = status.done[1]
    ctx.check(cands[2].x == T2.x and cands[2].y == T2.y, "candidat 2 du tungstene = celui de la creation (" .. T2.x .. ", " .. T2.y .. ")",
      string.format("(%d, %d)", cands[2].x, cands[2].y))
    local refused2 = false
    for _, r in ipairs(t.rejected) do if r == "2:batiment" then refused2 = true end end
    ctx.check(t.key == "tungsten" and refused2 and t.sites[1] and t.sites[1].try > 2, "tungstene : le candidat 2 (coffre du joueur) est refuse",
      "refus " .. table.concat(t.rejected, ","))
    local now = player_entities(s)
    local same = #now == #st.player_entities
    for i = 1, math.min(#now, #st.player_entities) do if now[i] ~= st.player_entities[i] then same = false end end
    ctx.check(same, "entites du joueur intactes (memes numeros)", #now .. " / " .. #st.player_entities)
  end,
}
