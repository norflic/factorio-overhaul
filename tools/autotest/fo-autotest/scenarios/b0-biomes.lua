--[[
  Scénario GREFFÉ « b0-biomes » (lot B0, 24/10) : les FRONTIÈRES entre biomes, en moteur réel, pour les captures
  AVANT / APRÈS (même graine, mêmes endroits) et pour contrôler que les tuiles des biomes restent des sols fermes.

  Lancement : & "<racine>\fo-autotest.bat" nopause 300 b0-biomes "<source>"
  Images    : & "<racine>\fo-captures.bat" b0-biomes "<source>"

  À la création de la carte (graine des bancs), les chunks sont générés jusqu'à RAYON chunks du départ ; pour chaque
  biome du mod, le scénario cherche une FRONTIÈRE naturelle (point où le biome et les sols vanilla se partagent un
  disque de 10 tuiles, à parts aussi égales que possible), et une frontière vanilla HERBE / DÉSERT de référence. Le
  site garanti du cristal (lot M0, posé par script) est aussi capturé. Les points de la graine 20261020 sont FIGÉS
  (POINTS) : les captures après correction sont prises aux mêmes endroits, même si la génération change.

  Captures (de jour, sans le mode Alt) : chaque frontière aux zooms 0,5, 1 et 2 ; vues larges (zoom 0,25) du
  cristal et de la référence vanilla ; site garanti du cristal aux zooms 0,5 et 1.
  Contrôles : tuiles du biome présentes, sol ferme (ground-tile, pas water-tile), frontière trouvée ; relevé des
  tuiles voisines du biome (journal) et des couches de dessin (layer).
]]

local RAYON = 18 -- chunks générés autour du départ
local CHERCHE = 544 -- tuiles : zone de recherche (chunks entièrement générés)
local R = 10 -- rayon du disque de mesure d'une frontière
local CHECK = 120

local BIOMES = {
  { tile = "fo-crystal-flats", key = "cristal" },
  { tile = "fo-toxic-marsh", key = "marais" },
  { tile = "fo-volcanic-ash", key = "cendres" },
}
local HERBE = { "grass-1", "grass-2", "grass-3", "grass-4" }
local DESERT = { "sand-1", "sand-2", "sand-3", "red-desert-0", "red-desert-1", "red-desert-2", "red-desert-3" }

-- Points figés pour la graine 20261020 (relevés au premier passage, AVANT correction) ; nil : recherche.
local POINTS = {
  [20261020] = { cristal = { -330.5, -120.5 }, cendres = { 494.5, -427.5 }, vanilla = { -475.5, -379.5 } },
}

-- Nuancier (zone préparée, sans décor) : disques de RN tuiles de chaque sol sur deux fonds vanilla (les deux voisins les
-- plus fréquents du biome de cristal) ; couleurs mesurées par tools/autotest/b0_bords.py, transitions sur des courbes.
local NX, NY, NPAS, RN = 2400, 2400, 16, 6
local NUANCIER = {
  { fond = "grass-2", disques = { "fo-crystal-flats", "fo-toxic-marsh", "fo-volcanic-ash", "red-desert-0", "sand-1" } },
  { fond = "red-desert-0", disques = { "fo-crystal-flats", "fo-toxic-marsh", "fo-volcanic-ash", "grass-2", "sand-1" } },
}

