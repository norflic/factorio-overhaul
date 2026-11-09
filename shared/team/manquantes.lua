--[[
  Lot RECHERCHE-BRAS (suite, 8/11) : diagnostic « quelle entité manque ? » d'un chantier qui n'avance plus (le DC et le lead : « la
  centrale 2 à 56 sur 57, l'entité manquante n'est pas nommée au journal »). Règle PURE (aucun moteur) : lit les champs d'une entité de
  projet (name, role, x, y, built, skipped, dropped, ghosted, fails, npc_blocks, why) et rend une phrase, lue par [FO-BLOQUE] (watch_stall)
  et [FO-CHANTIER-LENT] (script/team/chantier_lent.lua). LECTURE SEULE : rien n'est décidé.
]]
local Mq = {}

Mq.MAX = 3 -- entités nommées au plus (les plus refusées d'abord)

--- État d'une entité non posée : « fantome pose » ou « sans fantome », refus, blocages PNJ, dernier motif.
function Mq.state(e)
  local parts = { e.ghosted and "fantome pose" or "sans fantome" }
  if (e.fails or 0) > 0 then parts[#parts + 1] = e.fails .. " refus" end
  if (e.npc_blocks or 0) > 0 then parts[#parts + 1] = e.npc_blocks .. " blocage(s) PNJ" end
  if e.why then parts[#parts + 1] = "dernier motif : " .. tostring(e.why) end
  return table.concat(parts, ", ")
end

--- Entités non posées d'un projet (ni bâties, ni sautées, ni abandonnées), les plus refusées d'abord, puis nom, x, y (ordre total).
function Mq.missing(ents)
  local out = {}
  for _, e in ipairs(ents or {}) do
    if not e.built and not e.skipped and not e.dropped then out[#out + 1] = e end
  end
  table.sort(out, function(a, b)
    local fa, fb = a.fails or 0, b.fails or 0
    if fa ~= fb then return fa > fb end
    if a.name ~= b.name then return tostring(a.name) < tostring(b.name) end
    if a.x ~= b.x then return (a.x or 0) < (b.x or 0) end
    return (a.y or 0) < (b.y or 0)
  end)
  return out
end

--- Phrase « manquantes (N sur T) : nom/role en (x, y) etat ; ... ». nil quand rien ne manque.
function Mq.describe(ents, max)
  local miss = Mq.missing(ents)
  if #miss == 0 then return nil end
  max = max or Mq.MAX
  local items = {}
  for i = 1, math.min(max, #miss) do
    local e = miss[i]
    items[#items + 1] = string.format("%s/%s en (%g, %g) %s", tostring(e.name), tostring(e.role or "?"), e.x or 0, e.y or 0, Mq.state(e))
  end
  local more = #miss > max and string.format(" ; et %d autre(s)", #miss - max) or ""
  return string.format("manquantes (%d sur %d) : %s%s", #miss, #(ents or {}), table.concat(items, " ; "), more)
end

return Mq
