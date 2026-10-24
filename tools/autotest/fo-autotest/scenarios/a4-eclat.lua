-- Scénario greffé du lot A4 (24/10) : l'ÉCLAT DE TIR de chaque âge (couche draw_as_glow d'attacking_animation,
-- tools/render/pieces/levels/gun_e/eclat_tir.py) vu EN TIR, dans 8 directions par âge.
--   & "<racine>\fo-autotest.bat" nopause 1000 a4-eclat "<source>"     (contrôles, sans images)
--   & "<racine>\fo-captures.bat" a4-eclat "<source>"                   (captures, sans son)
--   py -3.9 tools/autotest/a4_eclat_images.py "<fo-shots>" --feuilles "<source>\graphics\levels\gun"
--
-- Par âge 2 à 15 (niveau impair 2e − 1), 8 tourelles, chacune face à un ver géant ENNEMI à 11 tuiles dans la direction
-- de l'image k (k = 0, 6, 16, 26, 32, 38, 48, 58 : N, NE vu en jeu, E, SE, S, SO, O, NO ; F121), cessez-le-feu de
-- l'ennemi, ver recréé s'il meurt ; sites à 80 tuiles d'écart (aucune tourelle n'atteint le ver d'un voisin).
-- Captures zoom 2 (sans mode Alt) : EN TIR, chaque site de jour à 3 instants, puis un site par âge (k = 26) de nuit ;
-- `a4-eclat-impair` : même scénario, captures décalées d'UN tick (shots_delay + 1 : une capture toutes les 10 ticks
-- n'échantillonne que 3 des 6 phases de la cadence de tir) ; puis les
-- munitions sont RETIRÉES et les vers détruits (la tête garde son orientation, F122 : sans cible) et chaque site est
-- recapturé à l'ARRÊT : la différence des deux captures d'un site montre l'éclat (et l'éclat vanilla de la munition,
-- explosion-gunshot, F126), a4_eclat_images.py la compare aux bouts des canons mesurés (sprites.json).
-- Table des sites : fo-shots/a4-eclat-sites.tsv. Contrôles : tourelles posées, chacune a tiré (chargeurs consommés),
-- orientation au contrôle = direction de sa cible (1/64 près).

local TX0, TY0, TPAS, TDIST, TCOL = -3200, 2400, 80, 11, 8
local KS = { 0, 6, 16, 26, 32, 38, 48, 58 }
local PROJ = math.sqrt(0.5)
local T_ECRIT, CHECK = 30, 900
local RES = { 640, 640 }
local INSTANTS = 3

local function orientation_image(k)
  if k % 16 == 0 then return k / 64 end
  local th = 2 * math.pi * k / 64
  return (math.atan2(math.sin(th), PROJ * math.cos(th)) / (2 * math.pi)) % 1
end

local function ecart(a, b)
  local d = math.abs(a - b) % 1
  return math.min(d, 1 - d)
end

local function ori(e)
  local ok, v = pcall(function() return e.orientation end)
  return ok and v or nil
end

