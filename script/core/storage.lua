--[[
  Stockage persistant versionné.

  - Chaque module déclare son namespace (Storage.declare) avec une fonction d'initialisation.
  - Un namespace absent d'une sauvegarde existante est créé automatiquement en on_configuration_changed :
    ajouter un module au mod ne casse jamais une partie en cours.
  - Les migrations de schéma sont séquentielles (schema N -> N+1), jouées avant la création des namespaces.

  Règles (déterminisme / sauvegarde) :
  - Ne JAMAIS stocker de fonction dans la table persistante (non sérialisable) : on stocke des noms de
    handlers (chaînes) et on résout la fonction au runtime.
  - Ne jamais mettre en cache la table persistante au niveau fichier : elle est remplacée au chargement.
]]

local Events = require("script.core.events")

local Storage = {}

Storage.SCHEMA_VERSION = 2 -- 2 : économie réelle des équipes (0.3)

local namespaces = {}  -- { {name=, init=}, ... } dans l'ordre de déclaration
local migrations = {}  -- [version_cible] = function(fo)

-- PORT-2.0 : en Factorio 2.0, `global` devient `storage`. C'est la seule ligne du mod qui nomme
-- la table persistante.
local function root()
  return global
end

function Storage.declare(name, init_fn)
  for i = 1, #namespaces do
    if namespaces[i].name == name then error("Storage : namespace déjà déclaré : " .. name) end
  end
  namespaces[#namespaces + 1] = { name = name, init = init_fn }
end

function Storage.migration(target_version, fn)
  migrations[target_version] = fn
end

function Storage.ns(name)
  return root().fo[name]
end

function Storage.raw()
  return root().fo
end

local function ensure_namespaces(fo)
  for i = 1, #namespaces do
    local ns = namespaces[i]
    if fo[ns.name] == nil then fo[ns.name] = ns.init() end
  end
end

Events.on_init(function()
  local r = root()
  r.fo = { schema = Storage.SCHEMA_VERSION }
  ensure_namespaces(r.fo)
end)

Events.on_configuration_changed(function()
  local r = root()
  if not r.fo then r.fo = { schema = Storage.SCHEMA_VERSION } end
  local fo = r.fo
  while fo.schema < Storage.SCHEMA_VERSION do
    local target = fo.schema + 1
    local m = migrations[target]
    if m then m(fo) end
    fo.schema = target
  end
  ensure_namespaces(fo)
end)

return Storage
