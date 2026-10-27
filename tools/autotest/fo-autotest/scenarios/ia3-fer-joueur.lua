--[[
  Lot IA3-f : CAS DU DC (votre équipe, fer hors de vue au départ), 15 min. Lancement :
  « fo-autotest.bat nopause 54000 ia3-fer-joueur <source> » (graine : FO_MAP_SEED). Monde et critère :
  scenarios/ia3f_joueur_common.lua. Témoin « avant le lot » : ia3-fer-joueur-avant (brouillard coupé).
]]
local C = require("scenarios/ia3f_joueur_common")

return {
  description = "IA3-f : cas du DC, votre equipe sans fer en vue explore, trouve et exploite un gisement de fer",
  base = nil,
  check_tick = 53000,

  init = function(ctx) C.setup(ctx, true) end,

  tick = function(ctx, e) C.poll(ctx, e, true) end,

  finish = function(ctx)
    local st = ctx.state()
    local r = C.finish(ctx, true)
    ctx.check(st.seen_chest0 ~= nil and st.seen_site0 == nil, "au depart : le coffre est vu, le gisement de fer NON",
      string.format("coffre %s, fer %s", tostring(st.seen_chest0), tostring(st.seen_site0)))
    ctx.check(st.iron_found ~= nil and st.seen_site ~= nil, "gisement de fer decouvert par les yeux de l'equipe",
      string.format("fer vu au tick %s, secteur du gisement vu au tick %s", tostring(st.iron_found), tostring(st.seen_site)))
    ctx.check((r.deaths or 0) == 0, "aucun eclaireur mort", tostring(r.deaths))
    ctx.check((r.audit_bad or 0) == 0 and (r.audit_ok or 0) >= 1, "aucun avant-poste dans un secteur jamais vu",
      string.format("%s controles, %s hors vue", tostring(r.audit_ok), tostring(r.audit_bad)))
  end,
}
