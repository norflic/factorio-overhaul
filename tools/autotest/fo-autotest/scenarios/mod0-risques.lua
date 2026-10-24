-- Scénario greffé du lot MOD-0 (24/10) : levée des risques moteur des modules MULTIPLICATIFS (demande du DC du 24/10 :
-- paliers +50 / +80 / +110 %, effets qui se multiplient sur une machine, 5 emplacements au niveau 1 puis +1 par niveau).
-- À LANCER SUR LA COPIE JETABLE (tools/autotest/mod0/jetable.py), qui seule a les prototypes de test :
--   py -3.9 tools/autotest/mod0/jetable.py --dest <dossier neuf, hors du dépôt>
--   & "<racine>\fo-autotest.bat" nopause 1900 mod0-risques "<dossier neuf>"
--   py -3.9 tools/autotest/mod0/analyse.py "<racine>\fo-autotest"         (coûts, temps par tick des fenêtres de R3)
--   & "<racine>\fo-captures.bat" mod0-risques "<dossier neuf>"             (images de R4 et R6 : x-mod0-*.png)
-- Sur le mod livré, le scénario s'arrête à l'init : « prototypes de test absents ».
--
-- Le BILAN ne compte que des contrôles de PROTOCOLE (mise en place). Les réponses sont des lignes « MESURE … » et
-- « VERDICT Rk : … » HORS bilan : un « non » est un résultat, pas un échec.
--
-- Chaque cellule (24 tuiles d'écart) a SON réseau électrique : un poteau invisible (zone 13 x 13) et une source
-- invisible remise pleine à chaque tick ; l'énergie prise est comptée (plafond par tick = puissance de la source).
-- Fenêtre de mesure : mises à jour des ticks 300 à 899 (10 s). Les produits sont retirés de la sortie à chaque tick.
--   R1 : addition des effets (3 modules de vitesse 3 ; puis une balise vanilla de 2 modules de vitesse 3 ; 3 x +50 % ;
--        paliers +50, +80, +110 ; 2 x productivité +10 % ; 1,15 sans epsilon) : bonus relus, durée réelle, puissance.
--   R2 : plafond d'une fabrication par tick : assembleurs 10, 100, 1 000 (recette de 0,5 s), avec productivité +10 % ;
--        fours 1, 10, 100, 1 000 (0,5 s) ; foreuses 1, 10, 100, 1 000 (minerai de fer, 1 s).
--   R3 : balise cachée (void, boîte 0,2, zone 0,3) au centre de la machine du milieu d'une grille 3 x 3 de machines
--        COLLÉES ; puis coût : 1 100 machines collées (bloc), balises posées pour 100 (tick 1000) puis 1 000 (tick 1100),
--        modules échangés (tick 1200), temps par tick avant (700-999) et après (1300-1599) par analyse.py.
--   R4 : vitesse +10, +100, +1 000 (machine ; +1 000 aussi en balise), 327,67 et 327,68, 2 x +200 ; consommation +10,
--        +100, +1 000 ; productivité +10, +100, +1 000 ; module de productivité vanilla (limité) en balise et en machine.
--   R5 : 1 GW et 1 TW sur réseau illimité, puis sur 1 MW ; 1 GW + témoin de 100 kW sur 10 MW ; input_flow_limit 10 kW ;
--        1 TW limité à 1 MW + témoin sur 10 MW ; buffer_capacity 10 MJ sur 1 MW.
--   R6 : zone des robots : machine de 34 emplacements remplie par robots (item-request-proxy), fantôme avec demande de
--        34 modules bâti par robots, bras vers une machine (avec et sans recette) depuis un coffre de modules.
--   R7 : événements levés (journal) pendant R6, plan posé sur une machine existante (modules demandés), copy_settings
--        par script ; coût d'un balayage des modules de 1 100 machines (tick 1700, 4 méthodes, 5 répétitions).

local NOM = "mod0-risques"
local X0, Y0, PAS, COLS = 3000.5, 3000.5, 24, 10
local WA, WB = 300, 900
local UNLIM = 1e13               -- J par tick
local function W(p) return p / 60 end
local BX0, BY0, BCOLS, BN = 3100.5, 3300.5, 34, 1100
local RX, RY = 3400.5, 3000.5
local T_ROBOTS = 60
local T_POSE_A, T_POSE_B, T_VERIF_B, T_ECHANGE, T_VERIF_E, T_SCAN = 1000, 1100, 1150, 1200, 1250, 1700
local T_SAVE_A, T_SAVE_B = 995, 1295
local T_GUI = 1400
local CHECK = 1800

---------------------------------------------------------------------------------------------------
-- Événements (R7) : abonnés au chargement du mod de test (le mod de test n'utilise que on_tick et on_nth_tick).
---------------------------------------------------------------------------------------------------
local EVTS = { "on_built_entity", "on_robot_built_entity", "script_raised_built", "script_raised_revive",
  "on_entity_settings_pasted", "on_pre_entity_settings_pasted", "on_player_fast_transferred", "on_gui_closed",
  "on_gui_opened", "on_player_cursor_stack_changed", "on_player_main_inventory_changed", "on_marked_for_upgrade",
  "on_pre_build", "on_robot_mined_entity", "on_player_mined_entity" }
local function nom_ent(e)
  for _, k in ipairs({ "created_entity", "entity", "destination", "source" }) do
    local v = e[k]
    if type(v) == "table" and v.valid then return k .. "=" .. v.name end
  end
  return "-"
end
for _, n in ipairs(EVTS) do
  local id = defines.events[n]
  if id then
    script.on_event(id, function(e)
      global.mod0_evts = global.mod0_evts or {}
      local l = global.mod0_evts
      if #l < 400 then l[#l + 1] = { tick = e.tick, name = n, ent = nom_ent(e) } end
    end)
  end
end

---------------------------------------------------------------------------------------------------
-- Cellules
---------------------------------------------------------------------------------------------------
local CELLS = {}
local function C(t) CELLS[#CELLS + 1] = t end
local function A(nom, rec, mods, bal, extra)
  local m = { n = nom, rec = rec or "mod0-r05", mods = mods, bal = bal }
  for k, v in pairs(extra or {}) do m[k] = v end
  return m
end
local V3 = "speed-module-3"

-- R1
C({ id = "R1-temoin", r = "R1", ms = { A("mod0-asm-1") } })
C({ id = "R1-3xvit3", r = "R1", ms = { A("mod0-asm-1", nil, { V3, V3, V3 }) } })
C({ id = "R1-3xvit3-balise", r = "R1", ms = { A("mod0-asm-1", nil, { V3, V3, V3 }) }, vbal = { V3, V3 } })
C({ id = "R1-3xv50", r = "R1", ms = { A("mod0-asm-1", nil, { "mod0-v50", "mod0-v50", "mod0-v50" }) } })
C({ id = "R1-paliers", r = "R1", ms = { A("mod0-asm-1", nil, { "mod0-v50", "mod0-v80", "mod0-v110" }) } })
C({ id = "R1-2xp10", r = "R1", ms = { A("mod0-asm-1", nil, { "mod0-p10", "mod0-p10" }) } })
C({ id = "R1-v115-brut", r = "R1", ms = { A("mod0-asm-1", nil, { "mod0-v115-brut" }) } })
-- R2
C({ id = "R2-asm-10", r = "R2", ms = { A("mod0-asm-10") } })
C({ id = "R2-asm-100", r = "R2", ms = { A("mod0-asm-100") } })
C({ id = "R2-asm-1000", r = "R2", ms = { A("mod0-asm-1000") } })
C({ id = "R2-asm-100-p10", r = "R2", ms = { A("mod0-asm-100", nil, { "mod0-p10" }) } })
C({ id = "R2-asm-1000-p10", r = "R2", ms = { A("mod0-asm-1000", nil, { "mod0-p10" }) } })
for _, v in ipairs({ 1, 10, 100, 1000 }) do
  C({ id = "R2-four-" .. v, r = "R2", ms = { A("mod0-four-" .. v, "mod0-four") } })
end
for _, v in ipairs({ 1, 10, 100, 1000 }) do
  C({ id = "R2-foreuse-" .. v, r = "R2", ms = { A("mod0-foreuse-" .. v, false) } })
end
-- R3 : grille 3 x 3 de machines collées, balise cachée au centre seulement.
do
  local ms = {}
  for _, dy in ipairs({ -3, 0, 3 }) do
    for _, dx in ipairs({ -3, 0, 3 }) do
      local centre = dx == 0 and dy == 0
      ms[#ms + 1] = A("mod0-asm-1", nil, nil, centre and { "mod0-cplt-v100" } or nil,
        { dx = dx, dy = dy, role = centre and "centre" or ("voisine " .. dx .. "," .. dy) })
    end
  end
  C({ id = "R3-grille", r = "R3", ms = ms, principale = 5 })
end
-- R4
C({ id = "R4-v1000", r = "R4", ms = { A("mod0-asm-1", "mod0-r10", { "mod0-v1000" }) } })
C({ id = "R4-v10000", r = "R4", ms = { A("mod0-asm-1", "mod0-r100", { "mod0-v10000" }) } })
C({ id = "R4-v100000", r = "R4", ms = { A("mod0-asm-1", "mod0-r100", { "mod0-v100000" }) } })
C({ id = "R4-v100000-balise", r = "R4", ms = { A("mod0-asm-1", "mod0-r100", nil, { "mod0-v100000" }) } })
C({ id = "R4-v32767", r = "R4", ms = { A("mod0-asm-1", "mod0-r100", { "mod0-v32767" }) } })
C({ id = "R4-v32768", r = "R4", ms = { A("mod0-asm-1", "mod0-r100", { "mod0-v32768" }) } })
C({ id = "R4-2xv20000", r = "R4", ms = { A("mod0-asm-1", "mod0-r100", { "mod0-v20000", "mod0-v20000" }) } })
C({ id = "R4-c1000", r = "R4", ms = { A("mod0-asm-1", nil, { "mod0-c1000" }) } })
C({ id = "R4-c10000", r = "R4", ms = { A("mod0-asm-1", nil, { "mod0-c10000" }) } })
C({ id = "R4-c100000", r = "R4", ms = { A("mod0-asm-1", nil, { "mod0-c100000" }) } })
C({ id = "R4-p1000", r = "R4", ms = { A("mod0-asm-1", nil, { "mod0-p1000" }) } })
C({ id = "R4-p10000", r = "R4", ms = { A("mod0-asm-1", nil, { "mod0-p10000" }) } })
C({ id = "R4-p100000", r = "R4", ms = { A("mod0-asm-1", nil, { "mod0-p100000" }) } })
C({ id = "R4-prodvanilla-balise", r = "R4", ms = { A("mod0-asm-1", nil, nil, { "productivity-module-3" }) } })
C({ id = "R4-prodvanilla-machine", r = "R4", ms = { A("mod0-asm-1", nil, { "productivity-module-3" }) } })
-- R5
C({ id = "R5-1gw-illimite", r = "R5", ms = { A("mod0-asm-1gw") } })
C({ id = "R5-1tw-illimite", r = "R5", ms = { A("mod0-asm-1tw") } })
C({ id = "R5-1gw-sur-1mw", r = "R5", cap = W(1e6), ms = { A("mod0-asm-1gw") } })
C({ id = "R5-1tw-sur-1mw", r = "R5", cap = W(1e6), ms = { A("mod0-asm-1tw") } })
C({ id = "R5-1gw-temoin-sur-10mw", r = "R5", cap = W(1e7),
  ms = { A("mod0-asm-1gw"), A("mod0-asm-1", nil, nil, nil, { dx = 5, role = "temoin 100 kW" }) } })
C({ id = "R5-flux-10kw", r = "R5", ms = { A("mod0-asm-flux") } })
C({ id = "R5-1tw-flux1mw-temoin-sur-10mw", r = "R5", cap = W(1e7),
  ms = { A("mod0-asm-1tw-flux"), A("mod0-asm-1", nil, nil, nil, { dx = 5, role = "temoin 100 kW" }) } })
C({ id = "R5-tampon-10mj-sur-1mw", r = "R5", cap = W(1e6), ms = { A("mod0-asm-tampon") } })

local PROTOS = { "mod0-asm-1", "mod0-asm-1000", "mod0-four-1000", "mod0-foreuse-1000", "mod0-balise-cachee",
  "mod0-source", "mod0-poteau", "mod0-asm-1tw-flux" }

---------------------------------------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------------------------------------
local function f6(v)
  if v == nil then return "nil" end
  return string.format("%.6g", v)
end

local function effets(e)
  local ok, ef = pcall(function() return e.effects end)
  if not ok or type(ef) ~= "table" then return "-" end
  local t = {}
  for _, k in ipairs({ "speed", "productivity", "consumption", "pollution" }) do
    if ef[k] then t[#t + 1] = k .. "=" .. f6(ef[k].bonus) end
  end
  return #t > 0 and table.concat(t, ",") or "{}"
end

local function lit(e, k)
  local ok, v = pcall(function() return e[k] end)
  if ok then return v end
  return nil
end

local function progres(m)
  if m.type == "mining-drill" then return 0 end
  return lit(m, "crafting_progress") or 0
end

local function modules_txt(inv)
  if not inv then return "-" end
  local c = inv.get_contents()
  local noms = {}
  for n in pairs(c) do noms[#noms + 1] = n end
  table.sort(noms)
  local t = {}
  for _, n in ipairs(noms) do t[#t + 1] = n .. "x" .. c[n] end
  return #t > 0 and table.concat(t, ",") or "vide"
end

local function profil(ctx, label, n, fn)
  local p = game.create_profiler()
  fn()
  p.stop()
  log({ "", ctx.tag, " COUT\t", label, "\tn=", tostring(n), "\t", p })
end

local function poser_cellule(ctx, s, spec, x, y)
  local c = { id = spec.id, r = spec.r, cap = spec.cap or UNLIM, ms = {}, x = x, y = y, e = 0,
    principale = spec.principale or 1 }
  s.create_entity({ name = "mod0-poteau", position = { x, y }, force = "player" })
  local src = s.create_entity({ name = "mod0-source", position = { x + 0.5, y + 0.5 }, force = "player" })
  if src then
    src.electric_buffer_size = c.cap
    src.power_production = 0
    src.power_usage = 0
    src.energy = c.cap
  end
  c.src = src
  local ok_all = src ~= nil
  for _, ms in ipairs(spec.ms) do
    local px, py = x + (ms.dx or 0), y + (ms.dy or 0)
    local proto = game.entity_prototypes[ms.n]
    if proto and proto.type == "mining-drill" then
      for tx = -2, 2 do
        for ty = -2, 2 do
          s.create_entity({ name = "iron-ore", position = { px + tx, py + ty }, amount = 1000000000 })
        end
      end
    end
    local m = s.create_entity({ name = ms.n, position = { px, py }, force = "player" })
    local rec = { m = m, role = ms.role or "principale", items = 0, mis = 0, mods = #(ms.mods or {}),
      bal_mis = 0, bal_n = #(ms.bal or {}) }
    if m then
      if ms.rec and m.type == "assembling-machine" then m.set_recipe(ms.rec) end
      if m.type == "furnace" then
        m.get_inventory(defines.inventory.furnace_source).insert({ name = "iron-ore", count = 50 })
      end
      if m.type == "mining-drill" then
        rec.coffre = s.create_entity({ name = "iron-chest", position = m.drop_position, force = "player" })
        ok_all = ok_all and rec.coffre ~= nil
      end
      local inv = m.get_module_inventory()
      for _, mod in ipairs(ms.mods or {}) do
        rec.mis = rec.mis + (inv and inv.insert({ name = mod, count = 1 }) or 0)
      end
      if ms.bal then
        local b = s.create_entity({ name = "mod0-balise-cachee", position = m.position, force = "player" })
        rec.balise = b
        if b then
          local bi = b.get_module_inventory()
          for _, mod in ipairs(ms.bal) do rec.bal_mis = rec.bal_mis + bi.insert({ name = mod, count = 1 }) end
        end
      end
    else
      ok_all = false
    end
    c.ms[#c.ms + 1] = rec
  end
  if spec.vbal then
    local vb = s.create_entity({ name = "beacon", position = { x, y + 3 }, force = "player" })
    c.vbal = vb
    c.vbal_mis = 0
    if vb then
      for _, mod in ipairs(spec.vbal) do c.vbal_mis = c.vbal_mis + vb.get_module_inventory().insert({ name = mod, count = 1 }) end
    end
  end
  return c, ok_all
end

local function snapshot(c, key)
  for _, rec in ipairs(c.ms) do
    local m = rec.m
    if m and m.valid then
      rec[key] = { pf = lit(m, "products_finished") or 0, prog = progres(m), bonus = lit(m, "bonus_progress") or 0,
        mprog = m.type == "mining-drill" and (lit(m, "mining_progress") or 0) or 0 }
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Zone des robots (R6, R7)
---------------------------------------------------------------------------------------------------
local function poser_robots(ctx, s, st)
  ctx.prepare_area(RX - 40, RY - 30, RX + 40, RY + 30, "grass-1")
  ctx.power(RX, RY)
  local z = {}
  z.rp = s.create_entity({ name = "roboport", position = { RX - 0.5, RY - 0.5 }, force = "player" })
  if z.rp then z.rp.insert({ name = "construction-robot", count = 20 }) end
  z.stock = s.create_entity({ name = "logistic-chest-storage", position = { RX + 3, RY }, force = "player" })
  if z.stock then
    z.stock.insert({ name = V3, count = 45 })
    z.stock.insert({ name = "speed-module", count = 40 })
    z.stock.insert({ name = "mod0-asm-1", count = 2 })
  end
  z.m1 = s.create_entity({ name = "mod0-asm-1", position = { RX - 8, RY + 8 }, force = "player" })
  if z.m1 then z.m1.set_recipe("mod0-r05") end
  z.ghost_pos = { RX + 8, RY + 8 }
  z.m2 = s.create_entity({ name = "mod0-asm-1", position = { RX - 8, RY - 8 }, force = "player" })
  if z.m2 then
    z.m2.set_recipe("mod0-r05")
    z.m2.get_module_inventory().insert({ name = "speed-module", count = 2 })
  end
  z.m3 = s.create_entity({ name = "mod0-asm-1", position = { RX + 8, RY - 8 }, force = "player" })
  if z.m3 then
    z.m3.set_recipe("mod0-r05")
    z.m3.get_module_inventory().insert({ name = V3, count = 3 })
  end
  z.m4 = s.create_entity({ name = "mod0-asm-1", position = { RX + 12, RY - 8 }, force = "player" })
  -- Bras : coffre de modules → bras rapide → machine (avec recette, puis sans recette).
  z.bras = {}
  for i, avec in ipairs({ true, false }) do
    local my = RY + (i - 1) * 8
    local m = s.create_entity({ name = "mod0-asm-1", position = { RX - 20, my }, force = "player" })
    if m and avec then m.set_recipe("mod0-r05") end
    local ch = s.create_entity({ name = "iron-chest", position = { RX - 23, my }, force = "player" })
    if ch then ch.insert({ name = V3, count = 10 }) end
    local ins = s.create_entity({ name = "fast-inserter", position = { RX - 22, my }, force = "player" })
    if ins then
      ins.pickup_position = { RX - 23, my }
      ins.drop_position = { RX - 21, my }
    end
    z.bras[i] = { m = m, ch = ch, ins = ins, avec = avec }
  end
  st.z = z
  local ok = z.rp and z.stock and z.m1 and z.m2 and z.m3 and z.m4 and z.bras[1].ins and z.bras[2].ins
  ctx.check(ok ~= nil and ok ~= false, "R6/R7 : zone des robots posee", "roboport, stock, 4 machines, 2 bras")
end

local function actions_robots(ctx, s, st)
  local z = st.z
  -- R6 : demande de 34 modules sur une machine posée (comme un plan posé sur une machine sans modules).
  local proxy = s.create_entity({ name = "item-request-proxy", position = z.m1.position, force = "player",
    target = z.m1, modules = { [V3] = 34 } })
  ctx.check(proxy ~= nil, "R6 : item-request-proxy de 34 modules pose", proxy and proxy.name)
  -- R6 : fantôme avec demande de 34 modules (plan posé à vide).
  local g = s.create_entity({ name = "entity-ghost", inner_name = "mod0-asm-1", position = z.ghost_pos,
    force = "player", expires = false })
  if g then
    local ok, err = pcall(function() g.item_requests = { ["speed-module"] = 34 } end)
    ctx.log("R6 fantome : item_requests ecrit " .. tostring(ok) .. " " .. tostring(err))
  end
  ctx.check(g ~= nil, "R6 : fantome mod0-asm-1 pose")
  -- R7 : plan posé PAR-DESSUS une machine existante (2 modules de vitesse 1) qui demande 4 modules de vitesse 3.
  local inv = game.create_inventory(1)
  local okb, errb = pcall(function()
    inv[1].set_stack({ name = "blueprint" })
    inv[1].set_blueprint_entities({ { entity_number = 1, name = "mod0-asm-1", position = { x = 0, y = 0 },
      recipe = "mod0-r05", items = { [V3] = 4 } } })
    local res = inv[1].build_blueprint({ surface = s, force = "player", position = z.m2.position, force_build = true })
    local t = {}
    for _, e in ipairs(res or {}) do t[#t + 1] = e.name .. "@" .. f6(e.position.x) .. "," .. f6(e.position.y) end
    ctx.log("R7 plan sur machine existante : build_blueprint rend " .. #(res or {}) .. " entite(s) " .. table.concat(t, " "))
  end)
  inv.destroy()
  ctx.log("R7 plan : pcall " .. tostring(okb) .. " " .. tostring(errb))
  local px = s.find_entities_filtered({ name = "item-request-proxy", position = z.m2.position, radius = 2 })
  for _, p in ipairs(px) do
    local req = {}
    for k, v in pairs(p.item_requests) do req[#req + 1] = k .. "x" .. v end
    table.sort(req)
    ctx.log("R7 plan : proxy sur la machine existante, demandes " .. table.concat(req, ",") .. ", cible "
      .. tostring(p.proxy_target and p.proxy_target.name))
  end
  st.plan_proxies = #px
  -- R7 : copy_settings par script (machine à 3 modules → machine vide, sans recette).
  local okc, rendu = pcall(function() return z.m4.copy_settings(z.m3) end)
  local rt = {}
  if okc and type(rendu) == "table" then for k, v in pairs(rendu) do rt[#rt + 1] = k .. "x" .. v end end
  table.sort(rt)
  ctx.log("R7 copy_settings (script) : pcall " .. tostring(okc) .. ", rendu {" .. table.concat(rt, ",") .. "}, recette "
    .. tostring(z.m4.get_recipe() and z.m4.get_recipe().name) .. ", modules " .. modules_txt(z.m4.get_module_inventory())
    .. ", proxys " .. #s.find_entities_filtered({ name = "item-request-proxy", position = z.m4.position, radius = 2 }))
end

---------------------------------------------------------------------------------------------------
-- Scénario
---------------------------------------------------------------------------------------------------
return {
  description = "MOD-0 : risques moteur des modules multiplicatifs (R1 a R7), sur la copie jetable seulement",
  base = nil,
  check_tick = CHECK,
  shots_delay = 1500,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.pret = false
    local manque = {}
    for _, n in ipairs(PROTOS) do
      if not game.entity_prototypes[n] then manque[#manque + 1] = n end
    end
    if not game.item_prototypes["mod0-v100000"] then manque[#manque + 1] = "mod0-v100000" end
    if #manque > 0 then
      ctx.fail("prototypes de test presents (copie jetable tools/autotest/mod0/jetable.py)",
        "prototypes de test absents : " .. table.concat(manque, ", "))
      return
    end
    ctx.ok("prototypes de test presents", #PROTOS .. " entites + modules de test")
    game.forces.player.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire("player", true)
    game.map_settings.enemy_expansion.enabled = false

    -- Effets des modules tels que le moteur les a chargés.
    local noms = { "speed-module-3", "productivity-module-3", "mod0-v50", "mod0-v80", "mod0-v110", "mod0-v115-brut",
      "mod0-p10", "mod0-v1000", "mod0-v10000", "mod0-v100000", "mod0-v32767", "mod0-v32768", "mod0-v20000",
      "mod0-c1000", "mod0-c10000", "mod0-c100000", "mod0-p1000", "mod0-p10000", "mod0-p100000", "mod0-cplt-v100" }
    for _, n in ipairs(noms) do
      local p = game.item_prototypes[n]
      local t = {}
      if p and p.module_effects then
        for _, k in ipairs({ "speed", "productivity", "consumption", "pollution" }) do
          if p.module_effects[k] then t[#t + 1] = k .. "=" .. f6(p.module_effects[k].bonus) end
        end
      end
      ctx.log("PROTO module " .. n .. " : " .. (p and table.concat(t, ",") or "ABSENT")
        .. (p and p.limitations and (" ; limitation " .. #p.limitations .. " recette(s)") or ""))
    end

    -- Cellules R1 à R5.
    local rows = math.ceil(#CELLS / COLS)
    ctx.prepare_area(X0 - 12, Y0 - 12, X0 + COLS * PAS, Y0 + rows * PAS, "grass-1")
    st.cells = {}
    local bad = {}
    for i, spec in ipairs(CELLS) do
      local x = X0 + ((i - 1) % COLS) * PAS
      local y = Y0 + math.floor((i - 1) / COLS) * PAS
      local c, ok = poser_cellule(ctx, s, spec, x, y)
      st.cells[#st.cells + 1] = c
      if not ok then bad[#bad + 1] = spec.id end
      for _, rec in ipairs(c.ms) do
        if rec.mis ~= rec.mods and not spec.id:find("prodvanilla%-machine") then
          bad[#bad + 1] = spec.id .. " modules " .. rec.mis .. "/" .. rec.mods
        end
        if rec.bal_n > 0 and rec.bal_mis ~= rec.bal_n then
          bad[#bad + 1] = spec.id .. " balise " .. rec.bal_mis .. "/" .. rec.bal_n
        end
      end
    end
    ctx.check(#bad == 0, "cellules R1 a R5 posees (" .. #CELLS .. "), modules inseres", table.concat(bad, " ; "))

    -- Bloc de R3 (coût) : 1 100 machines collées, recette de 1 000 s (toujours au travail).
    ctx.prepare_area(BX0 - 6, BY0 - 6, BX0 + BCOLS * 3 + 4, BY0 + math.ceil(BN / BCOLS) * 3 + 4, "grass-1")
    ctx.power(BX0 + BCOLS * 1.5, BY0 + math.ceil(BN / BCOLS) * 1.5)
    st.bloc = {}
    for i = 1, BN do
      local x = BX0 + ((i - 1) % BCOLS) * 3
      local y = BY0 + math.floor((i - 1) / BCOLS) * 3
      local m = s.create_entity({ name = "mod0-asm-1", position = { x, y }, force = "player" })
      if m then
        m.set_recipe("mod0-r1000")
        st.bloc[#st.bloc + 1] = m
      end
    end
    ctx.check(#st.bloc == BN, "R3 : bloc de machines collees pose", #st.bloc .. " / " .. BN)
    st.balises = {}

    poser_robots(ctx, s, st)
    st.pret = true
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.pret then return end
    local t = e.tick
    local s = ctx.surface()
    local fen = t > WA and t <= WB
    for _, c in ipairs(st.cells) do
      local src = c.src
      if src and src.valid then
        local used = c.cap - src.energy
        src.energy = c.cap
        if fen then c.e = c.e + used end
      end
      for _, rec in ipairs(c.ms) do
        local m = rec.m
        if m and m.valid then
          local n = 0
          if rec.coffre then
            if rec.coffre.valid then
              local inv = rec.coffre.get_inventory(defines.inventory.chest)
              n = inv.get_item_count()
              if n > 0 then inv.clear() end
            end
          else
            local out = m.get_output_inventory()
            n = out.get_item_count()
            if n > 0 then out.clear() end
            if m.type == "furnace" then
              local src_inv = m.get_inventory(defines.inventory.furnace_source)
              local k = src_inv.get_item_count("iron-ore")
              if k < 40 then src_inv.insert({ name = "iron-ore", count = 50 - k }) end
            end
          end
          if fen then rec.items = rec.items + n end
        end
      end
    end
    if t == WA then for _, c in ipairs(st.cells) do snapshot(c, "a") end end
    if t == WB then for _, c in ipairs(st.cells) do snapshot(c, "b") end end

    -- R6 / R7
    if t == T_ROBOTS then actions_robots(ctx, s, st) end
    if st.z and t % 30 == 0 and t <= 1500 then
      local z = st.z
      local n1 = z.m1.valid and z.m1.get_module_inventory().get_item_count() or -1
      if n1 ~= st.m1_n then
        ctx.log("R6 machine 34 emplacements : " .. n1 .. " module(s) au tick " .. t)
        st.m1_n = n1
        if n1 == 34 and not st.m1_tick then st.m1_tick = t end
      end
      local g = s.find_entity("mod0-asm-1", z.ghost_pos)
      local n2 = g and g.get_module_inventory().get_item_count() or -1
      if n2 ~= st.g_n then
        ctx.log("R6 machine batie depuis le fantome : " .. n2 .. " module(s) au tick " .. t)
        st.g_n = n2
      end
      local m2 = z.m2.valid and modules_txt(z.m2.get_module_inventory()) or "-"
      if m2 ~= st.m2_txt then
        ctx.log("R7 machine sous le plan : modules " .. m2 .. " au tick " .. t)
        st.m2_txt = m2
      end
    end

    -- R3 coût
    if t == T_SAVE_A or t == T_SAVE_B then
      local ok, err = pcall(function() game.auto_save("mod0-" .. t) end)
      ctx.log("auto_save mod0-" .. t .. " : " .. tostring(ok) .. " " .. tostring(err))
    end
    if t == T_POSE_A or t == T_POSE_B then
      local i0, i1 = 1, 100
      if t == T_POSE_B then i0, i1 = 101, BN end
      profil(ctx, "R3 pose balise cachee + 1 module", i1 - i0 + 1, function()
        for i = i0, i1 do
          local m = st.bloc[i]
          local b = s.create_entity({ name = "mod0-balise-cachee", position = m.position, force = "player" })
          b.get_module_inventory().insert({ name = "mod0-cplt-v100", count = 1 })
          st.balises[i] = b
        end
      end)
    end
    if t == T_VERIF_B or t == T_VERIF_E then
      local attendu = (t == T_VERIF_B) and 1 or 1.3
      local bons, bc1, rec1 = 0, 0, 0
      for i = 1, BN do
        local m = st.bloc[i]
        if math.abs(m.speed_bonus - attendu) < 1e-4 then bons = bons + 1 end
        if m.beacons_count == 1 then bc1 = bc1 + 1 end
        if #st.balises[i].get_beacon_effect_receivers() == 1 then rec1 = rec1 + 1 end
      end
      st["verif" .. t] = { bons = bons, bc1 = bc1, rec1 = rec1 }
      ctx.log("R3 bloc tick " .. t .. " : speed_bonus = " .. attendu .. " pour " .. bons .. "/" .. BN
        .. ", beacons_count = 1 pour " .. bc1 .. ", 1 seule machine touchee par " .. rec1 .. " balise(s)")
    end
    if t == T_ECHANGE then
      profil(ctx, "R3 echange des modules de complement (clear + 2 inserts)", BN, function()
        for i = 1, BN do
          local inv = st.balises[i].get_module_inventory()
          inv.clear()
          inv.insert({ name = "mod0-v50", count = 1 })
          inv.insert({ name = "mod0-v80", count = 1 })
        end
      end)
    end
    if t == T_SCAN then
      local bloc = st.bloc
      local REP = 5
      profil(ctx, "R7 balayage get_module_inventory().get_contents()", BN * REP, function()
        for _ = 1, REP do for i = 1, BN do local _c = bloc[i].get_module_inventory().get_contents() end end
      end)
      profil(ctx, "R7 balayage get_module_inventory().get_item_count()", BN * REP, function()
        for _ = 1, REP do for i = 1, BN do local _c = bloc[i].get_module_inventory().get_item_count() end end
      end)
      profil(ctx, "R7 balayage speed+consumption+productivity_bonus", BN * REP, function()
        for _ = 1, REP do
          for i = 1, BN do
            local m = bloc[i]
            local _a, _b, _c = m.speed_bonus, m.consumption_bonus, m.productivity_bonus
          end
        end
      end)
      profil(ctx, "R7 balayage effects", BN * REP, function()
        for _ = 1, REP do for i = 1, BN do local _c = bloc[i].effects end end
      end)
      profil(ctx, "R7 boucle vide (temoin)", BN * REP, function()
        for _ = 1, REP do for i = 1, BN do local _c = bloc[i] end end
      end)
    end

    -- Images (session avec images seulement) : interfaces ouvertes, show_gui.
    local p = game.connected_players[1]
    if p and st.cells and t >= T_GUI and t < T_GUI + 60 then
      local cibles = st.gui_cibles
      if not cibles then
        cibles = {}
        local function par_id(id)
          for _, c in ipairs(st.cells) do if c.id == id then return c.ms[c.principale].m end end
        end
        cibles[#cibles + 1] = { "r6-34-emplacements", st.z.m1 }
        cibles[#cibles + 1] = { "r4-v100000", par_id("R4-v100000") }
        cibles[#cibles + 1] = { "r4-p100000", par_id("R4-p100000") }
        cibles[#cibles + 1] = { "r3-centre-balise-cachee", par_id("R3-grille") }
        cibles[#cibles + 1] = { "r4-v32768", par_id("R4-v32768") }
        st.gui_cibles = cibles
      end
      local k = math.floor((t - T_GUI) / 10) + 1
      local phase = (t - T_GUI) % 10
      local cb = cibles[k]
      if cb and cb[2] and cb[2].valid then
        if phase == 0 then
          p.teleport({ cb[2].position.x, cb[2].position.y + 4 })
          local ok, err = pcall(function() p.opened = cb[2] end)
          if not ok then ctx.log("GUI " .. cb[1] .. " : opened refuse " .. tostring(err)) end
        elseif phase == 3 then
          game.take_screenshot({ path = "fo-shots/x-mod0-gui-" .. cb[1] .. ".png", player = p, show_gui = true,
            position = cb[2].position, zoom = 1, resolution = { 1920, 1080 }, force_render = true,
            allow_in_replay = true })
          ctx.log("GUI " .. cb[1] .. " : capture demandee, ouvert = " .. tostring(p.opened and p.opened.name))
        elseif phase == 6 then
          p.opened = nil
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    if not st.pret then
      ctx.fail("scenario pret", "prototypes de test absents : rien n'a ete mesure")
      return
    end
    local R = setmetatable({}, { __index = function() return {} end })
    for _, c in ipairs(st.cells) do
      local P = c.e / ((WB - WA) / 60)
      for j, rec in ipairs(c.ms) do
        local m = rec.m
        if m and m.valid and rec.a and rec.b then
          local recipe = m.type ~= "mining-drill" and (m.get_recipe() or (m.type == "furnace" and m.previous_recipe)) or nil
          local energie = recipe and recipe.energy or 1
          local crafts = rec.b.pf - rec.a.pf
          local frac = (rec.b.pf + rec.b.prog) - (rec.a.pf + rec.a.prog)
          local secs = (WB - WA) / 60
          local r = {
            sb = lit(m, "speed_bonus"), cb = lit(m, "consumption_bonus"), pb = lit(m, "productivity_bonus"),
            cs = lit(m, "crafting_speed"), bc = lit(m, "beacons_count"), crafts = crafts, items = rec.items,
            rate = rec.items / secs, crate = crafts / secs, speff = frac * energie / secs, P = P,
          }
          if j == c.principale then R[c.id] = r end
          R[c.id .. "#" .. j] = r
          ctx.log(string.format("MESURE %s [%s] %s : speed_bonus=%s consumption_bonus=%s productivity_bonus=%s "
            .. "crafting_speed=%s beacons=%s | fabrications=%d (%s/s) produits=%d (%s/s) vitesse_effective=%s "
            .. "| puissance_cellule=%s W | effects{%s} modules{%s} statut=%s",
            c.id, rec.role, m.name, f6(r.sb), f6(r.cb), f6(r.pb), f6(r.cs), f6(r.bc), crafts, f6(r.crate), rec.items,
            f6(r.rate), f6(r.speff), f6(P), effets(m), modules_txt(m.get_module_inventory()),
            tostring(m.status)))
          if rec.balise then
            local b = rec.balise
            ctx.log(string.format("MESURE %s balise cachee : valide=%s statut=%s effects{%s} recepteurs=%d modules{%s}",
              c.id, tostring(b.valid), tostring(b.valid and b.status), b.valid and effets(b) or "-",
              b.valid and #b.get_beacon_effect_receivers() or -1, b.valid and modules_txt(b.get_module_inventory()) or "-"))
          end
        else
          ctx.fail("mesure " .. c.id .. " #" .. j, "machine absente ou instantanes manquants")
        end
      end
      if c.vbal then
        ctx.log("MESURE " .. c.id .. " balise vanilla : modules " .. c.vbal_mis .. ", statut " .. tostring(c.vbal.status)
          .. ", effects{" .. effets(c.vbal) .. "}")
      end
    end
    local function near(a, b, tol) return a ~= nil and b ~= nil and math.abs(a - b) <= (tol or 1e-4) end
    local function rel(a, b, tol) return a ~= nil and b ~= nil and b ~= 0 and math.abs(a / b - 1) <= (tol or 0.03) end

    -- R1
    local r1 = near(R["R1-3xvit3"].sb, 1.5) and near(R["R1-3xvit3-balise"].sb, 2.0) and near(R["R1-3xv50"].sb, 1.5)
      and near(R["R1-paliers"].sb, 2.4) and near(R["R1-2xp10"].pb, 0.2)
    ctx.log(string.format("VERDICT R1 : %s ; vitesse 3 x vit3 %s (addition 1,5 / produit 2,375), + balise %s (2,0 / 3,0625), "
      .. "3 x +50 %% %s (1,5 / 2,375), paliers %s (2,4 / 4,67), prod 2 x 10 %% %s (0,2 / 0,21) ; consommation 3 x vit3 %s ; "
      .. "1,15 brut %s ; puissance temoin %s W, 3 x vit3 %s W, + balise %s W (dont balise vanilla 480 kW) ; "
      .. "fabrications/s temoin %s, 3 x vit3 %s, + balise %s, 3 x +50 %% %s, paliers %s",
      r1 and "OUI, les effets s'ADDITIONNENT" or "NON ou PARTIEL (voir MESURE)", f6(R["R1-3xvit3"].sb),
      f6(R["R1-3xvit3-balise"].sb), f6(R["R1-3xv50"].sb), f6(R["R1-paliers"].sb), f6(R["R1-2xp10"].pb),
      f6(R["R1-3xvit3"].cb), f6(R["R1-v115-brut"].sb), f6(R["R1-temoin"].P), f6(R["R1-3xvit3"].P),
      f6(R["R1-3xvit3-balise"].P), f6(R["R1-temoin"].crate), f6(R["R1-3xvit3"].crate), f6(R["R1-3xvit3-balise"].crate),
      f6(R["R1-3xv50"].crate), f6(R["R1-paliers"].crate)))
    -- R2
    local cap = rel(R["R2-asm-100"].crate, 60, 0.02) and rel(R["R2-asm-1000"].crate, 60, 0.02)
    ctx.log(string.format("VERDICT R2 : %s ; fabrications/s assembleur 10 %s (attendu 20), 100 %s (sans plafond 200), "
      .. "1 000 %s (sans plafond 2 000) ; produits/s 100 + prod 10 %% %s (doc : 80), 1 000 + prod 10 %% %s (doc : 260) ; "
      .. "four 1 %s, 10 %s, 100 %s, 1 000 %s (0,5 s : 2, 20, 200, 2 000) ; foreuse 1 %s, 10 %s, 100 %s, 1 000 %s "
      .. "(1 s : 1, 10, 100, 1 000)",
      cap and "OUI, au plus UNE fabrication par tick (60/s)" or "NON ou PARTIEL (voir MESURE)",
      f6(R["R2-asm-10"].crate), f6(R["R2-asm-100"].crate), f6(R["R2-asm-1000"].crate), f6(R["R2-asm-100-p10"].rate),
      f6(R["R2-asm-1000-p10"].rate), f6(R["R2-four-1"].rate), f6(R["R2-four-10"].rate), f6(R["R2-four-100"].rate),
      f6(R["R2-four-1000"].rate), f6(R["R2-foreuse-1"].rate), f6(R["R2-foreuse-10"].rate), f6(R["R2-foreuse-100"].rate),
      f6(R["R2-foreuse-1000"].rate)))
    -- R3
    local voisines_nulles, voisines_rate = 0, {}
    for j = 1, 9 do
      local r = R["R3-grille#" .. j]
      if j ~= 5 and r and near(r.sb, 0) and r.bc == 0 then voisines_nulles = voisines_nulles + 1 end
      if j ~= 5 and r then voisines_rate[#voisines_rate + 1] = f6(r.crate) end
    end
    local centre = R["R3-grille#5"]
    local vb = st.verif1150 or {}
    local ve = st.verif1250 or {}
    ctx.log(string.format("VERDICT R3 : %s ; centre speed_bonus %s, %s fab/s ; voisines collees sans effet : %d/8 "
      .. "(fab/s %s) ; bloc de %d machines collees : bonus juste %s/%s, beacons_count=1 %s, 1 seule receptrice %s ; "
      .. "apres echange : bonus juste %s",
      (centre and near(centre.sb, 1) and voisines_nulles == 8 and vb.bons == BN and vb.rec1 == BN)
        and "OUI, la balise cachee n'agit que sur SA machine" or "NON ou PARTIEL (voir MESURE)",
      f6(centre and centre.sb), f6(centre and centre.crate), voisines_nulles, table.concat(voisines_rate, " "), BN,
      tostring(vb.bons), BN, tostring(vb.bc1), tostring(vb.rec1), tostring(ve.bons)))
    -- R4
    ctx.log(string.format("VERDICT R4 (vitesse) : +10 sb %s (%s fab/s, attendu 0,2) ; +100 sb %s (%s fab/s, attendu 0,101) ; "
      .. "+1 000 sb %s (%s fab/s, attendu 1,001) ; +1 000 en balise sb %s (%s fab/s) ; 327,67 sb %s (%s fab/s, attendu 0,0329)"
      .. " ; 327,68 sb %s (%s fab/s) ; 2 x 200 sb %s (%s fab/s, attendu 0,0401)",
      f6(R["R4-v1000"].sb), f6(R["R4-v1000"].crate), f6(R["R4-v10000"].sb), f6(R["R4-v10000"].crate),
      f6(R["R4-v100000"].sb), f6(R["R4-v100000"].crate), f6(R["R4-v100000-balise"].sb), f6(R["R4-v100000-balise"].crate),
      f6(R["R4-v32767"].sb), f6(R["R4-v32767"].crate), f6(R["R4-v32768"].sb), f6(R["R4-v32768"].crate),
      f6(R["R4-2xv20000"].sb), f6(R["R4-2xv20000"].crate)))
    ctx.log(string.format("VERDICT R4 (consommation, productivite) : conso +10 cb %s P %s W (1,1 MW) ; +100 cb %s P %s W "
      .. "(10,1 MW) ; +1 000 cb %s P %s W (100,1 MW) ; prod +10 pb %s %s produits/s (22) ; +100 pb %s %s/s (202) ; "
      .. "+1 000 pb %s %s/s (2 002) ; prod vanilla en BALISE pb %s (%s/s) ; en MACHINE : %d insere(s), pb %s",
      f6(R["R4-c1000"].cb), f6(R["R4-c1000"].P), f6(R["R4-c10000"].cb), f6(R["R4-c10000"].P), f6(R["R4-c100000"].cb),
      f6(R["R4-c100000"].P), f6(R["R4-p1000"].pb), f6(R["R4-p1000"].rate), f6(R["R4-p10000"].pb), f6(R["R4-p10000"].rate),
      f6(R["R4-p100000"].pb), f6(R["R4-p100000"].rate), f6(R["R4-prodvanilla-balise"].pb),
      f6(R["R4-prodvanilla-balise"].rate), (function()
        for _, c in ipairs(st.cells) do if c.id == "R4-prodvanilla-machine" then return c.ms[1].mis end end
        return -1
      end)(), f6(R["R4-prodvanilla-machine"].pb)))
    -- R5
    local tem = R["R5-1gw-temoin-sur-10mw#2"]
    local tem2 = R["R5-1tw-flux1mw-temoin-sur-10mw#2"]
    ctx.log(string.format("VERDICT R5 : 1 GW illimite %s fab/s P %s W ; 1 TW illimite %s fab/s P %s W ; 1 GW sur 1 MW "
      .. "vitesse effective %s (ratio attendu 0,001) P %s W ; 1 TW sur 1 MW vitesse effective %s (1e-6) P %s W ; "
      .. "1 GW + temoin sur 10 MW : temoin %s fab/s (2 si protege, 0,02 si partage proportionnel), 1 GW vitesse %s ; "
      .. "input_flow_limit 10 kW : vitesse %s (0,1 attendu) P %s W ; 1 TW limite a 1 MW + temoin sur 10 MW : temoin "
      .. "%s fab/s, 1 TW vitesse %s, P %s W ; tampon 10 MJ sur 1 MW : %s fab/s, P %s W",
      f6(R["R5-1gw-illimite"].crate), f6(R["R5-1gw-illimite"].P), f6(R["R5-1tw-illimite"].crate),
      f6(R["R5-1tw-illimite"].P), f6(R["R5-1gw-sur-1mw"].speff), f6(R["R5-1gw-sur-1mw"].P),
      f6(R["R5-1tw-sur-1mw"].speff), f6(R["R5-1tw-sur-1mw"].P), f6(tem and tem.crate),
      f6(R["R5-1gw-temoin-sur-10mw"].speff), f6(R["R5-flux-10kw"].speff), f6(R["R5-flux-10kw"].P),
      f6(tem2 and tem2.crate), f6(R["R5-1tw-flux1mw-temoin-sur-10mw"].speff), f6(R["R5-1tw-flux1mw-temoin-sur-10mw"].P),
      f6(R["R5-tampon-10mj-sur-1mw"].crate), f6(R["R5-tampon-10mj-sur-1mw"].P)))
    -- R6
    local z = st.z
    local s = ctx.surface()
    local g = s.find_entity("mod0-asm-1", z.ghost_pos)
    local bras = {}
    for i, b in ipairs(z.bras) do
      bras[#bras + 1] = string.format("%s recette : %d module(s) dans la machine, %d dans le coffre, main du bras %s",
        b.avec and "avec" or "sans", b.m.get_module_inventory().get_item_count(), b.ch.get_item_count(),
        b.ins.held_stack.valid_for_read and (b.ins.held_stack.name .. "x" .. b.ins.held_stack.count) or "vide")
    end
    ctx.log(string.format("VERDICT R6 : machine 34 emplacements remplie par robots : %d/34 (complete au tick %s) ; "
      .. "fantome bati : %s, %d module(s) livre(s) sur 34 ; bras : %s",
      z.m1.get_module_inventory().get_item_count(), tostring(st.m1_tick), tostring(g ~= nil),
      g and g.get_module_inventory().get_item_count() or -1, table.concat(bras, " | ")))
    ctx.check(z.m1.get_module_inventory().get_item_count() == 34, "R6 : 34 modules livres par robots (protocole : robots actifs)")
    -- R7
    local ev = global.mod0_evts or {}
    local cpt, noms = {}, {}
    for _, x in ipairs(ev) do
      local k = x.name .. " " .. x.ent
      if not cpt[k] then cpt[k] = 0; noms[#noms + 1] = k end
      cpt[k] = cpt[k] + 1
    end
    table.sort(noms)
    local t = {}
    for _, k in ipairs(noms) do t[#t + 1] = k .. " x" .. cpt[k] end
    for _, x in ipairs(ev) do ctx.log("EVT tick " .. x.tick .. " " .. x.name .. " " .. x.ent) end
    ctx.log("VERDICT R7 : evenements leves pendant R6/R7 : " .. (#t > 0 and table.concat(t, " ; ") or "AUCUN")
      .. " ; machine sous le plan : modules " .. modules_txt(z.m2.get_module_inventory()) .. " (proxys du plan : "
      .. tostring(st.plan_proxies) .. ") ; livraisons par robots (34 + 34 modules) : aucun evenement dedie attendu")
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    if not st.pret then return end
    local z = st.z
    add("r6-machine-34-modules-alt", z.m1.position.x, z.m1.position.y, 2, 0, { info = true })
    add("r6-fantome-bati-alt", z.ghost_pos[1], z.ghost_pos[2], 2, 0, { info = true })
    add("r6-bras-alt", RX - 21, RY + 4, 1.5, 0, { info = true })
    for _, c in ipairs(st.cells) do
      if c.id == "R3-grille" then add("r3-grille-alt", c.x, c.y, 1.5, 0, { info = true }) end
      if c.id == "R1-3xvit3-balise" then add("r1-balise-alt", c.x, c.y + 1.5, 2, 0, { info = true }) end
      if c.id == "R4-v100000" then add("r4-v100000-alt", c.x, c.y, 2, 0, { info = true }) end
    end
    add("r3-bloc", BX0 + 20, BY0 + 12, 0.5, 0, { info = true })
  end,
}
