--[[
  Lot RECHERCHE (3/11) : la recherche de votre équipe ne se bloque plus quand le joueur change la recherche courante.
  Retour du DC (0.6.46) : « dès que l'utilisateur modifie ce qu'il veut rechercher, ça coupe entièrement le fil de recherche de
  la base et du coup la recherche se bloque ».
    1. règle pure (shared/ai3/recherche_joueur.lua) : qui tient la courante, qui écrit, comment on termine, prérequis ;
    2. moteur simulé : l'équipe cherche ; le joueur choisit une autre technologie qu'il ne paie pas ; la courante reste la
       sienne, l'équipe continue et termine ses technologies ; sans choix du joueur, rien ne change (témoin) ;
    3. mutants : « porte fermée » (ancien comportement : l'équipe ne pense plus sa recherche) et « courante écrasée »
       (l'équipe écrit dans la courante du joueur).
  Lancement : lua5.2 tests/recherche_joueur_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end

section("1. Règle pure")
local R = require("shared.ai3.recherche_joueur")
check(R.holder(nil, nil) == "libre" and R.holder(nil, "x") == "libre", "courante vide : libre")
check(R.holder("x", "x") == "sienne", "courante de l'équipe : sienne")
check(R.holder("y", "x") == "joueur" and R.holder("y", nil) == "joueur", "autre courante : joueur")
check(R.thinks("libre") and R.thinks("sienne") and R.thinks("joueur"), "l'équipe pense sa recherche dans tous les cas")
check(R.writes_force("libre") and R.writes_force("sienne") and not R.writes_force("joueur"),
  "l'équipe n'écrit pas dans la courante du joueur")
check(R.finish_by("libre") == "progress" and R.finish_by("sienne") == "progress" and R.finish_by("joueur") == "flag",
  "fin : progression ou drapeau")
check(R.prereqs_done({}, {}) and R.prereqs_done(nil, nil), "aucun prérequis : faits")
check(R.prereqs_done({ "a", "b" }, { a = true, b = true }) and not R.prereqs_done({ "a", "b" }, { a = true }),
  "prérequis tous faits ou non")
local fh = io.open("shared/ai3/recherche_joueur.lua")
local src = fh:read("*a")
fh:close()
check(not src:find("automation") and not src:find("iron") and not src:find("science%-pack"), "aucun nom d'objet ni de technologie")

section("2. Moteur simulé : le joueur change la recherche courante")
local M = require("tests.mock_engine")
local function W() return M.world() end
local function patches()
  local out, names = {}, { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

--- opts.mode : "joueur" (le joueur choisit une autre technologie qu'il ne paie pas), "temoin" (il ne touche à rien).
--- opts.mutant : "porte" ou "ecrase" (règle pure remplacée APRÈS new_game, qui recharge les modules).
local function run(opts)
  M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0 })
  local force = game.forces.player
  force.technologies["gun-turret"].researched = true -- palier de la tourelle fait d'avance (comme tests/pteam_test.lua)
  local Rm = require("shared.ai3.recherche_joueur")
  if opts.mutant == "porte" then
    Rm.thinks = function(h) return h ~= "joueur" end
  elseif opts.mutant == "ecrase" then
    Rm.writes_force = function() return true end
    Rm.finish_by = function() return "progress" end
  end
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  for _, it in ipairs({ { "iron-plate", 800 }, { "copper-plate", 300 }, { "coal", 200 }, { "stone", 100 }, { "pistol", 2 },
    { "firearm-magazine", 40 }, { "automation-science-pack", 60 }, { "logistic-science-pack", 60 } }) do
    chest.insert({ name = it[1], count = it[2] })
  end
  W().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  local function st() return global.fo.pteam.team.team.ia3 end
  local out = { force = force }
  local waited = 0
  while waited < 30 * 3600 and not (st() and st().lab and st().lab.tech) do M.run_ticks(60); waited = waited + 60 end
  out.started = st() and st().lab and st().lab.tech
  if not out.started then return out end
  if opts.mode == "joueur" then
    -- Le joueur choisit une AUTRE technologie dont les prérequis sont faits : la courante devient la sienne.
    for _, n in ipairs({ "logistics", "heavy-armor", "stone-wall", "military", "optics", "turrets" }) do
      local t = force.technologies[n]
      if n ~= out.started and t and not t.researched then out.pick = n break end
    end
    force.add_research(out.pick)
    out.current_after_pick = force.current_research and force.current_research.name
  end
  -- Le joueur n'a ni laboratoire ni packs : sa recherche n'avance pas ; 30 minutes de jeu.
  -- Par tranches de 10 s : tant que la technologie du joueur n'est pas faite, la courante doit rester la sienne.
  out.violations = 0
  for _ = 1, 180 do
    M.run_ticks(600)
    local cur = force.current_research and force.current_research.name
    if opts.mode == "joueur" and cur ~= out.pick and not force.technologies[out.pick].researched then out.violations = out.violations + 1 end
  end
  out.pick_done = opts.mode == "joueur" and force.technologies[out.pick].researched
  out.current_end = force.current_research and force.current_research.name
  out.done = 0
  for name, tt in pairs(force.technologies) do
    if tt.researched and name ~= "gun-turret" and name ~= out.pick then out.done = out.done + 1 end
  end
  return out
end

local t = run({ mode = "temoin" })
check(t.started ~= nil, "témoin : l'équipe a lancé une recherche (" .. tostring(t.started) .. ")")
check(t.done >= 1, "témoin : l'équipe termine des recherches en 30 min (" .. tostring(t.done) .. ")")

local a = run({ mode = "joueur" })
check(a.started ~= nil and a.pick ~= nil, "l'équipe a lancé une recherche, le joueur en choisit une autre ("
  .. tostring(a.started) .. " -> " .. tostring(a.pick) .. ")")
check(a.current_after_pick == a.pick, "la courante est celle du joueur")
check(a.done >= 1, "l'équipe continue de terminer des recherches malgré le choix du joueur (" .. tostring(a.done) .. ")")
check(a.violations == 0, "la courante du joueur n'est jamais écrasée par l'équipe (" .. tostring(a.violations) .. " relevé(s) en 30 min)")

section("3. Mutants")
local m1 = run({ mode = "joueur", mutant = "porte" })
check(m1.pick ~= nil, "mutant porte fermée : situation posée")
check(m1.done < a.done, "mutant porte fermée (ancien comportement) : l'équipe ne termine presque plus rien ("
  .. tostring(m1.done) .. " contre " .. tostring(a.done) .. ")")
local m2 = run({ mode = "joueur", mutant = "ecrase" })
check(m2.pick ~= nil and m2.violations > 0, "mutant courante écrasée : la recherche du joueur est remplacée ("
  .. tostring(m2.violations) .. " relevé(s))")

print(string.format("  mesures : temoin %s ; joueur %s (fait %s, courante finale %s) ; porte %s ; ecrase %d relevé(s)", tostring(t.done), tostring(a.done), tostring(a.pick_done), tostring(a.current_end), tostring(m1.done), m2.violations))
print(string.format("[RECHERCHE-JOUEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
