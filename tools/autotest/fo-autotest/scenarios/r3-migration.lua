--[[
  Scénario GREFFÉ « r3-migration » (lot AMELIO-RESSOURCES, 30/10) : une VRAIE sauvegarde 0.6.18 (sans monazite ni
  galène, ni chaîne du thorium) rechargée avec la source du lot. Double source OBLIGATOIRE :
    py -3.9 -B tools/autotest/banc.py --out <archive> --creation "<racine>/fo-logs/2026-10-30_AMELIO/RESSOURCES/src-0.6.18/factorio-overhaul"
       --qui amelio-ressources -- 700 r3-migration <source du lot>
  (src-0.6.18 = git archive 2e087bc + feuilles hors git ; À GARDER)

  Création (0.6.18) : 4 garanties (tungstène, cristal, méthane, champ de cratères) ; un coffre du joueur garni d'uranium
  238 (monnaie de l'âge 9) ; relevé des entités du joueur et de l'état de la garantie.
  Benchmark (lot) : la version ne monte pas, le contenu change : on_configuration_changed (F130) ou le filet de 600 ticks
  pose les 2 taches de sables noirs ET les 2 gisements de galène. Contrôles au tick 650 : 6 ressources traitées, les 4
  anciennes NON refaites, galène complète et à 300-600 tuiles, entités du joueur intactes, technologies du plomb et du
  thorium présentes et non recherchées.
]]

local MONDE = "fo-monde"
local CHECK = 650

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
  description = "AMELIO-RESSOURCES : sauvegarde 0.6.18 rechargee avec la galene et le thorium (sites poses, anciens intacts)",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local spawn = game.forces.player.get_spawn_position(s)
    local ch = s.create_entity({ name = "iron-chest", position = { spawn.x + 12.5, spawn.y + 12.5 }, force = "player" })
    if ch then ch.insert({ name = "uranium-238", count = 40 }) end
    st.chest_pos = { spawn.x + 12.5, spawn.y + 12.5 }
    st.entities = player_entities(s)
    local status = remote.interfaces[MONDE] and remote.call(MONDE, "status") or nil
    st.before = {}
    for _, d in ipairs(status and status.done or {}) do st.before[#st.before + 1] = { key = d.key, phase = d.phase, tick = d.tick } end
    st.had_galena = game.entity_prototypes["fo-galena"] ~= nil
    ctx.log("creation : " .. #st.entities .. " entite(s) du joueur, garanties " .. #st.before .. ", galene " .. tostring(st.had_galena))
  end,

  finish = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.check(not st.had_galena and #(st.before or {}) == 4, "creation par la 0.6.18 : pas de galene, 4 garanties", #(st.before or {}))
    local status = remote.call(MONDE, "status")
    ctx.check(#status.done == 6 and #status.fails == 0, "apres chargement : 6 ressources garanties traitees, aucun echec",
      #status.done .. " traitees, " .. #status.fails .. " echec(s)")
    local same = 0
    for _, b in ipairs(st.before or {}) do
      local d = by_key(status.done, b.key)
      if d and d.phase == b.phase and d.tick == b.tick then same = same + 1 end
    end
    ctx.check(same == 4, "les 4 anciennes garanties ne sont pas refaites", same .. " sur 4")
    local mz = by_key(status.done, "monazite")
    ctx.check(mz and mz.ok and (mz.phase == "config" or mz.phase == "filet"), "monazite : taches posees au chargement",
      mz and tostring(mz.phase) or "non traitee")
    local d = by_key(status.done, "galena")
    local spec = by_key(remote.call(MONDE, "specs"), "galena")
    ctx.check(d and d.ok and (d.phase == "config" or d.phase == "filet") and d.check_natural and #(d.sites or {}) == 2 - (d.found or 0),
      "galene : gisements poses au chargement (sauvegarde existante, gisements connus comptes)",
      d and string.format("phase %s, tick %s, trouve %s, %d site(s)", tostring(d.phase), tostring(d.tick), tostring(d.found), #(d.sites or {})) or "non traitee")
    local bad = {}
    for i, site in ipairs(d and d.sites or {}) do
      local ore = s.find_entities_filtered({ name = "fo-galena", position = { site.x + 0.5, site.y + 0.5 }, radius = spec.core_radius + 1.5 })
      local total = 0
      for _, r in ipairs(ore) do total = total + r.amount end
      if not (#ore == site.entities and total >= spec.min_total and site.dist >= spec.dmin and site.dist <= spec.dmax) then
        bad[#bad + 1] = string.format("site %d (%d, %d) a %.1f : %d entites, %d", i, site.x, site.y, site.dist, #ore, total)
      end
    end
    ctx.check(d and #bad == 0, "gisements de galene complets dans la sauvegarde migree", #bad > 0 and table.concat(bad, " ; ") or nil)
    local now = player_entities(s)
    local alive, set = 0, {}
    for _, u in ipairs(now) do set[u] = true end
    for _, u in ipairs(st.entities or {}) do if set[u] then alive = alive + 1 end end
    local ch = s.find_entity("iron-chest", st.chest_pos)
    ctx.check(alive == #(st.entities or {}) and ch and ch.get_item_count("uranium-238") == 40,
      "entites du joueur intactes, coffre et contenu gardes", alive .. " sur " .. #(st.entities or {}))
    local f = game.forces.player
    local ok = true
    for _, t in ipairs({ "fo-lead-processing", "fo-galena-roasting", "fo-thorium", "fo-superconductors" }) do
      if not (f.technologies[t] and not f.technologies[t].researched) then ok = false end
    end
    ctx.check(ok and not f.recipes["fo-molten-salt-reactor"].enabled and not f.recipes["fo-lead-plate"].enabled,
      "technologies du plomb, du grillage, du thorium et des supraconducteurs presentes, non recherchees ; recettes fermees")
  end,
}
