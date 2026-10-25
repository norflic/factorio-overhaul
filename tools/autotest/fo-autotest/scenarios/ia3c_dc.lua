--[[
  Lot IA3-c : LE CAS DU DC (25/10, 18 h 40 et 18 h 45 ; capture fo-logs\2026-10-25_DC-captures\pnj-inactifs-fer-ignore.png)
  rejoué en moteur réel, sans guerre ni ennemis (carte paisible, zone nettoyée) :
    votre équipe (8 PNJ offerts), coffre avec 600 pierres, 800 charbons, 60 chargeurs et 6 plaques de fer, AUCUN four ;
    pierre à 14 tuiles, charbon à 60 tuiles, FER à environ 127 tuiles, cuivre à environ 127 tuiles ; aucune autre
    ressource à moins de 300 tuiles. L'ancien cerveau affiche « Objectif : Charbon — il manque : 62 Plaque de fer ».
  Variantes (fichiers ia3c-dc-<variante>.lua) :
    avant : réglage fo-war-ia3-cerveau ÉTEINT (ancien cerveau) : MESURE seulement (le défaut est attendu) ;
    apres : réglage ALLUMÉ : contrôles du critère du DC (ci-dessous) ;
    loin  : ALLUMÉ, et AUCUN gisement de fer à moins de 300 tuiles : l'exploration du fer doit être demandée.
  Relevé toutes les 5 s (interfaces « fo-ia1 » et « fo-ia3c », lecture seule) ; une ligne par minute :
    minute M | pnj N inactifs I | fer coffre F livre L | pierre P charbon C | avant-postes {…} | projets pris Q actifs A | …
  Contrôles (variante apres, 20 min de jeu) : 62 plaques de fer livrées au coffre en 12 min au plus ; avant-poste de
  charbon bâti en 15 min au plus ; PNJ inactifs ≤ 30 % en moyenne de 2 à 20 min ; au moins 2 projets menés EN MÊME
  TEMPS (PNJ au travail) pendant au moins 25 % des relevés ; pierre et charbon déclarés saturés et du travail de fond
  retiré ; aucune exploration du fer (il est connu). Variante loin : exploration du fer demandée en 3 min au plus, aucune
  tâche de minage de fer. Chiffres et règle de lecture : fo-logs\2026-10-25_IA3-c\NOTES.md.
]]

local X, Y = 1504.5, 32.5
local CLEAR_R = 300

