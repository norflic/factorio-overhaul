--[[
  IA3-e « automatiser ce qui revient », côté RUNTIME : relie la règle pure main → machine (shared/ai3/automatiser.lua)
  au cerveau par besoins (script/ai3/cerveau.lua, shared/ai3/cerveau.lua) et au plan directeur d'IA1-d
  (script/team/build.lua). Allumé par défaut pour les FACTIONS au cerveau par besoins (votre équipe : voir
  Auto.FACTIONS_ONLY).

  - Mesures (fenêtre glissante de minutes complètes, f.team.ia3e.window) : à la fin de chaque tâche réussie
    (crochet Board.on_done), les PNJ-ticks de la tâche vont à l'objet qu'elle produit : tournée d'un avant-poste
    (produit de l'avant-poste), fonte au QG (plaques, au prorata), minage à la main (plaque de son minerai),
    fabrication à la main (objet fabriqué, nombre compté) ; les tâches de quai d'un module (portage du plan directeur)
    vont à sa LOGISTIQUE. Chaque minute, le débit livré au QG par objet (f.team.delivered) clôt la minute.
  - Décision (une fois par minute) : A.decide ; une demande devient Build.request (spec : générateur, paramètres
    dimensionnés, têtes d'alimentation, priorité du projet) ; Build.enable(f, { radius = 3 }) une fois, sans « seul ».
  - Suivi (chaque pensée) : Build.status de chaque demande ; le cerveau reçoit ctx.auto = { modules (état, manques,
    raison), cap (capacité d'extraction des modules finis, en unités d'avant-poste), covered (objets couverts) }.
  - Recherche : les objets d'un gabarit que l'équipe ne sait pas fabriquer (poteau moyen) sont rendus au cerveau par le
    crochet Ia3.wanted : la technologie qui les débloque prend de la valeur.
  - Lisible : une ligne « [FO-IA3E] <équipe> minute M » par minute (charges, débits, modules, verdicts et leurs
    raisons) ; une ligne à chaque demande, fin, refus ou blocage ; interface distante « fo-ia3e » (bancs).

  Déterminisme : listes triées, aucun temps mesuré (des ticks de jeu seulement), aucune fonction dans global.
]]

local T = require("shared.team.config")
local A = require("shared.ai3.automatiser")
local State = require("script.faction.state")
local Board = require("script.team.board")
local Build = require("script.team.build")
local Profiler = require("script.core.profiler")

local Auto = {}

Auto.FACTIONS_ONLY = true   -- votre équipe : même chemin de code, NON allumée dans ce lot (NOTES §3 : bancs du guide)
Auto.EVERY = 3600           -- ticks entre deux décisions
Auto.RADIUS = 3             -- treillis du plan directeur évalué au départ (7 × 7 lots)
Auto.REFUSE_EPOCH = 30 * 3600 -- un refus est revu quand le contexte change, et au plus tard toutes les 30 min
Auto.LOG_MAX = 16

local function sorted_keys(t) return State.sorted_keys(t or {}) end

local function minutes(f, tick)
  local war = State.war()
  return (tick - (f.started or (war and war.started) or 0)) / 3600
end

--- Produit de chaque méthode, et minerai -> plaque (mesure du minage à la main).
local PRODUCTS = {}
for _, m in ipairs(A.METHODS) do PRODUCTS[m.product] = true end
local PLATE_OF_RES = {}
for _, kind in ipairs(T.OUTPOST_ORDER) do
  local spec = T.outposts[kind]
  if T.smelter_inputs[spec.product] then PLATE_OF_RES[spec.resource] = spec.product end
end

-- Produit (nom, nombre) de chaque recette : mémoire LOCALE tirée des prototypes (mesure seulement).
local PRODUCT_AMOUNT = {}

local function enabled(f)
  if not (f and f.team and f.team.ia3c and f.hq and f.hq.valid) then return false end
  if Auto.FACTIONS_ONLY and f.is_player then return false end
  return true
end

local function state_of(f)
  local t = f.team
  t.ia3e = t.ia3e or { v = 1, window = {}, cur = nil, modules = {}, verdicts = {}, wanted = {}, hand = {}, logs = {},
    last_delivered = {}, next_decide = 0 }
  return t.ia3e
end

---------------------------------------------------------------------------------------------------
-- Mesures
---------------------------------------------------------------------------------------------------
local function bucket(st, tick)
  local m = math.floor(tick / 3600)
  if not st.cur or st.cur.m ~= m then
    st.cur = { m = m, load = {}, made = {}, logi = {} }
  end
  return st.cur
end

local function add(t, k, n) t[k] = (t[k] or 0) + n end

--- Crochet de fin de tâche (Board.on_done) : PNJ-ticks de la tâche attribués à l'objet qu'elle produit.
function Auto.on_done(f, task, ok, tick)
  if not (ok and f and f.team and f.team.ia3e and task and task.claimed) then return end
  local st = f.team.ia3e
  local dt = tick - task.claimed
  if dt <= 0 then return end
  local b = bucket(st, tick)
  local k = task.kind
  if task.ia1d then
    local pid = task.ia1d.pid
    for _, m in ipairs(st.modules) do
      if m.id == pid then add(b.logi, m.product, dt) break end
    end
    return
  end
  if k == "service" then
    local o = f.outposts and f.outposts[task.outpost]
    local spec = o and T.outposts[o.kind]
    if spec then add(b.load, spec.product, dt) end
  elseif k == "smelt" then
    local total, items = 0, {}
    for _, p in ipairs(sorted_keys(task.smelt)) do
      local n = task.smelt[p] or 0
      if n > 0 then total = total + n; items[#items + 1] = { p, n } end
    end
    for _, it in ipairs(items) do add(b.load, it[1], dt * it[2] / total) end
  elseif k == "mine" then
    local plate = PLATE_OF_RES[task.resource]
    add(b.load, plate or task.resource, dt)
  elseif k == "craft" and task.item then
    add(b.load, task.item, dt)
    st.hand[task.item] = (st.hand[task.item] or 0) + (task.count or 0)
    -- Objets fabriqués à la main, intermédiaires compris (étapes de la tâche : recette × fabrications × produits) : la
    -- part « à la main » se compare aux produits des assembleurs, intermédiaires compris (statistiques de la force).
    st.hand_all = st.hand_all or {}
    for _, c in ipairs(task.steps or {}) do
      local amount = PRODUCT_AMOUNT[c.recipe]
      if amount == nil then
        local rp = game.recipe_prototypes[c.recipe]
        local pr = rp and rp.products and rp.products[1]
        amount = { pr and pr.name or c.recipe, pr and (pr.amount or 1) or 1 }
        PRODUCT_AMOUNT[c.recipe] = amount
      end
      st.hand_all[amount[1]] = (st.hand_all[amount[1]] or 0) + (c.runs or 0) * amount[2]
    end
  end
end

--- Clôt la minute écoulée : débit livré au QG par objet (toutes sources), fenêtre glissante.
local function roll(f, st, tick)
  local m = math.floor(tick / 3600)
  if st.last_min == m then return end
  local delivered = f.team.delivered or {}
  if st.last_min ~= nil then
    local cur = st.cur
    if not cur or cur.m ~= st.last_min then cur = { m = st.last_min, load = {}, made = {}, logi = {} } end
    for _, item in ipairs(sorted_keys(PRODUCTS)) do
      local d = (delivered[item] or 0) - (st.last_delivered[item] or 0)
      if d > 0 then cur.made[item] = d end
    end
    st.window[#st.window + 1] = cur
    while #st.window > A.WINDOW do table.remove(st.window, 1) end
    st.cur = nil
  end
  for _, item in ipairs(sorted_keys(PRODUCTS)) do st.last_delivered[item] = delivered[item] or 0 end
  st.last_min = m
end

---------------------------------------------------------------------------------------------------
-- Suivi des demandes
---------------------------------------------------------------------------------------------------
local function note(f, st, tick, text)
  local line = string.format("[FO-IA3E] %s : %s a %.1f min", f.key or "player", text, minutes(f, tick))
  log(line)
  st.logs[#st.logs + 1] = { tick = tick, text = text }
  while #st.logs > Auto.LOG_MAX do table.remove(st.logs, 1) end
end

local function refresh(f, st, tick)
  for _, m in ipairs(st.modules) do
    if m.state ~= "fini" and m.state ~= "refuse" then
      local s = Build.status(f, m.id)
      if not s then
        m.state, m.reason = "refuse", "projet perdu"
      else
        local was = m.state
        local state = s.state
        if state == "bloque" and not s.retry_at then state, s.reason = "refuse", "abandon : " .. tostring(s.reason) end
        m.state, m.reason, m.missing = state, s.reason, s.missing or {}
        m.built, m.total = s.built or 0, s.total or 0
        if state ~= was then
          if state == "fini" then
            m.finished = tick
            m.finished_m = math.floor(tick / 3600)
            note(f, st, tick, string.format("module '%s' FINI (%d entites, %.0f objets/min nominal)", m.product, m.total, m.rate_nom or 0))
          elseif state == "refuse" then
            m.sig = st.sig
            note(f, st, tick, string.format("module '%s' REFUSE par le plan directeur : %s", m.product, tostring(m.reason)))
          elseif state == "bloque" then
            note(f, st, tick, string.format("module '%s' bloque : %s", m.product, tostring(m.reason)))
          end
        end
      end
    end
  end
end

--- Contexte d'un refus : rayon du treillis (il grandit jusqu'à Build.RADIUS_MAX quand rien ne tient), époque de 30 min
--- (le terrain change : arbres défrichés, avant-postes, bâtiments). Les technologies n'y sont pas : une recherche ne
--- change pas la place (moteur simulé, sonde du 27/10 : un refus « place » redemandé à chaque technologie).
local function signature(f, tick)
  local b = f.build
  return string.format("r%d:e%d", b and b.radius or 0, math.floor(tick / Auto.REFUSE_EPOCH))
end

---------------------------------------------------------------------------------------------------
-- Pensée
---------------------------------------------------------------------------------------------------
--- Appelé par le cerveau (Ia3.plan) avant la pensée pure. Rend ctx.auto (ou nil : automatisation éteinte).
function Auto.think(f, view, book, tick)
  if not enabled(f) then return nil end
  Profiler.start("ia3e:auto")
  local st = state_of(f)
  roll(f, st, tick)
  st.sig = signature(f, tick)
  refresh(f, st, tick)
  if tick >= (st.next_decide or 0) then
    st.next_decide = tick + Auto.EVERY
    local stock = view.stock or {}
    local res = A.decide({
      window = st.window, threatened = view.threatened, modules = st.modules,
      obtainable = function(item) return book:handcraftable(item) or (stock[item] or 0) > 0 end,
      book = book, stock = stock, has_plant = f.build and f.build.plant ~= nil, sig = st.sig,
    })
    st.wanted = res.wanted
    st.verdicts = {}
    for _, v in ipairs(res.verdicts) do
      st.verdicts[#st.verdicts + 1] = { product = v.product, verdict = v.verdict, why = v.why, L = v.L, D = v.D, T = v.T }
    end
    for _, rq in ipairs(res.requests) do
      -- Plan directeur allumé à la PREMIÈRE demande (une fois, sans « seul » : le cerveau garde ses tâches libres).
      if not f.build then
        Build.enable(f, { radius = Auto.RADIUS })
        note(f, st, tick, "plan directeur allume (rayon " .. Auto.RADIUS .. ")")
      end
      local prio = 40 + math.floor(A.VALUE * 45 / 100)
      local id, why = Build.request(f, { gen = rq.gen, args = rq.args, feed = rq.feed, prio = prio, domain = "production" })
      if id then
        st.modules[#st.modules + 1] = { id = id, product = rq.product, state = "attente", requested = tick,
          rate = rq.rate, rate_nom = rq.rate_nom, gen = rq.gen, args = rq.args, missing = {} }
        note(f, st, tick, string.format("module '%s' DEMANDE (%s %s, %.0f objets/min visés, nominal %.0f) : %s", rq.product, rq.gen,
          table.concat((function() local o = {} for i, a in ipairs(rq.args) do o[i] = tostring(a) end return o end)(), ","),
          rq.rate, rq.rate_nom, rq.why))
      else
        note(f, st, tick, string.format("module '%s' : demande impossible (%s)", rq.product, tostring(why)))
      end
    end
    Auto.minute_line(f, st, tick)
  end
  -- Contexte du cerveau.
  local mods, cap, covered = {}, {}, {}
  local fini_rate, target = {}, {}
  for _, m in ipairs(st.modules) do
    mods[#mods + 1] = { product = m.product, state = m.state, missing = m.missing, reason = m.reason }
    if m.state == "fini" then
      fini_rate[m.product] = (fini_rate[m.product] or 0) + (m.rate_nom or 0)
      target[m.product] = math.max(target[m.product] or 0, m.rate or 0)
    end
  end
  for _, p in ipairs(sorted_keys(fini_rate)) do
    if fini_rate[p] >= 0.8 * (target[p] or 0) then covered[p] = true end
    for _, kind in ipairs(T.OUTPOST_ORDER) do
      local spec = T.outposts[kind]
      if spec.product == p then cap[kind] = (cap[kind] or 0) + fini_rate[p] / (spec.drills * A.BURNER_RATE * 60) end
    end
  end
  Profiler.stop("ia3e:auto")
  return { modules = mods, cap = cap, covered = covered }
end

--- Ligne de la minute (lisibilité, critère 6) : charges et débits de la fenêtre, modules, verdicts et leurs raisons.
function Auto.minute_line(f, st, tick)
  local loads = {}
  for _, m in ipairs(A.METHODS) do
    local L, D, Lres, n = A.measure(st.window, m.product)
    loads[#loads + 1] = string.format("%s:%.2f/%.0f", m.product, L, D)
  end
  local mods = {}
  for _, m in ipairs(st.modules) do
    mods[#mods + 1] = string.format("%s#%d:%s(%d/%d)%s", m.product, m.id, m.state, m.built or 0, m.total or 0,
      m.reason and ("[" .. tostring(m.reason) .. "]") or "")
  end
  local vs = {}
  for _, v in ipairs(st.verdicts) do vs[#vs + 1] = v.product .. ":" .. v.verdict .. "(" .. tostring(v.why) .. ")" end
  local hand = {}
  for _, k in ipairs(sorted_keys(st.hand)) do hand[#hand + 1] = k .. "=" .. st.hand[k] end
  log(string.format("[FO-IA3E] %s minute %d | fenetre %d min | charge PNJ/debit {%s} | modules {%s} | verdicts {%s} | recherche voulue [%s] | main {%s}",
    f.key or "player", math.floor(minutes(f, tick) + 0.5), #st.window, table.concat(loads, " "), table.concat(mods, " "),
    table.concat(vs, " "), table.concat(sorted_keys(st.wanted), " "), table.concat(hand, " ")))
end

--- Objets que l'automatisation voudrait et que l'équipe ne sait pas fabriquer (crochet de la recherche).
function Auto.wanted(f)
  local st = f and f.team and f.team.ia3e
  return st and st.wanted or nil
end

Board.on_done = Auto.on_done

---------------------------------------------------------------------------------------------------
-- Interface distante de LECTURE (bancs)
---------------------------------------------------------------------------------------------------
local function team_of(key)
  if key == "player" then return State.faction("player") end
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and (f.key == key or id == key) then return f end
  end
  return nil
end

remote.add_interface("fo-ia3e", {
  status = function(key)
    local f = team_of(key)
    local st = f and f.team and f.team.ia3e
    if not st then return nil end
    local out = { modules = {}, verdicts = {}, wanted = sorted_keys(st.wanted), hand = {}, window = #st.window }
    for _, m in ipairs(st.modules) do
      local s = f.build and Build.status(f, m.id)
      out.modules[#out.modules + 1] = { id = m.id, product = m.product, state = m.state, reason = m.reason, requested = m.requested,
        finished = m.finished, rate = m.rate, rate_nom = m.rate_nom, built = m.built, total = m.total,
        parts = s and s.parts or {}, quais = s and s.quais or {} }
    end
    for _, v in ipairs(st.verdicts) do out.verdicts[#out.verdicts + 1] = { product = v.product, verdict = v.verdict, why = v.why, L = v.L, D = v.D, T = v.T } end
    for _, k in ipairs(sorted_keys(st.hand)) do out.hand[k] = st.hand[k] end
    out.hand_all = {}
    for _, k in ipairs(sorted_keys(st.hand_all)) do out.hand_all[k] = st.hand_all[k] end
    return out
  end,
})

return Auto