return {
  description = "A4 : eclat de tir par age (couche d'attacking_animation), 14 ages x 8 directions, en tir puis a l'arret",
  base = nil,
  check_tick = CHECK,
  shots_delay = 400,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.pret = false
    game.map_settings.enemy_expansion.enabled = false
    game.forces.player.set_cease_fire("enemy", false)
    game.forces.enemy.set_cease_fire("player", true)
    st.sites = {}
    local i = 0
    for e = 2, 15 do
      for _, k in ipairs(KS) do
        local x, y = TX0 + i % TCOL * TPAS, TY0 + math.floor(i / TCOL) * TPAS
        i = i + 1
        ctx.prepare_area(x - 20, y - 20, x + 21, y + 21, "grass-1")
        local n = 2 * e - 1
        local t = s.create_entity({ name = "fo-lvl-gun-" .. n, position = { x, y }, force = "player" })
        if t then t.insert({ name = "firearm-magazine", count = 200 }) end
        local o = orientation_image(k)
        local px, py = x, y
        if t then px, py = t.position.x, t.position.y end
        st.sites[#st.sites + 1] = { e = e, n = n, k = k, o = o, t = t, x = px, y = py,
          cx = px + TDIST * math.sin(2 * math.pi * o), cy = py - TDIST * math.cos(2 * math.pi * o), recrees = 0 }
      end
    end
    local nrows = math.ceil(#st.sites / TCOL)
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy",
        area = { { TX0 - 120, TY0 - 120 }, { TX0 + (TCOL - 1) * TPAS + 120, TY0 + (nrows - 1) * TPAS + 120 } } })) do
      en.destroy()
    end
    local poses = 0
    for _, c in ipairs(st.sites) do if c.t then poses = poses + 1 end end
    ctx.check(poses == #st.sites, "tourelles posees (14 ages x 8 directions)", poses .. " / " .. #st.sites)
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local s = ctx.surface()
    local t = e.tick
    if t == T_ECRIT then
      for _, c in ipairs(st.sites) do
        if c.t and c.t.valid then
          c.mun0 = c.t.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine")
        end
      end
    end
    -- arrêt du tir (session avec images) : juste après la dernière capture « en tir »
    if st.t_arret and t == st.t_arret then
      for _, c in ipairs(st.sites) do
        if c.t and c.t.valid then c.t.get_inventory(defines.inventory.turret_ammo).clear() end
        if c.cible and c.cible.valid then c.cible.destroy() end
      end
      st.arrete = true
      log("[FO-A4-ECLAT] tir arrete au tick " .. t)
    end
    if t >= T_ECRIT and not st.arrete then
      for _, c in ipairs(st.sites) do
        if not (c.cible and c.cible.valid) then
          c.cible = s.create_entity({ name = "behemoth-worm-turret", position = { c.cx, c.cy }, force = "enemy" })
          if c.cible and c.t and c.t.valid then
            local vx, vy = c.cible.position.x - c.t.position.x, c.cible.position.y - c.t.position.y
            c.o = (math.atan2(vx, -vy) / (2 * math.pi)) % 1
          end
          if t > T_ECRIT then c.recrees = c.recrees + 1 end
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then return end
    local tire, vise, l = 0, 0, {}
    for _, c in ipairs(st.sites) do
      local mun = c.t and c.t.valid and c.t.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine")
      local conso = (c.mun0 and mun) and (c.mun0 - mun) or -1
      local o = c.t and c.t.valid and ori(c.t)
      if conso > 0 then tire = tire + 1 end
      if o and ecart(o, c.o) < 1 / 64 then vise = vise + 1 end
      l[#l + 1] = string.format("%dk%02d:%d,%s", c.n, c.k, conso, o and string.format("%.4f", o) or "nil")
    end
    ctx.log("tir (niveau k : chargeurs consommes, orientation) : " .. table.concat(l, " "))
    ctx.check(tire == #st.sites, "chaque tourelle a tire (chargeurs consommes)", tire .. " / " .. #st.sites)
    ctx.check(vise == #st.sites, "orientation = direction de la cible (a 1/64 pres)", vise .. " / " .. #st.sites)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if not st.pret then return end
    local L = { "capture\tetat\tniveau\tage\tk\torientation\tx\ty" }
    local function site(nom, c, etat, nuit)
      add(nom, c.x, c.y - 1, 2, nuit and 0.5 or 0, { res = RES, info = false, aa = false })
      L[#L + 1] = string.format("%s\t%s\t%d\t%d\t%d\t%.6f\t%.5f\t%.5f", nom, etat, c.n, c.e, c.k,
        (c.t and c.t.valid and ori(c.t)) or -1, c.x, c.y)
    end
    -- INSTANTS captures en tir par site, espacées de #sites × 10 ticks : la couche d'éclat n'est dessinée qu'un court
    -- instant à chaque coup (cadence 6 ticks), une capture sur six environ la montre (premier passage, 24/10)
    local n = 0
    for i = 1, INSTANTS do
      for _, c in ipairs(st.sites) do
        site(string.format("tir-e%02d-k%02d-i%d", c.e, c.k, i), c, "tir", false)
        n = n + 1
      end
    end
    for _, c in ipairs(st.sites) do
      if c.k == 26 then
        site(string.format("tir-e%02d-k%02d-nuit", c.e, c.k), c, "tir-nuit", true)
        n = n + 1
      end
    end
    -- arrêt : 5 ticks après la dernière capture en tir (une capture toutes les 10 ticks, la 1re à ce tick)
    st.t_arret = game.tick + 10 * (n - 1) + 5
    for _, c in ipairs(st.sites) do
      site(string.format("arret-e%02d-k%02d", c.e, c.k), c, "arret", false)
    end
    game.write_file("fo-shots/a4-eclat-sites.tsv", table.concat(L, "\n") .. "\n", false)
  end,
}
