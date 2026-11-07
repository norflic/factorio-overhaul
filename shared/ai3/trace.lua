--[[
  Lot VIDEO L11 « trace par décision » (docs/VIDEO_AUTOMATISATION.md §6 L11 ; TODO_VIDEO G67, C14 : « set map pins for each tile ») :
  QUOI tracer et QUAND, pour que le DC voie sur la carte ce que l'IA décide. Le runtime (script/ai3/trace_carte.lua) pose et retire.
    - chaque événement (module DÉCIDÉ par la capitalisation, module POSÉ par le plan directeur) donne une ligne de journal ;
    - un événement qui a une position donne aussi une étiquette de carte (icône du produit, texte court : pourquoi, rang) ;
    - au plus Tr.MAX étiquettes par force : la plus ancienne est retirée ; un événement sur une clé déjà tracée remplace son texte
      (le module « décidé » puis « posé » garde UNE étiquette) ; texte borné à Tr.TEXT_MAX octets, coupé sur un caractère entier.
  PUR : aucune API, aucun nom du jeu (anti-échelle de tests/iag_test.lua §8). État sérialisable { seq, list }. Déterminisme : ordre
  d'arrivée (seq), aucun pairs, aucune horloge.
]]

local Tr = {}

Tr.MAX = 12         -- étiquettes par force au plus
Tr.TEXT_MAX = 40    -- octets du texte d'une étiquette au plus
Tr.KINDS = { decide = "decide", pose = "pose" }

function Tr.new() return { seq = 0, list = {} } end

--- Coupe une chaîne UTF-8 à `n` octets au plus, sans couper un caractère (les octets 10xxxxxx continuent un caractère).
function Tr.cut(s, n)
  s = tostring(s or "")
  if #s <= n then return s end
  local k = n
  while k > 0 do
    local b = s:byte(k + 1)
    if not b or b < 0x80 or b >= 0xC0 then break end
    k = k - 1
  end
  return s:sub(1, k)
end

--- Texte d'une étiquette : « R<rang> <pourquoi> » (le rang d'abord : il survit à la coupe).
function Tr.text(ev)
  local r = (type(ev.rank) == "number") and string.format("R%d ", math.floor(ev.rank)) or ""
  local k = (ev.kind == Tr.KINDS.pose) and "pose" or "ordre"
  return Tr.cut(string.format("%s%s %s", r, k, tostring(ev.why or "")), Tr.TEXT_MAX)
end

--- Ligne du journal [FO-TRACE] (toujours, avec ou sans position).
function Tr.line(force, ev, tick)
  local pos = (type(ev.x) == "number" and type(ev.y) == "number") and string.format("(%d, %d)", math.floor(ev.x), math.floor(ev.y))
    or "sans position"
  return string.format("[FO-TRACE] %s : %s %s rang %s, %s, %s a %.1f min", tostring(force), ev.kind == Tr.KINDS.pose and "pose" or "ordre",
    tostring(ev.item), tostring(ev.rank or "-"), tostring(ev.why or "-"), pos, (tick or 0) / 3600)
end

--- Un événement donne-t-il une étiquette ? Il lui faut une clé, un produit et une position.
function Tr.wants_tag(ev)
  return type(ev) == "table" and ev.key ~= nil and ev.item ~= nil and type(ev.x) == "number" and type(ev.y) == "number"
end

--- Note un événement ev = { key, item, x, y, why, rank, kind }. Rend les actions { add = entrée ou nil, remove = { entrées } } : le
--- runtime retire les étiquettes de `remove` (leur marque `placed` dit où elles sont), puis pose `add`. Une clé déjà tracée : son
--- étiquette est retirée et reposée avec le nouveau texte, à la place la plus récente.
function Tr.push(st, ev, tick)
  local acts = { remove = {} }
  if not Tr.wants_tag(ev) then return acts end
  local text = Tr.text(ev)
  local keep = {}
  for _, e in ipairs(st.list) do
    if e.key == ev.key then
      if e.text == text and e.x == ev.x and e.y == ev.y and e.item == ev.item then return acts end -- même étiquette : rien à refaire
      acts.remove[#acts.remove + 1] = e
    else
      keep[#keep + 1] = e
    end
  end
  st.seq = st.seq + 1
  local e = { key = ev.key, item = ev.item, x = ev.x, y = ev.y, text = text, tick = tick or 0, seq = st.seq, placed = {} }
  keep[#keep + 1] = e
  while #keep > Tr.MAX do
    acts.remove[#acts.remove + 1] = table.remove(keep, 1) -- la plus ancienne (ordre d'arrivée)
  end
  st.list = keep
  acts.add = e
  return acts
end

--- Entrées à poser encore sur la force `force` (chunk pas encore cartographié au premier essai), dans l'ordre d'arrivée.
function Tr.pending(st, force)
  local out = {}
  for _, e in ipairs(st.list) do if not e.placed[force] then out[#out + 1] = e end end
  return out
end

return Tr
