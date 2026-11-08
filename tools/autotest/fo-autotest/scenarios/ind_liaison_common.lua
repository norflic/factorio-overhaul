--[[
  Banc « ind-liaison » du lot INDUSTRIE I7 (31/10) : la LIAISON DE QUAI (shared/team/liaison.lua, script/team/liaison.lua) contre le
  moteur réel. Chaîne : quai chargé -> prix (Li.worth) -> projet -> tapis -> bras -> coffre ; `carry` éteint ; tapis coupé -> le PNJ reprend.

  Terrain : un champ de 180 x 100 tuiles autour de (50, 0), vidé et refait en herbe. Votre équipe (coffre d'équipe en (0, 0), 8 PNJ, plan
  directeur « seul », fo-war-ia3e coupé : le banc tient le rôle du cerveau) reçoit DEUX modules finis FICTIFS (remote fo-liaison inject) :
    - un module de départ dont le coffre de sortie est en (40, 0) ; le script y verse 3 objets toutes les 200 ticks (0,9 par s) ;
    - un module d'arrivée dont le quai d'entrée est le coffre (70, 0) (objet : plaque de fer, débit nominal 1,0/s) ; le script le
      vide à 0,7 par s pendant les fenêtres de mesure (une machine qui consomme).
  Courant : une interface électrique de l'arène, reliée par une ligne de poteaux le long de y = 4 ; les poteaux de la liaison s'y raccordent.
  Réglages de banc (remote fo-liaison set_param) : relevé toutes les 120 ticks, confirmé en un relevé, sans centrale.

  Variante « tapis » (défaut) : la liaison est demandée par la règle seule ; à sa fin (link.done), le coffre d'arrivée est ramené à 70 et
  vidé à 0,7/s pendant 1 500 ticks (2 700 pour le témoin) (fenêtre 1) : il ne doit jamais passer sous 60 et aucun objet n'est porté par un PNJ (stats.filled) ;
  le tapis est ensuite COUPÉ par script (une tuile détruite), le coffre ramené à 20 : le PNJ reprend (fenêtre 2).
  Variante « temoin » : la règle est éteinte (set_param off), la même fenêtre 1 à tick fixe : le coffre baisse sous 60 et le PNJ porte.
  Lancement : banc.py ... -- 5000 ind-liaison <source> (ou ind-liaison-temoin). Journal : [FO-IND-LIAISON(-TEMOIN)] + [FO-LIAISON] du mod.
]]

local ITEM = "iron-plate"
local CX = 50
local SRC = { x = 40, y = 0 }   -- tuile du coffre de sortie
local DST = { x = 70, y = 0 }   -- tuile du coffre d'entrée (quai)
local BUF = 1e8
local DRAIN = 0.7               -- objets par seconde consommés par le module d'arrivée
local W1 = 1500                 -- fenêtre 1 : le tapis sert le quai
local W2 = 1500                 -- fenêtre 2 : tapis coupé, le PNJ reprend
local T_FIXED = 1500            -- variante témoin : début de la fenêtre 1
local W1_TEMOIN = 2700          -- … plus longue : le quai passe sous 60 en 15 s, puis un PNJ doit marcher 70 tuiles (9 s) avant de déposer
local LOW = 60                  -- Build.QUAI_LOW
local WALL_X = 55               -- variante « mur » (lot TRAVERSEE)

