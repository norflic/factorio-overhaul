-- Scénario greffé du lot F1-C (4/11) : LA TOURELLE LASER des 15 âges en jeu (30 niveaux), de jour et de nuit, et son
-- FAISCEAU dans 8 directions (bouche mesurée sur la géométrie : laser_e/bouches.py). Sur le modèle de f3-assembleurs.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui F1-C -- 500 f1-lasers <source>          (contrôles)
--   py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache --ticks 3000" --qui F1-C
--       -- 500 f1-lasers <source>                                                                  (captures)
-- Grille : une rangée par ère (5), six tourelles par rangée (trois âges, niveau impair puis pair), alimentées (source
-- invisible du mod de test), tête vers l'EST (orientation écrite, F122), sans cible.
-- Faisceaux : niveaux 1 (vanilla), 3, 11, 19, 27 et 29 (âges 1, 2, 6, 10, 14, 15), une tourelle par direction (N, NE, E,
-- SE, S, SO, O, NO), un biter géant IMMOBILE (active = false, soigné à chaque tick, recréé s'il meurt) à 6 tuiles du bord ; sites à 80 tuiles
-- les uns des autres (portée 35,6 au niveau 30 : aucune tourelle n'atteint la cible d'une autre).
-- Captures : chaque ère au zoom 1, de jour et de nuit ; chaque âge (impair et pair) au zoom 2, de jour et de nuit ;
-- chaque faisceau au zoom 2, de jour. Tables : fo-shots/f1-lasers-sites.tsv (grille), fo-shots/f1-lasers-faisceaux.tsv
-- (centre de la capture, tourelle, cible, bouche prévue : source_offset et hauteur de sprites.lua).

local SPR_OK, SPR = pcall(require, "__factorio-overhaul__/graphics/levels/laser/sprites")

local X0, Y0 = -3200, 3000          -- grille des 30 niveaux
local FX0, FY0 = -3200, 3200        -- faisceaux : 8 colonnes (directions) × 6 rangées (niveaux)
local GAP = 2
local PAS = 80
local NIVEAUX_F = { 1, 3, 11, 19, 27, 29 }
local DIRS = { { "N", 0 }, { "NE", 1 }, { "E", 2 }, { "SE", 3 }, { "S", 4 }, { "SO", 5 }, { "O", 6 }, { "NO", 7 } }
local T_CIBLES = 30

local function emprise(n)
  if n <= 6 then return 2 elseif n <= 12 then return 3 elseif n <= 18 then return 4 elseif n <= 24 then return 5 end
  return 6
end
local function nom(n) return n == 1 and "laser-turret" or ("fo-lvl-laser-" .. n) end
local function faisceau(n) return n == 1 and "laser-beam" or ("fo-lvl-laser-" .. n .. "-faisceau") end
local function vec(k) local a = 2 * math.pi * k / 8 return math.sin(a), -math.cos(a) end

return {
  description = "F1-C : tourelles laser des 15 ages (30 niveaux), jour et nuit, faisceau dans 8 directions",
  base = nil,
  check_tick = 400,
  shots_delay = 420,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.sites, st.tirs = {}, {}
    game.map_settings.enemy_expansion.enabled = false
    game.forces.enemy.set_cease_fire("player", true)
    ctx.prepare_area(X0 - 12, Y0 - 12, X0 + 70, Y0 + 60, "concrete")
    ctx.power(X0 + 30, Y0 + 25)
    local y = Y0
    for ere = 1, 5 do
      local side = emprise((ere - 1) * 6 + 1)
      local x = X0
      for i = 1, 6 do
        local n = (ere - 1) * 6 + i
        local px, py = x + side / 2, y + side / 2
        local t = s.create_entity({ name = nom(n), position = { px, py }, force = "player" })
        if t then pcall(function() t.orientation = 0.25 end) end
        st.sites[#st.sites + 1] = { n = n, age = math.floor((n + 1) / 2), ere = ere, t = t, x = px, y = py,
          side = side }
        x = x + side + GAP
      end
      y = y + side + 4
    end
    local poses = 0
    for _, c in ipairs(st.sites) do if c.t then poses = poses + 1 end end
    ctx.check(poses == 30, "tourelles laser posees (30 niveaux)", poses .. " / 30")
    -- faisceaux : une tourelle par (niveau, direction), une cible immobile
    for r, n in ipairs(NIVEAUX_F) do
      for c, d in ipairs(DIRS) do
        local x, y = FX0 + (c - 1) * PAS, FY0 + (r - 1) * PAS
        ctx.prepare_area(x - 14, y - 14, x + 14, y + 14, "grass-1")
        for _, en in ipairs(s.find_entities_filtered({ force = "enemy", area = { { x - 60, y - 60 }, { x + 60, y + 60 } } })) do
          en.destroy()
        end
        ctx.power(x - 10, y + 10)
        local side = emprise(n)
        local t = s.create_entity({ name = nom(n), position = { x + (side % 2) * 0.5, y + (side % 2) * 0.5 },
          force = "player" })
        local ux, uy = vec(d[2])
        local dist = side / 2 + 6
        local tir = { n = n, dir = d[1], k = d[2], t = t, x = t and t.position.x or x, y = t and t.position.y or y,
          side = side, vus = 0, noms = {} }
        tir.cx, tir.cy = tir.x + dist * ux, tir.y + dist * uy
        st.tirs[#st.tirs + 1] = tir
      end
    end
    local pt = 0
    for _, f in ipairs(st.tirs) do if f.t then pt = pt + 1 end end
    ctx.check(pt == #st.tirs, "tourelles des faisceaux posees", pt .. " / " .. #st.tirs)
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret or e.tick < T_CIBLES then return end
    local s = ctx.surface()
    for _, f in ipairs(st.tirs) do
      if not (f.cible and f.cible.valid) then
        f.cible = s.create_entity({ name = "behemoth-biter", force = "enemy", position = { f.cx, f.cy } })
        if f.cible then
          f.cible.active = false
          f.morts = (f.morts or -1) + 1
        end
      end
      -- soignée à chaque tick : aux hauts niveaux, un tir tuait la cible et le faisceau ne se voyait plus (1er essai)
      if f.cible then f.cible.health = f.cible.prototype.max_health end
      if e.tick % 5 == 0 and e.tick >= 120 then
        local h = f.side / 2 + 8
        for _, b in ipairs(s.find_entities_filtered({ area = { { f.x - h, f.y - h }, { f.x + h, f.y + h } }, type = "beam" })) do
          f.vus = f.vus + 1
          f.noms[b.name] = true
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local bons, faux = 0, {}
    for _, f in ipairs(st.tirs) do
      if f.vus > 0 and f.noms[faisceau(f.n)] then
        bons = bons + 1
      else
        local ns = {}
        for k in pairs(f.noms) do ns[#ns + 1] = k end
        table.sort(ns)
        faux[#faux + 1] = string.format("niveau %d %s : %d vu(s) %s", f.n, f.dir, f.vus, table.concat(ns, ","))
      end
    end
    ctx.check(bons == #st.tirs, "faisceau de l'age vu sur chaque site (8 directions, niveaux 1, 3, 11, 19, 27, 29)",
      bons .. " / " .. #st.tirs .. (#faux > 0 and (" ; " .. table.concat(faux, " ; ")) or ""))
    ctx.check(SPR_OK and type(SPR) == "table" and SPR.ages and SPR.ages[15] ~= nil,
      "sprites.lua du laser lu (graphics/levels/laser)", SPR_OK and "lu" or tostring(SPR))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    local L = { "capture\tniveau\tage\tnuit\tx\ty\tgenre" }
    local rangs = {}
    for _, c in ipairs(st.sites) do
      rangs[c.ere] = rangs[c.ere] or {}
      table.insert(rangs[c.ere], c)
    end
    for ere = 1, 5 do
      local r = rangs[ere]
      local x0, x1 = r[1].x - r[1].side / 2, r[#r].x + r[#r].side / 2
      local cx, cy = (x0 + x1) / 2, r[1].y - 0.8
      local w = math.ceil((x1 - x0 + 4) * 32)
      local h = math.ceil((r[1].side + 6) * 32)
      for _, nuit in ipairs({ false, true }) do
        local nm = string.format("ere%d-z1-%s", ere, nuit and "nuit" or "jour")
        add(nm, cx, cy, 1, nuit and 0.5 or 0, { res = { w, h }, info = false, aa = true })
        L[#L + 1] = string.format("%s\t0\t0\t%d\t%.2f\t%.2f\tere", nm, nuit and 1 or 0, cx, cy)
      end
    end
    for i = 1, #st.sites, 2 do
      local a, b = st.sites[i], st.sites[i + 1]
      local cx, cy = (a.x + b.x) / 2, a.y - 0.8
      local w = math.ceil((b.x - a.x + a.side + 3) * 64)
      local h = math.ceil((a.side + 5) * 64)
      for _, nuit in ipairs({ false, true }) do
        local nm = string.format("age%02d-z2-%s", a.age, nuit and "nuit" or "jour")
        add(nm, cx, cy, 2, nuit and 0.5 or 0, { res = { w, h }, info = false, aa = true })
        L[#L + 1] = string.format("%s\t%d\t%d\t%d\t%.2f\t%.2f\tage", nm, a.n, a.age, nuit and 1 or 0, cx, cy)
      end
    end
    game.write_file("fo-shots/f1-lasers-sites.tsv", table.concat(L, "\n") .. "\n", false)
    local F = { "capture\tniveau\tdir\tk\ttx\tty\tcx\tcy\tzoom\tlargeur\thauteur\tL\tH" }
    for _, f in ipairs(st.tirs) do
      local cx, cy = (f.x + f.cx) / 2, (f.y + f.cy) / 2 - 1
      local w, h = 20 * 64, 16 * 64
      local nm = string.format("faisceau-n%02d-%s", f.n, f.dir)
      add(nm, cx, cy, 2, 0, { res = { w, h }, info = false, aa = true })
      local Lb, Hb = 0, 0
      local age = math.floor((f.n + 1) / 2)
      if f.n > 2 and SPR_OK and SPR.ages and SPR.ages[age] then
        Lb, Hb = -SPR.ages[age].tir.source_offset[2], SPR.ages[age].tir.hauteur
      end
      F[#F + 1] = string.format("%s\t%d\t%s\t%d\t%.3f\t%.3f\t%.3f\t%.3f\t2\t%d\t%d\t%.4f\t%.4f", nm, f.n, f.dir, f.k,
        f.x, f.y, cx, cy, w, h, Lb, Hb)
    end
    game.write_file("fo-shots/f1-lasers-faisceaux.tsv", table.concat(F, "\n") .. "\n", false)
  end,
}
