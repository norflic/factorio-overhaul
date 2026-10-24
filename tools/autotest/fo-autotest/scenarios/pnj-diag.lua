--[[
  Lot PNJ-VÉRIF (24/10) : DIAGNOSTIC des groupes d'attaque d'une faction (banc `default`, graine 20261020).
  Constat de départ (0.4.11) : Écarlate « attaque » Azur 32 fois de suite entre les ticks 95 401 et 104 701, 27
  soldats à chaque fois, toutes les 300 ticks ; ses soldats étaient restés à 960 tuiles du QG.
  Même carte et même guerre que `default` (base "default") ; le scénario ne fait qu'OBSERVER (aucune écriture) :
  - toutes les 60 ticks, les groupes moteur de la faction FACTION (numéros retenus) ;
  - toutes les 600 ticks (et 2 et 6 ticks après chaque pensée, dans [FIN_DETAIL - 1200, FIN_DETAIL]) : soldats,
    soldats dans un groupe, soldats à moins / à plus de 64 tuiles du QG, et chaque groupe (état, membres,
    position, distance au QG) ;
  - chaque on_ai_command_completed d'un groupe RETENU (tick, numéro, résultat, distraction).
  Lancement : `fo-autotest.bat nopause <ticks> pnj-diag <source>`. Aucun contrôle de réussite : BILAN « 1 OK »
  (le diagnostic a tourné). Journal : [FO-PNJ-DIAG].
]]

local FACTION = "fo-scarlet"
local DEBUT, FIN = 50000, 215000
local FIN_DETAIL = 96400

local GROUP_STATE = {}
for k, v in pairs(defines.group_state) do GROUP_STATE[v] = k end
local RESULT = {}
for k, v in pairs(defines.behavior_result) do RESULT[v] = k end

local function known()
  global.pnj_diag_groups = global.pnj_diag_groups or {}
  return global.pnj_diag_groups
end

script.on_event(defines.events.on_ai_command_completed, function(e)
  if e.tick < DEBUT or e.tick > FIN then return end
  if not known()[e.unit_number] then return end
  log(string.format("[FO-PNJ-DIAG] fin de commande du groupe %d au tick %d : %s, distraction %s",
    e.unit_number, e.tick, tostring(RESULT[e.result] or e.result), tostring(e.was_distracted)))
end)

return {
  description = "PNJ-VERIF : diagnostic des groupes d'attaque d'une faction",
  base = "default",
  check_tick = FIN + 60,

  tick = function(ctx, e)
    if e.tick < DEBUT or e.tick > FIN then return end
    local m = e.tick % 300
    local detail = e.tick % 600 == 0 or (e.tick >= FIN_DETAIL - 1200 and e.tick <= FIN_DETAIL and (m == 2 or m == 6))
    if e.tick % 60 ~= 0 and not detail then return end
    local s = ctx.surface()
    local units = s.find_entities_filtered({ force = FACTION, type = "unit" })
    local groups, order, in_group = {}, {}, 0
    local k = known()
    for _, u in ipairs(units) do
      local g = u.unit_group
      if g and g.valid then
        in_group = in_group + 1
        if not groups[g.group_number] then
          groups[g.group_number] = g
          order[#order + 1] = g.group_number
          k[g.group_number] = true
        end
      end
    end
    if not detail then return end
    table.sort(order)
    local hq
    for _, f in ipairs(ctx.call("points_of_interest").factions) do
      if "fo-" .. f.key == FACTION then hq = f.hq end
    end
    if not hq then return end
    local near, far = 0, 0
    for _, u in ipairs(units) do
      local dx, dy = u.position.x - hq.x, u.position.y - hq.y
      if dx * dx + dy * dy < 64 * 64 then near = near + 1 else far = far + 1 end
    end
    local parts = {}
    for _, n in ipairs(order) do
      local g = groups[n]
      local dx, dy = g.position.x - hq.x, g.position.y - hq.y
      parts[#parts + 1] = string.format("g%d %s m=%d a %d tuiles du QG", n, tostring(GROUP_STATE[g.state] or g.state), #g.members,
        math.floor(math.sqrt(dx * dx + dy * dy)))
    end
    ctx.log(string.format("tick %d | soldats %d (en groupe %d) | pres du QG %d, loin %d | %s", e.tick, #units, in_group, near,
      far, table.concat(parts, " ; ")))
  end,

  finish = function(ctx)
    ctx.ok("diagnostic joue", FACTION .. ", ticks " .. DEBUT .. " a " .. FIN)
  end,
}
