--[[ Lot MEGA-FONDERIE, micro-banc de DÉCISION (tranche 1 ; critères K1 et K5 : fo-logs/2026-11-08_MEGA-FONDERIE/CRITERES.md).
  Dispositif :
    1. guerre à 2 factions (Paisible), capitalisation et automatisation allumées, réglage fo-war-mega-fonderie allumé ;
    2. au tick 300, un gisement de fer d'environ 1 000 tuiles (ellipse 25 × 13, les ressources déjà là retirées, l'eau évitée) est posé à
       90 tuiles à l'est du QG de la première faction ; son coffre reçoit les pièces d'une rangée et d'une centrale (comme bras-simples) ;
    3. au tick 600, une rangée d'engrenages (fo-ind row) fait demander la centrale ; le banc en ravive les fantômes et garnit son quai de
       charbon (les PNJ sont trop lents pour un banc court) ;
    4. dès que la centrale est finie : fo-capi bench_mega sur la boîte du gisement (la décision de l'étape 11, sans attendre le cycle),
       puis sur un gisement GÉANT de 1 000 000 tuiles imposées (mesure de coût du pire cas, ligne [FO-MEGA-COUT]) ;
    5. contrôles : centrale finie ; gisement relevé (≥ 900 tuiles) ; décision DECIDE avec au moins 2 lignes de bus et des fours ; décision
       du géant bornée à 12 lignes ; sinon la cause écrite.
  Journal du mod : [FO-MEGA] (décision, taille, voies, fours, cause), [FO-MEGA-COUT] (durée au profileur, banc NON épinglé : indicatif).
  Lancement : banc.py --out <archive> --qui mega-fonderie -- 5000 mega-decision <source>
]]
local CHECK = 4900
local EVERY = 120
local PARTS = { { "assembling-machine-1", 40 }, { "inserter", 80 },
  { "transport-belt", 400 }, { "small-electric-pole", 100 }, { "iron-chest", 20 }, { "wood", 100 },
  { "copper-plate", 400 }, { "iron-plate", 1500 }, { "coal", 400 }, { "offshore-pump", 2 }, { "boiler", 2 }, { "steam-engine", 4 },
  { "pipe", 40 }, { "burner-inserter", 4 }, { "stone-furnace", 60 } }

