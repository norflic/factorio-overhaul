--[[
  Lot X10, levier L-R2 (7/11) : PREUVE de rendu du correctif des objets au sol (lot STOCKAGE-VITAL de charbonmain :
  plus rien répandu au pied du QG, le stock reprend les objets au sol autour du coffre). x10-sprites ne peut pas servir de
  preuve : il détruit lui-même ces objets et fige PNJ et machines. Ici, AUCUNE soustraction, aucun gel : la sauvegarde du DC
  joue telle quelle à vitesse 10, et l'on suit dans le temps ce que voit le DC.

  Même lancement que x10-sprites (banc.py --sauvegarde ... --captures --visuel="--window hd --measure --ticks 4200") ; vue :
  le joueur du DC, zoom 0,5 en HD (sa vue 4K au zoom 1), heure figée à midi. 6 phases CONSÉCUTIVES de 600 ticks (1 min de
  jeu) : sprite-count et R par phase (lr2_lecture.py, m2_lecture.py) ; au début de chaque phase, recensement : objets au sol
  dans la vue (par objet), objets au sol à 12 tuiles du coffre d'équipe, cases libres du coffre d'équipe et des coffres à 12
  tuiles. Rien n'est réécrit dans la sauvegarde du DC (la partie du banc est une COPIE).
]]

local VITESSE = 10
local ZOOM = 0.5
local HX, HY = 60 + 3, 33.75 + 3
local N_PHASES, DUREE, DEBUT = 6, 600, 120 -- 3 600 ticks : au-dela de 10 000, accord du DC (lead, 7/11)
local FIN = DEBUT + N_PHASES * DUREE + 80
local RAYON = 12
local PROF

local S = {
  description = "X10 L-R2 : objets au sol et sprites de la vue du DC dans le temps, sans soustraction",
  check_tick = -1,
  shots_delay = FIN + 100,
}

local function player() return game.connected_players[1] end

local function tally_text(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) if t[a] ~= t[b] then return t[a] > t[b] end return a < b end)
  local parts = {}
  for i = 1, #keys do parts[#parts + 1] = keys[i] .. "=" .. t[keys[i]] end
  return table.concat(parts, ", ")
end

local function ground(s, area)
  local list = s.find_entities_filtered({ area = area, type = "item-entity" })
  local by = {}
  for i = 1, #list do
    local ok, it = pcall(function() return list[i].stack.name end)
    it = ok and it or "?"
    by[it] = (by[it] or 0) + 1
  end
  return #list, by
end

local function census(ctx, label)
  local s, p = ctx.surface(), player()
  local c = p and p.position or { x = 0, y = 0 }
  local n_vue, by_vue = ground(s, { { c.x - HX, c.y - HY }, { c.x + HX, c.y + HY } })
  local chests = s.find_entities_filtered({ name = "fo-team-chest" })
  local txt = "aucun coffre d'equipe"
  if chests[1] then
    local q = chests[1].position
    local area = { { q.x - RAYON, q.y - RAYON }, { q.x + RAYON, q.y + RAYON } }
    local n_qg = ground(s, area)
    local inv = chests[1].get_inventory(defines.inventory.chest)
    local libres, cases = inv and inv.count_empty_stacks() or -1, inv and #inv or -1
    local near = s.find_entities_filtered({ area = area, type = { "container", "logistic-container" }, force = chests[1].force })
    local l2, c2 = 0, 0
    for i = 1, #near do
      local iv = near[i].get_inventory(defines.inventory.chest)
      if iv then l2, c2 = l2 + iv.count_empty_stacks(), c2 + #iv end
    end
    txt = string.format("coffre d'equipe (%.1f, %.1f) : cases libres %d / %d ; coffres a %d tuiles : %d, cases libres %d / %d ; objets au sol a %d tuiles : %d",
      q.x, q.y, libres, cases, RAYON, #near, l2, c2, RAYON, n_qg)
  end
  ctx.log(string.format("SOL %s : tick %d, objets au sol dans la vue %d (%s) ; %s", label, game.tick, n_vue, tally_text(by_vue), txt))
  return n_vue
end

S.init = function(ctx)
  local t = game.tick
  S.check_tick = t + FIN
  local st = ctx.state()
  st.debut, st.mesurees = t, 0
  local mods = {}
  for name, v in pairs(script.active_mods) do mods[#mods + 1] = name .. " " .. v end
  table.sort(mods)
  log(string.format("[FO-PERF4] debut tick %d (%.1f min de jeu) ; mode x10-sol ; mods : %s", t, t / 3600, table.concat(mods, ", ")))
  ctx.call("profiler", false, false)
  game.speed = VITESSE
  local s = ctx.surface()
  ctx.log(string.format("heure de la sauvegarde %.3f ; figee a midi (0) pour le banc", s.daytime))
  s.freeze_daytime = true
  s.daytime = 0
  ctx.check(t > 0, "partie chargee depuis une sauvegarde (tick de depart > 0)", t)
end

S.tick = function(ctx, e)
  local st = ctx.state()
  if not st.debut then return end
  local rel = e.tick - st.debut
  if rel == 60 then
    local p = player()
    if p then p.zoom = ZOOM end
    st.sol0 = census(ctx, "depart")
  end
  if rel < DEBUT or rel > DEBUT + N_PHASES * DUREE or (rel - DEBUT) % DUREE ~= 0 then return end
  local k = math.floor((rel - DEBUT) / DUREE) -- phases finies (Lua 5.2 : pas de « // »)
  if k >= 1 and PROF then
    PROF.stop()
    log({ "", ctx.tag, " PHASE fin ", string.format("t%02d", k), " tick ", tostring(e.tick), " ticks ", tostring(DUREE), " ", PROF })
    PROF = nil
    st.mesurees = st.mesurees + 1
  end
  if k < N_PHASES then
    local p = player()
    if p then p.zoom = ZOOM end
    local name = string.format("t%02d", k + 1)
    st.sol = census(ctx, name)
    ctx.log(string.format("PHASE debut %s tick %d zoom %.2f daytime %.2f", name, e.tick, ZOOM, ctx.surface().daytime))
    PROF = game.create_profiler()
  end
end

S.finish = function(ctx)
  local st = ctx.state()
  local n = census(ctx, "fin")
  ctx.check(st.mesurees == N_PHASES, "phases mesurees", st.mesurees .. " / " .. N_PHASES)
  ctx.check(#game.connected_players == 1, "un joueur connecte (la vue du DC)", #game.connected_players)
  -- Mesure, pas un critère : la ligne dit combien d'objets au sol restent (le correctif est jugé par son lot).
  ctx.log(string.format("BILAN-SOL : objets au sol dans la vue %d au depart, %d a la fin", st.sol0 or -1, n))
end

S.shots = function(ctx, add)
  local p = player()
  local pos = p and p.position or { x = 0, y = 0 }
  add("x10-sol-vue-dc", pos.x, pos.y, ZOOM, nil, {})
end

return S
