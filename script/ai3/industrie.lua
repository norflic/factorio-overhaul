--[[
  Lot INDUSTRIE I6 « choix » : côté RUNTIME de la règle pure shared/ai3/industrie.lua (PLAN INDUSTRIE §1 à §3).
  Réglage maître : fo-war-industrie (script/ai3/reserve.lua, Rsv.on) ; éteint, rien de ce fichier ne décide ni ne change une méthode
  (le mod joue comme 0.6.28).

  Chaîne (déclencheur → décision → action → effet) :
    1. DÉCLENCHEUR  : la capitalisation (script/ai3/capitalisation.lua, decide) refuse une chaîne « manque sous une demi-machine
                      (X/min) » ; la main fabrique souvent un objet (Ml.note, cerveau) ; Ind.think reçoit la décision entière.
    2. DÉCISION     : Ml.want / Ml.sources (demande), Id.decide (shared/ai3/industrie.lua) : machine, besoin en machines, RANGÉE
                      (≥ une demi-machine : la capitalisation la pose, ses méthodes passent par A.method_for et le patron) ou BLOC DE
                      MALL partagé (sous une demi-machine, plusieurs objets sur 4 voies communes), un emplacement à part (Em.mall).
    3. ACTION       : Auto.submit d'un module « bloc » (ou « patron » d'une machine pour un objet à plus de 4 entrées ; lot MALL-RUE :
                      « ruban » quand la demande dépasse un lot, Ind.ruban_wanted : sections en série, la rue franchie en souterrain) : le plan
                      directeur le pose (Build.request), les PNJ le bâtissent, ils le garnissent depuis le coffre du QG (quais).
    4. EFFET        : les coffres de sortie du bloc sont inscrits à la collecte des PNJ (p.outs) et leur BARRE est posée à la cible
                      (Id.barre, F95) : la machine s'arrête seule quand l'avance est faite ; Ml.set_running (capitalisation) passe
                      la main aux machines. Journal [FO-MALL].
  Portes (relecture 0.6.31) : un bloc NEUF est une amélioration : ni sous menace du QG, ni pendant qu'un cadre de la pile retient (famille « capital »,
  sauf s'il produit la matière qui manque), ni sans centrale possible ; il se paie sur le stock hors besoin MOINS ce que la décision vient d'engager. Son coffre
  ne se vide vers le QG que sous la cible (p.keep_stock, Ml.target) : c'est ce qui laisse la barre arrêter la machine.
  Ce fichier fournit aussi à A.method_for (shared/ai3/automatiser.lua) la lecture des prototypes (cat.fab, cat.kit) : c'est ce qui
  lève le refus « a 3 ingredients » des chaînes (patrons du lot I5).
  Déterminisme : listes triées, aucune horloge mesurée (ticks de jeu), état en nombres et chaînes.
]]

local Id = require("shared.ai3.industrie")
local Ml = require("shared.ai3.mall")
local Famine = require("script.team.famine_fer") -- lot BUS-INTERMEDIAIRES : aucune ligne d'intermédiaire pendant la famine de la plaque clé (F434)
local Cv = require("shared.ai3.couverture") -- lot COUVERTURE : réserve de machines (Cv.reserve_wants, source de la demande du mall)
local AmRt = require("script.ai3.amorce_rt") -- lot VIDEO L7 : graine du mall (liste de matériel des prochains projets)
local Em = require("shared.ai3.emplacements")
local A = require("shared.ai3.automatiser")
local L = require("shared.ai3.lecture")
local Pt = require("shared.team.patrons")
local Book = require("shared.team.book")
local State = require("script.faction.state")
local Stock = require("script.team.stock")
local General = require("script.ai3.general")
local Dep = require("script.ai3.depenses") -- lot DEPENSES2 (revue E3) : vue débitée du stock hors besoin
local Auto = require("script.ai3.automatisation")
local Rsv = require("script.ai3.reserve")
local Harvest = require("script.team.harvest")
local Profiler = require("script.core.profiler")
local PileRt = require("script.team.pile")
local Events = require("script.core.events")
local MallRt = require("script.team.mall_rangee") -- lot MALL (tranche 2) : rangée du mall, avant le module isolé (docs/MALL.md §3)
local Mp = require("shared.team.mall_paving") -- lot MALL-RUE : la demande du mall dépasse-t-elle un lot ? (Mp.compact, règle pure) : le gabarit RUBAN
local Bi = require("shared.team.bus_intermediaires") -- lot BUS-INTERMEDIAIRES : lignes d'intermédiaires pivots (graphe des recettes), repli à la main
local T = require("shared.team.config") -- (matières que le bus fournit : produits des avant-postes et combustible, lus aux données)

local Ind = {}

Ind.RETRY_TICKS = 10 * 3600  -- un bloc refusé par le plan directeur n'est pas redemandé avant 10 minutes de jeu
local BLOC_GEN = { bloc = true, ruban = true } -- lot MALL-RUE : le ruban (sections en série, la rue franchie en souterrain) est un bloc pour tout le reste (mêmes args)
Ind.COLLECT_AT = 5           -- objets dans un coffre de sortie du mall qui envoient un PNJ le vider (Build.COLLECT_AT : 200)

-- Lot RECIPE-SOLVER (codé en parallèle) : `Solver.new(book, bus)`, `Solver.hubs(s, demands, k)` -> { { item, rate, machines } }. `require` gardé :
-- sans le module, aucune ligne d'intermédiaire (le mall joue comme avant). Ind.SOLVER est remplaçable par un banc (doublure).
Ind.SOLVER = nil
do
  local ok, m = pcall(require, "shared.team.recipe_solver")
  if ok and type(m) == "table" and type(m.new) == "function" and type(m.hubs) == "function" then Ind.SOLVER = m end
end

local function sorted_keys(t) return State.sorted_keys(t or {}) end

