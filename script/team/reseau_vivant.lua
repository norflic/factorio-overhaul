--[[
  Lot CORR-RESEAU (version mince du lot RESEAU-VIVANT) : la santé du réseau électrique d'une équipe APRÈS l'état « fini » (règle
  pure : shared/team/reseau_sante.lua). Appelé par script/team/build.lua à chaque passe de l'équipe (Rv.step), derrière sa propre
  horloge : rien à abonner (les abonnements sont statiques, control.lua inchangé).

  Remarque du DC (28/10) : « savoir relier le réseau électrique + ne pas se baser que sur un seul input, ex : machine à vapeur
  détruite + trop dangereux => ils doivent trouver une autre voie et réalimenter le réseau ». Trois cas seulement :
    1. pièces de la centrale perdues, site sûr : le projet est ROUVERT (les pièces perdues redeviennent « à bâtir » : fantômes, PNJ,
       objets du coffre, la machinerie de Build, aucun second mécanisme de pose) ;
    2. pièces perdues et site DANGEREUX (ennemis vus de suite, pertes répétées) : la centrale est demandée AILLEURS (b.avoid écarte le
       lot perdu et le danger) ; remplacement refusé ou site calme : retour sur place ;
    3. centrale vivante mais des consommateurs sur un îlot sans centrale : les poteaux PERDUS des projets sont rouverts (jamais un
       poteau neuf : aucun poteau n'est ajouté, donc aucun doublon n'est créé).
  Entrées lues (jamais écrites dans la partie) : le projet de la centrale `b.plant`, les projets finis (poteaux), les générateurs et
  consommateurs de la force, `find_nearest_enemy` autour du site. État : b.sante (nombres, booléens, chaînes ; jamais de fonction) ;
  b.avoid = sites écartés { x, y, r }.
]]

local M = require("shared.team.modules")
local S = require("shared.team.reseau_sante")

local Rv = {}

Rv.PERIOD = 1200          -- 20 s : relevé de la centrale
Rv.NET_PERIOD = 7200      -- 2 min : consommateurs sur îlot, poteaux perdus
Rv.POLE_REOPEN_MAX = 5    -- réouvertures d'un même projet POUR SES POTEAUX (q.poles_reopened ; les reposes de la centrale ont leur plafond : S.MAX_TRIES, S.SITE_LOSSES, S.MAX_RELOC)
Rv.POLE_ENEMY_R = 28      -- jamais de pose de poteau avec un ennemi à cette portée
Rv.CAND_MAX = 40          -- poteaux perdus examinés par cycle
Rv.LOG_EVERY = 5 * 3600   -- une ligne de synthèse par équipe et par 5 min
Rv.LOT_AVOID_R = 16       -- tuiles : rayon écarté autour du lot de la centrale perdue (le lot fait 32 de côté)

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
  local found = surface.find_entities_filtered({ position = { e.x, e.y }, radius = 0.6, force = force, type = types })
  return found[1]
end

local function is_pole(name) return name:find("electric%-pole") ~= nil end

--- Rouvre : les pièces `ents` (marquées bâties mais absentes) redeviennent à bâtir ; le projet fini repasse en réserve.
function Rv.reopen(q, ents, why, surface)
  for _, e in ipairs(ents) do
    e.built, e.ghosted, e.fails, e.npc_blocks = false, nil, 0, 0
  end
  if q.state == "fini" then
    q.counted = true -- déjà compté aux statistiques : une sauvegarde d'avant ce drapeau ne recompte pas au « fini » suivant
    q.state, q.reason, q.reserve_next = "reserve", why, nil
    q.retries, q.retry_at = 0, nil -- lot INTEG-RECONSTRUCTION (D2) : les reprises de la construction ne comptent pas pour la reconstruction
  end
  q.reopened = (q.reopened or 0) + 1
  q.reopened_tick = game.tick
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
--- { islands = consommateurs sur un réseau sans centrale, free = consommateurs sous aucun poteau }. Le consommateur dans l'emprise d'un
--- projet en construction n'est pas compté : ses poteaux ne sont pas forcément posés, il n'est pas fini.
local function in_construction(b, x, y)
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and q.state ~= "fini" and q.state ~= "refuse" then
      for k = 1, 16 do
        local pt = q.parts and q.parts[k]
        if pt and pt.ox and x >= pt.ox - 3 and x <= pt.ox + (pt.w or 0) + 3 and y >= pt.oy - 3 and y <= pt.oy + (pt.h or 0) + 3 then
          return true
        end
      end
    end
  end
  return false
