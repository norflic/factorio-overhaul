--[[
  Lot RESEAU-GRAPHE, BUS DE PRODUITS en jeu (ordre du DC du 8/11 à 13 h 05) : version MINIMALE. La règle pure shared/team/reseau_graphe.lua (+ reseau_bus.lua)
  choisit, parmi les coffres de sortie et les quais que la liaison de quai (script/team/liaison.lua) relève déjà, le bus qui économise le plus de trajets de
  PNJ ; ce fichier le traduit en UNE liaison longue (tronc de tapis le long des rues, souterrains par le lot traversee, tracé et pose par le projet
  « liaison » de Liaison.plan et du plan directeur) et journalise [FO-BUS].

  Ce que fait cette version : par relevé, au plus une liaison demandée pour la paire (coffre de sortie, quai) la mieux placée du meilleur bus, quand elle est
  hors de portée de la liaison de quai (plus de Li.MAX_SPAN tuiles) ; la règle tourne par TRANCHES (une unité de Rg.step par passe de Build, jamais d'un coup).
  Les autres consommateurs du bus : une fois le tronc FINI, ses tapis (rôle liaison-tapis d'un projet de liaison fini) sont des sources du piquage par
  répartiteur (script/team/piquage.lua, discover : opt_in des liaisons finies, lot PIQUAGE) pour les quais du même objet à Pq.SEARCH_SPAN tuiles ; avant
  cela, chacun reste servi par la liaison de quai ou par ses PNJ. Une liaison longue par quai, jamais de tronc partagé.
  Lot BUS-INTERMEDIAIRES (DC, 9/11) : les objets qui sont des intermédiaires pivots du mall (ml.bi.hubs, écrits par script/ai3/industrie.lua depuis le
  graphe des recettes) passent DEVANT dans le classement des paires (Bi.order_buses : bonus = le débit du hub) et leurs liaisons sont comptées À PART
  (Bi.link_ok : plafond Bi.CFG.k, hors Bus.MAX_LINKS). Journal : « paire d'intermediaire ».

  Réglage fo-war-bus (settings/bus.lua), allumé par défaut ; absent ou éteint : rien ne tourne (le moteur simulé des tests n'a pas le réglage).
  État : b.liaison.bus = { next, job, maps, n, logs, seen, last } (nombres, chaînes, tables). Journal [FO-BUS], BUS.LOGS lignes au plus par équipe.
]]

local Rg = require("shared.team.reseau_graphe")
local Ln = require("shared.team.liaison")
local Bi = require("shared.team.bus_intermediaires") -- lot BUS-INTERMEDIAIRES : paires d'intermédiaires pivots devant, comptées à part

local Bus = {}

Bus.SETTING = "fo-war-bus"
Bus.PERIOD = 3600        -- ticks entre deux calculs de la règle (60 s)
Bus.MAX_TERM = 24        -- producteurs et consommateurs au plus par calcul (les plus proches du QG)
Bus.CONFIRM = 2          -- calculs de suite où la paire est choisie avant d'agir
Bus.STOCK_MIN = 50       -- objets au coffre de sortie pour croire à sa production quand le projet n'en donne pas le débit nominal
Bus.FALLBACK_RATE = 120  -- objets/min supposés d'un coffre de sortie qui porte au moins Bus.STOCK_MIN objets (NON MESURÉ)
Bus.MAX_LINKS = 4        -- liaisons de bus ouvertes ou finies au plus par équipe (le « k » de cette version)
Bus.LOGS = 40            -- lignes [FO-BUS] au plus par équipe
-- Tracé du tronc (liaison.lua, Liaison.plan) : recherche A* PAR TRANCHES, pour qu'une passe ne dépasse pas ~5 ms (mesuré en instructions : tests/bus_test.lua)
Bus.SLICE = 250          -- états développés au plus par passe (~1000 instructions chacun)
Bus.WEIGHT = 1.4         -- heuristique pondérée (tracé au plus 1,4 fois plus long que le meilleur, bien moins d'états : revue-s, 923 états en terrain libre)
Bus.MAX_STATES = 8000    -- états développés au plus sur le TOTAL des passes d'un tronc (au-delà : « trop long », la paire est laissée à la liaison de quai)
Bus.CACHE_TTL = 3600     -- ticks de validité des masques gardés en mémoire locale pendant la recherche

--- Signature d'un bout (sites de départ et d'arrivée) : la recherche reprise doit porter sur le même couple de bouts.
function Bus.end_sig(e) return string.format("%d:%d:%d>%d:%d:%d", e.src.bx, e.src.by, e.src.dir, e.dst.bx, e.dst.by, e.dst.dir) end

function Bus.on()
  local ok, s = pcall(function() return settings.global[Bus.SETTING] end)
  return ok and s ~= nil and s.value == true
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Un tracé de bus est accepté jusqu'à Rg.MAX_TRUNK tuiles et deux fois la distance à vol d'oiseau (la liaison de quai : 48 tuiles et 1,5 fois).
function Bus.route_ok(len, m)
  if len > Rg.MAX_TRUNK then return false, string.format("tapis de %d tuiles > %d", len, Rg.MAX_TRUNK) end
  local lim = 2 * (m + 1) + 12
  if len > lim then return false, string.format("detour de %d tuiles pour %d a vol d'oiseau (limite %d)", len, m + 1, lim) end
  return true, ""
end

--- Emprise maximale d'un tracé de bus autour des deux coffres (tuiles) ; la liaison de quai : 120.
Bus.MAX_BOX = 260

function Bus.say(f, tick, text)
  local b = f.build
  local st = b and b.liaison
  local bs = st and st.bus
  if bs then
    bs.logs = (bs.logs or 0) + 1
    if bs.logs > Bus.LOGS then return end
  end
  log(string.format("[FO-BUS] %s : %s a %.1f min", f.key or "player", text, tick / 3600))
end

local function state(st)
  st.bus = st.bus or { next = 0, n = { calculs = 0, choix = 0, demandes = 0 }, logs = 0, seen = {} }
  return st.bus
end

--- Lot BUS-INTERMEDIAIRES : débits des intermédiaires pivots { [objet] = objets/min } écrits par le mall (script/ai3/industrie.lua, ml.bi.hubs) ; vide sinon.
function Bus.hubs(f)
  local ml = f and f.team and f.team.ia3 and f.team.ia3.mall
  return (ml and ml.bi and ml.bi.hubs) or {}
end

--- Réglages de BANC (remote fo-liaison set_param bus_period / bus_confirm) : jamais appelés par le mod.
function Bus.set_param(st, name, value)
  local bs = state(st)
  if name == "bus_period" then bs.period = value; bs.next = 0
  elseif name == "bus_confirm" then bs.confirm = value
  else return nil end
  return value
end

--- Lance un calcul (relevé fini : c.docks, c.srcs). Rend vrai si un calcul démarre. h = aides de liaison.lua.
function Bus.start(h, f, surface, tick, b, st, c)
  if not Bus.on() then return false end
  local bs = state(st)
  if bs.job or tick < bs.next then return false end
  local hq = f.hq and f.hq.valid and f.hq.position
  if not hq then return false end
  local P, C, maps = {}, {}, { docks = {}, srcs = {} }
  -- lot RAPATRIEMENT : une sortie lointaine deja reliee par une ligne (b.rapatriement.lines[clé]) n'est plus un producteur (double compte) ;
  -- son coffre TAMPON en est un, au debit des lignes finies qui y menent (objets/s -> /min)
  local rap = b.rapatriement and b.rapatriement.lines or {}
  local tamp = {}
  for _, k in ipairs(sorted_keys(rap)) do
    local l = rap[k]
    if l.done and l.tampon and l.item then
      local tk = l.item .. "@" .. math.floor(l.tampon.x) .. ":" .. math.floor(l.tampon.y)
      tamp[tk] = (tamp[tk] or 0) + (l.flow or 0) * 60
    end
  end
  for _, s in ipairs(c.srcs) do
    if s.item and not s.linked and not rap[s.key] then
      local p = b.projects[s.pid]
      local nout = math.max(1, #((p and p.outs) or {}))
      local out = p and p.outflow and p.outflow[s.item]
      local rate = out and out * 60 / nout or nil
      local tr = tamp[s.item .. "@" .. s.x .. ":" .. s.y]
      if tr and tr >= 1 then rate = tr end
      if not rate and (s.n or 0) >= Bus.STOCK_MIN then rate = Bus.FALLBACK_RATE end
      if rate and rate >= 1 then
        P[#P + 1] = { key = s.key, item = s.item, x = s.x, y = s.y, rate = rate, _d = math.abs(s.x - hq.x) + math.abs(s.y - hq.y) }
        maps.srcs[s.key] = { pid = s.pid, idx = s.idx, x = s.x, y = s.y }
      end
    end
  end
  for _, d in ipairs(c.docks) do
    if d.item and not d.linked and (d.flow or 0) * 60 >= 1 then
      C[#C + 1] = { key = d.key, item = d.item, x = d.x, y = d.y, rate = d.flow * 60, _d = math.abs(d.x - hq.x) + math.abs(d.y - hq.y) }
      maps.docks[d.key] = { pid = d.pid, idx = d.idx, x = d.x, y = d.y, flow = d.flow, item = d.item }
    end
  end
  if #P == 0 or #C == 0 then bs.next = tick + (bs.period or Bus.PERIOD) return false end
  local hubs = Bus.hubs(f)
  local function keep(list)
    table.sort(list, function(a, z)
      local ha, hz = hubs[a.item] ~= nil, hubs[z.item] ~= nil
      if ha ~= hz then return ha end -- lot BUS-INTERMEDIAIRES : les terminaux d'un intermédiaire pivot restent dans le calcul avant les plus proches
      if a._d ~= z._d then return a._d < z._d end
      return a.key < z.key
    end)
    while #list > Bus.MAX_TERM do list[#list] = nil end
  end
  keep(P)
  keep(C)
  bs.job = Rg.begin({ producers = P, consumers = C, hub = { x = hq.x, y = hq.y }, k = Rg.k_for(14, 1e9) })
  bs.maps = maps
  bs.n.calculs = bs.n.calculs + 1
  bs.next = tick + (bs.period or Bus.PERIOD)
  return true
end

--- Une unité de calcul par passe ; à la fin, choix de la paire et demande de liaison. Rend vrai si une liaison a été demandée.
function Bus.advance(h, api, f, surface, tick)
  local b = f.build
  local st = b and b.liaison
  local bs = st and st.bus
  if not (bs and bs.job) then return false end
  if not Bus.on() then bs.job, bs.maps = nil, nil return false end
  if not Rg.step(bs.job, 1) then return false end
  local res = Rg.result(bs.job)
  local maps = bs.maps
  bs.job, bs.maps = nil, nil
  local s = res.stats
  if #res.buses == 0 then
    if not bs.said_none or bs.said_none ~= #s.rejects then
      bs.said_none = #s.rejects
      Bus.say(f, tick, string.format("aucun bus : %d composante(s), %d candidat(s), demande %.0f/min, refus %s", s.components, s.candidates, s.demand,
        #s.rejects > 0 and s.rejects[1] or "-"))
    end
    return false
  end
  -- ouvertes ; les liaisons ouvertes ou finies sont comptées à part pour les intermédiaires pivots (lot BUS-INTERMEDIAIRES : Bi.count_links)
  local open = 0
  for _, k in ipairs(sorted_keys(st.links)) do
    local l = st.links[k]
    if l.bus and not l.done then open = open + 1 end
  end
  local hubs = Bus.hubs(f)
  local counts = Bi.count_links(st.links, hubs)
  local present = {}
  local why = { lies = 0, portee = 0, attente = 0, garde = 0 }
  for _, bus in ipairs(Bi.order_buses(res.buses, hubs)) do -- les bus d'un intermédiaire pivot d'abord (bonus = le débit du hub)
    local cap_ok = Bi.link_ok(counts, bus.item, hubs, Bus.MAX_LINKS)
    -- paire : le consommateur qui contribue le plus, avec le producteur du même bus le plus proche, hors de portée de la liaison de quai
    for _, tc in ipairs(bus.taps) do
      local d = tc.kind == "c" and maps.docks[tc.key] or nil
      if d and st.links[tc.key] then why.lies = why.lies + 1 end
      if d and not st.links[tc.key] then
        local best, bspan
        for _, tp in ipairs(bus.taps) do
          local sr = tp.kind == "p" and maps.srcs[tp.key] or nil
          if sr then
            local span = math.abs(sr.x - d.x) + math.abs(sr.y - d.y)
            if span > Ln.MAX_SPAN and (not bspan or span < bspan or (span == bspan and tp.key < best.key)) then best, bspan = tp, span end
          end
        end
        if not best then why.portee = why.portee + 1 end
        if best then
          -- confirmation par QUAI (pas par paire) : le choix du producteur d'un bus change d'un calcul a l'autre quand les stocks bougent
          local pk = tc.key
          present[pk] = true
          bs.seen[pk] = (bs.seen[pk] or 0) + 1
          if bs.seen[pk] < (bs.confirm or Bus.CONFIRM) then why.attente = why.attente + 1
          elseif not (open < h.max_open(h.free_workers(f)) and cap_ok and not h.hq_threat(f, surface)) then why.garde = why.garde + 1 end
          if bs.seen[pk] >= (bs.confirm or Bus.CONFIRM) and open < h.max_open(h.free_workers(f)) and cap_ok and not h.hq_threat(f, surface) then
            local sr = maps.srcs[best.key]
            local last = st.last_try[tc.key]
            local tries = st.tries[tc.key] or 0
            if tries >= Ln.MAX_TRIES and last and tick - last < Ln.RETRY_AFTER then
              -- essais épuisés : on laisse
            elseif h.enemy_near(f, surface, d.x, d.y) or h.enemy_near(f, surface, sr.x, sr.y) then
              Bus.say(f, tick, string.format("bus %d (%s) : paire %s > %s retenue, ennemi a moins de %d tuiles", bus.id, bus.item, tc.key, best.key, Ln.ENEMY_R))
            else
              local dp, sp = b.projects[d.pid], b.projects[sr.pid]
              local arm, pole = h.pick_names(dp, sp)
              local belt = h.belt(f, d.flow)
              if not (arm and belt) then
                Bus.say(f, tick, string.format("bus %d (%s) : pas de pieces (%s)", bus.id, bus.item, not arm and "aucun bras electrique connu" or "aucun tapis debloque"))
              else
                st.tries[tc.key] = tries + 1
                st.last_try[tc.key] = tick
                local spec = { liaison = { key = tc.key, item = d.item, flow = d.flow, arm = arm, pole = pole, belt = belt, bus = true,
                  dock = { pid = d.pid, idx = d.idx, x = d.x, y = d.y }, src = { pid = sr.pid, idx = sr.idx, x = sr.x, y = sr.y, key = best.key } },
                  prio = api.prio, domain = "infrastructures", pile = "capital", product = d.item }
                local id = api.request(f, spec)
                if id then
                  st.links[tc.key] = { pid = id, src = best.key, item = d.item, dock_pid = d.pid, dock_idx = d.idx, done = false, since = tick, bus = true }
                  st.n.demandes = st.n.demandes + 1
                  bs.n.demandes = bs.n.demandes + 1
                  if hubs[bus.item] then
                    Bus.say(f, tick, string.format("paire d'intermediaire %s : sortie %s -> quai %s (projet %d), %.0f/min voulus au mall, %d liaison(s) d'intermediaire sur %d",
                      bus.item, best.key, tc.key, id, hubs[bus.item], counts.hubs + 1, Bi.CFG.k))
                  end
                  Bus.say(f, tick, string.format("bus %d choisi : %s, %d producteur(s) %d consommateur(s), %.0f/min servis (retour %.0f min, %d tuiles) ; "
                    .. "liaison demandee (projet %d) de la sortie %s au quai %s, %d tuiles a vol d'oiseau ; %.0f/%.0f demandes servies, plafond %.0f",
                    bus.id, bus.item, bus.n_prod, bus.n_cons, bus.served, bus.payback_min, bus.tiles, id, best.key, tc.key, bspan, s.served, s.demand, s.ceiling))
                  return true
                end
              end
            end
          end
        end
      end
    end
  end
  for _, k in ipairs(sorted_keys(bs.seen)) do if not present[k] then bs.seen[k] = nil end end
  local sig = string.format("%d/%d/%d/%d/%d", #res.buses, why.lies, why.portee, why.attente, why.garde)
  if bs.last ~= sig then
    bs.last = sig
    Bus.say(f, tick, string.format("%d bus calcule(s) : %.0f objets/min servis sur %.0f demandes, %d file(s), %d candidat(s) ; aucune paire a demander encore (quais deja relies %d, hors de portee de la liaison de quai %d, en attente de confirmation %d, gardes (ouvriers, danger, plafond) %d)",
      #res.buses, s.served, s.demand, s.belts, s.candidates, why.lies, why.portee, why.attente, why.garde))
  end
  return false
end

return Bus
