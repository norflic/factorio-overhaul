--[[
  Lot CHAMP, côté RUNTIME (règle pure : shared/team/champ.lua ; contrôle : shared/team/champ_verif.lua). Retour du DC du 2/11 : « ça ne
  fait pas le comment mais dit OK, on met ce pattern là et puis on verra bien » ; « tout le champ on le remplace, on fout des rangées de
  foreuses électriques [...] des rangées de N fours justement en fonction du débit ».

  Deux services, lus par script/team/migration_champ.lua (la migration d'un avant-poste de paires thermiques, par BANDES) :
    - Champ.frame(f, surface, o) : plan ENTIER du gisement de l'avant-poste `o` (lu au moteur : tuiles du gisement, eau, bâtiments,
      tuiles réservées par d'autres projets ; caractéristiques lues aux prototypes) ; rend le cadre figé (axe, phase, sortie, bords,
      décalages des rangées), les bandes dans l'ordre de pose (celles qui portent des paires d'abord, puis la plus proche du QG) et le
      journal [FO-CHAMP] du plan (contrôle de shared/team/champ_verif.lua : couverture, courant, tapis, fonderie) ;
    - Champ.band(f, surface, o, frame, pr) : la bande `pr` seule, au même cadre (entités nommées, emprise, paires recouvertes).
  Et le planificateur du site « champ » du plan directeur (Build.SITES.champ, spec.champ = { oid, pr, frame }) : la bande devient un
  projet ordinaire (réserve au coffre, défrichage, fantômes, PNJ bâtisseurs, fils, coffres de combustible remplis, coffres de sortie
  vidés), raccordé au réseau par une chaîne de poteaux quand aucun poteau alimenté n'est à portée.
  Noms : T (foreuse électrique, réceptacle de l'avant-poste, combustible), D (bras, coffre, poteaux), convoyeurs débloqués (Conv).
  Déterminisme : listes triées, aucun `pairs` dans une décision ; rien dans global ici (le cadre est gardé par la migration).
]]

local T = require("shared.team.config")
local D = require("shared.team.petrole_donnees")
local P = require("shared.team.plan")
local Ch = require("shared.team.champ")
local Cv = require("shared.team.champ_verif")
local Db = require("shared.team.debit")
local Paires = require("shared.team.pose_paires")
local State = require("script.faction.state")
local Build = require("script.team.build")
local Conv = require("script.team.convoyeurs")

local Champ = {}

