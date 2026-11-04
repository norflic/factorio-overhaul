--[[
  Lot DA-ENERGIE (4/11) : feuilles de la piscine d'entreposage, du dépôt géologique et de l'amplificateur de résonance
  (graphics/da/energie, PNG hors de git, D-6). Lua pur, depuis la racine du mod :

      lua5.2 tests/da_energie_feuilles_test.lua

  §1 manifeste et images (tests/datastage/da_energie_sheets.lua) ; §2 structure de sprites.lua : normale = moitié de la hr,
  même shift, rangées d'images (pièces mobiles) et leur lueur synchronisées, côtés pairs, 8 192 px au plus (F144), boîte de
  dessin qui contient chaque couche, icône ; §3 mutants : le contrôle refuse une image absente, une taille fausse, une rangée
  désynchronisée.
]]

local Sheets = dofile("tests/datastage/da_energie_sheets.lua")
local ok_n, fail_n = 0, 0
local function check(c, msg, detail)
  if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 end
  print(string.format("[DA-ENERGIE] %s %s%s", c and "OK" or "ECHEC", msg, detail and (" : " .. detail) or ""))
end

-- §1 manifeste
local r = Sheets.check(".")
for _, l in ipairs(Sheets.lines(r)) do print(l) end
check(Sheets.ok(r), "§1 manifeste, PNG présents, dimensions de sprites.lua", string.format("%d fichier(s), %d image(s) relue(s)", r.n, r.refs or 0))
if not Sheets.ok(r) then
  print("[DA-ENERGIE] BILAN : " .. ok_n .. " OK, " .. fail_n .. " ECHEC(S) (feuilles à régénérer : " .. Sheets.REGEN .. ")")
  os.exit(1)
end

-- §2 structure
local SPR = dofile(Sheets.DIR .. "/sprites.lua")
local function demi(n) return math.floor((n + 1) / 2) end
local function rect(c)
  local w, h = c.hr.width / 64, c.hr.height / 64
  return c.hr.shift[1] - w / 2, c.hr.shift[2] - h / 2, c.hr.shift[1] + w / 2, c.hr.shift[2] + h / 2
end
local ATTENDU = { piscine = { mobile = true }, depot = { lumiere = true }, reso = { mobile = true, lumiere = true },
  msr = { chaleur = true }, geo = { directions = true } }
local function unites(nom, u)
  if not u.directions then return { { nom, u } } end
  local t = {}
  for _, d in ipairs(Sheets.DIRECTIONS) do t[#t + 1] = { nom .. " " .. d, u.directions[d], u } end
  return t
end
for _, nom0 in ipairs(Sheets.BATIMENTS) do
 for _, un in ipairs(unites(nom0, SPR[nom0])) do
  local nom, u = un[1], un[2]
  local att = ATTENDU[nom0]
  if un[3] then u.boite, u.icone, u.map_color = un[3].boite, un[3].icone, un[3].map_color end
  local kinds = { "main", "shadow", "glow", "mobile", "mobile_glow", "lumiere", "chaleur" }
  local bon, ecarts = true, {}
  for _, k in ipairs(kinds) do
    local c = u[k]
    if c then
      if c.lr.width ~= demi(c.hr.width) or c.lr.height ~= demi(c.hr.height) then
        bon = false; ecarts[#ecarts + 1] = k .. " : normale pas la moitié de la hr"
      end
      if c.lr.shift[1] ~= c.hr.shift[1] or c.lr.shift[2] ~= c.hr.shift[2] then
        bon = false; ecarts[#ecarts + 1] = k .. " : shift différent entre hr et normale"
      end
      if c.hr.width * (c.images or 1) > 8192 or c.hr.height > 8192 then
        bon = false; ecarts[#ecarts + 1] = k .. " : plus de 8 192 px (F144)"
      end
      local x0, y0, x1, y1 = rect(c)
      if x0 < u.boite[1][1] - 1e-3 or y0 < u.boite[1][2] - 1e-3 or x1 > u.boite[2][1] + 1e-3 or y1 > u.boite[2][2] + 1e-3 then
        bon = false; ecarts[#ecarts + 1] = k .. " : hors de la boîte de dessin"
      end
    end
  end
  check(bon and u.main and u.shadow and u.glow, "§2 " .. nom .. " : couches principale, ombre, lueur ; normale = hr / 2, même shift, "
    .. "8 192 px, boîte de dessin", #ecarts > 0 and table.concat(ecarts, " ; ") or nil)
  if att.mobile then
    local m, g = u.mobile, u.mobile_glow
    local sync = m and g and m.images == g.images and m.hr.width == g.hr.width and m.hr.height == g.hr.height
      and m.hr.shift[1] == g.hr.shift[1] and m.hr.shift[2] == g.hr.shift[2]
    check(sync and m.images >= 8 and m.hr.width % 2 == 0 and m.hr.height % 2 == 0,
      "§2 " .. nom .. " : rangée d'images de la pièce mobile et sa lueur synchronisées (même nombre, taille, shift), côtés pairs",
      m and string.format("%d images de %dx%d", m.images, m.hr.width, m.hr.height) or "absente")
  else
    check(u.mobile == nil, "§2 " .. nom .. " : image fixe (aucune rangée d'images)")
  end
  check((u.lumiere ~= nil) == (att.lumiere == true), "§2 " .. nom .. " : flaque de lumière " .. (att.lumiere and "présente" or "absente"))
  check(u.icone and u.icone.icon_size == 64 and u.icone.icon_mipmaps == 4 and u.map_color and #u.map_color == 3,
    "§2 " .. nom .. " : icône 64 px à 4 mipmaps, couleur de carte")
  if att.chaleur then
    check(u.chaleur ~= nil, "§2 " .. nom .. " : état chauffé du collecteur (heat_picture : lueur seule)")
  end
 end
end

-- §3 mutants : sprites.lua faussé, le contrôle doit le refuser (copie de travail en mémoire, rien d'écrit)
local function refuse(mutate, quoi)
  local saved = {}
  local real_dofile = dofile
  local spr = real_dofile(Sheets.DIR .. "/sprites.lua")
  mutate(spr)
  _G.dofile = function(p)
    if p:match("da/energie/sprites%.lua$") then return spr end
    return real_dofile(p)
  end
  local rr = Sheets.check(".")
  _G.dofile = real_dofile
  check(not Sheets.ok(rr), "§3 mutant refusé : " .. quoi, #rr.ecarts .. " écart(s)")
  return saved
end
refuse(function(s) s.piscine.main.hr.width = s.piscine.main.hr.width + 2 end, "largeur fausse de la couche principale")
refuse(function(s) s.depot.glow.hr.filename = s.depot.glow.hr.filename:gsub("glow", "glaw") end, "image absente du manifeste")
refuse(function(s) s.reso.mobile.images = s.reso.mobile.images + 1 end, "rangée d'images désynchronisée")
refuse(function(s) s.reso = nil end, "bâtiment absent")
refuse(function(s) s.geo.directions.west = nil end, "direction absente (capteur orientable)")

print(string.format("[DA-ENERGIE] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
