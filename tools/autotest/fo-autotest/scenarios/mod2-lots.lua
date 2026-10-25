-- Scénario greffé du lot MOD-2 (25/10) : RECETTES PAR LOTS au-delà de 60 fabrications par seconde (D-15, Q-M2 a).
--   & "<racine>\fo-autotest.bat" nopause 2300 mod2-lots "<source>"
--   py -3.9 tools/autotest/mod2/analyse.py "<racine>\fo-autotest"      (coûts, temps par tick du bloc de 1 000 machines)
--   & "<racine>\fo-captures.bat" mod2-lots "<source>"                   (panneau : x-mod2-gui-*.png ; mode Alt)
--
-- Cellules (chacune nourrie et vidée par script à chaque tick, sauf mention) ; fenêtre de mesure ticks 600 à 1199 :
--   A0 témoin : niveau 30, 34 × palier 10, engrenage, posé SANS raise_built (jamais suivi : aucune décision de lot) ;
--   A  : même machine posée normalement, modules posés par script (aucun événement) : le balayage la passe au lot 100 ;
--   B  : conservation : niveau 30, engrenage, modules changés (0 → 3 → 34 → 3 → 0 × P10 : lots 1 → 10 → 100 → 10 → 1),
--        objets comptés à chaque bascule et en boucle fermée (plaques versées = 2 × engrenages sortis + reste) ;
--   C1 : béton (fluide), niveau 30, 34 × P10 (lot 10), eau versée par script, retour au lot 1 au tick 1 250 (boîte
--        plus petite) : eau, briques et minerai comptés à la bascule ; C2 : même machine nourrie par un tuyau infini ;
--   E  : usine chimique, 3 × P10, acide sulfurique (fluide en entrée ET en sortie) : lot 10 ;
--   D  : fours (aucun lot : un four choisit sa recette par l'objet entré) : vitesse et plaques/s d'un four électrique
--        à 2 × P10 entouré de 12 balises à 2 × P10, et d'un four en acier niveau 30 ;
--   H  : limite logistique : niveau 30, 34 × P10, engrenage, 16 bras empileurs entrants (coffres) et 8 sortants ;
--   F  : 1 000 machines d'assemblage 2, engrenage, 5 × P10 posés par script au tick 1 400 : toutes au lot 10 par le
--        balayage ; coûts (LuaProfiler) et temps par tick (analyse.py).
-- Recettes : engrenage actif au départ (lots activés à l'init) ; béton et acide activés par la RECHERCHE (événement) :
-- les lots doivent l'être aussi.

local NOM = "mod2-lots"
local X0, Y0 = 7000, 7000
local WA, WB = 600, 1200
local CHECK = 2200
local P10 = "fo-speed-module-10"
local L30 = "fo-lvl-assembler-30"
local T_B = { 300, 600, 900, 1300 }          -- B : bascules (modules changés puis relus)
local B_MODS = { 3, 34, 3, 0 }
local B_STOP = { [900] = 850, [1300] = 1250 } -- B : nourriture coupée avant les descentes
local T_C1 = 1250
local T_F, T_FPROF = 1400, 2000
local FX, FY, FCOLS, FN = 7000, 7120, 34, 1000

local STATUS = {}
for k, v in pairs(defines.entity_status) do STATUS[v] = k end
local function status(m) return m and m.valid and (STATUS[m.status] or tostring(m.status)) or "?" end

local function f6(v) return string.format("%.6g", v or 0) end

local function input(m) return m.get_inventory(defines.inventory.assembling_machine_input) end

local function set_mods(m, n)
  local inv = m.get_module_inventory()
  inv.clear()
  for _ = 1, n do inv.insert({ name = P10, count = 1 }) end
end

local function lot_state(m)
  local ok, r = pcall(remote.call, "fo-lots", "state", m)
  if ok then return r end
  return nil
end

local function lot_k(m)
  local s = lot_state(m)
  return s and s.k or 0
end

local function pend_item(st, name)
  local n = 0
  for _, it in ipairs(st and st.pending and st.pending.items or {}) do if it.name == name then n = n + it.count end end
  return n
end

local function pend_fluid(st, name)
  local n = 0
  for _, f in ipairs(st and st.pending and st.pending.fluids or {}) do if f.name == name then n = n + f.amount end end
  return n
end

local function box_total(m, name)
  local n = 0
  for i = 1, #m.fluidbox do
    local f = m.fluidbox[i]
    if f and f.name == name then n = n + f.amount end
  end
  return n
end

--- Plaques de fer « dans » la machine B : entrée + 2 × sortie + fabrication en cours + réserve.
local function b_total(m)
  local s = lot_state(m)
  local k = s and s.k or 1
  local inflight = (m.is_crafting() and m.crafting_progress > 0) and 2 * k or 0
  return input(m).get_item_count("iron-plate") + 2 * m.get_output_inventory().get_item_count("iron-gear-wheel") + inflight
    + pend_item(s, "iron-plate") + 2 * pend_item(s, "iron-gear-wheel"), k, inflight
end

--- Quantités de la recette de base du béton (passe 1 : 5 briques, et non 10).
local function concrete_amounts()
  local r = game.recipe_prototypes["concrete"]
  local a = {}
  for _, i in ipairs(r.ingredients) do a[i.name] = i.amount end
  a.product = r.products[1].amount
  return a
end

--- Matières « dans » une machine à béton, en équivalent d'ingrédients : eau, briques, minerai (boîte, entrée,
--- fabrication en cours, réserve) + le béton déjà fait dans la machine (sortie, réserve), ramené à ses ingrédients.
local function c_total(m)
  local A = concrete_amounts()
  local s = lot_state(m)
  local k = s and s.k or 1
  local busy = m.is_crafting() and m.crafting_progress > 0
  local inv = input(m)
  local conc = m.get_output_inventory().get_item_count("concrete") + pend_item(s, "concrete")
  local crafts = conc / A.product
  return {
    water = box_total(m, "water") + (busy and A.water * k or 0) + pend_fluid(s, "water") + crafts * A.water,
    brick = inv.get_item_count("stone-brick") + (busy and A["stone-brick"] * k or 0) + pend_item(s, "stone-brick")
      + crafts * A["stone-brick"],
    ore = inv.get_item_count("iron-ore") + (busy and A["iron-ore"] * k or 0) + pend_item(s, "iron-ore") + crafts * A["iron-ore"],
  }, k, s
end

local function put(m, name, want)
  local inv = input(m)
  local k = inv.get_item_count(name)
  if k < want then return inv.insert({ name = name, count = want - k }) end
  return 0
end

--- Eau versée dans la boîte d'entrée (jusqu'à la capacité) ; renvoie la quantité versée.
local function water(m, i)
  local cap = m.fluidbox.get_capacity(i)
  local cur = m.fluidbox[i]
  local have = cur and cur.amount or 0
  if have >= cap - 1e-9 then return 0 end
  m.fluidbox[i] = { name = "water", amount = cap, temperature = 15 }
  return cap - have
