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
local Scheduler = require("script.core.scheduler") -- lot TRANCHES : suite d'une passe au tick suivant (minuterie)
local Ra = require("script.team.reserve_amorcage") -- réserve d'amorçage du combustible (K lu aux DONNÉES ; partagée avec le champ)
local Profiler = require("script.core.profiler") -- mesure des tranches jouées par la minuterie (hors de la portée tt:foswap de la pensée)

local Swap = {}

Swap.SAFE = 30       -- tuiles : pas de remplacement si un ennemi est plus pres
Swap.RETRY = 18000   -- 5 min : emplacement laisse tranquille apres un echec de pose
Swap.LOGS = 20
-- Lot FOREUSES-THERMIQUES : poteaux posés par le remplacement, lus dans T (petit d'abord)
Swap.POLES = T.swap.poles
Swap.POLE_CAP = 12   -- poteaux fabriqués d'avance au plus
Swap.REPORT = 10 * 3600 -- bilan [FO-FOREUSES-ETAT] par tranche de 10 min
Swap.JTICK_KW = 60 / 1000
Swap.MIN_ORE = 3       -- tuiles de minerai au moins dans la zone de minage de l'electrique (comme Champ, Ch.CFG.min_ore)

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

--- Banc foreuses-dense (7/11, 0 remplacement sur 328 thermiques ; journal de diagnostic : 20 entrées seulement, 0 aux premières passes) :
--- `drop_target` d'une foreuse posée AVANT son récepteur (Outposts.extend : foreuse, puis four) reste nil tant qu'elle n'a rien déposé
--- (déduit, non prouvé seul). Avant B2 (bbc015f6), le relevé lisait le point de dépôt des DONNÉES dans les réceptacles. Index des
--- réceptacles valides d'un avant-poste par tuile couverte (O(réceptacles) une fois, puis O(1) par foreuse).
local function sink_tiles(o)
  local at = {}
  for _, k in ipairs(o.sinks or {}) do
    if k.valid and k.unit_number then
      local b = box_of(k)
      for ty = math.floor(b.y - b.h / 2 + 0.01), math.ceil(b.y + b.h / 2 - 0.01) - 1 do
        for tx = math.floor(b.x - b.w / 2 + 0.01), math.ceil(b.x + b.w / 2 - 0.01) - 1 do at[tx .. ":" .. ty] = k end
      end
    end
  end
  return at
end

--- Point de dépôt d'une foreuse (vecteur des données : T.drill_drop pour la thermique, T.drill_electric.drop sinon), tourné selon sa direction.
local function drop_point(d)
  local v = d.name == T.DRILL and T.drill_drop or T.drill_electric.drop
  local rx, ry = S.rotate(d.direction, v[1], v[2])
  return d.position.x + rx, d.position.y + ry
end

--- Récepteur d'une foreuse : celui du moteur (drop_target) s'il est connu ; sinon le réceptacle de l'avant-poste sous son point de dépôt
--- (`at` : sink_tiles), ou nil.
local function receiver_of(d, at)
  local t = d.drop_target
  if t and t.valid then return t end
  local px, py = drop_point(d)
  return at[math.floor(px) .. ":" .. math.floor(py)]
end

--- Revue du lead (7/11, (4)) : votre equipe partage la FORCE du joueur ; ses poteaux ne sont pas les notres. Tuiles des poteaux du plan
--- directeur de l'equipe (ses projets : centrale, liaisons, champs), memoire par equipe hors de global (recalculee apres un chargement), refaite
--- quand les projets changent (signature : numero et nombre de pieces de chaque projet).
local plan_poles = {}
local function plan_pole_tiles(f)
  local b = f.build
  if not (b and b.order and b.projects) then return {} end
  local sig = {}
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    sig[#sig + 1] = tostring(pid) .. ":" .. tostring(p and p.ents and #p.ents or 0)
  end
  local key = tostring(f.key or f.id)
  local s = table.concat(sig, ";")
  local c = plan_poles[key]
  if c and c.sig == s then return c.set end
  local set = {}
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    for _, e in ipairs(p and p.ents or {}) do
      if e.name and e.x and P.kind_rank(e.name) == 1 then set[P.tkey(math.floor(e.x), math.floor(e.y))] = true end
    end
  end
  plan_poles[key] = { sig = s, set = set }
  return set
end

--- (4) : poteau de l'EQUIPE ? Enregistre a son nom (State.own), pose par une chaine du remplacement (tuile retenue, f.swap.pole_pos) ou
--- piece de son plan directeur. Jamais un poteau du joueur : la chaine ne part pas de son reseau et ne tire pas sur sa centrale.
local function team_pole(f, p, plan_set)
  local u = p.unit_number
  local ow = u and State.owner(u)
  if ow and ow.f == f.id then return true end
  local k = P.tkey(math.floor(p.position.x), math.floor(p.position.y))
  return (f.swap and f.swap.pole_pos and f.swap.pole_pos[k]) == true or plan_set[k] == true
end

--- Réserve d'amorçage (décision du lead, 7/11, exception de sûreté) : avant-poste de combustible et K lus par
--- script/team/reserve_amorcage.lua (module léger, partagé avec le balayage et le retrait à sec du champ).
local fuel_outpost, reserve_keep = Ra.fuel_outpost, Ra.keep

--- Releve : foreuses a combustion des avant-postes avec leur recepteur, poteaux a portee et leur etat. Lot TRANCHES (lead, 7/11 : tt:foswap
--- jusqu'a 125 ms d'un bloc) : releve REPRENABLE, dans l'etat de passe `pass` (global : f.swap.pass) ; avant-postes dans l'ordre trie fixe au
--- depart de la passe (pass.oids), curseur pass.oi / pass.di. Une foreuse lue coute 1 unite de travail, une recherche de poteaux
--- Swap.POLE_COST ; s'arrete des que `budget` unites sont depensees. Rend le cout et vrai quand le releve est fini. Decisions lues au
--- tick de depart de la passe (pass.t0), jamais au tick courant : une passe en tranches decide comme d'un bloc.
--- pass.entries (pour S.plan), pass.refs { [id] = { oid, index, drill, key, sink_ent } }, pass.poles.
local function survey_step(f, surface, pass, budget)
  local used = 0
  pass.burners = pass.burners or {} -- (réserve d'amorçage ; une passe gardée dans global par une version d'avant n'en a pas)
  local retry = (f.swap and f.swap.retry) or {}
  while pass.oi <= #pass.oids do
    local oid = pass.oids[pass.oi]
    local o = f.outposts[oid]
    if o then
      -- revue du lead (7/11, B2, cout) : recepteur de chaque thermique lu au moteur (drop_target) dans l'ensemble des fours de l'avant-poste,
      -- au lieu d'un parcours de tous les fours par foreuse (171 x 171 lectures sur un avant-poste dense)
      local sink_set, sink_at
      -- lot MIGRATION-CHAMP : un champ en cours de migration (rangees electriques du plan directeur) ne recoit pas de remplacement sur place
      local list = o.migr == "en cours" and {} or (o.drill_list or {})
      local fuel = fuel_outpost(o) -- réserve d'amorçage : thermiques DEBOUT de l'avant-poste (toutes, refus et attentes compris)
      while pass.di <= #list do
        local i = pass.di
        local d = list[i]
        pass.di = i + 1
        used = used + 1
        if fuel and d.valid and d.name == T.DRILL then pass.burners[oid] = (pass.burners[oid] or 0) + 1 end
        if d.valid and d.name == T.DRILL and d.unit_number and not pass.refs[d.unit_number] then
          local pos = d.position
          local key = pos.x .. ":" .. pos.y
          if not (retry[key] and pass.t0 < retry[key]) then
            if not sink_set then
              sink_set = {}
              for _, s in ipairs(o.sinks or {}) do if s.valid and s.unit_number then sink_set[s.unit_number] = true end end
              sink_at = sink_tiles(o)
            end
            local t = receiver_of(d, sink_at) -- (drop_target, sinon point de dépôt des données : foreuse qui n'a encore rien déposé)
            local sink
            if t and t.valid and t.unit_number and sink_set[t.unit_number] then sink = box_of(t) end
            if sink then
              pass.any = true
              pass.entries[#pass.entries + 1] = { id = d.unit_number, x = pos.x, y = pos.y, dir = d.direction, sink = sink, o = oid }
              pass.refs[d.unit_number] = { oid = oid, index = i, drill = d, key = key, sink_ent = t }
            end
          end
        end
        if used >= budget then return used, false end
      end
      if pass.any then
        -- lot FOREUSES-THERMIQUES : poteaux jusqu'a une chaine de S.CHAIN_MAX poteaux (fil de 9 tuiles au plus) au-dela du rayon d'avant
        used = used + Swap.POLE_COST
        for _, p in ipairs(surface.find_entities_filtered({ position = o.pos, radius = T.swap.radius + S.CHAIN_MAX * 9, type = "electric-pole",
            force = f.force })) do
          if p.valid and p.unit_number and not pass.seen[p.unit_number] then
            pass.seen[p.unit_number] = true
            if team_pole(f, p, plan_pole_tiles(f)) then
              pass.poles[#pass.poles + 1] = { id = p.unit_number, x = p.position.x, y = p.position.y, dist = p.prototype.supply_area_distance,
                wire = p.prototype.max_wire_distance, powered = producing(p, pass.nets), ent = p }
            end
          end
        end
      end
    end
    pass.oi, pass.di, pass.any = pass.oi + 1, 1, false
    if used >= budget then return used, pass.oi > #pass.oids end
  end
  return used, true
end

--- Relecture indépendante (revue-0657, 7/11, BLOQUANT) : case ACTUELLE de `e` dans `list`, par identité ; jamais l'index du relevé. Entre
--- deux tranches, d'autres modules réécrivent la liste (migration_champ.lua retire : listes refaites ; adopte.lua : table.remove) ; écrire à
--- l'index du relevé écrasait une AUTRE foreuse, ou laissait un trou que ipairs (compact) arrête. nil si `e` n'y est plus.
local function slot_of(list, e)
  for i, x in ipairs(list or {}) do if x.valid and x == e then return i end end -- (revue-0657 : cases mortes sautees)
  return nil
end

--- Repose l'ancienne foreuse (l'electrique n'a pas pu etre posee). Revue du lead (7/11, (2)) : place verifiee d'abord (F70 : create_entity
--- pose par-dessus sans verifier) ; nil si elle ne se repose pas (l'appelant rend l'objet et le combustible au stock).
local function place_back(f, surface, d_pos, dir, fuel, o, index)
  if not surface.can_place_entity({ name = T.DRILL, position = d_pos, direction = dir, force = f.force }) then return nil end
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
local function swap_one(f, surface, ref, cx, cy, tick, prep, ndir)
  local d, o = ref.drill, ref.o
  if not d.valid then return false end
  local st0 = f.swap
  if not slot_of(o.drill_list, d) then -- (revue-0657 : la foreuse a quitté la liste depuis le relevé : plan périmé, rien n'est remplacé)
    st0.why = st0.why or {}
    st0.why["plan perime"] = (st0.why["plan perime"] or 0) + 1
    return false
  end
  local pos = { x = d.position.x, y = d.position.y }
  local dir = d.direction
  -- lot FOREUSES-THERMIQUES : direction de l'electrique (placement choisi par S.plan, peut-etre sur un autre cote du recepteur)
  local edir = ndir or dir
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
  if Outposts.reserved and Outposts.reserved(f, item, { x = cx, y = cy }, edir, { keep = keep, blocked = blocked }) then
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
  local idx = slot_of(o.drill_list, d) -- (revue-0657 : relue après prep, juste avant le retrait)
  if not idx then
    Stock.insert(f, item, 1)
    st0.why = st0.why or {}
    st0.why["plan perime"] = (st0.why["plan perime"] or 0) + 1
    return false
  end
  State.disown(d.unit_number)
  d.destroy()
  -- L'ouvrier degage la place (arbres, rochers) comme a la pose de l'avant-poste.
  local half = T.drill_electric.size / 2
  for _, e in ipairs(surface.find_entities_filtered({ area = { { cx - half, cy - half }, { cx + half, cy + half } },
      type = { "tree", "simple-entity" } })) do
    if e.valid then e.destroy() end
  end
  local new
  if surface.can_place_entity({ name = item, position = { x = cx, y = cy }, direction = edir, force = f.force }) then
    -- raise_built : les niveaux et les modules (famille « drill ») enregistrent la foreuse, comme pour les pieces refaites (F40 : nil si
    -- un gestionnaire la detruit).
    new = surface.create_entity({ name = item, position = { x = cx, y = cy }, direction = edir, force = f.force, raise_built = true })
    if new and not new.valid then new = nil end
  end
  if not new then
    if not place_back(f, surface, pos, dir, fuel, o, idx) then
      Stock.insert(f, T.DRILL, 1)
      if fuel > 0 then Stock.insert(f, T.fuel, fuel) end
    end
    Stock.insert(f, item, 1)
    st.retry[ref.key] = tick + Swap.RETRY
    st.failed = (st.failed or 0) + 1
    return false
  end
  State.own(new, f.id, "drill", o.id)
  o.drill_list[idx] = new
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
--- repris (poteaux retires, objets rendus au stock) et rend faux, raison. `free` = { n = poteaux au stock LIBRE de la pensee } (revue du
--- lead, 7/11, (3) : ce que le plan directeur a reserve n'est pas pris) ; debite de la chaine posee. `mine(poteau)` (facultatif, revue (4)) :
--- vrai pour un poteau de l'equipe ; le poteau neuf ne garde de fil de cuivre que vers l'equipe et sa chaine (le moteur relie de lui-meme
--- un poteau pose aux voisins a portee : deduit, non mesure ; le retrait est sans effet s'il ne le fait pas).
local function place_chain(f, surface, pole, list, src, free, mine)
  if #list == 0 then return true end
  if (free and free.n or 0) < #list or Stock.count(f, pole.name) < #list then return false, "poteaux au stock" end
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
    if mine then
      local nb = e.neighbours
      for _, n in ipairs(nb and nb.copper or {}) do
        if n.valid and n ~= prev and not mine(n) then e.disconnect_neighbour(n) end
      end
    end
    if prev and prev.valid then prev.connect_neighbour(e) end -- (F101 : raccord seul, deduit ; le fil est pose de toute facon)
    prev = e
  end
  local last = placed[#placed]
  if not (src and src.valid and last.valid and last.electric_network_id ~= nil and last.electric_network_id == src.electric_network_id) then
    return undo("reseau non relie")
  end
  free.n = free.n - #list
  return true, nil, placed
end

--- Revue du lead (7/11, B1) : une electrique (de l'avant-poste ou d'ailleurs : bandes du champ) depose-t-elle dans le four `k` ? Lu au
--- moteur (drop_target des foreuses electriques autour du four), `except` exclue.
local function fed_by_electric(surface, k, except)
  local kb = k.bounding_box
  for _, x in ipairs(surface.find_entities_filtered({ area = { { kb.left_top.x - 3, kb.left_top.y - 3 }, { kb.right_bottom.x + 3, kb.right_bottom.y + 3 } },
      type = "mining-drill" })) do
    if x.valid and x ~= except and not x.burner then
      local t = x.drop_target
      if t == k then return true end
      -- (électrique qui n'a encore rien déposé : son point de dépôt des données dans le four)
      if not (t and t.valid) then
        local px, py = drop_point(x)
        if S.inside(box_of(k), px, py) then return true end
      end
    end
  end
  return false
end

--- Revue du lead (7/11, B1 et B2) : le plan d'une entree a ete fait AVANT toute pose de la passe (paires relues une fois par passe). Encore
--- bon a l'execution ? Le four de l'entree est toujours la, et aucune electrique (posee plus tot dans la passe, ou d'ailleurs) ne depose
--- dans un four que son echange retirerait.
local function stale_plan(surface, ref, ex)
  if ref.sink_ent and not ref.sink_ent.valid then return true end
  for _, e in ipairs(ex and ex.ents or {}) do
    if e.valid and e.name ~= T.DRILL and fed_by_electric(surface, e, ref.drill) then return true end
  end
  return false
end

--- Lot FOREUSES-THERMIQUES (banc du 7/11) : la 3 x 3 en (cx, cy) tient-elle AVANT tout poteau ? Rien d'autre que l'ancienne foreuse et
--- ce qui se defriche (arbres, rochers) sur la boite, pas d'eau, et au moins Swap.MIN_ORE tuiles du minerai de l'avant-poste dans la zone
--- de minage (5 x 5). Lit le moteur : S.plan l'appelle au plus S.FIT_TRIES fois par passe.
local function fits_for(f, surface, refs)
  local item = T.DRILL_ELECTRIC
  local pr = game.entity_prototypes[item]
  local r = pr and pr.mining_drill_radius or 2.49
  -- Revue du lead (7/11, B2, cout) : les paires d'un avant-poste sont relues UNE fois par avant-poste et par passe (S.plan appelle fits
  -- jusqu'a S.FIT_TRIES fois, plusieurs placements par entree : jusqu'a 64 relectures de 171 foreuses avant). Valable le temps de la
  -- passe : S.plan decide avant toute pose ou tout retrait.
  local lists, infos = {}, {}
  local function lists_of(o)
    local l = lists[o]
    if l then return l end
    local mine_d, mine_s = {}, {}
    for _, d in ipairs(o.drill_list or {}) do if d.valid and d.unit_number then mine_d[d.unit_number] = d end end
    for _, k in ipairs(o.sinks or {}) do if k.valid and k.unit_number then mine_s[k.unit_number] = k end end
    l = { d = mine_d, s = mine_s, at = sink_tiles(o) }
    lists[o] = l
    return l
  end
  -- paires de l'avant-poste : recepteur de chaque foreuse, foreuses de chaque recepteur. Revue du lead (7/11, B1) : le recepteur REEL lu
  -- au moteur (drop_target : l'entite ou la foreuse depose), pour la thermique comme pour l'electrique ; le vecteur de depot de la
  -- thermique (T.drill_drop) tombait dans la 3 x 3 d'une electrique, et le four de celle-ci etait retire. Les electriques ne se
  -- retirent jamais (fixed) : un four qui recoit d'une electrique est garde (S.exchange, « recepteur d'une electrique »).
  local function info_of(o, l)
    local info = infos[o]
    if info then return info end
    local sink_of, feeders, fixed = {}, {}, {}
    for _, du in ipairs(sorted_keys(l.d)) do
      local d = l.d[du]
      if d.name ~= T.DRILL then fixed[du] = true end
      local tgt = receiver_of(d, l.at) -- (drop_target, sinon point de dépôt des données)
      local su = tgt and tgt.valid and tgt.unit_number
      if su and l.s[su] then
        sink_of[du] = su
        feeders[su] = feeders[su] or {}
        feeders[su][#feeders[su] + 1] = du
      end
    end
    info = { sink_of = sink_of, feeders = feeders, fixed = fixed }
    infos[o] = info
    return info
  end
  return function(e, cx, cy, dir)
    local ref = refs[e.id]
    if not (ref and ref.drill and ref.drill.valid) then return false end
    local half = T.drill_electric.size / 2 - 0.01
    local area = { { cx - half, cy - half }, { cx + half, cy + half } }
    if surface.count_tiles_filtered({ area = area, collision_mask = "water-tile" }) > 0 then return false end
    local sp = ref.o.kind and T.outposts[ref.o.kind]
    if sp and sp.resource then
      local n = surface.count_entities_filtered({ area = { { cx - r, cy - r }, { cx + r, cy + r } }, name = sp.resource })
      if n < Swap.MIN_ORE then return false end
    end
    -- lot FOREUSES-THERMIQUES (iii) : ce qui recouvre la 3 x 3 ; seules des paires du MEME avant-poste peuvent etre echangees (S.exchange)
    local l = lists_of(ref.o)
    local blockers = {}
    for _, x in ipairs(surface.find_entities_filtered({ area = area, collision_mask = "object-layer" })) do
      if x.valid and x ~= ref.drill and x.type ~= "tree" and x.type ~= "simple-entity" then
        local u = x.unit_number
        if u and x.name == T.DRILL and l.d[u] then
          blockers[#blockers + 1] = { kind = "drill", id = u }
        elseif u and l.s[u] then
          blockers[#blockers + 1] = { kind = "sink", id = u }
        else
          return false
        end
      end
    end
    if #blockers == 0 then return true end
    local info = info_of(ref.o, l)
    local plan = S.exchange(blockers, info, info.sink_of[ref.drill.unit_number], ref.drill.unit_number)
    if not plan then return false end
    -- B1 : relecture au moteur des fours a retirer : aucune electrique (de l'avant-poste ou d'ailleurs : bandes du champ) n'y depose
    for _, su in ipairs(plan.sinks) do
      if fed_by_electric(surface, l.s[su], ref.drill) then return false end
    end
    plan.ents = {}
    for _, du in ipairs(plan.drills) do plan.ents[#plan.ents + 1] = l.d[du] end
    for _, su in ipairs(plan.sinks) do plan.ents[#plan.ents + 1] = l.s[su] end
    return plan
  end
end

--- Lot FOREUSES-THERMIQUES (iii) : retire les paires de l'echange `plan` (entites encore valides), contenus et objets au stock ; rend la
--- liste de ce qu'il faut reposer si l'electrique ne passe pas (undo), et les objets rendus. L'ancienne n'est plus « possedee » AVANT
--- d'etre retiree (on_entity_destroyed ne compte pas une perte d'avant-poste ; la reconstruction ne la refait pas).
local INVS = { furnace = { "furnace_source", "furnace_result", "fuel" }, container = { "chest" } }
local function exchange_remove(f, plan)
  local undo, got = {}, {}
  for _, e in ipairs(plan.ents or {}) do
    if e and e.valid then
      undo[#undo + 1] = { name = e.name, x = e.position.x, y = e.position.y, dir = e.direction, kind = e.name == T.DRILL and "drill" or "sink" }
      local names = e.name == T.DRILL and { "fuel" } or (INVS[e.type] or {})
      for _, iname in ipairs(names) do
        local inv = e.get_inventory(defines.inventory[iname])
        if inv then
          local cnt = inv.get_contents()
          for _, n in ipairs(sorted_keys(cnt)) do
            Stock.insert(f, n, cnt[n])
            got[n] = (got[n] or 0) + cnt[n]
          end
        end
      end
      if e.unit_number then State.disown(e.unit_number) end
      Stock.insert(f, e.name, 1)
      got[e.name] = (got[e.name] or 0) + 1
      e.destroy()
    end
  end
  return undo, got
end

--- Repose ce que `exchange_remove` a retire (l'electrique n'a pas pu etre posee) ; objets repris au stock, contenus non (ils y restent).
--- Revue du lead (7/11, (2)) : place verifiee avant la pose (F70) ; une piece reposee reprend la case d'une retiree dans sa liste, sinon
--- compact la comptait perdue et le compte de foreuses tombait (outposts.lua : avant-poste vivant efface a 0). Ce qui ne se repose pas reste
--- au stock, et sa case morte est comptee perdue par compact.
local function exchange_undo(f, surface, o, undo)
  for _, u in ipairs(undo or {}) do
    if Stock.count(f, u.name) >= 1 and surface.can_place_entity({ name = u.name, position = { x = u.x, y = u.y }, direction = u.dir, force = f.force })
        and Stock.remove(f, u.name, 1) >= 1 then
      local e = surface.create_entity({ name = u.name, position = { x = u.x, y = u.y }, direction = u.dir, force = f.force })
      if e then
        State.own(e, f.id, u.kind, o.id)
        local list = u.kind == "drill" and o.drill_list or o.sinks
        local slot
        for i, x in ipairs(list) do if not x.valid then slot = i break end end
        list[slot or (#list + 1)] = e
      else
        Stock.insert(f, u.name, 1)
      end
    end
  end
end

--- Fin de passe : listes de l'avant-poste sans les entites retirees par un echange, compte de foreuses tenu.
local function compact(o)
  local kd, ks = {}, {}
  for _, d in ipairs(o.drill_list or {}) do if d.valid then kd[#kd + 1] = d end end
  for _, k in ipairs(o.sinks or {}) do if k.valid then ks[#ks + 1] = k end end
  local lost = #(o.drill_list or {}) - #kd
  o.drill_list, o.sinks = kd, ks
  o.drills = math.max(0, (o.drills or 0) - lost)
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
  log(string.format("[FO-FOREUSES-ETAT] %s min %d | remplacees %d (dont %d avec %d poteau(x) poses) | thermiques candidates %d, deja alimentees %d, a chaine %d | echanges %d (%d thermique(s) voisine(s) retiree(s)) | refus : %s | melange %d",
    f.key or "player", math.floor((tick - (f.started or 0)) / 3600), st.done or 0, st.chained or 0, st.poles or 0, n_burner or 0,
    n_ready or 0, n_chain or 0, st.exchanged or 0, st.ex_removed or 0, #w > 0 and table.concat(w, ", ") or "aucun", st.mixed or 0))
end

--- Lot TRANCHES : reference resolue d'une entree (l'avant-poste par son numero ; nil s'il a disparu entre deux tranches).
local function ref_of(f, pass, id)
  local r = pass.refs[id]
  local o = r and f.outposts[r.oid]
  if not o then return nil end
  return { o = o, index = r.index, drill = r.drill, key = r.key, sink_ent = r.sink_ent }
end

--- Tranche « plan » : S.plan sur le releve (lectures de place bornees par S.FIT_TRIES), refus retenus, etat de l'execution prepare.
local function plan_step(f, surface, book, pass)
  local st, t0 = f.swap, pass.t0
  local free = pass.free
  table.sort(pass.poles, function(a, b) return a.id < b.id end)
  if #pass.entries == 0 or #pass.poles == 0 then -- (lot GISEMENTS : st.ready relu par script/team/gisement.lua)
    st.ready = 0
    report(f, st, t0, 0, 0, #pass.entries)
    pass.phase = "fini"
    return 1
  end
  -- lot FOREUSES-THERMIQUES : le remplacement pose lui-meme sa chaine de poteaux depuis le poteau alimente le plus proche
  -- (bancs : f.team.chaine_off, interrupteur de ia1_remote.lua set_regle_chaine : comportement d'avant, temoin)
  local pole = not (f.team and f.team.chaine_off) and pole_choice(book, free) or nil
  local refs = {}
  for _, e in ipairs(pass.entries) do refs[e.id] = ref_of(f, pass, e.id) end
  -- réserve d'amorçage : avant-postes de combustible et leurs thermiques debout (relevé), thermiques gardées (pass.keep, relu à l'exécution)
  local keep, kd = reserve_keep(f)
  pass.keep = keep
  local reserve = {}
  for _, oid in ipairs(sorted_keys(pass.burners or {})) do reserve[oid] = { burners = pass.burners[oid], keep = keep } end
  if st.keep_said ~= keep and next(reserve) ~= nil then
    st.keep_said = keep
    log(string.format("[FO-FOREUSES-RESERVE] %s : %d thermique(s) gardee(s) par avant-poste de combustible (chaudiere %.0f kW, combustible %.0f kJ, thermique %s/s extraits, %s kW brules) a %.1f min",
      f.key or "player", keep, kd.boiler_kw or 0, kd.fuel_kj or 0, tostring(kd.drill_rate), tostring(kd.drill_kw), (t0 - (f.started or 0)) / 3600))
  end
  local ctx = { poles = pass.poles, electric = T.drill_electric, have = pass.have, obtainable = pass.obtainable, limit = T.swap.per_pass,
    pole = pole, free_for = pole and free_for(f, surface, pole) or nil, chain = P.pole_chain, chain_max = S.CHAIN_MAX,
    fits = fits_for(f, surface, refs), reserve = reserve }
  local out, n_ready, n_chain = S.plan(pass.entries, ctx)
  for _, rf in ipairs(ctx.refused or {}) do
    local ref = refs[rf.id]
    if ref then st.retry[ref.key] = t0 + Swap.RETRY end
    count(st, rf.why)
  end
  local by_pos = {}
  for _, p in ipairs(pass.poles) do by_pos[p.x .. ":" .. p.y] = p.ent end
  local item = T.DRILL_ELECTRIC
  pass.out, pass.k, pass.n_ready, pass.n_chain, pass.by_pos = out, 1, n_ready, n_chain, by_pos
  pass.pole = pole and { name = pole.name, supply = pole.supply, wire = pole.wire } or nil
  pass.pole_free = { n = pole and free and free[pole.name] or 0 } -- (3) : stock libre des poteaux, debite chaine par chaine
  pass.made, pass.kw_new, pass.need_poles, pass.touched = 0, 0, 0, {}
  pass.kw = (game.entity_prototypes[item].energy_usage or 0) * Swap.JTICK_KW
  pass.pc = power_of(f)
  pass.phase = "remplacer"
  return Swap.PLAN_COST + #pass.entries
end

--- Tranche « remplacer » : UNE entree du plan (chaine de poteaux, echange, pose de l'electrique). Rend le cout.
local function exec_step(f, surface, pass)
  local st, t0 = f.swap, pass.t0
  local r = pass.out[pass.k]
  pass.k = pass.k + 1
  if not r then
    pass.phase = "fini"
    return 1
  end
  local pole, pole_free, by_pos = pass.pole, pass.pole_free, pass.by_pos
  local pset = plan_pole_tiles(f)
  local function mine(p) return team_pole(f, p, pset) end -- (4) : poteaux de l'equipe (fils du poteau neuf)
  local ref = ref_of(f, pass, r.id)
  if ref and stale_plan(surface, ref, r.exchange) then
    count(st, "plan perime")
    ref = nil
  end
  if not ref then return Swap.EXEC_COST end
  local pc = pass.pc
  if pc and not S.power_ok({ capacity = pc.capacity, used = pc.used + pass.kw_new, committed = pc.committed }, pass.kw, 0.6) then
    count(st, "courant")
    pass.k = #pass.out + 1 -- comme le « break » de la passe d'un bloc : plus aucun remplacement dans cette passe
    return 1
  end
  -- réserve d'amorçage relue au moteur : le monde change entre deux tranches (une thermique détruite depuis le plan)
  if fuel_outpost(ref.o) then
    if pass.keep == nil then pass.keep = (reserve_keep(f)) end -- (passe d'une version d'avant, déjà au remplacement)
    local live = 0
    for _, d in ipairs(ref.o.drill_list or {}) do if d.valid and d.name == T.DRILL then live = live + 1 end end
    if not S.reserve_ok(live, pass.keep, 1 + ((r.exchange and r.exchange.drills) and #r.exchange.drills or 0)) then
      count(st, "reserve charbon")
      return Swap.EXEC_COST
    end
  end
  local placed_n = #(r.poles or {})
  local prep
  local undo
  local ex = r.exchange
  if placed_n > 0 then pass.need_poles = pass.need_poles + placed_n end
  if placed_n > 0 or (ex and ex.ents and #ex.ents > 0) then
    prep = function()
      if placed_n > 0 then
        local src = r.source and (r.source.ent or by_pos[r.source.x .. ":" .. r.source.y])
        local ok, why, placed = place_chain(f, surface, pole, r.poles, src, pole_free, mine)
        -- poteaux de l'avant-poste (o.swap_poles) : comptes NOTRES par le plan du champ (mine_of, script/team/champ.lua) avec le lot
        -- CHAMP-COUVERTURE R7 (champ3, b8929f90) ; sans ce lot, personne ne les lit (revue du lead (1), 7/11)
        if ok and placed then
          ref.o.swap_poles = ref.o.swap_poles or {}
          st.pole_pos = st.pole_pos or {}
          for _, e in ipairs(placed) do
            ref.o.swap_poles[#ref.o.swap_poles + 1] = e
            -- revue du lead (7/11, (5)) : poteau de l'equipe au registre (State.own), et sa tuile retenue : un poteau refait par la
            -- reconstruction (numero neuf, non enregistre) reste reconnu comme une source de l'equipe (releve, revue (4))
            State.own(e, f.id, "pole", ref.o.id)
            st.pole_pos[P.tkey(math.floor(e.position.x), math.floor(e.position.y))] = true
          end
        end
        if not ok then
          count(st, why)
          if why ~= "poteaux au stock" then st.retry[ref.key] = t0 + Swap.RETRY end
          return false
        end
      end
      -- (iii) courant amene (chaine posee et reliee, ou foreuse deja couverte) : les paires qui bloquent la 3 x 3 sont retirees
      if ex and ex.ents and #ex.ents > 0 then
        local got
        undo, got = exchange_remove(f, ex)
        pass.touched[ref.o.id] = true
        st.exchanged = (st.exchanged or 0) + 1
        st.ex_removed = (st.ex_removed or 0) + #ex.drills
        local items = {}
        for _, n in ipairs(sorted_keys(got)) do items[#items + 1] = got[n] .. " " .. n end
        log(string.format("[FO-FOREUSES-ECHANGE] %s : electrique en (%.1f, %.1f) direction %d : %d thermique(s) voisine(s) et %d recepteur(s) retire(s) de l'avant-poste %d (1 electrique pour %d thermiques), repris au stock : %s a %.1f min",
          f.key or "player", r.cx, r.cy, r.dir or -1, #ex.drills, #ex.sinks, ref.o.id, 1 + #ex.drills, #items > 0 and table.concat(items, ", ") or "rien",
          (t0 - (f.started or 0)) / 3600))
      end
      return true
    end
  end
  local done_swap = swap_one(f, surface, ref, r.cx, r.cy, t0, prep, r.dir)
  pass.touched[ref.o.id] = true -- (2) : listes compactees aussi apres un remplacement rate (ancienne qui ne se repose pas)
  if not done_swap and undo then
    exchange_undo(f, surface, ref.o, undo)
    count(st, "echange repris")
  end
  if done_swap then
    pass.made = pass.made + 1
    pass.kw_new = pass.kw_new + pass.kw
    if placed_n > 0 then
      st.chained = (st.chained or 0) + 1
      st.poles = (st.poles or 0) + placed_n
      if st.chained <= Swap.LOGS then
        log(string.format("[FO-FOREUSES] %s : electrique en (%.1f, %.1f) avec %d %s pose(s) depuis le reseau en (%.1f, %.1f) a %.1f min (%d avec chaine)",
          f.key or "player", r.cx, r.cy, placed_n, pole.name, r.source.x, r.source.y, (t0 - (f.started or 0)) / 3600, st.chained))
      end
    end
  end
  return Swap.EXEC_COST + 10 * placed_n
end

--- Tranche « fin » : listes compactees, fabrication d'avance, bilan.
local function finish_step(f, book, pass)
  local st, t0, free = f.swap, pass.t0, pass.free
  for _, oid in ipairs(sorted_keys(pass.touched or {})) do
    local o = f.outposts[oid]
    if o then compact(o) end
  end
  if pass.out then
    local have, pole = pass.have, pass.pole
    st.ready = pass.n_ready
    craft(f, book, free, S.demand(pass.n_ready + pass.n_chain, have - pass.made, T.swap.craft_cap), t0)
    if pole and pass.n_chain > 0 then
      local want = math.min(Swap.POLE_CAP, math.max(pass.need_poles, S.CHAIN_MAX)) - (free and free[pole.name] or 0)
      if want > 0 then craft(f, book, free, want, t0, pole.name) end
    end
    report(f, st, t0, pass.n_ready, pass.n_chain, #pass.entries)
  end
  return pass.made or 0
end

--- Lot TRANCHES (lead, 7/11 : tt:foswap jusqu'a 125 ms d'un bloc) : la passe se joue par tranches d'au plus Swap.SLICE unites de travail
--- (une foreuse relevee = 1, une recherche de poteaux d'un avant-poste = Swap.POLE_COST, le plan = Swap.PLAN_COST + entrees, un
--- remplacement = Swap.EXEC_COST + 10 par poteau). L'etat de la passe est dans global (f.swap.pass : nombres, tables, entites ; aucune
--- fonction) ; la suite est jouee au tick suivant par la minuterie Swap.TIMER. Toutes les decisions lisent pass.t0 (tick de depart) et
--- la copie du stock libre prise au depart : sur un monde inchange, une passe en tranches decide EXACTEMENT comme d'un bloc
--- (tests/foreuse_tranches_test.lua : global et journal compares). Swap.SLICED = false : la passe d'un bloc (ancien comportement).
Swap.SLICED = true
Swap.SLICE = 240
Swap.POLE_COST = 20
Swap.PLAN_COST = 60
Swap.EXEC_COST = 60
Swap.TIMER = "fo-foreuses-tranche"
Swap.book_of = nil -- livre de recettes de l'equipe (script/team/team.lua, book_for) : pour les tranches jouees hors de la pensee
Swap.slices = 0 -- tranches jouees (compte pour les bancs et les tests ; hors de global)
Swap.PASS_MAX = 3600 -- une passe qui n'a pas fini en 1 min (minuterie perdue) est abandonnee : la suivante repart du releve

--- Joue des tranches jusqu'au budget ; rend le nombre d'electriques posees si la passe finit, 0 sinon (la suite est programmee).
local function run_pass(f, surface, book, pass)
  local budget = Swap.SLICED and Swap.SLICE or math.huge
  local used = 0
  Swap.slices = Swap.slices + 1
  while true do
    local cost, done = 0, false
    -- une tranche entamee ne commence pas un plan ou un remplacement qui la ferait deborder (chaque tranche : au plus max(SLICE, une unite))
    local est = (pass.phase == "plan" and Swap.PLAN_COST + #pass.entries) or (pass.phase == "remplacer" and Swap.EXEC_COST) or 0
    if used > 0 and used + est > budget then
      Scheduler.after(1, Swap.TIMER, { fid = f.id })
      return 0
    end
    if pass.phase == "releve" then
      local c, fin = survey_step(f, surface, pass, budget - used)
      cost = c
      if fin then pass.phase = "plan" end
    elseif pass.phase == "plan" then
      cost = plan_step(f, surface, book, pass)
    elseif pass.phase == "remplacer" then
      cost = exec_step(f, surface, pass)
    else
      done = true
    end
    if done then
      f.swap.pass = nil
      return finish_step(f, book, pass)
    end
    used = used + cost
    if used >= budget then
      Scheduler.after(1, Swap.TIMER, { fid = f.id })
      return 0
    end
  end
end

--- Suite d'une passe en tranches (minuterie) : l'equipe et son QG doivent exister, sinon la passe est abandonnee.
Scheduler.define_timer(Swap.TIMER, function(p)
  local f = p and State.faction(p.fid)
  local pass = f and f.swap and f.swap.pass
  if not pass then return end
  local book = Swap.book_of and Swap.book_of(f)
  if not (f.hq and f.hq.valid and f.outposts and book) then
    f.swap.pass = nil
    log(string.format("[FO-FOREUSES] %s : passe du tick %d abandonnee (equipe, QG ou livre de recettes disparu)", tostring(f.key or "player"), pass.t0))
    return
  end
  -- (banc foreuses-dense du 7/11 : la portée tt:foswap de la pensée ne voyait que la PREMIÈRE tranche ; les suivantes, ici)
  Profiler.fstart("tt:foswap-tranche")
  run_pass(f, f.hq.surface, book, pass)
  Profiler.fstop("tt:foswap-tranche")
end)

--- Une pensee d'equipe : releve, remplacements, fabrication d'avance. `free` : stock libre ({ [objet] = n }) de la pensee.
function Swap.think(f, surface, book, free, tick)
  if not (f and f.outposts and f.hq and f.hq.valid and next(f.outposts)) then return 0 end
  local st = f.swap
  if not st then
    st = { next = 0, done = 0, failed = 0, retry = {} }
    f.swap = st
  end
  if st.pass then
    if tick - st.pass.t0 < Swap.PASS_MAX then return 0 end -- une passe en tranches est en cours : sa minuterie la joue
    log(string.format("[FO-FOREUSES] %s : passe du tick %d sans fin apres %d ticks : abandonnee", tostring(f.key or "player"), st.pass.t0, tick - st.pass.t0))
    st.pass = nil
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
  local fr = {}
  for _, k in ipairs(sorted_keys(free or {})) do fr[k] = free[k] end
  local pass = { t0 = tick, phase = "releve", oids = sorted_keys(f.outposts), oi = 1, di = 1, any = false, entries = {}, refs = {}, poles = {},
    seen = {}, nets = {}, have = have, obtainable = obtainable, free = fr, burners = {} }
  st.pass = pass
  return run_pass(f, surface, book, pass)
end

return Swap
