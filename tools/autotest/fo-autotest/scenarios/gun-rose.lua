-- Scénario greffé du lot A2 (24/10), étendu au lot A3-jeu (64 directions) : la mitrailleuse V3-E EN JEU, 30 niveaux.
--   & "<racine>\fo-autotest.bat" nopause 1000 gun-rose "<source>"      (contrôles, sans images)
--   & "<racine>\fo-captures.bat" gun-rose "<source>"                    (captures ; avec FO_AUDIO=1, interdit n° 7)
--   py -3.9 tools/autotest/gun_rose_images.py "<fo-shots>" --feuilles "<source>/graphics/levels/gun"
--                                                                       (image montrée contre image attendue)
--
-- ROSE (lot A3-jeu) : par niveau, une grille de 5 × 4 tourelles orientées dans 20 DIRECTIONS : les 16 multiples de 4
-- (d00, d04, …, d60) et les 4 diagonales VUES en jeu (d06, d26, d38, d58 : F121, E70). L'orientation écrite pour la
-- direction k est orientation_image(k) (même formule que feuilles.py) : le centre de la plage d'orientations pour
-- laquelle le moteur montre l'image k d'une tête à 64 directions avec apply_projection (tan 2πo = tan θk / 0,7071 ;
-- E70 : 1/8 -> 6, 3/8 -> 26, 5/8 -> 38, 7/8 -> 58). Un âge resté à 4 directions montre l'image la plus proche (N, E, S,
-- O ; à 45° pile, d08, d24, d40, d56 : l'une des deux, non contrôlé). Âge e : niveau impair 2e-1 à gauche, niveau
-- pair 2e à droite (54 tuiles plus loin) ; âge 1 : niveau 1 = mitrailleuse vanilla, niveau 2 ; une mitrailleuse
-- VANILLA orientée N à gauche de chaque âge. Orientation écrite au tick 30 (`turret.orientation`, E70 / F122 : tient
-- sans cible), munitions chargées, aucun ennemi à portée. Contrôles : prototypes, 20 directions par niveau dont les 4
-- diagonales, orientation relue au tick 60 et au tick de contrôle, boîte d'affichage (drawing_box) plus grande que la
-- boîte de sélection, reste et explosion agrandis (copies déclarées « -restes », « -explosion ») à partir du niveau 7.
-- L'IMAGE montrée ne se lit pas par script : gun_rose_images.py la compare, sur les captures zoom 2 de jour (sans mode
-- Alt ni anticrénelage), à chaque cellule de la feuille (pose de la table fo-shots/gun-rose-poses.tsv écrite ici).
-- TIR (E68, inchangé) : un niveau par âge (niveau impair 2e-1 ; âge 1 : niveau 1, vanilla), chacun face à un ver géant
-- ENNEMI au N, à l'E, au S et à l'O (60 sites à 80 tuiles d'écart ; ver aligné sur le centre RÉEL de la tourelle ;
-- cessez-le-feu de l'ennemi ; ver recréé s'il meurt). Contrôles : chaque tourelle a tiré (munitions consommées), son
-- orientation au contrôle est celle de sa cible (à 1/64 près) ; ÉCLAT : position de l'entité explosion-gunshot
-- (source_effects de la munition) relevée par le moteur = projectile_center + projectile_creation_distance × (ux, K × uy)
-- du prototype, à 1/32 de tuile près, K = 0,7071 (règle mesurée, feuilles.py).
-- Captures : par âge, grille du niveau impair à zoom 1 (jour, nuit) et à zoom 2 (jour sans mode Alt ni anticrénelage :
-- contrôle des images ; nuit) ; niveaux PAIRS 10, 18, 30 à zoom 2 (jour, nuit) ; tir : niveaux 1, 3, 23 (âge 12),
-- 25 (âge 13) et 29, 4 directions, zoom 2, deux instants.

