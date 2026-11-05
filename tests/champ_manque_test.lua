--[[
  Lot CORR-CHAMP-MANQUE (EFFONDREMENT, accord du lead du 5/11) : le champ du minerai dont la plaque MANQUE aux ordres ouverts a le
  siège +1 des emplacements (règle 8 de shared/ai3/emplacements.lua), sur le prédicat PARTAGÉ avec AGEBLOCAGE (Ca.blocked_items,
  Ca.unblocks de shared/ai3/capitalisation.lua). Banc HORS JEU, règles pures.
  Cas mesuré (fo-logs/2026-11-05_EFFONDREMENT/RAPPORT.md §2 bis, partie du DC 717152950 en 0.6.51) : 2 modules (packs rouges, patron
  de foreuses à combustion) attendaient du fer et tenaient les 2 emplacements de 11 à 31 min ; la foreuse électrique de fer était
  refusée « plan directeur occupe » ; rien ne dormait (le siège de DEPENSES2 (c) restait fermé).
  Lancement : lua5.2 tests/champ_manque_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Em = require("shared.ai3.emplacements")
local Ca = require("shared.ai3.capitalisation")
local Book = require("shared.team.book")
local RECIPES = dofile("tests/fixtures/recipes.lua") -- (vraies recettes du jeu, harness --dump-recipes)
local BOOK = Book.new(RECIPES)

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
end
local function section(name) if not quiet then print("== " .. name) end end

-- Recettes du jeu (forme de Ca.data : D.producers[objet] = { recettes }, D.recipes[r].ingredients = { { name, amount, fluid } }).
local D = {
  producers = {
    ["iron-plate"] = { "iron-plate" }, ["copper-plate"] = { "copper-plate" },
    ["iron-gear-wheel"] = { "iron-gear-wheel" }, ["assembling-machine-1"] = { "assembling-machine-1" },
    ["burner-mining-drill"] = { "burner-mining-drill" }, ["sulfur"] = { "sulfur" },
    ["electronic-circuit"] = { "electronic-circuit" },
  },
  recipes = {
    ["iron-plate"] = { ingredients = { { name = "iron-ore", amount = 1 } } },
    ["copper-plate"] = { ingredients = { { name = "copper-ore", amount = 1 } } },
    ["iron-gear-wheel"] = { ingredients = { { name = "iron-plate", amount = 2 } } },
    ["assembling-machine-1"] = { ingredients = { { name = "electronic-circuit", amount = 3 }, { name = "iron-gear-wheel", amount = 5 },
      { name = "iron-plate", amount = 9 } } },
    ["burner-mining-drill"] = { ingredients = { { name = "iron-gear-wheel", amount = 3 }, { name = "stone-furnace", amount = 1 },
      { name = "iron-plate", amount = 3 } } },
    ["sulfur"] = { ingredients = { { name = "water", amount = 30, fluid = true }, { name = "petroleum-gas", amount = 30, fluid = true } } },
    ["electronic-circuit"] = { ingredients = { { name = "iron-plate", amount = 1 }, { name = "copper-cable", amount = 3 } } },
  },
}
local NAMES = { "iron-plate", "copper-plate" }
local ORES = { ["iron-plate"] = "iron-ore", ["copper-plate"] = "copper-ore" }
local T = 11 * 3600
-- Les deux modules du cas B, en réserve (matière attendue) depuis 7,8 min.
local function waiting_mods()
  return { { key = "packs:automation-science-pack", states = { "reserve" }, opened = 28080 },
           { key = "chaine:burner-mining-drill", states = { "reserve" }, opened = 28080 } }
end

local function set_eq(a, b)
  for k in pairs(a or {}) do if not (b or {})[k] then return false end end
  for k in pairs(b or {}) do if not (a or {})[k] then return false end end
  return true
end

local function suite()
  section("prédicat partagé : matières qui manquent aux ordres ouverts (Ca.blocked_items)")
  local b = Ca.blocked_items({ D = D, open = { { missing = { { "assembling-machine-1", 2 } } }, { missing = { { "sulfur", 4 } } } } })
  check(set_eq(b, { ["assembling-machine-1"] = true, ["electronic-circuit"] = true, ["iron-gear-wheel"] = true, ["iron-plate"] = true,
    sulfur = true }), "manque + ses ingrédients DIRECTS, sans fluide")
  check(not b["iron-ore"], "pas les ingrédients des ingrédients (iron-ore n'est pas direct ici)")
  check(next(Ca.blocked_items({ D = D, open = { { missing = { { "iron-plate", 0 } } } } })) == nil, "un manque de 0 ne compte pas")
  check(next(Ca.blocked_items({ D = D, open = {} })) == nil and next(Ca.blocked_items({ D = D })) == nil, "aucun ordre ouvert : rien")
  check(Ca.blocked_items({ D = D, open = { { missing = { { "iron-plate", 5 } } } } })["iron-ore"] == true, "plaque qui manque : son minerai aussi")
  check(Ca.blocked_items({ open = { { missing = { { "x", 1 } } } } }).x == true, "sans recettes : le manque seul")

  section("prédicat partagé : une option débloque-t-elle un manque (Ca.unblocks)")
  local bl = { ["iron-plate"] = true, ["iron-ore"] = true }
  check(Ca.unblocks({ kind = "chaine", item = "iron-plate" }, bl) == true, "par l'objet qu'elle fait")
  check(Ca.unblocks({ kind = "couvrir", resource = "iron-ore" }, bl) == true, "par la ressource qu'elle extrait")
  check(Ca.unblocks({ kind = "module", product = "iron-plate" }, bl) == true, "par son produit")
  check(Ca.unblocks({ kind = "couvrir", resource = "copper-ore", product = "copper-plate" }, bl) == false, "une autre matière : non")
  check(Ca.unblocks(nil, bl) == false and Ca.unblocks({ item = "iron-plate" }, nil) == false, "rien : non")

  section("produits qui manquent (Em.short)")
  check(set_eq(Em.short(NAMES, ORES, { ["iron-plate"] = true }, { ["iron-plate"] = 66, ["copper-plate"] = 354 }), { ["iron-plate"] = true }),
    "plaque de fer dans le manque, stock 66 : manque")
  check(set_eq(Em.short(NAMES, ORES, { ["iron-ore"] = true }, { ["iron-plate"] = 66 }), { ["iron-plate"] = true }), "par son minerai aussi")
  check(next(Em.short(NAMES, ORES, { ["iron-plate"] = true }, { ["iron-plate"] = Em.PER_SLOT })) == nil,
    "stock riche (" .. Em.PER_SLOT .. ") : le module attend autre chose, pas de siège")
  check(Em.short(NAMES, ORES, { ["iron-plate"] = true }, { ["iron-plate"] = Em.PER_SLOT - 1 })["iron-plate"] == true, "juste sous le seuil : manque")
  check(next(Em.short(NAMES, ORES, {}, {})) == nil and next(Em.short(NAMES, ORES, nil, nil)) == nil, "rien de bloqué : rien")

  section("siège du complément : la règle 7 de DEPENSES2 inchangée, la règle 8 en plus (Em.complement)")
  check(Em.complement(NAMES, {}) == nil and Em.complement(NAMES, {}, nil) == nil, "rien ne dort, rien ne manque : pas de siège")
  check(set_eq(Em.complement(NAMES, { ["copper-plate"] = true }), { ["iron-plate"] = true }), "le cuivre dort : le fer (règle 7)")
  check(Em.complement(NAMES, { ["iron-plate"] = true, ["copper-plate"] = true }) == nil, "tout dort : pas de siège (règle 7)")
  check(set_eq(Em.complement(NAMES, {}, { ["iron-plate"] = true }), { ["iron-plate"] = true }), "rien ne dort, le fer manque : le fer (règle 8)")
  check(set_eq(Em.complement(NAMES, { ["copper-plate"] = true }, { ["iron-plate"] = true }), { ["iron-plate"] = true }), "les deux règles : le fer")
  check(Em.complement(NAMES, { ["iron-plate"] = true, ["copper-plate"] = true }, { ["iron-plate"] = true }) == nil,
    "jamais un produit qui dort")

  section("cas B de la partie du DC (0.6.51, minute 11) : la foreuse de fer reçoit le siège")
  local s0 = { base = 2, plates = { 66, 354 }, mods = waiting_mods(), tick = T, names = NAMES, sleeping = {} }
  local old = Em.slots(s0)
  check(old.busy and Em.drill_refused(old, "iron-plate") == true, "sans la règle 8 (DEPENSES2 (c) seule) : refusée « plan directeur occupe »")
  local s1 = {} for k, v in pairs(s0) do s1[k] = v end
  s1.short = Em.short(NAMES, ORES, Ca.blocked_items({ D = D, open = { { missing = { { "burner-mining-drill", 4 } } },
    { missing = { { "assembling-machine-1", 1 } } } } }), { ["iron-plate"] = 66, ["copper-plate"] = 354 })
  local sl = Em.slots(s1)
  check(sl.busy == true and sl.room == 0 and sl.room_comp == 1, "emplacements ordinaires pleins ; un siège de plus")
  check(Em.drill_refused(sl, "iron-plate") == false, "foreuse de fer : accordée")
  check(Em.drill_refused(sl, "copper-plate") == true, "foreuse de cuivre : refusée (le cuivre ne manque pas)")
  check(Em.order_seat(sl.room, sl.room_comp, sl.comp, "iron-plate") == "complement", "ordre « couvrir » du fer : siège du complément")
  check(Em.order_seat(sl.room, sl.room_comp, sl.comp, "copper-plate") == nil, "ordre du cuivre : refusé")
  check(Em.order_seat(sl.room, sl.room_comp, sl.comp, nil) == nil, "un module ordinaire (sans produit) : refusé")
  local r2, rc2 = Em.take(sl.room, sl.room_comp, 1)
  check(Em.order_seat(r2, rc2, sl.comp, "iron-plate") == nil, "un seul siège par décision")
  check(sl.why:find("matiere qui manque aux ordres ouverts (iron-plate)", 1, true) ~= nil, "le journal dit pourquoi : " .. sl.why)
  -- Décision suivante : un MODULE ouvert par le siège est compté dans mods ; plus de siège.
  local mods3 = waiting_mods()
  mods3[#mods3 + 1] = { key = "chaine:fonderie-fer", states = { "reserve" }, opened = T }
  local s3 = {} for k, v in pairs(s1) do s3[k] = v end
  s3.mods = mods3
  local sl3 = Em.slots(s3)
  check(sl3.room_comp == 0 and Em.drill_refused(sl3, "iron-plate") == true, "un module ouvert sur le siège compte : pas de second")

  section("relecture du lead (18 h 10, point 1) : le CHAMP n'est pas un module, il tient quand même le siège (held_comp, Em.champ_seat)")
  local s6 = {} for k, v in pairs(s1) do s6[k] = v end
  s6.held_comp = 1 -- le champ du fer ouvert à la décision précédente : il n'est PAS dans mods
  local sl6 = Em.slots(s6)
  check(sl6.room_comp == 0 and sl6.held_comp == 1 and Em.drill_refused(sl6, "iron-plate") == true,
    "le champ ouvert sur le siège le tient : pas de second champ à la décision suivante")
  check(sl6.counted == sl.counted and sl6.room == sl.room, "il ne prend aucun emplacement ordinaire (lot CHAMP)")
  check(sl6.why:find("siege tenu par 1 champ(s)", 1, true) ~= nil, "le journal le dit : " .. sl6.why)
  local s7 = {} for k, v in pairs(s0) do s7[k] = v end
  s7.held_comp = 1
  local sl7 = Em.slots(s7)
  check(sl7.comp == nil and sl7.room == old.room and sl7.counted == old.counted and sl7.why == old.why,
    "plus rien ne manque : un champ tenu ne change rien aux emplacements ordinaires")
  check(Em.champ_seat(false, 0, 0, sl.comp, "copper-plate") == "hors" and Em.champ_seat(false, 3, 0, nil, nil) == "hors",
    "emplacements libres au début de la décision : le champ ne prend rien, comme avant")
  check(Em.champ_seat(true, sl.room, sl.room_comp, sl.comp, "iron-plate") == "complement", "pleins : le champ du fer prend le siège")
  check(Em.champ_seat(true, sl.room, sl.room_comp, sl.comp, "copper-plate") == nil, "pleins : le champ du cuivre est refusé")
  local r6, rc6 = Em.take(sl.room, sl.room_comp, 1)
  check(Em.champ_seat(true, r6, rc6, sl.comp, "iron-plate") == nil, "un second champ du fer dans la même décision : refusé")
  check(Em.champ_seat(true, sl6.room, sl6.room_comp, sl6.comp, "iron-plate") == nil, "décision suivante, siège tenu : refusé")
  -- Le fer redevient riche : plus de siège.
  local s4 = {} for k, v in pairs(s1) do s4[k] = v end
  s4.short = Em.short(NAMES, ORES, { ["iron-plate"] = true }, { ["iron-plate"] = 1500 })
  check(Em.drill_refused(Em.slots(s4), "iron-plate") == true, "fer riche : refusée comme avant")

  section("relecture du lead (18 h 10, point 2) : le siège va à LA plaque qui manque le plus (Ca.seat_plate : coût brut, stock libre déduit)")
  local caseB = { { missing = { { "assembling-machine-1", 2 }, { "inserter", 7 }, { "iron-chest", 3 } } },
    { missing = { { "assembling-machine-1", 3 }, { "inserter", 10 }, { "iron-chest", 4 } } } }
  local pB, dB = Ca.seat_plate({ open = caseB, book = BOOK, names = NAMES, free = { ["iron-plate"] = 66, ["copper-plate"] = 354 } })
  check(pB == "iron-plate" and (dB["iron-plate"] or 0) > 0 and (dB["copper-plate"] or 0) == 0,
    string.format("cas B (assembleurs, bras, coffres ; fer 66, cuivre 354) : le fer (deficits fer %s, cuivre %s)", tostring(dB["iron-plate"]), tostring(dB["copper-plate"])))
  local circ = { { missing = { { "electronic-circuit", 40 } } } }
  local pC, dC = Ca.seat_plate({ open = circ, book = BOOK, names = NAMES, free = { ["iron-plate"] = 10, ["copper-plate"] = 20 } })
  check(pC == "copper-plate", string.format("40 circuits qui manquent (fer 10, cuivre 20) : le CUIVRE, par le câble (deficits fer %s, cuivre %s)",
    tostring(dC["iron-plate"]), tostring(dC["copper-plate"])))
  local old_b = Em.short(NAMES, ORES, Ca.blocked_items({ D = D, open = circ }), { ["iron-plate"] = 10, ["copper-plate"] = 20 })
  check(old_b["iron-plate"] == true and not old_b["copper-plate"], "le prédicat d'AGEBLOCAGE, lui, y voit le fer (ingrédient direct) : il reste tel quel")
  check(Ca.seat_plate({ open = caseB, book = BOOK, names = NAMES, free = { ["iron-plate"] = 5000, ["copper-plate"] = 5000 } }) == nil,
    "le stock libre couvre tout le coût brut : aucune plaque")
  check(Ca.seat_plate({ open = { { missing = { { "iron-plate", 5 }, { "copper-plate", 5 } } } }, book = BOOK, names = NAMES, free = {} }) == "iron-plate",
    "égalité : l'ordre des plaques (fer d'abord)")
  check(Ca.seat_plate({ open = { { missing = { { "iron-plate", 5 }, { "copper-plate", 6 } } } }, book = BOOK, names = NAMES, free = {} }) == "copper-plate",
    "un de plus en cuivre : le cuivre")
  check(Ca.seat_plate({ open = { { missing = { { "assembling-machine-1", 0 } } } }, book = BOOK, names = NAMES, free = {} }) == nil
    and Ca.seat_plate({ open = {}, book = BOOK, names = NAMES }) == nil and Ca.seat_plate({ open = caseB, names = NAMES }) == nil,
    "manque nul, aucun ordre ou aucun livre : aucune plaque")
  local closed = Book.new(RECIPES, { allowed = function(n) return n ~= "electronic-circuit" end })
  check(Ca.seat_plate({ open = circ, book = closed, names = NAMES, free = {} }) == nil,
    "recette des circuits pas encore ouverte (livre de la force) : on ne la suit pas, aucune plaque (D.producers la suivait)")
  local pB2 = Ca.seat_plate({ open = caseB, book = BOOK, names = NAMES, free = { ["iron-plate"] = 66, ["copper-plate"] = 354 } })
  check(pB2 == pB, "même entrée, même plaque (déterminisme)")
  local sB = Em.slots({ base = 2, plates = { 66, 354 }, mods = waiting_mods(), tick = T, names = NAMES, sleeping = {},
    short = Em.short(NAMES, ORES, { [pB] = true }, { ["iron-plate"] = 66, ["copper-plate"] = 354 }) })
  check(sB.comp and sB.comp["iron-plate"] and not sB.comp["copper-plate"] and not Em.drill_refused(sB, "iron-plate")
    and Em.drill_refused(sB, "copper-plate"), "cas B par le second prédicat : siège du fer seulement")

  section("témoin : sans manque, Em.slots rend exactement ce que rendait DEPENSES2 (c)")
  local same = true
  for _, sleep in ipairs({ {}, { ["copper-plate"] = true }, { ["iron-plate"] = true }, { ["iron-plate"] = true, ["copper-plate"] = true } }) do
    for _, n in ipairs({ 0, 1, 2, 3 }) do
      local mods = {}
      for i = 1, n do mods[i] = { key = "m" .. i, states = { "reserve" }, opened = 0 } end
      local a = Em.slots({ base = 2, plates = { 50, 50 }, mods = mods, tick = T, names = NAMES, sleeping = sleep })
      local c = Em.slots({ base = 2, plates = { 50, 50 }, mods = mods, tick = T, names = NAMES, sleeping = sleep, short = {} })
      if a.why ~= c.why or a.room_comp ~= c.room_comp or not set_eq(a.comp, c.comp) or a.busy ~= c.busy then same = false end
    end
  end
  check(same, "16 cas (sommeil × modules ouverts) : identiques avec short vide ou absent")
  local tx = Em.slots({ base = 2, plates = { 50, 50 }, mods = waiting_mods(), tick = T, names = NAMES, sleeping = { ["copper-plate"] = true } }).why
  check(tx:find(", +1 pour le complement du stock qui dort (iron-plate)", 1, true) ~= nil and not tx:find("manque", 1, true),
    "texte du journal de la règle 7 inchangé (lu par les outils de DEPENSES2)")
end

suite()

---------------------------------------------------------------------------------------------------
-- MUTANTS : chaque règle retirée doit faire échouer au moins un contrôle.
---------------------------------------------------------------------------------------------------
local base_fail = failures
print(string.format("[CHAMP-MANQUE] suite de base : %d OK, %d ECHEC(S)", passes, failures))
local saved = {}
local function patch(t, k, v) saved[#saved + 1] = { t, k, t[k] } t[k] = v end
local function unpatch() for i = #saved, 1, -1 do saved[i][1][saved[i][2]] = saved[i][3] saved[i] = nil end end
local killed, total = 0, 0
local function mutant(name, apply)
  total = total + 1
  local p0, f0 = passes, failures
  apply()
  quiet = true
  local ok = pcall(suite)
  quiet = false
  unpatch()
  local caught = (failures > f0) or not ok
  passes, failures = p0, f0
  if caught then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. name) end
end

mutant("manque ignoré (DEPENSES2 (c) seule)", function()
  local c = Em.complement
  patch(Em, "complement", function(n, s) return c(n, s) end)
end)
mutant("tout manque toujours", function() patch(Em, "short", function(names) local o = {} for _, n in ipairs(names) do o[n] = true end return o end) end)
mutant("stock riche ignoré", function() patch(Em, "PER_SLOT", 1e9) end)
mutant("deux sièges", function() patch(Em, "COMP_SLOTS", 2) end)
mutant("un produit qui dort reçoit le siège du manque", function()
  local c = Em.complement
  patch(Em, "complement", function(n, s, sh)
    local o = c(n, s, sh)
    for _, x in ipairs(n or {}) do if (sh or {})[x] then o = o or {} o[x] = true end end
    return o
  end)
end)
mutant("minerai oublié", function() patch(Em, "short", function(names, ores, bl, free)
  local o = {} for _, n in ipairs(names) do if (bl or {})[n] and ((free or {})[n] or 0) < Em.PER_SLOT then o[n] = true end end return o end) end)
mutant("ingrédients directs oubliés", function()
  patch(Ca, "blocked_items", function(ctx)
    local o = {} for _, od in ipairs(ctx.open or {}) do for _, m in ipairs(od.missing or {}) do if (m[2] or 0) > 0 then o[m[1]] = true end end end
    return o
  end)
end)
mutant("manque nul compté", function()
  patch(Ca, "blocked_items", function(ctx)
    local o = {} for _, od in ipairs(ctx.open or {}) do for _, m in ipairs(od.missing or {}) do o[m[1]] = true
      for _, rn in ipairs(ctx.D.producers[m[1]] or {}) do for _, i in ipairs(ctx.D.recipes[rn].ingredients) do if not i.fluid then o[i.name] = true end end end
    end end
    return o
  end)
end)
mutant("fluides comptés", function()
  patch(Ca, "blocked_items", function(ctx)
    local o = {} for _, od in ipairs(ctx.open or {}) do for _, m in ipairs(od.missing or {}) do if (m[2] or 0) > 0 then o[m[1]] = true
      for _, rn in ipairs(((ctx.D or {}).producers or {})[m[1]] or {}) do for _, i in ipairs(ctx.D.recipes[rn].ingredients) do o[i.name] = true end end
    end end end
    return o
  end)
end)
mutant("champ tenu ignoré (1e97d7da : seuls les modules comptent)", function()
  local sl0 = Em.slots
  patch(Em, "slots", function(s0) local c = {} for k, v in pairs(s0 or {}) do c[k] = v end c.held_comp = nil return sl0(c) end)
end)
mutant("le champ passe sans siège (1e97d7da : not to_champ)", function() patch(Em, "champ_seat", function() return "hors" end) end)
mutant("le champ prend le siège même avec des emplacements libres", function()
  patch(Em, "champ_seat", function(full, room, rc, comp, p) return Em.order_seat(room, rc, comp, p) == "complement" and "complement" or nil end)
end)
mutant("siège : ingrédients directs (l'ancien prédicat)", function()
  patch(Ca, "seat_plate", function(ctx)
    local b = Ca.blocked_items({ D = D, open = ctx.open })
    for _, n in ipairs(ctx.names or {}) do if b[n] and ((ctx.free or {})[n] or 0) < Em.PER_SLOT then return n end end
    return nil
  end)
end)
mutant("siège : stock libre ignoré", function()
  local sp = Ca.seat_plate
  patch(Ca, "seat_plate", function(ctx) local c = {} for k, v in pairs(ctx) do c[k] = v end c.free = {} return sp(c) end)
end)
mutant("siège : plus PETIT déficit", function()
  patch(Ca, "seat_plate", function(ctx)
    if not ctx.book then return nil, {} end
    local w = {} for _, o in ipairs(ctx.open or {}) do for _, m in ipairs(o.missing or {}) do if (m[2] or 0) > 0 then w[#w + 1] = { m[1], m[2] } end end end
    if #w == 0 then return nil, {} end
    local st = {} for _, n in ipairs(ctx.names) do st[n] = (ctx.free or {})[n] or 0 end
    local raw = ctx.book:plan(w, st).raw
    local best, bv = nil, nil
    for _, n in ipairs(ctx.names) do local v = raw[n] or 0 if v > 0 and (bv == nil or v < bv) then best, bv = n, v end end
    return best, {}
  end)
end)
mutant("ressource oubliée par unblocks", function()
  patch(Ca, "unblocks", function(o, b) return o ~= nil and b ~= nil and ((o.item and b[o.item]) or (o.product and b[o.product])) == true end)
end)

print(string.format("[CHAMP-MANQUE] MUTANTS : %d / %d refusés", killed, total))
print(string.format("[CHAMP-MANQUE] BILAN : %d OK, %d ECHEC(S)%s", passes, failures + (total - killed),
  base_fail > 0 and " (suite de base en échec)" or ""))
os.exit((failures == 0 and killed == total) and 0 or 1)
