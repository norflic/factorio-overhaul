--[[
  Lot RB-3 CERVEAU (1/11) : les ROBOTS d'une FACTION. Décision pure : shared/ai3/robots.lua (aucun nom d'objet) ; catalogue des unités :
  shared/ai3/catalogue.lua (cat.unites, lu aux prototypes) ; exécution : le balayage des ateliers (script/robots/usine.lua), qui pose
  l'unité du kit, et Military.adopt (script/faction/military.lua), qui en fait un SOLDAT de la faction (garnison, groupes, raids, retour,
  pertes servent sans copie).

  Ce fichier ne fait que RELIER, une fois par période et par faction :
    1. les candidats : les unités du catalogue dont la recette du kit est ouverte pour la force (la technologie est faite) ;
    2. le choix pur (Rb.choose) et la part de robots visée (Rb.want : part du plafond d'armée, moins ce qu'on a) ;
    3. une DEMANDE d'objets par minute au mall d'INDUSTRIE (Ml.want, source « unite ») : c'est le mall qui pose l'atelier (une cellule
       seule en sortie « unite », shared/ai3/industrie.lua) quand la machine et les ingrédients sont utilisables, jamais ce fichier.
  Une faction sans cerveau par besoins (pas de mall) ne demande rien. Réglage maître `fo-war-robots` éteint : rien.
  Ce que ce lot NE fait PAS (dit, pas caché) : il ne pilote pas la recherche de la technologie des robots (une faction qui ne l'a pas
  n'a aucune recette ouverte, donc aucun candidat) ; l'essaim ennemi n'est pas encore lu de l'estimateur de la prévision (la règle de
  zone est écrite et testée, sa donnée d'entrée reste nil) ; la comparaison soldat contre robot n'est pas écrite (un robot COMPLÈTE
  l'armée jusqu'à la part visée, Rb.SHARE).
  Déterminisme : factions dans l'ordre de State.alive(), listes triées, aucun pairs décisionnel ; état = nombres et chaînes.
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local General = require("script.ai3.general")
local Armee = require("script.robots.armee")
local Ml = require("shared.ai3.mall")
local Id = require("shared.ai3.industrie")
local Ro = require("shared.content.robots")
local Mo = require("shared.robots.modele")
local Rb = require("shared.ai3.robots")
local Auto = require("script.ai3.automatisation")
local Ca = require("shared.ai3.capitalisation") -- bancs : regle d obtention sur les vraies donnees (fo-robots-faction.obtenable)

local Fa = {}

Fa.CAUSE_EVERY = 3600 -- au plus une écriture des causes d'attente par minute et par faction
Fa.PERIOD = 1200 -- 20 secondes : une demande vit 10 minutes (Ml.WANT_TTL), elle est renouvelée tant que le besoin dure

--- Recette (nom) qui produit `item`, d'après le catalogue (liste triée : la première) ; nil si aucune.
local recipe_cache = {}
local function recipe_of(cat, item)
  local key = tostring(cat) .. "|" .. item
  if recipe_cache[key] ~= nil then return recipe_cache[key] or nil end
  local found = false
  local names = {}
  for name in next, cat.products do names[#names + 1] = name end -- trié juste après
  table.sort(names)
  for _, name in ipairs(names) do
    for _, p in ipairs(cat.products[name]) do
      if p == item then found = name break end
    end
    if found then break end
  end
  recipe_cache[key] = found
  return found or nil
end

--- Le kit `kit` peut-il encore devenir une unité ? Intégration 0.6.33 (12 robots, 4 usines) : une unité que le balayage des ateliers ne poserait pas (plafond,
--- géants admis à cet âge) ou que le mall a refusée (Chanfrein, Aileron, Lévite : plus de 8 entrées, P.MAX_SOLIDES ; usine inutilisable ; segments du
--- Couronné) est écartée : Rb.choose, qui les préférait au score, gardait sinon pour toujours un choix que personne ne fabrique.
local function kit_ok(force, ml, tick, kit)
  if Ml.refused(ml, tick, kit) then return false end
  local r = Ro.robot_of_kit(kit)
  if not r then return true end -- une unité d'un autre mod n'est pas au registre
  if r.segment_item and Ml.refused(ml, tick, r.segment_item) then return false end
  return Mo.can_release(Armee.release_params(force, r))
end

--- Candidats du choix pour une force : une fiche par unité du catalogue, `usable` quand la recette du kit est ouverte et que le kit peut devenir une unité.
function Fa.candidates(cat, force, ml, tick)
  local out = {}
  for _, kit in ipairs(cat.unite_list or {}) do
    local u = cat.unites[kit]
    local rn = recipe_of(cat, kit)
    local r = rn and force.recipes[rn]
    out[#out + 1] = { item = kit, hp = u.hp, dps = u.dps, range = u.range, min_range = u.min_range, zone = u.zone, points = u.points,
      cost = u.cost, usable = r ~= nil and r.enabled == true and kit_ok(force, ml, tick, kit) }
  end
  return out
end

--- Lot RB-FLUIDE : POURQUOI une faction n'a pas (encore) de robot, un maillon par ligne, de la recherche à l'usine. Aucune décision n'en
--- dépend : le journal [FO-ROBOTS] « attente » le dit, une fois par changement. Chaque kit non fabriqué, du moins cher au plus cher, au plus
--- 3 kits ; les maillons (dans l'ordre de la chaîne demande -> capitalisation -> recherche -> usine -> kit -> unité) :
---   recette   la recette du kit est fermée : la technologie qui l'ouvre, ses prérequis manquants, ses packs non fabricables, sa valeur,
---             son rang, la recherche qui tient le laboratoire ;
---   kit       le kit est refusé (mall) ou n'a plus de place sous le plafond ;
---   module    la demande est notée mais le module n'est pas fini (état, raison, objets manquants) ;
---   atelier   le module est fini mais aucune unité n'est née.
--- Rend une liste de textes.
local function explain(f, force, cat, ml, tick)
  local out = {}
  local kits = {}
  for _, kit in ipairs(cat.unite_list or {}) do kits[#kits + 1] = kit end
  table.sort(kits, function(a, b)
    local ca, cb = cat.unites[a].cost, cat.unites[b].cost
    if ca ~= cb then return ca < cb end
    return a < b
  end)
  local shown = 0
  for _, kit in ipairs(kits) do
    if shown >= 3 then break end
    local rn = recipe_of(cat, kit)
    local r = rn and force.recipes[rn]
    local line
    if not (r and r.enabled) then
      local t = rn and cat.g.unlocked_by[rn]
      local info = t and General.tech_info(f, t)
      if not t then
        line = string.format("%s : recette %s fermee, aucune technologie ne l'ouvre", kit, tostring(rn))
      elseif info and info.done then
        line = string.format("%s : technologie %s faite mais recette %s fermee pour la force", kit, t, tostring(rn))
      elseif info then
        local parts = {}
        if #info.missing > 0 then parts[#parts + 1] = "prerequis manquants " .. table.concat(info.missing, ",") end
        local np = {}
        for _, p in ipairs(info.packs) do if not p[2] then np[#np + 1] = p[1] end end
        if #np > 0 then parts[#parts + 1] = "packs non fabricables " .. table.concat(np, ",") end
        if info.tfeas == false then parts[#parts + 1] = "non payable (graphe)" end
        if #parts == 0 then
          parts[#parts + 1] = string.format("prete et payable, valeur %s, %s", tostring(info.value),
            info.rank == nil and "hors du classement des recherches" or (info.rank == 0 and "en cours" or ("rang " .. info.rank)))
        end
        if info.current and info.current ~= t then parts[#parts + 1] = "laboratoire sur " .. info.current end
        line = string.format("%s : recette fermee, technologie %s pas faite (%s)", kit, t, table.concat(parts, " ; "))
      else
        line = string.format("%s : recette fermee, technologie %s pas faite (etat inconnu)", kit, t)
      end
    elseif not kit_ok(force, ml, tick, kit) then
      local why = f.team and f.team.ia3 and f.team.ia3.industrie and f.team.ia3.industrie.refus and f.team.ia3.industrie.refus[kit]
      line = string.format("%s : kit ecarte (%s)", kit, Ml.refused(ml, tick, kit) and ("refuse par le mall : " .. tostring(why)) or "plafond d'armee")
    else
      local st = f.team and f.team.ia3 and f.team.ia3.industrie
      local blocs = {}
      for _, b in ipairs(st and st.blocs or {}) do
        for _, it in ipairs(b.items or {}) do
          if it == kit then
            local m = Auto.module(f, b.id)
            local miss = {}
            for _, mm in ipairs(m and m.missing or {}) do miss[#miss + 1] = tostring(mm[1]) .. " " .. tostring(mm[2]) end
            blocs[#blocs + 1] = string.format("module %d %s%s%s", b.id, tostring(m and m.state or b.state),
              (m and m.reason) and (" (" .. tostring(m.reason) .. ")") or "", #miss > 0 and (", manque " .. table.concat(miss, ", ")) or "")
          end
        end
      end
      if #blocs > 0 then
        line = string.format("%s : demande notee, %s", kit, table.concat(blocs, " ; "))
      elseif ml.want and ml.want[kit] then
        line = string.format("%s : demande notee, aucun module encore (le mall n'a pas decide)", kit)
      end
    end
    if line then
      out[#out + 1] = line
      shown = shown + 1
    end
  end
  return out
end

--- Lot RB-FLUIDE : la recherche du PREMIER robot. Avant le lot, aucune règle ne voulait la technologie d'un robot (valeur propre 35 : l'atelier et le kit,
--- loin derrière les recherches voulues, 100 à 300) : partie de 4 h, 29 recherches, aucune des robots. Une faction qui n'a AUCUN robot veut le kit le moins
--- cher dont la recette est fermée et dont la technologie est prête (prérequis faits) : un objet voulu (Gen.V_WANTED), comme la tourelle ou ce qu'attend un site de
--- pétrole. Une seule technologie à la fois, jamais une chaîne ; dès qu'un robot existe, le classement ordinaire reprend. Rend { [kit] = vrai } ou nil.
function Fa.wanted(f)
  if f.is_player or not Armee.enabled() then return nil end
  local force = f.force and game.forces[f.force]
  local cat = General.catalogue()
  if not (force and force.valid and cat and cat.unite_list and #cat.unite_list > 0) then return nil end
  if Armee.used(force.name) > 0 then return nil end
  local best
  for _, kit in ipairs(cat.unite_list) do
    local rn = recipe_of(cat, kit)
    local r = rn and force.recipes[rn]
    local t = rn and cat.g.unlocked_by[rn]
    if r and not r.enabled and t then
      local info = General.tech_info(f, t)
      if info and not info.done and info.ready then
        local c = cat.unites[kit].cost
        if best == nil or c < best.cost or (c == best.cost and kit < best.kit) then best = { kit = kit, cost = c } end
      end
    end
  end
  return best and { [best.kit] = true } or nil
end

--- Points de robots vivants de la force, par kit (les robots du mod sont lus au registre ; une unité d'un autre mod n'y est pas).
local function have_points(force, cands)
  local have, total = {}, 0
  for _, c in ipairs(cands) do
    local r = Ro.robot_of_kit(c.item)
    local p = r and Armee.have(force.name, r.id) * r.points or 0
    have[c.item] = p
    total = total + p
  end
  return have, total
end

--- Une faction pense à ses robots. Rend (choix, besoin en points, demande) ou nil.
function Fa.think(f, tick)
  if not Armee.enabled() then return nil end -- réglage maître éteint : aucune demande, par aucun chemin (moteur réel, rb-faction-eteint)
  local s = Armee.S()
  local ia3 = f.team and f.team.ia3
  local ml = ia3 and ia3.mall
  local force = f.force and game.forces[f.force] -- f.force est le NOM de la force
  if not (s and ml and force and force.valid) then return nil end
  local cat = General.catalogue()
  if not (cat and cat.unite_list and #cat.unite_list > 0) then return nil end
  local states = Armee.table_of("faction")
  local st = states[f.id]
  if not st then
    st = {}
    states[f.id] = st
  end
  local cands = Fa.candidates(cat, force, ml, tick)
  -- Lot RB-FLUIDE : une ligne par maillon qui arrête la chaîne, écrite quand l'ensemble change
  local causes = explain(f, force, cat, ml, tick)
  local csig = table.concat(causes, "|")
  if csig ~= st.csig and tick - (st.clog or -Fa.CAUSE_EVERY) >= Fa.CAUSE_EVERY then
    st.csig, st.clog = csig, tick
    for _, c in ipairs(causes) do log(string.format("[FO-ROBOTS] faction %s : attente : %s", tostring(f.key), c)) end
  end
  local have, robots = have_points(force, cands)
  local choice, why = Rb.choose(cands, { have = have, prev = st.prev })
  if not choice then
    st.why = why
    return nil
  end
  st.prev = choice.item
  local cap, used = Armee.cap(force), Armee.used(force.name)
  local want = Rb.want(cap, used, robots)
  local demand = Rb.demand(choice, want)
  local sig = string.format("%s|%d|%d", choice.item, want, demand and demand.units or 0)
  if sig ~= st.sig then
    st.sig = sig
    log(string.format("[FO-ROBOTS] faction %s : choix %s (score %.2f, %d point(s) piece), part visee %d/%d point(s), robots %d, besoin %d point(s) -> %s",
      tostring(f.key), choice.item, choice.score, choice.points, math.floor(cap * Rb.SHARE), cap, robots, want,
      demand and string.format("%d kit(s), %.2f/min", demand.units, demand.rate) or "rien a demander"))
  end
  if demand then
    Ml.want(ml, tick, demand.item, demand.rate, "unite")
    -- Intégration 0.6.33 : les segments d'un géant : aucune main ne les fabrique et personne d'autre ne les demande. Source « refus » : une cellule, jamais une
    -- rangée, que la règle du choix laisserait à la capitalisation (qui ne les connaît pas).
    local rb = Ro.robot_of_kit(demand.item)
    if rb and rb.segment_item then Ml.want(ml, tick, rb.segment_item, demand.rate * Ro.SEGMENTS, Id.SRC_REFUS) end
  end
  return choice, want, demand
end

local function sweep(e)
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and not f.is_player then Fa.think(f, e.tick) end
  end
end

Events.on_nth_tick(Fa.PERIOD, sweep)

-- Interface distante « fo-robots-faction » (bancs) : lecture de ce que la faction a décidé.
remote.add_interface("fo-robots-faction", {
  --- BANC SEULEMENT (lot RB-FLUIDE) : la règle d'obtention de la capitalisation sur les VRAIES données du jeu (relevé des prototypes), toutes
  --- les machines exécutantes, toutes les catégories présentes, seules les ressources de `known` (liste de noms) connues, rien au stock.
  --- Rend { [objet] = vrai | faux } pour chaque objet de `items`.
  obtenable = function(items, known, closed_techs)
    local dump = General.dump()
    local D = Ca.data(dump, { exec_roles = { main = true } })
    local present, kn = {}, {}
    for _, m in ipairs(D.makers) do for _, c in ipairs(m.cat_list) do present[c] = true end end
    for c in next, D.hand do present[c] = true end
    for _, k in ipairs(known or {}) do kn[k] = true end
    local techs = {}
    if not closed_techs then
      for t in next, dump.techs do techs[t] = true end -- toutes les technologies faites
    end
    local ctx = { D = D, input = {}, obt = {}, stock = {}, techs = techs, known = kn, cats_present = present }
    local out = {}
    for _, it in ipairs(items or {}) do out[it] = Ca.obtainable(ctx, it) end
    return out
  end,
  --- Une pensée tout de suite pour la faction `key` au tick `tick` : { item, want, units, rate } ou nil.
  think = function(key, tick)
    for _, id in ipairs(State.alive()) do
      local f = State.faction(id)
      if f and f.key == key then
        local choice, want, demand = Fa.think(f, tick or 0)
        if not choice then return nil end
        return { item = choice.item, want = want, units = demand and demand.units or 0, rate = demand and demand.rate or 0 }
      end
    end
    return nil
  end,
  --- Faction `key` : { workshops, robots, soldiers, garrison, mall = demande notée } (bancs).
  view = function(key)
    local s = Armee.S()
    for _, id in ipairs(State.alive()) do
      local f = State.faction(id)
      if f and f.key == key and s then
        local n = 0
        for _, un in ipairs(s.list) do
          local rec = s.factories[un]
          if rec and rec.e and rec.e.valid and rec.e.force.name == f.force then n = n + 1 end
        end
        local ml = f.team and f.team.ia3 and f.team.ia3.mall
        local want = {}
        local names = {}
        for k in next, (ml and ml.want or {}) do names[#names + 1] = k end -- trié juste après
        table.sort(names)
        for _, k in ipairs(names) do want[#want + 1] = { item = k, rate = ml.want[k].rate, src = ml.want[k].src } end
        return { force = f.force, workshops = n, robots = Armee.used(f.force), by_unit = f.soldiers_count,
          garrison = f.garrison_count, want = want, age = Armee.age(game.forces[f.force]) }
      end
    end
    return nil
  end,
})

return Fa