local X0, Y0 = 3000, -2400
local DX, DAGE, DPAIR, NCOL = 9, 40, 54, 5
local KS = { 0, 4, 6, 8, 12, 16, 20, 24, 26, 28, 32, 36, 38, 40, 44, 48, 52, 56, 58, 60 }
local DIAG = { 6, 26, 38, 58 }
local PROJ = math.sqrt(0.5)
-- tir (E68) : un niveau par âge (niveau impair 2e-1 ; âge 1 : niveau 1, vanilla) ; 60 sites en grille de 8 colonnes
local DIRS = { { "N", 0 }, { "E", 0.25 }, { "S", 0.5 }, { "O", 0.75 } }
local TIR_NIV = { 1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29 }
local TX0, TY0, TPAS, TDIST, TCOL = 3200, -2400, 80, 11, 8
local MES_MAX = 4
local K_PROJ = 0.7071 -- même valeur que tools/render/pieces/levels/gun_e/feuilles.py (E68)
local T_ECRIT, CHECK = 30, 900
local RES_Z1 = { 1600, 1280 }
local RES_Z2 = { 3072, 2560 }

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

--- Orientation pour laquelle le moteur montre l'image k (64 directions, apply_projection) : feuilles.orientation_image.
local function orientation_image(k)
  if k % 16 == 0 then return k / 64 end
  local th = 2 * math.pi * k / 64
  return (math.atan2(math.sin(th), PROJ * math.cos(th)) / (2 * math.pi)) % 1
end

--- Coin haut-gauche (position de la 1re tourelle) de la grille du niveau n.
local function grille(n)
  local e = math.floor((n + 1) / 2)
  local x = X0 + ((n % 2 == 0) and DPAIR or 0)
  return x, Y0 + (e - 1) * DAGE, e
end

