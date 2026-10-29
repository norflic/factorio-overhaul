--[[
  Tests hors jeu du lot FONDERIE-DYNAMIQUE (arbitrage du DC du 29/10 au soir : « la fonderie grandit en fonction du nombre de foreuses
  qu'elle a en input, donc dynamiquement, ni 2, ni 4, ni 8, mais dynamique »).
  Usage, depuis la racine du mod :   lua5.2 tests/fonderie_dyn_test.lua

  1. rangées des gabarits réels (Ligne.rows_of) : chaque rangée de la fonderie porte 2 fours et 4 bras, chaque paire 2 foreuses ; le
     squelette (tapis, poteaux) n'a pas de rangée ; les k premières rangées de la ligne de n sont la fonderie de k (mêmes pièces, mêmes
     places) : poser par étapes donne la même usine ;
  2. taille de départ (Fonte.initial) : sans plancher, nourrie par les foreuses, bornée par le stock ;
  3. pas de croissance (Fonte.step) : table de cas, bornes une à une, jamais de four sans minerai, jamais de retrait ;
  4. croissance pure jouée jusqu'au bout : monotone, bornée par la place réservée, finit à l'équilibre ou plein ; « ni 2, ni 4, ni 8 » ;
  5. exécutant (script/team/build.lua) au moteur simulé réduit : Build.ligne_split puis Build.ligne_step -> relevé -> Fonte.step ->
     pièces rendues, projet rouvert, journal [FO-FONTE] ; pauvre puis enrichi, riche, minerai épuisé, pièces manquantes, foreuses à
     l'arrêt, foreuses améliorées, ancien projet (sans p.ligne) intact, déterminisme ;
  6. câblage (lecture des sources) et mutants de la règle.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end

local M = require("shared.team.modules")
local Li = require("shared.team.ligne")
local T = require("shared.team.config")
local FONTE_SRC = read("shared/team/fonte.lua")
local function load_fonte(src)
  local fn = assert(load(src, "=fonte", "t"))
  return fn()
end
local Fonte = load_fonte(FONTE_SRC)

local STONE, STEEL = "stone-furnace", "steel-furnace"
local ORE = "iron-ore"
local function kind(e) local sp = M.spec(e.name) return sp and sp.kind end
local function four_piece(e) local k = kind(e) return k == "furnace" or k == "inserter" end
local function drill_piece(e) return kind(e) == "drill" end

---------------------------------------------------------------------------------------------------
section("1. Rangées des gabarits réels")
---------------------------------------------------------------------------------------------------
do
  local cases = 0
  for _, furnace in ipairs({ STONE, STEEL }) do
    for _, sortie in ipairs({ "centre", "exterieur" }) do
      local g0 = M.GEN.smelter(furnace, ORE, 1, sortie)
      local nmax = g0.extensions[1].max
      local side = M.spec(furnace).w
      for n = 1, math.min(nmax, 12) do
        local g = M.GEN.smelter(furnace, ORE, n, sortie)
        local rows = Li.rows_of(g.entities, side, 0, four_piece)
        local per, skel_ok = {}, true
        for i, e in ipairs(g.entities) do
          local r = rows[i]
          if four_piece(e) then
            if not r then skel_ok = false else per[r] = per[r] or { f = 0, i = 0 }; if kind(e) == "furnace" then per[r].f = per[r].f + 1 else per[r].i = per[r].i + 1 end end
          elseif r then skel_ok = false end
        end
        local rows_ok = true
        for r = 1, n do if not (per[r] and per[r].f == 2 and per[r].i == 4) then rows_ok = false end end
        for r in pairs(per) do if r < 1 or r > n then rows_ok = false end end
        local tag = string.format("%s %s n=%d", furnace, sortie, n)
        check(skel_ok, tag .. " : fours et bras ont une rangée, tapis et poteaux n'en ont pas")
        check(rows_ok, tag .. " : chaque rangée porte 2 fours et 4 bras")
        -- préfixe : les k premières rangées de la ligne de n = les fours et bras de la fonderie de k (mêmes places)
        for k = 1, n - 1 do
          local gk = M.GEN.smelter(furnace, ORE, k, sortie)
          local want = {}
          for _, e in ipairs(gk.entities) do if four_piece(e) then want[#want + 1] = string.format("%s@%g,%g:%d", e.name, e.x, e.y, e.dir or 0) end end
          local got = {}
          for i, e in ipairs(g.entities) do if rows[i] and rows[i] <= k then got[#got + 1] = string.format("%s@%g,%g:%d", e.name, e.x, e.y, e.dir or 0) end end
          table.sort(want); table.sort(got)
          check(table.concat(want, ";") == table.concat(got, ";"), tag .. " : rangées 1.." .. k .. " = la fonderie de " .. k)
        end
        check(#M.check(g) == 0, tag .. " : la ligne entière (squelette compris) passe M.check (poteaux de toutes les rangées)")
        cases = cases + 1
      end
    end
  end
  check(cases >= 20, "cas joués : " .. cases)
  local gd0 = M.GEN.drills(ORE, 1)
  local side = M.spec(gd0.params.drill).w
  for n = 1, gd0.extensions[1].max do
    local gd = M.GEN.drills(ORE, n)
    local rows = Li.rows_of(gd.entities, side, 1, drill_piece)
    local per, ok = {}, true
    for i, e in ipairs(gd.entities) do
      if drill_piece(e) then if not rows[i] then ok = false else per[rows[i]] = (per[rows[i]] or 0) + 1 end
      elseif rows[i] then ok = false end
    end
    for r = 1, n do if per[r] ~= 2 then ok = false end end
    check(ok, string.format("foreuses n=%d : chaque paire porte 2 foreuses, le tapis et les poteaux sont le squelette", n))
  end
  check(next(Li.rows_of({ { name = "x", y = 3 } }, 0, 0, function() return true end)) == nil, "pas nul : aucune rangée")
end

---------------------------------------------------------------------------------------------------
section("2. Taille de départ (Fonte.initial)")
---------------------------------------------------------------------------------------------------
local CAP, DR = 1 / 3.2, 0.5 -- four de pierre (plaque de fer), foreuse électrique
do
  local r, p, why = Fonte.initial({ rows_max = 6, pairs_max = 4, drill_rate = DR, cap = CAP })
  check(r == 6 and p == 4 and why == "foreuses", "riche (sans borne) : 4 paires, 6 rangées nourries (" .. r .. ", " .. p .. ", " .. why .. ")")
  r, p, why = Fonte.initial({ rows_max = 6, pairs_max = 4, drill_rate = DR, cap = CAP, budget = 0 })
  check(r == 1 and p == 1 and why == "budget", "pauvre (stock nul) : 1 paire, 1 rangée, pas 4 (" .. r .. ", " .. p .. ")")
  r, p, why = Fonte.initial({ rows_max = 6, pairs_max = 4, drill_rate = DR, cap = CAP, budget = 2 })
  check(r == 2 and p == 2 and why == "budget", "2 unités : 2 paires, 2 rangées (" .. r .. ", " .. p .. ")")
  r, p = Fonte.initial({ rows_max = 12, pairs_max = 1, drill_rate = DR, cap = CAP })
  check(r == 2 and p == 1, "1 paire planifiée : 2 rangées (4 fours = 1,25/s pour 1,0/s), pas 12 (" .. r .. ")")
  r, p = Fonte.initial({ rows_max = 3, pairs_max = 7, drill_rate = DR, cap = CAP })
  check(r == 3 and p == 7, "plus de foreuses que de place : la ligne réservée entière (" .. r .. ")")
  r, p = Fonte.initial({ rows_max = 5, pairs_max = 0, drill_rate = DR, cap = CAP })
  check(r == 1 and p == 0, "sans foreuse : une rangée (jamais zéro)")
  for _, pm in ipairs({ 1, 2, 3, 5, 7 }) do
    local a1, b1, c1 = Fonte.initial({ rows_max = 12, pairs_max = pm, drill_rate = DR, cap = CAP, budget = 3 })
    local a2, b2, c2 = Fonte.initial({ rows_max = 12, pairs_max = pm, drill_rate = DR, cap = CAP, budget = 3 })
    check(a1 == a2 and b1 == b2 and c1 == c2, "déterministe (" .. pm .. " paires)")
  end
end

---------------------------------------------------------------------------------------------------
section("3. Pas de croissance (Fonte.step)")
---------------------------------------------------------------------------------------------------
local function st(over)
  local s = { input = 1.0, cap = CAP, rows = 1, rows_max = 6, drills = 2, drill_rate = DR, pairs = 1, pairs_max = 4, budget = 10,
    step_rows = 2, step_pairs = 1 }
  for k, v in pairs(over or {}) do s[k] = v end
  return Fonte.step(s)
end
do
  local d = st()
  check(d.action == "ajouter_fours" and d.rows == 1 and d.pairs == 0, "1 paire (1,0/s) pour 2 fours (0,625/s) : +1 rangée (" .. d.action .. " " .. d.rows .. ")")
  d = st({ input = 3.0, drills = 6, pairs = 3 })
  check(d.action == "ajouter_fours" and d.rows == 2, "3 paires pour 1 rangée : +2 rangées (pas borné à step_rows)")
  d = st({ input = 3.0, drills = 6, pairs = 3, step_rows = 5 })
  check(d.action == "ajouter_fours" and d.rows == 4, "pas à 5 : jusqu'aux 5 rangées voulues (10 fours)")
  d = st({ input = 9.0, drills = 18, pairs = 9, pairs_max = 9, rows = 5, step_rows = 5 })
  check(d.action == "ajouter_fours" and d.rows == 1, "entrée au-delà de la ligne : jusqu'à la place réservée seulement (+1)")
  d = st({ input = 9.0, drills = 18, pairs = 9, pairs_max = 9, rows = 6 })
  check(d.action == "plein" and d.rows == 0 and d.pairs == 0, "toutes les rangées posées : plein, rien d'ajouté, rien de retiré")
  d = st({ budget = 0 })
  check(d.action == "budget" and d.rows == 0 and d.want == 1, "stock nul : budget, rien d'ajouté (1 voulu)")
  d = st({ input = 3.0, drills = 6, pairs = 3, budget = 1 })
  check(d.action == "ajouter_fours" and d.rows == 1, "budget d'une unité : +1 rangée seulement")
  d = st({ input = 1.0, rows = 2 })
  check(d.action == "ajouter_foreuses" and d.pairs == 1 and d.rows == 0, "ligne juste, paires en réserve : +1 paire (la ligne va vers sa taille)")
  d = st({ input = 1.0, rows = 4 })
  check(d.action == "ajouter_foreuses" and d.pairs == 1 and d.rows == 0, "fours en attente de minerai : des foreuses, pas de fours")
  d = st({ input = 1.0, rows = 4, step_pairs = 3 })
  check(d.action == "ajouter_foreuses" and d.pairs == 2, "fours en attente : les paires qui les nourrissent (2), bornées par le pas")
  d = st({ input = 1.0, rows = 4, pairs = 4, pairs_max = 4 })
  check(d.action == "sans_minerai" and d.rows == 0 and d.pairs == 0, "fours en trop, plus aucune foreuse à poser : sans_minerai, AUCUN four")
  d = st({ input = 0, drills = 0, rows = 2, pairs = 1, pairs_max = 1 })
  check(d.action == "sans_minerai" and d.rows == 0, "gisement épuisé : aucun four")
  d = st({ input = 0, drills = 0, rows = 2, pairs = 1, pairs_max = 3 })
  check(d.action == "ajouter_foreuses" and d.pairs == 1, "foreuses épuisées, paires réservées sur le minerai : une paire")
  d = st({ input = 3.75, drills = 7.5, rows = 6, pairs = 4, pairs_max = 5 })
  check(d.action == "equilibre" and d.pairs == 0, "ligne réservée pleine à l'équilibre : pas de paire qui déborderait")
  d = st({ input = 1.25, drills = 2.5, rows = 2, pairs = 4, pairs_max = 4 })
  check(d.action == "equilibre", "ligne entière à l'équilibre : rien")
  check(st({ cap = 0 }).action == "invalide" and st({ rows = 0 }).action == "invalide" and st({ rows_max = 0 }).action == "invalide", "entrées invalides : invalide")
  -- jamais de four sans minerai : sur une grille de cas, ajouter_fours exige une entrée au-delà des fours posés
  local bad, n = 0, 0
  for rows = 1, 6 do
    for drills = 0, 10 do
      for left = 0, 3 do
        for budget = 0, 3 do
          local d2 = st({ input = drills * DR, drills = drills, rows = rows, pairs = math.ceil(drills / 2), pairs_max = math.ceil(drills / 2) + left, budget = budget })
          n = n + 1
          if d2.rows > 0 and drills * DR <= 2 * rows * CAP + 1e-9 then bad = bad + 1 end
          if d2.rows < 0 or d2.pairs < 0 then bad = bad + 1 end
          if d2.rows > 0 and d2.pairs > 0 then bad = bad + 1 end
          if rows + d2.rows > 6 or d2.pairs > left then bad = bad + 1 end
          if (d2.rows > 0 or d2.pairs > 0) and budget < 1 then bad = bad + 1 end
          if d2.rows > 2 or d2.pairs > 1 then bad = bad + 1 end
        end
      end
    end
  end
  check(bad == 0 and n == 1056, "grille de " .. n .. " cas : pas de four sans entrée, bornes (place, paires, budget, pas), une seule sorte d'ajout (" .. bad .. " écart(s))")
end

---------------------------------------------------------------------------------------------------
section("4. Croissance pure jusqu'au bout")
---------------------------------------------------------------------------------------------------
--- Joue la ligne : stock en unités par pas (`income`), foreuses posées toutes productives sauf `dead`. Rend l'historique.
local function grow(F, rows_max, pairs_max, income, start_budget, dead)
  local rows, pairs = F.initial({ rows_max = rows_max, pairs_max = pairs_max, drill_rate = DR, cap = CAP, budget = start_budget })
  local hist, budget = { { rows, pairs } }, 0
  for _ = 1, 60 do
    budget = budget + income
    local live = 2 * pairs - (dead or 0)
    local d = F.step({ input = math.max(0, live) * DR, cap = CAP, rows = rows, rows_max = rows_max, drills = math.max(0, live), drill_rate = DR,
      pairs = pairs, pairs_max = pairs_max, budget = budget, step_rows = T.ligne.step_rows, step_pairs = T.ligne.step_pairs })
    rows, pairs = rows + d.rows, pairs + d.pairs
    budget = budget - d.rows - d.pairs
    hist[#hist + 1] = { rows, pairs, d.action }
  end
  return hist
end
do
  local finals = {}
  for pm = 1, 7 do
    local rmax = math.floor(pm * DR / CAP + 1e-9) -- la place que line_rows réserve pour ce gisement (Ligne.rows_wanted)
    local h = grow(Fonte, rmax, pm, 1, 0)
    local mono, inside = true, true
    for i = 2, #h do
      if h[i][1] < h[i - 1][1] or h[i][2] < h[i - 1][2] then mono = false end
      if h[i][1] > rmax or h[i][2] > pm then inside = false end
    end
    local last = h[#h]
    check(mono and inside, pm .. " paire(s) au gisement : croissance monotone, dans la place réservée")
    check(h[1][1] == 1 and h[1][2] == 1, pm .. " paire(s), départ pauvre : 1 rangée, 1 paire")
    check(last[3] == "equilibre" or last[3] == "plein", pm .. " paire(s) : la ligne finit à l'équilibre ou pleine (" .. tostring(last[3]) .. ")")
    check(last[2] == pm and last[1] == rmax, pm .. " paire(s) : toute la ligne réservée finit posée (" .. last[1] .. "/" .. rmax .. " rangées, " .. last[2] .. "/" .. pm .. " paires)")
    finals[#finals + 1] = 2 * last[1]
  end
  local distinct = {}
  for _, v in ipairs(finals) do distinct[v] = true end
  local nd = 0
  for _ in pairs(distinct) do nd = nd + 1 end
  check(nd >= 6, "ni 2, ni 4, ni 8 : la taille finale suit les foreuses (" .. table.concat(finals, ", ") .. " fours)")
  -- minerai qui manque : 2 foreuses épuisées sur une ligne de 4 paires, plus aucune réserve -> aucune rangée de plus
  local h = grow(Fonte, 6, 2, 1, 0, 2)
  local last = h[#h]
  check(last[1] <= 2, "2 foreuses épuisées sur 2 paires : la ligne ne grandit pas au-delà de ce que le minerai nourrit (" .. last[1] .. " rangées)")
  check(last[3] == "sans_minerai" or last[3] == "equilibre", "minerai qui manque : sans_minerai ou équilibre (" .. tostring(last[3]) .. ")")
  -- déterminisme
  local a, b = grow(Fonte, 6, 4, 1, 0), grow(Fonte, 6, 4, 1, 0)
  local same = #a == #b
  for i = 1, #a do if a[i][1] ~= b[i][1] or a[i][2] ~= b[i][2] then same = false end end
  check(same, "déterministe")
end

---------------------------------------------------------------------------------------------------
section("5. Exécutant au moteur simulé réduit (script/team/build.lua)")
---------------------------------------------------------------------------------------------------
local Mk = require("tests.mock_engine")
Mk.new_game({})
local Build = require("script.team.build")
local Stock = require("script.team.stock")
T = require("shared.team.config") -- l'instance que build.lua lit (le moteur simulé recharge les modules)
local Board = require("script.team.board")
local real_game, real_log, real_count, real_status = game, log, Stock.count, defines.entity_status
local real_contents, real_view = Stock.contents, Board.view_stock
local LOGS = {}
log = function(s) LOGS[#LOGS + 1] = s end
if not defines.entity_status then
  defines.entity_status = { working = 1, low_power = 2, waiting_for_space_in_destination = 3, no_minable_resources = 4, no_power = 5 }
end
local ES = defines.entity_status
local STOCK = 0          -- plaques de fer au coffre (budget de la ligne)
local ITEMS = nil        -- autres objets au coffre (nil : de tout, en quantité)
local IRON = T.outposts.iron.product
Stock.count = function(_, it)
  if it == IRON then return STOCK end
  if ITEMS == nil then return 100000 end
  return ITEMS[it] or 0
end
Stock.contents = function()
  local out = { [IRON] = STOCK }
  for k, v in pairs(ITEMS or {}) do out[k] = v end
  return out
end
Board.view_stock = function(_, stock) -- registre des tâches vide : tout le coffre est libre
  if ITEMS == nil then return setmetatable({ [IRON] = STOCK }, { __index = function() return 100000 end }) end
  return stock
end

--- Un projet de ligne comme plan_project le laisse avant Build.ligne_split : fonderie (partie 1) et foreuses (partie 2) aux
--- gabarits réels, pièces marquées par Build.tag_rows.
local function make_project(n, pm, furnace)
  local g = M.GEN.smelter(furnace or STONE, ORE, n)
  local gd = M.GEN.drills(ORE, pm)
  local function ents_of(gg, ox, oy, part)
    local inst = M.instantiate(gg, 0, ox, oy)
    local out = {}
    for _, e in ipairs(inst.entities) do out[#out + 1] = { name = e.name, x = e.position.x, y = e.position.y, dir = e.direction or 0, part = part, item = e.name } end -- item : posé par plan_project (item_of)
    return out
  end
  local e1, e2 = ents_of(g, 0, 0, 1), ents_of(gd, 40, 0, 2)
  Build.tag_rows(e1, g, 0, "four", "row")
  Build.tag_rows(e2, gd, 1, "drill", "pair")
  local ents = {}
  for _, e in ipairs(e1) do ents[#ents + 1] = e end
  for _, e in ipairs(e2) do ents[#ents + 1] = e end
  local p = { id = 7, state = "plan", spec = { gen = "smelter", feed = "tapis" }, ents = ents, stock = {}, obstacles = {}, missing = {},
    parts = { { kind = "module", ox = 0, oy = 0, w = g.w, h = g.h },
      { kind = "foreuses", ox = 40, oy = 0, w = gd.w, h = gd.h, ore = ORE, pairs = pm, drills = 2 * pm, drill = gd.params.drill,
        drill_rate = M.spec(gd.params.drill).speed } } }
  return p, g, gd
end

-- moteur simulé : les pièces BÂTIES du projet sont au monde ; statut et vitesse réglables par pièce
local WORLD
local function world_of(p, opts)
  opts = opts or {}
  local list = {}
  for _, e in ipairs(p.ents) do
    if e.built then
      local k = kind(e)
      if k == "drill" or k == "furnace" then
        local key = string.format("%g,%g", e.x, e.y)
        local st = (opts.status and opts.status[key]) or ES.working
        local proto = k == "drill" and { mining_speed = opts.mining_speed or 0.5 } or { crafting_speed = opts.crafting_speed or 1 }
        if not (opts.missing and opts.missing[key]) then
          list[#list + 1] = { position = { x = e.x, y = e.y }, type = k == "drill" and "mining-drill" or "furnace", status = st, prototype = proto, key = key }
        end
      end
    end
  end
  return list
end
local SURF = { find_entities_filtered = function(q)
  local out = {}
  local a = q.area
  for _, e in ipairs(WORLD) do
    -- intervalles FERMÉS comme le moteur (F96) : le script doit refiltrer
    if e.type == q.type and e.position.x >= a[1][1] and e.position.x <= a[2][1] and e.position.y >= a[1][2] and e.position.y <= a[2][2] then out[#out + 1] = e end
  end
  return out
end }
local FAKE_GAME = { forces = { fx = { mining_drill_productivity_bonus = 0 } },
  entity_prototypes = { ["electric-mining-drill"] = { mining_speed = 0.5 }, [STONE] = { crafting_speed = 1 }, [STEEL] = { crafting_speed = 2 } } }

local function team(p) return { key = "fx", force = "fx", build = { order = { p.id }, projects = { [p.id] = p } } } end
--- Chantier simulé : un projet rouvert est bâti en entier et refini (la réserve, les fantômes et les PNJ sont testés ailleurs).
local function build_all(p, tick)
  if p.state ~= "fini" then
    for _, e in ipairs(p.ents) do e.built = true end
    p.state, p.finished, p.reason = "fini", tick, nil
  end
end
local function count(p, pred) local n = 0 for _, e in ipairs(p.ents) do if pred(e) then n = n + 1 end end return n end
local function furnaces(p) return count(p, function(e) return kind(e) == "furnace" end) end
local function drills(p) return count(p, function(e) return kind(e) == "drill" end) end

--- Joue `steps` relevés espacés de T.ligne.every ; `income` plaques gagnées par relevé ; `world` : options du moteur simulé.
local TICK = 0 -- horloge de la partie simulée (Build.ligne_step garde son prochain relevé dans f.build)
local function play(f, p, steps, income, world)
  local tick = TICK
  local hist = {}
  for _ = 1, steps do
    build_all(p, tick)
    tick = tick + T.ligne.every + T.ligne.settle
    STOCK = STOCK + (income or 0)
    WORLD = world_of(p, world)
    game = FAKE_GAME
    Build.ligne_step(f, SURF, tick)
    game = real_game
    hist[#hist + 1] = { p.ligne.rows, p.ligne.pairs, p.ligne.last, p.state }
  end
  TICK = tick
  return hist
end

do -- Build.ligne_split : pauvre (stock nul)
  LOGS = {}
  STOCK = 0
  local p, g = make_project(6, 4)
  local total = #p.ents
  local f = team(p)
  game = FAKE_GAME
  Build.ligne_split(f, p, g)
  game = real_game
  local ln = p.ligne
  check(ln and ln.rows == 1 and ln.pairs == 1 and ln.rows_max == 6 and ln.pairs_max == 4, "plan pauvre : 1/6 rangée, 1/4 paire")
  check(furnaces(p) == 2 and drills(p) == 2, "plan pauvre : 2 fours et 2 foreuses à poser (" .. furnaces(p) .. ", " .. drills(p) .. ")")
  check(#p.ents + #ln.held == total, "aucune pièce perdue : posées + en attente = la ligne entière")
  local skel = count(p, function(e) local k = kind(e) return k == "belt" or k == "pole" end)
  local skel_all = 0
  local g2 = M.GEN.smelter(STONE, ORE, 6)
  local gd2 = M.GEN.drills(ORE, 4)
  for _, e in ipairs(g2.entities) do local k = kind(e) if k == "belt" or k == "pole" then skel_all = skel_all + 1 end end
  for _, e in ipairs(gd2.entities) do local k = kind(e) if k == "belt" or k == "pole" then skel_all = skel_all + 1 end end
  check(skel == skel_all, "squelette (tapis, poteaux) de la ligne ENTIÈRE posé dès le départ : la place est prise (" .. skel .. "/" .. skel_all .. ")")
  local held_ok = true
  for _, e in ipairs(ln.held) do
    if not ((e.part == 1 and e.row and e.row > 1) or (e.part == 2 and e.pair and e.pair > 1)) then held_ok = false end
  end
  check(held_ok, "en attente : seulement des pièces des rangées 2..6 et des paires 2..4")
  check(#LOGS == 1 and LOGS[1]:find("[FO-FONTE] fx : projet 7, ligne dynamique iron-ore : 1/6 rangee(s) posee(s)", 1, true) ~= nil, "journal du plan : " .. tostring(LOGS[1]))

  -- croissance avec le stock (80 plaques par relevé = 0,5 unité ; 160 = 1 unité)
  LOGS = {}
  local h = play(f, p, 30, 160)
  if os.getenv("FO_VERBOSE") then for _, l in ipairs(LOGS) do print("    " .. l) end end
  local last = h[#h]
  check(last[1] == 6 and last[2] == 4, "enrichie : la ligne finit entière, 6 rangées et 4 paires (" .. last[1] .. ", " .. last[2] .. ")")
  check(furnaces(p) == 12 and drills(p) == 8 and #p.ligne.held == 0, "enrichie : 12 fours et 8 foreuses posés, rien en attente")
  local mono = true
  for i = 2, #h do if h[i][1] < h[i - 1][1] or h[i][2] < h[i - 1][2] then mono = false end end
  check(mono, "croissance monotone (jamais de retrait)")
  local reopened, actions = 0, {}
  for _, l in ipairs(LOGS) do
    if l:find("action ajouter_fours", 1, true) then actions.f = (actions.f or 0) + 1 end
    if l:find("action ajouter_foreuses", 1, true) then actions.d = (actions.d or 0) + 1 end
  end
  check((actions.f or 0) >= 2 and (actions.d or 0) >= 2, "journal : fours et foreuses ajoutés par étapes (" .. tostring(actions.f) .. ", " .. tostring(actions.d) .. ")")
  check(p.reopened and p.reopened >= 4 and p.counted == true and p.reopened_tick == nil, "projet rouvert à chaque pas, compté une fois, sans gel des améliorations")
  local first = LOGS[1] or ""
  check(first:find("action ajouter_fours (+1 rangee(s), +0 paire(s), 6 piece(s) a poser) -> 2/6 rangee(s), 1/4 paire(s)", 1, true) ~= nil,
    "premier pas : 1 paire (1,0/s) pour 2 fours -> +1 rangée, 6 pièces (2 fours, 4 bras) : " .. first)
end

do -- riche : tout d'un coup, puis plein, rien de plus
  LOGS = {}
  STOCK = 100000
  local p, g = make_project(6, 4)
  local f = team(p)
  game = FAKE_GAME
  Build.ligne_split(f, p, g)
  game = real_game
  check(p.ligne.rows == 6 and p.ligne.pairs == 4 and #p.ligne.held == 0, "plan riche : la ligne entière d'un coup (comme avant le lot)")
  local h = play(f, p, 3, 0)
  check(h[#h][1] == 6 and h[#h][3] == "plein", "riche : 4 paires (4,0/s) pour 12 fours (3,75/s) : plein, rien d'ajouté (" .. tostring(h[#h][3]) .. ")")
  check(#LOGS == 2, "un changement d'état journalisé une fois (plan + plein), pas à chaque relevé (" .. #LOGS .. ")")
end

do -- minerai épuisé, pièces manquantes, foreuses à l'arrêt, foreuses améliorées
  STOCK = 0
  local p, g = make_project(6, 4)
  local f = team(p)
  game = FAKE_GAME
  Build.ligne_split(f, p, g)
  game = real_game
  play(f, p, 1, 0) -- pose de départ (1 rangée, 1 paire)
  STOCK = 100000
  -- les 2 foreuses posées sont épuisées
  local st = {}
  for _, e in ipairs(p.ents) do if kind(e) == "drill" then st[string.format("%g,%g", e.x, e.y)] = ES.no_minable_resources end end
  LOGS = {}
  local h = play(f, p, 1, 0, { status = st })
  check(h[1][1] == 1 and h[1][2] == 2 and h[1][3] == "ajouter_foreuses", "foreuses épuisées : une paire réservée, AUCUN four (" .. h[1][1] .. ", " .. h[1][2] .. ", " .. tostring(h[1][3]) .. ")")
  check((LOGS[1] or ""):find("2 epuisee(s)", 1, true) ~= nil, "journal : les foreuses épuisées sont dites")
  -- une foreuse à l'arrêt (sans courant) : rien n'est décidé
  local st2 = {}
  for _, e in ipairs(p.ents) do if kind(e) == "drill" then st2[string.format("%g,%g", e.x, e.y)] = ES.no_power break end end
  LOGS = {}
  local before = #p.ents
  h = play(f, p, 1, 0, { status = st2 })
  check(h[1][3] == "attente" and #p.ents == before and p.state == "fini", "foreuse sans courant : attente, rien d'ajouté")
  check((LOGS[1] or ""):find("a l'arret", 1, true) ~= nil, "journal : l'attente dit sa cause")
  -- un four détruit (pas encore refait) : rien n'est décidé (le relevé de reconstruction le refait)
  local miss = {}
  for _, e in ipairs(p.ents) do if kind(e) == "furnace" then miss[string.format("%g,%g", e.x, e.y)] = true break end end
  LOGS = {}
  h = play(f, p, 1, 0, { missing = miss })
  check(h[1][3] == "attente" and #p.ents == before, "four manquant : attente, rien d'ajouté")
  check((LOGS[1] or ""):find("pieces manquantes", 1, true) ~= nil, "journal : pièces manquantes")
  -- foreuses améliorées (niveau : vitesse doublée) : l'entrée double, des fours s'ajoutent
  LOGS = {}
  h = play(f, p, 1, 0, { mining_speed = 1.0 })
  check(h[1][3] == "ajouter_fours" and h[1][1] == 3, "foreuses améliorées (4 x 1,0/s) : +2 rangées (" .. tostring(h[1][3]) .. ", " .. h[1][1] .. ")")
end

do -- ancien projet (sauvegarde 0.6.18, sans p.ligne) : jamais relu, jamais modifié
  LOGS = {}
  local p = make_project(4, 3)
  for _, e in ipairs(p.ents) do e.built = true end
  p.state, p.finished = "fini", 0
  local n0 = #p.ents
  local f = team(p)
  WORLD = world_of(p)
  game = FAKE_GAME
  TICK = TICK + 100000
  Build.ligne_step(f, SURF, TICK)
  game = real_game
  check(p.ligne == nil and #p.ents == n0 and p.state == "fini" and p.reopened == nil and #LOGS == 0, "ancien projet : intact, aucun journal")
  -- réglage éteint : rien
  local p2, g2 = make_project(6, 4)
  local f2 = team(p2)
  T.ligne.dyn = false
  STOCK = 0
  game = FAKE_GAME
  Build.ligne_split(f2, p2, g2)
  TICK = TICK + 100000
  Build.ligne_step(f2, SURF, TICK)
  game = real_game
  T.ligne.dyn = true
  check(p2.ligne == nil, "T.ligne.dyn éteint : la ligne entière posée d'un coup, aucun relevé")
  -- ligne fixe (MIGRATION-CHAMP) : pas de pose par étapes
  local p3, g3 = make_project(6, 4)
  p3.spec.fixe = true
  game = FAKE_GAME
  Build.ligne_split(team(p3), p3, g3)
  game = real_game
  check(p3.ligne == nil, "ligne fixe (partie de champ) : taille de la partie, pas de pose par étapes")
end

do -- déterminisme de l'exécutant
  local function run()
    LOGS = {}
    STOCK = 0
    TICK = 0
    local p, g = make_project(6, 4)
    local f = team(p)
    game = FAKE_GAME
    Build.ligne_split(f, p, g)
    game = real_game
    play(f, p, 20, 120)
    local out = {}
    for _, l in ipairs(LOGS) do out[#out + 1] = l end
    return table.concat(out, "\n")
  end
  check(run() == run(), "deux parties identiques : mêmes décisions, même journal")
end

do -- ressources d'abord : un pas sans ses matériaux au coffre n'est pas lancé (la partie bâtie continue de produire)
  STOCK = 0
  local p, g = make_project(6, 4)
  local f = team(p)
  game = FAKE_GAME
  Build.ligne_split(f, p, g)
  game = real_game
  play(f, p, 1, 0)
  ITEMS = { ["inserter"] = 10 } -- des bras, aucun four
  STOCK = 1000
  LOGS = {}
  local n0 = #p.ents
  local h = play(f, p, 1, 0)
  check(h[1][3] == "materiaux" and #p.ents == n0 and p.state == "fini" and p.ligne.rows == 1, "fours absents du coffre : rien n'est rouvert (" .. tostring(h[1][3]) .. ")")
  check((LOGS[1] or ""):find("manque au coffre {stone-furnace x2} (ajouter_fours remis, demande au cerveau)", 1, true) ~= nil, "journal : ce qui manque est dit : " .. tostring(LOGS[1]))
  -- relecture : le manque est DEMANDÉ au cerveau (Build.brief.grow -> automatisation, but « alim ») ; sinon personne ne fabriquait les fours
  local br = Build.brief(f, p.id)
  check(br and br.grow and #br.grow == 1 and br.grow[1][1] == "stone-furnace" and br.grow[1][2] == 2,
    "Build.brief.grow : les 2 fours du pas à fabriquer (" .. tostring(br and br.grow and #br.grow) .. ")")
  ITEMS = { ["inserter"] = 10, ["stone-furnace"] = 2 }
  h = play(f, p, 1, 0)
  check(h[1][3] == "ajouter_fours" and p.ligne.rows == 2, "fours arrivés au coffre : la rangée est lancée")
  check(p.ligne.missing == nil and Build.brief(f, p.id).grow == nil, "pas lancé : plus rien demandé au cerveau")
  ITEMS = nil
end

do -- relecture : une pièce abandonnée (refus répétés, e.dropped) n'est plus attendue ; la ligne n'est pas figée en « pieces »
  STOCK = 0
  local p, g = make_project(6, 4)
  local f = team(p)
  game = FAKE_GAME
  Build.ligne_split(f, p, g)
  game = real_game
  play(f, p, 1, 0)
  local gone
  for _, e in ipairs(p.ents) do if kind(e) == "furnace" then e.dropped = true; gone = string.format("%g,%g", e.x, e.y) break end end
  STOCK = 1000
  LOGS = {}
  local h = play(f, p, 1, 0, { missing = { [gone] = true } })
  check(h[1][3] ~= "attente" and not (LOGS[1] or ""):find("pieces manquantes", 1, true), "four abandonné : la ligne est relue (" .. tostring(h[1][3]) .. ")")
  -- un four NON abandonné absent du monde : toujours « pieces » (le relevé de reconstruction le refait)
  local gone2
  for _, e in ipairs(p.ents) do if kind(e) == "furnace" and not e.dropped then gone2 = string.format("%g,%g", e.x, e.y) break end end
  LOGS = {}
  h = play(f, p, 1, 0, { missing = { [gone] = true, [gone2] = true } })
  check((LOGS[1] or ""):find("pieces manquantes", 1, true) ~= nil or h[1][3] == "attente", "four détruit non abandonné : attente")
end

game, log, Stock.count, defines.entity_status = real_game, real_log, real_count, real_status
Stock.contents, Board.view_stock = real_contents, real_view

---------------------------------------------------------------------------------------------------
section("6. Câblage et mutants")
---------------------------------------------------------------------------------------------------
do
  local src = read("script/team/build.lua")
  check(src:find('Build.tag_rows(ents, pg, 1, "drill", "pair")', 1, true) ~= nil, "plan_drills marque les paires de foreuses")
  check(src:find('if topts then Build.tag_rows(ents, g, 0, "four", "row") end', 1, true) ~= nil, "plan_project marque les rangées de fours")
  check(src:find("if topts then Build.ligne_split(f, p, g) end", 1, true) ~= nil, "plan_project pose par étapes")
  check(src:find("Build.ligne_step(f, surface, tick) -- lot FONDERIE-DYNAMIQUE", 1, true) ~= nil, "Build.think relève les lignes")
  check(src:find("cfg.rows_floor", 1, true) == nil, "plus de plancher de rangées dans build.lua")
  local auto_src = read("script/ai3/automatisation.lua")
  check(auto_src:find("for _, g in ipairs(s and s.grow or {}) do", 1, true) ~= nil, "automatisation : les pièces du pas suivant (Build.brief.grow) deviennent un but « alim »")
  check(src:find("if ligne_takes(ln, e, nr, np) and e.item then piece_needs(need, e) end", 1, true) ~= nil
    and src:find("if M.BURNER_ARM and e.name == M.BURNER_ARM then bump(need, T.outposts.coal.product, 2) end", 1, true) ~= nil,
    "ligne_missing compte comme needs_of (charbon d'amorce des bras à combustible)")
  check(src:find("if spec.shrunk then return cur end", 1, true) ~= nil, "garde CAPI-REPLI (spec.shrunk) intacte")
  local a = src:find("-- Lot FONDERIE-DYNAMIQUE : la ligne de fours suit", 1, true)
  local b = src:find("--- Foreuses de ravitaillement d'une voie", 1, true)
  local blk = (a and b) and src:sub(a, b) or ""
  check(#blk > 0 and not blk:find("[^i]pairs%(") and not blk:find("global[%.%[]") and not blk:find("require%("), "bloc de l'exécutant : aucun pairs, aucun global, aucun require")
  check(not blk:find("reopened_tick", 1, true) or blk:find("reopened_tick n'est PAS", 1, true), "un agrandissement n'écrit pas reopened_tick (pas de gel des améliorations)")
  check(T.ligne.rows_floor == nil and T.ligne.dyn == true and T.ligne.every > 0 and T.ligne.step_rows >= 1 and T.ligne.step_pairs >= 1, "réglages T.ligne de la ligne dynamique")
end
do
  local function suite(F)
    local bad = 0
    local function ck(c) if not c then bad = bad + 1 end end
    local r, p = F.initial({ rows_max = 6, pairs_max = 4, drill_rate = DR, cap = CAP, budget = 0 })
    ck(r == 1 and p == 1)
    r, p = F.initial({ rows_max = 6, pairs_max = 4, drill_rate = DR, cap = CAP })
    ck(r == 6 and p == 4)
    r = F.initial({ rows_max = 12, pairs_max = 1, drill_rate = DR, cap = CAP })
    ck(r == 2)
    local function s(over)
      local t = { input = 1.0, cap = CAP, rows = 1, rows_max = 6, drills = 2, drill_rate = DR, pairs = 1, pairs_max = 4, budget = 10, step_rows = 2, step_pairs = 1 }
      for k, v in pairs(over) do t[k] = v end
      return F.step(t)
    end
    local d = s({})
    ck(d.action == "ajouter_fours" and d.rows == 1)
    d = s({ input = 3.0, drills = 6, pairs = 3 })
    ck(d.rows == 2)
    d = s({ input = 9.0, drills = 18, pairs = 9, pairs_max = 9, rows = 5, step_rows = 5 })
    ck(d.rows == 1)
    d = s({ budget = 0 })
    ck(d.action == "budget" and d.rows == 0)
    d = s({ input = 1.0, rows = 4, pairs = 4, pairs_max = 4 })
    ck(d.action == "sans_minerai" and d.rows == 0 and d.pairs == 0)
    d = s({ input = 1.0, rows = 4 })
    ck(d.action == "ajouter_foreuses" and d.pairs == 1 and d.rows == 0)
    d = s({ input = 3.75, drills = 7.5, rows = 6, pairs = 4, pairs_max = 5 })
    ck(d.action == "equilibre" and d.pairs == 0)
    d = s({ input = 1.0, rows = 4, budget = 0 })
    ck(d.action == "budget" and d.pairs == 0)
    return bad
  end
  check(suite(Fonte) == 0, "la suite des mutants passe sur la règle réelle")
  local mutants = {
    { "plancher de 4 rangées remis", "local rows = math.max(1, math.min(fed, rmax))", "local rows = math.max(4, math.min(fed, rmax))" },
    { "budget ignoré au départ", "local units = s.budget and clamp_int(s.budget, 1) or math.huge", "local units = math.huge" },
    { "fours sans minerai (toujours une rangée)", "if dec.action == \"ajouter_fours\" or dec.action == \"retirer_foreuses\" then", "if true then" },
    { "pas non borné", "    add = math.min(add, step_r)\n", "" },
    { "budget ignoré pour les foreuses", "  if budget < 1 then out.action = \"budget\" return out end\n  out.action, out.pairs", "  out.action, out.pairs" },
    { "budget ignoré au pas", "    if budget < 1 then out.action = \"budget\" return out end\n    out.action, out.rows", "    out.action, out.rows" },
    { "paire qui déborde", "  if dec.action == \"equilibre\" and drills * dr >= 2 * rmax * cap - EPS then out.action = \"equilibre\" return out end\n", "" },
    { "foreuses sans réserve", "  if left <= 0 then\n", "  if left < 0 then\n" },
  }
  local killed = 0
  for _, m in ipairs(mutants) do
    local i = FONTE_SRC:find(m[2], 1, true)
    if not i then
      check(false, "mutant « " .. m[1] .. " » : texte introuvable dans fonte.lua")
    else
      local src = FONTE_SRC:sub(1, i - 1) .. m[3] .. FONTE_SRC:sub(i + #m[2])
      local ok, F = pcall(load_fonte, src)
      local bad = ok and suite(F) or 1
      if bad > 0 then killed = killed + 1 else print("  mutant survivant : " .. m[1]) end
    end
  end
  check(killed == #mutants, "mutants refusés : " .. killed .. " sur " .. #mutants)
  print(string.format("[FONDERIE-DYN] mutants : %d refusés sur %d", killed, #mutants))
end

print(string.format("[FONDERIE-DYN] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
