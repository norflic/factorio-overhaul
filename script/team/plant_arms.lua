--[[
  Lot PLANDIR : moniteur de la centrale à vapeur d'une équipe (journal seulement, rien n'est modifié).

  Décision du 28/10 (lead, après mesures en moteur réel) : les bras qui nourrissent les chaudières RESTENT à combustion. Un bras
  électrique sur une chaudière est un blackout en attente : au moindre creux (démarrage, charge au-delà de la production, coffre de
  charbon vide un instant), le bras s'arrête faute de courant, la chaudière s'éteint et la centrale ne repart jamais. Passés à
  l'électrique, les bras de la centrale la tuaient en 1,5 à 3,5 min dans 6 cas sur 6 (archives 2026-10-28_PLANDIR). Un bras à
  combustion se recharge seul avec le charbon qu'il déplace. Ce qui manque est le charbon du quai (mesuré : coffre à 0, 123456789, 32,7 min) : lot quai-charge, branche quai-charge.
]]
local M = require("shared.team.modules")
require("script.team.centrale_mort") -- lot INSTRUMENT-CENTRALE : journal de la mort des pièces de centrale (abonnement au bus)
local T = require("shared.team.config")
local Stock = require("script.team.stock")
local Bras = require("shared.team.bras_retour")
local C = require("shared.team.centrale") -- lot CORR-ENERGIE : croissance de la centrale
local Cv = require("shared.team.champ_vapeur") -- lot ENERGIE : champ de machines à vapeur (taille, perte)
local Cp = require("shared.team.centrale_pole") -- lot CENTRALE-PRES : poteau obtenable, taille de la centrale
local Sante = require("script.team.sante_centrale") -- lot ENERGIE (2/11) : santé de la centrale, amorce à la main, croissance avant saturation

local PA = {}

local function real_of(surface, e, force)
  local found = surface.find_entity(e.name, { e.x, e.y })
  if found and found.valid and found.force.name == force then return found end
  return nil
end

local STATUS_NAME = nil
local function status_name(r)
  if not STATUS_NAME then
    STATUS_NAME = {}
    for k, v in pairs(defines.entity_status) do STATUS_NAME[v] = k end
  end
  local st = r.status
  return st and STATUS_NAME[st] or "?"
end

