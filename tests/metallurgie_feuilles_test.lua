-- Lot DA-METALLURGIE (4/11) : feuilles de la métallurgie (D-6) et branchement des prototypes, hors jeu.
--   lua5.2 tests/metallurgie_feuilles_test.lua      (depuis la racine du mod ; les PNG doivent avoir été régénérés)
-- §1 manifeste et sprites.lua (tests/datastage/metallurgie_sheets.lua) ; §2 prototypes/metallurgie_machines.lua sur un faux
-- data.raw (copies vanilla teintées comme les font titanium, crafts et bauxite) : couches dédiées sans teinte, ombre, lueur
-- additive, boîtes de collision intactes, fumée des seules machines à combustible, icônes dédiées (entité, objet, recette
-- variante), poteau à 4 directions et 4 points de fil ; §3 mutants : chaque contrôle refuse une copie volontairement fausse.

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 else fail_n = fail_n + 1; print("ECHEC " .. msg) end
end

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[deepcopy(k)] = deepcopy(v) end
  return r
end

-- §1 ------------------------------------------------------------------------------------------------ feuilles
local Sheets = dofile("tests/datastage/metallurgie_sheets.lua")
local rs = Sheets.check(".")
if not Sheets.ok(rs) then for _, l in ipairs(Sheets.lines(rs)) do print(l) end end
check(Sheets.ok(rs) and rs.n > 0, string.format("§1 feuilles de graphics/metallurgie (%d PNG au manifeste, %d images relues)", rs.n, rs.refs or 0))
local SPR = rs.spr or {}

-- §2 ------------------------------------------------------------------------------------------------ prototypes
package.preload["__factorio-overhaul__/graphics/metallurgie/sprites"] = function() return dofile("graphics/metallurgie/sprites.lua") end

local MACHINES = { "fo-blast-furnace", "fo-coke-oven", "fo-kroll-reactor", "fo-ore-concentrator" }
local BURNER = { ["fo-blast-furnace"] = true, ["fo-coke-oven"] = true }
-- côtés des emprises (shared/content/epochs.lua) ; boîte de collision du mod : côté / 2 − 0,3
local COTE = { ["fo-blast-furnace"] = 4, ["fo-coke-oven"] = 3, ["fo-kroll-reactor"] = 4, ["fo-ore-concentrator"] = 2 }
local TINT = { r = 0.8, g = 0.6, b = 0.5 }

local function faux_data()
  local raw = { ["assembling-machine"] = {}, ["electric-pole"] = {}, item = {}, recipe = {} }
  for _, n in ipairs(MACHINES) do
    raw["assembling-machine"][n] = {
      type = "assembling-machine", name = n, collision_box = { { -COTE[n] / 2 + 0.3, -COTE[n] / 2 + 0.3 }, { COTE[n] / 2 - 0.3, COTE[n] / 2 - 0.3 } },
      animation = { layers = { { filename = "__base__/graphics/entity/assembling-machine-1/assembling-machine-1.png", tint = TINT } } },
      idle_animation = { filename = "__base__/x.png" }, integration_patch = { filename = "__base__/y.png" },
      energy_source = BURNER[n] and { type = "burner", fuel_category = "chemical" } or { type = "electric" },
      icons = { { icon = "__base__/graphics/icons/assembling-machine-1.png", icon_size = 64, tint = TINT } },
    }
    raw.item[n] = { type = "item", name = n, icons = { { icon = "__base__/graphics/icons/assembling-machine-1.png", tint = TINT } } }
  end
  raw["electric-pole"]["fo-ht-pylon"] = {
    type = "electric-pole", name = "fo-ht-pylon", collision_box = { { -0.65, -0.65 }, { 0.65, 0.65 } },
    pictures = { layers = { { filename = "__base__/graphics/entity/big-electric-pole/big-electric-pole.png", tint = TINT, direction_count = 4 } } },
    connection_points = { {}, {}, {}, {} }, icon = "__base__/graphics/icons/big-electric-pole.png", icon_size = 64,
  }
  raw.item["fo-ht-pylon"] = { type = "item", name = "fo-ht-pylon", icons = { { icon = "__base__/graphics/icons/big-electric-pole.png", tint = TINT } } }
  raw.recipe["fo-ht-pylon-aluminium"] = { type = "recipe", name = "fo-ht-pylon-aluminium",
    icons = { { icon = "__base__/graphics/icons/big-electric-pole.png", tint = TINT }, { icon = "__x__/alu.png", scale = 0.25 } } }
  return { raw = raw }
end

