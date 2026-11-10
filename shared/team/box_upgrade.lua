--[[
  Lot BOX-UPGRADE (directive du DC du 9/11) : RÉTROFIT INCRÉMENTAL des boxes. « Interdiction de déconstruire une fonderie ou un mall
  pour le refaire ; quand une box passe UPGRADE_REQUISE (nouveau four, assembleur, bras), rétrofit GLISSANT par tranches de 2 à 4
  machines, la box reste EN_COURS et produit sur les tranches non touchées ; remplacement synchronisé machine -> bras d'entrée/sortie ->
  poteau ; priorité dans une box : 1. goulot d'évacuation (bras de sortie, convoyeur d'évacuation), 2. machine, 3. alimentation ;
  zéro inactivité : si le kit d'upgrade manque, la machine actuelle continue ; anti-collision : une unité qui ne passe pas est
  ajournée sans bloquer la box. »
  Règles PURES (aucun moteur, aucun nom d'objet du jeu : tests/box_upgrade_test.lua) ; le moteur est script/team/box_upgrade_rt.lua.

  Entrées de Bu.plan(box, units, kit, cfg) :
    units = { { id, role ("sortie" | "machine" | "entree" | "poteau"), tier_now, tier_target (vitesses lues aux prototypes), item (objet
      du palier cible, 1 par unité), can_place (vrai, faux ou nil = pas encore mesuré), machine (id de la machine servie par un bras ou
      un poteau ; nil = unité « orpheline » : convoyeur d'évacuation, bras de quai…), x, y } } ;
    kit = { [item] = n } : les pièces du palier cible disponibles au stock ;
    cfg = { slice = machines par tranche (2 à 4, Bu.CFG.slice par défaut) }.
  Règles :
    1. Une unité est À MONTER si tier_target > tier_now ; sinon elle est ignorée (déjà au palier). Aucune unité à monter : MAXED.
    2. TRANCHE = `slice` machines (triées par id) AVEC leurs bras et leur poteau (« paire » : 2 machines + 4 bras = une unité de
       production complète, remplacée d'un bloc pour que l'entrée et la sortie suivent la vitesse de la machine ; le reste de la box
       produit pendant ce temps). Dans la tranche, ordre du DC : sortie -> machine -> entree -> poteau, puis id.
    3. Les unités ORPHELINES forment leurs propres tranches (2 × slice unités) : les sorties AVANT les paires (goulot d'évacuation),
       les entrées et les poteaux APRÈS.
    4. can_place == false : l'unité est AJOURNÉE (liste `deferred`) et la tranche continue sans elle ; une tranche vidée disparaît.
       Rien n'est jamais bloqué par une unité ajournée.
    5. KIT : une tranche n'est émise que si le kit la paie ENTIÈREMENT (1 objet par unité) ; la première tranche impayable arrête
       l'émission : `waiting = { item, manque }` (la machine actuelle continue). `total` compte toutes les tranches, payables ou non.
  Bu.next(state, done) : avance d'une tranche, état en nombres { i, n, done } ; rend un NOUVEL état (déterministe, sans effet de bord).
  Déterminisme : tri par rôle puis id, `pairs` seulement pour ramasser des clés ensuite triées ; aucun temps ; aucune fonction stockée.
  Lot RETROFIT-GABARITS (décision du DC du 10/11, fin du fichier) : unités dont le palier cible a une EMPRISE plus grande (fp_now, fp_target) :
  Bu.grows, Bu.grown_successors (cibles que Cap.successors exclut), Bu.fit (la cellule réservée l'accueille : Bl.grow sur l'occupation
  relevée, bras suivis par Bu.arm_move), ajournement à cause « emprise » (u.cause, compté par Bu.deferred_causes, dit par Bu.line).
]]

local Bl = require("shared.team.box_layout")

local Bu = {}

Bu.EN_COURS, Bu.MAXED = "EN_COURS", "MAXED"
Bu.ROLES = { "sortie", "machine", "entree", "poteau" } -- ordre de priorité du DC
Bu.RANK = { sortie = 1, machine = 2, entree = 3, poteau = 4 }
Bu.CFG = { slice = 2, slice_min = 2, slice_max = 4 }

--- L'unité a-t-elle un palier à monter ?
function Bu.todo(u)
  return u ~= nil and u.tier_now ~= nil and u.tier_target ~= nil and u.tier_target > u.tier_now
end

--- Clé d'une box (état f.team.retrofit[clé]).
function Bu.key(box) return tostring(box.kind) .. ":" .. tostring(box.id) end

--- Comparaison d'identifiants (nombres entre eux, sinon chaînes) : jamais une erreur de type.
local function id_lt(a, b)
  if type(a) == "number" and type(b) == "number" then return a < b end
  return tostring(a) < tostring(b)
end

--- Ordre dans une tranche : rang du rôle, puis id.
local function by_priority(a, b)
  local ra, rb = Bu.RANK[a.role] or 9, Bu.RANK[b.role] or 9
  if ra ~= rb then return ra < rb end
  return id_lt(a.id, b.id)
end

--- Machines par tranche, bornées à [slice_min, slice_max].
local function per_slice(cfg)
  local n = (cfg and cfg.slice) or Bu.CFG.slice
  if n < Bu.CFG.slice_min then n = Bu.CFG.slice_min end
  if n > Bu.CFG.slice_max then n = Bu.CFG.slice_max end
  return n
end

--- Découpe `list` (déjà ordonnée) en tranches de `size` unités, ajoutées à `out`.
local function cut(out, list, size)
  local cur = nil
  for _, u in ipairs(list) do
    if not cur or #cur >= size then cur = {} out[#out + 1] = cur end
    cur[#cur + 1] = u
  end
end

--- Tri des unités à monter : machines (par id), satellites par machine servie, orphelines par rôle.
local function split(units)
  local machines, sat, orphans = {}, {}, { sortie = {}, entree = {}, poteau = {} }
  local ids = {}
  for _, u in ipairs(units or {}) do
    if Bu.todo(u) then
      if u.role == "machine" then machines[#machines + 1] = u ids[u.id] = true end
    end
  end
  for _, u in ipairs(units or {}) do
    if Bu.todo(u) and u.role ~= "machine" then
      if u.machine ~= nil and ids[u.machine] then
        sat[u.machine] = sat[u.machine] or {}
        sat[u.machine][#sat[u.machine] + 1] = u
      elseif orphans[u.role] then
        orphans[u.role][#orphans[u.role] + 1] = u
      else
        orphans.entree[#orphans.entree + 1] = u -- rôle inconnu : traité comme une alimentation (dernier)
      end
    end
  end
  table.sort(machines, function(a, b) return id_lt(a.id, b.id) end)
  for _, k in ipairs(Bu.ROLES) do if orphans[k] then table.sort(orphans[k], by_priority) end end
  return machines, sat, orphans
end

--- Toutes les tranches dans l'ordre du DC (sans le kit ni l'ajournement) : sorties orphelines, paires, entrées et poteaux orphelins.
local function all_slices(units, cfg)
  local per = per_slice(cfg)
  local machines, sat, orphans = split(units)
  local out = {}
  cut(out, orphans.sortie, 2 * per)
  local cur = nil
  for i, m in ipairs(machines) do
    if (i - 1) % per == 0 then cur = {} out[#out + 1] = cur end
    cur[#cur + 1] = m
    for _, s in ipairs(sat[m.id] or {}) do cur[#cur + 1] = s end
  end
  for _, s in ipairs(out) do table.sort(s, by_priority) end
  cut(out, orphans.entree, 2 * per)
  cut(out, orphans.poteau, 2 * per)
  return out
end

--- Retire les unités `can_place == false` d'une tranche (ajournées) ; rend la tranche réduite (ou nil si vide).
local function defer(slice, deferred)
  local keep = {}
  for _, u in ipairs(slice) do
    if u.can_place == false then deferred[#deferred + 1] = u else keep[#keep + 1] = u end
  end
  if #keep == 0 then return nil end
  return keep
end

--- Le kit paie-t-il la tranche entière ? Rend vrai (et débite), ou faux et { item, manque } (premier objet manquant, par nom).
local function pay(slice, kit)
  local need = {}
  for _, u in ipairs(slice) do
    local it = u.item or "?"
    need[it] = (need[it] or 0) + 1
  end
  local items = {}
  for it in pairs(need) do items[#items + 1] = it end
  table.sort(items)
  for _, it in ipairs(items) do
    if (kit[it] or 0) < need[it] then return false, { item = it, manque = need[it] - (kit[it] or 0) } end
  end
  for _, it in ipairs(items) do kit[it] = kit[it] - need[it] end
  return true, nil
end

--- Plan d'un rétrofit glissant : { slices (payées, dans l'ordre), total (tranches à faire, payées ou non), deferred, waiting, status, todo }.
function Bu.plan(box, units, kit, cfg)
  local rest = {} -- copie du kit (le kit de l'appelant n'est pas débité) ; ramassage des clés sans décision sur leur ordre
  for k, n in pairs(kit or {}) do rest[k] = n end
  local deferred, slices, waiting, total, todo = {}, {}, nil, 0, 0
  for _, u in ipairs(units or {}) do if Bu.todo(u) then todo = todo + 1 end end
  if todo == 0 then return { slices = {}, total = 0, deferred = {}, waiting = nil, status = Bu.MAXED, todo = 0 } end
  for _, s in ipairs(all_slices(units, cfg)) do
    local kept = defer(s, deferred)
    if kept then
      total = total + 1
      if not waiting then
        local ok, w = pay(kept, rest)
        if ok then slices[#slices + 1] = kept else waiting = w end
      end
    end
  end
  table.sort(deferred, by_priority)
  return { slices = slices, total = total, deferred = deferred, waiting = waiting, status = Bu.EN_COURS, todo = todo }
end

--- Avance d'une tranche : rend un NOUVEL état { i = tranche courante (faites), n, done, t0 } ; `done` = unités remplacées à cette tranche.
function Bu.next(state, done)
  local s = state or { i = 0, n = 0, done = 0 }
  return { i = (s.i or 0) + 1, n = s.n or 0, done = (s.done or 0) + (done or 0), t0 = s.t0 }
end

--- Comptes d'une tranche : machines, bras (sortie + entree), poteaux.
function Bu.counts(slice)
  local m, b, p = 0, 0, 0
  for _, u in ipairs(slice or {}) do
    if u.role == "machine" then m = m + 1 elseif u.role == "poteau" then p = p + 1 else b = b + 1 end
  end
  return m, b, p
end

--- Ligne de journal [FO-RETROFIT] d'une tranche (ou d'une attente : slice nil). n_deferred : ajournées faute de place ; n_emprise
--- (facultatif) : ajournées parce que leur cellule réservée n'accueille pas la nouvelle emprise (lot RETROFIT-GABARITS).
function Bu.line(team, box, k, n, slice, n_deferred, waiting, done, n_emprise)
  local body
  if slice then
    local m, b, p = Bu.counts(slice)
    body = string.format("tranche %d/%d (%d machines, %d bras%s%s)", k, n, m, b, p > 0 and (", " .. p .. " poteaux") or "",
      done ~= nil and (", " .. done .. " remplacees") or "")
  else
    body = string.format("tranche %d/%d non emise", k, n)
  end
  local extra = ""
  if (n_deferred or 0) > 0 then extra = extra .. string.format(", ajournees %d (place)", n_deferred) end
  if (n_emprise or 0) > 0 then extra = extra .. string.format(", ajournees %d (emprise)", n_emprise) end
  if waiting then extra = extra .. string.format(", en attente de %s x%d", tostring(waiting.item), waiting.manque or 0) end
  return string.format("[FO-RETROFIT] %s : box %s %s : %s%s", tostring(team), tostring(box.kind), tostring(box.id), body, extra)
end

---------------------------------------------------------------------------------------------------
-- Lot RETROFIT-GABARITS (décision du DC : « rétrofit glissant à gabarits évolutifs : gérer les emprises distinctes (2×2 → 3×3) lors du
-- passage aux fours électriques ou assembleurs supérieurs, par réservation d'espace ») : règles PURES de l'unité qui change d'EMPRISE.
-- Une telle unité est traitée si et seulement si sa cellule réservée l'accueille (Bl.grow sur l'occupation relevée : tapis, poteaux,
-- bras, autres machines ; shared/team/box_layout.lua) ; sinon elle est AJOURNÉE, cause « emprise » (jamais bloquante). Ses bras suivent
-- la ligne d'interface de la cellule cible : déjà là s'ils ont été posés par le nouveau gabarit ; sinon déplacés dans la même tranche
-- (Bu.arm_move), bras long si la portée l'exige ; un bras qui ne peut pas suivre ajourne l'unité.
---------------------------------------------------------------------------------------------------

--- L'unité change-t-elle d'emprise (palier cible plus grand que l'actuel sur un axe) ? fp_now, fp_target = { w, h } (tuiles).
function Bu.grows(u)
  local a, b = u and u.fp_now, u and u.fp_target
  if not (a and b) then return false end
  return (b.w or 0) > (a.w or 0) or (b.h or 0) > (a.h or 0)
end

--- Catégories de `small` toutes dans `big` (tables { [cat] = true }) ; vide ou nil : couvert.
local function covers(big, small)
  for k in pairs(small or {}) do if not (big or {})[k] then return false end end
  return true
end

--- Successeurs à emprise PLUS GRANDE de `name` (ceux que Cap.successors exclut : le remplacement rapide refuse une autre emprise), triés
--- (vitesse, puis nom) : même type, même portée, catégories couvertes, vitesse strictement supérieure, emprise ≥ par axe et > sur un axe,
--- énergie identique ou passage au tout-électrique (le four électrique du DC) ; les niveaux > 1 des familles à niveaux restent au système
--- des niveaux (ctx.parse, même règle que Cap.successors). ctx = { mproto(name) -> { type, w, h, speed, item, energy, cats, reach },
--- machines = noms (ordre sans effet), parse(name) -> famille, niveau (facultatif) }.
function Bu.grown_successors(ctx, name)
  local p0 = ctx and ctx.mproto and ctx.mproto(name)
  if not (p0 and (p0.speed or 0) > 0) then return {} end
  local out = {}
  for _, t in ipairs(ctx.machines or {}) do
    local p1 = (t ~= name) and ctx.mproto(t) or nil
    if p1 and p1.item and p1.type == p0.type and (p1.speed or 0) > p0.speed and p1.reach == p0.reach
        and (p1.w or 0) >= (p0.w or 0) and (p1.h or 0) >= (p0.h or 0) and ((p1.w or 0) > (p0.w or 0) or (p1.h or 0) > (p0.h or 0))
        and (p1.energy == p0.energy or p1.energy == "electric") and covers(p1.cats, p0.cats) then
      local fam, n = nil, nil
      if ctx.parse then fam, n = ctx.parse(t) end
      if fam == nil or n == 1 then out[#out + 1] = t end
    end
  end
  table.sort(out, function(a, b)
    local sa, sb = ctx.mproto(a).speed, ctx.mproto(b).speed
    if sa ~= sb then return sa < sb end
    return a < b
  end)
  return out
end

--- Le bras long d'une liste de bras { { name, reach (tuiles, nombre) } } : le plus lent des bras de portée Bl.REACH_LONG (vitesse `speed`
--- croissante, puis nom), ou nil. Rien n'est nommé ici : la liste vient des prototypes.
function Bu.long_arm(arms)
  local best
  for _, a in ipairs(arms or {}) do
    if a.name and (a.reach or 0) >= Bl.REACH_LONG then
      if not best or (a.speed or 0) < (best.speed or 0) or ((a.speed or 0) == (best.speed or 0) and a.name < best.name) then best = a end
    end
  end
  return best and best.name or nil
end

--- Déplacement d'un bras de l'unité quand la machine grandit de `cell` (emprise actuelle, tuiles) à `rect` (Bl.grown) : un bras HORS du
--- rectangle cible reste (nil) ; un bras dedans est poussé sur la ligne d'interface du rectangle, dans son axe (le côté sud ou est, la
--- croissance va au sud-est) : rend { x, y, long } si, de là, il atteint encore son autre cible `far` (tapis, { x, y }) à portée courte
--- ou longue, sinon `false` (unité à ajourner). Pur : aucune occupation testée ici (Bu.fit s'en charge).
function Bu.arm_move(arm, cell, rect)
  local inside = arm.x >= rect.x and arm.x < rect.x + rect.w and arm.y >= rect.y and arm.y < rect.y + rect.h
  if not inside then return nil end
  local nx, ny = arm.x, arm.y
  if arm.y >= cell.y + cell.h then ny = rect.y + rect.h          -- bras au sud de la machine : ligne d'interface sud
  elseif arm.x >= cell.x + cell.w then nx = rect.x + rect.w      -- bras à l'est : ligne d'interface est
  else return false end                                          -- bras dans l'ancienne emprise (relevé incohérent) : refus
  local far = arm.far
  if not far then return false end
  local reach = math.max(math.abs(far.x - nx), math.abs(far.y - ny))
  if reach < 1 or reach > Bl.REACH_LONG then return false end
  return { x = nx, y = ny, long = reach >= Bl.REACH_LONG }
end

--- Une case est-elle libre pour un bras déplacé : hors de `occupied`, du rectangle cible et des autres cellules ?
local function free_for_arm(p, rect, cells, i, occupied)
  if occupied[Bl.key(p.x, p.y)] then return false end
  if p.x >= rect.x and p.x < rect.x + rect.w and p.y >= rect.y and p.y < rect.y + rect.h then return false end
  for j, c in ipairs(cells) do
    if j ~= i and p.x >= c.x and p.x < c.x + c.w and p.y >= c.y and p.y < c.y + c.h then return false end
  end
  return true
end

--- DÉCISION D'EMPRISE d'une unité qui grandit : `cells` = emprises relevées (tuiles entières { x, y, w, h }) des machines de la box, `i`
--- la machine, `new_size` = fp_target, `occupied` = { [Bl.key] = true } des cases prises (tapis, poteaux, bras d'autres unités, autres
--- entités, tuiles infranchissables ; JAMAIS la machine ni ses propres bras : ils sont dans `arms`), `arms` = ses bras { { id, x, y,
--- far = { x, y } } }. Rend { ok, rect, conflits (clés triées), moves = { [id] = { x, y, long } } (bras à déplacer, triés par id à
--- l'émission), cause = "emprise" quand ok est faux }. Déterministe ; aucun moteur.
function Bu.fit(cells, i, new_size, occupied, arms)
  occupied = occupied or {}
  local ok, conflits = Bl.grow(cells, i, new_size, occupied)
  local rect = Bl.grown(cells[i], new_size)
  local out = { ok = ok, rect = rect, conflits = conflits, moves = {} }
  for _, a in ipairs(arms or {}) do
    local mv = Bu.arm_move(a, cells[i], rect)
    if mv == false or (mv and not free_for_arm(mv, rect, cells, i, occupied)) then
      out.ok = false
      out.conflits[#out.conflits + 1] = "bras " .. tostring(a.id)
    elseif mv then
      out.moves[a.id] = mv
    end
  end
  if not out.ok then out.cause = "emprise" end
  return out
end

--- Les causes d'ajournement d'un plan, comptées : { place = n, emprise = n }.
function Bu.deferred_causes(plan)
  local c = { place = 0, emprise = 0 }
  for _, u in ipairs(plan and plan.deferred or {}) do
    local k = u.cause == "emprise" and "emprise" or "place"
    c[k] = c[k] + 1
  end
  return c
end


return Bu
