--[[
  Lot MALL, tranche 2 (docs/MALL.md §2.2, §2.4, §3, §4) : côté RUNTIME de la rangée du mall (règle pure : shared/team/mall_rangee.lua). Factions ET votre équipe : même
  règle, aucune branche sur f.is_player. Réglage fo-war-mall (script/team/mall.lua, Mall.on).

  Chaîne : 1. DÉCLENCHEUR : l'état S du mall (b.mall.pret, script/team/mall.lua) est vrai et le secteur est choisi, et Ind.think (script/ai3/industrie.lua) a un bloc ou une
  cellule à poser (objets qui manquent) ; 2. DÉCISION : Rt.accueille range ces objets dans une rangée du mall (celle qui a leurs entrées sur ses voies, sinon une rangée
  neuve, Mr.voies, Mr.ajouts) au lieu d'un module isolé ; 3. ACTION : un projet du plan directeur par SECTION (Build.request, site « mall », planifié par Rt.plan) : tête
  et cellules (motif du catalogue), chantier ordinaire (réserve, défrichage, fantômes, PNJ) ; 4. EFFET : la rangée fabrique, ses coffres de sortie sont collectés par les
  PNJ (p.outs) et ses quais remplis (p.quais) ; Rt.minute relit les compteurs (products_finished) : [FO-MALL] ... PRODUCTION.
  ALLONGER : Rt.minute (une fois par décision) ajoute des cellules quand la demande (Ml.sources) dépasse les machines de la rangée ; une section refusée par le terrain arrête la rangée
  (row.stop = cause, cellules rendues), ses objets redeviennent candidats (une autre rangée, sinon un module isolé).
  Raccord au courant : la section de tête d'une rangée est reliée au réseau alimenté par le raccord des bandes du champ (Champ._raccord_tous) ; ses sections suivantes
  continuent les poteaux de la rangée.
  État : b.mall.rows = { { j, voies, cells = { h, b, ih, ib, m }, projects = { { id, from, to } }, stop } }, b.mall.rep = { ox, oy, k }, nombres, chaînes, tables seulement.
]]

local Mr = require("shared.team.mall_rangee")
local Mt = require("shared.team.mall_tronc") -- tranche 3 : le tronc et les prises
local Sd = require("shared.team.serie_dirs") -- lot MALL-DIRECTIONS : noms des directions
local Ma = require("shared.team.mall_allonge") -- allongement au-delà de la demande, au surplus de matière
local Liq = require("shared.team.mall_liquidation") -- lot MALL-LIQUIDATION : le stock de machines qui dort paie une section de plus (réserve 20 %)
local Cat = require("shared.team.motifs.catalogue")
local P = require("shared.team.plan")
local Pu = require("shared.team.purete")
local A = require("shared.ai3.automatiser")
local Id = require("shared.ai3.industrie")
local T = require("shared.team.config")
local Ml = require("shared.ai3.mall")
local Build = require("script.team.build")
local State = require("script.faction.state")
local Events = require("script.core.events")
local Voulues = require("script.ai3.voulues") -- tranche 3 : le mall demande les objets de ses prises (répartiteur, souterrain)

local Rt = {}

Rt.MAX_NEW = 8             -- machines ajoutées au plus par demande
Rt.LOGS = 400              -- lignes de ce module au plus, par équipe (journal [FO-MALL])
Rt.RETRY_TICKS = 5 * 3600  -- délai avant de reposer une section refusée sans cause de terrain

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

local function who(f) return f.key or "player" end
local function say(f, st, tick, text)
  st.rlogs = (st.rlogs or 0) + 1
  if st.rlogs > Rt.LOGS then return end
  log(string.format("[FO-MALL] %s : %s a %.1f min", who(f), text, tick / 3600))
end

local MODELE
local function modele()
  if not MODELE then
    local inst = Cat.instancier(Mr.MOTIF, 1, { rot = 0, miroir = false })
    MODELE = assert(Mr.modele(inst.pieces))
  end
  return MODELE
end

local ITEM_CACHE = {}
local function item_of(name)
  local it = ITEM_CACHE[name]
  if it == nil then
    local pr = game.entity_prototypes[name]
    it = (pr and pr.items_to_place_this and pr.items_to_place_this[1] and pr.items_to_place_this[1].name) or name
    ITEM_CACHE[name] = it
  end
  return it
end

local function size(name, dir) return P.size(name, dir) end

--- La rangée du mall peut-elle recevoir des objets ? (état S vrai, ou forcé par un banc)
function Rt.ouvert(f)
  local b = f and f.build
  local st = b and b.mall
  if not (st and st.sect and Build.Mall.on()) then return false end
  return st.pret == true or st.force_pret == true or st.partiel ~= nil
end

local function repere(st, f)
  if not st.rep then
    local west, north = Mr.TETE, 0
    if Build.Mall.tronc_on and Build.Mall.tronc_on() then west, north = Mt.WEST, Mt.NORTH end
    local ox, oy = Mr.origin(st.sect, west, north)
    st.rep = { ox = ox, oy = oy, k = Mr.frame(st.sect.dir), west = west, north = north }
  end
  st.rows = st.rows or {}
  return st.rep
end

--- Objets servis par le mall (prévus ou posés) : { [objet] = vrai }.
function Rt.served(f)
  local out = {}
  local st = f and f.build and f.build.mall
  for _, r in ipairs(st and st.rows or {}) do
    for _, c in ipairs(r.cells) do
      if c.ih then out[c.ih] = true end
      if c.ib then out[c.ib] = true end
    end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Planification (crochet de Build, spec.site = « mall »)
---------------------------------------------------------------------------------------------------
Build.SITES = Build.SITES or {}

