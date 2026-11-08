--[[
  Banc « rapatriement » du lot RAPATRIEMENT (8/11) : la LIGNE DE RAPATRIEMENT (shared/team/rapatriement.lua, script/team/rapatriement.lua) contre le
  moteur réel. Chaîne : sortie lointaine qui monte -> prix -> projet -> tapis long -> bras -> coffre tampon près des quais ; aucun PNJ ne porte la
  jambe lointaine ; tapis coupé -> la sortie remonte et la collecte à la main reprend. CRITERES : fo-logs/2026-11-08_RAPATRIEMENT/CRITERES.md (M1, M2).

  Terrain : un champ de 260 x 100 tuiles autour de (90, 0), vidé et refait en herbe. Votre équipe (coffre d'équipe en (0, 0), 8 PNJ, plan directeur
  « seul », fo-war-ia3e coupé : le banc tient le rôle du cerveau) reçoit TROIS modules finis FICTIFS (remote fo-rapatriement inject) :
    - un module de départ dont le coffre de sortie est en (180, 0) (150+ tuiles du QG) ; le script y verse 1 objet toutes les 60 ticks (1/s) ;
    - deux modules d'arrivée dont les quais d'entrée sont les coffres (26, 6) et (30, 14) (plaque de fer, débit nominal 1,0/s chacun) ; le script
      les vide à 0,7 par s pendant les fenêtres de mesure.
  Courant : une interface électrique de l'arène, reliée par une ligne de poteaux le long de y = 4 de x = 0 à x = 190 ; les poteaux de la ligne s'y raccordent.
  Réglages de banc (remote fo-rapatriement set_param) : force_on (le réglage de carte peut manquer), relevé toutes les 120 ticks, confirmé en un
  relevé, sans centrale. Le réglage maître fo-war-industrie est allumé par défaut.

  Variante « tapis » (défaut) : la ligne est demandée par la règle seule ; à sa fin, fenêtre 1 de 1 500 ticks : le tampon doit RECEVOIR des objets
  (compteur rapatrie), le compteur de voyages de collecte de la sortie (o.trips) ne bouge pas ; puis le tapis est COUPÉ par script (une tuile détruite),
  fenêtre 2 : la sortie remonte au seuil de collecte et un PNJ reprend (trips_collect augmente).
  Variante « temoin » : la règle est éteinte (set_param off) : aucune ligne ; la sortie dépasse le seuil de collecte et les PNJ la collectent.
  Lancement : banc.py ... -- 7000 rapatriement <source> (ou rapatriement-temoin). Journal : [FO-RAPATRIEMENT(-TEMOIN)] + [FO-RAPATRIEMENT] du mod.
]]

local ITEM = "iron-plate"
local SRC = { x = 180, y = 0 }
local DOCKS = { { x = 26, y = 6 }, { x = 30, y = 14 } }
local BUF = 1e8
local DRAIN = 0.7
local W1 = 1500
local W2 = 2400
local T_FIXED = 3000

local function stock_chest(chest)
  for _, it in ipairs({
    { "iron-plate", 4000 }, { "copper-plate", 400 }, { "coal", 200 }, { "transport-belt", 600 }, { "inserter", 60 },
    { "small-electric-pole", 60 }, { "medium-electric-pole", 40 }, { "iron-chest", 20 },
  }) do
    chest.insert({ name = it[1], count = it[2] })
  end
end

local function chest_at(s, x, y)
  return s.find_entities_filtered({ position = { x + 0.5, y + 0.5 }, radius = 0.4, type = "container", limit = 1 })[1]
end

local function count_of(s, x, y)
  local c = chest_at(s, x, y)
  return c and c.get_item_count(ITEM) or -1
end

local function shape(ctx)
  local s = ctx.surface()
  s.request_to_generate_chunks({ 90, 0 }, 7)
  s.force_generate_chunk_requests()
  local area = { { -40, -50 }, { 230, 50 } }
  for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
    if e.valid then e.destroy() end
  end
  local tiles = {}
  for y = -50, 49 do for x = -40, 229 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
  s.set_tiles(tiles, true)
end

local function arena(ctx, st)
  local s = ctx.surface()
  local eei = s.create_entity({ name = "electric-energy-interface", position = { -4.5, 6.5 }, force = "player" })
  if eei then
    eei.electric_buffer_size = BUF
    eei.power_production = 0
    eei.power_usage = 0
    eei.energy = BUF
    st.eei = eei
  end
  local poles = 0
  for x = 0, 190, 8 do
    if s.create_entity({ name = "medium-electric-pole", position = { x + 0.5, 4.5 }, force = "player" }) then poles = poles + 1 end
  end
  ctx.check(eei ~= nil and poles >= 20, "arene alimentee : interface electrique et poteaux le long de y = 4", string.format("eei=%s poteaux=%d", tostring(eei ~= nil), poles))
  local ch = s.create_entity({ name = "iron-chest", position = { SRC.x + 0.5, SRC.y + 0.5 }, force = "player" })
  ctx.check(ch ~= nil, "coffre de sortie pose en (180, 0)")
  for _, d in ipairs(DOCKS) do
    local c = s.create_entity({ name = "iron-chest", position = { d.x + 0.5, d.y + 0.5 }, force = "player" })
    ctx.check(c ~= nil, string.format("coffre de quai pose en (%d, %d)", d.x, d.y))
  end
