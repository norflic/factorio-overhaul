-- Mise en forme française des nombres du calculateur d'équilibre (virgule décimale, espace fine des milliers).
local F = {}

local function trim(s)
  if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
  return s
end

--- Nombre à `d` décimales au plus (2 par défaut), zéros inutiles retirés, virgule française ; ∞ pour math.huge.
function F.num(x, d)
  if x == nil then return "—" end
  if x == math.huge then return "∞" end
  if x ~= x then return "?" end
  d = d or 2
  local s = trim(string.format("%." .. d .. "f", x))
  if s == "-0" then s = "0" end
  return (s:gsub("%.", ","))
end

--- Entier arrondi avec séparateur des milliers (espace insécable fine).
function F.thousands(x)
  if x == nil then return "—" end
  if x == math.huge then return "∞" end
  local neg = x < 0
  local s = tostring(math.floor(math.abs(x) + 0.5))
  local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
  return (neg and "-" or "") .. out
end

function F.pct(x, d)
  return F.num(100 * x, d or 1) .. " %"
end

--- Heures en « 12 h 05 ».
function F.hours(h)
  if h == math.huge then return "∞" end
  local mins = math.floor(h * 60 + 0.5)
  return string.format("%d h %02d", math.floor(mins / 60), mins % 60)
end

--- Arrondi lisible (même règle que L.round_nice au-delà de 20 ; 1 décimale sous 20, au moins 0,1).
function F.nice(x)
  if x == math.huge then return math.huge end
  if x < 20 then return math.max(0.1, math.floor(x * 10 + 0.5) / 10) end
  if x < 100 then return math.floor(x / 5 + 0.5) * 5 end
  if x < 10000 then return math.floor(x / 10 + 0.5) * 10 end
  return math.floor(x / 100 + 0.5) * 100
end

--- Grand facteur : décimal sous 10 000, sinon « 1,2 × 10^7 ».
function F.big(x)
  if x == math.huge or x ~= x then return "∞" end
  if x < 10000 then return F.num(x, 2) end
  local e = math.floor(math.log(x, 10))
  return F.num(x / 10 ^ e, 1) .. " × 10^" .. e
end

--- Grand nombre entier : milliers sous 10 millions, sinon notation scientifique.
function F.bignum(x, d)
  if x == math.huge then return "∞" end
  if d and x < 100 then return F.num(x, d) end
  if x < 1e7 then return F.thousands(x) end
  return F.big(x)
end

--- Petite valeur : 2 décimales au-dessus de 0,01, sinon notation scientifique (« 3,1 × 10^-5 »).
function F.small(x)
  if x == math.huge then return "∞" end
  if x == 0 then return "0" end
  if x >= 0.01 then return F.num(x, 2) end
  local e = math.floor(math.log(x, 10))
  return F.num(x / 10 ^ e, 1) .. " × 10^" .. e
end

--- Accumulateur de lignes (fin de ligne LF).
function F.printer()
  local lines = {}
  return {
    p = function(s) lines[#lines + 1] = s end,
    text = function() return table.concat(lines, "\n") .. "\n" end,
  }
end

return F
