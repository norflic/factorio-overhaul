--[[
  Tests hors jeu du lot LAYOUT (shared/team/layout_mine.lua) : agencement d'un champ de minerai en lignes de foreuses et
  couloirs de tapis.
  Usage, depuis la racine du mod :   lua5.2 tests/layout_mine_test.lua

  Vérifie : décalages de couverture (côtés 2 à 5), champ plein couvert en entier (4 tailles de foreuse, avec et sans colonne
  de poteaux), obstacles (lac), deux ressources collées (aucune foreuse sur les deux), coupe du couloir en deux sorties
  quand une voie déborde, foreuses retirées quand une seule ne tient pas, mode "single" (nombre de foreuses, sortie la plus
  proche), déterminisme, translation et renommage (aucun nom du jeu), FORCE BRUTE sur de petits champs (optimum d'une ligne
  unique, toutes positions et sous-ensembles), champs aléatoires contrôlés par un validateur indépendant, puis MUTANTS
  (chacun est refusé par la batterie).
]]

package.path = "./?.lua;" .. package.path
local LM = require("shared.team.layout_mine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local tk = LM.tkey
local function rect(x0, y0, x1, y1, res, amount, t)
  t = t or {}
  for x = x0, x1 do for y = y0, y1 do t[#t + 1] = { x = x, y = y, res = res, amount = amount or 100 } end end
  return t
end
local BIG = { x0 = -4, y0 = -4, x1 = 24, y1 = 18 }
local D3 = { w = 3, reach = 2.49, speed = 0.5, drop = { 0, -1.85 } }
-- sortie vers le nord (vecteur du prototype) : un côté pair dépose à une demi-tuile du milieu
local D2 = { w = 2, reach = 0.99, speed = 0.25, drop = { -0.5, -1.3 } }
local DRILLS = { D2, D3, { w = 4, reach = 2.99, speed = 1, drop = { -0.5, -2.35 } }, { w = 5, reach = 3.49, speed = 1.5, drop = { 0, -2.85 } } }

-- RNG maison (congruentiel) : aucun math.random
local function rng(seed)
  local s = seed
  return function(n)
    s = (s * 1664525 + 1013904223) % 4294967296
    return math.floor(s / 65536) % n
  end
end

local function serialize(p)
  local t = {}
  for _, d in ipairs(p.drills) do t[#t + 1] = string.format("D%d,%d,%d", d.ox, d.oy, d.dir) end
  for _, b in ipairs(p.belts) do t[#t + 1] = string.format("B%d,%d,%d", b.x, b.y, b.dir) end
  for _, e in ipairs(p.exits) do t[#t + 1] = string.format("E%d,%d,%d", e.x, e.y, e.dir) end
  return table.concat(t, ";")
end

---------------------------------------------------------------------------------------------------
-- Batterie : tout ce qu'un plan correct doit vérifier ; rend la liste des contrôles ratés (vide : correct).
-- Elle reçoit le module (original ou MUTANT).
---------------------------------------------------------------------------------------------------
local function battery(M)
  local bad = {}
  local function ck(cond, name) if not cond then bad[#bad + 1] = name end end
  local function errs(p, f, d, o) return M.check(p, f, d, o) end

  -- champ plein, 4 tailles, avec et sans colonne de poteaux : tout est capté, plan valide
  for _, d in ipairs(DRILLS) do
    for gap = 0, 1 do
      local f = { tiles = rect(0, 0, 19, 13, "a"), bounds = BIG }
      local p = M.plan(f, d, { gap = gap })
      ck(p ~= nil, "plein w" .. d.w .. " plan")
      if p then
        ck(#errs(p, f, d, { gap = gap, strict_active = true }) == 0, "plein w" .. d.w .. " gap" .. gap .. " valide")
        ck(p.covered == p.total, "plein w" .. d.w .. " gap" .. gap .. " tout capte")
      end
    end
  end

  -- lac
  do
    local bl = {}
    for x = 7, 12 do for y = 4, 9 do bl[tk(x, y)] = true end end
    local f = { tiles = rect(0, 0, 19, 13, "a"), blocked = bl, bounds = BIG }
    local p = M.plan(f, D3, { gap = 1 })
    ck(p ~= nil, "lac plan")
    if p then
      ck(#errs(p, f, D3, { gap = 1, strict_active = true }) == 0, "lac valide")
      ck(p.covered >= 0.9 * p.total, "lac couverture >= 90 %")
    end
  end

  -- deux ressources collées
  do
    local t = rect(0, 0, 9, 13, "a")
    rect(10, 0, 19, 13, "b", 100, t)
    local f = { tiles = t, bounds = BIG }
    local p = M.plan(f, D3, { gap = 1 })
    ck(p ~= nil, "mixte plan")
    if p then
      ck(#errs(p, f, D3, { gap = 1, strict_active = true }) == 0, "mixte valide (jamais deux ressources)")
      local seen = {}
      for _, d in ipairs(p.drills) do seen[d.res] = true end
      ck(seen.a and seen.b, "mixte : les deux ressources sont exploitees")
      ck(p.covered >= 0.9 * p.total, "mixte couverture >= 90 %")
    end
  end

  -- débit : foreuses rapides, tapis jaune : une voie porte 2 foreuses de 3,5/s ; couloir long coupé en deux sorties
  do
    local d = { w = 3, reach = 2.49, speed = 3.5 }
    local f = { tiles = rect(0, 0, 4, 59, "a"), bounds = { x0 = -4, y0 = -2, x1 = 9, y1 = 62 } }
    local p = M.plan(f, d, { gap = 1, belt_rate = 15, axes = { "V" } })
    ck(p ~= nil, "debit plan")
    if p then
      ck(#errs(p, f, d, { gap = 1, belt_rate = 15 }) == 0, "debit : aucune voie au-dessus de 7,5/s")
      local two = false
      for _, st in ipairs(p.strips) do if #st.exits == 2 then two = true end end
      ck(two, "debit : un couloir est coupe en deux sorties")
      for _, st in ipairs(p.strips) do ck(#st.drills <= 8, "debit : au plus 8 foreuses par couloir") end
      local p2 = M.plan(f, d, { gap = 1, belt_rate = 60, axes = { "V" } })
      ck(p2 and p2.covered > p.covered, "debit : un tapis plus rapide capte davantage de minerai avec moins de lignes")
    end
    -- une seule foreuse dépasse déjà la voie : rien n'est posé
    local f2 = { tiles = rect(0, 0, 9, 9, "a"), bounds = BIG }
    local p3 = M.plan(f2, { w = 3, reach = 2.49, speed = 8 }, { belt_rate = 15 })
    ck(p3 == nil, "debit : une foreuse a 8/s ne tient pas sur une voie de 7,5/s")
  end

  -- mode single : nombre de foreuses, sortie la plus proche
  do
    local f = { tiles = rect(0, 0, 13, 13, "a"), bounds = { x0 = -4, y0 = -4, x1 = 18, y1 = 18 } }
    local p = M.plan(f, D3, { mode = "single", max_drills = 5 })
    ck(p ~= nil and p.drills_n == 5 and p.strips_n == 1 and #p.exits == 1, "single : 5 foreuses, 1 ligne, 1 sortie")
    if p then ck(#errs(p, f, D3, {}) == 0, "single valide") end
    local pw = M.plan(f, D3, { mode = "single", max_drills = 4, toward = { x = -50, y = 7 } })
    local pe = M.plan(f, D3, { mode = "single", max_drills = 4, toward = { x = 90, y = 7 } })
    local pn = M.plan(f, D3, { mode = "single", max_drills = 4, toward = { x = 7, y = -90 } })
    local ps = M.plan(f, D3, { mode = "single", max_drills = 4, toward = { x = 7, y = 90 } })
    if pw and pe and pn and ps then
      ck(pw.exits[1].dir == 6 and pe.exits[1].dir == 2 and pn.exits[1].dir == 0 and ps.exits[1].dir == 4,
        "single : la sortie regarde vers la destination (O, E, N, S)")
    else
      ck(false, "single : plans vers 4 destinations")
    end
  end

  -- couloir fermé aux deux bouts par un mur : aucune ligne dans cet axe (jamais un tapis qui n'aboutit pas) ; l'autre axe sert
  do
    local bl = {}
    for x = -4, 24 do bl[tk(x, 14)] = true; bl[tk(x, -1)] = true end
    local f = { tiles = rect(0, 0, 19, 13, "a"), blocked = bl, bounds = BIG }
    local pv = M.plan(f, D3, { gap = 1, axes = { "V" } })
    local inside = false
    for _, bt in ipairs(pv and pv.belts or {}) do if bt.y >= 0 and bt.y <= 13 then inside = true end end
    ck(not inside, "mur horizontal : aucun tapis vertical entre les murs (bouts fermes)")
    if pv then ck(#errs(pv, f, D3, { gap = 1, strict_active = true }) == 0, "mur horizontal V valide") end
    local p = M.plan(f, D3, { gap = 1 })
    ck(p ~= nil, "mur horizontal : plan")
    if p then ck(#errs(p, f, D3, { gap = 1, strict_active = true }) == 0, "mur horizontal valide") end
  end

  -- sortie enfermée : un mur juste AU-DELÀ de la zone au nord et au sud ferme tous les couloirs verticaux ; au sud seulement,
  -- les couloirs sortent par le nord ; jamais un tapis qui débouche sur un obstacle (le tapis de liaison n'aurait aucun chemin)
  do
    local bl = {}
    for x = -10, 30 do bl[tk(x, BIG.y0 - 1)] = true; bl[tk(x, BIG.y1)] = true end
    local f = { tiles = rect(0, 0, 19, 13, "a"), blocked = bl, bounds = BIG }
    local pv = M.plan(f, D3, { gap = 1, axes = { "V" } })
    ck(pv == nil or #errs(pv, f, D3, { gap = 1 }) == 0, "murs au-dela, nord et sud : aucun couloir vertical n'y debouche")
    ck(pv == nil, "murs au-dela, nord et sud : pas de plan vertical")
    local ps = M.plan(f, D3, { mode = "single", max_drills = 3, axes = { "V" }, toward = { x = 8, y = 90 } })
    ck(ps == nil, "single, murs au-dela : pas de plan vertical")
    local pa = M.plan(f, D3, { gap = 1 })
    ck(pa ~= nil and #errs(pa, f, D3, { gap = 1 }) == 0, "murs au-dela, nord et sud : les couloirs horizontaux sortent par l'est ou l'ouest")
    local bl2 = {}
    for x = -10, 30 do bl2[tk(x, BIG.y1)] = true end
    local f2 = { tiles = rect(0, 0, 19, 13, "a"), blocked = bl2, bounds = BIG }
    local p2 = M.plan(f2, D3, { mode = "single", max_drills = 3, axes = { "V" }, toward = { x = 8, y = 90 } })
    ck(p2 ~= nil and p2.exits[1].dir == 0 and #errs(p2, f2, D3, {}) == 0, "single, mur au sud seulement : sortie par le nord")
  end

  -- colonne de poteaux : deux foreuses de lignes différentes ne se touchent pas (lignes de remplissage comprises)
  do
    local R = rng(4242)
    for case = 1, 14 do
      local t, bl = {}, {}
      local W, H = 12 + R(12), 10 + R(10)
      for x = 0, W - 1 do
        for y = 0, H - 1 do
          local dx, dy = x - W / 2, y - H / 2
          if (dx * dx) / (W * W / 4) + (dy * dy) / (H * H / 4) < 0.7 + (R(20) - 10) / 100 then
            t[#t + 1] = { x = x, y = y, res = "a", amount = 100 }
          end
        end
      end
      for i = 1, R(5) do bl[tk(R(W), R(H))] = true end
      local f = { tiles = t, blocked = bl, bounds = { x0 = -4, y0 = -4, x1 = W + 5, y1 = H + 5 } }
      local p = M.plan(f, D3, { gap = 1 })
      if p then
        local e = errs(p, f, D3, { gap = 1 })
        ck(#e == 0, "gap 1, champ " .. case .. " : " .. tostring(e[1]))
        ck(#p.pole_tiles >= 2, "gap 1, champ " .. case .. " : des tuiles de poteau restent libres")
      end
    end
  end
  return bad
end

section("Couverture : décalages")
do
  local lo, hi = LM.cover_offsets(3, 2.49)
  check(lo == -1 and hi == 3, "w=3 rayon 2,49 : -1..3 (5 tuiles)")
  lo, hi = LM.cover_offsets(2, 0.99)
  check(lo == 0 and hi == 1, "w=2 rayon 0,99 : 0..1 (2 tuiles)")
  lo, hi = LM.cover_offsets(4, 2.99)
  check(lo == -1 and hi == 4, "w=4 rayon 2,99 : -1..4 (6 tuiles)")
  lo, hi = LM.cover_offsets(5, 3.49)
  check(lo == -1 and hi == 5, "w=5 rayon 3,49 : -1..5 (7 tuiles)")
end

section("Batterie sur le module")
do
  local bad = battery(LM)
  check(#bad == 0, "batterie : " .. table.concat(bad, " ; "))
end

section("Champs pleins : chiffres")
do
  for _, d in ipairs(DRILLS) do
    local f = { tiles = rect(0, 0, 19, 13, "a"), bounds = BIG }
    local p0 = LM.plan(f, d, { gap = 0 })
    local p1 = LM.plan(f, d, { gap = 1 })
    print(string.format("  w=%d : gap 0 -> %d foreuses, %d ligne(s), %.0f %% ; gap 1 -> %d foreuses, %d ligne(s), %.0f %%", d.w,
      p0.drills_n, p0.strips_n, 100 * p0.covered / p0.total, p1.drills_n, p1.strips_n, 100 * p1.covered / p1.total))
  end
end

section("Déterminisme, translation, renommage")
do
  local f = { tiles = rect(0, 0, 19, 13, "a"), bounds = BIG }
  local p1, p2 = LM.plan(f, D3, { gap = 1 }), LM.plan(f, D3, { gap = 1 })
  check(serialize(p1) == serialize(p2), "deux passages identiques")
  -- translation (grandes coordonnées négatives) et renommage de la ressource
  local t = {}
  for _, e in ipairs(f.tiles) do t[#t + 1] = { x = e.x - 90000, y = e.y + 31000, res = "gisement-xyz", amount = e.amount } end
  local f2 = { tiles = t, bounds = { x0 = BIG.x0 - 90000, y0 = BIG.y0 + 31000, x1 = BIG.x1 - 90000, y1 = BIG.y1 + 31000 } }
  local q = LM.plan(f2, D3, { gap = 1 })
  check(q.drills_n == p1.drills_n and q.covered == p1.covered and q.strips_n == p1.strips_n, "translation + renommage : meme plan")
  check(#LM.check(q, f2, D3, { gap = 1 }) == 0, "translation : valide")
  -- quantités inégales : le minerai riche est capté d'abord (gain en quantité)
  local t3 = rect(0, 0, 5, 5, "a", 10)
  rect(12, 0, 17, 5, "a", 1000, t3)
  local f3 = { tiles = t3, bounds = BIG }
  local s = LM.plan(f3, D3, { mode = "single", max_drills = 2 })
  local rich = true
  for _, d in ipairs(s.drills) do if d.x < 11 then rich = false end end
  check(rich, "single, 2 foreuses : sur la tache riche")
  -- aucun minerai / foreuse incomplète
  check(LM.plan({ tiles = {}, bounds = BIG }, D3, {}) == nil, "aucun minerai : pas de plan")
  check(LM.plan(f, { w = 3 }, {}) == nil, "foreuse incomplete : pas de plan")
  check(LM.plan(f, { w = 3, h = 2, reach = 2, speed = 1 }, {}) == nil, "foreuse non carree : pas de plan")
  -- temps de minage par ressource : le débit suit
  local fm = { tiles = rect(0, 0, 9, 9, "lent"), bounds = BIG }
  local pm = LM.plan(fm, D3, { mining_time = { lent = 2 } })
  check(pm and math.abs(pm.drills[1].rate - 0.25) < 1e-9, "temps de minage 2 s : 0,25/s")
end

---------------------------------------------------------------------------------------------------
-- Force brute : optimum d'UNE ligne (tous axes, colonnes, plages, positions et sous-ensembles) sur de petits champs
---------------------------------------------------------------------------------------------------
section("Force brute : une ligne unique, petits champs")
local function brute_single(f, d, huge_cap)
  -- toutes les ligne à une sortie ouverte : plages libres, chaque côté = tous les sous-ensembles de positions disjointes
  local S = { lo = nil }
  local lo, hi = LM.cover_offsets(d.w, d.reach)
  local ore = {}
  for _, t in ipairs(f.tiles) do ore[tk(t.x, t.y)] = t end
  local b = f.bounds
  local w = d.w
  local best = 0
  local function covers(ox, oy)
    local keys, res = {}, nil
    for y = oy + lo, oy + w - 1 + hi do
      for x = ox + lo, ox + w - 1 + hi do
        local o = ore[tk(x, y)]
        if o then
          if res and res ~= o.res then return nil end
          res = o.res
          keys[#keys + 1] = tk(x, y)
        end
      end
    end
    if #keys == 0 then return nil end
    return keys, res
  end
  local function free(x, y)
    return x >= b.x0 and x < b.x1 and y >= b.y0 and y < b.y1 and not (f.blocked and f.blocked[tk(x, y)])
  end
  for _, axis in ipairs({ "V", "H" }) do
    local u0, u1, v0, v1
    if axis == "V" then u0, u1, v0, v1 = b.x0, b.x1, b.y0, b.y1 else u0, u1, v0, v1 = b.y0, b.y1, b.x0, b.x1 end
    for c = u0, u1 - 1 do
      local runs, a = {}, nil
      for v = v0, v1 - 1 do
        local x, y
        if axis == "V" then x, y = c, v else x, y = v, c end
        local fr = free(x, y)
        if fr and not a then a = v end
        if not fr and a then runs[#runs + 1] = { a, v - 1 }; a = nil end
      end
      if a then runs[#runs + 1] = { a, v1 - 1 } end
      for _, r in ipairs(runs) do
        if r[1] == v0 or r[2] == v1 - 1 then
          for _, res in ipairs({ "a", "b" }) do
            -- positions de chaque côté
            local sides = {}
            for _, side in ipairs({ -1, 1 }) do
              local pos = {}
              for p = r[1], r[2] - w + 1 do
                local u = side < 0 and c - w or c + 1
                local ox, oy
                if axis == "V" then ox, oy = u, p else ox, oy = p, u end
                local ok = ox >= b.x0 and oy >= b.y0 and ox + w <= b.x1 and oy + w <= b.y1
                if ok then
                  for yy = oy, oy + w - 1 do for xx = ox, ox + w - 1 do if not free(xx, yy) then ok = false end end end
                end
                if ok then
                  local keys, rr = covers(ox, oy)
                  if keys and rr == res then pos[#pos + 1] = { p = p, keys = keys } end
                end
              end
              -- sous-ensembles de positions disjointes (p espacés d'au moins w)
              local subsets = {}
              local function rec(i, chosen)
                if i > #pos then
                  local set = {}
                  for _, e in ipairs(chosen) do for _, k in ipairs(e.keys) do set[k] = true end end
                  subsets[#subsets + 1] = set
                  return
                end
                rec(i + 1, chosen)
                local last = chosen[#chosen]
                if not last or pos[i].p >= last.p + w then
                  chosen[#chosen + 1] = pos[i]
                  rec(i + 1, chosen)
                  chosen[#chosen] = nil
                end
              end
              rec(1, {})
              sides[#sides + 1] = subsets
            end
            for _, sa in ipairs(sides[1]) do
              for _, sb in ipairs(sides[2]) do
                local n = 0
                for k in pairs(sa) do n = n + 1 end
                for k in pairs(sb) do if not sa[k] then n = n + 1 end end
                if n > best then best = n end
              end
            end
          end
        end
      end
    end
  end
  return best * 100
end

do
  local seed, ratios, equal, worst, cases = 20261028, 0, 0, 1, 0
  local R = rng(seed)
  for _, d in ipairs({ D2, D3 }) do
    local per = d.w == 2 and 14 or 14
    for case = 1, per do
      local t, bl = {}, {}
      local W, H = 5 + R(3), 5 + R(3)
      for x = 0, W - 1 do
        for y = 0, H - 1 do
          if R(100) < 80 then t[#t + 1] = { x = x, y = y, res = "a", amount = 100 } end
        end
      end
      for i = 1, R(4) do bl[tk(R(W), R(H))] = true end
      local f = { tiles = t, blocked = bl, bounds = { x0 = -2, y0 = -2, x1 = W + 3, y1 = H + 3 } }
      if #t >= 4 then
        local want = brute_single(f, d)
        local p = LM.plan(f, d, { mode = "single", min_tiles = 1, belt_rate = 1000 })
        local got = p and p.covered or 0
        cases = cases + 1
        local r = want > 0 and got / want or 1
        ratios = ratios + r
        if got == want then equal = equal + 1 end
        worst = math.min(worst, r)
        check(got <= want, string.format("force brute w=%d cas %d : le glouton (%d) ne depasse pas l'optimum (%d)", d.w, case, got, want))
        if p then check(#LM.check(p, f, d, { belt_rate = 1000 }) == 0, string.format("force brute w=%d cas %d : plan valide", d.w, case)) end
      end
    end
  end
  print(string.format("  %d cas : glouton = optimum d'une ligne dans %d, rapport moyen %.3f, pire %.3f", cases, equal, ratios / cases, worst))
  check(cases >= 20, "au moins 20 cas de force brute")
  check(ratios / cases >= 0.93, "rapport moyen a l'optimum d'une ligne >= 0,93")
  check(worst >= 0.75, "pire rapport a l'optimum d'une ligne >= 0,75")
end

---------------------------------------------------------------------------------------------------
section("Champs aléatoires (blobs, obstacles, deux ressources) : validateur indépendant")
do
  local R = rng(777)
  local bad, n, covsum, totsum = 0, 0, 0, 0
  for case = 1, 40 do
    local t, bl = {}, {}
    local W, H = 10 + R(14), 8 + R(12)
    local mid = 3 + R(W - 6)
    for x = 0, W - 1 do
      for y = 0, H - 1 do
        local dx, dy = x - W / 2, y - H / 2
        if (dx * dx) / (W * W / 4) + (dy * dy) / (H * H / 4) < 0.55 + (R(30) - 15) / 100 then
          t[#t + 1] = { x = x, y = y, res = x < mid and "a" or "b", amount = 50 + R(200) }
        end
      end
    end
    for i = 1, R(14) do bl[tk(R(W), R(H))] = true end
    local d = DRILLS[1 + R(4)]
    local gap = R(2)
    local f = { tiles = t, blocked = bl, bounds = { x0 = -4, y0 = -4, x1 = W + 5, y1 = H + 5 } }
    local o = { gap = gap, belt_rate = (R(2) == 0) and 15 or 30 }
    local p = LM.plan(f, d, o)
    n = n + 1
    if p then
      local e = LM.check(p, f, d, { gap = gap, belt_rate = o.belt_rate })
      if #e > 0 then bad = bad + 1; print("  " .. e[1]) end
      covsum, totsum = covsum + p.covered, totsum + p.total
    end
  end
  check(bad == 0, bad .. " plan(s) invalide(s) sur 40")
  print(string.format("  40 champs : captation moyenne %.1f %% du minerai de la zone", 100 * covsum / totsum))
  check(covsum / totsum >= 0.8, "captation moyenne >= 80 %")
end

---------------------------------------------------------------------------------------------------
section("Mutants : la batterie les refuse")
do
  local f = io.open("shared/team/layout_mine.lua", "rb")
  local src = f:read("*a")
  f:close()
  local function mutate(old, new)
    local i, j = src:find(old, 1, true)
    if not i then return nil, "motif absent" end
    if src:find(old, j + 1, true) then return nil, "motif en double" end
    return src:sub(1, i - 1) .. new .. src:sub(j + 1)
  end
  local MUTANTS = {
    { "deux ressources acceptees", "            if res and res ~= o.res then ok = false end\n            res = o.res\n            keys[#keys + 1] = tk(x, y)\n            amount",
      "            res = o.res\n            keys[#keys + 1] = tk(x, y)\n            amount" },
    { "voie sans limite de debit", "while load > S.lane_cap + EPS and #m > 0 do", "while false and #m > 0 do" },
    { "obstacle ignore sous la foreuse", "for x = ox, ox + w - 1 do if S.blocked(x, y) then ok = false end end", "for x = ox, ox + w - 1 do end" },
    { "couloir sur obstacle", "local f = tile_free(S, x, y)\n    if f and not a", "local f = true\n    if f and not a" },
    { "bords toujours ouverts", "r.lo_open = r.a == v0 and beyond_free(v0 - 1)\n    r.hi_open = r.b == v1 - 1 and beyond_free(v1)", "r.lo_open, r.hi_open = true, true" },
    { "au-dela du bord ignore", "r.lo_open = r.a == v0 and beyond_free(v0 - 1)", "r.lo_open = r.a == v0" },
    { "foreuse inactive acceptee", "if n >= S.min_tiles then\n        sel[#sel + 1] = cands[best]", "if true then\n        sel[#sel + 1] = cands[best]" },
    { "sortie de foreuse sans le demi-pas des cotes pairs", "local x, y = drop[1], drop[2]\n  local rx, ry", "local x, y = 0, drop[2]\n  local rx, ry" },
    { "couverture trop courte", "return math.ceil(c - reach - 0.5 - EPS), floor(c + reach - 0.5 + EPS)", "return math.ceil(c - reach - 0.5 - EPS), floor(c + reach - 1.5 + EPS)" },
    { "colonne de poteaux oubliee", "for y = e.oy - gap, e.oy + w - 1 + gap do\n      for x = e.ox - gap, e.ox + w - 1 + gap do S.keep[tk(x, y)] = true end\n    end",
      "" },
    { "destination ignoree", "elseif cand.dist ~= best.dist then better = cand.dist < best.dist", "elseif false then better = true" },
    { "nombre de foreuses ignore", "local sel = choose_greedy(S, cands, cov, max_n or math.huge)", "local sel = choose_greedy(S, cands, cov, math.huge)" },
    { "pas de coupe en deux sorties", "if ok and j > 0 and j < n and sel[j].dr == sel[j + 1].dr then ok = false end",
      "if ok and j > 0 and j < n then ok = false end" },
    { "tapis non reserve", "for _, bt in ipairs(st.belts) do S.occ[tk(bt.x, bt.y)] = true end", "" },
    { "mauvais sens du tapis", "local FLOW = { V = { low = 0, high = 4 }, H = { low = 6, high = 2 } }", "local FLOW = { V = { low = 4, high = 0 }, H = { low = 6, high = 2 } }" },
    { "foreuse tournee a l'envers", "local FACE = { V = { [-1] = 2, [1] = 6 }, H = { [-1] = 4, [1] = 0 } }", "local FACE = { V = { [-1] = 6, [1] = 2 }, H = { [-1] = 4, [1] = 0 } }" },
  }
  local detected = 0
  for _, m in ipairs(MUTANTS) do
    local code, why = mutate(m[2], m[3])
    if not code then
      check(false, "mutant « " .. m[1] .. " » : " .. why)
    else
      local chunk, err = load(code, "=mutant", "t")
      check(chunk ~= nil, "mutant « " .. m[1] .. " » compile : " .. tostring(err))
      if chunk then
        local ok, M = pcall(chunk)
        local failed
        if ok then
          local ok2, bad = pcall(battery, M)
          failed = (not ok2) or #bad > 0
        else
          failed = true
        end
        if failed then detected = detected + 1 end
        check(failed, "mutant « " .. m[1] .. " » non detecte par la batterie")
      end
    end
  end
  print(string.format("  mutants refuses : %d sur %d", detected, #MUTANTS))
end

print(string.format("[LAYOUT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
