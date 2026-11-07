-- Lot EXPERIMENTAUX-PUISSANCE (7/11), DOUBLE SOURCE : une sauvegarde d'AVANT la règle d'échelle (création par 38ee70e1, essai 0.6.53)
-- rechargée avec la règle (demande du lead : « conserve la PROPORTION de vie »). 300 ticks :
--   py -3.9 -B tools/autotest/banc.py --out <archive> --creation <src-38ee70e1> --qui XP-PUISSANCE -- 300 xp-vie-migration <source neuve>
-- À la création : un Couronné de robotsjeu à pleine vie, une Tournesol à moitié, un Bourdon à moitié, un Mât-Foudre à pleine vie. Au
-- benchmark (source neuve) : le maximum a changé (contrôlé) et chacun garde SA part de vie (pleine reste pleine, moitié reste moitié).
-- 7/11 : avec une migration de script en plus, la part était appliquée DEUX fois (Tournesol et Bourdon à 100 %) : le moteur la garde seul.
local C = require("scenarios/xp_commun")

local X, Y = 15000, 6000
local CHECK = 120

local function part(e) return e.health / e.prototype.max_health end

return {
  description = "EXPERIMENTAUX-PUISSANCE : proportion de vie gardee au chargement d'une sauvegarde d'avant la regle",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    C.forces()
    local s = ctx.surface()
    ctx.prepare_area(X - 40, Y - 40, X + 200, Y + 40, "dry-dirt")
    local fname = "fo-xp-vie"
    local f = game.forces[fname] or game.create_force(fname)
    remote.call("fo-robots", "set_age", fname, 15)
    ctx.call("war_setting", "fo-war-robots-cap", 400)
    st.version_create = script.active_mods["factorio-overhaul"]
    st.u = {}
    local function note(nom, e, p)
      if e and e.valid then
        e.health = e.prototype.max_health * p
        st.u[#st.u + 1] = { nom = nom, e = e, p = p, max0 = e.prototype.max_health }
      else
        ctx.log("creation : " .. nom .. " absent")
      end
    end
    local un = remote.call("fo-robots", "spawn", fname, "crowned", X, Y)
    local cr = nil
    for _, e in ipairs(s.find_entities_filtered({ name = "fo-robot-player-crowned", position = { X, Y }, radius = 30 })) do cr = e end
    note("couronne", cr, 1.0)
    note("tournesol", s.create_entity({ name = "fo-xp-tournesol", position = { X + 60, Y }, force = f, raise_built = true }), 0.5)
    local bid = remote.call("fo-bourdon", "descendre", fname, X + 120, Y)
    local bo = nil
    for _, e in ipairs(s.find_entities_filtered({ name = "fo-bourdon", position = { X + 120, Y }, radius = 30 })) do bo = e end
    note("bourdon", bo, 0.5)
    note("mat-foudre", s.create_entity({ name = "fo-xp-mat-foudre", position = { X + 170, Y }, force = f, raise_built = true }), 1.0)
    for _, u in ipairs(st.u) do ctx.log(string.format("creation : %s PV %.0f / %.0f", u.nom, u.e.health, u.max0)) end
    ctx.log("creation par factorio-overhaul " .. tostring(st.version_create) .. ", couronne " .. tostring(un) .. ", bourdon " .. tostring(bid))
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(#st.u == 4, "4 unites posees a la creation", tostring(#st.u))
    for _, u in ipairs(st.u) do
      local e = u.e
      if e and e.valid then
        local m1 = e.prototype.max_health
        ctx.check(m1 > u.max0, u.nom .. " : maximum monte par la regle", string.format("%.0f -> %.0f", u.max0, m1))
        -- la régénération ne fait que monter la part (Tournesol : 1/36 000 du maximum par tick, 0,33 % en 120 ticks) ; sans la migration :
        -- 0,18 (Tournesol), 0,004 (Bourdon), 0,32 (Couronné), 0,30 (Mât-Foudre)
        ctx.check(part(e) >= u.p - 0.002 and part(e) <= u.p + 0.006, u.nom .. " : part de vie gardee", string.format("%.4f (attendu %.2f), PV %.0f / %.0f", part(e), u.p, e.health, m1))
      else
        ctx.check(false, u.nom .. " : toujours la apres le chargement")
      end
    end
  end,
}