---------------------------------------------------------------------------------------------------
-- Lecture des prototypes pour A.method_for (cat.fab, cat.kit), construite à la demande
---------------------------------------------------------------------------------------------------
local LEC = nil
local building = false
local function lecture()
  if not Rsv.on() then return nil end
  if LEC then return LEC end
  if building then return nil end
  building = true
  local ok, d = pcall(General.dump)
  if ok and type(d) == "table" then
    local fab, machines = L.read(d, {})
    local kd = L.kit_data(d)
    LEC = { fab = fab, machines = machines, kit = function(u) return L.kit(kd, u) end }
  end
  building = false
  return LEC
end
A.set_lecture_provider(lecture)
Ind.lecture = lecture

---------------------------------------------------------------------------------------------------
-- État de l'équipe (global : nombres, chaînes, tables)
---------------------------------------------------------------------------------------------------
local function state_of(f)
  local ia3 = f.team.ia3
  ia3.industrie = ia3.industrie or { v = 1, id = {}, blocs = {}, hold = {}, refus = {}, n = 0, sig = "" }
  ia3.industrie.said = ia3.industrie.said or {}
  return ia3.industrie
end

local function minutes(f, tick)
  local war = State.war()
  return (tick - (f.started or (war and war.started) or 0)) / 3600
end

local function say(f, tick, text)
  log(string.format("[FO-MALL] %s minute %.1f | %s", f.key or "player", minutes(f, tick), text))
end

---------------------------------------------------------------------------------------------------
-- Coffres de sortie des patrons : inscrits à la collecte, barre à la cible
---------------------------------------------------------------------------------------------------
--- Coffres posés par les gabarits « patron » et « bloc » : les coffres de l'exécutant (A.exec_chest) du projet qui ne sont ni un quai
--- d'entrée (p.quais) ni déjà une sortie (p.outs : le plan directeur inscrit lui-même celles de ses quais de sortie).
local function patron_chests(p)
  local chest = A.exec_chest()
  -- clés par TUILE : les quais notent le coin de la tuile, les entités du plan son centre
  local known = {}
  for _, q in ipairs(p.quais or {}) do known[math.floor(q.x) .. "," .. math.floor(q.y)] = true end
  for _, o in ipairs(p.outs or {}) do known[math.floor(o.x) .. "," .. math.floor(o.y)] = true end
  local out = {}
  for _, e in ipairs(p.ents or {}) do
    if e.name == chest and not known[math.floor(e.x) .. "," .. math.floor(e.y)] then out[#out + 1] = e end
  end
  return out
end

--- Lot VIDEO-L4, complément (demande du lead, 7/11) : cases ouvertes du coffre de sortie i d'un projet à QUOTA (p.quota.outs[i].cases,
--- shared/team/quotas.lua, posé par script/team/quotas_glue.lua), ou nil (pas de quota : rien ne change).
local function quota_cases(p, i)
  local q = type(p.quota) == "table" and type(p.quota.outs) == "table" and p.quota.outs[i]
  local c = type(q) == "table" and q.cases
  if type(c) == "number" and c >= 1 then return math.floor(c) end
  return nil
end