local function first_team(ctx)
  local out = {}
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key ~= "player" then out[#out + 1] = r end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out[1]
end

local function force_of(key) return game.forces["fo-" .. key] or game.forces[key] end

local function fill_quais(ctx, s, amount)
  for _, q in ipairs((s and s.quais) or {}) do
    local c = ctx.surface().find_entities_filtered({ position = { q.x, q.y }, radius = 0.4, type = "container", limit = 1 })[1]
    if c and c.valid and q.item and c.get_item_count(q.item) < amount then c.insert({ name = q.item, count = amount }) end
  end
end

--- Gisement de fer elliptique (demi-axes a, b) centré en (cx, cy) : ressources déjà là retirées, tuiles d'eau évitées. Rend la boîte et
--- le nombre de tuiles posées.
local function lay_patch(s, cx, cy, a, b)
  local box = { x0 = cx - a - 1, y0 = cy - b - 1, x1 = cx + a + 1, y1 = cy + b + 1, resource = "iron-ore" }
  for _, r in ipairs(s.find_entities_filtered({ area = { { box.x0, box.y0 }, { box.x1, box.y1 } }, type = "resource" })) do r.destroy() end
  local n = 0
  for x = cx - a, cx + a do
    for y = cy - b, cy + b do
      local dx, dy = (x - cx) / a, (y - cy) / b
      if dx * dx + dy * dy <= 1 and not s.get_tile(x, y).collides_with("water-tile") then
        if s.create_entity({ name = "iron-ore", position = { x + 0.5, y + 0.5 }, amount = 5000 }) then n = n + 1 end
      end
    end
  end
  return box, n
end

return {
  description = "MEGA-FONDERIE : decision de la mega-fonderie sur un gisement de 1 000 tuiles, centrale finie (K1, K5)",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    for _, s in ipairs({ { "fo-war-ia3e", true }, { "fo-war-capi", true }, { "fo-war-mega-fonderie", true }, { "fo-war-workers", 30 } }) do
      local v = ctx.call("war_setting", s[1], s[2])
      ctx.check(v == s[2], "reglage " .. s[1] .. " = " .. tostring(s[2]), tostring(v))
    end
    ctx.check(ctx.remote("fo-pvp", "set_difficulty", "peaceful") == true, "difficulte Paisible imposee avant la guerre")
    ctx.check(ctx.call("war_start", 2, 100) == true, "guerre lancee : 2 factions")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if t == 300 then
      local r = first_team(ctx)
      st.key = r and r.key
      local force = st.key and force_of(st.key)
      local hq = force and ctx.surface().find_entities_filtered({ name = "fo-faction-hq", force = force, limit = 1 })[1]
      ctx.check(hq ~= nil, "faction et QG releves (" .. tostring(st.key) .. ")")
      if not hq then return end
      if force.technologies["automation"] then force.technologies["automation"].researched = true end
      st.box, st.tiles = lay_patch(ctx.surface(), math.floor(hq.position.x) + 90, math.floor(hq.position.y), 25, 13)
      ctx.log(string.format("gisement de fer pose : %d tuiles, boite (%d, %d)-(%d, %d)", st.tiles, st.box.x0, st.box.y0, st.box.x1, st.box.y1))
      ctx.check(ctx.remote("fo-ind", "stock", st.key, PARTS) ~= nil, "coffre : pieces de la rangee et de la centrale")
    end
    if not st.key or not st.box then return end
    if t == 600 then
      local id, info = ctx.remote("fo-ind", "row", st.key, "iron-gear-wheel", 30)
      st.row = id
      ctx.log("rangee d'engrenages (pour la centrale) -> " .. tostring(id) .. " (" .. tostring(info) .. ")")
    end
    if t > 600 and t % EVERY == 0 and not st.decided then
      local a = ctx.remote("fo-ia3e", "status", st.key)
      if t % 480 == 0 then
        local ps = a and a.plant and ctx.remote("fo-ia1d", "status", st.key, a.plant)
        local u = ps and ps.unbuilt and ps.unbuilt[1]
        ctx.log(string.format("diag tick %d : plant=%s etat=%s ; projet %s bati %s/%s obstacles ouverts %s ; premier manquant %s", t, tostring(a and a.plant),
          tostring(a and a.plant_state), tostring(ps and ps.state), tostring(ps and ps.built), tostring(ps and ps.total), tostring(ps and ps.open_obstacles),
          u and string.format("%s (%s,%s) echecs %s", u.name, tostring(u.x), tostring(u.y), tostring(u.fails)) or "-"))
      end
      if a and a.plant and a.plant_state ~= "fini" then ctx.remote("fo-ind", "revive", st.key, a.plant) end
      if a and a.plant then fill_quais(ctx, ctx.remote("fo-ia1d", "status", st.key, a.plant), 200) end
      local fin = a and a.plant_state == "fini"
      if fin or t >= CHECK - 200 then
        st.plant_fini = fin and t or nil
        local res = ctx.remote("fo-capi", "bench_mega", st.key, st.box)
        local big = ctx.remote("fo-capi", "bench_mega", st.key, { x0 = st.box.x0, y0 = st.box.y0 + 1000, x1 = st.box.x1, y1 = st.box.y1 + 1000,
          resource = "iron-ore", tiles = 1000000 })
        st.decided = t
        for _, rec in pairs((res and res.deps) or {}) do
          if rec.res == "iron-ore" and (rec.lines or 0) > 0 and not st.rec then st.rec = rec end
        end
        local gid = "banc:iron-ore@" .. st.box.x0 .. "," .. (st.box.y0 + 1000)
        st.big = big and big.deps and big.deps[gid]
        local mid = "banc:iron-ore@" .. st.box.x0 .. "," .. st.box.y0
        st.mine = res and res.deps and res.deps[mid]
        st.power = res and res.power
        ctx.log(string.format("tick %d : centrale %s ; decision 1000 tuiles : %s (%s) ; geant : %s", t, fin and "FINIE" or "pas finie",
          tostring(st.mine and st.mine.state), tostring(st.mine and st.mine.cause), tostring(st.big and st.big.state)))
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local m, g = st.mine, st.big
    ctx.check((st.tiles or 0) >= 900, "gisement pose : au moins 900 tuiles", tostring(st.tiles))
    ctx.check(st.plant_fini ~= nil, "centrale finie avant la decision", tostring(st.plant_fini))
    ctx.check(m ~= nil and m.state == "decide", "K1 : mega-fonderie DECIDEE sur le gisement de 1 000 tuiles",
      m and (tostring(m.state) .. " : " .. tostring(m.cause)) or "aucune decision")
    ctx.check(m ~= nil and (m.lines or 0) >= 2 and (m.furnaces or 0) >= 2 * (m.lines or 0), "decision : au moins 2 lignes de bus et leurs fours",
      m and string.format("%s ligne(s), %s four(s)", tostring(m.lines), tostring(m.furnaces)) or "-")
    ctx.check(g ~= nil and g.state == "decide" and (g.lines or 99) <= 12, "gisement geant : decide, bus borne a 12 lignes",
      g and string.format("%s, %s ligne(s)", tostring(g.state), tostring(g.lines)) or "-")
  end,
}
