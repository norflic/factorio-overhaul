--[[
  Lot TESTS-GIT (0.6.64) : bancs hors jeu qui lisent la LISTE des fichiers du dépôt (avant : git ls-files, git grep) ou qui écrivent un
  fichier temporaire, avec ou sans git.
    - D.git() : git répond-il ici, à la racine de SON dépôt (la racine du mod) ? Une copie sans .git (git archive) répond non ; une copie
      posée DANS un autre dépôt aussi (le préfixe de git n'y est pas vide : ses fichiers ne sont pas ceux de ce dépôt).
    - D.lua_files(dirs, opts) : fichiers .lua sous `dirs` (« . » : tout le dépôt), chemins relatifs « a/b.lua », triés. Avec git : les
      fichiers suivis (git ls-files --cached ; opts.untracked : aussi les non suivis non ignorés, --others --exclude-standard, comme
      git grep --untracked). Sans git : REPLI sur le disque (dir /s /b, ou find). Une copie git archive contient exactement les fichiers
      suivis : le disque y rend la même liste. Rend la liste et sa source ("git" ou "disque").
    - D.grep(word, dirs, opts) : lignes « chemin:numéro:texte » des fichiers de D.lua_files qui CONTIENNENT `word` (texte simple), comme
      git grep -n -F ; et le nombre de lignes par fichier (git grep -c).
    - D.env(controle, joue) : ligne « [ENVIRONNEMENT] git absent : <controle> joué sur le disque (repli) » ou « ... non joué ». Un contrôle
      non joué reste un ECHEC du banc qui l'appelle : jamais un OK.
    - D.tmpname() : chemin de fichier temporaire ÉCRIVABLE. Sous Windows, os.tmpname() rend « \sXXX. », à la RACINE du disque courant :
      écrivable sur F: (clé, exFAT), refusé sur C: (« Permission denied » : une copie du mod sur C: plantait sans BILAN). Le nom est gardé,
      rangé dans %TEMP%.
  Usage (depuis la racine du mod, comme tous les bancs) : local D = require("tests.depot")
]]
local D = {}

local WIN = package.config:sub(1, 1) == "\\"
local NUL = WIN and "nul" or "/dev/null"

local function lines_of(cmd)
  local out = {}
  local p = io.popen(cmd)
  if not p then return out end
  for l in p:lines() do
    l = l:gsub("\r$", "")
    if l ~= "" then out[#out + 1] = l end
  end
  p:close()
  return out
end

local git_ok = nil
--- git répond-il, et le dossier courant est-il la racine de son dépôt ? (mémorisé)
function D.git()
  if git_ok == nil then
    local p = io.popen("git rev-parse --is-inside-work-tree --show-prefix 2>" .. NUL)
    local out = p and p:read("*a") or ""
    if p then p:close() end
    local inside, prefix = out:match("^(%a+)\r?\n(.-)\r?\n?$")
    git_ok = inside == "true" and (prefix == nil or prefix == "")
  end
  return git_ok
end

local cwd = nil
local function here()
  if not cwd then
    cwd = (lines_of(WIN and "cd" or "pwd")[1] or ""):gsub("\\", "/"):gsub("/$", "")
  end
  return cwd
end

local function sorted_unique(list)
  table.sort(list)
  local out, last = {}, nil
  for _, v in ipairs(list) do
    if v ~= last then out[#out + 1] = v end
    last = v
  end
  return out
end

--- Fichiers .lua sous `dirs` (liste de dossiers relatifs ; « . » : tout le dépôt). Rend (liste triée, source).
function D.lua_files(dirs, opts)
  local files = {}
  if D.git() then
    local specs = {}
    for _, d in ipairs(dirs) do specs[#specs + 1] = '"' .. ((d == "." or d == "") and "*.lua" or (d .. "/*.lua")) .. '"' end
    local cmd = "git ls-files --cached" .. ((opts and opts.untracked) and " --others --exclude-standard" or "") .. " -- "
      .. table.concat(specs, " ") .. " 2>" .. NUL
    for _, l in ipairs(lines_of(cmd)) do files[#files + 1] = l:gsub("\\", "/") end
    return sorted_unique(files), "git"
  end
  local root = here()
  for _, d in ipairs(dirs) do
    local cmd
    if WIN then
      local base = (d == "." or d == "") and "" or (d:gsub("/", "\\") .. "\\")
      cmd = 'dir /s /b /a-d "' .. base .. '*.lua" 2>nul'
    else
      cmd = 'find "' .. ((d == "" and ".") or d) .. '" -type f -name "*.lua" 2>/dev/null'
    end
    for _, l in ipairs(lines_of(cmd)) do
      local p = l:gsub("\\", "/")
      if p:sub(1, #root + 1) == root .. "/" then p = p:sub(#root + 2) end
      p = p:gsub("^%./", "")
      if p:find("%.lua$") then files[#files + 1] = p end
    end
  end
  return sorted_unique(files), "disque"
end

--- Lignes contenant `word` (texte simple) : { "chemin:numéro:texte", ... } dans l'ordre des fichiers puis des lignes ; counts[chemin] =
--- nombre de lignes. Rend (lignes, counts, nombre de fichiers lus, source).
function D.grep(word, dirs, opts)
  local files, source = D.lua_files(dirs, opts)
  local out, counts = {}, {}
  for _, path in ipairs(files) do
    local f = io.open(path, "rb")
    if f then
      local n, c = 0, 0
      for line in f:lines() do
        n = n + 1
        line = line:gsub("\r$", "")
        if line:find(word, 1, true) then
          c = c + 1
          out[#out + 1] = path .. ":" .. n .. ":" .. line
        end
      end
      f:close()
      if c > 0 then counts[path] = c end
    end
  end
  return out, counts, #files, source
end

local said = {}
--- Ligne [ENVIRONNEMENT] (une fois par contrôle) quand git est absent : `joue` vrai = contrôle joué sur le disque (repli).
function D.env(controle, joue)
  local key = tostring(controle) .. (joue and "+" or "-")
  if said[key] then return end
  said[key] = true
  print("[ENVIRONNEMENT] git absent : " .. tostring(controle) .. (joue and " joué sur le disque (repli)" or " non joué"))
end

--- Chemin de fichier temporaire écrivable (voir l'en-tête).
function D.tmpname()
  local t = os.tmpname()
  if WIN and t:match("^\\[^\\/]*$") then
    local dir = os.getenv("TEMP") or os.getenv("TMP")
    if dir and dir ~= "" then t = dir:gsub("[\\/]$", "") .. t end
  end
  return t
end

return D
