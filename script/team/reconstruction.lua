--[[
  Lot RECONSTRUIRE (reconstruction issue du lot COUVERTURE) : une pièce de l'équipe détruite est REFAITE, avant que l'équipe n'améliore quoi que
  ce soit (constat du DC, 28/10 : « un endroit détruit n'a pas été remplacé alors que ça prend deux secondes et qu'ils ont
  toutes les ressources », « le labo de recherche attaqué n'est pas réparé »). Règles pures : shared/team/reconstruction.lua.

  Pourquoi un registre et pas les fantômes du moteur : le fantôme laissé par une pièce détruite dépend du temps de vie des
  fantômes de la force (LuaForce.ghost_time_to_live, 0 par défaut = jamais effacé, mais le moteur n'en laisse que si le
  prototype le prévoit et ne les rend pas aux PNJ), et le ravivage par un PNJ est celui du plan directeur (script/team/build.lua),
  dont les projets finis ne reprennent plus leurs pièces. Le registre garde l'essentiel d'une pièce (nom, place, direction,
  recette, objet qui la pose), lu au moment de sa mort : refaire ne dépend de rien d'autre.

  Quelles pièces : celles que l'ÉQUIPE a posées, et seulement elles :
    - les pièces d'un projet du plan directeur (f.build.projects[].ents : laboratoire, assembleur, four, tapis, poteau…),
      reconnues à leur place ;
    - les foreuses et réceptacles d'un avant-poste encore vivant (registre des propriétaires, State.owner : « drill », « sink »).
  Les tourelles se refont par « défendre d'abord » (Outposts.fortify, positions par couverture) ; ce que le joueur a posé à la
  main n'est jamais refait par ses PNJ.
  Lot REBUILD-AVANT-POSTE : un avant-poste perdu en entier (dernière foreuse détruite) n'est plus jeté avec ses pièces : sa RUINE
  (script/team/ruines.lua) les garde, la première foreuse reposée recrée l'avant-poste, une foreuse électrique sans objet est remplacée
  par la foreuse à combustion (le lot FOREUSES la repasse en électrique), la pose attend qu'aucun ennemi (unité, nid, ver) ne soit près.

  Un lot par voyage : la pièce la plus précieuse et ses voisines à Rc.BATCH_RADIUS tuiles (tâche « rebuild », priorité de 70 à 86,
  sous l'urgence). Le PNJ prend les objets au stock (liste stricte du tableau), va sur place, pose. Pas de pose tant que des
  ennemis sont près de la place (la pièce est différée, puis abandonnée après trop de reports).
  « Améliorer attend » : Reconstruction.hold_upgrades(f) est vrai tant qu'une pièce refaisable attend (Ia3.capital_pay).
  INFRASTRUCTURE ÉLECTRIQUE (R.INFRA_TYPES) : refaite même posée à la main (pas les coffres), d'abord et avec une patience courte ;
  la valeur d'un poteau est le nombre de consommateurs coupés près de lui (état « sans courant » lu au moteur).
  Déterminisme : listes triées, aucun temps mesuré. État : f.recon (tables simples, dans la sauvegarde).
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local Board = require("script.team.board")
local Stock = require("script.team.stock")
local R = require("shared.ai3.reglages")
local Rc = require("shared.team.reconstruction")
local Protos = require("script.team.protos")
local Harvest = require("script.team.harvest") -- lot CORR-RECONSTRUIRE : le bois se coupe sur les arbres
local Sweep = require("script.team.rebuild_sweep") -- lot REBUILD-TOUT : relevé des pièces posées des projets du plan directeur
local Ruines = require("script.team.ruines") -- lot REBUILD-AVANT-POSTE : un avant-poste perdu en entier garde son plan, recréé à la première foreuse
local Ru = require("shared.team.ruines")
local T = require("shared.team.config")

local Recon = {}

Recon.MAX_OPEN = 3          -- tâches « rebuild » au tableau en même temps
Recon.SAFE_RADIUS = 28      -- tuiles : pas de pose si des unités ennemies sont plus près de la place
Recon.RETRY = 600           -- 10 s : report quand des ennemis sont près de la place
Recon.SEEDS_PER_THINK = 3   -- places essayées (épreuve « ennemis près ») par pensée
Recon.MATCH = 0.3           -- tolérance de position (tuiles) pour reconnaître une pièce d'un projet
Recon.LOGS = 60
Recon.DIAG_LOGS = 20        -- lignes « pose impossible » (diagnostic) par force
-- Lot CORR-RECONSTRUIRE : un poteau perdu dont aucun remplaçant n'est fabricable (bois et acier absents) fait COUPER le bois
-- (tâche de minage sur les arbres, Rc.pick_gather) au lieu d'attendre 32 min. Faux : l'ancien comportement (mutant des tests
-- et « sans la règle » du banc reconstruire-bois, réglé par l'interface fo-recon).
Recon.GATHER = true

local ITEM_OF = {}          -- mémoire LOCALE (prototypes seulement)
local function item_of(name)
  local it = ITEM_OF[name]
  if it == nil then
    local p = game.entity_prototypes[name]
    local list = p and p.items_to_place_this
    it = (list and list[1] and list[1].name) or false
    ITEM_OF[name] = it
  end
  return it or nil
end

function Recon.state(f)
  if not f.recon then f.recon = Rc.new() end
  local s = f.recon
  s.lost, s.hist = s.lost or {}, s.hist or {} -- sauvegarde d'une version d'essai sans l'un des deux : jamais d'erreur à l'indexation
  s.stats = s.stats or { recorded = 0, rebuilt = 0, blocked = 0, deferred = 0, tasks = 0, discarded = 0, logs = 0 }
  return s
end

local function stat(s, k, n) s.stats[k] = (s.stats[k] or 0) + (n or 1) end

--- Releves par nom de piece (mesure, aucun effet sur le jeu) : destruites, refaites par l'equipe (delai en ticks), refaites par
--- un autre moyen (plan directeur, joueur) vues a la tache ou au balayage de Recon.think.
local function by_name(s, name)
  s.stats.byname = s.stats.byname or {}
  local b = s.stats.byname[name]
  if not b then
    b = { rec = 0, own = 0, own_sum = 0, own_max = 0, ext = 0, ext_sum = 0, ext_max = 0 }
    s.stats.byname[name] = b
  end
  return b
end
local function delay_note(s, r, kind, tick)
  if r.counted then return end
  r.counted = true
  local d = math.max(0, tick - r.tick)
  local b = by_name(s, r.name)
  b[kind] = b[kind] + 1
  b[kind .. "_sum"] = b[kind .. "_sum"] + d
  if d > b[kind .. "_max"] then b[kind .. "_max"] = d end
end

local function team_of(force_name)
  if force_name == "player" then return State.faction("player") end
  return State.by_force(force_name)
end

--- La pièce morte appartient-elle à un projet du plan directeur de l'équipe ?
local function in_project(f, pos)
  local b = f.build
  if not b then return false end
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    if p then
      for _, e in ipairs(p.ents) do
        if math.abs(e.x - pos.x) <= Recon.MATCH and math.abs(e.y - pos.y) <= Recon.MATCH then return true end
      end
    end
  end
  return false
end

--- Pièce détruite (événement on_entity_died) : menace pour la couverture ; inscrite au registre si l'équipe l'avait posée.
local function on_died(e)
  local ent = e.entity
  if not (ent and ent.valid) then return end
  local role = R.ENTITY_ROLE[ent.type]
  if not role or role == "main" then return end
  local f = team_of(ent.force.name)
  if not (f and not f.eliminated and f.hq and f.hq.valid) then return end
  if not f.is_player and not R.RECON_FACTIONS then return end
  local s = Recon.state(f)
  local pos = ent.position
  local infra = R.INFRA_TYPES[ent.type] or false
  local value = infra and (ent.type == "electric-pole" and Rc.pole_value(0) or Rc.INFRA_VALUE) or Rc.role_value(role)
  if value <= 0 then return end
  if not infra and not R.RECON_ALL_PIECES then return end -- portée : infrastructure électrique seule par défaut
  local kind, oid
  local owner = ent.unit_number and State.owner(ent.unit_number)
  if infra then
    kind = nil -- l'infrastructure est refaite où qu'elle soit (avant-poste, centrale du joueur…)
  elseif owner then
    if owner.f ~= f.id or (owner.kind ~= "drill" and owner.kind ~= "sink") then return end
    kind, oid = owner.kind, owner.oid
  elseif not in_project(f, pos) then
    return
  elseif R.REBUILD_SWEEP then
    return -- lot REBUILD-TOUT : une pièce d'un projet du plan est refaite par le relevé (script/team/rebuild_sweep.lua), pas par le registre
  end
  local recipe
  if ent.type == "assembling-machine" then
    local ok, r = pcall(function() local x = ent.get_recipe() return x and x.name end)
    recipe = ok and r or nil
  end
  local reach
  if ent.type == "electric-pole" then
    -- Plus grande distance aux poteaux voisins qui restent : le remplaçant éventuel doit avoir le fil pour les rejoindre.
    local ok, nb = pcall(function() return ent.neighbours end)
    reach = 0
    if ok and type(nb) == "table" and nb.copper then
      for _, n in ipairs(nb.copper) do
        if n.valid then
          local d = math.sqrt((n.position.x - pos.x) ^ 2 + (n.position.y - pos.y) ^ 2)
          if d > reach then reach = d end
        end
      end
    end
  end
  local k = Rc.record(s, { name = ent.name, x = pos.x, y = pos.y, dir = ent.direction, item = item_of(ent.name), recipe = recipe,
    value = value, kind = kind, oid = oid, infra = infra or nil }, e.tick)
  if reach and s.lost[k] then s.lost[k].reach = reach; s.lost[k].etype = ent.type end
  stat(s, "recorded")
  by_name(s, ent.name).rec = by_name(s, ent.name).rec + 1
  if s.stats.logs < Recon.LOGS then
    s.stats.logs = s.stats.logs + 1
    log(string.format("[FO-RECON] %s : %s detruit en (%.1f, %.1f) a %.1f min, a refaire (valeur %d, %d en attente)", f.key or "player",
      ent.name, pos.x, pos.y, (e.tick - (f.started or 0)) / 3600, value, Rc.pending(s)))
  end
end
Events.on(defines.events.on_entity_died, on_died)

--- Lot REBUILD-TOUT : ce que le joueur (ou ses robots) retire À LA MAIN n'est pas refait par ses PNJ (mémoire du relevé).
local function on_hand_removed(e)
  local ent = e.entity
  if not (ent and ent.valid) then return end
  local f = State.faction("player")
  if f and f.build and ent.force.name == f.force then Sweep.note_hand(f, ent, e.tick or game.tick) end
end
Events.on(defines.events.on_player_mined_entity, on_hand_removed)
Events.on(defines.events.on_robot_mined_entity, on_hand_removed)

--- Y a-t-il des pièces refaisables en attente ? (« améliorer attend » : Ia3.capital_pay)
--- Lot SANS-GEL : les projets du plan directeur rouverts ne retiennent plus les améliorations dans le temps (gel de D4 supprimé, arbitrage du
--- DC « Supprimer le gel ») ; ils ne retiennent que leur MATIÈRE, par Recon.upgrade_stock.
function Recon.hold_upgrades(f)
  local s = f.recon
  if not s then return false end
  return Rc.hold_upgrades(s, function(item) return Stock.count(f, item) end, game.tick)
end

--- Lot SANS-GEL : stock sur lequel Capital.pay paie une amélioration (script/team/team.lua) : `stock` moins ce que la reconstruction des
--- projets rouverts prendra encore au coffre (Sweep.upgrade_stock : « refaire d'abord » à matière égale, sans durée). Rien à payer
--- (plan.ia3.pay vide) : `stock` tel quel, sans calcul.
function Recon.upgrade_stock(f, book, stock, tick, plan)
  local pay = plan and plan.ia3 and plan.ia3.pay
  if not pay or #pay == 0 then return stock end
  local c = f.team and f.team.capital
  -- Relecture SANS-GEL : le journal [FO-REBUILD-PRIO] ne cite l'amélioration décidée que si Capital.pay la paierait (une cible de
  -- plan.ia3.pay porte sa clé, comme la boucle de Capital.pay) ; sinon ce n'est pas la reconstruction qui la fait attendre.
  local cur = c and c.current
  local due = false
  if cur and cur.key then
    for _, p in ipairs(pay) do if p.target == cur.key then due = true break end end
  end
  return Sweep.upgrade_stock(f, stock, book, tick, due and cur or nil)
end

function Recon.pending(f) return f.recon and Rc.pending(f.recon) or 0 end

--- Valeur des poteaux perdus : les consommateurs de la force « sans courant » près de lui (au plus 8 poteaux par pensée, une fois
--- par seconde chacun). Un poteau qui ne coupe rien (doublon) vaut Rc.POLE_BASE ; un poteau qui coupe une ligne vaut jusqu'à Rc.POLE_CAP.
Recon.CUT_RADIUS = 40
local function refresh_poles(f, s, surface, tick)
  local n = 0
  for _, k in ipairs(State.sorted_keys(s.lost)) do
    local r = s.lost[k]
    if r.infra and r.name and not r.abandoned and (r.vtick or -999) + ((r.nread or 0) < 3 and 60 or 300) <= tick and n < 8 and Rc.is_pole_value(r) then
      n = n + 1
      r.vtick = tick
      r.nread = (r.nread or 0) + 1 -- trois relevés par seconde, puis un toutes les 5 s : une pièce qui attend ses matériaux ne coûte presque rien
      local cut = 0
      for _, c in ipairs(surface.find_entities_filtered({ force = f.force, type = R.CONSUMER_TYPES,
          area = { { r.x - Recon.CUT_RADIUS, r.y - Recon.CUT_RADIUS }, { r.x + Recon.CUT_RADIUS, r.y + Recon.CUT_RADIUS } } })) do
        if c.valid and c.status == defines.entity_status.no_power then cut = cut + 1 end
      end
      r.cut = cut
      r.value = Rc.pole_value(cut)
    end
  end
end

--- Lot REBUILD-AVANT-POSTE : une foreuse ÉLECTRIQUE perdue dont l'objet n'est pas au stock (et qui n'est fabriquée d'avance par personne) ne
--- doit pas laisser le champ muet : elle est remplacée par la foreuse à COMBUSTION du stock, posée pour que son dépôt tombe dans le MÊME
--- réceptacle (Ru.burner_center, miroir de la règle du lot FOREUSES) ; le lot FOREUSES la repasse en électrique dès que l'objet et le courant
--- sont là. Même patron que le poteau de remplacement (substitute_poles) : r.place / r.item, plus la place r.px, r.py.
Recon.SUBST_PER_THINK = 4
local function tile_size(name)
  local p = game.entity_prototypes[name]
  return (p and p.tile_width) or 1, (p and p.tile_height) or 1
end

--- Boîtes des réceptacles de l'avant-poste `oid` : ceux du registre (détruits) et ceux qui restent sur la carte.
local function sink_boxes(f, s, surface, r, spec)
  local boxes = {}
  for _, k in ipairs(State.sorted_keys(s.lost)) do
    local q = s.lost[k]
    if q.kind == "sink" and q.oid == r.oid then
      local w, h = tile_size(q.name)
      boxes[#boxes + 1] = { x = q.x, y = q.y, w = w, h = h }
    end
  end
  for _, e in ipairs(surface.find_entities_filtered({ position = { x = r.x, y = r.y }, radius = 4, name = spec.sink, force = f.force })) do
    if e.valid then
      local w, h = tile_size(e.name)
      boxes[#boxes + 1] = { x = e.position.x, y = e.position.y, w = w, h = h }
    end
  end
  table.sort(boxes, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  return boxes
end

--- Lot REBUILD-AVANT-POSTE (relecture) : un réceptacle ne se pose que dans un avant-poste qui a une foreuse vivante ou dont une foreuse
--- DUE a son objet au stock (Recon.act pose les foreuses d'abord). Sinon la tâche partirait, ne poserait rien et serait redonnée à
--- chaque pensée : des voyages pour rien pendant toute la vie de la ruine. `due` : pièces dues de la pensée.
local function sink_waits(f, r, due)
  if r.kind ~= "sink" then return false end
  local host = f.outposts and f.outposts[r.oid]
  if host and (host.drills or 0) > 0 then return false end
  for _, d in ipairs(due) do
    if d.kind == "drill" and d.oid == r.oid and d.item and Stock.count(f, d.item) >= 1 then return false end
  end
  return true
end

local function substitute_drills(f, s, surface, tick)
  local burner_item = item_of(T.DRILL)
  if not burner_item then return 0 end
  local n = 0
  for _, k in ipairs(State.sorted_keys(s.lost)) do
    local r = s.lost[k]
    if n < Recon.SUBST_PER_THINK and r.kind == "drill" and r.name == T.DRILL_ELECTRIC and not r.place and not r.abandoned and not r.claimed
      and not r.subst_fail and r.item and tick - r.tick >= Rc.calm_for(r)
      and Stock.count(f, r.item) < 1 and Stock.count(f, burner_item) >= 1 then
      n = n + 1
      local host = (f.outposts and f.outposts[r.oid]) or (s.ruins and s.ruins[r.oid])
      local spec = host and T.outposts[host.kind]
      local bx, by
      if spec then
        local sink = Ru.sink_of(r.x, r.y, r.dir, T.drill_electric.drop, sink_boxes(f, s, surface, r, spec))
        if sink then bx, by = Ru.burner_center(r.x, r.y, r.dir, sink, { size = (tile_size(T.DRILL)), drop = T.drill_drop }, T.drill_electric.size) end
      end
      if bx then
        r.place, r.item, r.px, r.py = T.DRILL, burner_item, bx, by
        stat(s, "drill_substituted")
        if s.stats.logs < Recon.LOGS then
          s.stats.logs = s.stats.logs + 1
          log(string.format("[FO-RECON] %s : foreuse electrique perdue en (%.1f, %.1f) sans objet au stock : foreuse a combustion posee a sa place en (%.1f, %.1f)",
            f.key or "player", r.x, r.y, bx, by))
        end
      else
        r.subst_fail = true -- réceptacle introuvable ou géométrie impossible : pas de nouvel essai, la pièce attend son objet
      end
    end
  end
  return n
end

--- Une pensée de l'équipe : tâches de reconstruction au tableau (après Board.sync, comme le plan directeur).
function Recon.think(f, surface, tick)
  Sweep.step(f, surface, tick) -- lot REBUILD-TOUT : relevé par tranches des pièces posées des projets (horloge propre)
  local s = f.recon
  if not s then return 0 end
  s.lost, s.hist = s.lost or {}, s.hist or {} -- registre d'une version d'essai : jamais d'erreur à l'indexation
  -- Fin de vie du registre (une fois par minute) : AVANT les sorties anticipées, sinon la mémoire des destructions (hist) d'un registre
  -- vide ou d'une équipe au tableau plein de tâches « rebuild » ne serait jamais élaguée (sauvegarde qui grossit).
  if Rc.prune_due(s, tick) then Rc.prune(s, tick) end
  Ruines.step(f, s, tick) -- lot REBUILD-AVANT-POSTE : verdict de chaque ruine (refaite, expirée, remplacée, sans pièce, site pris)
  if next(s.lost) == nil then return 0 end
  -- Mesure seule : une pièce perdue revue en place (refaite par le plan directeur, le joueur…) est datée, mais reste au registre.
  if tick >= (s.scan_at or 0) then
    s.scan_at = tick + 600
    local seen = 0
    for _, k in ipairs(State.sorted_keys(s.lost)) do
      local r = s.lost[k]
      if not r.counted and seen < 80 then
        seen = seen + 1
        local there = surface.find_entity(r.name, { r.x, r.y })
        if there and there.valid and there.force.name == f.force then
          delay_note(s, r, "ext", tick)
          -- revue globale 1 : la pièce refaite par un autre moyen (plan directeur, réseau vivant, joueur) sort du registre ; restée
          -- inscrite, elle faisait fabriquer des pièces de rechange (Rc.demand) et envoyer un PNJ pour rien jusqu'à l'oubli à 90 min
          if not r.claimed then Rc.done(s, k) end
        end
      end
    end
  end
  local b = Board.get(f)
  -- Libère les pièces dont la tâche n'existe plus ou n'a plus d'ouvrier (PNJ mort en route).
  local open = 0
  for _, k in ipairs(State.sorted_keys(s.lost)) do
    local r = s.lost[k]
    if r.claimed then
      local t = b.tasks[r.claimed]
      if not (t and t.worker) then r.claimed = nil end
    end
    -- Avant-poste disparu : une foreuse ou un réceptacle seul ne se refait pas, SAUF si sa ruine garde le plan (lot REBUILD-AVANT-POSTE :
    -- la première foreuse reposée recrée l'avant-poste).
    if r.kind and not (f.outposts and f.outposts[r.oid]) and not Ruines.keeps(s, r.oid) then
      Rc.done(s, k)
      stat(s, "discarded")
    end
  end
  for _, key in ipairs(State.sorted_keys(b.tasks)) do
    if b.tasks[key].kind == "rebuild" then open = open + 1 end
  end
  if open >= Recon.MAX_OPEN then return 0 end
  refresh_poles(f, s, surface, tick)
  substitute_drills(f, s, surface, tick)
  local due = Rc.due(s, tick)
  if #due == 0 then return 0 end
  local added, tried = {}, 0
  local have, taken = {}, {}
  for _, seed in ipairs(due) do
    if open + #added >= Recon.MAX_OPEN or tried >= Recon.SEEDS_PER_THINK then break end
    if sink_waits(f, seed, due) then
      -- réceptacle sans foreuse prête : ni place essayée ni tâche (il attend sa foreuse ou la fin de la ruine)
    elseif not taken[seed.key] and Stock.count(f, seed.item) < 1 then
      -- Mesure : pièce en attente faute d'objet au stock (elle ne consomme pas l'une des places essayées de la pensée).
      if not seed.nostock then
        seed.nostock = true
        by_name(s, seed.name).nostock = (by_name(s, seed.name).nostock or 0) + 1
      end
    elseif not taken[seed.key] then
    tried = tried + 1
    local near = surface.find_enemy_units({ x = seed.x, y = seed.y }, Recon.SAFE_RADIUS, f.force)
    -- Lot REBUILD-AVANT-POSTE : une pièce d'avant-poste de ressource attend aussi que nids et vers ne soient plus à portée (le champ est
    -- loin du QG, le PNJ y mourrait), et attend plus longtemps (priorité des ressources : on n'abandonne pas le champ au bout de 3 min).
    local foe = seed.kind and surface.find_nearest_enemy({ position = { x = seed.x, y = seed.y }, max_distance = Recon.SAFE_RADIUS, force = f.force })
    if #near > 0 or (foe and foe.valid) then
      Rc.defer(s, seed.key, tick + Recon.RETRY, tick, seed.kind and Ru.MAX_DEFERS or nil)
      stat(s, "deferred")
    else
      -- Le lot : les pièces voisines dont l'objet est au stock (compté pièce par pièce).
      local batch = {}
      local pool = {}
      for _, r in ipairs(due) do if not taken[r.key] then pool[#pool + 1] = r end end
      for _, r in ipairs(Rc.batch(s, pool, seed, Rc.BATCH_MAX, Rc.BATCH_RADIUS)) do
        local left = have[r.item]
        if left == nil then left = Stock.count(f, r.item) end
        if left >= 1 then
          have[r.item] = left - 1
          batch[#batch + 1] = r
        else
          have[r.item] = left
        end
      end
      -- réceptacles sans foreuse dans le lot (ni vivante, ni du lot) : retirés, ils attendent leur foreuse
      local drill_of = {}
      for _, r in ipairs(batch) do if r.kind == "drill" then drill_of[r.oid] = true end end
      local kept = {}
      for _, r in ipairs(batch) do
        local host = f.outposts and f.outposts[r.oid]
        if r.kind ~= "sink" or drill_of[r.oid] or (host and (host.drills or 0) > 0) then kept[#kept + 1] = r end
      end
      batch = kept
      if #batch > 0 then
        local keys = {}
        for _, r in ipairs(batch) do keys[#keys + 1] = r.key taken[r.key] = true end
        added[#added + 1] = { key = "rebuild:" .. batch[1].key, kind = "rebuild", prio = Rc.task_prio(batch[1].value),
          -- lot REBUILD-AVANT-POSTE : refaire un champ de foreuses est du travail d'EXTRACTION (pôle des gisements), pas de défense
          domain = batch[1].kind and "gisements" or "defense", work = 20 + 3 * #batch, items = Rc.items(batch), recs = keys,
          pos = { x = batch[1].x, y = batch[1].y } }
      end
    end
    end
  end
  if #added > 0 then
    local n = Board.add(f, added, tick)
    stat(s, "tasks", n)
    return n
  end
  return 0
end

--- Fabrication des objets d'INFRASTRUCTURE qui manquent au stock (poteaux, chaudières, machines à vapeur, pompes détruits) : une
--- tâche « craft » par objet, à la priorité de la reconstruction ; le livre de recettes de l'équipe dit si la fabrication à la main
--- est possible avec le stock libre (sinon rien : le manque reste lisible aux relevés « ns »). `free` : stock libre de la pensée.
local POLE_CANDS -- mémoire LOCALE (prototypes seulement) : les poteaux du jeu, { name, item, supply, wire }
local function pole_cands()
  if POLE_CANDS then return POLE_CANDS end
  POLE_CANDS = {}
  local names = Protos.names_of_type("electric-pole")
  for _, name in ipairs(names) do
    -- Lecture protégée : un prototype de poteau qui refuse l'un de ces attributs (moteur réel : « attempt to index … userdata »,
    -- planté à 42 min sur 987654321) est simplement écarté de la liste des remplaçants.
    local ok, it_name, supply, wire = pcall(function()
      local p = game.entity_prototypes[name]
      local list = p.items_to_place_this
      local it = list and list[1]
      if not it then return nil end
      return it.name, p.supply_area_distance or 0, p.max_wire_distance or 0
    end)
    if ok and it_name then
      POLE_CANDS[#POLE_CANDS + 1] = { name = name, item = it_name, supply = supply, wire = wire }
    elseif not ok then
      log("[FO-RECON] poteau " .. name .. " ecarte des remplacants : " .. tostring(it_name))
    end
  end
  local lst = {}
  for _, c in ipairs(POLE_CANDS) do lst[#lst + 1] = string.format("%s(%s, zone %.1f, fil %.1f)", c.name, c.item, c.supply, c.wire) end
  log("[FO-RECON] poteaux remplacants : " .. #POLE_CANDS .. " : " .. table.concat(lst, " ; "))
  return POLE_CANDS
end

--- L'objet de `item` est-il au stock libre ou fabricable à la main avec ce stock ?
local function available_or_craftable(book, free, item)
  if (free[item] or 0) >= 1 then return true end
  if not book:handcraftable(item) then return false end
  local avail = {}
  for _, k in ipairs(State.sorted_keys(free)) do avail[k] = free[k] end
  avail[item] = 0
  return next(book:plan({ { item, 1 } }, avail).raw) == nil
end

--- Matière brute qui manque pour fabriquer 1 `item` à la main avec le stock libre : { [objet] = n }, ou nil (non fabricable à la main).
local function missing_raw(book, free, item)
  if not book:handcraftable(item) then return nil end
  local avail = {}
  for _, k in ipairs(State.sorted_keys(free)) do avail[k] = free[k] end
  avail[item] = 0
  return book:plan({ { item, 1 } }, avail).raw
end

--- Une matière que seules des entités du monde donnent SANS gisement de minerai (le bois : arbres) ?
local function from_trees(item)
  local names = Harvest.names(item)
  return #names > 0 and not (#names == 1 and names[1] == item)
end

--- Lot CORR-RECONSTRUIRE : aucun poteau remplaçant n'est fabricable : tâche de minage de la matière récoltable qui manque (le bois),
--- sur les arbres, loin des nids (prudent). Une tâche par objet (clé stable).
function Recon.gather(f, s, book, free, r, tick)
  if not Recon.GATHER then return 0 end
  local c, list = Rc.pick_gather(pole_cands(), r.reach or 0, function(x) return missing_raw(book, free, x.item) end, from_trees)
  if not c then return 0 end
  local tasks = {}
  for _, u in ipairs(list) do
    tasks[#tasks + 1] = { key = "recon:gather:" .. u[1], kind = "mine", prio = Rc.task_prio(Rc.INFRA_VALUE), resource = u[1], count = u[2],
      trees = true, prudent = true, domain = "defense", tag = "reconstruction" }
  end
  -- Le tableau est resynchronisé à chaque pensée (les tâches libres non replanifiées disparaissent) : la tâche est rouverte tant que
  -- le besoin dure ; une tâche échouée (aucun arbre sûr à portée) est mise en pause par Board.finish (RETRY_TICKS).
  local n = Board.add(f, tasks, tick)
  s.gather_log = s.gather_log or {}
  local first = tasks[1] and tasks[1].resource
  if n > 0 and first and tick - (s.gather_log[first] or -math.huge) >= 3600 then
    s.gather_log[first] = tick
    stat(s, "gathers")
    if (s.stats.gather_logs or 0) < Recon.LOGS then
      s.stats.gather_logs = (s.stats.gather_logs or 0) + 1
      log(string.format("[FO-RECON] %s : aucun poteau fabricable pour remplacer %s : recolte de %s (%s) a %.1f min", f.key or "player", r.name,
        first, c.name, tick / 3600))
    end
  end
  return n
end

--- Poteau perdu dont l'objet manque ET ne peut être fabriqué : on pose le poteau du meilleur niveau fabricable (r.place / r.item).
local function substitute_poles(f, s, book, free, tick)
  for _, k in ipairs(State.sorted_keys(s.lost)) do
    local r = s.lost[k]
    if r.infra and r.etype == "electric-pole" and not r.place and not r.abandoned and not r.claimed
      and tick - r.tick >= Rc.calm_for(r) and not available_or_craftable(book, free, r.item) then
      local c = Rc.pick_alt(pole_cands(), r.reach or 0, function(x) return available_or_craftable(book, free, x.item) end)
      if not c then Recon.gather(f, s, book, free, r, tick) end
      if c and c.item ~= r.item then
        r.place, r.item = c.name, c.item
        stat(s, "substituted")
        by_name(s, r.name).subst = (by_name(s, r.name).subst or 0) + 1
        if s.stats.logs < Recon.LOGS then
          s.stats.logs = s.stats.logs + 1
          log(string.format("[FO-RECON] %s : %s introuvable ni fabricable : %s posé à sa place (portée de fil %.1f, voisins à %.1f)",
            f.key or "player", r.name, c.name, c.wire, r.reach or 0))
        end
      end
    end
  end
end

function Recon.craft_spares(f, book, free, tick)
  local s = f.recon
  if not (s and s.lost and next(s.lost) and book and free) then return 0 end
  substitute_poles(f, s, book, free, tick)
  local wanted = Rc.demand(s, tick, function(item) return free[item] or 0 end)
  if #wanted == 0 then return 0 end
  local added = {}
  local avail = {}
  for _, k in ipairs(State.sorted_keys(free)) do avail[k] = free[k] end
  for _, w in ipairs(wanted) do
    local item, n = w[1], w[2]
    if book:handcraftable(item) then
      local saved = avail[item]
      avail[item] = 0 -- besoin d'accumulation : l'objet lui-même n'est pas pris au stock
      local q = book:plan({ { item, n } }, avail)
      -- Relecture de la relève (revue statique 29/10) : la matière ne couvre pas toujours TOUT le besoin (3 poteaux perdus, bois pour 2) ;
      -- tout ou rien bloquait alors la fabrication ET la récolte (le poteau est « fabricable » pour 1). On fabrique ce que la matière permet.
      if next(q.raw) ~= nil then
        for m = n - 1, 1, -1 do
          local q2 = book:plan({ { item, m } }, avail)
          if next(q2.raw) == nil then q, n = q2, m break end
        end
      end
      avail[item] = saved
      if next(q.raw) == nil then
        local uses = {}
        for k in next, q.uses do uses[#uses + 1] = k end
        table.sort(uses)
        local list = {}
        for _, k in ipairs(uses) do list[#list + 1] = { k, q.uses[k] } end
        added[#added + 1] = { key = "craft:" .. item .. ":reconstruction", kind = "craft", prio = Rc.task_prio(Rc.INFRA_VALUE), item = item,
          count = n, steps = q.crafts, uses = list, tag = "reconstruction", domain = "defense" }
        for _, u in ipairs(list) do
          if u[1] ~= item then avail[u[1]] = (avail[u[1]] or 0) - u[2] end
        end
        stat(s, "spares")
      else
        -- Mesure : matière première qui manque pour fabriquer l'objet (une ligne par objet et par matière manquante).
        s.stats.rawlog = s.stats.rawlog or {}
        local miss = {}
        for k in next, q.raw do miss[#miss + 1] = k end
        table.sort(miss)
        local sig = item .. ":" .. table.concat(miss, ",")
        if not s.stats.rawlog[sig] and #miss > 0 then
          s.stats.rawlog[sig] = true
          log(string.format("[FO-RECON] %s : %s non fabricable, matiere manquante : %s", f.key or "player", item, table.concat(miss, ", ")))
        end
      end
    else
      s.stats.rawlog = s.stats.rawlog or {}
      if not s.stats.rawlog[item .. ":main"] then
        s.stats.rawlog[item .. ":main"] = true
        log(string.format("[FO-RECON] %s : %s non fabricable a la main (recette inconnue de l'equipe ou non manuelle)", f.key or "player", item))
      end
    end
  end
  if #added > 0 then return Board.add(f, added, tick) end
  return 0
end

--- RÉPARATION : l'infrastructure électrique ENDOMMAGÉE de votre équipe (santé sous Rc.REPAIR_BELOW %) est remise à neuf par un PNJ sur
--- place (LuaEntity.health est en écriture, bornée à la santé max). Un balayage par Recon.REPAIR_SCAN ticks et par équipe ; une tâche « repair » à la fois.
Recon.REPAIR_SCAN = 1800 -- 30 s (revue statique 29/10 : le balayage lit TOUS les poteaux de la surface ; 10 s coûtait un pic régulier sur une grosse usine)
function Recon.repair_think(f, surface, tick)
  if not f.is_player or (f.repair_at or 0) > tick then return 0 end
  f.repair_at = tick + Recon.REPAIR_SCAN
  local b = Board.get(f)
  for _, k in ipairs(State.sorted_keys(b.tasks)) do
    if b.tasks[k].kind == "repair" then return 0 end
  end
  local types = {}
  for _, k in ipairs(State.sorted_keys(R.INFRA_TYPES)) do types[#types + 1] = k end
  local cands = {}
  for _, e in ipairs(surface.find_entities_filtered({ force = f.force, type = types })) do
    -- get_health_ratio : un seul appel par entité (revue statique 29/10 : e.health + e.prototype.max_health créaient un objet prototype pour
    -- CHAQUE poteau de la surface à chaque balayage) ; nil sans santé.
    local ratio = e.valid and e.get_health_ratio() or nil
    if ratio and ratio < 1 then
      cands[#cands + 1] = { key = e.name .. "@" .. string.format("%.1f,%.1f", e.position.x, e.position.y), name = e.name,
        x = e.position.x, y = e.position.y, ratio = ratio }
    end
  end
  local batch = Rc.repair_batch(cands)
  if #batch == 0 then return 0 end
  if #surface.find_enemy_units({ x = batch[1].x, y = batch[1].y }, Recon.SAFE_RADIUS, f.force) > 0 then
    stat(f.recon or Recon.state(f), "repair_deferred")
    return 0
  end
  local targets = {}
  for _, c in ipairs(batch) do targets[#targets + 1] = { name = c.name, x = c.x, y = c.y } end
  return Board.add(f, { { key = "repair:" .. batch[1].key, kind = "repair", prio = Rc.REPAIR_PRIO, domain = "defense", work = 10 + 2 * #batch,
    targets = targets, pos = { x = batch[1].x, y = batch[1].y } } }, tick)
end

function Recon.repair_program(f, task)
  if not (task.pos and task.targets) then return nil end
  return { { "home" }, { "goto", task.pos, 4 }, { "act", "repair" }, { "home" } }
end

--- Remet à neuf les pièces du lot (ACTS.repair). Vrai si au moins une pièce a été réparée.
function Recon.repair_act(agent, f, task, surface)
  local s = Recon.state(f)
  local n = 0
  for _, t in ipairs(task.targets or {}) do
    local e = surface.find_entity(t.name, { t.x, t.y })
    if e and e.valid and e.force.name == f.force and e.health then
      local mx = e.prototype.max_health
      if mx and e.health < mx then
        e.health = mx
        n = n + 1
      end
    end
  end
  if n > 0 then
    stat(s, "repaired", n)
    s.stats.repair_logs = (s.stats.repair_logs or 0) + 1
    if s.stats.repair_logs <= 20 then
      log(string.format("[FO-RECON] %s : %d piece(s) endommagee(s) reparee(s) en (%.1f, %.1f) a %.1f min", f.key or "player", n, task.pos.x,
        task.pos.y, (game.tick - (f.started or 0)) / 3600))
    end
  end
  return n > 0
end

--- Programme de l'ouvrier qui prend la tâche (script/team/worker.lua, Worker.program). Les pièces sont marquées prises.
function Recon.program(f, task)
  local s = f.recon
  if not (s and task.pos and task.items) then return nil end
  Rc.claim(s, task.recs, task.key)
  return { { "home" }, { "take", task.items, strict = true }, { "goto", task.pos, 4 }, { "act", "rebuild" }, { "home" } }
end

--- Emprise de la pièce (boîte de collision du prototype, tournée selon la direction) élargie de 0,3 : { x0, y0, x1, y1 }.
local function footprint(r)
  local p = game.entity_prototypes[r.name]
  local cb = p and p.collision_box
  local hx, hy = 0.5, 0.5
  if cb and cb.left_top and cb.right_bottom then
    hx, hy = (cb.right_bottom.x - cb.left_top.x) / 2, (cb.right_bottom.y - cb.left_top.y) / 2
  end
  if r.dir == defines.direction.east or r.dir == defines.direction.west then hx, hy = hy, hx end
  return { r.x - hx - 0.3, r.y - hy - 0.3, r.x + hx + 0.3, r.y + hy + 0.3 }
end

--- Le PNJ debout sur l'emprise de la pièce l'empêcherait de se poser (moteur réel, plan directeur : un bâtisseur arrêté sur
--- la dernière machine) : il est écarté, à l'est de l'emprise, sur une case libre.
local function step_aside(surface, self, r)
  if not (self and self.valid) then return end
  local fp, q = footprint(r), self.position
  if q.x > fp[1] and q.x < fp[3] and q.y > fp[2] and q.y < fp[4] then
    local spot = surface.find_non_colliding_position(self.name, { x = fp[3] + 2, y = r.y }, 6, 0.5)
    if spot then self.teleport(spot) end
  end
end

--- Les objets tombés au sol (contenu d'un coffre ou d'un four détruit) empêchent la pose (moteur réel, lot COUVERTURE) : le PNJ
--- les ramasse, ce qui ne tient pas dans son sac est laissé.
local function clear_items(surface, inv, r)
  local fp = footprint(r)
  local area = { { fp[1], fp[2] }, { fp[3], fp[4] } }
  for _, e in ipairs(surface.find_entities_filtered({ area = area, type = "item-entity" })) do
    if e.valid then
      local st = e.stack
      if st and st.valid_for_read then
        local n = inv.insert({ name = st.name, count = st.count })
        if n >= st.count then e.destroy() else st.count = st.count - n end
      else
        e.destroy()
      end
    end
  end
  -- Restes de la pièce détruite (et cadavres) : ils refusent aussi le fantôme de reposage (mesuré par le lot réseau) ; on les retire.
  for _, e in ipairs(surface.find_entities_filtered({ area = area, type = "corpse" })) do
    if e.valid then e.destroy() end
  end
end

--- Pose les pièces du lot (script/team/worker.lua, ACTS.rebuild). Vrai si au moins une pièce est refaite.
function Recon.act(agent, f, task, surface)
  local s = f.recon
  if not s then return false end
  local inv = agent.entity.get_main_inventory()
  local placed = 0
  -- Lot REBUILD-AVANT-POSTE : les foreuses d'abord, les réceptacles ensuite (un réceptacle ne recrée jamais un avant-poste sans foreuse).
  local order, late = {}, {}
  for _, k in ipairs(task.recs or {}) do
    local q = s.lost[k]
    if q and q.kind == "sink" then late[#late + 1] = k else order[#order + 1] = k end
  end
  for _, k in ipairs(late) do order[#order + 1] = k end
  local revived = {}
  for _, k in ipairs(order) do
    local r = s.lost[k]
    if r and not r.abandoned then
      local px, py = r.px or r.x, r.py or r.y -- place de la pièce posée (foreuse de remplacement : r.px, r.py)
      local eff = { name = r.place or r.name, x = px, y = py, dir = r.dir }
      local there = surface.find_entity(r.place or r.name, { px, py })
      if not (there and there.valid) and r.place then there = surface.find_entity(r.name, { r.x, r.y }) end -- le poteau d'origine a pu être reposé par ailleurs
      local host = r.kind and f.outposts and f.outposts[r.oid]
      if there and there.valid and there.force.name == f.force then
        delay_note(s, r, "ext", game.tick)
        Rc.done(s, k) -- déjà refaite (par un autre moyen)
      elseif r.kind == "sink" and not (host and (host.drills or 0) > 0) then
        -- pas d'avant-poste vivant avec une foreuse : le réceptacle attend (sa foreuse, ou la fin de la ruine)
      elseif r.item and inv.get_item_count(r.item) >= 1 then
        step_aside(surface, agent.entity, eff)
        clear_items(surface, inv, eff)
        if surface.can_place_entity({ name = r.place or r.name, position = { x = px, y = py }, direction = r.dir, force = f.force })
          and (host or r.kind ~= "drill" or Ruines.recreate(f, r.oid, game.tick)) then
          -- Lot REBUILD-AVANT-POSTE : la première foreuse d'une ruine recrée l'avant-poste (Ruines.recreate, avant la pose)
          if r.kind == "drill" and not host then revived[#revived + 1] = r.oid end
          local ent = surface.create_entity({ name = r.place or r.name, position = { x = px, y = py }, direction = r.dir, force = f.force,
            raise_built = true })
          if ent and ent.valid then
            inv.remove({ name = r.item, count = 1 })
            if r.recipe and ent.type == "assembling-machine" then pcall(ent.set_recipe, r.recipe) end
            if r.kind and ent.unit_number then
              State.own(ent, f.id, r.kind, r.oid)
              local o = f.outposts and f.outposts[r.oid]
              if o then
                if r.kind == "drill" then
                  o.drill_list = o.drill_list or {}
                  o.drill_list[#o.drill_list + 1] = ent
                  o.drills = o.drills + 1
                else
                  o.sinks = o.sinks or {}
                  o.sinks[#o.sinks + 1] = ent
                end
              end
            end
            delay_note(s, r, "own", game.tick)
            Rc.done(s, k)
            placed = placed + 1
            stat(s, "rebuilt")
          end
        elseif r.kind == "drill" and not host and not (s.ruins and s.ruins[r.oid]) then
          -- ruine lâchée à l'instant (champ refait ou site pris) : la pièce est jetée au prochain tour de Recon.think
        else
          stat(s, "blocked")
          Rc.block(s, k)
          -- Diagnostic (hors comportement) : ce qui gêne la pose, pour les premiers cas seulement.
          if (s.stats.dlogs or 0) < Recon.DIAG_LOGS then
            s.stats.dlogs = (s.stats.dlogs or 0) + 1
            local fp = footprint(eff)
            local gens = {}
            for _, e2 in ipairs(surface.find_entities({ { fp[1], fp[2] }, { fp[3], fp[4] } })) do
              if e2.valid and #gens < 6 then
                gens[#gens + 1] = string.format("%s/%s@(%.1f,%.1f)%s", e2.name, e2.type, e2.position.x, e2.position.y,
                  e2.force and e2.force.name ~= f.force and (":" .. e2.force.name) or "")
              end
            end
            local tile = surface.get_tile(r.x, r.y)
            log(string.format("[FO-RECON] %s : pose impossible de %s en (%.1f, %.1f) dir %s : gene par %s ; sol %s ; ennemis a 12 tuiles %d",
              f.key or "player", r.name, r.x, r.y, tostring(r.dir), #gens > 0 and table.concat(gens, ", ") or "rien de visible",
              tile and tile.name or "?", #surface.find_enemy_units({ x = r.x, y = r.y }, 12, f.force)))
          end
        end
      end
    end
  end
  -- Lot REBUILD-AVANT-POSTE : un avant-poste recréé dont aucune foreuse n'a finalement été posée (pose refusée après coup) est retiré
  for _, oid in ipairs(revived) do Ruines.undo(f, oid) end
  Rc.release(s, task.key)
  if placed > 0 and s.stats.logs < Recon.LOGS then
    s.stats.logs = s.stats.logs + 1
    log(string.format("[FO-RECON] %s : %d piece(s) refaite(s) en (%.1f, %.1f) a %.1f min, %d en attente", f.key or "player", placed,
      task.pos.x, task.pos.y, (game.tick - (f.started or 0)) / 3600, Rc.pending(s)))
  end
  return placed > 0
end

remote.add_interface("fo-recon", {
  -- Banc seulement (reconstruire-bois : « avec » et « sans » la récolte du bois). Mémoire LOCALE, hors sauvegarde.
  set_gather = function(on) Recon.GATHER = on and true or false return Recon.GATHER end,
  status = function(key)
    local f = (key == nil or key == "player") and State.faction("player") or nil
    if not f and key ~= nil then
      for _, id in ipairs(State.alive()) do
        local x = State.faction(id)
        if x and (x.key == key or id == key) then f = x break end
      end
    end
    local s = f and f.recon
    if not s then return { pending = 0, recorded = 0, rebuilt = 0, blocked = 0, deferred = 0, tasks = 0, abandoned = 0, hold = false } end
    local ab = 0
    for _, k in ipairs(State.sorted_keys(s.lost)) do if s.lost[k].abandoned then ab = ab + 1 end end
    local st = s.stats
    local wait = {}
    for _, k in ipairs(State.sorted_keys(s.lost)) do
      local r = s.lost[k]
      if not r.counted then
        local w = wait[r.name] or { n = 0, max = 0 }
        w.n = w.n + 1
        w.max = math.max(w.max, game.tick - r.tick)
        wait[r.name] = w
      end
    end
    return { byname = st.byname, wait = wait, pending = Rc.pending(s), recorded = st.recorded, rebuilt = st.rebuilt, blocked = st.blocked, deferred = st.deferred,
      tasks = st.tasks, discarded = st.discarded, repaired = st.repaired or 0, abandoned = ab, hold = Recon.hold_upgrades(f) }
  end,
})

return Recon
