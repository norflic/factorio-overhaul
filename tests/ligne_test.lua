--[[
  Tests hors jeu du lot AGENCEMENT, partie FONDERIE EN LONGUE LIGNE (retour du DC du 29/10 en jouant la 0.6.16 : « le pattern est
  mauvais [...] pas reproductible », « une longue ligne et qui se mettent dans des coffres », coffres « plus proches du centre » pour
  la source de ressources, « vers l'extérieur » pour un flux d'usine). Pur, aucune API Factorio.
  Usage, depuis la racine du mod :   lua5.2 tests/ligne_test.lua

  1. gabarit « smelter » : sans consigne ou « centre », EXACTEMENT celui d'avant (entités, clé, paramètres) ; « exterieur » :
     tapis de sortie vers la tête, contrôles de M.check de 1 rangée au maximum de l'extension, extension qui garde la variante ;
  2. emprise : les rangées qui tiennent dans un lot (Ligne.rows_fit) = ce que P.fit accepte vraiment, aux deux sorties, avec la
     place des bras de sortie ; une rangée de plus est refusée ;
  3. quais de sortie : P.out_quai (1 ou 2 bras), P.out_side, P.port_room : aucun chevauchement ni sortie du lot aux 4 rotations,
     chaque bras prend sur le dernier tuile du tapis et dépose dans son coffre, le second est du côté extérieur ;
  4. règle de taille (Ligne.rows_wanted, budget_rows, sortie_for) : table de cas, bornes une à une, monotonie ;
  5. de bout en bout, sans le moteur : la ligne voulue est nourrie par les foreuses que le gisement porte (Rangees) et ses bras de
     sortie suivent son débit ;
  6. mutants : chaque règle faussée est refusée.
]]
package.path = "./?.lua;" .. package.path

