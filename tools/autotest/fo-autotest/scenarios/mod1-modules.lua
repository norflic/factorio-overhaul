-- Scénario greffé du lot MOD-1 (24/10) : modules MULTIPLICATIFS sur le mod LIVRÉ (décision D-15 du DC).
--   & "<racine>\fo-autotest.bat" nopause 2200 mod1-modules "<source>"
--   py -3.9 tools/autotest/mod1/analyse.py "<racine>\fo-autotest"        (coûts, temps par tick des fenêtres)
--   & "<racine>\fo-captures.bat" mod1-modules "<source>"                   (interfaces : x-mod1-gui-*.png)
--
-- Attendus calculés ICI, indépendamment du mod, en flottants : vitesse × Π (1 + b), énergie × Π (1 + c), sur les
-- modules de la machine (table VAL ci-dessous = décision du DC : +50, +80, +110 % puis +30 points ; énergie 60 % du
-- bonus ; productivité et efficacité gardées), arrondis au centième, bornés à × 0,2 et × 328,67 ; balise du joueur
-- en plus (additive : 0,5 × somme de ses modules).
--
-- Cellules (24 tuiles d'écart, CHACUNE son réseau : poteau moyen + interface électrique vanilla remise pleine à chaque
-- tick, énergie prise comptée) ; fenêtre de mesure : ticks 600 à 1199 (10 s) ; produits retirés à chaque tick :
--   1, 3, 5 et 14 modules de paliers variés, avec et sans balise de joueur voisine ; plafond (34 × palier 10) ;
--   machine mixte (productivité, efficacité) ; foreuse, four, laboratoire ; grille 3 × 3 de machines COLLÉES
--   (voisines intactes). Zone K : amélioration de niveau 6 → 7 (agrandissement par script) → 8 (remplacement rapide).
--   Zone L : robots qui livrent des modules (aucun événement : balayage). Zone M : 1 000 machines (temps de script).
-- Le BILAN compte les contrôles ; « MESURE » donne les chiffres.

local NOM = "mod1-modules"
local X0, Y0, PAS, COLS = 4000.5, 4000.5, 24, 6
local WA, WB = 600, 1200
local CAP = 1e8                         -- J par tick par cellule (6 GW) ; MOD-0 O-1 : jamais 1e13
local MX, MY, MCOLS, MN = 4400.5, 4000.5, 34, 1000
local LX, LY = 4400.5, 4200.5
local KX, KY = 4200.5, 4300.5
local T_UP1, T_UP2 = 400, 420
local T_BLOC = 1300
local T_PROF = 2000
local T_GUI = 700
local CHECK = 2100
local KFORCE = "mod1-up"

-- Effets VOULUS par module (fractions) : décision du DC (vitesse) et valeurs gardées (productivité, efficacité).
local VAL = {}
do
  local names = { "speed-module", "speed-module-2", "speed-module-3" }
  for k = 1, 10 do
    local b = 0.5 + 0.3 * (k - 1)
    VAL[k <= 3 and names[k] or ("fo-speed-module-" .. k)] = { speed = b, consumption = 0.6 * b }
  end
  local pn = { "productivity-module", "productivity-module-2", "productivity-module-3" }
  local pp = { 0.04, 0.06, 0.10 }
  local ps = { -0.05, -0.10, -0.15 }
  local pc = { 0.40, 0.60, 0.80 }
  for k = 1, 3 do VAL[pn[k]] = { productivity = pp[k], speed = ps[k], consumption = pc[k] } end
  local en = { "effectivity-module", "effectivity-module-2", "effectivity-module-3" }
  local ec = { -0.30, -0.40, -0.50 }
  for k = 1, 3 do VAL[en[k]] = { consumption = ec[k] } end
end

