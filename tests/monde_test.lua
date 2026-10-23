--[[
  Banc hors jeu du lot M0 (socle du monde) : garantie des monnaies des époques 5, 7 et 8.
  Usage, depuis la racine du mod :   lua5.2 tests/monde_test.lua

  1. Règles pures (shared/content/guarantee.lua) : spécifications tirées des données (X.base_resources,
     world.lua), lien avec les monnaies des niveaux, candidats dans l'anneau sur 2 000 graines, forme des sites
     (quantités, tuiles), déterminisme.
  2. Exécution (script/world/guarantee.lua) dans le moteur simulé (tests/mock_engine.lua) : partie neuve,
     refus (eau, bâtiment, gisement, voisin), échec puis reprise (correction M-1 : paliers, délais, eau comblée,
     joueurs prévenus), sauvegarde existante (gisements connus comptés), filet périodique, étiquettes de carte,
     sérialisabilité de l'état.
  Le moteur réel est prouvé à part : scénarios greffés « monde », « m0-migration » et « m0-reprise » (tools/autotest).
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local G = require("shared.content.guarantee")
local W = require("shared.content.world")
local X = require("shared.content.epochs")
local LV = require("shared.levels.config")

---------------------------------------------------------------------------------------------------
section("Spécifications tirées des données")
---------------------------------------------------------------------------------------------------
local specs = G.specs()
check(#specs == 3, "3 ressources garanties (" .. #specs .. ")")
local expect = { { "tungsten", "fo-tungsten-ore", 5, "ore" }, { "crystal", "fo-resonance-crystal", 7, "ore" },
  { "methane", "fo-methane", 8, "fluid" } }
for i, e in ipairs(expect) do
  local s = specs[i]
  check(s and s.key == e[1] and s.resource == e[2] and s.epoch == e[3] and s.kind == e[4],
    string.format("spécification %d : %s, %s, époque %d, %s", i, e[1], e[2], e[3], e[4]))
  local base
  for _, r in ipairs(X.base_resources) do if r.name == e[2] then base = r end end
  local g = base and base.placement.guaranteed
  check(g and s.count == g.count and s.dmin == g.distance[1] and s.dmax == g.distance[2],
    e[1] .. " : nombre et distances = X.base_resources (" .. tostring(s.count) .. ", " .. tostring(s.dmin) .. "-" .. tostring(s.dmax) .. ")")
  check(W.resources[e[1]].epoch == base.epoch and W.resources[e[1]].kind == s.kind,
    e[1] .. " : époque et genre de world.lua cohérents avec X.base_resources")
  check(s.tile == W.resources[e[1]].biome, e[1] .. " : tuile du site = biome de la ressource (" .. tostring(s.tile) .. ")")
  local biome_ok = false
  for _, b in ipairs(W.biomes) do if b.name == s.tile then biome_ok = true end end
  check(biome_ok, e[1] .. " : le biome existe dans W.biomes")
  check(#s.decoratives >= 3, e[1] .. " : décoratifs du biome régénérés (" .. #s.decoratives .. ")")
  check(s.dmin + s.core_radius + 1 < s.dmax - s.core_radius - 1, e[1] .. " : anneau non vide")
end
check(G.spec("tungsten").resource == "fo-tungsten-ore" and G.spec("inconnu") == nil, "G.spec par clé")
-- Copie fraîche : modifier une spécification rendue ne touche pas la suivante.
specs[1].count = 99
check(G.specs()[1].count == 1, "G.specs rend une copie")

---------------------------------------------------------------------------------------------------
section("Lien avec les monnaies des époques (shared/levels/config.lua)")
---------------------------------------------------------------------------------------------------
local currency = {
  [5] = { item = W.resources.tungsten.plate.item, from = "fo-tungsten-ore" },
  [7] = { item = W.resources.crystal.item, from = "fo-resonance-crystal" },
  [8] = { item = W.resources.methane.fluid .. "-barrel", from = "fo-methane" },
}
for _, ep in ipairs({ 5, 7, 8 }) do
  local m = LV.epoch_materials[ep]
  local c = currency[ep]
  check(m and m.item == c.item, string.format("époque %d : monnaie %s (config : %s)", ep, c.item, tostring(m and m.item)))
  local guaranteed = false
  for _, s in ipairs(G.specs()) do if s.resource == c.from and s.epoch == ep then guaranteed = true end end
  check(guaranteed, string.format("époque %d : sa ressource %s est garantie", ep, c.from))
end

---------------------------------------------------------------------------------------------------
section("Générateur et hachage")
---------------------------------------------------------------------------------------------------
local r = G.rng(0)
check(r.next() == 48271 and r.next() == 182605794, "Park-Miller : suite standard (graine 1 : 48271, 182605794)")
local a, b = G.rng(123), G.rng(123)
local same = true
for _ = 1, 100 do if a.next() ~= b.next() then same = false end end
check(same, "même graine, même suite")
local hmin, hmax = 1, 0
for x = -300, 300, 7 do
  for y = -300, 300, 11 do
    local h = G.hash(x, y, 987654)
    if h < hmin then hmin = h end
    if h > hmax then hmax = h end
  end
end
check(hmin >= 0 and hmax < 1 and hmax - hmin > 0.9, string.format("hachage dans [0, 1) et étalé (%.4f à %.4f)", hmin, hmax))
check(G.hash(-5, 7, 3) == G.hash(-5, 7, 3) and G.hash(-5, 7, 3) ~= G.hash(5, 7, 3), "hachage déterministe, sensible au signe")
check(G.mix(4294967295, 7101) >= 0 and G.mix(4294967295, 7101) < 2147483647, "graine de carte maximale (2^32 - 1) acceptée")

---------------------------------------------------------------------------------------------------
section("Candidats dans l'anneau (2 000 graines)")
---------------------------------------------------------------------------------------------------
for _, s in ipairs(G.specs()) do
  local rmin, rmax = G.ring(s)
  local bad, n, near, far = 0, 0, math.huge, 0
  local quadrant = { 0, 0, 0, 0 }
  for seed = 1, 2000 do
    local cands = G.candidates(seed * 2654435 % 4294967296, s, G.MAX_TRIES)
    for _, c in ipairs(cands) do
      local d = math.sqrt(c.x * c.x + c.y * c.y)
      n = n + 1
      if d < near then near = d end
      if d > far then far = d end
      -- Tout le cœur (gisement ou puits) dans [dmin, dmax] : l'arrondi à la tuile est couvert par la marge de 1.
      if d - s.core_radius < s.dmin or d + s.core_radius > s.dmax then bad = bad + 1 end
      local q = (c.x >= 0 and 1 or 2) + (c.y >= 0 and 0 or 2)
      quadrant[q] = quadrant[q] + 1
    end
  end
  check(bad == 0, string.format("%s : %d candidats, tous dans l'anneau %d-%d (cœur %d) ; de %.1f à %.1f", s.key, n, s.dmin, s.dmax, s.core_radius, near, far))
  local qmin, qmax = math.min(table.unpack(quadrant)), math.max(table.unpack(quadrant))
  check(qmin > 0.22 * n and qmax < 0.28 * n, string.format("%s : directions réparties (quadrants %d %d %d %d)", s.key, quadrant[1], quadrant[2], quadrant[3], quadrant[4]))
  local c1 = G.candidates(20261020, s, 5)
  local c2 = G.candidates(20261020, s, 5)
  local c3 = G.candidates(20261021, s, 5)
  local eq, diff = true, false
  for i = 1, 5 do
    if c1[i].x ~= c2[i].x or c1[i].y ~= c2[i].y then eq = false end
    if c1[i].x ~= c3[i].x or c1[i].y ~= c3[i].y then diff = true end
  end
  check(eq and diff, s.key .. " : candidats déterministes (même graine) et propres à la graine")
end
-- Deux ressources sur la même carte : tirages différents (graines propres, autoplace.seed1).
local t1, c1 = G.candidates(42, G.spec("tungsten"), 1)[1], G.candidates(42, G.spec("crystal"), 1)[1]
check(t1.x ~= c1.x or t1.y ~= c1.y, "tungstène et cristal : premiers candidats différents")

---------------------------------------------------------------------------------------------------
section("Reprise après échec : paliers, délais, autres candidats")
---------------------------------------------------------------------------------------------------
do
  local r0, r1, r2, r3, r9 = G.rules(0), G.rules(1), G.rules(2), G.rules(3), G.rules(9)
  check(r0.level == 0 and not r0.fill_water and r0.dmax_scale == 1 and r1.level == 1 and not r1.fill_water,
    "niveaux 0 et 1 : critères stricts (eau refusée, anneau des données)")
  check(r2.level == 2 and r2.fill_water and r2.water_share == G.WATER_SHARE and r2.dmax_scale == 1, "niveau 2 : eau du bord tolérée et comblée")
  check(r3.level == 3 and r3.fill_water and r3.dmax_scale == 1 + G.RING_STRETCH and r9.level == G.MAX_LEVEL, "niveau 3 et suivants : anneau allongé")
  check(G.retry_delay(1) == 600 and G.retry_delay(2) == 1200 and G.retry_delay(3) == 2400 and G.retry_delay(6) == 19200
    and G.retry_delay(7) == G.RETRY_MAX and G.retry_delay(1000) == G.RETRY_MAX, "délais de reprise : 600, 1200, 2400... au plus " .. G.RETRY_MAX)
  check(G.ground_verdict(r0, 10, 0, 0) == nil and G.ground_verdict(r0, 9, 1, 0) == "sol" and G.ground_verdict(r2, 6, 4, 0) == nil
    and G.ground_verdict(r2, 4, 6, 0) == "eau" and G.ground_verdict(r9, 10, 0, 1) == "sol",
    "sol : eau refusée aux niveaux 0-1, tolérée jusqu'à " .. G.WATER_SHARE .. " ensuite ; dalle jamais tolérée")
  local s = G.spec("tungsten")
  local base, a0, a1, a2 = G.candidates(42, s, 24), G.candidates(42, s, 24, 0), G.candidates(42, s, 24, 1), G.candidates(42, s, 24, 2)
  local same0, same1, same12 = true, 0, 0
  for i = 1, 24 do
    if base[i].x ~= a0[i].x or base[i].y ~= a0[i].y then same0 = false end
    for j = 1, 24 do
      if a1[i].x == base[j].x and a1[i].y == base[j].y then same1 = same1 + 1 end
      if a1[i].x == a2[j].x and a1[i].y == a2[j].y then same12 = same12 + 1 end
    end
  end
  check(same0, "essai 0 : suite d'origine inchangée (parties et bancs existants)")
  check(same1 == 0 and same12 == 0, "essais 1 et 2 : autres candidats (" .. same1 .. ", " .. same12 .. " en commun)")
  for _, sp in ipairs(G.specs()) do
    local bad, far = 0, 0
    local dmax3 = G.dmax(sp, 3)
    for seed = 1, 200 do
      for _, c in ipairs(G.candidates(seed * 7919, sp, G.MAX_TRIES, 3)) do
        local d = math.sqrt(c.x * c.x + c.y * c.y)
        if d - sp.core_radius < sp.dmin or d + sp.core_radius > dmax3 then bad = bad + 1 end
        if d + sp.core_radius > sp.dmax then far = far + 1 end
      end
    end
    check(bad == 0 and far > 0 and dmax3 == math.floor(sp.dmax * 1.5),
      string.format("%s : essai 3, candidats dans l'anneau allongé %d-%d (%d au-delà de %d)", sp.key, sp.dmin, dmax3, far, sp.dmax))
  end
end

---------------------------------------------------------------------------------------------------
section("Forme des sites")
---------------------------------------------------------------------------------------------------
for _, s in ipairs(G.specs()) do
  local L = G.layout(s, 300, -200, 20261020, s.count)
  local in_disc = {}
  for _, t in ipairs(L.tiles) do in_disc[t.x .. "," .. t.y] = true end
  local R = s.site_radius
  local area = math.pi * R * R
  check(#L.tiles > 0.8 * area and #L.tiles < 1.25 * area, string.format("%s : disque de biome de %d tuiles (pi r² = %.0f)", s.key, #L.tiles, area))
  local list = s.kind == "fluid" and L.wells or L.ore
  local outside, total = 0, 0
  for _, o in ipairs(list) do
    if not in_disc[o.x .. "," .. o.y] then outside = outside + 1 end
    total = total + o.amount
  end
  check(outside == 0, s.key .. " : tout le gisement est sur le biome posé")
  check(total == L.total, s.key .. " : total = somme des quantités")
  if s.kind == "fluid" then
    check(#L.wells == s.count, string.format("%s : %d puits", s.key, #L.wells))
    local okgap = true
    for i = 2, #L.wells do if math.abs(L.wells[i].x - L.wells[i - 1].x) < 3 then okgap = false end end
    check(okgap, s.key .. " : puits espacés d'au moins 3 tuiles (chevalet 3×3)")
    check(#G.layout(s, 0, 0, 1, 1).wells == 1, s.key .. " : un seul puits si une seule unité manque")
    local maxoff = 0
    for _, w in ipairs(L.wells) do maxoff = math.max(maxoff, math.abs(w.x - 300) + 1) end
    check(maxoff <= s.core_radius, s.key .. " : chevalets dans le cœur (" .. maxoff .. " <= " .. s.core_radius .. ")")
  else
    local minA, maxA = math.huge, 0
    for _, o in ipairs(L.ore) do minA = math.min(minA, o.amount); maxA = math.max(maxA, o.amount) end
    check(L.total >= s.min_total * 1.5, string.format("%s : %d minerais sur %d tuiles (>= 1,5 × min_total %d)", s.key, L.total, #L.ore, s.min_total))
    check(minA >= 1 and maxA <= s.amount * 1.1 and minA < maxA, string.format("%s : quantités de %d à %d par tuile", s.key, minA, maxA))
  end
  -- Même entrée, même site ; autre graine : bord différent.
  local L2 = G.layout(s, 300, -200, 20261020, s.count)
  local L3 = G.layout(s, 300, -200, 7, s.count)
  check(#L2.tiles == #L.tiles and L2.total == L.total, s.key .. " : forme déterministe")
  check(#L3.tiles ~= #L.tiles or L3.total ~= L.total or s.kind == "fluid", s.key .. " : forme propre à la graine")
end

---------------------------------------------------------------------------------------------------
section("Décision : unités trouvées, à poser")
---------------------------------------------------------------------------------------------------
local T, M2 = G.spec("tungsten"), G.spec("methane")
check(G.units_found(T, 99999, 50) == 0 and G.units_found(T, 100000, 1) == 1 and G.units_found(T, 350000, 900) == 3, "minerai : unités = quantité / min_total")
check(G.units_to_place(T, 0) == 1 and G.units_to_place(T, 1) == 0 and G.units_to_place(T, 4) == 0, "minerai : une unité à poser si aucune n'est connue")
check(G.units_found(M2, 0, 1) == 1 and G.units_to_place(M2, 1) == 1 and G.units_to_place(M2, 2) == 0, "fluide : unités = puits")
check(G.sites_for(T, 2) == 2 and G.sites_for(M2, 2) == 1 and G.sites_for(M2, 0) == 0, "sites : un par unité de minerai, un seul pour les puits")
check(G.far_enough(0, 0, 10, { { x = 40, y = 0, radius = 10 } }) and not G.far_enough(0, 0, 10, { { x = 25, y = 0, radius = 10 } }),
  "écart entre sites : rayon + rayon + " .. G.SPACING)

---------------------------------------------------------------------------------------------------
-- 2. Exécution dans le moteur simulé
---------------------------------------------------------------------------------------------------
local ME = require("tests.mock_engine")
local function world() return ME.world() end

local function logs_with(pattern)
  local out = {}
  for _, l in ipairs(world().logs) do if l:find(pattern, 1, true) then out[#out + 1] = l end end
  return out
end

local function patches_named(name)
  local n, amount = 0, 0
  for _, p in ipairs(world().patches) do
    if p.name == name then n = n + 1; amount = amount + (p.amount or 0) end
  end
  return n, amount
end

section("Partie neuve (on_init au tick 0)")
ME.new_game({ seed = 20261020 })
local st = global.fo.world
check(st and st.runs == 1, "une passe de garantie à la création")
for _, s in ipairs(G.specs()) do
  local d = st.done[s.key]
  check(d and d.phase == "init" and d.ok and d.check_natural == false and d.to_place == s.count,
    s.key .. " : posée à la création, sans compter les gisements connus")
  local site = d and d.sites[1]
  check(site and site.try == 1 and site.dist >= s.dmin and site.dist <= s.dmax, s.key .. " : premier candidat retenu, dans l'anneau (" .. tostring(site and site.dist) .. ")")
  local c1 = G.candidates(20261020, s, 1)[1]
  check(site and site.x == c1.x and site.y == c1.y, s.key .. " : position = candidat 1 de la graine")
  local _, amount = patches_named(s.resource)
  check(site and amount == site.total and site.entities == (s.kind == "fluid" and s.count or #G.layout(s, site.x, site.y, 20261020, 1).ore),
    s.key .. " : gisement posé (" .. tostring(amount) .. ")")
  check(site and world().tile_override[site.x .. "," .. site.y] == s.tile, s.key .. " : tuile du biome au centre du site")
end
check(#logs_with("[FO-MONDE] garanties (init") == 1, "une ligne de journal pour la passe")
check(#st.tags == 0, "étiquettes de carte posées tout de suite (moteur simulé : chunk toujours cartographié)")
check(world().decor_regenerated and world().decor_regenerated > 0, "décoratifs des biomes régénérés")
local rows = 0
for _, a in ipairs(world().decoratives_cleared or {}) do
  if a[2][2] - a[1][2] == 1 then rows = rows + 1 end
end
check(rows >= 3 * 10, "décor vanilla retiré des disques, ligne par ligne (" .. rows .. " lignes)")
local saved = ME.serialize and ME.serialize(global) or nil
check(saved == nil or type(saved) == "string", "état sérialisable (aucune fonction dans global)")
-- Rien n'est refait : configuration changée, filet.
local runs0 = st.runs
ME.dispatch(world().on_config, { mod_changes = {} })
ME.dispatch(world().nth[600], { tick = 600 })
check(global.fo.world.runs == runs0, "configuration changée et filet : rien n'est refait")

section("Refus : eau, bâtiment, gisement, voisin")
do
  local s = G.spec("tungsten")
  local cands = G.candidates(5, s, 6)
  local water_c, build_c, res_c = cands[1], cands[2], cands[3]
  ME.new_world({ seed = 5, tile_at = function(x, y)
    if math.abs(x - water_c.x) <= 2 and math.abs(y - water_c.y) <= 2 then return "water" end
    return "grass-1"
  end })
  ME.load_mod()
  -- Bâtiment du joueur sur le candidat 2, gisement de fer sur le candidat 3.
  ME.new_entity("iron-chest", build_c.x + 5.5, build_c.y + 0.5, game.surfaces[1], game.forces.player)
  world().patches[#world().patches + 1] = { x = res_c.x + 2, y = res_c.y, name = "iron-ore" }
  ME.dispatch(world().on_init)
  local d = global.fo.world.done.tungsten
  check(d and d.ok and d.sites[1].try == 4, "tungstène : candidat 4 retenu (" .. tostring(d and d.sites[1] and d.sites[1].try) .. ")")
  check(d and table.concat(d.rejected, ",") == "1:sol,2:batiment,3:gisement", "motifs : " .. tostring(d and table.concat(d.rejected, ",")))
  local wet = world().tile_override[water_c.x .. "," .. water_c.y]
  check(wet == nil, "l'eau du candidat 1 n'est pas touchée")
  -- Voisin : le cristal ne se pose pas sur le site du tungstène.
  local placed = {}
  for _, k in ipairs({ "tungsten", "crystal", "methane" }) do
    local site = global.fo.world.done[k].sites[1]
    placed[#placed + 1] = { x = site.x, y = site.y, r = G.spec(k).site_radius }
  end
  local apart = true
  for i = 1, #placed do
    for j = i + 1, #placed do
      if G.dist(placed[i].x, placed[i].y, placed[j].x, placed[j].y) < placed[i].r + placed[j].r + G.SPACING then apart = false end
    end
  end
  check(apart, "les trois sites sont disjoints (écart >= rayons + " .. G.SPACING .. ")")
end
do
  -- Voisin forcé : un site déjà posé exactement sur le candidat 1 du cristal.
  local s = G.spec("crystal")
  local c1 = G.candidates(9, s, 1)[1]
  ME.new_world({ seed = 9 })
  ME.load_mod()
  local surface = game.surfaces[1]
  local Guarantee = require("script.world.guarantee")
  local rep = Guarantee.apply(surface, { x = 0, y = 0 }, { keys = { "crystal" }, placed = { { x = c1.x, y = c1.y, radius = 10 } } })
  local res = rep.results[1]
  check(#rep.results == 1 and res.key == "crystal" and res.rejected[1] == "1:voisin" and res.sites[1].try == 2, "cristal : candidat 1 refusé (voisin), candidat 2 retenu")
end
section("Échec puis reprise (correction M-1 : un échec n'est jamais définitif)")
do
  -- Carte tout en eau : les 24 candidats sont refusés pour les 3 ressources.
  ME.new_world({ seed = 11, tile_at = function() return "water" end })
  ME.load_mod()
  ME.dispatch(world().on_init)
  local w = global.fo.world
  local all_sol = true
  for _, k in ipairs({ "tungsten", "crystal", "methane" }) do
    local f = w.fails[k]
    check(w.done[k] == nil, k .. " : échec à on_init, la ressource n'est PAS marquée traitée")
    check(f and f.count == 1 and f.next_tick == G.RETRY_BASE and #f.history == 1 and f.history[1].attempt == 0,
      k .. " : 1 échec compté, reprise au tick " .. G.RETRY_BASE .. " (" .. tostring(f and f.next_tick) .. ")")
    for _, r in ipairs(f and f.history[1].rejected or {}) do if not r:find(":sol$") then all_sol = false end end
    check(f and #f.history[1].rejected == G.MAX_TRIES, k .. " : " .. G.MAX_TRIES .. " candidats refusés")
  end
  check(all_sol, "niveau 0 : tous refusés pour le sol (eau)")
  local prints = 0
  for _, p in ipairs(world().game_prints) do if p:find("fo-monde.site-echec", 1, true) then prints = prints + 1 end end
  check(prints == 3, "joueurs prévenus : un message par ressource échouée (" .. prints .. ")")
  check(#logs_with("ECHEC : aucun candidat valable, joueurs prevenus") == 1, "échec écrit au journal (une ligne par passe)")
  -- Niveau 2 sur l'eau pure : refus « eau » (plus de WATER_SHARE d'eau sous le cœur), rien posé.
  local Guarantee = require("script.world.guarantee")
  local rep = Guarantee.apply(game.surfaces[1], { x = 0, y = 0 }, { keys = { "tungsten" }, attempts = { tungsten = 2 } })
  check(rep.results[1].ok == false and rep.results[1].rejected[1] == "1:eau" and rep.results[1].level == 2,
    "niveau 2, carte tout en eau : refus « eau » (" .. tostring(rep.results[1].rejected[1]) .. ")")
  -- Filet au tick 600 : essai 1 (autres candidats), encore de l'eau : 2e échec, délai doublé.
  game.tick = 600
  ME.dispatch(world().nth[600], { tick = 600 })
  local f = global.fo.world.fails.tungsten
  check(global.fo.world.runs == 2 and f.count == 2 and f.next_tick == 600 + 2 * G.RETRY_BASE and f.history[2].attempt == 1 and f.history[2].level == 1,
    "filet (tick 600) : essai 1, niveau 1 ; 2e échec, reprise au tick " .. (600 + 2 * G.RETRY_BASE) .. " (" .. tostring(f.next_tick) .. ")")
  -- Tick 1200 : délai non écoulé, rien n'est rejoué (coût : la boucle sur 3 clés).
  game.tick = 1200
  ME.dispatch(world().nth[600], { tick = 1200 })
  check(global.fo.world.runs == 2, "filet (tick 1200) : délai non écoulé, aucune passe")
  -- La côte : un tiers d'eau sous chaque candidat (aucun n'est valable aux niveaux 0 et 1, tous au niveau 2).
  local function coast(x, y) return (x + y) % 3 == 0 and "water" or "grass-1" end
  world().tile_at = coast
  game.tick = 1800
  ME.dispatch(world().nth[600], { tick = 1800 })
  w = global.fo.world
  check(w.runs == 3, "filet (tick 1800) : reprise")
  for _, k in ipairs({ "tungsten", "crystal", "methane" }) do
    local d = w.done[k]
    local s = G.spec(k)
    local site = d and d.sites[1]
    check(d and d.ok and d.phase == "filet" and d.attempt == 2 and d.level == 2 and #d.failures == 2 and w.fails[k] == nil,
      k .. " : réussie à l'essai 2 (niveau 2, eau du bord comblée), 2 échecs gardés dans l'historique")
    check(site and site.filled > 0, k .. " : eau comblée sous le site (" .. tostring(site and site.filled) .. " tuiles)")
    local wet = 0
    if site then
      for _, t in ipairs(G.layout(s, site.x, site.y, 11, 1).tiles) do
        local name = world().tile_override[t.x .. "," .. t.y] or coast(t.x, t.y)
        if name == "water" then wet = wet + 1 end
      end
    end
    check(site and wet == 0, k .. " : plus aucune tuile d'eau dans le disque du site (" .. wet .. ")")
    local _, amount = patches_named(s.resource)
    check(site and amount == site.total and amount > 0, k .. " : gisement posé (" .. tostring(amount) .. ")")
  end
  local poses = 0
  for _, p in ipairs(world().game_prints) do if p:find("fo-monde.site-pose", 1, true) then poses = poses + 1 end end
  check(poses == 3, "joueurs prévenus des 3 sites posés à la reprise (" .. poses .. ")")
  game.tick = 2400
  ME.dispatch(world().nth[600], { tick = 2400 })
  check(global.fo.world.runs == 3, "après la réussite : plus rien n'est rejoué")
end
do
  -- on_configuration_changed reprend un échec sans attendre son délai.
  ME.new_world({ seed = 12, tile_at = function() return "water" end })
  ME.load_mod()
  ME.dispatch(world().on_init)
  game.tick = 100
  ME.dispatch(world().on_config, { mod_changes = {} })
  local f = global.fo.world.fails.crystal
  check(f and f.count == 2 and f.history[2].phase == "config" and f.history[2].attempt == 1, "configuration changée : échec repris tout de suite (essai 1)")
  -- État d'avant la correction (développement du lot : « ok = faux » marqué traité, pas de fails) : repris.
  global.fo.world.fails = nil
  global.fo.world.done.crystal = { ok = false, sites = {}, rejected = {} }
  world().tile_at = function() return "grass-1" end
  game.tick = 600
  ME.dispatch(world().nth[600], { tick = 600 })
  local d = global.fo.world.done.crystal
  check(d and d.ok and d.phase == "filet" and #d.sites == 1, "ancien état « ok = faux » : repris par le filet")
end

section("Sauvegarde existante (on_configuration_changed) et filet")
do
  -- Une partie d'avant M0 : pas d'espace « world ». Du tungstène naturel suffisant à 300 tuiles, un seul puits de
  -- méthane à 400, rien pour le cristal.
  ME.new_game({ seed = 77 })
  global.fo.world = nil
  world().patches = {
    { x = 300, y = 0, name = "fo-tungsten-ore", amount = 150000 },
    { x = 0, y = 400, name = "fo-methane", amount = 450000 },
  }
  game.tick = 5000
  ME.dispatch(world().on_config, { mod_changes = { ["factorio-overhaul"] = { old_version = "0.4.4", new_version = "0.4.5" } } })
  local w = global.fo.world
  local dt, dc, dm = w.done.tungsten, w.done.crystal, w.done.methane
  check(dt and dt.phase == "config" and dt.check_natural and dt.found == 1 and dt.to_place == 0 and #dt.sites == 0,
    "tungstène connu (150 000) : rien posé (" .. tostring(dt and dt.found_total) .. ")")
  check(dc and dc.found == 0 and dc.to_place == 1 and #dc.sites == 1, "cristal absent : un site posé")
  -- Moteur simulé : 25 entités par gisement ponctuel ; le vrai moteur a un puits par entité.
  check(dm and dm.found == 25 and dm.to_place == 0, "méthane : unités = entités trouvées (moteur simulé : 25 par gisement)")
  check(w.runs == 1, "une seule passe")
  check(#world().game_prints >= 1 and world().game_prints[#world().game_prints]:find("fo-monde.site-pose", 1, true),
    "message aux joueurs pour chaque site posé")
end
do
  -- Filet : mod mis à jour sans montée de version ni changement de prototypes (on_configuration_changed absent).
  ME.new_game({ seed = 78 })
  global.fo.world.done.crystal = nil
  local runs0 = global.fo.world.runs
  ME.dispatch(world().nth[600], { tick = 600 })
  local w = global.fo.world
  check(w.runs == runs0 + 1 and w.done.crystal and w.done.crystal.phase == "filet", "filet : la ressource manquante est traitée")
  check(w.done.tungsten.phase == "init", "filet : les autres ne sont pas refaites")
  -- Espace absent (global.fo.world effacé) : recréé par le filet.
  global.fo.world = nil
  ME.dispatch(world().nth[600], { tick = 1200 })
  check(global.fo.world and global.fo.world.runs == 1 and global.fo.world.done.methane, "filet : espace « world » recréé et garanties posées")
end

section("Étiquettes de carte en attente")
do
  ME.new_world({ seed = 31 })
  ME.load_mod()
  local f = game.forces.player
  local real_tag = f.add_chart_tag
  f.add_chart_tag = function() return nil end -- chunk pas encore cartographié
  ME.dispatch(world().on_init)
  local w = global.fo.world
  check(#w.tags == 3, "3 étiquettes en attente (une par site) : " .. #w.tags)
  f.add_chart_tag = real_tag
  local t = w.tags[1]
  local ev = defines.events.on_chunk_charted
  ME.dispatch(world().events[ev], { surface_index = 1, force = game.forces.enemy, position = { x = t.cx, y = t.cy } })
  check(#global.fo.world.tags == 3, "force ennemie : rien")
  ME.dispatch(world().events[ev], { surface_index = 1, force = f, position = { x = t.cx + 50, y = t.cy } })
  check(#global.fo.world.tags == 3, "autre chunk : rien")
  ME.dispatch(world().events[ev], { surface_index = 1, force = f, position = { x = t.cx, y = t.cy } })
  check(#global.fo.world.tags == 2, "chunk du site cartographié : étiquette posée et retirée de l'attente")
end

section("Interface distante fo-monde")
do
  ME.new_game({ seed = 20261020 })
  local st2 = remote.call("fo-monde", "status")
  check(st2.runs == 1 and #st2.done == 3 and st2.done[1].key == "tungsten" and st2.tags_pending == 0, "status : 3 garanties, ordre des époques")
  local c = remote.call("fo-monde", "candidates", "nauvis", "crystal", 3)
  local g = G.candidates(20261020, G.spec("crystal"), 3)
  check(#c == 3 and c[2].x == g[2].x and c[2].y == g[2].y, "candidates : ceux de la règle pure")
  check(#remote.call("fo-monde", "specs") == 3, "specs")
end

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
