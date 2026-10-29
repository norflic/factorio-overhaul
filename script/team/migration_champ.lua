--[[
  Lot MIGRATION-CHAMP (retour du DC du 29/10 en jouant la 0.6.16) : « les foreuses thermiques, elles mettent directement dans des
  fours [...] l'idéal, ça serait du coup de revoir l'organisation du champ, en tout cas de parties du champ qui, par exemple, sont sur
  thermique, c'est pas optimal, on met de l'électrique à la place, on enlève les fours ceux qui sont directement sur les ressources, on
  place des foreuses à la place » ; « on veut des rangées de foreuses ». Règle pure : shared/team/migration_champ.lua.

  Tâche de FOND, une pensée toutes les CFG.every ticks par équipe, UN avant-poste à la fois. Un avant-poste de PAIRES foreuse thermique +
  four (celui de T.outposts dont le réceptacle est un four) est migré PAR PARTIES. Pour chaque partie :
    1. (veille)   l'équipe a le plan directeur, un réseau qui produit, l'objet de foreuse électrique, des plaques libres, aucun ennemi à
                  CFG.safe tuiles : la règle choisit une partie du champ (paires voisines d'un même lot de gisement du treillis dont le
                  retrait libère la place d'une ligne de foreuses) ;
    2. (projet)   une demande au PLAN DIRECTEUR (Build.request) : la fonderie à tapis de 0.6.17 (gabarit « smelter », voie de minerai servie
                  par une ligne de foreuses électriques et un collecteur, poteaux, fantômes, PNJ bâtisseurs), dimensionnée à la production
                  de la partie (spec.fixe, spec.paires) et placée près du champ ; les tuiles de la partie comptent comme LIBRES au plan
                  (spec.degel : script/team/build.lua, THAW). Le champ continue de produire pendant que le projet attend ses matières ;
    3. (retrait)  quand le projet a ses matières (état « reserve », raison « degel »), la partie est RETIRÉE (foreuses, fours, contenus
                  rendus au stock) si aucun ennemi n'est à CFG.safe tuiles et s'il reste une paire debout (ou si une ligne neuve a déjà
                  produit), puis le plan reprend (p.degele) : défrichage, fantômes, chantier ;
    4. (chantier) la partie suivante ne démarre que lorsque la ligne neuve a PRODUIT (produits finis de ses fours).
  Une demande annulée ou refusée avant le retrait ne coûte rien. Aucun objet retiré n'est perdu (ce qui ne tient pas au coffre est
  répandu au sol du QG). Le registre de reconstruction n'est pas autorisé à refaire une paire thermique de l'avant-poste migré.

  Journal : [FO-MIGRATION] par étape et par cause (une ligne par changement de cause, au plus CFG.logs lignes courantes par équipe).
  État : f.migration = { next, logs, o = { [id d'avant-poste] = { stage, fails, noop, done, produced, pid, ids, t0, ... } }, cur } :
  nombres, booléens, chaînes et listes de nombres ; jamais d'entité ni de fonction. o.migr (avant-poste) : "en cours", "partiel", "fini".
  Lecteurs : Outposts.extend et Outposts.reopen (pas d'agrandissement thermique), Outposts.status (plus de tournée d'un champ migré),
  script/team/foreuse_swap.lua (pas de remplacement sur place pendant la migration), script/team/build.lua (THAW, porte « degel »).
]]

local T = require("shared.team.config")
local Mod = require("shared.team.modules")
local P = require("shared.team.plan")
local D = require("shared.team.automatisation_donnees")
local Mg = require("shared.team.migration_champ")
local Rc = require("shared.team.reconstruction")
local State = require("script.faction.state")
local Stock = require("script.team.stock")
local Build = require("script.team.build")

local Mig = {}

local CFG = Mg.CFG
local FURNACE_INVENTORIES = { "furnace_source", "furnace_result", "fuel" }

local function sorted_keys(t) return State.sorted_keys(t or {}) end

local function name_of(f) return f.key or "player" end

--- Ligne de journal. `force` : lignes d'étape terminale, comptées à part (jamais coupées par le plafond des lignes courantes).
local function say(f, ms, text, force)
  if force then
    ms.logs_f = (ms.logs_f or 0) + 1
    if ms.logs_f > 40 then return end
  else
    ms.logs = ms.logs + 1
    if ms.logs > CFG.logs then return end
  end
  log("[FO-MIGRATION] " .. name_of(f) .. " : " .. text)
end

--- Une raison d'attente n'est écrite qu'à son changement.
local function say_why(f, ms, st, key, text)
  if st.why_last == key then return end
  st.why_last = key
  say(f, ms, text)
end

---------------------------------------------------------------------------------------------------
-- Lectures
---------------------------------------------------------------------------------------------------
local function is_furnace_kind(kind)
  local spec = T.outposts[kind]
  local proto = spec and game.entity_prototypes[spec.sink]
  return proto ~= nil and proto.type == "furnace"
end

local function box_of(e)
  local p = e.prototype
  return { x = e.position.x, y = e.position.y, w = p.tile_width or 1, h = p.tile_height or 1 }
end

--- Paires foreuse thermique + four VIVANTES de l'avant-poste, et les entités par numéro. Rien n'est écrit.
local function survey(o)
  local drills, sinks, ents = {}, {}, {}
  for _, d in ipairs(o.drill_list or {}) do
    if d.valid and d.name == T.DRILL and d.unit_number then
      local b = box_of(d)
      drills[#drills + 1] = { id = d.unit_number, x = b.x, y = b.y, dir = d.direction, w = b.w, h = b.h }
      ents[d.unit_number] = d
    end
  end
  for _, s in ipairs(o.sinks or {}) do
    if s.valid and s.type == "furnace" and s.unit_number then
      local b = box_of(s)
      sinks[#sinks + 1] = { id = s.unit_number, x = b.x, y = b.y, w = b.w, h = b.h }
      ents[s.unit_number] = s
    end
  end
  return Mg.match(drills, sinks, T.drill_drop), ents
end

--- Lots de gisement du treillis qui portent des paires (clé du lot posée sur chaque paire) : { [clé] = { x0, y0, x1, y1 } }.
local function lots_of(f, o, list)
  local b = f.build
  local ore = T.outposts[o.kind].resource
  local rects = {}
  for _, pr in ipairs(list) do
    local i, j = P.lot_of(b.lat, pr.drill.x, pr.drill.y)
    if i then
      local key = P.lot_key(i, j)
      local l = b.lots[key]
      if l and l.state == "gisement" and l.res == ore then
        pr.lot = key
        if not rects[key] then
          local x0, y0, x1, y1 = P.lot_rect(b.lat, i, j)
          rects[key] = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
        end
      end
    end
  end
  return rects
end

--- Méthode du plan directeur qui fond le produit de l'avant-poste (données de l'exécutant : aucun nom écrit ici).
local function method_of(kind)
  local product = T.outposts[kind] and T.outposts[kind].product
  for _, m in ipairs(D.METHODS) do
    if m.gen == "smelter" and m.feed == "tapis" and m.product == product then return m end
  end
  return nil
end

--- Cadences de la règle (gabarits de modules.lua) pour la méthode `m`, ou nil.
local function rates_of(m)
  local ore = m.args[2]
  local plate = Mod.PLATE_OF[ore]
  local g1 = Mod.GEN.smelter(m.args[1], ore, 1)
  local dg = Mod.GEN.drills(ore, 1)
  local bsp, esp = Mod.spec(T.DRILL), Mod.spec(T.DRILL_ELECTRIC)
  if not (plate and g1 and g1.nominal and g1.nominal[plate] and dg and bsp and esp) then return nil end
  local row_cap = g1.nominal[plate]
  return { burner = bsp.speed, electric = esp.speed, row_cap = row_cap, furnace = row_cap / 2,
    pairs_max = dg.extensions and dg.extensions[1] and dg.extensions[1].max or 1 }
end

local function line_of(ore)
  return function(n)
    local g = Mod.GEN.drills(ore, n)
    if g then return g.w, g.h end
    return nil
  end
end

--- Un réseau qui produit (centrale du plan finie, aucune pièce perdue, production > 0 : script/team/reseau_vivant.lua).
local function power_ok(b)
  return b.sante ~= nil and b.sante.healthy == true
end

local function enemy_near(f, surface, x, y)
  return surface.find_nearest_enemy({ position = { x = x, y = y }, max_distance = CFG.safe, force = f.force }) ~= nil
end

--- Le plan a-t-il posé une entité sur une tuile de la partie (tuiles `thaw`, liste plate) ?
local function uses_thaw(p, thaw)
  local set = {}
  for i = 1, #thaw - 1, 2 do set[P.tkey(thaw[i], thaw[i + 1])] = true end
  for _, e in ipairs(p.ents or {}) do
    for _, t in ipairs(P.tiles_of(e)) do
      if set[P.tkey(t[1], t[2])] then return true end
    end
  end
  return false
end

--- Produits finis des fours de la ligne neuve (au plus 24 fours lus).
local function made_by(f, surface, p)
  local n, seen = 0, 0
  for _, e in ipairs(p.ents or {}) do
    if seen >= 24 then break end
    local proto = game.entity_prototypes[e.name]
    if e.built and proto and proto.type == "furnace" then
      seen = seen + 1
      local found = surface.find_entities_filtered({ position = { e.x, e.y }, radius = 0.6, type = "furnace", force = f.force })
      local fe = found[1]
      if fe and fe.valid then n = n + fe.products_finished end
    end
  end
  return n
end

---------------------------------------------------------------------------------------------------
-- Retrait d'une partie
---------------------------------------------------------------------------------------------------
--- Rend `n` objets au stock ; ce qui ne tient pas est répandu au sol du QG (jamais perdu).
local function give(f, surface, name, n)
  local put = Stock.insert(f, name, n)
  if put < n then surface.spill_item_stack(f.hq_pos, { name = name, count = n - put }, false) end
end

--- Vide un inventaire dans le stock (le surplus qui ne tient pas est répandu au sol du QG). Rend le nombre d'objets repris.
local function empty_into_stock(f, surface, inv, got)
  if not inv then return 0 end
  local c = inv.get_contents()
  local n = 0
  for _, name in ipairs(sorted_keys(c)) do
    local count = c[name]
    give(f, surface, name, count)
    got[name] = (got[name] or 0) + count
    n = n + count
  end
  return n
end

--- Retire les paires `st.ids` encore debout : l'ancienne n'est plus « possédée » AVANT d'être retirée (sinon on_entity_destroyed compterait
--- une perte d'avant-poste), contenus et objets rendus au stock. Rend (paires retirées, objets rendus { [nom] = n }).
local function retire(f, surface, o, st, list, ents)
  local byid = {}
  for _, pr in ipairs(list) do byid[pr.id] = pr end
  local got, removed, gone_drills, gone_sinks = {}, 0, {}, {}
  for _, id in ipairs(st.ids) do
    local pr = byid[id]
    if pr then
      local d, s = ents[pr.id], ents[pr.sink_id]
      if d and d.valid then
        empty_into_stock(f, surface, d.get_fuel_inventory(), got)
        State.disown(d.unit_number)
        give(f, surface, d.name, 1)
        got[d.name] = (got[d.name] or 0) + 1
        gone_drills[d.unit_number] = true
        d.destroy()
        removed = removed + 1
      end
      if s and s.valid and not gone_sinks[pr.sink_id] then
        for _, inv_name in ipairs(FURNACE_INVENTORIES) do
          empty_into_stock(f, surface, s.get_inventory(defines.inventory[inv_name]), got)
        end
        State.disown(s.unit_number)
        give(f, surface, s.name, 1)
        got[s.name] = (got[s.name] or 0) + 1
        gone_sinks[pr.sink_id] = true
        s.destroy()
      end
    end
  end
  local keep_d, keep_s = {}, {}
  for _, d in ipairs(o.drill_list or {}) do
    if d.valid and not (d.unit_number and gone_drills[d.unit_number]) then keep_d[#keep_d + 1] = d end
  end
  for _, s in ipairs(o.sinks or {}) do
    if s.valid and not (s.unit_number and gone_sinks[s.unit_number]) then keep_s[#keep_s + 1] = s end
  end
  o.drill_list, o.sinks = keep_d, keep_s
  o.drills = math.max(0, (o.drills or 0) - removed)
  o.ext_dead = nil
  return removed, got
end

local function items_text(got)
  local out = {}
  for _, name in ipairs(sorted_keys(got)) do out[#out + 1] = got[name] .. " " .. name end
  return #out > 0 and table.concat(out, ", ") or "rien"
end

--- Le registre de reconstruction ne refait pas une paire thermique de l'avant-poste que l'on migre.
local function purge_recon(f, o)
  local s = f.recon
  if not (s and s.lost) then return 0 end
  local n = 0
  for _, k in ipairs(sorted_keys(s.lost)) do
    local r = s.lost[k]
    if r.oid == o.id and (r.kind == "drill" or r.kind == "sink") then
      Rc.done(s, k)
      n = n + 1
    end
  end
  return n
end

---------------------------------------------------------------------------------------------------
-- Étapes
---------------------------------------------------------------------------------------------------
local function new_state()
  return { stage = "veille", fails = 0, noop = 0, done = 0, produced = 0, retry = 0 }
end

--- Fin du suivi d'un avant-poste (état final posé sur l'avant-poste) ; la pensée suivante passe au suivant.
local function finish(f, ms, o, st, how, text)
  st.stage, st.pid, st.ids = "veille", nil, nil
  if how == "abandon" then
    st.abandoned = true
    st.abandoned_at = game.tick -- lot MIGRATION-DECLENCHE : reprise d'un état neuf après CFG.revive (start_next)
    o.migr = nil
    o.full = false
    o.full_by = nil
  else
    o.migr = how -- "fini" ou "partiel"
    o.full = true
    o.full_by = "migration"
  end
  ms.cur = nil
  say(f, ms, string.format("%s [equipe : %d demande(s), %d paire(s) retiree(s), %d ligne(s) neuve(s) ont produit]", text, ms.requests or 0, ms.retired or 0,
    ms.lines or 0), true)
end

--- Demande échouée (avant ou après un retrait) : nouvel essai plus tard, abandon après CFG.max_fails échecs de suite.
local function failed(f, ms, o, st, tick, why)
  st.fails = st.fails + 1
  st.retry = tick + CFG.retry
  -- lot MIGRATION-DECLENCHE : le plan a REFUSÉ cette partie (ex. « tapis des foreuses (minerai) ») : elle est écartée des choix suivants
  -- (Mg.pick_band, ctx.skip) et une AUTRE partie est essayée sous une minute (la même était redemandée 3 fois à 15 min d'écart, puis abandon)
  if why == "refuse" and st.band_key then
    st.bad = st.bad or {}
    if #st.bad < CFG.max_bad then st.bad[#st.bad + 1] = st.band_key end
    st.retry = tick + CFG.retry_refuse
  end
  st.band_key = nil
  st.stage, st.pid, st.ids, st.gate_t0, st.t_done = "veille", nil, nil, nil, nil
  ms.cur = nil
  if st.done == 0 and st.produced == 0 then o.migr, o.full, o.full_by = nil, false, nil end -- rien de migré : l'avant-poste est rendu en attendant
  if st.fails >= CFG.max_fails then
    finish(f, ms, o, st, (st.done > 0) and "partiel" or "abandon",
      string.format("avant-poste %d : migration %s apres %d echec(s) de suite (%s), %d partie(s) migree(s)", o.id,
        (st.done > 0) and "arretee" or "abandonnee", st.fails, tostring(why), st.done))
  else
    say(f, ms, string.format("avant-poste %d : partie annulee (%s), echec %d/%d, nouvel essai a %.1f min", o.id, tostring(why), st.fails,
      CFG.max_fails, st.retry / 3600))
  end
end

--- Choisit une partie et la demande au plan. Rend vrai si la demande est partie.
local function begin_part(f, surface, ms, o, st, list, rects, tick)
  local m = method_of(o.kind)
  local rates = m and rates_of(m)
  if not rates then
    st.abandoned, st.sans_gabarit = true, true -- abandon définitif (lot MIGRATION-DECLENCHE : jamais repris)
    say(f, ms, string.format("avant-poste %d : pas de gabarit de fonderie pour %s, migration impossible", o.id, tostring(o.kind)), true)
    return false
  end
  local skip = {}
  for _, k in ipairs(st.bad or {}) do skip[k] = true end
  local band, why = Mg.pick_band(list, { rects = rects, toward = f.hq_pos, produced = st.produced > 0,
    line = line_of(m.args[2]), rates = rates, skip = skip })
  if not band then
    if why == "vide" then
      finish(f, ms, o, st, "fini", string.format("avant-poste %d : champ migre en entier (%d partie(s), %d ligne(s) ont produit)", o.id,
        st.done, st.produced))
    elseif st.done > 0 and (why == "place" or why == "gabarit" or why == "treillis" or why == "garde") then
      finish(f, ms, o, st, "partiel", string.format("avant-poste %d : %d paire(s) restent (%s), %d partie(s) migree(s)", o.id, #list, why, st.done))
    else
      st.fails = st.fails + 1
      st.retry = tick + CFG.retry
      if st.fails >= CFG.max_fails then
        st.abandoned = true
        st.abandoned_at = tick -- lot MIGRATION-DECLENCHE : reprise d'un état neuf après CFG.revive
        say(f, ms, string.format("avant-poste %d : aucune partie ne libere assez de place (%s), %d paire(s) : migration abandonnee", o.id,
          why, #list), true)
      else
        say_why(f, ms, st, "pick:" .. tostring(why), string.format("avant-poste %d : pas de partie a migrer (%s), %d paire(s), essai %d/%d",
          o.id, why, #list, st.fails, CFG.max_fails))
      end
    end
    return false
  end
  local spec = { gen = m.gen, args = { m.args[1], m.args[2], 1 }, feed = m.feed, rate = band.rate, near = { x = o.pos.x, y = o.pos.y },
    prio = CFG.prio, domain = "production", fixe = true, paires = band.pairs, degel = { oid = o.id, tiles = band.thaw, zone = band.zone } }
  local id, rwhy = Build.request(f, spec)
  if not id then
    st.fails = st.fails + 1
    st.retry = tick + CFG.retry
    say_why(f, ms, st, "req:" .. tostring(rwhy), string.format("avant-poste %d : demande au plan impossible (%s)", o.id, tostring(rwhy)))
    return false
  end
  st.stage, st.pid, st.ids, st.t0, st.band_key = "projet", id, band.ids, tick, band.key
  st.cx, st.cy, st.gate_t0, st.why_last, st.retired = band.cx, band.cy, nil, nil, nil
  o.migr, o.full, o.full_by = "en cours", true, "migration"
  ms.cur = o.id
  ms.requests = (ms.requests or 0) + 1
  say(f, ms, string.format("avant-poste %d (%s) : partie %d demandee : %d paire(s) thermique(s) %s (lot %s), projet %d : fonderie de %d rangee(s) "
    .. "et ligne de %d paire(s) de foreuses electriques visees, %.0f plaques/min (la partie en livrait %.1f/s), %d paire(s) restent debout",
    o.id, o.kind, st.done + 1, band.n, table.concat(band.ids, ","), band.lot, id, band.rows, band.pairs, band.rate,
    band.n * math.min(rates.burner, rates.furnace), #list - band.n))
  return true
end

--- Projet demandé : attend le plan et les matières ; au moment du « degel », retire la partie.
local function step_project(f, surface, ms, o, st, tick)
  local b = f.build
  local p = b.projects[st.pid]
  local env = { now = tick }
  local list, ents
  if p and p.state == "reserve" and p.reason == "degel" then
    st.gate_t0 = st.gate_t0 or tick
    list, ents = survey(o)
    local present = 0
    local alive = {}
    for _, pr in ipairs(list) do alive[pr.id] = true end
    for _, id in ipairs(st.ids) do if alive[id] then present = present + 1 end end
    env.total, env.present, env.produced = #list, present, st.produced > 0
    env.enemy = enemy_near(f, surface, st.cx, st.cy) or enemy_near(f, surface, o.pos.x, o.pos.y)
    env.uses = uses_thaw(p, p.spec.degel.tiles)
    env.gate_age = tick - st.gate_t0
  end
  local act, why = Mg.gate(st, p, env)
  if act == "attendre" then
    say_why(f, ms, st, "gate:" .. why, string.format("avant-poste %d : projet %d en attente (%s)%s", o.id, st.pid, why,
      why == "ennemi" and string.format(", ennemi a moins de %d tuiles, rien n'est retire", CFG.safe) or ""))
    return
  end
  if act == "annuler" or act == "echec" then
    if p and act == "annuler" then Build.cancel(f, st.pid, "migration: " .. why) end
    failed(f, ms, o, st, tick, why)
    return
  end
  -- "retirer" ou "passer" : le plan reprend (p.degele)
  if act == "retirer" then
    if not list then list, ents = survey(o) end
    local removed, got = retire(f, surface, o, st, list, ents)
    local purged = purge_recon(f, o)
    st.retired = removed
    ms.retired = (ms.retired or 0) + removed
    say(f, ms, string.format("avant-poste %d : partie retiree, projet %d : %d foreuse(s) thermique(s) et leurs fours repris au stock (%s), %d paire(s) restent "
      .. "debout, %d piece(s) du registre de reconstruction ecartee(s)", o.id, st.pid, removed, items_text(got), math.max(0, #list - removed), purged), true)
  else
    st.noop = st.noop + 1
    st.retired = 0
    say(f, ms, string.format("avant-poste %d : projet %d : le plan n'a pas besoin de la place de la partie (%s), rien n'est retire", o.id, st.pid, why), true)
  end
  if p then p.degele, p.reserve_next = true, nil end
  st.stage, st.t_degel, st.why_last = "chantier", tick, nil
end

--- Chantier de la ligne neuve : la partie suivante attend qu'elle ait produit.
local function step_build(f, surface, ms, o, st, tick)
  local b = f.build
  local p = b.projects[st.pid]
  local env = { now = tick, made = 0 }
  if p and p.state == "fini" then
    st.t_done = st.t_done or tick
    env.made = made_by(f, surface, p)
  end
  local act, why = Mg.watch(st, p, env)
  if act == "produit" then
    if (st.retired or 0) > 0 then
      st.done = st.done + 1
      -- comptabilité : les paires retirées comptent de nouveau comme foreuses de l'avant-poste (leur production est celle de la ligne neuve) ;
      -- lecteurs : le bilan de capacité du cerveau (view.outposts[].drills), les ordres de la capitalisation (o.drills >= cible)
      o.drills = (o.drills or 0) + st.retired
      o.migr_credit = (o.migr_credit or 0) + st.retired
    end
    st.produced = st.produced + 1
    st.fails = 0
    ms.lines = (ms.lines or 0) + 1
    say(f, ms, string.format("avant-poste %d : la ligne neuve du projet %d produit (%d produits finis), partie %d terminee en %.1f min", o.id, st.pid,
      env.made, st.done, (tick - st.t0) / 3600), true)
    st.stage, st.pid, st.ids, st.t_done, st.gate_t0, st.why_last = "veille", nil, nil, nil, nil, nil
    st.retry = tick
    ms.cur = nil
    if st.noop >= CFG.max_noop then
      finish(f, ms, o, st, (st.done > 0) and "partiel" or "abandon",
        string.format("avant-poste %d : %d ligne(s) posee(s) sans liberer la place voulue : migration arretee, %d partie(s) migree(s)", o.id, st.noop, st.done))
    end
    return
  end
  if act == "abandonner" then
    -- le projet du plan reste au plan (il peut aboutir) ; la migration ne va pas plus loin. Rien produit encore : l'avant-poste redevient extensible
    finish(f, ms, o, st, (st.done > 0 or st.produced > 0) and "partiel" or "abandon",
      string.format("avant-poste %d : la ligne du projet %d n'aboutit pas (%s, %.0f min depuis le retrait) : migration arretee, %d partie(s) migree(s)",
        o.id, st.pid, tostring(why), (tick - st.t_degel) / 3600, st.done))
    return
  end
  if act == "perdu" then
    ms.cur = nil
    finish(f, ms, o, st, "abandon", string.format("avant-poste %d : la ligne du projet %d est perdue apres le retrait (%s) : migration abandonnee, "
      .. "l'avant-poste redevient extensible", o.id, st.pid, why))
    return
  end
  if p and p.state == "fini" and tick - st.t_done > CFG.fini_wait then
    say_why(f, ms, st, "fini:" .. why, string.format("avant-poste %d : ligne finie du projet %d, pas encore de produit fini (%d)", o.id, st.pid, env.made))
  elseif tick - st.t_degel > CFG.build_warn then
    say_why(f, ms, st, "lent:" .. tostring(why), string.format("avant-poste %d : chantier lent, projet %d a %s depuis %.0f min", o.id, st.pid, tostring(why),
      (tick - st.t_degel) / 3600))
  end
end

--- Premier avant-poste (par numéro) dont la migration peut partir.
local function start_next(f, surface, ms, free, obtainable, tick)
  local b = f.build
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    local st = ms.o[oid]
    -- lot MIGRATION-DECLENCHE : un abandon (échecs de suite, ligne perdue) n'est plus définitif : après CFG.revive, l'avant-poste repart
    -- d'un état neuf (parties refusées oubliées : le champ, le stock et le courant ont changé). L'abandon « pas de gabarit » reste. Un
    -- abandon d'une sauvegarde 0.6.18 (sans date) compte comme daté du tick 0 : repris à la première pensée.
    local since = st and st.abandoned and not st.sans_gabarit and (st.abandoned_at or 0) or nil
    if since and tick >= since + CFG.revive and is_furnace_kind(o.kind) and o.migr == nil then
      st = new_state()
      ms.o[oid] = st
      say(f, ms, string.format("avant-poste %d (%s) : migration reprise apres abandon (%.0f min)", o.id, o.kind, CFG.revive / 3600), true)
    end
    if is_furnace_kind(o.kind) and not (st and st.abandoned) and o.migr ~= "fini" and o.migr ~= "partiel" then
      st = st or new_state()
      ms.o[oid] = st
      local list = survey(o)
      local rects = lots_of(f, o, list)
      local product = T.outposts[o.kind].product
      -- la recherche d'ennemi (coûteuse) seulement quand le reste est réuni
      local enemy = false
      if #list >= CFG.min_pairs and next(rects) ~= nil and tick >= (st.retry or 0) then enemy = enemy_near(f, surface, o.pos.x, o.pos.y) end
      local ok, why = Mg.start_ok({ migr = o.migr, plan = true, power = power_ok(b), obtainable = obtainable, plates = free[product] or 0,
        lattice = next(rects) ~= nil, pairs = #list, enemy = enemy, now = tick, retry = st.retry, abandoned = st.abandoned })
      if ok then
        if begin_part(f, surface, ms, o, st, list, rects, tick) then return true end
      elseif o.migr == "en cours" and (why == "paires" or why == "treillis") and st.done > 0 then
        -- plus assez de paires pour une partie de plus : le reste est laissé tel quel
        finish(f, ms, o, st, (#list == 0) and "fini" or "partiel",
          string.format("avant-poste %d : %d paire(s) restent (%s), %d partie(s) migree(s)", o.id, #list, why, st.done))
      elseif why ~= "fait" then
        say_why(f, ms, st, "start:" .. why, string.format("avant-poste %d (%s) : migration en veille (%s), %d paire(s) thermique(s)", o.id, o.kind, why, #list))
      end
    end
  end
  return false
end

--- Une pensée d'équipe. `free` : stock libre ({ [objet] = n }). Rend 1 si une étape a eu lieu, sinon 0.
function Mig.think(f, surface, book, free, tick)
  if not (f and f.outposts and f.hq and f.hq.valid and f.build) then return 0 end
  local ms = f.migration
  if not ms then
    ms = { next = 0, logs = 0, logs_f = 0, o = {} }
    f.migration = ms
  end
  if tick < ms.next then return 0 end
  ms.next = tick + CFG.every
  local item = T.DRILL_ELECTRIC
  if not game.entity_prototypes[item] then return 0 end
  if ms.cur then
    local o = f.outposts[ms.cur]
    local st = o and ms.o[ms.cur]
    if not (o and st) then
      -- avant-poste perdu en cours de route : le projet du plan, s'il n'a rien retiré, est annulé (les matières rendues)
      local s2 = ms.o[ms.cur]
      ms.cur = nil
      if s2 and s2.stage == "projet" and s2.pid then Build.cancel(f, s2.pid, "migration: avant-poste perdu") end
      return 0
    end
    -- lot MIGRATION-DECLENCHE : le registre n'est purgé qu'APRÈS un retrait (étape « chantier ») ; en « projet » rien n'est retiré, et
    -- une paire tuée par une attaque pendant l'attente des matières (30 min au plus) doit être refaite (scarlet, avant-poste 6 : 8 paires
    -- avant la vague, 3 après, demande annulée sans rien migrer)
    if st.stage == "chantier" then purge_recon(f, o) end
    if st.stage == "projet" then step_project(f, surface, ms, o, st, tick)
    elseif st.stage == "chantier" then step_build(f, surface, ms, o, st, tick)
    else ms.cur = nil end
    return 1
  end
  local have = math.min(Stock.count(f, item), free and free[item] or 0)
  local obtainable = have > 0 or book:handcraftable(item)
  return start_next(f, surface, ms, free or {}, obtainable, tick) and 1 or 0
end

--- Lot MIGRATION-DECLENCHE : numéro du projet du plan directeur de la partie en cours (étapes « projet » et « chantier »), ou nil.
--- Lecteur : script/ai3/automatisation.lua (Auto.think) en fait un projet du cerveau, qui FABRIQUE ses matières manquantes : la réserve
--- de la ligne neuve attendait 30 min sans que personne ne fabrique ses foreuses électriques, bras, tapis (journal du DC, 0.6.18,
--- scarlet : projets 4, 10, 21 et 23 « reserve:materiaux », 0 entité bâtie, annulés). Lecture seule.
function Mig.project(f)
  local ms = f and f.migration
  local st = ms and ms.cur and ms.o and ms.o[ms.cur]
  if st and (st.stage == "projet" or st.stage == "chantier") and st.pid then return st.pid end
  return nil
end

--- Résumé pour les bancs et la fenêtre (lecture seule) : nombres seulement.
function Mig.summary(f)
  local ms = f.migration
  if not ms then return { requests = 0, retired = 0, lines = 0, outposts = 0 } end
  local n = #sorted_keys(ms.o)
  local credit = 0
  for _, oid in ipairs(sorted_keys(f.outposts or {})) do credit = credit + (f.outposts[oid].migr_credit or 0) end
  return { requests = ms.requests or 0, retired = ms.retired or 0, lines = ms.lines or 0, outposts = n, cur = ms.cur, credit = credit }
end

return Mig
