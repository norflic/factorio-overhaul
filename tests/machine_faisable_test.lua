--[[
  Décision du lead (5/11, 21 h 20, point (a)) : le choix de la machine des modules de la capitalisation écarte une machine dont une
  matière brute FABRIQUÉE (pas naturelle, que la main ne fait pas) n'est ni au stock ni produite (Ca.buildable,
  shared/ai3/capitalisation.lua ; runtime : Capi.usable_of et fit_module, script/ai3/capitalisation.lua).
  État de la minute 100 de la partie du DC (fo-logs/2026-11-05_PARTIE-DC-ESSAI/factorio-current-2032.log, votre équipe) :
    - MESURÉ : stock iron-plate 13 125, copper-plate 2 805 ([FO-CAPI-EMPLACEMENTS] à 99,9 min) ; les modules prenaient
      l'assembling-machine-2 (2 plaques d'acier, tests/fixtures/recipes.lua:12) et l'attendaient jusqu'au refus ;
    - HYPOTHÈSE du test : AUCUN acier, ni au stock ni produit. Le « 0 » des fenêtres [FO-IA3E] est un artefact (ce D ne compte pas
      les fours du QG ; un four d'acier a été payé à 53,5 min) : le débit réel d'acier N'EST PAS mesuré, et l'effet de la règle sur la
      partie du DC n'est PAS établi. Le test prouve la règle sous cette hypothèse, pas l'effet en jeu.
    §1 la règle pure (Ca.buildable) ;
    §2 le choix de la machine (A.pick_machine, A.method_for) : AM2 avant, AM1 après ; rouge avec l'ancien « utilisable » ;
    §3 le runtime au moteur simulé : Capi.usable_of et Capi.made_of, avec le livre de la force ;
    §4 mutants ;
    §5 (a)-mall (décision du lead, 5/11 au soir) : un BLOC du mall (Id.decide, shared/ai3/industrie.lua) passe par la MÊME règle
       (Ca.module_usable, Ca.made_of). MESURÉ dans la partie du DC : les 7 blocs du mall de votre équipe ont pris l'AM2 ([FO-IA1D]
       « bloc-assembling-machine-2-N », projets 5, 15, 25, 31, 40, 48, 58) ; 15, 25, 31, 40 et 48 ont été annulés « materiaux
       introuvables (15 min sans progres) » ; à 157,9 min, « bloc [submachine-gun] attend : … (manque steel-plate 2) ». Le bloc du
       test est celui du projet 40 ([burner-mining-drill, submachine-gun, transport-belt], 118,9 min). Même HYPOTHÈSE d'acier ;
       le câblage de script/ai3/industrie.lua est contrôlé par sa STRUCTURE, avec 3 mutants de texte.
  Lancement : lua5.2 tests/machine_faisable_test.lua (depuis la racine du mod ; quelques secondes).
]]
package.path = "./?.lua;" .. package.path
local Ca = require("shared.ai3.capitalisation")
local A = require("shared.ai3.automatiser")
local Book = require("shared.team.book")
local Id = require("shared.ai3.industrie")
local L = require("shared.ai3.lecture")
local F = require("tests.iag_fixture")

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
end
local function section(name) if not quiet then print("== " .. name) end end

local B = Book.new(dofile("tests/fixtures/recipes.lua"))
local STOCK = { ["iron-plate"] = 13125, ["copper-plate"] = 2805 }
local MADE = { ["iron-plate"] = 1219, ["copper-plate"] = 470 }
local function with(t, k, v) local c = {} for a, b in pairs(t) do c[a] = b end c[k] = v return c end
-- l'« utilisable » d'avant (handcraftable ou au stock) et celui du point (a) (même forme que Capi.usable_of)
local function usable_old(stock) return function(n) return B:handcraftable(n) or (stock[n] or 0) > 0 end end
-- (a)-mall : la règle partagée (Ca.module_usable) ; elle appelle Ca.buildable par la table, les mutants de §4 la touchent donc aussi
local function usable_new(stock, made) return Ca.module_usable(B, stock, made) end
-- relevé du mall (lecture du jeu de données de tests/iag_fixture.lua, emprises 3 x 3 : seule la machine choisie compte ici)
local MD = F.dump()
for _, e in ipairs(MD.entities) do
  if e.type == "assembling-machine" or e.type == "furnace" then e.w, e.h, e.boxes = 3, 3, {} end
