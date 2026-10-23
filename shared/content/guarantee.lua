--[[
  Garantie de placement des monnaies d'époque (lot M0, 23/10). Lua PUR : données et règles, testables hors jeu
  (tests/monde_test.lua) ; l'exécution en moteur est dans script/world/guarantee.lua.

  Problème : le tungstène (époque 5), le cristal (7) et le méthane (8) ne viennent que des biomes du mod, placés
  par bruit. Sur une graine sans cendres proches, le centre de commandement ne passe pas l'époque 5. Et dans une
  sauvegarde existante, l'autoplacement ne touche que les chunks NEUFS.

  Règle (une fois par ressource et par partie, sur nauvis) :
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
    sous le cœur, que des tuiles naturelles de terre ferme sous le cœur, loin des autres sites garantis).
]]

local W = require("shared.content.world")
local X = require("shared.content.epochs")

local G = {}

G.MAX_TRIES = 24       -- candidats essayés par site, au plus
G.SPACING = 8          -- tuiles libres au moins entre les disques de deux sites garantis
G.BUILD_MARGIN = 2     -- marge autour du disque où aucun bâtiment d'une force joueur ou IA n'est toléré
G.RESOURCE_MARGIN = 3  -- marge autour du cœur où aucun gisement ne doit déjà exister
G.EDGE_JITTER = 1.5    -- irrégularité du bord du disque de tuiles (en tuiles, ±)

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
local function base_resource(name)
  for _, r in ipairs(X.base_resources) do
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
    for _, key in ipairs(W.resource_order) do
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
      end
      SPECS[#SPECS + 1] = spec
    end
  end
  local copy = {}
  for i, s in ipairs(SPECS) do
    local c = {}
    for k, v in pairs(s) do c[k] = v end
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
function G.units_found(spec, total_amount, entity_count)
  if spec.kind == "fluid" then return entity_count or 0 end
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
function G.ring(spec)
  return spec.dmin + spec.core_radius + 1, spec.dmax - spec.core_radius - 1
end

function G.candidates(map_seed, spec, n)
  local rng = G.rng(G.mix(map_seed, spec.seed))
  for _ = 1, 3 do rng.next() end
  local rmin, rmax = G.ring(spec)
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
      out.wells[#out.wells + 1] = { x = cx + off, y = cy, amount = spec.well_amount }
      out.total = out.total + spec.well_amount
    end
  else
    local Ro = spec.ore_radius
    for dy = -Ro, Ro do
      for dx = -Ro, Ro do
        local d2 = dx * dx + dy * dy
        if d2 <= Ro * Ro then
          local x, y = cx + dx, cy + dy
          local f = (1 - 0.5 * math.sqrt(d2) / Ro) * (0.9 + 0.2 * G.hash(x, y, seed + 7))
          local a = math.max(1, math.floor(spec.amount * f))
          out.ore[#out.ore + 1] = { x = x, y = y, amount = a }
          out.total = out.total + a
        end
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
