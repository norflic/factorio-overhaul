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
  - Suivi (chaque pensée) : Build.brief de chaque demande (sans appel du moteur) ; le cerveau reçoit ctx.auto = { modules (état, manques,
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
Auto.FEED_STOCK = 200        -- objets au coffre du QG pour les quais d'un module fini (Build.QUAI_LOW déclenche le remplissage)
Auto.IDLE_OFF = true          -- plan directeur éteint quand tous ses projets sont refusés et qu'aucun module n'est fini
Auto.STARVE_HOLD = 15 * 3600 -- repli après une réserve affamée (× leur nombre)
Auto.RESERVE_MAX = 15 * 3600 -- une demande qui attend ses matériaux plus de 15 min est annulée (objets rendus au coffre) :
                             -- elle ne mange plus le fer de la recherche et de l'armée sans jamais produire (moteur réel,
                             -- e4-usine : réserves de 26 à 90 min, palier 3 jamais atteint chez 3 factions sur 4)

local function sorted_keys(t) return State.sorted_keys(t or {}) end

local function minutes(f, tick)
  local war = State.war()
  return (tick - (f.started or (war and war.started) or 0)) / 3600
end

--- Produit de chaque méthode, et minerai -> plaque (mesure du minage à la main).
local PRODUCTS = {}
local PLATES = {} -- produits des méthodes servies par des foreuses (plaques fondues)
for _, m in ipairs(A.METHODS) do
  PRODUCTS[m.product] = true
  if m.ore then PLATES[m.product] = true end
end
local PLATE_OF_RES = {}
for _, kind in ipairs(T.OUTPOST_ORDER) do
  local spec = T.outposts[kind]
  if T.smelter_inputs[spec.product] then PLATE_OF_RES[spec.resource] = spec.product end
end

-- Produit (nom, nombre) de chaque recette : mémoire LOCALE tirée des prototypes (mesure seulement).
local PRODUCT_AMOUNT = {}

Auto.SETTING = "fo-war-ia3e" -- réglage de carte (settings/ia3e.lua)
local function enabled(f)
  if not (f and f.team and f.team.ia3c and f.hq and f.hq.valid) then return false end
  if Auto.FACTIONS_ONLY and f.is_player then return false end
  local s = settings.global[Auto.SETTING]
  if s ~= nil and s.value == false then return false end
  return true
end

--- Lot AUTO : l'automatisation est-elle allumée pour les factions (réglage de carte ; absent : allumée, comme enabled) ?
function Auto.on()
  local s = settings.global[Auto.SETTING]
  return not (s ~= nil and s.value == false)
end

--- Lot AUTO : entités que l'exécutant de l'automatisation sait poser (déduites de ses gabarits, A.exec_entities).
function Auto.exec_entities() return A.exec_entities() end

--- Lot AUTO (correction après revue, H8) : ajoute à `exec` les exécutants de l'automatisation, recette par recette pour
--- ses machines de fabrication (A.add_executors ; `recipes` : relevé des recettes du catalogue).
function Auto.add_executors(exec, recipes) return A.add_executors(exec, recipes) end

local function state_of(f)
  local t = f.team
  t.ia3e = t.ia3e or { v = 1, window = {}, cur = nil, mods = {}, verdicts = {}, wanted = {}, hand = {}, logs = {},
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
    for _, m in ipairs(st.mods) do
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
    add(b.made, task.item, task.count or 0) -- débit d'un objet fabriqué : à la main (ici) + modules (mesurés, roll)
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
--- Production RÉELLE d'un module fini sur la dernière minute (lot IA3-e, moteur réel e2-usine : des modules finis sans
--- courant ne produisaient rien, mais retiraient les tournées de leurs avant-postes) : fours et assembleurs de ses
--- pièces dont la recette donne l'objet du module ; objets par minute.
local function measure_module(f, m)
  local surface = f.hq and f.hq.valid and f.hq.surface
  local s = surface and f.build and Build.brief(f, m.id)
  if not s then return 0 end
  local made = 0
  for _, pt in ipairs(s.parts or {}) do
    local area = { { pt.x, pt.y }, { pt.x + pt.w, pt.y + pt.h } }
    for _, e in ipairs(surface.find_entities_filtered({ area = area, force = f.force, type = { "furnace", "assembling-machine" } })) do
      local ok = e.type == "furnace"
      if not ok then
        local r = e.get_recipe and e.get_recipe() or nil
        ok = r ~= nil and r.name == m.product
      end
      if ok then made = made + (e.products_finished or 0) end
    end
  end
  local rate = m.made_prev and math.max(0, made - m.made_prev) or 0
  m.made_prev = made
  return rate
end

local function roll(f, st, tick)
  local m = math.floor(tick / 3600)
  if st.last_min == m then return end
  -- Production mesurée des modules finis (une lecture par minute et par module).
  for _, mod in ipairs(st.mods) do
    if mod.state == "fini" then mod.rate_meas = measure_module(f, mod) end
  end
  -- Débit d'une PLAQUE : sa production par les fours de la force (statistiques du moteur : avant-postes, fours du QG,
  -- modules) ; les livraisons au QG (f.team.delivered) comptaient aussi les plaques prises puis rapportées par les PNJ
  -- (moteur réel, e4-usine : scarlet « 537 plaques/min livrées », 82 fondues en 45 min) : module surdimensionné.
  -- Débit d'un objet FABRIQUÉ : fabrications à la main (fin de tâche) + production mesurée des modules finis.
  local force = game.forces[f.force]
  local stats = nil
  pcall(function() stats = force and force.item_production_statistics end)
  local produced = {}
  for _, item in ipairs(sorted_keys(PLATES)) do
    local n = nil
    if stats then pcall(function() n = stats.get_input_count(item) end) end
    produced[item] = n or ((f.team.delivered or {})[item] or 0) -- moteur simulé : sans statistiques, les livraisons
  end
  if st.last_min ~= nil then
    local cur = st.cur
    if not cur or cur.m ~= st.last_min then cur = { m = st.last_min, load = {}, made = {}, logi = {} } end
    for _, item in ipairs(sorted_keys(PLATES)) do
      local d = (produced[item] or 0) - (st.last_delivered[item] or 0)
      cur.made[item] = d > 0 and d or nil
    end
    for _, mod in ipairs(st.mods) do
      if mod.state == "fini" and not PLATES[mod.product] and (mod.rate_meas or 0) > 0 then
        cur.made[mod.product] = (cur.made[mod.product] or 0) + mod.rate_meas
      end
    end
    st.window[#st.window + 1] = cur
    while #st.window > A.WINDOW do table.remove(st.window, 1) end
    st.cur = nil
  end
  for _, item in ipairs(sorted_keys(PLATES)) do st.last_delivered[item] = produced[item] or 0 end
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

--- Lot AUTO : objets encore manquants d'une réserve (somme des manques de Build.brief).
local function missing_count(brief)
  local n = 0
  for _, m in ipairs((brief and brief.missing) or {}) do n = n + (m[2] or 0) end
  return n
end

--- Lot AUTO : minuteur d'une réserve, remis à zéro tant qu'elle AVANCE (un objet de plus réservé : la réserve prend au
--- coffre au fil de l'eau, Build.reserve). « Matériaux introuvables » veut dire Auto.RESERVE_MAX SANS progrès : la fonderie
--- d'emerald (e15-usine, graine 271828182) était annulée à 45 min alors que sa réserve avançait (plan à 30 min, replan à
--- 61, finie à 70,6 min). Rend le tick du dernier progrès.
local function reserve_clock(obj, since_key, left_key, brief, tick)
  local n = missing_count(brief)
  if obj[since_key] == nil or obj[left_key] == nil or n < obj[left_key] then
    obj[since_key], obj[left_key] = tick, n
  end
  return obj[since_key]
end

local function refresh(f, st, tick)
  -- Centrale (demandée AVANT le premier module électrique) : son état ; refusée, les modules électriques attendent que la
  -- raison change (signature).
  if st.plant_id and f.build then
    local ps = Build.brief(f, st.plant_id)
    local state = ps and ps.state or "refuse"
    if state == "bloque" and not (ps and ps.retry_at) then state = "refuse" end
    if state == "reserve" then
      reserve_clock(st, "plant_reserve_since", "plant_reserve_left", ps, tick)
      if tick - st.plant_reserve_since > Auto.RESERVE_MAX and Build.cancel(f, st.plant_id, "materiaux introuvables (15 min sans progres)") then
        state = "refuse"
        ps = Build.brief(f, st.plant_id)
      end
    else
      st.plant_reserve_since, st.plant_reserve_left = nil, nil
    end
    if state ~= st.plant_state then
      st.plant_state = state
      if state == "fini" then note(f, st, tick, "centrale FINIE")
      elseif state == "refuse" then
        st.plant_refused = { reason = tostring(ps and ps.reason or "projet perdu"), sig = st.sig }
        note(f, st, tick, "centrale REFUSEE par le plan directeur : " .. st.plant_refused.reason)
        -- Les modules électriques pas encore en chantier sont annulés : sans courant, ils ne produiraient rien.
        for _, m in ipairs(st.mods) do
          if m.electric and (m.state == "attente" or m.state == "plan" or m.state == "reserve") then
            Build.cancel(f, m.id, "pas de centrale")
          end
        end
      end
    end
    if state == "refuse" and st.plant_refused and st.plant_refused.sig ~= st.sig then
      -- contexte changé (rayon, époque de 30 min) : nouvel essai de la centrale à la prochaine demande électrique
      st.plant_id, st.plant_state, st.plant_refused = nil, nil, nil
    end
  end
  for _, m in ipairs(st.mods) do
    if m.state ~= "fini" and m.state ~= "refuse" then
      local s = Build.brief(f, m.id)
      if not s then
        m.state, m.reason = "refuse", "projet perdu"
      else
        local was = m.state
        local state = s.state
        if state == "bloque" and not s.retry_at then state, s.reason = "refuse", "abandon : " .. tostring(s.reason) end
        m.state, m.reason, m.missing = state, s.reason, s.missing or {}
        m.built, m.total = s.built or 0, s.total or 0
        if state == "reserve" then
          reserve_clock(m, "reserve_since", "reserve_left", s, tick)
          if tick - m.reserve_since > Auto.RESERVE_MAX and Build.cancel(f, m.id, "materiaux introuvables (15 min sans progres)") then
            state, m.state, m.reason = "refuse", "refuse", "materiaux introuvables (15 min sans progres)"
            -- Repli de l'équipe : plus de NOUVELLE demande pendant 15 min × le nombre de réserves affamées (moteur réel,
            -- e6 et e7-usine, amber : 4 réserves de 15 min en 70 min, la recherche des packs militaires arrêtée, palier 3
            -- jamais atteint contre 42 min au témoin).
            st.starved = (st.starved or 0) + 1
            st.hold_until = tick + Auto.STARVE_HOLD * st.starved
          end
        else
          m.reserve_since, m.reserve_left = nil, nil
        end
        if state ~= was then
          if state == "fini" then
            m.finished = tick
            m.finished_m = math.floor(tick / 3600)
            note(f, st, tick, string.format("module '%s' FINI (%d entites, %.0f objets/min nominal)", m.product, m.total, m.rate_nom or 0))
          elseif state == "refuse" then
            m.sig = st.sig
            note(f, st, tick, string.format("module '%s' REFUSE par le plan directeur : %s", m.product, tostring(m.reason)))
            -- Pas de rue jusqu'au réseau (rues fermées par l'eau, un nid, une force rivale) : la demande suivante de cet
            -- objet se pose PRÈS DE LA CENTRALE (moteur réel, e3-usine, emerald : centrale au coin du treillis, 10 refus).
            if tostring(m.reason):find("rue vers le reseau", 1, true) then
              st.near_plant = st.near_plant or {}
              st.near_plant[m.product] = (st.near_plant[m.product] or 0) + 1
              -- un seul nouvel essai près de la centrale (un plan coûte 25 à 40 ms) ; ensuite le refus vaut jusqu'au
              -- changement de contexte
              if st.near_plant[m.product] == 1 then m.sig = nil end
            end
          elseif state == "bloque" then
            note(f, st, tick, string.format("module '%s' bloque : %s", m.product, tostring(m.reason)))
          end
        end
      end
    end
  end
  -- Centrale refusée et plan directeur éteint : nouvel essai quand le contexte change (époque de 30 min).
  if not st.plant_id and st.plant_refused and st.plant_refused.sig ~= st.sig then st.plant_refused = nil end
  -- Plan directeur ÉTEINT quand il n'a plus rien à bâtir ni à servir (tous ses projets refusés, aucun module fini) : allumé,
  -- il fait marcher les PNJ par les rues et lit le terrain pour rien (moteur simulé, tests/ia3f_test.lua §6 après la
  -- fusion de main 0.5.0 : centrale refusée à 10 min, plan resté allumé, pétrole jamais trouvé contre 26 min sans lui).
  -- Rallumé à la prochaine demande.
  local b = f.build
  if b and Auto.IDLE_OFF then
    local busy = false
    for _, pid in ipairs(b.order or {}) do
      local p = b.projects[pid]
      if p and p.state ~= "refuse" then busy = true break end
    end
    if not busy then
      st.last_radius = b.radius
      f.build = nil
      st.plant_id, st.plant_state = nil, nil
      note(f, st, tick, "plan directeur eteint (rien a batir ni a servir)")
    end
  end
