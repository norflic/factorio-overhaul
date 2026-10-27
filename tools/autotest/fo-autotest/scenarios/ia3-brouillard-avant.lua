--[[
  Lot IA3-f : TÉMOIN « avant le lot » d'ia3-brouillard : même partie (4 factions, Normal, 60 min, même graine), brouillard
  COUPÉ par l'interface « fo-ia3f » (set_fog(false) : prospection sans brouillard, aucun regard, aucun éclaireur, aucun
  minage lointain) ; seules les mesures tournent (dates des avant-postes et du 1er site de fer hors départ). Lancement :
  « fo-autotest.bat nopause 216000 ia3-brouillard-avant <source> ». Les lignes « MESURE avant » se comparent aux lignes
  « MESURE apres » d'ia3-brouillard (2e gisement de fer au plus 5 min plus tard qu'avant le lot).
]]
local C = require("scenarios/ia3f_common")

return {
  description = "IA3-f temoin : meme partie qu'ia3-brouillard, brouillard coupe (comportement d'avant le lot)",
  base = nil,
  check_tick = 214000,

  init = function(ctx) C.start(ctx, false) end,

  tick = function(ctx, e) C.poll(ctx, e, false) end,

  finish = function(ctx)
    C.finish(ctx, false)
    local status = ctx.remote("fo-ia3f", "status")
    ctx.check(status.fog == false and (status.stats.looks or 0) == 0, "brouillard coupe : aucun regard",
      tostring(status.stats.looks))
  end,
}