end

local function net_read(f, surface, b)
  local gnets = {}
  for _, g in ipairs(surface.find_entities_filtered({ force = f.force, type = "generator" })) do
    local id = g.electric_network_id
    if id then gnets[id] = true end
  end
  local out = { islands = 0, uncovered = 0 }
  for _, e in ipairs(surface.find_entities_filtered({ force = f.force, type = ELEC_TYPES })) do
    -- Le réseau d'abord : la quasi-totalité des machines est sur un réseau avec centrale, et le prototype (objet créé à chaque lecture)
    -- ne se lit que pour les autres (revue statique 29/10 : le relevé touchait toutes les machines de la force toutes les 2 min).
    local id = e.electric_network_id
    if not (id and gnets[id]) and e.prototype.electric_energy_source_prototype
      and not in_construction(b, e.position.x, e.position.y) then
      if id then out.islands = out.islands + 1 else out.uncovered = out.uncovered + 1 end
    end
  end
  return out
end

--- Poteaux perdus : { { e, q } } (entité du plan, projet) pour tous les projets finis ou en cours.
local function lost_poles(f, surface, b)
  local out = {}
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and not q.abandoned and (q.poles_reopened or 0) < Rv.POLE_REOPEN_MAX and (q.state == "fini" or q.state == "chantier" or q.state == "raccordement") then
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
  if b.opts and b.opts.sante == false then return end -- interrupteur D'ESSAI (remote fo-ia1d set_option) : le témoin des bancs ; allumé sinon
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
    local foe0 = sv.reloc.x and surface.find_nearest_enemy({ position = { x = sv.reloc.x, y = sv.reloc.y }, max_distance = S.DANGER_R,
      force = f.force })
    local verdict, vwhy = S.reloc_verdict({ new_state = np and np.state or nil, enemies = foe0 and 1 or 0 }, sv.st)
    if verdict == "rentrer" then
      local old = b.projects[sv.reloc.old]
      -- un remplacement pas commencé est annulé (matières rendues au coffre) ; l'automatisation suit la centrale qui reste
      if np and np.state ~= "refuse" and api.cancel then api.cancel(f, np.id, "reseau: retour au site d'origine") end
      if np then np.abandoned = true end
      b.avoid = nil
      if old then
        old.abandoned = nil
        b.plant = old.id
        local _, lost = plant_read(f, surface, old)
        Rv.reopen(old, lost, "reseau: retour sur place", surface)
        say(f, tick, string.format("retour au site d'origine : %s ; %d piece(s) rouverte(s)", vwhy, #lost))
      end
      sv.reloc = nil
      return
    elseif verdict == "fini" then
      say(f, tick, "centrale de remplacement FINIE (projet " .. np.id .. ")")
      sv.reloc = nil
    end
  end
  local pp = b.plant and b.projects[b.plant]
  if not pp or pp.state == "refuse" or pp.state == "attente" or pp.state == "plan" then return end
  -- consommateurs sur îlot (période longue)
  local nr
  if tick >= sv.net_next then
    sv.net_next = tick + Rv.NET_PERIOD
    nr = net_read(f, surface, b)
    sv.islands, sv.uncovered = nr.islands, nr.uncovered
    sv.demand = nominal_demand(b)
    sv.lost_links = 0
    if nr.islands + nr.uncovered > 0 then sv.lost_links = #lost_poles(f, surface, b) end
  end
  local inp, lost = plant_read(f, surface, pp)
  inp.demand_kw = sv.demand
  inp.islands, inp.uncovered, inp.lost_links = sv.islands, sv.uncovered, sv.lost_links
  local site = site_of(pp)
  inp.enemies = 0
  sv.enemy_x, sv.enemy_y = nil, nil -- le danger VU à ce relevé seulement : pas de position périmée dans les sites écartés (pertes seules : le lot perdu)
  if site then
    local en = surface.find_nearest_enemy({ position = site, max_distance = S.DANGER_R, force = f.force })
    if en and en.valid then
      inp.enemies = 1
      sv.enemy_x, sv.enemy_y = en.position.x, en.position.y -- le danger, pas le site : c'est lui qu'une centrale de remplacement évite
    end
  end
  -- une perte survenue sur une centrale qui marchait : compte pour le jugement du site
  local was_healthy = sv.healthy
  sv.healthy = inp.fini and S.lost(inp) == 0 and inp.prod_kw > 0
  if sv.healthy then S.recovered(sv.st) end
  if was_healthy and S.lost(inp) > 0 then S.note_loss(sv.st, 1) end
  local action, why, detail = S.decide(inp, sv.st)
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
  if action == "relier" and tick < (sv.idle_until or 0) then return end
  sv.last_why = ""
  sv.decisions = sv.decisions + 1
  if action == "reposer" then
    Rv.reopen(pp, lost, "reseau: pieces de la centrale perdues", surface)
    S.applied(sv.st, action, tick)
    say(f, tick, string.format("centrale: %s ; %d piece(s) rouverte(s) (essai %d)", why, #lost, sv.st.tries))
  elseif action == "autre_site" then
    if sv.reloc then return end
    b.avoid = b.avoid or {}
    -- le lot perdu (ses voisins immédiats) ET le danger lui-même : la centrale de remplacement finit à plus de S.DANGER_R du
    -- danger (centre du lot à S.DANGER_R + 16 + AVOID_MARGIN du danger : même en diagonale du lot, la pièce la plus proche reste à plus de S.DANGER_R) ; sans ennemi vu au moment de la décision (pertes
    -- seules), seul le lot perdu est écarté
    if site then b.avoid[#b.avoid + 1] = { x = site.x, y = site.y, r = Rv.LOT_AVOID_R } end
    if sv.enemy_x then b.avoid[#b.avoid + 1] = { x = sv.enemy_x, y = sv.enemy_y, r = S.DANGER_R + 16 } end
    while #b.avoid > 6 do table.remove(b.avoid, 1) end
    local old = pp
    old.abandoned = true
    b.plant = nil
    local id = api.plant(f)
    sv.reloc = { old = old.id, new = id, x = site and site.x, y = site and site.y }
    local np = id and b.projects[id]
    if np then np.keep = true end -- l'automatisation ne l'annule pas (15 min sans progrès) : seul ce module décide du retour
    S.applied(sv.st, action, tick)
    say(f, tick, string.format("centrale: %s ; centrale demandee AILLEURS (projet %s, site ecarte %.0f,%.0f, danger %s)", why,
      tostring(id), site and site.x or 0, site and site.y or 0,
      sv.enemy_x and string.format("%.0f,%.0f ecarte de %d tuiles", sv.enemy_x, sv.enemy_y, S.DANGER_R + 16) or "non vu"))
  elseif action == "relier" then
    nr = nr or net_read(f, surface, b)
    if nr.islands + nr.uncovered == 0 then
      -- le relevé qui a déclenché la décision est périmé : les poteaux posés depuis couvrent tout, rien à faire
      sv.islands, sv.uncovered, sv.lost_links = 0, 0, 0
      return
    end
    -- les poteaux PERDUS (jamais un poteau neuf) : ceux de leurs projets sont rouverts, sauf sous le feu
    local per, n = {}, 0
    for _, c in ipairs(lost_poles(f, surface, b)) do
      local foe = surface.find_nearest_enemy({ position = { x = c.e.x, y = c.e.y }, max_distance = Rv.POLE_ENEMY_R, force = f.force })
      if not foe then
        per[c.q.id] = per[c.q.id] or { q = c.q, ents = {} }
        per[c.q.id].ents[#per[c.q.id].ents + 1] = c.e
        n = n + 1
      end
    end
    for _, pid in ipairs(sorted_keys(per)) do
      local q = per[pid].q
      Rv.reopen(q, per[pid].ents, "reseau: poteaux perdus", surface)
      q.poles_reopened = (q.poles_reopened or 0) + 1 -- le plafond des poteaux ne se mêle pas aux reposes de la centrale
    end
    -- un essai qui ne rouvre rien n'est pas un essai : on se tait 5 min (le compte d'essais ne s'use que sur du travail fait)
    if n > 0 then S.applied(sv.st, action, tick) else sv.idle_until = tick + 18000 end
    say(f, tick, string.format("reseau: %s ; %d poteau(x) perdu(s) rouvert(s) (les autres : ennemi a moins de %d tuiles)", why, n, Rv.POLE_ENEMY_R))
    sv.net_next = tick + 1200 -- relire vite après la remise en état
  elseif action == "combustible" then
    say(f, tick, "centrale: " .. why .. " (combustible : pas un probleme de reseau, les bras de la centrale s'en chargent)")
  end
end

return Rv
