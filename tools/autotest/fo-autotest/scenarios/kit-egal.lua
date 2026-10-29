--[[
  Lot KIT (28/10) : le kit de départ des factions est celui de votre équipe, et l'interrupteur des bancs rend l'ancien.
  Réponse du DC : « idéalement il faudrait vraiment pas leur donner de ressources : ils ne doivent pas avoir plus que le
  joueur principal, ils doivent eux-mêmes récolter les ressources nécessaires au début ; pour les tests c'est plus simple
  qu'ils aient des ressources de base ».
    - tick 100 : kit égal (réglage fo-war-kit-genereux éteint) : à la fondation, chaque QG a un coffre SANS foreuse, four,
      coffre, plaque ni bois ; aucun four posé au QG ; les ouvriers de départ sont là ; les 4 gisements semés aussi ;
    - tick 110 : guerre arrêtée, réglage allumé, guerre relancée (refondation : le réglage est relu à la fondation) ;
    - tick 200 : kit généreux : le coffre contient l'ancien kit (12 foreuses, 8 fours moins les 2 posés, plaques…), 2 fours
      posés, pas de bois.
  Lancement : `fo-autotest.bat nopause 300 kit-egal <source>` (ou par la file, banc.py). Journal : [FO-KIT-EGAL].
]]

local function qg_list(ctx)
  local out = {}
  for _, row in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = row end
  end
  return out
end

local function snapshot(ctx)
  local s = ctx.surface()
  local out = {}
  for _, r in ipairs(qg_list(ctx)) do
    local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = r.force, limit = 1 })[1]
    local c = {}
    local inv = hq and hq.get_inventory(defines.inventory.chest)
    if inv then c = inv.get_contents() end
    local total = 0
    for _, n in pairs(c) do total = total + n end
    out[#out + 1] = {
      key = r.key, hq = hq ~= nil, contents = c, total = total,
      furnaces = s.count_entities_filtered({ type = "furnace", force = r.force }),
      workers = r.n or 0,
      seeded = hq and s.count_entities_filtered({ position = hq.position, radius = 80, type = "resource" }) or 0,
    }
  end
  return out
end

local function describe(snap)
  local parts = {}
  for _, r in ipairs(snap) do
    local items = {}
    local names = {}
    for n in pairs(r.contents) do names[#names + 1] = n end
    table.sort(names)
    for _, n in ipairs(names) do items[#items + 1] = n .. "=" .. r.contents[n] end
    parts[#parts + 1] = string.format("%s : %d objet(s) [%s], %d four(s), %d ouvrier(s), %d tuile(s) de gisement", r.key, r.total,
      table.concat(items, " "), r.furnaces, r.workers, r.seeded)
  end
  return table.concat(parts, " | ")
end

return {
  description = "KIT : kit de depart des factions egal a celui du joueur ; interrupteur des bancs",
  base = nil,
  check_tick = 250,

  init = function(ctx)
    local k = ctx.call("war_setting", "fo-war-kit-genereux", false)
    ctx.check(k == false, "kit genereux eteint (kit egal)", tostring(k))
    local started = ctx.call("war_start", 2, 5, 4)
    ctx.check(started == true, "guerre lancee (2 factions)", tostring(started))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if e.tick == 100 then
      st.egal = snapshot(ctx)
      ctx.log("kit egal : " .. describe(st.egal))
    elseif e.tick == 110 then
      st.stopped = ctx.remote("factorio-overhaul", "war_stop")
      st.set = ctx.call("war_setting", "fo-war-kit-genereux", true)
    elseif e.tick == 120 then
      st.restarted = ctx.call("war_start", 2, 5, 4)
    elseif e.tick == 200 then
      st.gen = snapshot(ctx)
      ctx.log("kit genereux : " .. describe(st.gen))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.egal and #st.egal == 2, "2 QG au tick 100", st.egal and #st.egal or -1)
    for _, r in ipairs(st.egal or {}) do
      ctx.check(r.hq and r.total == 0, r.key .. " : coffre du QG VIDE en kit egal (comme le coffre d'equipe du joueur)", r.total)
      ctx.check(r.furnaces == 0, r.key .. " : aucun four pose au depart en kit egal", r.furnaces)
      ctx.check(r.workers >= 2, r.key .. " : des ouvriers de depart sont la", r.workers)
      ctx.check(r.seeded > 0, r.key .. " : gisements de depart semes (inchange)", r.seeded)
    end
    ctx.check(st.stopped ~= nil and st.set == true and st.restarted == true, "guerre arretee, reglage allume, guerre relancee",
      tostring(st.stopped) .. "/" .. tostring(st.set) .. "/" .. tostring(st.restarted))
    ctx.check(st.gen and #st.gen == 2, "2 QG apres la refondation", st.gen and #st.gen or -1)
    for _, r in ipairs(st.gen or {}) do
      ctx.check((r.contents["burner-mining-drill"] or 0) >= 12 and (r.contents["iron-plate"] or 0) >= 200,
        r.key .. " : kit genereux = ancien contenu (12 foreuses, 200 plaques de fer)", r.total)
      ctx.check(r.furnaces == 2, r.key .. " : 2 fours poses au QG en kit genereux", r.furnaces)
      ctx.check((r.contents["wood"] or 0) == 0, r.key .. " : pas de bois au depart, meme en kit genereux", r.contents["wood"] or 0)
    end
  end,
}
