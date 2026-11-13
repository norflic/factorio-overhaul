--[[
  REROUTAGE (lot s42 reroutage, chantier 4.4 du DC) : exécutant de la règle pure shared/team/reroutage.lua, « construire d'abord,
  couper ensuite ». Un tapis de l'équipe qui TRAVERSE un gisement que le champ veut paver est contourné par l'extérieur :
    1. Rer.note (appelé par le plan du champ, script/team/champ.lua, spec_of) : relève les tapis de l'équipe posés sur le gisement,
       classe les tronçons (Rr.runs), trace le contournement du premier tronçon traversant (Rr.plan, preuve Rr.verify) et l'inscrit ;
    2. Rer.pulse (toutes les Rer.EVERY ticks) : lit le monde, fait un pas de l'automate (Rr.step) et exécute son action :
         poser   : tapis du contournement, payés au stock de l'équipe, seulement si le stock couvre TOUT ce qui manque ;
         couper  : ROTATION du tapis d'amont vers le contournement (aucune destruction : le flux bascule d'un coup) ;
         retirer : l'ancienne ligne, une fois VIDE, est retirée, ses tapis rendus au stock, ses pièces cédées au plan
                   (Build.cede_piece : ni le relevé de reconstruction ni le réseau vivant ne les reposent, le minerai redevient planifiable).
  Gardes : un tronçon alimenté par une machine (collecteur), lu par un bras, embranché, sans amont ou sans aval, avec une pièce
  souterraine ou un répartiteur, ou posé par un joueur (last_user) n'est JAMAIS touché ; un tronçon traité une fois ne l'est plus
  (f.reroutage.done) : aucune boucle pose / retrait possible ; un seul tronçon à la fois par équipe.
  Aucun nom d'objet : types de prototype, tapis lus sur l'amont. État (nombres, chaînes, tables) : f.reroutage = { run, done, logs }.
  Journal : « [FO-REROUTAGE] ».
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local Stock = require("script.team.stock")
local P = require("shared.team.plan")
local Ch = require("shared.team.champ")
local Tv = require("shared.team.traversee")
local Rr = require("shared.team.reroutage")

local Rer = {}

Rer.ENABLED = true
Rer.EVERY = 120                 -- ticks entre deux pas de l'automate (toutes équipes)
Rer.NOTE_GAP = 1800             -- ticks au moins entre deux relevés d'une même équipe (le plan du champ est relu souvent)
Rer.LOGS = 60                   -- lignes au plus par équipe
Rer.REPLANS = 2                 -- tracés refaits au plus quand une tuile du contournement est prise avant la pose
Rer.BELT, Rer.DRILL, Rer.ARM = "transport-belt", "mining-drill", "inserter" -- TYPES de prototype (aucun nom d'objet)
Rer.LINES = { "underground-belt", "splitter" }
Rer.Build = nil                 -- posé par script/team/champ.lua (Build.cede_piece), sans require circulaire

function Rer.set_enabled(on) Rer.ENABLED = on and true or false end

local function say(f, text)
  local st = f.reroutage
  st.logs = (st.logs or 0) + 1
  if st.logs > Rer.LOGS then return end
  log(string.format("[FO-REROUTAGE] %s : %s a %.1f min", f.key or tostring(f.id), text, game.tick / 3600))
end

local function state_of(f)
  local st = f.reroutage
  if not st then st = { done = {}, logs = 0 }; f.reroutage = st end
  return st
end

local TYPE_OF = {}
local function type_of(name)
  local t = TYPE_OF[name]
  if t == nil then
    local pr = game.entity_prototypes[name]
    t = pr and pr.type or false
    TYPE_OF[name] = t
  end
  return t
end

local function belt_at(surface, f, x, y)
  local e = surface.find_entities_filtered({ position = { x + 0.5, y + 0.5 }, type = Rer.BELT, force = f.force, limit = 1 })[1]
  if e and e.valid then return e end
  return nil
end

local function items_on(e)
  local n = 0
  for i = 1, e.get_max_transport_line_index() do n = n + #e.get_transport_line(i) end
  return n
end

--- Tapis de l'équipe dans le rectangle (tuiles), avec ce qui les alimente ou les lit (foreuses, bras).
local function read_belts(f, surface, x0, y0, x1, y1)
  local area = { { x0, y0 }, { x1 + 1, y1 + 1 } }
  local belts, at = {}, {}
  for _, e in ipairs(surface.find_entities_filtered({ area = area, type = Rer.BELT, force = f.force })) do
    local b = { x = math.floor(e.position.x), y = math.floor(e.position.y), dir = e.direction, plain = true, human = e.last_user ~= nil,
      name = e.name }
    belts[#belts + 1] = b
    at[Rr.key(b.x, b.y)] = b
  end
  for _, e in ipairs(surface.find_entities_filtered({ area = area, type = Rer.LINES, force = f.force })) do
    local bb = e.bounding_box
    for x = math.floor(bb.left_top.x + 0.05), math.floor(bb.right_bottom.x - 0.05) do
      for y = math.floor(bb.left_top.y + 0.05), math.floor(bb.right_bottom.y - 0.05) do
        if not at[Rr.key(x, y)] then
          local b = { x = x, y = y, dir = e.direction, plain = false, name = e.name }
          belts[#belts + 1] = b
          at[Rr.key(x, y)] = b
        end
      end
    end
  end
  local wide = { { x0 - 3, y0 - 3 }, { x1 + 4, y1 + 4 } }
  for _, e in ipairs(surface.find_entities_filtered({ area = wide, type = { Rer.DRILL, Rer.ARM } })) do
    local d = e.drop_position
    local b = d and at[Rr.key(math.floor(d.x), math.floor(d.y))]
    if b then b.fed = true end
    if e.type == Rer.ARM then
      local pk = e.pickup_position
      b = pk and at[Rr.key(math.floor(pk.x), math.floor(pk.y))]
      if b then b.fed = true end -- un bras qui LIT le tapis : la ligne sert, elle reste
    end
  end
  table.sort(belts, function(a, b) return Rr.key(a.x, a.y) < Rr.key(b.x, b.y) end)
  return belts
end

local function make_ctx(f, surface, belts, ore_set, blocked, win)
  local proto = nil
  return function(belt_name, bounds)
    proto = belt_name
    return { map = Rr.index(belts), avoid = ore_set, bounds = bounds,
      free = function(x, y)
        if blocked and blocked[Ch.key(x, y)] then return false end
        if x < win[1] or y < win[2] or x > win[3] or y > win[4] then return false end
        return surface.can_place_entity({ name = proto, position = { x + 0.5, y + 0.5 }, force = f.force })
      end }
  end
end

--- Relevé au plan du champ. `ore` : liste plate { x1, y1, x2, y2... } du gisement ; `blocked` : tuiles occupées (clé Ch.key -> motif ou nom
--- d'entité) ; `mine` : tuiles des pièces du champ lui-même ; `win` = { x0, y0, x1, y1 } rectangle lu. Inscrit au plus un tronçon.
function Rer.note(f, surface, o, ore, blocked, mine, win)
  if not (Rer.ENABLED and f and f.hq and f.hq.valid and f.build) then return end
  local st = state_of(f)
  local tick = game.tick
  win = { math.floor(win[1]), math.floor(win[2]), math.ceil(win[3]), math.ceil(win[4]) }
  if st.run or tick < (st.next_note or 0) then return end
  -- pré-tri sans appel au moteur : une tuile du gisement tenue par un tapis, hors des pièces du champ
  local hit = false
  for i = 1, #ore - 1, 2 do
    local k = Ch.key(ore[i], ore[i + 1])
    local w = blocked[k]
    if w and not mine[k] and type_of(tostring(w)) == Rer.BELT then hit = true; break end
  end
  if not hit then return end
  st.next_note = tick + Rer.NOTE_GAP
  local ore_set, zone = {}, {}
  for i = 1, #ore - 1, 2 do ore_set[Rr.key(ore[i], ore[i + 1])] = true end
  local belts = read_belts(f, surface, win[1], win[2], win[3], win[4])
  for _, b in ipairs(belts) do
    local k = Rr.key(b.x, b.y)
    if ore_set[k] and not mine[Ch.key(b.x, b.y)] then zone[k] = true end
  end
  local ctx_of = make_ctx(f, surface, belts, ore_set, blocked, win)
  local counts, kinds = {}, {}
  for _, run in ipairs(Rr.runs(belts, zone)) do
    local why = run.kind
    local pk = run.p and Rr.key(run.p.x, run.p.y) or nil
    if why == "traversant" and st.done[tostring(pk)] then why = "deja traite" end
    if why == "traversant" then
      local x0, y0, x1, y1 = run.p.x, run.p.y, run.p.x, run.p.y
      for _, z in ipairs(run.old) do x0, y0, x1, y1 = math.min(x0, z.x), math.min(y0, z.y), math.max(x1, z.x), math.max(y1, z.y) end
      x0, y0, x1, y1 = math.min(x0, run.q.x), math.min(y0, run.q.y), math.max(x1, run.q.x), math.max(y1, run.q.y)
      local m = Tv.DETOUR_MAX -- la même marge que le détour d'un tracé neuf (shared/team/traversee.lua)
      local plan, pwhy = Rr.plan(run, ctx_of(run.p.name, { x0 - m, y0 - m, x1 + m, y1 + m }))
      local ok, vwhy = false, nil
      if plan then ok, vwhy = Rr.verify(run, plan, ore_set) end
      if plan and ok and not st.run then
        local pr = game.entity_prototypes[run.p.name]
        local item = pr and pr.items_to_place_this and pr.items_to_place_this[1] and pr.items_to_place_this[1].name
        if item then
          local old = {}
          for _, z in ipairs(run.old) do old[#old + 1] = { x = z.x, y = z.y, dir = z.dir } end
          st.run = { state = Rr.A_CONTOURNER, key = tostring(pk), oid = o and o.id, belt = run.p.name, item = item,
            p = { x = run.p.x, y = run.p.y }, q = { x = run.q.x, y = run.q.y, dir = run.q.dir }, cut = plan.cut,
            tiles = plan.tiles, old = old, t0 = tick, replans = 0, win = { win[1], win[2], win[3], win[4] } }
          say(f, string.format("avant-poste %s : tapis traversant le gisement de (%d, %d) a (%d, %d), %d tuile(s) sur le minerai ; contournement exterieur de %d tapis trace, stock %d ; etat %s",
            tostring(o and o.id), run.p.x, run.p.y, run.q.x, run.q.y, #old, #plan.tiles, Stock.count(f, item), Rr.A_CONTOURNER))
          why = "inscrit"
        else
          why = "aucun objet pour le tapis"
        end
      elseif not (plan and ok) then
        why = "refus : " .. tostring(pwhy or vwhy)
      else
        why = "en attente (un troncon a la fois)"
      end
    end
    if not counts[why] then counts[why] = 0; kinds[#kinds + 1] = why end
    counts[why] = counts[why] + 1
  end
  table.sort(kinds)
  local parts = {}
  for _, k in ipairs(kinds) do parts[#parts + 1] = k .. " " .. counts[k] end
  say(f, string.format("avant-poste %s : releve des tapis sur le gisement : %s", tostring(o and o.id), #parts > 0 and table.concat(parts, ", ") or "aucun troncon"))
end

--- Pièce du plan directeur posée sur la tuile (détenteur b.occ, même position, non cédée), ou nil.
local function piece_at(f, x, y, name)
  local b = f.build
  local q = b and b.occ and b.projects and b.projects[b.occ[P.tkey(x, y)] or false] or nil
  for _, pe in ipairs(q and q.ents or {}) do
    if not pe.dropped and pe.name == name and pe.x == x + 0.5 and pe.y == y + 0.5 then return q, pe end
  end
  return nil
end

local function finish(f, run, why)
  local st = f.reroutage
  st.done[run.key] = true
  st.run = nil
  say(f, string.format("avant-poste %s : troncon de (%d, %d) : %s apres %.1f min", tostring(run.oid), run.p.x, run.p.y, why, (game.tick - run.t0) / 3600))
end

--- Retire les tuiles du contournement posées par ce lot, jamais alimentées (avant la coupe seulement), et les rend au stock.
local function undo(f, surface, run)
  local n = 0
  for _, t in ipairs(run.tiles) do
    local e = t.mine and belt_at(surface, f, t.x, t.y)
    if e and e.direction == t.dir and items_on(e) == 0 then
      e.destroy()
      Stock.insert(f, run.item, 1)
      n = n + 1
    end
  end
  return n
end

local function step_run(f, surface, run)
  local pe, qe = belt_at(surface, f, run.p.x, run.p.y), belt_at(surface, f, run.q.x, run.q.y)
  local posed, missing = 0, {}
  for _, t in ipairs(run.tiles) do
    local e = belt_at(surface, f, t.x, t.y)
    if e and e.direction == t.dir then posed = posed + 1 else missing[#missing + 1] = t end
  end
  local old, old_items = {}, 0
  for _, z in ipairs(run.old) do
    local e = belt_at(surface, f, z.x, z.y)
    if e and e.direction == z.dir then old[#old + 1] = e; old_items = old_items + items_on(e) end
  end
  local facts = { total = #run.tiles, posed = posed, stock = Stock.count(f, run.item), p_ok = pe ~= nil,
    q_ok = qe ~= nil and qe.direction == run.q.dir, p_cut = pe ~= nil and pe.direction == run.cut, old_left = #old, old_items = old_items }
  local before = run.state
  local nxt, act = Rr.step(run.state, facts)
  run.state = nxt
  if nxt ~= before then
    say(f, string.format("avant-poste %s : troncon de (%d, %d) : %s -> %s (contournement %d/%d, ancienne ligne %d tuile(s), %d objet(s) dessus)",
      tostring(run.oid), run.p.x, run.p.y, before, nxt, posed, #run.tiles, #old, old_items))
  end
  if nxt == Rr.RACCORDE then return finish(f, run, "RACCORDE, gisement libre") end
  if nxt == Rr.ABANDONNE then
    local back = before ~= Rr.COUPE and undo(f, surface, run) or 0
    return finish(f, run, string.format("ABANDONNE (%s), %d tapis du contournement repris", tostring(act and act.why or "?"), back))
  end
  if not act then return end
  if act.kind == "attendre" then
    if run.wait ~= act.why then
      run.wait = act.why
      say(f, string.format("avant-poste %s : troncon de (%d, %d) : attente (%s) : %d tapis manquant(s), stock %d", tostring(run.oid), run.p.x, run.p.y,
        act.why, #missing, facts.stock))
    end
  elseif act.kind == "poser" then
    -- tout ou rien : chaque tuile manquante doit pouvoir recevoir son tapis, sinon rien ne se pose
    for _, t in ipairs(missing) do
      if not surface.can_place_entity({ name = run.belt, position = { t.x + 0.5, t.y + 0.5 }, direction = t.dir, force = f.force }) then
        if before == Rr.COUPE then return end -- flux déjà basculé : on attend que la tuile se libère
        local back = undo(f, surface, run)
        return finish(f, run, string.format("ABANDONNE (tuile (%d, %d) du contournement prise), %d tapis repris", t.x, t.y, back))
      end
    end
    local n = 0
    for _, t in ipairs(missing) do
      if Stock.remove(f, run.item, 1) < 1 then break end
      local e = surface.create_entity({ name = run.belt, position = { t.x + 0.5, t.y + 0.5 }, direction = t.dir, force = f.force, raise_built = true })
      if e and e.valid then t.mine = true; n = n + 1 else Stock.insert(f, run.item, 1); break end
    end
    say(f, string.format("avant-poste %s : troncon de (%d, %d) : %d tapis du contournement pose(s) sur %d manquant(s)", tostring(run.oid), run.p.x, run.p.y, n, #missing))
  elseif act.kind == "couper" then
    -- relu au moteur à l'instant de la coupe : chaque tuile porte son tapis (posed == total ci-dessus), amont et aval en place
    if Rr.peut_couper(facts) and pe and pe.valid then
      pe.direction = run.cut
      say(f, string.format("avant-poste %s : troncon de (%d, %d) : COUPE : amont tourne vers le contournement (%d tapis en place), l'ancienne ligne se vide", tostring(run.oid),
        run.p.x, run.p.y, posed))
    end
  elseif act.kind == "retirer" then
    local n = 0
    for _, e in ipairs(old) do
      if e.valid and items_on(e) == 0 then
        local x, y, name = math.floor(e.position.x), math.floor(e.position.y), e.name
        local pr = e.prototype
        local item = pr.items_to_place_this and pr.items_to_place_this[1] and pr.items_to_place_this[1].name or run.item
        local q, piece = piece_at(f, x, y, name)
        if piece and Rer.Build then Rer.Build.cede_piece(f, q, piece, "reroutage") end
        State.disown(e.unit_number)
        e.destroy()
        Stock.insert(f, item, 1)
        n = n + 1
      end
    end
    say(f, string.format("avant-poste %s : troncon de (%d, %d) : %d tapis de l'ancienne ligne retire(s) et rendu(s) au stock", tostring(run.oid), run.p.x, run.p.y, n))
  end
end

local function teams()
  local list = {}
  local war = State.war()
  if war and war.active then
    for _, id in ipairs(State.alive()) do
      local f = war.factions[id]
      if f and f.hq and f.hq.valid then list[#list + 1] = f end
    end
  end
  local p = State.faction("player")
  if p and p.hq and p.hq.valid then list[#list + 1] = p end
  return list
end

function Rer.pulse()
  if not Rer.ENABLED then return end
  for _, f in ipairs(teams()) do
    local st = f.reroutage
    if st and st.run and f.hq.valid then step_run(f, f.hq.surface, st.run) end
  end
end

Events.on_nth_tick(Rer.EVERY, Rer.pulse)

return Rer
