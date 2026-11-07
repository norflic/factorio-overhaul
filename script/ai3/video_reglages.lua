--[[
  Lot VIDEO (0.6.61) : exécutant de la migration unique des réglages de la vidéo (règle pure : shared/ai3/video_reglages.lua, Vr).
  À on_configuration_changed d'une partie sauvegardée avant la 0.6.61 : écrit settings.global[nom] = { value = true } pour chacun
  des quatre réglages de carte de la vidéo qui ne vaut pas vrai (LuaSettings.global : réglages runtime-global modifiables par
  script), une ligne [FO-VIDEO-REGLAGES], puis le drapeau `done` de la partie : plus jamais ensuite (un réglage éteint plus tard
  par le DC est respecté).
  État : Storage « video_reglages » = { done = booléen, tick = nombre ou nil, set = { noms } } (sérialisable, aucune fonction).
  Une partie neuve (on_init) prend les défauts du jeu, déjà vrais : le drapeau reste faux, mais la migration n'y est jamais due
  (sa version précédente ne sera jamais antérieure à la 0.6.61).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local Vr = require("shared.ai3.video_reglages")

local VideoReglages = {}
VideoReglages.MOD = "factorio-overhaul"

Storage.declare("video_reglages", function() return { done = false } end)

local function read(name)
  local ok, v = pcall(function() return settings.global[name].value end)
  if ok then return v end
  return nil
end

--- on_configuration_changed : la migration, si elle est due. Rend la liste des réglages écrits (vide si rien), ou nil (pas due).
function VideoReglages.on_config(data)
  local st = Storage.ns("video_reglages")
  if not st then return nil end
  if not Vr.due(data, VideoReglages.MOD, st.done) then return nil end
  local names, failed, already, absent = {}, {}, 0, 0
  for _, name in ipairs(Vr.NAMES) do
    local v = read(name)
    if v == true then already = already + 1 elseif v == nil then absent = absent + 1 end
  end
  for _, name in ipairs(Vr.to_set(read)) do
    -- (pcall, comme script/ai3/petrole.lua:52 : une écriture refusée ne doit jamais empêcher la partie de se charger)
    local ok = pcall(function() settings.global[name] = { value = true } end)
    if ok and read(name) == true then names[#names + 1] = name else failed[#failed + 1] = name end
  end
  st.done, st.tick, st.set = true, game and game.tick or 0, names
  local ch = data.mod_changes[VideoReglages.MOD]
  log(string.format("[FO-VIDEO-REGLAGES] migration %s -> %s : %d reglage(s) de la video allume(s) [%s] ; deja vrai(s) : %d ; absent(s) : %d ; refuse(s) : %d [%s] ; une seule fois",
    tostring(ch.old_version), tostring(ch.new_version), #names, table.concat(names, ", "), already, absent, #failed,
    table.concat(failed, ", ")))
  return names
end

Events.on_configuration_changed(VideoReglages.on_config)

return VideoReglages
