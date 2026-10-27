--[[
  Lot IA3-e (27/10) : banc « l'usine des factions » (critère A4 de docs/IA_ATTENDUS.md ; expériences E213, E214).
  Le banc NE POSE RIEN à la place du cerveau : 4 factions (ou 2), 100 soldats, 8 PNJ, difficulté Normal (biters en
  cessez-le-feu avec le joueur seulement, comme ia0-*), cerveau par besoins (réglage du mod, allumé par défaut). Il lit :
    - chaque 5 s, la tâche de chaque PNJ (interface « fo-ia1 », team_status) : PNJ-temps par sorte de tâche ;
    - chaque minute, l'état de l'automatisation (interface « fo-ia3e ») : modules demandés, construits, refusés,
      et les verdicts de la règle main -> machine (journal du mod, lignes [FO-IA3E]) ;
    - à T_FREEZE (45 min) : la mesure « SANS PNJ » : tous les PNJ des factions sont figés (entity.active = false)
      pendant 5 min ; chaque module FINI est relevé chaque minute (fours et assembleurs de ses pièces :
      products_finished ; centrale : énergie produite au dernier tick) ; un module « produit sans PNJ » si sa production
      est > 0 CHAQUE minute (centrale : machines à vapeur qui produisent à chaque relevé) ; puis les PNJ repartent ;
    - à 45 min : part de la fabrication À LA MAIN : objets fabriqués par les PNJ (interface « fo-ia3e », cumul par objet)
      contre ceux des assembleurs de la force (statistiques de production du moteur pour les mêmes objets ; la
      fabrication d'un personnage SANS joueur n'y entre pas : contrôlé ici, E213) ;
    - à 90 min : K7, part du temps des PNJ en TOURNÉES À PIED (tâches service, carry) de 30 à 90 min, minutes figées
      exclues ; le minage à la main est publié à part.
  Contrôles (BILAN) : seulement les relevés (au moins un module demandé par le cerveau, mesures écrites) ; les critères
  A4 sont PUBLIÉS en lignes « CRITERE ... : OUI/NON » (mesure : un critère non atteint n'est pas une panne du banc).
  Variantes : ia3e-usine (4 factions), ia3e-usine2 (2 factions). Lancement : banc.py ... -- 330000 ia3e-usine <source>.
]]

local MIN = 3600
local SAMPLE = 300
local T_FREEZE = 45 * MIN
local T_FREEZE2 = 75 * MIN
local FREEZE = 5 * MIN
local T_END = 90 * MIN
local K7_FROM = 30 * MIN
local CRAFTED = { "iron-gear-wheel", "electronic-circuit", "copper-cable", "automation-science-pack", "logistic-science-pack",
  "military-science-pack", "firearm-magazine", "piercing-rounds-magazine", "inserter", "transport-belt", "submachine-gun",
  "pistol", "grenade", "light-armor", "stone-furnace", "burner-mining-drill", "electric-mining-drill", "gun-turret",
  "iron-chest", "pipe", "iron-stick", "medium-electric-pole", "small-electric-pole", "lab", "assembling-machine-1",
  "boiler", "steam-engine", "offshore-pump", "steel-chest", "stone-wall" }
local TOURNEE = { service = true, carry = true }

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function kv(t, fmt)
  local out = {}
  for _, k in ipairs(sorted_keys(t)) do out[#out + 1] = k .. "=" .. string.format(fmt or "%s", t[k]) end
  return table.concat(out, " ")
end

--- Interface de l'automatisation (absente sur une source d'avant le lot : témoin « avant », mesures des tâches seules).
local function auto_status(ctx, key)
  if not (remote.interfaces["fo-ia3e"] and remote.interfaces["fo-ia3e"].status) then return nil end
  return remote.call("fo-ia3e", "status", key)
end

local function factions(ctx)
  local out = {}
  for _, row in ipairs(ctx.remote("fo-ia1", "teams") or {}) do
    if row.key ~= "player" then out[#out + 1] = row end
  end
  return out
end

--- Machines d'un module fini (rectangles de ses pièces) : fours, assembleurs, machines à vapeur.
local function machines_of(s, force, mod)
  local out = {}
  for _, pt in ipairs(mod.parts or {}) do
    local area = { { pt.x, pt.y }, { pt.x + pt.w, pt.y + pt.h } }
    for _, e in ipairs(s.find_entities_filtered({ area = area, force = force, type = { "furnace", "assembling-machine", "generator" } })) do
      out[#out + 1] = e
    end
  end
  table.sort(out, function(a, b) return a.unit_number < b.unit_number end)
  return out
end

local function production(list)
  local made, power, gens = 0, 0, 0
  for _, e in ipairs(list) do
    if e.valid then
      if e.type == "generator" then
        gens = gens + 1
        power = power + e.energy_generated_last_tick
      else
        made = made + e.products_finished
      end
    end
  end
  return made, power, gens
end

--- PNJ figés (et invulnérables pendant la mesure : e1, 7 personnages figés tués en 5 min) ou rendus.
local function set_npcs_active(ctx, active)
  local s = ctx.surface()
  local n = 0
  for _, row in ipairs(factions(ctx)) do
    for _, c in ipairs(s.find_entities_filtered({ type = "character", force = row.force })) do
      if c.valid then c.active = active; c.destructible = active; n = n + 1 end
    end
  end
  return n
end

--- Diagnostic d'un module fini (lot IA3-e, e5-usine : modules finis à 0 objet/min) : statut moteur des fours,
--- assembleurs, foreuses et bras de ses pièces (nombre par statut), contenu des coffres (quais).
local STATUS_NAME = nil
local function status_name(v)
  if not STATUS_NAME then
    STATUS_NAME = {}
    for k, x in pairs(defines.entity_status) do STATUS_NAME[x] = k end
  end
  return STATUS_NAME[v] or tostring(v)
end

local function diagnose(ctx, row, m)
  local s = ctx.surface()
  local by, chests = {}, {}
  for _, pt in ipairs(m.parts or {}) do
    local area = { { pt.x - 3, pt.y - 3 }, { pt.x + pt.w + 3, pt.y + pt.h + 3 } }
    for _, e in ipairs(s.find_entities_filtered({ area = area, force = row.force,
      type = { "furnace", "assembling-machine", "mining-drill", "inserter", "container" } })) do
      if e.type == "container" then
        local c = e.get_inventory(defines.inventory.chest).get_contents()
        local parts = {}
        for _, k in ipairs(sorted_keys(c)) do parts[#parts + 1] = k .. "=" .. c[k] end
        chests[#chests + 1] = "[" .. table.concat(parts, ",") .. "]"
      else
        local k = e.type .. ":" .. status_name(e.status)
        by[k] = (by[k] or 0) + 1
      end
    end
  end
  ctx.log(string.format("DIAG %s %s#%d : %s | coffres %s", row.key, m.product, m.id, kv(by), table.concat(chests, " ")))
end

--- Images (session avec images seulement : un joueur connecté) : vue d'ensemble de la base d'une faction et gros plan
--- de chaque module fini, dans script-output/fo-shots/ia3e-<faction>-<moment>.png.
local function snap(ctx, name, x, y, zoom)
  local player = game.connected_players[1]
  if not player then return false end
  game.take_screenshot({ player = player, surface = ctx.surface(), position = { x, y }, resolution = { 1600, 900 }, zoom = zoom,
    path = "fo-shots/ia3e-" .. name .. ".png", show_entity_info = true, anti_alias = true, daytime = 0,
    allow_in_replay = true, force_render = true })
  ctx.log("capture ia3e-" .. name)
  return true
end

local function photos(ctx, moment)
  local s = ctx.surface()
  for _, row in ipairs(factions(ctx)) do
    local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = row.force, limit = 1 })[1]
    if hq then
      snap(ctx, row.key .. "-" .. moment .. "-base", hq.position.x, hq.position.y, 0.18)
      local a = auto_status(ctx, row.key)
      local n = 0
      for _, m in ipairs(a and a.modules or {}) do
        for _, pt in ipairs(m.parts or {}) do
          n = n + 1
          if n <= 6 and m.state == "fini" then
            snap(ctx, string.format("%s-%s-%d-%s", row.key, moment, n, m.product), pt.x + pt.w / 2, pt.y + pt.h / 2, 0.6)
          end
        end
      end
    end
  end
end

return function(variant)
  local NF = (variant == "usine2" or variant == "photo") and 2 or 4
  -- Variante « photo » (captures pour le DC) : 2 factions, 51 min, images à 35, 43 et 50 min ; pas de mesure sans PNJ.
  local T_END = variant == "photo" and 51 * MIN or T_END
  local PHOTOS = variant == "photo" and { [35 * MIN] = "35min", [43 * MIN] = "43min", [50 * MIN] = "50min" } or {}
  return {
    description = "IA3-e : l'usine des factions (" .. NF .. " factions, Normal, 8 PNJ, " .. math.floor(T_END / MIN) .. " min)",
    base = nil,
    check_tick = T_END + 60,

    init = function(ctx)
      local ok = ctx.remote("fo-pvp", "set_difficulty", "normal")
      ctx.check(ok == true, "difficulte Normal imposee avant la guerre", tostring(ok))
      game.forces.player.set_cease_fire("enemy", true)
      game.forces.enemy.set_cease_fire("player", true)
      local started = ctx.call("war_start", NF, 100, 8)
      ctx.check(started == true, "guerre lancee : " .. NF .. " factions, 100 soldats, 8 PNJ", tostring(started))
      ctx.call("profiler", true)
      local cfg = {}
      for _, n in ipairs({ "fo-npc-start", "fo-war-workers", "fo-war-ia3-cerveau", "fo-war-ia3-marche" }) do
        cfg[#cfg + 1] = n .. "=" .. tostring(settings.global[n] and settings.global[n].value)
      end
      ctx.log("reglages " .. table.concat(cfg, " "))
    end,

    tick = function(ctx, e)
      local st = ctx.state()
      local t = e.tick
      st.tasks = st.tasks or {}
      st.k7 = st.k7 or {}
      -- Tâches des PNJ (PNJ-temps par sorte), hors minutes figées.
      if t % SAMPLE == 0 and not st.frozen then
        for _, row in ipairs(factions(ctx)) do
          local status = ctx.remote("fo-ia1", "team_status", row.key)
          if status then
            local b = st.tasks[row.key] or { all = {}, n = 0, k7 = {}, k7n = 0 }
            st.tasks[row.key] = b
            for _, npc in ipairs(status.npcs or {}) do
              local k = npc.task or "inactif"
              b.all[k] = (b.all[k] or 0) + 1
              b.n = b.n + 1
              if t >= K7_FROM then
                b.k7[k] = (b.k7[k] or 0) + 1
                b.k7n = b.k7n + 1
              end
            end
          end
        end
      end
      -- Ligne de la minute : modules.
      if t % MIN == 0 and t > 0 then
        for _, row in ipairs(factions(ctx)) do
          local a = auto_status(ctx, row.key)
          if a then
            local mods = {}
            for _, m in ipairs(a.modules) do mods[#mods + 1] = string.format("%s:%s(%d/%d)", m.product, m.state, m.built or 0, m.total or 0) end
            if #a.modules > 0 then st.any_request = true end
            if t % (5 * MIN) == 0 then
              ctx.log(string.format("minute %d | %s modules {%s} | voulu [%s]", t / MIN, row.key, table.concat(mods, " "), table.concat(a.wanted or {}, " ")))
            end
          end
        end
      end
      if PHOTOS[t] then photos(ctx, PHOTOS[t]) end
      -- Diagnostic des modules finis toutes les 10 min à partir de 30 min (hors gel).
      if t >= 30 * MIN and t % (10 * MIN) == 0 and not st.frozen then
        for _, row in ipairs(factions(ctx)) do
          local a = auto_status(ctx, row.key)
          for _, m in ipairs(a and a.modules or {}) do
            if m.state == "fini" then pcall(diagnose, ctx, row, m) end
          end
          -- centrale : chaudières et machines à vapeur de la force (statut, charbon, énergie du dernier tick)
          local sf = ctx.surface()
          local by = {}
          local kw = 0
          for _, e in ipairs(sf.find_entities_filtered({ force = row.force, type = { "boiler", "generator", "offshore-pump" } })) do
            local k = e.type .. ":" .. status_name(e.status)
            by[k] = (by[k] or 0) + 1
            if e.type == "generator" then kw = kw + e.energy_generated_last_tick * 60 / 1000 end
          end
          if next(by) then ctx.log(string.format("DIAG %s centrale : %s | %.0f kW", row.key, kv(by), kw)) end
        end
      end
      -- Mesure SANS PNJ (pas dans la variante « photo », trop courte) : à 45 min (critère A4), puis à 75 min (complément :
      -- les modules finis plus tard ; minutes figées hors des relevés de K7).
      if t == T_FREEZE2 and T_FREEZE2 < T_END and not st.frozen then
        local s = ctx.surface()
        st.freeze2 = {}
        st.freeze_at = t
        for _, row in ipairs(factions(ctx)) do
          local a = auto_status(ctx, row.key)
          local list = {}
          for _, m in ipairs(a and a.modules or {}) do
            if m.state == "fini" then
              local made = production(machines_of(s, row.force, m))
              list[#list + 1] = { product = m.product, id = m.id, last = made, per_min = {} }
            end
          end
          if #s.find_entities_filtered({ type = "generator", force = row.force, limit = 1 }) > 0 then
            list[#list + 1] = { product = "centrale", gens = true, per_min = {} }
          end
          st.freeze2[row.key] = { list = list, force = row.force }
        end
        st.cur_freeze = st.freeze2
        local n = set_npcs_active(ctx, false)
        st.frozen = true
        ctx.log(string.format("PNJ des factions FIGES a %d min (%d personnages) : 2e mesure de 5 min sans PNJ", t / MIN, n))
      end
      if t == T_FREEZE and T_FREEZE < T_END then
        local s = ctx.surface()
        st.freeze = {}
        st.freeze_at = t
        st.cur_freeze = st.freeze
        st.hand45 = {}
        for _, row in ipairs(factions(ctx)) do
          local a = auto_status(ctx, row.key)
          local list = {}
          for _, m in ipairs(a and a.modules or {}) do
            if m.state == "fini" then
              local ms = machines_of(s, row.force, m)
              local made, power = production(ms)
              list[#list + 1] = { product = m.product, id = m.id, n = #ms, made0 = made, last = made, per_min = {}, nominal = m.rate_nom or 0 }
            end
          end
          -- Centrale (projet du plan directeur, pas un module de la règle) : machines à vapeur de la force près du QG.
          local gens = s.find_entities_filtered({ type = "generator", force = row.force })
          table.sort(gens, function(x, y) return x.unit_number < y.unit_number end)
          if #gens > 0 then list[#list + 1] = { product = "centrale", n = #gens, gens = true, per_min = {} } end
          st.freeze[row.key] = { list = list, force = row.force }
          -- Fabrication à la main contre machines (cumuls à 45 min).
          local hand, machine, hand_final = 0, 0, 0
          local force = game.forces[row.force]
          local stats = force and force.item_production_statistics
          local per = {}
          for _, it in ipairs(CRAFTED) do
            local h = (a and (a.hand_all or a.hand) or {})[it] or 0
            local m = stats and stats.get_input_count(it) or 0
            hand = hand + h
            hand_final = hand_final + ((a and a.hand or {})[it] or 0)
            machine = machine + m
            if h > 0 or m > 0 then per[it] = h .. "/" .. m end
          end
          local plates = stats and (stats.get_input_count("iron-plate") + stats.get_input_count("copper-plate")) or 0
          st.hand45[row.key] = { hand = hand, machine = machine, plates = plates }
          ctx.log(string.format("FABRICATION %s a 45 min (main/machines, intermediaires compris ; objets finaux a la main %d) : %s ; plaques fondues %d",
            row.key, hand_final, kv(per), plates))
        end
        local n = set_npcs_active(ctx, false)
        st.frozen = true
        ctx.log(string.format("PNJ des factions FIGES a %d min (%d personnages) : mesure de 5 min sans PNJ", t / MIN, n))
      end
      if st.frozen and t > st.freeze_at and (t - st.freeze_at) % MIN == 0 then
        local s = ctx.surface()
        for _, key in ipairs(sorted_keys(st.cur_freeze)) do
          local fz = st.cur_freeze[key]
          for _, m in ipairs(fz.list) do
            if m.gens then
              local p = 0
              for _, g in ipairs(s.find_entities_filtered({ type = "generator", force = fz.force })) do p = p + g.energy_generated_last_tick end
              m.per_min[#m.per_min + 1] = math.floor(p * 60 / 1000)
            else
              local a = auto_status(ctx, key)
              local mod
              for _, x in ipairs(a and a.modules or {}) do if x.id == m.id then mod = x end end
              local made = mod and production(machines_of(s, fz.force, mod)) or m.last
              m.per_min[#m.per_min + 1] = made - m.last
              m.last = made
            end
          end
        end
        if t - st.freeze_at >= FREEZE then
          local n = set_npcs_active(ctx, true)
          st.frozen = false
          ctx.log(string.format("PNJ des factions repartis a %d min (%d personnages)", t / MIN, n))
          local label = st.cur_freeze == st.freeze2 and "SANS PNJ (75 min)" or "SANS PNJ"
          for _, key in ipairs(sorted_keys(st.cur_freeze)) do
            local fz = st.cur_freeze[key]
            local ok_n = 0
            local parts = {}
            for _, m in ipairs(fz.list) do
              local all = #m.per_min >= 5
              for _, v in ipairs(m.per_min) do if v <= 0 then all = false end end
              if all then ok_n = ok_n + 1 end
              local vals = {}
              for i, v in ipairs(m.per_min) do vals[i] = tostring(v) end
              parts[#parts + 1] = string.format("%s[%s]%s", m.product, table.concat(vals, ","), all and "OK" or "non")
            end
            fz.ok_n = ok_n
            ctx.log(string.format("%s %s : %d module(s) produisent 5 min sur %d finis : %s", label, key, ok_n, #fz.list, table.concat(parts, " ")))
          end
        end
      end
    end,

    -- Galerie officielle (fo-captures.bat) : une vue par faction après le contrôle.
    shots = function(ctx, add)
      local s = ctx.surface()
      for _, row in ipairs(factions(ctx)) do
        local hq = s.find_entities_filtered({ name = "fo-faction-hq", force = row.force, limit = 1 })[1]
        if hq then add("ia3e-" .. row.key .. "-fin", hq.position.x, hq.position.y, 0.18) end
      end
    end,
    shots_delay = T_END + 120,

    finish = function(ctx)
      local st = ctx.state()
      if T_FREEZE >= T_END then
        ctx.log("variante sans mesure sans PNJ (" .. math.floor(T_END / MIN) .. " min)")
        local s2 = 0
        for _, row in ipairs(factions(ctx)) do
          local a = auto_status(ctx, row.key)
          local parts = {}
          for _, m in ipairs(a and a.modules or {}) do parts[#parts + 1] = m.product .. ":" .. m.state end
          ctx.log(string.format("modules %s a %d min : %s", row.key, math.floor(T_END / MIN), table.concat(parts, " ")))
          if a and #a.modules > 0 then s2 = s2 + 1 end
        end
        ctx.check(s2 > 0, "au moins une faction a demande un module")
        return
      end
      ctx.check(st.freeze ~= nil, "mesure sans PNJ faite a 45 min")
      local n3, nh, nk7, nf = 0, 0, 0, 0
      for _, row in ipairs(factions(ctx)) do
        nf = nf + 1
        local key = row.key
        local fz = st.freeze and st.freeze[key]
        local h = st.hand45 and st.hand45[key]
        local b = st.tasks[key]
        local mods3 = fz and fz.ok_n or 0
        local share = h and (h.hand + h.machine) > 0 and h.hand / (h.hand + h.machine) or 1
        local share_p = h and (h.hand + h.machine + h.plates) > 0 and h.hand / (h.hand + h.machine + h.plates) or 1
        local tour, mine, k7n = 0, 0, b and b.k7n or 0
        for _, k in ipairs(sorted_keys(b and b.k7 or {})) do
          if TOURNEE[k] then tour = tour + b.k7[k] end
          if k == "mine" then mine = mine + b.k7[k] end
        end
        local k7 = k7n > 0 and tour / k7n or 1
        if mods3 >= 3 then n3 = n3 + 1 end
        if share <= 0.20 then nh = nh + 1 end
        if k7 <= 0.15 then nk7 = nk7 + 1 end
        ctx.log(string.format("CRITERES %s | modules produisant 5 min sans PNJ a 45 min : %d (vise >= 3 : %s) | fabrication a la main a 45 min : %d objets, machines %d (%.0f %% a la main, vise <= 20 %% : %s ; avec les plaques fondues %.0f %%) | tournees a pied 30-90 min : %.0f %% (vise <= 15 %% : %s), minage a la main %.0f %%",
          key, mods3, mods3 >= 3 and "OUI" or "NON", h and h.hand or -1, h and h.machine or -1, 100 * share, share <= 0.2 and "OUI" or "NON",
          100 * share_p, 100 * k7, k7 <= 0.15 and "OUI" or "NON", k7n > 0 and 100 * mine / k7n or 0))
        ctx.log(string.format("taches %s (0-90 min, releves) : %s", key, kv(b and b.all or {})))
      end
      ctx.log(string.format("CRITERES BILAN : %d faction(s) sur %d avec >= 3 modules sans PNJ ; %d avec <= 20 %% a la main ; %d avec tournees <= 15 %%",
        n3, nf, nh, nk7))
      if remote.interfaces["fo-ia3e"] then
        ctx.check(st.any_request == true, "au moins un module demande par le cerveau (aucun pose par le banc)")
      else
        ctx.log("source sans automatisation (temoin avant le lot) : pas de controle de demande")
      end
    end,
  }
end
