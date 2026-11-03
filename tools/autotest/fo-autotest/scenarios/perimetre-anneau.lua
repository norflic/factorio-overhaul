--[[
  Variante « anneau » (même cadre que perimetre-base) : les 4 grappes éloignées reçoivent d'avance une paire de tourelles ARMÉES posées par le
  banc (hors de l'équipe) : aucun poste « point » n'y naît et les postes d'ANNEAU sont servis par le périmètre lui-même. Attendu : au moins
  2 postes d'anneau avec un groupe, au moins 4 tourelles posées par le périmètre (propriétaire « perim »).
  Lancement : banc.py --out <archive> --qui PERIMETRE -- 9600 perimetre-anneau <source>.

  Banc court du lot PERIMETRE (fo-logs/2026-11-03_PERIMETRE/CRITERES.md, C2) : votre équipe RICHE (coffre : fer, cuivre, 12 tourelles,
  chargeurs ; recherche de la tourelle faite), sans guerre ni ennemi, sur un terrain vidé ; base de test : une chaîne de fours vers l'est
  jusqu'à une grappe de 4 assembleurs à 60 tuiles du coffre, une ligne de fours vers le sud jusqu'à une grappe de 3 fours à 60 tuiles.
  Attendu au tick CHECK : au moins 2 GROUPES aux points sensibles (au moins 2 tourelles à moins de 8 tuiles du centre d'un poste « point »,
  à portée l'une de l'autre), au moins 1 anneau et au moins 1 poste d'anneau servi (2 tourelles à moins de 10 tuiles), couverture ARMÉE des
  points sensibles >= 80 % (calculée ici, indépendamment du mod), aucune erreur Lua (le banc s'arrêterait).
  Lancement : banc.py --out <archive> --qui PERIMETRE -- 9600 perimetre-base <source>. Journal : [FO-PERIMETRE-BASE] + [FO-PERIMETRE] du mod.
]]
local CHECK = 9300
local SENS = { "assembling-machine", "furnace", "lab", "boiler", "generator", "offshore-pump", "mining-drill" }
local TURRETS = { "ammo-turret", "electric-turret", "fluid-turret" }

local function place(s, name, x, y)
  local e = s.create_entity({ name = name, position = { x, y }, force = "player", raise_built = true })
  return e and 1 or 0
end

local function turrets_of(s)
  local out = {}
  for _, t in ipairs(s.find_entities_filtered({ force = "player", type = TURRETS })) do
    local inv = t.get_inventory(defines.inventory.turret_ammo)
    out[#out + 1] = { x = t.position.x, y = t.position.y, armed = inv ~= nil and inv.get_item_count() > 0, range = t.prototype.turret_range or 18 }
  end
  return out
end

local function near(list, x, y, r)
  local out = {}
  for _, t in ipairs(list) do if (t.x - x) ^ 2 + (t.y - y) ^ 2 <= r * r then out[#out + 1] = t end end
  return out
end

--- Un groupe : au moins 2 tourelles à moins de r du centre, chacune à portée d'une autre du groupe.
local function grouped(list, x, y, r)
  local g = near(list, x, y, r)
  if #g < 2 then return false, #g end
  for i, a in ipairs(g) do
    local ok = false
    for j, b in ipairs(g) do
      if i ~= j and (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 <= a.range * a.range then ok = true break end
    end
    if not ok then return false, #g end
  end
  return true, #g
end

return {
  description = "PERIMETRE (variante anneau) : grappes deja couvertes, postes d'anneau servis par le perimetre",
  base = nil,
  check_tick = CHECK,

  init = function(ctx)
    ctx.prepare_area(-120, -120, 120, 120, "grass-1")
    local s = ctx.surface()
    for _, e in ipairs(s.find_entities_filtered({ area = { { -400, -400 }, { 400, 400 } }, force = "enemy" })) do e.destroy() end
    local tech = game.forces.player.technologies["gun-turret"]
    ctx.check(tech ~= nil, "technologie de la tourelle connue")
    if tech then tech.researched = true end
    local chest = s.create_entity({ name = "fo-team-chest", position = { 0.5, 0.5 }, force = "player", raise_built = true })
    ctx.check(chest ~= nil, "coffre d'equipe pose")
    if not chest then return end
    for _, it in ipairs({ { "iron-plate", 9000 }, { "copper-plate", 3000 }, { "coal", 1500 }, { "stone", 400 }, { "pistol", 4 },
      { "firearm-magazine", 400 }, { "gun-turret", 12 } }) do
      chest.insert({ name = it[1], count = it[2] })
    end
    local n = 0
    for _, x in ipairs({ 20, 30, 40, 50 }) do n = n + place(s, "stone-furnace", x, 0) end
    for _, p in ipairs({ { 62, -2 }, { 66, -2 }, { 62, 2 }, { 66, 2 } }) do n = n + place(s, "assembling-machine-1", p[1], p[2]) end
    for _, y in ipairs({ 25, 35, 45 }) do n = n + place(s, "stone-furnace", 0, y) end
    for _, x in ipairs({ -4, 0, 4 }) do n = n + place(s, "stone-furnace", x, 60) end
    ctx.check(n == 14, "base de test posee (14 batiments)", n)
    local pre = 0
    for _, p in ipairs({ { 64, -6 }, { 64, 6 }, { 40, -4 }, { 40, 4 }, { -5, 56 }, { 3, 56 }, { -5, 35 }, { 5, 35 } }) do
      local t = s.create_entity({ name = "gun-turret", position = { p[1], p[2] }, force = "player" })
      if t then t.insert({ name = "firearm-magazine", count = 20 }) pre = pre + 1 end
    end
    ctx.check(pre == 8, "8 tourelles armees posees d'avance aux 4 grappes (hors equipe)", pre)
    ctx.state().t0 = game.tick
  end,

  finish = function(ctx)
    local s = ctx.surface()
    local st = ctx.remote("fo-perimetre", "status", "player")
    ctx.check(st ~= nil, "etat du perimetre lu (interface fo-perimetre)")
    if not st then return end
    local tur = turrets_of(s)
    local groups, ring_served, lines = 0, 0, {}
    for _, p in ipairs(st.posts) do
      local ok, n = grouped(tur, p.x, p.y, p.kind == "point" and 8 or 10)
      if ok and p.kind == "point" then groups = groups + 1 end
      if ok and p.kind == "ring" then ring_served = ring_served + 1 end
      lines[#lines + 1] = string.format("%s:%s(%.0f,%.0f)=%d", p.key, p.kind, p.x, p.y, n)
    end
    ctx.log("postes " .. table.concat(lines, " ") .. string.format(" ; tourelles %d ; poses %d ; perim %d", #tur, st.poses or 0, st.held or 0))
    ctx.check(#st.rings >= 1, "au moins un anneau", #st.rings)
    ctx.check(ring_served >= 2, "au moins 2 postes d'anneau avec un groupe (a moins de 10 tuiles)", ring_served)
    ctx.check((st.held or 0) >= 4, "au moins 4 tourelles posees par le perimetre (proprietaire perim)", st.held)
    -- couverture armée, calculée ici (indépendante du mod) : poids 3 fabrique/labo/centrale, 2 pompe, 1 foreuse, 20 le coffre
    local W = { ["assembling-machine"] = 3, furnace = 3, lab = 3, boiler = 3, generator = 3, ["offshore-pump"] = 2, ["mining-drill"] = 1 }
    local pts = {}
    for _, e in ipairs(s.find_entities_filtered({ force = "player", type = SENS, area = { { -192, -192 }, { 192, 192 } } })) do
      pts[#pts + 1] = { x = e.position.x, y = e.position.y, w = W[e.type] or 0 }
    end
    pts[#pts + 1] = { x = 0.5, y = 0.5, w = 20 }
    local w, wc = 0, 0
    for _, p in ipairs(pts) do
      w = w + p.w
      for _, t in ipairs(tur) do
        if t.armed and (t.x - p.x) ^ 2 + (t.y - p.y) ^ 2 <= (0.8 * t.range) ^ 2 then wc = wc + p.w break end
      end
    end
    local pct = w > 0 and math.floor(100 * wc / w + 0.5) or 0
    ctx.check(pct >= 80, "couverture armee des points sensibles >= 80 %", string.format("%d %% (%d/%d)", pct, wc, w))
  end,
}
