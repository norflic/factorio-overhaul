-- Scénario greffé du lot A2 (24/10) : la mitrailleuse V3-E EN JEU, 30 niveaux, chacun orienté N, E, S, O.
--   & "<racine>\fo-autotest.bat" nopause 1000 gun-rose "<source>"      (contrôles, sans images)
--   & "<racine>\fo-captures.bat" gun-rose "<source>"                    (captures)
--
-- ROSE : une rangée par niveau (âge e : niveau impair 2e-1 puis niveau pair 2e, 10 tuiles plus bas ; âge 1 : niveau 1 =
-- mitrailleuse vanilla, niveau 2) ; dans chaque rangée, la mitrailleuse VANILLA (orientée N) puis le niveau orienté
-- N, E, S, O. Orientation écrite (`turret.orientation`, E70 / F122 : tient sans cible), munitions chargées, aucun ennemi
-- à portée. Contrôles : prototypes, poses, orientation relue au tick 60 et au tick de contrôle, boîte d'affichage
-- (drawing_box) plus grande que la boîte de sélection, reste et explosion agrandis (copies déclarées « -restes »,
-- « -explosion ») à partir du niveau 7.
-- TIR (E68) : niveaux 1 (vanilla), 13 (âge 7) et 29 (âge 15), chacun face à un ver géant ENNEMI au N, à l'E, au S et à
-- l'O (12 sites à 80 tuiles d'écart ; cessez-le-feu de l'ennemi ; ver recréé s'il meurt). Contrôle : chaque tourelle
-- a tiré (munitions consommées), et son orientation au contrôle est celle de sa cible (à 1/64 près).
-- Captures : par âge, zoom 1, jour et nuit (rangées impaire et paire) ; zoom 2 des âges 3, 9 et 15 (jour ; nuit pour 15) ;
-- tir : niveaux 1 et 29, 4 directions, zoom 2, deux instants.

local X0, Y0 = 3000, -2400
local DX, DROW, DAGE = 9, 10, 22
local DIRS = { { "N", 0 }, { "E", 0.25 }, { "S", 0.5 }, { "O", 0.75 } }
local TIR_NIV = { 1, 13, 29 }
local TX0, TY0, TPAS, TDIST = 3200, -2400, 80, 11
local T_ECRIT, CHECK = 30, 900

local function nom(LV, n)
  if n == 1 then return "gun-turret" end
  return LV and LV.name(LV.by_key.gun, n) or ("fo-lvl-gun-" .. n)
end

local function ecart(a, b)
  local d = math.abs(a - b) % 1
  return math.min(d, 1 - d)
end

local function ori(e)
  local ok, v = pcall(function() return e.orientation end)
  return ok and v or nil
end

local function pos_rose(n)
  local e = math.floor((n + 1) / 2)
  local y = Y0 + (e - 1) * DAGE + ((n % 2 == 0) and DROW or 0)
  return y, e
end

