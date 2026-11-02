--[[
  Lot AGES : libellé d'un objectif affiché d'une équipe (PUR : aucune API Factorio, testé hors jeu, tests/objectif_test.lua).

  Retour du DC du 2/11 (points 8 et 17) : « Unknown key: "fo-team.goal-ia3-alim-assembling-machine-2" ». L'objectif affiché
  (f.team.goal) est la clé du projet dominant du cerveau par besoins, écrite « ia3-<clé du but> » où chaque « : » devient
  « - » (shared/ai3/cerveau.lua). Les clés de traduction n'existaient que pour une partie des buts ; tout but nouveau
  (couverture, relève, amélioration, ordre de capitalisation, module « alim » de n'importe quel objet) donnait une clé
  inconnue à l'écran.

  Obj.describe(goal) rend { id, args } :
    id   = suffixe de la clé « fo-team.goal-<id> » (toujours une clé qui existe, test) ;
    args = liste de { kind, v } pour les paramètres __1__, __2__ : kind « item » (nom d'objet : nom localisé du prototype),
           « outpost » (genre d'avant-poste), « entity » (nom d'une famille à niveaux : le prototype de base), « number »,
           « text » (texte brut). Le runtime (script/team/objectif.lua) les traduit en chaînes localisées.
  Aucun but inconnu n'est une erreur : la clé de repli « ia3-autre » dit le texte brut.

  Les barreaux de l'échelle d'objectifs (T.ladder, T.player_ladder) gardent leur clé : id = goal.
]]

local Obj = {}

-- Modules « auto:<x> » dont <x> n'est PAS un objet du jeu et qui ont leur texte (script/gui/team_window.lua, AUTO_NAMED) ; tout
-- autre module automatise un objet : « ia3-auto-objet », avec le nom localisé de l'objet (aucun nom du jeu écrit ici).
Obj.FIXED_AUTO = { centrale = true, migration = true }
Obj.FIXED = { ["ia3-capital-fonderie"] = true, ["ia3-defense-munitions"] = true, ["ia3-recherche"] = true, ["ia3-armee"] = true }
Obj.OUTPOSTS = { coal = true, iron = true, copper = true, stone = true } -- genres d'avant-poste de T.OUTPOST_ORDER (test)

-- Nombre de paramètres de chaque clé « ia3-… » produite (le test compare au texte des fichiers de langue).
Obj.ARITY = {
  ["ia3-extraction-autre"] = 1, ["ia3-couverture"] = 1, ["ia3-releve"] = 1,
  ["ia3-auto-objet"] = 1, ["ia3-alim"] = 1,
  ["ia3-capital-up"] = 2, ["ia3-capital-pose"] = 1, ["ia3-capital-remplacer"] = 2,
  ["ia3-capi-couvrir"] = 1, ["ia3-capi-ouvrir"] = 1, ["ia3-capi-packs"] = 1, ["ia3-capi-chaine"] = 1, ["ia3-capi-fours"] = 1,
  ["ia3-capi-labos"] = 0, ["ia3-capi-energie"] = 0, ["ia3-capi-autre"] = 1,
  ["ia3-autre"] = 1,
}

local function res(id, ...) return { id = id, args = { ... } } end
local function item(v) return { kind = "item", v = v } end
local function text(v) return { kind = "text", v = v } end

--- Libellé d'un objectif (chaîne). Rend toujours une table { id, args }.
function Obj.describe(goal)
  goal = tostring(goal or "")
  local rest = goal:match("^ia3%-(.+)$")
  if not rest then return res(goal) end -- barreau de l'échelle d'objectifs
  if Obj.FIXED[goal] then return res(goal) end

  local kind = rest:match("^extraction%-(.+)$")
  if kind then
    if Obj.OUTPOSTS[kind] then return res(goal) end
    return res("ia3-extraction-autre", { kind = "outpost", v = kind })
  end
  kind = rest:match("^couverture%-(.+)$")
  if kind then return res("ia3-couverture", { kind = "outpost", v = kind }) end
  kind = rest:match("^releve%-(.+)$")
  if kind then return res("ia3-releve", { kind = "outpost", v = kind }) end

  local obj = rest:match("^auto%-(.+)$")
  if obj then
    if Obj.FIXED_AUTO[obj] then return res(goal) end
    return res("ia3-auto-objet", item(obj))
  end
  obj = rest:match("^alim%-(.+)$")
  if obj then return res("ia3-alim", item(obj)) end

  -- Amélioration payée par le capital : « capital:<famille>:<niveau>:<numéro ou "pose"> » ou « capital:remplacer:<de>><vers>:<n> ».
  local cap = rest:match("^capital%-(.+)$")
  if cap then
    local from, to = cap:match("^remplacer%-(.-)>(.-)%-%d+$")
    if from and to then return res("ia3-capital-remplacer", item(from), item(to)) end
    local fam, lvl, last = cap:match("^(.-)%-(%d+)%-(.+)$")
    if fam and fam ~= "" then
      if last == "pose" then return res("ia3-capital-pose", { kind = "entity", v = fam }) end
      return res("ia3-capital-up", { kind = "entity", v = fam }, { kind = "number", v = tonumber(lvl) })
    end
  end

  -- Ordre de la capitalisation : « capi:<genre>:<clé> ».
  local capi = rest:match("^capi%-(.+)$")
  if capi then
    local id = capi:match("^couvrir%-(.+)$")
    if id then return res("ia3-capi-couvrir", text(id)) end
    id = capi:match("^ouvrir%-(.+)$")
    if id then return res("ia3-capi-ouvrir", text(id)) end
    id = capi:match("^packs%-(.+)$")
    if id then return res("ia3-capi-packs", item(id)) end
    id = capi:match("^chaine%-(.+)$")
    if id then return res("ia3-capi-chaine", item(id)) end
    id = capi:match("^fours%-(.+)$")
    if id then return res("ia3-capi-fours", item(id)) end
    if capi:match("^labos") then return res("ia3-capi-labos") end
    if capi:match("^energie") then return res("ia3-capi-energie") end
    return res("ia3-capi-autre", text(capi))
  end
  return res("ia3-autre", text(rest))
end

return Obj
