-- Lot s43-robots (14/11) : les 3 VARIANTES face à leurs parents, en moteur (shared/robots/variantes.lua).
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --qui s43-robots -- 400 s43-variantes <source>
-- Une rangée par couple (parent à gauche, variante à droite) : Cloche / Rafistoleur, Trotte-Vapeur / Furet, Aiguille / Perce-Blindage ;
-- en haut le joueur, en bas une faction (peinture du propriétaire). Contrôles : prototypes présents, PV, vitesse, portée et soin lus
-- aux prototypes égaux aux données ; image au zoom 2 (rangée) et au zoom 1 (vue d'ensemble).
-- Chiffres attendus recopiés de shared/robots/variantes.lua (le mod de banc ne charge pas les modules du mod par chemin pointé) ;
-- tests/s43_robots_test.lua les fige du côté des données.
local WANT = {
  mender = { hp = 926, speed = 0.132, range = 8, tech = "fo-robot-mender" },
  skitter = { hp = 1340, speed = 0.224, range = 22, tech = "fo-robot-skitter" },
  lancer = { hp = 5870, speed = 0.08, range = 42, tech = "fo-robot-lancer" },
}
local function unit_name(owner, id) return "fo-robot-" .. owner .. "-" .. id end

local X0, Y0 = 1500, 1500
local COUPLES = { { "bellwether", "mender" }, { "steam-trotter", "skitter" }, { "needle", "lancer" } }
local OWNERS = { "player", "azure" }

return {
  description = "s43-robots : variantes face a leurs parents",
  base = nil,
  check_tick = 240,
  shots_delay = 30,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    ctx.prepare_area(X0 - 20, Y0 - 16, X0 + 20, Y0 + 16, "concrete")
    game.map_settings.enemy_expansion.enabled = false
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 120, Y0 - 120 }, { X0 + 120, Y0 + 120 } } })) do en.destroy() end
    st.u = {}
    local n, want = 0, 0
    for c, pair in ipairs(COUPLES) do
      for k, id in ipairs(pair) do
        for o, owner in ipairs(OWNERS) do
          want = want + 1
          local x = X0 - 12 + (c - 1) * 9 + (k - 1) * 4
          local y = Y0 - 4 + (o - 1) * 8
          local u = s.create_entity({ name = unit_name(owner, id), position = { x, y }, force = "player", direction = defines.direction.south })
          if u then
            n = n + 1
            u.set_command({ type = defines.command.stop, distraction = defines.distraction.none })
          end
          st.u[#st.u + 1] = { id = id, owner = owner, u = u }
        end
      end
    end
    ctx.check(n == want, "unites posees (3 couples x 2 proprietaires)", n .. " / " .. want)
    for _, pair in ipairs(COUPLES) do
      local r = WANT[pair[2]]
      r.id = pair[2]
      local p = game.entity_prototypes[unit_name("player", r.id)]
      local ap = p and p.attack_parameters
      ctx.check(p ~= nil and p.max_health == r.hp and math.abs(p.speed - r.speed) < 1e-6 and ap and ap.range == r.range,
        "prototype de " .. r.id .. " : PV, vitesse, portee des donnees",
        p and string.format("PV %s, vitesse %.3f, portee %s, cadence %s", p.max_health, p.speed, ap and ap.range or "?", ap and ap.cooldown or "?") or "absent")
      local kit = game.item_prototypes["fo-robot-kit-" .. r.id]
      local rec = game.recipe_prototypes["fo-robot-make-" .. r.id]
      ctx.check(kit ~= nil and rec ~= nil and kit.place_result and kit.place_result.name == unit_name("player", r.id),
        "kit et recette de " .. r.id, rec and (rec.category .. ", " .. #rec.ingredients .. " ingredients") or "absent")
      local t = game.technology_prototypes[r.tech]
      ctx.check(t ~= nil and t.effects[1] and t.effects[1].recipe == "fo-robot-make-" .. r.id, "technologie de " .. r.id, r.tech)
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local vivants = 0
    for _, e in ipairs(st.u) do if e.u and e.u.valid then vivants = vivants + 1 end end
    ctx.check(vivants == #st.u, "toutes les unites vivantes", vivants .. " / " .. #st.u)
  end,

  shots = function(ctx, add)
    add("variantes-z2", X0, Y0, 2, 0, { res = { 1600, 1000 }, info = false, aa = false })
    add("variantes-z1", X0, Y0, 1, 0, { res = { 1400, 1000 }, info = false, aa = false })
  end,
}