local function count_table(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

local function patch(s, name, cx, cy, r, amount)
  for dx = -r, r do
    for dy = -r, r do
      if dx * dx + dy * dy <= r * r then s.create_entity({ name = name, position = { cx + dx, cy + dy }, amount = amount }) end
    end
  end
end

return function(variant)
local ON = variant ~= "avant"
local CHECK = 72000

return {
  description = "IA3-c : le cas du DC (il manque 62 plaques de fer), variante " .. variant,
  check_tick = CHECK,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    s.peaceful_mode = true
    -- Zone : chunks générés, ressources et ennemis retirés à CLEAR_R tuiles, sol praticable autour du QG et des gisements.
    for cx = math.floor((X - CLEAR_R) / 32), math.floor((X + CLEAR_R) / 32) do
      for cy = math.floor((Y - CLEAR_R) / 32), math.floor((Y + CLEAR_R) / 32) do
        s.request_to_generate_chunks({ x = cx * 32 + 16, y = cy * 32 + 16 }, 0)
      end
    end
    s.force_generate_chunk_requests()
    local area = { { X - CLEAR_R, Y - CLEAR_R }, { X + CLEAR_R, Y + CLEAR_R } }
    local removed = 0
    for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "resource", "unit-spawner", "turret", "unit" } })) do
      if e.valid then e.destroy() removed = removed + 1 end
    end
    ctx.prepare_area(X - 130, Y - 40, X + 130, Y + 130, "grass-1")
    patch(s, "stone", X + 14, Y, 5, 5000)
    patch(s, "coal", X, Y + 60, 7, 5000)
    if variant ~= "loin" then patch(s, "iron-ore", X - 90, Y + 90, 9, 5000) end
    patch(s, "copper-ore", X + 90, Y + 90, 7, 5000)
    st.removed = removed
    if ON then
      local v = ctx.remote("factorio-overhaul", "war_setting", "fo-war-ia3-cerveau", true)
      ctx.check(v == true, "reglage fo-war-ia3-cerveau allume", tostring(v))
    else
      local v = ctx.remote("factorio-overhaul", "war_setting", "fo-war-ia3-cerveau", false)
      ctx.check(v == false, "reglage fo-war-ia3-cerveau eteint (ancien cerveau)", tostring(v))
    end
    local chest = s.create_entity({ name = "fo-team-chest", position = { X, Y }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if chest then
      for _, it in ipairs({ { "stone", 600 }, { "coal", 800 }, { "firearm-magazine", 60 }, { "iron-plate", 6 } }) do
        chest.insert({ name = it[1], count = it[2] })
      end
    end
    ctx.log(string.format("zone (%d, %d) : %d entites retirees ; pierre +14, charbon +60, fer %s, cuivre (+90, +90)",
      X, Y, removed, variant == "loin" and "AUCUN" or "(-90, +90)"))
    st.samples, st.idle_sum, st.n_sum, st.par2, st.par_n = 0, 0, 0, 0, 0
    st.max_taken = 0
  end,

  tick = function(ctx, e)
    if e.tick % 300 ~= 0 or e.tick == 0 then return end
    local st = ctx.state()
    local row
    local ok, rows = pcall(remote.call, "fo-ia1", "teams")
    if ok and type(rows) == "table" then
      for _, r in ipairs(rows) do if r.key == "player" then row = r end end
    end
    if not row then return end
    local s3 = remote.interfaces["fo-ia3c"] and remote.call("fo-ia3c", "status", "player") or nil
    local chest = ctx.surface().find_entities_filtered({ name = "fo-team-chest", position = { X, Y }, radius = 2, limit = 1 })[1]
    local inv = chest and chest.get_inventory(defines.inventory.chest)
    local stock = inv and inv.get_contents() or {}
    local deliv = (row.delivered or {})["iron-plate"] or 0
    local n = row.n or 0
    local idle = row.last and row.last.idle or 0
    local taken = s3 and s3.taken or 0
    if e.tick >= 7200 then
      st.samples = st.samples + 1
      st.idle_sum = st.idle_sum + idle
      st.n_sum = st.n_sum + n
      st.par_n = st.par_n + 1
      if taken >= 2 then st.par2 = st.par2 + 1 end
    end
    if taken > st.max_taken then st.max_taken = taken end
    if not st.t62 and deliv >= 62 then
      st.t62 = e.tick
      ctx.log(string.format("62 plaques de fer livrees au coffre a %.1f min", e.tick / 3600))
    end
    local op = s3 and s3.outposts or {}
    if not st.t_coal and (op.coal or 0) > 0 then
      st.t_coal = e.tick
      ctx.log(string.format("avant-poste de charbon bati a %.1f min", e.tick / 3600))
    end
    if not st.t_iron and (op.iron or 0) > 0 then
      st.t_iron = e.tick
      ctx.log(string.format("avant-poste de fer bati a %.1f min", e.tick / 3600))
    end
    if s3 then
      for _, r in ipairs(s3.explore or {}) do
        if r == "iron-ore" and not st.t_explore then
          st.t_explore = e.tick
          ctx.log(string.format("exploration du fer demandee a %.1f min", e.tick / 3600))
        end
      end
      for _, r in ipairs(s3.saturated or {}) do
        st.sat = st.sat or {}
        st.sat[r] = true
      end
      st.fond_dropped = s3.fond_dropped or 0
    end
    local status = remote.call("fo-ia1", "team_status", "player")
    local kinds = {}
    for _, npc in ipairs((status and status.npcs) or {}) do
      local k = (npc.task or "inactif") .. (npc.fond and "(fond)" or "")
      kinds[k] = (kinds[k] or 0) + 1
      if npc.task == "mine" and not npc.fond then st.mine_seen = (st.mine_seen or 0) + 1 end
    end
    if e.tick % 3600 == 0 then
      local ks = {}
      for k in pairs(kinds) do ks[#ks + 1] = k end
      table.sort(ks)
      local parts = {}
      for _, k in ipairs(ks) do parts[#parts + 1] = k .. ":" .. kinds[k] end
      local ops = {}
      for _, k in ipairs({ "coal", "iron", "copper", "stone" }) do ops[#ops + 1] = k .. "=" .. (op[k] or 0) end
      local projs = {}
      for _, p in ipairs((s3 and s3.projects) or {}) do projs[#projs + 1] = p.key .. ":" .. p.state .. (p.taken and "*" or "") end
      ctx.log(string.format("minute %d | pnj %d inactifs %d | fer coffre %d livre %d | pierre %d charbon %d | avant-postes {%s} | projets pris %d actifs %d K %d | taches {%s} | projets {%s}",
        e.tick / 3600, n, idle, stock["iron-plate"] or 0, deliv, stock["stone"] or 0, stock["coal"] or 0,
        table.concat(ops, " "), taken, s3 and s3.active or 0, s3 and s3.K or 0, table.concat(parts, " "), table.concat(projs, " ")))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local idle_pct = st.n_sum > 0 and math.floor(100 * st.idle_sum / st.n_sum + 0.5) or 100
    local par_pct = st.par_n > 0 and math.floor(100 * st.par2 / st.par_n + 0.5) or 0
    local function m(t) return t and string.format("%.1f min", t / 3600) or "jamais" end
    ctx.log(string.format("MESURE | variante %s | 62 fer %s | charbon %s | fer bati %s | inactifs %d %% (2-20 min) | 2 projets pris ou plus %d %% des releves (max %d) | sature [%s] | fond retire %d | exploration fer %s",
      variant, m(st.t62), m(st.t_coal), m(st.t_iron), idle_pct, par_pct, st.max_taken, (function()
        local ks = {}
        for k in pairs(st.sat or {}) do ks[#ks + 1] = k end
        table.sort(ks)
        return table.concat(ks, " ")
      end)(), st.fond_dropped or 0, m(st.t_explore)))
    ctx.check((st.samples or 0) >= 200, "releves ecrits", st.samples)
    if variant == "apres" then
      ctx.check(st.t62 ~= nil and st.t62 <= 12 * 3600, "62 plaques de fer livrees en 12 min au plus", m(st.t62))
      ctx.check(st.t_coal ~= nil and st.t_coal <= 15 * 3600, "avant-poste de charbon bati en 15 min au plus", m(st.t_coal))
      ctx.check(idle_pct <= 30, "PNJ inactifs <= 30 % de 2 a 20 min", idle_pct .. " %")
      ctx.check(par_pct >= 25, "2 projets ou plus menes en meme temps (PNJ au travail) >= 25 % des releves",
        par_pct .. " % (max " .. st.max_taken .. ")")
      ctx.check(st.sat and st.sat["stone"] and st.sat["coal"], "pierre et charbon declares satures")
      ctx.check(st.t_explore == nil, "aucune exploration du fer (gisement connu)", m(st.t_explore))
    elseif variant == "loin" then
      ctx.check(st.t_explore ~= nil and st.t_explore <= 3 * 3600, "exploration du fer demandee en 3 min au plus", m(st.t_explore))
    end
  end,
}
end
