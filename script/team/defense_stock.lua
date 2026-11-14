--[[
  Lot DEFENSE-STOCK, côté RUNTIME : les tourelles qui dorment au coffre sont posées en groupes là où l'ennemi arrive (règle pure :
  shared/team/defense_stock.lua ; tests/defense_stock_test.lua). Deux services :
    - Ds.view(f, fortify_open, out, stock) : relève les lieux (QG qui a perdu des tourelles, tourelles d'avance de la prévision,
      cellules attaquées du front, avant-postes touchés, laboratoires), consulte la règle et rend { pick, busy } pour le planificateur
      (poste « reserve », facultatif, SANS fabrication : seulement le stock) ; nil si le stock ne dépasse pas la réserve ;
    - Ds.place(f, surface, task, carrier) : pose, depuis l'inventaire du PNJ, les tourelles de la tâche « fortify » du poste « reserve »
      aux emplacements de la règle (Outposts.fortify_at : couloirs des lignes et tuiles réservées respectés, espacement des tourelles).
  Les tourelles posées appartiennent au poste « reserve<clé> » (State.own ; groupe de ravitaillement « oreserve<clé> » de
  Outposts.turret_groups) : elles sont inscrites dans f.turrets et réarmées par les tournées existantes.
  Journal : « [FO-DEFENSE] reserve ... » une ligne par pose ou par refus qui change (cause écrite), au plus Ds.LOGS par équipe.
  État : f.defstock (tables simples : nombres et chaînes, créé en événement, jamais lu ni écrit à on_load). Aucun temps mesuré.
]]
local State = require("script.faction.state")
local R = require("shared.ai3.reglages")
local T = require("shared.team.config")
local Fr = require("shared.team.front")
local Ds_rule = require("shared.team.defense_stock")
local Pose = require("shared.team.pose_tourelles")
local Outposts = require("script.faction.outposts")
local Co = require("shared.ai3.commande") -- lot s45 OUTILS : bastions désignés

local Ds = {}

Ds.OID = "reserve"
Ds.LOGS = 400            -- lignes [FO-DEFENSE] reserve au plus par équipe
Ds.REST = 7200           -- ticks : repos d'une cellule dont la pose n'a rien posé (comme le front)
Ds.CHECK_EVERY = 600     -- ticks : durée de validité d'un « le moteur autorise »

