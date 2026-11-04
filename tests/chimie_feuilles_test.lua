-- Banc hors jeu du lot DA-CHIMIE (4/11) : feuilles des 4 machines de chimie à fluides (graphics/machines/chimie, D-6) et leur
-- accord avec les prototypes.
--   lua5.2 tests/chimie_feuilles_test.lua      (depuis la racine du mod ; PNG régénérés par tools/render/pieces/chimie/feuilles.py)
-- Contrôles :
--   1. manifeste et sprites.lua (tests/datastage/chimie_sheets.lua) : fichiers présents, tailles, dimensions ;
--   2. chaque machine a ses 4 directions, chacune avec principale, ombre et lueur ; halo de nuit du vapocraqueur seul ;
--   3. normale = moitié arrondie au-dessus de la hr ; shift sur la grille de 1/64 de tuile ; 8 192 px au plus (F144) ;
--   4. les boîtes de fluide des prototypes (shared/content : fluid_in au nord, fluid_out au sud) sont CELLES dont les brides
--      sont rendues (RENDU ci-dessous = tools/render/pieces/chimie/m_*.py) ; un changement de fluid_in/fluid_out sans
--      nouveau rendu est refusé ;
--   5. mutants : une direction ôtée, une couche d'ombre ôtée, une boîte de fluide ajoutée sont refusés.
package.path = "./?.lua;" .. package.path

local Sheets = dofile("tests/datastage/chimie_sheets.lua")
local T = require("shared.content.titanium")

local ok, ko = 0, 0
local function check(c, msg)
  if c then ok = ok + 1 else ko = ko + 1; print("ECHEC " .. msg) end
end

-- Brides rendues par le kit (entrées au nord, sorties au sud, colonnes x de la machine posée « nord »)
local RENDU = {
  ["fo-steam-cracker"] = { "craqueur", 2, 1 },
  ["fo-reformer"] = { "reformeur", 2, 2 },
  ["fo-electrolyzer"] = { "electrolyseur", 1, 2 },
  ["fo-extraction-column"] = { "colonne", 1, 0 },
}

-- 1. manifeste
local r = Sheets.check(".")
for _, l in ipairs(Sheets.lines(r)) do print(l) end
check(Sheets.ok(r), "manifeste et sprites.lua des feuilles de chimie")

local spr = dofile(Sheets.DIR .. "/sprites.lua")

local function structure(s)
  local fautes = {}
  for _, nom in ipairs(Sheets.MACHINES) do
    local m = s.machines[nom]
    if not m then
      fautes[#fautes + 1] = nom .. " absente"
    else
      for _, d in ipairs(Sheets.DIRS) do
        local c = m[d]
        if not (c and c.main and c.shadow and c.glow) then
          fautes[#fautes + 1] = nom .. " " .. d .. " : principale, ombre ou lueur absente"
        else
          for _, k in ipairs(Sheets.KINDS) do
            local l = c[k]
            if l then
              if l.lr.width ~= math.floor((l.hr.width + 1) / 2) or l.lr.height ~= math.floor((l.hr.height + 1) / 2) then
                fautes[#fautes + 1] = string.format("%s %s %s : normale %dx%d pour hr %dx%d", nom, d, k, l.lr.width,
                  l.lr.height, l.hr.width, l.hr.height)
              end
              for _, v in ipairs(l.hr.shift) do
                if math.abs(v * 64 - math.floor(v * 64 + 0.5)) > 1e-6 then
                  fautes[#fautes + 1] = string.format("%s %s %s : shift %.6f hors grille 1/64", nom, d, k, v)
                end
              end
              if l.hr.width > 8192 or l.hr.height > 8192 then fautes[#fautes + 1] = nom .. " " .. d .. " " .. k .. " > 8192 px" end
            end
          end
          if (c.light ~= nil) ~= (nom == "craqueur") then
            fautes[#fautes + 1] = nom .. " " .. d .. " : halo de nuit " .. (c.light and "inattendu" or "absent")
          end
        end
      end
    end
  end
  return fautes
end

-- 2 et 3
local f = structure(spr)
for _, x in ipairs(f) do print("  " .. x) end
check(#f == 0, "4 machines x 4 directions : couches, normale, grille 1/64, 8 192 px, halo du seul vapocraqueur")

-- 4. boîtes de fluide des prototypes = brides rendues
local function accord(rendu)
  local fautes = {}
  for _, proto in ipairs({ "fo-steam-cracker", "fo-reformer", "fo-electrolyzer", "fo-extraction-column" }) do
    local x = T.x_building(proto)
    local att = rendu[proto]
    if not x then
      fautes[#fautes + 1] = proto .. " : bâtiment X absent"
    elseif (x.fluid_in or 0) ~= att[2] or (x.fluid_out or 0) ~= att[3] or x.size[1] ~= 3 or x.size[2] ~= 3 then
      fautes[#fautes + 1] = string.format("%s : %dx%d, %d entrée(s), %d sortie(s) ; rendu : 3x3, %d, %d", proto, x.size[1],
        x.size[2], x.fluid_in or 0, x.fluid_out or 0, att[2], att[3])
    end
  end
  return fautes
end
f = accord(RENDU)
for _, x in ipairs(f) do print("  " .. x) end
check(#f == 0, "boîtes de fluide des prototypes = brides rendues (entrées nord, sorties sud)")

-- 5. mutants
local function copie(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k, v in pairs(t) do o[k] = copie(v) end
  return o
end
local m1 = copie(spr)
m1.machines.reformeur.w = nil
check(#structure(m1) > 0, "mutant refusé : direction ouest du reformeur ôtée")
local m2 = copie(spr)
m2.machines.colonne.s.shadow = nil
check(#structure(m2) > 0, "mutant refusé : ombre sud de la colonne ôtée")
local m3 = copie(spr)
m3.machines.electrolyseur.n.light = m3.machines.craqueur.n.light
check(#structure(m3) > 0, "mutant refusé : halo de nuit sur l'électrolyseur")
local R2 = copie(RENDU)
R2["fo-electrolyzer"][3] = 1
check(#accord(R2) > 0, "mutant refusé : rendu de l'électrolyseur à une seule sortie")

print(string.format("[CHIMIE-FEUILLES] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
