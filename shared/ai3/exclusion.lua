--[[
  Lot VIDEO-PLAFONDS, partie d (V99, TODO_VIDEO.md : « I've disconnected the combinators so we never actually build the tiles for
  them » : pouvoir EXCLURE un objet de la demande). Règle PURE (aucune API du moteur), testée hors jeu (tests/exclusion_test.lua).
  Lecteur du réglage de carte et journal : script/ai3/exclusion.lua. Réglage : `fo-war-exclusion` (settings/exclusion.lua,
  runtime-global, chaîne, VIDE par défaut : sans objet exclu, la décision est celle d'avant, octet pour octet).

  Une chaîne liste des objets, séparés par des virgules, des points-virgules ou des blancs. Un objet exclu :
    1. n'apparaît dans AUCUN puits (Pf.excluded, agrégat des puits de Ca.decide : puits mesurés, puits ouvert du stock qui dort) ;
    2. n'apparaît dans AUCUNE option (Pf.gate, Ca.options : chaîne, four, pack, foreuse, laboratoire, levier, quel que soit l'ordre) ;
    3. n'a plus de recette choisie (choose_recipe : sa demande ne se propage pas à ses ingrédients, aucun amont inutile) ;
    4. est REFUSÉ PAR ÉCRIT : refus « exclu : <objet> (reglage fo-war-exclusion) » dans la décision, ligne [FO-EXCLU] au journal.
  Les ordres déjà OUVERTS ne sont pas retirés (ils se terminent ; l'exclusion vaut pour les ordres nouveaux).
  Aucun nom du jeu ici (test anti-échelle, tests/iag_test.lua §8). Déterminisme : l'ensemble et la liste sont triés ; aucun hasard.
]]

local Ex = {}

Ex.SETTING = "fo-war-exclusion"
Ex.MAX = 64                       -- objets exclus au plus (au-delà : jetons ignorés, et dits)
Ex.MAX_LEN = 4096                 -- caractères lus au plus
Ex.WHY = "exclu : "               -- début du motif de tout refus d'exclusion (le journal reconnaît ce début)
Ex.EVERY = 10 * 3600              -- ticks : un même refus (équipe, objet) n'est écrit qu'une fois par 10 minutes

--- Analyse la chaîne du réglage. Rend set ({ [objet] = true }), list (objets triés, sans doublon), bad (jetons ignorés, dans
--- l'ordre de lecture : nom invalide, ou au-delà de Ex.MAX). Une chaîne absente, vide ou non textuelle : rien d'exclu.
function Ex.parse(text)
  local set, list, bad = {}, {}, {}
  if type(text) ~= "string" then return set, list, bad end
  if #text > Ex.MAX_LEN then text = text:sub(1, Ex.MAX_LEN) end
  for tok in text:gmatch("[^,;%s]+") do
    if not tok:match("^[%w_%-]+$") then
      bad[#bad + 1] = tok
    elseif not set[tok] then
      if #list >= Ex.MAX then bad[#bad + 1] = tok
      else
        set[tok] = true
        list[#list + 1] = tok
      end
    end
  end
  table.sort(list)
  return set, list, bad
end

--- L'objet est-il exclu ? set nil ou objet nil : non.
function Ex.has(set, item)
  return type(set) == "table" and item ~= nil and set[item] == true
end

--- Motif écrit d'un refus d'exclusion.
function Ex.why(item)
  return Ex.WHY .. tostring(item) .. " (reglage " .. Ex.SETTING .. ")"
end

--- Ce motif est-il un refus d'exclusion ?
function Ex.is_refusal(why)
  return type(why) == "string" and why:sub(1, #Ex.WHY) == Ex.WHY
end

--- Le refus (clé) peut-il être écrit au journal à ce tick ? last = tick de la dernière écriture (nil : jamais).
function Ex.due(last, tick)
  return last == nil or tick - last >= Ex.EVERY or tick < last
end

return Ex
