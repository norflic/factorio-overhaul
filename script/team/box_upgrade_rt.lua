--[[
  Lot BOX-UPGRADE (directive du DC du 9/11) : MOTEUR du rétrofit glissant des boxes (règle pure : shared/team/box_upgrade.lua).
  Appelé UNE fois par impulsion d'hygiène, à la fin du relevé des boxes (script/team/boxes_rt.lua, Boxes.releve, tranche 0 : audit
  temporisé, cron lent de 3 min ou réveil « recherche » de script/team/scan_reveil.lua). Pour UNE box UPGRADE_REQUISE de sorte fonderie
  ou mall par équipe et par impulsion (celle déjà en rétrofit d'abord) :
    1. RELEVÉ des unités : pièces bâties des projets de la box (bande de champ : b.projects[id] ; rangée de mall : ses sections
       « fini »), retrouvées à leur position (par nom, sinon par TYPE : un bras déjà monté porte le nom du rang supérieur) ; rôle lu au
       TYPE du prototype (Bx.TYPES[kind] : la machine ; R.RANG_REACH.type : le bras), jamais à un nom ; un bras est « entree » s'il
       dépose dans une machine de la box, « sortie » s'il y prend (cible du moteur, sinon point de dépôt / de prise dans l'emprise).
    2. PALIER CIBLE = le successeur le plus rapide du MÊME type (script/ai3/capital.lua, Capital.successors_of : même groupe de
       remplacement rapide, même emprise, même énergie, mêmes catégories, même portée ; vitesse lue au prototype) dont l'objet est
       fabricable par la force (une recette activée, Capital.unlocked). tier = vitesse (crafting_speed, inserter_rotation_speed).
       Lot RETROFIT-GABARITS (décision du DC du 10/11) : à défaut, un successeur à EMPRISE PLUS GRANDE (Bu.grown_successors : même type,
       vitesse supérieure, énergie identique ou électrique, catalogue des machines Capital.machine_names) : l'unité « grandit ».
    3. KIT = Stock.count des objets cibles ; PLAN = Bu.plan ; `can_place` mesuré SEULEMENT pour les unités de la tranche courante
       (can_fast_replace, sinon can_place_entity{build_check_type = manual}) ; replanifié avec ces mesures (unités ajournées).
       Unité qui grandit : sa cellule réservée doit l'accueillir (Bu.fit : Bl.grow sur l'occupation RELEVÉE, entités de la couche objet
       hors la machine et ses bras, tuiles infranchissables ; ses bras suivent la ligne d'interface cible ou sont déplacés) ; sinon
       ajournée, cause « emprise ». La vérification du moteur (can_place_entity, build_check_type.manual) a lieu dans la primitive,
       l'ancienne encore debout la ferait toujours échouer avant le retrait.
    4. ÉMISSION : chaque unité de la tranche est remplacée par la primitive du lot AMELIORER (Capital.replace_entity -> replace_one :
       create_entity{fast_replace} du moteur, F39 : contenu et recette gardés ; objet cible pris au stock, ancien objet rendu au stock,
       propriété suivie) ; la pièce du plan prend le nom du nouveau palier pour une machine (la reconstruction cherche par nom), pas pour
       un bras (le plan garde le rang 1, la reconstruction cherche par type : règle de capital.lua). Unité qui grandit : la primitive
       PARTAGÉE du lot FOREUSES (script/team/swap_entity.lua, Se.swap : retrait, pose au centre de Bl.grown, repose de l'ancienne si
       échec) ; contenu et recette rendus à la nouvelle (le reste au stock), pièce du plan déplacée, bras déplacés (bras long si exigé).
    5. JOURNAL : « [FO-RETROFIT] <équipe> : box <kind> <id> : tranche k/n (2 machines, 4 bras, 6 remplacees), ajournees N (place),
       ajournees M (emprise), en attente de <item> x<n> » ; état f.team.retrofit[clé] = { i, n, done, t0, deferred, deferred_emprise,
       waiting_item, waiting_n } (nombres, chaînes).
  Gardes : au plus une box par équipe et par impulsion ; rien pendant une menace du QG (unités ennemies à T.hq_threat_radius du coffre,
  même mesure que script/team/liaison.lua) ; rien tant que la primitive n'est pas liée (Bur.bind, appelé par capital.lua au chargement :
  F24, aucun require pendant un événement, et capital.lua -> automatisation -> build -> hygiene -> boxes_rt -> ce module ferait une boucle).
  Déterminisme : projets dans l'ordre des listes du plan, unités triées par la règle pure ; aucun `pairs` décisionnel ; aucun temps mesuré.
]]

