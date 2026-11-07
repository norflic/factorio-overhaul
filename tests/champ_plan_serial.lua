--[[
  Empreinte d'un plan de champ (lot CHAMP-COUVERTURE, coût de Ch.plan) : sérialisation DÉTERMINISTE de tout ce que rend Ch.plan (entités
  dans l'ordre, cadre, stats, raisons, replis, refus, ordre et colonnes reposées), clés triées à toute profondeur, nombres en %.17g, puis
  FNV-1a 32 bits. Sert à prouver « tranches = bloc » et « optimisation = même plan », entité par entité, contre des empreintes de
  référence (tests/fixtures/champ_plans_ref.lua). Pur, aucune API Factorio.
]]
local S = {}

local function num(x)
  if x == math.floor(x) and math.abs(x) < 2 ^ 53 then return string.format("%d", x) end
  return string.format("%.17g", x)
end

local function ser(v, out)
  local t = type(v)
  if t == "nil" then out[#out + 1] = "~"
  elseif t == "boolean" then out[#out + 1] = v and "T" or "F"
  elseif t == "number" then out[#out + 1] = num(v)
  elseif t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "table" then
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
      local ta, tb = type(a), type(b)
      if ta ~= tb then return ta < tb end
      if ta == "number" then return a < b end
      return tostring(a) < tostring(b)
    end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
      ser(k, out)
      out[#out + 1] = "="
      ser(v[k], out)
      out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  else
    out[#out + 1] = "<" .. t .. ">" -- une fonction dans un plan : visible dans l'empreinte
  end
end

--- Chaîne de tout le plan (nil : « nil » et la raison).
function S.serial(p, why)
  if not p then return "nil:" .. tostring(why) end
  local out = {}
  ser(p, out)
  return table.concat(out)
end

--- FNV-1a 32 bits d'une chaîne, en hexadécimal.
function S.hash(s)
  local h = 2166136261
  local band, bxor, lsh = bit32.band, bit32.bxor, bit32.lshift
  local byte = string.byte
  for i = 1, #s do
    h = bxor(h, byte(s, i))
    -- h * 16777619 mod 2^32, sans dépasser la précision des doubles : 16777619 = 2^24 + 403 (h * 403 < 2^41)
    h = band(h * 403 + lsh(h, 24), 0xFFFFFFFF)
  end
  return string.format("%08x", h)
end

--- Empreinte courte d'un plan : (hash, longueur de la chaîne, entités).
function S.print(p, why)
  local s = S.serial(p, why)
  return S.hash(s), #s, p and #p.ents or 0
end

return S
