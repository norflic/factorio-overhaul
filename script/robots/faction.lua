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
local Ro = require("shared.content.robots")
local Rb = require("shared.ai3.robots")

local Fa = {}

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

--- Candidats du choix pour une force : une fiche par unité du catalogue, `usable` quand la recette du kit est ouverte.
function Fa.candidates(cat, force)
  local out = {}
  for _, kit in ipairs(cat.unite_list or {}) do
    local u = cat.unites[kit]
    local rn = recipe_of(cat, kit)
    local r = rn and force.recipes[rn]
    out[#out + 1] = { item = kit, hp = u.hp, dps = u.dps, range = u.range, min_range = u.min_range, zone = u.zone, points = u.points,
      cost = u.cost, usable = r ~= nil and r.enabled == true }
  end
  return out
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
  local cands = Fa.candidates(cat, force)
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
  if demand then Ml.want(ml, tick, demand.item, demand.rate, "unite") end
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
