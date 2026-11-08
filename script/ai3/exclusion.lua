--[[
  Lot VIDEO-PLAFONDS, partie d (V99) : EXÉCUTANT du réglage d'exclusion de demande. La règle est pure (shared/ai3/exclusion.lua) ;
  ici : la lecture du réglage de carte `fo-war-exclusion` (settings/exclusion.lua, runtime-global, chaîne VIDE par défaut) et le
  journal [FO-EXCLU]. Lu à chaque décision de la capitalisation (script/ai3/capitalisation.lua, build_input) ; rend nil quand rien
  n'est exclu (l'entrée de la décision n'a alors aucun champ de plus : le global et la décision sont ceux d'avant, octet pour octet).

  Journal [FO-EXCLU] (jamais plus d'une ligne par refus, équipe et 10 minutes : Ex.due) :
    - le réglage lu, à chaque CHANGEMENT : objets exclus, jetons ignorés, objets inconnus du jeu (exclus quand même) ;
    - chaque refus « exclu : » de la décision (option retirée, objet sans recette) ;
    - chaque puits (puits mesuré, besoin d'un but) retiré de la demande parce que son objet est exclu.
  Cache LOCAL au module (la chaîne lue et son analyse), jamais dans global ; le dernier tick écrit de chaque ligne aussi (le journal
  ne décide rien : un rechargement le remet à zéro, au pire une ligne de plus).
]]

local Ex = require("shared.ai3.exclusion")

local X = {}

local cache = { text = nil, set = nil }
local last = {} -- [équipe|ligne] = tick de la dernière écriture

local function unknown_of(list)
  local out = {}
  for _, name in ipairs(list) do
    local known = false
    if game then
      known = (game.item_prototypes and game.item_prototypes[name] ~= nil) or (game.fluid_prototypes and game.fluid_prototypes[name] ~= nil)
    end
    if not known then out[#out + 1] = name end
  end
  return out
end

--- Ensemble des objets exclus ({ [objet] = true }), ou nil quand le réglage est vide ou absent (moteur simulé des tests).
function X.read()
  local ok, text = pcall(function() return settings.global[Ex.SETTING].value end)
  if not ok or type(text) ~= "string" then text = "" end
  if text ~= cache.text then
    local set, list, bad = Ex.parse(text)
    cache.text = text
    cache.set = (#list > 0) and set or nil
    if #list > 0 or #bad > 0 then
      local unk = unknown_of(list)
      log(string.format("[FO-EXCLU] reglage %s : %d objet(s) exclu(s) [%s] ; jetons ignores [%s] ; inconnus du jeu, exclus quand meme [%s]",
        Ex.SETTING, #list, table.concat(list, " "), table.concat(bad, " "), table.concat(unk, " ")))
    end
  end
  return cache.set
end

local function once(key, tick)
  if not Ex.due(last[key], tick) then return false end
  last[key] = tick
  return true
end

--- Journal d'une décision finie. f = équipe, input = entrée de la décision (excl, sinks, need), res = résultat de Ca.decide.
function X.journal(f, input, res, tick, minutes)
  local set = input and input.excl
  if set == nil then return end
  local who = tostring(f.key or "?")
  for _, r in ipairs(res.refus or {}) do
    if Ex.is_refusal(r.why) and once(who .. "|refus|" .. tostring(r.key), tick) then
      log(string.format("[FO-EXCLU] %s : refus %s : %s a %.1f min", who, tostring(r.key), tostring(r.why), minutes))
    end
  end
  local seen = {}
  for _, s in ipairs(input.sinks or {}) do
    if s.item ~= nil and Ex.has(set, s.item) then seen[s.item] = "puits" end
  end
  local need = input.need or {}
  for k in pairs(need) do
    if Ex.has(set, k) and not seen[k] then seen[k] = "besoin d'un but" end
  end
  local items = {}
  for k in pairs(seen) do items[#items + 1] = k end
  table.sort(items)
  for _, k in ipairs(items) do
    if once(who .. "|puits|" .. k, tick) then
      log(string.format("[FO-EXCLU] %s : %s de %s retire de la demande : %s a %.1f min", who, seen[k], k, Ex.why(k), minutes))
    end
  end
end

return X
