--[[
  Lot PD-ELEC (demande D05 du DC : « incapables de détecter des zones non couvertes par l'électricité ») : relevé périodique,
  borné par tick, des machines des modules FINIS d'une équipe (factions et votre équipe) qui n'ont pas de courant parce qu'elles
  sont sur une île (réseau sans machine génératrice) ou sous aucun poteau, HORS du cas « poteau perdu » (déjà traité par
  script/team/reseau_vivant.lua, [FO-RESEAU]) ; puis un projet de RACCORDEMENT : une chaîne de poteaux planifiée par la recherche
  de chemin de 0.6.17/0.6.18 (P.pole_chain, masques du couloir) et bâtie par la machinerie ordinaire du plan directeur (réserve
  au coffre, fantômes, PNJ, fils au raccordement). Règle pure : shared/team/raccord.lua. Journal [FO-RACCORD].

  Appelé par script/team/build.lua à chaque passe d'équipe (Ra.step) ; rien à abonner. État : b.raccord (nombres, chaînes,
  tables ; jamais de fonction), créé à la première passe : les sauvegardes d'avant le lot le créent d'elles-mêmes. Seule entité gardée :
  les générateurs du relevé des générateurs en cours (b.raccord.lj.gens, lot LOURD), entre deux bandes.
  Coût : un début de relevé par minute (une lecture des machines génératrices), puis UNE partie de module par passe (une recherche
  d'entités sur sa boîte) ; la décision (au plus un raccordement par relevé) lit les poteaux autour du groupe choisi.
  Lot LOURD (7/11, fo-logs\2026-11-07_LOURD\CRITERES.md §1) : la lecture des machines génératrices du début de relevé se fait par BANDES de
  Ra.BAND lignes de chunks (boîte des chunks générés, api.box), une bande par passe sous le jeton du tick, au lieu d'une recherche sur toute
  la surface (MESURÉ sur la sauvegarde du DC, 0.6.59 : ra:debut 35,8 ms en moyenne, 83,3 ms au pire).
]]

local R = require("shared.team.raccord")
local M = require("shared.team.modules")
local P = require("shared.team.plan")
local Rv = require("script.team.reseau_vivant")
local Cr = require("shared.team.coupure_reseau") -- lot ENERGIE (2/11) : second chemin autour des ennemis
local Gens = require("script.team.generateurs") -- lot X10-S4 : registre des génératrices (plus de recherche sur toute la surface)

local Ra = {}

local ELEC_TYPES = { "mining-drill", "assembling-machine", "lab", "inserter", "furnace" }
local GEN_TYPES = { "generator", "burner-generator", "solar-panel" }
local LIVE_STATES = { fini = true, chantier = true, raccordement = true } -- projets dont un poteau perdu est rouvert par [FO-RESEAU]
local PENDING_STATES = { reserve = true, defrichage = true, fantomes = true, chantier = true, raccordement = true }
local DECIDE_MAX = 6 -- groupes examinés au plus par relevé (lectures du moteur bornées)
Ra.BAND = 2               -- lot LOURD : lignes de chunks par bande du relevé des générateurs (début de cycle)
Ra.BANDS_PER_PULSE = 1    -- lot LOURD : bandes par passe ; math.huge : tout le relevé à la passe du départ (l'horaire d'avant)
-- Lot LOURD, suite (0.6.63) : coût déclaré au jeton du DÉBUT par le registre des génératrices quand il sert (Gens.serves) : aucune recherche
-- du moteur ; MESURÉ hors jeu (tests/ra_bloc_test.lua, 60 génératrices, plan de 40 machines) : environ 3 600 instructions Lua du mod ;
-- en jeu, ra:debut 2,84 ms au pire (LOURD-ABAB série 2). La moitié du budget : une tranche du relevé du réseau (Rv.COLS = 32).
Ra.COUT_REGISTRE = 32

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function say(f, tick, text)
  log(string.format("[FO-RACCORD] %s : %s a %.1f min", f.key or "player", text, tick / 3600))
end

local function is_pole(name) return name:find("electric%-pole") ~= nil end

--- Pièce « machine » d'un plan (rang de pose machine ou bras) : seules celles-là sont relevées.
local function is_machine(e)
  local r = P.kind_rank(e.name)
  return r == 2 or r == 3
end

---------------------------------------------------------------------------------------------------
-- Relevé
---------------------------------------------------------------------------------------------------
--- Réseaux alimentés (au moins une machine génératrice de l'équipe) : { [numéro] = true }, nombre.
--- Lot X10-S4 : lu au registre des génératrices (script/team/generateurs.lua), même ensemble que l'ancienne recherche sur toute la surface.
local function live_networks(f, surface)
  return Gens.networks(surface, f.force, GEN_TYPES)
end

-- Lot LOURD : le même relevé par bandes. Une bande = Ra.BAND lignes de chunks sur toute la largeur de la boîte des chunks générés ; un
-- générateur n'est gardé que dans la bande qui contient sa POSITION (y dans [y0, y1[ : la recherche par zone rend aussi ce qui touche ou
-- chevauche la bande, F96). Les générateurs sont gardés comme ENTITÉS et leurs réseaux RELUS à la dernière bande : le moteur renumérote
-- un réseau qui se coupe ou se joint (même règle que le relevé du réseau, reseau_vivant.lua) ; live est donc celui de live_networks lu à
-- la fin, aux générateurs posés depuis dans une bande déjà faite près (vus au relevé suivant). État : st.lj.
local function gen_job_new(box)
  return { y = box.y0, y_end = box.y1 + 1, x0 = box.x0, x1 = box.x1 + 1, gens = {}, bands = 0 }
end

--- Une bande du relevé des générateurs ; vrai quand la dernière est faite.
local function gen_band(f, surface, j)
  local ya, yb = j.y, math.min(j.y + Ra.BAND, j.y_end)
  local top, bottom = ya * 32, yb * 32
  for _, g in ipairs(surface.find_entities_filtered({ area = { { j.x0 * 32, top }, { j.x1 * 32, bottom } }, force = f.force,
    type = GEN_TYPES })) do
    local y = g.position.y
    if y >= top and y < bottom then j.gens[#j.gens + 1] = g end
  end
  j.y = yb
  j.bands = j.bands + 1
  return j.y >= j.y_end
end

--- Fin du relevé des générateurs : réseaux relus maintenant ; { [numéro] = true }, nombre (comme live_networks).
local function gen_finish(j)
  local live, n = {}, 0
  for _, g in ipairs(j.gens) do
    if g.valid then
      local id = g.electric_network_id
      if id and not live[id] then live[id] = true; n = n + 1 end
    end
  end
  return live, n
end

-- Bancs hors jeu (tests/lourd_test.lua) : le relevé des générateurs par bandes et d'un bloc, sur un même monde.
Ra.generateurs = { new = gen_job_new, band = gen_band, finish = gen_finish, bloc = live_networks }

--- Lot LOURD (point 2) : coût DÉCLARÉ au jeton (script/core/lourd.lua) des Ra.BANDS_PER_PULSE bandes suivantes d'un relevé à la ligne
--- `y` (fin `y_end`, `width` chunks de large) : les chunks qu'elles couvrent, au plus jusqu'à la fin ; nil (tout le budget) quand tout le
--- relevé se fait à la passe.
function Ra.cout(y, y_end, width)
  if Ra.BANDS_PER_PULSE == math.huge then return nil end
  local n = 0
  for _ = 1, Ra.BANDS_PER_PULSE do
    if y >= y_end then break end
    local yb = math.min(y + Ra.BAND, y_end)
    n = n + (yb - y) * width
    y = yb
  end
  return n
end

--- Lot FONDERIE (3/11, 0.6.43) : une bande de champ EN COURS (réserve à chantier) dont des machines sont posées est relevée aussi, quand la
--- fonderie à tapis est allumée (`champ_live`, passé par build.lua) : son raccord du plan peut viser un poteau détruit depuis (attaque
--- de l'avant-poste, verif-guide 1618033988 : 68 consommateurs sur 72 sans courant de la minute 28 à 58, projet en chantier).
local function scanned(q, champ_live)
  if q.state == "fini" then return true end
  return champ_live == true and PENDING_STATES[q.state] == true and q.spec ~= nil and q.spec.champ ~= nil
end

local function start_cycle(f, surface, b, champ_live, live, n)
  if not live then live, n = live_networks(f, surface) end -- (lot LOURD : sinon, relevé des générateurs par bandes déjà fait)
  local units = {}
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and scanned(q, champ_live) and not q.abandoned and not (q.spec and (q.spec.raccord or q.spec.enceinte)) then
      local parts, seen = {}, {}
      for _, e in ipairs(q.ents) do
        if e.built and not e.dropped and is_machine(e) then
          local k = e.part or 0
          if not seen[k] then seen[k] = true; parts[#parts + 1] = k end
        end
      end
      table.sort(parts)
      for _, k in ipairs(parts) do units[#units + 1] = { pid, k } end
    end
  end
  return { live = live, n_live = n, units = units, i = 1, obs = {}, found = {}, machines = 0, champ_live = champ_live or nil }
end

local function tkey(x, y) return math.floor(x) .. ":" .. math.floor(y) end

local function scan_unit(f, surface, b, c, u)
  local q = b.projects[u[1]]
  if not (q and scanned(q, c.champ_live)) then return end
  local keys, x0, y0, x1, y1 = {}, math.huge, math.huge, -math.huge, -math.huge
  for _, e in ipairs(q.ents) do
    if (e.part or 0) == u[2] and e.built and not e.dropped and is_machine(e) then
      keys[tkey(e.x, e.y)] = true
      x0, y0, x1, y1 = math.min(x0, e.x), math.min(y0, e.y), math.max(x1, e.x), math.max(y1, e.y)
    end
  end
  if x0 == math.huge then return end
  for _, ent in ipairs(surface.find_entities_filtered({ area = { { x0 - 1, y0 - 1 }, { x1 + 1, y1 + 1 } }, force = f.force, type = ELEC_TYPES })) do
    local pos = ent.position
    -- une machine du PLAN (un niveau plus grand peut avoir décalé son centre d'une demi-tuile) ; jamais celle qu'un joueur a posée
    local mine = keys[tkey(pos.x, pos.y)] or keys[tkey(pos.x - 0.5, pos.y - 0.5)] or keys[tkey(pos.x + 0.5, pos.y - 0.5)]
      or keys[tkey(pos.x - 0.5, pos.y + 0.5)] or keys[tkey(pos.x + 0.5, pos.y + 0.5)]
    local un = ent.unit_number
    if mine and un and not c.found[un] then
      c.found[un] = true
      c.machines = c.machines + 1
      local net = ent.electric_network_id
      if not (net and c.live[net]) then -- le cas courant (réseau alimenté) ne lit pas le prototype
        local kind = R.classify(net, function(id) return c.live[id] == true end, ent.prototype.electric_energy_source_prototype ~= nil)
        if kind ~= "ok" then
          local bb = ent.bounding_box
          c.obs[#c.obs + 1] = { pid = q.id, part = u[2], net = net, x = pos.x, y = pos.y, kind = kind,
            box = { bb.left_top.x, bb.left_top.y, bb.right_bottom.x, bb.right_bottom.y } }
        end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Entrées de la décision
---------------------------------------------------------------------------------------------------
local function near_box(box, x, y, r)
  local dx = math.max(box[1] - x, 0, x - box[3])
  local dy = math.max(box[2] - y, 0, y - box[4])
  return dx * dx + dy * dy <= r * r
end

local function member(list, v)
  for _, x in ipairs(list) do if x == v then return true end end
  return false
end

--- Poteaux perdus que [FO-RESEAU] peut rouvrir (même filtre que reseau_vivant.lost_poles) : ceux des projets du groupe, ou à
--- R.LOST_NEAR de sa boîte. Au plus 40 lectures du moteur.
local function lost_near(f, surface, b, g)
  local n, reads = 0, 0
  local foes, seen = {}, {} -- lot ENERGIE (2/11) : les poteaux perdus TENUS par un ennemi ne comptent pas (reseau_vivant ne les rouvre pas)
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and not q.abandoned and LIVE_STATES[q.state] and (q.poles_reopened or 0) < Rv.POLE_REOPEN_MAX then
      local own = member(g.pids, q.id)
      for _, e in ipairs(q.ents) do
        if e.built and not e.dropped and is_pole(e.name) and (own or near_box(g.box, e.x, e.y, R.LOST_NEAR)) then
          reads = reads + 1
          if reads > 40 then return n, foes end
          local found = surface.find_entities_filtered({ position = { e.x, e.y }, radius = 0.6, force = f.force, type = "electric-pole", limit = 1 })
          if not found[1] then
            local foe = (not Rv.coupure_off(b)) and Rv.foe_near(f, surface, e.x, e.y) or nil
            if foe then
              local key = math.floor(foe.x) .. ":" .. math.floor(foe.y)
              if not seen[key] then seen[key] = true; foes[#foes + 1] = foe end
            else
              n = n + 1
            end
          end
        end
      end
    end
  end
  return n, foes
end

--- Poteaux pas encore bâtis d'un chantier (autre qu'un raccordement de ce groupe) à R.LOST_NEAR : l'île est peut-être attendue.
--- (lot FONDERIE, 0.6.43, champ-longue2-20261020 : île d'une bande d'azure « attendre : 14 à 44 poteaux d'un chantier voisin » de la minute
--- 28 à 146, chantier du champ arrêté) quand `champ_live`, les poteaux non posés des projets de CHAMP ne font plus attendre : ce chantier peut
--- ne jamais finir (obstacle, matières) ; au pire, quelques poteaux posés en double.
local function pending_near(b, g, champ_live)
  local n = 0
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and PENDING_STATES[q.state] and not q.abandoned and not (q.spec and q.spec.raccord and q.spec.raccord.key == g.key)
      and not (champ_live and q.spec and q.spec.champ) then
      for _, e in ipairs(q.ents) do
        if not e.built and is_pole(e.name) and near_box(g.box, e.x, e.y, R.LOST_NEAR) then n = n + 1 end
      end
    end
  end
  return n
end

local function wire_of(name)
  local w = P.wire(name)
  if w then return w end
  local proto = game.entity_prototypes[name]
  return proto and proto.max_wire_distance or nil
end

--- Bouts du raccordement d'un groupe : spec.raccord, ou nil et raison. Un fil seul suffit (bouts à portée) : il est tiré ici
--- (rend nil, "fil").
local function ends_of(f, surface, g, live)
  local m = R.MAX_DIST
  local targets = {}
  for _, p in ipairs(surface.find_entities_filtered({ area = { { g.box[1] - m, g.box[2] - m }, { g.box[3] + m, g.box[4] + m } },
    type = "electric-pole", force = f.force })) do
    local id = p.electric_network_id
    if id and live[id] then
      targets[#targets + 1] = { x = p.position.x, y = p.position.y, name = p.name, reach = p.prototype.max_wire_distance, ent = p }
    end
  end
  if #targets == 0 then return nil, string.format("aucun poteau alimente a moins de %d tuiles", m) end
  local starts, new = {}, false
  if g.kind == "ile" then
    for _, p in ipairs(surface.find_entities_filtered({ area = { { g.box[1] - 12, g.box[2] - 12 }, { g.box[3] + 12, g.box[4] + 12 } },
      type = "electric-pole", force = f.force })) do
      if p.electric_network_id == g.net then
        starts[#starts + 1] = { x = p.position.x, y = p.position.y, name = p.name, reach = p.prototype.max_wire_distance, ent = p }
      end
    end
    if #starts == 0 then return nil, "aucun poteau de l'ile trouve pres des machines" end
  else
    new = true
    local mb = g.mbox
    starts[1] = { x = (mb[1] + mb[3]) / 2, y = (mb[2] + mb[4]) / 2 }
  end
  local s, t, d = R.best_pair(starts, targets, m)
  if not s then return nil, string.format("aucune paire de poteaux a moins de %d tuiles", m) end
  local pole = (not new and P.wire(s.name)) and s.name or M.DEFAULT_POLE
  local proto = game.entity_prototypes[pole]
  local new_reach = wire_of(pole) or 9
  local reach = R.chain_reach(not new and s.reach or nil, t.reach, new_reach)
  if not new and d <= reach + 1e-6 then
    -- les deux réseaux sont à portée de fil : pas de poteau à poser, un fil (moteur réel : connect_neighbour)
    local ok = s.ent.connect_neighbour(t.ent)
    return nil, ok and "fil" or "fil refuse par le moteur"
  end
  local spec = { key = g.key, kind = g.kind, pole = pole, reach = reach, big = proto ~= nil and proto.tile_width >= 2,
    target = { x = t.x, y = t.y }, dist = d }
  -- lot ENERGIE (2/11) : les ennemis qui tenaient des poteaux perdus de la ligne : la chaîne neuve les contourne (second chemin)
  if g.foes and #g.foes > 0 then spec.avoid = Cr.avoid_zone(g.foes, { x = t.x, y = t.y }, 6) end
  if new then
    spec.start = { new = true }
    spec.cands = {}
    for i, c in ipairs(R.ring_tiles(g.mbox, t, proto and proto.supply_area_distance)) do
      if i > 12 then break end
      spec.cands[#spec.cands + 1] = { x = c.x, y = c.y }
    end
  else
    spec.start = { x = s.x, y = s.y }
  end
  return spec
end

---------------------------------------------------------------------------------------------------
-- Fin de relevé : suivi des raccordements ouverts, décisions
---------------------------------------------------------------------------------------------------
local function note(st, f, tick, key, text)
  if st.said[key] == text then return end
  st.said[key] = text
  say(f, tick, text)
end

local function finish_cycle(api, f, surface, b, st, c, tick)
  -- 1. raccordements ouverts
  for _, key in ipairs(sorted_keys(st.open)) do
    local q = b.projects[st.open[key]]
    if not q then
      st.open[key] = nil
    elseif q.state == "fini" then
      st.n.finis = st.n.finis + 1
      say(f, tick, string.format("groupe %s : raccordement fini (projet %d, %d poteau(x), %d fil(s) tire(s))", key, q.id, #q.ents, q.wired or 0))
      st.open[key] = nil
    elseif q.state == "refuse" or q.abandoned then
      st.n.refuses = st.n.refuses + 1
      say(f, tick, string.format("groupe %s : raccordement refuse (projet %d : %s)", key, q.id, tostring(q.reason)))
      st.open[key] = nil
    end
  end
  -- 2. groupes du relevé
  local groups = R.groups(c.obs)
  local present = {}
  for _, g in ipairs(groups) do
    present[g.key] = true
    st.seen[g.key] = (st.seen[g.key] or 0) + 1
  end
  for _, key in ipairs(sorted_keys(st.seen)) do
    if not present[key] then
      if st.tries[key] then
        st.n.repares = st.n.repares + 1
        say(f, tick, string.format("groupe %s : plus de machine sans courant (%d raccordement(s) tente(s))", key, st.tries[key]))
      end
      st.seen[key], st.tries[key], st.said[key], st.last_try[key], st.waited[key], st.waited_lost[key] = nil, nil, nil, nil, nil, nil
    end
  end
  local open_total = #sorted_keys(st.open)
  local ile, sans = 0, 0
  for _, o in ipairs(c.obs) do if o.kind == "ile" then ile = ile + 1 else sans = sans + 1 end end
  if (#c.obs > 0 or open_total > 0) and (tick >= (st.log_next or 0) or #groups ~= (st.last_groups or 0)) then
    st.log_next = tick + R.LOG_EVERY
    say(f, tick, string.format("releve : %d machine(s) des modules finis, %d sans courant (ile %d, sous aucun poteau %d) en %d groupe(s) ; "
      .. "%d reseau(x) alimente(s) ; raccordements ouverts %d, demandes %d, finis %d, refuses %d, groupes repares %d",
      c.machines, #c.obs, ile, sans, #groups, c.n_live, open_total, st.n.demandes, st.n.finis, st.n.refuses, st.n.repares))
  end
  st.last_groups = #groups
  -- 3. décisions (au plus un raccordement demandé par relevé)
  local asked = false
  local window
  window, st.rot = R.window(#groups, st.rot, DECIDE_MAX) -- lot COURANT2 : fenêtre tournante (plus de 6 groupes : chacun est décidé à son tour)
  for _, idx in ipairs(window) do
    local g = groups[idx]
    local last = st.last_try[g.key]
    local inp = { has_live = c.n_live > 0, open = st.open[g.key] ~= nil, open_total = open_total, seen = st.seen[g.key],
      tries = st.tries[g.key] or 0, since_try = last and (tick - last) or R.RETRY_AFTER, waited = st.waited[g.key] or 0,
      waited_lost = st.waited_lost[g.key] or 0 }
    if inp.has_live and not inp.open then
      inp.lost, g.foes = lost_near(f, surface, b, g)
      -- lot ENERGIE (2/11) : [FO-RESEAU] a jugé qu'aucun chemin sûr de poteaux perdus ne relie l'îlot (second chemin) : ces poteaux ne le retiennent plus
      local sv = b.sante
      if sv and sv.second_tick and tick - sv.second_tick <= R.SECOND_WINDOW and not Rv.coupure_off(b) then inp.lost = 0 end
      -- (lot COURANT2) plus de poteau perdu a portee (rouvert, ou second chemin) : l'attente repart de zero
      if inp.lost == 0 then st.waited_lost[g.key], inp.waited_lost = nil, 0 end
      -- (lot COURANT2) un poteau perdu qui retient le groupe depuis R.WAIT_LOST relevés ne le retient plus : suite de la décision comme sans perte
      local lost_free = inp.lost == 0 or inp.waited_lost >= R.WAIT_LOST
      if lost_free then inp.pending = pending_near(b, g, c.champ_live) end
      if lost_free and ((inp.pending or 0) == 0 or inp.waited >= R.WAIT_PENDING) and (inp.seen or 0) >= R.CONFIRM then
        local foe = surface.find_nearest_enemy({ position = { x = g.x, y = g.y }, max_distance = R.ENEMY_R, force = f.force })
        inp.enemies = foe and 1 or 0
      end
    end
    local action, why = R.decide(inp)
    -- (lot FONDERIE, 0.6.44) attente bornée derrière un chantier voisin : compte des relevés où le groupe a attendu pour cette raison
    if action == "attendre" and (inp.pending or 0) > 0 and inp.waited < R.WAIT_PENDING then st.waited[g.key] = inp.waited + 1 end
    if action == "laisser" and (inp.lost or 0) > 0 and inp.waited_lost < R.WAIT_LOST then st.waited_lost[g.key] = inp.waited_lost + 1 end
    if action == "relier" and asked then action, why = "attendre", "un raccordement par releve" end
    -- relecture au moment d'agir : le relevé s'étale sur plusieurs passes et le moteur renumérote un réseau qui se coupe ou se
    -- joint ; un numéro périmé gâcherait un essai (R.MAX_TRIES) sur un groupe déjà alimenté ou sur un départ introuvable
    local live = c.live
    if action == "relier" then
      live = live_networks(f, surface)
      local m = surface.find_entities_filtered({ position = { g.x, g.y }, radius = 0.5, force = f.force, type = ELEC_TYPES, limit = 1 })[1]
      local net = m and m.electric_network_id
      if not m then action, why = "attendre", "machine introuvable a la relecture"
      elseif net and live[net] then action, why = "attendre", "alimentee a la relecture"
      elseif g.kind == "ile" and not net then action, why = "attendre", "ile sans poteau a la relecture"
      elseif g.kind == "ile" then g.net = net end
    end
    if action == "relier" then
      asked = true
      local spec, err = ends_of(f, surface, g, live)
      if (st.tries[g.key] or 0) >= R.MAX_TRIES then st.tries[g.key] = R.MAX_TRIES - 1 end -- essai de plus après R.RETRY_AFTER
      st.tries[g.key] = (st.tries[g.key] or 0) + 1
      st.last_try[g.key] = tick
      if spec then
        local id = api.request(f, { raccord = spec, prio = api.prio, domain = "infrastructures" })
        if id then
          st.open[g.key] = id
          st.n.demandes = st.n.demandes + 1
          open_total = open_total + 1
          st.said[g.key] = nil
          say(f, tick, string.format("groupe %s (%s, %d machine(s), projet(s) %s) : raccordement demande (projet %d), %s vers le poteau alimente "
            .. "(%.0f, %.0f) a %.0f tuiles, poteau %s de portee %g (essai %d/%d)", g.key, g.kind, g.n, table.concat(g.pids, ","), id,
            spec.start.new and "poteau neuf contre la machine" or string.format("du poteau de l'ile (%.0f, %.0f)", spec.start.x, spec.start.y),
            spec.target.x, spec.target.y, spec.dist, spec.pole, spec.reach, st.tries[g.key], R.MAX_TRIES))
        end
      elseif err == "fil" then
        st.n.fils = (st.n.fils or 0) + 1
        say(f, tick, string.format("groupe %s (%s, %d machine(s)) : poteaux a portee, fil tire directement", g.key, g.kind, g.n))
      else
        note(st, f, tick, g.key, string.format("groupe %s (%s, %d machine(s)) : pas de raccordement : %s (essai %d/%d)", g.key, g.kind, g.n,
          tostring(err), st.tries[g.key], R.MAX_TRIES))
      end
    else
      note(st, f, tick, g.key, string.format("groupe %s (%s, %d machine(s), projet(s) %s) : %s : %s", g.key, g.kind, g.n,
        table.concat(g.pids, ","), action, why))
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Pas d'une équipe
---------------------------------------------------------------------------------------------------
--- api = { request = Build.request, prio = priorité des projets de raccordement } (build.lua n'est pas requis ici).
function Ra.step(api, f, surface, tick)
  local b = f.build
  if not b then return end
  if b.opts and b.opts.raccord == false then return end -- interrupteur D'ESSAI (remote fo-ia1d set_option) : témoin des bancs
  local st = b.raccord
  if not st then
    st = { next = tick + R.PERIOD, seen = {}, tries = {}, last_try = {}, open = {}, said = {}, log_next = 0, last_groups = 0,
      n = { demandes = 0, finis = 0, refuses = 0, repares = 0, fils = 0 } }
    b.raccord = st
  end
  st.last_try = st.last_try or {} -- (état d'un premier relevé de ce lot sans ce champ)
  st.waited = st.waited or {} -- (lot FONDERIE, 0.6.44) même chose
  st.waited_lost = st.waited_lost or {} -- (lot COURANT2) relevés « laisser » derrière un poteau perdu, par groupe
  st.rot = st.rot or 0 -- (lot COURANT2) départ de la fenêtre tournante des groupes décidés
  local c = st.cyc
  local P = api.prof
  if not c then
    local lj = st.lj
    if not lj then
      if tick < st.next then return end
      -- (revue de la 0.6.59, point 7 : la centrale est lue AVANT le jeton ; rien à relever, le jeton reste aux autres)
      -- rien à relever tant que la centrale n'est pas finie (b.plant) : [FO-RESEAU] et la construction s'en chargent
      local pp = b.plant and b.projects[b.plant]
      -- lot ENERGIE (2/11) : une centrale rouverte pour un poteau (chantier) ne ferme plus le relevé : sans cela, un seul poteau sûr rouvert et
      -- jamais posé (PNJ qui évitent l'ennemi) retenait le raccordement du second chemin (mesuré au banc energie-ilot-ennemi)
      local reopened_ok = pp and (pp.reopened or 0) > 0 and pp.state ~= "attente" and pp.state ~= "plan" and pp.state ~= "refuse" and not Rv.coupure_off(b)
      if not (pp and (pp.state == "fini" or reopened_ok)) then
        st.next = tick + R.PERIOD
        return
      end
      -- Lot POULS : le début de relevé (live_networks : une recherche sur toute la surface) ne tombe jamais sur le tick d'une bande du relevé du
      -- réseau (script/team/reseau_vivant.lua) ni sur un autre début (autre équipe) : jeton du tick (api.jeton, script/team/pouls_jeton.lua).
      -- Jeton pris : rien de fait, l'horloge intacte, nouvel essai à la passe suivante.
      -- Lot LOURD (point 2) : coût déclaré au jeton (script/core/lourd.lua) : chunks de la première bande ; sans boîte, tout le budget.
      -- Lot LOURD, suite (0.6.63, décision du lead du 8/11) : par le chemin d'un bloc (ci-dessous), Ra.COUT_REGISTRE quand le registre des
      -- génératrices sert VRAIMENT (Gens.serves, mêmes arguments que live_networks : aucune recherche du moteur) ; sinon tout le budget
      -- (Gens.list repart sur une recherche sur toute la surface). tests/ra_bloc_test.lua (R2) : le coût suit ce qui est relevé.
      local box = api.box and api.box(surface)
      local bloc = not box or Gens.ready()
      local cost
      if bloc then
        cost = Gens.serves(surface, f.force, GEN_TYPES) and Ra.COUT_REGISTRE or nil
      else
        cost = Ra.cout(box.y0, box.y1 + 1, box.x1 + 1 - box.x0)
      end
      if api.jeton and not api.jeton.take(tick, (f.key or "player") .. ":ra", api.pulse, cost) then return end
      st.next = tick + R.PERIOD
      -- Lot LOURD : boîte des chunks connue (api.box) : relevé des générateurs par bandes (st.lj), une bande par passe sous le jeton ; la
      -- centrale n'est lue qu'ici, au départ, comme avant. L'horloge est posée ici : la cadence des cycles est celle d'avant, le cycle
      -- commence quand la dernière bande est faite. Sans boîte (bancs d'avant ce lot) : d'un bloc, comme avant.
      -- Lot X10-S4 : registre des génératrices prêt (script/team/generateurs.lua, en jeu toujours) : d'un bloc aussi, car live_networks ne
      -- lit plus que les génératrices de l'équipe (O(génératrices), réseaux lus maintenant) ; les bandes restent le chemin sans registre.
      if bloc then
        if P then P.fstart("ra:debut") end
        st.cyc = start_cycle(f, surface, b, api.champ_live)
        if P then P.fstop("ra:debut") end
        return
      end
      lj = gen_job_new(box)
      st.lj = lj
    elseif api.jeton and not api.jeton.take(tick, (f.key or "player") .. ":ra", api.pulse, Ra.cout(lj.y, lj.y_end, lj.x1 - lj.x0)) then
      return
    end
    local done = false
    for _ = 1, Ra.BANDS_PER_PULSE do
      if P then P.fstart("ra:bande") end
      done = gen_band(f, surface, lj)
      if P then P.fstop("ra:bande") end
      if done then break end
    end
    if not done then return end
    st.lj = nil
    if P then P.fstart("ra:debut") end
    local live, n = gen_finish(lj)
    st.cyc = start_cycle(f, surface, b, api.champ_live, live, n)
    if P then P.fstop("ra:debut") end
    return
  end
  for _ = 1, R.UNITS_PER_PULSE do
    local u = c.units[c.i]
    if not u then break end
    c.i = c.i + 1
    scan_unit(f, surface, b, c, u)
  end
  if c.i > #c.units then
    -- revue de la 0.6.59, point 1 : la fin peut relire toute la surface (« relier » : live_networks) : sous le jeton du tick ; pris, elle
    -- passe au pouls suivant (relevé fini, rien d'autre ne bouge)
    local fin_par = (f.key or "player") .. ":ra"
    if api.jeton and not api.jeton.take(tick, fin_par, api.pulse) then return end
    st.cyc = nil
    if P then P.fstart("ra:fin") end
    finish_cycle(api, f, surface, b, st, c, tick)
    if P then P.fstop("ra:fin") end
  end
end

return Ra