local function stock_chest(chest)
  for _, it in ipairs({
    { "iron-plate", 4000 }, { "copper-plate", 400 }, { "coal", 200 }, { "transport-belt", 300 }, { "inserter", 60 },
    { "small-electric-pole", 40 }, { "medium-electric-pole", 20 }, { "iron-chest", 20 }, { "underground-belt", 20 },
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

--- Ramène le contenu du coffre à `n` objets (retire l'excédent, complète le manque).
local function set_count(s, x, y, n)
  local c = chest_at(s, x, y)
  if not c then return end
  local have = c.get_item_count(ITEM)
  if have > n then c.remove_item({ name = ITEM, count = have - n }) elseif have < n then c.insert({ name = ITEM, count = n - have }) end
end

local function shape(ctx)
  local s = ctx.surface()
  s.request_to_generate_chunks({ CX, 0 }, 5)
  s.force_generate_chunk_requests()
  local area = { { -40, -50 }, { 140, 50 } }
  for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
    if e.valid then e.destroy() end
  end
  local tiles = {}
  for y = -50, 49 do for x = -40, 139 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
  s.set_tiles(tiles, true)
end

local function arena(ctx, st, WALL)
  local s = ctx.surface()
  local eei = s.create_entity({ name = "electric-energy-interface", position = { 36.5, 6.5 }, force = "player" })
  if eei then
    eei.electric_buffer_size = BUF
    eei.power_production = 0
    eei.power_usage = 0
    eei.energy = BUF
    st.eei = eei
  end
  local poles = 0
  for x = 36, 84, 8 do
    if s.create_entity({ name = "medium-electric-pole", position = { x + 0.5, 4.5 }, force = "player" }) then poles = poles + 1 end
  end
  ctx.check(eei ~= nil and poles == 7, "arene alimentee : interface electrique et 7 poteaux", string.format("eei=%s poteaux=%d", tostring(eei ~= nil), poles))
  if WALL then
    -- lot TRAVERSEE : un mur de 1 tuile d'epaisseur en x = 55, de y = -10 a 10, en travers de tout couloir de la liaison (la boite du plan
    -- fait 6 tuiles de marge autour des coffres) : la liaison ne passe que par DESSOUS (paire de souterrains)
    local n = 0
    for y = -10, 10 do
      if s.create_entity({ name = "stone-wall", position = { WALL_X + 0.5, y + 0.5 }, force = "player" }) then n = n + 1 end
    end
    ctx.check(n == 21, "mur de 21 segments pose en x = " .. WALL_X, tostring(n))
    game.forces.player.recipes["underground-belt"].enabled = true
  end
  for _, c in ipairs({ SRC, DST }) do
    local ch = s.create_entity({ name = "iron-chest", position = { c.x + 0.5, c.y + 0.5 }, force = "player" })
    ctx.check(ch ~= nil, string.format("coffre pose en (%d, %d)", c.x, c.y))
  end
end

return function(variant)
  local TAG = "ind-liaison" .. (variant == "temoin" and "-temoin" or (variant == "mur" and "-mur" or ""))
  local WITH = variant ~= "temoin"
  local WALL = variant == "mur"
  return {
    description = "INDUSTRIE I7 : liaison de quai par tapis (" .. variant .. ")",
    base = nil,
    check_tick = 4900,

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
      arena(ctx, st, WALL)
      set_count(s, DST.x, DST.y, 400)
      local p1 = ctx.remote("fo-liaison", "inject", "player", { outs = { { x = SRC.x + 0.5, y = SRC.y + 0.5 } }, names = { arm = "inserter", pole = "small-electric-pole" } })
      local p2 = ctx.remote("fo-liaison", "inject", "player", { quais = { { x = DST.x + 0.5, y = DST.y + 0.5, item = ITEM } }, inflow = { [ITEM] = 1.0 },
        names = { arm = "inserter", pole = "small-electric-pole" } })
      ctx.check(p1 ~= nil and p2 ~= nil, "deux modules finis fictifs injectes", string.format("%s %s", tostring(p1), tostring(p2)))
      ctx.check(ctx.remote("fo-liaison", "set_param", "player", "sans_centrale", true) == true, "sans centrale (banc)")
      ctx.check(ctx.remote("fo-liaison", "set_param", "player", "period", 120) == 120, "releve toutes les 120 ticks")
      ctx.check(ctx.remote("fo-liaison", "set_param", "player", "confirm", 1) == 1, "confirmation en un releve")
      if not WITH then ctx.check(ctx.remote("fo-liaison", "set_param", "player", "off", true) == true, "regle eteinte (temoin)") end
      st.t0 = game.tick
      st.acc, st.consumed, st.produced = 0, 0, 0
      st.w1, st.w2 = nil, nil
      st.log_next = 0
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      if not st.t0 then return end
      local s = ctx.surface()
      local t = e.tick - st.t0
      if st.eei and st.eei.valid then st.eei.energy = BUF end
      -- le module de départ fabrique : 3 objets toutes les 200 ticks
      if t > 0 and t % 200 == 0 then
        local c = chest_at(s, SRC.x, SRC.y)
        if c then st.produced = st.produced + c.insert({ name = ITEM, count = 3 }) end
      end
      local win = st.w2 or st.w1
      -- consommation du module d'arrivée pendant une fenêtre
      if win and not win.closed then
        st.acc = st.acc + DRAIN / 60
        if st.acc >= 1 then
          local n = math.floor(st.acc)
          st.acc = st.acc - n
          local c = chest_at(s, DST.x, DST.y)
          if c then
            local took = c.remove_item({ name = ITEM, count = n })
            win.consumed = win.consumed + took
          end
        end
        local n = count_of(s, DST.x, DST.y)
        if n >= 0 and (not win.min or n < win.min) then win.min = n end
        if win.max == nil or n > win.max then win.max = n end
      end
      if t % 30 ~= 0 then return end
      local rep = ctx.remote("fo-ia1d", "report", "player")
      local lia = ctx.remote("fo-liaison", "report", "player")
      local filled = rep and rep.filled or 0
      local link = lia and lia.links and lia.links[1]
      if t >= st.log_next then
        st.log_next = t + 300
        ctx.log(string.format("[%s] t=%d : liaison %s | quai %d | sortie %d | PNJ ont porte %d | fenetre %s", TAG, t,
          link and (link.state .. (link.done and " (finie)" or "") .. " " .. link.built .. " piece(s)" .. (link.reason and (" : " .. link.reason) or "")) or "aucune",
          count_of(s, DST.x, DST.y), count_of(s, SRC.x, SRC.y), filled, st.w2 and "2" or (st.w1 and "1" or "-")))
      end
      -- fenêtre 1 : à la fin de la liaison (tapis) ou à tick fixe (témoin)
      if not st.w1 and ((WITH and link and link.done) or (not WITH and t >= T_FIXED)) then
        set_count(s, DST.x, DST.y, 70)
        st.w1 = { start = t, filled0 = filled, consumed = 0, produced0 = st.produced, src0 = count_of(s, SRC.x, SRC.y), tick0 = e.tick }
        ctx.log(string.format("[%s] fenetre 1 ouverte a t=%d : quai ramene a 70, PNJ ont porte %d jusqu'ici", TAG, t, filled))
      end
      if st.w1 and not st.w1.closed and t - st.w1.start >= (WITH and W1 or W1_TEMOIN) then
        local w = st.w1
        w.closed = true
        w.filled = filled - w.filled0
        w.end_n = count_of(s, DST.x, DST.y)
        w.belts = s.count_entities_filtered({ area = { { SRC.x, SRC.y - 1 }, { DST.x + 1, DST.y + 2 } }, type = "transport-belt" })
        ctx.log(string.format("[%s] fenetre 1 close a t=%d : quai min %s max %s fin %d, consomme %d, PNJ ont porte %d, tapis %d tuile(s)", TAG, t, tostring(w.min), tostring(w.max),
          w.end_n, w.consumed, w.filled, w.belts))
        if WITH then
          -- coupure : une tuile du milieu du tapis
          local mid = s.find_entities_filtered({ position = { (SRC.x + DST.x) / 2 + 0.5 - (WALL and 5 or 0), SRC.y + 0.5 }, radius = 0.6, type = "transport-belt", limit = 1 })[1]
          st.cut = mid ~= nil
          if mid then mid.destroy() end
          set_count(s, DST.x, DST.y, 20)
          st.w2 = { start = t, filled0 = filled, consumed = 0 }
          ctx.log(string.format("[%s] tapis COUPE a t=%d (tuile detruite : %s), quai ramene a 20", TAG, t, tostring(st.cut)))
        end
      end
      if st.w2 and not st.w2.closed and t - st.w2.start >= W2 then
        local w = st.w2
        w.closed = true
        w.filled = filled - w.filled0
        w.end_n = count_of(s, DST.x, DST.y)
        ctx.log(string.format("[%s] fenetre 2 close a t=%d : quai min %s fin %d, PNJ ont porte %d", TAG, t, tostring(w.min), w.end_n, w.filled))
      end
    end,

    finish = function(ctx)
      local st = ctx.state()
      local s = ctx.surface()
      local lia = ctx.remote("fo-liaison", "report", "player")
      local w1, w2 = st.w1, st.w2
      ctx.check(w1 ~= nil and w1.closed == true, "fenetre 1 jouee jusqu'au bout")
      if not (w1 and w1.closed) then return end
      if WITH then
        ctx.check(lia ~= nil and lia.n.demandes == 1, "une seule liaison demandee par la regle", lia and tostring(lia.n.demandes))
        ctx.check(lia ~= nil and lia.n.finis >= 1, "la liaison est finie (une fois, deux si la reconstruction a refait la tuile coupee)", lia and tostring(lia.n.finis))
        ctx.check(w1.belts >= 20, "le tapis est pose (27 tuiles attendues)", tostring(w1.belts))
        if WALL then
          local ugs = s.count_entities_filtered({ area = { { SRC.x, SRC.y - 8 }, { DST.x + 1, DST.y + 8 } }, type = "underground-belt", force = "player" })
          ctx.check(ugs == 2, "TRAVERSEE : une paire de souterrains pose sous le mur (" .. tostring(ugs) .. ")")
          local walls = s.count_entities_filtered({ area = { { WALL_X, -11 }, { WALL_X + 1, 11 } }, name = "stone-wall" })
          ctx.check(walls == 21, "TRAVERSEE : le mur est intact (" .. tostring(walls) .. ")")
        end
        ctx.check(w1.min ~= nil and w1.min >= LOW, "fenetre 1 : le quai ne passe jamais sous " .. LOW .. " (min " .. tostring(w1.min) .. ")")
        ctx.check(w1.filled == 0, "fenetre 1 : aucun objet porte par un PNJ (" .. tostring(w1.filled) .. ")")
        ctx.check(w1.end_n >= 70 - 5, "fenetre 1 : le quai a ete servi, fin a " .. tostring(w1.end_n) .. " (consomme " .. w1.consumed .. ")")
        ctx.check(w1.consumed >= 0.9 * DRAIN * W1 / 60 * 0.9, "fenetre 1 : la consommation a eu lieu (" .. w1.consumed .. ")")
        local bar_ok = false
        local c = chest_at(s, DST.x, DST.y)
        if c then
          local inv = c.get_inventory(defines.inventory.chest)
          bar_ok = inv.supports_bar() and inv.get_bar() <= 6
          ctx.log(string.format("[%s] barre du coffre d'entree : %s (pile %d)", TAG, tostring(inv.get_bar()), game.item_prototypes[ITEM].stack_size))
        end
        ctx.check(bar_ok, "la barre du coffre d'entree est posee (charge d'un aller-retour)")
        ctx.check(st.cut == true, "le tapis a ete coupe par script")
        ctx.check(w2 ~= nil and w2.closed == true, "fenetre 2 jouee jusqu'au bout")
        if w2 and w2.closed then
          ctx.check(w2.filled > 0, "fenetre 2 : tapis coupe, le PNJ reprend le quai (porte " .. tostring(w2.filled) .. ")")
          ctx.check(lia ~= nil and lia.n.coupees >= 1, "la coupure est vue : le projet de la liaison rouvert, ecrit \"coupee\" au journal (" .. tostring(lia and lia.n.coupees) .. ")")
          ctx.check(w2.end_n >= LOW, "fenetre 2 : le quai est reparti au-dessus de " .. LOW .. " (fin " .. tostring(w2.end_n) .. ")")
        end
      else
        ctx.check(lia ~= nil and lia.n.demandes == 0, "temoin : aucune liaison demandee", lia and tostring(lia.n.demandes))
        ctx.check(w1.min ~= nil and w1.min < LOW, "temoin, fenetre 1 : le quai passe sous " .. LOW .. " (min " .. tostring(w1.min) .. ")")
        ctx.check(w1.filled > 0, "temoin, fenetre 1 : le PNJ porte (" .. tostring(w1.filled) .. ")")
      end
      ctx.log(string.format("[%s] BILAN : fenetre 1 : min %s, PNJ ont porte %s ; fenetre 2 : PNJ ont porte %s", TAG, tostring(w1.min), tostring(w1.filled), w2 and tostring(w2.filled) or "-"))
    end,
  }
end
