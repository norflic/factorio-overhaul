--[[
  Scénario GREFFÉ « x2-migration » (lot X2, 25/10) : une VRAIE sauvegarde 0.4.25 (sans terres rares) rechargée avec la
  source du lot. Double source OBLIGATOIRE (tools/autotest/README.md §1.1) :
    $env:FO_CREATE_SRC = "<racine>\fo-logs\2026-10-25_X2\src-0.4.25\factorio-overhaul"   (git archive de main e072d1c)
    & "<racine>\fo-autotest.bat" nopause 700 x2-migration "<source X2>"
    $env:FO_CREATE_SRC = $null

  Création (0.4.25) : la partie a ses 4 garanties (tungstène, cristal, méthane, champ de cratères) ; on pose un coffre
  du joueur (avec des moteurs électriques, l'ancienne monnaie provisoire de l'âge 12) et une foreuse ; on relève les
  entités du joueur et l'état de la garantie.
  Benchmark (X2) : la version ne monte pas, le contenu change : on_configuration_changed (F130) ou le filet de 600 ticks
  pose les 2 TACHES DE SABLES NOIRS. Contrôles au tick 650 : 5 ressources traitées, les 4 anciennes NON refaites, les
  2 taches complètes, entités du joueur intactes (coffre et son contenu), prototypes et technologies de l'âge 12
  présents (non recherchés), monnaie de l'âge 12 = bobine dans la config chargée.
]]

local MONDE = "fo-monde"
local LV = require("__factorio-overhaul__/shared/levels/config")
local CHECK = 650

script.on_configuration_changed(function(data)
  local c = data.mod_changes and data.mod_changes["factorio-overhaul"]
  global.x2_config = { tick = game.tick, overhaul = c ~= nil }
  log("[FO-X2-MIGRATION] on_configuration_changed (tick " .. game.tick .. ")")
end)

local function player_entities(s)
  local list = {}
  for _, e in ipairs(s.find_entities_filtered({ force = "player" })) do
    if e.valid and e.unit_number then list[#list + 1] = e.unit_number end
  end
  table.sort(list)
  return list
end

local function by_key(list, key)
  for _, d in ipairs(list or {}) do if d.key == key then return d end end
end

return {
  description = "X2 : sauvegarde 0.4.25 rechargee avec les terres rares (2 taches de sables noirs posees, anciens sites intacts)",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local spawn = game.forces.player.get_spawn_position(s)
    local ch = s.create_entity({ name = "iron-chest", position = { spawn.x + 12.5, spawn.y + 12.5 }, force = "player" })
    if ch then ch.insert({ name = "electric-engine-unit", count = 40 }) end
    st.chest_pos = { spawn.x + 12.5, spawn.y + 12.5 }
    st.entities = player_entities(s)
    local status = remote.interfaces[MONDE] and remote.call(MONDE, "status") or nil
    st.before = {}
    for _, d in ipairs(status and status.done or {}) do st.before[#st.before + 1] = { key = d.key, phase = d.phase, tick = d.tick } end
    st.had_coil = game.item_prototypes["fo-superconducting-coil"] ~= nil
    st.old_item12 = LV.epoch_materials[12].item
    ctx.log("creation : " .. #st.entities .. " entite(s) du joueur, garanties " .. #st.before .. ", bobine " .. tostring(st.had_coil)
      .. ", monnaie 12 " .. tostring(st.old_item12))
  end,

  finish = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.check(not st.had_coil and #(st.before or {}) == 4 and st.old_item12 == "electric-engine-unit",
      "creation par la 0.4.25 : pas de bobine, 4 garanties, monnaie 12 = moteur electrique", #(st.before or {}))
    local status = remote.call(MONDE, "status")
    ctx.check(#status.done == 5 and #status.fails == 0, "apres chargement : 5 ressources garanties traitees, aucun echec",
      #status.done .. " traitees, " .. #status.fails .. " echec(s)")
    local same = 0
    for _, b in ipairs(st.before or {}) do
      local d = by_key(status.done, b.key)
      if d and d.phase == b.phase and d.tick == b.tick then same = same + 1 end
    end
    ctx.check(same == 4, "les 4 anciennes garanties ne sont pas refaites", same .. " sur 4")
    local d = by_key(status.done, "monazite")
    local spec = by_key(remote.call(MONDE, "specs"), "monazite")
    ctx.check(d and d.ok and (d.phase == "config" or d.phase == "filet") and d.check_natural and #(d.sites or {}) == 2 - (d.found or 0),
      "monazite : taches posees au chargement (sauvegarde existante, gisements connus comptes)",
      d and string.format("phase %s, tick %s, trouve %s, %d tache(s)", tostring(d.phase), tostring(d.tick), tostring(d.found), #(d.sites or {})) or "non traitee")
    local bad = {}
    for i, site in ipairs(d and d.sites or {}) do
      local ore = s.find_entities_filtered({ name = "fo-monazite", position = { site.x + 0.5, site.y + 0.5 }, radius = spec.core_radius + 1.5 })
      local total, wrong = 0, 0
      for _, r in ipairs(ore) do
        total = total + r.amount
        if s.get_tile(math.floor(r.position.x), math.floor(r.position.y)).name ~= "fo-black-sands" then wrong = wrong + 1 end
      end
      if not (#ore == site.entities and total >= spec.min_total and wrong == 0 and site.dist >= spec.dmin and site.dist <= spec.dmax) then
        bad[#bad + 1] = string.format("tache %d (%d, %d) a %.1f : %d entites, %d, hors sol %d", i, site.x, site.y, site.dist, #ore, total, wrong)
      end
    end
    ctx.check(d and #bad == 0 and #(d.sites or {}) >= 1, "taches completes dans la sauvegarde migree", #bad > 0 and table.concat(bad, " ; ") or nil)
    local now = player_entities(s)
    local alive, set = 0, {}
    for _, u in ipairs(now) do set[u] = true end
    for _, u in ipairs(st.entities or {}) do if set[u] then alive = alive + 1 end end
    local ch = s.find_entity("iron-chest", st.chest_pos)
    ctx.check(alive == #(st.entities or {}) and ch and ch.get_item_count("electric-engine-unit") == 40,
      "entites du joueur intactes ; ses 40 moteurs electriques restent au coffre (aucune conversion)", alive .. " sur " .. #(st.entities or {}))
    local f = game.forces.player
    local t1, t2 = f.technologies["fo-superconductors"], f.technologies["fo-cryostat"]
    ctx.check(t1 and t2 and not t1.researched and not t2.researched and not f.recipes["fo-superconducting-coil"].enabled,
      "technologies de l'age 12 presentes, non recherchees ; recette de la bobine fermee")
    ctx.check(LV.epoch_materials[12].item == "fo-superconducting-coil" and game.item_prototypes["fo-superconducting-coil"] ~= nil,
      "monnaie de l'age 12 : bobine supraconductrice (config chargee), objet present")
    ctx.log("on_configuration_changed vu : " .. tostring(global.x2_config ~= nil))
  end,
}
