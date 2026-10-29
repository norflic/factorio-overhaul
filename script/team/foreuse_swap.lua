--[[
  Lot FOREUSES (retour du DC du 29/10 apres 1 h 30 de partie sur 0.6.13) : « des foreuses thermiques encore presentes malgre la
  tech 2, alors qu'ils peuvent mettre des foreuses electriques a la place ». Regle pure : shared/team/foreuse_swap.lua.

  Tache de FOND bornee, au plus T.swap.per_pass remplacements toutes les T.swap.every ticks par equipe : une foreuse a combustion d'un
  avant-poste (celle de f.outposts[*].drill_list) devient electrique, sur place, quand
    - l'objet electrique est au stock (sinon il est fabrique d'avance, au plus T.swap.craft_cap, tache « craft » comme les pieces de
      la reconstruction) ;
    - un poteau de l'equipe dont la zone d'alimentation touche la future foreuse est sur un reseau qui PRODUIT (flux de la derniere
      minute > 0) ;
    - son recepteur (four ou coffre) reste le meme : le centre de la nouvelle boite de 3 x 3 est choisi pour que son depot y tombe ;
    - aucun ennemi a moins de Swap.SAFE tuiles.
  Pas de fast_replace : les emprises different (2 x 2, 3 x 3) et rien ne le prouve en moteur reel ; l'ancienne foreuse est retiree,
  l'emplacement verifie (arbres et rochers abattus comme a la pose de l'avant-poste), l'electrique posee ; si elle ne passe pas,
  l'ancienne est reposee a l'identique (combustible compris) et l'emplacement est laisse tranquille Swap.RETRY ticks.
  Le reste de la machinerie (propriete, liste de l'avant-poste, stock) est tenu : l'ancienne n'est plus « possedee » AVANT d'etre
  retiree (sinon on_entity_destroyed compterait une perte d'avant-poste).
  Determinisme : listes triees, aucun temps mesure ; etat dans f.swap (tables simples).
]]

local T = require("shared.team.config")
local S = require("shared.team.foreuse_swap")
local State = require("script.faction.state")
local Board = require("script.team.board")
local Stock = require("script.team.stock")

local Swap = {}

Swap.SAFE = 30       -- tuiles : pas de remplacement si un ennemi est plus pres
Swap.RETRY = 18000   -- 5 min : emplacement laisse tranquille apres un echec de pose
Swap.LOGS = 20

local function sorted_keys(t) return State.sorted_keys(t or {}) end

--- Le reseau du poteau produit-il du courant (un generateur de la derniere minute) ? Memoire par reseau, le temps d'une passe.
local function producing(pole, cache)
  local id = pole.electric_network_id
  if not id then return false end
  local c = cache[id]
  if c ~= nil then return c end
  local ok = false
  local stats = pole.electric_network_statistics
  if stats then
    for _, name in ipairs(sorted_keys(stats.input_counts)) do
      if stats.get_flow_count({ name = name, input = true, precision_index = defines.flow_precision_index.one_minute }) > 0 then
        ok = true
        break
      end
    end
  end
  cache[id] = ok
  return ok
end

local function box_of(e)
  local p = e.prototype
  return { x = e.position.x, y = e.position.y, w = p.tile_width or 1, h = p.tile_height or 1 }
end

