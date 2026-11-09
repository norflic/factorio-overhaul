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
local Cat = require("shared.team.motifs.catalogue")
local P = require("shared.team.plan")
local M = require("shared.team.modules")
local A = require("shared.ai3.automatiser")
local Id = require("shared.ai3.industrie")
local T = require("shared.team.config")
local Ml = require("shared.ai3.mall")
local Build = require("script.team.build")
local State = require("script.faction.state")
local Events = require("script.core.events")

local Rt = {}

Rt.MAX_NEW = 8             -- machines ajoutées au plus par demande
Rt.LOGS = 400              -- lignes de ce module au plus, par équipe (journal [FO-MALL])

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
  return st.pret == true or st.force_pret == true
end

local function repere(st)
  if not st.rep then
    local ox, oy = Mr.origin(st.sect)
    st.rep = { ox = ox, oy = oy, k = Mr.frame(st.sect.dir) }
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
  local sec = Mr.section(P, modele(), row, sp.from, sp.to, sp.names, st.rep, sp.head == true)
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
  -- raccord au réseau alimenté (section de tête : la rangée suivante se branche sur la précédente ou sur le réseau)
  if sp.head and not st.sans_raccord then
    local poles = {}
    for _, e in ipairs(sec.ents) do if e.role == "mall-poteau" then poles[#poles + 1] = e end end
    local cx, cy = 0, 0
    for _, e in ipairs(poles) do cx, cy = cx + e.x, cy + e.y end
    cx, cy = cx / #poles, cy / #poles
    local bd = { spec = { pole = { wire = P.wire(sp.names.poteau) or 7.5 }, mine = {}, ore = {} }, names = { pole = sp.names.poteau },
      plan = { bands = {}, pitch = 0, axis = "x" } }
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
--- Machines voulues pour un objet : ⌈débit voulu ÷ machine⌉, au moins 1, au plus Ml.MACHINES_MAX.
local function machines_for(rate, par_min)
  if not par_min or par_min <= 0 then return 1 end
  return min(max(1, ceil((rate or 0) * Id.LEAD / par_min - 1e-9)), Ml.MACHINES_MAX or 64)
end

--- Range des demandes dans une rangée. demandes = { { item, recipe, machine, machines, solides, rate } } ; names = le kit (machine, bras, bras_long, tapis, poteau, coffre, decl) ;
--- rend (id du projet) ou (nil, raison, attendre).
function Rt.place(f, demandes, names, tick, afford, why_text)
  local b = f.build
  local st = b.mall
  repere(st)
  local rows_max, cells_in = Mr.capacite(st.sect)
  local cells_max = min(cells_in + floor((st.sect.ext or 0) / Mr.PERIODE), Mr.MAX_CELLS)
  -- une rangée dont les voies acceptent TOUT, sinon une neuve
  local row, newrow
  for _, r in ipairs(st.rows) do
    local all_in = not r.stop and #r.cells < cells_max
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
    machine = names.machine, bras = names.bras, bras_long = names.bras_long, tapis = names.tapis, poteau = names.poteau, coffre = names.coffre }, decl = names.decl } })
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

