--[[
  EFFONDREMENT, banc comparé de la parade du kit offert : la recrue PAYÉE à part (correctif du banc recrue-kit, 7/11 21:43 : après le
  campeur, le filet de recul garde son attente 5 min, l'effectif ne remonte pas à 12 dans la fenêtre, donc jamais de croissance payée).
  Effectif de départ 12 ; coffre d'équipe avec 2 000 plaques de fer et 5 pistolets dès la mise en place ; ni mise à mort au départ ni
  campeur. La première recrue vue à 13 personnages ou plus (recrue de CROISSANCE, payée : script/team/team.lua, grow_due) meurt 300 ticks
  après son apparition ; au même tick, un PNJ de départ (kit offert) meurt aussi. Critères ÉCRITS AVANT :
  fo-logs/2026-11-05_EFFONDREMENT/CRITERES.md, « recrue-kit-payee ».
  Lancement (par la file) : banc.py --out <archive> --qui EFFONDREMENT -- 6000 recrue-kit-payee <source>
]]

local CHECK = 5900
local PAID_MAX = 5500
local START = 12
local GUN, AMMO = "pistol", "firearm-magazine"
local TAG = "RECRUE-KIT-PAYEE"

local function chest_of(ctx)
  return ctx.surface().find_entities_filtered({ name = "fo-team-chest", force = "player", limit = 1 })[1]
end

local function team(ctx)
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key == "player" then return r end
  end
  return nil
end

local function workers(ctx)
  local list = {}
  for _, c in ipairs(ctx.surface().find_entities_filtered({ type = "character", force = "player" })) do
    if c.valid and not c.player then list[#list + 1] = c end
  end
  table.sort(list, function(a, b) return (a.unit_number or 0) < (b.unit_number or 0) end)
  return list
end

--- Corps morts au tick `td`, chacun attribué à la position la plus proche (payee ou depart) : { paid = {n, gun, ammo}, free = {...} }.
local function corpses_split(ctx, td, pp, fp)
  local out = { paid = { n = 0, gun = 0, ammo = 0 }, free = { n = 0, gun = 0, ammo = 0 } }
  local function d2(a, b) return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 end
  for _, c in ipairs(ctx.surface().find_entities_filtered({ type = "character-corpse" })) do
    if c.valid and c.character_corpse_tick_of_death == td then
      local side = (pp and (not fp or d2(c.position, pp) <= d2(c.position, fp))) and out.paid or out.free
      local inv = c.get_inventory(defines.inventory.character_corpse)
      side.n, side.gun, side.ammo = side.n + 1, side.gun + inv.get_item_count(GUN), side.ammo + inv.get_item_count(AMMO)
    end
  end
  return out
end

local function text(c) return string.format("%d corps, pistolets %d, chargeurs %d", c.n, c.gun, c.ammo) end

return {
  description = "EFFONDREMENT : le corps d'une recrue PAYEE garde son kit ; celui d'un PNJ au kit offert le perd (meme tick)",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", START) == START, "effectif de depart " .. START)
    local s = ctx.surface()
    local c0 = game.forces.player.get_spawn_position(s)
    local p = s.find_non_colliding_position("fo-team-chest", { x = c0.x + 6, y = c0.y + 6 }, 20, 1)
    local chest = s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    local inv = chest.get_inventory(defines.inventory.chest)
    inv.insert({ name = "iron-plate", count = 2000 })
    inv.insert({ name = GUN, count = 5 })
    inv.insert({ name = "copper-plate", count = 500 })
    inv.insert({ name = "coal", count = 200 })
    inv.insert({ name = AMMO, count = 194 })
    local r = team(ctx)
    ctx.check(r ~= nil and r.n == START, "equipe creee a " .. START .. " PNJ", tostring(r and r.n))
    st.ok = true
    st.initial = {}
    for _, c in ipairs(workers(ctx)) do st.initial[c.unit_number or 0] = true end
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.ok or st.done then return end
    local t = e.tick
    local list = workers(ctx)
    -- (l'équipe naît avec le coffre posé : les 12 de départ sont relevés à l'init ; un PNJ de départ relevé plus tard y entre aussi)
    if t <= 60 then
      for _, c in ipairs(list) do st.initial[c.unit_number or 0] = true end
      return
    end
    if not st.paid and #list >= START + 1 then
      local best = nil
      for _, c in ipairs(list) do
        local u = c.unit_number or 0
        if not st.initial[u] and (not best or u > best) then best = u end
      end
      if best then
        st.paid = { unit = best, at = t }
        ctx.log(string.format("[FO-%s] recrue payee vue au tick %d : unite %d, %d personnages", TAG, t, best, #list))
      end
    end
    if st.paid and not st.killed and t - st.paid.at >= 300 then
      local paid_ent, free_ent = nil, nil
      for _, c in ipairs(list) do
        local u = c.unit_number or 0
        if u == st.paid.unit then paid_ent = c end
        if st.initial[u] and not free_ent then free_ent = c end
      end
      st.killed = t
      if paid_ent then
        st.paid_pos = { x = paid_ent.position.x, y = paid_ent.position.y }
        paid_ent.die()
      end
      if free_ent then
        st.free_pos = { x = free_ent.position.x, y = free_ent.position.y }
        st.free_unit = free_ent.unit_number
        free_ent.die()
      end
      ctx.log(string.format("[FO-%s] tick %d : recrue payee %s et PNJ de depart %s tues", TAG, t, tostring(paid_ent ~= nil), tostring(st.free_unit)))
    end
    if st.killed and t == st.killed + 30 then
      local sp = corpses_split(ctx, st.killed, st.paid_pos, st.free_pos)
      st.s_paid, st.s_free = sp.paid, sp.free
      ctx.log(string.format("[FO-%s] corps de la recrue payee : %s ; corps du PNJ de depart : %s", TAG, text(st.s_paid), text(st.s_free)))
      st.done = true
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.paid ~= nil and st.paid.at <= PAID_MAX, "une recrue payee (13 personnages ou plus) avant le tick " .. PAID_MAX,
      st.paid and string.format("tick %d, unite %d", st.paid.at, st.paid.unit) or "aucune")
    local sp, sf = st.s_paid, st.s_free
    ctx.check(sp ~= nil and sp.n == 1 and sp.gun == 1 and sp.ammo >= 10, "le corps de la recrue payee garde pistolet 1 et au moins 10 chargeurs",
      sp and text(sp) or "pas de releve")
    ctx.check(sf ~= nil and sf.n == 1 and sf.gun == 0, "le corps du PNJ de depart (kit offert) n'a plus son pistolet (chargeurs fabriques : limite F29)",
      sf and text(sf) or "pas de releve")
  end,
}
