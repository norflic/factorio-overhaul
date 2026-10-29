--[[
  Lot RECONSTRUIRE (micro-banc) : une équipe (coffre d'équipe, 8 PNJ) a une ligne de 5 poteaux, une chaudière et une machine à
  vapeur posés par script (comme à la main : hors plan directeur). Le coffre ne contient AUCUN poteau ni chaudière tout fait, mais
  de quoi les fabriquer. À 600 ticks le banc détruit 2 poteaux et la chaudière avec `die()` (événement on_entity_died du moteur,
  comme une attaque) et ramène deux autres pièces à 30 % de santé. L'équipe doit fabriquer les objets, refaire les trois pièces
  à leur place exacte (tâche « rebuild ») et remettre les deux autres à neuf (tâche « repair »).
  Mesures : pièces inscrites, délai (en secondes) de la destruction à la dernière reconstruction et à la dernière réparation,
  délai moyen par nom de pièce (interface « fo-recon », champ byname), objets attendus au stock.
  Lancement : banc.py -- 9000 reconstruire-infra <source>.
]]

local MIN = 3600
local HALF = 90
local REQUEST = 120
local KILL_AFTER_DONE = 300
local DEADLINE = 3600 -- 1 min : ticks de la destruction à la dernière reconstruction (poteaux : bien moins de 7 min)

local function deposit(s, name, cx, cy, r, amount)
  for dy = -r, r do
    for dx = -r, r do
      if dx * dx + dy * dy <= r * r then s.create_entity({ name = name, position = { cx + dx + 0.5, cy + dy + 0.5 }, amount = amount }) end
    end
  end
end


local PLANT = {
  { "small-electric-pole", 10, 10 }, { "small-electric-pole", 14, 10 }, { "small-electric-pole", 18, 10 }, { "small-electric-pole", 22, 10 },
  { "small-electric-pole", 26, 10 }, { "boiler", 30, 10 }, { "steam-engine", 30, 16 },
}

return {
  description = "RECONSTRUIRE : infrastructure electrique detruite refaite vite (fabriquee au besoin), endommagee reparee",
  check_tick = 9000,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    local c = { x = 0, y = 0 }
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
    -- Stock : matieres pour FABRIQUER poteaux et chaudiere (bois compris), AUCUN poteau ni chaudiere tout fait.
    for _, it in ipairs({ { "iron-plate", 800 }, { "copper-plate", 300 }, { "wood", 40 }, { "stone", 100 }, { "coal", 400 },
        { "pistol", 10 }, { "firearm-magazine", 100 }, { "iron-gear-wheel", 40 }, { "pipe", 20 } }) do
      chest.insert({ name = it[1], count = it[2] })
    end
    st.ents = {}
    for _, p in ipairs(PLANT) do
      local e = s.create_entity({ name = p[1], position = { p[2] + 0.5, p[3] + 0.5 }, force = "player", direction = 0, raise_built = true })
      ctx.check(e ~= nil, "pose de " .. p[1], p[1])
      st.ents[#st.ents + 1] = { name = p[1], x = e and e.position.x or p[2], y = e and e.position.y or p[3] }
    end
    st.t0 = game.tick
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local t = e.tick - st.t0
    local s = ctx.surface()
    if t == 600 and not st.killed then
      st.killed = t
      st.status0 = ctx.remote("fo-recon", "status", "player")
      st.targets = { st.ents[2], st.ents[3], st.ents[6] } -- deux poteaux et la chaudiere
      for _, tg in ipairs(st.targets) do
        local real = s.find_entity(tg.name, { tg.x, tg.y })
        if real and real.valid then real.die("enemy") end
      end
      -- deux pieces ENDOMMAGEES (poteau de tete et machine a vapeur) a 30 % de leur sante
      st.hurt = { st.ents[1], st.ents[7] }
      for _, tg in ipairs(st.hurt) do
        local real = s.find_entity(tg.name, { tg.x, tg.y })
        if real and real.valid then real.health = real.prototype.max_health * 0.3 end
      end
      ctx.log(string.format("destruction de %d piece(s), %d endommagee(s) a 30 %% a %d ticks", #st.targets, #st.hurt, t))
    end
    if st.killed and t > st.killed and t % 30 == 0 then
      if not st.rebuilt_at then
        local all = true
        for _, tg in ipairs(st.targets) do
          local real = s.find_entity(tg.name, { tg.x, tg.y })
          if not (real and real.valid and real.force.name == "player") then all = false end
        end
        if all then
          st.rebuilt_at = t
          ctx.log(string.format("toutes les pieces detruites refaites %d ticks (%.1f s) apres la destruction", t - st.killed, (t - st.killed) / 60))
        end
      end
      if not st.repaired_at then
        local all = true
        for _, tg in ipairs(st.hurt) do
          local real = s.find_entity(tg.name, { tg.x, tg.y })
          if not (real and real.valid and real.health >= real.prototype.max_health) then all = false end
        end
        if all then
          st.repaired_at = t
          ctx.log(string.format("toutes les pieces endommagees reparees %d ticks (%.1f s) apres", t - st.killed, (t - st.killed) / 60))
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local final = ctx.remote("fo-recon", "status", "player")
    ctx.check(st.killed ~= nil and #(st.targets or {}) == 3, "3 pieces d'infrastructure detruites par die()")
    ctx.check(final ~= nil and final.recorded - (st.status0 and st.status0.recorded or 0) == 3, "chaque piece detruite est inscrite au registre", final and final.recorded)
    ctx.check(st.rebuilt_at ~= nil, "poteaux et chaudiere refaits a leur place exacte (fabriques au besoin)", st.rebuilt_at)
    ctx.check(st.rebuilt_at ~= nil and st.rebuilt_at - st.killed <= DEADLINE, "reconstruction en moins de " .. DEADLINE .. " ticks", st.rebuilt_at and (st.rebuilt_at - st.killed))
    ctx.check(st.repaired_at ~= nil, "pieces endommagees remises a neuf", st.repaired_at)
    if final then
      ctx.log(string.format("FAIT registre : %d inscrite(s), %d refaite(s), %d reparee(s), %d tache(s), %d bloquee(s), %d differee(s)",
        final.recorded, final.rebuilt, final.repaired or 0, final.tasks, final.blocked, final.deferred))
      local names = {}
      for nm in pairs(final.byname or {}) do names[#names + 1] = nm end
      table.sort(names)
      for _, nm in ipairs(names) do
        local b = final.byname[nm]
        ctx.log(string.format("DELAI %s : detruites %d, refaites par l'equipe %d (moyenne %.1f s, max %.1f s), en attente d'objet %d", nm, b.rec, b.own,
          b.own > 0 and b.own_sum / b.own / 60 or 0, b.own_max / 60, b.nostock or 0))
      end
    end
  end,
}
