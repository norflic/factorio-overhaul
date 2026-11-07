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
local Bm = require("shared.team.book_max") -- lot S5 (×10) : plus grand nombre fabricable, sans la boucle de plans complets

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

local floor, ceil, abs = math.floor, math.ceil, math.abs

--- Lot S5 (×10) : clé numérique d'une tuile (unique pour |tx|, |ty| < 2^22 ; au-delà, deux tuiles peuvent partager une clé, ce qui
--- n'ajoute que des candidats relus par S.inside : le résultat ne change pas).
local function tkey(tx, ty) return tx * 8388608 + ty end

--- Lot S5 (×10) : réceptacles VALIDES d'un avant-poste (ordre de o.sinks, ipairs) et index par tuile. Une boîte par réceptacle (avant :
--- deux box_of par paire foreuse × réceptacle essayée, soit 6 lectures moteur et 3 tables). Chaque réceptacle est inscrit sur les tuiles
--- [floor(x - w/2), ceil(x + w/2) - 1] (idem en y) : un point STRICTEMENT dedans (S.inside, intervalle ouvert) tombe sur l'une
--- d'elles. Une tuile garde les indices dans l'ordre croissant : un nombre, ou une liste s'il y en a plusieurs.
local function sink_index(o)
  local boxes, idx = {}, {}
  for i, s in ipairs(o.sinks or {}) do
    if s.valid then
      local b = box_of(s)
      boxes[i] = b
      for tx = floor(b.x - b.w / 2), ceil(b.x + b.w / 2) - 1 do
        for ty = floor(b.y - b.h / 2), ceil(b.y + b.h / 2) - 1 do
          local k = tkey(tx, ty)
          local cur = idx[k]
          if cur == nil then
            idx[k] = i
          elseif type(cur) == "number" then
            idx[k] = { cur, i }
          else
            cur[#cur + 1] = i
          end
        end
      end
    end
  end
  return boxes, idx
end

--- Lot S5 (×10) : le premier réceptacle (ordre de o.sinks) dont la boîte contient le point (px, py), comme l'ancienne boucle.
local function sink_at(boxes, idx, px, py)
  local c = idx[tkey(floor(px), floor(py))]
  if c == nil then return nil end
  if type(c) == "number" then
    local b = boxes[c]
    if S.inside(b, px, py) then return b end
    return nil
  end
  for j = 1, #c do
    local b = boxes[c[j]]
    if S.inside(b, px, py) then return b end
  end
  return nil
end

--- Lot S5 (×10) : délais ACTIFS de f.swap.retry (clés « x:y » de l'ancienne foreuse, valeur : tick de fin), relus en nombres et
--- rangés par tuile (floor). La clé d'une foreuse (deux conversions nombre → chaîne, F16) n'est construite que si un délai actif
--- tombe sur l'une des 4 tuiles autour de sa position ; le test reste alors celui d'avant (retry[clé] et tick < retry[clé]).
--- Exact : la clé d'une foreuse est fmt(x) .. ":" .. fmt(y) ; fmt d'un nombre fini ne contient pas « : » et se relit par tonumber
--- à moins d'une demi-tuile près (au 14e chiffre), donc floor(v) est floor(x - 0.5) ou floor(x + 0.5) ; une clé qui ne se relit pas
--- en deux nombres n'est la clé d'aucune foreuse. Rend nil sans délai actif. L'ordre de `next` ne change rien (ensemble).
local function active_retry(retry, tick)
  local act, n = {}, 0
  for k, t in next, retry do
    if type(k) == "string" and type(t) == "number" and tick < t then
      local c = k:find(":", 1, true)
      local vx = c and tonumber(k:sub(1, c - 1))
      local vy = c and tonumber(k:sub(c + 1))
      if vx and vy then
        n = n + 1
        act[tkey(floor(vx), floor(vy))] = true
      end
    end
  end
  return n > 0 and act or nil
end

local function retried(retry, tick, act, pos)
  if not act then return false end
  local px, py = pos.x, pos.y
  local x0, y0 = floor(px - 0.5), floor(py - 0.5)
  if act[tkey(x0, y0)] or act[tkey(x0 + 1, y0)] or act[tkey(x0, y0 + 1)] or act[tkey(x0 + 1, y0 + 1)] then
    local key = px .. ":" .. py
    return (retry[key] and tick < retry[key]) and true or false
  end
  return false
end

--- Clé « x:y » d'une foreuse du relevé (construite seulement quand un délai est écrit).
local function key_of(ref)
  return ref.pos.x .. ":" .. ref.pos.y
end

--- Releve : foreuses a combustion des avant-postes avec leur recepteur, poteaux a portee et leur etat.
--- Rend entries (pour S.plan), refs { [id] = { o, index, drill, pos } }, poles.
local function survey(f, surface)
  local entries, refs, poles, seen = {}, {}, {}, {}
  local cache = {}
  local retry = (f.swap and f.swap.retry) or {}
  local tick = game.tick
  local act = active_retry(retry, tick)
  local drop = T.drill_drop
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    local any = false
    local boxes, idx -- lot S5 : index des réceptacles, bâti à la première foreuse à combustion qui en a besoin
    -- lot MIGRATION-CHAMP : un champ en cours de migration (rangees electriques du plan directeur) ne recoit pas de remplacement sur place
    for i, d in ipairs(o.migr == "en cours" and {} or (o.drill_list or {})) do
      if d.valid and d.name == T.DRILL and d.unit_number then
        local pos = d.position
        if not retried(retry, tick, act, pos) then
          local rx, ry = S.rotate(d.direction, drop[1], drop[2])
          if not boxes then boxes, idx = sink_index(o) end
          local sink = sink_at(boxes, idx, pos.x + rx, pos.y + ry)
          if sink then
            any = true
            entries[#entries + 1] = { id = d.unit_number, x = pos.x, y = pos.y, dir = d.direction, sink = sink }
            refs[d.unit_number] = { o = o, index = i, drill = d, pos = pos }
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
    st.retry[key_of(ref)] = tick + Swap.RETRY
    return false
  end
  -- Lot MELANGE (retour du DC du 3/11) : la zone de l'electrique deborde de celle de la thermique ; si elle touche une autre ressource
  -- minable, la foreuse en deverserait dans son four (charbon au combustible, puis foreuse figee) : pas de remplacement ici.
  local sp = o.kind and T.outposts[o.kind]
  local mv, ml = Melange.zone_at(surface, item, cx, cy, sp and sp.resource)
  if mv ~= "ok" then
    st.retry[key_of(ref)] = tick + 6 * Swap.RETRY
    st.mixed = (st.mixed or 0) + 1
    if st.mixed <= Swap.LOGS then
      local t = {}
      for _, it in ipairs(ml) do t[#t + 1] = it[1] .. " " .. it[2] end
      log(string.format("[FO-MELANGE] %s : foreuse a combustion en (%.1f, %.1f) gardee : l'electrique minerait aussi %s (avant-poste %d, %d cas)",
        f.key or "player", pos.x, pos.y, table.concat(t, ", "), o.id, st.mixed))
    end
    return false
  end
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
    st.retry[key_of(ref)] = tick + Swap.RETRY
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
  -- La matiere ne couvre pas toujours tout le besoin : on fabrique ce qu'elle permet (meme regle que Recon.craft_spares). Lot S5 (×10) :
  -- le plus grand nombre faisable de [1, want] par Bm.best (shared/team/book_max.lua), meme resultat que l'ancienne boucle de plans.
  local m, q = Bm.best(book, item, want, avail)
  if m == 0 then return 0 end
  want = m
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
  -- Stock LIBRE seulement : ce que le plan directeur a reserve (registre) n'est pas pris.
  local have = math.min(Stock.count(f, item), free and free[item] or 0)
  local obtainable = have > 0 or book:handcraftable(item)
  if not obtainable then
    st.ready = 0
    return 0 -- objet pas encore debloque : pas de releve (le cas de presque toute la partie au debut)
  end
  local entries, refs, poles = survey(f, surface)
  if #entries == 0 or #poles == 0 then st.ready = 0 return 0 end -- (lot GISEMENTS : st.ready relu par script/team/gisement.lua)
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

-- Lot S5 (x10) : releve expose pour tests/x10_s5_test.lua (equivalence avec l'ancien releve).
Swap._survey = survey

return Swap
