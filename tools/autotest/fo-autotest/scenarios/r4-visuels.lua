--[[
  Scénario GREFFÉ « r4-visuels » (lot AMELIO-RESSOURCES, 30/10) : planches de gisements pour le verdict du DC (critères
  D1 à D3), jour et nuit : cristal bleu glacier (K1) sur la plaine, galène (G1) sur l'herbe et sur la terre, lac de saumure
  propre sur le régolithe, comparés aux minerais vanilla voisins. Captures seulement (2 contrôles de pose).
    py -3.9 -B tools/autotest/banc.py --out <archive> --captures --visuel="--no-atlas-cache" --qui amelio-ressources -- 400 r4-visuels <source>
]]

local X0, Y0 = 3600, 3600
local PAS, R = 11, 4
-- Lignes : { sol, gisements } ; les puits (fluide) sont posés seuls, en 3 exemplaires.
local LIGNES = {
  { nom = "plaine", sol = "fo-crystal-flats", ordre = { "iron-ore", "fo-resonance-crystal", "stone" } },
  { nom = "herbe", sol = "grass-1", ordre = { "iron-ore", "fo-galena", "stone" } },
  { nom = "terre", sol = "dirt-4", ordre = { "fo-tungsten-ore", "fo-galena", "coal" } },
  { nom = "crateres", sol = "fo-crater-fields", ordre = { "iron-ore", "fo-ilmenite", "stone" } },
}
local PUITS = { sol = "fo-crater-fields", noms = { "crude-oil", "fo-brine", "fo-brine" } }

local function quantite(d)
  local t = math.min(1, d / (R + 0.5))
  return math.max(30, math.floor(20000 * (1 - t) ^ 2.2 + 40))
end

local function centre(l, i) return X0 + (i - 2) * PAS, Y0 + (l - 1) * PAS end

local function sol(s, cx, cy, r, tile)
  local tiles = {}
  for dx = -r, r do for dy = -r, r do tiles[#tiles + 1] = { name = tile, position = { cx + dx, cy + dy } } end end
  s.set_tiles(tiles) -- les tuiles AVANT les entités (F135)
end

return {
  description = "r4-visuels : planches cristal K1, galene G1, ilmenite I2S, saumure propre (jour et nuit)",
  check_tick = 300,
  shots_delay = 200,

  init = function(ctx)
    local s = ctx.surface()
    ctx.prepare_area(X0 - 30, Y0 - 20, X0 + 30, Y0 + 60, "grass-1")
    for _, e in ipairs(s.find_entities_filtered({ area = { { X0 - 120, Y0 - 120 }, { X0 + 120, Y0 + 160 } }, force = "enemy" })) do e.destroy() end
    local n_ok = 0
    for l, li in ipairs(LIGNES) do
      for i, nom in ipairs(li.ordre) do
        local cx, cy = centre(l, i)
        sol(s, cx, cy, R + 1, li.sol)
        local n = 0
        for dx = -R, R do
          for dy = -R, R do
            local d = math.sqrt(dx * dx + dy * dy)
            if d <= R + 0.5 and s.create_entity({ name = nom, position = { cx + dx + 0.5, cy + dy + 0.5 }, amount = quantite(d) }) then n = n + 1 end
          end
        end
        if n >= 60 then n_ok = n_ok + 1 end
      end
    end
    ctx.check(n_ok == 12, "12 gisements de planche poses (9 x 9, 8 stades)", n_ok)
    local py = Y0 + 4 * PAS + 6
    sol(s, X0, py, 16, PUITS.sol)
    local w = 0
    for i, nom in ipairs(PUITS.noms) do
      if s.create_entity({ name = nom, position = { X0 + (i - 2) * 8, py }, amount = 300000 }) then w = w + 1 end
    end
    ctx.check(w == 3, "puits poses : petrole vanilla et 2 lacs de saumure, sur le regolithe", w)
  end,

  shots = function(ctx, add)
    local opt = { aa = false }
    for l, li in ipairs(LIGNES) do
      local cx, cy = centre(l, 2)
      add("ligne-" .. li.nom .. "-z1-jour", cx + 0.5, cy + 0.5, 1, 0, opt)
      add("ligne-" .. li.nom .. "-z1-nuit", cx + 0.5, cy + 0.5, 1, 0.5, opt)
      add("ligne-" .. li.nom .. "-z2-jour", cx + 0.5, cy + 0.5, 2, 0, opt)
    end
    local py = Y0 + 4 * PAS + 6
    add("saumure-z1-jour", X0, py, 1, 0, opt)
    add("saumure-z2-jour", X0 + 4, py, 2, 0, opt)
    add("saumure-z1-nuit", X0, py, 1, 0.5, opt)
  end,
}
