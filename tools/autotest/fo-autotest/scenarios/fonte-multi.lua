-- Scénario greffé du lot FONTE-MULTI (8/11) : répétition de la ligne de foreuses sur un gisement. Un seul gisement de fer (disque de
-- rayon 14, environ 600 tuiles), deux demandes de fonderie de fer à 2 280 ticks d'écart (le plan de la première se fait en plusieurs passes), plan directeur seul (aucun PNJ ne bâtit :
-- la mesure porte sur le PLAN, lu à Build.layout). Mesures (zone minée = corps de la foreuse + 1 tuile de portée) :
--   - la ligne 2 ne mine pas par-dessus la ligne 1 : au plus 26 % de son minerai est déjà dans la zone de la ligne 1 (80 % de minerai
--     NEUF sous la zone, 25 % de recouvrement au pire) ; sans le lot (Build.REPETITION = false), la ligne 2 se pose contre la ligne 1 ;
--   - la couverture du gisement par les deux lignes dépasse celle de la ligne 1 seule d'au moins 40 % de plus.
-- Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui FONTE-MULTI -- 6000 fonte-multi <source>   (6 000 ticks, environ 1 min).
-- Journal : [FO-FONTE-MULTI] ; le mod écrit aussi [FO-REPETITION] (lot, minerai restant) au journal du jeu.

local TAG = "FO-FONTE-MULTI"
local CX, CY, R = 56, -28, 14
local HALF = 140
local T_A, T_B = 120, 2400
local CHECK = 5800

local function stock_chest(chest)
  for _, it in ipairs({
    { "iron-plate", 2000 }, { "copper-plate", 600 }, { "coal", 1500 }, { "stone", 200 },
    { "electric-mining-drill", 40 }, { "stone-furnace", 30 }, { "transport-belt", 800 }, { "inserter", 120 },
    { "fast-inserter", 20 }, { "burner-inserter", 10 }, { "medium-electric-pole", 80 }, { "big-electric-pole", 30 },
    { "iron-chest", 20 }, { "boiler", 2 }, { "steam-engine", 4 }, { "offshore-pump", 2 },
  }) do
    chest.insert({ name = it[1], count = it[2] })
  end
end

local function is_ore(tx, ty)
  local dx, dy = tx - CX, ty - CY
  return dx * dx + dy * dy <= R * R
end

return {
  description = "FONTE-MULTI : deux lignes de foreuses sur un meme gisement (plan seul)",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    s.request_to_generate_chunks({ 0, 0 }, 6)
    s.force_generate_chunk_requests()
    local area = { { -HALF, -HALF }, { HALF, HALF } }
    for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
      if e.valid then e.destroy() end
    end
    local tiles = {}
    for y = -HALF, HALF - 1 do for x = -HALF, HALF - 1 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
    s.set_tiles(tiles, true)
    local n = 0
    for dy = -R, R do
      for dx = -R, R do
        if dx * dx + dy * dy <= R * R then
          s.create_entity({ name = "iron-ore", position = { CX + dx + 0.5, CY + dy + 0.5 }, amount = 4000 })
          n = n + 1
        end
      end
    end
    st.field = n
    ctx.log("gisement de fer : " .. n .. " tuile(s)")
    local a = ctx.call("war_setting", "fo-war-ia3e", false)
    ctx.check(a == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)", tostring(a))
    local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    stock_chest(chest)
    local ok = ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 3 })
    ctx.check(ok == true, "plan directeur active")
    st.t0 = game.tick
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local t = e.tick - st.t0
    if t == T_A then
      st.a = ctx.remote("fo-ia1d", "request", "player", { gen = "smelter", args = { "stone-furnace", "iron-ore", 3 }, feed = true })
      ctx.log("demande A : " .. tostring(st.a))
    elseif t == T_B then
      st.b = ctx.remote("fo-ia1d", "request", "player", { gen = "smelter", args = { "stone-furnace", "iron-ore", 3 }, feed = true })
      ctx.log("demande B : " .. tostring(st.b))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.a ~= nil and st.b ~= nil, "les deux demandes ont un numero (A " .. tostring(st.a) .. ", B " .. tostring(st.b) .. ")")
    for _, id in ipairs({ st.a or -1, st.b or -1 }) do
      local sv = ctx.remote("fo-ia1d", "status", "player", id)
      ctx.log(string.format("projet %s : etat %s, raison %s, %d partie(s)", tostring(id), sv and tostring(sv.state) or "?", sv and tostring(sv.reason) or "?", sv and #(sv.parts or {}) or 0))
    end
    local lay = ctx.remote("fo-ia1d", "layout", "player")
    ctx.check(lay ~= nil, "relevé du plan lu")
    if not (lay and st.a and st.b) then return end
    -- zone minée de chaque projet : corps 3 x 3 + 1 tuile de portée (foreuse électrique)
    local zones, ndr = { [st.a] = {}, [st.b] = {} }, { [st.a] = 0, [st.b] = 0 }
    for _, e in ipairs(lay.ents) do
      local z = zones[e.pid]
      if z and e.name == "electric-mining-drill" then
        ndr[e.pid] = ndr[e.pid] + 1
        local tx0, ty0 = math.floor(e.x - 1.5 + 0.01), math.floor(e.y - 1.5 + 0.01)
        for ty = ty0 - 1, ty0 + 3 do for tx = tx0 - 1, tx0 + 3 do z[tx .. "," .. ty] = true end end
      end
    end
    local function ore_of(z)
      local out, n = {}, 0
      for k in pairs(z) do
        local x, y = k:match("^(-?%d+),(-?%d+)$")
        if is_ore(tonumber(x), tonumber(y)) then out[k] = true; n = n + 1 end
      end
      return out, n
    end
    local oa, na = ore_of(zones[st.a])
    local ob, nb = ore_of(zones[st.b])
    local both, overlap = 0, 0
    for k in pairs(ob) do if oa[k] then overlap = overlap + 1 end end
    both = na + nb - overlap
    ctx.log(string.format("ligne A : %d foreuse(s), %d tuile(s) de minerai minees ; ligne B : %d foreuse(s), %d tuile(s) ; recouvrement %d ; A+B %d sur %d (%.0f %%, A seule %.0f %%)",
      ndr[st.a], na, ndr[st.b], nb, overlap, both, st.field, 100 * both / st.field, 100 * na / st.field))
    ctx.check(ndr[st.a] >= 2, "ligne A : au moins 2 foreuses planifiees (" .. ndr[st.a] .. ")")
    ctx.check(ndr[st.b] >= 2, "ligne B : au moins 2 foreuses planifiees (" .. ndr[st.b] .. ")")
    ctx.check(nb > 0 and overlap <= 0.26 * nb, string.format("ligne B : au plus 26 %% de son minerai deja mine par la ligne A (%d sur %d)", overlap, nb))
    ctx.check(both >= 1.4 * na, string.format("A+B couvrent au moins 40 %% de plus que A seule (%d contre %d)", both, na))
  end,
}
