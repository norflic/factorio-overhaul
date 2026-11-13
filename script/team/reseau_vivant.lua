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
local Cr = require("shared.team.coupure_reseau") -- lot ENERGIE (2/11) : chemin le plus court des poteaux à reposer, second chemin
local Gens = require("script.team.generateurs") -- lot X10-S4 : registre des génératrices (plus de recherche sur toute la surface)
local Profiler = require("script.core.profiler") -- lot UPS : portées fines « ws: » (recherches sur toute la surface ; mesure seulement)
local Ze = require("shared.team.zone_equipe") -- lot UPS-2 : intersection d'une tranche et de la zone de l'équipe (Ze.clip, Ze.area)
local Zone = require("script.team.zone_equipe") -- lot UPS-2 : zone de l'équipe (rectangles fusionnés, F470)

local Rv = {}

Rv.PERIOD = 1200          -- 20 s : relevé de la centrale
Rv.NET_PERIOD = 7200      -- 2 min : consommateurs sur îlot, poteaux perdus
Rv.POLE_REOPEN_MAX = 5    -- réouvertures d'un même projet POUR SES POTEAUX (q.poles_reopened ; les reposes de la centrale ont leur plafond : S.MAX_TRIES, S.SITE_LOSSES, S.MAX_RELOC)
Rv.POLE_ENEMY_R = 28      -- jamais de pose de poteau avec un ennemi à cette portée
Rv.CAND_MAX = 40          -- poteaux perdus examinés par cycle
Rv.LOG_EVERY = 5 * 3600   -- une ligne de synthèse par équipe et par 5 min
Rv.LOT_AVOID_R = 16       -- tuiles : rayon écarté autour du lot de la centrale perdue (le lot fait 32 de côté)
-- Lot POULS (7/11, fo-logs\2026-11-07_POULS\CRITERES.md) : le relevé du réseau (net_read) par BANDES de lignes de chunks, sur plusieurs
-- passes du pouls, au lieu de deux recherches sur toute la surface d'un bloc (bp:reseau jusqu'à 224 ms sur la sauvegarde du DC).
-- Lot LOURD (fo-logs\2026-11-07_LOURD\CRITERES.md §1) : 1 ligne au lieu de 2. MESURÉ à 2 lignes sur la sauvegarde du DC (0.6.59, AB-0659) :
-- rv:bande 2,30 ms en moyenne, 8,15 ms au pire, 22 bandes sur 1 026 au-dessus de 5 ms. Le relevé dure deux fois plus de passes.
Rv.BAND = 1               -- lignes de chunks par bande
-- Lot LOURD, point 1 bis (décision du lead, 7/11 ; fo-logs\2026-11-07_LOURD\CRITERES.md §1 bis) : une bande est aussi coupée en LARGEUR,
-- par tranches de Rv.COLS chunks. MESURÉ à une ligne sur toute la largeur (LOURD-ABAB série 2) : rv:bande 7,13 ms au pire sur les lignes
-- denses. math.huge : toute la largeur (le relevé d'avant ce point).
Rv.COLS = 32              -- chunks de large par tranche
Rv.BANDS_PER_PULSE = 1    -- bandes par passe ; math.huge : tout le relevé dans la passe où il commence (l'horaire d'avant)

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
    e.rtick = game.tick -- lot ENERGIE : rouverte à ce tick (le graphe de la coupure compte un poteau déjà en reconstruction)
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
    if q and S.exempts(q.state, q.retry_at) then -- lot COURANT2 : seulement un projet dont le chantier avance (états de pose, ou reprise prévue)
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
  local gnets = Gens.networks(surface, f.force, "generator") -- lot X10-S4 : registre des génératrices
  local out = { islands = 0, uncovered = 0, nets = {}, live = gnets } -- (lot ENERGIE : nets = réseaux des îlots, live = réseaux alimentés)
  Profiler.fstart("ws:rv-net")
  local found = surface.find_entities_filtered({ force = f.force, type = ELEC_TYPES })
  Profiler.fstop("ws:rv-net")
  for _, e in ipairs(found) do
    -- Le réseau d'abord : la quasi-totalité des machines est sur un réseau avec centrale, et le prototype (objet créé à chaque lecture)
    -- ne se lit que pour les autres (revue statique 29/10 : le relevé touchait toutes les machines de la force toutes les 2 min).
    local id = e.electric_network_id
    if not (id and gnets[id]) and e.prototype.electric_energy_source_prototype
      and not in_construction(b, e.position.x, e.position.y) then
      if id then out.islands = out.islands + 1; out.nets[id] = true else out.uncovered = out.uncovered + 1 end
    end
  end
  return out
end

-- Lot POULS : le même relevé par bandes. Une bande = Rv.BAND lignes de chunks sur toute la largeur de la boîte des chunks générés
-- (api.box) ; une entité n'est comptée que dans la bande qui contient sa POSITION (y dans [y0, y1[ : la recherche par zone rend aussi
-- ce qui touche ou chevauche la bande, F96). Générateurs et consommateurs dans la même recherche. Un consommateur dont le réseau n'a pas
-- encore de générateur vu est GARDÉ ; il est jugé à la dernière bande, comme net_read : réseau sans générateur et hors chantier
-- (in_construction lu à la fin, comme net_read le lit au relevé). Monde figé : même résultat que net_read (tests/pouls_test.lua, P2).
-- Revue de la 0.6.59, point 2 : le moteur RENUMÉROTE un réseau qui se coupe ou se joint (en attaque, en plein relevé). Les générateurs et
-- les consommateurs gardés sont donc des ENTITÉS, dont le réseau est relu à la FIN : live et nets sont lus au même instant, celui de la
-- décision (coupure_plan les compare aux poteaux lus au même tick ; P7). Limite : un consommateur écarté pendant les bandes (réseau vivant
-- à sa lecture) n'est pas relu ; une coupure survenue après sa lecture ne le compte qu'au relevé suivant (jamais un faux îlot).
-- État : sv.nr_job (nombres, et listes d'entités gens et cons).
local BAND_TYPES = { "generator" }
for _, t in ipairs(ELEC_TYPES) do BAND_TYPES[#BAND_TYPES + 1] = t end

--- Lot UPS-2 : `rects` (facultatif) = zone de l'équipe (Zone.rects, copiée : nombres seulement, rangée dans l'état) ; une tranche ne cherche
--- que ses intersections avec la zone (Ze.clip). Le nombre de tranches, l'ordre, le coût DÉCLARÉ au jeton (Rv.cout) et la fin du relevé
--- sont inchangés : seul le travail du moteur baisse (les chunks vides de la boîte ne sont plus parcourus).
local function job_new(box, rects)
  local zr = nil
  if rects then
    zr = {}
    for i, r in ipairs(rects) do zr[i] = { x0 = r.x0, y0 = r.y0, x1 = r.x1, y1 = r.y1 } end
  end
  return { y = box.y0, y_end = box.y1 + 1, x0 = box.x0, x1 = box.x1 + 1, x = box.x0, gn = {}, gens = {}, cons = {}, bands = 0, rects = zr }
end

--- Lot UPS-2 : zone de relevé de l'équipe `f`, ou nil (toute la tranche, comme avant). Jamais pour une force où un joueur humain est
--- connecté : ses machines posées à la main, hors de tout plan, restent comptées (F470 ne le fait que pour les poteaux).
function Rv.zone(f, surface, tick)
  local force = game and game.forces and game.forces[f.force]
  if not force or #force.connected_players > 0 then return nil end
  return Zone.rects(f, surface, tick)
end

--- Une bande du relevé ; vrai quand la dernière est faite.
--- Lot LOURD (point 1 bis) : une TRANCHE de Rv.BAND lignes × Rv.COLS chunks, dans l'ordre ligne puis colonne (gauche à droite) ; une
--- entité n'est gardée que dans la tranche qui contient sa position, en y ET en x (intervalles demi-ouverts, F96). Un relevé commencé
--- avant ce point (sauvegarde, sans j.x) reprend sa ligne en cours au début.
local function job_band(f, surface, j)
  local ya, yb = j.y, math.min(j.y + Rv.BAND, j.y_end)
  local xa = j.x or j.x0
  local xb = math.min(xa + Rv.COLS, j.x1)
  local top, bottom, left, right = ya * 32, yb * 32, xa * 32, xb * 32
  local function take(e)
    local p = e.position
    if p.y >= top and p.y < bottom and p.x >= left and p.x < right then
      local id = e.electric_network_id
      if e.type == "generator" then
        if id then j.gn[id] = true end -- (écarte pendant les bandes les consommateurs d'un réseau déjà vu vivant)
        j.gens[#j.gens + 1] = e
      elseif not (id and j.gn[id]) and e.prototype.electric_energy_source_prototype then
        j.cons[#j.cons + 1] = e
      end
    end
  end
  if j.rects then
    -- lot UPS-2 : seulement les intersections de la tranche et de la zone ; une entité vue par deux intersections n'est prise qu'une fois
    local seen = {}
    for _, r in ipairs(Ze.clip(j.rects, { x0 = left, y0 = top, x1 = right, y1 = bottom })) do
      for _, e in ipairs(surface.find_entities_filtered({ area = Ze.area(r), force = f.force, type = BAND_TYPES })) do
        local u = e.unit_number
        if not (u and seen[u]) then
          if u then seen[u] = true end
          take(e)
        end
      end
    end
  else
    for _, e in ipairs(surface.find_entities_filtered({ area = { { left, top }, { right, bottom } }, force = f.force,
      type = BAND_TYPES })) do
      take(e)
    end
  end
  j.bands = j.bands + 1
  if xb >= j.x1 then
    j.x, j.y = j.x0, yb -- (ligne finie : la suivante, depuis la gauche)
  else
    j.x = xb
  end
  return j.y >= j.y_end
end

--- Fin du relevé : la même table que net_read, réseaux RELUS maintenant (générateurs, puis consommateurs gardés ; entité disparue
--- depuis sa bande : plus comptée, comme net_read lu maintenant ne la verrait pas).
local function job_finish(b, j)
  local live = {}
  for _, g in ipairs(j.gens) do
    if g.valid then
      local id = g.electric_network_id
      if id then live[id] = true end
    end
  end
  local out = { islands = 0, uncovered = 0, nets = {}, live = live }
  for _, e in ipairs(j.cons) do
    if e.valid then
      local id = e.electric_network_id
      if not (id and live[id]) then
        local p = e.position
        if not in_construction(b, p.x, p.y) then
          if id then out.islands = out.islands + 1; out.nets[id] = true else out.uncovered = out.uncovered + 1 end
        end
      end
    end
  end
  return out
end

--- Lot LOURD (point 2) : coût DÉCLARÉ au jeton (script/core/lourd.lua) du prochain pas du relevé `j` : les chunks couverts par les
--- Rv.BANDS_PER_PULSE tranches suivantes (même avance que job_band), au plus jusqu'à la fin ; nil (tout le budget) quand tout le relevé se
--- fait à la passe.
function Rv.cout(j)
  if Rv.BANDS_PER_PULSE == math.huge then return nil end
  local y, x, n = j.y, j.x or j.x0, 0
  for _ = 1, Rv.BANDS_PER_PULSE do
    if y >= j.y_end then break end
    local yb, xb = math.min(y + Rv.BAND, j.y_end), math.min(x + Rv.COLS, j.x1)
    n = n + (yb - y) * (xb - x)
    if xb >= j.x1 then x, y = j.x0, yb else x = xb end
  end
  return n
end

--- Avance le relevé en cours de Rv.BANDS_PER_PULSE bandes au plus (jeton du tick pris d'abord : api.jeton, script/team/pouls_jeton.lua,
--- au coût déclaré Rv.cout).
--- Rend la table du relevé quand il est fini, nil sinon.
local function job_step(api, f, surface, sv, tick)
  local j = sv.nr_job
  if api.jeton and not api.jeton.take(tick, (f.key or "player") .. ":rv", api.pulse, Rv.cout(j)) then return nil end
  local P = api.prof
  local done = false
  for _ = 1, Rv.BANDS_PER_PULSE do
    if P then P.fstart("rv:bande") end
    done = job_band(f, surface, j)
    if P then P.fstop("rv:bande") end
    if done then break end
  end
  if not done then return nil end
  sv.nr_job = nil
  if P then P.fstart("rv:fin") end
  local nr = job_finish(f.build, j)
  if P then P.fstop("rv:fin") end
  return nr
end

-- Bancs hors jeu (tests/pouls_test.lua) : le relevé par bandes et le relevé d'un bloc, pour les comparer sur un même monde.
Rv.bandes = { new = job_new, band = job_band, finish = job_finish }
Rv.net_read = net_read

--- Poteaux perdus : { { e, q } } (entité du plan, projet) pour tous les projets finis ou en cours.
local function lost_poles(f, surface, b)
  local out = {}
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and not q.abandoned and (q.poles_reopened or 0) < Rv.POLE_REOPEN_MAX and (q.state == "fini" or q.state == "chantier" or q.state == "raccordement") then
      for _, e in ipairs(q.ents) do
        if e.built and not e.dropped and is_pole(e.name) and not real_of(surface, e, f.force, "electric-pole") then -- lot HYGIENE-PLANS-FINIS : cédée = pas perdue
          out[#out + 1] = { e = e, q = q }
          if #out >= Rv.CAND_MAX then return out end
        end
      end
    end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Lot ENERGIE (2/11) : chemin le plus court et second chemin (règle pure : shared/team/coupure_reseau.lua)
---------------------------------------------------------------------------------------------------
--- Interrupteur D'ESSAI (remote fo-ia1d set_option no_coupure) : le témoin des bancs ; allumé sinon.
function Rv.coupure_off(b) return b.opts ~= nil and b.opts.no_coupure == true end

--- Ennemi à moins de Rv.POLE_ENEMY_R du point (x, y) : sa position, ou nil.
function Rv.foe_near(f, surface, x, y)
  local foe = surface.find_nearest_enemy({ position = { x = x, y = y }, max_distance = Rv.POLE_ENEMY_R, force = f.force })
  if foe and foe.valid then return { x = foe.position.x, y = foe.position.y } end
  return nil
end

--- Décision de la coupure : les candidats perdus `cands` ({ e, q }), la lecture du réseau `nr` (net_read). Rend le plan de K.plan
--- (order = numéros de candidats), la liste des ennemis vus et le nombre de poteaux lus ; nil si rien à décider (règle coupée, pas d'îlot).
local function coupure_plan(f, surface, b, nr, cands)
  if Rv.coupure_off(b) or not nr or not next(nr.nets) then return nil end
  local enemies, seen = {}, {}
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  local poles, reach_of = {}, {}
  local function reach(name)
    local r = reach_of[name]
    if r == nil then
      local proto = game.entity_prototypes[name]
      r = proto and proto.max_wire_distance or 9
      reach_of[name] = r
    end
    return r
  end
  for i, c in ipairs(cands) do
    local foe = Rv.foe_near(f, surface, c.e.x, c.e.y)
    if foe then
      local key = math.floor(foe.x) .. ":" .. math.floor(foe.y)
      if not seen[key] then seen[key] = true; enemies[#enemies + 1] = foe end
    end
    poles[#poles + 1] = { id = i, kind = "lost", x = c.e.x, y = c.e.y, reach = reach(c.e.name) }
    x0, y0, x1, y1 = math.min(x0, c.e.x), math.min(y0, c.e.y), math.max(x1, c.e.x), math.max(y1, c.e.y)
  end
  -- poteaux DÉJÀ rouverts (en reconstruction) : ils comptent comme des poteaux perdus du graphe, pour que le chemin reste continu
  -- pendant la reconstruction (sinon le relevé suivant ne voit plus de chemin et rouvre tout le reste) ; jamais rouverts une seconde fois
  local k = #cands
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    if q and not q.abandoned and q.state ~= "refuse" then
      for _, e in ipairs(q.ents) do
        if e.rtick and not e.built and is_pole(e.name) and k < #cands + Rv.CAND_MAX then
          k = k + 1
          poles[#poles + 1] = { id = k, kind = "lost", open = true, x = e.x, y = e.y, reach = reach(e.name) }
          x0, y0, x1, y1 = math.min(x0, e.x), math.min(y0, e.y), math.max(x1, e.x), math.max(y1, e.y)
        end
      end
    end
  end
  if x0 == math.huge then return nil end
  local m = 35
  for _, p in ipairs(surface.find_entities_filtered({ area = { { x0 - m, y0 - m }, { x1 + m, y1 + m } }, force = f.force, type = "electric-pole" })) do
    local id = p.electric_network_id
    local kind = id and ((nr.live[id] and "live") or (nr.nets[id] and "isl")) or nil
    if kind then
      k = k + 1
      poles[#poles + 1] = { id = k, kind = kind, net = id, x = p.position.x, y = p.position.y, reach = reach(p.name) }
    end
  end
  local n_read = #poles
  poles = Cr.trim(poles, Cr.MAX_NODES)
  return Cr.plan({ poles = poles, enemies = enemies, enemy_r = Rv.POLE_ENEMY_R }), enemies, n_read
end

---------------------------------------------------------------------------------------------------
-- Pas d'une équipe
---------------------------------------------------------------------------------------------------
local function say(f, tick, what)
  log(string.format("[FO-RESEAU] %s : %s a %.1f min", f.key or "player", what, tick / 3600))
end

--- Le relevé du réseau `nr` (net_read, ou la fin d'un relevé par bandes) appliqué à l'état de santé : îlots, demande nominale,
--- poteaux perdus. Inchangé depuis le lot ENERGIE (sorti de Rv.step au lot POULS, pour servir aux deux chemins).
local function apply_net(f, surface, b, sv, nr, api)
  sv.islands, sv.uncovered = nr.islands, nr.uncovered
  sv.demand = nominal_demand(b)
  sv.lost_links = 0
  if nr.islands + nr.uncovered > 0 then
    local P = api and api.prof
    if P then P.fstart("rv:pertes") end
    sv.lost_links = #lost_poles(f, surface, b)
    if P then P.fstop("rv:pertes") end
  end
end

--- La décision « relier » (poteaux perdus rouverts, chemin le plus court du lot ENERGIE) avec le relevé du réseau `nr`, frais. Inchangée
--- depuis le lot ENERGIE (sortie de Rv.step par la revue de la 0.6.59, point 1, pour être jouée à la fin d'un relevé par bandes).
local function do_relier(f, surface, b, sv, nr, why, tick)
  if nr.islands + nr.uncovered == 0 then
    -- le relevé qui a déclenché la décision est périmé : les poteaux posés depuis couvrent tout, rien à faire
    sv.islands, sv.uncovered, sv.lost_links = 0, 0, 0
    return
  end
  -- les poteaux PERDUS (jamais un poteau neuf) : ceux de leurs projets sont rouverts, sauf sous le feu
  local per, n = {}, 0
  local cands = lost_poles(f, surface, b)
  -- lot ENERGIE (2/11) : d'abord le CHEMIN LE PLUS COURT du réseau alimenté vers les îlots (sûr : aucun poteau tenu par un ennemi) ;
  -- s'il n'y en a pas, la règle d'avant (tous les poteaux que personne ne tient)
  local plan, enemies, n_read = coupure_plan(f, surface, b, nr, cands)
  local chosen
  if plan and plan.action == "chemin" then
    chosen = {}
    for _, i in ipairs(plan.order) do chosen[i] = true end
  elseif plan and plan.action == "second" then
    -- aucun chemin sûr, aucun poteau perdu ne relie l'îlot : en reposer d'autres ne sert à rien (et ouvre un chantier de la centrale qui
    -- retient le raccordement, mesuré au banc energie-ilot-ennemi) ; le raccordement bâtit une chaîne neuve
    chosen = {}
  end
  if plan and #plan.second > 0 then sv.second_tick = tick end -- le raccordement (script/team/raccord.lua) ne laisse plus la main à ces poteaux
  for i, c in ipairs(cands) do
    if not chosen or chosen[i] then
      local foe = Rv.foe_near(f, surface, c.e.x, c.e.y)
      if not foe then
        per[c.q.id] = per[c.q.id] or { q = c.q, ents = {} }
        per[c.q.id].ents[#per[c.q.id].ents + 1] = c.e
        n = n + 1
      end
    end
  end
  if plan then
    say(f, tick, string.format("coupure: %s ; %d poteau(x) perdu(s) lu(s), %d ennemi(s) vu(s), %d poteau(x) du graphe, %d rouvert(s) maintenant%s",
      plan.reason ~= "" and plan.reason or plan.action, #cands, #enemies, n_read or 0, n,
      #plan.second > 0 and string.format(" ; %d ilot(s) sans chemin sur : chaine neuve par le raccordement", #plan.second) or ""))
  end
  for _, pid in ipairs(sorted_keys(per)) do
    local q = per[pid].q
    Rv.reopen(q, per[pid].ents, "reseau: poteaux perdus", surface)
    q.poles_reopened = (q.poles_reopened or 0) + 1 -- le plafond des poteaux ne se mêle pas aux reposes de la centrale
  end
  -- un essai qui ne rouvre rien n'est pas un essai : on se tait 5 min (le compte d'essais ne s'use que sur du travail fait)
  if n > 0 then S.applied(sv.st, "relier", tick) else sv.idle_until = tick + 18000 end
  say(f, tick, string.format("reseau: %s ; %d poteau(x) perdu(s) rouvert(s) (les autres : ennemi a moins de %d tuiles)", why, n, Rv.POLE_ENEMY_R))
  sv.net_next = tick + 1200 -- relire vite après la remise en état
end

--- api = { plant = Build.plant } (fourni par build.lua : ce module ne requiert pas build.lua). Lot POULS : api.box (boîte des chunks
--- générés, script/team/boite_chunks.lua), api.jeton (script/team/pouls_jeton.lua), api.prof (profileur, portées fines rv:*) ; sans
--- api.box, le relevé du réseau se fait d'un bloc (bancs hors jeu d'avant ce lot).
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
  local pp, nr
  -- Lot POULS : un relevé du réseau commencé à une passe précédente avance (sous le jeton). Fini, il met à jour l'état du réseau (îlots,
  -- demande, poteaux perdus), si la centrale est là. Revue de la 0.6.59, point 4 (« une électricité coupée est une priorité n° 1 du DC ») :
  -- le relevé ne retient plus la centrale. Sa lecture, ses reposes, le retour d'une relocalisation et la décision gardent leur horloge
  -- (Rv.PERIOD) pendant le relevé ; seul l'état du réseau attend la fin du relevé (une décision prise pendant le relevé lit le précédent).
  if sv.nr_job then
    nr = job_step(api, f, surface, sv, tick)
    if nr then
      -- revue de la 0.6.59, point 1 : une décision « relier » attendait ce relevé frais (lancé par elle, ou pris pendant le relevé) ; elle
      -- est jouée maintenant, sans décider une seconde fois (S.decide compte ses relevés)
      if sv.relier then
        local why = sv.relier
        sv.relier = nil
        return do_relier(f, surface, b, sv, nr, why, tick)
      end
      pp = b.plant and b.projects[b.plant]
      if pp and pp.state ~= "refuse" and pp.state ~= "attente" and pp.state ~= "plan" then apply_net(f, surface, b, sv, nr, api) end
    end
  end
  do
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
    pp = b.plant and b.projects[b.plant]
    if not pp or pp.state == "refuse" or pp.state == "attente" or pp.state == "plan" then return end
    -- consommateurs sur îlot (période longue) ; pas de second relevé tant qu'un relevé est en cours
    if not sv.nr_job and tick >= sv.net_next then
      sv.net_next = tick + Rv.NET_PERIOD
      -- lot POULS : par bandes quand la boîte des chunks est connue (api.box, build.lua) ; d'un bloc sinon (bancs hors jeu sans boîte).
      -- Pas fini à cette passe : la décision de la centrale est prise quand même (point 4), avec l'état du relevé précédent.
      local box = api.box and api.box(surface)
      if box then
        sv.nr_job = job_new(box, Rv.zone(f, surface, tick))
        nr = job_step(api, f, surface, sv, tick)
      else
        nr = net_read(f, surface, b)
      end
      if nr then apply_net(f, surface, b, sv, nr, api) end
    end
  end
  local P = api.prof
  if P then P.fstart("rv:centrale") end
  local inp, lost = plant_read(f, surface, pp)
  if P then P.fstop("rv:centrale") end
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
  sv.healthy = S.healthy(inp) -- lot CHAMP-COURANT : une centrale sans demande qui n'a rien perdu est saine (avant : prod_kw > 0 seul)
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
    -- revue de la 0.6.59, point 1 : sans relevé frais à cette passe (production nulle confirmée, ou îlots d'un relevé ancien), le relevé
    -- se fait PAR BANDES, sous le jeton ; la décision est jouée à sa fin (sv.relier). Sans boîte des chunks (bancs d'avant ce lot) : d'un
    -- bloc, comme avant. Un relevé déjà en cours (décision prise pendant le relevé, point 4) : la décision attend SA fin.
    if not nr and sv.nr_job then
      sv.relier = why
      return
    end
    if not nr then
      local rbox = api.box and api.box(surface)
      if rbox then
        sv.nr_job = job_new(rbox, Rv.zone(f, surface, tick))
        sv.relier = why
        nr = job_step(api, f, surface, sv, tick)
        if not nr then return end
        sv.relier = nil
      else
        nr = net_read(f, surface, b)
      end
    end
    do_relier(f, surface, b, sv, nr, why, tick)
  elseif action == "combustible" then
    say(f, tick, "centrale: " .. why .. " (combustible : pas un probleme de reseau, les bras de la centrale s'en chargent)")
  end
end

return Rv
