--[[
  Micro-banc « piquage-micro » du lot PIQUAGE (8/11) : le PIQUAGE d'un tapis existant (shared/team/piquage.lua, script/team/piquage.lua) contre le
  moteur réel. Chaîne : tapis plein posé par le banc -> relevés -> projet de branche -> tapis, bras, poteau bâtis par les PNJ -> répartiteur posé
  par le script (fast_replace) avec la priorité de sortie sur le tapis PRINCIPAL -> le coffre du quai est servi sans PNJ.
  ÉCRIT LE 8/11 PENDANT LE GEL, NON JOUÉ : à lancer par la file (banc.py ... -- 6000 piquage-micro <source>) après « fin de gel » seulement.

  Terrain : un champ de 180 x 100 tuiles autour de (50, 0), refait en herbe. Votre équipe (coffre d'équipe en (0, 0), 8 PNJ, plan directeur « seul »,
  fo-war-ia3e coupé : le banc tient le rôle du cerveau) reçoit UN module fini fictif (remote fo-piquage inject) dont le quai d'entrée est le coffre
  (60, 6) (plaque de fer, débit nominal 1,0/s).
  Le tapis : de (31, -10) à (89, -10), vers l'est, alimenté par le script (jusqu'à 3 objets/s, tant que le tapis accepte) ; au bout, un bras qui
  vide dans un coffre-puits. La consommation du puits (un bras) est plus lente que l'offre : le tapis est PLEIN (surplus).
  Courant : interface électrique de l'arène + poteaux.

  Fenêtres : S0 (avant le répartiteur) et S1 (après) mesurent le débit du puits et la densité d'une tuile en aval : le répartiteur ne doit pas
  affamer l'aval. W (après le répartiteur) : le quai ramené à 70 est vidé à 0,7/s : il ne passe pas sous 60 et aucun PNJ ne porte.
  Variante « temoin » : la règle est éteinte (set_param off) ; le quai passe sous 60, le PNJ porte.
  Journal : [FO-PIQUAGE-MICRO(-TEMOIN)] + [FO-PIQUAGE] du mod.
]]

local ITEM = "iron-plate"
local DOCK = { x = 60, y = 6 }
local SINK = { x = 91, y = -10 }
local BUF = 1e8
local DRAIN = 0.7
local W = 1200
local WS = 1200
local LOW = 60

local function stock_chest(chest)
  for _, it in ipairs({
    { "iron-plate", 4000 }, { "copper-plate", 400 }, { "coal", 200 }, { "transport-belt", 300 }, { "inserter", 60 }, { "splitter", 3 },
    { "small-electric-pole", 40 }, { "medium-electric-pole", 20 }, { "iron-chest", 20 },
  }) do
    chest.insert({ name = it[1], count = it[2] })
  end
end

local function chest_at(s, x, y) return s.find_entities_filtered({ position = { x + 0.5, y + 0.5 }, radius = 0.4, type = "container", limit = 1 })[1] end
local function count_of(s, x, y) local c = chest_at(s, x, y); return c and c.get_item_count(ITEM) or -1 end
local function set_count(s, x, y, n)
  local c = chest_at(s, x, y)
  if not c then return end
  local have = c.get_item_count(ITEM)
  if have > n then c.remove_item({ name = ITEM, count = have - n }) elseif have < n then c.insert({ name = ITEM, count = n - have }) end
end

