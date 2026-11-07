-- Lot DESIGN-ATTAQUES (7/11) : COÛT EN JEU des 5 grandes attaques, UNE À LA FOIS (fenêtres de 1 000 ticks), pour le pire temps par tick.
-- À lancer SEUL sur le PC (mesure de performance, CLAUDE.md interdit n° 4) :
--   py -3.9 -B tools/autotest/banc.py --out <archive> --seul --qui DESIGN-ATTAQUES -- 5900 att2-perf <source>
--   py -3.9 -B tools/autotest/att2_perf.py <archive>     (pire tick et p99 de scriptUpdate par fenêtre ; témoin sans attaque)
-- Chaque géant n'est posé qu'au tick de sa frappe (sa 1re attaque est tue pendant la grande : script/robots/attaques2.lua), puis retiré
-- à la fin de sa fenêtre : la fenêtre ne mesure que SA grande attaque. Fenêtre témoin : ticks 610 à 1 590, sans rien.
local C = require("scenarios/att2_commun")

local Y = 3000
local IDS = { "cairn", "stylet", "trombe", "ixion", "tournesol" }
local function sx(k) return 6000 + (k - 1) * 400 end
local function lance(k) return 1600 + (k - 1) * 1000 end
local FIN = 5850

return {
  description = "DESIGN-ATTAQUES : cout en jeu des 5 grandes attaques, une a la fois (mesure --seul)",
  check_tick = FIN,

  init = function(ctx)
    local st = ctx.state()
    C.forces()
    remote.call("fo-att2", "journal", true)
    st.sites = {}
    local s = ctx.surface()
    for k, id in ipairs(IDS) do
      local R = C.rayon_base(id)
      ctx.prepare_area(sx(k) - R - 70, Y - R - 30, sx(k) + R + 25, Y + R + 25, "dry-dirt")
      for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { sx(k) - R - 120, Y - R - 120 }, { sx(k) + R + 120, Y + R + 120 } } })) do
        en.destroy()
      end
      local f = C.force_geant(k)
      local np = C.base(s, sx(k), Y, R, k * 3)
      st.sites[k] = { id = id, force = f.name, poles = np }
      ctx.log(string.format("[ATT2-PERF] fenetre %s : ticks %d a %d (%d poteaux)", id, lance(k), lance(k) + 999, np))
    end
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    for k, ss in ipairs(st.sites) do
      if e.tick == lance(k) then
        ss.g = s.create_entity({ name = "fo-xp-" .. ss.id, position = { sx(k) - C.PORTEE[ss.id], Y + 4 }, force = ss.force, raise_built = true })
        local okl, why = remote.call("fo-att2", "lancer", ss.g, sx(k) + 0.5, Y + 0.5, true)
        ctx.check(okl == true, ss.id .. " : grande attaque lancee", tostring(why))
      elseif e.tick == lance(k) + 990 and ss.g and ss.g.valid then
        ss.g.destroy()
      end
    end
  end,

  finish = function(ctx)
    local stats = remote.call("fo-att2", "stats")
    for _, id in ipairs(IDS) do
      local x = stats[id] or {}
      ctx.check((x.cibles or 0) > 0, id .. " : des cibles touchees", string.format("candidats %d, cibles %d, max ops/tick %d", x.candidats or 0,
        x.cibles or 0, x.max_ops or 0))
    end
  end,
}
