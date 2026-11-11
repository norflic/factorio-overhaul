--[[
  Lot OUVRIERS-30 (0.6.95) : exécutant de la migration unique du réglage « Factions : ouvriers au plus » (règle pure :
  shared/ai3/ouvriers_reglage.lua, Ow). À on_configuration_changed d'une partie sauvegardée avant la 0.6.95 : écrit
  settings.global["fo-war-workers"] = { value = défaut } si la valeur stockée est sous le défaut, une ligne
  [FO-OUVRIERS-REGLAGE], puis le drapeau `done` de la partie : plus jamais ensuite.
  État : Storage « ouvriers_reglage » = { done = booléen, tick = nombre ou nil, avant = nombre ou nil, apres = nombre ou nil }.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local Ow = require("shared.ai3.ouvriers_reglage")

local OuvriersReglage = {}
OuvriersReglage.MOD = "factorio-overhaul"

Storage.declare("ouvriers_reglage", function() return { done = false } end)

local function read(name)
  local ok, v = pcall(function() return settings.global[name].value end)
  if ok then return v end
  return nil
end

--- on_configuration_changed : la migration, si elle est due. Rend la valeur écrite, false si rien à écrire, nil si pas due.
function OuvriersReglage.on_config(data)
  local st = Storage.ns("ouvriers_reglage")
  if not st then return nil end
  if not Ow.due(data, OuvriersReglage.MOD, st.done) then return nil end
  local before = read(Ow.NAME)
  local target = Ow.to_set(before)
  local wrote = false
  if target ~= nil then
    -- (pcall, comme script/ai3/video_reglages.lua : une écriture refusée ne doit jamais empêcher la partie de se charger)
    local ok = pcall(function() settings.global[Ow.NAME] = { value = target } end)
    wrote = ok and read(Ow.NAME) == target
  end
  st.done, st.tick, st.avant, st.apres = true, game and game.tick or 0, before, read(Ow.NAME)
  local ch = data.mod_changes[OuvriersReglage.MOD]
  log(string.format("[FO-OUVRIERS-REGLAGE] migration %s -> %s : %s %s -> %s%s ; une seule fois",
    tostring(ch.old_version), tostring(ch.new_version), Ow.NAME, tostring(before), tostring(st.apres),
    target == nil and " (garde : deja au defaut ou plus)" or (wrote and " (remonte au defaut)" or " (ecriture refusee)")))
  return wrote and target or false
end

Events.on_configuration_changed(OuvriersReglage.on_config)

return OuvriersReglage