local function shape(ctx)
  local s = ctx.surface()
  s.request_to_generate_chunks({ 50, 0 }, 5)
  s.force_generate_chunk_requests()
  for _, e in ipairs(s.find_entities_filtered({ area = { { -40, -50 }, { 140, 50 } }, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
    if e.valid then e.destroy() end
  end
  local tiles = {}
  for y = -50, 49 do for x = -40, 139 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
  s.set_tiles(tiles, true)
end

local function arena(ctx, st)
  local s = ctx.surface()
  local eei = s.create_entity({ name = "electric-energy-interface", position = { 36.5, 6.5 }, force = "player" })
  if eei then eei.electric_buffer_size = BUF; eei.power_production = 0; eei.power_usage = 0; eei.energy = BUF; st.eei = eei end
  local poles = 0
  local function pole(x, y) if s.create_entity({ name = "medium-electric-pole", position = { x + 0.5, y + 0.5 }, force = "player" }) then poles = poles + 1 end end
  for x = 36, 84, 8 do pole(x, 4) end
  pole(36, -2); pole(36, -8)
  for x = 44, 92, 8 do pole(x, -8) end
  ctx.check(eei ~= nil and poles >= 14, "arene alimentee : interface electrique et poteaux", string.format("eei=%s poteaux=%d", tostring(eei ~= nil), poles))
  local n = 0
  for x = 31, 89 do
    if s.create_entity({ name = "transport-belt", position = { x + 0.5, -9.5 }, direction = defines.direction.east, force = "player" }) then n = n + 1 end
  end
  ctx.check(n == 59, "tapis du banc pose (59 tuiles)", tostring(n))
  local sink_arm = s.create_entity({ name = "inserter", position = { 90.5, -9.5 }, direction = defines.direction.west, force = "player" })
  local sink = s.create_entity({ name = "iron-chest", position = { SINK.x + 0.5, SINK.y + 0.5 }, force = "player" })
  ctx.check(sink_arm ~= nil and sink ~= nil, "puits pose (bras + coffre)")
  local dock = s.create_entity({ name = "iron-chest", position = { DOCK.x + 0.5, DOCK.y + 0.5 }, force = "player" })
  ctx.check(dock ~= nil, "coffre de quai pose en (60, 6)")
end

--- Remplit le tapis du banc : insère à l'arrière de chaque voie de la première tuile tant que la voie accepte.
local function feed(s)
  local b = s.find_entities_filtered({ position = { 31.5, -9.5 }, radius = 0.4, type = "transport-belt", limit = 1 })[1]
  if not b then return end
  for i = 1, 2 do
    local l = b.get_transport_line(i)
    if l.can_insert_at_back() then l.insert_at_back({ name = ITEM, count = 1 }) end
  end
end

local function belt_items(s, x, y)
  local b = s.find_entities_filtered({ position = { x + 0.5, y + 0.5 }, radius = 0.4, name = "transport-belt", limit = 1 })[1]
  if not b then return -1 end
  local n = 0
  for i = 1, 2 do for _, c in pairs(b.get_transport_line(i).get_contents()) do n = n + c end end
  return n
end

return function(variant)
  local TAG = "piquage-micro" .. (variant == "temoin" and "-temoin" or "")
  local WITH = variant ~= "temoin"
  return {
    description = "PIQUAGE : surplus d'un tapis existant vers le quai d'un module (" .. variant .. ")",
    base = nil,
    check_tick = 5900,

    init = function(ctx)
      local s = ctx.surface()
      local st = ctx.state()
      shape(ctx)
      game.forces.player.recipes["splitter"].enabled = true
      ctx.check(ctx.call("war_setting", "fo-war-ia3e", false) == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)")
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      stock_chest(chest)
      ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 1 }) == true, "plan directeur active")
      arena(ctx, st)
      set_count(s, DOCK.x, DOCK.y, 400)
      local p = ctx.remote("fo-piquage", "inject", "player", { quais = { { x = DOCK.x + 0.5, y = DOCK.y + 0.5, item = ITEM } }, inflow = { [ITEM] = 1.0 },
        names = { arm = "inserter", pole = "small-electric-pole" } })
      ctx.check(p ~= nil, "module fini fictif injecte", tostring(p))
      ctx.check(ctx.remote("fo-piquage", "set_param", "player", "sans_centrale", true) == true, "sans centrale (banc)")
      ctx.check(ctx.remote("fo-piquage", "set_param", "player", "period", 120) == 120, "releve toutes les 120 ticks")
      ctx.check(ctx.remote("fo-piquage", "set_param", "player", "confirm", 1) == 1, "confirmation en un releve")
      ctx.check(ctx.remote("fo-piquage", "set_param", "player", "disc_every", 300) == 300, "decouverte toutes les 300 ticks (banc)")
      -- tapis plein des le depart (sinon le tapis se remplit pendant 3 000 ticks)
      for _, b in ipairs(s.find_entities_filtered({ area = { { 30, -11 }, { 91, -9 } }, name = "transport-belt" })) do
        for i = 1, 2 do for _ = 1, 4 do b.get_transport_line(i).insert_at_back({ name = ITEM, count = 1 }) end end
      end
      if not WITH then ctx.check(ctx.remote("fo-piquage", "set_param", "player", "off", true) == true, "regle eteinte (temoin)") end
      st.t0 = game.tick
      st.acc, st.log_next = 0, 0
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.t0 then return end
      local s = ctx.surface()
      local t = e.tick - st.t0
      if st.eei and st.eei.valid then st.eei.energy = BUF end
      feed(s)
      local rep = ctx.remote("fo-ia1d", "report", "player")
      local pq = ctx.remote("fo-piquage", "report", "player")
      local filled = rep and rep.filled or 0
      local link = pq and pq.links and pq.links[1]
      local sink = chest_at(s, SINK.x, SINK.y)
      local sunk = sink and sink.get_item_count(ITEM) or 0
      if t == 1300 then st.s0 = { start = t, sunk0 = sunk, dens = 0, n = 0 } end
      if st.s0 and not st.s0.closed then
        if t % 30 == 0 then st.s0.dens = st.s0.dens + belt_items(s, 70, -10); st.s0.n = st.s0.n + 1 end
        if t - st.s0.start >= WS then st.s0.closed, st.s0.rate = true, (sunk - st.s0.sunk0) end
      end
      -- la fenêtre W s'ouvre quand le répartiteur est posé (piquage), ou à t = 3000 (témoin)
      local ready = (WITH and link and link.done and link.split) or ((not WITH) and t >= 3000)
      if not st.w and ready then
        set_count(s, DOCK.x, DOCK.y, 70)
        st.w = { start = t, filled0 = filled, consumed = 0 }
        st.s1 = { start = t, sunk0 = sunk, dens = 0, n = 0 }
        ctx.log(string.format("[%s] fenetre W ouverte a t=%d : quai ramene a 70, PNJ ont porte %d jusqu'ici", TAG, t, filled))
      end
      if st.w and not st.w.closed then
        st.acc = st.acc + DRAIN / 60
        if st.acc >= 1 then
          local n = math.floor(st.acc)
          st.acc = st.acc - n
          local c = chest_at(s, DOCK.x, DOCK.y)
          if c then st.w.consumed = st.w.consumed + c.remove_item({ name = ITEM, count = n }) end
        end
        local n = count_of(s, DOCK.x, DOCK.y)
        if n >= 0 and (not st.w.min or n < st.w.min) then st.w.min = n end
        if t - st.w.start >= W then
          st.w.closed = true
          st.w.filled = filled - st.w.filled0
          st.w.end_n = count_of(s, DOCK.x, DOCK.y)
          ctx.log(string.format("[%s] fenetre W close a t=%d : quai min %s fin %d, consomme %d, PNJ ont porte %d", TAG, t, tostring(st.w.min), st.w.end_n, st.w.consumed, st.w.filled))
        end
      end
      if st.s1 and not st.s1.closed then
        if t % 30 == 0 then st.s1.dens = st.s1.dens + belt_items(s, 70, -10); st.s1.n = st.s1.n + 1 end
        if t - st.s1.start >= WS then st.s1.closed, st.s1.rate = true, (sunk - st.s1.sunk0) end
      end
      if t % 30 == 0 and t >= st.log_next then
        st.log_next = t + 300
        ctx.log(string.format("[%s] t=%d : piquage %s | quai %d | puits %d | tuile 70 : %d objet(s) | PNJ ont porte %d", TAG, t,
          link and (link.state .. (link.done and " (fini)" or "") .. (link.split and " +repartiteur" or "") .. (link.reason and (" : " .. link.reason) or "")) or "aucun",
          count_of(s, DOCK.x, DOCK.y), sunk, belt_items(s, 70, -10), filled))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local s = ctx.surface()
      local pq = ctx.remote("fo-piquage", "report", "player")
      local w = st.w
      ctx.check(st.s0 ~= nil and st.s0.closed == true and st.s0.n > 0, "fenetre S0 (avant le repartiteur) jouee")
      ctx.check(w ~= nil and w.closed == true, "fenetre W jouee jusqu'au bout")
      if not (w and w.closed) then return end
      local d0 = st.s0.dens / math.max(1, st.s0.n)
      ctx.check(d0 >= 6, "le tapis du banc est plein (densite moyenne " .. string.format("%.1f", d0) .. " objets par tuile)")
      if WITH then
        ctx.check(pq ~= nil and pq.n.demandes == 1, "un seul piquage demande par la regle", pq and tostring(pq.n.demandes))
        ctx.check(pq ~= nil and pq.n.poses >= 1, "le repartiteur est pose", pq and tostring(pq.n.poses))
        local sp
        for _, e in ipairs(s.find_entities_filtered({ area = { { 30, -12 }, { 92, -7 } }, type = "splitter" })) do sp = e end
        ctx.check(sp ~= nil, "un repartiteur existe sur le tapis du banc")
        if sp then
          ctx.check(sp.splitter_output_priority == "left" or sp.splitter_output_priority == "right", "priorite de sortie ecrite d'un cote : " .. tostring(sp.splitter_output_priority))
          ctx.log(string.format("[%s] repartiteur en (%.1f, %.1f) sens %s priorite %s", TAG, sp.position.x, sp.position.y, tostring(sp.direction), tostring(sp.splitter_output_priority)))
        end
        ctx.check(w.min ~= nil and w.min >= LOW, "fenetre W : le quai ne passe jamais sous " .. LOW .. " (min " .. tostring(w.min) .. ")")
        ctx.check(w.filled == 0, "fenetre W : aucun objet porte par un PNJ (" .. tostring(w.filled) .. ")")
        ctx.check(w.consumed >= 0.9 * DRAIN * W / 60 * 0.9, "fenetre W : la consommation a eu lieu (" .. w.consumed .. ")")
        local s1 = st.s1
        ctx.check(s1 ~= nil and s1.closed == true, "fenetre S1 (apres le repartiteur) jouee")
        if s1 and s1.closed then
          local d1 = s1.dens / math.max(1, s1.n)
          ctx.check(d1 >= 0.9 * d0, string.format("l'aval n'est pas affame : densite apres %.1f contre %.1f avant", d1, d0))
          ctx.check(s1.rate >= 0.9 * st.s0.rate, string.format("l'aval n'est pas affame : debit du puits %d apres contre %d avant", s1.rate, st.s0.rate))
        end
        local c = chest_at(s, DOCK.x, DOCK.y)
        if c then
          local inv = c.get_inventory(defines.inventory.chest)
          ctx.check(inv.supports_bar() and inv.get_bar() <= 6, "la barre du coffre d'entree est posee (charge d'un aller-retour)")
        end
      else
        ctx.check(pq == nil or pq.n.demandes == 0, "temoin : aucun piquage demande", pq and tostring(pq.n.demandes))
        ctx.check(w.min ~= nil and w.min < LOW, "temoin : le quai passe sous " .. LOW .. " (min " .. tostring(w.min) .. ")")
        ctx.check(w.filled > 0, "temoin : le PNJ porte (" .. tostring(w.filled) .. ")")
      end
      ctx.log(string.format("[%s] BILAN : quai min %s, PNJ ont porte %s", TAG, tostring(w.min), tostring(w.filled)))
    end,
  }
end
