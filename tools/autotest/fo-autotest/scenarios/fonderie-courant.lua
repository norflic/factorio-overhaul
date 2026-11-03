--[[
  Lot FONDERIE (3/11, diagnostic d'ENERGIE4 sur lot7bis-20261020) : une bande dont les poteaux ne touchent pas le réseau alimenté.
  Deux cas identiques, à 100 tuiles d'une source (interface d'énergie + poteau) : une rangée de 7 poteaux (la bande) et une colonne de 8 poteaux
  à 18 tuiles d'elle (rien ne les relie), un bras électrique à côté de chaque poteau.
    - « ancien » : raccord 0.6.41, une chaîne depuis le poteau le plus proche de la source seulement ;
    - « regle »  : shared/team/champ_raccord.lua (Ra.connect), toutes les composantes jointes.
  Chaîne droite ici (un poteau toutes les 6,5 tuiles au plus) ; le jeu passe P.pole_chain, contrôlé hors jeu (tests/champ_raccord_test.lua).
  Contrôle à 5 min de jeu (tick 18 000) : bras sans courant. Lancement : banc.py ... -- 18100 fonderie-courant <source>. Journal [FO-FONDERIE-COURANT].
]]
local Ra = require("__factorio-overhaul__/shared/team/champ_raccord")

local R = 7.5
local CASES = { { key = "ancien", ox = 7000, oy = 3000 }, { key = "regle", ox = 7000, oy = 3300 } }

local function straight(a, b)
  local d = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
  local n = math.ceil(d / 6.5) - 1
  local out = {}
  for k = 1, n do
    out[#out + 1] = { x = math.floor(a.x + (b.x - a.x) * k / (n + 1)) + 0.5, y = math.floor(a.y + (b.y - a.y) * k / (n + 1)) + 0.5 }
  end
  return out
end

local function layout(ox, oy)
  local own = {}
  for x = 0, 42, 7 do own[#own + 1] = { x = ox + x + 0.5, y = oy + 0.5 } end
  for y = 30, 72, 6 do own[#own + 1] = { x = ox + 60.5, y = oy + y + 0.5 } end
  return own, { x = ox - 97.5, y = oy + 0.5 }
end

return {
  base = nil,
  check_tick = 18000,

  init = function(ctx)
    local s = ctx.surface()
    local st = ctx.state()
    for _, c in ipairs(CASES) do
      local own, src = layout(c.ox, c.oy)
      s.request_to_generate_chunks({ c.ox, c.oy + 30 }, 5)
    end
    s.force_generate_chunk_requests()
    for _, c in ipairs(CASES) do
      local own, src = layout(c.ox, c.oy)
      -- terrain dégagé : sol herbeux, rien dessus
      local tiles = {}
      for x = c.ox - 110, c.ox + 70 do for y = c.oy - 10, c.oy + 80 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end end
      s.set_tiles(tiles)
      for _, e in ipairs(s.find_entities_filtered({ area = { { c.ox - 110, c.oy - 10 }, { c.ox + 70, c.oy + 80 } } })) do
        if e.valid and e.type ~= "character" then e.destroy() end
      end
      local eei = s.create_entity({ name = "electric-energy-interface", position = { c.ox - 100, c.oy + 1 }, force = "player" })
      eei.power_production = 1e7 / 60
      eei.electric_buffer_size = 1e7
      s.create_entity({ name = "small-electric-pole", position = { src.x, src.y }, force = "player" })
      local arms = {}
      for _, p in ipairs(own) do
        s.create_entity({ name = "small-electric-pole", position = { p.x, p.y }, force = "player" })
        arms[#arms + 1] = s.create_entity({ name = "inserter", position = { p.x + 1, p.y }, direction = defines.direction.north, force = "player" })
      end
      local added
      if c.key == "ancien" then
        local start, sd
        for _, p in ipairs(own) do local d = (p.x - src.x) ^ 2 + (p.y - src.y) ^ 2; if not sd or d < sd then start, sd = p, d end end
        added = straight(start, src)
      else
        local fails
        added, fails = Ra.connect(own, { src }, R, straight)
        ctx.log(string.format("[FO-FONDERIE-COURANT] regle : %d poteau(x) ajoute(s), %d composante(s) en echec", #added, #fails))
      end
      local placed = 0
      for _, p in ipairs(added) do
        if s.create_entity({ name = "small-electric-pole", position = { p.x, p.y }, force = "player" }) then placed = placed + 1 end
      end
      st[c.key] = { arms = arms, added = #added, placed = placed }
      ctx.log(string.format("[FO-FONDERIE-COURANT] %s : %d poteaux de la bande et de la colonne, %d de liaison poses sur %d", c.key, #own, placed, #added))
    end
  end,

  finish = function(ctx)
    local st = ctx.state()
    local S = defines.entity_status
    local res = {}
    for _, c in ipairs(CASES) do
      local r = st[c.key]
      local off, nets = 0, {}
      for _, a in ipairs(r and r.arms or {}) do
        if a.valid then
          if a.status == S.no_power then off = off + 1 end
        end
      end
      res[c.key] = off
      ctx.log(string.format("[FO-FONDERIE-COURANT] %s a 5 min : %d bras sur %d sans courant", c.key, off, #(r and r.arms or {})))
    end
    ctx.check(res.ancien == 8, "defaut reproduit : raccord 0.6.41, les 8 bras de la colonne restent sans courant", tostring(res.ancien))
    ctx.check(res.regle == 0, "regle : 0 bras sans courant a 5 min (toutes les composantes jointes au reseau)", tostring(res.regle))
    ctx.check(st.regle and st.regle.placed == st.regle.added and st.regle.added > 0, "regle : poteaux de liaison tous poses",
      tostring(st.regle and st.regle.placed) .. " / " .. tostring(st.regle and st.regle.added))
  end,
}
