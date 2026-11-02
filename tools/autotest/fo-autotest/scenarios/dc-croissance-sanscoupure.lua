-- Lot ENERGIE (2/11) : TEMOIN de la partie dc-croissance pour la regle de coupure du reseau (shared/team/coupure_reseau.lua) : meme partie, mais
-- l'interrupteur d'essai no_coupure (remote fo-ia1d set_option) est pose sur chaque equipe des qu'elle a son plan directeur.
-- Lancement : banc.py --out <archive> --graine <g> --qui ENERGIE -- 540000 dc-croissance-sanscoupure <source>
local base = require("scenarios/dc_evolution_common")(860000)
local tick0 = base.tick
base.tick = function(ctx, e)
  tick0(ctx, e)
  if e.tick % 600 == 0 and e.tick <= 36000 then
    local ok, rows = pcall(remote.call, "fo-ia1", "teams")
    local n = 0
    for _, row in ipairs(ok and rows or {}) do
      local ok2, r = pcall(remote.call, "fo-ia1d", "set_option", row.key, "no_coupure", true)
      if ok2 and r == true then n = n + 1 end
    end
    if n > 0 and not ctx.state().coupure_off_logged then
      ctx.state().coupure_off_logged = true
      ctx.log(string.format("TEMOIN : no_coupure pose sur %d equipe(s) a %d ticks", n, e.tick))
    end
  end
end
return base
