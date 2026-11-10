--[[
  Lot BALISES-TEINTE (décision du DC, 10/11) : la teinte LUMINEUSE d'une balise suit le code couleur des MODULES qu'elle
  contient : cyan = vitesse, ambre = productivité, vert émeraude = efficacité (couleurs du lot ART-MODULES,
  tools/render/pieces/modules/LISEZMOI.md : #00E5FF, #FF9E1B, #1FE88A). Pur Lua, lu des DEUX côtés :
    - data    : prototypes/modules.lua (teinte `beacon_tint.secondary` de chaque module : couche lumineuse des balises) ;
    - control : script/team/balises_teinte.lua (lumière posée sur chaque balise d'après ses modules).
  Aucun nom d'objet : la famille d'un module se lit à sa table `effect` (data) ou `module_effect` (control) :
  { speed = { bonus }, productivity = { bonus }, consumption = { bonus }, pollution = { bonus } }.
  EN : beacon glow tint by module family, read from the module's effect table ; one shared colour table for data and control.
]]

local Mt = {}

--- Familles, dans l'ordre FIXE qui tranche les égalités (clé de la table `effect` du moteur).
Mt.FAMILLES = { "speed", "productivity", "consumption" }

--- Alias des familles telles que shared/content/modules.lua les nomme (M.ORDER) vers la clé d'effet du moteur.
Mt.ALIAS = { effectivity = "consumption", speed = "speed", productivity = "productivity" }

--- Code couleur du DC (lot ART-MODULES), composantes 0..1 (hex / 255).
Mt.COULEURS = {
  speed        = { r = 0.000, g = 0.898, b = 1.000 }, -- #00E5FF cyan électrique       / electric cyan
  productivity = { r = 1.000, g = 0.620, b = 0.106 }, -- #FF9E1B ambre ionique         / ionic amber
  consumption  = { r = 0.122, g = 0.910, b = 0.541 }, -- #1FE88A vert émeraude         / emerald green
}

--- Couleur { r, g, b } (copie) de la famille `famille` (clé d'effet ou alias), ou nil si inconnue.
function Mt.couleur(famille)
  local c = Mt.COULEURS[Mt.ALIAS[famille] or famille]
  if not c then return nil end
  return { r = c.r, g = c.g, b = c.b }
end

--- Gain d'une composante : ce qu'elle APPORTE (vitesse et productivité positives ; consommation NÉGATIVE : un module de
--- vitesse coûte de l'énergie, cela n'en fait pas un module d'efficacité). Un malus compte 0.
local function gain(famille, bonus)
  if type(bonus) ~= "number" then return 0 end
  if famille == "consumption" then return bonus < 0 and -bonus or 0 end
  return bonus > 0 and bonus or 0
end

--- Famille d'un module d'après sa table `effect` / `module_effect` : la plus forte des trois composantes décide ;
--- égalité → ordre de Mt.FAMILLES ; aucune composante positive → nil.
function Mt.famille(effect)
  if type(effect) ~= "table" then return nil end
  local best, best_g = nil, 0
  for _, fam in ipairs(Mt.FAMILLES) do
    local e = effect[fam]
    local g = gain(fam, type(e) == "table" and e.bonus or e)
    if g > best_g then best, best_g = fam, g end
  end
  return best
end

--- Comptes par famille d'une liste de familles (une entrée par module ; nil ignoré) : { speed = n, productivity = n,
--- consumption = n, total = n, familles = nombre de familles présentes }.
function Mt.compte(familles)
  local n = { speed = 0, productivity = 0, consumption = 0, total = 0, familles = 0 }
  for _, fam in ipairs(familles or {}) do
    if n[fam] ~= nil and fam ~= "total" and fam ~= "familles" then
      if n[fam] == 0 then n.familles = n.familles + 1 end
      n[fam] = n[fam] + 1
      n.total = n.total + 1
    end
  end
  return n
end

--- Couleur d'une balise d'après les familles de ses modules : une seule famille → sa couleur ; mélange → moyenne pondérée
--- par le nombre de modules de chaque famille ; vide → `defaut` tel quel (la couleur d'âge du prototype, inchangée).
function Mt.teinte(familles, defaut)
  local n = Mt.compte(familles)
  if n.total == 0 then return defaut end
  local r, g, b = 0, 0, 0
  for _, fam in ipairs(Mt.FAMILLES) do
    local k, c = n[fam], Mt.COULEURS[fam]
    if k > 0 then r, g, b = r + c.r * k, g + c.g * k, b + c.b * k end
  end
  return { r = r / n.total, g = g / n.total, b = b / n.total }
end

--- Deux couleurs sont-elles les mêmes au 1/255 près (pas de redessin pour un bruit d'arrondi) ?
function Mt.meme(a, b)
  if a == nil or b == nil then return a == b end
  local eps = 1 / 255
  return math.abs(a.r - b.r) < eps and math.abs(a.g - b.g) < eps and math.abs(a.b - b.b) < eps
end

return Mt
