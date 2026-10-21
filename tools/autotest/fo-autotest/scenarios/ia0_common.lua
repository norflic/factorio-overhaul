--[[
  Lot IA0 (PvP, OBJECTIFS.md C4) : outils communs des scénarios greffés ia0-*.lua (format :
  tools/autotest/README.md §4). Requis au CHARGEMENT par chaque scénario, jamais pendant un événement (F24).

  - start_war(ctx, level) : niveau imposé AVANT le lancement de la guerre (message d'introduction et état
    PvP à ce niveau), biters en cessez-le-feu avec le joueur (seules les factions peuvent toucher la base
    témoin), profileur, statistiques.
  - build_base(ctx[, tourelles]) : base témoin du joueur, « avant-poste » hors du secteur de départ (secteur
    de 64 tuiles voisin) : 1 tourelle approvisionnée par défaut (défense estimée 8), 4 assembleurs, 2 fours,
    1 coffre. Lot IA0b : `tourelles` (n) pose n tourelles approvisionnées (50 chargeurs perforants chacune),
    en rangées de 7 au nord des machines (défense estimée 8 × n) ; la 1re reste à la place d'origine.
  - poll(ctx, period) : relevé de l'interface « fo-pvp » (difficulté, déclarations, 1re attaque contre le
    joueur et sa cible, pertes, état de la base) ; ligne de journal par minute. Lot IA0b : cible RÉELLE de
    la 1re attaque (last_target : cible commune pour une attaque jointe), soldats envoyés, fenêtres d'assaut
    coordonné ouvertes ou prolongées (changements de rally_until).
  - Les contrôles finaux sont dans chaque scénario.
]]

local C = {}

C.MIN = 3600

local BASE = {
  { "gun-turret", 0, -6 }, { "assembling-machine-1", -6, 0 }, { "assembling-machine-1", -2, 0 },
  { "assembling-machine-1", 2, 0 }, { "assembling-machine-1", 6, 0 }, { "stone-furnace", -3, 5 },
  { "stone-furnace", 3, 5 }, { "wooden-chest", 0, 8 },
}
-- Lot IA0b : tourelles supplémentaires (rangée de 7 en y = -6, puis y = -10), la 1re étant celle de BASE.
local TURRET_X = { 0, -4, 4, -8, 8, -12, 12 }
local function layout(turrets)
  local list = {}
  for i, it in ipairs(BASE) do list[i] = it end
  for i = 2, turrets or 1 do
    local col, row = (i - 1) % #TURRET_X + 1, math.floor((i - 1) / #TURRET_X)
    list[#list + 1] = { "gun-turret", TURRET_X[col], -6 - 4 * row }
  end
  return list
end

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

function C.build_base(ctx, turrets)
  local s = ctx.surface()
  local c = game.forces.player.get_spawn_position(s)
  local center = { x = math.floor(c.x) - 96, y = math.floor(c.y) + 16 }
  ctx.prepare_area(center.x - 16, center.y - 16, center.x + 16, center.y + 16, "grass-1")
  local st = ctx.state()
  st.base, st.center, st.max_health = {}, center, {}
  local list = layout(turrets)
  for _, it in ipairs(list) do
    local want = { x = center.x + it[2], y = center.y + it[3] }
    local p = s.find_non_colliding_position(it[1], want, 12, 1)
    local e = p and s.create_entity({ name = it[1], position = p, force = "player" })
    if e then
      if it[1] == "gun-turret" then e.insert({ name = "piercing-rounds-magazine", count = 50 }) end
      st.base[#st.base + 1] = e
    end
  end
  ctx.check(#st.base == #list, "base temoin posee", string.format("%d/%d batiments (%d tourelles) en (%d, %d)", #st.base, #list,
    turrets or 1, center.x, center.y))
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
      local t = f.last_target or f.target -- last_target : lot IA0b (cible réelle, commune si jointe)
      rec.first_attack = f.last_attack
      rec.first_target = t and { x = t.x, y = t.y } or nil
      rec.first_defense = t and t.defense or nil
    end
    rec.joins, rec.sieges, rec.deterred, rec.soldiers = f.joins or 0, f.sieges or 0, f.deterred or 0, f.soldiers or 0
    if f.attacks > 0 and not st.first_attack then
      st.first_attack, st.first_key = f.last_attack, f.key
    end
  end
  st.losses = s.losses
  if s.rally_until and s.rally_until ~= st.last_rally then
    st.rallies, st.last_rally = (st.rallies or 0) + 1, s.rally_until
  end
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

--- Lot IA0b : contrôles d'une base témoin DÉFENDUE par `turrets` tourelles, attaquée et touchée au niveau
--- `level` (scénarios ia0-defendue*.lua). Journalise sièges, dissuasions et attaques jointes par faction.
function C.check_defended(ctx, level, turrets)
  local st = ctx.state()
  C.check_level(ctx, level)
  local early, keys = {}, {}
  for k in pairs(st.factions or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  local joins, sieges, soldiers = 0, 0, 0
  for _, k in ipairs(keys) do
    local r = st.factions[k]
    if r.first_attack and r.grace_end and r.first_attack < r.grace_end then early[#early + 1] = k .. "@" .. r.first_attack end
    joins, sieges, soldiers = joins + (r.joins or 0), sieges + (r.sieges or 0), soldiers + (r.soldiers or 0)
    ctx.log(string.format("%s : attaques %d (%d soldats), 1re au tick %s (defense estimee %s), sieges %d, dissuasions %d, attaques jointes %d",
      k, r.attacks or 0, r.soldiers or 0, tostring(r.first_attack), tostring(r.first_defense), r.sieges or 0, r.deterred or 0, r.joins or 0))
  end
  ctx.check(#early == 0, "aucune attaque contre le joueur avant la fin de la grace", table.concat(early, ", "))
  ctx.check(st.first_attack ~= nil, "au moins une attaque contre la base defendue",
    st.first_key and (st.first_key .. " au tick " .. st.first_attack) or "aucune")
  local r = st.first_key and st.factions[st.first_key]
  local t = r and r.first_target
  local near = false
  if t and st.center then
    local dx, dy = t.x - st.center.x, t.y - st.center.y
    near = dx * dx + dy * dy <= 48 * 48
  end
  ctx.check(near, "la 1re attaque vise la base temoin (cible a moins de 48 tuiles)", t and string.format("(%d, %d)", t.x, t.y) or "cible inconnue")
  ctx.check(r ~= nil and (r.first_defense or 0) >= 8 * turrets,
    "la faction a vu la defense (" .. turrets .. " tourelles, defense estimee >= " .. 8 * turrets .. ")", tostring(r and r.first_defense))
  ctx.check(st.base_hit ~= nil and st.first_attack ~= nil and st.base_hit > st.first_attack,
    "base temoin touchee apres la 1re attaque (batiment detruit ou endommage)", tostring(st.base_hit))
  ctx.check((st.losses or 0) >= 1, "pertes du joueur causees par une faction", st.losses)
  local n = st.attacks_total or 0
  ctx.log(string.format("total : %d attaques contre le joueur (taille moyenne %.1f), %d jointes (assaut coordonne), %d fenetres ouvertes ou prolongees, %d sieges",
    n, n > 0 and soldiers / n or 0, joins, st.rallies or 0, sieges))
  return joins, sieges, st.rallies or 0
end

return C
