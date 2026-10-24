-- Scénario greffé « ia1-modules » (lot IA1-c, docs/EQUIPES_PNJ.md §6.4, §16 ; RD_LOG E126, E127 proposées).
-- Chaque gabarit du catalogue (shared/team/modules.lua) est posé dans une arène, à la position et dans la direction
-- que donne le modèle, par une force à part (aucun bonus de recherche : bras à pile de 1). Alimentation :
--   - tapis d'entrée : chaque voie est remplie par le script à chaque tick (insert_at_back), comme un coffre infini
--     à débit illimité ; tuyau d'entrée : un tuyau nourricier remis plein (100) à chaque tick ;
--   - sorties : la tuile du port de sortie (tapis) est comptée voie par voie puis vidée à chaque tick ; un tuyau
--     puits est compté puis vidé à chaque tick ; les fours des avant-postes sont vidés toutes les 60 ticks ;
--   - électricité : interface électrique vanilla posée hors de l'emprise, reliée par un poteau au poteau de
--     raccordement du gabarit (le gabarit se sert de ses PROPRES poteaux) ; sa réserve est remise pleine à chaque
--     tick et l'énergie prise est comptée ; centrale à vapeur : 15 radars (4,5 MW) en charge, production lue sur les
--     machines (energy_generated_last_tick) ;
--   - combustible des avant-postes (porteurs) : charbon remis par le script toutes les 60 ticks ; bras à combustion
--     de la centrale : 2 charbons à la pose (comme une pose par un joueur), puis ils se servent sur le tapis.
-- Mesure : débit de chaque sortie ET de chaque entrée entre le tick WARM (25 min, régime établi, tapis de jonction
-- des packs saturés) et le tick CHECK (10 min plus tard), à ±10 % du nominal du modèle (g.nominal, g.inputs).
-- Recoupements du modèle avec le moteur : positions, prise et dépôt des bras, dépôt des foreuses, systèmes de fluides (même réseau dans le modèle ⇔ même get_fluid_system_id), réseau électrique, voies des
-- tapis de sortie. R8 : débit de conduites droites de 1 à 400 tuyaux.
-- Correction IA1-c (vérification adverse) : l'arène pose aussi les gabarits AGRANDIS à leur maximum déclaré
-- (extensions : centrale de 7 chaudières, etc.), TOUTES les variantes d'ère (M.era_variants : bâtiments aux niveaux
-- 7, 13 et 19, « remplacer le module » au changement d'emprise) et une CONTRE-ÉPREUVE refusée par le contrôle
-- (plastique à 6 usines : 12/s sur une voie de 7,5/s) dont la sortie doit plafonner au flot maximal du modèle. La
-- charge de chaque centrale est faite de radars (300 kW) : 25 % au-dessus de sa puissance nominale.
-- Lancement : `fo-autotest.bat nopause 128000 ia1-modules <source>` (environ 2 min) ; images : `fo-captures.bat ia1-modules <source>`.

local M = require("__factorio-overhaul__/shared/team/modules")

local FORCE = "fo-ia1m"
local X0, Y0 = -3200, 1600
local SLOT = 64
local COLS = 6
-- Correction IA1-c (mineur 3) : 30 s ne suffisaient pas aux blocs à deux étages (packs), dont l'étage A remplit le
-- tapis de jonction pendant des minutes (bras et convoyeurs à 133 % du modèle, entrées à 138 %). Passage de
-- diagnostic de 30 min (journal SUIVI, minute par minute, correction\ia1-modules-suivi) : dernière minute d'une
-- entrée hors de ±10 % = minute 17 (packs-verts-3-n13), 13 (packs-rouges-2-n19), 9 (packs-verts) ; ensuite tout
-- reste à ±10 % (hors grain du charbon, minute par minute). D'où un échauffement de 25 min et une fenêtre de 10 min.
local WARM = 90000
local WINDOW = 36000
local CHECK = WARM + WINDOW
local BUF = 1e8
local R8_LENGTHS = { 1, 2, 5, 10, 12, 17, 20, 30, 50, 100, 200, 400 }
local TOL = 0.02

-- Placements : tout le catalogue droit, plus des gabarits tournés (matrices entières).
local EXTRA = {
  { "fonderie-fer-pierre", 1 }, { "circuits-verts", 3 }, { "soufre-2", 2 }, { "raffinerie-2", 1 },
  { "centrale-vapeur-2", 2 }, { "packs-verts", 1 }, { "foreuses-fer-n7", 3 },
}

-- Gabarits agrandis au maximum déclaré de leur extension (correction IA1-c, défaut majeur 1).
local EXT = {
  { "centrale-vapeur-2", 7 }, { "fonderie-fer-acier", 6 }, { "engrenages", 5 }, { "plastique-2", 3 }, { "soufre-2", 3 },
  { "foreuses-fer", 7 },
}
-- Contre-épreuve : refusée par le contrôle ; la sortie mesurée doit être le flot maximal du modèle (une voie).
local CONTRE = { { "plastique-2", 6 } }

