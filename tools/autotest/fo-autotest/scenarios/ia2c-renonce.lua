--[[
  Lot IA2-c : GO / NO-GO au rassemblement avancé contre le joueur (Normal, 60 min). Lancement : « 216000 ia2c-renonce ».
  Base témoin d'ia0-normal (1 tourelle), vue par les éclaireurs des factions ; DÈS QUE la 1re attaque de la partie
  contre le joueur part (relevé toutes les 60 ticks), le joueur pose 14 tourelles approvisionnées autour de sa base. Le
  groupe parti avec ce qu'il avait vu (1 tourelle) découvre au rassemblement avancé la nouvelle défense : il doit
  RENONCER (« [FO-PVP] rassemblement … renonce ») si sa force n'atteint plus le rapport exigé.
  1re version (renfort à 22 min, essai du lot) : les factions avaient revu la base renforcée AVANT d'attaquer (défense
  de départ 120) : aucune surprise, aucun renoncement.
  Contrôles : base posée, renfort posé, au moins un renoncement au rassemblement (statut « fo-pvp »).
]]
local C = require("scenarios/ia0_common")

local RING = {}
for _, p in ipairs({ { -14, -12 }, { -7, -14 }, { 0, -14 }, { 7, -14 }, { 14, -12 }, { -16, -4 }, { 16, -4 }, { -16, 4 }, { 16, 4 },
  { -14, 12 }, { -7, 14 }, { 0, 14 }, { 7, 14 }, { 14, 12 } }) do RING[#RING + 1] = p end

return {
  description = "IA2-c : base renforcee au depart de la 1re attaque (14 tourelles), go / no-go au rassemblement, Normal, 60 min",
  base = nil,
  check_tick = 215000,

  init = function(ctx)
    C.build_base(ctx)
    C.start_war(ctx, "normal")
  end,

  tick = function(ctx, e)
    C.poll(ctx, e, 60)
    local st = ctx.state()
    if st.first_attack and not st.reinforced then
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
    ctx.check((st.reinforced or 0) >= 12, "renfort pose au depart de la 1re attaque", tostring(st.reinforced))
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
