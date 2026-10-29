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
  for _, c in ipairs(list) do
    local e = c.e
    e.built, e.ghosted, e.fails, e.npc_blocks, e.miss = false, false, 0, 0, nil
  end
  if q.state == "fini" then
    q.counted = true
    q.state, q.reason, q.reserve_next = "reserve", "reconstruction", nil
  elseif q.state == "raccordement" then
    q.state = "chantier"
  end
  q.reopened = (q.reopened or 0) + 1 -- non annulable (Build.cancel) tant que ses pièces ne sont pas refaites
  q.reopened_tick = tick
  q.rebuilt_pieces = (q.rebuilt_pieces or 0) + #list
end

--- Une passe de l'équipe. Rend le nombre de pièces rouvertes.
function Sweep.step(f, surface, tick)
  local b = f.build
  if not (R.REBUILD_SWEEP and b and b.projects and b.order and surface) or f.eliminated then return 0 end
  local st = state_of(b, tick)
  if tick < st.next then return 0 end
  st.next = tick + Rule.EVERY
  if tick >= (st.hand_next or 0) then st.hand_next = tick + Sweep.HAND_KEEP / 4 prune_hand(st, tick) end

  local sizes = {}
  for k, pid in ipairs(b.order) do
    local q = b.projects[pid]
    sizes[k] = (q and WATCHED[q.state] and not q.abandoned and not (q.spec and q.spec.enceinte)) and #q.ents or 0
  end
  local segs, pi, ei = Rule.slice(sizes, st.pi, st.ei, Rule.SLICE)
  st.pi, st.ei = pi, ei

  local cands = {}
  for _, sg in ipairs(segs) do
    local q = b.projects[b.order[sg[1]]]
    for i = sg[2], sg[3] do
      local e = q.ents[i]
      -- Sans objet qui la pose (e.item), une pièce rouverte ne pourrait jamais être refaite et bloquerait son projet : laissée.
      if e and e.built and e.item and not e.gave_up and not e.dropped and not e.wall then
        local ty = type_of(e.name)
        local cls = Rule.class_of(ty, R.REBUILD_FIRST, R.INFRA_TYPES)
        if cls then
          local hand = st.hand[place_key(e.x, e.y)] ~= nil
          if not hand then st.seen = st.seen + 1 end
          local present = surface.count_entities_filtered({ position = { e.x, e.y }, radius = Sweep.RADIUS, type = ty, force = f.force,
            limit = 1 }) > 0
          if hand then
            -- retirée à la main : abandonnée pour de bon (la mémoire des retraits expire au bout d'une heure, la pièce ne revient pas)
            if not present then e.gave_up = true end
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
  if #gave > 0 then st.gave_up = st.gave_up + #gave end
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
    reopen(g.q, g.list, tick)
    total = total + #g.list
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
