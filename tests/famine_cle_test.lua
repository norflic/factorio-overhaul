-- Lot FAMINE-FER : shared/team/famine_cle.lua (règle pure) et sa lecture par script/team/famine_fer.lua (moteur simulé minimal).
package.path = "./?.lua;" .. package.path
local ok, bad = 0, 0
local function check(name, cond) if cond then ok = ok + 1 else bad = bad + 1 print("ECHEC : " .. name) end end

local function load_rule(mut)
  package.loaded["shared.team.famine_cle"] = nil
  local fh = assert(io.open("shared/team/famine_cle.lua", "rb"))
  local src = fh:read("*a")
  fh:close()
  if mut then src = mut(src) end
  return assert(load(src, "=famine_cle"))()
end
local F = load_rule()

local base = { starved = true, migr = "en cours", stage = "projet", retired = 0, project = "reserve" }
local function with(over) local t = {} for k, v in pairs(base) do t[k] = v end for k, v in pairs(over) do t[k] = v end return t end

check("famine, bande en réserve, rien retiré : l'extension thermique reste ouverte", F.open(base) == true)
check("famine, projet en plan : ouverte", F.open(with({ project = "plan" })) == true)
check("famine, projet en attente : ouverte", F.open(with({ project = "attente" })) == true)
check("pas de famine : fermée (la migration garde la main)", F.open(with({ starved = false })) == false)
check("bande en chantier : fermée", F.open(with({ project = "chantier" })) == false)
check("paires déjà retirées : fermée", F.open(with({ retired = 3 })) == false)
check("migration autre que « en cours » : fermée", F.open(with({ migr = "fini" })) == false)
check("étape autre que « projet » : fermée", F.open(with({ stage = "veille" })) == false)
check("projet inconnu : fermé", F.open(with({ project = "" })) == false)
check("entrée vide : fermée", F.open(nil) == false and F.open({}) == false)

-- mutants : chacun doit faire échouer au moins un contrôle
local function survivors(mut)
  local R = load_rule(mut)
  local fails = 0
  local cases = {
    { base, true }, { with({ project = "plan" }), true }, { with({ starved = false }), false }, { with({ project = "chantier" }), false },
    { with({ retired = 3 }), false }, { with({ migr = "fini" }), false }, { with({ stage = "veille" }), false }, { with({ project = "" }), false },
  }
  for _, c in ipairs(cases) do if R.open(c[1]) ~= c[2] then fails = fails + 1 end end
  load_rule()
  return fails
end
check("mutant « famine sans issue » (toujours fermée) refusé", survivors(function(s) return (s:gsub("return F%.WAITING%[i%.project or \"\"%] == true", "return false")) end) > 0)
check("mutant « sans la condition de famine » refusé", survivors(function(s) return (s:gsub("if not %(i and i%.starved%) then return false end", "if not i then return false end")) end) > 0)
check("mutant « paires retirées ignorées » refusé", survivors(function(s) return (s:gsub("if %(i%.retired or 0%) > 0 then return false end", "")) end) > 0)
check("mutant « chantier compté comme attente » refusé", survivors(function(s) return (s:gsub("plan = true,", "plan = true, chantier = true,")) end) > 0)

-- compatibilité avec la règle du DC « plus de paire foreuse + four, l'électrique prend la suite » (shared/team/gisement.lua G.forbid_pairs) :
-- la famine ne rouvre JAMAIS un cas que G.forbid_pairs interdit (celle-ci ne s'applique déjà jamais à une matière qui manque)
local G = require("shared.team.gisement")
local function never_reopens_forbidden(R)
  for _, starved in ipairs({ true, false }) do
    for _, swap in ipairs({ 0, 2 }) do
      for _, ret in ipairs({ 0, 3 }) do
        local open = R.open({ starved = starved, migr = "en cours", stage = "projet", retired = ret, project = "reserve" })
        local forbidden = G.forbid_pairs({ sink_furnace = true, swap_done = swap, swap_ready = 0, retired = ret, starved = starved })
        if open and forbidden then return false end
      end
    end
  end
  return true
end
check("la famine ne rouvre aucun gisement interdit aux paires (G.forbid_pairs)", never_reopens_forbidden(F))
local R_mut = load_rule(function(s) return (s:gsub("if not %(i and i%.starved%) then return false end", "if not i then return false end")) end)
check("mutant « famine rouvre un gisement interdit aux paires » refusé", never_reopens_forbidden(R_mut) == false)
load_rule()

-- moteur : la lecture du runtime sur un état minimal
package.loaded["script.team.famine_fer"] = nil
local T = require("shared.team.config")
local Fr = dofile("script/team/famine_fer.lua")
local iron = T.outposts.iron
local f = { team = { ia3 = { starved = { [iron.product] = true } } }, migration = { o = { [1] = { stage = "projet", pid = 5 } } },
  build = { projects = { [5] = { state = "reserve" } } } }
local o = { id = 1, kind = "iron", migr = "en cours" }
check("moteur : plaque clé en famine, bande en réserve : ouverte", Fr.open(f, o) == true)
f.team.ia3.starved = {}
check("moteur : plus de famine : fermée", Fr.open(f, o) == false)
f.team.ia3.starved = { [iron.product] = true }
f.build.projects[5].state = "chantier"
check("moteur : bande en chantier : fermée", Fr.open(f, o) == false)
f.build.projects[5].state = "reserve"
check("moteur : autre matière que la plaque clé : fermée", Fr.open(f, { id = 1, kind = "coal", migr = "en cours" }) == false)
check("moteur : sans migration : fermée", Fr.open(f, { id = 1, kind = "iron" }) == false)

print(string.format("[FAMINE-CLE] BILAN : %d OK, %d ECHEC(S)", ok, bad))
os.exit(bad == 0 and 0 or 1)
