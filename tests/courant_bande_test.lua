--[[
  Lot COURANT-BANDE (V0675-A, graine 1618033988) : cause d'une bande « sans courant » ([FO-FONDERIE], script/team/champ.lua), règle pure
  shared/team/champ_raccord.lua (Ra.cause_sans_courant).
  Défaut mesuré : à 47 et 57 min, « 37 consommateur(s) sans courant sur 37, poteau alimente le plus proche a 1 tuiles » : le réseau de la bande
  ÉTAIT joint au réseau alimenté ([FO-FONCTION] elec minute 50 : foreuse_elec_reseau 8/8, poteaux_reseau_gen 84/85, kw_now 0.0), la centrale ne
  produisait rien (machines à vapeur détruites 42,2 → 50,5 min, chaudière à sec 56,3 min). La ligne ne lisait jamais le réseau du consommateur :
  elle faisait chercher un défaut de câblage inexistant. À 36 min au contraire (5 poteaux perdus), le réseau n'était PAS joint (126 tuiles).
  Lancement : lua5.2 tests/courant_bande_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path

local Ra = require("shared.team.champ_raccord")

local okc, fail = 0, 0
local function check(cond, msg)
  if cond then okc = okc + 1 else fail = fail + 1; print("ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

---------------------------------------------------------------------------------------------------
section("1. La règle existe et rend une chaîne")
---------------------------------------------------------------------------------------------------
check(type(Ra.cause_sans_courant) == "function", "1a : Ra.cause_sans_courant est une fonction")
local ok1, r1 = pcall(function() return Ra.cause_sans_courant(12, { [12] = true }, 0, nil, 480) end)
check(ok1 and type(r1) == "string", "1b : rend une chaîne sans erreur")

---------------------------------------------------------------------------------------------------
section("2. Rejeu du journal V0675-A")
---------------------------------------------------------------------------------------------------
-- 47 min : réseau du consommateur = réseau à génératrice (centrale 1 : machines à vapeur détruites), production 0 kW
local live = { [12] = true }
local s47 = Ra.cause_sans_courant(12, live, 0, nil, 480)
check(s47:find("JOINT", 1, true) ~= nil, "2a : 47 min : réseau joint annoncé (" .. tostring(s47) .. ")")
check(s47:find("0 kW", 1, true) ~= nil, "2b : 47 min : production 0 kW annoncée")
check(s47:find("poteau alimente le plus proche", 1, true) == nil, "2c : 47 min : plus de « poteau alimenté le plus proche » quand le réseau est joint")
-- 36 min : 5 poteaux perdus, réseau de la bande (n. 7) sans génératrice, poteau alimenté à 126 tuiles
local s36 = Ra.cause_sans_courant(7, live, 0, 126, 480)
check(s36:find("NON joint", 1, true) ~= nil, "2d : 36 min : réseau non joint annoncé (" .. tostring(s36) .. ")")
check(s36:find("126 tuiles", 1, true) ~= nil, "2e : 36 min : distance au poteau alimenté annoncée")
-- réseau non joint, aucun poteau alimenté dans le rayon
local sfar = Ra.cause_sans_courant(7, live, 0, nil, 480)
check(sfar:find("NON joint", 1, true) ~= nil and sfar:find("480", 1, true) ~= nil, "2f : aucun poteau alimenté à 480 tuiles (" .. tostring(sfar) .. ")")
-- consommateur sous aucun poteau
check(Ra.cause_sans_courant(nil, live, 0, nil, 480) == "sous aucun poteau", "2g : sous aucun poteau")
-- production non nulle mais insuffisante : la valeur est rendue telle quelle
check(Ra.cause_sans_courant(12, live, 659.4, nil, 480):find("659 kW", 1, true) ~= nil, "2h : production arrondie en kW")
-- déterminisme : deux appels, même chaîne
check(Ra.cause_sans_courant(12, live, 0, nil, 480) == s47, "2i : déterministe")

---------------------------------------------------------------------------------------------------
section("3. Câblage : script/team/champ.lua lit le réseau du consommateur avant le poteau alimenté")
---------------------------------------------------------------------------------------------------
do
  local fh = io.open("script/team/champ.lua", "rb")
  local src = fh and fh:read("*a") or ""
  if fh then fh:close() end
  check(src:find("Ra.cause_sans_courant(at_net, live, kw, dist, Champ.CFG.chain_far)", 1, true) ~= nil, "3a : l'émetteur [FO-FONDERIE] passe par la règle pure")
  check(src:find("if not at then at, at_net = { x = e.x, y = e.y }, ent.electric_network_id end", 1, true) ~= nil, "3b : le réseau du premier consommateur sans courant est lu")
  check(src:find('local live = Gens.networks(surface, f.force, "generator")', 1, true) ~= nil, "3c : les réseaux à génératrice sont lus au registre")
  check(src:find("if g.electric_network_id == at_net then kw = kw + (g.energy_generated_last_tick or 0) * 60 / 1000 end", 1, true) ~= nil, "3d : la production du réseau du consommateur est sommée")
  check(src:find("poteau alimente le plus proche a %s tuiles", 1, true) == nil, "3e : l'ancienne queue de ligne (distance seule, réseau jamais lu) a disparu")
  -- ordre : le réseau est classé avant toute recherche du poteau alimenté
  local a = src:find("if at_net and live[at_net] then", 1, true)
  local b = src:find("local np = powered_pole(f, surface, at.x, at.y, Champ.CFG.chain_far)", 1, true)
  check(a ~= nil and b ~= nil and a < b, "3f : le poteau alimenté n'est cherché que dans la branche « réseau non joint »")
end

---------------------------------------------------------------------------------------------------
section("4. Mutants (la règle réécrite sans la branche « joint » est refusée)")
---------------------------------------------------------------------------------------------------
do
  local muts = {
    { "sans branche joint", function(net, lv, kw, dist, far)
      if net == nil then return "sous aucun poteau" end
      if dist then return string.format("reseau NON joint, poteau alimente le plus proche a %.0f tuiles", dist) end
      return string.format("reseau NON joint, aucun poteau alimente a moins de %d tuiles", far)
    end },
    { "joint sans production", function(net, lv, kw, dist, far)
      if net == nil then return "sous aucun poteau" end
      if lv[net] then return "reseau JOINT au reseau alimente" end
      return string.format("reseau NON joint, aucun poteau alimente a moins de %d tuiles", far)
    end },
  }
  local caught = 0
  for _, m in ipairs(muts) do
    local s = m[2](12, live, 0, nil, 480)
    if not (s:find("JOINT", 1, true) and s:find("0 kW", 1, true)) then caught = caught + 1 else print("mutant survivant : " .. m[1]) end
  end
  check(caught == #muts, string.format("mutants refusés : %d sur %d", caught, #muts))
end

print(string.format("[COURANT-BANDE] BILAN : %d OK, %d ECHEC(S)", okc, fail))
if fail > 0 then os.exit(1) end
