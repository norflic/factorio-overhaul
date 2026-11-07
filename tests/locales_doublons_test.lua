--[[
  Contrôle statique (demande du lead, 7/11 vers 19 h 15, après le défaut d'integ-l10 : `local Pl = require("shared.ai3.palier")` à la
  l.97 de script/ai3/capitalisation.lua masquait `local Pl = require("shared.team.plan")` de la l.68 ; Pl.PITCH devenait nil et
  build_input plantait, sans qu'aucun test statique ni pur ne le voie) : AUCUN fichier de shared/ ni de script/ ne déclare deux fois le
  même nom en `local` au niveau du MODULE (portée du fichier : hors de toute fonction et de tout bloc do, if, while, for, repeat).
  Une seconde déclaration masque la première pour toute la suite du fichier, et les fonctions déjà écrites plus haut gardent l'ancienne
  valeur.
  Lancer depuis la racine du mod (git requis pour la liste des fichiers, suivis ou non ; sinon « dir /s /b ») :
    lua5.2 tests/locales_doublons_test.lua   -> [LOCALES] BILAN : N OK, 0 ECHEC(S)
  §1 lecteur (cas écrits, chaînes et commentaires ignorés, blocs comptés) ; §2 tous les fichiers, exceptions encore utiles, mutant de
  l'exception ; §3 mutant : l'ancien `local Pl` remis.
  EXCEPTIONS (une seule le 7/11) : script/team/build.lua, out_wanted, deux copies IDENTIQUES (contrôlé à l'octet) ; une exception s'ajoute
  ligne par ligne, chemin et nom, avec sa raison écrite à côté.
]]
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[LOCALES] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end

-- Exceptions, une par ligne : ["chemin:nom"] = { same = vrai si les deux déclarations doivent rester identiques à l'octet (contrôlé),
-- why = raison }. Une exception qui ne correspond plus à aucun doublon est une ERREUR (à retirer).
local EXCEPTIONS = {
  ["script/team/build.lua:out_wanted"] = { same = true, why = "deux copies identiques (commentaire compris) posees par le meme commit "
    .. "f917e95f du 1/11 (relecture I5 a I7), aussi sur main ; aucun masquage de valeur ; la seconde est a retirer par le proprietaire de build.lua" },
}

--- Jetons utiles d'un source Lua 5.2 : { {k = "id"|"kw"|"op", v = texte, line = n} } ; commentaires et chaînes retirés.
local KW = { ["and"] = 1, ["break"] = 1, ["do"] = 1, ["else"] = 1, ["elseif"] = 1, ["end"] = 1, ["false"] = 1, ["for"] = 1,
  ["function"] = 1, ["goto"] = 1, ["if"] = 1, ["in"] = 1, ["local"] = 1, ["nil"] = 1, ["not"] = 1, ["or"] = 1, ["repeat"] = 1,
  ["return"] = 1, ["then"] = 1, ["true"] = 1, ["until"] = 1, ["while"] = 1 }
local function tokens(src)
  local out, i, n, line = {}, 1, #src, 1
  local function long_end(at) -- at : position du premier « [ » ; rend la fin de la longue chaîne, ou nil
    local eq = src:match("^%[(=*)%[", at)
    if not eq then return nil end
    local close = "]" .. eq .. "]"
    local j = src:find(close, at + #eq + 2, true)
    return j and (j + #close - 1) or n
  end
  while i <= n do
    local c = src:sub(i, i)
    if c == "\n" then line = line + 1 i = i + 1
    elseif c:match("%s") then i = i + 1
    elseif src:sub(i, i + 1) == "--" then
      local e = (src:sub(i + 2, i + 2) == "[") and long_end(i + 2) or nil
      if not e then e = (src:find("\n", i, true) or (n + 1)) - 1 end
      for _ in src:sub(i, e):gmatch("\n") do line = line + 1 end
      i = e + 1
    elseif c == '"' or c == "'" then
      local j = i + 1
      while j <= n do
        local d = src:sub(j, j)
        if d == "\\" then j = j + 2 elseif d == c or d == "\n" then break else j = j + 1 end
      end
      out[#out + 1] = { k = "str", v = "", line = line }
      i = j + 1
    elseif c == "[" and long_end(i) then
      local e = long_end(i)
      for _ in src:sub(i, e):gmatch("\n") do line = line + 1 end
      out[#out + 1] = { k = "str", v = "", line = line }
      i = e + 1
    elseif c:match("[%a_]") then
      local w = src:match("^[%w_]+", i)
      out[#out + 1] = { k = KW[w] and "kw" or "id", v = w, line = line }
      i = i + #w
    elseif c:match("%d") then
      local w = src:match("^0[xX][%x%.]+[pP]?[%+%-]?%x*", i) or src:match("^[%d%.]+[eE]?[%+%-]?%d*", i)
      i = i + #w
    else
      out[#out + 1] = { k = "op", v = c, line = line }
      i = i + 1
    end
  end
  return out
end

--- Locales du niveau du module : liste { name, line } dans l'ordre du source.
local function module_locals(src)
  local t, out, depth = tokens(src), {}, 0
  local OPEN = { ["function"] = true, ["do"] = true, ["if"] = true, ["repeat"] = true }
  local i = 1
  while i <= #t do
    local tk = t[i]
    if tk.k == "kw" then
      if tk.v == "local" and depth == 0 then
        local nx = t[i + 1]
        if nx and nx.k == "kw" and nx.v == "function" then
          if t[i + 2] and t[i + 2].k == "id" then out[#out + 1] = { name = t[i + 2].v, line = t[i + 2].line } end
        else
          local j = i + 1
          while t[j] and t[j].k == "id" do
            out[#out + 1] = { name = t[j].v, line = t[j].line }
            if t[j + 1] and t[j + 1].k == "op" and t[j + 1].v == "," then j = j + 2 else break end
          end
        end
      elseif OPEN[tk.v] then depth = depth + 1
      elseif tk.v == "end" or tk.v == "until" then depth = depth - 1
      end
    end
    i = i + 1
  end
  return out, depth
end

--- Doublons d'un source : liste de textes « nom (l.a puis l.b) », et la profondeur finale (0 si le lecteur a bien suivi les blocs).
local USED = {} -- exceptions rencontrées : { [clé] = vrai }
--- Texte de chaque « local function nom( » jusqu'à son « end » en début de ligne (exception « same »).
local function bodies(src, name)
  local out, at = {}, 1
  while true do
    local i = src:find("local function " .. name .. "(", at, true)
    if not i then break end
    local j = src:find("\nend\n", i, true) or #src
    out[#out + 1] = src:sub(i, j)
    at = j
  end
  return out
end
local function doubles(src, path)
  local locs, depth = module_locals(src)
  local seen, out = {}, {}
  for _, l in ipairs(locs) do
    local key = (path or "?") .. ":" .. l.name
    local ex = EXCEPTIONS[key]
    if seen[l.name] then
      if ex and ex.same then
        local b = bodies(src, l.name)
        if #b == 2 and b[1] == b[2] then USED[key] = true else ex = nil end
      elseif ex then USED[key] = true end
      if not ex then out[#out + 1] = string.format("%s (l.%d puis l.%d)", l.name, seen[l.name], l.line) end
    end
    seen[l.name] = seen[l.name] or l.line
  end
  return out, depth, #locs
end

-- §1 le lecteur
do
  local src = table.concat({
    'local A = require("x") -- local B = 1',
    'local s = "local C = 2" .. [[local D = 3]] .. [==[ ]] local E ]==]',
    '--[[ local F = 4 ]]',
    'local function g(a) local A = a if a then local H = 1 end return A end',
    'do local A = 5 end',
    'for i = 1, 2 do local I = i end',
    'while false do local J = 1 end',
    'repeat local K = 1 until true',
    'local L, M = 1, 2',
    'local t = { ["end"] = 1, x = function() local A = 1 end }',
    'local A = 6',
  }, "\n")
  local locs, depth = module_locals(src)
  local names = {}
  for _, l in ipairs(locs) do names[#names + 1] = l.name end
  check(table.concat(names, ",") == "A,s,g,L,M,t,A" and depth == 0,
    "§1 locales du module seulement, chaines et commentaires ignores, blocs suivis (" .. table.concat(names, ",") .. ", profondeur " .. depth .. ")")
  local d = doubles(src)
  check(#d == 1 and d[1] == "A (l.1 puis l.11)", "§1 un doublon vu, ligne par ligne (" .. table.concat(d, " ; ") .. ")")
  check(#doubles("local A = 1\nlocal function f() local A = 2 end\ndo local A = 3 end\nif x then local A = 4 end") == 0,
    "§1 une locale de fonction ou de bloc n'est pas un doublon du module")
  check(#doubles("local A\nlocal function A() end") == 1, "§1 local function compte comme une declaration")
end

-- §2 tous les fichiers de shared/ et de script/
local function list_files()
  local files = {}
  local p = io.popen('git ls-files --cached --others --exclude-standard -- "shared/*.lua" "script/*.lua" 2>nul')
  if p then
    for l in p:lines() do files[#files + 1] = l end
    p:close()
  end
  if #files == 0 then
    local q = io.popen('dir /s /b /a-d shared\\*.lua script\\*.lua 2>nul')
    if q then
      for l in q:lines() do
        local rel = l:gsub("\\", "/"):match("/(shared/.+)$") or l:gsub("\\", "/"):match("/(script/.+)$")
        if rel then files[#files + 1] = rel end
      end
      q:close()
    end
  end
  table.sort(files)
  local uniq, last = {}, nil
  for _, f in ipairs(files) do if f ~= last then uniq[#uniq + 1] = f end last = f end
  return uniq
end
local files = list_files()
check(#files >= 100, "§2 fichiers trouves dans shared/ et script/ (" .. #files .. ")")
local total, nlocs, bad_depth = 0, 0, {}
for _, path in ipairs(files) do
  local ok, src = pcall(read, path)
  if ok then
    local d, depth, n = doubles(src, path)
    nlocs = nlocs + n
    if depth ~= 0 then bad_depth[#bad_depth + 1] = path .. " (" .. depth .. ")" end
    for _, x in ipairs(d) do
      total = total + 1
      print("[LOCALES] doublon : " .. path .. " : " .. x)
    end
  end
end
print(string.format("[LOCALES] §2 %d fichier(s), %d locale(s) du module, %d doublon(s), %d exception(s)", #files, nlocs, total,
  (function() local k = 0 for _ in pairs(EXCEPTIONS) do k = k + 1 end return k end)()))
check(#bad_depth == 0, "§2 le lecteur suit les blocs de chaque fichier (profondeur finale 0) : " .. table.concat(bad_depth, ", "))
check(total == 0, "§2 aucune locale du module declaree deux fois (" .. total .. " doublon(s))")
do
  local keys = {}
  for k in pairs(EXCEPTIONS) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    print("[LOCALES] exception : " .. k .. " : " .. EXCEPTIONS[k].why)
    check(USED[k] == true, "§2 exception encore utile (doublon present" .. (EXCEPTIONS[k].same and ", copies identiques" or "") .. ") : " .. k)
  end
end
do -- mutant de l'exception : la seconde copie de out_wanted modifiée d'un caractère n'est plus couverte
  local path = "script/team/build.lua"
  local okr, src = pcall(read, path)
  local i = okr and src:find("local function out_wanted(", src:find("local function out_wanted(", 1, true) + 1, true)
  local m = i and (src:sub(1, i - 1) .. src:sub(i):gsub("return false", "return nil", 1))
  check(m ~= nil and #doubles(m, path) == 1, "§2 mutant refuse : copies de out_wanted devenues differentes, l'exception ne couvre plus")
end

-- §3 mutant : l'ancien `local Pl = require("shared.ai3.palier")` remis à côté de `local Pl = require("shared.team.plan")`
do
  local path = "script/ai3/capitalisation.lua"
  local src = read(path)
  local anchor = 'local Pl = require("shared.team.plan")'
  local i = src:find(anchor, 1, true)
  local e = i and src:find("\n", i, true)
  local seen = false
  if e then
    local m = src:sub(1, e) .. 'local Pl = require("shared.ai3.palier")\n' .. src:sub(e + 1)
    local d = doubles(m, path)
    for _, x in ipairs(d) do if x:find("^Pl %(") then seen = true end end
  end
  check(seen, "§3 mutant refuse : l'ancien « local Pl » de l'etape 7 remis dans " .. path)
end

print(string.format("[LOCALES] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
