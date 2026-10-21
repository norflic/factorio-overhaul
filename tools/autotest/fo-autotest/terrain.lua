-- Outils de terrain du mod de test (vitrine, greffons) : zone plate et vide, alimentation invisible.
local Terrain = {}

--- Génère les chunks de la zone, retire les entités (sauf personnages), pose la tuile `tile` et retire le décor.
function Terrain.prepare_area(s, x0, y0, x1, y1, tile)
  for cx = math.floor(x0 / 32), math.floor((x1 - 1) / 32) do
    for cy = math.floor(y0 / 32), math.floor((y1 - 1) / 32) do
      s.request_to_generate_chunks({ x = cx * 32 + 16, y = cy * 32 + 16 }, 0)
    end
  end
  s.force_generate_chunk_requests()
  for _, e in ipairs(s.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
  local tiles = {}
  for x = x0, x1 - 1 do
    for y = y0, y1 - 1 do tiles[#tiles + 1] = { name = tile or "grass-1", position = { x, y } } end
  end
  s.set_tiles(tiles)
  s.destroy_decoratives({ area = { { x0, y0 }, { x1, y1 } } })
end

--- Alimentation INVISIBLE (prototypes de data.lua du mod de test) : poteau de portée 64 (zone 128×128
--- centrée sur (x, y)) et source de 600 GW. Renvoie la source, ou nil si les prototypes manquent.
function Terrain.power(s, x, y, force)
  if not (game.entity_prototypes["fo-autotest-power-pole"] and game.entity_prototypes["fo-autotest-power-source"]) then
    return nil
  end
  s.create_entity({ name = "fo-autotest-power-pole", position = { x, y }, force = force or "player" })
  local src = s.create_entity({ name = "fo-autotest-power-source", position = { x, y }, force = force or "player" })
  if src then
    src.electric_buffer_size = 1e12
    src.power_production = 1e10
    src.energy = 1e12
  end
  return src
end

return Terrain
