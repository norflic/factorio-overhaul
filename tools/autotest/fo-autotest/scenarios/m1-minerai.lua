--[[
  Scénario GREFFÉ « m1-minerai » (lot M1, 24/10) : le gisement de TUNGSTÈNE (feuille propre du kit minerai,
  tools/render/pieces/ressources) posé à côté des minerais vanilla, pour les captures aux zooms 1 et 2, de jour et de
  nuit, et pour contrôler que le prototype branché se pose, se mine et garde son nom.

  Lancement : & "<racine>\fo-autotest.bat" nopause 600 m1-minerai "<source>"
  Images    : & "<racine>\fo-captures.bat" m1-minerai "<source>"

  Deux planches de 3 × 2 gisements (9 × 9 tuiles, quantité décroissante du centre vers le bord : les 8 stades se
  voient, du plus riche au centre au plus pauvre au bord) :
  - N (sol natif) en (X0, Y0) : rangée du haut fer, TUNGSTÈNE (sur ses cendres volcaniques, fo-volcanic-ash), charbon ;
    rangée du bas cuivre, pierre, uranium ; tout le reste sur herbe ;
  - C (même sol) en (X0, Y0 + 40) : les mêmes six gisements, TOUS sur les cendres volcaniques (comparaison directe).
  Le tungstène est entre le fer et le charbon (les deux confusions possibles : gris-bleu, noir), 2 tuiles d'écart :
  chaque gros plan au zoom 2 montre le tungstène et un voisin côte à côte.
  Une foreuse électrique alimentée (sans poteau visible) mine le tungstène de la planche N (coin sud-est, visible
  dans les gros plans) : le prototype branché se mine (minerai dur, catégorie fo-hard-solid).
  Contrôles : prototype et nom gardés, minable, catégorie ; gisements posés (quantités) ; cendres sous le tungstène ;
  la foreuse a extrait du tungstène au tick du contrôle.
]]

local X0, Y0 = 3600, 3600
local PAS = 11
local R = 4 -- rayon du gisement (9 × 9 tuiles)
local ORDRE = { "iron-ore", "fo-tungsten-ore", "coal", "copper-ore", "stone", "uranium-ore" }
local W = 2 -- rang du tungstène dans ORDRE
local CHECK = 540

--- Quantité selon la distance au centre : du plus riche (au-delà du premier seuil vanilla, 15 000) au plus pauvre.
local function quantite(d)
  local t = math.min(1, d / (R + 0.5))
  return math.max(30, math.floor(20000 * (1 - t) ^ 2.2 + 40))
end

local function centre(planche, i)
  local col, lig = (i - 1) % 3, math.floor((i - 1) / 3)
  -- tuile du centre (entier) ; le centre du gisement est en (cx + 0,5, cy + 0,5)
  return X0 + (col - 1) * PAS, Y0 + planche * 40 + lig * PAS - 5
end

