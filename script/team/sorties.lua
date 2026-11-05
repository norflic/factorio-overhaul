--[[
  Lot CHARBON-MAIN : lecture des SORTIES des avant-postes bruts (produit = ressource : coffres de charbon, de pierre) pour le minage à la main.
  Règle pure : shared/team/sorties_main.lua. Lecture seule (aucune écriture d'état hors f.stats.sorties, compteurs du journal).
  Appelé par script/team/worker.lua au programme d'un minage à la main (rare : une fois par prise de tâche), jamais à on_load.
]]
local T = require("shared.team.config")
local Sm = require("shared.team.sorties_main")
local State = require("script.faction.state")
local Poles = require("script.team.poles")
local Board = require("script.team.board")

local S = {}

--- Lot ETAGE4 : état de la tournée de l'avant-poste `oid` au tableau : "prise" | "libre" | nil (absente ou en pause), attente sans preneur,
--- ticks sans progrès du PNJ qui la tient (relevé t.prog du bail, script/team/bail.lua ; à défaut, depuis la prise), ticks depuis la prise
--- (ou depuis le dernier abandon du bail, t.lease_t).
function S.tour(f, oid, tick)
  local t = Board.get(f).tasks["service:" .. tostring(oid)]
  if not t then return nil, nil, nil, nil, nil end
  if t.worker then
    return "prise", nil, tick - ((t.prog and t.prog.t) or t.claimed or tick), tick - (t.lease_t or t.claimed or tick), t.pre_act ~= false
  end
  return "libre", tick - (t.created or tick), nil, nil, nil
end

local RAW = Sm.raw_kinds(T.outposts)

--- Rangées { id, kind, outputs = { [item] = n }, lethal, unsafe, fails, tour, free_age, stall } des avant-postes bruts de ressource `item` dont les coffres de
--- sortie en ont (ordre des ids ; le danger n'est relevé que pour ceux-là).
function S.rows(f, item, tick)
  local rows = {}
  local surface = f.hq and f.hq.valid and f.hq.surface
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    if RAW[o.kind] == item then
      local n = 0
      for _, s in ipairs(o.sinks or {}) do
        if s.valid and s.type == "container" then n = n + s.get_inventory(defines.inventory.chest).get_item_count(item) end
      end
      if n > 0 then
        local pos = o.access or o.pos
        local unsafe = surface and pos and (surface.count_entities_filtered({ position = pos, radius = Poles.DANGER_RADIUS, force = "enemy",
          type = { "unit-spawner", "turret" }, limit = 1 }) > 0 or (f.is_player and Poles.near_loss(f, pos, tick))) or nil
        local tour, free_age, stall, held, pre_act = S.tour(f, oid, tick)
        rows[#rows + 1] = { id = oid, kind = o.kind, outputs = { [item] = n }, fails = o.flux_fails, unsafe = unsafe,
          tour = tour, free_age = free_age, stall = stall, held = held, pre_act = pre_act,
          lethal = (o.lethal_tick ~= nil and tick - o.lethal_tick < T.lethal_ticks) or nil }
      end
    end
  end
  return rows
end

S.EVERY = 5 * 3600 -- ticks entre deux lignes [FO-SEC]
S.SHOW = 6         -- avant-postes détaillés au plus par ligne

--- Journal [FO-SEC] (LECTURE SEULE, toutes les 5 min par équipe) : avant-postes dont des brûleurs sont À SEC, et l'état de leur tournée au
--- tableau : « prise » (un PNJ l'a, depuis n s), « libre » (au tableau sans preneur, depuis n s), « pause » (échec récent : n s de pause),
--- « absente » (jamais planifiée : le planificateur ne l'a pas posée). Avec les drapeaux du planificateur (meurtrier, dangereux, ratées
--- de suite) et le contenu des sorties. Appelé par script/team/team.lua après le plan. État : f.team.sec_t (tick de la dernière ligne).
function S.report(f, view, tick)
  local team = f.team
  if not team then return end
  if team.sec_t and tick - team.sec_t < S.EVERY then return end
  team.sec_t = tick
  local b = Board.get(f)
  local n_out, n_dry, n_bur, states, shown = 0, 0, 0, {}, {}
  for _, o in ipairs(view.outposts or {}) do
    if (o.dry or 0) > 0 then
      n_out, n_dry, n_bur = n_out + 1, n_dry + (o.dry or 0), n_bur + (o.burners or 0)
      local key = "service:" .. tostring(o.id)
      local t = b.tasks[key]
      local cd = b.cooldown[key]
      local st
      if t and t.worker then st = string.format("prise %ds p%d sans progres %ds", math.floor((tick - (t.claimed or tick)) / 60), t.prio or 0,
        math.floor((tick - ((t.prog and t.prog.t) or t.claimed or tick)) / 60))
      elseif t then st = string.format("libre %ds p%d", math.floor((tick - (t.created or tick)) / 60), t.prio or 0)
      elseif cd and tick < cd then st = string.format("pause %ds", math.floor((cd - tick) / 60))
      else st = "absente" end
      local word = st:match("^(%a+)")
      states[word] = (states[word] or 0) + 1
      if #shown < S.SHOW then
        local outs = {}
        for _, k in ipairs(State.sorted_keys(o.outputs or {})) do outs[#outs + 1] = k .. "=" .. o.outputs[k] end
        shown[#shown + 1] = string.format("%s:%s sec %d/%d [%s] %s%s%s%s fuel_low=%s d=%d", tostring(o.id), tostring(o.kind), o.dry or 0, o.burners or 0,
          table.concat(outs, ","), st, o.lethal and " meurtrier" or "", o.unsafe and " dangereux" or "",
          (o.fails or 0) > 0 and (" ratees=" .. o.fails) or "", tostring(o.fuel_low), math.floor(math.sqrt(o.d2 or 0)))
      end
    end
  end
  local parts = {}
  for _, k in ipairs(State.sorted_keys(states)) do parts[#parts + 1] = k .. " " .. states[k] end
  log(string.format("[FO-SEC] %s a %.1f min : %d avant-poste(s) avec des bruleurs a sec (%d sur %d) ; tournees {%s} ; refus du minage a la main (sorties) %d ; %s",
    f.key or "player", tick / 3600, n_out, n_dry, n_bur, table.concat(parts, ", "), (f.stats and f.stats.main_sorties) or 0, table.concat(shown, " | ")))
end

--- La règle est-elle allumée pour cette équipe ?
function S.on(f) return f.team ~= nil and Sm.on(f.team.sorties_regle) end

--- Combustible à porter du coffre vers l'avant-poste `o` dont les brûleurs manquent de `need` (Sm.carry_fuel).
function S.carry_fuel(f, o, need)
  local spec = T.outposts[o.kind]
  local self_fuel = spec ~= nil and spec.product == T.fuel
  local own = 0
  if self_fuel then
    for _, s in ipairs(o.sinks or {}) do
      if s.valid and s.type == "container" then own = own + s.get_inventory(defines.inventory.chest).get_item_count(T.fuel) end
    end
  end
  return Sm.carry_fuel(need, self_fuel, own)
end

--- Minage à la main de `item` : ok, raison, objets dans les sorties comptées, et l'état des tournées des avant-postes garnis (journal, lot
--- ETAGE4 : « 1:prise 40s », « 3:absente »...). Règle coupée (f.team.sorties_regle == false) : toujours ok.
function S.hand_ok(f, item, tick, crisis)
  if not (f.team and Sm.on(f.team.sorties_regle)) then return true, "coupee", 0, "" end
  local rows = S.rows(f, item, tick)
  local total = Sm.dormant(rows, RAW, item)
  local ok, why = Sm.hand_ok({ dormant = total, crisis = crisis })
  local parts = {}
  for _, r in ipairs(rows) do
    parts[#parts + 1] = string.format("%s:%s%s", tostring(r.id), r.tour or "absente",
      r.tour == "prise" and string.format(" sans progres %ds tenue %ds", math.floor((r.stall or 0) / 60), math.floor((r.held or 0) / 60))
      or (r.tour == "libre" and string.format(" %ds", math.floor((r.free_age or 0) / 60)) or ""))
  end
  return ok, why, total, table.concat(parts, ",")
end

return S
