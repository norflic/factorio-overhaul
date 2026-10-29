--[[
  Lot REBUILD-TOUT : exécutant du relevé de reconstruction des projets du plan directeur (règle pure : shared/team/rebuild_sweep.lua).
  Appelé par Recon.think (script/team/reconstruction.lua) à chaque pensée d'équipe, derrière sa propre horloge : rien à abonner ici.

  Retour du DC (29/10, 1 h 30 sur 0.6.13) : « il y a des productions qui ont été détruites, des bâtiments, convoyeurs, améliorations
  qui n'ont pas été remplacés [...] ils ont replacé les poteaux à l'endroit où ils étaient, mais les usines ne sont plus placées ».
  Les projets (f.build.projects[].ents) gardent la place de tout ce qui a été posé (e.built). Le relevé compare ces places au monde
  par tranches (Sw.SLICE pièces toutes les Sw.EVERY ticks, jamais toute la surface), et remet à « à bâtir » ce qui a disparu : le plan
  directeur (script/team/build.lua) pose le fantôme, les PNJ le ravivent, le coût est pris sur le stock de l'équipe (réserve du
  projet), les restes des pièces détruites sont retirés avant la pose (Build.clear_floor). AUCUN second mécanisme de pose.
  Toutes les équipes : les factions comme la vôtre. Ce que le joueur a retiré à la main (on_player_mined_entity, robots) n'est PAS
  refait (mémoire b.sweep.hand : position -> tick).
  Laissé à d'autres mécanismes : l'infrastructure électrique (R.INFRA_TYPES : registre de reconstruction et réseau vivant), les murs de
  l'enceinte (repair_enclosure), les foreuses et réceptacles d'avant-poste (registre de reconstruction, R.RECON_ALL_PIECES).
  Pas de pose pendant que l'ennemi est sur place : une pièce dont la place a un ennemi à Sw.ENEMY_R tuiles reste inscrite (sans compter
  dans les plafonds). État : b.sweep (nombres, booléens, tables simples) ; e.miss, e.rb, e.rb_t, e.gave_up sur les pièces du plan.
]]

local R = require("shared.ai3.reglages")
local Rule = require("shared.team.rebuild_sweep")
local Rr = require("shared.team.rebuild_rapide") -- lot REBUILD-RAPIDE : liste chaude, ordre, foreuse thermique de secours (règles pures)

local Sweep = {}

Sweep.ENEMY_R = 28        -- tuiles : aucune réouverture avec un ennemi à cette portée de la place (porte de Recon.SAFE_RADIUS, Rv.POLE_ENEMY_R)
Sweep.RADIUS = 0.4        -- rayon de recherche autour de la place (F96 : intervalles fermés ; une pièce voisine est à plus de 0,5)
Sweep.CELL = 16           -- tuiles : un seul contrôle de danger par case de 16 par passe
Sweep.LOGS = 40           -- lignes de journal par équipe
Sweep.HAND_KEEP = 3600 * 60 -- 1 h : mémoire des retraits à la main
Sweep.HAND_MAX = 400      -- retraits à la main retenus au plus

-- États d'un projet dont les pièces posées sont relevées. « attente », « plan », « refuse » et « bloque » n'ont pas (ou plus) de plan posé.
local WATCHED = { fini = true, raccordement = true, chantier = true, fantomes = true, defrichage = true, reserve = true }

local TYPE_OF = {} -- mémoire LOCALE (prototypes seulement)
local function type_of(name)
  local t = TYPE_OF[name]
  if t == nil then
    local p = game.entity_prototypes[name]
    t = p and p.type or false
    TYPE_OF[name] = t
  end
  return t or nil
end

local function place_key(x, y) return string.format("%.1f,%.1f", x, y) end

local function state_of(b, tick)
  local st = b.sweep
  if not st then
    st = { pi = 1, ei = 1, next = tick + Rule.EVERY, hand = {}, seen = 0, marked = 0, reopened = 0, gave_up = 0, danger = 0, logs = 0 }
    b.sweep = st
  end
  st.hand = st.hand or {}
  return st
end