--- (lay) ou (nil, raison, attendre) : le plan de la section p.spec.mall = { row, from, to, head, names }.
Build.SITES.mall = function(f, surface, p, h)
  local b = f.build
  local st = b.mall
  local sp = p.spec.mall
  local row = st and st.rows and st.rows[sp.row]
  if not (row and st.rep) then return nil, "mall : rangee inconnue" end
  -- une section précédente refusée rend les cellules suivantes (Rt.minute) : celles de ce projet peuvent ne plus exister (plantage de la carte à 600 %, graine 271828182 : « cell nil », 57 min)
  for i = sp.from, sp.to do
    if not row.cells[i] then return nil, "mall : cellules rendues" end
  end
  local extra = nil
  if sp.bus and sp.lines then extra = Mt.section(sp.lines, row, sp.names) end
  -- lot MALL-DIRECTIONS : au-delà du secteur, les rues du treillis sont franchies par un souterrain par tapis (rien sur la rue) ; sans souterrain
  -- débloqué, la section qui devrait franchir est refusée « obstacle:rue » (la rangée s'arrête, comme au bout du secteur)
  local serie, swhy = Rt.serie_of(f, st, row, sp.to, sp.names.souterrain)
  if not serie then return nil, "obstacle:rue (" .. tostring(swhy) .. ")" end
  local franchit = 0
  for _, t in ipairs(serie.trav) do if t.avant >= sp.from and t.avant <= sp.to then franchit = franchit + 1 end end
  if franchit > 0 and not sp.names.souterrain then return nil, "obstacle:rue (souterrain non debloque)" end
  -- au-delà du secteur, chaque cellule doit tomber dans un lot CONNU du treillis (b.lots) : jamais dans un chunk que personne n'a relevé
  local cap = Rt.cap_secteur(st)
  for i = math.max(sp.from, cap + 1), sp.to do
    local a = (i - 1) * Mr.PERIODE + (serie.shift[i] or 0)
    local wx, wy = Mr.to_world(a + 1.5, Mr.YA + 0.5, nil, st.rep.k, st.rep.ox, st.rep.oy, row.j)
    local li, lj = P.lot_at(b.lat, floor(wx), floor(wy))
    if not (li and b.lots and b.lots[P.lot_key(li, lj)]) then return nil, string.format("obstacle:treillis (cellule %d hors des lots connus en (%d, %d))", i, floor(wx), floor(wy)) end
  end
  local sec = Mr.section(P, modele(), row, sp.from, sp.to, sp.names, st.rep, sp.head == true, extra, serie)
  if franchit > 0 then
    local t1 = nil
    for _, t in ipairs(serie.trav) do if t.avant >= sp.from and t.avant <= sp.to then t1 = t1 or t end end
    say(f, st, game.tick, string.format("serie : section %d-%d de la rangee %d franchit %d rue(s) en souterrain (%s, 2 voies), direction %s : entree canonique %d, sortie %d (projet %d)",
      sp.from, sp.to, row.j, franchit, tostring(sp.names.souterrain), Sd.NOM[st.sect.dir] or "?", t1.a_in, t1.a_out, p.id))
  end
  local bx = Mr.box(sec.ents, size)
  local masks = h.read_masks(bx[1] - 2, bx[2] - 2, bx[3] + 3, bx[4] + 3)
  for _, e in ipairs(sec.ents) do
    for _, t in ipairs(P.tiles_of(e)) do
      local k = P.tkey(t[1], t[2])
      local occ = b.occ[k]
      if occ and occ ~= Build.Mall.OCC and occ ~= p.id then return nil, string.format("obstacle:reserve en (%d, %d)", t[1], t[2]) end
      if masks.water[k] then return nil, string.format("obstacle:eau en (%d, %d)", t[1], t[2]) end
      if masks.blocked[k] then return nil, string.format("obstacle:batiment en (%d, %d)", t[1], t[2]) end
    end
  end
  -- pureté (shared/team/purete.lua, script/team/purete.lua) : chaque tapis de la section porte ses objets déclarés ; aucun tapis étranger ne verse dessus, il ne verse sur aucun
  if Build.Pur and surface then
    local own = {}
    for _, e in ipairs(sec.ents) do
      for _, t in ipairs(P.tiles_of(e)) do own[Pu.tkey(t[1], t[2])] = true end
    end
    for k = 1, 2 do
      local okp, whyp = Build.Pur.check_route(f, surface, p, "mall", sec.lines[k], sec.carries[k], {}, { own = own })
      if not okp then return nil, "purete : " .. tostring(whyp) end
    end
    for _, r in ipairs(sec.routes or {}) do -- le tronc et les prises
      local okp, whyp = Build.Pur.check_route(f, surface, p, "mall", r.tiles, r.item, {}, { own = own })
      if not okp then return nil, "purete : " .. tostring(whyp) end
    end
  end
  -- raccord au réseau alimenté (section de tête : la rangée suivante se branche sur la précédente ou sur le réseau)
  -- une rangée dont la précédente vit se branche par son poteau relais, même si la précédente n'est pas encore bâtie : chercher le réseau pour elle la faisait refuser (partie tronc-partie-30bfce34,
  -- azure rangée 2 : la cible était un poteau de la rangée 1, en chantier)
  local relais_ok = false
  if row.j > 1 then
    for _, q in ipairs((st.rows[row.j - 1] or {}).projects or {}) do
      local pp = b.projects[q.id]
      if q.from == 1 and not q.dead and pp and pp.state ~= "refuse" then relais_ok = true end
    end
  end
  if (sp.head or (sp.bus and sp.from == 1)) and not st.sans_raccord and not relais_ok then
    local poles = {}
    for _, e in ipairs(sec.ents) do if e.role == "mall-poteau" then poles[#poles + 1] = e end end
    if #poles == 0 then return nil, "mall raccord : aucun poteau dans la section" end -- (sans poteau, raccord_tous rendrait 0 : la section passerait sans courant)
    local cx, cy = 0, 0
    for _, e in ipairs(poles) do cx, cy = cx + e.x, cy + e.y end
    cx, cy = cx / #poles, cy / #poles
    local bd = { spec = { pole = { wire = P.wire(sp.names.poteau) or 7.5 }, mine = {}, ore = {} }, names = { pole = sp.names.poteau },
      plan = { bands = {}, pitch = 0, axis = "x" } }
    local rep_s = st.rep
    bd.occ_libre = function(x, y, owner)
      if owner ~= Build.Mall.OCC then return false end
      local rx, ry = Mr.from_world(x + 0.5, y + 0.5, rep_s.k, rep_s.ox, rep_s.oy)
      rx, ry = floor(rx), floor(ry)
      if Mr.reserve_libre(rx, ry, rep_s.west or Mr.TETE, rep_s.north or 0) then return true end
      -- (s41 raccord-mall) avec le tronc, la place du tronc (16 tuiles entre les têtes et la base) murait le raccord : ses tuiles que le tronc n'utilise jamais sont ouvertes à la chaîne
      return rep_s.west == Mt.WEST and rep_s.north == Mt.NORTH and Mt.place_libre(rx, ry)
    end
    local Champ = package.loaded["script.team.champ"] -- (lecture : champ.lua est chargé par le plan directeur ; aucun require pendant un événement, F24)
    if not Champ then return nil, "mall raccord : champ non charge", true end
    local n, why, wait = Champ._raccord_tous(f, surface, bd, sec.ents, cx, cy, p)
    if not n then return nil, "mall raccord : " .. tostring(why), wait end
    -- (raccord_tous ajoute des pièces role « liaison »)
    bx = Mr.box(sec.ents, size)
    masks = h.read_masks(bx[1] - 2, bx[2] - 2, bx[3] + 3, bx[4] + 3)
  end
  -- les tuiles de ce plan quittent la réserve du secteur
  for _, e in ipairs(sec.ents) do
    for _, t in ipairs(P.tiles_of(e)) do
      local k = P.tkey(t[1], t[2])
      if b.occ[k] == Build.Mall.OCC then b.occ[k] = nil end
    end
  end
  return { key = "mall-rangee-" .. row.j, box = bx, ents = sec.ents, quais = sec.quais, outs = sec.outs, masks = masks, out_at = 50 }
end

-- Réinscription des machines du kit au chargement (M.BASE repart de ses données ; comme Events.on_load de script/ai3/industrie.lua).
Events.on_load(function()
  pcall(function()
    local list = { State.faction("player") }
    for _, id in ipairs(State.alive()) do list[#list + 1] = State.faction(id) end
    for _, f in ipairs(list) do
      local b = f.build
      for _, pid in ipairs(b and b.order or {}) do
        local sp = b.projects[pid] and b.projects[pid].spec and b.projects[pid].spec.mall
        if sp and sp.decl then A.declare(sp.decl) end
      end
    end
  end)
end)

---------------------------------------------------------------------------------------------------
-- Décision
---------------------------------------------------------------------------------------------------
--- La machine la moins rapide utilisable pour l'entrée `e` de la lecture (lecture.lua : `machines`), départage par nom : une rangée se paie en machines (partie neuve
--- t2-neuve90-a31ce386 : 12 assembling-machine-2 demandées à 72 min, réserve « materiaux » sans fin) ; une machine plus rapide n'est pas ce qui manque à une rangée qu'on allonge.
local function cheap(e, usable)
  local best
  for _, m in ipairs(e and e.machines or {}) do
    if not usable or usable(m.item) then
      if not best or (m.par_min or 0) < (best.par_min or 0) or ((m.par_min or 0) == (best.par_min or 0) and m.entity < best.entity) then best = m end
    end
  end
  return best
end

--- Machines voulues pour un objet : ⌈débit voulu ÷ machine⌉, au moins 1, au plus Ml.MACHINES_MAX.
local function machines_for(rate, par_min)
  if not par_min or par_min <= 0 then return 1 end
  return min(max(1, ceil((rate or 0) * Id.LEAD / par_min - 1e-9)), Ml.MACHINES_MAX or 64)
end

--- Objets « plaque » (produit fondu) : les seuls portés par le tronc à cette tranche.
local function plate_set() -- (posé une fois, dans un champ du module : pas de table neuve dans un local de module, F403)
  if not Rt.PLATE_SET then
    local out = {}
    for _, o in pairs(T.outposts) do if o.product and o.resource and o.product ~= o.resource then out[o.product] = true end end
    Rt.PLATE_SET = out
  end
  return Rt.PLATE_SET
end

local function bus_eligible(d, plates)
  if #(d.solides or {}) == 0 or #d.solides > 2 then return false end
  for _, s in ipairs(d.solides) do if not plates[s] then return false end end
  return true
end

--- Lot MALL-DIRECTIONS : plafond de cellules d'une rangée. Dans le secteur et son étendue lue (Mr.capacite + sect.ext) comme avant ; au-delà, la rangée
--- continue et franchit les rues du treillis par un souterrain par tapis (Mr.rues, Mr.serie_cells, Build.SITES.mall) : il faut un souterrain débloqué
--- (names.souterrain, sinon Rt.logistique). Rend (cells_max, cap_secteur, souterrain).
function Rt.cap_secteur(st)
  local _, cells_in = Mr.capacite(st.sect, st.rep.west, st.rep.north)
  return min(cells_in + floor((st.sect.ext or 0) / Mr.PERIODE), Mr.MAX_CELLS)
end
function Rt.cells_max(f, st, names)
  local cap = Rt.cap_secteur(st)
  local ug = names and names.souterrain
  if not ug then
    local lg = Rt.logistique and Rt.logistique(f) or nil -- (bancs : la lecture des prototypes peut être doublée ou absente)
    ug = lg and lg.souterrain or nil
  end
  if ug then return Mr.MAX_CELLS, cap, ug end
  return cap, cap, nil
end

--- Lot MALL-DIRECTIONS : la série de la rangée `row` jusqu'à la cellule `to` (+ 1 de regard en avant : l'entrée d'un souterrain peut être la dernière tuile
--- de la dernière cellule de cette section) : rues du treillis au-delà du secteur (cap_secteur × PERIODE), portée du souterrain lue au prototype.
--- Rend (serie, rues) ou (nil, raison) ; serie.trav vide : rien à franchir.
function Rt.serie_of(f, st, row, to, souterrain)
  local b = f.build
  if not (b.lat and st.rep and st.sect) then return { shift = {}, trav = {} }, {} end -- (banc sans treillis : rien à franchir)
  local lots = { ox = b.lat.ox - P.HALF, oy = b.lat.oy - P.HALF, pitch = P.PITCH, lot = P.LOT }
  local a_libre = Rt.cap_secteur(st) * Mr.PERIODE
  local rues = Mr.rues(st.rep, lots, a_libre, (to + 1) * Mr.PERIODE + 8 * (1 + floor((to + 1) * Mr.PERIODE / P.LOT)))
  if #rues == 0 then return { shift = {}, trav = {} }, rues end
  local proto = souterrain and game.entity_prototypes[souterrain]
  local reach = proto and proto.max_underground_distance or nil
  local serie, why = Mr.serie_cells(to + 1, rues, reach)
  if not serie then return nil, why end
  return serie, rues