local Bx = require("shared.team.boxes")
local Bu = require("shared.team.box_upgrade")
local Bl = require("shared.team.box_layout")
local R = require("shared.ai3.reglages")
local T = require("shared.team.config")
local L = require("shared.levels.config")
local Se = require("script.team.swap_entity") -- lot RETROFIT-GABARITS : remplacement à emprise différente (primitive partagée)

local Bur = {}

Bur.KINDS = { fonderie = true, mall = true } -- sortes de boxes rétrofitées (les machines : four, assembleur)
Bur.SEEK_R = 0.3 -- tuiles : rayon pour retrouver une pièce à sa position quand son nom a changé
Bur.OBJECT_LAYER = "object-layer" -- couche de collision relevée autour d'une cellule qui grandit (bâtiments, arbres, rochers, eau)

local Cap, Stock = nil, nil -- liés par script/ai3/capital.lua au chargement (Bur.bind)

--- Liaison tardive : la primitive de remplacement (Capital.replace_entity, successors_of, mproto, unlocked, machine_names) et le stock.
function Bur.bind(capital, stock) Cap, Stock = capital, stock end
function Bur.bound() return Cap ~= nil and Stock ~= nil end

local function key_of(f) return tostring(f.key or "player") end

--- Menace du QG : des unités ennemies à T.hq_threat_radius du coffre (même mesure que liaison.lua).
local function threat(f, surface)
  if not (f.hq and f.hq.valid and f.hq_pos) then return false end
  return surface.count_entities_filtered({ position = f.hq_pos, radius = T.hq_threat_radius, force = "enemy", type = "unit", limit = 1 }) > 0
end

