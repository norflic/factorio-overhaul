--[[
  Lot IA0 (PvP, OBJECTIFS.md C4) : outils communs des scénarios greffés ia0-*.lua (format :
  tools/autotest/README.md §4). Requis au CHARGEMENT par chaque scénario, jamais pendant un événement (F24).

  - start_war(ctx, level) : niveau imposé AVANT le lancement de la guerre (message d'introduction et état
    PvP à ce niveau), biters en cessez-le-feu avec le joueur (seules les factions peuvent toucher la base
    témoin), profileur, statistiques.
  - build_base(ctx) : base témoin du joueur, « avant-poste » hors du secteur de départ (secteur de
    64 tuiles voisin) : 1 tourelle approvisionnée (défense estimée 8), 4 assembleurs, 2 fours, 1 coffre.
  - poll(ctx, period) : relevé de l'interface « fo-pvp » (difficulté, déclarations, 1re attaque contre le
    joueur et sa cible, pertes, état de la base) ; ligne de journal par minute.
  - Les contrôles finaux sont dans chaque scénario.
]]

local C = {}

C.MIN = 3600

local BASE = {
  { "gun-turret", 0, -6 }, { "assembling-machine-1", -6, 0 }, { "assembling-machine-1", -2, 0 },
  { "assembling-machine-1", 2, 0 }, { "assembling-machine-1", 6, 0 }, { "stone-furnace", -3, 5 },
  { "stone-furnace", 3, 5 }, { "wooden-chest", 0, 8 },
}

function C.start_war(ctx, level)
  local ok = ctx.remote("fo-pvp", "set_difficulty", level)
  ctx.check(ok == true, "difficulte imposee avant la guerre", level)
  game.forces.player.set_cease_fire("enemy", true)
  game.forces.enemy.set_cease_fire("player", true)
  local started = ctx.call("war_start", 4, 100, 10)
  ctx.check(started == true, "guerre lancee (4 factions)", tostring(started))
  ctx.call("profiler", true)
  ctx.call("reset_stats")
  local st = ctx.remote("fo-pvp", "status")
  ctx.check(st.active and st.difficulty == level, "etat PvP au niveau impose des le lancement", st.difficulty)
end

function C.build_base(ctx)
  local s = ctx.surface()
  local c = game.forces.player.get_spawn_position(s)
  local center = { x = math.floor(c.x) - 96, y = math.floor(c.y) + 16 }
  ctx.prepare_area(center.x - 16, center.y - 16, center.x + 16, center.y + 16, "grass-1")
  local st = ctx.state()
  st.base, st.center, st.max_health = {}, center, {}
  for _, it in ipairs(BASE) do
    local want = { x = center.x + it[2], y = center.y + it[3] }
    local p = s.find_non_colliding_position(it[1], want, 12, 1)
    local e = p and s.create_entity({ name = it[1], position = p, force = "player" })
    if e then
      if it[1] == "gun-turret" then e.insert({ name = "piercing-rounds-magazine", count = 50 }) end
      st.base[#st.base + 1] = e
    end
  end
  ctx.check(#st.base == #BASE, "base temoin posee", string.format("%d/%d batiments en (%d, %d)", #st.base, #BASE, center.x, center.y))
end

--- État de la base témoin : bâtiments debout, bâtiments touchés (détruits ou endommagés).
function C.base_state(ctx)
  local st = ctx.state()
  local alive, touched = 0, 0
  for _, e in ipairs(st.base or {}) do
    if e.valid then
      alive = alive + 1
      if e.health and e.prototype.max_health and e.health < e.prototype.max_health then touched = touched + 1 end
    else
      touched = touched + 1
    end
  end
  return alive, touched, #(st.base or {})
end

--- Relevé : toutes les `period` ticks (60 pour les scénarios de preuve, 3600 pour ceux de mesure, afin de
--- ne pas peser sur le temps script mesuré). Retient : difficulté vue à chaque relevé, 1re attaque contre le
--- joueur (tick, faction, cible), tick de la 1re atteinte à la base après cette attaque.
function C.poll(ctx, e, period)
  if e.tick % period ~= 0 then return end
  local st = ctx.state()
  local s = ctx.remote("fo-pvp", "status")
  st.polls = (st.polls or 0) + 1
  st.levels = st.levels or {}
  st.levels[s.difficulty] = (st.levels[s.difficulty] or 0) + 1
  st.attacks_total, st.declared_total = 0, 0
  st.factions = st.factions or {}
  for _, f in ipairs(s.factions) do
    st.attacks_total = st.attacks_total + f.attacks
    if f.declared then st.declared_total = st.declared_total + 1 end
    local rec = st.factions[f.key] or {}
    st.factions[f.key] = rec
    rec.grace_end, rec.declared_at, rec.attacks, rec.kills, rec.sent_total = f.grace_end, f.declared_at, f.attacks, f.kills, f.sent_total
    if f.attacks > 0 and not rec.first_attack then
      rec.first_attack = f.last_attack
      rec.first_target = f.target and { x = f.target.x, y = f.target.y } or nil
    end
    if f.attacks > 0 and not st.first_attack then
      st.first_attack, st.first_key = f.last_attack, f.key
    end
  end
  st.losses = s.losses
  local alive, touched, total = C.base_state(ctx)
  if st.first_attack and touched > 0 and not st.base_hit then st.base_hit = e.tick end
  if e.tick % 3600 == 0 then
    local parts = {}
    for _, f in ipairs(s.factions) do
      parts[#parts + 1] = string.format("%s %s%s att=%d soldats=%d tues=%d", f.key, f.declared and "guerre" or "treve",
        f.provoked and "*" or "", f.attacks, f.soldiers, f.kills)
    end
    ctx.log(string.format("minute %d | difficulte %s | secteurs %d (cibles %d, balayages %d) | base %d/%d (touches %d) | pertes %d | %s",
      e.tick / 3600, s.difficulty, s.sectors, s.score, s.sweeps, alive, total, touched, s.losses, table.concat(parts, " ; ")))
  end
end

--- Contrôle commun : la difficulté imposée a été vue à CHAQUE relevé (réglage conservé dans la sauvegarde
--- rejouée par --benchmark).
function C.check_level(ctx, level)
  local st = ctx.state()
  local n = st.levels and st.levels[level] or 0
  ctx.check(n > 0 and n == st.polls, "difficulte " .. level .. " a chaque releve (sauvegarde rejouee)", n .. "/" .. tostring(st.polls))
end

return C
