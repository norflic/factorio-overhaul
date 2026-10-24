--[[
  Correction du lot IA1-a : 60 min SANS financement, SANS frein par le travail (fo-recruit-idle-max = 60 : seul
  le stock freine, Q-IA1-2 (2) à la lettre ; comportement du lot avant sa correction).
  Lancement : fo-autotest.bat nopause 216000 ia1-sansfonds-stock <source> (graine : FO_MAP_SEED). Détails,
  lecture : scenarios/ia1_sansfonds_common.lua. Journal : [FO-IA1-SANSFONDS-STOCK].
]]
local C = require("scenarios/ia1_sansfonds_common")

return {
  description = "IA1-a (correction) : 60 min sans financement, sans frein par le travail",
  base = nil,
  check_tick = 215000,
  init = function(ctx) C.init(ctx, 60) end,
  tick = function(ctx, e) C.tick(ctx, e) end,
  finish = function(ctx) C.finish(ctx) end,
}
