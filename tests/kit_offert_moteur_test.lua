--[[
  EFFONDREMENT, parade du KIT OFFERT (décision du lead, 7/11 vers 19 h 05 : champ free_kit, au plus 1 pistolet et les chargeurs non
  payés, détruits, jamais rendus au coffre), au MOTEUR SIMULÉ avec le vrai câblage : script/team/worker.lua (Worker.recruit : fiche du
  kit offert ; réarmement : chargeurs payés comptés ; on_entity_died : fiche notée ; on_post_entity_died : kit retiré du corps).
  Le moteur simulé suit le fait moteur du micro-banc kit-cadavre (9ee2b12d) : opts.corpses, le corps reçoit les inventaires AVANT
  on_entity_died, puis on_post_entity_died le rend (tests/mock_engine.lua).
  Cas : PNJ de l'effectif de départ (kit offert) tué avec une cargaison ; recrue PAYÉE tuée ; PNJ au kit offert réarmé de 4 chargeurs
  payés, puis tué ; recrue sans arme ; PNJ renvoyé (sans mort) ; et un témoin sans corps (opts.corpses éteint : rien ne casse).
  Lancement : lua5.2 tests/kit_offert_moteur_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
end

local GUN, AMMO = "pistol", "firearm-magazine"

local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

local function new_team(corpses)
  M.new_game({ patches = patches(), p_busy = 0.01, p_nopath = 0.01, p_lost = 0, corpses = corpses })
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "copper-plate", 500 }, { "coal", 400 }, { AMMO, 194 }, { GUN, 5 } }) do chest.insert({ name = it[1], count = it[2] }) end
  M.world().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  M.run_ticks(60)
  return global.fo.pteam.team, s, chest
end

