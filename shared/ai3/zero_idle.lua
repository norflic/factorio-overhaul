--[[
  Lot ZERO-IDLE (demande du DC, 8/11, 14 h 35 : « Tolérance zéro pour l'inactivité et expansion continue : S'il y a la moindre
  possibilité matérielle de crafter des foreuses et de construire de nouveaux fours, les agents doivent le faire sans aucune
  interruption. ») : règle PURE (aucune API Factorio).

  Quand des PNJ sont libres ET que le stock libre paie au moins un kit d'agrandissement d'une FONDERIE (paires foreuse + four d'un
  avant-poste dont le produit est fondu : produit ≠ ressource), un agrandissement est émis TOUT DE SUITE, sans attendre la saturation,
  la croissance des capacités visées (B.targets), la confirmation ni les emplacements de la capitalisation : c'est le chemin
  « extend » des avant-postes (shared/ai3/projets.lua, tâche « extend », script/team/worker.lua), servi en FOND (hors des K projets,
  après tous les autres, avec le reste du stock virtuel). Le PNJ libre fabrique les pièces qui manquent à la main (P.want), puis la
  tâche « extend » les pose.

  Plafond : le nombre de PNJ libres et le stock (un kit par PNJ libre, tant que le livre de recettes le paie), JAMAIS une constante de
  chantiers. Un avant-poste reçoit un agrandissement à la fois (clé « extend:<id> »).

  Causes (une par type de fonderie qui n'a plus rien émis à cette pensée) : « plein » (aucun avant-poste du type n'a de place : il faut
  un nouveau site, relève), « sans_avant_poste » (l'équipe n'a AUCUN avant-poste du type : k.n_any = 0, lot INJOIGNABLE), « en_cours » (chaque avant-poste avec place a déjà son agrandissement pris), « non_defendu » (les autres
  sont interdits par « défendre d'abord » : Planner.no_go), « combustible » (le kit ne manque que de combustible), « stock » (le kit
  manque d'une autre matière), « palier:<raison> » (aucune foreuse permise par la règle des paliers : thermique interdite par la bascule
  électrique, par exemple), « menace » (QG menacé : personne ne part agrandir).

  Paliers de foreuse (entrée `tiers`, dans l'ordre de préférence) : la règle prend le premier palier PERMIS (ok) ; le runtime ne donne
  aujourd'hui que le palier thermique (kit Planner.outpost_items) ; un palier électrique se branche par ctx.zi_tiers. Le thermique est
  refusé quand la bascule électrique l'interdit (view.thermal_off, lot ELECTRIQUE) ou quand un module électrique fini couvre le produit.

  Coût : au plus (PNJ libres + types) plans du livre (Book:plan) par pensée ; pire cas mesuré par debug.sethook dans
  tests/zero_idle_test.lua.
]]

local T = require("shared.team.config")
local Planner = require("shared.team.planner")
local R = require("shared.ai3.reglages")
local P = require("shared.ai3.projets")

local ZI = {}

-- Interrupteur (faux = la règle d'avant, aucun but). Hors jeu seulement, FO_ZERO_IDLE_OFF=1 l'éteint (témoin des bancs : `os` n'existe
-- pas dans le Lua du jeu, la règle y est toujours allumée).
ZI.ON = not (type(os) == "table" and type(os.getenv) == "function" and os.getenv("FO_ZERO_IDLE_OFF") == "1")
ZI.VALUE = 48     -- valeur du but (fond) : prio des tâches = P.prio_of(48) = 61, + P.FINISH_BONUS pour la pose (au-dessus du minage de fond)
ZI.KEY = "zero-idle:"

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

local function copy(t)
  local out = {}
  for _, k in ipairs(sorted_keys(t or {})) do out[k] = t[k] end
  return out
end

--- Types d'avant-postes qui sont des FONDERIES (la paire porte un four : produit ≠ ressource), dans l'ordre `order` (ressources clés
--- du besoin), puis T.OUTPOST_ORDER pour les autres. Aucun nom d'objet ici : tout vient de T.outposts.
function ZI.smelter_kinds(order)
  local out, seen = {}, {}
  local function add(kind)
    local spec = kind and T.outposts[kind]
    if spec and not seen[kind] and spec.product ~= spec.resource then
      seen[kind] = true
      out[#out + 1] = kind
    end
  end
  for _, k in ipairs(order or {}) do add(k) end
  for _, k in ipairs(T.OUTPOST_ORDER) do add(k) end
  return out
end

--- Paliers de foreuse d'un type : `forced` (ctx.zi_tiers[kind], liste { name, kit, ok, why }) sinon le palier thermique seul. Un produit
--- COUVERT par un module électrique fini (`covered`, st.covered posé par C.think à la pensée précédente) ne reçoit plus de paires
--- thermiques (ses tournées ordinaires sont déjà retirées : des brûleurs ajoutés là ne seraient ni ravitaillés ni vidés) : palier refusé
--- « couvert-electrique » ; son agrandissement est électrique (capitalisation, plan directeur).
--- `thermal_off` ({ [type] = raison }, view.thermal_off du lot ELECTRIQUE, script/team/electrique.lua) : la bascule électrique refuse les
--- paires thermiques de ce type (palier refusé « electrique:<raison> » ; ses tâches thermiques seraient filtrées au tableau).
function ZI.tiers(kind, forced, covered, thermal_off)
  if forced and forced[kind] then return forced[kind] end
  local spec = T.outposts[kind]
  local cov = covered and spec and covered[spec.product]
  local off = thermal_off and thermal_off[kind]
  local why = (off and ("electrique:" .. tostring(off))) or (cov and "couvert-electrique") or nil
  return { { name = "thermique", kit = Planner.outpost_items(kind), ok = not (cov or off), why = why } }
end

--- Lot AUTO-FINANCEMENT (directive du DC du 9/11, validée : « l'auto-financement sur les gisements ») : le kit d'agrandissement ne manque
--- QUE de la plaque de l'avant-poste (raw = { [product] = n }) et les sorties de cet avant-poste (ses fours, lues par la vue : o.outputs)
--- en tiennent au moins n : le PNJ part avec le reste du kit (pierre, combustible, pièces déjà au coffre), prend n plaques SUR PLACE et
--- fabrique les foreuses et les fours devant le gisement. Mesuré (graine 1618033988, 0.6.74) : 114 prises « extend:matiere » à 15 min
--- pendant que les fours de l'avant-poste débordaient et que le QG manquait de 458 à 1 220 plaques ; famine de 60 min.
--- Rend nil, ou { items (pièces portées depuis le QG, triées), n (plaques prises sur place), crafts (Book:plan, ordre exécutable),
--- ticks (durée des fabrications, secondes du livre × 60 + ZI.CRAFT_SLACK), avail (stock virtuel après la prise) }.
ZI.CRAFT_SLACK = 30
function ZI.onsite(book, kit, avail, raw, product, outputs)
  if not (book and product and raw) then return nil end
  local n = raw[product]
  if not n or n <= 0 then return nil end
  n = math.ceil(n) -- (une autre matière qui manque aussi laisse p2.raw non vide : refus plus bas)
  if ((outputs or {})[product] or 0) < n then return nil end
  local a2 = copy(avail)
  a2[product] = (a2[product] or 0) + n
  local p2 = book:plan(kit, a2)
  if next(p2.raw) ~= nil then return nil end
  local items = {}
  for _, it in ipairs(sorted_keys(p2.uses)) do
    local q = p2.uses[it]
    if it == product then q = q - n end -- les n plaques prises sur place ne sortent pas du coffre du QG
    if q > 0 then items[#items + 1] = { it, q } end
  end
  local secs = 0
  for _, c in ipairs(p2.crafts) do secs = secs + (c.energy or 0) end
  local crafts = {}
  for _, c in ipairs(p2.crafts) do crafts[#crafts + 1] = { recipe = c.recipe, runs = c.runs } end
  return { items = items, n = n, crafts = crafts, ticks = math.ceil(secs * 60) + ZI.CRAFT_SLACK, avail = p2.avail }
end

--- Décision PURE. inp = {
---   idle (PNJ sans tâche), fond (PNJ au fond doux : minage à la main, garde ; prêts à poser), threat (QG menacé),
---   book (livre de recettes : Book:plan), avail (stock virtuel { [objet] = n }), fuel (objet combustible),
---   kinds = { { kind, product, outposts = { { id, d2 } } (avec place, triés), open = { [id] = vrai }, no_go = { [id] = vrai },
---             tiers = { { name, kit, ok, why } } } } (ordre du besoin) }.
--- Rend { orders = { { kind, outpost, tier, items, onsite } }, idle, left, causes = { [kind] = cause }, missing = { [objet] = n }, plans, onsite }.
function ZI.decide(inp)
  local hands = math.max(0, (inp.idle or 0) + (inp.fond or 0))
  local res = { orders = {}, idle = inp.idle or 0, fond = inp.fond or 0, hands = hands, left = hands, causes = {}, missing = {}, plans = 0 }
  if hands <= 0 then return res end
  if inp.threat then
    for _, k in ipairs(inp.kinds or {}) do res.causes[k.kind] = "menace" end
    if #(inp.kinds or {}) == 0 then res.causes["*"] = "menace" end
    return res
  end
  if #(inp.kinds or {}) == 0 then
    res.causes["*"] = "aucune_fonderie"
    return res
  end
  local avail = copy(inp.avail)
  local state = {}
  for i, k in ipairs(inp.kinds) do state[i] = { idx = 1, done = false, n_open = 0, n_nogo = 0 } end
  local left = hands
  while left > 0 do
    local progressed = false
    for i, k in ipairs(inp.kinds) do
      if left <= 0 then break end
      local s = state[i]
      if not s.done then
        -- avant-poste suivant avec place, sans agrandissement pris, permis
        local o
        local list = k.outposts or {}
        while s.idx <= #list do
          local c = list[s.idx]
          s.idx = s.idx + 1
          if (k.open or {})[c.id] then s.n_open = s.n_open + 1
          elseif (k.no_go or {})[c.id] then s.n_nogo = s.n_nogo + 1
          else o = c break end
        end
        if not o then
          s.done = true
          -- lot INJOIGNABLE (partie du DC, 0.7.113 : « iron=plein » pendant 30 min chez azure sans AUCUN avant-poste de fer) : sans
          -- avant-poste du type (k.n_any == 0), la cause est « sans_avant_poste » (il faut ouvrir un site), pas « plein ». Une simple
          -- étiquette : rien n'est émis, le PNJ reste libre pour la tâche « build » du projet d'extraction.
          if #list == 0 then res.causes[k.kind] = res.causes[k.kind] or ((k.n_any == 0) and "sans_avant_poste" or "plein")
          elseif s.n_open >= s.n_nogo then res.causes[k.kind] = res.causes[k.kind] or "en_cours"
          else res.causes[k.kind] = res.causes[k.kind] or "non_defendu" end
        else
          local tier, refused = nil, nil
          for _, t in ipairs(k.tiers or {}) do
            if t.ok then tier = t break end
            refused = refused or t
          end
          if not tier then
            s.done = true
            res.causes[k.kind] = "palier:" .. tostring(refused and refused.why or "aucun")
          else
            local p = inp.book:plan(tier.kit, avail)
            res.plans = res.plans + 1
            local self_paid = (next(p.raw) ~= nil) and ZI.onsite(inp.book, tier.kit, avail, p.raw, k.product, o.outputs) or nil -- lot AUTO-FINANCEMENT
            if self_paid then
              avail = self_paid.avail
              res.orders[#res.orders + 1] = { kind = k.kind, outpost = o.id, tier = tier.name, items = self_paid.items, product = k.product,
                onsite = { item = k.product, n = self_paid.n, crafts = self_paid.crafts, ticks = self_paid.ticks } }
              res.onsite = (res.onsite or 0) + 1
              left = left - 1
              progressed = true
            elseif next(p.raw) ~= nil then
              s.done = true
              local only_fuel = true
              for _, item in ipairs(sorted_keys(p.raw)) do
                if item ~= inp.fuel then only_fuel = false end
                res.missing[item] = math.max(res.missing[item] or 0, math.ceil(p.raw[item]))
              end
              res.causes[k.kind] = only_fuel and "combustible" or "stock"
            else
              avail = p.avail
              res.orders[#res.orders + 1] = { kind = k.kind, outpost = o.id, tier = tier.name, items = tier.kit, product = k.product }
              left = left - 1
              progressed = true
            end
          end
        end
      end
    end
    if not progressed then break end
  end
  res.left = left
  return res
end

--- Entrée de la règle depuis la pensée pure (shared/ai3/cerveau.lua, C.think) : vue de l'équipe, situation `s`, livre, stock virtuel
--- après le planificateur permanent (`avail`), contexte (`ctx.zi_tiers` : paliers imposés ; facultatif), produits couverts par un module
--- électrique fini (`covered`, facultatif).
function ZI.input(view, s, book, avail, ctx, covered)
  local kinds = {}
  local turret_ok = view.defend_first and ((book.handcraftable and book:handcraftable(R.TURRET)) or (avail[R.TURRET] or 0) > 0) or false
  local no_go = Planner.no_go(view, turret_ok)
  local open = view.open or {}
  for _, kind in ipairs(ZI.smelter_kinds(s.key and s.key.order)) do
    local spec = T.outposts[kind]
    local outs, op, n_any = {}, {}, 0
    for _, o in ipairs(view.outposts or {}) do
      if o.kind == kind then n_any = n_any + 1 end
      if o.kind == kind and not o.full and (o.drills or 0) < T.max_drills(kind) then
        outs[#outs + 1] = { id = o.id, d2 = o.d2 or 0, outputs = o.outputs } -- (outputs : sorties de l'avant-poste, lot AUTO-FINANCEMENT)
        if open["extend:" .. tostring(o.id)] then op[o.id] = true end
      end
    end
    table.sort(outs, function(a, b)
      if a.d2 ~= b.d2 then return a.d2 < b.d2 end
      return tostring(a.id) < tostring(b.id)
    end)
    kinds[#kinds + 1] = { kind = kind, product = spec.product, outposts = outs, open = op, no_go = no_go, n_any = n_any,
      tiers = ZI.tiers(kind, ctx and ctx.zi_tiers, covered, view.thermal_off) }
  end
  local peril = view.qg_peril and view.qg_peril.peril
  return { idle = view.workers_idle or 0, fond = view.workers_fond or 0, threat = (view.hq_threat or peril) and true or false,
    book = book, avail = avail, fuel = T.fuel, kinds = kinds }
end

--- Buts de la décision (famille extraction, FOND : hors des K projets), à ajouter à la liste des buts de la pensée. Clé STABLE par
--- type et rang (« zero-idle:iron:2 ») : le projet ne se ferme et ne se rouvre pas (journal [FO-IA3C]) quand l'avant-poste visé change.
function ZI.goals(res)
  local out, rank = {}, {}
  for _, o in ipairs(res.orders or {}) do
    rank[o.kind] = (rank[o.kind] or 0) + 1
    out[#out + 1] = { key = ZI.KEY .. o.kind .. ":" .. rank[o.kind], family = "extraction", kind = "zero_idle", outpost = o.kind,
      target = o.outpost, items = o.items, tier = o.tier, fond = true, zero_idle = true, value = ZI.VALUE, why = o.product, onsite = o.onsite }
  end
  return out
end

--- Résumé GARDÉ dans l'état (global : nombres et chaînes seulement) : relu par le runtime pour la ligne [FO-ZERO-IDLE].
function ZI.summary(res)
  local orders = {}
  for _, o in ipairs(res.orders or {}) do orders[#orders + 1] = o.kind .. ":" .. tostring(o.outpost) .. ":" .. o.tier .. (o.onsite and ":auto-finance" or "") end
  return { idle = res.idle or 0, fond = res.fond or 0, emitted = #(res.orders or {}), left = res.left or 0,
    causes = copy(res.causes), missing = copy(res.missing), orders = orders, plans = res.plans or 0 }
end

--- Émission d'un but « zero_idle » (enregistrée dans P.EMIT). La pose prend le kit au stock virtuel ; sinon le kit est FABRIQUÉ à la
--- main (P.want) quand tout se fabrique avec ce qui reste au stock virtuel ; jamais de minage à la main pour lui (raw non vide :
--- « matiere », le reste du stock est allé aux projets d'avant).
P.EMIT.zero_idle = function(E, proj, g)
  local key = "extend:" .. tostring(g.target)
  if E.open[key] or E.keys[key] then return "en_cours" end
  if P.take(E, g.items) then
    P.add(E, { key = key, kind = "extend", prio = (proj.prio or 0) + P.FINISH_BONUS, outpost = g.target, outpost_kind = g.outpost,
      items = g.items, ia3 = proj.id, why = proj.key, zero_idle = true, onsite = g.onsite }) -- (onsite : lot AUTO-FINANCEMENT, plaques prises sur place)
    return "ok"
  end
  if g.onsite then return "matiere" end -- (les pièces portées ne sont plus au stock virtuel : pas de fabrication à la main pour elles)
  local p = E.book:plan(g.items, E.avail)
  if next(p.raw) ~= nil then return "matiere" end
  P.want(E, proj, g.items, proj.prio or 0, false, "zero-idle")
  return "matiere"
end

---------------------------------------------------------------------------------------------------
-- Journal [FO-ZERO-IDLE] : une ligne par minute où un PNJ est resté libre (accumulateur dans l'état, nombres seulement)
---------------------------------------------------------------------------------------------------
--- Ajoute le résumé d'une pensée à l'accumulateur de la minute (créé s'il est nil) ; rend l'accumulateur.
function ZI.note(acc, sm)
  acc = acc or { n = 0, idle = 0, fond = 0, emitted = 0, left = 0, causes = {}, missing = {}, orders = {} }
  if not sm then return acc end
  acc.n = acc.n + 1
  acc.idle = acc.idle + (sm.idle or 0)
  acc.fond = acc.fond + (sm.fond or 0)
  acc.emitted = acc.emitted + (sm.emitted or 0)
  acc.left = acc.left + (sm.left or 0)
  if (sm.left or 0) > 0 then
    for _, k in ipairs(sorted_keys(sm.causes or {})) do
      local c = k .. "=" .. tostring(sm.causes[k])
      acc.causes[c] = (acc.causes[c] or 0) + 1
    end
    for _, it in ipairs(sorted_keys(sm.missing or {})) do acc.missing[it] = math.max(acc.missing[it] or 0, sm.missing[it]) end
  end
  for _, o in ipairs(sm.orders or {}) do acc.orders[o] = (acc.orders[o] or 0) + 1 end
  return acc
end

local function join(t, fmt)
  local parts = {}
  for _, k in ipairs(sorted_keys(t)) do parts[#parts + 1] = string.format(fmt, k, t[k]) end
  return table.concat(parts, " ")
end

--- Ligne de la minute (nil : aucun PNJ libre de toute la minute, rien à dire).
function ZI.line(team, minute, acc)
  if not acc or acc.n == 0 or (acc.idle + acc.fond) == 0 then return nil end
  local why = acc.left == 0 and "aucune : chaque PNJ libre a recu un agrandissement" or join(acc.causes, "%s(x%d)")
  return string.format("[FO-ZERO-IDLE] %s minute %d | %d pensee(s) | PNJ libres %d sans tache + %d au fond (PNJ-pensees) | agrandissements emis %d {%s} | restes sans agrandissement %d | cause %s | manque {%s}",
    team, minute, acc.n, acc.idle, acc.fond, acc.emitted, join(acc.orders, "%s x%d"), acc.left, why ~= "" and why or "?",
    join(acc.missing, "%s %d"))
end

return ZI
