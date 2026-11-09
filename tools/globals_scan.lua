-- Balaye les fichiers Lua (5.2) donnés en argument et liste les LECTURES et ÉCRITURES de variables globales
-- inconnues, en lisant le bytecode (string.dump) : c'est ce qui aurait attrapé `o` de champ.lua:716 avant la partie.
-- Usage : lua5.2 globals_scan.lua fichier1.lua fichier2.lua ...
local KNOWN = {}
for w in ([[game script global defines rendering settings remote commands log rcon serpent ipairs pairs next type tostring
tonumber table string math select unpack assert error pcall xpcall setmetatable getmetatable rawget rawset rawequal rawlen
require package print bit32 load loadstring debug os io _G _ENV __DebugAdapter localised_print mods data coroutine collectgarbage
dofile loadfile table_size]]):gmatch("%S+") do KNOWN[w] = true end

local function reader(s)
  local pos, R = 1, {}
  function R.byte() local b = s:byte(pos); pos = pos + 1; return b end
  function R.int()
    local a, b, c, d = s:byte(pos, pos + 3); pos = pos + 4
    return a + b * 256 + c * 65536 + d * 16777216
  end
  function R.size() -- size_t : 4 ou 8 octets selon la compilation
    local v = 0
    for i = R.sizet, 1, -1 do v = v * 256 + s:byte(pos + i - 1) end
    pos = pos + R.sizet
    return v
  end
  function R.skip(n) pos = pos + n end
  function R.str()
    local n = R.size()
    if n == 0 then return nil end
    local v = s:sub(pos, pos + n - 2); pos = pos + n
    return v
  end
  return R
end

local function fonction(R, sink)
  local line = R.int(); R.int(); R.byte(); R.byte(); R.byte()
  local ncode = R.int()
  local code = {}
  for i = 1, ncode do code[i] = R.int() end
  local nk = R.int()
  local k = {}
  for i = 0, nk - 1 do
    local t = R.byte()
    if t == 1 then R.byte() elseif t == 3 then R.skip(8) elseif t == 4 then k[i] = R.str() end
  end
  local np = R.int()
  local protos = {}
  for i = 1, np do protos[i] = fonction(R, sink) end
  local nu = R.int(); R.skip(nu * 2)
  R.str() -- source
  local nl = R.int()
  local lines = {}
  for i = 1, nl do lines[i] = R.int() end
  local nv = R.int()
  for i = 1, nv do R.str(); R.int(); R.int() end
  local nun = R.int()
  local upnames = {}
  for i = 0, nun - 1 do upnames[i] = R.str() end
  for i, ins in ipairs(code) do
    local op = ins % 64
    local a = math.floor(ins / 64) % 256
    local c = math.floor(ins / 16384) % 512
    local b = math.floor(ins / 8388608) % 512
    if op == 6 and upnames[b] == "_ENV" and c >= 256 and k[c - 256] then sink("lit", k[c - 256], lines[i] or line) end
    if op == 8 and upnames[a] == "_ENV" and b >= 256 and k[b - 256] then sink("ecrit", k[b - 256], lines[i] or line) end
  end
end

local total = 0
for _, path in ipairs(arg) do
  local fn, err = loadfile(path)
  if not fn then
    print("ERREUR " .. path .. " : " .. err); total = total + 1
  else
    local d = string.dump(fn)
    local R = reader(d)
    R.skip(4 + 1 + 1 + 1 + 1) -- signature, version, format, boutisme, sizeof(int)
    R.sizet = R.byte()
    R.skip(1 + 1 + 1 + 6) -- instruction, nombre, intégral, queue
    local seen = {}
    fonction(R, function(mode, name, line)
      if not KNOWN[name] then
        local key = mode .. name .. line
        if not seen[key] then
          seen[key] = true
          total = total + 1
          print(string.format("%s:%d: %s la globale inconnue '%s'", path, line, mode, name))
        end
      end
    end)
  end
end
print(("BILAN : %d fichier(s), %d globale(s) inconnue(s)"):format(#arg, total))
