-- Lot RB-FLUIDE (1/11) : la regle d'obtention de la capitalisation sur les VRAIES donnees du jeu (relevé des prototypes).
-- Tout est executant, toutes les categories de machines sont presentes ; seul ce que la force CONNAIT change (petrole, eau). Avant le lot
-- (shared/ai3/capitalisation.lua de main 0.6.34), le pack chimique est « non obtenable » dans les deux cas ; apres, il l'est quand le
-- petrole et l'eau sont connus, et seulement alors.
--   py -3.9 -B tools/autotest/banc.py --out <archive> --qui RB-FLUIDE -- 100 rb-fluide-obtenable <source>
local ITEMS = { "chemical-science-pack", "sulfur", "plastic-bar", "petroleum-gas", "battery", "crude-oil", "automation-science-pack" }

local function ligne(r)
  local t = {}
  for _, k in ipairs(ITEMS) do t[#t + 1] = k .. "=" .. tostring(r[k]) end
  return table.concat(t, " ")
end

return {
  description = "RB-FLUIDE : obtention du pack chimique (recettes a fluide) sur les donnees reelles",
  check_tick = 60,
  init = function(ctx)
    local sans = ctx.remote("fo-robots-faction", "obtenable", ITEMS, { "iron-ore", "copper-ore", "coal", "stone" })
    local avec = ctx.remote("fo-robots-faction", "obtenable", ITEMS, { "iron-ore", "copper-ore", "coal", "stone", "crude-oil", "water" })
    local sans_eau = ctx.remote("fo-robots-faction", "obtenable", ITEMS, { "iron-ore", "copper-ore", "coal", "stone", "crude-oil" })
    ctx.log("petrole et eau inconnus : " .. ligne(sans))
    ctx.log("petrole seul connu      : " .. ligne(sans_eau))
    ctx.log("petrole et eau connus   : " .. ligne(avec))
    local st = ctx.state()
    st.sans, st.avec, st.sans_eau = sans, avec, sans_eau
    ctx.check(sans["automation-science-pack"] == true and avec["automation-science-pack"] == true, "le pack rouge (sans fluide) reste obtenable dans tous les cas")
    ctx.check(sans["chemical-science-pack"] == false, "petrole et eau inconnus : le pack chimique n'est PAS obtenable")
    ctx.check(avec["chemical-science-pack"] == true, "petrole et eau connus : le pack chimique est obtenable")
    ctx.check(avec["petroleum-gas"] == true and avec["crude-oil"] == true and avec["plastic-bar"] == true and avec["sulfur"] == true,
      "petrole et eau connus : gaz, plastique, soufre obtenables (fluides et recettes a fluide)")
    ctx.check(sans_eau["sulfur"] == false and sans_eau["chemical-science-pack"] == false, "eau inconnue : le soufre (eau + gaz) ne l'est pas")
  end,
  tick = function() end,
  finish = function() end,
}
