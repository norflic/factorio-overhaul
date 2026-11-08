--[[
  Micro-banc « rempl-micro » du lot REMPLISSAGE (8/11) : cible de remplissage d'un quai selon l'abondance du stock, contre le moteur réel.
  Terrain et cadre de piquage-micro (scenarios/piquage_micro_common.lua) : champ en herbe, coffre d'équipe en (0, 0) avec jusqu'a 14 000 plaques
  (stock abondant : plus de 4 fois la cible ordinaire de 400 ; autant que le coffre en tient, jusqu'a 14 000), UN module fini fictif (remote fo-piquage inject) dont le quai d'entrée est le
  coffre (60, 6) (plaque de fer, 1,0/s), le piquage éteint (off). Le quai part à 20 : sous la relance ordinaire (60).
  Attendu : un PNJ porte un plein chargement, le coffre dépasse largement 400 (ancienne cible), et le journal du mod écrit
  « [FO-REMPLISSAGE] ... stock abondant ... cible 0 -> N ». Puis le quai est ramené à 1 200 (sous la relance haute, au-dessus de 60) :
  l'ancienne règle n'aurait rien porté ; la nouvelle porte (relance proportionnelle).
  Lancement : banc.py ... --qui REMPLISSAGE -- 3600 rempl-micro <source> ; journal : [FO-REMPL-MICRO] + [FO-REMPLISSAGE] du mod.
]]

local ITEM = "iron-plate"
local DOCK = { x = 60, y = 6 }
local BUF = 1e8

local function chest_at(s, x, y) return s.find_entities_filtered({ position = { x + 0.5, y + 0.5 }, radius = 0.4, type = "container", limit = 1 })[1] end
local function count_of(s, x, y) local c = chest_at(s, x, y); return c and c.get_item_count(ITEM) or -1 end
local function set_count(s, x, y, n)
  local c = chest_at(s, x, y)
  if not c then return end
  local have = c.get_item_count(ITEM)
  if have > n then c.remove_item({ name = ITEM, count = have - n }) elseif have < n then c.insert({ name = ITEM, count = n - have }) end
end

return {
  description = "REMPLISSAGE : cible d'un quai selon l'abondance du stock (coffre plein, relance proportionnelle)",
  base = nil,
  check_tick = 3400,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    s.request_to_generate_chunks({ 50, 0 }, 5)
    s.force_generate_chunk_requests()
    for _, e in ipairs(s.find_entities_filtered({ area = { { -40, -50 }, { 140, 50 } }, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
      if e.valid then e.destroy() end
    end
    local tiles = {}
    for y = -50, 49 do for x = -40, 139 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
    s.set_tiles(tiles, true)
    ctx.check(ctx.call("war_setting", "fo-war-ia3e", false) == false, "reglage fo-war-ia3e coupe (le banc est le cerveau)")
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    for _, it in ipairs({ { ITEM, 14000 }, { "coal", 200 } }) do chest.insert({ name = it[1], count = it[2] }) end
    st.stock0 = chest.get_item_count(ITEM)
    ctx.check(st.stock0 >= 1600, "stock abondant : au moins 4 fois la cible ordinaire (400)", tostring(st.stock0))
    ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 1 }) == true, "plan directeur active")
    local dock = s.create_entity({ name = "iron-chest", position = { DOCK.x + 0.5, DOCK.y + 0.5 }, force = "player" })
    ctx.check(dock ~= nil, "coffre de quai pose en (60, 6)")
    set_count(s, DOCK.x, DOCK.y, 20)
    local p = ctx.remote("fo-piquage", "inject", "player", { quais = { { x = DOCK.x + 0.5, y = DOCK.y + 0.5, item = ITEM } }, inflow = { [ITEM] = 1.0 },
      names = { arm = "inserter", pole = "small-electric-pole" } })
    ctx.check(p ~= nil, "module fini fictif injecte", tostring(p))
    ctx.check(ctx.remote("fo-piquage", "set_param", "player", "off", true) == true, "piquage eteint (le PNJ porte)")
    st.t0 = game.tick
    st.max, st.log_next = 0, 0
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local s = ctx.surface()
    local t = e.tick - st.t0
    local n = count_of(s, DOCK.x, DOCK.y)
    if n > st.max then st.max = n end
    -- phase 2 : le premier remplissage est fini (coffre au-dessus de 1 500), le quai est ramene a 1 200
    if not st.p2 and n >= 1500 then
      st.p2 = { start = t, before = (ctx.remote("fo-ia1d", "report", "player") or {}).filled or 0, first = n, t_first = t }
      set_count(s, DOCK.x, DOCK.y, 1200)
      ctx.log(string.format("[FO-REMPL-MICRO] t=%d : premier remplissage atteint %d, quai ramene a 1200", t, n))
    end
    if st.p2 and not st.p2.done then
      st.p2.max = math.max(st.p2.max or 0, n)
      if n >= 2000 and t > st.p2.start then st.p2.done, st.p2.t_done = true, t end
    end
    if t % 30 == 0 and t >= st.log_next then
      st.log_next = t + 300
      local rep = ctx.remote("fo-ia1d", "report", "player") or {}
      ctx.log(string.format("[FO-REMPL-MICRO] t=%d : quai %d, max %d, PNJ ont porte %s", t, n, st.max, tostring(rep.filled)))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local rep = ctx.remote("fo-ia1d", "report", "player") or {}
    ctx.check(st.max > 400, "le quai depasse l'ancienne cible de 400 (max " .. tostring(st.max) .. ")")
    ctx.check(st.max >= 1500, "le quai approche sa capacite (max " .. tostring(st.max) .. " sur 3200)")
    ctx.check(st.p2 ~= nil, "phase 2 atteinte")
    if st.p2 then
      if st.stock0 >= 8000 then -- le premier remplissage laisse alors un stock encore abondant (hysteresis : >= 2 x 400)
        ctx.check(st.p2.done == true, "quai a 1200 (sous la relance haute, au-dessus de 60) : un PNJ le recharge au-dela de 2000 (max " .. tostring(st.p2.max) .. ")")
      end
      ctx.log(string.format("[FO-REMPL-MICRO] phase 2 : depart 1200, max %s, recharge %s", tostring(st.p2.max), st.p2.done and ("a t=" .. st.p2.t_done) or "non"))
    end
    ctx.log(string.format("[FO-REMPL-MICRO] BILAN : quai max %d, PNJ ont porte %s", st.max, tostring(rep.filled)))
  end,
}