local function nuancier(s)
  local rangs = #NUANCIER
  local n = #NUANCIER[1].disques
  local x0, y0 = NX - NPAS, NY - NPAS
  local x1, y1 = NX + n * NPAS, NY + rangs * NPAS
  local disques = {}
  for i, rang in ipairs(NUANCIER) do
    local ry = NY + (i - 1) * NPAS
    s.set_tiles((function()
      local t = {}
      for x = x0, x1 - 1 do
        for y = ry - NPAS / 2, ry + NPAS / 2 - 1 do t[#t + 1] = { name = rang.fond, position = { x, y } } end
      end
      return t
    end)())
    for j, nom in ipairs(rang.disques) do
      local cx = NX + (j - 1) * NPAS
      local t = {}
      for dx = -RN, RN do
        for dy = -RN, RN do
          if dx * dx + dy * dy <= RN * RN + RN then t[#t + 1] = { name = nom, position = { cx + dx, ry + dy } } end
        end
      end
      s.set_tiles(t)
      disques[#disques + 1] = { tuile = nom, fond = rang.fond, x = cx + 0.5, y = ry + 0.5 }
    end
  end
  s.destroy_decoratives({ area = { { x0, y0 }, { x1, y1 } } })
  return disques
end

local function fully_generated(s, p)
  local cx, cy = math.floor(p.x / 32), math.floor(p.y / 32)
  for dx = -1, 1 do
    for dy = -1, 1 do
      if not s.is_chunk_generated({ cx + dx, cy + dy }) then return false end
    end
  end
  return true
end

--- Meilleure frontière entre les tuiles `a` (liste de noms) et `b` (liste de noms, ou nil = tout sol ferme autre que a).
local function frontiere(s, a, b, exclus)
  local tiles = s.find_tiles_filtered({ area = { { -CHERCHE, -CHERCHE }, { CHERCHE, CHERCHE } }, name = a, limit = 40000 })
  if #tiles == 0 then return nil, 0 end
  local best, best_score
  local step = math.max(1, math.floor(#tiles / 400))
  for i = 1, #tiles, step do
    local p = tiles[i].position
    local loin = true
    for _, e in ipairs(exclus or {}) do
      if (p.x - e.x) ^ 2 + (p.y - e.y) ^ 2 < (e.r + R + 4) ^ 2 then loin = false end
    end
    if loin and fully_generated(s, p) then
      local na = s.count_tiles_filtered({ position = p, radius = R, name = a })
      local nb
      if b then
        nb = s.count_tiles_filtered({ position = p, radius = R, name = b })
      else
        local tout = s.count_tiles_filtered({ position = p, radius = R })
        local eau = s.count_tiles_filtered({ position = p, radius = R, collision_mask = "water-tile" })
        nb = tout - na - eau
      end
      -- Les arbres cachent le sol (marais du premier passage : forêt dense) : chaque arbre coûte 4 tuiles.
      local arbres = s.count_entities_filtered({ position = p, radius = R + 4, type = "tree" })
      local score = (math.min(na, nb) - 4 * arbres) * 1000 - math.floor(math.sqrt(p.x * p.x + p.y * p.y))
      if not best_score or score > best_score then best, best_score = { x = p.x + 0.5, y = p.y + 0.5, na = na, nb = nb }, score end
    end
  end
  return best, #tiles
end

--- Voisins (4-connexité) des tuiles du biome : histogramme des noms, sur un échantillon.
local function voisins(s, tile)
  local tiles = s.find_tiles_filtered({ area = { { -CHERCHE, -CHERCHE }, { CHERCHE, CHERCHE } }, name = tile, limit = 40000 })
  local h, noms = {}, {}
  local step = math.max(1, math.floor(#tiles / 3000))
  for i = 1, #tiles, step do
    local p = tiles[i].position
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local n = s.get_tile(p.x + d[1], p.y + d[2]).name
      if n ~= tile then
        if not h[n] then h[n] = 0; noms[#noms + 1] = n end
        h[n] = h[n] + 1
      end
    end
  end
  table.sort(noms, function(x, y) return h[x] > h[y] or (h[x] == h[y] and x < y) end)
  local parts = {}
  for _, n in ipairs(noms) do parts[#parts + 1] = n .. " " .. h[n] end
  return table.concat(parts, ", ")
end

return {
  description = "B0 : frontieres entre biomes (captures avant / apres, sol ferme)",
  check_tick = CHECK,
  shots_delay = 60,

  shots = function(ctx, add)
    local st = ctx.state()
    local sans = { info = false }
    for _, f in ipairs(st.frontieres or {}) do
      add("frontiere-" .. f.key .. "-z05", f.x, f.y, 0.5, 0, sans)
      add("frontiere-" .. f.key .. "-z1", f.x, f.y, 1, 0, sans)
      add("frontiere-" .. f.key .. "-z2", f.x, f.y, 2, 0, sans)
      if f.key == "cristal" or f.key == "vanilla" then
        add("large-" .. f.key .. "-z025", f.x, f.y, 0.25, 0, sans)
      end
    end
    if st.site then
      add("site-cristal-z05", st.site.x, st.site.y, 0.5, 0, sans)
      add("site-cristal-z1", st.site.x, st.site.y, 1, 0, sans)
    end
    if st.disques then
      local n = #NUANCIER[1].disques
      add("nuancier-z05", NX + (n - 1) * NPAS / 2 + 0.5, NY + NPAS / 2 + 0.5, 0.5, 0, sans)
      add("nuancier-cristal-z1", NX + 0.5, NY + NPAS / 2 + 0.5, 1, 0, sans)
      add("nuancier-cristal-z2", NX + 0.5 + RN, NY + 0.5, 2, 0, sans)
      -- Mise en page pour la mesure des couleurs (b0_bords.py) : centres des disques en coordonnées du monde.
      game.write_file("fo-shots/b0-nuancier.json", game.table_to_json({ rayon = RN, pas = NPAS, disques = st.disques }), false)
    end
  end,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local seed = s.map_gen_settings.seed
    st.seed = seed
    s.request_to_generate_chunks({ 0, 0 }, RAYON)
    s.force_generate_chunk_requests()
    -- Sites garantis (exclus des frontières naturelles), dont celui du cristal (capturé à part).
    local exclus = {}
    if remote.interfaces["fo-monde"] then
      for _, d in ipairs(remote.call("fo-monde", "status").done or {}) do
        for _, site in ipairs(d.sites or {}) do
          exclus[#exclus + 1] = { x = site.x, y = site.y, r = 20 }
          if d.key == "crystal" and not st.site then st.site = { x = site.x + 0.5, y = site.y + 0.5 } end
        end
      end
    end
    local fixes = POINTS[seed]
    st.frontieres = {}
    st.comptes = {}
    for _, b in ipairs(BIOMES) do
      local p, n = frontiere(s, { b.tile }, nil, exclus)
      st.comptes[b.key] = n
      if fixes and fixes[b.key] then p = { x = fixes[b.key][1], y = fixes[b.key][2], fige = true } end
      if p then
        st.frontieres[#st.frontieres + 1] = { key = b.key, tile = b.tile, x = p.x, y = p.y }
        ctx.log(string.format("frontiere %s : (%.1f, %.1f)%s, %s tuiles du biome dans la zone, disque %d / %s",
          b.key, p.x, p.y, p.fige and " FIGEE" or "", tostring(n), p.na or -1, tostring(p.nb)))
      end
      ctx.log("voisins de " .. b.tile .. " : " .. voisins(s, b.tile))
    end
    local p = frontiere(s, HERBE, DESERT, exclus)
    if fixes and fixes.vanilla then p = { x = fixes.vanilla[1], y = fixes.vanilla[2], fige = true } end
    if p then
      st.frontieres[#st.frontieres + 1] = { key = "vanilla", x = p.x, y = p.y }
      ctx.log(string.format("frontiere vanilla herbe/desert : (%.1f, %.1f)%s", p.x, p.y, p.fige and " FIGEE" or ""))
    end
    if st.site then ctx.log(string.format("site garanti du cristal : (%.1f, %.1f)", st.site.x, st.site.y)) end
    ctx.prepare_area(NX - NPAS, NY - NPAS, NX + #NUANCIER[1].disques * NPAS, NY + #NUANCIER * NPAS, "grass-2")
    st.disques = nuancier(s)
    local poses = 0
    for _, d in ipairs(st.disques) do
      if s.get_tile(math.floor(d.x), math.floor(d.y)).name == d.tuile then poses = poses + 1 end
    end
    st.disques_poses = poses
    local layers = {}
    for _, n in ipairs({ "fo-volcanic-ash", "fo-crystal-flats", "fo-toxic-marsh", "grass-1", "grass-2", "sand-1",
      "red-desert-0", "dirt-1", "water-shallow", "water-mud", "nuclear-ground" }) do
      local tp = game.tile_prototypes[n]
      layers[#layers + 1] = n .. " " .. (tp and tp.layer or "?")
    end
    ctx.log("couches (layer) : " .. table.concat(layers, ", "))
  end,

  tick = function(ctx, e) end,

  finish = function(ctx)
    local st = ctx.state()
    local par = {}
    for _, f in ipairs(st.frontieres or {}) do par[f.key] = f end
    for _, b in ipairs(BIOMES) do
      local tp = game.tile_prototypes[b.tile]
      local cm = tp and tp.collision_mask or {}
      ctx.check(tp ~= nil and cm["ground-tile"] == true and not cm["water-tile"],
        b.tile .. " : sol ferme (ground-tile, pas water-tile)", tp and ("layer " .. tp.layer) or "absent")
      ctx.check((st.comptes[b.key] or 0) > 0 and par[b.key] ~= nil,
        b.tile .. " : present a moins de " .. CHERCHE .. " tuiles du depart, frontiere trouvee",
        tostring(st.comptes[b.key]) .. " tuile(s)")
    end
    ctx.check(par.vanilla ~= nil, "frontiere vanilla herbe / desert trouvee")
    ctx.check(st.site ~= nil, "site garanti du cristal connu")
    ctx.check(st.disques and st.disques_poses == #st.disques, "nuancier : un disque de chaque sol sur chaque fond",
      tostring(st.disques_poses) .. " / " .. tostring(st.disques and #st.disques))
  end,
}
