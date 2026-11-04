-- Scénario greffé du lot BI-V1 (1/11) : les souches EN JEU. Moucheron et écraseur à côté des biters vanilla, 16 directions, et le coup de zone de l'écraseur.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui BIV1 -- 1500 bi-v1 <source>
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache" --qui BIV1 -- 1500 bi-v1 <source>
-- Rangée 1 : vanilla (petit, béhémoth), moucheron paliers 1, 4, 8, 12. Rangée 2 : écraseurs des 4 tailles, béhémoth, tourelle. Rangées 3 et 4 : 16 directions de chaque
-- souche, immobiles. Arène : un écraseur (titan) lâché contre un mur ; derrière le mur, à moins de 3 tuiles, une tourelle sans munitions : le coup de zone doit la toucher.
local X0, Y0 = 4600, 3000
local TN = { [1] = "small", [4] = "behemoth", [6] = "titan", [8] = "primordial", [10] = "abyssal", [12] = "eternal" }
local TICK = 1400

local function ecraseur(p) return "fo-crusher-" .. TN[p] .. "-biter" end
local function moucheron(p) return "fo-swarm-" .. ({ [1] = "small", [4] = "behemoth", [8] = "primordial", [12] = "eternal" })[p] .. "-biter" end

local function fige(s, st, nom, x, y, o)
  local u = s.create_entity({ name = nom, position = { x, y }, force = "enemy" })
  if u then
    u.active = false
    pcall(function() u.orientation = o or 0.625 end)
    st.gel[#st.gel + 1] = u
  end
  return u
end

return {
  description = "BI-V1 : moucheron et ecraseur en jeu, a cote des biters vanilla ; coup de zone de l'ecraseur",
  base = nil,
  check_tick = TICK,
  shots_delay = TICK + 20,

  init = function(ctx)
    local s, st = ctx.surface(), ctx.state()
    st.gel = {}
    ctx.prepare_area(X0 - 12, Y0 - 12, X0 + 90, Y0 + 90, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 80, Y0 - 80 }, { X0 + 160, Y0 + 160 } } })) do en.destroy() end
    local p = game.entity_prototypes
    local manque = {}
    for _, t in ipairs({ 6, 8, 10, 12 }) do
      if not p[ecraseur(t)] then manque[#manque + 1] = ecraseur(t) end
    end
    ctx.check(#manque == 0, "les 4 ecraseurs existent", table.concat(manque, " "))
    ctx.check(p["fo-swarm-small-biter"] ~= nil and p["fo-swarm-eternal-biter"] ~= nil, "noms des moucherons inchanges")
    local res = {}
    for _, r in ipairs(game.entity_prototypes["biter-spawner"].result_units) do res[r.unit] = true end
    ctx.check(res[ecraseur(6)] and res[ecraseur(12)], "le nid de dechiqueteurs pond des ecraseurs")

    -- Rangée 1
    fige(s, st, "small-biter", X0, Y0)
    fige(s, st, moucheron(1), X0 + 3, Y0)
    fige(s, st, moucheron(4), X0 + 6, Y0)
    fige(s, st, moucheron(8), X0 + 11, Y0)
    fige(s, st, moucheron(12), X0 + 18, Y0)
    fige(s, st, "behemoth-biter", X0 + 26, Y0)
    -- Rangée 2
    fige(s, st, "small-biter", X0, Y0 + 12)
    fige(s, st, ecraseur(6), X0 + 6, Y0 + 12)
    fige(s, st, ecraseur(8), X0 + 15, Y0 + 12)
    fige(s, st, ecraseur(10), X0 + 26, Y0 + 12)
    fige(s, st, ecraseur(12), X0 + 39, Y0 + 12)
    fige(s, st, "behemoth-biter", X0 + 50, Y0 + 12)
    s.create_entity({ name = "gun-turret", position = { X0 + 55, Y0 + 12 }, force = "player" })
    -- Rangées 3 et 4 : les 16 directions
    for k = 0, 15 do
      fige(s, st, moucheron(4), X0 + k * 4.5, Y0 + 24, k / 16)
      fige(s, st, ecraseur(6), X0 + (k % 8) * 7, Y0 + 36 + math.floor(k / 8) * 8, k / 16)
    end
    ctx.check(#st.gel == 12 + 32, "galerie posee", #st.gel)

    -- Arène du coup de zone
    local ax, ay = X0 + 70, Y0 + 40
    game.forces.enemy.set_cease_fire("player", false)
    game.forces.player.set_cease_fire("enemy", false)
    st.murs = {}
    for dy = -4, 4 do
      st.murs[#st.murs + 1] = s.create_entity({ name = "stone-wall", position = { ax + 0.5, ay + dy + 0.5 }, force = "player" })
    end
    st.derriere = s.create_entity({ name = "gun-turret", position = { ax + 3, ay }, force = "player" })
    st.brute = s.create_entity({ name = ecraseur(6), position = { ax - 8, ay + 0.5 }, force = "enemy" })
    ctx.check(st.brute ~= nil and st.derriere ~= nil, "arene posee")
    if st.brute then
      st.brute.set_command({ type = defines.command.attack, target = st.murs[5], distraction = defines.distraction.none })
    end
    st.pv0 = st.derriere and st.derriere.health
    st.x0 = st.brute and st.brute.position.x
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == 600 and st.brute and st.brute.valid then
      st.x600 = st.brute.position.x
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local vivants = 0
    for _, u in ipairs(st.gel) do if u.valid then vivants = vivants + 1 end end
    ctx.check(vivants == #st.gel, "galerie : toutes les unites sont la", vivants)
    local casses = 0
    for _, m in ipairs(st.murs) do if not m.valid then casses = casses + 1 end end
    ctx.check(st.brute and st.brute.valid, "l'ecraseur est toujours la")
    ctx.check(casses >= 2, "l'ecraseur casse plusieurs murs d'un coup", casses)
    local pv = st.derriere and st.derriere.valid and st.derriere.health or 0
    ctx.check(pv < st.pv0, "le coup de zone touche la tourelle derriere le mur", pv .. " / " .. tostring(st.pv0))
  end,

  shots = function(ctx, add)
    add("rang1-z1", X0 + 13, Y0 - 1, 1, 0, { res = { 1280, 416 }, info = false, aa = true })
    add("rang1-z2", X0 + 4, Y0 - 0.5, 2, 0, { res = { 1280, 416 }, info = false, aa = true })
    add("rang2-z1", X0 + 26, Y0 + 9, 1, 0, { res = { 1980, 640 }, info = false, aa = true })
    add("rang2-z05", X0 + 26, Y0 + 9, 0.5, 0, { res = { 990, 320 }, info = false, aa = true })
    add("nuit-rang2", X0 + 26, Y0 + 9, 1, 0.5, { res = { 1980, 640 }, info = false, aa = true })
    add("moucheron-dirs", X0 + 34, Y0 + 24, 1, 0, { res = { 2340, 180 }, info = false, aa = true })
    add("moucheron-dirs-z2", X0 + 16, Y0 + 24, 2, 0, { res = { 2340, 240 }, info = false, aa = true })
    add("ecraseur-dirs", X0 + 24, Y0 + 39, 1, 0, { res = { 1980, 640 }, info = false, aa = true })
    add("arene", X0 + 66, Y0 + 40, 1, 0, { res = { 800, 500 }, info = false, aa = true })
  end,
}
