--[[
  Lot CAPITAL « améliorer, et monter les époques » (décision D-20 (3) du DC, 27/10, 10 h 15 : « si l'IA est autonome elle
  le fera d'elle même, il faut que ce soit un choix logique et non encré en dur c'est très important » ; conception
  docs/IA3_CERVEAU.md §3.1, famille Capital, « améliorer un niveau » ; §3.7 « payer le niveau du centre »). PUR (aucune API
  Factorio) : testé hors jeu (tests/capital_test.lua) ; le runtime (script/ai3/capital.lua) lui donne le relevé des
  bâtiments à niveaux de la force, les prototypes de leurs niveaux et le coût de fabrication de chaque objet (graphe du
  cerveau général), puis il PAIE le niveau choisi par le même mécanisme que le joueur (script/levels/levels.lua).

  Ce qu'un joueur fait : il améliore ce qui rapporte le plus pour ce que ça coûte, et il monte son centre quand le centre
  ouvre des améliorations qui valent la peine (la condition du centre l'oblige d'abord à monter un bâtiment de chaque
  famille qu'il possède). En calcul, pour chaque bâtiment à niveaux de la force (et son centre) :

  1. CANDIDAT = le niveau suivant, s'il est permis (règles des DONNÉES des niveaux, Ld = shared/levels/config.lua ou une
     copie : Ld.check, Ld.max_level, Ld.cc_condition_level, Ld.cc_blockers). La famille « centre » n'est pas nommée : c'est
     celle dont les niveaux n'exigent aucun centre (Ld.required_cc = 0).
  2. COÛT LU DANS LES DONNÉES : la liste { {objet, n} } de Ld.cost(famille, n + 1) (le centre absent : l'objet qui le
     pose, lu dans son prototype). Coût en travail = Σ n × coût unitaire de l'objet (point fixe min-plus du graphe du
     cerveau général : fabrication, ingrédients, machines ; ctx.unit_cost), l'objet déjà au stock compté à
     Cap.STOCK_PCT % (investir un stock qui dort, H4). Un objet dont le coût unitaire est inconnu (nil : aucune façon
     connue de l'obtenir) rend le candidat IMPAYABLE (règle H8 : rien n'est fabriqué pour lui ; ses objets sont rendus
     dans `wanted`, la recherche qui les débloque prend de la valeur, H9).
  3. VALEUR LUE DANS LES PROTOTYPES des deux niveaux (ctx.proto(nom) -> { role, speed, dps, health, item }), par RÔLE du
     type de l'entité (shared/ai3/reglages.lua, R.ENTITY_ROLE : mots du moteur) :
       fabrique, foreuse : DÉBIT, gain = vitesse(n + 1) ÷ vitesse(n) − 1, × l'usage du bâtiment (en marche : 1 ; à
                           l'arrêt : Cap.IDLE_USE) × Cap.V_DEBIT ;
       militaire         : DÉFENSE, gain = (dps × vie)(n + 1) ÷ (dps × vie)(n) − 1 (la force d'un combattant croît comme
                           le produit de ses dégâts et de sa vie), × Cap.V_COMBAT, × Cap.THREAT_PCT % sous menace ;
       centre            : ÉPOQUE, Cap.V_EPOCH (ouvrir l'époque suivante) + ce que le centre DÉBLOQUE : la valeur des
                           améliorations que son plafond interdit aujourd'hui (bâtiments au plafond), ÷ Cap.LOOK_DIV.
     Chaque terme est pondéré par le poids de sa famille de buts (chef d'IA2-a, traits d'IA2-0 : capital, defense).
  4. CONDITION DU CENTRE (Q16) : une famille possédée sous le niveau exigé BLOQUE le centre ; son bâtiment le plus haut
     hérite de Cap.CHAIN_PCT % de la valeur du centre (la chaîne des pourquoi : « monter cette tourelle ouvre l'époque »).
  5. CHOIX : score = valeur × 1 000 ÷ (coût + Cap.COST_FLOOR), inertie de Cap.INERTIA_PCT % pour le candidat en cours ;
     égalités départagées par la clé.
  Le BUT rendu au cerveau (Cap.goal) porte la liste { {objet, n} } du coût : le dépliage (shared/ai3/projets.lua, P.want ;
  shared/ai3/general.lua, Gen.summary) la sert comme n'importe quel besoin, sans rien savoir des niveaux. Un coût qui
  contiendra demain une pièce montée est fabriqué (main), produit ou automatisé (machine, IA3-e) sans une ligne de plus.

  Aucun nom du jeu ici (test anti-échelle, tests/iag_test.lua §8). Déterminisme : listes triées par numéro d'entité et
  par clé, entiers pour les scores, aucun hasard, aucun pairs décisionnel.
]]

local Cap = {}

Cap.V_DEBIT = 100       -- un bâtiment en marche dont la vitesse doublerait vaut 100 (même échelle que Gen.V_PACK)
Cap.V_COMBAT = 60       -- un combattant dont la force doublerait vaut 60 (militaire : Gen.V_MIL 40 + son bonus 25, arrondi)
Cap.V_EPOCH = 100       -- ouvrir l'époque suivante (la progression : comme un pack nouveau, Gen.V_PACK)
Cap.IDLE_USE = 25       -- % : un bâtiment à l'arrêt ne rapporte qu'un quart de son gain (il servira peut-être)
Cap.THREAT_PCT = 200    -- % : sous menace, la défense vaut le double (H4 : l'horizon se raccourcit)
Cap.LOOK_DIV = 2        -- ce qu'un centre débloque compte pour moitié (gain d'après, pas d'aujourd'hui)
Cap.CHAIN_PCT = 50      -- part de la valeur du centre héritée par le bâtiment qui le bloque (condition Q16)
Cap.STOCK_PCT = 50      -- % : un objet déjà au stock libre coûte moitié (il dort ; son usage ailleurs a un prix)
Cap.COST_FLOOR = 10
Cap.INERTIA_PCT = 20
Cap.TOP = 3             -- candidats gardés pour le journal
-- Valeur du BUT au cerveau (échelle des projets, 0 à 100 ; shared/ai3/buts.lua) : sous l'armée qui grandit (46) et la
-- croissance de l'extraction (55), au-dessus du travail de fond ; + Cap.GOAL_STOCK quand tout le coût dort déjà au
-- stock libre (investir, H4 : aucun travail, rien ne manque) ; le centre (l'époque) + Cap.GOAL_EPOCH.
Cap.GOAL_VALUE = 40
Cap.GOAL_STOCK = 12
Cap.GOAL_EPOCH = 6

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function wf(w, fam) return ((w or {})[fam] or 1000) / 1000 end

--- Famille « centre » des données : celle dont les niveaux n'exigent aucun centre (aucun nom écrit).
function Cap.center_family(Ld)
  for _, fam in ipairs(Ld.families) do
    if fam.max >= 2 and Ld.required_cc(fam, 2) == 0 then return fam end
  end
  return nil
end

--- Gain relatif du niveau n au niveau n + 1, lu dans les prototypes ; rend gain (≥ 0), sorte (« debit », « combat » ou
--- nil).
function Cap.gain(Ld, proto, fam, n)
  if n >= fam.max then return 0, nil end
  local p0, p1 = proto(Ld.name(fam, n)), proto(Ld.name(fam, n + 1))
  if not (p0 and p1) then return 0, nil end
  local role = p0.role
  if (role == "fabrique" or role == "foreuse") and (p0.speed or 0) > 0 and (p1.speed or 0) > 0 then
    return math.max(0, p1.speed / p0.speed - 1), "debit"
  end
  if role == "militaire" and (p0.health or 0) > 0 and (p1.health or 0) > 0 then
    local f0 = (p0.dps or 1) * p0.health
    local f1 = (p1.dps or 1) * p1.health
    return math.max(0, f1 / f0 - 1), "combat"
  end
  return 0, nil
end

--- Valeur propre de l'amélioration d'un bâtiment (sans chaîne) : v, raison { sorte, gain en % }.
function Cap.building_value(Ld, proto, fam, n, working, ctx)
  local g, kind = Cap.gain(Ld, proto, fam, n)
  if not kind or g <= 0 then return 0, nil end
  local w = ctx and ctx.weights
  local v
  if kind == "debit" then
    local use = working and 100 or Cap.IDLE_USE
    v = Cap.V_DEBIT * g * use / 100 * wf(w, "capital")
  else
    local th = (ctx and ctx.threat) and Cap.THREAT_PCT or 100
    v = Cap.V_COMBAT * g * th / 100 * wf(w, "defense")
  end
  return math.floor(v + 0.5), { kind, math.floor(g * 1000 + 0.5) / 10 }
end

--- Coût en travail d'une liste { {objet, n} } (ctx.unit_cost ; stock libre ctx.stock à Cap.STOCK_PCT %) ; rend coût,
--- objets sans coût connu (liste triée), objets du coût tous au stock (vrai/faux).
function Cap.work_cost(list, ctx)
  local c, missing, all_in = 0, {}, true
  local stock = (ctx and ctx.stock) or {}
  for _, it in ipairs(list) do
    local item, n = it[1], it[2]
    local u = ctx and ctx.unit_cost and ctx.unit_cost(item)
    if u == nil then
      missing[#missing + 1] = item
    else
      local have = math.min(n, stock[item] or 0)
      if have < n then all_in = false end
      c = c + (n - have) * u + have * u * Cap.STOCK_PCT / 100
    end
  end
  table.sort(missing)
  if #missing > 0 then all_in = false end
  return math.floor(c + 0.5), missing, all_in
end

--- Candidats. census = { list = { {id, name, working} } (bâtiments à niveaux, triés par id), center = { id, name } ou
--- nil } ; ctx = { proto, unit_cost, stock, weights, threat, current }. Rend { cands (triés : score décroissant, clé),
--- blocked (impayables ou bloqués, triés), center_fam, blockers }.
function Cap.candidates(Ld, census, ctx)
  local proto = ctx.proto
  local cfam = Cap.center_family(Ld)
  local cc_level = 0
  local center = census.center
  if center and cfam then
    local f, n = Ld.parse(center.name)
    if f == cfam then cc_level = n end
  end
  -- Bâtiments par famille (le plus haut d'abord pour la chaîne Q16) et recensement Q16 de la force.
  local rows = {}
  local cond = cc_level > 0 and Ld.cc_condition_level(cc_level) or nil
  local q16 = {}
  local top_of = {}
  for _, b in ipairs(census.list or {}) do
    local fam, n = Ld.parse(b.name)
    if fam and fam ~= cfam then
      rows[#rows + 1] = { b = b, fam = fam, n = n }
      local c = q16[fam.key] or { any = true, top = false }
      if cond and n >= math.min(cond, fam.max) then c.top = true end
      q16[fam.key] = c
      -- Le bâtiment de la chaîne Q16 : le plus haut ; à niveau égal, celui qui est en marche (il rapporte aussi par
      -- lui-même) ; puis le plus petit numéro.
      local t = top_of[fam.key]
      local better = not t or n > t.n
      if t and n == t.n then
        local bw, tw = b.working and 1 or 0, t.b.working and 1 or 0
        better = bw > tw or (bw == tw and b.id < t.b.id)
      end
      if better then top_of[fam.key] = rows[#rows] end
    end
  end
  local cands, blocked = {}, {}
  local function add(c)
    -- Refus récent de l'exécutant (place, condition vue autrement par le jeu) : écarté jusqu'à son échéance (ctx.exclude).
    if ctx.exclude and ctx.exclude[c.key] then
      c.causes = { "refus" }
      blocked[#blocked + 1] = c
      return
    end
    local cost, missing, all_in = Cap.work_cost(c.cost, ctx)
    c.work, c.all_in = cost, all_in
    if #missing > 0 then
      c.causes = missing
      blocked[#blocked + 1] = c
      return
    end
    if c.value <= 0 then return end
    local score = math.floor(c.value * 1000 / (cost + Cap.COST_FLOOR))
    if ctx.current and c.key == ctx.current then score = math.floor(score * (100 + Cap.INERTIA_PCT) / 100) end
    c.score = score
    cands[#cands + 1] = c
  end
  -- Bâtiments : leur niveau suivant (permis par le plafond du centre).
  local own = {}
  for _, r in ipairs(rows) do
    local fam, n = r.fam, r.n
    local v, why = Cap.building_value(Ld, proto, fam, n, r.b.working, ctx)
    own[#own + 1] = { r = r, v = v, why = why }
    if n < fam.max and Ld.check(fam, n + 1, cc_level) then
      r.cand = { key = fam.key .. ":" .. (n + 1) .. ":" .. r.b.id, id = r.b.id, family = fam.key, from = n, to = n + 1,
        cost = Ld.cost(fam, n + 1), value = v, why = { why } }
    end
  end
  -- Centre : le poser (aucun) ou le monter. Valeur = l'époque + ce que son plafond débloque (÷ LOOK_DIV).
  local blockers = {}
  if cfam then
    local cap_now = cc_level > 0 and Ld.building_cap(cc_level) or Ld.building_cap(0)
    local unlocked = 0
    for _, o in ipairs(own) do
      local fam, n = o.r.fam, o.r.n
      if n >= cap_now and n < fam.max then unlocked = unlocked + o.v end
    end
    local cv = math.floor((Cap.V_EPOCH * wf(ctx.weights, "capital") + unlocked / Cap.LOOK_DIV) + 0.5)
    local cc
    if cc_level == 0 then
      local p = proto(Ld.name(cfam, 1))
      local item = p and p.item
      if item then
        cc = { key = cfam.key .. ":1:pose", family = cfam.key, from = 0, to = 1, build = true, cost = { { item, 1 } },
          value = cv, why = { { "epoque", 1 }, { "debloque", unlocked } }, center = true }
      end
    elseif cc_level < cfam.max then
      cc = { key = cfam.key .. ":" .. (cc_level + 1) .. ":" .. center.id, id = center.id, family = cfam.key,
        from = cc_level, to = cc_level + 1, cost = Ld.cost(cfam, cc_level + 1), value = cv,
        why = { { "epoque", cc_level + 1 }, { "debloque", unlocked } }, center = true }
      blockers = Ld.cc_blockers(q16)
    end
    if cc then
      if #blockers > 0 then
        cc.causes = {}
        for _, k in ipairs(blockers) do cc.causes[#cc.causes + 1] = "condition:" .. k end
        blocked[#blocked + 1] = cc
        -- Chaîne Q16 : le bâtiment le plus haut de chaque famille qui bloque hérite d'une part de la valeur du centre.
        local share = math.floor(cv * Cap.CHAIN_PCT / 100)
        for _, k in ipairs(blockers) do
          local t = top_of[k]
          if t and t.cand then
            t.cand.value = t.cand.value + share
            t.cand.chain = { target = cc.key, v = share }
          end
        end
      else
        add(cc)
      end
    end
  end
  for _, r in ipairs(rows) do if r.cand then add(r.cand) end end
  table.sort(cands, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.key < b.key
  end)
  table.sort(blocked, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.key < b.key
  end)
  return { cands = cands, blocked = blocked, center_fam = cfam, cc_level = cc_level, blockers = blockers }
end

--- Le choix : le meilleur candidat (nil s'il n'y en a pas) ; d.ranked = les Cap.TOP premiers { clé, score } ;
--- d.wanted = objets sans coût connu des candidats de valeur bloqués par eux (H8 -> H9).
function Cap.choose(Ld, census, ctx)
  local res = Cap.candidates(Ld, census, ctx)
  local d = res.cands[1] and {} or { none = true }
  for k, v in pairs(res.cands[1] or {}) do d[k] = v end
  d.ranked = {}
  for i = 1, math.min(Cap.TOP, #res.cands) do d.ranked[i] = { res.cands[i].key, res.cands[i].score } end
  d.n_cands = #res.cands
  d.blocked = res.blocked
  d.cc_level = res.cc_level
  local wanted = {}
  for _, b in ipairs(res.blocked) do
    for _, c in ipairs(b.causes or {}) do
      if c:sub(1, 10) ~= "condition:" then wanted[c] = true end
    end
  end
  d.wanted = wanted
  return d
end

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

--- But du cerveau (shared/ai3/projets.lua) pour une décision : la liste du coût et la cible. Clé PROPRE à la cible
--- (« capital:<famille>:<niveau>:<numéro> ») : une amélioration faite ferme son projet (annoncé « fini »).
function Cap.goal(d, weights)
  if not d or d.none or not d.key then return nil end
  local base = Cap.GOAL_VALUE + (d.all_in and Cap.GOAL_STOCK or 0) + (d.center and Cap.GOAL_EPOCH or 0)
  local w = math.max(1000, (weights or {}).capital or 1000) -- le caractère avance l'investissement, sans le retarder
  return { key = "capital:" .. d.key, family = "capital", kind = "upgrade", cost = d.cost, target = d.key,
    value = clamp(math.floor(base * w / 1000), 1, 100), center = d.center or nil }
end

--- Émission du projet (enregistrée dans P.EMIT.upgrade par shared/ai3/cerveau.lua) : tout le coût au stock virtuel ->
--- payé à cette pensée (E.pay, lu par le runtime après le tableau) ; sinon le dépliage le sert comme un besoin ordinaire
--- (prendre, main, matières brutes).
function Cap.emit(P)
  return function(E, proj, g)
    if P.take(E, g.cost) then
      E.pay = E.pay or {}
      E.pay[#E.pay + 1] = { key = g.key, target = g.target, cost = g.cost }
      return "ok"
    end
    P.want(E, proj, g.cost, proj.prio, false, "niveau")
    return "matiere"
  end
end

--- Texte de journal d'une décision (ASCII).
function Cap.why_text(d)
  if not d or d.none then
    local b = {}
    for i = 1, math.min(3, #((d and d.blocked) or {})) do
      local x = d.blocked[i]
      b[#b + 1] = x.key .. " [" .. table.concat(x.causes or {}, " ") .. "]"
    end
    return "aucune amelioration payable ; bloquees : " .. table.concat(b, ", ")
  end
  local parts = {}
  for _, w in ipairs(d.why or {}) do
    if w then parts[#parts + 1] = tostring(w[1]) .. " " .. tostring(w[2]) end
  end
  local cost = {}
  for _, it in ipairs(d.cost or {}) do cost[#cost + 1] = it[1] .. " " .. it[2] end
  local txt = "raisons [" .. table.concat(parts, ", ") .. "] cout [" .. table.concat(cost, ", ") .. "]"
  if d.chain then txt = txt .. " ; ouvre '" .. d.chain.target .. "' (+" .. d.chain.v .. ")" end
  local r = {}
  for i = 2, #(d.ranked or {}) do r[#r + 1] = d.ranked[i][1] .. " " .. d.ranked[i][2] end
  if #r > 0 then txt = txt .. " ; suivantes : " .. table.concat(r, ", ") end
  local bl = {}
  for i = 1, math.min(2, #(d.blocked or {})) do
    bl[#bl + 1] = d.blocked[i].key .. " [" .. table.concat(d.blocked[i].causes or {}, " ") .. "]"
  end
  if #bl > 0 then txt = txt .. " ; bloquees : " .. table.concat(bl, ", ") end
  return txt
end

Cap.sorted_keys = sorted_keys

return Cap