local function placements()
  local out = {}
  for _, g in ipairs(M.catalogue()) do out[#out + 1] = { key = g.key, k = 0 } end
  for _, e in ipairs(EXTRA) do out[#out + 1] = { key = e[1], k = e[2] } end
  for _, e in ipairs(EXT) do out[#out + 1] = { key = e[1], k = 0, ext = e[2] } end
  for _, r in ipairs(M.era_variants()) do out[#out + 1] = { key = r.key, k = 0 } end
  for _, e in ipairs(CONTRE) do out[#out + 1] = { key = e[1], k = 0, ext = e[2], contre = true } end
  return out
end

--- Gabarit d'un placement (catalogue, variante d'ère, extension ou contre-épreuve) ; calcul pur et déterministe,
--- refait au besoin (aucune fonction ni gabarit gardé dans global).
local function resolve(pl)
  local base = pl.base or pl.key
  local g = M.get_any(base)
  if not g then return nil, "gabarit inconnu : " .. tostring(base) end
  if pl.ext then
    if pl.contre then return M.regenerate(g, { [g.extensions[1].arg] = pl.ext }) end
    return M.extend(g, pl.ext)
  end
  return g
end

local function slot_origin(i)
  local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
  return X0 + col * SLOT, Y0 + row * SLOT
end

local function dist(a, b) local dx, dy = a.x - b.x, a.y - b.y; return math.sqrt(dx * dx + dy * dy) end

local function sorted_keys(t)
  local k = {}
  for x in pairs(t) do k[#k + 1] = x end
  table.sort(k)
  return k
end

--- Poteau moyen posé au plus près de (x, y) sur une tuile libre (décalage en spirale jusqu'à 6).
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

--- Chaîne de poteaux de `a` (entité poteau) vers la position b, fils compris ; renvoie le dernier poteau.
local function chain(s, a, b)
  local cur = a
  for _ = 1, 40 do
    local d = dist(cur.position, b)
    if d <= 7 then
      local last = place_pole(s, b.x, b.y)
      if last then cur.connect_neighbour(last); return last end
      return cur
    end
    local t = 7 / d
    local nxt = place_pole(s, cur.position.x + (b.x - cur.position.x) * t, cur.position.y + (b.y - cur.position.y) * t)
    if not nxt then return cur end
    cur.connect_neighbour(nxt)
    cur = nxt
  end
  return cur
end

local function setup_research(ctx, force)
  local names = {}
  for name in pairs(game.technology_prototypes) do names[#names + 1] = name end
  table.sort(names)
  local function only_recipes(t)
    for _, eff in ipairs(t.effects or {}) do if eff.type ~= "unlock-recipe" then return false end end
    return true
  end
  for _, name in ipairs(names) do
    local t = force.technologies[name]
    local ing = t.research_unit_ingredients
    local red, green = false, false
    for _, i in ipairs(ing) do
      if i.name == "automation-science-pack" then red = true elseif i.name == "logistic-science-pack" then green = true end
    end
    if #ing == 2 and red and green and t.enabled and not t.researched and math.abs(t.research_unit_energy - 60 * M.LAB_UNIT_TIME) < 0.5 then
      local seen, list, ok = {}, {}, true
      local function walk(x)
        local pn = sorted_keys(x.prerequisites)
        for _, p in ipairs(pn) do
          local pt = x.prerequisites[p]
          if not seen[p] and not pt.researched then
            seen[p] = true
            if not only_recipes(pt) then ok = false end
            walk(pt)
            list[#list + 1] = pt
          end
        end
      end
      walk(t)
      if ok then
        for _, p in ipairs(list) do p.researched = true end
        force.add_research(t)
        ctx.log("labos : recherche « " .. name .. " » (" .. t.research_unit_count .. " unités de " .. (t.research_unit_energy / 60) .. " s), " .. #list .. " prérequis posés")
        return name
      end
    end
  end
  return nil
end

local function build(ctx, st, i, pl)
  local s = ctx.surface()
  local g0, why0 = resolve(pl)
  local sx, sy = slot_origin(i)
  local ox, oy = sx + 8, sy + 8
  local P = { key = pl.key .. (pl.ext and ("@" .. pl.ext) or ""), base = pl.key, ext = pl.ext, contre = pl.contre, k = pl.k, ox = ox, oy = oy,
    ok = true, fails = {}, src = {}, sink = {}, fsrc = {}, fsink = {}, furn = {}, fuel = {}, engines = {}, counts = {}, lane_seen = {},
    energy = 0, gen = 0 }
  st.P[i] = P
  if not g0 then P.ok = false; P.fails[#P.fails + 1] = "gabarit : " .. tostring(why0); return end
  local inst, why = M.instantiate(g0, pl.k, ox, oy)
  if not inst then P.ok = false; P.fails[#P.fails + 1] = "instanciation : " .. tostring(why); return end
  local g = inst.gabarit
  P.w, P.h = g.w, g.h
  P.cx, P.cy = ox + g.w / 2, oy + g.h / 2
  local rep = M.analyze(g)
  P.nominal = g.nominal
  P.inputs = g.inputs
  P.power_kw = g.power_kw
  P.lanes_model = {}
  if P.contre then
    -- contre-épreuve : le contrôle refuse ; la sortie attendue est le flot maximal du modèle, objet par objet
    P.model_errors = #rep.errors
    P.expected = {}
    for _, fl in ipairs(rep.flows or {}) do if g.nominal[fl.item] then P.expected[fl.item] = fl.flow end end
  end
  -- 1. eau d'abord (F135), puis ressources
  if #inst.water > 0 then
    local tiles = {}
    for _, t in ipairs(inst.water) do tiles[#tiles + 1] = { name = "water", position = { t[1], t[2] } } end
    s.set_tiles(tiles)
  end
  for _, t in ipairs(M.resource_tiles(g)) do
    if t.well then
      s.create_entity({ name = "crude-oil", position = { ox + t[1], oy + t[2] }, amount = 300000 })
    else
      s.create_entity({ name = g.resource, position = { ox + t[1] + 0.5, oy + t[2] + 0.5 }, amount = 100000 })
    end
  end
  -- 2. entités du gabarit
  local ents = {}
  for j, e in ipairs(inst.entities) do
    local sp = M.spec(e.name)
    if sp.kind == "offshore" and not s.can_place_entity({ name = e.name, position = e.position, direction = e.direction, force = FORCE }) then
      P.fails[#P.fails + 1] = "pompe de rive : can_place_entity refuse " .. serpent.line(e.position)
    end
    local ent = s.create_entity({ name = e.name, position = e.position, direction = e.direction, force = FORCE,
      recipe = (sp.kind == "assembler") and e.recipe or nil })
    ents[j] = ent
    if not ent then
      P.fails[#P.fails + 1] = "création refusée : " .. e.name .. " en " .. serpent.line(e.position)
    else
      st.n_pos = st.n_pos + 1
      if math.abs(ent.position.x - e.position.x) > TOL or math.abs(ent.position.y - e.position.y) > TOL then
        st.pos_bad[#st.pos_bad + 1] = P.key .. " " .. e.name .. " modèle " .. serpent.line(e.position) .. " moteur " .. serpent.line(ent.position)
      end
      if sp.kind == "lab" then P.labs = true end
      if sp.kind == "generator" then P.engines[#P.engines + 1] = ent end
    end
  end
  P.ents = ents
  -- 3. recoupements : bras, foreuses
  for j, e in ipairs(g.entities) do
    local ent = ents[j]
    local sp = M.spec(e.name)
    if ent and sp.kind == "inserter" then
      st.n_ins = st.n_ins + 1
      local px, py = M.rot(e.dir, 0, -sp.reach)
      local dx, dy = M.rot(e.dir, 0, sp.reach + 0.2)
      local pp, dp = ent.pickup_position, ent.drop_position
      local want_p = { x = ox + e.x + px, y = oy + e.y + py }
      local want_d = { x = ox + e.x + dx, y = oy + e.y + dy }
      if dist(pp, want_p) > TOL or dist(dp, want_d) > TOL then
        st.ins_bad[#st.ins_bad + 1] = P.key .. " " .. e.name .. " n°" .. j .. " prise " .. serpent.line(pp) .. " (modèle " .. serpent.line(want_p)
          .. "), dépôt " .. serpent.line(dp) .. " (modèle " .. serpent.line(want_d) .. ")"
      end
    elseif ent and sp.kind == "drill" then
      st.n_drill = st.n_drill + 1
      local dx, dy = M.rot(e.dir, sp.drop[1], sp.drop[2])
      local want = { x = ox + e.x + dx, y = oy + e.y + dy }
      if math.floor(ent.drop_position.x) ~= math.floor(want.x) or math.floor(ent.drop_position.y) ~= math.floor(want.y) then
        st.ins_bad[#st.ins_bad + 1] = P.key .. " foreuse n°" .. j .. " dépôt " .. serpent.line(ent.drop_position) .. " (modèle " .. serpent.line(want) .. ")"
      end
    end
  end
  -- 4. fils (arbre du modèle)
  for _, w in ipairs(M.wires(g)) do
    local a, b = ents[w[1]], ents[w[2]]
    if a and b then a.connect_neighbour(b) end
  end
  -- 5. systèmes de fluides : même réseau du modèle ⇔ même identifiant du moteur
  -- indice moteur d'une boîte : celui dont un raccord vise un point de la boîte du modèle (le moteur n'expose pas
  -- toujours toutes les boîtes du prototype : raffinerie en traitement de base, 1er banc du 24/10)
  local function engine_index(ent, pts)
    for fi = 1, #ent.fluidbox do
      for _, pc in ipairs(ent.fluidbox.get_pipe_connections(fi)) do
        for _, p in ipairs(pts) do
          if math.abs(pc.target_position.x - (ox + p[1])) < 0.1 and math.abs(pc.target_position.y - (oy + p[2])) < 0.1 then return fi end
        end
      end
    end
    return nil
  end
  local by_net, ids = {}, {}
  for _, bx in ipairs(rep.boxes) do
    local ent = ents[bx.ent]
    if ent and not st.fb_logged[ent.name] and ent.fluidbox then
      st.fb_logged[ent.name] = true
      local mb = M.spec(ent.name).boxes
      ctx.log("boîtes à fluide du moteur : " .. ent.name .. (ent.get_recipe and ent.type == "assembling-machine" and ent.get_recipe() and (" (" .. ent.get_recipe().name .. ")") or "")
        .. " : " .. #ent.fluidbox .. " (prototype : " .. (mb and #mb or 1) .. ")")
    end
    local fi = ent and ent.fluidbox and engine_index(ent, bx.pts)
    if fi then
      local id = ent.fluidbox.get_fluid_system_id(fi)
      st.n_box = st.n_box + 1
      if id == nil then
        st.fluid_bad[#st.fluid_bad + 1] = P.key .. " " .. ent.name .. " boîte " .. bx.idx .. " : aucun système (modèle : raccordée)"
      else
        if by_net[bx.net] and by_net[bx.net] ~= id then
          st.fluid_bad[#st.fluid_bad + 1] = P.key .. " " .. ent.name .. " boîte " .. bx.idx .. " : système " .. id .. " ≠ " .. by_net[bx.net] .. " (même réseau au modèle)"
        end
        by_net[bx.net] = by_net[bx.net] or id
        if ids[id] and ids[id] ~= bx.net then
          st.fluid_bad[#st.fluid_bad + 1] = P.key .. " " .. ent.name .. " boîte " .. bx.idx .. " : système " .. id .. " partagé par deux réseaux du modèle"
        end
        ids[id] = ids[id] or bx.net
      end
    elseif ent then
      st.fluid_bad[#st.fluid_bad + 1] = P.key .. " " .. ent.name .. " : boîte " .. bx.idx .. " absente au moteur"
    end
  end
  -- 6. ports
  for pi, p in ipairs(g.ports) do
    local e, ent = g.entities[p.ent], ents[p.ent]
    if ent then
      if p.kind == "tapis" and p.io == "in" then
        P.src[#P.src + 1] = { ent = ent, lanes = { p.lanes[1], p.lanes[2] } }
      elseif p.kind == "tapis" and p.io == "out" then
        local sink_ent = ent
        if P.contre then
          -- contre-épreuve : 4 tuiles de tapis EN AVAL du port, comptage au bout (reprise de la correction IA1-c). Le
          -- 1er passage comptait sur la tuile du port elle-même, vidée à chaque tick : 8,7/s mesurés pour 7,5/s, car
          -- les bras qui déposent SUR cette tuile ne traversent aucune limite de voie. En jeu, la sortie continue en
          -- aval : c'est la limite d'une voie qui compte.
          local dv = { [defines.direction.north] = { 0, -1 }, [defines.direction.east] = { 1, 0 },
            [defines.direction.south] = { 0, 1 }, [defines.direction.west] = { -1, 0 } }
          local v = dv[ent.direction]
          for k = 1, 4 do
            local b = v and s.create_entity({ name = ent.name, position = { ent.position.x + v[1] * k, ent.position.y + v[2] * k },
              direction = ent.direction, force = FORCE })
            if b then sink_ent = b else P.fails[#P.fails + 1] = "tapis d'aval impossible au port " .. pi; break end
          end
        end
        P.sink[#P.sink + 1] = { ent = sink_ent, pi = pi }
        P.lanes_model[pi] = rep.lanes[pi]
      elseif p.kind == "tuyau" then
        -- raccord vers l'extérieur de l'emprise
        local q
        for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
          local x, y = e.x + d[1], e.y + d[2]
          if x < 0 or y < 0 or x > g.w or y > g.h then q = { x = ox + x, y = oy + y } end
        end
        local feeder = q and s.create_entity({ name = "pipe", position = q, force = FORCE })
        if not feeder then P.fails[#P.fails + 1] = "tuyau d'arène impossible au port " .. pi
        elseif p.io == "in" then P.fsrc[#P.fsrc + 1] = { ent = feeder, fluid = p.fluid }
        else P.fsink[#P.fsink + 1] = { ent = feeder, fluid = p.fluid } end
      elseif p.kind == "four" then
        P.furn[#P.furn + 1] = ent
      end
    end
  end
  for _, j in ipairs(g.fuel_ports or {}) do if ents[j] then P.fuel[#P.fuel + 1] = ents[j] end end
  for j, e in ipairs(g.entities) do
    if e.name == "burner-inserter" and ents[j] then ents[j].get_fuel_inventory().insert({ name = "coal", count = 2 }) end
  end
  -- 7. électricité : interface vanilla + poteau d'arène relié au poteau de raccordement
  if g.power_pole and ents[g.power_pole] then
    local pole = ents[g.power_pole]
    local best, bestd
    for x = ox - 4, ox + g.w + 3 do
      for y = oy - 4, oy + g.h + 3 do
        local inside = x >= ox - 1 and x < ox + g.w + 1 and y >= oy - 1 and y < oy + g.h + 1
        if not inside then
          local p = { x = x + 0.5, y = y + 0.5 }
          local d = dist(p, pole.position)
          if d <= 8.5 and (not bestd or d < bestd - 1e-9) and s.get_tile(x, y).name ~= "water" then best, bestd = p, d end
        end
      end
    end
    local ap = best and place_pole(s, best.x, best.y)
    if not ap then P.fails[#P.fails + 1] = "poteau d'arène impossible"
    else
      ap.connect_neighbour(pole)
      if #P.engines > 0 then
        -- charge : radars (300 kW chacun), 25 % au-dessus de la puissance nominale (15 pour 3,6 MW, 53 pour 12,6 MW),
        -- au sud de la case
        local nr = math.ceil((P.nominal["electricity-kw"] or 0) * 1.25 / 300)
        local cols = math.ceil(nr / 5)
        local rx, ry = sx + 8, sy + 36
        local last = chain(s, ap, { x = rx - 1, y = ry + 1 })
        local poles = { last }
        local placed = 0
        for c = 0, cols - 1 do
          for r = 0, 4 do
            if placed < nr and s.create_entity({ name = "radar", position = { rx + 4 * c + 1.5, ry + 4 * r + 1.5 }, force = FORCE }) then placed = placed + 1 end
          end
        end
        P.radars = placed
        ctx.log(string.format("centrale %s r%d : %d radars en charge (%.0f kW)", P.key, P.k, placed, placed * 300))
        for c = 0, cols - 1 do
          for r = 0, 4 do
            local pp = s.create_entity({ name = "medium-electric-pole", position = { rx + 4 * c + 3.5, ry + 4 * r + 3.5 }, force = FORCE })
            if pp then poles[#poles + 1] = pp end
          end
        end
        for a = 1, #poles do
          for b = a + 1, #poles do if dist(poles[a].position, poles[b].position) <= 9 then poles[a].connect_neighbour(poles[b]) end end
        end
      else
        -- interface 2 tuiles plus loin, dans l'axe qui s'éloigne du gabarit
        local vx, vy = ap.position.x - P.cx, ap.position.y - P.cy
        local tries = {}
        local px, py = ap.position.x, ap.position.y
        local sxv, syv = vx >= 0 and 1 or -1, vy >= 0 and 1 or -1
        if math.abs(vx) >= math.abs(vy) then
          tries = { { px + 0.5 + 2 * sxv, py + 0.5 }, { px + 0.5, py + 0.5 + 2 * syv }, { px + 0.5, py + 0.5 - 2 * syv } }
        else
          tries = { { px + 0.5, py + 0.5 + 2 * syv }, { px + 0.5 + 2 * sxv, py + 0.5 }, { px + 0.5 - 2 * sxv, py + 0.5 } }
        end
        local pos
        for _, t in ipairs(tries) do
          if not pos and s.can_place_entity({ name = "electric-energy-interface", position = { t[1], t[2] }, force = FORCE }) then pos = { t[1], t[2] } end
        end
        local eei = pos and s.create_entity({ name = "electric-energy-interface", position = pos, force = FORCE })
        if not eei then P.fails[#P.fails + 1] = "interface électrique impossible"
        else
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

local function r8_build(ctx, st)
  local s = ctx.surface()
  local y0 = Y0 + math.ceil(#st.P / COLS) * SLOT + 8
  st.r8 = {}
  for li, len in ipairs(R8_LENGTHS) do
    local y = y0 + 3 * (li - 1) + 0.5
    local first, last
    for x = 0, len + 1 do
      local p = s.create_entity({ name = "pipe", position = { X0 + x + 0.5, y }, force = FORCE })
      if x == 0 then first = p end
      last = p
    end
    -- longueur = tuyaux ENTRE la source (x = 0) et le puits (x = len + 1)
    st.r8[li] = { len = len, src = first, sink = last, n = 0 }
  end
end

local function tick_all(st, tick)
  for _, P in ipairs(st.P) do
    if P.ents then
      for _, sr in ipairs(P.src) do
        if sr.ent.valid then
          for l = 1, 2 do
            local it = sr.lanes[l]
            if it then
              local line = sr.ent.get_transport_line(l)
              if line.can_insert_at_back() and line.insert_at_back({ name = it, count = 1 }) then
                P.counts["in:" .. it] = (P.counts["in:" .. it] or 0) + 1
              end
            end
          end
        end
      end
      for _, sk in ipairs(P.sink) do
        if sk.ent.valid then
          for l = 1, 2 do
            local line = sk.ent.get_transport_line(l)
            local c = line.get_contents()
            for _, it in ipairs(sorted_keys(c)) do
              P.counts["out:" .. it] = (P.counts["out:" .. it] or 0) + c[it]
              local key = sk.pi .. ":" .. l .. ":" .. it
              P.lane_seen[key] = (P.lane_seen[key] or 0) + c[it]
            end
            line.clear()
          end
        end
      end
      for _, f in ipairs(P.fsrc) do
        if f.ent.valid then
          local cur = f.ent.fluidbox[1]
          local a = cur and cur.amount or 0
          P.counts["in:" .. f.fluid] = (P.counts["in:" .. f.fluid] or 0) + (100 - a)
          f.ent.fluidbox[1] = { name = f.fluid, amount = 100 }
        end
      end
      for _, f in ipairs(P.fsink) do
        if f.ent.valid then
          local cur = f.ent.fluidbox[1]
          if cur then
            P.counts["out:" .. cur.name] = (P.counts["out:" .. cur.name] or 0) + cur.amount
            f.ent.fluidbox[1] = nil
          end
        end
      end
      if P.eei and P.eei.valid then
        P.energy = P.energy + (BUF - P.eei.energy)
        P.eei.energy = BUF
      end
      for _, en in ipairs(P.engines) do if en.valid then P.gen = P.gen + en.energy_generated_last_tick end end
      if tick % 60 == 0 then
        for _, f in ipairs(P.furn) do
          if f.valid then
            local inv = f.get_output_inventory()
            local c = inv.get_contents()
            for _, it in ipairs(sorted_keys(c)) do P.counts["out:" .. it] = (P.counts["out:" .. it] or 0) + c[it] end
            inv.clear()
          end
        end
        for _, f in ipairs(P.fuel) do
          if f.valid then
            local inv = f.get_fuel_inventory()
            local have = inv.get_item_count("coal")
            if have < 5 then
              inv.insert({ name = "coal", count = 5 - have })
              P.counts["in:coal"] = (P.counts["in:coal"] or 0) + 5 - have
            end
          end
        end
      end
    end
  end
  if st.r8 then
    for _, r in ipairs(st.r8) do
      if r.src.valid and r.sink.valid then
        r.src.fluidbox[1] = { name = "water", amount = 100 }
        local cur = r.sink.fluidbox[1]
        if cur then r.n = r.n + cur.amount; r.sink.fluidbox[1] = nil end
      end
    end
  end
end

local function snapshot(st)
  for _, P in ipairs(st.P) do
    P.snap = {}
    for k, v in pairs(P.counts) do P.snap[k] = v end
    P.snap_energy, P.snap_gen = P.energy, P.gen
    P.snap_lanes = {}
    for k, v in pairs(P.lane_seen) do P.snap_lanes[k] = v end
  end
  for _, r in ipairs(st.r8 or {}) do r.snap = r.n end
end

return {
  description = "ia1-modules : chaque gabarit de module (shared/team/modules.lua) pose dans une arene, debit mesure sur 10 min apres 25 min de chauffe",
  base = nil,
  check_tick = CHECK,
  shots_delay = 2400,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    st.P, st.pos_bad, st.ins_bad, st.fluid_bad = {}, {}, {}, {}
    st.n_pos, st.n_ins, st.n_drill, st.n_box = 0, 0, 0, 0
    st.fb_logged = {}
    local force = game.forces[FORCE] or game.create_force(FORCE)
    force.set_cease_fire("enemy", true)
    game.forces.enemy.set_cease_fire(force, true)
    game.map_settings.pollution.enabled = false
    game.map_settings.enemy_expansion.enabled = false
    for _, r in ipairs(M.recipe_names()) do if force.recipes[r] then force.recipes[r].enabled = true end end
    local pls = placements()
    local rows = math.ceil(#pls / COLS)
    local maxlen = R8_LENGTHS[#R8_LENGTHS] + 2
    ctx.prepare_area(X0 - 16, Y0 - 16, X0 + math.max(COLS * SLOT, maxlen) + 16, Y0 + rows * SLOT + 3 * #R8_LENGTHS + 32, "grass-1")
    -- catalogue contrôlé hors jeu, rejoué ici sur la version chargée par le jeu ; puis chaque placement (variantes
    -- d'ère, extensions) ; la contre-épreuve doit être REFUSÉE
    local bad = {}
    for _, g in ipairs(M.catalogue()) do
      local errs = M.check(g)
      if #errs > 0 then bad[#bad + 1] = g.key .. " : " .. errs[1] end
    end
    ctx.check(#bad == 0, "catalogue sans erreur au contrôle du modèle (" .. #M.catalogue() .. " gabarits)", table.concat(bad, " | "))
    local pbad, n_era, n_ext, contre_refus = {}, 0, 0, {}
    local all_g = {}
    for _, pl in ipairs(pls) do
      local g, why = resolve(pl)
      if not g then pbad[#pbad + 1] = pl.key .. " : " .. tostring(why)
      else
        all_g[#all_g + 1] = g
        local errs = M.check(g)
        if pl.contre then contre_refus[#contre_refus + 1] = pl.key .. "@" .. pl.ext .. " : " .. (errs[1] or "ACCEPTÉ")
          if #errs == 0 then pbad[#pbad + 1] = pl.key .. "@" .. pl.ext .. " : contre-épreuve acceptée par le contrôle" end
        elseif #errs > 0 then pbad[#pbad + 1] = pl.key .. " : " .. errs[1] end
        if pl.ext and not pl.contre then n_ext = n_ext + 1 elseif not M.get(pl.key) and not pl.contre then n_era = n_era + 1 end
      end
    end
    ctx.check(#pbad == 0, "placements contrôlés : " .. n_era .. " variantes d'ère et " .. n_ext .. " extensions au maximum sans erreur, contre-épreuve refusée ("
      .. table.concat(contre_refus, " ; ") .. ")", table.concat(pbad, " | "))
    -- prototypes : emprise des bâtiments à niveaux et vitesses du modèle contre le jeu (tous les placements)
    local proto_bad = {}
    local seen = {}
    for _, g in ipairs(all_g) do
      for _, e in ipairs(g.entities) do
        if not seen[e.name] then
          seen[e.name] = true
          local p = game.entity_prototypes[e.name]
          local sp = M.spec(e.name)
          if not p then proto_bad[#proto_bad + 1] = e.name .. " absent"
          else
            local cb = p.collision_box
            local w = math.ceil(cb.right_bottom.x - cb.left_top.x - 0.01)
            local h = math.ceil(cb.right_bottom.y - cb.left_top.y - 0.01)
            if sp.kind ~= "offshore" and (w ~= sp.w or h ~= sp.h) then proto_bad[#proto_bad + 1] = e.name .. " " .. w .. "×" .. h .. " (modèle " .. sp.w .. "×" .. sp.h .. ")" end
            if sp.speed and p.crafting_speed and math.abs(p.crafting_speed - sp.speed) > 1e-6 then proto_bad[#proto_bad + 1] = e.name .. " vitesse " .. p.crafting_speed .. " (modèle " .. sp.speed .. ")" end
            if sp.speed and p.mining_speed and math.abs(p.mining_speed - sp.speed) > 1e-6 then proto_bad[#proto_bad + 1] = e.name .. " extraction " .. p.mining_speed .. " (modèle " .. sp.speed .. ")" end
            if sp.kind == "inserter" and p.inserter_rotation_speed and math.abs(p.inserter_rotation_speed - ({ ["burner-inserter"] = 0.01, inserter = 0.014, ["fast-inserter"] = 0.04, ["long-handed-inserter"] = 0.02 })[e.name]) > 1e-9 then
              proto_bad[#proto_bad + 1] = e.name .. " rotation " .. p.inserter_rotation_speed
            end
          end
        end
      end
    end
    for _, rn in ipairs(M.recipe_names()) do
      local r, mr = game.recipe_prototypes[rn], M.RECIPES[rn]
      if not r then proto_bad[#proto_bad + 1] = "recette " .. rn .. " absente"
      elseif math.abs(r.energy - mr.time) > 1e-9 then proto_bad[#proto_bad + 1] = "recette " .. rn .. " durée " .. r.energy .. " (modèle " .. mr.time .. ")" end
    end
    ctx.check(#proto_bad == 0, "prototypes et recettes du jeu conformes au modèle (emprises à niveaux comprises)", table.concat(proto_bad, " | "))
    for i, pl in ipairs(pls) do build(ctx, st, i, pl) end
    r8_build(ctx, st)
    st.tech = setup_research(ctx, force)
    ctx.check(st.tech ~= nil, "recherche des labos posée (packs rouges et verts, unité de " .. M.LAB_UNIT_TIME .. " s)", st.tech)
    local fails = {}
    for _, P in ipairs(st.P) do for _, f in ipairs(P.fails) do fails[#fails + 1] = P.key .. " r" .. P.k .. " : " .. f end end
    ctx.check(#fails == 0, "arène posée sans refus (" .. #st.P .. " placements)", table.concat(fails, " | "))
    ctx.check(#st.pos_bad == 0, "positions du moteur = positions du modèle (" .. st.n_pos .. " entités)", table.concat(st.pos_bad, " | "))
    ctx.check(#st.ins_bad == 0, "prise et dépôt des bras, dépôt des foreuses conformes au modèle (" .. st.n_ins .. " bras, " .. st.n_drill .. " foreuses)", table.concat(st.ins_bad, " | "))
    ctx.check(#st.fluid_bad == 0, "systèmes de fluides du moteur = réseaux du modèle (" .. st.n_box .. " boîtes)", table.concat(st.fluid_bad, " | "))
  end,

  tick = function(ctx, e)
    local st = ctx.state()
    if not st.P then return end
    tick_all(st, e.tick)
    if e.tick == WARM then snapshot(st) end
    if e.tick % 3600 == 0 then
      -- SUIVI : entrées de chaque placement, minute par minute (rapport au nominal du modèle)
      for _, P in ipairs(st.P) do
        if P.inputs and not P.contre then
          P.prev_min = P.prev_min or {}
          local parts = {}
          for _, it in ipairs(sorted_keys(P.inputs)) do
            local c = P.counts["in:" .. it] or 0
            local r = (c - (P.prev_min[it] or 0)) / 60
            P.prev_min[it] = c
            if P.inputs[it] > 0 then parts[#parts + 1] = string.format("%s=%.3f", it, r / P.inputs[it]) end
          end
          ctx.log(string.format("SUIVI\t%d\t%s\tr%d\t%s", math.floor(e.tick / 3600), P.key, P.k, table.concat(parts, " ")))
        end
      end
    end
    if e.tick == 600 then
      -- réseau électrique : chaque bâtiment électrique du gabarit raccordé, un seul réseau par gabarit
      local bad, n = {}, 0
      for _, P in ipairs(st.P) do
        local ids = {}
        for j, e2 in ipairs(M.instantiate(resolve(P), P.k, P.ox, P.oy).gabarit.entities) do
          local ent = P.ents and P.ents[j]
          local sp = M.spec(e2.name)
          if ent and ent.valid and (M.power_kw(e2.name) > 0 or sp.kind == "generator" or sp.kind == "pole") then
            n = n + 1
            if sp.kind ~= "pole" and not ent.is_connected_to_electric_network() then bad[#bad + 1] = P.key .. " " .. e2.name .. " n°" .. j .. " non raccordé" end
            if ent.electric_network_id then ids[ent.electric_network_id] = true end
          end
        end
        local k = sorted_keys(ids)
        if #k > 1 then bad[#bad + 1] = P.key .. " r" .. P.k .. " : " .. #k .. " réseaux électriques" end
      end
      ctx.check(#bad == 0, "réseau électrique : bâtiments raccordés par les poteaux du gabarit (" .. n .. ")", table.concat(bad, " | "))
    end
    if st.tech and e.tick % 60 == 0 then
      local force = game.forces[FORCE]
      if not force.current_research then
        st.tech_restarts = (st.tech_restarts or 0) + 1
        force.technologies[st.tech].researched = false
        force.add_research(st.tech)
      end
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local secs = (CHECK - WARM) / 60
    if (st.tech_restarts or 0) > 0 then ctx.log("labos : recherche relancée " .. st.tech_restarts .. " fois (achevée pendant le banc)") end
    local lane_bad = {}
    for _, P in ipairs(st.P) do
      if P.snap then
        local res, okall = {}, true
        local items = sorted_keys(P.nominal or {})
        for _, it in ipairs(items) do
          local nom = P.nominal[it]
          local got
          if it == "electricity-kw" then got = (P.gen - P.snap_gen) / (CHECK - WARM) * 60 / 1000
          else got = ((P.counts["out:" .. it] or 0) - (P.snap["out:" .. it] or 0)) / secs end
          local ratio = nom > 0 and got / nom or 0
          if P.contre then
            -- contre-épreuve : la sortie doit plafonner au flot maximal du modèle (une voie), bien sous le nominal
            local ex = P.expected[it] or nom
            local re = ex > 0 and got / ex or 0
            if re < 0.85 or re > 1.05 or got >= 0.9 * nom then okall = false end
            res[#res + 1] = string.format("%s %.4g mesuré, flot maximal du modèle %.4g (%.1f %%), nominal %.4g", it, got, ex, 100 * re, nom)
          else
            if ratio < 0.9 or ratio > 1.1 then okall = false end
            res[#res + 1] = string.format("%s %.4g/%.4g (%.1f %%)", it, got, nom, 100 * ratio)
          end
          ctx.log(string.format("MESURE\t%s\tr%d\tsortie\t%s\t%.6g\t%.6g\t%.4f", P.key, P.k, it, nom, got, ratio))
        end
        local ins = {}
        for _, it in ipairs(sorted_keys(P.inputs or {})) do
          local nom = P.inputs[it]
          local got = ((P.counts["in:" .. it] or 0) - (P.snap["in:" .. it] or 0)) / secs
          -- correction IA1-c (mineur 3) : entrées contrôlées à ±10 % (sauf la contre-épreuve, nourrie sous le nominal)
          local rin = nom > 0 and got / nom or 0
          if not P.contre and nom > 0 and (rin < 0.9 or rin > 1.1) then okall = false end
          ins[#ins + 1] = string.format("%s %.4g/%.4g (%.1f %%)", it, got, nom, 100 * rin)
          ctx.log(string.format("MESURE\t%s\tr%d\tentree\t%s\t%.6g\t%.6g\t%.4f", P.key, P.k, it, nom, got, nom > 0 and got / nom or 0))
        end
        if P.labs then
          -- labos : la sortie est la consommation de packs
          for _, it in ipairs(sorted_keys(P.inputs or {})) do
            local nom = P.inputs[it]
            local got = ((P.counts["in:" .. it] or 0) - (P.snap["in:" .. it] or 0)) / secs
            local ratio = got / nom
            if ratio < 0.9 or ratio > 1.1 then okall = false end
            res[#res + 1] = string.format("consommé %s %.4g/%.4g (%.1f %%)", it, got, nom, 100 * ratio)
          end
        end
        local what = P.contre and ("contre-épreuve " .. P.key .. " r" .. P.k .. " (refusée par le contrôle) : sortie plafonnée au flot maximal du modèle, pas au nominal")
          or ("débit " .. P.key .. " r" .. P.k .. " à ±10 % du nominal (sorties et entrées)")
        ctx.check(okall and #res > 0, what, table.concat(res, " ; ") .. " | entrées " .. table.concat(ins, " ; "))
        if P.eei then
          local kw = (P.energy - P.snap_energy) / (CHECK - WARM) * 60 / 1000
          ctx.log(string.format("MESURE\t%s\tr%d\tpuissance\tkW\t%.6g\t%.6g\t%.4f", P.key, P.k, P.power_kw, kw, kw / P.power_kw))
          ctx.check(kw > 0 and kw <= P.power_kw * 1.02, "puissance " .. P.key .. " r" .. P.k .. " mesurée sous la puissance déclarée",
            string.format("%.1f kW mesurés, %.1f kW déclarés", kw, P.power_kw))
        end
        -- voies des ports de sortie : objets vus voie par voie = voies du modèle
        for _, pi in ipairs(sorted_keys(P.lanes_model)) do
          local model = P.lanes_model[pi]
          for l = 1, 2 do
            local want = {}
            for _, it in ipairs(model[l] or {}) do want[it] = true end
            for _, it in ipairs(sorted_keys(want)) do
              if ((P.lane_seen[pi .. ":" .. l .. ":" .. it] or 0) - (P.snap_lanes[pi .. ":" .. l .. ":" .. it] or 0)) <= 0 then
                lane_bad[#lane_bad + 1] = P.key .. " r" .. P.k .. " port " .. pi .. " voie " .. l .. " : " .. it .. " attendu, absent"
              end
            end
          end
        end
        for _, k in ipairs(sorted_keys(P.lane_seen)) do
          local pi, l, it = k:match("^(%d+):(%d):(.+)$")
          local model = P.lanes_model[tonumber(pi)]
          local ok = false
          for _, x in ipairs((model and model[tonumber(l)]) or {}) do if x == it then ok = true end end
          if not ok and P.lane_seen[k] - (P.snap_lanes[k] or 0) > 0 then
            lane_bad[#lane_bad + 1] = P.key .. " r" .. P.k .. " port " .. pi .. " voie " .. l .. " : " .. it .. " inattendu"
          end
        end
      end
    end
    ctx.check(#lane_bad == 0, "voies des tapis de sortie conformes au modèle (gauche = 1, droite = 2)", table.concat(lane_bad, " | "))
    -- R8 : débit des conduites droites
    local r8 = {}
    local prev
    local mono = true
    for _, r in ipairs(st.r8 or {}) do
      local f = (r.n - (r.snap or 0)) / secs
      r8[#r8 + 1] = string.format("%d:%.0f", r.len, f)
      ctx.log(string.format("R8\t%d\t%.3f", r.len, f))
      if prev and f > prev * 1.02 then mono = false end
      prev = f
    end
    ctx.check(#r8 == #R8_LENGTHS and mono, "R8 : débit des conduites mesuré, décroissant avec la longueur (tuyaux : débit/s)", table.concat(r8, " "))
  end,

  shots = function(ctx, add)
    local st = ctx.state()
    for _, P in ipairs(st.P or {}) do
      if P.cx then
        local z = math.max(P.w, P.h) > 20 and 0.9 or 1.2
        add(P.key .. "-r" .. P.k, P.cx, P.cy, z, 0)
      end
    end
    -- gros plans
    for _, key in ipairs({ "circuits-verts", "packs-verts", "soufre-2", "centrale-vapeur-2", "centrale-vapeur-2@7", "plastique-2@6" }) do
      for _, P in ipairs(st.P or {}) do
        if P.key == key and P.k == 0 then add(key .. "-gros-plan", P.cx, P.cy, 2, 0) end
      end
    end
  end,
}
