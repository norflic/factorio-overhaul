-- s43 MEGA-BOURDON (ordre du DC du 13/11) : une salve du Méga-Bourdon sur une base de biters DENSE (nids, vers et unités serrés, à la
-- façon d'une carte à 600 % de taille et de fréquence) et ses trois bases voisines, posées à 120 tuiles et plus à l'est de la cloche :
-- au-delà de l'ancienne portée (36), au-delà du bord de son image (88 tuiles de demi-largeur). On compte nids, vers et unités avant la
-- première orbe, après la première orbe, après la première salve (4 orbes) et à la fin ; profileur du moteur par fenêtre de 30 ticks.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache --ticks 1500" --qui s43 -- 1500 megabourdon-salve <source>
local XM, Y = 4000, 3000
local BX = XM + 150                               -- centre de la base principale
local BASES = { { BX, Y, 28 }, { BX, Y - 62, 16 }, { BX, Y + 62, 16 }, { BX + 62, Y, 16 } }
local PAS = 6                                     -- nids tous les 6 tuiles, vers et unités entre eux
local X0, X1, Y0, Y1 = XM - 120, BX + 100, Y - 130, Y + 130

local PROF -- profileur du moteur (hors global)
local PLAN = {}
local function vue(tick, nom) PLAN[#PLAN + 1] = { tick = tick, nom = nom } end
vue(420, "avant")
for _, t in ipairs({ 540, 570, 600, 630, 660, 700, 760, 840, 960, 1200, 1450 }) do vue(t, string.format("salve-t%04d", t)) end

local function compte(s)
  local c = { nids = 0, vers = 0, unites = 0 }
  for _, e in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 60, Y0 - 60 }, { X1 + 60, Y1 + 60 } } })) do
    if e.type == "unit-spawner" then c.nids = c.nids + 1
    elseif e.type == "turret" then c.vers = c.vers + 1
    elseif e.type == "unit" then c.unites = c.unites + 1 end
  end
  return c
end
local function txt(c) return string.format("nids %d, vers %d, unites %d", c.nids, c.vers, c.unites) end

