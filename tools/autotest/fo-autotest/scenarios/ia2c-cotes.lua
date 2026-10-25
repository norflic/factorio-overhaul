--[[
  Lot IA2-c : base témoin du joueur défendue d'UN SEUL CÔTÉ (Normal, 60 min). Lancement : « 216000 ia2c-cotes ».
  La base (même place que celle d'ia0-normal : départ − 96 en x, + 16 en y) a ses machines à l'ouest (8 assembleurs,
  4 fours, 2 coffres) et 6 tourelles approvisionnées en colonne à l'EST (x = + 10). Les factions du nord-est et du
  sud-est arrivent donc en face des tourelles si elles vont droit : on mesure (tools/autotest/ia2c_joueur.py, lignes
  « [FO-PVP] attaque … octant o, cote d sur m ») si elles arrivent par un côté moins défendu, et ce qu'elles font après
  une attaque repoussée (M4 contre le joueur). Les contrôles du banc ne portent que sur le déroulement (attaque après la
  grâce, base touchée) : le côté et l'apprentissage se lisent dans le journal.
]]
local C = require("scenarios/ia0_common")

local MACHINES = {
  { "assembling-machine-1", -12, -8 }, { "assembling-machine-1", -8, -8 }, { "assembling-machine-1", -4, -8 },
  { "assembling-machine-1", 0, -8 }, { "assembling-machine-1", -12, 8 }, { "assembling-machine-1", -8, 8 },
  { "assembling-machine-1", -4, 8 }, { "assembling-machine-1", 0, 8 }, { "stone-furnace", -12, 0 },
  { "stone-furnace", -8, 0 }, { "stone-furnace", -4, 0 }, { "stone-furnace", 0, 0 }, { "wooden-chest", -14, 3 },
  { "wooden-chest", 2, 3 },
}
local TURRET_Y = { -10, -6, -2, 2, 6, 10 }

return {
  description = "IA2-c : base temoin defendue a l'est seulement (6 tourelles), Normal, 60 min",
  base = nil,
  check_tick = 215000,

  init = function(ctx)
    local s = ctx.surface()
    local c = game.forces.player.get_spawn_position(s)
    local center = { x = math.floor(c.x) - 96, y = math.floor(c.y) + 16 }
    ctx.prepare_area(center.x - 20, center.y - 16, center.x + 16, center.y + 16, "grass-1")
    local st = ctx.state()
    st.base, st.center = {}, center
    local list = {}
    for _, it in ipairs(MACHINES) do list[#list + 1] = it end
    for _, y in ipairs(TURRET_Y) do list[#list + 1] = { "gun-turret", 10, y } end
    for _, it in ipairs(list) do
      local want = { x = center.x + it[2], y = center.y + it[3] }
      local p = s.find_non_colliding_position(it[1], want, 12, 1)
      local e = p and s.create_entity({ name = it[1], position = p, force = "player" })
      if e then
        if it[1] == "gun-turret" then e.insert({ name = "piercing-rounds-magazine", count = 50 }) end
        st.base[#st.base + 1] = e
      end
    end
    ctx.check(#st.base == #list, "base temoin posee (tourelles a l'est)", string.format("%d/%d batiments en (%d, %d)", #st.base, #list,
      center.x, center.y))
    C.start_war(ctx, "normal")
  end,

  tick = function(ctx, e) C.poll(ctx, e, 60) end,

  finish = function(ctx)
    local st = ctx.state()
    C.check_level(ctx, "normal")
    local early, keys = {}, {}
    for k in pairs(st.factions or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local r = st.factions[k]
      if r.first_attack and r.grace_end and r.first_attack < r.grace_end then early[#early + 1] = k .. "@" .. r.first_attack end
      ctx.log(string.format("%s : attaques %d (%d soldats), 1re au tick %s", k, r.attacks or 0, r.soldiers or 0, tostring(r.first_attack)))
    end
    ctx.check(#early == 0, "aucune attaque contre le joueur avant la fin de la grace", table.concat(early, ", "))
    ctx.check(st.first_attack ~= nil, "au moins une attaque contre la base", st.first_key and (st.first_key .. " au tick " .. st.first_attack) or "aucune")
    ctx.check(st.base_hit ~= nil and st.first_attack ~= nil and st.base_hit > st.first_attack,
      "base temoin touchee apres la 1re attaque", tostring(st.base_hit))
  end,
}
