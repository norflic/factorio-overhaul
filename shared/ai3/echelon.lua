--[[
  Lot ECHELON « une usine qui s'échelonne » (retour du DC du 2/11 : « pouvoir échelonner une usine, par exemple la science rouge, si non
  scalable » ; mesure du lot MALL : le module des objets de base est le goulot de toute l'économie, des chantiers attendent le même objet
  pendant plus de 15 minutes).

  Règle PURE (aucune API Factorio ; AUCUN nom d'objet, de machine, de recette ou de technologie : soumise à l'anti-échelle de
  tests/iag_test.lua §8). Testée hors jeu : tests/echelon_test.lua. Le runtime est script/team/echelon.lua.

  CE QUE LE JOURNAL MONTRE (fo-logs/2026-11-02_ECHELON/RAPPORT.md, §1) : le nombre de machines n'est PAS le goulot. Un module de l'objet de
  base est posé à 1 machine de 180 objets/min nominaux ; il en sort 40/min au début puis 9/min. Trois causes, dans l'ordre où elles coûtent :
    1. AMORCAGE : le module qui fabrique l'objet X exige lui-même de X pour être bâti (8 de X, un bras rapide, une machine) et passe
       derrière tous les chantiers plus anciens, qui prennent chacun un morceau de X (`reserve` de script/team/build.lua prend ce qui est
       libre, projet après projet) : 17 à 19 minutes en « reserve:materiaux » dans deux parties différentes. Règle : Ech.held_back /
       Ech.take_limit, le PRODUCTEUR de ce qui manque passe d'abord.
    2. ENTREE : le module est servi par des quais que les PNJ remplissent (400 objets au plus, quand le quai passe sous 60) : la machine
       (180/min) attend sa matière (9/min). Règle : Ech.fill et Ech.lines, le quai se remplit et se relève selon le DÉBIT du module, pas
       selon une constante.
    3. DEMANDE : la demande d'un objet n'est lue qu'à la main (3 épisodes sur 20 minutes) : un arriéré de chantiers n'ouvre rien. Règle :
       Ech.backlog, les manques des chantiers deviennent une demande (objets/min = manque ÷ Ech.CATCHUP_MIN).
  Le nombre de machines, lui, suit la demande ET le débit d'entrée (Ech.plan) : N passe à N+1 quand la production reste sous Ech.SERVE de
  la demande ET que les machines posées ne suffisent pas à la porter, jamais au-delà de ce que l'entrée peut nourrir ni du plafond
  Ech.MAX_COPIES. Si les machines suffisent déjà (cas de l'objet de base), la règle ne pose PAS de machine : elle dit « entrée » et agit
  sur les quais (Ech.fill).

  CONFIGURATION (tous les plafonds sont ici, lisibles, et rendus par Ech.limits() au journal [FO-ECHELON]).
  Déterminisme : listes triées, entiers et flottants calculés dans un ordre fixe, aucun pairs décisionnel, aucune horloge mesurée (ticks
  de jeu donnés par l'appelant) ; l'état `st` ne garde que des nombres.
]]

local Ech = {}

Ech.TICKS_MIN = 3600       -- ticks de jeu par minute
Ech.WAIT_MIN = 2           -- minutes qu'un chantier attend un objet avant que son manque compte comme demande
Ech.CATCHUP_MIN = 3        -- l'arriéré doit pouvoir être rattrapé en 3 minutes (critère E1 du lot)
Ech.LEAD = 2               -- capacité visée = 2 fois la demande régulière (Id.LEAD, Ca.LEAD)
Ech.SERVE = 0.8            -- la production doit atteindre 80 % de la demande (critère E2 du lot)
Ech.STEP = 1               -- machines ajoutées par étape (N -> N+1)
Ech.COOLDOWN_MIN = 2       -- minutes entre deux ajouts : la machine d'avant doit avoir eu le temps de peser sur la production mesurée
Ech.MAX_COPIES = 8         -- PLAFOND : machines par module
Ech.MAX_MODULES = 4        -- PLAFOND : modules finis par objet quand un arriéré les réclame (la règle de base en garde 2)
Ech.MAX_LINES = 4          -- PLAFOND : lignes d'entrée (quais) en parallèle pour une même matière
Ech.LINE_CAP = 200         -- objets/min qu'une ligne d'entrée apporte (un aller-retour de 400 objets toutes les 2 minutes) ; HYPOTHESE à mesurer
Ech.FILL_MIN = 10          -- minutes de consommation d un module gardées dans ses quais (plus que la durée entre deux passages d un porteur)
Ech.LOW_MIN = 3            -- minutes de consommation sous lesquelles un quai est rempli (le porteur met jusqu a 3 minutes à venir : HYPOTHESE à mesurer)
Ech.GUARD_MAX_MIN = 10     -- minutes pendant lesquelles un producteur en attente passe devant (filet : passé ce délai, ordre normal)
Ech.EPS = 1e-9

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end

--- Les plafonds et délais, pour le journal et les tests : liste de { nom, valeur } dans un ordre fixe.
function Ech.limits()
  return {
    { "MAX_COPIES", Ech.MAX_COPIES }, { "MAX_MODULES", Ech.MAX_MODULES }, { "MAX_LINES", Ech.MAX_LINES },
    { "LINE_CAP", Ech.LINE_CAP }, { "WAIT_MIN", Ech.WAIT_MIN }, { "CATCHUP_MIN", Ech.CATCHUP_MIN },
    { "SERVE", Ech.SERVE }, { "COOLDOWN_MIN", Ech.COOLDOWN_MIN }, { "GUARD_MAX_MIN", Ech.GUARD_MAX_MIN },
  }
end

---------------------------------------------------------------------------------------------------
-- 1. L'arriéré des chantiers devient une demande
---------------------------------------------------------------------------------------------------
--- waiters : { { id, since (tick où le chantier attend), missing = { { objet, quantité } } } }, un élément par chantier en attente de matière.
--- Rend une liste triée (quantité décroissante, nom) de { item, qty, projects, oldest (ticks), rate (objets/min pour rattraper en CATCHUP_MIN),
--- due (le plus ancien attend depuis WAIT_MIN minutes ou plus) }.
function Ech.backlog(waiters, tick)
  local by = {}
  for _, w in ipairs(waiters or {}) do
    local waited = math.max(0, (tick or 0) - (w.since or tick or 0))
    for _, m in ipairs(w.missing or {}) do
      local item, n = m[1], m[2]
      if type(item) == "string" and type(n) == "number" and n > Ech.EPS then
        local r = by[item]
        if not r then r = { item = item, qty = 0, projects = 0, oldest = 0 } by[item] = r end
        r.qty = r.qty + n
        r.projects = r.projects + 1
        if waited > r.oldest then r.oldest = waited end
      end
    end
  end
  local out = {}
  for _, k in ipairs(sorted_keys(by)) do
    local r = by[k]
    r.rate = r.qty / Ech.CATCHUP_MIN
    r.due = r.oldest >= Ech.WAIT_MIN * Ech.TICKS_MIN
    out[#out + 1] = r
  end
  table.sort(out, function(a, b)
    if a.qty ~= b.qty then return a.qty > b.qty end
    return a.item < b.item
  end)
  return out
end

--- La demande d'un objet à la règle du choix (shared/ai3/industrie.lua) : liste { item, rate, src = "chantier" } des arriérés échus.
function Ech.sources(rows)
  local out = {}
  for _, r in ipairs(rows or {}) do
    if r.due then out[#out + 1] = { item = r.item, rate = r.rate, src = "chantier" } end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- 2. Le débit d'entrée borne le nombre de machines
---------------------------------------------------------------------------------------------------
--- Débit maximal (objets/min) qu'une matière d'entrée permet. inputs : { { name, per } } (per = unités d'entrée par objet fabriqué, > 0) ;
--- supply : { [name] = unités/min qui peuvent être apportées } (une matière absente de supply n'est pas bornée : débit inconnu).
--- Rend (débit, nom de l'entrée qui borne) ; math.huge et nil quand rien n'est borné.
function Ech.input_cap(inputs, supply)
  local cap, bind = math.huge, nil
  for _, i in ipairs(inputs or {}) do
    local s = supply and supply[i.name]
    if type(s) == "number" and type(i.per) == "number" and i.per > Ech.EPS then
      local c = s / i.per
      if c < cap - Ech.EPS or (math.abs(c - cap) <= Ech.EPS and bind and i.name < bind) then cap, bind = c, i.name end
    end
  end
  return cap, bind
end

--- Lignes d'entrée (quais en parallèle) pour porter `rate` objets/min : { { name, flow (unités/min), lines, capped } } dans l'ordre des entrées.
function Ech.lines(rate, inputs)
  local out = {}
  for _, i in ipairs(inputs or {}) do
    local flow = (rate or 0) * (i.per or 0)
    local n = math.ceil(flow / Ech.LINE_CAP - Ech.EPS)
    if n < 1 then n = 1 end
    local capped = false
    if n > Ech.MAX_LINES then n, capped = Ech.MAX_LINES, true end
    out[#out + 1] = { name = i.name, flow = flow, lines = n, capped = capped }
  end
  return out
end

--- Machines voulues pour un module (le coeur de la règle).
--- st (état, nombres) : last_add = tick du dernier ajout.
--- inp = { tick, n (machines posées), par_min (objets/min d'une machine), demand (objets/min réguliers, max des sources), backlog (ligne de
---   Ech.backlog ou nil), made (objets/min MESURÉS du module, nil : inconnu = 0), inputs, supply }
--- Rend { n, n_target, add (0 ou plus), bound, lever, why, need, target_rate, cap_in, bind } :
---   bound : "servi" (production au niveau), "entree" (les machines suffisent ou l'entrée borne : AJOUTER UNE MACHINE N'APPORTE RIEN),
---           "plafond" (Ech.MAX_COPIES), "delai" (attente du délai entre deux ajouts), "demande" (machine de plus), "aucun" (pas de module)
---   lever : "machine" | "entree" | "aucun"
function Ech.plan(st, inp)
  local n = math.max(0, math.floor(inp.n or 0))
  local par = inp.par_min or 0
  local demand = math.max(0, inp.demand or 0)
  local back = inp.backlog and inp.backlog.due and inp.backlog.rate or 0
  local target_rate = math.max(demand, back)               -- ce qu'il faut SERVIR
  local need = math.max(demand * Ech.LEAD, back)           -- ce qu'il faut pouvoir PRODUIRE
  local cap_in, bind = Ech.input_cap(inp.inputs, inp.supply)
  local out = { n = n, n_target = n, add = 0, bound = "servi", lever = "aucun", need = need, target_rate = target_rate, cap_in = cap_in, bind = bind }
  if n <= 0 or par <= Ech.EPS then
    out.bound, out.why = "aucun", "aucun module posé : l'ouverture revient à la règle du choix"
    return out
  end
  local n_need = math.ceil(need / par - Ech.EPS)
  local n_in = (cap_in == math.huge) and math.huge or math.floor(cap_in / par + Ech.EPS)
  local n_target = math.min(n_need, Ech.MAX_COPIES, n_in)
  if n_target < n then n_target = n end
  out.n_target = n_target
  local made = inp.made or 0
  if target_rate <= Ech.EPS or made >= Ech.SERVE * target_rate - Ech.EPS then
    out.why = string.format("production %.1f/min pour une demande de %.1f/min", made, target_rate)
    return out
  end
  -- la production reste sous SERVE × la demande
  if n * par + Ech.EPS >= target_rate then
    out.bound, out.lever = "entree", "entree"
    out.why = string.format("%d machine(s) de %.0f/min portent la demande de %.1f/min mais ne sortent que %.1f/min : l'entree n'arrive pas%s",
      n, par, target_rate, made, bind and (" (" .. bind .. ")") or "")
    return out
  end
  if n >= Ech.MAX_COPIES then
    out.bound, out.lever = "plafond", "entree"
    out.why = string.format("plafond de %d machine(s) atteint", Ech.MAX_COPIES)
    return out
  end
  if n >= n_in then
    out.bound, out.lever = "entree", "entree"
    out.why = string.format("l'entree %s ne porte que %.1f/min : une machine de plus n'apporte rien", tostring(bind), cap_in)
    return out
  end
  if st and st.last_add and (inp.tick or 0) - st.last_add < Ech.COOLDOWN_MIN * Ech.TICKS_MIN then
    out.bound, out.lever = "delai", "machine"
    out.why = "ajout recent : attente de la production mesuree"
    return out
  end
  local add = math.min(Ech.STEP, n_target - n)
  if add < 1 then
    out.bound, out.lever = "entree", "entree"
    out.why = "aucune machine de plus voulue"
    return out
  end
  out.add, out.bound, out.lever = add, "demande", "machine"
  out.why = string.format("production %.1f/min sous %.0f %% de la demande %.1f/min : %d -> %d machine(s)", made, Ech.SERVE * 100, target_rate, n, n + add)
  if st then st.last_add = inp.tick or 0 end
  return out
end

--- Modules finis permis pour un objet : la règle de base (`base`), plus jusqu'à Ech.MAX_MODULES quand un arriéré échu le réclame.
function Ech.module_cap(base, backlog)
  if backlog and backlog.due then return math.max(base or 0, Ech.MAX_MODULES) end
  return base
end

---------------------------------------------------------------------------------------------------
-- 3. Les quais suivent le débit du module
---------------------------------------------------------------------------------------------------
--- Remplissage d'un quai d'entrée : { fill (objets visés), low (seuil de remplissage) } pour un module de `rate` objets/min qui consomme
--- `per` unités par objet. base_fill / base_low : les constantes d'avant (jamais en dessous) ; cap : place du coffre (objets), nil : illimitée.
function Ech.fill(rate, per, base_fill, base_low, cap)
  local flow = math.max(0, (rate or 0) * (per or 0))
  local fill = math.max(base_fill or 0, math.ceil(flow * Ech.FILL_MIN - Ech.EPS))
  local low = math.max(base_low or 0, math.ceil(flow * Ech.LOW_MIN - Ech.EPS))
  if type(cap) == "number" and cap > 0 then
    if fill > cap then fill = cap end
  end
  if low >= fill then low = math.max(0, fill - 1) end
  return { fill = fill, low = low }
end

---------------------------------------------------------------------------------------------------
-- 4. Le producteur de ce qui manque passe d'abord
---------------------------------------------------------------------------------------------------
--- projects : { { id, state, since (tick d'entrée en réserve), produces = { [objet] = vrai }, missing = { { objet, quantité } } } } ;
--- seuls les projets en « reserve » comptent. Rend { [objet] = quantité } : ce que les PRODUCTEURS de l'objet en attente lui-même doivent
--- encore recevoir, et que les autres projets ne prennent pas. Un producteur attend au plus Ech.GUARD_MAX_MIN minutes en priorité.
function Ech.held_back(projects, tick)
  local held = {}
  for _, p in ipairs(projects or {}) do
    if p.state == "reserve" and p.produces then
      local waited = (tick or 0) - (p.since or tick or 0)
      if waited <= Ech.GUARD_MAX_MIN * Ech.TICKS_MIN then
        for _, m in ipairs(p.missing or {}) do
          if p.produces[m[1]] and type(m[2]) == "number" and m[2] > 0 then held[m[1]] = (held[m[1]] or 0) + m[2] end
        end
      end
    end
  end
  return held
end

--- Combien de `free` un projet peut prendre : le producteur de l'objet prend tout, un autre laisse la part retenue.
function Ech.take_limit(free, held, is_producer)
  free = math.max(0, free or 0)
  if is_producer then return free end
  return math.max(0, free - math.max(0, held or 0))
end

---------------------------------------------------------------------------------------------------
-- 5. Journal
---------------------------------------------------------------------------------------------------
--- Une ligne [FO-ECHELON] (aucune décision ne la lit).
function Ech.describe(item, plan, back)
  return string.format("%s : %s, %d machine(s) -> %d voulue(s) (besoin %.1f/min, entree %s) ; arriere %s ; %s",
    item, plan.bound, plan.n, plan.n_target, plan.need or 0,
    (plan.cap_in == math.huge or plan.cap_in == nil) and "non bornee" or string.format("%.1f/min", plan.cap_in),
    back and string.format("%d a rattraper chez %d chantier(s) depuis %.1f min", back.qty, back.projects, back.oldest / Ech.TICKS_MIN) or "aucun",
    tostring(plan.why))
end

return Ech
