--[[
  Scénario GREFFÉ « x2-usine » (lot X2, 25/10) : une PETITE USINE de la bobine supraconductrice (monnaie de l'âge 12),
  posée une fois avec de vrais bras, un vrai tapis et de vrais tuyaux, puis LAISSÉE TOURNER 10 min de jeu sans AUCUN
  transfert par script (défaut du lot X1 : la chaîne du titane n'avait été jouée qu'à transferts par script).

  Lancement : & "<racine>\fo-autotest.bat" nopause 38000 x2-usine "<source>"   (contrôle final au tick 37 800)
  Images    : & "<racine>\fo-captures.bat" x2-usine "<source>"

  Pose (tick 0, puis plus rien) :
  - un gisement de monazite de 11 × 5 tuiles (vrai prototype fo-monazite), 3 foreuses électriques qui déposent sur un
    tapis ; le tapis mène au concentrateur (bras) ;
  - concentrateur → bras → usine chimique (lessivage, acide sulfurique d'un réservoir) → bras → colonne d'extraction
    (huile légère d'un réservoir) → bras → four de frittage (ruban : yttrium, cuivre d'un coffre, oxygène par tuyau) →
    bras → bobineuse (azote liquide par tuyau, cryostat d'un assembleur 3) → bras → coffre des bobines ;
  - électrolyseur (eau d'un réservoir → hydrogène, oxygène) ; unité cryogénique (air → azote liquide, oxygène liquide) ;
  - sous-produits : oxyde de thorium et néodyme sortis par des bras filtrants dans des coffres ; hydrogène et oxygène
    liquide dans des réservoirs (aucun débouché en jeu : dit dans le bilan) ;
  - entrées posées une fois : acide, huile légère, eau (réservoirs), cuivre, titane, plastique, processeurs (coffres).
  Contrôles : géométrie (chaque bras prend et pose où il faut, chaque tuyau relie la bonne boîte), bobines produites par
  tranche de 2 min (aucun arrêt), total sur 10 min, état final de chaque machine, sous-produits sans débouché.
]]

local FX, FY = 4200, 3600
local T0, CHECK = 60, 37800
local WINDOW = 7200                       -- tranche de contrôle : 2 min de jeu
local START = 600                         -- début du décompte (10 min = 36 000 ticks à partir de là)

local function P(x, y) return { FX + x, FY + y } end

local function by_status()
  local t = {}
  for k, v in pairs(defines.entity_status) do t[v] = k end
  return t
end

--- Bras de `kind` en (x, y) qui prend dans `from` et pose dans `to` : la direction est CHERCHÉE (les 4 essayées) et
--- contrôlée par les positions de prise et de dépose (dans la boîte de l'entité visée).
local function inside(e, pos)
  if not (e and e.valid) then return false end
  local b = e.bounding_box
  return pos.x >= b.left_top.x - 0.01 and pos.x <= b.right_bottom.x + 0.01 and pos.y >= b.left_top.y - 0.01 and pos.y <= b.right_bottom.y + 0.01
end

local function bras(s, kind, x, y, from, to)
  for _, d in ipairs({ defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west }) do
    local ins = s.create_entity({ name = kind, position = P(x, y), force = "player", direction = d })
    if ins then
      if inside(from, ins.pickup_position) and inside(to, ins.drop_position) then return ins end
      ins.destroy()
    end
  end
  return nil
end

local function tuyaux(s, list)
  local n = 0
  for _, p in ipairs(list) do
    if s.create_entity({ name = "pipe", position = P(p[1], p[2]), force = "player" }) then n = n + 1 end
  end
  return n
end

local function ligne(x0, x1, y)
  local t = {}
  local step = x1 >= x0 and 1 or -1
  for x = x0, x1, step do t[#t + 1] = { x, y } end
  return t
end
local function colonne(x, y0, y1)
  local t = {}
  local step = y1 >= y0 and 1 or -1
  for y = y0, y1, step do t[#t + 1] = { x, y } end
  return t
end

local function fluid_in(e, name)
  if not (e and e.valid) then return 0 end
  return e.get_fluid_count(name)
end

return {
  description = "x2-usine : petite usine de la bobine supraconductrice, vrais bras, tapis et tuyaux, 10 min sans transfert par script",
  check_tick = CHECK,
  shots_delay = 2400,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    local f = game.forces.player
    f.technologies["fo-cryostat"].researched = true
    f.technologies["fo-superconductors"].researched = true
    ctx.prepare_area(FX - 36, FY - 20, FX + 14, FY + 10, "grass-1")
    for _, e in ipairs(s.find_entities_filtered({ area = { { FX - 120, FY - 120 }, { FX + 120, FY + 120 } }, force = "enemy" })) do e.destroy() end
    -- Gisement de monazite (tuiles x -32..-22, y -1..3) : sol des sables noirs, puis les ressources (F135).
    local tiles = {}
    for x = -33, -21 do for y = -2, 4 do tiles[#tiles + 1] = { name = "fo-black-sands", position = P(x, y) } end end
    s.set_tiles(tiles)
    local ore = 0
    for x = -32, -22 do
      for y = -1, 3 do
        if s.create_entity({ name = "fo-monazite", position = P(x + 0.5, y + 0.5), amount = 3000 }) then ore = ore + 1 end
      end
    end
    -- Machines (toutes vers le nord).
    local function machine(name, x, y, recipe)
      local e = s.create_entity({ name = name, position = P(x, y), force = "player", raise_built = true })
      if e and recipe then e.set_recipe(recipe) end
      return e
    end
    local m = {
      conc = machine("fo-ore-concentrator", -18, 0, "fo-monazite-concentrate"),
      leach = machine("chemical-plant", -14.5, 0.5, "fo-monazite-leaching"),
      extr = machine("fo-extraction-column", -10.5, 0.5, "fo-solvent-extraction"),
      sint = machine("fo-sintering-furnace", -6.5, 0.5, "fo-superconducting-tape"),
      wind = machine("fo-coil-winder", -3, 0, "fo-superconducting-coil"),
      cryo = machine("assembling-machine-3", -2.5, 3.5, "fo-cryostat"),
      elec = machine("fo-electrolyzer", -7.5, -10.5, "fo-water-electrolysis"),
      air = machine("fo-cryogenic-unit", 4.5, -6.5, "fo-air-distillation"),
    }
    st.m = m
    local missing = {}
    for _, k in ipairs({ "conc", "leach", "extr", "sint", "wind", "cryo", "elec", "air" }) do
      if not (m[k] and m[k].valid and m[k].get_recipe()) then missing[#missing + 1] = k end
    end
    ctx.check(#missing == 0 and ore == 55, "pose : 8 machines avec leur recette, gisement de 55 tuiles de monazite",
      #missing > 0 and table.concat(missing, ", ") or nil)
    -- Foreuses (nord : dépose sur le tapis en y = -0,5) et tapis vers l'est.
    st.drills = {}
    for _, x in ipairs({ -29.5, -26.5, -23.5 }) do
      st.drills[#st.drills + 1] = s.create_entity({ name = "electric-mining-drill", position = P(x, 1.5), force = "player",
        direction = defines.direction.north })
    end
    local belts = 0
    for x = -31.5, -20.5 do
      if s.create_entity({ name = "transport-belt", position = P(x, -0.5), force = "player", direction = defines.direction.east }) then
        belts = belts + 1
      end
    end
    local belt_end = s.find_entity("transport-belt", P(-20.5, -0.5))
    -- Coffres.
    local function coffre(x, y, items)
      local c = s.create_entity({ name = "steel-chest", position = P(x, y), force = "player" })
      for _, it in ipairs(items or {}) do c.insert({ name = it[1], count = it[2] }) end
      return c
    end
    st.c = {
      thorium = coffre(-14.5, 3.5),
      neodymium = coffre(-10.5, 3.5),
      copper = coffre(-6.5, 3.5, { { "copper-plate", 400 } }),
      cryo_in = coffre(-2.5, 6.5, { { "fo-titanium-plate", 80 }, { "plastic-bar", 160 }, { "processing-unit", 80 } }),
      coils = coffre(-0.5, -0.5),
    }
    -- Bras (rapides ; filtrants pour les sous-produits).
    local B = {}
    B.belt_conc = bras(s, "fast-inserter", -19.5, -0.5, belt_end, m.conc)
    B.conc_leach = bras(s, "fast-inserter", -16.5, -0.5, m.conc, m.leach)
    B.leach_extr = bras(s, "fast-inserter", -12.5, 0.5, m.leach, m.extr)
    B.leach_th = bras(s, "filter-inserter", -14.5, 2.5, m.leach, st.c.thorium)
    B.extr_sint = bras(s, "fast-inserter", -8.5, 0.5, m.extr, m.sint)
    B.extr_nd = bras(s, "filter-inserter", -10.5, 2.5, m.extr, st.c.neodymium)
    B.cu_sint = bras(s, "fast-inserter", -6.5, 2.5, st.c.copper, m.sint)
    B.sint_wind = bras(s, "fast-inserter", -4.5, -0.5, m.sint, m.wind)
    B.cryo_wind = bras(s, "fast-inserter", -2.5, 1.5, m.cryo, m.wind)
    B.in_cryo = bras(s, "fast-inserter", -2.5, 5.5, st.c.cryo_in, m.cryo)
    B.wind_out = bras(s, "fast-inserter", -1.5, -0.5, m.wind, st.c.coils)
    if B.leach_th then B.leach_th.set_filter(1, "fo-thorium-oxide") end
    if B.extr_nd then B.extr_nd.set_filter(1, "fo-neodymium") end
    st.B = B
    local bad = {}
    for _, k in ipairs({ "belt_conc", "conc_leach", "leach_extr", "leach_th", "extr_sint", "extr_nd", "cu_sint", "sint_wind",
      "cryo_wind", "in_cryo", "wind_out" }) do
      if not B[k] then bad[#bad + 1] = k end
    end
    ctx.check(#bad == 0 and #st.drills == 3 and belts == 12,
      "11 bras posés, chacun prenant et posant dans la bonne entité ; 3 foreuses, 12 tapis", #bad > 0 and table.concat(bad, ", ") or nil)
    -- Réservoirs (entrées remplies à la pose, sous-produits vides).
    local function reservoir(x, y, fluid, amount)
      local t = s.create_entity({ name = "storage-tank", position = P(x, y), force = "player" })
      if t and fluid then t.insert_fluid({ name = fluid, amount = amount }) end
      return t
    end
    st.t = {
      acid = reservoir(-16.5, -5.5, "sulfuric-acid", 10000),
      oil = reservoir(-11.5, -5.5, "light-oil", 5000),
      water = reservoir(-8.5, -15.5, "water", 20000),
      h2 = reservoir(-24.5, -9.5),
      lox = reservoir(3.5, -14.5),
    }
    -- Tuyaux.
    local np = 0
    np = np + tuyaux(s, colonne(-15.5, -1.5, -3.5))                       -- acide → lessivage
    np = np + tuyaux(s, colonne(-10.5, -1.5, -3.5))                       -- huile légère → colonne
    np = np + tuyaux(s, colonne(-7.5, -12.5, -13.5))                      -- eau → électrolyseur
    np = np + tuyaux(s, colonne(-6.5, -8.5, -1.5))                        -- oxygène → four de frittage
    np = np + tuyaux(s, ligne(-8.5, -22.5, -8.5))                         -- hydrogène → réservoir
    np = np + tuyaux(s, { { 2.5, -9.5 } })                                -- azote liquide : sortie
    np = np + tuyaux(s, ligne(2.5, -3.5, -10.5))                          -- azote liquide → ouest
    np = np + tuyaux(s, colonne(-3.5, -9.5, -1.5))                        -- azote liquide → bobineuse
    np = np + tuyaux(s, colonne(4.5, -9.5, -12.5))                        -- oxygène liquide → réservoir
    st.pipes = np
    ctx.check(np == 3 + 3 + 2 + 8 + 15 + 1 + 7 + 9 + 4, "52 tuyaux posés", np)
    ctx.power(FX + 10.5, FY + 5.5)
    st.samples = {}
    st.log = {}
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.m then return end
    if e.tick == T0 then
      -- Géométrie des fluides : chaque machine voit l'entité attendue sur la bonne boîte (relu au moteur).
      local function linked(ent, idx, other)
        if not (ent and ent.valid) then return false end
        for _, c in ipairs(ent.fluidbox.get_connections(idx)) do
          if c.owner == other then return true end
        end
        return false
      end
      local function pipe_at(x, y) return ctx.surface().find_entity("pipe", P(x, y)) end
      local m, t = st.m, st.t
      local links = {
        { "lessivage : acide", linked(m.leach, 1, pipe_at(-15.5, -1.5)) },
        { "colonne : huile légère", linked(m.extr, 1, pipe_at(-10.5, -1.5)) },
        { "électrolyseur : eau", linked(m.elec, 1, pipe_at(-7.5, -12.5)) },
        { "électrolyseur : hydrogène (sortie 1)", linked(m.elec, 2, pipe_at(-8.5, -8.5)) },
        { "électrolyseur : oxygène (sortie 2)", linked(m.elec, 3, pipe_at(-6.5, -8.5)) },
        { "four de frittage : oxygène", linked(m.sint, 1, pipe_at(-6.5, -1.5)) },
        { "unité cryogénique : azote liquide (sortie 1)", linked(m.air, 3, pipe_at(2.5, -9.5)) },
        { "unité cryogénique : oxygène liquide (sortie 2)", linked(m.air, 4, pipe_at(4.5, -9.5)) },
        { "bobineuse : azote liquide", linked(m.wind, 1, pipe_at(-3.5, -1.5)) },
        { "réservoir d'acide", linked(t.acid, 1, pipe_at(-15.5, -3.5)) },
        { "réservoir d'huile", linked(t.oil, 1, pipe_at(-10.5, -3.5)) },
        { "réservoir d'eau", linked(t.water, 1, pipe_at(-7.5, -13.5)) },
        { "réservoir d'hydrogène", linked(t.h2, 1, pipe_at(-22.5, -8.5)) },
        { "réservoir d'oxygène liquide", linked(t.lox, 1, pipe_at(4.5, -12.5)) },
      }
      local bad = {}
      for _, l in ipairs(links) do if not l[2] then bad[#bad + 1] = l[1] end end
      st.links_bad = bad
      ctx.check(#bad == 0, "tuyaux : les 14 liaisons de fluide attendues existent au moteur", #bad > 0 and table.concat(bad, " ; ") or nil)
      return
    end
    if e.tick >= START and (e.tick - START) % WINDOW == 0 and e.tick <= START + 36000 then
      local c = st.c.coils.valid and st.c.coils.get_item_count("fo-superconducting-coil") or 0
      st.samples[#st.samples + 1] = { tick = e.tick, coils = c, made = st.m.wind.valid and st.m.wind.products_finished or 0 }
      ctx.log(string.format("tick %d : bobines au coffre %d (bobineuse : %d finies)", e.tick, c, st.samples[#st.samples].made))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.m then return end
    local m, c, t = st.m, st.c, st.t
    local sn = by_status()
    -- Production sur 10 min, par tranches de 2 min.
    local S = st.samples
    ctx.check(#S == 6, "6 relevés (début, puis toutes les 2 min sur 10 min)", #S)
    local per, stall = {}, false
    for i = 2, #S do
      local d = S[i].coils - S[i - 1].coils
      per[#per + 1] = tostring(d)
      if d <= 0 then stall = true end
    end
    local total = #S >= 2 and (S[#S].coils - S[1].coils) or 0
    ctx.check(not stall and #S == 6, "aucun arrêt : des bobines sortent dans CHAQUE tranche de 2 min", table.concat(per, ", "))
    ctx.check(total >= 30, "au moins 30 bobines en 10 min de jeu, sans transfert par script après la pose",
      string.format("%d bobines (de %d à %d au coffre)", total, S[1] and S[1].coils or -1, S[#S] and S[#S].coils or -1))
    local last = #S >= 2 and (S[#S].coils - S[#S - 1].coils) or 0
    local first = #S >= 2 and (S[2].coils - S[1].coils) or 0
    ctx.check(last >= 0.8 * first and last > 0, "débit tenu : la dernière tranche vaut au moins 80 % de la première",
      string.format("%d puis %d", first, last))
    -- Matières de la chaîne : relevées, sous-produits comptés.
    local mined = m.conc.valid and m.conc.products_finished or 0
    ctx.check(mined >= 1, "concentrateur : concentré fait à partir de la monazite minée et convoyée", mined)
    local th, nd = c.thorium.get_item_count("fo-thorium-oxide"), c.neodymium.get_item_count("fo-neodymium")
    local h2, lox = fluid_in(t.h2, "fo-hydrogen"), fluid_in(t.lox, "fo-liquid-oxygen")
    ctx.check(th >= 1 and nd >= 1, "sous-produits solides sortis par bras filtrants (rien ne bloque la chaîne)",
      string.format("oxyde de thorium %d, néodyme %d", th, nd))
    ctx.log(string.format("SOUS-PRODUITS SANS DÉBOUCHÉ EN JEU (stockés) : oxyde de thorium %d, néodyme %d (aimants seulement), hydrogène %.0f, oxygène liquide %.0f",
      th, nd, h2, lox))
    ctx.log(string.format("ENTRÉES RESTANTES : acide %.0f, huile légère %.0f, eau %.0f, cuivre %d, titane %d, plastique %d, processeurs %d",
      fluid_in(t.acid, "sulfuric-acid"), fluid_in(t.oil, "light-oil"), fluid_in(t.water, "water"),
      c.copper.get_item_count("copper-plate"), c.cryo_in.get_item_count("fo-titanium-plate"), c.cryo_in.get_item_count("plastic-bar"),
      c.cryo_in.get_item_count("processing-unit")))
    for _, k in ipairs({ "conc", "leach", "extr", "sint", "wind", "cryo", "elec", "air" }) do
      local e = m[k]
      if e and e.valid then
        local fb = {}
        for i = 1, #e.fluidbox do
          local fl = e.fluidbox[i]
          fb[#fb + 1] = i .. ":" .. (fl and (fl.name .. " " .. string.format("%.0f", fl.amount)) or "-")
        end
        ctx.log(string.format("machine %s (%s) : statut %s, %d fabrication(s) ; fluides [%s]", k, e.name,
          tostring(sn[e.status]), e.products_finished, table.concat(fb, " ")))
      end
    end
    local d_ok = 0
    for _, d in ipairs(st.drills) do if d.valid and d.status ~= defines.entity_status.no_minable_resources then d_ok = d_ok + 1 end end
    ctx.check(d_ok == 3, "3 foreuses toujours sur la monazite à la fin", d_ok)
  end,

  shots = function(ctx, add)
    local opt = { aa = false }
    add("usine-z05-jour", FX - 10, FY - 4, 0.5, 0, opt)
    add("usine-chaine-z1-jour", FX - 10, FY + 0.5, 1, 0, opt)
    add("usine-fluides-z1-jour", FX - 4, FY - 8, 1, 0, opt)
    add("usine-gisement-z1-jour", FX - 26, FY + 1, 1, 0, opt)
    add("usine-gisement-z1-nuit", FX - 26, FY + 1, 1, 0.5, opt)
  end,
}
