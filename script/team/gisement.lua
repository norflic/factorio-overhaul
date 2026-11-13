--[[
  Lot GISEMENTS (retour du DC du 31/10, 0.6.27) : « les foreuses thermiques occupent encore une partie des gisements et elles ne
  fonctionnent pas », « les fours sur le gisement prennent de l'espace ». Règle pure : shared/team/gisement.lua (G.verdict).

  Tâche de FOND bornée (au plus Gis.PER_PASS actions toutes les Gis.EVERY ticks par équipe) sur les foreuses à combustion des
  avant-postes (f.outposts[*].drill_list) :
    - une foreuse À L'ARRÊT depuis G.IDLE (statut autre que « travaille ») est jugée (lot DECOUPLAGE : plus de « rebrancher », aucun
      four reposé au dépôt d'une foreuse) : « ravitailler » (sans combustible, matière en manque ou électrique impossible),
      « remplacer » (Swap.think s'en charge, remplacement électrique prêt : on attend G.HARD), « retirer » (arrêt de G.RETIRE quand
      l'électrique peut prendre la place, matière non en manque ; ou minerai épuisé sous elle) ;
    - retirer = objets REPRIS au stock (foreuse, combustible, four et son contenu), jamais détruits ; l'avant-poste n'est plus plein
      (la place libérée sert aux foreuses électriques de la capitalisation) et plus aucune paire à four n'est reposée sur le minerai
      (G.forbid_pairs, lu par Outposts.extend, script/faction/outposts.lua).
  Journal [FO-GISEMENT]. Déterminisme : listes triées, aucun temps mesuré (ticks du jeu). État : f.gisement (tables simples).
]]

local T = require("shared.team.config")
local G = require("shared.team.gisement")
local S = require("shared.team.foreuse_swap")
local State = require("script.faction.state")
local Stock = require("script.team.stock")
local Profiler = require("script.core.profiler") -- lot UPS : portées fines « ws: » (recherches sur toute la surface ; mesure seulement)
local El = require("shared.team.elagage") -- lot P1-ELAGAGE : foreuses sans ressource sous leur zone démontées

local Gis = {}

Gis.EVERY = 1800     -- 30 s entre deux passes
Gis.PER_PASS = 4     -- actions au plus par passe
Gis.LOGS = 40        -- lignes de journal au plus par équipe

local function sorted_keys(t) return State.sorted_keys(t or {}) end

local function box_of(e)
  local p = e.prototype
  return { x = e.position.x, y = e.position.y, w = p.tile_width or 1, h = p.tile_height or 1 }
end

local function say(f, st, text, tick)
  st.logs = (st.logs or 0) + 1
  if st.logs <= Gis.LOGS then
    log(string.format("[FO-GISEMENT] %s : %s a %.1f min", f.key or "player", text, (tick - (f.started or 0)) / 3600))
  end
end

local function state_of(f)
  local st = f.gisement
  if not st then
    st = { next = 0, retired = 0, idle = {}, logs = 0 }
    f.gisement = st
  end
  return st
end

--- Reprend un objet entier au stock de l'équipe : l'entité, son combustible et son contenu.
local function take_back(f, e, item)
  if not (e and e.valid) then return end
  for _, inv_id in ipairs({ defines.inventory.fuel, defines.inventory.furnace_source, defines.inventory.furnace_result,
      defines.inventory.furnace_modules }) do
    local inv = e.get_inventory(inv_id)
    if inv then
      local c = inv.get_contents()
      for _, name in ipairs(sorted_keys(c)) do Stock.insert(f, name, c[name]) end
      inv.clear()
    end
  end
  State.disown(e.unit_number)
  e.destroy()
  if item then Stock.insert(f, item, 1) end
end

--- L'électrique peut-il prendre la place ? Objet obtenable (book : livre de l'équipe) et centrale en bonne santé.
local function electric_possible(f, book)
  if not (f.build and f.build.sante and f.build.sante.healthy == true) then return false end
  if Stock.count(f, T.DRILL_ELECTRIC) > 0 then return true end
  return book ~= nil and book:handcraftable(T.DRILL_ELECTRIC)
