--[[
  Scénario GREFFÉ « x3m-migration » (lot X3-MINERAIS, 30/10) : une VRAIE sauvegarde 0.6.22 (sans quartz filonien ni fonderie
  de puces) rechargée avec la source du lot. Double source OBLIGATOIRE :
    py -3.9 -B tools/autotest/banc.py --out <archive> --creation "<copie de la 0.6.22 : git archive jouable-0.6.22 + feuilles>"
       --qui x3-minerais -- 700 x3m-migration <source du lot>
  Création (0.6.22) : 10 garanties ; un coffre du joueur garni de processeurs ; relevé des entités du joueur et des garanties.
  Benchmark (lot) : la version ne monte pas, le contenu change : on_configuration_changed (F130) ou le filet de 600 ticks pose
  les 2 veines de quartz. Contrôles au tick 650 : 11 ressources traitées, les 10 anciennes NON refaites, quartz complet sur la
  plaine de cristal à 400-800 tuiles, entités du joueur intactes, fonderie de puces présente et non recherchée.
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
  description = "X3-MINERAIS : sauvegarde 0.6.22 rechargee avec le quartz filonien et la fonderie de puces (veines posees, anciens intacts)",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local spawn = game.forces.player.get_spawn_position(s)
    local ch = s.create_entity({ name = "iron-chest", position = { spawn.x + 12.5, spawn.y + 12.5 }, force = "player" })
    if ch then ch.insert({ name = "processing-unit", count = 40 }) end
    st.chest_pos = { spawn.x + 12.5, spawn.y + 12.5 }
    st.entities = player_entities(s)
    local status = remote.interfaces[MONDE] and remote.call(MONDE, "status") or nil
    st.before = {}
    for _, d in ipairs(status and status.done or {}) do st.before[#st.before + 1] = { key = d.key, phase = d.phase, tick = d.tick } end
    st.had_quartz = game.entity_prototypes["fo-vein-quartz"] ~= nil
    ctx.log("creation : " .. #st.entities .. " entite(s) du joueur, garanties " .. #st.before .. ", quartz " .. tostring(st.had_quartz))
  end,

  finish = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local nb = #(st.before or {})
    ctx.check(not st.had_quartz and nb == 10, "creation par la 0.6.22 : pas de quartz, 10 garanties", nb)
    local status = remote.call(MONDE, "status")
    local nspecs = #remote.call(MONDE, "specs")
    ctx.check(#status.done == nspecs and nspecs == 11 and #status.fails == 0, "apres chargement : 11 ressources garanties traitees, aucun echec",
      #status.done .. " traitees sur " .. nspecs .. ", " .. #status.fails .. " echec(s)")
    local same = 0
    for _, b in ipairs(st.before or {}) do
      local d = by_key(status.done, b.key)
      if d and d.phase == b.phase and d.tick == b.tick then same = same + 1 end
    end
    ctx.check(same == nb and nb == 10, "les 10 anciennes garanties ne sont pas refaites", same .. " sur " .. nb)
    local d = by_key(status.done, "quartz")
    local spec = by_key(remote.call(MONDE, "specs"), "quartz")
    ctx.check(d and d.ok and (d.phase == "config" or d.phase == "filet") and d.check_natural and #(d.sites or {}) == 2,
      "quartz : 2 veines posees au chargement (sauvegarde existante ; aucune naturelle)",
      d and string.format("phase %s, tick %s, trouve %s, %d site(s)", tostring(d.phase), tostring(d.tick), tostring(d.found), #(d.sites or {})) or "non traitee")
    local bad = {}
    for i, site in ipairs(d and d.sites or {}) do
      local ore = s.find_entities_filtered({ name = "fo-vein-quartz", position = { site.x + 0.5, site.y + 0.5 }, radius = spec.core_radius + 1.5 })
      local total, wrong = 0, 0
      for _, r in ipairs(ore) do
        total = total + r.amount
        if s.get_tile(math.floor(r.position.x), math.floor(r.position.y)).name ~= "fo-crystal-flats" then wrong = wrong + 1 end
      end
      if not (#ore == site.entities and total >= spec.min_total and wrong == 0 and site.dist >= spec.dmin and site.dist <= spec.dmax) then
        bad[#bad + 1] = string.format("site %d (%d, %d) a %.1f : %d entites, %d, %d hors plaine", i, site.x, site.y, site.dist, #ore, total, wrong)
      end
    end
    ctx.check(d and #bad == 0, "veines de quartz completes, sur la plaine de cristal, dans la sauvegarde migree", #bad > 0 and table.concat(bad, " ; ") or nil)
    local now = player_entities(s)
    local alive, set = 0, {}
    for _, u in ipairs(now) do set[u] = true end
    for _, u in ipairs(st.entities or {}) do if set[u] then alive = alive + 1 end end
    local ch = s.find_entity("iron-chest", st.chest_pos)
    ctx.check(alive == #(st.entities or {}) and ch and ch.get_item_count("processing-unit") == 40,
      "entites du joueur intactes, coffre et contenu gardes", alive .. " sur " .. #(st.entities or {}))
    local f = game.forces.player
    local t = f.technologies["fo-chip-foundry"]
    ctx.check(t and not t.researched and f.recipes["fo-etched-processor"] and not f.recipes["fo-etched-processor"].enabled
      and f.recipes["processing-unit"] and game.recipe_prototypes["fo-cleanroom-processor"] ~= nil,
      "fonderie de puces presente, non recherchee, recettes fermees ; processeur vanilla et de la salle blanche gardes")
  end,
}