local P = require("shared.team.plan")
local M = require("shared.team.modules")
local Li = require("shared.team.ligne")
local Rg = require("shared.team.rangees")
local T = require("shared.team.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local STONE, STEEL = "stone-furnace", "steel-furnace"
local lat = P.lattice({ x = 0.5, y = 0.5 })
local x0, y0, x1, y1 = P.lot_rect(lat, 3, 3)
local rect = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
local ALL_FREE = function() return true end

--- Bras de sortie par tapis (comme script/team/build.lua, out_arms) : nombre de bras (au plus Li.MAX_ARMS) ou nil.
local function arms_of(g)
  local outn = 0
  for k, v in pairs(g.nominal) do if k ~= "electricity-kw" then outn = outn + v end end
  local nports = 0
  for _, q in ipairs(g.ports) do if q.kind == "tapis" and q.io == "out" then nports = nports + 1 end end
  local ins, cnt = M.choose_inserters(outn / math.max(1, nports), true, Li.MAX_ARMS)
  return ins, cnt
end

local DIRS = { N = { 0, -1 }, E = { 1, 0 }, S = { 0, 1 }, W = { -1, 0 } }

--- Pose g (P.fit, tête tournée vers `dirname`) avec `fan` bras de sortie ; rend le placement et l'instance, ou nil.
local function place(g, dirname, fan)
  local d = DIRS[dirname]
  local toward = { x = cx + d[1] * 70, y = cy + d[2] * 70 }
  local fit = P.fit(g, rect, { toward = toward, head_toward = toward, fan = fan, free = ALL_FREE })
  if not fit then return nil end
  local r = fit.k == 0 and g or M.rotate(g, fit.k)
  return fit, M.instantiate(r, 0, fit.ox, fit.oy)
end

local function ents_of(inst)
  local out = {}
  for _, e in ipairs(inst.entities) do out[#out + 1] = { name = e.name, x = e.position.x, y = e.position.y, dir = e.direction or 0 } end
  return out
end

section("1. Gabarit « smelter » : l'ancien inchangé, la variante « exterieur »")
do
  local function same(a, b)
    if #a.entities ~= #b.entities then return false end
    for i, e in ipairs(a.entities) do
      local f = b.entities[i]
      if e.name ~= f.name or e.x ~= f.x or e.y ~= f.y or e.dir ~= f.dir or e.recipe ~= f.recipe then return false end
    end
    return true
  end
  for _, furnace in ipairs({ STONE, STEEL }) do
    for n = 1, 8 do
      local g0 = M.GEN.smelter(furnace, "iron-ore", n)
      local g1 = M.GEN.smelter(furnace, "iron-ore", n, "centre")
      local g2 = M.GEN.smelter(furnace, "iron-ore", n, nil)
      check(g0 and g1 and g2 and same(g0, g1) and same(g0, g2) and g0.key == g1.key and #g0.args == 3 and #g1.args == 3,
        furnace .. " n=" .. n .. " : sans consigne = « centre » = le gabarit d'avant (3 paramètres, même clé)")
    end
  end
  local g = M.GEN.smelter(STONE, "iron-ore", 3)
  check(g.key == "fonderie-fer-pierre" and g.params.n == 3, "la clé d'avant reste « fonderie-fer-pierre »")
  local bad, why = M.GEN.smelter(STONE, "iron-ore", 3, "ailleurs")
  check(bad == nil and type(why) == "string" and why:find("sortie"), "sortie inconnue refusée avec une raison (" .. tostring(why) .. ")")
  for _, furnace in ipairs({ STONE, STEEL }) do
    local gc = M.GEN.smelter(furnace, "iron-ore", 1)
    local top = gc.extensions[1].max
    for n = 1, top do
      local ge = M.GEN.smelter(furnace, "iron-ore", n, "exterieur")
      local gc2 = M.GEN.smelter(furnace, "iron-ore", n)
      check(ge ~= nil and #M.check(ge) == 0, furnace .. " exterieur n=" .. n .. " : M.check sans défaut" .. (ge and #M.check(ge) > 0 and (" : " .. M.check(ge)[1]) or ""))
      if ge and gc2 then
        check(ge.key == gc2.key .. "-ext" and ge.args[4] == "exterieur" and #ge.args == 4, "clé et paramètres de la variante")
        check(#ge.entities == #gc2.entities and ge.w == gc2.w and ge.h == gc2.h, "même nombre d'entités, même emprise")
        local a, b = ge.nominal[M.PLATE_OF["iron-ore"]], gc2.nominal[M.PLATE_OF["iron-ore"]]
        check(a == b and a > 0, "même production nominale (" .. tostring(a) .. ")")
        -- ports : l'entrée au nord (dir S) ; les deux sorties AU NORD aussi (dir N), c'est-à-dire à la tête
        local inst = M.instantiate(ge, 0, 0, 0)
        local nout, ok_head = 0, true
        for _, p in ipairs(P.belt_ports(inst)) do
          if p.io == "in" then check(p.y == 0 and p.dir == M.S, "l'entrée est à la tête") end
          if p.io == "out" then nout = nout + 1; ok_head = ok_head and p.y == 0 and p.dir == M.N end
        end
        check(nout == 2 and ok_head, "les deux sorties finissent à la tête, tournées vers l'extérieur")
        -- l'extension garde la variante
        if n < top then
          local g3 = M.extend(ge, n + 1)
          check(g3 and g3.args[4] == "exterieur" and g3.key:sub(-4) == "-ext", "M.extend garde la variante")
        end
      end
    end
  end
end

section("2. Emprise : rangées au plus (Ligne.rows_fit) = ce que P.fit accepte")
do
  check(Li.rows_fit(24, 1, 3, 2, 2) == 9, "lot de 24, tête 3, quai 2, four de 2 : 9 rangées")
  check(Li.rows_fit(24, 1, 3, 0, 2) == 10, "sortie à la tête (rien au bout) : 10 rangées")
  check(Li.rows_fit(24, 1, 3, 2, 3) == 6 and Li.rows_fit(24, 1, 3, 2, 0) == 0 and Li.rows_fit(nil, 1, 3, 2, 2) == 0, "autres côtés, entrées absurdes")
  for _, furnace in ipairs({ STONE, STEEL }) do
    for _, sortie in ipairs({ "centre", "exterieur" }) do
      local side = M.spec(furnace).w
      local want = Li.rows_fit(P.LOT, 1, P.FEED_DEPTH, sortie == "centre" and 2 or 0, side)
      local best = 0
      local top = M.GEN.smelter(furnace, "iron-ore", 1).extensions[1].max
      for rows = 1, math.min(12, top + 3) do
        local g = M.GEN.smelter(furnace, "iron-ore", rows, sortie)
        if g then
          local _, arms = arms_of(g)
          local fit = place(g, "N", arms)
          local fit2 = place(g, "E", arms)
          if fit and fit2 then best = rows end
          check((fit ~= nil) == (fit2 ~= nil), string.format("%s %s %d rangées : tenir ne dépend pas de l'orientation", furnace, sortie, rows))
        end
      end
      -- le gabarit existe au-delà de la borne de son extension (débits des voies) : P.fit s'y arrête quand même à rows_fit
      check(best == math.min(want, top + 3), string.format("%s %s : P.fit accepte jusqu'à %d rangées, Ligne.rows_fit dit %d (essai jusqu'à %d)", furnace, sortie, best, want, top + 3))
    end
  end
end

section("3. Quais de sortie : un ou deux bras, aux quatre rotations")
do
  local function inside(e)
    for _, t in ipairs(P.tiles_of(e)) do
      if t[1] < x0 or t[1] >= x1 or t[2] < y0 or t[2] >= y1 then return false end
    end
    return true
  end
  local tested = 0
  for _, sortie in ipairs({ "centre", "exterieur" }) do
    for _, rows in ipairs({ 2, 5, 9 }) do
      for _, dn in ipairs({ "N", "E", "S", "W" }) do
        local g = M.GEN.smelter(STONE, "iron-ore", rows, sortie)
        local _, arms = arms_of(g)
        local fit, inst = place(g, dn, arms)
        local tag = string.format("%s %d rangées tête %s", sortie, rows, dn)
        if rows > Li.rows_fit(P.LOT, 1, P.FEED_DEPTH, sortie == "centre" and 2 or 0, 2) then
          check(fit == nil, tag .. " : plus grand que le lot, refusé")
        elseif check(fit ~= nil, tag .. " : posée") == nil and fit then
          tested = tested + 1
          local list = ents_of(inst)
          local all = {}
          for _, e in ipairs(list) do all[#all + 1] = e end
          local nq = 0
          for _, port in ipairs(P.belt_ports(inst)) do
            if port.io == "out" then
              local sd = P.out_side(inst, port)
              local q = P.out_quai(port, "inserter", arms, arms > 1 and sd or nil)
              check(#q == 2 * arms, tag .. " : 2 entités par bras")
              for i = 1, #q, 2 do
                local arm, chest = q[i], q[i + 1]
                nq = nq + 1
                local dv = P.DV[arm.dir]
                local pick = { math.floor(arm.x) + dv[1], math.floor(arm.y) + dv[2] }
                check(pick[1] == port.x and pick[2] == port.y, tag .. " : le bras prend sur le dernier tuile du tapis")
                check(math.floor(chest.x) == math.floor(arm.x) - dv[1] and math.floor(chest.y) == math.floor(arm.y) - dv[2],
                  tag .. " : le coffre est de l'autre côté du bras")
                check(arm.role == "sortie-bras" and chest.role == "sortie", tag .. " : rôles")
              end
              for _, e in ipairs(q) do all[#all + 1] = e end
              if arms > 1 then
                -- le second bras est du côté EXTÉRIEUR : hors de la boîte du module
                local lat_arm = q[3]
                local ox0, oy0 = fit.ox, fit.oy
                local outside = lat_arm.x < ox0 or lat_arm.x > ox0 + inst.w or lat_arm.y < oy0 or lat_arm.y > oy0 + inst.h
                check(outside, tag .. " : le second bras est hors du module")
              end
            end
          end
          check(nq == 2 * arms, tag .. " : un quai par tapis de sortie (" .. nq .. ")")
          -- la tête d'alimentation (quais des deux voies), comme le plan : pas de chevauchement non plus
          for _, ip in ipairs(P.belt_ports(inst)) do
            if ip.io == "in" then
              local fd = P.feeder(ip, { "quai", "quai" }, "inserter", nil)
              for _, e in ipairs(fd.entities) do all[#all + 1] = e end
            end
          end
          check(#P.overlaps(all) == 0, tag .. " : aucun chevauchement (module, quais, tête)")
          local inl = true
          for _, e in ipairs(all) do inl = inl and inside(e) end
          check(inl, tag .. " : tout reste dans le lot")
          -- la réserve de P.port_room couvre exactement les tuiles des quais de sortie
          local room = {}
          for _, t in ipairs(P.port_room(inst, arms)) do room[P.tkey(t[1], t[2])] = true end
          local cover = true
          for _, e in ipairs(all) do
            if e.role == "sortie-bras" or e.role == "sortie" then
              for _, t in ipairs(P.tiles_of(e)) do cover = cover and room[P.tkey(t[1], t[2])] == true end
            end
          end
          check(cover, tag .. " : P.port_room réserve les tuiles des quais")
        end
      end
    end
  end
  check(tested >= 20, "assez de poses essayées (" .. tested .. ")")
  -- sans fan : port_room et out_quai exactement comme avant le lot
  local g = M.GEN.smelter(STONE, "iron-ore", 3)
  local _, inst = place(g, "S", 1)
  local old = {}
  for _, p in ipairs(P.belt_ports(inst)) do
    local v = P.DV[p.dir]
    if p.io == "in" then
      local lx, ly = v[2], -v[1]
      for k = 1, P.FEED_DEPTH do for s = -2, 2 do old[#old + 1] = { p.x - k * v[1] + s * lx, p.y - k * v[2] + s * ly } end end
    else
      for k = 1, 2 do old[#old + 1] = { p.x + k * v[1], p.y + k * v[2] } end
    end
  end
  local cur = P.port_room(inst)
  local same = #cur == #old
  for i = 1, math.min(#cur, #old) do same = same and cur[i][1] == old[i][1] and cur[i][2] == old[i][2] end
  check(same, "port_room sans fan = la réserve d'avant")
  local q = P.out_quai({ x = 10, y = 20, dir = 4 })
  check(#q == 2 and q[1].x == 10.5 and q[1].y == 21.5 and q[1].dir == 0 and q[2].x == 10.5 and q[2].y == 22.5 and q[1].name == "inserter",
    "out_quai sans compte = le quai d'avant")
end

--- Règles de taille : la suite de contrôles passe sur `L` (la vraie ou un mutant) ; rend le nombre d'échecs.
local function suite(L, verbose)
  local bad = 0
  local function ck(cond, msg) if not cond then bad = bad + 1; if verbose then print("  ECHEC : " .. msg) end end end
  -- sortie
  ck(L.sortie_for("usine") == "exterieur", "usine : coffres vers l'extérieur")
  ck(L.sortie_for("base") == "centre" and L.sortie_for(nil) == "centre" and L.sortie_for("n'importe quoi") == "centre", "base ou inconnu : centre")
  -- emprise
  ck(L.rows_fit(24, 1, 3, 2, 2) == 9 and L.rows_fit(24, 1, 3, 0, 2) == 10, "rangées dans un lot")
  -- budget
  ck(L.budget_rows(0, 80, 0.5, 2) == 2, "sans plaques : la base (2)")
  ck(L.budget_rows(nil, 80, 0.5, 2) == 2, "stock inconnu : la base")
  ck(L.budget_rows(480, 80, 0.5, 2) == 3, "480 plaques, la moitié : 3 rangées")
  ck(L.budget_rows(1600, 80, 0.5, 2) == 10, "1 600 plaques : 10 rangées")
  ck(L.budget_rows(1600, 0, 0.5, 2) == 2 and L.budget_rows(1600, 80, 0, 2) == 2, "coût ou part nuls : la base")
  ck(L.budget_rows(1600, 80, 5, 2) == L.budget_rows(1600, 80, 1, 2), "la part est bornée à 1")
  local prev = 0
  for stock = 0, 3000, 100 do
    local b = L.budget_rows(stock, 80, 0.5, 2)
    ck(b >= prev, "budget monotone en stock (" .. stock .. ")")
    prev = b
  end
  -- taille de la ligne
  local base = { rows_rate = 4, pairs_dep = 6, drill_rate = 0.5, cap = 0.3125, pairs_line = 7, rows_max = 12, rows_fit = 9, grow = true }
  local function with(t) local s = {} for k, v in pairs(base) do s[k] = v end for k, v in pairs(t) do s[k] = v end return s end
  local r, why = L.rows_wanted(with({}))
  ck(r == 9 and why == "gisement", "gisement de 6 paires, 4 rangées demandées : 9 rangées (" .. tostring(r) .. " " .. tostring(why) .. ")")
  r, why = L.rows_wanted(with({ grow = false }))
  ck(r == 4 and why == "demande", "croissance éteinte : la demande (le comportement d'avant)")
  r, why = L.rows_wanted(with({ pairs_dep = 0 }))
  ck(r == 4 and why == "demande", "gisement inconnu : la demande")
  r, why = L.rows_wanted(with({ pairs_dep = 2 }))
  ck(r == 4 and why == "demande", "petit gisement (2 paires = 3 rangées) : jamais sous la demande")
  r, why = L.rows_wanted(with({ pairs_dep = 7, pairs_line = 5 }))
  ck(r == 8, "une ligne de foreuses ne porte que 5 paires : 8 rangées (" .. tostring(r) .. ")")
  r, why = L.rows_wanted(with({ pairs_dep = 7, rows_fit = 9 }))
  ck(r == 9 and why == "emprise", "7 paires = 11 rangées, le lot en tient 9 : emprise (" .. tostring(r) .. " " .. tostring(why) .. ")")
  r, why = L.rows_wanted(with({ pairs_dep = 7, rows_max = 6, rows_fit = 9 }))
  ck(r == 6 and why == "emprise", "borne du gabarit")
  r, why = L.rows_wanted(with({ budget_rows = 5 }))
  ck(r == 5 and why == "budget", "budget de 5 rangées")
  r, why = L.rows_wanted(with({ budget_rows = 2 }))
  ck(r == 4 and why == "budget", "budget sous la demande : la demande, jamais moins (la raison dit ce qui a retenu la croissance)")
  r, why = L.rows_wanted(with({ out_ok = function(n) return n <= 7 end }))
  ck(r == 7 and why == "sortie", "bras de sortie qui ne suivent que 7 rangées")
  r, why = L.rows_wanted(with({ out_ok = function(n) return n <= 3 end }))
  ck(r == 4 and why == "sortie", "bras qui ne suivent même pas la demande : la demande, sans croissance")
  r, why = L.rows_wanted(with({ rows_rate = 11, rows_fit = 9 }))
  ck(r == 9, "demande plus grande que le lot : ramenée à ce qui tient (" .. tostring(r) .. ")")
  r, why = L.rows_wanted(with({ rows_rate = 0 }))
  ck(r >= 1, "demande nulle : au moins une rangée")
  -- invariants sur un balayage : bornes respectées, jamais sous la demande tenable, déterministe, monotone en gisement
  local last = 0
  for pd = 0, 7 do
    for rate = 1, 10 do
      for bud = 1, 12, 3 do
        local s = with({ pairs_dep = pd, rows_rate = rate, budget_rows = bud })
        local rows = L.rows_wanted(s)
        local rows2 = L.rows_wanted(s)
        ck(rows == rows2, "déterministe")
        ck(rows >= 1 and rows <= 9, string.format("bornes (gisement %d, demande %d, budget %d) : %d", pd, rate, bud, rows))
        ck(rows >= math.min(rate, 9), string.format("jamais sous la demande tenable (%d, %d) : %d", pd, rate, rows))
        if rows > rate then
          ck(rows <= bud, string.format("au-delà de la demande, le budget borne (%d > %d)", rows, bud))
          ck(Rg.pairs_for_rows(rows, 0.5, 0.3125) <= math.min(pd, 7), string.format("les foreuses du gisement nourrissent la ligne (%d rangées, %d paires)", rows, pd))
        end
      end
    end
    local rows = L.rows_wanted(with({ pairs_dep = pd, rows_rate = 1, budget_rows = 12 }))
    ck(rows >= last, "monotone en gisement (" .. pd .. ")")
    last = rows
  end
  -- disposition des bras
  local f1, f2 = L.fan(1), L.fan(2)
  ck(#f1 == 1 and f1[1].arm[1] == 1 and f1[1].chest[1] == 2 and f1[1].arm[2] == 0, "un bras : devant le bout")
  ck(#f2 == 2 and f2[2].arm[1] == 0 and f2[2].arm[2] == 1 and f2[2].chest[2] == 2 and f2[2].drop[2] == 1, "deux bras : le second sur le côté extérieur")
  ck(#L.fan(nil) == 1 and #L.fan(5) == 2, "compte absent : un bras ; au plus deux")
  ck(L.MAX_ARMS == 2, "deux bras au plus")
  return bad
end

section("4. Règle de taille")
do
  local bad = suite(Li, true)
  check(bad == 0, "la suite de contrôles passe sur les règles réelles (" .. bad .. " échec(s))")
  local cfg = T.ligne
  check(type(cfg) == "table" and cfg.grow == true and cfg.cover == 0.8 and cfg.top_lots >= 1 and cfg.rows_floor >= 1 and cfg.row_cost > 0
    and cfg.stock_share > 0 and cfg.stock_share <= 1, "réglages T.ligne présents et sensés")
end

section("5. De bout en bout, sans le moteur")
do
  -- pour chaque gisement (paires portées) et chaque four : la ligne voulue existe, passe M.check, tient dans un lot avec ses bras,
  -- et ses foreuses (Rangees.pairs_for_rows) ne dépassent pas ce que le gisement porte
  local dsp = M.spec(T.DRILL_ELECTRIC)
  local g_drill = M.GEN.drills("iron-ore", 1)
  local pairs_line = g_drill.extensions[1].max
  check(pairs_line == 7, "une ligne de foreuses : 7 paires au plus")
  local cases = 0
  for _, furnace in ipairs({ STONE, STEEL }) do
    for _, sortie in ipairs({ "centre", "exterieur" }) do
      local g0 = M.GEN.smelter(furnace, "iron-ore", 2, sortie)
      local cap = g0.nominal["iron-plate"] / (2 * 2)
      for pd = 0, 7 do
        for _, stock in ipairs({ 0, 400, 5000 }) do
          local rows = Li.rows_wanted({
            rows_rate = 2, pairs_dep = pd, drill_rate = dsp.speed, cap = cap, pairs_line = pairs_line, rows_max = g0.extensions[1].max, grow = true,
            rows_fit = Li.rows_fit(P.LOT, 1, P.FEED_DEPTH, sortie == "centre" and 2 or 0, M.spec(furnace).w),
            out_ok = function(r) return M.choose_inserters(r * cap, true, Li.MAX_ARMS) ~= nil end,
            budget_rows = Li.budget_rows(stock, T.ligne.row_cost, T.ligne.stock_share, T.ligne.rows_floor),
          })
          local g = M.GEN.smelter(furnace, "iron-ore", rows, sortie)
          local tag = string.format("%s %s gisement %d, stock %d, %d rangées", furnace, sortie, pd, stock, rows)
          check(g ~= nil and #M.check(g) == 0, tag .. " : gabarit valide")
          if g then
            local ins, arms = arms_of(g)
            check(ins ~= nil, tag .. " : les bras de sortie suivent le débit")
            check(place(g, "N", arms) ~= nil, tag .. " : tient dans un lot")
            if rows > 2 then check(Rg.pairs_for_rows(rows, dsp.speed, cap) <= pd, tag .. " : nourrie par les foreuses du gisement") end
            cases = cases + 1
          end
        end
      end
    end
  end
  check(cases == 96, "tous les cas joués (" .. cases .. ")")
  -- le cas du DC : 8 fours en réserve, un gisement qui porte 6 paires, un coffre qui a des plaques
  local cap = M.GEN.smelter(STONE, "iron-ore", 2).nominal["iron-plate"] / 4
  local rows = Li.rows_wanted({ rows_rate = 2, pairs_dep = 6, drill_rate = dsp.speed, cap = cap, pairs_line = 7, rows_max = 12, rows_fit = 9,
    out_ok = function(r) return M.choose_inserters(r * cap, true, Li.MAX_ARMS) ~= nil end, budget_rows = Li.budget_rows(1200, 80, 0.5, 2), grow = true })
  check(rows == 7, "1 200 plaques en réserve, 6 paires au gisement : 7 rangées (14 fours), pas 4 fours (" .. rows .. ")")
end

section("6. Mutants")
do
  local mutants = {
    { "sortie : usine => centre", function(L) L.sortie_for = function() return "centre" end end },
    { "sortie : tout vers l'extérieur", function(L) L.sortie_for = function() return "exterieur" end end },
    { "emprise : tête oubliée", function(L) L.rows_fit = function(lot, m, h, t, s) return math.floor((lot - math.max(m, t)) / s) end end },
    { "emprise : quai oublié", function(L) L.rows_fit = function(lot, m, h, t, s) return math.floor((lot - math.max(m, h)) / s) end end },
    { "budget : plancher oublié", function(L) local f = L.budget_rows; L.budget_rows = function(a, b, c, d) return math.min(f(a, b, c, d), math.floor((a or 0) * c / b)) end end },
    { "budget : part ignorée", function(L) L.budget_rows = function(st, rc, sh, fl) return math.max(fl, math.floor((st or 0) / rc)) end end },
    { "taille : budget ignoré", function(L) local f = L.rows_wanted; L.rows_wanted = function(s) local t = {} for k, v in pairs(s) do t[k] = v end t.budget_rows = nil return f(t) end end },
    { "taille : bras de sortie ignorés", function(L) local f = L.rows_wanted; L.rows_wanted = function(s) local t = {} for k, v in pairs(s) do t[k] = v end t.out_ok = nil return f(t) end end },
    { "taille : emprise du lot ignorée", function(L) local f = L.rows_wanted; L.rows_wanted = function(s) local t = {} for k, v in pairs(s) do t[k] = v end t.rows_fit = nil return f(t) end end },
    { "taille : gisement ignoré", function(L) local f = L.rows_wanted; L.rows_wanted = function(s) local t = {} for k, v in pairs(s) do t[k] = v end t.pairs_dep = 0 return f(t) end end },
    { "taille : sous la demande", function(L) local f = L.rows_wanted; L.rows_wanted = function(s) local r, w = f(s) return math.max(1, r - 1), w end end },
    { "taille : croissance toujours allumée", function(L) local f = L.rows_wanted; L.rows_wanted = function(s) local t = {} for k, v in pairs(s) do t[k] = v end t.grow = true return f(t) end end },
    { "taille : ligne de foreuses non bornée", function(L) local f = L.rows_wanted; L.rows_wanted = function(s) local t = {} for k, v in pairs(s) do t[k] = v end t.pairs_line = nil return f(t) end end },
    { "bras : un seul", function(L) L.fan = function() return { { arm = { 1, 0 }, chest = { 2, 0 }, drop = { 1, 0 } } } end end },
    { "bras : second du mauvais côté", function(L) L.fan = function(c) local o = { { arm = { 1, 0 }, chest = { 2, 0 }, drop = { 1, 0 } } } if (c or 1) >= 2 then o[2] = { arm = { 0, -1 }, chest = { 0, -2 }, drop = { 0, -1 } } end return o end end },
    { "bras : trois", function(L) L.MAX_ARMS = 3 end },
  }
  local survivors = 0
  for _, m in ipairs(mutants) do
    local L = {}
    for k, v in pairs(Li) do L[k] = v end
    m[2](L)
    local bad = suite(L, false)
    check(bad > 0, "mutant refusé : " .. m[1])
    if bad == 0 then survivors = survivors + 1 end
  end
  check(survivors == 0, "aucun mutant survivant")
  print(string.format("[LIGNE] mutants : %d refusés sur %d", #mutants - survivors, #mutants))
end

print(string.format("[LIGNE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
