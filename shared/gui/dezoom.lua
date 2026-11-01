--[[
  Dézoom étendu (demande du Directeur Créatif, 31/10 : « il faudrait qu on puisse dezoomer plus car la vision est assez
  proche meme en full dezoomer, si on doit visualiser une megabase l idee serait de dezoomer 20 pourcent de plus »).

  Règle PURE (aucune API moteur) : une liste de crans de zoom sous la limite de la molette. `LuaPlayer.zoom` s'écrit par
  script mais ne se lit pas (runtime-api.json : read = false) : le mod ne connaît donc que le DERNIER cran qu'il a posé.

  Cran 0 = la molette du jeu a la main. Cran k >= 1 = le zoom écrit VALUES[k]. Vers le bas (dézoomer) : cran + 1, borné.
  Vers le haut : cran - 1 ; on repasse au cran 0 en réécrivant la limite de la molette, d'où la molette reprend normalement.

  LIMITE DE LA MOLETTE : WHEEL_LIMIT = 0,25 n'est PAS prouvée (ni prototype, ni utility-constants, ni doc ne la donnent ;
  `allow-increased-zoom` du config.ini est une option de débogage). C'est la valeur connue du jeu 1.1, à confirmer en jeu
  par le Directeur Créatif ; les crans (0,80 / 0,64 / 0,50 / 0,40 de la limite) couvrent l'incertitude.
]]

local M = {}

M.WHEEL_LIMIT = 0.25
M.FACTORS = { 0.80, 0.64, 0.50, 0.40 } -- 1 : 20 % sous la limite de la molette
M.VALUES = {}
for i, f in ipairs(M.FACTORS) do M.VALUES[i] = M.WHEEL_LIMIT * f end

function M.count() return #M.VALUES end

--- Zoom à écrire pour un cran (0 : la limite de la molette). nil hors de 0..count.
function M.zoom_of(idx)
  if idx == 0 then return M.WHEEL_LIMIT end
  return M.VALUES[idx]
end

--- Un appui. `down` vrai : dézoomer d'un cran ; faux : remonter d'un cran.
--- Rend (cran, zoom à écrire ou nil). nil : rien à écrire (déjà au cran 0 en remontant).
--- Au dernier cran, un appui vers le bas réécrit le même zoom (la molette a pu le changer depuis).
function M.step(idx, down)
  idx = tonumber(idx) or 0
  if idx < 0 then idx = 0 elseif idx > #M.VALUES then idx = #M.VALUES end
  if down then
    idx = math.min(#M.VALUES, idx + 1)
  else
    if idx == 0 then return 0, nil end
    idx = idx - 1
  end
  return idx, M.zoom_of(idx)
end

--- Pourcentage du champ de vision par rapport à la limite de la molette (zoom plus petit = vue plus large).
function M.view_percent(zoom)
  return math.floor(M.WHEEL_LIMIT / zoom * 100 + 0.5)
end

return M
