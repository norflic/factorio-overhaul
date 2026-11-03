--[[
  Lot FONDERIE-M (3/11, diagnostic du verif-guide 1618033988) : un minage à la main PRUDENT (mode survie, cerveau par besoins, manque de
  plaques) ou DE FOND ne va pas sur une tuile proche d'un site de l'équipe où la prévision annonce une vague (cadre « preparer » ouvert) ou
  la juge insurmontable. Mesuré : à 20,0 min « ap1 INSURMONTABLE (vague 801 PV contre 503 PV reunissables) : repli au QG » ; à 21,7 min le
  mode survie demande du minerai de fer à la main ; à 36,0 min deux PNJ meurent en minant en (40, -49) et (40, -50), à 9 tuiles de cet
  avant-poste (49, -50) ; dans le passage K, aussi à 39,6 et 48,3 min.
  Règle pure (aucune lecture du moteur) ; le jeu passe les sites de script/ai3/prevision.lua (Prev.wave_sites, crochet Worker.wave_sites).
]]
local Mv = {}

Mv.R = 40 -- tuiles autour d'un site dont la vague est attendue ou insurmontable : aucun minage prudent ni de fond

--- Sites menacés : ceux de `sites` ({ key, kind, x, y }) dont l'état de prévision (`states[key]` : { prep, insurm }) annonce une vague ou
--- la juge insurmontable ; le QG est exclu (défendu par ses tourelles, et les mineurs n'auraient plus de tuile proche). Rend { { x, y } }.
function Mv.from_states(sites, states)
  local out = {}
  for _, s in ipairs(sites or {}) do
    local ps = states and states[s.key]
    if s.kind ~= "qg" and ps and (ps.prep == true or ps.insurm == true) then out[#out + 1] = { x = s.x, y = s.y } end
  end
  return out
end

--- Vrai si la tuile (x, y) est à `r` tuiles (Mv.R par défaut) ou moins d'un site menacé.
function Mv.blocked(x, y, sites, r)
  r = r or Mv.R
  local r2 = r * r
  for _, s in ipairs(sites or {}) do
    if (x - s.x) * (x - s.x) + (y - s.y) * (y - s.y) <= r2 then return true end
  end
  return false
end

return Mv