end

--- Noms du répartiteur et du souterrain à poser (le moins rapide dont la recette est débloquée) : { repartiteur, souterrain } ou nil. Lu aux prototypes.
function Rt.logistique(f)
  local force = game.forces and game.forces[f.force]
  if not force then return nil end
  local out = {}
  for _, what in ipairs({ { "repartiteur", T.LOGISTIC_TYPES.splitter }, { "souterrain", T.LOGISTIC_TYPES.underground } }) do
    local best, best_speed
    local protos = game.get_filtered_entity_prototypes({ { filter = "type", type = what[2] } })
    local names = {}
    for name in pairs(protos) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
      local r = force.recipes[name]
      if r and r.enabled then
        local sp = protos[name].belt_speed or 0
        if not best or sp < best_speed then best, best_speed = name, sp end
      end
    end
    if not best then return nil end
    out[what[1]] = best
  end
  return out
end

--- Tous les objets des types logistiques du jeu (la recherche voulue du mall : Voulues), triés. Un nom de plus ne coûte rien.
local function logistic_items()
  local out, seen = {}, {}
  for _, typ in ipairs({ T.LOGISTIC_TYPES.splitter, T.LOGISTIC_TYPES.underground }) do
    local protos = game.get_filtered_entity_prototypes({ { filter = "type", type = typ } })
    local names = {}
    for name in pairs(protos) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
      local it = item_of(name)
      if it and not seen[it] then seen[it] = true; out[#out + 1] = it end
    end
  end
  table.sort(out)
  return out
end

--- Débit nominal des plaques des demandes, en objets/s (d.rate : objets/min de la sortie), objet par objet : ce que lisent script/team/liaison.lua et script/team/rapatriement.lua pour décider de servir
--- un coffre de tête de ligne par tapis, comme le quai d'un module.
local function bus_inflow(demandes)
  local out = {}
  for _, d in ipairs(demandes) do
    local proto = game.recipe_prototypes and game.recipe_prototypes[d.recipe]
    local per, made = {}, 1
    if proto then
      for _, ing in ipairs(proto.ingredients) do per[ing.name] = ing.amount end
      local pr = proto.products[1]
      made = (pr and pr.amount and pr.amount > 0) and pr.amount or 1
    end
    for _, s in ipairs(d.solides) do
      out[s] = (out[s] or 0) + (d.rate or 0) / 60 * (per[s] or 1) / made
    end
  end
  return out
end

--- Rangée alimentée par le tronc pour ces objets (toutes leurs entrées sont des plaques) : un tapis par plaque, A = la ligne de plus petit numéro. Rend (projet) ou (nil, raison, attendre).
function Rt.place_bus(f, demandes, names, tick, afford, why_text)
  local b = f.build
  local st = b.mall
  repere(st)
  local lg = Rt.logistique(f)
  if not (lg or (names.repartiteur and names.souterrain)) then return nil, "tronc : repartiteur ou souterrain non debloque" end
  local nm = {}
  for k, v in pairs(names) do nm[k] = v end -- (copie d'une table de noms : l'ordre n'a aucun effet)
  nm.repartiteur = names.repartiteur or lg.repartiteur
  nm.souterrain = names.souterrain or lg.souterrain
  st.lines = st.lines or {}
  -- plaques voulues (au plus 2 pour un même appel, les autres objets repartent en candidats)
  local want, seen = {}, {}
  for _, d in ipairs(demandes) do
    for _, s in ipairs(d.solides) do if not seen[s] then seen[s] = true; want[#want + 1] = s end end
  end
  table.sort(want)
  if #want > 2 then return nil, "tronc : plus de 2 plaques dans ce groupe" end
  -- une rangée alimentée par le tronc qui a ces plaques sur ses voies et de la place, sinon une neuve
  local rows_max = Mr.capacite(st.sect, st.rep.west, st.rep.north)
  local cells_max = Rt.cells_max(f, st, nm) -- (lot MALL-DIRECTIONS : au-delà du secteur, les rues franchies en souterrain)
  local row, newrow
  for _, r in ipairs(st.rows) do
    if r.bus and not r.stop and #r.cells < cells_max and not (r.retry_at and r.retry_at > tick) then
      local has = true
      for _, s in ipairs(want) do if not Mr.accepte(r.voies, { s }, "?") then has = false end end
      if has then row = r break end
    end
  end
  -- numéros des lignes (les nouvelles sont ajoutées à la fin ; rendues si le matériel manque)
  local prev_lines = {}
  for i, ln in ipairs(st.lines) do prev_lines[i] = { k = ln.k, item = ln.item, y_to = ln.y_to } end
  local function line_of(item)
    for _, ln in ipairs(st.lines) do if ln.item == item then return ln.k end end
    return nil
  end
  for _, s in ipairs(want) do
    if not line_of(s) then
      if #st.lines >= Mt.KMAX then return nil, "tronc : lignes pleines (" .. Mt.KMAX .. ")" end
      st.lines[#st.lines + 1] = Mt.ligne(#st.lines + 1, s)
    end
  end
  local function restore()
    st.lines = {}
    for i, ln in ipairs(prev_lines) do st.lines[i] = ln end
  end
  if not row then
    if #st.rows >= rows_max then restore() return nil, string.format("mall plein (%d rangee(s) sur %d)", #st.rows, rows_max) end
    local ks = {}
    for _, s in ipairs(want) do ks[#ks + 1] = { k = line_of(s), item = s } end
    table.sort(ks, function(x, y) return x.k < y.k end)
    local a, b2 = ks[1], ks[2]
    local voies = { a.item, a.item }
    if b2 then voies[3], voies[4] = b2.item, b2.item end
    row, newrow = { j = #st.rows + 1, voies = voies, cells = {}, projects = {}, bus = { a = a.k, b = b2 and b2.k or nil } }, true
  end
  local aj = Mr.ajouts(row, demandes, Rt.MAX_NEW)
  if #aj == 0 then restore() return nil, "mall : rien a ajouter" end
  local cells = Mr.sceller(aj)
  local from = #row.cells + 1
  if from - 1 + #cells > cells_max then
    if from - 1 >= cells_max then restore(); row.stop = "obstacle:secteur"; return nil, "mall : rangee " .. row.j .. " au bout du secteur" end
    for i = #cells, cells_max - (from - 1) + 1, -1 do cells[i] = nil end
  end
  for _, c in ipairs(cells) do c.m = c.m or nm.machine; row.cells[#row.cells + 1] = c end
  local to = #row.cells
  local lines_snapshot = nil
  local extra = nil
  if from == 1 then
    lines_snapshot = {}
    for i, ln in ipairs(st.lines) do lines_snapshot[i] = { k = ln.k, item = ln.item, y_to = ln.y_to } end
    extra = Mt.section(lines_snapshot, row, nm)
  end
  local sec = Mr.section(P, modele(), row, from, to, nm, st.rep, false, extra)
  local list = {}
  for _, it in ipairs(Mr.cout(sec.ents)) do list[#list + 1] = { item_of(it[1]), it[2] } end
  if afford then
    local ok, whyc = afford(list)
    if not ok then
      for i = to, from, -1 do row.cells[i] = nil end
      restore()
      -- seuls le répartiteur ou le souterrain manquent : pas d'attente, le mall continue en rangée à quais (l'attente d'un objet que personne n'a encore fabriqué bloquerait tout le mall)
      local rest = {}
      local logi = { [item_of(nm.repartiteur)] = true, [item_of(nm.souterrain)] = true }
      for _, it in ipairs(list) do if not logi[it[1]] then rest[#rest + 1] = it end end
      if #rest < #list and afford(rest) then return nil, "tronc : repartiteur ou souterrain pas encore disponibles" end
      return nil, tostring(whyc), true
    end
  end
  local spec = { site = "mall", domain = "production", why = why_text or "MALL rangee (tronc)", mall = { row = row.j, from = from, to = to, head = false, bus = true, lines = lines_snapshot, names = {
    machine = nm.machine, bras = nm.bras, bras_long = nm.bras_long, tapis = nm.tapis, poteau = nm.poteau, coffre = nm.coffre, repartiteur = nm.repartiteur, souterrain = nm.souterrain }, decl = names.decl } }
  local id, why = Build.request(f, spec)
  if not id then
    for i = to, from, -1 do row.cells[i] = nil end
    restore()
    return nil, why
  end
  if extra then
    for _, ln in ipairs(st.lines) do if extra.y_to[ln.k] then ln.y_to = extra.y_to[ln.k] end end
  end
  local p = b.projects[id]
  if p and extra then
    -- seules les lignes dont la tête est dans CETTE section (ses coffres) ont un consommateur à déclarer
    local flows, inflow = bus_inflow(demandes), {}
    for _, q in ipairs(extra.quais) do inflow[q.item] = flows[q.item] end
    p.inflow = inflow
  end
  if p then
    p.keep_stock = {}
    for _, d in ipairs(demandes) do p.keep_stock[d.item] = max(Id.COLLECT_AT or 50, Ml.target(d.rate or 0)) end
  end
  if newrow then
    st.rows[#st.rows + 1] = row
    say(f, st, tick, string.format("rangee %d OUVERTE sur le TRONC : voies {%s}, lignes %d/%s, %d cellule(s) (projet %d)", row.j, table.concat(row.voies, ","), row.bus.a, tostring(row.bus.b), to - from + 1, id))
  else
    say(f, st, tick, string.format("rangee %d (tronc) allongee : cellules %d a %d (projet %d)", row.j, from, to, id))
  end
  row.projects[#row.projects + 1] = { id = id, from = from, to = to, tick = tick, lines_prev = lines_snapshot and prev_lines or nil }
  return id
end

--- Range des demandes dans une rangée. demandes = { { item, recipe, machine, machines, solides, rate } } ; names = le kit (machine, bras, bras_long, tapis, poteau, coffre, decl) ;
--- rend (id du projet) ou (nil, raison, attendre).
function Rt.place(f, demandes, names, tick, afford, why_text, seule)
  local b = f.build
  local st = b.mall
  repere(st)
  -- S2 partiel : seuls les objets dont les plaques coulent
  if not (st.pret or st.force_pret) and st.partiel then
    local kept = {}
    for _, d in ipairs(demandes) do
      local ok_d = true
      for _, s in ipairs(d.solides or {}) do
        if st.partiel.all[s] and not st.partiel.ok[s] then ok_d = false end
      end
      if ok_d then kept[#kept + 1] = d end
    end
    if #kept == 0 then return nil, "S2 partiel : les plaques de ces objets ne coulent pas" end
    demandes = kept
  end
  local plates = plate_set()
  local bus_d = {}
  for _, d in ipairs(demandes) do if bus_eligible(d, plates) then bus_d[#bus_d + 1] = d end end
  if #bus_d > 0 and not seule and Build.Mall.tronc_on and Build.Mall.tronc_on() then
    local id, why, wait = Rt.place_bus(f, bus_d, names, tick, afford, why_text)
    if id or wait then return id, why, wait end
    -- pas de tronc possible (répartiteur non débloqué, lignes pleines) : la rangée à quais d'avant
  end
  local rows_max = Mr.capacite(st.sect, st.rep.west, st.rep.north)
  local cells_max, _, souterrain = Rt.cells_max(f, st, names) -- (lot MALL-DIRECTIONS : au-delà du secteur, les rues franchies en souterrain)
  -- une rangée dont les voies acceptent TOUT, sinon une neuve
  local row, newrow
  for _, r in ipairs(st.rows) do
    local all_in = (not seule or r == seule) and not r.stop and #r.cells < cells_max and not (r.retry_at and r.retry_at > tick)
    for _, d in ipairs(demandes) do
      if not Mr.accepte(r.voies, d.solides, d.item) then all_in = false end
    end
    if all_in then row = r break end
  end
  if not row then
    if #st.rows >= rows_max then return nil, string.format("mall plein (%d rangee(s) sur %d)", #st.rows, rows_max) end
    local cands = {}
    for _, d in ipairs(demandes) do cands[#cands + 1] = { name = d.item, solides = d.solides } end
    local voies = Mr.voies(cands)
    if #voies == 0 then return nil, "mall : aucune voie" end
    for _, d in ipairs(demandes) do
      if not Mr.accepte(voies, d.solides, d.item) then return nil, "mall : " .. d.item .. " : entree hors des voies" end
    end
    row, newrow = { j = #st.rows + 1, voies = voies, cells = {}, projects = {} }, true
  end
  local aj = Mr.ajouts(row, demandes, Rt.MAX_NEW)
  if #aj == 0 then return nil, "mall : rien a ajouter" end
  local cells = Mr.sceller(aj)
  local from = #row.cells + 1
  if from - 1 + #cells > cells_max then
    if from - 1 >= cells_max then row.stop = "obstacle:secteur"; return nil, "mall : rangee " .. row.j .. " au bout du secteur" end
    for i = #cells, cells_max - (from - 1) + 1, -1 do cells[i] = nil end
  end
  for _, c in ipairs(cells) do c.m = c.m or names.machine; row.cells[#row.cells + 1] = c end
  local to = #row.cells
  local sec = Mr.section(P, modele(), row, from, to, names, st.rep, from == 1)
  local list = {}
  for _, it in ipairs(Mr.cout(sec.ents)) do list[#list + 1] = { item_of(it[1]), it[2] } end
  if afford then
    local ok, whyc = afford(list)
    if not ok then
      for i = to, from, -1 do row.cells[i] = nil end
      return nil, tostring(whyc), true
    end
  end
  local id, why = Build.request(f, { site = "mall", domain = "production", why = why_text or "MALL rangee", mall = { row = row.j, from = from, to = to, head = from == 1, names = {
    machine = names.machine, bras = names.bras, bras_long = names.bras_long, tapis = names.tapis, poteau = names.poteau, coffre = names.coffre, souterrain = souterrain }, decl = names.decl } })
  if not id then
    for i = to, from, -1 do row.cells[i] = nil end
    return nil, why
  end
  local p = b.projects[id]
  if p then
    p.keep_stock = p.keep_stock or {}
    for _, d in ipairs(demandes) do p.keep_stock[d.item] = max(Id.COLLECT_AT or 50, Ml.target(d.rate or 0)) end
    p.mall_barre = nil
  end
  if newrow then
    st.rows[#st.rows + 1] = row
    say(f, st, tick, string.format("rangee %d OUVERTE : voies {%s}, sections demandees : %d cellule(s) (projet %d)", row.j, table.concat(row.voies, ","), to - from + 1, id))
  else
    say(f, st, tick, string.format("rangee %d allongee : cellules %d a %d (projet %d)", row.j, from, to, id))
  end
  row.projects[#row.projects + 1] = { id = id, from = from, to = to, tick = tick }
  return id
end

--- Part d'un ingrédient par objet fabriqué (objets d'ingrédient par objet de sortie), lue au prototype.
local function part_de(rname, s)
  local proto = game.recipe_prototypes and game.recipe_prototypes[rname]
  if not proto then return 1 end
  local amount, made = 1, 1
  for _, ing in ipairs(proto.ingredients) do if ing.name == s then amount = ing.amount end end
  local pr = proto.products[1]
  if pr and pr.amount and pr.amount > 0 then made = pr.amount end
  return amount / made
end

--- Le premier intermédiaire qu'il faut au mall avant cette recette : une entrée solide qui n'est pas une plaque, qu'aucune rangée ne fabrique, et qu'une recette assemblable sait faire ; d'abord ce dont
--- elle a elle-même besoin. Partie 388473a0, votre équipe : des rangées posées attendaient engrenages, tuyaux, câbles et circuits que le coffre du QG n'avait pas ; 18 min à l'arrêt. Rend
--- { item, pr, rate } ou nil. depth borne la descente ; rate en objets/min.
local function intermediaire_manquant(lec, usable, rname, rate, depth, served, plates)
  -- une cellule de rangée est faite pour un assembleur : une recette de four n'est pas un intermédiaire du mall (partie inter-a4e67879, azure : 8 fours de pierre pour l'acier, projet bloqué)
  local function assemblable(pr)
    local m = cheap(pr.entry, usable)
    local proto = m and game.entity_prototypes[m.entity]
    return proto ~= nil and proto.type == "assembling-machine"
  end
  local e = lec.fab[rname]
  local solides = {}
  for _, x in ipairs(e and e.solides or {}) do solides[#solides + 1] = x.name end
  table.sort(solides)
  for _, s in ipairs(solides) do
    if not plates[s] and not served[s] then
      local pr = Id.profile(lec.fab, s, usable)
      if pr and pr.s <= 4 and pr.par_min > 0 and pr.s > 0 and assemblable(pr) then
        local rate_s = (rate or 0) * part_de(rname, s)
        local deeper = depth > 0 and intermediaire_manquant(lec, usable, pr.recipe, rate_s, depth - 1, served, plates) or nil
        return deeper or { item = s, pr = pr, rate = rate_s }
      end
    end
  end
  return nil
end

--- Une décision de Ind.think passe par le mall. c = { dec, kind, items } (Id.order) ; mod = prepare(...) ; rend vrai (pris) ou (faux, raison, attendre).
function Rt.accueille(f, c, mod, lec, tick, afford, usable)
  if not Rt.ouvert(f) then return false, "ferme" end
  local demandes = {}
  local dec = c.dec
  local kit = (c.kind == "bloc") and mod.args[3] or mod.args[5]
  local decl = { kit = kit.decl and kit.decl.kit or {}, machines = {} }
  local seen_m = {}
  local first_machine
  for _, it in ipairs(c.items) do
    local rname = (c.kind == "bloc") and dec.recipes[it] or dec.recipe
    local rate = (c.kind == "bloc") and dec.rates[it] or dec.rate
    local e = lec.fab[rname]
    if not e then return false, "recette " .. tostring(rname) .. " non lue" end
    local solides = {}
    for _, s in ipairs(e.solides or {}) do solides[#solides + 1] = s.name end
    table.sort(solides)
    local m = cheap(e, usable)
    if not m then return false, "aucune machine utilisable pour " .. tostring(rname) end
    if not seen_m[m.entity] then
      seen_m[m.entity] = true
      decl.machines[#decl.machines + 1] = { machine = m, categories = { e.category } }
    end
    first_machine = first_machine or m.entity
    demandes[#demandes + 1] = { item = it, recipe = rname, machine = m.entity, machines = machines_for(rate, m.par_min), solides = solides, rate = rate }
  end
  -- les rangées d'intermédiaires d'abord (une par décision) : la recette demandée revient à la décision suivante
  local served, plates, inter = Rt.served(f), plate_set(), nil
  for _, d in ipairs(demandes) do
    inter = intermediaire_manquant(lec, usable, d.recipe, d.rate, 2, served, plates)
    if inter then break end
  end
  local inter_m = inter and cheap(inter.pr.entry, usable) or nil
  if inter_m and not seen_m[inter_m.entity] then
    seen_m[inter_m.entity] = true
    decl.machines[#decl.machines + 1] = { machine = inter_m, categories = { inter.pr.entry.category } }
  end
  A.declare(decl)
  local names = { machine = first_machine, bras = kit.bras, bras_long = kit.bras_long, tapis = kit.tapis, poteau = mod.pole or kit.poteau, coffre = kit.coffre or Build.QUAI_CHEST, decl = decl }
  f.build.mall.names_kit = names
  if inter_m then
    local d = { item = inter.item, recipe = inter.pr.recipe, machine = inter_m.entity, machines = machines_for(inter.rate, inter_m.par_min), solides = inter.pr.solides, rate = inter.rate }
    local id_i, why_i, wait_i = Rt.place(f, { d }, names, tick, afford, "MALL intermediaire " .. inter.item)
    if id_i then
      say(f, f.build.mall, tick, string.format("intermediaire %s d'abord (%d machine(s), %.1f/min, projet %d), avant %s", inter.item, d.machines, inter.rate, id_i, table.concat(c.items, ",")))
      return true
    end
    if wait_i then return false, why_i, wait_i end
    -- (refus : mall plein, entrée hors des voies) la recette demandée continue comme avant
  end
  local id, why, wait = Rt.place(f, demandes, names, tick, afford, "MALL rangee " .. table.concat(c.items, ","))
  if id then return true end
  return false, why, wait
end

--- Bascule d'un ordre « chaine » de la capitalisation (docs/MALL.md §3) : l'objet va dans une rangée du mall au lieu d'un module isolé du treillis (S vrai, entrées solides
--- sur 4 voies au plus). `o` = { item, rate (objets/min), key } ; `pole` = poteau choisi par l'appelant ; rend l'identifiant du projet, ou vrai (déjà servi : la rangée a ses
--- machines), ou (nil, raison) : le chemin d'avant (module isolé), cause écrite une fois par objet. La dépense a déjà été jugée par la capitalisation.
function Rt.chaine(f, o, book, stock, tick, pole)
  if not Rt.ouvert(f) then return nil, "ferme" end
  local st = f.build.mall
  local function refuse(why)
    st.chaine_why = st.chaine_why or {}
    if st.chaine_why[o.item] ~= why then
      st.chaine_why[o.item] = why
      say(f, st, tick, string.format("ordre chaine %s : hors du mall (%s)", tostring(o.item), tostring(why)))
    end
    return nil, why
  end
  local lec = A.lecture()
  if not lec then return refuse("lecture des recettes absente") end
  local usable = function(n) return book:handcraftable(n) or ((stock or {})[n] or 0) > 0 end
  local pr, why = Id.profile(lec.fab, o.item, usable)
  if not pr then return refuse(why) end
  if pr.s > 4 then return refuse(pr.s .. " entrees solides (4 voies)") end
  if pr.par_min <= 0 then return refuse("sans debit") end
  local kit, whyk = A.patron_kit(lec, usable)
  if not kit then return refuse(whyk) end
  local mc = cheap(pr.entry, usable) or pr.machine
  local decl = { kit = kit.decl.kit, machines = { { machine = mc, categories = { pr.entry.category } } } }
  A.declare(decl)
  local names = { machine = mc.entity, bras = kit.bras, bras_long = kit.bras_long, tapis = kit.tapis, poteau = pole or kit.poteau, coffre = kit.coffre, decl = decl }
  st.names_kit = st.names_kit or names
  local machines = machines_for(o.rate or 0, mc.par_min)
  local dem = { { item = o.item, recipe = pr.recipe, machine = names.machine, machines = machines, solides = pr.solides, rate = o.rate or 0 } }
  -- déjà servi : la rangée qui l'a porte assez de machines
  for _, r in ipairs(st.rows or {}) do
    if Mr.compte(r, pr.recipe) >= machines then return true end
  end
  local id, whyp = Rt.place(f, dem, names, tick, nil, "MALL ordre chaine " .. tostring(o.item))
  if id then return id end
  if tostring(whyp) == "mall : rien a ajouter" then return true end
  return refuse(whyp)
end

---------------------------------------------------------------------------------------------------
-- La minute : barres, refus, allongement, compteurs
---------------------------------------------------------------------------------------------------
local function chest_inv(surface, x, y)
  local ch = surface.find_entity(Build.QUAI_CHEST, { x, y })
  return ch, ch and ch.get_inventory(defines.inventory.chest)
end

--- Nom d'un état de machine (defines.entity_status) ; table construite une fois (ni décision ni sauvegarde : le journal seulement).
local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function status_name(s)
  if not Rt.STATUS_NAMES then
    local out = {}
    for name, v in pairs(defines.entity_status) do out[v] = name end
    Rt.STATUS_NAMES = out
  end
  return Rt.STATUS_NAMES[s] or tostring(s)
end

--- Ce que boivent les machines posées : parts[j] = liste triée { item, per_machine } (une machine de la rangée j, au plus, objets/min), conso = ce que tout le mall peut boire, entrée par entrée.
local function consommation(st, lec)
  local conso, parts = {}, {}
  for _, r in ipairs(st.rows) do
    local maxi = {}
    for _, c in ipairs(r.cells) do
      for _, rname in ipairs({ c.h or false, c.b or false }) do
        local e = rname and lec.fab[rname]
        if e then
          local par_min = 0
          for _, m in ipairs(e.machines or {}) do if m.entity == c.m then par_min = m.par_min or 0 end end
          for _, x in ipairs(e.solides or {}) do
            local u = par_min * part_de(rname, x.name)
            conso[x.name] = (conso[x.name] or 0) + u
            if u > (maxi[x.name] or 0) then maxi[x.name] = u end
          end
        end
      end
    end
    local list = {}
    for _, k in ipairs(sorted_keys(maxi)) do list[#list + 1] = { item = k, per_machine = maxi[k] } end
    parts[r.j] = list
  end
  return parts, conso
end

--- La recette la moins représentée de la rangée (ordre : compte, puis nom) : la demande d'une cellule de plus. Rend une demande pour Rt.place, ou nil.
local function cellule_de_plus(r, lec)
  local best
  local seen = {}
  for _, c in ipairs(r.cells) do
    for _, pair in ipairs({ { c.ih, c.h }, { c.ib, c.b } }) do
      local it, rn = pair[1], pair[2]
      if it and rn and not seen[rn] then
        seen[rn] = true
        local n = Mr.compte(r, rn)
        if not best or n < best.n or (n == best.n and rn < best.recipe) then best = { item = it, recipe = rn, n = n, machine = c.m } end
      end
    end
  end
  local e = best and lec.fab[best.recipe]
  if not e then return nil end
  local solides, par_min = {}, 0
  for _, s in ipairs(e.solides or {}) do solides[#solides + 1] = s.name end
  table.sort(solides)
  for _, m in ipairs(e.machines or {}) do if m.entity == best.machine then par_min = m.par_min or 0 end end
  return { item = best.item, recipe = best.recipe, machine = best.machine, machines = best.n + Ma.PAR_CELLULE, solides = solides, rate = par_min }
end

--- Lot MALL-LIQUIDATION : les pièces d'UNE section de la rangée, lues au plan de sa dernière section finie (aucun nom en dur) : liste triée { objet, n, machine }
--- (machine = vrai pour la pièce posée au rôle de machine de la rangée). Rend nil sans section finie.
local function pieces_section(b, r)
  local last = Mr.derniere(r.projects)
  local p = last and b.projects[last.id]
  if not (p and p.state == "fini" and p.ents) then return nil end
  local machines = {}
  for _, e in ipairs(p.ents) do if e.role == "mall-machine_asm" then machines[item_of(e.name)] = true end end
  local out = {}
  for _, it in ipairs(Mr.cout(p.ents)) do
    local objet = item_of(it[1])
    out[#out + 1] = { objet, it[2], machines[objet] or false }
  end
  return out
end

--- Lot MALL-LIQUIDATION : le stock dormant de la rangée paie-t-il une section de plus ? Rend (nombre de sections, machine au coffre, nom de la machine) ou nil.
local function stock_dormant(b, r, libre)
  local section = pieces_section(b, r)
  if not section then return nil end
  local ok, n, piece = Liq.surplus(libre, section)
  if not ok then return nil end
  return n, libre[piece] or 0, piece
end

--- Une fois par décision (Ind.think) : barres des coffres de sortie, cellules rendues par une section refusée, allongement, compteurs.
function Rt.minute(f, surface, lec, sources, afford, tick, libre)
  local b = f.build
  local st = b and b.mall
  if not (st and st.rows) or not surface then return end
  local protect = {}
  -- 1. états des projets
  for _, r in ipairs(st.rows) do
    for i = #r.projects, 1, -1 do
      local q = r.projects[i]
      local p = b.projects[q.id]
      local s = p and p.state or "perdu"
      if s == "fini" and p and not p.mall_barre then
        p.mall_barre = true
        -- barre de chaque coffre de sortie : la cible de Ml pour l'objet de cette machine, au moins une case
        for _, o in ipairs(p.outs or {}) do
          local ch, inv = chest_inv(surface, o.x, o.y)
          if ch and inv and inv.supports_bar() then
            local item = o.item
            local stack = item and game.item_prototypes[item] and game.item_prototypes[item].stack_size or 50
            local target = p.keep_stock and item and p.keep_stock[item] or 100
            inv.set_bar(max(2, ceil(target / stack + 1e-9)) + 1) -- F95 : la barre rend `cases + 1` ; ici : limite ouverte à cases
          end
        end
      elseif (s == "refuse" or s == "perdu") and not q.dead then
        q.dead = true
        local why = p and p.reason or "projet perdu"
        -- les sections suivantes : annulées tant que rien n'est bâti (leurs réservations ne restent pas). Une section déjà bâtie garde ses cellules, suivies par le compteur ; une cellule se repère à
        -- sa place dans la rangée, celles rendues sous une section gardée deviennent des cases vides (sans recette)
        local gardees, garde_to = {}, 0
        for _, q2 in ipairs(r.projects) do
          if q2 ~= q and not q2.dead and q2.from > q.from then
            local pp = b.projects[q2.id]
            if not pp or pp.state == "refuse" or Build.cancel(f, q2.id, "mall : section precedente refusee") then
              q2.dead = true
            else
              for k = q2.from, q2.to do gardees[k] = true end
              garde_to = max(garde_to, q2.to)
            end
          end
        end
        for k = #r.cells, q.from, -1 do
          if k > garde_to then r.cells[k] = nil elseif not gardees[k] then r.cells[k] = {} end
        end
        if q.lines_prev then st.lines = q.lines_prev end -- (les lignes et leur étendue reviennent à leur état d'avant la section refusée)
        if tostring(why):find("obstacle", 1, true) or tostring(why):find("purete", 1, true) then r.stop = tostring(why)
        else r.retry_at = tick + Rt.RETRY_TICKS end -- (raccord, projet perdu : nouvel essai plus tard, pas à chaque minute)
        say(f, st, tick, string.format("rangee %d : section %d-%d refusee (%s) : cellules rendues, arret : %s", r.j, q.from, q.to, tostring(why), tostring(r.stop)))
      end
    end
  end
  -- 1b. la recherche voulue : les objets des prises du tronc, tant qu'ils ne sont pas débloqués (Voulues, lu par le cerveau général)
  if Build.Mall.tronc_on and Build.Mall.tronc_on() and Rt.ouvert(f) then
    if Rt.logistique(f) then Voulues.clear(f, "mall") else Voulues.set(f, "mall", logistic_items(), tick) end
  end
  -- 2. allongement (une demande à la fois : la dernière section finie)
  if Rt.ouvert(f) and #st.rows > 0 then
    local rate_of = {}
    for _, c in ipairs(sources or {}) do rate_of[c.item] = c.rate end
    for _, r in ipairs(st.rows) do
      local last = Mr.derniere(r.projects) -- (la dernière section VIVANTE : une section refusée reste dans la liste et figeait la rangée)
      local p = last and b.projects[last.id]
      if not r.stop and not (r.retry_at and r.retry_at > tick) and p and p.state == "fini" and #r.cells < Mr.MAX_CELLS then
        local want = {}
        local seen = {}
        for _, c in ipairs(r.cells) do
          for _, pair in ipairs({ { c.ih, c.h }, { c.ib, c.b } }) do
            local it, recipe = pair[1], pair[2]
            if it and not seen[it] and rate_of[it] then
              seen[it] = true
              local e = lec.fab[recipe]
              local par_min, solides = nil, {}
              for _, s in ipairs(e and e.solides or {}) do solides[#solides + 1] = s.name end
              table.sort(solides)
              for _, m in ipairs(e and e.machines or {}) do if m.entity == c.m then par_min = m.par_min end end
              want[#want + 1] = { item = it, recipe = recipe, machine = c.m, machines = machines_for(rate_of[it], par_min), solides = solides, rate = rate_of[it] }
            end
          end
        end
        table.sort(want, function(a, c2) return a.item < c2.item end)
        local names = st.names_kit
        if names and #Mr.ajouts(r, want, Rt.MAX_NEW) > 0 then
          local id, why, wait = Rt.place(f, want, names, tick, afford, "MALL rangee " .. r.j .. " allongee")
          if not id and not wait and tostring(why) ~= r.last_why then
            r.last_why = tostring(why)
            say(f, st, tick, string.format("rangee %d : allongement refuse : %s", r.j, tostring(why)))
          end
          if id then break end
        end
      end
    end
  end
  -- 2b. au-delà de la demande : une cellule de plus quand la matière est en surplus (shared/team/mall_allonge.lua) ; une section à la fois pour tout le mall, la rangée la plus courte d'abord
  if libre and Build.Mall.flow and (st.pret or st.force_pret) and #st.rows > 0 and st.names_kit then
    local ouvert = false
    for _, r in ipairs(st.rows) do
      for _, q in ipairs(r.projects) do
        local pq = b.projects[q.id]
        if not q.dead and pq and pq.state ~= "fini" then ouvert = true end
      end
    end
    if not ouvert then
      local parts, conso = consommation(st, lec)
      local flow = {}
      for _, r in ipairs(st.rows) do
        for _, x in ipairs(parts[r.j] or {}) do
          if flow[x.item] == nil then flow[x.item] = Build.Mall.flow(f, x.item) end
        end
      end
      local ordre = {}
      for _, r in ipairs(st.rows) do ordre[#ordre + 1] = r end
      table.sort(ordre, function(x, y) if #x.cells ~= #y.cells then return #x.cells < #y.cells end return x.j < y.j end)
      for _, r in ipairs(ordre) do
        if not r.stop and not (r.retry_at and r.retry_at > tick) and #r.cells < Mr.MAX_CELLS then
          -- lot MALL-LIQUIDATION (le DC, 9/11 : « fin de la thésaurisation ») : AVANT le débit, le stock de machines qui dort au coffre paie la section
          -- (shared/team/mall_liquidation.lua, réserve Liq.RESERVE_PCT) ; les plaques restent exigées par `afford`, la place par la rangée. Sinon : la règle du débit mesuré.
          local dormant, au_coffre, machine = stock_dormant(b, r, libre)
          local cible
          if dormant then cible = #r.cells + 1 else cible = Ma.cible(#r.cells, parts[r.j] or {}, flow, libre, conso, Mr.MAX_CELLS) end
          local d = cible > #r.cells and cellule_de_plus(r, lec) or nil
          if d then
            local id = Rt.place(f, { d }, st.names_kit, tick, afford, "MALL rangee " .. r.j .. " allongee au surplus", r)
            if id then
              if dormant then
                say(f, st, tick, string.format("rangee %d : section de plus PAYEE PAR LE STOCK DORMANT (%d %s au coffre, reserve %d %%, %d section(s) payables ; %s, projet %d)",
                  r.j, au_coffre, tostring(machine), floor(Liq.RESERVE_PCT * 100 + 0.5), dormant, d.item, id))
              else
                say(f, st, tick, string.format("rangee %d : surplus : cible %d cellule(s), une de plus (%s, projet %d)", r.j, cible, d.item, id))
              end
              break
            end
          end
        end
      end
    end
  end
  -- 3. compteurs (lecture en FONCTION : objets fabriqués par le mall et sortis en coffre)
  local total_made, total_chests, total_m, total_run = 0, 0, 0, 0
  for _, r in ipairs(st.rows) do
    local made, chests, nm, run, expected = 0, 0, 0, 0, 0
    local etats, q_vides, q_total, vides = {}, 0, 0, {}
    for _, q in ipairs(r.projects) do
      local p = b.projects[q.id]
      if p and not q.dead then
        for _, e in ipairs(p.ents) do
          if e.role == "mall-machine_asm" then
            expected = expected + 1
            local en = surface.find_entity(e.name, { e.x, e.y })
            if en and en.force.name == f.force then
              nm = nm + 1
              made = made + (en.products_finished or 0)
              if en.status == defines.entity_status.working or en.status == defines.entity_status.low_power then run = run + 1 end
              local sn = status_name(en.status)
              etats[sn] = (etats[sn] or 0) + 1
            end
          elseif e.role == "mall-sortie" then
            local ch, inv = chest_inv(surface, e.x, e.y)
            if ch and inv then chests = chests + inv.get_item_count() end
          end
        end
        for _, qd in ipairs(p.quais or {}) do
          local _, qi = chest_inv(surface, qd.x, qd.y)
          if qi and qd.item then
            q_total = q_total + 1
            if qi.get_item_count(qd.item) == 0 then
              q_vides = q_vides + 1
              vides[qd.item] = true
            end
          end
        end
      end
    end
    -- compteur CUMULÉ : products_finished est porté par la machine ; une machine détruite retire son compte de la somme (partie neuve 67887c48, scarlet : 1 535 puis 102), le cumul ne redescend pas
    r.made0 = r.made0 or 0
    local delta = math.max(0, made - r.made0)
    r.made0 = made
    r.made_total = (r.made_total or 0) + delta
    if nm > 0 and (delta > 0 or r.last_prod_m ~= nm) then
      r.last_prod_m = nm
      say(f, st, tick, string.format("PRODUCTION rangee %d : %d machine(s) sur %d dont %d en marche, %d objet(s) fabriques (+%d depuis la derniere minute), %d objet(s) dans les coffres de sortie, cellules %d, arret %s",
        r.j, nm, expected, run, r.made_total, delta, chests, #r.cells, tostring(r.stop)))
    end
    -- rangée posée qui ne tourne pas : pourquoi (états des machines, quais vides) ; au plus une ligne par 5 min et par rangée
    if nm > 0 and run == 0 and delta == 0 and tick >= (r.arret_next or 0) then
      r.arret_next = tick + 5 * 3600
      local parts, its = {}, {}
      for _, k in ipairs(sorted_keys(etats)) do parts[#parts + 1] = k .. "=" .. etats[k] end
      for _, k in ipairs(sorted_keys(vides)) do its[#its + 1] = k end
      say(f, st, tick, string.format("ARRET rangee %d : 0 machine(s) en marche sur %d : etats {%s} ; quais vides %d sur %d {%s}", r.j, nm, table.concat(parts, ","), q_vides, q_total, table.concat(its, ",")))
    end
    total_made, total_chests, total_m, total_run = total_made + r.made_total, total_chests + chests, total_m + nm, total_run + run
  end
  st.fab = { made = total_made, chests = total_chests, machines = total_m, run = total_run, tick = tick }
end

--- Tapis et bras d'abord (lot amelioration-2 : azure manquait de 470 à 520 tapis de base à 67-74 min, sans une rangée de mall à 65,5 min) : les candidats qui portent un objet posant une entité de ces
--- types passent devant, ordre relatif gardé. Lu au prototype : aucun nom d'objet.
local function premier(item)
  local pr = game.item_prototypes[item]
  local pe = pr and pr.place_result
  return pe ~= nil and T.MALL_PREMIERS[pe.type] == true
end

function Rt.ordonne(cands)
  local first, rest = {}, {}
  for _, c in ipairs(cands) do
    local hit = false
    for _, it in ipairs(c.items or {}) do if premier(it) then hit = true end end
    if hit then first[#first + 1] = c else rest[#rest + 1] = c end
  end
  for _, c in ipairs(rest) do first[#first + 1] = c end
  return first
end

--- Contexte du cerveau (script/ai3/automatisation.lua, comme la centrale et la migration) : une section en chantier est un projet dont les MANQUES sont fabriqués (mods) ; une
--- section de tête finie demande les objets de ses quais qui manquent au coffre (feeds). `pile` : famille « capi » de la pile (la porte de la pensée la lit).
function Rt.contexte(f, mods, feeds, stock, book, feed_stock)
  local st = f.build and f.build.mall
  for _, r in ipairs(st and st.rows or {}) do
    for _, q in ipairs(r.projects) do
      if not q.dead then
        local p = f.build.projects[q.id]
        if p and p.state ~= "fini" and p.state ~= "refuse" then
          local ps = Build.brief(f, q.id)
          if ps then mods[#mods + 1] = { id = q.id, product = "mall:" .. r.j .. ":" .. q.from, state = ps.state, missing = ps.missing or {}, reason = ps.reason, gain = 0, pile = "capi" } end
        elseif p and p.state == "fini" and q.from == 1 then
          local ps = Build.brief(f, q.id)
          local items = {}
          for _, it in ipairs(ps and ps.quais or {}) do
            local makeable = (book and book.handcraftable and book:handcraftable(it)) or T.smelter_inputs[it] ~= nil
            local have = stock[it] or 0
            if makeable and have < feed_stock then items[#items + 1] = { it, feed_stock - have } end
          end
          if #items > 0 then feeds[#feeds + 1] = { product = "mall:" .. r.j, id = q.id, items = items, gain = 0 } end
        end
      end
    end
  end
end

--- Rapport (bancs) : rangées et compteurs.
function Rt.report(f)
  local st = f and f.build and f.build.mall
  if not st then return nil end
  local rows = {}
  for _, r in ipairs(st.rows or {}) do
    local projs = {}
    for _, q in ipairs(r.projects) do
      local p = f.build.projects[q.id]
      projs[#projs + 1] = { id = q.id, from = q.from, to = q.to, state = p and p.state or "perdu", reason = p and p.reason or nil, built = p and p.built or 0, missing = p and p.missing or nil }
    end
    rows[#rows + 1] = { j = r.j, voies = r.voies, cells = #r.cells, stop = r.stop, projects = projs }
  end
  local outposts = 0
  for _ in pairs(f.outposts or {}) do outposts = outposts + 1 end -- (comptage : l'ordre n'a aucun effet)
  return { s2 = st.s2, partiel = st.partiel ~= nil, sect = st.sect, rep = st.rep, rows = rows, fab = st.fab, pret = st.pret, force = st.force_pret, team_force = f.force, outposts = outposts }
end

local function team_of(key)
  if key == "player" then return State.faction("player") end
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and (f.key == key or id == key) then return f end
  end
  return nil
end

if remote and remote.add_interface then remote.add_interface("fo-mall", {
  --- BANC SEULEMENT : force_pret / sans_raccord.
  set_param = function(key, name, v)
    local f = team_of(key)
    if not (f and f.build) then return nil end
    f.build.mall = f.build.mall or { v = 1, phase = "neuf", logs = 0 }
    local st = f.build.mall
    if name == "force_pret" then st.force_pret = v
    elseif name == "sans_raccord" then st.sans_raccord = v
    elseif name == "force_plant" then st.force_plant = v
    elseif name == "s2_tenue" then st.s2_tenue = v
    elseif name == "etat_every" then st.etat_every = v
    elseif name == "sect" then st.sect = v; st.phase = "choisi" -- (le relevé du terrain ne l'écrase plus)
    else return nil end
    return v
  end,
  --- BANC SEULEMENT : pose une demande directe. demandes = { { item, recipe, machine, machines, solides, rate } }, names = le kit.
  offre = function(key, demandes, names)
    local f = team_of(key)
    if not (f and f.build and f.build.mall) then return nil, "mall absent" end
    f.build.mall.names_kit = names
    return Rt.place(f, demandes, names, game.tick, nil, "MALL banc")
  end,
  --- BANC SEULEMENT : passe de Rt.minute, avec la demande en objets par minute.
  minute = function(key, lec_fab, sources, tick)
    local f = team_of(key)
    if not f then return nil end
    local surface = f.hq and f.hq.surface
    Rt.minute(f, surface, { fab = lec_fab }, sources, nil, tick or game.tick)
    return true
  end,
  report = function(key) return Rt.report(team_of(key)) end,
}) end

return Rt
