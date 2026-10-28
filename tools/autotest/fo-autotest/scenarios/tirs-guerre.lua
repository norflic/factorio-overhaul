-- Scénario greffé du lot TIRS (27/10 ; ronde 4) : la partie du GUIDE (verif-guide, lot VERIF-NUIT) jouée telle quelle,
-- plus le relevé des compteurs du lot toutes les minutes : combien d'événements « tir » la guerre lève (tourelles des
-- factions, de votre équipe, vanilla : `autres`, sans plafond), combien sont habillés. La simulation est celle de
-- verif-guide (le relevé ne fait que LIRE l'interface fo-tirs) : ses contrôles valent ceux de verif-guide (journal
-- [FO-TIRS-GUERRE] au lieu de [FO-VERIF-GUIDE]).
--   banc.py --graine 271828182 --qui TIRS -- 216000 tirs-guerre <source>   (puis --graine 1618033988)

local base = require("scenarios/verif-guide")

local S = {}
for k, v in pairs(base) do S[k] = v end -- copie au chargement (aucun ordre ne compte)

S.description = "TIRS : partie du guide (verif-guide) et compteurs du lot par minute"

local function releve(ctx, tick)
  if not ctx.has("fo-tirs", "stats") then return end
  local s = ctx.remote("fo-tirs", "stats")
  local ev, hab = 0, 0
  for _, a in ipairs(s.ages) do ev, hab = ev + a.evts, hab + a.habilles end
  ctx.log(string.format("RELEVE\ttick=%d\tautres=%d\tevts_ages_temoins=%d\thabilles=%d", tick, s.autres, ev, hab))
end

S.tick = function(ctx, e)
  if base.tick then base.tick(ctx, e) end
  if e.tick > 0 and e.tick % 3600 == 0 then releve(ctx, e.tick) end
end

S.finish = function(ctx)
  if base.finish then base.finish(ctx) end
  releve(ctx, game.tick)
end

return S