--- Barre du coffre de sortie `o` : `cases` cases ouvertes (F95 : la barre borne aussi `insert` ; n cases ouvertes = barre n + 1), jamais plus
--- que le coffre n'en a. Rend 1 si elle est posée.
local function bar_out(surface, o, cases)
  local c = surface.find_entity(A.exec_chest(), { o.x, o.y })
  if not (c and c.valid) then return 0 end
  local inv = c.get_inventory(defines.inventory.chest)
  if not (inv and inv.supports_bar()) then return 0 end
  inv.set_bar(math.min(#inv, cases) + 1)
  return 1
end

--- Lot VIDEO-L4, complément : barre des coffres de sortie de TOUT projet fini qui a un quota (la sortie bornée à Q.SORTIE_MIN minutes de
--- son débit nominal : la machine s'arrête seule quand le coffre est plein) ; pour un patron ou un bloc, la plus petite avec sa barre à
--- lui (p.spec.args). Une fois par FIN du projet et par quota (p.quota_bar = fin|clé du quota) : un coffre refait l'a perdue, un quota
--- recalculé (cases sous la barre changées) la refait. Indépendant du réglage de l'industrie (les quotas de L4 valent sans lui).
local function quota_bars(f, b, surface)
  local n = 0
  if not surface then return 0 end
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    if p and p.state == "fini" and type(p.quota) == "table" then
      local mark = tostring(p.finished or 0) .. "|" .. tostring(p.quota_key)
      if p.quota_bar ~= mark then
        p.quota_bar = mark
        local gen = p.spec and p.spec.gen
        local args = (p.spec and p.spec.args) or {}
        local own = (gen == "patron" and args[6]) or (BLOC_GEN[gen] and args[4]) or nil
        for i, o in ipairs(p.outs or {}) do
          local cases = quota_cases(p, i)
          if cases then
            if type(own) == "number" and own > 0 and own < cases then cases = own end
            n = n + bar_out(surface, o, cases)
          end
        end
      end
    end
  end
  return n
end

--- Inscrit les coffres de sortie de tout projet « patron » ou « bloc » à la collecte (p.outs, seuil Ind.COLLECT_AT) et pose leur barre
--- quand le projet est fini. Rend le nombre de coffres inscrits et le nombre de barres posées. Idempotent : par tuile (patron_chests, un projet replanifié a
--- d'autres coffres), et la barre à chaque FIN du projet (p.ind_bar = p.finished) : un coffre refait par une reconstruction l'a perdue, la machine le remplirait.
--- Lot VIDEO-L4, complément : puis la barre de QUOTA de tout projet fini qui en a un (quota_bars, 3e valeur rendue).
function Ind.sweep(f, tick)
  local b = f.build
  if not b then return 0, 0, 0 end
  local surface = f.hq and f.hq.surface
  if not Rsv.on() then
    local qb = quota_bars(f, b, surface)
    if qb > 0 then say(f, tick, string.format("barres de quota : %d coffre(s) de sortie", qb)) end
    return 0, 0, qb
  end
  local reg, bars = 0, 0
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    local gen = p and p.spec and p.spec.gen
    if gen == "patron" or BLOC_GEN[gen] then
      local again = p.ind_bar ~= (p.finished or 0)
      if again and p.state ~= "attente" and p.state ~= "plan" and p.state ~= "reserve" and #(p.ents or {}) > 0 then
        for _, e in ipairs(patron_chests(p)) do
          p.outs[#p.outs + 1] = { x = e.x, y = e.y, at = Ind.COLLECT_AT }
          reg = reg + 1
        end
      end
      if again and p.state == "fini" and surface then
        local barre = (gen == "patron") and (p.spec.args or {})[6] or (p.spec.args or {})[4]
        p.ind_bar = p.finished or 0
        if type(barre) == "number" and barre > 0 then
          for _, o in ipairs(p.outs or {}) do
            local c = surface.find_entity(A.exec_chest(), { o.x, o.y })
            if c and c.valid then
              local inv = c.get_inventory(defines.inventory.chest)
              if inv and inv.supports_bar() then
                inv.set_bar(math.min(#inv, barre) + 1) -- F95 : la barre borne aussi `insert`; n cases ouvertes = barre n + 1
                bars = bars + 1
              end
            end
          end
        end
      end
    end
  end
  if reg > 0 or bars > 0 then
    say(f, tick, string.format("sorties des patrons : %d coffre(s) inscrit(s) a la collecte, %d barre(s) posee(s)", reg, bars))
  end
  -- (après la barre du patron ou du bloc : la barre de quota la remplace par la plus petite des deux)
  local qb = quota_bars(f, b, surface)
  if qb > 0 then say(f, tick, string.format("barres de quota : %d coffre(s) de sortie", qb)) end
  return reg, bars, qb
end

---------------------------------------------------------------------------------------------------
-- Module d'un bloc ou d'une cellule seule
---------------------------------------------------------------------------------------------------
local function recipe_table(book, rname)
  local r = book.recipes and book.recipes[rname]
  if not r then return nil end
  return { name = rname, category = r.category, energy = r.energy, ingredients = r.ingredients, products = r.products }
end

local function machine_entry(lec, recipe, entity)
  local e = lec.fab[recipe]
  for _, m in ipairs(e and e.machines or {}) do if m.entity == entity then return m, e end end
  return nil
end

--- Débit nominal (objets par minute) de la somme des produits d'un gabarit.
local function nominal_sum(g)
  local s = 0
  for _, k in ipairs(sorted_keys(g.nominal)) do if k ~= "electricity-kw" then s = s + g.nominal[k] * 60 end end
  return s
end

--- Prépare le module d'une décision : { gen, args, items, product, rate, g, why_not }. `ruban` (lot MALL-RUE) : le bloc prend le gabarit
--- RUBAN (shared/team/patrons.lua §6 bis : corridor continué de section en section, la rue franchie en souterrain) ; refusé (4 entrées
--- distinctes, cadence) : le bloc d'avant, comme si de rien n'était.
local function prepare(f, lec, book, view, dec, kind, ruban)
  local stock = view.stock or {}
  local usable = function(n) return book:handcraftable(n) or (stock[n] or 0) > 0 end
  local kit, why = A.patron_kit(lec, usable)
  if not kit then return nil, why end
  local items, recs, cats, slots_chest = {}, {}, {}, 0
  local first
  if kind == "bloc" then items = dec.items else items = { dec.item } end
  local barre = 1
  local pieces = kit.decl.kit
  -- le coffre posé est celui du plan directeur (A.exec_chest), pas forcément celui que la lecture trouve le moins cher
  local cp = game.entity_prototypes[A.exec_chest() or ""]
  slots_chest = cp and cp.get_inventory_size(defines.inventory.chest) or (pieces.coffre and pieces.coffre.slots) or 0
  for _, it in ipairs(items) do
    local rname = (kind == "bloc") and dec.recipes[it] or dec.recipe
    local rt = recipe_table(book, rname)
    if not rt then return nil, "limite : recette " .. tostring(rname) .. " inconnue du livre" end
    recs[#recs + 1] = rt
    first = first or machine_entry(lec, rname, dec.machine)
    local _, e = machine_entry(lec, rname, dec.machine)
    if e then cats[e.category] = true end
    local rate = (kind == "bloc") and dec.rates[it] or dec.rate
    local proto = game.item_prototypes[it]
    barre = math.max(barre, Id.barre(rate, proto and proto.stack_size or 1, slots_chest))
  end
  if not first then return nil, "limite : machine " .. tostring(dec.machine) .. " absente de la lecture" end
  local catl = sorted_keys(cats)
  local k2 = {}
  for kk, v in pairs(kit) do k2[kk] = v end
  k2.decl = { kit = pieces, machines = { { machine = first, categories = catl } } }
  A.declare(k2.decl)
  local args, gen
  if kind == "bloc" then
    gen, args = (ruban and "ruban" or "bloc"), { dec.machine, recs, k2, barre }
  else
    -- lot RB-3 : le kit d'une unité reste dans la machine (sortie « unite » : ni bras ni coffre de sortie)
    gen, args = "patron", { dec.machine, recs[1], dec.unite and "unite" or "coffre", 1, k2, barre }
  end
  local pole = A.choose_pole(book, stock, Harvest.reachable(f))
  local g, why2 = A.template(gen, args, pole, A.choose_arms(book, stock)) -- lot RECHERCHE-BRAS : bras obtenables
  if not g and gen == "ruban" then gen = "bloc"; g, why2 = A.template(gen, args, pole, A.choose_arms(book, stock)) end -- (lot MALL-RUE : repli sur le bloc)
  if not g then return nil, "gabarit refuse : " .. tostring(why2) end
  return { gen = gen, args = args, items = items, product = items[1], g = g, pole = g.pole, arms = g.arms, barre = barre }
end

--- Le stock HORS besoin paie-t-il cette liste de matériel { { objet, n } } ? (lot MALL : extrait de `affordable`) Rend vrai, ou faux et la raison.
local function afford_list(f, book, view, list, tick, orders)
  local stock = view.stock or {}
  local miss = {}
  for _, it in ipairs(list) do
    if not (book:handcraftable(it[1]) or (stock[it[1]] or 0) > 0) then miss[#miss + 1] = it[1] end
  end
  if #miss > 0 then return false, "recherche : " .. table.concat(miss, ",") end
  -- Lot DEPENSES2 (revue E3) : le stock hors besoin DÉBITÉ de ce que la règle du stock qui dort a accordé ou engagé (comme la capitalisation).
  local rv = Dep.capi_reserve(f, Rsv.input(f, tick), tick)
  if not rv then return false, "besoin non evalue (stock hors besoin inconnu)" end
  local free = {}
  for _, k in ipairs(sorted_keys(rv.free)) do free[k] = rv.free[k] end
  for _, o in ipairs(orders or {}) do
    for _, it in ipairs(o.items or {}) do
      if free[it[1]] then free[it[1]] = math.max(0, free[it[1]] - (it[2] or 0)) end
    end
  end
  local plan = book:plan(list, free)
  local short = {}
  -- Lot CC-BOIS (F504) : la matière naturelle que l'équipe récolte (le bois du petit poteau que A.choose_pole a retenu pour elle) ne bloque
  -- plus l'achat : même lecture que le choix du poteau (A.short_of) ; le chantier du bloc la demande, l'ouvrier la coupe.
  for _, it in ipairs(A.short_of(book, plan.raw, Harvest.reachable(f))) do short[#short + 1] = it[1] .. " " .. math.ceil(it[2]) end
  if #short > 0 then return false, "stock hors besoin insuffisant (manque " .. table.concat(short, ", ") .. ")" end
  return true
end

--- Stock LIBRE pour l'allongement du mall au surplus : hors besoin, débité de ce que cette décision engage et du fer mis de côté pour la défense (planificateur, defense_hold). Rend { [objet] = n } ou nil.
local function mall_libre(f, res, tick)
  local rv = Dep.capi_reserve(f, Rsv.input(f, tick), tick)
  if not rv then return nil end
  local hold = f.team and f.team.ia3 and f.team.ia3.defense_hold or {}
  local libre = {}
  for _, k in ipairs(sorted_keys(rv.free)) do libre[k] = math.max(0, rv.free[k] - (hold[k] or 0)) end
  for _, o in ipairs(res and res.orders or {}) do
    for _, it in ipairs(o.items or {}) do
      if libre[it[1]] then libre[it[1]] = math.max(0, libre[it[1]] - (it[2] or 0)) end
    end
  end
  return libre
end

--- Le stock HORS besoin paie-t-il le module ? Rend vrai, ou faux et la raison. Les objets du gabarit qu'on ne sait pas fabriquer
--- ni n'a au coffre sont refusés (« recherche : … »). `orders` : les ordres de la décision de cette minute, que le même stock paie déjà.
local function affordable(f, book, view, mod, tick, orders)
  local stock = view.stock or {}
  local meth = { gen = mod.gen, product = mod.product }
  local _, items = A.cost(meth, mod.g, { book = book, stock = stock, has_plant = Auto.plant_state(f) ~= nil })
  local list = {}
  for _, name in ipairs(sorted_keys(items)) do list[#list + 1] = { name, items[name] } end
  return afford_list(f, book, view, list, tick, orders)
end

---------------------------------------------------------------------------------------------------
-- Pensée (appelée une fois par décision de la capitalisation)
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Lot BUS-INTERMEDIAIRES : lignes d'intermédiaires pivots (règle pure : shared/team/bus_intermediaires.lua)
---------------------------------------------------------------------------------------------------
--- Matières que le bus fournit déjà : les produits des avant-postes (T.outposts[k].product) et le combustible (T.fuel), lus aux données.
local function bus_set()
  local out = {}
  for _, kind in ipairs(T.OUTPOST_ORDER or {}) do
    local o = T.outposts[kind]
    if o and o.product then out[o.product] = true end
  end
  if T.fuel then out[T.fuel] = true end
  return out
end

--- État d'une ligne (Bi.fallback) : présente quand une rangée du mall porte l'objet (b.mall.rows, cellules ih/ib), finie quand tous les projets de
--- cette rangée le sont ; relevés de suite sans production comptés sur cs.flows (production des MACHINES de la dernière minute, décision d'avant).
local function line_state(f, item, flows, prev)
  local b = f.build
  local present, done = false, true
  for _, r in ipairs((b and b.mall and b.mall.rows) or {}) do
    local hit = false
    for _, c in ipairs(r.cells or {}) do if c.ih == item or c.ib == item then hit = true end end
    if hit then
      present = true
      for _, q in ipairs(r.projects or {}) do
        local p = b.projects[q.id]
        if not (p and p.state == "fini") then done = false end
      end
    end
  end
  local fl = flows and flows[item]
  local produced = fl ~= nil and ((fl.made or 0) - (fl.hand or 0)) > 0
  return { present = present, done = present and done, empty_releves = Bi.empty_count(prev and prev.empty_releves or 0, produced) }
end

--- Les intermédiaires pivots (Solver.hubs sur la demande ENTIÈRE du mall : ce qu'il produit déjà, ml.items, et ce que la main et les autres sources
--- demandent, Ml.sources, hors les lignes elles-mêmes) deviennent des lignes (Bi.lines) demandées EN PRIORITÉ dès la phase mid : Ml.want (source
--- Bi.SRC, lu par Id.decide) et Ml.sinks (lignes d'abord : la capitalisation ouvre la chaîne, MallRt.chaine la pose en rangée). Écrit ml.bi =
--- { phase, lines, hubs, states, fallback, sig } (nombres, chaînes, booléens) : lu par le bus (script/team/bus.lua, Bus.hubs) et par la main
--- (Ml.hand_allowed). Phase : celle de l'arbre de décision écrite par Elec (f.elec.phase, Dt.phase) ; absente : early (aucune ligne).
local function intermediaires(f, ml, cs, book, tick)
  local S = Ind.SOLVER
  if not S then ml.bi = nil return end
  local phase = (f.elec and f.elec.phase) or "early"
  local own = {}
  for _, it in ipairs(ml.items or {}) do own[#own + 1] = { item = it.item, rate = it.rate, src = "mall" } end
  local demands = {}
  for _, c in ipairs(Id.merge({ own, Ml.sources(ml, tick) })) do
    if not (#c.srcs == 1 and c.srcs[1] == Bi.SRC) then demands[#demands + 1] = { item = c.item, rate = c.rate } end
  end
  local famine = Famine.team_starved(f, tick) == true
  local lines = Bi.lines(S.hubs(S.new(book, bus_set()), demands, Bi.CFG.k), phase, Bi.CFG, famine)
  local prev = (ml.bi and ml.bi.states) or {}
  local states, fallback = {}, {}
  for _, l in ipairs(lines) do
    Ml.want(ml, tick, l.item, l.rate_row or l.rate, Bi.SRC) -- (rate_row : une rangée d'abord, banc V0676-N)
    states[l.item] = line_state(f, l.item, cs.flows, prev[l.item])
    if Bi.fallback(states[l.item], Bi.CFG) then fallback[l.item] = true end
  end
  local sig = Bi.describe(lines, fallback)
  if sig ~= (ml.bi and ml.bi.sig) and (#lines > 0 or (ml.bi and ml.bi.sig)) then
    say(f, tick, string.format("rangee d'intermediaire demandee (phase %s, %d ligne(s)%s) : %s", phase, #lines, famine and ", famine de la plaque cle : lignes retenues" or "", sig))
  end
  ml.bi = { tick = tick, phase = phase, lines = lines, hubs = Bi.hub_rates(lines), states = states, fallback = fallback, sig = sig }
end

--- Lot MALL-RUE (décision du DC : « l'expansion industrielle et la continuité logistique priment sur la grille théorique ») : la demande du
--- mall dépasse-t-elle ce qu'un lot tient ? Les blocs vivants (st.blocs, hors morts) et les blocs décidés (cands), côte à côte avec leurs
--- têtes d'alimentation (Mp.compact, gap Mp.GAP), plus larges que P.LOT → vrai : le gabarit RUBAN (P.ruban), dont le corridor continue de
--- section en section, la rue franchie par un souterrain (Build.Pave, script/team/build.lua). Un ruban déjà vivant → vrai (continuité).
--- Largeur d'un bloc : celle de P.bloc / P.ruban (ceil(m / 2) colonnes de la machine lue, + P.TETE de chaque côté). Pur, déterministe.
function Ind.ruban_wanted(st, cands, width)
  local blocks = {}
  local function add(items, machine)
    local k = math.ceil(#items / 2)
    local mw = width[machine] or 3
    blocks[#blocks + 1] = { w = k * mw + (k - 1) + 2 * Pt.TETE, h = 1 }
  end
  for _, b in ipairs(st.blocs) do
    if b.gen == "ruban" and not b.dead then return true end
    if b.kind == "bloc" and not b.dead then add(b.items, b.machine or (cands[1] and cands[1].dec.machine)) end
  end
  for _, c in ipairs(cands) do if c.kind == "bloc" then add(c.dec.items, c.dec.machine) end end
  return #blocks >= 2 and Mp.compact(blocks, Mp.GAP).w > Pt.LOT
end

--- s40 p19 : blocs encore suivis. Un bloc mort (b.dead : refuse ou perdu, etats finaux du module ; ses objets sont deja reportes par st.hold)
--- restait pour toujours dans la liste : relu a chaque decision et a chaque Ind.status. Rend la MEME table quand aucun n'est mort.
function Ind.vivants(blocs)
  local out, morts = {}, 0
  for _, b in ipairs(blocs) do
    if b.dead then morts = morts + 1 else out[#out + 1] = b end
  end
  if morts == 0 then return blocs end
  return out
end

--- s40 p20 : memo des refus dits ({ [objet] = cause }) ramene aux objets ENCORE refuses (refus : liste { item, why }). Avant, une entree ne
--- partait jamais : un refus leve puis revenu avec la meme cause n'etait plus ecrit au journal, et la table ne faisait que grandir.
function Ind.refus_purge(memo, refus)
  local now = {}
  for _, r in ipairs(refus or {}) do now[r.item] = true end
  for _, k in ipairs(sorted_keys(memo)) do
    if not now[k] then memo[k] = nil end
  end
  return memo
end

function Ind.think(f, cs, res, view, book, tick)
  if not Rsv.on() then return nil end
  local lec = lecture()
  local ia3 = f.team and f.team.ia3
  if not (lec and ia3) then return nil end
  Profiler.start("ind:think")
  local st = state_of(f)
  local ml = ia3.mall
  if not ml then ml = Ml.new() ia3.mall = ml end
  -- 1. la demande non servie du cerveau : refus « manque sous une demi-machine »
  for _, r in ipairs(res and res.refus or {}) do
    if r.kind == "chaine" then
      local rate = Id.parse_refus(r.why)
      if rate and not (st.hold[r.item] and st.hold[r.item] > tick) then Ml.want(ml, tick, r.item, rate, "refus") end
    end
  end
  -- 1b. lot COUVERTURE : la pose prévue des ordres couvrir/ouvrir (foreuses, tapis, poteaux, fours du module) ÷ le rythme de pose (réserve de machines)
  for _, w in ipairs(cs.couv_wants or {}) do
    if not (st.hold[w.item] and st.hold[w.item] > tick) and not Ml.refused(ml, tick, w.item) then Ml.want(ml, tick, w.item, w.rate, Cv.SRC) end
  end
  -- 1c. lot BUS-INTERMEDIAIRES : les intermédiaires pivots du graphe des recettes deviennent des lignes demandées en priorité dès la phase mid (ml.bi :
  -- lu par le bus et par la main)
  intermediaires(f, ml, cs, book, tick)
  -- 2. objets déjà servis : machine posée (relevé de la capitalisation), chaîne ouverte, bloc en cours
  local served = {}
  for _, m in ipairs(cs.scan and cs.scan.machines or {}) do
    local e = lec.fab[m.recipe]
    for _, p in ipairs(e and e.produits or {}) do served[p] = true end
  end
  for _, o in ipairs(cs.open or {}) do if o.exec == "module" and o.item then served[o.item] = true end end
  for it in pairs(MallRt.served(f)) do served[it] = true end -- lot MALL : un objet servi (ou demandé) par une rangée du mall (union d'ensemble : l'ordre n'a aucun effet)
  local mods = {}
  st.blocs = Ind.vivants(st.blocs) -- s40 p19 : les blocs morts de la passe d'avant (report deja pose, etat final) ne sont plus relus
  for _, b in ipairs(st.blocs) do
    local m = Auto.module(f, b.id)
    b.state = m and tostring(m.state) or "perdu"
    if b.state == "refuse" or b.state == "perdu" then
      if not b.dead then
        b.dead = true
        for _, it in ipairs(b.items) do st.hold[it] = tick + Ind.RETRY_TICKS end
        say(f, tick, string.format("module %d [%s] %s (%s) : les objets sont redemandes dans %d min", b.id, table.concat(b.items, ","), b.state,
          tostring(m and m.reason or "?"), Ind.RETRY_TICKS / 3600))
      end
    else
      for _, it in ipairs(b.items) do served[it] = true end
      -- horloges d'ÉTAT (ticks de jeu) : dernier progrès des entités bâties, entrée en chantier (Em.work_tick)
      if m and (m.built or 0) ~= (b.built or -1) then b.built, b.progress_tick = m.built or 0, tick end
      b.work_tick = Em.work_tick(b.work_tick, { b.state }, tick)
      -- Em.mall : un bloc suspendu par la pile (il a rendu ses objets) depuis Em.PILE_HOLD ne tient plus l'emplacement
      b.pile_tick = Em.pile_tick(b.pile_tick, m ~= nil and m.state == "reserve" and m.reason == "pile", tick)
      if b.state ~= "fini" then
        mods[#mods + 1] = { key = b.id, states = { b.state }, progress_tick = b.progress_tick, opened = b.tick, work_tick = b.work_tick, pile_tick = b.pile_tick }
      end
    end
    if m and m.state == "fini" and not b.said_fini then
      b.said_fini = true
      say(f, tick, string.format("bloc %d [%s] FINI : %d entite(s) posee(s), sorties a la collecte des PNJ", b.id, table.concat(b.items, ","), m.built or 0))
    end
  end
  -- 3. la décision
  local stock = view.stock or {}
  -- lot VIDEO L7 : la liste de matériel des prochains projets du plan directeur, graine du mall (sans attendre 3 épisodes à la main) ;
  -- stock BRUT du coffre (la liste est brute)
  AmRt.seed(f, ml, tick, book, function(it) return Stock.count(f, it) end)
  local sources = Ml.sources(ml, tick)
  local keep = {}
  for _, c in ipairs(sources) do if not (st.hold[c.item] and st.hold[c.item] > tick) then keep[#keep + 1] = c end end
  local width = {}
  for _, m in ipairs(lec.machines or {}) do width[m.entity] = m.w end
  local out = Id.decide(st.id, { tick = tick, sources = { keep }, fab = lec.fab, served = served, unites = General.catalogue().unites,
    usable = function(n) return book:handcraftable(n) or (stock[n] or 0) > 0 end,
    bloc_max = function(ent) return Pt.colonnes(width[ent] or 3) * 2 end })
  for _, r in ipairs(out.refus) do Ml.refuse(ml, tick, r.item) end -- intégration 0.6.33 : lu par la demande de robots (script/robots/faction.lua)
  local sig = Id.describe(out)
  if sig ~= st.sig then
    st.sig = sig
    say(f, tick, sig)
    Ind.refus_purge(st.refus, out.refus) -- s40 p20 : un refus disparu est oublie (il sera redit s'il revient)
    for _, r in ipairs(out.refus) do
      if st.refus[r.item] ~= r.why then
        st.refus[r.item] = r.why
        say(f, tick, string.format("refus : %s : %s", r.item, r.why))
      end
    end
  end
  -- 4. l'action : un bloc (ou une cellule seule) au plus par décision, dans l'emplacement du mall ; un candidat qui attend (recherche, stock, pile) ne bloque
  -- pas les suivants. Aucun bloc neuf sous menace du QG (comme les leviers de la capitalisation).
  local sl = Em.mall({ mods = mods, tick = tick })
  if sl.room > 0 and not view.threatened then
    local function wait(label, kind, text)
      local line = string.format("%s %s attend : %s", kind, label, tostring(text))
      if st.said[label] ~= line then
        st.said[label] = line
        say(f, tick, line)
      end
    end
    local cands = Id.order(out) -- lot RB-FLUIDE : la cellule d'un kit d'unité passe devant les blocs
    local ruban = Ind.ruban_wanted(st, cands, width) -- lot MALL-RUE : la demande dépasse un lot : les blocs prennent le gabarit ruban
    if MallRt.ouvert(f) then cands = MallRt.ordonne(cands) end -- lot MALL : tapis et bras d'abord
    cands = Bi.order_cands(cands, ml.bi and ml.bi.hubs) -- lot BUS-INTERMEDIAIRES : les intermédiaires pivots devant les objets finis
    for _, c in ipairs(cands) do
      local dec, kind = c.dec, c.kind
      local label = kind == "bloc" and ("[" .. table.concat(dec.items, ",") .. "]") or dec.item
      local allowed, pwhy = PileRt.porte_any(f, "capital", c.items)
      local mod, why
      if allowed then mod, why = prepare(f, lec, book, view, dec, kind == "bloc" and "bloc" or "cellule", ruban) end
      -- lot MALL (tranche 2, docs/MALL.md §3) : l'état S vrai, ces objets vont dans une rangée du mall (allongée) et plus dans un module isolé.
      -- Refus du mall (rangées pleines, entrée hors voies) : le module isolé d'avant, cause écrite ; attente (matériel) : pas de module isolé
      local mall_ok, mall_why, mall_wait
      if allowed and mod and MallRt.ouvert(f) and f.build and f.build.mall then
        local vstock = view.stock or {}
        mall_ok, mall_why, mall_wait = MallRt.accueille(f, c, mod, lec, tick, function(list) return afford_list(f, book, view, list, tick, res and res.orders) end,
          function(n) return book:handcraftable(n) or (vstock[n] or 0) > 0 end)
      end
      if mall_ok then
        st.said[label] = nil
        say(f, tick, string.format("%s %s : rangee du mall (au lieu d'un module isole)", kind, label))
        break
      elseif mall_wait then
        wait(label, kind, "mall : " .. tostring(mall_why))
      elseif not allowed then
        PileRt.refuse(f, "mall:" .. label, kind .. " " .. label .. " non demande (" .. tostring(pwhy) .. ")", tick)
      elseif not mod then
        say(f, tick, string.format("%s %s refuse : %s", kind, label, tostring(why)))
        for _, it in ipairs(c.items) do
          st.hold[it] = tick + Ind.RETRY_TICKS
          Ml.refuse(ml, tick, it)
        end
      elseif (mod.g.power_kw or 0) > 0 and Auto.plant_state(f) == "refuse" then
        wait(label, kind, "centrale refusee")
      else
        local ok, why2 = affordable(f, book, view, mod, tick, res and res.orders)
        if not ok then
          wait(label, kind, why2)
        else
          local rate = 0
          for _, it in ipairs(mod.items) do rate = rate + ((kind == "bloc") and dec.rates[it] or dec.rate) end
          -- feed = "quai" : toute entrée d'un bloc se sert au coffre du QG par un quai, JAMAIS par des foreuses (script/team/build.lua, plan_feed :
          -- une voie de matière brute à plus de P.AUTO_FLOW envoyait le bloc chercher un gisement ; mesuré au banc ind-jetable : 4 foreuses, 154 entités)
          local id, why3 = Auto.submit(f, { product = mod.product, gen = mod.gen, args = mod.args, feed = "quai", rate = rate,
            rate_nom = nominal_sum(mod.g), electric = (mod.g.power_kw or 0) > 0, gain = 1, pole = mod.pole, arms = mod.arms,
            why = "MALL " .. kind .. " " .. label }, tick, nil)
          if id then
            st.blocs[#st.blocs + 1] = { id = id, items = mod.items, kind = kind, tick = tick, state = "attente", gen = mod.gen,
              barre = mod.barre, machine = dec.machine } -- (machine : lot MALL-RUE, largeur des blocs vivants pour Ind.ruban_wanted)
            st.n = st.n + 1
            st.said[label] = nil
            -- la réserve du mall : le coffre de sortie se vide vers le QG sous cette cible seulement (script/team/build.lua, out_wanted)
            local p = f.build and f.build.projects[id]
            if p then
              p.keep_stock = {}
              for _, it in ipairs(mod.items) do
                p.keep_stock[it] = math.max(Ind.COLLECT_AT, Ml.target((kind == "bloc") and dec.rates[it] or dec.rate))
              end
            end
            say(f, tick, string.format("%s %s DEMANDE : module %d (%s, %d entite(s), %.1f objets/min voulus, nominal %.1f, barre %d case(s)) -> %s",
              kind, label, id, mod.gen, mod.g.n_ent, rate, nominal_sum(mod.g), mod.barre, "plan directeur"))
            break
          end
          say(f, tick, string.format("%s %s : demande impossible (%s)", kind, label, tostring(why3)))
          for _, it in ipairs(mod.items) do st.hold[it] = tick + Ind.RETRY_TICKS end
        end
      end
    end
  end
  MallRt.minute(f, f.hq and f.hq.surface, lec, keep, function(list) return afford_list(f, book, view, list, tick, res and res.orders) end, tick, mall_libre(f, res, tick)) -- lot MALL : barres, cellules rendues, allongement, compteurs
  Ind.sweep(f, tick)
  for _, k in ipairs(sorted_keys(st.hold)) do if st.hold[k] <= tick then st.hold[k] = nil end end
  Profiler.stop("ind:think")
  return out
end

--- Au chargement, M.BASE (shared/team/modules.lua) repart de ses données : les machines et les pièces d'un mod posées par un patron sont redéclarées d'après
--- les arguments sauvés, sinon P.size lèverait dès le premier relevé d'un projet (reconstruction, relevé des tuiles). Rien n'est écrit dans global.
Events.on_load(function()
  pcall(function()
    local list = { State.faction("player") }
    for _, id in ipairs(State.alive()) do list[#list + 1] = State.faction(id) end
    for _, f in ipairs(list) do
      local b = f.build
      for _, pid in ipairs(b and b.order or {}) do
        local spec = b.projects[pid] and b.projects[pid].spec
        local gen = spec and spec.gen
        if gen == "patron" or BLOC_GEN[gen] then
          local kit = (spec.args or {})[gen == "patron" and 5 or 3]
          if type(kit) == "table" then A.declare(kit.decl) end
        end
      end
    end
  end)
end)

local function team_of(key)
  if key == "player" then return State.faction("player") end
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and (f.key == key or id == key) then return f end
  end
  return nil
end

--- État lisible (bancs).
function Ind.status(f)
  local st = f and f.team and f.team.ia3 and f.team.ia3.industrie
  if not st then return nil end
  local blocs = {}
  for _, b in ipairs(st.blocs) do
    local m = Auto.module(f, b.id)
    local p = f.build and f.build.projects[b.id]
    local outs, quais = {}, {}
    for _, o in ipairs(p and p.outs or {}) do outs[#outs + 1] = { x = o.x, y = o.y, at = o.at } end
    for _, q in ipairs(p and p.quais or {}) do quais[#quais + 1] = { x = q.x, y = q.y, item = q.item } end
    blocs[#blocs + 1] = { id = b.id, items = b.items, kind = b.kind, state = m and m.state or b.state, built = m and m.built or 0,
      total = m and m.total or 0, outs = outs, quais = quais, barre = b.barre, reason = m and m.reason or nil, missing = m and m.missing or nil,
      keep = p and p.keep_stock or nil }
  end
  return { n = st.n, blocs = blocs, sig = st.sig }
end

-- Interface distante (BANCS SEULEMENT) : demande notée, pensée hâtée, stock injecté, état.
remote.add_interface("fo-ind", {
  --- Note la demande de `item` (objets par minute) comme le ferait un refus de la capitalisation.
  want = function(key, item, rate)
    local f = team_of(key)
    local ia3 = f and f.team and f.team.ia3
    if not ia3 then return false end
    ia3.mall = ia3.mall or Ml.new()
    return Ml.want(ia3.mall, game.tick, item, rate, "banc")
  end,
  --- Fait décider la capitalisation à la prochaine pensée (la première décision tombe sinon vers le tick 3 300) ; vrai si elle a déjà relevé ses machines.
  hasten = function(key)
    local f = team_of(key)
    local cs = f and f.team and f.team.capi
    if not (cs and cs.scan) then return false end
    cs.n = 10
    return true
  end,
  --- Pose des objets au coffre d'équipe : list = { { nom, nombre } }. Rend le nombre inséré par objet.
  stock = function(key, list)
    local f = team_of(key)
    local chest = f and (f.hq or f.chest)
    if not (chest and chest.valid) then return nil end
    local out = {}
    for _, it in ipairs(list or {}) do out[it[1]] = chest.insert({ name = it[1], count = it[2] }) end
    return out
  end,
  --- BANC SEULEMENT (le temps : des PNJ à 1 minute de jeu mettent plus de 9 000 ticks à bâtir 55 entités) : ravive les fantômes du projet `id`
  --- comme le ferait un PNJ (même geste que script/team/build.lua : ravivage, puis recette de la machine). Le reste (états, fils, fin) est celui du plan directeur.
  revive = function(key, id)
    local f = team_of(key)
    local p = f and f.build and f.build.projects[id]
    local surface = f and f.hq and f.hq.surface
    if not (p and surface) then return nil end
    local n = 0
    for _, e in ipairs(p.ents or {}) do
      if not e.built then
        for _, gh in ipairs(surface.find_entities_filtered({ ghost_name = e.name, position = { e.x, e.y }, radius = 0.3, force = f.force })) do
          if gh.valid then
            local _, ent = gh.revive({ raise_revive = true })
            if ent and ent.valid then
              n = n + 1
              e.built, e.ghosted = true, nil
              if e.recipe and ent.type == "assembling-machine" then pcall(ent.set_recipe, e.recipe) end
            end
          end
        end
      end
    end
    return n
  end,
  status = function(key)
    local f = team_of(key)
    return f and Ind.status(f) or nil
  end,
  --- BANC SEULEMENT : demande à l'exécutant UNE RANGÉE de `item` au débit `rate` (objets/min), par le chemin des ordres « chaîne » de la
  --- capitalisation (A.method_for, A.sized, Auto.submit : script/ai3/capitalisation.lua, execute) sans passer par sa décision. Rend l'id du module.
  row = function(key, item, rate)
    local f = team_of(key)
    local ia3 = f and f.team and f.team.ia3
    if not (ia3 and f.hq and f.hq.valid) then return nil, "equipe" end
    local force = game.forces[f.force]
    local book = Book.from_game(game.recipe_prototypes, { allowed = function(name)
      local r = force.recipes[name]
      return r ~= nil and r.enabled
    end })
    local inv = f.hq.get_inventory(defines.inventory.chest)
    local contents = inv and inv.get_contents() or {}
    local usable = function(n) return book:handcraftable(n) or (contents[n] or 0) > 0 end
    local meth, why = A.method_for(item, book, usable)
    if not meth then return nil, why end
    local g, args = A.sized(meth, rate, A.choose_pole(book, contents, Harvest.reachable(f)), A.choose_arms(book, contents))
    if not g then return nil, args end
    local id, why2 = Auto.submit(f, { product = item, gen = meth.gen, args = args, feed = meth.feed, rate = rate,
      rate_nom = (g.nominal[item] or 0) * 60, electric = (g.power_kw or 0) > 0, gain = 1, pole = g.pole, arms = g.arms, why = "banc : rangee" }, game.tick, nil)
    if not id then return nil, why2 end
    local st = state_of(f)
    st.blocs[#st.blocs + 1] = { id = id, items = { item }, kind = "rangee", tick = game.tick, state = "attente", gen = meth.gen, barre = 0 }
    return id, string.format("%s %s %d machine(s) demandee(s), %d entites", meth.gen, tostring(meth.patron and meth.args[1] or meth.args[3]),
      meth.patron and args[4] or 1, g.n_ent)
  end,
  --- Le fournisseur de lecture répond-il ? (nombre de recettes lues, ou nil)
  lecture = function()
    local lec = lecture()
    if not lec then return nil end
    local n = 0
    for _ in pairs(lec.fab) do n = n + 1 end
    return n
  end,
  --- La méthode que A.method_for donnerait pour `item` : { gen, machine, sortie, entrees } ou nil, raison. (`book` : celui de la force.)
  methode = function(item)
    local lec = lecture()
    if not lec then return nil, "lecture absente" end
    local d = General.dump()
    local book = Book.new(d.recipes)
    local m, why = A.method_for(item, book, nil)
    if not m then return nil, why end
    local g = A.template(m.gen, m.args)
    return { gen = m.gen, machine = m.patron and m.args[1] or m.args[3], sortie = m.patron and m.args[3] or nil, n_ent = g and g.n_ent or 0 }
  end,
})

return Ind
