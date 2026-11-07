--[[
  Lot VIDEO (0.6.61, demande du lead du 7/11 vers 21 h 50, ordre du DC de 21 h 37 : « TOUTES les règles de la vidéo … ALLUMÉES par
  défaut », et il veut en voir l'effet « dès que je lance ma partie », peut-être sa partie EN COURS) : MIGRATION UNIQUE des quatre
  réglages de carte de la vidéo (settings/video.lua) dans une partie sauvegardée avant la 0.6.61. Règle PURE (aucune API) : quand
  la migration est due, et quels réglages écrire. L'exécutant est script/ai3/video_reglages.lua.

  Pourquoi : un réglage de carte (runtime-global) déjà stocké dans une sauvegarde garde sa valeur stockée ; le nouveau défaut (vrai
  depuis la 0.6.60) ne s'applique qu'aux réglages ABSENTS de la sauvegarde [DÉDUIT de la doc des réglages, non joué]. Une partie
  passée par une version où ces réglages valaient faux les garderait éteints.
  Quand : à on_configuration_changed, quand la version PRÉCÉDENTE du mod (mod_changes[mod].old_version, « a.b.c ») est antérieure
  à Vr.BEFORE (0.6.61 : la 0.6.60 l'est aussi, elle n'avait pas cette migration), et une seule fois par partie (drapeau `done` de
  l'exécutant). Ensuite jamais : un réglage éteint plus tard par le DC est respecté. Un changement de contenu sans montée de version
  (mod_changes vide, F130), un mod ajouté à une partie (old_version absent) ou une version illisible : pas de migration.
]]

local Vr = {}

-- Triés par nom (ordre d'écriture et de journal déterministe).
Vr.NAMES = { "fo-debug-trace-carte", "fo-war-lots-minerai", "fo-war-paliers", "fo-war-portes" }
Vr.BEFORE = { 0, 6, 61 }

--- « a.b.c » antérieure à ref = { a, b, c } ? nil si la version est illisible.
function Vr.older(version, ref)
  if type(version) ~= "string" then return nil end
  local a, b, c = version:match("^(%d+)%.(%d+)%.(%d+)$")
  if not a then return nil end
  local v = { tonumber(a), tonumber(b), tonumber(c) }
  for i = 1, 3 do
    if v[i] ~= ref[i] then return v[i] < ref[i] end
  end
  return false
end

--- La migration est-elle due ? data = ConfigurationChangedData, mod_name = nom du mod, done = drapeau de la partie.
function Vr.due(data, mod_name, done)
  if done then return false end
  local ch = data and data.mod_changes and data.mod_changes[mod_name]
  return Vr.older(ch and ch.old_version, Vr.BEFORE) == true
end

--- Réglages à écrire : ceux de Vr.NAMES dont la valeur lue n'est pas vraie. read(name) rend la valeur, ou nil si le réglage
--- n'existe pas (alors rien n'est écrit pour lui).
function Vr.to_set(read)
  local out = {}
  for _, name in ipairs(Vr.NAMES) do
    local v = read(name)
    if v ~= nil and v ~= true then out[#out + 1] = name end
  end
  return out
end

return Vr