end

--- Index de la boîte d'entrée qui prend l'eau (filtre de la recette).
local function water_box(m)
  for i = 1, #m.fluidbox do
    local f = m.fluidbox.get_filter(i)
    if f and f.name == "water" then return i end
  end
  return 1
end

return {
  description = "MOD-2 : recettes par lots (debit au-dela de 60 /s, bascule aller-retour sans perte, fluides, fours, bras, 1 000 machines)",
  base = nil,
  check_tick = CHECK,
  shots_delay = 1000,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local f = game.forces.player
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    game.map_settings.enemy_expansion.enabled = false
    ctx.check(ctx.has("fo-lots", "state"), "interface fo-lots presente (mod MOD-2)")
    -- Lots chargés et activation (engrenage : actif au départ ; béton, acide : par la recherche).
    local n = remote.call("fo-lots", "bases")
    local nl = 0
    for name in pairs(game.recipe_prototypes) do if name:sub(1, 6) == "fo-lot" then nl = nl + 1 end end
    ctx.log("PROTO " .. nl .. " lots pour " .. n .. " recettes")
    ctx.check(nl >= 400 and n >= 200, "lots charges (x10, x100)", nl .. " lots, " .. n .. " bases")
    local g10, g100 = game.recipe_prototypes["fo-lot10-iron-gear-wheel"], game.recipe_prototypes["fo-lot100-iron-gear-wheel"]
    ctx.check(g10 and g100 and g10.hidden and g100.hidden and g100.energy == 50 and g100.ingredients[1].amount == 200
      and g100.products[1].amount == 100, "engrenage x100 : 200 plaques -> 100 engrenages en 50 s, cache",
      g100 and (g100.energy .. " s ; " .. serpent.line(g100.ingredients) .. " -> " .. serpent.line(g100.products)))
    ctx.check(f.recipes["iron-gear-wheel"].enabled and f.recipes["fo-lot10-iron-gear-wheel"].enabled
      and f.recipes["fo-lot100-iron-gear-wheel"].enabled, "lots de l'engrenage actifs avec la recette de base (init)")
    local before = f.recipes["fo-lot10-concrete"].enabled
    f.technologies["concrete"].researched = true
    f.technologies["sulfur-processing"].researched = true
    ctx.check(before == false and f.recipes["concrete"].enabled and f.recipes["fo-lot10-concrete"].enabled
      and f.recipes["fo-lot100-concrete"].enabled and f.recipes["fo-lot10-sulfuric-acid"].enabled,
      "lots du beton et de l'acide actives par la recherche (on_research_finished)",
      "avant " .. tostring(before) .. " ; apres " .. tostring(f.recipes["fo-lot10-concrete"].enabled))
    f.stack_inserter_capacity_bonus = 11

    ctx.prepare_area(X0 - 30, Y0 - 20, X0 + 190, Y0 + 220, "grass-1")
    ctx.power(X0 + 60, Y0 + 30)
    ctx.power(X0 + 150, Y0 + 30)
    ctx.power(X0 + 50, Y0 + 165)

    local function l30(x, y, raise)
      local m = s.create_entity({ name = L30, position = { x, y }, force = f, raise_built = raise })
      m.set_recipe("iron-gear-wheel")
      return m
    end
    -- A0 témoin (jamais suivi), A automatique.
    st.a0 = { m = l30(X0, Y0, false), n = 0 }
    set_mods(st.a0.m, 34)
    st.a = { m = l30(X0 + 30, Y0, true), n = 0 }
    set_mods(st.a.m, 34)
    ctx.check(lot_k(st.a.m) == 1 and lot_k(st.a0.m) == 1, "A et A0 : lot 1 a la pose (modules poses ensuite, sans evenement)")
    -- B : conservation.
    st.b = { m = l30(X0 + 60, Y0, true), fed = 0, out = 0, sw = {} }
    -- C1, C2 : béton.
    local function concrete(x, y)
      local m = s.create_entity({ name = L30, position = { x, y }, force = f, raise_built = true })
      m.set_recipe("concrete")
      set_mods(m, 34)
      pcall(remote.call, "fo-modules", "refresh", m, true)
      return m
    end
    st.c1 = { m = concrete(X0 + 90, Y0), n = 0, w = 0, br = 0, ore = 0 }
    st.c2 = { m = concrete(X0 + 120, Y0), n = 0 }
    do
      local m = st.c2.m
      local conns = m.fluidbox.get_pipe_connections(water_box(m))
      local tp = conns and conns[1] and conns[1].target_position
      if tp then
        local pipe = s.create_entity({ name = "infinity-pipe", position = tp, force = f })
        if pipe then pipe.set_infinity_pipe_filter({ name = "water", percentage = 1 }) end
        st.c2.pipe = pipe
      end
      ctx.check(st.c2.pipe ~= nil, "C2 : tuyau infini d'eau raccorde", serpent.line(tp))
    end
    -- E : usine chimique, acide sulfurique.
    do
      local m = s.create_entity({ name = "chemical-plant", position = { X0 + 150, Y0 }, force = f, raise_built = true })
      m.set_recipe("sulfuric-acid")
      set_mods(m, 3)
      pcall(remote.call, "fo-modules", "refresh", m, true)
      st.e = { m = m, acid = 0 }
    end
    -- D : fours.
    do
      local fx, fy = X0 + 10, Y0 + 60
      local fe = s.create_entity({ name = "electric-furnace", position = { fx, fy }, force = f, raise_built = true })
      set_mods(fe, 2)
      pcall(remote.call, "fo-modules", "refresh", fe, true)
      local nb = 0
      local offs = { { -3, -3 }, { 0, -3 }, { 3, -3 }, { -3, 0 }, { 3, 0 }, { -3, 3 }, { 0, 3 }, { 3, 3 },
        { -6, 0 }, { 6, 0 }, { 0, -6 }, { 0, 6 } }
      for _, o in ipairs(offs) do
        local b = s.create_entity({ name = "beacon", position = { fe.position.x + o[1], fe.position.y + o[2] }, force = f })
        if b then
          b.get_module_inventory().insert({ name = P10, count = 2 })
          nb = nb + 1
        end
      end
      local sf = s.create_entity({ name = "fo-lvl-furnace-30", position = { fx + 40, fy }, force = f, raise_built = true })
      st.d = { fe = fe, sf = sf, nb = nb, n = 0, nsf = 0 }
    end
    -- H : bras.
    do
      local m = s.create_entity({ name = L30, position = { X0 + 100, Y0 + 60 }, force = f, raise_built = true })
      m.set_recipe("iron-gear-wheel")
      set_mods(m, 34)
      pcall(remote.call, "fo-modules", "refresh", m, true)
      local bb = m.bounding_box
      local x1, y1 = math.floor(bb.left_top.x + 0.5), math.floor(bb.left_top.y + 0.5)
      local x2, y2 = math.floor(bb.right_bottom.x + 0.5), math.floor(bb.right_bottom.y + 0.5)
      local ins, outs = {}, {}
      -- dir : direction du bras (la prise est du côté de sa direction, E151) ; (cx, cy) : coffre.
      local function arm(px, py, dir, cx, cy, src)
        local chest = s.create_entity({ name = "iron-chest", position = { cx, cy }, force = f })
        local a = s.create_entity({ name = "stack-inserter", position = { px, py }, direction = dir, force = f })
        local mx, my = 2 * px - cx, 2 * py - cy -- point dans la machine, symétrique du coffre
        if src then
          a.pickup_position = { cx, cy }
          a.drop_position = { mx, my }
        else
          a.pickup_position = { mx, my }
          a.drop_position = { cx, cy }
        end
        if src then
          chest.insert({ name = "iron-plate", count = 1000 })
          ins[#ins + 1] = { i = a, c = chest, n = 0 }
        else
          outs[#outs + 1] = { i = a, c = chest }
        end
      end
      local D = defines.direction
      for x = x1 + 0.5, x2 - 0.5 do arm(x, y1 - 0.5, D.north, x, y1 - 1.5, true) end           -- nord : 6 entrants
      for y = y1 + 0.5, y2 - 0.5 do arm(x1 - 0.5, y, D.west, x1 - 1.5, y, true) end            -- ouest : 6 entrants
      for y = y1 + 0.5, y2 - 0.5 do arm(x2 + 0.5, y, D.west, x2 + 1.5, y, false) end           -- est : 6 sortants
      local i = 0
      for x = x1 + 0.5, x2 - 0.5 do                                                              -- sud : 4 entrants, 2 sortants
        i = i + 1
        if i <= 4 then arm(x, y2 + 0.5, D.south, x, y2 + 1.5, true) else arm(x, y2 + 0.5, D.north, x, y2 + 1.5, false) end
      end
      st.h = { m = m, ins = ins, outs = outs, n = 0 }
      ctx.log("H : bras entrants " .. #ins .. ", sortants " .. #outs .. " ; capacite des bras empileurs " .. (f.stack_inserter_capacity_bonus + 1))
    end
    -- F : 1 000 machines.
    do
      local rows = math.ceil(FN / FCOLS)
      ctx.prepare_area(FX - 4, FY - 4, FX + FCOLS * 3 + 4, FY + rows * 3 + 4, "grass-1")
      st.bloc = {}
      local p = game.create_profiler()
      for k = 1, FN do
        local m = s.create_entity({ name = "assembling-machine-2", position = { FX + ((k - 1) % FCOLS) * 3, FY + math.floor((k - 1) / FCOLS) * 3 },
          force = f, raise_built = true })
        if m then
          m.set_recipe("iron-gear-wheel")
          st.bloc[#st.bloc + 1] = m
        end
      end
      p.stop()
      log({ "", "[FO-MOD2-LOTS] COUT\tpose de 1 000 machines (create_entity raise_built, suivi compris)\tn=", tostring(FN), "\t", p })
      ctx.check(#st.bloc == FN, "F : 1 000 machines posees", #st.bloc)
    end
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local t = e.tick
    local fen = t > WA and t <= WB

    -- A0, A : engrenage nourri, sortie vidée.
    for _, c in ipairs({ st.a0, st.a }) do
      local m = c.m
      put(m, "iron-plate", 100000)
      local out = m.get_output_inventory()
      local nb = out.get_item_count()
      if nb > 0 then out.clear() end
      if fen then c.n = c.n + nb end
      if not c.k100 and lot_k(m) == 100 then c.k100 = t end
    end

    -- B : conservation.
    local b = st.b
    if b and b.m.valid then
      local m = b.m
      local stop = false
      for at, before in pairs(B_STOP) do if t > before and t <= at then stop = true end end
      if not stop then b.fed = b.fed + put(m, "iron-plate", 100000) end
      local out = m.get_output_inventory()
      local nb = out.get_item_count()
      if nb > 0 then
        out.clear()
        b.out = b.out + nb
      end
      for i, at in ipairs(T_B) do
        if t == at then
          local tot0, k0, fl0 = b_total(m)
          set_mods(m, B_MODS[i])
          pcall(remote.call, "fo-modules", "refresh", m, true)
          local tot1, k1, fl1 = b_total(m)
          local sx = lot_state(m)
          b.sw[#b.sw + 1] = { t = t, k0 = k0, k1 = k1, tot0 = tot0, tot1 = tot1, fl0 = fl0,
            pend = sx and sx.pending and serpent.line(sx.pending) or "aucune", input = input(m).get_item_count("iron-plate") }
        end
      end
    end

    -- C1 : béton, eau versée par script ; C2 : tuyau infini.
    local c1 = st.c1
    if c1 and c1.m.valid then
      local m = c1.m
      if t < T_C1 then c1.w = c1.w + water(m, water_box(m)) end
      c1.br = c1.br + put(m, "stone-brick", 100000)
      c1.ore = c1.ore + put(m, "iron-ore", 100000)
      local out = m.get_output_inventory()
      local nb = out.get_item_count()
      if nb > 0 then out.clear() end
      c1.n = c1.n + nb
      if fen then c1.nf = (c1.nf or 0) + nb end
      if t == WA then c1.k_mes = lot_k(m) end
      if t == T_C1 then
        local tot0, k0 = c_total(m)
        set_mods(m, 3)
        pcall(remote.call, "fo-modules", "refresh", m, true)
        local tot1, k1, sx = c_total(m)
        c1.sw = { tot0 = tot0, tot1 = tot1, k0 = k0, k1 = k1, pend = sx and sx.pending and serpent.line(sx.pending) or "aucune",
          cap = m.fluidbox.get_capacity(water_box(m)), box = box_total(m, "water") }
      end
      if t > T_C1 and t % 150 == 0 then
        local s2 = lot_state(m)
        ctx.log(string.format("C1 tick %d : lot %s ; boite eau %s ; reserve %s", t, tostring(s2 and s2.k), f6(box_total(m, "water")),
          s2 and s2.pending and serpent.line(s2.pending) or "aucune"))
      end
    end
    local c2 = st.c2
    if c2 and c2.m.valid then
      local m = c2.m
      put(m, "stone-brick", 100000)
      put(m, "iron-ore", 100000)
      local out = m.get_output_inventory()
      local nb = out.get_item_count()
      if nb > 0 then out.clear() end
      if fen then c2.n = c2.n + nb end
    end

    -- E : acide.
    local ce = st.e
    if ce and ce.m.valid then
      local m = ce.m
      put(m, "sulfur", 1000)
      put(m, "iron-plate", 1000)
      water(m, water_box(m))
      for i = 1, #m.fluidbox do
        local fl = m.fluidbox[i]
        if fl and fl.name == "sulfuric-acid" then
          if fen then ce.acid = ce.acid + fl.amount end
          m.fluidbox[i] = nil
        end
      end
    end

    -- D : fours.
    local d = st.d
    if d then
      for _, key in ipairs({ "fe", "sf" }) do
        local m = d[key]
        if m and m.valid then
          local src = m.get_inventory(defines.inventory.furnace_source)
          if src.get_item_count("iron-ore") < 50 then src.insert({ name = "iron-ore", count = 50 }) end
          if key == "sf" then
            local fuel = m.get_inventory(defines.inventory.fuel)
            if fuel and fuel.get_item_count("coal") < 20 then fuel.insert({ name = "coal", count = 20 }) end
          end
          local out = m.get_output_inventory()
          local nb = out.get_item_count()
          if nb > 0 then out.clear() end
          if fen then
            if key == "fe" then d.n = d.n + nb else d.nsf = d.nsf + nb end
          end
        end
      end
    end

    -- H : bras.
    local h = st.h
    if h and h.m.valid then
      for _, o in ipairs(h.ins) do
        local inv = o.c.get_inventory(defines.inventory.chest)
        local k = inv.get_item_count("iron-plate")
        if k < 1000 then
          inv.insert({ name = "iron-plate", count = 1000 - k })
          if fen then o.n = o.n + 1000 - k end
        end
      end
      for _, o in ipairs(h.outs) do
        local inv = o.c.get_inventory(defines.inventory.chest)
        local nb = inv.get_item_count()
        if nb > 0 then inv.clear() end
        if fen then h.n = h.n + nb end
      end
    end

    -- F : modules posés par script au tick T_F (aucun événement) ; toutes au lot 10 par le balayage.
    if t == T_F and st.bloc then
      for _, m in ipairs(st.bloc) do if m.valid then set_mods(m, 5) end end
      ctx.log("F : 5 x P10 poses par script sur " .. #st.bloc .. " machines au tick " .. t .. " (aucun evenement)")
    end
    if st.bloc and t > T_F and t % 30 == 0 and not st.bloc_fini then
      local n10 = 0
      for _, m in ipairs(st.bloc) do
        local r = m.valid and m.get_recipe()
        if r and r.name == "fo-lot10-iron-gear-wheel" then n10 = n10 + 1 end
      end
      if n10 == #st.bloc then st.bloc_fini = t end
      if t % 150 == 0 then ctx.log("F : " .. n10 .. " / " .. #st.bloc .. " machines au lot 10 au tick " .. t) end
    end
    if t == T_FPROF and st.bloc then
      for k = 1, 3 do
        local p = game.create_profiler()
        for _, m in ipairs(st.bloc) do remote.call("fo-lots", "consider", m) end
        p.stop()
        log({ "", "[FO-MOD2-LOTS] COUT\tdecision sans bascule (appel distant compris, #", tostring(k), ")\tn=", tostring(#st.bloc), "\t", p })
      end
      local p0 = game.create_profiler()
      for _, m in ipairs(st.bloc) do local _ = remote.call("fo-lots", "state", m) end
      p0.stop()
      log({ "", "[FO-MOD2-LOTS] COUT\tappel distant seul (state, temoin)\tn=", tostring(#st.bloc), "\t", p0 })
      -- Bascule forcée : 100 machines repassent au lot 1 (modules retirés) puis relues (décision et set_recipe).
      local p1 = game.create_profiler()
      for k = 1, 100 do
        local m = st.bloc[k]
        m.get_module_inventory().clear()
        remote.call("fo-modules", "refresh", m, true)
      end
      p1.stop()
      log({ "", "[FO-MOD2-LOTS] COUT\tmodules retires + relecture + bascule 10 -> 1 (balise reecrite comprise)\tn=100\t", p1 })
      local p2 = game.create_profiler()
      for k = 101, 200 do remote.call("fo-lots", "switch_to", st.bloc[k], 1) end
      p2.stop()
      log({ "", "[FO-MOD2-LOTS] COUT\tbascule seule 10 -> 1 (set_recipe, machine vide, appel distant compris)\tn=100\t", p2 })
      local p3 = game.create_profiler()
      for k = 201, 300 do remote.call("fo-modules", "refresh", st.bloc[k], true) end
      p3.stop()
      log({ "", "[FO-MOD2-LOTS] COUT\trelecture forcee sans bascule (balise reecrite, temoin)\tn=100\t", p3 })
    end

    -- Images (session avec images seulement) : interfaces ouvertes.
    local p = game.connected_players[1]
    local T_GUI = 1000
    if p and t >= T_GUI and t < T_GUI + 40 then
      local cibles = { { "A-lot100", st.a.m }, { "C1-beton-lot10", st.c1.m }, { "E-acide-lot10", st.e.m }, { "B-lot100", st.b.m } }
      local k = math.floor((t - T_GUI) / 10) + 1
      local phase = (t - T_GUI) % 10
      local cb = cibles[k]
      if cb and cb[2] and cb[2].valid then
        if phase == 0 then
          p.teleport({ cb[2].position.x, cb[2].position.y + 6 })
          pcall(function() p.opened = cb[2] end)
        elseif phase == 4 then
          game.take_screenshot({ path = "fo-shots/x-mod2-gui-" .. cb[1] .. ".png", player = p, show_gui = true,
            position = cb[2].position, zoom = 1, resolution = { 1920, 1080 }, force_render = true, allow_in_replay = true })
        elseif phase == 7 then
          p.opened = nil
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then
      ctx.fail("scenario pret", "init interrompue")
      return
    end
    local secs = (WB - WA) / 60
    -- A0, A : débit.
    local a0, a = st.a0, st.a
    local v = a.m.crafting_speed
    local want = v / 0.5
    ctx.log(string.format("MESURE A0 (temoin, jamais suivi) : vitesse %s ; %d engrenages en %.0f s = %.2f /s ; lot %d", f6(a0.m.crafting_speed),
      a0.n, secs, a0.n / secs, lot_k(a0.m)))
    ctx.log(string.format("MESURE A (automatique) : vitesse %s (voulu %.1f engrenages/s) ; lot 100 au tick %s ; %d engrenages en %.0f s = %.2f /s",
      f6(v), want, tostring(a.k100), a.n, secs, a.n / secs))
    ctx.check(math.abs(a0.n / secs - 60) < 0.6, "A0 temoin : plafonne a 60 engrenages/s (lot 1, jamais suivi)", f6(a0.n / secs))
    ctx.check(a.k100 and a.k100 <= 310, "A : passe seule au lot 100 par le balayage (<= 310 ticks)", tostring(a.k100))
    ctx.check(math.abs(a.n / secs - want) <= 0.01 * want + 10, "A : debit au lot 100 = vitesse / 0,5 s (" .. string.format("%.0f", want) .. " /s)",
      string.format("%.2f /s mesure", a.n / secs))
    -- B : conservation à chaque bascule et en boucle fermée.
    local b = st.b
    local seq = {}
    local exact = true
    for _, sw in ipairs(b.sw) do
      seq[#seq + 1] = sw.k0 .. "->" .. sw.k1
      ctx.log(string.format("MESURE B tick %d : lot %d -> %d ; plaques dans la machine avant %d (en cours %d) apres %d ; entree apres %d ; reserve %s",
        sw.t, sw.k0, sw.k1, sw.tot0, sw.fl0, sw.tot1, sw.input, sw.pend))
      if sw.tot0 ~= sw.tot1 then exact = false end
    end
    ctx.check(table.concat(seq, " ") == "1->10 10->100 100->10 10->1", "B : bascules 1 -> 10 -> 100 -> 10 -> 1", table.concat(seq, " "))
    ctx.check(exact, "B : aucune plaque perdue ni creee a chaque bascule (entree + sortie + en cours + reserve)")
    local tot, k = b_total(b.m)
    local bal = b.fed - 2 * b.out - tot
    ctx.log(string.format("MESURE B boucle fermee : plaques versees %d ; engrenages sortis %d ; dans la machine %d (lot %d) ; ecart %d", b.fed,
      b.out, tot, k, bal))
    ctx.check(bal == 0 and b.out > 0, "B : boucle fermee exacte (plaques versees = 2 x engrenages sortis + reste)", bal)
    local sb = lot_state(b.m)
    ctx.check(not (sb and sb.pending), "B : aucune reserve en attente a la fin (bras ou script tenant l'entree pleine)",
      sb and sb.pending and serpent.line(sb.pending) or "aucune")
    -- C1 : béton.
    local c1 = st.c1
    local sw = c1.sw
    if sw then
      ctx.log(string.format("MESURE C1 bascule tick %d : lot %d -> %d ; en equivalent d'ingredients (beton fait compris) : eau %s -> %s ; briques %s -> %s ; minerai %s -> %s ; capacite apres %s ; boite apres %s ; reserve %s",
        T_C1, sw.k0, sw.k1, f6(sw.tot0.water), f6(sw.tot1.water), f6(sw.tot0.brick), f6(sw.tot1.brick), f6(sw.tot0.ore), f6(sw.tot1.ore),
        f6(sw.cap), f6(sw.box), sw.pend))
      ctx.check(sw.k0 == 10 and sw.k1 == 1, "C1 : beton lot 10 -> 1 (3 x P10 au lieu de 34)", sw.k0 .. " -> " .. sw.k1)
      ctx.check(math.abs(sw.tot0.water - sw.tot1.water) < 1e-3 and math.abs(sw.tot0.brick - sw.tot1.brick) < 1e-6
        and math.abs(sw.tot0.ore - sw.tot1.ore) < 1e-6,
        "C1 : eau, briques et minerai gardes a la bascule (fabrication en cours achevee, boite plus petite : reste en reserve)")
    else
      ctx.fail("C1 : bascule", "absente")
    end
    local c1v = c1.m.valid and lot_state(c1.m)
    local tc1 = c_total(c1.m)
    local A = concrete_amounts()
    local crafts = c1.n / A.product
    local wbal = c1.w - A.water * crafts - tc1.water
    local bbal = c1.br - A["stone-brick"] * crafts - tc1.brick
    ctx.log(string.format("MESURE C1 boucle fermee : eau versee %s ; betons %d ; eau dans la machine %s ; ecart eau %s ; briques ecart %s ; lot %s ; reserve %s",
      f6(c1.w), c1.n, f6(tc1.water), f6(wbal), f6(bbal), tostring(c1v and c1v.k), c1v and c1v.pending and serpent.line(c1v.pending) or "aucune"))
    ctx.check(math.abs(wbal) < 0.01 and math.abs(bbal) < 1e-6, "C1 : boucle fermee exacte (eau, briques)", f6(wbal) .. " ; " .. f6(bbal))
    ctx.check(pend_fluid(c1v, "water") < 1e-3 and pend_item(c1v, "stone-brick") == 0, "C1 : reserve reversee dans la machine (vide a la fin)",
      c1v and c1v.pending and serpent.line(c1v.pending) or "aucune")
    local cw = st.c1.m.crafting_speed
    ctx.log(string.format("MESURE C1 (eau par script) : lot %s pendant la mesure ; %d betons en %.0f s = %.2f /s", tostring(c1.k_mes), c1.nf or 0, secs, (c1.nf or 0) / secs))
    ctx.log(string.format("MESURE C2 (tuyau infini) : vitesse %s ; %d betons en %.0f s = %.2f /s (voulu %.1f) ; lot %d", f6(st.c2.m.crafting_speed),
      st.c2.n, secs, st.c2.n / secs, st.c2.m.crafting_speed, lot_k(st.c2.m)))
    ctx.check(c1.k_mes == 10 and (c1.nf or 0) / secs >= 0.95 * 818 and lot_k(st.c2.m) == 10,
      "C1, C2 : beton au lot 10, debit voulu tenu avec l'eau versee par script (~818 /s)", string.format("%.1f /s", (c1.nf or 0) / secs))
    -- E : acide.
    local ce = st.e
    local ve = ce.m.crafting_speed
    ctx.log(string.format("MESURE E (usine chimique, 3 x P10) : vitesse %s ; lot %d ; acide %s en %.0f s = %.1f /s (voulu %.1f)", f6(ve), lot_k(ce.m),
      f6(ce.acid), secs, ce.acid / secs, 50 * ve))
    ctx.check(lot_k(ce.m) == 10 and math.abs(ce.acid / secs - 50 * ve) <= 0.03 * 50 * ve, "E : acide sulfurique au lot 10, debit voulu (fluide en sortie)",
      string.format("%.1f /s", ce.acid / secs))
    -- D : fours.
    local d = st.d
    ctx.log(string.format("MESURE D four electrique 2 x P10 + %d balises a 2 x P10 : vitesse %s ; %d plaques en %.0f s = %.2f /s (plafond 60) ; four en acier niveau 30 : vitesse %s ; %.2f plaques/s",
      d.nb, f6(d.fe.crafting_speed), d.n, secs, d.n / secs, f6(d.sf and d.sf.crafting_speed), d.nsf / secs))
    ctx.check(d.fe.crafting_speed / 3.2 < 60, "D : four electrique au maximum de ce banc sous 60 fabrications/s (aucun lot requis)",
      string.format("%.2f /s voulues", d.fe.crafting_speed / 3.2))
    -- H : bras.
    local h = st.h
    local per = {}
    local tin = 0
    for _, o in ipairs(h.ins) do
      per[#per + 1] = string.format("%.1f", o.n / secs)
      tin = tin + o.n
    end
    ctx.log(string.format("MESURE H bras : %d engrenages en %.0f s = %.2f /s ; plaques entrees %.1f /s (%d bras) ; par bras : %s ; lot %d ; voulu %.0f /s",
      h.n, secs, h.n / secs, tin / secs, #h.ins, table.concat(per, " ; "), lot_k(h.m), h.m.crafting_speed / 0.5))
    ctx.check(lot_k(h.m) == 100 and h.n / secs > 60, "H : avec de vrais bras, plus de 60 engrenages/s sortent (limite logistique mesuree)",
      string.format("%.1f /s", h.n / secs))
    -- F : 1 000 machines.
    ctx.check(st.bloc_fini and st.bloc_fini - T_F <= 330, "F : 1 000 machines au lot 10 apres le balayage (<= 330 ticks)",
      tostring(st.bloc_fini) .. " (modules poses au tick " .. T_F .. ")")
    local n1 = 0
    for k = 1, 100 do
      local r = st.bloc[k].get_recipe()
      if r and r.name == "iron-gear-wheel" then n1 = n1 + 1 end
    end
    ctx.check(n1 == 100, "F : 100 machines sans modules revenues au lot 1", n1)
    local stats = remote.call("fo-lots", "stats")
    ctx.log("STATS " .. serpent.line(stats))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if st.a then add("A-lot100-alt", st.a.m.position.x, st.a.m.position.y, 1, 0, { info = true }) end
    if st.c1 then add("C1-beton-alt", st.c1.m.position.x, st.c1.m.position.y, 1, 0, { info = true }) end
    if st.e then add("E-acide-alt", st.e.m.position.x, st.e.m.position.y, 1, 0, { info = true }) end
  end,
}
