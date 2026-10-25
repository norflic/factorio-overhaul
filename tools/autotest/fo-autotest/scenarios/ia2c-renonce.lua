--[[
  Lot IA2-c : GO / NO-GO au rassemblement avancé contre le joueur (Normal, 60 min). Lancement : « 216000 ia2c-renonce ».
  Base témoin d'ia0-normal (1 tourelle), vue par les éclaireurs des factions ; à 22 min (avant la 1re attaque de la
  partie, 20,8 min au plus tôt : le moment est tiré entre 20,8 et 31,2 min en Normal), le joueur pose 14 tourelles
  approvisionnées autour de sa base. Une faction qui arrive au rassemblement avec ce qu'elle avait vu (1 tourelle)
  découvre la nouvelle défense : elle doit RENONCER (lignes « [FO-PVP] rassemblement … renonce »), sauf si un regard
  de ses yeux ou de ses éclaireurs l'avait déjà vue (elle attaque alors en la connaissant, ou se dit dissuadée).
  Contrôles : base posée, renfort posé, au moins une décision de rassemblement, et au moins un renoncement OU aucune
  attaque partie sur une défense inconnue (journal : `tools/autotest/ia2c_joueur.py`).
]]
local C = require("scenarios/ia0_common")

local REINFORCE_TICK = 22 * 3600
local RING = {}
for _, p in ipairs({ { -14, -12 }, { -7, -14 }, { 0, -14 }, { 7, -14 }, { 14, -12 }, { -16, -4 }, { 16, -4 }, { -16, 4 }, { 16, 4 },
  { -14, 12 }, { -7, 14 }, { 0, 14 }, { 7, 14 }, { 14, 12 } }) do RING[#RING + 1] = p end

return {
  description = "IA2-c : base renforcee a 22 min (14 tourelles), go / no-go au rassemblement, Normal, 60 min",
  base = nil,
  check_tick = 215000,

  init = function(ctx)
    C.build_base(ctx)
    C.start_war(ctx, "normal")
  end,

  tick = function(ctx, e)
    C.poll(ctx, e, 60)
    local st = ctx.state()
    if e.tick == REINFORCE_TICK and not st.reinforced then
      local s = ctx.surface()
      local n = 0
      for _, it in ipairs(RING) do
        local want = { x = st.center.x + it[1], y = st.center.y + it[2] }
        local p = s.find_non_colliding_position("gun-turret", want, 8, 1)
        local t = p and s.create_entity({ name = "gun-turret", position = p, force = "player" })
        if t then
          t.insert({ name = "piercing-rounds-magazine", count = 50 })
          st.base[#st.base + 1] = t
          n = n + 1
        end
      end
      st.reinforced = n
      ctx.log(string.format("renfort : %d tourelles posees au tick %d", n, e.tick))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    C.check_level(ctx, "normal")
    ctx.check((st.reinforced or 0) >= 12, "renfort pose a 22 min", tostring(st.reinforced))
    local s = ctx.remote("fo-pvp", "status")
    local ren, keys = 0, {}
    for _, f in ipairs(s.factions) do
      ren = ren + (f.renonce or 0)
      keys[#keys + 1] = string.format("%s renonce %d, attaques %d, vus %d, style %s", f.key, f.renonce or 0, f.attacks or 0, f.known or 0,
        f.style or "-")
    end
    ctx.log("factions : " .. table.concat(keys, " ; "))
    ctx.check(ren >= 1, "au moins un renoncement au rassemblement (defense vue grossie)", tostring(ren))
  end,
}