local function centre_grille(n)
  local x, y = grille(n)
  return x + (NCOL - 1) * DX / 2, y + (#KS / NCOL - 1) * DX / 2 - 1
end

return {
  description = "A2/A3-jeu : mitrailleuse V3-E en jeu, 30 niveaux x 20 directions (rose, 64 directions), tir N/E/S/O (E68)",
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
    ctx.prepare_area(X0 - 20, Y0 - 10, X0 + DPAIR + NCOL * DX + 6, Y0 + 15 * DAGE + 4, "concrete")
    local nsites = #TIR_NIV * #DIRS
    local nrows = math.ceil(nsites / TCOL)
    for k = 0, nsites - 1 do
      local x, y = TX0 + k % TCOL * TPAS, TY0 + math.floor(k / TCOL) * TPAS
      ctx.prepare_area(x - 20, y - 20, x + 21, y + 21, "grass-1")
    end
    for _, e in ipairs(s.find_entities_filtered({ force = "enemy",
        area = { { X0 - 120, Y0 - 120 }, { TX0 + (TCOL - 1) * TPAS + 120, TY0 + (nrows - 1) * TPAS + 120 } } })) do
      e.destroy()
    end
    -- ROSE
    st.rose = {}
    local poses, voulues = 0, 0
    for e = 1, 15 do
      local _, y = grille(2 * e - 1)
      local van = s.create_entity({ name = "gun-turret", position = { X0 - 12, y }, force = "player" })
      voulues = voulues + 1
      if van then
        poses = poses + 1
        van.insert({ name = "firearm-magazine", count = 10 })
        st.rose[#st.rose + 1] = { n = 1, k = 0, o = 0, t = van, vanille = true }
      end
    end
    for n = 1, 30 do
      local gx, gy = grille(n)
      for i, k in ipairs(KS) do
        local x = gx + ((i - 1) % NCOL) * DX
        local y = gy + math.floor((i - 1) / NCOL) * DX
        voulues = voulues + 1
        local t = s.create_entity({ name = nom(nil, n), position = { x, y }, force = "player" })
        if t then
          poses = poses + 1
          t.insert({ name = "firearm-magazine", count = 10 })
          st.rose[#st.rose + 1] = { n = n, k = k, o = orientation_image(k), t = t }
        end
      end
    end
    ctx.check(poses == voulues, "rose : tourelles posees", poses .. " / " .. voulues)
    -- 20 directions par niveau, dont les 4 diagonales vues en jeu (F121)
    local par, diag_ok = {}, 0
    for _, c in ipairs(st.rose) do
      if not c.vanille then
        par[c.n] = par[c.n] or {}
        par[c.n][c.k] = true
      end
    end
    local niv_ok = 0
    for n = 1, 30 do
      local nb = 0
      for _ in pairs(par[n] or {}) do nb = nb + 1 end
      local d = 0
      for _, k in ipairs(DIAG) do if par[n] and par[n][k] then d = d + 1 end end
      if nb >= 16 and d == #DIAG then niv_ok = niv_ok + 1 end
      if d == #DIAG then diag_ok = diag_ok + 1 end
    end
    ctx.check(niv_ok == 30, "rose : au moins 16 directions par niveau (" .. #KS .. ") dont d06, d26, d38, d58",
      niv_ok .. " / 30 niveaux ; diagonales " .. diag_ok .. " / 30")
    -- TIR
    st.tir = {}
    local i = 0
    for _, n in ipairs(TIR_NIV) do
      for _, d in ipairs(DIRS) do
        local x, y = TX0 + i % TCOL * TPAS, TY0 + math.floor(i / TCOL) * TPAS
        i = i + 1
        local t = s.create_entity({ name = nom(nil, n), position = { x, y }, force = "player" })
        if t then t.insert({ name = "firearm-magazine", count = 200 }) end
        local dx = ({ N = 0, E = TDIST, S = 0, O = -TDIST })[d[1]]
        local dy = ({ N = -TDIST, E = 0, S = TDIST, O = 0 })[d[1]]
        -- cible alignée sur le centre RÉEL (emprise impaire : centre au demi-tuile)
        local px, py = x, y
        if t then px, py = t.position.x, t.position.y end
        st.tir[#st.tir + 1] = { n = n, dir = d[1], o = d[2], t = t, x = x, y = y, cx = px + dx, cy = py + dy,
          recrees = 0, mes = {} }
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
    if t > T_ECRIT then
      -- E68 : éclat de tir (entité explosion-gunshot, source_effects de la munition) relevé par le moteur
      for _, c in ipairs(st.tir) do
        if c.t and c.t.valid and #c.mes < MES_MAX then
          local ex = s.find_entities_filtered({ name = "explosion-gunshot",
            area = { { c.x - 9, c.y - 9 }, { c.x + 9, c.y + 9 } } })
          for _, x in ipairs(ex) do
            local dx, dy = x.position.x - c.t.position.x, x.position.y - c.t.position.y
            local neuf = true
            for _, m in ipairs(c.mes) do
              if math.abs(m.dx - dx) < 1 / 512 and math.abs(m.dy - dy) < 1 / 512 then neuf = false end
            end
            if neuf and #c.mes < MES_MAX then
              local cb = c.cible and c.cible.valid and c.cible.position
              c.mes[#c.mes + 1] = { dx = dx, dy = dy, o = ori(c.t), tick = t,
                cbx = cb and (cb.x - c.t.position.x), cby = cb and (cb.y - c.t.position.y) }
            end
          end
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
    local tient, faux, pire = 0, {}, 0
    for _, c in ipairs(st.rose) do
      local o = c.t and c.t.valid and ori(c.t)
      if o then pire = math.max(pire, ecart(o, c.o)) end
      if o and ecart(o, c.o) < 1 / 256 then
        tient = tient + 1
      elseif #faux < 8 then
        faux[#faux + 1] = c.n .. "d" .. c.k .. "=" .. tostring(o)
      end
    end
    ctx.check(tient == #st.rose, "rose : orientation relue au tick " .. CHECK .. " = orientation ecrite (sans cible)",
      tient .. " / " .. #st.rose .. string.format(" ; ecart max %.2e tour", pire) ..
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
    for _, c in ipairs(st.tir) do
      local m = {}
      for _, x in ipairs(c.mes) do
        m[#m + 1] = string.format("(%.4f;%.4f;o=%s;t=%d)", x.dx, x.dy, x.o and string.format("%.4f", x.o) or "nil", x.tick)
      end
      ctx.log(string.format("ECLAT niveau %d %s : %d releve(s) %s", c.n, c.dir, #c.mes, table.concat(m, " ")))
    end
    -- éclat : règle du moteur (E68) contre le relevé, à partir des valeurs du PROTOTYPE (sprites.lua, « tir »)
    local eclat_ok, pire_e, l3 = 0, 0, {}
    for _, c in ipairs(st.tir) do
      local p = game.entity_prototypes[nom(nil, c.n)]
      local ap = p and p.attack_parameters
      local m = c.mes[1]
      local ok = false
      if ap and m and m.o and m.cbx and ecart(m.o, c.o) < 1 / 256 then
        local pc = ap.projectile_center or { 0, 0 }
        local cx0, cy = pc.x or pc[1] or 0, pc.y or pc[2] or 0
        local d = ap.projectile_creation_distance or 0
        -- règle E68 : visée de projectile_center vers la cible, dans le repère « déprojeté » (y / K), reprojetée
        local vx, vy = m.cbx - cx0, m.cby - cy
        local n = math.sqrt(vx * vx + (vy / K_PROJ) ^ 2)
        local ex, ey = cx0 + d * vx / n, cy + d * vy / n
        local err = math.max(math.abs(m.dx - ex), math.abs(m.dy - ey))
        if err > pire_e then pire_e = err end
        ok = err <= 1 / 32
        l3[#l3 + 1] = string.format("%d%s:%.3f", c.n, c.dir, err)
      else
        l3[#l3 + 1] = string.format("%d%s:sans-releve-aligne", c.n, c.dir)
      end
      if ok then eclat_ok = eclat_ok + 1 end
    end
    ctx.log("eclat (niveau direction : ecart max |releve - regle| en tuiles) : " .. table.concat(l3, " "))
    ctx.check(eclat_ok == #st.tir, string.format("eclat : position relevee = projectile_center + distance x (vx, vy) / |(vx, vy / %.4f)|, v = "
      .. "cible - projectile_center, valeurs du prototype, a 1/32 pres (E68)", K_PROJ), eclat_ok .. " / " .. #st.tir .. string.format(" ; ecart max %.4f", pire_e))
    ctx.check(tire == #st.tir, "tir : chaque tourelle a tire (chargeurs consommes)", tire .. " / " .. #st.tir)
    ctx.check(vise == #st.tir, "tir : orientation = direction de la cible (a 1/64 pres)", vise .. " / " .. #st.tir)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if not st.pret then return end
    -- table des poses de la rose, pour gun_rose_images.py (positions RÉELLES des entités)
    local L = { "niveau\tage\tk\torientation_ecrite\torientation_lue\tx\ty\tnom" }
    for _, c in ipairs(st.rose) do
      if c.t and c.t.valid and not c.vanille then
        L[#L + 1] = string.format("%d\t%d\t%d\t%.6f\t%.6f\t%.5f\t%.5f\t%s", c.n, math.floor((c.n + 1) / 2), c.k, c.o,
          ori(c.t) or -1, c.t.position.x, c.t.position.y, c.t.name)
      end
    end
    game.write_file("fo-shots/gun-rose-poses.tsv", table.concat(L, "\n") .. "\n", false)
    for e = 1, 15 do
      local n = 2 * e - 1
      local cx, cy = centre_grille(n)
      add(string.format("rose-age%02d-z1-jour", e), cx, cy, 1, 0, { res = RES_Z1, info = false })
      add(string.format("rose-age%02d-z1-nuit", e), cx, cy, 1, 0.5, { res = RES_Z1, info = false })
      add(string.format("rose64-age%02d-z2-jour", e), cx, cy, 2, 0, { res = RES_Z2, info = false, aa = false })
      add(string.format("rose64-age%02d-z2-nuit", e), cx, cy, 2, 0.5, { res = RES_Z2, info = false })
    end
    -- niveaux PAIRS (socle + pièce paire) à zoom 2, jour et nuit : 10 (âge 5), 18 (âge 9), 30 (âge 15)
    for _, e in ipairs({ 5, 9, 15 }) do
      local n = 2 * e
      local cx, cy = centre_grille(n)
      add(string.format("pair-niv%02d-z2-jour", n), cx, cy, 2, 0, { res = RES_Z2, info = false })
      add(string.format("pair-niv%02d-z2-nuit", n), cx, cy, 2, 0.5, { res = RES_Z2, info = false })
    end
    for _, c in ipairs(st.tir) do
      if c.n == 1 or c.n == 3 or c.n == 23 or c.n == 25 or c.n == 29 then
        for k = 1, 2 do
          add(string.format("tir-niv%02d-%s-%d", c.n, c.dir, k), c.x, c.y - 1, 2, 0, { res = { 640, 640 } })
        end
      end
    end
  end,
}