local function rep(name, n)
  local t = {}
  for _ = 1, n do t[#t + 1] = name end
  return t
end

local S1, S2, S3 = "speed-module", "speed-module-2", "speed-module-3"
local CELLS = {
  { id = "A-temoin", m = "assembling-machine-2", rec = "iron-gear-wheel", mods = {} },
  { id = "B-1-module", m = "assembling-machine-2", rec = "iron-gear-wheel", mods = { S1 } },
  { id = "C-3-paliers", m = "assembling-machine-2", rec = "iron-gear-wheel", mods = { S1, S2, S3 } },
  { id = "C2-3-paliers+balise", m = "assembling-machine-2", rec = "iron-gear-wheel", mods = { S1, S2, S3 }, vbal = { S3, S3 } },
  { id = "D-5-paliers", m = "assembling-machine-2", rec = "iron-gear-wheel", mods = { S1, S2, S3, "fo-speed-module-4", "fo-speed-module-5" } },
  { id = "E-14-palier1", m = "fo-lvl-assembler-30", rec = "low-density-structure", mods = rep(S1, 14) },
  { id = "E2-14-palier1+balise", m = "fo-lvl-assembler-30", rec = "low-density-structure", mods = rep(S1, 14), vbal = { S3, S3 } },
  { id = "F-plafond-34-palier10", m = "fo-lvl-assembler-30", rec = "low-density-structure", mods = rep("fo-speed-module-10", 34) },
  { id = "G-mixte", m = "assembling-machine-2", rec = "iron-gear-wheel",
    mods = { S3, S3, "productivity-module-3", "effectivity-module-3", "effectivity-module" } },
  { id = "J1-foreuse", m = "electric-mining-drill", mods = { S1, S2, "productivity-module" }, foreuse = true },
  { id = "J2-four", m = "electric-furnace", rec = "iron-plate", mods = { S3, S3 }, four = true },
  { id = "J3-labo", m = "lab", mods = { S1, S1 }, labo = true },
}
-- Grille 3 × 3 de machines COLLÉES (cellule V, 3 tuiles d'écart) : centre 3 modules (balise), côtés 1 module (pas de
-- balise), coins 2 modules (balise à eux).
local GRID = {}
for _, dy in ipairs({ -3, 0, 3 }) do
  for _, dx in ipairs({ -3, 0, 3 }) do
    local mods
    if dx == 0 and dy == 0 then mods = { S3, S3, S3 }
    elseif dx == 0 or dy == 0 then mods = { S1 }
    else mods = { S2, S2 } end
    GRID[#GRID + 1] = { dx = dx, dy = dy, mods = mods }
  end
end

---------------------------------------------------------------------------------------------------
-- Attendus
---------------------------------------------------------------------------------------------------
local function round(x) return math.floor(x + 0.5) end
local function clampT(t) if t < 20 then return 20 end if t > 32867 then return 32867 end return t end

--- Facteurs voulus (centièmes) et produits exacts (flottants) d'une liste de modules.
local function attendu(mods)
  local ps, pc, prod = 1, 1, 0
  local any_s, any_c = false, false
  for _, n in ipairs(mods) do
    local v = VAL[n]
    if v.speed then ps = ps * math.max(0.2, 1 + v.speed); any_s = true end
    if v.consumption then pc = pc * math.max(0.2, 1 + v.consumption); any_c = true end
    if v.productivity then prod = prod + v.productivity end
  end
  return { ts = clampT(round(ps * 100)), tc = clampT(round(pc * 100)), ps = ps, pc = pc, prod = prod }
end

--- Effet d'une balise vanilla (efficacité de distribution 0,5) sur une machine.
local function balise(vmods)
  local s, c = 0, 0
  for _, n in ipairs(vmods or {}) do
    s = s + 0.5 * (VAL[n].speed or 0)
    c = c + 0.5 * (VAL[n].consumption or 0)
  end
  return s, c
end

local function f6(v) if v == nil then return "nil" end return string.format("%.6g", v) end

local function lit(e, k)
  local ok, v = pcall(function() return e[k] end)
  if ok then return v end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Pose
---------------------------------------------------------------------------------------------------
--- Réseau d'une cellule : poteau moyen à gauche de la boîte, interface électrique vanilla à sa gauche.
local function reseau(s, bb, cy)
  local px = math.floor(bb.left_top.x) - 0.5
  local py = math.floor(cy) + 0.5
  local pole = s.create_entity({ name = "medium-electric-pole", position = { px, py }, force = "player" })
  local src = s.create_entity({ name = "electric-energy-interface", position = { px - 1.5, py + 0.5 }, force = "player" })
  if src then
    src.electric_buffer_size = CAP
    src.power_production = 0
    src.power_usage = 0
    src.energy = CAP
  end
  return pole, src
end

local function inserer(m, mods)
  local inv = m.get_module_inventory()
  local n = 0
  for _, nm in ipairs(mods) do n = n + (inv and inv.insert({ name = nm, count = 1 }) or 0) end
  return n
end

local function nourrir(m, rec)
  if rec == "iron-gear-wheel" then
    local inv = m.get_inventory(defines.inventory.assembling_machine_input)
    local k = inv.get_item_count("iron-plate")
    if k < 100 then inv.insert({ name = "iron-plate", count = 100 - k }) end
  elseif rec == "low-density-structure" then
    local inv = m.get_inventory(defines.inventory.assembling_machine_input)
    for _, it in ipairs({ "copper-plate", "steel-plate", "plastic-bar" }) do
      local k = inv.get_item_count(it)
      if k < 100 then inv.insert({ name = it, count = 100 - k }) end
    end
  elseif rec == "iron-plate" then
    local inv = m.get_inventory(defines.inventory.furnace_source)
    local k = inv.get_item_count("iron-ore")
    if k < 40 then inv.insert({ name = "iron-ore", count = 50 - k }) end
  end
end

local function poser_cellule(s, spec, x, y)
  local c = { id = spec.id, spec = spec, x = x, y = y, e = 0, items = 0, ok = true }
  if spec.foreuse then
    for tx = -3, 3 do
      for ty = -3, 3 do s.create_entity({ name = "iron-ore", position = { x + tx, y + ty }, amount = 100000000 }) end
    end
  end
  local m = s.create_entity({ name = spec.m, position = { x, y }, force = "player", raise_built = true })
  c.m = m
  if not m then c.ok = false return c end
  if spec.rec and m.type == "assembling-machine" then m.set_recipe(spec.rec) end
  c.pole, c.src = reseau(s, m.bounding_box, m.position.y)
  if spec.foreuse then
    c.coffre = s.create_entity({ name = "iron-chest", position = m.drop_position, force = "player" })
  end
  if spec.labo then
    m.insert({ name = "automation-science-pack", count = 200 })
  end
  c.mis = inserer(m, spec.mods)
  if c.mis ~= #spec.mods then c.ok = false end
  if spec.vbal then
    local bb = m.bounding_box
    local vb = s.create_entity({ name = "beacon", position = { math.floor(bb.right_bottom.x) + 1.5, math.floor(m.position.y) + 0.5 },
      force = "player" })
    c.vbal = vb
    if vb then
      for _, nm in ipairs(spec.vbal) do vb.get_module_inventory().insert({ name = nm, count = 1 }) end
      local p2 = s.create_entity({ name = "medium-electric-pole", position = { vb.position.x, vb.position.y + 2 }, force = "player" })
      if p2 and c.pole then p2.connect_neighbour(c.pole) end
      c.pole2 = p2
    else
      c.ok = false
    end
  end
  return c
end

local function poser_grille(s, x, y)
  local c = { id = "V-grille-collee", x = x, y = y, e = 0, items = 0, ok = true, grille = {} }
  for _, g in ipairs(GRID) do
    local m = s.create_entity({ name = "assembling-machine-2", position = { x + g.dx, y + g.dy }, force = "player", raise_built = true })
    if m then
      m.set_recipe("iron-gear-wheel")
      local mis = inserer(m, g.mods)
      c.grille[#c.grille + 1] = { m = m, mods = g.mods, mis = mis, dx = g.dx, dy = g.dy }
      if mis ~= #g.mods then c.ok = false end
    else
      c.ok = false
    end
  end
  -- Réseau : une sous-station à l'ouest (zone 18 × 18 : couvre les trois colonnes collées), fils retirés (aucun lien
  -- avec une autre cellule), interface électrique dans sa zone.
  local sub = s.create_entity({ name = "substation", position = { x - 6.5, y }, force = "player" })
  if sub then pcall(function() sub.disconnect_neighbour() end) end
  local src = s.create_entity({ name = "electric-energy-interface", position = { x - 9.5, y + 3 }, force = "player" })
  if src then
    src.electric_buffer_size = CAP
    src.power_production = 0
    src.power_usage = 0
    src.energy = CAP
  end
  c.src = src
  return c
end

---------------------------------------------------------------------------------------------------
-- Zones K (niveau), L (robots), M (1 000 machines)
---------------------------------------------------------------------------------------------------
local function make_force(name)
  local f = game.forces[name] or game.create_force(name)
  for _, other in ipairs({ "player", "enemy" }) do
    f.set_cease_fire(other, true)
    game.forces[other].set_cease_fire(f, true)
  end
  return f
end

local LV
do
  local ok, res = pcall(require, "__factorio-overhaul__/shared/levels/config")
  if ok then LV = res end
end

local function poser_k(ctx, s, st)
  ctx.prepare_area(KX - 30, KY - 20, KX + 30, KY + 20, "grass-1")
  local f = make_force(KFORCE)
  f.recipes["iron-gear-wheel"].enabled = true
  local cc = s.create_entity({ name = LV.name(LV.by_key.command, 15), position = { KX - 16, KY }, force = f, raise_built = true })
  ctx.power(KX, KY, f)
  local a = s.create_entity({ name = LV.name(LV.by_key.assembler, 6), position = { KX + 6, KY }, force = f, raise_built = true })
  if a then
    a.set_recipe("iron-gear-wheel")
    st.k_mis = inserer(a, { S1, S1, S1, S2, S2, S2 })
  end
  if cc then
    local inv = cc.get_inventory(defines.inventory.chest)
    for _, n in ipairs({ 7, 8 }) do
      for _, cst in ipairs(LV.cost(LV.by_key.assembler, n)) do inv.insert({ name = cst[1], count = cst[2] }) end
    end
  end
  st.k = { cc = cc, a = a }
  ctx.check(cc ~= nil and a ~= nil and st.k_mis == 6, "K : centre 15, assembleur niveau 6 avec 6 modules (force a part)",
    tostring(a and a.name) .. ", modules " .. tostring(st.k_mis))
end

local function poser_l(ctx, s, st)
  ctx.prepare_area(LX - 40, LY - 30, LX + 40, LY + 30, "grass-1")
  ctx.power(LX, LY)
  local z = {}
  z.rp = s.create_entity({ name = "roboport", position = { LX - 0.5, LY - 0.5 }, force = "player" })
  if z.rp then z.rp.insert({ name = "construction-robot", count = 20 }) end
  z.stock = s.create_entity({ name = "logistic-chest-storage", position = { LX + 3, LY }, force = "player" })
  if z.stock then
    z.stock.insert({ name = S2, count = 20 })
    z.stock.insert({ name = S3, count = 20 })
    z.stock.insert({ name = "assembling-machine-2", count = 2 })
  end
  z.m1 = s.create_entity({ name = "assembling-machine-2", position = { LX - 8.5, LY + 8.5 }, force = "player", raise_built = true })
  if z.m1 then z.m1.set_recipe("iron-gear-wheel") end
  z.ghost_pos = { LX + 8.5, LY + 8.5 }
  st.z = z
  ctx.check(z.rp and z.stock and z.m1 and true or false, "L : roboport, stock de modules, machine posee")
end

local function actions_l(ctx, s, st)
  local z = st.z
  local proxy = s.create_entity({ name = "item-request-proxy", position = z.m1.position, force = "player",
    target = z.m1, modules = { [S2] = 5 } })
  local g = s.create_entity({ name = "entity-ghost", inner_name = "assembling-machine-2", position = z.ghost_pos,
    force = "player", expires = false })
  if g then pcall(function() g.item_requests = { [S3] = 3 } end) end
  ctx.check(proxy ~= nil and g ~= nil, "L : demande de 5 modules (proxy) et fantome avec 3 modules poses", "tick " .. game.tick)
end

local function poser_m(ctx, s, st)
  local rows = math.ceil(MN / MCOLS)
  ctx.prepare_area(MX - 6, MY - 6, MX + MCOLS * 3 + 4, MY + rows * 3 + 4, "grass-1")
  ctx.power(MX + MCOLS * 1.5, MY + rows * 1.5)
  st.bloc = {}
  local p = game.create_profiler()
  for i = 1, MN do
    local x = MX + ((i - 1) % MCOLS) * 3
    local y = MY + math.floor((i - 1) / MCOLS) * 3
    local m = s.create_entity({ name = "assembling-machine-2", position = { x, y }, force = "player", raise_built = true })
    if m then st.bloc[#st.bloc + 1] = m end
  end
  p.stop()
  log({ "", "[FO-MOD1-MODULES] COUT\tpose de 1 000 machines (create_entity raise_built, suivi compris)\tn=", tostring(MN), "\t", p })
  ctx.check(#st.bloc == MN, "M : 1 000 machines collees posees (raise_built)", #st.bloc .. " / " .. MN)
end

---------------------------------------------------------------------------------------------------
-- Contrôles d'une machine contre l'attendu
---------------------------------------------------------------------------------------------------
local function etat(e)
  local ok, r = pcall(remote.call, "fo-modules", "state", e)
  if ok then return r end
  return nil
end

local function balises_cachees(s, e)
  local bb = e.bounding_box
  return s.count_entities_filtered({ name = "fo-mm-balise", area = { { bb.left_top.x, bb.left_top.y }, { bb.right_bottom.x, bb.right_bottom.y } } })
end

--- Bonus relus contre l'attendu (centième exact). Renvoie ok, texte.
local function bonus_ok(e, mods, vmods)
  local a = attendu(mods)
  local bs, bc = balise(vmods)
  local want_s = (a.ts - 100) / 100 + bs
  local want_c = (a.tc - 100) / 100 + bc
  if want_s > 327.67 then want_s = 327.67 end
  if want_c > 327.67 then want_c = 327.67 end
  local sb, cb = lit(e, "speed_bonus") or -99, lit(e, "consumption_bonus") or -99
  local ok = math.abs(sb - want_s) < 0.005 and math.abs(cb - want_c) < 0.005
  return ok, string.format("speed_bonus %s (attendu %s ; produit %s) ; consumption_bonus %s (attendu %s ; produit %s)",
    f6(sb), f6(want_s), f6(a.ps), f6(cb), f6(want_c), f6(a.pc)), a, want_s, want_c
end

return {
  description = "MOD-1 : modules multiplicatifs (vitesse et energie mesurees contre la formule, plafond, voisines, niveau, robots, 1 000 machines)",
  base = nil,
  check_tick = CHECK,
  shots_delay = 800,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    game.map_settings.enemy_expansion.enabled = false
    for _, r in ipairs({ "iron-gear-wheel", "low-density-structure", "iron-plate" }) do
      if game.forces.player.recipes[r] then game.forces.player.recipes[r].enabled = true end
    end
    ctx.check(ctx.has("fo-modules", "state"), "interface fo-modules presente (mod MOD-1)")
    -- Prototypes tels que le moteur les a chargés.
    local slots = {}
    for _, n in ipairs({ "assembling-machine-2", "electric-mining-drill", "fo-lvl-assembler-2", "fo-lvl-assembler-30",
      "fo-lvl-drill-30", "fo-lvl-furnace-30", "assembling-machine-3", "electric-furnace", "lab" }) do
      local p = game.entity_prototypes[n]
      slots[#slots + 1] = n .. "=" .. tostring(p and p.module_inventory_size)
    end
    ctx.log("PROTO emplacements : " .. table.concat(slots, " ; "))
    local sl = function(n) local p = game.entity_prototypes[n] return p and p.module_inventory_size end
    ctx.check(sl("assembling-machine-2") == 5 and sl("electric-mining-drill") == 5 and sl("fo-lvl-assembler-2") == 6
      and sl("fo-lvl-assembler-30") == 34 and sl("fo-lvl-drill-30") == 34 and (sl("fo-lvl-furnace-30") or 0) == 0,
      "emplacements : 5 au niveau 1, +1 par niveau (34 au niveau 30) ; four en acier sans", table.concat(slots, " ; "))
    local bad = {}
    for name, v in pairs(VAL) do
      local p = game.item_prototypes[name]
      local me = p and p.module_effects or {}
      local t = {}
      for _, k in ipairs({ "speed", "consumption", "productivity" }) do
        local got = me[k] and me[k].bonus or 0
        t[#t + 1] = k .. "=" .. string.format("%.17g", got)
        if math.abs(got - (v[k] or 0)) > 1e-4 then bad[#bad + 1] = name .. "." .. k .. " " .. f6(got) .. "≠" .. f6(v[k] or 0) end
      end
      ctx.log("PROTO module " .. name .. " : " .. table.concat(t, " ") .. " ; centiemes du mod "
        .. serpent.line(remote.call("fo-modules", "cents", name)))
    end
    table.sort(bad)
    ctx.check(#bad == 0, "effets des modules : paliers du DC (vitesse +50, +80, +110 % ..., energie 60 %), autres gardes",
      table.concat(bad, " ; "))
    local hidden = 0
    for _, effect in ipairs({ "speed", "consumption", "productivity" }) do
      for _, sg in ipairs({ "p", "n" }) do
        for b = 0, 14 do
          if game.item_prototypes[string.format("fo-mm-%s-%s%02d", effect, sg, b)] then hidden = hidden + 1 end
        end
      end
    end
    ctx.check(hidden == 90 and game.entity_prototypes["fo-mm-balise"] ~= nil, "90 modules caches et la balise cachee charges", hidden)

    -- Cellules.
    local n = #CELLS + 1
    local rows = math.ceil(n / COLS)
    ctx.prepare_area(X0 - 14, Y0 - 14, X0 + COLS * PAS, Y0 + rows * PAS, "grass-1")
    st.cells = {}
    local bad2 = {}
    for i, spec in ipairs(CELLS) do
      local x = X0 + ((i - 1) % COLS) * PAS
      local y = Y0 + math.floor((i - 1) / COLS) * PAS
      if spec.m == "fo-lvl-assembler-30" then x, y = x - 0.5, y - 0.5 end
      local c = poser_cellule(s, spec, x, y)
      st.cells[#st.cells + 1] = c
      if not c.ok then bad2[#bad2 + 1] = spec.id end
    end
    do
      local i = #CELLS + 1
      local x = X0 + ((i - 1) % COLS) * PAS
      local y = Y0 + math.floor((i - 1) / COLS) * PAS
      local c = poser_grille(s, x, y)
      st.grille = c
      if not c.ok then bad2[#bad2 + 1] = c.id end
    end
    ctx.check(#bad2 == 0, "cellules posees, modules inseres (" .. #CELLS .. " + grille 3 x 3)", table.concat(bad2, " ; "))

    poser_k(ctx, s, st)
    poser_l(ctx, s, st)
    poser_m(ctx, s, st)
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local t = e.tick
    local s = ctx.surface()
    local fen = t > WA and t <= WB
    -- Mesure (même travail à chaque tick, fenêtre ou non : le coût du mod de test reste constant).
    local all = {}
    for _, c in ipairs(st.cells) do all[#all + 1] = c end
    all[#all + 1] = st.grille
    for _, c in ipairs(all) do
      local src = c.src
      if src and src.valid then
        local used = CAP - src.energy
        src.energy = CAP
        if fen then c.e = c.e + used end
      end
      local ms = c.grille or { { m = c.m } }
      for _, g in ipairs(ms) do
        local m = g.m
        if m and m.valid then
          local spec = c.spec or { rec = "iron-gear-wheel" }
          local nb = 0
          if c.coffre then
            if c.coffre.valid then
              local inv = c.coffre.get_inventory(defines.inventory.chest)
              nb = inv.get_item_count()
              if nb > 0 then inv.clear() end
            end
          elseif not (spec.labo) then
            local out = m.get_output_inventory()
            nb = out.get_item_count()
            if nb > 0 then out.clear() end
            nourrir(m, spec.rec)
          end
          if fen and not c.grille then c.items = c.items + nb end
        end
      end
    end
    if t == WA then
      for _, c in ipairs(st.cells) do
        if c.m and c.m.valid then c.a = { pf = lit(c.m, "products_finished") or 0, prog = lit(c.m, "crafting_progress") or 0,
          mp = lit(c.m, "mining_progress") or 0, rp = lit(c.m, "research_progress") } end
      end
    end
    if t == WB then
      for _, c in ipairs(st.cells) do
        if c.m and c.m.valid then c.b = { pf = lit(c.m, "products_finished") or 0, prog = lit(c.m, "crafting_progress") or 0,
          mp = lit(c.m, "mining_progress") or 0 } end
      end
    end

    -- K : amélioration de niveau 6 → 7 (agrandissement par script) puis 7 → 8 (remplacement rapide).
    if (t == T_UP1 or t == T_UP2) and st.k and st.k.a and st.k.a.valid then
      local before = st.k.a
      local r = remote.call("factorio-overhaul", "levels_upgrade", before)
      local new = r and r.entity
      local label = t == T_UP1 and "6 -> 7" or "7 -> 8"
      if new and new.valid then
        st.k.a = new
        local inv = new.get_module_inventory()
        local nmods = inv and inv.get_item_count() or -1
        local okb, txt = bonus_ok(new, { S1, S1, S1, S2, S2, S2 })
        local stt = etat(new)
        local nb = balises_cachees(s, new)
        local orph = s.count_entities_filtered({ name = "fo-mm-balise", area = { { KX - 30, KY - 20 }, { KX + 30, KY + 20 } } })
        ctx.check(nmods == 6 and okb and stt and stt.tracked and stt.beacon ~= nil and nb == 1 and orph == 1,
          "K : amelioration " .. label .. " : modules gardes, balise recalculee, une seule balise cachee",
          string.format("%s ; modules %d ; %s ; suivie %s, balise %s ; balises dans la machine %d, dans la zone %d", new.name,
            nmods, txt, tostring(stt and stt.tracked), tostring(stt and stt.beacon and stt.beacon.valid), nb, orph))
        if stt and stt.beacon then
          ctx.check(math.abs(stt.beacon.position.x - new.position.x) < 0.01 and math.abs(stt.beacon.position.y - new.position.y) < 0.01,
            "K : " .. label .. " : balise au centre de la nouvelle machine",
            f6(stt.beacon.position.x) .. "," .. f6(stt.beacon.position.y) .. " / " .. f6(new.position.x) .. "," .. f6(new.position.y))
        end
      else
        ctx.fail("K : amelioration " .. label, "refusee : " .. tostring(r and r.reason))
      end
    end

    -- L : robots.
    if t == 30 and st.z then actions_l(ctx, s, st) end
    if st.z and t % 10 == 0 and t > 30 and t <= CHECK then
      local z = st.z
      local function suivi(m, mods, key)
        if not (m and m.valid) then return end
        local n = m.get_module_inventory().get_item_count()
        if n == #mods and not st[key .. "_livre"] then st[key .. "_livre"] = t end
        if st[key .. "_livre"] and not st[key .. "_juste"] then
          local okb = bonus_ok(m, mods)
          if okb then st[key .. "_juste"] = t end
        end
      end
      suivi(z.m1, rep(S2, 5), "l1")
      if not (z.g and z.g.valid) then
        z.g = s.find_entity("assembling-machine-2", z.ghost_pos)
        if z.g and not st.l2_bati then st.l2_bati = t end
      end
      suivi(z.g, rep(S3, 3), "l2")
    end

    -- M : modules posés par script (aucun événement) sur les 1 000 machines.
    if t == T_BLOC and st.bloc then
      local n = 0
      for _, m in ipairs(st.bloc) do if m.valid then n = n + inserer(m, { S1, S2, S3 }) end end
      ctx.log("M : " .. n .. " modules inseres par script au tick " .. t .. " (aucun evenement)")
    end
    if st.bloc and t > T_BLOC and t % 30 == 0 and not st.bloc_fini then
      local bons = 0
      for _, m in ipairs(st.bloc) do
        if m.valid and math.abs(m.speed_bonus - 4.67) < 0.005 then bons = bons + 1 end
      end
      if bons == #st.bloc then st.bloc_fini = t end
      if t % 150 == 0 then ctx.log("M : " .. bons .. " / " .. #st.bloc .. " machines au produit au tick " .. t) end
    end
    if t == T_PROF and st.bloc then
      for k = 1, 3 do
        local p = game.create_profiler()
        local n, changed = remote.call("fo-modules", "sweep_all")
        p.stop()
        log({ "", "[FO-MOD1-MODULES] COUT\tbalayage complet sans changement (#", tostring(k), ", ", tostring(changed), " recalcul(s))\tn=", tostring(n), "\t", p })
      end
      local p = game.create_profiler()
      for _, m in ipairs(st.bloc) do remote.call("fo-modules", "refresh", m, true) end
      p.stop()
      log({ "", "[FO-MOD1-MODULES] COUT\trecalcul force (3 modules, balise reecrite)\tn=", tostring(#st.bloc), "\t", p })
      local p2 = game.create_profiler()
      for _ = 1, 5 do for _, m in ipairs(st.bloc) do local _ = m.get_module_inventory().get_contents() end end
      p2.stop()
      log({ "", "[FO-MOD1-MODULES] COUT\tget_contents seul (temoin du moteur)\tn=", tostring(5 * #st.bloc), "\t", p2 })
    end

    -- Images (session avec images seulement) : interfaces ouvertes.
    local p = game.connected_players[1]
    if p and st.cells and t >= T_GUI and t < T_GUI + 50 then
      local cibles = st.gui_cibles
      if not cibles then
        cibles = {}
        for _, c in ipairs(st.cells) do
          if c.id == "E-14-palier1" or c.id == "F-plafond-34-palier10" or c.id == "C-3-paliers" or c.id == "G-mixte" then
            cibles[#cibles + 1] = { c.id, c.m }
          end
        end
        if st.z and st.z.m1 then cibles[#cibles + 1] = { "L-robots", st.z.m1 } end
        st.gui_cibles = cibles
      end
      local k = math.floor((t - T_GUI) / 10) + 1
      local phase = (t - T_GUI) % 10
      local cb = cibles[k]
      if cb and cb[2] and cb[2].valid then
        if phase == 0 then
          p.teleport({ cb[2].position.x, cb[2].position.y + 5 })
          local ok, err = pcall(function() p.opened = cb[2] end)
          if not ok then ctx.log("GUI " .. cb[1] .. " : opened refuse " .. tostring(err)) end
        elseif phase == 4 then
          game.take_screenshot({ path = "fo-shots/x-mod1-gui-" .. cb[1] .. ".png", player = p, show_gui = true,
            position = cb[2].position, zoom = 1, resolution = { 1920, 1080 }, force_render = true, allow_in_replay = true })
          ctx.log("GUI " .. cb[1] .. " : capture demandee, ouvert = " .. tostring(p.opened and p.opened.name))
        elseif phase == 7 then
          p.opened = nil
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    if not st.pret then
      ctx.fail("scenario pret", "init interrompue")
      return
    end
    local stats = remote.call("fo-modules", "stats")
    ctx.log("STATS " .. serpent.line(stats))
    local secs = (WB - WA) / 60
    for _, c in ipairs(st.cells) do
      local spec = c.spec
      local m = c.m
      if not (m and m.valid and c.a and c.b) then
        ctx.fail("mesure " .. c.id, "machine absente ou instantanes manquants")
      else
        local okb, txt, a = bonus_ok(m, spec.mods, spec.vbal)
        local bs, bc = balise(spec.vbal)
        local stt = etat(m)
        -- Balise cachée attendue si le produit (arrondi) diffère de la somme, en vitesse ou en énergie.
        local sum_s, sum_c = 0, 0
        for _, nm in ipairs(spec.mods) do sum_s = sum_s + (VAL[nm].speed or 0); sum_c = sum_c + (VAL[nm].consumption or 0) end
        local diff = math.abs((a.ts - 100) / 100 - sum_s) > 0.004 or math.abs((a.tc - 100) / 100 - sum_c) > 0.004
        local nbal = balises_cachees(s, m)
        ctx.check(okb, "bonus relus = formule (" .. c.id .. ")", txt)
        ctx.check((diff and nbal == 1) or (not diff and nbal == 0), "balise cachee " .. (diff and "presente" or "absente")
          .. " (" .. c.id .. ")", "balises dans la machine : " .. nbal .. " ; modules caches " .. serpent.line(stt and stt.modules))
        if not spec.labo then
          -- Vitesse mesurée (fabrications, ou minerai, par seconde) et énergie mesurée, contre le produit EXACT des
          -- modules (non arrondi) : fab = base × (Π (1 + b) + balise du joueur) / durée de la recette.
          local proto = m.prototype
          local sb, cb = lit(m, "speed_bonus"), lit(m, "consumption_bonus")
          local pb = lit(m, "productivity_bonus") or 0
          local power = c.e / (WB - WA) * 60
          local eu = proto.energy_usage or 0
          local drain = lit(m, "electric_drain") or 0
          local bal_w = c.vbal and c.vbal.valid and (c.vbal.prototype.energy_usage or 0) * 60 or 0
          local fs = math.min(a.ps + bs, 328.67)       -- facteur de vitesse voulu (exact), plafond
          local fc = math.min(a.pc + bc, 328.67)       -- facteur d'énergie voulu (exact), plafond
          local want_w = (eu * fc + drain) * 60 + bal_w
          local fab, want_fab
          if spec.foreuse then
            fab = c.items / secs
            want_fab = proto.mining_speed * fs * (1 + pb)
          else
            local r = spec.four and game.recipe_prototypes["iron-plate"] or m.get_recipe()
            fab = (c.b.pf - c.a.pf + (c.b.prog - c.a.prog)) / secs
            want_fab = proto.crafting_speed * fs / r.energy
          end
          local plafond = want_fab > 60 and not spec.foreuse
          ctx.log(string.format("MESURE %s : modules %d ; speed_bonus %s ; consumption_bonus %s ; productivity_bonus %s ; "
            .. "facteur vitesse voulu %s, energie %s ; fab/s %s (attendu %s%s) ; puissance %s W (attendue %s W ; energy_usage %s J/tick, "
            .. "drain %s J/tick, balise du joueur %s W)",
            c.id, #spec.mods, f6(sb), f6(cb), f6(pb), f6(fs), f6(fc), f6(fab), f6(want_fab), plafond and ", plafond de 60 /s" or "",
            f6(power), f6(want_w), f6(eu), f6(drain), f6(bal_w)))
          if plafond then want_fab = 60 end
          ctx.check(math.abs(fab - want_fab) <= 0.01 * want_fab + 0.05, "vitesse mesuree = produit des modules (" .. c.id .. ")",
            string.format("%.4f /s mesure, %.4f attendu (facteur %.4f)", fab, want_fab, fs))
          ctx.check(math.abs(power - want_w) <= 0.01 * want_w + 100, "energie mesuree = produit des modules (" .. c.id .. ")",
            string.format("%.0f W mesure, %.0f W attendu (facteur %.4f)", power, want_w, fc))
        end
      end
    end
    -- Grille : voisines intactes.
    local g = st.grille
    local bad, txt = 0, {}
    for _, cell in ipairs(g.grille) do
      local okb, t2 = bonus_ok(cell.m, cell.mods)
      local nb = balises_cachees(s, cell.m)
      local want_nb = #cell.mods >= 2 and 1 or 0
      if not okb or nb ~= want_nb then bad = bad + 1 end
      txt[#txt + 1] = string.format("(%d,%d) %d mod. %s balises %d", cell.dx, cell.dy, #cell.mods, okb and "juste" or ("FAUX " .. t2), nb)
    end
    ctx.check(bad == 0, "V : grille 3 x 3 collee, chaque machine a exactement le produit de SES modules", table.concat(txt, " ; "))
    -- K
    ctx.check(st.k and st.k.a and st.k.a.valid and st.k.a.name == LV.name(LV.by_key.assembler, 8), "K : assembleur au niveau 8 a la fin",
      st.k and st.k.a and st.k.a.valid and st.k.a.name)
    if st.k and st.k.a and st.k.a.valid then
      local okb, t2 = bonus_ok(st.k.a, { S1, S1, S1, S2, S2, S2 })
      ctx.check(okb, "K : bonus justes a la fin (niveau 8)", t2)
    end
    -- L
    ctx.log(string.format("MESURE L : proxy livre au tick %s, juste au tick %s ; fantome bati au tick %s, livre %s, juste %s",
      tostring(st.l1_livre), tostring(st.l1_juste), tostring(st.l2_bati), tostring(st.l2_livre), tostring(st.l2_juste)))
    ctx.check(st.l1_livre and st.l1_juste and st.l1_juste - st.l1_livre <= 310, "L : 5 modules livres par robots, produit applique par le balayage (<= 310 ticks)",
      tostring(st.l1_livre) .. " -> " .. tostring(st.l1_juste))
    ctx.check(st.l2_livre and st.l2_juste and st.l2_juste - st.l2_livre <= 310, "L : machine batie par robots puis 3 modules livres, produit applique (<= 310 ticks)",
      tostring(st.l2_livre) .. " -> " .. tostring(st.l2_juste))
    -- M
    ctx.check(st.bloc_fini and st.bloc_fini - T_BLOC <= 330, "M : 1 000 machines au produit apres le balayage (<= 330 ticks)",
      tostring(st.bloc_fini) .. " (modules poses au tick " .. T_BLOC .. ")")
    local nb = s.count_entities_filtered({ name = "fo-mm-balise", area = { { MX - 6, MY - 6 }, { MX + MCOLS * 3 + 4, MY + 40 * 3 } } })
    ctx.check(nb == MN, "M : une balise cachee par machine du bloc", nb .. " / " .. MN)
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    for _, c in ipairs(st.cells or {}) do
      if c.id == "F-plafond-34-palier10" or c.id == "E-14-palier1" or c.id == "C2-3-paliers+balise" then
        add(c.id .. "-alt", c.x, c.y, 1, 0, { info = true })
      end
    end
    if st.grille then add("V-grille-alt", st.grille.x, st.grille.y, 1, 0, { info = true }) end
  end,
}
