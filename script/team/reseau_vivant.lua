--[[
  Lot RESEAU-VIVANT : la santé du réseau électrique d'une équipe APRÈS l'état « fini » (règle pure : shared/team/reseau_sante.lua ;
  modèle du réseau : shared/team/reseau.lua). Appelé par script/team/build.lua à chaque passe de l'équipe (Rv.step), derrière sa
  propre horloge : rien à abonner (les abonnements sont statiques, control.lua inchangé).

  FRONTIÈRE avec la reconstruction (lots COUVERTURE / RECONSTRUIRE, registre de pièces détruites par événement de mort) : ce
  module ne tient PAS de registre et ne refait PAS les pièces une à une. Il LIT l'état (existence des pièces du projet de la
  centrale, production lue au moteur, combustible, réseau du moteur de chaque consommateur, ennemis à portée) et décide au niveau
  du RÉSEAU : refaire la centrale sur place, la demander AILLEURS, ou relever les poteaux perdus qui rallument des
  consommateurs. Refaire = REOUVRIR le projet (les pièces perdues redeviennent « à bâtir » : fantômes, PNJ, objets du coffre, la
  machinerie de Build, sans second mécanisme de pose). Si le registre de pièces est un jour fusionné, il appelle Rv.reopen.

  Entrées lues (jamais écrites dans la partie) : le projet de la centrale `b.plant`, les projets finis (poteaux), les
  générateurs et consommateurs de la force (réseau électrique du moteur), `find_nearest_enemy` autour du site.
  État : b.sante (nombres, booléens, chaînes ; jamais de fonction) ; b.avoid = sites écartés { x, y, r }.
]]

local M = require("shared.team.modules")
local S = require("shared.team.reseau_sante")
local R = require("shared.team.reseau")
local P = require("shared.team.plan")
local Br = require("shared.team.reseau_pont")

local Rv = {}

Rv.PERIOD = 1200          -- 20 s : relevé de la centrale
Rv.NET_PERIOD = 7200      -- 2 min : consommateurs sur îlot, poteaux perdus
Rv.POLE_REOPEN_MAX = 5    -- réouvertures d'un même projet pour ses poteaux (on ne nourrit pas un point que l'ennemi tient)
Rv.POLE_ENEMY_R = 28      -- jamais de pose de poteau avec un ennemi à cette portée
Rv.CAND_MAX = 40          -- poteaux perdus examinés par cycle
Rv.RELOC_BLOCK = 5 * 3600  -- pas de nouvelle demande d'autre site pendant 5 min après un refus du plan
Rv.PLANNED_R = 15         -- tuiles : un poteau prévu non posé à cette distance de l'écart suspend le pont
Rv.BRIDGE_SEEN = 2        -- relevés de réseau de suite avec un îlot pontable avant de poser un pont
Rv.BRIDGE_WAIT = 10 * 3600  -- un pont qui attend ses poteaux au coffre plus de 10 min est annulé
Rv.BRIDGE_BLOCK = 5 * 3600
Rv.LOG_EVERY = 5 * 3600   -- une ligne de synthèse par équipe et par 5 min

local TYPES = {
  source = { "boiler" }, gen = { "generator" }, eau = { "offshore-pump" }, tuyau = { "pipe", "pipe-to-ground" },
}
local KIND = { boiler = "source", generator = "gen", offshore = "eau", pipe = "tuyau", ptg = "tuyau" }
local ELEC_TYPES = { "mining-drill", "assembling-machine", "lab", "inserter", "furnace" }

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Une entité de ce GENRE (type du moteur : un niveau supérieur remplace le nom, pas le type) de la force sur la place `e`.
local function real_of(surface, e, force, types)
  local found = surface.find_entities_filtered({ position = { e.x, e.y }, radius = 0.2, force = force, type = types })
  return found[1]
end

local function is_pole(name) return name:find("electric%-pole") ~= nil end

