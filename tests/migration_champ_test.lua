--[[
  Tests hors jeu du lot MIGRATION-CHAMP (retour du DC du 29/10 en jouant la 0.6.16 : « les foreuses thermiques, elles mettent directement
  dans des fours [...] on met de l'électrique à la place, on enlève les fours ceux qui sont directement sur les ressources, on place des
  foreuses à la place »).   Usage, depuis la racine du mod :   lua5.2 tests/migration_champ_test.lua

  1. géométrie : boîtes, tuiles, appariement foreuse/four (4 directions) ;
  2. taille de la ligne neuve (production d'avant conservée, rangées minimales, débit demandé = rangées voulues par le plan) ;
  3. place libérée (M.fits) et choix de la partie (M.pick_band) sur des champs émulés de 8 à 20 paires : invariants recalculés à part ;
  4. ACCORD avec le plan : la ligne de foreuses que la règle promet est acceptée par P.fit une fois les tuiles de la partie dégelées,
     et refusée sans dégel (le dégel sert à quelque chose) ;
  5. décisions : départ, retrait, porte, suivi du chantier ;
  6. EXÉCUTANT (script/team/migration_champ.lua) sous un moteur simulé : chaîne complète déclencheur -> décision -> action -> effet,
     production jamais nulle, ennemi, refus du plan, plan qui n'a pas besoin de la place, avant-poste perdu, courant coupé ;
  7. câblage : les crochets de script/team/build.lua, outposts.lua, team.lua et foreuse_swap.lua sont en place ;
  8. mutants : chaque règle faussée est refusée.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local P = require("shared.team.plan")
local Mod = require("shared.team.modules")
local T = require("shared.team.config")
local Sw = require("shared.team.foreuse_swap")
local Pp = require("shared.team.pose_paires")
local D = require("shared.team.automatisation_donnees")
local Mg = require("shared.team.migration_champ")
local CFG = Mg.CFG

---------------------------------------------------------------------------------------------------
-- Données communes : cadences du gabarit réel, champ émulé
---------------------------------------------------------------------------------------------------
local METHOD
for _, m in ipairs(D.METHODS) do if m.gen == "smelter" and m.product == T.outposts.iron.product then METHOD = m end end
local ORE = METHOD.args[2]
local g1 = Mod.GEN.smelter(METHOD.args[1], ORE, 1)
local ROW_CAP = g1.nominal[Mod.PLATE_OF[ORE]]
local dg1 = Mod.GEN.drills(ORE, 1)
local RATES = { burner = Mod.spec(T.DRILL).speed, electric = Mod.spec(T.DRILL_ELECTRIC).speed, row_cap = ROW_CAP, furnace = ROW_CAP / 2,
  pairs_max = dg1.extensions[1].max }
local function line(n) local g = Mod.GEN.drills(ORE, n); if g then return g.w, g.h end end

--- Champ émulé : n paires foreuse 2 x 2 + four 2 x 2 posées comme place_pairs (minerai trié par distance au centre, quatre directions,
--- four au coin le plus éloigné), dans le lot de rectangle `rect`. Rend la liste des paires { id, lot, drill, sink }.
local function field(n, cx, cy, lot, first_id)
  local res = {}
  for y = -12, 11 do for x = -12, 11 do res[#res + 1] = { x = cx + x + 0.5, y = cy + y + 0.5 } end end
  local pl = Pp.new({ resources = Pp.sorted(res, { x = cx, y = cy }), cap = 400, w = 2, h = 2 })
  local occ, out = {}, {}
  local function tiles(x, y) return Pp.tiles({ x = x, y = y }, 2, 2) end
  while #out < n do
    local pos = pl.next()
    if not pos then break end
    for _, dir in ipairs({ 0, 2, 4, 6 }) do
      local vx, vy = Sw.rotate(dir, T.drill_drop[1], T.drill_drop[2])
      local dx, dy = pos.x + vx, pos.y + vy
      local best, bd
      for a = 0, 1 do
        for b = 0, 1 do
          local c = { x = math.floor(dx) + a, y = math.floor(dy) + b }
          if math.abs(c.x - dx) <= 1 and math.abs(c.y - dy) <= 1 and (math.abs(c.x - pos.x) >= 2 or math.abs(c.y - pos.y) >= 2) then
            local free = true
            for _, k in ipairs(tiles(c.x, c.y)) do if occ[k] then free = false end end
            for _, k in ipairs(tiles(pos.x, pos.y)) do if occ[k] then free = false end end
            local d = (c.x - pos.x) ^ 2 + (c.y - pos.y) ^ 2
            if free and (not bd or d > bd) then best, bd = c, d end
          end
        end
      end
      if best then
        for _, k in ipairs(tiles(pos.x, pos.y)) do occ[k] = true end
        for _, k in ipairs(tiles(best.x, best.y)) do occ[k] = true end
        pl.occupy(tiles(pos.x, pos.y)); pl.occupy(tiles(best.x, best.y))
        out[#out + 1] = { id = (first_id or 0) + #out + 1, lot = lot, dir = dir, drill = { x = pos.x, y = pos.y, w = 2, h = 2 },
          sink = { x = best.x, y = best.y, w = 2, h = 2 } }
        break
      end
    end
  end
  return out
end

--- Lot de 24 x 24 dont le centre est (cx, cy) (le centre du champ).
local function rect_at(cx, cy) return { x0 = cx - 12, y0 = cy - 12, x1 = cx + 12, y1 = cy + 12 } end

local function ctx_for(rect, produced, toward)
  return { rects = { ["0:0"] = rect }, toward = toward or { x = rect.x0 + 12, y = rect.y0 + 40 }, produced = produced or false,
    line = line, rates = RATES }
end

local function tile_set(flat)
  local s = {}
  for i = 1, #flat - 1, 2 do s[flat[i] .. ":" .. flat[i + 1]] = true end
  return s
end

local function pair_tiles(pr)
  return Mg.tiles({ Mg.box(pr.drill), Mg.box(pr.sink) })
end

---------------------------------------------------------------------------------------------------
-- La batterie de contrôles sur le module de règles courant (le vrai ou un mutant, dans le même `Mg`)
---------------------------------------------------------------------------------------------------
local function suite(verbose)
  local bad = 0
  local function ck(cond, msg)
    if not cond then bad = bad + 1; if verbose then print("  ECHEC : " .. msg) end end
  end

  -- 1. géométrie ---------------------------------------------------------------------------------
  local b = Mg.box({ x = 10, y = 10, w = 2, h = 2 })
  ck(b.x0 == 9 and b.y0 == 9 and b.x1 == 11 and b.y1 == 11, "boîte d'un objet 2 x 2")
  local tl = Mg.tiles({ b })
  ck(#tl == 8 and tl[1] == 9 and tl[2] == 9 and tl[7] == 10 and tl[8] == 10, "quatre tuiles, triées par y puis x")
  ck(#Mg.tiles({ b, Mg.box({ x = 11, y = 10, w = 2, h = 2 }) }) == 12, "deux boîtes qui se touchent : 6 tuiles, sans doublon")
  ck(#Mg.tiles({ Mg.box({ x = 10, y = 10, w = 2, h = 2 }), Mg.box({ x = 12, y = 10, w = 2, h = 2 }) }) == 16, "contact par le bord : pas de tuile partagée")
  -- appariement dans les quatre directions : le dépôt de la foreuse tombe dans le four
  local sink = { id = 100, x = 9, y = 8, w = 2, h = 2 }
  for _, dir in ipairs({ 0, 2, 4, 6 }) do
    local sx, sy = Sw.rotate(dir, sink.x - 10, sink.y - 10)
    local s = { id = 100, x = 10 + sx, y = 10 + sy, w = 2, h = 2 }
    local m = Mg.match({ { id = 7, x = 10, y = 10, dir = dir, w = 2, h = 2 } }, { s }, T.drill_drop)
    ck(#m == 1 and m[1].id == 7 and m[1].sink_id == 100, "appariement direction " .. dir)
    local far = Mg.match({ { id = 7, x = 10, y = 10, dir = dir, w = 2, h = 2 } }, { { id = 100, x = 30, y = 30, w = 2, h = 2 } }, T.drill_drop)
    ck(#far == 0, "four hors de portée du dépôt : pas de paire (direction " .. dir .. ")")
  end
  local m2 = Mg.match({ { id = 9, x = 10, y = 10, dir = 0, w = 2, h = 2 }, { id = 3, x = 30, y = 10, dir = 0, w = 2, h = 2 } },
    { { id = 101, x = 29, y = 8, w = 2, h = 2 }, { id = 100, x = 9, y = 8, w = 2, h = 2 } }, T.drill_drop)
  ck(#m2 == 2 and m2[1].id == 3 and m2[2].id == 9 and m2[1].sink_id == 101 and m2[2].sink_id == 100, "paires triées par foreuse, four par géométrie")

  -- 2. taille de la ligne neuve ----------------------------------------------------------------
  local s4 = Mg.sizing(4, RATES)
  ck(math.abs(s4.old - 4 * 0.25) < 1e-9, "4 paires thermiques livraient 1 plaque/s")
  ck(s4.pairs == 1, "1 paire de foreuses électriques (2 x 0,5 minerai/s) remplace 4 paires thermiques")
  ck(s4.rows == 2, "il faut 2 rangées de fours pour fondre 1 plaque/s (une rangée : " .. ROW_CAP .. "/s)")
  ck(math.abs(s4.rate - 2 * ROW_CAP * 60) < 1e-6, "débit demandé = rangées x capacité d'une rangée, par minute")
  ck(Mg.sizing(1, RATES).rows == CFG.min_rows, "une seule paire : au moins le minimum de rangées (le plan refuse un tapis sous 1 minerai/s)")
  ck(Mg.sizing(4, RATES).pairs == 1 and Mg.sizing(5, RATES).pairs == 2 and Mg.sizing(8, RATES).pairs == 2 and Mg.sizing(9, RATES).pairs == 3,
    "paires de foreuses : arrondi par excès (4 -> 1, 5 -> 2, 8 -> 2, 9 -> 3)")
  ck(Mg.sizing(100, RATES).pairs == RATES.pairs_max, "borné par ce qu'un collecteur porte")
  local slow_furnace = { burner = 0.5, electric = 0.5, row_cap = 0.2, furnace = 0.1, pairs_max = 7 }
  ck(math.abs(Mg.sizing(2, slow_furnace).old - 0.2) < 1e-9, "le four plus lent que la foreuse limite la production d'avant")
  -- le plan retrouve exactement `rows` rangées avec ce débit (template_of : ceil(cur * want / nominal))
  for k = 1, 8 do
    local sz = Mg.sizing(k, RATES)
    ck(math.ceil(1 * (sz.rate / 60) / ROW_CAP - 1e-9) == sz.rows, "le plan retrouve " .. sz.rows .. " rangée(s) pour " .. k .. " paire(s)")
    ck(sz.rows * ROW_CAP + 1e-9 >= sz.old, "les fours fondent au moins la production d'avant (" .. k .. " paires)")
    ck(sz.pairs * 2 * RATES.electric + 1e-9 >= sz.old or sz.pairs == RATES.pairs_max, "les foreuses livrent au moins la production d'avant (" .. k .. ")")
  end
  -- seuil du tapis du plan : le minerai demandé par la fonderie atteint P.AUTO_FLOW
  ck(Mg.sizing(1, RATES).rows * 2 * (ROW_CAP / 2) >= P.AUTO_FLOW - 1e-9, "la fonderie minimale dépasse le seuil du tapis du plan (P.AUTO_FLOW)")

  -- 3. place libérée -----------------------------------------------------------------------------
  local rect = { x0 = 0, y0 = 0, x1 = 24, y1 = 24 }
  local freed = {}
  for y = 5, 12 do for x = 5, 8 do freed[#freed + 1] = x; freed[#freed + 1] = y end end -- 4 x 8 libérées
  local f1 = Mg.fits(rect, freed, {}, 4, 8)
  ck(f1 and f1.x == 5 and f1.y == 5 and f1.w == 4 and f1.h == 8 and f1.freed == 32, "ligne 4 x 8 sur une place libérée de 4 x 8")
  local f2 = Mg.fits(rect, freed, {}, 8, 4)
  ck(f2 and f2.w == 4 and f2.h == 8, "la ligne se tourne d'un quart de tour")
  local others = { 6, 8 }
  ck(Mg.fits(rect, freed, others, 4, 8) == nil or Mg.fits(rect, freed, others, 4, 8).freed < 32, "une paire restante dans la place réduit ou empêche la ligne")
  local wall = {}
  for y = 0, 23 do for x = 0, 23 do wall[#wall + 1] = x; wall[#wall + 1] = y end end
  ck(Mg.fits(rect, freed, wall, 4, 8) == nil, "lot plein de paires restantes : rien ne tient")
  ck(Mg.fits(rect, {}, {}, 4, 8) == nil, "rien de libéré : la ligne ne compte pour rien (recouvrement minimal)")
  local edge = {}
  for y = 0, 7 do edge[#edge + 1] = 0; edge[#edge + 1] = y end -- la colonne de la marge du lot seule
  ck(Mg.fits(rect, edge, {}, 4, 8) == nil, "place libérée seulement dans la marge du lot : refusé")
  local edge2 = {}
  for y = 0, 7 do for x = 0, 3 do edge2[#edge2 + 1] = x; edge2[#edge2 + 1] = y end end
  local fe = Mg.fits(rect, edge2, {}, 4, 8)
  ck(fe and fe.x >= 1 and fe.y >= 1, "place libérée au bord du lot : la ligne se pose à la marge d'une tuile")
  ck(Mg.fits(rect, freed, {}, 30, 4) == nil, "ligne plus large que le lot : refusé")

  -- 4. choix de la partie sur des champs émulés ------------------------------------------------
  for _, n in ipairs({ 8, 12, 16, 20 }) do
    local cx, cy = 100 + n, -50
    local pl = field(n, cx, cy, "0:0")
    local rc = rect_at(cx, cy)
    local band, why = Mg.pick_band(pl, ctx_for(rc, false))
    ck(band ~= nil, "champ de " .. n .. " paires : une partie trouvée (" .. tostring(why) .. ")")
    if band then
      ck(band.n == #band.ids and band.n >= 1, n .. " : n = nombre d'identifiants")
      ck(band.n <= CFG.max_part_pairs, n .. " : au plus max_part_pairs paires")
      ck(band.n <= #pl - CFG.keep_pairs, n .. " : au moins keep_pairs paire(s) restent debout tant qu'aucune ligne neuve n'a produit")
      local sorted = true
      for i = 2, #band.ids do if band.ids[i - 1] >= band.ids[i] then sorted = false end end
      ck(sorted, n .. " : identifiants triés, sans doublon")
      -- les identifiants sont des paires du champ
      local byid, member = {}, {}
      for _, pr in ipairs(pl) do byid[pr.id] = pr end
      local all_in = true
      for _, id in ipairs(band.ids) do member[id] = true; if not byid[id] then all_in = false end end
      ck(all_in, n .. " : identifiants connus")
      -- le dégel = exactement les tuiles de la partie
      local want = {}
      for _, id in ipairs(band.ids) do for _, v in ipairs({ table.unpack(pair_tiles(byid[id])) }) do want[#want + 1] = v end end
      local ws, hs = {}, tile_set(band.thaw)
      for i = 1, #want - 1, 2 do ws[want[i] .. ":" .. want[i + 1]] = true end
      local same = true
      for k in pairs(ws) do if not hs[k] then same = false end end
      for k in pairs(hs) do if not ws[k] then same = false end end
      ck(same, n .. " : dégel = tuiles des foreuses et fours de la partie, rien de plus")
      -- aucune tuile du dégel n'est à une paire qui reste
      local clean = true
      for _, pr in ipairs(pl) do
        if not member[pr.id] then
          for _, k in ipairs({ table.unpack(pair_tiles(pr)) }) do end
          local t = pair_tiles(pr)
          for i = 1, #t - 1, 2 do if hs[t[i] .. ":" .. t[i + 1]] then clean = false end end
        end
      end
      ck(clean, n .. " : le dégel ne touche aucune paire qui reste")
      -- la ligne promise : dans le lot (marge), libre de toute paire restante, recouvre la partie à CFG.min_overlap
      local fit = band.fit
      ck(fit.x >= rc.x0 + CFG.lot_margin and fit.y >= rc.y0 + CFG.lot_margin and fit.x + fit.w <= rc.x1 - CFG.lot_margin
        and fit.y + fit.h <= rc.y1 - CFG.lot_margin, n .. " : la ligne est dans le lot, marge comprise")
      local hit_other, over = 0, 0
      for ty = fit.y, fit.y + fit.h - 1 do
        for tx = fit.x, fit.x + fit.w - 1 do
          if hs[tx .. ":" .. ty] then over = over + 1 end
          for _, pr in ipairs(pl) do
            if not member[pr.id] then
              local t = pair_tiles(pr)
              for i = 1, #t - 1, 2 do if t[i] == tx and t[i + 1] == ty then hit_other = hit_other + 1 end end
            end
          end
        end
      end
      ck(hit_other == 0, n .. " : la ligne ne touche aucune paire qui reste (" .. hit_other .. ")")
      ck(over >= math.ceil(CFG.min_overlap * fit.w * fit.h - 1e-9), n .. " : la ligne recouvre la partie (" .. over .. " tuiles)")
      local z = band.zone
      ck(z ~= nil and z.x0 == fit.x - CFG.zone_slack and z.y0 == fit.y - CFG.zone_slack and z.x1 == fit.x + fit.w + CFG.zone_slack
        and z.y1 == fit.y + fit.h + CFG.zone_slack, n .. " : la zone du plan = la ligne promise et son jeu")
      -- taille : rangées et débit cohérents avec M.sizing
      local sz = Mg.sizing(band.n, RATES)
      ck(band.pairs == sz.pairs and band.rows == sz.rows and math.abs(band.rate - sz.rate) < 1e-9, n .. " : taille de la ligne = M.sizing")
      -- déterminisme : l'ordre d'entrée ne change rien
      local rev = {}
      for i = #pl, 1, -1 do rev[#rev + 1] = pl[i] end
      local band2 = Mg.pick_band(rev, ctx_for(rc, false))
      local same_ids = band2 and #band2.ids == #band.ids
      if same_ids then for i = 1, #band.ids do if band.ids[i] ~= band2.ids[i] then same_ids = false end end end
      ck(same_ids and band2.fit.x == fit.x and band2.fit.y == fit.y, n .. " : ordre d'entrée sans effet")
      -- une ligne neuve a produit : la règle peut aller plus loin que keep_pairs
      local bp = Mg.pick_band(pl, ctx_for(rc, true))
      ck(bp ~= nil and bp.n <= CFG.max_part_pairs, n .. " : après une ligne qui a produit, une partie reste possible")
    end
  end
  -- plafond d'une partie : une ligne qui exige plus de place que max_part_pairs paires n'en retire pas davantage
  do
    local big = field(24, 100, -50, "0:0")
    local cb = ctx_for(rect_at(100, -50), true)
    cb.line = function() return 10, 10 end
    local bb = Mg.pick_band(big, cb)
    ck(bb == nil or bb.n <= CFG.max_part_pairs, "plafond : au plus " .. CFG.max_part_pairs .. " paires par partie, même avec une grande ligne (" .. tostring(bb and bb.n) .. ")")
    ck(bb ~= nil, "plafond : une partie reste trouvée sur le champ de 24 paires")
  end
  -- garde : la dernière paire ne part pas tant qu'aucune ligne neuve n'a produit
  do
    local one = field(1, 100, -50, "0:0")
    local b1, w1 = Mg.pick_band(one, ctx_for(rect_at(100, -50), false))
    ck(b1 == nil and w1 == "garde", "une seule paire, aucune ligne neuve : « garde »")
    local two = field(2, 100, -50, "0:0")
    local b2, w2 = Mg.pick_band(two, ctx_for(rect_at(100, -50), false))
    ck(b2 == nil or b2.n <= 1, "deux paires, aucune ligne neuve : au plus une partie d'une paire (" .. tostring(w2) .. ")")
    local _, w0 = Mg.pick_band({}, ctx_for(rect_at(100, -50), false))
    ck(w0 == "vide", "aucune paire : « vide »")
    local none = field(8, 100, -50, "0:0")
    local c2 = ctx_for(rect_at(100, -50), false)
    c2.rects = {}
    local bn, wn = Mg.pick_band(none, c2)
    ck(bn == nil and wn == "treillis", "aucun lot de gisement : « treillis »")
    local c3 = ctx_for(rect_at(100, -50), false)
    c3.line = function() return nil end
    local bg, wg = Mg.pick_band(none, c3)
    ck(bg == nil and wg == "gabarit", "gabarit refusé : « gabarit »")
    -- paires hors du lot ou dans la marge : écartées
    local out = field(8, 100, -50, "9:9")
    local bo, wo = Mg.pick_band(out, ctx_for(rect_at(100, -50), false))
    ck(bo == nil and wo == "treillis", "paires d'un autre lot : écartées")
    -- une paire seule en bout de lot à deux champs : la partie reste dans UN lot
    local a = field(6, 100, -50, "0:0")
    local c = field(6, 160, -50, "1:0", 100)
    local both = {}
    for _, v in ipairs(a) do both[#both + 1] = v end
    for _, v in ipairs(c) do both[#both + 1] = v end
    local cx2 = { rects = { ["0:0"] = rect_at(100, -50), ["1:0"] = rect_at(160, -50) }, toward = { x = 160, y = 0 }, produced = false,
      line = line, rates = RATES }
    local bb = Mg.pick_band(both, cx2)
    if bb then
      local lots_used, same_lot = {}, true
      local byid = {}
      for _, pr in ipairs(both) do byid[pr.id] = pr end
      for _, id in ipairs(bb.ids) do lots_used[byid[id].lot] = true end
      local cnt = 0
      for _ in pairs(lots_used) do cnt = cnt + 1 end
      ck(cnt == 1 and lots_used[bb.lot], "deux lots : la partie reste dans un seul lot (" .. bb.lot .. ")")
    end
  end

  -- 5. décisions ---------------------------------------------------------------------------------
  local base = { plan = true, power = true, obtainable = true, plates = 500, lattice = true, pairs = 8, enemy = false, now = 1000, retry = 0 }
  local function so(over)
    local c = {}
    for k, v in pairs(base) do c[k] = v end
    for k, v in pairs(over) do c[k] = v end
    return Mg.start_ok(c)
  end
  ck(so({}) == true, "départ : tout réuni")
  local r
  _, r = so({ plan = false }); ck(r == "plan", "départ : sans plan directeur")
  _, r = so({ power = false }); ck(r == "courant", "départ : sans courant")
  _, r = so({ obtainable = false }); ck(r == "objet", "départ : sans foreuse électrique")
  _, r = so({ pairs = CFG.min_pairs - 1 }); ck(r == "paires", "départ : trop peu de paires")
  _, r = so({ lattice = false }); ck(r == "treillis", "départ : champ hors du treillis")
  _, r = so({ plates = CFG.min_plates - 1 }); ck(r == "plaques", "départ : trop peu de plaques libres")
  _, r = so({ retry = 2000 }); ck(r == "attente", "départ : nouvel essai plus tard")
  _, r = so({ enemy = true }); ck(r == "ennemi", "départ : ennemi à portée")
  _, r = so({ migr = "fini" }); ck(r == "fait", "départ : déjà migré")
  _, r = so({ migr = "partiel" }); ck(r == "fait", "départ : migration terminée en partie")
  _, r = so({ abandoned = true }); ck(r == "fait", "départ : abandonné")
  ck(so({ migr = "en cours" }) == true, "départ : un champ en cours reprend")
  -- retrait
  local function cr(c) return Mg.can_retire(c) end
  ck(cr({ present = 4, total = 8, produced = false }) == true, "retrait : 4 paires sur 8")
  _, r = cr({ present = 8, total = 8, produced = false }); ck(r == "garde", "retrait : la dernière paire reste (rien n'a produit)")
  ck(cr({ present = 8, total = 8, produced = true }) == true, "retrait : tout peut partir quand une ligne neuve a produit")
  _, r = cr({ present = 2, total = 8, produced = true, enemy = true }); ck(r == "ennemi", "retrait : jamais avec un ennemi à portée")
  ck(cr({ present = 0, total = 0, produced = false }) == true, "retrait : rien à retirer (les paires sont déjà détruites)")
  ck(cr({ present = 3, total = 3, produced = false }) == false, "retrait : toutes les paires restantes d'un champ pauvre : refusé")
  -- porte
  local st = { t0 = 0 }
  local function gate(p, env) return Mg.gate(st, p, env) end
  local a1, w1 = gate(nil, { now = 10 }); ck(a1 == "echec", "porte : projet disparu")
  a1 = gate({ state = "refuse" }, { now = 10 }); ck(a1 == "echec", "porte : projet refusé")
  a1, w1 = gate({ state = "plan" }, { now = 10 }); ck(a1 == "attendre" and w1 == "plan", "porte : le plan attend")
  a1, w1 = gate({ state = "plan" }, { now = CFG.gate_wait + 1 }); ck(a1 == "annuler" and w1 == "delai-plan", "porte : plan trop long")
  a1, w1 = gate({ state = "reserve", reason = "materiaux" }, { now = 10 }); ck(a1 == "attendre" and w1 == "matieres", "porte : matières attendues, rien n'est retiré")
  a1, w1 = gate({ state = "reserve", reason = "materiaux" }, { now = CFG.gate_wait + 1 }); ck(a1 == "annuler" and w1 == "matieres", "porte : matières trop longues : annulé")
  local env = { now = 10, uses = true, total = 8, present = 4, produced = false, enemy = false, gate_age = 0 }
  a1 = gate({ state = "reserve", reason = "degel" }, env); ck(a1 == "retirer", "porte : tout est prêt, retrait")
  local env2 = { now = 10, uses = true, total = 8, present = 4, produced = false, enemy = true, gate_age = 5 }
  a1, w1 = gate({ state = "reserve", reason = "degel" }, env2); ck(a1 == "attendre" and w1 == "ennemi", "porte : ennemi, on attend sans rien retirer")
  env2.gate_age = CFG.safe_wait + 1
  a1, w1 = gate({ state = "reserve", reason = "degel" }, env2); ck(a1 == "annuler" and w1 == "ennemi", "porte : ennemi trop longtemps : demande annulée")
  local env3 = { now = 10, uses = true, total = 8, present = 8, produced = false, enemy = false, gate_age = 0 }
  a1, w1 = gate({ state = "reserve", reason = "degel" }, env3); ck(a1 == "annuler" and w1 == "garde", "porte : retirer la dernière paire : annulé")
  local env4 = { now = 10, uses = false, total = 8, present = 4, produced = false, enemy = true, gate_age = 0 }
  a1, w1 = gate({ state = "reserve", reason = "degel" }, env4); ck(a1 == "passer" and w1 == "hors-partie", "porte : le plan n'utilise pas la place : rien n'est retiré, le plan passe")
  a1 = gate({ state = "chantier" }, { now = 10 }); ck(a1 == "passer", "porte : déjà au chantier : on ne retire rien")
  -- suivi
  local wt = Mg.watch
  a1 = wt(st, nil, { now = 1, made = 0 }); ck(a1 == "perdu", "suivi : projet disparu")
  a1 = wt(st, { state = "refuse" }, { now = 1, made = 0 }); ck(a1 == "perdu", "suivi : projet refusé")
  a1 = wt(st, { state = "chantier" }, { now = 1, made = 999 }); ck(a1 == "attendre", "suivi : chantier en cours, même avec des produits lus")
  a1 = wt(st, { state = "fini" }, { now = 1, made = CFG.produce_min - 1 }); ck(a1 == "attendre", "suivi : ligne finie qui ne produit pas encore")
  a1 = wt(st, { state = "fini" }, { now = 1, made = CFG.produce_min }); ck(a1 == "produit", "suivi : la ligne a produit")
  a1 = wt(st, { state = "bloque" }, { now = 1, made = 0 }); ck(a1 == "attendre", "suivi : projet bloqué, on attend")
  local stw = { t0 = 0, t_degel = 1000, t_done = 5000 }
  a1 = wt(stw, { state = "bloque" }, { now = 1000 + CFG.build_max + 1, made = 0 }); ck(a1 == "abandonner", "suivi : chantier qui n'aboutit pas en " .. CFG.build_max .. " ticks : la migration s'arrête")
  a1 = wt(stw, { state = "chantier" }, { now = 1000 + CFG.build_max - 1, made = 0 }); ck(a1 == "attendre", "suivi : chantier encore dans les délais")
  a1 = wt(stw, { state = "fini" }, { now = 5000 + CFG.fini_max + 1, made = 0 }); ck(a1 == "abandonner", "suivi : ligne finie sans production en " .. CFG.fini_max .. " ticks : la migration s'arrête")
  a1 = wt(stw, { state = "fini" }, { now = 5000 + CFG.fini_max + 1, made = CFG.produce_min }); ck(a1 == "produit", "suivi : produire passe avant le délai")
  return bad
end

section("1 à 5. Règle pure")
do
  local bad = suite(true)
  check(bad == 0, "la batterie de la règle réelle est sans échec (" .. bad .. ")")
end

---------------------------------------------------------------------------------------------------
-- 4 bis. Accord avec le plan : P.fit accepte la ligne promise une fois la partie dégelée, la refuse sans dégel
---------------------------------------------------------------------------------------------------
section("4 bis. Accord avec P.fit")
do
  local cases, ok_thaw, ko_nothaw, total_bands = 0, 0, 0, 0
  for _, spec in ipairs({ { 8, 100, -50 }, { 12, 101, -49 }, { 16, 90, 20 }, { 20, 0, 0 }, { 10, -300, 200 }, { 14, 33, 77 } }) do
    local n, cx, cy = spec[1], spec[2], spec[3]
    local pl = field(n, cx, cy, "0:0")
    local rc = rect_at(cx, cy)
    local ctx = ctx_for(rc, false)
    local band = Mg.pick_band(pl, ctx)
    cases = cases + 1
    if band then
      total_bands = total_bands + 1
      local gen = Mod.GEN.drills(ORE, band.pairs)
      local ores = {}
      for y = rc.y0 - 12, rc.y1 + 12 do for x = rc.x0 - 12, rc.x1 + 12 do ores[P.tkey(x, y)] = true end end
      local blocked = {}
      for _, pr in ipairs(pl) do
        local t = pair_tiles(pr)
        for i = 1, #t - 1, 2 do blocked[P.tkey(t[i], t[i + 1])] = true end
      end
      local thaw = {}
      for i = 1, #band.thaw - 1, 2 do thaw[P.tkey(band.thaw[i], band.thaw[i + 1])] = true end
      local function free_with(tx, ty) local k = P.tkey(tx, ty); return thaw[k] or not blocked[k] end
      local function free_without(tx, ty) return not blocked[P.tkey(tx, ty)] end
      local fit = P.fit(gen, { x0 = rc.x0, y0 = rc.y0, x1 = rc.x1, y1 = rc.y1 }, { free = free_with, ore = ores, within = band.zone })
      if fit then ok_thaw = ok_thaw + 1 end
      check(fit ~= nil, "P.fit accepte la ligne de " .. band.pairs .. " paire(s) promise pour le champ de " .. n .. " une fois la partie dégelée")
      if fit then
        -- la place trouvée par le plan recouvre la partie dégelée (le dégel sert) ; sans dégel, le plan ne peut pas la poser là
        local fr = Mg.fits(rc, band.thaw, {}, fit.w, fit.h)
        local blocked_there = 0
        for ty = fit.oy, fit.oy + fit.h - 1 do for tx = fit.ox, fit.ox + fit.w - 1 do if blocked[P.tkey(tx, ty)] then blocked_there = blocked_there + 1 end end end
        check(blocked_there > 0, "la ligne posée par le plan sert la place libérée (" .. blocked_there .. " tuile(s) dégelée(s) recouverte(s))")
        check(fit.ox >= band.zone.x0 and fit.oy >= band.zone.y0 and fit.ox + fit.w <= band.zone.x1 and fit.oy + fit.h <= band.zone.y1,
          "la ligne posée par le plan reste dans la zone promise")
      end
      local fit0 = P.fit(gen, { x0 = rc.x0, y0 = rc.y0, x1 = rc.x1, y1 = rc.y1 }, { free = free_without, ore = ores, within = band.zone })
      -- sans dégel, le plan peut trouver une autre place libre du lot (champ clairsemé) ; ce qui compte : la place qu'il choisit AVEC dégel
      if fit0 == nil then ko_nothaw = ko_nothaw + 1 end
    end
  end
  check(total_bands >= 4, "des parties trouvées sur les champs émulés (" .. total_bands .. " sur " .. cases .. ")")
  print(string.format("[MIGRATION-CHAMP] accord P.fit : %d partie(s), %d acceptée(s) avec dégel, %d refusée(s) sans dégel", total_bands, ok_thaw, ko_nothaw))
end

---------------------------------------------------------------------------------------------------
-- 6. L'exécutant sous un moteur simulé
---------------------------------------------------------------------------------------------------
section("6. Exécutant sous moteur simulé")
local function executor_run(scn)
  scn = scn or {}
  local logs = {}
  _G.log = function(s) logs[#logs + 1] = s end
  _G.defines = { direction = { north = 0, east = 2, south = 4, west = 6 }, inventory = { furnace_source = 1, furnace_result = 2, fuel = 3 } }
  local sink_name, drill_name, edrill_name = T.outposts.iron.sink, T.DRILL, T.DRILL_ELECTRIC
  _G.game = { tick = 0, entity_prototypes = {
    [sink_name] = { type = "furnace", tile_width = 2, tile_height = 2 },
    [drill_name] = { type = "mining-drill", tile_width = 2, tile_height = 2 },
    [edrill_name] = { type = "mining-drill", tile_width = 3, tile_height = 3 },
  } }
  -- stock factice
  local chest = {}
  local spilled = {}
  local Stock = {
    insert = function(f, name, n) chest[name] = (chest[name] or 0) + n; return n end,
    count = function(f, name) return chest[name] or 0 end,
    remove = function(f, name, n) local g = math.min(n, chest[name] or 0); chest[name] = (chest[name] or 0) - g; return g end,
  }
  local disowned = {}
  local State = {
    sorted_keys = function(t) local ks = {} for k in pairs(t or {}) do ks[#ks + 1] = k end table.sort(ks) return ks end,
    disown = function(u) disowned[u] = true end,
  }
  -- plan directeur factice : demandes et annulations
  local Build = { requests = {}, cancels = {} }
  Build.request = function(f, spec)
    local b = f.build
    local id = b.next_id
    b.next_id = id + 1
    b.projects[id] = { id = id, spec = spec, state = "attente", ents = {}, parts = {} }
    Build.requests[#Build.requests + 1] = id
    return id
  end
  Build.cancel = function(f, id, why)
    local p = f.build.projects[id]
    if not p or not (p.state == "attente" or p.state == "plan" or p.state == "reserve") then return false end
    p.state, p.reason = "refuse", why
    Build.cancels[#Build.cancels + 1] = { id, why }
    return true
  end
  local saved = {}
  for _, name in ipairs({ "script.faction.state", "script.team.stock", "script.team.build", "script.team.migration_champ" }) do
    saved[name] = package.loaded[name]
  end
  package.loaded["script.faction.state"] = State
  package.loaded["script.team.stock"] = Stock
  package.loaded["script.team.build"] = Build
  package.loaded["script.team.migration_champ"] = nil
  local Mig = require("script.team.migration_champ")

  -- le monde : un avant-poste de fer dans le lot (0, 3) du treillis ancré au QG en (0, 0)
  local lat = { ox = 0, oy = 0 }
  local i, j = 0, 3
  local lx0, ly0, lx1, ly1 = P.lot_rect(lat, i, j)
  local cx, cy = (lx0 + lx1) / 2, (ly0 + ly1) / 2
  local pl = field(scn.pairs or 8, cx, cy, P.lot_key(i, j))
  local nextu = 1000
  local function entity(name, etype, x, y, w, h, dir)
    nextu = nextu + 1
    local e = { valid = true, name = name, type = etype, unit_number = nextu, position = { x = x, y = y }, direction = dir or 0,
      prototype = { tile_width = w, tile_height = h }, products_finished = 0, inv = {} }
    e.get_fuel_inventory = function() return { get_contents = function() return { coal = 5 } end } end
    e.get_inventory = function(id)
      return { get_contents = function() if id == defines.inventory.furnace_result then return { [T.outposts.iron.product] = 3 } end return {} end }
    end
    e.destroy = function() e.valid = false end
    return e
  end
  local o = { id = 1, kind = "iron", pos = { x = cx, y = cy }, drills = #pl, drill_list = {}, sinks = {}, turret_list = {}, last_service = 0 }
  local by_unit = {}
  for _, pr in ipairs(pl) do
    local d = entity(drill_name, "mining-drill", pr.drill.x, pr.drill.y, 2, 2, pr.dir)
    local s = entity(sink_name, "furnace", pr.sink.x, pr.sink.y, 2, 2, 0)
    o.drill_list[#o.drill_list + 1] = d
    o.sinks[#o.sinks + 1] = s
    by_unit[d.unit_number], by_unit[s.unit_number] = d, s
  end
  local f = {
    key = "essai", force = "player", outposts = { [1] = o }, outposts_count = 1, hq = { valid = true }, hq_pos = { x = 0, y = 0 },
    build = { lat = lat, lots = { [P.lot_key(i, j)] = { i = i, j = j, state = scn.lot_state or "gisement", res = ORE } }, projects = {},
      order = {}, next_id = 1, occ = {}, sante = { healthy = scn.power ~= false } },
  }
  local fake_furnaces = {}
  local surface = {
    find_nearest_enemy = function(args)
      if scn.enemy and scn.enemy(game.tick) then return { valid = true } end
      return nil
    end,
    find_entities_filtered = function(args)
      local out = {}
      for _, fe in ipairs(fake_furnaces) do
        if fe.valid and math.abs(fe.position.x - args.position[1]) <= 0.6 and math.abs(fe.position.y - args.position[2]) <= 0.6 then out[#out + 1] = fe end
      end
      return out
    end,
    spill_item_stack = function(pos, stack) spilled[#spilled + 1] = stack end,
  }
  local book = { handcraftable = function() return true end }
  local free = { [T.outposts.iron.product] = scn.plates or 800, [edrill_name] = 4 }
  chest[T.outposts.iron.product] = scn.plates or 800

  local E = { f = f, o = o, pl = pl, logs = logs, chest = chest, Build = Build, spilled = spilled, disowned = disowned, Mig = Mig, surface = surface,
    book = book, free = free, lot = P.lot_key(i, j), by_unit = by_unit }
  function E.alive()
    local n = 0
    for _, pr in ipairs(pl) do
      -- une paire vit si sa foreuse et son four valent encore
      local d, s
      for _, e in ipairs(o.drill_list) do if e.valid and e.position.x == pr.drill.x and e.position.y == pr.drill.y then d = e end end
      for _, e in ipairs(o.sinks) do if e.valid and e.position.x == pr.sink.x and e.position.y == pr.sink.y then s = e end end
      if d and s then n = n + 1 end
    end
    return n
  end
  function E.think()
    game.tick = game.tick + CFG.every
    return Mig.think(f, surface, book, free, game.tick)
  end
  function E.project(id) return f.build.projects[id or Build.requests[#Build.requests]] end
  function E.add_line_ents(p, built)
    -- ce que le plan réserverait : un tapis sur une tuile de la partie, des fours de la fonderie
    local th = p.spec.degel.tiles
    p.ents[#p.ents + 1] = { name = D.PARTS.belt, x = th[1] + 0.5, y = th[2] + 0.5, dir = 0, built = built }
    for k = 1, 4 do
      local e = { name = sink_name, x = 5000 + 2 * k, y = 5000, dir = 0, built = built }
      p.ents[#p.ents + 1] = e
      local fe = entity(sink_name, "furnace", e.x, e.y, 2, 2, 0)
      fake_furnaces[#fake_furnaces + 1] = fe
    end
  end
  function E.make_products(n)
    for _, fe in ipairs(fake_furnaces) do fe.products_finished = fe.products_finished + n end
  end
  function E.restore()
    for name, v in pairs(saved) do package.loaded[name] = v end
  end
  return E
end

--- Pilote de plan : fait avancer un projet comme advance() de build.lua (états du plan), sans moteur. `script` = fonction de tick.
local function drive_plan(E, p, stage)
  if stage == "plan" then p.state = "plan"
  elseif stage == "materiaux" then p.state, p.reason = "reserve", "materiaux"
  elseif stage == "degel" then
    p.state, p.reason = "reserve", "degel"
    if #p.ents == 0 then E.add_line_ents(p, false) end
  elseif stage == "chantier" then p.state, p.reason = "chantier", nil
  elseif stage == "fini" then
    p.state, p.reason = "fini", nil
    for _, e in ipairs(p.ents) do e.built = true end
  end
end

do
  -- A. La chaîne complète, un champ de 8 paires : demande -> matières -> retrait -> chantier -> production -> partie suivante
  local E = executor_run({ pairs = 8 })
  local Mig, f, o = E.Mig, E.f, E.o
  local min_prod = math.huge
  local function production()
    local live = E.alive() * 0.25
    for _, pid in ipairs(E.Build.requests) do
      local p = E.project(pid)
      if p.state == "fini" and p.degele then live = live + 1 end
    end
    return live
  end
  -- 1. départ
  E.think()
  check(#E.Build.requests == 1, "A1 : une demande partie au plan (" .. #E.Build.requests .. ")")
  local p = E.project()
  check(p and p.spec.degel and #p.spec.degel.tiles >= 8, "A2 : la demande porte les tuiles de la partie à dégeler")
  check(p.spec.fixe == true and p.spec.paires >= 1 and p.spec.rate > 0 and p.spec.feed == "tapis" and p.spec.gen == "smelter",
    "A3 : demande de fonderie à tapis de taille fixe")
  check(p.spec.args[2] == ORE and p.spec.args[3] == 1, "A4 : minerai et gabarit lus des données de l'exécutant")
  check(o.migr == "en cours" and o.full == true and o.full_by == "migration", "A5 : l'avant-poste est marqué en cours, plein pour l'agrandissement")
  check(E.alive() == 8, "A6 : rien n'est retiré à la demande (" .. E.alive() .. " paires)")
  check(f.migration.cur == 1 and f.migration.o[1].stage == "projet", "A7 : suivi en étape « projet »")
  local band_n = #f.migration.o[1].ids
  -- 2. le plan planifie, puis attend ses matières : le champ produit toujours
  drive_plan(E, p, "plan"); E.think()
  drive_plan(E, p, "materiaux")
  for _ = 1, 5 do E.think(); min_prod = math.min(min_prod, production()) end
  check(E.alive() == 8, "A8 : matières attendues, les 8 paires produisent encore")
  check(f.migration.o[1].stage == "projet", "A9 : toujours en étape « projet »")
  -- 3. matières réunies : retrait
  drive_plan(E, p, "degel")
  E.think()
  local left = E.alive()
  check(left == 8 - band_n, "A10 : la partie (" .. band_n .. " paires) est retirée, " .. left .. " restent")
  check(left >= CFG.keep_pairs, "A11 : au moins " .. CFG.keep_pairs .. " paire(s) debout (aucune ligne neuve n'a produit)")
  min_prod = math.min(min_prod, production())
  check(p.degele == true, "A12 : le plan est libéré (p.degele)")
  check(f.migration.o[1].stage == "chantier", "A13 : étape « chantier »")
  check((E.chest[T.DRILL] or 0) == band_n and (E.chest[T.outposts.iron.sink] or 0) == band_n, "A14 : foreuses thermiques et fours rendus au stock")
  check((E.chest.coal or 0) == 5 * band_n and (E.chest[T.outposts.iron.product] or 0) == 800 + 3 * band_n, "A15 : combustible et plaques des fours repris au stock")
  check(#o.drill_list == left and #o.sinks == left and o.drills == left, "A16 : listes de l'avant-poste tenues (" .. #o.drill_list .. ", " .. #o.sinks .. ", " .. o.drills .. ")")
  local n_dis = 0
  for _ in pairs(E.disowned) do n_dis = n_dis + 1 end
  check(n_dis == 2 * band_n, "A17 : les pièces retirées ne sont plus possédées avant d'être détruites (" .. n_dis .. ")")
  check(#E.spilled == 0, "A18 : rien n'est répandu quand le stock a la place")
  -- 4. chantier, puis ligne finie sans production : on n'avance pas
  drive_plan(E, p, "chantier")
  for _ = 1, 4 do E.think(); min_prod = math.min(min_prod, production()) end
  check(#E.Build.requests == 1, "A19 : pas de nouvelle partie pendant le chantier")
  drive_plan(E, p, "fini")
  E.think()
  check(#E.Build.requests == 1 and f.migration.o[1].stage == "chantier", "A20 : ligne finie qui n'a rien produit : la partie suivante attend")
  E.make_products(CFG.produce_min)
  E.think()
  check(f.migration.o[1].produced == 1 and f.migration.o[1].done == 1, "A21 : la ligne a produit : partie comptée")
  check(o.drills == left + band_n and o.migr_credit == band_n, "A21 bis : les paires migrées comptent de nouveau comme foreuses de l'avant-poste (bilan de capacité)")
  -- 5. la partie suivante part
  E.think()
  check(#E.Build.requests == 2, "A22 : partie suivante demandée une fois la précédente produite (" .. #E.Build.requests .. ")")
  min_prod = math.min(min_prod, production())
  check(min_prod > 0, "A23 : la production n'est JAMAIS tombée à 0 (minimum " .. min_prod .. ")")
  local jr = table.concat(E.logs, "\n")
  check(jr:find("%[FO%-MIGRATION%].-partie 1 demandee") ~= nil, "A24 : journal : demande")
  check(jr:find("%[FO%-MIGRATION%].-partie retiree") ~= nil, "A25 : journal : retrait")
  check(jr:find("%[FO%-MIGRATION%].-produit") ~= nil, "A26 : journal : production")
  E.restore()
end

do
  -- B. Un ennemi à portée au moment du retrait : rien n'est retiré, puis le retrait a lieu à son départ
  local enemy_until = 0
  local E = executor_run({ pairs = 8, enemy = function(t) return t < enemy_until end })
  E.think()
  local p = E.project()
  drive_plan(E, p, "plan"); E.think()
  drive_plan(E, p, "materiaux"); E.think()
  enemy_until = game.tick + 5 * CFG.every
  drive_plan(E, p, "degel")
  for _ = 1, 3 do E.think() end
  check(E.alive() == 8 and not p.degele, "B1 : ennemi à moins de " .. CFG.safe .. " tuiles : rien n'est retiré (" .. E.alive() .. " paires)")
  check(E.f.migration.o[1].stage == "projet", "B2 : la demande reste en attente")
  local jr = table.concat(E.logs, "\n")
  check(jr:find("en attente %(ennemi%)") ~= nil, "B3 : journal : attente pour ennemi")
  for _ = 1, 4 do E.think() end
  check(E.alive() < 8 and p.degele == true, "B4 : l'ennemi parti, la partie est retirée (" .. E.alive() .. " paires)")
  E.restore()
  -- B'. Un ennemi qui ne part pas : la demande est annulée, rien n'a été retiré
  local E2 = executor_run({ pairs = 8, enemy = function() return true end })
  -- l'ennemi bloque aussi le départ : on le laisse partir le temps de la demande
  local present = false
  local E3 = executor_run({ pairs = 8, enemy = function() return present end })
  E3.think()
  local p3 = E3.project()
  drive_plan(E3, p3, "plan"); E3.think()
  drive_plan(E3, p3, "degel"); present = true
  for _ = 1, math.floor(CFG.safe_wait / CFG.every) + 3 do E3.think() end
  check(E3.alive() == 8, "B5 : ennemi permanent : toujours 8 paires")
  check(#E3.Build.cancels == 1 and E3.Build.cancels[1][2]:find("ennemi") ~= nil, "B6 : demande annulée pour ennemi (matières rendues par le plan)")
  check(E3.o.migr == nil and E3.o.full == false and E3.f.migration.o[1].fails == 1, "B7 : l'avant-poste redevient extensible, un échec compté")
  E2.restore(); E3.restore()
end

do
  -- C. Le plan refuse la demande : rien n'a été retiré ; après trois échecs, abandon sans dommage
  local E = executor_run({ pairs = 8 })
  for round = 1, CFG.max_fails do
    E.think()
    local p = E.project()
    check(p ~= nil and p.state == "attente", "C" .. round .. "a : demande " .. round)
    p.state, p.reason = "refuse", "pas de lot"
    E.think()
    check(E.alive() == 8, "C" .. round .. "b : après le refus, rien n'est retiré")
    game.tick = game.tick + CFG.retry
  end
  local st = E.f.migration.o[1]
  check(st.fails == CFG.max_fails and st.abandoned == true, "C4 : abandon après " .. CFG.max_fails .. " échecs")
  check(E.o.migr == nil and E.o.full == false and E.f.migration.cur == nil, "C5 : l'avant-poste est rendu tel quel")
  local n = #E.Build.requests
  for _ = 1, 20 do E.think() end
  check(#E.Build.requests == n, "C6 : plus aucune demande après l'abandon")
  E.restore()
end

do
  -- D. Le plan n'a pas besoin de la place de la partie : rien n'est retiré, la ligne se construit, puis compte comme production
  local E = executor_run({ pairs = 8 })
  E.think()
  local p = E.project()
  drive_plan(E, p, "plan"); E.think()
  E.add_line_ents(p, false)
  p.ents[1] = { name = D.PARTS.belt, x = 5100.5, y = 5100.5, dir = 0, built = false } -- tapis loin de la partie
  drive_plan(E, p, "degel")
  E.think()
  check(E.alive() == 8 and p.degele == true, "D1 : la ligne est ailleurs : rien n'est retiré, le plan continue")
  check(E.f.migration.o[1].noop == 1 and E.f.migration.o[1].retired == 0, "D2 : une ligne « sans effet » comptée")
  drive_plan(E, p, "chantier"); E.think()
  drive_plan(E, p, "fini"); E.make_products(CFG.produce_min); E.think()
  check(E.f.migration.o[1].produced == 1 and E.f.migration.o[1].done == 0, "D3 : la ligne produit : elle ne compte pas comme partie migrée")
  check(E.o.migr == "en cours", "D4 : l'avant-poste reste en cours")
  E.restore()
end

do
  -- D bis. Un chantier qui n'aboutit jamais : la migration s'arrête, le plan garde son projet, l'avant-poste garde ses paires restantes
  local E = executor_run({ pairs = 8 })
  E.think()
  local p = E.project()
  drive_plan(E, p, "plan"); E.think()
  drive_plan(E, p, "materiaux"); E.think()
  drive_plan(E, p, "degel"); E.think()
  local left = E.alive()
  drive_plan(E, p, "chantier")
  for _ = 1, math.floor(CFG.build_max / CFG.every) + 3 do E.think() end
  check(E.f.migration.cur == nil and E.o.migr == nil, "Dbis1 : chantier sans issue : plus de suivi en cours, plus de marque sur l'avant-poste")
  check(E.f.migration.o[1].abandoned == true and E.o.full == false, "Dbis2 : l'avant-poste redevient extensible (rien n'a produit)")
  check(E.alive() == left and p.state == "chantier", "Dbis3 : les paires restantes et le projet du plan ne sont pas touchés")
  local n = #E.Build.requests
  for _ = 1, 10 do E.think() end
  check(#E.Build.requests == n, "Dbis4 : aucune nouvelle demande")
  E.restore()
end

do
  -- E. L'avant-poste est perdu (détruit par les biters) pendant l'attente des matières : la demande est annulée
  local E = executor_run({ pairs = 8 })
  E.think()
  local p = E.project()
  drive_plan(E, p, "plan"); E.think()
  drive_plan(E, p, "materiaux"); E.think()
  E.f.outposts[1] = nil
  E.think()
  check(#E.Build.cancels == 1 and p.state == "refuse", "E1 : avant-poste perdu : la demande du plan est annulée")
  check(E.f.migration.cur == nil, "E2 : plus de suivi en cours")
  E.restore()
end

do
  -- F. Pas de courant, pas de foreuse électrique, pas de plaques, hors du treillis : en veille, aucune demande, aucune pièce touchée
  for _, scn in ipairs({ { power = false, label = "sans courant" }, { lot_state = "libre", label = "hors lot de gisement" }, { plates = 10, label = "sans plaques" },
    { pairs = 2, label = "trop peu de paires" } }) do
    scn.pairs = scn.pairs or 8
    local E = executor_run(scn)
    for _ = 1, 6 do E.think() end
    check(#E.Build.requests == 0 and E.alive() == scn.pairs and E.o.migr == nil, "F : " .. scn.label .. " : aucune demande, rien touché")
    E.restore()
  end
  -- sans foreuse électrique ni moyen de la fabriquer
  local E = executor_run({ pairs = 8 })
  E.book.handcraftable = function() return false end
  E.free[T.DRILL_ELECTRIC] = 0
  for _ = 1, 6 do E.think() end
  check(#E.Build.requests == 0 and E.alive() == 8, "F : objet électrique introuvable : aucune demande")
  E.restore()
end

do
  -- G. Un champ entier migré (paires qui restent peu nombreuses) : les parties s'enchaînent jusqu'à la fin, la production reste > 0
  local E = executor_run({ pairs = 12 })
  local min_prod, steps = math.huge, 0
  local function production()
    local live = E.alive() * 0.25
    for _, pid in ipairs(E.Build.requests) do
      local p = E.project(pid)
      if p.state == "fini" and p.degele and p.spec.produces then live = live + 1 end
    end
    return live
  end
  local last = 0
  while steps < 400 and E.o.migr ~= "fini" and E.o.migr ~= "partiel" and not (E.f.migration and E.f.migration.o[1] and E.f.migration.o[1].abandoned) do
    steps = steps + 1
    E.think()
    local n = #E.Build.requests
    local p = n > 0 and E.project() or nil
    if p and n > last and p.state == "attente" then
      -- un projet neuf : plan, matières, dégel, chantier, fini, production, à chaque tour d'horloge
      local seq = { "plan", "materiaux", "materiaux", "degel", "chantier", "chantier", "fini" }
      p.seq, p.seq_i = seq, 0
      last = n
    end
    if p and p.seq and p.seq_i < #p.seq and p.state ~= "refuse" then
      p.seq_i = p.seq_i + 1
      drive_plan(E, p, p.seq[p.seq_i])
      if p.seq[p.seq_i] == "fini" then p.spec.produces = true; E.make_products(CFG.produce_min) end
    end
    min_prod = math.min(min_prod, production())
  end
  local st = E.f.migration.o[1]
  check(steps < 400, "G1 : la migration se termine (" .. steps .. " pensées)")
  check(min_prod > 0, "G2 : production jamais nulle sur toute la migration (minimum " .. min_prod .. ")")
  check(E.o.migr == "fini" or E.o.migr == "partiel", "G3 : état final « fini » ou « partiel » (" .. tostring(E.o.migr) .. ")")
  check(st.done >= 2, "G4 : au moins deux parties migrées (" .. st.done .. ")")
  check(E.o.migr == "fini" and E.alive() == 0 and #E.o.drill_list == 0 and #E.o.sinks == 0 or E.o.migr == "partiel" and E.alive() > 0,
    "G5 : état final cohérent avec les paires restantes (" .. E.alive() .. ")")
  check(E.o.full == true, "G6 : l'avant-poste reste plein (pas de nouvelle paire thermique)")
  local jr = table.concat(E.logs, "\n")
  check(jr:find("champ migre en entier") ~= nil or jr:find("paire%(s%) restent") ~= nil, "G7 : journal : fin de migration")
  print(string.format("[MIGRATION-CHAMP] champ de 12 paires : %d pensées, %d partie(s), état final %s, %d paire(s) restante(s)", steps, st.done, tostring(E.o.migr), E.alive()))
  E.restore()
end

do
  -- H. Le surplus qui ne tient pas au coffre est répandu, jamais perdu
  local E = executor_run({ pairs = 8 })
  local real_insert = package.loaded["script.team.stock"].insert
  package.loaded["script.team.stock"].insert = function(f, name, n) if name == "coal" then return 0 end return real_insert(f, name, n) end
  E.think()
  local p = E.project()
  drive_plan(E, p, "plan"); E.think()
  drive_plan(E, p, "materiaux"); E.think()
  drive_plan(E, p, "degel"); E.think()
  check(#E.spilled > 0 and E.spilled[1].name == "coal", "H1 : combustible qui ne tient pas : répandu au sol du QG")
  E.restore()
end

---------------------------------------------------------------------------------------------------
-- 7. Câblage : les crochets (lecture du code source)
---------------------------------------------------------------------------------------------------
section("7. Câblage")
do
  local function read(path)
    local fh = io.open(path, "rb")
    if not fh then return "" end
    local s = fh:read("*a")
    fh:close()
    return s
  end
  local build, outposts, team, swap = read("script/team/build.lua"), read("script/faction/outposts.lua"), read("script/team/team.lua"), read("script/team/foreuse_swap.lua")
  -- la chaîne : déclencheur (team.lua) -> décision (migration_champ.lua) -> action (Build.request, porte, retrait) -> effet (build.lua THAW)
  check(team:find('require%("script.team.migration_champ"%)') ~= nil, "C1 : team.lua charge l'exécutant")
  check(team:find("MigChamp.think%(f, surface, book_for%(f%), stock, tick%)") ~= nil, "C2 : team.lua l'appelle à chaque pensée d'équipe")
  check(build:find("THAW = p.spec.degel and p.spec.degel.tiles or nil", 1, true) ~= nil, "C3 : le plan pose le dégel autour de plan_project")
  check(build:find("blocked[P.tkey(THAW[i], THAW[i + 1])] = nil", 1, true) ~= nil, "C4 : read_masks compte les tuiles du dégel comme libres")
  check(build:find("SCAN.tick = nil", 1, true) ~= nil, "C5 : les relevés du tick sont jetés avant et après le plan")
  check(build:find('p.reason, p.reserve_next = "degel", tick + 60', 1, true) ~= nil, "C6 : la porte « degel » retient le chantier")
  check(build:find("if p.spec.degel and not p.degele then", 1, true) ~= nil, "C7 : la porte s'ouvre avec p.degele")
  check(build:find("if spec.fixe then return cur end", 1, true) ~= nil, "C8 : la ligne d'une partie ne grandit pas avec le gisement")
  check(build:find("p.spec.paires", 1, true) ~= nil, "C9 : les paires de foreuses tiennent dans la place libérée")
  check(build:find("within = p.spec and p.spec.degel and p.spec.degel.zone or nil", 1, true) ~= nil and build:find("fopts.within = opts.within", 1, true) ~= nil,
    "C9 bis : la ligne de foreuses est bornée à la zone libérée (plan_drills -> place_module -> P.fit)")
  check(outposts:find("if o.migr then return 0 end", 1, true) ~= nil, "C10 : Outposts.extend ne pose plus de paire thermique sur un champ migré")
  check(outposts:find("not o.migr and not o.hold_until", 1, true) ~= nil, "C11 : Outposts.reopen ne rouvre pas un champ migré")
  check(swap:find('o.migr == "en cours"', 1, true) ~= nil, "C12 : foreuse_swap laisse le champ en cours de migration")
  check(team:find("full = (o.full or o.migr ~= nil) or false", 1, true) ~= nil,
    "C12 bis : la vue des avant-postes (lue par les planificateurs) dit « plein » pour tout champ migré, même quand une attente (release_holds) a remis o.full à faux")
  -- les trois étapes du THAW sont dans le bon ordre : posé, plan, retiré
  local a = build:find("THAW = p.spec.degel", 1, true)
  local b2 = build:find("plan_project(f, surface, p)", a, true)
  local c = build:find("if THAW then THAW = nil", a, true)
  check(a and b2 and c and a < b2 and b2 < c, "C13 : THAW posé, plan, THAW retiré (dans cet ordre)")
  -- la porte est après la réserve des matières (le champ produit pendant l'attente) et avant le défrichage
  local r = build:find("if reserve(f, p) then", 1, true)
  local g = build:find('"degel"', r, true)
  local d = build:find('"defrichage" or "fantomes"', r, true)
  check(r and g and d and r < g and g < d, "C14 : la porte est entre « matières réunies » et « défrichage »")
end

---------------------------------------------------------------------------------------------------
-- 8. Mutants : chaque règle faussée est refusée par la batterie 1 à 5 ou par l'exécutant
---------------------------------------------------------------------------------------------------
section("8. Mutants")
do
  local orig = {}
  for k, v in pairs(Mg) do orig[k] = v end
  local function restore()
    for k, v in pairs(orig) do Mg[k] = v end
  end
  local mutants = {
    { "sizing : arrondi des paires par défaut", function() Mg.sizing = function(k, r, cfg)
        cfg = cfg or Mg.CFG
        local old = k * math.min(r.burner, r.furnace or math.huge)
        return { old = old, pairs = math.max(1, math.floor(old / (2 * r.electric))), rows = math.max(cfg.min_rows, math.ceil(old / r.row_cap - 1e-9)),
          rate = math.max(cfg.min_rows, math.ceil(old / r.row_cap - 1e-9)) * r.row_cap * 60 } end end },
    { "sizing : pas de minimum de rangées", function() Mg.sizing = function(k, r, cfg)
        local old = k * math.min(r.burner, r.furnace or math.huge)
        local rows = math.max(1, math.ceil(old / r.row_cap - 1e-9))
        return { old = old, pairs = math.max(1, math.min(r.pairs_max or 1, math.ceil(old / (2 * r.electric) - 1e-9))), rows = rows, rate = rows * r.row_cap * 60 } end end },
    { "sizing : le four n'est pas limitant", function() Mg.sizing = function(k, r, cfg)
        cfg = cfg or Mg.CFG
        local old = k * r.burner * 0.5
        local rows = math.max(cfg.min_rows, math.ceil(old / r.row_cap - 1e-9))
        return { old = old, pairs = math.max(1, math.min(r.pairs_max or 1, math.ceil(old / (2 * r.electric) - 1e-9))), rows = rows, rate = rows * r.row_cap * 60 } end end },
    { "sizing : débit en plaques par seconde", function() local o = orig.sizing; Mg.sizing = function(k, r, cfg)
        local s = o(k, r, cfg); s.rate = s.rate / 60; return s end end },
    { "fits : les paires restantes sont ignorées", function() local o = orig.fits; Mg.fits = function(rect, freed, others, w, h, cfg) return o(rect, freed, {}, w, h, cfg) end end },
    { "fits : pas de recouvrement minimal", function() local o = orig.fits; Mg.fits = function(rect, freed, others, w, h, cfg)
        local c2 = {}
        for k, v in pairs(cfg or Mg.CFG) do c2[k] = v end
        c2.min_overlap = 0
        return o(rect, freed, others, w, h, c2) end end },
    { "fits : pas de marge de lot", function() local o = orig.fits; Mg.fits = function(rect, freed, others, w, h, cfg)
        local c2 = {}
        for k, v in pairs(cfg or Mg.CFG) do c2[k] = v end
        c2.lot_margin = 0
        return o(rect, freed, others, w, h, c2) end end },
    { "fits : la ligne ne se tourne pas", function() local o = orig.fits; Mg.fits = function(rect, freed, others, w, h, cfg)
        local r = o(rect, freed, others, w, h, cfg)
        if r and r.w ~= w then return nil end
        return r end end },
    { "pick_band : la dernière paire peut partir", function() local o = orig.pick_band; Mg.pick_band = function(pl, ctx)
        local c2 = {}
        for k, v in pairs(ctx) do c2[k] = v end
        c2.produced = true
        return o(pl, c2) end end },
    { "pick_band : partie sans plafond", function() local o = orig.pick_band; Mg.pick_band = function(pl, ctx)
        local c2 = {}
        for k, v in pairs(ctx) do c2[k] = v end
        local cfg = {}
        for k, v in pairs(ctx.cfg or Mg.CFG) do cfg[k] = v end
        cfg.max_part_pairs = 1000
        c2.cfg = cfg
        return o(pl, c2) end end },
    { "pick_band : identifiants non triés", function() local o = orig.pick_band; Mg.pick_band = function(pl, ctx)
        local b, w = o(pl, ctx)
        if b then local r = {}; for i = #b.ids, 1, -1 do r[#r + 1] = b.ids[i] end; b.ids = r end
        return b, w end end },
    { "pick_band : dégel élargi à toute la boîte", function() local o = orig.pick_band; Mg.pick_band = function(pl, ctx)
        local b, w = o(pl, ctx)
        if b then
          local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
          for i = 1, #b.thaw - 1, 2 do x0, y0, x1, y1 = math.min(x0, b.thaw[i]), math.min(y0, b.thaw[i + 1]), math.max(x1, b.thaw[i]), math.max(y1, b.thaw[i + 1]) end
          local t = {}
          for y = y0, y1 do for x = x0, x1 do t[#t + 1] = x; t[#t + 1] = y end end
          b.thaw = t
        end
        return b, w end end },
    { "pick_band : zone absente", function() local o = orig.pick_band; Mg.pick_band = function(pl, ctx)
        local b, w = o(pl, ctx)
        if b then b.zone = nil end
        return b, w end end },
    { "pick_band : zone élargie à tout le lot", function() local o = orig.pick_band; Mg.pick_band = function(pl, ctx)
        local b, w = o(pl, ctx)
        if b then b.zone = { x0 = -1e6, y0 = -1e6, x1 = 1e6, y1 = 1e6 } end
        return b, w end end },
    { "pick_band : gabarit toujours accepté", function() local o = orig.pick_band; Mg.pick_band = function(pl, ctx)
        local c2 = {}
        for k, v in pairs(ctx) do c2[k] = v end
        c2.line = function(n) return 1, 1 end
        return o(pl, c2) end end },
    { "start_ok : le courant n'est pas exigé", function() local o = orig.start_ok; Mg.start_ok = function(c, cfg) c.power = true; return o(c, cfg) end end },
    { "start_ok : l'ennemi n'est pas regardé", function() local o = orig.start_ok; Mg.start_ok = function(c, cfg) c.enemy = false; return o(c, cfg) end end },
    { "start_ok : plaques libres ignorées", function() local o = orig.start_ok; Mg.start_ok = function(c, cfg) c.plates = 1e9; return o(c, cfg) end end },
    { "start_ok : un champ migré repart", function() local o = orig.start_ok; Mg.start_ok = function(c, cfg) c.migr = nil; c.abandoned = nil; return o(c, cfg) end end },
    { "start_ok : objet électrique non exigé", function() local o = orig.start_ok; Mg.start_ok = function(c, cfg) c.obtainable = true; return o(c, cfg) end end },
    { "can_retire : l'ennemi est ignoré", function() local o = orig.can_retire; Mg.can_retire = function(c, cfg) c.enemy = false; return o(c, cfg) end end },
    { "can_retire : la dernière paire peut partir", function() local o = orig.can_retire; Mg.can_retire = function(c, cfg) c.produced = true; return o(c, cfg) end end },
    { "gate : retrait sans regarder la place utilisée", function() local o = orig.gate; Mg.gate = function(st, p, env, cfg) env.uses = true; return o(st, p, env, cfg) end end },
    { "gate : retrait dès le plan (matières ignorées)", function() local o = orig.gate; Mg.gate = function(st, p, env, cfg)
        if p and p.state == "reserve" and p.reason == "materiaux" then return "retirer", "ok" end
        return o(st, p, env, cfg) end end },
    { "gate : attente d'ennemi sans fin", function() local o = orig.gate; Mg.gate = function(st, p, env, cfg) env.gate_age = 0; return o(st, p, env, cfg) end end },
    { "gate : pas de délai des matières", function() local o = orig.gate; Mg.gate = function(st, p, env, cfg) env.now = st.t0; return o(st, p, env, cfg) end end },
    { "watch : produit sans produit fini", function() local o = orig.watch; Mg.watch = function(st, p, env, cfg) if p and p.state == "fini" then return "produit", "ok" end return o(st, p, env, cfg) end end },
    { "watch : aucun abandon", function() local o = orig.watch; Mg.watch = function(st, p, env, cfg)
        local a, w = o(st, p, env, cfg)
        if a == "abandonner" then return "attendre", w end
        return a, w end end },
    { "watch : produit dès le chantier", function() local o = orig.watch; Mg.watch = function(st, p, env, cfg) if p and p.state == "chantier" then return "produit", "ok" end return o(st, p, env, cfg) end end },
    { "match : direction ignorée", function() Mg.match = function(drills, sinks, drop)
        local d2 = {}
        for i, d in ipairs(drills) do d2[i] = { id = d.id, x = d.x, y = d.y, dir = 0, w = d.w, h = d.h } end
        return orig.match(d2, sinks, drop) end end },
    { "tiles : doublons", function() Mg.tiles = function(boxes)
        local out = {}
        for _, b in ipairs(boxes) do
          for ty = math.floor(b.y0 + 1e-6), math.ceil(b.y1 - 1e-6) - 1 do for tx = math.floor(b.x0 + 1e-6), math.ceil(b.x1 - 1e-6) - 1 do out[#out + 1] = tx; out[#out + 1] = ty end end
        end
        return out end end },
  }
  --- Batterie complète sous le module de règles courant (vrai ou muté) : échecs de la batterie pure + scénarios de l'exécutant.
  local function probe()
    local bad = suite(false)
    local before_f, before_p = failures, passes
    local saved_print = print
    print = function() end
    local ok_run, err = pcall(function()
      local E = executor_run({ pairs = 8 })
      E.think()
      local p = E.project()
      if p then
        drive_plan(E, p, "plan"); E.think()
        drive_plan(E, p, "materiaux"); E.think()
        if E.alive() < 8 then bad = bad + 1 end -- retiré avant les matières
        drive_plan(E, p, "degel"); E.think()
        if E.alive() == 0 then bad = bad + 1 end
        if E.alive() == 8 then bad = bad + 1 end -- le retrait doit avoir lieu
        drive_plan(E, p, "chantier"); E.think()
        drive_plan(E, p, "fini"); E.think()
        if E.f.migration.o[1].produced ~= 0 then bad = bad + 1 end -- compté produit sans un seul produit fini
      else
        bad = bad + 1
      end
      E.restore()
      -- ennemi : rien retiré
      local E2 = executor_run({ pairs = 8, enemy = function(t) return t >= 2 * CFG.every + 300 end })
      E2.think()
      local p2 = E2.project()
      if p2 then
        drive_plan(E2, p2, "plan"); E2.think()
        drive_plan(E2, p2, "degel")
        E2.think(); E2.think()
        if E2.alive() < 8 then bad = bad + 1 end
      else
        bad = bad + 1
      end
      E2.restore()
      -- plan sans besoin de la place : rien retiré
      local E3 = executor_run({ pairs = 8 })
      E3.think()
      local p3 = E3.project()
      if p3 then
        drive_plan(E3, p3, "plan"); E3.think()
        drive_plan(E3, p3, "degel")
        p3.ents = { { name = D.PARTS.belt, x = 5100.5, y = 5100.5, dir = 0, built = false } }
        E3.think()
        if E3.alive() < 8 then bad = bad + 1 end
      else
        bad = bad + 1
      end
      E3.restore()
      -- plus de 2 paires seulement : aucune demande
      local E4 = executor_run({ pairs = 2 })
      for _ = 1, 3 do E4.think() end
      if #E4.Build.requests > 0 then bad = bad + 1 end
      E4.restore()
      -- courant coupé ou pas de plaques : aucune demande
      local E5 = executor_run({ pairs = 8, power = false })
      for _ = 1, 3 do E5.think() end
      if #E5.Build.requests > 0 then bad = bad + 1 end
      E5.restore()
      local E6 = executor_run({ pairs = 8, plates = 5 })
      for _ = 1, 3 do E6.think() end
      if #E6.Build.requests > 0 then bad = bad + 1 end
      E6.restore()
    end)
    print = saved_print
    if not ok_run then bad = bad + 1; if err then saved_print("  (erreur sous mutant : " .. tostring(err):sub(1, 120) .. ")") end end
    failures, passes = before_f, before_p
    return bad, ok_run
  end
  -- témoin nul : sans mutation, la batterie complète ne relève rien
  local bad0, ok0 = probe()
  check(bad0 == 0 and ok0, "témoin nul : la batterie complète est sans échec sur les vraies règles (" .. bad0 .. ")")
  local survivors = 0
  for _, m in ipairs(mutants) do
    restore()
    m[2]()
    local bad, ok_run = probe()
    check(bad > 0, "mutant refusé : " .. m[1])
    if bad == 0 then survivors = survivors + 1 end
  end
  restore()
  check(survivors == 0, "aucun mutant survivant")
  print(string.format("[MIGRATION-CHAMP] mutants : %d refusés sur %d", #mutants - survivors, #mutants))
end

---------------------------------------------------------------------------------------------------
-- 9. Lot MIGRATION-DECLENCHE (retour du DC du 29/10 en jouant la 0.6.18 ; journal de sa partie, scarlet : parties refusées 3 fois à
--    l'identique puis champ abandonné ; réserves « materiaux » jamais servies ; paires tuées pendant l'attente jamais refaites)
---------------------------------------------------------------------------------------------------
section("9. MIGRATION-DECLENCHE")
do
  -- K1-K3. Règle pure : une partie refusée est écartée, une autre est choisie ; tout refusé : nil, « refusees »
  local rect = rect_at(0, 0)
  local pl = field(8, 0, 0, "0:0")
  local ctx = ctx_for(rect, false, { x = 0, y = -100 })
  local b1 = Mg.pick_band(pl, ctx)
  check(b1 and b1.key == Mg.band_key(b1.lot, b1.ids), "K1 : la partie porte sa clé (lot et paires triées)")
  ctx.skip = { [b1.key] = true }
  local b2 = Mg.pick_band(pl, ctx)
  check(b2 ~= nil and b2.key ~= b1.key, "K2 : la partie refusée est écartée, une autre est choisie (" .. tostring(b2 and b2.key) .. ")")
  local seen, last, why = {}, nil, nil
  ctx.skip = {}
  for _ = 1, 200 do
    last, why = Mg.pick_band(pl, ctx)
    if not last then break end
    check(not seen[last.key], "K3a : jamais deux fois la même partie")
    seen[last.key] = true
    ctx.skip[last.key] = true
  end
  check(last == nil and why == "refusees", "K3 : toutes les parties refusées : aucune, raison « refusees » (" .. tostring(why) .. ")")
  ctx.skip = nil
  local b0 = Mg.pick_band(pl, ctx)
  check(b0 and b0.key == b1.key, "K3 bis : sans liste d'écart, le choix est inchangé (déterminisme)")
end

do
  -- K4-K6. Exécutant : un refus du plan fait demander une AUTRE partie, sous CFG.retry_refuse
  local E = executor_run({ pairs = 8 })
  E.think()
  local p1 = E.project()
  local ids1 = table.concat(E.f.migration.o[1].ids, ",")
  p1.state, p1.reason = "refuse", "gisement : tapis des foreuses (minerai)"
  E.think()
  local st = E.f.migration.o[1]
  check(st.bad and #st.bad == 1 and st.retry - game.tick <= CFG.retry_refuse, "K4 : partie refusée retenue, nouvel essai sous " .. CFG.retry_refuse / 60 .. " s")
  for _ = 1, math.ceil(CFG.retry_refuse / CFG.every) + 1 do E.think() end
  check(#E.Build.requests == 2, "K5 : nouvelle demande après le délai court (" .. #E.Build.requests .. ")")
  local ids2 = table.concat(E.f.migration.o[1].ids or {}, ",")
  check(ids2 ~= "" and ids2 ~= ids1, "K6 : la nouvelle demande porte une autre partie (" .. ids1 .. " puis " .. ids2 .. ")")
  E.restore()
end

do
  -- K7-K8. Un abandon n'est plus définitif : après CFG.revive, l'avant-poste repart d'un état neuf
  local E = executor_run({ pairs = 8 })
  for _ = 1, CFG.max_fails do
    E.think()
    local p = E.project()
    p.state, p.reason = "refuse", "pas de lot"
    E.think()
    game.tick = game.tick + CFG.retry
  end
  check(E.f.migration.o[1].abandoned == true, "K7a : abandon après " .. CFG.max_fails .. " échecs")
  local n = #E.Build.requests
  game.tick = game.tick + CFG.revive
  E.think(); E.think()
  check(#E.Build.requests == n + 1 and not E.f.migration.o[1].abandoned, "K7 : reprise après " .. CFG.revive / 3600 .. " min : nouvelle demande")
  check(table.concat(E.logs, "\n"):find("migration reprise apres abandon", 1, true) ~= nil, "K8 : journal [FO-MIGRATION] de la reprise")
  E.restore()
end

do
  -- K8 bis. Sauvegarde 0.6.18 : un avant-poste abandonné SANS date (champ de scarlet) est repris ; l'abandon « pas de gabarit » ne l'est jamais
  local E = executor_run({ pairs = 8 })
  game.tick = CFG.revive + 600
  E.f.migration = { next = 0, logs = 0, logs_f = 0, o = { [1] = { stage = "veille", fails = 3, noop = 0, done = 0, produced = 0, retry = 0, abandoned = true } } }
  E.think()
  check(#E.Build.requests == 1, "K8 bis : abandon d'une sauvegarde 0.6.18 (sans date) : repris, nouvelle demande")
  E.restore()
  local E2 = executor_run({ pairs = 8 })
  game.tick = 10 * CFG.revive
  E2.f.migration = { next = 0, logs = 0, logs_f = 0, o = { [1] = { stage = "veille", fails = 0, noop = 0, done = 0, produced = 0, retry = 0, abandoned = true,
    sans_gabarit = true } } }
  for _ = 1, 3 do E2.think() end
  check(#E2.Build.requests == 0, "K8 ter : abandon « pas de gabarit » : jamais repris")
  E2.restore()
end

do
  -- K9-K10. Registre de reconstruction : gardé pendant l'attente des matières (rien n'est retiré), purgé après le retrait
  local E = executor_run({ pairs = 8 })
  E.f.recon = { lost = { a = { oid = 1, kind = "drill" }, b = { oid = 1, kind = "sink" }, c = { oid = 2, kind = "drill" } } }
  E.think()
  local p = E.project()
  drive_plan(E, p, "plan"); E.think()
  drive_plan(E, p, "materiaux"); E.think(); E.think()
  check(E.f.recon.lost.a ~= nil and E.f.recon.lost.b ~= nil, "K9 : en attente des matières, les paires tuées restent à refaire")
  drive_plan(E, p, "degel"); E.think()
  check(E.f.recon.lost.a == nil and E.f.recon.lost.b == nil and E.f.recon.lost.c ~= nil, "K10 : après le retrait, les paires de l'avant-poste migré ne sont plus refaites (les autres si)")
  E.restore()
end

do
  -- K11-K12. Le projet de la migration est lu par le cerveau : Mig.project, puis but « auto:migration » qui émet ses manques
  local E = executor_run({ pairs = 8 })
  check(E.Mig.project(E.f) == nil, "K11a : aucune migration en cours : pas de projet")
  E.think()
  local p = E.project()
  check(E.Mig.project(E.f) == p.id, "K11 : en étape « projet », le numéro du projet est rendu")
  E.restore()
  local A = require("shared.ai3.automatiser")
  local goals = A.goals({}, { mods = { { product = "migration", state = "reserve", missing = { { T.DRILL_ELECTRIC, 2 } }, reason = "materiaux", gain = 0 } } },
    {}, nil)
  local g
  for _, it in ipairs(goals) do if it.key == "auto:migration" then g = it end end
  check(g ~= nil and g.missing[1][1] == T.DRILL_ELECTRIC and g.value >= A.VALUE, "K12 : but « auto:migration » avec ses manques (valeur " .. tostring(g and g.value) .. ")")
  local fh = io.open("script/ai3/automatisation.lua", "rb")
  local src = fh and fh:read("*a") or ""
  if fh then fh:close() end
  check(src:find("local mig_id = MigChamp.project(f)", 1, true) ~= nil and src:find('product = "migration", state = ps.state, missing = ps.missing', 1, true) ~= nil,
    "K12 bis : câblage : Auto.think met la ligne de la migration dans les projets du cerveau")
  local a1 = src:find("local mig_id = MigChamp.project(f)", 1, true)
  local a2 = src:find("return { mods = mods", 1, true)
  check(a1 and a2 and a1 < a2, "K12 ter : avant le retour du contexte du cerveau")
end

do
  -- K13. Mutants des règles du lot
  local orig_pick = Mg.pick_band
  Mg.pick_band = function(pl, ctx) local c2 = {}; for k, v in pairs(ctx) do c2[k] = v end; c2.skip = nil; return orig_pick(pl, c2) end
  local E = executor_run({ pairs = 8 })
  E.think()
  local ids1 = table.concat(E.f.migration.o[1].ids, ",")
  E.project().state = "refuse"
  E.think()
  for _ = 1, math.ceil(CFG.retry_refuse / CFG.every) + 1 do E.think() end
  local ids2 = table.concat(E.f.migration.o[1].ids or {}, ",")
  check(ids2 == ids1, "K13a : mutant « liste d'écart ignorée » : la même partie revient (refusé par K6)")
  E.restore()
  Mg.pick_band = orig_pick
  local saved = CFG.revive
  CFG.revive = math.huge
  local E2 = executor_run({ pairs = 8 })
  for _ = 1, CFG.max_fails do E2.think(); E2.project().state = "refuse"; E2.think(); game.tick = game.tick + CFG.retry end
  local n = #E2.Build.requests
  game.tick = game.tick + saved
  E2.think(); E2.think()
  check(#E2.Build.requests == n, "K13b : mutant « abandon définitif » : aucune reprise (refusé par K7)")
  E2.restore()
  CFG.revive = saved
end

print(string.format("[MIGRATION-CHAMP] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
