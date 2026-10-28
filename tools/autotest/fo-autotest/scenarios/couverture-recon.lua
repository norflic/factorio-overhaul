--[[
  Lot COUVERTURE, volet RECONSTRUCTION (micro-banc) : une équipe (coffre d'équipe, 8 PNJ, plan directeur « seul ») construit
  une fonderie de 3 fours ; quand le projet est FINI, le banc détruit 3 pièces de natures différentes (four, tapis ou pince,
  coffre) avec `die()` (l'événement on_entity_died du moteur, comme une attaque) ; l'équipe doit les refaire à la même place
  (script/team/reconstruction.lua, tâche « rebuild ») et « améliorer attend » tant qu'une pièce attend.
  Mesures : pièces inscrites, délai de la destruction à la dernière reconstruction, pièces revenues à leur place exacte,
  attente des améliorations (interface « fo-recon », champ hold), tâches « rebuild » créées.
  Lancement : fo-autotest.bat nopause 30000 couverture-recon <source> ; journal : [FO-COUVERTURE-RECON].
]]

local MIN = 3600
local HALF = 90
local REQUEST = 120
local KILL_AFTER_DONE = 300
local DEADLINE = 3600 -- ticks de la destruction à la dernière reconstruction

local function stock_chest(chest)
  for _, it in ipairs({
    { "iron-plate", 1500 }, { "copper-plate", 400 }, { "coal", 1200 }, { "stone", 200 },
    { "electric-mining-drill", 10 }, { "stone-furnace", 30 }, { "transport-belt", 300 }, { "inserter", 60 },
    { "burner-inserter", 10 }, { "medium-electric-pole", 40 }, { "iron-chest", 20 },
    { "pistol", 10 }, { "firearm-magazine", 100 },
  }) do
    chest.insert({ name = it[1], count = it[2] })
  end
end

local function deposit(s, name, cx, cy, r, amount)
  for dy = -r, r do
    for dx = -r, r do
      if dx * dx + dy * dy <= r * r then s.create_entity({ name = name, position = { cx + dx + 0.5, cy + dy + 0.5 }, amount = amount }) end
    end
  end
end

return {
  description = "COUVERTURE : pieces detruites refaites par l'equipe, ameliorations en attente",
  check_tick = 30000,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local c = { x = 0, y = 0 }
    st.c = c
    s.request_to_generate_chunks({ c.x, c.y }, 4)
    s.force_generate_chunk_requests()
    local area = { { c.x - HALF, c.y - HALF }, { c.x + HALF, c.y + HALF } }
    for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
      if e.valid then e.destroy() end
    end
    local tiles = {}
    for y = c.y - HALF, c.y + HALF - 1 do for x = c.x - HALF, c.x + HALF - 1 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
    s.set_tiles(tiles, true)
    deposit(s, "iron-ore", c.x + 50, c.y - 20, 8, 3000)
    deposit(s, "coal", c.x - 50, c.y - 40, 6, 2000)
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    local chest = s.create_entity({ name = "fo-team-chest", position = { c.x + 0.5, c.y + 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    stock_chest(chest)
    ctx.check(ctx.remote("fo-ia1d", "enable", "player", { seul = true, ghosts_ahead = true, radius = 3 }) == true, "plan directeur active")
    st.t0 = game.tick
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local t = e.tick - st.t0
    local s = ctx.surface()
    if t == REQUEST then
      st.pid = ctx.remote("fo-ia1d", "request", "player", { gen = "smelter", args = { "stone-furnace", "iron-ore", 3 }, feed = false })
      ctx.log("demande de la fonderie : projet " .. tostring(st.pid))
    end
    if t > REQUEST and t % 300 == 0 and not st.killed then
      local r = ctx.remote("fo-ia1d", "report", "player")
      if r then
        for _, p in ipairs(r.projects) do
          if p.id == st.pid and p.state == "fini" and not st.done_at then
            st.done_at = t
            ctx.log(string.format("projet %d fini a %d ticks (%.1f min)", p.id, t, t / MIN))
          end
        end
      end
    end
    -- destruction de 3 pieces de natures differentes
    if st.done_at and not st.killed and t >= st.done_at + KILL_AFTER_DONE then
      local lay = ctx.remote("fo-ia1d", "layout", "player")
      local want = { "stone-furnace", "inserter", "transport-belt", "iron-chest", "burner-inserter", "medium-electric-pole" }
      st.targets = {}
      local seen = {}
      for _, name in ipairs(want) do
        for _, en in ipairs(lay and lay.ents or {}) do
          if en.pid == st.pid and en.name == name and not seen[name] and #st.targets < 3 then
            local real = s.find_entity(name, { en.x, en.y })
            if real and real.valid and real.force.name == "player" then
              seen[name] = true
              st.targets[#st.targets + 1] = { name = name, x = en.x, y = en.y }
            end
          end
        end
      end
      st.killed = t
      st.status0 = ctx.remote("fo-recon", "status", "player")
      for _, tg in ipairs(st.targets) do
        local real = s.find_entity(tg.name, { tg.x, tg.y })
        if real and real.valid then real.die("enemy") end
      end
      ctx.log(string.format("destruction de %d piece(s) a %d ticks : %s", #st.targets, t, (function()
        local l = {}
        for _, tg in ipairs(st.targets) do l[#l + 1] = string.format("%s(%.1f,%.1f)", tg.name, tg.x, tg.y) end
        return table.concat(l, " ")
      end)()))
    end
    if st.killed then
      if t == st.killed + 60 then
        st.status1 = ctx.remote("fo-recon", "status", "player")
        ctx.log(string.format("a +60 ticks : %d en attente, %d inscrite(s), ameliorations en attente = %s",
          st.status1 and st.status1.pending or -1, st.status1 and st.status1.recorded or -1, tostring(st.status1 and st.status1.hold)))
      end
      if t > st.killed + 60 and t % 60 == 0 and not st.rebuilt_at then
        local all = #st.targets > 0
        for _, tg in ipairs(st.targets) do
          local real = s.find_entity(tg.name, { tg.x, tg.y })
          if not (real and real.valid and real.force.name == "player") then all = false end
        end
        if all then
          st.rebuilt_at = t
          st.status2 = ctx.remote("fo-recon", "status", "player")
          ctx.log(string.format("toutes les pieces refaites a %d ticks de la destruction", t - st.killed))
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local final = ctx.remote("fo-recon", "status", "player")
    ctx.check(st.done_at ~= nil, "le projet de fonderie est fini avant la fin du banc", st.done_at)
    ctx.check(st.killed ~= nil and #(st.targets or {}) >= 2, "au moins 2 pieces detruites par die()", st.targets and #st.targets or 0)
    if not (st.killed and st.targets) then return end
    ctx.check(st.status1 ~= nil and st.status1.recorded - (st.status0 and st.status0.recorded or 0) == #st.targets,
      "chaque piece detruite est inscrite au registre", st.status1 and st.status1.recorded)
    ctx.check(st.status1 ~= nil and st.status1.hold == true, "ameliorer attend tant qu'une piece attend (hold)", st.status1 and tostring(st.status1.hold))
    ctx.check(st.rebuilt_at ~= nil, "toutes les pieces sont revenues a leur place exacte", st.rebuilt_at)
    ctx.check(st.rebuilt_at ~= nil and st.rebuilt_at - st.killed <= DEADLINE, "reconstruction en moins de " .. DEADLINE .. " ticks", st.rebuilt_at and (st.rebuilt_at - st.killed))
    ctx.check(final ~= nil and final.pending == 0 and final.hold == false, "plus rien en attente, les ameliorations reprennent", final and final.pending)
    ctx.check(final ~= nil and final.rebuilt >= #st.targets and final.tasks >= 1, "tache(s) rebuild creee(s) et pieces refaites", final and final.rebuilt)
    if final then
      ctx.log(string.format("FAIT registre : %d inscrite(s), %d refaite(s), %d tache(s), %d bloquee(s), %d differee(s), %d abandonnee(s), %d menace(s) notee(s)",
        final.recorded, final.rebuilt, final.tasks, final.blocked, final.deferred, final.abandoned, final.hits))
    end
  end,
}
