--[[
  Lot PD-REPARATION (D79, micro-banc) : votre équipe (coffre d'équipe, 8 PNJ) a un labo, un assembleur, une foreuse, un convoyeur,
  deux murs, un poteau et, loin d'eux, un four. À 600 ticks le banc les blesse par `damage()` (événement on_entity_damaged du
  moteur, comme une attaque) ; le four reçoit en plus un coup toutes les 60 ticks jusqu'à 2 400 ticks (attaque locale).
  Attendu : labo, assembleur, foreuse, convoyeur et mur à 40 % remis à neuf par des PNJ (tâche « repair » de ce lot) ; le four
  seulement APRÈS la fin de son attaque + Rp.CALM ; le mur à 90 % (au-dessus du seuil de 50 %) laissé tel quel ; le poteau
  réparé par RECONSTRUIRE (pas par ce lot).
  Lancement : banc.py -- 7000 pd-reparation <source> (contrôle final au tick 6 000).
]]

local HALF = 90
local HIT_EVERY = 60
local ATTACK_END = 2400
local CALM = 600 -- Rp.CALM

local function deposit(s, name, cx, cy, r, amount)
  for dy = -r, r do
    for dx = -r, r do
      if dx * dx + dy * dy <= r * r then s.create_entity({ name = name, position = { cx + dx + 0.5, cy + dy + 0.5 }, amount = amount }) end
    end
  end
end

-- { clé, entité, x, y, santé visée (fraction), attendu }
local PIECES = {
  { "labo", "lab", 12, 12, 0.4, "repare" },
  { "assembleur", "assembling-machine-1", 18, 12, 0.4, "repare" },
  { "convoyeur", "transport-belt", 22, 12, 0.3, "repare" },
  { "mur", "stone-wall", 24, 16, 0.4, "repare" },
  { "mur90", "stone-wall", 26, 16, 0.9, "laisse" },
  { "poteau", "small-electric-pole", 14, 16, 0.3, "recon" },
  { "foreuse", "burner-mining-drill", 50, -20, 0.4, "repare" },
  { "four", "stone-furnace", -50, 30, 0.4, "attaque" },
}

local function find(s, p)
  for _, e in ipairs(s.find_entities_filtered({ area = { { p.x - 0.6, p.y - 0.6 }, { p.x + 0.6, p.y + 0.6 } }, force = "player" })) do
    if e.valid and e.type ~= "character" and e.health then return e end
  end
end

return {
  description = "PD-REPARATION : batiments endommages (labo, assembleur, foreuse, four...) repares par les PNJ, pas pendant l'attaque",
  check_tick = 6000, -- 1er banc : check_tick = ticks du banc, le contrôle final n'a pas tourné

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    s.request_to_generate_chunks({ 0, 0 }, 4)
    s.force_generate_chunk_requests()
    local area = { { -HALF, -HALF }, { HALF, HALF } }
    for _, e in ipairs(s.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "resource", "unit-spawner", "turret", "unit", "fish" } })) do
      if e.valid then e.destroy() end
    end
    local tiles = {}
    for y = -HALF, HALF - 1 do for x = -HALF, HALF - 1 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
    s.set_tiles(tiles, true)
    deposit(s, "iron-ore", 50, -20, 6, 3000)
    deposit(s, "coal", -20, -40, 5, 2000)
    ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 8) == 8, "effectif de depart 8")
    local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    for _, it in ipairs({ { "iron-plate", 800 }, { "copper-plate", 300 }, { "wood", 40 }, { "stone", 100 }, { "coal", 400 },
        { "pistol", 10 }, { "firearm-magazine", 100 }, { "iron-gear-wheel", 40 }, { "pipe", 20 } }) do
      chest.insert({ name = it[1], count = it[2] })
    end
    st.p = {}
    for _, p in ipairs(PIECES) do
      s.create_entity({ name = p[2], position = { p[3] + 0.5, p[4] + 0.5 }, force = "player", direction = 0, raise_built = true })
      local e = find(s, { x = p[3] + 0.5, y = p[4] + 0.5 })
      ctx.check(e ~= nil, "pose de " .. p[1], p[2])
      st.p[#st.p + 1] = { key = p[1], frac = p[5], want = p[6], name = e and e.name, x = e and e.position.x or p[3], y = e and e.position.y or p[4] }
    end
    st.t0 = game.tick
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.t0 then return end
    local t = e.tick - st.t0
    local s = ctx.surface()
    if t == 600 and not st.hurt then
      st.hurt = t
      for _, p in ipairs(st.p) do
        local real = p.name and s.find_entity(p.name, { p.x, p.y })
        if real and real.valid then
          -- Coups physiques de 10 % jusqu'à la santé visée : les résistances rognent chaque coup.
          local mx = real.prototype.max_health
          local n = 0
          while real.valid and real.health > mx * p.frac and n < 50 do
            real.damage(mx * 0.1, "enemy", "physical") -- type par défaut « impact » : le mur y résiste presque en entier (banc 2)
            n = n + 1
          end
          p.after = real.valid and real.health / mx or 0
        end
      end
      ctx.log(string.format("%d piece(s) blessee(s) par damage() a %d ticks", #st.p, t))
    end
    if st.hurt and t > st.hurt and t <= ATTACK_END and t % HIT_EVERY == 0 then
      for _, p in ipairs(st.p) do
        if p.want == "attaque" then
          local real = s.find_entity(p.name, { p.x, p.y })
          if real and real.valid then
            real.damage(1, "enemy")
            st.last_hit = t
            if real.health >= real.prototype.max_health then p.full_during = p.full_during or t end
          end
        end
      end
    end
    if st.hurt and t > st.hurt and t % 30 == 0 then
      for _, p in ipairs(st.p) do
        local real = s.find_entity(p.name, { p.x, p.y })
        if real and real.valid and real.health >= real.prototype.max_health and not p.full then
          p.full = t
          ctx.log(string.format("%s (%s) remis a neuf %d ticks (%.1f s) apres la blessure", p.key, p.name, t - st.hurt, (t - st.hurt) / 60))
        end
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    ctx.check(st.hurt ~= nil, "pieces blessees")
    for _, p in ipairs(st.p or {}) do
      ctx.log(string.format("FAIT %s (%s) : sante apres le coup %.0f %%, remis a neuf a %s", p.key, tostring(p.name), (p.after or 0) * 100,
        p.full and string.format("%d ticks", p.full - (st.hurt or 0)) or "jamais"))
      if p.want == "repare" then
        ctx.check(p.full ~= nil, p.key .. " endommage remis a neuf par l'equipe", p.full)
      elseif p.want == "laisse" then
        ctx.check(p.full == nil, p.key .. " au-dessus du seuil laisse tel quel", p.full)
      elseif p.want == "attaque" then
        ctx.check(p.full ~= nil and p.full >= ATTACK_END + CALM, "four sous attaque repare seulement apres la fin de l'attaque + Rp.CALM", p.full)
      elseif p.want == "recon" then
        ctx.log("poteau (infrastructure de votre equipe, lot RECONSTRUIRE) : " .. (p.full and "repare" or "non repare"))
      end
    end
  end,
}