end

--- Sa matière manque-t-elle par rapport au besoin (écrit par la pensée, shared/ai3/cerveau.lua) ?
local function starved_of(f, spec)
  local sv = spec and f.team and f.team.ia3 and f.team.ia3.starved
  return sv and (sv[spec.product] == true or sv[spec.resource] == true) or false
end

--- Lot GISEMENTS : plus de paire foreuse + four sur CE champ ? (lu par Outposts.extend ; règle pure : G.forbid_pairs)
function Gis.pairs_forbidden(f, o, spec)
  local sp = spec and game.entity_prototypes[spec.sink]
  local here = 0
  for _, d in ipairs(o.drill_list or {}) do
    if d.valid and d.name == T.DRILL_ELECTRIC then here = here + 1 end
  end
  return G.forbid_pairs({ sink_furnace = sp ~= nil and sp.type == "furnace", swap_done = here, swap_ready = f.swap and f.swap.ready,
    retired = o.retired, starved = starved_of(f, spec) })
end

--- Combustible du stock dans une machine, jusqu'à T.fuel_refill_to. Rend le nombre posé.
local function refuel(f, e)
  local inv = e and e.valid and e.get_fuel_inventory and e.get_fuel_inventory()
  if not inv then return 0 end
  local want = T.fuel_refill_to - inv.get_item_count(T.fuel)
  if want <= 0 then return 0 end
  local took = math.min(want, Stock.count(f, T.fuel))
  if took <= 0 or Stock.remove(f, T.fuel, took) < 1 then return 0 end
  return inv.insert({ name = T.fuel, count = took })
end

