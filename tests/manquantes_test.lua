-- Lot RECHERCHE-BRAS (suite) : entités manquantes nommées dans [FO-BLOQUE] et [FO-CHANTIER-LENT] (shared/team/manquantes.lua). Hors jeu ; mutants refusés.
package.path = "./?.lua;" .. package.path
_G.log = function() end
local ok, ko = 0, 0
local function check(name, cond, info)
  if cond then ok = ok + 1 else ko = ko + 1 print("ECHEC : " .. name .. (info and (" (" .. tostring(info) .. ")") or "")) end
end
local Mq = require("shared.team.manquantes")
local C = require("shared.team.chantier_lent")

local function ents()
  return {
    { name = "boiler", role = "chaudiere", x = 1, y = 2, built = true },
    { name = "steam-engine", role = "machine", x = 5.5, y = 2, built = true },
    { name = "small-electric-pole", role = "poteau", x = 9, y = 4, ghosted = true, fails = 2, why = "occupe" },
    { name = "pipe", role = "tuyau", x = 3, y = 3, ghosted = false, npc_blocks = 1 },
    { name = "pipe", role = "tuyau", x = 2, y = 3 },
    { name = "inserter", role = "bras", x = 7, y = 7, skipped = true },
    { name = "transport-belt", role = "tapis", x = 8, y = 8, dropped = true },
    { name = "offshore-pump", role = "pompe", x = 0, y = 0, fails = 5, ghosted = true, why = "eau" },
  }
end
local function rule_ok(R)
  local e = ents()
  local m = R.missing(e)
  if #m ~= 4 then return false end -- ni bâties, ni sautées, ni abandonnées
  if m[1].name ~= "offshore-pump" or m[2].name ~= "small-electric-pole" then return false end -- les plus refusées d'abord
  if m[3].x ~= 2 or m[4].x ~= 3 then return false end -- puis nom, x (ordre total)
  local d = R.describe(e)
  if not d or not d:find("manquantes (4 sur 8)", 1, true) then return false end
  if not d:find("offshore-pump/pompe en (0, 0) fantome pose, 5 refus, dernier motif : eau", 1, true) then return false end
  if not d:find("et 1 autre(s)", 1, true) then return false end
  if d:find("steam-engine", 1, true) or d:find("inserter", 1, true) then return false end
  local s = R.state({ ghosted = false, npc_blocks = 2 })
  if s ~= "sans fantome, 2 blocage(s) PNJ" then return false end
  if R.describe({ { name = "x", built = true } }) ~= nil or R.describe({}) ~= nil or R.describe(nil) ~= nil then return false end
  local d1 = R.describe(e, 1)
  return d1 and d1:find("et 3 autre(s)", 1, true) ~= nil and not d1:find("small-electric-pole", 1, true)
end
check("temoin : la regle passe", rule_ok(Mq))

-- la phrase est dans la ligne [FO-CHANTIER-LENT] et absente quand rien ne manque
local base = { team = "t", pid = 3, band = "x", state = "chantier", minute = 12, cause = "c", stall_min = 10, built = 1, total = 2, roles = {}, tasks = {}, tasks_n = 0 }
local l0 = C.line(base)
base.miss = Mq.describe(ents())
local l1 = C.line(base)
check("ligne sans diagnostic : inchangee", not l0:find("manquantes", 1, true) and l1:sub(1, #l0) == l0)
check("ligne avec diagnostic : phrase a la fin", l1:find("; manquantes (4 sur 8) : offshore-pump", 1, true) ~= nil and l1:find("et 1 autre%(s%)$") ~= nil)

-- l'exécutant lit les entités du projet
package.loaded["script.team.board"] = {}
local Cl = require("script.team.chantier_lent")
check("Cl.missing : suffixe de [FO-BLOQUE]", Cl.missing({ ents = ents() }):sub(1, 17) == " ; manquantes (4 " and Cl.missing({ ents = {} }) == "" and Cl.missing(nil) == "")

local MUTANTS = {
  { "bâties comptées", function(R) local m = R.missing R.missing = function(e) local o = {} for _, x in ipairs(e or {}) do o[#o + 1] = x end return o end end },
  { "sautées comptées", function(R) local m = R.missing R.missing = function(e) local o = {} for _, x in ipairs(e or {}) do if not x.built then o[#o + 1] = x end end table.sort(o, function(a, b) return (a.fails or 0) > (b.fails or 0) end) return o end end },
  { "moins refusées d'abord", function(R) local m = R.missing R.missing = function(e) local o = m(e) table.sort(o, function(a, b) return (a.fails or 0) < (b.fails or 0) end) return o end end },
  { "tout nommé (pas de plafond)", function(R) local d = R.describe R.describe = function(e) return d(e, 99) end end },
  { "rien ne manque : phrase vide", function(R) local d = R.describe R.describe = function(e, m) return d(e, m) or "manquantes (0 sur 0) : " end end },
  { "état sans fantôme", function(R) R.state = function(e) return "?" end end },
}
for _, mu in ipairs(MUTANTS) do
  package.loaded["shared.team.manquantes"] = nil
  local R = require("shared.team.manquantes")
  mu[2](R)
  check("mutant refuse : " .. mu[1], not rule_ok(R))
end
print(string.format("[MANQUANTES] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
