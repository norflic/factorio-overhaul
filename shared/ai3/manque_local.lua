--[[
  Lot VIDEO-L3 « MANQUE MESURÉ AU CONSOMMATEUR, TRANSIT COMPRIS » (feuille de route validée par le DC le 7/11 :
  docs/VIDEO_AUTOMATISATION.md §6 L3, docs/TODO_VIDEO.md §G rang 3, D0 et D1 ; lignes V14, V26, V28, V29, V59, V81, V82, V83,
  G25). Règle PURE, testée hors jeu (tests/manque_local_test.lua). BRANCHÉE : Mq.sinks dans script/ai3/capitalisation.lua (:1259) et Mq.step dans
  script/team/manque_vue.lua (:163) ; Mv.ENABLED = true (manque_vue.lua:34), Col.MQ = true (script/team/collecte.lua:84).

  La vidéo : « any item with a negative signal is in demand » ; chaque module « report[s] any ingredients that are missing » ;
  « product that is in transit is accounted for as well » ; le réseau additionne TOUS les coffres fournisseurs.
  Chez nous (docs/IA_WORKFLOW.md §2 et §5) : la vue ne voit pas les coffres de sortie du plan directeur (D0) ; le fer attend au champ
  pendant que la recrue en manque (D1).

  Règles :
    1. MANQUE PUBLIÉ par module qui TOURNE : pour chaque entrée, max(0, Mq.H_NEED min de débit nominal − ce qu'il a en entrée − ce
       qui est EN ROUTE vers lui). Jamais négatif ; l'excès livré à un module ne couvre pas le voisin (il va à ce module).
    2. TRANSIT dédoublonné PAR TÂCHE : une tâche réservée pour un module et l'inventaire du PNJ qui la porte sont la même matière ;
       on garde le plus grand des deux, jamais leur somme. Une entrée de transit sans tâche est refusée (rien ne permet de la
       dédoublonner).
    3. COURANT : un module à l'arrêt faute de courant n'a pas de manque d'entrée ; il est écrit à part (no_power).
    4. Demandes hors module (recrue, manque du cerveau) : `wants`, chacune avec sa priorité. Une demande NETTE (`net = true` : le
       manque de l'objectif, que le planificateur a déjà calculé contre le stock libre) ne puise pas au stock une seconde fois ; elle
       passe directement aux sorties, puis à la construction.
    5. COUVERTURE d'un manque, par priorité décroissante (puis clé), dans cet ordre :
         a. le STOCK libre ;
         b. les SORTIES dont la collecte est PRISE par un PNJ (en route vers le QG) : disponibles ;
         c. les SORTIES collectables sans collecte prise (tâche ouverte non servie, ou aucune tâche), la plus proche d'abord : elles
            ne sont PAS disponibles (piège du lot FLUX : compter des plaques dormantes comme disponibles sans tournée qui les ramène
            a fait chuter Écarlate de 30 686 à 14 074 plaques) ; elles deviennent une COLLECTE à émettre ou à relever, qui hérite
            de la plus haute priorité des manques qu'elle couvre (D1), et elles RETIENNENT la construction ;
         d. le reste est un manque à CONSTRUIRE (build).
    6. RETENUE BORNÉE : une sortie qui retient la construction sans que sa collecte soit prise depuis Mq.COLLECT_WAIT ne la retient
       plus (la construction reprend) ; sa collecte reste demandée (expired = vrai). Horloge remise à zéro quand la collecte est
       prise, quand la sortie ne sert plus, ou quand elle disparaît.
    7. LECTURES : un module ou une sortie lus il y a plus de Mq.MAX_AGE ne comptent pas (stale) ; tourniquet de lecture
       Mq.slice (Mq.READ ids par pensée, curseur = dernier id lu : stable quand des modules s'ajoutent ou partent).
    8. FERMÉ PAR DÉFAUT (lot L13, même règle que Pf.input de shared/ai3/plafonds.lua, recopiée ici pour le coût) : un module dont l'état du courant, les entrées lues ou l'heure de
       lecture manquent ne publie rien (refused) ; un débit nominal absent ou invalide ne publie rien pour cette entrée ; une
       sortie dont la sûreté n'est pas connue (ok ~= vrai) ne retient pas la construction et n'est pas collectée.
    9. LABORATOIRES (lot VIDEO-COUVERTURE 3, V59) : un module qui consomme la RECHERCHE EN COURS (m.consumes = Mq.RESEARCH) publie le manque de
       packs comme un module de recette : débit d'un ingrédient = quantité par unité × vitesse de recherche totale × 60 ÷ durée de l'unité,
       par minute (Mq.module). Sans technologie en file (tech = false) : rien à consommer, aucun manque ; technologie non lue, vitesse ou
       durée invalide : refusé (règle 8). Les packs du module, de ses quais et en route, comptent comme une entrée ordinaire.
   10. MUNITIONS (V10, C3.4) : les chargeurs qui manquent aux tourelles sont une demande hors module (Mq.ammo_want) : somme des manques des groupes
       dont la recharge est due et que nulle tournée n'a déjà prise, à la priorité de l'armée. Avant, la famille « armée » les gardait à parts
       réservées, hors des puits, et aucun manque mesuré ne les voyait.
  Sorties : need, by_module (le manque de CHAQUE module : { [id] = { [objet] = n } }, avant le stock : need en est la somme), dispo_stock, dispo_sorties, dort, out_all, net (= dispo_stock + dispo_sorties − need, signé : négatif = manque,
  comme le signal de la vidéo), build, short_by (part non couverte de chaque besoin : clé « m:<module> » ou « w:<demande> »),
  collect, starved, no_power, stale, refused, items.
  Déterminisme : objets, ids, clés et sources parcourus triés ; aucun hasard ; aucune horloge mesurée ; l'état `st` ne garde que
  des nombres, des chaînes et des tables. Aucun nom du jeu ici (test anti-échelle, tests/iag_test.lua §8).
]]

local Mq = {}

Mq.H_NEED = 1               -- minutes de débit nominal publiées comme manque d'un module
Mq.MAX_AGE = 2 * 3600       -- ticks : une lecture plus vieille ne compte pas
Mq.READ = 32                -- modules lus par pensée (tourniquet)
Mq.COLLECT_WAIT = 10 * 3600 -- ticks : une sortie non collectée retient la construction au plus 10 min
Mq.EPS = 1e-9
Mq.RESEARCH = "research"  -- m.consumes d'un module qui consomme la recherche en cours (lot VIDEO-COUVERTURE 3, V59) ; voir Mq.module

---------------------------------------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------------------------------------
local function id_before(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then return ta == "number" end
  return a < b
end

local function valid_id(id)
  return (type(id) == "number" and id == id and id ~= math.huge and id ~= -math.huge) or (type(id) == "string" and id ~= "")
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

--- Nombre fini ≥ 0, ou nil (Pf.input sans le texte du refus : appelé à chaque lecture).
local function num(v)
  if type(v) == "number" and v == v and v >= 0 and v ~= math.huge then return v end
  return nil
end

local function add(t, k, v) t[k] = (t[k] or 0) + v end

---------------------------------------------------------------------------------------------------
-- État et tourniquet
---------------------------------------------------------------------------------------------------
function Mq.new() return { cursor = nil, wait = {} } end

--- Tourniquet (règle 7). ids = liste d'ids (n'importe quel ordre) ; rend les au plus n ids à relire cette pensée, triés à partir
--- du premier id strictement après st.cursor (en boucle), et avance st.cursor au dernier rendu.
function Mq.slice(st, ids, n)
  local list = {}
  for _, id in ipairs(ids or {}) do if valid_id(id) then list[#list + 1] = id end end
  table.sort(list, id_before)
  n = math.max(0, math.floor((num(n) or Mq.READ) + Mq.EPS))
  if #list == 0 or n == 0 then return {} end
  local start = 1
  if st.cursor ~= nil then
    start = #list + 1
    for i, id in ipairs(list) do
      if id_before(st.cursor, id) then start = i break end
    end
    if start > #list then start = 1 end
  end
  local out = {}
  for k = 0, math.min(n, #list) - 1 do out[#out + 1] = list[((start - 1 + k) % #list) + 1] end
  st.cursor = out[#out]
  return out
end

---------------------------------------------------------------------------------------------------
-- Calcul
---------------------------------------------------------------------------------------------------
local function fresh(read_tick, tick)
  return type(read_tick) == "number" and tick - read_tick <= Mq.MAX_AGE
end

--- Transit par module et par objet, dédoublonné par tâche (règle 2).
local function transit_of(list, res)
  local per = {} -- [module][objet][tâche] = plus grand n
  for _, e in ipairs(list or {}) do
    local n = type(e) == "table" and num(e.n) or nil
    if type(e) ~= "table" or not valid_id(e.task) or not valid_id(e.module) or type(e.item) ~= "string" or n == nil then
      res.refused[#res.refused + 1] = { id = "transit:" .. tostring(type(e) == "table" and e.module or "?"),
        why = "transit sans tache, module, objet ou quantite" }
    else
      per[e.module] = per[e.module] or {}
      per[e.module][e.item] = per[e.module][e.item] or {}
      local cur = per[e.module][e.item][e.task]
      if cur == nil or n > cur then per[e.module][e.item][e.task] = n end
    end
  end
  local tr = {}
  for _, m in ipairs(sorted_keys(per)) do
    tr[m] = {}
    for _, it in ipairs(sorted_keys(per[m])) do
      local s = 0
      for _, k in ipairs(sorted_keys(per[m][it])) do s = s + per[m][it][k] end
      tr[m][it] = s
    end
  end
  return tr
end

--- Lot VIDEO-COUVERTURE 3 (V59) : un module de laboratoires (m.consumes = Mq.RESEARCH) consomme les ingrédients de la recherche en cours, pas ceux d'une recette.
--- m = { consumes = Mq.RESEARCH, id, power, have, read_tick, prio, speed, tech }, où `speed` = vitesse de recherche TOTALE des laboratoires du
--- module (somme des vitesses, bonus de force compris), `tech` = false (aucune technologie en file : rien à consommer) ou
--- { unit_time = secondes d'une unité, ingredients = { { item, n } } (n par unité) }. Débit d'un ingrédient (par minute) :
--- n × speed × 60 ÷ unit_time. Un module d'un autre type est rendu tel quel. Rend le module normalisé (`inputs` posé), ou nil et la raison
--- (garde fermée, règle 8 : une technologie non lue, une vitesse ou une durée invalides ne publient rien).
function Mq.module(m)
  if type(m) ~= "table" or m.consumes ~= Mq.RESEARCH then return m end
  local out = {}
  for _, k in ipairs(sorted_keys(m)) do out[k] = m[k] end
  if m.tech == false then
    out.inputs = {}
    return out
  end
  local t = m.tech
  if type(t) ~= "table" then return nil, "technologie non lue" end
  local speed, ut = num(m.speed), num(t.unit_time)
  if not speed or speed <= 0 or not ut or ut <= 0 or type(t.ingredients) ~= "table" then
    return nil, "vitesse, duree d'unite ou ingredients de la technologie invalides"
  end
  local per = {}
  for _, ing in ipairs(t.ingredients) do
    local n = type(ing) == "table" and num(ing.n) or nil
    if type(ing) ~= "table" or type(ing.item) ~= "string" or n == nil then return nil, "ingredient de technologie invalide" end
    add(per, ing.item, n * speed * 60 / ut)
  end
  out.inputs = {}
  for _, it in ipairs(sorted_keys(per)) do out.inputs[#out.inputs + 1] = { item = it, rate = per[it] } end
  return out
end

--- Lot VIDEO-COUVERTURE 3 (V10, C3.4) : les munitions manquantes des tourelles, demande hors module de Mq.step. groups = { { key, due,
--- missing, has_task } } (due : la recharge est due, missing : chargeurs qui manquent à la cible, has_task : une tournée de recharge est déjà
--- au tableau et porte ce qu'il faut) ; o = { item, prio } (la munition portée aux tourelles, la priorité de l'armée). Rend { key = « but:<objet> »,
--- item, n, prio }, ou nil quand rien ne manque. Les munitions entraient en famille « armée » à parts réservées, hors des puits.
function Mq.ammo_want(groups, o)
  if type(o) ~= "table" or type(o.item) ~= "string" or o.item == "" or num(o.prio) == nil then return nil end
  local n = 0
  for _, g in ipairs(groups or {}) do
    local miss = type(g) == "table" and num(g.missing) or nil
    if miss and g.due == true and not g.has_task then n = n + miss end
  end
  if n <= Mq.EPS then return nil end
  return { key = "but:" .. o.item, item = o.item, n = n, prio = o.prio }
end

--- Manques des modules (règles 1, 3, 7, 8) : rend { [objet] = liste de besoins { key, n, prio } }.
local function module_needs(mods, tr, tick, res)
  local needs = {}
  local list = {}
  for _, m0 in ipairs(mods or {}) do
    local m, why = Mq.module(m0)
    if m == nil then res.refused[#res.refused + 1] = { id = type(m0) == "table" and m0.id or "?", why = why }
    elseif type(m) == "table" and valid_id(m.id) then list[#list + 1] = m
    else res.refused[#res.refused + 1] = { id = "?", why = "module sans id" } end
  end
  table.sort(list, function(a, b) return id_before(a.id, b.id) end)
  for _, m in ipairs(list) do
    if type(m.power) ~= "boolean" then
      res.refused[#res.refused + 1] = { id = m.id, why = "courant inconnu" }
    elseif type(m.have) ~= "table" or type(m.inputs) ~= "table" then
      res.refused[#res.refused + 1] = { id = m.id, why = "entrees non lues" }
    elseif not fresh(m.read_tick, tick) then
      res.stale[#res.stale + 1] = m.id
    elseif m.power == false then
      res.no_power[#res.no_power + 1] = m.id
    else
      local prio = (type(m.prio) == "number" and m.prio == m.prio) and m.prio or 0
      local mkey = "m:" .. tostring(m.id)
      local mt = tr[m.id] or {}
      local hungry = {}
      local ins = {}
      for _, x in ipairs(m.inputs) do if type(x) == "table" and type(x.item) == "string" then ins[#ins + 1] = x end end
      table.sort(ins, function(a, b) return a.item < b.item end)
      for _, x in ipairs(ins) do
        local rate = num(x.rate)
        if rate == nil then
          res.refused[#res.refused + 1] = { id = m.id, why = "debit nominal absent : " .. x.item }
        else
          local have = num(m.have[x.item]) or 0 -- une entrée lue et vide vaut 0 (la table est lue : règle 8)
          local way = mt[x.item] or 0
          local need = rate * Mq.H_NEED - have - way
          if need > Mq.EPS then
            needs[x.item] = needs[x.item] or {}
            needs[x.item][#needs[x.item] + 1] = { key = mkey, n = need, prio = prio }
            res.by_module[m.id] = res.by_module[m.id] or {}
            res.by_module[m.id][x.item] = need
            if have <= Mq.EPS and way <= Mq.EPS then hungry[#hungry + 1] = x.item end
          end
        end
      end
      if #hungry > 0 then res.starved[#res.starved + 1] = { id = m.id, items = hungry, consumes = m.consumes } end
    end
  end
  return needs
end

--- Sources (sorties du plan directeur) lisibles, triées par distance puis id.
local function sources_of(sources, tick, res)
  local list = {}
  for _, s in ipairs(sources or {}) do
    if type(s) ~= "table" or not valid_id(s.id) or type(s.items) ~= "table" then
      res.refused[#res.refused + 1] = { id = type(s) == "table" and s.id or "?", why = "sortie sans id ou sans contenu lu" }
    elseif not fresh(s.read_tick, tick) then
      res.stale[#res.stale + 1] = s.id
    else
      list[#list + 1] = { s = s, d = num(s.d) or math.huge }
    end
  end
  table.sort(list, function(a, b)
    if a.d ~= b.d then return a.d < b.d end
    return id_before(a.s.id, b.s.id)
  end)
  local out = {}
  for i, e in ipairs(list) do out[i] = e.s end
  return out
end

--- Un pas. input = { mods, wants, transit, sources, stock } (voir l'en-tête) ; st = Mq.new() (gardé d'une pensée à l'autre).
--- Rend res, ou nil et la raison si l'état ou le tick manque.
function Mq.step(st, input, tick)
  if type(st) ~= "table" then return nil, "etat absent" end
  if type(tick) ~= "number" or tick ~= tick then return nil, "tick absent" end
  st.wait = st.wait or {}
  input = input or {}
  local res = { need = {}, dispo_stock = {}, dispo_sorties = {}, dort = {}, out_all = {}, net = {}, build = {}, collect = {},
    short_by = {}, starved = {}, no_power = {}, stale = {}, refused = {}, items = {}, by_module = {} }
  local tr = transit_of(input.transit, res)
  local needs = module_needs(input.mods, tr, tick, res)
  -- Demandes hors module (règle 4).
  local wl = {}
  for _, w in ipairs(input.wants or {}) do
    local n = type(w) == "table" and num(w.n) or nil
    if type(w) == "table" and valid_id(w.key) and type(w.item) == "string" and n and n > Mq.EPS then wl[#wl + 1] = w
    else res.refused[#res.refused + 1] = { id = type(w) == "table" and w.key or "?", why = "demande sans cle, objet ou quantite" } end
  end
  table.sort(wl, function(a, b) return id_before(a.key, b.key) end)
  for _, w in ipairs(wl) do
    needs[w.item] = needs[w.item] or {}
    needs[w.item][#needs[w.item] + 1] = { key = "w:" .. tostring(w.key), n = w.n,
      prio = (type(w.prio) == "number" and w.prio == w.prio) and w.prio or 0, net = w.net == true or nil }
  end
  -- Stock libre : seulement les quantités valides.
  local stock = {}
  if type(input.stock) == "table" then
    for _, k in ipairs(sorted_keys(input.stock)) do
      local v = num(input.stock[k])
      if v then stock[k] = v end
    end
  else
    res.refused[#res.refused + 1] = { id = "stock", why = "stock absent" }
  end
  local srcs = sources_of(input.sources, tick, res)
  -- Ensemble des objets ; sorties indexées par objet (dans l'ordre trié des sorties).
  local items, seen = {}, {}
  local by_item = {}
  local function note(it) if not seen[it] then seen[it] = true items[#items + 1] = it end end
  for _, it in ipairs(sorted_keys(needs)) do note(it) end
  for _, it in ipairs(sorted_keys(stock)) do note(it) end
  for _, s in ipairs(srcs) do
    for _, it in ipairs(sorted_keys(s.items)) do
      local n = num(s.items[it])
      if n and n > 0 then
        note(it)
        local l = by_item[it] or {}
        l[#l + 1] = { s = s, n = n }
        by_item[it] = l
      end
    end
  end
  table.sort(items)
  res.items = items
  -- Couverture (règle 5), objet par objet.
  local used = {} -- [id de sortie] = vrai : sert à une collecte ce pas-ci (horloge de la règle 6)
  local actions = {} -- [id de sortie .. "|" .. objet] = action
  local order = {}
  for _, it in ipairs(items) do
    local nl = needs[it] or {}
    table.sort(nl, function(a, b)
      if a.prio ~= b.prio then return a.prio > b.prio end
      return a.key < b.key
    end)
    local total = 0
    for _, nd in ipairs(nl) do total = total + nd.n end
    res.need[it] = total > 0 and total or nil
    -- Offres : stock, sorties prises, sorties collectables (fraîches puis échues).
    local s_left = stock[it] or 0
    local taken, fresh_c, expired_c = {}, {}, {}
    local dispo_out, dort, all = 0, 0, 0
    for _, e in ipairs(by_item[it] or {}) do
      local s, n = e.s, e.n
      do
        all = all + n
        if s.collect == "taken" then
          local c = num(s.carry)
          local q = c and math.min(n, c) or n
          taken[#taken + 1] = { s = s, left = q }
          dispo_out = dispo_out + q
          dort = dort + (n - q)
        else
          dort = dort + n
          if s.ok == true then
            local w = st.wait[s.id]
            if w ~= nil and tick - w >= Mq.COLLECT_WAIT then expired_c[#expired_c + 1] = { s = s, left = n }
            else fresh_c[#fresh_c + 1] = { s = s, left = n } end
          end
        end
      end
    end
    res.dispo_stock[it] = (stock[it] or 0) > 0 and stock[it] or nil
    res.dispo_sorties[it] = dispo_out > 0 and dispo_out or nil
    res.dort[it] = dort > 0 and dort or nil
    res.out_all[it] = all > 0 and all or nil
    res.net[it] = (stock[it] or 0) + dispo_out - total
    local function from(list, n, nd, act)
      -- Les offres se consomment dans l'ordre : list.i saute celles qui sont vides (coût linéaire en besoins + offres).
      local i = list.i or 1
      while i <= #list and list[i].left <= Mq.EPS do i = i + 1 end
      list.i = i
      for j = i, #list do
        local o = list[j]
        if n <= Mq.EPS then break end
        if o.left > Mq.EPS then
          local q = math.min(n, o.left)
          o.left, n = o.left - q, n - q
          if act then
            local k = tostring(o.s.id) .. "|" .. it
            local a = actions[k]
            if not a then
              a = { source = o.s.id, item = it, n = 0, prio = nd.prio, task = o.s.task, d = o.s.d, expired = act == "expired" or nil }
              actions[k] = a
              order[#order + 1] = k
            end
            a.n = a.n + q
            if nd.prio > a.prio then a.prio = nd.prio end
            used[o.s.id] = true
          end
        end
      end
      return n
    end
    local build = 0
    for _, nd in ipairs(nl) do
      local n = nd.n
      local q = nd.net and 0 or math.min(n, s_left) -- une demande NETTE a déjà compté le stock (règle 4)
      s_left, n = s_left - q, n - q
      n = from(taken, n, nd, nil)
      n = from(fresh_c, n, nd, "fresh")
      if n > Mq.EPS then
        build = build + n
        res.short_by[#res.short_by + 1] = { key = nd.key, item = it, n = n, prio = nd.prio }
        from(expired_c, n, nd, "expired") -- règle 6 : collecte encore demandée, construction non retenue
      end
    end
    res.build[it] = build > Mq.EPS and build or nil
  end
  -- Actions de collecte, triées (priorité décroissante, distance, sortie, objet).
  local tmp = {}
  for _, k in ipairs(order) do local x = actions[k] tmp[#tmp + 1] = { a = x, d = num(x.d) or math.huge } end
  table.sort(tmp, function(p, q)
    local a, b = p.a, q.a
    if a.prio ~= b.prio then return a.prio > b.prio end
    if p.d ~= q.d then return p.d < q.d end
    if a.source ~= b.source then return id_before(a.source, b.source) end
    return a.item < b.item
  end)
  for i, e in ipairs(tmp) do res.collect[i] = e.a end
  -- Listes d'écarts triées (l'ordre d'entrée ne compte pas).
  table.sort(res.stale, id_before)
  table.sort(res.refused, function(a, b)
    local ka, kb = tostring(a.id), tostring(b.id)
    if ka ~= kb then return ka < kb end
    return a.why < b.why
  end)
  -- Horloges de la règle 6.
  local live = {}
  for _, s in ipairs(srcs) do live[s.id] = s end
  for _, id in ipairs(sorted_keys(st.wait)) do
    local s = live[id]
    if not s or s.collect == "taken" or not used[id] then st.wait[id] = nil end
  end
  for _, s in ipairs(srcs) do
    if used[s.id] and s.collect ~= "taken" and st.wait[s.id] == nil then st.wait[s.id] = tick end
  end
  return res
end

--- Puits MESURÉS pour la capitalisation (input.sinks, objets par minute) : la part NON couverte des manques des MODULES qui tournent
--- (res.short_by, clés « m: ») ÷ Mq.H_NEED, ajoutée après la liste `base` (recopiée telle quelle). Les demandes hors module (« w: »,
--- objectif et recrue) n'y vont pas : la capitalisation les lit déjà (input.need). La consommation d'un module FINI n'est dans aucun
--- autre puits (Ca.requirements ne propage que puits, buts, ordres ouverts et packs : shared/ai3/demande.lua, en-tête). Sans
--- résultat (res absent) : `base` seule.
function Mq.sinks(res, base)
  local out = {}
  for _, s in ipairs(base or {}) do out[#out + 1] = s end
  if type(res) ~= "table" or type(res.short_by) ~= "table" then return out end
  local per = {}
  for _, e in ipairs(res.short_by) do
    local n = type(e) == "table" and num(e.n) or nil
    if n and n > Mq.EPS and type(e.key) == "string" and e.key:sub(1, 2) == "m:" and type(e.item) == "string" then add(per, e.item, n) end
  end
  for _, it in ipairs(sorted_keys(per)) do
    local r = per[it] / Mq.H_NEED
    out[#out + 1] = { item = it, rate = r, want = r, src = "mq" }
  end
  return out
end

return Mq
