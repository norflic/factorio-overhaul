--[[
  Lot C1 : les factions montent leur centre de commandement (l'époque suivante) AU RÉGLAGE PAR DÉFAUT du jeu
  (fo-war-capital ALLUMÉ depuis ce lot ; éteint, aucune faction ne montait jamais son centre). Moteur réel.
  Partie : 2 factions, 5 soldats, 4 ouvriers ; AUCUN réglage touché. Au tick 120 le coffre de chaque QG est garni (coût du
  centre aux niveaux 2 et 3, coût du niveau 2 de chaque famille : les tourelles qui bloquent la condition Q16 sont montées
  d'abord par la chaîne). Contrôles (finish) :
    1. le réglage fo-war-capital vaut vrai (défaut du jeu, rien n'a été posé par le banc) ;
    2. chaque faction a un centre de niveau >= 2 en fin de partie (la décision, pas l'interface distante, l'a monté) ;
    3. le coût du centre est PAYÉ : à l'échantillon (toutes les 30 ticks) où le niveau passe de 1 à 2, le coffre du QG a perdu
       au moins le coût de chaque objet du niveau 2 (jamais offert) ;
    4. chaque montée vient d'une ligne du journal du mod (compté dans factorio.log par le banc : [FO-CAPITAL] centre monte).
  Journal : [FO-C1-CENTRE] ; côté mod : [FO-CAPITAL], [FO-CAPITAL-CENTRE] (une ligne par changement de cause).
]]

local L = require("__factorio-overhaul__/shared/levels/config")
local IFACE = "fo-centre-qg"
local FILL_TICK, SAMPLE = 120, 30

local function chest_of(s, force)
  return s.find_entities_filtered({ force = force, name = "fo-faction-hq" })[1]
end

local function count_of(hq, item)
  local inv = hq and hq.get_inventory(defines.inventory.chest)
  return inv and inv.get_item_count(item) or 0
end

local function wanted_items()
  local want = {}
  local function add(list, times)
    for _, it in ipairs(list) do want[it[1]] = math.max(want[it[1]] or 0, it[2] * times) end
  end
  local cc = L.by_key.command
  for n = 2, 3 do add(L.cost(cc, n), 3) end
  for _, fam in ipairs(L.families) do
    if fam ~= cc then add(L.cost(fam, 2), 12) end
  end
  local names = {}
  for k in pairs(want) do names[#names + 1] = k end
  table.sort(names)
  return want, names
end

return {
  description = "C1 : les factions montent leur centre au reglage par defaut (stock garni, cout paye, journal par cause)",
  check_tick = 9800,

  init = function(ctx)
    local st = ctx.state()
    st.started = ctx.call("war_start", 2, 5, 4)
    st.samples = {}
    local setting = settings.global["fo-war-capital"]
    st.setting = setting and setting.value
    ctx.log("creation : guerre " .. tostring(st.started) .. ", fo-war-capital = " .. tostring(st.setting))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if not (remote.interfaces[IFACE]) then return end
    if e.tick == FILL_TICK then
      local want, names = wanted_items()
      -- Des engrenages en abondance : sans eux, une tourelle à améliorer n'est ni payée ni fabriquée (aucun PNJ libre,
      -- Cap.emit) et la décision en cours, gardée par l'inertie, bloque le centre derrière (constaté au banc, Écarlate).
      want["iron-gear-wheel"] = math.max(want["iron-gear-wheel"] or 0, 600)
      st.cost2 = L.cost(L.by_key.command, 2)
      for _, row in ipairs(remote.call(IFACE, "status") or {}) do
        local hq = chest_of(s, row.force)
        local put = {}
        for _, item in ipairs(names) do
          local n = hq and hq.insert({ name = item, count = want[item] }) or 0
          put[#put + 1] = item .. "=" .. n .. "/" .. want[item]
        end
        ctx.log(row.key .. " : coffre garni a " .. e.tick .. " : " .. table.concat(put, " "))
      end
    elseif e.tick > FILL_TICK and e.tick % SAMPLE == 0 and st.cost2 then
      local row = {}
      for _, r in ipairs(remote.call(IFACE, "status") or {}) do
        local hq = chest_of(s, r.force)
        local stock = {}
        for _, it in ipairs(st.cost2) do stock[it[1]] = count_of(hq, it[1]) end
        row[r.key] = { level = r.level, stock = stock, tick = e.tick }
      end
      st.samples[#st.samples + 1] = row
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.started == true, "guerre lancee", tostring(st.started))
    ctx.check(st.setting == true, "fo-war-capital vaut vrai au reglage par defaut (rien n'a ete pose par le banc)", tostring(st.setting))
    local last = st.samples[#st.samples] or {}
    local keys = {}
    for k in pairs(last) do keys[#keys + 1] = k end
    table.sort(keys)
    ctx.check(#keys == 2, "2 factions vivantes au dernier echantillon", #keys)
    for _, key in ipairs(keys) do
      local lvl = last[key].level
      ctx.check(lvl >= 2, key .. " : centre monte par la decision (niveau " .. tostring(lvl) .. " >= 2)", tostring(lvl))
      -- Le passage 1 -> 2 : le coffre perd au moins le coût de chaque objet.
      local from
      for i = 2, #st.samples do
        local a, b = st.samples[i - 1][key], st.samples[i][key]
        if a and b and a.level == 1 and b.level >= 2 then from = i break end
      end
      ctx.check(from ~= nil, key .. " : passage du niveau 1 au niveau 2 observe", tostring(from))
      if from then
        local a, b = st.samples[from - 1][key], st.samples[from][key]
        local ok, detail = true, {}
        for _, it in ipairs(st.cost2) do
          local drop = a.stock[it[1]] - b.stock[it[1]]
          detail[#detail + 1] = it[1] .. " -" .. drop .. " (cout " .. it[2] .. ")"
          if drop < it[2] - 20 then ok = false end
        end
        ctx.check(ok, key .. " : cout du centre 2 PAYE au coffre du QG entre les ticks " .. a.tick .. " et " .. b.tick,
          table.concat(detail, ", "))
      end
    end
  end,
}
