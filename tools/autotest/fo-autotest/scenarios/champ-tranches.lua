--[[
  Lot CHAMP-TRANCHES (7/11), critère C7a (fo-logs/2026-11-07_CHAMP-TRANCHES/CRITERES.md) : micro-banc du registre des travaux du plan de
  champ (script/team/champ_jobs.lua) EN MOTEUR RÉEL.
    - init : le profileur du mod passe en détail par tick (portées champ:frame-plan et champ:band-plan lues ensuite par
      tools/autotest/perf3.py) ; les specs du corpus de champ3 (tests/champ_formes.lua, données pures : 17 formes et le géant ; les deux
      cadres réels sont lus dans des fichiers, `io` n'existe pas en jeu) sont soumises au registre par l'interface « fo-champ-travaux » ;
    - tick : chaque travail prêt est repris ;
    - finish (tick 6 000) : tous les plans repris, chacun IDENTIQUE (sérialiseur de champ3) à Ch.plan sur la même spec dans le même
      jeu ; livraison dans l'ordre d'arrivée.
  Le contrôle des 16 ms se lit au détail du profileur (perf3.py --detail), hors du scénario. Lancement :
    py -3.9 -B tools/autotest/banc.py --qui CHAMP-TRANCHES --out <archive> -- 6100 champ-tranches <source>
  Journal : [FO-CHAMP-TRANCHES].
]]
package.loaded["shared.team.champ_fonderie"] = package.loaded["shared.team.champ_fonderie"] or require("__factorio-overhaul__/shared/team/champ_fonderie")
package.loaded["shared.team.melange"] = package.loaded["shared.team.melange"] or require("__factorio-overhaul__/shared/team/melange")
package.loaded["shared.team.champ_colonne"] = package.loaded["shared.team.champ_colonne"] or require("__factorio-overhaul__/shared/team/champ_colonne")
-- (36f3a424 : champ.lua requiert aussi champ_couverture ; un require de l'autre mod se résout depuis CE mod : chaque dépendance
-- est chargée ici d'abord, feuilles avant le reste)
package.loaded["shared.team.champ_couverture"] = package.loaded["shared.team.champ_couverture"] or require("__factorio-overhaul__/shared/team/champ_couverture")
package.loaded["shared.team.champ"] = package.loaded["shared.team.champ"] or require("__factorio-overhaul__/shared/team/champ")
local Ch = package.loaded["shared.team.champ"]
local Fm = require("__factorio-overhaul__/tests/champ_formes")
local Sr = require("__factorio-overhaul__/tests/champ_plan_serial")

-- Corpus de champ3 SANS les deux cadres réels (lus dans des fichiers : `io` n'existe pas en jeu) : les 17 formes et le géant
local function corpus()
  local out = {}
  for _, s in ipairs(Fm.shapes()) do out[#out + 1] = { name = s.name, spec = function() return Fm.spec_of(s.ore, s.o) end } end
  local g = Fm.rect(0, 0, 200, 200)
  out[#out + 1] = { name = "geant 200 x 200", spec = function() return Fm.spec_of(g, {}) end }
  return out
end

return {
  description = "CHAMP-TRANCHES : plans de champ par tranches en moteur reel (corpus de champ3, registre des travaux)",
  base = nil,
  check_tick = 6000,

  init = function(ctx)
    ctx.call("profiler", true, "detail")
    local st = ctx.state()
    st.keys, st.got, st.order = {}, {}, {}
    for i, cs in ipairs(corpus()) do
      local key = string.format("c%02d", i)
      local r = remote.call("fo-champ-travaux", "soumettre", key, "frame", cs.spec())
      ctx.check(r == "calcul", cs.name .. " : travail cree", tostring(r))
      st.keys[#st.keys + 1] = { key = key, name = cs.name }
    end
    ctx.log(string.format("[FO-CHAMP-TRANCHES] %d travail(aux) soumis au tick %d", #st.keys, game.tick))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    for _, k in ipairs(st.keys) do
      if not st.got[k.key] then
        local r = remote.call("fo-champ-travaux", "reprendre", k.key, "frame")
        if r and not r.pending then
          st.got[k.key] = { h = Sr.print(r.p, r.why), tick = e.tick, created = r.created, steps = r.steps }
          st.order[#st.order + 1] = k.key
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local same, all, fifo = 0, 0, true
    for i, k in ipairs(st.keys) do
      local g = st.got[k.key]
      local cs
      for _, x in ipairs(corpus()) do if x.name == k.name then cs = x end end
      local ref = Sr.print(Ch.plan(cs.spec()))
      if g then
        all = all + 1
        if g.h == ref then same = same + 1 end
        ctx.log(string.format("[FO-CHAMP-TRANCHES] %s : repris au tick %d (cree au tick %d, %d pas), empreinte %s, bloc %s", k.name, g.tick,
          g.created or -1, g.steps or 0, g.h, ref))
      end
      if st.order[i] ~= k.key then fifo = false end
    end
    ctx.check(all == #st.keys, "tous les plans repris", string.format("%d sur %d", all, #st.keys))
    ctx.check(same == #st.keys, "chaque plan repris = Ch.plan d'un bloc sur la meme spec", string.format("%d sur %d", same, #st.keys))
    ctx.check(fifo, "livraison dans l'ordre d'arrivee", table.concat(st.order, ","))
    local s = remote.call("fo-champ-travaux", "etat")
    ctx.log(string.format("[FO-CHAMP-TRANCHES] registre : %d en file, %d prets, %d pas, %d crees, %d repris", s.queued, s.ready, s.stats.steps,
      s.stats.created, s.stats.taken))
  end,
}
