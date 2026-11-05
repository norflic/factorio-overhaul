--[[
  Tests hors jeu du lot CHAMP-COUVERTURE, R7 et R5a / R5c (règles pures) :
    shared/team/champ_voisins.lua  un gisement, un champ (avant-postes posés sur le même gisement, à toute distance) ;
    shared/team/champ_rythme.lua   porte des plaques d'un agrandissement (part bâtie, prorata des foreuses posées).
  L'exécutant (script/team/migration_champ.lua) est contrôlé sous moteur simulé : tests/migration_champ_test.lua, sections CC1 et CC2.
  Usage, depuis la racine du mod :   lua5.2 tests/champ_rythme_test.lua
]]
package.path = "./?.lua;" .. package.path

local V = require("shared.team.champ_voisins")
local Ry = require("shared.team.champ_rythme")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

--- Gisement allongé de 140 x 20 tuiles (deux avant-postes à 90 tuiles l'un de l'autre y tiennent).
local function long_deposit()
  local o = {}
  for x = 0, 139 do for y = -10, 9 do o[#o + 1] = x; o[#o + 1] = y end end
  return o
end

local function battery()
  local r = {}
  local ore = long_deposit()
  -- 1. un gisement, un champ
  local got = V.on_deposit(ore, {
    { id = 14, tiles = { 100.5, 0.5 } },                   -- position sur le gisement, à 90 tuiles du premier
    { id = 7, tiles = { 300, 300, 120, 5 } },              -- position ailleurs, une paire sur le gisement
    { id = 3, tiles = { 300, 300, 301, 300 } },            -- ni position ni paire sur le gisement
    { id = 9, tiles = { 140, 0 } },                        -- juste au-delà du bord est (x = 140 n'est pas du minerai)
    { id = 2, tiles = { -0.5, -10.5 } },                   -- (-0,5 ; -10,5) : tuile (-1, -11), hors du gisement
  })
  r.deposit = #got == 2 and got[1] == 7 and got[2] == 14
  r.sorted = #got < 2 or got[1] < got[2]
  r.empty = #V.on_deposit({}, { { id = 1, tiles = { 0, 0 } } }) == 0
  -- 2. part bâtie (R5c : prorata des foreuses posées)
  r.share0 = Ry.share({}, 5) == 0
  r.share80 = math.abs(Ry.share({ { planned = 10, built = 10 }, { planned = 10, built = 10 }, { planned = 10, built = 10 }, { planned = 10, built = 10 } }, 5) - 0.8) < 1e-9
  r.share_empty_bands = Ry.share({ { planned = 10, built = 0 }, { planned = 10, built = 0 } }, 2) == 0
  r.share_prorata = math.abs(Ry.share({ { planned = 10, built = 10 }, { planned = 10, built = 5 } }, 4) - 0.375) < 1e-9
  r.share_cancelled = Ry.share({ { planned = 0, built = 0 } }, 1) == 0
  r.share_no_frame = Ry.share({}, 0) == 1
  r.share_cap = Ry.share({ { planned = 4, built = 9 } }, 1) == 1
  -- 3. porte des plaques (R5a)
  r.gate_rich_empty = Ry.ext_wait({ under = 0, free = 20000, wanted = false, share = 0 }) == false
  r.gate_rich_built = Ry.ext_wait({ under = 0, free = 20000, wanted = false, share = 0.8 }) == true
  r.gate_poor = Ry.ext_wait({ under = 0, free = 2999, wanted = false, share = 1 }) == false
  r.gate_pairs = Ry.ext_wait({ under = 3, free = 20000, wanted = false, share = 1 }) == false
  r.gate_wanted = Ry.ext_wait({ under = 0, free = 20000, wanted = true, share = 1 }) == false
  r.gate_79 = Ry.ext_wait({ under = 0, free = 3000, wanted = false, share = 0.79 }) == false
  return r
end

local NAMES = {
  deposit = "R7 : avant-postes posés sur le gisement (position ou paire), à toute distance ; les autres non",
  sorted = "R7 : numéros triés", empty = "R7 : gisement vide, aucun voisin",
  share0 = "R5c : aucune bande demandée : part 0", share80 = "R5c : 4 bandes pleines sur 5 : part 0,8",
  share_empty_bands = "R5c : bandes finies sans leurs foreuses : part 0", share_prorata = "R5c : prorata (10/10 + 5/10) sur 4 : 0,375",
  share_cancelled = "R5c : bande annulée (sans pièces) : 0", share_no_frame = "R5c : cadre sans bande : 1 (rien à bâtir)",
  share_cap = "R5c : une bande compte au plus 1",
  gate_rich_empty = "R5a : 20 000 plaques, champ vide : l'agrandissement part", gate_rich_built = "R5a : 20 000 plaques, champ bâti à 80 % : il attend",
  gate_poor = "R5a : 2 999 plaques : il part", gate_pairs = "R5a : bande à paires : jamais retenue par la porte",
  gate_wanted = "R5a : voulue par la capitalisation : jamais retenue", gate_79 = "R5a : 79 % bâti : il part",
}
local ORDER = { "deposit", "sorted", "empty", "share0", "share80", "share_empty_bands", "share_prorata", "share_cancelled", "share_no_frame",
  "share_cap", "gate_rich_empty", "gate_rich_built", "gate_poor", "gate_pairs", "gate_wanted", "gate_79" }

section("1. regles")
local r = battery()
for _, k in ipairs(ORDER) do check(r[k], NAMES[k]) end

section("2. mutants")
local muts = {
  { "porte des plaques seule (ancienne regle : part ignoree)", function()
      local o = Ry.ext_wait
      Ry.ext_wait = function(c) if (c.under or 0) > 0 or c.wanted then return false end return (c.free or 0) >= Ry.CFG.plates end
      return function() Ry.ext_wait = o end end },
  { "foreuses prevues comptees pour posees", function()
      local o = Ry.share
      Ry.share = function(bands, total) local b2 = {}; for i, b in ipairs(bands) do b2[i] = { planned = b.planned, built = b.planned } end; return o(b2, total) end
      return function() Ry.share = o end end },
  { "bandes jamais demandees ignorees (part sur les seules bandes demandees)", function()
      local o = Ry.share
      Ry.share = function(bands, total) return o(bands, math.max(1, #bands)) end
      return function() Ry.share = o end end },
  { "voisins par la seule position", function()
      local o = V.on_deposit
      V.on_deposit = function(ore, cands) local c2 = {}; for i, c in ipairs(cands) do c2[i] = { id = c.id, tiles = { c.tiles[1], c.tiles[2] } } end; return o(ore, c2) end
      return function() V.on_deposit = o end end },
  { "seuil a 100 %", function()
      local o = Ry.CFG.share; Ry.CFG.share = 1
      return function() Ry.CFG.share = o end end },
}
for _, m in ipairs(muts) do
  local undo = m[2]()
  local mr = battery()
  undo()
  local seen = false
  for _, k in ipairs(ORDER) do if not mr[k] then seen = true end end
  check(seen, "mutant vu : " .. m[1])
end

print(string.format("[CHAMP-RYTHME] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
