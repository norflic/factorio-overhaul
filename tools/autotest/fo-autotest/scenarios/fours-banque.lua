-- Scénario greffé « fours-banque » (lot FOURS, 28/10). Micro-banc en moteur réel de la règle shared/team/banque_fours.lua :
-- pour chaque flux de minerai F (objets/s), la fonderie électrique du catalogue (shared/team/modules.lua, G.smelter) est
-- posée à la taille que donne la banque (Bk.pairs(Bk.count(F))) ET, quand elle diffère, à la taille proportionnelle d'avant
-- (⌈F ÷ (2 r)⌉ paires). Le script verse le minerai sur la voie 1 du tapis d'entrée au débit F EXACT (jamais plus : un tapis
-- clairsemé, comme des foreuses qui ne débordent pas), le charbon sur la voie 2 à volonté ; la sortie est comptée puis vidée.
-- Mesures entre le tick WARM et le tick CHECK :
--   - plaques par seconde contre min(F, n r) du modèle (±12 %) ;
--   - charge de chaque four (part des échantillons où il travaille) : rangée par rangée, la rangée la moins servie contre
--     la borne B.LOAD_MIN, et fours inutilisés (charge < 5 %) comptés.
-- Lancement : fo-autotest.bat nopause 21600 fours-banque <source> (environ 1 min) ; sans images.
local M = require("__factorio-overhaul__/shared/team/modules")
local Bk = require("__factorio-overhaul__/shared/team/banque_fours")

local FORCE = "fo-fours"
local X0, Y0 = -3200, 2400
local SLOT_X, SLOT_Y = 40, 36
local COLS = 5
local WARM = 7200
local CHECK = WARM + 14400
local BUF = 1e8
local FURNACE = "stone-furnace"
local ORE, PLATE = "iron-ore", "iron-plate"
local FLOWS = { 0.4, 0.8, 1.2, 1.8, 2.5, 3.5, 5.0 }

