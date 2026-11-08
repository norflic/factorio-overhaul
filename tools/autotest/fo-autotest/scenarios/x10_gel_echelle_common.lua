--[[
  Lot X10-GEL, C20' (b) : scène ×10 synthétique (fo-logs/2026-11-07_X10/L1_CRITERES.md §4, « Scène de C20' (b) », accordée par le
  lead le 8/11 vers 8 h 30). Deux scénarios, une seule différence, le réglage de carte `fo-war-gel` écrit par le mod au premier tick
  (remote « fo-gel », reglage) :
    x10-gel-echelle-temoin : éteint (rien n'est figé) ;
    x10-gel-echelle-gel    : allumé.
  COMPOSITION : scenarios/x10_gel_echelle_compo.lua, écrite par tools/autotest/x10_gel_compo.py depuis le RECENSEMENT de la partie du
  DC (scénario x10-gel-recensement, archive nommée dans ce fichier). Une faction de la partie = un groupe de banc (interface « fo-gel »)
  sur sa propre force ; chaque îlot relevé (sorte, foreuses, minerai, gisement, charbon, statuts), chaque candidat refusé (par raison),
  chaque soldat (nom, rôle, distance), chaque poste et chaque amas de tourelles de la faction est posé FACTEUR fois, à sa distance du QG
  (dix directions ; un bloc qui en chevauche un autre est repoussé vers l'extérieur, de 16 tuiles en 16 tuiles : distances relevées au
  journal). Candidats relevés de nouveau toutes les Gu.RESCAN ticks comme ceux d'une faction (remote « fo-gel » candidats).
  Ce qui reste plus facile qu'en partie (L1, dit tel quel) : aucune faction n'y pense (pas d'IA, pas d'attaque, pas d'armée dehors) ;
  tourelles sans munitions ; foreuses électriques refusées sans courant ; expansion des biters coupée, cessez-le-feu avec eux.
  Lancement (PC au repos, accord du lead) :
    py -3.9 -B tools/autotest/banc.py --seul --qui X10-GEL --out <archive> -- 10000 x10-gel-echelle-temoin <copie figée>
    (puis x10-gel-echelle-gel ; ordre T, G, T, G, T, G) ; fenêtre de mesure : ticks 3 000 à 10 000.
]]
local COMPO = require("scenarios/x10_gel_echelle_compo")

local FACTOR = 10
local CELL_W, CELL_H = 7, 8      -- cellule d'un îlot ou d'un refus d'avant-poste
local QCELL = 4                  -- cellule d'un four du QG
local HQ_X0, HQ_DX, HQ_Y = 6000, 3000, 6000
local HOME_DY = 14               -- garnison du QG : QG + (0, 14) (script/ai3/soldats.lua, home)
local BLOCKS_PER_TICK = 2
local BUILD_TICK = 10
-- dix directions (vecteurs unitaires écrits, pas de trigonométrie) : 0°, 36°, 72°, ... 324°
local DIRS = { { 1, 0 }, { 0.809, 0.5878 }, { 0.309, 0.9511 }, { -0.309, 0.9511 }, { -0.809, 0.5878 }, { -1, 0 }, { -0.809, -0.5878 },
  { -0.309, -0.9511 }, { 0.309, -0.9511 }, { 0.809, -0.5878 } }

local function force_of(g) return "fo-gel-e" .. g end
local function bench_of(g) return "e" .. g end

local function sorted_keys(t)
  local k = {}
  for x in next, t do k[#k + 1] = x end
  table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
  return k
end

-- Hasard du banc (déterministe : LCG, bits HAUTS ; les bits bas d'un LCG modulo 2^31 ont une période courte).
local function rng(st)
  st.seed = (st.seed * 1103515245 + 12345) % 2147483648
  return math.floor(st.seed / 65536)
end
local function between(st, a, b)
  if b <= a then return a end
  return a + rng(st) % (b - a + 1)
end

--- Statuts d'un îlot du recensement (« working=2 no_fuel=1 ») -> liste de statuts, un par machine, dans l'ordre foreuses puis four.
local function statuses(etats, n)
  local out = {}
  for _, part in ipairs((function() local p = {} for w in string.gmatch(etats or "", "%S+") do p[#p + 1] = w end return p end)()) do
    local k, v = string.match(part, "^([%w_]+)=(%d+)$")
    if k then for _ = 1, tonumber(v) do out[#out + 1] = k end end
  end
  for i = #out + 1, n do out[i] = "working" end
  return out
end

---------------------------------------------------------------------------------------------------
-- Plan (tick BUILD_TICK) : blocs placés, sans rien poser
---------------------------------------------------------------------------------------------------
local function overlaps(placed, r)
  for _, q in ipairs(placed) do
    if r.x0 < q.x1 + 4 and q.x0 < r.x1 + 4 and r.y0 < q.y1 + 4 and q.y0 < r.y1 + 4 then return true end
  end
  return false
end

--- Rectangle libre le plus proche de la distance voulue, dans la direction j ; rend le rectangle et la distance prise.
local function place_rect(placed, hq, dist, j, w, h)
  local d = dist
  for _ = 1, 400 do
    local v = DIRS[(j - 1) % #DIRS + 1]
    local cx, cy = math.floor(hq.x + v[1] * d), math.floor(hq.y + v[2] * d)
    local r = { x0 = cx - math.floor(w / 2), y0 = cy - math.floor(h / 2) }
    r.x1, r.y1 = r.x0 + w, r.y0 + h
    if not overlaps(placed, r) then
      placed[#placed + 1] = r
      return r, d
    end
    d = d + 16
  end
  error("x10-gel-echelle : aucune place libre pour un bloc")
end

--- Plan d'une faction du recensement (groupe g) : blocs d'avant-postes (îlots et refus), bloc du QG, postes, amas.
local function plan_faction(g, F, st)
  local hq = { x = HQ_X0 + (g - 1) * HQ_DX, y = HQ_Y }
  local placed = {}
  local P = { g = g, hq = hq, blocks = {}, soldiers = {}, turrets = {}, wanted = {}, got = {} }
  -- bloc du QG (fours du QG relevés et refusés) d'abord, au nord du QG ; la garnison du QG est au sud (QG + (0, 14))
  local qcells = {}
  for _, I in ipairs(F.ilots) do
    if I.s == "qg" then for _ = 1, FACTOR do qcells[#qcells + 1] = { k = "qg", I = I } end end
  end
  for _, why in ipairs(F.refus_qg) do for _ = 1, FACTOR do qcells[#qcells + 1] = { k = "qg-refus", why = why } end end
  if #qcells > 0 then
    local cols = math.max(1, math.ceil(math.sqrt(#qcells)))
    local rows = math.ceil(#qcells / cols)
    local r = { x0 = hq.x - math.floor(cols * QCELL / 2), y0 = hq.y - 8 - rows * QCELL }
    r.x1, r.y1 = r.x0 + cols * QCELL, r.y0 + rows * QCELL
    placed[#placed + 1] = r
    P.blocks[#P.blocks + 1] = { rect = r, cols = cols, cell_w = QCELL, cell_h = QCELL, cells = qcells }
  end
  local home = { x0 = hq.x - 10, y0 = hq.y - 6, x1 = hq.x + 10, y1 = hq.y + HOME_DY + 10 } -- garnison du QG : place gardée et préparée
  placed[#placed + 1] = home
  P.blocks[#P.blocks + 1] = { rect = home, cols = 0, cells = {} }
  -- avant-postes : chaque avant-poste du recensement, FACTOR fois, dans les dix directions, à sa distance
  for k, O in ipairs(F.outposts) do
    local cells = {}
    for _, I in ipairs(O.ilots) do cells[#cells + 1] = { k = I.s, I = I } end
    for _, why in ipairs(O.refus) do cells[#cells + 1] = { k = "refus", why = why } end
    if #cells > 0 then
      local cols = math.max(1, math.ceil(math.sqrt(#cells)))
      local rows = math.ceil(#cells / cols)
      for j = 1, FACTOR do
        local r, d = place_rect(placed, hq, O.d, j + k, cols * CELL_W, rows * CELL_H)
        P.blocks[#P.blocks + 1] = { rect = r, cols = cols, cell_w = CELL_W, cell_h = CELL_H, cells = cells }
        P.wanted[#P.wanted + 1], P.got[#P.got + 1] = O.d, d
      end
    end
  end
  -- amas de tourelles : FACTOR fois, à leur distance (bloc de 3 tuiles par tourelle)
  for k, A in ipairs(F.amas) do
    for j = 1, FACTOR do
      local cols = math.max(1, math.ceil(math.sqrt(A.t)))
      local rows = math.ceil(A.t / cols)
      local r = place_rect(placed, hq, A.d, j + 3 * k, cols * 3, rows * 3)
      for i = 1, A.t do
        local cx, cy = (i - 1) % cols, math.floor((i - 1) / cols)
        P.turrets[#P.turrets + 1] = { x = r.x0 + cx * 3 + 1, y = r.y0 + cy * 3 + 1, name = F.turret_names[between(st, 1, #F.turret_names)] }
      end
      P.blocks[#P.blocks + 1] = { rect = r, cols = 0, cells = {} } -- zone préparée pour les tourelles
    end
  end
  -- soldats : rôle et nom du recensement, FACTOR fois ; gardes et patrouilles répartis sur les postes (FACTOR fois chacun)
  local posts = {}
  for k, d in ipairs(F.postes) do
    for j = 1, FACTOR do
      local r = place_rect(placed, hq, d, j + 7 * k, 12, 12)
      posts[#posts + 1] = { x = r.x0 + 6, y = r.y0 + 6 }
      P.blocks[#P.blocks + 1] = { rect = r, cols = 0, cells = {} }
    end
  end
  local np = 0
  for _, S in ipairs(F.soldats) do
    for _ = 1, FACTOR do
      local s = { name = S.name, role = S.role }
      if S.role == "qg" or #posts == 0 then
        s.x, s.y = hq.x + between(st, -6, 6), hq.y + HOME_DY + between(st, -4, 4)
        s.role = nil
      else
        np = np + 1
        local p = posts[(np - 1) % #posts + 1]
        s.px, s.py = p.x, p.y
        s.x, s.y = p.x + between(st, -3, 3), p.y + between(st, -3, 3)
      end
      P.soldiers[#P.soldiers + 1] = s
    end
  end
  return P
end

---------------------------------------------------------------------------------------------------
-- Pose d'un bloc
---------------------------------------------------------------------------------------------------
local SMELT = {}
local function plate_of(ore)
  if SMELT[ore] ~= nil then return SMELT[ore] or nil end
  SMELT[ore] = false
  for _, name in ipairs(sorted_keys(game.recipe_prototypes)) do
    local r = game.recipe_prototypes[name]
    if r.category == "smelting" and #r.ingredients == 1 and r.ingredients[1].name == ore and r.products[1] and r.products[1].type == "item" then
      SMELT[ore] = r.products[1].name
      break
    end
  end
  return SMELT[ore] or nil
end

local function ore_under(s, x, y, ore, amount)
  if not game.entity_prototypes[ore] then ore = "iron-ore" end
  for _, dx in ipairs({ -0.5, 0.5 }) do
    for _, dy in ipairs({ -0.5, 0.5 }) do s.create_entity({ name = ore, position = { x + dx, y + dy }, amount = math.max(1, amount) }) end
  end
end

local function fuel(e, st, I, status)
  if status == "no_fuel" then return end
  local c = between(st, I and I.c0 or 5, I and I.c1 or 50)
  if c > 0 then e.insert({ name = "coal", count = c }) end
end

local function fill(inv, item)
  if not (inv and item) then return end
  for _ = 1, 64 do
    if inv.insert({ name = item, count = 1000 }) == 0 then return end
  end
end

local function drill(s, force, x, y, dir, I, st, status, out)
  local per = math.floor((I and I.g or 4000) / (4 * math.max(1, I and I.f or 1)))
  ore_under(s, x, y, I and I.m or "iron-ore", per)
  local d = s.create_entity({ name = "burner-mining-drill", position = { x, y }, direction = dir, force = force })
  if d then fuel(d, st, I, status); out.drills[#out.drills + 1] = d end
  return d
end

local function chest_at_drop(s, force, d)
  local dp = d.drop_position
  return s.create_entity({ name = "wooden-chest", position = { math.floor(dp.x) + 0.5, math.floor(dp.y) + 0.5 }, force = force })
end

--- Cellule d'avant-poste en (cx, cy) : îlot (coffre, four) ou refus. Rend l'entité à adopter (îlot) ou nil.
local function cell_outpost(s, force, cx, cy, c, st, out)
  local D = defines.direction
  if c.k == "coffre" then
    local stt = statuses(c.I.e, 1)
    local d = drill(s, force, cx + 3, cy + 5, D.north, c.I, st, stt[1], out)
    local ch = d and chest_at_drop(s, force, d)
    if ch and (stt[1] == "full_output" or stt[1] == "waiting_for_space_in_destination") then fill(ch.get_inventory(defines.inventory.chest), c.I.m) end
    return d
  elseif c.k == "four" then
    local n = math.max(1, math.min(4, c.I.f))
    local stt = statuses(c.I.e, n + 1)
    local spots = { { 3, 6, D.north }, { 3, 2, D.south }, { 5, 4, D.west }, { 1, 4, D.east } }
    local first
    for i = 1, n do
      local p = spots[i]
      local d = drill(s, force, cx + p[1], cy + p[2], p[3], c.I, st, stt[i], out)
      first = first or d
    end
    local f = s.create_entity({ name = "stone-furnace", position = { cx + 3, cy + 4 }, force = force })
    if f then
      fuel(f, st, c.I, stt[n + 1])
      if stt[n + 1] == "full_output" then fill(f.get_output_inventory(), plate_of(c.I.m)) end
    end
    return first
  end
  -- refus d'avant-poste (raison du recensement) ; une raison sans cas écrit ici est posée en « sans cible » (dit au journal)
  local why = c.why
  if why == "electrique" then
    local e = s.create_entity({ name = "electric-mining-drill", position = { cx + 3.5, cy + 4.5 }, direction = D.north, force = force })
    if e then out.drills[#out.drills + 1] = e end
  elseif why == "bus" then
    local d = drill(s, force, cx + 3, cy + 5, D.north, nil, st, "working", out)
    local dp = d and d.drop_position
    if dp then s.create_entity({ name = "transport-belt", position = { math.floor(dp.x) + 0.5, math.floor(dp.y) + 0.5 }, direction = D.east, force = force }) end
  elseif why == "bras" then
    drill(s, force, cx + 3, cy + 6, D.north, nil, st, "working", out)
    local f = s.create_entity({ name = "stone-furnace", position = { cx + 3, cy + 4 }, force = force })
    if f then f.insert({ name = "coal", count = 5 }) end
    s.create_entity({ name = "burner-inserter", position = { cx + 4.5, cy + 3.5 }, direction = D.west, force = force })
  else
    drill(s, force, cx + 3, cy + 5, D.north, nil, st, "working", out) -- « sans cible » : rien sur la tuile de dépôt
    out.unknown[why] = (out.unknown[why] or 0) + 1
  end
  return nil
end

--- Cellule du QG : four rempli à la main (îlot) ou refusé (« recette » : vide ; « bras » : un bras le sert ; autre : vide).
local function cell_qg(s, force, cx, cy, c, st, out)
  local f = s.create_entity({ name = "stone-furnace", position = { cx + 2, cy + 2 }, force = force })
  if not f then return nil end
  out.fours[#out.fours + 1] = f
  if c.k == "qg" then
    local stt = statuses(c.I.e, 1)
    fuel(f, st, c.I, stt[1])
    local item = c.I.m
    if not game.item_prototypes[item] or not plate_of(item) then item = "iron-ore" end
    f.get_inventory(defines.inventory.furnace_source).insert({ name = item, count = between(st, 10, 50) })
    if stt[1] == "full_output" then fill(f.get_output_inventory(), plate_of(item)) end
    return f
  end
  f.insert({ name = "coal", count = 5 })
  if c.why == "bras" then
    f.get_inventory(defines.inventory.furnace_source).insert({ name = "iron-ore", count = 10 })
    s.create_entity({ name = "burner-inserter", position = { cx + 3.5, cy + 1.5 }, direction = defines.direction.west, force = force })
  elseif c.why ~= "recette" then
    out.unknown[c.why] = (out.unknown[c.why] or 0) + 1
  end
  return nil
end

local function build_block(ctx, s, P, B, st, out)
  local r = B.rect
  ctx.prepare_area(r.x0 - 2, r.y0 - 2, r.x1 + 2, r.y1 + 2, "grass-1")
  local force = force_of(P.g)
  for i, c in ipairs(B.cells) do
    local cx = r.x0 + ((i - 1) % B.cols) * B.cell_w
    local cy = r.y0 + math.floor((i - 1) / B.cols) * B.cell_h
    local head
    if B.cell_w == QCELL then head = cell_qg(s, force, cx, cy, c, st, out) else head = cell_outpost(s, force, cx, cy, c, st, out) end
    if head then out.heads[#out.heads + 1] = head end
  end
end

---------------------------------------------------------------------------------------------------
-- Scénario
---------------------------------------------------------------------------------------------------
return function(ON)
  local S = {
    description = "X10-GEL C20' (b) : scene x10 synthetique (recensement de la partie du DC), fo-war-gel " .. (ON and "ALLUME" or "ETEINT"),
    check_tick = 9900,
  }
  local function report(ctx, tag)
    local b = ctx.remote("fo-gel", "bilan")
    if b then
      log(string.format("[FO-X10-ECHELLE] %s tick %d : gel %s ; ilots %d, figes %d, machines figees %d (n_frozen %d), soldats figes %d", tag,
        game.tick, ON and "allume" or "eteint", b.ilots, b.figes, b.machines_figees, b.n_frozen, b.soldats_figes))
    end
    return b
  end
  S.init = function(ctx)
    local now = ctx.remote("fo-gel", "reglage", ON)
    ctx.check(now == ON, "fo-war-gel ecrit par le mod au chargement : " .. (ON and "allume" or "eteint"), tostring(now))
    ctx.call("profiler", false, false)
  end
  S.tick = function(ctx, e)
    local st = ctx.state()
    local s = ctx.surface()
    if e.tick == BUILD_TICK then
      game.map_settings.enemy_expansion.enabled = false
      st.rng = { seed = 20261108 }
      st.plans, st.queue, st.qpos = {}, {}, 1
      for g, F in ipairs(COMPO.factions) do
        local fname = force_of(g)
        if not game.forces[fname] then game.create_force(fname) end
        st.plans[g] = plan_faction(g, F, st.rng)
        for _, B in ipairs(st.plans[g].blocks) do st.queue[#st.queue + 1] = { g = g, B = B } end
      end
      for g = 1, #COMPO.factions do
        local fa = game.forces[force_of(g)]
        fa.set_cease_fire("enemy", true)
        game.forces.enemy.set_cease_fire(fa, true)
        for h = 1, #COMPO.factions do if h ~= g then fa.set_cease_fire(force_of(h), true) end end
        ctx.remote("fo-gel", "banc", bench_of(g), force_of(g))
        ctx.remote("fo-gel", "joueurs", bench_of(g), {})
      end
      st.out = {}
      for g = 1, #COMPO.factions do st.out[g] = { drills = {}, fours = {}, heads = {}, unknown = {} } end
      log(string.format("[FO-X10-ECHELLE] plan : %d bloc(s) a poser, facteur %d, source du recensement %s", #st.queue, FACTOR, tostring(COMPO.source)))
    elseif st.queue and st.qpos <= #st.queue then
      for _ = 1, BLOCKS_PER_TICK do
        local q = st.queue[st.qpos]
        if not q then break end
        build_block(ctx, s, st.plans[q.g], q.B, st.rng, st.out[q.g])
        st.qpos = st.qpos + 1
      end
      if st.qpos > #st.queue then st.built_at = e.tick end
    elseif st.built_at and not st.adopted then
      -- îlots adoptés (relevé initial du banc, hors fenêtre), candidats donnés (relevés de nouveau comme une faction), garnisons
      local why_all, n_ok, n_cands = {}, 0, 0
      for g = 1, #COMPO.factions do
        local O, name = st.out[g], bench_of(g)
        for _, h in ipairs(O.heads) do
          local r = h.valid and ctx.remote("fo-gel", "adopte", name, h)
          if r and r.id then n_ok = n_ok + 1 else local w = tostring(r and r.why); why_all[w] = (why_all[w] or 0) + 1 end
        end
        ctx.remote("fo-gel", "candidats", name, O.drills, O.fours)
        n_cands = n_cands + #O.drills + #O.fours
        local P = st.plans[g]
        ctx.remote("fo-gel", "garnison", name, force_of(g), { x = P.hq.x, y = P.hq.y }, 1)
        ctx.remote("fo-gel", "g_joueurs", name, {})
        for _, sd in ipairs(P.soldiers) do
          local u = s.create_entity({ name = sd.name, position = { sd.x, sd.y }, force = force_of(g) })
          if u then ctx.remote("fo-gel", "soldat", name, u, sd.role, sd.px, sd.py) end
        end
        for _, t in ipairs(P.turrets) do
          local te = s.create_entity({ name = t.name, position = { t.x, t.y }, force = force_of(g) })
          if te then ctx.remote("fo-gel", "tourelle", name, te) end
        end
      end
      local wl, unk = {}, {}
      for _, k in ipairs(sorted_keys(why_all)) do wl[#wl + 1] = k .. "=" .. why_all[k] end
      for g = 1, #COMPO.factions do
        for _, k in ipairs(sorted_keys(st.out[g].unknown)) do unk[#unk + 1] = "e" .. g .. ":" .. k .. "=" .. st.out[g].unknown[k] end
      end
      log(string.format("[FO-X10-ECHELLE] pose finie au tick %d : %d ilot(s) adopte(s), refus a l'adoption [%s] ; %d candidat(s) ; raisons posees en « sans cible » [%s]",
        e.tick, n_ok, table.concat(wl, " "), n_cands, table.concat(unk, " ")))
      for g = 1, #COMPO.factions do
        local P = st.plans[g]
        local far, sum_w, sum_g = 0, 0, 0
        for i = 1, #P.wanted do
          sum_w, sum_g = sum_w + P.wanted[i], sum_g + P.got[i]
          if P.got[i] > P.wanted[i] then far = far + 1 end
        end
        log(string.format("[FO-X10-ECHELLE] groupe %s : %d soldat(s), %d tourelle(s), %d bloc(s) d'avant-poste dont %d repousse(s) ; distance moyenne voulue %.0f, prise %.0f",
          bench_of(g), #P.soldiers, #P.turrets, #P.wanted, far, #P.wanted > 0 and sum_w / #P.wanted or 0, #P.wanted > 0 and sum_g / #P.wanted or 0))
      end
      ctx.check(e.tick < 3000, "scene posee avant la fenetre de mesure (tick 3 000)", e.tick)
      st.adopted = e.tick
    end
    if st.adopted and e.tick > st.adopted and (e.tick - st.adopted) % 600 == 0 then report(ctx, "releve") end
  end
  S.finish = function(ctx)
    local b = report(ctx, "bilan")
    local r = ctx.remote("fo-gel", "recensement")
    if r then
      local by = {}
      for _, I in ipairs(r.ilots) do by[I.sorte] = (by[I.sorte] or 0) + 1 end
      local parts = {}
      for _, k in ipairs(sorted_keys(by)) do parts[#parts + 1] = k .. "=" .. by[k] end
      log(string.format("[FO-X10-ECHELLE] recensement de la scene : %d ilot(s) [%s]", #r.ilots, table.concat(parts, " ")))
    end
    if ON then
      ctx.check(b ~= nil and (b.figes > 0 or b.soldats_figes > 0), "gel en marche au bilan (quelque chose est fige)",
        b and string.format("%d ilot(s), %d soldat(s)", b.figes, b.soldats_figes) or "-")
    else
      ctx.check(b ~= nil and b.figes == 0 and b.soldats_figes == 0 and b.n_frozen == 0, "temoin : rien de fige", b and
        string.format("%d ilot(s), %d soldat(s)", b.figes, b.soldats_figes) or "-")
    end
  end
  return S
end
