--[[
  Lot X10-GEL, FAIT MOTEUR pour l'option (ii) du lead (8/11) : écrire `mining_progress` et `bonus_mining_progress` d'une foreuse à
  l'arrêt (active = false).
    py -3.9 -B tools/autotest/banc.py --qui X10-GEL-F --out <archive> -- 900 x10-gel-progres <source>

  Doc 1.1.91 (doc-html/runtime-api.json, LuaEntity.mining_progress et bonus_mining_progress, lecture et écriture) : « a number in range
  [0, mining_target.prototype.mineable_properties.mining_time] ». Le fer (mining_time 1) ne distingue pas cette plage de [0, 1]
  (relecture du lead, 8/11 vers 6 h) : paires sur un minerai du mod à mining_time 2 et sur un autre à mining_time ≠ 1.
  Le fait à prouver : « aucune fabrication gratuite, et la progression écrite est bien reprise, en unités de mining_time ».
  Paires de foreuses thermiques identiques (foreuse -> coffre, même minerai, même charbon), posées au même tick, sans lien avec le gel :
    tick 60  : les foreuses passent active = false ; progressions relues (égales dans chaque paire) ; pour la foreuse D, écriture de
               p × mining_time dans mining_progress (ou bonus_mining_progress, force à +50 % de productivité minière) ; relue aussitôt ;
    tick 99  : progressions de la jumelle T inchangées depuis 60 (une foreuse à l'arrêt les garde) ;
    tick 100 : toutes repassent active = true ;
    tick 880 : bilan : premier dépôt de D au tick attendu en unités de mining_time (et pas à celui d'une plage [0, 1]), minerais de D et T
               exactement ceux que leurs progressions et le temps de marche donnent (aucune fabrication gratuite).
]]

local X0, Y0 = 6000, 3000
local COAL = 10
-- Cas : minerai (nil = fer ; « mt2 » : un minerai solide du mod à mining_time 2 ; « mt? » : un autre à mining_time ni 1 ni 2, de
-- préférence < 1), fraction p de mining_time écrite dans la progression, ou dans la progression de PRODUCTIVITÉ (bonus = true).
local CASES = {
  { p = 0.10 }, { p = 0.50 }, { p = 0.95 },
  { ore = "mt2", p = 0.50 }, { ore = "mt2", p = 0.95 },
  { ore = "mt?", p = 0.50 }, { ore = "mt?", p = 0.95 },
  { p = 0.90, bonus = true },
}

--- Minerais solides (catégorie basic-solid, sans fluide, objet), triés par nom : le premier à mining_time 2 ; le premier à mining_time
--- ni 1 ni 2 (de préférence < 1).
local function pick_ores()
  local names = {}
  for name, pr in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "resource" } })) do
    local mp = pr.mineable_properties
    if pr.resource_category == "basic-solid" and mp and mp.minable and not mp.required_fluid and not pr.infinite_resource
      and mp.products and mp.products[1] and mp.products[1].type == "item" then names[#names + 1] = name end
  end
  table.sort(names)
  local two, low, other
  for _, name in ipairs(names) do
    local mt = game.entity_prototypes[name].mineable_properties.mining_time
    if mt == 2 and not two then two = name end
    if mt ~= 1 and mt ~= 2 then
      if mt < 1 and not low then low = name end
      if not other then other = name end
    end
  end
  return two, low or other
end

local function pair_at(s, i, force, ore_name)
  local out = {}
  for j, tag in ipairs({ "D", "T" }) do
    local px, py = X0 + (i - 1) * 10 + (j - 1) * 5, Y0
    for _, dx in ipairs({ -0.5, 0.5 }) do
      for _, dy in ipairs({ -0.5, 0.5 }) do s.create_entity({ name = ore_name, position = { px + dx, py + dy }, amount = 1000 }) end
    end
    local d = s.create_entity({ name = "burner-mining-drill", position = { px, py }, direction = defines.direction.north, force = force })
    local dp = d.drop_position
    local c = s.create_entity({ name = "wooden-chest", position = { math.floor(dp.x) + 0.5, math.floor(dp.y) + 0.5 }, force = force })
    d.insert({ name = "coal", count = COAL })
    out[tag] = { d = d, c = c }
  end
  return out
end

--- Objets au coffre (tous, triés par nom : aucun ordre de pairs).
local function ore(c)
  local inv = c.get_inventory(defines.inventory.chest)
  local contents = inv.get_contents()
  local names = {}
  for n in pairs(contents) do names[#names + 1] = n end
  table.sort(names)
  local total = 0
  for _, n in ipairs(names) do total = total + contents[n] end
  return total
end

return {
  description = "X10-GEL fait moteur : mining_progress et bonus_mining_progress ecrits sur une foreuse a l'arret",
  check_tick = 880,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    local t = e.tick
    if t == 10 then
      ctx.prepare_area(X0 - 10, Y0 - 10, X0 + 10 * #CASES + 10, Y0 + 10, "grass-1")
      for _, fo in ipairs({ "fo-gel-p", "fo-gel-pb" }) do
        if not game.forces[fo] then game.create_force(fo) end
        game.forces[fo].set_cease_fire("enemy", true)
        game.forces.enemy.set_cease_fire(fo, true)
      end
      game.forces["fo-gel-pb"].mining_drill_productivity_bonus = 0.5
      local two, other = pick_ores()
      ctx.log(string.format("minerais : mining_time 2 = %s ; autre = %s (mining_time %s)", tostring(two), tostring(other),
        other and tostring(game.entity_prototypes[other].mineable_properties.mining_time) or "-"))
      st.pairs = {}
      for i, c in ipairs(CASES) do
        local name = (c.ore == "mt2" and two) or (c.ore == "mt?" and other) or (c.ore == nil and "iron-ore") or nil
        if name then
          local P = pair_at(s, i, c.bonus and "fo-gel-pb" or "fo-gel-p", name)
          local mt = game.entity_prototypes[name].mineable_properties.mining_time
          P.mt, P.cycle, P.name, P.case = mt, mt / (P.D.d.prototype.mining_speed / 60), name, c
          st.pairs[#st.pairs + 1] = P
          ctx.log(string.format("paire %d : %s, mining_time %.3f, cycle %.1f ticks%s", #st.pairs, name, mt, P.cycle,
            c.bonus and ", productivite +50 %" or ""))
        else
          ctx.log("cas " .. i .. " : non joue (aucun minerai " .. tostring(c.ore) .. ")")
        end
      end
    elseif t == 60 then
      st.w = {}
      for i, P in ipairs(st.pairs) do
        local p = P.case.p
        P.D.d.active, P.T.d.active = false, false
        local pd, pt = P.D.d.mining_progress, P.T.d.mining_progress
        local bd, bt = P.D.d.bonus_mining_progress, P.T.d.bonus_mining_progress
        local want = p * P.mt
        local field = P.case.bonus and "bonus_mining_progress" or "mining_progress"
        P.D.d[field] = want
        local back = P.D.d[field]
        st.w[i] = { p0 = pd, pt = pt, b0 = bd, bt = bt, want = want, back = back, c0D = ore(P.D.c), c0T = ore(P.T.c) }
        ctx.log(string.format("paire %d : progression D %.4f, T %.4f ; productivite D %.4f, T %.4f ; ecrite (%s) %.4f, relue %.4f",
          i, pd, pt, bd, bt, field, want, back))
        ctx.check(math.abs(back - want) < 1e-6, string.format("fait : %s ecrit sur une foreuse a l'arret relu tel quel (%s, %.2f de mining_time %.2f)",
          field, P.name, p, P.mt), string.format("%.6f / %.6f", back, want))
      end
    elseif t == 99 then
      for i, P in ipairs(st.pairs) do
        local w = st.w[i]
        ctx.check(math.abs(P.T.d.mining_progress - w.pt) < 1e-9 and math.abs(P.T.d.bonus_mining_progress - w.bt) < 1e-9,
          "fait : une foreuse a l'arret garde sa progression et sa progression de productivite (paire " .. i .. ")")
      end
    elseif t == 100 then
      for i = 1, #st.pairs do st.pairs[i].D.d.active, st.pairs[i].T.d.active = true, true end
    end
    if st.w and t > 100 then
      for i = 1, #st.pairs do
        local P, w = st.pairs[i], st.w[i]
        if not w.firstD and ore(P.D.c) > w.c0D then w.firstD = t end
        if not w.firstT and ore(P.T.c) > w.c0T then w.firstT = t end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local span = 880 - 100
    for i, P in ipairs(st.pairs) do
      local w, p = st.w[i], P.case.p
      local nD, nT = ore(P.D.c) - w.c0D, ore(P.T.c) - w.c0T
      local runs = span / P.cycle -- cycles de marche après le réveil
      local fT, bT = w.pt / P.mt, w.bt / P.mt
      local expT = math.floor(fT + runs) + (P.case.bonus and math.floor(bT + 0.5 * runs) or 0)
      local expD, tD, tD01
      if P.case.bonus then
        expD = math.floor(w.p0 / P.mt + runs) + math.floor(p + 0.5 * runs)
      else
        expD = math.floor(p + runs)
        tD = 100 + (1 - p) * P.cycle -- plage [0, mining_time] (doc)
        tD01 = 100 + (P.mt - p) / (P.D.d.prototype.mining_speed / 60) -- si la plage était [0, 1] (p écrit tel quel)
      end
      local tT = 100 + (1 - fT) * P.cycle
      ctx.log(string.format("paire %d (%s, mining_time %.2f, %s p = %.2f) : premier depot D %s (attendu %s ; plage 0..1 : %s), T %s (attendu %.0f) ; minerais D %d (attendu %d), T %d (attendu %d)",
        i, P.name, P.mt, P.case.bonus and "productivite" or "progression", p, tostring(w.firstD), tD and string.format("%.0f", tD) or "-",
        tD01 and string.format("%.0f", tD01) or "-", tostring(w.firstT), tT, nD, expD, nT, expT))
      if tD then
        ctx.check(w.firstD ~= nil and math.abs(w.firstD - tD) <= 2.5,
          string.format("fait : la progression ecrite est reprise en unites de mining_time (%s, mining_time %.2f, p = %.2f)", P.name, P.mt, p),
          tostring(w.firstD) .. " / " .. string.format("%.0f", tD))
      end
      ctx.check(nD == expD, string.format("fait : aucune fabrication gratuite (%s, %s p = %.2f)", P.name,
        P.case.bonus and "productivite" or "progression", p), nD .. " / " .. expD)
      ctx.check(nT == expT and w.firstT ~= nil and math.abs(w.firstT - tT) <= 2.5, "temoin T : depots au rythme de sa propre progression (paire " .. i .. ")",
        nT .. " / " .. expT .. ", premier " .. tostring(w.firstT))
    end
  end,
}
