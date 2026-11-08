--[[
  Lot X10-GEL : la comptabilité d'un îlot figé (shared/faction/gel_compta.lua), hors jeu. fo-logs/2026-11-07_X10/L1_CRITERES.md §3.3, §4.
    K1  foreuse thermique -> coffre : 2,5 minerais par 600 ticks, fraction gardée, 15 en 3 600 ticks ; gisement et charbon débités.
    K2  foreuse -> four (dépôt direct) -> sortie du four : plaques = minerai miné, aucun reste.
    K3  deux foreuses -> un four (le four limite) : contre-pression, aucun reste dans le bus, foreuses à l'arrêt « sortie pleine ».
    K4  four du QG rempli à la main : la source baisse, la sortie monte, recette relue.
    K5  limites : sans combustible, gisement vide, sortie pleine, coffre plein, source vide (statuts comptables).
    K6  productivité : 10 % de plaques en plus, à l'objet près sur 100 cycles.
    K7  conservation sur 300 îlots tirés d'une graine : rien de négatif, aucun produit sans ses ingrédients, aucune place dépassée.
    K8  déterminisme : même entrée, même sortie (texte sérialisé), entrées insérées dans un autre ordre comprises.
    K9  électrique (prêt pour le palier B) : satisfaction 0,5 -> moitié ; 0 -> « no_power » ; drain compté.
    K10 assembleur à deux ingrédients de bus (engrenages + plaques) : une source courte ne laisse pas de reste chez l'autre.
    K11 cycle refusé ; bus sans preneur refusé (Gc.check).
    K12 coût : instructions Lua par machine et par pas (debug.sethook, compte exact) ; C8 d'origine (400) NON TENU, seuil C8' de 1 300 décidé par le lead après mesure (7/11, 20 h 01).
    K13 remise à zéro (îlot à relire) : fractions et reports perdus, jamais gagnés.
    K18 option (ii) : Gc.progress_write en unités de mining_time (2 ; 1,5), dépassement porté en fin de plage, reste de côté.
    K17 report de la fraction d'un réveil au gel suivant (Gc.bank, Gc.restore) : foreuse et four, 2 et 5 gels et réveils, perte < 1 par
        machine sur toute la partie (et non par réveil), jamais un gain.
    Mutants (texte de la source changé, chargé par load) : ils doivent TOUS être vus.
  Usage : lua5.2 tests/gel_compta_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local quiet = false
local function check(c, msg)
  if c then ok_n = ok_n + 1; if not quiet and os.getenv("FO_VERBOSE") then print("[GEL-COMPTA] OK : " .. msg) end
  else fail_n = fail_n + 1; if not quiet then print("[GEL-COMPTA] ECHEC : " .. msg) end end
  return c
end

local SRC_PATH = "shared/faction/gel_compta.lua"
local function read_source()
  local fh = assert(io.open(SRC_PATH, "rb"))
  local s = fh:read("*a")
  fh:close()
  return s
end
local SOURCE = read_source()

local function load_gc(text)
  local fn = assert(load(text, "=" .. SRC_PATH))
  return fn()
end

local COAL = 4000000
local DRILL_W = 150000 / 60   -- foreuse thermique : 150 kW = 2 500 J/tick
local FURN_W = 90000 / 60     -- four en pierre : 90 kW

local function drill(id, o)
  o = o or {}
  return { id = id, kind = "drill", rate = (o.speed or 0.25) / (o.mt or 1) / 60, out = { { o.ore or "iron-ore", 1 } }, prod = o.prod or 0,
    energy = "burner", power = DRILL_W, eff = 1, emis = 12 / (150000 * 60), fuel = "fu" .. id, res = { "re" .. id }, src = {}, dst = o.dst }
end
local function furnace(id, o)
  o = o or {}
  return { id = id, kind = "craft", rate = (o.speed or 1) / (3.2 * 60), ing = { { o.ore or "iron-ore", 1 } }, out = { { o.plate or "iron-plate", 1 } },
    prod = o.prod or 0, energy = o.energy or "burner", power = FURN_W, drain = o.drain, eff = 1, emis = 2 / (90000 * 60),
    fuel = (o.energy == "electric") and nil or ("fu" .. id), src = o.src, dst = o.dst }
end
local function fuel(n, rem) return { items = { coal = n or 0 }, rem = rem or 0 } end
local function IL(ms) return { machines = ms, fv = { coal = COAL } } end
local function pool(items, space, amount) return { items = items or {}, space = space or {}, amount = amount } end

--- Applique un résultat à la frontière (ce que fera le runtime au monde), et garde l'état.
local function apply(Gc, fr, st, res)
  for _, id in ipairs(Gc.sorted_names(res.take)) do
    local p = fr.pools[id]
    for _, n in ipairs(Gc.sorted_names(res.take[id])) do
      p.items[n] = (p.items[n] or 0) - res.take[id][n]
      if p.space[n] then p.space[n] = p.space[n] + res.take[id][n] end
    end
  end
  for _, id in ipairs(Gc.sorted_names(res.put)) do
    local p = fr.pools[id]
    for _, n in ipairs(Gc.sorted_names(res.put[id])) do
      p.items[n] = (p.items[n] or 0) + res.put[id][n]
      p.space[n] = (p.space[n] or 0) - res.put[id][n]
    end
  end
  for _, id in ipairs(Gc.sorted_names(res.mined)) do fr.pools[id].amount = fr.pools[id].amount - res.mined[id] end
  for _, id in ipairs(Gc.sorted_names(res.fuel)) do
    local fp, u = fr.fuel[id], res.fuel[id]
    for _, n in ipairs(Gc.sorted_names(u.items)) do fp.items[n] = (fp.items[n] or 0) - u.items[n] end
    fp.rem = u.rem
  end
  Gc.commit(st, res)
end

local function run(Gc, il, fr, st, steps, dt)
  local tot = { crafts = {}, produced = {}, consumed = {}, last = nil, pollution = 0, excess = 0 }
  for _ = 1, steps do
    local res = assert(Gc.step(il, fr, st, dt))
    for _, id in ipairs(Gc.sorted_names(res.crafts)) do tot.crafts[id] = (tot.crafts[id] or 0) + res.crafts[id] end
    for _, n in ipairs(Gc.sorted_names(res.produced)) do tot.produced[n] = (tot.produced[n] or 0) + res.produced[n] end
    for _, n in ipairs(Gc.sorted_names(res.consumed)) do tot.consumed[n] = (tot.consumed[n] or 0) + res.consumed[n] end
    tot.pollution = tot.pollution + res.pollution
    tot.excess = tot.excess + res.excess
    apply(Gc, fr, st, res)
    tot.last = res
  end
  return tot
end

local function carry_of(st, bus, n) return ((st.carry or {})[bus] or {})[n] or 0 end

---------------------------------------------------------------------------------------------------
-- Les cas (rend le nombre d'échecs vus, pour les mutants)
---------------------------------------------------------------------------------------------------
local function cases(Gc)
  local f0 = fail_n

  -- K1 foreuse -> coffre
  do
    local il = IL({ drill(1, { dst = { { k = "pool", id = "chest" } } }) })
    local fr = { pools = { chest = pool({}, { ["iron-ore"] = 1000 }), re1 = pool(nil, nil, 1000) }, fuel = { fu1 = fuel(5) } }
    local st = {}
    local r1 = Gc.step(il, fr, st, 600)
    check(r1 and r1.crafts[1] == 2 and math.abs(r1.frac[1] - 0.5) < 1e-6, "K1 : 2 minerais au premier pas de 600 ticks, fraction 0,5 gardee")
    apply(Gc, fr, st, r1)
    local tot = run(Gc, il, fr, st, 5, 600)
    check(fr.pools.chest.items["iron-ore"] == 15, "K1 : 15 minerais au coffre en 3 600 ticks (" .. tostring(fr.pools.chest.items["iron-ore"]) .. ")")
    check(fr.pools.re1.amount == 985, "K1 : gisement debite de 15 (" .. tostring(fr.pools.re1.amount) .. ")")
    -- 15 minerais × 600 kJ = 9 MJ : 3 charbons entamés (12 MJ), braise 3 MJ
    check(fr.fuel.fu1.items.coal == 2 and math.abs(fr.fuel.fu1.rem - 3000000) < 1, "K1 : 9 MJ brules, 3 charbons pris, braise 3 MJ (" ..
      tostring(fr.fuel.fu1.items.coal) .. ", " .. tostring(fr.fuel.fu1.rem) .. ")")
    check(tot.last.status[1] == "working", "K1 : statut comptable « working »")
  end

  -- K2 foreuse -> four -> sortie
  do
    local il = IL({
      drill(1, { dst = { { k = "bus", id = "b1" } } }),
      furnace(2, { src = { { k = "bus", id = "b1" } }, dst = { { k = "pool", id = "out2" } } }) })
    local fr = { pools = { out2 = pool({}, { ["iron-plate"] = 100 }), re1 = pool(nil, nil, 5000) }, fuel = { fu1 = fuel(10), fu2 = fuel(10) } }
    local st = {}
    local tot = run(Gc, il, fr, st, 6, 600)
    check(fr.pools.out2.items["iron-plate"] == 15, "K2 : 15 plaques en 3 600 ticks (" .. tostring(fr.pools.out2.items["iron-plate"]) .. ")")
    check(carry_of(st, "b1", "iron-ore") == 0 and tot.excess == 0, "K2 : aucun minerai reste dans le bus")
    check((tot.produced["iron-ore"] or 0) == 15 and (tot.consumed["iron-ore"] or 0) == 15, "K2 : 15 minerais produits et 15 consommes (statistiques)")
    check(fr.pools.re1.amount == 4985, "K2 : gisement debite de 15")
  end

  -- K3 deux foreuses -> un four
  do
    local il = IL({
      drill(1, { dst = { { k = "bus", id = "b" } } }), drill(2, { dst = { { k = "bus", id = "b" } } }),
      furnace(3, { src = { { k = "bus", id = "b" } }, dst = { { k = "pool", id = "out3" } } }) })
    local fr = { pools = { out3 = pool({}, { ["iron-plate"] = 100 }), re1 = pool(nil, nil, 5000), re2 = pool(nil, nil, 5000) },
      fuel = { fu1 = fuel(10), fu2 = fuel(10), fu3 = fuel(10) } }
    local st = {}
    local tot = run(Gc, il, fr, st, 6, 600)
    local plates = fr.pools.out3.items["iron-plate"] or 0
    check(plates == 18, "K3 : le four limite : 18 plaques en 3 600 ticks (18,75 au plus) (" .. plates .. ")")
    check(carry_of(st, "b", "iron-ore") == 0 and tot.excess == 0, "K3 : contre-pression : aucun reste dans le bus")
    check((10000 - fr.pools.re1.amount - fr.pools.re2.amount) == plates, "K3 : minerai mine = plaques (" .. (10000 - fr.pools.re1.amount - fr.pools.re2.amount) .. ")")
  end

  -- K4 four du QG rempli à la main
  do
    local il = IL({ furnace(1, { src = { { k = "pool", id = "src1" } }, dst = { { k = "pool", id = "out1" } } }) })
    local fr = { pools = { src1 = pool({ ["iron-ore"] = 10 }, {}), out1 = pool({ ["iron-plate"] = 5 }, { ["iron-plate"] = 95 }) }, fuel = { fu1 = fuel(1) } }
    local st = {}
    local tot = run(Gc, il, fr, st, 6, 600)
    check(fr.pools.src1.items["iron-ore"] == 0 and fr.pools.out1.items["iron-plate"] == 15, "K4 : source 10 -> 0, sortie 5 -> 15")
    check(tot.last.status[1] == "no_ingredients", "K4 : source vide : « no_ingredients » (" .. tostring(tot.last.status[1]) .. ")")
  end

  -- K5 limites
  do
    local function one(machines, pools, fuels, dt)
      local fr = { pools = pools, fuel = fuels }
      return Gc.step(IL(machines), fr, {}, dt or 600)
    end
    local r = one({ drill(1, { dst = { { k = "pool", id = "c" } } }) }, { c = pool({}, { ["iron-ore"] = 50 }), re1 = pool(nil, nil, 100) }, { fu1 = fuel(0) })
    check(r.crafts[1] == 0 and r.status[1] == "no_fuel", "K5 : sans combustible : 0, « no_fuel » (" .. r.status[1] .. ")")
    r = one({ drill(1, { dst = { { k = "pool", id = "c" } } }) }, { c = pool({}, { ["iron-ore"] = 50 }), re1 = pool(nil, nil, 0) }, { fu1 = fuel(3) })
    check(r.crafts[1] == 0 and r.status[1] == "no_minable_resources", "K5 : gisement vide : « no_minable_resources » (" .. r.status[1] .. ")")
    r = one({ drill(1, { dst = { { k = "pool", id = "c" } } }) }, { c = pool({ ["iron-ore"] = 50 }, { ["iron-ore"] = 0 }), re1 = pool(nil, nil, 100) }, { fu1 = fuel(3) })
    check(r.crafts[1] == 0 and r.status[1] == "waiting_for_space_in_destination", "K5 : coffre plein : « waiting_for_space_in_destination » (" .. r.status[1] .. ")")
    r = one({ drill(1, { dst = { { k = "bus", id = "b" } } }), furnace(2, { src = { { k = "bus", id = "b" } }, dst = { { k = "pool", id = "o" } } }) },
      { o = pool({ ["iron-plate"] = 100 }, { ["iron-plate"] = 0 }), re1 = pool(nil, nil, 100) }, { fu1 = fuel(3), fu2 = fuel(3) })
    check(r.crafts[2] == 0 and r.status[2] == "full_output" and r.crafts[1] == 0, "K5 : sortie du four pleine : four « full_output », foreuse a l'arret (" ..
      r.status[2] .. ", " .. r.status[1] .. ")")
    check(r.status[1] == "waiting_for_space_in_destination", "K5 : la foreuse attend la place (" .. r.status[1] .. ")")
    check(r.passes == 1, "K5 : la contre-pression de la passe arriere suffit : une seule passe (" .. tostring(r.passes) .. ")")
    r = one({ drill(1, { dst = { { k = "bus", id = "b" } } }), furnace(2, { src = { { k = "bus", id = "b" } }, dst = { { k = "pool", id = "o" } } }) },
      { o = pool({}, { ["iron-plate"] = 100 }), re1 = pool(nil, nil, 100) }, { fu1 = fuel(3), fu2 = fuel(0) })
    check(r.crafts[2] == 0 and r.status[2] == "no_fuel" and r.crafts[1] == 0, "K5 : four sans combustible : la foreuse ne mine pas pour rien")
  end

  -- K6 productivité
  do
    local il = IL({ furnace(1, { prod = 0.1, src = { { k = "pool", id = "s" } }, dst = { { k = "pool", id = "o" } } }) })
    local fr = { pools = { s = pool({ ["iron-ore"] = 100 }, {}), o = pool({}, { ["iron-plate"] = 1000 }) }, fuel = { fu1 = fuel(50) } }
    local st = {}
    run(Gc, il, fr, st, 40, 600)
    local made = fr.pools.o.items["iron-plate"]
    check(made == 110 or made == 109, "K6 : 100 cycles a 10 % : 110 plaques (a la fraction pres) (" .. tostring(made) .. ")")
    check(fr.pools.s.items["iron-ore"] == 0, "K6 : 100 minerais consommes")
  end

  -- K7 conservation, îlots tirés d'une graine
  do
    local seed = 20261107
    local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648 return seed % n end
    local bad = 0
    for t = 1, 300 do
      local nd = 1 + rnd(3)
      local ms, pools, fuels = {}, {}, {}
      for i = 1, nd do
        ms[#ms + 1] = drill(i, { speed = 0.25 + rnd(4) * 0.25, prod = rnd(3) * 0.1, dst = { { k = "bus", id = "b" } } })
        pools["re" .. i] = pool(nil, nil, rnd(40))
        fuels["fu" .. i] = fuel(rnd(3), rnd(2) * 1000000)
      end
      local fid = nd + 1
      ms[#ms + 1] = furnace(fid, { speed = 1 + rnd(2), prod = rnd(2) * 0.2, src = { { k = "bus", id = "b" } }, dst = { { k = "pool", id = "o" } } })
      pools.o = pool({}, { ["iron-plate"] = rnd(60) })
      fuels["fu" .. fid] = fuel(rnd(3), 0)
      local fr = { pools = pools, fuel = fuels }
      local st = {}
      local mined0 = 0
      for i = 1, nd do mined0 = mined0 + pools["re" .. i].amount end
      local space0 = pools.o.space["iron-plate"]
      local tot = run(Gc, IL(ms), fr, st, 8, 300 + rnd(900))
      local mined = mined0
      for i = 1, nd do mined = mined - fr.pools["re" .. i].amount end
      local ore_use = tot.consumed["iron-ore"] or 0
      local plates = fr.pools.o.items["iron-plate"] or 0
      local fprod = ms[#ms].prod
      local okk = true
      for i = 1, nd do if fr.pools["re" .. i].amount < 0 or fr.fuel["fu" .. i].items.coal < 0 then okk = false end end
      if fr.fuel["fu" .. fid].items.coal < 0 then okk = false end
      if plates > space0 then okk = false end                                    -- place dépassée
      if plates > ore_use * (1 + fprod) + 1 + 1e-6 then okk = false end           -- plaque sans minerai
      if ore_use > (tot.produced["iron-ore"] or 0) then okk = false end            -- minerai consommé jamais produit
      if (tot.produced["iron-ore"] or 0) > mined * 1.3 + nd then okk = false end   -- minerai sans gisement (productivité 20 % au plus)
      if tot.excess > 0 then okk = false end
      if not okk then bad = bad + 1 end
    end
    check(bad == 0, "K7 : conservation sur 300 ilots tires (" .. bad .. " faux)")
  end

  -- K8 déterminisme
  do
    local function ser(v)
      if type(v) ~= "table" then return tostring(v) end
      local keys = {}
      for k in pairs(v) do keys[#keys + 1] = k end
      table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
      local parts = {}
      for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
      return "{" .. table.concat(parts, ",") .. "}"
    end
    local function mk(rev)
      local pools = {}
      local names = { "re1", "re2", "out3" }
      if rev then names = { "out3", "re2", "re1" } end
      for _, n in ipairs(names) do
        if n == "out3" then pools[n] = pool({}, { ["iron-plate"] = 7 }) else pools[n] = pool(nil, nil, 30) end
      end
      return IL({ drill(1, { dst = { { k = "bus", id = "b" } } }), drill(2, { dst = { { k = "bus", id = "b" } } }),
        furnace(3, { src = { { k = "bus", id = "b" } }, dst = { { k = "pool", id = "out3" } } }) }), { pools = pools, fuel = { fu1 = fuel(1), fu2 = fuel(1), fu3 = fuel(1) } }
    end
    local il1, fr1 = mk(false)
    local il2, fr2 = mk(true)
    local a = ser(Gc.step(il1, fr1, {}, 1800))
    local b = ser(Gc.step(il2, fr2, {}, 1800))
    check(a == b, "K8 : meme entree (inseree dans un autre ordre), meme sortie")
  end

  -- K9 électrique
  do
    local function mk(sat)
      local il = IL({ furnace(1, { energy = "electric", drain = 50, src = { { k = "pool", id = "s" } }, dst = { { k = "pool", id = "o" } } }) })
      return il, { pools = { s = pool({ ["iron-ore"] = 1000 }, {}), o = pool({}, { ["iron-plate"] = 1000 }) }, fuel = {}, sat = sat }
    end
    local il, fr = mk(1)
    local r1 = Gc.step(il, fr, {}, 3840)
    il, fr = mk(0.5)
    local r5 = Gc.step(il, fr, {}, 3840)
    il, fr = mk(0)
    local r0 = Gc.step(il, fr, {}, 3840)
    check(r1.crafts[1] == 20 and r5.crafts[1] == 10, "K9 : satisfaction 1 : 20 cycles, 0,5 : 10 (" .. r1.crafts[1] .. ", " .. r5.crafts[1] .. ")")
    check(r0.crafts[1] == 0 and r0.status[1] == "no_power" and r5.status[1] == "low_power", "K9 : satisfaction 0 : « no_power » ; 0,5 : « low_power »")
    check(math.abs(r1.energy - (20 * FURN_W * 3.2 * 60 + 50 * 3840)) < 1, "K9 : energie electrique = cycles x energie d'un cycle + drain")
  end

  -- K10 assembleur à deux ingrédients de bus
  do
    local gear = { id = 2, kind = "craft", rate = 1 / 30, ing = { { "iron-plate", 2 } }, out = { { "iron-gear-wheel", 1 } }, energy = "electric", power = 1000,
      src = { { k = "pool", id = "pl" } }, dst = { { k = "bus", id = "g" } } }
    local plate = { id = 3, kind = "craft", rate = 1 / 60, ing = { { "iron-ore", 1 } }, out = { { "iron-plate", 1 } }, energy = "electric", power = 1000,
      src = { { k = "pool", id = "ore" } }, dst = { { k = "bus", id = "p" } } }
    local belt = { id = 4, kind = "craft", rate = 1 / 30, ing = { { "iron-gear-wheel", 1 }, { "iron-plate", 1 } }, out = { { "transport-belt", 2 } },
      energy = "electric", power = 1000, src = { { k = "bus", id = "g" }, { k = "bus", id = "p" } }, dst = { { k = "pool", id = "o" } } }
    local il = IL({ gear, plate, belt })
    local fr = { pools = { pl = pool({ ["iron-plate"] = 500 }, {}), ore = pool({ ["iron-ore"] = 3 }, {}), o = pool({}, { ["transport-belt"] = 1000 }) }, fuel = {}, sat = 1 }
    local st = {}
    local tot = run(Gc, il, fr, st, 3, 600)
    check((tot.crafts[4] or 0) == 3 and (tot.crafts[2] or 0) == 3 and carry_of(st, "g", "iron-gear-wheel") == 0 and tot.excess == 0,
      "K10 : plaques de bus courtes (3) : 3 tapis, 3 engrenages, aucun engrenage en reste (" .. tostring(tot.crafts[4]) .. ", " ..
      tostring(tot.crafts[2]) .. ", reste " .. carry_of(st, "g", "iron-gear-wheel") .. ")")
  end

  -- K11 formes refusées
  do
    local a = { id = 1, kind = "craft", rate = 1, ing = { { "x", 1 } }, out = { { "y", 1 } }, energy = "electric", power = 1, src = { { k = "bus", id = "b2" } }, dst = { { k = "bus", id = "b1" } } }
    local b = { id = 2, kind = "craft", rate = 1, ing = { { "y", 1 } }, out = { { "x", 1 } }, energy = "electric", power = 1, src = { { k = "bus", id = "b1" } }, dst = { { k = "bus", id = "b2" } } }
    local okc, why = Gc.check({ machines = { a, b } })
    check(not okc and why == "cycle", "K11 : cycle refuse (" .. tostring(why) .. ")")
    local c = drill(1, { dst = { { k = "bus", id = "seul" } } })
    okc, why = Gc.check({ machines = { c } })
    check(not okc and why == "bus sans preneur", "K11 : bus sans preneur refuse (" .. tostring(why) .. ")")
    okc = Gc.check({ machines = { drill(1, { dst = { { k = "pool", id = "c" } } }) } })
    check(okc, "K11 : foreuse -> coffre acceptee")
  end

  -- K14 deux foreuses sur le MÊME gisement presque vide : jamais plus que ce qu'il contient
  do
    local d1, d2 = drill(1, { dst = { { k = "pool", id = "c" } } }), drill(2, { dst = { { k = "pool", id = "c" } } })
    d1.res, d2.res = { "g" }, { "g" }
    local il = IL({ d1, d2 })
    local fr = { pools = { c = pool({}, { ["iron-ore"] = 100 }), g = pool(nil, nil, 3) }, fuel = { fu1 = fuel(5), fu2 = fuel(5) } }
    local st = {}
    run(Gc, il, fr, st, 2, 1200)
    check(fr.pools.g.amount == 0 and fr.pools.c.items["iron-ore"] == 3, "K14 : gisement partage de 3 : 3 minerais, gisement a 0 (" ..
      tostring(fr.pools.g.amount) .. ", " .. tostring(fr.pools.c.items["iron-ore"]) .. ")")
  end

  -- K15 report au-delà du plafond : compté « excès »
  do
    local il = IL({ drill(1, { dst = { { k = "bus", id = "b" } } }), furnace(2, { src = { { k = "bus", id = "b" } }, dst = { { k = "pool", id = "o" } } }) })
    local fr = { pools = { o = pool({ ["iron-plate"] = 100 }, { ["iron-plate"] = 0 }), re1 = pool(nil, nil, 100) }, fuel = { fu1 = fuel(3), fu2 = fuel(3) } }
    local r = Gc.step(il, fr, { carry = { b = { ["iron-ore"] = 80 } } }, 600)
    check(r.excess == 30 and r.carry.b["iron-ore"] == 80, "K15 : report de 80 sans preneur : garde 80, compte 30 en exces (" .. tostring(r.excess) .. ")")
    check(r.passes == 1, "K15 : sortie pleine vue a la passe arriere : une seule passe (" .. tostring(r.passes) .. ")")
  end

  -- K16 ordre topologique : Kahn à file TRIÉE (le rang le plus petit d'abord)
  do
    local il = IL({ drill(1, { dst = { { k = "bus", id = "a" } } }), drill(2, { dst = { { k = "bus", id = "b" } } }),
      furnace(3, { src = { { k = "bus", id = "b" } }, dst = { { k = "pool", id = "o" } } }),
      furnace(4, { src = { { k = "bus", id = "a" } }, dst = { { k = "pool", id = "o" } } }) })
    local o = Gc.order(il)
    check(o and table.concat(o, ",") == "1,2,3,4", "K16 : ordre 1,2,3,4 (" .. tostring(o and table.concat(o, ",")) .. ")")
  end

  -- K13 remise à zéro
  do
    local st = { frac = { [1] = 0.7 }, pfrac = { [1] = { ["iron-plate"] = 0.4 } }, carry = { b = { ["iron-ore"] = 3 } } }
    local lost = Gc.reset(st)
    check(lost["iron-ore"] == 3 and next(st.frac) == nil and next(st.pfrac) == nil and next(st.carry) == nil, "K13 : remise a zero : fractions et reports perdus (jamais gagnes)")
  end

  -- K17 report de la fraction d'un réveil au gel suivant (diagnostic du 8/11, micro-banc A d'aa0f5477) : sur N gels et réveils, la perte
  -- est la fraction du DERNIER réveil (< 1 par machine sur toute la partie), jamais un gain ; foreuse et four du QG isolés.
  do
    local function cycles(kind, n, T)
      local il, fr
      if kind == "drill" then
        il = IL({ drill(1, { dst = { { k = "pool", id = "chest" } } }) })
        fr = { pools = { chest = pool({}, { ["iron-ore"] = 100000 }), re1 = pool(nil, nil, 100000) }, fuel = { fu1 = fuel(1000) } }
      else
        il = IL({ furnace(1, { src = { { k = "pool", id = "src" } }, dst = { { k = "pool", id = "out" } } }) })
        fr = { pools = { src = pool({ ["iron-ore"] = 100000 }, {}), out = pool({}, { ["iron-plate"] = 100000 }) }, fuel = { fu1 = fuel(1000) } }
      end
      local st, total = {}, 0
      for _ = 1, n do
        Gc.restore(st) -- gel
        local left = T
        while left > 0 do -- pas du créneau (1 200 ticks), puis pas dû au réveil
          local dt = math.min(1200, left)
          local res = assert(Gc.step(il, fr, st, dt))
          total = total + (res.crafts[1] or 0)
          apply(Gc, fr, st, res)
          left = left - dt
        end
        Gc.bank(st) -- réveil
      end
      return total, il.machines[1].rate * T * n
    end
    for _, kind in ipairs({ "drill", "furnace" }) do
      for _, n in ipairs({ 2, 5 }) do
        local got, ideal = cycles(kind, n, 1900)
        check(got <= ideal + 1e-9 and got >= ideal - 1, string.format("K17 : %s, %d gels et reveils de 1 900 ticks : %d fabrications pour %.3f (perte < 1 sur toute la partie, jamais un gain)",
          kind, n, got, ideal))
      end
    end
    local st = { frac = { [1] = 0.4 }, pfrac = { [1] = { ["iron-plate"] = 0.25 } }, carry = { b = { ["iron-ore"] = 2 } } }
    local lost = Gc.bank(st)
    check(lost["iron-ore"] == 2 and next(st.frac) == nil and st.bank_frac[1] == 0.4 and st.bank_pfrac[1]["iron-plate"] == 0.25,
      "K17 : au reveil, fraction et produits a faire mis de cote, reports de bus perdus")
    Gc.restore(st)
    check(st.frac[1] == 0.4 and st.pfrac[1]["iron-plate"] == 0.25 and st.bank_frac == nil and next(st.carry) == nil,
      "K17 : au gel, l'etat repart de la fraction mise de cote")
  end

  -- K18 option (ii) : progression à écrire au réveil, en unités de mining_time de la cible (fait moteur x10-gel-progres)
  do
    local p, r = Gc.progress_write(0.3, 0.4, 2)
    check(math.abs(p - 1.1) < 1e-9 and r == 0, string.format("K18 : mining_time 2 : 0,3 + 0,4 x 2 = 1,1 ecrit, rien de cote (%.6f, %.6f)", p, r))
    p, r = Gc.progress_write(0.2, 0.5, 1.5)
    check(math.abs(p - 0.95) < 1e-9 and r == 0, string.format("K18 : mining_time 1,5 : 0,2 + 0,5 x 1,5 = 0,95 (%.6f)", p))
    p, r = Gc.progress_write(1.2, 0.5, 2)
    check(p < 2 and p > 2 - 1e-5 and math.abs(r - (2.2 - p) / 2) < 1e-12 and r > 0.09 and r < 0.11,
      string.format("K18 : depassement : fin de plage ecrite (%.6f), le reste (%.6f fabrication) reste de cote", p, r))
  end


  return fail_n - f0
end

---------------------------------------------------------------------------------------------------
-- Source vraie
---------------------------------------------------------------------------------------------------
local Gc = load_gc(SOURCE)
cases(Gc)

-- K12 coût en instructions (debug.sethook, compte exact), pour un avant-poste typique (foreuse -> four) et un îlot de 12 machines
do
  local function count_instr(fn)
    local n = 0
    debug.sethook(function() n = n + 1 end, "", 1)
    fn()
    debug.sethook()
    return n
  end
  local il = IL({ drill(1, { dst = { { k = "bus", id = "b" } } }), furnace(2, { src = { { k = "bus", id = "b" } }, dst = { { k = "pool", id = "o" } } }) })
  local function fr() return { pools = { o = pool({}, { ["iron-plate"] = 100 }), re1 = pool(nil, nil, 5000) }, fuel = { fu1 = fuel(5), fu2 = fuel(5) } } end
  local n2 = count_instr(function() Gc.step(il, fr(), {}, 600) end)
  local ms, pools, fuels = {}, { o = pool({}, { ["iron-plate"] = 1000 }) }, {}
  for i = 1, 11 do ms[#ms + 1] = drill(i, { dst = { { k = "bus", id = "b" } } }); pools["re" .. i] = pool(nil, nil, 5000); fuels["fu" .. i] = fuel(5) end
  ms[#ms + 1] = furnace(12, { speed = 4, src = { { k = "bus", id = "b" } }, dst = { { k = "pool", id = "o" } } })
  fuels.fu12 = fuel(5)
  local n12 = count_instr(function() Gc.step(IL(ms), { pools = pools, fuel = fuels }, {}, 600) end)
  print(string.format("[GEL-COMPTA] instructions par pas : avant-poste (2 machines) %d, soit %.0f par machine ; ilot de 12 machines %d, soit %.0f par machine", n2, n2 / 2, n12, n12 / 12))
  check(n2 / 2 <= 1300, "K12 (C8' ; C8 de 400 non tenu) : avant-poste : au plus 1 300 instructions par machine et par pas (" .. string.format("%.0f", n2 / 2) .. ")")
  check(n12 / 12 <= 1300, "K12 (C8' ; C8 de 400 non tenu) : ilot de 12 machines : au plus 1 300 instructions par machine et par pas (" .. string.format("%.0f", n12 / 12) .. ")")
end

---------------------------------------------------------------------------------------------------
-- Mutants
---------------------------------------------------------------------------------------------------
local MUTANTS = {
  { "conservation coupee (ingredients non pris)", "local got = take(m.src or {}, it[1], k * it[2], pools, buses, res)", "local got = k * it[2]" },
  { "combustible ignore", "local function burn(il, m, need_j, fr, buses, res)\n  if need_j <= Gc.EPS then return end", "local function burn(il, m, need_j, fr, buses, res)\n  do return end" },
  { "gisement non debite", "p.amount = p.amount - q", "p.amount = p.amount" },
  { "satisfaction electrique ignoree", "local s = (m.energy == \"electric\") and sat or 1", "local s = 1" },
  { "contre-pression coupee (passe arriere)", "if a > 0 then d = min(d, max(0, absorb - (pf[n] or 0)) / a) end\n    end\n    d = max(0, d)", "end\n    d = max(0, d)" },
  { "contre-pression coupee (passe avant)", "local x = max(0, min(cap, l.ing, l.res, l.fuel, l.out, D[i] or 0))", "local x = max(0, min(cap, l.ing, l.res, l.fuel))" },
  { "report non compte en exces", "res.excess = res.excess + (box[n] - Gc.CARRY_MAX)", "res.excess = res.excess" },
  { "fraction non remise a zero", "st.frac, st.pfrac, st.carry = {}, {}, {}", "st.pfrac, st.carry = {}, {}" },
  { "fraction de temps perdue a chaque pas", "res.frac[m.id] = (x >= cap - Gc.EPS) and max(0, min(0.999999, cap - k)) or 0", "res.frac[m.id] = 0" },
  { "ordre des machines non trie", "    table.sort(ready)\n", "" },
  { "productivite ignoree", "local total = k * it[2] * (1 + (m.prod or 0)) + (pf_old[n] or 0)", "local total = k * it[2] + (pf_old[n] or 0)" },
  { "report oublie au reveil (Gc.bank)", "for _, id in ipairs(sorted_names(st.frac)) do bf[id] = (bf[id] or 0) + st.frac[id] end", "" },
  { "report oublie au gel (Gc.restore)", "st.frac, st.pfrac, st.carry = st.bank_frac or {}, st.bank_pfrac or {}, {}", "st.frac, st.pfrac, st.carry = {}, {}, {}" },
  { "plage 0..1 (progression ecrite)", "local new = p0 + f * mt", "local new = p0 + f" },
  { "plage 0..1 (fin de plage)", "local cap = mt * (1 - Gc.PROGRESS_EPS)", "local cap = 1 - Gc.PROGRESS_EPS" },
  { "statut sortie pleine perdu", "if l.out < 1 - Gc.EPS then return \"full_output\" end", "if false then end" },
}

quiet = true
local seen, missed = 0, {}
for _, mu in ipairs(MUTANTS) do
  local name, from, to = mu[1], mu[2], mu[3]
  local s, e = SOURCE:find(from, 1, true)
  if not s then
    missed[#missed + 1] = name .. " (texte introuvable)"
  else
    local text = SOURCE:sub(1, s - 1) .. to .. SOURCE:sub(e + 1)
    local okl, M = pcall(load_gc, text)
    local before = fail_n
    local okc = okl and pcall(cases, M)
    local died = (fail_n > before) or not okc or not okl
    fail_n = before
    if died then seen = seen + 1 else missed[#missed + 1] = name end
  end
end
quiet = false
check(#missed == 0, string.format("mutants : %d/%d vus%s", seen, #MUTANTS, #missed > 0 and (" ; NON VUS : " .. table.concat(missed, " ; ")) or ""))

print(string.format("[GEL-COMPTA] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
