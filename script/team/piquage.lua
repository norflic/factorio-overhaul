--[[
  Lot PIQUAGE (demande du DC du 8/11, en jouant la 0.6.65) : l'entrée d'un bloc servie à la main (coffre de quai + bras + tournées « fill » de
  PNJ) est alimentée, quand cela paie, par le SURPLUS d'un tapis existant qui porte son objet. Règle pure : shared/team/piquage.lua (lire son
  en-tête). Ce fichier lit le monde et applique ; il ne décide rien d'autre que ce que la règle rend.

  1. RELEVÉ (Piquage.step) : une fois par Ln.PERIOD, comme la liaison (script/team/liaison.lua), les quais d'entrée des projets FINIS ; pour
     chaque quai qui peut un jour se payer, DÉCOUVERTE des tuiles de tapis HORS PLAN (aucune tuile réservée par un projet) à portée qui portent SON
     objet seul (au plus MAX_TRACK, une fois par DISC_EVERY), puis un relevé de ces tuiles à chaque passage (Pq.observe : nombres seuls, jamais d'entité).
  2. DÉCISION : tuiles retenues (Pq.tile_verdict : dense, droite, alimentée, prolongée), côtés libres, Pq.rank contre les sorties de module que la
     liaison voit déjà (b.liaison.seen : la liaison garde sa place si elle paie mieux) ; Li.decide ; une demande par relevé.
  3. PROJET : Build.request({ liaison = { piquage = true, ... } }) : même famille que la liaison (rôles liaison-*, pile « capital », garde de
     la centrale), tracé de la sortie du répartiteur au bras du quai (Trav.route, souterrains), un bras, un poteau. Le RÉPARTITEUR n'est pas une entité du
     projet : son objet est compté aux besoins du projet (build.lua, needs_of) pour que le cerveau le fabrique et que la réserve le retienne.
  4. FIN : le script remplace le tapis par le répartiteur SUR PLACE (surface.create_entity{fast_replace}, comme l'amélioration des tapis,
     script/team/convoyeurs.lua), écrit tout de suite la priorité de sortie sur le tapis PRINCIPAL (l'aval n'est jamais affamé : la branche ne
     reçoit que le surplus), pose la barre du coffre d'entrée (Li.bar). Le coffre reste en tampon (Pq.CHEST).
  5. SUIVI : répartiteur disparu = remplacé (3 essais), puis « coupe » ; le coffre qui baisse rend sa tournée au PNJ sans rien d'autre.

  Réglage maître : fo-war-industrie (Rsv.on), comme la liaison. État : b.piquage (nombres, chaînes, tables ; jamais de fonction ni d'entité).
  Journal [FO-PIQUAGE] (format : Pq.line). Interface de BANC (remote fo-piquage) : report, set_param.
]]

local Pq = require("shared.team.piquage")
local Tv = require("shared.team.traversee") -- lot COLONNES : tracé virtuel et preuve des paires souterraines
local Li = require("shared.team.liaison")
local M = require("shared.team.modules")
local P = require("shared.team.plan")
local T = require("shared.team.config")
local State = require("script.faction.state")
local Conv = require("script.team.convoyeurs")
local Stock = require("script.team.stock")
local Rsv = require("script.ai3.reserve")
local Registry = require("script.companion.registry")
local Pur = require("script.team.purete") -- lot PURETE-TAPIS : la branche ne verse sur aucun tapis étranger, aucun tapis étranger ne verse sur elle ni sur le répartiteur
local LAST_SEARCH = -1 -- tick de la dernière recherche de branche (local au module, jamais dans global)

local Piquage = {}

Piquage.MAX_TRACK = 12     -- tuiles suivies au plus par quai
Piquage.MAX_SCAN = 300     -- tapis lus au plus à une découverte
Piquage.DISC_EVERY = 10 * 3600 -- ticks entre deux découvertes pour un quai (s'il suit moins de MAX_TRACK tuiles)
Piquage.EMPTY_RETRY = 3 * 3600 -- ... ou 3 min quand aucune tuile n'est suivie (le tapis peut se remplir plus tard : micro-banc 8/11, découverte unique à t=0 sur un tapis vide)
Piquage.ROUTE_WEIGHT = 1.4 -- A* pondéré de la branche : au plus 1,4 fois le meilleur tracé, bien moins de noeuds
Piquage.ROUTE_NODES = 300  -- noeuds développés au plus par recherche (~870 instructions chacun mesurées : ~0,26 million, test « pire cas borné »)
Piquage.ROUTE_SLICE = 200  -- lot PIQUAGE-COUT : états développés au plus par pensée (tracé par tranches, ctx.phase_slice de Tv.route ; phase B ~1 100 instructions par état)
Piquage.SPLIT_TRIES = 3    -- poses du répartiteur au plus par liaison
Piquage.EVAL_MAX = 3       -- quais évalués (lecture des côtés libres) au plus par relevé

local DEAD = { refuse = true }
local SKIP_KEYS = { "alim", "alimquai", "raccord", "enceinte", "liaison", "site", "quartier" }
local POLE_SET = {}
for _, name in ipairs(M.POLES) do POLE_SET[name] = true end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function say(f, text)
  log(text)
end

local function note(st, key, text)
  if st.said[key] == text then return false end
  st.said[key] = text
  return true
end

--- Verdict d'un quai en MOTS FIXES (Pq.VERDICT_CODES, Pq.CAUSE_CODES), lu en lecture seule par la vue du cerveau (b.piquage.quais) : au plus une entrée
--- par quai, retirée avec le quai ; le tick ne change qu'avec le verdict ou la cause.
local function mark(st, key, verdict, cause, tick)
  local q = st.quais[key]
  if q and q.verdict == verdict and q.cause == cause then return end
  st.quais[key] = { verdict = verdict, cause = cause, tick = tick }
end

local function cause_of(action, reason, top)
  if reason:find("a confirmer", 1, true) then return "a_confirmer" end
  if reason:find("menace", 1, true) then return "menace" end
  if reason:find("ennemi", 1, true) then return "ennemi" end
  if reason:find("sans effet", 1, true) then return "essais_epuises" end
  if action == "laisser" and top and top.code and top.code ~= "ok" then return top.code end
  return "ne_se_paie_pas"
end

local function new_state(tick)
  return { next = tick + Li.PERIOD, seen = {}, tries = {}, last_try = {}, links = {}, said = {}, track = {}, disc = {}, flow = {}, quais = {}, bilan = {},
    log_next = 0, n = { demandes = 0, finis = 0, refuses = 0, poses = 0, coupees = 0 } }
end

local function minutes(tick) return tick / 3600 end

---------------------------------------------------------------------------------------------------
-- Données du jeu (aucun nom écrit ici)
---------------------------------------------------------------------------------------------------
local BELT_NAMES -- cache local (jamais dans global) : noms des tapis des données

local function belt_names()
  if BELT_NAMES then return BELT_NAMES end
  local out = {}
  for _, b in ipairs(Conv.belts()) do out[#out + 1] = b.name end
  BELT_NAMES = out
  return out
end

--- Répartiteur le moins cher dont la recette est débloquée pour la force : { name, item } ou nil (comme script/team/champ.lua, logistic).
local function pick_splitter(f)
  local protos = game.get_filtered_entity_prototypes({ { filter = "type", type = T.LOGISTIC_TYPES.splitter } })
  local list = {}
  for name, pr in pairs(protos) do
    local items = pr.items_to_place_this
    if items and items[1] and not pr.has_flag("hidden") then
      list[#list + 1] = { name = name, speed = pr.belt_speed or 0, item = items[1].name }
    end
  end
  table.sort(list, function(a, b) if a.speed ~= b.speed then return a.speed < b.speed end return a.name < b.name end)
  local force = game.forces[f.force]
  for _, x in ipairs(list) do
    local r = force and force.recipes[x.item]
    if r ~= nil and r.enabled == true then return x end
  end
  return nil
end

local function belt_item(name)
  for _, b in ipairs(Conv.belts()) do if b.name == name then return b.item end end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Lecture du monde
---------------------------------------------------------------------------------------------------
local function eligible(p)
  if not p or p.state ~= "fini" or p.abandoned or not p.spec then return false end
  for _, k in ipairs(SKIP_KEYS) do if p.spec[k] then return false end end
  local first = p.parts and p.parts[1]
  if first and first.kind == "centrale" then return false end
  return true
end

local function chest_at(f, surface, x, y)
  return surface.find_entities_filtered({ position = { x, y }, radius = 0.4, force = f.force, type = "container", limit = 1 })[1]
end

local function inflow_of(st, p)
  if p.inflow then return p.inflow end
  local c = st.flow[p.id]
  if c == nil then
    c = false
    local spec = p.spec
    local fn = spec and spec.gen and M.GEN[spec.gen]
    if fn then
      local ok, g = pcall(M.with_pole, spec.pole, fn, table.unpack(spec.args or {}))
      if ok and g and g.inputs then
        c = {}
        for _, k in ipairs(sorted_keys(g.inputs)) do c[k] = g.inputs[k] end
      end
    end
    st.flow[p.id] = c
  end
  return c or nil
end

local function dist_hq(f, x, y)
  local hq = f.hq_pos
  if not hq then return 0 end
  local dx, dy = x - hq.x, y - hq.y
  return math.sqrt(dx * dx + dy * dy)
end

local function free_workers(f)
  local n = 0
  for _, id in ipairs(State.sorted_keys(f.engineers or {})) do
    local a = Registry.get(id)
    if a and a.entity and a.entity.valid and (not a.task or a.task.safe) then n = n + 1 end
  end
  return n
end

local function hq_threat(f, surface)
  if not (f.hq and f.hq.valid and f.hq_pos) then return false end
  return surface.count_entities_filtered({ position = f.hq_pos, radius = T.hq_threat_radius, force = "enemy", type = "unit", limit = 1 }) > 0
end

local function enemy_near(f, surface, x, y)
  return surface.find_nearest_enemy({ position = { x = x, y = y }, max_distance = Li.ENEMY_R, force = f.force }) ~= nil
end

local function belt_at(f, surface, x, y)
  return surface.find_entities_filtered({ position = { x + 0.5, y + 0.5 }, radius = 0.4, name = belt_names(), force = f.force, limit = 1 })[1]
end

--- Un relevé d'une tuile : { count = objets voulus (deux voies), other = objets d'une autre nature }.
local function sample_belt(ent, item)
  local n, other = 0, 0
  for i = 1, 2 do
    local c = ent.get_transport_line(i).get_contents()
    for _, name in ipairs(sorted_keys(c)) do
      if name == item then n = n + c[name] else other = other + c[name] end
    end
  end
  return { count = n, other = other }
end

--- Tuile libre pour une pièce du piquage : ni projet de l'équipe (b.occ), ni eau, ni entité qui occupe le sol (arbre compris si `strict`).
local function tile_free(b, surface, x, y, strict)
  if b.occ[P.tkey(x, y)] then return false end
  local tl = surface.get_tile(x, y)
  if tl and tl.valid and tl.collides_with("water-tile") then return false end
  local hits = surface.find_entities_filtered({ area = { { x + 0.05, y + 0.05 }, { x + 0.95, y + 0.95 } }, collision_mask = "object-layer" })
  for _, e in ipairs(hits) do
    if strict or not (e.type == "tree" or e.type == "simple-entity" or e.force.name == "neutral") then return false end
  end
  return true
end

---------------------------------------------------------------------------------------------------
-- Relevé
---------------------------------------------------------------------------------------------------
local function scan_unit(f, surface, b, st, c, pid)
  local p = b.projects[pid]
  if not eligible(p) then return end
  local flows = inflow_of(st, p)
  local seen = {}
  for idx, q in ipairs(p.quais or {}) do
    local ch = q.item and chest_at(f, surface, q.x, q.y)
    local tk = math.floor(q.x) .. ":" .. math.floor(q.y) .. ":" .. tostring(q.item)
    if ch and not seen[tk] then
      seen[tk] = true
      c.docks[#c.docks + 1] = { key = pid .. ":q" .. idx, pid = pid, idx = idx, x = math.floor(q.x), y = math.floor(q.y), item = q.item,
        flow = q.flow or (flows and flows[q.item]) or 0, n = ch.get_item_count(q.item) }
      c.tours = c.tours + (q.tours or 0)
      c.items = c.items + (q.filled or 0)
    end
  end
end

local function start_cycle(b)
  local units = {}
  for _, pid in ipairs(b.order) do
    if eligible(b.projects[pid]) then units[#units + 1] = pid end
  end
  return { units = units, i = 1, docks = {}, tours = 0, items = 0 }
end

--- Découverte : tuiles de tapis à portée du quai qui portent son objet SEUL. Garde au plus MAX_TRACK (les plus proches du quai).
local function discover(f, surface, st, d, tick)
  local tr = st.track[d.key]
  if not tr then tr = { tiles = {}, order = {} }; st.track[d.key] = tr end
  st.disc[d.key] = tick
  local R = Pq.SEARCH_SPAN
  local ents = surface.find_entities_filtered({ area = { { d.x - R, d.y - R }, { d.x + R + 1, d.y + R + 1 } }, name = belt_names(), force = f.force,
    limit = Piquage.MAX_SCAN })
  -- tapis du plan que leur projet déclare piquables (p.tapis_piquable = { {x, y, item} }, tuiles entières : lignes de rapatriement)
  local opt_in = {}
  for _, pid in ipairs(f.build.order) do
    local q = f.build.projects[pid]
    if q and q.state == "fini" and q.tapis_piquable then
      for _, t in ipairs(q.tapis_piquable) do opt_in[t.x .. ":" .. t.y] = t.item end
    end
  end
  -- lignes de liaison finies (sortie de module ou tampon -> bras -> tapis -> quai) : leurs tuiles de tapis sont des SOURCES pour les autres quais du
  -- même objet (le tapis s'accumule quand le quai servi est plein : surplus). Jamais une branche de piquage elle-même (pas de piquage en chaîne).
  for _, pid in ipairs(f.build.order) do
    local q = f.build.projects[pid]
    local ls = q and q.state == "fini" and q.spec and q.spec.liaison
    if ls and not ls.piquage and ls.item then
      for _, e in ipairs(q.ents or {}) do
        if e.role == "liaison-tapis" and not e.type then opt_in[math.floor(e.x) .. ":" .. math.floor(e.y)] = ls.item end
      end
    end
  end
  -- lignes des AUTRES projets finis du plan (sorties de modules, lignes de fonderie, champs) : sources aussi, hors têtes d'alimentation (rôle « tete »),
  -- hors souterrains, hors branches de piquage et hors projet du quai lui-même. Sans cela une partie avancée n'a aucun tapis « hors plan »
  -- (dcsave du 8/11 : « aucune_source » pour 14 à 21 quais par équipe). Le surplus seul passe au quai (priorité de sortie sur la ligne).
  local plan_ok = {}
  for _, pid in ipairs(f.build.order) do
    local q = f.build.projects[pid]
    if q and q.state == "fini" and q.id ~= d.pid and not (q.spec and q.spec.liaison and q.spec.liaison.piquage) then
      for _, e in ipairs(q.ents or {}) do
        if e.role ~= "tete" and not e.type and e.name and Conv.is_belt(e.name) then plan_ok[math.floor(e.x) .. ":" .. math.floor(e.y)] = true end
      end
    end
  end
  local found = {}
  for _, e in ipairs(ents) do
    local tx, ty = math.floor(e.position.x), math.floor(e.position.y)
    local key = tx .. ":" .. ty
    -- les tapis du PLAN directeur (tuiles réservées par un projet : têtes de quai, lignes de modules, champs, liaisons) ne sont jamais piqués,
    -- sauf ceux que leur projet déclare piquables (opt_in) : seuls comptent les tapis posés hors plan (par le joueur, ou à la main par l'équipe)
    if not tr.tiles[key] and (not f.build.occ[P.tkey(tx, ty)] or opt_in[key] == d.item or plan_ok[key]) then
      local s = sample_belt(e, d.item)
      if s.count > 0 and s.other == 0 then
        found[#found + 1] = { key = key, x = tx, y = ty, dir = e.direction, sample = s, m = Li.manhattan(tx, ty, d.x, d.y) }
      end
    end
  end
  table.sort(found, function(a, c) if a.m ~= c.m then return a.m < c.m end return a.key < c.key end)
  for _, t in ipairs(found) do
    if #tr.order >= Piquage.MAX_TRACK then break end
    tr.tiles[t.key] = { x = t.x, y = t.y, dir = t.dir, obs = Pq.observe(nil, t.sample) }
    tr.order[#tr.order + 1] = t.key
  end
end

--- Relevé des tuiles suivies ; une tuile dont le tapis a disparu ou a changé de sens est oubliée.
local function observe_tracks(f, surface, st, d)
  local tr = st.track[d.key]
  if not tr then return end
  local keep = {}
  for _, key in ipairs(tr.order) do
    local t = tr.tiles[key]
    local e = belt_at(f, surface, t.x, t.y)
    if e and e.direction == t.dir then
      t.obs = Pq.observe(t.obs, sample_belt(e, d.item))
      keep[#keep + 1] = key
    else
      tr.tiles[key] = nil
    end
  end
  tr.order = keep
end

---------------------------------------------------------------------------------------------------
-- Évaluation d'un quai : candidats, côtés libres, sorties de module vues par la liaison
---------------------------------------------------------------------------------------------------
local function dock_sites(b, surface, d)
  return Li.sites(d.x, d.y, function(x, y) return tile_free(b, surface, x, y, false) end)
end

--- Sorties de module que la liaison apparie à ce quai (b.liaison.seen : « quai>sortie »), avec leur éloignement. Lecture seule.
local function liaison_outs(b, d)
  local out = {}
  local ln = b.liaison
  if not ln or not ln.seen then return out end
  local prefix = d.key .. ">"
  for _, k in ipairs(sorted_keys(ln.seen)) do
    if k:sub(1, #prefix) == prefix then
      local skey = k:sub(#prefix + 1)
      local pid, idx = skey:match("^(%d+):o(%d+)$")
      local sp = pid and b.projects[tonumber(pid)]
      local o = sp and sp.outs and sp.outs[tonumber(idx)]
      if o then out[#out + 1] = { key = skey, span = Li.manhattan(math.floor(o.x), math.floor(o.y), d.x, d.y) } end
    end
  end
  return out
end

local function build_cands(f, surface, b, st, d)
  local tr = st.track[d.key]
  local cands = {}
  if not tr then return cands end
  local sites = dock_sites(b, surface, d)
  if #sites == 0 then return cands end
  for _, key in ipairs(tr.order) do
    local t = tr.tiles[key]
    local ok0 = Pq.tile_verdict({ obs = t.obs, shape = "straight", back = true, front = true })
    if ok0 and #cands < Pq.MAX_CANDS then
      local e = belt_at(f, surface, t.x, t.y)
      if e and e.direction == t.dir then
        local v = Li.DV[t.dir]
        local back, front = false, false
        local nb = e.belt_neighbours
        for _, i in ipairs(nb and nb.inputs or {}) do
          if math.floor(i.position.x) == t.x - v[1] and math.floor(i.position.y) == t.y - v[2] and i.direction == t.dir then back = true end
        end
        front = nb ~= nil and #(nb.outputs or {}) > 0
        local sides = {}
        for _, side in ipairs({ "left", "right" }) do
          local g = Pq.geometry(t.x, t.y, t.dir, side)
          local behind = belt_at(f, surface, g.side_tile.x - v[1], g.side_tile.y - v[2])
          local feeds = behind ~= nil and behind.direction == t.dir -- un tapis parallèle alimenterait aussi le répartiteur
          if not feeds and tile_free(b, surface, g.side_tile.x, g.side_tile.y, true) and tile_free(b, surface, g.branch.x, g.branch.y, false) then
            local best
            for _, s in ipairs(sites) do
              local m = Li.manhattan(g.branch.x, g.branch.y, s.bx, s.by)
              if not best or m < best then best = m end
            end
            if best then sides[side] = { span = best } end
          end
        end
        cands[#cands + 1] = { key = key, x = t.x, y = t.y, dir = t.dir, obs = t.obs, shape = back and "straight" or "curve", back = back, front = front,
          sides = sides }
      end
    end
  end
  return cands
end

---------------------------------------------------------------------------------------------------
-- Noms des pièces (lus aux projets du module d'arrivée)
---------------------------------------------------------------------------------------------------
local function pick_names(dp)
  local arm, pole
  local nm = dp.spec and dp.spec.names
  local best_arm, best_rate, best_pole, best_wire
  for _, e in ipairs(dp.ents or {}) do
    local s = M.spec(e.name)
    if s and (e.role == "quai-bras" or e.role == "sortie-bras") and not s.burner and s.reach == 1 then
      if not best_rate or s.rate < best_rate or (s.rate == best_rate and e.name < best_arm) then best_arm, best_rate = e.name, s.rate end
    elseif s and POLE_SET[e.name] and s.w == 1 and s.h == 1 then
      if not best_wire or s.wire > best_wire or (s.wire == best_wire and e.name < best_pole) then best_pole, best_wire = e.name, s.wire end
    end
  end
  arm = (nm and nm.arm) or best_arm
  pole = (nm and nm.pole) or best_pole
  return arm, pole or M.DEFAULT_POLE
end

---------------------------------------------------------------------------------------------------
-- Suivi des liaisons ouvertes : pose du répartiteur, barre, vie
---------------------------------------------------------------------------------------------------
local function apply_bar(api, f, surface, b, link)
  local dp = b.projects[link.dock_pid]
  local q = dp and dp.quais and dp.quais[link.dock_idx]
  if not (q and q.item) then return end
  local ch = chest_at(f, surface, q.x, q.y)
  if not ch then return end
  local proto = game.item_prototypes[q.item]
  local inv = ch.get_inventory(defines.inventory.chest)
  local want = Li.bar(api.fill, proto and proto.stack_size or 1)
  if inv.supports_bar() and inv.get_bar() ~= want then inv.set_bar(want) end
end

local function split_entity(f, surface, lc)
  local g = lc.geo
  return surface.find_entities_filtered({ position = { g.x, g.y }, radius = 0.6, name = lc.split, force = f.force, limit = 1 })[1]
end

--- Remplace le tapis source par le répartiteur et écrit la priorité. Rend true, ou false et la raison.
local function place_split(f, surface, p, lc)
  local g = lc.geo
  local item = lc.extra and lc.extra.item
  if not item then return false, "repartiteur inconnu" end
  if Stock.count(f, item) < 1 then return false, "aucun repartiteur au coffre" end
  local belt = belt_at(f, surface, g.tile.x, g.tile.y)
  if not belt then return false, "tapis source disparu" end
  if belt.direction ~= g.dir then return false, "tapis source tourne" end
  -- lot PURETE-TAPIS : la seconde entrée du répartiteur (derrière sa tuile latérale) est relue à la POSE (elle n'était lue qu'à la décision) : un tapis
  -- de n'importe quelle force, tourné vers le répartiteur, y déverserait son objet sur le tapis principal
  do
    local v = Li.DV[g.dir]
    for _, r in ipairs(Pur.feeding(surface, g.side_tile.x, g.side_tile.y)) do
      if r.dir == g.dir and r.x == g.side_tile.x - v[1] and r.y == g.side_tile.y - v[2] then
        return false, "tapis etranger derriere la tuile laterale du repartiteur"
      end
    end
  end
  if not surface.can_fast_replace({ name = lc.split, position = { g.x, g.y }, direction = g.dir, force = f.force }) then
    return false, "remplacement sur place refuse par le moteur"
  end
  -- le remplacement sur place détruit l'entité du tapis : son nom est lu AVANT (lu après, LuaEntity invalide, plantage en partie 0.7.90)
  local belt_name = belt.name
  local old_item = belt_item(belt_name)
  local ent = surface.create_entity({ name = lc.split, position = { g.x, g.y }, direction = g.dir, force = f.force, fast_replace = true, spill = false,
    raise_built = false })
  if not ent then return false, "pose refusee" end
  Stock.remove(f, item, 1)
  if old_item then Stock.insert(f, old_item, 1) end
  ent.splitter_output_priority = g.priority
  -- la pièce de tapis remplacée appartenait peut-être à un projet du plan (liaison, rapatriement) : son relevé de pièces doit dire « répartiteur »
  -- (sinon la reconstruction croirait le tapis détruit et le referait par-dessus le répartiteur)
  local b = f.build
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and q ~= p then
      for _, e in ipairs(q.ents or {}) do
        if e.name == belt_name and math.floor(e.x) == g.tile.x and math.floor(e.y) == g.tile.y then
          e.name, e.x, e.y, e.dir, e.item, e.piq = lc.split, g.x, g.y, g.dir, item, true
        end
      end
    end
  end
  return true, ent.splitter_output_priority
end

local function follow_links(api, f, surface, b, st, tick)
  for _, dkey in ipairs(sorted_keys(st.links)) do
    local link = st.links[dkey]
    local q = b.projects[link.pid]
    local lc = q and q.spec and q.spec.liaison
    local dock = { key = dkey, item = link.item, flow = link.flow, dist = link.dist }
    if not q then
      st.links[dkey] = nil
    elseif q.state == "fini" then
      if not link.done then
        link.done = true
        st.n.finis = st.n.finis + 1
        mark(st, dkey, "branche_finie", "ok", tick)
        say(f, Pq.line(f.key, dock, "branche finie", string.format("projet %d, %d piece(s), %d fil(s) tire(s) : le repartiteur suit", q.id, #q.ents, q.wired or 0), minutes(tick)))
      end
      apply_bar(api, f, surface, b, link)
      if lc and lc.geo then
        local have = split_entity(f, surface, lc)
        if have then
          if not link.split then
            link.split = true
          end
          if have.splitter_output_priority ~= lc.geo.priority then have.splitter_output_priority = lc.geo.priority end
        elseif (link.split_tries or 0) < Piquage.SPLIT_TRIES then
          local ok, why = place_split(f, surface, q, lc)
          if ok then
            link.split, q.piq_placed = true, true
            st.n.poses = st.n.poses + 1
            mark(st, dkey, "repartiteur_pose", "ok", tick)
            say(f, Pq.line(f.key, dock, "repartiteur pose", string.format("sur le tapis (%d, %d), priorite de sortie du tapis principal : %s (la branche ne recoit que le surplus), coffre du quai garde en tampon",
              lc.geo.tile.x, lc.geo.tile.y, tostring(why)), minutes(tick)))
          else
            mark(st, dkey, "attente", why == "aucun repartiteur au coffre" and "repartiteur_a_fabriquer" or "remplacement_refuse", tick)
            if note(st, dkey .. "#pose", why) then say(f, Pq.line(f.key, dock, "attendre", "repartiteur : " .. tostring(why), minutes(tick))) end
            if why ~= "aucun repartiteur au coffre" then link.split_tries = (link.split_tries or 0) + 1 end
          end
        elseif not link.cut then
          link.cut = true
          mark(st, dkey, "coupe", "remplacement_refuse", tick)
          st.n.coupees = st.n.coupees + 1
          say(f, Pq.line(f.key, dock, "coupe", string.format("%d pose(s) du repartiteur refusee(s) : la branche reste inerte, le PNJ continue a la main", Piquage.SPLIT_TRIES), minutes(tick)))
        end
        -- livraison : coffre au-dessus de la barre basse, ou tapis de la branche chargé
        if link.split and not link.cut then
          local ch = chest_at(f, surface, lc.dock.x + 0.5, lc.dock.y + 0.5)
          local n = ch and ch.get_item_count(link.item) or 0
          local branch_n = 0
          local be = belt_at(f, surface, lc.geo.branch.x, lc.geo.branch.y)
          if be then branch_n = sample_belt(be, link.item).count end
          local live = Pq.delivers(n, api.low, branch_n)
          mark(st, dkey, live and "actif" or "inerte", live and "livre" or "ne_livre_pas", tick)
          if note(st, dkey .. "#vie", live and "actif" or "inerte") then
            say(f, Pq.line(f.key, dock, live and "piquage actif" or "piquage ne livre pas",
              string.format("coffre %d (barre basse %d), %d objet(s) sur la 1re tuile de la branche", n, api.low, branch_n), minutes(tick)))
          end
        end
      end
    elseif DEAD[q.state] or q.abandoned then
      st.n.refuses = st.n.refuses + 1
      mark(st, dkey, "refuse", "projet_refuse", tick)
      say(f, Pq.line(f.key, dock, "piquage refuse", string.format("projet %d : %s ; le PNJ continue a la main", q.id, tostring(q.reason)), minutes(tick)))
      st.links[dkey] = nil
    elseif link.done then
      link.done = false
      st.n.coupees = st.n.coupees + 1
      mark(st, dkey, "coupe", "projet_rouvert", tick)
      say(f, Pq.line(f.key, dock, "coupe", string.format("projet %d rouvert (etat %s) : le coffre baisse, le PNJ reprend le quai", q.id, q.state), minutes(tick)))
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Décision
---------------------------------------------------------------------------------------------------
local function linked_by_liaison(b, key)
  local ln = b.liaison
  return ln and ln.links and ln.links[key] ~= nil
end

local function finish_cycle(api, f, surface, b, st, c, tick)
  follow_links(api, f, surface, b, st, tick)
  local piques, linked = 0, 0
  for _, d in ipairs(c.docks) do
    local l = st.links[d.key]
    if l and l.done then piques = piques + 1 elseif linked_by_liaison(b, d.key) then linked = linked + 1 end
  end
  -- quais candidats : débit, pas déjà servis, qui peuvent se payer au mieux (tapis à 6 tuiles)
  local order = {}
  for _, d in ipairs(c.docks) do
    d.dist = dist_hq(f, d.x, d.y)
    d.fill, d.low = api.fill, api.low
    if st.links[d.key] then
      -- le verdict de la branche vient de follow_links
    elseif linked_by_liaison(b, d.key) then
      mark(st, d.key, "laisser", "sortie_plus_rentable", tick) -- (servi par une liaison : rien à ajouter)
    elseif not (d.item and (d.flow or 0) >= Li.MIN_FLOW) then
      mark(st, d.key, "laisser", "ne_se_paie_pas", tick) -- débit sous Li.MIN_FLOW : rien à économiser
    else
      local best = Pq.worth({ flow = d.flow, dist = d.dist, span = 6, fill = api.fill, low = api.low })
      if best then order[#order + 1] = d else mark(st, d.key, "laisser", "ne_se_paie_pas", tick) end
    end
  end
  table.sort(order, function(a, c2) if a.flow ~= c2.flow then return a.flow > c2.flow end return a.key < c2.key end)
  local threat = hq_threat(f, surface)
  for _, d in ipairs(order) do d.threat = threat end
  local free = free_workers(f)
  local open = 0
  for _, k in ipairs(sorted_keys(st.links)) do if not st.links[k].done then open = open + 1 end end
  local split = nil
  local evals, asked = 0, false
  local seen_now = {}
  for _, d in ipairs(order) do
    -- découverte et relevé (bornés : au plus 3 découvertes par passage)
    local tr = st.track[d.key]
    if not tr or (#tr.order < Piquage.MAX_TRACK and tick - (st.disc[d.key] or -Piquage.DISC_EVERY) >= (st.disc_every or (#tr.order == 0 and Piquage.EMPTY_RETRY or Piquage.DISC_EVERY))) then
      if (c.discovered or 0) < 3 then
        c.discovered = (c.discovered or 0) + 1
        discover(f, surface, st, d, tick)
      end
    else
      observe_tracks(f, surface, st, d)
    end
    tr = st.track[d.key]
    if tr and #tr.order == 0 and (st.disc[d.key] or 0) > 0 then
      mark(st, d.key, "laisser", "aucune_source", tick) -- découverte faite, aucun tapis hors plan qui porte l'objet seul à portée
    end
    local ready = false
    for _, key in ipairs(tr and tr.order or {}) do
      if tr.tiles[key].obs.n >= Pq.MIN_SAMPLES then ready = true break end
    end
    if tr and #tr.order > 0 and not ready then mark(st, d.key, "attente", "releves_insuffisants", tick) end
    if ready and evals < Piquage.EVAL_MAX and not asked then
      evals = evals + 1
      local cands = build_cands(f, surface, b, st, d)
      local ranked = Pq.rank(d, cands, liaison_outs(b, d), {})
      local top = ranked[1]
      if not top then
        mark(st, d.key, "laisser", "aucune_source", tick)
        if note(st, d.key, "aucune") then say(f, Pq.line(f.key, d, "laisser", Pq.why_none(ranked), minutes(tick))) end
      elseif top.kind == "sortie" then
        mark(st, d.key, "laisser", "sortie_plus_rentable", tick)
        if note(st, d.key, "sortie " .. top.key) then
          say(f, Pq.line(f.key, d, "laisser", string.format("la liaison a la sortie %s (%d tuiles) paie mieux que le piquage : %s", top.key, top.span, top.why), minutes(tick)))
        end
      else
        local pk = d.key .. ">" .. top.key
        seen_now[pk] = true
        st.seen[pk] = (st.seen[pk] or 0) + 1
        local last = st.last_try[d.key]
        local inp = { worth = top.ok, worth_why = top.why, open = false, open_total = open, free = free, seen = st.confirm and (st.seen[pk] >= st.confirm and Li.CONFIRM or 0) or st.seen[pk], tries = st.tries[d.key] or 0,
          since_try = last and (tick - last) or Li.RETRY_AFTER, threat = threat }
        if top.ok and inp.seen >= Li.CONFIRM and not threat then
          inp.enemies = enemy_near(f, surface, d.x, d.y) and 1 or 0
        end
        local action, reason = Pq.decide(inp)
        if action == "relier" then
          local dp = b.projects[d.pid]
          local arm, pole = pick_names(dp)
          local belt = Conv.choose(f, d.flow)
          local sp = pick_splitter(f)
          if not (arm and belt) then
            mark(st, d.key, "refuse", "pieces_inconnues", tick)
            if note(st, d.key, "pieces") then say(f, Pq.line(f.key, d, "piquage refuse", not arm and "aucun bras electrique connu du module" or "aucun tapis debloque", minutes(tick))) end
          elseif not sp then
            mark(st, d.key, "refuse", "repartiteur_manquant", tick)
            if note(st, d.key, "repartiteur") then say(f, Pq.line(f.key, d, "piquage refuse", "aucun repartiteur debloque pour la force", minutes(tick))) end
          else
            asked = true
            st.tries[d.key] = (st.tries[d.key] or 0) + 1
            st.last_try[d.key] = tick
            local g = Pq.geometry(top.x, top.y, top.dir, top.side)
            st.site_i = st.site_i or {}
            st.site_i[d.key] = ((st.site_i[d.key] or 0) % Li.ROUTE_TRIES) + 1 -- le site du bras du quai tourne à chaque demande
            local spec = { liaison = { piquage = true, key = d.key, item = d.item, flow = d.flow, arm = arm, pole = pole, belt = belt, split = sp.name,
              extra = { item = sp.item }, geo = g, site_i = st.site_i[d.key], dock = { pid = d.pid, idx = d.idx, x = d.x, y = d.y } },
              prio = api.prio, domain = "infrastructures", pile = "capital", product = d.item }
            local id = api.request(f, spec)
            if id then
              st.links[d.key] = { pid = id, item = d.item, flow = d.flow, dist = d.dist, dock_pid = d.pid, dock_idx = d.idx, done = false, since = tick }
              st.n.demandes = st.n.demandes + 1
              open = open + 1
              st.said[d.key] = nil
              mark(st, d.key, "demande", "ok", tick)
              say(f, Pq.line(f.key, d, "piquage demande", string.format("projet %d : tapis (%d, %d) dense %d fois sur %d, branche %s a %d tuiles du quai, %s (essai %d/%d)",
                id, top.x, top.y, (st.track[d.key].tiles[top.key] or { obs = { dense = 0, n = 0 } }).obs.dense,
                (st.track[d.key].tiles[top.key] or { obs = { dense = 0, n = 0 } }).obs.n, top.side, top.span, reason .. " ; " .. top.why, st.tries[d.key], Li.MAX_TRIES), minutes(tick)))
            end
          end
        else
          mark(st, d.key, action == "attendre" and "attente" or "laisser", cause_of(action, reason, top), tick)
          if note(st, d.key, action .. reason) then say(f, Pq.line(f.key, d, action, reason, minutes(tick))) end
        end
      end
    end
  end
  for _, k in ipairs(sorted_keys(st.seen)) do if not seen_now[k] then st.seen[k] = nil end end
  -- bilan APRÈS l'examen des quais de ce relevé (avant, « non_vu » comptait les quais pas encore examinés)
  local alive = {}
  for _, d in ipairs(c.docks) do alive[d.key] = true end
  for _, k in ipairs(sorted_keys(st.quais)) do
    if not alive[k] and not st.links[k] then st.quais[k] = nil end
  end
  st.bilan = { quais = #c.docks, tapis = linked, piquage = piques, tournees = c.tours, objets = c.items, tick = tick }
  if #c.docks > 0 and tick >= st.log_next then
    st.log_next = tick + Li.LOG_EVERY
    local tally = {}
    for _, d in ipairs(c.docks) do
      local q = st.quais[d.key]
      local k = q and (q.verdict .. "/" .. q.cause) or "non_vu"
      tally[k] = (tally[k] or 0) + 1
    end
    local parts = {}
    for _, k in ipairs(sorted_keys(tally)) do parts[#parts + 1] = k .. " " .. tally[k] end
    say(f, Pq.bilan_line(f.key, { docks = #c.docks, linked = linked, piques = piques, tours = c.tours, items = c.items, minutes = minutes(tick),
      causes = table.concat(parts, ", ") }))
  end
end

--- api = { request = Build.request, prio, fill = Build.QUAI_FILL, low = Build.QUAI_LOW }.
function Piquage.step(api, f, surface, tick)
  local b = f.build
  if not b then return end
  local st = b.piquage
  if not st then
    if not Rsv.on() then return end
    st = new_state(tick)
    b.piquage = st
  end
  if st.off then return end
  local c = st.cyc
  if not c then
    if tick < st.next then return end
    st.next = tick + (st.period or Li.PERIOD)
    if not Rsv.on() then return end
    local pp = b.plant and b.projects[b.plant]
    if not (st.sans_centrale or (pp and pp.state == "fini")) then return end
    st.cyc = start_cycle(b)
    return
  end
  for _ = 1, Li.UNITS_PER_PULSE do
    local pid = c.units[c.i]
    if not pid then break end
    c.i = c.i + 1
    scan_unit(f, surface, b, st, c, pid)
  end
  if c.i > #c.units then
    st.cyc = nil
    finish_cycle(api, f, surface, b, st, c, tick)
  end
end

---------------------------------------------------------------------------------------------------
-- Plan d'un projet de piquage (appelé par plan_project de build.lua quand spec.liaison.piquage)
---------------------------------------------------------------------------------------------------
--- api : les aides locales de build.lua (comme Liaison.plan). Rend true, ou false et la raison.
function Piquage.plan(api, f, surface, p)
  local b = f.build
  local lc = p.spec.liaison
  local dock, g = lc.dock, lc.geo
  if not (dock and g and lc.arm and lc.belt and lc.pole and lc.split) then return false, "piquage: pieces inconnues" end
  if not chest_at(f, surface, dock.x + 0.5, dock.y + 0.5) then return false, "piquage: coffre du quai disparu" end
  local src = belt_at(f, surface, g.tile.x, g.tile.y)
  if not (src and src.direction == g.dir) then return false, "piquage: tapis source disparu" end
  local mg = 6
  local x0, y0 = math.min(dock.x, g.branch.x) - mg, math.min(dock.y, g.branch.y) - mg
  local x1, y1 = math.max(dock.x, g.branch.x) + mg, math.max(dock.y, g.branch.y) + mg
  if x1 - x0 > 120 or y1 - y0 > 120 then return false, "piquage: trop loin" end
  local masks = api.read_masks(x0, y0, x1 + 1, y1 + 1)
  -- tuiles interdites au tracé : tapis, souterrains et répartiteurs du monde (le tapis source et son prolongement compris), tuile devant chacun
  -- (sinon la branche recevrait ce que ce tapis y déverse), tuile latérale du répartiteur
  local solid, guard = {}, {}
  local types = { T.LOGISTIC_TYPES.splitter, T.LOGISTIC_TYPES.underground }
  local world = surface.find_entities_filtered({ area = { { x0, y0 }, { x1 + 1, y1 + 1 } }, name = belt_names() })
  for _, t in ipairs(types) do
    for _, e in ipairs(surface.find_entities_filtered({ area = { { x0, y0 }, { x1 + 1, y1 + 1 } }, type = t })) do world[#world + 1] = e end
  end
  for _, e in ipairs(world) do
    local v = Li.DV[e.direction]
    local bb = e.bounding_box -- un répartiteur occupe deux tuiles : chacune a sa tuile de sortie
    for ty = math.floor(bb.left_top.y + 0.01), math.ceil(bb.right_bottom.y - 0.01) - 1 do
      for tx = math.floor(bb.left_top.x + 0.01), math.ceil(bb.right_bottom.x - 0.01) - 1 do
        solid[P.tkey(tx, ty)] = true
        if v then guard[P.tkey(tx + v[1], ty + v[2])] = true end
      end
    end
  end
  guard[P.tkey(g.branch.x, g.branch.y)] = nil -- la sortie du répartiteur est le départ du tracé
  solid[P.tkey(g.tile.x, g.tile.y)], solid[P.tkey(g.main.x, g.main.y)], solid[P.tkey(g.side_tile.x, g.side_tile.y)] = true, true, true
  -- tapis planifiés ou bâtis du plan directeur : leur tuile de sortie reste libre (comme la liaison)
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and q ~= p and not q.abandoned and not DEAD[q.state] then
      for _, e in ipairs(q.ents) do
        if e.name:find("belt", 1, true) then
          local v = P.DV[e.dir or 0]
          if v then guard[P.tkey(math.floor(e.x) + v[1], math.floor(e.y) + v[2])] = true end
        end
      end
    end
  end
  local planned = {}
  local function inside(x, y) return x >= x0 and x <= x1 and y >= y0 and y <= y1 end
  local function free(x, y)
    if not inside(x, y) then return false end
    local k = P.tkey(x, y)
    return not (masks.water[k] or masks.blocked[k] or b.occ[k] or solid[k] or guard[k] or planned[k])
  end
  local D = { x = dock.x, y = dock.y }
  local sites = Li.sites(D.x, D.y, free)
  table.sort(sites, function(a, c)
    local ma, mc = Li.manhattan(g.branch.x, g.branch.y, a.bx, a.by), Li.manhattan(g.branch.x, g.branch.y, c.bx, c.by)
    if ma ~= mc then return ma < mc end
    return a.dir < c.dir
  end)
  if #sites == 0 then return false, "piquage: aucune place pour un bras contre le coffre du quai" end
  local bounds = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  local function start_ok(x, y) return inside(x, y) and not (masks.water[P.tkey(x, y)] or masks.blocked[P.tkey(x, y)] or b.occ[P.tkey(x, y)] or solid[P.tkey(x, y)]) end
  if not start_ok(g.branch.x, g.branch.y) then return false, "piquage: la sortie du repartiteur n'est pas libre" end
  -- COÛT BORNÉ (8/11, gels de 50 à 400 ms mesurés dans la partie du DC) : UNE recherche de branche par appel et par tick, sur UN site (celui que
  -- demande lc.site_i ; les autres attendent le relevé suivant, qui tourne le site), un A* pondéré (Piquage.ROUTE_WEIGHT) plafonné en noeuds
  -- (Piquage.ROUTE_NODES). Lot COLONNES (chantier 6 du DC) : le tracé des lignes de rapatriement et de liaison (Trav.route), sans gisement ni
  -- détour (une seule recherche) : un obstacle sur le vecteur (tapis perpendiculaire, bâtiment) est franchi par une paire de souterrains.
  if LAST_SEARCH == game.tick then return false, "piquage: une recherche de branche par tick, la suivante au prochain passage", "calcul" end
  local site = sites[((lc.site_i or 1) - 1) % #sites + 1]
  planned = { [P.tkey(site.ax, site.ay)] = true }
  local function cost(x, y)
    if x == g.branch.x and y == g.branch.y then return 1 end
    if not free(x, y) then return nil end
    local k = P.tkey(x, y)
    local cst = 1
    if P.in_street(b.lat, x, y) then cst = P.STREET_COST end
    if masks.clear[k] then cst = cst + 1 end
    return cst
  end
  LAST_SEARCH = game.tick
  -- lot PIQUAGE-COUT : Trav.route fait jusqu'à DEUX recherches (tuiles, puis paires souterraines), chacune plafonnée à ROUTE_NODES : 619 000
  -- instructions d'un tenant au pire. Le MÊME tracé se cherche par tranches (comme le tapis des foreuses, script/team/foreuses_tranches.lua) :
  -- au plus ROUTE_SLICE états par pensée, l'état de la recherche dans p.rs_piq (tables de nombres), jeté si la branche ou le site change.
  local sig = table.concat({ g.branch.x, g.branch.y, g.dir, site.bx, site.by, site.ax, site.ay, tostring(lc.belt), x0, y0, x1, y1 }, ":")
  local rs = p.rs_piq
  if rs and rs.sig ~= sig then rs = nil end
  local tiles, why, tn = api.trav.route(f, surface, p, { x = g.branch.x, y = g.branch.y }, { x = site.bx, y = site.by }, Li.end_dir(site), bounds, cost,
    { belt = lc.belt, sd = g.dir, weight = Piquage.ROUTE_WEIGHT, max = Piquage.ROUTE_NODES, no_ore = true, no_detour = true, no_diag = true, kind = "piquage",
      phase_slice = Piquage.ROUTE_SLICE, phase_state = rs and rs.st or nil })
  if not tiles and why == "pending" then
    p.rs_piq = { sig = sig, st = tn }
    return false, "piquage: trace de la branche en cours (tranches)", "calcul"
  end
  p.rs_piq = nil
  if not tiles then return false, "piquage: " .. tostring(why) end
  do
    local ok, w2 = Li.route_ok(#Tv.virtual_belts(tiles), Li.manhattan(g.branch.x, g.branch.y, site.bx, site.by))
    if not ok then return false, "piquage: " .. w2 end
    -- lot PURETE-TAPIS : preuve de pureté de la branche (causes a, b, c, d) contre une lecture fraîche du monde ; la dernière tuile verse sur le bras du quai
    local pok, pwhy = Pur.check_route(f, surface, p, "piquage", tiles, lc.item, { [P.tkey(site.ax, site.ay)] = true }, nil)
    if not pok then return false, "piquage: " .. pwhy end
  end
  -- le prix réel du tracé : un tracé plus long que l'estimation ne doit pas ruiner le retour (même calcul que la décision)
  local okw, ww = Pq.worth({ flow = lc.flow, dist = dist_hq(f, dock.x, dock.y), tiles = #tiles, fill = api.fill or 400, low = api.low or 60 })
  if not okw then return false, "piquage: " .. ww end
  planned = { [P.tkey(site.ax, site.ay)] = true }
  local taken = { [site.ax .. ":" .. site.ay] = true }
  for _, t in ipairs(tiles) do planned[P.tkey(t.x, t.y)] = true; taken[t.x .. ":" .. t.y] = true end
  local px, py = Li.pole_tile(site, free, taken)
  if not px then return false, "piquage: aucune place pour un poteau contre le bras" end
  -- preuve sur le tracé VIRTUEL (une paire souterraine = des tapis droits), puis celle des paires (Tv.verify), comme la liaison
  local names = { arm = lc.arm, belt = lc.belt, pole = lc.pole, ug = tn and tn.ug }
  local ents = Pq.entities({ geo = g, dst = site, route = tiles, names = names, pole = { px, py } })
  local bad = Pq.verify(g, Pq.entities({ geo = g, dst = site, route = Tv.virtual_belts(tiles), names = names, pole = { px, py } }), D,
    function(x) return x.role == "liaison-tapis" end, function(x) return x.role == "liaison-bras" end)
  if #bad == 0 then bad = Tv.verify(tiles, { x = g.branch.x, y = g.branch.y }, { x = site.bx, y = site.by }, Li.end_dir(site), tn and tn.maxd or 0, nil) end
  if #bad > 0 then return false, "piquage: geometrie fausse (" .. bad[1] .. ")" end
  for _, x in ipairs(ents) do x.part = 1 end
  if not api.reserve_tiles(b, p, ents) then return false, "place" end
  local passable = api.seg_passable(b)
  local wood = api.wood_of(surface, p.ents)
  for _, x in ipairs(p.ents) do
    local a = P.anchor_for(b.lat, x.x, x.y, passable)
    local ax, ay
    if a then ax, ay = a.x, a.y else ax, ay = math.floor(x.x / 8) * 8 + 4, math.floor(x.y / 8) * 8 + 4 end
    local fx, fy = api.free_spot(b, masks, ax, ay, wood)
    if (fx - x.x) * (fx - x.x) + (fy - x.y) * (fy - x.y) > api.REACH * api.REACH then fx, fy = api.free_spot(b, masks, x.x, x.y, wood) end
    x.ax, x.ay = fx, fy
    x.anchor = string.format("%s%g:%g", a and "" or "c", fx, fy)
    x.item = api.item_of(x.name)
  end
  P.sort_build(p.ents)
  p.obstacles, p.obst_keys = {}, {}
  for _, x in ipairs(p.ents) do
    for _, t in ipairs(P.tiles_of(x)) do
      local k = P.tkey(t[1], t[2])
      if masks.clear[k] or wood[k] then api.add_obstacle(p, { x = t[1] + 0.5, y = t[2] + 0.5, anchor = x.anchor, ax = x.ax, ay = x.ay }) end
    end
  end
  p.parts[1] = { kind = "liaison", key = "liaison", ox = g.branch.x, oy = g.branch.y, w = 1, h = 1, power = false }
  p.counted = true
  log(string.format("[FO-PIQUAGE] %s : projet %d planifie (quai %s, %s) : %d tuile(s) de tapis %s, bras %s, poteau %s, de la sortie du repartiteur (%d, %d) au quai (%d, %d), tapis source (%d, %d) vers %d, %d obstacle(s)",
    f.key or "player", p.id, tostring(lc.key), tostring(lc.item), #tiles, lc.belt, lc.arm, lc.pole, g.branch.x, g.branch.y, D.x, D.y, g.tile.x, g.tile.y, g.dir, #p.obstacles))
  return true
end

---------------------------------------------------------------------------------------------------
-- Interface de BANC (jamais appelée par le mod)
---------------------------------------------------------------------------------------------------
local function team_of_key(key)
  if key == "player" then return State.faction("player") end
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and (f.key == key or id == key) then return f end
  end
  return nil
end

remote.add_interface("fo-piquage", {
  --- Module FINI fictif (comme fo-liaison inject) : d = { quais = { {x, y, item} }, inflow = { objet = objets/s }, names = { arm, pole } }.
  --- Le coffre est posé par le banc ; rien n'est bâti ici. Rend le numéro du projet.
  inject = function(key, d)
    local f = team_of_key(key)
    local b = f and f.build
    if not (b and type(d) == "table") then return nil end
    local id = b.next_id
    b.next_id = id + 1
    local x, y = 0, 0
    for _, q in ipairs(d.quais or {}) do x, y = q.x, q.y end
    local p = {
      id = id, spec = { gen = "banc", names = d.names }, state = "fini", created = game.tick, finished = game.tick, parts = {}, ents = {}, wires = {},
      stock = {}, quais = {}, outs = {}, obstacles = {}, fails = 0, prio = 55, domain = "production", counted = true, inflow = d.inflow,
    }
    p.parts[1] = { kind = "module", key = "banc", ox = math.floor(x), oy = math.floor(y), w = 1, h = 1, power = true }
    for _, q in ipairs(d.quais or {}) do p.quais[#p.quais + 1] = { x = q.x, y = q.y, item = q.item } end
    b.projects[id] = p
    b.order[#b.order + 1] = id
    return id
  end,
  set_param = function(key, name, value)
    local f = team_of_key(key)
    local b = f and f.build
    if not b then return nil end
    b.piquage = b.piquage or new_state(game.tick)
    local st = b.piquage
    if name == "period" then st.period = value; st.next = game.tick
    elseif name == "sans_centrale" then st.sans_centrale = value and true or false
    elseif name == "off" then st.off = value and true or false
    elseif name == "confirm" then st.confirm = value
    elseif name == "disc_every" then st.disc_every = value
    else return nil end
    return value
  end,
  report = function(key)
    local f = team_of_key(key)
    local st = f and f.build and f.build.piquage
    if not st then return nil end
    local links = {}
    for _, k in ipairs(sorted_keys(st.links)) do
      local l = st.links[k]
      local q = f.build.projects[l.pid]
      links[#links + 1] = { dock = k, pid = l.pid, done = l.done, split = l.split == true, state = q and q.state or "?", reason = q and q.reason or nil }
    end
    return { n = st.n, links = links, tries = st.tries }
  end,
})

return Piquage
