--[[
  Lot STOCKAGE-VITAL (retour du DC sur 0.6.58, 7/11 : « ils se sont retrouvés avec des coffres remplis de pierres […] ils ont pas pensé
  à poser des coffres ») : micro-banc du COFFRE URGENT en moteur réel, sans sauvegarde, moins de 5 000 ticks.

  Scène (tick SETUP = 300 ; votre équipe naît à la pose du coffre d'équipe au tick 0, avec ses 8 PNJ offerts) :
    * le coffre du QG est vidé puis REMPLI DE PIERRE jusqu'à la dernière case (comme une partie de 0.6.58 : la réserve des vitales
      n'existait pas), 1 case de charbon, AUCUNE plaque ni minerai de fer ;
    * 4 des 8 PNJ sont retirés (fo-ia1 kill_npc) : l'équipe est SOUS son effectif de départ, donc fond coupé (comme le DC de 87 à
      118 min) ; les 4 restants ont chacun 100 plaques de fer EN POCHE (ce qu'un PNJ rapporte d'un avant-poste) ;
    * arbres retirés à moins de R_TREES tuiles du coffre, puis selon VARIANT :
        "bois"     : 20 bois dans le coffre plein (une case), aucun arbre ;
        "arbres"   : aucun bois, 8 arbres plantés à 10-16 tuiles du coffre ;
        "sans-bois": ni bois ni arbre (et pas de fer) : rien ne permet de fabriquer un coffre.

  CRITÈRES (écrits AVANT le premier passage ; N = 60 s) :
    S1  scène posée : coffre du QG plein (toutes les cases), fer 0 au coffre, équipe sous son effectif de départ, bois et arbres
        conformes à la variante ;
    "bois" et "arbres" :
    C1  une annexe (coffre de votre force autour du QG) posée au plus N = 60 s après SETUP, et la PREMIÈRE est un coffre en BOIS
        (le fer est à 0 : le coffre urgent ne dépend pas du fer) ;
    C2  [FO-STOCKAGE] : au moins une ligne de raison du coffre urgent (compteur f.stats.stock_logs lu par la sonde ; la ligne se
        relit aussi dans le journal, commande du rapport) ;
    C3  [FO-ANNEXE] : au moins une annexe posée par le mod (compteur f.stats.annex_placed) ;
    C4  fer ENTRÉ au stock : « livre fer » de votre équipe (f.team.delivered, fo-ia1 teams) en hausse d'au moins 100 après SETUP ;
    C5  pierre plus ramassée : à CHECK, Stock.skip_fn écarte la pierre (sonde, verdict du ramassage des avant-postes) ET la pierre du
        stock (QG + annexes) n'a jamais dépassé son total de SETUP ;
    "sans-bois" :
    C1' aucune annexe posée (aucune matière : limite connue, écrite au rapport) ;
    C2' [FO-STOCKAGE] : au moins une ligne de raison, et la dernière raison lue (f.stock_why) n'est pas vide ;
    toutes : sonde du coût de Stock.insert par COMPTEUR D'INSTRUCTIONS (debug.sethook, période 1 ; jamais os.clock), au tick
    SETUP + 60 (stock plein) et à CHECK - 60 : fer (vital) et pierre, 50 objets, 100 dépôts ; mesure, sans seuil.
  Contrôles à CHECK = 4 500 ; banc : `banc.py ... -- 4600 stockage-plein-<variante> <source>` ; journal : [FO-STOCKAGE-PLEIN-<VARIANTE>].
  Témoin : la même scène sur 0e340b99 (0.6.58), où C1 à C5 doivent échouer (rien n'est posé) ; la sonde y est absente sauf si
  le témoin porte le seul remote de mesure (fo-ia1 stock_cost, lecture seule).
]]
return function(VARIANT)
local SETUP, CHECK = 300, 4500
local N = 60 * 60          -- C1 : annexe posée au plus 60 s après la scène
local R_TREES = 100        -- arbres retirés autour du coffre (le minage à la main cherche à 96 tuiles)
local KILL = 4             -- PNJ retirés (8 offerts au départ) : sous l'effectif de départ
local POCKET = 100         -- plaques de fer en poche par PNJ restant
local WOOD_IN_CHEST = 20
local ANNEX_NAMES = { "wooden-chest", "iron-chest" }
local PROBE_N, PROBE_REPS = 50, 100

local function inv_of(e) return e.get_inventory(defines.inventory.chest) end
local function fill_of(e)
  local inv = inv_of(e)
  return #inv - inv.count_empty_stacks(), #inv
end

local function annexes(s, qg)
  local p = qg.position
  local out = {}
  for _, e in ipairs(s.find_entities_filtered({ area = { { p.x - 30, p.y - 30 }, { p.x + 30, p.y + 30 } }, force = "player",
    name = ANNEX_NAMES })) do
    if e ~= qg then out[#out + 1] = e end
  end
  table.sort(out, function(a, b) return a.unit_number < b.unit_number end)
  return out
end

local function total(s, qg, item)
  local n = qg.get_item_count(item)
  for _, e in ipairs(annexes(s, qg)) do n = n + e.get_item_count(item) end
  return n
end

local function tree_name()
  local protos = game.get_filtered_entity_prototypes({ { filter = "type", type = "tree" } })
  local names = {}
  for name, p in pairs(protos) do
    local mp = p.mineable_properties
    for _, pr in ipairs(mp and mp.products or {}) do
      if pr.name == "wood" then names[#names + 1] = name break end
    end
  end
  table.sort(names)
  return names[1]
end

local function player_row(ctx)
  for _, r in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if r.key == "player" then return r end
  end
  return nil
end

local function delivered_iron(ctx)
  local r = player_row(ctx)
  return r and (r.delivered or {})["iron-plate"] or 0
end

local function probe(ctx, item)
  if not ctx.has("fo-ia1", "stock_cost") then return nil end
  local ok, res = pcall(ctx.remote, "fo-ia1", "stock_cost", "player", item, PROBE_N, PROBE_REPS)
  return ok and res or nil
end

local function probe_line(ctx, when, item, r)
  if not r then
    ctx.log(string.format("SONDE %s %s : absente (remote fo-ia1 stock_cost)", when, item))
  elseif not r.hook then
    ctx.log(string.format("SONDE %s %s : debug.sethook indisponible", when, item))
  else
    ctx.log(string.format("SONDE %s %s : %.1f instructions et %.1f appels par Stock.insert de %d (%d depots, %d objets pris), %d inventaire(s), %d annexe(s), ecarte du ramassage %s",
      when, item, r.instr, r.calls, PROBE_N, r.reps, r.put, r.inventaires, r.annexes, tostring(r.skip_item)))
  end
end

return {
  description = "STOCKAGE-VITAL : coffre du QG plein de pierre, fer a 0, equipe sous son effectif ; variante " .. VARIANT,
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local c = game.forces.player.get_spawn_position(s)
    local p = s.find_non_colliding_position("fo-team-chest", { x = c.x + 6, y = c.y + 6 }, 20, 1)
    local chest = p and s.create_entity({ name = "fo-team-chest", position = p, force = "player", raise_built = true })
    if chest then
      for _, it in ipairs({ { "pistol", 3 }, { "firearm-magazine", 60 }, { "coal", 200 }, { "copper-plate", 100 }, { "iron-plate", 100 } }) do
        chest.insert({ name = it[1], count = it[2] })
      end
    end
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    ctx.state().chest = chest
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    local qg = st.chest
    if not (qg and qg.valid) then return end
    local s = ctx.surface()
    local t = e.tick
    if t == SETUP then
      local team = ctx.remote("fo-ia1", "team_status", "player")
      st.n0 = team and #team.npcs or 0
      st.floor = math.min(settings.global["fo-npc-start"].value, settings.global["fo-player-team-npc-max"].value)
      -- PNJ retirés : les KILL derniers numéros
      local ids = {}
      for _, np in ipairs(team and team.npcs or {}) do ids[#ids + 1] = np.id end
      table.sort(ids)
      st.killed = 0
      for i = #ids, math.max(1, #ids - KILL + 1), -1 do
        if ctx.remote("fo-ia1", "kill_npc", "player", ids[i]) == true then st.killed = st.killed + 1 end
      end
      -- arbres retirés autour du coffre
      local removed = 0
      for _, tr in ipairs(s.find_entities_filtered({ position = qg.position, radius = R_TREES, type = "tree" })) do
        if tr.destroy() then removed = removed + 1 end
      end
      st.trees_removed = removed
      -- coffre du QG : vidé, puis bois (variante), 1 case de charbon, pierre jusqu'à la dernière case
      local inv = inv_of(qg)
      inv.clear()
      if VARIANT == "bois" then qg.insert({ name = "wood", count = WOOD_IN_CHEST }) end
      qg.insert({ name = "coal", count = game.item_prototypes["coal"].stack_size })
      qg.insert({ name = "stone", count = game.item_prototypes["stone"].stack_size * #inv })
      local u, n = fill_of(qg)
      st.fill0 = { u, n }
      st.stone0 = total(s, qg, "stone")
      st.stone_max = st.stone0
      -- arbres plantés (variante « arbres ») : 8 à 10-16 tuiles du coffre, au nord-est
      st.planted = 0
      if VARIANT == "arbres" then
        local name = tree_name()
        st.tree = name
        for i = 0, 7 do
          local want = { x = qg.position.x + 10 + (i % 4) * 2, y = qg.position.y - 10 - math.floor(i / 4) * 3 }
          local q = name and s.find_non_colliding_position(name, want, 6, 1)
          if q and s.create_entity({ name = name, position = q }) then st.planted = st.planted + 1 end
        end
      end
      -- Scène v2 (premier passage du 7/11, 16 h 20 : 2 coffres de fer EN POCHE d'un PNJ, fabriqués avant la scène, posés au dépôt
      -- en 2 s : le coffre urgent ne servait jamais) : fabrications des PNJ annulées et coffres d'annexe retirés de leurs poches,
      -- puis fer en poche des PNJ restants
      st.pocket, st.cancelled, st.pocket_chests = 0, 0, 0
      for _, ch in ipairs(s.find_entities_filtered({ position = qg.position, radius = 80, type = "character", force = "player" })) do
        for i = ch.crafting_queue_size, 1, -1 do
          local q = ch.crafting_queue and ch.crafting_queue[i]
          if q then
            ch.cancel_crafting({ index = i, count = q.count })
            st.cancelled = st.cancelled + q.count
          end
        end
        local mi = ch.get_inventory(defines.inventory.character_main)
        if mi then
          for _, nm in ipairs(ANNEX_NAMES) do
            local k = mi.get_item_count(nm)
            if k > 0 then st.pocket_chests = st.pocket_chests + mi.remove({ name = nm, count = k }) end
          end
          st.pocket = st.pocket + mi.insert({ name = "iron-plate", count = POCKET })
        end
      end
      st.iron0 = delivered_iron(ctx)
      local after = ctx.remote("fo-ia1", "team_status", "player")
      st.n1 = after and #after.npcs or -1
      st.annex0 = #annexes(s, qg)
      ctx.log(string.format("scene v2 : coffre %d/%d cases, pierre %d, bois %d, fer %d ; PNJ %d -> %d (depart %d) ; arbres retires %d, plantes %d (%s) ; fer en poche %d ; coffres retires des poches %d, fabrications annulees %d ; annexes %d",
        u, n, st.stone0, qg.get_item_count("wood"), qg.get_item_count("iron-plate"), st.n0, st.n1, st.floor, removed, st.planted,
        tostring(st.tree), st.pocket, st.pocket_chests, st.cancelled, st.annex0))
    elseif t == SETUP + 60 then
      probe_line(ctx, "plein", "iron-plate", probe(ctx, "iron-plate"))
      probe_line(ctx, "plein", "stone", probe(ctx, "stone"))
    elseif t > SETUP and t % 60 == 0 then
      local list = annexes(s, qg)
      if #list > (st.annex0 or 0) and not st.first_annex_tick then
        st.first_annex_tick = t
        st.first_annex_name = list[1].name
        ctx.log(string.format("premiere annexe : %s a %.1f s apres la scene", list[1].name, (t - SETUP) / 60))
      end
      local stone = total(s, qg, "stone")
      if stone > (st.stone_max or 0) then st.stone_max = stone end
      if t % 600 == 0 then
        local u, n = fill_of(qg)
        ctx.log(string.format("t+%d s : QG %d/%d, annexes %d, fer QG+annexes %d, livre fer %+d, pierre %d, bois %d", (t - SETUP) / 60, u, n, #list,
          total(s, qg, "iron-plate"), delivered_iron(ctx) - (st.iron0 or 0), stone, total(s, qg, "wood")))
      end
    end
    if t == CHECK - 60 then
      st.p_iron = probe(ctx, "iron-plate")
      st.p_stone = probe(ctx, "stone")
      probe_line(ctx, "fin", "iron-plate", st.p_iron)
      probe_line(ctx, "fin", "stone", st.p_stone)
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local s = ctx.surface()
    local qg = st.chest
    if not (qg and qg.valid) then
      ctx.check(false, "coffre d'equipe present a la fin")
      return
    end
    local f0 = st.fill0 or { 0, 1 }
    local wood_ok
    if VARIANT == "bois" then wood_ok = (st.planted or 0) == 0
    elseif VARIANT == "arbres" then wood_ok = (st.planted or 0) >= 6
    else wood_ok = (st.planted or 0) == 0 end
    ctx.check(f0[1] == f0[2] and (st.n1 or 99) < (st.floor or 0) and wood_ok,
      "S1 scene : coffre plein, equipe sous son effectif de depart, bois et arbres de la variante",
      string.format("%d/%d cases, PNJ %s/%s, plantes %s", f0[1], f0[2], tostring(st.n1), tostring(st.floor), tostring(st.planted)))
    local list = annexes(s, qg)
    local p = st.p_iron or {}
    local delta = delivered_iron(ctx) - (st.iron0 or 0)
    if VARIANT ~= "sans-bois" then
      local dt = st.first_annex_tick and (st.first_annex_tick - SETUP) or nil
      ctx.check(dt ~= nil and dt <= N and st.first_annex_name == "wooden-chest",
        "C1 annexe posee en moins de 60 s, la premiere en bois", dt and string.format("%.1f s, %s", dt / 60, tostring(st.first_annex_name)) or "aucune")
      ctx.check((p.stock_logs or 0) >= 1, "C2 [FO-STOCKAGE] : raison du coffre urgent au journal", tostring(p.stock_logs))
      ctx.check((p.annex_placed or 0) >= 1, "C3 [FO-ANNEXE] : annexe posee par le mod",
        string.format("posees %s dont au depot %s", tostring(p.annex_placed), tostring(p.annex_held)))
      ctx.check(delta >= 100, "C4 fer entre au stock (livre fer >= 100 apres la scene)", delta)
      local sp = st.p_stone or {}
      ctx.check(sp.skip_item == true and (st.stone_max or 0) <= (st.stone0 or 0), "C5 pierre plus ramassee (verdict du ramassage, pierre du stock jamais au-dessus de la scene)",
        string.format("ecartee %s, pierre max %s pour %s", tostring(sp.skip_item), tostring(st.stone_max), tostring(st.stone0)))
    else
      ctx.check(#list == 0, "C1' sans bois ni fer ni arbre : aucune annexe (limite connue)", #list)
      ctx.check((p.stock_logs or 0) >= 1 and p.why ~= nil, "C2' [FO-STOCKAGE] : raison ecrite", tostring(p.why))
    end
    local refused = {}
    local names = {}
    for name in pairs(p.refused or {}) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do refused[#refused + 1] = name .. " " .. p.refused[name] end
    ctx.log(string.format("fin : annexes %d, livre fer %+d, pierre %d (scene %d), raison %s ; refus (objets, cumul des tentatives) {%s}", #list,
      delta, total(s, qg, "stone"), st.stone0 or -1, tostring(p.why), table.concat(refused, ", ")))
  end,
}
end
