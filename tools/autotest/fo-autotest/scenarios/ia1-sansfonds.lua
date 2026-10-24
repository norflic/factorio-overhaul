--[[
  Correction du lot IA1-a : 60 min SANS financement, réglages PAR DÉFAUT du mod (frein par le travail compris).
  Lancement : fo-autotest.bat nopause 216000 ia1-sansfonds <source> (graine : FO_MAP_SEED). Détails, lecture :
  scenarios/ia1_sansfonds_common.lua. Journal : [FO-IA1-SANSFONDS].
]]
local C = require("scenarios/ia1_sansfonds_common")

return {
  description = "IA1-a (correction) : 60 min sans financement, reglages par defaut",
  base = nil,
  check_tick = 215000,
  init = function(ctx) C.init(ctx, nil) end,
  tick = function(ctx, e) C.tick(ctx, e) end,
  finish = function(ctx) C.finish(ctx) end,
}
