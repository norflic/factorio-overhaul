--[[
  Garantie de placement des monnaies d'époque (lot M0, 23/10). Lua PUR : données et règles, testables hors jeu
  (tests/monde_test.lua) ; l'exécution en moteur est dans script/world/guarantee.lua.

  Problème : le tungstène (époque 5), le cristal (7) et le méthane (8) ne viennent que des biomes du mod, placés
  par bruit. Sur une graine sans cendres proches, le centre de commandement ne passe pas l'époque 5. Et dans une
  sauvegarde existante, l'autoplacement ne touche que les chunks NEUFS.

  Règle (une réussite par ressource et par partie, sur nauvis) :
  - nombre et distance au départ : X.base_resources (shared/content/epochs.lua, placement.guaranteed) ;
  - partie neuve (on_init au tick 0) : le site garanti est TOUJOURS posé. Au démarrage, les chunks à plus de
    200 tuiles ne sont pas générés : le jeu ne sait pas encore si la graine a un gisement à cette distance, et le
    savoir demanderait de générer 2 000 chunks (environ 1,5 s et une sauvegarde 5 fois plus grosse) ;
  - sauvegarde existante (on_configuration_changed, ou le filet périodique) : posé seulement s'il manque des
    « unités » dans les chunks DÉJÀ générés à moins de la distance maximale (minerai : quantité totale / min_total ;
    fluide : nombre de puits) ;
  - le site : des candidats tirés de la graine de la carte (Park-Miller, aucun ordre de pairs, aucune
    trigonométrie), dans l'anneau [distance min + rayon du cœur, distance max - rayon du cœur] ; le premier
    candidat valable est retenu (pas de bâtiment d'une force autre qu'« enemy » ou « neutral », pas de gisement
    sous le cœur, que des tuiles naturelles de terre ferme sous le cœur, loin des autres sites garantis) ;
  - échec (aucun des MAX_TRIES candidats valable) : la ressource n'est PAS marquée traitée ; elle est reprise par
    le filet après un délai croissant (G.retry_delay), avec une AUTRE suite de candidats (essai k : graine décalée)
    et des critères assouplis par paliers (G.rules) : niveau 1, nouveaux candidats ; niveau 2, eau tolérée sous le
    cœur (au plus WATER_SHARE) et comblée par le sol du biome ; niveau 3 et suivants, distance maximale allongée
    de RING_STRETCH. Un bâtiment, un gisement existant ou une dalle posée par un joueur ne sont jamais tolérés.
]]

local W = require("shared.content.world")
local X = require("shared.content.epochs")

local G = {}

