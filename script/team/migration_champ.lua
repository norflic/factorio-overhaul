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
local Th = require("shared.team.thermique") -- lot THERMIQUE (ablation : balayage seul)
local Rc = require("shared.team.reconstruction")
local State = require("script.faction.state")
local Stock = require("script.team.stock")
local Build = require("script.team.build")
local Champ = require("script.team.champ") -- lot CHAMP : la partie migrée est une BANDE du champ en rangées (shared/team/champ.lua), hors du treillis

local Mig = {}

local CFG = Mg.CFG
-- Lot CHAMP : règles de la migration en BANDES du champ (la règle de shared/team/migration_champ.lua, ces seuils changés) :
--   min_pairs 1    une seule paire suffit (un avant-poste neuf de paires passe au champ dès que le courant et les objets le permettent) ;
--   keep_pairs 0   la bande qui remplace les paires produit plus qu'elles : un petit avant-poste n'est plus bloqué par la garde
--                  (« garde » annulait la demande : un champ d'une seule bande ne migrait jamais) ;
--   EXT_PLATES     une bande SANS paire (agrandissement du champ) n'est demandée que si la plaque du champ est sous ce stock libre.
local CHAMP_CFG = {}
for _, k in ipairs(State.sorted_keys(CFG)) do CHAMP_CFG[k] = CFG[k] end
CHAMP_CFG.min_pairs, CHAMP_CFG.keep_pairs = 1, 0
-- gate_wait 90 min, retry 3 min : une bande qui attend ses matières (tapis, bras, poteaux à fabriquer) n'est plus annulée au bout de 30 min
-- pour être redemandée 15 min plus tard, réserve rendue entre les deux (mesuré, partie de 150 min, graine 20261020 : deux bandes d'Azure
-- annulées « matieres » à 52 et 68 min, la suivante demandée à 87 min : 35 min sans bande)
CHAMP_CFG.gate_wait, CHAMP_CFG.retry = 90 * 3600, 3 * 3600
CHAMP_CFG.block_max = 15 * 3600 -- une bande bloquée (fantôme refusé) est laissée au plan après 15 min : la suivante part (step_build)
local EXT_PLATES = 3000
local FURNACE_INVENTORIES = { "furnace_source", "furnace_result", "fuel" }

local function sorted_keys(t) return State.sorted_keys(t or {}) end

local function name_of(f) return f.key or "player" end

--- Ligne de journal. `force` : lignes d'étape terminale, comptées à part (jamais coupées par le plafond des lignes courantes).
local function say(f, ms, text, force)
  if force then
    ms.logs_f = (ms.logs_f or 0) + 1
    if ms.logs_f > 120 then return end -- (lot CHAMP : 40 avant ; le devenir de chaque bande est forcé, champ_bandes.py le lit)
  else
    ms.logs = ms.logs + 1
    if ms.logs > CFG.logs then return end
  end
  log("[FO-MIGRATION] " .. name_of(f) .. " : " .. text)
end

--- Une raison d'attente n'est écrite qu'à son changement.
local function say_why(f, ms, st, key, text, force)
  if st.why_last == key then return end
  st.why_last = key
  say(f, ms, text, force)
end

--- Lot CHAMP : deux champs migrent EN MÊME TEMPS au plus (créneaux ms.cur et ms.cur2, de minerais différents : le fer et le cuivre
--- avancent ensemble) ; ms.cur reste le créneau lu par les autres modules (script/team/pile.lua, Mig.project).
local function claim(ms, id)
  if not ms.cur then ms.cur = id else ms.cur2 = id end
end
local function release(ms, id)
  if ms.cur == id then ms.cur = nil end
  if ms.cur2 == id then ms.cur2 = nil end
  if ms.cur2 and not ms.cur then ms.cur, ms.cur2 = ms.cur2, nil end
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

--- Lot CHAMP : avant-postes du MÊME minerai sur le même gisement que `o` (centre à moins de Champ.SIB_R tuiles), triés par numéro.
--- Un champ se planifie une fois pour tout le gisement : leurs paires sont retirées sous les bandes comme celles de `o`.
--- Lot CHAMP : la position `p` est-elle dans la boîte du gisement d'un champ sans avant-poste (Mig.want, marge CFG.want_margin) ?
local function in_box(box, p)
  local m = Mg.CFG.want_margin
  return p.x >= box[1] - m and p.x <= box[3] + m and p.y >= box[2] - m and p.y <= box[4] + m
end

local function siblings(f, o)
  local out = {}
  local r2 = Champ.SIB_R * Champ.SIB_R
  -- un gisement sans avant-poste (o.box) n'a pour voisins que ce qui est dans SA boîte : à 64 tuiles, un avant-poste d'un gisement voisin
  -- serait pris pour le même gisement et ne migrerait plus (« son gisement est le champ de... »)
  local function near(q)
    if o.box then return in_box(o.box, q.pos) end
    if q.box then return in_box(q.box, o.pos) end
    return (q.pos.x - o.pos.x) ^ 2 + (q.pos.y - o.pos.y) ^ 2 <= r2
  end
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local q = f.outposts[oid]
    if q ~= o and q.kind == o.kind and near(q) then out[#out + 1] = q end
  end
  -- gisements sans avant-poste demandés par la capitalisation (Mig.want) : voisins eux aussi (un seul champ par gisement)
  local fields = f.migration and f.migration.fields
  for _, fid in ipairs(sorted_keys(fields)) do
    local q = fields[fid]
    if q ~= o and q.kind == o.kind and near(q) then out[#out + 1] = q end
  end
  return out
end

--- Paires de `o` et de ses voisins du même gisement (lot CHAMP), comme survey(o).
local function survey_field(f, o)
  local all = { drill_list = {}, sinks = {} }
  for _, q in ipairs({ o, table.unpack(siblings(f, o)) }) do
    for _, d in ipairs(q.drill_list or {}) do all.drill_list[#all.drill_list + 1] = d end
    for _, x in ipairs(q.sinks or {}) do all.sinks[#all.sinks + 1] = x end
  end
  return survey(all)
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
  -- lot CHAMP : à qui appartient chaque foreuse (l'avant-poste ou un voisin du même gisement), lu AVANT le retrait
  local owners = st.frame and { o, table.unpack(siblings(f, o)) } or { o }
  local owner_of, rem = {}, {}
  for i, q in ipairs(owners) do
    rem[i] = 0
    for _, d in ipairs(q.drill_list or {}) do if d.valid and d.unit_number then owner_of[d.unit_number] = i end end
  end
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
        local oi = owner_of[d.unit_number]
        if oi then rem[oi] = rem[oi] + 1 end
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
  -- lot CHAMP : les voisins du même gisement perdent aussi les paires retirées sous la bande
  for i, q in ipairs(owners) do
    local keep_d, keep_s = {}, {}
    for _, d in ipairs(q.drill_list or {}) do
      if d.valid and not (d.unit_number and gone_drills[d.unit_number]) then keep_d[#keep_d + 1] = d end
    end
    for _, s in ipairs(q.sinks or {}) do
      if s.valid and not (s.unit_number and gone_sinks[s.unit_number]) then keep_s[#keep_s + 1] = s end
    end
    q.drill_list, q.sinks = keep_d, keep_s
    q.drills = math.max(0, (q.drills or 0) - rem[i])
    q.ext_dead = nil
  end
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
-- Lot THERMIQUE : lectures pour la règle pure shared/team/thermique.lua (« on REMPLACE les thermiques par l'électrique »)
---------------------------------------------------------------------------------------------------
--- Cadences (ore/s) d'une foreuse thermique et d'une foreuse électrique sur le minerai de `kind`, lues aux prototypes ; nil si illisibles.
local function rates_of_kind(f, kind)
  local spec = T.outposts[kind]
  local rp = spec and game.entity_prototypes[spec.resource]
  local bp, ep = game.entity_prototypes[T.DRILL], game.entity_prototypes[T.DRILL_ELECTRIC]
  if not (rp and rp.mineable_properties and bp and ep and bp.mining_speed and ep.mining_speed) then return nil end
  local mt = rp.mineable_properties.mining_time or 1
  local force = game.forces and game.forces[f.force]
  local prod = force and force.mining_drill_productivity_bonus or 0
  return bp.mining_speed / mt * (1 + prod), ep.mining_speed / mt * (1 + prod)
end

--- Foreuses thermiques debout d'un avant-poste (ou d'un gisement voulu).
local function thermal_count(o)
  local n = 0
  for _, d in ipairs(o.drill_list or {}) do
    if d.valid and d.name == T.DRILL then n = n + 1 end
  end
  return n
end

--- Foreuses électriques EN MARCHE des bandes finies du champ `oid` (une bande qui ne mine pas ne couvre rien : sortie bouchée, courant coupé).
local function working_of(f, surface, oid)
  local b = f.build
  local n = 0
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    if p and p.state == "fini" and p.spec and p.spec.champ and p.spec.champ.oid == oid then
      for _, e in ipairs(p.ents or {}) do
        if e.built and e.role == "champ-foreuse" then
          local de = surface.find_entity(e.name, { e.x, e.y })
          if de and de.valid and de.status == defines.entity_status.working then n = n + 1 end
        end
      end
    end
  end
  return n
end

--- Combustible (ore/s) que brûlent les générateurs de la force à cet instant : plancher du minerai CRITIQUE (le charbon de la centrale).
local function fuel_burn(f, surface)
  local proto = game.item_prototypes and game.item_prototypes[T.fuel]
  local value = proto and proto.fuel_value or 0
  if value <= 0 then return 0 end
  local watts = 0
  for _, g in ipairs(surface.find_entities_filtered({ type = "generator", force = f.force })) do
    if g.valid then watts = watts + (g.energy_generated_last_tick or 0) * 60 end
  end
  return watts / value
end

--- Gisements de la force pour la règle pure : un par propriétaire de champ (les voisins du même gisement lui sont rattachés), un par
--- avant-poste ou gisement voulu sinon. Rend (liste, par numéro).
local function build_fields(f, surface, ms, free)
  local fields, byid = {}, {}
  local targets = {}
  for _, oid in ipairs(sorted_keys(f.outposts)) do targets[#targets + 1] = f.outposts[oid] end
  for _, fid in ipairs(sorted_keys(ms.fields)) do targets[#targets + 1] = ms.fields[fid] end
  for _, o in ipairs(targets) do
    if is_furnace_kind(o.kind) then
      local th, el = rates_of_kind(f, o.kind)
      local st = ms.o[o.id]
      local framed = (st and st.frame and not st.abandoned) and true or false
      local sib = siblings(f, o)
      local subsumed = false
      if not framed then
        for _, q in ipairs(sib) do
          local sq = ms.o[q.id]
          if sq and sq.frame and not sq.abandoned then subsumed = true end
        end
      end
      if th and not subsumed then
        local n = thermal_count(o)
        if framed then for _, q in ipairs(sib) do n = n + thermal_count(q) end end
        local fl = { id = o.id, res = o.kind, pairs = n, th_rate = th, el_rate = el, working = framed and working_of(f, surface, o.id) or 0,
          busy = (st and st.stage ~= "veille") and true or false, wanted = (st and (st.want_until or 0) > game.tick) and true or false,
          have = free[T.outposts[o.kind].product] or 0, framed = framed }
        fields[#fields + 1] = fl
        byid[o.id] = fl
      end
    end
  end
  return fields, byid
end

--- Contexte de la règle pure : courant, fer libre, stock de chaque minerai (son produit), minerai critique (le combustible) et son plancher.
local function th_context(f, surface, b, free, book)
  local ctx = { power = power_ok(b), iron = free[T.outposts.iron.product] or 0, floor = {}, stock = {}, critical = {} }
  local burn
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local spec = T.outposts[kind]
    ctx.stock[kind] = free[spec.product] or 0
    if spec.resource == T.fuel then
      burn = burn or fuel_burn(f, surface)
      ctx.critical[kind], ctx.floor[kind] = true, burn
    end
  end
  return ctx
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
  if st.frame then -- lot CHAMP : les voisins du même gisement suivent (plus de paire posée par eux sur le champ)
    for _, q in ipairs(siblings(f, o)) do
      q.migr, q.full, q.full_by = (how == "abandon") and nil or how, how ~= "abandon", (how ~= "abandon") and "migration" or nil
    end
  end
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
  release(ms, o.id)
  say(f, ms, string.format("%s [equipe : %d demande(s), %d paire(s) retiree(s), %d ligne(s) neuve(s) ont produit]", text, ms.requests or 0, ms.retired or 0,
    ms.lines or 0), true)
end

--- Demande échouée (avant ou après un retrait) : nouvel essai plus tard, abandon après CFG.max_fails échecs de suite.
local function failed(f, ms, o, st, tick, why)
  st.fails = st.fails + 1
  st.retry = tick + (st.frame and CHAMP_CFG.retry or CFG.retry) -- (lot CHAMP : une bande annulée est redemandée sous 3 min)
  -- lot MIGRATION-DECLENCHE : le plan a REFUSÉ cette partie (ex. « tapis des foreuses (minerai) ») : elle est écartée des choix suivants
  -- (Mg.pick_band, ctx.skip) et une AUTRE partie est essayée sous une minute (la même était redemandée 3 fois à 15 min d'écart, puis abandon)
  if why == "refuse" and st.band_key then
    st.bad = st.bad or {}
    if #st.bad < CFG.max_bad then st.bad[#st.bad + 1] = st.band_key end
    st.retry = tick + CFG.retry_refuse
  end
  st.band_key = nil
  st.stage, st.pid, st.ids, st.gate_t0, st.t_done = "veille", nil, nil, nil, nil
  release(ms, o.id)
  if st.done == 0 and st.produced == 0 then o.migr, o.full, o.full_by = nil, false, nil end -- rien de migré : l'avant-poste est rendu en attendant
  if st.fails >= CFG.max_fails then
    finish(f, ms, o, st, (st.done > 0) and "partiel" or "abandon",
      string.format("avant-poste %d : migration %s apres %d echec(s) de suite (%s), %d partie(s) migree(s)", o.id,
        (st.done > 0) and "arretee" or "abandonnee", st.fails, tostring(why), st.done))
  else
    say(f, ms, string.format("avant-poste %d : partie annulee (%s), echec %d/%d, nouvel essai a %.1f min", o.id, tostring(why), st.fails,
      CFG.max_fails, st.retry / 3600), st.frame ~= nil) -- (lot CHAMP : forcée pour une bande du champ)
  end
end

--- Lot CHAMP : la bande suivante du champ de l'avant-poste `o` (cadre figé au premier appel), demandée au plan directeur comme un SITE
--- (Build.SITES.champ, script/team/champ.lua). Les paires dont une tuile est sous la bande sont celles que le dégel retire. Rend vrai si la
--- demande est partie.
local function begin_band(f, surface, ms, o, st, list, tick, free)
  if not st.frame then
    local frame, order = Champ.frame(f, surface, o)
    if not frame then
      st.fails, st.retry = st.fails + 1, tick + CFG.retry
      say_why(f, ms, st, "champ:" .. tostring(order), string.format("avant-poste %d : pas de plan de champ (%s), essai %d/%d", o.id, tostring(order), st.fails, CFG.max_fails))
      if st.fails >= CFG.max_fails then st.abandoned, st.abandoned_at = true, tick end
      return false
    end
    st.frame, st.order, st.done_pr = frame, order, {}
  end
  local bad = {}
  for _, k in ipairs(st.bad or {}) do bad[k] = true end
  local product = T.outposts[o.kind].product
  local pr
  for _, x in ipairs(st.order) do
    if not pr and not st.done_pr[tostring(x)] and not bad[x] then pr = x end
  end
  if not pr then
    finish(f, ms, o, st, (st.done > 0 or st.produced > 0) and "fini" or "abandon", (#st.order == 0)
      and string.format("avant-poste %d : aucune bande ne tient sur le gisement (occupe : voir [FO-CHAMP]), les paires restent", o.id)
      or string.format("avant-poste %d : champ pose (%d bande(s) produisent)", o.id, st.produced))
    return false
  end
  local bd, why = Champ.band(f, surface, o, st.frame, pr)
  if not bd then
    st.bad = st.bad or {}
    st.bad[#st.bad + 1] = pr
    st.retry = tick + CFG.retry_refuse
    say(f, ms, string.format("avant-poste %d : bande %d ecartee (%s)", o.id, pr, tostring(why)))
    return false
  end
  -- paires sous la bande : retirées au dégel
  local under = {}
  for i = 1, #bd.tiles - 1, 2 do under[P.tkey(bd.tiles[i], bd.tiles[i + 1])] = true end
  local ids, thaw = {}, {}
  for _, pr2 in ipairs(list) do
    local t = Mg.tiles({ Mg.box(pr2.drill), Mg.box(pr2.sink) })
    local hit = false
    for i = 1, #t - 1, 2 do if under[P.tkey(t[i], t[i + 1])] then hit = true end end
    if hit then
      ids[#ids + 1] = pr2.id
      for i = 1, #t do thaw[#thaw + 1] = t[i] end
    end
  end
  table.sort(ids)
  -- une bande voulue par la capitalisation (Mig.want) n'attend pas que la plaque manque : la règle a déjà jugé l'agrandissement rentable
  local wanted = (st.want_until or 0) > tick
  if #ids == 0 and (free[product] or 0) >= EXT_PLATES and not wanted then
    say_why(f, ms, st, "ext:" .. pr, string.format("avant-poste %d : bande %d sans paire en attente (%d %s libres, agrandissement sous %d)", o.id, pr,
      free[product] or 0, product, EXT_PLATES))
    st.retry = tick + CFG.retry
    return false
  end
  local cx, cy, n = 0, 0, 0
  for _, e in ipairs(bd.ents) do cx, cy, n = cx + e.x, cy + e.y, n + 1 end
  cx, cy = cx / math.max(1, n), cy / math.max(1, n)
  -- la bande porte sa plaque (spec.product) et la famille d'investissement de la pile « capi » (shared/ai3/pile.lua) : pendant une retenue,
  -- elle avance pour une plaque d'un cadre ouvert ou qui manque, comme un module de la capitalisation (avant : « migration », rang améliorer,
  -- jamais d'exception : 4 à 6 refus par équipe et par heure, réserve rendue à chaque refus)
  local spec = { site = "champ", champ = { oid = o.id, pr = pr, frame = st.frame }, near = { x = o.pos.x, y = o.pos.y }, prio = CFG.prio,
    domain = "production", lazy_clear = true, pile = "capi", product = product }
  if #ids > 0 then spec.degel = { oid = o.id, tiles = thaw } end
  local id, rwhy = Build.request(f, spec)
  if not id then
    st.fails, st.retry = st.fails + 1, tick + CFG.retry
    say_why(f, ms, st, "req:" .. tostring(rwhy), string.format("avant-poste %d : demande au plan impossible (%s)", o.id, tostring(rwhy)))
    return false
  end
  st.stage, st.pid, st.ids, st.t0, st.band_key = "projet", id, ids, tick, pr
  st.cx, st.cy, st.gate_t0, st.why_last, st.retired = cx, cy, nil, nil, nil
  o.migr, o.full, o.full_by = "en cours", true, "migration"
  for _, q in ipairs(siblings(f, o)) do q.migr, q.full, q.full_by = "en cours", true, "migration" end -- même gisement : plus de paire de plus
  claim(ms, o.id)
  ms.requests = (ms.requests or 0) + 1
  local nd, nf = 0, 0
  for _, e in ipairs(bd.plan.ents) do if e.kind == "foreuse" then nd = nd + 1 elseif e.kind == "four" then nf = nf + 1 end end
  say(f, ms, string.format("%s %d (%s) : bande %d du champ demandee, projet %d : %d foreuse(s) electrique(s), %d four(s), %d paire(s) thermique(s) dessous (%s), %d paire(s) ailleurs%s",
    o.field and "gisement" or "avant-poste", o.id, o.kind, pr, id, nd, nf, #ids, table.concat(ids, ","), #list - #ids,
    wanted and " (voulue par la capitalisation)" or ""), true)
  return true
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
    prio = CFG.prio, domain = "production", fixe = true, paires = band.pairs, degel = { oid = o.id, tiles = band.thaw, zone = band.zone },
    pile = "migration" } -- lot FUITES-PILE : famille de la pile (réserve au coffre suspendue pendant une retenue, sauf en chantier)
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
  claim(ms, o.id)
  ms.requests = (ms.requests or 0) + 1
  say(f, ms, string.format("avant-poste %d (%s) : partie %d demandee : %d paire(s) thermique(s) %s (lot %s), projet %d : fonderie de %d rangee(s) "
    .. "et ligne de %d paire(s) de foreuses electriques visees, %.0f plaques/min (la partie en livrait %.1f/s), %d paire(s) restent debout",
    o.id, o.kind, st.done + 1, band.n, table.concat(band.ids, ","), band.lot, id, band.rows, band.pairs, band.rate,
    band.n * math.min(rates.burner, rates.furnace), #list - band.n))
  return true
end

--- Relecture MIGRATION-DECLENCHE : paires de la partie, y compris celles REFAITES par la reconstruction pendant l'attente des matières
--- (nouveaux numéros d'unité, mêmes tuiles). Le registre n'est plus purgé en étape « projet » : une paire tuée puis refaite sur la
--- partie doit être retirée elle aussi, sinon elle occupe les tuiles promises au plan (`thaw`) et la ligne neuve ne se pose pas
--- (build.lua ne libère rien au dégel). Rend les numéros triés et le nombre de paires ajoutées. Lecture seule.
local function part_ids(st, list, thaw)
  local set, ids = {}, {}
  for _, id in ipairs(st.ids or {}) do
    if not set[id] then set[id] = true; ids[#ids + 1] = id end
  end
  local tset = {}
  for i = 1, #(thaw or {}) - 1, 2 do tset[P.tkey(thaw[i], thaw[i + 1])] = true end
  local added = 0
  for _, pr in ipairs(list) do
    if not set[pr.id] then
      local t = Mg.tiles({ Mg.box(pr.drill) })
      local inside = #t > 0
      for i = 1, #t - 1, 2 do
        if not tset[P.tkey(t[i], t[i + 1])] then inside = false; break end
      end
      if inside then set[pr.id] = true; ids[#ids + 1] = pr.id; added = added + 1 end
    end
  end
  table.sort(ids)
  return ids, added
end

--- Projet demandé : attend le plan et les matières ; au moment du « degel », retire la partie.
local function step_project(f, surface, ms, o, st, tick)
  local b = f.build
  local p = b.projects[st.pid]
  local env = { now = tick }
  local list, ents
  if p and p.state == "reserve" and p.reason == "degel" then
    st.gate_t0 = st.gate_t0 or tick
    if st.frame then list, ents = survey_field(f, o) else list, ents = survey(o) end
    local ids, added = part_ids(st, list, p.spec and p.spec.degel and p.spec.degel.tiles)
    if added > 0 then
      st.ids = ids
      say(f, ms, string.format("avant-poste %d : %d paire(s) refaite(s) par la reconstruction sur la partie du projet %d : retirees avec elle",
        o.id, added, st.pid), true)
    end
    local present = 0
    local alive = {}
    for _, pr in ipairs(list) do alive[pr.id] = true end
    for _, id in ipairs(st.ids) do if alive[id] then present = present + 1 end end
    env.total, env.present, env.produced = #list, present, st.produced > 0
    env.enemy = enemy_near(f, surface, st.cx, st.cy) or enemy_near(f, surface, o.pos.x, o.pos.y)
    env.uses = uses_thaw(p, p.spec.degel.tiles)
    env.gate_age = tick - st.gate_t0
  end
  local act, why = Mg.gate(st, p, env, st.frame and CHAMP_CFG or nil)
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
    if not list then if st.frame then list, ents = survey_field(f, o) else list, ents = survey(o) end end
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
  -- Lot CHAMP : une bande BLOQUÉE (fantôme refusé : une tourelle de l'équipe posée depuis sur son emprise ; mesuré, banc final-lot-20261020,
  -- azure projet 6, 41 entités bâties sur 42) gardait le créneau 90 min, puis arrêtait TOUT le champ (Mg.watch « abandonner ») : 40 paires
  -- de fer restées thermiques. Après CHAMP_CFG.block_max, elle est laissée au plan (qui peut encore la finir), comptée comme posée, et la
  -- bande suivante part.
  if st.frame then
    if p and p.state == "bloque" then
      st.block_t0 = st.block_t0 or tick
      if tick - st.block_t0 > CHAMP_CFG.block_max then
        if st.band_key then st.done_pr[tostring(st.band_key)] = true end
        say(f, ms, string.format("avant-poste %d : bande %s du projet %d bloquee depuis %.0f min (%s) : laissee au plan, bande suivante", o.id,
          tostring(st.band_key), st.pid, (tick - st.block_t0) / 3600, tostring(p.reason)), true)
        st.stage, st.pid, st.ids, st.t_done, st.gate_t0, st.why_last, st.block_t0 = "veille", nil, nil, nil, nil, nil, nil
        st.retry = tick
        release(ms, o.id)
        return
      end
    else
      st.block_t0 = nil
    end
  end
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
    if st.frame and st.band_key then st.done_pr[tostring(st.band_key)] = true end -- lot CHAMP : bande posée et qui produit
    ms.lines = (ms.lines or 0) + 1
    say(f, ms, string.format("avant-poste %d : la ligne neuve du projet %d produit (%d produits finis), partie %d terminee en %.1f min", o.id, st.pid,
      env.made, st.done, (tick - st.t0) / 3600), true)
    st.stage, st.pid, st.ids, st.t_done, st.gate_t0, st.why_last = "veille", nil, nil, nil, nil, nil
    st.retry = tick
    release(ms, o.id)
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
    release(ms, o.id)
    finish(f, ms, o, st, "abandon", string.format("avant-poste %d : la ligne du projet %d est perdue apres le retrait (%s) : migration abandonnee, "
      .. "l'avant-poste redevient extensible", o.id, st.pid, why))
    return
  end
  if p and p.state == "fini" and tick - st.t_done > CFG.fini_wait then
    say_why(f, ms, st, "fini:" .. why, string.format("avant-poste %d : ligne finie du projet %d, pas encore de produit fini (%d)", o.id, st.pid, env.made), st.frame ~= nil)
  elseif tick - st.t_degel > CFG.build_warn then
    say_why(f, ms, st, "lent:" .. tostring(why), string.format("avant-poste %d : chantier lent, projet %d a %s depuis %.0f min", o.id, st.pid, tostring(why),
      (tick - st.t_degel) / 3600), st.frame ~= nil)
  end
end

---------------------------------------------------------------------------------------------------
-- Lot THERMIQUE : balayage des paires thermiques d'un gisement COUVERT, et part électrique par minerai (journal [FO-THERMIQUE])
---------------------------------------------------------------------------------------------------
-- Retour du DC du 2/11 : « on REMPLACE les thermiques par l'électrique ; on voit bien les rangées de foreuses sur un ou 2 gisements (pas tous) ».
-- Mesuré (150 min, main 0.6.37) : des paires restent sur des gisements dont une bande produit (paires hors des bandes : bords, tuiles
-- occupées, foreuses sans four). Règle : shared/team/thermique.lua (Th.sweep). Un gisement doit être COUVERT à deux relevés de suite (une bande
-- bouchée un instant ne fait pas retirer ses paires).
local SWEEP_EVERY = 3600     -- 1 min entre deux relevés
local SWEEP_CONFIRM = 2      -- relevés de suite « couvert » avant de retirer
local REPORT_EVERY = 5 * 3600 -- une ligne [FO-THERMIQUE] par équipe toutes les 5 min
local REPORT_LOGS = 150      -- lignes [FO-THERMIQUE] au plus par équipe

--- Paires thermiques du gisement de `o` (appariées) PLUS les foreuses thermiques sans four (four détruit) : rend (liste de paires pour retire(),
--- entités, propriétaires).
local function sweep_list(f, o)
  local list, ents = survey_field(f, o)
  local matched = {}
  for _, pr in ipairs(list) do matched[pr.id] = true end
  local owners = { o }
  for _, q in ipairs(siblings(f, o)) do owners[#owners + 1] = q end
  for _, q in ipairs(owners) do
    for _, d in ipairs(q.drill_list or {}) do
      if d.valid and d.name == T.DRILL and d.unit_number and not matched[d.unit_number] then
        matched[d.unit_number] = true
        list[#list + 1] = { id = d.unit_number, drill = box_of(d) }
        ents[d.unit_number] = d
      end
    end
  end
  return list, ents, owners
end

local function sweep(f, surface, ms, free, book, tick)
  if tick < (ms.sweep_next or 0) then return 0 end
  ms.sweep_next = tick + SWEEP_EVERY
  local fields, byid = build_fields(f, surface, ms, free)
  if #fields == 0 then return 0 end
  local ctx = th_context(f, surface, f.build, free, book)
  local gated = {}
  for _, fl in ipairs(fields) do
    local st = ms.o[fl.id]
    if st then st.cov_n = Th.covered(fl) and ((st.cov_n or 0) + 1) or 0 end
    local g = {}
    for _, k in ipairs(sorted_keys(fl)) do g[k] = fl[k] end
    if not st or (st.cov_n or 0) < SWEEP_CONFIRM then g.working = 0 end
    gated[#gated + 1] = g
  end
  local acts, refused = Th.sweep(gated, ctx)
  local swept = 0
  for _, a in ipairs(acts) do
    local o = Champ.target(f, a.id)
    local st = ms.o[a.id]
    if o and st and st.stage == "veille" then
      local list, ents, owners = sweep_list(f, o)
      if #list > 0 then
        local ids = {}
        for _, pr in ipairs(list) do ids[#ids + 1] = pr.id end
        table.sort(ids)
        local before = {}
        for i, q in ipairs(owners) do before[i] = q.drills or 0 end
        local fl = byid[a.id]
        local removed, got = retire(f, surface, o, { ids = ids, frame = true }, list, ents)
        -- la comptabilité des foreuses de l'avant-poste ne change pas : l'électrique de la bande en tient lieu (comme au retrait d'une bande)
        for i, q in ipairs(owners) do
          q.drills = before[i]
          purge_recon(f, q)
        end
        o.migr_credit = (o.migr_credit or 0) + removed
        ms.retired = (ms.retired or 0) + removed
        ms.swept = (ms.swept or 0) + removed
        swept = swept + removed
        say(f, ms, string.format("gisement de l'avant-poste %d (%s) : %d paire(s) thermique(s) retiree(s) de force, bande electrique productive (%d foreuse(s) en marche, "
          .. "%.2f ore/s contre %.2f ore/s thermique), repris au stock : %s", o.id, o.kind, removed, fl and fl.working or 0,
          fl and fl.working * fl.el_rate or 0, fl and fl.pairs * fl.th_rate or 0, items_text(got)), true)
      end
    end
  end
  if tick >= (ms.th_report_next or 0) then
    ms.th_report_next = tick + REPORT_EVERY
    ms.th_logs = (ms.th_logs or 0) + 1
    if ms.th_logs <= REPORT_LOGS then
      local parts = {}
      for _, r in ipairs(Th.shares(fields, T.OUTPOST_ORDER)) do
        if r.pairs + r.working > 0 then
          parts[#parts + 1] = string.format("%s %d thermique(s), %d electrique(s) en marche, part %s, %d gisement(s) couvert(s) gardant des paires", r.res, r.pairs,
            r.working, r.share and string.format("%.0f%%", r.share * 100) or "-", r.covered_with_pairs)
        end
      end
      local why = {}
      for _, r in ipairs(refused) do why[#why + 1] = string.format("%d:%s", r.id, r.why) end
      log(string.format("[FO-THERMIQUE] %s min %.0f | %s | refus du balayage : %s | %d paire(s) balayee(s) depuis le debut", name_of(f), tick / 3600,
        #parts > 0 and table.concat(parts, " ; ") or "aucune foreuse", #why > 0 and table.concat(why, ", ") or "aucun", ms.swept or 0))
    end
  end
  return swept > 0 and 1 or 0
end
Mig.sweep = sweep -- (bancs hors jeu : tests/migration_champ_test.lua, section T)

--- Premier avant-poste (par numéro) dont la migration peut partir.
local function start_next(f, surface, ms, free, obtainable, tick, busy)
  local b = f.build
  -- Lot CHAMP : la plaque la plus en manque d'abord (retour du DC du 2/11 : « 57 plaques de cuivre » pour près de 1 000 de fer), puis
  -- le numéro d'avant-poste
  -- Lot CHAMP (ordres « couvrir / ouvrir ») : les champs voulus par la capitalisation d'abord (Mig.want), gisements sans avant-poste compris
  local cand = {}
  local function add(oid, o)
    if is_furnace_kind(o.kind) then
      local sq = ms.o[oid]
      cand[#cand + 1] = { oid = oid, have = free[T.outposts[o.kind].product] or 0, want = (sq and (sq.want_until or 0) > tick) and 1 or 0 }
    end
  end
  for _, oid in ipairs(sorted_keys(f.outposts)) do add(oid, f.outposts[oid]) end
  for _, fid in ipairs(sorted_keys(ms.fields)) do add(fid, ms.fields[fid]) end
  table.sort(cand, function(a, c)
    if a.want ~= c.want then return a.want > c.want end
    if a.have ~= c.have then return a.have < c.have end
    return a.oid < c.oid
  end)
  for _, it in ipairs(cand) do
    local oid = it.oid
    local o = Champ.target(f, oid)
    local st = ms.o[oid]
    -- lot CHAMP : un créneau déjà pris : seulement un champ d'un AUTRE minerai (ni l'avant-poste en cours, ni son gisement)
    if busy and (oid == busy.id or o.kind == busy.kind or Champ.data(f, o.kind) == nil) then goto next_outpost end
    -- lot MIGRATION-DECLENCHE : un abandon (échecs de suite, ligne perdue) n'est plus définitif : après CFG.revive, l'avant-poste repart
    -- d'un état neuf (parties refusées oubliées : le champ, le stock et le courant ont changé). L'abandon « pas de gabarit » reste. Un
    -- abandon d'une sauvegarde 0.6.18 (sans date) compte comme daté du tick 0 : repris à la première pensée.
    local since = st and st.abandoned and not st.sans_gabarit and (st.abandoned_at or 0) or nil
    if since and tick >= since + CFG.revive and o.migr == nil then
      st = new_state()
      ms.o[oid] = st
      say(f, ms, string.format("avant-poste %d (%s) : migration reprise apres abandon (%.0f min)", o.id, o.kind, CFG.revive / 3600), true)
    end
    -- lot CHAMP : un voisin d'un gisement déjà planifié par un autre avant-poste n'en planifie pas un second
    local owner
    for _, q in ipairs(siblings(f, o)) do
      local sq = ms.o[q.id]
      if not owner and sq and sq.frame and not sq.abandoned then owner = q end
    end
    if owner then
      if st then say_why(f, ms, st, "champ-de:" .. owner.id, string.format("avant-poste %d (%s) : son gisement est le champ de l'avant-poste %d", o.id, o.kind, owner.id)) end
    elseif not (st and st.abandoned) and o.migr ~= "fini" and o.migr ~= "partiel" then
      st = st or new_state()
      ms.o[oid] = st
      -- lot CHAMP : le champ en bandes quand la règle a ses données (foreuse, tapis débloqué, poteau) ; sinon le treillis comme avant
      local champ = Champ.data(f, o.kind) ~= nil
      local list = champ and survey_field(f, o) or survey(o)
      local rects = champ and {} or lots_of(f, o, list)
      local product = T.outposts[o.kind].product
      local cfg = champ and CHAMP_CFG or CFG
      local npairs = #list
      if champ and st.frame and npairs == 0 then npairs = 1 end -- bandes sans paire : agrandissement du champ (begin_band)
      if champ and it.want == 1 and npairs == 0 then npairs = 1 end -- voulu par la capitalisation : un gisement sans paire se pose aussi
      local lattice = champ or next(rects) ~= nil
      -- la recherche d'ennemi (coûteuse) seulement quand le reste est réuni
      local enemy = false
      if npairs >= cfg.min_pairs and lattice and tick >= (st.retry or 0) then enemy = enemy_near(f, surface, o.pos.x, o.pos.y) end
      -- lot CHAMP : la bande coûte surtout du FER (foreuses, bras, tapis) : la garde de stock lit les plaques de fer ; elle lisait la plaque
      -- du champ, et un champ de cuivre ne migrait jamais quand le cuivre manquait (le cas même du DC)
      local plates = champ and (free[T.outposts.iron.product] or 0) or (free[product] or 0)
      local ok, why = Mg.start_ok({ migr = o.migr, plan = true, power = power_ok(b), obtainable = obtainable, plates = plates,
        lattice = lattice, pairs = npairs, enemy = enemy, now = tick, retry = st.retry, abandoned = st.abandoned }, cfg)
      if ok then
        if champ then
          if begin_band(f, surface, ms, o, st, list, tick, free) then return true end
        elseif begin_part(f, surface, ms, o, st, list, rects, tick) then return true end
      elseif o.migr == "en cours" and (why == "paires" or why == "treillis") and st.done > 0 and not (champ and st.frame) then
        -- plus assez de paires pour une partie de plus : le reste est laissé tel quel
        finish(f, ms, o, st, (#list == 0) and "fini" or "partiel",
          string.format("avant-poste %d : %d paire(s) restent (%s), %d partie(s) migree(s)", o.id, #list, why, st.done))
      elseif why ~= "fait" then
        say_why(f, ms, st, "start:" .. why, string.format("avant-poste %d (%s) : migration en veille (%s), %d paire(s) thermique(s)", o.id, o.kind, why, #list))
      end
    end
    ::next_outpost::
  end
  return false
end

local function ms_of(f)
  local ms = f.migration
  if not ms then
    ms = { next = 0, logs = 0, logs_f = 0, o = {} }
    f.migration = ms
  end
  return ms
end

---------------------------------------------------------------------------------------------------
-- Lot CHAMP : ordres « couvrir / ouvrir » de la capitalisation (script/ai3/capitalisation.lua) passés par le champ
---------------------------------------------------------------------------------------------------
-- Demande du lead (2/11) : « faire passer les ordres couvrir / ouvrir de la capitalisation par le champ pour que ses lignes électriques ne
-- bloquent plus les gisements ». Avant, un tel ordre posait une fonderie à foreuses du TREILLIS (gabarit d'AUTO) dont la ligne de foreuses
-- électriques, son tapis et ses poteaux occupaient le gisement : le champ n'y trouvait plus de bande (mesuré, partie de 150 min, graine
-- 20261020, emerald : « gisement occupe (hors paires) : electric-mining-drill 18, reserve 127 [...] transport-belt 29 », aucune bande).

--- Sorte d'avant-poste (T.outposts) dont le champ sait poser le minerai `resource` aujourd'hui (réceptacle four, foreuse, tapis débloqué,
--- poteau : Champ.data), ou nil.
function Mig.takes(f, resource)
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    if T.outposts[kind].resource == resource and is_furnace_kind(kind) and Champ.data(f, kind) ~= nil then return kind end
  end
  return nil
end

--- Un ordre de la capitalisation veut le gisement recensé `dep` { id, resource, tiles, x0, y0, x1, y1, cx, cy }. La cible (Mg.want_target) :
--- le champ déjà planifié sur ce gisement, sinon l'avant-poste à fours le plus proche du centre, sinon un gisement SANS avant-poste
--- (ms.fields, créé ici si un réseau alimenté est à portée d'une chaîne de poteaux). La cible devient « voulue » (st.want_until) : servie
--- avant les autres (start_next), une paire n'y est pas exigée, une bande sans paire n'attend pas que la plaque manque (begin_band).
--- Rend (numéro de la cible, bandes qui produisent déjà) ou nil, raison.
function Mig.want(f, dep, tick)
  local kind = Mig.takes(f, dep.resource)
  if not kind then return nil, "pas de champ pour ce minerai" end
  local ms = ms_of(f)
  ms.fields = ms.fields or {}
  local cands = {}
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local q = f.outposts[oid]
    if q.kind == kind then
      local sq = ms.o[oid]
      cands[#cands + 1] = { id = oid, pos = q.pos, framed = (sq and sq.frame and not sq.abandoned) and true or nil }
    end
  end
  for _, fid in ipairs(sorted_keys(ms.fields)) do
    local q = ms.fields[fid]
    if q.kind == kind then
      local sq = ms.o[fid]
      cands[#cands + 1] = { id = fid, pos = q.pos, field = true, framed = (sq and sq.frame and not sq.abandoned) and true or nil }
    end
  end
  local c = Mg.want_target(cands, dep, CFG.want_margin)
  local o = c and Champ.target(f, c.id)
  if not o then
    -- gisement neuf : sans réseau alimenté à portée d'une chaîne de poteaux, la bande se poserait sans courant
    if not Champ.powered_pole(f, f.hq.surface, dep.cx, dep.cy) then
      return nil, string.format("aucun reseau alimente a moins de %d tuiles", Champ.CFG.chain_r)
    end
    ms.nfield = (ms.nfield or 0) + 1
    local id = Champ.FIELD_BASE + ms.nfield
    o = { id = id, kind = kind, pos = { x = dep.cx, y = dep.cy }, field = true, dep = dep.id, drill_list = {}, sinks = {}, drills = 0,
      box = { dep.x0, dep.y0, dep.x1, dep.y1 } }
    ms.fields[id] = o
    say(f, ms, string.format("gisement %d (%s) : champ voulu par la capitalisation sur %s (%d tuiles), sans avant-poste", id, kind,
      tostring(dep.id), dep.tiles or 0), true)
  end
  if o.migr == "fini" then return nil, "champ deja pose en entier" end
  local st = ms.o[o.id]
  if not st then st = new_state(); ms.o[o.id] = st end
  if st.sans_gabarit then return nil, "champ impossible (gabarit)" end
  -- (un cadre VIDE, « aucune bande ne tient », n'est replanifié qu'après CFG.revive : le plan entier d'un grand gisement coûte cher)
  local wait = (st.order and #st.order == 0) and CFG.revive or CHAMP_CFG.retry
  if st.abandoned and tick >= (st.abandoned_at or 0) + wait then
    -- un champ abandonné (échecs de suite, aucune bande ne tenait) repart : refus et cadre vide oubliés (le gisement a pu changer)
    st.abandoned, st.abandoned_at, st.fails, st.bad = nil, nil, 0, nil
    if st.order and #st.order == 0 then st.frame, st.order = nil, nil end
  end
  if st.abandoned then return nil, "champ abandonne il y a moins de " .. math.floor(wait / 3600) .. " min" end
  if o.migr == "partiel" and st.stage == "veille" then o.migr, st.fails, st.bad = nil, 0, nil end -- arrêté après des échecs : on reprend
  st.want_until = math.max(st.want_until or 0, tick + CFG.want_ttl)
  return o.id, st.produced
end

--- Suivi d'un ordre de la capitalisation sur le champ `id` (garde la cible « voulue » tant que l'ordre suit). Rend { produced, stage,
--- pid, pstate, reason, built (entités posées du projet en cours), abandoned, migr } ou nil (cible perdue).
function Mig.follow(f, id, tick)
  local ms = f and f.migration
  local o = Champ.target(f, id)
  local st = ms and ms.o and ms.o[id]
  if not (o and st) then return nil end
  st.want_until = math.max(st.want_until or 0, tick + CFG.want_ttl)
  local p = st.pid and f.build and f.build.projects[st.pid]
  local built = 0
  if p then for _, e in ipairs(p.ents or {}) do if e.built then built = built + 1 end end end
  return { produced = st.produced or 0, stage = st.stage, pid = st.pid, pstate = p and p.state or nil, reason = p and p.reason or nil,
    built = built, abandoned = st.abandoned or nil, migr = o.migr }
end

--- Une pensée d'équipe. `free` : stock libre ({ [objet] = n }). Rend 1 si une étape a eu lieu, sinon 0.
function Mig.think(f, surface, book, free, tick)
  if not (f and f.outposts and f.hq and f.hq.valid and f.build) then return 0 end
  local ms = ms_of(f)
  if tick < ms.next then return 0 end
  ms.next = tick + CFG.every
  if tick >= (ms.report_next or 0) then -- lot CHAMP : état des bandes du champ au journal ([FO-CHAMP-ETAT])
    ms.report_next = tick + Champ.REPORT_EVERY
    Champ.report(f, surface, tick)
  end
  local item = T.DRILL_ELECTRIC
  if not game.entity_prototypes[item] then return 0 end
  local did = 0
  for _, slot in ipairs({ "cur", "cur2" }) do
    local id = ms[slot]
    if id then
      local o = Champ.target(f, id) -- (lot CHAMP : avant-poste, ou gisement voulu par la capitalisation)
      local st = o and ms.o[id]
      if not (o and st) then
        -- avant-poste perdu en cours de route : le projet du plan, s'il n'a rien retiré, est annulé (les matières rendues)
        local s2 = ms.o[id]
        release(ms, id)
        if s2 and s2.stage == "projet" and s2.pid then Build.cancel(f, s2.pid, "migration: avant-poste perdu") end
        -- lot CHAMP : journal (avant : silencieux ; une bande annulée ainsi paraissait « en attente » jusqu'à la fin du banc)
        if s2 and s2.pid then say(f, ms, string.format("avant-poste %d : avant-poste perdu, projet %d %s", id, s2.pid,
          s2.stage == "projet" and "annule" or "laisse au plan"), true) end
        if s2 then s2.stage, s2.pid = "veille", nil end
      else
        -- lot MIGRATION-DECLENCHE : le registre n'est purgé qu'APRÈS un retrait (étape « chantier ») ; en « projet » rien n'est retiré, et
        -- une paire tuée par une attaque pendant l'attente des matières (30 min au plus) doit être refaite (scarlet, avant-poste 6 : 8 paires
        -- avant la vague, 3 après, demande annulée sans rien migrer)
        if st.stage == "chantier" then purge_recon(f, o) end
        if st.stage == "projet" then step_project(f, surface, ms, o, st, tick)
        elseif st.stage == "chantier" then step_build(f, surface, ms, o, st, tick)
        else release(ms, id) end
        did = 1
      end
    end
  end
  -- lot THERMIQUE (ablation) : balayage des paires thermiques des gisements couverts (une fois par minute)
  if free and sweep(f, surface, ms, free, book, tick) > 0 then did = 1 end
  if ms.cur2 then return did end
  -- un créneau libre : le premier comme avant ; le second (lot CHAMP) seulement pour un champ d'un autre minerai que celui en cours
  local busy = ms.cur and Champ.target(f, ms.cur)
  if busy and not (ms.o[ms.cur] and ms.o[ms.cur].frame) then return did end
  local have = math.min(Stock.count(f, item), free and free[item] or 0)
  local obtainable = have > 0 or book:handcraftable(item)
  local started = start_next(f, surface, ms, free or {}, obtainable, tick, busy and { id = busy.id, kind = busy.kind } or nil)
  return (started or did == 1) and 1 or 0
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

--- Lot CHAMP : projets des DEUX créneaux (étapes « projet » et « chantier ») : { { pid, item } } (item : la plaque que la bande
--- produit, lue par la porte de la pile). Lecteur : script/ai3/automatisation.lua (un but « fabriquer » par créneau ; avant, le second
--- créneau n'avait aucun but et attendait ses matières : 26 min contre 15 pour le premier, azure, graine 20261020). Lecture seule.
function Mig.projects(f)
  local ms = f and f.migration
  local out = {}
  for _, slot in ipairs({ "cur", "cur2" }) do
    local id = ms and ms[slot]
    local st = id and ms.o and ms.o[id]
    local o = id and Champ.target(f, id)
    if st and (st.stage == "projet" or st.stage == "chantier") and st.pid then
      out[#out + 1] = { pid = st.pid, item = st.frame and o and T.outposts[o.kind] and T.outposts[o.kind].product or nil }
    end
  end
  return out
end

--- Résumé pour les bancs et la fenêtre (lecture seule) : nombres seulement.
function Mig.summary(f)
  local ms = f.migration
  if not ms then return { requests = 0, retired = 0, lines = 0, outposts = 0 } end
  local n = #sorted_keys(ms.o)
  local credit = 0
  for _, oid in ipairs(sorted_keys(f.outposts or {})) do credit = credit + (f.outposts[oid].migr_credit or 0) end
  return { requests = ms.requests or 0, retired = ms.retired or 0, lines = ms.lines or 0, outposts = n, cur = ms.cur, credit = credit, swept = ms.swept or 0 }
end

return Mig