--- Une passe : rend le nombre d'actions faites. book : livre de l'équipe (l'électrique est-il obtenable ?).
function Gis.think(f, surface, tick, book)
  if not (f and f.outposts and next(f.outposts)) then return 0 end
  local st = state_of(f)
  if tick < st.next then return 0 end
  st.next = tick + Gis.EVERY
  local seen, actions = {}, 0
  local ready = (f.swap and f.swap.ready or 0) > 0
  local elec = electric_possible(f, book)
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    local spec = T.outposts[o.kind]
    -- un champ en migration est géré par la migration ; sans réceptacle de four, l'arrêt d'une foreuse (coffre plein) n'est pas jugé ici
    local sink_proto = spec and game.entity_prototypes[spec.sink]
    local on_furnace = sink_proto and sink_proto.type == "furnace"
    local starved = starved_of(f, spec)
    -- matière redevenue en manque (ou électriques partis) : le champ se rouvre aux paires (DC : « au minimum les foreuses thermiques »)
    if o.full and o.full_why == "electrique" and not Gis.pairs_forbidden(f, o, spec) then
      o.full, o.full_by, o.full_why = false, nil, nil
    end
    if o.migr ~= "en cours" and o.drill_list then
      local keep, removed = {}, 0
      for index, d in ipairs(o.drill_list) do
        local kept = true
        if d.valid and d.name == T.DRILL and d.unit_number then
          local u = d.unit_number
          local s = d.status
          local working = (s == defines.entity_status.working) or (s == defines.entity_status.normal)
          local first = st.idle[u] or tick
          if not working then seen[u] = first end
          local idle = working and 0 or (tick - first)
          if actions < Gis.PER_PASS and idle >= G.IDLE and (on_furnace or s == defines.entity_status.no_minable_resources) then
            local pos = d.position
            local rx, ry = S.rotate(d.direction, T.drill_drop[1], T.drill_drop[2])
            local sink
            for _, sk in ipairs(o.sinks or {}) do
              if sk.valid and S.inside(box_of(sk), pos.x + rx, pos.y + ry) then sink = sk break end
            end
            local no_fuel = (s == defines.entity_status.no_fuel) or (sink ~= nil and sink.status == defines.entity_status.no_fuel)
            local verdict, why = G.verdict({ idle = idle, dead = (s == defines.entity_status.no_minable_resources),
              sink = sink and "ok" or "manque", ready = ready,
              elec = elec, starved = starved, no_fuel = no_fuel, can_fuel = Stock.count(f, T.fuel) > 0 })
            if verdict == "ravitailler" then
              local put = refuel(f, d) + refuel(f, sink)
              if put > 0 then
                st.refueled = (st.refueled or 0) + 1
                st.idle[u] = nil
                seen[u] = nil
                actions = actions + 1
                say(f, st, string.format("foreuse a combustion en (%.1f, %.1f) remise en marche, %d combustible(s) (%s)", pos.x, pos.y, put, why), tick)
              end
            elseif verdict == "retirer" then
              take_back(f, d, T.DRILL)
              if sink and sink.valid then take_back(f, sink, spec.sink) end
              st.retired = st.retired + 1
              o.retired = (o.retired or 0) + 1
              actions = actions + 1
              removed = removed + 1
              kept = false
              seen[u] = nil
              o.full, o.full_by, o.full_why = nil, nil, nil -- la place libérée sert aux foreuses électriques de la capitalisation
              -- lot RACCORD-BANDE : le risque vu au diagnostic d'aa17f16c (retrait sur « électrique possible » sans électrique qui tourne) au journal
              local el_here, el_run = 0, 0
              for _, q in ipairs(o.drill_list) do
                if q.valid and q.name == T.DRILL_ELECTRIC then
                  el_here = el_here + 1
                  if q.status == defines.entity_status.working then el_run = el_run + 1 end
                end
              end
              say(f, st, string.format("foreuse a combustion retiree en (%.1f, %.1f) : %s (arret %.1f min, avant-poste %d, %d retiree(s) ; electriques sur cet avant-poste : %d posee(s), %d qui tourne(nt)%s)",
                pos.x, pos.y, why, idle / 3600, o.id, st.retired, el_here, el_run, el_run == 0 and " : AUCUNE ne remplace la foreuse retiree" or ""), tick)
            end
          end
        end
        if kept then keep[#keep + 1] = d end
      end
      if removed > 0 then
        o.drill_list = keep
        o.drills = math.max(0, (o.drills or #keep + removed) - removed)
      end
    end
  end
  st.idle = seen
  return actions
end

--- Lot P1-ELAGAGE : ronde découpée (shared/team/elagage.lua) sur TOUTES les foreuses de l'équipe ; une foreuse dont la zone de
--- minage ne porte plus aucune ressource est démontée, son objet (celui du prototype) et son contenu rendus au stock.
function Gis.prune(f, surface, tick)
  if not (f and f.force and surface and surface.valid) then return 0 end
  f.elagage = f.elagage or {}
  return El.step(f.elagage, tick, {
    list = function()
      Profiler.fstart("ws:elagage")
      local l = surface.find_entities_filtered({ type = "mining-drill", force = f.force })
      Profiler.fstop("ws:elagage")
      table.sort(l, function(a, b) return (a.unit_number or 0) < (b.unit_number or 0) end)
      return l
    end,
    valid = function(d) return d and d.valid end,
    left = function(d)
      local r = d.prototype.mining_drill_radius or 0
      local p = d.position
      return surface.count_entities_filtered({ type = "resource",
        area = { { p.x - r, p.y - r }, { p.x + r, p.y + r } } })
    end,
    retire = function(d)
      local its = d.prototype.items_to_place_this
      local item = its and its[1] and its[1].name
      local pos = d.position
      take_back(f, d, item)
      log(string.format("[FO-ELAGAGE] %s : foreuse sans ressource demontee en (%.1f, %.1f), objet %s rendu au stock",
        f.key or "player", pos.x, pos.y, tostring(item)))
    end,
  })
end

return Gis