--- Releve : foreuses a combustion des avant-postes avec leur recepteur, poteaux a portee et leur etat.
--- Rend entries (pour S.plan), refs { [id] = { o, index, drill } }, poles.
local function survey(f, surface)
  local entries, refs, poles, seen = {}, {}, {}, {}
  local cache = {}
  local retry = (f.swap and f.swap.retry) or {}
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    local any = false
    for i, d in ipairs(o.drill_list or {}) do
      if d.valid and d.name == T.DRILL and d.unit_number then
        local pos = d.position
        local key = pos.x .. ":" .. pos.y
        if not (retry[key] and game.tick < retry[key]) then
          local v = T.drill_drop
          local rx, ry = S.rotate(d.direction, v[1], v[2])
          local sink
          for _, s in ipairs(o.sinks or {}) do
            if s.valid and S.inside(box_of(s), pos.x + rx, pos.y + ry) then sink = box_of(s) break end
          end
          if sink then
            any = true
            entries[#entries + 1] = { id = d.unit_number, x = pos.x, y = pos.y, dir = d.direction, sink = sink }
            refs[d.unit_number] = { o = o, index = i, drill = d, key = key }
          end
        end
      end
    end
    if any then
      for _, p in ipairs(surface.find_entities_filtered({ position = o.pos, radius = T.swap.radius, type = "electric-pole",
          force = f.force })) do
        if p.valid and p.unit_number and not seen[p.unit_number] then
          seen[p.unit_number] = true
          poles[#poles + 1] = { id = p.unit_number, x = p.position.x, y = p.position.y, dist = p.prototype.supply_area_distance,
            powered = producing(p, cache) }
        end
      end
    end
  end
  table.sort(poles, function(a, b) return a.id < b.id end)
  return entries, refs, poles
end

local function place_back(f, surface, d_pos, dir, fuel, o, index)
  local old = surface.create_entity({ name = T.DRILL, position = d_pos, direction = dir, force = f.force })
  if old then
    if fuel > 0 then old.get_fuel_inventory().insert({ name = T.fuel, count = fuel }) end
    State.own(old, f.id, "drill", o.id)
    o.drill_list[index] = old
  end
  return old
end

--- Remplace UNE foreuse. Rend vrai si l'electrique est posee.
local function swap_one(f, surface, ref, cx, cy, tick)
  local d, o = ref.drill, ref.o
  if not d.valid then return false end
  local pos = { x = d.position.x, y = d.position.y }
  local dir = d.direction
  if surface.find_nearest_enemy({ position = pos, max_distance = Swap.SAFE, force = f.force }) then return false end
  local item = T.DRILL_ELECTRIC
  if Stock.remove(f, item, 1) < 1 then return false end
  local inv = d.get_fuel_inventory()
  local fuel = inv and inv.get_item_count(T.fuel) or 0
  State.disown(d.unit_number)
  d.destroy()
  -- L'ouvrier degage la place (arbres, rochers) comme a la pose de l'avant-poste.
  local half = T.drill_electric.size / 2
  for _, e in ipairs(surface.find_entities_filtered({ area = { { cx - half, cy - half }, { cx + half, cy + half } },
      type = { "tree", "simple-entity" } })) do
    if e.valid then e.destroy() end
  end
  local new
  if surface.can_place_entity({ name = item, position = { x = cx, y = cy }, direction = dir, force = f.force }) then
    new = surface.create_entity({ name = item, position = { x = cx, y = cy }, direction = dir, force = f.force })
  end
  local st = f.swap
  if not new then
    place_back(f, surface, pos, dir, fuel, o, ref.index)
    Stock.insert(f, item, 1)
    st.retry[ref.key] = tick + Swap.RETRY
    st.failed = (st.failed or 0) + 1
    return false
  end
  State.own(new, f.id, "drill", o.id)
  o.drill_list[ref.index] = new
  Stock.insert(f, T.DRILL, 1)
  if fuel > 0 then Stock.insert(f, T.fuel, fuel) end
  st.done = (st.done or 0) + 1
  if st.done <= Swap.LOGS then
    log(string.format("[FO-FOREUSES] %s : foreuse a combustion remplacee par une electrique en (%.1f, %.1f) a %.1f min (avant-poste %d, %d faite(s))",
      f.key or "player", cx, cy, (tick - (f.started or 0)) / 3600, o.id, st.done))
  end
  return true
end

--- Fabrication d'avance de l'objet electrique (meme patron que Recon.craft_spares) : `want` objets, sur le stock libre `free`.
local function craft(f, book, free, want, tick)
  local item = T.DRILL_ELECTRIC
  if want <= 0 or not book:handcraftable(item) then return 0 end
  local avail = {}
  for _, k in ipairs(sorted_keys(free)) do avail[k] = free[k] end
  avail[item] = 0 -- besoin d'accumulation : l'objet lui-meme n'est pas pris au stock
  local q = book:plan({ { item, want } }, avail)
  if next(q.raw) ~= nil then return 0 end
  local list = {}
  for _, k in ipairs(sorted_keys(q.uses)) do list[#list + 1] = { k, q.uses[k] } end
  return Board.add(f, { { key = "craft:" .. item .. ":foreuse", kind = "craft", prio = T.swap.prio, item = item, count = want,
    steps = q.crafts, uses = list, tag = "foreuse" } }, tick)
end

--- Une pensee d'equipe : releve, remplacements, fabrication d'avance. `free` : stock libre ({ [objet] = n }) de la pensee.
function Swap.think(f, surface, book, free, tick)
  if not (f and f.outposts and f.hq and f.hq.valid and next(f.outposts)) then return 0 end
  local st = f.swap
  if not st then
    st = { next = 0, done = 0, failed = 0, retry = {} }
    f.swap = st
  end
  if tick < st.next then return 0 end
  st.next = tick + T.swap.every
  local item = T.DRILL_ELECTRIC
  if not game.entity_prototypes[item] then return 0 end
  local have = Stock.count(f, item)
  local obtainable = have > 0 or book:handcraftable(item)
  local entries, refs, poles = survey(f, surface)
  if #entries == 0 or #poles == 0 then return 0 end
  local out, n_ready = S.plan(entries, { poles = poles, electric = T.drill_electric, have = have, obtainable = obtainable,
    limit = T.swap.per_pass })
  local made = 0
  for _, r in ipairs(out) do
    local ref = refs[r.id]
    if ref and swap_one(f, surface, ref, r.cx, r.cy, tick) then made = made + 1 end
  end
  st.ready = n_ready
  craft(f, book, free, S.demand(n_ready, have - made, T.swap.craft_cap), tick)
  return made
end

return Swap