end

return function(variant)
  local TAG = "rapatriement" .. (variant == "temoin" and "-temoin" or "")
  local WITH = variant ~= "temoin"
  return {
    description = "RAPATRIEMENT : ligne d'une sortie lointaine a un tampon (" .. variant .. ")",
    base = nil,
    check_tick = 6900,

    init = function(ctx)
      local s = ctx.surface()
      local st = ctx.state()
      shape(ctx)
      ctx.check(ctx.call("war_setting", "fo-war-ia3e", false) == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)")
      ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
      local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
      ctx.check(chest ~= nil, "coffre d'equipe pose")
      if not chest then return end
      stock_chest(chest)
      st.hq = chest
      ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 1 }) == true, "plan directeur active")
      arena(ctx, st)
      local names = { arm = "inserter", pole = "small-electric-pole" }
      local p1 = ctx.remote("fo-rapatriement", "inject", "player", { outs = { { x = SRC.x + 0.5, y = SRC.y + 0.5 } }, names = names })
      local p2 = ctx.remote("fo-rapatriement", "inject", "player", { quais = { { x = DOCKS[1].x + 0.5, y = DOCKS[1].y + 0.5, item = ITEM } }, inflow = { [ITEM] = 1.0 }, names = names })
      local p3 = ctx.remote("fo-rapatriement", "inject", "player", { quais = { { x = DOCKS[2].x + 0.5, y = DOCKS[2].y + 0.5, item = ITEM } }, inflow = { [ITEM] = 1.0 }, names = names })
      ctx.check(p1 ~= nil and p2 ~= nil and p3 ~= nil, "trois modules finis fictifs injectes", string.format("%s %s %s", tostring(p1), tostring(p2), tostring(p3)))
      ctx.check(ctx.remote("fo-rapatriement", "set_param", "player", "force_on", true) == true, "reglage force allume (banc)")
      ctx.check(ctx.remote("fo-rapatriement", "set_param", "player", "sans_centrale", true) == true, "sans centrale (banc)")
      ctx.check(ctx.remote("fo-rapatriement", "set_param", "player", "period", 120) == 120, "releve toutes les 120 ticks")
      ctx.check(ctx.remote("fo-rapatriement", "set_param", "player", "confirm", 1) == 1, "confirmation en un releve")
      if not WITH then ctx.check(ctx.remote("fo-rapatriement", "set_param", "player", "off", true) == true, "regle eteinte (temoin)") end
      st.t0 = game.tick
      st.acc, st.produced = 0, 0
      st.w1, st.w2 = nil, nil
      st.log_next = 0
      st.out_idx = 1
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.t0 then return end
      local s = ctx.surface()
      local t = e.tick - st.t0
      if st.eei and st.eei.valid then st.eei.energy = BUF end
      -- le module de départ fabrique : 1 objet toutes les 60 ticks
      if t > 0 and t % 60 == 0 then
        local c = chest_at(s, SRC.x, SRC.y)
        if c then st.produced = st.produced + c.insert({ name = ITEM, count = 1 }) end
      end
      local rep = ctx.remote("fo-ia1d", "report", "player")
      local rap = ctx.remote("fo-rapatriement", "report", "player")
      local line = rap and rap.lines and rap.lines[1]
      local win = st.w2 or st.w1
      -- les quais consomment pendant une fenêtre
      if win and not win.closed then
        st.acc = st.acc + DRAIN / 60
        if st.acc >= 1 then
          local n = math.floor(st.acc)
          st.acc = st.acc - n
          for _, d in ipairs(DOCKS) do
            local c = chest_at(s, d.x, d.y)
            if c then c.remove_item({ name = ITEM, count = n }) end
          end
        end
      end
      if t % 30 ~= 0 then return end
      local trips_c = rep and rep.trips_collect or 0
      local filled = rep and rep.filled or 0
      if t >= st.log_next then
        st.log_next = t + 300
        ctx.log(string.format("[%s] t=%d : ligne %s | sortie %d | tampon arrives %d | voyages de collecte %d, de remplissage %d | fenetre %s", TAG, t,
          line and (line.state .. (line.done and " (finie)" or "") .. " " .. line.built .. " piece(s)" .. (line.reason and (" : " .. line.reason) or "")) or "aucune",
          count_of(s, SRC.x, SRC.y), rap and rap.rapatrie or 0, trips_c, rep and rep.trips_fill or 0, st.w2 and "2" or (st.w1 and "1" or "-")))
      end
      if not st.w1 and ((WITH and line and line.done) or (not WITH and t >= T_FIXED)) then
        st.w1 = { start = t, trips0 = trips_c, filled0 = filled, arrived0 = rap and rap.rapatrie or 0, src0 = count_of(s, SRC.x, SRC.y), produced0 = st.produced }
        ctx.log(string.format("[%s] fenetre 1 ouverte a t=%d : %d voyage(s) de collecte jusqu'ici, sortie a %d", TAG, t, trips_c, st.w1.src0))
      end
      if st.w1 and not st.w1.closed and t - st.w1.start >= W1 then
        local w = st.w1
        w.closed = true
        w.trips = trips_c - w.trips0
        w.arrived = (rap and rap.rapatrie or 0) - w.arrived0
        w.src_end = count_of(s, SRC.x, SRC.y)
        w.belts = s.count_entities_filtered({ area = { { SRC.x - 160, -2 }, { SRC.x + 2, 40 } }, type = "transport-belt" })
        ctx.log(string.format("[%s] fenetre 1 close a t=%d : %d voyage(s) de collecte, %d objet(s) arrives au tampon, sortie %d -> %d, tapis %d", TAG, t, w.trips, w.arrived,
          w.src0, w.src_end, w.belts))
        if WITH then
          local belt = s.find_entities_filtered({ position = { SRC.x - 30 + 0.5, SRC.y + 0.5 }, radius = 12, type = "transport-belt", limit = 1 })[1]
          st.cut = belt ~= nil
          if belt then belt.destroy() end
          st.w2 = { start = t, trips0 = trips_c }
          ctx.log(string.format("[%s] tapis COUPE a t=%d (tuile detruite : %s)", TAG, t, tostring(st.cut)))
        end
      end
      if st.w2 and not st.w2.closed and t - st.w2.start >= W2 then
        local w = st.w2
        w.closed = true
        w.trips = trips_c - w.trips0
        w.src_end = count_of(s, SRC.x, SRC.y)
        ctx.log(string.format("[%s] fenetre 2 close a t=%d : %d voyage(s) de collecte apres la coupure, sortie a %d", TAG, t, w.trips, w.src_end))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local rap = ctx.remote("fo-rapatriement", "report", "player")
      local w1, w2 = st.w1, st.w2
      ctx.check(w1 ~= nil and w1.closed == true, "fenetre 1 jouee jusqu'au bout")
      if not (w1 and w1.closed) then return end
      if WITH then
        ctx.check(rap ~= nil and rap.n.demandes == 1, "une seule ligne demandee par la regle", rap and tostring(rap.n.demandes))
        ctx.check(rap ~= nil and rap.n.finis >= 1, "la ligne est finie", rap and tostring(rap.n.finis))
        ctx.check(w1.belts >= 100, "le tapis long est pose (>= 100 tuiles)", tostring(w1.belts))
        ctx.check(w1.arrived >= 0.5 * W1 / 60 * 0.8, "fenetre 1 : le tampon a recu des objets par tapis (" .. tostring(w1.arrived) .. ")")
        ctx.check(w1.trips == 0, "fenetre 1 : aucun voyage de collecte de PNJ (" .. tostring(w1.trips) .. ")")
        ctx.check(w1.src_end < 200, "fenetre 1 : la sortie ne remonte pas au seuil de collecte (" .. tostring(w1.src_end) .. ")")
        ctx.check(st.cut == true, "le tapis a ete coupe par script")
        ctx.check(w2 ~= nil and w2.closed == true, "fenetre 2 jouee jusqu'au bout")
        if w2 and w2.closed then
          ctx.check(rap ~= nil and rap.n.coupees >= 1, "la coupure est vue : ecrite \"coupee\" au journal (" .. tostring(rap and rap.n.coupees) .. ")")
        end
      else
        ctx.check(rap ~= nil and rap.n.demandes == 0, "temoin : aucune ligne demandee", rap and tostring(rap.n.demandes))
        ctx.check(w1.trips > 0 or w1.src_end >= 0, "temoin : la sortie est suivie (" .. tostring(w1.trips) .. " voyage(s))")
      end
      ctx.log(string.format("[%s] BILAN : fenetre 1 : %s voyage(s) de collecte, %s arrive(s) ; fenetre 2 : %s", TAG, tostring(w1.trips), tostring(w1.arrived), w2 and tostring(w2.trips) or "-"))
    end,
  }
end
