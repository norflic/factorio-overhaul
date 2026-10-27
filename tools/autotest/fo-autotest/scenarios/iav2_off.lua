--[[
  Lot IA-V2 (27/10, version 0.5.0) : les trois bascules du nouveau cerveau sont ALLUMÉES par défaut (marché et registre
  d'IA3-b, cerveau par besoins d'IA3-c, brouillard d'IA3-f). Les TÉMOINS « avant » (ia3b-fer-avant, ia3c-dc-avant,
  ia3-fer-joueur-avant, ia3-brouillard-avant) rejouent la même carte avec le comportement de 0.4.30 : les trois bascules
  ÉTEINTES avant la guerre ou la pose du coffre (le marché est figé par équipe à sa première lecture, le cerveau aussi
  une fois allumé : l'éteindre AVANT la première pensée suffit).
  Usage : require("scenarios/iav2_off")(ctx, { marche = false, cerveau = false, fog = false }) ; un champ absent n'est
  pas touché.
]]
return function(ctx, want)
  if want.marche ~= nil then
    local v = ctx.remote("factorio-overhaul", "war_setting", "fo-war-ia3-marche", want.marche)
    ctx.check(v == want.marche, "reglage fo-war-ia3-marche " .. (want.marche and "allume" or "eteint") .. " (IA-V2)", tostring(v))
  end
  if want.cerveau ~= nil then
    local v = ctx.remote("factorio-overhaul", "war_setting", "fo-war-ia3-cerveau", want.cerveau)
    ctx.check(v == want.cerveau, "reglage fo-war-ia3-cerveau " .. (want.cerveau and "allume" or "eteint") .. " (IA-V2)", tostring(v))
  end
  if want.fog ~= nil then
    local v = ctx.remote("fo-ia3f", "set_fog", want.fog)
    ctx.check(v == want.fog, "brouillard " .. (want.fog and "actif" or "coupe") .. " (IA-V2)", tostring(v))
  end
end
