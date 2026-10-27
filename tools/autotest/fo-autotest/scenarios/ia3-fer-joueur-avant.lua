--[[
  Lot IA3-f : TÉMOIN « avant le lot » d'ia3-fer-joueur : même monde, brouillard COUPÉ (prospection omnisciente d'avant
  le lot). « fo-autotest.bat nopause 54000 ia3-fer-joueur-avant <source> ». Ligne « MESURE avant joueur ».
]]
local C = require("scenarios/ia3f_joueur_common")

return {
  description = "IA3-f temoin : cas du DC, brouillard coupe (comportement d'avant le lot)",
  base = nil,
  check_tick = 53000,

  init = function(ctx) C.setup(ctx, false) end,

  tick = function(ctx, e) C.poll(ctx, e, false) end,

  finish = function(ctx) C.finish(ctx, false) end,
}