-- Contrôles d'un data.raw habillé (renvoient une liste d'erreurs ; vides = juste)
local function couches_de(e)
  local L = {}
  local function ajoute(s)
    if s.layers then for _, l in ipairs(s.layers) do L[#L + 1] = l end else L[#L + 1] = s end
  end
  if e.animation then ajoute(e.animation) end
  if e.pictures then ajoute(e.pictures) end
  for _, v in ipairs(e.working_visualisations or {}) do if v.animation then ajoute(v.animation) end end
  return L
end

local function controle_entite(e, poteau)
  local err = {}
  local L = couches_de(e)
  local ombre, lueur = false, false
  for _, l in ipairs(L) do
    for _, s in ipairs({ l, l.hr_version or {} }) do
      if s.filename and not s.filename:find("^__factorio%-overhaul__/graphics/metallurgie/") then err[#err + 1] = "couche hors des feuilles" end
      if s.tint then err[#err + 1] = "couche teintée" end
    end
    if not l.hr_version or l.hr_version.scale ~= 0.5 then err[#err + 1] = "sans hr_version à l'échelle 0,5" end
    if l.draw_as_shadow then ombre = true end
    if l.draw_as_glow then
      lueur = true
      if l.blend_mode ~= "additive" or (l.hr_version and l.hr_version.blend_mode ~= "additive") then err[#err + 1] = "lueur non additive" end
    end
    if poteau and (l.direction_count ~= 4 or not l.hr_version or l.hr_version.direction_count ~= 4) then err[#err + 1] = "poteau sans 4 directions" end
  end
  if not ombre then err[#err + 1] = "sans ombre" end
  if not lueur then err[#err + 1] = "sans lueur" end
  if e.idle_animation or e.integration_patch then err[#err + 1] = "visuel vanilla resté (idle, patch)" end
  for _, ic in ipairs(e.icons or {}) do
    if ic.tint or not tostring(ic.icon):find("graphics/metallurgie/") then err[#err + 1] = "icône d'entité non dédiée" end
  end
  local db, cb = e.drawing_box, e.collision_box
  if not db or db[1][1] > cb[1][1] or db[1][2] > cb[1][2] or db[2][1] < cb[2][1] or db[2][2] < cb[2][2] then
    err[#err + 1] = "boîte de dessin qui ne couvre pas la collision"
  end
  if poteau then
    if #e.connection_points ~= 4 then err[#err + 1] = "points de fil ≠ 4" end
    for _, cp in ipairs(e.connection_points) do
      if not (cp.wire and cp.wire.copper and cp.shadow and cp.shadow.copper) or cp.wire.copper[2] > -2 then
        err[#err + 1] = "point de fil absent ou trop bas"
      end
    end
  end
  return err
end

local avant = faux_data()
local cb_avant = {}
for _, n in ipairs(MACHINES) do cb_avant[n] = deepcopy(avant.raw["assembling-machine"][n].collision_box) end
_G.data = avant
local Met = dofile("prototypes/metallurgie_machines.lua")
local n = Met.appliquer()
local raw = _G.data.raw
check(n == 5, "§2 appliquer() habille 5 bâtiments (" .. tostring(n) .. ")")
for _, nom in ipairs(MACHINES) do
  local e = raw["assembling-machine"][nom]
  local err = controle_entite(e, false)
  check(#err == 0, "§2 " .. nom .. " : " .. (#err == 0 and "couches dédiées, ombre, lueur additive, icône, boîte" or table.concat(err, ", ")))
  check(e.collision_box[1][1] == cb_avant[nom][1][1] and e.collision_box[2][2] == cb_avant[nom][2][2], "§2 " .. nom .. " : boîte de collision intacte")
  local fume = e.energy_source.smoke ~= nil
  check(fume == (BURNER[nom] == true), "§2 " .. nom .. " : fumée " .. (BURNER[nom] and "posée (combustible)" or "absente (électrique)"))
  local it = raw.item[nom]
  check(it.icons and it.icons[1].icon:find("graphics/metallurgie/") and not it.icons[1].tint, "§2 " .. nom .. " : icône d'objet dédiée")
end
local py = raw["electric-pole"]["fo-ht-pylon"]
local errp = controle_entite(py, true)
check(#errp == 0, "§2 fo-ht-pylon : " .. (#errp == 0 and "4 directions, 4 points de fil, lueur des feux, icône" or table.concat(errp, ", ")))
local rv = raw.recipe["fo-ht-pylon-aluminium"]
check(rv.icons[1].icon:find("graphics/metallurgie/") and rv.icons[2].icon == "__x__/alu.png", "§2 recette variante : icône du pylône remplacée, marque gardée")
-- points de fil : direction 2 (traverse nord-sud) : rouge au sud, vert au nord (grand poteau vanilla)
local cp2 = py.connection_points[3]
check(cp2.wire.red[2] > cp2.wire.green[2], "§2 direction 2 : fil rouge au sud du vert, comme le grand poteau vanilla")

-- §3 ------------------------------------------------------------------------------------------------ mutants
local function mutant(nom, f, poteau)
  local e = deepcopy(poteau and py or raw["assembling-machine"]["fo-blast-furnace"])
  f(e)
  local err = controle_entite(e, poteau)
  check(#err > 0, "§3 mutant refusé : " .. nom)
end
mutant("couche principale teintée", function(e) e.animation.layers[1].tint = TINT end)
mutant("lueur sans blend additive", function(e) e.working_visualisations[1].animation.blend_mode = nil end)
mutant("sans ombre", function(e) table.remove(e.animation.layers, 2) end)
mutant("copie vanilla restée", function(e) e.animation.layers[1].filename = "__base__/graphics/entity/steel-furnace/steel-furnace.png" end)
mutant("idle vanilla resté", function(e) e.idle_animation = { filename = "__base__/x.png" } end)
mutant("icône teintée", function(e) e.icons[1].tint = TINT end)
mutant("boîte de dessin trop petite", function(e) e.drawing_box = { { -0.5, -0.5 }, { 0.5, 0.5 } } end)
mutant("poteau à 3 points de fil", function(e) e.connection_points[4] = nil end, true)
mutant("poteau à 1 direction", function(e) e.pictures.layers[1].direction_count = 1 end, true)

print(string.format("[METAL-FEUILLES] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