--- Rouvre : les pièces `ents` (marquées bâties mais absentes) redeviennent à bâtir ; le projet fini repasse en réserve.
function Rv.reopen(q, ents, why)
  for _, e in ipairs(ents) do
    e.built, e.ghosted, e.fails, e.npc_blocks = false, nil, 0, 0
  end
  if q.state == "fini" then q.state, q.reason, q.reserve_next = "reserve", why, nil end
  q.reopened = (q.reopened or 0) + 1
end

---------------------------------------------------------------------------------------------------
-- Relevé de la centrale
---------------------------------------------------------------------------------------------------
local function site_of(pp)
  local pt = pp.parts and pp.parts[1]
  if not pt then return nil end
  return { x = pt.ox + (pt.w or 0) / 2, y = pt.oy + (pt.h or 0) / 2 }
end

local function plant_read(f, surface, pp)
  local inp = { fini = pp.state == "fini", missing = { source = 0, gen = 0, eau = 0, tuyau = 0 },
    present = { source = 0, gen = 0, eau = 0, tuyau = 0 }, prod_kw = 0, dry = 0 }
  local lost = {}
  for _, e in ipairs(pp.ents) do
    local sp = M.spec(e.name)
    local k = sp and KIND[sp.kind]
    if k and e.built then
      local r = real_of(surface, e, f.force, TYPES[k])
      if r then
        inp.present[k] = inp.present[k] + 1
        if k == "gen" then inp.prod_kw = inp.prod_kw + (r.energy_generated_last_tick or 0) * 60 / 1000 end
        if k == "source" then
          local inv = r.get_fuel_inventory()
          if inv and inv.is_empty() and ((r.burner and r.burner.remaining_burning_fuel) or 0) <= 0 then inp.dry = inp.dry + 1 end
        end
      else
        inp.missing[k] = inp.missing[k] + 1
        lost[#lost + 1] = e
      end
    end
  end
  return inp, lost
end

--- Demande nominale (kW) des machines électriques posées dans les projets finis : pas une mesure, un ordre de grandeur pour
--- distinguer « centrale arrêtée faute de demande » de « centrale en panne ».
local function nominal_demand(b)
  local kw = 0
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and q.state == "fini" then
      for _, e in ipairs(q.ents) do
        if e.built then
          local sp = M.spec(e.name)
          if sp and (sp.kind == "assembler" or sp.kind == "lab" or sp.kind == "drill" or sp.kind == "inserter") then
            kw = kw + (sp.usage_kw or sp.power or 0)
          end
        end
      end
    end
  end
  return kw
end

---------------------------------------------------------------------------------------------------
-- Relevé du réseau (engine = vérité : l'identifiant de réseau de chaque consommateur)
---------------------------------------------------------------------------------------------------
local function box_of(e, id)
  local bb = e.bounding_box
  return { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y, kw = 0, id = id }
end

--- { islands = n, uncovered = n, cons = { boîtes des consommateurs hors réseau de centrale }, gens = { boîtes } }
local function net_read(f, surface)
  local gnets, gens = {}, {}
  for _, g in ipairs(surface.find_entities_filtered({ force = f.force, type = "generator" })) do
    local id = g.electric_network_id
    if id then gnets[id] = true end
    gens[#gens + 1] = box_of(g)
  end
  local out = { islands = 0, uncovered = 0, cons = {}, gens = gens, gnets = gnets }
  for _, e in ipairs(surface.find_entities_filtered({ force = f.force, type = ELEC_TYPES })) do
    if e.prototype.electric_energy_source_prototype then
      local id = e.electric_network_id
      if not id then
        out.uncovered = out.uncovered + 1
        out.cons[#out.cons + 1] = box_of(e)
      elseif not gnets[id] then
        out.islands = out.islands + 1
        out.cons[#out.cons + 1] = box_of(e, id)
      end
    end
  end
  return out
end

--- Poteaux perdus : { { e, q } } (entité du plan, projet) pour tous les projets finis ou en cours.
local function lost_poles(f, surface, b)
  local out = {}
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and (q.reopened or 0) < Rv.POLE_REOPEN_MAX and (q.state == "fini" or q.state == "chantier" or q.state == "raccordement") then
      for _, e in ipairs(q.ents) do
        if e.built and is_pole(e.name) and not real_of(surface, e, f.force, "electric-pole") then
          out[#out + 1] = { e = e, q = q }
          if #out >= Rv.CAND_MAX then return out end
        end
      end
    end
  end
  return out
end

--- Plan de relève : quels poteaux perdus rallument les consommateurs hors réseau (coût minimal, R.repair). Rend la liste
--- { { e, q } } et le texte du plan.
local function repair_plan(f, surface, nr, cands)
  local poles, ents, idx = {}, surface.find_entities_filtered({ force = f.force, type = "electric-pole" }), {}
  table.sort(ents, function(a, c) return a.unit_number < c.unit_number end)
  for i, p in ipairs(ents) do
    local pr = p.prototype
    poles[i] = { x = p.position.x, y = p.position.y, wire = pr.max_wire_distance or 0, supply = pr.supply_area_distance or 0 }
    idx[p.unit_number] = i
  end
  -- les fils RÉELS du moteur entre poteaux vivants (le modèle à la portée surestime la connexité)
  local edges, have_edges = {}, false
  for i, p in ipairs(ents) do
    local okn, nbs = pcall(function() return p.neighbours end)
    if okn and nbs then have_edges = true end
    for _, o in ipairs((okn and nbs and nbs.copper) or {}) do
      local j = o.valid and idx[o.unit_number]
      if j and j > i then edges[#edges + 1] = { i, j } end
    end
  end
  local model = {}
  for i, c in ipairs(cands) do
    local pr = game.entity_prototypes[c.e.name]
    model[i] = { x = c.e.x, y = c.e.y, wire = pr and pr.max_wire_distance or 7.5, supply = pr and pr.supply_area_distance or 2.5, cost = 1 }
  end
  local plan = R.repair({ poles = poles, consumers = nr.cons, producers = nr.gens, edges = have_edges and edges or nil }, model)
  local out = {}
  for _, j in ipairs(plan.chosen) do out[#out + 1] = cands[j] end
  local txt = string.format("%d poteau(x) a relever sur %d perdu(s), %d consommateur(s) a rallumer, %d hors d'atteinte", #out, #cands,
    plan.restored or 0, #(plan.unreachable or {}))
  return out, txt, plan
end

---------------------------------------------------------------------------------------------------
-- Ponts : îlots de poteaux jamais reliés au réseau d'une centrale
---------------------------------------------------------------------------------------------------
--- Poteaux du moteur et écarts îlot -> réseau alimenté (shared/team/reseau_pont.lua). Rend la liste d'écarts et les poteaux.
local function bridge_gaps(f, surface, nr)
  local need = {}
  for _, c in ipairs(nr.cons) do if c.id then need[c.id] = true end end
  local ents = surface.find_entities_filtered({ force = f.force, type = "electric-pole" })
  table.sort(ents, function(a, c) return a.unit_number < c.unit_number end)
  local poles = {}
  for i, e in ipairs(ents) do
    poles[i] = { x = e.position.x, y = e.position.y, id = e.electric_network_id, wire = e.prototype.max_wire_distance or 0, name = e.name }
  end
  return Br.gaps(poles, need, nr.gnets), poles, ents
end

--- Lance un pont pour le plus court écart. Rend un texte (journal) et vrai si un projet ou un fil a été posé.
local function make_bridge(api, f, surface, sv, nr, tick)
  local b = f.build
  local gaps, poles, ents = bridge_gaps(f, surface, nr)
  local g
  for _, x in ipairs(gaps) do if Br.useful(x) then g = x break end end
  if not g then return "aucun ecart utile", false end
  local pa, pb = poles[g.a], poles[g.b]
  -- un poteau PRÉVU et pas encore posé près de l'écart (un chantier qui avance) : ce n'est pas un îlot oublié, le chantier le relie
  -- (un pont ferait un doublon, exactement ce que le lot supprime)
  for k = 0, 6 do
    local qx, qy = pa.x + (pb.x - pa.x) * k / 6, pa.y + (pb.y - pa.y) * k / 6
    for _, pid in ipairs(b.order) do
      local q = b.projects[pid]
      if q and q.state ~= "refuse" and q.state ~= "fini" then
        for _, e in ipairs(q.ents) do
          if not e.built and is_pole(e.name) and (e.x - qx) ^ 2 + (e.y - qy) ^ 2 <= Rv.PLANNED_R * Rv.PLANNED_R then
            return string.format("chantier en cours : poteau prevu en (%g, %g) pres de l'ecart (projet %d)", e.x, e.y, q.id), false
          end
        end
      end
    end
  end
  if g.d <= g.reach + 1e-6 then
    -- déjà à portée de fil mais pas reliés : on tire le fil (un fil, pas un chantier)
    local ok = pcall(function() return ents[g.a].connect_neighbour({ wire = defines.wire_type.copper, target_entity = ents[g.b] }) end)
    return string.format("fil tire entre deux poteaux a %.1f tuiles (%s)", g.d, ok and "ok" or "refuse"), ok
  end
  local function free(x, y)
    local tx, ty = math.floor(x), math.floor(y)
    if b.occ[P.tkey(tx, ty)] then return false end
    return surface.can_place_entity({ name = pa.name, position = { x, y }, force = f.force })
  end
  local chain = P.pole_chain({ x = pa.x, y = pa.y }, { x = pb.x, y = pb.y }, g.reach, false, free)
  if not chain or #chain == 0 then return string.format("aucune chaine de poteaux entre l'ilot et le reseau (ecart %.1f)", g.d), false end
  local id, why = api.bridge(f, pa.name, chain)
  if not id then return "pont refuse : " .. tostring(why), false end
  sv.bridge = { pid = id, since = tick }
  return string.format("pont %d : %d poteau(x) sur %.1f tuiles entre l'ilot (reseau %s) et la centrale", id, #chain, g.d, tostring(g.id)), true
end

---------------------------------------------------------------------------------------------------
-- Pas d'une équipe
---------------------------------------------------------------------------------------------------
local function say(f, tick, what)
  log(string.format("[FO-RESEAU] %s : %s a %.1f min", f.key or "player", what, tick / 3600))
end

--- api = { plant = Build.plant } (fourni par build.lua : ce module ne requiert pas build.lua).
function Rv.step(api, f, surface, tick)
  local b = f.build
  if not b then return end
  local sv = b.sante
  if not sv then
    sv = { st = S.new(), next = tick + Rv.PERIOD, net_next = tick + Rv.NET_PERIOD, islands = 0, uncovered = 0, lost_links = 0,
      demand = 0, healthy = false, log_next = tick + Rv.LOG_EVERY, last_why = "", decisions = 0 }
    b.sante = sv
  end
  if tick < sv.next then return end
  sv.next = tick + Rv.PERIOD
  -- une centrale de remplacement refusée : retour à la centrale d'origine, rouverte sur place (dernier recours)
  if sv.reloc then
    local np = b.projects[sv.reloc.new]
    if not np or np.state == "refuse" then
      local old = b.projects[sv.reloc.old]
      b.avoid = nil
      if old then
        b.plant = old.id
        old.abandoned = nil
      end
      -- aucun autre site : on ne rouvre PAS sous le feu ; la décision suivante rouvrira dès que les ennemis seront partis, et
      -- aucune nouvelle demande d'autre site pendant Rv.RELOC_BLOCK ticks (un plan coûte 25 à 40 ms)
      sv.reloc_block = tick + Rv.RELOC_BLOCK
      say(f, tick, string.format("centrale de remplacement refusee (%s) : retour au site d'origine, pieces a refaire quand il sera sur",
        tostring(np and np.reason or "perdue")))
      sv.reloc = nil
      return
    elseif np.state == "fini" then
      say(f, tick, "centrale de remplacement FINIE (projet " .. np.id .. ")")
      sv.reloc = nil
    end
  end
  if sv.bridge then
    local bp = b.projects[sv.bridge.pid]
    if not bp or bp.state == "fini" or bp.state == "refuse" then
      if bp and bp.state == "fini" then say(f, tick, "pont " .. bp.id .. " FINI") end
      sv.bridge = nil
      sv.net_next = tick + 1200
    elseif bp.state == "reserve" and tick - sv.bridge.since > Rv.BRIDGE_WAIT then
      api.cancel(f, bp.id, "pont: poteaux introuvables au coffre")
      say(f, tick, "pont " .. bp.id .. " annule (poteaux introuvables au coffre apres 10 min)")
      sv.bridge, sv.bridge_block = nil, tick + Rv.BRIDGE_BLOCK
    end
  end
  local pp = b.plant and b.projects[b.plant]
  if not pp or pp.state == "refuse" or pp.state == "attente" or pp.state == "plan" then return end
  -- consommateurs sur îlot (période longue)
  local nr
  if tick >= sv.net_next then
    sv.net_next = tick + Rv.NET_PERIOD
    nr = net_read(f, surface)
    sv.islands, sv.uncovered = nr.islands, nr.uncovered
    sv.demand = nominal_demand(b)
    sv.lost_links, sv.bridges = 0, 0
    if nr.islands + nr.uncovered > 0 then
      sv.lost_links = #lost_poles(f, surface, b)
      if sv.lost_links == 0 then sv.bridges = #(bridge_gaps(f, surface, nr)) end
    end
    sv.bridge_seen = sv.bridges > 0 and ((sv.bridge_seen or 0) + 1) or 0
  end
  local inp, lost = plant_read(f, surface, pp)
  inp.demand_kw = sv.demand
  inp.islands, inp.uncovered, inp.lost_links = sv.islands, sv.uncovered, sv.lost_links
  inp.bridges = (tick >= (sv.bridge_block or 0) and (sv.bridge_seen or 0) >= Rv.BRIDGE_SEEN) and (sv.bridges or 0) or 0
  inp.bridging = sv.bridge ~= nil
  local site = site_of(pp)
  inp.enemies = 0
  if site then
    local en = surface.find_nearest_enemy({ position = site, max_distance = S.DANGER_R, force = f.force })
    if en then
      inp.enemies = 1
      sv.enemy_x, sv.enemy_y = en.position.x, en.position.y -- la POSITION du danger, pas seulement celle du site
    end
  end
  -- une perte survenue sur une centrale qui marchait : compte pour le jugement du site
  local was_healthy = sv.healthy
  sv.healthy = inp.fini and S.lost(inp) == 0 and inp.prod_kw > 0
  if sv.healthy then S.recovered(sv.st) end
  if was_healthy and S.lost(inp) > 0 then S.note_loss(sv.st, 1) end
  local action, why, detail = S.decide(inp, sv.st)
  if action == "autre_site" and tick < (sv.reloc_block or 0) then
    action, why = "attendre", "aucun autre site (essai recent refuse par le plan)"
  end
  -- synthèse périodique
  if tick >= sv.log_next then
    sv.log_next = tick + Rv.LOG_EVERY
    say(f, tick, string.format("synthese : centrale %s, production %.0f kW, sources %d/%d a sec %d, machines %d, pompes %d, perdues %d, "
      .. "consommateurs hors reseau %d (sans poteau %d), poteaux perdus %d, ennemis %d, essais %d, deplacements %d",
      pp.state, inp.prod_kw, inp.present.source, inp.present.source + inp.missing.source, inp.dry, inp.present.gen, inp.present.eau,
      detail.lost, sv.islands + sv.uncovered, sv.uncovered, sv.lost_links, inp.enemies, sv.st.tries, sv.st.relocations))
  end
  if action == "ok" or action == "attendre" then
    if action == "attendre" and why ~= sv.last_why and why ~= "centrale pas finie" then
      sv.last_why = why
      say(f, tick, "attend : " .. why)
    end
    return
  end
  sv.last_why = ""
  sv.decisions = sv.decisions + 1
  if action == "reposer" then
    Rv.reopen(pp, lost, "reseau: pieces de la centrale perdues")
    S.applied(sv.st, action, tick)
    say(f, tick, string.format("centrale: %s ; %d piece(s) rouverte(s) (essai %d)", why, #lost, sv.st.tries))
  elseif action == "autre_site" then
    if sv.reloc then return end
    b.avoid = b.avoid or {}
    -- écartés : l'ancien site (son lot) et, quand un ennemi est connu, TOUT ce qui est à portée de lui (la centrale de remplacement
    -- doit finir à plus de S.DANGER_R du danger, pas seulement loin de l'ancien site)
    if site then b.avoid[#b.avoid + 1] = { x = site.x, y = site.y, r = sv.enemy_x and 16 or S.DANGER_R } end
    if sv.enemy_x then b.avoid[#b.avoid + 1] = { x = sv.enemy_x, y = sv.enemy_y, r = S.DANGER_R } end
    while #b.avoid > 6 do table.remove(b.avoid, 1) end
    local old = pp
    old.abandoned = true
    b.plant = nil
    local id = api.plant(f)
    sv.reloc = { old = old.id, new = id }
    S.applied(sv.st, action, tick)
    say(f, tick, string.format("centrale: %s ; centrale demandee AILLEURS (projet %s, site ecarte %.0f,%.0f rayon %d)", why,
      tostring(id), site and site.x or 0, site and site.y or 0, S.DANGER_R))
  elseif action == "relier" then
    if tick < (sv.relier_next or 0) then return end
    nr = nr or net_read(f, surface)
    local cands = lost_poles(f, surface, b)
    local plan_list, txt = repair_plan(f, surface, nr, cands)
    if #plan_list == 0 and #cands > 0 and (nr.islands + nr.uncovered) > 0 then
      -- le modèle ne voit pas de chemin : repli, les poteaux perdus les plus proches des consommateurs hors réseau
      local near = {}
      for _, c in ipairs(cands) do
        for _, bx in ipairs(nr.cons) do
          if math.abs(c.e.x - (bx.x0 + bx.x1) / 2) < 24 and math.abs(c.e.y - (bx.y0 + bx.y1) / 2) < 24 then near[#near + 1] = c break end
        end
      end
      plan_list, txt = near, txt .. " ; repli : " .. #near .. " proche(s) des consommateurs"
    end
    local per = {}
    local n = 0
    for _, c in ipairs(plan_list) do
      local clear = not surface.find_nearest_enemy({ position = { x = c.e.x, y = c.e.y }, max_distance = Rv.POLE_ENEMY_R, force = f.force })
      if clear then
        per[c.q.id] = per[c.q.id] or { q = c.q, ents = {} }
        per[c.q.id].ents[#per[c.q.id].ents + 1] = c.e
        n = n + 1
      end
    end
    for _, pid in ipairs(sorted_keys(per)) do Rv.reopen(per[pid].q, per[pid].ents, "reseau: poteaux perdus") end
    -- rien à rouvrir (poteaux perdus qui ne servent à rien, ennemis à portée) : on ne relit pas ni ne journalise chaque 20 s
    sv.relier_next = tick + (n > 0 and 1200 or 7200)
    if n > 0 or sv.relier_quiet ~= txt then
      sv.relier_quiet = txt
      say(f, tick, string.format("reseau: %s ; %s ; %d rouvert(s) (les autres : ennemis a %d tuiles)", why, txt, n, Rv.POLE_ENEMY_R))
    end
    sv.net_next = tick + 1200 -- relire vite après la remise en état
  elseif action == "ponter" then
    nr = nr or net_read(f, surface)
    local txt, made = make_bridge(api, f, surface, sv, nr, tick)
    say(f, tick, string.format("reseau: %s ; %s", why, txt))
    if not made then sv.bridge_block = tick + (txt:find("chantier en cours", 1, true) and 7200 or Rv.BRIDGE_BLOCK) end
    sv.net_next = tick + 1200
  elseif action == "combustible" then
    if tick >= (sv.comb_next or 0) then
      sv.comb_next = tick + Rv.LOG_EVERY
      say(f, tick, "centrale: " .. why .. " (combustible : pas un probleme de reseau, les bras de la centrale s'en chargent)")
    end
  end
end

return Rv