Champ.CFG = {
  radius = 96,      -- tuiles autour de l'avant-poste où le gisement est lu
  side = 8,         -- foreuses par côté et par groupe au plus (une bande coûte ce que sa fonderie coûte : la suivante l'agrandit)
  margin_v = 10,    -- tuiles lues en travers au-delà du gisement
  margin_u = 120,   -- tuiles lues le long de l'axe au-delà du gisement (fonderies)
  chain_r = 160,    -- tuiles : poteau alimenté le plus loin cherché pour raccorder une bande
  logs = 40,        -- lignes [FO-CHAMP] au plus par équipe
}

local function sorted_keys(t) return State.sorted_keys(t or {}) end

local function say(f, text)
  f.champ_logs = (f.champ_logs or 0) + 1
  if f.champ_logs > Champ.CFG.logs then return end
  log(string.format("[FO-CHAMP] %s : %s a %.1f min", f.key or "player", text, game.tick / 3600))
end
Champ.say = say

---------------------------------------------------------------------------------------------------
-- Lectures
---------------------------------------------------------------------------------------------------
local function enabled(f, item)
  local force = game.forces[f.force]
  local r = force and force.recipes[item]
  return r ~= nil and r.enabled == true
end

--- Caractéristiques lues aux prototypes, et les noms : (data, names) ou nil, raison.
function Champ.data(f, kind)
  local spec = T.outposts[kind]
  if not spec then return nil, "avant-poste inconnu" end
  local dp = game.entity_prototypes[T.DRILL_ELECTRIC]
  local rp = game.entity_prototypes[spec.resource]
  if not (dp and rp and dp.mining_drill_radius and rp.mineable_properties) then return nil, "foreuse ou minerai" end
  local size = dp.tile_width
  local reach = math.floor((2 * dp.mining_drill_radius - size) / 2 + 0.5)
  local force = game.forces[f.force]
  local prod = force and force.mining_drill_productivity_bonus or 0
  local rate = dp.mining_speed / (rp.mineable_properties.mining_time or 1) * (1 + prod)
  local pole
  for _, n in ipairs(D.POLES) do
    local pp = game.entity_prototypes[n]
    if pp and not pole and enabled(f, n) then pole = { name = n, proto = pp } end
  end
  if not pole then
    local n = D.POLES[#D.POLES]
    pole = { name = n, proto = game.entity_prototypes[n] }
  end
  if not pole.proto then return nil, "poteau" end
  local usable = Conv.usable(f)
  local belts, bnames = {}, {}
  for _, bt in ipairs(Conv.belts()) do
    if usable(bt.name) then belts[#belts + 1] = { lane = Db.lane_capacity(bt.speed) }; bnames[#bnames + 1] = bt.name end
  end
  if #belts == 0 then return nil, "tapis" end
  local data = {
    drill = { size = size, reach = reach, rate = rate },
    pole = { reach = math.floor(pole.proto.supply_area_distance - 0.5 + 1e-6), wire = pole.proto.max_wire_distance },
    belts = belts,
  }
  local names = { drill = T.DRILL_ELECTRIC, pole = pole.name, belts = bnames, arm = D.ARM, chest = D.CHEST, fuel = T.fuel }
  local fp = game.entity_prototypes[spec.sink]
  if fp and fp.type == "furnace" then
    local rec = game.recipe_prototypes[spec.product]
    local per = 1
    for _, ing in ipairs(rec and rec.ingredients or {}) do if ing.name == spec.resource then per = ing.amount end end
    if not (rec and rec.energy and rec.energy > 0) then return nil, "recette du four" end
    data.furnace = { size = fp.tile_width, rate = (fp.crafting_speed or 1) * per / rec.energy, fuel = fp.burner_prototype ~= nil }
    names.furnace = spec.sink
  end
  local ap = game.entity_prototypes[D.ARM]
  data.inserter = { rate = ap and ap.inserter_rotation_speed and ap.inserter_rotation_speed * 60 or 0.83 }
  -- emprises des pièces pour le plan directeur (P.tiles_of) : lues aux prototypes
  for _, n in ipairs({ names.drill, names.pole, names.arm, names.chest, names.furnace or names.drill }) do
    local pp = game.entity_prototypes[n]
    if pp then P.declare_size(n, pp.tile_width, pp.tile_height) end
  end
  return data, names
end

--- Tuiles (liste plate) du gisement de l'avant-poste : composante connexe des tuiles de minerai autour de son centre.
local function ore_tiles(surface, o)
  local res = T.outposts[o.kind].resource
  local raw = {}
  for _, r in ipairs(surface.find_entities_filtered({ position = o.pos, radius = Champ.CFG.radius, name = res })) do
    if r.valid then raw[#raw + 1] = { x = r.position.x, y = r.position.y } end
  end
  local comp = Paires.component(Paires.sorted(raw, o.pos), Paires.GAP, o.pos)
  local out = {}
  for _, t in ipairs(comp) do out[#out + 1] = math.floor(t.x); out[#out + 1] = math.floor(t.y) end
  return out
end

local function add_box(set, e)
  local bb = e.bounding_box
  for x = math.floor(bb.left_top.x + 0.01), math.ceil(bb.right_bottom.x - 0.01) - 1 do
    for y = math.floor(bb.left_top.y + 0.01), math.ceil(bb.right_bottom.y - 0.01) - 1 do set[Ch.key(x, y)] = true end
  end
end

--- Tuiles NÔTRES (libres pour le plan) : paires de l'avant-poste et entités des bandes déjà demandées pour lui.
local function mine_of(f, o)
  local mine = {}
  for _, l in ipairs({ o.drill_list or {}, o.sinks or {} }) do
    for _, e in ipairs(l) do if e.valid then add_box(mine, e) end end
  end
  local b = f.build
  for _, pid in ipairs(b and b.order or {}) do
    local p = b.projects[pid]
    if p and p.spec and p.spec.champ and p.spec.champ.oid == o.id then
      for _, e in ipairs(p.ents) do for _, t in ipairs(P.tiles_of(e)) do mine[Ch.key(t[1], t[2])] = true end end
    end
  end
  return mine
end

--- Tuiles où rien ne se pose dans le rectangle : eau, bâtiments (arbres et rochers exceptés : défrichés), tuiles réservées par un
--- autre projet du plan directeur ; les tuiles `mine` restent libres.
local function blocked_in(f, surface, x0, y0, x1, y1, mine)
  local blocked = {}
  for _, t in ipairs(surface.find_tiles_filtered({ area = { { x0, y0 }, { x1, y1 } }, collision_mask = "water-tile" })) do
    blocked[Ch.key(math.floor(t.position.x), math.floor(t.position.y))] = true
  end
  for _, e in ipairs(surface.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, collision_mask = "object-layer" })) do
    local soft = e.type == "tree" or e.type == "simple-entity" or (e.force.name == "neutral" and e.type ~= "cliff")
    if not soft and e.type ~= "resource" then add_box(blocked, e) end
  end
  local occ = f.build and f.build.occ or {}
  for x = math.floor(x0), math.ceil(x1) do
    for y = math.floor(y0), math.ceil(y1) do
      if occ[P.tkey(x, y)] then blocked[Ch.key(x, y)] = true end
    end
  end
  return blocked
end

--- Spec de la règle pure pour l'avant-poste `o` : (spec, names) ou nil, raison.
local function spec_of(f, surface, o, frame, only)
  local data, names = Champ.data(f, o.kind)
  if not data then return nil, names end
  local ore = ore_tiles(surface, o)
  if #ore < 2 then return nil, "gisement epuise" end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for i = 1, #ore - 1, 2 do
    x0, x1 = math.min(x0, ore[i]), math.max(x1, ore[i])
    y0, y1 = math.min(y0, ore[i + 1]), math.max(y1, ore[i + 1])
  end
  local axis = frame and frame.axis or ((y1 - y0 > x1 - x0) and "y" or "x")
  local mu, mv = Champ.CFG.margin_u, Champ.CFG.margin_v
  if axis == "x" then x0, x1, y0, y1 = x0 - mu, x1 + mu, y0 - mv, y1 + mv else x0, x1, y0, y1 = x0 - mv, x1 + mv, y0 - mu, y1 + mu end
  local mine = mine_of(f, o)
  local spec = {
    ore = ore, blocked = blocked_in(f, surface, x0, y0, x1, y1, mine), mine = mine,
    drill = data.drill, pole = data.pole, belts = data.belts, furnace = data.furnace, inserter = data.inserter,
    target = f.hq_pos, max_side = Champ.CFG.side,
  }
  if frame then
    local fr = {}
    for _, k in ipairs(sorted_keys(frame)) do fr[k] = frame[k] end
    fr.only = only
    spec.frame = fr
  end
  return spec, names
end

---------------------------------------------------------------------------------------------------
-- Plans
---------------------------------------------------------------------------------------------------
--- Plan entier : (cadre, ordre des bandes { pr }, plan) ou nil, raison. Journal : une ligne [FO-CHAMP] par plan.
function Champ.frame(f, surface, o)
  local spec, names = spec_of(f, surface, o, nil, nil)
  if not spec then return nil, names end
  local plan, why = Ch.plan(spec)
  if not plan then return nil, why end
  local rep = Cv.verify(plan, spec)
  -- ordre : bandes qui portent des paires de l'avant-poste (le plus de paires d'abord), puis la plus proche du QG en travers
  local hv = (plan.axis == "x") and f.hq_pos.y or f.hq_pos.x
  local pairs_in = {}
  for _, d in ipairs(o.drill_list or {}) do
    if d.valid then
      local v = (plan.axis == "x") and d.position.y or d.position.x
      for _, bd in ipairs(plan.bands) do
        if v >= bd.pr and v < bd.pr + plan.pitch then pairs_in[bd.pr] = (pairs_in[bd.pr] or 0) + 1 end
      end
    end
  end
  local order = {}
  for _, bd in ipairs(plan.bands) do if #bd.groups > 0 then order[#order + 1] = { pr = bd.pr, n = pairs_in[bd.pr] or 0, d = math.abs(bd.b - hv) } end end
  table.sort(order, function(a, b)
    if (a.n > 0) ~= (b.n > 0) then return a.n > 0 end
    if a.n ~= b.n then return a.n > b.n end
    if a.d ~= b.d then return a.d < b.d end
    return a.pr < b.pr
  end)
  local prs, with = {}, 0
  for _, it in ipairs(order) do prs[#prs + 1] = it.pr; if it.n > 0 then with = with + 1 end end
  say(f, string.format("avant-poste %d (%s) : plan du champ, %d bande(s) (%d avec des paires), axe %s, sortie %s ; %d foreuses, %d fours, %d poteaux, %d tapis ; %s",
    o.id, o.kind, #prs, with, plan.axis, plan.exit > 0 and "+" or "-", plan.stats.drills, plan.stats.furnaces,
    plan.stats.poles, plan.stats.belts, Cv.line(rep)))
  return plan.frame, prs, plan
end

--- Entités nommées d'un plan (bande seule) : ents { name, x, y, dir, role }, quais, outs, emprise { tuiles }.
local function named(plan, names)
  local ents, quais, outs = {}, {}, {}
  for _, e in ipairs(plan.ents) do
    local name
    if e.kind == "foreuse" then name = names.drill
    elseif e.kind == "tapis" then name = names.belts[e.belt or 1]
    elseif e.kind == "poteau" then name = names.pole
    elseif e.kind == "four" then name = names.furnace
    elseif e.kind == "bras" then name = names.arm
    elseif e.kind == "coffre" then name = names.chest end
    if name then
      local role = (e.kind == "coffre" and e.role == "sortie") and "sortie" or ("champ-" .. e.kind)
      ents[#ents + 1] = { name = name, x = e.x, y = e.y, dir = e.dir, role = role }
      if e.kind == "coffre" and e.role == "combustible" then quais[#quais + 1] = { x = e.x, y = e.y, item = names.fuel } end
      if e.kind == "coffre" and e.role == "sortie" then outs[#outs + 1] = { x = e.x, y = e.y } end
    end
  end
  return ents, quais, outs
end

--- La bande `pr` seule : { ents, quais, outs, tiles (liste plate de son emprise), plan } ou nil, raison.
function Champ.band(f, surface, o, frame, pr)
  local spec, names = spec_of(f, surface, o, frame, { [pr] = true })
  if not spec then return nil, names end
  local plan, why = Ch.plan(spec)
  if not plan then return nil, why end
  if #plan.ents == 0 then return nil, "bande vide" end
  local ents, quais, outs = named(plan, names)
  local tiles = {}
  for _, e in ipairs(ents) do for _, t in ipairs(P.tiles_of(e)) do tiles[#tiles + 1] = t[1]; tiles[#tiles + 1] = t[2] end end
  return { ents = ents, quais = quais, outs = outs, tiles = tiles, plan = plan, names = names, spec = spec }
end

---------------------------------------------------------------------------------------------------
-- Site « champ » du plan directeur
---------------------------------------------------------------------------------------------------
--- Poteau alimenté le plus proche (réseau d'une génératrice de l'équipe), ou nil.
local function powered_pole(f, surface, x, y)
  local powered = {}
  for _, g in ipairs(surface.find_entities_filtered({ type = "generator", force = f.force })) do
    if g.electric_network_id then powered[g.electric_network_id] = true end
  end
  local best, bd
  for _, e in ipairs(surface.find_entities_filtered({ position = { x, y }, radius = Champ.CFG.chain_r, type = "electric-pole", force = f.force })) do
    if e.electric_network_id and powered[e.electric_network_id] then
      local d = (e.position.x - x) ^ 2 + (e.position.y - y) ^ 2
      if not bd or d < bd or (d == bd and (e.position.x < best.x or (e.position.x == best.x and e.position.y < best.y))) then
        best, bd = { x = e.position.x, y = e.position.y }, d
      end
    end
  end
  return best
end

Build.SITES = Build.SITES or {}
Build.SITES.champ = function(f, surface, p, h)
  local cs = p.spec.champ
  local o = cs and f.outposts and f.outposts[cs.oid]
  if not o then return nil, "champ: avant-poste perdu" end
  local bd, why = Champ.band(f, surface, o, cs.frame, cs.pr)
  if not bd then return nil, "champ: " .. tostring(why) end
  local b = f.build
  -- poteaux d'une bande voisine déjà demandée (rangée partagée, même place sur le treillis) : déjà au plan, pas deux fois
  local ents = {}
  local dropped = 0
  for _, e in ipairs(bd.ents) do
    local taken = false
    for _, t in ipairs(P.tiles_of(e)) do
      local q = b.occ[P.tkey(t[1], t[2])]
      if q and q ~= p.id then taken = true end
    end
    if taken then dropped = dropped + 1 else ents[#ents + 1] = e end
  end
  -- raccord au réseau : un poteau alimenté à portée d'un poteau de la bande, sinon une chaîne de poteaux
  local poles = {}
  for _, e in ipairs(ents) do if e.name == bd.names.pole then poles[#poles + 1] = e end end
  local wire = bd.spec.pole.wire
  local cx, cy = 0, 0
  for _, e in ipairs(poles) do cx, cy = cx + e.x, cy + e.y end
  if #poles > 0 then cx, cy = cx / #poles, cy / #poles end
  local net = powered_pole(f, surface, cx, cy)
  local chain_n = 0
  if net then
    local start, sd
    for _, e in ipairs(poles) do
      local d = (e.x - net.x) ^ 2 + (e.y - net.y) ^ 2
      if not sd or d < sd then start, sd = e, d end
    end
    if start and sd > wire * wire then
      local x0, y0 = math.floor(math.min(start.x, net.x)) - 8, math.floor(math.min(start.y, net.y)) - 8
      local x1, y1 = math.ceil(math.max(start.x, net.x)) + 8, math.ceil(math.max(start.y, net.y)) + 8
      local blocked = blocked_in(f, surface, x0, y0, x1, y1, bd.spec.mine)
      local used = {}
      for _, e in ipairs(ents) do for _, t in ipairs(P.tiles_of(e)) do used[Ch.key(t[1], t[2])] = true end end
      local function free(x, y)
        local k = Ch.key(math.floor(x), math.floor(y))
        return not blocked[k] and not used[k]
      end
      local chain = P.pole_chain({ x = start.x, y = start.y }, net, wire, false, free, nil)
      if not chain then return nil, "champ: aucune chaine de poteaux jusqu'au reseau" end
      for _, c in ipairs(chain) do ents[#ents + 1] = { name = bd.names.pole, x = c.x, y = c.y, dir = 0, role = "liaison" }; chain_n = chain_n + 1 end
    end
  end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, e in ipairs(ents) do
    x0, y0 = math.min(x0, math.floor(e.x)), math.min(y0, math.floor(e.y))
    x1, y1 = math.max(x1, math.floor(e.x)), math.max(y1, math.floor(e.y))
  end
  local masks = h.read_masks(x0 - 2, y0 - 2, x1 + 3, y1 + 3)
  local nd, nf = 0, 0
  for _, e in ipairs(ents) do
    if e.name == bd.names.drill then nd = nd + 1 elseif e.name == bd.names.furnace then nf = nf + 1 end
  end
  say(f, string.format("projet %d : bande %d du champ de l'avant-poste %d (%s) : %d foreuses, %d fours, %d entites (%d deja au plan), raccord %s",
    p.id, cs.pr, o.id, o.kind, nd, nf, #ents, dropped, net and (chain_n > 0 and (chain_n .. " poteau(x)") or "a portee") or "aucun reseau alimente vu"))
  return { key = "champ:" .. o.id .. ":" .. cs.pr, box = { x0, y0, x1, y1 }, ents = ents, quais = bd.quais, outs = bd.outs, masks = masks }
end

return Champ
