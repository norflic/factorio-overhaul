--[[
  Scénario GREFFÉ « tv-archi » (lot TV-ARCHI, tranche 1 : V23, enveloppe d'avance ; règle shared/team/quartiers.lua, runtime
  script/team/quartiers.lua). Plan directeur « seul » (le banc tient le rôle du cerveau, comme energie-demande), au plus 2 500 ticks.
  Chaîne prouvée : déclencheur (lots libres des quartiers ouverts < besoin, centrale finie, PNJ inactifs) -> décision ([FO-ENVELOPPE],
  quartier choisi) -> projet « quartier » (plan : poteau, 2 coffres de dépôt, liaison au réseau, arbres du lot en obstacles) -> défrichage
  par les PNJ -> pose -> quartier OUVERT, son poteau sur le réseau de la centrale.

  Terrain : zone de ±140 vidée, herbe ; lac au sud (rive pour la centrale, hors du cœur). Le QG (coffre d'équipe) en (0, 0) : le lot (i, j)
  est le carré de 24 tuiles centré en (28 i, 28 j). Le CŒUR (lots -1..1) est rempli : un coffre en bois de la force du joueur dans 7 des
  8 lots autour du QG (état « occupe ») ; il reste 1 lot libre, sous le besoin minimal (2). Le quartier attendu est (0, -1) (anneau 1, 8
  lots libres, pôle au lot (0, -3), plus petit J à égalité) ; 6 arbres sont posés dans ce lot, hors du centre.
  Le banc pose PAR SCRIPT les entités planifiées des projets arrivés aux fantômes (remote fo-ia1d.quartiers « bench_build ») : les PNJ ne
  font que défricher. Les arbres ne sont jamais touchés par le banc.
  TÉMOIN (tv-archi-temoin, même terrain, fo-war-enveloppe ÉTEINT) : centrale finie, aucun quartier demandé, aucun état créé.
  Lancement : banc.py --qui TV-ARCHI -- 2500 tv-archi <source> ; journal : [FO-TV-ARCHI] du banc, [FO-ENVELOPPE] du mod.
]]

local HALF = 140
local CHECK = 2400
local T_REQUEST = 120
local HUB_LOT = "0:-3"
local HUB = { x0 = -12, y0 = -96, x1 = 12, y1 = -72 }
local TREES = { { -8, -92 }, { -4, -90 }, { 4, -80 }, { 8, -76 }, { 0, -94 }, { -10, -78 } }

local function water_disc(tiles, cx, cy, r)
  for dy = -r, r do
    for dx = -r, r do
      if dx * dx + dy * dy <= r * r then tiles[#tiles + 1] = { name = "water", position = { cx + dx, cy + dy } } end
    end
  end
end

local function shape(ctx)
  local s = ctx.surface()
  s.request_to_generate_chunks({ 0, 0 }, 7)
  s.force_generate_chunk_requests()
  local area = { { -HALF, -HALF }, { HALF, HALF } }
  for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
    if e.valid then e.destroy() end
  end
  local tiles = {}
  for y = -HALF, HALF - 1 do for x = -HALF, HALF - 1 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
  s.set_tiles(tiles, true)
  local water = {}
  water_disc(water, 4, 80, 18)
  s.set_tiles(water, true) -- eau AVANT les entités (F135)
end

local function stock_chest(chest)
  local lost = {}
  for _, it in ipairs({
    { "iron-plate", 1500 }, { "copper-plate", 300 }, { "coal", 1600 }, { "stone", 100 },
    { "transport-belt", 200 }, { "inserter", 60 }, { "burner-inserter", 40 }, { "pipe", 50 },
    { "medium-electric-pole", 120 }, { "small-electric-pole", 100 }, { "iron-chest", 20 },
    { "boiler", 4 }, { "steam-engine", 8 }, { "offshore-pump", 4 }, { "pistol", 4 }, { "firearm-magazine", 100 },
  }) do
    local n = chest.insert({ name = it[1], count = it[2] })
    if n < it[2] then lost[#lost + 1] = it[1] end
  end
  return lost
end

local function status(ctx, id) return id and ctx.remote("fo-ia1d", "status", "player", id) or nil end
local function report(ctx) return ctx.remote("fo-ia1d", "quartiers", "player", "report") end
local BUILD_STATES = { fantomes = true, chantier = true }

return function(temoin)
return {
  description = temoin and "TV-ARCHI TEMOIN : enveloppe d'avance eteinte (fo-war-enveloppe), centrale seule, 2 500 ticks"
    or "TV-ARCHI : quartier ouvert d'avance (poteau relie, depots, lot du pole defriche), 2 500 ticks",
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.check(ctx.call("war_setting", "fo-war-enveloppe", not temoin) == (not temoin), "reglage fo-war-enveloppe " .. (temoin and "ETEINT (temoin)" or "allume"))
    ctx.check(ctx.call("war_setting", "fo-war-ia3e", false) == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)")
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    shape(ctx)
    local nt = 0
    for _, t in ipairs(TREES) do
      if s.create_entity({ name = "tree-01", position = { t[1] + 0.5, t[2] + 0.5 } }) then nt = nt + 1 end
    end
    ctx.check(nt == #TREES, "6 arbres poses dans le lot du pole attendu (0, -3)", nt)
    -- cœur rempli : 7 lots sur 8 autour du QG portent un coffre de la force du joueur (état « occupe »), le lot (1, 0) reste libre
    local nb = 0
    for j = -1, 1 do
      for i = -1, 1 do
        if not (i == 0 and j == 0) and not (i == 1 and j == 0) then
          if s.create_entity({ name = "wooden-chest", position = { 28 * i + 6.5, 28 * j + 6.5 }, force = "player" }) then nb = nb + 1 end
        end
      end
    end
    ctx.check(nb == 7, "7 lots du coeur occupes", nb)
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    local lost = stock_chest(chest)
    ctx.check(#lost == 0, "coffre d'equipe garni en entier", table.concat(lost, ","))
    ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 4 }) == true, "plan directeur active")
    st.t0 = game.tick
    st.built = {}
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local t = e.tick - st.t0
    if t == T_REQUEST then
      st.plant = ctx.remote("fo-ia1d", "request", "player", { gen = "steam", args = { 1 }, feed = true })
      ctx.log(string.format("[FO-TV-ARCHI] centrale demandee au tick %d : projet %s", e.tick, tostring(st.plant)))
    end
    if t % 30 ~= 0 or not st.plant then return end
    -- le banc pose les entités des projets arrivés aux fantômes (centrale, puis quartier)
    local ids = { st.plant }
    local rep = report(ctx)
    for _, k in ipairs(rep and rep.known or {}) do if k.pid then ids[#ids + 1] = k.pid end end
    for _, id in ipairs(ids) do
      local pr = status(ctx, id)
      if pr and BUILD_STATES[pr.state] then
        local n = ctx.remote("fo-ia1d", "quartiers", "player", "bench_build", id)
        if n and n > 0 then
          st.built[id] = (st.built[id] or 0) + n
          ctx.log(string.format("[FO-TV-ARCHI] tick %d : %d entite(s) du projet %d posee(s) par le banc (etat %s)", e.tick, n, id, pr.state))
        end
      end
    end
    local pp = status(ctx, st.plant)
    if pp and pp.state == "fini" and not st.plant_t then
      st.plant_t = t
      ctx.remote("fo-ia1d", "quartiers", "player", "now")
      ctx.log(string.format("[FO-TV-ARCHI] centrale finie au tick %d ; decision des quartiers a la pensee suivante", e.tick))
    end
    for _, k in ipairs(rep and rep.known or {}) do
      if k.open and not st.open_t then
        st.open_t, st.open_key = t, k.key
        ctx.log(string.format("[FO-TV-ARCHI] quartier %s ouvert au tick %d (projet %s, lot %s)", k.key, e.tick, tostring(k.pid), tostring(k.lot)))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local rep = report(ctx)
    local pp = status(ctx, st.plant)
    ctx.check(pp ~= nil and pp.state == "fini", "la centrale est finie (prealable)", pp and (tostring(pp.state) .. " " .. tostring(pp.reason)) or "nil")
    local eng = s.find_entities_filtered({ name = "steam-engine", force = "player", limit = 1 })[1]
    if temoin then
      ctx.check(rep == nil or (rep.on == false and #rep.known == 0), "TEMOIN : reglage eteint, aucun quartier demande",
        rep and (tostring(rep.on) .. "/" .. #rep.known) or "pas d'etat")
      ctx.check(#s.find_entities_filtered({ area = { { HUB.x0, HUB.y0 }, { HUB.x1, HUB.y1 } }, name = "iron-chest" }) == 0, "TEMOIN : aucun coffre de depot au lot (0, -3)")
      ctx.check(#s.find_entities_filtered({ area = { { HUB.x0, HUB.y0 }, { HUB.x1, HUB.y1 } }, type = "tree" }) == #TREES, "TEMOIN : les arbres du lot (0, -3) sont toujours la")
      return
    end
    local k1 = rep and rep.known and rep.known[1]
    ctx.check(rep ~= nil and rep.on == true, "reglage lu allume")
    ctx.check(k1 ~= nil and k1.key == "0:-1" and k1.lot == HUB_LOT, "le quartier (0, -1) est ouvert d'avance, pole au lot (0, -3) (choix : anneau 1, lots libres, J)",
      k1 and (k1.key .. " lot " .. tostring(k1.lot)) or "aucun")
    ctx.check(k1 ~= nil and (k1.obstacles or 0) >= #TREES, "les arbres du lot du pole sont des obstacles du projet", k1 and k1.obstacles or "nil")
    ctx.check(st.open_t ~= nil, "le quartier est OUVERT (projet fini) avant le controle", k1 and (tostring(k1.state) .. " " .. tostring(k1.reason)) or "nil")
    local area = { { HUB.x0, HUB.y0 }, { HUB.x1, HUB.y1 } }
    ctx.check(#s.find_entities_filtered({ area = area, type = "tree" }) == 0, "les 6 arbres du lot du pole sont coupes (par les PNJ)",
      #s.find_entities_filtered({ area = area, type = "tree" }))
    ctx.check(#s.find_entities_filtered({ area = area, name = "iron-chest", force = "player" }) == 2, "2 coffres de depot au lot du pole",
      #s.find_entities_filtered({ area = area, name = "iron-chest", force = "player" }))
    local pole = s.find_entities_filtered({ area = area, type = "electric-pole", force = "player", limit = 1 })[1]
    ctx.check(pole ~= nil and eng ~= nil and pole.electric_network_id == eng.electric_network_id,
      "le poteau du quartier est sur le reseau de la centrale (meme electric_network_id)",
      (pole and pole.electric_network_id or "pas de poteau") .. " / " .. (eng and eng.electric_network_id or "pas de machine"))
    ctx.log(string.format("[FO-TV-ARCHI] BILAN DU PLAN : centrale finie au tick %s, quartier %s ouvert au tick %s, %s entite(s) posee(s) par le banc, lignes [FO-ENVELOPPE] %d",
      tostring(st.plant_t), tostring(st.open_key), tostring(st.open_t), tostring(k1 and st.built[k1.pid] or 0), rep and rep.logs or 0))
  end,
}
end
