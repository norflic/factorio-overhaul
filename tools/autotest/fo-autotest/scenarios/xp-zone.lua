-- Lot EXPERIMENTAUX-PUISSANCE (5/11), 1 500 ticks, sans images : la SALVE DE ZONE d'un géant en moteur réel, et son COÛT.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui XP-PUISSANCE -- 1500 xp-zone <source>
--   puis : python tools/autotest/analyze.py <archive> --spikes   (scriptUpdate et entityUpdate par tick, en ms)
-- Une base ennemie dense : une tourelle au centre (la seule cible militaire) et environ 3 800 lampes (non militaires, 1 × 1, tous les
-- 2 tuiles) dans un disque de 70 tuiles. La Tournesol (âge 14 : zone 75, salve 312 000 par cible), de jour, à 50 tuiles du centre.
-- Contrôles : (a) une salve frappe toute la base (au plus Ech.PLAFOND cibles) en tranches de Ech.TRANCHE par tick ; (b) la base est RASÉE
-- avant le contrôle, y compris après la mort de la tourelle (« jusqu'à la fin ») ; (c) un témoin de SA force au milieu reste intact ;
-- (d) un cratère (sol nuclear-ground) est posé au point visé.
-- Second site, 400 tuiles plus au sud : la même base devant le COURONNÉ de robotsjeu (âge 15 : zone 90, salve laser 660 000), qui suit la même
-- règle depuis le commit 7da51f02 (script/robots/geant.lua, Geant.salves) : mêmes contrôles (b), (c), (d).
local C = require("scenarios/xp_commun")

local CHECK = 1400
local X, Y = 12000, 4200
local CX = X + 50
local R = 70
local Y2 = Y + 400

local function lampes(s, y)
  local out = {}
  for ix = -R, R, 2 do
    for iy = -R, R, 2 do
      if ix * ix + iy * iy <= R * R and not (math.abs(ix) <= 3 and math.abs(iy) <= 3) and not (ix == 0 and iy == 10) then
        local e = s.create_entity({ name = "small-lamp", position = { CX + ix + 0.5, y + iy + 0.5 }, force = C.CIBLE })
        if e then out[#out + 1] = e end
      end
    end
  end
  return out
end

local function restants(s, y)
  return s.count_entities_filtered({ position = { CX, y or Y }, radius = R + 1, force = C.CIBLE })
end

return {
  description = "EXPERIMENTAUX-PUISSANCE : salve de zone de la Tournesol sur une base dense de 3 800 lampes",
  check_tick = CHECK,

  init = function(ctx)
    local st = ctx.state()
    C.forces()
    remote.call("fo-xp", "journal", true)
    local s = ctx.surface()
    s.freeze_daytime = true
    s.daytime = 0
    ctx.prepare_area(X - 20, Y - R - 10, CX + R + 10, Y + R + 10, "dry-dirt")
    ctx.prepare_area(X - 20, Y2 - R - 10, CX + R + 10, Y2 + R + 10, "dry-dirt")
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X - 120, Y - 200 }, { CX + 200, Y2 + 200 } } })) do en.destroy() end
    local fname = "fo-xp-zone"
    local f = game.forces[fname] or game.create_force(fname)
    local cible = game.forces[C.CIBLE]
    cible.set_cease_fire(f, true)
    f.set_cease_fire(cible, false)
    game.forces.enemy.set_cease_fire(f, true)
    f.set_cease_fire(game.forces.enemy, true)
    remote.call("fo-robots", "set_age", fname, 15)
    st.tourelle = s.create_entity({ name = "gun-turret", position = { CX, Y }, force = C.CIBLE })
    st.n0 = #lampes(s, Y) + 1
    st.temoin = s.create_entity({ name = "lab", position = { CX + 0.5, Y + 10.5 }, force = fname })
    st.g = s.create_entity({ name = "fo-xp-tournesol", position = { X, Y }, force = f, raise_built = true })
    ctx.check(st.g ~= nil and st.g.valid, "la Tournesol se pose")
    ctx.log(string.format("base : %d entites ennemies dans %d tuiles", st.n0, R))
    -- second site : le Couronné de robotsjeu
    local fro = "fo-xp-zone-ro"
    local f2 = game.forces[fro] or game.create_force(fro)
    cible.set_cease_fire(f2, true)
    f2.set_cease_fire(cible, false)
    game.forces.enemy.set_cease_fire(f2, true)
    f2.set_cease_fire(game.forces.enemy, true)
    remote.call("fo-robots", "set_age", fro, 15)
    ctx.call("war_setting", "fo-war-robots-cap", 400)
    s.create_entity({ name = "gun-turret", position = { CX, Y2 }, force = C.CIBLE })
    st.n2 = #lampes(s, Y2) + 1
    st.temoin2 = s.create_entity({ name = "lab", position = { CX + 0.5, Y2 + 10.5 }, force = fro })
    local un, why = remote.call("fo-robots", "spawn", fro, "crowned", X, Y2)
    st.ro = un
    ctx.check(un ~= nil, "le Couronne se pose", tostring(why))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if t % 30 == 0 and t <= CHECK then
      local s = ctx.surface()
      local n = restants(s)
      if st.tourelle_morte == nil and not (st.tourelle and st.tourelle.valid) then st.tourelle_morte = t end
      if n == 0 and not st.rasee then st.rasee = t end
      local n2 = restants(s, Y2)
      if n2 == 0 and not st.rasee2 then st.rasee2 = t end
      if t % 120 == 0 then ctx.log(string.format("t%d : %d entites ennemies restantes (Couronne : %d)", t, n, n2)) end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local n = restants(s)
    local stt = remote.call("fo-xp", "stats").tournesol
    ctx.check(st.g and st.g.valid, "la Tournesol est toujours la")
    ctx.check(n == 0, "la base est rasee avant le controle", string.format("%d restantes sur %d, rasee au tick %s", n, st.n0, tostring(st.rasee)))
    ctx.check(st.tourelle_morte ~= nil and stt.tues >= st.n0 - 1, "les lampes (non militaires) sont frappees, la tourelle morte comprise",
      string.format("tourelle morte au tick %s, tues %d sur %d", tostring(st.tourelle_morte), stt.tues, st.n0))
    ctx.check(st.temoin and st.temoin.valid and st.temoin.health == st.temoin.prototype.max_health, "temoin de sa force intact au milieu")
    local tile = s.get_tile(CX, Y)
    ctx.check(tile and tile.name == "nuclear-ground", "cratere au point vise", tile and tile.name or "?")
    local n2 = restants(s, Y2)
    ctx.check(n2 == 0, "Couronne : la base est rasee avant le controle", string.format("%d restantes sur %d, rasee au tick %s", n2, st.n2 or -1,
      tostring(st.rasee2)))
    ctx.check(st.temoin2 and st.temoin2.valid and st.temoin2.health == st.temoin2.prototype.max_health, "Couronne : temoin de sa force intact")
    local tile2 = s.get_tile(CX, Y2)
    ctx.check(tile2 and tile2.name == "nuclear-ground", "Couronne : cratere au point vise", tile2 and tile2.name or "?")
  end,
}