return {
  description = "MEGA-BOURDON s43 : une salve sur une base dense et ses voisines (nids, vers, unités avant et après)",
  check_tick = 1480,
  shots_delay = PLAN[1].tick,

  init = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    ctx.prepare_area(X0, Y0, X1, Y1, "dry-dirt")
    for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { X0 - 200, Y0 - 200 }, { X1 + 200, Y1 + 200 } } })) do en.destroy() end
    -- prototypes du mod lus en jeu (noms triés) : nids, vers, unités des nids ; titans exclus
    local function tries(filtre, garde)
      local o = {}
      for n, p in pairs(game.get_filtered_entity_prototypes(filtre)) do if garde(n, p) then o[#o + 1] = n end end
      table.sort(o)
      return o
    end
    local pas_titan = function(n) return n:sub(1, 9) ~= "fo-titan-" end
    local nids = tries({ { filter = "type", type = "unit-spawner" } }, pas_titan)
    local vers = tries({ { filter = "type", type = "turret" } }, function(n) return pas_titan(n) and n:find("worm", 1, true) ~= nil end)
    local vus, unites = {}, {}
    for _, n in ipairs(nids) do
      for _, ru in ipairs(game.entity_prototypes[n].result_units or {}) do
        if not vus[ru.unit] and pas_titan(ru.unit) then vus[ru.unit] = true; unites[#unites + 1] = ru.unit end
      end
    end
    table.sort(unites)
    local i_n, i_v, i_u = 0, 0, 0
    local function suivant(l, i) i = i % #l + 1; return l[i], i end
    for _, b in ipairs(BASES) do
      local cx, cy, r = b[1], b[2], b[3]
      for dx = -r, r, PAS do
        for dy = -r, r, PAS do
          if dx * dx + dy * dy <= r * r then
            local n
            n, i_n = suivant(nids, i_n)
            if n then s.create_entity({ name = n, position = { cx + dx, cy + dy }, force = "enemy" }) end
            if (dx + dy + 2 * r) % (2 * PAS) == 0 then -- une case sur deux (dx et dy partent de -r)
              n, i_v = suivant(vers, i_v)
              local q = n and s.find_non_colliding_position(n, { cx + dx + PAS / 2, cy + dy + PAS / 2 }, PAS, 0.5)
              if q then s.create_entity({ name = n, position = q, force = "enemy" }) end
            end
            n, i_u = suivant(unites, i_u)
            if n then
              for k = 0, 1 do s.create_entity({ name = n, position = { cx + dx + PAS / 2, cy + dy - 1 + 2 * k }, force = "enemy" }) end
            end
          end
        end
      end
    end
    st.depart = compte(s)
    ctx.log("[FO-MEGA-SALVE] pose : " .. txt(st.depart) .. string.format(" ; %d types de nids, %d de vers, %d d'unites", #nids, #vers, #unites))
    st.mega = remote.call("fo-bourdon", "descendre", "player", XM, Y, 1, "mega")
    ctx.check(st.mega ~= nil, "le Méga-Bourdon descend")
    st.journal = {}
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local t = e.tick
    if t == 2 then remote.call("fo-bourdon", "muet", st.mega, true) end -- le Glas coupé : on juge les casemates seules
    local s = ctx.surface()
    local m = remote.call("fo-bourdon", "etat", st.mega) or {}
    local tirs = m.tirs or 0
    if t == 420 then st.avant = compte(s) ctx.log("[FO-MEGA-SALVE] avant (t420) : " .. txt(st.avant)) end
    if tirs >= 1 and not st.t1 then st.t1 = t ctx.log(string.format("[FO-MEGA-SALVE] premiere orbe partie a t%d", t)) end
    if tirs >= 4 and not st.t4 then st.t4 = t ctx.log(string.format("[FO-MEGA-SALVE] quatrieme orbe (fin de la salve) partie a t%d", t)) end
    -- premier impact : le premier tick où le compte baisse
    if st.t1 and not st.premier_mort and t % 2 == 0 then
      local c = compte(s)
      if st.avant and c.nids + c.vers + c.unites < st.avant.nids + st.avant.vers + st.avant.unites then
        st.premier_mort = t
        ctx.log("[FO-MEGA-SALVE] premier impact (t" .. t .. ", tirs " .. tirs .. ") : " .. txt(c))
      end
    end
    if st.t4 and not st.apres4 and t >= st.t4 + 150 then
      st.apres4 = compte(s)
      ctx.log("[FO-MEGA-SALVE] apres la premiere salve, 4 orbes (t" .. t .. ") : " .. txt(st.apres4))
    end
    if t >= 400 and t % 10 == 0 and t <= 1100 then
      local c = compte(s)
      ctx.log(string.format("[FO-MEGA-SALVE] t%d tirs %d : %s", t, tirs, txt(c)))
    end
    -- profileur du moteur (temps réel, tout compris) par fenêtre de 30 ticks
    if t >= 390 and t <= 1290 and t % 30 == 0 then
      if PROF then PROF.stop() log({ "", "[FO-MEGA-SALVE] prof t" .. (t - 30) .. "-" .. t .. " (tirs " .. tirs .. ") : ", PROF }) end
      PROF = game.create_profiler()
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local fin = compte(s)
    local m = remote.call("fo-bourdon", "etat", st.mega) or {}
    ctx.log("[FO-MEGA-SALVE] fin : " .. txt(fin) .. string.format(" ; tirs %d, phase %s", m.tirs or -1, tostring(m.phase)))
    local av = st.avant or st.depart or { nids = 0, vers = 0, unites = 0 }
    ctx.check(av.nids >= 60 and av.vers >= 10 and av.unites >= 100, "base dense posée", txt(av))
    ctx.check(st.t1 ~= nil, "les casemates tirent au-delà du bord de l'image (base à 120 tuiles et plus)", tostring(st.t1))
    local a4 = st.apres4
    ctx.check(a4 ~= nil and a4.nids == 0 and a4.vers == 0, "une salve rase les nids et les vers des quatre bases", a4 and txt(a4) or "pas de salve")
    -- les couvées (enemy_mechanics) libèrent 2 unités du palier inférieur à leur mort : les unités ne se comptent qu'à la fin
    ctx.check(fin.nids == 0 and fin.vers == 0 and fin.unites == 0, "à la fin, plus un nid, un ver ni une unité", txt(fin))
  end,

  shots = function(ctx, add)
    for i, p in ipairs(PLAN) do
      local suivant = PLAN[i + 1]
      add(p.nom, XM + 95, Y, 0.125, 0, { res = { 1600, 1040 }, cadence = suivant and math.max(1, suivant.tick - p.tick) or nil, aa = true })
    end
  end,
}
