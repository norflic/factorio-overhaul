--[[
  Lot X10, levier L-R2 (7/11) : DE QUOI sont faits les sprites de la vue du DC ? Soustraction par classe, dans UNE session avec
  images sur la SAUVEGARDE du DC (même lancement que x10-rendu : banc.py --sauvegarde ... --captures
  --visuel="--window hd --measure --ticks 7000"). On lit `sprite-count` de perf-stats.csv phase par phase (m2_lecture.py) :
  le nombre de sprites ne dépend PAS de la charge du PC (seules les durées en dépendent) ; --seul n'est utile que pour lire
  aussi R (prepare + cpu-render) par phase.

  Vue : le joueur du DC, zoom 0,5 dans la fenêtre HD (1920 × 1080) = la surface de SA vue habituelle en 4K au zoom 1
  (120 × 67,5 tuiles, MOTEUR.md §13.3). Rectangle d'action : la vue + 3 tuiles de marge (sprites qui débordent).

  Phases (300 ticks mesurés chacune ; d'abord les RÉVERSIBLES, puis les soustractions définitives, sur la COPIE de la partie) :
    temoin-a ; alt-inverse (mode Alt inversé) ; rendu-mod-cache (objets de rendu du mod invisibles) ; nuit (daytime 0,5 figé :
    les couches draw_as_light comptent-elles ?) ; temoin-b ;
    pnj-figes (tous les fo-companion active = false ; 700 ticks d'attente : traces de pas, 600 ticks de vie) ;
    machines-figees (fours, foreuses, chaudières, machines à vapeur, bras, assembleurs, labos de la vue : fumée et couches
    de travail ; 700 ticks d'attente : fumée, 600 ticks) ;
    objets-tapis (objets des tapis de la vue vidés tous les 5 ticks, jusqu'à la fin) ; objets-sol (objets posés au sol
    de la vue détruits : 1 774 à l'essai à blanc, autour du coffre d'équipe) ; decoratifs (détruits dans la vue) ; restes (corpse
    détruits) ; batiments-mod (fo-lvl-*, tourelles lourdes, centre, expérimentaux, Bourdon de la vue détruits ; prédiction
    écrite au journal : nombre × couches de LR2_SPRITES.md) ; ressources (détruites) ; arbres-roches (détruits).
  Recensement de la vue au départ et à la fin (entités par nom, décoratifs, ressources, restes, objets sur les tapis,
  objets de rendu du mod, PNJ en marche). Rien n'est réécrit dans la sauvegarde du DC : la partie du banc est une COPIE.
]]

local VITESSE = 10
local ZOOM = 0.5
local HX, HY = 60 + 3, 33.75 + 3 -- demi-vue en tuiles (1920 / 32 / 0,5 / 2 ; 1080 / 32 / 0,5 / 2) + marge

local PHASES = {
  { name = "temoin-a", at = 120 },
  { name = "alt-inverse", at = 480, set = "alt" },
  { name = "rendu-mod-cache", at = 840, set = "rendu" },
  { name = "nuit", at = 1200, set = "nuit" },
  { name = "temoin-b", at = 1560 },
  { name = "pnj-figes", at = 2570, set = "pnj", lead = 700 },
  { name = "machines-figees", at = 3580, set = "machines", lead = 700 },
  { name = "objets-tapis", at = 3950, set = "tapis", lead = 60 },
  { name = "objets-sol", at = 4320, set = "sol", lead = 60 },
  { name = "decoratifs", at = 4690, set = "decoratifs", lead = 60 },
  { name = "restes", at = 5060, set = "restes", lead = 60 },
  { name = "batiments-mod", at = 5430, set = "mod", lead = 60 },
  { name = "ressources", at = 5800, set = "ressources", lead = 60 },
  { name = "arbres-roches", at = 6170, set = "arbres", lead = 60 },
}
local DUREE = 300
local FIN = 6570
local PROF -- chronomètre de la phase : local au chargement, jamais dans global

local MACHINES = { "assembling-machine", "boiler", "burner-generator", "furnace", "generator", "inserter", "lab", "mining-drill",
  "offshore-pump", "pump", "reactor" }
local MOD_PREFIXES = { "fo-lvl-", "fo-heavy-gun-turret", "fo-command", "fo-faction-hq", "fo-bourdon", "fo-xp-" }

local S = {
  description = "X10 L-R2 : composition des sprites de la vue du DC, soustraction par classe",
  check_tick = -1,
  shots_delay = 6670,
}

local function player() return game.connected_players[1] end

local function rect()
  local p = player()
  local c = p and p.position or { x = 0, y = 0 }
  return { { c.x - HX, c.y - HY }, { c.x + HX, c.y + HY } }
end

local function tally_text(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) if t[a] ~= t[b] then return t[a] > t[b] end return a < b end)
  local parts = {}
  for i = 1, #keys do parts[#parts + 1] = keys[i] .. "=" .. t[keys[i]] end
  return table.concat(parts, ", ")
end

local function is_mod_building(name)
  for _, pfx in ipairs(MOD_PREFIXES) do
    if name:sub(1, #pfx) == pfx then return true end
  end
  return false
end

--- Objets de rendu du mod : total, dans la vue (cible entité ou position dans le rectangle), par type, visibles.
local function mod_render_ids(area, s)
  local ids = rendering.get_all_ids("factorio-overhaul")
  local inside, by_type, visible = {}, {}, 0
  for i = 1, #ids do
    local id = ids[i]
    if rendering.is_valid(id) and rendering.get_surface(id).index == s.index then
      local pos
      local ok, tgt = pcall(rendering.get_target, id)
      if ok and tgt then pos = tgt.entity and tgt.entity.valid and tgt.entity.position or tgt.position end
      if not pos then
        local ok2, lt = pcall(rendering.get_left_top, id)
        if ok2 and lt then pos = lt.entity and lt.entity.valid and lt.entity.position or lt.position end
      end
      if not pos then
        local ok3, fr = pcall(rendering.get_from, id)
        if ok3 and fr then pos = fr.entity and fr.entity.valid and fr.entity.position or fr.position end
      end
      if pos and pos.x >= area[1][1] and pos.x <= area[2][1] and pos.y >= area[1][2] and pos.y <= area[2][2] then
        inside[#inside + 1] = id
        local ty = rendering.get_type(id)
        by_type[ty] = (by_type[ty] or 0) + 1
        if rendering.get_visible(id) then visible = visible + 1 end
      end
    end
  end
  return #ids, inside, by_type, visible
end

local function census(ctx, label)
  local s, area = ctx.surface(), rect()
  local list = s.find_entities_filtered({ area = area })
  local by_name, by_type = {}, {}
  local belts, items, walking, pnj = 0, 0, 0, 0
  local ground, gb = {}, { math.huge, math.huge, -math.huge, -math.huge }
  for i = 1, #list do
    local e = list[i]
    by_name[e.name] = (by_name[e.name] or 0) + 1
    by_type[e.type] = (by_type[e.type] or 0) + 1
    if e.type == "transport-belt" or e.type == "underground-belt" or e.type == "splitter" then
      belts = belts + 1
      for k = 1, e.get_max_transport_line_index() do items = items + e.get_transport_line(k).get_item_count() end
    end
    if e.type == "item-entity" then
      local ok, it = pcall(function() return e.stack.name end)
      it = ok and it or "?"
      ground[it] = (ground[it] or 0) + 1
      local p = e.position
      gb[1], gb[2] = math.min(gb[1], p.x), math.min(gb[2], p.y)
      gb[3], gb[4] = math.max(gb[3], p.x), math.max(gb[4], p.y)
    end
    if e.name == "fo-companion" or e.type == "character" then
      pnj = pnj + 1
      local ok, ws = pcall(function() return e.walking_state end)
      if ok and ws and ws.walking then walking = walking + 1 end
    end
  end
  local deco = #s.find_decoratives_filtered({ area = area })
  local n_ids, inside, rtypes, rvis = mod_render_ids(area, s)
  ctx.log(string.format("RECENSEMENT-VUE %s : tick %d, rectangle (%.1f, %.1f) a (%.1f, %.1f), entites %d, decoratifs %d, tapis %d, objets sur les tapis %d, personnages %d dont en marche %d, rendu du mod %d dont dans la vue %d (visibles %d) : %s",
    label, game.tick, area[1][1], area[1][2], area[2][1], area[2][2], #list, deco, belts, items, pnj, walking, n_ids, #inside, rvis,
    tally_text(rtypes)))
  ctx.log(string.format("RECENSEMENT-VUE %s : objets au sol par objet : %s ; boite (%.1f, %.1f) a (%.1f, %.1f)", label,
    tally_text(ground), gb[1], gb[2], gb[3], gb[4]))
  ctx.log(string.format("RECENSEMENT-VUE %s : types : %s", label, tally_text(by_type)))
  ctx.log(string.format("RECENSEMENT-VUE %s : noms : %s", label, tally_text(by_name)))
  local p = player()
  if p then
    ctx.log(string.format("RECENSEMENT-VUE %s : joueur %s en (%.1f, %.1f), zoom %.2f, mode Alt %s, daytime %.3f", label, p.name,
      p.position.x, p.position.y, ZOOM, tostring(p.game_view_settings.show_entity_info), s.daytime))
  end
end

local APPLY = {}

APPLY.alt = function(ctx, st, on)
  local p = player()
  if not p then return "aucun joueur" end
  if on then
    st.alt0 = p.game_view_settings.show_entity_info
    p.game_view_settings.show_entity_info = not st.alt0
  else
    p.game_view_settings.show_entity_info = st.alt0
  end
  return "mode Alt " .. tostring(p.game_view_settings.show_entity_info)
end

APPLY.rendu = function(ctx, st, on)
  local s = ctx.surface()
  local _, inside = mod_render_ids(rect(), s)
  if on then
    st.caches = {}
    for _, id in ipairs(inside) do
      if rendering.get_visible(id) then st.caches[#st.caches + 1] = id; rendering.set_visible(id, false) end
    end
    return #st.caches .. " objet(s) de rendu du mod caches"
  end
  local n = 0
  for _, id in ipairs(st.caches or {}) do if rendering.is_valid(id) then rendering.set_visible(id, true); n = n + 1 end end
  return n .. " objet(s) rendus visibles"
end

APPLY.nuit = function(ctx, st, on)
  local s = ctx.surface()
  if on then
    st.day0, st.freeze0 = s.daytime, s.freeze_daytime
    s.freeze_daytime = true
    s.daytime = 0.5
  else
    s.daytime = st.day0
    s.freeze_daytime = st.freeze0
  end
  return string.format("daytime %.3f fige %s", s.daytime, tostring(s.freeze_daytime))
end

local function freeze(list)
  local n = 0
  for i = 1, #list do
    local e = list[i]
    if e.valid and e.active then
      if pcall(function() e.active = false end) then n = n + 1 end
    end
  end
  return n
end

APPLY.pnj = function(ctx)
  return freeze(ctx.surface().find_entities_filtered({ name = "fo-companion" })) .. " PNJ figes (toute la carte)"
end

APPLY.machines = function(ctx)
  return freeze(ctx.surface().find_entities_filtered({ area = rect(), type = MACHINES })) .. " machine(s) de la vue figee(s)"
end

APPLY.tapis = function(ctx)
  local list = ctx.surface().find_entities_filtered({ area = rect(), type = { "transport-belt", "underground-belt", "splitter" } })
  local n = 0
  for i = 1, #list do
    local e = list[i]
    for k = 1, e.get_max_transport_line_index() do
      local l = e.get_transport_line(k)
      n = n + l.get_item_count()
      l.clear()
    end
  end
  return n .. " objet(s) retires des tapis"
end

local function destroy_all(list, keep)
  local n, by = 0, {}
  for i = 1, #list do
    local e = list[i]
    if e.valid and not (keep and keep(e)) then
      local name = e.name
      if e.destroy() then n = n + 1; by[name] = (by[name] or 0) + 1 end
    end
  end
  return n, by
end

APPLY.sol = function(ctx)
  local n, by = destroy_all(ctx.surface().find_entities_filtered({ area = rect(), type = "item-entity" }))
  return n .. " objet(s) au sol detruit(s)"
end

APPLY.decoratifs = function(ctx)
  local s, area = ctx.surface(), rect()
  local n = #s.find_decoratives_filtered({ area = area })
  s.destroy_decoratives({ area = area })
  return n .. " decoratif(s) detruit(s)"
end

APPLY.restes = function(ctx)
  local n, by = destroy_all(ctx.surface().find_entities_filtered({ area = rect(), type = "corpse" }))
  return n .. " reste(s) detruit(s) : " .. tally_text(by)
end

APPLY.mod = function(ctx)
  local list = ctx.surface().find_entities_filtered({ area = rect() })
  local sel = {}
  for i = 1, #list do if is_mod_building(list[i].name) then sel[#sel + 1] = list[i] end end
  local n, by = destroy_all(sel)
  return n .. " batiment(s) du mod detruit(s) : " .. tally_text(by)
end

APPLY.ressources = function(ctx)
  local n, by = destroy_all(ctx.surface().find_entities_filtered({ area = rect(), type = "resource" }))
  return n .. " ressource(s) detruite(s) : " .. tally_text(by)
end

APPLY.arbres = function(ctx)
  local n, by = destroy_all(ctx.surface().find_entities_filtered({ area = rect(), type = { "tree", "simple-entity", "cliff" } }))
  return n .. " arbre(s), roche(s), falaise(s) detruit(s) : " .. tally_text(by)
end

S.init = function(ctx)
  local t = game.tick
  S.check_tick = t + FIN
  local st = ctx.state()
  st.debut, st.mesurees = t, 0
  local mods = {}
  for name, v in pairs(script.active_mods) do mods[#mods + 1] = name .. " " .. v end
  table.sort(mods)
  log(string.format("[FO-PERF4] debut tick %d (%.1f min de jeu) ; mode x10-sprites ; mods : %s", t, t / 3600, table.concat(mods, ", ")))
  ctx.call("profiler", false, false)
  game.speed = VITESSE
  ctx.check(t > 0, "partie chargee depuis une sauvegarde (tick de depart > 0)", t)
end

S.tick = function(ctx, e)
  local st = ctx.state()
  if not st.debut then return end
  local rel = e.tick - st.debut
  if rel == 60 then
    local p = player()
    if p then p.zoom = ZOOM end
    census(ctx, "depart")
  end
  if st.tapis_on and rel % 5 == 0 then APPLY.tapis(ctx) end
  for i = 1, #PHASES do
    local ph = PHASES[i]
    local lead = ph.lead or 30
    if ph.set and rel == ph.at - lead then
      local ok, msg = pcall(APPLY[ph.set], ctx, st, true)
      ctx.log(string.format("ACTION %s tick %d : %s", ph.name, e.tick, ok and msg or ("ERREUR " .. tostring(msg))))
      if ph.set == "tapis" then st.tapis_on = true end
    end
    if rel == ph.at then
      local p = player()
      if p then p.zoom = ZOOM end
      ctx.log(string.format("PHASE debut %s tick %d zoom %.2f daytime %.2f", ph.name, e.tick, ZOOM, ctx.surface().daytime))
      st.phase, st.phase_tick = i, e.tick
      PROF = game.create_profiler()
    elseif rel == ph.at + DUREE and st.phase == i and PROF then
      PROF.stop()
      log({ "", ctx.tag, " PHASE fin ", ph.name, " tick ", tostring(e.tick), " ticks ", tostring(e.tick - st.phase_tick), " ", PROF })
      PROF, st.phase = nil, nil
      st.mesurees = st.mesurees + 1
      if ph.set == "alt" or ph.set == "rendu" or ph.set == "nuit" then
        local ok, msg = pcall(APPLY[ph.set], ctx, st, false)
        ctx.log(string.format("RETOUR %s tick %d : %s", ph.name, e.tick, ok and msg or ("ERREUR " .. tostring(msg))))
      end
    end
  end
end

S.finish = function(ctx)
  local st = ctx.state()
  census(ctx, "fin")
  ctx.check(st.mesurees == #PHASES, "phases mesurees", st.mesurees .. " / " .. #PHASES)
  ctx.check(#game.connected_players == 1, "un joueur connecte (la vue du DC)", #game.connected_players)
end

S.shots = function(ctx, add)
  local p = player()
  local pos = p and p.position or { x = 0, y = 0 }
  add("x10-sprites-vue-videe", pos.x, pos.y, ZOOM, nil, {})
end

return S