local function agents_of(f)
  local Registry = require("script.companion.registry")
  local ids = {}
  for id in pairs(f.engineers) do ids[#ids + 1] = id end
  table.sort(ids)
  local out = {}
  for _, id in ipairs(ids) do
    local a = Registry.get(id)
    if a and a.entity and a.entity.valid then out[#out + 1] = a end
  end
  return out
end

--- Tue l'entité et rend le contenu du character-corpse posé à sa place (nil : aucun corps).
local function kill(s, e)
  local x, y = e.position.x, e.position.y
  e.die()
  local best
  for _, c in ipairs(s.find_entities_filtered({ type = "character-corpse" })) do
    if c.valid and math.abs(c.position.x - x) < 0.01 and math.abs(c.position.y - y) < 0.01 then best = c end
  end
  if not best then return nil end
  return best.get_inventory(defines.inventory.character_corpse)
end

local function logs_with(tag)
  local n = 0
  for _, l in ipairs(M.world().logs) do if l:find(tag, 1, true) then n = n + 1 end end
  return n
end

--- Partie avec corps ; `mut` (facultatif) remplace Sp.kit_take dans la table chargée par CETTE partie (mutant de la règle).
local function main_run(mut)
local f, s, chest = new_team(true)
if mut then package.loaded["shared.team.spirale"].kit_take = mut end
local flt = (M.world().filters or {})[defines.events.on_post_entity_died]
check(flt ~= nil and #flt == 1 and flt[1].filter == "type" and flt[1].type == "character",
  "filtre moteur pose a on_init : on_post_entity_died limite aux personnages (relecture de revue-0657)")
local Worker = require("script.team.worker")
local ns = global.fo.kit_offert
local list = agents_of(f)
check(#list >= 4, "equipe de depart : au moins 4 PNJ (" .. #list .. ")")
local function fiche(a) return ns.units[a.entity.unit_number] end
local n_fiches = 0
for _, a in ipairs(list) do if fiche(a) then n_fiches = n_fiches + 1 end end
check(n_fiches == #list, "effectif de depart : chaque PNJ a la fiche de son kit offert (" .. n_fiches .. "/" .. #list .. ")")

-- 1. PNJ de l'effectif de départ (kit offert), avec une cargaison
local a1 = list[1]
a1.entity.get_main_inventory().insert({ name = "iron-plate", count = 7 })
local inv1 = kill(s, a1.entity)
M.run_ticks(1)
check(inv1 ~= nil, "corps pose a la mort")
check(inv1 and inv1.get_item_count(GUN) == 0 and inv1.get_item_count(AMMO) == 0, "kit offert : ni pistolet ni chargeur dans le corps")
check(inv1 and inv1.get_item_count("iron-plate") == 7, "kit offert : la cargaison reste dans le corps (7 plaques)")
check(logs_with("[FO-KIT-OFFERT]") == 1, "journal [FO-KIT-OFFERT] ecrit une fois")
check(next(ns.dead) == nil, "aucune fiche de mort en attente apres le corps rendu")

-- 2. recrue PAYÉE (kit pris au coffre par l'appelant) : rien n'est retiré
local paid = Worker.recruit(f, s, game.tick, false, false)
check(paid ~= nil and not paid.free_kit and ns.units[paid.entity.unit_number] == nil, "recrue payee : pas de fiche")
local inv2 = paid and kill(s, paid.entity)
M.run_ticks(1)
check(inv2 and inv2.get_item_count(GUN) == 1 and inv2.get_item_count(AMMO) == 10, "recrue payee : pistolet et 10 chargeurs gardes dans le corps")

-- 3. PNJ au kit offert qui a tiré 4 chargeurs, réarmé de 4 chargeurs PAYÉS au dépôt : 6 offerts retirés, 4 payés laissés
local a3 = list[2]
local am = a3.entity.get_inventory(defines.inventory.character_ammo)
am.remove({ name = AMMO, count = 4 })
local paid0 = (f.team.rearm and f.team.rearm.mags) or 0
local u3 = a3.entity.unit_number
local waited = 0
while waited < 30 * 3600 and (not ns.units[u3] or ns.units[u3].paid == 0) do
  M.run_ticks(60)
  waited = waited + 60
  if not a3.entity.valid then break end
end
local k3 = ns.units[u3]
check(k3 ~= nil and k3.paid == 4, "reamement au depot : 4 chargeurs payes comptes sur la fiche (" .. tostring(k3 and k3.paid) .. ", "
  .. waited .. " ticks)")
check(((f.team.rearm and f.team.rearm.mags) or 0) - paid0 == 4, "reamement : 4 chargeurs pris au coffre")
local inv3 = a3.entity.valid and kill(s, a3.entity) or nil
M.run_ticks(1)
check(inv3 and inv3.get_item_count(GUN) == 0 and inv3.get_item_count(AMMO) == 4, "reame : pistolet offert retire, 4 chargeurs payes laisses ("
  .. tostring(inv3 and inv3.get_item_count(AMMO)) .. ")")

-- 4. recrue sans arme : pas de fiche
local un = Worker.recruit(f, s, game.tick, true, false)
check(un ~= nil and un.free_kit and ns.units[un.entity.unit_number] == nil, "recrue sans arme : free_kit mais pas de fiche (rien d'offert)")

-- 5. renvoi sans mort : la fiche part avec le PNJ
local Registry = require("script.companion.registry")
local a5 = list[3]
local u5 = a5.entity.unit_number
check(ns.units[u5] ~= nil, "avant le renvoi : fiche presente")
Registry.remove(a5.id, true)
check(ns.units[u5] == nil and ns.dead[u5] == nil, "renvoi (sans mort) : plus de fiche, aucune mort notee")

-- 6. le coffre n'a rien recu du kit retiré (détruit, jamais rendu)
local guns_box = chest.get_inventory(defines.inventory.chest).get_item_count(GUN)
check(guns_box <= 5, "le kit retire n'est pas rendu au coffre (pistolets au coffre " .. guns_box .. " <= 5)")
local tk = ns.taken[f.id]
check(tk and tk.gun == 2 and tk.ammo == 16, "cumul : 2 pistolets, 16 chargeurs retires (" .. tostring(tk and tk.gun) .. ", " .. tostring(tk and tk.ammo) .. ")")
end

print("== Partie avec corps (fait moteur kit-cadavre)")
main_run(nil)

print("== Temoin : partie sans corps (opts.corpses eteint) : rien ne casse, la fiche de mort expire")
local g = new_team(false)
local ns2 = global.fo.kit_offert
local l2 = agents_of(g)
local b1 = l2[1]
local ub = b1.entity.unit_number
b1.entity.die()
M.run_ticks(1)
check(ns2.dead[ub] ~= nil, "sans corps rendu : la mort reste notee")
M.run_ticks(700)
local b2 = agents_of(g)[1]
if b2 then b2.entity.die() end
M.run_ticks(1)
check(ns2.dead[ub] == nil, "fiche de mort oubliee apres Sp.KIT_TTL (600 ticks), a la mort suivante")

-- Mutants de la règle (chacun doit faire tomber au moins un contrôle de la partie avec corps)
local MUTANTS = {
  { "rien retire (aucune parade)", function() return 0, 0 end },
  { "chargeurs payes retires aussi (paid ignore)", function(gift, present) return math.min(1, present.gun or 0), math.min(gift.ammo, present.ammo or 0) end },
  { "tout le corps vide (au-dela du don)", function(gift, present) return present.gun or 0, present.ammo or 0 end },
  { "pistolet garde", function(gift, present, paid) return 0, math.max(0, math.min(gift.ammo, (present.ammo or 0) - (paid or 0))) end },
}
local killed = 0
for _, m in ipairs(MUTANTS) do
  local p0, f0 = passes, failures
  local out = print
  print = function() end
  local ok = pcall(main_run, m[2])
  print = out
  local caught = failures > f0 or not ok
  if caught then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. m[1]) end
  if not ok then print("  mutant refuse par un PLANTAGE (pas par un controle) : " .. m[1]) end
  passes, failures = p0, f0
end
print(string.format("[KIT-OFFERT-MOTEUR] MUTANTS : %d / %d refuses", killed, #MUTANTS))
if killed < #MUTANTS then failures = failures + 1 end

print(string.format("[KIT-OFFERT-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
