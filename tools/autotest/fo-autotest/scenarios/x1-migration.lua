--[[
  Scénario GREFFÉ « x1-migration » (lot X1-TITANE, 25/10) : une VRAIE sauvegarde 0.4.16 (sans titane) rechargée avec
  la source du lot. Double source OBLIGATOIRE (tools/autotest/README.md §1.1) :
    $env:FO_CREATE_SRC = "<racine>\fo-logs\2026-10-25_X1\src-0.4.16"   (git archive de main f625f17, version 0.4.16)
    & "<racine>\fo-autotest.bat" nopause 700 x1-migration "<source X1>"
    $env:FO_CREATE_SRC = $null

  Création (0.4.16) : la partie a ses 3 sites garantis (tungstène, cristal, méthane) ; on pose un coffre du joueur et on
  relève les entités du joueur et l'état de la garantie.
  Benchmark (X1) : la version ne monte pas (info.json inchangé), mais le contenu change : on_configuration_changed
  (F130) ou, à défaut, le filet de 600 ticks pose le CHAMP DE CRATÈRES (gisements connus comptés). Contrôles au
  tick 650 : 4 ressources traitées, les 3 anciennes NON refaites, le champ complet (ilménite, 3 puits de saumure, sol
  des cratères, 400-900 tuiles), entités du joueur intactes, prototypes et technologie du titane présents (non
  recherchée), monnaie de l'âge 11 = plaque de titane dans la config chargée.
]]

local MONDE = "fo-monde"
local LV = require("__factorio-overhaul__/shared/levels/config")
local CHECK = 650

script.on_configuration_changed(function(data)
  local c = data.mod_changes and data.mod_changes["factorio-overhaul"]
  local names = {}
  for name in pairs(data.mod_changes or {}) do names[#names + 1] = name end
  table.sort(names)
  global.x1_config = { tick = game.tick, overhaul = c ~= nil }
  log("[FO-X1-MIGRATION] on_configuration_changed (tick " .. game.tick .. ") : factorio-overhaul "
    .. tostring(c and c.old_version) .. " -> " .. tostring(c and c.new_version) .. " ; mod_changes { " .. table.concat(names, ", ") .. " }")
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
  description = "X1 : sauvegarde 0.4.16 rechargee avec le titane (champ de crateres pose, anciens sites intacts)",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local spawn = game.forces.player.get_spawn_position(s)
    local ch = s.create_entity({ name = "iron-chest", position = { spawn.x + 12.5, spawn.y + 12.5 }, force = "player" })
    if ch then ch.insert({ name = "iron-plate", count = 50 }) end
    st.entities = player_entities(s)
    local status = remote.interfaces[MONDE] and remote.call(MONDE, "status") or nil
    st.before = {}
    for _, d in ipairs(status and status.done or {}) do st.before[#st.before + 1] = { key = d.key, phase = d.phase, tick = d.tick } end
    st.had_titanium = game.item_prototypes["fo-titanium-plate"] ~= nil
    ctx.log("creation : " .. #st.entities .. " entite(s) du joueur, garanties " .. #st.before .. ", titane " .. tostring(st.had_titanium))
  end,

  finish = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.check(not st.had_titanium and #(st.before or {}) == 3, "creation par la 0.4.16 : pas de titane, 3 garanties", #(st.before or {}))
    local status = remote.call(MONDE, "status")
    ctx.check(#status.done == 4 and #status.fails == 0, "apres chargement : 4 ressources garanties traitees, aucun echec",
      #status.done .. " traitees, " .. #status.fails .. " echec(s)")
    local same = 0
    for _, b in ipairs(st.before or {}) do
      local d = by_key(status.done, b.key)
      if d and d.phase == b.phase and d.tick == b.tick then same = same + 1 end
    end
    ctx.check(same == 3, "les 3 anciennes garanties ne sont pas refaites", same .. " sur 3")
    local d = by_key(status.done, "ilmenite")
    local spec = by_key(remote.call(MONDE, "specs"), "ilmenite")
    local site = d and d.sites and d.sites[1]
    ctx.check(d and d.ok and (d.phase == "config" or d.phase == "filet") and d.check_natural and d.found == 0 and site,
      "ilmenite : champ pose au chargement (sauvegarde existante, gisements connus comptes)",
      d and string.format("phase %s, tick %s, trouve %s", tostring(d.phase), tostring(d.tick), tostring(d.found)) or "non traitee")
    if site and spec then
      local c = { site.x + 0.5, site.y + 0.5 }
      local ore = s.find_entities_filtered({ name = "fo-ilmenite", position = c, radius = spec.core_radius + 1.5 })
      local wells = s.find_entities_filtered({ name = "fo-brine", position = c, radius = spec.core_radius + 1.5 })
      local total, wrong = 0, 0
      for _, r in ipairs(ore) do
        total = total + r.amount
        if s.get_tile(math.floor(r.position.x), math.floor(r.position.y)).name ~= "fo-crater-fields" then wrong = wrong + 1 end
      end
      ctx.check(#ore == site.entities and total >= spec.min_total and #wells == 3 and wrong == 0 and site.dist >= spec.dmin and site.dist <= spec.dmax,
        "champ complet dans la sauvegarde migree", string.format("(%d, %d) a %.1f : %d entites, %d ; puits %d ; hors sol %d", site.x, site.y,
          site.dist, #ore, total, #wells, wrong))
    end
    local now = player_entities(s)
    local alive = 0
    local set = {}
    for _, u in ipairs(now) do set[u] = true end
    for _, u in ipairs(st.entities or {}) do if set[u] then alive = alive + 1 end end
    ctx.check(alive == #(st.entities or {}), "entites du joueur intactes", alive .. " sur " .. #(st.entities or {}))
    local t = game.forces.player.technologies["fo-titanium-processing"]
    ctx.check(t and not t.researched and not game.forces.player.recipes["fo-titanium-plate"].enabled,
      "technologie du titane presente, non recherchee ; recette de la plaque fermee")
    ctx.check(LV.epoch_materials[11].item == "fo-titanium-plate" and game.item_prototypes["fo-titanium-plate"] ~= nil,
      "monnaie de l'age 11 : plaque de titane (config chargee), objet present")
    ctx.log("on_configuration_changed vu : " .. tostring(global.x1_config ~= nil))
  end,
}
