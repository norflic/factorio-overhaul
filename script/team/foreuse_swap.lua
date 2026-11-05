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
local Outposts = require("script.faction.outposts") -- crochet des tuiles reservees par le plan directeur (Outposts.reserved)
local Melange = require("script.team.melange") -- lot MELANGE : zone de la future foreuse electrique (5 x 5) relue au moteur
local P = require("shared.team.plan") -- lot FOREUSES-THERMIQUES : chaine de poteaux (P.pole_chain, recherche de chemin bornee)
local Sante = require("script.team.sante_centrale") -- lot FOREUSES-THERMIQUES : puissance des chantiers (bilan d'energie existant)

local Swap = {}

Swap.SAFE = 30       -- tuiles : pas de remplacement si un ennemi est plus pres
Swap.RETRY = 18000   -- 5 min : emplacement laisse tranquille apres un echec de pose
Swap.LOGS = 20
-- Lot FOREUSES-THERMIQUES : poteaux posés par le remplacement (petit d'abord : le moyen manque aux bandes du champ dans la partie du DC)
Swap.POLES = { "small-electric-pole", "medium-electric-pole" }
Swap.POLE_CAP = 12   -- poteaux fabriqués d'avance au plus
Swap.REPORT = 10 * 3600 -- bilan [FO-FOREUSES-ETAT] par tranche de 10 min
Swap.JTICK_KW = 60 / 1000

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
    -- lot MIGRATION-CHAMP : un champ en cours de migration (rangees electriques du plan directeur) ne recoit pas de remplacement sur place
    for i, d in ipairs(o.migr == "en cours" and {} or (o.drill_list or {})) do
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
      -- lot FOREUSES-THERMIQUES : poteaux jusqu'a une chaine de S.CHAIN_MAX poteaux (fil de 9 tuiles au plus) au-dela du rayon d'avant
      for _, p in ipairs(surface.find_entities_filtered({ position = o.pos, radius = T.swap.radius + S.CHAIN_MAX * 9, type = "electric-pole",
          force = f.force })) do
        if p.valid and p.unit_number and not seen[p.unit_number] then
          seen[p.unit_number] = true
          poles[#poles + 1] = { id = p.unit_number, x = p.position.x, y = p.position.y, dist = p.prototype.supply_area_distance,
            wire = p.prototype.max_wire_distance, powered = producing(p, cache), ent = p }
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

--- Remplace UNE foreuse. Rend vrai si l'electrique est posee. `prep` (facultatif, lot FOREUSES-THERMIQUES) : pose des poteaux, appelee
--- APRES les gardes (ennemi, place reservee, couloir, melange) et AVANT de retirer l'ancienne foreuse ; faux : rien n'est remplace.
local function swap_one(f, surface, ref, cx, cy, tick, prep)
  local d, o = ref.drill, ref.o
  if not d.valid then return false end
  local pos = { x = d.position.x, y = d.position.y }
  local dir = d.direction
  if surface.find_nearest_enemy({ position = pos, max_distance = Swap.SAFE, force = f.force }) then return false end
  local item = T.DRILL_ELECTRIC
  local st = f.swap
  -- Relecture statique : la place de la future boite est peut-etre reservee par le plan directeur (meme garde que place_pairs) ;
  -- on le sait AVANT de retirer l'ancienne foreuse.
  -- Lot ÉTAGE 5 (revue B1) : remplacement SUR PLACE : les tuiles de couloir sous l'ancienne foreuse ne comptent pas (sinon une foreuse à
  -- combustion déjà sur un couloir ne passait JAMAIS à l'électrique) ; seules les tuiles hors de l'ancienne emprise respectent le couloir.
  local bb = d.bounding_box
  local keep = { math.floor(bb.left_top.x + 0.01), math.floor(bb.left_top.y + 0.01), math.ceil(bb.right_bottom.x - 0.01) - 1,
    math.ceil(bb.right_bottom.y - 0.01) - 1 }
  -- B1, 2e relecture : le remplacement n'est refusé que s'il COUPE le couloir ; tout ce qui arrête un PNJ autour de la future boîte
  -- compte comme pris (couche « player-layer » : bâtiments de toutes les forces, rochers, falaises, arbres ; les tapis non), sauf
  -- l'ancienne foreuse et ce qui bouge (personnages, unités, véhicules) ; l'eau aussi (3e relecture : rochers, falaises, eau).
  local taken = {}
  local r = T.drill_electric.size / 2 + 3
  local area = { { cx - r, cy - r }, { cx + r, cy + r } }
  local MOVING = { character = true, unit = true, car = true, ["spider-vehicle"] = true, locomotive = true, ["cargo-wagon"] = true,
    ["fluid-wagon"] = true, ["artillery-wagon"] = true }
  for _, t in ipairs(surface.find_tiles_filtered({ area = area, collision_mask = "player-layer" })) do
    taken[math.floor(t.position.x) .. "," .. math.floor(t.position.y)] = true
  end
  for _, e in ipairs(surface.find_entities_filtered({ area = area, collision_mask = "player-layer" })) do
    if e.valid and e ~= d and not MOVING[e.type] then
      local eb = e.bounding_box
      for ty = math.floor(eb.left_top.y + 0.01), math.ceil(eb.right_bottom.y - 0.01) - 1 do
        for tx = math.floor(eb.left_top.x + 0.01), math.ceil(eb.right_bottom.x - 0.01) - 1 do taken[tx .. "," .. ty] = true end
      end
    end
  end
  local blocked = function(x, y) return taken[x .. "," .. y] == true end
  if Outposts.reserved and Outposts.reserved(f, item, { x = cx, y = cy }, dir, { keep = keep, blocked = blocked }) then
    st.retry[ref.key] = tick + Swap.RETRY
    return false
  end
  -- Lot MELANGE (retour du DC du 3/11) : la zone de l'electrique deborde de celle de la thermique ; si elle touche une autre ressource
  -- minable, la foreuse en deverserait dans son four (charbon au combustible, puis foreuse figee) : pas de remplacement ici.
  local sp = o.kind and T.outposts[o.kind]
  local mv, ml = Melange.zone_at(surface, item, cx, cy, sp and sp.resource)
  if mv ~= "ok" then
    st.retry[ref.key] = tick + 6 * Swap.RETRY
    st.mixed = (st.mixed or 0) + 1
    if st.mixed <= Swap.LOGS then
      local t = {}
      for _, it in ipairs(ml) do t[#t + 1] = it[1] .. " " .. it[2] end
      log(string.format("[FO-MELANGE] %s : foreuse a combustion en (%.1f, %.1f) gardee : l'electrique minerait aussi %s (avant-poste %d, %d cas)",
        f.key or "player", pos.x, pos.y, table.concat(t, ", "), o.id, st.mixed))
    end
    return false
  end
  if Stock.count(f, item) < 1 then return false end
  if prep and not prep() then return false end
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
    -- raise_built : les niveaux et les modules (famille « drill ») enregistrent la foreuse, comme pour les pieces refaites (F40 : nil si
    -- un gestionnaire la detruit).
    new = surface.create_entity({ name = item, position = { x = cx, y = cy }, direction = dir, force = f.force, raise_built = true })
    if new and not new.valid then new = nil end
  end
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
--- Lot FOREUSES-THERMIQUES : `item` (facultatif) : un poteau, meme patron.
local function craft(f, book, free, want, tick, item)
  item = item or T.DRILL_ELECTRIC
  if want <= 0 or not book:handcraftable(item) then return 0 end
  local avail = {}
  for _, k in ipairs(sorted_keys(free)) do avail[k] = free[k] end
  avail[item] = 0 -- besoin d'accumulation : l'objet lui-meme n'est pas pris au stock
  local q = book:plan({ { item, want } }, avail)
  if next(q.raw) ~= nil then
    -- La matiere ne couvre pas toujours tout le besoin : on fabrique ce qu'elle permet (meme regle que Recon.craft_spares).
    local found = false
    for m = want - 1, 1, -1 do
      local q2 = book:plan({ { item, m } }, avail)
      if next(q2.raw) == nil then q, want, found = q2, m, true break end
    end
    if not found then return 0 end
  end
  local list = {}
  for _, k in ipairs(sorted_keys(q.uses)) do list[#list + 1] = { k, q.uses[k] } end
  return Board.add(f, { { key = "craft:" .. item .. ":foreuse", kind = "craft", prio = T.swap.prio, item = item, count = want,
    steps = q.crafts, uses = list, tag = "foreuse" } }, tick)
end

--- Lot FOREUSES-THERMIQUES : poteau a poser (le premier au stock libre, sinon le premier fabricable) et son gabarit, ou nil.
local function pole_choice(book, free)
  local list = {}
  for _, name in ipairs(Swap.POLES) do
    local pr = game.entity_prototypes[name]
    if pr then list[#list + 1] = { name = name, have = free and free[name] or 0, craftable = book:handcraftable(name) } end
  end
  local name = S.pole_item(list)
  if not name then return nil end
  local pr = game.entity_prototypes[name]
  return { name = name, supply = pr.supply_area_distance, wire = pr.max_wire_distance }
end

--- Tuile libre pour un poteau de la chaine d'une entree : ni sur la future foreuse ni sur son recepteur, posable, ni reservee par le plan
--- directeur ni sur un couloir d'acces (Outposts.reserved).
local function free_for(f, surface, pole)
  return function(e, box)
    return function(x, y)
      local pb = { x = x, y = y, w = 1, h = 1 }
      if S.overlap(pb, box) or S.overlap(pb, e.sink) then return false end
      if not surface.can_place_entity({ name = pole.name, position = { x = x, y = y }, force = f.force }) then return false end
      if Outposts.reserved and Outposts.reserved(f, pole.name, { x = x, y = y }, 0) then return false end
      return true
    end
  end
end

--- Pose la chaine `list` depuis le poteau `src` (entite). Rend vrai si le dernier poteau est sur le reseau de la source ; sinon tout est
--- repris (poteaux retires, objets rendus au stock) et rend faux, raison.
local function place_chain(f, surface, pole, list, src)
  if #list == 0 then return true end
  if Stock.count(f, pole.name) < #list then return false, "poteaux au stock" end
  local placed = {}
  local function undo(why)
    for _, e in ipairs(placed) do
      if e.valid then e.destroy() end
      Stock.insert(f, pole.name, 1)
    end
    return false, why
  end
  local prev = src
  for _, q in ipairs(list) do
    if not surface.can_place_entity({ name = pole.name, position = { x = q.x, y = q.y }, force = f.force }) then return undo("place prise") end
    if Stock.remove(f, pole.name, 1) < 1 then return undo("poteaux au stock") end
    local e = surface.create_entity({ name = pole.name, position = { x = q.x, y = q.y }, force = f.force, raise_built = true })
    if not (e and e.valid) then
      Stock.insert(f, pole.name, 1)
      return undo("pose refusee")
    end
    placed[#placed + 1] = e
    if prev and prev.valid then prev.connect_neighbour(e) end -- (F101 : raccord seul, deduit ; le fil est pose de toute facon)
    prev = e
  end
  local last = placed[#placed]
  if not (src and src.valid and last.valid and last.electric_network_id ~= nil and last.electric_network_id == src.electric_network_id) then
    return undo("reseau non relie")
  end
  return true
end

--- Bilan de puissance de l'equipe (kW) : capacite et production de la centrale (plan directeur, f.build.grow), chantiers admis.
local function power_of(f)
  local g = f.build and f.build.grow
  if not (g and (g.capacity or 0) > 0) then return nil end
  return { capacity = g.capacity * Swap.JTICK_KW, used = (g.power or 0) * Swap.JTICK_KW, committed = Sante.committed(f) }
end

local function count(st, why)
  st.why = st.why or {}
  st.why[why] = (st.why[why] or 0) + 1
end

--- Lot FOREUSES-THERMIQUES : bilan [FO-FOREUSES-ETAT] une fois par tranche de 10 min (remplacements, poteaux, candidats, refus par cause).
local function report(f, st, tick, n_ready, n_chain, n_burner)
  local slot = math.floor(tick / Swap.REPORT)
  if st.slot == slot then return end
  local first = st.slot == nil
  st.slot = slot
  if first then return end
  local w = {}
  for _, k in ipairs(sorted_keys(st.why or {})) do w[#w + 1] = k .. " " .. st.why[k] end
  log(string.format("[FO-FOREUSES-ETAT] %s min %d | remplacees %d (dont %d avec %d poteau(x) poses) | thermiques candidates %d, deja alimentees %d, a chaine %d | refus : %s | melange %d",
    f.key or "player", math.floor((tick - (f.started or 0)) / 3600), st.done or 0, st.chained or 0, st.poles or 0, n_burner or 0,
    n_ready or 0, n_chain or 0, #w > 0 and table.concat(w, ", ") or "aucun", st.mixed or 0))
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
  -- Stock LIBRE seulement : ce que le plan directeur a reserve (registre) n'est pas pris.
  local have = math.min(Stock.count(f, item), free and free[item] or 0)
  local obtainable = have > 0 or book:handcraftable(item)
  if not obtainable then
    st.ready = 0
    return 0 -- objet pas encore debloque : pas de releve (le cas de presque toute la partie au debut)
  end
  local entries, refs, poles = survey(f, surface)
  if #entries == 0 or #poles == 0 then -- (lot GISEMENTS : st.ready relu par script/team/gisement.lua)
    st.ready = 0
    report(f, st, tick, 0, 0, #entries)
    return 0
  end
  -- lot FOREUSES-THERMIQUES : le remplacement pose lui-meme sa chaine de poteaux depuis le poteau alimente le plus proche
  local pole = pole_choice(book, free)
  local ctx = { poles = poles, electric = T.drill_electric, have = have, obtainable = obtainable, limit = T.swap.per_pass,
    pole = pole, free_for = pole and free_for(f, surface, pole) or nil, chain = P.pole_chain, chain_max = S.CHAIN_MAX }
  local out, n_ready, n_chain = S.plan(entries, ctx)
  for _, rf in ipairs(ctx.refused or {}) do
    local ref = refs[rf.id]
    if ref then st.retry[ref.key] = tick + Swap.RETRY end
    count(st, rf.why)
  end
  local by_pos = {}
  for _, p in ipairs(poles) do by_pos[p.x .. ":" .. p.y] = p.ent end
  local made, kw_new, need_poles = 0, 0, 0
  local kw = (game.entity_prototypes[item].energy_usage or 0) * Swap.JTICK_KW
  local pc = power_of(f)
  for _, r in ipairs(out) do
    local ref = refs[r.id]
    if ref then
      if pc and not S.power_ok({ capacity = pc.capacity, used = pc.used + kw_new, committed = pc.committed }, kw, 0.6) then
        count(st, "courant")
        break
      end
      local placed_n = #(r.poles or {})
      local prep
      if placed_n > 0 then
        need_poles = need_poles + placed_n
        prep = function()
          local src = r.source and (r.source.ent or by_pos[r.source.x .. ":" .. r.source.y])
          local ok, why = place_chain(f, surface, pole, r.poles, src)
          if not ok then
            count(st, why)
            if why ~= "poteaux au stock" then st.retry[ref.key] = tick + Swap.RETRY end
          end
          return ok
        end
      end
      if swap_one(f, surface, ref, r.cx, r.cy, tick, prep) then
        made = made + 1
        kw_new = kw_new + kw
        if placed_n > 0 then
          st.chained = (st.chained or 0) + 1
          st.poles = (st.poles or 0) + placed_n
          if st.chained <= Swap.LOGS then
            log(string.format("[FO-FOREUSES] %s : electrique en (%.1f, %.1f) avec %d %s pose(s) depuis le reseau en (%.1f, %.1f) a %.1f min (%d avec chaine)",
              f.key or "player", r.cx, r.cy, placed_n, pole.name, r.source.x, r.source.y, (tick - (f.started or 0)) / 3600, st.chained))
          end
        end
      end
    end
  end
  st.ready = n_ready
  craft(f, book, free, S.demand(n_ready + n_chain, have - made, T.swap.craft_cap), tick)
  if pole and n_chain > 0 then
    local want = math.min(Swap.POLE_CAP, math.max(need_poles, S.CHAIN_MAX)) - (free and free[pole.name] or 0)
    if want > 0 then craft(f, book, free, want, tick, pole.name) end
  end
  report(f, st, tick, n_ready, n_chain, #entries)
  return made
end

return Swap
