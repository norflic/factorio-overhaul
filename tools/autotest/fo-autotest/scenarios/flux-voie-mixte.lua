--[[
  Lot FLUX-VOIE, preuve du melange : meme partie que scenarios/flux-voie.lua (ia1-build plaine, scan des tapis), mais le gisement de
  fer porte des tuiles de CHARBON (1 tuile sur 9, motif regulier : bord de gisement mele). Les foreuses de fer minent tout ce que
  couvre leur zone (regle du moteur) ; le mod ne regarde que les tuiles de fer au placement (shared/team/plan.lua, P.fit :
  `opts.ore`). Attendu SANS correction : du charbon sur la voie du minerai de la fonderie de fer, la voie se bouche, la fonderie
  tourne sous 70 % (ECHEC du controle de base). Attendu AVEC correction : aucune foreuse de fer ne couvre de charbon.
  Lancement : banc.py ... -- 132000 flux-voie-mixte <source>
]]
local base = require("scenarios/flux-voie")
local init0 = base.init
base.description = "FLUX-VOIE-MIXTE : gisement de fer mele de charbon, scan des tapis"
base.init = function(ctx)
  init0(ctx)
  local s = ctx.surface()
  local st = ctx.state()
  local c = st.c or { x = 0, y = 0 }
  local cx, cy, r = c.x + 56, c.y - 28, 10
  local n = 0
  for dy = -r, r do
    for dx = -r, r do
      if dx * dx + dy * dy <= r * r and (dx * 3 + dy * 5) % 9 == 0 then
        local pos = { cx + dx + 0.5, cy + dy + 0.5 }
        for _, e in ipairs(s.find_entities_filtered({ position = pos, type = "resource" })) do e.destroy() end
        if s.create_entity({ name = "coal", position = pos, amount = 3000 }) then n = n + 1 end
      end
    end
  end
  ctx.log("[FO-FLUX-VOIE] gisement de fer mele : " .. n .. " tuile(s) de charbon posees")
  ctx.check(n > 5, "charbon dans le gisement de fer", tostring(n))
end
return base