--- Projets d'une box : la bande (fonderie) ou les sections « fini » de la rangée (mall).
local function projects_of(f, box)
  local b = f.build
  if not (b and b.projects) then return {} end
  if box.kind == "fonderie" then
    local p = b.projects[box.id]
    return p and { p } or {}
  end
  local out = {}
  for _, r in ipairs(b.mall and b.mall.rows or {}) do
    if r.j == box.id then
      for _, q in ipairs(r.projects or {}) do
        local p = b.projects[q.id]
        if p and p.state == "fini" then out[#out + 1] = p end
      end
    end
  end
  return out
end

--- Rôle d'un type de prototype pour la sorte de box : "machine", "bras" ou nil.
local function role_of_type(kind, t)
  for _, mt in ipairs(Bx.TYPES[kind] or {}) do if mt == t then return "machine" end end
  if t == R.RANG_REACH.type then return "bras" end
  return nil
end

--- La pièce `pe` du plan, retrouvée à sa position : par nom, sinon par le type de son prototype (nom déjà monté).
local function entity_at(surface, f, pe)
  local e = surface.find_entity(pe.name, { pe.x, pe.y })
  if e and e.valid then return e end
  local mp = Cap.mproto(pe.name)
  if not mp then return nil end
  for _, c in ipairs(surface.find_entities_filtered({ position = { pe.x, pe.y }, radius = Bur.SEEK_R, type = mp.type, force = f.force })) do
    if c.valid and Cap.mproto(c.name) then return c end
  end
  return nil
end

--- Contexte des successeurs à emprise plus grande (Bu.grown_successors) : catalogue des machines et familles à niveaux, lus aux données.
local function grown_ctx()
  return { mproto = Cap.mproto, machines = Cap.machine_names and Cap.machine_names() or {}, parse = L.parse }
end

--- Le plus rapide des successeurs `succ` dont l'objet est fabricable, ou nil.
local function best_unlocked(f, succ)
  for i = #succ, 1, -1 do
    local tp = Cap.mproto(succ[i])
    if tp and tp.item and Cap.unlocked(f, tp.item) then return { name = succ[i], item = tp.item, speed = tp.speed, w = tp.w, h = tp.h } end
  end
  return nil
end

--- Palier cible d'un prototype : le successeur le plus rapide dont l'objet est fabricable ; à défaut un successeur à emprise plus grande
--- (lot RETROFIT-GABARITS) ; { name, item, speed, w, h } ou false (mémo par nom).
local function target_of(f, name, memo)
  local t = memo[name]
  if t ~= nil then return t end
  t = best_unlocked(f, Cap.successors_of(name) or {}) or best_unlocked(f, Bu.grown_successors(grown_ctx(), name)) or false
  memo[name] = t
  return t
end

--- La machine de la box dont l'emprise contient (x, y) (liste `machines` = { { id, x, y, w, h } }), ou nil.
local function machine_at(machines, x, y)
  if not (x and y) then return nil end
  for _, m in ipairs(machines) do
    if math.abs(x - m.x) <= m.w / 2 and math.abs(y - m.y) <= m.h / 2 then return m.id end
  end
  return nil
end

--- Rôle et machine servie d'un bras : cible du moteur si elle est une machine de la box, sinon point de dépôt / de prise dans une emprise.
--- Rend aussi le point LOINTAIN du bras (son tapis : prise d'une entrée, dépôt d'une sortie), pour le suivi de la ligne d'interface.
local function arm_role(e, machines, is_machine)
  local dt, pt = e.drop_target, e.pickup_target
  local dp, pp = e.drop_position, e.pickup_position
  if dt and dt.valid and dt.unit_number and is_machine[dt.unit_number] then return "entree", dt.unit_number, pp end
  if pt and pt.valid and pt.unit_number and is_machine[pt.unit_number] then return "sortie", pt.unit_number, dp end
  local md = machine_at(machines, dp and dp.x, dp and dp.y)
  if md then return "entree", md, pp end
  local mp = machine_at(machines, pp and pp.x, pp and pp.y)
  if mp then return "sortie", mp, dp end
  return "entree", nil, pp -- bras hors des machines de la box (quai, évacuation inconnue) : orphelin, dernier servi
end

--- Une unité à monter depuis l'entité `e` (palier cible connu), ou nil. fp_now / fp_target (emprises, tuiles) : Bu.grows.
local function unit_of(f, e, role, memo)
  local mp = Cap.mproto(e.name)
  if not (mp and mp.speed) then return nil end
  local t = target_of(f, e.name, memo)
  if not t or t.name == e.name then return nil end
  return { id = e.unit_number, role = role, tier_now = mp.speed, tier_target = t.speed, target = t.name, item = t.item,
    x = e.position.x, y = e.position.y, fp_now = { w = mp.w or 1, h = mp.h or 1 }, fp_target = { w = t.w or 1, h = t.h or 1 } }
end

--- Relevé des unités d'une box : machines d'abord (leur emprise sert aux bras), puis les bras. Rend units (données) et refs[id] = { e, pe,
--- ctx } ; ctx = { machines, arms_of[id machine] = { { id, x, y (tuiles), far = { x, y }, e, pe } } } (tous les bras, montés ou non).
local function survey(f, surface, box)
  local units, refs, memo = {}, {}, {}
  local machines, is_machine, arms = {}, {}, {}
  local ctx = { machines = machines, arms_of = {} }
  for _, p in ipairs(projects_of(f, box)) do
    for _, pe in ipairs(p.ents or {}) do
      if pe.built and not pe.skipped and not pe.dropped then
        local e = entity_at(surface, f, pe)
        if e and e.valid and e.unit_number and e.force.name == f.force then
          local role = role_of_type(box.kind, e.type)
          if role == "machine" then
            local mp = Cap.mproto(e.name)
            machines[#machines + 1] = { id = e.unit_number, x = e.position.x, y = e.position.y, w = mp and mp.w or 1, h = mp and mp.h or 1 }
            is_machine[e.unit_number] = true
            local u = unit_of(f, e, "machine", memo)
            if u then units[#units + 1] = u refs[u.id] = { e = e, pe = pe, ctx = ctx } end
          elseif role == "bras" then
            arms[#arms + 1] = { e = e, pe = pe }
          end
        end
      end
    end
  end
  for _, a in ipairs(arms) do
    local role, mid, far = arm_role(a.e, machines, is_machine)
    if mid then
      ctx.arms_of[mid] = ctx.arms_of[mid] or {}
      local list = ctx.arms_of[mid]
      list[#list + 1] = { id = a.e.unit_number, x = math.floor(a.e.position.x), y = math.floor(a.e.position.y),
        far = far and { x = math.floor(far.x), y = math.floor(far.y) } or nil, e = a.e, pe = a.pe }
    end
    local u = unit_of(f, a.e, role, memo)
    if u then u.machine = mid units[#units + 1] = u refs[u.id] = { e = a.e, pe = a.pe, ctx = ctx } end
  end
  return units, refs
end

--- Kit : pièces cibles au stock, par objet (objets distincts triés).
local function kit_of(f, units)
  local kit, seen, items = {}, {}, {}
  for _, u in ipairs(units) do
    if u.item and not seen[u.item] then seen[u.item] = true items[#items + 1] = u.item end
  end
  table.sort(items)
  for _, it in ipairs(items) do kit[it] = Stock.count(f, it) end
  return kit
end

--- Cases occupées autour du rectangle `rect` : entités de la couche objet (hors `own` : la machine et ses bras, et ce qui bouge) et tuiles
--- infranchissables ; { [Bl.key] = true }.
local function occupied_around(surface, rect, own)
  local occ = {}
  local area = { { rect.x - 1, rect.y - 1 }, { rect.x + rect.w + 1, rect.y + rect.h + 1 } }
  for _, o in ipairs(surface.find_entities_filtered({ area = area, collision_mask = Bur.OBJECT_LAYER })) do
    if o.valid and not (o.unit_number and own[o.unit_number]) and not Se.MOVING[o.type] then
      local bb = o.bounding_box
      for ty = math.floor(bb.left_top.y + 0.01), math.ceil(bb.right_bottom.y - 0.01) - 1 do
        for tx = math.floor(bb.left_top.x + 0.01), math.ceil(bb.right_bottom.x - 0.01) - 1 do occ[Bl.key(tx, ty)] = true end
      end
    end
  end
  for _, t in ipairs(surface.find_tiles_filtered({ area = area, collision_mask = Bur.OBJECT_LAYER })) do
    occ[Bl.key(math.floor(t.position.x), math.floor(t.position.y))] = true
  end
  return occ
end

--- Lot RETROFIT-GABARITS : une machine qui change d'emprise passe si sa cellule réservée l'accueille (Bu.fit sur l'occupation RELEVÉE) ;
--- sinon ajournée, cause « emprise » (u.cause). Note sur l'unité le rectangle cible (u.rect) et les bras à déplacer (u.moves).
local function fits(surface, u, ref)
  local ctx, e = ref.ctx, ref.e
  local cells, i = {}, nil
  for k, m in ipairs(ctx.machines) do
    cells[k] = { x = math.floor(m.x - m.w / 2 + 0.01), y = math.floor(m.y - m.h / 2 + 0.01), w = m.w, h = m.h }
    if m.id == u.id then i = k end
  end
  if not i then u.cause = "emprise" return false end
  local arms = ctx.arms_of[u.id] or {}
  local own = { [e.unit_number] = true }
  for _, a in ipairs(arms) do own[a.id] = true end
  local occ = occupied_around(surface, Bl.grown(cells[i], u.fp_target), own)
  local fit = Bu.fit(cells, i, u.fp_target, occ, arms)
  u.cause, u.moves, u.rect = fit.cause, fit.moves, fit.rect
  return fit.ok
end

--- Anti-collision d'une unité : remplacement rapide possible, sinon pose manuelle du nouveau palier à la même place ; une unité qui
--- grandit : sa cellule réservée (fits).
local function can_place(surface, f, u, ref)
  if Bu.grows(u) then return fits(surface, u, ref) end
  local e = ref.e
  local args = { name = u.target, position = e.position, direction = e.direction, force = f.force }
  if surface.can_fast_replace and surface.can_fast_replace(args) then return true end
  args.build_check_type = defines.build_check_type and defines.build_check_type.manual or nil
  return surface.can_place_entity(args) == true
end

--- Bras de l'équipe lus au catalogue des prototypes : { { name, reach (tuiles), speed, item } }, fabricables seulement (Bu.long_arm).
local function arm_catalog(f)
  local out = {}
  for _, n in ipairs(Cap.machine_names and Cap.machine_names() or {}) do
    local p = Cap.mproto(n)
    if p and p.type == R.RANG_REACH.type and p.reach and p.item and Cap.unlocked(f, p.item) then
      local px, py = p.reach:match("^([-%d.]+),([-%d.]+)>")
      local reach = math.floor(math.max(math.abs(tonumber(px) or 0), math.abs(tonumber(py) or 0)) + 0.5)
      out[#out + 1] = { name = n, reach = reach, speed = p.speed, item = p.item }
    end
  end
  return out
end

--- Déplace le bras `a` (relevé) en `mv` = { x, y, long } (Bu.arm_move) : bras long de l'équipe si exigé (objet pris au stock, ancien
--- rendu). Rend vrai si le bras suit, faux sinon (il reste où il est : l'unité l'a déjà passé, la machine est posée).
local function move_arm(f, surface, a, mv)
  local e = a.e
  if not (e and e.valid) then return false end
  local name = e.name
  if mv.long then
    name = Bu.long_arm(arm_catalog(f))
    if not name then return false end
  end
  local tp, op = Cap.mproto(name), Cap.mproto(e.name)
  if name ~= e.name then
    if not (tp and op and tp.item and op.item) or Stock.count(f, tp.item) < 1 then return false end
    Stock.remove(f, tp.item, 1)
  end
  local check = defines.build_check_type and defines.build_check_type.manual or nil
  local new = Se.swap(surface, f, e, name, { x = mv.x + 0.5, y = mv.y + 0.5, dir = e.direction, size = 1, check = check, keep_owner = true })
  if not new then
    if name ~= e.name then Stock.insert(f, tp.item, 1) end
    return false
  end
  if name ~= e.name then Stock.insert(f, op.item, 1) end
  a.e = new
  if a.pe then a.pe.x, a.pe.y = new.position.x, new.position.y end
  return true
end

--- Lot RETROFIT-GABARITS : remplacement à emprise différente par la primitive partagée (Se.swap) : objet cible pris au stock, ancien
--- rendu, contenu et recette rendus à la nouvelle (le reste au stock), pièce du plan renommée et déplacée, bras déplacés (u.moves, triés).
local function grow_one(f, surface, u, ref)
  local e = ref.e
  local tp, op = Cap.mproto(u.target), Cap.mproto(e.name)
  if not (tp and op) then return nil, "inconnue" end
  if not u.rect then return nil, "emprise" end
  if Stock.count(f, tp.item) < 1 then return nil, "objet" end
  local contents = Se.take(e)
  Stock.remove(f, tp.item, 1)
  local check = defines.build_check_type and defines.build_check_type.manual or nil
  local rect = u.rect
  local new, back = Se.swap(surface, f, e, u.target, { x = rect.x + rect.w / 2, y = rect.y + rect.h / 2, dir = e.direction,
    size = math.max(rect.w, rect.h), check = check, keep_owner = true })
  if not new then
    Stock.insert(f, tp.item, 1)
    local left = contents.items
    if back then ref.e = back left = Se.give(back, contents) else Stock.insert(f, op.item, 1) end
    for _, it in ipairs(left) do Stock.insert(f, it.name, it.count) end
    return nil, "echec"
  end
  Stock.insert(f, op.item, 1)
  if f.team and f.team.consumed then f.team.consumed[tp.item] = (f.team.consumed[tp.item] or 0) + 1 end
  for _, it in ipairs(Se.give(new, contents)) do Stock.insert(f, it.name, it.count) end
  ref.e = new
  if ref.pe then ref.pe.name, ref.pe.x, ref.pe.y = u.target, new.position.x, new.position.y end
  local ids = {}
  for id in pairs(u.moves or {}) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    for _, a in ipairs(ref.ctx.arms_of[u.id] or {}) do
      if a.id == id then move_arm(f, surface, a, u.moves[id]) end
    end
  end
  return new
end

--- Émission d'une tranche : chaque unité remplacée par la primitive du lot AMELIORER (ou, si elle grandit, par la primitive partagée du
--- lot FOREUSES). Rend (faites, motifs triés « motif xN »).
local function execute(f, surface, slice, refs)
  local done, why = 0, {}
  for _, u in ipairs(slice) do
    local ref = refs[u.id]
    local new, w = nil, "disparue"
    if ref and ref.e.valid then
      if Bu.grows(u) then new, w = grow_one(f, surface, u, ref) else new, w = Cap.replace_entity(f, ref.e, u.target) end
    end
    if new then
      done = done + 1
      local mp = Cap.mproto(u.target)
      if ref.pe and u.role == "machine" and not (mp and mp.rang) then ref.pe.name = u.target end
    else
      why[w or "?"] = (why[w or "?"] or 0) + 1
    end
  end
  local ks = {}
  for k in pairs(why) do ks[#ks + 1] = k end
  table.sort(ks)
  local parts = {}
  for _, k in ipairs(ks) do parts[#parts + 1] = k .. " x" .. why[k] end
  return done, parts
end

--- La box à rétrofiter : celle déjà en cours si elle l'est encore, sinon la première UPGRADE_REQUISE des sortes servies ; les états des
--- boxes sorties d'UPGRADE_REQUISE sont oubliés.
local function pick_box(t, list)
  local rs = t.retrofit or {}
  t.retrofit = rs
  local by = {}
  for _, b in ipairs(list) do if Bur.KINDS[b.kind] and b.status == Bx.UPGRADE_REQUISE then by[Bu.key(b)] = b end end
  local ks = {}
  for k in pairs(rs) do ks[#ks + 1] = k end
  table.sort(ks)
  local cur = nil
  for _, k in ipairs(ks) do
    if by[k] then cur = cur or by[k] else rs[k] = nil end
  end
  if cur then return cur end
  for _, b in ipairs(list) do if by[Bu.key(b)] then return b end end
  return nil
end

--- Journal et état d'une impulsion sur la box.
local function record(f, t, box, st, slice, plan, done, parts, tick)
  local key = Bu.key(box)
  local causes = Bu.deferred_causes(plan)
  st.deferred = causes.place
  st.deferred_emprise = causes.emprise
  st.waiting_item = plan.waiting and plan.waiting.item or nil
  st.waiting_n = plan.waiting and plan.waiting.manque or nil
  st.t0 = st.t0 or tick
  t.retrofit[key] = st
  local k = slice and st.i or (st.i + 1) -- tranche faite, ou celle qui attend
  local line = Bu.line(key_of(f), box, k, st.n, slice, st.deferred, plan.waiting, done, st.deferred_emprise)
  if parts and #parts > 0 then line = line .. " ; refus : " .. table.concat(parts, ", ") end
  log(line .. string.format(" a %.1f min", tick / 3600))
end

--- Impulsion : une tranche du rétrofit d'UNE box UPGRADE_REQUISE de l'équipe `f` (appelée à la fin du relevé des boxes).
function Bur.impulsion(f, surface, tick)
  local t = f.team
  if not (t and t.boxes and t.boxes.list and Bur.bound()) then return end
  local box = pick_box(t, t.boxes.list)
  if not box or threat(f, surface) then return end
  local key = Bu.key(box)
  local units, refs = survey(f, surface, box)
  local kit = kit_of(f, units)
  local plan = Bu.plan(box, units, kit, Bu.CFG)
  local st = t.retrofit[key] or { i = 0, n = 0, done = 0 }
  if plan.status == Bu.MAXED then
    if t.retrofit[key] then
      log(string.format("[FO-RETROFIT] %s : box %s %s : rien a monter (%d tranches, %d unites remplacees) a %.1f min", key_of(f),
        tostring(box.kind), tostring(box.id), st.i, st.done, tick / 3600))
    end
    t.retrofit[key] = nil
    return
  end
  local first = plan.slices[1]
  if not first then
    st.n = st.i + plan.total
    record(f, t, box, st, nil, plan, nil, nil, tick)
    return
  end
  for _, u in ipairs(first) do u.can_place = can_place(surface, f, u, refs[u.id]) end
  plan = Bu.plan(box, units, kit, Bu.CFG)
  local slice = plan.slices[1]
  if not slice then
    st.n = st.i + plan.total
    record(f, t, box, st, nil, plan, nil, nil, tick)
    return
  end
  local done, parts = execute(f, surface, slice, refs)
  local nxt = Bu.next(st, done)
  nxt.n = nxt.i - 1 + plan.total
  record(f, t, box, nxt, slice, plan, done, parts, tick)
end

return Bur