-- Types de bâtiments de l'équipe qui comptent comme « un bâtiment à proximité » : table construite au CHARGEMENT (jamais affectée dans une
-- fonction : tests/upvalue_gc_test.lua), faite de données pures de shared/ai3/reglages.lua et shared/team/pose_tourelles.lua.
local ASSET_TYPES = {}
for _, ty in ipairs(R.ENTITY_TYPES) do
  if Pose.role_factor(R.ENTITY_ROLE[ty]) > 0 then ASSET_TYPES[#ASSET_TYPES + 1] = ty end
end

local function state(f, tick)
  local st = f.defstock
  if not st then
    st = { rest = {}, chk = {}, chk_tick = tick, poses = 0, logs = 0, sig = {} }
    f.defstock = st
  end
  return st
end

--- Portée de couverture d'un groupe (comme le front : 80 % de la portée de la tourelle, au plus Fr.NEAR).
local function range_near()
  local proto = game.entity_prototypes[T.turret]
  local r = proto and proto.turret_range
  if r and r > 0 then return math.min(Fr.NEAR, math.floor(r * 0.8)) end
  return Fr.NEAR
end

--- Tourelles de l'équipe { x, y } (toutes) et nombre de celles de ce poste.
local function turrets_of(f)
  local list, placed = {}, 0
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t.valid then
      list[#list + 1] = { x = t.position.x, y = t.position.y }
      local o = State.owner(id)
      if o and type(o.oid) == "string" and o.oid:sub(1, #Ds.OID) == Ds.OID then placed = placed + 1 end
    end
  end
  return list, placed
end

local function say(f, st, sig_key, sig, fmt, ...)
  if st.logs >= Ds.LOGS then return end
  if st.sig[sig_key] == sig then return end -- le même refus n'est pas écrit deux fois de suite
  st.sig[sig_key] = sig
  st.logs = st.logs + 1
  log("[FO-DEFENSE] reserve " .. (f.key or "player") .. " " .. string.format(fmt, ...))
end

--- Vue du poste pour le planificateur. `out` : la vue en construction (out.front.pick sert à éviter la course avec le front) ;
--- `stock` : stock libre ; `hq_turrets` : tourelles du groupe « hq » ; `outposts` : view.outposts (champ `protect`).
function Ds.view(f, fortify_open, out, stock, hq_turrets, outposts)
  local surface = f.hq and f.hq.valid and f.hq.surface or nil
  if not surface or f.eliminated then return nil end
  local tick = game.tick
  local busy = fortify_open and fortify_open[Ds.OID] or false
  local have_stock = stock and stock[T.turret] or 0
  -- s46 outils : un bastion du joueur se sert sous la réserve (tout stock > 0 suffit)
  local bastions = f.team and f.team.commande and Co.bastion_zones(f.team.commande, Ds_rule.GROUP_CAP) or {}
  if Ds_rule.surplus_for(have_stock, #bastions > 0) <= 0 then return { busy = busy, under = true } end -- sous la réserve : rien à offrir, rien à relever (s44 : cause lue par defense_log)
  local st = state(f, tick)
  local near = range_near()
  local turrets, placed = turrets_of(f)
  local zones = {}
  local seen = {}
  local hq = f.hq_pos
  local posts = {} -- avant-postes de l'équipe : leurs tournées de ravitaillement passent près d'eux
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local po = f.outposts[oid]
    if po and po.pos then posts[#posts + 1] = po.pos end
  end
  local served_r2 = Ds_rule.SERVED_R * Ds_rule.SERVED_R
  local function add(z)
    if seen[z.key] then return end
    seen[z.key] = true
    z.have = Fr.count_near(turrets, z.x, z.y, near)
    z.dist = hq and math.floor(math.sqrt((z.x - hq.x) ^ 2 + (z.y - hq.y) ^ 2)) or 0
    for _, p in ipairs(posts) do
      if (z.x - p.x) ^ 2 + (z.y - p.y) ^ 2 <= served_r2 then z.served = true break end
    end
    zones[#zones + 1] = z
  end
  -- 0. lot s45 OUTILS : bastions défensifs désignés par le joueur (outil de commandement, Maj + R) : servis comme un QG attaqué
  if f.team and f.team.commande then
    for _, b in ipairs(bastions) do
      add({ key = b.key, kind = "qg", x = b.x, y = b.y, score = 0, want = b.want, ordre = true, r = b.r }) -- s46 : spirale, sous la réserve
    end
  end
  -- 1. le QG d'une faction qui en a perdu des tourelles (le plus haut nombre vu, f.team.hq_peak)
  if not f.is_player and f.hq_pos then
    local peak = f.team and f.team.hq_peak or 0
    if peak > (hq_turrets or 0) then
      add({ key = "qg", kind = "qg", x = f.hq_pos.x, y = f.hq_pos.y, score = 0, want = peak })
    end
  end
  -- 2. la prévision (vague imminente plus forte que la défense du site) : lignes déjà calculées pour le front
  local Front = package.loaded["script.team.front"]
  local prevu = Front and Front.prevu and Front.prevu(f) or nil
  for _, pr in ipairs(prevu or {}) do
    add({ key = pr.key, kind = "prevu", x = pr.x, y = pr.y, score = 0, want = pr.want })
  end
  -- 3. cellules attaquées de la mémoire du front (toutes celles qui comptent, pas les trois premières)
  local fm = f.front_mem
  if fm and fm.mem then
    for _, c in ipairs(Fr.top(fm.mem, Fr.SCAN)) do
      add({ key = c.key, kind = "attaque", x = c.x, y = c.y, score = c.score })
    end
  end
  -- 4. avant-postes touchés par des vagues (view.outposts[i].protect) ou où un PNJ a été tué récemment (lethal) : un groupe, pas la seule
  -- tourelle de la règle ordinaire (T.defend_turrets) ; jamais près d'un nid ou d'un ver (le moteur refuse un lieu où un ennemi est à CALM_R)
  for _, o in ipairs(outposts or {}) do
    local po = f.outposts and f.outposts[o.id]
    if (o.protect or o.lethal) and po and po.pos then
      add({ key = "ap" .. tostring(o.id), kind = "site", x = po.pos.x, y = po.pos.y, score = 0 })
    end
  end
  -- 5. laboratoires (groupes de bâtiments d'amélioration relevés par le front)
  for _, c in ipairs(fm and fm.cover or {}) do
    add({ key = c.key, kind = "couverture", x = c.x, y = c.y, score = 0 })
  end
  if #zones == 0 then return { busy = busy } end
  if tick - st.chk_tick > 3600 then st.chk, st.chk_tick = {}, tick end
  local rest = {}
  for _, key in ipairs(State.sorted_keys(st.rest)) do
    if st.rest[key] > tick then rest[key] = true else st.rest[key] = nil end
  end
  local types = ASSET_TYPES
  -- carte du danger de l'équipe (IA3-k) : la porte des tâches refuserait d'y envoyer un PNJ au-delà du seuil de blocage
  local Cp = package.loaded["script.ai3.comportement"]
  local Dg = package.loaded["shared.ai3.danger"]
  local dmap, block
  if Cp and Cp.team and Dg then
    local t = Cp.team(f)
    dmap = t and t.map or nil
    block = Dg.block((Cp.character(f)))
  end
  local function allow(row)
    local c = st.chk[row.key]
    if c and tick - c.t < Ds.CHECK_EVERY then return c.ok, c.why end
    local pos = { x = row.x, y = row.y }
    local ok, why = true, nil
    if row.kind == "attaque" then
      ok = surface.count_entities_filtered({ position = pos, radius = Fr.ASSET_R, force = f.force, type = types, limit = 1 }) > 0
      if not ok then why = "sans_batiment" end
    end
    -- le QG se renforce sous l'attaque (les PNJ y sont chez eux) ; ailleurs, aucun ennemi sur place et une case non bloquée par la carte du danger
    if ok and row.kind ~= "qg" then
      if surface.find_nearest_enemy({ position = pos, max_distance = Fr.CALM_R, force = f.force }) ~= nil then
        ok, why = false, "ennemi"
      elseif dmap and Dg.danger_at(dmap, row.x, row.y, tick) >= block then
        ok, why = false, "danger"
      end
    end
    st.chk[row.key] = { t = tick, ok = ok, why = why }
    return ok, why
  end
  local fpick = out and out.front and out.front.pick
  local plan = Ds_rule.plan({
    stock = have_stock, ammo = stock[T.turret_ammo] or 0, placed = placed, zones = zones, rest = rest,
    avoid = fpick and fpick.key or nil, allow = allow, turrets = turrets,
  })
  -- journal : un refus qui change, par lieu (la cause est celle de la règle ; le premier lieu non servi suffit à lire pourquoi rien ne part)
  local pick = plan.pick
  if not pick then
    for _, r in ipairs(plan.rows) do
      if r.skip and r.skip ~= "servie" and r.skip ~= "suivante" then
        say(f, st, "refus:" .. tostring(r.key), r.skip .. ":" .. r.have,
          "refus a %.1f min : lieu %s (%s) en (%.0f, %.0f) ; stock %d (reserve %d), surplus %d ; a portee %d sur %d voulue(s), score %d ; cause %s%s",
          tick / 3600, tostring(r.key), r.kind, r.x, r.y, have_stock, Ds_rule.RESERVE, plan.surplus, r.have, r.want, r.score, r.skip,
          r.why and (" (" .. r.why .. ")") or (r.skip == "loin" and string.format(" (%d tuiles du QG, hors des avant-postes)", r.dist) or ""))
      end
    end
  end
  -- lignes lues en lecture seule par la vue du débogueur (nombres et mots fixes, bornées) : key, kind, x, y, score, have, want, dist,
  -- skip (cause), why (mot fixe d'un refus), tick (dernière évaluation)
  local keep = {}
  for i, r in ipairs(plan.rows) do
    if i > 24 then break end
    r.tick = tick
    keep[#keep + 1] = r
  end
  st.rows, st.rows_tick, st.placed = keep, tick, placed
  return { pick = pick, busy = busy, surplus = plan.surplus }
end

--- Tourelles déjà posées par le poste (plafond du poste ; lu par script/team/intermediaires.lua pour le plafond de fabrication).
function Ds.placed(f)
  local _, n = turrets_of(f)
  return n
end

--- Pose des tourelles de la tâche (emplacements de la règle, refus au-delà de Fr.ACCEPT tuiles du centre).
function Ds.place(f, surface, task, carrier)
  local c = task.pos
  local key = task.cell_key
  if not (c and key) then return 0 end
  local zr = task.ordre_r -- s46 outils : bastion du joueur : toute place dans le rayon de l'ordre, arbres et rochers dégagés
  local accept
  if zr then
    local lim = zr + 1
    accept = function(pos) return (pos.x - c.x) ^ 2 + (pos.y - c.y) ^ 2 <= lim * lim end
  else
    accept = function(pos) return Fr.accepts(c.x, c.y, pos.x, pos.y) end
  end
  local cleared = 0
  local clear = zr and function(q) -- arbres et rochers (données du prototype : count_as_rock_for_filtered_deconstruction) sous l'emprise
    local box = { { q.x - 1.5, q.y - 1.5 }, { q.x + 1.5, q.y + 1.5 } }
    local hit = false
    for _, e in ipairs(surface.find_entities_filtered({ area = box, type = { "tree", "simple-entity" } })) do
      if e.valid and (e.type == "tree" or e.prototype.count_as_rock_for_filtered_deconstruction) then
        e.destroy({ raise_destroy = true })
        cleared, hit = cleared + 1, true
      end
    end
    return hit
  end or nil
  local n = Outposts.fortify_at(f, surface, Ds.OID .. key, task.sites or {}, task.items[1][2], carrier, accept, nil, clear)
  local tick = game.tick
  local st = state(f, tick)
  st.poses = st.poses + n
  if zr and st.logs < Ds.LOGS then
    -- diagnostic : ce qui occupe la zone du bastion (types moteur), lu une fois par pose
    local function cnt(ty) return surface.count_entities_filtered({ position = { c.x, c.y }, radius = zr, type = ty }) end
    local own = surface.count_entities_filtered({ position = { c.x, c.y }, radius = zr, force = f.force })
    st.logs = st.logs + 1
    log(string.format("[FO-DEFENSE] reserve %s bastion %s en (%.0f, %.0f) rayon %d : %d emplacement(s) en spirale, %d tourelle(s) posee(s), "
      .. "%d arbre(s)/rocher(s) degage(s) ; zone : minerai %d case(s), arbres %d, rochers et decors %d, entites de l'equipe %d, falaises %d",
      f.key or "player", key, c.x, c.y, zr, #(task.sites or {}), n, cleared, cnt("resource"), cnt("tree"), cnt("simple-entity"), own, cnt("cliff")))
  end
  -- une pose à zéro (emplacements bloqués, plus de tourelle au porteur) met le lieu au repos : il ne monopolise pas la tâche
  st.rest[key] = n == 0 and tick + Ds.REST or nil
  if st.logs < Ds.LOGS then
    st.logs = st.logs + 1
    local near = range_near()
    local turrets = turrets_of(f)
    log(string.format("[FO-DEFENSE] reserve %s pose a %.1f min : lieu %s en (%.0f, %.0f) ; %d tourelle(s) posee(s) sur %d demandee(s) ; %d a portee apres la pose (groupe minimal %d) ; cumul %d ; cause %s",
      f.key or "player", tick / 3600, key, c.x, c.y, n, task.items[1][2], Fr.count_near(turrets, c.x, c.y, near), Ds_rule.MIN_GROUP, st.poses,
      n > 0 and "stock au-dela de la reserve" or "aucun emplacement libre (lieu au repos)"))
  end
  return n
end

--- Porteur tué en allant renforcer le lieu : il se repose comme un avant-poste meurtrier (T.lethal_ticks).
function Ds.on_lost(f, key, cause)
  local tick = game.tick
  local st = state(f, tick)
  if key then st.rest[key] = tick + T.lethal_ticks end
  if st.logs < Ds.LOGS then
    st.logs = st.logs + 1
    log(string.format("[FO-DEFENSE] reserve %s : PNJ tue en allant renforcer le lieu %s (%s) a %.1f min ; lieu au repos %.1f min",
      f.key or "player", tostring(key), tostring(cause), tick / 3600, T.lethal_ticks / 3600))
  end
end

return Ds