end

--- Contexte d'un refus : rayon du treillis (il grandit jusqu'à Build.RADIUS_MAX quand rien ne tient), époque de 30 min
--- (le terrain change : arbres défrichés, avant-postes, bâtiments). Les technologies n'y sont pas : une recherche ne
--- change pas la place (moteur simulé, sonde du 27/10 : un refus « place » redemandé à chaque technologie).
local function signature(f, tick, st)
  local b = f.build
  -- plan directeur éteint (rien à bâtir) : le rayon qu'il avait (sinon la signature changerait à l'extinction et tout
  -- refus serait redemandé à la minute suivante)
  return string.format("r%d:e%d", b and b.radius or (st and st.last_radius or 0), math.floor(tick / Auto.REFUSE_EPOCH))
end

---------------------------------------------------------------------------------------------------
-- Pensée
---------------------------------------------------------------------------------------------------
--- Appelé par le cerveau (Ia3.plan) avant la pensée pure. Rend ctx.auto (ou nil : automatisation éteinte).
--- Objets à peser (chaînes, triées) : étapes de la dernière décision de recherche (IA-G) et du coût de l'amélioration en
--- cours (lot CAPITAL) ; nil s'il n'y en a aucune.
--- Auto.capital_steps : posé au chargement par script/ai3/capital.lua (Capital.steps : nil quand fo-war-capital est éteint).
Auto.capital_steps = nil
function Auto.items_of(f)
  local a = f.team.iag and f.team.iag.steps
  local b = Auto.capital_steps and Auto.capital_steps(f) or nil
  if not (b and #b > 0) then return a end
  if not (a and #a > 0) then return b end
  local seen, out = {}, {}
  for _, k in ipairs(a) do if not seen[k] then seen[k] = true out[#out + 1] = k end end
  for _, k in ipairs(b) do if not seen[k] then seen[k] = true out[#out + 1] = k end end
  table.sort(out)
  return out
end

--- Lot CAPIB : crochet posé par script/ai3/capitalisation.lua (Capi.on) : vrai quand la capitalisation décide pour cette
--- faction (réglage fo-war-capi). A.decide continue de MESURER (fenêtre, verdicts, objets voulus par la recherche) mais
--- ses demandes ne sont plus envoyées : un seul décideur par levier (docs/IA_CAPITALISATION.md §5).
Auto.decide_off = function(f) return false end

--- Lot CAPIB : envoie une demande de module au plan directeur (centrale d'abord si le module est électrique), comme une
--- demande d'A.decide. rq = { product, gen, args, feed, rate, rate_nom, electric, gain, why, near, capi }. Rend l'id du
--- module (suivi dans f.team.ia3e.mods, champ capi = clé de l'ordre CAPI) ou nil, raison.
local function submit(f, st, tick, rq, research)
  -- Plan directeur allumé à la PREMIÈRE demande (une fois, sans « seul » : le cerveau garde ses tâches libres).
  if not f.build then
    Build.enable(f, { radius = Auto.RADIUS })
    note(f, st, tick, "plan directeur allume (rayon " .. Auto.RADIUS .. ")")
  end
  local prio = 40 + math.floor(A.VALUE * 45 / 100)
  -- Recherche ouverte que ce module ne sert pas : ses tâches passent après celles de la recherche (critère K1)
  if research and research.tech and not research.for_auto and not A.serves_research(research, rq.product) then
    prio = prio - 10
  end
  -- Centrale d'abord (correction e2-usine) : demandée APRÈS le module, elle ne trouvait plus de rue vers le réseau
  -- que le module avait amorcé seul (« pas de rue vers le reseau ») ; demandée avant, elle amorce le réseau et les
  -- modules s'y relient (ordre du banc ia1-build d'IA1-d).
  if rq.electric and not st.plant_id then
    st.plant_id = Build.plant(f)
    st.plant_state = "attente"
    note(f, st, tick, "centrale demandee (projet " .. tostring(st.plant_id) .. ") avant le premier module electrique")
  end
  local spec = { gen = rq.gen, args = rq.args, feed = rq.feed, prio = prio, domain = "production", near = rq.near }
  if not spec.near and rq.electric and st.near_plant and st.near_plant[rq.product] and st.plant_id then
    local ps = Build.brief(f, st.plant_id)
    local pt = ps and ps.parts and ps.parts[1]
    if pt then spec.near = { x = pt.x + pt.w / 2, y = pt.y + pt.h / 2 } end
  end
  local id, why = Build.request(f, spec)
  if id then
    st.mods[#st.mods + 1] = { id = id, product = rq.product, state = "attente", requested = tick,
      rate = rq.rate, rate_nom = rq.rate_nom, gen = rq.gen, args = rq.args, missing = {}, electric = rq.electric or nil,
      gain = rq.gain, capi = rq.capi }
    if rq.electric then st.plant_gain = math.max(st.plant_gain or 0, rq.gain or 0) end
    note(f, st, tick, string.format("module '%s' DEMANDE%s (%s %s, %.0f objets/min visés, nominal %.0f) : %s", rq.product,
      rq.capi and (" par CAPI [" .. rq.capi .. "]") or "", rq.gen,
      table.concat((function()
        local o = {}
        for i, a in ipairs(rq.args) do o[i] = type(a) == "table" and ("recette " .. tostring(a.name)) or tostring(a) end
        return o
      end)(), ","),
      rq.rate or 0, rq.rate_nom or 0, tostring(rq.why)))
    return id
  end
  note(f, st, tick, string.format("module '%s' : demande impossible (%s)", rq.product, tostring(why)))
  return nil, why
end

function Auto.submit(f, rq, tick, research)
  if not enabled(f) then return nil, "automatisation eteinte" end
  return submit(f, state_of(f), tick, rq, research)
end

--- Lot CAPIB : le module `id` suivi par l'automatisation (état, manques, raison, construits) ou nil.
function Auto.module(f, id)
  local st = f and f.team and f.team.ia3e
  if not st then return nil end
  for _, m in ipairs(st.mods) do if m.id == id then return m end end
  return nil
end

--- Lot CAPIB : état de la centrale ("fini", "refuse", ... ; nil sans centrale demandée) et sa raison de refus.
function Auto.plant_state(f)
  local st = f and f.team and f.team.ia3e
  if not st then return nil end
  return st.plant_state, st.plant_refused and st.plant_refused.reason or nil
end

function Auto.think(f, view, book, tick, research)
  if not enabled(f) then return nil end
  Profiler.start("ia3e:auto")
  local st = state_of(f)
  roll(f, st, tick)
  st.sig = signature(f, tick, st)
  refresh(f, st, tick)
  if tick >= (st.next_decide or 0) then
    st.next_decide = tick + Auto.EVERY
    local stock = view.stock or {}
    local res = A.decide({
      window = st.window, threatened = view.threatened, mods = st.mods,
      obtainable = function(item) return book:handcraftable(item) or (stock[item] or 0) > 0 end,
      book = book, stock = stock, sig = st.sig,
      has_plant = st.plant_id ~= nil and st.plant_state ~= "refuse",
      no_power = st.plant_refused and st.plant_refused.reason or nil,
      -- objets du dépliage du cerveau général (IA-G : étapes hand, produce, extract de la dernière décision)
      -- lot CAPITAL : et ceux du dépliage du coût de l'amélioration en cours (f.team.capital.steps)
      items = Auto.items_of(f),
      hold = (tick < (st.hold_until or 0)) and string.format("repli jusqu'a %.0f min (%d reserve(s) affamee(s))",
        (st.hold_until or 0) / 3600, st.starved or 0) or nil,
    })
    st.wanted = res.wanted
    st.verdicts = {}
    for _, v in ipairs(res.verdicts) do
      st.verdicts[#st.verdicts + 1] = { product = v.product, verdict = v.verdict, why = v.why, L = v.L, D = v.D, T = v.T,
        depth = v.depth, generic = v.generic }
    end
    -- Lot CAPIB : sous la capitalisation, A.decide mesure (verdicts, objets voulus) mais ne demande plus rien.
    if not Auto.decide_off(f) then
      for _, rq in ipairs(res.requests) do submit(f, st, tick, rq, research) end
    end
    Auto.minute_line(f, st, tick)
  end
  -- Contexte du cerveau.
  local mods, cap, covered = {}, {}, {}
  local fini_rate, target = {}, {}
  -- La centrale est un PROJET du cerveau comme un module (lot IA3-e, e3-usine : demandée seule au plan directeur, sa
  -- réserve « materiaux » attendait 64 min, personne ne fabriquait ses chaudière et machines à vapeur), avec la valeur
  -- du module électrique qui l'attend.
  if st.plant_id and st.plant_state ~= "fini" and st.plant_state ~= "refuse" then
    local ps = Build.brief(f, st.plant_id)
    if ps then
      mods[#mods + 1] = { product = "centrale", state = ps.state, missing = ps.missing or {}, reason = ps.reason, gain = st.plant_gain }
    end
  end
  local feeds = {}
  local stock = view.stock or {}
  for _, m in ipairs(st.mods) do
    -- Lot CAPIB : un module demandé par la capitalisation est un projet « capi » du cerveau (but de fond), pas « auto ».
    if not m.capi then
      mods[#mods + 1] = { product = m.product, state = m.state, missing = m.missing, reason = m.reason, gain = m.gain }
    end
    if m.state == "fini" and f.build then
      -- Objets de ses quais d'entrée qui manquent au coffre : fabriqués ou fondus pour lui (pas les minerais ni le
      -- charbon : avant-postes ; un quai de minerai est un défaut du plan, la fonderie se dimensionne pour le tapis).
      local s = Build.brief(f, m.id)
      local items = {}
      for _, it in ipairs(s and s.quais or {}) do
        local makeable = (book and book.handcraftable and book:handcraftable(it)) or T.smelter_inputs[it] ~= nil
        local have = stock[it] or 0
        if makeable and have < Auto.FEED_STOCK then items[#items + 1] = { it, Auto.FEED_STOCK - have } end
      end
      if #items > 0 then feeds[#feeds + 1] = { product = m.product, id = m.id, items = items, gain = m.gain } end
    end
    if m.state == "fini" then
      -- débit MESURÉ (la minute écoulée), pas le nominal : un module sans courant ne couvre rien
      fini_rate[m.product] = (fini_rate[m.product] or 0) + (m.rate_meas or 0)
      target[m.product] = math.max(target[m.product] or 0, m.rate or 0)
    end
  end
  for _, p in ipairs(sorted_keys(fini_rate)) do
    if fini_rate[p] >= 0.5 * (target[p] or 0) and fini_rate[p] > 0 then covered[p] = true end
    for _, kind in ipairs(T.OUTPOST_ORDER) do
      local spec = T.outposts[kind]
      if spec.product == p then cap[kind] = (cap[kind] or 0) + fini_rate[p] / (spec.drills * A.BURNER_RATE * 60) end
    end
  end
  Profiler.stop("ia3e:auto")
  return { mods = mods, cap = cap, covered = covered, feeds = feeds }
end

--- Ligne de la minute (lisibilité, critère 6) : charges et débits de la fenêtre, modules, verdicts et leurs raisons.
function Auto.minute_line(f, st, tick)
  -- objets pesés à la dernière pensée (gabarits écrits et tout objet chargé à la main : consigne du DC du 27/10), par
  -- profondeur du graphe des recettes
  local loads = {}
  for _, v in ipairs(st.verdicts) do
    loads[#loads + 1] = string.format("%s:%.2f/%.0f", v.product, v.L or 0, v.D or 0)
  end
  local mods = {}
  for _, m in ipairs(st.mods) do
    -- les 3 premiers objets qui manquent au chantier (lisibilité : pourquoi une réserve attend)
    local miss = ""
    if m.state == "reserve" and m.missing and #m.missing > 0 then
      local parts = {}
      for i = 1, math.min(3, #m.missing) do parts[i] = m.missing[i][1] .. "x" .. m.missing[i][2] end
      miss = "<" .. table.concat(parts, ",") .. ">"
    end
    mods[#mods + 1] = string.format("%s#%d:%s(%d/%d)%s%s%s", m.product, m.id, m.state, m.built or 0, m.total or 0,
      m.state == "fini" and string.format("=%d/min", m.rate_meas or 0) or "",
      m.reason and ("[" .. tostring(m.reason) .. "]") or "", miss)
  end
  if st.plant_id then mods[#mods + 1] = "centrale#" .. st.plant_id .. ":" .. tostring(st.plant_state) end
  local vs = {}
  for _, v in ipairs(st.verdicts) do
    vs[#vs + 1] = v.product .. ":" .. v.verdict .. (v.generic and "*" or "") .. "(d" .. tostring(v.depth or 0) .. ", " .. tostring(v.why) .. ")"
  end
  local hand = {}
  for _, k in ipairs(sorted_keys(st.hand)) do hand[#hand + 1] = k .. "=" .. st.hand[k] end
  log(string.format("[FO-IA3E] %s minute %d | fenetre %d min | charge PNJ/debit {%s} | modules {%s} | verdicts {%s} | recherche voulue [%s] | main {%s}",
    f.key or "player", math.floor(minutes(f, tick) + 0.5), #st.window, table.concat(loads, " "), table.concat(mods, " "),
    table.concat(vs, " "), table.concat(sorted_keys(st.wanted), " "), table.concat(hand, " ")))
end

--- Objets que l'automatisation voudrait et que l'équipe ne sait pas fabriquer (crochet de la recherche).
--- Lot CAPIB : plus ceux que les exécutants de la capitalisation attendent (Auto.want ; nil réglage éteint).
function Auto.wanted(f)
  local st = f and f.team and f.team.ia3e
  if not st then return nil end
  local cw = st.capi_wanted
  if cw and #cw > 0 then
    local m = {}
    for _, k in ipairs(sorted_keys(st.wanted)) do m[k] = st.wanted[k] end
    for _, k in ipairs(cw) do m[k] = true end
    return m
  end
  return st.wanted
end

--- Lot CAPIB : objets qu'un exécutant de la capitalisation attend (liste triée) ; la recherche qui les débloque prend de
--- la valeur (comme les objets voulus par A.decide).
function Auto.want(f, list)
  local st = f and f.team and f.team.ia3e
  if st then st.capi_wanted = (list and #list > 0) and list or nil end
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
    local out = { mods = {}, verdicts = {}, wanted = sorted_keys(st.wanted), hand = {}, window = #st.window,
      plant = st.plant_id, plant_state = st.plant_state }
    for _, m in ipairs(st.mods) do
      local s = f.build and Build.status(f, m.id)
      out.mods[#out.mods + 1] = { id = m.id, product = m.product, state = m.state, reason = m.reason, requested = m.requested,
        finished = m.finished, rate = m.rate, rate_nom = m.rate_nom, rate_meas = m.rate_meas, built = m.built, total = m.total,
        parts = s and s.parts or {}, quais = s and s.quais or {} }
    end
    for _, v in ipairs(st.verdicts) do out.verdicts[#out.verdicts + 1] = { product = v.product, verdict = v.verdict, why = v.why, L = v.L, D = v.D, T = v.T, depth = v.depth, generic = v.generic } end
    for _, k in ipairs(sorted_keys(st.hand)) do out.hand[k] = st.hand[k] end
    out.hand_all = {}
    for _, k in ipairs(sorted_keys(st.hand_all)) do out.hand_all[k] = st.hand_all[k] end
    return out
  end,
})

return Auto