local function sorted_keys(t)
  local k = {}
  for x in pairs(t) do k[#k + 1] = x end
  table.sort(k)
  return k
end

local function dist(a, b) local dx, dy = a.x - b.x, a.y - b.y; return math.sqrt(dx * dx + dy * dy) end

local function place_pole(s, x, y)
  for r = 0, 6 do
    for dx = -r, r do
      for dy = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then
          local p = { x = math.floor(x) + dx + 0.5, y = math.floor(y) + dy + 0.5 }
          if s.can_place_entity({ name = "medium-electric-pole", position = p, force = FORCE }) then
            return s.create_entity({ name = "medium-electric-pole", position = p, force = FORCE })
          end
        end
      end
    end
  end
  return nil
end

--- Placements : un par (flux, taille). La taille de la banque, puis l'ancienne si elle diffère.
local function placements()
  local sp = M.spec(FURNACE)
  local fr = Bk.furnace({ speed = sp.speed, time = M.RECIPES[PLATE].time, fuel_kw = sp.burner_kw, fuel_kj = M.COAL_J })
  local out = {}
  for _, F in ipairs(FLOWS) do
    local pb = Bk.pairs(Bk.count(F, fr.rate, Bk.COVER))
    local po = math.max(1, math.ceil(F / (2 * fr.rate) - 1e-9))
    out[#out + 1] = { F = F, pairs = pb, kind = "banque", r = fr.rate }
    if po ~= pb then out[#out + 1] = { F = F, pairs = po, kind = "ancien", r = fr.rate } end
  end
  return out
end

local function build(ctx, st, i, pl)
  local s = ctx.surface()
  local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
  local ox, oy = X0 + col * SLOT_X, Y0 + row * SLOT_Y
  local P = { pl = pl, ok = true, fails = {}, counts = {}, furn = {}, credit = 0, in_n = 0, out_n = 0, fur_samples = 0,
    key = string.format("F=%.2f %s (%d paires)", pl.F, pl.kind, pl.pairs) }
  st.P[i] = P
  local g0, why0 = M.GEN.smelter(FURNACE, ORE, pl.pairs)
  if not g0 then P.ok = false; P.fails[#P.fails + 1] = "gabarit : " .. tostring(why0); return end
  local inst, why = M.instantiate(g0, 0, ox, oy)
  if not inst then P.ok = false; P.fails[#P.fails + 1] = "instanciation : " .. tostring(why); return end
  local g = inst.gabarit
  P.g = g
  P.n_furn = 0
  local ents = {}
  for j, e in ipairs(inst.entities) do
    local ent = s.create_entity({ name = e.name, position = e.position, direction = e.direction, force = FORCE })
    ents[j] = ent
    if not ent then
      P.fails[#P.fails + 1] = "création refusée : " .. e.name .. " en " .. serpent.line(e.position)
    elseif M.spec(e.name).kind == "furnace" then
      P.furn[#P.furn + 1] = { ent = ent, y = e.position.y, x = e.position.x, work = 0 }
      P.n_furn = P.n_furn + 1
    end
  end
  for _, w in ipairs(M.wires(g)) do
    local a, b = ents[w[1]], ents[w[2]]
    if a and b then a.connect_neighbour(b) end
  end
  P.src, P.sink = {}, {}
  for _, p in ipairs(g.ports) do
    local ent = ents[p.ent]
    if ent and p.kind == "tapis" and p.io == "in" then P.src[#P.src + 1] = { ent = ent, lanes = { p.lanes[1], p.lanes[2] } } end
    if ent and p.kind == "tapis" and p.io == "out" then P.sink[#P.sink + 1] = ent end
  end
  -- électricité : interface vanilla reliée par un poteau d'arène
  local pole = g.power_pole and ents[g.power_pole]
  if pole then
    local best, bestd
    for x = ox - 4, ox + g.w + 3 do
      for y = oy - 4, oy + g.h + 3 do
        local inside = x >= ox - 1 and x < ox + g.w + 1 and y >= oy - 1 and y < oy + g.h + 1
        if not inside then
          local p = { x = x + 0.5, y = y + 0.5 }
          local d = dist(p, pole.position)
          if d <= 8.5 and (not bestd or d < bestd - 1e-9) then best, bestd = p, d end
        end
      end
    end
    local ap = best and place_pole(s, best.x, best.y)
    if ap then
      ap.connect_neighbour(pole)
      local px, py = ap.position.x, ap.position.y
      for _, t in ipairs({ { px + 2.5, py + 0.5 }, { px - 2.5, py + 0.5 }, { px + 0.5, py + 2.5 }, { px + 0.5, py - 2.5 } }) do
        if not P.eei and s.can_place_entity({ name = "electric-energy-interface", position = t, force = FORCE }) then
          local eei = s.create_entity({ name = "electric-energy-interface", position = t, force = FORCE })
          if eei then
            eei.electric_buffer_size = BUF
            eei.power_production = 0
            eei.power_usage = 0
            eei.energy = BUF
            P.eei = eei
          end
        end
      end
    end
  end
  if not P.eei then P.fails[#P.fails + 1] = "alimentation électrique impossible" end
  if #P.src ~= 1 or #P.sink ~= 2 then P.fails[#P.fails + 1] = "ports : " .. #P.src .. " entrée(s), " .. #P.sink .. " sortie(s)" end
  P.ox, P.oy = ox, oy
end

local function tick_all(st, tick)
  for _, P in ipairs(st.P) do
    if #P.fails == 0 then
      -- minerai au débit F exact sur la voie 1 (un minerai refusé par un tapis plein n'est pas rattrapé)
      P.credit = P.credit + P.pl.F / 60
      for _, sr in ipairs(P.src) do
        if sr.ent.valid then
          local l1 = sr.ent.get_transport_line(1)
          while P.credit >= 1 do
            P.credit = P.credit - 1
            if l1.can_insert_at_back() and l1.insert_at_back({ name = ORE, count = 1 }) then P.in_n = P.in_n + 1 end
          end
          local l2 = sr.ent.get_transport_line(2)
          if l2.can_insert_at_back() then l2.insert_at_back({ name = "coal", count = 1 }) end
        end
      end
      for _, sk in ipairs(P.sink) do
        if sk.valid then
          for l = 1, 2 do
            local line = sk.get_transport_line(l)
            P.out_n = P.out_n + (line.get_contents()[PLATE] or 0)
            line.clear()
          end
        end
      end
      if P.eei and P.eei.valid then P.eei.energy = BUF end
      if tick >= WARM and tick % 10 == 0 then
        P.fur_samples = P.fur_samples + 1
        for _, f in ipairs(P.furn) do
          if f.ent.valid and f.ent.status == defines.entity_status.working then f.work = f.work + 1 end
        end
      end
      if tick == WARM then P.in_snap, P.out_snap = P.in_n, P.out_n end
    end
  end
end

return {
  description = "fours-banque : fonderies dimensionnees par la banque de fours (shared/team/banque_fours.lua) contre l'ancienne taille, flux de minerai exact, 2 min de chauffe puis 4 min de mesure",
  base = nil,
  check_tick = CHECK,
  shots_delay = 2400,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.P = {}
    local force = game.forces[FORCE] or game.create_force(FORCE)
    force.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire(force, true)
    game.map_settings.pollution.enabled = false
    game.map_settings.enemy_expansion.enabled = false
    for _, r in ipairs(M.recipe_names()) do if force.recipes[r] then force.recipes[r].enabled = true end end
    local pls = placements()
    ctx.prepare_area(X0 - 16, Y0 - 16, X0 + COLS * SLOT_X + 16, Y0 + math.ceil(#pls / COLS) * SLOT_Y + 16, "grass-1")
    for i, pl in ipairs(pls) do build(ctx, st, i, pl) end
    local fails = {}
    for _, P in ipairs(st.P) do for _, f in ipairs(P.fails) do fails[#fails + 1] = P.key .. " : " .. f end end
    ctx.check(#fails == 0, "arène posée sans refus (" .. #st.P .. " fonderies)", table.concat(fails, " | "))
    -- prototypes : le four et la recette du jeu = ceux du modèle (vitesse, temps de recette)
    local p = game.entity_prototypes[FURNACE]
    local r = game.recipe_prototypes[PLATE]
    local sp = M.spec(FURNACE)
    ctx.check(p and r and math.abs(p.crafting_speed - sp.speed) < 1e-9 and math.abs(r.energy - M.RECIPES[PLATE].time) < 1e-9,
      "four et recette du jeu conformes au modèle (vitesse " .. tostring(p and p.crafting_speed) .. ", recette " .. tostring(r and r.energy) .. " s)")
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.P then return end
    tick_all(st, e.tick)
  end,

  finish = function(ctx)
    local st = ctx.state()
    local secs = (CHECK - WARM) / 60
    local bad_out, bad_load, idle_banque, idle_ancien = {}, {}, 0, 0
    local rows_ok = 0
    for _, P in ipairs(st.P) do
      if #P.fails == 0 then
        local made = ((P.out_n - (P.out_snap or 0)) / secs)
        local fed = ((P.in_n - (P.in_snap or 0)) / secs)
        local n_f = P.n_furn
        local cap = n_f * P.pl.r
        local want = math.min(P.pl.F, cap)
        -- charge de chaque four, regroupés par rangée (même y de centre), moyenne par rangée
        local rows = {}
        for _, f in ipairs(P.furn) do
          local key = string.format("%.1f", f.y)
          rows[key] = rows[key] or { sum = 0, n = 0 }
          rows[key].sum = rows[key].sum + f.work / math.max(1, P.fur_samples)
          rows[key].n = rows[key].n + 1
        end
        local min_row, line = 1, {}
        for _, k in ipairs(sorted_keys(rows)) do
          local avg = rows[k].sum / rows[k].n
          min_row = math.min(min_row, avg)
          line[#line + 1] = string.format("%.2f", avg)
        end
        local idle = 0
        for _, f in ipairs(P.furn) do if f.work / math.max(1, P.fur_samples) < 0.05 then idle = idle + 1 end end
        if P.pl.kind == "banque" then idle_banque = idle_banque + idle else idle_ancien = idle_ancien + idle end
        ctx.log(string.format("MESURE\t%s\t%d fours\tF=%.3f\tentre=%.3f\tproduit=%.3f\tattendu=%.3f\tcharge_min_rangee=%.3f\trangees=%s\tinutilises=%d",
          P.pl.kind, n_f, P.pl.F, fed, made, want, min_row, table.concat(line, ","), idle))
        if want > 0 and math.abs(made - want) / want > 0.12 then
          bad_out[#bad_out + 1] = string.format("%s (%d fours) : %.3f/s produits, %.3f attendus", P.key, n_f, made, want)
        end
        if P.pl.kind == "banque" then
          -- n_f ≥ 2 : la rangée la moins servie doit tenir la borne du modèle (B.LOAD_MIN)
          if n_f >= 2 and min_row < Bk.LOAD_MIN - 0.05 then
            bad_load[#bad_load + 1] = string.format("%s : rangée la moins servie à %.2f (borne %.2f)", P.key, min_row, Bk.LOAD_MIN)
          else
            rows_ok = rows_ok + 1
          end
        end
      end
    end
    ctx.check(#bad_out == 0, "plaques produites = min(F, n r) du modèle à ±12 % (" .. #st.P .. " fonderies)", table.concat(bad_out, " | "))
    ctx.check(#bad_load == 0, "banque dimensionnée : la rangée la moins servie tient la borne de charge du modèle (" .. rows_ok .. " fonderies)", table.concat(bad_load, " | "))
    ctx.check(idle_banque == 0, "banque dimensionnée : aucun four inutilisé (charge < 5 %), " .. idle_banque .. " trouvé(s) (ancienne taille : " .. idle_ancien .. ")")
  end,
}