--- Une décision de Ind.think passe par le mall. c = { dec, kind, items } (Id.order) ; mod = prepare(...) ; rend vrai (pris) ou (faux, raison, attendre).
function Rt.accueille(f, c, mod, lec, tick, afford)
  if not Rt.ouvert(f) then return false, "ferme" end
  local demandes = {}
  for _, it in ipairs(c.items) do
    local dec = c.dec
    local rname = (c.kind == "bloc") and dec.recipes[it] or dec.recipe
    local rate = (c.kind == "bloc") and dec.rates[it] or dec.rate
    local e = lec.fab[rname]
    if not e then return false, "recette " .. tostring(rname) .. " non lue" end
    local solides = {}
    for _, s in ipairs(e.solides or {}) do solides[#solides + 1] = s.name end
    table.sort(solides)
    local par_min
    for _, m in ipairs(e.machines or {}) do if m.entity == dec.machine then par_min = m.par_min end end
    demandes[#demandes + 1] = { item = it, recipe = rname, machine = dec.machine, machines = machines_for(rate, par_min), solides = solides, rate = rate }
  end
  local kit = (c.kind == "bloc") and mod.args[3] or mod.args[5]
  local names = { machine = c.dec.machine, bras = kit.bras, bras_long = kit.bras_long, tapis = kit.tapis, poteau = mod.pole or kit.poteau, coffre = kit.coffre or Build.QUAI_CHEST, decl = kit.decl }
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
  local decl = { kit = kit.decl.kit, machines = { { machine = pr.machine, categories = { pr.entry.category } } } }
  A.declare(decl)
  local names = { machine = pr.machine.entity, bras = kit.bras, bras_long = kit.bras_long, tapis = kit.tapis, poteau = pole or kit.poteau, coffre = kit.coffre, decl = decl }
  st.names_kit = st.names_kit or names
  local machines = machines_for(o.rate or 0, pr.par_min)
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

--- Une fois par décision (Ind.think) : barres des coffres de sortie, cellules rendues par une section refusée, allongement, compteurs.
function Rt.minute(f, surface, lec, sources, afford, tick)
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
        for k = #r.cells, q.from, -1 do r.cells[k] = nil end
        if tostring(why):find("obstacle", 1, true) then r.stop = tostring(why) end
        say(f, st, tick, string.format("rangee %d : section %d-%d refusee (%s) : cellules rendues, arret : %s", r.j, q.from, q.to, tostring(why), tostring(r.stop)))
      end
    end
  end
  -- 2. allongement (une demande à la fois : la dernière section finie)
  if Rt.ouvert(f) and #st.rows > 0 then
    local rate_of = {}
    for _, c in ipairs(sources or {}) do rate_of[c.item] = c.rate end
    for _, r in ipairs(st.rows) do
      local last = r.projects[#r.projects]
      local p = last and b.projects[last.id]
      if not r.stop and p and p.state == "fini" and #r.cells < Mr.MAX_CELLS then
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
  -- 3. compteurs (lecture en FONCTION : objets fabriqués par le mall et sortis en coffre)
  local total_made, total_chests, total_m, total_run = 0, 0, 0, 0
  for _, r in ipairs(st.rows) do
    local made, chests, nm, run, waiting = 0, 0, 0, 0, 0
    for _, q in ipairs(r.projects) do
      local p = b.projects[q.id]
      if p and not q.dead then
        for _, e in ipairs(p.ents) do
          if e.role == "mall-machine_asm" then
            local en = surface.find_entity(e.name, { e.x, e.y })
            if en and en.force.name == f.force then
              nm = nm + 1
              made = made + (en.products_finished or 0)
              if en.status == defines.entity_status.working or en.status == defines.entity_status.low_power then run = run + 1 end
            end
          elseif e.role == "mall-sortie" then
            local ch, inv = chest_inv(surface, e.x, e.y)
            if ch and inv then chests = chests + inv.get_item_count() end
          end
        end
      end
    end
    r.made0 = r.made0 or 0
    local delta = made - r.made0
    r.made0 = made
    if nm > 0 and (delta > 0 or r.last_prod_m ~= nm) then
      r.last_prod_m = nm
      say(f, st, tick, string.format("PRODUCTION rangee %d : %d machine(s) dont %d en marche, %d objet(s) fabriques (+%d depuis la derniere minute), %d objet(s) dans les coffres de sortie, cellules %d, arret %s",
        r.j, nm, run, made, delta, chests, #r.cells, tostring(r.stop)))
    end
    total_made, total_chests, total_m, total_run = total_made + made, total_chests + chests, total_m + nm, total_run + run
  end
  st.fab = { made = total_made, chests = total_chests, machines = total_m, run = total_run, tick = tick }
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
          if ps then mods[#mods + 1] = { product = "mall:" .. r.j .. ":" .. q.from, state = ps.state, missing = ps.missing or {}, reason = ps.reason, gain = 0, pile = "capi" } end
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
  return { sect = st.sect, rep = st.rep, rows = rows, fab = st.fab, pret = st.pret, force = st.force_pret }
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