G.MAX_TRIES = 24       -- candidats essayés par site, au plus
G.SPACING = 8          -- tuiles libres au moins entre les disques de deux sites garantis
G.BUILD_MARGIN = 2     -- marge autour du disque où aucun bâtiment d'une force joueur ou IA n'est toléré
G.RESOURCE_MARGIN = 3  -- marge autour du cœur où aucun gisement ne doit déjà exister
G.EDGE_JITTER = 1.5    -- irrégularité du bord du disque de tuiles (en tuiles, ±)
-- Reprise après échec (correction M-1 de la vérification du lot M0) :
G.MAX_LEVEL = 3        -- dernier palier d'assouplissement (les essais suivants changent seulement de candidats)
G.WATER_SHARE = 0.5    -- niveau >= 2 : part d'eau tolérée sous le cœur (comblée par le sol du biome)
G.RING_STRETCH = 0.5   -- niveau >= 3 : distance maximale × 1,5
G.RETRY_BASE = 600     -- délai avant la reprise après le 1er échec (ticks) ; doublé à chaque échec suivant
G.RETRY_MAX = 36000    -- délai maximal (10 min de jeu)
G.SALT_STEP = 1000     -- décalage de la graine des candidats par essai (essai 0 : suite d'origine)

local MOD = 2147483647
local MUL = 48271

---------------------------------------------------------------------------------------------------
-- Générateur déterministe (Park-Miller, comme script/core/rng.lua, mais à état local : il ne touche pas au
-- stockage et ne dépend que de la graine).
---------------------------------------------------------------------------------------------------
function G.rng(seed)
  local s = seed % (MOD - 1) + 1
  local r = {}
  function r.next()
    s = (s * MUL) % MOD
    return s
  end
  function r.float()
    return (r.next() - 1) / (MOD - 1)
  end
  return r
end

--- Graine propre à une ressource, tirée de la graine de la carte (entier positif quelconque).
function G.mix(map_seed, salt)
  local a = (math.floor(map_seed) % MOD) * 31 % MOD
  local b = (math.floor(salt) % MOD) * 7919 % MOD
  return (a + b) % MOD
end

--- Hachage d'une tuile dans [0, 1) (bord irrégulier, quantités) ; arithmétique exacte en double.
function G.hash(x, y, seed)
  local v = ((x % MOD) * 92821 + (y % MOD) * 68917 + (seed % MOD)) % MOD
  if v == 0 then v = 1 end
  for _ = 1, 3 do v = (v * MUL) % MOD end
  return (v - 1) / (MOD - 1)
end

---------------------------------------------------------------------------------------------------
-- Spécifications : une par ressource garantie, dans l'ordre des époques (W.resource_order).
---------------------------------------------------------------------------------------------------
--- Ressource de X : d'abord X.base_resources (déjà en jeu avant X0 : tungstène, cristal, méthane), puis X.resources
--- (ressources neuves du scénario : ilménite, lot X1-TITANE).
local function base_resource(name)
  for _, r in ipairs(X.base_resources) do
    if r.name == name then return r end
  end
  for _, r in ipairs(X.resources) do
    if r.name == name then return r end
  end
  return nil
end

local function biome_decoratives(biome)
  local out = {}
  local decor = W.decor and W.decor[biome]
  for _, d in ipairs(decor and decor.decoratives or {}) do out[#out + 1] = d.name end
  return out
end

local SPECS = nil

--- Liste ordonnée des spécifications (copie fraîche à chaque appel : l'appelant peut la modifier).
function G.specs()
  if not SPECS then
    SPECS = {}
    for _, key in ipairs(W.guarantee_order or W.resource_order) do
      local r = W.resources[key]
      local base = assert(base_resource(r.resource), "garantie : " .. r.resource .. " absent de X.base_resources")
      local g = assert(base.placement and base.placement.guaranteed, "garantie : " .. r.resource .. " sans placement.guaranteed")
      local gu = assert(r.guarantee, "garantie : " .. key .. " sans champ guarantee (world.lua)")
      local spec = {
        key = key,
        resource = r.resource,
        kind = r.kind,
        epoch = base.epoch,
        tile = r.biome,
        count = g.count,
        dmin = g.distance[1],
        dmax = g.distance[2],
        site_radius = gu.site_radius,
        seed = r.autoplace.seed1,
        decoratives = biome_decoratives(r.biome),
        -- icône de l'étiquette de carte et des messages : l'objet du minerai (X1-TITANE : la ressource fo-ilmenite
        -- donne l'objet fo-ilmenite-ore ; pour le tungstène et le cristal, même nom), ou le fluide
        icon = r.kind == "fluid" and (r.fluid or r.resource) or (r.item or r.resource),
      }
      if r.kind == "fluid" then
        spec.well_amount = gu.wells.amount
        spec.well_spacing = gu.wells.spacing
        -- Cœur : tous les puits (au plus `count`) et leur chevalet 3×3.
        spec.core_radius = math.floor((g.count - 1) * gu.wells.spacing / 2) + 2
      else
        spec.ore_radius = gu.ore_radius
        spec.amount = gu.amount
        spec.min_total = gu.min_total
        spec.core_radius = gu.ore_radius
        spec.clear_trees = gu.clear_trees or nil
        if gu.ore_offset or gu.field_wells then
          -- Champ (lot X1-TITANE, champ de cratères) : gisement décalé de ore_offset et puits d'une AUTRE ressource
          -- (fluide) sur le même disque. Le cœur couvre le gisement et les chevalets 3×3 des puits.
          local ox, oy = (gu.ore_offset or { 0, 0 })[1], (gu.ore_offset or { 0, 0 })[2]
          spec.ore_offset = { ox, oy }
          local core = math.sqrt(ox * ox + oy * oy) + gu.ore_radius
          if gu.field_wells then
            local offs = {}
            for i, o in ipairs(gu.field_wells.offsets) do
              offs[i] = { o[1], o[2] }
              local d = math.sqrt(o[1] * o[1] + o[2] * o[2]) + 2
              if d > core then core = d end
            end
            spec.field_wells = { key = gu.field_wells.key, resource = gu.field_wells.resource, amount = gu.field_wells.amount,
              offsets = offs }
          end
          spec.core_radius = math.ceil(core)
        end
      end
      SPECS[#SPECS + 1] = spec
    end
  end
  local copy = {}
  for i, s in ipairs(SPECS) do
    local c = {}
    for k, v in pairs(s) do c[k] = v end
    if s.field_wells then
      -- copie profonde du champ (l'appelant peut modifier sa copie)
      local fw = { key = s.field_wells.key, resource = s.field_wells.resource, amount = s.field_wells.amount, offsets = {} }
      for j, o in ipairs(s.field_wells.offsets) do fw.offsets[j] = { o[1], o[2] } end
      c.field_wells = fw
    end
    if s.ore_offset then c.ore_offset = { s.ore_offset[1], s.ore_offset[2] } end
    copy[i] = c
  end
  return copy
end

function G.spec(key)
  for _, s in ipairs(G.specs()) do
    if s.key == key then return s end
  end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Décision
---------------------------------------------------------------------------------------------------
--- Unités déjà présentes : minerai = quantité totale / min_total (arrondi bas) ; fluide = nombre de puits.
--- Champ (field_wells) : sans au moins autant de puits de sa ressource fluide que le champ en pose (well_count), aucun
--- champ n'est compté (0) : le champ de cratères garanti est ilménite ET saumure.
function G.units_found(spec, total_amount, entity_count, well_count)
  if spec.kind == "fluid" then return entity_count or 0 end
  if spec.field_wells and (well_count or 0) < #spec.field_wells.offsets then return 0 end
  return math.floor((total_amount or 0) / spec.min_total)
end

--- Unités à poser (0 : rien à faire).
function G.units_to_place(spec, found)
  return math.max(0, spec.count - (found or 0))
end

--- Nombre de sites à poser pour `units` unités : un site par unité de minerai ; un seul site pour tous les puits.
function G.sites_for(spec, units)
  if units <= 0 then return 0 end
  if spec.kind == "fluid" then return 1 end
  return units
end

---------------------------------------------------------------------------------------------------
-- Candidats : positions (tuiles entières, relatives au départ) dans l'anneau, tirées de la graine.
---------------------------------------------------------------------------------------------------
--- Règles de l'essai `attempt` (0 : premier essai, critères stricts ; k : après k échecs).
function G.rules(attempt)
  attempt = attempt or 0
  local level = math.min(attempt, G.MAX_LEVEL)
  return {
    attempt = attempt,
    level = level,
    fill_water = level >= 2,
    water_share = level >= 2 and G.WATER_SHARE or 0,
    dmax_scale = level >= 3 and 1 + G.RING_STRETCH or 1,
  }
end

--- Distance maximale effective à l'essai `attempt`.
function G.dmax(spec, attempt)
  return math.floor(spec.dmax * G.rules(attempt).dmax_scale)
end

--- Délai (ticks) avant la reprise après `fails` échecs (1, 2, ...) : RETRY_BASE × 2^(fails - 1), au plus RETRY_MAX.
function G.retry_delay(fails)
  local d = G.RETRY_BASE
  for _ = 2, fails or 1 do
    d = d * 2
    if d >= G.RETRY_MAX then return G.RETRY_MAX end
  end
  return math.min(d, G.RETRY_MAX)
end

--- Le sol sous le cœur est-il acceptable ? land, water, other : nombres de tuiles naturelles de terre ferme, d'eau
--- naturelle et d'autres tuiles (dalles d'un joueur...). Renvoie nil (valable) ou le motif de refus.
function G.ground_verdict(rules, land, water, other)
  if other > 0 then return "sol" end
  if water == 0 then return nil end
  if not rules.fill_water then return "sol" end
  if water > rules.water_share * (land + water) then return "eau" end
  return nil
end

function G.ring(spec, attempt)
  return spec.dmin + spec.core_radius + 1, G.dmax(spec, attempt) - spec.core_radius - 1
end

--- n candidats de l'essai `attempt` (0 ou nil : suite d'origine, inchangée depuis le lot M0).
function G.candidates(map_seed, spec, n, attempt)
  attempt = attempt or 0
  local rng = G.rng(G.mix(map_seed, spec.seed + G.SALT_STEP * attempt))
  for _ = 1, 3 do rng.next() end
  local rmin, rmax = G.ring(spec, attempt)
  local out = {}
  for i = 1, n do
    local vx, vy, q
    repeat
      vx = 2 * rng.float() - 1
      vy = 2 * rng.float() - 1
      q = vx * vx + vy * vy
    until q > 0.01 and q <= 1
    local len = math.sqrt(q)
    local r = math.sqrt(rmin * rmin + rng.float() * (rmax * rmax - rmin * rmin))
    out[i] = { x = math.floor(vx / len * r + 0.5), y = math.floor(vy / len * r + 0.5) }
  end
  return out
end

--- Distance (tuiles) entre deux points.
function G.dist(ax, ay, bx, by)
  local dx, dy = ax - bx, ay - by
  return math.sqrt(dx * dx + dy * dy)
end

--- Le site (centre cx, cy, rayon r) est-il assez loin des sites déjà posés ({x, y, radius}) ?
function G.far_enough(cx, cy, r, placed)
  for _, p in ipairs(placed or {}) do
    local need = r + p.radius + G.SPACING
    local dx, dy = cx - p.x, cy - p.y
    if dx * dx + dy * dy < need * need then return false end
  end
  return true
end

---------------------------------------------------------------------------------------------------
-- Forme du site (positions absolues de tuiles ; listes dans l'ordre des lignes puis des colonnes).
--   tiles : disque du biome, bord irrégulier ;
--   ore   : { x, y, amount } (minerai) ; wells : { x, y, amount } (fluide, `units` puits).
---------------------------------------------------------------------------------------------------
function G.layout(spec, cx, cy, map_seed, units)
  local seed = G.mix(map_seed, spec.seed + 101)
  local R = spec.site_radius
  local tiles = {}
  local span = R + math.ceil(G.EDGE_JITTER)
  for dy = -span, span do
    for dx = -span, span do
      local x, y = cx + dx, cy + dy
      local lim = R + (G.hash(x, y, seed) * 2 - 1) * G.EDGE_JITTER
      if dx * dx + dy * dy <= lim * lim then tiles[#tiles + 1] = { x = x, y = y } end
    end
  end
  local out = { tiles = tiles, ore = {}, wells = {}, total = 0 }
  if spec.kind == "fluid" then
    local n = units or spec.count
    for i = 1, n do
      local off = math.floor((i - (n + 1) / 2) * spec.well_spacing)
      out.wells[#out.wells + 1] = { x = cx + off, y = cy, amount = spec.well_amount, name = spec.resource }
      out.total = out.total + spec.well_amount
    end
  else
    local Ro = spec.ore_radius
    -- Champ (X1-TITANE) : gisement décalé ; quantités tirées des positions ABSOLUES (même hachage qu'avant).
    local ox, oy = 0, 0
    if spec.ore_offset then ox, oy = spec.ore_offset[1], spec.ore_offset[2] end
    for dy = -Ro, Ro do
      for dx = -Ro, Ro do
        local d2 = dx * dx + dy * dy
        if d2 <= Ro * Ro then
          local x, y = cx + ox + dx, cy + oy + dy
          local f = (1 - 0.5 * math.sqrt(d2) / Ro) * (0.9 + 0.2 * G.hash(x, y, seed + 7))
          local a = math.max(1, math.floor(spec.amount * f))
          out.ore[#out.ore + 1] = { x = x, y = y, amount = a, name = spec.resource }
          out.total = out.total + a
        end
      end
    end
    if spec.field_wells then
      -- puits du champ : comptés à part (well_total) ; `total` reste la quantité de MINERAI
      out.well_total = 0
      for _, o in ipairs(spec.field_wells.offsets) do
        out.wells[#out.wells + 1] = { x = cx + o[1], y = cy + o[2], amount = spec.field_wells.amount, name = spec.field_wells.resource }
        out.well_total = out.well_total + spec.field_wells.amount
      end
    end
  end
  return out
end

--- Carré (tuiles) autour d'un centre : { x0, y0, x1, y1 }, bornes incluses.
function G.square(cx, cy, r)
  return { x0 = cx - r, y0 = cy - r, x1 = cx + r, y1 = cy + r }
end

return G
