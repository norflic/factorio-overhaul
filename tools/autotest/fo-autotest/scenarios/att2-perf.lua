-- Lot DESIGN-ATTAQUES (7/11) : COÛT EN JEU des 5 grandes attaques, UNE À LA FOIS (fenêtres de 1 200 ticks), pour le pire temps par tick.
-- À lancer SEUL sur le PC (mesure de performance, CLAUDE.md interdit n° 4) :
--   py -3.9 -B tools/autotest/banc.py --out <archive> --seul --qui DESIGN-ATTAQUES -- 7700 att2-perf <source>
--   py -3.9 -B tools/autotest/att2_perf.py <archive>     (pire tick et p99 de scriptUpdate, de la frappe à la fin de chaque grande attaque
--                                                          lue au journal [FO-ATT2] ; fenêtre témoin sans attaque)
-- Chaque géant n'est posé qu'au tick de son lancement (sa 1re attaque est tue pendant la grande : script/robots/attaques2.lua), puis retiré
-- à la fin de sa fenêtre. Passage du 7/11 (5 900 ticks, fenêtres de 1 000) : le Tournesol était coupé à 300 ticks ; la 1re attaque des géants
-- reprenait après la grande dans la même fenêtre (d'où la lecture de la frappe à la fin au journal).
local C = require("scenarios/att2_commun")

local Y = 3000
local IDS = { "cairn", "stylet", "trombe", "ixion", "tournesol" }
local FEN = 1200
local function sx(k) return 6000 + (k - 1) * 400 end
local function lance(k) return 1600 + (k - 1) * FEN end
local FIN = lance(#IDS) + FEN - 50

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
      ctx.log(string.format("[ATT2-PERF] fenetre %s : ticks %d a %d (%d poteaux)", id, lance(k), lance(k) + FEN - 1, np))
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
      elseif e.tick == lance(k) + FEN - 100 and ss.g and ss.g.valid then -- avant le contrôle final (FIN = dernier lancement + FEN - 50)
        ss.fini = remote.call("fo-att2", "en_cours") == 0
        ss.g.destroy()
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local stats = remote.call("fo-att2", "stats")
    for _, id in ipairs(IDS) do
      local x = stats[id] or {}
      ctx.check((x.cibles or 0) > 0, id .. " : des cibles touchees", string.format("candidats %d, cibles %d, max ops/tick %d, max jetons/tick %d",
        x.candidats or 0, x.cibles or 0, x.max_ops or 0, x.max_cout or 0))
    end
    for _, ss in ipairs(st.sites) do
      ctx.check(ss.fini == true, ss.id .. " : la grande attaque a fini dans sa fenetre")
    end
  end,
}