local function poser(s, nom, cx, cy, sol)
  local tiles = {}
  for dx = -R - 1, R + 1 do
    for dy = -R - 1, R + 1 do tiles[#tiles + 1] = { name = sol, position = { cx + dx, cy + dy } } end
  end
  s.set_tiles(tiles) -- les tuiles AVANT les entités (F135)
  local n, total = 0, 0
  for dx = -R, R do
    for dy = -R, R do
      local d = math.sqrt(dx * dx + dy * dy)
      if d <= R + 0.5 then
        local q = quantite(d)
        local e = s.create_entity({ name = nom, position = { cx + dx + 0.5, cy + dy + 0.5 }, amount = q })
        if e then n, total = n + 1, total + q end
      end
    end
  end
  return n, total
end

return {
  description = "m1-minerai : gisement de tungstene (feuille M1) a cote des minerais vanilla, zooms 1 et 2, jour et nuit",
  check_tick = CHECK,
  shots_delay = 120,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    ctx.prepare_area(X0 - 40, Y0 - 30, X0 + 40, Y0 + 80, "grass-1")
    for _, e in ipairs(s.find_entities_filtered({ area = { { X0 - 120, Y0 - 120 }, { X0 + 120, Y0 + 180 } }, force = "enemy" })) do
      e.destroy()
    end
    local p = game.entity_prototypes["fo-tungsten-ore"]
    ctx.check(p ~= nil and p.type == "resource", "prototype fo-tungsten-ore (nom garde, type resource)")
    if not p then return end
    ctx.check(p.resource_category == "fo-hard-solid" and p.mineable_properties.minable
      and p.mineable_properties.products[1].name == "fo-tungsten-ore",
      "tungstene minable (categorie fo-hard-solid, produit fo-tungsten-ore)",
      tostring(p.resource_category))
    st.poses = {}
    local tout_ok = true
    for planche = 0, 1 do
      for i, nom in ipairs(ORDRE) do
        local cx, cy = centre(planche, i)
        local sol = (planche == 1 or nom == "fo-tungsten-ore") and "fo-volcanic-ash" or "grass-1"
        local n, total = poser(s, nom, cx, cy, sol)
        st.poses[#st.poses + 1] = { nom = nom, x = cx, y = cy, planche = planche, n = n, total = total }
        if n < 60 then tout_ok = false end
      end
    end
    ctx.check(tout_ok, "12 gisements poses (9 x 9, 61 entites chacun au moins)", #st.poses)
    -- cendres sous le tungstène de la planche N
    local tx, ty = centre(0, W)
    local t = s.get_tile(tx, ty)
    ctx.check(t.name == "fo-volcanic-ash", "cendres volcaniques sous le tungstene", t.name)
    -- foreuse électrique au coin sud-est du gisement de tungstène de la planche N, alimentée ; dépôt au nord, sur
    -- le gisement
    local d = s.create_entity({ name = "electric-mining-drill", position = { tx + 4.5, ty + 3.5 }, force = "player",
                                direction = defines.direction.north })
    if d then
      st.coffre = s.create_entity({ name = "wooden-chest", position = d.drop_position, force = "player" })
      ctx.power(tx + 4.5, ty + 3.5)
    end
    ctx.check(d ~= nil and st.coffre ~= nil, "foreuse electrique et coffre poses sur le tungstene")
    st.foreuse = d and d.position
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local n = st.coffre and st.coffre.valid and st.coffre.get_item_count("fo-tungsten-ore") or 0
    ctx.check(n > 0, "la foreuse electrique a extrait du tungstene (feuille M1 branchee)", n)
    local poses = 0
    for _, g in ipairs(st.poses or {}) do
      poses = poses + s.count_entities_filtered({ name = g.nom, area = { { g.x - R - 0.5, g.y - R - 0.5 }, { g.x + R + 1.5, g.y + R + 1.5 } } })
    end
    ctx.check(poses >= 12 * 60, "gisements toujours en place au controle", poses)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if not st.poses then return end
    local opt = { aa = false }
    -- planches entières au zoom 1 (31 × 20 tuiles dans un cadre de 50 × 28)
    for _, pn in ipairs({ { 0, "natif" }, { 1, "cendres" } }) do
      local planche, nom = pn[1], pn[2]
      local cx, cy = centre(planche, 5)
      local _, hy = centre(planche, 2)
      add("planche-" .. nom .. "-z1-jour", cx + 0.5, (cy + hy) / 2 + 0.5, 1, 0, opt)
      add("planche-" .. nom .. "-z1-nuit", cx + 0.5, (cy + hy) / 2 + 0.5, 1, 0.5, opt)
    end
    -- gros plans au zoom 2 (25 × 14 tuiles) : le tungstène et un voisin côte à côte (centres à 11 tuiles)
    for _, pn in ipairs({ { 0, "natif" }, { 1, "cendres" } }) do
      local planche, nom = pn[1], pn[2]
      local tx, ty = centre(planche, W)
      local fx = centre(planche, 1)
      local cx = centre(planche, 3)
      add(nom .. "-fer-tungstene-z2-jour", (tx + fx) / 2 + 0.5, ty + 0.5, 2, 0, opt)
      add(nom .. "-fer-tungstene-z2-nuit", (tx + fx) / 2 + 0.5, ty + 0.5, 2, 0.5, opt)
      add(nom .. "-tungstene-charbon-z2-jour", (tx + cx) / 2 + 0.5, ty + 0.5, 2, 0, opt)
      add(nom .. "-tungstene-charbon-z2-nuit", (tx + cx) / 2 + 0.5, ty + 0.5, 2, 0.5, opt)
    end
    local tx, ty = centre(0, W)
    add("tungstene-seul-z2-jour", tx + 0.5, ty + 0.5, 2, 0, opt)
    add("tungstene-seul-z2-nuit", tx + 0.5, ty + 0.5, 2, 0.5, opt)
    add("tungstene-seul-z4-jour", tx + 0.5, ty + 0.5, 4, 0, opt)
    add("vue-ensemble-z05-jour", X0 + 0.5, Y0 + 20.5, 0.5, 0, opt)
  end,
}
