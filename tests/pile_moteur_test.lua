--[[
  Lot PILE-PRIORITE : banc HORS JEU de la CHAÎNE complète, moteur simulé (tests/mock_engine.lua). Votre équipe (coffre posé).
    chaîne : pièce détruite au registre (f.recon, script/team/reconstruction.lua) -> entrées de la pile (script/team/pile.lua,
    PileRt.inputs) -> pensée (script/ai3/cerveau.lua, ctx.pile -> shared/ai3/cerveau.lua C.think -> shared/ai3/pile.lua Pi.update,
    état f.team.ia3.pile) -> fabrication R1 de l'objet manquant (tableau des tâches) et garde de l'amélioration (script/team/team.lua :
    changement de foreuses, migration du champ, paiement du capital) -> journal [FO-PILE] -> pièce refaite ou retirée : dépilée,
    l'amélioration revient.
  Lancement : lua5.2 tests/pile_moteur_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end
local function W() return M.world() end

local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

local function logs_with(tag)
  local out = {}
  for _, l in ipairs(W().logs) do if l:find(tag, 1, true) then out[#out + 1] = l end end
  return out
end

local ITEM = "burner-mining-drill" -- objet de la pièce perdue : fabricable à la main au départ, absent du coffre

local function run_all()
  -- Le QG de votre équipe ne demande pas de tourelle dans ce banc (sinon le cadre « protéger le QG » retient dès le départ, ce qui est
  -- juste mais cache le cas étudié : une perte SEULE).
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  require("shared.team.config").defend_hq = 0 -- après new_game (les modules du mod y sont rechargés)
  if W().remote["fo-ia3f"] then remote.call("fo-ia3f", "set_fog", false) end
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 400 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 200 }, { "stone-furnace", 8 },
      { "pistol", 2 }, { "firearm-magazine", 40 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  M.run_ticks(900)
  local f = global.fo.pteam.team
  local trace = {}

  -- Espions des familles d'amélioration (les tables des modules sont partagées avec script/team/team.lua).
  local calls = { swap = 0, mig = 0, pay = 0 }
  local FoSwap = require("script.team.foreuse_swap")
  local MigChamp = require("script.team.migration_champ")
  local Ia3 = require("script.ai3.cerveau")
  local o_swap, o_mig, o_pay = FoSwap.think, MigChamp.think, Ia3.capital_pay
  FoSwap.think = function(...) calls.swap = calls.swap + 1 return o_swap(...) end
  MigChamp.think = function(...) calls.mig = calls.mig + 1 return o_mig(...) end
  Ia3.capital_pay = function(...) calls.pay = calls.pay + 1 return o_pay(...) end

  section("1. La pile existe pour votre équipe (le cerveau principal aussi)")
  local st = f.team and f.team.ia3 and f.team.ia3.pile
  check(st ~= nil, "pile créée à la pensée dans f.team.ia3.pile")
  check(#logs_with("[FO-PILE]") >= 1, "journal [FO-PILE] écrit à la première pensée (" .. #logs_with("[FO-PILE]") .. ")")
  trace[#trace + 1] = logs_with("[FO-PILE]")[1] or "?"
  local hold0 = st and st.hold
  check(hold0 == false, "aucune perte, QG sans tourelle demandée : l'amélioration n'est pas retenue ("
    .. tostring(st and require("shared.ai3.pile").describe(st)) .. ")")

  section("2. Une pièce détruite SANS son objet au coffre : réparer passe avant améliorer")
  local Rc = require("shared.team.reconstruction")
  require("script.team.reconstruction").state(f)
  local key = Rc.record(f.recon, { name = ITEM, x = 30.5, y = 30.5, item = ITEM, value = Rc.role_value("foreuse") }, game.tick - 2000)
  calls.swap, calls.mig, calls.pay = 0, 0, 0
  local crafted = false
  for _ = 1, 4 do
    M.run_ticks(300)
    for _, t in ipairs(require("script.team.board").get(f).list or {}) do
      if t.kind == "craft" and t.item == ITEM then crafted = true end
    end
  end
  st = f.team.ia3.pile
  check(st.hold and st.top == 1, "pièce perdue sans objet : sommet s'adapter, amélioration retenue")
  check(calls.swap == 0 and calls.mig == 0 and calls.pay == 0,
    string.format("aucun changement de foreuses, migration ni paiement pendant la retenue (%d, %d, %d)", calls.swap, calls.mig, calls.pay))
  check(crafted or (f.recon.lost[key] == nil), "l'objet de la pièce est fabriqué (tâche au tableau) ou la pièce déjà refaite")
  local susp = logs_with("SUSPENDU")
  check(#susp >= 1, "journal : la pile annonce l'amélioration SUSPENDUE au changement de sommet")
  trace[#trace + 1] = susp[1] or "?"

  section("3. Pièce refaite (ou retirée) : dépilée, l'amélioration revient")
  if f.recon.lost[key] then Rc.done(f.recon, key) end
  calls.swap, calls.mig, calls.pay = 0, 0, 0
  M.run_ticks(600)
  st = f.team.ia3.pile
  check(not st.hold and (st.closed_n or 0) >= 1, "pièce partie : cadre dépilé, amélioration permise")
  check(calls.swap >= 1 and calls.mig >= 1, string.format("changement de foreuses et migration de nouveau appelés (%d, %d)", calls.swap, calls.mig))
  local back = logs_with("ameliorer permis")
  check(#back >= 2, "journal : retour à « ameliorer permis » noté")
  trace[#trace + 1] = back[#back] or "?"

  section("4. État sérialisable")
  local function deep_ok(t, seen)
    seen = seen or {}
    if seen[t] then return true end
    seen[t] = true
    for k, v in pairs(t) do
      local tk, tv = type(k), type(v)
      if tk ~= "string" and tk ~= "number" then return false end
      if tv == "table" then if getmetatable(v) ~= nil or not deep_ok(v, seen) then return false end
      elseif tv ~= "string" and tv ~= "number" and tv ~= "boolean" then return false end
    end
    return true
  end
  check(deep_ok(st), "f.team.ia3.pile : nombres, chaînes, booléens, tables (global)")
  FoSwap.think, MigChamp.think, Ia3.capital_pay = o_swap, o_mig, o_pay
  return trace
end

--- QG à 0 tourelle (règle ordinaire T.defend_hq) : le cadre « protéger le QG » retient dès le départ, aucun paiement d'amélioration.
local function run_hq()
  section("0. QG sans ses tourelles : protéger d'abord")
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  if W().remote["fo-ia3f"] then remote.call("fo-ia3f", "set_fog", false) end
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 60 }, { "copper-plate", 100 }, { "coal", 200 }, { "stone", 200 }, { "stone-furnace", 8 },
      { "pistol", 2 }, { "firearm-magazine", 40 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  local Ia3 = require("script.ai3.cerveau")
  local FoSwap = require("script.team.foreuse_swap")
  local n = { pay = 0, swap = 0 }
  local o_pay, o_swap = Ia3.capital_pay, FoSwap.think
  Ia3.capital_pay = function(...) n.pay = n.pay + 1 return o_pay(...) end
  FoSwap.think = function(...) n.swap = n.swap + 1 return o_swap(...) end
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  M.run_ticks(1500)
  local f = global.fo.pteam.team
  local st = f.team.ia3.pile
  local fr = nil
  for _, x in ipairs(st.frames or {}) do if x.key == "proteger:hq" then fr = x end end
  check(st.hold and fr ~= nil, "QG à 0 tourelle, 60 fer : cadre « protéger le QG », amélioration retenue")
  check(n.pay == 0 and n.swap == 0, string.format("aucun paiement d'amélioration ni changement de foreuses (%d, %d)", n.pay, n.swap))
  local l = logs_with("proteger:hq")
  check(#l >= 1, "journal [FO-PILE] : le cadre protéger le QG est écrit")
  Ia3.capital_pay, FoSwap.think = o_pay, o_swap
  return l[1]
end

local l0 = run_hq()
if l0 then print("  " .. l0) end
local t1 = run_all()
for _, l in ipairs(t1) do print("  " .. l) end
print(string.format("[PILE-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