local function prune_hand(st, tick)
  local list = {}
  for k, t in next, st.hand do list[#list + 1] = { k, t } end
  table.sort(list, function(x, y) if x[2] ~= y[2] then return x[2] < y[2] end return x[1] < y[1] end) -- le plus ancien d'abord
  local keep = #list
  for _, it in ipairs(list) do
    if tick - it[2] > Sweep.HAND_KEEP or keep > Sweep.HAND_MAX then
      st.hand[it[1]] = nil
      keep = keep - 1
    end
  end
  st.hand_cnt = keep
end

--- Une pièce retirée À LA MAIN par le joueur (ou ses robots) : mémorisée pour ne pas être refaite. Mémoire bornée à Sweep.HAND_MAX
--- retraits (le plus ancien est oublié d'abord) et à Sweep.HAND_KEEP ticks.
function Sweep.note_hand(f, ent, tick)
  local b = f and f.build
  if not (b and ent and ent.valid) then return end
  local st = state_of(b, tick)
  local k = place_key(ent.position.x, ent.position.y)
  if st.hand[k] == nil then st.hand_cnt = (st.hand_cnt or 0) + 1 end
  st.hand[k] = tick
  if st.hand_cnt > Sweep.HAND_MAX * 2 then prune_hand(st, tick) end
end

--- Rouvre les pièces `list` d'un même projet : « à bâtir », fantômes puis ravivage par les PNJ du plan. Un projet fini repasse en réserve
--- (comme reseau_vivant.reopen : déjà compté aux statistiques) ; un projet en raccordement repasse en chantier.
local function reopen(q, list, tick)
  local lag -- lot REBUILD-RAPIDE : plus long délai entre la mort d'une pièce et sa réouverture (nil : aucune pièce tuée datée)
  for _, c in ipairs(list) do
    local e = c.e
    e.built, e.ghosted, e.fails, e.npc_blocks, e.miss = false, false, 0, 0, nil
    -- lot REBUILD-RAPIDE : date de la première destruction encore à refaire (journal du délai total, [FO-REBUILD-RAPIDE] à la fin)
    if e.died_t then
      if not q.rr_died or e.died_t < q.rr_died then q.rr_died = e.died_t end
      if not lag or tick - e.died_t > lag then lag = tick - e.died_t end
      e.died_t = nil
    end
  end
  if q.state == "fini" then
    q.counted = true
    q.state, q.reason, q.reserve_next = "reserve", "reconstruction", nil
  elseif q.state == "raccordement" then
    q.state = "chantier"
  end
  q.reopened = (q.reopened or 0) + 1 -- non annulable (Build.cancel) tant que ses pièces ne sont pas refaites
  q.reopened_tick = tick
  q.retries, q.retry_at = 0, nil -- lot INTEG-RECONSTRUCTION (D2) : les reprises de la construction ne comptent pas pour la reconstruction
  q.rebuilt_pieces = (q.rebuilt_pieces or 0) + #list
  -- lot REBUILD-SUIVI : suivi au journal ([FO-REBUILD-ETAT]) jusqu'à ce que le projet soit refini
  if not q.etat_open then q.etat_open, q.etat_from, q.etat_n, q.etat_next = true, tick, 0, tick + Rule.ETAT_EVERY end
  q.etat_n = (q.etat_n or 0) + #list
  return lag
end

--- Lot REBUILD-RAPIDE (d) : réouverture d'une pièce rendue à l'électrique par script/team/rebuild_rapide.lua (même règle que le relevé).
function Sweep.reopen_pieces(q, list, tick) return reopen(q, list, tick) end

--- Lot REBUILD-SUIVI : une ligne toutes les Rule.ETAT_EVERY ticks par projet rouvert (pièces à refaire, objets à refaire et manquants
--- au coffre, état, danger), une ligne à la fin (refait en N min). Avant, le journal s'arrêtait à la réouverture et `[FO-BLOQUE]` ne
--- dit chaque cause qu'une fois : une fonderie rouverte restait muette pendant plus d'une heure (audit 29/10, Ligue Azur).
local function report(f, b, st, tick)
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and q.etat_open then
      if q.state == "fini" then
        q.etat_open = nil
        if q.rr_died then -- lot REBUILD-RAPIDE : délai total, de la première destruction au projet refini
          if (st.rr_logs or 0) < Sweep.RAPIDE_LOGS then
            st.rr_logs = (st.rr_logs or 0) + 1
            log(string.format("[FO-REBUILD-RAPIDE] %s : projet %d (%s) refait %.0f s apres la premiere destruction (rang %d) a %.1f min", f.key or "player",
              q.id or 0, tostring(q.spec and (q.spec.key or q.spec.gen) or "?"), (tick - q.rr_died) / 60, Rr.project_rank(q.spec), tick / 3600))
          end
          q.rr_died = nil
        end
        if (st.etat_logs or 0) < Rule.ETAT_LOGS then
          st.etat_logs = (st.etat_logs or 0) + 1
          log(string.format("[FO-REBUILD-ETAT] %s : projet %d (%s) REFAIT en %.1f min (%d piece(s) rouverte(s)) a %.1f min", f.key or "player",
            q.id or 0, tostring(q.spec and (q.spec.key or q.spec.gen) or "?"), (tick - (q.etat_from or tick)) / 3600, q.etat_n or 0, tick / 3600))
        end
      elseif q.abandoned or q.state == "refuse" then
        q.etat_open = nil
      elseif tick >= (q.etat_next or 0) then
        q.etat_next = tick + Rule.ETAT_EVERY
        if (st.etat_logs or 0) < Rule.ETAT_LOGS then
          st.etat_logs = (st.etat_logs or 0) + 1
          local todo, pieces = Rule.todo(q)
          log(string.format("[FO-REBUILD-ETAT] %s : projet %d (%s) etat %s[%s], %d piece(s) a refaire sur %d, a refaire {%s}, manque au coffre {%s}, " ..
            "%d rouverte(s) depuis %.1f min, danger %d, a %.1f min", f.key or "player", q.id or 0,
            tostring(q.spec and (q.spec.key or q.spec.gen) or "?"), tostring(q.state), tostring(q.reason or ""), pieces, #q.ents,
            Rule.items_text(todo), Rule.items_text(q.missing), q.etat_n or 0, (tick - (q.etat_from or tick)) / 3600, st.danger or 0, tick / 3600))
        end
      end
    end
  end
end

--- Lot INTEG-RECONSTRUCTION (D4) : l'équipe a-t-elle un projet du plan directeur rouvert à refaire ? (Recon.hold_upgrades : « améliorer attend »)
function Sweep.hold(f, tick)
  local b = f.build
  if not (R.REBUILD_SWEEP and b and b.projects and b.order) then return false end
  for _, pid in ipairs(b.order) do
    if Rule.project_holds(b.projects[pid], tick) then return true end
  end
  return false
end

Sweep.MATCH = 0.3       -- tuiles : tolérance de position d'une pièce du plan (comme Recon.MATCH)
Sweep.RAPIDE_LOGS = 60  -- lignes [FO-REBUILD-RAPIDE] par équipe

--- Lot REBUILD-RAPIDE (a) : une pièce d'un projet du plan tuée (on_entity_died, lu par script/team/reconstruction.lua) entre dans la liste
--- chaude : elle est marquée absente à la date de sa mort et relue à CHAQUE passe du relevé, sans attendre que le curseur (Rule.SLICE pièces
--- par passe, une passe par pensée d'équipe) repasse deux fois sur elle (de 1 à 4 min mesurées sur la partie du DC du 29/10, Scarlet).
--- Rend vrai si une pièce du plan a été trouvée à cette place.
function Sweep.note_died(f, pos, tick)
  local b = f and f.build
  if not (R.REBUILD_SWEEP and b and b.projects and b.order and pos) then return false end
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and q.ents and WATCHED[q.state] and not q.abandoned then
      for i, e in ipairs(q.ents) do
        if math.abs(e.x - pos.x) <= Sweep.MATCH and math.abs(e.y - pos.y) <= Sweep.MATCH then
          local st = state_of(b, tick)
          if Rr.hot_add(st, pid, i, e, tick) then st.hot[#st.hot][3], st.hot[#st.hot][4] = e.x, e.y end
          return true
        end
      end
    end
  end
  return false
end

--- Lot REBUILD-RAPIDE (a) : passe sur la liste chaude. Les pièces dues entrent dans `cands` (même règle que le curseur : deux vues, la
--- première étant la mort) ; `seen[e]` évite que le curseur les relise dans la même passe. Une pièce revue en place, rouverte ou qui n'est
--- plus au plan sort de la liste ; une pièce encore marquée ou due mais non choisie (ennemi sur place, plafond) y reste.
local function hot_pass(b, force, st, surface, tick, cands, seen)
  if not (st.hot and #st.hot > 0) then return end
  local rank = {}
  for k, pid in ipairs(b.order) do rank[pid] = k end
  local keep = {}
  for _, h in ipairs(st.hot) do
    local q = b.projects[h[1]]
    local e = q and q.ents and q.ents[h[2]]
    local k = rank[h[1]]
    if e and k and h[3] and WATCHED[q.state] and not q.abandoned and not (q.spec and q.spec.enceinte) and e.built and e.item
      and not e.gave_up and not e.dropped and not e.wall and math.abs(e.x - h[3]) <= Sweep.MATCH and math.abs(e.y - h[4]) <= Sweep.MATCH
      and st.hand[place_key(e.x, e.y)] == nil then
      local ty = type_of(e.name)
      local cls = Rule.class_of(ty, R.REBUILD_FIRST, R.INFRA_TYPES)
      if cls then
        seen[e] = true
        local present = surface.count_entities_filtered({ position = { e.x, e.y }, radius = Sweep.RADIUS, type = ty, force = force,
          limit = 1 }) > 0
        local r = Rule.observe(e, present, tick)
        if r == "due" then
          cands[#cands + 1] = { q = q, pi = k, i = h[2], e = e, class = cls, ty = ty, hot = true }
          keep[#keep + 1] = h
        elseif r == "marque" then
          keep[#keep + 1] = h
        end
      end
    end
  end
  Rr.hot_set_list(st, keep)
end

--- Une passe de l'équipe. Rend le nombre de pièces rouvertes.
function Sweep.step(f, surface, tick)
  local b = f.build
  if not (R.REBUILD_SWEEP and b and b.projects and b.order and surface) or f.eliminated then return 0 end
  local st = state_of(b, tick)
  if tick < st.next then return 0 end
  st.next = tick + Rule.EVERY
  if tick >= (st.hand_next or 0) then st.hand_next = tick + Sweep.HAND_KEEP / 4 prune_hand(st, tick) end
  report(f, b, st, tick)

  -- Lot REBUILD-RAPIDE (a) : la liste chaude d'abord (pièces tuées depuis les dernières passes), puis la tranche du curseur.
  local cands, seen = {}, {}
  hot_pass(b, f.force, st, surface, tick, cands, seen)

  local sizes = {}
  for k, pid in ipairs(b.order) do
    local q = b.projects[pid]
    sizes[k] = (q and WATCHED[q.state] and not q.abandoned and not (q.spec and q.spec.enceinte)) and #q.ents or 0
  end
  local segs, pi, ei = Rule.slice(sizes, st.pi, st.ei, Rule.SLICE)
  st.pi, st.ei = pi, ei

  for _, sg in ipairs(segs) do
    local q = b.projects[b.order[sg[1]]]
    for i = sg[2], sg[3] do
      local e = q.ents[i]
      -- Sans objet qui la pose (e.item), une pièce rouverte ne pourrait jamais être refaite et bloquerait son projet : laissée.
      if e and e.gave_up and Rule.gave_expired(e, tick) then
        -- lot INTEG-RECONSTRUCTION (D3) : abandon levé (80 min), la pièce est de nouveau relevée
        e.gave_up, e.gave_t, e.rb, e.rb_t, e.miss = nil, nil, nil, nil, nil
      end
      if e and e.built and e.item and not e.gave_up and not e.dropped and not e.wall and not seen[e] then
        local ty = type_of(e.name)
        local cls = Rule.class_of(ty, R.REBUILD_FIRST, R.INFRA_TYPES)
        if cls then
          local hand = st.hand[place_key(e.x, e.y)] ~= nil
          if not hand then st.seen = st.seen + 1 end
          local present = surface.count_entities_filtered({ position = { e.x, e.y }, radius = Sweep.RADIUS, type = ty, force = f.force,
            limit = 1 }) > 0
          if hand then
            -- retirée à la main : abandonnée pour de bon (la mémoire des retraits expire au bout d'une heure, la pièce ne revient pas)
            if not present then e.gave_up, e.hand_gave = true, true end
          else
            local r = Rule.observe(e, present, tick)
            if r == "marque" and e.miss == tick then st.marked = st.marked + 1 end
            if r == "due" then cands[#cands + 1] = { q = q, pi = sg[1], i = i, e = e, class = cls, ty = ty } end
          end
        end
      end
    end
  end
  if #cands == 0 then return 0 end

  local memo = {}
  local function safe(c)
    local key = math.floor(c.e.x / Sweep.CELL) .. ":" .. math.floor(c.e.y / Sweep.CELL)
    local ok = memo[key]
    if ok == nil then
      local foe = surface.find_nearest_enemy({ position = { x = c.e.x, y = c.e.y }, max_distance = Sweep.ENEMY_R, force = f.force })
      ok = not (foe and foe.valid)
      memo[key] = ok
      if not ok then st.danger = st.danger + 1 end
    end
    return ok
  end
  local picked, gave = Rule.select(cands, tick, safe)
  if #gave > 0 then
    st.gave_up = st.gave_up + #gave
    -- lot INTEG-RECONSTRUCTION (D3) : l'abandon se dit au journal (il restait silencieux : trou définitif dans une ligne de production)
    if st.logs < Sweep.LOGS then
      st.logs = st.logs + 1
      local c1 = gave[1]
      log(string.format("[FO-REBUILD] %s : %d piece(s) ABANDONNEE(S) (detruites %d fois en %d min, %s en %.1f, %.1f), reprises dans %d min a %.1f min",
        f.key or "player", #gave, Rule.MAX_REBUILD, math.floor(Rule.FORGET / 3600), c1.e.name, c1.e.x, c1.e.y, math.floor(Rule.GAVE_KEEP / 3600), tick / 3600))
    end
  end
  if #picked == 0 then return 0 end

  local by = {}
  for _, c in ipairs(picked) do
    local g = by[c.pi]
    if not g then g = { q = c.q, list = {}, first = 0 } by[c.pi] = g end
    g.list[#g.list + 1] = c
  end
  local keys = {}
  for k in next, by do keys[#keys + 1] = k end
  table.sort(keys)
  local total = 0
  for _, k in ipairs(keys) do
    local g = by[k]
    local lag = reopen(g.q, g.list, tick)
    total = total + #g.list
    if lag and (st.rr_logs or 0) < Sweep.RAPIDE_LOGS then -- lot REBUILD-RAPIDE : latence de détection et rang de la reconstruction
      st.rr_logs = (st.rr_logs or 0) + 1
      local c1 = g.list[1]
      log(string.format("[FO-REBUILD-RAPIDE] %s : projet %d (%s), %d piece(s) rouverte(s) %.0f s apres leur destruction (%s en %.1f, %.1f), rang %d " ..
        "(1 alimentation, 2 production principale, 3 le reste), chantier sans attendre toute la matiere a %.1f min", f.key or "player", g.q.id or 0,
        tostring(g.q.spec and (g.q.spec.key or g.q.spec.gen) or "?"), #g.list, lag / 60, c1.e.name, c1.e.x, c1.e.y, Rr.project_rank(g.q.spec), tick / 3600))
    end
    st.reopened = st.reopened + #g.list
    if st.logs < Sweep.LOGS then
      st.logs = st.logs + 1
      local c1 = g.list[1]
      log(string.format("[FO-REBUILD] %s : projet %d, %d piece(s) detruite(s) rouverte(s) (%s en %.1f, %.1f, classe %d) a %.1f min", f.key or "player",
        g.q.id or 0, #g.list, c1.e.name, c1.e.x, c1.e.y, c1.class, tick / 3600))
    end
  end
  return total
end

return Sweep
