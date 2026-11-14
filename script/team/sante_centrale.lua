--[[
  Lot ENERGIE (centrale résiliente, retour du DC du 2/11 sur la 0.6.34, points 5 et 11) : EXÉCUTANT de la règle pure
  shared/team/sante_centrale.lua. Les chaînes déclencheur -> décision -> action -> effet :

  1. AMORCE À LA MAIN. Déclencheur : PA.watch (script/team/plant_arms.lua, toutes les 5 s) lit les pièces de chaque centrale (Sante.observe) ;
     des chaudières vivantes sans combustible ni flamme pendant S.DRY_CHECKS relevés de suite. Décision : S.prime (stock du QG, S.COOL).
     Action : une tâche « carry » de priorité S.PRIO (quai_tasks de script/team/build.lua -> Sante.tasks), portée par un PNJ qui prend le
     charbon au coffre du QG, marche jusqu'à la centrale et le verse dans les chaudières (Build.work, mode « amorce » -> Sante.work).
     Effet : les machines à vapeur repartent, les foreuses électriques de la centrale et les bras à combustion reprennent le charbon.
  2. CROISSANCE AVANT LA SATURATION. Déclencheur : PA.watch ; production + consommateurs en chantier + modules retenus >= S.ANTICIPATE de la
     capacité (Sante.growth). Décision : C.growth (shared/team/centrale.lua) reçoit `anticipate` ; une reconstruction sans progrès depuis
     S.STALL ne compte plus comme chantier ouvert. Action : Build.grow_plant (inchangé). Effet : la capacité grandit avant que les machines
     électriques manquent de courant.
  3. PORTE DES CONSOMMATEURS. Déclencheur : un projet électrique passe de « attente » à « plan » (advance, script/team/build.lua ->
     Sante.gate). Décision : S.admit (production + chantiers + ce module contre la capacité). Action : le projet reste en « attente »
     (raison « courant ») et sa puissance compte dans la demande de centrale de plus. Effet : aucun module ne s'ouvre au-delà de ce que la
     centrale produit ; après S.GATE_WAIT il passe quand même (jamais de blocage définitif).

  État : f.build.sante = { plants = { [id projet] = { dry_n, primed, prime, said, ... } }, stall, gate, held, dark, logs } (nombres, chaînes,
  tables simples ; rien d'autre dans global).
]]
local M = require("shared.team.modules")
local T = require("shared.team.config")
local Stock = require("script.team.stock")
local S = require("shared.team.sante_centrale")
local Sweep = require("script.team.rebuild_sweep") -- s43 : réouverture des pièces manquantes de la centrale (Sweep.reopen_pieces)

local Sante = {}

local JTICK_KW = 60 / 1000 -- J/tick -> kW

local function mem(f)
  local b = f.build
  b.sante = b.sante or {}
  local sm = b.sante
  sm.plants = sm.plants or {}
  sm.stall = sm.stall or {}
  sm.gate = sm.gate or {}
  sm.held = sm.held or {}
  sm.dark = sm.dark or 0
  sm.logs = sm.logs or 0
  return sm
end
Sante.mem = mem

--- Témoin des bancs : l'option `no_sante` (remote fo-ia1d set_option) coupe l'amorce, la porte et l'avance (le relevé et le journal restent).
function Sante.off(f)
  return f.build and f.build.opts and f.build.opts.no_sante == true
end

local function say(f, ev)
  local sm = mem(f)
  sm.logs = sm.logs + 1
  if sm.logs > S.LOGS then return end
  ev.team = f.key or "player"
  log(S.line(ev))
end

local function real_of(surface, e, force)
  local found = surface.find_entity(e.name, { e.x, e.y })
  if found and found.valid and found.force.name == force then return found end
  return nil
end

--- Chaudière réelle à sec : ni combustible dans son inventaire, ni flamme.
local function is_dry(r)
  local inv = r.get_fuel_inventory()
  if not (inv and inv.is_empty()) then return false end
  return ((r.burner and r.burner.remaining_burning_fuel) or 0) <= 0
end

--- Relevé d'une centrale (projet `p` fini ou rouvert), toutes les 5 s. Rend l'enregistrement { causes, dry, repair, production, capacity }.
function Sante.observe(f, surface, p, tick)
  local sm = mem(f)
  local st = sm.plants[p.id] or {}
  sm.plants[p.id] = st
  local c = { boilers = { want = 0, alive = 0, dry = 0 }, arms = { want = 0, alive = 0 }, belts = { want = 0, alive = 0 },
    engines = { want = 0, alive = 0 }, pumps = { want = 0, alive = 0 } }
  local prod_j, cap_j = 0, 0
  local first_dry
  local missing = {} -- s43 : pièces posées absentes du monde (S.to_reopen)
  for _, e in ipairs(p.ents or {}) do
    if not (e.dropped or e.gave_up) then
      local sp = M.spec(e.name) or {}
      local bucket
      if sp.water and sp.burner_kw then bucket = c.boilers
      elseif sp.power_out then bucket = c.engines
      elseif sp.kind == "offshore" then bucket = c.pumps
      elseif e.was_burner or e.name == M.BURNER_ARM then bucket = c.arms
      elseif sp.kind == "belt" then bucket = c.belts end
      if bucket then
        bucket.want = bucket.want + 1
        local r = real_of(surface, e, f.force)
        if not r and e.built then missing[#missing + 1] = e end
        if r then
          bucket.alive = bucket.alive + 1
          if bucket == c.boilers and is_dry(r) then
            bucket.dry = bucket.dry + 1
            first_dry = first_dry or e
          elseif bucket == c.engines then
            prod_j = prod_j + (r.energy_generated_last_tick or 0)
            cap_j = cap_j + sp.power_out * 1000 / 60
          end
        end
      end
    end
  end
  -- s43 scen-energie : une pièce manquante de la centrale est rouverte TOUT DE SUITE (la réparation suit la cause lue), par la même
  -- réouverture que le relevé de reconstruction (Sweep.reopen_pieces : fantôme, PNJ, coût pris au stock) ; mêmes gardes que lui
  if #missing > 0 and not Sante.off(f) then
    local sw = f.build and f.build.sweep
    local pieces = {}
    for i, e in ipairs(missing) do
      local hand = sw and sw.hand and sw.hand[string.format("%.1f,%.1f", e.x, e.y)] ~= nil
      local foe = surface.find_nearest_enemy({ position = { x = e.x, y = e.y }, max_distance = Sweep.ENEMY_R, force = f.force })
      pieces[i] = { built = e.built, item = e.item, alive = false, hand = hand, enemy = foe ~= nil }
    end
    local list, names = {}, {}
    for _, i in ipairs(S.to_reopen(pieces)) do
      list[#list + 1] = { e = missing[i] }
      names[#names + 1] = missing[i].name
    end
    if #list > 0 then
      Sweep.reopen_pieces(p, list, tick)
      say(f, { kind = "repare", plant = p.id, tick = tick, n = #list, what = table.concat(names, ", ") })
    end
  end
  -- coffre de quai (secours) : contenu lu au moteur
  local q = p.quais and p.quais[1]
  if q then
    local chest = surface.find_entities_filtered({ position = { q.x, q.y }, radius = 0.4, type = "container", force = f.force, limit = 1 })[1]
    if chest then c.chest = { n = chest.get_item_count(q.item), low = 60 } end
  end
  c.production, c.capacity = prod_j * JTICK_KW, cap_j * JTICK_KW
  local res = S.classify(c)
  res.production, res.capacity = c.production, c.capacity
  res.c = c
  -- temps SANS COURANT : une centrale posée dont toutes les chaudières vivantes sont à sec (ou toutes détruites)
  local dt = math.min(600, tick - (st.last or tick))
  st.last = tick
  if c.boilers.want > 0 and (c.boilers.alive == 0 or c.boilers.dry >= c.boilers.alive) then sm.dark = sm.dark + dt end
  -- amorce : chaudières à sec depuis S.DRY_CHECKS relevés
  if Sante.off(f) then
    st.prime = nil
  elseif S.confirm(st, c.boilers.dry) then
    local stock = Stock.count(f, T.fuel)
    local pr, why = S.prime(st, c.boilers.dry, stock, tick)
    if pr then
      st.prime = { count = pr.count, boilers = pr.boilers, total = pr.total, x = first_dry.x, y = first_dry.y }
      if st.said ~= "amorce" then
        st.said = "amorce"
        say(f, { kind = "amorce", plant = p.id, tick = tick, boilers = pr.boilers, count = pr.count, total = pr.total, stock = stock })
      end
    else
      st.prime = nil
      if why ~= "amorce recente" and st.said ~= "sans:" .. why then
        st.said = "sans:" .. why
        say(f, { kind = "sans-amorce", plant = p.id, tick = tick, dry = c.boilers.dry, why = why })
      end
    end
  else
    st.prime = nil
    if c.boilers.dry == 0 then st.said = nil end
  end
  -- journal : un état par changement de causes (et toutes les 10 min tant que la centrale est malade)
  local sig = table.concat(res.causes, "+")
  if sig ~= st.sig or (sig ~= "" and tick >= (st.next_say or 0)) then
    st.next_say = tick + 36000
    if sig ~= "" or st.sig ~= nil then
      say(f, { kind = "etat", plant = p.id, tick = tick, causes = res.causes, boilers_alive = c.boilers.alive, boilers_want = c.boilers.want,
        dry = c.boilers.dry, arms_alive = c.arms.alive, arms_want = c.arms.want, belts_alive = c.belts.alive, belts_want = c.belts.want,
        engines_alive = c.engines.alive, engines_want = c.engines.want, pumps_alive = c.pumps.alive, pumps_want = c.pumps.want,
        production = c.production, capacity = c.capacity })
    end
    st.sig = sig
  end
  return res
end

--- Tâche d'amorce d'une centrale (appelée par quai_tasks) : `anchor(x, y)` rend le point d'appui { x, y } près de la chaudière.
function Sante.tasks(f, p, out, anchor)
  local st = mem(f).plants[p.id]
  local pr = st and st.prime
  if not pr then return end
  local a = anchor(pr.x, pr.y)
  out[#out + 1] = {
    key = "ia1d:" .. p.id .. ":amorce", kind = "carry", prio = S.PRIO, no_rush = true, domain = "logistique", work = 40,
    items = { { T.fuel, pr.total } },
    ia1d = { pid = p.id, mode = "amorce", ax = a.x, ay = a.y },
  }
end

--- Exécution de la tâche par le PNJ arrivé près de la centrale (Build.work, mode « amorce ») : verse le charbon porté dans les chaudières
--- à sec. Rend "done" (même sans rien verser : le charbon porté retourne au coffre à la maison).
function Sante.work(f, p, surface, inv, tick)
  local sm = mem(f)
  local st = sm.plants[p.id] or {}
  sm.plants[p.id] = st
  local per = st.prime and st.prime.count or S.PRIME
  local put_total, nb = 0, 0
  for _, e in ipairs(p.ents or {}) do
    local sp = M.spec(e.name) or {}
    if sp.water and sp.burner_kw then
      local r = real_of(surface, e, f.force)
      if r and is_dry(r) then
        local have = inv.get_item_count(T.fuel)
        if have <= 0 then break end
        local put = r.get_fuel_inventory().insert({ name = T.fuel, count = math.min(per, have) })
        if put > 0 then
          inv.remove({ name = T.fuel, count = put })
          put_total, nb = put_total + put, nb + 1
        end
      end
    end
  end
  st.prime = nil
  if put_total > 0 then
    st.primed, st.dry_n, st.said = tick, 0, nil
    say(f, { kind = "amorce-faite", plant = p.id, tick = tick, put = put_total, boilers = nb })
  end
  return "done"
end

--- Lot COURANT2 (revue du 3/11, défaut 1) : un SITE (spec.site : bande de champ, pompes, fonderie au gisement) échappe à la porte (admis sans
--- calcul) et n'a pas de gabarit (template_of rend nil) : sa puissance nominale est la somme de ses entités planifiées, notée au plan.
function Sante.site_kw(p)
  local kw = 0
  for _, e in ipairs(p.ents or {}) do kw = kw + M.power_kw(e.name) end
  return kw
end

-- Un site ne pèse sur la centrale qu'à partir du moment où ses fantômes se posent : en « reserve » (matières, jusqu'à 90 min) il ne
-- consomme rien et ferait demander une centrale trop tôt.
local SITE_COMMIT_STATES = { fantomes = true, chantier = true, raccordement = true }

--- Puissance (kW nominaux) des consommateurs EN CHANTIER (admis, pas encore finis) et des modules RETENUS par la porte.
--- except : un numéro de projet à ne pas compter, ou (lot COURANT-LIBRE) un ensemble { [numéro] = true }.
function Sante.committed(f, except)
  local b = f.build
  local kw = 0
  local skip = type(except) == "table" and except or nil
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if skip and skip[pid] then p = nil end
    -- admis et pas fini : « attente » compris (le plan attend un réseau, des masques : l'état revient à « attente » entre deux essais), jamais
    -- un projet rouvert (son module a déjà sa part dans la production)
    if p and (skip or pid ~= except) and p.power_kw and p.power_kw > 0 and p.admitted and not p.reopened and not p.abandoned
      and p.state ~= "fini" and p.state ~= "refuse" and not (p.state == "bloque" and not p.retry_at)
      and (not (p.spec and p.spec.site) or SITE_COMMIT_STATES[p.state]) then
      kw = kw + p.power_kw
    end
  end
  return kw
end

--- Lot s41 energie : puissance INSTALLÉE (kW nominaux) des consommateurs FINIS (ni abandonnés, ni centrales), dans l'ordre des projets.
--- Une machine posée mais à l'arrêt y compte : c'est la demande qui vient (S.demand).
function Sante.installed(f)
  local b = f.build
  local plant = { [b.plant or 0] = true }
  for _, id in ipairs(b.extra_plants or {}) do plant[id] = true end
  local kw = 0
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    if p and not plant[pid] and p.state == "fini" and not p.abandoned and type(p.power_kw) == "number" and p.power_kw > 0 then kw = kw + p.power_kw end
  end
  return kw
end

function Sante.held(f)
  local sm = mem(f)
  local ids = {}
  for id in pairs(sm.held) do ids[#ids + 1] = id end
  table.sort(ids)
  local kw = 0
  for _, id in ipairs(ids) do kw = kw + sm.held[id] end
  return kw
end

--- Porte des consommateurs : `kw_of(spec)` rend la puissance nominale (kW) du gabarit. Rend vrai si le projet peut passer à « plan ».
function Sante.gate(f, p, tick, kw_of)
  if p.admitted or Sante.off(f) then return true end
  local sp = p.spec or {}
  local sm = mem(f)
  local b = f.build
  local is_plant = p.id == b.plant
  for _, id in ipairs(b.extra_plants or {}) do if id == p.id then is_plant = true end end
  if sp.alim or sp.alimquai or sp.raccord or sp.enceinte or sp.liaison or sp.site or is_plant or p.reopened then p.admitted = true return true end
  if p.power_kw == nil then p.power_kw = kw_of(sp) or 0 end
  local g = f.build.grow
  -- lot 5b (W04 n°2) : la centrale est-elle FINIE ? Alors une capacité ou une production non lue retient le module (S.admit) au lieu de l'admettre
  local pp = b.projects[b.plant]
  local plant_done = pp ~= nil and pp.state == "fini"
  if p.power_kw <= 0 or (not plant_done and (not g or (g.capacity or 0) <= 0)) then p.admitted = true return true end
  g = g or {}
  local st = sm.gate[p.id] or {}
  sm.gate[p.id] = st
  local ok, why = S.admit(st, { capacity = g.capacity and g.capacity * JTICK_KW or nil, used = g.power and g.power * JTICK_KW or nil,
    committed = Sante.committed(f, p.id), plant_done = plant_done }, p.power_kw, tick)
  if ok then
    p.admitted = true
    sm.held[p.id] = nil
    if st.said then say(f, { kind = "admis", project = p.id, tick = tick, why = why or "marge" }) end
    sm.gate[p.id] = nil
    return true
  end
  sm.held[p.id] = p.power_kw
  p.reason = "courant"
  if not st.said then
    st.said = true
    say(f, { kind = "retenu", project = p.id, tick = tick, why = why })
  end
  return false
end

--- s50 centrale-75 : une centrale de l'équipe a-t-elle des chaudières à sec au dernier relevé (cause chaudiere_a_sec) ? Ordre des projets.
function Sante.coal_short(f)
  local sm = mem(f)
  local b = f.build
  local ids = { b.plant }
  for _, id in ipairs(b.extra_plants or {}) do ids[#ids + 1] = id end
  for _, id in ipairs(ids) do
    local st = id and sm.plants[id]
    if st and type(st.sig) == "string" and st.sig:find("chaudiere_a_sec", 1, true) then return true end
  end
  return false
end

--- Ligne « centrale de plus demandée avant la saturation » (journal ; PA.watch).
function Sante.line_avance(f, tick, used, committed, capacity)
  return S.line({ kind = "avance", team = f.key or "player", tick = tick, used = used, committed = committed, capacity = capacity })
end

--- Entrées de la croissance (PA.watch) : { anticipate, stalled (reconstructions sans progrès : ids) }.
function Sante.growth(f, tick, plants, used_j, capacity_j)
  local sm = mem(f)
  if Sante.off(f) then sm.ant_n = 0 return false, {}, 0, 0, 0 end
  -- étape 5a de VIDEO-INTEG : + les kW que la capitalisation a retenus faute de courant (S.capi_kw ; boucle B)
  local committed = Sante.committed(f) + Sante.held(f) + S.capi_kw(f.team and f.team.capi and f.team.capi.kw_blocked, tick)
  -- lot s41 energie : la demande compte la puissance installée à l'arrêt (S.demand), plus la seule production mesurée
  local used, cap = S.demand(used_j * JTICK_KW, Sante.installed(f)), capacity_j * JTICK_KW
  local stalled = {}
  for _, p in ipairs(plants) do
    if p.state ~= "fini" and p.reopened then
      local built = 0
      for _, e in ipairs(p.ents or {}) do if e.built then built = built + 1 end end
      if S.stalled(sm.stall, p.id, built, tick) then
        stalled[#stalled + 1] = p.id
        local m = sm.stall[p.id]
        if not m.said then
          m.said = true
          say(f, { kind = "bloquee", plant = p.id, tick = tick, waited = tick - m.since, built = built })
        end
      end
    end
  end
  local flag = S.anticipate(used, committed, cap)
  local was_n = sm.ant_n or 0
  local ant = S.sustain(sm, flag)
  -- lot TV-ENERGIE (diagnostic azure : hypothèse « le compteur d'anticipation repart à zéro quand les chantiers admis changent d'état ») :
  -- une ligne quand une avance en cours (>= 2 relevés) est INTERROMPUE, avec les chiffres du relevé, pour la lire en partie réelle
  if not flag and was_n >= 2 then
    say(f, { kind = "avance-rompue", tick = tick, n = was_n, used = used, committed = committed, capacity = cap })
  end
  -- lot ELECTRIQUE (c, DC 8/11 : « 4 machines à vapeur à plein régime ») : + les kW des électriques PRÉVUES que la marge ne couvre pas
  -- (thermiques à convertir, paires refusées ; f.team.elec_kw, script/team/electrique.lua, valable S.CAPI_TTL) : un déficit, centrale demandée
  -- avant la pose et à la taille du besoin (C.deficit_size)
  local elec = S.capi_kw(f.team and f.team.elec_kw, tick)
  return ant, stalled, used, committed, cap,
    S.deficit(f.team and f.team.capi and f.team.capi.kw_blocked, tick) + elec, -- lot TV-ENERGIE : déficit de kW avec épargne qui dort
    elec -- lot ELECTRIQUE : part des électriques prévues (journal [FO-ENERGIE] de plant_arms)
end

return Sante
