-- Lot EXPERIMENTAUX-PUISSANCE (7/11), B1 de la revue de la 0.6.57 : une partie sauvegardée PENDANT une salve de zone de la 0.6.56 plantait
-- à la reprise (job sans secteurs : liste `found` sans curseur, ou plan sans compteurs `cnt` ; Ech.frapper les indexait). 600 ticks :
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui XP-PUISSANCE -- 600 xp-zone-ancien <source>
-- À la création (on_init, dans la sauvegarde) : une Tournesol devant une petite base, et deux jobs de salve AU FORMAT DE LA 0.6.56 posés
-- pour elle (remote « fo-xp », « ancien_job » : l'un avant rangement, l'autre en frappe), salve marquée active. Au benchmark, la
-- sauvegarde est rechargée : les deux jobs sont abandonnés au premier tick sans erreur, la salve n'est plus active, puis la Tournesol tire
-- une VRAIE salve et rase la base.
local C = require("scenarios/xp_commun")

local X, Y = 12000, 5200
local CX = X + 30
local R = 20
local CHECK = 540

local function restants(s)
  return s.count_entities_filtered({ position = { CX, Y }, radius = R + 1, force = C.CIBLE })
end

return {
  description = "EXPERIMENTAUX-PUISSANCE : jobs de salve de la 0.6.56 dans une sauvegarde, abandonnes sans erreur (B1)",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    C.forces()
    remote.call("fo-xp", "journal", true)
    local s = ctx.surface()
    ctx.prepare_area(X - 20, Y - R - 10, CX + R + 10, Y + R + 10, "dry-dirt")
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X - 120, Y - 120 }, { CX + 120, Y + 120 } } })) do en.destroy() end
    local fname = "fo-xp-ancien"
    local f = game.forces[fname] or game.create_force(fname)
    local cible = game.forces[C.CIBLE]
    cible.set_cease_fire(f, true)
    f.set_cease_fire(cible, false)
    game.forces.enemy.set_cease_fire(f, true)
    f.set_cease_fire(game.forces.enemy, true)
    remote.call("fo-robots", "set_age", fname, 15)
    s.create_entity({ name = "gun-turret", position = { CX, Y }, force = C.CIBLE })
    for ix = -R, R, 3 do
      for iy = -R, R, 3 do
        if ix * ix + iy * iy <= R * R and not (math.abs(ix) <= 2 and math.abs(iy) <= 2) then
          s.create_entity({ name = "small-lamp", position = { CX + ix + 0.5, Y + iy + 0.5 }, force = C.CIBLE })
        end
      end
    end
    st.n0 = restants(s)
    st.g = s.create_entity({ name = "fo-xp-tournesol", position = { X, Y }, force = f, raise_built = true })
    ctx.check(st.g ~= nil and st.g.valid, "la Tournesol se pose")
    st.un = st.g and st.g.unit_number
    st.poses = st.un and remote.call("fo-xp", "ancien_job", st.un) or 0
    local jz = remote.call("fo-xp", "jobs_zone")
    ctx.check(st.poses == 2 and jz.anciens == 2 and remote.call("fo-xp", "zone_active", st.un), "creation : 2 jobs de la 0.6.56 dans la sauvegarde, salve active",
      string.format("poses %s, anciens %s", tostring(st.poses), tostring(jz.anciens)))
    ctx.log(string.format("creation : base de %d entites, Tournesol %s", st.n0, tostring(st.un)))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == 2 then
      local jz = remote.call("fo-xp", "jobs_zone")
      st.anciens2 = jz.anciens
    end
    if e.tick % 30 == 0 and not st.rasee and restants(ctx.surface()) == 0 then st.rasee = e.tick end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.anciens2 == 0, "reprise : les jobs de la 0.6.56 sont abandonnes au premier tick, sans erreur", tostring(st.anciens2))
    ctx.check(st.g and st.g.valid, "la Tournesol est toujours la")
    local n = restants(ctx.surface())
    ctx.check(n == 0, "une vraie salve suit et rase la base", string.format("%d restantes sur %d, rasee au tick %s", n, st.n0 or -1, tostring(st.rasee)))
  end,
}