--- Diagnostic d'une centrale sans courant (journal, 8 lignes au plus par équipe, à chaque nouvelle panne) : charbon des coffres de quai, combustible et
--- vapeur des chaudières, statut des bras. Lecture seule.
local function snapshot(f, surface, p, st, tag, tick)
  st.snaps = (st.snaps or 0) + 1
  if st.snaps > 8 then return end
  local parts = {}
  for _, q in ipairs(p.quais or {}) do
    local c = surface.find_entities_filtered({ position = { q.x, q.y }, radius = 0.4, type = "container", force = f.force, limit = 1 })[1]
    parts[#parts + 1] = string.format("coffre(%s)=%d", tostring(q.item), c and c.get_item_count(q.item) or -1)
  end
  for _, e in ipairs(p.ents) do
    if (M.spec(e.name) or {}).water ~= nil then
      local r = real_of(surface, e, f.force)
      if r then
        local inv = r.get_fuel_inventory()
        local fb = r.fluidbox
        local steam = 0
        for i = 1, #fb do local fl = fb[i]; if fl and fl.name == "steam" then steam = steam + fl.amount end end
        parts[#parts + 1] = string.format("chaudiere combustible=%d vapeur=%.0f statut=%s", inv and inv.get_item_count() or -1, steam, status_name(r))
      end
    elseif (M.spec(e.name) or {}).power_out ~= nil then
      local r = real_of(surface, e, f.force)
      if r then parts[#parts + 1] = string.format("machine statut=%s", status_name(r)) end
    elseif e.was_burner or e.name == M.BURNER_ARM then
      local r = real_of(surface, e, f.force)
      if r then parts[#parts + 1] = string.format("bras %s/%s statut=%s", e.name, tostring(e.role), status_name(r)) end
    end
  end
  log(string.format("[FO-PLANDIR] %s : centrale, diagnostic (%s) a %.1f min : %s", f.key or "player", tag, tick / 3600,
    table.concat(parts, " ; ")))
end

--- Remplace sur place le bras réel `real` par `name` ; rend la nouvelle entité ou nil.
local function swap(surface, real, name, force)
  return surface.create_entity({ name = name, position = real.position, direction = real.direction, force = force,
    fast_replace = true, spill = false, raise_built = true })
end

--- Migration (versions 0.6.5 à 0.6.7 : bras de centrale passés à l'électrique) : les bras marqués `was_burner` repassent à
--- combustion, avec du combustible du coffre (règle pure : shared/team/bras_retour.lua). Repris à chaque relevé tant qu'il en
--- reste (bras réel introuvable, pas de place). Rend le nombre de bras repassés.
local function restore(f, surface, p, tick)
  local todo = Bras.to_restore(p.ents, M.BURNER_ARM)
  if #todo == 0 then return 0 end
  local done = 0
  for _, i in ipairs(todo) do
    local e = p.ents[i]
    local r = real_of(surface, e, f.force)
    if r then
      local new = swap(surface, r, M.BURNER_ARM, f.force)
      if new and new.valid then
        local fuel = new.get_fuel_inventory()
        if fuel and Stock.count(f, T.fuel) >= T.fuel_per_burner then
          fuel.insert({ name = T.fuel, count = Stock.remove(f, T.fuel, T.fuel_per_burner) })
        end
        Bras.restored(e, M.BURNER_ARM)
        done = done + 1
      end
    end
  end
  log(string.format("[FO-PLANDIR] %s : centrale, %d bras electrique(s) remis a la combustion (%d a remettre) a %.1f min",
    f.key or "player", done, #todo, tick / 3600))
  return done
end

--- Banc seulement (remote fo-ia1d) : reproduit la conversion des versions 0.6.5 à 0.6.7 (bras de la centrale passés au bras
--- électrique le plus lent de portée 1, entrée marquée `was_burner`), pour prouver la migration. Rend le nombre de bras convertis.
function PA.legacy_electric(f, surface)
  local b = f.build
  local p = b and b.plant and b.projects[b.plant]
  if not (p and p.state == "fini") then return 0 end
  local name = M.ELECTRIC_ARM
  local done = 0
  for _, e in ipairs(p.ents) do
    if e.name == M.BURNER_ARM then
      local r = real_of(surface, e, f.force)
      local new = r and swap(surface, r, name, f.force)
      if new and new.valid then e.name, e.item, e.was_burner = name, name, true; done = done + 1 end
    end
  end
  return done
end

--- Relevé de la centrale (projet `p` fini), toutes les 5 s : premier courant et pannes (journal).
PA.EVERY = 300
function PA.step(f, surface, p, tick)
  local b = f.build
  b.plant_watch = b.plant_watch or { snaps = 0 }
  local st = b.plant_watch
  if tick < (st.next or 0) then return end
  st.next = tick + PA.EVERY
  restore(f, surface, p, tick)
  local power, dry = 0, false
  for _, e in ipairs(p.ents) do
    local sp = M.spec(e.name) or {}
    if sp.power_out then
      local r = real_of(surface, e, f.force)
      if r then power = power + (r.energy_generated_last_tick or 0) end
    elseif sp.water then
      local r = real_of(surface, e, f.force)
      if r then
        local inv = r.get_fuel_inventory()
        if inv and inv.is_empty() and ((r.burner and r.burner.remaining_burning_fuel) or 0) <= 0 then dry = true end
      end
    end
  end
  if power > 0 and not st.first_power then
    st.first_power = tick
    log(string.format("[FO-PLANDIR] %s : centrale, 1er courant a %.1f min (puissance %.0f J/tick)", f.key or "player", tick / 3600, power))
  end
  if st.first_power and power <= 0 and dry and not st.was_dry then
    snapshot(f, surface, p, st, "centrale a sec", tick)
  end
  st.was_dry = dry and power <= 0
end

--- Lot CORR-ENERGIE : relevé de TOUTES les centrales à vapeur de l'équipe, toutes les 5 s (indépendant du moniteur ci-dessus) :
--- production et capacité des machines à vapeur bâties, projets de centrale finis, ouverts et refusés. Rend le nombre de
--- chaudières de la centrale à demander (règle pure shared/team/centrale.lua) ou nil, puis la liste des centrales de plus à abandonner
--- (réserve de matériaux incomplète depuis trop longtemps) ; la demande est faite par Build.grow_plant, l'abandon par Build.cancel.
PA.WATCH_EVERY = 300
PA.LOG_EVERY = 5 * 3600 -- lot ENERGIE-CROISSANCE : bilan [FO-ENERGIE] toutes les 5 min
function PA.watch(f, surface, tick)
  local b = f.build
  b.grow = b.grow or { sat = 0 }
  local g = b.grow
  if tick < (g.next or 0) then return nil end
  g.next = tick + PA.WATCH_EVERY
  local power, capacity, done, pending = 0, 0, 0, 0
  local pending_kw = 0 -- lot ELECTRIQUE (e) : kW nominaux des machines des chantiers ouverts (C.parallel_kw)
  local planned, boilers_alive, boiler_kw = 0, 0, nil -- lot ENERGIE : capacité prévue (vivante ou non), chaudières vivantes
  local reopened_alive, rebuilding = 0, 0 -- lot ENERGIE (relecture) : centrales déjà finies, rouvertes par la reconstruction
  local reopened_power, new_kw = 0, 0 -- lot CC-ENERGIE (F491) : production des machines vivantes rouvertes ; kW nominaux des centrales NEUVES en chantier
  -- les projets de centrale : la première (b.plant) et celles demandées par la croissance (b.extra_plants)
  -- (revue globale 1 : un projet de croissance devenu LA centrale quand la première a été refusée ou annulée ne se compte qu'une fois)
  local ids, seen = {}, {}
  if b.plant then ids[1] = b.plant; seen[b.plant] = true end
  for _, id in ipairs(b.extra_plants or {}) do
    if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
  end
  local plants = {}
  for _, pid in ipairs(ids) do
    local p = b.projects[pid]
    if p then
      plants[#plants + 1] = p
      -- lot ENERGIE (2/11) : santé de la centrale posée (chaudières à sec -> amorce à la main, pièces manquantes, temps sans courant)
      if p.state == "fini" or (p.reopened and p.finished) then Sante.observe(f, surface, p, tick) end
      if p.state == "fini" then
        done = done + 1
        for _, e in ipairs(p.ents) do
          local sp = M.spec(e.name) or {}
          if sp.power_out then
            planned = planned + sp.power_out * 1000 / 60
            -- la capacité ne compte que les machines VIVES : une centrale détruite ne cache pas la saturation des autres
            local r = real_of(surface, e, f.force)
            if r then
              capacity = capacity + M.spec(e.name).power_out * 1000 / 60
              power = power + (r.energy_generated_last_tick or 0)
            end
          elseif sp.water and sp.burner_kw then -- chaudière (lot ENERGIE : taille du champ de plus)
            boiler_kw = boiler_kw or sp.burner_kw
            if real_of(surface, e, f.force) then boilers_alive = boilers_alive + 1 end
          end
        end
      else
        -- lot ENERGIE (relecture) : une machine détruite ROUVRE le projet (Sweep.reopen_pieces, en quelques secondes) : il n'est plus « fini »,
        -- et sans ce relevé sa capacité sortait du prévu : la perte ne se constatait jamais. Hors de `capacity` (saturation inchangée).
        local was_built = p.reopened and p.finished
        if was_built then
          for _, e in ipairs(p.ents) do
            local sp = M.spec(e.name) or {}
            if sp.power_out then
              planned = planned + sp.power_out * 1000 / 60
              local r = real_of(surface, e, f.force)
              if r then
                reopened_alive = reopened_alive + sp.power_out * 1000 / 60
                reopened_power = reopened_power + (r.energy_generated_last_tick or 0)
              end
            elseif sp.water and sp.burner_kw then
              boiler_kw = boiler_kw or sp.burner_kw
              if real_of(surface, e, f.force) then boilers_alive = boilers_alive + 1 end
            end
          end
        end
        if p.state ~= "refuse" and not (p.state == "bloque" and not p.retry_at) then
          pending = pending + 1 -- (un chantier bloqué sans reprise prévue est abandonné : il compte plus bas comme un refus)
          local pk = 0
          for _, e in ipairs(p.ents or {}) do
            local sp = M.spec(e.name) or {}
            if sp.power_out then pk = pk + sp.power_out end
          end
          -- chantier sans machine connue (plan pas encore posé) : capacité inconnue, aucun chantier en parallèle (C.parallel_kw)
          if pk > 0 and pending_kw then pending_kw = pending_kw + pk else pending_kw = nil end
          if was_built then rebuilding = rebuilding + 1 else new_kw = new_kw + pk end
        end
      end
    end
  end
  g.done, g.pending, g.capacity, g.power = done, pending, capacity, power
  local was = g.saturated
  C.observe(g, power, capacity)
  if g.saturated and not was then
    log(string.format("[FO-ENERGIE] %s : centrale saturee a %.1f min (%.0f J/tick sur %.0f, %d centrale(s) finie(s), %d en projet)",
      f.key or "player", tick / 3600, power, capacity, done, pending))
  end
  local refused, stale = 0, {}
  for _, id in ipairs(b.extra_plants or {}) do
    local p = b.projects[id]
    if p and ((p.state == "refuse" and p.reason ~= C.STALE_REASON) or (p.state == "bloque" and not p.retry_at)) then refused = refused + 1 end
    if p and C.stale(p.state, p.reason, tick - (p.started or tick)) then stale[#stale + 1] = id end
  end
  g.refused = refused
  if #stale > 0 then g.cool_until = tick + C.COOL end
  -- lot ENERGIE-CROISSANCE : un refus du plan n'est plus définitif, il ouvre une pause de C.COOL puis la croissance réessaie
  if C.after_refusal(g, refused, tick) then
    log(string.format("[FO-ENERGIE] %s : centrale de plus refusee par le plan (%d refus sur %d permis) : nouvel essai a %.1f min",
      f.key or "player", refused, C.MAX_REFUSED, (g.cool_until or tick) / 3600))
  end
  local hold = tick < (b.grow_hold_until or 0)
  -- lot ENERGIE : perte (machines détruites non revenues depuis 10 min) et taille du champ (chaudières vivantes, voie de tapis)
  local lost = Cv.lost(g, planned, capacity + reopened_alive)
  -- lot ENERGIE (2/11) : la centrale de plus part AVANT la saturation (production + chantiers + modules retenus), et une reconstruction sans
  -- progrès depuis Sante.STALL ne retient plus la croissance (Ambre : 23 min saturée à 100 % pendant que 13 pièces sur 28 attendaient du fer)
  local anticipate, stalled, used_kw, committed_kw, cap_kw, deficit_kw, elec_kw = Sante.growth(f, tick, plants, power, capacity + reopened_alive)
  C.deficit_track(g, (deficit_kw or 0) > 0) -- lot TV-ENERGIE (diagnostic azure) : déficit de kW avec épargne qui dort, suivi de relevé en relevé
  -- lot TV-ENERGIE (G65) : crise d'énergie (centrale perdue, ou saturation qui dure pendant le repli) = UNITÉ DE SECOURS, jamais le champ ;
  -- le compte des secours d'une crise repart de zéro quand la capacité est revenue
  local crisis, crisis_why = C.crisis(g, { lost = lost, hold = hold })
  if not crisis and pending == 0 and not Cv.down(planned, capacity + reopened_alive) and not g.saturated then g.secours_n = 0 end
  local ns = 0
  for _, id in ipairs(stalled) do
    local q = b.projects[id]
    if q and q.state ~= "refuse" and not (q.state == "bloque" and not q.retry_at) then ns = ns + 1 end
  end
  -- lot CC-ENERGIE (F491) : demande MESURÉE sur la capacité bâtie vivante + celle des centrales neuves en chantier (C.grow_load)
  local gate = C.grow_load(power + reopened_power, capacity + reopened_alive, new_kw * 1000 / 60)
  local nb, why = C.growth(g, { load = gate, done = done, pending = pending - ns, rebuilding = math.max(0, rebuilding - ns), refused = refused, hold = hold,
    cool = tick < (g.cool_until or 0), off = b.opts and b.opts.no_grow == true, lost = lost, built = boilers_alive,
    engaged_kw = used_kw and (used_kw + Sante.committed(f) + Sante.held(f)) or nil, cap_kw = cap_kw, -- lot P0-CENTRALE
    anticipate = anticipate, secours_n = g.secours_n, deficit_kw = deficit_kw, boiler_kw = boiler_kw, pending_kw = pending_kw,
    lane_cap = Cv.lane_cap(M.BELT_RATE, boiler_kw, M.COAL_J) })
  if why == C.LOAD_REASON and not g.load_held then
    log(string.format("[FO-ENERGIE] %s : croissance RETENUE a %.1f min : demande mesuree %.0f kW sur %.0f kW batis vivants et %.0f kW en chantier (%.0f %%, seuil %.0f %%) ; declencheur ecarte : %s",
      f.key or "player", tick / 3600, (power + reopened_power) * 60 / 1000, (capacity + reopened_alive) * 60 / 1000, new_kw, (gate or 0) * 100,
      C.GROW_LOAD * 100, lost and "perte" or g.saturated and "saturation" or anticipate and "avance" or ((deficit_kw or 0) > 0) and ("deficit " .. string.format("%.0f", deficit_kw) .. " kW") or "?"))
  end
  g.load_held = (why == C.LOAD_REASON) or nil
  if nb and crisis then
    g.secours_n = (g.secours_n or 0) + 1
    log(string.format("[FO-ENERGIE] %s : UNITE DE SECOURS demandee a %.1f min (crise : %s ; capacite vivante %.0f sur %.0f J/tick prevus, saturee depuis %d relevés ; secours %d sur %d) : %d chaudiere(s), projet distinct, aucun champ en crise",
      f.key or "player", tick / 3600, crisis_why == "perte" and "centrale perdue" or "saturation pendant le repli de l'equipe",
      capacity + reopened_alive, planned, g.sat or 0, g.secours_n, C.SECOURS_MAX, nb))
  end
  if nb and not crisis and not lost and pending > 0 then -- lot ELECTRIQUE (e) : chantier en parallèle
    log(string.format("[FO-ENERGIE] %s : centrale EN PARALLELE a %.1f min : deficit %.0f kW (capitalisation %.0f, electrique %.0f) au-dela des %d chantier(s) ouvert(s) (%.0f kW) : centrale de %d chaudiere(s)",
      f.key or "player", tick / 3600, deficit_kw or 0, (deficit_kw or 0) - (elec_kw or 0), elec_kw or 0, pending, pending_kw or 0, nb))
  elseif nb and not crisis and not anticipate and not g.saturated and (deficit_kw or 0) > 0 then
    log(string.format("[FO-ENERGIE] %s : DEFICIT de kW a %.1f min : %.0f kW retenus faute de courant (capitalisation avec de l'epargne qui dort %.0f, electriques prevues %.0f) (capacite %.0f kW, vue de la porte %.0f kW) : centrale de %d chaudiere(s) demandee tout de suite (sans attendre la saturation ni l'avance)",
      f.key or "player", tick / 3600, deficit_kw, deficit_kw - (elec_kw or 0), elec_kw or 0, cap_kw or 0, used_kw or 0, nb))
  end
  if nb and lost then
    log(Cv.line({ kind = "perte", team = f.key or "player", tick = tick, alive = capacity + reopened_alive, planned = planned, nb = nb }))
  elseif nb and not g.saturated and anticipate then
    log(Sante.line_avance(f, tick, used_kw, committed_kw, cap_kw))
    log(Cv.line({ kind = "champ", team = f.key or "player", tick = tick, nb = nb, built = boilers_alive, refused = refused, why = "avant la saturation" }))
  elseif nb then
    log(Cv.line({ kind = "champ", team = f.key or "player", tick = tick, nb = nb, built = boilers_alive, refused = refused }))
  end
  local load = C.load(power, capacity)
  if not nb and g.saturated and why ~= g.why then
    g.why = why
    log(string.format("[FO-ENERGIE] %s : decision : pas de centrale de plus a %.1f min : %s (production %.0f kW sur %.0f kW, %.0f %% ; saturee depuis %d s)",
      f.key or "player", tick / 3600, tostring(why), power * 60 / 1000, capacity * 60 / 1000, (load or 0) * 100, (g.sat or 0) * PA.WATCH_EVERY / 60))
  end
  -- bilan toutes les C.LOG_EVERY (aucune décision ne le lit) : production, capacité, charge (la demande, quand elle dépasse la
  -- capacité, ne se mesure pas : la centrale saturée produit sa capacité), centrales, dernière décision
  if capacity > 0 and tick >= (g.log_next or 0) then
    g.log_next = tick + PA.LOG_EVERY
    log(string.format("[FO-ENERGIE] %s : bilan a %.1f min : production %.0f kW, capacite %.0f kW, charge %.0f %% (%s), %d centrale(s) finie(s), %d en projet, %d refus, %d demande(s) ; decision : %s",
      f.key or "player", tick / 3600, power * 60 / 1000, capacity * 60 / 1000, (load or 0) * 100,
      g.saturated and "saturee : la demande atteint la production" or "marge", done, pending, refused, g.requests or 0,
      nb and ("centrale de " .. nb .. " chaudiere(s)") or tostring(why)))
  end
  if nb then C.requested(g); g.why = nil end
  return nb, stale, (nb ~= nil and crisis) or false
end

-- Lot CENTRALE-PRES : objets OBTENABLES et taille d'une centrale (règles pures : shared/team/centrale_pole.lua). Un objet est obtenable
-- quand il est au coffre, ou qu'aucune recette ne le produit (matière naturelle), ou qu'une recette qui le produit est ouverte à la
-- force. Index « objet -> recettes qui le produisent » lu une fois aux prototypes (donnée dérivée, pas de `global` : refait à chaque
-- chargement) ; les recettes sont parcourues par noms triés.
local PRODUCERS = nil
local function producers()
  if PRODUCERS then return PRODUCERS end
  local names = {}
  for name in pairs(game.recipe_prototypes) do names[#names + 1] = name end
  table.sort(names)
  local idx = {}
  for _, rn in ipairs(names) do
    for _, pr in ipairs(game.recipe_prototypes[rn].products or {}) do
      if pr.type ~= "fluid" then
        local l = idx[pr.name]
        if not l then l = {} idx[pr.name] = l end
        l[#l + 1] = rn
      end
    end
  end
  PRODUCERS = idx
  return idx
end

--- Vide l'index (tests, qui changent de recettes).
function PA.reset_producers() PRODUCERS = nil end

--- Cet objet peut-il encore venir ? (voir ci-dessus). `f` : l'équipe (coffre et force).
function PA.obtainable(f, name)
  if Stock.count(f, name) > 0 then return true end
  local list = producers()[name]
  if not list then return true end
  local force = game.forces[f.force]
  if not force then return true end
  for _, rn in ipairs(list) do
    local r = force.recipes[rn]
    if r and r.enabled then return true end
  end
  return false
end

--- Objets d'une réserve qu'aucune fabrication ne peut couvrir (liste triée), pour refuser tout de suite une réserve qui ne se lèvera jamais.
function PA.dead(f, missing)
  return Cp.dead(missing, function(name) return PA.obtainable(f, name) end)
end

--- Taille et poteau d'une centrale de `nb` chaudières du générateur `gen`, `pref` = poteau de la première centrale (nil : le défaut).
--- Rend (n, poteau, réduite) ou (nil, cause).
function PA.fit(f, gen, nb, pref)
  local poles = Cp.candidates(pref, M.DEFAULT_POLE, function(name) return PA.obtainable(f, name) end)
  return Cp.fit(nb, poles, function(pole, n) return Cp.valid(gen, pole, n) end)
end

--- Taille de la centrale à demander (appelé par Build.grow_plant avant Build.request) : rend (n, poteau) ou nil quand aucun poteau
--- obtenable ne tient une centrale, après une ligne [FO-ENERGIE] qui dit pourquoi ; un refus ouvre la pause de C.COOL (la demande
--- n'a pas eu lieu : elle ne compte pas parmi les C.MAX_REQUESTS) et ne compte pas comme refus du plan.
function PA.size(f, gen, nb, pref, tick, secours)
  local n, pole, reduced = PA.fit(f, gen, nb, pref) -- (refus : n nil, `pole` porte alors la CAUSE)
  local g = f.build.grow or {}
  f.build.grow = g
  if not n then
    g.cool_until = math.max(g.cool_until or 0, tick + C.COOL)
    g.requests = math.max(0, (g.requests or 0) - 1)
    g.size_refused = (g.size_refused or 0) + 1
    log(string.format("[FO-ENERGIE] %s : centrale de %d chaudiere(s) REFUSEE a %.1f min : %s (poteau prevu %s, defaut %s) ; aucune reserve ouverte, nouvel essai a %.1f min",
      f.key or "player", nb, tick / 3600, tostring(pole), tostring(pref or M.DEFAULT_POLE), M.DEFAULT_POLE, g.cool_until / 3600))
    return nil
  end
  if reduced or pole ~= (pref or M.DEFAULT_POLE) then
    log(string.format("[FO-ENERGIE] %s : centrale de %d chaudiere(s) demandee a %.1f min, %s avec le poteau %s (obtenable ; prevu %s, defaut %s%s)",
      f.key or "player", nb, tick / 3600, reduced and ("ramenee a " .. n) or "gardee", pole, tostring(pref or M.DEFAULT_POLE), M.DEFAULT_POLE,
      PA.obtainable(f, M.DEFAULT_POLE) and ", obtenable" or ", NON obtenable : recette fermee, rien au coffre"))
  end
  return n, pole
end

PA.STALE_REASON = C.STALE_REASON

return PA