return {
  description = "A2 : mitrailleuse V3-E en jeu, 30 niveaux x 4 directions (rose), tir N/E/S/O (E68)",
  base = nil,
  check_tick = CHECK,
  shots_delay = 300,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.pret = false
    local manque = {}
    for n = 2, 30 do
      if not game.entity_prototypes["fo-lvl-gun-" .. n] then manque[#manque + 1] = n end
    end
    ctx.check(#manque == 0, "prototypes fo-lvl-gun-2 a 30 presents", #manque == 0 and "29" or table.concat(manque, ","))
    game.map_settings.enemy_expansion.enabled = false
    game.forces.player.set_cease_fire("enemy", false)
    game.forces.enemy.set_cease_fire("player", true)
    ctx.prepare_area(X0 - 8, Y0 - 8, X0 + 5 * DX + 8, Y0 + 15 * DAGE + 4, "concrete")
    ctx.prepare_area(TX0 - 20, TY0 - 20, TX0 + 3 * TPAS + 20, TY0 + 4 * TPAS + 20, "grass-1")
    for _, e in ipairs(s.find_entities_filtered({ force = "enemy",
        area = { { X0 - 120, Y0 - 120 }, { TX0 + 3 * TPAS + 120, TY0 + 4 * TPAS + 120 } } })) do
      e.destroy()
    end
    -- ROSE
    st.rose = {}
    local poses, voulues = 0, 0
    for n = 1, 30 do
      local y = pos_rose(n)
      local van = s.create_entity({ name = "gun-turret", position = { X0, y }, force = "player" })
      voulues = voulues + 1
      if van then
        poses = poses + 1
        van.insert({ name = "firearm-magazine", count = 10 })
        st.rose[#st.rose + 1] = { n = 1, dir = "N", o = 0, t = van, x = X0, y = y, vanille = true }
      end
      for k, d in ipairs(DIRS) do
        local x = X0 + k * DX
        voulues = voulues + 1
        local t = s.create_entity({ name = nom(nil, n), position = { x, y }, force = "player" })
        if t then
          poses = poses + 1
          t.insert({ name = "firearm-magazine", count = 10 })
          st.rose[#st.rose + 1] = { n = n, dir = d[1], o = d[2], t = t, x = x, y = y }
        end
      end
    end
    ctx.check(poses == voulues, "rose : tourelles posees", poses .. " / " .. voulues)
    -- TIR
    st.tir = {}
    local i = 0
    for _, n in ipairs(TIR_NIV) do
      for k, d in ipairs(DIRS) do
        local x, y = TX0 + i % 3 * TPAS, TY0 + math.floor(i / 3) * TPAS
        i = i + 1
        local t = s.create_entity({ name = nom(nil, n), position = { x, y }, force = "player" })
        if t then t.insert({ name = "firearm-magazine", count = 200 }) end
        local dx = ({ N = 0, E = TDIST, S = 0, O = -TDIST })[d[1]]
        local dy = ({ N = -TDIST, E = 0, S = TDIST, O = 0 })[d[1]]
        st.tir[#st.tir + 1] = { n = n, dir = d[1], o = d[2], t = t, x = x, y = y, cx = x + dx, cy = y + dy,
          recrees = 0 }
      end
    end
    local ok_tir = 0
    for _, c in ipairs(st.tir) do if c.t then ok_tir = ok_tir + 1 end end
    ctx.check(ok_tir == #st.tir, "tir : tourelles posees", ok_tir .. " / " .. #st.tir)
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local s = ctx.surface()
    local t = e.tick
    if t == T_ECRIT then
      local ecrites = 0
      for _, c in ipairs(st.rose) do
        if c.t and c.t.valid then
          local ok = pcall(function() c.t.orientation = c.o end)
          if ok then ecrites = ecrites + 1 end
        end
      end
      st.ecrites = ecrites
      for _, c in ipairs(st.tir) do
        if c.t and c.t.valid then
          c.mun0 = c.t.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine")
        end
      end
    end
    if t >= T_ECRIT then
      for _, c in ipairs(st.tir) do
        if not (c.cible and c.cible.valid) then
          c.cible = s.create_entity({ name = "behemoth-worm-turret", position = { c.cx, c.cy }, force = "enemy" })
          if t > T_ECRIT then c.recrees = c.recrees + 1 end
        end
      end
    end
    if t == T_ECRIT + 30 then
      local tient = 0
      for _, c in ipairs(st.rose) do
        local o = c.t and c.t.valid and ori(c.t)
        if o and ecart(o, c.o) < 1 / 256 then tient = tient + 1 end
      end
      st.tient_60 = tient
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    ctx.check(st.ecrites == #st.rose, "rose : orientation ecrite (E70)", tostring(st.ecrites) .. " / " .. #st.rose)
    ctx.check(st.tient_60 == #st.rose, "rose : orientation tenue 30 ticks apres l'ecriture", tostring(st.tient_60) .. " / " .. #st.rose)
    local tient, faux = 0, {}
    for _, c in ipairs(st.rose) do
      local o = c.t and c.t.valid and ori(c.t)
      if o and ecart(o, c.o) < 1 / 256 then
        tient = tient + 1
      elseif #faux < 8 then
        faux[#faux + 1] = c.n .. c.dir .. "=" .. tostring(o)
      end
    end
    ctx.check(tient == #st.rose, "rose : orientation tenue au tick " .. CHECK .. " (sans cible)", tient .. " / " .. #st.rose ..
      (#faux > 0 and (" ; " .. table.concat(faux, " ")) or ""))
    -- prototypes : boîte d'affichage, reste et explosion
    local box_ok, restes_ok, lignes = 0, 0, {}
    for n = 2, 30 do
      local p = game.entity_prototypes["fo-lvl-gun-" .. n]
      if p then
        local db, sb = p.drawing_box, p.selection_box
        local h = db and (db.right_bottom.y - db.left_top.y) or 0
        local hs = sb.right_bottom.y - sb.left_top.y
        -- niveau 2 : visuel vanilla (tête vanilla sur la pièce e01), sans drawing_box, comme la vanilla
        if n == 2 then
          if not db or h == 0 then box_ok = box_ok + 1 end
        elseif db and h > hs then
          box_ok = box_ok + 1
        end
        local cn = {}
        for k in pairs(p.corpses or {}) do cn[#cn + 1] = k end
        table.sort(cn)
        local foot = sb.right_bottom.x - sb.left_top.x
        local want = foot > 2.01
        local has = cn[1] and cn[1]:find("%-restes$") ~= nil
        if has == want then restes_ok = restes_ok + 1 end
        lignes[#lignes + 1] = string.format("%d:%.1fx%.1f/%s", n, db and (db.right_bottom.x - db.left_top.x) or 0, h,
          cn[1] or "-")
      end
    end
    ctx.log("prototypes (niveau : boite d'affichage l x h / reste) : " .. table.concat(lignes, " "))
    ctx.check(box_ok == 29, "drawing_box plus haute que la selection aux niveaux 3 a 30 (tete au-dessus du socle) ; "
      .. "niveau 2 sans drawing_box (vanilla)", box_ok .. " / 29")
    ctx.check(restes_ok == 29, "reste agrandi (copie declaree) des que l'emprise depasse 2x2, vanilla sinon", restes_ok .. " / 29")
    -- tir
    local tire, vise, l2 = 0, 0, {}
    for _, c in ipairs(st.tir) do
      local mun = c.t and c.t.valid and c.t.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine")
      local conso = (c.mun0 and mun) and (c.mun0 - mun) or -1
      local o = c.t and c.t.valid and ori(c.t)
      if conso > 0 then tire = tire + 1 end
      if o and ecart(o, c.o) < 1 / 64 then vise = vise + 1 end
      l2[#l2 + 1] = string.format("%d%s:conso=%d,o=%s,recrees=%d", c.n, c.dir, conso, o and string.format("%.4f", o) or "nil",
        c.recrees)
    end
    ctx.log("tir (niveau direction : chargeurs consommes, orientation, cibles recreees) : " .. table.concat(l2, " "))
    ctx.check(tire == #st.tir, "tir : chaque tourelle a tire (chargeurs consommes)", tire .. " / " .. #st.tir)
    ctx.check(vise == #st.tir, "tir : orientation = direction de la cible (a 1/64 pres)", vise .. " / " .. #st.tir)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if not st.pret then return end
    local cx = X0 + 2.5 * DX
    for e = 1, 15 do
      local y = Y0 + (e - 1) * DAGE + DROW / 2
      add(string.format("rose-age%02d-z1-jour", e), cx, y, 1, 0)
      add(string.format("rose-age%02d-z1-nuit", e), cx, y, 1, 0.5)
    end
    for _, e in ipairs({ 3, 9, 15 }) do
      local y = Y0 + (e - 1) * DAGE - 1
      add(string.format("rose-age%02d-z2-van-N-E", e), X0 + DX, y, 2, 0)
      add(string.format("rose-age%02d-z2-S-O", e), X0 + 3.5 * DX, y, 2, 0)
      if e == 15 then
        add(string.format("rose-age%02d-z2-van-N-E-nuit", e), X0 + DX, y, 2, 0.5)
        add(string.format("rose-age%02d-z2-S-O-nuit", e), X0 + 3.5 * DX, y, 2, 0.5)
      end
    end
    for _, c in ipairs(st.tir) do
      if c.n == 1 or c.n == 29 then
        for k = 1, 2 do
          add(string.format("tir-niv%02d-%s-%d", c.n, c.dir, k), c.x, c.y - 1, 2, 0, { res = { 640, 640 } })
        end
      end
    end
  end,
}