end
local MFAB = L.read(MD, {})
-- livre de la minute 100 : l'AM3 n'est pas recherchée (les blocs de la partie prenaient l'AM2)
local MB = Book.new(MD.recipes, { allowed = function(n) return n ~= "assembling-machine-3" end })
local BLOC40 = { "burner-mining-drill", "submachine-gun", "transport-belt" }
local function mall_bloc(usable)
  local src = {}
  for _, it in ipairs(BLOC40) do src[#src + 1] = { item = it, rate = 0.5, src = "refus" } end
  local out = Id.decide({}, { tick = 200000, sources = { src }, fab = MFAB, usable = usable, bloc_max = 8 })
  local b = out.blocs[1]
  return b and b.machine, b and table.concat(b.items, ","), #out.blocs
end
local function machine_of(m)
  if not m then return nil end
  if m.patron then return m.args[1] end
  return m.args and m.args[3]
end

local function suite()
  section("§1 règle pure : Ca.buildable (minute 100 : 0 acier, ni au stock ni produit)")
  local ok2, r2 = Ca.buildable("assembling-machine-2", B, STOCK, MADE)
  check(ok2 == false and r2 == "steel-plate", "AM2 : pas faisable, il manque l'acier (" .. tostring(r2) .. ")")
  check(Ca.buildable("assembling-machine-1", B, STOCK, MADE) == true, "AM1 : faisable (fer et cuivre au stock)")
  check(Ca.buildable("medium-electric-pole", B, STOCK, MADE) == false, "poteau moyen : pas faisable (acier) ; les 19 de stone-wall")
  check(Ca.buildable("assembling-machine-2", B, with(STOCK, "steel-plate", 2), MADE) == true, "2 aciers au stock : une AM2 se fait")
  check(Ca.buildable("assembling-machine-2", B, with(STOCK, "steel-plate", 1), MADE) == false, "1 seul acier : pas assez pour une AM2")
  check(Ca.buildable("assembling-machine-2", B, STOCK, with(MADE, "steel-plate", 3)) == true, "acier PRODUIT au dernier relevé : faisable")
  check(Ca.buildable("stone-furnace", B, {}, {}) == true, "matière NATURELLE (pierre) : jamais un refus, les PNJ la récoltent")
  check(Ca.buildable("iron-chest", B, {}, {}) == false, "fer ni au stock ni produit : le coffre de fer ne se fait pas")
  check(Ca.buildable("iron-chest", B, {}, { ["iron-plate"] = 1 }) == true, "fer produit : il se fait")
  check(Ca.buildable("assembling-machine-2", nil, STOCK, MADE) == true, "sans livre : vrai, comme avant")
  check(Ca.buildable("steel-plate", B, {}, {}) == true, "un objet hors de la main n'est pas jugé ici (l'utilisable le refuse déjà)")

  section("§2 choix de la machine (minute 100) : AM2 avant, AM1 après")
  check(A.pick_machine({ "crafting" }, usable_old(STOCK)) == "assembling-machine-2", "AVANT : l'AM2 est choisie (rouge, ce que montre la partie)")
  check(A.pick_machine({ "crafting" }, usable_new(STOCK, MADE)) == "assembling-machine-1", "APRÈS : l'AM1 est choisie")
  for _, it in ipairs({ "grenade", "iron-stick", "pistol", "copper-cable" }) do
    local m0 = A.method_for(it, B, usable_old(STOCK))
    local m1 = A.method_for(it, B, usable_new(STOCK, MADE))
    check(machine_of(m0) == "assembling-machine-2" and machine_of(m1) == "assembling-machine-1",
      it .. " (module de la partie) : " .. tostring(machine_of(m0)) .. " avant, " .. tostring(machine_of(m1)) .. " après")
  end
  check(A.pick_machine({ "crafting" }, usable_new(with(STOCK, "steel-plate", 50), MADE)) == "assembling-machine-2",
    "l'acier revient au stock : l'AM2 revient")
  check(A.pick_machine({ "crafting" }, usable_new(with(STOCK, "assembling-machine-2", 4), MADE)) == "assembling-machine-2",
    "des AM2 déjà au coffre : utilisables, même sans acier")

  section("§5 (a)-mall : bloc du projet 40 de la partie (Id.decide) : AM2 avant, AM1 après")
  local old_m = function(n) return MB:handcraftable(n) or (STOCK[n] or 0) > 0 end
  local m0, items0, n0 = mall_bloc(old_m)
  check(m0 == "assembling-machine-2" and items0 == table.concat(BLOC40, ","),
    "AVANT : le bloc [" .. tostring(items0) .. "] prend l'AM2 (" .. tostring(m0) .. ", " .. tostring(n0) .. " bloc(s)), comme le projet 40")
  local m1, items1 = mall_bloc(Ca.module_usable(MB, STOCK, MADE))
  check(m1 == "assembling-machine-1" and items1 == table.concat(BLOC40, ","),
    "APRÈS : le même bloc prend l'AM1 (" .. tostring(m1) .. ")")
  local pr = Id.profile(MFAB, "submachine-gun", Ca.module_usable(MB, STOCK, MADE))
  check(pr and pr.machine.entity == "assembling-machine-1", "cellule seule [submachine-gun] (« manque steel-plate 2 » à 157,9 min) : AM1")
  check(mall_bloc(Ca.module_usable(MB, with(STOCK, "steel-plate", 10), MADE)) == "assembling-machine-2", "acier au stock : le bloc reprend l'AM2")
  local FL = { ["steel-plate"] = { made = 3, hand = 0 }, ["iron-plate"] = { made = 10, hand = 2 } }
  check(mall_bloc(Ca.module_usable(MB, STOCK, Ca.made_of(FL))) == "assembling-machine-2",
    "faction : acier produit (statistiques de sa force) : l'AM2")
  check(mall_bloc(Ca.module_usable(MB, STOCK, Ca.made_of(FL, true))) == "assembling-machine-1",
    "votre équipe : l'acier de la force « player » (usine du DC) ne compte pas, la main seulement : l'AM1")
  local mp = Ca.made_of(FL, true)
  check(mp["steel-plate"] == 0 and mp["iron-plate"] == 2 and Ca.made_of(FL)["steel-plate"] == 3 and next(Ca.made_of(nil)) == nil,
    "Ca.made_of : main seule pour votre équipe, statistiques pour une faction, vide sans relevé")
end

suite()
local base_fail = failures

section("§5 bis câblage de script/ai3/industrie.lua (structure) et de script/ai3/capitalisation.lua (délégation)")
local function read_file(path)
  local fh = assert(io.open(path, "rb"))
  local t = fh:read("*a")
  fh:close()
  return t
end
local function plain_count(src, pat)
  local n, i = 0, 1
  while true do
    local a, b = src:find(pat, i, true)
    if not a then return n end
    n, i = n + 1, b + 1
  end
end
-- vrai si la décision, le kit et la rangée de banc passent tous par Ca.module_usable, et plus aucun « utilisable » ancien (main ou coffre)
local function mall_wired(src)
  return plain_count(src, "local usable = Ca.module_usable(book, stock, Ca.made_of(cs.flows, f.is_player))") == 1
    and plain_count(src, "    usable = usable,\n") == 1
    and plain_count(src, "prepare(f, lec, book, view, dec, kind == \"bloc\" and \"bloc\" or \"cellule\", usable)") == 1
    and plain_count(src, "local function prepare(f, lec, book, view, dec, kind, usable)") == 1
    and plain_count(src, "Ca.module_usable(book, contents, Ca.made_of(cs and cs.flows, f.is_player))") == 1
    and plain_count(src, "handcraftable(n) or") == 0
end
local IND = read_file("script/ai3/industrie.lua")
check(mall_wired(IND), "industrie.lua : décision (Id.decide), kit (prepare) et rangée de banc par Ca.module_usable, aucun ancien « utilisable »")
local CAPI = read_file("script/ai3/capitalisation.lua")
check(plain_count(CAPI, "Capi.usable_of = Ca.module_usable") == 1 and plain_count(CAPI, "return Ca.made_of(cs and cs.flows, player)") == 1
  and plain_count(CAPI, "handcraftable(n) or") == 0, "capitalisation.lua : Capi.usable_of et Capi.made_of délèguent à la règle partagée (pas de copie)")
local text_killed = 0
local TEXT_MUT = {
  { "décision du mall : ancien utilisable", "    usable = usable,\n", "    usable = function(n) return book:handcraftable(n) or (stock[n] or 0) > 0 end,\n" },
  { "kit du patron sans la règle", "\"cellule\", usable)", "\"cellule\")" },
  { "rangée de banc : ancien utilisable", "Ca.module_usable(book, contents, Ca.made_of(cs and cs.flows, f.is_player))",
    "function(n) return book:handcraftable(n) or (contents[n] or 0) > 0 end" },
}
for _, m in ipairs(TEXT_MUT) do
  local a, b = IND:find(m[2], 1, true)
  local mutated = a and (IND:sub(1, a - 1) .. m[3] .. IND:sub(b + 1)) or IND
  if a and not mall_wired(mutated) then text_killed = text_killed + 1 else print("  MUTANT DE TEXTE SURVIVANT : " .. m[1]) end
end
check(text_killed == #TEXT_MUT, string.format("mutants de texte du câblage : %d / %d refusés", text_killed, #TEXT_MUT))

section("§3 runtime au moteur simulé : Capi.usable_of, Capi.made_of (livre de la force)")
do
  local M = require("tests.mock_engine")
  M.new_world({ difficulty = "peaceful", ia3e = true, capi = true })
  M.load_mod()
  M.dispatch(M.world().on_init)
  M.command("fo-war", "start 2 30 30 320")
  M.run_ticks(600)
  local f = global.fo.war.factions[1]
  local Capi = require("script.ai3.capitalisation")
  local force = game.forces[f.force]
  local fb = Book.from_game(game.recipe_prototypes, { allowed = function(name)
    local r = force and force.recipes and force.recipes[name]
    return r ~= nil and r.enabled
  end })
  local u = Capi.usable_of(fb, STOCK, MADE)
  if fb:handcraftable("assembling-machine-2") then
    check(u("assembling-machine-2") == false and u("assembling-machine-1") == true, "Capi.usable_of : AM2 écartée sans acier, AM1 gardée")
    check(A.pick_machine({ "crafting" }, u) == "assembling-machine-1", "Capi.usable_of au choix de la machine : AM1")
  else
    print("  (livre de la force du moteur simulé : AM2 pas encore ouverte ; contrôle sur un livre complet)")
    local u2 = Capi.usable_of(Book.from_game(game.recipe_prototypes), STOCK, MADE)
    check(u2("assembling-machine-2") == false and u2("assembling-machine-1") == true, "Capi.usable_of (livre complet) : AM2 écartée, AM1 gardée")
  end
  check(Capi.usable_of(fb, with(STOCK, "assembling-machine-2", 1), MADE)("assembling-machine-2") == true, "Capi.usable_of : au coffre, utilisable")
  local fl = { flows = { ["steel-plate"] = { made = 4 }, ["iron-plate"] = { made = 10, hand = 2 } } }
  local made = Capi.made_of(fl)
  check(made["steel-plate"] == 4 and made["iron-plate"] == 10, "Capi.made_of (faction) lit cs.flows, statistiques de la force")
  local mp = Capi.made_of(fl, true)
  check(mp["steel-plate"] == 0 and mp["iron-plate"] == 2,
    "Capi.made_of (votre équipe) : la main seulement, jamais les statistiques de la force player (usine du DC humain)")
  local fb2 = Book.from_game(game.recipe_prototypes)
  local st0 = with(STOCK, "steel-plate", 0)
  check(Capi.usable_of(fb2, st0, Capi.made_of(fl))("assembling-machine-2") == true
    and Capi.usable_of(fb2, st0, Capi.made_of(fl, true))("assembling-machine-2") == false,
    "acier fondu par le DC (statistiques de la force player) : AM2 utilisable pour une faction, PAS pour votre équipe")
  check(next(Capi.made_of({})) == nil and next(Capi.made_of(nil)) == nil, "Capi.made_of sans relevé : vide")
end

-- §4 mutants de la règle pure (chacun doit faire échouer §1 ou §2)
local saved = {}
local function patch(t, k, v) saved[#saved + 1] = { t, k, t[k] } t[k] = v end
local function unpatch() for i = #saved, 1, -1 do saved[i][1][saved[i][2]] = saved[i][3] saved[i] = nil end end
local killed, total = 0, 0
local function mutant(name, apply)
  total = total + 1
  local p0, f0 = passes, failures
  apply()
  quiet = true
  local ok = pcall(suite)
  quiet = false
  unpatch()
  local caught = (failures > f0) or not ok
  passes, failures = p0, f0
  if caught then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. name) end
end
local real = Ca.buildable
mutant("toujours faisable (avant)", function() patch(Ca, "buildable", function() return true end) end)
mutant("stock ignoré", function() patch(Ca, "buildable", function(i, b, s, m) return real(i, b, {}, m) end) end)
mutant("production ignorée", function() patch(Ca, "buildable", function(i, b, s, m) return real(i, b, s, {}) end) end)
mutant("matières naturelles comptées", function()
  patch(Ca, "buildable", function(i, b, s, m)
    if not b then return true end
    local raw = b:plan({ { i, 1 } }, s or {}).raw
    for k, n in pairs(raw) do if k ~= i and n > 0 and ((m or {})[k] or 0) <= 0 then return false, k end end
    return true
  end)
end)
mutant("(a)-mall : Ca.module_usable ancien (main ou coffre)", function()
  patch(Ca, "module_usable", function(b, s) return function(n) return b:handcraftable(n) or ((s or {})[n] or 0) > 0 end end)
end)
mutant("(a)-mall : Ca.made_of lit les statistiques de la force pour votre équipe", function()
  local real_made = Ca.made_of
  patch(Ca, "made_of", function(fl) return real_made(fl, false) end)
end)
mutant("plaques seules (fer et cuivre)", function()
  patch(Ca, "buildable", function(i, b, s, m)
    if not b then return true end
    local raw = b:plan({ { i, 1 } }, s or {}).raw
    for _, k in ipairs({ "iron-plate", "copper-plate" }) do if (raw[k] or 0) > 0 and ((m or {})[k] or 0) <= 0 then return false, k end end
    return true
  end)
end)
print(string.format("[MACHINE-FAISABLE] MUTANTS : %d / %d refusés", killed, total))
print(string.format("[MACHINE-FAISABLE] BILAN : %d OK, %d ECHEC(S)%s", passes, failures + (total - killed),
  base_fail > 0 and " (suite de base en échec)" or ""))
os.exit((failures == 0 and killed == total) and 0 or 1)
