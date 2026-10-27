--[[
  Lot IA-G « le cerveau général » (demande du DC, 27/10, 7 h 10 : « un véritable cerveau, quelqu'un qui généralise, qui
  récupère l'arbre d'avancement, qui regarde ses ressources, ce qu'elles apportent »). PUR (aucune API Factorio).

  Il lit l'arbre d'avancement dans le CATALOGUE (shared/ai3/catalogue.lua, tiré des prototypes) et l'état de l'équipe
  (stock, technologies faites, machines posées, ressources connues), et il :
    1. CHOISIT son but de recherche (Gen.choose) : parmi les technologies prêtes (prérequis faits, actives), PAYABLES au
       sens du graphe (shared/ai3/graphe.lua : chaque pack se fabrique depuis des ressources CONNUES avec des machines
       qu'un exécutant sait poser ; règle H8), celle de plus grande VALEUR pour son COÛT :
         valeur (H9, « la recherche vaut ce qu'elle débloque ») = ce que débloquent ses recettes, par RÔLE de l'objet lu
           dans les prototypes (pack de laboratoire, objet attendu par un but, militaire, machine, logistique) et ses
           bonus (types d'effets), chaque terme pondéré par le poids de sa famille (chef d'IA2-a, traits d'IA2-0 :
           shared/ai3/buts.lua, B.weights) ; plus la part d'une CHAÎNE vers un pack que l'équipe ne sait pas encore
           faire (une technologie prête hérite de la valeur du pack qu'elle rapproche, divisée par la longueur de la
           chaîne, seulement si toute la chaîne est payable) ;
         coût = packs × leur coût de fabrication dans le graphe (point fixe min-plus : temps de recette, ingrédients,
           machines manquantes) + temps de laboratoire + le laboratoire s'il n'y en a pas ;
         inertie : la technologie en cours garde + 20 % (comme les projets) ;
    2. DÉPLIE le but (Gen.summary) en étapes du graphe (prendre, main, machine, extraire, explorer, rechercher,
       construire) et les range par EXÉCUTANT (Gen.dispatch) ;
    3. REGARDE SES RESSOURCES (Gen.key_resources) : le besoin BRUT de chaque ressource sur les buts de l'équipe (dépliage
       sans le stock consommable : ce que les buts mangent en tout) donne l'ordre des avant-postes, la ressource la plus
       demandée, le combustible et les ressources sans besoin (avant-poste seulement si son produit manque) ;
    4. explique chaque décision (Gen.why_text) : la chaîne des pourquoi.
  Le caractère pondère (poids des familles), il ne remplace jamais le calcul.

  Aucun nom du jeu ici (test anti-échelle, tests/iag_test.lua) : tout vient du catalogue et de l'état.
  Déterminisme : listes triées, entiers pour les scores, égalités départagées par le nom ; aucun hasard.
]]

local G = require("shared.ai3.graphe")

local Gen = {}

Gen.V_PACK = 100       -- débloque un pack de laboratoire que l'équipe ne sait pas encore faire (progression)
Gen.V_WANTED = 100     -- débloque un objet qu'un but attend et que l'équipe ne sait pas faire
Gen.V_MIL = 40         -- militaire (arme, munition, armure, capsule, tourelle, mur)
Gen.V_MACHINE = 30     -- machine (fabrique, foreuse, laboratoire, énergie)
Gen.V_LOG = 10         -- logistique (tapis, bras, poteau, coffre)
Gen.V_OTHER = 5
Gen.V_BONUS = { militaire = 25, capital = 10 }
Gen.FAMILY = { pack = "recherche", wanted = "capital", militaire = "armee", machine = "capital", logistique = "capital",
  autre = "capital" }
Gen.CHAIN = 100        -- valeur d'une chaîne vers un pack, partagée entre ses technologies manquantes
Gen.COST_FLOOR = 10
Gen.LAB_W = 0.5        -- une seconde de laboratoire coûte une demi-seconde de travail (c'est du temps, pas des bras)
Gen.INERTIA_PCT = 20
Gen.TOP = 3            -- candidates gardées pour le journal
Gen.LATER_DIV = 4      -- un objet débloqué que l'équipe ne saura PAS fabriquer ensuite (ingrédient sans source, machine
                       -- sans exécutant) ne vaut qu'un quart : il ne sert pas tout de suite (« ce qui sert », H9)

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function wf(w, fam) return ((w or {})[fam] or 1000) / 1000 end

--- Évaluation (points fixes) de l'état ; `memo` = { key, ev } facultatif (fonction pure de la clé : même résultat chez
--- tous les pairs, revue B1).
function Gen.prepare(cat, state, memo)
  local key = G.state_key(cat.g, state)
  if memo and memo.key == key and memo.ev then return memo.ev, key, true end
  local ev = G.prepare(cat.g, state)
  if memo then memo.key, memo.ev = key, ev end
  return ev, key, false
end

--- Technologies PRÊTES : pas faites, prérequis faits, actives (disabled = { [techno] = vrai }).
function Gen.ready(cat, state, disabled)
  local out = {}
  for _, t in ipairs(cat.tech_list) do
    if not state.techs[t] and not (disabled and disabled[t]) then
      local ok = true
      for _, p in ipairs(cat.techs[t].prerequisites) do if not state.techs[p] then ok = false break end end
      if ok then out[#out + 1] = t end
    end
  end
  return out
end

--- La recette est-elle DÉJÀ ouverte (une technologie faite la débloque, ou aucune ne la verrouille) ?
local function already_open(cat, state, r)
  local t = cat.g.unlocked_by[r]
  if t == nil then return cat.g.recipes[r] ~= nil end
  return state.techs[t] == true
end

--- Valeur propre d'une technologie (sans chaîne) : v, raisons { {rôle, objet} }, palier (ouvre un pack que l'équipe
--- saura fabriquer). `ev` = évaluation de l'état (Gen.prepare) : un objet qui ne sera pas fabricable, ou une machine
--- qu'aucun exécutant ne sait poser, vaut Gen.LATER_DIV fois moins.
function Gen.value(cat, ev, state, t, ctx)
  local spec = cat.techs[t]
  local w = ctx and ctx.weights
  local wanted = ctx and ctx.wanted or {}
  local v, why, palier = 0, {}, false
  local seen = {}
  for _, r in ipairs(spec.unlocks) do
    if not already_open(cat, state, r) then
      for _, p in ipairs(cat.products[r] or {}) do
        if not seen[p] then
          seen[p] = true
          local role = cat.role[p]
          local later = not ev.feas[p] or (role == "machine" and not cat.g.machine[p])
          local k
          local v0 = v
          if wanted[p] then
            k = "wanted"
            v = v + math.floor(Gen.V_WANTED * wf(w, Gen.FAMILY.wanted))
          elseif role == "pack" then
            k = "pack"
            if not later then palier = true end
            v = v + math.floor(Gen.V_PACK * wf(w, Gen.FAMILY.pack))
          elseif role == "militaire" then
            k = role
            v = v + math.floor(Gen.V_MIL * wf(w, Gen.FAMILY.militaire))
          elseif role == "machine" then
            k = role
            v = v + math.floor(Gen.V_MACHINE * wf(w, Gen.FAMILY.machine))
          elseif role == "logistique" then
            k = role
            v = v + math.floor(Gen.V_LOG * wf(w, Gen.FAMILY.logistique))
          else
            k = "autre"
            v = v + math.floor(Gen.V_OTHER * wf(w, Gen.FAMILY.autre))
          end
          if later then
            v = v0 + math.floor((v - v0) / Gen.LATER_DIV)
            k = k .. ", plus tard"
          end
          why[#why + 1] = { k, p }
        end
      end
    end
  end
  for _, fam in ipairs(sorted_keys(spec.bonus)) do
    local base = Gen.V_BONUS[fam] or 0
    local family = fam == "militaire" and "armee" or "capital"
    v = v + math.floor(base * wf(w, family))
    why[#why + 1] = { "bonus", fam }
  end
  return v, why, palier
end

--- Chaînes : chaque technologie NON prête qui ouvre un pack (ou un objet attendu) et dont toute la chaîne est payable
--- donne à ses prérequis manquants une part de sa valeur. Rend { [techno] = { v, target, len } }.
function Gen.chains(cat, ev, state, ctx)
  local out = {}
  local w = ctx and ctx.weights
  for _, u in ipairs(cat.tech_list) do
    if not state.techs[u] and ev.tfeas[u] then
      local v, _, palier = Gen.value(cat, ev, state, u, { weights = w, wanted = ctx and ctx.wanted })
      local wanted_hit = false
      for _, r in ipairs(cat.techs[u].unlocks) do
        for _, p in ipairs(cat.products[r] or {}) do
          if ctx and ctx.wanted and ctx.wanted[p] and ev.feas[p] then wanted_hit = true end
        end
      end
      if palier or wanted_hit then
        local list, seen = {}, {}
        local function walk(n)
          if seen[n] or state.techs[n] then return end
          seen[n] = true
          local s = cat.techs[n]
          if not s then return end
          for _, pre in ipairs(s.prerequisites) do walk(pre) end
          list[#list + 1] = n
        end
        walk(u)
        if #list > 1 then
          local share = math.floor(Gen.CHAIN * wf(w, "recherche") / #list)
          for _, n in ipairs(list) do
            if n ~= u and (not out[n] or share > out[n].v) then out[n] = { v = share, target = u, len = #list } end
          end
        end
      end
    end
  end
  return out
end

--- Coût d'une technologie (unités de travail du graphe) : packs + temps de laboratoire + un laboratoire s'il n'y en a
--- aucun de posé.
function Gen.cost(cat, ev, state, t, lab_speed)
  local spec = cat.techs[t]
  local c = 0
  for _, ing in ipairs(spec.ingredients) do
    c = c + (ev.cost[ing[1]] or G.HUGE) * ing[2] * spec.count
  end
  c = c + spec.count * spec.time * Gen.LAB_W / math.max(0.1, lab_speed or 1)
  local has_lab, lab_cost = false, G.HUGE
  for _, l in ipairs(cat.labs) do
    if (state.built[l.item] or 0) > 0 or (state.stock and (state.stock[l.item] or 0) > 0) then has_lab = true end
    local fits = true
    for _, ing in ipairs(spec.ingredients) do if not l.inputs[ing[1]] then fits = false end end
    if fits and ev.cost[l.item] and ev.cost[l.item] < lab_cost then lab_cost = ev.cost[l.item] end
  end
  if not has_lab and lab_cost < G.HUGE then c = c + lab_cost end
  return math.floor(c + 0.5)
end

--- Le choix. ctx = { weights, wanted = { [objet] = vrai }, current = techno en cours, disabled = { [techno] = vrai },
--- lab_speed }. Rend une décision { tech, value, cost, score, palier, why, chain, ranked, blocked } ou nil (et la
--- décision porte alors `blocked` : technologies de valeur impayables et leurs causes).
function Gen.choose(cat, ev, state, ctx)
  ctx = ctx or {}
  local chains = Gen.chains(cat, ev, state, ctx)
  local cands, blocked = {}, {}
  for _, t in ipairs(Gen.ready(cat, state, ctx.disabled)) do
    local v, why, palier = Gen.value(cat, ev, state, t, ctx)
    local ch = chains[t]
    if ch then
      v = v + ch.v
      palier = true
    end
    if ev.tfeas[t] then
      if v > 0 then
        local cost = Gen.cost(cat, ev, state, t, ctx.lab_speed)
        local score = math.floor(v * 1000 / (cost + Gen.COST_FLOOR))
        if t == ctx.current then score = math.floor(score * (100 + Gen.INERTIA_PCT) / 100) end
        cands[#cands + 1] = { tech = t, value = v, cost = cost, score = score, palier = palier, why = why, chain = ch }
      end
    elseif v > 0 then
      blocked[#blocked + 1] = { tech = t, value = v }
    end
  end
  table.sort(cands, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.tech < b.tech
  end)
  table.sort(blocked, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.tech < b.tech
  end)
  local d = cands[1] or { tech = nil }
  d.ranked = {}
  for i = 1, math.min(Gen.TOP, #cands) do d.ranked[i] = { cands[i].tech, cands[i].score } end
  d.n_ready = #cands
  d.blocked = blocked
  return d
end

--- Dépliage d'une liste de buts ({ {tech = …} | {item = …, n = …} }) : résumé par sorte d'étape.
function Gen.summary(cat, ev, state, goals)
  local res = G.unfold(cat.g, goals, state, ev)
  local s = { hand = {}, produce = {}, extract = {}, build = {}, take = {}, explore = {}, research = {}, line = {},
    supply = {}, steps = #res.steps, nodes = res.nodes, payable = res.payable, truncated = res.truncated, causes = {} }
  for _, st in ipairs(res.steps) do
    local k = st.kind
    if k == "hand" or k == "produce" then
      local r = cat.g.recipes[st.name]
      local amount = 1
      for _, p in ipairs(r.products) do if p.name == st.item then amount = p.amount end end
      s[k][st.item] = (s[k][st.item] or 0) + st.n * amount
    elseif k == "extract" or k == "take" then
      s[k][st.name] = (s[k][st.name] or 0) + (st.n or 0)
    elseif k == "build" then
      s.build[st.name] = (s.build[st.name] or 0) + 1
    elseif k == "explore" or k == "research" or k == "line" or k == "supply" then
      s[k][#s[k] + 1] = st.name
    end
  end
  local causes = {}
  for _, b in ipairs(res.blocked) do for _, c in ipairs(b.causes or {}) do causes[c] = true end end
  s.causes = sorted_keys(causes)
  return s
end

--- BRAS LIBRES (demande du DC « ils ne scalent pas » ; intégrateur, 27/10 : à 30 PNJ, 53 à 64 % d'inactifs sous IA-V2,
--- « le cerveau ne crée du travail que pour ce qui manque ») : combien de buts SUIVANTS déplier d'avance. Un joueur qui
--- a des bras libres prépare la recherche d'après et agrandit ce que ses buts mangeront. Profondeur = 0 tant que les
--- PNJ sans tâche sont moins de Gen.IDLE_MIN ou moins de Gen.IDLE_PCT % de l'effectif (rien ne change à 8 PNJ occupés),
--- puis 1 par Gen.IDLE_PER PNJ sans tâche, au plus Gen.AHEAD_MAX.
Gen.IDLE_MIN = 2
Gen.IDLE_PCT = 25
Gen.IDLE_PER = 3
Gen.AHEAD_MAX = 3
function Gen.ahead_depth(idle, workers)
  idle, workers = idle or 0, workers or 0
  if idle < Gen.IDLE_MIN or idle * 100 < Gen.IDLE_PCT * math.max(1, workers) then return 0 end
  return math.min(Gen.AHEAD_MAX, math.max(1, math.floor(idle / Gen.IDLE_PER)))
end

--- Bras libres DURABLES (moteur réel, banc g5, graine 271828182 : à la PREMIÈRE pensée, les 8 PNJ sont sans tâche
--- faute de tâches encore distribuées ; la règle partait à 0,0 min, fabriquait les packs de deux recherches et une
--- capacité de fer de plus avec le fer du départ : Ambre à 10 soldats à 30 min contre 38 sans elle, fer à 5 plaques,
--- palier 2 jamais). La profondeur ne vaut que si des PNJ sont sans tâche depuis Gen.IDLE_THINKS pensées de suite
--- (1 min), et jamais avant Gen.SPARE_START ticks de partie (le départ a toujours du travail qui arrive).
Gen.IDLE_THINKS = 12
Gen.SPARE_START = 5 * 3600
function Gen.spare_depth(run, idle, workers, elapsed)
  if (elapsed or 0) < Gen.SPARE_START or (run or 0) < Gen.IDLE_THINKS then return 0 end
  return Gen.ahead_depth(idle, workers)
end

--- Packs des `depth` technologies SUIVANTES (liste `next`, dans l'ordre du choix), encore à faire et payables : ce que la
--- faction fabrique d'avance avec ses bras libres (jamais pour une technologie impayable : H8). Rend { {pack, n} } trié.
function Gen.lookahead(cat, ev, state, next, depth)
  local packs = {}
  local used = 0
  for _, t in ipairs(next or {}) do
    if used >= (depth or 0) then break end
    local spec = cat.techs[t]
    if spec and not state.techs[t] and ev.tfeas[t] then
      used = used + 1
      for _, ing in ipairs(spec.ingredients) do packs[ing[1]] = (packs[ing[1]] or 0) + ing[2] * spec.count end
    end
  end
  local out = {}
  for _, p in ipairs(sorted_keys(packs)) do out[#out + 1] = { p, packs[p] } end
  return out
end

--- Étapes rangées par EXÉCUTANT (le travail que l'équipe sait faire aujourd'hui) :
---   main      -> tâches « craft » du tableau (script/team/board.lua) : objets fabriqués à la main ;
---   machine   -> fonderie du QG et machines posées : objets produits par une machine ;
---   extraire  -> minage à la main et avant-postes : ressources ;
---   construire-> pose d'une machine (laboratoire du QG, fours, foreuses ; plan directeur d'IA1-d pour le reste) ;
---   explorer  -> éclaireurs d'IA3-f ;
---   rechercher-> laboratoire du QG.
function Gen.dispatch(sum)
  return { main = sum.hand, machine = sum.produce, extraire = sum.extract, construire = sum.build,
    explorer = sum.explore, rechercher = sum.research, prendre = sum.take, causes = sum.causes }
end

--- CE QUE RAPPORTERAIT chaque ressource INCONNUE qu'un exécutant saurait extraire (« quelles ressources peuvent
--- rapporter ») : on la suppose connue, on refait les points fixes, et sa valeur = la valeur propre (Gen.value) des
--- technologies qui deviennent payables, plus celle des objets de rôle connu qui deviennent fabricables (pack 100,
--- militaire 40, machine 30, logistique 10, pondérés comme Gen.value). Rend une liste triée { {ressource, valeur,
--- technologies débloquées} } (valeur décroissante, puis le nom). Coût : un point fixe par ressource inconnue
--- extractible (2 à 3 ms hors jeu chacun) : appelé seulement aux décisions.
function Gen.resource_values(cat, ev, state, ctx)
  ctx = ctx or {}
  local w = ctx.weights
  local out = {}
  local base_role = { pack = Gen.V_PACK, militaire = Gen.V_MIL, machine = Gen.V_MACHINE, logistique = Gen.V_LOG }
  for _, res in ipairs(cat.resource_list) do
    local r = cat.resources[res]
    if not state.known[res] and r and cat.g.by_rescat[r.category] then
      local known = {}
      for _, k in ipairs(sorted_keys(state.known)) do known[k] = state.known[k] end
      known[res] = true
      local s2 = { stock = state.stock, techs = state.techs, built = state.built, known = known }
      local ev2 = G.prepare(cat.g, s2)
      local v, techs = 0, {}
      for _, t in ipairs(cat.tech_list) do
        if not state.techs[t] and ev2.tfeas[t] and not ev.tfeas[t] then
          local tv = Gen.value(cat, ev2, s2, t, ctx)
          if tv > 0 then
            v = v + tv
            techs[#techs + 1] = t
          end
        end
      end
      for _, item in ipairs(sorted_keys(cat.role)) do
        if ev2.feas[item] and not ev.feas[item] then
          local role = cat.role[item]
          v = v + math.floor((base_role[role] or 0) * wf(w, Gen.FAMILY[role] or "capital"))
        end
      end
      out[#out + 1] = { res, v, techs }
    end
  end
  table.sort(out, function(a, b)
    if a[2] ~= b[2] then return a[2] > b[2] end
    return a[1] < b[1]
  end)
  return out
end

--- Ressources CLÉS de l'équipe, déduites du besoin BRUT de ses buts (résumé d'un dépliage SANS le stock consommable).
--- kind_of(ressource) -> type d'avant-poste (table de l'exécutant, shared/team/config.lua) ou nil ; kinds = types
--- d'avant-poste dans leur ordre. Rend { top, fuel, order = {types, besoin décroissant, combustible exclu},
--- optional = { [type] = vrai } (sans besoin), need = { [type] = n } }.
function Gen.key_resources(cat, sum, kinds, kind_of)
  local need = {}
  for _, k in ipairs(kinds) do need[k] = 0 end
  for _, res in ipairs(sorted_keys(sum.extract)) do
    local k = kind_of(res)
    if k then need[k] = (need[k] or 0) + sum.extract[res] end
  end
  -- Combustible : le meilleur candidat du catalogue qu'un avant-poste de l'exécutant sait rapporter.
  local fuel = nil
  for _, res in ipairs(cat.fuels or { cat.fuel }) do
    local k = kind_of(res)
    if k then fuel = k break end
  end
  local order = {}
  for _, k in ipairs(kinds) do if k ~= fuel then order[#order + 1] = k end end
  table.sort(order, function(a, b)
    if need[a] ~= need[b] then return need[a] > need[b] end
    return a < b
  end)
  local optional = {}
  for _, k in ipairs(order) do if (need[k] or 0) <= 0 and k ~= order[1] then optional[k] = true end end
  return { top = order[1], fuel = fuel, order = order, optional = optional, need = need }
end

local function fmt_map(m, max)
  local parts = {}
  for _, k in ipairs(sorted_keys(m)) do
    local v = m[k]
    parts[#parts + 1] = k .. " " .. (type(v) == "number" and tostring(math.floor(v + 0.5)) or tostring(v))
    if max and #parts >= max then parts[#parts + 1] = "..." break end
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end
Gen.fmt_map = fmt_map

--- La chaîne des pourquoi d'une décision (texte de journal, ASCII).
function Gen.why_text(d, sum)
  if not d or not d.tech then
    local b = {}
    for i = 1, math.min(3, #((d and d.blocked) or {})) do b[#b + 1] = d.blocked[i].tech end
    return "aucune technologie payable ; de valeur mais impayables : " .. table.concat(b, ", ")
  end
  local parts = {}
  for _, w in ipairs(d.why or {}) do parts[#parts + 1] = w[2] .. " (" .. w[1] .. ")" end
  local txt = "debloque [" .. table.concat(parts, ", ") .. "]"
  if d.chain then txt = txt .. " ; rapproche '" .. d.chain.target .. "' (chaine de " .. d.chain.len .. ", +" .. d.chain.v .. ")" end
  local r = {}
  for i = 2, #(d.ranked or {}) do r[#r + 1] = d.ranked[i][1] .. " " .. d.ranked[i][2] end
  if #r > 0 then txt = txt .. " ; suivantes : " .. table.concat(r, ", ") end
  if sum then
    txt = txt .. string.format(" | depliage %d etapes : main %s machine %s extraire %s construire %s explorer [%s]",
      sum.steps, fmt_map(sum.hand, 6), fmt_map(sum.produce, 6), fmt_map(sum.extract), fmt_map(sum.build),
      table.concat(sum.explore, " "))
  end
  return txt
end

return Gen
